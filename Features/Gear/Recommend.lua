local _, ns = ...

------------------------------------------------------------
-- Recommendation labels and colors
------------------------------------------------------------
ns.RECOMMEND = {
    FREE_UPGRADE      = { label = "Free upgrade!",           color = "ff00ffff" }, -- cyan
    UPGRADE_NOW       = { label = "Upgrade now",             color = "ff00ff00" }, -- green
    UPGRADE_LATER     = { label = "Upgrade later",           color = "ffffff00" }, -- yellow
    HOLD_CRESTS       = { label = "Hold crests",             color = "ffff8800" }, -- orange
    SAVE_FOR_DROP     = { label = "Wait for a drop",         color = "ffff8800" }, -- orange
    CREST_CAPPED      = { label = "Capped this week",        color = "ffff4444" }, -- red-ish
    SAFE_TEMP         = { label = "Temporary upgrade",       color = "ff88bbff" }, -- light blue
    BAD_INVESTMENT    = { label = "Bad investment",           color = "ffff0000" }, -- red
    CRAFT_INSTEAD     = { label = "Craft instead",            color = "ffcc66ff" }, -- purple
    USE_LOWER_TRACK   = { label = "Use cheaper crests",        color = "ff66bbff" }, -- light blue
    WASTED_CREST      = { label = "Wasteful crest spend",      color = "ffff3333" }, -- red
    WAIT_BETTER       = { label = "Wait for better source",   color = "ffaaaaaa" }, -- grey
    MAXED             = { label = "Max rank",                 color = "ff888888" }, -- dark grey
    NO_ITEM           = { label = "",                         color = "ff555555" },
}

------------------------------------------------------------
-- Crest cost system
------------------------------------------------------------
-- Base cost per upgrade
ns.BASE_CREST_COST = 20
-- Discounted cost (high-watermark achievement)
ns.DISCOUNTED_CREST_COST = 10

-- Account-wide achievement IDs for the 50% crest discount ("outgrowing").
-- When unlocked, upgrades of that crest type cost 10 instead of 20.
--
-- Season 2 (Mistcrests). These replace the Season 1 "of the Dawn" set --
-- 61809 / 42767-42770 -- which were still in place after the season
-- rolled. That is not a harmless staleness: the ids belong to
-- achievements a returning player is likely to HAVE, so the discount
-- read as earned on tracks where it is not, and every cost calculation
-- downstream halved. It is why 80 Champion crests were reported as
-- eight upgrades rather than four.
--
-- The numbering is not contiguous -- Hero skips 62413 and Myth skips
-- 62415 -- so these cannot be derived from the first id and have to be
-- recorded. Verify against wowhead.com/achievement=<id> when the season
-- rolls again.
ns.DISCOUNT_ACHIEVEMENTS = {
    Adventurer = 62410, -- Adventurer of the Mist
    Veteran    = 62411, -- Veteran of the Mist
    Champion   = 62412, -- Champion of the Mist
    Hero       = 62414, -- Hero of the Mist
    Myth       = 62416, -- Myth of the Mist
}

--- What the game calls the "outgrown" achievement for a track.
---
--- Written once because it was written twice and both copies went stale
--- at the season roll: the ids above were updated to Season 2 while the
--- advisor and the /yh discounts dump both kept printing "of the Dawn",
--- so the addon named a Season 1 achievement while checking a Season 2
--- one. A player looking up the name it gave them found the wrong
--- achievement, or none.
ns.DISCOUNT_ACHIEVEMENT_SUFFIX = "of the Mist"

function ns:GetDiscountAchievementName(track)
    return track .. " " .. ns.DISCOUNT_ACHIEVEMENT_SUFFIX
end

-- Cache achievement status (checked once per session)
local discountCache = {}

function ns:HasDiscountAchievement(crestTrack)
    if discountCache[crestTrack] ~= nil then
        return discountCache[crestTrack]
    end

    local achieveID = ns.DISCOUNT_ACHIEVEMENTS[crestTrack]
    if achieveID then
        local ok, _, _, _, completed = pcall(GetAchievementInfo, achieveID)
        if ok and completed then
            discountCache[crestTrack] = true
            return true
        end
    end

    discountCache[crestTrack] = false
    return false
end

-- Clear cache (call on login/reload if needed)
function ns:ClearDiscountCache()
    wipe(discountCache)
end

function ns:GetCrestCost(crestTrack)
    -- Manual override first (user can toggle via /yyh discount)
    local db = YippYappHelperDB or {}
    local discounts = db.discounts or {}

    if discounts[crestTrack] then
        return ns.DISCOUNTED_CREST_COST
    end

    -- Check account-wide achievement
    if ns:HasDiscountAchievement(crestTrack) then
        return ns.DISCOUNTED_CREST_COST
    end

    return ns.BASE_CREST_COST
end

-- What's the highest track that content drops for the player?
-- Returns: farmableTrack, farmableRankInItemTrack
-- Determines from M+ key level and raid tier what track content provides,
-- then compares against the item's track.
function ns:GetFarmableInfo(itemTrack)
    local profile = ns:GetCurrentProfile()

    -- Determine the highest track from M+ end-of-dungeon drops
    local mplusIlvl = 0
    for _, entry in ipairs(ns.DUNGEON_LOOT) do
        local keyNum = tonumber(entry.key:match("M(%d+)"))
        if keyNum and keyNum <= profile.maxKeyLevel then
            if entry.loot > mplusIlvl then mplusIlvl = entry.loot end
        end
    end

    -- Map M+ ilvl to a track using the LOWEST match (not highest)
    -- 259 = Hero 1/6 (not Champ 5/6), 272 = Myth 1/6 (not Hero 5/6)
    local mplusTrack = nil
    if mplusIlvl > 0 then
        for i = #ns.TRACK_ORDER, 1, -1 do
            local t = ns.TRACK_ORDER[i]
            local levels = ns.GEAR_TRACKS[t]
            if mplusIlvl >= levels[1] then
                mplusTrack = t
                break
            end
        end
    end

    -- Raid tier directly maps to a track
    local raidTrack = ns.RAID_TRACKS[profile.raidTier]

    -- Pick the higher of the two
    local farmTrack = nil
    local mplusRank = mplusTrack and ns.TRACK_RANK[mplusTrack] or 0
    local raidRank = raidTrack and ns.TRACK_RANK[raidTrack] or 0
    if mplusRank >= raidRank then
        farmTrack = mplusTrack
    else
        farmTrack = raidTrack
    end

    if not farmTrack then
        return nil, 0
    end

    local itemTrackRank = ns.TRACK_RANK[itemTrack] or 0
    local farmTrackRank = ns.TRACK_RANK[farmTrack] or 0

    if farmTrackRank > itemTrackRank then
        -- Content drops a higher track — item's track is fully replaceable
        local levels = ns.GEAR_TRACKS[itemTrack]
        return farmTrack, levels and #levels or 6
    elseif farmTrackRank == itemTrackRank then
        -- Same track — find what rank M+ drops at within this track.
        -- Uses end-of-dungeon loot only: raid is too RNG per-slot
        -- (various bosses drop various ranks, only endbosses guarantee
        -- 6/6) so we don't tell the player to wait on raid drops in
        -- the same track. Previously we returned (farmTrack, 6) here
        -- which made Myth 2/6 incorrectly report "Myth 6/6 drops from
        -- Mythic raid — save crests." Returning nil drops Rule 4's
        -- same-track save-for-drop and hands the item to the slot-
        -- priority upgrade rules, which is what the player wants.
        local levels = ns.GEAR_TRACKS[itemTrack]
        if levels and mplusIlvl > 0 then
            for r = #levels, 1, -1 do
                if levels[r] <= mplusIlvl then
                    return farmTrack, r
                end
            end
        end
        return nil, 0
    end

    -- Content drops a lower track — not relevant
    return nil, 0
end

-- Is the player capped on earning this crest type?
-- Checks both weekly cap (Hero/Myth) and season cumulative cap (Champion etc).
function ns:IsCrestCapped(crestTrack)
    local weeklyInfo = ns:GetCrestWeeklyInfo(crestTrack)

    -- Weekly cap check (Hero/Myth have maxWeeklyQuantity > 0)
    if weeklyInfo and weeklyInfo.weeklyMax > 0 and weeklyInfo.weeklyRemaining <= 0 then
        return true
    end

    -- Season cumulative cap check (Champion etc use totalEarned vs maxQuantity)
    for _, crest in ipairs(ns.CRESTS) do
        if crest.track == crestTrack then
            local cInfo = C_CurrencyInfo.GetCurrencyInfo(crest.id)
            if cInfo then
                local seasonCap = cInfo.useTotalEarnedForMaxQty and cInfo.maxQuantity or 0
                if seasonCap > 0 then
                    local earnable = math.max(seasonCap - (cInfo.totalEarned or 0), 0)
                    if earnable <= 0 then
                        return true
                    end
                end
            end
        end
    end

    return false
end

-- How many upgrades can the player afford for a given crest track?
function ns:GetAffordableUpgrades(crestTrack)
    local count = ns:GetCrestCountByTrack(crestTrack)
    local cost = ns:GetCrestCost(crestTrack)
    if cost == 0 then return 99 end
    return math.floor(count / cost)
end

-- How many crests can still be earned this season (current cap - total earned)
function ns:GetEarnableCrests(crestTrack)
    local info = ns:GetCrestWeeklyInfo(crestTrack)
    if not info then return 0 end
    -- seasonCap comes from GetCrestInfo, not weekly info
    for _, crest in ipairs(ns.CRESTS) do
        if crest.track == crestTrack then
            local cInfo = C_CurrencyInfo.GetCurrencyInfo(crest.id)
            if cInfo and cInfo.useTotalEarnedForMaxQty and cInfo.maxQuantity then
                return math.max(cInfo.maxQuantity - (cInfo.totalEarned or 0), 0)
            end
        end
    end
    return 0
end

-- Total budget: current crests + still earnable this season
function ns:GetTotalCrestBudget(crestTrack)
    return ns:GetCrestCountByTrack(crestTrack) + ns:GetEarnableCrests(crestTrack)
end

------------------------------------------------------------
-- The crest budget, spent.
--
-- Every affordability question the addon asked used to be asked one
-- slot at a time: can I pay for THIS upgrade, and would paying for it
-- starve something more important. Each slot answered from a fresh scan
-- of the other fifteen, so sixteen slots produced sixteen independent
-- opinions about the same wallet -- and no answer at all to the only
-- question a capped player actually has, which is "I hold 140 Veteran,
-- that is seven upgrades, WHICH seven?".
--
-- This spends the budget once and records where it went. Ranks are
-- bought one at a time, each going to the best remaining candidate:
-- highest slot priority first, and among equals the lowest item level,
-- because that is the slot the rank is worth most in. Buying a rank
-- raises that slot's level, so equal-priority slots interleave instead
-- of one weapon swallowing the wallet -- which is both what players do
-- and what makes the resulting list read as an order of operations.
--
-- The walk continues past the point the crests run out, so the plan
-- also describes what is NOT affordable and by how much. That is the
-- half the old code could not express: it could say "hold crests" but
-- never "you are 60 short of this, and here is what is ahead of it".
------------------------------------------------------------

