"""Cut the delve companion banner from a screenshot of the Journeys panel.

Source of truth is Art/companion-banner-master.jpg -- a full-resolution
WoW screenshot with the Journeys panel open on the companion row. The
crop rectangle below is measured against 2560x1440; a screenshot at
another resolution needs BOUNDS re-measured, which is why they are named
constants rather than buried in the cut.

Output:

  * Media/CompanionBanner.tga (512x128, uncompressed 32-bit)

ONE texture, drawn at its native 341x103 and never stretched.

It was three slices for several cuts -- two caps at native width and a
stretched middle -- so the card could be any width. That bought nothing
and cost a great deal: the middle had the companion's name baked into
it, so it had to be rebuilt from sampled columns, which flattened the
banner's mottled gold into a smear; and every slice boundary was a seam
that needed edge padding to stop the GPU sampling into its neighbour.

Fixing the width at the art's own size makes all of that go away. The
name stays baked because nothing stretches it, the texture is used
exactly as photographed, and there are no internal edges to bleed. The
consequence is that this file is Valeera specifically -- but it always
was, because the portrait is in it too.

The corners are cut to transparent. The frame is a rounded rectangle
photographed on the Journeys panel's dark background, so a rectangular
crop brings four black triangles with it -- which read as chipped
corners against any surface that is not that same black. They are
removed by flooding inward from each corner over dark pixels, bounded to
a box at each corner -- the gold bevel is NOT a closed curve, and an
unbounded flood walks through a notch in the chevron ornaments and empties
the frame's whole dark interior.

Run:  python Tools/make_companion_banner.py
"""

from PIL import Image
from collections import deque
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "Art", "companion-banner-master.jpg")
OUT = os.path.join(ROOT, "Media", "CompanionBanner.tga")

# Measured against a 2560x1440 screenshot: the frame's outer edges.
#
# These were wrong once in a way worth recording: the first cut took
# 542..618 and 305..634, which is the frame's INNER lit area. That
# dropped the entire bottom border and sliced both chevron ornaments in
# half, and it looked plausible in isolation because what is left is
# still a rectangle of banner. The giveaway is that the top border was
# present and the bottom was not -- a frame is symmetrical, so a crop
# that keeps one and loses the other is a crop, not the art.
LEFT, TOP, RIGHT, BOTTOM = 297, 540, 638, 643

# A pixel is "background" below this luminance. The panel behind the
# banner sits near 20; the gold bevel that has to stop the flood runs
# well above 90 all the way round.
DARK = 60

# How far in from each corner the flood may reach. The rounding is about
# a dozen pixels; this is generous enough to clear it and far short of
# anything the frame needs to keep.
CORNER = 26

CANVAS = (512, 128)


def cut_corners(im):
    """Flood transparent inward from each corner over dark pixels.

    A flood rather than a drawn rounded-rectangle mask: the corner radius
    and the bevel's exact profile are the art's, not numbers worth
    guessing at, and a mask a pixel off either shaves the gold or leaves
    a black rind. The flood finds the real boundary because the boundary
    is what stops it.

    Each flood is confined to a CORNER-sized box. Unbounded, it does not
    stay outside the frame: the chevron ornaments have notches cut into
    them, and the dark inside a notch joins the dark outside the banner,
    so the fill walks through and empties the frame's whole dark interior
    -- 79% of the image on the first attempt. The gold is not a closed
    curve, so it cannot be relied on as a wall; the box is the wall.

    Returns the number of pixels cleared, so a run that quietly clears
    nothing -- or far too much -- is visible instead of silent.
    """
    px = im.load()
    w, h = im.size
    seen = [[False] * h for _ in range(w)]
    cleared = 0

    for cx, cy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        x0, x1 = (0, CORNER) if cx == 0 else (w - CORNER, w)
        y0, y1 = (0, CORNER) if cy == 0 else (h - CORNER, h)
        q = deque([(cx, cy)])
        while q:
            x, y = q.popleft()
            if x < x0 or y < y0 or x >= x1 or y >= y1 or seen[x][y]:
                continue
            seen[x][y] = True
            r, g, b, _ = px[x, y]
            # Rec. 601 luma; the bevel is yellow, which a plain average
            # would under-weight enough to leak through in places.
            if (0.299 * r + 0.587 * g + 0.114 * b) >= DARK:
                continue
            px[x, y] = (r, g, b, 0)
            cleared += 1
            q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))

    return cleared


def main():
    if not os.path.exists(SRC):
        sys.exit("No master at %s -- drop a 2560x1440 screenshot of the "
                 "Journeys panel there and re-run." % SRC)

    im = Image.open(SRC).convert("RGBA")
    if im.size != (2560, 1440):
        # Not fatal, but the bounds above are pixel measurements against
        # one resolution and will land somewhere arbitrary on another.
        print("warning: master is %dx%d, bounds were measured on 2560x1440"
              % im.size)

    banner = im.crop((LEFT, TOP, RIGHT, BOTTOM)).copy()
    w, h = banner.size
    cleared = cut_corners(banner)

    # A sanity range, not a precise expectation. Four corners of this
    # radius come to a few hundred pixels; thousands means the flood got
    # into the frame and ate the banner, and zero means DARK is below the
    # background and it never started.
    total = w * h
    if cleared == 0:
        print("warning: no corner pixels cleared -- DARK may be too low")
    elif cleared > total * 0.15:
        print("warning: cleared %d of %d pixels (%.0f%%) -- the flood likely "
              "escaped into the frame" % (cleared, total, 100.0 * cleared / total))

    sheet = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    sheet.paste(banner, (0, 0))
    sheet.save(OUT, "TGA", compression=None)

    cw, ch = CANVAS
    print("wrote %s (%dx%d, %d bytes)" % (OUT, cw, ch, os.path.getsize(OUT)))
    print("  banner %dx%d, %d corner pixels cleared" % (w, h, cleared))
    print("  SetTexCoord(0, %.6f, 0, %.6f)" % (w / float(cw), h / float(ch)))


if __name__ == "__main__":
    main()
