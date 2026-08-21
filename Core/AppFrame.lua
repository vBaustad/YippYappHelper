local _, ns = ...

------------------------------------------------------------
-- AppFrame: the window that opened before the shell existed.
--
-- Core\Shell.lua replaced it. Both ns:OpenMain and ns:OpenTo reach for
-- the shell first and only fall back here when it is absent, which
-- happens in exactly one situation: somebody who updated the addon and
-- reloaded rather than restarting the client, so their .toc predates
-- Core\Shell.lua and that file is not loaded at all. "Nothing happens"
-- is the worst possible answer to a key press, so the fallback stays.
--
-- What did not stay is the cost of it. This file built its entire home
-- dashboard at load -- 64 frames and 209 regions, the largest single
-- contributor in the addon -- for a window that, in any session where
-- the shell exists, cannot be opened by any means. Now it builds
-- nothing at all in that case.
--
-- The guard tests what the callers test. If ns:OpenMain and ns:OpenTo
-- would both choose the shell, there is no path to this window, and the
-- three conditions have to stay in agreement: a shell that can Toggle
-- and Open is a shell that has taken over both doors.
--
-- Everything published here -- ns.AppFrame, ns.ShowAppPage,
-- ns.ToggleApp, ns.currentAppPage, ns._refreshDashboard -- is read
-- behind an `if ns.X then` by every caller, so absent reads as
-- "this build has no old window", which is the truth.
-- ns:ToggleDashboard is not lost either: Integrations\Dashboard.lua
-- loads after this file and defines its own.
------------------------------------------------------------
if ns.Shell and ns.Shell.Toggle and ns.Shell.Open then return end

------------------------------------------------------------
-- AppFrame: unified navigation shell for YippYapp Helper
------------------------------------------------------------
local FRAME_W, FRAME_H = ns:GetAppFrameSize()
local PAD       = 14
local HEADER_H  = 32
-- Gap between the header band and the content panel below it. The header
-- icon centres on the combined band, so both live here.
local HEADER_GAP = 4
local ICON_SIZE = 28
local CARD_GAP  = 14
local CW        = FRAME_W - PAD * 2

------------------------------------------------------------
-- Main frame
------------------------------------------------------------
local app = CreateFrame("Frame", "YippYappApp", UIParent, "BackdropTemplate")
app:SetSize(FRAME_W, FRAME_H)
app:SetPoint("CENTER")
app:SetMovable(true)
app:EnableMouse(true)
app:RegisterForDrag("LeftButton")
app:SetScript("OnDragStart", app.StartMoving)
app:SetScript("OnDragStop", app.StopMovingOrSizing)
app:SetClampedToScreen(true)
app:SetFrameStrata("HIGH")
ns.Widgets:Apply(app, "panel")
ns.SmoothFrame(app)
app:Hide()
ns.AppFrame = app

-- ESC to close (handled locally rather than via UISpecialFrames to avoid
-- ADDON_ACTION_BLOCKED taint errors when Blizzard's secure close iterator
-- hits this frame mid-combat).
-- ESC handled via UISpecialFrames, but only registered out of combat to
-- avoid the secure-close taint we hit earlier. Keyboard isn't captured by
-- the frame itself, so chat/edit-box typing is not blocked.
local function registerSpecialFrame()
    for _, n in ipairs(UISpecialFrames) do if n == "YippYappApp" then return end end
    tinsert(UISpecialFrames, "YippYappApp")
end
local function unregisterSpecialFrame()
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "YippYappApp" then table.remove(UISpecialFrames, i); break end
    end
end
local combatGuard = CreateFrame("Frame")
combatGuard:RegisterEvent("PLAYER_REGEN_DISABLED")
combatGuard:RegisterEvent("PLAYER_REGEN_ENABLED")
combatGuard:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        unregisterSpecialFrame()
    elseif event == "PLAYER_REGEN_ENABLED" and app:IsShown() then
        registerSpecialFrame()
    end
end)
app:HookScript("OnShow", function() if not InCombatLockdown() then registerSpecialFrame() end end)
app:HookScript("OnHide", function() unregisterSpecialFrame() end)
app:SetScript("OnHide", function()
    -- Close any open popups
    if YippYappProfileDropdown then YippYappProfileDropdown:Hide() end
    if YippYappPIPicker then YippYappPIPicker:Hide() end
    -- Restore any embedded sub-panel to standalone mode
    if ns.ShowAppPage then
        ns:ShowAppPage("home")
    end
end)

------------------------------------------------------------
-- Header overlay (always renders above sub-panels)
------------------------------------------------------------
local headerOverlay = CreateFrame("Frame", nil, app)
headerOverlay:SetAllPoints(app)
headerOverlay:SetFrameLevel(app:GetFrameLevel() + 100)

------------------------------------------------------------
-- Custom close button (matches ReadyCheck / Settings styling)
------------------------------------------------------------
local closeBtn = CreateFrame("Button", nil, headerOverlay, "BackdropTemplate")
closeBtn:SetSize(20, 20)
closeBtn:SetPoint("RIGHT", app, "TOPRIGHT", -8, -(HEADER_H + HEADER_GAP) / 2)
ns.Widgets:Apply(closeBtn, "row")
local closeLabel = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
closeLabel:SetPoint("CENTER", 0, 0)
closeLabel:SetText("×")
closeLabel:SetTextColor(0.85, 0.85, 0.85)

closeBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(0.0, 0.8, 1.0, 1)
    closeLabel:SetTextColor(1, 1, 1)
end)
closeBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    closeLabel:SetTextColor(0.85, 0.85, 0.85)
end)
closeBtn:SetScript("OnClick", function() app:Hide() end)

------------------------------------------------------------
-- Settings (gear) button, left of close
------------------------------------------------------------
local settingsBtn = CreateFrame("Button", nil, headerOverlay, "BackdropTemplate")
settingsBtn:SetSize(70, 20)
settingsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
ns.Widgets:Apply(settingsBtn, "row")
local settingsLabel = settingsBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
settingsLabel:SetPoint("CENTER", 0, 0)
settingsLabel:SetText("Settings")
settingsLabel:SetTextColor(0.85, 0.85, 0.85)
settingsBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(0.0, 0.8, 1.0, 1)
    settingsLabel:SetTextColor(1, 1, 1)
end)
settingsBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    settingsLabel:SetTextColor(0.85, 0.85, 0.85)
end)
settingsBtn:SetScript("OnClick", function()
    -- Settings open in Blizzard's options window, so step out of the way
    -- rather than stacking two full-screen panels.
    app:Hide()
    if ns.InterruptsSettings and ns.InterruptsSettings.Open then
        ns.InterruptsSettings:Open()
    end
end)

------------------------------------------------------------
-- "Buy me a coffee" link (placed on the home dashboard; see below)
------------------------------------------------------------
local BMC_URL = "buymeacoffee.com/vbaustad"

StaticPopupDialogs["YIPPYAPP_BMC"] = StaticPopupDialogs["YIPPYAPP_BMC"] or {
    text = "Thanks for using YippYapp Helper!\nCopy the link below if you'd like to buy me a coffee.",
    button1 = CLOSE,
    hasEditBox = true,
    editBoxWidth = 260,
    OnShow = function(self)
        -- Modern retail uses `self.EditBox` (capital); older builds exposed
        -- it lowercase. Fall back gracefully so this works on both.
        local eb = self.EditBox or self.editBox
        if not eb then return end
        eb:SetText(BMC_URL)
        eb:HighlightText()
        eb:SetFocus()
    end,
    EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Home mode elements
local homeIcon = headerOverlay:CreateTexture(nil, "ARTWORK")
-- Full-bleed art, so the box size is the octagon size. The air around it
-- comes from the band, not the texture. No texcoord crop — trimming would
-- cut the flat sides off the octagon.
homeIcon:SetSize(ICON_SIZE, ICON_SIZE)
-- Centred on the band between the window's top edge and the content panel,
-- not on HEADER_H alone. The panel sits 4px below the header, so centring
-- on the header midline leaves the icon looking like it rides high.
homeIcon:SetPoint("LEFT", app, "TOPLEFT", PAD, -(HEADER_H + HEADER_GAP) / 2)
homeIcon:SetTexture("Interface\\AddOns\\YippYappHelper\\Media\\YippYappHelper")

local homeTitle = headerOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
homeTitle:SetPoint("LEFT", homeIcon, "RIGHT", 6, 0)
homeTitle:SetText("|cff00ff00YippYapp Helper|r")
ns.ApplyTextShadow(homeTitle)

local homeSub = headerOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
homeSub:SetPoint("LEFT", homeTitle, "RIGHT", 8, 0)
homeSub:SetTextColor(unpack(ns.COLORS.TEXT_TERTIARY))
homeSub:SetText(ns.SEASON_NAME or "Midnight Season 2")
ns.ApplyTextShadow(homeSub)


-- Sub-page mode: back button + page title
local backBtn = CreateFrame("Button", nil, headerOverlay, "BackdropTemplate")
backBtn:SetSize(60, 22)
backBtn:SetPoint("LEFT", app, "TOPLEFT", PAD, -(HEADER_H + HEADER_GAP) / 2)
ns.Widgets:Apply(backBtn, "row")
local backFs = backBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
backFs:SetPoint("CENTER")
backFs:SetText("|cffaaaaaa< Back|r")

backBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.18, 0.18, 0.18, 1)
    self:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
