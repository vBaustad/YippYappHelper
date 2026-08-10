local _, ns = ...

------------------------------------------------------------
-- Ready Check Window
------------------------------------------------------------

local WINDOW_WIDTH           = 600

local ROW_HEIGHT_FULL    = 22
local ROW_HEIGHT_COMPACT = 17
local HEADER_HEIGHT      = 30
local BOTTOM_PAD         = 6

local PAD                = 8
local STATUS_W           = 18
local NAME_W             = 130
local ICON_SIZE          = 18
local COL_W              = 38   -- column cell width (icon centered inside)

local COMPACT_COLS       = 4

------------------------------------------------------------
-- Check definitions — order drives the icon column order
------------------------------------------------------------
local function SpellIcon(spellID, fallback)
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
    if info and info.iconID then return info.iconID end
    return fallback or 134400
end

-- Spell-ID pools sourced from the shared registry in Core/Data.lua so
-- ReadyCheck and RaidUI agree on what counts as a flask/food/etc. The
-- local arrays are aliases — `AddFoodSpellIDs` style extenders append
-- here and into the shared registry so runtime additions propagate.
local FOOD_SPELL_IDS   = ns.CONSUMABLE_SPELL_IDS.FOOD
local FLASK_SPELL_IDS  = ns.CONSUMABLE_SPELL_IDS.FLASK
local BRONZE_SPELL_IDS = ns.CONSUMABLE_SPELL_IDS.BRONZE

local function SpellIDSet(list)
    local set = {}
    for _, id in ipairs(list) do set[id] = true end
    return set
end
local foodSet   = SpellIDSet(FOOD_SPELL_IDS)
local flaskSet  = SpellIDSet(FLASK_SPELL_IDS)
local bronzeSet = SpellIDSet(BRONZE_SPELL_IDS)

-- Raid-buff stat aura IDs. Consumed as a table lookup (not a chain of
-- `sid == N` comparisons) because in 11.x, aura fields returned by
-- C_UnitAuras.GetAuraDataByIndex are tagged "secret values" and a direct
-- == compare under our own taint raises "attempt to compare local 'sid'
-- (a secret number value, while execution tainted by 'YippYappHelper')".
-- 12.x further tightened this: indexing ANY table with a secret key now
-- raises "attempted to index a table that cannot be indexed with secret
-- keys". `SafeLookup` wraps the index in pcall so a tainted aura can no
-- longer abort the whole HELPFUL scan.
local STAT_BUFF_IDS = {
    [1459]   = "int",
    [6673]   = "ap",
    [1126]   = "vers",
    [21562]  = "stam",
    [462854] = "haste",
}

-- Icon fallbacks. Flask/phial uses 134873 (a reliable alchemy bottle) —
-- the 1417734 FileDataID was showing as a blank green square on some clients.
-- Food iconID is overridden per-player (uses their Well Fed aura's actual
-- icon, or a generic food icon when still channel-eating).
-- Use texture paths instead of numeric FileDataIDs. Paths like
-- "Interface\\Icons\\<name>" are stable across patches; FileDataIDs
-- occasionally get renumbered or stop resolving (causing green squares).
local ICON_FOOD_GENERIC   = "Interface\\Icons\\INV_Misc_Food_145"
local ICON_FLASK_FALLBACK = "Interface\\Icons\\INV_Alchemy_EndlessFlask_01"
local ICON_DURABILITY     = "Interface\\Icons\\INV_Hammer_17"

local ICON_VANTUS = "Interface\\Icons\\INV_Inscription_80_VantusRune_Demons"

-- Column order and per-column detection. Left to right.
local CHECKS_META = {
    { key = "food",   header = "Food",   label = "Food",                              iconID = ICON_FOOD_GENERIC },
    { key = "flask",  header = "Flask",  label = "Flask / Phial",                     iconID = ICON_FLASK_FALLBACK },
    { key = "vantus", header = "Vantus", label = "Vantus Rune",                       iconID = ICON_VANTUS },
    { key = "int",    header = "Int",    label = "Intellect (Arcane Intellect)",      spellID = 1459  },
    { key = "ap",     header = "AP",     label = "Attack Power (Battle Shout)",       spellID = 6673  },
    { key = "vers",   header = "Vers",   label = "Versatility (Mark of the Wild)",    spellID = 1126  },
    { key = "stam",   header = "Stam",   label = "Stamina (Power Word: Fortitude)",   spellID = 21562 },
    { key = "haste",  header = "Haste",  label = "Haste / Crit (Skyfury)",            spellID = 462854 },
    { key = "move",   header = "Move",   label = "Movement (Blessing of the Bronze)", iconID = 4622448 },
    { key = "dur",    header = "Dur",    label = "Durability",                        iconID = ICON_DURABILITY },
}

local iconsResolved = false
local function ResolveCheckIcons()
    if iconsResolved then return end
    for _, c in ipairs(CHECKS_META) do
        if c.spellID then c.iconID = SpellIcon(c.spellID, c.iconID) end
    end
    iconsResolved = true
end

------------------------------------------------------------
-- SavedVariables
------------------------------------------------------------
local function DB()
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.readyCheck = YippYappHelperDB.readyCheck or {
        enabled   = true,
        collapsed = false,
        -- TOPLEFT anchor is filled in lazily on first show, centered on
        -- screen. SetHeight only affects the bottom edge afterwards, so
        -- the header buttons stay put when collapsing/expanding.
        anchorLeft = nil, anchorTop = nil,
    }
    return YippYappHelperDB.readyCheck
end

------------------------------------------------------------
-- Buff detection
------------------------------------------------------------
local function UnitHasAuraByName(unit, name)
    if not unit or not UnitExists(unit) then return false end
    return C_UnitAuras.GetAuraDataBySpellName(unit, name, "HELPFUL") ~= nil
end

-- Returns the matching aura table (or nil). Lets callers show details in tooltip.
local function FindAura(unit, predicate)
    if not unit or not UnitExists(unit) then return nil end
    local i = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then return nil end
        if predicate(aura) then return aura end
        i = i + 1
    end
end

-- Finds the "Well Fed" aura (post-eating buff). Returns the aura table so
-- callers can use its actual food-item icon instead of a generic one.
local function FindWellFed(unit)
    return FindAura(unit, function(a)
        if a.spellId and foodSet[a.spellId] then return true end
        return a.name == "Well Fed"
    end)
end

-- Returns true if the unit is currently channelling a food/drink aura.
-- The channel aura is literally named "Food" or "Drink" in English; most
-- food items cast one of a handful of well-known channel spells.
local EATING_AURA_NAMES = { Food = true, Drink = true, Refreshment = true }
local function IsEating(unit)
    return FindAura(unit, function(a)
        return a.name and EATING_AURA_NAMES[a.name]
    end) ~= nil
end

-- Food column state. Returns one of:
--   { state = "wellfed", aura = <auraTable> }  — show aura.icon, steady
--   { state = "eating",  aura = nil }          — show generic food icon, pulsing
--   { state = "missing" }                      — empty square
local function EvalFood(unit)
    local wf = FindWellFed(unit)
    if wf then return { state = "wellfed", aura = wf } end
    if IsEating(unit) then return { state = "eating" } end
    return { state = "missing" }
end

local function FindFlask(unit)
    return FindAura(unit, function(a)
        if a.spellId and flaskSet[a.spellId] then return true end
        if not a.name then return false end
        return a.name:find("^Phial of ") or a.name:find("^Flask of ")
    end)
