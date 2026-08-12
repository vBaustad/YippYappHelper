local _, ns = ...

------------------------------------------------------------
-- Consumables panel with tabs: Enchants | Gems | Consumables
-- Filter bar: class dropdown + spec buttons
------------------------------------------------------------
local PANEL_WIDTH  = 460
local PANEL_HEIGHT = 540
local PAD = 14
local ROW_H = 24
local ICON_SIZE = 20
local FILTER_H = 34

------------------------------------------------------------
-- Spec key helper
------------------------------------------------------------
local SPEC_CONSUMABLE_MAP = {
    [259] = "ROGUE_ASSASSINATION", [260] = "ROGUE_OUTLAW", [261] = "ROGUE_SUBTLETY",
    [250] = "DEATHKNIGHT_BLOOD", [251] = "DEATHKNIGHT_FROST", [252] = "DEATHKNIGHT_UNHOLY",
    [577] = "DEMONHUNTER_HAVOC", [581] = "DEMONHUNTER_VENGEANCE", [1480] = "DEMONHUNTER_DEVOURER",
    [102] = "DRUID_BALANCE", [103] = "DRUID_FERAL", [104] = "DRUID_GUARDIAN", [105] = "DRUID_RESTORATION",
    [1467] = "EVOKER_DEVASTATION", [1468] = "EVOKER_PRESERVATION", [1473] = "EVOKER_AUGMENTATION",
    [253] = "HUNTER_BEASTMASTERY", [254] = "HUNTER_MARKSMANSHIP", [255] = "HUNTER_SURVIVAL",
    [62] = "MAGE_ARCANE", [63] = "MAGE_FIRE", [64] = "MAGE_FROST",
    [268] = "MONK_BREWMASTER", [269] = "MONK_WINDWALKER", [270] = "MONK_MISTWEAVER",
    [65] = "PALADIN_HOLY", [66] = "PALADIN_PROTECTION", [70] = "PALADIN_RETRIBUTION",
    [256] = "PRIEST_DISCIPLINE", [257] = "PRIEST_HOLY", [258] = "PRIEST_SHADOW",
    [262] = "SHAMAN_ELEMENTAL", [263] = "SHAMAN_ENHANCEMENT", [264] = "SHAMAN_RESTORATION",
    [265] = "WARLOCK_AFFLICTION", [266] = "WARLOCK_DEMONOLOGY", [267] = "WARLOCK_DESTRUCTION",
    [71] = "WARRIOR_ARMS", [72] = "WARRIOR_FURY", [73] = "WARRIOR_PROTECTION",
}

-- All classes with their spec IDs (ordered)
local CLASS_SPECS = {
    { classFile = "DEATHKNIGHT", name = "Death Knight", specs = { 250, 251, 252 } },
    { classFile = "DEMONHUNTER", name = "Demon Hunter", specs = { 577, 581, 1480 } },
    { classFile = "DRUID",       name = "Druid",        specs = { 102, 103, 104, 105 } },
    { classFile = "EVOKER",      name = "Evoker",       specs = { 1467, 1468, 1473 } },
    { classFile = "HUNTER",      name = "Hunter",       specs = { 253, 254, 255 } },
    { classFile = "MAGE",        name = "Mage",         specs = { 62, 63, 64 } },
    { classFile = "MONK",        name = "Monk",         specs = { 268, 269, 270 } },
    { classFile = "PALADIN",     name = "Paladin",      specs = { 65, 66, 70 } },
    { classFile = "PRIEST",      name = "Priest",       specs = { 256, 257, 258 } },
    { classFile = "ROGUE",       name = "Rogue",        specs = { 259, 260, 261 } },
    { classFile = "SHAMAN",      name = "Shaman",       specs = { 262, 263, 264 } },
    { classFile = "WARLOCK",     name = "Warlock",      specs = { 265, 266, 267 } },
    { classFile = "WARRIOR",     name = "Warrior",      specs = { 71, 72, 73 } },
}

