local _, ns = ...

------------------------------------------------------------
-- Dungeon teleports: the one table.
--
-- There were two, and they disagreed. The Teleports page carried a list
-- grouped by expansion; the Mythic+ page carried a second list keyed by
-- dungeon name, and between them eight spell IDs were simply invented --
-- a tidy run of 1289772..1289782 that exists in no addon, no database
-- and no game. Every Midnight tile on both pages was a dead button, and
-- the two lists agreeing with each other about the wrong number is
-- exactly what made it look deliberate.
--
-- So: one table, read by both. A wrong id is still possible, but a wrong
-- id in only one half of the addon is not.
--
-- Verified against BigWigs\Tools\Keystones.lua, which is hand-maintained
-- per season and carries the same mapping keyed by challenge map id, and
-- spot-checked against EllesmereUI's SEASON_PORTALS for the current
-- eight. Where the two disagreed with us, both agreed with each other.
--
-- Adding a season means editing this file and nothing else.
------------------------------------------------------------

------------------------------------------------------------
-- Entry shape
--
--   { id = n, name = "..." }             one spell
--   { ids = { a, b }, name = "..." }     several; any known one counts
--   { ally = a, horde = b, name = "..." } one spell per faction
--   mplus = { "..." }                    extra names Mythic+ uses
--
-- `ids` is for a dungeon that has been given a teleport more than once:
-- a legacy dungeon rejoining a season is issued a new spell, and a
-- character who earned the old one still has the old one. Whichever the
-- player actually knows is the one cast.
--
-- `ally`/`horde` is a different thing that looks the same. Two spells
-- exist at once and which one you can ever have is decided by your
-- faction, not by when you played. Both are listed so the "do you know
-- it" test needs no faction logic at all; the ordering below puts yours
-- first so a LOCKED tile still shows your faction's icon.
------------------------------------------------------------
local TELEPORT_GROUPS = {
    {
        header = "Midnight",
        entries = {
            { id = 1286812, name = "Altar of Fangs" },
            -- These three read like older-expansion dungeons and are
            -- not. Midnight rebuilds the zones they sit in, so what
            -- looks like a returning dungeon is new content wearing a
            -- familiar name: Murder Row is not the Suramar street,
            -- Zul'Aman is a new Midnight zone built over the old one,
            -- and Magisters' Terrace is a new version of the Quel'Thalas
            -- original rather than the Burning Crusade one.
            --
            -- The test for filing a dungeon is whether Midnight remade
            -- it, not whether the name predates Midnight. Leave them.
            { id = 1286809, name = "Murder Row" },
            { id = 1286807, name = "Den of Nalorakk" },
            { id = 1254572, name = "Magisters' Terrace" },
            { id = 1286801, name = "The Blinding Vale" },
            { id = 1286804, name = "Voidscar Arena" },
            { id = 1254400, name = "Windrunner Spire" },
            { id = 1254563, name = "Nexus-Point Xenas" },
            { id = 1254559, name = "Maisara Caverns" },
        },
    },
    {
        header = "The War Within",
        entries = {
            { id = 1216786, name = "Operation: Floodgate" },
            { id = 1237215, name = "Eco-Dome Al'dani" },
            { id = 445417,  name = "Ara-Kara, City of Echoes" },
            { id = 445414,  name = "The Dawnbreaker" },
            { id = 445444,  name = "Priory of the Sacred Flame" },
            { id = 445416,  name = "City of Threads" },
            { id = 445269,  name = "The Stonevault" },
            { id = 445440,  name = "Cinderbrew Meadery" },
            { id = 445441,  name = "Darkflame Cleft" },
            { id = 445443,  name = "The Rookery" },
        },
    },
    {
        header = "Dragonflight",
        entries = {
            { id = 393267,  name = "Brackenhide Hollow" },
            { id = 393283,  name = "Halls of Infusion" },
            { id = 393276,  name = "Neltharus" },
            { id = 393222,  name = "Uldaman: Legacy of Tyr" },
            { id = 424197,  name = "Dawn of the Infinite" },
            { id = 393279,  name = "The Azure Vault" },
            { id = 393262,  name = "The Nokhud Offensive" },
            { id = 393273,  name = "Algeth'ar Academy" },
            -- One spell, not two. This carried a second id on the
            -- theory that a returning dungeon is reissued a teleport --
            -- true of Kings' Rest and Temple of Sethraliss below, and
            -- not of this one, which kept the Dragonflight spell when
            -- it came back.
            { id = 393256,  name = "Ruby Life Pools" },
        },
    },
    {
        header = "Shadowlands",
        entries = {
            { id = 354462,  name = "The Necrotic Wake" },
            { id = 354463,  name = "Plaguefall" },
            { id = 354464,  name = "Mists of Tirna Scithe" },
            { id = 354466,  name = "Spires of Ascension" },
            { id = 354467,  name = "Theater of Pain" },
            { id = 354468,  name = "De Other Side" },
            { id = 354469,  name = "Sanguine Depths" },
            -- Mythic+ splits this into two halves with their own names
            -- and its own map ids, and both are reached by the one
            -- teleport.
            { id = 367416,  name = "Tazavesh",
              mplus = { "Tazavesh: Streets of Wonder", "Tazavesh: So'leah's Gambit" } },
            { id = 354465,  name = "Halls of Atonement" },
        },
    },
    {
        header = "Battle for Azeroth",
        entries = {
            { id = 410071,  name = "Freehold" },
            { id = 410074,  name = "The Underrot" },
            { id = 424167,  name = "Waycrest Manor" },
            { id = 424187,  name = "Atal'Dazar" },
            { id = 373274,  name = "Operation: Mechagon" },
            { ally = 445418, horde = 464256, name = "Siege of Boralus" },
            -- Was 272268, which AllTheThings files under
            -- NeverImplemented: a spell that shipped in the data and
            -- never in the game. It is the only id here that was wrong
            -- in a way IsSpellKnown could not distinguish from "you have
            -- not earned it yet", so the tile read locked forever and
            -- looked like the player's problem.
            { ally = 467553, horde = 467555, name = "The MOTHERLODE!!" },
            -- Reissued for Midnight. The BfA spell still works for
            -- anyone who earned it back then, so both count.
            { ids = { 1286831, 272261 }, name = "Kings' Rest" },
            { ids = { 1286828, 272267 }, name = "Temple of Sethraliss" },
        },
    },
    {
        header = "Legion",
        entries = {
            { id = 410078,  name = "Neltharion's Lair" },
            { id = 424153,  name = "Black Rook Hold" },
            { id = 424163,  name = "Darkheart Thicket" },
            { id = 393764,  name = "Halls of Valor" },
            { id = 393766,  name = "Court of Stars" },
            { id = 373262,  name = "Return to Karazhan" },
            { id = 1254551, name = "Seat of the Triumvirate" },
        },
    },
    {
        header = "Warlords of Draenor",
        entries = {
            { id = 159901,  name = "The Everbloom" },
            { id = 159900,  name = "Grimrail Depot" },
            { id = 159896,  name = "Iron Docks" },
            { id = 159897,  name = "Auchindoun" },
            { id = 159895,  name = "Bloodmaul Slag Mines" },
            { id = 159899,  name = "Shadowmoon Burial Grounds" },
            { id = 159902,  name = "Upper Blackrock Spire" },
            -- 1254557 was added to the game data alongside the original
            -- and BigWigs records it without knowing which one is
            -- issued now. Listing both costs nothing -- an unknown spell
            -- simply answers no -- and listing only one risks a tile
            -- that reads locked for somebody who has the port.
            { ids = { 159898, 1254557 }, name = "Skyreach" },
        },
    },
    {
        header = "Cataclysm",
        entries = {
            { id = 410080,  name = "The Vortex Pinnacle" },
            { id = 424142,  name = "Throne of the Tides" },
            { id = 445424,  name = "Grim Batol" },
        },
    },
    {
        header = "Mists of Pandaria",
        entries = {
            { id = 131204,  name = "Temple of the Jade Serpent" },
            { id = 131205,  name = "Stormstout Brewery" },
            { id = 131206,  name = "Shado-Pan Monastery" },
            { id = 131225,  name = "Gate of the Setting Sun" },
            { id = 131222,  name = "Mogu'shan Palace" },
            { id = 131228,  name = "Siege of Niuzao Temple" },
            { id = 131232,  name = "Scholomance" },
            { id = 131231,  name = "Scarlet Halls" },
            { id = 131229,  name = "Scarlet Monastery" },
        },
    },
    {
        header = "Wrath of the Lich King",
        entries = {
            { id = 1254555, name = "Pit of Saron" },
        },
    },
}

