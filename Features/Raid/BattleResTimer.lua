local _, ns = ...

------------------------------------------------------------
-- Battle Res Timer
--
-- Shows the Combat Resurrection icon with a cooldown swipe and
-- countdown text. Driven by `C_Spell.GetSpellCharges(20484)`
-- (Rebirth's spellID), which is the same authoritative source
-- BigWigs uses — the game itself maintains the brez pool, so
-- we don't have to reproduce per-encounter accumulation rules
-- or guess at charge counts.
--
-- The display is shown:
--   * In raid difficulties that use the battle-res system
--     (LFR/Normal/Heroic/Mythic/Timewalking).
--   * In Mythic+ keystone runs (the same brez pool applies).
--   * Hidden in groups that don't have a brez pool (normal/
--     heroic dungeons, scenarios, open world).
--
-- The frame is draggable while unlocked, with a Lock button
-- attached to the top edge — same pattern as the L'ura helper.
------------------------------------------------------------

ns.BattleResTimer = ns.BattleResTimer or {}
local BR = ns.BattleResTimer

local REBIRTH_SPELLID = 20484  -- Rebirth — the BR pool is keyed off this in-game

local DIFFICULTIES_WITH_BREZ = {
    [14] = true,  -- Normal raid
    [15] = true,  -- Heroic raid
    [16] = true,  -- Mythic raid
    [17] = true,  -- LFR
    [33] = true,  -- Timewalking raid
    [8]  = true,  -- Mythic Keystone (M+)
}

------------------------------------------------------------
-- SavedVariables
------------------------------------------------------------

local DEFAULTS = {
    enabled         = true,
    -- Locked by default, and see the session reset below for why an
    -- unlocked timer is not a state this frame should ever boot into.
    locked          = true,
    scale           = 1.0,
    showOutOfCombat = true,
    position        = { anchor = "CENTER", relativePoint = "CENTER", x = 0, y = -180 },
}

-- "Unlocked" is a transient positioning state, not a preference.
--
-- While it is set the frame is mouse-enabled, and a mouse-enabled frame
-- parked in the middle of the screen silently eats every mouse-button
-- keybind pressed over it: the click is delivered to the frame instead
-- of the binding system, and nothing anywhere says so. The player just
-- finds that their side buttons stopped casting.
--
-- Nothing legitimate leaves it unlocked either. Positioning belongs to
-- Edit Mode, which drags through its own selection frame and never needs
-- this, and ApplyLockState keeps the in-place Lock button hidden — so an
-- unlock had no way back short of knowing the slash command existed.
-- Clear it once per session, the same way the interrupt tracker's test
-- mode is cleared, so it can never outlive the session that asked.
local lockRestored = false

local function db()
    YippYappHelperDB = YippYappHelperDB or {}
    local d = YippYappHelperDB.battleResTimer
    if type(d) ~= "table" then
        d = {}
        YippYappHelperDB.battleResTimer = d
    end
    if type(d.enabled)         ~= "boolean" then d.enabled         = DEFAULTS.enabled end
    if type(d.locked)          ~= "boolean" then d.locked          = DEFAULTS.locked  end
    if type(d.scale)           ~= "number"  then d.scale           = DEFAULTS.scale   end
    if type(d.showOutOfCombat) ~= "boolean" then d.showOutOfCombat = DEFAULTS.showOutOfCombat end
    if d.scale < 0.5 then d.scale = 0.5 elseif d.scale > 2.5 then d.scale = 2.5 end
    if not lockRestored then
        lockRestored = true
        d.locked = true
    end
    if type(d.position) ~= "table" then
        d.position = {
            anchor = DEFAULTS.position.anchor,
            relativePoint = DEFAULTS.position.relativePoint,
            x = DEFAULTS.position.x,
            y = DEFAULTS.position.y,
        }
    end
    return d
end

------------------------------------------------------------
-- Display
------------------------------------------------------------

