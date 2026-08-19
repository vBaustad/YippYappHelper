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
    SAFE_TEMP         = { label = "Safe temporary upgrade",  color = "ff88bbff" }, -- light blue
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
                    risk     = risk,
                    -- Low sorts first. A slot the content is about to
                    -- replace is a worse home for a scarce crest than an
                    -- equally important slot that will keep it, and the
                    -- ORDER is where that belongs -- not in a label that
                    -- says "spend here last" on the slot the plan just
                    -- funded first. That contradiction is what this is.
                    riskRank = (risk == "high" and 2)
                        or (risk == "moderate" and 1) or 0,
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

    -- The walk. Pick the best remaining candidate, buy it one rank, repeat.
    local spent = 0
    while true do
        local best
        for _, c in ipairs(candidates) do
            if c.rank < c.maxRank then
                -- Priority, then replacement risk, then item level,
                -- then slot id. The last key is not cosmetic: two rings
                -- of the same priority and level would otherwise swap
                -- places with table iteration order, and the panel would
                -- reshuffle itself between refreshes.
                local function better(a, b)
                    if not b then return true end
                    if a.priority ~= b.priority then return a.priority > b.priority end
                    if a.riskRank ~= b.riskRank then return a.riskRank < b.riskRank end
                    if a.ilvl ~= b.ilvl then return a.ilvl < b.ilvl end
                    return a.slotID < b.slotID
                end
                if better(c, best) then best = c end
            end
        end
        if not best then break end

        best.rank = best.rank + 1
        best.ilvl = (best.levels and best.levels[best.rank]) or best.ilvl
        spent = spent + cost

        local summary = plan.slots[best.slotID]
        local step = {
            slotID     = best.slotID,
            slotName   = best.slotName,
            rank       = best.rank,
            maxRank    = best.maxRank,
            toIlvl     = best.ilvl,
            cumulative = spent,
            funded     = spent <= budget,
            -- Against spendable, not held: the reserve is deliberately
            -- not planned, so a step it would have paid for is not one
            -- the panel should show above the line.
            paid       = spent <= plan.spendable,
            -- Does this rank survive a drop? The slot's high-water mark
            -- makes any future item in it free up to the level reached,
            -- so a rank landing ABOVE what the player's content drops is
            -- banked permanently, and one landing below is overtaken by
            -- the next piece that falls in that slot.
            sticks     = best.ilvl > ceiling,
        }
        plan.steps[#plan.steps + 1] = step

        if not summary.firstStep then
            summary.firstStep    = #plan.steps
            -- Everything bought before this slot's first rank is what a
            -- "these come first" explanation has to name.
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
    local replacementRisk = ns:GetReplacementRisk(slotID, ilvl)
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

    -- "Main Hand and Chest come first" / "Head comes first". Worth the
    -- three lines: the panel prints this on most of its rows, and a list
    -- that disagrees with its own verb reads as a bug in the advice.
    local function JoinSlots(names)
        if #names == 0 then return "better slots", "come" end
        if #names == 1 then return names[1], "comes" end
        return names[1] .. " and " .. names[2], "come"
    end

    local nextIlvl = ns.GEAR_TRACKS[track] and ns.GEAR_TRACKS[track][rank + 1]
    local step = nextIlvl and (ilvl .. " to " .. nextIlvl) or ("rank " .. (rank + 1))

    ------------------------------------------------------------
    -- Nothing in the wallet reaches this slot: everything ahead of it
    -- in the plan spends the crests first.
    ------------------------------------------------------------
    if mine.paidRanks == 0 then
        local who, verb = JoinSlots(ns:GetCrestPlanBlockers(plan, slotID, 2))
        -- Against spendable, not held. With a reserve in play the crests
        -- sitting in the wallet are deliberately not on the table, and
        -- measuring the gap against them produced "0 more Adventurer
        -- covers this one too" on a slot that plainly was not covered.
        local short = math.max((mine.crestsBefore or 0) + crestCost - plan.spendable, 0)

        if plan.spendable >= crestCost then
            -- Affordable on its own, but only by taking the crests off a
            -- slot worth more. This is the case the old "Hold crests"
            -- fired on; it now names which slot, and what closing the
            -- gap would cost.
            return ns.RECOMMEND.HOLD_CRESTS,
                who .. " " .. verb .. " first — " .. short .. " more " ..
                crestTrack .. " covers this one too"
        end
        return ns.RECOMMEND.UPGRADE_LATER,
            "Need " .. short .. " more " .. crestTrack .. " — " ..
            who .. " " .. verb .. " first"
    end

    ------------------------------------------------------------
    -- Funded. Say what the crests buy here and what that costs.
    ------------------------------------------------------------
    -- The target level is only worth naming when it is not already the
    -- level the step's own "279 to 282" just gave. Buying a single rank
    -- otherwise reads "279 to 282 -- 1 of 5 ranks, to 282".
    local buys
    if mine.paidRanks == mine.wantedRanks then
        buys = "all " .. mine.wantedRanks ..
            (mine.wantedRanks == 1 and " rank to " or " ranks to ") .. mine.paidIlvl
    elseif mine.paidRanks == 1 then
        buys = "1 of " .. mine.wantedRanks .. " ranks"
    else
        buys = mine.paidRanks .. " of " .. mine.wantedRanks .. " ranks, to " .. mine.paidIlvl
    end
    -- Against spendable, not held. With a reserve in play "60 of your
    -- 100 Champion" describes a wallet the plan has already decided is
    -- only 60 -- two numbers for one thing, in adjacent sentences.
    local spendStr = mine.paidCost .. " of your " .. plan.spendable ..
        " " .. crestTrack
    if plan.reserve > 0 then spendStr = spendStr .. " to spend" end

    -- Whether a spend survives a drop is not the same question as
    -- whether the item does.
    --
    -- The slot keeps a high-water mark, so any future piece in it is
    -- free up to the level already reached. A rank that lands ABOVE
    -- what the player's content drops is therefore banked permanently:
    -- the replacement arrives and is immediately promoted to it for no
    -- crests. A rank that lands below is the one that gets overtaken --
    -- the drop is simply better, and the mark never comes into play.
    --
    -- This is why the old advice was backwards. It warned loudest about
    -- deep upgrades, which are the ones the mark protects, and stayed
    -- quiet about shallow ones, which are the ones a drop erases.
    local overtaken = (mine.paidRanks > 0) and (mine.stickyRanks == 0)
        and (mine.risk == "high")
    local isFirst = mine.firstStep and mine.firstStep <= 1

    local sticksNote = ""
    if mine.stickyRanks > 0 and plan.ceiling and plan.ceiling > 0 then
        sticksNote = " — clears the " .. plan.ceiling ..
            " your content drops, so the slot keeps it"
    end

    if isFirst then
        return ns.RECOMMEND.UPGRADE_NOW,
            "Spend here first: " .. step .. ", " .. buys ..
            " (" .. spendStr .. ")" .. sticksNote
    end

    if overtaken then
        return ns.RECOMMEND.SAFE_TEMP,
            step .. " — " .. buys .. ", but stays under the " .. (plan.ceiling or 0) ..
            " your content drops, so a piece will overtake it (" .. spendStr .. ")"
    end

    return ns.RECOMMEND.UPGRADE_NOW,
        step .. " — " .. buys .. " (" .. spendStr .. ")" .. sticksNote
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
        local rec, reason = ns:GetRecommendation(slotInfo.slot)
        results[slotInfo.slot] = {
            recommendation = rec,
            reason = reason,
            slotName = slotInfo.name,
            slotID = slotInfo.slot,
        }
    end
    return results
end
