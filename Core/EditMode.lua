local _, ns = ...

------------------------------------------------------------
-- Movable frame registry.
--
-- LibEditMode owns everything to do with positioning: selection outlines,
-- "Click to Edit", dragging, snapping, the settings dialog, and saving
-- per-layout positions. See Core/EditModeLib.lua for the registration.
--
-- This file is only the adapter layer. Our movable frames each have
-- their own idea of "locked" and their own way of being made visible,
-- and most only exist during their own encounter. LibEditMode cannot
-- select a frame that is hidden or absent, so entering Edit Mode has to
-- conjure each one first. That is all this does.
--
-- Two frames here, not five. The ready-check overview, the after-key
-- summary and the dungeon utility notes are not Edit Mode's business:
-- they appear on their own schedule and are dragged wherever you like
-- while they are open, which is a better fit than a mode you have to
-- enter to move something you are already looking at. See Core/Hud.lua.
--
-- What is left is the two frames that ARE always on screen, which is
-- exactly the case Edit Mode is built for. It also retired the "show
-- while editing" checkbox panel that used to sit beside the Edit Mode
-- manager: it existed because five frames buried each other on entry,
-- and a small timer and a strip of bars do not.
--
-- Positioning used to be per-frame Unlock/Lock buttons in the options
-- panel, which could not work: Blizzard's settings window is not movable
-- and covers the screen, so you unlocked a frame and then could not see
-- it. Those buttons are gone too.
------------------------------------------------------------

ns.EditMode = ns.EditMode or {}
local EM = ns.EditMode

-- `show` is what makes the frame visible while positioning. `frame` is
-- resolved lazily because several are built the first time they are used.
local FRAMES = {
    {
        key   = "brez",
        label = "Battle Res Timer",
        frame = function() return _G.YYH_BattleResTimer end,
        isLocked  = function() local BR = ns.BattleResTimer; return not BR or BR:IsLocked() end,
        setLocked = function(v) if ns.BattleResTimer then ns.BattleResTimer:SetLocked(v) end end,
        show      = function() if ns.BattleResTimer then ns.BattleResTimer:Preview() end end,
        hide      = function() if ns.BattleResTimer then ns.BattleResTimer:ClearPreview() end end,
        available = function() return ns.BattleResTimer ~= nil end,
        enabled   = function()
            local BR = ns.BattleResTimer
            return not BR or not BR.IsEnabled or BR:IsEnabled()
        end,
    },
    {
        key   = "interrupts",
        label = "Interrupt Tracker",
        frame = function() return _G.YippYappInterruptsRoot end,
        isLocked  = function()
            local S = ns.InterruptsSettings
            return not S or (S:Get("locked") and true or false)
        end,
        setLocked = function(v)
            local S = ns.InterruptsSettings
            if S then S:Set("locked", v and true or false) end
        end,
        -- Test mode fills the tracker with five dummy bars, which is the
        -- whole point during editing: bar width, height, spacing, icons
        -- and text options are meaningless against an empty frame.
        --
        -- Capture the player's real setting once, on the way in. show() is
        -- called again by RefreshPreviews after every settings change, and
        -- re-capturing there would record the value we just forced -- so
        -- exiting Edit Mode would strand the tracker in test mode.
        show = function()
            local S = ns.InterruptsSettings
            if not S then return end
            if EM._trackerTest == nil then
                EM._trackerTest = S:Get("testMode") and true or false
            end
            S:Set("testMode", true)
        end,
        hide = function()
            local S = ns.InterruptsSettings
            if not S then return end
            S:Set("testMode", EM._trackerTest and true or false)
            EM._trackerTest = nil
        end,
        available = function() return ns.InterruptsSettings ~= nil end,
        -- Test mode forces the tracker past every visibility rule, but
        -- not past being switched off: ShouldShow checks `enabled`
        -- first. So a disabled tracker has no frame to select and Edit
        -- Mode has nothing to draw an outline on -- which looks exactly
        -- like a broken addon rather than a ticked-off checkbox.
        enabled = function()
            local S = ns.InterruptsSettings
            return not S or (S:Get("enabled") and true or false)
        end,
    },
}

