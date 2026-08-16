local _, ns = ...

------------------------------------------------------------
-- Constants
------------------------------------------------------------
local EQUIP_PANEL_WIDTH = 440
local INFO_PANEL_WIDTH = 280
local FRAME_HEIGHT = 500

local function GetInfoWidth()
    return ns._infoPanelRef and ns._infoPanelRef:GetWidth() or INFO_PANEL_WIDTH
end
local SLOT_SIZE = 36
local LABEL_MAX_WIDTH = 150

local QUALITY_COLORS = {
    [0] = { 0.6, 0.6, 0.6 },   -- Poor
    [1] = { 1.0, 1.0, 1.0 },   -- Common
    [2] = { 0.12, 1.0, 0.0 },  -- Uncommon
    [3] = { 0.0, 0.44, 0.87 }, -- Rare
    [4] = { 0.64, 0.21, 0.93 },-- Epic
    [5] = { 1.0, 0.5, 0.0 },   -- Legendary
}

------------------------------------------------------------
-- Main container (holds both panels)
------------------------------------------------------------
local container = CreateFrame("Frame", "YippYappHelperFrame", UIParent)
container:SetSize(EQUIP_PANEL_WIDTH + INFO_PANEL_WIDTH, FRAME_HEIGHT)
container:SetPoint("CENTER")
container:SetMovable(true)
container:EnableMouse(true)
container:RegisterForDrag("LeftButton")
container:SetScript("OnDragStart", function(self)
    if not ns.upgradeVendorOpen then
        self:StartMoving()
    end
end)
container:SetScript("OnDragStop", container.StopMovingOrSizing)
container:SetClampedToScreen(true)
container:SetFrameStrata("MEDIUM")
container:Hide()
ns.MainFrame = container

-- ESC closes the frame: add/remove from UISpecialFrames dynamically
-- so we don't eat ESC when the frame is hidden
container:SetScript("OnShow", function()
    if container.inAppMode then return end
    tinsert(UISpecialFrames, "YippYappHelperFrame")
end)
container:SetScript("OnHide", function()
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "YippYappHelperFrame" then
            table.remove(UISpecialFrames, i)
            break
        end
    end
end)

------------------------------------------------------------
-- Left panel: Equipment
------------------------------------------------------------
local equipPanel = CreateFrame("Frame", nil, container, "BackdropTemplate")
equipPanel:SetSize(EQUIP_PANEL_WIDTH, FRAME_HEIGHT)
equipPanel:SetPoint("TOPLEFT")
equipPanel:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
equipPanel:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
equipPanel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
ns.SmoothFrame(equipPanel)

-- Title
local equipTitle = equipPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
equipTitle:SetPoint("TOP", 0, -12)
ns.ApplyTextShadow(equipTitle)
equipTitle:SetText("|cff00ff00YippYapp Helper|r")

