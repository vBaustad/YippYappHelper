#!/usr/bin/env python3
"""
Regenerate Features/Gear/ClassGuideData.lua from Wowhead's per-spec
stat-priority and best-in-slot guides.

Usage:
    python Tools/scrape_class_guides.py            # write the Lua file
    python Tools/scrape_class_guides.py --dry-run  # report only
    python Tools/scrape_class_guides.py --spec MAGE_FIRE

Two pages per spec:
    /guide/classes/{cls}/{spec}/stat-priority-pve-{role}
    /guide/classes/{cls}/{spec}/bis-gear

Everything shared with the consumables scraper is imported from it
rather than copied — above all the SPECS table, which carries the
class/spec/role slugs. Two copies of that would drift the first time
Blizzard adds a spec, and the role slug is load-bearing: it is part of
the stat-priority URL.

WHAT COMES OUT

stat priority is per HERO TALENT BUILD, not per spec. Fire Mage lists
Sunfury and Frostfire separately, and while those two happen to agree
today, several specs do not. Flattening them to one list per spec would
invent a consensus the guide does not claim, so each build keeps its own
ordered list.

best-in-slot is a Slot / Item / Source table. Catalyst pieces carry
`original-item=` — the thing you feed the Catalyst to get the tier
piece — which is worth keeping, since "which item do I catalyse" is a
question the addon can otherwise never answer.

WHAT IS DELIBERATELY NOT SCRAPED

Rotation pages. They are prose written by named authors rather than
lists of IDs, and shipping them verbatim is a different proposition from
shipping item numbers.
"""

import argparse
import difflib
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from scrape_consumables import (  # noqa: E402
    CURRENT_SEASON, ROOT, SPECS,
    fetch, extract_markup, parse_names, parse_tables,
    cell_items, cell_label, lua_str, split_h2,
)

OUT_PATH = os.path.join(ROOT, "Features", "Gear", "ClassGuideData.lua")

# Eighty pages a run, and a run gets repeated while a parser is being
# tuned. Wowhead started returning 403 partway through development for
# exactly that reason, which is a fair response and also loses the whole
# sweep. Cached pages make re-running the PARSER free, so only a genuine
# data refresh costs requests.
CACHE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".cache")
CACHE_MAX_AGE = 12 * 3600


def cached_fetch(url, refresh=False):
    """fetch() with an on-disk cache. Returns None on a 404, as fetch does."""
    import hashlib
    os.makedirs(CACHE_DIR, exist_ok=True)
    path = os.path.join(CACHE_DIR, hashlib.sha1(url.encode()).hexdigest() + ".html")
    if not refresh and os.path.exists(path):
        if time.time() - os.path.getmtime(path) < CACHE_MAX_AGE:
            with open(path, encoding="utf-8") as fh:
                body = fh.read()
            return body or None
    html = fetch(url)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(html or "")
    time.sleep(1.0)  # only sleep on a real request
    return html

STAT_URL = "https://www.wowhead.com/guide/classes/{cls}/{spec}/stat-priority-pve-{role}"
BIS_URL = "https://www.wowhead.com/guide/classes/{cls}/{spec}/bis-gear"

# Primary stats are listed first in every priority and are not a choice —
# nobody gems for the wrong primary. Kept anyway: dropping them would
# silently renumber every list, and "Intellect first" is still true.
KNOWN_STATS = (
    "strength", "agility", "intellect", "stamina",
    "critical strike", "crit", "haste", "mastery", "versatility",
    "leech", "avoidance", "speed",
)