end)
backBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.12, 0.12, 0.12, 1)
    self:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
end)
backBtn:Hide()

local pageTitle = headerOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
pageTitle:SetPoint("LEFT", backBtn, "RIGHT", 8, 0)
pageTitle:Hide()

------------------------------------------------------------
-- Page containers (content area below header)
------------------------------------------------------------
local pages = {}
local currentPage = "home"

local function MakePage(id)
    local c = CreateFrame("Frame", nil, app)
    c:SetPoint("TOPLEFT", 0, -HEADER_H)
    c:SetPoint("BOTTOMRIGHT", 0, 0)
    c:Hide()
    -- Inner bordered panel for consistent darker look across all pages
    -- (matches the settings page style).
    local inner = CreateFrame("Frame", nil, c, "BackdropTemplate")
    inner:SetPoint("TOPLEFT", 0, -10)
    inner:SetPoint("BOTTOMRIGHT", 0, 0)
    ns.Widgets:Apply(inner, "panel")
    inner:SetFrameLevel(c:GetFrameLevel())
    c.inner = inner
    pages[id] = c
    return c
end

-- Home page
local homePage = CreateFrame("Frame", nil, app)
homePage:SetPoint("TOPLEFT", 0, -HEADER_H)
homePage:SetPoint("BOTTOMRIGHT", 0, 0)
local homeInner = CreateFrame("Frame", nil, homePage, "BackdropTemplate")
homeInner:SetPoint("TOPLEFT", 0, -HEADER_GAP)
homeInner:SetPoint("BOTTOMRIGHT", 0, 0)
ns.Widgets:Apply(homeInner, "panel")
homeInner:SetFrameLevel(homePage:GetFrameLevel())

------------------------------------------------------------
-- Buy me a coffee (bottom-right of dashboard, subtle)
------------------------------------------------------------
-- Square cup logo (3200x3200 source) — display compact at 26x26.
local bmcBtn = CreateFrame("Button", nil, homePage)
bmcBtn:SetSize(26, 26)
bmcBtn:SetPoint("BOTTOMRIGHT", homePage, "BOTTOMRIGHT", -12, 10)

local bmcTex = bmcBtn:CreateTexture(nil, "ARTWORK")
bmcTex:SetAllPoints()
bmcTex:SetTexture("Interface\\AddOns\\YippYappHelper\\Media\\bmc-logo-yellow")
bmcTex:SetAlpha(0.65)

local bmcLabel = homePage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
bmcLabel:SetPoint("RIGHT", bmcBtn, "LEFT", -6, 0)
bmcLabel:SetText("|cff888888if you want to support|r")

