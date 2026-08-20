local _, ns = ...

-- Single source for the season string shown in the UI. Season names were
-- previously typed into each page and drifted out of date independently.
ns.SEASON_NAME = "Midnight Season 2"

-- Patch day and season start are a week apart: 12.1 opens with Heroic
-- and Mythic 0 only, and keystones go live the following reset. Anything
-- that advises about Mythic+ has to know which of those two weeks it is,
-- or it will send people at content that does not exist yet.
-- Dates below are the US unlock days. Europe resets a day later, so the
-- same content opens on the 12th and the 19th there -- Blizzard's own
-- announcements are headlined "Goes Live August 11" and "Goes Live 12
-- August" for the two regions. Hardcoding the US day told EU players
-- keystones were live a full day before they were.
local function SeasonDate(month, day)
    local region = GetCurrentRegion and GetCurrentRegion() or 1
    if region == 3 then day = day + 1 end     -- 3 = Europe
    return time({ year = 2026, month = month, day = day, hour = 0 })
end

ns.SEASON_PATCH_START = SeasonDate(8, 11)
ns.SEASON_MPLUS_START = SeasonDate(8, 18)

-- Voidcore bonus rolls are absent from the first Season 2 vault and only
-- appear the week after, for anyone with three panes unlocked. Without a
-- date to check, the planner would spend the opening fortnight telling
-- players to unlock a reward the game has not switched on yet.
ns.SEASON_VOIDCORE_START = SeasonDate(8, 25)

-- The raid does not open with the patch either. Advising someone to go
-- get a raid lockout in week one is advice they cannot act on, and the
-- vault's raid row cannot fill until this date.
--
-- Confirmed: the raid opens on the same reset as keystones, 18 August in
-- the US and the 19th in Europe. SeasonDate applies the regional day
-- itself, so this is one date rather than two.
ns.SEASON_RAID_START = SeasonDate(8, 18)

------------------------------------------------------------
-- Gear Tracks: track name -> ordered item levels per rank
--
-- Midnight Season 2 (Curse of Ula'tek). Cross-checked against two
-- independent sources that agree exactly:
--   1. The in-game currency descriptions, e.g. Hero Mistcrest reads
--      "Used to upgrade Hero equipment in Midnight Season 2 up to item
--      levels 308-321" — i.e. ranks 2..6 of the Hero track.
--   2. norumu's community gearing sheet (linktr.ee/norumu).
--
-- Unlike Season 1 the tracks are perfectly regular: every track starts
-- 4 steps up the shared item-level ladder and is 6 ranks long, so each
-- track overlaps the next by exactly 2 ranks.
--
-- Shared ladder:
--   256 259 263 266 269 272 276 279 282 285 289 292 295 298 302
--   305 308 311 315 318 321 324 328 331 334 337 341 344
------------------------------------------------------------
ns.GEAR_TRACKS = {
    Adventurer = { 266, 269, 272, 276, 279, 282 },
    Veteran    = { 279, 282, 285, 289, 292, 295 },
    Champion   = { 292, 295, 298, 302, 305, 308 },
    Hero       = { 305, 308, 311, 315, 318, 321 },
    Myth       = { 318, 321, 324, 328, 331, 334 },
}

------------------------------------------------------------
-- Above-Myth item levels.
--
-- Season 2 has power above Myth 6/6 (334) that is NOT reachable with
-- crests, so it deliberately lives outside GEAR_TRACKS:
--   * Ascendant Venomstones (later in the season) upgrade fully
--     upgraded Hero / Myth / max-quality crafted weapons, trinkets and
--     — new in S2 — necklaces. 10 Venomstones per upgrade.
--   * "Myth 9" is the item level Blizzard quotes for Very Rare items
--     and drops from the last two Mythic bosses, both as boss drops
--     and from the Great Vault.
------------------------------------------------------------
ns.ASCENDANT = {
    HERO_CRAFT  = 324,  -- max-quality crafted at Hero level + Venomstone
    HERO        = 328,  -- Hero 6/6 (321) + Venomstone
    MYTH_CRAFT  = 337,  -- max-quality crafted at Myth level + Venomstone
    MYTH        = 341,  -- Myth 6/6 (334) + Venomstone; the "Myth 8" cap
    MYTH_9      = 344,  -- Very Rare + last two Mythic bosses
}
ns.VENOMSTONES_PER_UPGRADE = 10
ns.VENOMSTONE_SLOTS = { "Weapon", "Trinket", "Neck" }

-- Which crest track is used to upgrade each gear track
ns.TRACK_CREST = {
    Adventurer = "Adventurer",
    Veteran    = "Veteran",
    Champion   = "Champion",
    Hero       = "Hero",
    Myth       = "Myth",
}

-- Track ordering (low to high value)
ns.TRACK_ORDER = { "Adventurer", "Veteran", "Champion", "Hero", "Myth" }
ns.TRACK_RANK = {}
for i, t in ipairs(ns.TRACK_ORDER) do
    ns.TRACK_RANK[t] = i
end

------------------------------------------------------------
-- Crafted item level ranges by crest quality (Season 2)
--
-- INFERRED — the crafting ladder is the least well-attested part of the
-- Season 2 data. Anchors come from norumu's sheet ("Blues + 80
-- Adventurer Crests" at 266, "+80 Veteran" at 282, "Spark of Tides" at
-- 295, "+80 Hero" at 308, "+80 Myth" at 321) with the S1 shape applied
-- on top (each tier's max == the next tier's min). Verify at the
-- crafting order UI once 12.1 is live.
------------------------------------------------------------
ns.CRAFTED_RANGES = {
    Adventurer = { min = 266, max = 279 },
    Veteran    = { min = 282, max = 295 },
    Champion   = { min = 295, max = 308 },
    Hero       = { min = 308, max = 321 },
    Myth       = { min = 321, max = 334 },
}