# Wowhead's slot wording -> the addon's. Anything unmapped is kept as
# written rather than dropped, so a new slot name shows up in the data
# instead of vanishing.
SLOT_NAMES = {
    "head": "Head", "helm": "Head", "neck": "Neck", "shoulders": "Shoulders",
    "shoulder": "Shoulders", "back": "Back", "cloak": "Back",
    "chest": "Chest", "wrist": "Wrist", "wrists": "Wrist",
    "bracers": "Wrist", "hands": "Hands", "gloves": "Hands",
    "waist": "Waist", "belt": "Waist", "legs": "Legs", "feet": "Feet",
    "boots": "Feet", "ring": "Ring", "rings": "Ring", "ring 1": "Ring 1",
    "ring 2": "Ring 2", "finger": "Ring", "trinket": "Trinket",
    "trinkets": "Trinket", "trinket 1": "Trinket 1", "trinket 2": "Trinket 2",
    "weapon": "Weapon", "weapons": "Weapon", "main hand": "Main Hand",
    "mainhand": "Main Hand", "main-hand": "Main Hand",
    "off hand": "Off Hand", "offhand": "Off Hand", "off-hand": "Off Hand",
    "two-hand": "Weapon", "shield": "Off Hand",
    # Wowhead's authors are not consistent about weapon and cloak wording,
    # and an unrecognised slot is not cosmetic: the page matches BiS rows
    # against equipped gear by slot name, so "Cape" instead of "Back"
    # silently drops the "equipped" marker on a piece you are wearing.
    "cape": "Back", "cloak/back": "Back",
    "1h weapon": "Weapon", "2h weapon": "Weapon",
    "one-hand": "Weapon", "1-hand": "Weapon", "2-hand": "Weapon",
    "weapon (1h)": "Weapon", "weapon (2h)": "Weapon",
    "weapons (1h)": "Weapon", "weapons (2h)": "Weapon",
}


def normalise_slot(raw):
    """Map a guide's slot wording onto the addon's, tolerantly.

    Several guides qualify a slot in parentheses -- "Trinket (Damage)",
    "Trinket (Raid only)" -- which is editorial, not a different slot.
    Strip the qualifier and retry before giving up, so those rows still
    match equipped gear instead of only looking like they should.
    """
    low = raw.lower().strip()
    if low in SLOT_NAMES:
        return SLOT_NAMES[low]
    bare = re.sub(r"\s*\([^)]*\)\s*", " ", low).strip()
    if bare in SLOT_NAMES:
        return SLOT_NAMES[bare]
    return None


def clean(text):
    """Strip BBCode wrappers from a short label, keeping the words."""
    text = re.sub(r"\[/?[^\]]*\]", "", text or "")
    text = text.replace("&ndash;", "-").replace("&amp;", "&")
    return " ".join(text.split()).strip(" :-")


def parse_stat_priority(markup):
    """Ordered stat lists with the build and context they belong to.

    Anchored on the [ol] rather than on whatever wraps it. Guides use at
    least two containers for the same thing — Fire Mage puts each list in
    a [box], Holy Priest uses [div style=...] inside a [grid] — and
    matching containers found Fire Mage while silently returning nothing
    for Holy Priest. The ordered list is the one part that is always
    there, because it *is* the data: the whole datum is the ordering.

    Two labels are recovered by looking backwards from each list:
      build   - nearest preceding [center], e.g. "Archon", "Sunfury"
      context - nearest preceding [h3], e.g. "Raid", "Dungeons/Mythic+"

    Context matters. Several healers publish different priorities for
    raid and for Mythic+, and collapsing those into one list would
    silently pick whichever appeared first.
    """
    found = []
    for m in re.finditer(r"\[ol\]([\s\S]*?)\[/ol\]", markup):
        stats = []
        for li in re.findall(r"\[li\]([\s\S]*?)\[/li\]", m.group(1)):
            name = clean(li)
            if name and any(k in name.lower() for k in KNOWN_STATS):
                stats.append(name)
        if len(stats) < 2:
            continue  # an ordered list that is not a stat priority

        before = markup[:m.start()]
        title = ""
        centers = re.findall(r"\[center\]([\s\S]*?)\[/center\]", before)
        if centers:
            title = clean(centers[-1])
        title = re.sub(r"(?i)\s*stat priority\s*", "", title).strip()

        context = ""
        heads = re.findall(r"\[h3[^\]]*\]([\s\S]*?)\[/h3\]", before)
        if heads:
            context = clean(heads[-1])

        found.append({"build": title or "Default",
                      "context": context, "stats": stats})

    # Merge lists that agree, keeping every build name — so the UI can
    # say which builds a priority covers rather than picking one and
    # implying a consensus the guide never claimed.
    merged = []
    for entry in found:
        for prev in merged:
            if prev["stats"] == entry["stats"] and prev["context"] == entry["context"]:
                if entry["build"] not in prev["builds"]:
                    prev["builds"].append(entry["build"])
                break
        else:
            merged.append({"builds": [entry["build"]],
                           "context": entry["context"],
                           "stats": entry["stats"]})
    return merged


