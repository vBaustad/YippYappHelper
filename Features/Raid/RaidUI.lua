local _, ns = ...

------------------------------------------------------------
-- Class colors
------------------------------------------------------------
local CLASS_COLORS = {
    WARRIOR     = { 0.78, 0.61, 0.43 },
    PALADIN     = { 0.96, 0.55, 0.73 },
    HUNTER      = { 0.67, 0.83, 0.45 },
    ROGUE       = { 1.00, 0.96, 0.41 },
    PRIEST      = { 1.00, 1.00, 1.00 },
    DEATHKNIGHT = { 0.77, 0.12, 0.23 },
    SHAMAN      = { 0.00, 0.44, 0.87 },
    MAGE        = { 0.25, 0.78, 0.92 },
    WARLOCK     = { 0.53, 0.53, 0.93 },
    MONK        = { 0.00, 1.00, 0.60 },
    DRUID       = { 1.00, 0.49, 0.04 },
    DEMONHUNTER = { 0.64, 0.19, 0.79 },
    EVOKER      = { 0.20, 0.58, 0.50 },
}

local TIER_COUNT_COLORS = {
    [0] = { 1.0, 0.3, 0.3 },
    [1] = { 1.0, 0.6, 0.3 },
    [2] = { 1.0, 1.0, 0.3 },
    [3] = { 0.7, 1.0, 0.3 },
    [4] = { 0.3, 1.0, 0.3 },
    [5] = { 0.3, 1.0, 0.8 },
}

-- Raid buff definitions. spellID drives the icon lookup via
-- C_Spell.GetSpellInfo; fallbackIcon is a stable texture path used when
-- the spell-info call returns nil (can happen early in session or if
-- Blizzard renumbers a spellID mid-patch).
local RAID_BUFFS = {
    -- Stat buffs
    { file = "MAGE",        buff = "Arcane Intellect",       desc = "5% Intellect",
      spellID = 1459,   fallbackIcon = "Interface\\Icons\\Spell_Holy_MagicalSentry" },
    { file = "WARRIOR",     buff = "Battle Shout",           desc = "5% Attack Power",
      spellID = 6673,   fallbackIcon = "Interface\\Icons\\Ability_Warrior_BattleShout" },
    { file = "PRIEST",      buff = "Power Word: Fortitude",  desc = "5% Stamina",
      spellID = 21562,  fallbackIcon = "Interface\\Icons\\Spell_Holy_WordFortitude" },
    { file = "DRUID",       buff = "Mark of the Wild",       desc = "3% Versatility",
      spellID = 1126,   fallbackIcon = "Interface\\Icons\\Spell_Nature_Regeneration" },
    { file = "SHAMAN",      buff = "Skyfury",                desc = "Crit + Haste",
      spellID = 462854, fallbackIcon = "Interface\\Icons\\Spell_Nature_WindFury" },
    -- Utility / movement
    { file = "EVOKER",      buff = "Blessing of the Bronze", desc = "Movement speed",
      spellID = 364342, fallbackIcon = 4622448 },
    -- Debuffs applied to the boss
    { file = "MONK",        buff = "Mystic Touch",           desc = "5% Phys Dmg Taken",
      spellID = 113746, fallbackIcon = "Interface\\Icons\\Ability_Monk_MysticTouch" },
    { file = "DEMONHUNTER", buff = "Chaos Brand",            desc = "5% Magic Dmg Taken",
      spellID = 1490,   fallbackIcon = "Interface\\Icons\\Ability_Warlock_Eradication" },
}

-- Icon widget cache for the Raid Buffs strip. Created lazily on first
-- overview refresh, reused on subsequent refreshes.
local buffIconFrames = {}
local function EnsureBuffIconFrame(idx, parent, size)
    local f = buffIconFrames[idx]
    if f then return f end
    f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetSize(size, size)
    ns.Widgets:Apply(f, "inset")
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetPoint("TOPLEFT", 1, -1)
    f.tex:SetPoint("BOTTOMRIGHT", -1, 1)
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetFrameStrata("TOOLTIP")
        GameTooltip:AddLine(self._buffName or "", 1, 1, 1)
        if self._desc then GameTooltip:AddLine(self._desc, 0.75, 0.75, 0.75, true) end
        if self._present then
            GameTooltip:AddLine("|cff00ff00Present|r")
        else
            GameTooltip:AddLine("|cffff4444Missing|r")
        end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    buffIconFrames[idx] = f
    return f
end

-- Role prefixes
local ROLE_PREFIX = { TANK = "|cff8888ffT|r", HEALER = "|cff00ff00H|r", DAMAGER = "|cffff4444D|r" }

------------------------------------------------------------
-- Raid Inspect Window
------------------------------------------------------------
local RAID_WIDTH = 400
local RAID_HEIGHT = 500
local ROW_HEIGHT = 20