-- Spec names (hardcoded — API can be unreliable across classes)
local SPEC_NAMES = {
    [250] = "Blood", [251] = "Frost", [252] = "Unholy",
    [577] = "Havoc", [581] = "Vengeance", [1480] = "Devourer",
    [102] = "Balance", [103] = "Feral", [104] = "Guardian", [105] = "Restoration",
    [1467] = "Devastation", [1468] = "Preservation", [1473] = "Augmentation",
    [253] = "Beast Mastery", [254] = "Marksmanship", [255] = "Survival",
    [62] = "Arcane", [63] = "Fire", [64] = "Frost",
    [268] = "Brewmaster", [269] = "Windwalker", [270] = "Mistweaver",
    [65] = "Holy", [66] = "Protection", [70] = "Retribution",
    [256] = "Discipline", [257] = "Holy", [258] = "Shadow",
    [259] = "Assassination", [260] = "Outlaw", [261] = "Subtlety",
    [262] = "Elemental", [263] = "Enhancement", [264] = "Restoration",
    [265] = "Affliction", [266] = "Demonology", [267] = "Destruction",
    [71] = "Arms", [72] = "Fury", [73] = "Protection",
}

local specIconCache = {}

local function GetSpecInfo(specID)
    -- Try to get icon from API if not cached
    if not specIconCache[specID] then
        local _, _, _, icon = GetSpecializationInfoByID(specID)
        if icon then specIconCache[specID] = icon end
    end
    return SPEC_NAMES[specID], specIconCache[specID]
end

-- Selection state (reset each time the panel is shown)
local selectedClassFile = nil
local selectedSpecID = nil

local function GetPlayerClassAndSpec()
    local _, classFile = UnitClass("player")
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex) or nil
    return classFile, specID
end

local function GetConsumableKey()
    return selectedSpecID and SPEC_CONSUMABLE_MAP[selectedSpecID]
end

------------------------------------------------------------
-- Main frame
------------------------------------------------------------
local frame = CreateFrame("Frame", "YippYappConsumablesFrame", UIParent, "BackdropTemplate")
frame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
frame:SetPoint("CENTER", 200, 0)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetClampedToScreen(true)
frame:SetFrameStrata("HIGH")
frame:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
})
frame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
ns.SmoothFrame(frame)
frame:Hide()
ns.ConsumablesFrame = frame

frame:SetScript("OnShow", function()
    -- Always reset to player's class/spec on open
    selectedClassFile, selectedSpecID = GetPlayerClassAndSpec()
    if frame.inAppMode then return end
    tinsert(UISpecialFrames, "YippYappConsumablesFrame")
end)
frame:SetScript("OnHide", function()
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "YippYappConsumablesFrame" then
            table.remove(UISpecialFrames, i)
            break
        end
    end
end)

local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -2, -2)

local titleIcon, titleFs = ns.MakeWindowHeader(frame, "|cffff00ffConsumables|r", nil, PAD)

local specFs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
specFs:SetPoint("LEFT", titleFs, "RIGHT", 10, 0)
specFs:SetTextColor(unpack(ns.COLORS.TEXT_TERTIARY))

------------------------------------------------------------
-- App mode
------------------------------------------------------------
local HEADER_H = 34
local filterBar  -- forward declare; created below

function ns:SetConsumablesAppMode(enabled, contentWidth, contentHeight)
    if enabled then
        frame:SetBackdrop(nil)
        closeBtn:Hide()
        titleFs:Hide()
        specFs:Hide()
        frame:SetMovable(false)
        frame:EnableMouse(false)
        local dw, dh = ns:GetAppFrameSize()
        frame:SetSize(contentWidth or dw, contentHeight or (dh - 34))
        -- Match the Loot Browser header: no card border, flush to inner
        -- panel sides, with just a thin bottom divider.
        filterBar:ClearAllPoints()
        filterBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -10)
        filterBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -10)
        filterBar:SetBackdrop(nil)
        if not filterBar._divider then
            local div = filterBar:CreateTexture(nil, "OVERLAY")
            div:SetColorTexture(0.35, 0.35, 0.35, 0.8)
            div:SetHeight(1)
            div:SetPoint("BOTTOMLEFT", filterBar, "BOTTOMLEFT", 0, 0)
            div:SetPoint("BOTTOMRIGHT", filterBar, "BOTTOMRIGHT", 0, 0)
            filterBar._divider = div
        end
        filterBar._divider:Show()
    else
        frame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets   = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
        frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        closeBtn:Show()
        titleFs:Show()
        specFs:Show()
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
        -- Restore standalone filter bar (card with border) below title
        filterBar:ClearAllPoints()
        filterBar:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -HEADER_H)
        filterBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -HEADER_H)
        filterBar:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets   = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        filterBar:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
        filterBar:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
        if filterBar._divider then filterBar._divider:Hide() end
    end