local display
local previewMode = false

local function FormatRemaining(secs)
    if secs <= 0 then return "" end
    if secs >= 60 then
        return ("%d:%02d"):format(math.floor(secs / 60), math.floor(secs % 60))
    end
    return tostring(math.ceil(secs))
end

local function ApplyPosition()
    if not display then return end
    -- Edit Mode owns the position when it is managing this frame.
    if ns.EditModeManagesPosition and ns.EditModeManagesPosition("brez") then
        return
    end
    local d = db()
    display:ClearAllPoints()
    display:SetPoint(d.position.anchor, UIParent, d.position.relativePoint, d.position.x, d.position.y)
end

local function ApplyLockState()
    if not display then return end
    local locked = db().locked
    display:EnableMouse(not locked)
    if display.lockBtn then
        -- Never shown: positioning belongs to Edit Mode, which drags via
        -- its own selection frame. An in-place Lock button would only
        -- offer a second, conflicting way to move the timer.
        display.lockBtn:Hide()
    end
end

local function CreateDisplay()
    local f = CreateFrame("Frame", "YYH_BattleResTimer", UIParent, "BackdropTemplate")
    f:SetSize(56, 56)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not db().locked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        local d = db()
        d.position.anchor = point
        d.position.relativePoint = relPoint
        d.position.x = math.floor(x + 0.5)
        d.position.y = math.floor(y + 0.5)
    end)

    -- Backdrop just for the unlocked-mode hover affordance; hidden in
    -- locked mode so the icon sits clean over the rest of the UI.
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    f:SetBackdropColor(0, 0, 0, 0)
    f:SetBackdropBorderColor(0, 0, 0, 0)

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    local iconPath = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(REBIRTH_SPELLID))
                     or 136080  -- Interface\Icons\Spell_Nature_Reincarnation
    icon:SetTexture(iconPath)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.icon = icon

    local cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawBling(false)
    cooldown:SetHideCountdownNumbers(true)  -- Blizzard CD numbers
    cooldown.noCooldownCount = true         -- OmniCC opt-out
    f.cooldown = cooldown

    local cdText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    cdText:SetPoint("CENTER", icon, "CENTER", 0, 0)
    cdText:SetTextColor(1, 1, 1, 1)
    cdText:SetShadowColor(0, 0, 0, 1)
    cdText:SetShadowOffset(1, -1)
    f.cdText = cdText

    -- Charges count, anchored top-right of the icon. Sits above the
    -- cooldown swipe (TOPRIGHT instead of overlapping center text) and
    -- uses a thick outline so it stays readable over both the bright
    -- icon art and the dimmed swipe at low charges.
    local charges = f:CreateFontString(nil, "OVERLAY")
    charges:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    charges:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -1, -1)
    charges:SetJustifyH("RIGHT")
    charges:SetTextColor(0.2, 1.0, 0.3, 1)
    charges:SetShadowColor(0, 0, 0, 1)
    charges:SetShadowOffset(1, -1)
    f.charges = charges

    -- Lock button — hidden when locked so the icon stays clean.
    local lockBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    lockBtn:SetSize(50, 16)
    lockBtn:SetPoint("BOTTOM", f, "TOP", 0, 2)
    lockBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    lockBtn:SetBackdropColor(0.10, 0.10, 0.10, 0.95)
    lockBtn:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
    local label = lockBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    label:SetText("Lock")
    lockBtn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.0, 0.8, 1.0, 1) end)
    lockBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9) end)
    lockBtn:SetScript("OnClick", function() BR:SetLocked(true) end)
    -- Hidden from birth: Edit Mode owns positioning, so this never shows.
    -- Kept only so the drag/lock plumbing below still has something to
    -- reference.
    lockBtn:Hide()
    f.lockBtn = lockBtn

    return f
end

