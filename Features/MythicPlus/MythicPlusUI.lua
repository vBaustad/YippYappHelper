local _, ns = ...

------------------------------------------------------------
-- Mythic Plus UI: keystones, ratings, and dungeon scores
------------------------------------------------------------
local PAD = 12
local ROW_H = 18
local SECTION_GAP = 10

------------------------------------------------------------
-- Main frame (standalone)
------------------------------------------------------------
local frame = CreateFrame("Frame", "YippYappMythicPlus", UIParent, "BackdropTemplate")
local MPLUS_W, MPLUS_H = ns:GetAppFrameSize()
frame:SetSize(MPLUS_W, MPLUS_H)
frame:SetPoint("CENTER")
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
ns.MythicPlusFrame = frame

-- Quick slash command to jump straight to the Mythic+ page in the app.
SLASH_YYHKEYS1 = "/keys"
SLASH_YYHKEYS2 = "/yhkeys"
SlashCmdList.YYHKEYS = function()
    if ns.ShowAppPage and ns.AppFrame then
        ns.AppFrame:Show()
        ns:ShowAppPage("mythicplus")
    end
end

-- ESC to close (standalone)
frame:SetScript("OnShow", function()
    tinsert(UISpecialFrames, "YippYappMythicPlus")
end)
frame:SetScript("OnHide", function()
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "YippYappMythicPlus" then
            table.remove(UISpecialFrames, i)
            break
        end
    end
end)

-- Title
local titleIcon, titleFs = ns.MakeWindowHeader(frame, "|cff00d4ffMythic+|r", nil, PAD)

-- Close button
local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -2, -2)

------------------------------------------------------------
-- Tabs
------------------------------------------------------------
local activeTab = "home"
local TAB_H = 22
local TAB_W = 90
local TAB_GAP = 4
local TAB_Y = -36
local testMode = false

local tabDefs = {
    { id = "home",  label = "Home" },
    { id = "guild", label = "Guild" },
}

local tabButtons = {}
for i, def in ipairs(tabDefs) do
    local tab = ns.CreateUnderlineTab(frame, def.label, { 0.0, 0.83, 1.0 })
    tab:SetSize(TAB_W, TAB_H)
    tab:SetPoint("TOPLEFT", PAD + (i - 1) * (TAB_W + TAB_GAP), TAB_Y)
    tab._id = def.id
    tab:SetScript("OnClick", function()
        activeTab = def.id
        ns:RefreshMythicPlus()
    end)
    tabButtons[def.id] = tab
end

-- Temporary slash command to toggle the fake-group test mode.
-- TODO: remove once real data flows cover all the layout edge cases.
SLASH_YYHMPLUSTEST1 = "/yyhmplustest"
SlashCmdList.YYHMPLUSTEST = function()
    testMode = not testMode
    print("|cff00ff00YippYapp|r M+ test mode: " .. (testMode and "ON" or "OFF"))
    if frame:IsShown() and ns.RefreshMythicPlus then ns:RefreshMythicPlus() end
end

local function UpdateTabHighlights()
    for id, tab in pairs(tabButtons) do
        if id == activeTab then ns.SetTabActive(tab)
        else ns.SetTabInactive(tab) end
    end
end

------------------------------------------------------------
-- Vault header (persistent, right-aligned on tab row)
------------------------------------------------------------
local vaultContainer = CreateFrame("Frame", nil, frame)
vaultContainer:SetSize(250, TAB_H)
vaultContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, TAB_Y)
local vaultSlotBtns = {}
local vaultLabelFs = nil
local vaultInited = false

