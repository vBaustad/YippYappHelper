#!/usr/bin/env python3
"""Regenerate Features/MythicPlus/UtilityData.lua.

    python Tools/build_utility.py [path-to-AddOns]

WHAT THIS READS, AND WHAT IT DOES NOT
-------------------------------------
Mythic Plus Utility (by Nikyou) curates something genuinely hard: for
every dungeon mechanic, which category of player utility answers it --
expressed as tags like [enrage], [poison], [creature_stun]. Its other
table tags each class's toolkit the same way, so "what should I bring"
becomes a set intersection.

This reads those two tables for the FACTS in them: spell ids, mechanic
names and tags. It does not read their prose, and none of their text
reaches our file. The lead lines, descriptions and per-spell notes below
are ours, written against the mechanic list the tags describe -- the
same way the previous season's entries were written.

MPU ships no licence, so keeping this derivation explicit, narrow and
regenerable matters more than it would with a permissive one. If their
data ever needs to ship verbatim instead, that is a conversation with
the author, not something to do quietly.

Neither this script nor its output is a substitute for running the
dungeon: where a note here disagrees with the game, the game is right.
"""

import io
import os
import re
import sys
from datetime import date

DEFAULT_ADDONS = r"S:\Blizzard\World of Warcraft\_retail_\Interface\AddOns"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Features", "MythicPlus", "UtilityData.lua")

