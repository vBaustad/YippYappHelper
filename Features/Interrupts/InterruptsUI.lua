local _, ns = ...

------------------------------------------------------------
-- Interrupts UI: configurable party interrupt tracker.
-- Driven by InterruptsSettings; supports bar/icon modes,
-- orientation, grow direction, class coloring, timers, etc.
------------------------------------------------------------

ns.InterruptsUI = ns.InterruptsUI or {}
local UI = ns.InterruptsUI

local root
local slots = {}       -- slots[unitKey] = frame (unitKey: "player"/"party1"..)
local slotOrder = {}   -- stable order list of unit keys currently shown

-- Persistent slot pools keyed by mode. Slots live forever once created
-- (WoW frames can't be destroyed) so we reuse them across rebuilds
-- instead of CreateFrame'ing fresh ones on every GROUP_ROSTER_UPDATE /
-- ZONE_CHANGED_NEW_AREA. The pool size caps at #UNIT_KEYS (5).
local slotPools = { bar = {}, icon = {} }

local UNIT_KEYS = { "player", "party1", "party2", "party3", "party4" }

local function S()
    return ns.InterruptsSettings
end

local function classColor(class)
    if not class then return 1, 1, 1 end
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then return 1, 1, 1 end
    return c.r, c.g, c.b
end

------------------------------------------------------------
-- Root frame
------------------------------------------------------------

-- Forward declarations so closures created inside ensureRoot (OnDragStop
-- in particular) can reach these — they're defined further down in the
-- file, but the closure is bound when ensureRoot runs.
local rebuild
local applyPosition

local function ensureRoot()
    if root then return root end
    root = CreateFrame("Frame", "YippYappInterruptsRoot", UIParent, "BackdropTemplate")
    root:SetSize(1, 1)
    root:SetMovable(true)
    -- Mouse follows the lock, and applyLockedState below keeps it there.
    --
    -- This used to be an unconditional EnableMouse(true), which made the
    -- tracker eat every mouse click landing on it for the entire session.
    -- Locking did not help: locked only refuses the drag, the click is
    -- still consumed. A consumed click never reaches the binding system,
    -- so a mouse-button keybind pressed with the cursor over the tracker
    -- silently did nothing -- no error, no message, and the tracker sits
    -- at the middle of the screen by default.
    --
    -- Nothing here needs the mouse otherwise: the tracker has no
    -- tooltips and no clickable parts, only the drag.
    root:EnableMouse(false)
    root:RegisterForDrag("LeftButton")
    root:SetScript("OnDragStart", function(self)
        if S() and S():Get("locked") then return end
        self._dragging = true
        self:StartMoving()
    end)
    root:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self._dragging = false
        local _, _, anchor, x, y = self:GetPoint(1)
        local S_ = S()
        if not S_ then return end
        local all = S_:All()
        all.anchor = anchor or "CENTER"
        all.posX = x or 0
        all.posY = y or 0
        applyPosition()
        -- If events tried to rebuild while we were dragging, honor it now.
        if self._pendingRebuild then
            self._pendingRebuild = false
            rebuild()
        end
    end)

    -- inner content frame so the backdrop can inset/pad around slots
    root.content = CreateFrame("Frame", nil, root)

    -- Drag overlay: visible whenever the frame is unlocked. Shows a cyan
    -- dashed-style border and a centered "drag" label to signal that the
    -- tracker can be moved.
    local overlay = CreateFrame("Frame", nil, root, "BackdropTemplate")
    overlay:SetAllPoints(root)
    overlay:SetFrameLevel(root:GetFrameLevel() + 10)
    overlay:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    overlay:SetBackdropColor(0, 0.6, 1.0, 0.12)
    overlay:SetBackdropBorderColor(0, 0.8, 1.0, 0.9)
    overlay:EnableMouse(false)

    local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmallOutline")
    label:SetPoint("CENTER")
    label:SetText("drag to move")
    label:SetTextColor(0, 0.9, 1.0)

    overlay:Hide()
    root.dragOverlay = overlay
    return root
end

local function applyLockedState()
    if not root then return end
    local locked = S() and S():Get("locked")
    -- The mouse is the drag, and the drag is the only thing an unlocked
    -- tracker offers. See ensureRoot for what leaving it on costs.
    root:EnableMouse(not locked)
    if root.dragOverlay then
        root.dragOverlay:SetShown(not locked)
    end
