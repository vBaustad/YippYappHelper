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

--- Raises a frame's selection overlay above the frame's own children.
---
--- LibEditMode parents the selection to the frame at the default level,
--- but our windows put clickable content on top: the completion popup
--- fills its body with action buttons and draws overlays at level +10.
--- Those swallow the click before the selection ever sees it, so the
--- frame looks selectable but cannot be picked up.
---
--- Strata has to be matched too, and matched *again* whenever it
--- changes. Strata outranks frame level, so a frame that raises itself
--- above its own selection child takes every click -- and the shared
--- situation window changes strata with whatever it is showing, which is
--- why this is a function rather than four lines inside Register.
function ns.EditModeLib.SyncSelection(frame)
    if not frame or not LEM.frameSelections then return end
    local selection = LEM.frameSelections[frame]
    if not selection then return end
    selection:SetFrameStrata(frame:GetFrameStrata())
    selection:SetFrameLevel(frame:GetFrameLevel() + 20)
    selection:EnableMouse(true)
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

    ns.EditModeLib.SyncSelection(frame)

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

------------------------------------------------------------
-- Registration
------------------------------------------------------------

local done = {}

--- Registers the frames in ns.EditMode:Frames() that now exist.
---
--- Nothing to do while that list is empty, which it is since the Battle
--- Res Timer was retired -- it was the only frame Edit Mode placed. The
--- helpers above (Register, Caption, Checkbox, Slider) are what a new
--- entry would be written with, so they stay; `done` keys off the frame
--- so re-registration is still impossible once one comes back.
local function RegisterAll()
    for _, def in ipairs(ns.EditMode and ns.EditMode:Frames() or {}) do
        local f = def.frame and def.frame()
        if f and not done[def.key] then
            done[def.key] = true
            Register(f, def.key, def.default or { point = "CENTER", x = 0, y = 0 },
                     def.settings or {}, def.label or def.key)
        end
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
        print(("  %-16s shown=%s sel=%s selShown=%s mouse=%s size=%dx%d strata=%s/%s"):format(
            def.key,
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
--- A persistent frame never had this problem, which is how the cause was
--- found: the one frame that was always up was the one that worked.
local function RevealSelections()
    if not LEM.frameSelections then return end
    -- Walks OUR frames, not the library's whole table.
    --
    -- LEM.frameSelections lives on the shared LibStub library object, so
    -- it holds every frame every addon in the session registered. The
    -- previous version iterated all of them and called ShowHighlighted --
    -- a Blizzard mixin method on an EditModeSystemSelectionTemplate --
    -- on frames belonging to addons that had not asked for anything. That
    -- reaches into another addon's Edit Mode state from our call stack,
    -- and hands them our taint along with it.
    --
    -- `managed` is populated by Register, so it is exactly our own set.
    for _, entry in ipairs(managed) do
        local selection = LEM.frameSelections[entry.frame]
        if selection and entry.frame:IsShown() and selection.ShowHighlighted then
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