end

local function FindVantus(unit)
    return FindAura(unit, function(a)
        return a.name and a.name:find("^Vantus Rune:")
    end)
end

-- Blessing of the Bronze grants a per-class spellID; any of them counts.
local function FindBronze(unit)
    return FindAura(unit, function(a) return a.spellId and bronzeSet[a.spellId] end)
end

------------------------------------------------------------
-- Durability
-- GetInventoryItemDurability only reports the player's own gear, so we
-- share each raider's % via a lightweight addon comm on ready-check.
------------------------------------------------------------
local DURABILITY_PREFIX = "YYHDUR"
C_ChatInfo.RegisterAddonMessagePrefix(DURABILITY_PREFIX)

local durabilityCache = {}  -- [shortName] = { pct = <0..100>, ts = GetTime() }
local DURABILITY_TTL = 600  -- 10 min

local function ComputeOwnDurability()
    local current, max = 0, 0
    for slot = 1, 18 do
        local cur, m = GetInventoryItemDurability(slot)
        if cur and m and m > 0 then
            current = current + cur
            max     = max + m
        end
    end
    if max == 0 then return nil end
    return math.floor(current / max * 100 + 0.5)
end

local function BroadcastOwnDurability()
    local pct = ComputeOwnDurability()
    if not pct then return end
    local shortName = Ambiguate(UnitName("player"), "short")
    durabilityCache[shortName] = { pct = pct, ts = GetTime() }
    if not IsInGroup() then return end
    local channel = IsInRaid() and "RAID" or "PARTY"
    -- Random 0-1.5s stagger so 30 raiders don't all flood CHAT_MSG_ADDON
    -- in the same tick (Blizzard throttles/drops bursts).
    C_Timer.After(math.random() * 1.5, function()
        C_ChatInfo.SendAddonMessage(DURABILITY_PREFIX, tostring(pct), channel)
    end)
end

local function GetDurabilityFor(unit)
    if UnitIsUnit(unit, "player") then
        return ComputeOwnDurability()
    end
    local raw = UnitName(unit)
    if not raw then return nil end
    -- Cache key matches the format used on receive (Ambiguate short).
    local short = Ambiguate(raw, "short")
    local entry = durabilityCache[short] or durabilityCache[raw]
    if entry and (GetTime() - entry.ts) < DURABILITY_TTL then
        return entry.pct
    end
    return nil
end


------------------------------------------------------------
-- Window shell
------------------------------------------------------------
local frame = CreateFrame("Frame", "YippYappReadyCheck", UIParent, "BackdropTemplate")
frame:SetSize(WINDOW_WIDTH, 240)
frame:SetScale(0.85)
frame:SetFrameStrata("FULLSCREEN_DIALOG")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local db = DB()
    -- Save the frame's current anchor state directly. More robust than
    -- GetLeft/GetTop subtraction, which can get the wrong sign or be
    -- off by effective-scale when UIParent ≠ frame scale.
    local point, _, relativePoint, x, y = self:GetPoint()
    if point then
        db.point          = point
        db.relativePoint  = relativePoint
        db.x              = x
        db.y              = y
        -- Keep legacy fields in sync so an old-schema read still works.
        db.anchorLeft = x
        db.anchorTop  = y
    end
end)
frame:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 },
})
frame:SetBackdropColor(0.06, 0.06, 0.06, 0.72)
frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.85)
frame:Hide()

-- Forward declaration — wired up once EnableAuraTracking is defined below.
local onReadyCheckFrameHide
frame:SetScript("OnHide", function()
    if onReadyCheckFrameHide then onReadyCheckFrameHide() end
end)

-- Header
local titleIcon, title = ns.MakeWindowHeader(frame, nil, nil, PAD)
title:SetText("|cff00aaffReady Check|r")

local countdown = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
countdown:SetPoint("LEFT", title, "RIGHT", 10, 0)

local summary = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
summary:SetPoint("TOPRIGHT", -64, -14)
summary:SetJustifyH("RIGHT")

-- Custom-styled header buttons matching the rest of the addon (BackdropTemplate
-- + tooltip border, cyan hover). ASCII "+" / "−" / "×" render reliably in
-- FRIZQT__.TTF, unlike the Unicode ▲/▼ triangles.
local function MakeHeaderButton(parent, glyph, size, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(size, size)
    b:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    b:SetBackdropColor(0.10, 0.10, 0.10, 0.9)
    b:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)

    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER", 0, 0)
    fs:SetText(glyph)
    fs:SetTextColor(0.85, 0.85, 0.85)
    b._label = fs

    b:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.0, 0.8, 1.0, 1)
        self._label:SetTextColor(1, 1, 1)
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
        self._label:SetTextColor(0.85, 0.85, 0.85)
    end)
    b:SetScript("OnClick", onClick)
    return b
end

-- Collapse / expand toggle
local collapseBtn = MakeHeaderButton(frame, "−", 20, nil)
collapseBtn:SetPoint("TOPRIGHT", -34, -10)

local function UpdateCollapseTexture()
    collapseBtn._label:SetText(DB().collapsed and "+" or "−")
end
UpdateCollapseTexture()

-- Close button (custom, replacing Blizzard UIPanelCloseButton).
-- Anchored a couple extra pixels in from the right so its 1px border
-- doesn't get clipped by the frame's own edge.
local closeBtn = MakeHeaderButton(frame, "×", 20, function() frame:Hide() end)
closeBtn:SetPoint("TOPRIGHT", -12, -10)

-- Column header (shown in full view only)
local headerRow = CreateFrame("Frame", nil, frame)
headerRow:SetHeight(16)
headerRow:SetPoint("TOPLEFT",  PAD, -HEADER_HEIGHT)
headerRow:SetPoint("TOPRIGHT", -PAD, -HEADER_HEIGHT)

local headerLabels = {}
for i, meta in ipairs(CHECKS_META) do
    local fs = headerRow:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fs:SetText(meta.header)
    fs:SetTextColor(0.75, 0.75, 0.75)
    fs:SetJustifyH("CENTER")
    headerLabels[i] = fs
end

-- Vertical column dividers (drawn behind the roster rows).
local columnDividerFrame = CreateFrame("Frame", nil, frame)
columnDividerFrame:SetPoint("TOPLEFT",  frame, "TOPLEFT",  0, -(HEADER_HEIGHT + 18))
columnDividerFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, BOTTOM_PAD)
columnDividerFrame:SetFrameLevel(frame:GetFrameLevel())

local columnDividers = {}
for i = 1, #CHECKS_META + 1 do
    local line = columnDividerFrame:CreateTexture(nil, "ARTWORK")
    line:SetWidth(1)
    line:SetColorTexture(0.22, 0.22, 0.22, 0.9)
    columnDividers[i] = line
end

-- Horizontal line closing the grid below the last row.
local bottomDivider = frame:CreateTexture(nil, "ARTWORK")
bottomDivider:SetHeight(1)
bottomDivider:SetColorTexture(0.25, 0.25, 0.25, 0.6)
bottomDivider:Hide()

local divider = frame:CreateTexture(nil, "ARTWORK")
divider:SetHeight(1)
divider:SetPoint("TOPLEFT",  8, -(HEADER_HEIGHT + 18))
divider:SetPoint("TOPRIGHT", -8, -(HEADER_HEIGHT + 18))
divider:SetColorTexture(0.25, 0.25, 0.25, 0.6)