end

------------------------------------------------------------
-- Filter bar: class dropdown + spec buttons
------------------------------------------------------------
filterBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
filterBar:SetHeight(FILTER_H)
filterBar:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -34)
filterBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -34)
filterBar:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets   = { left = 2, right = 2, top = 2, bottom = 2 },
})
filterBar:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
filterBar:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
ns.SmoothFrame(filterBar)

-- Class label
local classLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
classLabel:SetPoint("LEFT", 10, 0)
classLabel:SetTextColor(unpack(ns.COLORS.TEXT_TERTIARY))
classLabel:SetText("Class:")
ns.ApplyTextShadow(classLabel)

-- Class dropdown button
local classBtn = CreateFrame("Button", nil, filterBar, "BackdropTemplate")
classBtn:SetSize(140, 24)
classBtn:SetPoint("LEFT", classLabel, "RIGHT", 6, 0)
classBtn:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 8,
    insets   = { left = 2, right = 2, top = 2, bottom = 2 },
})
classBtn:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
classBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
ns.SmoothFrame(classBtn)
ns.AddGlowHighlight(classBtn, 0.06)

local classBtnName = classBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
classBtnName:SetPoint("LEFT", 8, 0)
ns.ApplyTextShadow(classBtnName)

local classBtnArrow = classBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
classBtnArrow:SetPoint("RIGHT", -4, 0)
classBtnArrow:SetTextColor(unpack(ns.COLORS.TEXT_TERTIARY))
classBtnArrow:SetText("v")

classBtn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.6) end)
classBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5) end)

-- Class dropdown popup
local classDropdown = CreateFrame("Frame", "YippYappConsumClassDropdown", UIParent, "BackdropTemplate")
classDropdown:SetSize(160, 10)
classDropdown:SetFrameStrata("DIALOG")
classDropdown:SetClampedToScreen(true)
classDropdown:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 },
})
classDropdown:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
classDropdown:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
ns.SmoothFrame(classDropdown)
classDropdown:EnableMouse(true)
classDropdown:Hide()

classDropdown:SetScript("OnShow", function()
    tinsert(UISpecialFrames, "YippYappConsumClassDropdown")
end)
classDropdown:SetScript("OnHide", function()
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "YippYappConsumClassDropdown" then
            table.remove(UISpecialFrames, i)
            break
        end
    end
end)

-- Build class rows
local classRows = {}
local ddY = 6
for _, ci in ipairs(CLASS_SPECS) do
    local row = CreateFrame("Button", nil, classDropdown)
    row:SetSize(148, 22)
    row:SetPoint("TOPLEFT", 6, -ddY)

    local rowHl = row:CreateTexture(nil, "HIGHLIGHT")
    rowHl:SetAllPoints()
    rowHl:SetColorTexture(1, 1, 1, 0.05)
    rowHl:SetBlendMode("ADD")

    local rowName = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rowName:SetPoint("LEFT", 8, 0)
    ns.ApplyTextShadow(rowName)

    local cc = RAID_CLASS_COLORS[ci.classFile]
    if cc then
        rowName:SetText(cc:WrapTextInColorCode(ci.name))
    else
        rowName:SetText(ci.name)
    end

    local rowCheck = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rowCheck:SetPoint("RIGHT", -4, 0)
    row._check = rowCheck
    row._classFile = ci.classFile

    row:SetScript("OnClick", function(self)
        classDropdown:Hide()
        selectedClassFile = self._classFile
        -- Select first spec of new class
        for _, cinfo in ipairs(CLASS_SPECS) do
            if cinfo.classFile == selectedClassFile then
                selectedSpecID = cinfo.specs[1]
                break
            end
        end
        ns:RefreshConsumablesFilter()
        ns:RefreshConsumables()
    end)

    table.insert(classRows, row)
    ddY = ddY + 22
end
classDropdown:SetHeight(ddY + 6)

