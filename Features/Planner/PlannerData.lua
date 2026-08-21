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
    -- Cyan, matching ns.RECOMMEND.FREE_UPGRADE and the pulsing border
    -- on the gear page. The stripe is the only thing tying a row here
    -- to the cards it is talking about, so it has to be the same cyan
    -- and not merely a nearby one.
    gear   = { label = "Gear",     short = "Gear",    accent = { 0.0,  1.0,  1.0  } }, -- cyan
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
            -- Needed to ask the client what a better run would pay. It
            -- pairs with `level` in GetNextActivitiesIncrease and there
            -- is no other way to identify which reward ladder a slot is
            -- on.
            tierID     = a.activityTierID,
            -- Carried through so a caller can ask the client what this
            -- slot would actually pay out. GetExampleRewardItemHyperlinks
            -- is keyed by activity id and nothing else identifies one.
            id         = a.id,
            threshold  = a.threshold,
            progress   = a.progress or 0,
            level      = a.level or 0,
            unlocked   = (a.progress or 0) >= (a.threshold or 0),
        }
        if entry.unlocked then
            -- What this slot would pay, resolved once, here.
            --
            -- The dashboard was asking the client for this itself, so
            -- two places did the same three-call dance and could
            -- disagree. It belongs with the rest of the slot.
            --
            -- The example link is only ever read for its item LEVEL:
            -- the item itself is chosen when you claim, so anything
            -- that showed a specific item would be promising a drop the
            -- vault has not picked.
            if a.id and C_WeeklyRewards.GetExampleRewardItemHyperlinks then
                local okL, link =
                    pcall(C_WeeklyRewards.GetExampleRewardItemHyperlinks, a.id)
                if okL and type(link) == "string" and link ~= ""
                    and C_Item and C_Item.GetDetailedItemLevelInfo then
                    -- Assigned first: GetDetailedItemLevelInfo returns
                    -- three values and a call used as an argument spills
                    -- all of them, handing tonumber a boolean base.
                    local effective = C_Item.GetDetailedItemLevelInfo(link)
                    entry.rewardIlvl = tonumber(effective)
                end
            end
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
--
-- Above all of them: item level the character already owns. Everything
-- else on this panel is a proposal to go and spend an evening earning
-- something; this one is a walk to a vendor for gear that has already
-- been paid for, and it is the only row that can be finished during the
-- loading screen before the raid.
local PRI_FREE_UPGRADE  = 0
local PRI_UNLOCK_NEXT   = 1
local PRI_UNLOCK_UPPER  = 2
local PRI_IMPROVE       = 3
local PRI_CREST_CAP     = 4
local PRI_FINAL_FILLED  = 5
local PRI_FILLER        = 6
-- Below everything: a real thing to do that will not improve your gear.
local PRI_NOT_AN_UPGRADE = 9

--- How many real actions the plan wants before it starts padding.
---
--- Some entries are not actions at all -- "652 of 750 Field Accolades",
--- "34 Hero crests left" -- they are counters that move on their own
--- while you do the things above them. On a busy week they push a real
--- suggestion off the bottom of a six-row panel to say something the
--- player cannot act on, so they are marked `filler` and only appear
--- when the list is genuinely short. Nothing to do is worth saying;
--- saying it over the top of something to do is not.
local MIN_PLAN_ROWS = 3

--- What the character is actually wearing.
---
--- The EQUIPPED average, not the overall. Overall counts what is sitting
--- in the bags, and a bank full of alt gear would quietly make every
--- reward look worthless.
local function equippedIlvl()
    if not GetAverageItemLevel then return nil end
    local ok, _, equipped = pcall(GetAverageItemLevel)
    return ok and tonumber(equipped) or nil
end

--- Rank an item by whether its reward would actually be worn.
---
--- A suggestion that cannot improve your gear is not urgent, however
--- much of the vault it fills -- and the plan had no idea, so it would
--- cheerfully rank "run a tier 2 delve for a 282" above everything on a
--- character in 300s. It still gets listed, because filling the slot is
--- worth something and a week can turn, but it goes to the bottom and
--- says why.
---
--- A margin, not a straight comparison: a reward one or two levels above
--- what you wear is a sidegrade in practice, not a reason to run
--- anything. Below that it is honestly not worth the evening.
local UPGRADE_MARGIN = 3

