"""Draw Yeeper, the addon's robot mascot, as a portrait icon.

Geometry rather than illustration, for the same reason as the addon icon:
it stays crisp at the ~40px the dashboard portrait uses, and it can be
regenerated after a palette change instead of re-commissioned.

Palette matches the addon mark: gold on dark purple.

Run:  python Tools/make_yeeper.py
"""

from PIL import Image, ImageDraw
import os

SS = 1024                 # supersample, downscaled at the end
C = SS / 2

PURPLE_D = (38, 22, 58, 255)
PURPLE   = (92, 52, 138, 255)
GOLD     = (245, 192, 50, 255)
GOLD_L   = (253, 222, 112, 255)
CYAN     = (120, 230, 255, 255)
BLACK    = (12, 9, 18, 255)


def rr(d, box, r, fill, outline=None, width=0):
    d.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)


def build(blink=False):
    img = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Antenna, drawn first so the head overlaps its base.
    d.rectangle([C - 18, 120, C + 18, 300], fill=BLACK)
    d.ellipse([C - 74, 40, C + 74, 188], fill=BLACK)
    d.ellipse([C - 58, 56, C + 58, 172], fill=CYAN)
    d.ellipse([C - 30, 74, C + 6, 116], fill=(255, 255, 255, 230))

    # Head
    rr(d, [140, 250, SS - 140, SS - 150], 150, BLACK)
    rr(d, [166, 276, SS - 166, SS - 176], 130, PURPLE)

    # Visor
    rr(d, [212, 360, SS - 212, 640], 90, BLACK)
    rr(d, [236, 384, SS - 236, 616], 74, PURPLE_D)

    # Eyes, matched. The pupils sit slightly high in each socket, which
    # keeps him looking attentive rather than vacant.
    #
    # The blink frame closes both to thin slots. Keeping the slots at the
    # same vertical centre as the open eyes stops the face appearing to
    # nod when the frames swap.
    if blink:
        rr(d, [300, 478, 424, 506], 14, GOLD_L)
        rr(d, [600, 478, 724, 506], 14, GOLD_L)
    else:
        for x in (300, 600):
            d.ellipse([x, 430, x + 124, 554], fill=GOLD_L)
            d.ellipse([x + 30, 460, x + 94, 524], fill=BLACK)

    # Mouth grille
    for i in range(4):
        x = 360 + i * 78
        rr(d, [x, 700, x + 46, 790], 16, BLACK)

    # Ear pods
    rr(d, [96, 470, 160, 630], 26, BLACK)
    rr(d, [110, 484, 146, 616], 18, GOLD)
    rr(d, [SS - 160, 470, SS - 96, 630], 26, BLACK)
    rr(d, [SS - 146, 484, SS - 110, 616], 18, GOLD)

    return img.resize((128, 128), Image.LANCZOS)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    # Two frames side by side: open on the left, blinking on the right.
    # One texture keeps it to a single file load, and swapping texcoords
    # is cheaper than swapping textures every few seconds.
    sheet = Image.new("RGBA", (256, 128), (0, 0, 0, 0))
    sheet.paste(build(False), (0, 0))
    sheet.paste(build(True), (128, 0))

    out = os.path.join(root, "Media", "Yeeper.tga")
    sheet.save(out, "TGA", compression=None)
    print(f"{os.path.relpath(out, root):32} {os.path.getsize(out) / 1024:7.1f} KB")


if __name__ == "__main__":
    main()
