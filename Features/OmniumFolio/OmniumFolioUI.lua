local _, ns = ...

------------------------------------------------------------
-- Omnium Folio page.
--
-- Two views: the five-step chain driven by your real quest state, and a
-- reference for the Rune rows each step unlocks.
------------------------------------------------------------

ns.OmniumFolioUI = ns.OmniumFolioUI or {}
local UI = ns.OmniumFolioUI
local OF = ns.OmniumFolio

local PAD = 16
local ACCENT   = { 0.72, 0.52, 1.0 }
local ACCENT_HEX = "ffb885ff"

local TABS = {
    { id = "steps", label = "The Chain" },
    { id = "runes", label = "Runes" },
}

local state = { tab = "steps" }

-- Marks are texture markup, not glyphs: the game fonts have no check or
-- circle characters and fall back to empty boxes.
local STATUS = {
    done = {
        rgb = { 0.30, 0.85, 0.40 }, hex = "ff4cd964", pill = "Done",
        mark = "|TInterface\\COMMON\\Indicator-Green:14:14|t",
    },
    active = {
        rgb = { 1.00, 0.80, 0.10 }, hex = "ffffcc1a", pill = "In progress",
        mark = "|TInterface\\COMMON\\Indicator-Yellow:14:14|t",
    },
    todo = {
        rgb = { 0.45, 0.45, 0.50 }, hex = "ff8a8a94", pill = "Not started",
        mark = "|TInterface\\COMMON\\Indicator-Gray:14:14|t",
    },
}

------------------------------------------------------------
-- Widget pools
------------------------------------------------------------
local function AcquireFS(self, parent, template)
    self._fs = self._fs or {}
    self._fsIdx = (self._fsIdx or 0) + 1
    local fs = self._fs[self._fsIdx]
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
        self._fs[self._fsIdx] = fs
    end
    fs:SetParent(parent)
    fs:SetFontObject(template or "GameFontNormal")
    fs:ClearAllPoints()
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetTextColor(1, 1, 1)
    fs:SetText("")
    fs:Show()
    return fs
end

local function AcquireTex(self, parent, layer)
    self._tex = self._tex or {}
    self._texIdx = (self._texIdx or 0) + 1
    local t = self._tex[self._texIdx]
    if not t then
        t = parent:CreateTexture(nil, layer or "BACKGROUND")
        self._tex[self._texIdx] = t
    end
    t:SetParent(parent)
    t:SetDrawLayer(layer or "BACKGROUND")
    t:ClearAllPoints()
    t:SetTexture(nil)
    t:SetVertexColor(1, 1, 1, 1)
    t:Show()
    return t
end

--- Cards are plain textures on the content frame, not child frames: a
--- child frame draws above every FontString owned by its parent, so a
--- card frame would paint straight over its own text. Layers on one
--- frame order correctly regardless of creation order, so a card may be
--- drawn after the text it sits behind has been measured.
local function DrawCard(self, content, x, y, w, h, bg, stripe)
    local card = AcquireTex(self, content, "BACKGROUND")
    card:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
    card:SetSize(w, math.max(h, 1))
    card:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)

    -- Hairline along the top edge, for a little depth.
    local edge = AcquireTex(self, content, "BORDER")
    edge:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
    edge:SetSize(w, 1)
    edge:SetColorTexture(1, 1, 1, 0.05)

    if stripe then
        local s = AcquireTex(self, content, "BORDER")
        s:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
        s:SetSize(3, math.max(h, 1))
        s:SetColorTexture(stripe[1], stripe[2], stripe[3], stripe[4] or 1)
    end
    return card
end