classBtn:SetScript("OnClick", function(self)
    if classDropdown:IsShown() then
        classDropdown:Hide()
    else
        -- Update checkmarks
        for _, row in ipairs(classRows) do
            if row._classFile == selectedClassFile then
                row._check:SetText("|cff00ccff>|r")
            else
                row._check:SetText("")
            end
        end
        classDropdown:ClearAllPoints()
        classDropdown:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        classDropdown:Show()
    end
end)

-- Divider between class dropdown and spec buttons
local divTex = filterBar:CreateTexture(nil, "ARTWORK")
divTex:SetSize(1, 20)
divTex:SetPoint("LEFT", classBtn, "RIGHT", 12, 0)
divTex:SetColorTexture(0.25, 0.25, 0.25, 0.5)

-- Spec label
local specLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
specLabel:SetPoint("LEFT", divTex, "RIGHT", 10, 0)
specLabel:SetTextColor(unpack(ns.COLORS.TEXT_TERTIARY))
specLabel:SetText("Spec:")
ns.ApplyTextShadow(specLabel)

-- Spec buttons (up to 4, created once, updated dynamically)
local specButtons = {}
for i = 1, 4 do
    local btn = CreateFrame("Button", nil, filterBar, "BackdropTemplate")
    btn:SetHeight(24)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    btn:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
    ns.SmoothFrame(btn)
    ns.AddGlowHighlight(btn, 0.06)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", 4, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn._icon = icon

    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    ns.ApplyTextShadow(lbl)
    btn._label = lbl

    btn:Hide()
    btn:SetScript("OnClick", function(self)
        if self._specID then
            selectedSpecID = self._specID
            ns:RefreshConsumablesFilter()
            ns:RefreshConsumables()
        end
    end)

    specButtons[i] = btn
end

-- Update filter bar display
function ns:RefreshConsumablesFilter()
    -- Class button text
    local cc = selectedClassFile and RAID_CLASS_COLORS[selectedClassFile]
    local className = ""
    for _, ci in ipairs(CLASS_SPECS) do
        if ci.classFile == selectedClassFile then className = ci.name; break end
    end
    if cc then
        classBtnName:SetText(cc:WrapTextInColorCode(className))
    else
        classBtnName:SetText(className)
    end

    -- Spec buttons
    local specs = {}
    for _, ci in ipairs(CLASS_SPECS) do
        if ci.classFile == selectedClassFile then specs = ci.specs; break end
    end

    local prevBtn = specLabel
    for i = 1, 4 do
        local btn = specButtons[i]
        if i <= #specs then
            local specID = specs[i]
            local specName, specIcon = GetSpecInfo(specID)
            btn._specID = specID
            btn._icon:SetTexture(specIcon or 134400)
            btn._label:SetText(specName or ("Spec " .. i))

            -- Size to fit
            local textW = btn._label:GetStringWidth()
            btn:SetWidth(textW + 30)

            btn:ClearAllPoints()
            if i == 1 then
                btn:SetPoint("LEFT", specLabel, "RIGHT", 6, 0)
            else
                btn:SetPoint("LEFT", specButtons[i - 1], "RIGHT", 4, 0)
            end

            -- Active styling
            if specID == selectedSpecID then
                btn:SetBackdropBorderColor(0.0, 0.8, 1.0, 0.8)
                btn._label:SetTextColor(0.0, 0.8, 1.0)
            else
                btn:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
                btn._label:SetTextColor(unpack(ns.COLORS.TEXT_SECONDARY))
            end

            btn:Show()
        else
            btn:Hide()
        end
    end

    -- Update header spec label
    local specName = selectedSpecID and GetSpecInfo(selectedSpecID) or ""
    specFs:SetText(specName .. " " .. className)
end

------------------------------------------------------------
-- Tab system
------------------------------------------------------------
local currentTab = "enchants"

local TAB_DEFS = {
    { id = "enchants",     label = "Enchants",     color = { 0.0, 1.0, 0.3 } },
    { id = "gems",         label = "Gems",         color = { 0.64, 0.21, 0.93 } },
    { id = "consumables",  label = "Consumables",  color = { 1.0, 0.53, 0.0 } },
}

local tabButtons = {}
local containers = {}
-- The scroll frame that owns each container. Shown/hidden with the tab;
-- the container itself is the scroll child and is always "visible".
local scrolls = {}

