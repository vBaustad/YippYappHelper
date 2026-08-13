#!/usr/bin/env python3
"""
Regenerate Features/Trinkets/TrinketData.lua from bloodmallet.com.

Usage:
    python Tools/scrape_trinkets.py             # write the Lua file
    python Tools/scrape_trinkets.py --dry-run
    python Tools/scrape_trinkets.py --spec PRIEST_SHADOW
    python Tools/scrape_trinkets.py --no-carry  # drop unpublished specs

Endpoint (discovered from the chart page's own XHR):
    https://bloodmallet.com/chart/get/{data_type}/{fight_style}/{class}/{spec}

Note the ordering — data type and fight style come first, then class and
spec as separate path segments. The response carries:
    sorted_data_keys : trinket names, best first
    data             : {trinket name: {item level: dps}}
    item_ids         : {trinket name: itemID}
    simc_settings    : includes `tier` (e.g. "MID1") and the simc hash
    timestamp        : when the sim was run

We keep the ranking and a single relative-value number per trinket
rather than the full item-level matrix — the matrix is ~15x the data for
information the addon never shows.

`tier` is stored so the in-game panel can say which season the sim data
is from. bloodmallet re-runs after a season flips, so a Season 1 tier
string on a Season 2 character means "this is last tier's ranking".

bloodmallet does not re-sim the whole roster at once — a new tier lands
a few specs at a time over weeks. So a plain overwrite mid-transition
deletes the specs that have not been re-run yet, trading a stale list
for no list at all, which is worse. Instead every spec/style block the
scrape did not get fresh data for is carried over from the existing
file with its old `tier` intact, and the addon flags those individually.
Pass --no-carry to overwrite rather than merge.
"""

import argparse
import gzip
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_PATH = os.path.join(ROOT, "Features", "Trinkets", "TrinketData.lua")

ENDPOINT = "https://bloodmallet.com/chart/get/{dtype}/{style}/{cls}/{spec}"

# castingpatchwerk covers every spec, casters and melee alike -- the
# plain `patchwerk`, `hecticaddcleave`, `beastlord` and dungeon styles
# all answer "No standard chart with these values found" (checked
# 2026-08-13). Extra entries here are harmless: a style with no data is
# skipped per spec, so add them back if bloodmallet starts publishing
# them.
FIGHT_STYLES = [
    ("ST",  "castingpatchwerk"),
    ("AOE", "castingpatchwerk5"),  # 5-target
]

# (addon key, bloodmallet class slug, bloodmallet spec slug)
SPECS = [
    ("DEATHKNIGHT_BLOOD",     "death_knight", "blood"),
    ("DEATHKNIGHT_FROST",     "death_knight", "frost"),
    ("DEATHKNIGHT_UNHOLY",    "death_knight", "unholy"),
    ("DEMONHUNTER_HAVOC",     "demon_hunter", "havoc"),
    ("DEMONHUNTER_VENGEANCE", "demon_hunter", "vengeance"),
    ("DEMONHUNTER_DEVOURER",  "demon_hunter", "devourer"),
    ("DRUID_BALANCE",         "druid",        "balance"),
    ("DRUID_FERAL",           "druid",        "feral"),
    ("DRUID_GUARDIAN",        "druid",        "guardian"),
    ("DRUID_RESTORATION",     "druid",        "restoration"),
    ("EVOKER_DEVASTATION",    "evoker",       "devastation"),
    ("EVOKER_PRESERVATION",   "evoker",       "preservation"),
    ("EVOKER_AUGMENTATION",   "evoker",       "augmentation"),
    ("HUNTER_BEASTMASTERY",   "hunter",       "beast_mastery"),
    ("HUNTER_MARKSMANSHIP",   "hunter",       "marksmanship"),
    ("HUNTER_SURVIVAL",       "hunter",       "survival"),
    ("MAGE_ARCANE",           "mage",         "arcane"),
    ("MAGE_FIRE",             "mage",         "fire"),
    ("MAGE_FROST",            "mage",         "frost"),
    ("MONK_BREWMASTER",       "monk",         "brewmaster"),
    ("MONK_MISTWEAVER",       "monk",         "mistweaver"),
    ("MONK_WINDWALKER",       "monk",         "windwalker"),
    ("PALADIN_HOLY",          "paladin",      "holy"),
    ("PALADIN_PROTECTION",    "paladin",      "protection"),
    ("PALADIN_RETRIBUTION",   "paladin",      "retribution"),
    ("PRIEST_DISCIPLINE",     "priest",       "discipline"),
    ("PRIEST_HOLY",           "priest",       "holy"),
    ("PRIEST_SHADOW",         "priest",       "shadow"),
    ("ROGUE_ASSASSINATION",   "rogue",        "assassination"),
    ("ROGUE_OUTLAW",          "rogue",        "outlaw"),
    ("ROGUE_SUBTLETY",        "rogue",        "subtlety"),
    ("SHAMAN_ELEMENTAL",      "shaman",       "elemental"),
    ("SHAMAN_ENHANCEMENT",    "shaman",       "enhancement"),
    ("SHAMAN_RESTORATION",    "shaman",       "restoration"),
    ("WARLOCK_AFFLICTION",    "warlock",      "affliction"),
    ("WARLOCK_DEMONOLOGY",    "warlock",      "demonology"),
    ("WARLOCK_DESTRUCTION",   "warlock",      "destruction"),
    ("WARRIOR_ARMS",          "warrior",      "arms"),
    ("WARRIOR_FURY",          "warrior",      "fury"),
    ("WARRIOR_PROTECTION",    "warrior",      "protection"),
]

