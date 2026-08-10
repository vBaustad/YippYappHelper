local _, ns = ...

------------------------------------------------------------
-- Trinkets page.
--
-- Two views over the same bloodmallet data:
--   "My Spec"      — what should I equip, ranked.
--   "Loot Council" — pick a trinket, see which specs actually want it,
--                    so a raid lead can say "only Frost DKs roll on this"
--                    without alt-tabbing.
------------------------------------------------------------

ns.TrinketUI = ns.TrinketUI or {}
local UI = ns.TrinketUI
local T = ns.Trinkets

local PAD = 12
local ROW_H = 22
local TABS = {
    { id = "spec",    label = "My Spec" },
    { id = "council", label = "Loot Council" },
}

local ACCENT = { 0.45, 0.85, 1.0 }

-- Fight style applies to both views, so it is a separate control rather
-- than four tabs: "My Spec / AoE" and "Loot Council / AoE" are the same
-- question asked of two different lists.
local STYLES = {
    { id = "ST",  label = "Single Target" },
    { id = "AOE", label = "AoE" },
}

local state = { tab = "spec", selected = nil, style = "ST" }

------------------------------------------------------------
-- Row pool
------------------------------------------------------------
local function AcquireRow(self, parent)
    self._rows = self._rows or {}
    self._rowIdx = (self._rowIdx or 0) + 1
    local row = self._rows[self._rowIdx]
    if not row then
        row = CreateFrame("Button", nil, parent, "BackdropTemplate")
        row:SetHeight(ROW_H)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 4, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.rank:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.rank:SetWidth(28)
        row.rank:SetJustifyH("LEFT")
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.text:SetPoint("LEFT", row.rank, "RIGHT", 4, 0)
        row.text:SetJustifyH("LEFT")
        row.value = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.value:SetPoint("RIGHT", -8, 0)
        row.value:SetJustifyH("RIGHT")
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.06)
        hl:SetBlendMode("ADD")
        self._rows[self._rowIdx] = row
    end
    row:SetParent(parent)
    row:ClearAllPoints()
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)
    row:SetScript("OnClick", nil)
    row.value:SetText("")
    row.rank:SetText("")
    row:Show()
    return row
end

local function ReleaseRows(self)
    for i = 1, (self._rowIdx or 0) do
        if self._rows[i] then self._rows[i]:Hide() end
    end
    self._rowIdx = 0
end

------------------------------------------------------------
-- Item icon/name resolution (async-safe)
------------------------------------------------------------
local function applyItem(row, itemID, fallbackName)
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
    row.icon:SetTexture(icon or 134400)

    local name, link, quality
    if C_Item and C_Item.GetItemInfo then
        name, link, quality = C_Item.GetItemInfo(itemID)
    end
    local label = name or fallbackName or ("item:" .. tostring(itemID))
    if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
        label = ITEM_QUALITY_COLORS[quality].hex .. label .. "|r"
    end
    row.text:SetText(label)

    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(itemID)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    if not name and C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
end

------------------------------------------------------------
-- Views
------------------------------------------------------------
local function relColor(rel)
    if rel >= -0.5 then return "|cff40ff40" end
    if rel >= -2.0 then return "|cffd0ff40" end
    if rel >= -5.0 then return "|cffffcc00" end
    return "|cffff8080"
end