local function EnsureDisplay()
    if display then return display end
    display = CreateDisplay()
    display:SetScale(db().scale)
    ApplyPosition()
    ApplyLockState()
    display:Hide()
    return display
end

------------------------------------------------------------
-- State + ticker
------------------------------------------------------------

local lastStartTime = -1

local function ShouldShowDisplay()
    if previewMode then return true end
    if not db().enabled then return false end
    -- The diff-ID whitelist already encodes "instance has a brez pool"
    -- (raid difficulties + Mythic Keystone), so we no longer gate on
    -- IsInRaid — that would shut out M+ keystone runs.
    local _, _, diffID = GetInstanceInfo()
    if not DIFFICULTIES_WITH_BREZ[diffID or 0] then return false end
    -- Out-of-combat gate. When showOutOfCombat is false, the icon is
    -- only visible while engaged with a boss or while combat is active —
    -- keeps the screen tidy during trash/clearing between pulls.
    if not db().showOutOfCombat then
        if not (InCombatLockdown() or IsEncounterInProgress()) then
            return false
        end
    end
    return true
end

--- Redraws the icon, and returns whether it should be on screen.
---
--- The return value exists so callers stop asking the same question
--- twice. Every one of them used to run Tick() and then call
--- ShouldShowDisplay() again to decide whether to run the ticker -- and
--- ShouldShowDisplay calls db() (which re-validates and clamps the whole
--- saved table) and GetInstanceInfo(). On the event path below that was
--- two of each, per event, in combat.
local function Tick()
    -- Preview owns the display state until ClearPreview is called, so
    -- the ticker doesn't overwrite the synthetic charges/cooldown the
    -- user just saw click "Preview".
    if previewMode then return true end
    if not ShouldShowDisplay() then
        if display then display:Hide() end
        return false
    end
    EnsureDisplay()

    local info = C_Spell and C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(REBIRTH_SPELLID)
    if not info then
        -- No active brez pool yet (e.g. just zoned into the raid before
        -- the encounter populates it). Treat that as "0 charges" so the
        -- count is always present — empty text would look like a bug.
        display.cooldown:Clear()
        display.cdText:SetText("")
        display.charges:SetText("0")
        display.charges:SetTextColor(1.0, 0.25, 0.25, 1)
        display.icon:SetDesaturated(true)
        display:Show()
        return true
    end

    local current     = info.currentCharges or 0
    local startTime   = info.cooldownStartTime or 0
    local fullDuration = info.cooldownDuration or 0

    -- Always show the count — players want to know "how many brez can my
    -- raid land right now" at a glance, including the zero-charge state.
    -- Green when at least one is up, red when none are available.
    display.charges:SetText(tostring(current))
    if current > 0 then
        display.icon:SetDesaturated(false)
        display.charges:SetTextColor(0.2, 1.0, 0.3, 1)
    else
        display.icon:SetDesaturated(true)
        display.charges:SetTextColor(1.0, 0.25, 0.25, 1)
    end

    if startTime ~= lastStartTime then
        lastStartTime = startTime
        display.cooldown:Clear()
        if startTime > 0 and fullDuration > 0 then
            display.cooldown:SetCooldown(startTime, fullDuration)
        end
    end

    if fullDuration > 0 and startTime > 0 then
        local remaining = (startTime + fullDuration) - GetTime()
        if remaining > 0 then
            display.cdText:SetText(FormatRemaining(remaining))
        else
            display.cdText:SetText("")
        end
    else
        display.cdText:SetText("")
    end

    display:Show()
    return true
end

------------------------------------------------------------
-- Event wiring
------------------------------------------------------------