local raidFrame = CreateFrame("Frame", "YippYappRaidFrame", UIParent, "BackdropTemplate")
raidFrame:SetSize(RAID_WIDTH, RAID_HEIGHT)
raidFrame:SetPoint("CENTER", 200, 0)
raidFrame:SetMovable(true)
raidFrame:EnableMouse(true)
raidFrame:RegisterForDrag("LeftButton")
raidFrame:SetScript("OnDragStart", raidFrame.StartMoving)
raidFrame:SetScript("OnDragStop", raidFrame.StopMovingOrSizing)
raidFrame:SetClampedToScreen(true)
raidFrame:SetFrameStrata("HIGH")
ns.Widgets:Apply(raidFrame, "panel")
ns.SmoothFrame(raidFrame)
raidFrame:Hide()
ns.RaidFrame = raidFrame

-- ESC to close
raidFrame:SetScript("OnShow", function()
    if raidFrame.inAppMode then return end
    tinsert(UISpecialFrames, "YippYappRaidFrame")
end)
raidFrame:SetScript("OnHide", function()
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "YippYappRaidFrame" then
            table.remove(UISpecialFrames, i)
            break
        end
    end
end)

-- Close button
local close = CreateFrame("Button", nil, raidFrame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)

-- Forward-declared because SetRaidAppMode below touches both and both
-- are built further down the file. Without this they resolve to globals
-- inside that function, and the globals are nil -- so entering the shell
-- threw on the first line that touched one, exactly as Consumables did.
-- Same mistake, different page; a load harness finds these, reading does
-- not.
local overviewTab, overviewContainer, guideContainer

function ns:SetRaidAppMode(enabled, contentWidth, contentHeight)
    if enabled then
        raidFrame:SetMovable(false)
        raidFrame:EnableMouse(false)
        ns.Widgets:Unskin(raidFrame)
        close:Hide()
        -- A tab bar with one tab in it tells you nothing, and
        -- the shell already names the page above it. Hidden in
        -- app mode; kept for the standalone window, where it is
        -- the only thing labelling the view.
        overviewTab:Hide()
        -- The container reserved 44px for the title and that one tab.
        -- With both hidden the shell names the page above, so that space
        -- is a gap rather than a margin.
        overviewContainer:ClearAllPoints()
        overviewContainer:SetPoint("TOPLEFT", 0, -4)
        overviewContainer:SetPoint("BOTTOMRIGHT", 0, 0)
        -- The Guide sits in the same box. Repositioned alongside rather
        -- than anchored TO overviewContainer, because that one is hidden
        -- whenever the Guide is showing and a frame anchored to a hidden
        -- frame still lays out -- but the day someone "tidies up" by
        -- reparenting it, it would stop.
        guideContainer:ClearAllPoints()
        guideContainer:SetPoint("TOPLEFT", 0, -4)
        guideContainer:SetPoint("BOTTOMRIGHT", 0, 0)
        local dw, dh = ns:GetAppFrameSize()
        raidFrame:SetSize(contentWidth or dw, contentHeight or (dh - 34))
    else
        raidFrame:SetMovable(true)
        raidFrame:EnableMouse(true)
        ns.Widgets:Apply(raidFrame, "panel")
        close:Show()
        raidFrame:SetSize(RAID_WIDTH, RAID_HEIGHT)
    end
end

------------------------------------------------------------
-- Tab system: Overview (default)
-- The tier/perf containers below are kept as legacy mounts for code
-- that still references them.
------------------------------------------------------------
local currentTab = "overview"
local rescanBtn  -- forward declare

-- Assigned, not re-declared: forward-declared above SetRaidAppMode.
overviewContainer = CreateFrame("Frame", nil, raidFrame)
overviewContainer:SetPoint("TOPLEFT", 0, -44)
overviewContainer:SetPoint("BOTTOMRIGHT", 0, 0)

local tierContainer = CreateFrame("Frame", nil, raidFrame)
tierContainer:SetPoint("TOPLEFT", 0, -44)
tierContainer:SetPoint("BOTTOMRIGHT", 0, 0)
tierContainer:Hide()

local perfContainer = CreateFrame("Frame", nil, raidFrame)
perfContainer:SetPoint("TOPLEFT", 0, -44)
perfContainer:SetPoint("BOTTOMRIGHT", 0, 0)
perfContainer:Hide()

-- The Boss Guide's box. Built empty and filled lazily by
-- Features\Raid\RaidGuideUI.lua the first time the sub-tab is opened --
-- that file loads after this one, so there is nothing to call yet, and
-- a guide nobody opened is a guide nobody should have paid to build.
guideContainer = CreateFrame("Frame", nil, raidFrame)
guideContainer:SetPoint("TOPLEFT", 0, -44)
guideContainer:SetPoint("BOTTOMRIGHT", 0, 0)
guideContainer:Hide()

-- Reuse overviewContainer for groups content (merged)
local groupsContainer = overviewContainer

overviewTab = ns.CreateUnderlineTab(raidFrame, "Overview", { 1.0, 1.0, 0.3 })
overviewTab:SetSize(110, 24)
overviewTab:SetPoint("TOPLEFT", 8, -18)

