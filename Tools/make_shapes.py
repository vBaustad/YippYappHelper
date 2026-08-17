#!/usr/bin/env python3
"""Generate the sprite shapes the raid trainer draws its actors with.

    python Tools/make_shapes.py

The trainer started out drawing everything as a disc, because a disc is
the one shape the addon already had art for. That reads correctly for
ground effects -- a swirl or a puddle in WoW really is a circle -- and
badly for everything else, because a player, a boss and three kinds of
add all rendered as coloured dots that differ only in hue.

So this writes a small alphabet of silhouettes. Same convention as
Tools/make_round_corners.py, and for the same reasons: white RGB with
the shape in the alpha channel, so the Lua side picks the colour with
SetVertexColor and one tile serves every state a thing can be in.

TWO RULES THE SHAPES ARE BUILT TO, both of which are about rotation.

1. EVERY SHAPE FITS INSIDE THE TEXTURE'S INSCRIBED CIRCLE.

   Texture:SetRotation spins the art inside its own rectangle and clips
   whatever leaves it. A shape drawn out to the corners would have those
   corners sheared off the moment it turned, and the artefact looks like
   a rendering bug rather than a shape choice. Keeping every vertex
   within radius size/2 means any shape can face any direction.

2. DIRECTIONAL SHAPES POINT ALONG +X.

   Authored pointing right, so the Lua can pass an angle straight to
   SetRotation with no per-shape offset to remember. Core/../RaidTrainer.lua
   carries a single SPRITE_FACING constant for the whole set, so if the
   client's rotation convention turns out to be mirrored or a quarter
   turn off, it is one number in one place rather than eight.
"""

import math
import os
import struct

# Drawn between about 14 and 44 pixels. 64 gives a comfortable downscale
# at the top of that range without shipping tiles anyone would notice.
SIZE = 64

# Coverage is sampled rather than solved, which is what gives the
# diagonals an alpha ramp instead of a staircase. 6x6 per pixel is 36
# samples; past that the edges stop visibly improving.
SUPERSAMPLE = 6

# A hair under half, so a shape's own antialiased edge finishes inside
# the tile rather than being clipped flat by it.
R = SIZE / 2.0 - 1.0


def poly(*points):
    """A closed polygon, in units of R with the origin at the centre."""
    return [(x, y) for x, y in points]


def star(spikes, inner, outer=1.0, phase=0.0):
    """A ring of alternating radii -- stars, cogs and spiky discs."""
    pts = []
    for i in range(spikes * 2):
        angle = phase + i * math.pi / spikes
        r = outer if i % 2 == 0 else inner
        pts.append((math.cos(angle) * r, math.sin(angle) * r))
    return pts


def ngon(sides, phase=0.0, r=1.0):
    return [
        (math.cos(phase + i * 2 * math.pi / sides) * r,
         math.sin(phase + i * 2 * math.pi / sides) * r)
        for i in range(sides)
    ]


def blob(seed=7, lumps=13, low=0.72, high=1.0):
    """A lumpy near-circle, for things that are meant to look organic.

    Deterministic on purpose. Art regenerated from a seeded loop is the
    same art next time somebody runs the tool; art from random() is a
    diff in the repository every time.
    """
    pts = []
    state = seed
    for i in range(lumps):
        # A small linear congruential step. Not a good generator, and it
        # does not need to be -- it needs to be repeatable.
        state = (state * 1103515245 + 12345) % 2147483648
        t = state / 2147483648.0
        r = low + (high - low) * t
        angle = i * 2 * math.pi / lumps
        pts.append((math.cos(angle) * r, math.sin(angle) * r))
    return pts


# The alphabet.
#
# Directional shapes (ship, dart) point along +X. The rest are radially
# symmetric, so their orientation only matters if the Lua spins them --
# which the swirl relies on.
SHAPES = {
    # The player. A dart with a notched tail, which is the cheapest
    # silhouette that says "this end is the front" at 16 pixels.
    "ShapeShip": poly((1.0, 0.0), (-0.75, 0.70), (-0.42, 0.0), (-0.75, -0.70)),

    # Projectiles, and anything that should read as travelling.
    "ShapeDart": poly((1.0, 0.0), (-0.35, 0.55), (-0.15, 0.0), (-0.35, -0.55)),

    # A plain diamond -- pickups, and the small stuff.
    "ShapeDiamond": poly((1.0, 0.0), (0.0, 0.80), (-1.0, 0.0), (0.0, -0.80)),

    # Adds. A hexagon reads as constructed, a blob as grown; the raid has
    # both kinds and they should not look alike.
    "ShapeHex": ngon(6),
    "ShapeBlob": blob(),

    # The boss, when the Encounter Journal has no portrait to give us. A
    # spiked disc is the shape a threat wants to be, and it is
    # distinguishable from every add at a glance.
    "ShapeSpike": star(9, 0.66),

    # Collectables. A five-pointed star is unmistakably "pick this up"
    # and is used nowhere else in the set.
    "ShapeStar": star(5, 0.45, phase=math.pi / 2),
}