for i, def in ipairs(TAB_DEFS) do
    local btn = ns.CreateUnderlineTab(frame, def.label, def.color)
    btn:SetSize(110, 24)
    -- Align the tab row with the filter bar and the content rows below.
    -- The old -PAD + 8 offset pulled the first tab 6px left of everything
    -- else, so "Enchants" hung off the panel edge.
    btn:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", (i - 1) * 114, -2)
    tabButtons[def.id] = btn

    -- Scrolled, because the guide text is scraped and its length is not
    -- ours to control. These were plain frames pinned to the panel edge,
    -- so a long guide simply drew past the bottom and over whatever was
    -- behind it.
    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", -PAD, -28)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 8)
    scroll:SetScript("OnMouseWheel", function(sf, delta)
        local v = sf:GetVerticalScroll() - delta * 30
        sf:SetVerticalScroll(math.max(0, math.min(v, sf:GetVerticalScrollRange())))
    end)
    scroll:Hide()

    local container = CreateFrame("Frame", nil, scroll)
    container:SetSize(math.max(frame:GetWidth() - 40, 400), 400)
    scroll:SetScrollChild(container)

    scrolls[def.id] = scroll
    containers[def.id] = container
end

local function UpdateTabs()
    for id, btn in pairs(tabButtons) do
        if id == currentTab then
            ns.SetTabActive(btn)
            scrolls[id]:Show()
        else
            ns.SetTabInactive(btn)
            scrolls[id]:Hide()
        end
    end
end

for id, btn in pairs(tabButtons) do
    btn:SetScript("OnClick", function()
        currentTab = id
        UpdateTabs()
    end)
end

UpdateTabs()

------------------------------------------------------------
-- Object pools (all parented to scrollContent)
------------------------------------------------------------
local fsPool, fsPoolIdx = {}, 0
local iconPool, iconPoolIdx = {}, 0
local bgPool, bgPoolIdx = {}, 0
local btnPool, btnPoolIdx = {}, 0

local function AcquireFs(parent, font)
    parent = parent or frame
    fsPoolIdx = fsPoolIdx + 1
    local fs = fsPool[fsPoolIdx]
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
        fsPool[fsPoolIdx] = fs
    else
        fs:SetParent(parent)
        fs:SetFontObject(font or "GameFontNormal")
        fs:SetTextColor(1, 1, 1)
        fs:SetAlpha(1)
    end
    fs:ClearAllPoints()
    fs:SetWordWrap(false)
    fs:SetWidth(0)
    fs:SetJustifyH("LEFT")
    fs:Show()
    return fs
end

local function AcquireIcon(parent)
    parent = parent or frame
    iconPoolIdx = iconPoolIdx + 1
    local tex = iconPool[iconPoolIdx]
    if not tex then
        tex = parent:CreateTexture(nil, "ARTWORK")
        iconPool[iconPoolIdx] = tex
    else
        tex:SetParent(parent)
    end
    tex:ClearAllPoints()
    tex:SetTexture(nil)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tex:SetVertexColor(1, 1, 1, 1)
    tex:SetDesaturated(false)
    tex:Show()
    return tex
end

local function AcquireBg(parent)
    parent = parent or frame
    bgPoolIdx = bgPoolIdx + 1
    local tex = bgPool[bgPoolIdx]
    if not tex then
        tex = parent:CreateTexture(nil, "BACKGROUND")
        bgPool[bgPoolIdx] = tex
    else
        tex:SetParent(parent)
    end
    tex:ClearAllPoints()
    tex:Show()
    return tex
end

local function AcquireHitBtn(parent)
    parent = parent or frame
    btnPoolIdx = btnPoolIdx + 1
    local btn = btnPool[btnPoolIdx]
    if not btn then
        btn = CreateFrame("Button", nil, parent)
        btn:RegisterForClicks("LeftButtonUp")
        btnPool[btnPoolIdx] = btn
    else
        btn:SetParent(parent)
    end
    btn:ClearAllPoints()
    btn:SetScript("OnEnter", nil)
    btn:SetScript("OnLeave", nil)
    btn:SetScript("OnClick", nil)
    btn:Show()
    return btn
end

local function ResetPools()
    for i = 1, fsPoolIdx do fsPool[i]:Hide() end
    fsPoolIdx = 0
    for i = 1, iconPoolIdx do iconPool[i]:Hide() end
    iconPoolIdx = 0
    for i = 1, bgPoolIdx do bgPool[i]:Hide() end
    bgPoolIdx = 0
    for i = 1, btnPoolIdx do btnPool[i]:Hide() end
    btnPoolIdx = 0
