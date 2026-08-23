local _, ns = ...

------------------------------------------------------------------------
-- EJ API Compatibility Layer
-- Blizzard moves functions between global EJ_* and C_EncounterJournal.*
------------------------------------------------------------------------
local CEJ = C_EncounterJournal or {}

local function EJ_Call(cejName, globalName, ...)
    if CEJ[cejName] then
        return CEJ[cejName](...)
    elseif _G[globalName] then
        return _G[globalName](...)
    end
    return nil
end

local function EJ_GetCurrentTierCompat()
    return EJ_Call("GetCurrentTier", "EJ_GetCurrentTier")
end
local function EJ_SelectTierCompat(tier)
    return EJ_Call("SelectTier", "EJ_SelectTier", tier)
end
local function EJ_GetNumTiersCompat()
    return EJ_Call("GetNumTiers", "EJ_GetNumTiers") or 0
end
local function EJ_GetInstanceByIndexCompat(index, isRaid)
    return EJ_Call("GetInstanceByIndex", "EJ_GetInstanceByIndex", index, isRaid)
end
local function EJ_SelectInstanceCompat(instanceID)
    return EJ_Call("SelectInstance", "EJ_SelectInstance", instanceID)
end
local function EJ_GetEncounterInfoByIndexCompat(index)
    return EJ_Call("GetEncounterInfoByIndex", "EJ_GetEncounterInfoByIndex", index)
end
local function EJ_SelectEncounterCompat(encounterID)
    return EJ_Call("SelectEncounter", "EJ_SelectEncounter", encounterID)
end
local function EJ_SetDifficultyCompat(diffID)
    return EJ_Call("SetDifficulty", "EJ_SetDifficulty", diffID)
end
local function EJ_GetDifficultyCompat()
    return EJ_Call("GetDifficulty", "EJ_GetDifficulty")
end
local function EJ_SetLootFilterCompat(classID, specID)
    return EJ_Call("SetLootFilter", "EJ_SetLootFilter", classID, specID)
end
local function EJ_SetSlotFilterCompat(slotFilter)
    return EJ_Call("SetSlotFilter", "EJ_SetSlotFilter", slotFilter)
end
local function EJ_GetNumLootCompat()
    return EJ_Call("GetNumLoot", "EJ_GetNumLoot") or 0
end
local function EJ_GetSlotFilterCompat()
    return EJ_Call("GetSlotFilter", "EJ_GetSlotFilter")
end
local function EJ_GetLootFilterCompat()
    if CEJ.GetLootFilter then
        return CEJ.GetLootFilter()
    elseif _G.EJ_GetLootFilter then
        return _G.EJ_GetLootFilter()
    end
    return nil, nil
end

local function EJ_GetLootInfoByIndexCompat(index)
    if CEJ.GetLootInfoByIndex then
        return CEJ.GetLootInfoByIndex(index)
    end
    if _G.EJ_GetLootInfoByIndex then
        local name, icon, slot, armorType, itemID, itemLink = _G.EJ_GetLootInfoByIndex(index)
        if name then
            return { name = name, icon = icon, itemID = itemID, link = itemLink }
        end
    end
    return nil
end

------------------------------------------------------------------------
-- Item Stats Compatibility
------------------------------------------------------------------------
local function GetItemStatsCompat(itemLink)
    if C_Item and C_Item.GetItemStats then
        return C_Item.GetItemStats(itemLink)
    elseif _G.GetItemStats then
        local stats = {}
        _G.GetItemStats(itemLink, stats)
        if next(stats) then return stats end
        return nil
    end
    return nil
end

------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------
local EISFT = Enum.ItemSlotFilterType

ns.LOOT_DIFF_COLORS = {
    GREEN  = { r = 0.12, g = 0.75, b = 0.12 },
    BLUE   = { r = 0.00, g = 0.44, b = 0.87 },
    PURPLE = { r = 0.64, g = 0.21, b = 0.93 },
}

ns.LOOT_DIFFICULTIES = {
    DUNGEON = {
        { id = 1,  name = "N",   fullName = "Normal",     color = "GREEN"  },
        { id = 2,  name = "H",   fullName = "Heroic",     color = "BLUE"   },
        { id = 23, name = "M",   fullName = "Mythic",     color = "PURPLE" },
    },
    RAID = {
        { id = 17, name = "LFR", fullName = "LFR",        color = "GREEN",  colOffset = 1 },
        { id = 14, name = "N",   fullName = "Normal",     color = "BLUE",   colOffset = 2 },
        { id = 15, name = "H",   fullName = "Heroic",     color = "PURPLE", colOffset = 3 },
        { id = 16, name = "M",   fullName = "Mythic",     color = "PURPLE", colOffset = 4 },
    },
    WORLD_BOSS = {
        { id = 0,  name = "WB",  fullName = "World Boss", color = "PURPLE", colOffset = 3 },
    },
}

ns.LOOT_SLOT_FILTERS = {
    { name = "Head",      filter = EISFT.Head      },
    { name = "Neck",      filter = EISFT.Neck      },
    { name = "Shoulder",  filter = EISFT.Shoulder  },
    { name = "Back",      filter = EISFT.Cloak     },
    { name = "Chest",     filter = EISFT.Chest     },
    { name = "Wrist",     filter = EISFT.Wrist     },
    { name = "Hands",     filter = EISFT.Hand      },
    { name = "Waist",     filter = EISFT.Waist     },
    { name = "Legs",      filter = EISFT.Legs      },
    { name = "Feet",      filter = EISFT.Feet      },
    { name = "Finger",    filter = EISFT.Finger    },
    { name = "Trinket",   filter = EISFT.Trinket   },
    { name = "Main Hand", filter = EISFT.MainHand  },
    { name = "Off Hand",  filter = EISFT.OffHand   },
}

ns.LOOT_SECONDARY_STATS = {
    { key = "ITEM_MOD_CRIT_RATING_SHORT",   short = "Crit",    name = "Critical Strike" },
    { key = "ITEM_MOD_HASTE_RATING_SHORT",  short = "Haste",   name = "Haste" },
    { key = "ITEM_MOD_MASTERY_RATING_SHORT", short = "Mastery", name = "Mastery" },
    { key = "ITEM_MOD_VERSATILITY",          short = "Vers",    name = "Versatility" },
}

------------------------------------------------------------------------
-- Caches
------------------------------------------------------------------------
local lootBrowserCache = {}
local instanceCache = nil
ns.isLootScanning = false

------------------------------------------------------------------------
-- Navigation State
------------------------------------------------------------------------
ns.lootBrowserState = {
    selectedClassID   = nil,
    selectedClassFile = nil,
    selectedSpecIndex = nil,  -- 1..N within selectedClassID
    selectedSpecID    = nil,
    selectedSlot      = EISFT.Head,
    selectedSlotName  = "Head",
    selectedStats     = {},
    selectedView      = "dungeon",   -- "dungeon" or "raid"
    isFavoritesMode   = false,
    isAllSlots        = false,
    -- Retired raids are folded away until asked for. Session state, not
    -- saved: "collapsed" is the right thing to open on every time.
    showPreviousTiers = false,
}

------------------------------------------------------------------------
-- EJ Interference Suppression (ref-counted)
--
-- Save/restore the user's EJ filter state across our bulk EJ_Select*
-- calls so we don't disrupt an open Encounter Journal. We deliberately
-- DO NOT touch EncounterJournal:SetScript or its event registrations:
-- writing to a Blizzard frame from an addon propagates taint to that
-- frame, which then poisons MoneyFrame_Update on item-sell-price
-- tooltips ("attempt to perform arithmetic on a secret number value").
-- Our own cache invalidation is already gated by ns.isLootScanning, so
-- letting EJ's native OnEvent run during a scan is harmless.
------------------------------------------------------------------------
local ejSuppressCount = 0
local ejSavedDifficulty = nil
local ejSavedSlotFilter = nil
local ejSavedLootClassID = nil
local ejSavedLootSpecID = nil

local function SuppressEJ()
    ejSuppressCount = ejSuppressCount + 1
    if ejSuppressCount > 1 then return end

    ejSavedDifficulty = EJ_GetDifficultyCompat()
    ejSavedSlotFilter = EJ_GetSlotFilterCompat()
    ejSavedLootClassID, ejSavedLootSpecID = EJ_GetLootFilterCompat()
end

local function UnsuppressEJ()
    ejSuppressCount = ejSuppressCount - 1
    if ejSuppressCount > 0 then return end
    ejSuppressCount = 0

    if ejSavedDifficulty then
        EJ_SetDifficultyCompat(ejSavedDifficulty)
        ejSavedDifficulty = nil
    end
    if ejSavedSlotFilter then
        EJ_SetSlotFilterCompat(ejSavedSlotFilter)
        ejSavedSlotFilter = nil
    end
    if ejSavedLootClassID and ejSavedLootSpecID then
        EJ_SetLootFilterCompat(ejSavedLootClassID, ejSavedLootSpecID)
        ejSavedLootClassID = nil
        ejSavedLootSpecID = nil
    end

end

------------------------------------------------------------------------
-- Seasonal Dungeon Allowlist
--
-- This used to be a hardcoded table of Season 1 Encounter Journal
-- instance IDs, which meant the dungeon view went blank the moment the
-- season rolled over. It now resolves at runtime instead:
--
--   1. C_ChallengeMode.GetMapTable() — the live Mythic+ pool, correct in
--      any locale and self-updating every season.
--   2. A hardcoded English name list, unioned in as a safety net.
--
-- The union matters during the gap between patch day and season start
-- (11-18 Aug 2026): the API still reports the old pool while the new
-- dungeons are already open at Heroic, and showing both is correct.
------------------------------------------------------------------------
local SEASONAL_DUNGEON_NAMES = {
    -- Midnight Season 2
    "Altar of Fangs",
    "Murder Row",
    "Den of Nalorakk",
    "The Blinding Vale",
    "Voidscar Arena",
    "Kings' Rest",
    "Ruby Life Pools",
    "Temple of Sethraliss",
}

local function GetSeasonalDungeonNames()
    local names = {}

    if C_ChallengeMode and C_ChallengeMode.GetMapTable then
        local ok, maps = pcall(C_ChallengeMode.GetMapTable)
        if ok and type(maps) == "table" then
            for _, mapID in ipairs(maps) do
                local mapName = C_ChallengeMode.GetMapUIInfo(mapID)
                if mapName then names[mapName] = true end
            end
        end
    end

    for _, n in ipairs(SEASONAL_DUNGEON_NAMES) do
        names[n] = true
    end
    return names
end

