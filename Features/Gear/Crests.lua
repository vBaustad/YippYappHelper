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
--
-- Primary set (3437-3441) is the one whose in-game descriptions name
-- the Season 2 item level ranges and sources. Run /yh crests to see
-- what resolved on your client.
------------------------------------------------------------
ns.CRESTS = {
    { id = 3437, candidates = { 3437, 3442 }, name = "Adventurer Mistcrest", color = "ff1eff00", track = "Adventurer" },
    { id = 3438, candidates = { 3438, 3443 }, name = "Veteran Mistcrest",    color = "ff0070dd", track = "Veteran"    },
    { id = 3439, candidates = { 3439, 3444 }, name = "Champion Mistcrest",   color = "ffa335ee", track = "Champion"   },
    { id = 3440, candidates = { 3440, 3445 }, name = "Hero Mistcrest",       color = "ffff8000", track = "Hero"       },
    { id = 3441, candidates = { 3441, 3446 }, name = "Myth Mistcrest",       color = "ffff0000", track = "Myth"       },
}

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
resolver:SetScript("OnEvent", function()
    ns:ResolveCrestIDs()
end)

function ns:GetCrestInfo()
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
            })
        end
    end
    return crests
end

function ns:GetCrestWeeklyInfo(track)
    for _, crest in ipairs(ns.CRESTS) do
        if crest.track == track then
            local info = C_CurrencyInfo.GetCurrencyInfo(crest.id)
            if info then
                return {
                    quantity = info.quantity,
                    earnedThisWeek = info.quantityEarnedThisWeek or 0,
                    weeklyMax = info.maxWeeklyQuantity or 0,
                    weeklyRemaining = math.max((info.maxWeeklyQuantity or 0) - (info.quantityEarnedThisWeek or 0), 0),
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

            frame.text:SetText(string.format(
                "|c%s%s|r  %d%s%s%s",
                data.color, data.track, data.quantity, discountStr, capStr, weekStr
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