-- The current season's dungeon pool, by name. Every name must match a
-- canonical entry above. One that does not is skipped and collected in
-- ns.TELEPORT_MISSING_SEASON, which Tools/loadcheck.py asserts is empty
-- -- a typo here would otherwise quietly shrink the section people look
-- at first, and a missing tile is not something you notice.
--
-- Rolling the season over means editing this list and nothing else.
local CURRENT_SEASON = {
    header = "Midnight Season 2 - Current",
    names = {
        "Altar of Fangs",
        "Murder Row",
        "Den of Nalorakk",
        "The Blinding Vale",
        "Voidscar Arena",
        "Kings' Rest",
        "Ruby Life Pools",
        "Temple of Sethraliss",
    },
}

------------------------------------------------------------
-- Derived views
------------------------------------------------------------

-- Read once at load. UnitFactionGroup answers "Neutral" for a Pandaren
-- who has not chosen yet, which is not a bug to guard against: neither
-- ordering is more right for them, and both spells are in the list
-- either way.
local playerFaction = UnitFactionGroup and UnitFactionGroup("player")

-- Normalise every shape into `ids`, so nothing downstream handles more
-- than one.
for _, group in ipairs(TELEPORT_GROUPS) do
    for _, entry in ipairs(group.entries) do
        if entry.ally or entry.horde then
            -- Yours first: EntryKnown falls back to ids[1] for a
            -- teleport nobody has, and that is the icon a locked tile
            -- draws.
            if playerFaction == "Horde" then
                entry.ids = { entry.horde, entry.ally }
            else
                entry.ids = { entry.ally, entry.horde }
            end
        elseif not entry.ids then
            entry.ids = { entry.id }
        end
    end