-- Item chips: icon + name, with a real item tooltip on hover.
local function AcquireItemChip(self, parent, itemID)
    self._chip = self._chip or {}
    self._chipIdx = (self._chipIdx or 0) + 1
    local b = self._chip[self._chipIdx]
    if not b then
        b = CreateFrame("Button", nil, parent)
        b:SetHeight(20)
        b._icon = b:CreateTexture(nil, "ARTWORK")
        b._icon:SetSize(18, 18)
        b._icon:SetPoint("LEFT", 0, 0)
        b._icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b._label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b._label:SetPoint("LEFT", b._icon, "RIGHT", 6, 0)
        b:SetScript("OnEnter", function(s)
            if not s._itemID then return end
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(s._itemID)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(s)
            if IsModifiedClick("CHATLINK") and s._link then
                ChatEdit_InsertLink(s._link)
            end
        end)
        self._chip[self._chipIdx] = b
    end
    b:SetParent(parent)
    b:ClearAllPoints()
    b._itemID = itemID

    local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(itemID)
    b._link = link
    b._icon:SetTexture(icon or select(5, GetItemInfoInstant(itemID)) or 134400)
    local hex = (quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        and ITEM_QUALITY_COLORS[quality].hex) or "|cffffffff"
    b._label:SetText(hex .. (name or "item") .. "|r")
    b:SetWidth(24 + b._label:GetStringWidth() + 6)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
    b:Show()
    return b
end

local function AcquireWaypoint(self, parent, wayString, label)
    self._way = self._way or {}
    self._wayIdx = (self._wayIdx or 0) + 1
    local btn = self._way[self._wayIdx]
    if not btn then
        btn = ns.MakeWaypointButton(parent, wayString, label)
        if not btn then return nil end
        self._way[self._wayIdx] = btn
    else
        btn:SetParent(parent)
        if not btn:Rebind(wayString, label) then return nil end
    end
    btn:ClearAllPoints()
    btn:Show()
    return btn
end

local function ReleaseAll(self)
    for _, key in ipairs({ "_fs", "_tex", "_chip", "_way" }) do
        local pool = self[key]
        local idx = self[key .. "Idx"] or 0
        if pool then
            for i = 1, idx do
                if pool[i] then pool[i]:Hide() end
            end
        end
        self[key .. "Idx"] = 0
    end
end

------------------------------------------------------------
-- Shared bits
------------------------------------------------------------
local function SectionHeader(self, content, y, inner, text)
    local fs = AcquireFS(self, content, "GameFontNormal")
    fs:SetPoint("TOPLEFT", PAD, y)
    fs:SetWidth(inner)
    fs:SetTextColor(unpack(ns.COLORS.TEXT_HEADER))
    fs:SetText(text)
    ns.ApplyTextShadow(fs)
    local line = AcquireTex(self, content, "ARTWORK")
    line:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, y - 16)
    line:SetSize(inner, 1)
    line:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.35)
    return y - 24
end