------------------------------------------------------------
-- Crafting constants
------------------------------------------------------------
ns.CRAFT_CREST_COST = 80              -- crests to craft a spark item (equivalent to 5/6)
ns.VETERAN_EMBELLISH_RESERVE = 160    -- save this many Veteran crests for embellishment crafts

------------------------------------------------------------
-- Crest income the season cap does not measure.
--
-- `useTotalEarnedForMaxQty` makes the client report a crest as capped
-- once totalEarned reaches maxQuantity, and for most income that is the
-- truth. It is not the truth for quest-box crests: the boxes handed out
-- by weekly activities pay Veteran crests that do not count against the
-- allowance, so a character sitting at 100/100 can still collect a
-- couple of hundred more this week.
--
-- That gap is not cosmetic. Everything downstream that asks "can I earn
-- more of this" -- the hold-crests advice, the scarcity flag, the whole
-- budget -- was answering from `totalEarned` alone, so a capped Veteran
-- track told the player to hoard against a ceiling they were about to
-- walk straight through.
--
-- What is recorded here is the SHAPE of that income, not a live number.
-- The addon cannot see which of these a character has turned in without
-- quest ids, and guessing would be worse than admitting the gap -- so
-- the budget treats this as "the cap is not the real ceiling" and the
-- panel says so, rather than quietly inflating the affordable count.
--
-- Sourced from community gearing coverage of the 12.1 pre-season, Aug
-- 2026. Verify when the season rolls: the uncapped boxes are a
-- pre-season quirk and are the sort of thing a hotfix closes.
--
-- Two KINDS of income live here and they are kept apart on purpose.
-- `boxes` repeat every week, so they are headroom the track gets again
-- next reset. `once` is a season-opening quest a character can only ever
-- be paid for one time -- real headroom for someone gearing up, and
-- nothing at all for a character who cleared them in week one. Summing
-- the two would tell a capped player in week twelve that Hero crests
-- still rain from the sky.
ns.UNCAPPED_CREST_SOURCES = {
    Veteran = {
        perBox = 20,
        boxes = {
            "Special Assignments in Midnight zones (2 active, rotate every 3.5 days)",
            "Special Assignment on the Coiled Isle",
            "Curse Surge weekly (3 of them)",
            "Trailing Xalatath -- Vereesa, Silvermoon",
            "Lady Liadrin weekly, Silvermoon",
            "Abundance (Zul'Aman is the quickest)",
            "Saltheril's Soiree runestone defense",
            "Legends of the Haranir (Aln'hara's Bloom is a 2-minute run)",
            "Stormarion Assault (first Epic box only -- later boxes pay nothing)",
        },
    },
    -- Hero and Myth have no weekly boxes at all -- these are the two
    -- season-opening quests, and they are the whole reason a fresh
    -- character can spend past a Hero cap in the first week.
    -- Source: Larias' Raider's Guide for S2 Midnight (lariasguide.com),
    -- which credits Squishei for confirming the nemesis boss pays
    -- uncapped crests in Season 2. Amounts are per character, once.
    Hero = {
        once = {
            { amount = 60, label = "Azta'rec, the Venomfall Deeps nemesis boss (can be done in a group)" },
            { amount = 20, label = "Cracked Keystone -- the Season 2 tier 11 delve quest" },
        },
    },
    Myth = {
        once = {
            { amount = 30, label = "Azta'rec, the Venomfall Deeps nemesis boss (can be done in a group)" },
            { amount = 20, label = "Cracked Keystone -- the Season 2 tier 11 delve quest" },
        },
    },
}

--- Crests a track can still be given this week outside its season cap.
---
--- REPEATING income only -- see the note above. Returns 0 for every
--- track with no such income, which is all of them but Veteran. The
--- count is an upper bound over untouched weeklies, so callers must
--- present it as headroom rather than as crests in hand.
function ns:GetUncappedCrestIncome(crestTrack)
    local src = ns.UNCAPPED_CREST_SOURCES[crestTrack]
    if not src then return 0, 0 end
    return (src.perBox or 0) * #(src.boxes or {}), #(src.boxes or {})
end

