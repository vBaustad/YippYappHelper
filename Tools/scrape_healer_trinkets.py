#!/usr/bin/env python3
"""
Regenerate Features/Trinkets/TrinketDataHealer.lua from a QE Live capture.

Usage:
    python Tools/scrape_healer_trinkets.py
    python Tools/scrape_healer_trinkets.py --dry-run
    python Tools/scrape_healer_trinkets.py --in Tools/qe_capture.json

bloodmallet does not publish healers -- it sims damage, and a healer's
trinket question is not a DPS question -- so Tools/scrape_trinkets.py
comes back empty for all seven healer specs and always will. QE Live
(questionablyepic.com/live/trinkets) is the healer equivalent: same
question, HPS instead of DPS, and it covers every healing spec.

There is nothing to fetch. QE Live computes each chart in the browser
from the player held in React state, so this script does not scrape the
site -- Tools/qe_capture.js drives the page and writes out the numbers,
and this turns that capture into Lua. Recapture first, then run this.

Why a separate Lua file rather than more blocks in TrinketData.lua: that
file is overwritten wholesale by the bloodmallet scrape, which reads back
only the fields it writes. Healer blocks living there would lose their
provider and scale markers on the next bloodmallet run and then be read
as bloodmallet percentages, which they are not. Separate files, one
owner each, and the addon merges them at load.

Two things the emitted blocks carry that bloodmallet's do not:

    provider = "qe"      so the UI can name the right source, and not
                         tell a Holy Priest that bloodmallet has not
                         simmed them yet -- bloodmallet never will.
    scale    = "score"   the curve holds QE's HPS-equivalent score, not
                         bloodmallet's percent gain over an empty slot.
                         Ranking is the same either way, but the
                         percent-behind arithmetic is not, so the reader
                         has to know which it is holding.

Raid maps onto the ST style key and Dungeon onto AOE. Those keys mean
"target count" for a DPS spec and "content" for a healer, which is a real
mismatch -- but it is the mapping that keeps the loot council view whole.
The council index is built per style, so healers filed under their own
keys would simply not appear beside the DPS specs rolling on the same
trinket, which is the entire point of that page. The UI relabels the
tabs when the spec on screen is a healer.
"""

import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IN_PATH = os.path.join(ROOT, "Tools", "qe_capture.json")
OUT_PATH = os.path.join(ROOT, "Features", "Trinkets", "TrinketDataHealer.lua")
TIER_FROM = os.path.join(ROOT, "Features", "Trinkets", "TrinketData.lua")

SPEC_KEY = {
    "Restoration Druid":   "DRUID_RESTORATION",
    "Preservation Evoker": "EVOKER_PRESERVATION",
    "Mistweaver Monk":     "MONK_MISTWEAVER",
    "Holy Paladin":        "PALADIN_HOLY",
    "Discipline Priest":   "PRIEST_DISCIPLINE",
    "Holy Priest":         "PRIEST_HOLY",
    "Restoration Shaman":  "SHAMAN_RESTORATION",
}

# QE's content axis, expressed in the style keys the rest of the addon
# already indexes by. See the module docstring for why they share.
STYLE_KEY = {"Raid": "ST", "Dungeon": "AOE"}
STYLE_ORDER = ["ST", "AOE"]

# QE writes where a trinket drops as prose ("Venomous Abyss (Raid) -
# Nek'zali"). The index filters on bloodmallet's one-word vocabulary, so
# the prose is reduced to that. Delves get their own word rather than
# being forced into one of bloodmallet's: they are current content, but
# they are not what a loot council hands out, and the council filter is
# allowed to tell the difference.
def classify_source(drop):
    if not drop:
        return None
    if "(Raid)" in drop:
        return "Raid"
    if "(Dungeon)" in drop:
        return "Dungeon"
    if "Delve" in drop:
        return "Delve"
    return None


def target_tier(path):
    """The tier the addon considers current, so healer blocks age out too.

    Written as a literal rather than read from ns.TRINKET_TARGET_TIER at
    load: a capture is a snapshot of one season, and a file that always
    claims to be current would go on claiming it after the season flips.
    """
    try:
        with open(path, encoding="utf-8") as f:
            m = re.search(r'^ns\.TRINKET_TARGET_TIER = "([^"]*)"', f.read(), re.M)
        return m.group(1) if m else None
    except OSError:
        return None


def lua_str(s):
    if s is None:
        return "nil"
    s = str(s).replace("\\", "\\\\").replace('"', '\\"')
    return '"%s"' % s.replace("\r", "").replace("\n", "\\n")


def condense(block, items, pool):
    """One spec/content chart, in the shape TrinketIndex reads."""
    rows, curve, source, steps = [], {}, {}, set()

    top = max(r[2] for r in block["r"])
    for iid, at, val, _lo, ci in block["r"]:
        meta = items.get(str(iid)) or items.get(iid)
        name, hi, drop = meta if meta else ("item:%d" % iid, at, "")
        src = classify_source(drop)
        row = {
            "id": iid,
            # Each trinket at its own ceiling, which is what the chart
            # ranks by -- a delve trinket stopping at 321 is not being
            # compared against a raid drop at 344 as though they were
            # the same item level.
            "ilvl": at,
            # `lo` says "this has an upgrade ladder in current content",
            # which is how the browse list separates this season's
            # trinkets from ones still being simmed out of older ones.
            # QE sims everything from 272 up, ladder or not, so its
            # lowest step proves nothing -- the drop label does. Left
            # off entirely when QE does not say where the item comes
            # from, rather than guessed at from the item level.
            "lo": _lo if src else None,
            "rel": round((val - top) / float(top) * 100.0, 2),
            "name": name,
        }
        rows.append(row)
        if src:
            source[iid] = src
        if ci >= 0:
            points = {}
            for lvl, v in zip(block["L"], pool[ci]):
                if v >= 0:
                    points[lvl] = v
            if points:
                curve[iid] = points
                steps.update(points)

    return {
        "ilvl": max(r["ilvl"] for r in rows),
        "rows": rows,
        "curve": curve,
        "steps": sorted(steps),
        "source": source,
        "playstyle": block.get("p"),
        "profile": block["c"],
    }