-- Close button
local close = CreateFrame("Button", nil, container, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", container, "TOPRIGHT", -2, -2)

-- Divider below title
local equipDivider = equipPanel:CreateTexture(nil, "ARTWORK")
equipDivider:SetHeight(1)
equipDivider:SetPoint("TOPLEFT", 12, -36)
equipDivider:SetPoint("TOPRIGHT", -12, -36)
equipDivider:SetColorTexture(0.5, 0.5, 0.5, 0.6)

------------------------------------------------------------
-- Right panel: Crests & Suggestions
------------------------------------------------------------
local infoPanel = CreateFrame("Frame", nil, container, "BackdropTemplate")
infoPanel:SetSize(INFO_PANEL_WIDTH, FRAME_HEIGHT)
infoPanel:SetPoint("TOPLEFT", equipPanel, "TOPRIGHT", -1, 0)
ns._infoPanelRef = infoPanel
infoPanel:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
infoPanel:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
infoPanel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
ns.SmoothFrame(infoPanel)

-- Crests header
local crestHeader = infoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
crestHeader:SetPoint("TOPLEFT", 14, -14)
crestHeader:SetText("Crests")

local crestDivider = infoPanel:CreateTexture(nil, "ARTWORK")
crestDivider:SetHeight(1)
crestDivider:SetPoint("TOPLEFT", crestHeader, "BOTTOMLEFT", 0, -4)
crestDivider:SetPoint("RIGHT", infoPanel, "RIGHT", -14, 0)
crestDivider:SetColorTexture(0.5, 0.5, 0.5, 0.4)

-- Crest rows (5 for Midnight S1)
ns.CrestFrames = {}
for i = 1, #ns.CRESTS do
    local row = CreateFrame("Frame", nil, infoPanel)
    row:SetSize(GetInfoWidth() - 28, 20)
    row:SetPoint("TOPLEFT", crestDivider, "BOTTOMLEFT", 0, -4 - (i - 1) * 22)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT")

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetJustifyH("LEFT")

    ns.CrestFrames[i] = row
end

-- Suggestions header
local suggestHeader = infoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
suggestHeader:SetPoint("TOPLEFT", crestDivider, "BOTTOMLEFT", 0, -4 - (#ns.CRESTS) * 22 - 10)
suggestHeader:SetText("Suggestions")

local suggestDivider = infoPanel:CreateTexture(nil, "ARTWORK")
suggestDivider:SetHeight(1)
suggestDivider:SetPoint("TOPLEFT", suggestHeader, "BOTTOMLEFT", 0, -4)
suggestDivider:SetPoint("RIGHT", infoPanel, "RIGHT", -14, 0)
suggestDivider:SetColorTexture(0.5, 0.5, 0.5, 0.4)

-- Scrollable suggestions area
local suggestScroll = CreateFrame("ScrollFrame", nil, infoPanel, "UIPanelScrollFrameTemplate")
suggestScroll:SetPoint("TOPLEFT", suggestDivider, "BOTTOMLEFT", 0, -6)
suggestScroll:SetPoint("BOTTOMRIGHT", infoPanel, "BOTTOMRIGHT", -28, 12)

local suggestContent = CreateFrame("Frame", nil, suggestScroll)
suggestContent:SetSize(GetInfoWidth() - 42, 1)
suggestScroll:SetScrollChild(suggestContent)

ns.SuggestContent = suggestContent
ns.SuggestEntries = {}

------------------------------------------------------------
-- App mode: strip chrome, scale up equip panel, rearrange crests
------------------------------------------------------------
-- Space between the paper doll and the suggestions beneath it.
local GEAR_STACK_GAP = 10

local APP_SCALE = math.max(1.0, 1.2 * ns:GetUIScale())  -- scale with screen, min 1.0

-- Create larger crest display frames for app mode (2-column layout)
local appCrestFrames = {}
for i = 1, #ns.CRESTS do
    local crestDef = ns.CRESTS[i]
    local af = CreateFrame("Frame", nil, infoPanel, "BackdropTemplate")
    af:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    af:SetBackdropColor(0.08, 0.08, 0.08, 0.8)
    af:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.4)

    af.icon = af:CreateTexture(nil, "ARTWORK")
    af.icon:SetSize(20, 20)
    af.icon:SetPoint("LEFT", 8, 0)
    af.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    af.countFs = af:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    af.countFs:SetPoint("LEFT", af.icon, "RIGHT", 6, 0)

    af.nameFs = af:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    af.nameFs:SetPoint("LEFT", af.countFs, "RIGHT", 4, 0)
    af.nameFs:SetText("|c" .. crestDef.color .. crestDef.track .. "|r")

    af.upgFs = af:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    af.upgFs:SetPoint("RIGHT", -8, 0)

    af:Hide()
    appCrestFrames[i] = af
end
ns.AppCrestFrames = appCrestFrames

ns._gearAppMode = false

function ns:SetGearAppMode(enabled, contentWidth, contentHeight)
    ns._gearAppMode = enabled
    if enabled then
        container:SetMovable(false)
        container:EnableMouse(false)
        -- Both panels used to be stripped to nothing in app mode, which
        -- made sense when the app frame was a plain dark box behind them.
        -- On the shell they read as two ungrouped piles of widgets, so
        -- they take a surface from the skin instead.
        if ns.Widgets then
            ns.Widgets:Apply(equipPanel, "inset")
            ns.Widgets:Apply(infoPanel, "inset")
        else
            equipPanel:SetBackdrop(nil)
            infoPanel:SetBackdrop(nil)
        end
        close:Hide()
        equipTitle:Hide()
        equipDivider:Hide()

        local totalW = contentWidth or ns:GetAppFrameSize()

        local totalH = contentHeight or select(2, ns:GetAppFrameSize()) or 580

        -- Stacked, not side by side.
        --
        -- Beside each other, neither half got what it needed: the doll is
        -- a 440-wide two-column slot list whose content stops well short
        -- of its panel, and the suggestions had a 280px column to write
        -- sentences in. Both were mostly air, in different directions.
        --
        -- Stacking gives the doll the height it wants and hands the
        -- suggestions the full width, which is the dimension a list of
        -- "slot -- what to do about it" actually uses.
        -- The suggestions take what their content needs, not a share of
        -- the page. At 30% they were claiming 198px to show three and a
        -- half cards, and every pixel of that came off the doll -- which
        -- is height-bound, so it was the expensive place to be generous.
        local SUGGEST_H = math.min(math.max(150, math.floor(totalH * 0.26)), 220)
        local dollH = totalH - SUGGEST_H - GEAR_STACK_GAP

        -- The doll scales to whichever runs out first, its height or the
        -- page's width. Fixed at 1.2 it was sized for a 960px window and
        -- overflowed everything narrower.
        -- Cap raised past APP_SCALE's 1.2. That constant was a
        -- magnification limit for a fixed-size window; here the region
        -- decides, and clamping to 1.2 would only bite on a screen wide
        -- AND tall enough to want more.
        --
        -- In practice height binds and width does not come close: the
        -- doll is 440x500, so a 700-wide region would allow 1.59x on
        -- width while the height budget allows about 0.96x. Making it
        -- meaningfully wider means changing the doll's own two-column
        -- layout, not this arithmetic.
        local scale = math.min(1.45,
            dollH / FRAME_HEIGHT,
            totalW / EQUIP_PANEL_WIDTH)
        equipPanel:SetScale(scale)
        local scaledEquipW = math.floor(EQUIP_PANEL_WIDTH * scale)

        -- Centred: the doll is narrower than the page even scaled up, and
        -- left-aligning it would leave a hole down the right.
        --
        -- Offsets are in the panel's own units because SetScale changes
        -- what a point means to its children -- dividing by scale is what
        -- keeps it centred rather than drifting as the scale changes.
        equipPanel:ClearAllPoints()
        equipPanel:SetPoint("TOPLEFT", container, "TOPLEFT",
            math.floor((totalW - scaledEquipW) / 2) / scale, 0)

        infoPanel:ClearAllPoints()
        infoPanel:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(dollH + GEAR_STACK_GAP))
        infoPanel:SetSize(totalW, SUGGEST_H)
        container:SetSize(totalW, totalH)
        suggestContent:SetWidth(totalW - 42)

        -- Hide default small crest rows (prevent RefreshCrests from showing them)
        for _, row in ipairs(ns.CrestFrames) do row:Hide() end
        crestHeader:Hide()
        crestDivider:Hide()

        -- Show large 2-column crests.
        --
        -- Width from totalW: the info panel used to be a narrow column
        -- beside the doll and is now a full-width band beneath it, so
        -- newInfoW no longer exists. Left as it was this line did
        -- arithmetic on nil, which is an error rather than a bad layout.
        local colW = math.floor((totalW - 28 - 10) / 2)
        local rowH = 36

        -- The shell keeps a currency rail on every page, so inside it
        -- this grid is the same five numbers a second time, six inches
        -- apart. Suppressed there and the space given to suggestions,
        -- which had been pushed into the bottom third of the panel to
        -- make room for the duplicate.
        local railOwnsCrests = ns.Shell and ns.Shell.IsOpen and ns.Shell:IsOpen()

        for i, af in ipairs(appCrestFrames) do
            if railOwnsCrests then
                af:Hide()
            else
                local col = (i - 1) % 2
                local r = math.floor((i - 1) / 2)
                af:SetSize(colW, rowH)
                af:ClearAllPoints()
                af:SetPoint("TOPLEFT", infoPanel, "TOPLEFT", 14 + col * (colW + 10), -14 - r * (rowH + 6))
                af:Show()
            end
        end

        -- Move suggestions header below the crest grid
        local crestRows = math.ceil(#ns.CRESTS / 2)
        local crestBlockH = railOwnsCrests and 0 or (crestRows * (rowH + 6) + 10)
        suggestHeader:ClearAllPoints()
        suggestHeader:SetPoint("TOPLEFT", infoPanel, "TOPLEFT", 14, -14 - crestBlockH)
        suggestDivider:ClearAllPoints()
        suggestDivider:SetPoint("TOPLEFT", suggestHeader, "BOTTOMLEFT", 0, -4)
        suggestDivider:SetPoint("RIGHT", infoPanel, "RIGHT", -14, 0)
    else
        -- Restore chrome
        container:SetMovable(true)
        container:EnableMouse(true)
        equipPanel:SetScale(1)
        equipPanel:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        equipPanel:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
        equipPanel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        infoPanel:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        infoPanel:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
        infoPanel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        close:Show()
        equipTitle:Show()
        equipDivider:Show()

        -- Restore original sizes and positions
        equipPanel:SetSize(EQUIP_PANEL_WIDTH, FRAME_HEIGHT)
        equipPanel:ClearAllPoints()
        equipPanel:SetPoint("TOPLEFT")
        infoPanel:SetSize(INFO_PANEL_WIDTH, FRAME_HEIGHT)
        infoPanel:ClearAllPoints()
        infoPanel:SetPoint("TOPLEFT", equipPanel, "TOPRIGHT", -1, 0)
        container:SetSize(EQUIP_PANEL_WIDTH + INFO_PANEL_WIDTH, FRAME_HEIGHT)
        suggestContent:SetWidth(INFO_PANEL_WIDTH - 42)

        -- Restore default crest rows
        for _, row in ipairs(ns.CrestFrames) do row:Show() end
        crestHeader:Show()
        crestDivider:Show()

        -- Hide app crest frames
        for _, af in ipairs(appCrestFrames) do af:Hide() end

        -- Restore suggestions header position
        suggestHeader:ClearAllPoints()
        suggestHeader:SetPoint("TOPLEFT", crestDivider, "BOTTOMLEFT", 0, -4 - (#ns.CRESTS) * 22 - 10)
        suggestDivider:ClearAllPoints()
        suggestDivider:SetPoint("TOPLEFT", suggestHeader, "BOTTOMLEFT", 0, -4)
        suggestDivider:SetPoint("RIGHT", infoPanel, "RIGHT", -14, 0)
    end
end

local suggestRowPool = {}
local suggestRowPoolIdx = 0

local function AcquireSuggestRow()
    suggestRowPoolIdx = suggestRowPoolIdx + 1
    local row = suggestRowPool[suggestRowPoolIdx]
    if not row then
        row = CreateFrame("Frame", nil, suggestContent, "BackdropTemplate")
        row:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets   = { left = 2, right = 2, top = 2, bottom = 2 },
        })

        row.slotFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.slotFs:SetPoint("TOPLEFT", 10, -6)

        row.tagFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.tagFs:SetPoint("TOPRIGHT", -10, -6)
        row.tagFs:SetJustifyH("RIGHT")

        row.reasonFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.reasonFs:SetPoint("TOPLEFT", 10, -22)
        row.reasonFs:SetJustifyH("LEFT")
        row.reasonFs:SetWordWrap(true)
        row.reasonFs:SetTextColor(0.55, 0.55, 0.55)

        suggestRowPool[suggestRowPoolIdx] = row
    end
    row:ClearAllPoints()
    row:Show()
    return row
end

-- Legacy pool for non-app mode (keeps old format working at vendor)
local suggestFontPool = {}
local suggestFontPoolIdx = 0

local function AcquireFontString(template)
    suggestFontPoolIdx = suggestFontPoolIdx + 1
    local fs = suggestFontPool[suggestFontPoolIdx]
    if not fs then
        fs = suggestContent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
        suggestFontPool[suggestFontPoolIdx] = fs
    else
        fs:SetFontObject(template or "GameFontNormalSmall")
        fs:SetTextColor(1, 1, 1)
        fs:SetWordWrap(false)
    end
    fs:ClearAllPoints()
    fs:Show()
    return fs
end

function ns:RefreshSuggestions()
    -- Hide all previous elements
    for i = 1, suggestFontPoolIdx do suggestFontPool[i]:Hide() end
    suggestFontPoolIdx = 0
    for i = 1, suggestRowPoolIdx do suggestRowPool[i]:Hide() end
    suggestRowPoolIdx = 0
    wipe(ns.SuggestEntries)

    local recommendations = ns:GetAllRecommendations()

    -- Sort: actionable items first, skip empty/maxed
    local sorted = {}
    for _, slotInfo in ipairs(ns.SLOT_IDS) do
        local r = recommendations[slotInfo.slot]
        if r and r.recommendation ~= ns.RECOMMEND.NO_ITEM and r.recommendation ~= ns.RECOMMEND.MAXED then
            table.insert(sorted, r)
        end
    end

    local labelOrder = {
        [ns.RECOMMEND.FREE_UPGRADE]   = 0,
        [ns.RECOMMEND.UPGRADE_NOW]    = 1,
        [ns.RECOMMEND.BAD_INVESTMENT] = 2,
        [ns.RECOMMEND.WASTED_CREST]   = 2,
        [ns.RECOMMEND.HOLD_CRESTS]    = 3,
        [ns.RECOMMEND.SAFE_TEMP]      = 4,
        [ns.RECOMMEND.UPGRADE_LATER]  = 5,
        [ns.RECOMMEND.USE_LOWER_TRACK] = 5,
        [ns.RECOMMEND.CRAFT_INSTEAD]  = 6,
        [ns.RECOMMEND.WAIT_BETTER]    = 7,
    }
    table.sort(sorted, function(a, b)
        local oa = labelOrder[a.recommendation] or 99
        local ob = labelOrder[b.recommendation] or 99
        if oa ~= ob then return oa < ob end
        local pa = ns.SLOT_PRIORITY[a.slotID] or 2
        local pb = ns.SLOT_PRIORITY[b.slotID] or 2
        return pa > pb
    end)

    local w = GetInfoWidth() - 42
    local yOffset = 0

    if ns._gearAppMode then
        -- ── App mode: card-style rows ──
        for _, r in ipairs(sorted) do
            local rec = r.recommendation
            local row = AcquireSuggestRow()
            row:SetWidth(w)
            row:SetPoint("TOPLEFT", 0, -yOffset)

            -- Subtle background tinted by recommendation color
            row:SetBackdropColor(0.08, 0.08, 0.08, 0.8)
            -- Parse hex color for border tint
            local hexColor = rec.color or "ff888888"
            local cr = tonumber(hexColor:sub(3, 4), 16) / 255
            local cg = tonumber(hexColor:sub(5, 6), 16) / 255
            local cb = tonumber(hexColor:sub(7, 8), 16) / 255
            row:SetBackdropBorderColor(cr * 0.5, cg * 0.5, cb * 0.5, 0.6)

            -- Slot name with priority indicator
            local slotPri = ns.SLOT_PRIORITY[r.slotID] or 2
            local priStr = ""
            if slotPri >= 5 then priStr = "|cff00ff00!! |r"
            elseif slotPri >= 4 then priStr = "|cff88ff88! |r"
            end
            row.slotFs:SetText(priStr .. "|cffffffff" .. r.slotName .. "|r")

            -- Tag (colored recommendation label, right-aligned)
            row.tagFs:SetText("|c" .. hexColor .. rec.label .. "|r")

            -- Reason text
            row.reasonFs:SetWidth(w - 20)
            if r.reason and r.reason ~= "" then
                row.reasonFs:SetText(r.reason)
                row.reasonFs:Show()
                local reasonH = row.reasonFs:GetStringHeight()
                row:SetHeight(26 + reasonH + 6)
                yOffset = yOffset + 26 + reasonH + 6 + 4
            else
                row.reasonFs:Hide()
                row:SetHeight(30)
                yOffset = yOffset + 34
            end

            table.insert(ns.SuggestEntries, row)
        end
    else
        -- ── Vendor mode: compact text list (original style) ──
        local lastLabel = nil
        for _, r in ipairs(sorted) do
            local rec = r.recommendation

            if rec.label ~= lastLabel then
                if lastLabel then yOffset = yOffset + 4 end
                local sectionHeader = AcquireFontString("GameFontNormal")
                sectionHeader:SetPoint("TOPLEFT", 0, -yOffset)
                sectionHeader:SetWidth(w)
                sectionHeader:SetJustifyH("LEFT")
                sectionHeader:SetText("|c" .. rec.color .. rec.label .. "|r")
                table.insert(ns.SuggestEntries, sectionHeader)
                yOffset = yOffset + sectionHeader:GetStringHeight() + 3
                lastLabel = rec.label
            end

            local slotPri = ns.SLOT_PRIORITY[r.slotID] or 2
            local priStr = ""
            if slotPri >= 5 then priStr = "|cff00ff00[!!!]|r "
            elseif slotPri >= 4 then priStr = "|cff88ff88[!!]|r "
            elseif slotPri >= 3 then priStr = "|cffffff88[!]|r "
            end

            local header = AcquireFontString()
            header:SetPoint("TOPLEFT", 4, -yOffset)
            header:SetWidth(w - 4)
            header:SetJustifyH("LEFT")
            header:SetText(priStr .. "|cffffffff" .. r.slotName .. "|r")
            table.insert(ns.SuggestEntries, header)
            yOffset = yOffset + header:GetStringHeight() + 1

            if r.reason and r.reason ~= "" then
                local reason = AcquireFontString()
                reason:SetPoint("TOPLEFT", 12, -yOffset)
                reason:SetWidth(w - 12)
                reason:SetJustifyH("LEFT")
                reason:SetWordWrap(true)
                reason:SetTextColor(0.6, 0.6, 0.6)
                reason:SetText(r.reason)
                table.insert(ns.SuggestEntries, reason)
                yOffset = yOffset + reason:GetStringHeight() + 4
            end
        end
    end

    if #sorted == 0 then
        local noItems = AcquireFontString()
        noItems:SetPoint("TOPLEFT", 0, 0)
        noItems:SetTextColor(0.5, 0.5, 0.5)
        noItems:SetText("No upgradeable items found.")
        table.insert(ns.SuggestEntries, noItems)
        yOffset = 20
    end

    suggestContent:SetHeight(math.max(yOffset, 1))
end

------------------------------------------------------------
-- Equipment Slot Buttons
------------------------------------------------------------
ns.SlotButtons = {}

local function CreateSlotButton(parent, slotInfo)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(SLOT_SIZE, SLOT_SIZE)
    btn:SetPoint(slotInfo.anchor, parent, slotInfo.anchor, slotInfo.x, slotInfo.y)

    -- Background
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.1, 0.1, 0.1, 1)

    -- Icon
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 1, -1)
    btn.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Border: 4 thin edge textures
    local borderThickness = 2
    btn.borderTop = btn:CreateTexture(nil, "OVERLAY")
    btn.borderTop:SetHeight(borderThickness)
    btn.borderTop:SetPoint("TOPLEFT", -1, 1)
    btn.borderTop:SetPoint("TOPRIGHT", 1, 1)

    btn.borderBottom = btn:CreateTexture(nil, "OVERLAY")
    btn.borderBottom:SetHeight(borderThickness)
    btn.borderBottom:SetPoint("BOTTOMLEFT", -1, -1)
    btn.borderBottom:SetPoint("BOTTOMRIGHT", 1, -1)

    btn.borderLeft = btn:CreateTexture(nil, "OVERLAY")
    btn.borderLeft:SetWidth(borderThickness)
    btn.borderLeft:SetPoint("TOPLEFT", -1, 1)
    btn.borderLeft:SetPoint("BOTTOMLEFT", -1, -1)

    btn.borderRight = btn:CreateTexture(nil, "OVERLAY")
    btn.borderRight:SetWidth(borderThickness)
    btn.borderRight:SetPoint("TOPRIGHT", 1, 1)
    btn.borderRight:SetPoint("BOTTOMRIGHT", 1, -1)

    function btn:SetBorderColor(r, g, b, a)
        self.borderTop:SetColorTexture(r, g, b, a)
        self.borderBottom:SetColorTexture(r, g, b, a)
        self.borderLeft:SetColorTexture(r, g, b, a)
        self.borderRight:SetColorTexture(r, g, b, a)
    end
    btn:SetBorderColor(0.5, 0.5, 0.5, 0.8)

    -- Upgrade glow (action bar proc style)
    btn.glowFrame = CreateFrame("Frame", nil, btn)
    btn.glowFrame:SetPoint("TOPLEFT", -8, 8)
    btn.glowFrame:SetPoint("BOTTOMRIGHT", 8, -8)
    btn.glowFrame:SetFrameLevel(btn:GetFrameLevel() - 1)
    btn.glowFrame:Hide()

    btn.glowFrame.ants = btn.glowFrame:CreateTexture(nil, "ARTWORK")
    btn.glowFrame.ants:SetAllPoints()
    btn.glowFrame.ants:SetAtlas("ActionBarSpellHighlightBorder")
    btn.glowFrame.ants:SetVertexColor(1.0, 0.85, 0.0, 0.9)

    btn.glowFrame.animGroup = btn.glowFrame.ants:CreateAnimationGroup()
    btn.glowFrame.animGroup:SetLooping("BOUNCE")
    local fade = btn.glowFrame.animGroup:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.5)
    fade:SetToAlpha(1.0)
    fade:SetDuration(0.6)
    fade:SetSmoothing("IN_OUT")

    -- Upgrade arrow indicator
    btn.upgradeIcon = btn:CreateTexture(nil, "OVERLAY", nil, 7)
    btn.upgradeIcon:SetSize(18, 18)
    btn.upgradeIcon:SetPoint("TOPRIGHT", 4, 4)
    btn.upgradeIcon:SetAtlas("bags-greenarrow")
    btn.upgradeIcon:Hide()

    -- Slot name label (next to icon)
    btn.nameLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.nameLabel:SetTextColor(0.8, 0.8, 0.8)
    btn.nameLabel:SetWidth(LABEL_MAX_WIDTH)
    btn.nameLabel:SetWordWrap(false)

    -- Item level text (below slot name)
    btn.ilvlText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.ilvlText:SetTextColor(1, 1, 1)
    btn.ilvlText:SetWidth(LABEL_MAX_WIDTH)
    btn.ilvlText:SetWordWrap(false)

    -- Status label (upgrade recommendation)
    btn.statusLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.statusLabel:SetWidth(LABEL_MAX_WIDTH)
    btn.statusLabel:SetWordWrap(false)

    if slotInfo.anchor == "TOPLEFT" then
        btn.nameLabel:SetJustifyH("LEFT")
        btn.ilvlText:SetJustifyH("LEFT")
        btn.statusLabel:SetJustifyH("LEFT")
        btn.nameLabel:SetPoint("TOPLEFT", btn, "TOPRIGHT", 6, 0)
        btn.ilvlText:SetPoint("TOPLEFT", btn.nameLabel, "BOTTOMLEFT", 0, -1)
        btn.statusLabel:SetPoint("TOPLEFT", btn.ilvlText, "BOTTOMLEFT", 0, -1)
    elseif slotInfo.anchor == "TOPRIGHT" then
        btn.nameLabel:SetJustifyH("RIGHT")
        btn.ilvlText:SetJustifyH("RIGHT")
        btn.statusLabel:SetJustifyH("RIGHT")
        btn.nameLabel:SetPoint("TOPRIGHT", btn, "TOPLEFT", -6, 0)
        btn.ilvlText:SetPoint("TOPRIGHT", btn.nameLabel, "BOTTOMRIGHT", 0, -1)
        btn.statusLabel:SetPoint("TOPRIGHT", btn.ilvlText, "BOTTOMRIGHT", 0, -1)
    elseif slotInfo.anchor == "BOTTOMLEFT" then
        btn.nameLabel:SetJustifyH("LEFT")
        btn.ilvlText:SetJustifyH("LEFT")
        btn.statusLabel:SetJustifyH("LEFT")
        btn.nameLabel:SetPoint("TOPLEFT", btn, "TOPRIGHT", 6, 0)
        btn.ilvlText:SetPoint("TOPLEFT", btn.nameLabel, "BOTTOMLEFT", 0, -1)
        btn.statusLabel:SetPoint("TOPLEFT", btn.ilvlText, "BOTTOMLEFT", 0, -1)
    elseif slotInfo.anchor == "BOTTOMRIGHT" then
        btn.nameLabel:SetJustifyH("RIGHT")
        btn.ilvlText:SetJustifyH("RIGHT")
        btn.statusLabel:SetJustifyH("RIGHT")
        btn.nameLabel:SetPoint("TOPRIGHT", btn, "TOPLEFT", -6, 0)
        btn.ilvlText:SetPoint("TOPRIGHT", btn.nameLabel, "BOTTOMRIGHT", 0, -1)
        btn.statusLabel:SetPoint("TOPRIGHT", btn.ilvlText, "BOTTOMRIGHT", 0, -1)
    end

    -- Tooltip on hover (show equipped item, or compare cursor item)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.itemLink then
            GameTooltip:SetInventoryItem("player", self.slotID)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)

    -- Schedule a full UI refresh after equipping. Coalesce rapid-fire
    -- clicks (e.g. a user cycling through upgrade suggestions) so a
    -- single 0.2s tick services the whole burst instead of firing one
    -- redundant refresh per click.
    local refreshPending = false
    local function ScheduleRefresh()
        if refreshPending then return end
        refreshPending = true
        C_Timer.After(0.2, function()
            refreshPending = false
            if ns.MainFrame and ns.MainFrame:IsShown() then
                ns:InvalidateScanCache()
                ns:RefreshCrests()
                ns:RefreshAllSlots()
            end
        end)
    end

    -- Click: pick up / equip / send to vendor
    btn:SetScript("OnClick", function(self, button)
        if not self.slotID then return end

        if IsModifiedClick("CHATLINK") and self.itemLink then
            ChatEdit_InsertLink(self.itemLink)
            return
        end

        if button == "RightButton" and ns.upgradeVendorOpen then
            ns:SendItemToUpgrade(self.slotID)
            return
        end

        if InCombatLockdown() then return end

        if CursorHasItem() then
            EquipCursorItem(self.slotID)
            ScheduleRefresh()
        elseif button == "LeftButton" then
            if ns.upgradeVendorOpen then
                ns:SendItemToUpgrade(self.slotID)
            else
                PickupInventoryItem(self.slotID)
            end
        end
    end)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    -- Drag: pick up equipped item
    btn:SetScript("OnDragStart", function(self)
        if self.slotID and not InCombatLockdown() then
            PickupInventoryItem(self.slotID)
        end
    end)

    -- Drop: equip cursor item into this slot
    btn:SetScript("OnReceiveDrag", function(self)
        if self.slotID and CursorHasItem() and not InCombatLockdown() then
            EquipCursorItem(self.slotID)
            ScheduleRefresh()
        end
    end)

    -- Highlight on hover
    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetAllPoints(btn.icon)
    btn.highlight:SetColorTexture(1, 1, 1, 0.15)

    btn.slotID = slotInfo.slot
    btn.slotName = slotInfo.name
    return btn
