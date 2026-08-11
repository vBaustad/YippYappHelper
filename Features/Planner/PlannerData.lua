local _, ns = ...

------------------------------------------------------------
-- Activity Planner
-- Looks at the player's vault progress, weekly crest headroom, and
-- current profile tier to produce a prioritized "what to do tonight"
-- list. The dashboard widget renders whatever this returns.
------------------------------------------------------------

ns.Planner = ns.Planner or {}
local P = ns.Planner

-- Blizzard's weekly-rewards enums. Guard against API renames / client
-- variants by falling back to hard-coded integer values that have been
-- stable since Shadowlands.
local ACTIVITY_TYPE_MPLUS = (Enum and Enum.WeeklyRewardChestThresholdType
    and Enum.WeeklyRewardChestThresholdType.Activities) or 1
local ACTIVITY_TYPE_WORLD = (Enum and Enum.WeeklyRewardChestThresholdType
    and Enum.WeeklyRewardChestThresholdType.World) or 2
local ACTIVITY_TYPE_RAID  = (Enum and Enum.WeeklyRewardChestThresholdType
    and Enum.WeeklyRewardChestThresholdType.Raid) or 3

-- Human-readable category metadata. `accent` drives the row's left
-- stripe color on the dashboard.
local CATEGORIES = {
    mplus  = { label = "Mythic+",  short = "M+",      accent = { 0.0,  0.83, 1.0  } }, -- cyan
    raid   = { label = "Raid",     short = "Raid",    accent = { 0.85, 0.40, 0.95 } }, -- violet
    delves = { label = "Delves",   short = "Delves",  accent = { 0.35, 0.85, 0.40 } }, -- green
    crests = { label = "Crests",   short = "Crests",  accent = { 1.0,  0.60, 0.20 } }, -- amber
}
P.CATEGORIES = CATEGORIES