--- Crests a track can be given once per character, outside the cap.
---
--- Deliberately NOT folded into the budget: nothing the client exposes
--- says whether this character has already handed the quests in, and a
--- number that only counts down for players who never look at it is
--- worse than no number. Callers that show it must say "once per
--- character", never "you can still earn".
function ns:GetOneShotCrestIncome(crestTrack)
    local src = ns.UNCAPPED_CREST_SOURCES[crestTrack]
    if not src or not src.once then return 0, 0 end
    local total = 0
    for _, entry in ipairs(src.once) do
        total = total + (entry.amount or 0)
    end
    return total, #src.once
end

------------------------------------------------------------
-- Key strategic facts
------------------------------------------------------------
-- When you max a lower track, the item auto-promotes to the next track.
-- These ranks are "free" — covered by cheaper crests from the previous track.
-- e.g., maxing Champion gives you Hero 2/6 without spending Hero crests.
--
-- Season 2 tracks are perfectly regular (each starts 4 ladder steps above
-- the last, each is 6 ranks long), so the overlap is exactly 2 ranks for
-- every track — including Veteran, which was 1 in Season 1.
ns.TRACK_FREE_RANKS = {
    Veteran    = { count = 2, prevTrack = "Adventurer" },
    Champion   = { count = 2, prevTrack = "Veteran" },
    Hero       = { count = 2, prevTrack = "Champion" },
    Myth       = { count = 2, prevTrack = "Hero" },
}


-- Vault breakpoint value (crests-per-week equivalent bonus)
ns.VAULT_BREAKPOINTS = {
    [3] = 0.40,  -- 3/6 from vault = 40% more crests/week value
    [4] = 0.60,  -- 4/6 from vault = 60% more crests/week value
}

-- Crest save discount is 50% and works for ALL crest types
ns.CREST_SAVE_DISCOUNT = 0.50

------------------------------------------------------------
-- Consumable / raid-buff spell ID registry (Midnight S1)
-- Single source of truth — ReadyCheck.lua and RaidUI.lua both read from
-- here. Previously each file carried its own list and they drifted
-- (RaidUI was still carrying Dragonflight flask IDs against Midnight S1
-- content). Add new IDs here only.
-- Name-pattern fallbacks ("Well Fed", "Phial of ...", "Flask of ...") are
-- still applied per-consumer to catch anything we miss.
------------------------------------------------------------
ns.CONSUMABLE_SPELL_IDS = {
    FOOD = {
        382145, 382150, 382146, 382149, 382246,
        396092, 382247,
        382152, 382153, 382157, 382154, 382155, 382156,
        382230, 382231, 382232, 382234, 382235, 382236,
    },
    FLASK = {
        1236763, 1239355, 1235057, 1239755, 1236767,
        1235111, 1235110, 1235108,
    },
    -- Evoker "Blessing of the Bronze" grants a class-specific sub-aura per
    -- raider; match any of them as "movement speed raid buff present".
    BRONZE = {
        381732, 381741, 381746, 381748, 381749, 381750,
        381751, 381752, 381753, 381754, 381756, 381757, 381758,
    },
}

------------------------------------------------------------
-- Dungeon loot reference (M+ key level -> loot ilvl, vault ilvl)
-- Season 2. Crest column matches the in-game Mistcrest descriptions:
-- Heroic -> Veteran, M0 -> Champion, +2..+3 -> Champion,
-- +4..+8 -> Hero, +9 and up -> Myth.
------------------------------------------------------------
-- Source: norumu's community sheet, "Dungeons Drops" (column O) read
-- against the item level ladder (column C).
--
-- These were briefly replaced with numbers from a /yh ejtest probe. That
-- probe was wrong: it compared GetLootInfoByIndex(1) across difficulties,
-- but index 1 is not the same item at every difficulty, so it was
-- comparing unrelated items. The sheet's values stand.
--
-- Normal / Heroic / M0 are independently confirmed — they match both the
-- journal's own baseline and an in-game tooltip (M0 reads
-- "Champion 1/6 / 292").
ns.DUNGEON_LOOT = {
    { key = "Heroic", loot = 276, vault = 289 },
    { key = "M0",     loot = 292, vault = 302 },
    { key = "M2",     loot = 295, vault = 305 },
    { key = "M3",     loot = 295, vault = 305 },
    { key = "M4",     loot = 298, vault = 308 },
    { key = "M5",     loot = 302, vault = 308 },
    { key = "M6",     loot = 305, vault = 311 },
    { key = "M7",     loot = 305, vault = 315 },
    { key = "M8",     loot = 308, vault = 315 },
    { key = "M9",     loot = 308, vault = 315 },
    { key = "M10",    loot = 311, vault = 318 },
    { key = "M11",    loot = 311, vault = 318 },
    { key = "M12",    loot = 311, vault = 318 },
}