-- Forward declaration; Render is defined further below.
local Render

------------------------------------------------------------
-- Status icon helper
-- Blizzard's standard ready-check textures: show no border/bg.
------------------------------------------------------------
local READY_TEX    = "Interface\\RaidFrame\\ReadyCheck-Ready"
local NOTREADY_TEX = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local WAITING_TEX  = "Interface\\RaidFrame\\ReadyCheck-Waiting"

-- Authoritative ready-state map fed from event arguments. Keyed by name so
-- it survives unitID churn across READY_CHECK_CONFIRM ticks. Reset on each
-- fresh READY_CHECK. Values: "ready" | "notready" | nil (pending).
local readyStatus = {}

local function GetReadyFor(unit)
    local raw = UnitName(unit)
    local name = raw and Ambiguate(raw, "short")
    return name and readyStatus[name] or nil
end

local function ApplyStatusTexture(texture, unit)
    local status = GetReadyCheckStatus(unit)
    if status == "ready" then
        texture:SetTexture(READY_TEX); return true
    elseif status == "notready" then
        texture:SetTexture(NOTREADY_TEX); return false
    else
        texture:SetTexture(WAITING_TEX); return nil
    end
end

------------------------------------------------------------
-- Full-view row pool (status + name + icon strip)
-- Rows are created once and reused in-place across renders. Previously each
-- render did Release/Acquire (hide-all-then-show-again) + ClearAllPoints on
-- every icon, which at 30 raiders × 10 icons = ~600 wasted SetPoint calls
-- and 60 Show/Hide flips per refresh.
------------------------------------------------------------
local fullRows = {}  -- persistent list; length grows monotonically

-- Layout positions only depend on constants (PAD, STATUS_W, NAME_W, COL_W,
-- ICON_SIZE, #CHECKS_META) so they can be computed once at load time.
local ICON_XS = {}
local COLUMN_BOUNDARIES = {}
do
    local colStart = PAD + STATUS_W + 8 + NAME_W + 10
    for i = 1, #CHECKS_META do
        local cellCenter = colStart + (i - 1) * COL_W + COL_W / 2
        ICON_XS[i] = cellCenter - ICON_SIZE / 2
    end
    for i = 0, #CHECKS_META do
        COLUMN_BOUNDARIES[i + 1] = colStart + i * COL_W
    end
end

local function MakeFullRow()
    local row = CreateFrame("Frame", nil, frame)
    row:SetHeight(ROW_HEIGHT_FULL)
    row:Hide()

    row.status = row:CreateTexture(nil, "ARTWORK")
    row.status:SetSize(STATUS_W, STATUS_W)
    row.status:SetPoint("LEFT", PAD, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", row.status, "RIGHT", 8, 0)
    row.name:SetWidth(NAME_W)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.icons = {}
    for i = 1, #CHECKS_META do
        local btn = CreateFrame("Frame", nil, row, "BackdropTemplate")
        btn:SetSize(ICON_SIZE, ICON_SIZE)
        -- Icon x-position within the row is a fixed layout constant, so
        -- anchor once at creation rather than re-anchoring every render.
        btn:SetPoint("LEFT", row, "LEFT", ICON_XS[i], 0)
        btn:EnableMouse(true)

        -- Empty-slot look: dark fill + subtle border, always present.
        btn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets   = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        btn:SetBackdropColor(0.10, 0.10, 0.10, 0.9)
        btn:SetBackdropBorderColor(0.32, 0.32, 0.32, 1)

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", 1, -1)
        tex:SetPoint("BOTTOMRIGHT", -1, 1)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.tex = tex

        -- Pulse animation for "actively eating" state
        btn.pulse = btn:CreateAnimationGroup()
        btn.pulse:SetLooping("REPEAT")
        local p1 = btn.pulse:CreateAnimation("Alpha")
        p1:SetFromAlpha(1); p1:SetToAlpha(0.35); p1:SetDuration(0.6); p1:SetOrder(1)
        local p2 = btn.pulse:CreateAnimation("Alpha")
        p2:SetFromAlpha(0.35); p2:SetToAlpha(1); p2:SetDuration(0.6); p2:SetOrder(2)

        -- Text overlay for numeric values (durability %)
        local textFs = btn:CreateFontString(nil, "OVERLAY")
        textFs:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        textFs:SetPoint("CENTER", 0, 0)
        textFs:Hide()
        btn.textFs = textFs

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            -- Tooltip must sit above our FULLSCREEN_DIALOG frame.
            GameTooltip:SetFrameStrata("TOOLTIP")
            GameTooltip:AddLine(CHECKS_META[i].label, 1, 1, 1)
            if self._present == true then
                GameTooltip:AddLine("|cff00ff00present|r")
                if self._aura and self._aura.name then
                    GameTooltip:AddLine(self._aura.name, 0.8, 0.8, 0.8)
                    local exp = self._aura.expirationTime or 0
                    if exp > 0 then
                        local remaining = math.max(0, math.floor(exp - GetTime()))
                        if remaining > 60 then
                            GameTooltip:AddLine(
                                string.format("|cffaaaaaa%dm %ds remaining|r",
                                    math.floor(remaining / 60), remaining % 60))
                        elseif remaining > 0 then
                            GameTooltip:AddLine(string.format("|cffaaaaaa%ds remaining|r", remaining))
                        end
                    end
                end
            elseif self._present == false then
                GameTooltip:AddLine("|cffff4040missing|r")
            else
                GameTooltip:AddLine("|cff888888n/a|r (out of range or not applicable)")
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- Make sure the icon frame sits above the row (for reliable mouse hits)
        btn:SetFrameLevel(row:GetFrameLevel() + 2)

        row.icons[i] = btn
    end
    return row
end

local FIRST_ROW_Y_FULL = -(HEADER_HEIGHT + 22)

local function EnsureFullRows(count)
    while #fullRows < count do
        local row = MakeFullRow()
        local idx = #fullRows + 1
        -- Each row's vertical position depends only on its index and fixed
        -- constants, so anchor once at creation.
        local y = FIRST_ROW_Y_FULL - (idx - 1) * ROW_HEIGHT_FULL
        row:SetPoint("TOPLEFT",  frame, "TOPLEFT",  0, y)
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, y)
        table.insert(fullRows, row)
    end
end

local function HideExtraFullRows(usedCount)
    for i = usedCount + 1, #fullRows do
        if fullRows[i]:IsShown() then fullRows[i]:Hide() end
    end
end

local function HideAllFullRows()
    for i = 1, #fullRows do
        if fullRows[i]:IsShown() then fullRows[i]:Hide() end
    end
end

-- opts: { present=bool|nil, iconID, aura, pulse=bool, text=string|nil, textColor={r,g,b} }
local function ApplyIconState(iconFrame, opts)
    local present = opts.present
    iconFrame._present = present
    iconFrame._aura    = opts.aura
    if iconFrame._textShown then
        iconFrame.textFs:Hide()
        iconFrame._textShown = false
    end
    -- Only stop the pulse if it was actually running. Calling Stop()
    -- unconditionally per render caused animation churn + visual flicker
    -- on every row of the readycheck list even when nothing changed.
    if opts.pulse ~= true and iconFrame._pulsing then
        iconFrame.pulse:Stop()
        iconFrame._pulsing = false
    end

    if opts.text then
        -- Text-only mode (durability %): no icon, no backdrop/border.
        iconFrame.tex:Hide()
        iconFrame.textFs:SetText(opts.text)
        local c = opts.textColor or { 1, 1, 1 }
        iconFrame.textFs:SetTextColor(c[1], c[2], c[3])
        iconFrame.textFs:Show()
        iconFrame._textShown = true
        iconFrame:SetBackdropColor(0, 0, 0, 0)
        iconFrame:SetBackdropBorderColor(0, 0, 0, 0)
        iconFrame:SetAlpha(1)
        return
    end
    -- Restore normal backdrop for icon-mode buttons (in case this frame was
    -- previously used in text mode on an earlier render).
    iconFrame:SetBackdropColor(0.10, 0.10, 0.10, 0.9)

    if present == true then
        iconFrame.tex:SetTexture(opts.iconID)
        iconFrame.tex:SetDesaturated(false)
        iconFrame.tex:SetVertexColor(1, 1, 1, 1)
        iconFrame.tex:Show()
        iconFrame:SetBackdropBorderColor(0.32, 0.32, 0.32, 1)
        iconFrame:SetAlpha(1)
        if opts.pulse and not iconFrame._pulsing then
            iconFrame.pulse:Play()
            iconFrame._pulsing = true
        end
    elseif present == false then
        iconFrame.tex:Hide()
        iconFrame:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
        iconFrame:SetAlpha(1)
    else
        iconFrame.tex:SetTexture(opts.iconID)
        iconFrame.tex:SetDesaturated(true)
        iconFrame.tex:SetVertexColor(0.5, 0.5, 0.5, 0.4)
        iconFrame.tex:Show()
        iconFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.6)
        iconFrame:SetAlpha(1)
    end