end

------------------------------------------------------------
-- Item link cache
------------------------------------------------------------
local itemLinkCache = {}
local itemIconCache = {}
local itemNameCache = {}
local pendingRefresh = false

local function CacheItem(itemID)
    if itemLinkCache[itemID] then return end
    local item = Item:CreateFromItemID(itemID)
    item:ContinueOnItemLoad(function()
        local name, link, _, _, _, _, _, _, _, icon = GetItemInfo(itemID)
        if link then itemLinkCache[itemID] = link end
        if icon then itemIconCache[itemID] = icon end
        if name then itemNameCache[itemID] = name end
        if frame:IsShown() and not pendingRefresh then
            pendingRefresh = true
            C_Timer.After(0.1, function()
                pendingRefresh = false
                if frame:IsShown() then
                    ns:RefreshConsumables()
                end
            end)
        end
    end)
end

local function GetItemLink(itemID)
    if not itemLinkCache[itemID] then CacheItem(itemID) end
    return itemLinkCache[itemID]
end
local function GetItemIcon(itemID)
    if not itemIconCache[itemID] then CacheItem(itemID) end
    return itemIconCache[itemID]
end
local function GetItemName(itemID)
    if not itemNameCache[itemID] then CacheItem(itemID) end
    return itemNameCache[itemID]
end

------------------------------------------------------------
-- Row drawing
------------------------------------------------------------
local LABEL_W = 120

local function DrawRow(parent, y, itemID, label)
    local icon = GetItemIcon(itemID)
    local link = GetItemLink(itemID)
    local name = GetItemName(itemID) or ("item:" .. itemID)
    local pw = parent:GetWidth()
    if pw < 10 then pw = frame:GetWidth() end

    local bg = AcquireBg(parent)
    bg:SetHeight(ROW_H)
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
    bg:SetPoint("RIGHT", parent, "RIGHT", -PAD, 0)
    bg:SetColorTexture(1, 1, 1, 0.02)

    local labelFs = AcquireFs(parent, "GameFontNormal")
    labelFs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, y - 3)
    labelFs:SetWidth(LABEL_W)
    labelFs:SetTextColor(0.65, 0.65, 0.65)
    labelFs:SetText(label)

    local itemX = PAD + LABEL_W + 12
    if icon then
        local tex = AcquireIcon(parent)
        tex:SetSize(ICON_SIZE, ICON_SIZE)
        tex:SetPoint("TOPLEFT", parent, "TOPLEFT", itemX, y - 2)
        tex:SetTexture(icon)
    end

    local nameFs = AcquireFs(parent, "GameFontNormal")
    nameFs:SetPoint("TOPLEFT", parent, "TOPLEFT", itemX + ICON_SIZE + 6, y - 3)
    nameFs:SetWidth(pw - itemX - ICON_SIZE - PAD - 10)
    if link then
        nameFs:SetText(link)
    else
        nameFs:SetText("|cffffffff" .. name .. "|r")
    end

    local itemLink = link or ("item:" .. itemID)
    local btn = AcquireHitBtn(parent)
    btn:SetSize(pw - PAD * 2, ROW_H)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
    btn:SetScript("OnEnter", function(self)
        -- ANCHOR_CURSOR, not ANCHOR_RIGHT. The hit area spans the whole
        -- row, so anchoring to the owner's right edge put the tooltip
        -- against the far side of the panel however close to the left
        -- the pointer actually was.
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(itemLink)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function()
        if IsModifiedClick("CHATLINK") then
            HandleModifiedItemClick(itemLink)
        end
    end)

    return y - ROW_H
end