------------------------------------------------------------
-- The key level above which gear stops improving.
--
-- Both columns above flatten before the key ceiling does: +10, +11 and
-- +12 all drop 311 and all vault 318. So past that point a higher key
-- buys rating and nothing else -- which the game never says, and which
-- is why people grind +12s believing the vault is still climbing.
--
-- Derived rather than written down, so a corrected row in DUNGEON_LOOT
-- moves the answer instead of leaving a stale constant behind it.
-- Returns keyLevel, loot, vault, or nil if the table has no M+ rows.
------------------------------------------------------------
function ns:GetKeyGearCeiling()
    local maxLoot, maxVault = 0, 0
    for _, entry in ipairs(ns.DUNGEON_LOOT or {}) do
        if tonumber(entry.key:match("M(%d+)")) then
            if (entry.loot or 0) > maxLoot then maxLoot = entry.loot end
            if (entry.vault or 0) > maxVault then maxVault = entry.vault end
        end
    end
    if maxLoot == 0 then return nil end

    -- Lowest key that reaches both ceilings: the first level at which
    -- pushing further stops paying in item level.
    local best
    for _, entry in ipairs(ns.DUNGEON_LOOT) do
        local level = tonumber(entry.key:match("M(%d+)"))
        if level and entry.loot == maxLoot and entry.vault == maxVault then
            if not best or level < best then best = level end
        end
    end
    if not best then return nil end
    return best, maxLoot, maxVault
end

------------------------------------------------------------
-- Raid reference anchors
------------------------------------------------------------
ns.RAID_TRACKS = {
    Normal  = "Champion",
    Heroic  = "Hero",
    Mythic  = "Myth",
}

------------------------------------------------------------
-- Great Vault raid rewards (Season 2).
--
-- New in 12.1: LFR / Normal / Heroic vault rewards always jump to the
-- FIRST rank of the next track up, and the Mythic vault hands out a
-- fully upgraded Myth 6/6 piece. Very Rare items and drops from the
-- penultimate and final bosses come in at "Myth 9" (344) whether they
-- drop off the boss or out of the vault.
--
-- This is the single most important number change of the patch: a
-- Heroic vault slot is now worth a Myth 1/6 (318), not a Hero piece.
------------------------------------------------------------
ns.RAID_VAULT_TRACKS = {
    LFR    = { track = "Champion", rank = 1, ilvl = 292 },
    Normal = { track = "Hero",     rank = 1, ilvl = 305 },
    Heroic = { track = "Myth",     rank = 1, ilvl = 318 },
    Mythic = { track = "Myth",     rank = 6, ilvl = 334 },
}
ns.RAID_VERY_RARE_ILVL = 344   -- Very Rare + last two Mythic bosses

------------------------------------------------------------
-- Honest framing for "best" lists.
--
-- A best-in-slot table and a sim ranking both answer a question the
-- player is not asking. They ask "is this drop good for me"; both
-- sources answer "here is the best item in the abstract". Those are
-- different questions, because an item's value depends on the set it
-- lands in — stat weights move as gear changes, and a table presented
-- without that caveat implies a certainty it does not have.
--
-- Shared rather than written per page so the trinket list and the
-- best-in-slot list cannot drift into saying different things about the
-- same limitation.
------------------------------------------------------------
ns.GEAR_CAVEAT = {
    bis = "This is where the season ends, not the route there — you will "
        .. "spend most of it wearing things that are not on this list.\n"
        .. "Whether a drop is an upgrade depends on the rest of your gear. "
        .. "Stat weights shift as your set changes, so a piece ranked lower "
        .. "here can still be the better one on you. Sim what actually drops.",

    trinket = "These sim one trinket at a time against a fixed character, "
        .. "and you are not that character.\n"
        .. "Trinkets interact with your stats, your other trinket and your "
        .. "set bonuses, so a lower-ranked one can win in your bags. Use this "
        .. "to narrow the field, then sim the pair you actually own.",
}

------------------------------------------------------------
-- What the Catalyst does now, in 12.1.
--
-- A best-in-slot list can name armour in every class-set slot and not
-- one tier token, and since 12.1 that is the answer rather than an
-- omission: class set armour inherits the secondary stats of whatever
-- you convert, and certain item effects travel with it. So the chase is
-- the named piece, and the Catalyst is the last step on it rather than
-- a separate source you go to instead.
--
-- Here rather than in ClassGuideData because that file is generated: a
-- hand-written paragraph in it survives until the next scrape.
------------------------------------------------------------
ns.CATALYST_NOTE = {
    -- The conclusion, on the page. Kept to one line at the widths this
    -- page is drawn at -- it sits above the doll, and the doll pays for
    -- anything taller.
    line = "Class set inherits the secondary stats — and item effects "
        .. "— of the piece you convert. Chase the items here, not the token.",

    title = "The Catalyst changed in 12.1",

    -- The rest, on hover.
    detail = {
        "Class set armour now keeps the secondary stats of the item you "
            .. "convert, and certain special effects travel with it — "
            .. "Ula'tek's Venomcursed cantrip among them.",
        "That is why this list can name armour in every class-set slot "
            .. "and no tier at all. The named piece IS the tier piece, one "
            .. "Catalyst charge later, and rows tagged +cat say which item "
            .. "feeds which.",
        "The Venomous Abyss still drops class set armour directly. A "
            .. "direct drop rolls its own secondaries and carries no item "
            .. "effect, and you choose neither.",
        "Ahead of the Curve or Keystone Master grants 3 extra Catalyst "
            .. "charges this season.",
    },
}

