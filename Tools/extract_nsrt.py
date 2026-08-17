#!/usr/bin/env python3
"""Read the real encounter timelines out of NorthernSkyRaidTools' saved variables.

    python Tools/extract_nsrt.py [encounterID]

The raid trainer's scenarios began life transcribed from a video guide,
which is a fine source for what a mechanic ASKS OF YOU and a poor one for
anything a machine needs: names come out mangled, phases are described in
prose, and there are no timings at all.

Northern Sky is a raid-tools addon whose saved variables happen to carry,
per encounter and per difficulty:

    internalID   the ability, in the raid's own words
    phase        which phase it belongs to -- 1, 1.5 for an intermission, 2
    text         what the raid is told to DO about it: Soak, Frontal,
                 Dodge, Adds, Stop Cast, Debuffs, AoE
    timers       when it goes off, in seconds from the pull

That last column is the thing the transcript could never supply and the
thing a trainer most needs, and `text` maps almost one-to-one onto the
trainer's own mechanic verbs. Together they are enough to build a fight
that is actually shaped like the fight.

Read-only, and pointed at a file the game wrote. Nothing here modifies
the user's saved variables -- it parses them the same way
Tools/loadcheck.py parses the addon, by handing Lua to Lua.
"""

import glob
import os
import sys

from lupa import LuaRuntime

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# .../AddOns/YippYappHelper -> .../_retail_
RETAIL = os.path.dirname(os.path.dirname(os.path.dirname(ROOT)))
SV_GLOB = os.path.join(
    RETAIL, "WTF", "Account", "*", "SavedVariables", "NorthernSkyRaidTools.lua")

# The raid, in pull order, by combat-log encounter ID. Confirmed against
# BigWigs_TheVenomousAbyss and RaiderIO's locale strings.
BOSSES = [
    (3470, "Nek'zali the Soulcoiler", "soulcoiler"),
    (3445, "Entombed Sentinels",      "sentinels"),
    (3497, "The Lost Explorers",      "explorers"),
    (3455, "Vashnik the Malignant",   "vashnik"),
    (3420, "Sszorak",                 "sisterrag"),
    (3421, "The Twin Fangs",          "twinfangs"),
    (3429, "The Coiled Altar",        "alteredfangs"),
    (3492, "Ula'tek",                 None),
]

# Blizzard's difficulty IDs.
DIFFICULTY = {14: "Normal", 15: "Heroic", 16: "Mythic"}

# What each of Northern Sky's action words means to the trainer. This is
# the whole reason the file is worth reading: the raid's own shorthand
# for "what do I do about this" is already a mechanic verb.
VERB = {
    # Straight mappings.
    "soak": "soak", "soaks": "soak", "blood-soak": "soak",
    "frontal": "line", "shells": "line", "bait": "line",
    "dodge": "dodge", "move": "dodge",
    "adds": "chaser", "poison add": "chaser",
    "stop cast": "caster", "interrupt": "caster", "kick": "caster",
    "debuffs": "drop", "drop-pool": "drop", "drop pool": "drop",
    "infection": "drop",
    "aoe": "tax",
    "spread": "spread", "pre-spread": "spread", "blink nova": "spread",
    "stack": "stack",
    "orbs": "orb",
    "waves": "wave",
    "fish spawn": "carry", "time to throw": "carry",
    "number game": "meet",
    "bomb inc": "refuge", "jump": "refuge",
    # Deliberately unmapped: these are real mechanics that a lone dot in
    # an arena cannot practise, and inventing a verb for them would be
    # inventing a fight. They stay visible in the report as "-" so the
    # gap is a decision rather than an oversight.
    "dispels": "-",        # a healer's call
    "tank-hit": "-",       # a defensive
    "taunt": "-",          # a tank swap
    "frostfire debuffs": "-",   # paired opposite-element clearing
}



def find_saved_variables():
    hits = sorted(glob.glob(SV_GLOB))
    if not hits:
        sys.exit("No NorthernSkyRaidTools.lua found under %s" % SV_GLOB)
    return hits


def load(path):
    # Saved variables are plain assignments, so executing them in a bare
    # runtime is enough -- there is no addon API to stub.
    lua = LuaRuntime(unpack_returned_tuples=False)
    with open(path, encoding="utf-8", errors="replace") as fh:
        lua.execute(fh.read())
    return lua.globals().NSRT


def as_list(value):
    """Northern Sky stores a single phase as a scalar and several as a table."""
    if value is None:
        return []
    if hasattr(value, "values"):
        return list(value.values())
    return [value]


def abilities(alerts):
    """(internalID, phases, action, timers) for one encounter+difficulty."""
    out = []
    for name, entry in alerts.items():
        try:
            phases = sorted(float(p) for p in as_list(entry.phase))
        except (TypeError, ValueError):
            phases = []
        timers = sorted(float(t) for t in as_list(entry.timers))
        action = str(entry.text or "").strip()
        out.append((str(name), phases, action, timers))
    # Ordered by first cast, so the list reads as the fight runs.
    out.sort(key=lambda e: (e[3][0] if e[3] else 9e9, e[0]))
    return out


def report(nsrt, only=None):
    alerts = nsrt.EncounterAlerts
    if alerts is None:
        sys.exit("This profile has no EncounterAlerts.")

    for encID, label, key in BOSSES:
        if only and encID != only:
            continue
        present = [d for d in sorted(DIFFICULTY) if alerts[encID] and alerts[encID][d]]
        print("=" * 72)
        print("%s   encounterID %d   scenario key %s" % (label, encID, key or "-"))
        if not alerts[encID]:
            print("  (nothing recorded)")
            continue

        for diff in present:
            rows = abilities(alerts[encID][diff])
            print("  -- %s --" % DIFFICULTY[diff])
            for name, phases, action, timers in rows:
                verb = VERB.get(action.lower(), "?")
                ph = "/".join(("%g" % p) for p in phases) or "-"
                when = ", ".join("%.0f" % t for t in timers[:9]) or "no timers"
                print("    %-22s phase %-8s %-10s -> %-8s  %s"
                      % (name, ph, action or "-", verb, when))


def main():
    only = int(sys.argv[1]) if len(sys.argv) > 1 else None
    for path in find_saved_variables():
        print("### %s" % path)
        report(load(path), only)


if __name__ == "__main__":
    main()