def parse_bis(markup):
    """Slot / Item / Source rows from the BiS table.

    Classified per row rather than by table header: header wording varies
    between guides, and sniffing it dropped whole tables in the
    consumables scraper for the same reason.
    """
    # Scope to the recommended-gear chapter. The page also carries Raid
    # Drops, Mythic+ Drops and Trinkets tables, and scanning all of them
    # swept in rows whose first column is a RANK, not a slot -- which is
    # how "1" and "2" ended up as slot names, pointing at items already
    # listed above under their real slot.
    scoped = ""
    for title, body in split_h2(markup):
        low = title.lower()
        if "recommended" in low or "best in slot" in low or "bis" in low:
            scoped += body
    if not scoped:
        scoped = markup  # better a noisy list than an empty one

    out, seen = [], set()
    for rows in parse_tables(scoped):
        for cells in rows:
            if len(cells) < 2:
                continue
            raw_slot = clean(cell_label(cells[0])).lower()
            if not raw_slot or raw_slot in ("slot", "item", "source"):
                continue

            # Column layout is not fixed. Most guides run
            # Slot | Item | Source, but some insert an enchant column —
            # Enhancement Shaman's table is Slot | enchant | Item |
            # Source — so reading cells[1] found nothing at all there.
            # Locate the column that actually carries a gear token
            # instead of trusting a position.
            #
            # Enchant cells write [url=item=NNN], which does not match
            # the [item=NNN] pattern, so an enchant cannot be mistaken
            # for the best-in-slot piece. That is worth relying on
            # deliberately rather than by luck.
            item_idx, ids, bonus = None, [], ""
            for idx in range(1, len(cells)):
                found = cell_items(cells[idx])
                if found:
                    item_idx, ids = idx, found
                    # Bonus IDs encode the upgrade rank the guide is
                    # actually recommending. Without them the addon shows
                    # the item at its base level, which for a Myth-track
                    # piece is a different item level to the one the BiS
                    # list means -- so the page would quietly understate
                    # every recommendation.
                    bm = re.search(r"\[item=%d\s+bonus=([\d:]+)" % ids[0],
                                   cells[idx])
                    if bm:
                        bonus = bm.group(1)
                    break
            if not ids:
                continue

            slot = normalise_slot(raw_slot) or clean(cell_label(cells[0]))
            source = ""
            if item_idx is not None and item_idx + 1 < len(cells):
                source = clean(cells[-1])
            # The pre-Catalyst item, when this row is a tier conversion.
            orig = re.search(r"original-item=(\d+)", cells[item_idx])
            key = (slot, ids[0])
            if key in seen:
                continue
            seen.add(key)
            entry = {"slot": slot, "itemID": ids[0], "source": source}
            if bonus:
                entry["bonus"] = bonus
            if orig:
                entry["catalystFrom"] = int(orig.group(1))
            out.append(entry)
    return out