-- Optional hand-picked row backgrounds. Anything not listed falls back
-- to the instance's own Encounter Journal art, so new dungeons look
-- right without needing a texture ID looked up by hand.
local DUNGEON_BG_TEXTURES = {
    [476]  = 1041999,  -- Skyreach
    [945]  = 1718213,  -- Seat of the Triumvirate
    [1201] = 4742929,  -- Algeth'ar Academy
    [278]  = 608210,   -- Pit of Saron
    [1299] = 7464937,  -- Windrunner Spire
    [1300] = 7467174,  -- Magisters' Terrace
    [1316] = 7570501,  -- Nexus-Point Xenas
    [1315] = 7478529,  -- Maisara Caverns
}

local function InstanceBackground(instanceID)
    if DUNGEON_BG_TEXTURES[instanceID] then
        return DUNGEON_BG_TEXTURES[instanceID]
    end
    -- EJ_GetInstanceInfo: name, description, bgImage, buttonImage, ...
    local ok, _, _, bgImage = pcall(EJ_Call, "GetInstanceInfo",
        "EJ_GetInstanceInfo", instanceID)
    if ok and bgImage then return bgImage end
    return nil
end

local WORLD_BOSS_INSTANCE_ID = 1312

------------------------------------------------------------------------
-- Instance + Boss Discovery (cached per session)
------------------------------------------------------------------------
------------------------------------------------------------------------
-- Yielding, because this sweep is too big for one frame.
--
-- The client kills any script that runs too long without returning, and
-- this is thousands of Encounter Journal calls: every tier of every
-- expansion while the instance cache is cold, then every boss of every
-- instance at every difficulty. It used to run as one synchronous pass
-- and finally grew past the limit -- "script ran too long", reported
-- against whichever EJ call happened to be executing when the watchdog
-- fired, which is why the error pointed at a one-line compatibility
-- shim that has nothing wrong with it.
--
-- So the work yields. `ScanYield` gives the frame back once the slice
-- has had its budget, and the runner below resumes next frame.
------------------------------------------------------------------------
-- One frame's worth at 60fps. This is a load somebody is watching a
-- spinner for, not background work, so the useful trade is fewer frames
-- rather than a smoother framerate during them: at 8ms it gave back half
-- of every frame and took twice as long to show anything.
local SCAN_BUDGET_FOREGROUND_MS = 16
------------------------------------------------------------------------
-- ...and the exact opposite trade for the login prewarm.
--
-- The reasoning above is sound and was applied to both kinds of scan,
-- which was the bug: the prewarm is precisely the case where NOBODY is
-- watching a spinner. Taking a full frame's budget every frame for a
-- sweep of every tier of every expansion caps the client at roughly
-- 30fps for as long as it runs -- seconds, a few seconds after a
-- loading screen, for a panel the player has not opened and may never
-- open this session.
--
-- 4ms costs the prewarm about four times the wall clock and nobody can
-- tell, because nothing is waiting on it. If a real request turns up
-- mid-sweep the background pass yields the journal to it anyway, and the
-- foreground scan it becomes uses the budget above.
------------------------------------------------------------------------
local SCAN_BUDGET_BACKGROUND_MS = 4
local scanBudgetMs = SCAN_BUDGET_FOREGROUND_MS
local sliceStartedAt = 0

--- Hands the frame back if this slice has used its budget.
---
--- Safe to call from anywhere: the cache builder is also reached
--- synchronously from the journal-link index, and yielding outside a
--- coroutine is an error rather than a no-op.
---
--- Asked via coroutine.running() rather than coroutine.isyieldable(),
--- which does not exist here: isyieldable arrived in Lua 5.2 and the
--- client runs 5.1, so calling it is "attempt to call a nil value" --
--- and Tools/loadcheck.py runs on 5.5, where it exists, so the harness
--- was perfectly happy with code the game could not execute.
---
--- The two-value form covers both: 5.1 returns nil on the main thread,
--- 5.2+ returns the thread plus an is-main flag.
local function ScanYield()
    local co, isMain = coroutine.running()
    if not co or isMain then return end
    if debugprofilestop() - sliceStartedAt >= scanBudgetMs then
        coroutine.yield()
    end
end

--- The work, separated from the error handling around it.
---
--- Split out because pcall cannot wrap it any more: Lua 5.1 cannot yield
--- across a C call and pcall is one, so the first ScanYield inside a
--- pcall'd body dies with "attempt to yield across metamethod/C-call
--- boundary". Anything this calls may still pcall freely -- the rule is
--- only that nothing yields INSIDE one.
------------------------------------------------------------
-- Sanity bounds for the journal walks below.
--
-- Every one of them is a `while true` whose only exit is the Encounter
-- Journal returning nil for the next index. That is the documented
-- shape, and it is also a hang if the journal ever declines to say no --
-- which is a real risk precisely where this runs, a few seconds after a
-- loading screen, on the API that is least settled at that moment.
--
-- Set far above anything the game ships so they never fire in normal
-- use. They are not a limit on content; they are the difference between
-- a bug that stops and a bug that takes the client with it.
------------------------------------------------------------
local MAX_INSTANCES_PER_TIER = 500
local MAX_BOSSES_PER_INSTANCE = 100

local function BuildInstanceCacheWork()
        local instances = { dungeons = {}, raids = {}, worldBosses = {} }

        local currentTier = EJ_GetCurrentTierCompat()
        if not currentTier then return nil end

        local numTiers = EJ_GetNumTiersCompat()
        local seasonalNames = GetSeasonalDungeonNames()
        local foundDungeons = {}
        for tier = numTiers, 1, -1 do
            ScanYield()
            EJ_SelectTierCompat(tier)
            local index = 1
            while index <= MAX_INSTANCES_PER_TIER do
                ScanYield()
                local instanceID, name = EJ_GetInstanceByIndexCompat(index, false)
                if not instanceID then break end
                if name and seasonalNames[name] and not foundDungeons[instanceID] then
                    foundDungeons[instanceID] = true
                    EJ_SelectInstanceCompat(instanceID)
                    local bosses = {}
                    local bi = 1
                    while bi <= MAX_BOSSES_PER_INSTANCE do
                        ScanYield()
                        local bossName, _, bossID = EJ_GetEncounterInfoByIndexCompat(bi)
                        if not bossName then break end
                        table.insert(bosses, { name = bossName, encounterID = bossID })
                        bi = bi + 1
                    end

                    local hasNormal = false
                    if #bosses > 0 then
                        EJ_SelectEncounterCompat(bosses[1].encounterID)
                        EJ_SetDifficultyCompat(1)
                        EJ_SetSlotFilterCompat(EISFT.NoFilter)
                        local numLoot = EJ_GetNumLootCompat()
                        if numLoot and numLoot > 0 then
                            local testInfo = EJ_GetLootInfoByIndexCompat(1)
                            if testInfo and testInfo.link then
                                local _, _, _, itemLevel = GetItemInfo(testInfo.link)
                                if itemLevel then
                                    hasNormal = (itemLevel >= 200)
                                end
                            end
                        end
                    end

                    table.insert(instances.dungeons, {
                        instanceID = instanceID,
                        name = name,
                        bosses = bosses,
                        hasNormal = hasNormal,
                        bgTexture = InstanceBackground(instanceID),
                    })
                    EJ_SelectTierCompat(tier)
                end
                index = index + 1
            end
        end

        EJ_SelectTierCompat(currentTier)

        -- The raid half yielded NOWHERE. The dungeon walk above hands
        -- the frame back at each tier and each instance, and this ran
        -- every raid of every expansion, and every boss inside each one,
        -- in a single unbroken stretch -- so the budget the scanner is
        -- built around simply did not apply to half its work.
        local raidIdx = 1
        while raidIdx <= MAX_INSTANCES_PER_TIER do
            ScanYield()
            local instanceID, name = EJ_GetInstanceByIndexCompat(raidIdx, true)
            if not instanceID then break end

            EJ_SelectInstanceCompat(instanceID)
            local bosses = {}
            local bi = 1
            while bi <= MAX_BOSSES_PER_INSTANCE do
                ScanYield()
                local bossName, _, bossID = EJ_GetEncounterInfoByIndexCompat(bi)
                if not bossName then break end
                table.insert(bosses, { name = bossName, encounterID = bossID })
                bi = bi + 1
            end

            if instanceID == WORLD_BOSS_INSTANCE_ID then
                table.insert(instances.worldBosses, {
                    instanceID = instanceID,
                    name = name,
                    bosses = bosses,
                })
            else
                table.insert(instances.raids, {
                    instanceID = instanceID,
                    name = name,
                    bosses = bosses,
                })
            end
            raidIdx = raidIdx + 1
        end

    return instances
end

------------------------------------------------------------------------
-- The instance list is static until the game patches.
--
-- Which raids and dungeons exist, and which bosses are in them, does not
-- change while anybody is playing -- and yet finding it out costs a walk
-- through every tier of every expansion in the Encounter Journal, once
-- per session, for the life of the addon.
--
-- So it is written down. The stamp is the game's interface version plus
-- our own, because either one changing is a reason to look again: a
-- patch can add an instance, and an addon update can change which
-- dungeons we consider seasonal.
--
-- This does not make the loot itself free -- that is still fetched per
-- boss -- but it removes the discovery walk, which is the part that runs
-- at login whether or not anybody opens the panel.
------------------------------------------------------------------------
local function CacheStamp()
    local ifaceOk, iface = pcall(function() return select(4, GetBuildInfo()) end)
    local addonVer
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local ok, v = pcall(C_AddOns.GetAddOnMetadata, "YippYappHelper", "Version")
        if ok then addonVer = v end
    end
    return ("%s-%s"):format(
        ifaceOk and tostring(iface) or "?",
        tostring(addonVer or "?"))
end

------------------------------------------------------------------------
-- ...and so is the loot hanging off it.
--
-- Which items a boss drops is as fixed as which bosses exist: it changes
-- when the game patches and at no other time. Fetching it costs the bulk
-- of the sweep -- the instance walk finds a few dozen bosses, and then
-- every one of them is asked for its loot at every difficulty -- and it
-- was being paid again on every reload.
--
-- Stored whole, links included. The compact form would be item ids with
-- the rest rebuilt on load, and it was not worth it: a row's name and
-- icon come back asynchronously from the client, so dropping them trades
-- disk for a panel that renders blank until item data arrives. This is
-- larger on disk and identical in behaviour.
--
-- Keyed by spec and slot filter, exactly as in memory, so a player who
-- only ever looks at one filter only ever stores one.
------------------------------------------------------------------------
-- Forward declaration: the check lives next to FinishScan, where the
-- reason for it is, but the load path needs it too -- a bad pass already
-- written to disk has to be refused on the way back in, or the guard
-- only protects players who did not already have one.
local EveryBossIdentical

local function SaveLootRows()
    YippYappHelperDB = YippYappHelperDB or {}
    -- A shallow copy, because the live table gets wiped and the saved one
    -- must not go with it. The entries below the top level are replaced
    -- wholesale rather than edited, so sharing them is safe.
    local copy = {}
    for key, rows in pairs(lootBrowserCache) do copy[key] = rows end
    YippYappHelperDB.lootRows = { stamp = CacheStamp(), data = copy }
