local _, ns = ...

------------------------------------------------------------
-- Settings, built from Blizzard's own Settings API.
--
-- Previously this was a hand-drawn canvas panel: custom checkboxes, a
-- custom tab column, custom buttons. It worked, but it looked nothing
-- like every other addon's options and it had to reimplement layout,
-- scrolling and hit areas by hand.
--
-- Registering real settings instead means Blizzard draws the controls,
-- so we inherit the current checkbox/slider/dropdown art, the two-column
-- label/control layout, the Defaults button, keyboard navigation, and
-- the options search index — and we stop owning any of it.
--
-- Values are stored exactly where they were before. Every entry is a
-- proxy setting over the existing getter/setter, so nothing about the
-- saved-variable layout changes and no migration is needed.
------------------------------------------------------------

local S = ns.InterruptsSettings

local registered = false

local function VarType(kind)
    -- Settings.VarType is the modern spelling; older builds used strings.
    if Settings and Settings.VarType then
        if kind == "boolean" then return Settings.VarType.Boolean end
        if kind == "number"  then return Settings.VarType.Number end
        return Settings.VarType.String
    end
    return kind
end

--- One checkbox backed by an arbitrary getter/setter.
local function AddCheckbox(category, key, name, tooltip, get, set)
    local setting = Settings.RegisterProxySetting(
        category, "YYH_" .. key, VarType("boolean"), name, false,
        function() return get() and true or false end,
        function(v) set(v and true or false) end)
    Settings.CreateCheckbox(category, setting, tooltip)
    return setting
end

--- Interrupt-tracker options all live in one table, so they share a path.
local function AddTrackerCheckbox(category, key, name, tooltip)
    return AddCheckbox(category, "trk_" .. key, name, tooltip,
        function() return S:Get(key) end,
        function(v) S:Set(key, v) end)
end

--- A module toggle (YippYappHelperDB.modules), defaulting to on.
local function AddModuleCheckbox(category, module, name, tooltip)
    return AddCheckbox(category, "mod_" .. module, name, tooltip,
        function() return ns.ModuleEnabled(module) end,
        function(v)
            ns.SetModuleEnabled(module, v)
            if ns.OnModuleToggled then ns.OnModuleToggled(module, v) end
        end)
end

local function AddHeader(layout, text)
    if not CreateSettingsListSectionHeaderInitializer then return end
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
end

--- Action buttons (Preview, Unlock, ...) have no stored value, so they are
--- initializers rather than settings.
local function AddButton(layout, name, buttonText, tooltip, onClick)
    if not CreateSettingsButtonInitializer then return end
    layout:AddInitializer(
        CreateSettingsButtonInitializer(name, buttonText, onClick, tooltip, true))
end

------------------------------------------------------------
-- Category tree
------------------------------------------------------------

------------------------------------------------------------
-- The settings page
--
-- One page, not four. Once appearance and position moved to Edit Mode,
-- what was left was a dozen on/off switches -- spreading those across
-- subcategories meant three clicks to find a checkbox and no page that
-- showed you what the addon actually does.
------------------------------------------------------------

