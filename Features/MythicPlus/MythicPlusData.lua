local _, ns = ...

------------------------------------------------------------
-- Mythic Plus Data: API wrappers and keystone sharing
------------------------------------------------------------

-- Addon comm prefix for keystone sharing
local COMM_PREFIX = "YYH_MPLUS"
C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)

------------------------------------------------------------
-- Own keystone
------------------------------------------------------------
function ns:GetOwnKeystone()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus.GetOwnedKeystoneLevel()
    if not mapID or not level then return nil end
    local name = C_ChallengeMode.GetMapUIInfo(mapID)
    return { mapID = mapID, level = level, name = name or "Unknown" }
end

------------------------------------------------------------
-- Own M+ rating
------------------------------------------------------------
function ns:GetOwnMPlusRating()
    return C_ChallengeMode.GetOverallDungeonScore() or 0
end

------------------------------------------------------------
-- Per-unit M+ rating summary
-- Returns: { rating = number, runs = { [mapID] = { score, level, success } } }
------------------------------------------------------------
function ns:GetUnitMPlusSummary(unit)
    local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
    if not summary then return nil end

    local result = {
        rating = summary.currentSeasonScore or 0,
        runs = {},
    }

    if summary.runs then
        for _, run in ipairs(summary.runs) do
            result.runs[run.challengeModeID] = {
                score = run.mapScore or 0,
                level = run.bestRunLevel or 0,
                success = run.finishedSuccess,
            }
        end
    end

    return result
end

------------------------------------------------------------
-- Current season dungeon maps
-- Uses C_ChallengeMode.GetMapTable() filtered to current
-- rotation (maps that appear in the LFG M+ UI)
------------------------------------------------------------
-- Preferred display order for current season dungeons
-- Midnight Season 2 rotation (keys live 18 Aug 2026): the new Altar of
-- Fangs, the four Midnight dungeons held back from S1, and three legacy
-- dungeons (Kings' Rest and Temple of Sethraliss from BfA, Ruby Life
-- Pools from Dragonflight).
local DUNGEON_ORDER = {
    "Altar of Fangs",
    "Murder Row",
    "Den of Nalorakk",
    "The Blinding Vale",
    "Voidscar Arena",
    "Kings' Rest",
    "Ruby Life Pools",
    "Temple of Sethraliss",
}

local DUNGEON_ORDER_MAP = {}
for i, name in ipairs(DUNGEON_ORDER) do
    DUNGEON_ORDER_MAP[name] = i
end

function ns:GetSeasonMaps()
    local maps = C_ChallengeMode.GetMapTable()
    if not maps then return {} end

    local result = {}
    for _, mapID in ipairs(maps) do
        local name, _, _, icon = C_ChallengeMode.GetMapUIInfo(mapID)
        if name then
            table.insert(result, { mapID = mapID, name = name, icon = icon })
        end
    end

    table.sort(result, function(a, b)
        local oa = DUNGEON_ORDER_MAP[a.name] or 999
        local ob = DUNGEON_ORDER_MAP[b.name] or 999
        if oa ~= ob then return oa < ob end
        return a.name < b.name
    end)
    return result
end

