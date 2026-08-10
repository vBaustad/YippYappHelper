local _, ns = ...

------------------------------------------------------------
-- LibEditMode integration.
--
-- When LibEditMode is present our frames become real Edit Mode systems:
-- Blizzard's own selection outlines and "Click to Edit" hover, snapping
-- against the grid and other elements, and a native settings dialog with
-- the game's dropdowns, sliders and checkboxes.
--
-- Without it, Core/EditMode.lua's hand-drawn selection boxes take over.
-- That fallback exists because the library is optional: it is not vendored
-- with the addon, so a user who has not installed it still gets working
-- (if plainer) frame positioning rather than none at all.
--
-- Positions live in YippYappHelperDB.editMode, keyed by Edit Mode layout,
-- because the whole point of layouts is that a raid layout and a solo
-- layout can put the same frame in different places.
------------------------------------------------------------

local LEM = LibStub and LibStub("LibEditMode", true)
if not LEM then return end

ns.EditModeLib = { active = true }

-- Modules re-anchor themselves from their own saved position whenever
-- they rebuild, which fought LibEditMode for ownership: change any
-- setting, and the frame snapped back to where the module thought it
-- belonged. They now defer to this instead of racing it.
local managesPosition = {}
function ns.EditModeManagesPosition(key)
    return managesPosition[key] == true
end

local S = ns.InterruptsSettings

local function posDB(key, layoutName)
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.editMode = YippYappHelperDB.editMode or {}
    YippYappHelperDB.editMode[key] = YippYappHelperDB.editMode[key] or {}
    local byLayout = YippYappHelperDB.editMode[key]
    byLayout[layoutName] = byLayout[layoutName] or {}
    return byLayout[layoutName]
end

--- Appearance options that are not per-layout: a frame's size and
--- opacity are a preference, not something you want differing between a
--- raid layout and a solo one. Position is per-layout; these are not.
local function optDB(key)
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.editModeOpts = YippYappHelperDB.editModeOpts or {}
    YippYappHelperDB.editModeOpts[key] = YippYappHelperDB.editModeOpts[key] or {}
    return YippYappHelperDB.editModeOpts[key]
end

--- Scale and opacity for frames whose module exposes neither. Applied
--- straight to the frame, so it works without every module growing its
--- own API for something purely visual.
local function applyFrameOpts(frame, key)
    local o = optDB(key)
    if o.scale then frame:SetScale(o.scale) end
    if o.alpha then frame:SetAlpha(o.alpha) end
end

local function Kind(name)
    -- SettingType is the library's enum; fall back to the string if a
    -- future version renames it, rather than erroring at load.
    return (LEM.SettingType and LEM.SettingType[name]) or name:lower()
end

--- Applies a stored position, or the default when the layout is new.
--- Re-applies a stored position.
---
--- relativePoint is stored separately from point and must be: a frame can
--- anchor its TOPLEFT to UIParent's CENTER, and collapsing the two (using
--- `point` for both anchors) moves it by half the screen. That is exactly
--- what happened to the interrupt tracker -- it reported shown=y at a
--- real size while sitting outside the viewport.
local function ApplyPosition(frame, key, layoutName, default)
    local p = posDB(key, layoutName)
    local point    = p.point or default.point
    local relPoint = p.relativePoint or p.point or default.relativePoint or default.point
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, relPoint, p.x or default.x, p.y or default.y)
end

-- Frames LibEditMode is positioning for us. Several modules re-anchor
-- themselves from their own saved position on every rebuild, which would
-- yank a frame back the moment any setting changed, so we re-assert the
-- Edit Mode position afterwards.
local managed = {}
local repairPending = false

local function RepairAfterChange()
    if repairPending then return end
    repairPending = true

    C_Timer.After(0.05, function()
        repairPending = false
        -- Rebuilds tear down the dummy content that made the frame
        -- visible, so put it back or the user is left editing nothing.
        if ns.EditMode and ns.EditMode.RefreshPreviews then
            ns.EditMode:RefreshPreviews()
        end
    end)
end