------------------------------------------------------------
-- Vault snapshot — { mplus={progress,threshold,level}, ... }
-- Returns nil if the API isn't available (rare / classic split).
------------------------------------------------------------
local function snapshotVaultTrack(activityType)
    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then return nil end
    local ok, acts = pcall(C_WeeklyRewards.GetActivities, activityType)
    if not ok or not acts then return nil end
    local out = { filled = 0, total = 0, next = nil, all = {} }
    for _, a in ipairs(acts) do
        out.total = out.total + 1
        local entry = {
            index      = a.index,
            threshold  = a.threshold,
            progress   = a.progress or 0,
            level      = a.level or 0,
            unlocked   = (a.progress or 0) >= (a.threshold or 0),
        }
        if entry.unlocked then
            out.filled = out.filled + 1
        elseif not out.next then
            -- First not-yet-unlocked slot — this is what to target.
            out.next = entry
        end
        out.all[#out.all + 1] = entry
    end
    return out
end

function P:GetVaultSnapshot()
    return {
        mplus  = snapshotVaultTrack(ACTIVITY_TYPE_MPLUS),
        raid   = snapshotVaultTrack(ACTIVITY_TYPE_RAID),
        world  = snapshotVaultTrack(ACTIVITY_TYPE_WORLD),
    }
end

------------------------------------------------------------
-- Crest weekly headroom — how many more crests the player can earn
-- this week before hitting the weekly-increment cap.
------------------------------------------------------------
local function crestWeeklyRemaining(trackName)
    if not ns.GetCrestWeeklyInfo then return 0, 0 end
    local info = ns:GetCrestWeeklyInfo(trackName)
    if not info then return 0, 0 end
    local earned = info.earnedThisWeek or 0
    local cap    = info.weeklyMax or 0
    if cap <= 0 then return 0, 0 end
    return math.max(cap - earned, 0), cap
end

------------------------------------------------------------
-- Plan builder — produces a list of `{ category, title, detail,
-- priority, progress = { have, target } }`. Caller renders.
------------------------------------------------------------

-- Lower priority = shown first. Unlock-vault actions outrank crest
-- farming, which outranks miscellaneous nudges.
local PRI_UNLOCK_NEXT   = 1
local PRI_UNLOCK_UPPER  = 2
local PRI_CREST_CAP     = 3
local PRI_FINAL_FILLED  = 4
local PRI_FILLER        = 5

local function describeNextMPlus(track)
    if not track or not track.next then return nil end
    local n = track.next
    local need = math.max(n.threshold - n.progress, 1)
    local runWord = need == 1 and "run" or "runs"
    local keyHint
    if n.level and n.level > 0 then
        keyHint = string.format("(keeps key level ≥ %d)", n.level)
    else
        keyHint = "(any +2 or higher)"
    end
    return {
        category = "mplus",
        title    = string.format("%d more M+ %s » unlocks vault slot %d",
            need, runWord, n.index),
        detail   = keyHint,
        priority = (n.index == 1) and PRI_UNLOCK_NEXT or PRI_UNLOCK_UPPER,
        progress = { have = n.progress, target = n.threshold },
    }
end

local function describeNextRaid(track)
    if not track or not track.next then return nil end
    local n = track.next
    local need = math.max(n.threshold - n.progress, 1)
    local bossWord = need == 1 and "boss" or "bosses"
    return {
        category = "raid",
        title    = string.format("%d more raid %s » unlocks vault slot %d",
            need, bossWord, n.index),
        detail   = "Any difficulty counts (Normal+ for Hero loot)",
        priority = (n.index == 1) and PRI_UNLOCK_NEXT or PRI_UNLOCK_UPPER,
        progress = { have = n.progress, target = n.threshold },
    }
end

local function describeNextDelve(track)
    if not track or not track.next then return nil end
    local n = track.next
    local need = math.max(n.threshold - n.progress, 1)
    local delveWord = need == 1 and "delve" or "delves"
    return {
        category = "delves",
        title    = string.format("%d more T8+ %s » unlocks vault slot %d",
            need, delveWord, n.index),
        detail   = "Bountiful delves award extra rewards",
        priority = (n.index == 1) and PRI_UNLOCK_NEXT or PRI_UNLOCK_UPPER,
        progress = { have = n.progress, target = n.threshold },
    }
end

------------------------------------------------------------
-- Bonus Roll threshold (new in Season 2).
--
-- Nebulous Voidcores are a Great Vault reward option from week 1, but
-- only once at least three slots are filled — across ALL rows combined,
-- not three in one row. That threshold is the single most valuable
-- milestone of the week for most players, because a banked Bonus Roll
-- can later be spent on a much higher difficulty than the content that
-- filled the slots.
------------------------------------------------------------
local BONUS_ROLL_SLOTS = 3

local function countFilledSlots(vault)
    if not vault then return 0 end
    local filled = 0
    for _, key in ipairs({ "mplus", "raid", "world" }) do
        local track = vault[key]
        if track then filled = filled + (track.filled or 0) end
    end
    return filled
end

local function describeBonusRoll(vault)
    -- Nothing to chase before Voidcore rolls exist. The planner lists
    -- actionable work, so this drops out entirely rather than showing a
    -- row the player cannot act on.
    if ns.SEASON_VOIDCORE_START and time() < ns.SEASON_VOIDCORE_START then
        return nil
    end

    local filled = countFilledSlots(vault)
    if filled >= BONUS_ROLL_SLOTS then return nil end
    local need = BONUS_ROLL_SLOTS - filled
    return {
        category = "crests",
        title    = string.format("%d more vault %s » unlocks a Bonus Roll",
            need, need == 1 and "slot" or "slots"),
        detail   = "Any row counts. Bonus Rolls can be banked for harder content",
        priority = PRI_UNLOCK_NEXT,
        progress = { have = filled, target = BONUS_ROLL_SLOTS },
    }
end

-- Pick the weekly crest headroom for the track the player currently
-- wants most (driven by their profile's "precious" crest list).
local function describeCrestCap()
    local profile = ns.GetCurrentProfile and ns:GetCurrentProfile() or nil
    if not profile then return nil end
    local trackOrder = profile.preciousCrests or { "Hero", "Champion" }
    for _, track in ipairs(trackOrder) do
        local remaining, cap = crestWeeklyRemaining(track)
        if cap > 0 and remaining > 0 then
            return {
                category = "crests",
                title    = string.format("%d %s crests left this week",
                    remaining, track),
                detail   = string.format("Weekly cap %d · current pace adds up", cap),
                priority = PRI_CREST_CAP,
                progress = { have = cap - remaining, target = cap },
            }
        end
    end
    return nil
end

local function vaultFullyUnlocked(v)
    if not v then return false end
    local function done(t) return t and t.total > 0 and t.filled >= t.total end
    return done(v.mplus) and done(v.raid) and done(v.world)
end

function P:BuildPlan()
    local vault = self:GetVaultSnapshot()
    local plan = {
        vault  = vault,
        items  = {},
        resetDays = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
                     and math.floor((C_DateAndTime.GetSecondsUntilWeeklyReset() or 0) / 86400 + 0.5)
                     or nil,
    }

    local items = plan.items
    local add = function(item) if item then items[#items + 1] = item end end

    add(describeBonusRoll(vault))
    add(describeNextMPlus(vault and vault.mplus))
    add(describeNextRaid(vault and vault.raid))
    add(describeNextDelve(vault and vault.world))
    add(describeCrestCap())

    if #items == 0 then
        -- Completely drained state — still give the user something.
        if vaultFullyUnlocked(vault) then
            items[#items + 1] = {
                category = "crests",
                title    = "Vault fully unlocked",
                detail   = "Free time — push keys or farm lower crests",
                priority = PRI_FINAL_FILLED,
            }
        else
            items[#items + 1] = {
                category = "crests",
                title    = "No pressing activities",
                detail   = "Crest caps, vault progress, upgrades all comfortable",
                priority = PRI_FILLER,
            }
        end
    end

    table.sort(items, function(a, b) return (a.priority or 99) < (b.priority or 99) end)
    return plan
end