bmcBtn:SetScript("OnEnter", function(self)
    bmcTex:SetAlpha(1)
    bmcLabel:SetText("|cffffc840if you want to support|r")
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Buy me a coffee", 1, 0.85, 0.2)
    GameTooltip:AddLine(BMC_URL, 0.7, 0.7, 0.7)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click to copy the link.", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end)
bmcBtn:SetScript("OnLeave", function()
    bmcTex:SetAlpha(0.55)
    bmcLabel:SetText("|cff888888if you want to support|r")
    GameTooltip:Hide()
end)
bmcBtn:SetScript("OnClick", function() StaticPopup_Show("YIPPYAPP_BMC") end)
pages.home = homePage

MakePage("gear")
MakePage("raid")
MakePage("progression")
MakePage("loot")
MakePage("consumables")
MakePage("mythicplus")
MakePage("teleports")
MakePage("trinkets")
MakePage("bis")

------------------------------------------------------------
-- Page navigation
------------------------------------------------------------
local PAGE_INFO = {
    gear        = { title = "|cff00ff00Gear Upgrades|r" },
    raid        = { title = "|cff00aaffRaid|r" },
    progression = { title = "|cffffff00Progression|r" },
    loot        = { title = "|cff00ccffLoot Browser|r" },
    consumables = { title = "|cffff00ffConsumables|r" },
    mythicplus  = { title = "|cff00d4ffMythic+|r" },
    teleports   = { title = "|cff88ccffTeleports|r" },
    trinkets    = { title = "|cff70d0ffTrinkets|r" },
    bis         = { title = "|cff73ff8cBest in Slot|r" },
}

local CONTENT_W = FRAME_W
local CONTENT_H = FRAME_H - HEADER_H

-- Restore a sub-panel's strata to standalone mode
local function RestoreFrameLevel(f)
    -- Gear panel uses MEDIUM so it stays behind the app; others use HIGH
    if f == ns.MainFrame then
        f:SetFrameStrata("MEDIUM")
    else
        f:SetFrameStrata("HIGH")
    end
end

local function LeaveCurrentPage()
    if currentPage == "gear" and ns.MainFrame then
        ns.MainFrame.inAppMode = nil
        ns.MainFrame:Hide()
        ns.MainFrame:SetParent(UIParent)
        RestoreFrameLevel(ns.MainFrame)
        if ns.SetGearAppMode then ns:SetGearAppMode(false) end
    elseif currentPage == "raid" and ns.RaidFrame then
        ns.RaidFrame.inAppMode = nil
        ns.RaidFrame:Hide()
        ns.RaidFrame:SetParent(UIParent)
        RestoreFrameLevel(ns.RaidFrame)
        if ns.SetRaidAppMode then ns:SetRaidAppMode(false) end
    elseif currentPage == "progression" and ns.ProgressionFrame then
        ns.ProgressionFrame.inAppMode = nil
        ns.ProgressionFrame:Hide()
        ns.ProgressionFrame:SetParent(UIParent)
        RestoreFrameLevel(ns.ProgressionFrame)
        if ns.SetProgressionAppMode then ns:SetProgressionAppMode(false) end
    elseif currentPage == "loot" and ns.LootBrowserFrame then
        ns.LootBrowserFrame.inAppMode = nil
        ns.LootBrowserFrame:Hide()
        ns.LootBrowserFrame:SetParent(UIParent)
        RestoreFrameLevel(ns.LootBrowserFrame)
        if ns.SetLootBrowserAppMode then ns:SetLootBrowserAppMode(false) end
    elseif currentPage == "consumables" and ns.ConsumablesFrame then
        ns.ConsumablesFrame.inAppMode = nil
        ns.ConsumablesFrame:Hide()
        ns.ConsumablesFrame:SetParent(UIParent)
        RestoreFrameLevel(ns.ConsumablesFrame)
        if ns.SetConsumablesAppMode then ns:SetConsumablesAppMode(false) end
    elseif currentPage == "mythicplus" and ns.MythicPlusFrame then
        ns.MythicPlusFrame.inAppMode = nil
        ns.MythicPlusFrame:Hide()
        ns.MythicPlusFrame:SetParent(UIParent)
        RestoreFrameLevel(ns.MythicPlusFrame)
        if ns.SetMythicPlusAppMode then ns:SetMythicPlusAppMode(false) end
    elseif currentPage == "teleports" and ns.TeleportFrame then
        ns.TeleportFrame.inAppMode = nil
        ns.TeleportFrame:Hide()
        ns.TeleportFrame:SetParent(UIParent)
        RestoreFrameLevel(ns.TeleportFrame)
        if ns.SetTeleportAppMode then ns:SetTeleportAppMode(false) end
    end
end

-- Normalize a sub-panel's strata/level to sit inside the app frame
-- but below the header overlay (which is at +100)
local function NormalizeFrameLevel(f)
    f:SetFrameStrata(app:GetFrameStrata())
    f:SetFrameLevel(app:GetFrameLevel() + 5)
end

local function EnterPage(id)
    if id == "gear" and ns.MainFrame then
        local f = ns.MainFrame
        f.inAppMode = true
        if ns.SetGearAppMode then ns:SetGearAppMode(true, CONTENT_W) end
        f:SetParent(pages.gear)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", pages.gear, "TOPLEFT", 0, 0)
        NormalizeFrameLevel(f)
        f:Show()
        if ns.RefreshAllSlots then ns:RefreshAllSlots() end
        if ns.RefreshCrests then ns:RefreshCrests() end
        if ns.RefreshSuggestions then ns:RefreshSuggestions() end

    elseif id == "raid" and ns.RaidFrame then
        local f = ns.RaidFrame
        f.inAppMode = true
        if ns.SetRaidAppMode then ns:SetRaidAppMode(true, CONTENT_W, CONTENT_H) end
        f:SetParent(pages.raid)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", pages.raid, "TOPLEFT", 0, 0)
        NormalizeFrameLevel(f)
        f:Show()
        if ns.RefreshRaidOverview then ns:RefreshRaidOverview() end

    elseif id == "progression" then
        -- Same shape as the loot branch below: the page builds itself
        -- on first open now, so this has to ask for it rather than test
        -- for it.
        if not ns.ProgressionFrame and ns.CreateProgressionFrame then
            ns:CreateProgressionFrame()
        end
        local f = ns.ProgressionFrame
        f.inAppMode = true
        f:SetParent(pages.progression)
        f:ClearAllPoints()
        -- Progression has its own ~34px internal top margin (CONTENT_TOP);
        -- shift the frame up by 20 so the content lines up just below the
        -- inner panel's top border without creating empty space.
        f:SetPoint("TOPLEFT", pages.progression, "TOPLEFT", 0, 20)
        f:SetPoint("BOTTOMRIGHT", pages.progression, "BOTTOMRIGHT", 0, 0)
        NormalizeFrameLevel(f)
        f:Show()
        if ns.SetProgressionAppMode then ns:SetProgressionAppMode(true) end

    elseif id == "loot" then
        if not ns.LootBrowserFrame then
            ns:CreateLootBrowserFrame()
        end
        local f = ns.LootBrowserFrame
        f.inAppMode = true
        if ns.SetLootBrowserAppMode then ns:SetLootBrowserAppMode(true, CONTENT_W, CONTENT_H) end
        f:SetParent(pages.loot)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", pages.loot, "TOPLEFT", 0, 0)
        NormalizeFrameLevel(f)
        f:Show()
        ns:LootBrowser_DetectSpec()
        ns:LootBrowser_ShowPage()

    elseif id == "consumables" and ns.ConsumablesFrame then
        local f = ns.ConsumablesFrame
        f.inAppMode = true
        if ns.SetConsumablesAppMode then ns:SetConsumablesAppMode(true, CONTENT_W, CONTENT_H) end
        f:SetParent(pages.consumables)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", pages.consumables, "TOPLEFT", 0, 0)
        NormalizeFrameLevel(f)
        f:Show()
        if ns.RefreshConsumables then ns:RefreshConsumables() end

    elseif id == "mythicplus" and ns.MythicPlusFrame then
        local f = ns.MythicPlusFrame
        f.inAppMode = true
        if ns.SetMythicPlusAppMode then ns:SetMythicPlusAppMode(true, CONTENT_W, CONTENT_H) end
        f:SetParent(pages.mythicplus)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", pages.mythicplus, "TOPLEFT", 0, 0)
        NormalizeFrameLevel(f)
        f:Show()
        if ns.RefreshMythicPlus then ns:RefreshMythicPlus() end

    elseif id == "trinkets" then
        -- Mounted rather than built: the shell owns the sub-tab strip
        -- and the filter strip, and hands the page only its content
        -- region. Mount is idempotent, so this is also the refresh.
        if ns.Shell then
            ns.Shell:Mount("trinkets", pages.trinkets.inner or pages.trinkets)
        end

    elseif id == "bis" then
        if ns.BisUI and ns.BisUI.BuildInto then
            ns.BisUI:BuildInto(pages.bis)
        end

    elseif id == "teleports" and ns.TeleportFrame then
        local f = ns.TeleportFrame
        f.inAppMode = true
        if ns.SetTeleportAppMode then ns:SetTeleportAppMode(true, CONTENT_W, CONTENT_H) end
        f:SetParent(pages.teleports)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", pages.teleports, "TOPLEFT", 0, 0)
        NormalizeFrameLevel(f)
        f:Show()
        if ns.RefreshTeleports then ns:RefreshTeleports() end
    end
end

function ns:ShowAppPage(id)
    LeaveCurrentPage()

    for pageId, page in pairs(pages) do
        if pageId == id then
            page:Show()
        else
            page:Hide()
        end
    end

    currentPage = id
    ns.currentAppPage = id

    if id == "home" then
        homeIcon:Show()
        homeTitle:Show()
        homeSub:Show()
        backBtn:Hide()
        pageTitle:Hide()
    else
        homeIcon:Hide()
        homeTitle:Hide()
        homeSub:Hide()
        backBtn:Show()
        local info = PAGE_INFO[id]
        pageTitle:SetText(info and info.title or id)
        pageTitle:Show()
        EnterPage(id)
    end
end

backBtn:SetScript("OnClick", function()
    ns:ShowAppPage("home")
end)

------------------------------------------------------------
-- Home page dashboard
------------------------------------------------------------

-- ── Row 1: Character bar ─────────────────────────────────
local charBar = CreateFrame("Frame", nil, homePage, "BackdropTemplate")
charBar:SetSize(CW, 50)
charBar:SetPoint("TOPLEFT", homePage, "TOPLEFT", PAD, -PAD)
ns.Widgets:Apply(charBar, "inset")
ns.SmoothFrame(charBar)

local charSpecFs = charBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
charSpecFs:SetPoint("LEFT", 14, 0)
ns.ApplyTextShadow(charSpecFs)

local charIlvlFs = charBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
charIlvlFs:SetPoint("CENTER", 0, 0)
ns.ApplyTextShadow(charIlvlFs)

-- Forward declare
-- Jump counter, on the character bar rather than in the title. It belongs
-- with the other per-character readouts, and it is a curiosity, so it
-- sits quietly to the right of the item level rather than getting a page.
-- Plain text, matching the item level beside it. A filled chip with an
-- icon made the least important thing on the bar the heaviest, and
-- anchoring it to the centred item level crowded the two together in the
-- middle. It sits in its own space before the goal selector instead.
local charJumps = CreateFrame("Frame", nil, charBar)
charJumps:SetSize(90, 20)
-- Offset clears the goal selector (button plus its label) on the right.
charJumps:SetPoint("RIGHT", charBar, "RIGHT", -206, 0)
charJumps:EnableMouse(true)
charJumps:Hide()

local charJumpsFs = charJumps:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
charJumpsFs:SetPoint("RIGHT", 0, 0)
charJumpsFs:SetJustifyH("RIGHT")

charJumps:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Jumps", 1, 1, 1)
    GameTooltip:AddLine("Counted on this character since the addon was "
        .. "installed. Does nothing whatsoever.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
charJumps:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function RefreshCharJumps()
    local n = ns.FunStats and ns.FunStats:Get("jumps") or 0
    -- Hidden until there is something to report, so a fresh character is
    -- not told it has jumped zero times.
    if n <= 0 then charJumps:Hide() return end
    charJumpsFs:SetText(("|cff8a8a94%s jumps|r"):format(BreakUpLargeNumbers(n)))
    charJumps:SetWidth(math.max(charJumpsFs:GetStringWidth(), 10))
    charJumps:Show()
end
ns.RefreshCharJumps = RefreshCharJumps

-- Live: the counter announces its own changes, so the chip ticks as you
-- jump instead of only when the dashboard happens to rebuild.
if ns.FunStats and ns.FunStats.OnChanged then
    ns.FunStats:OnChanged(function()
        if app and app:IsShown() then RefreshCharJumps() end
    end)
end

local UpdateProfileDisplay
local RefreshDashboard

-- Profile dropdown button
local profileBtn = CreateFrame("Button", nil, charBar, "BackdropTemplate")
profileBtn:SetSize(140, 34)
profileBtn:SetPoint("RIGHT", -8, 0)
ns.Widgets:Apply(profileBtn, "row")
-- The button showed only the value ("Normal"), which reads as a status
-- rather than a control -- and nothing on screen said what it governed.
-- Name it, and put the consequence in the tooltip.
local profileLabel = charBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
profileLabel:SetPoint("RIGHT", profileBtn, "LEFT", -6, 0)
profileLabel:SetTextColor(unpack(ns.COLORS.TEXT_TERTIARY))
profileLabel:SetText("Goal:")

profileBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Content goal", 1, 1, 1)
    GameTooltip:AddLine("What you are gearing for. Sets which item levels "
        .. "count as an upgrade, and what the dashboard tells you to farm.",
        0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
profileBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
ns.SmoothFrame(profileBtn)
ns.AddGlowHighlight(profileBtn, 0.06)

local profileNameFs = profileBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
profileNameFs:SetPoint("LEFT", 8, 0)
ns.ApplyTextShadow(profileNameFs)

local profileArrow = profileBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
profileArrow:SetPoint("RIGHT", -6, 0)
profileArrow:SetTextColor(unpack(ns.COLORS.TEXT_TERTIARY))
profileArrow:SetText("v")

-- Profile dropdown popup
local profileDropdown = CreateFrame("Frame", "YippYappProfileDropdown", UIParent, "BackdropTemplate")
profileDropdown:SetSize(220, 10)
profileDropdown:SetFrameStrata("DIALOG")
profileDropdown:SetClampedToScreen(true)
ns.Widgets:Apply(profileDropdown, "row")
ns.SmoothFrame(profileDropdown)
profileDropdown:EnableMouse(true)
profileDropdown:Hide()

profileDropdown:SetScript("OnShow", function()
    tinsert(UISpecialFrames, "YippYappProfileDropdown")
end)
profileDropdown:SetScript("OnHide", function()
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "YippYappProfileDropdown" then
            table.remove(UISpecialFrames, i)
            break
        end
    end
end)

local PROFILE_DESCS = {
    normal  = "Casual / Delves / M+ up to 8",
    heroic  = "Heroic Raid / M+ 10",
    mythic  = "Mythic Raid / M+ 10+",
}

local profileRows = {}
local yOff = 8
for i, p in ipairs(ns.PROFILES) do
    local row = CreateFrame("Button", nil, profileDropdown)
    row:SetSize(204, 28)
    row:SetPoint("TOPLEFT", 8, -yOff)

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.05)
    hl:SetBlendMode("ADD")

    row.nameFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameFs:SetPoint("TOPLEFT", 6, -3)

    row.descFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.descFs:SetPoint("TOPLEFT", 6, -16)
    row.descFs:SetTextColor(unpack(ns.COLORS.TEXT_TERTIARY))
    row.descFs:SetText(PROFILE_DESCS[p.id] or "")

    row.check = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.check:SetPoint("RIGHT", -6, 0)

    local pid = p.id
    local pname = p.name
    row:SetScript("OnClick", function()
        YippYappHelperDB.profile = pid
        UpdateProfileDisplay()
        profileDropdown:Hide()
        -- Refresh dashboard (summary, farm guide depend on profile)
        RefreshDashboard()
        -- Refresh gear panel if open
        if ns.MainFrame and ns.MainFrame:IsShown() then
            if ns.RefreshAllSlots then ns:RefreshAllSlots() end
            if ns.RefreshSuggestions then ns:RefreshSuggestions() end
        end
    end)

    profileRows[i] = { row = row, id = pid, name = pname }
    yOff = yOff + 28
end
profileDropdown:SetHeight(yOff + 6)

UpdateProfileDisplay = function()
    local profile = ns:GetCurrentProfile()
    local color = "|cff00aaff"
    profileNameFs:SetText(color .. profile.name .. "|r")

    -- Update checkmarks in dropdown
    for _, pr in ipairs(profileRows) do
        local isActive = (pr.id == profile.id)
        local nameColor = isActive and "|cffffffff" or "|cff" .. "aaaaaa"
        pr.row.nameFs:SetText(nameColor .. pr.name .. "|r")
        pr.row.check:SetText(isActive and "|cff00ff00>|r" or "")

        if isActive then
            local bg = pr.row.bg
            if not bg then
                bg = pr.row:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                pr.row.bg = bg
            end
            bg:SetColorTexture(0, 1, 0, 0.04)
            bg:Show()
        elseif pr.row.bg then
            pr.row.bg:Hide()
        end
    end
end

profileBtn:SetScript("OnClick", function(self)
    if profileDropdown:IsShown() then
        profileDropdown:Hide()
    else
        UpdateProfileDisplay()
        profileDropdown:ClearAllPoints()
        profileDropdown:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -2)
        profileDropdown:Show()
    end
end)

UpdateProfileDisplay()

-- ── Row 2: Crest overview ────────────────────────────────
local CREST_ROW_Y = -(PAD + 50 + 10)
local CREST_BAR_H = 48
local CREST_COLS = 5
local CREST_GAP = 8
local CREST_W = math.floor((CW - (CREST_COLS - 1) * CREST_GAP) / CREST_COLS)

local CREST_TRACKS = {
    { track = "Adventurer", hex = "ff1eff00", r = 0.12, g = 1.00, b = 0.00 },
    { track = "Veteran",    hex = "ff0070dd", r = 0.00, g = 0.44, b = 0.87 },
    { track = "Champion",   hex = "ffa335ee", r = 0.64, g = 0.21, b = 0.93 },
    { track = "Hero",       hex = "ffff8000", r = 1.00, g = 0.50, b = 0.00 },
    { track = "Myth",       hex = "ffff0000", r = 1.00, g = 0.00, b = 0.00 },
}

local crestFrames = {}

for i, ct in ipairs(CREST_TRACKS) do
    local x = PAD + (i - 1) * (CREST_W + CREST_GAP)
    local bar = CreateFrame("Frame", nil, homePage, "BackdropTemplate")
    bar:SetSize(CREST_W, CREST_BAR_H)
    bar:SetPoint("TOPLEFT", homePage, "TOPLEFT", x, CREST_ROW_Y)
    ns.Widgets:Apply(bar, "inset")
    ns.SmoothFrame(bar)

    -- Track name (top-left, colored)
    local nameFs = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameFs:SetPoint("TOPLEFT", 8, -5)
    nameFs:SetText("|c" .. ct.hex .. ct.track .. "|r")
    ns.ApplyTextShadow(nameFs)

    -- Season cap info (top-right)
    local upgFs = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    upgFs:SetPoint("TOPRIGHT", -8, -5)
    upgFs:SetJustifyH("RIGHT")

    -- Crest icon (bottom-left)
    local iconTex = bar:CreateTexture(nil, "ARTWORK")
    iconTex:SetSize(20, 20)
    iconTex:SetPoint("BOTTOMLEFT", 8, 5)
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Count (large, next to icon, bottom)
    local countFs = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    countFs:SetPoint("LEFT", iconTex, "RIGHT", 5, 0)
    countFs:SetText("0")

    crestFrames[ct.track] = { bar = bar, iconTex = iconTex, countFs = countFs, upgFs = upgFs }
end

-- ── Row 3: Upgrade summary (left) + Farm guide (right) ──
local SUMMARY_Y = CREST_ROW_Y - CREST_BAR_H - 14
local SUMMARY_GAP = 10
local SUMMARY_W = math.floor((CW - SUMMARY_GAP) / 2)
local SUMMARY_H = 184

-- Helper: build a styled summary/farm panel with header row, accent underline,
-- and a matching row factory. Matches the visual weight of other app panels.
local function MakeSummaryPanel(parent, x, y, w, h, titleText, accentRGB)
    local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    p:SetSize(w, h)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    ns.Widgets:Apply(p, "inset")
    ns.SmoothFrame(p)

    -- Title bar: slightly darker strip behind the title for weight
    local titleBg = p:CreateTexture(nil, "ARTWORK")
    titleBg:SetPoint("TOPLEFT", 4, -4)
    titleBg:SetPoint("TOPRIGHT", -4, -4)
    titleBg:SetHeight(24)
    titleBg:SetColorTexture(0.12, 0.12, 0.12, 0.9)

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titleBg, "LEFT", 10, 0)
    title:SetTextColor(unpack(ns.COLORS.TEXT_HEADER))
    title:SetText(titleText)
    ns.ApplyTextShadow(title)

    -- Accent underline matching the panel's theme color
    local accent = p:CreateTexture(nil, "OVERLAY")
    accent:SetPoint("TOPLEFT", titleBg, "BOTTOMLEFT", 0, 0)
    accent:SetPoint("TOPRIGHT", titleBg, "BOTTOMRIGHT", 0, 0)
    accent:SetHeight(1)
    accent:SetColorTexture(accentRGB[1], accentRGB[2], accentRGB[3], 0.8)

    p._title = title
    p._contentTop = -34  -- where rows should start
    return p