local function Register(frame, key, default, settings, label)
    if not frame then return end
    table.insert(managed, { frame = frame, key = key, default = default })

    -- Seed from where the module already put it. Until this point the
    -- module owned the position and has applied whatever the player had
    -- saved; from here on we own it. Without this the frame would fall
    -- back to the hardcoded CENTER default and every existing position
    -- would be silently thrown away on upgrade.
    local layoutName = LEM.GetActiveLayoutName and LEM:GetActiveLayoutName()
    if layoutName then
        local p = posDB(key, layoutName)
        -- A stored entry without relativePoint predates the fix above and
        -- is very likely off-screen, so re-seed rather than trust it.
        if not p.point or not p.relativePoint then
            local point, _, relPoint, x, y = frame:GetPoint()
            if point then
                p.point, p.relativePoint = point, relPoint
                p.x, p.y = math.floor(x + 0.5), math.floor(y + 0.5)
            end
        end
    end

    managesPosition[key] = true
    applyFrameOpts(frame, key)

    LEM:AddFrame(frame, function(f, layoutName, point, x, y)
        -- LibEditMode normalises to one anchor point, so clear any
        -- relativePoint carried over from the module's own scheme --
        -- leaving a stale one would re-introduce the mismatch above.
        local p = posDB(key, layoutName)
        p.point, p.relativePoint, p.x, p.y = point, point, x, y
    end, default, label)

    -- Raise the selection above the frame's own children. LibEditMode
    -- parents it to the frame at the default level, but our windows put
    -- clickable content on top: the completion popup fills its body with
    -- secure action buttons, and both it and the tracker draw a lock
    -- overlay at level +10. Those swallow the click before the selection
    -- ever sees it, so the frame looks selectable but cannot be picked up.
    local selection = LEM.frameSelections and LEM.frameSelections[frame]
    if selection then
        -- Match the frame's strata. LibEditMode's selection sits at MEDIUM,
        -- but the completion popup raises itself to HIGH -- and strata
        -- outranks frame level, so the frame took every click above its own
        -- selection child. Its close button still worked (also a child of
        -- the HIGH frame), which made it look like a layering problem
        -- within the frame rather than a strata mismatch.
        selection:SetFrameStrata(frame:GetFrameStrata())
        -- Then clear the frame's own children within that strata: the
        -- popup fills its body with secure buttons and both it and the
        -- tracker draw a lock overlay at level +10.
        selection:SetFrameLevel(frame:GetFrameLevel() + 20)
        selection:EnableMouse(true)
    end

    if settings and LEM.AddFrameSettings then
        LEM:AddFrameSettings(frame, settings)
    end

    -- No shortcut to the options panel from here. Blizzard's settings
    -- window cannot open over Edit Mode, so the button would have to
    -- either close Edit Mode -- silently discarding unsaved layout
    -- changes -- or call SaveLayouts, committing edits the player may
    -- have been trying out and meant to revert. Neither is predictable
    -- from a button labelled "settings", and the full options are one
    -- Escape away regardless.

    LEM:RegisterCallback("layout", function(layoutName)
        ApplyPosition(frame, key, layoutName, default)
    end)

    -- Locked for good: LibEditMode drags via its own selection frame, and
    -- an unlocked module also renders its own "drag to move" overlay,
    -- which showed through as a second ghost label.
    if ns.EditMode then
        for _, def in ipairs(ns.EditMode:Frames()) do
            if def.key == key then pcall(def.setLocked, true) end
        end
    end
end

------------------------------------------------------------
-- Setting builders
------------------------------------------------------------

local function Checkbox(name, default, get, set)
    return {
        name = name, kind = Kind("Checkbox"), default = default,
        get = function() return get() and true or false end,
        set = function(_, value) set(value and true or false); RepairAfterChange() end,
    }
end

local function Slider(name, default, minV, maxV, step, get, set, fmt)
    return {
        name = name, kind = Kind("Slider"), default = default,
        minValue = minV, maxValue = maxV, valueStep = step,
        formatter = fmt or function(v) return tostring(math.floor(v)) end,
        get = function() return get() end,
        set = function(_, value) set(value); RepairAfterChange() end,
    }
end

local function Dropdown(name, default, values, get, set)
    return {
        name = name, kind = Kind("Dropdown"), default = default,
        values = values,
        get = function() return get() end,
        set = function(_, value) set(value); RepairAfterChange() end,
    }