local function rankByReward(item, rewardIlvl)
    if not (item and rewardIlvl and rewardIlvl > 0) then return item end
    local worn = equippedIlvl()
    -- No answer from the client is not the same as "not an upgrade".
    -- Saying nothing beats demoting everything on a character whose
    -- item level has not resolved yet.
    if not (worn and worn > 0) then return item end

    if rewardIlvl <= worn + UPGRADE_MARGIN then
        item.priority = PRI_NOT_AN_UPGRADE
        item.detail = ("Pays %d · you wear %d, so it fills but does not upgrade")
            :format(rewardIlvl, math.floor(worn))
        item.notUpgrade = true
    end
    return item
end

-- Exposed for Tools/loadcheck.py. The interesting half of this is the
-- case the fixture cannot reach through BuildPlan -- a reward at or
-- below what the character wears -- and a comparison that never fires
-- looks exactly like one that works.
P._RankByReward = function(item, ilvl) return rankByReward(item, ilvl) end

local function describeNextMPlus(track)
    if not track or not track.next then return nil end
    local n = track.next
    local need = math.max(n.threshold - n.progress, 1)
    local runWord = need == 1 and "dungeon" or "dungeons"
    local keyHint
    if n.level and n.level > 0 then
        keyHint = string.format("keep the key at +%d or higher", n.level)
    else
        keyHint = "any +2 or higher counts"
    end
    -- Title is the action, detail is what it buys.
    --
    -- These used to be one line joined by a guillemet -- "2 more M+ runs
    -- » unlocks vault slot 1" -- with the qualifier stranded underneath
    -- in brackets. That reads as a formula rather than as advice, and it
    -- spent the loudest line on a payoff nobody has to be sold on. The
    -- panel is called Worth Doing Tonight; the bold line should be the
    -- doing.
    return {
        category = "mplus",
        title    = string.format("Run %d more Mythic+ %s", need, runWord),
        detail   = string.format("Unlocks vault slot %d · %s", n.index, keyHint),
        priority = (n.index == 1) and PRI_UNLOCK_NEXT or PRI_UNLOCK_UPPER,
        progress = { have = n.progress, target = n.threshold },
    }
end

--- "Your vault reward is 289; a +12 would make it 302."
---
--- Unlocking a slot and improving what is already in it are different
--- jobs, and the plan only ever spoke about the first. Once the slot is
--- yours the count stops mattering and the LEVEL starts -- which is the
--- single most useful thing anyone can be told about a vault they have
--- already half filled, and nothing on this page said it.
---
--- The client answers this itself rather than us modelling the reward
--- ladder: GetNextActivitiesIncrease takes the tier and level a slot
--- qualified at and returns the next rung and what it pays.
---
--- Deliberately reads the LOWEST earned slot. That is the one dragging
--- the reward down, and improving it is the cheapest gain available.
local function describeVaultUpgrade(track, kind)
    if not (track and track.all) then return nil end
    if not (C_WeeklyRewards and C_WeeklyRewards.GetNextActivitiesIncrease) then
        return nil
    end

    local worst
    for _, slot in ipairs(track.all) do
        if slot.unlocked and slot.tierID
            and (not worst or (slot.level or 0) < (worst.level or 0)) then
            worst = slot
        end
    end
    if not worst then return nil end

    -- Plumber notes this returns false for Delves, so a nil answer is
    -- expected rather than exceptional -- say nothing rather than guess
    -- at a reward ladder we would then have to maintain per season.
    local ok, hasData, _, nextLevel, nextItemLevel =
        pcall(C_WeeklyRewards.GetNextActivitiesIncrease, worst.tierID, worst.level)
    if not (ok and hasData and nextLevel and nextItemLevel) then return nil end
    if nextItemLevel <= 0 then return nil end

    -- The rung above pays the same as the rung you are on.
    --
    -- This rendered as "+10 » reward 318 to 318" -- a suggestion to go
    -- and run something in order to change nothing. It happens at the
    -- top of a ladder, where the next level up is still inside the same
    -- reward bracket, and it is the plan at its least trustworthy: the
    -- one row anyone can check against the vault in front of them.
    if nextItemLevel <= (worst.rewardIlvl or 0) then return nil end

    -- `nextLevel` counts in the same units as `level` did, and zero is a
    -- real answer rather than a missing one: for Mythic+ it means Mythic
    -- difficulty with no keystone, which is the rung above Heroic and
    -- below +2. Printed raw it read "Run a +0", which is not a thing.
    -- Blizzard's own tooltip says "Complete a dungeon on Mythic
    -- difficulty" here, and that is what it is.
    local action
    if kind == "mplus" then
        action = nextLevel > 0 and ("Run a +%d"):format(nextLevel)
            or "Run a Mythic dungeon"
    elseif kind == "world" then
        action = ("Run a tier %d delve"):format(nextLevel)
    else
        local name = GetDifficultyInfo and GetDifficultyInfo(nextLevel)
        action = name and ("Kill a boss on %s"):format(name)
            or ("Kill a boss on difficulty %d"):format(nextLevel)
    end

    -- Ranked by what it pays, not only by what it fills. Improving a
    -- reward you would never equip is the clearest case of a suggestion
    -- that looks urgent and is not.
    return rankByReward({
        category = kind,
        -- "to", not an arrow. U+2192 is not in the client's font and
        -- renders as an empty box. Anything outside Latin-1 has to be
        -- checked in game, and a word always works.
        title    = ("%s to upgrade the vault"):format(action),
        detail   = ("Slot %d's reward goes from %d to %d"):format(
            worst.index or 1, worst.rewardIlvl or 0, nextItemLevel),
        priority = PRI_IMPROVE,
    }, nextItemLevel)
