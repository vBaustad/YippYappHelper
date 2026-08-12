#!/usr/bin/env python3
"""
Regenerate Features/Consumables/ConsumablesData.lua from Wowhead's
per-spec "Enchants, Gems & Consumables" guides.

Usage:
    python Tools/scrape_consumables.py            # write the Lua file
    python Tools/scrape_consumables.py --dry-run  # report only
    python Tools/scrape_consumables.py --spec DEMONHUNTER_VENGEANCE

Why this works without a browser: Wowhead server-renders each guide's
source markup (their own BBCode dialect) into the page HTML. That markup
is far easier and more stable to parse than the rendered DOM, because
every recommendation is an explicit [item=ID] token inside a labelled
table row.

The scraper records the season each guide claims ("Midnight Season 1",
"Midnight Season 2", ...). ConsumablesUI shows a staleness warning when a
spec's guide has not been refreshed for the current season, so a stale
scrape is visible in-game rather than silently wrong.
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

# The season the addon currently targets. Guides still labelled with an
# older season are flagged rather than dropped — a Season 1 recommendation
# is usually still directionally right on day one of Season 2.
CURRENT_SEASON = "Midnight Season 2"

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_PATH = os.path.join(ROOT, "Features", "Consumables", "ConsumablesData.lua")

# (addon key, class slug, spec slug, role slug)
SPECS = [
    ("DEATHKNIGHT_BLOOD",        "death-knight", "blood",         "tank"),
    ("DEATHKNIGHT_FROST",        "death-knight", "frost",         "dps"),
    ("DEATHKNIGHT_UNHOLY",       "death-knight", "unholy",        "dps"),
    ("DEMONHUNTER_HAVOC",        "demon-hunter", "havoc",         "dps"),
    ("DEMONHUNTER_VENGEANCE",    "demon-hunter", "vengeance",     "tank"),
    ("DEMONHUNTER_DEVOURER",     "demon-hunter", "devourer",      "dps"),
    ("DRUID_BALANCE",            "druid",        "balance",       "dps"),
    ("DRUID_FERAL",              "druid",        "feral",         "dps"),
    ("DRUID_GUARDIAN",           "druid",        "guardian",      "tank"),
    ("DRUID_RESTORATION",        "druid",        "restoration",   "healer"),
    ("EVOKER_DEVASTATION",       "evoker",       "devastation",   "dps"),
    ("EVOKER_PRESERVATION",      "evoker",       "preservation",  "healer"),
    ("EVOKER_AUGMENTATION",      "evoker",       "augmentation",  "dps"),
    ("HUNTER_BEASTMASTERY",      "hunter",       "beast-mastery", "dps"),
    ("HUNTER_MARKSMANSHIP",      "hunter",       "marksmanship",  "dps"),
    ("HUNTER_SURVIVAL",          "hunter",       "survival",      "dps"),
    ("MAGE_ARCANE",              "mage",         "arcane",        "dps"),
    ("MAGE_FIRE",                "mage",         "fire",          "dps"),
    ("MAGE_FROST",               "mage",         "frost",         "dps"),
    ("MONK_BREWMASTER",          "monk",         "brewmaster",    "tank"),
    ("MONK_MISTWEAVER",          "monk",         "mistweaver",    "healer"),
    ("MONK_WINDWALKER",          "monk",         "windwalker",    "dps"),
    ("PALADIN_HOLY",             "paladin",      "holy",          "healer"),
    ("PALADIN_PROTECTION",       "paladin",      "protection",    "tank"),
    ("PALADIN_RETRIBUTION",      "paladin",      "retribution",   "dps"),
    ("PRIEST_DISCIPLINE",        "priest",       "discipline",    "healer"),
    ("PRIEST_HOLY",              "priest",       "holy",          "healer"),
    ("PRIEST_SHADOW",            "priest",       "shadow",        "dps"),
    ("ROGUE_ASSASSINATION",      "rogue",        "assassination", "dps"),
    ("ROGUE_OUTLAW",             "rogue",        "outlaw",        "dps"),
    ("ROGUE_SUBTLETY",           "rogue",        "subtlety",      "dps"),
    ("SHAMAN_ELEMENTAL",         "shaman",       "elemental",     "dps"),
    ("SHAMAN_ENHANCEMENT",       "shaman",       "enhancement",   "dps"),
    ("SHAMAN_RESTORATION",       "shaman",       "restoration",   "healer"),
    ("WARLOCK_AFFLICTION",       "warlock",      "affliction",    "dps"),
    ("WARLOCK_DEMONOLOGY",       "warlock",      "demonology",    "dps"),
    ("WARLOCK_DESTRUCTION",      "warlock",      "destruction",   "dps"),
    ("WARRIOR_ARMS",             "warrior",      "arms",          "dps"),
    ("WARRIOR_FURY",             "warrior",      "fury",          "dps"),
    ("WARRIOR_PROTECTION",       "warrior",      "protection",    "tank"),
]

BASE = "https://www.wowhead.com/guide/classes/{cls}/{spec}/enchants-gems-pve-{role}"


# ---------------------------------------------------------------- fetch

def fetch(url, retries=3):
    last = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
                "Accept-Encoding": "gzip",
            })
            with urllib.request.urlopen(req, timeout=60) as r:
                raw = r.read()
                gz = r.headers.get("Content-Encoding") == "gzip"
            if gz:
                raw = gzip.decompress(raw)
            return raw.decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            last = e
        except Exception as e:  # noqa: BLE001 - network flakiness
            last = e
        time.sleep(1.5 * (attempt + 1))
    raise RuntimeError("fetch failed for %s: %s" % (url, last))


def extract_markup(html):
    """Pull Wowhead's guide BBCode out of the page's embedded JS string.

    The guide lives inside a JS string literal, so every closing tag
    arrives as `[\\/h3]` rather than `[/h3]`. Undo the escapes *before*
    looking for the section markers, or the end marker is never found.
    """
    text = html.replace("\\/", "/").replace('\\"', '"')
    text = text.replace("\\r\\n", "\n").replace("\\n", "\n").replace("\\t", "\t")

    start = text.find("[h2 ")
    if start < 0:
        return None
    end = max(text.rfind("[/h3]"), text.rfind("[/h2]"), text.rfind("[/table]"))
    if end < 0 or end <= start:
        return None
    return text[start:end + 8]


# ---------------------------------------------------------------- parse

def parse_names(html):
    """id -> display name, per Wowhead gatherer type (3=item, 6=spell)."""
    names = {"item": {}, "spell": {}}
    for m in re.finditer(r"WH\.Gatherer\.addData\((\d+),\s*\d+,\s*(\{[\s\S]*?\})\);",
                         html):
        kind = {"3": "item", "6": "spell"}.get(m.group(1))
        if not kind:
            continue
        for im in re.finditer(r'"(\d+)":\{"name_enus":"((?:[^"\\]|\\.)*)"',
                              m.group(2)):
            raw = im.group(2).replace('\\"', '"').replace("\\/", "/")
            # Item names are prefixed with a quality digit on some rows.
            names[kind][int(im.group(1))] = re.sub(r"^\d(?=\D)", "", raw).strip()
    return names


# Trailing page furniture that is not part of the advice.
BOILERPLATE = re.compile(
    r"(Our [A-Za-z' ]+ guides are always updated"
    r"|Previous Page:"
    r"|Next Page:"
    r"|If you are interested in more in-depth"
    r"|Make sure to check our changelog)")


def strip_bbcode(text, names=None):
    """Turn guide BBCode into readable plain text for the in-game panel.

    Item and spell references are resolved to their real names — the
    in-game panel renders this as plain text, so leaving `[item=241325]`
    (or a `{item:...}` placeholder) would show the player a raw ID.
    """
    names = names or {"item": {}, "spell": {}}
    t = text

    def name_for(kind, iid):
        return names.get(kind, {}).get(int(iid))

    def sub_ref(kind):
        def repl(m):
            got = name_for(kind, m.group(1))
            return got if got else ""
        return repl

    t = re.sub(r"\[item=(\d+)[^\]]*\]", sub_ref("item"), t)
    t = re.sub(r"\[spell=(\d+)[^\]]*\]", sub_ref("spell"), t)
    t = re.sub(r"\[url=\"?([^\]\"]+)\"?\]", "", t)
    t = re.sub(r"\[/url\]", "", t)
    t = re.sub(r"\[/?(b|i|u|ul|ol|li|pad|center|color[^\]]*|size[^\]]*)\]", "", t)
    t = re.sub(r"\[icon[^\]]*\]\[/icon\]", "", t)
    t = re.sub(r"\[[^\]]*\]", "", t)
    t = t.replace("&nbsp;", " ").replace("&amp;", "&")
    t = t.replace("&quot;", '"').replace("&#39;", "'").replace("&lt;", "<").replace("&gt;", ">")
    cut = BOILERPLATE.search(t)
    if cut:
        t = t[:cut.start()]
    t = re.sub(r"[ \t]+", " ", t)
    t = re.sub(r" *\n *", "\n", t)
    t = re.sub(r"\n{3,}", "\n\n", t)
    # Tidy artefacts left behind by unresolved references.
    t = re.sub(r"\(\s*[,/]?\s*\)", "", t)
    t = re.sub(r"\s+([,.;:])", r"\1", t)
    t = re.sub(r"([,/])\1+", r"\1", t)
    return t.strip()


def parse_tables(markup):
    """Return every [table]...[/table] block as a list of row cell-lists.

    Some guides are hand-authored and ship a table with no closing tag
    (Fire Mage's consumables table, for one), so also stop at the next
    structural boundary. Without this the whole table is dropped and the
    spec silently ends up with zero consumables.
    """
    tables = []
    pattern = r"\[table[^\]]*\]([\s\S]*?)(?:\[/table\]|\[/center\]|\[h2 |\[h3 |$)"
    for tbl in re.findall(pattern, markup):
        rows = []
        for tr in re.findall(r"\[tr\]([\s\S]*?)\[/tr\]", tbl):
            cells = re.findall(r"\[td[^\]]*\]([\s\S]*?)\[/td\]", tr)
            rows.append(cells)
        if rows:
            tables.append(rows)
    return tables


def cell_items(cell):
    return [int(x) for x in re.findall(r"\[item=(\d+)", cell)]


def cell_label(cell):
    return strip_bbcode(cell).strip()


def split_h2(markup):
    """Split the guide into its top-level [h2] blocks: title -> body."""
    out = []
    parts = re.split(r"\[h2[^\]]*\]([\s\S]*?)\[/h2\]", markup)
    for i in range(1, len(parts), 2):
        title = re.sub(r"\[[^\]]*\]", "", parts[i]).strip()
        body = parts[i + 1] if i + 1 < len(parts) else ""
        out.append((title, body))
    return out


def parse_sections(block, names):
    """Map each [h3] heading inside one h2 block to the prose beneath it.

    Scoped to a single h2 block on purpose: splitting the whole guide at
    once let the last enchant section swallow the entire consumables
    chapter, tables and all.
    """
    out = {}
    parts = re.split(r"\[h3[^\]]*\]([\s\S]*?)\[/h3\]", block)
    for i in range(1, len(parts), 2):
        title = re.sub(r"\[[^\]]*\]", "", parts[i]).strip()
        body = parts[i + 1] if i + 1 < len(parts) else ""
        # Drop tables from prose — their contents are already structured
        # data, and flattening them produces unreadable run-on text.
        body = re.sub(r"\[table[^\]]*\][\s\S]*?(?:\[/table\]|\[/center\])",
                      "", body)
        out[title] = strip_bbcode(body, names)
    return out


def raw_sections(block):
    """Section bodies with the BBCode left intact.

    parse_sections() runs strip_bbcode over each body, which is correct
    for the prose it feeds to the UI but destroys every [item=ID] token
    on the way. Anything extracting items needs the markup, so it needs
    this instead -- and it needs it per section, or gem bullets get read
    out of enchant prose two headings away.
    """
    out = {}
    parts = re.split(r"\[h3[^\]]*\]([\s\S]*?)\[/h3\]", block)
    for i in range(1, len(parts), 2):
        title = re.sub(r"\[[^\]]*\]", "", parts[i]).strip()
        out[title] = parts[i + 1] if i + 1 < len(parts) else ""
    return out


ENCHANT_SLOT_ROWS = {
    "helm": "Head", "head": "Head", "chest": "Chest", "shoulders": "Shoulders",
    "shoulder": "Shoulders", "legs": "Legs", "boots": "Boots", "feet": "Boots",
    "ring": "Ring", "rings": "Ring", "cloak": "Cloak", "back": "Cloak",
    "bracers": "Bracers", "wrist": "Bracers", "weapon": "Weapon",
    "weapons": "Weapon", "main hand": "Weapon", "off hand": "Off Hand",
}

GEM_ROW_HINTS = ("gem", "diamond")

CONSUMABLE_LABELS = {
    "flask": "Flask", "combat potion": "Combat Potion", "potion": "Combat Potion",
    "health potion": "Health Potion", "healing potion": "Health Potion",
    "weapon buff": "Weapon Buff", "augment rune": "Augment Rune",
    "food": "Food", "rune": "Augment Rune", "oil": "Weapon Buff",
    "stone": "Weapon Buff",
}


def consumable_label(low):
    """Longest keyword wins, so 'health potion' beats bare 'potion'."""
    best = None
    for kw, pretty in sorted(CONSUMABLE_LABELS.items(),
                             key=lambda kv: -len(kv[0])):
        if kw in low:
            best = pretty
            break
    return best


def parse_spec(markup, names):
    tables = parse_tables(markup)

    # Guide text, scoped per top-level chapter so enchant prose and
    # consumable prose never mix.
    gem_enchant_body, consumable_body = "", ""
    for title, body in split_h2(markup):
        tl = title.lower()
        if "consumable" in tl:
            consumable_body += body
        elif "enchant" in tl or "gem" in tl:
            gem_enchant_body += body

    ge_sections = parse_sections(gem_enchant_body, names)
    co_sections = parse_sections(consumable_body, names)

    enchants, gems, consumables = [], [], []

    # Classify every row on its own label rather than on the table header.
    # Header wording varies per guide ("Type/Best", "Consumable/Best in
    # Slot", ...) and header sniffing silently dropped whole tables for
    # specs like Augmentation Evoker and Fire Mage.
    for rows in tables:
        for cells in rows:
            if len(cells) < 2:
                continue
            label = cell_label(cells[0])
            low = label.lower().strip()
            if not low or low in ("slot", "type", "consumable", "stat"):
                continue  # header row
            ids = cell_items(cells[1])
            alts = cell_items(cells[2]) if len(cells) > 2 else []
            if not ids:
                continue

            if any(h in low for h in GEM_ROW_HINTS):
                gems.append({"label": label, "itemID": ids[0],
                             "alt": alts[0] if alts else None})
            elif low in ENCHANT_SLOT_ROWS:
                enchants.append({"slot": ENCHANT_SLOT_ROWS[low],
                                 "itemID": ids[0],
                                 "alt": alts[0] if alts else None})
            else:
                entry = {"label": consumable_label(low) or label,
                         "itemID": ids[0]}
                extra = ids[1:] + alts
                if extra:
                    entry["alt"] = extra[0]
                consumables.append(entry)

    # Per-colour gem picks are written as bullets under the Gems heading,
    # e.g. "[b]Peridot[/b]: [item=240894]". Search only the gems chapter —
    # scanning the whole guide also swept up prose bullets like
    # "Raiding: <potion>" and filed potions as gems.
    # Scope to the Gems section itself. This used to locate the right
    # section and then assign the whole enchants+gems body regardless,
    # which the old narrow bullet regex hid: it matched so little that
    # the over-broad haystack never showed. Widen the pattern and the
    # bug surfaces instantly as Vengeance "recommending" 23 gems, half
    # of them picked out of enchant prose and alternate-scenario asides.
    gem_chunk = ""
    for k, v in raw_sections(gem_enchant_body).items():
        if "gem" in k.lower():
            gem_chunk += v
    if gem_chunk:
        # Guides write gem bullets in at least two dialects, and an
        # earlier pattern that only understood the first silently
        # under-parsed 17 of 40 specs -- Enhancement Shaman came out with
        # zero gems while its page listed six.
        #
        #   Frost Mage:   [li][b]Amethyst[/b]: [item=240898][/li]
        #   Enhancement:  [li][color=q6]Other Gems[/color] [b]&ndash;[/b]
        #                 one each of [item=A], [item=B], [item=C] & [item=D]
        #
        # So: split into bullets, take the label from whichever wrapper
        # opens it, and collect EVERY item in the bullet rather than the
        # first. The multi-item case is the one that hurt most -- "one
        # each of A, B, C & D" is four gems, and only A was being kept.
        #
        # Splitting on [li] also flattens nested [ul] lists for free: the
        # outer "With 5+ Sockets" bullet holds no items of its own and
        # contributes nothing, while each inner bullet gets its own
        # fragment.
        for frag in re.split(r"\[li\]", gem_chunk):
            ids = [int(x) for x in re.findall(r"\[item=(\d+)", frag)]
            if not ids:
                continue
            lab = re.match(r"\s*\[b\]([^\[]+)\[/b\]", frag) \
                or re.match(r"\s*\[color=[^\]]*\]([^\[]+)\[/color\]", frag)
            label = lab.group(1).strip(" :-–&;ndash") if lab else "Gem"
            for iid in ids:
                resolved = names["item"].get(iid, "")
                if "gem" not in label.lower() and not re.search(
                        r"peridot|lapis|garnet|amethyst|diamond|ruby|sapphire|"
                        r"emerald|topaz|onyx", (label + " " + resolved).lower()):
                    continue
                if not any(g["itemID"] == iid for g in gems):
                    gems.append({"label": label, "itemID": iid, "alt": None})

    def joined(sections, *keys, exclude=()):
        seen, chunks = set(), []
        for k, v in sections.items():
            kl = k.lower()
            if not v or any(x in kl for x in exclude):
                continue
            if keys and not any(x in kl for x in keys):
                continue
            if v in seen:
                continue
            seen.add(v)
            chunks.append(v)
        return "\n\n".join(chunks)

    season = None
    m = re.search(r"(Midnight Season \d+|The War Within Season \d+)", markup)
    if m:
        season = m.group(1)

    return {
        "enchants": enchants,
        "gems": gems,
        "consumables": consumables,
        "enchantGuide": joined(ge_sections, exclude=("gem",)),
        "gemGuide": joined(ge_sections, "gem"),
        "consumableGuide": joined(co_sections),
        "season": season,
    }


# ------------------------------------------------------------------ emit

def lua_str(s):
    if not s:
        return '""'
    s = s.replace("\\", "\\\\").replace('"', '\\"')
    s = s.replace("\r", "").replace("\n", "\\n")
    return '"%s"' % s


def emit(all_specs):
    L = []
    add = L.append
    add("local _, ns = ...")
    add("")
    add("---" + "-" * 57)
    add("-- Consumables & Enchant data per class/spec")
    add("-- Key format: \"CLASS_SPEC\" (e.g. \"ROGUE_SUBTLETY\")")
    add("--")
    add("-- GENERATED FILE — do not hand-edit.")
    add("-- Regenerate with:  python Tools/scrape_consumables.py")
    add("-- Source: Wowhead per-spec enchants/gems/consumables guides.")
    add("--")
    add("-- Each spec records the season its guide was written for. The")
    add("-- Consumables page shows a staleness banner when that is behind")
    add("-- ns.CONSUMABLES_TARGET_SEASON, so out-of-date advice is visible")
    add("-- in-game instead of silently wrong.")
    add("---" + "-" * 57)
    add("")
    add("ns.ConsumablesDB = {}")
    add("ns.CONSUMABLES_TARGET_SEASON = %s" % lua_str(CURRENT_SEASON))
    add("ns.CONSUMABLES_SCRAPED_AT = %s" % lua_str(
        time.strftime("%Y-%m-%d", time.gmtime())))
    add("")

    for key, data in all_specs:
        add('ns.ConsumablesDB["%s"] = {' % key)
        add("    season = %s," % lua_str(data.get("season")))

        add("    enchants = {")
        for e in data["enchants"]:
            alt = (", alt = %d" % e["alt"]) if e.get("alt") else ""
            add('        { slot = %-14s itemID = %d%s },'
                % (lua_str(e["slot"]) + ",", e["itemID"], alt))
        add("    },")
        add("    enchantGuide = %s," % lua_str(data["enchantGuide"]))

        add("    gems = {")
        for g in data["gems"]:
            alt = (", alt = %d" % g["alt"]) if g.get("alt") else ""
            add('        { label = %s, itemID = %d%s },'
                % (lua_str(g["label"]), g["itemID"], alt))
        add("    },")
        add("    gemGuide = %s," % lua_str(data["gemGuide"]))

        add("    consumables = {")
        for c in data["consumables"]:
            alt = (", alt = { itemID = %d }" % c["alt"]) if c.get("alt") else ""
            add('        { label = %s, itemID = %d%s },'
                % (lua_str(c["label"]), c["itemID"], alt))
        add("    },")
        add("    consumableGuide = %s," % lua_str(data["consumableGuide"]))
        add("}")
        add("")

    return "\n".join(L) + "\n"


# ------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--spec", action="append", help="limit to these addon keys")
    ap.add_argument("--out", default=OUT_PATH)
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
        url = BASE.format(cls=cls, spec=spec, role=role)
        html = fetch(url)
        if html is None:
            problems.append("%s: 404 %s" % (key, url))
            continue
        markup = extract_markup(html)
        if not markup:
            problems.append("%s: no guide markup found" % key)
            continue
        data = parse_spec(markup, parse_names(html))
        if not data["enchants"] and not data["consumables"]:
            problems.append("%s: parsed 0 enchants and 0 consumables" % key)
            continue
        results.append((key, data))

        # An empty category is the failure that actually happens, and it
        # used to pass silently: the guard above only fires when BOTH
        # enchants and consumables are empty, so Enhancement Shaman
        # shipped `gems = {}` for a page that listed six of them, and
        # nothing said a word. Seventeen specs were under-parsed before
        # anyone noticed. Empty is not always wrong -- but it is always
        # worth a look, so say so on the line and again at the end.
        empty = [name for name in ("enchants", "gems", "consumables")
                 if not data[name]]
        if empty:
            emptied.append("%s: no %s" % (key, ", ".join(empty)))

        stale = "" if data["season"] == CURRENT_SEASON else \
            "  [stale: %s]" % (data["season"] or "unknown season")
        print("%-24s %2d enchants  %2d gems  %2d consumables%s%s"
              % (key, len(data["enchants"]), len(data["gems"]),
                 len(data["consumables"]), stale,
                 "  <-- EMPTY: " + ", ".join(empty) if empty else ""))
        time.sleep(0.4)  # be polite to Wowhead

    print("\n%d/%d specs parsed" % (len(results), len(targets)))
    if emptied:
        print("EMPTY CATEGORIES (check the guide before trusting these):")
        for e in emptied:
            print("  " + e)
    if problems:
        print("PROBLEMS:")
        for p in problems:
            print("  " + p)

    if args.dry_run:
        return 0
    if len(results) < len(targets):
        print("\nRefusing to write a partial file — fix the problems above "
              "or rerun. (Use --spec to retry individual specs.)",
              file=sys.stderr)
        return 1

    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        f.write(emit(results))
    print("\nwrote %s" % args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