local function RefreshVaultHeader()
    C_AddOns.LoadAddOn("Blizzard_WeeklyRewards")
    local BlizzardMixin = WeeklyRewardsActivityMixin

    -- Hide old slots
    for _, btn in ipairs(vaultSlotBtns) do btn:Hide() end

    local activities = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.Activities)
    if not activities or #activities == 0 then return end
    table.sort(activities, function(a, b) return a.index < b.index end)

    local VAULT_BTN_W, VAULT_BTN_H = 56, TAB_H
    local VAULT_BTN_GAP = 3
    local numSlots = math.min(#activities, 3)

    -- Label
    if not vaultLabelFs then
        vaultLabelFs = vaultContainer:CreateFontString(nil, "OVERLAY")
        vaultLabelFs:SetFont(STANDARD_TEXT_FONT, 10, "")
    end
    vaultLabelFs:ClearAllPoints()
    vaultLabelFs:SetPoint("RIGHT", vaultContainer, "RIGHT", -(numSlots * (VAULT_BTN_W + VAULT_BTN_GAP) + 2), 0)
    vaultLabelFs:SetText("|cff888888Vault|r")
    vaultLabelFs:Show()

    for si, activityInfo in ipairs(activities) do
        if si > 3 then break end
        local filled = activityInfo.progress >= activityInfo.threshold

        local slotBtn = vaultSlotBtns[si]
        if not slotBtn then
            slotBtn = CreateFrame("Button", nil, vaultContainer, "BackdropTemplate")
            slotBtn:SetSize(VAULT_BTN_W, VAULT_BTN_H)
            slotBtn._fs = slotBtn:CreateFontString(nil, "OVERLAY")
            slotBtn._fs:SetPoint("CENTER")
            slotBtn._fs:SetJustifyH("CENTER")
            slotBtn._fs:SetWidth(VAULT_BTN_W)
            slotBtn._fs:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
            vaultSlotBtns[si] = slotBtn
        end

        slotBtn:ClearAllPoints()
        local bx = -(numSlots - si) * (VAULT_BTN_W + VAULT_BTN_GAP)
        slotBtn:SetPoint("RIGHT", vaultContainer, "RIGHT", bx, 0)
        slotBtn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets   = { left = 2, right = 2, top = 2, bottom = 2 },
        })

        if filled then
            slotBtn:SetBackdropColor(0.0, 0.25, 0.0, 0.8)
            slotBtn:SetBackdropBorderColor(0.0, 0.6, 0.0, 0.7)
        else
            slotBtn:SetBackdropColor(0.08, 0.08, 0.08, 0.8)
            slotBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
        end

        if filled then
            local itemLink = C_WeeklyRewards.GetExampleRewardItemHyperlinks(activityInfo.id)
            local ilvl = itemLink and itemLink ~= "" and C_Item.GetDetailedItemLevelInfo(itemLink)
            if ilvl then
                slotBtn._fs:SetText("|cffffffff" .. ilvl .. "|r")
            else
                local lvl = activityInfo.level > 0 and ("+" .. activityInfo.level) or "Done"
                slotBtn._fs:SetText("|cff00ff00" .. lvl .. "|r")
            end
        else
            slotBtn._fs:SetText("|cff999999" .. activityInfo.progress .. "/" .. activityInfo.threshold .. "|r")
        end

        local isFilled = filled
        slotBtn.info = activityInfo
        if BlizzardMixin then
            for _, method in ipairs({
                "CanShowPreviewItemTooltip", "HandlePreviewMythicRewardTooltip",
                "HandlePreviewRaidRewardTooltip", "HandlePreviewPvPRewardTooltip",
                "HandlePreviewWorldRewardTooltip", "IsCompletedAtHeroicLevel",
                "AddTopRunsToTooltip", "AddRaidCompletionInfoToGameTooltip",
                "GetRaidName", "ShowPreviewItemTooltip", "ShowIncompleteTooltip",
            }) do
                if BlizzardMixin[method] then slotBtn[method] = BlizzardMixin[method] end
            end
        end

        slotBtn:SetScript("OnClick", function() WeeklyRewards_ShowUI() end)
        slotBtn:SetScript("OnEnter", function(self)
            if isFilled then
                self:SetBackdropColor(0.0, 0.35, 0.0, 0.9)
                self:SetBackdropBorderColor(0.0, 0.8, 0.0, 0.9)
            else
                self:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
                self:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.7)
            end
            if BlizzardMixin and self.info then
                BlizzardMixin.OnEnter(self)
            else
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine("Great Vault", 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        slotBtn:SetScript("OnLeave", function(self)
            if isFilled then
                self:SetBackdropColor(0.0, 0.25, 0.0, 0.8)
                self:SetBackdropBorderColor(0.0, 0.6, 0.0, 0.7)
            else
                self:SetBackdropColor(0.08, 0.08, 0.08, 0.8)
                self:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
            end
            GameTooltip:Hide()
        end)

        slotBtn:Show()
    end
end

------------------------------------------------------------
-- Content area (below tabs)
------------------------------------------------------------
local content = CreateFrame("Frame", nil, frame)
content:SetPoint("TOPLEFT", PAD, TAB_Y - TAB_H - 4)
content:SetPoint("BOTTOMRIGHT", -PAD, PAD)

------------------------------------------------------------
-- Object pools
------------------------------------------------------------
local fsPool = {}
local fsPoolIdx = 0

local function AcquireFS(parent, template)
    fsPoolIdx = fsPoolIdx + 1
    local fs = fsPool[fsPoolIdx]
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
        fsPool[fsPoolIdx] = fs
    else
        fs:SetFontObject(template or "GameFontNormalSmall")
        fs:SetParent(parent)
    end
    fs:SetTextColor(1, 1, 1)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:SetWidth(0)  -- reset; callers may SetWidth after acquiring
    fs:ClearAllPoints()
    fs:Show()
    return fs
end

local texPool = {}
local texPoolIdx = 0

local function AcquireTex(parent)
    texPoolIdx = texPoolIdx + 1
    local tex = texPool[texPoolIdx]
    if not tex then
        tex = parent:CreateTexture(nil, "ARTWORK")
        texPool[texPoolIdx] = tex
    else
        tex:SetParent(parent)
    end
    tex:ClearAllPoints()
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetAlpha(1)
    tex:SetDesaturated(false)
    tex:SetDrawLayer("ARTWORK", 0)
    tex:Show()
    return tex
end

-- Regular buttons (player cards, vault, etc.)
local btnPool = {}
local btnPoolIdx = 0

local function AcquireBtn(parent)
    btnPoolIdx = btnPoolIdx + 1
    local btn = btnPool[btnPoolIdx]
    if not btn then
        btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
        btnPool[btnPoolIdx] = btn
    else
        btn:SetParent(parent)
    end
    btn:ClearAllPoints()
    btn:SetScript("OnClick", nil)
    btn:SetScript("OnEnter", nil)
    btn:SetScript("OnLeave", nil)
    btn:Show()
    return btn
end

-- Secure buttons (dungeon icon teleport tiles)
local secBtnPool = {}
local secBtnPoolIdx = 0

local function AcquireSecureBtn(parent)
    secBtnPoolIdx = secBtnPoolIdx + 1
    local btn = secBtnPool[secBtnPoolIdx]
    if not btn then
        btn = CreateFrame("Button", nil, parent, "BackdropTemplate,SecureActionButtonTemplate")
        btn:RegisterForClicks("AnyUp", "AnyDown")
        secBtnPool[secBtnPoolIdx] = btn
    else
        btn:SetParent(parent)
    end
    btn:ClearAllPoints()
    if not InCombatLockdown() then
        btn:SetAttribute("type", nil)
        btn:SetAttribute("macrotext", nil)
    end
    btn:SetScript("OnEnter", nil)
    btn:SetScript("OnLeave", nil)
    btn:Show()
    return btn
end

local function ResetPools()
    for i = 1, fsPoolIdx do fsPool[i]:Hide() end
    fsPoolIdx = 0
    for i = 1, texPoolIdx do texPool[i]:Hide() end
    texPoolIdx = 0
    for i = 1, btnPoolIdx do btnPool[i]:Hide() end
    btnPoolIdx = 0
    for i = 1, secBtnPoolIdx do secBtnPool[i]:Hide() end
    secBtnPoolIdx = 0
end

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
-- Four fake teammates (self is prepended separately in test mode).
local TEST_MEMBERS = {
    { name = "Tankicus",   class = "WARRIOR",     unit = "player" },
    { name = "Healzorz",   class = "PRIEST",      unit = "player" },
    { name = "Sneakybois", class = "ROGUE",       unit = "player" },
    { name = "Evoksnoke",  class = "EVOKER",      unit = "player" },
}

-- Deterministic stand-in map/level pairs for the 4 test teammates.
local TEST_KEYSTONES = {
    { mapID = 2811, level = 10 }, -- Magisters' Terrace
    { mapID = 658,  level = 14 }, -- Pit of Saron
    { mapID = 1209, level = 11 }, -- Skyreach
    { mapID = 2805, level = 13 }, -- Windrunner Spire
}

local function GetGroupMembers()
    if testMode then
        local out = {}
        -- Real player first so their own keystone + real scores are preserved.
        table.insert(out, {
            name = UnitName("player"),
            class = select(2, UnitClass("player")),
            unit = "player",
        })
        for i, m in ipairs(TEST_MEMBERS) do
            table.insert(out, { name = m.name, class = m.class, unit = m.unit, _testIdx = i })
        end
        return out
    end

    local members = {}
    local playerName = UnitName("player")
    local _, playerClass = UnitClass("player")

    table.insert(members, { name = playerName, class = playerClass, unit = "player" })

    local numGroup = GetNumGroupMembers()
    if numGroup <= 1 then return members end

    -- Always use the 5-man party slots regardless of whether the character
    -- is currently in a raid. M+ group views should only show the key group.
    do
        for i = 1, 4 do
            local unit = "party" .. i
            local name = UnitName(unit)
            local _, class = UnitClass(unit)
            if name then
                table.insert(members, { name = name, class = class, unit = unit })
            end
        end
    end

    return members
end

local function ColorRating(score)
    if not score or score == 0 then return "|cff555555-|r" end
    local r, g, b = ns:GetRatingColor(score)
    return string.format("|cff%02x%02x%02x%d|r", r * 255, g * 255, b * 255, score)
end

local tooltip = GameTooltip

------------------------------------------------------------
-- Refresh
------------------------------------------------------------
-- Guild tab: show guild members' keystones
local function RefreshGuildTab()
    local cw = content:GetWidth()
    if cw < 10 then cw = (ns:GetAppFrameSize()) - PAD * 2 end
    local y = 0

    local hdr = AcquireFS(content, "GameFontNormal")
    hdr:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    hdr:SetFont(STANDARD_TEXT_FONT, 13, "")
    hdr:SetText("|cffbbbbbbGuild Keystones|r")
    y = y - 22

    -- Collect guild keystone data from addon comms
    local guildKeys = {}
    for pName, ks in pairs(ns:GetGuildKeystones()) do
        table.insert(guildKeys, {
            name = pName,
            mapID = ks.mapID,
            level = ks.level,
            dungeonName = ks.name,
        })
    end

    -- Refresh button: custom-styled, anchored to the vault row on the main
    -- frame (sits to the LEFT of the vault header), not to content — so it
    -- doesn't overlap the second guild-keystone column on wider rosters.
    local refreshBtn = frame._guildRefreshBtn
    if not refreshBtn then
        refreshBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
        refreshBtn:SetSize(78, 20)
        refreshBtn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets   = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        refreshBtn:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
        refreshBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.7)

        local fs = refreshBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("CENTER")
        fs:SetText("Refresh")
        fs:SetTextColor(0.85, 0.85, 0.85)
        refreshBtn._label = fs

        refreshBtn:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(0.0, 0.8, 1.0, 1)
            self._label:SetTextColor(1, 1, 1)
        end)
        refreshBtn:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.7)
            self._label:SetTextColor(0.85, 0.85, 0.85)
        end)
        refreshBtn:SetScript("OnClick", function()
            if ns.RequestGuildKeystones then ns:RequestGuildKeystones() end
            if ns.RefreshMythicPlus then
                C_Timer.After(1.5, function() ns:RefreshMythicPlus() end)
            end
        end)

        frame._guildRefreshBtn = refreshBtn
    end
    refreshBtn:ClearAllPoints()
    refreshBtn:SetPoint("RIGHT", vaultContainer, "LEFT", -8, 0)
    refreshBtn:Show()

    if #guildKeys == 0 then
        local cx = math.floor(cw / 2)
        local empty = AcquireTex(content)
        empty:SetSize(56, 56)
        empty:SetPoint("TOP", content, "TOP", 0, y - 14)
        empty:SetTexture(525134)  -- INV_Relics_Hourglass (neutral "waiting" feel)
        empty:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        empty:SetVertexColor(0.6, 0.6, 0.6, 0.9)
        empty:SetDrawLayer("ARTWORK", 0)

        local line1 = AcquireFS(content)
        line1:SetPoint("TOP", empty, "BOTTOM", 0, -10)
        line1:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
        line1:SetText("|cffbbbbbbNo guild keystones yet|r")

        local line2 = AcquireFS(content)
        line2:SetPoint("TOP", line1, "BOTTOM", 0, -6)
        line2:SetFont(STANDARD_TEXT_FONT, 11, "")
        line2:SetWidth(cw - 20)
        line2:SetJustifyH("CENTER")
        if IsInGuild() then
            line2:SetText("|cff888888Guildies need YippYapp installed to share keys.\nHit Refresh to ping the guild — replies arrive over the next few seconds.|r")
        else
            line2:SetText("|cff888888You're not in a guild.|r")
        end
        return
    end

    -- Sort by key level descending
    table.sort(guildKeys, function(a, b) return a.level > b.level end)

    local KS_CARD_W = math.floor((cw - 6) / 2)
    local KS_CARD_H = 34
    local KS_CARD_GAP = 3
    local KS_ICON_SIZE = 26

    for ki, ks in ipairs(guildKeys) do
        local col = (ki - 1) % 2
        local row = math.floor((ki - 1) / 2)
        local kx = col * (KS_CARD_W + 6)
        local ky = y - row * (KS_CARD_H + KS_CARD_GAP)

        local cc = ks.class and RAID_CLASS_COLORS[ks.class]

        -- Card background
        local ksBg = AcquireTex(content)
        ksBg:SetSize(KS_CARD_W, KS_CARD_H)
        ksBg:SetPoint("TOPLEFT", content, "TOPLEFT", kx, ky)
        ksBg:SetColorTexture(0.09, 0.09, 0.09, 0.7)
        ksBg:SetDrawLayer("BACKGROUND", 1)

        -- Class accent
        if cc then
            local ksAccent = AcquireTex(content)
            ksAccent:SetSize(3, KS_CARD_H)
            ksAccent:SetPoint("TOPLEFT", ksBg, "TOPLEFT", 0, 0)
            ksAccent:SetColorTexture(cc.r, cc.g, cc.b, 0.8)
            ksAccent:SetDrawLayer("BACKGROUND", 2)
        end

        -- Dungeon icon
        local ksIcon = AcquireTex(content)
        ksIcon:SetSize(KS_ICON_SIZE, KS_ICON_SIZE)
        ksIcon:SetPoint("LEFT", ksBg, "LEFT", 8, 0)
        ksIcon:SetDrawLayer("ARTWORK", 0)
        local spellID = ns:GetDungeonTeleportSpell(ks.mapID)
        local spellTex = spellID and C_Spell.GetSpellTexture(spellID)
        if spellTex then
            ksIcon:SetTexture(spellTex)
            ksIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            local _, _, _, mapTex = C_ChallengeMode.GetMapUIInfo(ks.mapID)
            ksIcon:SetTexture(mapTex or 134400)
            ksIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end

        -- Key level
        local ksLvl = AcquireFS(content)
        ksLvl:SetPoint("LEFT", ksIcon, "RIGHT", 5, 0)
        ksLvl:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
        ksLvl:SetText("|cff00d4ff+" .. ks.level .. "|r")

        -- Player name
        local ksName = AcquireFS(content)
        ksName:SetPoint("TOPLEFT", ksIcon, "TOPRIGHT", 42, -1)
        ksName:SetWidth(KS_CARD_W - KS_ICON_SIZE - 56)
        ksName:SetFont(STANDARD_TEXT_FONT, 10, "")
        ksName:SetText(cc and cc:WrapTextInColorCode(ks.name) or ks.name)

        -- Dungeon name
        local ksDung = AcquireFS(content)
        ksDung:SetPoint("BOTTOMLEFT", ksIcon, "BOTTOMRIGHT", 42, 1)
        ksDung:SetWidth(KS_CARD_W - KS_ICON_SIZE - 56)
        ksDung:SetFont(STANDARD_TEXT_FONT, 9, "")
        ksDung:SetText("|cff999999" .. ks.dungeonName .. "|r")
    end