end

local function MakeSummaryRow(panel, width)
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(width, 16)

    -- Chevron bullet
    local bullet = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bullet:SetPoint("LEFT", 0, 0)
    bullet:SetText("›")
    bullet:SetTextColor(0.55, 0.55, 0.55)
    row._bullet = bullet

    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", bullet, "RIGHT", 6, 0)
    fs:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetMaxLines(2)
    fs:SetText("")
    row._fs = fs
    return row
end

-- Left: Upgrade Summary (green theme, matches Gear Upgrades nav)
-- Mr. Yeeper's panel. It used to be a bare list of upgrade facts; it now
-- leads with his read on them, because the useful output was never the
-- numbers themselves but the conclusion you were meant to draw from
-- them. The numbers stay underneath as the evidence.
local summaryPanel = MakeSummaryPanel(
    homePage, PAD, SUMMARY_Y, SUMMARY_W, SUMMARY_H,
    "Mr. Yeeper", { 0.72, 0.52, 1.0 })

local yeeperPortrait = summaryPanel:CreateTexture(nil, "ARTWORK")
yeeperPortrait:SetSize(46, 46)
yeeperPortrait:SetPoint("TOPLEFT", summaryPanel, "TOPLEFT", 14,
    summaryPanel._contentTop - 2)
yeeperPortrait:SetTexture("Interface\\AddOns\\YippYappHelper\\Media\\Yeeper")

