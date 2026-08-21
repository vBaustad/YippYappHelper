local _, ns = ...

------------------------------------------------------------
-- Dashboard: main hub opened by /yh
------------------------------------------------------------
local DASH_WIDTH = 320
local DASH_HEIGHT = 280
local BUTTON_WIDTH = 260
local BUTTON_HEIGHT = 44
local BUTTON_SPACING = 6

local dashboard = CreateFrame("Frame", "YippYappDashboard", UIParent, "BackdropTemplate")
dashboard:SetSize(DASH_WIDTH, DASH_HEIGHT)
dashboard:SetPoint("CENTER")
dashboard:SetMovable(true)
dashboard:EnableMouse(true)
dashboard:RegisterForDrag("LeftButton")
dashboard:SetScript("OnDragStart", dashboard.StartMoving)
dashboard:SetScript("OnDragStop", dashboard.StopMovingOrSizing)
dashboard:SetClampedToScreen(true)
dashboard:SetFrameStrata("HIGH")
dashboard:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
dashboard:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
dashboard:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
dashboard:Hide()
ns.Dashboard = dashboard

-- ESC to close
dashboard:SetScript("OnShow", function()
    tinsert(UISpecialFrames, "YippYappDashboard")
end)
dashboard:SetScript("OnHide", function()
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "YippYappDashboard" then
            table.remove(UISpecialFrames, i)
            break
        end
    end
end)

-- Icon
local dashIcon = dashboard:CreateTexture(nil, "ARTWORK")
-- Full-bleed art, so the box size is the octagon. Matches the app header.
-- No texcoord crop here or it would cut the octagon's flat sides.
dashIcon:SetSize(28, 28)
dashIcon:SetPoint("TOPLEFT", 12, -8)
dashIcon:SetTexture("Interface\\AddOns\\YippYappHelper\\Media\\YippYappHelper")

-- Title
local title = dashboard:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("LEFT", dashIcon, "RIGHT", 6, 2)
title:SetText("|cff00ff00YippYapp Helper|r")

-- Subtitle
local subtitle = dashboard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
subtitle:SetPoint("LEFT", dashIcon, "RIGHT", 6, -10)
subtitle:SetTextColor(0.5, 0.5, 0.5)
subtitle:SetText(ns.SEASON_NAME or "Midnight Season 2")

-- Close button
local closeBtn = CreateFrame("Button", nil, dashboard, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -2, -2)

-- Settings button, left of close, styled like rest of app
local settingsBtn = CreateFrame("Button", nil, dashboard, "BackdropTemplate")
settingsBtn:SetSize(70, 20)
settingsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, -1)
settingsBtn:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 0, right = 0, top = 0, bottom = 0 },
})
settingsBtn:SetBackdropColor(0.10, 0.10, 0.10, 0.9)
settingsBtn:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
local sLabel = settingsBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sLabel:SetPoint("CENTER", 0, 0)
sLabel:SetText("Settings")
sLabel:SetTextColor(0.85, 0.85, 0.85)
settingsBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(0.0, 0.8, 1.0, 1)
    sLabel:SetTextColor(1, 1, 1)
end)
settingsBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    sLabel:SetTextColor(0.85, 0.85, 0.85)
end)
settingsBtn:SetScript("OnClick", function()
    dashboard:Hide()
    if ns.InterruptsSettings and ns.InterruptsSettings.Open then
        ns.InterruptsSettings:Open()
    end
end)
ns.DashboardSettingsButton = settingsBtn

-- Divider
local div = dashboard:CreateTexture(nil, "ARTWORK")
div:SetHeight(1)
div:SetPoint("TOPLEFT", 12, -44)
div:SetPoint("TOPRIGHT", -12, -44)
div:SetColorTexture(0.5, 0.5, 0.5, 0.5)

------------------------------------------------------------
-- Button factory
------------------------------------------------------------
local buttons = {}