local function UpdateTabStyles()
    ns.SetTabInactive(overviewTab)
    overviewContainer:Hide()
    if currentTab == "overview" then
        ns.SetTabActive(overviewTab)
        overviewContainer:Show()
    end
end

overviewTab:SetScript("OnClick", function()
    currentTab = "overview"
    UpdateTabStyles()
    ns:RefreshRaidOverview()
end)

-- Apply initial tab styling
UpdateTabStyles()

function ns.SetRaidTab(tabName)
    currentTab = tabName
    UpdateTabStyles()
    if tabName == "overview" then
        ns:RefreshRaidOverview()
    end
end

------------------------------------------------------------
-- The shell's sub-tabs: Overview and Boss Guide.
--
-- Separate from SetRaidTab above, which drives the standalone window's
-- own view and predates the shell. Two switchers on one frame sounds
-- like a mistake until you notice they answer to different owners: the
-- shell owns the strip above the page, and the standalone window owns
-- the tab drawn inside it. Merging them would mean the standalone
-- window grew a Boss Guide tab it has no room to draw.
------------------------------------------------------------
local pageTab = "guide"

function ns:SetRaidPageTab(id)
    pageTab = id or "guide"
    if pageTab == "guide" then
        overviewContainer:Hide()
        guideContainer:Show()
        -- Built on first open, not at load. Nine pages of frames for the
        -- eight you did not look at is the reason the shell builds
        -- lazily, and a guide with seven bosses of wrapped text is not
        -- the place to make an exception.
        if ns.RaidGuideUI then
            ns.RaidGuideUI:BuildInto(guideContainer)
            ns.RaidGuideUI:Refresh()
        end
    else
        guideContainer:Hide()
        overviewContainer:Show()
        ns:RefreshRaidOverview()
    end
end

--- What the shell calls to refresh the page, whichever view is up.
---
--- The page was registered with refresh = "RefreshRaidOverview", which
--- redrew the roster even while the Guide was the visible view -- so
--- opening the Guide and resizing the window redrew the wrong thing and
--- left the Guide stale.
function ns:RefreshRaidPage()
    if pageTab == "guide" then
        if ns.RaidGuideUI then
            ns.RaidGuideUI:BuildInto(guideContainer)
            ns.RaidGuideUI:Refresh()
        end
    else
        ns:RefreshRaidOverview()
    end
end

------------------------------------------------------------
-- Tier Tracker tab content
------------------------------------------------------------
rescanBtn = CreateFrame("Button", nil, raidFrame, "BackdropTemplate")
rescanBtn:SetSize(60, 18)
rescanBtn:SetPoint("TOPRIGHT", -36, -44)
ns.Widgets:Apply(rescanBtn, "row")
rescanBtn:SetFrameLevel(raidFrame:GetFrameLevel() + 10)
rescanBtn:Hide()

local rescanText = rescanBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
rescanText:SetAllPoints()
rescanText:SetText("|cff00ff00Rescan|r")

rescanBtn:SetScript("OnClick", function() ns:ScanRaid() end)
rescanBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(0.3, 1.0, 0.3, 0.8)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Rescan raid for tier pieces")
    GameTooltip:Show()
end)
rescanBtn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    GameTooltip_Hide()
end)

local summaryText = tierContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
summaryText:SetPoint("TOPLEFT", 14, -6)
summaryText:SetWidth(RAID_WIDTH - 110)
summaryText:SetJustifyH("LEFT")

local divider = tierContainer:CreateTexture(nil, "ARTWORK")
divider:SetHeight(1)
divider:SetPoint("TOPLEFT", 12, -22)
divider:SetPoint("TOPRIGHT", -12, -22)
divider:SetColorTexture(0.5, 0.5, 0.5, 0.6)

local headerName = tierContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
headerName:SetPoint("TOPLEFT", 14, -26)
headerName:SetText(ns.Widgets:Tint("muted", "Player"))

local headerTier = tierContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
headerTier:SetPoint("TOPLEFT", 138, -26)
headerTier:SetText(ns.Widgets:Tint("muted", "Tier"))

local headerPieces = tierContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
headerPieces:SetPoint("TOPLEFT", 212, -26)
headerPieces:SetText(ns.Widgets:Tint("muted", "Pieces"))

-- A surface under the tier list, created before the scroll frame so it
-- stays behind it -- siblings at the same frame level draw in creation
-- order. Anchored below the column headers so they stay on the page
-- rather than on the panel.
local tierSurface = ns.Widgets and ns.Widgets:Panel(tierContainer, "inset")
if tierSurface then
    tierSurface:SetPoint("TOPLEFT", 6, -36)
    tierSurface:SetPoint("BOTTOMRIGHT", -8, 6)
end

local scrollFrame = CreateFrame("ScrollFrame", nil, tierContainer, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 12, -40)
scrollFrame:SetPoint("BOTTOMRIGHT", -28, 12)

local scrollContent = CreateFrame("Frame", nil, scrollFrame)
scrollContent:SetSize(RAID_WIDTH - 44, 1)
scrollFrame:SetScrollChild(scrollContent)

