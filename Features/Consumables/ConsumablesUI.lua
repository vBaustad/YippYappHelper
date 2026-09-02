local _, ns = ...

------------------------------------------------------------
-- Consumables panel with tabs: Enchants | Gems | Consumables
-- Filter bar: class dropdown + spec buttons
------------------------------------------------------------
local PANEL_WIDTH  = 460
local PANEL_HEIGHT = 540
-- Padding comes from the shell, not from here. Eight pages had picked
-- their own -- 12 in four of them, 14 in three -- so every page sat to a
-- different rhythm from the chrome around it and from each other. One
-- source means a spacing change lands everywhere at once.
local PAD = (ns.Shell and ns.Shell.PAD) or 14
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
------------------------------------------------------------
-- The tab list, and why it lives up here
--
-- Shell:Mount asks a page for its sub-tabs BEFORE it builds it: it
-- restores the saved tab, draws the strip, and only then calls Build.
-- Since the page below is built on first open, anything the shell needs
-- in that window has to exist without it.
--
-- Get this wrong and the failure hides: the strip is empty on the first
-- visit and correct on the second, because by then the page exists.
------------------------------------------------------------
local TAB_DEFS = {
    { id = "enchants",     label = "Enchants",     color = { 0.0, 1.0, 0.3 } },
    { id = "gems",         label = "Gems",         color = { 0.64, 0.21, 0.93 } },
    { id = "consumables",  label = "Consumables",  color = { 1.0, 0.53, 0.0 } },
}

--- The views this page offers.
---
--- The shell owns the sub-tab strip; this page was drawing its own row a
--- few pixels from where the shell puts one, which is two tab rows on a
--- single screen. Its own row still serves the standalone window and is
--- hidden in app mode.
---
--- Reads TAB_DEFS and nothing else, which is what lets it answer before
--- a single frame exists. Its partner ns:SetConsumablesTab stays inside
--- the builder: that one drives real tab buttons, and the shell only
--- calls it on a click, long after Build.
function ns:GetConsumablesTabs()
    local out = {}
    for i, def in ipairs(TAB_DEFS) do
        out[i] = { id = def.id, label = def.label, width = 110 }
    end
    return out
end

------------------------------------------------------------
-- The page itself, built on first open.
--
-- Everything below this line used to run at load: 32 frames and 77
-- regions -- the panel, the filter bar with its two dropdowns, and a tab
-- button, scroll frame and container for each of the three tabs -- for a
-- page that has to be clicked to be seen.
--
-- Wrapped whole rather than picked apart. The file is one construction
-- script from here down, with no events and no registration, so the
-- smallest honest change is to stop running it until somebody asks. Its
-- 73 locals become the function's, which is why they were counted first:
-- Lua allows 200 per function.
--
-- ns:SetConsumablesAppMode, ns:SetConsumablesTab and
-- ns:RefreshConsumables are all defined in here, and that is correct.
-- Core\ShellPages.lua looks each of them up BY NAME after running the
-- creator, and every other caller guards on them. A page that does not
-- exist has no app mode, no current tab and nothing to refresh.
------------------------------------------------------------
function ns:CreateConsumablesFrame()
    if ns.ConsumablesFrame then return end

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
ns.Widgets:Apply(frame, "panel")
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
-- Forward-declared, all three, because SetConsumablesAppMode below
-- touches them and they are built further down the file.
--
-- filterBar was declared here and the other two were not, which is the
-- whole of the "Consumables shows nothing" bug: a local declared LATER
-- is not in scope inside a function written earlier, so `tabButtons`
-- there resolved to a global, and the global was nil. It threw on
-- pairs(nil) before the page had drawn a single row. Nothing about the
-- call site looked wrong -- the table exists, just not yet.
local filterBar, tabButtons, scrolls

function ns:SetConsumablesAppMode(enabled, contentWidth, contentHeight)
    if enabled then
        ns.Widgets:Unskin(frame)
        closeBtn:Hide()
        -- The shell draws the strip in app mode.
        for _, btn in pairs(tabButtons) do btn:Hide() end
        -- ...so the 28px this content reserved for that row is now dead
        -- space at the top of the page. Reclaim it. Hiding a control
        -- without re-anchoring what sat below it is how a migration
        -- leaves a page looking emptier than it was.
        for _, scroll in pairs(scrolls) do
            scroll:ClearAllPoints()
            scroll:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -2)
            scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 8)
        end
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
        ns.Widgets:Unskin(filterBar)
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
        ns.Widgets:Apply(frame, "panel")
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
        ns.Widgets:Apply(filterBar, "row")
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
ns.Widgets:Apply(filterBar, "row")
ns.SmoothFrame(filterBar)

--- The filter strip's borders, from the skin.
---
--- These controls were skinned with W:Apply and then immediately
--- repainted with hardcoded greys and a cyan selection, so the top of
--- the page wore a cold grey/cyan palette while the cards below it wore
--- the skin's warm gold. That is the whole of "the top feels like a
--- different style" -- the skin was reaching these frames and being
--- overwritten a line later by a colour no skin can change.
---
--- The `inset` edge deliberately, not `row`: these read as controls
--- sitting ON the page, and matching the cards' own hairline is what
--- puts them in the same design as everything under them.
local function EdgeIdle(btn)
    local _, edge = ns.Widgets:Surface("inset")
    if edge then
        btn:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4] or 1)
    else
        btn:SetBackdropBorderColor(ns.Widgets:Color("faint"))
    end
end

local function EdgeAccent(btn, alpha)
    local r, g, b = ns.Widgets:Color("accent")
    btn:SetBackdropBorderColor(r, g, b, alpha or 0.9)
end

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
ns.Widgets:Apply(classBtn, "row")
ns.SmoothFrame(classBtn)
ns.AddGlowHighlight(classBtn, 0.06)

local classBtnName = classBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
classBtnName:SetPoint("LEFT", 8, 0)
ns.ApplyTextShadow(classBtnName)

local classBtnArrow = classBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
classBtnArrow:SetPoint("RIGHT", -4, 0)
classBtnArrow:SetTextColor(unpack(ns.COLORS.TEXT_TERTIARY))
classBtnArrow:SetText("v")

classBtn:SetScript("OnEnter", function(self) EdgeAccent(self, 0.55) end)
classBtn:SetScript("OnLeave", EdgeIdle)
EdgeIdle(classBtn)

-- Popout, at the far end of the strip.
--
-- Right-aligned rather than trailing the spec buttons, so it does not
-- move when you switch from a three-spec class to a four-spec one --
-- a control that changes place when you change an unrelated filter is a
-- control you have to look for every time.
local popBtn = CreateFrame("Button", nil, filterBar, "BackdropTemplate")
popBtn:SetSize(70, 24)
popBtn:SetPoint("RIGHT", filterBar, "RIGHT", -10, 0)
ns.Widgets:Apply(popBtn, "row")
ns.SmoothFrame(popBtn)
ns.AddGlowHighlight(popBtn, 0.06)

local popBtnFs = popBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
popBtnFs:SetPoint("CENTER")
popBtnFs:SetText("Popout")
popBtnFs:SetTextColor(ns.Widgets:Color("muted"))
ns.ApplyTextShadow(popBtnFs)

