"""Draw the addon's pages to a PNG, without the game.

The load harness has always known where everything is -- it computes the
whole layout to assert that boxes do not overlap -- but it never drew
it, so every question of the form "is that text too small, and is it in
the wrong place" had to be answered by a person taking a screenshot in
WoW and sending it over. This turns that round trip into a command.

STATUS: HALF FINISHED, AND HONEST ABOUT WHICH HALF.

WORKS. Anything sized explicitly or anchored to something that is: the
whole left rail (boss list, instance headings, role and difficulty
toggles, the Bloodlust row), and every widget's shown/hidden state. It
correctly shows the trainer button absent, which is a real fact about
the page and exactly the kind of thing a screenshot round trip was being
spent on.

DOES NOT WORK YET. The reading column's widths. A guide card resolves to
168px where the game gives it about 770, because the stub in
loadcheck.py only approximates width propagation -- it was written to
answer "do these two boxes overlap", which needs relative positions, not
"how wide is this", which needs a real layout pass. Everything inside
those cards then wraps to a sliver and piles up. Do not read the right
half of the picture as the truth.

Finishing it means making the stub a genuine two-pass layout engine
(resolve widths down the tree, then heights back up). That is a real
piece of work rather than a polish pass, and it is worth doing only if
the left-hand half keeps paying for itself.

It can never tell you a MECHANIC is wrong. Only somebody watching the
real fight can do that.

    python Tools/render.py                       -- the boss guide, default boss
    python Tools/render.py --boss sentinels      -- a specific boss
    python Tools/render.py --boss sszorak --page 2 --role TANK
    python Tools/render.py --out C:/tmp/page.png
"""

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image, ImageDraw, ImageFont     # noqa: E402
import profile as P                             # noqa: E402

SCREEN_W, SCREEN_H = 1000, 900
UNIT = "\x1f"       # between fields
REC = "\x1e"        # between regions
PT = "\x1d"         # between anchor points

# Anchor point -> fraction of the rect, x and y. y counts DOWN here: this
# is a picture, not WoW's bottom-left origin, and converting once at the
# boundary is far less error-prone than carrying two conventions.
FX = {"LEFT": 0.0, "RIGHT": 1.0, "CENTER": 0.5}
FY = {"TOP": 0.0, "BOTTOM": 1.0, "CENTER": 0.5}


def frac(point, table, default=0.5):
    """The x or y fraction named by an anchor like TOPLEFT."""
    if not point:
        return default
    point = point.upper()
    for key, value in table.items():
        if key in point:
            return value
    return default


DUMP = """
function(maxN)
    local out = {}
    for i = 1, math.min(#_REGIONS, maxN) do
        local r = _REGIONS[i]
        local pts = {}
        for _, p in ipairs(r._pts or {}) do
            pts[#pts + 1] = table.concat({
                tostring(p.p or ""), tostring(p.relP or ""),
                tostring((p.rel and p.rel.__rid) or ""),
                tostring(p.x or 0), tostring(p.y or 0) }, ",")
        end
        local function rgb(c)
            if not c then return "" end
            return string.format("%.3f,%.3f,%.3f,%.3f",
                c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1)
        end
        out[#out + 1] = table.concat({
            tostring(r.__rid or 0),
            tostring(r._type or "Frame"),
            tostring((r._parent and r._parent.__rid) or ""),
            (r._shown == false) and "0" or "1",
            tostring(r.GetWidth and r:GetWidth() or r._w or ""),
            tostring(r._h or (r._type == "FontString" and 12) or ""),
            tostring(r._lvl or 1),
            (r._text or ""):gsub("[\\30\\31\\29]", " "),
            rgb(r._rgba), rgb(r._textRGBA),
            tostring((r._all and r._all.__rid) or ""),
            table.concat(pts, "\\29"),
        }, "\\31")
    end
    return table.concat(out, "\\30")
end
"""


class Region(object):
    __slots__ = ("id", "kind", "parent", "shown", "w", "h", "level",
                 "text", "rgba", "trgba", "allpoints", "points", "rect")

    def __init__(self, blob):
        f = blob.split(UNIT)
        f += [""] * (12 - len(f))
        self.id = int(f[0] or 0)
        self.kind = f[1]
        self.parent = int(f[2]) if f[2] else None
        self.shown = f[3] == "1"
        self.w = float(f[4]) if f[4] else None
        self.h = float(f[5]) if f[5] else None
        self.level = int(float(f[6] or 1))
        self.text = f[7]
        self.rgba = tuple(float(v) for v in f[8].split(",")) if f[8] else None
        self.trgba = tuple(float(v) for v in f[9].split(",")) if f[9] else None
        self.allpoints = int(f[10]) if f[10] else None
        self.points = []
        for chunk in (f[11].split(PT) if f[11] else []):
            if not chunk:
                continue
            p, relp, rel, x, y = (chunk.split(",") + [""] * 5)[:5]
            self.points.append({
                "p": p, "relp": relp or p,
                "rel": int(rel) if rel else None,
                "x": float(x or 0), "y": float(y or 0),
            })
        self.rect = None