end

local function applyBackdrop()
    if not root then return end
    local d = S():All()
    if d.showBackdrop then
        -- Background fill only, no edge. Every bar already carries its own
        -- border, so an outer frame border just boxed in the whole tracker
        -- without adding information -- and drew a bare rectangle on screen
        -- whenever there was nothing to track.
        root:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        local a = (d.backdropAlpha or 85) / 100
        root:SetBackdropColor(0, 0, 0, a)
    else
        ns.Widgets:Unskin(root)
    end
end

-- Root's own anchor corner, derived from grow direction, so the pinned
-- side of the tracker stays fixed regardless of how many bars are shown.
local function rootAnchorForGrow(grow)
    if grow == "up"    then return "BOTTOMLEFT" end
    if grow == "left"  then return "TOPRIGHT"   end
    return "TOPLEFT" -- down / right / default
end

function applyPosition()
    if not root then return end
    -- Edit Mode owns the position when it is managing this frame. Without
    -- this, rebuild() re-anchors from our own saved coords and undoes the
    -- player's Edit Mode placement on every settings change.
    if ns.EditModeManagesPosition and ns.EditModeManagesPosition("interrupts") then
        return
    end
    local d = S():All()
    root:ClearAllPoints()
    local rootAnchor = rootAnchorForGrow(d.growDirection)
    root:SetPoint(rootAnchor, UIParent, d.anchor or "CENTER", d.posX or 0, d.posY or 0)
end

------------------------------------------------------------
-- Slot construction (bar or icon)
------------------------------------------------------------

local function buildBarSlot()
    local s = CreateFrame("Frame", nil, root.content or root, "BackdropTemplate")
    s:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    s:SetBackdropColor(0, 0, 0, 1)
    s:SetBackdropBorderColor(0, 0, 0, 1)

    s.bg = s:CreateTexture(nil, "BACKGROUND")
    s.bg:SetAllPoints()
    s.bg:SetColorTexture(0, 0, 0, 0.6)

    s.bar = CreateFrame("StatusBar", nil, s)
    s.bar:SetPoint("TOPLEFT", s, "TOPLEFT", 1, -1)
    s.bar:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -1, 1)
    s.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    s.bar:SetMinMaxValues(0, 1)
    s.bar:SetValue(1)

    s.spellIcon = s:CreateTexture(nil, "ARTWORK")
    s.spellIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    s.name = s.bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmallOutline")
    s.timer = s.bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmallOutline")
    s.timer:SetJustifyH("RIGHT")

    s.spellIcon:SetDrawLayer("OVERLAY", 1)

    return s
end

local function buildIconSlot()
    local s = CreateFrame("Frame", nil, root.content or root, "BackdropTemplate")
    s:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    s:SetBackdropColor(0, 0, 0, 1)
    s:SetBackdropBorderColor(0, 0, 0, 1)
    s.bg = s:CreateTexture(nil, "BACKGROUND")
    s.bg:SetAllPoints()
    s.bg:SetColorTexture(0, 0, 0, 0.6)

    s.spellIcon = s:CreateTexture(nil, "ARTWORK")
    s.spellIcon:SetPoint("TOPLEFT", 1, -1)
    s.spellIcon:SetPoint("BOTTOMRIGHT", -1, 1)
    s.spellIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    s.cd = CreateFrame("Cooldown", nil, s, "CooldownFrameTemplate")
    s.cd:SetAllPoints(s.spellIcon)

    s.name = s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmallOutline")
    s.name:SetPoint("BOTTOM", s, "TOP", 0, 2)

    s.timer = s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmallOutline")
    s.timer:SetPoint("CENTER", s, "CENTER")

    return s
end

local function slotSize(mode, d)
    if mode == "bar" then
        return d.barWidth, d.barHeight
    end
    return d.iconSize, d.iconSize
end

------------------------------------------------------------
-- Layout
------------------------------------------------------------