end

--- Field Accolades toward a targeted piece.
---
--- The threshold is not something the client will tell us -- currency
--- costs live on a vendor, not in an API -- so it is written down, and
--- written down with its source: method.gg's Midnight Season 2 gearing
--- guide, which gives 750 for a targeted slot off the Veteran track.
--- Recorded the same way as the crest ids, and wrong the same way if a
--- patch retunes it, so it is worth re-checking each season.
---
--- The currency is found by name rather than by id, because a guessed
--- id reads zero rather than erroring and would turn this into a
--- confident lie. Not found means this says nothing at all.
local ACCOLADE_CURRENCY = "Field Accolade"
local ACCOLADE_TARGET_COST = 750

local function describeAccolades()
    if not ns.FindCurrencyByName then return nil end
    local entry = ns:FindCurrencyByName(ACCOLADE_CURRENCY)
    if not entry then return nil end

    local have = tonumber(entry.quantity) or 0
    if have >= ACCOLADE_TARGET_COST then
        -- Affordable is an action: the currency is sitting there and
        -- spending it tonight is a real piece of gear.
        return {
            category = "crests",
            title    = ("Spend %d Field Accolades"):format(ACCOLADE_TARGET_COST),
            detail   = "Buys a targeted piece · aim it at your worst slot",
            priority = PRI_UNLOCK_NEXT,
            progress = { have = have, target = ACCOLADE_TARGET_COST },
        }
    end
    -- Short of the cost it is a savings balance, not a plan. It fills
    -- itself while you do everything above it, and there is no evening
    -- in which "98 more Field Accolades" is the thing to go and do.
    return {
        category = "crests",
        title    = ("Field Accolades: %d of %d"):format(have, ACCOLADE_TARGET_COST),
        detail   = ("%d more buys a targeted piece"):format(ACCOLADE_TARGET_COST - have),
        priority = PRI_CREST_CAP,
        filler   = true,
        progress = { have = have, target = ACCOLADE_TARGET_COST },
    }
end

local function describeNextRaid(track)
    if not track or not track.next then return nil end
    local n = track.next
    local need = math.max(n.threshold - n.progress, 1)
    local bossWord = need == 1 and "boss" or "bosses"
    return {
        category = "raid",
        title    = string.format("Kill %d more raid %s", need, bossWord),
        detail   = string.format(
            "Unlocks vault slot %d · Normal or higher for Hero loot", n.index),
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
        title    = string.format("Run %d more tier 8+ %s", need, delveWord),
        detail   = string.format(
            "Unlocks vault slot %d · bountiful delves pay extra", n.index),
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
        title    = string.format("Fill %d more vault %s",
            need, need == 1 and "slot" or "slots"),
        detail   = "Unlocks a Bonus Roll · any row counts, and it banks",
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
                detail   = string.format("Weekly cap %d · earned %d so far",
                    cap, cap - remaining),
                priority = PRI_CREST_CAP,
                -- A budget line, not an instruction. The crests come
                -- out of the content already listed above, and "cap
                -- this week's crests" has its own checklist row -- so
                -- on a busy week this is the third place one fact is
                -- printed, and the only one of the three that is not
                -- something to go and do.
                filler   = true,
                progress = { have = cap - remaining, target = cap },
            }
        end
    end
    return nil
end