def solve(regions):
    """Absolute rects, in a top-left origin with y increasing downward."""
    solving = set()

    def rect_of(rid):
        if rid is None:
            return (0.0, 0.0, float(SCREEN_W), float(SCREEN_H))
        r = regions.get(rid)
        if r is None:
            return (0.0, 0.0, float(SCREEN_W), float(SCREEN_H))
        if r.rect is not None:
            return r.rect
        if rid in solving:
            # A cycle. Anchoring two things to each other is legal in WoW
            # and unresolvable here; the screen is a better answer than a
            # crash or an infinite descent.
            return (0.0, 0.0, float(SCREEN_W), float(SCREEN_H))
        solving.add(rid)
        r.rect = _solve_one(r, rect_of)
        solving.discard(rid)
        return r.rect

    def _solve_one(r, rect_of):
        if r.allpoints is not None or (not r.points and r.parent is not None
                                       and r.w is None and r.h is None):
            return rect_of(r.allpoints if r.allpoints is not None else r.parent)

        w, h = r.w, r.h
        # Two opposing horizontal anchors give a width; same vertically.
        if w is None and len(r.points) >= 2:
            xs = []
            for p in r.points:
                pl, pt_, pw, ph = rect_of(p["rel"] if p["rel"] is not None else r.parent)
                xs.append((frac(p["p"], FX), pl + frac(p["relp"], FX) * pw + p["x"]))
            xs.sort()
            if xs[-1][0] - xs[0][0] > 0.01:
                w = (xs[-1][1] - xs[0][1]) / (xs[-1][0] - xs[0][0])
        if h is None and len(r.points) >= 2:
            ys = []
            for p in r.points:
                pl, pt_, pw, ph = rect_of(p["rel"] if p["rel"] is not None else r.parent)
                ys.append((frac(p["p"], FY), pt_ + frac(p["relp"], FY) * ph - p["y"]))
            ys.sort()
            if ys[-1][0] - ys[0][0] > 0.01:
                h = (ys[-1][1] - ys[0][1]) / (ys[-1][0] - ys[0][0])

        if w is None:
            w = 8.0 * max(len(strip_colour(r.text)), 1) if r.kind == "FontString" else 0.0
        if h is None:
            h = 12.0 if r.kind == "FontString" else 0.0

        if not r.points:
            pl, pt_, pw, ph = rect_of(r.parent)
            return (pl, pt_, w, h)

        p = r.points[0]
        pl, pt_, pw, ph = rect_of(p["rel"] if p["rel"] is not None else r.parent)
        ax = pl + frac(p["relp"], FX) * pw + p["x"]
        # y is negative-downward in WoW, positive-downward here.
        ay = pt_ + frac(p["relp"], FY) * ph - p["y"]
        return (ax - frac(p["p"], FX) * w, ay - frac(p["p"], FY) * h, w, h)

    for rid in list(regions):
        rect_of(rid)
    return regions


def visible(r, regions):
    """Shown, and every ancestor shown too.

    A region defaults to shown in the stub, and the addon builds every
    page up front and hides the ones it is not on -- so asking only about
    the region itself drew the whole addon on top of itself, every tab at
    once. Visibility is a property of the CHAIN.

    Walked fresh each time rather than cached: a thousand regions is
    nothing, and the cached version was wrong in both directions at once.
    """
    node, guard = r, 0
    while node is not None and guard < 64:
        if not node.shown:
            return False
        node = regions.get(node.parent) if node.parent else None
        guard += 1
    return True


def wrap(text, width, font):
    """Break a string to fit a pixel width, as the client would."""
    if width < 12:
        return [text]
    out, cur = [], ""
    for word in text.split():
        trial = (cur + " " + word).strip()
        if font.getlength(trial) > width and cur:
            out.append(cur)
            cur = word
        else:
            cur = trial
    if cur:
        out.append(cur)
    return out or [text]


def strip_colour(text):
    return re.sub(r"\|c%s|\|r" % "[0-9a-fA-F]{8}", "", text or "")


def first_colour(text):
    m = re.search(r"\|c[0-9a-fA-F]{2}([0-9a-fA-F]{6})", text or "")
    if not m:
        return None
    v = m.group(1)
    return (int(v[0:2], 16) / 255, int(v[2:4], 16) / 255, int(v[4:6], 16) / 255, 1)


def to255(c, fallback=(210, 210, 215)):
    if not c:
        return fallback
    return tuple(max(0, min(255, int(round(v * 255)))) for v in c[:3])