------------------------------------------------------------
-- Where each slot sits on a paper doll.
--
-- The character sheet's order, not the inventory index order: head down
-- the left, hands down the right, weapons across the bottom. Reading a
-- doll by slot id puts Wrist between Feet and Ring 1 and nobody can
-- find anything.
--
-- Here rather than in either page because BOTH draw a doll, and they had
-- drifted: the best-in-slot page used this order while the gear page
-- used its own, so the same character read differently depending on
-- which page you were on.
--
-- `side` is "L", "R", or "W" for the weapon row that spans both.
------------------------------------------------------------
ns.DOLL_LAYOUT = {
    { slot = 1,  side = "L", row = 1, name = "Head"      },
    { slot = 2,  side = "L", row = 2, name = "Neck"      },
    { slot = 3,  side = "L", row = 3, name = "Shoulders" },
    { slot = 15, side = "L", row = 4, name = "Back"      },
    { slot = 5,  side = "L", row = 5, name = "Chest"     },
    { slot = 9,  side = "L", row = 6, name = "Wrist"     },
    { slot = 13, side = "L", row = 7, name = "Trinket 1" },
    { slot = 10, side = "R", row = 1, name = "Hands"     },
    { slot = 6,  side = "R", row = 2, name = "Waist"     },
    { slot = 7,  side = "R", row = 3, name = "Legs"      },
    { slot = 8,  side = "R", row = 4, name = "Feet"      },
    { slot = 11, side = "R", row = 5, name = "Ring 1"    },
    { slot = 12, side = "R", row = 6, name = "Ring 2"    },
    { slot = 14, side = "R", row = 7, name = "Trinket 2" },
    { slot = 16, side = "W", row = 8, name = "Main Hand" },
    { slot = 17, side = "W", row = 8, name = "Off Hand"  },
}

