local _, ns = ...

------------------------------------------------------------
-- Midnight Season 2 upgrade currency: Mistcrests.
--
-- Blizzard ships TWO currency IDs per crest tier — one carrying the
-- real description and one silent duplicate. Season 1 had the same
-- quirk (Myth Dawncrest exists as both 3347 and 3348), and picking the
-- wrong one yields a currency that always reads zero.
--
-- Rather than bet on a single ID, each tier lists its candidates in
-- preference order and ResolveCrestIDs() picks the one the client
-- actually recognises at login. `id` starts as the preferred candidate
-- so anything reading ns.CRESTS before PLAYER_LOGIN still works.
------------------------------------------------------------
-- VERIFIED against Wowhead's canonical currency pages, Aug 2026.
--
-- There are TWO complete sets of Mistcrest currency rows in the client:
--
--   3437-3441   dead
--   3442-3446   live      <-- this one
--
-- The addon shipped pointed at the dead block, so a character holding 80
-- Champion Mistcrests read as zero -- and everything that hangs off crest
-- counts (affordability, the waste warning, the whole upgrade advisor)
-- was working from an empty wallet.
--
-- Nothing in the client distinguishes the pairs. Both rows of a track
-- share a name AND a description, and even Wowhead serves both under the
-- same slug: currency=3437 and currency=3442 are both
-- "adventurer-mistcrest". So this cannot be derived, only recorded --
-- and the recorded value cannot be sanity-checked by reading a name
-- back. Verify against wowhead.com/currency=<id> when a season rolls.
--
-- The dead twin stays as a fallback candidate: if a patch swaps which
-- block is live, ResolveCrestIDs follows whichever the player actually
-- holds rather than showing zero until someone edits this file.
ns.CRESTS = {
    { id = 3442, candidates = { 3442, 3437 }, name = "Adventurer Mistcrest", color = "ff1eff00", track = "Adventurer" },
    { id = 3443, candidates = { 3443, 3438 }, name = "Veteran Mistcrest",    color = "ff0070dd", track = "Veteran"    },
    { id = 3444, candidates = { 3444, 3439 }, name = "Champion Mistcrest",   color = "ffa335ee", track = "Champion"   },
    { id = 3445, candidates = { 3445, 3440 }, name = "Hero Mistcrest",       color = "ffff8000", track = "Hero"       },
    { id = 3446, candidates = { 3446, 3441 }, name = "Myth Mistcrest",       color = "ffff0000", track = "Myth"       },
}

--- The catalyst charge currency.
---
--- Recorded rather than derived, like the crest rows above and with the
--- same caveat: nothing in the client marks which currency this is, so
--- it can only be written down. Cross-checked against LariasWeeklyChecklist's
--- constants file, which is maintained against a live client each season.
--- Verify at wowhead.com/currency=3465 when a season rolls.
ns.CATALYST_CURRENCY_ID = 3465

-- Season 1 Dawncrests. Kept only so the addon can warn about crests
-- left unspent when Season 1 locks at the 12.1 launch.
ns.LEGACY_CRESTS = {
    { id = 3383, name = "Adventurer Dawncrest", track = "Adventurer" },
    { id = 3341, name = "Veteran Dawncrest",    track = "Veteran"    },
    { id = 3343, name = "Champion Dawncrest",   track = "Champion"   },
    { id = 3345, name = "Hero Dawncrest",       track = "Hero"       },
    { id = 3347, name = "Myth Dawncrest",       track = "Myth"       },
}

-- Weekly earning increment (cumulative cap increases by this each week)
ns.CREST_WEEKLY_INCREMENT = 100

------------------------------------------------------------
-- Pick the live currency ID for each tier.
--
-- A candidate wins if the client returns currency info with a non-empty
-- name. When both candidates resolve (which is the normal case, since
-- both rows exist in the client DB), prefer whichever the character has
-- actually earned; failing that, keep the listed preference order.
------------------------------------------------------------
function ns:ResolveCrestIDs()
    if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then return end

    for _, crest in ipairs(ns.CRESTS) do
        local best, bestEarned = nil, -1
        for _, id in ipairs(crest.candidates) do
            local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
            if ok and info and info.name and info.name ~= "" then
                local earned = (info.totalEarned or 0) + (info.quantity or 0)
                if earned > bestEarned then
                    best, bestEarned = id, earned
                end
                -- Trust the client's own name over our hardcoded string.
                if best == id then crest.name = info.name end
            end
        end
        if best then crest.id = best end
    end
    ns._crestsResolved = true