end

local byName = {}
for _, group in ipairs(TELEPORT_GROUPS) do
    for _, entry in ipairs(group.entries) do
        byName[entry.name] = entry
    end
end

--- True when the player has this teleport, plus the spell to cast.
---
--- Any of the entry's spells counts. Returns the KNOWN spell when there
--- is one, so the tile casts what they actually have, and the first
--- otherwise, so a locked tile still has an icon and a tooltip.
local function EntryKnown(entry)
    for _, id in ipairs(entry.ids) do
        if IsSpellKnown(id) then return true, id end
    end
    return false, entry.ids[1]
end

-- The season section, resolved to the same entry TABLES the expansion
-- groups hold -- not copies. That identity is what keeps the two
-- sections from ever disagreeing about a dungeon.
local seasonGroup, missingSeasonNames = nil, {}
do
    local entries = {}
    for _, name in ipairs(CURRENT_SEASON.names) do
        local entry = byName[name]
        if entry then
            entries[#entries + 1] = entry
        else
            missingSeasonNames[#missingSeasonNames + 1] = name
        end
    end
    if #entries > 0 then
        seasonGroup = { header = CURRENT_SEASON.header, entries = entries }
    end
end

-- What gets drawn: the current season first, then expansions newest
-- first. TELEPORT_GROUPS remains the list of canonical entries, so the
-- summary can count each teleport once however often it is shown.
local DISPLAY_GROUPS = {}
if seasonGroup then DISPLAY_GROUPS[#DISPLAY_GROUPS + 1] = seasonGroup end
for _, group in ipairs(TELEPORT_GROUPS) do
    DISPLAY_GROUPS[#DISPLAY_GROUPS + 1] = group
end

--- Spell candidates by the name Mythic+ uses for the dungeon.
---
--- Mythic+ asks C_ChallengeMode for a name and gets the dungeon's own,
--- which is the canonical name here for all but the two halves of
--- Tazavesh. The `mplus` field carries those.
local spellsByName = {}
for name, entry in pairs(byName) do
    spellsByName[name] = entry.ids
    for _, alias in ipairs(entry.mplus or {}) do
        spellsByName[alias] = entry.ids
    end
end

--- The dungeon a teleport spell travels to.
---
--- Every candidate id, not only the one this character knows: the caller
--- is identifying a cast that has already started, and by then the
--- client has said which spell it is.
local nameBySpell = {}
for _, group in ipairs(TELEPORT_GROUPS) do
    for _, entry in ipairs(group.entries) do
        for _, id in ipairs(entry.ids) do
            nameBySpell[id] = entry.name
        end
    end
end

ns.TELEPORT_GROUPS         = TELEPORT_GROUPS
ns.TELEPORT_DISPLAY_GROUPS = DISPLAY_GROUPS
ns.TELEPORT_MISSING_SEASON = missingSeasonNames
ns.TELEPORT_SPELLS_BY_NAME = spellsByName
ns.TELEPORT_NAME_BY_SPELL  = nameBySpell
ns.TeleportEntryKnown      = EntryKnown