--- Ranks the character already owns and has not collected.
---
--- A slot remembers the highest item level it has ever held, and
--- upgrades up to there cost no crests. Which means gear can sit one
--- vendor visit below where it is entitled to be for weeks, silently,
--- because nothing about the character looks wrong -- and the panel that
--- exists to say what is worth doing tonight was the obvious place for
--- it to have been said all along.
---
--- Counts SLOTS and RANKS separately. Slots is how many pieces to hand
--- over and ranks is what comes back, and they are rarely the same
--- number: one slot four ranks below its line is a bigger evening than
--- four slots one rank below theirs.
---
--- nil when there is nothing waiting, which on a character who visits a
--- vendor regularly is most of the time. A row that says "no free
--- upgrades" is a row spent on the absence of news.
local function describeFreeUpgrades()
    if not (ns.SLOT_IDS and ns.CanUpgradeItem and ns.GetFreeUpgradeIlvl) then
        return nil
    end

    local slots, ranks, names = 0, 0, {}
    for _, si in ipairs(ns.SLOT_IDS) do
        local canUpgrade, up = ns:CanUpgradeItem(si.slot)
        local levels = canUpgrade and up and up.track and ns.GEAR_TRACKS[up.track]
        if levels then
            local mark = ns:GetFreeUpgradeIlvl(si.slot) or 0
            local n = 0
            if mark > (up.currIlvl or 0) then
                for r = (up.currUpgrade or 0) + 1, (up.maxUpgrade or 0) do
                    if levels[r] and levels[r] <= mark then n = n + 1 else break end
                end
            end
            if n > 0 then
                slots = slots + 1
                ranks = ranks + n
                names[#names + 1] = si.name
            end
        end
    end
    if slots == 0 then return nil end

    -- Named while naming them still fits. Three slot names is a useful
    -- sentence and six is a list nobody reads to the end of, so past
    -- two it counts the rest instead.
    local where
    if #names == 1 then
        where = names[1]
    elseif #names == 2 then
        where = names[1] .. " and " .. names[2]
    else
        where = ("%s, %s and %d more"):format(names[1], names[2], #names - 2)
    end

    return {
        category = "gear",
        title    = slots == 1
            and ("Collect a free upgrade on your " .. names[1])
            or ("Collect %d free gear upgrades"):format(slots),
        -- The title carries the single slot's name already, so
        -- repeating it in the detail would spend the second line
        -- saying the first line again.
        detail   = slots == 1
            and ("%d %s at the upgrade vendor, no crests"):format(
                ranks, ranks == 1 and "rank" or "ranks")
            or ("%s · %d ranks, no crests"):format(where, ranks),
        priority = PRI_FREE_UPGRADE,
        -- Not filler. Filler is a counter that moves on its own while
        -- you do the rows above it, and this one moves only when the
        -- player goes and does it.
        extra    = { slots = slots, ranks = ranks, where = where },
    }
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

    -- Two piles, not one list.
    --
    -- `actions` are things to go and do; `filler` are counters that
    -- move on their own. Sorting them together by priority put a
    -- savings balance in the middle of an evening's work, because
    -- priority was answering "how urgent" when the question here is
    -- "is this even a task".
    local actions, filler = {}, {}
    local add = function(item)
        if not item then return end
        local into = item.filler and filler or actions
        into[#into + 1] = item
    end

    add(describeFreeUpgrades())
    add(describeBonusRoll(vault))
    add(describeNextMPlus(vault and vault.mplus))
    add(describeNextRaid(vault and vault.raid))
    add(describeNextDelve(vault and vault.world))
    add(describeVaultUpgrade(vault and vault.mplus, "mplus"))
    add(describeVaultUpgrade(vault and vault.world, "world"))
    add(describeAccolades())
    add(describeCrestCap())

    local byPriority = function(a, b) return (a.priority or 99) < (b.priority or 99) end
    table.sort(actions, byPriority)
    table.sort(filler, byPriority)

    for _, item in ipairs(actions) do items[#items + 1] = item end
    -- Padding only, and only up to the floor. A thin week is exactly
    -- when a progress counter earns its row; a full one is exactly when
    -- it does not.
    for _, item in ipairs(filler) do
        if #items >= MIN_PLAN_ROWS then break end
        items[#items + 1] = item
    end

    -- What was held back, for anything that wants to explain the
    -- panel rather than render it -- and for Tools/loadcheck.py, which
    -- otherwise cannot tell "correctly demoted" from "never built".
    plan.deferred = filler

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

    return plan
end