------------------------------------------------------------
-- What a rank is worth, and why these numbers.
--
-- Every rank costs the same crest, so the only thing that can order a
-- plan is what the rank is WORTH -- and that is not its item level. It
-- is the item level multiplied by how long the player keeps it, which
-- the drop band decides:
--
--   above the whole band   the content cannot hand this out, so the
--                          rank is permanent. Full value.
--   inside the band        the slot's high-water mark promotes an
--                          incoming piece from the weaker source up to
--                          here for free, so the rank is refunded when
--                          that source fills the slot -- and lost when
--                          the stronger one does. Half, for the coin
--                          toss over which arrives first.
--   below the whole band   any drop clears it and the mark never comes
--                          into play. Stats until the slot turns over,
--                          which is real but small -- and is the only
--                          reason this is not zero.
--
-- Reaching a track's cap does something else, and it is NOT what an
-- earlier pass of this file claimed. An item does not move onto the
-- next track. A Champion piece at 6/6 is 308 and is finished forever.
--
-- What carries over is the SLOT. Its high-water mark is now 308, so the
-- next Hero piece to land there -- arriving at 305, Hero 1/6 -- is
-- upgraded to 308 for nothing. The crests saved are HERO crests, on an
-- item the player does not own yet.
--
-- That makes finishing a track the one thing a spent-out lower crest
-- can do for a higher one: it is the only exchange in the game, and it
-- runs through the slot rather than through a vendor. Which is why the
-- rebate is applied to the run's COST rather than its value -- 20 Hero
-- saved is worth more than the 20 Champion it cost, and CREST_VALUE is
-- what prices that difference.
--
-- The size of the rebate is not fixed at the two ranks TRACK_FREE_RANKS
-- names. It is the gap between where the mark sits and where the drop
-- arrives: a 305 raid piece is lifted one rank, a 311 key piece already
-- starts above the mark and is lifted none. So it is read off the drop
-- band like everything else here.
--
-- These are weights, not measurements. They are set where the ordering
-- they produce matches what the drop band already says in words, and
-- they are deliberately coarse: the ranking is robust to moving any of
-- them by a tenth, and anything finer would be false precision about a
-- coin toss.
------------------------------------------------------------
ns.PLAN_VALUE = {
    permanent = 1.00,
    banked    = 0.50,
    rental    = 0.20,
}

--- How much of a rank's item level the player actually keeps.
local function RankDurability(ilvl, bandLow, bandHigh)
    local V = ns.PLAN_VALUE
    -- No band means no content model to judge against; treat every rank
    -- as kept rather than inventing a discount.
    if not bandHigh or bandHigh <= 0 then return V.permanent end
    if ilvl > bandHigh then return V.permanent end
    if bandLow and ilvl >= bandLow then return V.banked end
    return V.rental
end

--- What finishing this track saves on the NEXT piece to land in the slot.
---
--- Returns the rebate priced in THIS track's crests, the track it is
--- saved on, and how many of its ranks the mark covers. Zero when the
--- content already hands out pieces above where the mark would sit --
--- a 311 key drop starts past a 308 mark and owes it nothing.
local function MarkRebate(track, bandLow)
    local nextTrack = ns.TRACK_ORDER[(ns.TRACK_RANK[track] or 0) + 1]
    if not nextTrack then return 0, nil, 0 end

    local nextLevels = ns.GEAR_TRACKS[nextTrack]
    local markIlvl = ns:GetMaxIlvlForTrack(track)
    if not nextLevels or markIlvl <= 0 then return 0, nextTrack, 0 end

    -- Where the mark sits on the next track's ladder, and where the
    -- player's weakest source drops onto it. A drop below the track
    -- starts at its first rank; one above the mark is already past it.
    local markRank, dropRank = 0, 1
    for i, lvl in ipairs(nextLevels) do
        if lvl <= markIlvl then markRank = i end
        if bandLow and bandLow > 0 and lvl <= bandLow then dropRank = i end
    end

    local ranks = markRank - dropRank
    -- The two positions come back as well as the difference. A player
    -- reads their gear as "Hero 1/6", not as 305, so the sentence that
    -- explains this has to be able to say which rank it means.
    if ranks <= 0 then return 0, nextTrack, 0, markRank, dropRank end

    -- Priced across currencies. A Hero crest is worth more than the
    -- Champion one that saved it, and on a wallet the content has
    -- outgrown the Champion side of that trade is nearly free.
    local here  = ns.CREST_VALUE[track] or 1
    local there = ns.CREST_VALUE[nextTrack] or here
    local saved = ranks * ns:GetCrestCost(ns.TRACK_CREST[nextTrack] or nextTrack)
    return saved * (there / here), nextTrack, ranks, markRank, dropRank
end

local planCache = {}

--- Drop memoised plans. Cheap, and a stale plan is worse than a slow one.
function ns:InvalidateCrestPlans()
    wipe(planCache)
end

do
    -- The wallet and the gear are the only two inputs, so those are the
    -- two events that can make a plan stale. Without this the cache
    -- would serve a pre-purchase plan for the rest of the session --
    -- the addon's advice frozen at the moment it was first asked.
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    watcher:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    watcher:SetScript("OnEvent", function() wipe(planCache) end)
end

