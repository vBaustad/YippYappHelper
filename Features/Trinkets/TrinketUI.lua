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

local state = { tab = "spec", selected = nil, style = "ST",
                search = "", showAll = false }

-- A ranked list is a top-N question. Twenty-five rows is a wall that
-- also forces a scrollbar; ten answers "what should I use" and the rest
-- are one click away.
local TOP_N = 10
local MAX_SEARCH_ROWS = 15
local MAX_SUGGEST = 5

------------------------------------------------------------
-- Search
------------------------------------------------------------
-- Names live in the sim data, so matching needs no item API and works
-- for items this client has never seen.
--
-- Lowercased once and cached on the entry itself. The alternative --
-- string.lower over every trinket on every keystroke -- is essentially
-- the entire cost of having a search box, and it buys nothing: the data
-- is static for the session.
local function lowerName(entry)
    local lc = entry._lc
    if not lc then
        lc = (entry.name or ""):lower()
        entry._lc = lc
    end
    return lc
end

--- Plain-text find, not a pattern match: trinket names contain "(", "-"
--- and "'", any of which would either error or silently mean something
--- else as a Lua pattern.
local function matches(entry, needle)
    if needle == "" then return true end
    return lowerName(entry):find(needle, 1, true) ~= nil
end

--- Whatever the active tab is listing, for search and suggestions.
local function currentEntries()
    if state.tab == "spec" then
        local specKey = T:GetPlayerSpecKey()
        local list = specKey and T:GetForSpec(specKey, state.style)
        return list or {}
    end
    return T:GetAllTrinkets(state.style) or {}
end

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

-- Wrapped multi-line text. AcquireRow is a fixed 22px single line, and
-- the caveat needs to breathe: clipping it to one row would truncate a
-- warning into a confident-looking fragment, which is the exact failure
-- the caveat exists to prevent.
--
-- Returns the fontstring so the caller can measure it — the height
-- depends on how the text wraps at the current panel width.
local function AcquireNote(self, parent, width, text)
    self._notes = self._notes or {}
    self._noteIdx = (self._noteIdx or 0) + 1
    local fs = self._notes[self._noteIdx]
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        self._notes[self._noteIdx] = fs
    end
    fs:SetParent(parent)
    fs:ClearAllPoints()
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetTextColor(0.60, 0.60, 0.66)
    fs:SetText(text)
    fs:Show()
    return fs
end