end

--- Interrupt-tracker options all share one storage path.
local function TrackerCheckbox(name, key)
    return Checkbox(name, S:Defaults()[key],
        function() return S:Get(key) end,
        function(v) S:Set(key, v) end)
end

local function TrackerSlider(name, key, minV, maxV, step, fmt)
    return Slider(name, S:Defaults()[key], minV, maxV, step,
        function() return S:Get(key) end,
        function(v) S:Set(key, v) end, fmt)
end

--- Scale/opacity sliders for a frame, driving SetScale/SetAlpha directly.
local function FrameScale(key, frame)
    return {
        name = "Scale", kind = Kind("Slider"), default = 100,
        minValue = 50, maxValue = 200, valueStep = 5,
        formatter = function(v) return ("%d%%"):format(math.floor(v)) end,
        get = function() return (optDB(key).scale or 1) * 100 end,
        set = function(_, value)
            optDB(key).scale = value / 100
            if frame then frame:SetScale(value / 100) end
        end,
    }
end

local function FrameAlpha(key, frame)
    return {
        name = "Opacity", kind = Kind("Slider"), default = 100,
        minValue = 20, maxValue = 100, valueStep = 5,
        formatter = function(v) return ("%d%%"):format(math.floor(v)) end,
        get = function() return (optDB(key).alpha or 1) * 100 end,
        set = function(_, value)
            optDB(key).alpha = value / 100
            if frame then frame:SetAlpha(value / 100) end
        end,
    }
end

--- Leading caption for a frame's dialog. These windows appear on their
--- own schedule and cannot be opened manually, so "when does this show
--- up" is the first thing worth saying -- and a tooltip you have to
--- discover does not answer it.
--- No "Enabled" checkbox lives in these dialogs. Disabling a frame hides
--- it, hiding it destroys its selection, and losing the selection closes
--- the dialog -- so the switch deletes the very panel holding it, with no
--- way back without leaving Edit Mode entirely. Enabling is a settings
--- panel concern; Edit Mode is only ever about appearance and position.
local function Caption(text)
    return { name = text, kind = Kind("Divider") }
end

local pct = function(v) return ("%d%%"):format(math.floor(v)) end
local px  = function(v) return ("%dpx"):format(math.floor(v)) end

------------------------------------------------------------
-- Registration
------------------------------------------------------------

local done = {}