end

------------------------------------------------------------
-- Compact-view row pool (grid cells with just status + name)
-- Same persistent-rows pattern as full view.
------------------------------------------------------------
local compactRows = {}

local function MakeCompactRow()
    local row = CreateFrame("Frame", nil, frame)
    row:SetHeight(ROW_HEIGHT_COMPACT)
    row:Hide()
    row.cells = {}
    for i = 1, COMPACT_COLS do
        local cell = CreateFrame("Frame", nil, row)
        cell:SetHeight(ROW_HEIGHT_COMPACT)
        cell.status = cell:CreateTexture(nil, "ARTWORK")
        cell.status:SetSize(STATUS_W - 4, STATUS_W - 4)
        cell.status:SetPoint("LEFT", 4, 0)
        cell.name = cell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cell.name:SetPoint("LEFT", cell.status, "RIGHT", 4, 0)
        cell.name:SetJustifyH("LEFT")
        cell.name:SetWordWrap(false)
        row.cells[i] = cell
    end
    return row
end

local FIRST_ROW_Y_COMPACT = -(HEADER_HEIGHT + 6)
local COMPACT_COL_W = math.floor((WINDOW_WIDTH - 2 * PAD) / COMPACT_COLS)

local function EnsureCompactRows(count)
    while #compactRows < count do
        local row = MakeCompactRow()
        local idx = #compactRows + 1
        -- A "row" in compact view holds COMPACT_COLS cells. Row position
        -- depends only on its row index.
        local y = FIRST_ROW_Y_COMPACT - (idx - 1) * ROW_HEIGHT_COMPACT
        row:SetPoint("TOPLEFT",  frame, "TOPLEFT",  PAD, y)
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, y)
        -- Cells have fixed widths and positions within a row.
        for i, cell in ipairs(row.cells) do
            cell:SetWidth(COMPACT_COL_W)
            cell:SetPoint("LEFT", row, "LEFT", (i - 1) * COMPACT_COL_W, 0)
            cell.name:SetWidth(COMPACT_COL_W - STATUS_W - 12)
            cell:Hide()
        end
        table.insert(compactRows, row)
    end
end

local function HideExtraCompactRows(usedCount)
    for i = usedCount + 1, #compactRows do
        if compactRows[i]:IsShown() then compactRows[i]:Hide() end
    end
end

local function HideAllCompactRows()
    for i = 1, #compactRows do
        if compactRows[i]:IsShown() then compactRows[i]:Hide() end
    end
end

------------------------------------------------------------
-- Layout helpers
------------------------------------------------------------
------------------------------------------------------------
-- Test roster (for /yyhrc preview)
-- 24 fake raiders across classes with varied ready / buff / durability
-- states so every visual state in the window is exercised.
------------------------------------------------------------
local TEST_ROSTER = {
    { name = "Bloodfang",   class = "WARRIOR",     ready = "ready",    food = "wellfed", flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = true,  dur = 100 },
    { name = "Shadowblade", class = "ROGUE",       ready = "ready",    food = "wellfed", flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = true,  dur = 95 },
    { name = "Lightshield", class = "PALADIN",     ready = "ready",    food = "wellfed", flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = true,  dur = 82 },
    { name = "Frostwhisper", class = "MAGE",       ready = "ready",    food = "eating",  flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = true,  dur = 88 },
    { name = "Nightbloom",  class = "DRUID",       ready = "ready",    food = "wellfed", flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = true,  dur = 76 },
    { name = "Stormcaller", class = "SHAMAN",      ready = "ready",    food = "wellfed", flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = true,  dur = 91 },
    { name = "Voidspeaker", class = "WARLOCK",     ready = "notready", food = "wellfed", flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = true,  dur = 67 },
    { name = "Holyflame",   class = "PRIEST",      ready = "ready",    food = "wellfed", flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = true,  dur = 100 },
    { name = "Shadowhunt",  class = "HUNTER",      ready = "ready",    food = "missing", flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = true,  dur = 85 },
    { name = "Frostgrip",   class = "DEATHKNIGHT", ready = "ready",    food = "wellfed", flask = false, vantus = false, int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = true,  dur = 58 },
    { name = "Chiblast",    class = "MONK",        ready = "pending",  food = "eating",  flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = true,  dur = 72 },
    { name = "Felreaver",   class = "DEMONHUNTER", ready = "ready",    food = "wellfed", flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = true,  dur = 89 },
    { name = "Bronzewing",  class = "EVOKER",      ready = "ready",    food = "wellfed", flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = true,  dur = 93 },
    { name = "Axewield",    class = "WARRIOR",     ready = "ready",    food = "wellfed", flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = false, dur = 100 },
    { name = "Daggerfall",  class = "ROGUE",       ready = "pending",  food = "missing", flask = false, vantus = false, int = true,  ap = true,  vers = false, stam = true,  haste = true,  move = true,  dur = 34 },
    { name = "Sunforge",    class = "PALADIN",     ready = "ready",    food = "wellfed", flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = true,  dur = 88 },
    { name = "Arcaneweave", class = "MAGE",        ready = "ready",    food = "wellfed", flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = false, move = true,  dur = 81 },
    { name = "Wildroot",    class = "DRUID",       ready = "ready",    food = "wellfed", flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = true,  dur = 96 },
    { name = "Thunderfist", class = "SHAMAN",      ready = "notready", food = "missing", flask = false, vantus = false, int = true,  ap = true,  vers = true,  stam = false, haste = true,  move = true,  dur = 45 },
    { name = "Soulrend",    class = "WARLOCK",     ready = "ready",    food = "wellfed", flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = true,  dur = 73 },
    { name = "Mindweave",   class = "PRIEST",      ready = "ready",    food = "wellfed", flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = true,  dur = 100 },
    { name = "Trueshot",    class = "HUNTER",      ready = "ready",    food = "wellfed", flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = true,  dur = 84 },
    { name = "Deathchill",  class = "DEATHKNIGHT", ready = "pending",  food = "eating",  flask = true,  vantus = true,  int = true,  ap = true,  vers = true,  stam = true,  haste = true,  move = true,  dur = 62 },
    { name = "Stormglide",  class = "EVOKER",      ready = "ready",    food = "wellfed", flask = true,  vantus = true,  int = true,  ap = false, vers = true,  stam = true,  haste = true,  move = true,  dur = 97 },
}