------------------------------------------------------------
-- Rating color (uses Blizzard's built-in color mapping)
------------------------------------------------------------
function ns:GetRatingColor(score)
    local color = C_ChallengeMode.GetDungeonScoreRarityColor(score)
    if color then
        return color.r, color.g, color.b
    end
    return 0.5, 0.5, 0.5
end

------------------------------------------------------------
-- Current affixes
------------------------------------------------------------
--- This week's affixes, in the order the client returns them.
---
--- The index matters and is carried through. C_MythicPlus.GetCurrentAffixes
--- gives back {id, seasonID} with no keystone level on it -- the level an
--- affix switches on at is its POSITION in the list. So index is the only
--- handle on "which slot is this affix filling", and the slot is exactly
--- what changes when Fortified and Tyrannical trade places.
function ns:GetCurrentAffixes()
    local affixes = C_MythicPlus.GetCurrentAffixes()
    if not affixes then return {} end

    local result = {}
    for i, affix in ipairs(affixes) do
        local name, desc, icon = C_ChallengeMode.GetAffixInfo(affix.id)
        if name then
            table.insert(result, {
                id = affix.id, name = name, desc = desc, icon = icon,
                index = i, seasonID = affix.seasonID,
            })
        end
    end
    return result
end

------------------------------------------------------------
-- Which affixes are worth a row
------------------------------------------------------------
-- Of the five affixes up in a week, two are pure season furniture --
-- the same affix in the same slot every Tuesday -- and those are the
-- only ones not worth a row.
--
-- The other three all tell you something:
--   the Xal'atath's Bargain, which is a different affix each week
--   Fortified and Tyrannical, which are BOTH up every week and swap
--   which keystone level they switch on at
--
-- So presence alone is not the test. Fortified and Tyrannical appear
-- every single week and would pass a presence check as furniture; what
-- makes them news is that their SLOT changes, and the slot is the
-- keystone level. An affix is hidden only when it is both always
-- present and always in the same place.
--
-- Which affixes those are is LEARNED, not written down. A hardcoded list
-- of seasonal affix ids is stale the day a season rolls, and it fails
-- silently in the worst direction: hiding the affix that changed while
-- showing the ones that did not.
--
-- Scoped per season, because ids do not carry across one and a record
-- from the last season would leave every new affix permanently short of
-- the observation count, and so permanently "new".
------------------------------------------------------------

--- The keystone levels each affix slot applies over.
---
--- Indexed by an affix's POSITION in C_MythicPlus.GetCurrentAffixes,
--- not by its id, because the id in a slot changes -- a different
--- Xal'atath's Bargain every week -- while the slot's range does not.
---
--- Each entry is { from, to }; `to` absent means "and up".
---
--- Season 2 of Midnight, per a community affix guide:
---   slot 1  +2 to +4    the beginner-aid affix, gone by +5
---   slot 2  +5 to +11   the week's Bargain, replaced at +12
---   slot 3  +7 and up   whichever of Fortified/Tyrannical is up this week
---   slot 4  +10 and up  the other one, which joins it from +10
---   slot 5  +12 and up  replaces the Bargain
---
--- Slots 3 and 4 are the reason this is a table and not arithmetic on
--- the index. Below +10 only ONE of Fortified/Tyrannical is active and
--- the pair alternates weekly; from +10 both are. So the two slots carry
--- different thresholds, and which affix is sitting in which is the
--- thing a player actually wants off this card.
---
--- The ordering assumption worth naming: slot 3 is taken to be the
--- week's active one and slot 4 the one that joins at +10, because the
--- client returns affixes in ascending order of when they apply. If a
--- week ever showed those two reversed, these labels would be swapped.
---
--- Hardcoded season data, so it goes stale on a season roll. It fails
--- visibly rather than silently -- a wrong threshold is a number the
--- player can check against their own keystone -- but verify it when a
--- season turns.
ns.AFFIX_LEVELS = {
    [0] = { { 2, 4 }, { 5, 11 }, { 7 }, { 10 }, { 12 } },
}

--- Slots whose row names another slot's affix alongside its own.
---
--- Keyed by season, then by the slot doing the naming, pointing at the
--- slot it borrows a name from. Season 2 of Midnight has one: the +10
--- row, where Fortified and Tyrannical stop alternating and both apply,
--- so it reads "Fortified + Tyrannical" rather than naming one of them
--- and leaving the reader to work out that the other is up too.
---
--- This replaced a footnote under the card saying the same thing in a
--- sentence. The row is where the fact belongs -- a badge reading "+10+"
--- beside one affix name is what was misleading, so the fix is to make
--- the name right rather than to add a line apologising for it.
ns.AFFIX_COMBINE = {
    [0] = { [4] = 3 },
}

--- The label for an affix row: its own name, or a combined one.
---
--- `list` is the week's affixes, needed because the partner slot has to
--- actually be up before its name can be borrowed.
function ns:GetAffixLabel(af, list)
    if type(af) ~= "table" or not af.name then return nil end
    local combine = ns.AFFIX_COMBINE[af.seasonID or 0]
    local partnerIdx = combine and combine[af.index or 0]
    if not partnerIdx then return af.name end
    for _, other in ipairs(list or {}) do
        if other.index == partnerIdx and other.name then
            return other.name .. " + " .. af.name
        end
    end
    return af.name
end

--- The keystone range an affix applies over: from, to.
---
--- `to` is nil for "and up". Both are nil when this season's thresholds
--- are not recorded -- a real answer, and callers must draw nothing for
--- it rather than a zero, since an affix badge reading "+0" is worse
--- than no badge at all.
function ns:GetAffixLevels(af)
    if type(af) ~= "table" or not af.index then return nil end
    local levels = ns.AFFIX_LEVELS[af.seasonID or 0]
    local e = levels and levels[af.index]
    if not e then return nil end
    return e[1], e[2]
end

--- The range as a short label: "+5-11", or "+7+" when open-ended.
function ns:GetAffixLevelText(af)
    local from, to = self:GetAffixLevels(af)
    if not from then return nil end
    if to then return "+" .. from .. "-" .. to end
    return "+" .. from .. "+"
end

--- A starting answer, so a fresh install is not blind for a week.
---
--- Keyed by seasonID. These are the affixes that are up every week AND
--- always at the same keystone level -- the season's own two. Fortified
--- and Tyrannical are deliberately NOT here: they are up every week too,
--- but they trade slots, and which one gates which key level is the
--- thing worth reading.
---
--- Recorded from a live client on 2026-08-19 via
--- /dump C_MythicPlus.GetCurrentAffixes(), which returned, in order:
---   165 Lindormi's Guidance     furniture -- hidden
---   162 Xal'atath's Bargain     changes identity each week
---    10 Fortified               swaps slots with Tyrannical
---     9 Tyrannical              swaps slots with Fortified
---   147 Xal'atath's Guile       furniture -- hidden
---
--- This is exactly the hardcoded list the learned model exists to avoid,
--- and it is safe only because it cannot outlive its usefulness: it
--- applies ONLY until two distinct weeks have been observed, after which
--- ns:GetAffixSplit ignores it entirely and goes on what it has seen. A
--- wrong seed therefore costs at most one week of hiding the wrong row,
--- and corrects itself without anyone editing this file.
---
--- seasonID reads 0 on this client, which is a real value and not a
--- missing one -- so the table is keyed with it rather than treating 0
--- as absent.
ns.AFFIX_FURNITURE = {
    [0] = { 165, 147 },
}

--- Note this week's affixes so the changing one can be told from the
--- standing ones. Idempotent: called on every refresh, records once per
--- distinct week.
function ns:ObserveAffixes(list)
    if type(list) ~= "table" or #list == 0 then return end

    YippYappHelperDB = YippYappHelperDB or {}
    local all = YippYappHelperDB.affixObs
    if type(all) ~= "table" then all = {}; YippYappHelperDB.affixObs = all end

    local season = list[1].seasonID or 0
    local rec = all[season]
    if type(rec) ~= "table" then
        rec = { weeks = 0, seen = {} }
        all[season] = rec
    end

    -- Signature carries the INDEX, so a week that swapped Fortified and
    -- Tyrannical without changing the set still counts as new data --
    -- that swap is precisely what marks the pair as worth showing.
    local parts = {}
    for _, af in ipairs(list) do
        parts[#parts + 1] = af.id .. "@" .. (af.index or 0)
    end
    local sig = table.concat(parts, ",")
    if rec.last == sig then return end
    rec.last = sig
    rec.weeks = (rec.weeks or 0) + 1

    for _, af in ipairs(list) do
        local e = rec.seen[af.id]
        if type(e) ~= "table" then
            rec.seen[af.id] = { n = 1, i = af.index or 0 }
        else
            e.n = e.n + 1
            -- -1 means "has been seen in more than one slot".
            if e.i ~= -1 and e.i ~= (af.index or 0) then e.i = -1 end
        end
    end
end

--- Splits this week's affixes into the ones that changed and the ones
--- that are up every week.
---
--- Returns changing[], standing[], learned. `learned` is false until two
--- distinct weeks have been seen, because one week of data cannot tell
--- the two apart -- and callers must show everything rather than guess
--- while it is false.
function ns:GetAffixSplit()
    local list = self:GetCurrentAffixes()
    if #list == 0 then return {}, {}, false end
    self:ObserveAffixes(list)

    local season = list[1].seasonID or 0
    local rec = (YippYappHelperDB and YippYappHelperDB.affixObs
                 and YippYappHelperDB.affixObs[season]) or nil
    local weeks = rec and rec.weeks or 0

    -- What is up every week: observed if there is enough history, seeded
    -- if not. Observation wins the moment it can answer, so the seed
    -- cannot outlive the season it was written for.
    -- Furniture: up every week AND never in a different slot. Observed
    -- if there is enough history, seeded if not -- observation wins the
    -- moment it can answer, so a seed cannot outlive its season.
    local alwaysUp = {}
    if weeks >= 2 then
        for _, af in ipairs(list) do
            local e = rec.seen[af.id]
            if type(e) == "table" and e.n >= weeks and e.i ~= -1 then
                alwaysUp[af.id] = true
            end
        end
    else
        local seeded = ns.AFFIX_FURNITURE[season]
        if not seeded then return list, {}, false end
        for _, id in ipairs(seeded) do alwaysUp[id] = true end
    end

    local changing, standing = {}, {}
    for _, af in ipairs(list) do
        if alwaysUp[af.id] then
            standing[#standing + 1] = af
        else
            changing[#changing + 1] = af
        end
    end

    -- A week where nothing reads as changing cannot be right for a live
    -- season, so show the lot rather than an empty card.
    if #changing == 0 then return list, {}, false end
    return changing, standing, true
end

------------------------------------------------------------
-- This week's runs
------------------------------------------------------------
-- Deliberately the same source the Great Vault reads, so the count on
-- the page and the chips in the header agree by construction instead of
-- being two estimates that drift apart on a Tuesday.
--
-- `completed` is the vault's test, not the timer's -- a depleted key
-- still fills a slot. Anything here that calls a run "timed" would be
-- answering a question this API was not asked.
--
------------------------------------------------------------
-- The run journal
--
-- C_MythicPlus.GetRunHistory answers ONE thing about a run: whether it
-- completed. Not whether it beat the timer, not by how much, not what
-- the key upgraded to, not what it paid in score. That is why the week
-- list could only say "counts" and "left" -- it was reporting the only
-- fact it had.
--
-- Everything richer exists for exactly one moment. C_ChallengeMode.
-- GetCompletionInfo is populated when a run ends and says nothing
-- before or after, so the only way to have it later is to write it down
-- when it happens. This does that, into saved variables, and the week
-- list reads back from it.
--
-- Return order verified against RaiderIO/core.lua, which is maintained
-- against a live client:
--   mapID, level, time, onTime, keystoneUpgradeLevels, practiceRun,
--   oldDungeonScore, newDungeonScore, ...
--
-- The consequence worth stating: a run finished before this existed --
-- or on a character or install without it -- has no entry, and never
-- will. The list falls back to "completed" for those rather than
-- inventing a time, which is why rows can differ in what they show.
------------------------------------------------------------

--- The start of the current M+ week, as an epoch second.
---
--- Derived from the reset the client is counting down to rather than
--- from a weekday, because reset day and hour differ by region and a
--- hardcoded Tuesday is wrong for half the world.
local function WeekStart()
    local now = (type(time) == "function" and time()) or 0
    if now == 0 then return 0 end
    local secs = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
        and C_DateAndTime.GetSecondsUntilWeeklyReset()
    if not secs or secs <= 0 then return 0 end
    return (now + secs) - (7 * 24 * 60 * 60)
end

function ns:GetRunJournal()
    YippYappHelperDB = YippYappHelperDB or {}
    local j = YippYappHelperDB.runJournal
    if type(j) ~= "table" then j = {}; YippYappHelperDB.runJournal = j end
    return j
end

--- Drop entries from before this week's reset.
---
--- The journal is a record of THIS week, so last week's runs are not
--- history worth keeping -- they would show up in a list headed "This
--- Week" the moment the reset passed.
function ns:PruneRunJournal()
    local j = self:GetRunJournal()
    local start = WeekStart()
    if start <= 0 then return j end
    for i = #j, 1, -1 do
        if (j[i].at or 0) < start then table.remove(j, i) end
    end
    return j
end

--- Write down the run that just finished.
function ns:RecordCompletedRun()
    if not (C_ChallengeMode and C_ChallengeMode.GetCompletionInfo) then return end

    local mapID, level, ms, onTime, chests, practice, oldScore, newScore =
        C_ChallengeMode.GetCompletionInfo()
    -- A practice run is not a real one and must not reach the vault list
    -- or the score arithmetic.
    if not mapID or practice then return end

    local deaths
    if C_ChallengeMode.GetDeathCount then
        deaths = C_ChallengeMode.GetDeathCount()
    end

    -- The par time, so "how far over" can be worked out later without
    -- needing the dungeon's own data at read time.
    local limit = select(3, C_ChallengeMode.GetMapUIInfo(mapID))

    local j = self:PruneRunJournal()
    j[#j + 1] = {
        mapID  = mapID,
        level  = level or 0,
        ms     = ms or 0,
        onTime = onTime and true or false,
        chests = chests or 0,
        gain   = (newScore and oldScore) and (newScore - oldScore) or nil,
        deaths = deaths,
        limit  = limit,
        at     = (type(time) == "function" and time()) or 0,
    }
end

--- The journal entry for a run, or nil.
---
--- Matched on map AND level, and each entry is consumed once, so two
--- runs of the same key this week get their own rows rather than both
--- showing the first one's time.
local function TakeJournalEntry(pool, mapID, level)
    for i, e in ipairs(pool) do
        if e.mapID == mapID and e.level == level then
            table.remove(pool, i)
            return e
        end
    end
    return nil
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    f:SetScript("OnEvent", function()
        -- Straight away, not on a timer. GetCompletionInfo is populated
        -- for this event and the popup's own three-second delay is about
        -- letting the end-of-run banner clear, which has nothing to do
        -- with reading the numbers.
        local ok, err = pcall(ns.RecordCompletedRun, ns)
        if not ok and ns.Debug then ns:Debug("run journal: " .. tostring(err)) end
    end)
end

-- Returns highest key first: { mapID, name, level, completed }
function ns:GetWeeklyRuns()
    local history = C_MythicPlus.GetRunHistory(false, true)
    if not history then return {} end

    -- A working copy: entries are consumed as they are matched, so two
    -- runs of the same key do not both take the first one's detail.
    local pool = {}
    for _, e in ipairs(self:PruneRunJournal()) do pool[#pool + 1] = e end

    local out = {}
    for _, run in ipairs(history) do
        local mapID = run.mapChallengeModeID
        if mapID then
            local name = C_ChallengeMode.GetMapUIInfo(mapID)
            local level = run.level or 0
            local entry = {
                mapID     = mapID,
                name      = name or "Unknown",
                level     = level,
                completed = run.completed and true or false,
            }
            -- `detail` is absent for anything finished before the
            -- journal existed, and callers must handle that rather than
            -- assume every run has a time.
            entry.detail = TakeJournalEntry(pool, mapID, level)
            out[#out + 1] = entry
        end
    end

    -- The vault fills from the top of this list, so the order on screen
    -- is the order that decides the reward.
    table.sort(out, function(a, b) return a.level > b.level end)
    return out
end

------------------------------------------------------------
-- Great Vault M+ progress
-- Returns: { slots = { {threshold, progress, level}, ... }, totalRuns = n }
-- Each slot: threshold = runs needed, progress = runs done, level = lowest
-- key level that counts for this slot's reward.
------------------------------------------------------------
function ns:GetVaultProgress()
    local activities = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.Activities)
    if not activities or #activities == 0 then
        -- Fallback: try MythicPlus type
        activities = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.MythicPlus)
    end
    if not activities then return nil end

    -- Sort by threshold ascending (slot 1 = easiest)
    table.sort(activities, function(a, b) return a.threshold < b.threshold end)

    local slots = {}
    for _, act in ipairs(activities) do
        table.insert(slots, {
            threshold = act.threshold,
            progress = act.progress,
            level = act.level,
            rewards = act.rewards,
        })
    end

    return { slots = slots }
end

------------------------------------------------------------
-- Dungeon teleport
-- Uses the Challenger's Path teleport spells per dungeon.
-- Maps challengeModeMapID -> teleport spellID.
-- These must be updated each season when the dungeon pool rotates.
------------------------------------------------------------
-- Teleport spells keyed by dungeon name (matched against C_ChallengeMode names)
-- Sourced from Porter addon Data.lua — covers all known Hero's Path teleports
-- Values are a spell ID, or a list of candidates in preference order.
--
-- Several dungeons carry more than one teleport spell: legacy dungeons
-- reissue a new one when they rejoin a season (Kings' Rest exists as both
-- the BfA 272261 and the Midnight S2 1289778), so which one a given
-- character knows depends on when they earned it. Candidates are resolved
-- against IsSpellKnown at query time.
local DUNGEON_TELEPORT_BY_NAME = {
    -- Midnight Season 2
    ["Altar of Fangs"]           = 1289772,
    ["Den of Nalorakk"]          = 1289773,
    ["The Blinding Vale"]        = 1289776,
    ["Murder Row"]               = { 1289775, 1248186, 1253942 },
    ["Voidscar Arena"]           = { 1289777, 1286119 },
    ["Kings' Rest"]              = { 1289778, 272261 },
    ["Temple of Sethraliss"]     = { 1289782, 272267 },
    ["Ruby Life Pools"]          = { 1289780, 393256 },
    -- Midnight Season 1
    ["Magisters' Terrace"]       = 1254572,
    ["Windrunner Spire"]         = 1254400,
    ["Nexus-Point Xenas"]        = 1254563,
    ["Maisara Caverns"]          = 1254559,
    ["Pit of Saron"]             = 1254555,
    ["Seat of the Triumvirate"]  = 1254551,
    ["Skyreach"]                 = 159898,
    ["Algeth'ar Academy"]        = 393273,
    -- TWW Season 3
    ["Operation: Floodgate"]     = 1216786,
    ["Eco-Dome Al'dani"]         = 1237215,
    ["Ara-Kara, City of Echoes"] = 445417,
    ["The Dawnbreaker"]          = 445414,
    ["Priory of the Sacred Flame"] = 445444,
    ["Tazavesh: Streets of Wonder"] = 367416,
    ["Tazavesh: So'leah's Gambit"] = 367416,
    ["Halls of Atonement"]       = 354465,
    -- TWW legacy (S1/S2)
    ["City of Threads"]          = 445416,
    ["The Stonevault"]           = 445269,
    ["Cinderbrew Meadery"]       = 445440,
    ["Darkflame Cleft"]          = 445441,
    ["The Rookery"]              = 445443,
    -- Dragonflight
    ["Brackenhide Hollow"]       = 393267,
    ["Halls of Infusion"]        = 393283,
    ["Neltharus"]                = 393276,
    ["Uldaman: Legacy of Tyr"]   = 393222,
    ["Dawn of the Infinite"]     = 424197,
    ["The Azure Vault"]          = 393279,
    ["The Nokhud Offensive"]     = 393262,
    -- Shadowlands
    ["The Necrotic Wake"]        = 354462,
    ["Plaguefall"]               = 354463,
    ["Mists of Tirna Scithe"]    = 354464,
    ["Halls of Atonement"]       = 354465,
    ["Spires of Ascension"]      = 354466,
    ["Theater of Pain"]          = 354467,
    ["De Other Side"]            = 354468,
    ["Sanguine Depths"]          = 354469,
    -- BfA
    ["Freehold"]                 = 410071,
    ["The Underrot"]             = 410074,
    ["Waycrest Manor"]           = 424167,
    ["Atal'Dazar"]               = 424187,
    ["Operation: Mechagon"]      = 373274,
    ["Siege of Boralus"]         = 445418,
    ["The MOTHERLODE!!"]         = 272268,
    -- Legion
    ["Neltharion's Lair"]        = 410078,
    ["Black Rook Hold"]          = 424153,
    ["Darkheart Thicket"]        = 424163,
    ["Halls of Valor"]           = 393764,
    ["Court of Stars"]           = 393766,
    ["Return to Karazhan"]       = 373262,
    -- WoD
    ["The Everbloom"]            = 159901,
    ["Grimrail Depot"]           = 159900,
    ["Iron Docks"]               = 159896,
    ["Auchindoun"]               = 159897,
    ["Bloodmaul Slag Mines"]     = 159895,
    ["Shadowmoon Burial Grounds"] = 159899,
    ["Upper Blackrock Spire"]    = 159902,
    -- MoP
    ["Temple of the Jade Serpent"] = 131204,
    ["Stormstout Brewery"]       = 131205,
    ["Shado-Pan Monastery"]      = 131206,
    ["Gate of the Setting Sun"]  = 131225,
    ["Mogu'shan Palace"]         = 131222,
    ["Siege of Niuzao Temple"]   = 131228,
    ["Scholomance"]              = 131232,
    ["Scarlet Halls"]            = 131231,
    ["Scarlet Monastery"]        = 131229,
    -- Cata
    ["The Vortex Pinnacle"]      = 410080,
    ["Throne of the Tides"]      = 424142,
    ["Grim Batol"]               = 445424,
}

-- Build mapID -> spellID cache on first use
local teleportCache = nil

local function GetTeleportCache()
    if teleportCache then return teleportCache end

    local maps = C_ChallengeMode.GetMapTable()
    -- Nothing is memoised until there is something to memoise.
    --
    -- GetMapTable is empty for the first moments after a reload, until
    -- the client answers RequestMapInfo. Caching that emptiness left
    -- every tile on the page with canTele = false, so no macrotext was
    -- ever set on any of them and every teleport click did nothing at
    -- all -- silently, and for the rest of the session, with no way back
    -- short of another reload. Intermittent by construction: whether it
    -- bit you depended only on which side of that reply the page
    -- happened to be drawn on. Returning a throwaway empty table means
    -- the next caller simply tries again.
    if not maps or #maps == 0 then
        if C_MythicPlus and C_MythicPlus.RequestMapInfo then
            C_MythicPlus.RequestMapInfo()
        end
        return {}
    end

    local cache = {}
    for _, mapID in ipairs(maps) do
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        if name and DUNGEON_TELEPORT_BY_NAME[name] then
            cache[mapID] = DUNGEON_TELEPORT_BY_NAME[name]
        end
    end
    teleportCache = cache
    return teleportCache
end

-- Resolve a table entry (spell ID or candidate list) to the ID this
-- character actually has. Falls back to the first candidate so the UI can
-- still show a greyed-out icon for a teleport that is not unlocked yet.
local function ResolveTeleport(entry)
    if type(entry) ~= "table" then return entry end
    for _, spellID in ipairs(entry) do
        if IsSpellKnown(spellID) then return spellID, true end
    end
    return entry[1], false
end

-- The reverse of DUNGEON_TELEPORT_BY_NAME: which dungeon a teleport
-- spell belongs to.
--
-- Covers every candidate ID rather than only the one this character
-- knows. The caller is identifying a cast that has already started, and
-- by then the client has said which spell it is -- resolving against
-- IsSpellKnown there would be answering a question nobody asked.
local teleportBySpell = nil

local function GetTeleportBySpell()
    if teleportBySpell then return teleportBySpell end
    teleportBySpell = {}
    for name, entry in pairs(DUNGEON_TELEPORT_BY_NAME) do
        if type(entry) == "table" then
            for _, spellID in ipairs(entry) do teleportBySpell[spellID] = name end
        else
            teleportBySpell[entry] = name
        end
    end
    return teleportBySpell
end

--- The dungeon a teleport spell travels to, or nil if it is not one.
function ns:GetDungeonForTeleportSpell(spellID)
    if not spellID then return nil end
    return GetTeleportBySpell()[spellID]
end

function ns:GetDungeonTeleportSpell(mapID)
    return (ResolveTeleport(GetTeleportCache()[mapID]))
end

function ns:CanTeleportToDungeon(mapID)
    local entry = GetTeleportCache()[mapID]
    if not entry then return false end
    local spellID, known = ResolveTeleport(entry)
    if known ~= nil and type(entry) == "table" then return known end
    return spellID and IsSpellKnown(spellID) or false
end

function ns:TeleportToDungeon(mapID)
    local entry = GetTeleportCache()[mapID]
    if not entry then return end
    if not ns:CanTeleportToDungeon(mapID) then
        print("|cff00ff00YippYapp|r: Teleport not unlocked for this dungeon")
        return
    end
    -- CastSpellByID is protected; use the Teleports page instead
    print("|cff00ff00YippYapp|r: Use the |cff88ccffTeleports|r page to teleport (secure button required)")
    -- Only redirects a window that is already open -- this is a nudge
    -- after a refused teleport, not a reason to throw a window at
    -- somebody. Shell first, then the old frame, same as everywhere else.
    if ns.Shell and ns.Shell.IsOpen and ns.Shell:IsOpen() then
        ns.Shell:Open("teleports")
    elseif ns.AppFrame and ns.AppFrame:IsShown() and ns.ShowAppPage then
        ns:ShowAppPage("teleports")
    end
end

------------------------------------------------------------
-- Keystone sharing via addon comms
------------------------------------------------------------
local partyKeystones = {}  -- [playerName] = { mapID, level, name } (from PARTY/RAID)
local guildKeystones = {}  -- [playerName] = { mapID, level, name } (from GUILD)

function ns:GetPartyKeystones()
    return partyKeystones
end

-- Stale guild entries (player no longer has a key / logged out / left
-- guild without a broadcast) are aged out lazily on read. 1 week TTL is
-- long enough to tolerate weekly reset cadence without flushing reliable
-- data, short enough that dead entries don't pile up across expansions.
local GUILD_TTL_SECONDS = 60 * 60 * 24 * 7

function ns:GetGuildKeystones()
    local now = GetTime()
    for name, entry in pairs(guildKeystones) do
        if entry.ts and (now - entry.ts) > GUILD_TTL_SECONDS then
            guildKeystones[name] = nil
        end
    end
    return guildKeystones
end

local function SendKS(channel)
    local ks = ns:GetOwnKeystone()
    if not ks then return end
    local msg = string.format("KS:%d:%d", ks.mapID, ks.level)
    C_ChatInfo.SendAddonMessage(COMM_PREFIX, msg, channel)
end

-- Cooldown to prevent timer pile-up when many guildies broadcast KSQ at
-- once (e.g. after a Tuesday reset). Without this, each KSQ schedules an
-- independent C_Timer that each fire a redundant guild-wide KS reply.
local lastGuildKSReplyAt = 0
local GUILD_KS_REPLY_COOLDOWN = 15

function ns:BroadcastKeystone()
    -- Always use PARTY — keystones only concern the 5-man group.
    -- Sending to RAID inside a raid is noisy and irrelevant.
    if IsInGroup() then SendKS("PARTY") end
    if IsInGuild() then SendKS("GUILD") end
end

-- Ask the guild to re-broadcast their keys
function ns:RequestGuildKeystones()
    if not IsInGuild() then return end
    C_ChatInfo.SendAddonMessage(COMM_PREFIX, "KSQ:", "GUILD")
    -- Also send our own right away so the requester sees us
    SendKS("GUILD")
end

--- Ask the party to re-broadcast their keys.
---
--- The guild had this and the party did not, which left the party with
--- no way to recover from a message it never received: everything was
--- push, on a one-second timer after a roster change, and anything that
--- missed that window stayed missing until the group changed again. Four
--- people cannot flood anything, so there is no cooldown or jitter here.
function ns:RequestPartyKeystones()
    if not IsInGroup() then return end
    C_ChatInfo.SendAddonMessage(COMM_PREFIX, "KSQ:", "PARTY")
    SendKS("PARTY")
end

local commFrame = CreateFrame("Frame")
commFrame:RegisterEvent("CHAT_MSG_ADDON")
commFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
commFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
commFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
commFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
commFrame:RegisterEvent("PLAYER_GUILD_UPDATE")

commFrame:SetScript("OnEvent", function(self, event, prefix, msg, channel, sender)
    if event == "CHAT_MSG_ADDON" and prefix == COMM_PREFIX then
        local shortName = Ambiguate(sender, "short")
        local cmd, mapIDStr, levelStr = strsplit(":", msg)
        if cmd == "KS" then
            local mapID = tonumber(mapIDStr)
            local level = tonumber(levelStr)
            if mapID and level then
                local name = C_ChallengeMode.GetMapUIInfo(mapID)
                local entry = { mapID = mapID, level = level, name = name or "Unknown", ts = GetTime() }
                if channel == "GUILD" then
                    -- Keyed by sender, so a large or hostile guild can
                    -- grow this without bound. Cap it: past a few hundred
                    -- keys the list is unreadable anyway, and the table
                    -- is only wiped on a weekly reset.
                    local count = 0
                    for _ in pairs(guildKeystones) do count = count + 1 end
                    if count < 300 or guildKeystones[shortName] then
                        guildKeystones[shortName] = entry
                    end
                elseif shortName ~= UnitName("player") then
                    -- Ignore our own broadcast: PARTY addon messages echo back to the sender.
                    partyKeystones[shortName] = entry
                end
                if ns.RefreshMythicPlus then ns:RefreshMythicPlus() end
                -- The after-key summary is usually the thing waiting on
                -- this, and it is already on screen by the time replies
                -- land -- so it has to be told, not just the M+ page.
                if ns.RefreshCompletionPopup then ns.RefreshCompletionPopup() end
            end
        elseif cmd == "KSQ" and channel == "GUILD" then
            -- Someone asked guild for keys; send ours back (with a small jitter
            -- so 500 guildies don't all reply in the same frame). Enforce a
            -- short cooldown so bursts of KSQ don't stack independent timers.
            local now = GetTime()
            if now - lastGuildKSReplyAt >= GUILD_KS_REPLY_COOLDOWN then
                lastGuildKSReplyAt = now
                C_Timer.After(math.random() * 2, function() SendKS("GUILD") end)
            end
        elseif cmd == "KSQ" and channel == "PARTY" then
            -- Straight back, no jitter and no cooldown: the most four
            -- people can produce is four messages, and the thing waiting
            -- on the answer is a window that is already on screen.
            SendKS("PARTY")
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        local inGroup = {}
        local playerName = UnitName("player")
        inGroup[playerName] = true
        -- Only retain party slots 1-4; raid members aren't relevant to M+.
        for i = 1, 4 do
            local unit = "party" .. i
            local name = UnitName(unit)
            if name then inGroup[name] = true end
        end
        for name in pairs(partyKeystones) do
            if not inGroup[name] then partyKeystones[name] = nil end
        end
        C_Timer.After(1, function() ns:BroadcastKeystone() end)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "CHALLENGE_MODE_MAPS_UPDATE" then
        -- The map table just changed, so anything derived from it is
        -- stale. This is also the event that arrives when the list
        -- finally populates after a reload, and the season rotating is
        -- the same fact arriving later.
        teleportCache = nil
        C_Timer.After(2, function() ns:BroadcastKeystone() end)
        -- Pull guild keys shortly after login
        if IsInGuild() then
            C_Timer.After(4, function() ns:RequestGuildKeystones() end)
        end
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        -- Finishing a key replaces everybody's keystone at once, which
        -- makes this the moment every cached entry in the group goes
        -- wrong -- and it is also the moment the after-key summary opens
        -- to show them. Nothing re-broadcast here before, so that window
        -- listed the keys people were holding before the run.
        --
        -- Twice, because the new key is not granted the instant the run
        -- ends: the first pass usually still reads the old one, and the
        -- second catches up. Sending a key twice costs one addon message.
        C_Timer.After(3, function()
            ns:BroadcastKeystone()
            if ns.RequestPartyKeystones then ns:RequestPartyKeystones() end
        end)
        C_Timer.After(8, function() ns:BroadcastKeystone() end)
    elseif event == "PLAYER_GUILD_UPDATE" then
        wipe(guildKeystones)
        if IsInGuild() then
            C_Timer.After(2, function() ns:RequestGuildKeystones() end)
        end
    end
end)
