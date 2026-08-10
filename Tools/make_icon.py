"""Build the YippYapp Helper icon set from the painted master.

Source of truth is Art/icon-master.png — the hand-painted compass rose,
background already removed. Everything else is derived from it, so a new
master is the only thing needed to re-cut the whole set.

Two outputs:

  * Media/YippYappHelper.tga (128px) - full bleed, used everywhere in
    game. The mark touches all four edges, so each caller controls how
    much air it gets purely by sizing its own box. An earlier cut carried
    a built-in margin for the inline icons, but once those boxes grew to
    32px the padding just made the mark look small, so the callers own
    the spacing now. Note this only works on the minimap because
    MinimapButton.lua overrides LibDBIcon's 5% texcoord crop - crop plus
    full bleed would slice the octagon's flat edges off.
  * curseforge-icon.png (512px) - 4% margin, since a project avatar sits
    on a card and wants a little air around it.

Run:  python Tools/make_icon.py
"""

from PIL import Image
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MASTER = os.path.join(ROOT, "Art", "icon-master.png")


def squared(im):
    """Trim to the painted pixels, then centre on a square canvas.

    Padding rather than stretching: the master is about 2% taller than it
    is wide (generation drift), and squashing it to fit would tilt the
    octagon's flat edges just enough to notice against the round ring.
    """
    im = im.convert("RGBA")
    im = im.crop(im.getchannel("A").getbbox())
    side = max(im.size)
    out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    out.paste(im, ((side - im.width) // 2, (side - im.height) // 2), im)
    return out


def with_margin(im, fraction):
    side = int(max(im.size) / (1 - fraction * 2))
    out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    out.paste(im, ((side - im.width) // 2, (side - im.height) // 2), im)
    return out


def main():
    if not os.path.exists(MASTER):
        raise SystemExit(f"missing master art: {MASTER}")

    base = squared(Image.open(MASTER))

    out_tga = os.path.join(ROOT, "Media", "YippYappHelper.tga")
    base.resize((128, 128), Image.LANCZOS).save(out_tga, "TGA", compression=None)

    out_png = os.path.join(ROOT, "curseforge-icon.png")
    with_margin(base, 0.04).resize((512, 512), Image.LANCZOS).save(out_png, "PNG")

    for p in (out_tga, out_png):
        print(f"{os.path.relpath(p, ROOT):40} {os.path.getsize(p) / 1024:7.1f} KB")


if __name__ == "__main__":
    main()
