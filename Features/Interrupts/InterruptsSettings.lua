local _, ns = ...

------------------------------------------------------------
-- Interrupts Settings: persistent config + movable in-addon
-- settings window (the Blizzard panel isn't draggable, so
-- everything lives inside the addon itself).
------------------------------------------------------------

ns.InterruptsSettings = ns.InterruptsSettings or {}
local S = ns.InterruptsSettings

------------------------------------------------------------
-- Textures (built-in + common Blizzard assets, no SharedMedia)
------------------------------------------------------------

S.BAR_TEXTURES = {
    { key = "blizzard",   label = "Blizzard",    path = "Interface\\TargetingFrame\\UI-StatusBar" },
    { key = "raid",       label = "Raid Bar",    path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { key = "flat",       label = "Flat",        path = "Interface\\Buttons\\WHITE8x8" },
    { key = "glaze",      label = "Glaze",       path = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
    { key = "minimalist", label = "Minimalist",  path = "Interface\\TargetingFrame\\UI-StatusBar" },
}

function S:GetBarTexturePath(key)
    for _, t in ipairs(self.BAR_TEXTURES) do
        if t.key == key then return t.path end
    end
    return self.BAR_TEXTURES[1].path
end

------------------------------------------------------------
-- Defaults
------------------------------------------------------------

local DEFAULTS = {
    enabled         = true,
    mode            = "bar",
    barWidth        = 180,
    barHeight       = 22,
    barTexture      = "blizzard",
    iconSize        = 36,
    spacing         = 4,
    orientation     = "horizontal",
    growDirection   = "down",
    barStyle        = "classFill",
    classBorder     = false,
    showSpellIcon   = true,
    showName        = true,
    showTimer       = true,
    countDirection  = "down",
    posX            = 0,
    posY            = -160,
    anchor          = "CENTER",
    locked          = false,
    -- Legacy single-string field (kept for compatibility); new code uses
    -- the per-context flags below.
    visibility      = "group",
    visGroup        = true,
    visInstance     = false,
    visMythicPlus   = false,
    visRaid         = false,
    visPvp          = false,
    visAlways       = false,
    testMode        = false,
    showBackdrop    = true,
    backdropAlpha   = 0.85,
    framePadding    = 6,
}

local listeners = {}

-- Numeric fields are clamped to sane ranges so a corrupted SavedVariable
-- (stale schema, another addon stepping on YippYappHelperDB, hand-edit)
-- can't produce a 0-width bar or a million-pixel offset.
local NUMERIC_RANGES = {
    barWidth      = { min = 40,     max = 600  },
    barHeight     = { min = 6,      max = 80   },
    iconSize      = { min = 12,     max = 96   },
    spacing       = { min = 0,      max = 40   },
    posX          = { min = -8000,  max = 8000 },
    posY          = { min = -8000,  max = 8000 },
    backdropAlpha = { min = 0,      max = 1    },
    framePadding  = { min = 0,      max = 40   },
}

local function validateAndClamp(d)
    for k, defaultV in pairs(DEFAULTS) do
        local cur = d[k]
        if cur == nil or type(cur) ~= type(defaultV) then
            d[k] = defaultV
        elseif type(defaultV) == "number" then
            local r = NUMERIC_RANGES[k]
            if r then
                if cur < r.min then d[k] = r.min
                elseif cur > r.max then d[k] = r.max end
            end
        end
    end
end

-- Test mode is a transient Edit Mode state, not a preference. It is
-- driven only by entering and leaving Edit Mode, and the "what was it
-- before" value lives in memory -- so reloading while Edit Mode had it on
-- used to strand the tracker showing five dummy bars forever, with no
-- switch left to turn it off. Clear it once per session instead.
local testModeCleared = false

local function db()
    YippYappHelperDB = YippYappHelperDB or {}
    if not YippYappHelperDB.interrupts then
        YippYappHelperDB.interrupts = {}
    end
    local d = YippYappHelperDB.interrupts
    validateAndClamp(d)
    if not testModeCleared then
        testModeCleared = true
        d.testMode = false
    end
    return d
end

function S:Get(key)     return db()[key] end
function S:Set(key, v)
    db()[key] = v
    for _, cb in ipairs(listeners) do pcall(cb, key, v) end
end
function S:OnChanged(cb) table.insert(listeners, cb) end
function S:All()         return db() end
function S:Defaults()    return DEFAULTS end

------------------------------------------------------------
-- Visibility context
------------------------------------------------------------
function S:ShouldShow()
    local d = db()
    if not d.enabled then return false end
    if d.testMode then return true end

    if d.visAlways then return true end

    local inInstance, instanceType = IsInInstance()

    if d.visGroup and IsInGroup() then return true end
    if d.visInstance and inInstance and (instanceType == "party" or instanceType == "raid") then return true end
    if d.visRaid and inInstance and instanceType == "raid" then return true end
    if d.visPvp and inInstance and (instanceType == "pvp" or instanceType == "arena") then return true end
    if d.visMythicPlus and inInstance and instanceType == "party"
       and C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        local lvl = select(1, C_ChallengeMode.GetActiveKeystoneInfo())
        if lvl and lvl > 0 then return true end
    end
    return false
end

------------------------------------------------------------
-- Settings live in Core/BlizzSettings.lua, built on Blizzard's Settings
-- API so the controls are the game's own. This file is now only the
-- interrupt tracker's data model -- defaults, validation, Get/Set and
-- the visibility rules -- which those settings read through.
--
-- The hand-drawn settings window that used to live here (tab column,
-- custom checkboxes, sliders and dropdowns, ~1000 lines) was removed in
-- 3.0.0 once nothing referenced it.
------------------------------------------------------------
-- Settings now live in Core/BlizzSettings.lua, built on Blizzard's
-- Settings API so the controls are the game's own. This file keeps the
-- interrupt tracker's data model (S:Get/S:Set) that those settings read.
------------------------------------------------------------

--- Settings live in Blizzard's Options -> AddOns panel, and only there.
--- One home for them means no second copy to keep in sync, and it is where
--- players already look for addon options.
function S:Open()
    if ns.OpenBlizzardSettings and ns.OpenBlizzardSettings() then return true end
    -- Very old clients without the Settings API: nothing to fall back to.
    print("|cffff5555YippYapp:|r could not open the settings panel")
    return false
end
function S:Toggle() S:Open() end

SLASH_YYHINTERRUPTS1 = "/yyhinterrupts"
SlashCmdList.YYHINTERRUPTS = function() S:Toggle() end

SLASH_YYHSETTINGS1 = "/yyhopts"
SLASH_YYHSETTINGS2 = "/yyhsettings"
SlashCmdList.YYHSETTINGS = function() S:Toggle() end
ns.OpenSettings = function() S:Open() end