local function layoutSlots()
    if not root then return end
    local d = S():All()
    local w, h = slotSize(d.mode, d)
    local spacing = d.spacing or 4
    local grow = d.growDirection
    local vertical = (grow == "up" or grow == "down")

    local count = math.max(1, #slotOrder)
    local step = vertical and (h + spacing) or (w + spacing)
    local contentW = vertical and w or (count * w + (count - 1) * spacing)
    local contentH = vertical and (count * h + (count - 1) * spacing) or h
    local pad = d.framePadding or 6

    -- Anchor content to the same corner of root that root is pinned by,
    -- so growth always extends away from the pinned side.
    local rootAnchor = rootAnchorForGrow(grow)
    root.content:ClearAllPoints()
    if rootAnchor == "TOPLEFT" then
        root.content:SetPoint("TOPLEFT", root, "TOPLEFT", pad, -pad)
    elseif rootAnchor == "BOTTOMLEFT" then
        root.content:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", pad, pad)
    elseif rootAnchor == "TOPRIGHT" then
        root.content:SetPoint("TOPRIGHT", root, "TOPRIGHT", -pad, -pad)
    end
    root.content:SetSize(contentW, contentH)
    root:SetSize(contentW + pad * 2, contentH + pad * 2)

    for i, key in ipairs(slotOrder) do
        local s = slots[key]
        if s then
            s:ClearAllPoints()
            s:SetSize(w, h)
            if grow == "down" then
                s:SetPoint("TOPLEFT", root.content, "TOPLEFT", 0, -(i - 1) * step)
            elseif grow == "up" then
                s:SetPoint("BOTTOMLEFT", root.content, "BOTTOMLEFT", 0, (i - 1) * step)
            elseif grow == "right" then
                s:SetPoint("TOPLEFT", root.content, "TOPLEFT", (i - 1) * step, 0)
            elseif grow == "left" then
                s:SetPoint("TOPRIGHT", root.content, "TOPRIGHT", -(i - 1) * step, 0)
            end
        end
    end
end

------------------------------------------------------------
-- Slot styling (applies settings to a single slot)
------------------------------------------------------------

local function resolveSpellID(entry, class)
    if entry and entry.spellID then return entry.spellID end
    if ns.Interrupts and ns.Interrupts.GetDefaultInterrupt then
        -- Pass the unit: for the player it lets the lookup ask the game
        -- which interrupt is actually known, rather than guessing from
        -- class alone and showing a Feral ability to a Balance druid.
        return ns.Interrupts:GetDefaultInterrupt(class, entry and entry.unit)
    end
end

local function styleSlot(s, d, entry)
    local _, unitClass = UnitClass(entry and entry.unit or "player")
    local class = (entry and entry.class) or unitClass
    local spellID = resolveSpellID(entry, class)

    -- Apply bar texture
    if s.bar and S().GetBarTexturePath then
        s.bar:SetStatusBarTexture(S():GetBarTexturePath(d.barTexture))
    end

    -- Spell icon (always shown when enabled; uses class default at rest)
    if s.spellIcon then
        if d.showSpellIcon and spellID then
            local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
            s.spellIcon:SetTexture((info and info.iconID) or 134400)
            s.spellIcon:Show()
        else
            s.spellIcon:Hide()
        end
    end

    -- Spell icon placement on bar mode (square on the left)
    if d.mode == "bar" and s.spellIcon and s.spellIcon:IsShown() then
        s.spellIcon:ClearAllPoints()
        s.spellIcon:SetPoint("TOPLEFT", s, "TOPLEFT", 1, -1)
        s.spellIcon:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", 1, 1)
        s.spellIcon:SetWidth(d.barHeight - 2)
        if s.bar then
            s.bar:ClearAllPoints()
            s.bar:SetPoint("TOPLEFT", s.spellIcon, "TOPRIGHT", 1, 0)
            s.bar:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -1, 1)
        end
    elseif d.mode == "bar" and s.bar then
        s.bar:ClearAllPoints()
        s.bar:SetPoint("TOPLEFT", s, "TOPLEFT", 1, -1)
        s.bar:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -1, 1)
    end

    -- Bar + text coloring per barStyle
    -- Text is always outlined white in classFill mode; class-colored in classText mode
    local r, g, b = classColor(class)
    local barR, barG, barB = r, g, b
    local textR, textG, textB = 1, 1, 1
    if d.barStyle == "classText" then
        barR, barG, barB = 0, 0, 0
        textR, textG, textB = r, g, b
    end
    if s.bar then s.bar:SetStatusBarColor(barR, barG, barB, 1) end

    -- Cache settings flags that slotOnUpdate reads every frame
    s._mode = d.mode
    s._showTimer = d.showTimer
    s._countDown = (d.countDirection == "down")

    -- Class-colored border
    if s.SetBackdropBorderColor then
        if d.classBorder then
            s:SetBackdropBorderColor(r, g, b, 1)
        else
            s:SetBackdropBorderColor(0, 0, 0, 1)
        end
    end

    -- Name
    if s.name then
        if d.showName and entry and entry.name then
            s.name:SetText(entry.name)
            s.name:SetTextColor(textR, textG, textB)
            if d.mode == "bar" then
                s.name:ClearAllPoints()
                s.name:SetPoint("LEFT", s.bar or s, "LEFT", 4, 0)
            end
            s.name:Show()
        else
            s.name:Hide()
        end
    end

    -- Timer text placement (actual text set in OnUpdate)
    if s.timer then
        if d.showTimer then
            if d.mode == "bar" then
                s.timer:ClearAllPoints()
                s.timer:SetPoint("RIGHT", s.bar or s, "RIGHT", -4, 0)
            end
            s.timer:SetTextColor(textR, textG, textB)
            s.timer:Show()
        else
            s.timer:Hide()
        end
    end