function UI:RenderMySpec(content, width)
    local y = -6
    local specKey = T:GetPlayerSpecKey()

    if not specKey then
        local fs = AcquireRow(self, content)
        fs:SetPoint("TOPLEFT", PAD, y)
        fs:SetWidth(width - PAD * 2)
        fs.text:SetText("|cff888888Could not determine your specialization.|r")
        return y - ROW_H
    end

    local list, ilvl, stamp = T:GetForSpec(specKey, state.style)
    if not list then
        local fs = AcquireRow(self, content)
        fs:SetPoint("TOPLEFT", PAD, y)
        fs:SetWidth(width - PAD * 2)
        -- Distinguish "not simmed at all" from "simmed, but not for this
        -- fight style" -- a few specs have single target only, and saying
        -- "no sims for you" there reads as a data failure.
        local otherStyle = (state.style == "ST") and "AOE" or "ST"
        if T:GetForSpec(specKey, otherStyle) then
            fs.text:SetText(("|cff888888bloodmallet has no %s sims for %s -- try the other tab.|r")
                :format(state.style == "ST" and "single-target" or "AoE", T:SpecName(specKey)))
        else
            fs.text:SetText(("|cff888888bloodmallet has no trinket sims for %s this tier.|r")
                :format(T:SpecName(specKey)))
        end
        return y - ROW_H
    end

    local hdr = AcquireRow(self, content)
    hdr:SetPoint("TOPLEFT", PAD, y)
    hdr:SetWidth(width - PAD * 2)
    hdr.icon:SetTexture(nil)
    hdr.text:SetText(("%s  |cff666666at item level %d|r")
        :format(T:ColorSpec(specKey), ilvl or 0))
    hdr.value:SetText("|cff666666vs best|r")
    y = y - ROW_H - 4

    for rank, row in ipairs(list) do
        local r = AcquireRow(self, content)
        r:SetPoint("TOPLEFT", PAD, y)
        r:SetWidth(width - PAD * 2)
        r.rank:SetText("|cff888888" .. rank .. ".|r")
        applyItem(r, row.id, row.name)
        if rank == 1 then
            r.value:SetText("|cff40ff40best|r")
        else
            r.value:SetText(("%s%.1f%%|r"):format(relColor(row.rel), row.rel))
        end
        y = y - ROW_H
    end

    if stamp and stamp ~= "" then
        local fs = AcquireRow(self, content)
        fs:SetPoint("TOPLEFT", PAD, y - 6)
        fs:SetWidth(width - PAD * 2)
        fs.text:SetText("|cff666666Simmed " .. stamp .. " — bloodmallet.com|r")
        y = y - ROW_H - 6
    end
    return y
end

function UI:RenderCouncil(content, width)
    local y = -6
    local all = T:GetAllTrinkets(state.style)

    if not all or #all == 0 then
        local fs = AcquireRow(self, content)
        fs:SetPoint("TOPLEFT", PAD, y)
        fs:SetWidth(width - PAD * 2)
        fs.text:SetText("|cff888888No trinket data loaded.|r")
        return y - ROW_H
    end

    local intro = AcquireRow(self, content)
    intro:SetPoint("TOPLEFT", PAD, y)
    intro:SetWidth(width - PAD * 2)
    intro.icon:SetTexture(nil)
    intro.text:SetText("|cffaaaaaaClick a trinket to expand it, click again to collapse.|r")
    y = y - ROW_H - 2

    -- Read state.selected when the click happens, not when the row is
    -- built. Rows come from a pool and are rebuilt on every refresh, so a
    -- captured flag is one render out of date the moment anything else
    -- changes the selection.
    local function toggle(id)
        state.selected = (state.selected == id) and nil or id
        UI:Refresh()
    end

    for _, bucket in ipairs(all) do
        local r = AcquireRow(self, content)
        r:SetPoint("TOPLEFT", PAD, y)
        r:SetWidth(width - PAD * 2)
        applyItem(r, bucket.id, bucket.name)

        local top = bucket.specs[1]
        local isOpen = (state.selected == bucket.id)
        if top then
            r.value:SetText(("%s |cff888888best: #%d|r")
                :format(isOpen and "|cff888888-|r" or "|cff888888+|r", top.rank))
        end
        r:SetScript("OnClick", function() toggle(bucket.id) end)
        y = y - ROW_H

        if isOpen then
            for _, entry in ipairs(bucket.specs) do
                local sr = AcquireRow(self, content)
                sr:SetPoint("TOPLEFT", PAD + 26, y)
                sr:SetWidth(width - PAD * 2 - 26)
                sr.icon:SetTexture(nil)
                sr.rank:SetText("|cff888888#" .. entry.rank .. "|r")
                sr.text:SetText(T:ColorSpec(entry.key))
                -- Collapse from the spec rows as well: with a long list
                -- expanded, the header you opened it from can be scrolled
                -- off, and clicking the block you are looking at is the
                -- obvious way to close it.
                sr:SetScript("OnClick", function() toggle(bucket.id) end)
                if entry.rank == 1 then
                    sr.value:SetText("|cff40ff40top pick|r")
                else
                    sr.value:SetText(("%s%.1f%%|r")
                        :format(relColor(entry.rel), entry.rel))
                end
                y = y - ROW_H
            end
            y = y - 4
        end
    end
    return y
