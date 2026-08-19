"""Cut the delve companion banner from a screenshot of the Journeys panel.

Source of truth is Art/companion-banner-master.jpg -- a full-resolution
WoW screenshot with the Journeys panel open on the companion row. The
crop rectangle below is measured against 2560x1440; a screenshot at
another resolution needs BOUNDS re-measured, which is why they are named
constants rather than buried in the slicing.

Output:

  * Media/CompanionBanner.tga (512x128, uncompressed 32-bit)

Three slices packed into one texture, because the card is a variable
width and the banner is not:

    left  (103x103)  left chevron, frame edge, and the portrait on top
    right  (34x103)  right chevron ornament
    mid    (128x103) the flat middle, stretched between the two

The portrait is BAKED into the left slice rather than drawn separately.
It sits on top of the frame in the original, overlapping its left edge,
so there is no clean frame underneath to recover -- and the two are one
piece of art in the same sense the window medallion's ring and portrait
are. The consequence is that this file is Valeera specifically, and a
season that changes the companion needs a new cut.

The middle is a cross-fade between a column taken from each END of the
flat region rather than one column repeated. The banner is lit warmer on
the left, so a single sampled column matches one side and leaves a visible
vertical seam against the other -- which is exactly what the first cut did.

Run:  python Tools/make_companion_banner.py
"""

from PIL import Image
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "Art", "companion-banner-master.jpg")
OUT = os.path.join(ROOT, "Media", "CompanionBanner.tga")

# Measured against a 2560x1440 screenshot. Top/bottom are the frame's
# outer edges; the columns are the slice boundaries.
#
# These were wrong once in a way worth recording: the first cut took
# 542..618 and 305..634, which is the frame's INNER lit area. That
# dropped the entire bottom border and sliced both chevron ornaments in
# half, and it looked plausible in isolation because what is left is
# still a rectangle of banner. The giveaway is that the top border was
# present and the bottom was not -- a frame is symmetrical, so a crop
# that keeps one and loses the other is a crop, not the art.
TOP, BOTTOM = 540, 643        # 103 tall, both gold borders included
LEFT_0, LEFT_1 = 297, 400     # left chevron + frame edge + baked portrait
RIGHT_0, RIGHT_1 = 604, 638   # right chevron ornament
FADE_A = (400, 404)           # clean column just right of the portrait
FADE_B = (590, 594)           # clean column just left of the ornament

MID_W = 128
CANVAS = (512, 128)

# Where each slice's CONTENT starts. Each is written with PAD columns of
# its own edge pixel repeated on either side.
#
# The padding is not cosmetic. The card stretches the middle slice, so
# the GPU samples it with bilinear filtering, and at a slice's edge that
# blend reaches one texel PAST the texcoord -- into whatever sits next to
# it in the sheet. Packed tight against transparent gaps that meant every
# internal edge faded to nothing, which drew as a hard dark seam at each
# slice boundary. Repeating the edge pixel means the sample reaches into
# a copy of itself and the join disappears.
PAD = 2
PACK_LEFT_X = 2
PACK_RIGHT_X = 112
PACK_MID_X = 256


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

    h = BOTTOM - TOP
    left = im.crop((LEFT_0, TOP, LEFT_1, BOTTOM))
    right = im.crop((RIGHT_0, TOP, RIGHT_1, BOTTOM))

    a = im.crop((FADE_A[0], TOP, FADE_A[1], BOTTOM)).resize((MID_W, h), Image.LANCZOS)
    b = im.crop((FADE_B[0], TOP, FADE_B[1], BOTTOM)).resize((MID_W, h), Image.LANCZOS)

    # Blended column by column rather than with a rotated gradient mask.
    # The rotate-a-linear_gradient trick worked but ran backwards, so the
    # middle started at the RIGHT end's tone and stepped visibly against
    # the left cap -- the one seam this cross-fade exists to remove. Which
    # way rotate() takes a gradient is not worth having to remember, and
    # getting it wrong is invisible in the code and obvious on the page.
    mid = Image.new("RGBA", (MID_W, h))
    for x in range(MID_W):
        t = x / float(max(MID_W - 1, 1))
        col = Image.blend(a.crop((x, 0, x + 1, h)), b.crop((x, 0, x + 1, h)), t)
        mid.paste(col, (x, 0))

    sheet = Image.new("RGBA", CANVAS, (0, 0, 0, 0))

    def place(im_, x0):
        """Write a slice at x0, bracketed by copies of its own edge columns."""
        sheet.paste(im_, (x0, 0))
        first = im_.crop((0, 0, 1, im_.height))
        last = im_.crop((im_.width - 1, 0, im_.width, im_.height))
        for i in range(1, PAD + 1):
            sheet.paste(first, (x0 - i, 0))
            sheet.paste(last, (x0 + im_.width - 1 + i, 0))

    place(left, PACK_LEFT_X)
    place(right, PACK_RIGHT_X)
    place(mid, PACK_MID_X)
    sheet.save(OUT, "TGA", compression=None)

    # Printed so the Lua texcoords can be checked against the cut rather
    # than trusted. They are the only coupling between the two files.
    w, ch = CANVAS
    def tc(x0, x1):
        return "%.6f, %.6f, 0, %.6f" % (x0 / w, x1 / w, h / ch)
    print("wrote %s (%dx%d, %d bytes)" % (OUT, w, ch, os.path.getsize(OUT)))
    print("  LEFT  w=%d  SetTexCoord(%s)"
          % (left.width, tc(PACK_LEFT_X, PACK_LEFT_X + left.width)))
    print("  RIGHT w=%d  SetTexCoord(%s)"
          % (right.width, tc(PACK_RIGHT_X, PACK_RIGHT_X + right.width)))
    print("  MID   w=%d  SetTexCoord(%s)" % (MID_W, tc(PACK_MID_X, PACK_MID_X + MID_W)))
    print("  banner = %dx%d" % (RIGHT_1 - LEFT_0, h))


if __name__ == "__main__":
    main()