def emit(specs, meta):
    L = []
    add = L.append
    add("local _, ns = ...")
    add("")
    add("---" + "-" * 57)
    add("-- Healer trinket rankings, from QE Live (questionablyepic.com).")
    add("--")
    add("-- GENERATED FILE — do not hand-edit.")
    add("-- Regenerate with:  python Tools/scrape_healer_trinkets.py")
    add("--")
    add("-- bloodmallet sims damage and publishes no healer charts, so the")
    add("-- seven healing specs come from QE Live instead. Merged into the")
    add("-- same ns.TrinketData table, and kept in a separate file only")
    add("-- because the bloodmallet scrape rewrites its own file whole.")
    add("--")
    add("-- QE splits by content rather than by target count, so its Raid")
    add("-- chart is filed under ST and its Dungeon chart under AOE. The")
    add("-- blocks say so in `profile`, and the UI relabels the tabs for a")
    add("-- healer rather than claiming these are target counts.")
    add("--")
    add("-- `curve` holds QE's HPS-equivalent score per item level, NOT")
    add("-- bloodmallet's percent gain over an empty slot -- `scale` marks")
    add("-- which, because the two rank alike but subtract differently.")
    add("---" + "-" * 57)
    add("")
    add("ns.TrinketData = ns.TrinketData or {}")
    add("ns.TRINKET_HEALER_SOURCE = %s" % lua_str("questionablyepic.com"))
    add("ns.TRINKET_HEALER_SCRAPED_AT = %s" % lua_str(meta["captured"]))
    add("")

    for key in sorted(specs):
        styles = specs[key]
        add('ns.TrinketData["%s"] = {' % key)
        for skey in [s for s in STYLE_ORDER if s in styles]:
            b = styles[skey]
            add("    %s = {" % skey)
            add("        provider = %s," % lua_str("qe"))
            add("        profile = %s," % lua_str(b["profile"]))
            add("        playstyle = %s," % lua_str(b["playstyle"]))
            add("        scale = %s," % lua_str("score"))
            add("        ilvl = %d," % b["ilvl"])
            add("        timestamp = %s," % lua_str(meta["captured"]))
            add("        tier = %s," % lua_str(meta["tier"]))
            if b["steps"] and b["curve"]:
                add("        steps = { %s },"
                    % ", ".join(str(s) for s in b["steps"]))
                add("        curve = {")
                for r in b["rows"]:
                    points = b["curve"].get(r["id"])
                    if not points:
                        continue
                    add("            [%d] = { %s }," % (r["id"], ", ".join(
                        "[%d]=%d" % (s, points[s]) for s in sorted(points))))
                add("        },")
            if b["source"]:
                add("        source = { %s }," % ", ".join(
                    "[%d]=%s" % (i, lua_str(b["source"][i]))
                    for i in sorted(b["source"])))
            add("        list = {")
            for r in b["rows"]:
                lo = ("lo = %d, " % r["lo"]) if r.get("lo") else ""
                add('            { id = %-8s ilvl = %d, %srel = %6.2f, name = %s },'
                    % (str(r["id"]) + ",", r["ilvl"], lo, r["rel"],
                       lua_str(r["name"])))
            add("        },")
            add("    },")
        add("}")
        add("")
    return "\n".join(L) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="src", default=IN_PATH)
    ap.add_argument("--out", default=OUT_PATH)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    with open(args.src, encoding="utf-8") as f:
        cap = json.load(f)

    tier = target_tier(TIER_FROM)
    meta = {"captured": cap.get("captured"), "tier": tier}

    specs, unknown = {}, []
    for block in cap["blocks"]:
        key = SPEC_KEY.get(block["s"])
        style = STYLE_KEY.get(block["c"])
        if not key or not style:
            unknown.append("%s/%s" % (block["s"], block["c"]))
            continue
        specs.setdefault(key, {})[style] = condense(block, cap["items"],
                                                    cap["pool"])

    for key in sorted(specs):
        print("%-24s %s" % (key, "  ".join(
            "%s(%s):%d trinkets @%d" % (s, b["profile"], len(b["rows"]), b["ilvl"])
            for s, b in sorted(specs[key].items()))))
    print("\n%d specs, captured %s, tagged tier=%s"
          % (len(specs), meta["captured"], tier))
    if unknown:
        print("skipped, not a spec/content this script knows: "
              + ", ".join(unknown), file=sys.stderr)

    missing = sorted(set(SPEC_KEY.values()) - set(specs))
    if missing:
        print("no data captured for: " + ", ".join(missing), file=sys.stderr)

    if args.dry_run:
        return 0
    if not specs:
        print("nothing to write", file=sys.stderr)
        return 1

    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        f.write(emit(specs, meta))
    print("wrote %s" % args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