MAX_ROWS = 25  # top N trinkets per spec/style — the tail is noise

# How many of those also keep their full item-level curve. The curve is
# ~8 numbers per trinket and would otherwise be most of the file, and
# nobody is weighing a crossover between the 22nd and 23rd best trinket.
MATRIX_ROWS = 15


def fetch_json(url, retries=3):
    last = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={
                "User-Agent": "YippYappHelper-datagen/1.0 (addon data update)",
                "Accept": "application/json",
                "Accept-Encoding": "gzip",
            })
            with urllib.request.urlopen(req, timeout=60) as r:
                raw = r.read()
                gz = r.headers.get("Content-Encoding") == "gzip"
            if gz:
                raw = gzip.decompress(raw)
            return json.loads(raw.decode("utf-8", "replace"))
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            last = e
        except Exception as e:  # noqa: BLE001
            last = e
        time.sleep(2.0 * (attempt + 1))
    raise RuntimeError("fetch failed: %s (%s)" % (url, last))


def condense(payload):
    """Rank trinkets and express each as % behind the best shown."""
    if not payload or payload.get("status") == "error":
        return None
    order = payload.get("sorted_data_keys") or []
    data = payload.get("data") or {}
    ids = payload.get("item_ids") or {}
    if not order or not data:
        return None

    # Each trinket at its own highest simulated item level, which is what
    # bloodmallet's own chart ranks by (verified: sorting the payload that
    # way reproduces sorted_data_keys exactly).
    #
    # There is no longer a single item level to compare at. Trinkets now
    # top out at different steps depending on where they drop -- crafted
    # at 334, raid up to 344 -- and some exist at exactly one step, so
    # requiring a step that every trinket shares (what this used to do)
    # matches nothing and throws away the whole spec. The per-trinket
    # ceiling is also the more useful question: how good is this thing
    # once it is as good as it gets.
    rows = []
    for name in order[:MAX_ROWS]:
        steps = [int(s) for s in data.get(name, {}) if str(s).isdigit()]
        if not steps:
            continue
        ilvl = max(steps)
        # `lo` is what separates this season's trinkets from the ones
        # bloodmallet keeps simming out of previous content. A current
        # trinket has an upgrade ladder -- 292 up to 331, 334 or 344 --
        # while anything carried forward is stuck at the single item
        # level it capped out at, so lo == ilvl means "not from here".
        # Cheaper and more honest than guessing from item ID ranges.
        rows.append({"name": name, "dps": data[name][str(ilvl)],
                     "ilvl": ilvl, "lo": min(steps), "id": ids.get(name)})
    if not rows:
        return None

    top = max(r["dps"] for r in rows) or 1
    for r in rows:
        # Percent behind the best trinket — the number players actually
        # reason about ("this one is 3% worse").
        r["rel"] = round((r["dps"] - top) / float(top) * 100.0, 2)

    # The scaling curve, for the top rows only. This is what makes the
    # crossover visible: two trinkets can rank the other way round at a
    # lower item level, and the flat "best available" ranking cannot say
    # so. Kept to MATRIX_ROWS because the tail below that is not what
    # anyone is deciding between, and the matrix is the bulk of the file.
    #
    # Values are percent gain over `baseline` — the same profile with the
    # slot empty — which is what bloodmallet's own chart measures. It is
    # comparable across trinkets and item levels within a block, so the
    # UI can rank at a chosen item level by reading it straight off.
    base = None
    for step in sorted((int(s) for s in data.get("baseline", {})
                        if str(s).isdigit()), reverse=True):
        base = data["baseline"][str(step)]
        break

    # Where it drops -- which is why two trinkets stop at different item
    # levels, and what the loot council view filters on, so it is kept
    # for every row rather than only the ones with a curve. A trinket
    # ranked 20th here may be 3rd for the spec next door.
    source = {}
    sources = payload.get("data_sources") or {}
    for r in rows:
        if r["id"] and sources.get(r["name"]):
            source[r["id"]] = sources[r["name"]]

    curve, steps = {}, set()
    if base:
        for r in rows[:MATRIX_ROWS]:
            iid = r["id"]
            if not iid:
                continue
            points = {}
            for s, dps in data.get(r["name"], {}).items():
                if not str(s).isdigit():
                    continue
                points[int(s)] = round((dps - base) / float(base) * 100.0, 2)
            if not points:
                continue
            curve[iid] = points
            steps.update(points)

    settings = payload.get("simc_settings") or {}
    return {
        "ilvl": max(r["ilvl"] for r in rows),
        "rows": rows,
        "steps": sorted(steps),
        "curve": curve,
        "source": source,
        "tier": settings.get("tier"),
        "simc": settings.get("simc_hash"),
        "timestamp": (payload.get("timestamp") or "")[:19],
    }