local function DrawAltRow(parent, y, itemID)
    local icon = GetItemIcon(itemID)
    local link = GetItemLink(itemID)
    local name = GetItemName(itemID) or ("item:" .. itemID)
    local pw = parent:GetWidth()
    if pw < 10 then pw = frame:GetWidth() end

    local bg = AcquireBg(parent)
    bg:SetHeight(ROW_H)
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
    bg:SetPoint("RIGHT", parent, "RIGHT", -PAD, 0)
    bg:SetColorTexture(1, 1, 1, 0.015)

    local labelFs = AcquireFs(parent, "GameFontNormalSmall")
    labelFs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, y - 4)
    labelFs:SetWidth(LABEL_W)
    labelFs:SetTextColor(0.4, 0.4, 0.4)
    labelFs:SetText("or")

    local itemX = PAD + LABEL_W + 12
    if icon then
        local tex = AcquireIcon(parent)
        tex:SetSize(ICON_SIZE, ICON_SIZE)
        tex:SetPoint("TOPLEFT", parent, "TOPLEFT", itemX, y - 2)
        tex:SetTexture(icon)
    end

    local nameFs = AcquireFs(parent, "GameFontNormal")
    nameFs:SetPoint("TOPLEFT", parent, "TOPLEFT", itemX + ICON_SIZE + 6, y - 3)
    nameFs:SetWidth(pw - itemX - ICON_SIZE - PAD - 10)
    if link then
        nameFs:SetText(link)
    else
        nameFs:SetText("|cffffffff" .. name .. "|r")
    end

    local altLink = link or ("item:" .. itemID)
    local btn = AcquireHitBtn(parent)
    btn:SetSize(pw - PAD * 2, ROW_H)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
    btn:SetScript("OnEnter", function(self)
        -- ANCHOR_CURSOR, not ANCHOR_RIGHT. The hit area spans the whole
        -- row, so anchoring to the owner's right edge put the tooltip
        -- against the far side of the panel however close to the left
        -- the pointer actually was.
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(altLink)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function()
        if IsModifiedClick("CHATLINK") then
            HandleModifiedItemClick(altLink)
        end
    end)

    return y - ROW_H
end

------------------------------------------------------------
-- Staleness banner.
--
-- ConsumablesData.lua is scraped from Wowhead, and those guides are
-- rewritten some weeks into a new season. Showing last season's advice
-- silently would be worse than showing it with a warning, so each spec
-- records the season it was written for and we say so up front.
------------------------------------------------------------
local function DrawStaleBanner(parent, y, data)
    local target = ns.CONSUMABLES_TARGET_SEASON
    if not target or not data then return y end
    if data.season == target then return y end

    local pw = parent:GetWidth()
    if pw < 10 then pw = frame:GetWidth() end

    -- Kept to a single compact line: these containers do not scroll, so
    -- every pixel the banner adds pushes the last rows off the bottom.
    local bg = AcquireBg(parent)
    bg:SetHeight(20)
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y - 1)
    bg:SetPoint("RIGHT", parent, "RIGHT", -PAD, 0)
    bg:SetColorTexture(0.45, 0.30, 0.05, 0.35)

    local fs = AcquireFs(parent, "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 6, y - 6)
    fs:SetWidth(pw - PAD * 2 - 12)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:SetText(("|cffffcc00%s advice|r — %s guides are not published yet.")
        :format(data.season or "Earlier season", target))
    return y - 24
end

--- Match the scroll child to what was actually drawn into it.
---
--- Every Draw* function already returned the y it finished at and every
--- caller discarded it, so the child kept its placeholder height and the
--- scroll bar never knew there was anything to scroll.
---
--- y runs negative downwards, hence the negation.
local function SizeContent(parent, y)
    local width = parent:GetParent() and parent:GetParent():GetWidth() or 0
    if width > 20 then parent:SetWidth(width - 4) end
    parent:SetHeight(math.max(-y + PAD, 1))
end

local function DrawGuide(parent, y, text)
    local pw = parent:GetWidth()
    if pw < 10 then pw = frame:GetWidth() end
    local textW = pw - PAD * 2 - 20

    -- Divider
    local div = AcquireBg(parent)
    div:SetHeight(1)
    div:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 4, y - 6)
    div:SetPoint("RIGHT", parent, "RIGHT", -PAD - 4, 0)
    div:SetColorTexture(0.3, 0.3, 0.3, 0.3)
    y = y - 16

    -- Header
    local hdr = AcquireFs(parent, "GameFontNormal")
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, y)
    hdr:SetTextColor(unpack(ns.COLORS.TEXT_HEADER))
    hdr:SetText("Guide")
    ns.ApplyTextShadow(hdr)
    y = y - 20

    -- Split on double newlines into paragraphs
    local paragraphs = {}
    for para in (text .. "\n\n"):gmatch("(.-)\n\n") do
        local trimmed = para:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            table.insert(paragraphs, trimmed)
        end
    end
    -- If no double newlines found, treat whole text as one paragraph
    if #paragraphs == 0 then
        table.insert(paragraphs, text)
    end

    for i, para in ipairs(paragraphs) do
        local fs = AcquireFs(parent, "GameFontNormal")
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 10, y)
        fs:SetWidth(textW)
        fs:SetWordWrap(true)
        fs:SetSpacing(2)
        fs:SetTextColor(0.7, 0.7, 0.65)
        fs:SetText(para)
        y = y - fs:GetStringHeight() - 10
    end

    return y
