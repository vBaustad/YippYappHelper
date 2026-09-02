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

-- Cache achievement status.
--
-- Once per session was once too few. The discount is account-wide and
-- earned by crossing an item level in every slot, which is a thing that
-- happens WHILE the player is looking at this panel -- and the answer
-- was cached false from login, so the prices stayed doubled until a
-- reload. That is the one moment the numbers matter most: somebody has
-- just crossed a threshold and is deciding what to spend next.
local discountCache = {}

--- Forget the cached achievement answers. For ACHIEVEMENT_EARNED.
function ns:InvalidateDiscountCache()
    wipe(discountCache)
end

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
local function MarkRebate(track, bandLow, bandHigh)
    local nextTrack = ns.TRACK_ORDER[(ns.TRACK_RANK[track] or 0) + 1]
    if not nextTrack then return 0, nil, 0 end

    local nextLevels = ns.GEAR_TRACKS[nextTrack]
    local markIlvl = ns:GetMaxIlvlForTrack(track)
    if not nextLevels or markIlvl <= 0 then return 0, nextTrack, 0 end

    -- The mark is insurance, and the previous pass threw it away.
    --
    -- Gating this on the HIGH end of the band -- "you farm 311 in every
    -- slot, so a 308 mark is always overtaken" -- is true and useless.
    -- Of course better gear exists; the whole season is the trip to it.
    -- The question is what to do on the way, and the answer is that some
    -- Hero pieces arrive at 1/6, and a slot marked at 308 starts those
    -- at 2/6 instead.
    --
    -- So it pays out against the LOW end: the weakest source that can
    -- fill the slot is the one the mark rescues.

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

    -- Priced as item level rather than as crests, so it can be added to
    -- what the run buys instead of discounting what it costs.
    --
    -- That distinction is the whole fix. As a cost discount the rebate
    -- helped the EXPENSIVE runs most -- a hundred crests knocked down to
    -- seventy-three still looked like a bargain -- which is exactly
    -- backwards. The insurance is the same size whether the piece was
    -- one rank from its cap or five; only the price of it changes. As a
    -- fixed term over a varying cost, the cheap mark wins by the margin
    -- it should.
    local nextLadder = ns:GetMaxIlvlForTrack(nextTrack) - nextLevels[1]
    local perRank = nextLadder / math.max(#nextLevels - 1, 1)
    return ranks * perRank, nextTrack, ranks, markRank, dropRank
end

local planCache = {}
local seasonCache = {}
-- Filled by ns:GetCraftPlan below, declared up here so
-- InvalidateCrestPlans can clear it with the rest.
local craftCache = nil

-- A slot's mark does not depend on which crest is asking, and reading it
-- does: ns:GetFreeUpgradeIlvl falls through to a bag scan per slot. Five
-- tracks each walking sixteen slots is eighty of those for one panel
-- draw, of which seventy-five are the same answer again. Cleared with
-- the plans, which the suggestions panel does at the top of every
-- refresh -- so this is a per-render cache, not a session-long one that
-- would outlive the bag it read.
local markCache = {}

--- Drop memoised plans. Cheap, and a stale plan is worse than a slow one.
function ns:InvalidateCrestPlans()
    wipe(planCache)
    wipe(seasonCache)
    wipe(markCache)
    -- The craft plan reads the bags for sparks and the doll for what is
    -- already made, so it goes stale on exactly the same events.
    craftCache = nil
end

--- A slot's mark, and whether the client actually answered for it.
---
--- The second return matters to anything quoting a price: with no answer
--- the mark falls back to what the bags can prove, which is a lower
--- bound, and a lower bound used as the line charges for ranks that may
--- already be paid for. See ns:GetMarkRead / ns:GetFreeUpgradeIlvl.
local function SlotMark(slotID)
    local hit = markCache[slotID]
    if hit then return hit[1], hit[2] end
    local mark = ns.GetFreeUpgradeIlvl and ns:GetFreeUpgradeIlvl(slotID) or 0
    local read = (ns.GetMarkRead and ns:GetMarkRead(slotID) or 0) > 0
    markCache[slotID] = { mark, read }
    return mark, read
end

------------------------------------------------------------
-- The crafts the list wants, and what they cost the wallet.
--
-- Everything else in this file prices ONE route to item level: pay a
-- crest, move a rank. The best-in-slot list has always known about a
-- second one -- several specs are told to make a piece rather than kill
-- something for it -- and the crest advisor had never heard of it, so
-- it happily talked a player into spending the exact 80 Hero the craft
-- they are saving for needs.
--
-- What a craft is, in the only terms this file cares about:
--
--   * A Spark of Tides, which the season hands out a fixed number of.
--     That is the real limit -- crests refill, sparks do not -- so
--     nothing here reserves crests for a craft the player cannot
--     actually start today.
--   * ns.CRAFT_CREST_COST of ONE tier's crests, all at once. Not a
--     ladder: the 80 buys the whole piece, which is why it competes
--     with a RUN of upgrades rather than with a single rank.
--   * A landing item level from ns.CRAFTED_RANGES, decided by the
--     crafter's quality rather than by anything the player holds. The
--     advice quotes the top of the range and says "at max quality",
--     because a number without that caveat is a promise about somebody
--     else's profession skill.
--
-- Deliberately NOT a claim about which profession, which recipe, or
-- what the reagents cost in gold. The addon can see the guide's slot,
-- the bags' sparks and the wallet; everything past that belongs to the
-- crafting UI.
------------------------------------------------------------

--- Sparks in the bags: how many crafts the player could start tonight.
---
--- The bags, not Tidal Spark Dust. The dust counts sparks OBTAINED and
--- never goes down, which is exactly what the weekly checklist wants
--- and exactly the wrong number here -- a player who already spent all
--- four would be told to hold crests for a craft they cannot make.
local function SparksInBags()
    if C_Item and C_Item.GetItemCount then
        local ok, n = pcall(C_Item.GetItemCount, ns.SPARK_ITEM_ID)
        if ok and n then return n end
    end
    if GetItemCount then
        local ok, n = pcall(GetItemCount, ns.SPARK_ITEM_ID)
        if ok and n then return n end
    end
    return 0
end

--- The highest track whose max-quality craft would beat `ilvl`, subject
--- to a budget test. Returns nil when no tier clears both.
local function BestCraftTrack(ilvl, affordable)
    for i = #ns.TRACK_ORDER, 1, -1 do
        local track = ns.TRACK_ORDER[i]
        local range = ns.CRAFTED_RANGES[track]
        if range and range.max > ilvl and affordable(track) then
            return track
        end
    end
    return nil
end

--- The addon's own name for an inventory slot.
local function SlotName(slotID)
    for _, si in ipairs(ns.SLOT_IDS or {}) do
        if si.slot == slotID then return si.name end
    end
    return nil
end

--- Every slot the player's own best-in-slot list says to CRAFT, with
--- what a craft would land there and whether it has already happened.
---
--- Memoised with the crest plans, because it walks the guide, sixteen
--- slots and the bags, and every row on the panel asks for it.
function ns:GetCraftPlan()
    if craftCache then return craftCache end

    local out = {
        sparks  = SparksInBags(),
        wanted  = {},   -- guide says craft, nothing crafted there yet
        done    = {},   -- guide says craft, and you made it
        byTrack = {},   -- crestTrack -> the one craft that tier pays for
    }
    craftCache = out

    local key = ns.PlayerSpecKey and ns:PlayerSpecKey()
    local guide = key and ns.ClassGuideData and ns.ClassGuideData[key]
    if not (guide and guide.bis) then return out end

    -- Placed the way the Best in Slot page places them, so "the second
    -- Ring" means the same slot on both pages. A guide that lists more
    -- pieces than the character has slots simply runs out of room, and
    -- the overflow is not a craft anyone can act on.
    local taken = {}
    for _, entry in ipairs(guide.bis) do
        local placed = nil
        for _, invSlot in ipairs(ns.GUIDE_SLOT_INV[entry.slot] or {}) do
            if not taken[invSlot] then
                taken[invSlot], placed = entry, invSlot
                break
            end
        end

        if placed and ns:IsCraftedGuideEntry(entry) then
            local info = ns:GetSlotInfo(placed)
            local worn = (info and info.ilvl) or 0
            local row = {
                slotID   = placed,
                slotName = SlotName(placed) or entry.slot,
                itemID   = entry.itemID,
                wornIlvl = worn,
                crafted  = (info and info.crafted) or false,
            }

            if row.crafted then
                out.done[#out.done + 1] = row
            else
                -- Three answers to "which tier", and they are three
                -- different pieces of advice. `now` is a craft to go and
                -- do; `soon` is what this season's cap still allows,
                -- which is the one worth holding crests toward; `best`
                -- is the ceiling, and is only ever quoted as a target.
                row.now = BestCraftTrack(worn, function(t)
                    return ns:GetCrestCountByTrack(t) >= ns.CRAFT_CREST_COST
                end)
                row.soon = BestCraftTrack(worn, function(t)
                    return ns:GetCrestCountByTrack(t) + ns:GetEarnableCrests(t)
                        >= ns.CRAFT_CREST_COST
                end)
                row.best = BestCraftTrack(worn, function() return true end)
                -- `soon` first, deliberately. Picking the tier the
                -- wallet can already pay for spends the season's
                -- scarcest thing -- the spark, which does not refill --
                -- on whatever happened to be affordable tonight. The
                -- tier worth aiming at is the best one this season's cap
                -- can still reach; whether the crests are in hand yet is
                -- a different question, and `ready` answers it.
                row.track = row.soon or row.now or row.best
                local range = row.track and ns.CRAFTED_RANGES[row.track]
                row.ilvl = range and range.max or 0
                out.wanted[#out.wanted + 1] = row
            end
        end
    end

    ------------------------------------------------------------
    -- Which wallet each craft is a claim on.
    --
    -- One per tier, and only the best of them: two crafts on the same
    -- track is 160 crests held back, and a reserve that size stops
    -- being advice and starts being a wallet the player is not allowed
    -- to spend. ns.CRAFT_RESERVE_MAX caps the total the same way.
    --
    -- Sparks gate the whole thing. Holding crests for a craft with no
    -- spark to start it is the paralysis this file spends the rest of
    -- its length avoiding.
    ------------------------------------------------------------
    table.sort(out.wanted, function(a, b)
        local pa = ns.SLOT_PRIORITY[a.slotID] or 2
        local pb = ns.SLOT_PRIORITY[b.slotID] or 2
        if pa ~= pb then return pa > pb end
        -- The emptier slot first: a craft into a bare slot is worth more
        -- than one replacing something already decent.
        if a.wornIlvl ~= b.wornIlvl then return a.wornIlvl < b.wornIlvl end
        return a.slotID < b.slotID
    end)

    local budget = math.min(out.sparks, ns.CRAFT_RESERVE_MAX or 2)
    for _, row in ipairs(out.wanted) do
        if budget <= 0 then break end
        if row.track and not out.byTrack[row.track] then
            out.byTrack[row.track] = row
            budget = budget - 1
        end
    end

    return out
end

--- What a track has to keep back for a craft, and which craft.
---
--- nil unless the player is holding a spark: see ns:GetCraftPlan.
function ns:GetCraftReserve(crestTrack)
    if not crestTrack then return nil end
    local row = ns:GetCraftPlan().byTrack[crestTrack]
    if not row then return nil end
    return {
        amount   = ns.CRAFT_CREST_COST,
        slotID   = row.slotID,
        slotName = row.slotName,
        ilvl     = row.ilvl,
        wornIlvl = row.wornIlvl,
        held     = ns:GetCrestCountByTrack(crestTrack),
        -- Whether the 80 is already in the wallet, or something the cap
        -- still allows. The two are different sentences.
        ready    = row.now == crestTrack,
    }
end

--- The "make this one instead" verdict for a slot, or nil.
---
--- `reachIlvl` is the highest item level crests could take whatever is
--- in the slot NOW -- its track cap, or 0 for a bare or off-season slot.
--- The craft has to beat that or it is not advice, it is a preference.
---
--- Requires a spark in the bags. Without one the craft is a plan rather
--- than a decision, and a row saying "make this instead" above a slot
--- the player cannot make anything for is worse than silence: they stop
--- spending, and nothing replaces the spend.
function ns:GetCraftAdvice(slotID, reachIlvl)
    local plan = ns:GetCraftPlan()
    if plan.sparks < 1 then return nil end

    local row
    for _, r in ipairs(plan.wanted) do
        if r.slotID == slotID then row = r break end
    end
    if not (row and row.track and row.ilvl > 0) then return nil end
    if row.ilvl <= (reachIlvl or 0) then return nil end

    local track = row.track
    local held  = ns:GetCrestCountByTrack(track)
    local cost  = ns.CRAFT_CREST_COST
    local short = math.max(cost - held, 0)
    local range = ns.CRAFTED_RANGES[track]

    ------------------------------------------------------------
    -- The line, in the order the decision is made: what it costs, what
    -- it makes, and why it beats the alternative sitting in the slot.
    ------------------------------------------------------------
    local reason
    if short == 0 then
        reason = cost .. " " .. track .. " crafts the piece your list wants here — "
            .. row.ilvl .. " at max quality"
    else
        reason = "Hold " .. short .. " more " .. track .. " for the craft your "
            .. "list wants here — " .. cost .. " makes it, " .. row.ilvl
            .. " at max quality"
    end
    if (reachIlvl or 0) > 0 then
        reason = reason .. ", past the " .. reachIlvl .. " crests reach on what is in the slot"
    end
    reason = reason .. "."

    local detail = {
        "Your best-in-slot list names a crafted piece for this slot, so "
            .. "every crest spent on what is in it now buys item level the "
            .. "craft throws away.",
    }

    if range and range.min < row.ilvl then
        detail[#detail + 1] = "A max-quality craft lands at " .. row.ilvl ..
            "; a lower-quality one lands as low as " .. range.min ..
            ". That is the crafter's skill, not your wallet — ask for the "
            .. "rank before you hand over the spark."
    end

    detail[#detail + 1] = "Crafted gear takes no crest upgrades afterwards, "
        .. "so the " .. cost .. " is the whole bill for the slot rather "
        .. "than the first rung of a ladder."

    if short > 0 then
        local earnable = ns:GetEarnableCrests(track)
        if earnable >= short then
            detail[#detail + 1] = "You hold " .. held .. ". The other " ..
                short .. " is still inside this season's cap, so it is "
                .. "content to run rather than a wait."
        else
            detail[#detail + 1] = "You hold " .. held .. ", and the cap "
                .. "allows " .. earnable .. " more this season — " ..
                math.max(short - earnable, 0) .. " of it waits on a reset."
        end
    end

    local spares = plan.sparks - 1
    detail[#detail + 1] = plan.sparks .. (plan.sparks == 1
        and " Spark of Tides in the bags, and this is what it is for."
        or (" Sparks of Tides in the bags, so this one costs you nothing you "
            .. "were saving — " .. spares .. " left after it."))

    return reason, detail
end

------------------------------------------------------------
-- What a crest tier will cost this CHARACTER, not this wardrobe.
--
-- Every demand figure in this file counts the pieces a player is wearing
-- on the track RIGHT NOW. That is the wrong set, and it is wrong in the
-- direction that makes the addon hoard.
--
-- A Champion crest is not spent on "my four Champion pieces". Over a
-- season it is spent on every slot that will ever hold a Champion item,
-- which on a character with two Veteran pieces and an empty back is
-- those slots too -- their Champion drop has simply not arrived yet.
-- Counting only what is worn today made the total look small, the wallet
-- look scarce, and every rule downstream reach for "hold".
--
-- Counted forward instead, and the number a player actually needs falls
-- out of the watermark. A slot's mark is the highest item level it has
-- held, ranks at or under it are free, so the cost of taking a slot to a
-- track's cap is the ranks ABOVE its mark -- whatever is in it now, and
-- whether or not anything is. Which is why a Myth piece subtracts a
-- whole slot from the Hero bill: the mark it sets is past the Hero cap,
-- so no Hero crest will ever be spent there again. Ten Myth pieces leave
-- six slots at five ranks each, and 600 Hero crests covers the lot.
--
-- The point of the number is the comparison. If everything this tier
-- could ever want is already inside what the player can still get, the
-- tier is not scarce, and every rule that rations it -- the reserve, the
-- hold-for-a-drop bet, "these slots first" -- is solving a problem that
-- does not exist. Spend it as it arrives.
--
-- Deliberately an UPPER bound, in three places at once: it assumes every
-- unfilled slot takes a piece at the bottom of the track, it assumes
-- every one of them gets a piece at all, and where the client has not
-- answered for a slot's mark it charges for ranks that may well be paid
-- for already. Over-stating demand can only ever withhold the
-- spend-freely verdict, never hand it out wrongly, which is the only
-- direction an error here is allowed to run.
------------------------------------------------------------
function ns:GetSeasonDemand(crestTrack)
    if not crestTrack then return nil end
    if seasonCache[crestTrack] then return seasonCache[crestTrack] end

    local levels = ns.GEAR_TRACKS[crestTrack]
    if not levels then return nil end

    local capIlvl = levels[#levels]
    local cost    = ns:GetCrestCost(crestTrack)
    local myRank  = ns.TRACK_RANK[crestTrack] or 0

    local out = {
        track   = crestTrack,
        cost    = cost,
        capIlvl = capIlvl,
        slots   = 0,   -- every slot on the doll
        settled = 0,   -- ...that will never want this crest again
        wanting = 0,   -- ...that still could, worn or not
        demand  = 0,   -- to take every one of those to the cap
        unread  = 0,   -- marks the client has not answered for
        pieces  = {},
    }

    for _, si in ipairs(ns.SLOT_IDS or {}) do
        out.slots = out.slots + 1

        local info     = ns:GetSlotInfo(si.slot)
        local curIlvl  = info and info.ilvl or 0
        local curTrack = info and info.track
        local wornRank = curTrack and ns.TRACK_RANK[curTrack] or 0

        -- Past the cap by any route, or wearing something from a higher
        -- track. Either way this crest has nothing left to buy here --
        -- nobody puts a Hero piece into a slot holding a Myth one.
        if curIlvl >= capIlvl or wornRank > myRank then
            out.settled = out.settled + 1
        else
            local mark, read = SlotMark(si.slot)
            if not read then out.unread = out.unread + 1 end

            -- The mark this slot will have, not the one it has.
            --
            -- Read literally, a slot wearing a Champion 1/6 is on the
            -- Hero bill for five ranks. But the piece in it is going to
            -- be taken to the Champion cap first -- that is what the
            -- rest of the addon advises, and Champion is the cheap
            -- crest -- which lifts the slot's mark to 308. A Hero drop
            -- landing there then costs four ranks, not five.
            --
            -- Reported as exactly that arithmetic: ten Myth, five Hero
            -- and one Champion, all at 1/6, is "500 hero + 100 champion
            -- + 80 hero". The 80 is this. Pricing it at 100 had the
            -- addon quietly disagreeing with the player's own maths
            -- about an upgrade it had already told them to buy.
            --
            -- The one place this stops being a pure upper bound: it
            -- assumes the lower piece does get maxed. It is the cheapest
            -- advice on the page and the tier below is almost always the
            -- looser one, but a player who ignores it is short by the
            -- overlap -- one rank, on the tracks where the bands meet.
            if curTrack and curTrack ~= crestTrack then
                local ownCap = ns:GetMaxIlvlForTrack(curTrack)
                if ownCap > mark then mark = ownCap end
            end

            -- Where the climb starts. A piece already on this track
            -- starts from its own rank; anything else -- a lower track,
            -- an off-season piece, a bare slot -- is assumed to take a
            -- drop at the bottom, which is the worst it can be.
            local from = (curTrack == crestTrack) and (info.rank or 1) or 1

            local ranks, free = 0, 0
            for r = from + 1, #levels do
                if levels[r] > mark then
                    ranks = ranks + 1
                else
                    free = free + 1
                end
            end

            if ranks > 0 then
                out.wanting = out.wanting + 1
                out.demand  = out.demand + ranks * cost
                out.pieces[#out.pieces + 1] = {
                    slotID   = si.slot,
                    slotName = si.name,
                    worn     = curTrack == crestTrack,
                    -- A slot whose drop has not landed yet. The bill is
                    -- real; the piece it is for is hypothetical, and any
                    -- sentence quoting this has to be able to say so.
                    awaited  = curTrack ~= crestTrack,
                    ranks    = ranks,
                    free     = free,
                    cost     = ranks * cost,
                    mark     = mark,
                }
            else
                -- Every rank this track has is already under the slot's
                -- mark: the drop lands and climbs to the cap for free.
                out.settled = out.settled + 1
            end
        end
    end

    out.held     = ns:GetCrestCountByTrack(crestTrack)
    out.earnable = ns:GetEarnableCrests(crestTrack)
    out.budget   = out.held + out.earnable
    out.short    = math.max(out.demand - out.budget, 0)
    out.surplus  = math.max(out.budget - out.demand, 0)
    -- The verdict the whole function exists for. Nothing to ration:
    -- everything this tier could ever want is inside what is already
    -- gettable, so there is no ordering decision left to make.
    out.abundant = out.demand > 0 and out.budget >= out.demand
    -- Cheapest first, so a caller naming names starts where the crests
    -- go furthest.
    table.sort(out.pieces, function(a, b)
        if a.cost ~= b.cost then return a.cost < b.cost end
        return a.slotID < b.slotID
    end)

    seasonCache[crestTrack] = out
    return out
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
                    -- Read once per candidate rather than per run: the
                    -- walk scores every run of every slot on every pick,
                    -- and this reaches a scraped table and the player's
                    -- saved pins.
                    bis      = ns.IsBisItem and ns:IsBisItem(si.slot) or false,
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
            bis          = c.bis,
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
    --
    -- And none when the tier is not scarce in the first place. The
    -- reserve rations a stock; a stock big enough to cover every slot
    -- this crest could ever be spent on is not being rationed, it is
    -- being sat on. See ns:GetSeasonDemand.
    local season = ns.GetSeasonDemand and ns:GetSeasonDemand(crestTrack)
    plan.abundant = (season and season.abundant) or false
    plan.seasonDemand = season and season.demand or 0

    local reserve = 0
    if plan.seasonCapped and uncapped <= 0 and cost > 0
        and not outgrown and not plan.abundant then
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
    ------------------------------------------------------------
    -- And the crests a craft has already spoken for.
    --
    -- A separate reserve from the one above, because it protects
    -- something else. That one keeps a rank back for a drop that has
    -- not landed yet; this one keeps 80 back for a piece the player's
    -- own best-in-slot list told them to MAKE -- and a craft, unlike a
    -- drop, cannot be brought forward by getting lucky. Spend the 80 on
    -- a rank tonight and the spark sits in the bags until the cap moves.
    --
    -- The same three exemptions as above, for the same reasons: no
    -- reserve while the tier still has income to spend twice, none on a
    -- track the content has outgrown, and none on a tier with enough for
    -- everything anyway. See ns:GetCraftReserve for the fourth and
    -- strongest one -- no spark, no reserve.
    --
    -- NOT capped at "leave one rank buyable" the way the drop reserve
    -- is. That guard exists so a reserve cannot paralyse a wallet; here
    -- freezing the wallet is the entire advice, and a craft half paid
    -- for buys nothing at all.
    --
    -- `craft.ready` is what makes this safe on a tier that still earns.
    -- A wallet already holding the 80 is one misclick from spending it,
    -- and that is the mistake worth naming; a wallet holding 20 toward
    -- an 80 is not being tempted by anything, so it only gets frozen
    -- once the season cap says the other 60 are not coming this week.
    local craft = ns.GetCraftReserve and ns:GetCraftReserve(crestTrack)
    plan.craftReserve = 0
    if craft and not outgrown and not plan.abundant
        and (craft.ready or (plan.seasonCapped and uncapped <= 0)) then
        plan.craftReserve = math.min(craft.amount, held)
        reserve = math.min(reserve + plan.craftReserve, held)
        plan.craftSlot = craft.slotID
        plan.craftSlotName = craft.slotName
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
    ------------------------------------------------------------
    -- Paired slots share one mark, taken from the lower of the two.
    --
    -- So a run that caps a ring or a trinket only earns the rebate if
    -- its partner is already at that level. Without this the plan hands
    -- a hundred crests to one trinket and reports a free Hero rank that
    -- will never arrive, because the mark never moved off the partner.
    ------------------------------------------------------------
    local bySlot, slotIlvl, slotName = {}, {}, {}
    for _, c in ipairs(candidates) do bySlot[c.slotID] = c end
    for _, si in ipairs(ns.SLOT_IDS or {}) do
        local info = ns:GetSlotInfo(si.slot)
        slotIlvl[si.slot] = info and info.ilvl or 0
        slotName[si.slot] = si.name
    end

    --- The partner's CURRENT level, live as the walk buys ranks.
    --- nil when the slot is not half of a pair.
    local function PartnerIlvl(slotID)
        local partner = ns.SLOT_PAIRS and ns.SLOT_PAIRS[slotID]
        if not partner then return nil end
        local c = bySlot[partner]
        return c and c.ilvl or (slotIlvl[partner] or 0), partner
    end

    local rebate, markTrack, markRanks, markRank, dropRank =
        MarkRebate(crestTrack, bandLow, bandHigh)
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

        -- A pair whose partner is not there yet earns nothing: the mark
        -- is the lower of the two and has not moved.
        local partner = PartnerIlvl(c.slotID)
        local pairReady = (partner == nil) or (partner >= landing)

        -- The insurance carries the slot's weight too. The mark sits on
        -- THIS slot, so the crests it saves are saved on the piece that
        -- lands HERE -- a free rank on a weapon is worth what a weapon
        -- rank is worth. Left unweighted it was competing against a
        -- number four or five times its scale and never won: a trinket
        -- took a hundred crests to reach a cap whose mark could not move,
        -- beating a slot that would actually have banked something.
        local value = gain
        if c.rank + k >= c.maxRank and runCost <= reachable and pairReady then
            value = value + rebate
        end
        return value * (c.priority or 2) / runCost
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
        -- The keeper before the filler. Two trinkets at the same rank
        -- and level are otherwise identical to the scoring, and slot id
        -- is a worse answer than "this is the one you are keeping".
        if c.bis ~= bestC.bis then return c.bis end
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
                    local pIlvl, pSlot = PartnerIlvl(best.slotID)
                    if pIlvl and pIlvl < best.ilvl then
                        summary.pairSlot = slotName[pSlot] or "its partner"
                        summary.pairIlvl = pIlvl
                    else
                        summary.pairSlot, summary.pairIlvl = nil, nil
                    end
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
------------------------------------------------------------
-- Is the piece in this slot one the player means to keep?
--
-- Two trinkets at the same rank and item level are the same purchase to
-- everything above this line, so the walk was breaking the tie on slot
-- id -- Trinket 1 beat Trinket 2 because 13 is less than 14. When one
-- of them is the spec's best-in-slot and the other is filler that is
-- not a tie at all: crests on the keeper stay bought, crests on the
-- filler go when it does.
--
-- The scraped guide and the player's own pins both count, pins first --
-- someone who has pinned a choice has simed it or decided it, and that
-- outranks a page scraped in August.
--
-- Deliberately only a TIE-BREAK. Best-in-slot says which of two equal
-- purchases to make, not that a best-in-slot piece is worth more crests
-- than a bigger upgrade elsewhere; and the guide is one opinion at one
-- point in time, which ns.GEAR_CAVEAT already says at length.
------------------------------------------------------------
local function EquippedItemID(slotID)
    local info = ns.GetSlotInfo and ns:GetSlotInfo(slotID)
    local link = info and info.link
    return link and tonumber(link:match("item:(%d+)")) or nil
end

function ns:IsBisItem(slotID)
    local itemID = EquippedItemID(slotID)
    if not itemID then return false end

    local specKey = ns.PlayerSpecKey and ns:PlayerSpecKey()
    if not specKey then return false end

    -- The player's own pins, which override the guide row for that slot.
    if ns.GetBisPins then
        local ok, pins = pcall(ns.GetBisPins, ns, specKey)
        if ok and type(pins) == "table" then
            for pinnedSlot, pinnedID in pairs(pins) do
                if pinnedSlot == slotID then return pinnedID == itemID end
            end
        end
    end

    local guide = ns.ClassGuideData and ns.ClassGuideData[specKey]
    for _, row in ipairs(guide and guide.bis or {}) do
        if row.itemID == itemID then return true end
    end
    return false
end

--- Is this slot being held rather than funded?
---
--- The plan still ALLOCATES to it -- the walk knows nothing about
--- holding -- so the advice and the plan can disagree unless both ask
--- the same question. They did disagree: Trinket 1 read "Hold 100
--- Champion" while Trinket 2 read "Feet and Trinket 1 first", naming as
--- a prerequisite the very slot the panel had just said not to spend on.
function ns:IsHeldForDrops(plan, slotID)
    if not plan or not plan.outgrown then return false end
    -- The bet this rule makes is a scarcity bet: the same crests can
    -- finish one piece now or whichever piece the next drop lands on, so
    -- hold and let the drop choose. With enough crests for every slot on
    -- the track there is nothing to choose between -- both happen -- and
    -- holding is just an item level not being worn.
    if plan.abundant then return false end
    if (plan.markRanks or 0) <= 0 then return false end
    local mine = plan.slots and plan.slots[slotID]
    if not mine then return false end
    return mine.wantedRanks >= 4 and mine.paidRanks > 0
end

function ns:GetCrestPlanBlockers(plan, slotID, limit)
    if not plan then return {} end
    local mine = plan.slots and plan.slots[slotID]
    if not mine or not mine.firstStep then return {} end

    local names, seen = {}, {}
    for i = 1, mine.firstStep - 1 do
        local step = plan.steps[i]
        -- A slot the panel is telling the player to hold is not a slot
        -- to do first. Naming it here is the plan's allocation leaking
        -- past the advice that overrode it.
        if not seen[step.slotID] and not ns:IsHeldForDrops(plan, step.slotID) then
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
    local season = ns.GetSeasonDemand and ns:GetSeasonDemand(crestTrack)
    local census = ns:GetGearCensus()
    local t = census.tracks[crestTrack]
    if not t or t.count == 0 then
        -- Wearing nothing on this track used to end the answer here, and
        -- that is the case the whole season-demand idea is about: a
        -- character with 600 Hero crests and no Hero piece yet has the
        -- most useful thing in the addon to be told, which is that the
        -- crests are already sorted and only the drops are missing. The
        -- old code called that "no track" and said nothing.
        if not (season and season.wanting > 0) then return nil end
        t = { track = crestTrack, pieces = {}, count = 0,
              ranksLeft = 0, demand = 0 }
    end

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
        -- Held and earnable kept apart, not just summed.
        --
        -- `budget` is the two added together, and every sentence built
        -- on it read as though the whole figure were future income --
        -- "480 to finish them all and 520 coming" describes crests
        -- mostly already in the wallet as though none of them were
        -- there. The player is deciding between spending and farming,
        -- and that decision needs the two halves named separately.
        earnable    = math.max(budget - held, 0),
        -- The whole-character bill, which is a different and much larger
        -- number than `demand` above: that one prices the pieces being
        -- worn on this track today, this one prices every slot the crest
        -- could ever be spent on. See ns:GetSeasonDemand.
        season      = season,
        outgrown    = ns:IsCrestOutgrown(crestTrack),
        canFinish   = canFinish,
        finishCost  = spend,
        -- What the shallowest unfinished piece costs. `order` is sorted
        -- cheapest first, so this is the lowest price at which anything
        -- at all on this track can be carried home -- the number that
        -- decides whether farming is worth starting.
        cheapestCost = order[1] and (order[1].left * cost) or 0,
        -- The deepest piece the wallet can still afford to carry home,
        -- which is the threshold a player can actually apply to a drop:
        -- "anything at 4/6 or better is worth finishing".
        worstRankWorthFinishing = deepest
            and (order[1].maxRank - deepest) or nil,
        untracked   = #census.untracked,
    }

    ------------------------------------------------------------
    -- "Can I max this track" has two yeses and they are not the same
    -- answer.
    --
    -- One is "the crests are in your bags, go and click" and the other
    -- is "the season cap still allows enough, go and run keys". A single
    -- max_all verdict collapsed them, so a player holding a third of
    -- what the track wants was told to max everything on it -- true
    -- eventually, useless tonight, and indistinguishable from the case
    -- where it was true right now.
    ------------------------------------------------------------
    -- Nothing to ration beats every other verdict, because the others
    -- are all answers to "which of these can I afford" -- a question
    -- that stops existing once the answer is all of them, including the
    -- slots whose pieces have not dropped yet.
    if policy.season and policy.season.abundant then
        policy.verdict = "abundant"
    elseif t.count == 0 then
        -- Slots want this crest, but no piece of the track has landed in
        -- one yet. Not "done" -- there is nothing to be done with -- and
        -- not a shortfall either until there is something to spend on.
        policy.verdict = "awaiting"
    elseif #order == 0 then
        policy.verdict = "done"
    elseif held >= t.demand then
        policy.verdict = "max_now"
    elseif budget >= t.demand then
        policy.verdict = "max_farm"
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

------------------------------------------------------------
-- The slots a tier's bill is waiting on.
--
-- ns:GetSeasonDemand prices every slot that could ever want this crest.
-- These are the ones with nothing of the tier in them yet: no per-slot
-- rule can see them, because there is no piece to hang a rule on, and no
-- plan can order them, because there is nothing to spend on. They are
-- most of the bill on any character below the top track.
--
-- Weapons come back separately, because they are the only slots whose
-- priority makes them worth naming on their own -- ns.SLOT_PRIORITY puts
-- both at 5, a step clear of chest and legs, and the plan cannot act on
-- that for a slot it cannot spend in. A Champion 6/6 main hand under
-- Hero is the commonest shape there is and the ordering never sees it.
--
-- An EMPTY off hand is left out. The advisor cannot tell a dual wielder
-- waiting on a drop from a staff user whose off hand is bare all
-- expansion, and only one of those two should be told to bank crests for
-- it. Main hand is always kept; every spec has one.
--
-- Whether the two share a watermark line is settled now: two one-handers
-- do, as a ranked pair, and anything else in the off hand does not. It
-- is still not in ns.SLOT_PAIRS, because that table is a constant and
-- this one depends on what is held -- see PairFor in Core/Core.lua.
------------------------------------------------------------
function ns:GetAwaitedSlots(season)
    local out = { count = 0, cost = 0, arms = {}, armCost = 0 }
    for _, pc in ipairs(season and season.pieces or {}) do
        if pc.awaited then
            out.count = out.count + 1
            out.cost  = out.cost + (pc.cost or 0)
            if (ns.SLOT_PRIORITY or {})[pc.slotID] == 5
                and (pc.slotID == 16 or ns:GetSlotInfo(pc.slotID)) then
                out.arms[#out.arms + 1] = pc.slotName
                out.armCost = out.armCost + (pc.cost or 0)
            end
        end
    end
    return out
end

--- One line a player can act on, for a whole track, plus a second line
--- when something has already claimed part of the wallet.
---
--- Written WITHOUT the track's name in front of it, because the only
--- thing that draws it is the crest tile's own tooltip and that tooltip
--- is already headed by the currency. It used to lead with "Champion: "
--- for a strip of lines above the improvements list, and the player
--- read a paragraph about wallets before reaching the slots it was
--- about. Per-slot advice belongs on the per-slot rows; a fact about a
--- whole wallet belongs on the wallet.
local function TrackPolicySentence(self, crestTrack)
    local ns = self
    local p = ns:GetTrackPolicy(crestTrack)
    if not p then return nil end

    local pieces = p.count .. (p.count == 1 and " piece" or " pieces")

    ------------------------------------------------------------
    -- The count the bill is FOR.
    --
    -- Two numbers sat next to each other meaning different sets:
    -- `p.count` is every piece on the track, `p.demand` prices only the
    -- ones still climbing. Four pieces with two already capped read as
    -- "4 pieces, 160 to finish them all", and the 160 was never for
    -- four. Below, both come off `wanting`.
    --
    -- And "finish them all" over a single piece read as finishing every
    -- item on the character -- the player's own report. One piece takes
    -- "max it"; the plural keeps "max them".
    ------------------------------------------------------------
    local one   = p.wanting == 1
    local todo  = p.wanting .. (one and " piece" or " pieces") ..
        " short of the cap"
    local bill  = p.demand .. (one and " to max it" or " to max them")

    -- What a craft has already taken off the top. Said here rather than
    -- folded into the sentences below because it is true of every one of
    -- them and would have to be written eight times.
    --
    -- Gated on the PLAN, not on the craft alone. A wanted craft whose
    -- tier is outgrown or awash in crests is exempt from the reserve --
    -- and a tile promising that 80 are spoken for, over rows that go on
    -- spending them, is the two halves of the addon contradicting each
    -- other about the same wallet.
    local claim = nil
    local plan = ns:GetCrestPlan(crestTrack)
    local craft = (plan and (plan.craftReserve or 0) > 0)
        and ns:GetCraftReserve(crestTrack) or nil
    if craft then
        claim = craft.amount .. " of them are spoken for by the " ..
            craft.slotName .. " your list says to craft — " .. craft.ilvl ..
            " at max quality" ..
            (craft.ready and ", and you are holding the crests for it."
                or ", once the crests are there.")
    end

    if p.verdict == "done" then
        return pieces .. ", all at the cap.", claim
    end
    if p.verdict == "awaiting" then
        local sd = p.season
        -- Nothing worn on this track, so there is no "pieces" count to
        -- lead with and the sentence has to be about slots and drops.
        -- The bill is still worth stating: it is what the player is
        -- saving toward, and on most characters it is smaller than the
        -- hoarding instinct assumes.
        local slots = sd.wanting .. (sd.wanting == 1 and " slot" or " slots")
        return "Nothing on this track yet. " .. slots ..
            " could take one, " .. sd.demand .. " to carry them all to " ..
            sd.capIlvl .. " — you hold " .. sd.held ..
            (sd.short > 0
                and (", " .. sd.short .. " short of that.")
                or ", and the drops are the only thing missing."), claim
    end
    if p.verdict == "abundant" then
        local sd = p.season
        -- Led with the verdict, not the arithmetic.
        --
        -- The numbers are the evidence and they were the whole sentence:
        -- a player reading "580 to take every one of them to 321" has to
        -- do the comparison themselves to find out it is good news. What
        -- they asked for is the conclusion first -- there is enough, stop
        -- worrying about running out -- with the figures behind it.
        --
        -- Held and available are different reassurances and the sentence
        -- says which one it means. "Enough in hand" is spend it tonight;
        -- "enough available" is you will not be short by the time the
        -- drops land, which on a wallet holding 345 of a 580 bill is the
        -- claim being made and it would be a lie stated as the other.
        local slots = sd.wanting .. (sd.wanting == 1 and " slot" or " slots")
        local inHand = sd.held >= sd.demand
        if inHand then
            return "Enough in hand to max all " .. slots ..
                " without worrying about running short — " .. sd.demand ..
                " needed, " .. sd.held .. " held.", claim
        end
        return "Enough available to max all " .. slots ..
            " without worrying about running short — " .. sd.demand ..
            " needed, " .. sd.budget .. " available (" .. sd.held ..
            " held, " .. sd.earnable .. " still under the cap).", claim
    end
    if p.verdict == "max_now" then
        return todo .. ", " .. bill .. " and you hold " .. p.held .. ". " ..
            (one and "Do it." or "Max everything on this track."), claim
    end
    if p.verdict == "max_farm" then
        -- The earnable half is stated as what the cap ALLOWS, not as
        -- crests "coming". Nothing arrives on its own: that number is
        -- content the player has not run yet, and it is only this
        -- week's allowance -- the cap rises again at reset.
        return todo .. ", " .. bill .. ". You hold " .. p.held ..
            " and the cap allows " .. p.earnable .. " more — earn it and " ..
            (one and "it maxes." or "every piece maxes."), claim
    end
    if p.verdict == "nothing_reachable" then
        local line = todo .. ", " .. bill .. ", you hold " .. p.held ..
            ". Not enough" .. (one and "" or " to carry even one home")
        -- Whether that is a dead end or an evening's work is decided by
        -- the cap, not the wallet, and the two read identically without
        -- this. "Hold, or take a drop" on a track with 300 crests still
        -- earnable is advice to sit on hands for no reason.
        if not p.outgrown and p.budget >= p.cheapestCost then
            return line .. " — but " .. p.cheapestCost ..
                " finishes the cheapest, and the cap allows " ..
                p.earnable .. " more. Go and earn it.", claim
        end
        return line .. " — hold, or take a drop.", claim
    end

    local names = {}
    for i, piece in ipairs(p.canFinish) do
        if i > 3 then names[#names + 1] = "+" .. (#p.canFinish - 3) .. " more" break end
        names[#names + 1] = piece.slotName
    end
    local rest = p.wanting - #p.canFinish
    local line = todo .. ", " .. bill .. ", you hold " .. p.held ..
        ". Enough for " .. #p.canFinish .. " — " ..
        table.concat(names, ", ") .. "."
    if rest > 0 then
        if p.outgrown then
            line = line .. " The other " .. rest .. " want drops, not crests."
        elseif p.earnable > 0 then
            -- "Will have to wait" was the whole answer, and it is the
            -- one thing a player cannot act on. Farming is the obvious
            -- next move and the only question about it is whether it is
            -- enough -- so say how far it gets, and where it stops.
            line = line .. " The other " .. rest .. ": the cap allows " ..
                p.earnable .. " more, still " .. (p.demand - p.budget) ..
                " short of finishing them."
        else
            line = line .. " The other " .. rest ..
                ": the cap is reached, so drops do the rest."
        end
    end
    return line, claim
end

------------------------------------------------------------
-- ...and the half of the tier the sentence above cannot see.
--
-- Every verdict but two prices the pieces WORN on the track. That is the
-- right set for "which of these can I afford tonight" and the wrong one
-- for "am I nearly done with this crest", and the second question is the
-- one a wallet gets hovered for. `awaiting` and `abundant` already speak
-- in slots rather than pieces, so they are left alone -- appending here
-- would have them say it twice.
--
-- This lives on the wallet and not on the slot rows on purpose. It is
-- one fact about sixteen slots; said per row it was a paragraph of tier
-- arithmetic under every piece of advice, and the panel stopped being
-- readable. Per-slot explanation belongs on the per-slot row.
------------------------------------------------------------
------------------------------------------------------------
-- What the outgrown achievement still wants, said once.
--
-- This used to be on the SLOTS: every piece under the threshold carried
-- "7 slots to Champion of the Mist -- 50% off for alts (460 crests
-- total)", the same sentence seven times, over a wallet holding 180.
-- One fact about sixteen slots belongs where the balance is; the rows
-- keep only what is true of the slot they are on.
--
-- It names the drop route as well as the crest one, because the
-- threshold is an ITEM LEVEL and not a track. Anything landing in one
-- of those slots at or above it counts and costs nothing, and on a bill
-- the wallet cannot cover that is the cheaper half of the answer -- and
-- the half the crest-priced version could not see at all.
------------------------------------------------------------
local function AchievementClause(self, crestTrack)
    local ns = self
    if not ns.GetChasedAchievement then return nil end
    local chase = ns:GetChasedAchievement()
    if not chase or chase.track ~= crestTrack or chase.remaining <= 0 then
        return nil
    end

    -- No bill here on purpose. The sentence this appends to has just
    -- priced the same pieces -- "8 pieces short of the cap, 640 to max
    -- them" -- and on the track being chased those two sets are usually
    -- the same set, so quoting the total again is the wallet saying one
    -- number twice. What is NEW is that there is an achievement at this
    -- item level, how many slots are off it, that a drop counts as well
    -- as a crest, and what earning it is worth.
    local slots = chase.remaining ..
        (chase.remaining == 1 and " more slot" or " more slots")
    local line = chase.name .. " wants " .. slots .. " at " .. chase.ilvl .. "+"

    -- Crests only buy the slots crests CAN buy. A slot whose track caps
    -- below the threshold, or which is empty, is named as wanting a drop
    -- rather than left to look purchasable.
    if chase.upgradeable == 0 then
        line = line .. ", and crests reach none of them — they want drops."
    elseif #chase.blockers > 0 then
        line = line .. ", and " .. #chase.blockers ..
            (#chase.blockers == 1 and " of them wants" or " of them want") ..
            " a drop rather than crests."
    else
        line = line .. " — a drop at that level counts too, not just crests."
    end

    return line .. " Earning it halves this crest for your alts."
end

function ns:GetTrackPolicyLine(crestTrack)
    local line, claim = TrackPolicySentence(self, crestTrack)
    if not line then return nil end

    -- Appended on every path, including the two that return early: an
    -- abundant wallet is exactly the one that should be told the
    -- achievement is a few hundred crests away.
    local achieve = AchievementClause(self, crestTrack)

    local season = ns.GetSeasonDemand and ns:GetSeasonDemand(crestTrack)
    local p = ns:GetTrackPolicy(crestTrack)
    if not season or not p or p.verdict == "awaiting" or p.verdict == "abundant" then
        return achieve and (line .. " " .. achieve) or line, claim
    end

    local waiting = ns:GetAwaitedSlots(season)
    if waiting.count == 0 then
        return achieve and (line .. " " .. achieve) or line, claim
    end

    line = line .. " " .. waiting.count .. " more " ..
        (waiting.count == 1 and "slot wants " or "slots want ") .. crestTrack ..
        " once drops land — another " .. waiting.cost .. "."

    ------------------------------------------------------------
    -- And the weapon, only where naming it changes something.
    --
    -- "Keep some back for the weapon" is advice with a cost: followed on
    -- a wallet that covers both, it retires item level for nothing. So
    -- it fires on exactly the case where the two compete -- enough for
    -- the weapon's own bill, not enough for that AND the pieces already
    -- on the track. Below that the player cannot afford it either way
    -- and being told to hold is just a smaller number to stare at; above
    -- it, both happen, and the addon should say nothing at all.
    --
    -- The first draft said it whenever a weapon was waiting. On a
    -- character holding 200 Hero, 60 of it going into gloves and 80 the
    -- weapon's whole bill, that read as "do not upgrade" over a row
    -- correctly headed "Upgrade now" -- the two halves of the panel
    -- arguing about a wallet that comfortably covered both.
    ------------------------------------------------------------
    local armCost = waiting.armCost
    if #waiting.arms > 0 and armCost > 0
        and p.held >= armCost and p.held < (p.demand or 0) + armCost then
        line = line .. " " .. (#waiting.arms == 1 and waiting.arms[1] or "Your weapons")
            .. " is " .. armCost .. " of that, and worth most — keep it back."
    end

    if achieve then line = line .. " " .. achieve end

    return line, claim
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

------------------------------------------------------------
-- Paying for the overlap with the cheaper crest, using a spare piece.
--
-- GetCrestWaste above says the first ranks of a track are a bad use of
-- its crests, because the track underneath reaches the same item level
-- for the same price. True, and it stops one step short of the move,
-- because the cheaper crest cannot be spent on the worn piece: a Hero
-- 1/6 takes Hero crests and nothing else.
--
-- What takes the cheaper crest is a SECOND piece for the same slot, and
-- the slot's own memory does the rest. It remembers the highest item
-- level it has ever held, and upgrades up to that level cost no crests
-- at all -- so a Champion piece for a slot already wearing a Hero 1/6
-- is not the 100 Champion its five remaining ranks look like:
--
--   Champion 1/6   292  -- the slot has seen 305, so free
--   Champion 2/6   295  -- free
--   Champion 3/6   298  -- free
--   Champion 4/6   302  -- free
--   Champion 5/6   305  -- free
--   Champion 6/6   308  -- 20 Champion, the first rank above 305
--
-- and once the slot has reached 308 the worn Hero piece goes 305 to 308
-- for nothing. Twenty Champion instead of twenty Hero, for the same
-- item level, which is the only trade between two crest tiers the game
-- offers.
--
-- The price is therefore not "how far down the track the spare is" --
-- which is what makes this worth computing rather than guessing. It is
-- how many of its ranks land ABOVE what the slot has already seen, and
-- on a geared character that is usually one. A spare deep down a track
-- in a slot that has never held anything good is the case where it is
-- genuinely five, and the advice has to say so rather than pretend both
-- are the same move.
--
-- nil when there is nothing to trade: no spare for the slot, no ranks
-- the lower track could have covered, or a slot whose mark already sits
-- at the lower track's cap.
------------------------------------------------------------
function ns:GetMarkLaunder(slotID)
    local canUpgrade, up = ns:CanUpgradeItem(slotID)
    if not canUpgrade or not up then return nil end

    local track   = up.track
    local overlap = track and ns.TRACK_FREE_RANKS[track]
    if not overlap then return nil end

    local levels     = ns.GEAR_TRACKS[track]
    local prevTrack  = overlap.prevTrack
    local prevLevels = ns.GEAR_TRACKS[prevTrack]
    if not levels or not prevLevels then return nil end

    local crestTrack     = ns.TRACK_CREST[track]
    local prevCrestTrack = ns.TRACK_CREST[prevTrack]
    if not crestTrack or not prevCrestTrack then return nil end

    -- What sets a mark is BINDING, and both of the things a player
    -- normally does with a drop bind it: putting it on, or simply
    -- keeping it until the trade timer runs out. So the mark is the
    -- default outcome, and the only way to miss it is to hand the piece
    -- to somebody else while there is still time.
    --
    -- Which is why this is read from the client rather than derived from
    -- what the player is wearing. Worn gear is bound and has marked, so
    -- the two agree most of the time -- and come apart on a drop that is
    -- still in its window, which is the moment somebody is most likely
    -- to be looking at this panel.
    local mark = ns:GetFreeUpgradeIlvl(slotID) or 0

    -- Zero is not "this slot has held nothing". It is "the client has
    -- not answered for this slot yet" -- the query wants the upgrade
    -- vendor open, and away from one it falls back to a cache that may
    -- never have been filled.
    --
    -- Every number below is a difference from this one, so a zero here
    -- does not make the advice vague, it makes it wrong: a Champion 1/6
    -- prices at five ranks and a hundred crests, and the row tells the
    -- player to hold out for a piece that would have cost twenty. Silence
    -- is the right answer to a price nobody read.
    --
    -- The guard is on the READ and the arithmetic runs on the floor: a
    -- bound piece in the bags makes the spare CHEAPER than the client's
    -- answer alone would say, and that direction is always safe. What
    -- is not safe is a price standing on the bags with no answer under
    -- it at all -- the floor is a lower bound, and a lower bound used
    -- as the line over-charges for everything above it.
    if ns:GetMarkRead(slotID) <= 0 then return nil end
    if mark <= 0 then return nil end

    local cost     = ns:GetCrestCost(crestTrack)
    local prevCost = ns:GetCrestCost(prevCrestTrack)
    local rank     = up.currUpgrade or 0
    local maxRank  = up.maxUpgrade or 0

    local best
    for _, spare in ipairs(ns:GetBagSpares(slotID)) do
        -- A spare at its last rank cannot be bought any further, so it
        -- is not a trade between two crest tiers -- it is either
        -- already counted (bound, and the slot's free ranks have it) or
        -- it is ns:GetBagLift's, below.
        -- An off-stat spare is not a trade. Finishing one moves no
        -- line, so the saving this entry is built on would never
        -- arrive -- see ns:PieceIsOffStat in Core/Core.lua.
        if spare.track == prevTrack and spare.rank < spare.maxRank
            and not ns:PieceIsOffStat(spare.link) then
            -- What the spare costs to finish, priced against the mark
            -- rather than against its rank.
            local paidRanks, freeRanks = 0, 0
            local top = spare.ilvl
            for r = spare.rank + 1, spare.maxRank do
                local lvl = prevLevels[r]
                if lvl then
                    if lvl > mark then paidRanks = paidRanks + 1
                    else freeRanks = freeRanks + 1 end
                    top = lvl
                end
            end

            -- What finishing it then hands the worn piece: every rank of
            -- it at or under where the spare tops out, that the slot has
            -- not already reached.
            local savedRanks, savedTo = 0, nil
            for r = rank + 1, maxRank do
                local lvl = levels[r]
                if lvl and lvl > mark and lvl <= top then
                    savedRanks = savedRanks + 1
                    savedTo = lvl
                end
            end

            if savedRanks > 0 then
                local entry = {
                    spare      = spare,
                    top        = top,
                    paidRanks  = paidRanks,
                    freeRanks  = freeRanks,
                    cost       = paidRanks * prevCost,
                    savedRanks = savedRanks,
                    savedTo    = savedTo,
                    saved      = savedRanks * cost,
                }
                entry.net = entry.saved - entry.cost
                -- Best net first, then the cheaper one: two spares that
                -- buy the same thing are the same advice, and the one
                -- asking for fewer crests is the one to name.
                if not best or entry.net > best.net
                    or (entry.net == best.net and entry.cost < best.cost) then
                    best = entry
                end
            end
        end
    end
    if not best then return nil end

    -- Anything for this slot still sitting unbound above the mark. It
    -- has not marked the slot, and it will the moment it binds -- so
    -- every number above is the price BEFORE a decision the player has
    -- not made yet, and the row must not read as though it were final.
    --
    -- The highest one, because that is the one that moves the mark
    -- furthest. How far it moves is deliberately not predicted: rings
    -- and trinkets share a mark between two slots and one bound piece
    -- does not necessarily move it, so the row says the price is
    -- provisional and stops there.
    for _, spare in ipairs(ns:GetBagSpares(slotID)) do
        if spare.unbound and spare.ilvl > mark
            and not ns:PieceIsOffStat(spare.link)
            and (not best.pending or spare.ilvl > best.pending.ilvl) then
            best.pending = spare
        end
    end

    best.slotID         = slotID
    best.track          = track
    best.prevTrack      = prevTrack
    best.crestTrack     = crestTrack
    best.prevCrestTrack = prevCrestTrack
    best.rank           = rank
    best.maxRank        = maxRank
    best.fromIlvl       = levels[rank] or up.currIlvl
    best.mark           = mark
    best.held           = ns:GetCrestCountByTrack(prevCrestTrack)
    -- Whether the cheaper crest is one this player is short of. It is
    -- what decides the expensive case: 100 crests of something with
    -- nowhere else to go is a different sentence from 100 crests of
    -- something four other slots are waiting on.
    best.spareIsCheap   = ns:IsCrestFree(prevCrestTrack)
    return best
end

------------------------------------------------------------
-- The other half of a drop: what it gives the slot, not the body.
--
-- A piece is worth item level twice. Once for wearing, and once
-- because the slot remembers the highest item level it has held, and
-- every rank up to there costs nothing -- so a better piece for a slot
-- pays out even in a bag, and even if it is never worn.
--
-- The second half is invisible at exactly the moment it is decided. A
-- fresh drop is still tradeable, and a tradeable piece has given the
-- slot nothing: the item level lands when it BINDS. Both of the things
-- a player normally does bind it -- putting it on, or simply keeping it
-- until the trade timer runs out -- and handing it to somebody else is
-- the only way to miss.
--
-- So this is the one rule that reads a piece the player has not
-- committed to, and all it says is what committing is worth. It is
-- allowed to name the item level because the piece is above what the
-- slot has reached: that much of the move is not a guess, only how
-- much further a LATER piece might take it would be.
--
-- Bound spares are not read here. A bound piece has already given the
-- slot its item level, so its ranks are free now rather than later, and
-- RULE 0 has them -- see BoundBagFloor in Core/Core.lua, which is what
-- makes sure RULE 0 actually knows.
--
-- Rings, trinkets and one-handers are not read here either, in any
-- state. Two slots share one memory there and it follows the lower of
-- the pair, so what keeping the piece is worth is genuinely unknown --
-- a 295 trinket over a 292 and a 292 buys nothing at all, and the same
-- piece over a 295 and a 292 buys three item levels in both slots. A
-- number for that would be a guess wearing a decimal point.
--
-- nil when there is nothing tradeable above what the slot has reached,
-- or when what is there covers no rank the worn piece has left.
------------------------------------------------------------
function ns:GetBagLift(slotID)
    local canUpgrade, up = ns:CanUpgradeItem(slotID)
    if not canUpgrade or not up then return nil end

    local track  = up.track
    local levels = track and ns.GEAR_TRACKS[track]
    if not levels then return nil end

    local crestTrack = ns.TRACK_CREST[track]
    if not crestTrack then return nil end

    -- The same silence as ns:GetMarkLaunder, and guarded on the same
    -- thing. This rule is forward-looking -- it says what a rank WILL
    -- cost once the player commits -- and that needs the real line, not
    -- a lower bound on it. Standing on the bags alone it would count
    -- ranks as about-to-be-free that are either free already or never
    -- were.
    if ns:GetMarkRead(slotID) <= 0 then return nil end

    local mark = ns:GetFreeUpgradeIlvl(slotID) or 0
    if mark <= 0 then return nil end

    -- The highest one, because that is the one that takes the slot
    -- furthest. Two tradeable pieces are one decision.
    local best
    for _, spare in ipairs(ns:GetBagSpares(slotID)) do
        -- Keeping an off-stat piece lifts nothing when it binds, so it
        -- is not the decision this rule is about.
        if spare.unbound and not spare.shared and spare.ilvl > mark
            and not ns:PieceIsOffStat(spare.link)
            and (not best or spare.ilvl > best.ilvl) then
            best = spare
        end
    end
    if not best then return nil end

    local rank    = up.currUpgrade or 0
    local maxRank = up.maxUpgrade or 0

    -- Ranks of the WORN piece that the spare would cover: above what
    -- the slot has reached, at or under where the spare sits.
    local ranks, toIlvl = 0, nil
    for r = rank + 1, maxRank do
        local lvl = levels[r]
        if lvl and lvl > mark and lvl <= best.ilvl then
            ranks  = ranks + 1
            toIlvl = lvl
        end
    end
    if ranks == 0 then return nil end

    return {
        slotID     = slotID,
        spare      = best,
        mark       = mark,
        track      = track,
        crestTrack = crestTrack,
        fromIlvl   = levels[rank] or mark,
        ranks      = ranks,
        toIlvl     = toIlvl,
        saved      = ranks * ns:GetCrestCost(crestTrack),
    }
end

--- The piece, as the player would read it off the tooltip.
local function LiftPiece(lift)
    return lift.spare.track .. " " .. lift.spare.rank .. "/" ..
        lift.spare.maxRank
end

--- How binding happens, said as the two ordinary things it is.
---
--- Written out in full rather than "once it binds", because "bind" is
--- the mechanic and the two things are the advice. One of them is doing
--- nothing at all, and a player who does not know that is a player who
--- thinks this costs them something.
local BIND_SENTENCE =
    "It is still tradeable, so it has given the slot nothing yet. Two "
    .. "things change that and both are ordinary: put it on, or leave it "
    .. "alone until its trade timer runs out. Handing it to somebody else "
    .. "is the only thing that does not."

--- The headline and the reasoning for a tradeable piece in the bags.
local function BagLiftSentences(lift)
    local piece = LiftPiece(lift)
    local line
    if lift.ranks == 1 then
        line = "Keep the " .. piece .. " in your bags — this slot's "
            .. "next rank, " .. lift.fromIlvl .. " to " .. lift.toIlvl ..
            ", then costs no crests"
    else
        line = "Keep the " .. piece .. " in your bags — this slot's "
            .. "next " .. lift.ranks .. " ranks, " .. lift.fromIlvl .. " to " ..
            lift.toIlvl .. ", then cost no crests"
    end
    return line, {
        BIND_SENTENCE,
        "Either way the slot has been to " .. lift.toIlvl ..
            ", and getting what you are wearing there stops costing crests "
            .. "— " .. lift.saved .. " " .. lift.crestTrack ..
            " you keep. Wearing it gets you the same " .. lift.toIlvl ..
            " outright, so upgrading instead is only worth it if you want "
            .. "the piece you already have on.",
    }
end

--- One line, for a slot that has free ranks already and is about to
--- have more.
local function BagLiftAddendum(lift)
    return "And the " .. LiftPiece(lift) .. " in your bags is still "
        .. "tradeable — keep it, which putting it on does and so "
        .. "does letting its timer run out, and the free run carries on to "
        .. lift.toIlvl .. ": " .. lift.ranks ..
        (lift.ranks == 1 and " more rank, " or " more ranks, ") ..
        lift.saved .. " " .. lift.crestTrack .. " you keep."
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
        -- A bare slot the guide says to CRAFT is the strongest version
        -- of this advice and the one the panel used to drop on the
        -- floor: GetRankedRecommendations filters NO_ITEM out, so the
        -- slot with nothing in it said nothing at all.
        local bareReason, bareDetail = ns:GetCraftAdvice(slotID, 0)
        if bareReason then
            return ns.RECOMMEND.CRAFT_INSTEAD, bareReason, bareDetail
        end
        return ns.RECOMMEND.NO_ITEM, ""
    end

    local canUpgrade, upgradeInfo, why = ns:CanUpgradeItem(slotID)

    if not upgradeInfo then
        -- Crafted items: show as maxed with crafted note
        if info.crafted then
            return ns.RECOMMEND.MAXED, "Crafted — no crest upgrades"
        end
        -- A slot no crest can touch is exactly where a craft is the
        -- whole answer, and this used to be the one place the panel had
        -- nothing to say. Off-season gear and an empty slot both reach
        -- 0 with crests, so anything the guide says to make beats it.
        local bareReason, bareDetail = ns:GetCraftAdvice(slotID, 0)
        if bareReason then
            return ns.RECOMMEND.CRAFT_INSTEAD, bareReason, bareDetail
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
            -- The rest is only the full price if nothing in the bags is
            -- about to shorten it. A tradeable piece above where this
            -- slot has been extends the free run the moment it binds,
            -- and the player is holding that decision right now.
            local lift = ns:GetBagLift(slotID)
            return ns.RECOMMEND.FREE_UPGRADE,
                freeRanks .. (freeRanks == 1 and " free rank to "
                    or " free ranks to ") .. (freeTarget or "?") ..
                " — then " .. paidCost .. " " .. crestTrack ..
                " for the rest",
                lift and { BagLiftAddendum(lift) } or nil
        end
    end

    -- ============================================================
    -- RULE 0b: A spare piece for this slot pays with the cheaper crest
    --
    -- Directly after the free ranks, because it is the next best thing
    -- to one: a rank bought with a crest the player is not short of.
    -- See ns:GetMarkLaunder for why the price is almost never the one
    -- the spare's rank suggests.
    -- ============================================================
    local launder = ns:GetMarkLaunder(slotID)
    if launder then
        local piece = launder.prevTrack .. " " .. launder.spare.rank ..
            "/" .. launder.spare.maxRank

        -- What the spare actually costs, said before anything else. The
        -- whole reason this rule exists is that the number in the
        -- player's head -- five ranks left, a hundred crests -- is
        -- usually not the number the vendor would charge.
        local price = launder.cost .. " " .. launder.prevCrestTrack
        local net   = launder.saved - launder.cost

        -- Waiting is only advice when there is something to wait FOR.
        -- A spare with one rank above what the slot has seen is already
        -- as cheap as this trade gets: a piece further up its track has
        -- the same single rank to buy, so "hold out for a better one"
        -- would be telling the player to wait for the same price.
        local cheaperExists = launder.paidRanks > 1

        -- And nothing is worth waiting for until the price is real. A
        -- piece for this slot still inside its trade window has not
        -- marked anything yet, so "hold out for a cheaper spare" would
        -- be advice about a number that changes the moment the player
        -- decides to keep what they already looted.
        local pending = launder.pending

        local line
        if pending then
            line = "The " .. pending.track .. " " .. pending.rank .. "/" ..
                pending.maxRank .. " in your bags is still tradeable — "
                .. "settle that first, this price follows it"
        elseif net > 0 then
            line = "The " .. piece .. " in your bags does this for " ..
                price .. " — then this rank is free"
        elseif launder.spareIsCheap then
            line = price .. " on the " .. piece .. " in your bags saves " ..
                launder.saved .. " " .. launder.crestTrack .. " — spend it, " ..
                launder.prevCrestTrack .. " has nowhere better to go"
        elseif cheaperExists then
            line = "The " .. piece .. " in your bags would save " ..
                launder.saved .. " " .. launder.crestTrack .. ", but costs " ..
                price .. " — a " .. launder.prevTrack ..
                " piece further up its track does it for less"
        else
            line = price .. " on the " .. piece .. " in your bags buys this "
                .. "rank instead — an even trade, so spend whichever you "
                .. "have more of"
        end

        local detail = {}
        if pending then
            detail[1] = "That piece marks the slot the moment it binds — "
                .. "putting it on does that, and so does letting its trade "
                .. "timer run out. Giving it away is the only thing that "
                .. "does not. Until one of those happens the slot has still "
                .. "only reached " .. launder.mark .. ", and the " .. piece ..
                " prices at " .. price .. "."
            detail[2] = "Keep it and the slot moves up to " .. pending.ilvl ..
                ", and the " .. piece .. " gets cheaper by however many of "
                .. "its ranks that covers. Worth settling first — this is "
                .. "the only number here that is still up to you."
            return ns.RECOMMEND.USE_LOWER_TRACK, line, detail
        end
        if launder.freeRanks > 0 then
            detail[1] = "This slot has already reached " .. launder.mark ..
                ", so " .. launder.freeRanks .. " of that piece's ranks cost "
                .. "nothing and only the last " .. launder.paidRanks ..
                (launder.paidRanks == 1 and " does" or " do") .. " — " ..
                price .. " to take it to " .. launder.top .. "."
        else
            detail[1] = "Taking that piece to " .. launder.top .. " is " ..
                launder.paidRanks ..
                (launder.paidRanks == 1 and " rank" or " ranks") ..
                " above anything this slot has held, so it is the full " ..
                price .. "."
        end

        detail[#detail + 1] = "The slot has then reached " .. launder.top ..
            ", and what you are wearing goes " .. launder.fromIlvl .. " to " ..
            launder.savedTo .. " for nothing — " .. launder.saved .. " " ..
            launder.crestTrack .. " you keep."

        if net < 0 and not launder.spareIsCheap and cheaperExists then
            -- The one place this advice is genuinely a judgement call,
            -- so it is left as one. Waiting is cheaper; waiting is also
            -- how a player spends the week NOT wearing an item level
            -- that was there for the taking, and nothing here can price
            -- which of those matters more today.
            detail[#detail + 1] = "You hold " .. launder.held .. " " ..
                launder.prevCrestTrack .. ", and a " .. launder.prevTrack ..
                " piece further up its track reaches " .. launder.top ..
                " for fewer of them. Worth waiting for — but if you would "
                .. "rather have the item level now, " .. price ..
                " is the whole price."
        else
            detail[#detail + 1] = "That piece stops at " .. launder.top ..
                " for good; the one you are wearing carries on to " ..
                ns:GetMaxIlvlForTrack(track) .. ", which is why it is still "
                .. "the one to keep."
        end

        return ns.RECOMMEND.USE_LOWER_TRACK, line, detail
    end

    -- ============================================================
    -- RULE 0c: A piece in the bags this slot has never been to
    --
    -- Last of the free ones, and after the spare-piece trade above on
    -- purpose: where both fire it is usually the same piece, and there
    -- the price of the trade is the more useful thing to be told.
    --
    -- What is left for here is the case that had nothing at all: a drop
    -- for a slot already wearing something of the same track, a rank or
    -- two up. No crest changes hands in that story, so no rule about
    -- crests noticed it -- and it is the most common good news the
    -- addon has to give.
    -- ============================================================
    local lift = ns:GetBagLift(slotID)
    if lift then
        local liftLine, liftDetail = BagLiftSentences(lift)
        return ns.RECOMMEND.FREE_UPGRADE, liftLine, liftDetail
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
        local nextRank = waste.overlapRanks + 1

        -- The row is about THIS slot.
        --
        -- It used to spend most of its width directing crests elsewhere
        -- -- "Spend Champion on Waist +5 more (140 held)" -- on a row
        -- headed Neck. True, useful, and the wrong place for it: a
        -- player reading the Neck row is deciding about the neck, and
        -- three-quarters of the sentence was about a belt.
        --
        -- What belongs here is the one fact that decides it: the first
        -- ranks of this track land on item levels the track below
        -- already reaches, so spending the scarcer crest on them buys
        -- nothing the cheaper one could not.
        --
        -- "to", not an arrow: U+2192 is outside the client font's range
        -- and draws as an empty box. The em dash is fine -- it is used
        -- 180-odd times across the addon and renders.
        local line = "Ranks 1-" .. waste.overlapRanks .. " are wasted " ..
            waste.crestTrack .. " — " .. waste.prevTrack .. " reaches " ..
            waste.toIlvl .. " too. Keep " .. waste.crestTrack ..
            " for rank " .. nextRank .. "+"

        -- Where the cheaper crests could go instead is still worth
        -- knowing; it just belongs on the hover, with the arithmetic.
        local detail = {
            waste.crestTrack .. " " .. waste.rank .. "/" .. waste.maxRank ..
                " to " .. waste.overlapRanks .. "/" .. waste.maxRank ..
                " is " .. waste.fromIlvl .. " to " .. waste.toIlvl ..
                ", and a maxed " .. waste.prevTrack .. " piece is " ..
                waste.toIlvl .. " as well — so those " .. waste.wastedCrests ..
                " " .. waste.crestTrack .. " buy item level " ..
                waste.prevCrestTrack .. " already reaches.",
        }
        if sinks > 0 then
            local where = waste.sinkSlots[1]
            if sinks > 1 then
                where = where .. " and " .. (sinks - 1) .. " other" ..
                    (sinks > 2 and "s" or "")
            end
            detail[#detail + 1] = "You hold " .. waste.prevCrestCount .. " " ..
                waste.prevCrestTrack .. ", and " .. where ..
                " can still take them."
        end
        detail[#detail + 1] = "Rank " .. nextRank ..
            " and up is the part nothing cheaper reaches, which is what " ..
            waste.crestTrack .. " is for."

        if sinks > 0 then
            return ns.RECOMMEND.WASTED_CREST, line, detail
        end
        return ns.RECOMMEND.USE_LOWER_TRACK, line, detail
    end

    -- ============================================================
    -- RULE 3.5: The list says make this one, not upgrade it
    --
    -- Ahead of the drop and spend rules because it settles the same
    -- question they do -- should crests go here -- and settles it
    -- harder. Those two say wait, or say how much; this one says the
    -- item in this slot is not the item you are going to wear, so
    -- nothing bought for it survives.
    --
    -- Behind the free-rank rules, because free is free: a rank that
    -- costs nothing is worth taking even on a piece a craft replaces.
    -- ============================================================
    local craftReason, craftDetail =
        ns:GetCraftAdvice(slotID, ns:GetMaxIlvlForTrack(track))
    if craftReason then
        return ns.RECOMMEND.CRAFT_INSTEAD, craftReason, craftDetail
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
    --
    -- Every slot under the threshold counts towards the same
    -- achievement, which is exactly the trap. Crossing into a new track
    -- drops seven or eight slots under the line on the same afternoon,
    -- and the first cut answered every one of them with the same
    -- wallet-wide sentence and the same green "Upgrade now" -- seven
    -- rows telling a player holding 180 Champion to spend 460.
    --
    -- The achievement is a REASON to prefer a slot, not a budget. WHICH
    -- of them happens tonight is the spend plan's question and rules 6-8
    -- below already answer it, so this rule now speaks only for slots
    -- the crests in hand actually reach. The rest fall through and get
    -- the ordering ("Legs and Feet first"), the shortfall, or -- on a
    -- track the content has moved past -- the honest answer that what
    -- the slot is waiting for is a drop.
    --
    -- The whole-achievement arithmetic went to the crest tile, where one
    -- fact about sixteen slots is said once. Same rule that took the
    -- outlook strip off this list.
    -- ============================================================
    for _, achieveTrack in ipairs(ns.TRACK_ORDER) do
        if not ns:HasDiscountAchievement(achieveTrack) then
            local achieveIlvl = ns:GetMaxIlvlForTrack(achieveTrack)
            if ilvl < achieveIlvl then
                -- This slot is below the achievement threshold
                local slotsRemaining, _, upgradeableCount, slots =
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

                    -- Does the wallet reach this slot tonight? The plan
                    -- already answered that, measured against spendable
                    -- rather than held so a reserve is not promised
                    -- away. No entry at all -- unknown crest track, or
                    -- the slot dropped out of the candidate scan -- is
                    -- not evidence against, so it passes through.
                    local aPlan = ns:GetCrestPlan(thisSlotCrestTrack)
                    local aMine = aPlan and aPlan.slots and aPlan.slots[slotID]
                    local reached = (not aMine) or (aMine.paidRanks or 0) > 0

                    local achieveName = ns:GetDiscountAchievementName(achieveTrack)
                    if reached and slotsRemaining == 1 then
                        return ns.RECOMMEND.UPGRADE_NOW,
                            "Last slot for " .. achieveName .. "! 50% off for alts (" ..
                            thisSlotCost .. " " .. thisSlotCrestTrack .. ")"
                    elseif reached then
                        -- This slot's own price, and how much of the
                        -- achievement stands behind it. Nothing about
                        -- the other six that the player cannot act on
                        -- from this row.
                        local after = slotsRemaining - 1
                        return ns.RECOMMEND.UPGRADE_NOW,
                            thisSlotCost .. " " .. thisSlotCrestTrack ..
                            " clears this one for " .. achieveName .. " — " ..
                            after .. (after == 1 and " slot" or " slots") .. " after it"
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

        ------------------------------------------------------------
        -- Is the shortfall this week's problem or the season's?
        --
        -- Every rank in the plan is stamped `funded` against the full
        -- budget -- crests held PLUS what the season cap still allows --
        -- and that flag was recorded and never read. So a slot two keys
        -- away from affordable and a slot the season cannot reach both
        -- said "Need 80 more Champion", and the player had no way to
        -- tell which. Those are opposite instructions: go and run
        -- content, versus stop looking at crests for this slot.
        --
        -- "Farmable" here means this week's allowance covers it. The cap
        -- rises again at every reset, so a slot outside it is waiting on
        -- a reset rather than out of reach forever -- which is why only
        -- the outgrown case below is allowed to say "wants a drop".
        ------------------------------------------------------------
        local farmable = mine.fundedRanks > 0

        -- Where the shortfall is going to come from.
        --
        -- "80 more Champion covers this one too" reads as an instruction
        -- to go and farm Champion, and on a wallet the content has
        -- outgrown that is the wrong instinct entirely: nothing the
        -- player runs pays this tier directly any more. It still
        -- arrives -- capping a higher track spills its income down a
        -- tier -- but as a by-product of content that pays something
        -- else, which is a different plan for the week.
        --
        -- This is the one case where crests really are the wrong thing
        -- to be looking at, so it is the only one that says so, and it
        -- goes above the affordability branches: a slot the season will
        -- not pay for is not made reachable by taking crests off a
        -- better slot.
        if plan.outgrown and not farmable then
            return ns.RECOMMEND.SAVE_FOR_DROP,
                "More " .. crestTrack .. " than the season pays out — it "
                .. "only arrives as overflow now. Wants a drop"
        end

        if plan.spendable >= crestCost then
            -- Affordable on its own, but only by taking the crests off a
            -- slot worth more. This is the case the old "Hold crests"
            -- fired on; it now names which slot, and what closing the
            -- gap would cost.
            -- Not a shortage, an order. With crests enough for every
            -- slot on the track nothing is being kept back and nothing
            -- is at risk of missing out, so "hold" is the wrong word for
            -- "later" -- and it is the word that makes a player sit on a
            -- wallet they have been told twice is full.
            if plan.abundant then
                return ns.RECOMMEND.UPGRADE_LATER,
                    who .. " first — this one is covered too"
            end

            local line = who .. " first — " .. short .. " more " .. crestTrack
            return ns.RECOMMEND.HOLD_CRESTS,
                farmable and (line .. " covers this")
                    -- Past the allowance, "80 more Champion" is a number
                    -- with nowhere to come from this week, and left bare
                    -- it reads as a farming target.
                    or (line .. ", past this week's cap")
        end

        if farmable then
            return ns.RECOMMEND.UPGRADE_LATER,
                "Need " .. short .. " more " .. crestTrack .. " — the cap "
                .. "allows " .. plan.seasonEarnable .. " more, so this is "
                .. "farmable. " .. who .. " first"
        end
        return ns.RECOMMEND.UPGRADE_LATER,
            "Need " .. short .. " more " .. crestTrack .. " — past this "
            .. "week's cap, so it waits on a reset or a drop. " .. who
            .. " first"
    end

    local finish = ns.GetTrackCompletion and ns:GetTrackCompletion(crestTrack)

    ------------------------------------------------------------
    -- Deep run on a track the content has moved past: hold, and let a
    -- drop choose the slot.
    --
    -- This is the reserve, back, and in the form it should always have
    -- had. The mark has to be set BEFORE the higher piece is upgraded,
    -- and a Hero 1/6 will land in one of these slots without asking --
    -- so the crests are worth most in hand, ready to finish whichever
    -- Champion piece the drop lands on top of. The player does not
    -- choose that slot; the game does. Finishing the Champion piece is
    -- enough on its own -- the mark applies retroactively and the piece
    -- does not have to be worn -- and the Hero piece in that slot then
    -- starts at 2/6 instead of 1/6.
    --
    -- Spend the same crests now and you are picking that slot yourself,
    -- from six, before the drop has told you which one it is. Same 100
    -- crests, one-in-six odds of them mattering.
    --
    -- Only on a track the player has outgrown, and only for runs deep
    -- enough to be a real bet. A piece two ranks from its cap is cheap
    -- enough to just do, and the anti-hoarding rule stands everywhere
    -- else: crests held with nothing to react to are power not worn.
    ------------------------------------------------------------
    if ns:IsHeldForDrops(plan, slotID) then
        local n = #(ns.GEAR_TRACKS[plan.markTrack] or {})
        local full = mine.wantedRanks * crestCost
        return ns.RECOMMEND.HOLD_CRESTS,
            "Hold " .. full .. " " .. crestTrack .. " — spend it when a " ..
            (plan.markTrack or "higher") .. " " .. plan.dropRank .. "/" .. n ..
            " lands here",
            -- Said the way a player would say it.
            --
            -- The previous version explained the mechanic -- "you have to
            -- set the mark before you upgrade the Hero piece" -- which is
            -- both jargon and a rule nobody asked to be taught. "Set the
            -- mark" is this file's vocabulary, not the game's and not the
            -- player's. What they need is the price, why it is a bad
            -- price right now, and the two things that would change it.
            {
                full .. " " .. crestTrack .. " to take this from " ..
                    rank .. "/" .. maxRank .. " to " ..
                    ns:GetMaxIlvlForTrack(track) .. ", and " ..
                    (finish and finish.needCrest or 0) .. " of your pieces are "
                    .. "this far down — " .. (finish and finish.cost or 0) ..
                    " to cover them all.",
                "Too expensive to spend on a guess. Hold until a " ..
                    (plan.markTrack or "higher") .. " " .. plan.dropRank .. "/" ..
                    #(ns.GEAR_TRACKS[plan.markTrack] or {}) ..
                    " actually lands here — finishing this piece then starts it "
                    .. "at " .. plan.markRank .. "/" ..
                    #(ns.GEAR_TRACKS[plan.markTrack] or {}) ..
                    " instead — or until a " .. crestTrack ..
                    " piece turns up further up its track, where the same "
                    .. "crests reach the top for less.",
            }
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
        -- "all 1 rank" is not something anyone writes.
        buys = mine.wantedRanks == 1 and "its last rank"
            or ("all " .. mine.wantedRanks .. " ranks")
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
    local trackMax = ns:GetMaxIlvlForTrack(track)

    -- A track that tops out under everything the player loots is
    -- the dominant fact about any spend on it, so it is tested
    -- before the rest. Reaching such a cap still reported "caps the
    -- track", which sounds like an achievement and hides that the
    -- cap is below the worst thing the player is handed -- the mark
    -- it sets can never pay out, and the ranks are stats until the
    -- slot turns over.
    if (plan.bandLow or 0) > 0 and trackMax <= plan.bandLow then
        label = ns.RECOMMEND.SAFE_TEMP
        outcome = " — " .. track .. " tops out under everything you loot"
    elseif mine.promotes and mine.pairSlot then
        -- The pair is the purchase. Capping one half moves nothing, so
        -- the row says what the other half still needs rather than
        -- promising a rebate that cannot land.
        -- No "mark" here either. Rings and trinkets are a pair and the
        -- lower one is what counts -- which is sayable without naming
        -- the bookkeeping behind it.
        outcome = " — caps it, but " .. mine.pairSlot .. " must reach " ..
            mine.paidIlvl .. " too"
    elseif mine.promotes and mine.promotesTo and (plan.markRanks or 0) > 0 then
        -- The item stops at the cap. What carries on is the slot: its
        -- mark now sits at this level, so the next piece to land there
        -- is lifted to it for nothing.
        -- Conditional, because it is conditional. Raid pieces arrive at
        -- different levels off different bosses, so a mark helps the
        -- ones that land under it and owes nothing to the ones above.
        -- Stating it as "next Hero free to 308" promised a rebate on
        -- every drop, when a later boss hands out a piece that already
        -- starts higher.
        local n = #(ns.GEAR_TRACKS[mine.promotesTo] or {})
        outcome = " — caps it; a " .. mine.promotesTo .. " " ..
            plan.dropRank .. "/" .. n .. " drop here then starts at " ..
            plan.markRank .. "/" .. n
    elseif mine.promotes then
        outcome = " — caps the track"
    elseif mine.stickyRanks > 0 and (plan.bandHigh or 0) > 0 then
        outcome = " — clears your " .. plan.bandHigh .. " drops, so it sticks"
    elseif mine.bankedRanks > 0 and (plan.bandLow or 0) > 0 then
        outcome = " — over " .. plan.bandLow .. ", refunded when a " ..
            plan.bandLow .. " drops"
    elseif (plan.bandLow or 0) > 0 then
        -- Nothing bought here outlives a drop, but the track could still
        -- cross the floor -- which makes this a fixable stopgap rather
        -- than a doomed one, so the fix gets named.
        label = ns.RECOMMEND.SAFE_TEMP
        outcome = " — stops under the " .. plan.bandLow .. " you loot; " ..
            trackMax .. " clears it"
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

    -- 1. What it does to this slot.
    if mine.promotes then
        detail[#detail + 1] = "Maxes " .. (mine.slotName or "this slot") ..
            " — its last " .. mine.paidRanks .. " " .. crestTrack ..
            (mine.paidRanks == 1 and " rank, " or " ranks, ") ..
            mine.paidCost .. " crests."
    else
        local shortBy = mine.wantedRanks - mine.paidRanks
        detail[#detail + 1] = "Takes " .. (mine.slotName or "this slot") ..
            " to " .. mine.paidIlvl .. ", " .. shortBy ..
            (shortBy == 1 and " rank " or " ranks ") .. "short of the " ..
            ns:GetMaxIlvlForTrack(track) .. " cap."
    end

    -- 2. What it buys on the piece that replaces it.
    if (plan.bandLow or 0) > 0 and trackMax <= plan.bandLow then
        detail[#detail + 1] = track .. " caps at " .. trackMax ..
            ", under the " .. plan.bandLow .. " you get handed — so every "
            .. "rank here is a stopgap until the slot turns over."
    elseif mine.promotes and mine.pairSlot then
        detail[#detail + 1] = "Counts as a pair, and the lower one is what "
            .. "matters — " .. mine.pairSlot .. " is at " .. mine.pairIlvl ..
            ", so nothing changes until it reaches " .. mine.paidIlvl .. " too."
    elseif mine.promotes and mine.promotesTo and (plan.markRanks or 0) > 0 then
        -- Said in ranks, because that is how the game shows gear and
        -- how players talk about it. "308 instead of 305" is the same
        -- fact in a unit nobody carries in their head.
        local saved = plan.markRanks * ns:GetCrestCost(mine.promotesTo)
        local ranks = #(ns.GEAR_TRACKS[mine.promotesTo] or {})
        detail[#detail + 1] = "A " .. mine.promotesTo .. " piece here would "
            .. "start at " .. plan.markRank .. "/" .. ranks .. " instead of " ..
            plan.dropRank .. "/" .. ranks .. " — " .. saved .. " " ..
            mine.promotesTo .. " saved."
        -- The honest caveat, and the reason the line above says "would".
        -- Raid item level is per BOSS, not per difficulty: the same slot
        -- comes off an early boss low and a late one high, so the mark
        -- pays out on some kills and not others. The advisor cannot see
        -- which bosses you kill.
        detail[#detail + 1] = "Raid drops vary by boss, so that only pays "
            .. "on the ones landing lower."
    elseif mine.stickyRanks > 0 then
        detail[#detail + 1] = "Nothing you run drops above " ..
            plan.bandHigh .. ", so this one is yours to keep."
    elseif (plan.bandLow or 0) > 0 and mine.bankedRanks == 0 then
        detail[#detail + 1] = "Stopping at " .. mine.paidIlvl ..
            " leaves it under the " .. plan.bandLow .. " you get handed, so "
            .. "the next drop just replaces it. Going to " .. trackMax ..
            " would start that piece a rank up."
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
        ------------------------------------------------------------
        -- Every number below is AFTER this upgrade.
        --
        -- The slot leaves the count, its ranks leave the bill, and its
        -- price leaves the wallet. On a row headed "Upgrade now" that is
        -- the frame worth reporting -- it answers "where does clicking
        -- this leave me" -- but nothing SAID so, and the reader was left
        -- holding a Champion count that had quietly dropped the slot
        -- they were hovering and a balance 60 under the tile beside it.
        -- Two numbers that look wrong in a sentence that is right is
        -- worse than the sentence not being there.
        --
        -- Which slot leaves is decided by whether this row actually
        -- carries it to the cap, NOT by `mine.promotes`. Those are the
        -- same thing right up until the track has nothing above it: a
        -- Myth row maxes its slot and promotes nothing, so the count
        -- kept a piece the bill had already paid off.
        ------------------------------------------------------------
        local finishesMine = (mine.wantedRanks or 0) > 0
            and (mine.paidRanks or 0) >= mine.wantedRanks
        local after = math.max(finish.needCrest - (finishesMine and 1 or 0), 0)
        local rest  = math.max(finish.cost - mine.paidCost, 0)
        local left  = math.max(finish.held - mine.paidCost, 0)
        local spends = (mine.paidCost or 0) > 0
        local sinceLead = spends and "After this: " or ""

        ------------------------------------------------------------
        -- The pieces on a track are not the bill for the track.
        --
        -- `finish` prices what is WORN on it. A character with four Hero
        -- pieces and eight Champion ones is not two weeks from being
        -- done with Hero: every one of those Champion slots reopens the
        -- tier the moment a Hero drop lands in it, and the Champion cap
        -- only pays for the first rank or two of that climb.
        --
        -- The arithmetic stays worn-only, because that is the spend
        -- being decided tonight. What stops is drawing the tier's ending
        -- from it -- "you never need one again" is the claim that cannot
        -- survive the other slots existing, and a player who acts on it
        -- spends the wallet flat a fortnight before the drops arrive.
        --
        -- ns:GetSeasonDemand has counted forward like this since it was
        -- written. This is the slot tooltip catching up with it.
        ------------------------------------------------------------
        -- Only the BOOLEAN here. What the waiting slots cost is a fact
        -- about the wallet and is said once on the crest tile, not
        -- sixteen times down the panel -- the rule the outlook strip was
        -- removed for. What the hover needs is narrower: whether it is
        -- allowed to promise the tier ends.
        local sd = ns.GetSeasonDemand and ns:GetSeasonDemand(crestTrack)
        local forGood = ns:GetAwaitedSlots(sd).count == 0

        -- Two short sentences, not one with three clauses hung off it.
        -- The compressed version -- "4 pieces and 400 crests left against
        -- 140 in hand, and it only comes in behind Hero now, so a drop in
        -- those slots is the faster route" -- packs the state, the
        -- income model and the verdict into a single breath, and none of
        -- the three survives it.
        local pieces = after .. " " .. crestTrack ..
            (after == 1 and " piece" or " pieces")
        local state = sinceLead .. pieces .. " short of the cap, " ..
            rest .. " crests" ..
            (spends and (" against your " .. left .. ".")
                or (", and you hold " .. left .. "."))

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
        -- What the track is worth spending on at all.
        --
        -- Every piece left near the bottom is the case where crests are
        -- the wrong tool: five ranks buys one slot's insurance, and
        -- doing that across a set is weeks of farming for something a
        -- single drop hands over. Keep the crests for pieces already
        -- close to their cap and let the rest turn over.
        local allDeep = finish.nearest and finish.nearest >= 4

        if after == 0 then
            detail[#detail + 1] = forGood
                and ("Your last " .. crestTrack ..
                    " piece — you never need one again.")
                or ("The last " .. crestTrack .. " piece you are wearing.")
        elseif allDeep then
            detail[#detail + 1] = sinceLead .. pieces .. " left, none closer "
                .. "than " .. finish.nearest .. " ranks. A drop does that job "
                .. "for free — keep " .. crestTrack .. " for pieces near the top."
        elseif rest <= left then
            detail[#detail + 1] = state .. (forGood
                and (" Enough for all of them, and then " .. crestTrack ..
                    " is done.")
                or " Enough for all of them.")
        elseif finish.withinAllowance then
            detail[#detail + 1] = state .. " The other " .. (rest - left) ..
                " is inside this season's cap — content to run, not a wait."
        else
            detail[#detail + 1] = state .. " The cap allows " ..
                finish.earnable .. " more — about " .. finish.weeks ..
                " weeks, or sooner if one drops."
        end

    end

    -- 3.5. What the wallet is already promised to.
    --
    -- The reserve is subtracted from `spendable` above, so a row can
    -- read "not enough" while the balance on the tile says otherwise --
    -- and without this line the player is looking at a contradiction
    -- rather than at a decision. Only on the OTHER slots: the craft's
    -- own row is a CRAFT_INSTEAD and says all of this in full.
    local craftHold = ns.GetCraftReserve and ns:GetCraftReserve(crestTrack)
    if craftHold and (plan.craftReserve or 0) > 0 and craftHold.slotID ~= slotID then
        detail[#detail + 1] = craftHold.amount .. " " .. crestTrack ..
            " is spoken for by the " .. craftHold.slotName ..
            " your list says to craft — " .. craftHold.ilvl ..
            " at max quality, and the spark for it is already in your bags. "
            .. "That is what this slot is being counted against."
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
    local partnerID = ns.SLOT_PAIRS and ns.SLOT_PAIRS[slotID]
    for otherID, sum in pairs(plan.slots or {}) do
        -- Skip this slot's own pair partner. The pair line two lines up
        -- has already said it is short and by how much, and saying it
        -- again as a separate warning reads as two different problems.
        if otherID ~= slotID and otherID ~= partnerID
            and sum.paidRanks == 0 and sum.wantedRanks > 0
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

    -- Why this one and not its partner. Only worth a line when the pair
    -- actually split on it -- saying "this is best-in-slot" about a piece
    -- with nothing to be chosen over is noise.
    if mine.bis then
        local partnerID = ns.SLOT_PAIRS and ns.SLOT_PAIRS[slotID]
        local partner = partnerID and plan.slots and plan.slots[partnerID]
        if partner and not partner.bis then
            detail[#detail + 1] = "On your best-in-slot list, so it comes "
                .. "before " .. (partner.slotName or "the other") .. "."
        end
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
    [ns.RECOMMEND.CRAFT_INSTEAD]   = 4,  -- yes, but at the crafting table
    ------------------------------------------------ divider falls here
    [ns.RECOMMEND.HOLD_CRESTS]     = 5,  -- not yet, something first
    [ns.RECOMMEND.UPGRADE_LATER]   = 6,  -- not yet, cannot afford it
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
---
--- Craft instead sits INSIDE it, which is the one place this list is not
--- about the vendor. It is still a spend, still tonight, and still the
--- best use of that tier -- the 80 crests just go through a crafting
--- table rather than an upgrade window. Drawn under "keep crests out of
--- these for now" it would say the opposite of what it means.
ns.RECOMMEND_ACTIONABLE_MAX = 4

--- The last rank drawn at full strength. Past it a row is something to
--- know rather than something to do, and the vendor panel greys it.
--- Was a bare `ord >= 6` at the one call site, which is a divider
--- written in a magic number: inserting a label above it silently
--- reclassified two rows that had not changed meaning.
ns.RECOMMEND_LIT_MAX = 6

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