end

local resolver = CreateFrame("Frame")
resolver:RegisterEvent("PLAYER_LOGIN")
-- Re-resolve whenever the wallet moves.
--
-- Resolving once at login is wrong for the case that matters most: on a
-- fresh season a character has ZERO of both candidate rows, so the tie
-- breaks on listed order and the pick is a coin toss. The moment crests
-- actually arrive -- unboxed, earned, whatever -- the evidence changes,
-- and the pick has to change with it. Before this, unboxing 80 Champion
-- Mistcrests onto the other row left the addon reading the empty one
-- until the next login.
resolver:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
resolver:SetScript("OnEvent", function()
    ns:ResolveCrestIDs()
end)

function ns:GetCrestInfo()
    -- Resolved here too, not only on the event. Core.lua answers
    -- CURRENCY_DISPLAY_UPDATE by refreshing the crest panel, and the
    -- order two frames receive the same event is not defined -- so
    -- relying on the resolver alone would leave the display one event
    -- behind whenever Core happened to run first. It is ten currency
    -- lookups; correctness is worth more than that.
    ns:ResolveCrestIDs()

    local crests = {}
    for _, crest in ipairs(ns.CRESTS) do
        local info = C_CurrencyInfo.GetCurrencyInfo(crest.id)
        if info then
            table.insert(crests, {
                name = crest.name,
                color = crest.color,
                track = crest.track,
                quantity = info.quantity,
                maxQuantity = info.maxQuantity or 0,
                earnedThisWeek = info.quantityEarnedThisWeek or 0,
                weeklyMax = info.maxWeeklyQuantity or 0,
                totalEarned = info.totalEarned or 0,
                seasonCap = info.useTotalEarnedForMaxQty and info.maxQuantity or 0,
                icon = info.iconFileID,
                -- The currency's real rarity and id, both of which the
                -- API already returns and this was discarding. `color`
                -- above is our own track legend -- Hero orange, Myth red
                -- -- and is not what the game calls these currencies.
                quality = info.quality,
                currencyID = crest.id,
            })
        end
    end
    return crests
end

function ns:GetCrestWeeklyInfo(track)
    -- Same reason as GetCrestInfo: this is the other read path, used by
    -- the upgrade recommender and the planner, and Recommend.lua reads
    -- crest.id directly straight after calling it.
    ns:ResolveCrestIDs()

    for _, crest in ipairs(ns.CRESTS) do
        if crest.track == track then
            local info = C_CurrencyInfo.GetCurrencyInfo(crest.id)
            if info then
                local earned = info.quantityEarnedThisWeek or 0
                local cap    = info.maxWeeklyQuantity or 0

                -- Crests are capped CUMULATIVELY, not weekly.
                --
                -- Dumping every currency the client caps per week comes
                -- back with two, and no crest is either of them --
                -- maxWeeklyQuantity is zero on all five. The allowance
                -- is a season total that grows by CREST_WEEKLY_INCREMENT
                -- each week and is measured against totalEarned, which
                -- is what useTotalEarnedForMaxQty means.
                --
                -- Reading only the weekly fields therefore reported a
                -- cap of zero for every crest, so "have you capped this
                -- week" could never answer yes -- on a character that
                -- had.
                if cap <= 0 and (info.maxQuantity or 0) > 0
                    and info.useTotalEarnedForMaxQty then
                    earned = info.totalEarned or 0
                    cap    = info.maxQuantity
                end

                return {
                    quantity = info.quantity,
                    earnedThisWeek = earned,
                    weeklyMax = cap,
                    weeklyRemaining = math.max(cap - earned, 0),
                    -- So callers can say "300 this season" rather than
                    -- "300 this week", which would be a different and
                    -- wrong claim.
                    cumulative = (info.maxWeeklyQuantity or 0) <= 0,
                }
            end
        end
    end
    return { quantity = 0, earnedThisWeek = 0, weeklyMax = 0, weeklyRemaining = 0 }
