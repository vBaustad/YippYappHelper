local _, ns = ...

------------------------------------------------------------
-- Movable frame registry.
--
-- LibEditMode owns everything to do with positioning: selection outlines,
-- "Click to Edit", dragging, snapping, the settings dialog, and saving
-- per-layout positions. See Core/EditModeLib.lua for the registration.
--
-- This file is only the adapter layer. Our four movable frames each have
-- their own idea of "locked" and their own way of being made visible, and
-- most only exist during their own encounter. LibEditMode cannot select a
-- frame that is hidden or absent, so entering Edit Mode has to conjure
-- each one first. That is all this does.
--
-- Positioning used to be per-frame Unlock/Lock buttons in the options
-- panel, which could not work: Blizzard's settings window is not movable
-- and covers the screen, so you unlocked a frame and then could not see
-- it. Those buttons are gone.
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
    },
    {
        key   = "readyCheck",
        label = "Ready Check",
        frame = function() return _G.YippYappReadyCheck end,
        -- No lock concept of its own: it saves position on drag and has
        -- no unlock affordance, so there is nothing to toggle.
        isLocked  = function() return true end,
        setLocked = function() end,
        show      = function()
            if ns.ReadyCheck and ns.ReadyCheck.Preview then
                ns.ReadyCheck.Preview(true)   -- 24-player test roster
            end
        end,
        hide      = function() if ns.ReadyCheck and ns.ReadyCheck.Hide then ns.ReadyCheck.Hide() end end,
        available = function() return ns.ReadyCheck ~= nil end,
    },
    {
        key   = "mplusCompletion",
        label = "Mythic+ Completion",
        frame = function() return _G.YippYappMPlusCompletion end,
        isLocked  = function() return ns.IsCompletionPopupLocked and ns.IsCompletionPopupLocked() end,
        setLocked = function(v) if ns.SetCompletionPopupLocked then ns.SetCompletionPopupLocked(v) end end,
        show      = function() if ns.ShowCompletionPopupTest then ns.ShowCompletionPopupTest() end end,
        hide      = function() if ns.HideCompletionPopup then ns.HideCompletionPopup() end end,
        available = function() return ns.SetCompletionPopupLocked ~= nil end,
    },
    {
        key   = "utilityAdvisor",
        label = "Utility Advisor",
        frame = function() return _G.YippYappUtilityAdvisor end,
        isLocked  = function()
            local UA = ns.UtilityAdvisor
            return not UA or not UA.IsLocked or UA:IsLocked()
        end,
        setLocked = function(v)
            if ns.UtilityAdvisor and ns.UtilityAdvisor.SetLocked then
                ns.UtilityAdvisor:SetLocked(v)
            end
        end,
        show = function()
            if ns.UtilityAdvisor and ns.UtilityAdvisor.ShowTest then ns.UtilityAdvisor:ShowTest() end
        end,
        -- This entry had no hide at all, so unticking it in the toggle
        -- panel called a nil field and the window simply stayed up.
        hide = function()
            if ns.UtilityAdvisor and ns.UtilityAdvisor.Hide then ns.UtilityAdvisor:Hide() end
        end,
        available = function()
            return ns.UtilityAdvisor and ns.UtilityAdvisor.SetLocked ~= nil
        end,
    },
}

function EM:Frames() return FRAMES end

------------------------------------------------------------
-- Which frames are conjured for editing
------------------------------------------------------------
-- Showing all five at once buries the screen -- the completion popup,
-- utility advisor and ready-check overview are full windows, and their
-- test content is deliberately busy. Remembered per character so the
-- choice survives leaving and re-entering Edit Mode.

local function showDB()
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.editModeShow = YippYappHelperDB.editModeShow or {}
    return YippYappHelperDB.editModeShow
end

function EM:IsShownForEditing(key)
    local v = showDB()[key]
    if v == nil then return true end   -- default: everything visible
    return v and true or false
end

function EM:SetShownForEditing(key, on)
    showDB()[key] = on and true or false
    for _, def in ipairs(FRAMES) do
        if def.key == key and def.available and def.available() then
            local frame = def.frame and def.frame()
            if on then
                pcall(def.setLocked, true)
                if def.show then pcall(def.show) end
                -- A frame conjured after Edit Mode opened has a dormant
                -- selection; LibEditMode only reveals them on entry.
                if ns.EditModeLib then
                    if ns.EditModeLib.SetSelectionShown then
                        ns.EditModeLib.SetSelectionShown(frame, true)
                    end
                    if ns.EditModeLib.Reveal then
                        C_Timer.After(0, ns.EditModeLib.Reveal)
                    end
                end
            else
                if def.hide then pcall(def.hide) end
                -- Some frames stay visible in their own right -- the
                -- tracker with "Always" ticked is still tracking. Hiding
                -- the content is not enough: the selection overlay has to
                -- go too, or an unticked frame still wears a blue box.
                if ns.EditModeLib and ns.EditModeLib.SetSelectionShown then
                    ns.EditModeLib.SetSelectionShown(frame, false)
                end
            end
        end
    end