def ellipse(x, y, cx, cy, rx, ry):
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


def skull(x, y):
    """The boss token.

    Built as a predicate rather than a polygon because a skull is mostly
    HOLES -- two sockets, a nose and the gaps between the teeth -- and a
    single closed outline cannot describe a shape with holes in it. An
    add-and-subtract test can, and it stays readable as arithmetic.

    Everything is kept inside radius 1 so the tile can still be rotated
    without shearing, even though the skull is drawn upright.
    """
    # Cranium and jaw, as two overlapping ellipses.
    if not (ellipse(x, y, 0, 0.20, 0.76, 0.70)
            or ellipse(x, y, 0, -0.42, 0.50, 0.46)):
        return False
    # The pinch above the jaw. Without these the silhouette is an egg.
    if ellipse(x, y, 0.72, -0.14, 0.30, 0.30):
        return False
    if ellipse(x, y, -0.72, -0.14, 0.30, 0.30):
        return False
    # Sockets. The single feature doing most of the reading work at
    # 26 pixels, so they are large and set wide.
    if ellipse(x, y, 0.32, 0.26, 0.24, 0.26):
        return False
    if ellipse(x, y, -0.32, 0.26, 0.24, 0.26):
        return False
    # Nose.
    if ellipse(x, y, 0, -0.10, 0.11, 0.15):
        return False
    # Teeth, as gaps cut out of the jaw.
    if -0.88 <= y <= -0.28:
        for tooth in (-0.30, -0.10, 0.10, 0.30):
            if abs(x - tooth) <= 0.04:
                return False
    return True


def sword(x, y):
    """Melee. A blade pointing +X, with a crossguard and a pommel.

    Drawn as a predicate for the same reason the skull is: it is several
    overlapping rectangles rather than one closed outline, and describing
    it as a union is far easier to read than a vertex list that has to
    walk all the way round it.

    Kept chunky on purpose. This is drawn at about fifteen pixels, so a
    realistically thin blade would vanish -- the reading has to come from
    the crossguard breaking the silhouette, not from fine detail.
    """
    # Blade, tapering to a point over its last third.
    if -0.20 <= x <= 0.94:
        half = 0.115
        if x > 0.60:
            half = 0.115 * (1.0 - (x - 0.60) / 0.36)
        if abs(y) <= half:
            return True
    # Crossguard.
    if -0.34 <= x <= -0.20 and abs(y) <= 0.42:
        return True
    # Grip.
    if -0.66 <= x <= -0.34 and abs(y) <= 0.085:
        return True
    # Pommel.
    if ellipse(x, y, -0.72, 0.0, 0.11, 0.15):
        return True
    return False


def bow(x, y):
    """Ranged. A recurve seen side-on: the limb, and its string.

    The straight string is doing the work. An arc on its own is close
    enough to a circle to be taken for one of the ground effects, which
    is the one thing an ally glyph must never look like -- and the chord
    across it settles that in a single stroke.
    """
    d = math.sqrt(x * x + y * y)
    a = math.atan2(y, x)
    limit = math.radians(76)

    if 0.56 <= d <= 0.84 and abs(a) <= limit:
        return True
    tip_x = 0.70 * math.cos(limit)
    tip_y = 0.70 * math.sin(limit)
    if abs(x - tip_x) <= 0.08 and abs(y) <= tip_y:
        return True
    return False


def shield(x, y):
    """Tank. A heater shield: flat shoulders tapering to a point.

    The most recognisable of the four at fifteen pixels, because nothing
    else in the set has a flat top -- the eye finds it before it has
    resolved any detail.
    """
    if y > 0.74 or y < -0.86:
        return False
    half = 0.62
    if y < 0.10:
        # Curved taper rather than straight, or it reads as a spade.
        t = (0.10 - y) / 0.96
        half = 0.62 * (1.0 - t * t * 0.96)
    if abs(x) > half:
        return False
    # Knock the top corners off so it is a shield and not a tombstone.
    if y > 0.56 and abs(x) > 0.50:
        return ellipse(x, y, 0.50 if x > 0 else -0.50, 0.56, 0.12, 0.18)
    return True