-- The texture is a two-frame sheet: eyes open on the left half, blinking
-- on the right. Swapping texcoords avoids a second file and any load
-- hitch mid-blink.
local YEEPER_OPEN  = { 0.0, 0.5, 0.0, 1.0 }
local YEEPER_BLINK = { 0.5, 1.0, 0.0, 1.0 }
yeeperPortrait:SetTexCoord(unpack(YEEPER_OPEN))

-- Bob. A Translation animation rather than OnUpdate: Blizzard drives it,
-- so it costs nothing while the app is closed and stops on its own.
--
-- Two explicit legs on REPEAT rather than one on BOUNCE. BOUNCE replays
-- the same animation reversed, and the easing is not mirrored with it --
-- so the curve reverses direction abruptly at the top and reads as a
-- snap. Up-then-down, each eased independently, returns to the origin
-- smoothly and loops without a seam.
local yeeperBob = yeeperPortrait:CreateAnimationGroup()
yeeperBob:SetLooping("REPEAT")

local bobUp = yeeperBob:CreateAnimation("Translation")
bobUp:SetOrder(1)
bobUp:SetOffset(0, 3)
bobUp:SetDuration(1.8)
bobUp:SetSmoothing("IN_OUT")

local bobDown = yeeperBob:CreateAnimation("Translation")
bobDown:SetOrder(2)
bobDown:SetOffset(0, -3)
bobDown:SetDuration(1.8)
bobDown:SetSmoothing("IN_OUT")

-- Blink. Randomised gaps, because a metronome reads as a broken texture
-- rather than a living thing. Doubles up occasionally for the same reason.
local yeeperBlinkTimer
local function YeeperScheduleBlink()
    if yeeperBlinkTimer then yeeperBlinkTimer:Cancel() end
    yeeperBlinkTimer = C_Timer.NewTimer(math.random(30, 70) / 10, function()
        if not summaryPanel:IsVisible() then YeeperScheduleBlink() return end
        yeeperPortrait:SetTexCoord(unpack(YEEPER_BLINK))
        C_Timer.After(0.12, function()
            yeeperPortrait:SetTexCoord(unpack(YEEPER_OPEN))
            -- Roughly one blink in four is a double.
            if math.random(1, 4) == 1 then
                C_Timer.After(0.16, function()
                    yeeperPortrait:SetTexCoord(unpack(YEEPER_BLINK))
                    C_Timer.After(0.1, function()
                        yeeperPortrait:SetTexCoord(unpack(YEEPER_OPEN))
                    end)
                end)
            end
            YeeperScheduleBlink()
        end)
    end)
end

-- Only animate while he is on screen.
summaryPanel:HookScript("OnShow", function()
    yeeperBob:Play()
    YeeperScheduleBlink()
end)
summaryPanel:HookScript("OnHide", function()
    yeeperBob:Stop()
    if yeeperBlinkTimer then yeeperBlinkTimer:Cancel(); yeeperBlinkTimer = nil end
    yeeperPortrait:SetTexCoord(unpack(YEEPER_OPEN))
end)

-- Speech bubble. A plain block of text reads as a caption about him; a
-- bubble with a tail reads as something he said.
-- Width is computed, not anchored. With both edges anchored the wrap
-- width is unknown until layout runs, so measuring the text to size the
-- bubble either under-measured (clipping the last line) or collapsed it
-- to a single truncated line. Fixed numbers remove the ordering problem.
local YEEPER_BUBBLE_W = SUMMARY_W - 14 - 46 - 12 - 12
local yeeperBubble = CreateFrame("Frame", nil, summaryPanel, "BackdropTemplate")
yeeperBubble:SetPoint("TOPLEFT", yeeperPortrait, "TOPRIGHT", 12, 2)
yeeperBubble:SetWidth(YEEPER_BUBBLE_W)
yeeperBubble:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})
yeeperBubble:SetBackdropColor(0.16, 0.14, 0.22, 0.85)
yeeperBubble:SetBackdropBorderColor(0.45, 0.36, 0.62, 0.7)

-- No tail: at this size a drawn nub reads as a stray artefact rather
-- than a pointer. Proximity to the portrait is enough.

local yeeperSpeech = yeeperBubble:CreateFontString(nil, "OVERLAY", "GameFontNormal")
yeeperSpeech:SetPoint("TOPLEFT", 10, -8)
yeeperSpeech:SetWidth(YEEPER_BUBBLE_W - 20)
yeeperSpeech:SetJustifyH("LEFT")
yeeperSpeech:SetJustifyV("TOP")
yeeperSpeech:SetSpacing(3)
yeeperSpeech:SetWordWrap(true)
yeeperSpeech:SetTextColor(0.92, 0.92, 0.95)

-- Reveal the line as if he is saying it. SetAlphaGradient fades text in
-- by character index, which -- unlike building the string a letter at a
-- time -- does not chop colour escapes in half or reflow the wrap on
-- every frame.
local yeeperReveal
local function YeeperFit()
    -- Width is fixed, so the height is correct straight away.
    yeeperBubble:SetHeight(math.max((yeeperSpeech:GetStringHeight() or 14) + 18, 46))
end

-- Tips: the "so what do I do" that a remark on its own leaves hanging.
-- Kept as plain bullets under the bubble rather than inside it, so the
-- spoken line stays a sentence and the actions stay scannable.
local yeeperTips = {}
for i = 1, 4 do
    local fs = summaryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", yeeperBubble, "BOTTOMLEFT", 4, -6 - (i - 1) * 15)
    fs:SetWidth(YEEPER_BUBBLE_W - 8)
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(0.62, 0.60, 0.70)
    fs:Hide()
    yeeperTips[i] = fs
end

local function YeeperShowTips(tips)
    for i, fs in ipairs(yeeperTips) do
        local t = tips and tips[i]
        if t then
            fs:SetText("|cffb885ff-|r  " .. t)
            fs:Show()
        else
            fs:SetText("")
            fs:Hide()
        end
    end
end

local function YeeperSay(text)
    yeeperSpeech:SetText(text or "")
    YeeperFit()
    if yeeperReveal then yeeperReveal:Cancel(); yeeperReveal = nil end
    if not text or text == "" or not yeeperSpeech.SetAlphaGradient then return end

    local len = strlenutf8 and strlenutf8(text) or #text
    local pos = 0
    yeeperSpeech:SetAlphaGradient(0, 24)
    yeeperReveal = C_Timer.NewTicker(0.02, function(self)
        pos = pos + 2.2
        if pos >= len then
            yeeperSpeech:SetAlphaGradient(len, 1)   -- fully opaque
            self:Cancel()
            yeeperReveal = nil
            return
        end
        yeeperSpeech:SetAlphaGradient(pos, 24)
    end)
end

------------------------------------------------------------
-- Yeeper has more than one thing to say
------------------------------------------------------------
-- One line per visit made him feel like a status readout. A short
-- playlist you can page through makes him feel like he has been keeping
-- notes -- and it lets the urgent line lead without burying the rest.

-- One line at a time. Paging through slides put the reader in charge of
-- finding the interesting one, which is backwards: he should just say
-- the thing.
--
-- Picked at random rather than cycled. A strict rotation is predictable
-- after a handful of visits -- you learn the running order and it stops
-- feeling like he chose. Random with a short memory of what he last said
-- keeps it fresh without letting the same line land twice in a row.
local yeeperRecent = {}
local yeeperLast = nil
-- How many recent lines he refuses to repeat.
--
-- Was 4, chosen when the pool was a handful of asides. With jabber in
-- the playlist the pool is two to three times bigger, and a memory of
-- four let the vault line come back after eight or nine opens. If memory
-- ever eats the whole pool the code below falls back to repeating, so
-- raising this cannot make him mute.
local YEEPER_MEMORY = 10

