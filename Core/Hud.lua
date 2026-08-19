local _, ns = ...

------------------------------------------------------------
-- The windows that show up on their own.
--
-- Three of them: the ready-check overview, the dungeon utility notes,
-- and the after-key summary. They have nothing to do with each other
-- except the one thing that matters here -- none of them can be opened
-- on demand. They appear when the game says so, which makes them
-- awkward to position and awkward to look at on purpose.
--
-- So this is a registry, not a container. Each window keeps its own
-- frame, its own place on screen and its own saved position. What they
-- share is the handling of those two awkward facts:
--
--   * you drag them wherever you like, whenever they are open, and
--     where you drop one is where it appears next time
--   * `/yh test <name>` conjures one with sample content, since none of
--     them can be summoned any other way
--
-- They used to be panels of one shared host that showed exactly one at a
-- time and arbitrated between them by priority. That bought a single
-- position for three windows of three different sizes, and a rule about
-- which one wins that only existed because they were fighting over one
-- spot. Given separate positions they never fight, so there is nothing
-- to arbitrate and nothing to restore afterwards.
--
-- Deliberately NOT Edit Mode. That ceremony -- enter a mode, dim the
-- world, find the frame, leave again -- is built for frames that are
-- always on screen. For a window you are already looking at, "drag it"
-- is the whole interaction, and it cannot suffer the failure the options
-- panel used to have, where you unlocked a frame you could not see.
------------------------------------------------------------

ns.Hud = ns.Hud or {}
local Hud = ns.Hud

local windows = {}   -- id -> entry
local order   = {}   -- registration order, for stable listing

------------------------------------------------------------
-- Saved positions
------------------------------------------------------------

local function DB()
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.windows = YippYappHelperDB.windows or {}
    return YippYappHelperDB.windows
end

--- Readers for each module's own pre-registry position key.
---
--- These are the positions people actually chose over the last few
--- seasons, in three different shapes because three modules invented
--- three schemas. Migrating beats dumping every window back at its
--- default the day somebody updates. The old keys are read, never
--- written and never deleted: they cost nothing, and a rollback should
--- not lose the position a second time.
local LEGACY = {
    readyCheck = function(d)
        if d.point then return d.point, d.relativePoint or d.point, d.x, d.y end
        if d.anchorLeft and d.anchorTop then
            return "TOPLEFT", "TOPLEFT", d.anchorLeft, d.anchorTop
        end
    end,
    mplusCompletion = function(d)
        local p = d.position
        if p and p.anchor then return p.anchor, p.relativePoint or p.anchor, p.x, p.y end
    end,
    utilityAdvisor = function(d)
        local p = d.position
        if p and p.anchor then return p.anchor, p.relativePoint or p.anchor, p.x, p.y end
    end,
}

local function savedPosition(e)
    local saved = DB()[e.id]
    if saved and saved.point then
        return saved.point, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0
    end

    local reader = LEGACY[e.id]
    local old = reader and YippYappHelperDB and YippYappHelperDB[e.id]
    if old then
        local point, rel, x, y = reader(old)
        if point then return point, rel or point, x or 0, y or 0 end
    end

    local d = e.default
    return d.point, d.relativePoint or d.point, d.x or 0, d.y or 0
end

--- Puts a window where it belongs. Safe to call whenever.
function Hud:ApplyPosition(id)
    local e = windows[id]
    if not e then return end
    local point, rel, x, y = savedPosition(e)
    e.frame:ClearAllPoints()
    e.frame:SetPoint(point, UIParent, rel, x, y)
end

local function remember(e)
    local point, _, rel, x, y = e.frame:GetPoint()
    if not point then return end
    DB()[e.id] = {
        point = point, relativePoint = rel,
        -- Rounded because a drag lands on fractions, and a saved
        -- position gets read back out of a bug report often enough that
        -- whole numbers are worth the two calls.
        x = math.floor(x + 0.5), y = math.floor(y + 0.5),
    }