end

------------------------------------------------------------
-- OnUpdate: drive bar fill + timer text
------------------------------------------------------------

local function setReadyState(s)
    if s.bar then
        s.bar:SetValue(1)
        s.bar:SetAlpha(1)
    end
    if s.timer then s.timer:SetText("") end
    if s.cd then s.cd:Clear() end
    s:SetAlpha(1)
end

-- Throttle OnUpdate to ~20fps; bar timer resolution doesn't need per-frame.
-- Also cache settings-derived flags on the slot itself (refreshed only when
-- settings change) so we don't call S():All() 60 times/sec per slot.
local SLOT_UPDATE_HZ = 1 / 20

local function slotOnUpdate(s, elapsed)
    s._acc = (s._acc or 0) + elapsed
    if s._acc < SLOT_UPDATE_HZ then return end
    s._acc = 0

    local entry = s._entry
    if not entry or not entry.lastCastAt or not entry.readyAt then
        setReadyState(s); return
    end
    local duration = entry.readyAt - entry.lastCastAt
    if duration <= 0 then return end
    local now = GetTime()
    local remaining = entry.readyAt - now
    if remaining <= 0 then
        setReadyState(s)
        s._entry = nil
        return
    end
    local elapsedSince = now - entry.lastCastAt

    if s._mode == "bar" and s.bar then
        s.bar:SetValue(remaining / duration)
        -- Cooldown state is already signalled by the bar draining; the
        -- old 0.5 / 0.85 fade just made it darker and harder to read.
        s.bar:SetAlpha(1)
    end
    s:SetAlpha(1)

    if s.timer and s._showTimer then
        local v = s._countDown and remaining or elapsedSince
        s.timer:SetFormattedText(v >= 10 and "%.0f" or "%.1f", v)
    end
    if s._mode == "icon" and s.cd and not s._cdStarted then
        s.cd:SetCooldown(entry.lastCastAt, duration)
        s._cdStarted = true
    end
end

------------------------------------------------------------
-- Rebuild: tear down & recreate slots for current roster/mode
------------------------------------------------------------

local function acquireSlot(mode)
    local pool = slotPools[mode]
    for i = 1, #pool do
        local s = pool[i]
        if not s._inUse then
            s._inUse = true
            -- releaseAllSlots hides everything at the start of each
            -- rebuild, and nothing showed them again. A freshly created
            -- frame is visible by default, so the first rebuild looked
            -- fine and every one after it produced an empty tracker.
            s:Show()
            return s
        end
    end
    local s = (mode == "bar") and buildBarSlot() or buildIconSlot()
    s._mode = mode
    s._inUse = true
    table.insert(pool, s)
    return s
end

local function releaseAllSlots()
    for _, pool in pairs(slotPools) do
        for _, s in ipairs(pool) do
            if s._inUse then
                s._inUse = false
                s:Hide()
                s:SetScript("OnUpdate", nil)
                s._entry = nil
                s._cdStarted = false
            end
        end
    end
end