end

------------------------------------------------------------
-- Build
------------------------------------------------------------
function UI:Refresh()
    if not self._content then return end
    ReleaseRows(self)

    local width = self._content:GetWidth()
    if width < 50 then width = 600 end

    local endY
    if state.tab == "spec" then
        endY = self:RenderMySpec(self._content, width)
    else
        endY = self:RenderCouncil(self._content, width)
    end
    self._content:SetHeight(math.max(-endY + 20, 100))
end

function UI:BuildInto(parent)
    if parent._yyhTrinketsBuilt then
        self:Refresh()
        return
    end
    parent._yyhTrinketsBuilt = true

    local host = parent.inner or parent

    -- Tabs
    local tabBar = CreateFrame("Frame", nil, host)
    tabBar:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -8)
    tabBar:SetPoint("TOPRIGHT", host, "TOPRIGHT", -8, -8)
    tabBar:SetHeight(26)

    local buttons = {}
    local function select(id)
        state.tab = id
        state.selected = nil
        for tid, btn in pairs(buttons) do
            if tid == id then ns.SetTabActive(btn) else ns.SetTabInactive(btn) end
        end
        self:Refresh()
    end

    local x = 0
    for _, def in ipairs(TABS) do
        local btn = ns.CreateUnderlineTab(tabBar, def.label, ACCENT)
        btn:SetSize(110, 24)
        btn:SetPoint("TOPLEFT", tabBar, "TOPLEFT", x, 0)
        btn:SetScript("OnClick", function() select(def.id) end)
        buttons[def.id] = btn
        x = x + 116
    end

    -- Fight style, right-aligned so it reads as a modifier on the view
    -- rather than a third view. Styles with no data anywhere are skipped
    -- outright instead of offered as a tab onto an empty list.
    local styleButtons = {}
    local function selectStyle(id)
        state.style = id
        state.selected = nil
        for sid, btn in pairs(styleButtons) do
            if sid == id then ns.SetTabActive(btn) else ns.SetTabInactive(btn) end
        end
        self:Refresh()
    end

    local sx = 0
    for i = #STYLES, 1, -1 do
        local def = STYLES[i]
        if T:HasStyle(def.id) then
            local btn = ns.CreateUnderlineTab(tabBar, def.label, ACCENT)
            local w = (def.id == "ST") and 100 or 60
            btn:SetSize(w, 24)
            btn:SetPoint("TOPRIGHT", tabBar, "TOPRIGHT", -sx, 0)
            btn:SetScript("OnClick", function() selectStyle(def.id) end)
            styleButtons[def.id] = btn
            sx = sx + w + 6
        end
    end
    -- Fall back to whatever style does exist, so the page is never blank.
    if not styleButtons[state.style] then
        state.style = next(styleButtons) or "ST"
    end
    if styleButtons[state.style] then selectStyle(state.style) end

    -- Staleness banner
    local banner
    if T:IsStale() then
        banner = host:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        banner:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 4, -4)
        banner:SetPoint("RIGHT", host, "RIGHT", -12, 0)
        banner:SetJustifyH("LEFT")
        banner:SetWordWrap(true)
        banner:SetText(T:StaleText())
    end

    local scroll = CreateFrame("ScrollFrame", nil, host, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, banner and -24 or -6)
    scroll:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -26, 8)
    scroll:SetScript("OnMouseWheel", function(sf, delta)
        local newVal = sf:GetVerticalScroll() - delta * 30
        newVal = math.max(0, math.min(newVal, sf:GetVerticalScrollRange()))
        sf:SetVerticalScroll(newVal)
    end)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(math.max(host:GetWidth() - 40, 400), 400)
    scroll:SetScrollChild(content)
    self._content = content
    self._scroll = scroll

    select("spec")
end