# Two names are a typo apart at 0.917 and the closest UNRELATED pair in
# the corpus is 0.852, so the cut goes in the gap. Chosen from the data
# rather than picked: "Nymrissa Wavecaller" and "Nymrissa Wavebinder"
# score 0.789 and must NOT merge -- they are different words, not a
# misspelling, and only the Encounter Journal knows which one is real.
SOURCE_MERGE_RATIO = 0.88

# Names the ratio cannot fix, because they are wrong by a whole word
# rather than by a letter.
#
# "Nymrissa Wavecaller" and "Nymrissa Wavebinder" score 0.789 -- close
# to the unrelated pairs, and nowhere near the 0.917 a typo scores. No
# threshold separates them safely, so the merge has to be asserted, and
# asserting it needs a source outside the guides.
#
# Every entry here was read off the client's own Encounter Journal.
# Wavecaller is the boss the journal ships; Wavebinder is the guides'
# mistake, and the item that drops from her -- Wavecaller's Seastone --
# had been saying so all along.
#
# Keys are _source_key form: lowercase, apostrophes gone, no leading
# "The". Values are the spelling to emit.
SOURCE_ALIASES = {
    "nymrissa wavebinder": "Nymrissa Wavecaller",
}

# Segments that say how you get a thing rather than where it drops. They
# never name a place, so they are never canonicalised against one.
ACQUISITION = {
    "catalyst", "crafting", "crafted", "tier set", "vault", "misc",
    "mythic+", "raid", "world boss", "pvp", "delves",
    "blacksmithing", "jewelcrafting", "leatherworking", "tailoring",
    "alchemy", "enchanting", "inscription", "engineering",
}


def _source_key(name):
    """What two spellings of the same place have in common."""
    n = name.lower().replace("’", "'").replace("'", "")
    n = re.sub(r"^the\s+", "", n)
    return " ".join(n.split())


def split_source(raw):
    """A source string as its separate segments.

    Guides join these with "&", "/" and "|", and the pipe is the one that
    matters: "|" opens an escape sequence in a WoW FontString. So
    "Tier Set|The Coiled Altar" reaches the client as |T -- the texture
    escape -- and swallows the rest of the line. Ten rows carried one.

    "(Raid)" goes at the same time. It is on 32 rows and never news: the
    boss name in front of it already carried the point, and it cost the
    width that name needed.
    """
    raw = re.sub(r"\s*\(Raid\)", "", raw or "")
    # "Catalyst the The Coiled Altar Shoulders" and "Catalyst - Ula'tek"
    # are the same statement in two shapes, and neither shape is a name.
    # Reduce both to the separator the rest of the column uses.
    raw = re.sub(r"^(Catalyst|Tier Set)\s+the\s+(.*?)\s+"
                 r"(Head|Shoulders?|Chest|Hands|Gloves|Waist|Legs|Feet|Back|Wrist)$",
                 r"\1 / \2", raw, flags=re.I)
    raw = re.sub(r"^(Catalyst|Tier Set)\s*-\s*", r"\1 / ", raw, flags=re.I)
    parts = [p.strip() for p in re.split(r"\s*[&/|]\s*", raw)]
    return [p for p in parts if p]


