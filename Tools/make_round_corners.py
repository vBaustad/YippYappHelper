#!/usr/bin/env python3
"""Generate the round art the addon draws its own curves with.

    python Tools/make_round_corners.py

Writes four tiles:

    RoundFill / RoundEdge   one corner of a rounded rectangle, and its
                            hairline. Core/Widgets.lua tiles these four
                            ways to round a card.
    CircleMask / CircleRing a full disc and its rim, for the hero talent
                            medallions on the Best in Slot page. The
                            disc is used as a mask over the tree's own
                            icon and the rim is drawn over the result,
                            which is how Blizzard's hero talent picker
                            is built and therefore the shape people
                            already read as "hero talent".

Why our own art rather than a Blizzard atlas: the mask atlases that
would do this job get renamed between builds. Baganator ships a runtime
check picking between "common-mask-circle" and "CircleMaskScalable"
depending on which one the client has, and an atlas that silently
resolves to nothing renders as a missing corner nobody sees until a
patch day. Two 4KB tiles we generate ourselves cannot drift.

Both tiles are white with the shape in the alpha channel, so the Lua
side tints them with whatever colour the active skin gives that role --
one tile serves the dark panels and the Blizzlike gold alike.

Each tile is the TOP-LEFT corner of a rounded rectangle: the arc is
centred on the tile's bottom-right, so the solid part is the inside of
the card. The other three corners are the same tile flipped through
SetTexCoord, which is why there is one file and not four.
"""

import os
import struct

# Drawn at 8px in the UI. 32 leaves four source pixels per drawn pixel,
# which is enough for the downscale to stay smooth without shipping a
# tile larger than the thing it draws.
SIZE = 32
# One drawn pixel of ring at an 8px radius. The edge tile is an annulus
# rather than a second filled disc laid under the first: these surfaces
# are semi-transparent, and a filled disc behind them shows its colour
# through the whole card instead of only at the border.
EDGE_PX = SIZE // 8
# Coverage is sampled rather than computed, so the arc gets an alpha
# ramp instead of a staircase.
SUPERSAMPLE = 8

# The discs get their own, larger tile. They are drawn at 40px rather
# than the corners' 8, and a rim thin enough to look right at that size
# is barely more than a pixel in a 32px source -- too little to carry a
# clean antialiased curve.
CIRCLE_SIZE = 64
# Blizzard's hero talent medallions wear a rim of roughly a twelfth of
# their radius. Ours was four source pixels out of a fifteen-pixel
# radius, which is over a quarter of the radius and therefore nearly
# HALF the medallion's area -- the rim was eating the artwork it was
# supposed to frame. Area goes as the square of the radius, which is why
# a rim that looks merely thick hides so much.
CIRCLE_RIM_PX = 3


def coverage(cx, cy, inner, outer, ox, oy):
    """Fraction of pixel (cx, cy) inside the ring between two radii."""
    hits = 0
    step = 1.0 / SUPERSAMPLE
    for sy in range(SUPERSAMPLE):
        for sx in range(SUPERSAMPLE):
            x = cx + (sx + 0.5) * step
            y = cy + (sy + 0.5) * step
            d = ((ox - x) ** 2 + (oy - y) ** 2) ** 0.5
            if inner <= d <= outer:
                hits += 1
    return hits / (SUPERSAMPLE * SUPERSAMPLE)


def tile(inner, outer, size=SIZE, centred=False):
    """Rows top-to-bottom of alpha bytes.

    The corner tiles put the arc centre on the tile's bottom-right, so
    the solid part is the inside of the card. The discs put it in the
    middle of the tile, so the shape is a whole circle.
    """
    ox = oy = size / 2.0 if centred else float(size)
    return [
        [int(coverage(x, y, inner, outer, ox, oy) * 255 + 0.5) for x in range(size)]
        for y in range(size)
    ]


def write_tga(path, rows):
    """Uncompressed 32-bit BGRA, origin bottom-left.

    Hand-rolled rather than via PIL so the byte layout is not at the
    mercy of a library default: WoW wants uncompressed, and PIL's TGA
    writer has shipped RLE by default in some versions.
    """
    size = len(rows)
    header = struct.pack(
        "<BBBHHBHHHHBB",
        0,        # no image id
        0,        # no colour map
        2,        # uncompressed true-colour
        0, 0, 0,  # colour map spec
        0, 0,     # origin
        size, size,
        32,       # bits per pixel
        8,        # 8 alpha bits, origin bottom-left
    )
    body = bytearray()
    # Bottom-left origin means the last row of the image goes first.
    for row in reversed(rows):
        for a in row:
            body += bytes((255, 255, 255, a))  # B, G, R, A
    with open(path, "wb") as fh:
        fh.write(header)
        fh.write(body)
    print("wrote %s (%d bytes)" % (path, 18 + len(body)))


def main():
    media = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Media")
    write_tga(os.path.join(media, "RoundFill.tga"), tile(0, SIZE))
    write_tga(os.path.join(media, "RoundEdge.tga"), tile(SIZE - EDGE_PX, SIZE))

    # A hair under half, so the disc's own antialiased edge finishes
    # inside the tile instead of being clipped flat by it.
    r = CIRCLE_SIZE / 2.0 - 1
    write_tga(os.path.join(media, "CircleMask.tga"),
              tile(0, r, CIRCLE_SIZE, centred=True))
    write_tga(os.path.join(media, "CircleRing.tga"),
              tile(r - CIRCLE_RIM_PX, r, CIRCLE_SIZE, centred=True))
    print("rim is %.1f%% of the radius" % (100.0 * CIRCLE_RIM_PX / r))


if __name__ == "__main__":
    main()