local function YeeperRefresh()
    if not ns.Advisor then return end
    -- Counted here rather than on frame show: this runs once per visit to
    -- the home screen, which is what "opening the tab again" means.
    if ns.FunStats and ns.FunStats.Bump then ns.FunStats:Bump("homeOpens") end
    -- Counted per addon version, so the introduction replays after an
    -- update: a returning player knows as little about what changed as
    -- a new one does.
    if ns.Advisor and ns.Advisor.NoteOpen then ns.Advisor:NoteOpen() end
    local ok, lines = pcall(function() return ns.Advisor:Playlist() end)
    lines = (ok and lines) or {}
    if #lines == 0 then return end

    -- Urgent business always leads: anything the rules raised is a real
    -- problem and outranks entertainment.
    local msg = lines[1]
    -- Never the same line twice running, whatever its priority. A
    -- genuinely urgent line still leads -- but repeating it verbatim on
    -- the next open reads as a stuck addon rather than an insistent one,
    -- and the player has already read it.
    if #lines > 1 and msg.text == yeeperLast then
        for _, m in ipairs(lines) do
            if m.text ~= yeeperLast then msg = m break end
        end
    end
    if #lines > 1 and not (msg.p and msg.p >= 60) then
        -- Everything he could say, minus what he has said recently.
        local fresh = {}
        for _, m in ipairs(lines) do
            local stale = false
            for _, seenText in ipairs(yeeperRecent) do
                if seenText == m.text then stale = true break end
            end
            if not stale then table.insert(fresh, m) end
        end
        -- If memory has eaten everything, he is allowed to repeat himself.
        local pool = #fresh > 0 and fresh or lines
        msg = pool[math.random(#pool)]
    end

    table.insert(yeeperRecent, msg.text)
    while #yeeperRecent > YEEPER_MEMORY do table.remove(yeeperRecent, 1) end
    -- Tracked separately from yeeperRecent: that list only gates the
    -- random path, and the back-to-back guard above has to apply to the
    -- high-priority path too.
    yeeperLast = msg.text
    -- Only the panel knows which line it picked, so the count of "times
    -- actually said" has to be recorded here. It is what demotes a
    -- standing problem out of the urgent slot once he has led with it.
    if ns.Advisor.NoteShown then ns.Advisor:NoteShown(msg.text) end

    YeeperSay(msg.text)
    YeeperShowTips(msg.tips)
end

local summaryLines = {}
for i = 1, 8 do   -- 6 evidence rows plus headroom for the advisor line
    local row = MakeSummaryRow(summaryPanel, SUMMARY_W - 28)
    summaryLines[i] = row._fs      -- keep existing callers working
    summaryLines[i]._row = row
end

local function LayoutSummaryLines()
    -- Below whichever is taller: the portrait or what Yeeper just said.
    local blockH = math.max(46, yeeperBubble:GetHeight() or 46)
    local yOff = summaryPanel._contentTop - blockH - 8
    for i, fs in ipairs(summaryLines) do
        local row = fs._row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", summaryPanel, "TOPLEFT", 14, yOff)
        local h = fs:GetStringHeight()
        if h < 1 then h = 14 end
        row:SetHeight(h)
        yOff = yOff - h - 4
    end
end

-- Right: Activity Planner (cyan-violet theme — the "what should I do
-- tonight" companion to the green Upgrade Summary on the left). Shows
-- a compact vault-progress strip at the top and up to 3 prioritized
-- action rows underneath, each with a category accent stripe and an
-- inline progress bar.
local plannerPanel = MakeSummaryPanel(
    homePage, PAD + SUMMARY_W + SUMMARY_GAP, SUMMARY_Y, SUMMARY_W, SUMMARY_H,
    "Tonight's Plan", { 0.55, 0.55, 1.0 })

-- Vault progress strip (three tracks side-by-side, 3 dots each).
local VAULT_STRIP_H  = 22
local vaultStrip = CreateFrame("Frame", nil, plannerPanel)
vaultStrip:SetPoint("TOPLEFT", plannerPanel, "TOPLEFT", 14, plannerPanel._contentTop - 2)
vaultStrip:SetPoint("TOPRIGHT", plannerPanel, "TOPRIGHT", -14, plannerPanel._contentTop - 2)
vaultStrip:SetHeight(VAULT_STRIP_H)

local vaultLabel = vaultStrip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
vaultLabel:SetPoint("LEFT", 0, 0)
vaultLabel:SetText("Vault")
vaultLabel:SetTextColor(0.55, 0.55, 0.55)

-- Three tracks: M+, Raid, Delves. Each has a short name + 3 dot textures.
local VAULT_TRACK_DEFS = {
    { key = "mplus", label = "M+",    color = { 0.0,  0.83, 1.0  } },
    { key = "raid",  label = "Raid",  color = { 0.85, 0.40, 0.95 } },
    { key = "world", label = "Delve", color = { 0.35, 0.85, 0.40 } },
}

local vaultDots = {}     -- [trackKey] = { labelFs, dots = { tex1, tex2, tex3 } }
do
    -- Layout within the strip: "Vault" label at x=0 takes ~36px, then each
    -- track gets a label (up to 40px for "Delve") followed by a 6px gap and
    -- three 9px dots at 12px spacing (block width = 79). Previously stripX
    -- was 42 and dots started at +28 — the label's 32px width overlapped
    -- the first dot by 4px.
    local stripX  = 48
    local lblW    = 40
    local dotGap  = 6
    local dotStep = 12
    local dotSize = 9
    local dotsStart = lblW + dotGap          -- relative to groupX
    local blockW    = dotsStart + 2 * dotStep + dotSize
    local available = (SUMMARY_W - 28) - stripX
    local trackW    = math.floor(available / #VAULT_TRACK_DEFS)
    if trackW < blockW then trackW = blockW end
    for i, def in ipairs(VAULT_TRACK_DEFS) do
        local groupX = stripX + (i - 1) * trackW

        local lbl = vaultStrip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", vaultStrip, "LEFT", groupX, 0)
        lbl:SetText(def.label)
        lbl:SetTextColor(def.color[1] * 0.9, def.color[2] * 0.9, def.color[3] * 0.9)
        lbl:SetWidth(lblW)
        lbl:SetJustifyH("LEFT")

        local dots = {}
        for d = 1, 3 do
            local dot = vaultStrip:CreateTexture(nil, "ARTWORK")
            dot:SetSize(dotSize, dotSize)
            dot:SetPoint("LEFT", vaultStrip, "LEFT",
                groupX + dotsStart + (d - 1) * dotStep, 0)
            dot:SetColorTexture(0.18, 0.18, 0.18, 1)
            dots[d] = dot
        end
        vaultDots[def.key] = { labelFs = lbl, dots = dots, color = def.color }
    end
end

-- Action rows: icon stripe + title + detail + progress bar.
-- Budget check (panel = SUMMARY_H = 184):
--   title bar              = 24
--   content top padding    = 10   » content starts at -34
--   vault strip            = 22
--   vault-to-rows gap      = 4
--   3 rows + 2 gaps        = 3*PLAN_ROW_H + 2*PLAN_ROW_GAP
--   bottom margin          = ~8
-- 3 rows @ PLAN_ROW_H=32, PLAN_ROW_GAP=4 → 104 px of row content.
-- Total: 24+10+22+4+104+8 = 172 ≤ 184 (with 12px slack).
local PLAN_ROW_H = 32
local PLAN_ROW_GAP = 4
local planRows = {}
local PLAN_ROWS = 3

local function MakePlanRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(PLAN_ROW_H)

    -- Left accent stripe (category color) — 3px wide vertical line.
    local accent = row:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 0, -1)
    accent:SetPoint("BOTTOMLEFT", 0, 3)
    accent:SetWidth(3)
    accent:SetColorTexture(0.5, 0.5, 0.5, 1)
    row._accent = accent

    local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", accent, "TOPRIGHT", 8, -1)
    title:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -1)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    row._title = title

    local detail = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detail:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    detail:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -2)
    detail:SetJustifyH("LEFT")
    detail:SetWordWrap(false)
    detail:SetTextColor(0.55, 0.55, 0.55)
    row._detail = detail

    -- Thin progress bar along the bottom of the row. Sits inside the
    -- row's bounding box so it never overflows the panel.
    local barTrack = row:CreateTexture(nil, "BACKGROUND")
    barTrack:SetPoint("BOTTOMLEFT", accent, "BOTTOMRIGHT", 8, 0)
    barTrack:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 0)
    barTrack:SetHeight(2)
    barTrack:SetColorTexture(0.12, 0.12, 0.12, 0.9)
    row._barTrack = barTrack

    local barFill = row:CreateTexture(nil, "ARTWORK")
    barFill:SetPoint("TOPLEFT", barTrack, "TOPLEFT", 0, 0)
    barFill:SetPoint("BOTTOMLEFT", barTrack, "BOTTOMLEFT", 0, 0)
    barFill:SetWidth(1)
    barFill:SetColorTexture(0.55, 0.55, 0.55, 1)
    row._barFill = barFill
    row._barTrackWidth = nil  -- resolved on first layout
    return row
end

for i = 1, PLAN_ROWS do
    local row = MakePlanRow(plannerPanel)
    row:SetPoint("TOPLEFT",  plannerPanel, "TOPLEFT",  14,
        plannerPanel._contentTop - VAULT_STRIP_H - 4 - (i - 1) * (PLAN_ROW_H + PLAN_ROW_GAP))
    row:SetPoint("TOPRIGHT", plannerPanel, "TOPRIGHT", -14,
        plannerPanel._contentTop - VAULT_STRIP_H - 4 - (i - 1) * (PLAN_ROW_H + PLAN_ROW_GAP))
    row:Hide()
    planRows[i] = row