end

local lootRowsLoaded = false
local function LoadLootRows()
    if lootRowsLoaded then return end
    lootRowsLoaded = true

    local db = YippYappHelperDB and YippYappHelperDB.lootRows
    if type(db) ~= "table" or db.stamp ~= CacheStamp() then return end
    if type(db.data) ~= "table" then return end

    for key, rows in pairs(db.data) do
        -- Shape-checked, and empties refused. This came off disk, and an
        -- empty list is not a cache -- it is a scan that failed once and
        -- would otherwise be served as fact forever.
        if type(key) == "string" and type(rows) == "table" and #rows > 0
            and not EveryBossIdentical(rows) then
            lootBrowserCache[key] = rows
        end
    end
end

-- Published for Tools/loadcheck.py, which has to seed a saved copy that
-- the addon will actually accept. A test that composed the stamp itself
-- would pass while the real one drifted.
function ns:LootCacheStamp() return CacheStamp() end

local function LoadSavedInstances()
    local db = YippYappHelperDB and YippYappHelperDB.lootInstances
    if type(db) ~= "table" then return nil end
    if db.stamp ~= CacheStamp() then return nil end
    local d = db.data
    -- Shape-checked rather than trusted. This came off disk and a
    -- half-written table would fail much further away, in a render.
    if type(d) ~= "table" or type(d.dungeons) ~= "table"
        or type(d.raids) ~= "table" or type(d.worldBosses) ~= "table" then
        return nil
    end
    if #d.dungeons == 0 and #d.raids == 0 then return nil end
    return d
end

local function SaveInstances(data)
    if type(data) ~= "table" then return end
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.lootInstances = { stamp = CacheStamp(), data = data }
end

local function BuildInstanceCache()
    if instanceCache then return instanceCache end

    -- Written down last time, and nothing has patched since.
    local saved = LoadSavedInstances()
    if saved then
        instanceCache = saved
        return saved
    end

    SuppressEJ()

    -- Guarded only when we cannot yield. On a coroutine, resume already
    -- hands errors back rather than raising them -- which is the whole
    -- job pcall was doing here -- and the runner unsuppresses the
    -- journal on the way out either way.
    local ok, result
    local co, isMain = coroutine.running()
    if co and not isMain then
        ok, result = true, BuildInstanceCacheWork()
    else
        ok, result = pcall(BuildInstanceCacheWork)
    end

    UnsuppressEJ()

    if not ok then
        print("|cff00ff00YippYapp|r |cffff6060Loot Browser:|r Instance cache error: " .. tostring(result))
        return nil
    end

    instanceCache = result
    SaveInstances(result)
    return result
end

function ns:GetInstanceCache()
    if not instanceCache then
        BuildInstanceCache()
    end
    return instanceCache
end

--- Does a journal instance name refer to what our data file calls `want`?
---
--- Equality with a leading-article fallback, not equality alone. The
--- names in ns.PROGRESSION were written from patch notes, and the
--- journal's own string is the one that has to match: "The Tidebound
--- Grotto" against "Tidebound Grotto" is the difference between the
--- Lair sitting under the raid and it vanishing into the fold, with
--- nothing on screen to say which of the two strings was wrong.
--- WeeklyChecklist hedges the same name the same way.
local function NameMatches(instName, want)
    if not (instName and want) then return false end
    if instName == want then return true end
    local function bare(s) return (s:gsub("^[Tt]he%s+", "")) end
    return bare(instName) == bare(want)
end

--- Split the raid list into this season's instances and the retired ones.
---
--- The Encounter Journal hands a tier's raids back in release order, so
--- the raid anyone is actually running arrived LAST: the page opened on
--- two or three finished instances and you scrolled past them to reach
--- the current one.
---
--- Two things are current in 12.1 and ns.PROGRESSION names both: the
--- raid, and the Lair under it. The Lair is one boss and fills the same
--- Great Vault row, so it reads as an appendix to the raid rather than
--- as a peer -- hence a fixed order here rather than the journal's.
---
--- Everything the journal lists after the season's raid is current too:
--- a raid the journal knows and our data file does not is newer than
--- ours, not older, so it belongs at the top. Falls back to "the last
--- one is the current one" when no name matches at all, which is what
--- the journal's own ordering already implies -- without that, a data
--- file gone stale would fold every raid on the page away.
---
--- Retired raids come back newest first: under a collapsed heading the
--- most recent tier is the one someone is most likely still farming.
function ns:SplitRaidsByTier(raids)
    local current, previous = {}, {}
    if not raids or #raids == 0 then return current, previous end

    local prog = ns.PROGRESSION or {}

    -- Built by hand rather than as a literal: a nil in the middle of a
    -- table constructor ends ipairs at the hole, so a season with no
    -- raid named would silently drop the Lair too.
    local ORDER = {}
    if prog.RAID_NAME then table.insert(ORDER, prog.RAID_NAME) end
    if prog.LAIRS and prog.LAIRS.name then table.insert(ORDER, prog.LAIRS.name) end

    local cut = #raids
    if prog.RAID_NAME then
        for i, inst in ipairs(raids) do
            if NameMatches(inst.name, prog.RAID_NAME) then
                cut = i
                break
            end
        end
    end

    -- Keyed on the instance table, not the name: two entries sharing a
    -- name would otherwise both answer to one match and land twice.
    local taken = {}

    -- The named ones first, in the order above, wherever the journal
    -- happened to put them.
    for _, name in ipairs(ORDER) do
        for _, inst in ipairs(raids) do
            if inst.name and NameMatches(inst.name, name) and not taken[inst] then
                taken[inst] = true
                table.insert(current, inst)
            end
        end
    end

    -- Then anything else at or after the cut.
    for i = cut, #raids do
        if not taken[raids[i]] then
            taken[raids[i]] = true
            table.insert(current, raids[i])
        end
    end

    for i = #raids, 1, -1 do
        if not taken[raids[i]] then
            table.insert(previous, raids[i])
        end
    end
    return current, previous
end

------------------------------------------------------------------------
-- Loot Scanning
------------------------------------------------------------------------
------------------------------------------------------------------------
-- Did the journal answer for the boss we asked about?
--
-- Set true when it did not. The journal has one global selection, so
-- between our EJ_SelectEncounter and our read of the loot, anything else
-- driving it -- another addon, or Blizzard's own panels -- can move that
-- selection, and the loot we then read belongs to a different boss.
--
-- That is how nine bosses came to list the same ten items. The shape of
-- the result gives it away when EVERY boss matches, and
-- EveryBossIdentical catches that case, but a selection that moves once
-- part-way through a sweep corrupts some rows and not others -- which
-- looks entirely plausible and would be cached and served as fact.
--
-- This is the exact test rather than the heuristic: every loot row the
-- journal hands back names the encounter it belongs to, so a row that
-- names a different one is proof the selection moved under us.
--
-- One flag rather than plumbing a return value through three layers:
-- only one pass runs at a time, and StartScan clears it.
------------------------------------------------------------------------
local scanTainted = false

local function ScanLootForEncounter(instanceID, encounterID, difficultyID, classID, specID, slotFilter)
    local items = {}
    EJ_SelectInstanceCompat(instanceID)
    EJ_SelectEncounterCompat(encounterID)
    EJ_SetDifficultyCompat(difficultyID)

    if classID and specID then
        EJ_SetLootFilterCompat(classID, specID)
    end
    if slotFilter then
        EJ_SetSlotFilterCompat(slotFilter)
    end


    local index = 1
    while true do
        local info = EJ_GetLootInfoByIndexCompat(index)
        if not info or not info.name then break end
        -- Checked only when the journal says which boss it means. The
        -- field is not guaranteed across client versions, and an absent
        -- one is "cannot verify", not "wrong".
        if info.encounterID and encounterID
            and info.encounterID ~= encounterID then
            scanTainted = true
            -- Nothing from this read is trustworthy: the selection has
            -- already moved, so the rows before this one may be another
            -- boss's too.
            return {}
        end
        -- Skip entries without an itemID. The loot browser shows an icon
        -- + tooltip for every row; without an itemID neither hyperlink
        -- nor SetItemByID resolves, so the entry would render as a
        -- tooltipless icon using whatever texture the pool had last.
        if info.itemID then
            table.insert(items, {
                name     = info.name,
                icon     = info.icon,
                itemID   = info.itemID,
                itemLink = info.link,
                -- The journal flags Very Rare items itself. That is a far
                -- better Myth 9 signal than inferring it from the boss:
                -- Very Rare drops come in at 344 from ANY boss, not just
                -- the last two.
                veryRare = info.displayAsVeryRare or info.displayAsExtremelyRare or false,
                seasonID = info.displaySeasonID,
            })
        end
        index = index + 1
    end
    return items
end

local function ScanSourceType(results, instances, sourceType, difficulties, classID, specID, slotFilter)
    for _, inst in ipairs(instances) do
        for _, boss in ipairs(inst.bosses) do
            -- Per boss rather than per instance: one instance is a dozen
            -- encounter scans across four difficulties, which is already
            -- more than a frame's worth on its own.
            ScanYield()
            local entry = {
                sourceName  = inst.name,
                sourceType  = sourceType,
                bossName    = boss.name,
                encounterID = boss.encounterID,
                items       = {},
            }

            if sourceType == "worldboss" then
                for _, tryDiff in ipairs({0, 14, 15}) do
                    local items = ScanLootForEncounter(inst.instanceID, boss.encounterID, tryDiff, classID, specID, slotFilter)
                    if #items > 0 then
                        entry.items[0] = items
                        break
                    end
                end
            else
                for _, diff in ipairs(difficulties) do
                    local skip = false
                    if sourceType == "dungeon" and diff.id == 1 and inst.hasNormal == false then
                        skip = true
                    end
                    if not skip then
                        local items = ScanLootForEncounter(inst.instanceID, boss.encounterID, diff.id, classID, specID, slotFilter)
                        if #items > 0 then
                            entry.items[diff.id] = items
                        end
                    end
                end

            end

            local hasItems = false
            for _ in pairs(entry.items) do hasItems = true; break end
            if hasItems then
                table.insert(results, entry)
            end
        end
    end
end

------------------------------------------------------------------------
-- The scan runner
--
-- One pass at a time, resumed each frame until it finishes. Everything
-- that made the old synchronous version correct is kept and simply
-- spread out: the journal stays suppressed for the whole pass, the
-- cache is written before unsuppressing, and an empty result is never
-- cached.
------------------------------------------------------------------------
local activeScan = nil
local StartScan          -- defined below, used by ScanLootBrowserSlot

local scanRunner = CreateFrame("Frame")
scanRunner:Hide()
-- Published for Tools/loadcheck.py, which has no frames and therefore no
-- OnUpdate: the only way to prove this yields rather than running one
-- long block is to resume it by hand and count the resumptions.
ns.LootScanRunner = scanRunner

