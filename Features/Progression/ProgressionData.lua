local _, ns = ...

------------------------------------------------------------
-- Midnight Season 2 (Curse of Ula'tek): Progression Source Data
--
-- Sources, in order of trust:
--   1. In-game Mistcrest currency descriptions (crest tiers + sources).
--   2. norumu's community gearing sheet (item levels per activity).
--   3. Blizzard's 12.1 endgame-gearing blog (vault track jumps,
--      Venomstones, bonus rolls).
--
-- Anything marked INFERRED below is not directly attested and should be
-- spot-checked once 12.1 is live.
--
-- Dates: patch launches 11 Aug 2026 (12 Aug EU). SEASON 2 STARTS ONE
-- WEEK LATER, 18 Aug — keys, Bountiful Delves, the raid and the M+
-- season all gate on that second date, not on patch day.
------------------------------------------------------------
ns.PROGRESSION = {}

------------------------------------------------------------
-- Mythic+
------------------------------------------------------------
ns.PROGRESSION.MYTHIC_PLUS = {
    { key = "H",  label = "Heroic", loot = 276, vault = 289, crestType = "Veteran",  crestAmount = "10" },
    { key = "M0", label = "M0",     loot = 292, vault = 302, crestType = "Champion", crestAmount = "10" },
    { key = 2,  loot = 295, vault = 305, crestType = "Champion", crestAmount = "" },
    { key = 3,  loot = 295, vault = 305, crestType = "Champion", crestAmount = "" },
    { key = 4,  loot = 298, vault = 308, crestType = "Hero",     crestAmount = "" },
    { key = 5,  loot = 302, vault = 308, crestType = "Hero",     crestAmount = "" },
    { key = 6,  loot = 305, vault = 311, crestType = "Hero",     crestAmount = "" },
    { key = 7,  loot = 305, vault = 315, crestType = "Hero",     crestAmount = "" },
    { key = 8,  loot = 308, vault = 315, crestType = "Hero",     crestAmount = "" },
    { key = 9,  loot = 308, vault = 318, crestType = "Myth",     crestAmount = "" },
    { key = 10, loot = 311, vault = 318, crestType = "Myth",     crestAmount = "" },
    { key = 11, loot = 311, vault = 318, crestType = "Myth",     crestAmount = "" },
    { key = 12, loot = 311, vault = 318, crestType = "Myth",     crestAmount = "" },
}

ns.PROGRESSION.MYTHIC_PLUS_NOTES = {
    "Season 2 keys unlock 18 Aug, one week after the patch",
    "Hero crests run +4 to +8; Myth crests start at +9",
    "M+ is the only uncapped source of Hero gear early in the season",
    "M0 dungeons are on a daily lockout",
    "Expired keystone deducts 4 crests",
}

ns.PROGRESSION.MYTHIC_PLUS_DUNGEONS = {
    "Altar of Fangs",        -- new, 3 bosses
    "Murder Row",
    "Den of Nalorakk",
    "The Blinding Vale",
    "Voidscar Arena",
    "Kings' Rest",           -- BfA
    "Ruby Life Pools",       -- Dragonflight
    "Temple of Sethraliss",  -- BfA
}

-- The same pool with the two things code actually needs: the instance
-- map ID that GetInstanceInfo returns, and the timer.
--
-- Map IDs are taken from the installed LittleWigs modules rather than
-- guessed -- BigWigs:NewBoss() carries the real ID for each encounter.
-- Timers are from Wowhead's Season 2 overview and are PTR values, so
-- they may shift before launch.
ns.PROGRESSION.MYTHIC_PLUS_POOL = {
    { name = "Altar of Fangs",       mapID = 2993, timer = 30 * 60 },
    { name = "Murder Row",           mapID = 2813, timer = 34 * 60 },
    { name = "Den of Nalorakk",      mapID = 2825, timer = 32 * 60 },
    { name = "The Blinding Vale",    mapID = 2859, timer = 31 * 60 },
    { name = "Voidscar Arena",       mapID = 2923, timer = 30 * 60 },
    { name = "Kings' Rest",          mapID = 1762, timer = 33 * 60 },
    { name = "Temple of Sethraliss", mapID = 1877, timer = 33 * 60 },
    { name = "Ruby Life Pools",      mapID = 2521, timer = 28 * 60 },
}