end

function ns:RefreshMythicPlus()
    if not frame:IsShown() then return end

    ResetPools()
    UpdateTabHighlights()
    RefreshVaultHeader()

    if activeTab == "guild" then
        RefreshGuildTab()
        return
    end

    local cw = content:GetWidth()
    if cw < 10 then cw = (ns:GetAppFrameSize()) - PAD * 2 end
    local y = 0

    local members = GetGroupMembers()
    local maps = ns:GetSeasonMaps()
    if #maps == 0 then return end
    local partyKeys = ns:GetPartyKeystones()
    local ownSummary = ns:GetUnitMPlusSummary("player")

    -- Collect keystones
    local keystones = {}
    local keyMapIDs = {}

    if testMode then
        -- Real player's real keystone first
        local ownKs = ns:GetOwnKeystone()
        if ownKs then
            table.insert(keystones, {
                name = UnitName("player"),
                class = select(2, UnitClass("player")),
                mapID = ownKs.mapID, level = ownKs.level, dungeonName = ownKs.name,
            })
            keyMapIDs[ownKs.mapID] = true
        end
        -- Then the 4 fake teammates with test keystones
        for _, m in ipairs(members) do
            if m._testIdx then
                local t = TEST_KEYSTONES[m._testIdx]
                if t then
                    local mapName = C_ChallengeMode.GetMapUIInfo(t.mapID) or "Unknown"
                    table.insert(keystones, {
                        name = m.name, class = m.class,
                        mapID = t.mapID, level = t.level, dungeonName = mapName,
                    })
                    keyMapIDs[t.mapID] = true
                end
            end
        end
    else
        local ownKs = ns:GetOwnKeystone()
        if ownKs then
            table.insert(keystones, {
                name = UnitName("player"),
                class = select(2, UnitClass("player")),
                mapID = ownKs.mapID, level = ownKs.level, dungeonName = ownKs.name,
            })
            keyMapIDs[ownKs.mapID] = true
        end
        -- Build a name→class lookup once so the inner loop becomes O(1).
        local membersByName = {}
        for _, m in ipairs(members) do membersByName[m.name] = m.class end
        local selfName = UnitName("player")
        for pName, ks in pairs(partyKeys) do
            if pName ~= selfName then
                table.insert(keystones, {
                    name = pName, class = membersByName[pName],
                    mapID = ks.mapID, level = ks.level, dungeonName = ks.name,
                })
                keyMapIDs[ks.mapID] = true
            end
        end
    end

    local ownRating = ns:GetOwnMPlusRating()

    -- Index keystones by mapID so per-tile OnEnter tooltips don't have to
    -- linearly scan the list on every mouse move.
    local keystonesByMapID = {}
    for _, ks in ipairs(keystones) do
        local bucket = keystonesByMapID[ks.mapID]
        if not bucket then
            bucket = {}
            keystonesByMapID[ks.mapID] = bucket
        end
        bucket[#bucket + 1] = ks
    end

    -- ── Dungeon Icon Headers with names above ──
    local numMaps = math.max(#maps, 1)
    -- Scale icon size to fit available width (leave room for name column)
    local NAME_AREA = 110
    local ICON_GAP = 6
    local maxIconW = math.floor((cw - NAME_AREA - (numMaps - 1) * ICON_GAP) / numMaps)
    local ICON_SIZE = math.min(74, math.max(maxIconW, 48))
    local totalIconW = numMaps * ICON_SIZE + (numMaps - 1) * ICON_GAP
    local iconStartX = math.max(NAME_AREA, math.floor((cw - totalIconW) / 2))

    -- ── Your character info beside dungeon icons ──
    -- Name + rating on the left, dungeon icons to the right — this IS your row
    local playerName = UnitName("player")
    local _, playerClass = UnitClass("player")
    local playerCC = playerClass and RAID_CLASS_COLORS[playerClass]

    -- Name + rating vertically centered against the icon row (14px names + 74px icons = 88px)
    local iconRowH = 14 + ICON_SIZE  -- dungeon names + icons
    local nameBlockH = 28  -- approx height of name + rating
    local nameOffsetY = math.floor((iconRowH - nameBlockH) / 2)

    -- Class color accent bar for own row
    if playerCC then
        local myAccent = AcquireTex(content)
        myAccent:SetSize(3, iconRowH)
        myAccent:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        myAccent:SetColorTexture(playerCC.r, playerCC.g, playerCC.b, 0.8)
        myAccent:SetDrawLayer("BACKGROUND", 2)
    end

    local myNameFs = AcquireFS(content)
    myNameFs:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y - nameOffsetY)
    myNameFs:SetWidth(iconStartX - 16)
    myNameFs:SetFont(STANDARD_TEXT_FONT, 14, "")
    myNameFs:SetText(playerCC and playerCC:WrapTextInColorCode(playerName) or playerName)

    local myRatingFs = AcquireFS(content)
    myRatingFs:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y - nameOffsetY - 16)
    myRatingFs:SetFont(STANDARD_TEXT_FONT, 12, "")
    if ownRating > 0 then
        local rr, rg, rb = ns:GetRatingColor(ownRating)
        myRatingFs:SetText(tostring(ownRating))
        myRatingFs:SetTextColor(rr, rg, rb)
    else
        myRatingFs:SetText("No rating")
        myRatingFs:SetTextColor(0.35, 0.35, 0.35)
    end

    -- Dungeon names above icons
    for i, map in ipairs(maps) do
        local ix = iconStartX + (i - 1) * (ICON_SIZE + ICON_GAP)
        local nameFs = AcquireFS(content)
        nameFs:SetPoint("TOPLEFT", content, "TOPLEFT", ix, y)
        nameFs:SetWidth(ICON_SIZE)
        nameFs:SetJustifyH("CENTER")
        nameFs:SetFont(STANDARD_TEXT_FONT, 10, "")
        -- Two-word names: show first word on top, rest below
        local short = map.name
        -- Trim "The " prefix
        if short:sub(1, 4) == "The " then short = short:sub(5) end
        -- If more than ~10 chars, abbreviate
        if #short > 12 then
            -- Take first word + initial of rest
            local first = short:match("^(%S+)") or short
            if #first < #short then
                short = first
            end
        end
        if keyMapIDs[map.mapID] then
            nameFs:SetText("|cff00cc00" .. short .. "|r")
        else
            nameFs:SetText("|cff888888" .. short .. "|r")
        end
    end
    y = y - 14

    -- Icons
    for i, map in ipairs(maps) do
        local ix = iconStartX + (i - 1) * (ICON_SIZE + ICON_GAP)

        local runData = ownSummary and ownSummary.runs[map.mapID]
        local score = runData and runData.score or 0
        local level = runData and runData.level or 0
        local canTele = ns:CanTeleportToDungeon(map.mapID)

        local tile = AcquireSecureBtn(content)
        tile:SetSize(ICON_SIZE, ICON_SIZE)
        tile:SetPoint("TOPLEFT", content, "TOPLEFT", ix, y)
        tile:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets   = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        tile:SetBackdropColor(0, 0, 0, 0)

        if keyMapIDs[map.mapID] then
            tile:SetBackdropBorderColor(0.0, 0.8, 0.0, 0.8)
        else
            tile:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
        end

        local icon = AcquireTex(tile)
        icon:SetPoint("TOPLEFT", tile, "TOPLEFT", 3, -3)
        icon:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -3, 3)
        icon:SetTexture(map.icon)
        icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        icon:SetDrawLayer("ARTWORK", 0)
        if not canTele then icon:SetAlpha(0.4) end

        local overlay = AcquireTex(tile)
        overlay:SetAllPoints(icon)
        overlay:SetColorTexture(0, 0, 0, 0.4)
        overlay:SetDrawLayer("ARTWORK", 1)

        -- Key level (top)
        local lvlFs = AcquireFS(tile)
        lvlFs:SetPoint("TOP", tile, "TOP", 0, -8)
        lvlFs:SetJustifyH("CENTER")
        lvlFs:SetWidth(ICON_SIZE)
        local lvlFontSize = math.max(math.floor(ICON_SIZE * 0.27), 12)
        lvlFs:SetFont(STANDARD_TEXT_FONT, lvlFontSize, "OUTLINE")
        lvlFs:SetText(level > 0 and ("|cffffffff" .. level .. "|r") or "")

        -- Score (bottom)
        local scoreFs = AcquireFS(tile)
        scoreFs:SetPoint("BOTTOM", tile, "BOTTOM", 0, 6)
        scoreFs:SetJustifyH("CENTER")
        scoreFs:SetWidth(ICON_SIZE)
        local scoreFontSize = math.max(math.floor(ICON_SIZE * 0.19), 10)
        scoreFs:SetFont(STANDARD_TEXT_FONT, scoreFontSize, "OUTLINE")
        if score > 0 then
            local r, g, b = ns:GetRatingColor(score)
            scoreFs:SetText(tostring(score))
            scoreFs:SetTextColor(r, g, b)
        else
            scoreFs:SetText("|cff555555—|r")
        end

        -- Tooltip + teleport
        local mapID = map.mapID
        local mapName = map.name
        tile:SetScript("OnEnter", function(self)
            self:SetBackdropColor(1, 1, 1, 0.15)
            tooltip:SetOwner(self, "ANCHOR_TOP")
            tooltip:AddLine(mapName, 1, 1, 1)
            if level > 0 then tooltip:AddLine("Best: +" .. level, 0.7, 0.7, 0.7) end
            if score > 0 then
                local r, g, b = ns:GetRatingColor(score)
                tooltip:AddLine("Score: " .. score, r, g, b)
            end
            local bucket = keystonesByMapID[mapID]
            if bucket then
                for _, ks in ipairs(bucket) do
                    local kcc = ks.class and RAID_CLASS_COLORS[ks.class]
                    local kName = kcc and kcc:WrapTextInColorCode(ks.name) or ks.name
                    tooltip:AddLine(kName .. " has +" .. ks.level, 0, 0.8, 0)
                end
            end
            tooltip:AddLine(canTele and "\nClick to teleport" or "\nTeleport not unlocked",
                canTele and 0 or 0.5, canTele and 0.8 or 0.5, canTele and 0 or 0.5)
            tooltip:Show()
        end)
        tile:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0, 0, 0, 0)
            tooltip:Hide()
        end)

        -- Secure teleport via macro attribute
        if canTele then
            local spellName = C_Spell.GetSpellName(ns:GetDungeonTeleportSpell(mapID))
            if spellName then
                tile:SetAttribute("type", "macro")
                tile:SetAttribute("macrotext", "/cast " .. spellName)
            end
        end
    end

    y = y - (ICON_SIZE + 6)

    -- ── Group Member Cards (skip self — already shown as dungeon icons) ──
    local CARD_H = 38
    local CARD_GAP = 4
    local CELL_W = ICON_SIZE
    local CELL_H = CARD_H - 4

    -- Build group member list (excluding self). In test mode, include the
    -- fake teammates (those marked with _testIdx) but still skip the real
    -- player since they're already shown in the row above.
    local groupMembers = {}
    for _, member in ipairs(members) do
        if member._testIdx or (not testMode and member.unit ~= "player") then
            table.insert(groupMembers, member)
        end
    end

    for _, member in ipairs(groupMembers) do
        local summary
        if testMode and member._testIdx then
            -- Synthesize per-dungeon run data so the cells populate with
            -- plausible scores for layout preview.
            local runs = {}
            local seed = member._testIdx
            for mi, map in ipairs(maps) do
                local lvl = 8 + ((seed + mi) % 7)
                local score = 100 + lvl * 15 + (seed * 7)
                runs[map.mapID] = { score = score, level = lvl, success = true }
            end
            summary = { rating = 2400 + member._testIdx * 120, runs = runs }
        else
            summary = member.unit and ns:GetUnitMPlusSummary(member.unit)
        end
        local mRating = summary and summary.rating or 0
        local cc = member.class and RAID_CLASS_COLORS[member.class]

        -- Card background
        local cardBg = AcquireTex(content)
        cardBg:SetHeight(CARD_H)
        cardBg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        cardBg:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
        cardBg:SetColorTexture(0.07, 0.07, 0.07, 0.6)
        cardBg:SetDrawLayer("BACKGROUND", 1)

        -- Class color accent bar
        if cc then
            local accent = AcquireTex(content)
            accent:SetSize(3, CARD_H)
            accent:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            accent:SetColorTexture(cc.r, cc.g, cc.b, 0.8)
            accent:SetDrawLayer("BACKGROUND", 2)
        end

        -- Name
        local nfs = AcquireFS(content)
        nfs:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y - 3)
        nfs:SetWidth(iconStartX - 16)
        nfs:SetFont(STANDARD_TEXT_FONT, 13, "")
        nfs:SetText(cc and cc:WrapTextInColorCode(member.name) or member.name)

        -- Rating below name
        local rfs = AcquireFS(content)
        rfs:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y - 19)
        rfs:SetFont(STANDARD_TEXT_FONT, 12, "")
        if mRating > 0 then
            local r, g, b = ns:GetRatingColor(mRating)
            rfs:SetText(tostring(mRating))
            rfs:SetTextColor(r, g, b)
        else
            rfs:SetText("No rating")
            rfs:SetTextColor(0.35, 0.35, 0.35)
        end

        -- Score cells aligned under icons
        for mi, map in ipairs(maps) do
            local runData = summary and summary.runs[map.mapID]
            local mScore = runData and runData.score or 0
            local bestLevel = runData and runData.level or 0
            local cx = iconStartX + (mi - 1) * (ICON_SIZE + ICON_GAP)

            -- Cell background
            local cellBg = AcquireTex(content)
            cellBg:SetSize(CELL_W, CELL_H)
            cellBg:SetPoint("TOPLEFT", content, "TOPLEFT", cx, y - 2)
            cellBg:SetDrawLayer("ARTWORK", 0)

            if mScore > 0 then
                local r, g, b = ns:GetRatingColor(mScore)
                cellBg:SetColorTexture(r * 0.3, g * 0.3, b * 0.3, 0.9)
            else
                cellBg:SetColorTexture(0.04, 0.04, 0.04, 0.9)
            end

            -- Red tint for keys we have but player hasn't done
            if keyMapIDs[map.mapID] and mScore == 0 then
                local cellHL = AcquireTex(content)
                cellHL:SetSize(CELL_W + 2, CELL_H + 2)
                cellHL:SetPoint("CENTER", cellBg, "CENTER", 0, 0)
                cellHL:SetColorTexture(0.8, 0.15, 0.15, 0.25)
                cellHL:SetDrawLayer("BACKGROUND", 2)
            end

            -- Key level (top)
            if bestLevel > 0 then
                local lvlFs = AcquireFS(content)
                lvlFs:SetPoint("TOP", cellBg, "TOP", 0, -3)
                lvlFs:SetJustifyH("CENTER")
                lvlFs:SetWidth(CELL_W)
                lvlFs:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
                lvlFs:SetText("|cffffffff" .. bestLevel .. "|r")
            end

            -- Score (bottom)
            local sFs = AcquireFS(content)
            sFs:SetPoint("BOTTOM", cellBg, "BOTTOM", 0, 3)
            sFs:SetJustifyH("CENTER")
            sFs:SetWidth(CELL_W)
            sFs:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
            if mScore > 0 then
                local r, g, b = ns:GetRatingColor(mScore)
                sFs:SetText(tostring(mScore))
                sFs:SetTextColor(r, g, b)
            else
                sFs:SetText(keyMapIDs[map.mapID] and "|cffff4444—|r" or "|cff333333—|r")
            end
        end

        y = y - (CARD_H + CARD_GAP)
    end

    -- ── Bottom: Group Keystones (left) + Rating Goals (right) ──
    y = y - SECTION_GAP
    local div2 = AcquireTex(content)
    div2:SetHeight(1)
    div2:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    div2:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
    div2:SetColorTexture(0.25, 0.25, 0.25, 0.6)
    y = y - 8

    local bottomY = y
    local halfW = math.floor(cw / 2) - 6

    -- ── Left: Group Keystones ──
    local ksHdr = AcquireFS(content)
    ksHdr:SetPoint("TOPLEFT", content, "TOPLEFT", 0, bottomY)
    ksHdr:SetFont(STANDARD_TEXT_FONT, 13, "")
    ksHdr:SetText("|cffbbbbbbGroup Keystones|r")
    local ksY = bottomY - 20

    if #keystones > 0 then
        local KS_CARD_H = 36
        local KS_CARD_GAP = 3
        local KS_ICON_SIZE = 28
        local ksCardW = halfW

        for ki, ks in ipairs(keystones) do
            local cc = ks.class and RAID_CLASS_COLORS[ks.class]

            local ksBg = AcquireTex(content)
            ksBg:SetSize(ksCardW, KS_CARD_H)
            ksBg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, ksY)
            ksBg:SetColorTexture(0.09, 0.09, 0.09, 0.7)
            ksBg:SetDrawLayer("BACKGROUND", 1)

            if cc then
                local ksAccent = AcquireTex(content)
                ksAccent:SetSize(3, KS_CARD_H)
                ksAccent:SetPoint("TOPLEFT", ksBg, "TOPLEFT", 0, 0)
                ksAccent:SetColorTexture(cc.r, cc.g, cc.b, 0.8)
                ksAccent:SetDrawLayer("BACKGROUND", 2)
            end

            local ksIcon = AcquireTex(content)
            ksIcon:SetSize(KS_ICON_SIZE, KS_ICON_SIZE)
            ksIcon:SetPoint("LEFT", ksBg, "LEFT", 8, 0)
            ksIcon:SetDrawLayer("ARTWORK", 0)
            -- Use the teleport spell icon (reliable) or fallback to map icon
            local spellID = ns:GetDungeonTeleportSpell(ks.mapID)
            local spellTex = spellID and C_Spell.GetSpellTexture(spellID)
            if spellTex then
                ksIcon:SetTexture(spellTex)
                ksIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            else
                -- Try map icon
                local _, _, _, mapIconTex = C_ChallengeMode.GetMapUIInfo(ks.mapID)
                ksIcon:SetTexture(mapIconTex or 134400)
                ksIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end

            local ksLvl = AcquireFS(content)
            ksLvl:SetPoint("LEFT", ksIcon, "RIGHT", 6, 0)
            ksLvl:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE")
            ksLvl:SetText("|cff00d4ff+" .. ks.level .. "|r")

            local ksName = AcquireFS(content)
            ksName:SetPoint("TOPLEFT", ksIcon, "TOPRIGHT", 58, -1)
            ksName:SetWidth(ksCardW - KS_ICON_SIZE - 74)
            ksName:SetFont(STANDARD_TEXT_FONT, 10, "")
            ksName:SetText(cc and cc:WrapTextInColorCode(ks.name) or ks.name)

            local ksDung = AcquireFS(content)
            ksDung:SetPoint("BOTTOMLEFT", ksIcon, "BOTTOMRIGHT", 58, 1)
            ksDung:SetWidth(ksCardW - KS_ICON_SIZE - 74)
            ksDung:SetFont(STANDARD_TEXT_FONT, 9, "")
            ksDung:SetText("|cff999999" .. ks.dungeonName .. "|r")

            ksY = ksY - (KS_CARD_H + KS_CARD_GAP)
        end
    else
        local noKs = AcquireFS(content)
        noKs:SetPoint("TOPLEFT", content, "TOPLEFT", 4, ksY)
        noKs:SetText("|cff555555No keystones in group|r")
        ksY = ksY - ROW_H
    end

    -- ── Right: Rating Goals ──
    local goalX = halfW + 12
    local goalW = cw - goalX
    local goalHdr = AcquireFS(content)
    goalHdr:SetPoint("TOPLEFT", content, "TOPLEFT", goalX, bottomY)
    goalHdr:SetFont(STANDARD_TEXT_FONT, 13, "")
    goalHdr:SetText("|cffbbbbbbRating Goals|r")
    local goalY = bottomY - 20

    local MILESTONES = { 2000, 2500, 3000 }
    local ownScore = ownRating

    -- Score-per-key-level table (timed, based on real data)
    local SCORE_BY_LEVEL = {
        [2] = 100, [3] = 120, [4] = 145, [5] = 185,
        [6] = 245, [7] = 275, [8] = 285, [9] = 307, [10] = 330,
        [11] = 350, [12] = 365, [13] = 380, [14] = 395, [15] = 410,
    }

    local function KeyLevelForScore(targetScore)
        for lvl = 2, 15 do
            if (SCORE_BY_LEVEL[lvl] or 0) >= targetScore then return lvl end
        end
        return 15
    end

    local BAR_H = 18
    local BAR_GAP = 6
    -- Use highest milestone as the bar max for consistent scaling
    local barMax = MILESTONES[#MILESTONES]

    for _, target in ipairs(MILESTONES) do
        local achieved = ownScore >= target
        local r, g, b = ns:GetRatingColor(target)
        local pct = math.min(ownScore / target, 1)

        -- Bar background
        local barBg = AcquireTex(content)
        barBg:SetSize(goalW, BAR_H)
        barBg:SetPoint("TOPLEFT", content, "TOPLEFT", goalX, goalY)
        barBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        barBg:SetDrawLayer("ARTWORK", 0)

        -- Bar fill
        local barFill = AcquireTex(content)
        barFill:SetSize(math.max((goalW - 2) * pct, 1), BAR_H - 2)
        barFill:SetPoint("TOPLEFT", barBg, "TOPLEFT", 1, -1)
        barFill:SetDrawLayer("ARTWORK", 1)

        if achieved then
            barFill:SetColorTexture(r * 0.5, g * 0.5, b * 0.5, 0.8)
        else
            barFill:SetColorTexture(r * 0.35, g * 0.35, b * 0.35, 0.7)
        end

        -- Target label on left of bar
        local targetFs = AcquireFS(content)
        targetFs:SetPoint("LEFT", barBg, "LEFT", 6, 0)
        targetFs:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
        targetFs:SetJustifyH("LEFT")

        if achieved then
            targetFs:SetText(string.format("|cff%02x%02x%02x%d|r  |cff00ff00Done|r",
                r * 255, g * 255, b * 255, target))
        else
            local deficit = target - ownScore
            local targetAvg = math.ceil(target / numMaps)
            local neededLvl = KeyLevelForScore(targetAvg)
            targetFs:SetText(string.format("|cff%02x%02x%02x%d|r",
                r * 255, g * 255, b * 255, target))

            -- Right side: key level hint
            local hintFs = AcquireFS(content)
            hintFs:SetPoint("RIGHT", barBg, "RIGHT", -6, 0)
            hintFs:SetJustifyH("RIGHT")
            hintFs:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
            hintFs:SetText(string.format("|cffaaaaaaall +%d|r", neededLvl))
        end

        goalY = goalY - (BAR_H + BAR_GAP)
    end

    -- Below bars: show weakest dungeons to focus on (for next unachieved milestone)
    for _, target in ipairs(MILESTONES) do
        if ownScore < target then
            local targetAvg = math.ceil(target / numMaps)
            local neededLvl = KeyLevelForScore(targetAvg)
            local tr, tg, tb = ns:GetRatingColor(target)

            -- Gather and sort dungeon scores
            local dungeonScores = {}
            for _, map in ipairs(maps) do
                local runData = ownSummary and ownSummary.runs[map.mapID]
                local score = runData and runData.score or 0
                -- Get spell icon for dungeon
                local spellID = ns:GetDungeonTeleportSpell(map.mapID)
                local spellTex = spellID and C_Spell.GetSpellTexture(spellID)
                local _, _, _, mapTex = C_ChallengeMode.GetMapUIInfo(map.mapID)
                table.insert(dungeonScores, {
                    name = map.name,
                    score = score,
                    icon = spellTex or mapTex,
                })
            end
            table.sort(dungeonScores, function(a, b) return a.score < b.score end)

            goalY = goalY - 2

            local focusHdr = AcquireFS(content)
            focusHdr:SetPoint("TOPLEFT", content, "TOPLEFT", goalX, goalY)
            focusHdr:SetFont(STANDARD_TEXT_FONT, 13, "")
            focusHdr:SetText(string.format("|cffbbbbbbFocus for |cff%02x%02x%02x%d|r",
                tr * 255, tg * 255, tb * 255, target))
            goalY = goalY - 20

            local FOCUS_ROW_H = 24
            local FOCUS_ICON = 20
            local shown = 0
            for _, ds in ipairs(dungeonScores) do
                if ds.score < targetAvg and shown < 4 then
                    shown = shown + 1

                    -- Row background
                    local rowBg = AcquireTex(content)
                    rowBg:SetSize(goalW, FOCUS_ROW_H)
                    rowBg:SetPoint("TOPLEFT", content, "TOPLEFT", goalX, goalY)
                    rowBg:SetColorTexture(0.08, 0.08, 0.08, 0.5)
                    rowBg:SetDrawLayer("BACKGROUND", 1)

                    -- Dungeon icon
                    local dIcon = AcquireTex(content)
                    dIcon:SetSize(FOCUS_ICON, FOCUS_ICON)
                    dIcon:SetPoint("LEFT", rowBg, "LEFT", 4, 0)
                    dIcon:SetTexture(ds.icon or 134400)
                    dIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    dIcon:SetDrawLayer("ARTWORK", 0)

                    -- Dungeon name
                    local short = ds.name
                    if short:sub(1, 4) == "The " then short = short:sub(5) end
                    if #short > 14 then short = short:match("^(%S+)") or short end

                    local nameFs = AcquireFS(content)
                    nameFs:SetPoint("LEFT", dIcon, "RIGHT", 5, 0)
                    nameFs:SetFont(STANDARD_TEXT_FONT, 11, "")
                    nameFs:SetWidth(goalW - FOCUS_ICON - 70)
                    nameFs:SetText("|cffcccccc" .. short .. "|r")

                    -- Target key level on right
                    local lvlFs = AcquireFS(content)
                    lvlFs:SetPoint("RIGHT", rowBg, "RIGHT", -6, 0)
                    lvlFs:SetJustifyH("RIGHT")
                    lvlFs:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")

                    if ds.score > 0 then
                        local cr, cg, cb = ns:GetRatingColor(ds.score)
                        lvlFs:SetText(string.format("|cff%02x%02x%02x%d|r |cff666666>|r |cff00d4ff+%d|r",
                            cr * 255, cg * 255, cb * 255, ds.score, neededLvl))
                    else
                        lvlFs:SetText(string.format("|cffff4444-|r |cff666666>|r |cff00d4ff+%d|r", neededLvl))
                    end

                    goalY = goalY - (FOCUS_ROW_H + 2)
                end
            end

            break  -- only show focus for the next unachieved milestone
        end
    end

    y = math.min(ksY, goalY)
end

------------------------------------------------------------
-- App mode (embedded in AppFrame)
------------------------------------------------------------
function ns:SetMythicPlusAppMode(enabled, contentWidth, contentHeight)
    if enabled then
        frame:SetBackdrop(nil)
        closeBtn:Hide()
        titleFs:Hide()
        frame:SetMovable(false)
        frame:EnableMouse(false)
        local dw, dh = ns:GetAppFrameSize()
        frame:SetSize(contentWidth or dw, contentHeight or (dh - 34))
        local appTabY = -18
        for id, tab in pairs(tabButtons) do
            tab:ClearAllPoints()
            local idx = (id == "home") and 0 or 1
            tab:SetPoint("TOPLEFT", PAD + idx * (TAB_W + TAB_GAP), appTabY)
            tab:Show()
        end
        vaultContainer:ClearAllPoints()
        vaultContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, appTabY)
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", PAD, appTabY - TAB_H - 4)
        content:SetPoint("BOTTOMRIGHT", -PAD, PAD)
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
        frame:SetMovable(true)
        frame:EnableMouse(true)
        local sw, sh = ns:GetAppFrameSize()
        frame:SetSize(sw, sh)
        for id, tab in pairs(tabButtons) do
            tab:ClearAllPoints()
            local idx = (id == "home") and 0 or 1
            tab:SetPoint("TOPLEFT", PAD + idx * (TAB_W + TAB_GAP), TAB_Y)
            tab:Show()
        end
        vaultContainer:ClearAllPoints()
        vaultContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, TAB_Y)
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", PAD, TAB_Y - TAB_H - 4)
        content:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    end
end

------------------------------------------------------------
-- Events: auto-refresh when group changes
------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
eventFrame:RegisterEvent("MYTHIC_PLUS_CURRENT_AFFIX_UPDATE")

eventFrame:SetScript("OnEvent", function()
    if frame:IsShown() then
        C_Timer.After(0.5, function()
            if frame:IsShown() then
                ns:RefreshMythicPlus()
            end
        end)
    end
end)