ns.RaidRows = {}

------------------------------------------------------------
-- Helper: gather raid roster data
------------------------------------------------------------
local function GetRaidRoster()
    local roster = {}
    local n = GetNumGroupMembers()
    if n == 0 then return roster end

    if IsInRaid() then
        for i = 1, n do
            local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(i)
            if name then
                local assignedRole = UnitGroupRolesAssigned("raid" .. i) or "NONE"
                table.insert(roster, {
                    name = name:match("^([^%-]+)") or name,
                    fullName = name,
                    class = fileName,
                    group = subgroup or 1,
                    role = assignedRole,
                    online = online,
                    index = i,
                })
            end
        end
    else
        -- Party mode
        local units = { "player" }
        for i = 1, n - 1 do
            table.insert(units, "party" .. i)
        end
        for i, unit in ipairs(units) do
            if UnitExists(unit) then
                local name = UnitName(unit)
                local _, fileName = UnitClass(unit)
                local assignedRole = UnitGroupRolesAssigned(unit) or "NONE"
                if name then
                    table.insert(roster, {
                        name = name,
                        fullName = name,
                        class = fileName,
                        group = 1,
                        role = assignedRole,
                        online = UnitIsConnected(unit),
                        index = i,
                    })
                end
            end
        end
    end
    return roster
end

------------------------------------------------------------
-- Shared section layout helpers (consistent across all tabs)
------------------------------------------------------------
-- Padding comes from the shell, not from here. Every page had picked
-- its own -- 12 in four, 14 in three -- so each sat to a different
-- rhythm from the chrome around it and from the others. One source
-- means a spacing change lands everywhere at once.
local SECTION_PAD = (ns.Shell and ns.Shell.PAD) or 14
local SECTION_LINE_H = 20

-- This is the page's only rule. It was briefly emptied on the assumption
-- it followed a section header that carried its own -- but that header
-- factory turned out never to have been called, so emptying this left
-- the page with no divider at all. Colour comes from the skin now, which
-- is the part that was actually worth changing.
local function MakeDivider(parent, y)
    local div = parent:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT", SECTION_PAD - 2, y + 2)
    div:SetPoint("RIGHT", parent, "RIGHT", -SECTION_PAD, 0)
    local r, g, b = ns.Widgets:Color("muted")
    div:SetColorTexture(r, g, b, 0.30)
    return y - 8
end

------------------------------------------------------------
-- Consumable / buff checking
-- Note: In 12.0+, aura name fields on other players are secret/tainted strings.
-- We use spellId-based detection instead of name matching.
------------------------------------------------------------

-- Spell IDs sourced from the shared registry in Core/Data.lua. These were
-- previously duplicated locally and had drifted — the flask IDs here were
-- still Dragonflight-era values while ReadyCheck.lua already carried the
-- current Midnight S1 pool. Registering both files against the same list
-- guarantees they agree on what counts as a consumable.
local function AsIDSet(list)
    local set = {}
    for _, id in ipairs(list) do set[id] = true end
    return set
end
local FLASK_SPELL_IDS = AsIDSet(ns.CONSUMABLE_SPELL_IDS.FLASK)
local FOOD_SPELL_IDS  = AsIDSet(ns.CONSUMABLE_SPELL_IDS.FOOD)

local RUNE_SPELL_IDS = {
    [453247] = true, -- Void-Touched Augment Rune
    [393438] = true, -- Crystallized Augment Rune
}

local function HasBuff(unit, checkFunc)
    for i = 1, 40 do
        local data = C_UnitAuras and C_UnitAuras.GetBuffDataByIndex(unit, i)
        if not data then break end
        local ok, result = pcall(checkFunc, data)
        if ok and result then return true end
    end
    return false
end

local function HasFlask(unit)
    return HasBuff(unit, function(data)
        -- Check by spell ID first (reliable, works with tainted names)
        if data.spellId and FLASK_SPELL_IDS[data.spellId] then return true end
        -- Fallback: long duration buff (>30min) from self that isn't harmful
        if data.duration and data.duration >= 1800 and data.isFromPlayerOrPlayerPet and not data.isHarmful then
            -- Try name match with pcall (works for own buffs, tainted for others)
            local ok, name = pcall(tostring, data.name)
            if ok and name then
                if name:find("Flask") or name:find("Phial") or name:find("Tempered") then return true end
            end
        end
        return false
    end)
end

local function HasFood(unit)
    return HasBuff(unit, function(data)
        if data.spellId and FOOD_SPELL_IDS[data.spellId] then return true end
        -- Well Fed has many spell IDs across expansions; try name as fallback
        local ok, name = pcall(tostring, data.name)
        if ok and name and name:find("Well Fed") then return true end
        return false
    end)
end

local function HasAugmentRune(unit)
    return HasBuff(unit, function(data)
        if data.spellId and RUNE_SPELL_IDS[data.spellId] then return true end
        local ok, name = pcall(tostring, data.name)
        if ok and name and (name:find("Augment") or name:find("Crystallized")) then return true end
        return false
    end)