--- Season 2 pool entry for an instance map ID, or nil when the player is
--- somewhere outside the pool.
function ns.GetSeasonDungeon(mapID)
    for _, d in ipairs(ns.PROGRESSION.MYTHIC_PLUS_POOL) do
        if d.mapID == mapID then return d end
    end
end

------------------------------------------------------------
-- Raid: The Venomous Abyss (8 bosses)
--
-- The vault column is the headline change of 12.1: LFR/Normal/Heroic
-- vault rewards always jump to rank 1 of the NEXT track, and the Mythic
-- vault hands out a fully upgraded Myth 6/6.
------------------------------------------------------------
ns.PROGRESSION.RAID_NAME = "The Venomous Abyss"

ns.PROGRESSION.RAID_BOSSES = {
    "Nek'zali the Soulcoiler",
    "Entombed Sentinels",
    "The Lost Explorers",
    "Vashnik the Malignant",
    "Sszorak",
    "The Twin Fangs",
    "The Coiled Altar",
    "Ula'tek",
}

-- Season 2 is a single raid, so this is a flat list of difficulties
-- rather than Season 1's per-wing boss ranges. One card per difficulty:
-- what bosses drop, what the vault gives, and which crest you earn.
ns.PROGRESSION.RAID = {
    -- Drops are the 4/6 rank of each track, confirmed against the
    -- Encounter Journal in-game (Raid Finder reads "Veteran 4/6 / 289",
    -- Mythic reads "Myth 4/6 / 328"). Vault values follow Blizzard's
    -- "jump to the first step of the next track" rule.
    {
        difficulty = "LFR", label = "Raid Finder",
        crestType = "Veteran",  color = "ff0070dd",
        loot = 289, vault = 292,
    },
    {
        difficulty = "Normal",
        crestType = "Champion", color = "ffa335ee",
        loot = 302, vault = 305,
    },
    {
        difficulty = "Heroic",
        crestType = "Hero",     color = "ffff8000",
        loot = 315, vault = 318,
    },
    {
        difficulty = "Mythic",
        crestType = "Myth",     color = "ffff0000",
        loot = 328, vault = 334,
        -- Penultimate + final boss and Very Rare items, drop or vault.
        mythNine = 344,
    },
}

ns.PROGRESSION.RAID_NOTES = {
    "Heroic vault now gives Myth 1/6 (318) — the big 12.1 change",
    "Mythic vault always gives a fully upgraded Myth 6/6 (334)",
    "Last two bosses and Very Rare items are Myth 9 (344), drop or vault",
    "Bonus Rolls cost 1 Nebulous Voidcore for raid loot (was 2)",
    "Catalyzed set pieces now keep the source item's secondaries and cantrip",
}

------------------------------------------------------------
-- Lairs — instanced world bosses, 15-25 players, World -> Flex Mythic.
-- First Lair is The Tidebound Grotto (Nymrissa Wavecaller).
-- Counts toward the RAID row of the Great Vault.
------------------------------------------------------------
ns.PROGRESSION.LAIRS = {
    name = "The Tidebound Grotto",
    boss = "Nymrissa Wavecaller",
    notes = {
        "Scales from World difficulty up to Flexible Mythic",
        "Drops raid-level gear and fills the Raid row of the Great Vault",
        "Only raid boss in 12.1 offering Flexible Mythic",
    },
}

------------------------------------------------------------
-- Delves
--
-- Bountiful Delves and the Nemesis boss unlock with Season 2 on 18 Aug.
-- New delves: The Ring of Glory, Gnarldor Isle. Nemesis: Venomfall Deeps.
------------------------------------------------------------
ns.PROGRESSION.DELVES = {
    { tier = 1,  loot = 266, vault = 279, crestType = "",           crestAmount = "" },
    { tier = 2,  loot = 269, vault = 282, crestType = "",           crestAmount = "" },
    { tier = 3,  loot = 272, vault = 285, crestType = "",           crestAmount = "" },
    { tier = 4,  loot = 276, vault = 289, crestType = "Adventurer", crestAmount = "" },
    { tier = 5,  loot = 279, vault = 292, crestType = "Veteran",    crestAmount = "" },
    { tier = 6,  loot = 282, vault = 298, crestType = "Veteran",    crestAmount = "" },
    { tier = 7,  loot = 292, vault = 302, crestType = "Champion",   crestAmount = "" },
    { tier = 8,  loot = 295, vault = 305, crestType = "Champion",   crestAmount = "" },
    { tier = 9,  loot = 295, vault = 305, crestType = "Champion",   crestAmount = "" },
    { tier = 10, loot = 295, vault = 305, crestType = "Champion",   crestAmount = "" },
    { tier = 11, loot = 295, vault = 305, crestType = "Hero",       crestAmount = "" },
}