------------------------------------------------------------
-- The Chain
------------------------------------------------------------
function UI:RenderSteps(content, width)
    local y = -10
    local inner = width - PAD * 2
    local done, total = OF:GetProgress()
    local unlocked = OF:IsUnlocked()

    -- ── Header card ─────────────────────────────────────────
    DrawCard(self, content, PAD, y, inner, 64,
        { 0.13, 0.10, 0.19, 0.95 }, { ACCENT[1], ACCENT[2], ACCENT[3], 0.95 })

    local title = AcquireFS(self, content, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD + 14, y - 10)
    title:SetWidth(inner - 130)
    title:SetText("|c" .. ACCENT_HEX .. "Omnium Folio|r")
    ns.ApplyTextShadow(title)

    local count = AcquireFS(self, content, "GameFontNormalLarge")
    count:SetPoint("TOPRIGHT", content, "TOPLEFT", PAD + inner - 14, y - 10)
    count:SetJustifyH("RIGHT")
    count:SetWidth(110)
    count:SetText(("|cffffffff%d|r|cff888888 / %d|r"):format(done, total))

    -- Five discrete pips read better than a bar for a five-step chain.
    local pipW = math.floor((inner - 28 - (total - 1) * 4) / total)
    for i = 1, total do
        local pip = AcquireTex(self, content, "ARTWORK")
        pip:SetPoint("TOPLEFT", content, "TOPLEFT",
            PAD + 14 + (i - 1) * (pipW + 4), y - 38)
        pip:SetSize(pipW, 5)
        if i <= done then
            pip:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.95)
        else
            pip:SetColorTexture(0.22, 0.22, 0.26, 0.9)
        end
    end

    local blurb = AcquireFS(self, content, "GameFontNormalSmall")
    blurb:SetPoint("TOPLEFT", PAD + 14, y - 48)
    blurb:SetWidth(inner - 28)
    blurb:SetTextColor(0.72, 0.70, 0.80)
    blurb:SetText("Runes last the rest of Midnight — this carries into Season 2.")
    y = y - 76

    -- ── Unlock gate ─────────────────────────────────────────
    if not unlocked then
        DrawCard(self, content, PAD, y, inner, 72,
            { 0.20, 0.14, 0.04, 0.9 }, { 1.0, 0.72, 0.1, 0.95 })

        local t = AcquireFS(self, content, "GameFontNormal")
        t:SetPoint("TOPLEFT", PAD + 14, y - 9)
        t:SetWidth(inner - 28)
        t:SetText("|cffffcc00Locked|r  |cff666666·|r  start with |cffffffff"
            .. OF.INTRO.name .. "|r")

        local w = AcquireFS(self, content, "GameFontNormalSmall")
        w:SetPoint("TOPLEFT", PAD + 14, y - 28)
        w:SetWidth(inner - 28)
        w:SetTextColor(0.75, 0.75, 0.75)
        w:SetText(OF.INTRO.where)

        local wp = AcquireWaypoint(self, content, OF.INTRO.waypoint, OF.INTRO.name)
        if wp then wp:SetPoint("TOPLEFT", content, "TOPLEFT", PAD + 14, y - 50) end
        y = y - 82

        local d = AcquireFS(self, content, "GameFontNormalSmall")
        d:SetPoint("TOPLEFT", PAD + 2, y)
        d:SetWidth(inner - 4)
        d:SetTextColor(0.68, 0.68, 0.70)
        d:SetText(OF.INTRO.detail)
        y = y - (d:GetStringHeight() or 12) - 14
    else
        -- Quest giver strip
        local g = AcquireFS(self, content, "GameFontNormalSmall")
        g:SetPoint("TOPLEFT", PAD + 2, y)
        g:SetWidth(inner - 120)
        g:SetTextColor(0.70, 0.70, 0.76)
        g:SetText(("Quests from |cffffffff%s|r\n%s")
            :format(OF.QUEST_GIVER.name, OF.QUEST_GIVER.where))
        local wp = AcquireWaypoint(self, content, OF.QUEST_GIVER.waypoint,
            OF.QUEST_GIVER.name)
        if wp then
            wp:SetPoint("TOPRIGHT", content, "TOPLEFT", PAD + inner, y - 2)
        end
        y = y - (g:GetStringHeight() or 24) - 14
    end

    -- ── Step cards ──────────────────────────────────────────
    for _, step in ipairs(OF.STEPS) do
        local status, progress = OF:GetStepStatus(step)
        local sty = STATUS[status]
        local isDone = status == "done"

        -- Measure first so the card wraps its contents.
        local bodyH = isDone and 0 or 34
        if not isDone and step.itemID then bodyH = bodyH + 24 end
        if progress then bodyH = bodyH + 16 end
        local cardH = 30 + bodyH

        DrawCard(self, content, PAD, y, inner, cardH,
            isDone and { 0.09, 0.11, 0.09, 0.7 } or { 0.13, 0.13, 0.16, 0.92 },
            { sty.rgb[1], sty.rgb[2], sty.rgb[3], isDone and 0.55 or 0.95 })

        local mark = AcquireFS(self, content, "GameFontNormal")
        mark:SetPoint("TOPLEFT", PAD + 12, y - 7)
        mark:SetWidth(18)
        mark:SetTextColor(unpack(sty.rgb))
        mark:SetText(sty.mark)

        local name = AcquireFS(self, content, "GameFontNormal")
        name:SetPoint("TOPLEFT", PAD + 32, y - 7)
        name:SetWidth(inner - 150)
        name:SetText(("|cff777777%d.|r  %s%s|r"):format(
            step.week, isDone and "|cff8a8a8a" or "|cffffffff", step.title))

        -- Status pill, right-aligned
        local pillW = 84
        local pill = AcquireTex(self, content, "ARTWORK")
        pill:SetPoint("TOPRIGHT", content, "TOPLEFT", PAD + inner - 10, y - 6)
        pill:SetSize(pillW, 16)
        pill:SetColorTexture(sty.rgb[1] * 0.25, sty.rgb[2] * 0.25,
                             sty.rgb[3] * 0.25, 0.9)
        local pillFs = AcquireFS(self, content, "GameFontNormalSmall")
        pillFs:SetPoint("TOPRIGHT", content, "TOPLEFT", PAD + inner - 10, y - 7)
        pillFs:SetWidth(pillW)
        pillFs:SetJustifyH("CENTER")
        pillFs:SetText("|c" .. sty.hex .. sty.pill .. "|r")

        local rowY = y - 30

        if not isDone then
            local task = AcquireFS(self, content, "GameFontNormalSmall")
            task:SetPoint("TOPLEFT", PAD + 32, rowY)
            task:SetWidth(inner - 46)
            task:SetTextColor(0.85, 0.85, 0.88)
            task:SetText(step.task)
            rowY = rowY - 15

            local meta = AcquireFS(self, content, "GameFontNormalSmall")
            meta:SetPoint("TOPLEFT", PAD + 32, rowY)
            meta:SetWidth(inner - 46)
            meta:SetTextColor(0.60, 0.60, 0.66)
            meta:SetText(step.hint
                and (step.where .. "  |cff444444·|r  " .. step.hint)
                or step.where)
            rowY = rowY - 16

            if step.itemID then
                local chip = AcquireItemChip(self, content, step.itemID)
                chip:SetPoint("TOPLEFT", content, "TOPLEFT", PAD + 32, rowY)
                local need = AcquireFS(self, content, "GameFontNormalSmall")
                need:SetPoint("LEFT", chip, "RIGHT", 8, 0)
                need:SetWidth(90)
                need:SetTextColor(0.66, 0.66, 0.72)
                need:SetText(("need %d"):format(step.itemCount))
                rowY = rowY - 22
            end

            if progress then
                local p = AcquireFS(self, content, "GameFontNormalSmall")
                p:SetPoint("TOPLEFT", PAD + 32, rowY)
                p:SetWidth(inner - 46)
                p:SetTextColor(1.0, 0.80, 0.10)
                p:SetText(progress)
            end
        end

        y = y - cardH - 6
    end

    -- ── Notes ───────────────────────────────────────────────
    y = y - 8
    y = SectionHeader(self, content, y, inner, "Good to know")
    for _, note in ipairs(OF.NOTES) do
        local n = AcquireFS(self, content, "GameFontNormalSmall")
        n:SetPoint("TOPLEFT", PAD + 4, y)
        n:SetWidth(inner - 8)
        n:SetTextColor(0.66, 0.66, 0.72)
        n:SetText("|c" .. ACCENT_HEX .. "•|r  " .. note)
        y = y - (n:GetStringHeight() or 12) - 4
    end

    return y - 10