def canonical_sources(all_specs):
    """Settle on one spelling per place, and split names glued together.

    The guides are written by hand, and the same raid appears as "The
    Coiled Altar" 110 times and "The Coiled Alter" 6 -- plus three
    spellings of King's Rest and two of Entombed Sentinels. Left alone
    that is three separate problems: the page displays a misspelling, one
    place sorts as two, and an Encounter Journal lookup misses silently.

    Majority wins, which is what makes this self-maintaining. Nothing
    here hardcodes which spelling is correct, so a guide that fixes its
    own typo simply moves the count and this follows it.
    """
    counts = {}
    for _key, data in all_specs:
        for row in data.get("bis", []):
            for seg in split_source(row.get("source", "")):
                counts[seg] = counts.get(seg, 0) + 1

    # Most frequent first, so a cluster is always named by its winner.
    ordered = sorted(counts, key=lambda n: (-counts[n], n))
    canon = {}
    for name in ordered:
        # Asserted corrections first: they outrank both the majority and
        # the ratio, because they were checked against the game and
        # those two were not.
        alias = SOURCE_ALIASES.get(_source_key(name))
        if alias:
            canon[name] = alias
            continue
        if _source_key(name) in ACQUISITION:
            canon[name] = name
            continue
        for winner in canon.values():
            if _source_key(winner) in ACQUISITION:
                continue
            ratio = difflib.SequenceMatcher(
                None, _source_key(winner), _source_key(name)).ratio()
            if ratio >= SOURCE_MERGE_RATIO:
                canon[name] = winner
                break
        else:
            canon[name] = name

    # Two names run together with no separator -- "The Coiled Altar
    # Sszorak", "Crafting Blacksmithing". Split only where the whole
    # segment is exactly one known name followed by another, so a real
    # multi-word name can never be torn in half.
    known = sorted(set(canon.values()), key=len, reverse=True)

    def unglue(seg):
        for a in known:
            if seg.startswith(a + " ") and len(seg) > len(a) + 1:
                rest = seg[len(a) + 1:]
                if rest in canon:
                    return [a, canon[rest]]
        return [seg]

    rewritten = 0
    for _key, data in all_specs:
        for row in data.get("bis", []):
            segs = []
            for seg in split_source(row.get("source", "")):
                for piece in unglue(canon.get(seg, seg)):
                    if piece not in segs:
                        segs.append(piece)
            new = " / ".join(segs)
            if new != (row.get("source") or ""):
                rewritten += 1
            row["source"] = new
    return rewritten

def parse_season(markup):
    m = re.search(r"Midnight Season \d+", markup)
    return m.group(0) if m else ""