end

------------------------------------------------------------
-- Registration
------------------------------------------------------------

--- Adopts a window.
---
--- `opts.default` is where it sits before anyone has moved it.
--- `opts.preview` fills it with sample content for `/yh test`.
--- `opts.hide` dismisses it, for the modules where hiding the frame is
--- not the whole job -- the ready check has a fade, a countdown and an
--- aura watcher to stop along with it.
function Hud:Register(id, frame, opts)
    if not frame or windows[id] then return end
    opts = opts or {}

    local e = {
        id      = id,
        frame   = frame,
        label   = opts.label or id,
        aliases = opts.aliases,
        preview = opts.preview,
        hide    = opts.hide,
        default = opts.default or { point = "CENTER", x = 0, y = 0 },
    }
    windows[id] = e
    table.insert(order, id)

    -- Movable for as long as it is open, with no lock and no mode to
    -- enter first. The contents already handle their own clicks --
    -- buttons, roster rows, keystone teleports -- and a drag that starts
    -- on one of those is consumed by it, so this only ever picks up
    -- drags that began on the window's own background.
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        remember(e)
    end)

    Hud:ApplyPosition(id)
end

------------------------------------------------------------
-- Looking them up, and looking at them
------------------------------------------------------------

--- Resolves a word typed at chat to one of the registered windows.
---
--- Matched against the id, the label and whatever aliases the window
--- registered, so `/yh test ready` and `/yh test readyCheck` are the
--- same command and neither has to be spelled the way the code does.
--- Windows carry their own names because the registry is the only place
--- that knows what exists -- a list kept in the slash handler would go
--- stale the first time a fourth window appeared.
function Hud:Find(word)
    if type(word) ~= "string" or word == "" then return nil end
    word = word:lower()
    for _, id in ipairs(order) do
        local e = windows[id]
        if id:lower() == word or (e.label or ""):lower() == word then return id end
        for _, alias in ipairs(e.aliases or {}) do
            if alias:lower() == word then return id end
        end
    end
    -- Explicit, not fallen off the end: no match is an answer callers
    -- print, and a function returning zero values is not the same thing
    -- as one returning nil the moment anybody wraps it in tostring.
    return nil
end

function Hud:Modes() return order, windows end
function Hud:Frame(id) return windows[id] and windows[id].frame end

function Hud:IsShown(id)
    local e = windows[id]
    return (e and e.frame:IsShown()) and true or false
end

--- Which windows are on screen.
---
--- A list rather than a single answer, because they are independent now:
--- a ready check called mid-keystone legitimately puts two of them up at
--- once, in two different places, and neither is wrong.
function Hud:Shown()
    local out = {}
    for _, id in ipairs(order) do
        if Hud:IsShown(id) then out[#out + 1] = id end
    end
    return out
end

--- Fills one window with sample content and shows it.
---
--- The only way to look at one on purpose: you cannot start a ready
--- check to see where it sits, and the after-key summary wants a
--- finished keystone. Each module supplies its own sample.
---
--- `arg` is whatever was typed after the window's name, handed straight
--- to the module. The registry has no idea what it means and should not:
--- the utility notes use it to step between dungeons, and the next
--- window to want an argument will mean something else entirely by it.
function Hud:PreviewMode(id, arg)
    local e = windows[id]
    if not e then return false end
    if e.preview then pcall(e.preview, arg) end
    return true
end

--- Dismisses one window.
---
--- Routed through the module's own hide where it has one, because
--- hiding the ready check is not merely hiding a frame: there is a fade
--- to stop, a countdown to cancel and an aura watcher to unregister.
function Hud:Dismiss(id)
    local e = windows[id]
    if not e then return end
    if e.hide then pcall(e.hide) else e.frame:Hide() end
end

function Hud:ReleaseAll()
    for _, id in ipairs(order) do Hud:Dismiss(id) end
end