local function BuildAll(category, layout)
    AddHeader(layout, "Features")
    AddCheckbox(category, "brEnabled", "Battle Res Timer",
        "Tracks battle resurrection charges and the timer until the next "
        .. "one, in raids and keystone dungeons.",
        function() local BR = ns.BattleResTimer; return BR and BR:IsEnabled() end,
        function(v) local BR = ns.BattleResTimer; if BR then BR:SetEnabled(v) end end)

    AddCheckbox(category, "readyCheck", "Ready Check overview",
        "Replaces the default ready-check prompt with a roster overview "
        .. "showing food, flasks and readiness at a glance.",
        function() return ns.ReadyCheck and ns.ReadyCheck.IsEnabled and ns.ReadyCheck.IsEnabled() end,
        function(v)
            if ns.ReadyCheck and ns.ReadyCheck.SetEnabled then ns.ReadyCheck.SetEnabled(v) end
        end)

    AddTrackerCheckbox(category, "enabled", "Interrupt Tracker",
        "Tracks party and raid interrupt cooldowns in a movable frame.")

    -- The trigger lives in the tooltip, not the label: this column is
    -- narrow enough that any suffix is truncated mid-word, which reads
    -- worse than no hint at all. The Edit Mode dialogs carry the trigger
    -- as visible text, where there is room for it.
    AddModuleCheckbox(category, "mplusCompletion", "Mythic+ summary",
        "Shows a summary when a keystone run finishes, with timer, upgrade "
        .. "level, and party breakdown.")

    AddModuleCheckbox(category, "utilityAdvisor", "Utility advisor",
        "Surfaces a per-spec utility checklist (defensives, dispels, CC) "
        .. "when you enter a Mythic+ dungeon.")

    AddCheckbox(category, "trinketTooltips", "Trinket sim rankings",
        "Adds simulated DPS rankings from bloodmallet to trinket tooltips.",
        function()
            YippYappHelperDB = YippYappHelperDB or {}
            return YippYappHelperDB.trinketTooltips ~= false
        end,
        function(v)
            YippYappHelperDB = YippYappHelperDB or {}
            YippYappHelperDB.trinketTooltips = v and true or false
        end)

    AddCheckbox(category, "minimapIcon", "Minimap button",
        "Show the YippYapp Helper button next to your minimap.",
        function()
            YippYappHelperDB = YippYappHelperDB or {}
            YippYappHelperDB.libDBIcon = YippYappHelperDB.libDBIcon or {}
            return not YippYappHelperDB.libDBIcon.hide
        end,
        function(v)
            YippYappHelperDB = YippYappHelperDB or {}
            YippYappHelperDB.libDBIcon = YippYappHelperDB.libDBIcon or {}
            YippYappHelperDB.libDBIcon.hide = not v
            local DBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
            if DBIcon then
                if v then DBIcon:Show("YippYappHelper") else DBIcon:Hide("YippYappHelper") end
            end
        end)

    AddHeader(layout, "Battle Res Timer")
    AddCheckbox(category, "brOOC", "Show between pulls",
        "Keep the timer visible between pulls instead of only during combat. "
        .. "Applies inside raids and keystone dungeons only -- there is no "
        .. "battle res pool in the open world, so the timer never shows there.",
        function() local BR = ns.BattleResTimer; return BR and BR:IsShowOutOfCombat() end,
        function(v) local BR = ns.BattleResTimer; if BR then BR:SetShowOutOfCombat(v) end end)

    AddHeader(layout, "Show the Interrupt Tracker when")
    AddTrackerCheckbox(category, "visAlways", "Always",
        "Overrides the rest -- the tracker stays up regardless of context.")
    AddTrackerCheckbox(category, "visGroup", "In a group", nil)
    AddTrackerCheckbox(category, "visInstance", "In dungeons and raids", nil)
    AddTrackerCheckbox(category, "visMythicPlus", "During an active keystone", nil)
    AddTrackerCheckbox(category, "visRaid", "In raid instances only", nil)
    AddTrackerCheckbox(category, "visPvp", "In PvP and arenas", nil)

    AddHeader(layout, "Appearance and position")
    AddButton(layout, "All YippYapp frames", "Open Edit Mode",
        "Size, opacity, layout, compact mode and where each frame sits all "
        .. "live in Edit Mode, where you can see the change as you make it.",
        function() if ns.EditMode then ns.EditMode:Open() end end)
end
-- Registration
------------------------------------------------------------

local rootCategory

local function Register()
    if registered then return rootCategory end
    if not (Settings and Settings.RegisterVerticalLayoutCategory
            and Settings.RegisterProxySetting and Settings.RegisterAddOnCategory) then
        return nil
    end

    local category, layout = Settings.RegisterVerticalLayoutCategory("YippYapp Helper")
    if not category then return nil end
    -- Do NOT assign category.ID. The Settings API fills it with the
    -- numeric id that OpenToCategory expects; the old canvas panel set a
    -- string here, which clobbered it and made OpenToCategory fail
    -- silently -- the addon window closed and nothing opened.

    BuildAll(category, layout)
    Settings.RegisterAddOnCategory(category)

    rootCategory = category
    registered = true
    return category
end

--- Opens Options -> AddOns -> YippYapp Helper.
function ns.OpenBlizzardSettings()
    local category = Register()
    if not (category and Settings.OpenToCategory) then
        print("|cffff5555YippYapp:|r could not open the settings panel")
        return false
    end
    -- Prefer the object's own id; fall back to the display name, which
    -- OpenToCategory also accepts, so a future API change cannot leave
    -- the button silently doing nothing again.
    local id = category.GetID and category:GetID() or nil
    local ok = false
    if id then ok = pcall(Settings.OpenToCategory, id) end
    if not ok then ok = pcall(Settings.OpenToCategory, "YippYapp Helper") end
    if not ok then
        print("|cffff5555YippYapp:|r could not open the settings panel")
    end
    return ok
end

-- Register at login so the category exists in the options list (and in
-- the options search) without the player opening it first.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    -- Guarded: a failure here must not take the rest of the addon with it.
    local ok, err = pcall(Register)
    if not ok then
        print("|cffff5555YippYapp:|r settings registration failed: " .. tostring(err))
    end
end)