ns.PROGRESSION.DELVE_NOTES = {
    "New delves: The Ring of Glory, Gnarldor Isle",
    "Nemesis delve: Venomfall Deeps (boss Azta'rec)",
    "Tier 11 coffers reach 305 once you hit Delver's Journey 9",
    "Tier 11 is the only delve source of Hero Mistcrests",
    "Bountiful Delves and Nemesis unlock with Season 2 on 18 Aug",
}

-- Trovehunter's Bounty Map rewards (separate from bountiful delves)
ns.PROGRESSION.TROVEHUNTER = {
    { tier = 4,  loot = 282, crestType = "Veteran",  crestAmount = "" },
    { tier = 5,  loot = 289, crestType = "Veteran",  crestAmount = "" },
    { tier = 6,  loot = 292, crestType = "Champion", crestAmount = "" },
    { tier = 7,  loot = 295, crestType = "Champion", crestAmount = "" },
    { tier = 8,  loot = 305, crestType = "Hero",     crestAmount = "" },
    { tier = 9,  loot = 305, crestType = "Hero",     crestAmount = "" },
    { tier = 10, loot = 305, crestType = "Hero",     crestAmount = "" },
    { tier = 11, loot = 305, crestType = "Hero",     crestAmount = "" },
}

------------------------------------------------------------
-- Prey Hunts
-- Weekly hunt cap raised to 15 in Season 2 to cover the Coiled Isle.
-- Crest tiers here are INFERRED from item level alignment — the S2
-- Mistcrest descriptions list "Repeatable/Weekly Outdoor Events" rather
-- than naming Prey explicitly.
------------------------------------------------------------
ns.PROGRESSION.PREY = {
    { difficulty = "Normal",    loot = 266, vault = 279, crestType = "Adventurer", crestAmount = "" },
    { difficulty = "Hard",      loot = 279, vault = 292, crestType = "Veteran",    crestAmount = "" },
    { difficulty = "Nightmare", loot = 292, vault = 305, crestType = "Champion",   crestAmount = "" },
}

ns.PROGRESSION.PREY_NOTES = {
    "Weekly hunt limit raised to 15 for Season 2",
    "You get gear from 2 hunts per difficulty per week",
    "Hunts count toward the World row of the Vault",
    "Nightmare Champion gear boxes also award Ascendant Venomstones",
    "New affixes: Pack Ambush, Exploding Corpse Snakes, Toxic Snare",
    "Ambush is Normal-only; Hard and Nightmare run all other affixes",
}

------------------------------------------------------------
-- World content
------------------------------------------------------------
ns.PROGRESSION.WORLD = {
    { source = "12.1 Campaign",        loot = 256, crestType = "",           crestAmount = "" },
    { source = "World Quests",         loot = 266, crestType = "Adventurer", crestAmount = "" },
    { source = "World Boss / Vault",   loot = 279, crestType = "Veteran",    crestAmount = "" },
    { source = "Pinnacle Cache",       loot = 285, crestType = "",           crestAmount = "" },
    { source = "World Boss (Normal)",  loot = 292, crestType = "Champion",   crestAmount = "" },
    { source = "World Boss (Heroic)",  loot = 305, crestType = "Hero",       crestAmount = "" },
    { source = "World Boss (Mythic)",  loot = 318, crestType = "Myth",       crestAmount = "" },
}

ns.PROGRESSION.WORLD_NOTES = {
    "Void Assaults, Val and Naigtal now give Season 2 Adventurer crests",
    "Heroic World Tier world boss and weeklies give Veteran crests",
    "Ritual Site tiers 1-6 now match Season 2 delve tiers 1-6",
    "Ritual Site recommended ilvl: T4 259, T5 268, T6 275",
    "Void-Touched caches: 200 Field Accolades (Adventurer), 500/750 (Veteran)",
    "Season 1 world boss drops stay S1 and can no longer be upgraded",
}