end

for _, slotInfo in ipairs(ns.SLOT_IDS) do
    local btn = CreateSlotButton(equipPanel, slotInfo)
    ns.SlotButtons[slotInfo.slot] = btn
end

------------------------------------------------------------
-- Refresh equipped gear display
------------------------------------------------------------
-- Track name colors for display
local TRACK_COLORS = {
    Adventurer = "ff1eff00",
    Veteran    = "ff0070dd",
    Champion   = "ffa335ee",
    Hero       = "ffff8000",
    Myth       = "ffff0000",
}

function ns:RefreshAllSlots()
    for _, slotInfo in ipairs(ns.SLOT_IDS) do
        local btn = ns.SlotButtons[slotInfo.slot]
        local info = ns:GetSlotInfo(slotInfo.slot)

        if info then
            btn.icon:SetTexture(info.icon)
            btn.itemLink = info.link

            -- Color border by quality
            local c = QUALITY_COLORS[info.quality] or QUALITY_COLORS[1]
            btn:SetBorderColor(c[1], c[2], c[3], 0.9)

            -- Track comes from CanUpgradeItem only — never guessed from
            -- item level. Guessing mislabels last season's gear, whose
            -- item levels fall inside this season's bands (a locked S1
            -- 272 piece read as "Adventurer 3/6").
            local canUpgrade, upgradeInfo, why = ns:CanUpgradeItem(slotInfo.slot)
            local track = upgradeInfo and upgradeInfo.track
            local trackColor = track and TRACK_COLORS[track] or "ffffffff"

            -- Slot name with track label: "Head — Champion 3/5"
            if upgradeInfo and track then
                btn.nameLabel:SetText(slotInfo.name .. " — |c" .. trackColor .. track .. " " .. upgradeInfo.currUpgrade .. "/" .. upgradeInfo.maxUpgrade .. "|r")
            elseif why == "mismatch" then
                -- Tooltip claims a track, but the item level does not match
                -- that rank — so it is not on this season's track.
                btn.nameLabel:SetText(slotInfo.name .. " — |cffcc8844off-track|r")
            else
                -- No upgrade track: last season's gear, or a drop that
                -- never had one. Say so rather than leaving the row bare,
                -- so it reads as "replace this", not "data missing".
                btn.nameLabel:SetText(slotInfo.name .. " — |cff888888no track|r")
            end

            -- Get recommendation
            local rec, reason = ns:GetRecommendation(slotInfo.slot)

            if canUpgrade and upgradeInfo then
                -- Show ilvl range with free-upgrade info
                local ilvlStr = info.ilvl .. " -> " .. upgradeInfo.maxIlvl

                -- Check for free upgrades via high-water mark
                local freeIlvl = ns:GetFreeUpgradeIlvl(slotInfo.slot)
                if freeIlvl > info.ilvl then
                    local freeTarget = math.min(freeIlvl, upgradeInfo.maxIlvl)
                    if freeTarget > info.ilvl then
                        ilvlStr = ilvlStr .. " |cff00ff00(free to " .. freeTarget .. ")|r"
                    end
                end

                -- Check for track overlap (first ranks covered by cheaper crests)
                local overlap = ns.TRACK_FREE_RANKS[track]
                if overlap and upgradeInfo.currUpgrade < overlap.count then
                    local ranksFromPrev = overlap.count - upgradeInfo.currUpgrade
                    if ranksFromPrev > 0 then
                        ilvlStr = ilvlStr .. " |cffaaaaaa(" .. ranksFromPrev .. " free via " .. overlap.prevTrack .. ")|r"
                    end
                end

                btn.ilvlText:SetText(ilvlStr)
                btn.upgradeIcon:Show()
                btn.statusLabel:SetText("|c" .. rec.color .. rec.label .. "|r")
                btn.statusLabel:Show()

                -- Glow for upgradeable items
                btn.glowFrame:Show()
                if not btn.glowFrame.animGroup:IsPlaying() then
                    btn.glowFrame.animGroup:Play()
                end

                -- Color glow based on recommendation
                if rec == ns.RECOMMEND.FREE_UPGRADE then
                    btn.glowFrame.ants:SetVertexColor(0.0, 1.0, 1.0, 1.0)
                elseif rec == ns.RECOMMEND.UPGRADE_NOW then
                    btn.glowFrame.ants:SetVertexColor(0.3, 1.0, 0.3, 1.0)
                elseif rec == ns.RECOMMEND.BAD_INVESTMENT or rec == ns.RECOMMEND.WASTED_CREST then
                    btn.glowFrame.ants:SetVertexColor(1.0, 0.2, 0.2, 0.8)
                elseif rec == ns.RECOMMEND.HOLD_CRESTS then
                    btn.glowFrame.ants:SetVertexColor(1.0, 0.6, 0.0, 0.9)
                else
                    btn.glowFrame.ants:SetVertexColor(1.0, 0.85, 0.0, 0.9)
                end
            elseif upgradeInfo and not canUpgrade then
                btn.ilvlText:SetText(tostring(info.ilvl))
                btn.upgradeIcon:Hide()
                btn.statusLabel:SetText("|c" .. ns.RECOMMEND.MAXED.color .. "Max rank|r")
                btn.statusLabel:Show()
                btn.glowFrame:Hide()
                btn.glowFrame.animGroup:Stop()
            else
                btn.ilvlText:SetText(tostring(info.ilvl))
                btn.upgradeIcon:Hide()
                btn.statusLabel:SetText("")
                btn.statusLabel:Hide()
                btn.glowFrame:Hide()
                btn.glowFrame.animGroup:Stop()
            end
        else
            btn.icon:SetTexture(nil)
            btn.ilvlText:SetText("")
            btn.upgradeIcon:Hide()
            btn.statusLabel:SetText("")
            btn.statusLabel:Hide()
            btn.itemLink = nil
            btn.nameLabel:SetText("|cff555555" .. slotInfo.name .. "|r")
            btn:SetBorderColor(0.2, 0.2, 0.2, 0.5)
            btn.glowFrame:Hide()
            btn.glowFrame.animGroup:Stop()
        end
    end

    ns:RefreshSuggestions()
end