end

------------------------------------------------------------
-- Runes
------------------------------------------------------------
function UI:RenderRunes(content, width)
    local y = -10
    local inner = width - PAD * 2
    local done = OF:GetProgress()

    local hdr = AcquireFS(self, content, "GameFontNormalSmall")
    hdr:SetPoint("TOPLEFT", PAD, y)
    hdr:SetWidth(inner)
    hdr:SetTextColor(0.72, 0.70, 0.80)
    hdr:SetText("Each completed step unlocks the next row. Rows with several Runes let you pick one.")
    y = y - (hdr:GetStringHeight() or 12) - 12

    for _, group in ipairs(OF.RUNES) do
        local open = done >= group.row

        -- Row header
        DrawCard(self, content, PAD, y, inner, 22,
            open and { 0.16, 0.11, 0.23, 0.95 } or { 0.10, 0.10, 0.12, 0.8 },
            { ACCENT[1], ACCENT[2], ACCENT[3], open and 0.95 or 0.25 })

        local h = AcquireFS(self, content, "GameFontNormalSmall")
        h:SetPoint("TOPLEFT", PAD + 12, y - 5)
        h:SetWidth(inner - 24)
        if open then
            h:SetText(("|c%sRow %d|r  |cffffffff%s|r  |cff666666%s|r")
                :format(ACCENT_HEX, group.row, group.label, group.pick))
        else
            h:SetText(("|cff5a5a62Row %d  %s|r  |cff44444a— unlocks at step %d|r")
                :format(group.row, group.label, group.row))
        end
        y = y - 26

        for _, rune in ipairs(group.runes) do
            local n = AcquireFS(self, content, "GameFontNormal")
            n:SetPoint("TOPLEFT", PAD + 20, y - 6)
            n:SetWidth(inner - 40)
            if open then
                n:SetText("|cffffe6a8" .. rune.name .. "|r")
            else
                n:SetText("|cff6a6a72" .. rune.name .. "|r")
            end

            local d = AcquireFS(self, content, "GameFontNormalSmall")
            d:SetPoint("TOPLEFT", PAD + 20, y - 24)
            d:SetWidth(inner - 40)
            d:SetTextColor(open and 0.76 or 0.46, open and 0.76 or 0.46,
                           open and 0.80 or 0.50)
            d:SetText(rune.text)

            -- Measured last, drawn behind: layers, not creation order, decide.
            local h2 = 30 + (d:GetStringHeight() or 12)
            DrawCard(self, content, PAD + 10, y, inner - 10, h2,
                { 0.11, 0.11, 0.14, open and 0.9 or 0.5 })
            y = y - h2 - 5
        end
        y = y - 8
    end

    return y - 10