end

function ns:GetCrestCountByTrack(track)
    for _, crest in ipairs(ns.CRESTS) do
        if crest.track == track then
            local info = C_CurrencyInfo.GetCurrencyInfo(crest.id)
            if info then
                return info.quantity
            end
        end
    end
    return 0
end

function ns:RefreshCrests()
    if not ns.CrestFrames then return end

    local crests = ns:GetCrestInfo()
    local hideDefault = ns._gearAppMode
    for i, frame in ipairs(ns.CrestFrames) do
        local data = crests[i]
        if data then
            frame.icon:SetTexture(data.icon)
            local discountStr = ""
            if ns.HasDiscountAchievement and ns:HasDiscountAchievement(data.track) then
                discountStr = " |cff00ff00-50%|r"
            end

            -- Season cap + weekly info
            local capStr = ""
            if data.seasonCap and data.seasonCap > 0 then
                capStr = string.format("  |cff888888%d/%d|r", data.totalEarned, data.seasonCap)
            end
            local weekStr = ""
            if data.weeklyMax > 0 then
                local weekRemain = math.max(data.weeklyMax - data.earnedThisWeek, 0)
                if weekRemain > 0 then
                    weekStr = string.format("  |cff666666+%dw|r", weekRemain)
                end
            end

            -- What the balance BUYS, next to the balance itself.
            --
            -- A crest count on its own is not a number anyone acts on --
            -- the question is always how many upgrades it is, and the
            -- suggestions below refer to exactly that. It used to be
            -- carried by a per-track header down in the list, which both
            -- restated these rows and pushed the advice off the page.
            local buysStr = ""
            local plan = ns.GetCrestPlan and ns:GetCrestPlan(data.track)
            if plan and plan.slotCount > 0 then
                buysStr = string.format("  |cffdddddd%d up|r", plan.affordableNow)
                -- A wallet the content has moved past still buys real
                -- upgrades -- stats now, and a high-water mark the next
                -- drop cashes in -- so the count above stays. What it
                -- cannot buy is an item level the player keeps, and
                -- without saying so the row reads exactly like a live
                -- track. This is the one word that explains why the
                -- advice under it looks strange.
                if plan.outgrown then
                    buysStr = buysStr .. "  |cffff8800outgrown|r"
                end
                if plan.reserve > 0 then
                    -- Named, because a reserve is the addon declining to
                    -- plan crests the player can see in this very row.
                    buysStr = buysStr .. string.format(
                        "  |cffffcc44%d kept|r", plan.reserve)
                end
            end

            frame.text:SetText(string.format(
                "|c%s%s|r  %d%s%s%s%s",
                data.color, data.track, data.quantity, discountStr,
                buysStr, capStr, weekStr
            ))
            if not hideDefault then frame:Show() end
        else
            frame:Hide()
        end
    end

    -- Also update app-mode crest frames if they exist
    if ns.AppCrestFrames then
        for i, af in ipairs(ns.AppCrestFrames) do
            local data = crests[i]
            if data and af:IsShown() then
                af.icon:SetTexture(data.icon)
                af.countFs:SetText("|cffffffff" .. data.quantity .. "|r")

                local parts = {}
                if data.seasonCap and data.seasonCap > 0 then
                    local seasonRemain = math.max(data.seasonCap - data.totalEarned, 0)
                    local col = seasonRemain <= 0 and "ff555555" or "ff888888"
                    table.insert(parts, "|c" .. col .. data.totalEarned .. "/" .. data.seasonCap .. "|r")
                end
                if data.weeklyMax > 0 then
                    local weekRemain = math.max(data.weeklyMax - data.earnedThisWeek, 0)
                    if weekRemain > 0 then
                        table.insert(parts, "|cff666666+" .. weekRemain .. "w|r")
                    end
                end
                af.upgFs:SetText(table.concat(parts, " "))
            end
        end
    end
end