def cross(x, y):
    """Healer. A plus, and deliberately nothing cleverer.

    Every game that has needed to say "healer" in a few pixels has used
    this, which is exactly why it works: it is read rather than
    interpreted.
    """
    arm, reach = 0.26, 0.80
    return (abs(x) <= arm and abs(y) <= reach) or (abs(y) <= arm and abs(x) <= reach)


def rasterise_fn(fn):
    """Rows top-to-bottom of alpha for an arbitrary point-inside test."""
    step = 1.0 / SUPERSAMPLE
    half = SIZE / 2.0
    rows = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            hits = 0
            for sy in range(SUPERSAMPLE):
                for sx in range(SUPERSAMPLE):
                    mx = (x + (sx + 0.5) * step - half) / R
                    my = -(y + (sy + 0.5) * step - half) / R
                    if fn(mx, my):
                        hits += 1
            row.append(int(hits / (SUPERSAMPLE * SUPERSAMPLE) * 255 + 0.5))
        rows.append(row)
    return rows


def point_in_poly(px, py, verts):
    inside = False
    n = len(verts)
    j = n - 1
    for i in range(n):
        xi, yi = verts[i]
        xj, yj = verts[j]
        if (yi > py) != (yj > py):
            xint = (xj - xi) * (py - yi) / (yj - yi) + xi
            if px < xint:
                inside = not inside
        j = i
    return inside


def rasterise(verts):
    """Rows top-to-bottom of alpha bytes for a polygon in R units."""
    step = 1.0 / SUPERSAMPLE
    half = SIZE / 2.0
    rows = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            hits = 0
            for sy in range(SUPERSAMPLE):
                for sx in range(SUPERSAMPLE):
                    # Pixel space to shape space. Y is negated because
                    # row 0 is the TOP of the image and the shapes are
                    # authored with Y pointing up.
                    mx = (x + (sx + 0.5) * step - half) / R
                    my = -(y + (sy + 0.5) * step - half) / R
                    if point_in_poly(mx, my, verts):
                        hits += 1
            row.append(int(hits / (SUPERSAMPLE * SUPERSAMPLE) * 255 + 0.5))
        rows.append(row)
    return rows


def rasterise_swirl(arcs=3, inner=0.55, outer=0.98, sweep=1.5):
    """An annulus cut into arcs, for the rotating telegraph ring.

    Not a polygon, so it gets its own sampler. The point of it is that
    a telegraph the player has seen a hundred times should still read as
    "this is winding up" at a glance, and a ring that turns does that
    without any extra Lua beyond an angle that grows.
    """
    step = 1.0 / SUPERSAMPLE
    half = SIZE / 2.0
    span = 2 * math.pi / arcs
    rows = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            hits = 0
            for sy in range(SUPERSAMPLE):
                for sx in range(SUPERSAMPLE):
                    mx = (x + (sx + 0.5) * step - half) / R
                    my = -(y + (sy + 0.5) * step - half) / R
                    d = math.sqrt(mx * mx + my * my)
                    if inner <= d <= outer:
                        a = math.atan2(my, mx) % span
                        if a <= span * sweep / arcs:
                            hits += 1
            row.append(int(hits / (SUPERSAMPLE * SUPERSAMPLE) * 255 + 0.5))
        rows.append(row)
    return rows


def write_tga(path, rows):
    """Uncompressed 32-bit BGRA, origin bottom-left.

    Hand-rolled rather than via PIL, matching make_round_corners.py:
    WoW wants uncompressed, and PIL's TGA writer has defaulted to RLE in
    some versions.
    """
    size = len(rows)
    header = struct.pack(
        "<BBBHHBHHHHBB",
        0, 0, 2,
        0, 0, 0,
        0, 0,
        size, size,
        32, 8,
    )
    body = bytearray()
    for row in reversed(rows):
        for a in row:
            body += bytes((255, 255, 255, a))
    with open(path, "wb") as fh:
        fh.write(header)
        fh.write(body)
    print("wrote %-28s (%d bytes)" % (os.path.basename(path), 18 + len(body)))


def main():
    media = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Media")
    for name, verts in sorted(SHAPES.items()):
        write_tga(os.path.join(media, name + ".tga"), rasterise(verts))
    write_tga(os.path.join(media, "ShapeSwirl.tga"), rasterise_swirl())
    write_tga(os.path.join(media, "ShapeSkull.tga"), rasterise_fn(skull))
    write_tga(os.path.join(media, "ShapeSword.tga"), rasterise_fn(sword))
    write_tga(os.path.join(media, "ShapeBow.tga"), rasterise_fn(bow))
    write_tga(os.path.join(media, "ShapeShield.tga"), rasterise_fn(shield))
    write_tga(os.path.join(media, "ShapeCross.tga"), rasterise_fn(cross))


if __name__ == "__main__":
    main()
