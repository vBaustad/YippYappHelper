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
local function BuildInstanceCache()
    if instanceCache then return instanceCache end

    SuppressEJ()

    local ok, result = pcall(function()
        local instances = { dungeons = {}, raids = {}, worldBosses = {} }

        local currentTier = EJ_GetCurrentTierCompat()
        if not currentTier then return nil end

        local numTiers = EJ_GetNumTiersCompat()
        local seasonalNames = GetSeasonalDungeonNames()
        local foundDungeons = {}
        for tier = numTiers, 1, -1 do
            EJ_SelectTierCompat(tier)
            local index = 1
            while true do
                local instanceID, name = EJ_GetInstanceByIndexCompat(index, false)
                if not instanceID then break end
                if name and seasonalNames[name] and not foundDungeons[instanceID] then
                    foundDungeons[instanceID] = true
                    EJ_SelectInstanceCompat(instanceID)
                    local bosses = {}
                    local bi = 1
                    while true do
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

        local raidIdx = 1
        while true do
            local instanceID, name = EJ_GetInstanceByIndexCompat(raidIdx, true)
            if not instanceID then break end

            EJ_SelectInstanceCompat(instanceID)
            local bosses = {}
            local bi = 1
            while true do
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
    end)

    UnsuppressEJ()

    if not ok then
        print("|cff00ff00YippYapp|r |cffff6060Loot Browser:|r Instance cache error: " .. tostring(result))
        return nil
    end

    instanceCache = result
    return result
end

function ns:GetInstanceCache()
    if not instanceCache then
        BuildInstanceCache()
    end
    return instanceCache
end

------------------------------------------------------------------------
-- Loot Scanning
------------------------------------------------------------------------
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

function ns:ScanLootBrowserSlot(specIndex, slotFilter)
    local classID = ns.lootBrowserState.selectedClassID or select(3, UnitClass("player"))
    local specID = ns.lootBrowserState.selectedSpecID
        or GetSpecializationInfoForClassID(classID, specIndex)

    local cacheKey = specID .. "-" .. slotFilter
    if lootBrowserCache[cacheKey] then
        return lootBrowserCache[cacheKey]
    end

    if not instanceCache then
        local built = BuildInstanceCache()
        if not built then
            print("|cff00ff00YippYapp|r |cffff6060Loot Browser:|r Could not load instance data. Try /reload.")
            return {}
        end
    end

    SuppressEJ()
    ns.isLootScanning = true

    local ok, results = pcall(function()
        local r = {}
        ScanSourceType(r, instanceCache.dungeons,    "dungeon",   ns.LOOT_DIFFICULTIES.DUNGEON,    classID, specID, slotFilter)
        ScanSourceType(r, instanceCache.raids,       "raid",      ns.LOOT_DIFFICULTIES.RAID,       classID, specID, slotFilter)
        ScanSourceType(r, instanceCache.worldBosses, "worldboss", ns.LOOT_DIFFICULTIES.WORLD_BOSS, classID, specID, slotFilter)
        return r
    end)

    -- Populate the cache BEFORE unsuppressing. UnsuppressEJ restores
    -- difficulty/slot/loot filters, which fires EJ_DIFFICULTY_UPDATE /
    -- EJ_LOOT_DATA_RECIEVED; our ejFrame handler wipes the cache on those
    -- events unless isLootScanning is still true. Keep the flag set across
    -- the unsuppress so the restore events are ignored.
    --
    -- Never cache an empty result. The prewarm pass fires 5s after login,
    -- before EJ has necessarily populated its loot map — scanning then
    -- returns `{}`. If we cached that, the next open would read the stale
    -- empty entry (the EJ-event invalidation only fires while the browser
    -- is visible), leaving the user with a blank window until they
    -- reselected class/spec to force a cache clear.
    if ok and results and #results > 0 then
        lootBrowserCache[cacheKey] = results
    end

    UnsuppressEJ()
    ns.isLootScanning = false

    if not ok then
        print("|cff00ff00YippYapp|r |cffff6060Loot Browser:|r Scan error: " .. tostring(results))
        return {}
    end

    return results
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

local equipWatcher = CreateFrame("Frame")
equipWatcher:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
equipWatcher:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
equipWatcher:SetScript("OnEvent", function()
    wipe(equippedIlvlCache)
end)

--- Lowest equipped item level among the slots this item could fill.
--- For paired slots (rings, trinkets, weapons) that is the piece you
--- would actually replace, which is the comparison that matters.
function ns:GetEquippedIlvlForItem(itemID)
    if not itemID then return nil end
    local _, _, _, equipLoc = GetItemInfoInstant(itemID)
    local slots = equipLoc and EQUIP_LOC_SLOTS[equipLoc]
    if not slots then return nil end

    local lowest
    for _, slotID in ipairs(slots) do
        local lvl = EquippedIlvl(slotID)
        -- An empty slot is the weakest possible "current" item, so any
        -- drop for it counts as an upgrade.
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

function ns:ClearAllLootBrowserCaches()
    wipe(lootBrowserCache)
    instanceCache = nil
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

local function GetFavoritesTable(create)
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
    local specID = ns.lootBrowserState.selectedSpecID
    if not specID then return nil end
    if not YippYappHelperDB.lootFavorites[charKey][specID] then
        if not create then return nil end
        YippYappHelperDB.lootFavorites[charKey][specID] = {}
    end
    return YippYappHelperDB.lootFavorites[charKey][specID]
end

function ns:IsLootFavorite(itemID)
    local tbl = GetFavoritesTable(false)
    return tbl and tbl[itemID] or false
end

function ns:ToggleLootFavorite(itemID)
    if ns:IsLootFavorite(itemID) then
        local tbl = GetFavoritesTable(false)
        if tbl then tbl[itemID] = nil end
    else
        local tbl = GetFavoritesTable(true)
        if tbl then tbl[itemID] = true end
    end
end

function ns:GetAllFavoriteItemIDs()
    local tbl = GetFavoritesTable(false)
    return tbl or {}
end

function ns:GetFavoritesCount()
    local tbl = GetFavoritesTable(false)
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
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    -- First pass at 5s: EJ has usually populated its initial map by then.
    C_Timer.After(5, function()
        if ns.LootBrowser_DetectSpec then ns:LootBrowser_DetectSpec() end
        local state = ns.lootBrowserState
        if not state.selectedSpecIndex then return end
        -- NoFilter returns every slot in one scan → powers All Slots/Favorites
        -- and is the longest single scan; running it primes the EJ cache for
        -- the per-slot scans that follow.
        ns:ScanLootBrowserSlot(state.selectedSpecIndex, EISFT.NoFilter)
    end)
    -- Second pass at 12s to cover slot-specific cache for the default "Head".
    C_Timer.After(12, function()
        local state = ns.lootBrowserState
        if not state.selectedSpecIndex then return end
        ns:ScanLootBrowserSlot(state.selectedSpecIndex, EISFT.Head)
    end)
end)