popBtn:SetScript("OnEnter", function(self)
    EdgeAccent(self, 0.55)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Popout")
    GameTooltip:AddLine("These items in a small movable window, for parking "
        .. "beside the Auction House. Shift-click a name there to search "
        .. "for it.", 0.8, 0.8, 0.85, true)
    GameTooltip:Show()
end)
popBtn:SetScript("OnLeave", function(self) EdgeIdle(self); GameTooltip:Hide() end)
EdgeIdle(popBtn)
-- Resolved at click time: the toggle is defined at the foot of the file,
-- with the window it opens.
popBtn:SetScript("OnClick", function()
    if ns.ToggleConsumablesPopout then ns:ToggleConsumablesPopout() end
end)

-- Class dropdown popup
local classDropdown = CreateFrame("Frame", "YippYappConsumClassDropdown", UIParent, "BackdropTemplate")
classDropdown:SetSize(160, 10)
classDropdown:SetFrameStrata("DIALOG")
classDropdown:SetClampedToScreen(true)
ns.Widgets:Apply(classDropdown, "row")
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
    ns.Widgets:Apply(btn, "row")
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
            -- Selected reads in the skin's accent rather than a fixed
            -- cyan, so the chosen spec is lit in the same colour the
            -- rest of the window uses for "this one".
            if specID == selectedSpecID then
                EdgeAccent(btn, 0.9)
                btn._label:SetTextColor(ns.Widgets:Color("accent"))
            else
                EdgeIdle(btn)
                btn._label:SetTextColor(ns.Widgets:Color("muted"))
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

-- Assigned, not declared: both are forward-declared up by
-- SetConsumablesAppMode, which reads them. Re-declaring them local here
-- would shadow those and leave the function looking at nil again.
tabButtons = {}
local containers = {}
-- The scroll frame that owns each container. Shown/hidden with the tab;
-- the container itself is the scroll child and is always "visible".
scrolls = {}

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
    -- No page-wide surface any more.
    --
    -- There used to be an "inset" panel spanning the whole content area,
    -- anchored 22px LEFT of the filter bar -- so it hung off the page's
    -- left edge, out past the tabs, and read as a second recessed window
    -- inside the first. The shell's content region already IS the
    -- surface; the sections below draw the cards that belong on it.

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    -- Flush with the filter bar above it. The -PAD pulled the whole list
    -- 14px left of the tabs and the class dropdown, which is why nothing
    -- on the page lined up with anything else.
    scroll:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -28)
    -- 10, not 26: the bar only appears when it is needed now, and when
    -- it does it sits in the page margin beside the cards rather than
    -- carving a permanent gutter out of them.
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 8)
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
    -- The popout mirrors whichever tab is open, and switching tabs does
    -- not go through RefreshConsumables. Guarded because this runs once
    -- at load, before the foot of the file has defined it.
    if ns.RefreshConsumablesPopout then ns:RefreshConsumablesPopout() end
end

for id, btn in pairs(tabButtons) do
    btn:SetScript("OnClick", function()
        currentTab = id
        UpdateTabs()
    end)
end

UpdateTabs()

function ns:SetConsumablesTab(id)
    if not tabButtons[id] or currentTab == id then return end
    currentTab = id
    UpdateTabs()
end

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

-- Forward-declared: the section pool is built further down with the row
-- helpers it belongs to, but ResetPools up here has to release it. The
-- load harness caught this immediately -- it is the same shape as the
-- bug that had this very page rendering nothing.
local ResetSections

local function ResetPools()
    ResetSections()
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

-- Forward-declared: the popout is built hundreds of lines below, with
-- the rest of the window it belongs to, but the cache up here has to
-- know whether it is on screen. Assigned there, called from here.
local PopoutShown