CLASSES = ["DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MAGE",
           "MONK", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"]

SPECS = {
    "DEATHKNIGHT": [250, 251, 252], "DEMONHUNTER": [577, 581, 1480],
    "DRUID": [102, 103, 104, 105], "EVOKER": [1467, 1468, 1473],
    "HUNTER": [253, 254, 255], "MAGE": [62, 63, 64],
    "MONK": [268, 270, 269], "PALADIN": [65, 66, 70],
    "PRIEST": [256, 257, 258], "ROGUE": [259, 260, 261],
    "SHAMAN": [262, 263, 264], "WARLOCK": [265, 266, 267],
    "WARRIOR": [71, 72, 73],
}

# Ours, not theirs: MPU does not track interrupts as utility at all (it
# notes "this cast can be interrupted" in prose instead). Every entry
# leads with one, because every one of these dungeons has casts worth
# stopping and it is the first thing anyone looks for.
INTERRUPT = {
    "DEATHKNIGHT": (47528, "Mind Freeze"), "DEMONHUNTER": (183752, "Disrupt"),
    "DRUID": (106839, "Skull Bash"), "EVOKER": (351338, "Quell"),
    "HUNTER": (147362, "Counter Shot"), "MAGE": (2139, "Counterspell"),
    "MONK": (116705, "Spear Hand Strike"), "PALADIN": (96231, "Rebuke"),
    "PRIEST": (15487, "Silence"), "ROGUE": (1766, "Kick"),
    "SHAMAN": (57994, "Wind Shear"), "WARLOCK": (19647, "Spell Lock"),
    "WARRIOR": (6552, "Pummel"),
}
# Priest's is Shadow-only, and the old entries said so every time.
INTERRUPT_NOTE = {"PRIEST": "Shadow interrupt"}

MAX_PER_CLASS = 7

# ----------------------------------------------------------------- ours
#
# One entry per dungeon in the current pool. `lead` is the sentence under
# the header, `description` the paragraph, and `notes` attaches a reason
# to a specific spell -- the part actually worth arguing about.

EDITORIAL = {
    2993: dict(
        name="Altar of Fangs",
        lead="Hard CC on Evolve, poison dispels behind the interrupts, one enrage to strip.",
        description=(
            "Evolve is the channel that defines the pull -- stun, fear, incapacitate or grip "
            "it, and it is a humanoid, so humanoid CC works too. Envenom and Mass Envenom are "
            "interruptible poisons, and whatever lands wants a poison dispel. Regurgitate on "
            "the first boss carries a disease as well as a snare, and it can be sidestepped "
            "entirely. Toxic Atrophy on the second boss is interruptible. Ravenous Claws is a "
            "removable enrage, and Gorge is a self-buff that wants Mortal Wounds on it."),
        notes={
            2908: "Ravenous Claws is the enrage worth the talent here",
            19801: "Tranquilizing Shot -- Ravenous Claws",
            5938: "Shiv strips Ravenous Claws",
            207167: "AoE incap straight into an Evolve channel",
            99: "AoE incap on the Evolve packs",
        },
    ),
    2825: dict(
        name="Den of Nalorakk",
        lead="Freedom from roots and snares, a curse dispel, and two enrages worth stripping.",
        description=(
            "Glacial Tomb and Rime Detonation lock you in place, and the answer is movement "
            "freedom or a root break rather than a health bar. Frigid Roar and Healing Breeze "
            "are both interruptible, and Healing Breeze is a purge target that also wants "
            "Mortal Wounds on the caster. Insatiable Hunger is a curse. Toxic Spores on the "
            "first boss is a poison. Bestial Wrath and Mother's Wrath are both removable "
            "enrages, and Razor Dive keeps a bleed rolling underneath all of it."),
        notes={
            2908: "Two enrages here: Bestial Wrath and Mother's Wrath",
            19801: "Tranquilizing Shot covers both enrages",
            1044: "Blessing of Freedom beats Glacial Tomb outright",
            475: "Remove Curse -- Insatiable Hunger",
            2782: "Insatiable Hunger is a curse, not a poison",
        },
    ),
    1762: dict(
        name="Kings' Rest",
        lead="Purge Bind Soul, strip Ancestral Fury, dispel Wretched Discharge. Then the curses.",
        description=(
            "Three casts outrank everything else in here, and a group missing them notices: "
            "Bind Soul is a purge, Ancestral Fury is an enrage, Wretched Discharge is a "
            "disease. Hex and Hex Volley are curses. Unholy Mending and Healing Tide Totem are "
            "heals to pressure -- Mortal Wounds, then kill the totem. Overload wants a grip. "
            "Deathly Roar and Pit of Despair are fears. Bleeds never stop: Severing Axe, "
            "Whirling Axe, Impaling Spear, Savage Maul, Mortal Bleed and Sudden Rupture."),
        notes={
            2908: "Ancestral Fury -- the enrage that matters most in here",
            19801: "Tranquilizing Shot -- Ancestral Fury",
            5938: "Shiv -- Ancestral Fury",
            475: "Hex and Hex Volley are both curses",
            2782: "Hex Volley goes out to the whole group",
            32375: "Mass Dispel answers Bind Soul across a pack",
            528: "Bind Soul is the purge that matters",
            278326: "Consume Magic -- Bind Soul",
        },
    ),
    2813: dict(
        name="Murder Row",
        lead="Curse of Doom decides the pull. Poison cleanses and enrage removal behind it.",
        description=(
            "Curse of Doom is flagged above everything else here, and a group with no curse "
            "dispel will feel it on every pull. Heartstop Poison comes off the boss and off "
            "trash, so poison removal is close behind. Seduction is a sleep cast by a demon: "
            "interrupt it, or CC the demon -- one of the few places Imprison and Banish are "
            "literally the right button. Fel Rage and Back to Work! are enrages, Fel Crazed is "
            "a purge, and Health Funnel wants Mortal Wounds and a body out of the beam."),
        notes={
            475: "Curse of Doom -- the dispel this dungeon is built around",
            2782: "Curse of Doom, before anything else",
            51886: "Cleanse Spirit -- Curse of Doom",
            218164: "Detox -- Heartstop Poison",
            217832: "Imprison genuinely applies: Seduction is cast by a demon",
            710: "Banish -- the Seduction caster is a demon",
            2908: "Fel Rage and Back to Work!",
        },
    ),
    2521: dict(
        name="Ruby Life Pools",
        lead="Stop Flaming Barrage with hard CC, purge the shields, walk out of Inferno.",
        description=(
            "Flaming Barrage is the cast that kills people, and every kind of hard control "
            "works on it -- stun, fear, incapacitate or grip the humanoid casting it. Blaze of "
            "Glory and Stormcloud Barrier are purges, and Ice Shield sits on a humanoid you "
            "can simply CC instead. Inferno is pure movement. Cold Claws snares and Blazing "
            "Rush bleeds, but neither decides a pull. Light on dispels, heavy on control."),
        notes={
            278326: "Consume Magic -- Blaze of Glory and Stormcloud Barrier",
            528: "Two shields worth purging",
            30449: "Spellsteal -- Stormcloud Barrier is worth taking",
            179057: "Chaos Nova into Flaming Barrage",
            119381: "Leg Sweep into Flaming Barrage",
            46968: "Shockwave -- the Flaming Barrage packs",
        },
    ),
    1877: dict(
        name="Temple of Sethraliss",
        lead="Poison dispels throughout, a curse on Addle Mind, CC for the snakes and archers.",
        description=(
            "Poison is the through-line: Poison Spit on the boss, Cytotoxin and Poisoned Cheap "
            "Shot from trash. Addle Mind is the curse. A Knot of Snakes is a beast pack, so "
            "beast CC and grips gather it. Arrow Barrage wants the archer stunned and everyone "
            "out of the line, which makes it a control check and a movement check at once. "
            "Accumulate Charge is a purge, Serrated Charge bleeds, and Shrouded Fang patrols "
            "stealthed if you keep getting jumped on the way in."),
        notes={
            475: "Addle Mind is a curse",
            2782: "Addle Mind and the poisons, on one talent",
            218164: "Detox -- Cytotoxin and Poison Spit",
            213644: "Cleanse Toxins -- poison is everywhere here",
            2637: "Hibernate -- A Knot of Snakes are beasts",
            109248: "Binding Shot gathers A Knot of Snakes",
        },
    ),
    2859: dict(
        name="The Blinding Vale",
        lead="The bleed dungeon. Freedom for Bloodthorn Roots, a poison dispel for Toxic Spew.",
        description=(
            "Bleeds define this place. Thornblade, Incise, Grievous Thrash, Thornspike and "
            "Grievous Gash all stack physical damage that most classes cannot dispel at all, "
            "so the real answers are the immunities: Blessing of Protection, Ice Block, Cloak "
            "of Shadows. Bloodthorn Roots pins you, so bring freedom. Toxic Spew is the poison. "
            "Lightbloom Pollination is a heal that wants Mortal Wounds, Lightmaw Beams is "
            "movement, and Potad-Toss goes on an elemental, so elemental CC applies."),
        notes={
            1022: "Blessing of Protection clears the bleed stack outright",
            45438: "Ice Block clears bleeds",
            31224: "Cloak of Shadows clears the bleed stack",
            1044: "Blessing of Freedom -- Bloodthorn Roots",
            374251: "Cauterizing Flame -- bleed and poison in one",
            51514: "Hex -- the Potad-Toss carriers",
        },
    ),
    2923: dict(
        name="Voidscar Arena",
        lead="Three separate enrages, poison throughout, and Shell Guard wants beast CC.",
        description=(
            "Bloodsurge, Bolster and Feral Rage are three different enrages, which is what "
            "turns a Soothe or a Tranquilizing Shot from nice-to-have into a slot worth "
            "spending. Poison Splash and Mind-Numbing Poison come off the boss and Corrosive "
            "Essence off trash. Devour and Mending Void are channels -- stop them, and put "
            "Mortal Wounds on whatever is healing. Shell Guard sits on a beast, so beast CC "
            "and Cyclone both apply. Mad Shriek is a physical fear, Void Beam is movement."),
        notes={
            2908: "Three enrages in here. Take it",
            19801: "Tranquilizing Shot -- three enrages",
            5938: "Shiv -- three enrages",
            2637: "Hibernate -- Shell Guard is on a beast",
            33786: "Cyclone -- Shell Guard is explicitly cycloneable",
            218164: "Detox -- poison on the boss and the trash",
        },
    ),
}

ORDER = [2993, 2825, 1762, 2813, 2521, 1877, 2859, 2923]


# ------------------------------------------------------------- reading
def read_instances(addons):
    src = io.open(os.path.join(addons, "MythicPlusUtility", "InstancesData.lua"),
                  encoding="utf-8").read()
    out, cur, where = {}, None, "boss"
    for line in src.splitlines():
        m = re.match(r"\s*\[(\d+)\] = \{ -- (.+)", line)
        if m:
            cur = {"id": int(m.group(1)), "name": m.group(2).strip(), "mech": []}
            out[cur["id"]], where = cur, "boss"
            continue
        if cur is None:
            continue
        if re.search(r"--\s*Trash\s*$", line):
            where = "trash"
        m = re.search(r"\{ -- (.+?)\s*$", line)
        if m and "] = {" not in line:
            cur["mech"].append({"name": m.group(1).strip(), "where": where, "tags": []})
        t = re.search(r'tags = "(.*?)"', line)
        if t and cur["mech"]:
            cur["mech"][-1]["tags"] = re.findall(r"\[(\w+)\]", t.group(1))
    return out


def read_abilities(addons):
    src = io.open(os.path.join(addons, "MythicPlusUtility", "SpellsData.lua"),
                  encoding="utf-8").read()
    src = src[src.index("MythicPlusUtility.utilityAbilities ="):]
    out, cur = {}, None
    for line in src.splitlines():
        m = re.match(r"\s{4}(\w+|\[\d+\]) = \{", line)
        if m:
            key = m.group(1)
            cur = int(key.strip("[]")) if key.startswith("[") else key
            out.setdefault(cur, {})
            continue
        m = re.match(r'\s*\[(\d+)\] = \{tags = "(.*?)"(.*?)\}, -- (.+?)\s*$', line)
        if m and cur is not None:
            out[cur][int(m.group(1))] = {
                "tags": re.findall(r"\[(\w+)\]", m.group(2)),
                "baseline": "baseline = true" in m.group(3),
                "name": m.group(4).strip(),
            }
    return out


# ------------------------------------------------------------ matching
def match(dungeon, cls, abilities):
    """What one class brings to one dungeon, split class-wide vs per-spec.

    The split is not cosmetic. A Havoc demon hunter does not have Void
    Nova and a Balance druid's dispel is not a feral's, so anything that
    lives in a spec's pool has to land in bySpec or the panel recommends
    buttons the reader does not own. bySpec is merged over byClass at
    runtime, so this loses nothing.
    """
    tags, hot = set(), set()
    for m in dungeon["mech"]:
        tags |= set(m["tags"])
        if "important" in m["tags"] or "super_important" in m["tags"]:
            hot |= set(m["tags"])

    def gather(pool, seen):
        out = []
        for sid, v in pool.items():
            hit = set(v["tags"]) & tags
            if not hit or sid in seen:
                continue
            seen.add(sid)
            out.append({
                "id": sid, "name": v["name"], "talent": not v["baseline"],
                # Answering a mechanic the dungeon itself flags as
                # important outranks a situational pick, and a spell that
                # only ever saves its caster ranks below one that helps
                # the group.
                "rank": (0 if hit & hot else 1) + (1 if "self_only" in v["tags"] else 0),
            })
        out.sort(key=lambda p: (p["rank"], p["talent"], p["id"]))
        return out

    seen = set()
    wide = gather(abilities.get(cls, {}), seen)[:MAX_PER_CLASS - 1]
    # Only what actually made the cut blocks a spec entry: a class pick
    # trimmed by the cap should not silently suppress the spec version.
    seen = set(p["id"] for p in wide)
    per_spec = {}
    for spec in SPECS[cls]:
        picks = gather(abilities.get(spec, {}), set(seen))[:3]
        if picks:
            per_spec[spec] = picks
    return wide, per_spec


# -------------------------------------------------------------- writing
def lua_string(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def wrap(text, indent, width=72):
    """Long strings break with .. rather than running past 80 columns."""
    words, lines, cur = text.split(), [], ""
    for w in words:
        if cur and len(cur) + len(w) + 1 > width:
            lines.append(cur)
            cur = w
        else:
            cur = (cur + " " + w).strip()
    if cur:
        lines.append(cur)
    pad = " " * indent
    out = [lua_string(lines[0] + (" " if len(lines) > 1 else ""))]
    for i, ln in enumerate(lines[1:]):
        tail = " " if i < len(lines) - 2 else ""
        out.append(pad + ".. " + lua_string(ln + tail))
    return "\n".join(out)


def emit(instances, abilities):
    L = []
    add = L.append
    add("local _, ns = ...")
    add("")
    add("-" * 58)
    add("-- Mythic+ utility, per dungeon and per class.")
    add("--")
    add("-- GENERATED -- do not hand-edit. Regenerate with:")
    add("--     python Tools/build_utility.py")
    add("--")
    add("-- The prose and the notes are ours. The mechanic-to-utility")
    add("-- mapping under them is derived from Mythic Plus Utility's")
    add("-- curated tags (by Nikyou); the generator's header says exactly")
    add("-- what is read from that addon and what is not.")
    add("--")
    add("-- Data model, per instanceMapID:")
    add("--   header, lead, description,")
    add("--   byClass = { CLASS = { spellID | { id=, talent=, note= } } },")
    add("--   bySpec  = { [specID] = { ... } }   -- merged on top of byClass")
    add("-" * 58)
    add("")
    add('ns.UTILITY_BUILT_AT = "%s"' % date.today().isoformat())
    add("")
    add("ns.UTILITY_DUNGEONS = {")

    for mapid in ORDER:
        ed = EDITORIAL[mapid]
        d = instances[mapid]
        add("    -- " + "=" * 53)
        add("    [%d] = { -- %s" % (mapid, ed["name"]))
        add("        header      = %s," % lua_string(ed["name"]))
        add("        lead        = %s," % wrap(ed["lead"], 22))
        add("        description = %s," % wrap(ed["description"], 22))
        def row(p, notes):
            note = notes.get(p["id"])
            if note:
                return ("{ id = %d,%s note = %s },   -- %s"
                        % (p["id"], " talent = true," if p["talent"] else "",
                           lua_string(note), p["name"]))
            if p["talent"]:
                return "{ id = %d, talent = true },   -- %s" % (p["id"], p["name"])
            return "%d,%s-- %s" % (p["id"], " " * max(1, 9 - len(str(p["id"]))), p["name"])

        spec_rows = {}
        add("        byClass = {")
        for cls in CLASSES:
            sid, iname = INTERRUPT[cls]
            rows = []
            if cls in INTERRUPT_NOTE:
                rows.append("{ id = %d, talent = true, note = %s },   -- %s"
                            % (sid, lua_string(INTERRUPT_NOTE[cls]), iname))
            else:
                rows.append("%d,%s-- %s" % (sid, " " * max(1, 9 - len(str(sid))), iname))
            wide, per_spec = match(d, cls, abilities)
            for p in wide:
                rows.append(row(p, ed["notes"]))
            for spec, picks in per_spec.items():
                spec_rows[spec] = [row(p, ed["notes"]) for p in picks]
            add("            %s = {" % cls)
            for r in rows:
                add("                " + r)
            add("            },")
        add("        },")
        if spec_rows:
            add("        bySpec = {")
            for spec in sorted(spec_rows):
                add("            [%d] = {" % spec)
                for r in spec_rows[spec]:
                    add("                " + r)
                add("            },")
            add("        },")
        add("    },")
        add("")

    add("}")
    add("")
    return "\n".join(L) + "\n"


def main():
    addons = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_ADDONS
    mpu = os.path.join(addons, "MythicPlusUtility")
    if not os.path.isdir(mpu):
        print("Mythic Plus Utility is not installed at %s" % mpu)
        print("Pass the AddOns folder as an argument, or install it to regenerate.")
        return 1
    instances = read_instances(addons)
    abilities = read_abilities(addons)
    missing = [m for m in ORDER if m not in instances]
    if missing:
        print("MPU has no data for %s -- has the season rolled over?" % missing)
        return 1
    io.open(OUT, "w", encoding="utf-8", newline="\n").write(emit(instances, abilities))
    print("wrote %s (%d dungeons)" % (os.path.relpath(OUT, ROOT), len(ORDER)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