local function RegisterAll()
    -- Battle Res Timer
    local BR = ns.BattleResTimer
    if BR and _G.YYH_BattleResTimer and not done.brez then
        done.brez = true
        Register(_G.YYH_BattleResTimer, "brez",
            { point = "CENTER", x = 0, y = -160 }, {
                Caption("Shown in raids and keystone dungeons"),
                Checkbox("Show between pulls", false,
                    function() return BR:IsShowOutOfCombat() end,
                    function(v) BR:SetShowOutOfCombat(v) end),
                Slider("Scale", 100, 50, 250, 5,
                    function() return (BR:GetScale() or 1) * 100 end,
                    function(v) BR:SetScale(v / 100) end, pct),
            }, "Battle Res Timer")
    end

    -- Interrupt Tracker
    if S and _G.YippYappInterruptsRoot and not done.interrupts then
        done.interrupts = true
        Register(_G.YippYappInterruptsRoot, "interrupts",
            { point = "CENTER", x = 0, y = -160 }, {
                Caption("Shown per the visibility rules at the bottom"),
                Dropdown("Orientation", "horizontal", {
                    { text = "Horizontal", value = "horizontal" },
                    { text = "Vertical",   value = "vertical" },
                },
                    function() return S:Get("orientation") end,
                    function(v) S:Set("orientation", v) end),
                Dropdown("Grow direction", "down", {
                    { text = "Down",  value = "down" },
                    { text = "Up",    value = "up" },
                    { text = "Left",  value = "left" },
                    { text = "Right", value = "right" },
                },
                    function() return S:Get("growDirection") end,
                    function(v) S:Set("growDirection", v) end),
                TrackerSlider("Bar width",  "barWidth",  40, 600, 5, px),
                TrackerSlider("Bar height", "barHeight",  6,  80, 1, px),
                TrackerSlider("Icon size",  "iconSize",  12,  96, 1, px),
                TrackerSlider("Spacing",    "spacing",    0,  40, 1, px),
                TrackerSlider("Padding",    "framePadding", 0, 40, 1, px),
                TrackerCheckbox("Show background", "showBackdrop"),
                TrackerCheckbox("Class-colored border", "classBorder"),
                TrackerCheckbox("Show spell icon", "showSpellIcon"),
                TrackerCheckbox("Show player name", "showName"),
                TrackerCheckbox("Show timer", "showTimer"),
                { name = "Show the tracker when", kind = Kind("Divider") },
                TrackerCheckbox("Always", "visAlways"),
                TrackerCheckbox("In a group", "visGroup"),
                TrackerCheckbox("In dungeons and raids", "visInstance"),
                TrackerCheckbox("During an active keystone", "visMythicPlus"),
                TrackerCheckbox("In raid instances only", "visRaid"),
                TrackerCheckbox("In PvP and arenas", "visPvp"),
            }, "Interrupt Tracker")
    end

    -- Ready Check overview
    if ns.ReadyCheck and _G.YippYappReadyCheck and not done.readyCheck then
        done.readyCheck = true
        Register(_G.YippYappReadyCheck, "readyCheck",
            { point = "CENTER", x = 0, y = 0 }, {
                Caption("Shown when someone starts a ready check"),
                FrameScale("readyCheck", _G.YippYappReadyCheck),
                FrameAlpha("readyCheck", _G.YippYappReadyCheck),
            }, "Ready Check")
    end

    -- Mythic+ completion popup
    if ns.SetCompletionPopupLocked and _G.YippYappMPlusCompletion and not done.mplusCompletion then
        done.mplusCompletion = true
        Register(_G.YippYappMPlusCompletion, "mplusCompletion",
            { point = "CENTER", x = 0, y = 120 }, {
                Caption("Shown after you finish a keystone"),
                FrameScale("mplusCompletion", _G.YippYappMPlusCompletion),
                FrameAlpha("mplusCompletion", _G.YippYappMPlusCompletion),
            }, "Mythic+ Completion")
    end

    -- Utility Advisor
    if ns.UtilityAdvisor and _G.YippYappUtilityAdvisor and not done.utilityAdvisor then
        done.utilityAdvisor = true
        Register(_G.YippYappUtilityAdvisor, "utilityAdvisor",
            { point = "CENTER", x = 0, y = 0 }, {
                Caption("Shown when you enter a Mythic+ dungeon"),
                Dropdown("Display", "full", {
                    { text = "Full notes",     value = "full" },
                    { text = "Abilities only", value = "compact" },
                },
                    function()
                        local UA = ns.UtilityAdvisor
                        return (UA and UA:IsCompact()) and "compact" or "full"
                    end,
                    function(v)
                        local UA = ns.UtilityAdvisor
                        if UA and UA.SetCompact then UA:SetCompact(v == "compact") end
                    end),
                {
                    name = "Icon size", kind = Kind("Slider"), default = 48,
                    minValue = 24, maxValue = 64, valueStep = 4,
                    formatter = function(v) return ("%dpx"):format(math.floor(v)) end,
                    get = function()
                        local UA = ns.UtilityAdvisor
                        return (UA and UA.GetIconSize and UA:GetIconSize()) or 48
                    end,
                    set = function(_, value)
                        local UA = ns.UtilityAdvisor
                        if UA and UA.SetIconSize then UA:SetIconSize(value) end
                        RepairAfterChange()
                    end,
                },
                FrameScale("utilityAdvisor", _G.YippYappUtilityAdvisor),
                FrameAlpha("utilityAdvisor", _G.YippYappUtilityAdvisor),
            }, "Utility Advisor")
    end
end

------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------

