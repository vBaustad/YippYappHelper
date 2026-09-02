#!/usr/bin/env python3
"""
Regenerate Features/Trinkets/TrinketTiers.lua from the trinket tier list
Wowhead's class guides publish.

Usage:
    python Tools/scrape_trinket_tiers.py            # write the Lua file
    python Tools/scrape_trinket_tiers.py --dry-run  # report only
    python Tools/scrape_trinket_tiers.py --spec MAGE_FIRE

WHY THIS EXISTS ALONGSIDE THE SIM DATA

TrinketData.lua ranks trinkets by simulated throughput and nothing else.
That is the right answer to "which of these two does more damage" and the
wrong answer to most of the questions people actually ask, because a sim
does not know that a trinket only drops from the Great Vault, that an
on-use wants pairing with a specific cooldown, or that two trinkets you
would never wear together both sim well alone. Wowhead's authors grade
with all of that in hand.

It also covers the one spec the sims cannot: bloodmallet does not sim
Augmentation Evoker and QE Live only does healers, so Augmentation has no
sim data at all. It has a tier list like everyone else.

NO EXTRA REQUESTS

The tier list lives inside the same /bis-gear page scrape_class_guides.py
already fetches, under a "Best <Spec> Trinkets in <Season>" heading, so
this shares that scraper's on-disk cache. A run right after a class-guide
run costs nothing.

WHAT THE MARKUP LOOKS LIKE

    [tier-list=rows grid]
      [tier]
        [tier-label bg=q5]S[/tier-label]
        [tier-content]
          [icon-badge=270164 quality=4 display-options=raid
                              tooltip="Trinket_1_Tooltip"]
    ...
    [tooltip name=Trinket_1_Tooltip]Passive Trinket. Overall Best.[/tooltip]

`display-options` is the content type the trinket comes from, and the
page declares its own label for each one. The [tooltip] bodies sit after
the guide's last section, which is why this reads unescape_markup() --
the whole document -- rather than extract_markup()'s slice.

TIER LABELS ARE NOT NORMALISED

Six different ladders are in use across the forty specs: most are S-D,
but one runs S+ down to F, another A+ through F, and Preservation Evoker
adds F and G below D. Rewriting those onto one scale would put words in
an author's mouth, so the label is stored verbatim and `rank` records
where it sat -- 1 for the top tier down -- which is what the UI sorts on.
"""

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from scrape_consumables import (  # noqa: E402
    CURRENT_SEASON, ROOT, SPECS, lua_str, parse_names, unescape_markup,
)
from scrape_class_guides import BIS_URL, cached_fetch  # noqa: E402

OUT_PATH = os.path.join(ROOT, "Features", "Trinkets", "TrinketTiers.lua")

# The heading that opens the trinket section. Wowhead words it with the
# spec and season baked in -- "Best Fire Mage Trinkets in Midnight Season
# 2" -- so match on the stable part and read the season back out of it.
TRINKET_H2 = re.compile(r"Trinkets\b", re.I)
SEASON_RE = re.compile(r"\bin\s+(.+?)\s*$")

# display-options value -> our own fallback label, used only when the
# page does not declare one. Wowhead's own wording wins where present,
# since "Mythic Plus" vs "Dungeons" is the author's call, not ours.
FALLBACK_CATEGORY = {
    "raid": "Raid",
    "dungeon": "Mythic+",
    "delves": "Delves",
    "crafting": "Crafting",
    "pvp": "PvP",
    "world": "World",
}