local usingTestRoster = false

-- Single-pass scan of a unit's HELPFUL auras. Previously each GatherFromUnit
-- call did 8+ independent FindAura scans (flask, vantus, int, ap, vers, stam,
-- haste, move, wellfed, eating) which at 30 raiders = ~3,600 aura index
-- lookups per render. This batches them into one iteration of the aura list.
local EATING_NAMES = EATING_AURA_NAMES

-- Per-unit cache of the aura scan result. Invalidated on UNIT_AURA for the
-- affected unit (via ns.ReadyCheck_InvalidateUnitAuras), GROUP_ROSTER_UPDATE
-- (wipe-all), or a new READY_CHECK session. Without this, a single unit's
-- aura tick forced a full 30-unit aura rescan every 0.5s.
local auraCache = {}

-- Looks up `t[k]` under pcall so a secret-tainted aura field (spellId or
-- name on raid units in Midnight) can't propagate a "cannot be indexed
-- with secret keys" error out of the scan loop.
local function SafeLookup(t, k)
    if k == nil then return nil end
    local ok, v = pcall(function() return t[k] end)
    if ok then return v end
    return nil
end

-- Same idea for string method calls: nm:find/match on a secret-string can
-- throw, so wrap the whole predicate in pcall and treat any taint as "no
-- match" for this aura.
local function SafeStringTest(fn)
    local ok, hit = pcall(fn)
    return ok and hit and true or false
end

local function ScanUnitAuras_Raw(unit)
    local out = {
        flask = nil, vantus = nil,
        int = nil, ap = nil, vers = nil, stam = nil, haste = nil, move = nil,
        wellfed = nil, eating = false,
    }
    if not unit or not UnitExists(unit) then return out end
    local i = 1
    while true do
        local a = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not a then break end
        local sid = a.spellId
        local nm  = a.name

        local statKey = SafeLookup(STAT_BUFF_IDS, sid)
        if statKey then out[statKey] = a end

        if SafeLookup(flaskSet, sid) then
            out.flask = out.flask or a
        elseif nm and not out.flask
               and SafeStringTest(function() return nm:find("^Phial of ") or nm:find("^Flask of ") end) then
            out.flask = a
        end

        if SafeLookup(bronzeSet, sid) then out.move = a end

        if nm and not out.vantus
           and SafeStringTest(function() return nm:find("^Vantus Rune:") end) then
            out.vantus = a
        end

        if not out.wellfed then
            -- Midnight "hearty" foods use buff names other than the literal
            -- "Well Fed" (e.g. "Hearty Well Fed", "Hearty Feast"). Match the
            -- spellID whitelist first, then any name starting with "Well Fed"
            -- or containing "Hearty".
            if SafeLookup(foodSet, sid) then
                out.wellfed = a
            elseif nm and SafeStringTest(function()
                    return nm == "Well Fed" or nm:find("^Well Fed") or nm:find("^Hearty")
                end) then
                out.wellfed = a
            end
        end

        if not out.eating and SafeLookup(EATING_NAMES, nm) then out.eating = true end

        i = i + 1
    end
    return out
end

local function ScanUnitAuras(unit)
    if not unit then return ScanUnitAuras_Raw(unit) end
    local cached = auraCache[unit]
    if cached then return cached end
    local result = ScanUnitAuras_Raw(unit)
    -- Only cache for real live units so a transient empty-slot snapshot
    -- doesn't stick around after the slot gets filled.
    if UnitExists(unit) then auraCache[unit] = result end
    return result
end

local function InvalidateUnitAuras(unit)
    if unit then auraCache[unit] = nil end
end

local function InvalidateAllAuras()
    wipe(auraCache)
end

local function GatherFromUnit(unit)
    if not UnitExists(unit) then return nil end
    local _, class = UnitClass(unit)
    local rawName = UnitName(unit) or "?"
    local name = Ambiguate(rawName, "short")
    local ready = readyStatus[name]
    if not ready then
        local blizz = GetReadyCheckStatus(unit)
        if blizz == "ready" or blizz == "notready" then ready = blizz end
    end

    local a = ScanUnitAuras(unit)
    local foodState
    if a.wellfed then foodState = { state = "wellfed", aura = a.wellfed }
    elseif a.eating then foodState = { state = "eating" }
    else foodState = { state = "missing" } end

    return {
        unit  = unit,
        name  = name,
        class = class,
        ready = ready,
        food  = foodState,
        aura  = {
            flask  = a.flask,
            vantus = a.vantus,
            int    = a.int,
            ap     = a.ap,
            vers   = a.vers,
            stam   = a.stam,
            haste  = a.haste,
            move   = a.move,
        },
        dur = GetDurabilityFor(unit),
        test = false,
    }
end

-- Rotating sample icons for the preview so test rows visually vary.
local SAMPLE_FOOD_ICONS = {
    "Interface\\Icons\\INV_Misc_Food_145",
    "Interface\\Icons\\INV_Misc_Food_162_fish",
    "Interface\\Icons\\INV_Misc_Food_11",
    "Interface\\Icons\\INV_Misc_Food_74",
    "Interface\\Icons\\INV_Misc_Food_76",
}
local SAMPLE_FLASK_ICONS = {
    "Interface\\Icons\\INV_Alchemy_EndlessFlask_01",
    "Interface\\Icons\\INV_Alchemy_EndlessFlask_04",
    "Interface\\Icons\\INV_Potion_62",
    "Interface\\Icons\\INV_Potion_79",
    "Interface\\Icons\\INV_Alchemy_Flask_02",
}

