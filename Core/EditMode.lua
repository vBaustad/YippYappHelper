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
--
-- EMPTY, since the Battle Res Timer went. It was the last entry: every
-- other window in this addon moves itself, dragged where you want it
-- while it is open, and only the timer -- which is up during a pull,
-- when dragging anything is the last thing you want to be doing --
-- needed a mode of its own to place it.
--
-- Kept as a table rather than deleted with the feature. Everything
-- around it is machinery, not a feature: the lifecycle below still
-- registers whatever is in here, the library is still embedded, and one
-- entry brings the whole thing back. Deleting it would be deleting the
-- ability to have a placeable frame at all, which is not what retiring
-- one timer means.
local FRAMES = {
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
    -- Nothing to place. Said out loud rather than opening an Edit Mode
    -- with no outlines in it, which reads as the feature being broken
    -- instead of empty.
    if #FRAMES == 0 then
        print("|cff00ff00YippYapp|r has no frames to position - every window "
            .. "moves itself. Drag one while it is open.")
        return false
    end
    if InCombatLockdown() then
        print("|cffff5555YippYapp:|r Edit Mode cannot be opened in combat.")
        return false
    end
    if not EditModeManagerFrame then
        print("|cffff5555YippYapp:|r Edit Mode is not available on this client.")
        return false
    end
    -- Step out of the way: Edit Mode dims and locks out other UI.

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