local function ReleaseRows(self)
    for i = 1, (self._rowIdx or 0) do
        if self._rows[i] then self._rows[i]:Hide() end
    end
    self._rowIdx = 0
    for i = 1, (self._noteIdx or 0) do
        if self._notes and self._notes[i] then self._notes[i]:Hide() end
    end
    self._noteIdx = 0
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

    -- Above the list, not below it. A spec's ranking runs to 25 rows --
    -- roughly 550px against a 500px panel -- so a caveat placed after it
    -- sits permanently below the scroll fold, where it qualifies nothing
    -- because nobody reads it. It frames the numbers, so it goes first.
    local caveat = ns.GEAR_CAVEAT and ns.GEAR_CAVEAT.trinket
    if caveat then
        local note = AcquireNote(self, content, width - PAD * 2, caveat)
        note:SetPoint("TOPLEFT", PAD, y - 2)
        y = y - (note:GetStringHeight() or 30) - 10
    end

    local hdr = AcquireRow(self, content)
    hdr:SetPoint("TOPLEFT", PAD, y)
    hdr:SetWidth(width - PAD * 2)
    hdr.icon:SetTexture(nil)
    hdr.text:SetText(("%s  |cff666666at item level %d|r")
        :format(T:ColorSpec(specKey), ilvl or 0))
    hdr.value:SetText("|cff666666vs best|r")
    y = y - ROW_H - 4

    -- Long-hand on purpose. `state.showAll and #list or TOP_N` reads
    -- fine and is wrong the moment #list is 0, because 0 is truthy in
    -- Lua and the fallback never fires.
    local needle = state.search
    local limit
    if needle ~= "" then
        limit = MAX_SEARCH_ROWS
    elseif state.showAll then
        limit = #list
    else
        limit = TOP_N
    end

    -- rank comes from the position in the FULL list, not from the loop
    -- counter. Filtering must not renumber things: a trinket that is
    -- 14th stays 14th when you search for it, or the number is a lie.
    local shown, hidden = 0, 0
    for rank, row in ipairs(list) do
        if matches(row, needle) then
            if shown < limit then
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
                shown = shown + 1
            else
                hidden = hidden + 1
            end
        end
    end

    if shown == 0 then
        local fs = AcquireRow(self, content)
        fs:SetPoint("TOPLEFT", PAD, y)
        fs:SetWidth(width - PAD * 2)
        fs.text:SetText("|cff888888No trinket matches that name.|r")
        y = y - ROW_H
    elseif hidden > 0 then
        local more = AcquireRow(self, content)
        more:SetPoint("TOPLEFT", PAD, y)
        more:SetWidth(width - PAD * 2)
        more.icon:SetTexture(nil)
        if needle ~= "" then
            more.text:SetText(("|cff888888%d more match — refine the search.|r")
                :format(hidden))
        else
            more.text:SetText(("|cff888888+%d more|r  |cffaaaaaaShow all|r"):format(hidden))
            more:SetScript("OnClick", function()
                state.showAll = true
                UI:Refresh()
            end)
        end
        y = y - ROW_H
    elseif state.showAll and needle == "" then
        local less = AcquireRow(self, content)
        less:SetPoint("TOPLEFT", PAD, y)
        less:SetWidth(width - PAD * 2)
        less.icon:SetTexture(nil)
        less.text:SetText(("|cffaaaaaaShow top %d only|r"):format(TOP_N))
        less:SetScript("OnClick", function()
            state.showAll = false
            UI:Refresh()
        end)
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

    -- Above the list, not below it. A spec's ranking runs to 25 rows --
    -- roughly 550px against a 500px panel -- so a caveat placed after it
    -- sits permanently below the scroll fold, where it qualifies nothing
    -- because nobody reads it. It frames the numbers, so it goes first.
    local caveat = ns.GEAR_CAVEAT and ns.GEAR_CAVEAT.trinket
    if caveat then
        local note = AcquireNote(self, content, width - PAD * 2, caveat)
        note:SetPoint("TOPLEFT", PAD, y - 2)
        y = y - (note:GetStringHeight() or 30) - 10
    end


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
    -- Written long-hand on purpose. The obvious `cond and nil or id` is
    -- broken in Lua: nil is falsy, so the `and` branch falls straight
    -- through to the `or` and the expression can never yield nil. That is
    -- why this row expanded but would not collapse.
    local function toggle(id)
        if state.selected == id then
            state.selected = nil
        else
            state.selected = id
        end
        UI:Refresh()
    end

    local needle = state.search
    local limit
    if needle ~= "" then
        limit = MAX_SEARCH_ROWS
    elseif state.showAll then
        limit = #all
    else
        limit = TOP_N
    end
    local shown, hidden = 0, 0

    for _, bucket in ipairs(all) do
      if matches(bucket, needle) then
       if shown >= limit then
        hidden = hidden + 1
       else
        shown = shown + 1
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
      end
    end

    if shown == 0 then
        local fs = AcquireRow(self, content)
        fs:SetPoint("TOPLEFT", PAD, y)
        fs:SetWidth(width - PAD * 2)
        fs.text:SetText("|cff888888No trinket matches that name.|r")
        y = y - ROW_H
    elseif hidden > 0 then
        local more = AcquireRow(self, content)
        more:SetPoint("TOPLEFT", PAD, y)
        more:SetWidth(width - PAD * 2)
        more.icon:SetTexture(nil)
        if needle ~= "" then
            more.text:SetText(("|cff888888%d more match — refine the search.|r")
                :format(hidden))
        else
            more.text:SetText(("|cff888888+%d more|r  |cffaaaaaaShow all|r"):format(hidden))
            more:SetScript("OnClick", function()
                state.showAll = true
                UI:Refresh()
            end)
        end
        y = y - ROW_H
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

    ------------------------------------------------------------
    -- Search
    ------------------------------------------------------------
    local searchBox = CreateFrame("EditBox", nil, host, "SearchBoxTemplate")
    searchBox:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 4, banner and -22 or -4)
    searchBox:SetSize(220, 20)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(40)
    if searchBox.Instructions then
        searchBox.Instructions:SetText("Search trinkets")
    end

    -- Suggestions hang off host rather than the scroll content so they
    -- float over the list instead of pushing it down, and so scrolling
    -- cannot carry them out of view while the box still has focus.
    local suggest = CreateFrame("Frame", nil, host, "BackdropTemplate")
    suggest:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 8, -2)
    suggest:SetWidth(260)
    suggest:SetFrameStrata("DIALOG")
    suggest:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
    })
    suggest:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
    suggest:SetBackdropBorderColor(0.30, 0.30, 0.34, 1)
    suggest:Hide()

    local suggestRows = {}
    local function suggestRow(i)
        local b = suggestRows[i]
        if not b then
            b = CreateFrame("Button", nil, suggest)
            b:SetHeight(18)
            b:SetPoint("TOPLEFT", 4, -2 - (i - 1) * 18)
            b:SetPoint("RIGHT", suggest, "RIGHT", -4, 0)
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            b.text:SetPoint("LEFT", 2, 0)
            b.text:SetJustifyH("LEFT")
            local hl = b:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.10)
            suggestRows[i] = b
        end
        return b
    end

    -- Stops at MAX_SUGGEST rather than collecting everything and
    -- trimming: with a few hundred trinkets in the council view the
    -- difference is the whole loop versus five iterations, on every
    -- keystroke.
    local applyingSuggestion = false

    local function updateSuggestions(text)
        local needle = text:lower()
        if needle == "" then suggest:Hide() return end

        local n = 0
        local seen = {}
        for _, entry in ipairs(currentEntries()) do
            local name = entry.name
            if name and not seen[name] and matches(entry, needle) then
                seen[name] = true
                n = n + 1
                local b = suggestRow(n)
                b.text:SetText(name)
                b:SetScript("OnClick", function()
                    -- Flagged so OnTextChanged does not immediately
                    -- rebuild the suggestion list we are about to hide.
                    applyingSuggestion = true
                    searchBox:SetText(name)
                    applyingSuggestion = false
                    searchBox:ClearFocus()
                    suggest:Hide()
                end)
                b:Show()
                if n >= MAX_SUGGEST then break end
            end
        end
        for i = n + 1, #suggestRows do suggestRows[i]:Hide() end
        if n == 0 then
            suggest:Hide()
        else
            suggest:SetHeight(n * 18 + 6)
            suggest:Show()
        end
    end

    -- Debounced. Typing "alnseer" is seven refreshes without this, each
    -- rebuilding every row; coalescing means one. The token guards
    -- against an earlier timer firing after a later keystroke.
    local searchToken = 0
    -- HookScript, NOT SetScript, on every script the template defines.
    --
    -- SearchBoxTemplate's own OnTextChanged is what hides the "Search"
    -- placeholder and shows the clear button; its OnEditFocusLost puts
    -- the placeholder back; its OnEscapePressed empties the box.
    -- Replacing them left the placeholder painted over whatever was
    -- typed and the clear button out of step with the field.
    searchBox:HookScript("OnTextChanged", function(box, userInput)
        -- Deliberately NOT gated on userInput.
        --
        -- SearchBoxTemplate's clear button empties the box
        -- programmatically, so userInput is false and the old guard
        -- dropped the event -- the text vanished while state.search kept
        -- its old needle and the list stayed filtered with no way back
        -- short of a reload. Clicking a suggestion had the same fault
        -- from the other side: it set the text and the search never
        -- applied.
        --
        -- Re-entrancy is handled by the applyingSuggestion flag and by
        -- the no-op check below, so the guard bought nothing.
        local text = box:GetText() or ""
        if not applyingSuggestion then updateSuggestions(text) end

        searchToken = searchToken + 1
        local mine = searchToken
        C_Timer.After(0.12, function()
            if mine ~= searchToken then return end
            local needle = text:lower()
            if needle == state.search then return end
            state.search = needle
            state.selected = nil
            UI:Refresh()
        end)
    end)

    searchBox:HookScript("OnEscapePressed", function(box)
        box:SetText("")
        box:ClearFocus()
        suggest:Hide()
        if state.search ~= "" then
            state.search = ""
            UI:Refresh()
        end
    end)
    searchBox:HookScript("OnEnterPressed", function(box)
        box:ClearFocus()
        suggest:Hide()
    end)
    searchBox:HookScript("OnEditFocusLost", function() suggest:Hide() end)

    self._searchBox = searchBox

    local scroll = CreateFrame("ScrollFrame", nil, host, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -4, -6)
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