end

local function GetUnitForRosterIndex(index, isRaid)
    if isRaid then
        return "raid" .. index
    else
        if index == 1 then return "player" end
        return "party" .. (index - 1)
    end
end

-- Helper: format a player name with class color
local function ColorName(p)
    local cc = CLASS_COLORS[p.class] or { 0.7, 0.7, 0.7 }
    local hex = string.format("ff%02x%02x%02x", cc[1] * 255, cc[2] * 255, cc[3] * 255)
    return "|c" .. hex .. p.name .. "|r"
end

------------------------------------------------------------
-- Overview tab content
------------------------------------------------------------
local ovPool = {}
local ovPoolIdx = 0

local function OvAcquire(parent, font)
    ovPoolIdx = ovPoolIdx + 1
    local fs = ovPool[ovPoolIdx]
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
        ovPool[ovPoolIdx] = fs
    else
        fs:SetFontObject(font or "GameFontNormal")
        fs:SetTextColor(1, 1, 1)
    end
    fs:ClearAllPoints()
    fs:SetWordWrap(false)
    fs:SetWidth(raidFrame:GetWidth() - 28)
    fs:SetJustifyH("LEFT")
    fs:Show()
    return fs
end

------------------------------------------------------------
-- The empty state.
--
-- This page reads a group, and most of the time you open it there is
-- not one -- so the no-group case is not an edge case, it is the
-- common one. It was four words in the top-left corner of an
-- otherwise blank page, which reads as something failing to load
-- rather than as a page waiting for a group.
--
-- Built once and cached on the container: the pool above holds font
-- strings only, so a ring texture made on every refresh would leak
-- one per refresh.
------------------------------------------------------------
local function OverviewEmptyState()
    if overviewContainer._empty then return overviewContainer._empty end

    local W = ns.Widgets
    local e = CreateFrame("Frame", nil, overviewContainer)
    e:SetPoint("TOP", overviewContainer, "TOP", 0, -70)
    e:SetPoint("LEFT", overviewContainer, "LEFT", 0, 0)
    e:SetPoint("RIGHT", overviewContainer, "RIGHT", 0, 0)
    e:SetHeight(190)

    -- One of the addon own shapes rather than a game icon: a file we
    -- ship cannot be missing, and a ring is how this UI draws a group
    -- everywhere else.
    e.ring = e:CreateTexture(nil, "ARTWORK")
    e.ring:SetSize(54, 54)
    e.ring:SetPoint("TOP", e, "TOP", 0, 0)
    e.ring:SetTexture([[Interface\AddOns\YippYappHelper\Media\CircleRing]])
    e.ring:SetVertexColor(W:Color("faint"))
    e.ring:SetAlpha(0.7)

    e.title = W:Label(e, "GameFontNormalLarge", "CENTER")
    e.title:SetPoint("TOP", e.ring, "BOTTOM", 0, -12)
    e.title:SetPoint("LEFT", e, "LEFT", 0, 0)
    e.title:SetPoint("RIGHT", e, "RIGHT", 0, 0)
    e.title:SetText("Not in a group")

    -- What the page WILL show, not only what it cannot. An empty state
    -- that reports the absence teaches nothing, and this is the one
    -- moment the page gets to explain itself.
    e.body = W:Label(e, "GameFontNormal", "CENTER")
    e.body:SetPoint("TOP", e.title, "BOTTOM", 0, -10)
    e.body:SetPoint("LEFT", e, "LEFT", 24, 0)
    e.body:SetPoint("RIGHT", e, "RIGHT", -24, 0)
    e.body:SetTextColor(W:Color("muted"))
    e.body:SetText("Join a party or raid and this fills in with your roster and "
        .. "roles, the group composition, which raid buffs nobody is bringing, "
        .. "and who still has no food or flask.")

    overviewContainer._empty = e
    return e