end

-- Empty-state label shown when the planner has nothing pressing.
local plannerEmpty = plannerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
plannerEmpty:SetPoint("TOPLEFT", plannerPanel, "TOPLEFT", 14,
    plannerPanel._contentTop - VAULT_STRIP_H - 10)
plannerEmpty:SetPoint("TOPRIGHT", plannerPanel, "TOPRIGHT", -14,
    plannerPanel._contentTop - VAULT_STRIP_H - 10)
plannerEmpty:SetJustifyH("LEFT")
plannerEmpty:SetWordWrap(true)
plannerEmpty:SetTextColor(0.65, 0.65, 0.65)
plannerEmpty:Hide()

-- ── Row 4: Navigation buttons ────────────────────────────
-- Ordered so each row of three is one kind of question, at NAV_COLS = 3:
--
--   what do I wear      Gear Upgrades  Best in Slot  Trinkets
--   what do I bring     Consumables    Progression   Loot Browser
--   what am I running   Mythic+        Raid Tools    Teleports
--
-- Nine entries, three clean rows.
local NAV_DEFS = {
    { id = "gear",        label = "Gear Upgrades",   hex = "ff00ff00" },
    { id = "bis",         label = "Best in Slot",    hex = "ff73ff8c" },
    { id = "trinkets",    label = "Trinkets",        hex = "ff70d0ff" },

    { id = "consumables", label = "Consumables",     hex = "ffff00ff" },
    { id = "progression", label = "Progression",     hex = "ffffff00" },
    { id = "loot",        label = "Loot Browser",    hex = "ff00ccff" },

    { id = "mythicplus",  label = "Mythic+",         hex = "ff00d4ff" },
    { id = "raid",        label = "Raid",           hex = "ff00aaff" },
    { id = "teleports",   label = "Teleports",       hex = "ff88ccff" },

}

local NAV_COLS = 3
local NAV_GAP = 10
local NAV_W = math.floor((CW - (NAV_COLS - 1) * NAV_GAP) / NAV_COLS)
local NAV_H = 36
local NAV_ROW_GAP = 8
local NAV_Y = SUMMARY_Y - SUMMARY_H - 12

-- Buttons are kept rather than discarded: some entries hide themselves
-- once they have nothing left to say (see RefreshNav), and a hidden
-- button must close the gap instead of leaving a hole in the grid.
local navButtons = {}

--- The marching-ants border the gear slots use for "this is ready".
--- Reused verbatim so "there is something to do here" looks the same
--- everywhere in the addon rather than inventing a second visual
--- language for the same idea.
local function AddAntsGlow(btn, r, g, b)
    if btn.antsGlow then return btn.antsGlow end

    local glow = CreateFrame("Frame", nil, btn)
    glow:SetPoint("TOPLEFT", -6, 6)
    glow:SetPoint("BOTTOMRIGHT", 6, -6)
    glow:SetFrameLevel(math.max(btn:GetFrameLevel() - 1, 0))
    glow:Hide()

    glow.ants = glow:CreateTexture(nil, "ARTWORK")
    glow.ants:SetAllPoints()
    glow.ants:SetAtlas("ActionBarSpellHighlightBorder")
    glow.ants:SetVertexColor(r, g, b, 0.9)

    glow.animGroup = glow.ants:CreateAnimationGroup()
    glow.animGroup:SetLooping("BOUNCE")
    local fade = glow.animGroup:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.5)
    fade:SetToAlpha(1.0)
    fade:SetDuration(0.6)
    fade:SetSmoothing("IN_OUT")

    btn.antsGlow = glow
    return glow
end

for i, def in ipairs(NAV_DEFS) do
    local btn = CreateFrame("Button", nil, homePage, "BackdropTemplate")
    btn:SetSize(NAV_W, NAV_H)
    ns.Widgets:Apply(btn, "row")
    ns.SmoothFrame(btn)
    ns.AddGlowHighlight(btn, 0.08)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", 12, 0)
    label:SetText("|c" .. def.hex .. def.label .. "|r")
    ns.ApplyTextShadow(label)

    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrow:SetPoint("RIGHT", -10, 0)
    arrow:SetTextColor(unpack(ns.COLORS.TEXT_TERTIARY))
    arrow:SetText(">")

    btn:SetScript("OnClick", function()
        ns:ShowAppPage(def.id)
    end)

    btn.navID = def.id
    navButtons[#navButtons + 1] = btn
end

--- Position only the visible buttons, so hiding one closes the gap
--- rather than leaving a blank cell where it used to be.
local function LayoutNav()
    local slot = 0
    for _, btn in ipairs(navButtons) do
        if btn.navHidden then
            btn:Hide()
        else
            local col = slot % NAV_COLS
            local row = math.floor(slot / NAV_COLS)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", homePage, "TOPLEFT",
                PAD + col * (NAV_W + NAV_GAP),
                NAV_Y - row * (NAV_H + NAV_ROW_GAP))
            btn:Show()
            slot = slot + 1
        end
    end
end


LayoutNav()