function rebuild()
    ensureRoot()
    -- Never tear down & reposition the frame while the user is dragging —
    -- otherwise GROUP_ROSTER_UPDATE firing mid-drag (e.g. invite landing)
    -- makes the frame jump out from under the cursor.
    if root._dragging then
        root._pendingRebuild = true
        return
    end
    local d = S():All()

    -- Return all live slots to their pools. We never SetParent(nil) —
    -- that would orphan a frame that can't be garbage-collected in WoW.
    releaseAllSlots()
    wipe(slots); wipe(slotOrder)

    local units = UNIT_KEYS
    if d.testMode then
        units = UNIT_KEYS -- show all five with dummy data
    end

    local now = GetTime()
    for _, u in ipairs(units) do
        if d.testMode or UnitExists(u) then
            local s = acquireSlot(d.mode)
            s:SetScript("OnUpdate", slotOnUpdate)
            slots[u] = s
            table.insert(slotOrder, u)
            if d.testMode then
                local _, class = UnitClass(u)
                if not class then class = ({"WARRIOR","MAGE","PRIEST","ROGUE","DRUID"})[#slotOrder] end
                s._entry = {
                    name = UnitName(u) or ("Player" .. #slotOrder),
                    class = class,
                    unit = u,
                    spellID = 1766,
                    lastCastAt = now,
                    readyAt = now + 15,
                }
                styleSlot(s, d, s._entry)
            else
                -- Reattach any in-flight CD for this unit. ns.Interrupts.state
                -- is keyed by GUID and survives slot teardown; without this,
                -- any rebuild (GROUP_ROSTER_UPDATE, zone-in, etc.) would
                -- visually reset an active cooldown bar.
                local guid = UnitGUID(u)
                local active = ns.Interrupts and ns.Interrupts.state and guid and ns.Interrupts.state[guid]
                if active and active.readyAt and active.readyAt > now then
                    s._entry = active
                    s._cdStarted = false
                    styleSlot(s, d, active)
                else
                    styleSlot(s, d, { unit = u, name = UnitName(u), class = select(2, UnitClass(u)) })
                end
            end
        end
    end

    layoutSlots()
    applyPosition()
    applyBackdrop()
    applyLockedState()
    UI:ApplyVisibility()
end

------------------------------------------------------------
-- Visibility
------------------------------------------------------------

function UI:ApplyVisibility()
    if not root then return end
    -- An empty tracker is worse than no tracker: with "Always" ticked and
    -- no interrupt-capable group members, the frame drew as a bare
    -- bordered rectangle sitting on the screen forever. Nothing to track
    -- means nothing to show, whatever the visibility rule says.
    if S():ShouldShow() and #slotOrder > 0 then root:Show() else root:Hide() end
end

------------------------------------------------------------
-- Data callbacks
------------------------------------------------------------

function UI:OnCast(guid, entry)
    ensureRoot()
    local unit = entry.unit
    local s = slots[unit]
    if not s then
        rebuild()
        s = slots[unit]
    end
    if not s then return end
    s._entry = entry
    s._cdStarted = false
    styleSlot(s, S():All(), entry)
end

function UI:OnAttributed(guid, nameplateUnit, spellID)
    -- Attribution used to call UIFrameFlash here, but (a) its showWhenDone=false
    -- hid the slot when the flash finished so the countdown stopped, and
    -- (b) its alpha animation fought slotOnUpdate's own SetAlpha. The bar
    -- draining is already visual feedback enough — leave OnCast to show the CD.
end

------------------------------------------------------------
-- Settings change hook
------------------------------------------------------------

local function onSettingChanged(key)
    if key == "posX" or key == "posY" or key == "anchor" then
        applyPosition()
    elseif key == "locked" then
        applyLockedState()
    elseif key == "enabled" or key == "visibility" or key == "testMode" then
        rebuild()
    else
        rebuild()
    end
end

------------------------------------------------------------
-- Init
------------------------------------------------------------

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:RegisterEvent("PLAYER_ENTERING_WORLD")
init:RegisterEvent("GROUP_ROSTER_UPDATE")
init:RegisterEvent("ZONE_CHANGED_NEW_AREA")
init:RegisterEvent("CHALLENGE_MODE_START")
init:RegisterEvent("CHALLENGE_MODE_COMPLETED")
init:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        if S() and S().OnChanged then S():OnChanged(onSettingChanged) end
        rebuild()
    else
        UI:ApplyVisibility()
        if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
            rebuild()
        end
    end
end)