local function CreateDashButton(label, description, color, onClick)
    local idx = #buttons + 1
    local yOffset = -52 - (idx - 1) * (BUTTON_HEIGHT + BUTTON_SPACING)

    local btn = CreateFrame("Button", nil, dashboard, "BackdropTemplate")
    btn:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    btn:SetPoint("TOP", 0, yOffset)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    btn:SetBackdropColor(0.12, 0.12, 0.12, 1)
    btn:SetBackdropBorderColor(color[1], color[2], color[3], 0.6)

    local btnLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btnLabel:SetPoint("TOPLEFT", 12, -8)
    btnLabel:SetText(label)

    local btnDesc = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btnDesc:SetPoint("TOPLEFT", btnLabel, "BOTTOMLEFT", 0, -2)
    btnDesc:SetTextColor(0.55, 0.55, 0.55)
    btnDesc:SetText(description)

    -- Hover effects
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.18, 0.18, 0.18, 1)
        self:SetBackdropBorderColor(color[1], color[2], color[3], 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.12, 0.12, 0.12, 1)
        self:SetBackdropBorderColor(color[1], color[2], color[3], 0.6)
    end)

    btn:SetScript("OnClick", function()
        dashboard:Hide()
        onClick()
    end)

    table.insert(buttons, btn)
    return btn
end

------------------------------------------------------------
-- Dashboard buttons
------------------------------------------------------------
CreateDashButton(
    "|cff00ff00Gear Upgrades|r",
    "Crest advisor and upgrade recommendations",
    { 0.0, 1.0, 0.3 },
    function()
        if ns.MainFrame then
            ns:RefreshAllSlots()
            ns:RefreshCrests()
            ns.MainFrame:Show()
        end
    end
)

CreateDashButton(
    "|cff00aaffRaid|r",
    "Tier tracker, L'ura Runes, raid overview",
    { 0.0, 0.67, 1.0 },
    function()
        if ns.RaidFrame then
            if GetNumGroupMembers() > 0 then
                ns:ScanRaid()
            else
                ns.RaidFrame:Show()
            end
        end
    end
)

CreateDashButton(
    "|cffffff00Progression Overview|r",
    "Gear sources, crests, and season reference",
    { 1.0, 1.0, 0.0 },
    function()
        if ns.CreateProgressionFrame then ns:CreateProgressionFrame() end
        if ns.ProgressionFrame then
            ns.ProgressionFrame:Show()
        end
    end
)

CreateDashButton(
    "|cff00ccffLoot Browser|r",
    "Find loot by slot, spec, and stats",
    { 0.0, 0.8, 1.0 },
    function()
        if not ns.LootBrowserFrame then
            ns:CreateLootBrowserFrame()
        end
        ns:LootBrowser_DetectSpec()
        ns.LootBrowserFrame:Show()
        ns:LootBrowser_ShowPage()
    end
)

CreateDashButton(
    "|cffff00ffConsumables|r",
    "Enchants, gems, flasks, and food for your spec",
    { 1.0, 0.0, 1.0 },
    function()
        if ns.ConsumablesFrame then
            ns:RefreshConsumables()
            ns.ConsumablesFrame:Show()
        end
    end
)

CreateDashButton(
    "|cff88ccffTeleports|r",
    "Dungeon and raid teleports",
    { 0.53, 0.8, 1.0 },
    function()
        if ns.TeleportFrame then
            ns.TeleportFrame:Show()
            ns:RefreshTeleports()
        end
    end
)

CreateDashButton(
    "|cff00d4ffMythic+|r",
    "Keystones, ratings, and dungeon scores",
    { 0.0, 0.83, 1.0 },
    function()
        if ns.MythicPlusFrame then
            ns.MythicPlusFrame:Show()
            ns:RefreshMythicPlus()
        end
    end
)

-- Resize dashboard to fit buttons
local totalHeight = 52 + #buttons * (BUTTON_HEIGHT + BUTTON_SPACING) + 12
dashboard:SetHeight(totalHeight)

------------------------------------------------------------
-- Toggle
------------------------------------------------------------
function ns:ToggleDashboard()
    if dashboard:IsShown() then
        dashboard:Hide()
    else
        dashboard:Show()
    end
end