------------------------------------------------------------
-- Crafting
-- INFERRED ladder — see ns.CRAFTED_RANGES in Core/Data.lua.
------------------------------------------------------------
ns.PROGRESSION.CRAFTING_ADVENTURER = {
    label = "Blue Gear + Adventurer Crests",
    qualities = { 266, 269, 272, 276, 279 },
}

ns.PROGRESSION.CRAFTING_VETERAN = {
    label = "Blue Gear + Veteran Crests",
    qualities = { 282, 285, 289, 292, 295 },
}

ns.PROGRESSION.CRAFTING_SPARK = {
    {
        label = "Spark of Tides (no crests)",
        color = "ffa335ee",
        qualities = { 295, 298, 302, 305, 308 },
    },
    {
        label = "Spark + Hero",
        color = "ffff8000",
        qualities = { 308, 311, 315, 318, 321 },
    },
    {
        label = "Spark + Myth",
        color = "ffff0000",
        qualities = { 321, 324, 328, 331, 334 },
    },
}

ns.PROGRESSION.CRAFTING_NOTES = {
    "Spark of Tides gear requires 80 crests of the chosen type",
    "Max-quality crafts can take an Ascendant Venomstone later in S2",
    "Item levels here are inferred from PTR data — verify in-game",
}

------------------------------------------------------------
-- Ascendant Venomstones (the Season 2 Voidcore successor).
-- Unlocks later in the season; 10 stones per upgrade.
------------------------------------------------------------
ns.PROGRESSION.VENOMSTONES = {
    cost = 10,
    slots = "Weapons, Trinkets and Necklaces",
    results = {
        { label = "Crafted (max quality) at Hero", ilvl = 324 },
        { label = "Hero 6/6",                      ilvl = 328 },
        { label = "Crafted (max quality) at Myth", ilvl = 337 },
        { label = "Myth 6/6",                      ilvl = 341 },
    },
    sources = {
        "Every Heroic or Mythic Venomous Abyss boss",
        "Mythic+ keystones at +10 or higher",
        "Tier 11 Bountiful Delves",
        "Nightmare Prey Hunt Champion gear boxes",
    },
    notes = {
        "Necklaces are newly eligible in Season 2 (cap: Myth 8)",
        "Only fully upgraded Hero / Myth / max-quality crafted gear qualifies",
    },
}

------------------------------------------------------------
-- Great Vault / Bonus Rolls
------------------------------------------------------------
ns.PROGRESSION.VAULT_NOTES = {
    "Nebulous Voidcores are a vault reward option from week 1 of S2",
    "You need 3 filled slots in a week to claim the Bonus Roll option",
    "Orin Straylight (at the Catalyst in Silvermoon) adds 1/week from week 8",
    "Bonus Roll item level follows the boss you roll, not the slots you filled",
    "Taking an item from the vault does NOT remove it from the Bonus Roll pool",
}

------------------------------------------------------------
-- Crest Sources Summary
-- Taken verbatim from the in-game Mistcrest currency descriptions.
------------------------------------------------------------
ns.PROGRESSION.CREST_SOURCES = {
    {
        crestType = "Adventurer",
        color = "ff1eff00",
        upgradeRange = "269-282",
        sources = {
            "Repeatable Outdoor Events",
            "Tier 4 Delves",
        },
    },
    {
        crestType = "Veteran",
        color = "ff0070dd",
        upgradeRange = "282-295",
        sources = {
            "Repeatable Outdoor Events",
            "LFR Venomous Abyss",
            "Heroic Season Dungeons",
            "Delves Tier 5-6",
            "Trovehunter's Bounty Tier 4-5",
        },
    },
    {
        crestType = "Champion",
        color = "ffa335ee",
        upgradeRange = "295-308",
        sources = {
            "Weekly Outdoor Events",
            "Normal Venomous Abyss",
            "Mythic Season Dungeons (M0)",
            "M+ keys 2-3",
            "Delves Tier 7-10",
            "Trovehunter's Bounty Tier 6-7",
        },
    },
    {
        crestType = "Hero",
        color = "ffff8000",
        upgradeRange = "308-321",
        sources = {
            "Heroic Venomous Abyss",
            "M+ keys 4-8",
            "Delves Tier 11",
            "Trovehunter's Bounty Tier 8+",
        },
    },
    {
        crestType = "Myth",
        color = "ffff0000",
        upgradeRange = "321-334",
        sources = {
            "Mythic Venomous Abyss",
            "M+ keys 9 and above",
        },
    },
}