end
function ns:RefreshRaidOverview()
    for i = 1, ovPoolIdx do ovPool[i]:Hide() end
    ovPoolIdx = 0

    local roster = GetRaidRoster()

    if #roster == 0 then
        OverviewEmptyState():Show()
        return
    end
    if overviewContainer._empty then overviewContainer._empty:Hide() end

    local tanks, healers, dps = 0, 0, 0
    local classCounts = {}
    for _, p in ipairs(roster) do
        if p.role == "TANK" then tanks = tanks + 1
        elseif p.role == "HEALER" then healers = healers + 1
        else dps = dps + 1 end
        classCounts[p.class] = (classCounts[p.class] or 0) + 1
    end

    -- ── Two-column layout ──
    -- Left: Group roster
    -- Right: Composition + Buffs + Consumables
    local fw = raidFrame:GetWidth() - 28
    local rightX = math.floor(fw * 0.55) + SECTION_PAD  -- right column starts at ~55%
    local rightW = fw - rightX + SECTION_PAD

    -- ── RIGHT COLUMN ──
    local ry = -8

    -- Composition (large, prominent)
    local compFs = OvAcquire(overviewContainer, "GameFontNormalLarge")
    compFs:SetPoint("TOPLEFT", rightX, ry)
    compFs:SetWidth(rightW)
    compFs:SetText("|cff8888ff" .. tanks .. " Tank|r   " ..
        "|cff00ff00" .. healers .. " Heal|r   " ..
        "|cffff4444" .. dps .. " DPS|r")
    ns.ApplyTextShadow(compFs)
    ry = ry - 22

    local totalFs = OvAcquire(overviewContainer, "GameFontNormalSmall")
    totalFs:SetPoint("TOPLEFT", rightX, ry)
    totalFs:SetTextColor(unpack(ns.COLORS.TEXT_TERTIARY))
    totalFs:SetText(#roster .. " players in group")
    ry = ry - 20

    -- Raid Buffs icon strip. Icons with a green border = present in raid;
    -- desaturated + red border = missing. Hover any icon for name + status.
    local buffHdr = OvAcquire(overviewContainer, "GameFontNormal")
    buffHdr:SetPoint("TOPLEFT", rightX, ry)
    buffHdr:SetTextColor(unpack(ns.COLORS.TEXT_HEADER))
    buffHdr:SetText("Raid Buffs")
    ns.ApplyTextShadow(buffHdr)
    ry = ry - SECTION_LINE_H

    local BUFF_ICON_SIZE = 34
    local BUFF_ICON_GAP  = 5
    -- Fit as many icons per row as the right column can hold; wrap if
    -- the list grows beyond what fits in one row. Current 6 buffs fit
    -- easily in one row on any normal raid-frame width.
    local iconsPerRow = math.max(1,
        math.floor((rightW - 4) / (BUFF_ICON_SIZE + BUFF_ICON_GAP)))
    local rowsUsed = 0
    for i, rb in ipairs(RAID_BUFFS) do
        local icon = EnsureBuffIconFrame(i, overviewContainer, BUFF_ICON_SIZE)
        local col = (i - 1) % iconsPerRow
        local row = math.floor((i - 1) / iconsPerRow)
        rowsUsed = math.max(rowsUsed, row + 1)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", overviewContainer, "TOPLEFT",
            rightX + 4 + col * (BUFF_ICON_SIZE + BUFF_ICON_GAP),
            ry - row * (BUFF_ICON_SIZE + BUFF_ICON_GAP))

        -- Resolve icon: prefer spellID lookup, fall back to static path.
        local iconID = rb.fallbackIcon or 134400
        if rb.spellID and C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(rb.spellID)
            if info and info.iconID then iconID = info.iconID end
        end
        icon.tex:SetTexture(iconID)

        local have = classCounts[rb.file] and classCounts[rb.file] > 0
        if have then
            icon.tex:SetDesaturated(false)
            icon.tex:SetVertexColor(1, 1, 1, 1)
            icon:SetBackdropBorderColor(0.0, 0.85, 0.35, 1)
            icon:SetAlpha(1)
        else
            -- Keep the icon visible so the raid leader can still see
            -- *which* buffs are missing, but heavily desaturate it so
            -- the eye reads "off" at a glance: full greyscale + dim
            -- vertex color + low overall alpha + dull red border.
            icon.tex:SetDesaturated(true)
            icon.tex:SetVertexColor(0.35, 0.35, 0.35, 1)
            icon:SetBackdropBorderColor(0.45, 0.12, 0.12, 0.9)
            icon:SetAlpha(0.55)
        end

        icon._buffName = rb.buff
        icon._desc     = rb.desc
        icon._present  = have
        icon:Show()
    end
    -- Hide any surplus icons from a previous render with more buffs.
    for i = #RAID_BUFFS + 1, #buffIconFrames do
        buffIconFrames[i]:Hide()
    end

    ry = ry - rowsUsed * (BUFF_ICON_SIZE + BUFF_ICON_GAP) - 4

    -- Consumables
    local isRaid = IsInRaid()
    local flaskCount, foodCount, runeCount = 0, 0, 0
    local missingFlask, missingFood = {}, {}

    for _, p in ipairs(roster) do
        local unit = GetUnitForRosterIndex(p.index, isRaid)
        if UnitExists(unit) and UnitIsConnected(unit) then
            if HasFlask(unit) then
                flaskCount = flaskCount + 1
            else
                table.insert(missingFlask, p)
            end
            if HasFood(unit) then
                foodCount = foodCount + 1
            else
                table.insert(missingFood, p)
            end
            if HasAugmentRune(unit) then
                runeCount = runeCount + 1
            end
        end
    end

    local consHdr = OvAcquire(overviewContainer, "GameFontNormal")
    consHdr:SetPoint("TOPLEFT", rightX, ry)
    consHdr:SetWidth(rightW)
    consHdr:SetTextColor(unpack(ns.COLORS.TEXT_HEADER))
    consHdr:SetText("Consumables")
    ns.ApplyTextShadow(consHdr)
    ry = ry - SECTION_LINE_H

    local total = #roster
    local flaskColor = flaskCount == total and "ff00ff00" or (flaskCount >= total * 0.8 and "ffffff00" or "ffff4444")
    local foodColor = foodCount == total and "ff00ff00" or (foodCount >= total * 0.8 and "ffffff00" or "ffff4444")
    local runeColor = runeCount == total and "ff00ff00" or "ff888888"

    -- Flask line
    local flaskFs = OvAcquire(overviewContainer, "GameFontNormal")
    flaskFs:SetPoint("TOPLEFT", rightX + 4, ry)
    flaskFs:SetWidth(rightW)
    local flaskNames = ""
    if #missingFlask > 0 and #missingFlask <= 4 then
        local names = {}
        for _, p in ipairs(missingFlask) do table.insert(names, ColorName(p)) end
        flaskNames = "  |cff555555-|r " .. table.concat(names, " ")
    elseif #missingFlask > 4 then
        flaskNames = "  |cffff4444" .. #missingFlask .. " missing|r"
    end
    flaskFs:SetText("|c" .. flaskColor .. flaskCount .. "/" .. total .. "|r  Flask" .. flaskNames)
    ry = ry - 17

    -- Food line
    local foodFs = OvAcquire(overviewContainer, "GameFontNormal")
    foodFs:SetPoint("TOPLEFT", rightX + 4, ry)
    foodFs:SetWidth(rightW)
    local foodNames = ""
    if #missingFood > 0 and #missingFood <= 4 then
        local names = {}
        for _, p in ipairs(missingFood) do table.insert(names, ColorName(p)) end
        foodNames = "  |cff555555-|r " .. table.concat(names, " ")
    elseif #missingFood > 4 then
        foodNames = "  |cffff4444" .. #missingFood .. " missing|r"
    end
    foodFs:SetText("|c" .. foodColor .. foodCount .. "/" .. total .. "|r  Food" .. foodNames)
    ry = ry - 17

    -- Rune line
    local runeFs = OvAcquire(overviewContainer, "GameFontNormal")
    runeFs:SetPoint("TOPLEFT", rightX + 4, ry)
    runeFs:SetWidth(rightW)
    runeFs:SetText("|c" .. runeColor .. runeCount .. "/" .. total .. "|r  Augment Rune")

    -- ── LEFT COLUMN: group roster (starts from top, full left side) ──
    ns:RefreshRaidGroups(roster, -8)
