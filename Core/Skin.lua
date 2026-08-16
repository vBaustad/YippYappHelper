local _, ns = ...

------------------------------------------------------------
-- Skins.
--
-- A skin decides what things look like. It never decides where they go.
--
-- That line is the whole design. Regions, sizes and layout live in
-- Core/Shell.lua and are identical under every skin; a provider supplies
-- backdrops, borders and colours for a small vocabulary of roles. Break
-- the line and you do not have two skins, you have two layouts to
-- maintain, and every page change has to be made twice.
--
-- Two providers to start:
--
--   "default"   what the addon looks like today. It stays because
--               people running ElvUI, Ellesmere and similar want the
--               addon to sit quietly inside their UI rather than
--               reintroduce Blizzard's frame art in the middle of it.
--   "blizzlike" Blizzard's own panel styling, for people running the
--               default UI who want it to look like part of the game.
--
-- Neither is "the" skin. Shipping only the Blizzlike one would be a
-- regression for every user in the first group.
--
-- Applies to the app frame only. The in-combat frames -- interrupt
-- tracker, battle res timer, and the group frame -- are deliberately
-- outside this: they sit over your gameplay rather than being read
-- deliberately, and dressing them in panel art makes them worse. They
-- stay minimal under every skin.
------------------------------------------------------------

ns.Skin = ns.Skin or {}
local Skin = ns.Skin

local providers, activeID = {}, nil

------------------------------------------------------------
-- Roles
--
-- The vocabulary a page may ask for. Deliberately short: every role is
-- one a provider has to implement and a page has to choose between, so
-- an unbounded list makes both jobs worse.
------------------------------------------------------------
Skin.ROLES = {
    window = true,   -- the outer frame
    panel  = true,   -- a region: nav, rail, content
    inset  = true,   -- a block inside a panel: a card, a group
    row    = true,   -- a list row
    header = true,   -- a strip above content
}

--- Register a provider.
---
--- provider = {
---   displayName   shown in settings
---   description   one line, shown under it
---   beta          optional, badges it in the picker
---   IsCompatible  optional, return false to hide it (a skin that
---                 needs a texture pack that is not installed)
---   Panel(parent, role)  return a styled frame for that role
---   Color(key)    optional named colours: "accent", "muted", "danger"
--- }
function Skin:Register(id, provider)
    if type(id) ~= "string" or id == "" or type(provider) ~= "table" then
        return false
    end
    if providers[id] and providers[id] ~= provider then
        error("Duplicate YippYapp skin: " .. id)
    end
    provider.id = id
    providers[id] = provider
    return true
end

--- Every provider that could be selected, sorted for display.
---
--- Incompatible ones are returned too, flagged rather than hidden: a
--- skin silently missing from the list looks like a bug, whereas one
--- greyed out with a reason explains itself.
function Skin:GetProviders()
    local out = {}
    for id, p in pairs(providers) do
        local compatible = true
        if type(p.IsCompatible) == "function" then
            local ok, result = pcall(p.IsCompatible, p)
            compatible = (not ok) or (result ~= false)
        end
        out[#out + 1] = {
            id = id,
            provider = p,
            name = p.displayName or id,
            description = p.description or "",
            beta = p.beta == true,
            compatible = compatible,
        }
    end
    table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
    return out
end

--- The active provider, always non-nil once anything is registered.
---
--- Falls back to "default" rather than to nothing: a saved skin id can
--- outlive the thing that provided it -- a companion addon disabled,
--- say -- and the page still has to render.
function Skin:Active()
    local id = activeID
    if id and providers[id] then return providers[id] end
    return providers["default"]
end

function Skin:ActiveID()
    return (activeID and providers[activeID]) and activeID or "default"
end

function Skin:SetActive(id)
    if not providers[id] then return false end
    activeID = id
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.skin = id
    if ns.Shell and ns.Shell.Rebuild then ns.Shell:Rebuild() end
    return true
end

-- What an untouched install gets. Blizzlike while the new shell is being
-- tested, because the point of testing it is to look at it -- the
-- addon's own dark panels remain the eventual default for anyone running
-- a replacement UI, and are one `/yh skin default` away.
Skin.TESTING_DEFAULT = "blizzlike"