# Reading back a file this same script wrote, so the format is fixed and
# regex is enough — there is no general Lua here to parse.
FILE_TIER_RE = re.compile(r'^ns\.TRINKET_TIER = "([^"]*)"', re.M)
SPEC_RE = re.compile(r'^ns\.TrinketData\["([A-Z_]+)"\] = \{\n(.*?)^\}',
                     re.M | re.S)
STYLE_RE = re.compile(r'^    ([A-Z]+) = \{\n(.*?)^    \},', re.M | re.S)
ROW_RE = re.compile(
    r'\{ id = (\d+),\s+(?:ilvl = (\d+), )?(?:lo = (\d+), )?'
    r'rel = *(-?[\d.]+), name = "(.*?)" \}')
FIELD_RE = {
    "ilvl": re.compile(r'^        ilvl = (\d+),', re.M),
    "timestamp": re.compile(r'^        timestamp = "([^"]*)",', re.M),
    "tier": re.compile(r'^        tier = "([^"]*)",', re.M),
}
STEPS_RE = re.compile(r'^        steps = \{ ([\d, ]+) \},', re.M)
CURVE_RE = re.compile(r'^        curve = \{\n(.*?)^        \},', re.M | re.S)
CURVE_ROW_RE = re.compile(r'^            \[(\d+)\] = \{ (.*?) \},', re.M)
POINT_RE = re.compile(r'\[(\d+)\]=(-?[\d.]+)')
SOURCE_RE = re.compile(r'^        source = \{ (.*?) \},', re.M)
SOURCE_ENTRY_RE = re.compile(r'\[(\d+)\]="((?:[^"\\]|\\.)*)"')


