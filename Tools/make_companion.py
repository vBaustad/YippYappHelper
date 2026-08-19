"""Cut the delve companion's portrait from a painted or captured master.

Source of truth is Art/companion-master.png -- whatever you drop there,
at whatever size. Everything else is derived, so replacing the master and
re-running is the whole workflow.

Output:

  * Media/CompanionValeera.tga (128px square, uncompressed 32-bit)

Square and unmasked on purpose. The card applies Blizzard's circular
mask at runtime, the same one the window's own sign uses, so baking a
circle into the file would mask it twice -- and the second one always
lands a pixel off the first, which shows up as a hairline of background
around the rim.

128px for a 62px medallion: WoW does not mipmap addon textures well, and
a file cut to its display size goes soft the moment the player runs the
UI at any scale above 1. It is 64KB, which is not worth economising.

The crop is top-weighted rather than centred. A portrait master is
usually a head on a body, so the centre of the image is the chest -- a
centred square crop reliably cuts the face in half. --focus moves it.

Run:  python Tools/make_companion.py
      python Tools/make_companion.py --focus 0.5 --src Art/other.png
"""

from PIL import Image
import argparse
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SRC = os.path.join(ROOT, "Art", "companion-master.png")
OUT = os.path.join(ROOT, "Media", "CompanionValeera.tga")
SIZE = 128


def trimmed(im):
    """Drop fully transparent margins, if there are any.

    Guarded on the alpha channel actually varying: a fully opaque image
    has a bounding box equal to itself, and a fully transparent one has
    none at all -- getbbox returns None there, and cropping to None
    raises rather than no-ops.
    """
    im = im.convert("RGBA")
    box = im.getchannel("A").getbbox()
    if box and box != (0, 0, im.width, im.height):
        im = im.crop(box)
    return im


def squared(im, focus):
    """Centre-crop to a square, biased vertically by `focus`.

    focus is where the crop's centre sits down the image: 0.0 is the top
    edge, 1.0 the bottom. The default of 0.38 puts a head roughly in the
    middle of the square for a typical waist-up portrait.

    A portrait narrower than it is tall is cropped vertically and a wide
    one horizontally, so this works on a screenshot and on a tall piece
    of splash art without being told which it got.
    """
    side = min(im.size)

    if im.height > side:
        top = int((im.height - side) * focus)
        top = max(0, min(top, im.height - side))
        return im.crop((0, top, side, top + side))

    if im.width > side:
        left = (im.width - side) // 2
        return im.crop((left, 0, left + side, side))

    return im


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=DEFAULT_SRC)
    ap.add_argument("--focus", type=float, default=0.38,
                    help="0.0 crops from the top, 1.0 from the bottom")
    args = ap.parse_args()

    if not os.path.exists(args.src):
        # Named explicitly rather than "file not found": the whole point
        # of this script is that the master is the one thing a person has
        # to supply, so the error should say where to put it.
        sys.exit("No master at %s -- drop the image there and re-run." % args.src)

    im = squared(trimmed(Image.open(args.src)), args.focus)
    im = im.resize((SIZE, SIZE), Image.LANCZOS)

    # compression=None to match the rest of Media/. WoW reads run-length
    # encoded TGA inconsistently across texture sizes, and every other
    # file here is uncompressed, so the folder stays one format.
    im.save(OUT, "TGA", compression=None)
    print("wrote %s (%dx%d, %d bytes)"
          % (OUT, SIZE, SIZE, os.path.getsize(OUT)))


if __name__ == "__main__":
    main()