--- Everything known about one crest track's budget and where it goes.
---
--- Fields:
---   cost            crests per rank
---   held            crests in the wallet right now
---   seasonEarnable  crests the season cap still allows
---   seasonCapped    true when the cap is reached (and there IS a cap)
---   uncapped        crests this track can still be given outside the cap
---   budget          held + seasonEarnable
---   demand          crests to max every slot on this track
---   shortfall       demand - budget, floored at zero
---   steps           every rank, in the order it should be bought
---   slots           per-slot summary, keyed by slotID
---   order           slotIDs in the order their first rank comes up
function ns:GetCrestPlan(crestTrack)
    if not crestTrack then return nil end
    if planCache[crestTrack] then return planCache[crestTrack] end

    local cost = ns:GetCrestCost(crestTrack)
    local held = ns:GetCrestCountByTrack(crestTrack)
    local seasonEarnable = ns:GetEarnableCrests(crestTrack)
    local uncapped = ns.GetUncappedCrestIncome and ns:GetUncappedCrestIncome(crestTrack) or 0
    local budget = held + seasonEarnable
    local ceiling = ns:GetDropCeiling()
    local bandLow, bandHigh = ns:GetDropBand()
    local outgrown = ns:IsCrestOutgrown(crestTrack)

    -- Candidates: every equipped piece this crest can actually be spent
    -- on. Crests are track-locked, so a slot on another track is not
    -- competition for this wallet however valuable the slot is.
    local candidates = {}
    for _, si in ipairs(ns.SLOT_IDS) do
        local canUp, up = ns:CanUpgradeItem(si.slot)
        if canUp and up then
            local track = up.track or ns:GetTrackFromIlvl(up.currIlvl)
            if ns.TRACK_CREST[track] == crestTrack then
                local levels = ns.GEAR_TRACKS[track]
                local rank = up.currUpgrade or 0
                local startIlvl = up.currIlvl or (levels and levels[rank]) or 0
                -- Risk is read once, from the item level the slot starts
                -- at, and then held fixed for the walk. Recomputing it as
                -- ranks are bought would let a slot re-rank itself
                -- mid-plan, and the order would stop being reproducible.
                local risk = ns:GetReplacementRisk(si.slot, startIlvl)
                candidates[#candidates + 1] = {
                    slotID   = si.slot,
                    slotName = si.name,
                    priority = ns.SLOT_PRIORITY[si.slot] or 2,
                    track    = track,
                    levels   = levels,
                    rank     = rank,
                    maxRank  = up.maxUpgrade or 0,
                    ilvl     = startIlvl,
                    -- Kept for the reserve, which counts at-risk slots.
                    -- It no longer orders the walk: the drop band does
                    -- that, and against the right number. Risk measures
                    -- the gap to a ceiling built from the raid track's
                    -- MAX -- ten item levels above what the raid drops
                    -- -- so on a Heroic profile every slot below Hero
                    -- reads "high" and the signal is flat.
                    risk     = risk,
                }
            end
        end
    end

    local plan = {
        track          = crestTrack,
        cost           = cost,
        held           = held,
        seasonEarnable = seasonEarnable,
        seasonCapped   = seasonEarnable <= 0 and ns:IsCrestCapped(crestTrack),
        uncapped       = uncapped,
        budget         = budget,
        affordableNow  = cost > 0 and math.floor(held / cost) or 0,
        affordableAll  = cost > 0 and math.floor(budget / cost) or 0,
        steps          = {},
        slots          = {},
        order          = {},
        slotCount      = #candidates,
        demand         = 0,
        shortfall      = 0,
    }

    -- Per-slot summaries exist before the walk, so a slot that gets no
    -- funding at all still has an entry to report against.
    for _, c in ipairs(candidates) do
        plan.slots[c.slotID] = {
            slotID       = c.slotID,
            slotName     = c.slotName,
            priority     = c.priority,
            track        = c.track,
            rank         = c.rank,
            maxRank      = c.maxRank,
            fromIlvl     = c.ilvl,
            risk         = c.risk,
            wantedRanks  = c.maxRank - c.rank,
            fundedRanks  = 0,
            bankedRanks  = 0,      -- paid ranks inside the drop band
            promotes     = false,  -- paid ranks reach this track's cap
            promotesTo   = nil,    -- ...and put the piece on this track
            paidRanks    = 0,      -- covered by crests in hand today
            paidIlvl     = c.ilvl,
            paidCost     = 0,
            stickyRanks  = 0,      -- paid ranks a drop cannot overtake
            firstStep    = nil,
            crestsBefore = nil,    -- spent on better slots ahead of this one
        }
        plan.demand = plan.demand + (c.maxRank - c.rank) * cost
    end

    plan.shortfall = math.max(plan.demand - budget, 0)
    plan.scarce    = plan.demand > budget

    ------------------------------------------------------------
    -- Keep something back when the wallet cannot refill.
    --
    -- This is the failure the whole feature exists for. Crests capped
    -- for the season are a stock, not an income: spend to zero and the
    -- next drop -- which is the thing most worth upgrading, because it
    -- is new and its slot's floor is already paid for -- sits at its
    -- drop level until the cap raises. Planning the last crest is how a
    -- player ends a week unable to touch anything.
    --
    -- No reserve when the track still has income, whether that is
    -- allowance left under the cap or the quest boxes that ignore it:
    -- holding crests back against a wallet that refills on its own is
    -- just a slower version of the same waste.
    --
    -- One upgrade per slot the content can still replace, two at most.
    -- More than that and the reserve competes with the upgrades it is
    -- meant to protect.
    ------------------------------------------------------------
    --
    -- And none at all on a wallet the content has outgrown. The reserve
    -- protects a FUTURE drop, and once every piece the player is handed
    -- arrives on a higher track there is no future drop these crests
    -- could ever pay for. Holding them back then protects nothing: it
    -- retires item levels the player could be wearing, in a currency
    -- with nowhere else to go. On the panel that prompted this it held
    -- back exactly the 40 Champion that would have finished a second
    -- piece to its track cap.
    local reserve = 0
    if plan.seasonCapped and uncapped <= 0 and cost > 0 and not outgrown then
        local atRisk = 0
        for _, c in ipairs(candidates) do
            if c.risk == "high" then atRisk = atRisk + 1 end
        end
        reserve = math.min(atRisk, 2) * cost
        -- Never hold back so much that nothing can be bought at all.
        -- A reserve that swallows the wallet gives the player the exact
        -- paralysis it was added to prevent.
        if reserve >= held then
            reserve = math.max(held - cost, 0)
        end
    end
    plan.reserve   = reserve
    plan.spendable = math.max(held - reserve, 0)
    plan.ceiling   = ceiling
    plan.bandLow   = bandLow
    plan.bandHigh  = bandHigh
    plan.outgrown  = outgrown
    -- Recomputed against spendable now that the reserve is known. The
    -- header prints this, and it has to be the count the walk will
    -- actually mark payable or the panel contradicts its own list.
    plan.affordableNow = cost > 0 and math.floor(plan.spendable / cost) or 0

    ------------------------------------------------------------
    -- The walk. Pick the best RUN of ranks, not the best single rank.
    --
    -- Buying one rank at a time and re-picking the best slot after each
    -- is what spread a wallet thin. Equal-priority slots interleave by
    -- item level, which reads like fairness and costs the player the one
    -- thing on this track worth saving for: the cap. Ranks are not
    -- independent purchases. The last one on a track promotes the piece
    -- onto the next track, and the ranks nearest the cap are the ones
    -- landing high enough for the slot to keep them -- so a run bought
    -- whole is worth more than the same crests dribbled across slots.
    --
    -- A one-rank walk cannot express that, because it never looks
    -- further ahead than one rank. On the panel that prompted this, 160
    -- Champion bought one piece to its cap and left two trinkets
    -- stranded mid-track, where the same 160 finishes two of them.
    --
    -- So every candidate offers every run it could still buy -- one
    -- rank, two, up to its cap -- each scored on what the player keeps
    -- per crest spent, and the best run wins outright. Runs are chosen
    -- whole but RECORDED rank by rank, so the steps list, the running
    -- total and the paid/unpaid line are all exactly what they were.
    ------------------------------------------------------------
    local rebate, markTrack, markRanks, markRank, dropRank =
        MarkRebate(crestTrack, bandLow)
    plan.markTrack  = markTrack
    plan.markRanks  = markRanks
    plan.markRebate = rebate
    plan.markRank   = markRank    -- where the mark lands on that ladder
    plan.dropRank   = dropRank    -- where the drop would have started

    --- Value kept per crest spent, for buying k more ranks on c.
    --- reachable is what the wallet can still finish with right now.
    local function ScoreRun(c, k, reachable)
        local gain, landing = 0, c.ilvl
        for j = 1, k do
            local step = c.levels and c.levels[c.rank + j]
            if not step then return nil end
            gain = gain + (step - landing) * RankDurability(step, bandLow, bandHigh)
            landing = step
        end

        local runCost = k * cost
        -- Finishing the track discounts the run rather than inflating
        -- it: the crests come back on a future piece, in a currency
        -- worth more than the one being spent here.
        --
        -- Only for a run the wallet can actually finish. Crediting a
        -- rebate the player cannot reach is precisely how a plan talks
        -- itself into stranding crests halfway up a track.
        local effective = runCost
        if c.rank + k >= c.maxRank and runCost <= reachable then
            -- Never below one rank's price. A rebate that swallows the
            -- run would divide by almost nothing and rank it above
            -- everything on the page regardless of what it buys.
            effective = math.max(runCost - rebate, cost)
        end
        return gain * (c.priority or 2) / effective
    end

    -- Ties break on priority, then item level, then slot id, then the
    -- shorter run. The slot id is not cosmetic: two rings at the same
    -- priority and level would otherwise swap places with table
    -- iteration order and the panel would reshuffle between refreshes.
    local function Better(score, c, k, bestScore, bestC, bestK)
        if not bestC then return true end
        if score ~= bestScore then return score > bestScore end
        if c.priority ~= bestC.priority then return c.priority > bestC.priority end
        if c.ilvl ~= bestC.ilvl then return c.ilvl < bestC.ilvl end
        if c.slotID ~= bestC.slotID then return c.slotID < bestC.slotID end
        return k < bestK
    end

    local spent = 0
    while true do
        -- Crests in hand while any remain, then what the season still
        -- allows. A run that fits in neither is planned without its
        -- promotion, which is the truth: it will not be finished.
        local reachable = (spent < plan.spendable)
            and (plan.spendable - spent)
            or math.max(budget - spent, 0)

        local best, bestK, bestScore
        for _, c in ipairs(candidates) do
            for k = 1, c.maxRank - c.rank do
                local score = ScoreRun(c, k, reachable)
                if score and Better(score, c, k, bestScore, best, bestK) then
                    best, bestK, bestScore = c, k, score
                end
            end
        end
        if not best then break end

        local summary = plan.slots[best.slotID]
        for _ = 1, bestK do
            best.rank = best.rank + 1
            best.ilvl = (best.levels and best.levels[best.rank]) or best.ilvl
            spent = spent + cost

            -- Which side of the player's own content this rank lands on.
            -- The whole ordering above turns on it, so it is recorded
            -- rather than re-derived by every string that explains it.
            local band = "permanent"
            if bandHigh > 0 and best.ilvl <= bandHigh then
                band = (bandLow > 0 and best.ilvl >= bandLow) and "banked" or "rental"
            end

            local step = {
                slotID     = best.slotID,
                slotName   = best.slotName,
                rank       = best.rank,
                maxRank    = best.maxRank,
                toIlvl     = best.ilvl,
                cumulative = spent,
                funded     = spent <= budget,
                -- Against spendable, not held: the reserve is
                -- deliberately not planned, so a step it would have paid
                -- for is not one the panel should show above the line.
                paid       = spent <= plan.spendable,
                band       = band,
                -- Its own field because the reason strings read it
                -- directly: a rank the content cannot reach is banked by
                -- the slot's mark whatever else is true of it.
                sticks     = band == "permanent",
                -- The rank that tops the track out and sets the slot's
                -- mark. The item stops here; the next one benefits.
                promotes   = (best.rank >= best.maxRank) and markTrack or nil,
            }
            plan.steps[#plan.steps + 1] = step

            if not summary.firstStep then
                summary.firstStep    = #plan.steps
                -- Everything bought before this slot's first rank is
                -- what a "these come first" explanation has to name.
                summary.crestsBefore = spent - cost
                plan.order[#plan.order + 1] = best.slotID
            end
            if step.funded then
                summary.fundedRanks = summary.fundedRanks + 1
            end
            if step.paid then
                summary.paidRanks = summary.paidRanks + 1
                summary.paidIlvl  = best.ilvl
                summary.paidCost  = summary.paidCost + cost
                if step.sticks then
                    summary.stickyRanks = summary.stickyRanks + 1
                elseif band == "banked" then
                    summary.bankedRanks = summary.bankedRanks + 1
                end
                if step.promotes then
                    summary.promotes   = true
                    summary.promotesTo = step.promotes
                end
            end
        end
    end

    -- How far down the order the crests in hand reach. The panel draws a
    -- line here; it is the most useful single fact on the page, and the
    -- old layout had nowhere to put it.
    plan.paidSteps = 0
    for _, step in ipairs(plan.steps) do
        if step.paid then plan.paidSteps = plan.paidSteps + 1 end
    end

    planCache[crestTrack] = plan
    return plan
end

--- Slot names paid for ahead of `slotID` on its own track, best first.
--- Answers "why not this one yet" with the actual competition rather
--- than with a single hardcoded "top slots".
function ns:GetCrestPlanBlockers(plan, slotID, limit)
    if not plan then return {} end
    local mine = plan.slots and plan.slots[slotID]
    if not mine or not mine.firstStep then return {} end

    local names, seen = {}, {}
    for i = 1, mine.firstStep - 1 do
        local step = plan.steps[i]
        if not seen[step.slotID] then
            seen[step.slotID] = true
            names[#names + 1] = step.slotName
            if limit and #names >= limit then break end
        end
    end
    return names
end

------------------------------------------------------------
-- The whole set, counted once.
--
-- Every question above this line is asked one slot at a time, and the
-- most useful question about a crest track cannot be: "can I finish
-- this track at all" is a fact about sixteen slots and one wallet, and
-- no per-slot rule can reach it. Without it the panel will happily open
-- a 100-crest climb on the fifth Champion piece while the player has
-- 200 crests and four other pieces in the same state -- each row true,
-- the set of them describing a plan that cannot happen.
--
-- Old-season and untracked pieces are counted too, and deliberately not
-- hidden. They are slots whose demand has not arrived yet: whatever
-- replaces one lands on some track and starts wanting crests, so a
-- track budget that ignores them is optimistic by however many there
-- are.
------------------------------------------------------------
function ns:GetGearCensus()
    local census = {
        tracks    = {},
        untracked = {},   -- an item, but not on this season's ladder
        empty     = {},   -- nothing equipped
        maxed     = {},   -- on a track, already at its cap
        slots     = 0,
    }

    for _, si in ipairs(ns.SLOT_IDS or {}) do
        census.slots = census.slots + 1
        local info = ns:GetSlotInfo(si.slot)
        if not info or (info.ilvl or 0) == 0 then
            census.empty[#census.empty + 1] = si.name
        else
            local canUp, up = ns:CanUpgradeItem(si.slot)
            local track = up and up.track
            if not track then
                census.untracked[#census.untracked + 1] = si.name
            else
                local t = census.tracks[track]
                if not t then
                    t = { track = track, pieces = {}, count = 0,
                          ranksLeft = 0, demand = 0 }
                    census.tracks[track] = t
                end
                local rank    = up.currUpgrade or 0
                local maxRank = up.maxUpgrade or 0
                local left    = math.max(maxRank - rank, 0)
                t.count     = t.count + 1
                t.ranksLeft = t.ranksLeft + left
                t.pieces[#t.pieces + 1] = {
                    slotID   = si.slot,
                    slotName = si.name,
                    rank     = rank,
                    maxRank  = maxRank,
                    left     = left,
                    ilvl     = up.currIlvl or info.ilvl,
                    priority = ns.SLOT_PRIORITY[si.slot] or 2,
                }
                if not canUp or left == 0 then
                    census.maxed[#census.maxed + 1] = si.name
                end
            end
        end
    end

    for track, t in pairs(census.tracks) do
        t.demand = t.ranksLeft * ns:GetCrestCost(ns.TRACK_CREST[track] or track)
    end
    return census
end

------------------------------------------------------------
-- What to do with a whole track, in one verdict.
--
-- Finishing a piece is worth the same on every slot -- it tops the
-- track out and sets the slot's mark -- but it costs whatever that
-- piece has left to climb. So when the wallet cannot finish everything,
-- the cheapest completions buy the most marks per crest, and a plan
-- that spreads evenly across five pieces finishes none of them.
--
-- That is the shape of the advice players actually want: not sixteen
-- opinions but "you cannot finish all five, here are the two you can,
-- the rest want drops".
------------------------------------------------------------
function ns:GetTrackPolicy(crestTrack)
    if not crestTrack then return nil end
    local census = ns:GetGearCensus()
    local t = census.tracks[crestTrack]
    if not t or t.count == 0 then return nil end

    local plan   = ns:GetCrestPlan(crestTrack)
    local held   = ns:GetCrestCountByTrack(crestTrack)
    local budget = plan and plan.budget or held
    local cost   = ns:GetCrestCost(crestTrack)

    -- Cheapest completions first: the pieces nearest their cap.
    local order = {}
    for _, piece in ipairs(t.pieces) do
        if piece.left > 0 then order[#order + 1] = piece end
    end
    table.sort(order, function(a, b)
        if a.left ~= b.left then return a.left < b.left end
        if a.priority ~= b.priority then return a.priority > b.priority end
        return a.slotID < b.slotID
    end)

    local canFinish, spend, deepest = {}, 0, nil
    for _, piece in ipairs(order) do
        local runCost = piece.left * cost
        if spend + runCost <= held then
            spend = spend + runCost
            canFinish[#canFinish + 1] = piece
            deepest = piece.left
        end
    end

    local policy = {
        track       = crestTrack,
        count       = t.count,
        pieces      = t.pieces,
        wanting     = #order,
        demand      = t.demand,
        held        = held,
        budget      = budget,
        outgrown    = ns:IsCrestOutgrown(crestTrack),
        canFinish   = canFinish,
        finishCost  = spend,
        -- The deepest piece the wallet can still afford to carry home,
        -- which is the threshold a player can actually apply to a drop:
        -- "anything at 4/6 or better is worth finishing".
        worstRankWorthFinishing = deepest
            and (order[1].maxRank - deepest) or nil,
        untracked   = #census.untracked,
    }

    if #order == 0 then
        policy.verdict = "done"
    elseif budget >= t.demand then
        policy.verdict = "max_all"
    elseif #canFinish > 0 then
        policy.verdict = "finish_close"
    else
        policy.verdict = "nothing_reachable"
    end

    return policy
end

------------------------------------------------------------
-- How close the player is to never needing this crest again.
--
-- A track has a finish line and it is not the achievement: it is the
-- moment every slot sits at or above the track's cap, because from then
-- on the crest has nothing left to buy. That is the fact worth telling
-- someone -- "three pieces and you are done with Champion for good" is
-- a reason to spend, where "Champion tops out at 308" is a rule they
-- did not ask to be taught.
--
-- Slots count as done however they got there. A Hero piece sitting at
-- 311 is past the Champion cap and will never want a Champion crest, so
-- it is finished for this purpose even though nothing was spent on it.
------------------------------------------------------------
function ns:GetTrackCompletion(crestTrack)
    if not crestTrack then return nil end
    local capIlvl = ns:GetMaxIlvlForTrack(crestTrack)
    if capIlvl <= 0 then return nil end

    local cost = ns:GetCrestCost(crestTrack)
    local out = {
        track     = crestTrack,
        capIlvl   = capIlvl,
        slots     = 0,
        done      = 0,     -- at or above the cap, by any route
        needCrest = 0,     -- on this track, still climbing
        needDrop  = 0,     -- below the cap and crests cannot get there
        cost      = 0,     -- to finish every needCrest slot
        held      = ns:GetCrestCountByTrack(crestTrack),
        remaining = {},    -- the pieces still climbing, cheapest first
    }

    for _, si in ipairs(ns.SLOT_IDS or {}) do
        out.slots = out.slots + 1
        local info = ns:GetSlotInfo(si.slot)
        local ilvl = info and info.ilvl or 0
        if ilvl >= capIlvl then
            out.done = out.done + 1
        else
            local canUp, up = ns:CanUpgradeItem(si.slot)
            local track = up and up.track
            if canUp and track and ns.TRACK_CREST[track] == crestTrack then
                local left = math.max((up.maxUpgrade or 0) - (up.currUpgrade or 0), 0)
                if left > 0 then
                    out.needCrest = out.needCrest + 1
                    out.cost = out.cost + left * cost
                    out.remaining[#out.remaining + 1] = {
                        slotID = si.slot, slotName = si.name,
                        left = left, cost = left * cost,
                    }
                else
                    out.needDrop = out.needDrop + 1
                end
            else
                -- Empty, off-season, or parked on a lower track whose
                -- own cap sits under this one. Crests cannot move it.
                out.needDrop = out.needDrop + 1
            end
        end
    end

    out.canFinish = out.cost > 0 and out.held >= out.cost
    out.short     = math.max(out.cost - out.held, 0)
    out.surplus   = math.max(out.held - out.cost, 0)
    -- Done means done: no slot left that this crest could still buy.
    out.finished  = out.needCrest == 0

    ------------------------------------------------------------
    -- The SHAPE of what is left, not just its price.
    --
    -- "260 crests" describes two completely different weeks. Three
    -- pieces each a rank from their cap is an evening and a drop away;
    -- three pieces at 1/6 is most of a season, and the crests are better
    -- spent elsewhere while drops do that job for free. Same number.
    ------------------------------------------------------------
    table.sort(out.remaining, function(a, b)
        if a.left ~= b.left then return a.left < b.left end
        return a.slotID < b.slotID
    end)
    out.nearest = out.remaining[1] and out.remaining[1].left or 0
    out.deepest = out.remaining[#out.remaining]
        and out.remaining[#out.remaining].left or 0

    ------------------------------------------------------------
    -- And how long the shortfall actually is.
    --
    -- A cap the player has not reached is not a wait -- those crests are
    -- sitting in content they have not run yet, and the answer is "go
    -- and earn it", not "come back in a fortnight". Only the part beyond
    -- this season's allowance needs resets, and the allowance grows by
    -- CREST_WEEKLY_INCREMENT a week.
    --
    -- Which is why this is the first thing in the addon to read that
    -- constant. It has been defined and unused since it was written.
    ------------------------------------------------------------
    out.earnable = ns:GetEarnableCrests(crestTrack)
    if out.short > 0 then
        -- Counted the way a player counts it: weeks until the track is
        -- done, this one included. Reporting only the resets BEYOND the
        -- allowance was answering a question nobody asks -- "2" when the
        -- honest answer to "how long until I can max these" is 3.
        local beyondCap = math.max(out.short - out.earnable, 0)
        out.withinAllowance = beyondCap <= 0
        out.weeks = 1 + math.ceil(beyondCap / (ns.CREST_WEEKLY_INCREMENT or 100))
    end
    return out
end

--- One line a player can act on, for a whole track.
function ns:GetTrackPolicyLine(crestTrack)
    local p = ns:GetTrackPolicy(crestTrack)
    if not p then return nil end

    local pieces = p.count .. (p.count == 1 and " piece" or " pieces")

    if p.verdict == "done" then
        return crestTrack .. ": " .. pieces .. ", all at the cap."
    end
    if p.verdict == "max_all" then
        return crestTrack .. ": " .. pieces .. ", " .. p.demand ..
            " to finish them all and " .. p.budget ..
            " coming. Max everything on this track."
    end
    if p.verdict == "nothing_reachable" then
        return crestTrack .. ": " .. pieces .. ", " .. p.demand ..
            " to finish them all, you hold " .. p.held ..
            ". Not enough to carry even one home — hold, or take a drop."
    end

    local names = {}
    for i, piece in ipairs(p.canFinish) do
        if i > 3 then names[#names + 1] = "+" .. (#p.canFinish - 3) .. " more" break end
        names[#names + 1] = piece.slotName
    end
    local rest = p.wanting - #p.canFinish
    local line = crestTrack .. ": " .. pieces .. ", " .. p.demand ..
        " to finish them all, you hold " .. p.held .. ". Enough for " ..
        #p.canFinish .. " — " .. table.concat(names, ", ") .. "."
    if rest > 0 then
        line = line .. " The other " .. rest ..
            (p.outgrown and " want drops, not crests." or " will have to wait.")
    end
    return line
end

--- Every crest track with something to spend on, highest track first.
--- The panel groups by this: a budget is per track, so advice about one
--- wallet belongs under that wallet and nowhere else.
function ns:GetActiveCrestPlans()
    local out, seen = {}, {}
    for i = #ns.TRACK_ORDER, 1, -1 do
        local crestTrack = ns.TRACK_CREST[ns.TRACK_ORDER[i]]
        if crestTrack and not seen[crestTrack] then
            seen[crestTrack] = true
            local plan = ns:GetCrestPlan(crestTrack)
            if plan and plan.slotCount > 0 then
                out[#out + 1] = plan
            end
        end
    end
    return out
end

------------------------------------------------------------
-- Crest waste: paying a scarce crest for an item level a cheaper
-- crest already reaches.
--
-- Season 2 tracks overlap by exactly two ranks (ns.TRACK_FREE_RANKS),
-- so rank 1 -> 2 of the higher track lands on the same item level as
-- rank 5 -> 6 of the one below it, at the same 20-crest price:
--
--   Champion 5/6 305 -> 6/6 308   ==   Hero 1/6 305 -> 2/6 308
--   Hero     5/6 318 -> 6/6 321   ==   Myth 1/6 318 -> 2/6 321
--
-- The two crests are not worth the same, though. Myth crests keep
-- buying ranks 3-6 for the whole season; Hero crests stop mattering the
-- week every Hero-track slot is maxed, around week 3-4. So the higher
-- crest spent inside the overlap is strictly dominated: it buys nothing
-- the cheaper one could not, and burns one that still had somewhere
-- else to go. Same shape one tier down, which is why the Hero/Champion
-- case only starts to matter once the player is farming +10 keys and
-- Champion crests have gone abundant.
--
-- The addon already advised the free promotion out of this band; what
-- it never did was say the spend itself is a mistake before you make
-- it. That is what this returns.
--
-- nil when nothing is at stake. Otherwise a table describing the spend.
-- `sinkSlots` names the equipped lower-track pieces that could absorb
-- the cheaper crests instead; with none of those the advice is still
-- true, but there is no move to make right now, so callers should
-- soften it rather than shout.
------------------------------------------------------------
function ns:GetCrestWaste(slotID)
    local canUpgrade, upgradeInfo = ns:CanUpgradeItem(slotID)
    if not canUpgrade or not upgradeInfo then return nil end

    local track = upgradeInfo.track
    local overlap = track and ns.TRACK_FREE_RANKS[track]
    if not overlap then return nil end

    -- Only ranks below the overlap count are duplicated by the track
    -- underneath. Myth 2 -> 3 is Myth-only ground and is never waste.
    local rank = upgradeInfo.currUpgrade or 0
    if rank < 1 or rank >= overlap.count then return nil end

    local crestTrack = ns.TRACK_CREST[track]
    local prevCrestTrack = ns.TRACK_CREST[overlap.prevTrack]
    if not crestTrack or not prevCrestTrack then return nil end

    -- Nothing to protect if the crest being spent is not scarce for this
    -- player -- the warning would be pure noise. This is also what gates
    -- the Hero case by content level: Hero -> Champion is only worth
    -- saying once Champion crests are free, which the profiles model as
    -- "farming +10 keys or better".
    if not ns:IsCrestPrecious(crestTrack) then return nil end

    local levels = ns.GEAR_TRACKS[track]
    if not levels or not levels[rank] or not levels[overlap.count] then return nil end

    -- Where could the cheaper crests go instead? Only equipped pieces
    -- still sitting on the lower track can absorb them.
    --
    -- A candidate that is itself parked in ITS own overlap band earns
    -- this same warning one tier down, so leading with it would have the
    -- addon pointing at a slot it is simultaneously telling the player
    -- to leave alone. It is still a real sink -- the ranks above the
    -- band do need genuine crests -- so it stays in the list, just not
    -- at the front of it.
    local prevOverlap = ns.TRACK_FREE_RANKS[overlap.prevTrack]
    local prevOverlapRanks = 0
    if prevOverlap then prevOverlapRanks = prevOverlap.count end

    local clean, muddy, sinkRanks = {}, {}, 0
    for _, si in ipairs(ns.SLOT_IDS) do
        if si.slot ~= slotID then
            local canUp, up = ns:CanUpgradeItem(si.slot)
            if canUp and up and up.track == overlap.prevTrack then
                sinkRanks = sinkRanks + ((up.maxUpgrade or 0) - (up.currUpgrade or 0))
                if (up.currUpgrade or 0) >= prevOverlapRanks then
                    table.insert(clean, si.name)
                else
                    table.insert(muddy, si.name)
                end
            end
        end
    end

    local sinkSlots = clean
    for _, name in ipairs(muddy) do
        table.insert(sinkSlots, name)
    end

    local cost = ns:GetCrestCost(crestTrack)
    local prevCost = ns:GetCrestCost(prevCrestTrack)
    local prevCount = ns:GetCrestCountByTrack(prevCrestTrack)
    local prevAffordable = 0
    if prevCost > 0 then
        prevAffordable = math.floor(prevCount / prevCost)
    end

    local wastedRanks = overlap.count - rank

    return {
        slotID         = slotID,
        track          = track,
        prevTrack      = overlap.prevTrack,
        crestTrack     = crestTrack,
        prevCrestTrack = prevCrestTrack,
        rank           = rank,
        maxRank        = upgradeInfo.maxUpgrade,
        overlapRanks   = overlap.count,
        fromIlvl       = levels[rank],
        toIlvl         = levels[overlap.count],
        wastedRanks    = wastedRanks,
        wastedCrests   = wastedRanks * cost,
        sinkSlots      = sinkSlots,
        cleanSinks     = #clean,
        sinkRanks      = sinkRanks,
        prevCrestCount = prevCount,
        prevAffordable = prevAffordable,
    }
end

--- Every slot whose next crest purchase lands inside the overlap band.
--- Returns the list, plus crestTrack -> total crests at stake.
function ns:GetAllCrestWaste()
    local list, totals = {}, {}
    for _, si in ipairs(ns.SLOT_IDS) do
        local waste = ns:GetCrestWaste(si.slot)
        if waste then
            waste.slotName = si.name
            table.insert(list, waste)
            totals[waste.crestTrack] = (totals[waste.crestTrack] or 0) + waste.wastedCrests
        end
    end
    return list, totals
end

-- Achievement progress: how many slots still need upgrades to earn a discount achievement?
-- Uses ilvl thresholds so cross-track items count (e.g. Champion 1/5 at 246 satisfies Veteran).
-- Returns: slotsRemaining, totalCrestCost, upgradeableCount, perSlotInfo[]
function ns:GetAchievementProgress(targetTrack)
    local targetIlvl = ns:GetMaxIlvlForTrack(targetTrack)
    if targetIlvl == 0 then return 0, 0, 0, {} end

    local slotsNeeded = {}
    local totalCrestCost = 0
    local upgradeableCount = 0

    for _, slotInfo in ipairs(ns.SLOT_IDS) do
        local info = ns:GetSlotInfo(slotInfo.slot)

        if not info or info.ilvl == 0 then
            -- Empty slot — needs a drop, can't upgrade
            table.insert(slotsNeeded, {
                slotID = slotInfo.slot,
                slotName = slotInfo.name,
                needsReplacement = true,
            })
        elseif info.ilvl < targetIlvl then
            -- Below threshold — check if upgradeable to reach it
            local canUpgrade, upgradeInfo = ns:CanUpgradeItem(slotInfo.slot)
            if upgradeInfo and canUpgrade then
                local track = upgradeInfo.track
                local levels = ns.GEAR_TRACKS[track]
                local trackMax = levels and levels[#levels] or 0

                if trackMax >= targetIlvl then
                    -- Can reach threshold by upgrading within current track
                    local crestTrack = ns.TRACK_CREST[track]
                    local cost = ns:GetCrestCost(crestTrack)
                    local ranksNeeded = 0
                    for r = upgradeInfo.currUpgrade + 1, #levels do
                        ranksNeeded = ranksNeeded + 1
                        if levels[r] >= targetIlvl then break end
                    end
                    local slotCost = ranksNeeded * cost
                    totalCrestCost = totalCrestCost + slotCost
                    upgradeableCount = upgradeableCount + 1
                    table.insert(slotsNeeded, {
                        slotID = slotInfo.slot,
                        slotName = slotInfo.name,
                        currentIlvl = info.ilvl,
                        crestTrack = crestTrack,
                        ranksNeeded = ranksNeeded,
                        crestCost = slotCost,
                    })
                else
                    -- Track caps below threshold — needs a higher-track drop
                    table.insert(slotsNeeded, {
                        slotID = slotInfo.slot,
                        slotName = slotInfo.name,
                        currentIlvl = info.ilvl,
                        needsReplacement = true,
                    })
                end
            else
                -- Can't upgrade (maxed in a low track) — needs replacement
                table.insert(slotsNeeded, {
                    slotID = slotInfo.slot,
                    slotName = slotInfo.name,
                    currentIlvl = info.ilvl,
                    needsReplacement = true,
                })
            end
        end
        -- ilvl >= targetIlvl: slot already counts, skip
    end

    return #slotsNeeded, totalCrestCost, upgradeableCount, slotsNeeded
end

--- The slots holding an "outgrown" achievement up that crests cannot fix.
---
--- GetAchievementProgress already separates these -- a slot whose track
--- caps below the threshold, or which carries no item at all, needs a
--- DROP and no amount of currency will move it. That distinction was
--- computed and then discarded: Rule 5.5 only speaks when every
--- remaining slot is upgradeable, so the moment one slot needs a drop
--- the addon works the whole thing out and says nothing whatsoever.
---
--- Which is backwards. "Six slots to Champion of the Mist, and Wrist is
--- the one blocking it -- it is Veteran track, caps at 295, so it wants
--- a drop rather than crests" is the most useful sentence available,
--- and it is only reachable in the case the advisor currently goes
--- quiet for.
---
--- Returns the blocking slot entries, plus how many slots remain in
--- total and what the upgradeable ones would cost.
function ns:GetAchievementBlockers(targetTrack)
    local remaining, cost, upgradeable, slots = ns:GetAchievementProgress(targetTrack)
    local blockers = {}
    for _, entry in ipairs(slots or {}) do
        if entry.needsReplacement then
            blockers[#blockers + 1] = entry
        end
    end
    return blockers, remaining, cost, upgradeable
end

--- The lowest achievement the player has not earned, and its state.
---
--- nil once every track is outgrown. `blockers` empty means the whole
--- thing is purchasable today, which is the only case Rule 5.5 handles.
function ns:GetChasedAchievement()
    for _, track in ipairs(ns.TRACK_ORDER) do
        if not ns:HasDiscountAchievement(track) then
            local blockers, remaining, cost, upgradeable =
                ns:GetAchievementBlockers(track)
            if remaining <= 0 then return nil end
            return {
                track      = track,
                name       = ns:GetDiscountAchievementName(track),
                ilvl       = ns:GetMaxIlvlForTrack(track),
                remaining  = remaining,
                cost       = cost,
                upgradeable = upgradeable,
                blockers   = blockers,
            }
        end
    end
    return nil
end

------------------------------------------------------------
-- Replacement risk assessment
------------------------------------------------------------
------------------------------------------------------------
-- The item level the player's own content actually hands out.
--
-- Was computed inside GetReplacementRisk and thrown away with the
-- verdict, so everything downstream could learn that a slot was "high
-- risk" but never what it was at risk OF. The plan needs the number
-- itself: whether a crest sticks depends on where the rank lands
-- relative to this, not on a three-way label.
------------------------------------------------------------
function ns:GetDropCeiling()
    local profile = ns:GetCurrentProfile()
    local dropIlvl, vaultIlvl = 0, 0

    for _, entry in ipairs(ns.DUNGEON_LOOT) do
        local keyNum = tonumber(entry.key:match("M(%d+)"))
        if keyNum and keyNum <= profile.maxKeyLevel then
            if entry.loot > dropIlvl then dropIlvl = entry.loot end
            if entry.vault and entry.vault > vaultIlvl then vaultIlvl = entry.vault end
        end
    end

    -- The raid contributes the level its loot ARRIVES at, which is the
    -- bottom of its track -- not GetMaxIlvlForTrack, which is that
    -- track fully upgraded and reachable only by spending the very
    -- crests this is meant to advise on. Reading the max had a Mythic
    -- profile report a 321 "drop" ceiling that nothing below Myth 6/6
    -- could ever clear, so every rank on every lower track was filed as
    -- doomed and the distinction stopped carrying information.
    local raidTrack = ns.RAID_TRACKS[profile.raidTier]
    local raidLevels = raidTrack and ns.GEAR_TRACKS[raidTrack]
    if raidLevels and raidLevels[1] and raidLevels[1] > dropIlvl then
        dropIlvl = raidLevels[1]
    end

    -- The vault is one pick a week against sixteen slots, so it is not
    -- what overtakes a slot -- it is what a slot could get lucky with.
    -- Returned separately rather than folded in.
    return dropIlvl, vaultIlvl
end

------------------------------------------------------------
-- The BAND of item levels the player's own content hands out.
--
-- GetDropCeiling above answers "what is the best thing that drops for
-- me", and that is the number deciding whether a crest buys a
-- PERMANENT item level. It is not the number deciding whether the
-- slot's high-water mark is worth setting, and the two are routinely
-- ten item levels apart: a Heroic raider farming +10 keys is handed
-- 305 by the raid and 311 by the end of a dungeon.
--
-- The mark only ever pays out against the WEAKER source. A slot marked
-- at 308 promotes an incoming 305 for free; against an incoming 311 the
-- mark sits below the drop and does nothing at all. So a rank landing
-- under the low end of this band is pure rental -- stats until the slot
-- turns over, nothing banked -- while a rank landing between the two
-- ends banks a refund on every drop the weaker source produces.
--
-- Both numbers were already computed in GetDropCeiling. Only the high
-- one survived the return, which is why nothing downstream could tell
-- a rental apart from a rebate.
--
-- Returns lowIlvl, highIlvl, lowTrack.
------------------------------------------------------------
function ns:GetDropBand()
    local profile = ns:GetCurrentProfile()
    local sources = {}

    -- End-of-dungeon at the best key the player actually runs. Lower
    -- keys are not a source: nobody farms a +4 while holding a +10, and
    -- counting one would drag the floor down onto content the player
    -- has already left behind.
    local keyIlvl = 0
    for _, entry in ipairs(ns.DUNGEON_LOOT) do
        local keyNum = tonumber(entry.key:match("M(%d+)"))
        if keyNum and keyNum <= profile.maxKeyLevel and entry.loot > keyIlvl then
            keyIlvl = entry.loot
        end
    end
    if keyIlvl > 0 then sources[#sources + 1] = keyIlvl end

    -- The raid contributes the level its loot ARRIVES at, not that
    -- track fully upgraded -- the same reason GetDropCeiling reads
    -- raidLevels[1] and not GetMaxIlvlForTrack.
    local raidTrack = ns.RAID_TRACKS[profile.raidTier]
    local raidLevels = raidTrack and ns.GEAR_TRACKS[raidTrack]
    if raidLevels and raidLevels[1] then
        sources[#sources + 1] = raidLevels[1]
    end

    if #sources == 0 then return 0, 0, nil end

    local low, high = sources[1], sources[1]
    for _, ilvl in ipairs(sources) do
        if ilvl < low  then low  = ilvl end
        if ilvl > high then high = ilvl end
    end

    return low, high, ns:GetTrackFromIlvl(low)
end

--- Has the player's content moved past what this crest can buy?
---
--- True when every piece the player is handed arrives on a HIGHER track
--- than this wallet pays for. Such a wallet can never fund a future
--- drop -- the drop lands on a track its crests are not valid for -- so
--- its only remaining customers are the items already worn.
---
--- This is the difference between a crest that is merely plentiful and
--- one the player has outgrown, and several rules below need to tell
--- them apart: advice about saving, holding, or reserving crests is
--- advice about a future purchase, and for an outgrown wallet there is
--- no future purchase to save for.
function ns:IsCrestOutgrown(crestTrack)
    if not crestTrack then return false end
    local _, _, lowTrack = ns:GetDropBand()
    local dropRank = lowTrack and ns.TRACK_RANK[lowTrack] or 0
    if dropRank == 0 then return false end
    return dropRank > (ns.TRACK_RANK[crestTrack] or 0)
end

function ns:GetReplacementRisk(slotID, ilvl)
    local profile = ns:GetCurrentProfile()

    local farmableIlvl = 0
    local vaultIlvl = 0

    -- M+ loot ceiling based on profile key level
    for _, entry in ipairs(ns.DUNGEON_LOOT) do
        local keyNum = tonumber(entry.key:match("M(%d+)"))
        if keyNum and keyNum <= profile.maxKeyLevel then
            if entry.loot > farmableIlvl then farmableIlvl = entry.loot end
            if entry.vault and entry.vault > vaultIlvl then vaultIlvl = entry.vault end
        end
    end

    -- Raid ceiling
    local raidTrack = ns.RAID_TRACKS[profile.raidTier]
    if raidTrack then
        local raidMax = ns:GetMaxIlvlForTrack(raidTrack)
        if raidMax > farmableIlvl then farmableIlvl = raidMax end
    end

    local ceiling = math.max(farmableIlvl, vaultIlvl)

    if ceiling == 0 then
        return "low"
    end

    local gap = ceiling - ilvl

    if gap >= 20 then
        return "high"
    elseif gap >= 10 then
        return "moderate"
    else
        return "low"
    end
end

------------------------------------------------------------
-- Core recommendation engine
------------------------------------------------------------
function ns:GetRecommendation(slotID)
    local info = ns:GetSlotInfo(slotID)
    if not info then
        return ns.RECOMMEND.NO_ITEM, ""
    end

    local canUpgrade, upgradeInfo, why = ns:CanUpgradeItem(slotID)

    if not upgradeInfo then
        -- Crafted items: show as maxed with crafted note
        if info.crafted then
            return ns.RECOMMEND.MAXED, "Crafted — no crest upgrades"
        end
        if why == "mismatch" then
            return ns.RECOMMEND.NO_ITEM,
                "Item level does not match its upgrade track — not this season's gear"
        end
        return ns.RECOMMEND.NO_ITEM,
            "No upgrade track — previous season or an untracked drop"
    end

    if not canUpgrade then
        return ns.RECOMMEND.MAXED, "Fully upgraded"
    end

    local ilvl = info.ilvl
    local track = upgradeInfo.track or ns:GetTrackFromIlvl(ilvl)
    local crestTrack = ns.TRACK_CREST[track]
    local isFree = ns:IsCrestFree(crestTrack)
    local isPrecious = ns:IsCrestPrecious(crestTrack)
    local trackRank = ns.TRACK_RANK[track] or 1
    local rank = upgradeInfo.currUpgrade
    local maxRank = upgradeInfo.maxUpgrade

    local crestCost = ns:GetCrestCost(crestTrack)
    local crestCount = ns:GetCrestCountByTrack(crestTrack)
    local upgradesNeeded = maxRank - rank

    -- High-water mark: upgrades are free up to previously reached ilvl
    local freeIlvl = ns:GetFreeUpgradeIlvl(slotID)
    local freeRanks = 0
    if freeIlvl > ilvl then
        local levels = ns.GEAR_TRACKS[track]
        if levels then
            for r = rank + 1, maxRank do
                if levels[r] and levels[r] <= freeIlvl then
                    freeRanks = freeRanks + 1
                else
                    break
                end
            end
        end
    end

    -- ============================================================
    -- RULE 0: Free upgrades via high-water mark
    -- If the item can be upgraded for free (previously had higher
    -- rank in this slot), tell the player immediately.
    -- ============================================================
    if freeRanks > 0 then
        if freeRanks >= upgradesNeeded then
            return ns.RECOMMEND.FREE_UPGRADE,
                "All remaining ranks are free — upgrade at the vendor"
        else
            local freeTarget = ns.GEAR_TRACKS[track] and ns.GEAR_TRACKS[track][rank + freeRanks]
            local paidRanks = upgradesNeeded - freeRanks
            local paidCost = paidRanks * crestCost
            return ns.RECOMMEND.FREE_UPGRADE,
                freeRanks .. " free ranks to " .. (freeTarget or "?") ..
                " — then " .. paidCost .. " " .. crestTrack .. " for the rest"
        end
    end

    -- ============================================================
    -- RULE 1: Item at track cap, next track exists
    -- ============================================================
    if rank == maxRank and trackRank < #ns.TRACK_ORDER then
        local nextTrack = ns.TRACK_ORDER[trackRank + 1]
        return ns.RECOMMEND.WAIT_BETTER,
            "Fully upgraded — need a " .. nextTrack .. " drop to go higher"
    end

    -- ============================================================
    -- RULE 2: Capped this week — can't afford and can't earn more
    -- Only show if you actually can't afford the upgrade right now.
    -- For free crests, show as softer "upgrade later" instead of red warning.
    -- ============================================================
    if crestCount < crestCost and ns:IsCrestCapped(crestTrack) then
        if isFree then
            return ns.RECOMMEND.UPGRADE_LATER,
                "Need " .. crestCost .. " " .. crestTrack .. " — more available next reset"
        else
            return ns.RECOMMEND.CREST_CAPPED,
                "Need " .. crestCost .. " " .. crestTrack .. " — capped until next reset"
        end
    end

    -- ============================================================
    -- RULE 3: Wasteful spend inside the track overlap
    --
    -- The first ranks of this track sit on item levels the track below
    -- also reaches, for the same price. Buying them with the scarcer
    -- crest is strictly dominated — see ns:GetCrestWaste for why. Warn
    -- loudly when there is a lower-track piece to spend on instead;
    -- fall back to the old promotion advice when there is not.
    --
    -- Fires BEFORE save-for-drop so promoted items (e.g. Champion 6/6
    -- → Hero 2/6) still get correct upgrade advice.
    -- ============================================================
    local waste = ns:GetCrestWaste(slotID)
    if waste then
        local sinks = #waste.sinkSlots
        if sinks > 0 then
            local where = waste.sinkSlots[1]
            if sinks > 1 then
                where = where .. " +" .. (sinks - 1) .. " more"
            end
            return ns.RECOMMEND.WASTED_CREST,
                waste.wastedCrests .. " " .. waste.crestTrack .. " for " ..
                -- "to", not an arrow: U+2192 is outside the client
                -- font's range and draws as an empty box. Seen on the
                -- dashboard, and this is the same string built the same
                -- way. The em dash below is fine -- it is used 180-odd
                -- times across the addon and renders.
                waste.fromIlvl .. " to " .. waste.toIlvl .. " — a maxed " ..
                waste.prevTrack .. " piece lands there too. Spend " ..
                waste.prevCrestTrack .. " on " .. where ..
                " (" .. waste.prevCrestCount .. " held); keep " ..
                waste.crestTrack .. " for rank " .. (waste.overlapRanks + 1) .. "+"
        end
        return ns.RECOMMEND.USE_LOWER_TRACK,
            "Rank " .. rank .. "/" .. maxRank .. " — " .. waste.toIlvl ..
            " is also a maxed " .. waste.prevTrack .. " piece, so " ..
            waste.prevCrestTrack .. " crests reach it. Keep " ..
            waste.crestTrack .. " for rank " .. (waste.overlapRanks + 1) .. "+"
    end

    -- ============================================================
    -- RULE 4: Save for drops — content drops higher rank or track
    -- If content drops a HIGHER TRACK entirely, don't spend crests
    -- on this item at all — wait for a replacement drop.
    -- If same track but content drops a higher rank, save crests
    -- and wait for the higher-rank drop instead of upgrading.
    -- E.g. Hero 2/6 shouldn't be upgraded if M+ drops Hero 3/6.
    -- ============================================================
    local farmTrack, farmRankInTrack = ns:GetFarmableInfo(track)
    local farmTrackRank = farmTrack and ns.TRACK_RANK[farmTrack] or 0
    local itemTrackRank = ns.TRACK_RANK[track] or 0

    -- Build a source hint like "M+6 to M+10" or "Heroic raid"
    local function GetSourceHint(forTrack)
        local profile = ns:GetCurrentProfile()
        local parts = {}
        local targetMin = forTrack and ns.GEAR_TRACKS[forTrack] and ns.GEAR_TRACKS[forTrack][1] or 0
        local lowestKey, highestKey
        for _, entry in ipairs(ns.DUNGEON_LOOT) do
            local keyNum = tonumber(entry.key:match("M(%d+)"))
            if keyNum and keyNum <= profile.maxKeyLevel and entry.loot >= targetMin then
                if not lowestKey then lowestKey = keyNum end
                highestKey = keyNum
            end
        end
        if lowestKey and highestKey then
            if lowestKey == highestKey then
                table.insert(parts, "M+" .. lowestKey)
            else
                table.insert(parts, "M+" .. lowestKey .. "-" .. highestKey)
            end
        end
        local raidTrack = ns.RAID_TRACKS[profile.raidTier]
        if raidTrack and ns.TRACK_RANK[raidTrack] and ns.TRACK_RANK[forTrack]
           and ns.TRACK_RANK[raidTrack] >= ns.TRACK_RANK[forTrack] then
            table.insert(parts, profile.raidTier .. " raid")
        end
        return #parts > 0 and table.concat(parts, " / ") or "content"
    end

    -- Only suggest saving if the item is at a LOW rank (1-3/6) AND
    -- the crests being spent are precious (limited supply) AND
    -- the item is above the overlap zone (not from a free promotion).
    -- Items at/below the overlap rank (e.g. Hero 2/6 from Champion 6/6
    -- promotion) are already "paid for" with cheaper crests — upgrade them.
    if farmTrack and isPrecious then
        if farmTrackRank > itemTrackRank then
            -- Content drops a higher track — this item will be replaced
            local source = GetSourceHint(farmTrack)
            return ns.RECOMMEND.SAVE_FOR_DROP,
                farmTrack .. " drops from " .. source ..
                " — save " .. crestTrack .. " crests, wait for replacement"
        elseif farmTrackRank == itemTrackRank and rank < farmRankInTrack then
            -- Same track, but content drops a higher rank — wait for the drop
            -- e.g. Hero 2/6 when M+ drops Hero 3/6
            local savedCost = (farmRankInTrack - rank) * crestCost
            local source = GetSourceHint(track)
            return ns.RECOMMEND.SAVE_FOR_DROP,
                track .. " " .. farmRankInTrack .. "/6 drops from " .. source ..
                " — save " .. savedCost .. " " .. crestTrack .. " crests"
        end
    end

    -- ============================================================
    -- RULE 5: Maxed track — need a higher track drop
    -- ============================================================
    if rank == maxRank then
        local nextTrackIdx = ns.TRACK_RANK[track] and ns.TRACK_RANK[track] + 1 or nil
        local nextTrack = nextTrackIdx and ns.TRACK_ORDER[nextTrackIdx]
        if nextTrack then
            return ns.RECOMMEND.WAIT_BETTER,
                "Fully upgraded — need a " .. nextTrack .. " drop to go higher"
        end
    end

    -- ============================================================
    -- RULE 5.5: Achievement completion priority
    -- Check each missing achievement (lowest first). If this slot
    -- is below the threshold and can be upgraded to reach it,
    -- prioritize that. Cross-track items count: e.g. Champion 1/5
    -- at ilvl 246 already satisfies Veteran (max 246).
    -- ============================================================
    for _, achieveTrack in ipairs(ns.TRACK_ORDER) do
        if not ns:HasDiscountAchievement(achieveTrack) then
            local achieveIlvl = ns:GetMaxIlvlForTrack(achieveTrack)
            if ilvl < achieveIlvl then
                -- This slot is below the achievement threshold
                local slotsRemaining, totalAchieveCost, upgradeableCount, slots =
                    ns:GetAchievementProgress(achieveTrack)

                -- Only recommend if all remaining slots are upgradeable (no drops needed)
                if slotsRemaining > 0 and slotsRemaining == upgradeableCount then
                    -- Find this slot's specific cost
                    local thisSlotCost = 0
                    local thisSlotCrestTrack = crestTrack
                    for _, s in ipairs(slots) do
                        if s.slotID == slotID then
                            thisSlotCost = s.crestCost
                            thisSlotCrestTrack = s.crestTrack or crestTrack
                            break
                        end
                    end

                    local achieveName = ns:GetDiscountAchievementName(achieveTrack)
                    if slotsRemaining == 1 then
                        return ns.RECOMMEND.UPGRADE_NOW,
                            "Last slot for " .. achieveName .. "! 50% off for alts (" ..
                            thisSlotCost .. " " .. thisSlotCrestTrack .. ")"
                    else
                        return ns.RECOMMEND.UPGRADE_NOW,
                            slotsRemaining .. " slots to " .. achieveName ..
                            " — 50% off for alts (" .. totalAchieveCost .. " crests total)"
                    end
                end
            end
            break -- Only chase the lowest missing achievement
        end
    end

    -- ============================================================
    -- RULE 6-8: Where this slot falls in the track's spend plan.
    --
    -- Crests are track-locked, so the only competition for this wallet
    -- is the other slots on this same track. ns:GetCrestPlan spends the
    -- whole budget once, rank by rank, best slot first -- so instead of
    -- re-deriving a private opinion here, this reads off the plan and
    -- reports the slot's actual position in it.
    --
    -- Reasons are written to be read at a glance and to survive two
    -- lines in a narrow panel: what it costs, whether the crests in the
    -- wallet reach it, and if not, what is ahead of it. The old strings
    -- appended a raw "140/340 Veteran (+0)" to an unrelated clause,
    -- which is the thing that made this panel unreadable.
    -- ============================================================
    local plan = ns:GetCrestPlan(crestTrack)
    local mine = plan and plan.slots and plan.slots[slotID]

    if not plan or not mine then
        -- No plan (unknown crest track, or the slot dropped out of the
        -- candidate scan between calls). Say the plain cost rather than
        -- inventing a position in an order that does not exist.
        return ns.RECOMMEND.UPGRADE_NOW,
            "Next rank costs " .. crestCost .. " " .. crestTrack
    end

    -- "Main Hand and Chest first" / "Head first". No verb: it had to
    -- agree with the number of slots named, and dropping it buys back
    -- five characters on a line the panel was already truncating.
    local function JoinSlots(names)
        if #names == 0 then return "better slots" end
        if #names == 1 then return names[1] end
        return names[1] .. " and " .. names[2]
    end

    ------------------------------------------------------------
    -- Nothing in the wallet reaches this slot: everything ahead of it
    -- in the plan spends the crests first.
    ------------------------------------------------------------
    if mine.paidRanks == 0 then
        local who = JoinSlots(ns:GetCrestPlanBlockers(plan, slotID, 2))
        -- Against spendable, not held. With a reserve in play the crests
        -- sitting in the wallet are deliberately not on the table, and
        -- measuring the gap against them produced "0 more Adventurer
        -- covers this one too" on a slot that plainly was not covered.
        local short = math.max((mine.crestsBefore or 0) + crestCost - plan.spendable, 0)

        -- Where the shortfall is going to come from.
        --
        -- "80 more Champion covers this one too" reads as an instruction
        -- to go and farm Champion, and on a wallet the content has
        -- outgrown that is the wrong instinct entirely: nothing the
        -- player runs pays this tier directly any more. It still
        -- arrives -- capping a higher track spills its income down a
        -- tier -- but as a by-product of content that pays something
        -- else, which is a different plan for the week.
        if plan.spendable >= crestCost then
            -- Affordable on its own, but only by taking the crests off a
            -- slot worth more. This is the case the old "Hold crests"
            -- fired on; it now names which slot, and what closing the
            -- gap would cost.
            return ns.RECOMMEND.HOLD_CRESTS,
                who .. " first — " .. short .. " more " .. crestTrack ..
                " covers this"
        end
        return ns.RECOMMEND.UPGRADE_LATER,
            "Need " .. short .. " more " .. crestTrack .. " — " ..
            who .. " first"
    end

    ------------------------------------------------------------
    -- Funded. Say what the crests buy, and what the player keeps.
    --
    -- Two separate questions, and the old strings answered only the
    -- first. "292 to 295 -- 3 of 5 ranks, to 302" describes a purchase
    -- without saying whether any of it survives contact with the next
    -- drop, which is the only thing that decides if it was worth making.
    --
    -- Ranks are planned in runs now, so the run is what gets named: the
    -- level it starts at, the level it reaches, and how much of the slot
    -- that covers. The old form previewed one rank and then described a
    -- different number of them in the same breath.
    ------------------------------------------------------------
    local reach = mine.paidIlvl or ilvl
    local runStr = (reach > ilvl) and (ilvl .. " to " .. reach)
        or ("rank " .. (rank + 1))

    local buys
    if mine.paidRanks >= mine.wantedRanks then
        buys = "all " .. mine.wantedRanks ..
            (mine.wantedRanks == 1 and " rank" or " ranks")
    else
        buys = mine.paidRanks .. " of " .. mine.wantedRanks .. " ranks"
    end

    ------------------------------------------------------------
    -- What survives the next drop, in one clause.
    --
    -- The slot keeps a high-water mark, so a future piece landing in it
    -- is free up to the level already reached. That makes the drop BAND
    -- -- not a single ceiling -- decide what a spend is worth:
    --
    --   above the band   nothing the player runs hands this out, so the
    --                    rank is theirs permanently.
    --   inside it        the mark promotes an incoming piece from the
    --                    weaker source up to here for nothing, so the
    --                    spend comes back as a rebate on that drop.
    --   below it         any drop clears it and the mark never applies.
    --
    -- And above all of them, reaching the track's cap: the piece moves
    -- onto the next track, so the slot stops being capped where this
    -- track ends. That is the one outcome worth leading with, and the
    -- shipped strings had no way to say it at all.
    --
    -- The old code chose between this clause and the "spend here first"
    -- lead, and first won -- so a weapon and a trinket in identical
    -- positions got opposite advice, one silently reassured and the
    -- other warned about. They are different facts about different
    -- questions and both are printed now.
    ------------------------------------------------------------
    local label, outcome = ns.RECOMMEND.UPGRADE_NOW, ""
    if mine.promotes and mine.promotesTo and (plan.markRanks or 0) > 0 then
        -- The item stops at the cap. What carries on is the slot: its
        -- mark now sits at this level, so the next piece to land there
        -- is lifted to it for nothing.
        outcome = " — caps the track, next " .. mine.promotesTo ..
            " free to " .. mine.paidIlvl
    elseif mine.promotes then
        outcome = " — caps the track"
    elseif mine.stickyRanks > 0 and (plan.bandHigh or 0) > 0 then
        outcome = " — clears your " .. plan.bandHigh .. " drops, so it sticks"
    elseif mine.bankedRanks > 0 and (plan.bandLow or 0) > 0 then
        outcome = " — over " .. plan.bandLow .. ", refunded when a " ..
            plan.bandLow .. " drops"
    elseif (plan.bandLow or 0) > 0 then
        -- Nothing bought here outlives a drop. Still worth doing when
        -- the crests have nowhere better to be -- which on an outgrown
        -- wallet is always -- but the player should know they are
        -- renting it.
        label = ns.RECOMMEND.SAFE_TEMP
        outcome = " — under your " .. plan.bandLow ..
            " floor, so a drop replaces it"
    end

    -- Which wallet this is the best use of, not which row is the most
    -- important on the page. Crests are track-locked, so every track has
    -- a best spend, and the shipped string claimed each of them was THE
    -- first -- two rows under "Spend here first" on one panel.
    --
    -- The lead names the currency, so the price after it does not have
    -- to. Every character here is one the panel was cutting off.
    local price, lead = mine.paidCost .. " " .. crestTrack, ""
    if mine.firstStep and mine.firstStep <= 1 then
        lead  = "Best " .. crestTrack .. ": "
        price = tostring(mine.paidCost)
    end

    ------------------------------------------------------------
    -- The long version, for the hover.
    --
    -- What this is NOT: a description of the upgrade system. An earlier
    -- pass filled this with true sentences about how tracks and marks
    -- work -- "Champion tops out at 308 and the item stops there" --
    -- which is a rule the player did not ask to be taught, dressed up
    -- as advice. Nobody hovers a recommendation to find out how the game
    -- works. They hover it to find out why THIS one.
    --
    -- So every line here is a consequence for this character: what the
    -- spend finishes, what it makes cheaper later, and how much closer
    -- it gets them to never needing this crest again. The mechanics are
    -- still in there, but stated as what they do rather than what they
    -- are -- "a Hero piece landing here would start at 308" says the
    -- same thing as a paragraph about high-water marks, and says it
    -- about the player's own weapon.
    ------------------------------------------------------------
    local detail = {}
    local finish = ns.GetTrackCompletion and ns:GetTrackCompletion(crestTrack)

    -- 1. What it does to this slot.
    if mine.promotes then
        detail[#detail + 1] = "Maxes " .. (mine.slotName or "this slot") ..
            " — the last " .. mine.paidRanks ..
            (mine.paidRanks == 1 and " rank " or " ranks ") .. crestTrack ..
            " can give it, for " .. mine.paidCost .. " crests."
    else
        local shortBy = mine.wantedRanks - mine.paidRanks
        detail[#detail + 1] = "Takes " .. (mine.slotName or "this slot") ..
            " to " .. mine.paidIlvl .. ", " .. shortBy ..
            (shortBy == 1 and " rank " or " ranks ") .. "short of the " ..
            ns:GetMaxIlvlForTrack(track) .. " cap."
    end

    -- 2. What it buys on the piece that replaces it.
    if mine.promotes and mine.promotesTo and (plan.markRanks or 0) > 0 then
        -- Said in ranks, because that is how the game shows gear and
        -- how players talk about it. "308 instead of 305" is the same
        -- fact in a unit nobody carries in their head.
        local saved = plan.markRanks * ns:GetCrestCost(mine.promotesTo)
        local ranks = #(ns.GEAR_TRACKS[mine.promotesTo] or {})
        detail[#detail + 1] = "The next " .. mine.promotesTo ..
            " piece to land here then starts at " .. plan.markRank .. "/" ..
            ranks .. " instead of " .. plan.dropRank .. "/" .. ranks ..
            " — " .. saved .. " " .. mine.promotesTo .. " you never spend."
    elseif mine.stickyRanks > 0 then
        detail[#detail + 1] = "Nothing you run drops above " ..
            plan.bandHigh .. ", so this one is yours to keep."
    elseif (plan.bandLow or 0) > 0 and mine.bankedRanks == 0 then
        detail[#detail + 1] = "It sits under the " .. plan.bandLow ..
            " you get handed, so the next piece to drop here simply "
            .. "replaces it — worth doing only because these crests have "
            .. "nowhere better to go."
    end

    -- 3. The track, in one sentence that ends in a conclusion.
    --
    -- This was five: a progress count, a shortfall, the shape of what
    -- was left, a drops-or-crests verdict and a warning against saving
    -- up. All true, and reading them was a briefing rather than a tip.
    --
    -- The shortfall in particular was stated and left there. "260 short"
    -- is not something anyone can act on; "about 3 weeks, or a drop in
    -- any of them" is the same fact with the decision already made.
    if finish and finish.needCrest > 0 then
        local after = math.max(finish.needCrest - (mine.promotes and 1 or 0), 0)
        local rest  = math.max(finish.cost - mine.paidCost, 0)
        local left  = math.max(finish.held - mine.paidCost, 0)

        -- Two short sentences, not one with three clauses hung off it.
        -- The compressed version -- "4 pieces and 400 crests left against
        -- 140 in hand, and it only comes in behind Hero now, so a drop in
        -- those slots is the faster route" -- packs the state, the
        -- income model and the verdict into a single breath, and none of
        -- the three survives it.
        local state = after .. " more " .. crestTrack ..
            (after == 1 and " piece" or " pieces") .. " to max would cost " ..
            rest .. ", and you have " .. left .. "."

        ------------------------------------------------------------
        -- The cap is the constraint, not where the crest comes from.
        --
        -- This used to tell an outgrown track that "you only earn
        -- Champion once Hero caps", which is simply false. Champion is
        -- on offer all season -- M0, low keys, delves, the weekly
        -- outdoor stuff -- and a player 60 short of their cap will find
        -- those 60 without help. What they cannot do is exceed the cap,
        -- and that is the only thing standing between them and the rest
        -- of the track.
        --
        -- Which is also why this no longer branches on `outgrown`. The
        -- allowance grows at the same rate on every track, so the answer
        -- is the same shape whether or not the content has moved past
        -- it. Outgrown still decides what a rank is WORTH -- rental
        -- against banked -- and it has no business making claims about
        -- income.
        ------------------------------------------------------------
        if after == 0 then
            detail[#detail + 1] = "That is the last " .. crestTrack ..
                " piece — after this you never need one again."
        elseif rest <= left then
            detail[#detail + 1] = state .. " Enough for all of them, and "
                .. "then you are done with " .. crestTrack .. " for good."
        elseif finish.withinAllowance then
            detail[#detail + 1] = state .. " The other " ..
                (rest - left) .. " is still inside this season's cap, so it "
                .. "is content to run rather than a wait."
        else
            detail[#detail + 1] = state .. " The cap allows " ..
                finish.earnable .. " more this season, so about " ..
                finish.weeks .. " weeks — or a drop finishes any of them sooner."
        end
    end

    -- 4. The trap, and only when it is actually set.
    --
    -- Spending down to nothing on a deep climb while a piece two ranks
    -- from its cap goes unfunded is the mistake that costs a week: the
    -- cheap one sets its slot's mark for a fraction of the price, and
    -- once the wallet is empty and the season cap is reached there is no
    -- way to go back for it until reset.
    --
    -- The run scoring already prefers cheap completions, so this fires
    -- rarely -- when a high-priority deep run outbids one. That is
    -- exactly when it is worth saying.
    local stranded, shortBy
    for otherID, sum in pairs(plan.slots or {}) do
        if otherID ~= slotID and sum.paidRanks == 0 and sum.wantedRanks > 0
            and sum.wantedRanks <= 2 then
            local need = sum.wantedRanks * crestCost
            if not shortBy or need < shortBy then
                stranded, shortBy = sum.slotName, need
            end
        end
    end
    if stranded and mine.paidRanks > 0 then
        detail[#detail + 1] = "Leaves " .. stranded .. " " .. shortBy ..
            " short of its own cap" ..
            (plan.seasonCapped and ", and the season cap is reached — that one "
                .. "waits for reset." or " — cheap, so do it before anything deeper.")
    end

    return label, lead .. price .. " for " .. runStr .. ", " .. buys .. outcome,
        detail
end

------------------------------------------------------------
-- Ranking: most worth doing, first.
--
-- Two panels draw this list -- the vendor window and the shell's Gear
-- page -- and neither agreed with the other about order. The shell's
-- did not sort at all: it walked ns.SLOT_IDS, so the one slot actually
-- worth spending on today appeared wherever Feet happens to sit in the
-- equipment list, three rows below advice that says to do nothing. A
-- second private sort in the caller would have drifted from the first
-- the same way the reasons did, so the order lives here and both read it.
--
-- The list answers one question per row -- should crests go into this
-- slot right now -- and it is ordered by the answer. Yes and free, yes,
-- yes but it will be overtaken, not yet, no.
--
-- The warnings sat at the top on the theory that a spend you are about
-- to regret is urgent. That reads backwards in a list titled
-- Improvements: "Wasteful crest spend" is a slot to keep crests OUT of,
-- and putting it above three slots to put crests INTO contradicts the
-- ordering the rest of the list follows. It also put the only red row
-- on the page at the top, which says "most important" in a list where
-- position already means that.
--
-- Burying it is safe precisely because the order is followed top-down:
-- a player working the list spends on the good slots first and never
-- reaches the wasteful one with crests still in hand. The warning is
-- there when they go looking at that slot, which is when it matters.
ns.RECOMMEND_ORDER = {
    [ns.RECOMMEND.FREE_UPGRADE]    = 1,  -- yes, and it costs nothing
    [ns.RECOMMEND.UPGRADE_NOW]     = 2,  -- yes, spend here
    [ns.RECOMMEND.SAFE_TEMP]       = 3,  -- yes, but a drop overtakes it
    ------------------------------------------------ divider falls here
    [ns.RECOMMEND.HOLD_CRESTS]     = 4,  -- not yet, something first
    [ns.RECOMMEND.UPGRADE_LATER]   = 5,  -- not yet, cannot afford it
    [ns.RECOMMEND.CRAFT_INSTEAD]   = 6,
    [ns.RECOMMEND.USE_LOWER_TRACK] = 7,  -- no, a cheaper crest reaches it
    [ns.RECOMMEND.WASTED_CREST]    = 8,  -- no, and spending here burns a crest
    [ns.RECOMMEND.BAD_INVESTMENT]  = 9,
    [ns.RECOMMEND.SAVE_FOR_DROP]   = 10, -- no, a drop is coming
    [ns.RECOMMEND.CREST_CAPPED]    = 11,
    [ns.RECOMMEND.WAIT_BETTER]     = 12, -- nothing to do at all
    [ns.RECOMMEND.MAXED]           = 13,
    [ns.RECOMMEND.NO_ITEM]         = 14,
}

--- The last rank that is still "spend crests here". Panels draw their
--- divider after it. Named rather than written as a literal in each
--- caller: the two drifted apart once already, and a divider in the
--- wrong place silently reclassifies advice.
ns.RECOMMEND_ACTIONABLE_MAX = 3

--- Sorts `list` (entries from ns:GetAllRecommendations) in place, best
--- first, and returns it.
---
--- Ties inside a label break on the plan: a slot the wallet reaches
--- sooner is the one to do first. That position is per-track, though,
--- and a Champion queue position is not comparable to an Adventurer
--- one -- so it only decides between slots on the SAME track, and
--- everything else falls through to how much the slot is worth and how
--- close it is to being affordable.
function ns:SortRecommendations(list)
    local rank, gap, track = {}, {}, {}
    for _, r in ipairs(list) do
        local crestTrack = nil
        local up = select(2, ns:CanUpgradeItem(r.slotID))
        if up then crestTrack = ns.TRACK_CREST[up.track] end
        track[r.slotID] = crestTrack

        local plan = crestTrack and ns:GetCrestPlan(crestTrack)
        local mine = plan and plan.slots and plan.slots[r.slotID]
        rank[r.slotID] = mine and mine.firstStep or math.huge
        -- How far out of reach: zero for anything already covered, so
        -- funded slots never sort behind unfunded ones on this key.
        gap[r.slotID] = (mine and mine.paidRanks == 0 and plan)
            and math.max((mine.crestsBefore or 0) + plan.cost - plan.spendable, 0)
            or 0
    end

    table.sort(list, function(a, b)
        local oa = ns.RECOMMEND_ORDER[a.recommendation] or 99
        local ob = ns.RECOMMEND_ORDER[b.recommendation] or 99
        if oa ~= ob then return oa < ob end

        -- Same track: the plan already decided which comes first.
        if track[a.slotID] and track[a.slotID] == track[b.slotID]
            and rank[a.slotID] ~= rank[b.slotID] then
            return rank[a.slotID] < rank[b.slotID]
        end

        -- Across tracks: whichever is closer to being affordable.
        if gap[a.slotID] ~= gap[b.slotID] then
            return gap[a.slotID] < gap[b.slotID]
        end

        local pa = ns.SLOT_PRIORITY[a.slotID] or 2
        local pb = ns.SLOT_PRIORITY[b.slotID] or 2
        if pa ~= pb then return pa > pb end
        -- Slot id last, so the order is stable between refreshes rather
        -- than reshuffling with whatever table iteration produced.
        return (a.slotID or 0) < (b.slotID or 0)
    end)
    return list
end

--- Every slot worth showing, already ranked. The list panels want.
function ns:GetRankedRecommendations()
    local recs = ns:GetAllRecommendations()
    local list = {}
    for _, si in ipairs(ns.SLOT_IDS or {}) do
        local r = recs[si.slot]
        if r and r.recommendation
            and r.recommendation ~= ns.RECOMMEND.NO_ITEM
            and r.recommendation ~= ns.RECOMMEND.MAXED then
            list[#list + 1] = r
        end
    end
    return ns:SortRecommendations(list)
end

------------------------------------------------------------
-- Batch: get recommendations for all slots
------------------------------------------------------------
function ns:GetAllRecommendations()
    local results = {}
    for _, slotInfo in ipairs(ns.SLOT_IDS) do
        -- The third return is the hover. Rules that have nothing more to
        -- say than their one line simply do not return one, and the
        -- panel shows the line alone.
        local rec, reason, detail = ns:GetRecommendation(slotInfo.slot)
        results[slotInfo.slot] = {
            recommendation = rec,
            reason = reason,
            detail = detail,
            slotName = slotInfo.name,
            slotID = slotInfo.slot,
        }
    end
    return results
end