end

------------------------------------------------------------
-- Groups tab content
------------------------------------------------------------
local grpPool = {}
local grpPoolIdx = 0

local function GrpAcquire(parent, font)
    grpPoolIdx = grpPoolIdx + 1
    local fs = grpPool[grpPoolIdx]
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
        grpPool[grpPoolIdx] = fs
    else
        fs:SetFontObject(font or "GameFontNormal")
        fs:SetTextColor(1, 1, 1)
    end
    fs:ClearAllPoints()
    -- Reset width / justify on every acquisition. Previously a slot
    -- that a caller had SetWidth-constrained (e.g. a split-balance
    -- cell at 40px) kept that width on reuse, which truncated later
    -- uses like the "Split Balance" / "Suggested Swaps" headers into
    -- "split..." / "sugg...". SetWidth(0) returns the font string to
    -- auto-sizing; SetJustifyH("LEFT") is our default alignment.
    fs:SetWidth(0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:Show()
    return fs
end

function ns:RefreshRaidGroups(roster, startY)
    for i = 1, grpPoolIdx do grpPool[i]:Hide() end
    grpPoolIdx = 0

    -- If called standalone (from SetRaidTab), fetch roster ourselves
    if not roster then
        roster = GetRaidRoster()
    end
    local baseY = startY or -8

    if #roster == 0 then
        return
    end

    -- Sort roster into groups
    local groups = {}
    for i = 1, 8 do groups[i] = {} end
    for _, p in ipairs(roster) do
        local g = p.group or 1
        if g >= 1 and g <= 8 then
            table.insert(groups[g], p)
        end
    end

    local maxGroup = 0
    for g = 1, 8 do
        if #groups[g] > 0 then maxGroup = g end
    end

    -- ── Group display — left 55% of the frame ──
    -- Two rows, columns scale to cover every populated group up to 8.
    -- Top row = odd groups, bottom row = even.
    local fw = math.floor((raidFrame:GetWidth() - 28) * 0.55)
    local memberLineH = 18
    local groupBlockH = 22 + 5 * memberLineH + 10

    local grpStartY = MakeDivider(groupsContainer, baseY)

    -- Build rowOrder dynamically so groups 7-8 are visible if populated.
    local rowOrder = { {}, {} }
    for g = 1, math.max(6, maxGroup) do
        local row = (g % 2 == 1) and 1 or 2
        table.insert(rowOrder[row], g)
    end
    local colCount = math.max(3, math.max(#rowOrder[1], #rowOrder[2]))
    local colW = math.floor(fw / colCount)

    for row, groupNums in ipairs(rowOrder) do
        for col, g in ipairs(groupNums) do
            if g <= maxGroup and #groups[g] > 0 then
                local x = SECTION_PAD + (col - 1) * colW
                local cellY = grpStartY - (row - 1) * groupBlockH

                local hdr = GrpAcquire(groupsContainer, "GameFontNormal")
                hdr:SetPoint("TOPLEFT", groupsContainer, "TOPLEFT", x, cellY)
                hdr:SetText("|cff" .. ns.Widgets:Hex("muted") .. "Group " .. g .. "|r")

                for j, p in ipairs(groups[g]) do
                    local mfs = GrpAcquire(groupsContainer, "GameFontNormal")
                    mfs:SetPoint("TOPLEFT", groupsContainer, "TOPLEFT", x + 8, cellY - 4 - j * memberLineH)
                    local roleTag = ROLE_PREFIX[p.role] or " "
                    mfs:SetText(roleTag .. " " .. ColorName(p))
                end
            end
        end
    end
end

------------------------------------------------------------
-- Performance tab (C_DamageMeter API)
------------------------------------------------------------
local perfPool = {}
local perfPoolIdx = 0

------------------------------------------------------------
-- Refresh tier display
------------------------------------------------------------
local tierRowPool = {}
local tierRowPoolIdx = 0

local function AcquireTierRow()
    tierRowPoolIdx = tierRowPoolIdx + 1
    local row = tierRowPool[tierRowPoolIdx]
    if not row then
        row = CreateFrame("Frame", nil, scrollContent)
        row:SetSize(RAID_WIDTH - 44, ROW_HEIGHT)
        row._bg = row:CreateTexture(nil, "BACKGROUND")
        row._bg:SetAllPoints()
        row._nameStr = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row._nameStr:SetPoint("LEFT", 2, 0)
        row._nameStr:SetWidth(120)
        row._nameStr:SetJustifyH("LEFT")
        row._nameStr:SetWordWrap(false)
        row._tierStr = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row._tierStr:SetPoint("LEFT", 126, 0)
        row._tierStr:SetWidth(70)
        row._tierStr:SetJustifyH("CENTER")
        row._piecesStr = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row._piecesStr:SetPoint("LEFT", row, "LEFT", 200, 0)
        row._piecesStr:SetWidth(140)
        row._piecesStr:SetJustifyH("LEFT")
        row._piecesStr:SetWordWrap(false)
        row._piecesStr:SetTextColor(0.6, 0.6, 0.6)
        tierRowPool[tierRowPoolIdx] = row
    end
    row:ClearAllPoints()
    row:Show()
    return row
end

function ns:RefreshRaidDisplay()
    for i = 1, tierRowPoolIdx do tierRowPool[i]:Hide() end
    tierRowPoolIdx = 0
    -- Also hide legacy rows if any
    for _, row in ipairs(ns.RaidRows) do row:Hide() end
    wipe(ns.RaidRows)

    local sorted = ns:GetSortedTierData()
    local summary = ns:GetTierSummary()

    summaryText:SetText(string.format(
        "%d players scanned | 2-set: |cff00ff00%d|r | 4-set: |cff00ff00%d|r | No tier: |cffff4444%d|r",
        summary.total, summary.with2set, summary.with4set, summary.counts[0] or 0
    ))

    local yOffset = 0
    for i, data in ipairs(sorted) do
        local row = AcquireTierRow()
        row:SetPoint("TOPLEFT", 0, -yOffset)

        if i % 2 == 0 then
            row._bg:SetColorTexture(1, 1, 1, 0.03)
            row._bg:Show()
        else
            row._bg:Hide()
        end

        local cc = CLASS_COLORS[data.class] or { 1, 1, 1 }
        row._nameStr:SetTextColor(cc[1], cc[2], cc[3])

        local displayName = data.name
        if data.tierCount >= 4 then
            displayName = displayName .. "  |cff888888PASS|r"
        end
        row._nameStr:SetText(displayName)

        local tc = TIER_COUNT_COLORS[data.tierCount] or { 1, 1, 1 }
        row._tierStr:SetTextColor(tc[1], tc[2], tc[3])

        local tierLabel = data.tierCount .. "/5"
        if data.tierCount >= 4 then
            tierLabel = tierLabel .. " (4-set)"
        elseif data.tierCount >= 2 then
            tierLabel = tierLabel .. " (2-set)"
        end
        row._tierStr:SetText(tierLabel)

        if data.tierCount >= 4 then
            row._piecesStr:SetText("max")
        elseif #data.tierSlots > 0 then
            row._piecesStr:SetText(table.concat(data.tierSlots, ", "))
        else
            row._piecesStr:SetText("--")
        end

        yOffset = yOffset + ROW_HEIGHT
    end

    scrollContent:SetHeight(math.max(yOffset, 1))
end

------------------------------------------------------------
-- Auto-refresh on roster changes
------------------------------------------------------------
local rosterEventFrame = CreateFrame("Frame")
rosterEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
rosterEventFrame:SetScript("OnEvent", function()
    -- Only refresh if the raid frame is visible and on the overview tab
    if raidFrame:IsShown() and currentTab == "overview" then
        ns:RefreshRaidOverview()
    end
end)