end

------------------------------------------------------------
-- Toggle panel
------------------------------------------------------------

local togglePanel

local function BuildTogglePanel()
    if togglePanel then return togglePanel end

    -- The Edit Mode manager is the classic ornate dialog: a dark
    -- translucent fill inside a gold border with decorated corners.
    -- Reading its NineSlice layout name off the live frame returned
    -- nothing, and DefaultPanelTemplate is a flatter, opaque panel -- so
    -- apply the dialog art directly. The insets are the standard ones for
    -- this border; smaller values let the fill bleed over the frame.
    local p = CreateFrame("Frame", "YippYappEditModeToggles", UIParent, "BackdropTemplate")
    p:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true,
        tileSize = 32,
        edgeSize = 32,
        insets   = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    p:SetBackdropColor(1, 1, 1, 0.9)

    p:SetSize(250, 96 + #FRAMES * 26)
    p:SetFrameStrata("DIALOG")
    p:EnableMouse(true)

    -- Anchored to the Edit Mode manager rather than to the screen, so it
    -- travels with the panel it belongs to. Deliberately not movable: a
    -- separately draggable box is what made it feel bolted on.
    p:ClearAllPoints()
    if EditModeManagerFrame then
        p:SetPoint("TOPLEFT", EditModeManagerFrame, "TOPRIGHT", 6, 0)
    else
        p:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -140)
    end

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText("YippYapp Frames")

    -- Say what these do. A checkbox next to a feature name reads as an
    -- enable switch, and unticking one here only stops it being conjured
    -- for editing -- the feature itself is untouched.
    local hint = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", 18, -40)
    hint:SetPoint("TOPRIGHT", -16, -40)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetTextColor(0.55, 0.55, 0.58)
    hint:SetText("Show while editing. Does not enable or disable anything.")

    local y = -74
    for _, def in ipairs(FRAMES) do
        local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
        cb:SetSize(26, 26)
        cb:SetPoint("TOPLEFT", 16, y)
        cb:SetChecked(EM:IsShownForEditing(def.key))
        cb:SetScript("OnClick", function(self)
            EM:SetShownForEditing(def.key, self:GetChecked())
        end)

        local lbl = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        lbl:SetText(def.label)
        lbl:SetTextColor(1, 1, 1)   -- Blizzard's option labels are white

        def._checkbox = cb
        y = y - 26
    end

    p:Hide()
    togglePanel = p
    return p
end

function EM:ShowTogglePanel()
    local p = BuildTogglePanel()
    for _, def in ipairs(FRAMES) do
        if def._checkbox then
            def._checkbox:SetChecked(EM:IsShownForEditing(def.key))
            def._checkbox:SetEnabled(def.available and def.available() or false)
        end
    end
    p:Show()
end

function EM:HideTogglePanel()
    if togglePanel then togglePanel:Hide() end
end

--- Reveals every registered frame so LibEditMode has something to select.
---
--- Each frame is also forced *locked*. LibEditMode drags through its own
--- selection frame and manages SetMovable itself, so a module's native
--- drag is redundant under it — and an unlocked module draws its own
--- "drag to move" overlay, which showed through as a second ghost label.
function EM:ShowAllForEditing()
    for _, def in ipairs(FRAMES) do
        if def.available and def.available() then
            -- Lock FIRST, then show. Three of these modules hide themselves
            -- as part of locking (the popup and advisor both run
            -- `if locked then win:Hide() end`, and the brez timer's lock
            -- clears its preview). Showing first meant immediately undoing
            -- it, which is why nothing appeared until a settings change
            -- happened to call show() again on its own.
            pcall(def.setLocked, true)
            if EM:IsShownForEditing(def.key) then
                if def.show then pcall(def.show) end
            elseif def.hide then
                pcall(def.hide)
            end
        end
    end
    EM:ShowTogglePanel()
end

--- Hides the dummy content again once Edit Mode closes. Frames stay
--- locked: LibEditMode is the only thing that should ever move them.
function EM:RestoreAfterEditing()
    EM:HideTogglePanel()
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
            if EM:IsShownForEditing(def.key) and (not f or not f:IsShown()) then
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
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    ShowUIPanel(EditModeManagerFrame)
    return true
end