def read_existing(path):
    """Previously generated blocks, so unpublished specs survive a rerun."""
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return {}

    m = FILE_TIER_RE.search(text)
    file_tier = m.group(1) if m else None

    out = {}
    for key, body in SPEC_RE.findall(text):
        styles = {}
        for skey, sbody in STYLE_RE.findall(body):
            fields = {}
            for name, rx in FIELD_RE.items():
                fm = rx.search(sbody)
                fields[name] = fm.group(1) if fm else None
            rows = []
            for iid, ilvl, lo, rel, name in ROW_RE.findall(sbody):
                rows.append({
                    "id": int(iid),
                    # Files written before trinkets had per-item ceilings
                    # compared everything at the block's one item level.
                    "ilvl": int(ilvl) if ilvl else int(fields["ilvl"] or 0),
                    "lo": int(lo) if lo else None,
                    "rel": float(rel),
                    "name": name.replace('\\"', '"').replace("\\\\", "\\"),
                })
            if not rows:
                continue

            # Order by the number actually shown. Blocks written before
            # trinkets had per-item ceilings kept bloodmallet's ranking,
            # which sorts by each trinket's own top item level, while
            # `rel` was computed at the one item level they all shared --
            # two different questions, so the list could read "#7 -2.7%,
            # #8 -2.1%" and rank a trinket below one it beats. Sorting by
            # rel is a no-op for anything scraped since (both now come
            # from the same basis) and makes the older blocks agree with
            # themselves.
            #
            # No tie-break on name: the sort is stable, so trinkets on
            # the same number keep the order bloodmallet gave them.
            # Breaking ties alphabetically would reshuffle rows that are
            # already correct, and reading the file back would then
            # disagree with the scrape that wrote it.
            rows.sort(key=lambda r: -r["rel"])

            # A block written before curves existed simply has none, and
            # cannot get one: bloodmallet serves only the current run, so
            # the item-level detail for a spec it has not re-simmed is
            # gone. Those carry forward flat rather than blocking a merge.
            curve = {}
            cm = CURVE_RE.search(sbody)
            if cm:
                for iid, points in CURVE_ROW_RE.findall(cm.group(1)):
                    curve[int(iid)] = {int(s): float(v)
                                       for s, v in POINT_RE.findall(points)}
            sm = STEPS_RE.search(sbody)
            steps = [int(s) for s in sm.group(1).split(",")] if sm else []
            source = {}
            om = SOURCE_RE.search(sbody)
            if om:
                source = {int(i): v.replace('\\"', '"').replace("\\\\", "\\")
                          for i, v in SOURCE_ENTRY_RE.findall(om.group(1))}

            styles[skey] = {
                "ilvl": int(fields["ilvl"] or max(r["ilvl"] for r in rows)),
                "timestamp": fields["timestamp"] or "",
                # No per-block tier means a file from before this was
                # written, when one tier covered every block in it.
                "tier": fields["tier"] or file_tier,
                "steps": steps,
                "curve": curve,
                "source": source,
                "rows": rows,
                "carried": True,
            }
        if styles:
            out[key] = styles
    return out


def lua_str(s):
    if s is None:
        return "nil"
    s = str(s).replace("\\", "\\\\").replace('"', '\\"')
    s = s.replace("\r", "").replace("\n", "\\n")
    return '"%s"' % s