local frame = CreateFrame("Frame", "YYH_BattleResTimerFrame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
-- SPELL_UPDATE_CHARGES and not SPELL_UPDATE_COOLDOWN.
--
-- Both were registered. COOLDOWN is one of the noisiest events the
-- client sends: it fires for any spell whose cooldown state moves, which
-- in combat is several times a second on every spec, and each one ran a
-- full redraw plus two GetInstanceInfo calls. The ticker below already
-- redraws at 2Hz, which the comment on it correctly calls the right rate
-- for a countdown -- so all those events bought was the same picture,
-- drawn far more often than anyone can read it.
--
-- CHARGES stays because it is the one that carries news: it fires when a
-- battle res is actually spent or comes back, and that is the number
-- people are looking at. Without it the count could sit half a second
-- stale, which is exactly the moment it matters.
frame:RegisterEvent("SPELL_UPDATE_CHARGES")

local updater = frame:CreateAnimationGroup()
updater:SetLooping("REPEAT")
local anim = updater:CreateAnimation()
anim:SetDuration(0.5)  -- 2Hz refresh — smooth countdown without burning CPU
updater:SetScript("OnLoop", Tick)

--- Runs the 2Hz ticker only while the icon is actually up.
---
--- Declared here rather than beside Tick: it closes over `updater`, and
--- written any earlier it would have captured a nil global instead.
local function SyncUpdater(shown)
    if shown then
        if not updater:IsPlaying() then updater:Play() end
    elseif updater:IsPlaying() then
        updater:Stop()
    end
end

frame:SetScript("OnEvent", function()
    -- Most events just trigger an immediate Tick so the display
    -- catches state changes (zoning out of a raid, charges spent
    -- by a teammate) without waiting for the 0.5s ticker.
    SyncUpdater(Tick())
end)

------------------------------------------------------------
-- Public API (consumed by RaidSettings tab)
------------------------------------------------------------

function BR:IsEnabled() return db().enabled end
function BR:SetEnabled(on)
    db().enabled = not not on
    SyncUpdater(Tick())
end

function BR:IsLocked() return db().locked end
function BR:SetLocked(on)
    db().locked = not not on
    EnsureDisplay()
    ApplyLockState()
    if not db().locked then
        -- Unlocking lights up the icon so the user can see what they're
        -- dragging even outside an active raid encounter.
        BR:Preview()
    else
        -- Locking returns control to the live ticker so the icon mirrors
        -- the actual brez pool again.
        BR:ClearPreview()
    end
end

function BR:GetScale() return db().scale end
function BR:SetScale(v)
    v = tonumber(v) or DEFAULTS.scale
    if v < 0.5 then v = 0.5 elseif v > 2.5 then v = 2.5 end
    db().scale = v
    if display then display:SetScale(v) end
end

function BR:IsShowOutOfCombat() return db().showOutOfCombat end
function BR:SetShowOutOfCombat(on)
    db().showOutOfCombat = not not on
    SyncUpdater(Tick())
end

function BR:Preview()
    EnsureDisplay()
    previewMode = true
    -- Synthetic state for the preview — show "1 charge, 30s on the
    -- next" so the icon, swipe, count, and countdown all light up.
    display.icon:SetDesaturated(false)
    display.charges:SetText("1")
    display.charges:SetTextColor(0.2, 1.0, 0.3, 1)
    display.cdText:SetText("0:30")
    display.cooldown:Clear()
    display.cooldown:SetCooldown(GetTime() - 60, 90)
    display:Show()
end

function BR:ClearPreview()
    previewMode = false
    Tick()
end

function BR:HandleSlash(rest)
    local sub = strlower(strtrim(rest or ""))
    if sub == "" or sub == "preview" then
        BR:Preview()
    elseif sub == "clear" or sub == "hide" then
        BR:ClearPreview()
    elseif sub == "lock" then
        BR:SetLocked(true)
    elseif sub == "unlock" then
        BR:SetLocked(false)
    elseif sub == "on" then
        BR:SetEnabled(true)
    elseif sub == "off" then
        BR:SetEnabled(false)
    else
        print("|cff00ff00YippYapp|r: /yh brez [preview|clear|lock|unlock|on|off]")
    end
end