function EM:Frames() return FRAMES end

--- Reveals every registered frame so LibEditMode has something to select.
---
--- Each frame is also forced *locked*. LibEditMode drags through its own
--- selection frame and manages SetMovable itself, so a module's native
--- drag is redundant under it — and an unlocked module draws its own
--- "drag to move" overlay, which showed through as a second ghost label.
function EM:ShowAllForEditing()
    -- Say which frames will not be there, once, on the way in. Edit Mode
    -- can only ever show you what exists, and a disabled module is
    -- indistinguishable from a bug from the inside of it.
    local off
    for _, def in ipairs(FRAMES) do
        if def.available and def.available() and def.enabled and not def.enabled() then
            off = (off and (off .. ", ") or "") .. def.label
        end
    end
    if off then
        print("|cffff9955YippYapp:|r " .. off .. " is switched off, so there is nothing "
            .. "to position. Turn it on in Options - AddOns - YippYapp Helper.")
    end

    for _, def in ipairs(FRAMES) do
        if def.available and def.available() then
            -- Lock FIRST, then show. Some of these modules hide
            -- themselves as part of locking, so showing first meant
            -- immediately undoing it -- which is why nothing appeared
            -- until a settings change happened to call show() again on
            -- its own.
            pcall(def.setLocked, true)
            if def.show then pcall(def.show) end
        end
    end
end

--- Hides the dummy content again once Edit Mode closes. Frames stay
--- locked: LibEditMode is the only thing that should ever move them.
function EM:RestoreAfterEditing()
    for _, def in ipairs(FRAMES) do
        if def.available and def.available() then
            pcall(def.setLocked, true)
            if def.hide then pcall(def.hide) end
        end
    end
end

--- Re-asserts the dummy content. Modules tear their contents down on any
--- settings change, which would otherwise leave an empty shell mid-edit.
function EM:RefreshPreviews()
    for _, def in ipairs(FRAMES) do
        if def.available and def.available() and def.show then
            -- Only revive what actually went away. These builders tear
            -- down and rebuild their contents, so calling them on a frame
            -- that is already fine is churn at best and, in the completion
            -- popup's case, orphans its pooled rows.
            local f = def.frame and def.frame()
            if not f or not f:IsShown() then
                pcall(def.show)
            end
        end
    end
end

--- Opens Blizzard's Edit Mode. LibEditMode's enter callback takes it from
--- here, so this is the only entry point the options panel needs.
function EM:Open()
    if InCombatLockdown() then
        print("|cffff5555YippYapp:|r Edit Mode cannot be opened in combat.")
        return false
    end
    if not EditModeManagerFrame then
        print("|cffff5555YippYapp:|r Edit Mode is not available on this client.")
        return false
    end
    -- Step out of the way: Edit Mode dims and locks out other UI.
    if ns.AppFrame and ns.AppFrame:IsShown() then ns.AppFrame:Hide() end

    -- Both panel calls go through securecall.
    --
    -- ShowUIPanel and HideUIPanel run inside FramePositionDelegate, which
    -- is a secure object. Calling them straight from addon code taints
    -- the whole panel-management system for the rest of the session, and
    -- a tainted FramePositionDelegate is one of the classic ways an addon
    -- leaves a UI subtly wrong: panels open in the wrong slot, and
    -- protected calls further along the same path get blocked. Those
    -- blocks are silent unless scriptErrors is on, so the only thing the
    -- player sees is a keybind that stopped working.
    --
    -- securecall runs the function without the caller's taint following
    -- it in, which is exactly what this needs -- showing a panel is not a
    -- protected action, so nothing here required the taint to begin with.
    if SettingsPanel and SettingsPanel:IsShown() then
        securecall("HideUIPanel", SettingsPanel)
    end
    securecall("ShowUIPanel", EditModeManagerFrame)
    return true
end
