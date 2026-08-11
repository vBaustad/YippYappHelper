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

-- Account-wide achievement IDs for 50% crest cost discount (Midnight S1)
-- When unlocked, upgrades of that crest type cost 10 instead of 20 on alts
ns.DISCOUNT_ACHIEVEMENTS = {
    Adventurer = 61809, -- Adventurer of the Dawn
    Veteran    = 42767, -- Veteran of the Dawn
    Champion   = 42768, -- Champion of the Dawn
    Hero       = 42769, -- Hero of the Dawn
    Myth       = 42770, -- Myth of the Dawn
}

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

------------------------------------------------------------
-- Replacement risk assessment
------------------------------------------------------------
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
    local slotPriority = ns.SLOT_PRIORITY[slotID] or 2
    local replacementRisk = ns:GetReplacementRisk(slotID, ilvl)
    local isFree = ns:IsCrestFree(crestTrack)
    local isPrecious = ns:IsCrestPrecious(crestTrack)
    local trackRank = ns.TRACK_RANK[track] or 1
    local rank = upgradeInfo.currUpgrade
    local maxRank = upgradeInfo.maxUpgrade

    local crestCost = ns:GetCrestCost(crestTrack)
    local affordable = ns:GetAffordableUpgrades(crestTrack)
    local crestCount = ns:GetCrestCountByTrack(crestTrack)
    local upgradesNeeded = maxRank - rank
    local totalCost = upgradesNeeded * crestCost
    local totalBudget = ns:GetTotalCrestBudget(crestTrack)
    local earnable = ns:GetEarnableCrests(crestTrack)

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
                waste.fromIlvl .. "→" .. waste.toIlvl .. " — a maxed " ..
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

                    local achieveName = achieveTrack .. " of the Dawn"
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
    -- Crests can ONLY be spent on their own track's gear.
    -- The question is: which items on this track to prioritize.
    -- "Precious" means limited supply — prioritize high-value slots.
    -- "Free" means abundant — upgrade everything.
    -- ============================================================
    -- Afford string: show current/needed, plus earnable if relevant
    local affordStr
    if affordable >= upgradesNeeded then
        affordStr = ", " .. totalCost .. " " .. crestTrack
    elseif earnable > 0 then
        affordStr = ", " .. crestCount .. "/" .. totalCost .. " " .. crestTrack .. " (+" .. earnable .. ")"
    else
        affordStr = ", " .. crestCount .. "/" .. totalCost .. " " .. crestTrack .. " (capped)"
    end

    -- Calculate total crests needed for ALL items on this track
    local totalTrackCost = 0
    for _, si in ipairs(ns.SLOT_IDS) do
        local canUp2, upInfo2 = ns:CanUpgradeItem(si.slot)
        if canUp2 and upInfo2 then
            local t2 = upInfo2.track or ns:GetTrackFromIlvl(upInfo2.currIlvl)
            if ns.TRACK_CREST[t2] == crestTrack then
                totalTrackCost = totalTrackCost + (upInfo2.maxUpgrade - upInfo2.currUpgrade) * crestCost
            end
        end
    end
    -- Are crests scarce? (total budget can't cover all items on this track)
    local crestsScarce = totalBudget < totalTrackCost

    -- ============================================================
    -- Calculate upgrade priority rank among all upgradeable items
    -- on the same crest track, sorted by slot priority descending.
    -- Also track crest budget reserved for higher-priority items.
    -- ============================================================
    local upgradeRank = 1
    local sameTrackCount = 0
    local reservedForHigher = 0
    local topSlotName = nil
    for _, si in ipairs(ns.SLOT_IDS) do
        local canUp2, upInfo2 = ns:CanUpgradeItem(si.slot)
        if canUp2 and upInfo2 then
            local t2 = upInfo2.track or ns:GetTrackFromIlvl(upInfo2.currIlvl)
            local ct2 = ns.TRACK_CREST[t2]
            if ct2 == crestTrack then
                sameTrackCount = sameTrackCount + 1
                local pri2 = ns.SLOT_PRIORITY[si.slot] or 2
                -- Only count as higher rank if STRICTLY higher priority
                if pri2 > slotPriority then
                    upgradeRank = upgradeRank + 1
                    -- Track crests needed to max all higher-priority items
                    local cost2 = (upInfo2.maxUpgrade - upInfo2.currUpgrade) * crestCost
                    reservedForHigher = reservedForHigher + cost2
                    if not topSlotName then topSlotName = si.name end
                end
            end
        end
    end

    -- e.g. "priority #2 of 5" — refers to item priority across the track,
    -- not upgrade ranks (which are always 6). Action verb shown separately.
    local rankStr
    if sameTrackCount <= 1 then
        rankStr = "top priority"
    elseif upgradeRank == 1 then
        rankStr = "top priority of " .. sameTrackCount
    else
        rankStr = "priority #" .. upgradeRank .. " of " .. sameTrackCount
    end

    -- Would spending on this item leave enough for higher-priority items?
    local budgetAfterSpend = totalBudget - crestCost
    local wouldStarveHigher = reservedForHigher > 0 and budgetAfterSpend < reservedForHigher

    -- ============================================================
    -- RULE 6-8: Prioritize by slot value + crest budget
    -- Top priority items upgrade freely. Lower priority items check
    -- that spending here won't prevent maxing higher-priority gear.
    -- ============================================================
    if upgradeRank <= 2 then
        if replacementRisk == "high" then
            return ns.RECOMMEND.SAFE_TEMP, rankStr .. " — may get replaced" .. affordStr
        end
        return ns.RECOMMEND.UPGRADE_NOW, rankStr .. affordStr
    elseif wouldStarveHigher then
        -- Spending here would leave too few crests for top-priority items
        return ns.RECOMMEND.HOLD_CRESTS,
            "Save " .. crestTrack .. " for " .. (topSlotName or "top slots") ..
            " (" .. reservedForHigher .. " needed)" .. affordStr
    elseif upgradeRank <= 4 then
        if crestsScarce then
            return ns.RECOMMEND.UPGRADE_LATER, rankStr .. " — crests are limited" .. affordStr
        end
        return ns.RECOMMEND.UPGRADE_NOW, rankStr .. affordStr
    else
        if crestsScarce then
            return ns.RECOMMEND.UPGRADE_LATER, rankStr .. " — upgrade top slots first" .. affordStr
        end
        return ns.RECOMMEND.UPGRADE_LATER, rankStr .. affordStr
    end
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