def emit(results, meta):
    L = []
    add = L.append
    add("local _, ns = ...")
    add("")
    add("---" + "-" * 57)
    add("-- Trinket rankings per spec, from bloodmallet.com SimulationCraft runs.")
    add("--")
    add("-- GENERATED FILE — do not hand-edit.")
    add("-- Regenerate with:  python Tools/scrape_trinkets.py")
    add("--")
    add("-- Each trinket is simmed at its own highest item level -- they do")
    add("-- not share one, since a crafted trinket and a raid drop cap out")
    add("-- in different places -- so `ilvl` is per row, and the block's")
    add("-- `ilvl` is just the highest of them. `rel` is percent behind the")
    add("-- best trinket in the list.")
    add("--")
    add("-- `tier` is bloodmallet's own tier tag, and it is per block: a")
    add("-- new tier arrives a few specs at a time, so blocks it has not")
    add("-- re-simmed keep the previous tier's ranking and the UI flags")
    add("-- those specifically rather than presenting them as current.")
    add("---" + "-" * 57)
    add("")
    add("ns.TrinketData = {}")
    add("ns.TRINKET_SOURCE = %s" % lua_str("bloodmallet.com"))
    add("ns.TRINKET_TIER = %s" % lua_str(meta.get("tier")))
    add("ns.TRINKET_SIMC = %s" % lua_str(meta.get("simc")))
    add("ns.TRINKET_SCRAPED_AT = %s" % lua_str(
        time.strftime("%Y-%m-%d", time.gmtime())))
    add("ns.TRINKET_TARGET_TIER = %s  -- bump when the season flips"
        % lua_str("MID2"))
    add("")

    for key in sorted(results):
        styles = results[key]
        add('ns.TrinketData["%s"] = {' % key)
        # Fixed order rather than dict order, so a spec whose 5-target
        # chart is fresh and whose single-target one was carried does not
        # come out with its styles swapped and show up as a diff that
        # changed nothing. Anything not in FIGHT_STYLES still gets
        # written, after — dropping a style silently is how carried data
        # disappears without anyone noticing.
        ordered = [s for s, _ in FIGHT_STYLES if s in styles]
        ordered += [s for s in styles if s not in ordered]
        for skey in ordered:
            block = styles[skey]
            add("    %s = {" % skey)
            add("        ilvl = %d," % block["ilvl"])
            add("        timestamp = %s," % lua_str(block["timestamp"]))
            add("        tier = %s," % lua_str(block.get("tier")))
            # Beside `list` rather than inside the rows: it keeps every
            # row on one line, which is what lets this file be read back
            # for a merge without a Lua parser.
            steps = block.get("steps") or []
            curve = block.get("curve") or {}
            if steps and curve:
                add("        steps = { %s },"
                    % ", ".join(str(s) for s in steps))
                add("        curve = {")
                for r in block["rows"]:
                    points = curve.get(r["id"])
                    if not points:
                        continue
                    add("            [%d] = { %s }," % (r["id"], ", ".join(
                        "[%d]=%.2f" % (s, points[s]) for s in sorted(points))))
                add("        },")
            source = block.get("source") or {}
            if source:
                add("        source = { %s }," % ", ".join(
                    "[%d]=%s" % (i, lua_str(source[i])) for i in sorted(source)))
            add("        list = {")
            for r in block["rows"]:
                iid = r["id"] if r["id"] else 0
                # `lo` is absent on blocks carried from before it was
                # recorded, and writing a made-up one would claim those
                # trinkets are current content.
                lo = ("lo = %d, " % r["lo"]) if r.get("lo") else ""
                add('            { id = %-8s ilvl = %d, %srel = %6.2f, name = %s },'
                    % (str(iid) + ",", r["ilvl"], lo, r["rel"],
                       lua_str(r["name"])))
            add("        },")
            add("    },")
        add("}")
        add("")
    return "\n".join(L) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--spec", action="append")
    ap.add_argument("--out", default=OUT_PATH)
    ap.add_argument("--no-carry", dest="carry", action="store_false",
                    help="overwrite instead of keeping blocks bloodmallet "
                         "has not re-simmed yet")
    args = ap.parse_args()

    targets = SPECS
    if args.spec:
        wanted = {s.upper() for s in args.spec}
        targets = [s for s in SPECS if s[0] in wanted]

    results, problems, meta = {}, [], {}
    for key, cls, spec in targets:
        got = {}
        for skey, style in FIGHT_STYLES:
            url = ENDPOINT.format(dtype="trinkets", style=style,
                                  cls=cls, spec=spec)
            payload = fetch_json(url)
            block = condense(payload)
            if block:
                got[skey] = block
                meta.setdefault("tier", block["tier"])
                meta.setdefault("simc", block["simc"])
            time.sleep(0.4)
        if got:
            results[key] = got
            print("%-24s %s" % (key, "  ".join(
                "%s:%d trinkets @%d" % (k, len(v["rows"]), v["ilvl"])
                for k, v in got.items())))
        else:
            problems.append(key)
            print("%-24s no data" % key)

    print("\n%d/%d specs with fresh data   tier=%s"
          % (len(results), len(targets), meta.get("tier")))
    if problems:
        print("not published this run: " + ", ".join(problems))

    # Anything bloodmallet has not re-simmed keeps the ranking it had,
    # tagged with the tier it came from. Merged per style, not per spec:
    # a spec can pick up a fresh single-target chart weeks before its
    # 5-target one, and the half that arrived must not drag the other
    # half out of the file with it.
    carried = []
    if args.carry:
        for key, styles in read_existing(args.out).items():
            for skey, block in styles.items():
                if results.get(key, {}).get(skey):
                    continue
                results.setdefault(key, {})[skey] = block
                carried.append("%s/%s@%s" % (key, skey, block.get("tier")))
        if carried:
            print("\ncarried %d older block(s): %s"
                  % (len(carried), ", ".join(sorted(carried))))

    # ns.TRINKET_TIER is the newest tier in the file, which is the fresh
    # one whenever the scrape returned anything. With nothing fresh it
    # falls back to the carried blocks, so a run during an outage does
    # not blank the tier and make every spec look unlabelled.
    if not meta.get("tier"):
        meta["tier"] = next((b.get("tier") for s in results.values()
                             for b in s.values() if b.get("tier")), None)

    print("%d specs in file" % len(results))

    if args.dry_run:
        return 0
    if not results:
        print("nothing to write", file=sys.stderr)
        return 1

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        f.write(emit(results, meta))
    print("wrote %s" % args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