end

local function DrawColumnHeader(parent, y)
    local pw = parent:GetWidth()
    if pw < 10 then pw = frame:GetWidth() end

    local bg = AcquireBg(parent)
    bg:SetHeight(18)
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
    bg:SetPoint("RIGHT", parent, "RIGHT", -PAD, 0)
    bg:SetColorTexture(1, 1, 1, 0.03)

    local slotFs = AcquireFs(parent, "GameFontNormalSmall")
    slotFs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 8, y - 2)
    slotFs:SetTextColor(0.45, 0.45, 0.45)
    slotFs:SetText("Slot")

    local itemFs = AcquireFs(parent, "GameFontNormalSmall")
    itemFs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + LABEL_W + 12, y - 2)
    itemFs:SetTextColor(0.45, 0.45, 0.45)
    itemFs:SetText("Item")

    return y - 20
end

------------------------------------------------------------
-- Refresh display
------------------------------------------------------------
function ns:RefreshConsumables()
    ResetPools()

    -- Ensure selection is initialized
    if not selectedClassFile then
        selectedClassFile, selectedSpecID = GetPlayerClassAndSpec()
    end

    ns:RefreshConsumablesFilter()

    local specKey = GetConsumableKey()
    local specName = selectedSpecID and GetSpecInfo(selectedSpecID) or "Unknown"
    local data = specKey and ns.ConsumablesDB[specKey]

    if not data then
        for _, cont in pairs(containers) do
            local fs = AcquireFs(cont, "GameFontNormal")
            fs:SetPoint("CENTER", cont, "CENTER", 0, 0)
            fs:SetText("|cff888888No data for " .. (specName or "this spec") .. " yet.|r")
        end
        return
    end

    -- Pre-cache all items
    if data.enchants then
        for _, e in ipairs(data.enchants) do CacheItem(e.itemID) end
    end
    if data.gems then
        for _, g in ipairs(data.gems) do CacheItem(g.itemID) end
    end
    if data.consumables then
        for _, c in ipairs(data.consumables) do
            CacheItem(c.itemID)
            if c.alt then CacheItem(c.alt.itemID) end
        end
    end

    -- Enchants tab
    local ep = containers.enchants
    local ey = DrawStaleBanner(containers.enchants, -6, data)
    if data.enchants and #data.enchants > 0 then
        ey = DrawColumnHeader(ep, ey)
        for _, e in ipairs(data.enchants) do
            ey = DrawRow(ep, ey, e.itemID, e.slot)
        end
    end
    if data.enchantGuide then
        ey = DrawGuide(ep, ey, data.enchantGuide)
    end
    SizeContent(ep, ey)

    -- Gems tab
    local gp = containers.gems
    local gy = DrawStaleBanner(gp, -6, data)
    if data.gems and #data.gems > 0 then
        gy = DrawColumnHeader(gp, gy)
        for _, g in ipairs(data.gems) do
            gy = DrawRow(gp, gy, g.itemID, g.label)
        end
    end
    if data.gemGuide then
        gy = DrawGuide(gp, gy, data.gemGuide)
    end
    SizeContent(gp, gy)

    -- Consumables tab
    local cp = containers.consumables
    local cy = DrawStaleBanner(cp, -6, data)
    if data.consumables and #data.consumables > 0 then
        cy = DrawColumnHeader(cp, cy)
        for _, c in ipairs(data.consumables) do
            cy = DrawRow(cp, cy, c.itemID, c.label)
            if c.alt then
                cy = DrawAltRow(cp, cy, c.alt.itemID)
            end
        end
    end
    if data.consumableGuide then
        cy = DrawGuide(cp, cy, data.consumableGuide)
    end
    SizeContent(cp, cy)
end