def draw(regions, out_path, title):
    img = Image.new("RGB", (SCREEN_W, SCREEN_H), (24, 24, 28))
    d = ImageDraw.Draw(img, "RGBA")
    try:
        font = ImageFont.load_default(size=12)
        small = ImageFont.load_default(size=10)
    except TypeError:                      # very old Pillow
        font = small = ImageFont.load_default()

    # Painter's order: frame level, then creation order, so a thing made
    # later and parented deeper lands on top -- which is what the client
    # does and what makes a background read as a background.
    ordered = sorted((r for r in regions.values() if visible(r, regions)),
                     key=lambda r: (r.level, r.id))
    for r in ordered:
        x, y, w, h = r.rect
        if w < 1 or h < 1:
            if r.kind != "FontString":
                continue
        if x > SCREEN_W or y > SCREEN_H or x + w < 0 or y + h < 0:
            continue

        if r.kind == "FontString":
            text = strip_colour(r.text)
            if not text.strip():
                continue
            col = to255(r.trgba or first_colour(r.text), (215, 215, 220))
            # Wrapped to the region's own width, because "does this fit"
            # is most of what this tool exists to answer. Unwrapped, a
            # bullet that overflows its card by 200px looks identical to
            # one that fits, which is the single question worth asking.
            lines = wrap(text, w, font) if w >= 40 else [text]
            for k, line in enumerate(lines):
                d.text((x, y + k * 13), line, fill=col, font=font)
        elif r.kind in ("Texture", "MaskTexture"):
            if r.rgba:
                col = to255(r.rgba)
                alpha = int(max(0.0, min(1.0, r.rgba[3] if len(r.rgba) > 3 else 1)) * 255)
                d.rectangle([x, y, x + w, y + h], fill=col + (alpha,))
        else:
            d.rectangle([x, y, x + w, y + h], outline=(70, 70, 80), width=1)

    d.rectangle([0, 0, SCREEN_W - 1, 22], fill=(14, 14, 16))
    d.text((8, 5), title, fill=(150, 200, 255), font=small)
    img.save(out_path)
    return out_path


def render_guide(boss, page, role, heroic, out_path):
    L, ns, _ = P.build(track_regions=True, stub_anchors=False)
    L.execute("PAGE_W, PAGE_H = %d, %d" % (SCREEN_W, SCREEN_H - 30))
    setup = L.eval("""
        function(ns, bossId, page, role, heroic)
            YippYappHelperDB = YippYappHelperDB or {}
            YippYappHelperDB.raidGuide = {
                boss = bossId, role = role, heroic = heroic and true or false,
            }
            local UI = ns.RaidGuideUI
            if not (UI and UI.BuildInto) then return "no guide UI" end

            -- Mount it into a frame of a known size. Nothing in this
            -- process has clicked anything, so the page has never been
            -- built -- and a renderer that faithfully draws an unmounted
            -- page draws an empty screen, which looks exactly like a
            -- broken solver and took a while to tell apart.
            local host = CreateFrame("Frame", nil, UIParent)
            host:SetSize(PAGE_W, PAGE_H)
            host:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
            host:Show()
            UI:BuildInto(host)
            UI:Refresh()
            UI:SetPage(page)
            -- Open it. The harness never clicks anything, so the app
            -- frame and every page above this one are still hidden --
            -- and a renderer that honours visibility correctly draws an
            -- empty screen, which looks exactly like a broken solver.
            local node, guard = UI._host, 0
            while node and guard < 64 do
                if node.Show then node:Show() end
                node = node.GetParent and node:GetParent() or nil
                guard = guard + 1
            end
            return "ok"
        end
    """)(ns, boss, page, role, heroic)
    if str(setup) != "ok":
        raise SystemExit("could not open the guide: %s" % setup)

    blob = str(L.eval(DUMP)(200000))
    regions = {}
    for rec in blob.split(REC):
        if not rec:
            continue
        r = Region(rec)
        regions[r.id] = r
    solve(regions)
    title = "Boss Guide  --  %s  --  page %d  --  %s  --  %s" % (
        boss, page, role, "Heroic" if heroic else "Normal")
    return draw(regions, out_path, title), len(regions)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--boss", default="soulcoiler")
    ap.add_argument("--page", type=int, default=1)
    ap.add_argument("--role", default="DAMAGER")
    ap.add_argument("--heroic", action="store_true")
    ap.add_argument("--out", default=os.path.join(P.LC.ROOT, "Tools", "render.png"))
    a = ap.parse_args()
    path, n = render_guide(a.boss, a.page, a.role, a.heroic, a.out)
    print("drew %d regions -> %s" % (n, path))


if __name__ == "__main__":
    main()
