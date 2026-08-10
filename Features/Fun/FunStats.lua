local _, ns = ...

------------------------------------------------------------
-- Fun stats.
--
-- Counters for things the game does not track. Nothing here affects
-- play; it exists because "how many times have I jumped on this
-- character" is a question people enjoy having answered.
--
-- Stored per character under YippYappHelperDB.funStats, because the fun
-- is in the individual character's number, not an account total.
--
-- Event-driven only. Nothing polls, nothing runs OnUpdate: a stats toy
-- has no business costing frames.
------------------------------------------------------------

ns.FunStats = ns.FunStats or {}
local FS = ns.FunStats

local function db()
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.funStats = YippYappHelperDB.funStats or {}
    local key = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    YippYappHelperDB.funStats[key] = YippYappHelperDB.funStats[key] or {}
    return YippYappHelperDB.funStats[key]
end

local listeners = {}

--- Fires whenever a counter changes, so displays can update as it happens
--- rather than waiting for whatever refresh cycle they sit in.
function FS:OnChanged(cb) table.insert(listeners, cb) end

local function bump(stat, by)
    local d = db()
    d[stat] = (d[stat] or 0) + (by or 1)
    for _, cb in ipairs(listeners) do pcall(cb, stat, d[stat]) end
end

--- Public counter, for things tracked outside this file.
function FS:Bump(stat, by) bump(stat, by) end

function FS:Get(stat) return db()[stat] or 0 end
function FS:All() return db() end

--- Ordered for display. Add entries here and to the tracking below.
FS.STATS = {
    { key = "jumps", label = "Jumps", icon = "Interface\\Icons\\Ability_Rogue_Sprint" },
}

------------------------------------------------------------
-- Tracking
------------------------------------------------------------

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")

--- Counts a finished dungeon or raid boss as a "guild run" when at least
--- one other group member shares your guild. The advisor uses this to
--- decide whether social remarks are fair: someone who plays with their
--- guild gets ribbed differently from someone who does not, and someone
--- with no guild is never asked about it at all.
local function countedWithGuild()
    if not IsInGuild() or not IsInGroup() then return false end
    local myGuild = GetGuildInfo("player")
    if not myGuild then return false end
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, GetNumGroupMembers() do
        local unit = prefix .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            if GetGuildInfo(unit) == myGuild then return true end
        end
    end
    return false
end

watcher:RegisterEvent("CHALLENGE_MODE_COMPLETED")
watcher:RegisterEvent("ENCOUNTER_END")

watcher:SetScript("OnEvent", function(_, event, ...)
    if event == "CHALLENGE_MODE_COMPLETED" then
        if countedWithGuild() then bump("guildRuns") end
        return
    elseif event == "ENCOUNTER_END" then
        local _, _, _, _, success = ...
        if success == 1 and countedWithGuild() then bump("guildRuns") end
        return
    end
    if event ~= "PLAYER_LOGIN" then return end
    -- JumpOrAscendStart is the global the jump keybind calls, so a secure
    -- hook catches every jump without polling IsFalling every frame.
    if type(JumpOrAscendStart) == "function" then
        hooksecurefunc("JumpOrAscendStart", function()
            -- Holding the key on a flying mount calls this repeatedly to
            -- ascend, which would inflate the count into nonsense. Only
            -- record it when we are actually jumping off the ground.
            if not IsFalling() and not IsFlying() then bump("jumps") end
        end)
    end
end)

------------------------------------------------------------
-- Chat output
------------------------------------------------------------

function FS:Print()
    print("|cffb885ffYippYapp|r fun stats for "
        .. (UnitName("player") or "you") .. ":")
    for _, s in ipairs(FS.STATS) do
        print(("  %-22s |cffffffff%d|r"):format(s.label, FS:Get(s.key)))
    end
end

function FS:Reset()
    local d = db()
    for k in pairs(d) do d[k] = nil end
    for _, cb in ipairs(listeners) do pcall(cb, nil, 0) end
    print("|cffb885ffYippYapp|r fun stats reset.")
end