end

------------------------------------------------------------
-- Build
------------------------------------------------------------
function UI:Refresh()
    if not self._content then return end
    ReleaseAll(self)

    local width = self._content:GetWidth()
    if width < 50 then width = 600 end

    local endY
    if state.tab == "runes" then
        endY = self:RenderRunes(self._content, width)
    else
        endY = self:RenderSteps(self._content, width)
    end
    self._content:SetHeight(math.max(-endY + 20, 100))
end

function UI:BuildInto(parent)
    if parent._yyhFolioBuilt then
        self:Refresh()
        return
    end
    parent._yyhFolioBuilt = true

    local host = parent.inner or parent

    local tabBar = CreateFrame("Frame", nil, host)
    tabBar:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -8)
    tabBar:SetPoint("TOPRIGHT", host, "TOPRIGHT", -8, -8)
    tabBar:SetHeight(26)

    local buttons = {}
    local function select(id)
        state.tab = id
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

    local scroll = CreateFrame("ScrollFrame", nil, host, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -6)
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

    select("steps")
end

------------------------------------------------------------
-- Refresh when quest or item state changes while the page is open
------------------------------------------------------------
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("QUEST_LOG_UPDATE")
watcher:RegisterEvent("QUEST_TURNED_IN")
watcher:RegisterEvent("BAG_UPDATE_DELAYED")
watcher:RegisterEvent("ITEM_DATA_LOAD_RESULT")
local pending = false
watcher:SetScript("OnEvent", function()
    if pending then return end
    if not (ns.AppFrame and ns.AppFrame:IsShown()
            and ns.currentAppPage == "omnium") then
        return
    end
    pending = true
    -- These events arrive in bursts; coalesce hard.
    C_Timer.After(0.5, function()
        pending = false
        if ns.AppFrame and ns.AppFrame:IsShown()
            and ns.currentAppPage == "omnium" then
            UI:Refresh()
        end
    end)
end)