--- The layout as two columns, for pages that draw it that way.
--- The weapon row splits: main hand under the left column, off hand
--- under the right, which lands them side by side on the same row.
function ns:GetDollColumns()
    local left, right = {}, {}
    for _, e in ipairs(ns.DOLL_LAYOUT) do
        if e.side == "L" then left[#left + 1] = e.slot
        elseif e.side == "R" then right[#right + 1] = e.slot
        end
    end
    for _, e in ipairs(ns.DOLL_LAYOUT) do
        if e.side == "W" then
            if #left <= #right then left[#left + 1] = e.slot
            else right[#right + 1] = e.slot end
        end
    end
    return left, right
end

------------------------------------------------------------
-- Slots whose high-water mark is shared, and taken from the LOWER
-- of the two.
--
-- Rings and trinkets are one mark between two slots, and it only moves
-- when BOTH pieces reach the level. Carrying one trinket to 308 while
-- its partner sits at 292 leaves the mark at 292: the next piece to
-- land in either slot is lifted to 292 and no further, and the hundred
-- crests spent bought item level on one item rather than a rebate on
-- the next.
--
-- Which makes a pair a single purchase priced at two. The advisor has
-- to know that before it recommends finishing one of them, or it
-- promises a free rank that will not arrive.
------------------------------------------------------------
ns.SLOT_PAIRS = {
    [11] = 12, [12] = 11,   -- Ring 1 / Ring 2
    [13] = 14, [14] = 13,   -- Trinket 1 / Trinket 2
}

------------------------------------------------------------
-- Slot priority (higher = more valuable to upgrade)
------------------------------------------------------------
ns.SLOT_PRIORITY = {
    [16] = 5, -- Main Hand (weapon)
    [17] = 5, -- Off Hand (weapon)
    [5]  = 4, -- Chest
    [7]  = 4, -- Legs
    [1]  = 4, -- Helm
    [13] = 4, -- Trinket 1
    [14] = 4, -- Trinket 2
    [3]  = 3, -- Shoulder
    [10] = 3, -- Hands
    [8]  = 3, -- Feet
    [11] = 3, -- Ring 1
    [12] = 3, -- Ring 2
    [2]  = 2, -- Neck
    [6]  = 2, -- Waist
    [15] = 2, -- Back
    [9]  = 2, -- Wrist
}

------------------------------------------------------------
-- Crest value tiers (higher = more precious, spend carefully)
------------------------------------------------------------
ns.CREST_VALUE = {
    Adventurer = 1,
    Veteran    = 2,
    Champion   = 3,
    Hero       = 4,
    Myth       = 5,
}

------------------------------------------------------------
-- Player profiles (3 tiers matching real progression paths)
------------------------------------------------------------
ns.PROFILES = {
    {
        id = "normal",
        name = "Normal",
        desc = "Casual / Delves / M+ up to 8",
        maxKeyLevel = 8,
        raidTier = "Normal",
        preciousCrests = { "Champion", "Hero", "Myth" },
        freeCrests = { "Adventurer", "Veteran" },
        -- Content drops up to Champion track from M+8 end-of-dungeon
        -- Hero from vault at M+6-8
        farmableTrack = "Champion",
    },
    {
        id = "heroic",
        name = "Heroic",
        desc = "Heroic Raid / M+ 10",
        maxKeyLevel = 10,
        raidTier = "Heroic",
        preciousCrests = { "Hero", "Myth" },
        freeCrests = { "Adventurer", "Veteran", "Champion" },
        -- Hero drops from heroic raid + M+10 end-of-dungeon
        -- Myth from vault only (~1/week)
        farmableTrack = "Hero",
    },
    {
        id = "mythic",
        name = "Mythic",
        desc = "Mythic Raid / M+ 10+",
        maxKeyLevel = 12,
        raidTier = "Mythic",
        preciousCrests = { "Myth" },
        freeCrests = { "Adventurer", "Veteran", "Champion", "Hero" },
        -- Myth drops from mythic raid + high M+ vault
        -- Hero is plentiful
        farmableTrack = "Myth",
    },
}

------------------------------------------------------------
-- Helpers: look up track from item level
------------------------------------------------------------
function ns:GetTrackFromIlvl(ilvl)
    -- Walk tracks from highest to lowest, return first match
    for i = #ns.TRACK_ORDER, 1, -1 do
        local track = ns.TRACK_ORDER[i]
        local levels = ns.GEAR_TRACKS[track]
        if ilvl >= levels[1] and ilvl <= levels[#levels] then
            return track
        end
    end
    return nil
end

function ns:GetRankInTrack(track, ilvl)
    local levels = ns.GEAR_TRACKS[track]
    if not levels then return nil, nil end
    for i, lvl in ipairs(levels) do
        if ilvl == lvl then
            return i, #levels
        end
    end
    return nil, #levels
end

function ns:GetMaxIlvlForTrack(track)
    local levels = ns.GEAR_TRACKS[track]
    if levels then
        return levels[#levels]
    end
    return 0
end

function ns:GetCurrentProfile()
    local profileId = YippYappHelperDB and YippYappHelperDB.profile or "heroic"
    -- Migration: map old profile IDs to new ones
    local migration = {
        casual = "normal", heroic_raider = "heroic", mythic_raider = "mythic",
        mplus_mid = "normal", mplus_high = "heroic", alt = "normal",
    }
    if migration[profileId] then
        profileId = migration[profileId]
        if YippYappHelperDB then YippYappHelperDB.profile = profileId end
    end
    for _, profile in ipairs(ns.PROFILES) do
        if profile.id == profileId then
            return profile
        end
    end
    return ns.PROFILES[2] -- default heroic
end

function ns:IsCrestPrecious(crestTrack)
    local profile = ns:GetCurrentProfile()
    for _, t in ipairs(profile.preciousCrests) do
        if t == crestTrack then return true end
    end
    return false
end

function ns:IsCrestFree(crestTrack)
    local profile = ns:GetCurrentProfile()
    for _, t in ipairs(profile.freeCrests) do
        if t == crestTrack then return true end
    end
    return false
end

------------------------------------------------------------
-- UI scaling: calculate frame sizes based on screen space
------------------------------------------------------------
local TARGET_W = 960
local TARGET_H = 580
local SIDE_PANEL_W = 190  -- progression crest sources panel

function ns:GetAppFrameSize()
    local screenW = GetScreenWidth()
    local screenH = GetScreenHeight()

    -- Max width: leave room for side panel + edges (80% of screen)
    local maxW = math.floor(screenW * 0.80) - SIDE_PANEL_W
    -- Max height: 85% of screen
    local maxH = math.floor(screenH * 0.85)

    local w = math.min(TARGET_W, math.max(maxW, 700))
    local h = math.min(TARGET_H, math.max(maxH, 450))

    return w, h
end

function ns:GetUIScale()
    local w = ns:GetAppFrameSize()
    return w / TARGET_W
end

------------------------------------------------------------
-- Shared visual helpers (inspired by Plumber addon)
------------------------------------------------------------

-- Consistent text color hierarchy
ns.COLORS = {
    TEXT_PRIMARY   = { 0.92, 0.92, 0.92 },  -- near white, main text
    TEXT_SECONDARY = { 0.55, 0.55, 0.55 },  -- medium gray, descriptions
    TEXT_TERTIARY  = { 0.35, 0.35, 0.35 },  -- dark gray, hints/disabled
    TEXT_HEADER    = { 0.70, 0.70, 0.70 },  -- section headers
    ACCENT_GREEN   = { 0.0, 1.0, 0.3 },
    ACCENT_GOLD    = { 1.0, 0.82, 0.0 },
}

-- Disable texture sharpening for smooth edges at any scale
function ns.DisableSharpening(texture)
    if texture.SetTexelSnappingBias then
        texture:SetTexelSnappingBias(0)
    end
    if texture.SetSnapToPixelGrid then
        texture:SetSnapToPixelGrid(false)
    end
end

-- Apply smooth anti-aliased look to a BackdropTemplate frame's border textures
function ns.SmoothFrame(frame)
    for _, region in pairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then
            ns.DisableSharpening(region)
        end
    end
end

-- Apply text shadow for depth
function ns.ApplyTextShadow(fontString)
    fontString:SetShadowColor(0, 0, 0, 0.8)
    fontString:SetShadowOffset(1, -1)
end

------------------------------------------------------------
-- Window header
--
-- The app frame sets the house style: a full-bleed icon at PAD, centred
-- on the band between the window's top edge and the content below, with
-- the title beside it. Windows that can also open standalone build their
-- header through here so both routes look the same.
--
-- Anything drawn under a header should sit at HEADER_H + HEADER_GAP.
------------------------------------------------------------
ns.HEADER_H    = 32
ns.HEADER_GAP  = 4
ns.HEADER_ICON = 28

--- Vertical centre of the header band, as a negative offset from a
--- frame's TOPLEFT. Anchor header widgets by their LEFT/RIGHT to this and
--- they line up regardless of their own height.
function ns.HeaderCenterY()
    return -(ns.HEADER_H + ns.HEADER_GAP) / 2
end

--- Builds icon + title (+ optional subtitle). Returns all three so the
--- caller can hide or recolour them.
function ns.MakeWindowHeader(frame, titleText, subText, pad)
    pad = pad or 16
    local cy = ns.HeaderCenterY()

    -- Deliberately no icon. The addon mark belongs on the dashboard and
    -- the app's home screen only; repeating it on every sub-page and
    -- standalone window made them read as separate addons rather than as
    -- pages of one. Consistent title placement is what ties them
    -- together, not a repeated logo.
    local icon = nil

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", frame, "TOPLEFT", pad, cy)
    title:SetText(titleText or "")
    ns.ApplyTextShadow(title)

    local sub
    if subText then
        sub = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sub:SetPoint("LEFT", title, "RIGHT", 8, 0)
        sub:SetTextColor(unpack(ns.COLORS.TEXT_TERTIARY))
        sub:SetText(subText)
        ns.ApplyTextShadow(sub)
    end
    return icon, title, sub
end

-- Create a smooth ADD-blend highlight on a frame (replaces flat color hovers)
function ns.AddGlowHighlight(frame, alpha)
    local hl = frame:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, alpha or 0.06)
    hl:SetBlendMode("ADD")
    return hl
end

------------------------------------------------------------
-- Shared tab.
--
-- These were a row of words with a two-pixel mark under whichever one
-- was current, and nothing else: no container, no rule, no shared edge.
-- That does not read as a set of choices -- it reads as one highlighted
-- label -- because the indicator had nothing to sit ON. An underline
-- only means "selected" when there is a line for it to be part of.
--
-- Three things changed, and they work together:
--
--   * every tab carries a faint line along its own bottom edge, always,
--     so the strip has a rail whether or not its container drew one;
--   * the active mark is thicker and spans the tab rather than being
--     inset, so it reads as a segment of that rail rather than as a
--     dash under a word;
--   * the active LABEL goes bright rather than accent-coloured. Colour
--     was doing the selection job and the underline was decoration;
--     now the underline carries it and brightness backs it up, which is
--     the pairing people already read as tabs.
--
-- Returns a button with .label, .selectedBar and .baseLine.
------------------------------------------------------------
function ns.CreateUnderlineTab(parent, text, activeColor)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(24)
    btn:EnableMouse(true)

    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("CENTER", 0, 1)
    lbl:SetText(text)
    lbl:SetTextColor(unpack(ns.COLORS.TEXT_SECONDARY))
    ns.ApplyTextShadow(lbl)
    btn.label = lbl

    -- The rail. Drawn per tab as well as per strip so a page that never
    -- gave its tabs a container still gets one; where a strip does draw
    -- a continuous rule, this simply coincides with it.
    local base = btn:CreateTexture(nil, "ARTWORK")
    base:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    base:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    base:SetHeight(1)
    local sc = ns.COLORS.TEXT_SECONDARY
    base:SetColorTexture(sc[1], sc[2], sc[3], 0.22)
    btn.baseLine = base

    local sel = btn:CreateTexture(nil, "OVERLAY")
    sel:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    sel:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    sel:SetHeight(3)
    sel:SetColorTexture(activeColor[1], activeColor[2], activeColor[3], 1)
    sel:Hide()
    btn.selectedBar = sel

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.04)
    hl:SetBlendMode("ADD")

    btn.activeColor = activeColor
    return btn
end

--- The continuous rule a strip of tabs sits on.
---
--- Drawn on the strip rather than assembled from the tabs, because a
--- rule made of per-tab segments has a hole wherever the tabs have a
--- gap. Safe to call repeatedly; the first call is the one that counts.
function ns.TabBaseline(strip, inset)
    if not strip then return nil end
    if strip._tabBaseline then return strip._tabBaseline end
    local line = strip:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", inset or 0, 0)
    line:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", -(inset or 0), 0)
    local c = ns.COLORS.TEXT_SECONDARY
    line:SetColorTexture(c[1], c[2], c[3], 0.22)
    strip._tabBaseline = line
    return line
end

function ns.SetTabActive(tab)
    tab.selectedBar:Show()
    tab.label:SetTextColor(unpack(ns.COLORS.TEXT_PRIMARY))
end

function ns.SetTabInactive(tab)
    tab.selectedBar:Hide()
    tab.label:SetTextColor(unpack(ns.COLORS.TEXT_SECONDARY))
end

------------------------------------------------------------
-- Map waypoints
--
-- Parses the "/way #2393 47.9 51.6" form used by guide sites and drops a
-- real Blizzard map pin, super-tracked so the arrow appears immediately.
-- Coordinates in that format are percentages; UiMapPoint wants 0-1.
------------------------------------------------------------

--- mapID, x, y from a "/way #map x y" string, or nil if it doesn't parse.
function ns.ParseWaypoint(str)
    if type(str) ~= "string" then return nil end
    local mapID, x, y = str:match("#(%d+)%s+([%d%.]+)%s+([%d%.]+)")
    mapID, x, y = tonumber(mapID), tonumber(x), tonumber(y)
    if not (mapID and x and y) then return nil end
    return mapID, x, y
end

--- Place and super-track a map pin. Returns true on success.
function ns.SetWaypoint(mapID, x, y, label)
    if not (mapID and x and y) then return false end
    if InCombatLockdown() then
        print("|cff00ff00YippYapp|r: Can't set a map pin in combat.")
        return false
    end
    if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint) then return false end

    -- Some maps (instances, scenarios) refuse user waypoints outright.
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then
        print(("|cff00ff00YippYapp|r: The game won't allow a pin on that map (%s). Use |cffffffff/way #%d %.1f %.1f|r.")
            :format(label or "unknown", mapID, x, y))
        return false
    end

    local ok = pcall(function()
        local point = UiMapPoint.CreateFromCoordinates(mapID, x / 100, y / 100)
        C_Map.SetUserWaypoint(point)
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
    end)
    if ok and label then
        print(("|cff00ff00YippYapp|r: Pin set — |cffffffff%s|r"):format(label))
    end
    return ok
end

-- The same map-pin art Blizzard puts on a /way pin, so the chip reads as
-- a waypoint. Falls back to the old tracking icon if the atlas is ever
-- renamed out from under us.
local function PinMarkup(atlas)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        return ("|A:%s:16:12|a"):format(atlas)
    end
    return "|TInterface\\MINIMAP\\TRACKING\\None:12:12|t"
end

local PIN_ICON     = PinMarkup("Waypoint-MapPin-Untracked")
local PIN_ICON_LIT = PinMarkup("Waypoint-MapPin-Tracked")

--- A clickable "pin" chip for a /way string. Returns the button (height
--- 16) or nil when the string doesn't parse.
---
--- The button carries a :Rebind(wayString, label) so pooled buttons can
--- be pointed at new coordinates without duplicating the scripts.
function ns.MakeWaypointButton(parent, wayString, label)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(18)   -- the pin art is 16 tall; give it room to click

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", 0, 0)
    btn._fs = fs

    local function paint(hex, icon)
        if not btn._x then return end
        fs:SetText(("%s|c%s %.1f, %.1f|r"):format(icon, hex, btn._x, btn._y))
        btn:SetWidth(fs:GetStringWidth() + 16)
    end

    function btn:Rebind(str, lbl)
        local mapID, x, y = ns.ParseWaypoint(str)
        if not mapID then return false end
        self._mapID, self._x, self._y, self._label = mapID, x, y, lbl
        paint("ff66bbff", PIN_ICON)
        return true
    end

    btn:SetScript("OnClick", function(self)
        ns.SetWaypoint(self._mapID, self._x, self._y, self._label)
    end)
    btn:SetScript("OnEnter", function(self)
        paint("ffffffff", PIN_ICON_LIT)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self._label or "Waypoint")
        GameTooltip:AddLine("Click to place a map pin", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        paint("ff66bbff", PIN_ICON)
        GameTooltip:Hide()
    end)

    if not btn:Rebind(wayString, label) then return nil end
    return btn
end

-- Smooth fade-in for a frame (call on OnEnter, auto-stops)
function ns.FadeIn(frame, duration)
    duration = duration or 0.12
    frame._fadeAlpha = frame:GetAlpha()
    frame:SetAlpha(0)
    frame:Show()
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local progress = math.min(elapsed / duration, 1)
        self:SetAlpha(progress)
        if progress >= 1 then
            self:SetScript("OnUpdate", nil)
        end
    end)
end
