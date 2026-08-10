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
function ns:GetCurrentAffixes()
    local affixes = C_MythicPlus.GetCurrentAffixes()
    if not affixes then return {} end

    local result = {}
    for _, affix in ipairs(affixes) do
        local name, desc, icon = C_ChallengeMode.GetAffixInfo(affix.id)
        if name then
            table.insert(result, { id = affix.id, name = name, desc = desc, icon = icon })
        end
    end
    return result
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
    teleportCache = {}
    local maps = C_ChallengeMode.GetMapTable()
    if maps then
        for _, mapID in ipairs(maps) do
            local name = C_ChallengeMode.GetMapUIInfo(mapID)
            if name and DUNGEON_TELEPORT_BY_NAME[name] then
                teleportCache[mapID] = DUNGEON_TELEPORT_BY_NAME[name]
            end
        end
    end
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
    if ns.AppFrame and ns.AppFrame:IsShown() then
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

local commFrame = CreateFrame("Frame")
commFrame:RegisterEvent("CHAT_MSG_ADDON")
commFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
commFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
commFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
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
                    guildKeystones[shortName] = entry
                elseif shortName ~= UnitName("player") then
                    -- Ignore our own broadcast: PARTY addon messages echo back to the sender.
                    partyKeystones[shortName] = entry
                end
                if ns.RefreshMythicPlus then ns:RefreshMythicPlus() end
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
        C_Timer.After(2, function() ns:BroadcastKeystone() end)
        -- Pull guild keys shortly after login
        if IsInGuild() then
            C_Timer.After(4, function() ns:RequestGuildKeystones() end)
        end
    elseif event == "PLAYER_GUILD_UPDATE" then
        wipe(guildKeystones)
        if IsInGuild() then
            C_Timer.After(2, function() ns:RequestGuildKeystones() end)
        end
    end
end)
