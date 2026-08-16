local _, ns = ...

------------------------------------------------------------
-- Currencies.
--
-- The rail showed five crests and nothing else, which is a fraction of
-- what a season actually asks you to track. This reads the player's own
-- currency list -- the same one the character sheet's Currency tab shows
-- -- so the addon lists what the game lists, grouped the way the game
-- groups it, without a hand-maintained table that goes stale every patch.
--
-- C_CurrencyInfo.GetCurrencyListInfo walks a flat list where headers and
-- entries are interleaved and `currencyListDepth` says how deep you are.
-- Headers can be collapsed by the player, in which case their children
-- are simply absent from the list rather than flagged -- so a collapsed
-- header legitimately has no items and is dropped rather than rendered
-- as an empty group.
--
-- Crests are deliberately NOT part of this. They are the thing the addon
-- is mostly about, they have their own resolved IDs (see
-- Features/Gear/Crests.lua, where two parallel ID blocks exist and only
-- one is live), and they get their own strip at the top of the rail.
------------------------------------------------------------

--- Currency IDs already shown elsewhere, so the general list does not
--- repeat them.
local function crestIDs()
    local out = {}
    for _, c in ipairs(ns.CRESTS or {}) do
        -- Guarded because indexing with nil is a crash, not a miss, and
        -- this runs on every rail refresh -- including ones that can
        -- happen before ResolveCrestIDs has settled which of each tier's
        -- two candidate IDs is the live one.
        if c.id then out[c.id] = true end
        for _, candidate in ipairs(c.candidates or {}) do
            if candidate then out[candidate] = true end
        end
    end
    return out
end

--- The current expansion's name, as the currency list spells it.
---
--- The list's top-level headers are expansions, and everything under one
--- -- Delves, Professions, Season 2, Zones -- is a child of it at a
--- greater currencyListDepth. So "only this expansion's currencies" is
--- answerable from the data rather than from a curated list that would
--- need editing every launch.
local function currentExpansionName()
    if type(GetExpansionLevel) ~= "function" then return nil end
    local ok, level = pcall(GetExpansionLevel)
    if not ok or not level then return nil end
    return _G["EXPANSION_NAME" .. level]
end

--- Grouped currencies: { { header = "Midnight", items = { info, ... } }, ... }
---
--- Scoped to the current expansion. The full list runs to a dozen dead
--- headers from expansions nobody is playing, and a rail that needs
--- scrolling past Legion to reach this week's crests is worse than no
--- rail. Everything is still in the game's own Currency tab.
---
--- Returns an empty table rather than nil when the API is unavailable, so
--- callers can iterate without guarding twice.
function ns:GetCurrencyGroups()
    local groups = {}
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize) then
        return groups
    end

    local ok, size = pcall(C_CurrencyInfo.GetCurrencyListSize)
    if not ok or not size or size == 0 then return groups end

    local skip = crestIDs()
    local current = nil

    -- Depth of the expansion header we are inside, and whether it is the
    -- one we want. nil means we have not met a top-level header yet, in
    -- which case entries are kept: a list with no expansion headers at
    -- all should show its contents rather than nothing.
    local expansion = currentExpansionName()
    local rootDepth, inScope = nil, true

    for i = 1, size do
        local infoOk, info = pcall(C_CurrencyInfo.GetCurrencyListInfo, i)
        -- Documented as MayReturnNothing, and the list can change under
        -- us mid-walk when a currency is earned.
        if infoOk and info then
            local depth = tonumber(info.currencyListDepth) or 0
            if info.isHeader then
                if rootDepth == nil or depth <= rootDepth then
                    -- A top-level header: an expansion. Everything until
                    -- the next one belongs to it.
                    rootDepth = depth
                    inScope = (expansion == nil) or (info.name == expansion)
                end
                current = inScope and { header = info.name or "", items = {} } or nil
                if current then groups[#groups + 1] = current end
            elseif not inScope then
                -- Belongs to an expansion we are not showing.
            elseif not info.isTypeUnused and not skip[info.currencyID] then
                if not current then
                    current = { header = "", items = {} }
                    groups[#groups + 1] = current
                end
                current.items[#current.items + 1] = {
                    currencyID = info.currencyID,
                    name       = info.name,
                    quantity   = info.quantity or 0,
                    icon       = info.iconFileID,
                    quality    = info.quality,
                    maxQuantity = info.maxQuantity or 0,
                    totalEarned = info.totalEarned or 0,
                    useTotalEarned = info.useTotalEarnedForMaxQty,
                    accountWide = info.isAccountWide,
                }
            end
        end
    end

    -- Collapsed headers arrive with no children. Rendering them would be
    -- a list of empty boxes that the player cannot expand from here.
    local out = {}
    for _, g in ipairs(groups) do
        if #g.items > 0 then out[#out + 1] = g end
    end
    return out
end

--- How close a currency is to its cap, or nil when it has none.
---
--- Two different caps exist and they are not interchangeable: most
--- currencies cap the amount you may hold (`maxQuantity` against
--- `quantity`), while season currencies cap what you may earn in total
--- (`useTotalEarnedForMaxQty`, measured against `totalEarned`). Reading
--- the wrong one shows a full wallet as empty the moment you spend.
function ns:GetCurrencyCapProgress(entry)
    if not entry or (entry.maxQuantity or 0) <= 0 then return nil end
    local have = entry.useTotalEarned and entry.totalEarned or entry.quantity
    return have or 0, entry.maxQuantity
end