def strip_tags(text, names=None):
    """Guide prose with the BBCode taken out but the words left in.

    Item and spell links carry the sentence rather than decorate it --
    "Pairs perfectly with [item=270175]" says nothing once the token is
    dropped -- so they resolve to the name Wowhead's own gatherer data
    gives them. A link to something the page never described falls back
    to dropping the token, which is the old behaviour and still better
    than printing a bare number at a reader.
    """
    names = names or {}
    items = names.get("item", {})
    spells = names.get("spell", {})

    def sub(table):
        def inner(m):
            return table.get(int(m.group(1)), "")
        return inner

    text = re.sub(r"\[item=(\d+)[^\]]*\]", sub(items), text)
    text = re.sub(r"\[spell=(\d+)[^\]]*\]", sub(spells), text)
    text = re.sub(r"\[/?[^\]]*\]", "", text)
    text = text.replace("\r", "")
    text = re.sub(r"[ \t]+", " ", text)
    # A link that resolved to nothing leaves the space that was in front
    # of it sitting against the punctuation that followed.
    text = re.sub(r" +([.,;:!?])", r"\1", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def find_section(markup):
    """The slice of markup under the trinket heading, and its season.

    Returns (body, season) or (None, None). The section ends at the next
    [h2, since the tier list is never the last thing on the page.
    """
    heads = [(m.start(), m.end(), m.group(1))
             for m in re.finditer(r"\[h2[^\]]*\](.*?)\[/h2\]", markup, re.S)]
    for i, (start, end, raw) in enumerate(heads):
        title = strip_tags(raw)
        if not TRINKET_H2.search(title):
            continue
        stop = heads[i + 1][0] if i + 1 < len(heads) else len(markup)
        season = None
        sm = SEASON_RE.search(title)
        if sm:
            season = sm.group(1).strip()
        return markup[end:stop], season
    return None, None


def parse_categories(section, names=None):
    """display-options value -> the label the page gives it."""
    out = {}
    for value, label in re.findall(
            r"\[display-option=(\w+)[^\]]*\](.*?)\[/display-option\]",
            section, re.S):
        label = strip_tags(label, names)
        if label:
            out[value] = label
    return out


def parse_notes(markup, names=None):
    """[tooltip name=X]body[/tooltip] -> {X: body}, whole document."""
    out = {}
    for name, body in re.findall(
            r"\[tooltip name=([A-Za-z0-9_]+)\](.*?)\[/tooltip\]",
            markup, re.S):
        body = strip_tags(body, names)
        if body:
            out[name] = body
    return out


def parse_tiers(section, categories, notes):
    """The tier list, best tier first.

    A trinket listed in two tiers keeps the better one -- that is an
    authoring slip rather than a statement, and showing a trinket as both
    S and C is worse than picking the one the author meant first.
    """
    tiers, seen = [], set()
    for block in re.findall(r"\[tier\](.*?)\[/tier\]", section, re.S):
        lm = re.search(r"\[tier-label[^\]]*\](.*?)\[/tier-label\]", block, re.S)
        if not lm:
            continue
        label = strip_tags(lm.group(1))
        items = []
        for item_id, attrs in re.findall(r"\[icon-badge=(\d+)([^\]]*)\]", block):
            item_id = int(item_id)
            if item_id in seen:
                continue
            seen.add(item_id)
            cm = re.search(r"display-options=(\w+)", attrs)
            value = cm.group(1) if cm else None
            tm = re.search(r'tooltip="([^"]+)"', attrs)
            items.append({
                "id": item_id,
                "from": (categories.get(value)
                         or FALLBACK_CATEGORY.get(value)
                         or None),
                "note": notes.get(tm.group(1)) if tm else None,
            })
        if items:
            tiers.append({"label": label or "?", "items": items})
    return tiers


def parse_intro(section, names=None):
    """The prose above the tier list.

    This is where the pairing advice lives -- one on-use plus one passive,
    which stats the spec wants out of the slot -- and it is the part a
    ranked list cannot say. Everything from the [center] block onward is
    the widget and its "hover for notes" instruction, which is about
    Wowhead's page rather than about trinkets.
    """
    cut = section.find("[center]")
    if cut < 0:
        cut = section.find("[tier-list")
    return strip_tags(section[:cut] if cut > 0 else section, names)


def scrape(key, cls, spec, refresh=False):
    html = cached_fetch(BIS_URL.format(cls=cls, spec=spec), refresh=refresh)
    if not html:
        return None
    markup = unescape_markup(html)
    section, season = find_section(markup)
    if not section or "[tier-list" not in section:
        return None
    # Names for the [item=] and [spell=] links the notes are written
    # around, off the page's own gatherer payload rather than a second
    # lookup. Only the prose needs them -- the trinkets themselves are
    # stored as bare IDs and named at runtime.
    names = parse_names(html)
    categories = parse_categories(section, names)
    tiers = parse_tiers(section, categories, parse_notes(markup, names))
    if not tiers:
        return None
    return {
        "season": season or CURRENT_SEASON,
        "intro": parse_intro(section, names),
        "tiers": tiers,
    }


def emit(all_specs, scraped_at):
    L = []
    add = L.append
    add("local _, ns = ...")
    add("")
    add("---" + "-" * 57)
    add("-- Trinket tier list per class/spec, from Wowhead's class guides.")
    add("--")
    add("-- GENERATED FILE - do not hand-edit.")
    add("-- Regenerate with:  python Tools/scrape_trinket_tiers.py")
    add("--")
    add("-- This is the editorial answer, not the simulated one. It knows")
    add("-- what a sim cannot: that a trinket wants pairing with a specific")
    add("-- cooldown, that another only drops from the Great Vault, that two")
    add("-- that both sim well are never worn together. Read alongside")
    add("-- TrinketData.lua rather than instead of it -- and note this is")
    add("-- the only trinket data Augmentation Evoker has at all, since")
    add("-- bloodmallet does not sim it and QE Live covers only healers.")
    add("--")
    add("-- `rank` is 1 for the top tier downward. Sort on that, not on the")
    add("-- label: the forty specs use six different ladders between them")
    add("-- (S-D mostly, but also S+ and A+ at the top and F and G below D),")
    add("-- and the labels are the authors' own wording, kept verbatim.")
    add("--")
    add("-- `from` is the content the trinket drops from, worded as the")
    add("-- guide words it. `note` is the author's hover note, present on")
    add("-- the trinkets they chose to annotate and nil on the rest.")
    add("--")
    add("-- Item names are NOT stored. They resolve from the ID at runtime,")
    add("-- which localises for free and survives a rename.")
    add("---" + "-" * 57)
    add("")
    add("ns.TrinketTiers = {}")
    add('ns.TRINKET_TIER_SOURCE = "Wowhead class guides"')
    add('ns.TRINKET_TIER_TARGET_SEASON = %s' % lua_str(CURRENT_SEASON))
    add('ns.TRINKET_TIER_SCRAPED_AT = %s' % lua_str(scraped_at))
    add("")

    for key in sorted(all_specs):
        block = all_specs[key]
        add('ns.TrinketTiers["%s"] = {' % key)
        add("    season = %s," % lua_str(block["season"]))
        if block["intro"]:
            add("    intro = %s," % lua_str(block["intro"]))
        add("    tiers = {")
        for rank, tier in enumerate(block["tiers"], start=1):
            add("        { label = %s, rank = %d, items = {"
                % (lua_str(tier["label"]), rank))
            for item in tier["items"]:
                bits = ["id = %d" % item["id"]]
                if item["from"]:
                    bits.append("from = %s" % lua_str(item["from"]))
                if item["note"]:
                    bits.append("note = %s" % lua_str(item["note"]))
                add("            { %s }," % ", ".join(bits))
            add("        } },")
        add("    },")
        add("}")
        add("")
    return "\n".join(L).rstrip("\n") + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--spec", action="append", help="limit to these addon keys")
    ap.add_argument("--out", default=OUT_PATH)
    ap.add_argument("--refresh", action="store_true",
                    help="ignore the on-disk page cache")
    ap.add_argument("--date", help="value for TRINKET_TIER_SCRAPED_AT")
    args = ap.parse_args()

    wanted = set(args.spec or [])
    results, missing = {}, []
    for key, cls, spec, _role in SPECS:
        if wanted and key not in wanted:
            continue
        block = scrape(key, cls, spec, refresh=args.refresh)
        if not block:
            missing.append(key)
            print("%-26s no tier list" % key)
            continue
        results[key] = block
        counts = " ".join("%s:%d" % (t["label"], len(t["items"]))
                          for t in block["tiers"])
        notes = sum(1 for t in block["tiers"] for i in t["items"] if i["note"])
        stale = "" if block["season"] == CURRENT_SEASON \
            else "  [%s]" % block["season"]
        print("%-26s %-46s %2d notes%s" % (key, counts, notes, stale))

    print()
    print("%d/%d specs parsed" % (len(results), len(SPECS) if not wanted
                                  else len(wanted)))
    if missing:
        print("no tier list for: %s" % ", ".join(missing))
    behind = [k for k, v in results.items() if v["season"] != CURRENT_SEASON]
    if behind:
        print("behind %s: %s" % (CURRENT_SEASON, ", ".join(sorted(behind))))

    if args.dry_run:
        print("\ndry run - nothing written")
        return 0
    if not results:
        print("\nnothing parsed - refusing to write an empty file")
        return 1

    scraped_at = args.date
    if not scraped_at:
        import datetime
        scraped_at = datetime.date.today().isoformat()
    with open(args.out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(emit(results, scraped_at))
    print("\nwrote %s" % args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