def emit(all_specs):
    add = [].append
    L = []
    def w(line=""):
        L.append(line)

    w("local _, ns = ...")
    w()
    w("-" * 60)
    w("-- Per-spec stat priority and best-in-slot, from Wowhead's class")
    w("-- guides.")
    w("--")
    w("-- GENERATED FILE - do not hand-edit.")
    w("-- Regenerate with:  python Tools/scrape_class_guides.py")
    w("--")
    w("-- statPriority is per HERO TALENT BUILD. Builds that agree are")
    w("-- merged and list both names, so the UI can say which builds a")
    w("-- priority covers instead of implying a spec-wide consensus.")
    w("--")
    w("-- bis rows carry `bonus` (colon-joined bonus IDs) where the guide")
    w("-- specifies an upgrade rank. Without those the item resolves at")
    w("-- its base item level, not the one the list actually means.")
    w("--")
    w("-- bis rows carry catalystFrom when the piece is a Catalyst")
    w("-- conversion: that is the item you feed in to get this one.")
    w("--")
    w("-- Item names are NOT stored. They are resolved from the ID at")
    w("-- runtime, which localises for free and survives a rename.")
    w("-" * 60)
    w()
    w("ns.ClassGuideData = {}")
    w('ns.CLASS_GUIDE_SOURCE = "Wowhead class guides"')
    w('ns.CLASS_GUIDE_TARGET_SEASON = %s' % lua_str(CURRENT_SEASON))
    w('ns.CLASS_GUIDE_SCRAPED_AT = "%s"' % time.strftime("%Y-%m-%d"))
    w()

    for key, data in all_specs:
        w('ns.ClassGuideData["%s"] = {' % key)
        w("    season = %s," % lua_str(data["season"]))
        w("    statPriority = {")
        for entry in data["statPriority"]:
            w("        {")
            w("            builds = { %s },"
              % ", ".join(lua_str(b) for b in entry["builds"]))
            w("            context = %s," % lua_str(entry.get("context") or ""))
            w("            stats = {")
            for stat in entry["stats"]:
                w("                %s," % lua_str(stat))
            w("            },")
            w("        },")
        w("    },")
        w("    bis = {")
        for row in data["bis"]:
            extra = ""
            if row.get("bonus"):
                extra += " bonus = %s," % lua_str(row["bonus"])
            if row.get("catalystFrom"):
                extra += " catalystFrom = %d," % row["catalystFrom"]
            # Every field carries its own trailing comma before padding.
            # Formatting the itemID with %d and no comma produced
            # `itemID = 268213   source = ...`, which is a syntax error
            # the generator itself cannot see -- only running the Lua
            # parser over the output catches it.
            w("        { slot = %-14s itemID = %-9s source = %-30s%s }," % (
                lua_str(row["slot"]) + ",",
                str(row["itemID"]) + ",",
                lua_str(row["source"]) + ",", extra))
        w("    },")
        w("}")
        w()

    return "\n".join(L) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--spec", action="append")
    ap.add_argument("--out", default=OUT_PATH)
    ap.add_argument("--refresh", action="store_true",
                    help="bypass the page cache and refetch")
    args = ap.parse_args()

    targets = SPECS
    if args.spec:
        wanted = {s.upper() for s in args.spec}
        targets = [s for s in SPECS if s[0] in wanted]
        if not targets:
            print("no specs matched", file=sys.stderr)
            return 2

    results, problems, emptied = [], [], []
    for key, cls, spec, role in targets:
        stat_html = cached_fetch(STAT_URL.format(cls=cls, spec=spec, role=role),
                                 args.refresh)
        bis_html = cached_fetch(BIS_URL.format(cls=cls, spec=spec), args.refresh)
        if stat_html is None and bis_html is None:
            problems.append("%s: both pages 404" % key)
            continue

        stats, bis, season = [], [], ""
        if stat_html:
            markup = extract_markup(stat_html)
            stats = parse_stat_priority(markup)
            season = parse_season(markup)
        if bis_html:
            markup = extract_markup(bis_html)
            bis = parse_bis(markup)
            season = season or parse_season(markup)

        data = {"statPriority": stats, "bis": bis, "season": season}
        results.append((key, data))

        # Empty is not always wrong, but it is always worth a look. The
        # consumables scraper shipped three specs with no gems for a week
        # because nothing said so out loud.
        empty = [n for n in ("statPriority", "bis") if not data[n]]
        if empty:
            emptied.append("%s: no %s" % (key, ", ".join(empty)))

        stale = "" if season == CURRENT_SEASON else \
            "  [stale: %s]" % (season or "unknown season")
        print("%-24s %2d stat lists  %2d bis slots%s%s"
              % (key, len(stats), len(bis), stale,
                 "  <-- EMPTY: " + ", ".join(empty) if empty else ""))

    fixed = canonical_sources(results)
    if fixed:
        print("normalised %d source strings (one spelling per place)" % fixed)

    print("\n%d/%d specs parsed" % (len(results), len(targets)))
    if emptied:
        print("EMPTY CATEGORIES (check the guide before trusting these):")
        for e in emptied:
            print("  " + e)
    if problems:
        print("PROBLEMS:")
        for p in problems:
            print("  " + p)

    # A partial sweep must not overwrite a good file: shipping holes
    # silently is worse than not running at all.
    if problems and not args.spec:
        print("\nrefusing to write a partial file", file=sys.stderr)
        return 1
    if args.dry_run:
        return 0

    text = emit(results)
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    old = ""
    if os.path.exists(args.out):
        with open(args.out, encoding="utf-8") as fh:
            old = fh.read()
    # Ignore the date line when deciding whether anything changed, so a
    # no-op run leaves the file byte-identical instead of churning a diff.
    def strip_date(s):
        return re.sub(r'ns\.CLASS_GUIDE_SCRAPED_AT = "[^"]*"', "", s)
    if old and strip_date(old) == strip_date(text):
        print("no change")
        return 0
    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write(text)
    print("wrote %s" % args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
