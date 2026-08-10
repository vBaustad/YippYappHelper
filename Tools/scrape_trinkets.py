#!/usr/bin/env python3
"""
Regenerate Features/Trinkets/TrinketData.lua from bloodmallet.com.

Usage:
    python Tools/scrape_trinkets.py             # write the Lua file
    python Tools/scrape_trinkets.py --dry-run
    python Tools/scrape_trinkets.py --spec PRIEST_SHADOW

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
"""

import argparse
import gzip
import json
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_PATH = os.path.join(ROOT, "Features", "Trinkets", "TrinketData.lua")

ENDPOINT = "https://bloodmallet.com/chart/get/{dtype}/{style}/{cls}/{spec}"

# Only castingpatchwerk is currently populated — patchwerk,
# hecticaddcleave, beastlord and the dungeon styles all return "no
# standard chart" right now. Extra entries here are harmless: a style
# with no data is skipped per spec, so add them back when bloodmallet
# starts publishing them.
FIGHT_STYLES = [
    ("ST", "castingpatchwerk"),
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
    """Rank trinkets and express each as % gain over the weakest shown."""
    if not payload or payload.get("status") == "error":
        return None
    order = payload.get("sorted_data_keys") or []
    data = payload.get("data") or {}
    ids = payload.get("item_ids") or {}
    if not order or not data:
        return None

    # Use the highest simulated item level every trinket actually has, so
    # the comparison is apples to apples.
    steps = [int(s) for s in payload.get("simulated_steps", []) if str(s).isdigit()]
    steps.sort(reverse=True)
    ilvl = None
    for step in steps:
        if all(str(step) in data.get(k, {}) for k in order[:MAX_ROWS]):
            ilvl = step
            break
    if ilvl is None:
        return None

    rows = []
    for name in order[:MAX_ROWS]:
        dps = data.get(name, {}).get(str(ilvl))
        if dps is None:
            continue
        rows.append({"name": name, "dps": dps, "id": ids.get(name)})
    if not rows:
        return None

    base = min(r["dps"] for r in rows) or 1
    top = max(r["dps"] for r in rows) or 1
    for r in rows:
        # Percent behind the best trinket — the number players actually
        # reason about ("this one is 3% worse").
        r["rel"] = round((r["dps"] - top) / float(top) * 100.0, 2)
    settings = payload.get("simc_settings") or {}
    return {
        "ilvl": ilvl,
        "rows": rows,
        "tier": settings.get("tier"),
        "simc": settings.get("simc_hash"),
        "timestamp": (payload.get("timestamp") or "")[:19],
    }


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
    add("-- `rel` is percent behind the best trinket in that list, at the")
    add("-- item level in `ilvl`. `tier` is bloodmallet's own tier tag; when")
    add("-- it is behind the current season the UI says so rather than")
    add("-- presenting last tier's ranking as current.")
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
        for skey, block in styles.items():
            add("    %s = {" % skey)
            add("        ilvl = %d," % block["ilvl"])
            add("        timestamp = %s," % lua_str(block["timestamp"]))
            add("        list = {")
            for r in block["rows"]:
                iid = r["id"] if r["id"] else 0
                add('            { id = %-8s rel = %6.2f, name = %s },'
                    % (str(iid) + ",", r["rel"], lua_str(r["name"])))
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

    print("\n%d/%d specs with data   tier=%s"
          % (len(results), len(targets), meta.get("tier")))
    if problems:
        print("no data for: " + ", ".join(problems))

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