-- Several frames are built on demand, so registration waits until they
-- exist. Entering Edit Mode is the moment they all have to be real.
--- Prints registration state for each movable frame. Used by /yh editdebug
--- because "no outline" has several possible causes -- frame missing,
--- registration skipped, or the selection being covered -- and they are
--- indistinguishable from a screenshot.
function ns.EditModeDebug()
    print("|cff00ff00YippYapp Edit Mode:|r")
    for _, def in ipairs(ns.EditMode:Frames()) do
        local f = def.frame and def.frame()
        local sel = f and LEM.frameSelections and LEM.frameSelections[f]
        print(("  %-16s want=%s shown=%s sel=%s selShown=%s mouse=%s size=%dx%d strata=%s/%s"):format(
            def.key,
            (ns.EditMode.IsShownForEditing and ns.EditMode:IsShownForEditing(def.key)) and "y" or "N",
            (f and f:IsShown()) and "y" or "n",
            sel and "y" or "N",
            (sel and sel:IsShown()) and "y" or "N",
            (sel and sel:IsMouseEnabled()) and "y" or "N",
            sel and math.floor(sel:GetWidth() or 0) or 0,
            sel and math.floor(sel:GetHeight() or 0) or 0,
            f and f:GetFrameStrata() or "-",
            sel and sel:GetFrameStrata() or "-"))
    end
end

--- Registers any frame that now exists. Safe to call repeatedly: each
--- frame registers once, tracked in `done`.
local function EnsureRegistered()
    local ok, err = pcall(RegisterAll)
    if not ok then
        print("|cffff5555YippYapp:|r Edit Mode registration failed: " .. tostring(err))
    end
end

--- Builds every frame, registers it, then puts it away again.
---
--- This has to happen before the player ever enters Edit Mode. AddFrame
--- creates its selection frame hidden and relies on the enter transition
--- to reveal it, so a frame registered *during* Edit Mode gets no
--- selection box until the next entry. Most of our frames are built the
--- first time they are shown, so without forcing them into existence here
--- they simply are not registered yet -- which is exactly why the battle
--- res timer had no outline.
---
--- Show and hide happen in the same execution, so nothing is drawn.
local function InstantiateAndRegister()
    if ns.EditMode then
        ns.EditMode:ShowAllForEditing()
        EnsureRegistered()
        ns.EditMode:RestoreAfterEditing()
    else
        EnsureRegistered()
    end
end

--- LibEditMode reveals selections during its own enter transition, but
--- only for frames that are visible at that instant. Ours are hidden then
--- -- they are encounter windows that we conjure a moment later -- so
--- their selections stay dormant and the frame looks selectable but is
--- not. Re-assert once our frames are actually up.
---
--- The interrupt tracker never had this problem because it is persistent,
--- which is why it alone worked.
--- Show or hide one frame's selection overlay without touching the frame,
--- for frames that are legitimately visible on their own.
function ns.EditModeLib.SetSelectionShown(frame, on)
    if not frame or not LEM.frameSelections then return end
    local sel = LEM.frameSelections[frame]
    if not sel then return end
    if on then
        if sel.ShowHighlighted then sel:ShowHighlighted() else sel:Show() end
    else
        sel:Hide()
    end
end

function ns.EditModeLib.Reveal()
    if not LEM.frameSelections then return end
    for frame, selection in next, LEM.frameSelections do
        if frame:IsShown() and selection.ShowHighlighted then
            selection:ShowHighlighted()
        end
    end
end

local function RevealSelections()
    if not LEM.frameSelections then return end
    for frame, selection in next, LEM.frameSelections do
        if frame:IsShown() and selection.ShowHighlighted then
            selection:ShowHighlighted()
        end
    end
end

LEM:RegisterCallback("enter", function()
    -- Frames must be visible for their selections to be usable. Anything
    -- created since login also gets picked up here.
    if ns.EditMode and ns.EditMode.ShowAllForEditing then
        ns.EditMode:ShowAllForEditing()
    end
    EnsureRegistered()
    -- Next frame: the shows above have to land first.
    C_Timer.After(0, RevealSelections)
end)

LEM:RegisterCallback("exit", function()
    if ns.EditMode and ns.EditMode.RestoreAfterEditing then
        ns.EditMode:RestoreAfterEditing()
    end
end)

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    -- Slight delay: the modules that own these frames finish their own
    -- login setup first, so their globals exist by the time we build them.
    C_Timer.After(1, InstantiateAndRegister)
end)