function Skin:Restore()
    YippYappHelperDB = YippYappHelperDB or {}
    local saved = YippYappHelperDB.skin
    if saved and providers[saved] then
        activeID = saved
    elseif providers[self.TESTING_DEFAULT] then
        activeID = self.TESTING_DEFAULT
    end
end

------------------------------------------------------------
-- The default provider: what the addon looks like today.
--
-- Lifted from the values already in use across AppFrame and the feature
-- pages rather than reinvented, so selecting it is genuinely a no-op
-- for anyone who liked the addon before this existed.
------------------------------------------------------------
local Default = {
    displayName = "YippYapp",
    description = "The addon's own dark panels. Sits quietly inside ElvUI and similar.",
}

local DEFAULT_FILL = {
    window = { 0.04, 0.04, 0.04, 0.95 },
    panel  = { 0.06, 0.06, 0.06, 0.97 },
    inset  = { 0.08, 0.08, 0.08, 0.80 },
    row    = { 0.10, 0.10, 0.10, 0.55 },
    header = { 0.06, 0.06, 0.06, 0.90 },
}

-- Grey, and one place to say so. Apply and Surface both need the edge
-- colour, and two literals is how the square border and the rounded one
-- end up different shades of grey without anyone meaning them to be.
local DEFAULT_EDGE     = { 0.35, 0.35, 0.35, 1 }
-- Rows are separated by tone rather than by lines, so theirs is barely
-- there. Kept as a border rather than dropped so a row still has an
-- edge to round.
local DEFAULT_ROW_EDGE = { 0.35, 0.35, 0.35, 0.25 }

-- Depth, but less of it than the Blizzlike skin takes. This skin's job
-- is to sit quietly inside somebody else's UI, and a heavily shaded
-- panel stops matching the flat ones around it. The colours stay
-- neutral grey for the same reason -- warming them would look like WoW
-- and wrong inside ElvUI, which is the one thing this skin exists to
-- avoid.
local DEFAULT_SHADOW = {
    panel = { inset = 2, thickness = 6, alpha = 0.28 },
    inset = { inset = 1, thickness = 4, alpha = 0.22 },
}

--- Dress a frame that already exists.
---
--- Split out from Panel so the nine feature pages can be migrated
--- without being rewritten. Between them they call SetBackdrop about 180
--- times on frames they build themselves for their own reasons; asking
--- each one to instead create its frames through the skin would mean
--- restructuring every file. Restyling in place is a one-line change at
--- each site and gets the same result.
--- The flat colours behind a role: fill, then edge.
---
--- Exists so ns.Widgets can paint this same surface in a different
--- shape -- a rounded card -- without copying the values out of here.
--- The skin keeps saying what a surface is coloured; the widget only
--- decides what shape it is cut to.
function Default:Surface(role)
    return DEFAULT_FILL[role] or DEFAULT_FILL.panel,
           role == "row" and DEFAULT_ROW_EDGE or DEFAULT_EDGE
end

function Default:Apply(f, role)
    local fill, edge = self:Surface(role)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        f:SetBackdropColor(fill[1], fill[2], fill[3], fill[4])
        f:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4])
    elseif f.CreateTexture then
        -- No BackdropTemplate on this frame. A plain texture is not a
        -- border, but it is a surface, and a page that renders flat is
        -- better than one that errors.
        local bg = f._yyhFill or f:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetAllPoints(f)
        bg:SetColorTexture(fill[1], fill[2], fill[3], fill[4])
        -- Shown explicitly: W:Unskin hides this to take a page flush
        -- into the shell, and re-skinning has to bring it back.
        bg:Show()
        f._yyhFill = bg
    end

    local shadow = DEFAULT_SHADOW[role]
    if shadow and ns.Widgets then
        ns.Widgets:InnerShadow(f, shadow.inset, shadow.thickness, shadow.alpha)
    end
    return f
end

function Default:Panel(parent, role)
    return self:Apply(CreateFrame("Frame", nil, parent, "BackdropTemplate"), role)
end

Skin:Register("default", Default)