local function CacheItem(itemID)
    if itemLinkCache[itemID] then return end
    local item = Item:CreateFromItemID(itemID)
    item:ContinueOnItemLoad(function()
        local name, link, _, _, _, _, _, _, _, icon = GetItemInfo(itemID)
        if link then itemLinkCache[itemID] = link end
        if icon then itemIconCache[itemID] = icon end
        if name then itemNameCache[itemID] = name end
        -- The popout counts as on screen, not just the page.
        --
        -- This was gated on the page alone, and the popout is the window
        -- that opens BESIDE the Auction House -- usually with the page
        -- itself closed. So the first visit of a session drew the rows
        -- against an empty cache, the names landed a moment later with
        -- nothing listening, and the list sat there reading "item:273072"
        -- until it was closed and opened again.
        local pageUp, popUp = frame:IsShown(), PopoutShown and PopoutShown()
        if (pageUp or popUp) and not pendingRefresh then
            pendingRefresh = true
            C_Timer.After(0.1, function()
                pendingRefresh = false
                -- The page's refresh redraws the popout at the end of
                -- itself, so only the popout-alone case needs its own
                -- call.
                if frame:IsShown() then
                    ns:RefreshConsumables()
                elseif PopoutShown and PopoutShown() then
                    ns:RefreshConsumablesPopout()
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
-- The card's own padding, and where content sits once it is inside one.
-- Split, because the two axes want different answers.
--
-- Horizontally: nothing. The card IS the table's background, so a row
-- that stops short of its edge leaves a border, then a gap, then the
-- row -- padding on top of the page margin the card already sits in.
-- Rows run to the card's edge and the hairline frames them.
--
-- Vertically: a little, so the first and last rows are not sitting on
-- the border they are framed by.
-- Zero on every side. The card IS the table's background, so ANY gap
-- between its border and the table's own fill reads as the table
-- floating inside a box.
--
-- The breathing room the table needs at its top and bottom is real, but
-- it belongs INSIDE the table's fill, not outside it: a taller header
-- band, and a strip of the same background under the last row. Padding
-- the card instead leaves the card's own colour showing through, which
-- is the gap it was supposed to remove.
local SEC_PAD_X = 0
local SEC_PAD = 0
-- Space above the header text and below the last row, carried by the
-- table's own background rather than by the card's padding.
local TABLE_EDGE = 8
-- Breathing room belongs to the TEXT, not to the card. Pushing the rows
-- off the border just moved the whitespace outside where it reads as a
-- seam; inside the row it reads as a margin.
local ROW_TEXT_PAD = 14
local SEC_GAP = 10
local ROW_X = PAD + SEC_PAD_X

--- The width this container's contents actually have.
---
--- Taken from the SCROLL FRAME, not from the container. SizeContent sets
--- the container's own width and it runs AFTER everything has been
--- drawn, so every row and card in a refresh was measuring itself
--- against the width left over from the previous one. That was invisible
--- while the rows were bare text on a full-width page; it became a card
--- stopping half way across the panel the moment they gained a border.
local function ContentWidth(parent)
    local sf = parent and parent:GetParent()
    local w = sf and sf:GetWidth() or 0
    if w > 20 then return w - 4 end
    w = (parent and parent:GetWidth()) or 0
    if w > 20 then return w end
    return frame:GetWidth()
end

-- Sections, pooled. Same widget Teleports, Progression, the Loot Browser
-- and Mythic+ use, so a consumables list reads as the same kind of thing
-- as everything else in the addon rather than as a bare table on a slab.
local secPool, secPoolIdx = {}, 0

local function AcquireSection(parent)
    secPoolIdx = secPoolIdx + 1
    local sec = secPool[secPoolIdx]
    if not sec then
        sec = ns.Widgets:SectionCard(parent)
        secPool[secPoolIdx] = sec
    else
        sec:SetParent(parent)
    end
    sec:ClearAllPoints()
    sec:SetValue("")
    sec:Show()
    -- Exposed so Tools/loadcheck.py can read the laid-out geometry back
    -- and check the cards do not overlap or run past the region. Two
    -- assignments, and it turns "the sections look right" into something
    -- a check can decide.
    ns.__consSecPool, ns.__consSecIdx = secPool, secPoolIdx
    return sec
end

function ResetSections()
    for i = 1, secPoolIdx do secPool[i]:Hide() end
    secPoolIdx = 0
    ns.__consSecIdx = 0
end

--- Open a section and return it plus the y its contents start at.
---
--- Titled with the SPEC, not the tab. The tab strip directly above
--- already reads "Enchants" / "Gems" / "Consumables", so repeating it
--- here would be a heading that tells you what you just clicked. Which
--- spec the recommendations are for is the thing the card can say that
--- nothing else on the page does -- the window's own spec label is
--- hidden in app mode.
---
--- Sized on close rather than here: how many rows a spec has, and how
--- tall its guide wraps to, are not known until they are drawn.
local function OpenSection(parent, y, title)
    local sec = AcquireSection(parent)
    sec:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
    sec:SetText(title)
    return sec, y - ns.Widgets:SectionTitleHeight() - SEC_PAD
end

local function CloseSection(parent, sec, top, y)
    local w = ContentWidth(parent)
    sec:Layout(w - PAD * 2, (top - y) + SEC_PAD * 2)
    return y - SEC_PAD - SEC_GAP
end

--- Shift-click sends the item wherever something is listening.
---
--- HandleModifiedItemClick is the game's own router for this and knows
--- more destinations than we do -- the chat box, the socket UI, a trade
--- skill's search field -- so it goes first and its answer is trusted.
--- It was previously gated behind an IsModifiedClick("CHATLINK") test of
--- our own, which is a check it already makes internally and which threw
--- away every other modifier it handles.
---
--- The fallback is for one destination in particular. The Auction House
--- is the whole reason this list gets opened beside something else, and a
--- shift-click that does nothing in front of an auctioneer reads as the
--- addon being broken. Guarded on the method existing rather than on a
--- client version, so where it does not apply it is inert rather than
--- wrong.
local function LinkClick(link)
    if not link then return end
    if HandleModifiedItemClick and HandleModifiedItemClick(link) then return end
    if not IsModifiedClick("CHATLINK") then return end
    local ah = _G.AuctionHouseFrame
    if ah and ah.SetSearchText and ah:IsShown() then
        local name = GetItemInfo(link)
        if name then pcall(ah.SetSearchText, ah, name) end
    end
end

--- The hit area for a row's item: its icon and its name, and nothing
--- else on the line.
---
--- This was the whole row, edge to edge. So the tooltip fired over the
--- "Flask" label, over the empty half of the row past the name, and over
--- the dead space between two names -- running the pointer down the list
--- popped a tooltip the entire way, and there was nowhere on the panel
--- to rest the cursor without one. Hugging the text also puts the
--- shift-click target on the thing that looks like a link, which is what
--- a reader will aim at anyway.
---
--- Sized from the FontString, not from the panel: GetStringWidth is the
--- text's natural width, which is what the reader can see, capped at the
--- width the row allotted it so a long name cannot hand out a hit area
--- wider than the row holding it.
local function HookItemHit(parent, x, y, nameFs, link)
    local textW = math.min(nameFs:GetStringWidth() or 0, nameFs:GetWidth() or 0)
    local btn = AcquireHitBtn(parent)
    btn:SetSize(ICON_SIZE + 6 + math.max(textW, 20), ROW_H - 2)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    btn:SetScript("OnEnter", function(self)
        -- ANCHOR_CURSOR still, even though the hit area is small now.
        -- This list is meant to be parked at the edge of the screen
        -- beside the Auction House, and anchoring off the frame's own
        -- side puts the tooltip half off the screen there.
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function() LinkClick(link) end)
    return btn
end

local function DrawRow(parent, y, itemID, label)
    local icon = GetItemIcon(itemID)
    local link = GetItemLink(itemID)
    local name = GetItemName(itemID) or ("item:" .. itemID)
    local pw = ContentWidth(parent)

    local bg = AcquireBg(parent)
    bg:SetHeight(ROW_H)
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", ROW_X, y)
    bg:SetPoint("RIGHT", parent, "RIGHT", -ROW_X, 0)
    bg:SetColorTexture(1, 1, 1, 0.02)

    local labelFs = AcquireFs(parent, "GameFontNormal")
    labelFs:SetPoint("TOPLEFT", parent, "TOPLEFT", ROW_X + ROW_TEXT_PAD, y - 3)
    labelFs:SetWidth(LABEL_W)
    labelFs:SetTextColor(0.65, 0.65, 0.65)
    labelFs:SetText(label)

    local itemX = ROW_X + ROW_TEXT_PAD + LABEL_W
    if icon then
        local tex = AcquireIcon(parent)
        tex:SetSize(ICON_SIZE, ICON_SIZE)
        tex:SetPoint("TOPLEFT", parent, "TOPLEFT", itemX, y - 2)
        tex:SetTexture(icon)
    end

    local nameFs = AcquireFs(parent, "GameFontNormal")
    nameFs:SetPoint("TOPLEFT", parent, "TOPLEFT", itemX + ICON_SIZE + 6, y - 3)
    nameFs:SetWidth(pw - itemX - ICON_SIZE - ROW_X - 10)
    if link then
        nameFs:SetText(link)
    else
        nameFs:SetText("|cffffffff" .. name .. "|r")
    end

    HookItemHit(parent, itemX, y - 2, nameFs, link or ("item:" .. itemID))

    return y - ROW_H
end

local function DrawAltRow(parent, y, itemID)
    local icon = GetItemIcon(itemID)
    local link = GetItemLink(itemID)
    local name = GetItemName(itemID) or ("item:" .. itemID)
    local pw = ContentWidth(parent)

    local bg = AcquireBg(parent)
    bg:SetHeight(ROW_H)
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", ROW_X, y)
    bg:SetPoint("RIGHT", parent, "RIGHT", -ROW_X, 0)
    bg:SetColorTexture(1, 1, 1, 0.015)

    local labelFs = AcquireFs(parent, "GameFontNormalSmall")
    labelFs:SetPoint("TOPLEFT", parent, "TOPLEFT", ROW_X + ROW_TEXT_PAD, y - 4)
    labelFs:SetWidth(LABEL_W)
    labelFs:SetTextColor(0.4, 0.4, 0.4)
    labelFs:SetText("or")

    local itemX = ROW_X + ROW_TEXT_PAD + LABEL_W
    if icon then
        local tex = AcquireIcon(parent)
        tex:SetSize(ICON_SIZE, ICON_SIZE)
        tex:SetPoint("TOPLEFT", parent, "TOPLEFT", itemX, y - 2)
        tex:SetTexture(icon)
    end

    local nameFs = AcquireFs(parent, "GameFontNormal")
    nameFs:SetPoint("TOPLEFT", parent, "TOPLEFT", itemX + ICON_SIZE + 6, y - 3)
    nameFs:SetWidth(pw - itemX - ICON_SIZE - ROW_X - 10)
    if link then
        nameFs:SetText(link)
    else
        nameFs:SetText("|cffffffff" .. name .. "|r")
    end

    HookItemHit(parent, itemX, y - 2, nameFs, link or ("item:" .. itemID))

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

    local pw = ContentWidth(parent)

    -- Kept to a single compact line: these containers do not scroll, so
    -- every pixel the banner adds pushes the last rows off the bottom.
    local bg = AcquireBg(parent)
    bg:SetHeight(20)
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", ROW_X, y - 1)
    bg:SetPoint("RIGHT", parent, "RIGHT", -ROW_X, 0)
    bg:SetColorTexture(0.45, 0.30, 0.05, 0.35)

    local fs = AcquireFs(parent, "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", ROW_X + 6, y - 6)
    fs:SetWidth(pw - ROW_X * 2 - 12)
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
--- Show the scroll bar only when there is something to scroll.
---
--- UIPanelScrollFrameTemplate draws its bar unconditionally, so a page
--- whose content fitted still carried a full-height bar and the 26px of
--- reserved gutter beside it -- a control for a gesture that does
--- nothing, and a strip of dead page next to the cards.
local function UpdateScrollBar(scroll, contentH)
    local bar = scroll and (scroll.ScrollBar or scroll.scrollBar)
    -- Type-checked, not just nil-checked. Which field holds the bar --
    -- and whether the template makes one at all -- has changed between
    -- client versions, so this asks whether what came back can actually
    -- be shown rather than assuming it can.
    if type(bar) ~= "table" or not bar.SetShown then return end
    local viewH = scroll:GetHeight() or 0
    -- The mouse wheel still works either way; this only decides whether
    -- the bar is worth the width it takes.
    bar:SetShown(viewH > 0 and contentH > viewH + 1)
end

local function SizeContent(parent, y)
    local width = ContentWidth(parent)
    if width > 20 then parent:SetWidth(width) end
    local h = math.max(-y + PAD, 1)
    parent:SetHeight(h)
    UpdateScrollBar(parent:GetParent(), h)
end

local function DrawGuide(parent, y, text)
    local pw = ContentWidth(parent)
    local textW = pw - ROW_X * 2 - ROW_TEXT_PAD * 2

    -- No divider and no "Guide" heading here any more: the section card
    -- this is drawn into carries both, and the rule is its top edge. The
    -- hand-rolled pair drew a second line a few pixels from the card's
    -- own, which is the doubled-rule problem every other page had.

    -- Prose gets a vertical margin where the table does not. Rows are
    -- flush to the card's edges because the card is their frame and a
    -- gap there reads as a seam; a paragraph pressed against the same
    -- border just reads as text about to fall out of the box.
    y = y - ROW_TEXT_PAD

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
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", ROW_X + ROW_TEXT_PAD, y)
        fs:SetWidth(textW)
        fs:SetWordWrap(true)
        fs:SetSpacing(2)
        fs:SetTextColor(0.7, 0.7, 0.65)
        fs:SetText(para)
        y = y - fs:GetStringHeight() - 10
    end

    return y - ROW_TEXT_PAD + 10
end

local function DrawColumnHeader(parent, y)
    local pw = ContentWidth(parent)

    -- Taller than its text needs, with the labels pushed down inside
    -- it. The band still starts at the card's top border, so the space
    -- above "Slot" is the header's own background rather than a gap
    -- above the table.
    local headerH = 18 + TABLE_EDGE
    local bg = AcquireBg(parent)
    bg:SetHeight(headerH)
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", ROW_X, y)
    bg:SetPoint("RIGHT", parent, "RIGHT", -ROW_X, 0)
    bg:SetColorTexture(1, 1, 1, 0.03)

    local slotFs = AcquireFs(parent, "GameFontNormalSmall")
    slotFs:SetPoint("TOPLEFT", parent, "TOPLEFT", ROW_X + ROW_TEXT_PAD, y - TABLE_EDGE - 2)
    slotFs:SetTextColor(0.45, 0.45, 0.45)
    slotFs:SetText("Slot")

    local itemFs = AcquireFs(parent, "GameFontNormalSmall")
    itemFs:SetPoint("TOPLEFT", parent, "TOPLEFT", ROW_X + ROW_TEXT_PAD + LABEL_W, y - TABLE_EDGE - 2)
    itemFs:SetTextColor(0.45, 0.45, 0.45)
    itemFs:SetText("Item")

    return y - headerH - 2
end

--- A blank strip of the table's own background, closing it off.
---
--- The space under the last row has to be part of the TABLE. Card
--- padding would leave the card's colour showing between the border and
--- the rows, which is the gap this is meant to remove; a strip of
--- row-coloured fill does the same job from the inside.
local function DrawTableFoot(parent, y)
    local bg = AcquireBg(parent)
    bg:SetHeight(TABLE_EDGE)
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", ROW_X, y)
    bg:SetPoint("RIGHT", parent, "RIGHT", -ROW_X, 0)
    bg:SetColorTexture(1, 1, 1, 0.02)
    return y - TABLE_EDGE
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
        local sec, top = OpenSection(ep, ey, specName)
        sec:SetValue(("|cff%s%d slots|r"):format(
            ns.Widgets:Hex("faint"), #data.enchants))
        ey = DrawColumnHeader(ep, top)
        for _, e in ipairs(data.enchants) do
            ey = DrawRow(ep, ey, e.itemID, e.slot)
        end
        ey = DrawTableFoot(ep, ey)
        ey = CloseSection(ep, sec, top, ey)
    end
    if data.enchantGuide then
        local sec, top = OpenSection(ep, ey, "Guide")
        ey = CloseSection(ep, sec, top, DrawGuide(ep, top, data.enchantGuide))
    end
    SizeContent(ep, ey)

    -- Gems tab
    local gp = containers.gems
    local gy = DrawStaleBanner(gp, -6, data)
    if data.gems and #data.gems > 0 then
        local sec, top = OpenSection(gp, gy, specName)
        sec:SetValue(("|cff%s%d gems|r"):format(
            ns.Widgets:Hex("faint"), #data.gems))
        gy = DrawColumnHeader(gp, top)
        for _, g in ipairs(data.gems) do
            gy = DrawRow(gp, gy, g.itemID, g.label)
        end
        gy = DrawTableFoot(gp, gy)
        gy = CloseSection(gp, sec, top, gy)
    end
    if data.gemGuide then
        local sec, top = OpenSection(gp, gy, "Guide")
        gy = CloseSection(gp, sec, top, DrawGuide(gp, top, data.gemGuide))
    end
    SizeContent(gp, gy)

    -- Consumables tab
    local cp = containers.consumables
    local cy = DrawStaleBanner(cp, -6, data)
    local cSec, cTop
    if data.consumables and #data.consumables > 0 then
        cSec, cTop = OpenSection(cp, cy, specName)
        cSec:SetValue(("|cff%s%d items|r"):format(
            ns.Widgets:Hex("faint"), #data.consumables))
        cy = DrawColumnHeader(cp, cTop)
        for _, c in ipairs(data.consumables) do
            cy = DrawRow(cp, cy, c.itemID, c.label)
            if c.alt then
                cy = DrawAltRow(cp, cy, c.alt.itemID)
            end
        end
    end
    if cSec then
        cy = DrawTableFoot(cp, cy)
        cy = CloseSection(cp, cSec, cTop, cy)
    end
    if data.consumableGuide then
        local sec, top = OpenSection(cp, cy, "Guide")
        cy = CloseSection(cp, sec, top, DrawGuide(cp, top, data.consumableGuide))
    end
    SizeContent(cp, cy)

    -- Changing class or spec behind an open popout has to reach it, or
    -- it sits there listing the last spec you looked at.
    if ns.RefreshConsumablesPopout then ns:RefreshConsumablesPopout() end
end

------------------------------------------------------------
-- Popout
--
-- The Auction House is the reason this exists. The panel is 460 wide
-- before the shell around it, and what you want while standing at an
-- auctioneer is fifteen names you can shift-click -- not a class
-- dropdown, a spec strip and a guide underneath. So: the open tab's
-- rows, in a window small enough to park beside something else, that
-- remembers where you put it.
--
-- Its own row pool, deliberately. ResetPools wipes the page's pools on
-- every refresh of the main panel, so a popout drawing from them would
-- be blanked by a spec click behind it.
------------------------------------------------------------
-- Wider and taller than it started, and both for the same reason: the
-- names here are the longest in the addon. A weapon enchant at 250 wide
-- wrapped onto a second line inside a 22px row, so every long name was
-- drawn through the one under it and the window read as a wall. Now the
-- row is one line tall, the name is truncated rather than wrapped, and
-- the full text is a click away.
local POP_W, POP_ROW_H = 292, 24

-- The window's own margin, and the gap between an icon and its name.
local POP_PAD = 12
local POP_ICON, POP_ICON_GAP = 18, 7

-- The band under the rows carrying the one line that says what a click
-- and a shift-click do.
local POP_HINT_H = 18

-- The gap between the Auction House's right edge and this window, while
-- it is pinned there. Enough that the two do not read as one frame, small
-- enough that they still read as a pair.
local POP_AH_GAP = 4

-- The pin checkbox's band along the bottom, added to the height only
-- while that checkbox is showing.
local POP_FOOT_H = 22

local popout, popRows = nil, {}

-- Fills the forward declaration the item cache made for this.
function PopoutShown()
    return (popout and popout:IsShown()) and true or false
end

-- Whether the window on screen is one this file put there, rather than
-- one the player opened. Only an auto-opened window is auto-closed:
-- someone who popped it out by hand before walking to an auctioneer did
-- not ask for the Auction House to take it away again.
local popoutAuto = false

local function PopoutDB()
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.consumablesPopout = YippYappHelperDB.consumablesPopout or {}
    return YippYappHelperDB.consumablesPopout
end

--- Is the Auction House on screen?
---
--- Read off the frame rather than tracked from the events, because the
--- two answers can disagree: Blizzard_AuctionHouseUI is load-on-demand,
--- so at AUCTION_HOUSE_SHOW the frame may not exist yet, and a flag set
--- there would claim an open window that is not drawn.
local function AuctionHouseOpen()
    local ah = _G.AuctionHouseFrame
    return (ah and ah:IsShown()) and true or false
end

--- What this window is pinned to, or nil if it is loose.
---
--- Absent from the DB means pinned. The pin is the point of the feature
--- -- a shopping list you have to drag into place every visit is not
--- much of a convenience -- so the box starts ticked and unticking it is
--- the deliberate act.
local function PopoutPinHost()
    if not AuctionHouseOpen() then return nil end
    if PopoutDB().pinAH == false then return nil end
    return _G.AuctionHouseFrame
end

--- Write down where the window is right now, in UIParent's terms.
---
--- Screen coordinates rather than the anchor it currently has, because
--- the anchor it currently has may be the Auction House -- a frame that
--- is not there at login and cannot be restored against.
---
--- Guarded on both reads: a frame that has never been laid out has no
--- rectangle to report, and saving nil for a coordinate would take the
--- window somewhere nobody put it.
local function PopoutFreeze()
    if not popout then return end
    local left, top = popout:GetLeft(), popout.GetTop and popout:GetTop()
    if not (left and top) then return end
    local scale = (popout:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    local db = PopoutDB()
    db.point, db.rel = "TOPLEFT", "BOTTOMLEFT"
    db.x, db.y = left * scale, top * scale
end

--- Put the window where it belongs.
---
--- Anchored TOPLEFT to the Auction House's TOPRIGHT, so it hangs off the
--- side rather than covering anything. That corner also fixes the top
--- edge, which matters more than it sounds: the window's height changes
--- with the view -- Gems is a third of Consumables -- and anchored from
--- the bottom it would jump every time you paged the arrows.
local function PopoutPlace()
    if not popout then return end
    popout:ClearAllPoints()
    local host = PopoutPinHost()
    if host then
        popout:SetPoint("TOPLEFT", host, "TOPRIGHT", POP_AH_GAP, 0)
        return
    end
    local db = PopoutDB()
    if db.point then
        popout:SetPoint(db.point, UIParent, db.rel or db.point, db.x or 0, db.y or 0)
    else
        -- Parked at the right edge of the screen, not offset from the
        -- centre: the app frame is centred and has grown, so "centre
        -- plus 300" was landing on top of it. The screen edge is clear
        -- of both the app and a centred Auction House, and it is where
        -- someone would drag this anyway.
        popout:SetPoint("RIGHT", UIParent, "RIGHT", -40, 0)
    end
end

--- What the open tab is showing, flattened.
---
--- Alternatives come through as rows of their own, marked so they can be
--- indented -- the page distinguishes them with an "or" in a column this
--- window has no room for, and two names at the same indent with no word
--- between them read as two things to buy rather than a choice.
local function PopoutList()
    local data = ns.ConsumablesDB and ns.ConsumablesDB[GetConsumableKey() or ""]
    if not data then return {} end
    local src = (currentTab == "enchants" and data.enchants)
        or (currentTab == "gems" and data.gems)
        or data.consumables
    local out = {}
    for _, e in ipairs(src or {}) do
        out[#out + 1] = { itemID = e.itemID }
        if e.alt then out[#out + 1] = { itemID = e.alt.itemID, alt = true } end
    end
    return out
end

--- Switch views, taking the rest of the addon with it.
---
--- Through the shell when the page is mounted there, so its sub-tab
--- strip does not sit underlining a view that is no longer the one
--- showing. Both calls, not one or the other: Shell:SetSubTab returns
--- early when the page was never mounted -- the standalone window, or
--- the app never opened this session -- and SetConsumablesTab returns
--- early when the id is already current, which is what it will be once
--- the shell path has run. Either order, one of them does the work and
--- the other is a no-op.
local function PopoutSetTab(id)
    if ns.Shell and ns.Shell.SetSubTab then
        ns.Shell:SetSubTab("consumables", id)
    end
    if ns.SetConsumablesTab then ns:SetConsumablesTab(id) end
end

--- Move `step` views along, wrapping.
---
--- Wrapping rather than stopping at the ends. Three views is short
--- enough that a greyed-out arrow is more to read than it saves, and
--- next-from-the-last landing back on the first is what a three-item
--- pager is expected to do.
local function PopoutCycle(step)
    local n = #TAB_DEFS
    if n == 0 then return end
    local at = 1
    for i, def in ipairs(TAB_DEFS) do
        if def.id == currentTab then at = i break end
    end
    local nxt = TAB_DEFS[(at - 1 + step) % n + 1]
    if nxt then PopoutSetTab(nxt.id) end
end

--- One arrow of the pager.
---
--- Text rather than art. The obvious candidates are Blizzard's spellbook
--- page arrows, which are 32px of chunky gilt frame built for a book --
--- next to a 12px title in a 250px window they would be the loudest
--- thing on it.
local function PopArrow(parent, glyph, step)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(16, 18)
    b:RegisterForClicks("LeftButtonUp")
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER")
    fs:SetText(glyph)
    fs:SetTextColor(ns.Widgets:Color("muted"))
    b._fs = fs
    b:SetScript("OnEnter", function(s2)
        s2._fs:SetTextColor(ns.Widgets:Color("accent"))
        GameTooltip:SetOwner(s2, "ANCHOR_TOP")
        GameTooltip:AddLine(step < 0 and "Previous view" or "Next view")
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(s2)
        s2._fs:SetTextColor(ns.Widgets:Color("muted"))
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function() PopoutCycle(step) end)
    return b
end

--- The item whose tooltip is currently pinned open, or nil.
---
--- An id rather than a row, because the rows are re-wired on every
--- redraw and item data lands in a stream -- a tooltip held open while
--- the names are still arriving has to survive being redrawn under.
local popTipID

local function PopTipHide()
    if not popTipID then return end
    popTipID = nil
    GameTooltip:Hide()
end

--- Put the tooltip beside the WINDOW, not beside the row.
---
--- Anchored to the row it would open half way down the list and cover
--- the rows under it. Anchored to the window it clears the whole list,
--- and the side is chosen by which one has the room: pinned to the
--- Auction House this window is already well right of centre, and a
--- tooltip hard-anchored to its right would run off the screen.
local function PopTipShow(row, itemID, link)
    if not (popout and link) then return end
    popTipID = itemID
    GameTooltip:SetOwner(row, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    local right = popout:GetRight() or 0
    local room = (UIParent:GetRight() or 0) - right
    if room > 340 then
        GameTooltip:SetPoint("TOPLEFT", popout, "TOPRIGHT", 6, 0)
    else
        GameTooltip:SetPoint("TOPRIGHT", popout, "TOPLEFT", -6, 0)
    end
    GameTooltip:SetHyperlink(link)
    GameTooltip:Show()
end

--- Shift-click, which in front of an auctioneer means "find me this".
---
--- The search bar is driven directly rather than through
--- HandleModifiedItemClick: the game's router sends a shift-click to the
--- chat box whenever one is open, and standing at the Auction House with
--- a shopping list in front of you, the chat box is not what was meant.
--- Away from an auctioneer the router is exactly right, so that is the
--- fallback -- and it is also the fallback while the name is still on
--- its way, since there is nothing to search for without one.
---
--- Both calls are guarded and pcall'd. SearchBar and StartSearch are
--- Blizzard's, not ours, and a shopping list that throws at the Auction
--- House is worse than one that quietly links to chat.
local function PopoutSearchAH(itemID, link)
    local name = GetItemName(itemID)
    local ah = _G.AuctionHouseFrame
    if name and ah and ah:IsShown() then
        local bar = ah.SearchBar
        local filled = false
        if bar and bar.SearchBox and bar.SearchBox.SetText then
            filled = pcall(bar.SearchBox.SetText, bar.SearchBox, name)
        elseif ah.SetSearchText then
            filled = pcall(ah.SetSearchText, ah, name)
        end
        if filled then
            if bar and bar.StartSearch then pcall(bar.StartSearch, bar) end
            return
        end
    end
    if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
end

--- One row, which is itself the hit area -- sized to the icon and the
--- name, as on the page, so the highlight hugs the item rather than
--- sweeping the full width of an empty window.
---
--- No tooltip on hover, unlike the page. This window is parked on top of
--- the Auction House and the cursor crosses it on the way to something
--- else; a tooltip that opens itself on the way past covers the auction
--- list underneath, repeatedly, for no one. So it is asked for -- click
--- -- and it then stays up until it is dismissed, which also means it
--- can be read without holding the mouse still.
local function PopRow(i)
    local r = popRows[i]
    if not r then
        r = CreateFrame("Button", nil, popout.body)
        r:SetHeight(POP_ROW_H)
        r:RegisterForClicks("LeftButtonUp")
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(POP_ICON, POP_ICON)
        r.icon:SetPoint("LEFT", 0, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", POP_ICON_GAP, 0)
        r.name:SetJustifyH("LEFT")
        -- Truncated, never wrapped. A name that wraps is a name drawn
        -- through the row below it.
        r.name:SetWordWrap(false)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.06)
        hl:SetBlendMode("ADD")
        popRows[i] = r
    end
    -- Exposed for Tools/loadcheck.py, like the page's section pool: the
    -- harness has no way down a frame's children, and what a row does
    -- when it is clicked is the whole of this window.
    ns.__consPopRows = popRows
    r:Show()
    return r
end

local function BuildPopout()
    if popout then return popout end

    local f = CreateFrame("Frame", "YippYappConsumablesPopout", UIParent,
                          "BackdropTemplate")
    f:SetSize(POP_W, 120)
    -- DIALOG, not HIGH.
    --
    -- HIGH is what the app frame itself sits at, and equal strata is
    -- settled by frame level -- which the app wins, so the popout opened
    -- UNDER the window it popped out of. DIALOG is where this file
    -- already puts its class dropdown and where the addon puts every
    -- other loose frame, and it clears both the app and the Auction
    -- House, which is the one thing this is meant to sit in front of.
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    -- Refused while pinned, rather than allowed and snapped back on the
    -- next redraw. A window that follows the cursor and then jumps home
    -- reads as broken; one that simply does not move reads as locked,
    -- which is what the checkbox underneath it says it is.
    f:SetScript("OnDragStart", function(s)
        if PopoutPinHost() then return end
        s:StartMoving()
    end)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        -- Saved against UIParent, never against the Auction House. This
        -- only runs when the window was loose, but GetPoint would still
        -- hand back whatever it is anchored to, and a position stored
        -- relative to a load-on-demand frame is one that cannot be
        -- restored at login.
        local db = PopoutDB()
        local point, _, rel, x, y = s:GetPoint()
        db.point, db.rel, db.x, db.y = point, rel, x, y
    end)
    ns.Widgets:Apply(f, "panel")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetSize(24, 24)
    -- Inside the panel. The template's art carries its own padding, so a
    -- positive offset hangs the button off the corner.
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() f:Hide() end)

    -- The pager, tucked in beside the close button rather than flanking
    -- the title. The title changes width with the view and the spec
    -- name, so arrows anchored to it would shuffle along the bar every
    -- time you pressed one.
    f.nextBtn = PopArrow(f, ">", 1)
    f.nextBtn:SetPoint("RIGHT", close, "LEFT", -2, 0)
    f.prevBtn = PopArrow(f, "<", -1)
    f.prevBtn:SetPoint("RIGHT", f.nextBtn, "LEFT", 0, 0)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("TOPLEFT", POP_PAD, -9)
    -- Stopped clear of the pager. Without a cap a long spec name runs
    -- under the arrows and out the side of the window.
    f.title:SetWidth(POP_W - POP_PAD - 64)
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(false)
    ns.ApplyTextShadow(f.title)

    f.body = CreateFrame("Frame", nil, f)
    f.body:SetPoint("TOPLEFT", POP_PAD, -30)
    f.body:SetPoint("BOTTOMRIGHT", -POP_PAD, 8)

    -- What a click does, said once at the bottom rather than left to be
    -- discovered.
    --
    -- The page above teaches neither gesture -- there, hovering is the
    -- tooltip and shift-click goes to chat -- so without a line saying
    -- so, the two useful things you can do in this window are invisible.
    -- Its wording follows the Auction House: shift-click means "search"
    -- in front of an auctioneer and "link" away from one, and claiming
    -- the wrong one is worse than claiming nothing.
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOMLEFT", POP_PAD, 8)
    f.hint:SetWidth(POP_W - POP_PAD * 2)
    f.hint:SetJustifyH("LEFT")
    f.hint:SetWordWrap(false)

    -- The unlock, on the window rather than in the options.
    --
    -- Same reasoning as the utility advisor's "Don't show this": the
    -- moment anyone wants this switch is the moment they have tried to
    -- drag the window and it would not move, and nobody goes looking
    -- through an options page for that. It is worded as the pin rather
    -- than as a lock so the ticked state -- which is the default -- says
    -- what it does instead of only saying what it forbids.
    --
    -- Shown only while the Auction House is open, because that is the
    -- only time it means anything: everywhere else the window is loose
    -- already, and a permanently greyed switch is worse than no switch.
    f.pin = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.pin:SetSize(20, 20)
    f.pin:SetPoint("BOTTOMLEFT", 8, 4)
    f.pin:SetHitRectInsets(0, -112, 0, 0)   -- the label is part of the target
    f.pinLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.pinLabel:SetPoint("LEFT", f.pin, "RIGHT", 1, 0)
    f.pinLabel:SetText("Pin to Auction House")
    f.pinLabel:SetTextColor(0.55, 0.55, 0.58)
    f.pin:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Pin to Auction House")
        GameTooltip:AddLine("Keeps this list against the top right of the "
            .. "Auction House. Untick it to drag the window wherever you "
            .. "want it -- it will stay there.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    f.pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.pin:SetScript("OnClick", function(s)
        local pinned = s:GetChecked() and true or false
        -- Unticking freezes the window where it already is, rather than
        -- releasing it to wherever it last sat loose. Otherwise the one
        -- gesture that means "let me move this" begins by throwing it
        -- across the screen -- and on a fresh install "loose" is the far
        -- right edge, nowhere near the corner it was just pinned to.
        if not pinned then PopoutFreeze() end
        PopoutDB().pinAH = pinned
        PopoutPlace()
    end)

    -- Escape closes it, like the class dropdown above and every other
    -- loose frame this addon puts on the screen.
    f:SetScript("OnShow", function()
        tinsert(UISpecialFrames, "YippYappConsumablesPopout")
    end)
    f:SetScript("OnHide", function()
        -- A tooltip opened by a click has no cursor to leave and so
        -- nothing else to close it: without this it outlives the window
        -- it belongs to and sits there on its own.
        PopTipHide()
        -- Closed by hand, by Escape, or by us. Whichever it was, this
        -- window is no longer one the Auction House is responsible for.
        popoutAuto = false
        for i = #UISpecialFrames, 1, -1 do
            if UISpecialFrames[i] == "YippYappConsumablesPopout" then
                table.remove(UISpecialFrames, i)
                break
            end
        end
    end)

    f:Hide()

    -- Assigned before placing it: PopoutPlace reads the upvalue, not the
    -- local, so anchoring the window before this line leaves it at the
    -- default position however the pin is set.
    popout = f
    PopoutPlace()
    return f
end

--- Redraw, if it is open. Cheap enough to call from anywhere that
--- changes what it should be showing.
function ns:RefreshConsumablesPopout()
    if not (popout and popout:IsShown()) then return end

    local tabLabel = "Consumables"
    for _, def in ipairs(TAB_DEFS) do
        if def.id == currentTab then tabLabel = def.label break end
    end
    local specName = selectedSpecID and GetSpecInfo(selectedSpecID) or ""
    popout.title:SetText(("|cff%s%s|r  |cff%s%s|r"):format(
        ns.Widgets:Hex("accent"), tabLabel,
        ns.Widgets:Hex("muted"), specName))

    local list = PopoutList()
    local y = 0
    for i, e in ipairs(list) do
        local r = PopRow(i)
        local indent = e.alt and 14 or 0
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", popout.body, "TOPLEFT", indent, y)
        r.icon:SetTexture(GetItemIcon(e.itemID) or 134400)

        local link = GetItemLink(e.itemID)
        -- Width cleared before measuring: GetStringWidth reports the
        -- text's natural width, but a FontString still carrying last
        -- render's cap would report that instead.
        r.name:SetWidth(0)
        r.name:SetText(link
            or ("|cffffffff" .. (GetItemName(e.itemID)
                or ("item:" .. e.itemID)) .. "|r"))
        local room = POP_W - POP_PAD * 2 - POP_ICON - POP_ICON_GAP - indent
        local textW = math.min(r.name:GetStringWidth() or 0, room)
        r.name:SetWidth(textW)
        r:SetWidth(POP_ICON + POP_ICON_GAP + math.max(textW, 20))

        local hover = link or ("item:" .. e.itemID)
        local itemID = e.itemID
        r:SetScript("OnClick", function(s)
            if IsModifiedClick("CHATLINK") or IsShiftKeyDown() then
                PopoutSearchAH(itemID, hover)
            elseif popTipID == itemID then
                PopTipHide()
            else
                PopTipShow(s, itemID, hover)
            end
        end)
        -- Re-anchored rather than dropped when the list redraws under an
        -- open tooltip -- which it does on its own, as the names arrive.
        if popTipID == itemID then PopTipShow(r, itemID, hover) end

        y = y - POP_ROW_H
    end
    for i = #list + 1, #popRows do popRows[i]:Hide() end

    -- The pin follows the Auction House, and its state follows the DB
    -- rather than whatever was last clicked -- the box is the readout as
    -- well as the switch, and the two have to agree after a /reload.
    local atAH = AuctionHouseOpen()
    popout.pin:SetChecked(PopoutDB().pinAH ~= false)
    popout.pin:SetShown(atAH)
    popout.pinLabel:SetShown(atAH)

    popout.hint:SetText(atAH
        and "Click for details   Shift-click to search"
        or "Click for details   Shift-click to link")
    popout.hint:ClearAllPoints()
    popout.hint:SetPoint("BOTTOMLEFT", POP_PAD,
        8 + (atAH and POP_FOOT_H or 0))

    -- Sized to its contents: the title band, the rows, the hint, the
    -- bottom padding, and the pin's band when that is showing. A fixed
    -- height would be empty for Gems and short for Consumables.
    popout:SetHeight(math.max(
        -y + 30 + POP_HINT_H + 8 + (atAH and POP_FOOT_H or 0), 64))
end

function ns:ToggleConsumablesPopout()
    local f = BuildPopout()
    if f:IsShown() then
        f:Hide()
        return
    end
    -- Opened by hand until something says otherwise. The Auction House
    -- path below sets this back to true immediately after its own call,
    -- which is the only way it becomes true.
    popoutAuto = false

    -- Whose consumables, if nobody has said yet.
    --
    -- The page seeds this from its own OnShow, and until this window
    -- could open itself that was enough: the only route here was the
    -- Popout button, which is ON the page, so the page had been shown.
    -- The Auction House route has no such guarantee -- walk to an
    -- auctioneer in a session where the Consumables page was never
    -- opened and selectedSpecID is still nil, GetConsumableKey returns
    -- nil with it, and the window comes up correctly sized around
    -- nothing at all.
    if not selectedSpecID then
        selectedClassFile, selectedSpecID = GetPlayerClassAndSpec()
    end
    -- Names may not be cached yet if the page has never been drawn for
    -- this spec; CacheItem re-fires RefreshConsumables when they land,
    -- which reaches the popout through the hook at the end of it.
    local data = ns.ConsumablesDB and ns.ConsumablesDB[GetConsumableKey() or ""]
    for _, e in ipairs(PopoutList()) do
        local _ = data and CacheItem(e.itemID)
    end
    -- Placed before it is shown, not only when it is built. Opening this
    -- by hand while standing at an auctioneer has to pin it too, and
    -- BuildPopout's own call runs once in a session.
    PopoutPlace()
    f:Show()
    -- Above anything else already at DIALOG, including a dropdown left
    -- open behind it.
    f:Raise()
    ns:RefreshConsumablesPopout()
end

------------------------------------------------------------
-- The Auction House
--
-- The window that exists for the Auction House did not know when the
-- Auction House was open, so every visit started by opening the app,
-- finding the Consumables page and pressing Popout. This closes that
-- loop: walk up to an auctioneer and the list is already beside it.
--
-- Default on, like the utility advisor and unlike Open on Login. The
-- difference is that this is answering something you just did -- you
-- walked to a vendor that sells exactly what this lists -- rather than
-- putting a window on screen because the game happened to load.
------------------------------------------------------------

--- The Auction House opened (or closed). Returns whether this opened the
--- window itself.
---
--- A named function rather than the body of the handler below, so the
--- load harness can put both edges through it without an auctioneer --
--- the same reason ns.OpenOnLoginIfWanted is one.
function ns.ConsumablesPopoutAtAuctionHouse(open)
    if not open then
        local wasAuto = popoutAuto
        if popout and wasAuto then popout:Hide() end
        -- Re-placed even when it stays up. An anchor does not follow its
        -- target into hiding, so a pinned window left alone would sit
        -- wherever the Auction House used to be, still anchored to a
        -- frame nobody can see -- and the next thing to move it would be
        -- a drag that the pin refuses.
        PopoutPlace()
        ns:RefreshConsumablesPopout()
        return false
    end

    -- Off in the options: no window of our own, but a window the player
    -- opened by hand still gets pinned. The setting is about opening
    -- uninvited, not about where an invited window sits.
    if ns.ModuleEnabled and not ns.ModuleEnabled("consumablesAtAH") then
        PopoutPlace()
        ns:RefreshConsumablesPopout()
        return false
    end

    local f = BuildPopout()
    if f:IsShown() then
        -- Already up, so nothing to open -- but it was placed loose and
        -- has to move onto the Auction House now, and grow the pin band
        -- it did not have a moment ago.
        PopoutPlace()
        ns:RefreshConsumablesPopout()
        return false
    end

    ns:ToggleConsumablesPopout()
    -- After the call, not before: ToggleConsumablesPopout clears this on
    -- the way through, on the assumption that a hand opened it.
    popoutAuto = true
    ns:RefreshConsumablesPopout()
    return true
end

end

------------------------------------------------------------
-- The Auction House watcher
--
-- OUTSIDE ns:CreateConsumablesFrame, and being outside it is the whole
-- reason this sits down here rather than beside the popout it drives.
--
-- Everything above -- the popout, its rows, ns.ToggleConsumablesPopout,
-- ns.ConsumablesPopoutAtAuctionHouse -- is declared INSIDE that
-- function, which does not run until the Consumables page is first
-- built. A CreateFrame():RegisterEvent up there registers nothing until
-- you have already opened the page by hand, which is precisely the trip
-- this feature exists to save. It shipped that way once, and the symptom
-- was "it only appears after I open it myself".
--
-- The events rather than a hook on AuctionHouseFrame, for the mirror of
-- the same reason: Blizzard_AuctionHouseUI is load-on-demand, so at
-- login there is no frame to hook and a hook installed then would never
-- be installed at all.
------------------------------------------------------------
do
    local watch = CreateFrame("Frame")
    watch:RegisterEvent("AUCTION_HOUSE_SHOW")
    watch:RegisterEvent("AUCTION_HOUSE_CLOSED")

    --- Build the page if nobody has yet, so the popout it owns exists.
    ---
    --- Safe to call cold and safe to call twice: CreateConsumablesFrame
    --- returns immediately once ns.ConsumablesFrame is set, and the shell
    --- skips its own create for the same reason. So the first Auction
    --- House visit pays what opening the page would have cost, and every
    --- visit after it pays nothing.
    local function Ready()
        if ns.ConsumablesPopoutAtAuctionHouse then return true end
        if not ns.CreateConsumablesFrame then return false end
        -- Loud on failure, and pcall for exactly that reason. This runs
        -- inside a C_Timer callback, and an error thrown in one of those
        -- is swallowed whole for anyone who has not turned script errors
        -- on -- which is everyone, by default. A feature that silently
        -- does nothing is the hardest kind of bug to report, so it says
        -- so instead of leaving the player to guess.
        local ok, err = pcall(ns.CreateConsumablesFrame, ns)
        if not ok then
            print("|cffff5555YippYapp:|r could not build the consumables page: "
                  .. tostring(err))
            return false
        end
        return ns.ConsumablesPopoutAtAuctionHouse ~= nil
    end

    -- Both exposed for /yh ah, which walks this path and says what it
    -- found. Every step of it is invisible from the outside -- an event
    -- that may never have been registered, a page that may not be built,
    -- a timer callback nobody can see fail -- and "nothing happened" is
    -- not a report anyone can act on.
    ns.ConsumablesAHWatcher = watch
    ns.ConsumablesAHReady = Ready

    watch:SetScript("OnEvent", function(_, event)
        if event == "AUCTION_HOUSE_SHOW" then
            -- Deferred a frame. AUCTION_HOUSE_SHOW is what causes that
            -- addon to load and its frame to be shown, and the order of
            -- those against this handler is not ours to decide -- read
            -- too early, AuctionHouseFrame is either absent or not yet
            -- shown, and the pin falls back to the loose position.
            C_Timer.After(0, function()
                if Ready() then ns.ConsumablesPopoutAtAuctionHouse(true) end
            end)
        elseif ns.ConsumablesPopoutAtAuctionHouse then
            -- Nothing to build on the way out: a page that was never made
            -- has no popout to put away.
            ns.ConsumablesPopoutAtAuctionHouse(false)
        end
    end)
end