local function pickSample(list, i)
    return list[((i - 1) % #list) + 1]
end

local function GatherFromTest(entry, idx)
    local foodState
    if entry.food == "wellfed" then
        foodState = { state = "wellfed", aura = { icon = pickSample(SAMPLE_FOOD_ICONS, idx) } }
    elseif entry.food == "eating" then
        foodState = { state = "eating" }
    else
        foodState = { state = "missing" }
    end
    return {
        name  = entry.name,
        class = entry.class,
        ready = entry.ready == "pending" and nil or entry.ready,
        food  = foodState,
        aura  = {
            flask  = entry.flask  and { icon = pickSample(SAMPLE_FLASK_ICONS, idx) } or nil,
            vantus = entry.vantus and {} or nil,
            int    = entry.int    and {} or nil,
            ap     = entry.ap     and {} or nil,
            vers   = entry.vers   and {} or nil,
            stam   = entry.stam   and {} or nil,
            haste  = entry.haste  and {} or nil,
            move   = entry.move   and {} or nil,
        },
        dur  = entry.dur,
        test = true,
    }
end

-- Forward declaration so GatherRoster can reference it (body defined below).
local IterateRaidUnits

local function GatherRoster()
    if usingTestRoster then
        local list = {}
        for i, e in ipairs(TEST_ROSTER) do list[#list+1] = GatherFromTest(e, i) end
        return list
    end
    local list = {}
    for _, u in ipairs(IterateRaidUnits()) do
        local d = GatherFromUnit(u)
        if d then list[#list+1] = d end
    end
    return list
end

IterateRaidUnits = function()
    local list = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do list[#list+1] = "raid" .. i end
    elseif IsInGroup() then
        list[#list+1] = "player"
        for i = 1, GetNumGroupMembers() - 1 do list[#list+1] = "party" .. i end
    else
        list[#list+1] = "player"
    end
    return list
end

-- Header labels are anchored once using the pre-computed boundaries.
-- They never move across renders, so doing this in load-time init keeps
-- ApplyHeaderRow down to a single Show/Hide batch per render.
do
    for i, fs in ipairs(headerLabels) do
        local cellCenter = COLUMN_BOUNDARIES[i] + COL_W / 2
        fs:SetPoint("CENTER", headerRow, "LEFT", cellCenter - PAD, 0)
    end
end

local headerShown = nil
local function ApplyHeaderRow(show)
    if headerShown == show then return end
    headerShown = show
    if show then
        headerRow:Show()
        divider:Show()
    else
        headerRow:Hide()
        divider:Hide()
        columnDividerFrame:Hide()
        for _, line in ipairs(columnDividers) do line:Hide() end
        bottomDivider:Hide()
    end
end

-- Called after rows are laid out so we know the bottom y of the grid.
-- Positions vertical column dividers and the closing horizontal line so
-- they meet exactly at the last crossing, not extending past it.
local function PositionGridLines(gridBottomY)
    local gridTop    = -(HEADER_HEIGHT + 18)  -- under the header divider
    local gridLeft   = COLUMN_BOUNDARIES[1]
    local gridRight  = COLUMN_BOUNDARIES[#COLUMN_BOUNDARIES]

    columnDividerFrame:Show()

    -- Verticals: run from grid top to the gridBottomY only (no overshoot).
    for i, line in ipairs(columnDividers) do
        local x = COLUMN_BOUNDARIES[i]
        if not x then line:Hide()
        else
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT",    frame, "TOPLEFT", x, gridTop)
            line:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", x, gridBottomY)
            line:Show()
        end
    end

    -- Closing horizontal line: from leftmost vertical to rightmost vertical.
    bottomDivider:ClearAllPoints()
    bottomDivider:SetPoint("TOPLEFT",  frame, "TOPLEFT", gridLeft,  gridBottomY)
    bottomDivider:SetPoint("TOPRIGHT", frame, "TOPLEFT", gridRight, gridBottomY)
    bottomDivider:Show()
end

------------------------------------------------------------
-- Build: FULL view
------------------------------------------------------------
local function BuildFullView()
    ResolveCheckIcons()
    HideAllCompactRows()
    ApplyHeaderRow(true)

    local roster = GatherRoster()
    local totalCount = #roster
    EnsureFullRows(totalCount)

    local readyCount = 0

    for idx, p in ipairs(roster) do
        local row = fullRows[idx]
        if not row:IsShown() then row:Show() end

        -- Status icon
        if p.ready == "ready" then
            row.status:SetTexture(READY_TEX);    readyCount = readyCount + 1
        elseif p.ready == "notready" then
            row.status:SetTexture(NOTREADY_TEX)
        else
            row.status:SetTexture(WAITING_TEX)
        end

        local col = p.class and RAID_CLASS_COLORS[p.class]
        row.name:SetText(col and col:WrapTextInColorCode(p.name) or p.name)

        for i, c in ipairs(CHECKS_META) do
            local btn = row.icons[i]

            if c.key == "food" then
                local fs = p.food
                if fs.state == "wellfed" then
                    ApplyIconState(btn, {
                        present = true,
                        iconID  = (fs.aura and fs.aura.icon) or c.iconID,
                        aura    = fs.aura,
                    })
                elseif fs.state == "eating" then
                    ApplyIconState(btn, { present = true, iconID = c.iconID, pulse = true })
                else
                    ApplyIconState(btn, { present = false, iconID = c.iconID })
                end
            elseif c.key == "dur" then
                if p.dur then
                    local r, g, b = 0.3, 1, 0.3
                    if p.dur < 70 then r, g, b = 1, 0.8, 0.2 end
                    if p.dur < 40 then r, g, b = 1, 0.3, 0.3 end
                    ApplyIconState(btn, { text = p.dur .. "%", textColor = { r, g, b } })
                else
                    ApplyIconState(btn, { present = nil, iconID = c.iconID })
                end
            else
                local a = p.aura[c.key]
                local present = a ~= nil
                -- For flask, prefer the actual aura's icon (each phial has its
                -- own icon texture). For fixed raid buffs (Int/AP/Stam/etc.)
                -- the spell-based iconID is stable and preferred for uniformity.
                local iconID = c.iconID
                if present and c.key == "flask" and a.icon then
                    iconID = a.icon
                end
                ApplyIconState(btn, { present = present, iconID = iconID, aura = a })
            end
        end
    end

    HideExtraFullRows(totalCount)

    summary:SetText(string.format("|cffffffff%d|r/%d ready", readyCount, totalCount))

    local gridBottomY = FIRST_ROW_Y_FULL - totalCount * ROW_HEIGHT_FULL
    PositionGridLines(gridBottomY)

    frame:SetHeight(-gridBottomY + BOTTOM_PAD)
end

------------------------------------------------------------
-- Build: COMPACT view
------------------------------------------------------------
local function BuildCompactView()
    HideAllFullRows()
    ApplyHeaderRow(false)

    local roster = GatherRoster()
    local totalCount = #roster
    local readyCount = 0
    local rowsNeeded = math.ceil(totalCount / COMPACT_COLS)
    EnsureCompactRows(rowsNeeded)

    for idx, p in ipairs(roster) do
        local rowIdx = math.floor((idx - 1) / COMPACT_COLS) + 1
        local colIdx = ((idx - 1) % COMPACT_COLS) + 1
        local row = compactRows[rowIdx]
        if not row:IsShown() then row:Show() end
        local cell = row.cells[colIdx]
        if not cell:IsShown() then cell:Show() end

        if p.ready == "ready" then
            cell.status:SetTexture(READY_TEX); readyCount = readyCount + 1
        elseif p.ready == "notready" then
            cell.status:SetTexture(NOTREADY_TEX)
        else
            cell.status:SetTexture(WAITING_TEX)
        end

        local col2 = p.class and RAID_CLASS_COLORS[p.class]
        cell.name:SetText(col2 and col2:WrapTextInColorCode(p.name) or p.name)
    end

    -- Hide any trailing cells in the last used row + any surplus rows.
    local lastRow = compactRows[rowsNeeded]
    if lastRow then
        local usedCols = ((totalCount - 1) % COMPACT_COLS) + 1
        for c = usedCols + 1, COMPACT_COLS do
            local cell = lastRow.cells[c]
            if cell:IsShown() then cell:Hide() end
        end
    end
    HideExtraCompactRows(rowsNeeded)

    summary:SetText(string.format("|cffffffff%d|r/%d ready", readyCount, totalCount))
    bottomDivider:Hide()
    local gridBottomY = FIRST_ROW_Y_COMPACT - rowsNeeded * ROW_HEIGHT_COMPACT
    frame:SetHeight(-gridBottomY + BOTTOM_PAD)
end

------------------------------------------------------------
-- Render dispatch
------------------------------------------------------------
Render = function()
    UpdateCollapseTexture()
    if DB().collapsed then
        BuildCompactView()
    else
        BuildFullView()
    end
end

collapseBtn:SetScript("OnClick", function()
    DB().collapsed = not DB().collapsed
    Render()
end)

------------------------------------------------------------
-- Countdown
------------------------------------------------------------
local endTime = 0
local ticker
local function StartCountdown(duration)
    endTime = GetTime() + (duration or 30)
    if ticker then ticker:Cancel() end
    local function tick()
        local remaining = math.max(0, math.floor(endTime - GetTime() + 0.5))
        countdown:SetText(string.format("|cffcccc00%ds|r", remaining))
        if remaining <= 0 and ticker then ticker:Cancel(); ticker = nil end
    end
    tick()
    ticker = C_Timer.NewTicker(0.25, tick)
end

local function StopCountdown()
    if ticker then ticker:Cancel(); ticker = nil end
    countdown:SetText("")
end

------------------------------------------------------------
-- Fade-out animation on finish
-- Fade begins the moment the check ends (no multi-second tail like the
-- old 3s pre-fade delay), then gracefully fades out — not a snap-hide.
------------------------------------------------------------
local fadeGroup = frame:CreateAnimationGroup()
local fade = fadeGroup:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0)
fade:SetDuration(1.5)
fadeGroup:SetScript("OnFinished", function()
    frame:Hide()
    frame:SetAlpha(1)  -- reset for next show
end)

-- Dismissal state (hoisted so ShowFrameInstant can clear it when a
-- new ready-check overrides a pending fade from the previous one).
local lingerTimer
local hoverTicker
local fadePending = false

local function ShowFrameInstant()
    fadeGroup:Stop()
    -- Any lingering deferred-fade or hover-watch from a previous
    -- session is now moot — the new check is visible and active.
    fadePending = false
    if lingerTimer then lingerTimer:Cancel(); lingerTimer = nil end
    if hoverTicker then hoverTicker:Cancel(); hoverTicker = nil end
    frame:SetAlpha(1)
    frame:Show()
end

------------------------------------------------------------
-- Events
------------------------------------------------------------
-- UNIT_AURA is high-frequency; register only while a ready check is active
-- or the frame is visible, and unregister again afterward.
local events = CreateFrame("Frame")
events:RegisterEvent("READY_CHECK")
events:RegisterEvent("READY_CHECK_CONFIRM")
events:RegisterEvent("READY_CHECK_FINISHED")
events:RegisterEvent("CHAT_MSG_ADDON")
-- Roster change invalidates the aura cache: the unit at a given token
-- slot may have been replaced.
events:RegisterEvent("GROUP_ROSTER_UPDATE")
-- Pull-timer / countdown: when the raid leader starts a countdown, the
-- ready-check window is stale info — dismiss it immediately so the
-- screen is clear for the incoming boss warnings.
events:RegisterEvent("START_TIMER")
-- Combat start: snap-close (no fade, no linger). The fight is live and
-- the ready-check panel is in the way of boss mechanics.
events:RegisterEvent("PLAYER_REGEN_DISABLED")

local function EnableAuraTracking(on)
    if on then events:RegisterEvent("UNIT_AURA")
    else events:UnregisterEvent("UNIT_AURA") end
end

-- Defined at the top of the file; wired here so that closing the window
-- (manual × click, /yyhrc hide, fade-out animation, parent Hide) always
-- stops UNIT_AURA bookkeeping — not only the ready-check finish paths.
onReadyCheckFrameHide = function()
    EnableAuraTracking(false)
    -- Frame is gone — any deferred fade / hover watch is stale now.
    fadePending = false
    if lingerTimer then lingerTimer:Cancel(); lingerTimer = nil end
    if hoverTicker then hoverTicker:Cancel(); hoverTicker = nil end
end

-- Dismissal variants — three shapes, picked per trigger:
--   DismissInstant    — snap-hide, no fade. Combat start.
--   DismissFade       — fade-out. Pull countdown / end of linger.
--   DismissDelayedFade — linger N seconds, then fade. Normal finish /
--                        everyone-answered paths (so the final status
--                        stays readable for a beat).
--
-- Hover-to-pause: if the user's cursor is over the window when a fade
-- is about to start, we suppress it and set `fadePending`. As soon as
-- the mouse leaves (hover ticker below), we fire the fade right then.
-- Combat (DismissInstant) always wins — hover does NOT pause a snap.
--
-- `lingerTimer`, `hoverTicker`, `fadePending` are declared earlier
-- (above ShowFrameInstant) so the show path can clear pending state
-- from a prior session.

local function CancelLinger()
    if lingerTimer then lingerTimer:Cancel(); lingerTimer = nil end
end

local function StopHoverWatch()
    fadePending = false
    if hoverTicker then hoverTicker:Cancel(); hoverTicker = nil end
end

-- StartHoverWatch is used in two states:
--   (A) fadePending = true, fade not playing → wait for mouse to
--       LEAVE, then play the fade.
--   (B) fade currently playing → wait for mouse to ENTER; if it
--       does, stop the fade, restore alpha, flip to state (A).
-- The ticker self-cancels once neither condition is live.
local StartHoverWatch
local function PlayFade()
    if not frame:IsShown() then return end
    fadeGroup:Play()
    EnableAuraTracking(false)
    StartHoverWatch()  -- monitor for mouse re-entry during the fade
end

StartHoverWatch = function()
    if hoverTicker then return end
    hoverTicker = C_Timer.NewTicker(0.1, function()
        if fadePending then
            -- State A: waiting for mouse to clear the window.
            if not frame:IsMouseOver() then
                fadePending = false
                if hoverTicker then hoverTicker:Cancel(); hoverTicker = nil end
                PlayFade()
            end
            return
        end
        -- State B: fade in progress, waiting for mouse to re-enter.
        if fadeGroup:IsPlaying() then
            if frame:IsMouseOver() then
                fadeGroup:Stop()
                frame:SetAlpha(1)
                fadePending = true  -- fall through into state A next tick
            end
            return
        end
        -- Fade finished (or was never pending). Nothing more to watch.
        if hoverTicker then hoverTicker:Cancel(); hoverTicker = nil end
    end)
end

local function DismissInstant()
    CancelLinger()
    StopHoverWatch()
    fadeGroup:Stop()
    StopCountdown()
    frame:SetAlpha(1)  -- reset for next show
    if frame:IsShown() then frame:Hide() end
    EnableAuraTracking(false)
end

local function DismissFade()
    CancelLinger()
    StopCountdown()
    if frame:IsShown() and frame:IsMouseOver() then
        -- User is examining the window — hold the fade and arm the
        -- hover-watch ticker, which plays the fade the instant the
        -- cursor clears the window.
        fadePending = true
        StartHoverWatch()
        return
    end
    fadePending = false
    PlayFade()
end

local function DismissDelayedFade(delay)
    StopCountdown()
    CancelLinger()
    lingerTimer = C_Timer.NewTimer(delay or 3, function()
        lingerTimer = nil
        DismissFade()
    end)
end

local refreshThrottle
local function QueueRefresh(delay)
    if refreshThrottle then return end
    refreshThrottle = C_Timer.NewTimer(delay or 0.1, function()
        refreshThrottle = nil
        if frame:IsShown() then Render() end
    end)
end

local function ShowFrameAtSavedPos()
    local db = DB()

    -- Prefer new schema (point/relativePoint/x/y), fall back to the
    -- legacy anchorLeft/anchorTop TOPLEFT-anchored pair, else center.
    local point         = db.point
    local relativePoint = db.relativePoint
    local x, y          = db.x, db.y

    if not point and db.anchorLeft and db.anchorTop then
        point, relativePoint = "TOPLEFT", "TOPLEFT"
        x, y = db.anchorLeft, db.anchorTop
    end

    if not point then
        -- First-ever show: center the (expanded) window horizontally and
        -- place it a bit above vertical center. ~600px approx height for
        -- a 24-player expanded view; the user can drag to fine-tune.
        local screenW = UIParent:GetWidth()
        local screenH = UIParent:GetHeight()
        local approxH = 600
        point, relativePoint = "TOPLEFT", "TOPLEFT"
        x = math.floor((screenW - WINDOW_WIDTH) / 2)
        y = -math.floor((screenH - approxH) / 2)
        db.point, db.relativePoint, db.x, db.y = point, relativePoint, x, y
        db.anchorLeft, db.anchorTop = x, y
    end

    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, relativePoint, x, y)
    ShowFrameInstant()
end

-- Only refresh on UNIT_AURA events for actual group members, to avoid
-- a burst of no-op refreshes from unrelated units (pets, target, etc).
local function UnitIsInGroup(unit)
    if not unit then return false end
    if unit == "player" then return true end
    if unit:match("^raid%d+$") then return true end
    if unit:match("^party%d+$") then return true end
    return false
end

events:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
    if event == "CHAT_MSG_ADDON" then
        if arg1 ~= DURABILITY_PREFIX then return end
        local pct = tonumber(arg2)
        if not pct then return end
        local sender = arg4 and Ambiguate(arg4, "short") or nil
        if not sender then return end
        durabilityCache[sender] = { pct = pct, ts = GetTime() }
        -- 30 durability messages arrive in a burst during the staggered
        -- broadcast — coalesce into one render at the end of the window.
        if frame:IsShown() then QueueRefresh(0.6) end
        return
    end

    if event == "GROUP_ROSTER_UPDATE" then
        InvalidateAllAuras()
        if frame:IsShown() then QueueRefresh(0.3) end
        return
    end

    if not DB().enabled then return end
    if event == "READY_CHECK" then
        usingTestRoster = false
        EnableAuraTracking(true)
        -- Fresh session → stale cached aura data shouldn't leak into the
        -- new ready-check panel.
        InvalidateAllAuras()
        -- Reset our event-captured status map. arg1 is the initiator's
        -- name — they're implicitly "ready" since they started the check.
        wipe(readyStatus)
        if arg1 then readyStatus[Ambiguate(arg1, "short")] = "ready" end
        BroadcastOwnDurability()
        ShowFrameAtSavedPos()
        Render()
        StartCountdown(arg2 or 30)
        -- Unit tokens (raid1..raidN) aren't always resolved the instant
        -- READY_CHECK fires in larger raids, so the first render can drop
        -- rows for raiders whose UnitExists returned false. Retry twice to
        -- backfill once tokens settle.
        C_Timer.After(0.3, function() if frame:IsShown() then Render() end end)
        C_Timer.After(1.2, function() if frame:IsShown() then Render() end end)
    elseif event == "READY_CHECK_CONFIRM" then
        -- arg1 = unit, arg2 = ready (boolean). Record it in our map so
        -- we don't depend on GetReadyCheckStatus (which can be stale
        -- for a tick after the event fires).
        -- Key by short-ambiguated name to match the initiator-seed key
        -- format (line above wipes + seeds with Ambiguate(arg1, "short")).
        -- UnitName on a cross-realm player returns "Name-Realm", which
        -- would miss the initiator's seed and double-count responders.
        local rawName = arg1 and UnitName(arg1)
        local name = rawName and Ambiguate(rawName, "short")
        if name then
            readyStatus[name] = arg2 and "ready" or "notready"
        end
        -- Was calling Render() directly — at 30 players that's 30 full
        -- renders in the first second. Throttle to coalesce bursts.
        if frame:IsShown() then QueueRefresh(0.15) end
        -- Early-finish: count unique responders directly from readyStatus
        -- (cheap — no per-confirm GetRaidRosterInfo storm).
        local num = GetNumGroupMembers()
        if num > 0 then
            local answered = 0
            for _ in pairs(readyStatus) do answered = answered + 1 end
            if answered >= num then
                DismissDelayedFade()
            end
        end
    elseif event == "READY_CHECK_FINISHED" then
        if frame:IsShown() then Render() end
        DismissDelayedFade()
    elseif event == "START_TIMER" then
        -- arg1 is Enum.StartTimerType. PlayerCountdown fires from /cd,
        -- /countdown, the Blizzard native pull timer, and whichever
        -- DBM / BigWigs pull-timer option is set to use the native
        -- countdown. Bare BigWigs / DBM pull bars use their own comms
        -- and won't fire this — those still need a manual close.
        local playerCountdown = (Enum and Enum.StartTimerType
            and Enum.StartTimerType.PlayerCountdown) or 3
        if arg1 == playerCountdown then
            DismissFade()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        DismissInstant()
    elseif event == "UNIT_AURA" then
        -- 0.5s debounce — aura ticks in a 30-man raid can fire dozens of
        -- times per second, and rendering only every 100ms still burns cpu.
        -- Only the unit that actually changed gets its cache invalidated;
        -- every other row reads cached aura data on the next render.
        if UnitIsInGroup(arg1) then
            InvalidateUnitAuras(arg1)
            if frame:IsShown() then QueueRefresh(0.5) end
        end
    end
end)

------------------------------------------------------------
-- Public API + slash command
------------------------------------------------------------
local function Preview(withTestRoster)
    DB().enabled = true
    usingTestRoster = withTestRoster and true or false
    if not usingTestRoster then BroadcastOwnDurability() end
    ShowFrameAtSavedPos()
    Render()
    StartCountdown(30)
end

-- Expose spell-ID pools so other files / users can extend at runtime
-- if a new patch adds consumables we haven't catalogued.
local function addIDsTo(set, list, listRef)
    for _, id in ipairs(list) do
        if not set[id] then set[id] = true; table.insert(listRef, id) end
    end
end

ns.ReadyCheck = {
    IsEnabled  = function() return DB().enabled end,
    SetEnabled = function(v) DB().enabled = v and true or false end,
    Preview    = Preview,
    Hide       = function() frame:Hide() end,
    AddFoodSpellIDs   = function(list) addIDsTo(foodSet,  list, FOOD_SPELL_IDS)  end,
    AddFlaskSpellIDs  = function(list) addIDsTo(flaskSet, list, FLASK_SPELL_IDS) end,
    AddBronzeSpellIDs = function(list) addIDsTo(bronzeSet, list, BRONZE_SPELL_IDS) end,
}

SLASH_YYHREADYCHECK1 = "/yyhrc"
SlashCmdList.YYHREADYCHECK = function(msg)
    if msg == "hide" then
        frame:Hide()
    elseif msg == "live" then
        Preview(false)  -- real current group
    else
        Preview(true)   -- 24 test characters (default)
    end
end