--- Abandons the pass in flight. Only ever used to get out of the way of
--- something the player asked for.
local function CancelScan()
    if not activeScan then return end
    activeScan = nil
    scanRunner:Hide()
    UnsuppressEJ()
    ns.isLootScanning = false
end

--- Is the player looking at the journal we are about to drive?
---
--- The sweep works by moving the Encounter Journal's own selection --
--- instance, difficulty, slot filter -- and reading what comes back.
--- That is fine against a closed journal and rude against an open one:
--- every selection we make re-renders Blizzard's panel, so our 16ms
--- slice budget turned into 70-112ms slices the moment the Adventure
--- Guide was on screen. Measured, from a player who opened it while a
--- background sweep was running.
---
--- It is also their window. Our scan changes what it is showing while
--- they are reading it.
local function JournalIsOpen()
    return EncounterJournal and EncounterJournal.IsShown
        and EncounterJournal:IsShown() and true or false
end

------------------------------------------------------------------------
-- Does this pass say every boss drops the same thing?
--
-- Then it is not loot, it is one encounter's loot copied across every
-- row. The Encounter Journal has a single global selection, so anything
-- that re-selects underneath a running sweep -- the player browsing the
-- Adventure Guide was the case that found this -- makes
-- EJ_GetLootInfoByIndex answer for whichever encounter won rather than
-- the one being asked about.
--
-- Caught here as well as prevented upstream, because prevention is a
-- guess about every way the selection can move and this is a fact about
-- the result. And the cost of being wrong changed: these rows are
-- written to disk now, so a bad pass used to last a session and would
-- otherwise last until the next patch.
--
-- Four entries before it will call anything, and every one of them has
-- to match. Two bosses sharing a short filtered list is ordinary; four
-- sharing an identical one is not.
------------------------------------------------------------------------
function EveryBossIdentical(results)
    if type(results) ~= "table" or #results < 4 then return false end

    local first
    for _, entry in ipairs(results) do
        local ids = {}
        for _, items in pairs(entry.items or {}) do
            for _, item in ipairs(items) do
                ids[#ids + 1] = tostring(item.itemID or "?")
            end
        end
        if #ids == 0 then return false end
        table.sort(ids)
        local sig = table.concat(ids, ",")
        if not first then
            first = sig
        elseif sig ~= first then
            return false
        end
    end
    return true
end

local function FinishScan(ok, results)
    local scan = activeScan
    activeScan = nil
    scanRunner:Hide()

    -- Cache BEFORE unsuppressing. UnsuppressEJ restores difficulty and
    -- filters, which fires EJ_DIFFICULTY_UPDATE / EJ_LOOT_DATA_RECIEVED;
    -- our ejFrame handler wipes the cache on those events unless
    -- isLootScanning is still true, so the flag stays set across it.
    --
    -- Never cache an empty result. The prewarm runs seconds after login,
    -- before the journal has necessarily populated its loot map, and a
    -- cached `{}` would leave the panel blank until something forced the
    -- cache to clear.
    -- ...and never cache one gathered around an open journal.
    --
    -- Slices are skipped while the Adventure Guide is up, but the guide
    -- can be opened partway through one -- the check happens once per
    -- frame, not once per journal call. That window is enough to read a
    -- boss's loot out of whichever encounter the journal had selected
    -- instead, and a wrong answer written to the cache is served again
    -- for the rest of the session.
    --
    -- Throwing the pass away costs a rescan. Keeping it cost nine bosses
    -- listing the same ten items.
    if ok and results and #results > 0 and not JournalIsOpen()
        and not scanTainted and not EveryBossIdentical(results) then
        lootBrowserCache[scan.key] = results
        -- Written down so the next session does not pay for this again.
        SaveLootRows()
    end

    UnsuppressEJ()
    ns.isLootScanning = false

    if not ok then
        print("|cff00ff00YippYapp|r |cffff6060Loot Browser:|r Scan error: " .. tostring(results))
        return
    end

    -- Tell whoever is looking. The panel asked for this and got an empty
    -- table at the time, so without this it would sit on a loading line
    -- until the next thing that happened to redraw it.
    if ns.LootBrowserFrame and ns.LootBrowserFrame:IsShown()
        and ns.LootBrowser_RefreshDisplay then
        ns:LootBrowser_RefreshDisplay()
    end
end

local function RunSlice(self)
    local scan = activeScan
    if not scan then self:Hide(); return end

    ------------------------------------------------------------
    -- Every sweep waits, foreground included.
    --
    -- The first cut let a foreground scan through on the grounds that
    -- the player had asked our panel a question and was owed an answer.
    -- That was wrong, and the symptom showed it: the journal has ONE
    -- global selection, so while it is open our EJ_SelectEncounter and
    -- the journal's own re-selection fight over it -- and
    -- EJ_GetLootInfoByIndex then answers for whichever encounter won.
    --
    -- Reported as a Raids page where all nine bosses listed the same ten
    -- items. That is not a slow answer, it is a wrong one, and it was
    -- being written into the cache to be served again later.
    --
    -- Waiting is the only safe option. A delayed panel is a nuisance; a
    -- panel confidently showing one boss's loot under every boss's name
    -- is worse than no panel.
    ------------------------------------------------------------
    if JournalIsOpen() then
        scan.waitedForJournal = true
        return
    end

    sliceStartedAt = debugprofilestop()
    local ok, res = coroutine.resume(scan.co)
    if not ok then
        FinishScan(false, res)
    elseif coroutine.status(scan.co) == "dead" then
        FinishScan(true, res)
    end
end

-- Named for the tracer.
--
-- This is where the sweep actually spends the client's frames, and it is
-- an OnUpdate script on a local frame -- so nothing hanging off `ns`
-- could ever see it. The first real stall this addon caught was 9.6
-- seconds long and reported "not inside anything we wrap", which was
-- true and told us nothing.
--
-- One slice is supposed to be about 16ms. Anything near a second means
-- the budget is not being honoured somewhere inside the walk, and this
-- says so by name.
scanRunner:SetScript("OnUpdate", function(self)
    if ns.Trace and ns.Trace.on then
        return ns.Trace:Section("loot: sweep slice", RunSlice, self)
    end
    return RunSlice(self)
end)

--- Begins a pass. The coroutine body is the old synchronous sweep.
StartScan = function(cacheKey, classID, specID, slotFilter, background)
    SuppressEJ()
    scanTainted = false
    ns.isLootScanning = true
    -- Read by ScanYield on every slice of this pass. Set here rather
    -- than carried on activeScan because ScanYield is also reachable
    -- from the synchronous journal-link index, which has no scan.
    scanBudgetMs = background and SCAN_BUDGET_BACKGROUND_MS
                              or SCAN_BUDGET_FOREGROUND_MS

    activeScan = {
        key = cacheKey,
        background = background and true or false,
        co = coroutine.create(function()
            -- Marked rather than timed: this yields, so its elapsed time
            -- would be the wall clock it was parked across rather than
            -- the work it did. The label is the point -- the frame
            -- watchdog reads it, so a stall inside the cache build says
            -- so instead of shrugging.
            local prev = ns.Trace and ns.Trace:Mark("loot: instance cache")
            if not instanceCache and not BuildInstanceCache() then
                if ns.Trace then ns.Trace:Unmark(prev) end
                error("could not load instance data", 0)
            end
            if ns.Trace then ns.Trace:Unmark(prev) end
            local r = {}
            prev = ns.Trace and ns.Trace:Mark("loot: journal sweep")
            ScanSourceType(r, instanceCache.dungeons,    "dungeon",   ns.LOOT_DIFFICULTIES.DUNGEON,    classID, specID, slotFilter)
            ScanSourceType(r, instanceCache.raids,       "raid",      ns.LOOT_DIFFICULTIES.RAID,       classID, specID, slotFilter)
            ScanSourceType(r, instanceCache.worldBosses, "worldboss", ns.LOOT_DIFFICULTIES.WORLD_BOSS, classID, specID, slotFilter)
            if ns.Trace then ns.Trace:Unmark(prev) end
            return r
        end),
    }
    scanRunner:Show()
end

--- True while a pass is in flight, so the panel can say so.
function ns:IsLootScanRunning() return activeScan ~= nil end

--- `background` marks a pass nobody is waiting on -- the login prewarm.
--- It yields the journal the moment a real request turns up.
function ns:ScanLootBrowserSlot(specIndex, slotFilter, background)
    local classID = ns.lootBrowserState.selectedClassID or select(3, UnitClass("player"))
    local specID = ns.lootBrowserState.selectedSpecID
        or GetSpecializationInfoForClassID(classID, specIndex)

    -- The written-down copy, once per session, before anything decides a
    -- scan is needed.
    LoadLootRows()

    local cacheKey = specID .. "-" .. slotFilter
    if lootBrowserCache[cacheKey] then
        return lootBrowserCache[cacheKey]
    end

    -- The instance cache is built inside the pass, not here. Walking
    -- every tier of every expansion is the single heaviest stretch of
    -- this whole sweep, so doing it synchronously "first" was doing the
    -- worst part in exactly the way that trips the watchdog.

    if activeScan then
        -- The same filter is already on its way: let it finish.
        if activeScan.key == cacheKey then return {} end

        -- A different one. This used to return empty and drop the
        -- request on the floor, which is what made opening the browser
        -- during the login prewarm show the wrong thing and then sit
        -- there: the pass that finished was not the pass anybody asked
        -- for, and nothing ever started the one that was.
        --
        -- A background pass is only warming the cache, so it loses to
        -- somebody actually waiting. Two foreground requests means the
        -- player changed slot while it was working, and the newer answer
        -- is the one they want.
        if activeScan.background or not background then
            CancelScan()
        else
            return {}
        end
    end

    StartScan(cacheKey, classID, specID, slotFilter, background)
    -- Nothing yet. The panel shows its loading line, and the scan calls
    -- back into the display when it lands -- the same shape the EJ data
    -- events already use.
    return {}
end

------------------------------------------------------------------------
-- Journal link index (itemID -> real item link)
--
-- Built for the Best in Slot page, which only has bare item IDs. That is
-- not enough to show an item: a modern item's BASE entry is Rare, item
-- level 28, "+5 Intellect, 7 Armor". Everything real -- Epic quality,
-- +96 Intellect, 103 Armor, the upgrade track -- lives in the bonus IDs,
-- and the journal is where we can get them without inventing any.
--
-- Highest difficulty only. A BiS list is a target, so the Mythic version
-- is the one it means; the remaining gap to max rank is closed by
-- RewriteTooltipIlvl, exactly as the keystone rows do it.
------------------------------------------------------------------------
local journalLinks = nil
-- When the last build attempt failed. The journal is not always
-- populated the first time we ask, so failure must not be cached
-- forever -- but nor can it be free to retry: the Best in Slot page asks
-- once per row, so an unguarded retry would run a full journal scan
-- thirty-odd times per render.
local journalTriedAt = nil
local JOURNAL_RETRY = 30

------------------------------------------------------------------------
-- The index is another thing that only changes when the game patches.
--
-- It maps an item id to the journal's own link for it, and building it
-- is a third walk of the Encounter Journal -- once per session, lazily,
-- the first time the Best in Slot or Trinkets page asks about a row.
-- Which item the journal lists for a boss does not change between
-- reloads any more than the boss list does.
--
-- Same stamp as the instance list and the loot rows, so a patch or an
-- addon update invalidates all three together and nothing else
-- invalidates any of them.
------------------------------------------------------------------------
local function SaveJournalLinks()
    if not journalLinks or not next(journalLinks) then return end
    YippYappHelperDB = YippYappHelperDB or {}
    -- Safe by reference: each build assigns a fresh table, so dropping
    -- our own handle later does not empty the saved one.
    YippYappHelperDB.lootLinks = { stamp = CacheStamp(), data = journalLinks }
end

local journalLinksLoaded = false
local function LoadJournalLinks()
    if journalLinksLoaded then return end
    journalLinksLoaded = true

    local db = YippYappHelperDB and YippYappHelperDB.lootLinks
    if type(db) ~= "table" or db.stamp ~= CacheStamp() then return end
    if type(db.data) ~= "table" or not next(db.data) then return end

    -- Never accept an empty index, for the same reason one is never
    -- written: the journal is not always populated when first asked, and
    -- an empty one served as fact leaves every page showing base items
    -- with no way to recover.
    journalLinks = db.data
end

-- Highest difficulty per source type, mirroring LOOT_DIFFICULTIES.
local BEST_DIFFICULTY = { dungeon = 23, raid = 16, worldboss = 0 }

local function IndexInstances(instances, sourceType)
    local diff = BEST_DIFFICULTY[sourceType]
    for _, inst in ipairs(instances or {}) do
        for _, boss in ipairs(inst.bosses or {}) do
            EJ_SelectInstanceCompat(inst.instanceID)
            EJ_SelectEncounterCompat(boss.encounterID)
            EJ_SetDifficultyCompat(diff)

            local index = 1
            while true do
                local info = EJ_GetLootInfoByIndexCompat(index)
                if not info or not info.name then break end
                -- First link wins. An item that drops from several bosses
                -- is the same item; re-indexing it just costs work.
                if info.itemID and info.link and not journalLinks[info.itemID] then
                    journalLinks[info.itemID] = info.link
                end
                index = index + 1
            end
        end
    end
end

--- The journal's own link for an item, or nil if it does not drop.
---
--- nil is a normal answer, not a failure: crafted gear, tier tokens and
--- catalyst output are not in any loot table, and the caller falls back
--- to the bare item for those.
---
--- The index is built once and reused. It deliberately clears the loot
--- and slot filters first -- with the player's own class filter left in
--- place the journal returns only their armour type, so every other
--- spec's list would silently come back empty.
function ns:GetJournalItemLink(itemID)
    if not itemID then return nil end
    -- Last session's index, before deciding a walk is needed.
    LoadJournalLinks()
    if journalLinks then return journalLinks[itemID] end
    if journalTriedAt and (time() - journalTriedAt) < JOURNAL_RETRY then
        return nil
    end
    journalTriedAt = time()

    if not instanceCache and not BuildInstanceCache() then return nil end

    journalLinks = {}
    SuppressEJ()
    ns.isLootScanning = true

    local ok, err = pcall(function()
        EJ_SetLootFilterCompat(0, 0)
        if EISFT and EISFT.NoFilter then EJ_SetSlotFilterCompat(EISFT.NoFilter) end
        IndexInstances(instanceCache.dungeons,    "dungeon")
        IndexInstances(instanceCache.raids,       "raid")
        IndexInstances(instanceCache.worldBosses, "worldboss")
    end)

    -- Never keep an empty index. The journal is not always populated the
    -- first time we ask, and caching {} here would mean the page showed
    -- base items for the rest of the session with no way to recover.
    if not ok or not next(journalLinks) then
        journalLinks = nil
    else
        journalTriedAt = nil
        -- Written down so the next session does not walk for this again.
        SaveJournalLinks()
    end

    UnsuppressEJ()
    ns.isLootScanning = false
    if not ok then
        print("|cff00ff00YippYapp|r |cffff6060Loot Browser:|r Link index error: " .. tostring(err))
        return nil
    end
    return journalLinks and journalLinks[itemID] or nil
end

------------------------------------------------------------------------
-- Secondary Stat Filtering (client-side post-processing)
------------------------------------------------------------------------
function ns:FilterLootByStats(results, statKeys)
    if not statKeys or #statKeys == 0 then return results, 0 end

    local preFilterCount = #results
    local filtered = {}
    for _, entry in ipairs(results) do
        local newEntry = {
            sourceName  = entry.sourceName,
            sourceType  = entry.sourceType,
            bossName    = entry.bossName,
            encounterID = entry.encounterID,
            items       = {},
        }

        for diffID, items in pairs(entry.items) do
            local kept = {}
            for _, item in ipairs(items) do
                if not item.itemLink then
                    table.insert(kept, item)
                else
                    local stats = GetItemStatsCompat(item.itemLink)
                    if not stats then
                        table.insert(kept, item)
                    else
                        local hasAll = true
                        for _, key in ipairs(statKeys) do
                            if not stats[key] then
                                hasAll = false
                                break
                            end
                        end
                        if hasAll then
                            table.insert(kept, item)
                        end
                    end
                end
            end
            if #kept > 0 then
                newEntry.items[diffID] = kept
            end
        end

        local hasItems = false
        for _ in pairs(newEntry.items) do hasItems = true; break end
        if hasItems then
            table.insert(filtered, newEntry)
        end
    end
    return filtered, preFilterCount
end

-- Filter already-shaped data (Favorites / All Slots paths) whose items are
-- a single flat list per instance rather than per-difficulty dicts.
function ns:FilterShapedLootByStats(shaped, statKeys)
    if not statKeys or #statKeys == 0 then return shaped end
    local out = {}
    for _, inst in ipairs(shaped) do
        local kept = {}
        for _, item in ipairs(inst.items) do
            local keep = true
            if item.itemLink then
                local stats = GetItemStatsCompat(item.itemLink)
                if stats then
                    for _, key in ipairs(statKeys) do
                        if not stats[key] then keep = false; break end
                    end
                end
            end
            if keep then table.insert(kept, item) end
        end
        if #kept > 0 then
            table.insert(out, {
                instanceName = inst.instanceName,
                sourceType   = inst.sourceType,
                bgTexture    = inst.bgTexture,
                items        = kept,
            })
        end
    end
    return out
end

------------------------------------------------------------------------
-- Drop item level + upgrade comparison
--
-- The Encounter Journal's own item links carry whatever item level the
-- journal last resolved, which is unreliable early in a session and
-- needs item data to be cached. We already know exactly what each
-- difficulty awards this season (Core/Data.lua), so read it from there
-- instead — instant, correct, and no async item lookups.
------------------------------------------------------------------------
-- Raid drop item levels are the 4/6 rank of their track, NOT rank 1.
-- Verified in-game against the Encounter Journal on the 12.1 PTR:
--   Raid Finder  -> "Item Level 289, Upgrade Level: Veteran 4/6"
--   Mythic       -> "Item Level 328, Upgrade Level: Myth 4/6"
-- The community sheet listed each track's opening item level, which is
-- where the earlier 279/292/305/318 came from. The Great Vault numbers
-- below are unaffected and still match Blizzard's "jump to the first step
-- of the next track" rule (LFR -> Champion 1/6 = 292, and so on).
ns.LOOT_DIFF_ILVL = {
    -- Dungeon difficulty IDs (NOT yet verified in-game — see note below)
    [1]  = 259,   -- Normal / Follower
    [2]  = 276,   -- Heroic
    [23] = 292,   -- Mythic (M0)
    -- Raid difficulty IDs (verified)
    [17] = 289,   -- Raid Finder  = Veteran 4/6
    [14] = 302,   -- Normal       = Champion 4/6
    [15] = 315,   -- Heroic       = Hero 4/6
    [16] = 328,   -- Mythic       = Myth 4/6
    -- World boss
    [0]  = 292,
}

--- Item levels for the two Myth 9 bosses; see ns.RAID_VERY_RARE_ILVL.
local function MythNineIlvl()
    return ns.RAID_VERY_RARE_ILVL or 344
end

------------------------------------------------------------------------
-- Difficulty selection
--
-- The Encounter Journal only knows Normal / Heroic / Mythic-0 for
-- dungeons, so a single fixed item level per drop goes stale the moment
-- you start running keys. Instead the player picks the content level
-- they actually run and every drop is priced at that level.
--
-- Choices are derived from ns.DUNGEON_LOOT / ns.LOOT_DIFF_ILVL rather
-- than restated here, so there is one place to fix when Blizzard tunes
-- the numbers.
------------------------------------------------------------------------
local function BuildDungeonChoices()
    local out = {
        { key = "N", label = "Normal", ilvl = ns.LOOT_DIFF_ILVL[1] },
    }
    for _, row in ipairs(ns.DUNGEON_LOOT or {}) do
        local label
        if row.key == "Heroic" then
            label = "Heroic"
        elseif row.key == "M0" then
            label = "Mythic 0"
        else
            label = "M+" .. tostring(row.key):gsub("^M", "")
        end
        out[#out + 1] = {
            key = row.key, label = label,
            ilvl = row.loot, vault = row.vault,
        }
    end
    return out
end

local function BuildRaidChoices()
    return {
        { key = "LFR", label = "Raid Finder", ilvl = ns.LOOT_DIFF_ILVL[17],
          vault = ns.RAID_VAULT_TRACKS and ns.RAID_VAULT_TRACKS.LFR.ilvl },
        { key = "N",   label = "Normal",      ilvl = ns.LOOT_DIFF_ILVL[14],
          vault = ns.RAID_VAULT_TRACKS and ns.RAID_VAULT_TRACKS.Normal.ilvl },
        { key = "H",   label = "Heroic",      ilvl = ns.LOOT_DIFF_ILVL[15],
          vault = ns.RAID_VAULT_TRACKS and ns.RAID_VAULT_TRACKS.Heroic.ilvl },
        { key = "M",   label = "Mythic",      ilvl = ns.LOOT_DIFF_ILVL[16],
          vault = ns.RAID_VAULT_TRACKS and ns.RAID_VAULT_TRACKS.Mythic.ilvl,
          allowsMythNine = true },
    }
end

local difficultyChoices
function ns:GetLootDifficultyChoices(view)
    difficultyChoices = difficultyChoices or {
        dungeon = BuildDungeonChoices(),
        raid    = BuildRaidChoices(),
    }
    return difficultyChoices[view] or difficultyChoices.dungeon
end

-- First-run defaults follow the player's chosen profile, so a Mythic
-- raider does not open the browser on Raid Finder numbers.
local PROFILE_DEFAULTS = {
    normal = { dungeon = "M0",  raid = "N" },
    heroic = { dungeon = "M8",  raid = "H" },
    mythic = { dungeon = "M10", raid = "M" },
}

local function DefaultDifficulty(view)
    local profile = ns.GetCurrentProfile and ns:GetCurrentProfile()
    local set = PROFILE_DEFAULTS[profile and profile.id or "heroic"]
        or PROFILE_DEFAULTS.heroic
    return set[view]
end

function ns:GetSelectedLootDifficulty(view)
    view = view or ns.lootBrowserState.selectedView or "dungeon"
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.lootDifficulty = YippYappHelperDB.lootDifficulty or {}

    local key = YippYappHelperDB.lootDifficulty[view] or DefaultDifficulty(view)
    local choices = ns:GetLootDifficultyChoices(view)
    for _, c in ipairs(choices) do
        if c.key == key then return c end
    end
    -- Saved key no longer exists (season retune) — fall back to the last
    -- entry, which is the hardest content available.
    return choices[#choices]
end

function ns:SetSelectedLootDifficulty(view, key)
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.lootDifficulty = YippYappHelperDB.lootDifficulty or {}
    YippYappHelperDB.lootDifficulty[view] = key
end

-- Encounter Journal difficulty ID for the selected choice, so the item
-- link we show is the one for that difficulty. The journal has no
-- concept of keystone levels, so every M+ selection maps to Mythic 0 —
-- the tooltip shows the M0 item, and our own "Drops at" line carries the
-- real key-level item level.
-- Keys MUST match the `key` fields these choices are built from:
-- ns.DUNGEON_LOOT uses "Heroic" / "M0" / "M2".., not "H". The map
-- previously said H = 2, so every Heroic selection missed and fell
-- through to the `or 23` default — silently showing Mythic loot.
local DUNGEON_EJ_DIFF = { N = 1, Heroic = 2, M0 = 23 }
local RAID_EJ_DIFF    = { LFR = 17, N = 14, H = 15, M = 16 }

--- Keystone level for the current dungeon selection, or nil when the
--- selection is not a keystone (Normal / Heroic / M0) or we are in raids.
function ns:GetSelectedKeystoneLevel(view)
    view = view or ns.lootBrowserState.selectedView or "dungeon"
    if view ~= "dungeon" then return nil end
    local c = ns:GetSelectedLootDifficulty(view)
    if not c or type(c.key) ~= "string" then return nil end
    local n = c.key:match("^M(%d+)$")
    n = n and tonumber(n)
    if not n or n < 2 then return nil end   -- M0 is not a keystone
    return n
end

function ns:GetSelectedEJDifficulty(view)
    view = view or ns.lootBrowserState.selectedView or "dungeon"
    local c = ns:GetSelectedLootDifficulty(view)
    if not c then return nil end
    if view == "raid" then return RAID_EJ_DIFF[c.key] end

    local mapped = DUNGEON_EJ_DIFF[c.key]
    if mapped then return mapped end
    -- Keystone levels have no journal difficulty of their own; Mythic 0
    -- is the correct base to read their links from.
    if type(c.key) == "string" and c.key:match("^M%d+$") then return 23 end
    -- Anything else is a table/map mismatch. Say so instead of silently
    -- defaulting, which is how "Heroic" ended up showing Mythic loot.
    print(("|cff00ff00YippYapp|r |cffff6060Loot Browser:|r unmapped difficulty key '%s' — please report.")
        :format(tostring(c.key)))
    return 23
end

--- Item level a drop would come in at, for the currently selected
--- difficulty. Applies the Myth 9 override on the last two raid bosses.
function ns:GetLootIlvlForSelection(view, instanceName, bossName)
    local choice = ns:GetSelectedLootDifficulty(view)
    if not choice then return nil end
    if choice.allowsMythNine and instanceName and bossName
        and ns:IsMythNineBoss(instanceName, bossName) then
        return MythNineIlvl(), choice
    end
    return choice.ilvl, choice
end

--- True when this boss drops at Myth 9 (344) instead of the normal
--- Mythic item level. In Season 2 that is the penultimate and final
--- boss of the current raid, plus any Very Rare item.
function ns:IsMythNineBoss(instanceName, bossName)
    local prog = ns.PROGRESSION
    if not prog or not prog.RAID_NAME or not prog.RAID_BOSSES then return false end
    if instanceName ~= prog.RAID_NAME then return false end

    local bosses = prog.RAID_BOSSES
    local n = #bosses
    if n < 2 then return false end
    return bossName == bosses[n] or bossName == bosses[n - 1]
end

------------------------------------------------------------------------
-- Equipped-gear comparison
------------------------------------------------------------------------
local EQUIP_LOC_SLOTS = {
    INVTYPE_HEAD            = { 1 },
    INVTYPE_NECK            = { 2 },
    INVTYPE_SHOULDER        = { 3 },
    INVTYPE_CLOAK           = { 15 },
    INVTYPE_CHEST           = { 5 },
    INVTYPE_ROBE            = { 5 },
    INVTYPE_WRIST           = { 9 },
    INVTYPE_HAND            = { 10 },
    INVTYPE_WAIST           = { 6 },
    INVTYPE_LEGS            = { 7 },
    INVTYPE_FEET            = { 8 },
    INVTYPE_FINGER          = { 11, 12 },
    INVTYPE_TRINKET         = { 13, 14 },
    INVTYPE_WEAPON          = { 16, 17 },
    INVTYPE_2HWEAPON        = { 16 },
    INVTYPE_WEAPONMAINHAND  = { 16 },
    INVTYPE_RANGED          = { 16 },
    INVTYPE_RANGEDRIGHT     = { 16 },
    INVTYPE_WEAPONOFFHAND   = { 17 },
    INVTYPE_SHIELD          = { 17 },
    INVTYPE_HOLDABLE        = { 17 },
}

-- A full refresh asks about hundreds of icons, most of which share a
-- slot, so cache the equipped item levels and drop the cache when gear
-- actually changes.
local equippedIlvlCache = {}

local function EquippedIlvl(slotID)
    local cached = equippedIlvlCache[slotID]
    if cached ~= nil then
        return cached or nil  -- `false` means "checked, slot is empty"
    end

    local loc = ItemLocation:CreateFromEquipmentSlot(slotID)
    if not C_Item.DoesItemExist(loc) then
        equippedIlvlCache[slotID] = false
        return nil
    end
    local ok, lvl = pcall(C_Item.GetCurrentItemLevel, loc)
    if ok and lvl and lvl > 0 then
        equippedIlvlCache[slotID] = lvl
        return lvl
    end
    equippedIlvlCache[slotID] = false
    return nil
end

--- True while a two-handed weapon is equipped.
---
--- Matters because an empty off-hand under a two-hander is not an empty
--- slot -- it is a slot OCCUPIED by the other half of what you are
--- already wielding. Treating it as empty is what made every one-hand
--- weapon, shield and off-hand in the browser read "new", i.e. a free
--- upgrade over nothing, to a player holding a 311 staff. Taking any of
--- them costs you that staff.
local TWO_HAND_LOCS = {
    INVTYPE_2HWEAPON = true, INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true,
}

local function MainHandIsTwoHander()
    local link = GetInventoryItemLink and GetInventoryItemLink("player", 16)
    if not link then return false end
    local _, _, _, equipLoc = GetItemInfoInstant(link)
    return equipLoc and TWO_HAND_LOCS[equipLoc] or false
end

local equipWatcher = CreateFrame("Frame")
equipWatcher:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
equipWatcher:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
equipWatcher:SetScript("OnEvent", function()
    wipe(equippedIlvlCache)
end)

--- The inventory slots an item can go in, or nil if it is not gear.
---
--- Exported so the Best in Slot page can check a pin before storing it.
--- Deriving the slot from the item is the only way to be sure: the guide
--- data carries a slot name per row, but a pin can come from anywhere,
--- and taking its word would let a starred helm sit in a ring slot.
function ns:GetItemSlots(itemID)
    if not itemID then return nil end
    local _, _, _, equipLoc = GetItemInfoInstant(itemID)
    return equipLoc and EQUIP_LOC_SLOTS[equipLoc] or nil
end

--- Lowest equipped item level among the slots this item could fill.
--- For paired slots (rings, trinkets, weapons) that is the piece you
--- would actually replace, which is the comparison that matters.
function ns:GetEquippedIlvlForItem(itemID)
    if not itemID then return nil end
    local _, _, _, equipLoc = GetItemInfoInstant(itemID)
    local slots = equipLoc and EQUIP_LOC_SLOTS[equipLoc]
    if not slots then return nil end

    local lowest, twoHand
    for _, slotID in ipairs(slots) do
        local lvl = EquippedIlvl(slotID)
        -- The off-hand is only genuinely empty if no two-hander is
        -- filling it. Under a two-hander the honest baseline is that
        -- weapon's own item level, because it is what you would be
        -- giving up.
        if not lvl and slotID == 17 then
            if twoHand == nil then twoHand = MainHandIsTwoHander() end
            if twoHand then lvl = EquippedIlvl(16) end
        end
        -- A genuinely empty slot is the weakest possible "current" item,
        -- so any drop for it counts as an upgrade.
        if not lvl then return 0, slotID end
        if not lowest or lvl < lowest then lowest = lvl end
    end
    return lowest
end

--- "Champion 3/6" for an item level, or nil if it is not on a track.
--- Where tracks overlap (305 is both Champion 5/6 and Hero 1/6) the
--- higher track wins, since that is the one you would keep upgrading.
function ns:DescribeIlvlRank(ilvl)
    if not ilvl or not ns.TRACK_ORDER then return nil end
    for i = #ns.TRACK_ORDER, 1, -1 do
        local track = ns.TRACK_ORDER[i]
        local levels = ns.GEAR_TRACKS[track]
        if levels then
            for rank, lvl in ipairs(levels) do
                if lvl == ilvl then
                    return ("%s %d/%d"):format(track, rank, #levels)
                end
            end
        end
    end
    return nil
end

--- Upgrade verdict for one drop, priced at the selected difficulty.
--- Returns nil when we cannot compare (unknown slot or unknown ilvl).
function ns:GetLootUpgradeInfo(itemID, view, instanceName, bossName, veryRare, itemLink)
    local expected, choice = ns:GetLootIlvlForSelection(view, instanceName, bossName)
    -- A Very Rare item comes in at Myth 9 from any Mythic raid boss, not
    -- just the final two.
    if veryRare and choice and choice.allowsMythNine then
        expected = MythNineIlvl()
    end

    -- Prefer the item level the Encounter Journal itself reports — it is
    -- the same data the Adventure Guide's difficulty tabs show, so it
    -- stays right even when our table is stale.
    --
    -- ...but NOT for keystone levels. The journal's Mythic Keystone
    -- difficulty does not reliably report a per-key-level item level, and
    -- the probe that appeared to show otherwise was comparing different
    -- items. ns.DUNGEON_LOOT (from the community sheet, column O) is the
    -- source of truth for keystones; the link is authoritative only for
    -- the real journal difficulties: Normal, Heroic, M0 and the four raid
    -- difficulties.
    local fromJournal = false
    local isKeystone = ns:GetSelectedKeystoneLevel(view) ~= nil
    if not isKeystone then
        local actual = itemLink and ns.SafeItemLevel and ns.SafeItemLevel(itemLink)
        if actual and actual > 0 then
            expected = actual
            fromJournal = true
        end
    end
    if not expected then return nil end
    local equipped = ns:GetEquippedIlvlForItem(itemID)
    if not equipped then return nil end
    return {
        expected  = expected,
        equipped  = equipped,
        delta     = expected - equipped,
        isUpgrade = expected > equipped,
        vault     = choice and choice.vault,
        vaultRank = choice and choice.vault and ns:DescribeIlvlRank(choice.vault),
        rank      = ns:DescribeIlvlRank(expected),
        diffLabel = choice and choice.label,
        fromJournal = fromJournal,
        isKeystone = isKeystone,
        mythNine  = choice and choice.allowsMythNine
            and ns:IsMythNineBoss(instanceName, bossName) or false,
    }
end

------------------------------------------------------------------------
-- Cache Invalidation
------------------------------------------------------------------------
function ns:ClearLootBrowserCache()
    wipe(lootBrowserCache)
end

function ns:ClearAllLootBrowserCaches(forgetSaved)
    wipe(lootBrowserCache)
    instanceCache = nil
    -- The written-down copy survives by default: it is the thing that
    -- stops the walk happening every session, so dropping it on every
    -- routine invalidation would defeat the point. `forgetSaved` is for
    -- when the list itself is suspect rather than the loot hanging off
    -- it.
    if forgetSaved and YippYappHelperDB then
        YippYappHelperDB.lootInstances = nil
        YippYappHelperDB.lootRows = nil
        YippYappHelperDB.lootLinks = nil
        lootRowsLoaded = false
        journalLinksLoaded = false
        journalLinks = nil
    end
end

------------------------------------------------------------------------
-- Navigation Functions
------------------------------------------------------------------------
function ns:LootBrowser_DetectSpec()
    local _, classFile, classID = UnitClass("player")
    ns.lootBrowserState.selectedClassID = classID
    ns.lootBrowserState.selectedClassFile = classFile

    local lootSpecID = GetLootSpecialization()
    if lootSpecID == 0 then
        local currentSpec = GetSpecialization()
        if currentSpec then
            ns.lootBrowserState.selectedSpecIndex = currentSpec
            ns.lootBrowserState.selectedSpecID = select(1, GetSpecializationInfo(currentSpec))
        end
    else
        for i = 1, GetNumSpecializations() do
            local specID = GetSpecializationInfo(i)
            if specID == lootSpecID then
                ns.lootBrowserState.selectedSpecIndex = i
                ns.lootBrowserState.selectedSpecID = specID
                break
            end
        end
    end

    -- Default to Favorites if any exist, otherwise All Slots
    if ns:GetFavoritesCount() > 0 then
        ns.lootBrowserState.isFavoritesMode = true
        ns.lootBrowserState.isAllSlots = false
        ns.lootBrowserState.selectedSlot = nil
        ns.lootBrowserState.selectedSlotName = "Favorites"
    else
        ns.lootBrowserState.isFavoritesMode = false
        ns.lootBrowserState.isAllSlots = true
        ns.lootBrowserState.selectedSlot = nil
        ns.lootBrowserState.selectedSlotName = "All Slots"
    end
end

function ns:LootBrowser_SwitchSpec(specIndex)
    if ns.isLootScanning then return end
    local classID = ns.lootBrowserState.selectedClassID
    if not classID then return end
    local specID = GetSpecializationInfoForClassID(classID, specIndex)
    if not specID then return end
    ns.lootBrowserState.selectedSpecIndex = specIndex
    ns.lootBrowserState.selectedSpecID = specID
    ns:ClearLootBrowserCache()
    if ns.LootBrowser_ShowPage then ns:LootBrowser_ShowPage() end
end

function ns:LootBrowser_SwitchClass(classID)
    if ns.isLootScanning then return end
    if not classID then return end
    local _, classFile = GetClassInfo(classID)
    ns.lootBrowserState.selectedClassID = classID
    ns.lootBrowserState.selectedClassFile = classFile
    local specID = GetSpecializationInfoForClassID(classID, 1)
    ns.lootBrowserState.selectedSpecIndex = 1
    ns.lootBrowserState.selectedSpecID = specID
    ns:ClearLootBrowserCache()
    if ns.LootBrowser_UpdateSpecBar then ns:LootBrowser_UpdateSpecBar() end
    if ns.LootBrowser_ShowPage then ns:LootBrowser_ShowPage() end
end

function ns:LootBrowser_SwitchSlot(slotFilter, slotName)
    if slotFilter == "FAVORITES" then
        ns.lootBrowserState.isFavoritesMode = true
        ns.lootBrowserState.isAllSlots = false
        ns.lootBrowserState.selectedSlot = nil
        ns.lootBrowserState.selectedSlotName = "Favorites"
    elseif slotFilter == "ALL_SLOTS" then
        ns.lootBrowserState.isFavoritesMode = false
        ns.lootBrowserState.isAllSlots = true
        ns.lootBrowserState.selectedSlot = nil
        ns.lootBrowserState.selectedSlotName = "All Slots"
    else
        ns.lootBrowserState.isFavoritesMode = false
        ns.lootBrowserState.isAllSlots = false
        ns.lootBrowserState.selectedSlot = slotFilter
        ns.lootBrowserState.selectedSlotName = slotName
    end
    if ns.LootBrowser_ShowPage then ns:LootBrowser_ShowPage() end
end

function ns:LootBrowser_SwitchView(view)
    ns.lootBrowserState.selectedView = view
    if ns.LootBrowser_UpdateViewTabs then ns:LootBrowser_UpdateViewTabs() end
    -- The "By boss" chip is inert outside the dungeon view, so restyle it
    -- whenever the view changes.
    if ns.LootBrowser_UpdateDisplayToggles then ns:LootBrowser_UpdateDisplayToggles() end
    if ns.LootBrowser_RefreshDisplay then ns:LootBrowser_RefreshDisplay() end
end

function ns:LootBrowser_ToggleStat(statKey)
    local stats = ns.lootBrowserState.selectedStats
    for i, key in ipairs(stats) do
        if key == statKey then
            table.remove(stats, i)
            ns:LootBrowser_OnStatFilterChanged()
            return
        end
    end
    if #stats >= 2 then return end
    table.insert(stats, statKey)
    ns:LootBrowser_OnStatFilterChanged()
end

function ns:LootBrowser_ClearStats()
    wipe(ns.lootBrowserState.selectedStats)
    ns:LootBrowser_OnStatFilterChanged()
end

function ns:LootBrowser_OnStatFilterChanged()
    if ns.LootBrowser_UpdateStatBar then ns:LootBrowser_UpdateStatBar() end
    if ns.lootBrowserState.selectedSlot or ns.lootBrowserState.isFavoritesMode or ns.lootBrowserState.isAllSlots then
        if ns.LootBrowser_RefreshDisplay then
            ns:LootBrowser_RefreshDisplay()
        end
    end
end

------------------------------------------------------------------------
-- Favorites System
------------------------------------------------------------------------
function ns:GetLootCharacterKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

--- Favourites for one spec, or nil when there is no spec to key on.
---
--- `specID` is explicit so pages other than the Loot Browser can use
--- this. Reading ns.lootBrowserState.selectedSpecID unconditionally
--- meant the store answered to a dropdown on a different page: a
--- favourite marked from the Trinkets page would land under whichever
--- spec the Loot Browser happened to be showing, or silently go nowhere
--- if it had never been opened. The Loot Browser still passes nothing
--- and gets its own selection, which is what it wants.
local function GetFavoritesTable(create, specID)
    YippYappHelperDB = YippYappHelperDB or {}
    if not YippYappHelperDB.lootFavorites then
        if not create then return nil end
        YippYappHelperDB.lootFavorites = {}
    end
    local charKey = ns:GetLootCharacterKey()
    if not YippYappHelperDB.lootFavorites[charKey] then
        if not create then return nil end
        YippYappHelperDB.lootFavorites[charKey] = {}
    end
    specID = specID or ns.lootBrowserState.selectedSpecID
    if not specID then return nil end
    if not YippYappHelperDB.lootFavorites[charKey][specID] then
        if not create then return nil end
        YippYappHelperDB.lootFavorites[charKey][specID] = {}
    end
    return YippYappHelperDB.lootFavorites[charKey][specID]
end

--- The spec a page outside the Loot Browser should mark against: the
--- one the player is actually playing, not a dropdown they may never
--- have touched.
function ns:GetPlayerSpecID()
    if not GetSpecialization then return nil end
    local idx = GetSpecialization()
    if not idx then return nil end
    return (GetSpecializationInfo(idx))
end

function ns:IsLootFavorite(itemID, specID)
    local tbl = GetFavoritesTable(false, specID)
    return tbl and tbl[itemID] or false
end

function ns:ToggleLootFavorite(itemID, specID)
    if ns:IsLootFavorite(itemID, specID) then
        local tbl = GetFavoritesTable(false, specID)
        if tbl then tbl[itemID] = nil end
    else
        local tbl = GetFavoritesTable(true, specID)
        if tbl then tbl[itemID] = true end
    end
end

function ns:GetAllFavoriteItemIDs(specID)
    local tbl = GetFavoritesTable(false, specID)
    return tbl or {}
end

function ns:GetFavoritesCount(specID)
    local tbl = GetFavoritesTable(false, specID)
    if not tbl then return 0 end
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

------------------------------------------------------------------------
-- Reshape: regroup per-boss results into per-instance with dedup
------------------------------------------------------------------------
-- Difficulty priority for dedup (higher = preferred for display)
local DIFF_PRIORITY = {
    [23] = 6,  -- Mythic dungeon
    [2]  = 5,  -- Heroic dungeon
    [1]  = 4,  -- Normal dungeon
    [16] = 6,  -- Mythic raid
    [15] = 5,  -- Heroic raid
    [14] = 4,  -- Normal raid
    [17] = 3,  -- LFR
    [0]  = 4,  -- World boss
}

--- Regroup per-boss results into per-instance, deduped.
---
--- Picks the item version for the difficulty currently selected in the
--- browser, falling back to the hardest available. Previously this always
--- kept the hardest version, so in All Slots / Favorites mode every
--- tooltip showed Mythic loot no matter what the difficulty dropdown
--- said — the dropdown only affected the number we printed ourselves.
function ns:ReshapeLootByInstance(results, preferredDiff)
    if preferredDiff == nil then
        preferredDiff = ns:GetSelectedEJDifficulty()
    end

    local function DiffPriority(diffID)
        if diffID == preferredDiff then return 100 end
        return DIFF_PRIORITY[diffID] or 0
    end

    -- Build bgTexture lookup from instance cache
    local bgLookup = {}
    local cache = instanceCache
    if cache then
        for _, list in ipairs({ cache.dungeons, cache.raids, cache.worldBosses }) do
            for _, inst in ipairs(list) do
                bgLookup[inst.name] = inst.bgTexture
            end
        end
    end

    local byInstance = {}   -- instanceName -> { sourceType, items[] }
    local instanceOrder = {} -- preserve encounter order

    for _, entry in ipairs(results) do
        local instName = entry.sourceName
        if not byInstance[instName] then
            byInstance[instName] = {
                instanceName = instName,
                sourceType   = entry.sourceType,
                bgTexture    = bgLookup[instName],
                items        = {},
                itemSeen     = {},  -- itemID -> index in items
            }
            table.insert(instanceOrder, instName)
        end
        local inst = byInstance[instName]

        -- Collect items from all difficulties, keeping highest-priority version
        for diffID, diffItems in pairs(entry.items) do
            local priority = DiffPriority(diffID)
            for _, item in ipairs(diffItems) do
                local existIdx = inst.itemSeen[item.itemID]
                if existIdx then
                    local existing = inst.items[existIdx]
                    if priority > (existing._priority or 0) then
                        existing.itemLink = item.itemLink
                        existing.icon = item.icon
                        existing.diffID = diffID
                        existing._priority = priority
                        existing.bossName = entry.bossName
                        existing.veryRare = item.veryRare
                    end
                else
                    local newItem = {
                        itemID   = item.itemID,
                        name     = item.name,
                        icon     = item.icon,
                        itemLink = item.itemLink,
                        diffID   = diffID,
                        bossName = entry.bossName,
                        veryRare = item.veryRare,
                        sourceName = instName,
                        _priority = priority,
                    }
                    table.insert(inst.items, newItem)
                    inst.itemSeen[item.itemID] = #inst.items
                end
            end
        end
    end

    -- Build ordered result, strip internal bookkeeping
    local shaped = {}
    for _, instName in ipairs(instanceOrder) do
        local inst = byInstance[instName]
        inst.itemSeen = nil
        for _, item in ipairs(inst.items) do
            item._priority = nil
        end
        table.insert(shaped, inst)
    end
    return shaped
end

------------------------------------------------------------------------
-- Favorites Loot Scan: scan all slots, merge, filter to favorites
------------------------------------------------------------------------
function ns:ScanFavoritesLoot()
    local specIndex = ns.lootBrowserState.selectedSpecIndex
    if not specIndex then return {} end

    local favIDs = ns:GetAllFavoriteItemIDs()
    local hasFavs = false
    for _ in pairs(favIDs) do hasFavs = true; break end
    if not hasFavs then return {} end

    -- One scan with NoFilter returns every slot at once — ~14x faster than
    -- scanning each slot filter individually.
    local allResults = ns:ScanLootBrowserSlot(specIndex, EISFT.NoFilter) or {}

    -- Reshape by instance
    local shaped = ns:ReshapeLootByInstance(allResults)

    -- Filter to only favorited items
    local filtered = {}
    for _, inst in ipairs(shaped) do
        local kept = {}
        for _, item in ipairs(inst.items) do
            if favIDs[item.itemID] then
                table.insert(kept, item)
            end
        end
        if #kept > 0 then
            table.insert(filtered, {
                instanceName = inst.instanceName,
                sourceType   = inst.sourceType,
                items        = kept,
            })
        end
    end

    -- Sort by number of favorites descending
    table.sort(filtered, function(a, b)
        return #a.items > #b.items
    end)

    return filtered
end

------------------------------------------------------------------------
-- All Slots Scan: scan all 14 slots and merge by instance
------------------------------------------------------------------------
function ns:ScanAllSlotsLoot()
    local specIndex = ns.lootBrowserState.selectedSpecIndex
    if not specIndex then return {} end

    -- One scan with NoFilter returns every slot at once — ~14x faster than
    -- scanning each slot filter individually.
    local allResults = ns:ScanLootBrowserSlot(specIndex, EISFT.NoFilter) or {}
    return ns:ReshapeLootByInstance(allResults)
end

------------------------------------------------------------------------
-- Item data arrival (debounced re-render)
--
-- Icons and names come back empty for items the client has not cached
-- yet. We request a load during render; this redraws once those land so
-- the rows fill in instead of waiting for the next user interaction.
------------------------------------------------------------------------
local itemLoadFrame = CreateFrame("Frame")
local itemRedrawPending = false
itemLoadFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
itemLoadFrame:SetScript("OnEvent", function()
    if itemRedrawPending or ns.isLootScanning then return end
    if not (ns.LootBrowserFrame and ns.LootBrowserFrame:IsShown()) then return end
    itemRedrawPending = true
    -- ITEM_DATA_LOAD_RESULT fires once per item, so coalesce hard.
    C_Timer.After(0.75, function()
        itemRedrawPending = false
        if ns.LootBrowserFrame and ns.LootBrowserFrame:IsShown()
            and ns.LootBrowser_RefreshDisplay then
            ns:LootBrowser_RefreshDisplay()
        end
    end)
end)

------------------------------------------------------------------------
-- EJ Event Listener (debounced cache refresh)
------------------------------------------------------------------------
local ejFrame = CreateFrame("Frame")
local lbRefreshPending = false
ejFrame:RegisterEvent("EJ_LOOT_DATA_RECIEVED")
ejFrame:RegisterEvent("EJ_DIFFICULTY_UPDATE")

ejFrame:SetScript("OnEvent", function()
    if not ns.isLootScanning then
        -- Only invalidate + refresh when the panel is open; keep the cache
        -- warm otherwise so reopening feels instant.
        if ns.LootBrowserFrame and ns.LootBrowserFrame:IsShown() then
            ns:ClearLootBrowserCache()
            if not lbRefreshPending
               and (ns.lootBrowserState.selectedSlot or ns.lootBrowserState.isFavoritesMode or ns.lootBrowserState.isAllSlots)
               and ns.LootBrowser_RefreshDisplay then
                lbRefreshPending = true
                C_Timer.After(0.5, function()
                    lbRefreshPending = false
                    if ns.LootBrowserFrame and ns.LootBrowserFrame:IsShown()
                       and (ns.lootBrowserState.selectedSlot or ns.lootBrowserState.isFavoritesMode or ns.lootBrowserState.isAllSlots) then
                        ns:LootBrowser_RefreshDisplay()
                    end
                end)
            end
        end
    end
end)

------------------------------------------------------------------------
-- Prewarm: background-scan common filters shortly after login so the
-- first panel open doesn't pay the EJ async-fetch latency.
------------------------------------------------------------------------
local EISFT = Enum.ItemSlotFilterType
local prewarmFrame = CreateFrame("Frame")
prewarmFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
prewarmFrame:SetScript("OnEvent", function(self)
    ------------------------------------------------------------
    -- Not while the player is inside an instance.
    --
    -- This guard used to live inside the load-gate closure below, which
    -- meant it only ever ran under `/yh loadtest loot` -- the by-hand
    -- path, where the player has explicitly asked for the work and the
    -- guard is least wanted. On the normal path, which is the one every
    -- session takes, the gate returns "go ahead", the closure is never
    -- called, and the sweep ran on the way into dungeons exactly as
    -- before. The protection read as present and was not.
    --
    -- Note the order against the unregister below: bailing here keeps
    -- the event registered, so the next loading screen asks again.
    ------------------------------------------------------------
    if IsInInstance and IsInInstance() then return end
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    -- Held back while hunting a freeze. This walks every tier of every
    -- expansion through the Encounter Journal a few seconds after a
    -- loading screen, which puts it squarely in the window under
    -- suspicion -- so it gets a name and can be run by hand instead.
    if ns.LoadGateOpen and not ns.LoadGateOpen("loot", function()
        ------------------------------------------------------------
        -- Run by hand, so the instance guard above deliberately does
        -- not apply: asking for the work IS asking for it here.
        --
        -- This is a nicety -- it makes the first panel open feel
        -- instant -- and it is thousands of journal calls, five seconds
        -- after a loading screen, on a client that is still busy with
        -- one. Zoning into a dungeon is the version of that where the
        -- player is least able to afford it.
        --
        -- Deliberately NOT claiming the client loads journal data on
        -- zone-in: that was asserted here and never verified. What IS
        -- established, by this file's own scars, is that the journal
        -- populates asynchronously and is not ready when first asked --
        -- see the EJ_LOOT_DATA_RECIEVED handling and the five-second
        -- delay below. Doing a long walk through it during a zone is bad
        -- on those grounds alone.
        --
        -- Reported as freezing on the way in and out of dungeons, and on
        -- reloading inside one. Waiting costs a slower first open once,
        -- outside.
        ------------------------------------------------------------
        if ns.LootBrowser_DetectSpec then ns:LootBrowser_DetectSpec() end
        local state = ns.lootBrowserState
        if not state.selectedSpecIndex then return end
        ns:ScanLootBrowserSlot(state.selectedSpecIndex, EISFT.NoFilter, true)
    end, function()
        -- The sweep runs on a coroutine driven by an OnUpdate, so the
        -- call above returns long before the work does.
        return ns.IsLootScanRunning and ns:IsLootScanRunning() or false
    end, function()
        -- The expensive half is the instance cache -- every tier of
        -- every expansion -- and it is built once and kept. Run by hand
        -- without this, the sweep finds it already there and reports the
        -- cost of nothing.
        ns:ClearAllLootBrowserCaches()
    end) then return end
    -- First pass at 5s: EJ has usually populated its initial map by then.
    C_Timer.After(5, function()
        if ns.LootBrowser_DetectSpec then ns:LootBrowser_DetectSpec() end
        local state = ns.lootBrowserState
        if not state.selectedSpecIndex then return end
        -- NoFilter returns every slot in one scan → powers All Slots/Favorites
        -- and is the longest single scan; running it primes the EJ cache for
        -- the per-slot scans that follow.
        ns:ScanLootBrowserSlot(state.selectedSpecIndex, EISFT.NoFilter, true)
    end)
    -- Second pass at 12s to cover slot-specific cache for the default "Head".
    C_Timer.After(12, function()
        local state = ns.lootBrowserState
        if not state.selectedSpecIndex then return end
        ns:ScanLootBrowserSlot(state.selectedSpecIndex, EISFT.Head, true)
    end)
end)