------------------------------------------------------------
-- Dashboard refresh (called when home page is shown)
------------------------------------------------------------
RefreshDashboard = function()
    -- Cheap, and the dashboard refresh is the one place guaranteed to run
    -- whenever the home screen is shown.
    if ns.RefreshCharJumps then ns.RefreshCharJumps() end
    -- Character bar
    local specIndex = GetSpecialization and GetSpecialization()
    local specName = ""
    if specIndex then
        local _, name = GetSpecializationInfo(specIndex)
        specName = name or ""
    end
    local className = UnitClass("player") or ""
    local _, classFile = UnitClass("player")
    local classColor = classFile and RAID_CLASS_COLORS[classFile]
    if classColor then
        charSpecFs:SetText(classColor:WrapTextInColorCode(specName .. " " .. className))
    else
        charSpecFs:SetText(specName .. " " .. className)
    end

    local _, equipped = GetAverageItemLevel()
    charIlvlFs:SetText(string.format("|cffffffffilvl %d|r", math.floor(equipped or 0)))

    UpdateProfileDisplay()

    -- Crest bars
    local crestData = ns:GetCrestInfo()
    local crestByTrack = {}
    for _, cd in ipairs(crestData) do
        crestByTrack[cd.track] = cd
    end
    for _, ct in ipairs(CREST_TRACKS) do
        local cf = crestFrames[ct.track]
        if cf then
            local cd = crestByTrack[ct.track]
            local count          = cd and cd.quantity or 0
            local totalEarned    = cd and cd.totalEarned or 0
            local seasonCap      = cd and cd.seasonCap or 0
            local earnedThisWeek = cd and cd.earnedThisWeek or 0
            local weeklyCap      = cd and cd.weeklyMax or 0
            if cd and cd.icon then cf.iconTex:SetTexture(cd.icon) end

            cf.countFs:SetText("|cffffffff" .. count .. "|r")

            -- Show season earned/cap + weekly remaining
            local parts = {}
            if seasonCap > 0 then
                local seasonRemaining = math.max(seasonCap - totalEarned, 0)
                if seasonRemaining <= 0 then
                    table.insert(parts, "|cff555555" .. totalEarned .. "/" .. seasonCap .. "|r")
                else
                    table.insert(parts, "|cff888888" .. totalEarned .. "/" .. seasonCap .. "|r")
                end
            end
            if weeklyCap > 0 then
                local weekRemaining = math.max(weeklyCap - earnedThisWeek, 0)
                if weekRemaining > 0 then
                    table.insert(parts, "|cff666666+" .. weekRemaining .. "w|r")
                end
            end
            cf.upgFs:SetText(table.concat(parts, " "))
        end
    end

    -- Upgrade summary
    local freeCount = 0
    local upgradeableCount = 0
    local maxedCount = 0

    -- Collect all recommendations, prioritizing actionable ones
    local REC_PRIORITY = {
        FREE_UPGRADE   = 1,
        UPGRADE_NOW    = 2,
        SAFE_TEMP      = 3,
        USE_LOWER_TRACK = 4,
        UPGRADE_LATER  = 5,
        HOLD_CRESTS    = 6,
        SAVE_FOR_DROP  = 7,
        CREST_CAPPED   = 8,
        WAIT_BETTER    = 9,
        MAXED          = 10,
        NO_ITEM        = 11,
    }

    local topRecs = {}

    -- Slots holding gear with no upgrade track — last season's pieces, or
    -- drops that never had one. At a season boundary this is the most
    -- actionable number on the page: those slots are dead weight.
    local staleCount = 0
    -- Crests needed to finish every pending upgrade, per crest track.
    local needByTrack = {}

    for _, slotInfo in ipairs(ns.SLOT_IDS) do
        local canUp, upInfo, why = ns:CanUpgradeItem(slotInfo.slot)
        if upInfo then
            if upInfo.currUpgrade >= upInfo.maxUpgrade then
                maxedCount = maxedCount + 1
            else
                local watermark = ns:GetFreeUpgradeIlvl(slotInfo.slot)
                local isFree = watermark > upInfo.currIlvl
                if isFree then
                    freeCount = freeCount + 1
                end
                if canUp then
                    upgradeableCount = upgradeableCount + 1
                    -- Free upgrades cost nothing, so they do not count
                    -- toward the crest bill.
                    if not isFree then
                        local crestTrack = ns.TRACK_CREST[upInfo.track]
                        local cost = crestTrack and ns:GetCrestCost(crestTrack)
                        if crestTrack and cost then
                            needByTrack[crestTrack] = (needByTrack[crestTrack] or 0) + cost
                        end
                    end
                end
            end
        elseif why and ns:GetSlotInfo(slotInfo.slot) then
            staleCount = staleCount + 1
        end

        if ns.GetRecommendation then
            local ok, rec, reason = pcall(ns.GetRecommendation, ns, slotInfo.slot)
            if ok and rec and rec.label and rec.label ~= "" then
                -- Find which key this rec matches
                local recKey = nil
                for key, r in pairs(ns.RECOMMEND) do
                    if r == rec then recKey = key; break end
                end
                local pri = recKey and REC_PRIORITY[recKey] or 99
                if pri <= 7 then  -- only show actionable recommendations
                    table.insert(topRecs, {
                        slot = slotInfo,
                        rec = rec,
                        reason = reason,
                        priority = pri,
                    })
                end
            end
        end
    end

    table.sort(topRecs, function(a, b) return a.priority < b.priority end)

    -- How much of the pending bill your crests actually cover.
    local shortfall = {}
    for crestTrack, needed in pairs(needByTrack) do
        local have = ns:GetCrestCountByTrack(crestTrack) or 0
        if have < needed then
            shortfall[#shortfall + 1] = {
                track = crestTrack, short = needed - have,
            }
        end
    end
    table.sort(shortfall, function(a, b) return a.short > b.short end)

    -- Yeeper speaks first, in his own space beside the portrait. The rows
    -- below stay as evidence: a panel that is only opinion cannot be
    -- checked when it claims you are 40 crests short.
    YeeperRefresh()

    local line = 1
    if freeCount > 0 then
        summaryLines[line]:SetText(string.format(
            "|cff00ffff%d|r free ilvl %s waiting (no crest cost)",
            freeCount, freeCount == 1 and "upgrade" or "upgrades"))
        line = line + 1
    end

    summaryLines[line]:SetText(string.format(
        "|cffffffff%d|r can upgrade now  |cff666666·|r  |cff888888%d at max rank|r",
        upgradeableCount, maxedCount))
    line = line + 1

    -- Last season's gear, called out by name so it reads as "replace
    -- these" rather than a silent gap in the counts above.
    if staleCount > 0 then
        summaryLines[line]:SetText(string.format(
            "|cffcc8844%d|r %s no upgrade track |cff808080(previous season)|r",
            staleCount, staleCount == 1 and "slot has" or "slots have"))
        line = line + 1
    end

    -- Only worth saying when you cannot afford everything pending.
    if shortfall[1] then
        local s = shortfall[1]
        local hex = (ns.CRESTS and (function()
            for _, c in ipairs(ns.CRESTS) do
                if c.track == s.track then return c.color end
            end
        end)()) or "ffffffff"
        summaryLines[line]:SetText(string.format(
            "Short |c%s%d %s|r for everything pending",
            hex, s.short, s.track))
        line = line + 1
    end

    -- Show top 3 recommendations. Format: "Slot — Action  (reason)"
    local shown = 0
    for _, tr in ipairs(topRecs) do
        if shown >= 3 or line > 6 then break end
        shown = shown + 1
        local recColor = tr.rec.color or "ffffffff"
        local action   = tr.rec.label or ""
        local slotName = tr.slot.name
        local reason   = tr.reason or ""
        local text = string.format(
            "|cffffffff%s|r |cff666666—|r |c%s%s|r", slotName, recColor, action)
        if reason ~= "" then
            text = text .. string.format("  |cff808080(%s)|r", reason)
        end
        summaryLines[line]:SetText(text)
        line = line + 1
    end

    -- The panel is Yeeper's alone now: no bullet rows, no restatement of
    -- the numbers he just summarised. The block above still computes them
    -- because other parts of the dashboard read the same locals; only the
    -- rendering is dropped. Worth collapsing properly once nothing else
    -- depends on it.
    for i = 1, #summaryLines do
        summaryLines[i]:SetText("")
        if summaryLines[i]._row then summaryLines[i]._row:Hide() end
    end

    -- ── Activity Planner ──
    -- Fill vault progress dots + up to PLAN_ROWS actionable rows. Data
    -- is computed by ns.Planner; this block is pure presentation.
    local plan = ns.Planner and ns.Planner:BuildPlan() or nil

    -- Vault dots: filled = unlocked (track color), empty = dim.
    local vault = plan and plan.vault or nil
    for _, def in ipairs(VAULT_TRACK_DEFS) do
        local trackData = vault and vault[def.key]
        local dots = vaultDots[def.key].dots
        local color = vaultDots[def.key].color
        for d = 1, 3 do
            local slot = trackData and trackData.all and trackData.all[d]
            if slot and slot.unlocked then
                dots[d]:SetColorTexture(color[1], color[2], color[3], 1)
            else
                -- Faint preview: show the next target slightly brighter
                -- than locked ones so the eye lands on what to chase.
                local isNextTarget = slot and not slot.unlocked and trackData
                    and trackData.next and trackData.next.index == slot.index
                if isNextTarget then
                    dots[d]:SetColorTexture(color[1] * 0.45, color[2] * 0.45, color[3] * 0.45, 1)
                else
                    dots[d]:SetColorTexture(0.16, 0.16, 0.16, 1)
                end
            end
        end
    end

    -- Plan rows
    local items = (plan and plan.items) or {}
    local trackWidth = plannerPanel:GetWidth() - 14 - 14 - 3 - 8 - 2  -- mirror MakePlanRow anchors
    for i = 1, PLAN_ROWS do
        local row = planRows[i]
        local item = items[i]
        if item then
            local cat = ns.Planner.CATEGORIES[item.category]
            local accentColor = cat and cat.accent or { 0.6, 0.6, 0.6 }
            row._accent:SetColorTexture(accentColor[1], accentColor[2], accentColor[3], 1)
            row._title:SetText(item.title or "")
            row._detail:SetText(item.detail or "")

            if item.progress and item.progress.target and item.progress.target > 0 then
                local frac = math.max(0, math.min(1,
                    (item.progress.have or 0) / item.progress.target))
                row._barTrack:Show()
                row._barFill:SetColorTexture(accentColor[1], accentColor[2], accentColor[3], 0.9)
                row._barFill:SetWidth(math.max(1, trackWidth * frac))
                row._barFill:Show()
            else
                row._barTrack:Hide()
                row._barFill:Hide()
            end
            row:Show()
        else
            row:Hide()
        end
    end

    -- Reserved slot for the empty-state message (nothing to do right now).
    -- Only shown when BuildPlan returned a single "filler" item AND we
    -- intentionally want a larger, friendlier message than a normal row.
    if #items == 1 and (items[1].priority or 0) >= 4 then
        plannerEmpty:SetText(string.format("|cffffffff%s|r\n|cff888888%s|r",
            items[1].title or "", items[1].detail or ""))
        plannerEmpty:Show()
        planRows[1]:Hide()
    else
        plannerEmpty:Hide()
    end
end

-- Hook: refresh dashboard when home page is shown
homePage:SetScript("OnShow", RefreshDashboard)
ns._refreshDashboard = RefreshDashboard

-- Auto-refresh dashboard when gear or crests change while visible
local dashEventFrame = CreateFrame("Frame")
dashEventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
dashEventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
dashEventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
dashEventFrame:RegisterEvent("ITEM_UPGRADE_MASTER_UPDATE")

local dashRefreshPending = false
dashEventFrame:SetScript("OnEvent", function(self, event, arg1)
    -- Only care about player inventory changes
    if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end

    -- Debounce: don't refresh multiple times per frame
    if dashRefreshPending then return end
    if not app:IsShown() or currentPage ~= "home" then return end

    dashRefreshPending = true
    C_Timer.After(0.3, function()
        dashRefreshPending = false
        if app:IsShown() and currentPage == "home" then
            RefreshDashboard()
        end
    end)
end)

-- Default to home
ns:ShowAppPage("home")

------------------------------------------------------------
-- Public API
------------------------------------------------------------
function ns:ToggleApp()
    if app:IsShown() then
        app:Hide()
    else
        ns:ShowAppPage("home")
        app:Show()
    end
end

function ns:ToggleDashboard()
    ns:ToggleApp()
end
