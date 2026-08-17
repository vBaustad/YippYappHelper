local _, ns = ...

------------------------------------------------------------
-- The mechanics trainer.
--
-- A top-down arena you play with WASD and the mouse, so a player can
-- find out whether they actually understood the guide before thirty
-- other people find out for them.
--
-- The reference was a browser game that teaches a raid tier by letting
-- you fail its mechanics for free. That is the idea worth copying: the
-- thing being practised is not the boss, it is the REACTION -- see the
-- shape, know whether you belong inside it or outside it, get there in
-- time -- and doing that while you are also busy is the whole
-- difficulty. Hence a gun: standing still and reading the floor is easy,
-- and nobody does it on a real pull.
--
------------------------------------------------------------
-- THE KEYBOARD, and why it is safe here.
--
-- Capturing movement keys in WoW has one genuine hazard: a frame that
-- swallows keys the player needed. The idiom that avoids it is to
-- capture per-key rather than wholesale --
--
--   OnKeyDown: SetPropagateKeyboardInput(false) ONLY for our keys,
--              true for everything else.
--
-- so Escape still closes the window, chat still opens, and every
-- ability keybind still fires. We swallow exactly WASD and the arrows,
-- and only while a round is actually running.
--
-- SetPropagateKeyboardInput is also only ever called from inside a key
-- handler, never from an event or a timer. That is deliberate: the
-- combat pause below flips a flag, and the next keypress reads it. A
-- pause that reached out and changed keyboard state on its own would be
-- doing it at the least predictable moment in the game.
--
-- The key-up is swallowed if and only if the key-down was, tracked in
-- `held`. Swallowing one without the other is how a frame leaves the
-- client believing a key is still down.
------------------------------------------------------------
-- TWO OTHER DECISIONS WORTH STATING.
--
-- EVERY DAMAGE SOURCE IS AVOIDABLE. The real fights pulse raid-wide
-- damage you cannot dodge, and modelling that would drain the health bar
-- for reasons the player cannot act on. A score is only worth reading if
-- everything that took health off you was something you could have not
-- done. The single exception is KINDS.tax, which argues its own case.
--
-- IT PAUSES WHEN YOU ENTER COMBAT, and releases the keyboard when it
-- does. This opens over the app, and the app opens in a raid.
------------------------------------------------------------

ns.RaidTrainer = ns.RaidTrainer or {}
local T = ns.RaidTrainer

------------------------------------------------------------
-- Geometry
------------------------------------------------------------
local ARENA_R = 100

local PLAYER_SPEED = 46
local PLAYER_R     = 3.4
local ALLY_R       = 2.8
local MAX_HP       = 100

-- Shooting. Tuned against the add health in
-- Features\Raid\RaidTrainerScenarios.lua: a little under seven shots a
-- second at 12 a shot kills a 70-health add in about a second of held
-- fire, which is long enough that you have to commit to it and short
-- enough that you can still leave to dodge something.
local FIRE_COOLDOWN = 0.15
local SHOT_SPEED    = 170
local SHOT_DAMAGE   = 12
local SHOT_R        = 2.2
local SHOT_LIFE     = 1.5

local MEDIA = "Interface\\AddOns\\YippYappHelper\\Media\\"
local ART = {
    ship    = MEDIA .. "ShapeShip",
    dart    = MEDIA .. "ShapeDart",
    diamond = MEDIA .. "ShapeDiamond",
    hex     = MEDIA .. "ShapeHex",
    blob    = MEDIA .. "ShapeBlob",
    spike   = MEDIA .. "ShapeSpike",
    skull   = MEDIA .. "ShapeSkull",
    sword   = MEDIA .. "ShapeSword",
    bow     = MEDIA .. "ShapeBow",
    shield  = MEDIA .. "ShapeShield",
    cross   = MEDIA .. "ShapeCross",
    star    = MEDIA .. "ShapeStar",
    swirl   = MEDIA .. "ShapeSwirl",
    disc    = MEDIA .. "CircleMask",
    ring    = MEDIA .. "CircleRing",
}
local WHITE = "Interface\\Buttons\\WHITE8x8"

--- The one place the sprite alphabet's facing is corrected.
---
--- Tools/make_shapes.py authors every directional shape pointing along
--- +X so an aim angle can go straight into SetRotation. If the client's
--- rotation turns out to run the other way, or the art reads a quarter
--- turn off, this is the number to change -- not eight call sites.
local SPRITE_FACING = 0

local function dist(x1, y1, x2, y2)
    local dx, dy = x1 - x2, y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

--- The angle of a vector, on whichever Lua this is running under.
---
--- WoW ships 5.1, where math.atan2 exists and math.atan takes one
--- argument. Lua 5.3 deleted atan2 and made math.atan accept two. The
--- addon only has to satisfy 5.1 -- but Tools/loadcheck.py runs these
--- files under a newer interpreter, and a nil-call there would take the
--- whole trainer out of the one harness that checks it.
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local function randomPoint(inset)
    local r = (ARENA_R - (inset or 12)) * math.sqrt(math.random())
    local a = math.random() * math.pi * 2
    return math.cos(a) * r, math.sin(a) * r
end

local function edgePoint()
    local a = math.random() * math.pi * 2
    return math.cos(a) * ARENA_R, math.sin(a) * ARENA_R, a
end

local function clampToArena(x, y, pad)
    local d = math.sqrt(x * x + y * y)
    local limit = ARENA_R - (pad or 0)
    if d <= limit or d == 0 then return x, y end
    return x / d * limit, y / d * limit
end

--- How far a ray from (x, y) travels before it leaves the arena.
---
--- Exact, rather than "long enough": every frontal used to default to a
--- length of ARENA_R * 2, which is the arena's DIAMETER measured from
--- whatever point it started at. From the boss in the middle that is
--- twice as far as the wall, so the bars ran out past the floor and into
--- the corners of the frame -- a mechanic drawn across scenery it could
--- never reach. Solving the ray against the circle costs one square root
--- and cannot be wrong.
local function distanceToWall(x, y, dir)
    local ux, uy = math.cos(dir), math.sin(dir)
    local b = x * ux + y * uy
    local c = x * x + y * y - ARENA_R * ARENA_R
    local disc = b * b - c
    if disc <= 0 then return ARENA_R end
    return math.max(-b + math.sqrt(disc), 8)
end

--- How wide a cone is at `along` of `len`, as a fraction of its full
--- width. Frontals are cones, not planks: narrow at the caster, full
--- width at the far end.
local CONE_NOSE = 0.28
local function coneFrac(along, len)
    return CONE_NOSE + (1 - CONE_NOSE) * math.min(math.max(along / len, 0), 1)
end

--- Perpendicular distance from a point to an infinite line through
--- `ox, oy` in direction `dir`, plus how far along that line it sits.
local function alongAcross(px, py, ox, oy, dir)
    local dx, dy = px - ox, py - oy
    local c, s = math.cos(dir), math.sin(dir)
    return dx * c + dy * s, math.abs(-dx * s + dy * c)
end

------------------------------------------------------------
-- Colours
--
-- A vocabulary rather than decoration, and the vocabulary is the
-- teaching device: red means the shape will hurt you, green means the
-- shape is where you need to be. A player who learns only that has
-- learned most of what the trainer is for.
--
-- Shape carries the second half of it. Ground effects are discs because
-- in WoW they genuinely are; anything ALIVE gets a silhouette, so the
-- player, the boss and three kinds of add are never telling each other
-- apart by hue alone.
------------------------------------------------------------
local C = {
    bad    = { 0.95, 0.25, 0.20 },
    good   = { 0.30, 0.95, 0.45 },
    goo    = { 0.45, 0.85, 0.20 },
    beam   = { 1.00, 0.55, 0.15 },
    wave   = { 0.35, 0.80, 1.00 },
    add    = { 0.80, 0.35, 1.00 },
    orb    = { 1.00, 0.85, 0.25 },
    ally   = { 0.55, 0.62, 0.75 },
    shot   = { 1.00, 0.95, 0.60 },
    boss   = { 1.00, 0.45, 0.35 },
    well   = { 0.90, 0.30, 0.60 },
}

------------------------------------------------------------
-- Damage schools
--
-- The game's own colours, because they are a real teaching signal: a
-- player learns "green puddle" and "purple circle" long before they
-- learn an ability's name, and a trainer that painted every hazard the
-- same red would be throwing away the shorthand they will actually use
-- at the pull.
--
-- The trick is that this must NOT overwrite the other signal. Red means
-- get out and green means get in, and that is the whole teaching device
-- of the thing. So the two are split across the shape:
--
--   the RING says what to DO   -- red get out, green get in
--   the FILL says what it IS   -- fire, poison, shadow, blood
--
-- which is also how the game does it. A green soak circle full of fire
-- reads correctly as "stand in the fire", and neither half has to give
-- anything up.
--
-- Schools are tagged per mechanic in RaidTrainerScenarios.lua, from the
-- guide's own descriptions. A mechanic with no school falls back to the
-- semantic colour, so an untagged one is merely plain rather than wrong.
------------------------------------------------------------
local SCHOOL = {
    fire     = { 1.00, 0.48, 0.12 },
    frost    = { 0.45, 0.80, 1.00 },
    nature   = { 0.40, 0.90, 0.25 },
    shadow   = { 0.62, 0.35, 0.92 },
    arcane   = { 0.92, 0.48, 1.00 },
    holy     = { 1.00, 0.90, 0.55 },
    blood    = { 0.80, 0.12, 0.16 },
    physical = { 0.85, 0.72, 0.52 },
}

--- The colour a mechanic's fill should be, falling back to whatever the
--- caller was going to use anyway.
local function schoolOf(a, fallback)
    return (a.school and SCHOOL[a.school]) or fallback
end

------------------------------------------------------------
-- The window
------------------------------------------------------------
local ARENA_PX = 470
local HEADER_H = 74
local FOOTER_H = 78
-- From the shell, for the same reason as everywhere else: a page that
-- picks its own padding sits at a different left edge to its neighbours.
local PAD      = (ns.Shell and ns.Shell.PAD) or 14

local f = CreateFrame("Frame", "YippYappRaidTrainer", UIParent, "BackdropTemplate")
f:SetSize(ARENA_PX + PAD * 2, ARENA_PX + HEADER_H + FOOTER_H)
f:SetPoint("CENTER")
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:SetClampedToScreen(true)
f:SetFrameStrata("DIALOG")
f:Hide()
ns.RaidTrainerFrame = f
T.frame = f

if ns.Widgets then ns.Widgets:Apply(f, "panel") end
if ns.SmoothFrame then ns.SmoothFrame(f) end

-- An opaque plate under the skin's panel.
--
-- The skin's surfaces are semi-transparent by design, which is right for
-- a page sitting inside the app's own window and wrong for this: the
-- trainer floats over the guide it was launched from, so the guide's
-- body text was showing through the arena floor. Everything here is read
-- at a glance and under time pressure, and the one thing a game field
-- must not be is busy.
local plate = f:CreateTexture(nil, "BACKGROUND", nil, -8)
plate:SetAllPoints()
plate:SetColorTexture(0.04, 0.04, 0.05, 0.97)

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", PAD, -10)
if ns.ApplyTextShadow then ns.ApplyTextShadow(title) end

local diffBadge = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
diffBadge:SetPoint("LEFT", title, "RIGHT", 8, -1)
if ns.ApplyTextShadow then ns.ApplyTextShadow(diffBadge) end

local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
subtitle:SetTextColor(0.6, 0.6, 0.6)
subtitle:SetJustifyH("LEFT")

local function MakeBar(width, height, parent, r, g, b)
    local bar = CreateFrame("StatusBar", nil, parent or f)
    bar:SetSize(width, height)
    bar:SetStatusBarTexture(WHITE)
    bar:SetStatusBarColor(r, g, b)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(100)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.09, 0.09, 0.11, 0.95)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.text:SetPoint("CENTER")
    return bar
end

-- Your health, and the boss's. Two bars rather than a number each: what
-- either one is needed for mid-round is "how close is this to over",
-- which is a length.
local hp = MakeBar(150, 12, f, 0.3, 0.85, 0.35)
hp:SetPoint("TOPRIGHT", -PAD - 26, -16)

local bossBar = MakeBar(150, 10, f, C.boss[1], C.boss[2], C.boss[3])
bossBar:SetPoint("TOPRIGHT", hp, "BOTTOMRIGHT", 0, -5)

-- The encounter's own timer, when it has one. Yellow, and its own bar
-- rather than a number in the score line: it is a thing that fills while
-- you are busy elsewhere, and a number at the foot of the screen is
-- exactly where nobody looks while that is happening.
local energyBar = MakeBar(150, 10, f, 1.0, 0.80, 0.15)
energyBar:SetPoint("TOPRIGHT", bossBar, "BOTTOMRIGHT", 0, -5)
energyBar:Hide()

-- Bloodlust. A phase you are meant to empty every cooldown into is worth
-- saying out loud, and it blinks because that is what the real thing
-- does to a raid's UI.
local lustText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lustText:SetPoint("TOPRIGHT", energyBar, "BOTTOMRIGHT", 0, -6)
lustText:Hide()
if ns.ApplyTextShadow then ns.ApplyTextShadow(lustText) end

-- The arena.
local arena = CreateFrame("Frame", nil, f)
arena:SetSize(ARENA_PX, ARENA_PX)
arena:SetPoint("TOP", 0, -HEADER_H)
arena:SetClipsChildren(true)
arena:EnableMouse(true)

local floorTex = arena:CreateTexture(nil, "BACKGROUND")
floorTex:SetAllPoints()
floorTex:SetTexture(ART.disc)
floorTex:SetVertexColor(0.07, 0.07, 0.09, 1)

local floorRing = arena:CreateTexture(nil, "BACKGROUND", nil, 1)
floorRing:SetAllPoints()
floorRing:SetTexture(ART.ring)
floorRing:SetVertexColor(0.35, 0.35, 0.42, 0.9)

local hurt = arena:CreateTexture(nil, "OVERLAY", nil, 7)
hurt:SetAllPoints()
hurt:SetTexture(WHITE)
hurt:SetVertexColor(1, 0, 0, 0)

local callOut = arena:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
callOut:SetPoint("TOP", arena, "TOP", 0, -28)
if ns.ApplyTextShadow then ns.ApplyTextShadow(callOut) end

-- The countdown, high up rather than dead centre.
--
-- At the centre it sat squarely on top of the boss, which is the one
-- thing on the field you want to be reading in the second before the
-- pull -- where it is, which way the formation is facing, what has
-- already spawned. Its own line near the top keeps all of that visible.
local countText = arena:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
countText:SetPoint("TOP", arena, "TOP", 0, -40)
if ns.ApplyTextShadow then ns.ApplyTextShadow(countText) end

local bigText = arena:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
bigText:SetPoint("CENTER")
if ns.ApplyTextShadow then ns.ApplyTextShadow(bigText) end

-- Which phase you are in, under the countdown line. Announced on entry
-- and then left up: a player who tabs back in mid-round should not have
-- to infer the phase from what is on the floor.
local phaseText = arena:CreateFontString(nil, "OVERLAY", "GameFontNormal")
phaseText:SetPoint("TOP", arena, "TOP", 0, -10)
if ns.ApplyTextShadow then ns.ApplyTextShadow(phaseText) end

-- What the player is currently carrying, over their own head.
--
-- A split soak only works if you can see which side of it you are on,
-- and until now nothing on screen said so -- the mechanic resolved and
-- the consequence arrived fourteen seconds later with no thread between
-- them.
local debuffText = arena:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
if ns.ApplyTextShadow then ns.ApplyTextShadow(debuffText) end

local resultText = arena:CreateFontString(nil, "OVERLAY", "GameFontNormal")
resultText:SetPoint("TOP", bigText, "BOTTOM", 0, -8)
resultText:SetWidth(ARENA_PX - 80)
resultText:SetJustifyH("CENTER")

local scoreText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
scoreText:SetPoint("TOPLEFT", arena, "BOTTOMLEFT", 2, -8)
scoreText:SetJustifyH("LEFT")

local hintText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hintText:SetPoint("TOPLEFT", scoreText, "BOTTOMLEFT", 0, -5)
hintText:SetWidth(ARENA_PX - 160)
hintText:SetJustifyH("LEFT")
hintText:SetTextColor(0.5, 0.5, 0.5)
hintText:SetText("WASD or arrows to move.  Aim with the mouse, hold left-click to shoot.")

local function MakeButton(text, width)
    local b = CreateFrame("Button", nil, f, "BackdropTemplate")
    b:SetSize(width or 92, 22)
    if ns.Widgets then ns.Widgets:Apply(b, "row") end
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetAllPoints()
    b.text:SetText(text)
    if ns.AddGlowHighlight then ns.AddGlowHighlight(b, 0.10) end
    return b
end

local retryBtn = MakeButton("Try again")
retryBtn:SetPoint("BOTTOMRIGHT", -PAD, PAD)

------------------------------------------------------------
-- Difficulty
--
-- Two buttons showing both options, not one button showing the current
-- one.
--
-- A lone button labelled "Normal" is genuinely ambiguous: half of all
-- toggle buttons in software mean "you are here" and the other half mean
-- "click for this", and nothing on the control says which kind it is. It
-- is only unambiguous to the person who wrote it. With both choices on
-- screen and one of them lit, the question does not arise -- and it also
-- reveals that Heroic exists at all, which the toggle hid from anybody
-- who never clicked it.
------------------------------------------------------------
local heroicBtn = MakeButton("Heroic", 62)
heroicBtn:SetPoint("RIGHT", retryBtn, "LEFT", -10, 0)

local normalBtn = MakeButton("Normal", 62)
normalBtn:SetPoint("RIGHT", heroicBtn, "LEFT", -2, 0)

local HEROIC_COLOUR = { 1.00, 0.42, 0.35 }
local NORMAL_COLOUR = { 0.45, 0.85, 1.00 }

-- State
------------------------------------------------------------
local S = {
    running = false, paused = false,
    time = 0, hp = MAX_HP,
    px = 0, py = 0, aim = 0, moving = false, firing = false,
    fireCd = 0,
    actors = {}, shots = {}, allies = {},
    nextEvent = 1, passed = 0, failed = 0, stacks = 0,
    phaseIndex = 1, phaseTime = 0, phases = nil,
    energy = 0, carrying = nil,
    heroic = false, countdown = 0, flash = 0, callUntil = 0,
    scenario = nil, boss = nil, bossActor = nil,
    debuffs = {}, corpses = {},
}
T.state = S

local function scale()
    return (arena:GetWidth() or ARENA_PX) / (ARENA_R * 2)
end

local function StyleDifficulty()
    local on = { [normalBtn] = not S.heroic, [heroicBtn] = S.heroic }
    local col = { [normalBtn] = NORMAL_COLOUR, [heroicBtn] = HEROIC_COLOUR }
    for btn, active in pairs(on) do
        if ns.Widgets then ns.Widgets:Apply(btn, active and "inset" or "row") end
        if active then
            local c = col[btn]
            btn.text:SetTextColor(c[1], c[2], c[3])
        else
            -- Clearly dimmer than the active one rather than merely a
            -- different shade. Two similar-looking buttons is the same
            -- ambiguity again, wearing a costume.
            btn.text:SetTextColor(0.42, 0.42, 0.46)
        end
    end
end

------------------------------------------------------------

------------------------------------------------------------
-- Sprites
--
-- One pooled texture per visual element, keyed by the draw layer it
-- belongs on. Pooling across layers is what a single pool cannot do --
-- a texture's layer is fixed when it is created -- and the layering is
-- the thing that keeps ground effects underneath the things standing on
-- them.
------------------------------------------------------------
local pools = {}

local function acquire(layer, sub)
    local key = layer .. tostring(sub)
    pools[key] = pools[key] or {}
    local t = table.remove(pools[key])
    if not t then
        t = arena:CreateTexture(nil, layer, nil, sub)
        t._poolKey = key
    end
    t:SetRotation(0)
    t:Show()
    return t
end

local function recycle(t)
    if not t then return end
    t:Hide()
    local key = t._poolKey
    if key then pools[key][#pools[key] + 1] = t end
end

--- The i-th visual belonging to an actor, created on first use.
---
--- Indexed rather than acquired fresh each frame: Draw runs sixty times
--- a second, and a pool that handed out a new texture every call would
--- be a leak with extra steps.
local function V(a, i, layer, sub)
    a.vis = a.vis or {}
    a.visUsed = math.max(a.visUsed or 0, i)
    local t = a.vis[i]
    if not t then
        t = acquire(layer or "ARTWORK", sub or 0)
        a.vis[i] = t
    end
    -- Shown on every fetch, because HideSurplus below may have hidden
    -- this slot on an earlier frame and a reused sprite that stays
    -- hidden is the same bug in the opposite direction.
    t:Show()
    return t
end

--- Hide whatever an actor drew last frame and did not draw this one.
---
--- The count is not fixed per kind: a spread draws one ring per player
--- carrying it, and Imbibe one swirl per lit altar, so the number really
--- does change between frames. Without this the extras were simply left
--- on the floor -- lit, stale, and indistinguishable from live mechanics.
local function HideSurplus(a)
    if not a.vis then return end
    for j = (a.visUsed or 0) + 1, #a.vis do
        if a.vis[j] then a.vis[j]:Hide() end
    end
end

local function releaseVis(a)
    for _, t in ipairs(a.vis or {}) do recycle(t) end
    a.vis = nil
end

--- Place a sprite in arena coordinates.
local function put(tex, art, x, y, size, s, col, alpha, rotation)
    tex:SetTexture(ART[art] or art)
    tex:SetSize(size * s, size * s)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", arena, "CENTER", x * s, y * s)
    tex:SetVertexColor(col[1], col[2], col[3], alpha or 1)
    tex:SetRotation(rotation or 0)
    return tex
end

--- A rotated bar, for lines, beams and waves. Anchored by its midpoint
--- half its length along its own direction, which is where a rotated
--- texture's centre has to be for the near end to sit on the caster.
local function putBar(tex, ox, oy, dir, len, width, s, col, alpha)
    tex:SetTexture(WHITE)
    tex:SetSize(len * s, width * s)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", arena, "CENTER",
        (ox + math.cos(dir) * len / 2) * s,
        (oy + math.sin(dir) * len / 2) * s)
    tex:SetVertexColor(col[1], col[2], col[3], alpha or 1)
    tex:SetRotation(dir)
    return tex
end

------------------------------------------------------------
-- Persistent sprites: the player, the raid, the boss, the well
--
-- Not pooled. There is exactly one of each and they exist for the life
-- of the frame, so borrowing them from a pool would only add a way for
-- them to go missing.
------------------------------------------------------------
local playerTex = arena:CreateTexture(nil, "OVERLAY", nil, 6)
playerTex:SetTexture(ART.ship)

local playerRing = arena:CreateTexture(nil, "OVERLAY", nil, 5)
playerRing:SetTexture(ART.ring)

local wellTex = arena:CreateTexture(nil, "ARTWORK", nil, 1)
wellTex:SetTexture(ART.ring)

local allyTex = {}
for i = 1, 6 do
    allyTex[i] = arena:CreateTexture(nil, "OVERLAY", nil, 2)
    allyTex[i]:SetTexture(ART.hex)
    allyTex[i].label = arena:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
end

-- The boss token. Upright, never rotated: a spinning skull reads as a
-- loading spinner, and the health bar in the header already says
-- everything a ring around it would have hinted at.
local bossSkull = arena:CreateTexture(nil, "OVERLAY", nil, 4)
bossSkull:SetTexture(ART.skull)

-- Which way it is looking.
--
-- The facing decides where every frontal goes, and until now the only
-- way to know it was to watch where the last cone fired -- which is
-- after the fact, and on a boss that turns deliberately it is the one
-- piece of state worth reading ahead. The skull itself stays upright,
-- because a rotating skull reads as a loading spinner, so the arrow
-- carries the direction on its own.
local bossFace = arena:CreateTexture(nil, "OVERLAY", nil, 5)
bossFace:SetTexture(ART.dart)

-- A dim stub of the cone's axis, so the arrow reads as "it is looking
-- THAT way down the room" rather than as a decoration stuck to its chin.
local bossGaze = arena:CreateTexture(nil, "ARTWORK", nil, 3)
bossGaze:SetTexture(WHITE)

-- The ward it hides behind while a phase says it cannot be hurt.
local bossWard = arena:CreateTexture(nil, "ARTWORK", nil, 4)
bossWard:SetTexture(ART.swirl)
local bossWardRing = arena:CreateTexture(nil, "ARTWORK", nil, 5)
bossWardRing:SetTexture(ART.ring)

------------------------------------------------------------
-- Corpses
--
-- Restless Amani do not stay dead. Each one leaves a body where it fell,
-- and the Ritual of Awakening raises every corpse still lying there --
-- which is what Slithering Flames is FOR. Without them the Flames were
-- half a mechanic: a debuff you carried away from the raid for no
-- reason, arriving right after you had been told you played correctly,
-- so it read as a punishment for soaking.
--
-- Kept out of the actor list on purpose. Actors belong to a phase and
-- are cleared at its boundary; a corpse has to survive from the phase
-- that made it into the phase that burns it.
------------------------------------------------------------
local MAX_CORPSES = 14
local corpseTex = {}
for i = 1, MAX_CORPSES do
    corpseTex[i] = arena:CreateTexture(nil, "ARTWORK", nil, 5)
    corpseTex[i]:SetTexture(ART.skull)
end

local function AddCorpse(x, y)
    if #S.corpses >= MAX_CORPSES then return end
    S.corpses[#S.corpses + 1] = { x = x, y = y }
end

--- Burn every corpse within `r` of a point. Returns how many.
local function BurnCorpses(x, y, r)
    local n = 0
    for i = #S.corpses, 1, -1 do
        local c = S.corpses[i]
        if dist(x, y, c.x, c.y) <= r then
            table.remove(S.corpses, i)
            n = n + 1
        end
    end
    return n
end

local function DrawCorpses(s)
    for i = 1, MAX_CORPSES do
        local c = S.corpses[i]
        if c then
            -- Dim and small, so a floor of them reads as litter to clear
            -- rather than as a dozen more things to dodge.
            put(corpseTex[i], "skull", c.x, c.y, 11, s, { 0.55, 0.52, 0.60 }, 0.75)
        else
            corpseTex[i]:Hide()
        end
    end
end

------------------------------------------------------------
-- Forward declarations
--
-- Four of these now, and they all have the same cause: this file builds
-- the scoring and the raid AI before the actors and the phase machinery
-- they consult. Without a declaration up here the name inside those
-- functions resolves to a nil GLOBAL, and the failure surfaces much
-- later and somewhere unrelated -- which has cost real time twice.
--
-- Anything added below that reaches forward belongs in this list.
------------------------------------------------------------
local Spawn          -- built with the actors
local CurrentPhase   -- built with the phase machinery

------------------------------------------------------------
-- Scoring
------------------------------------------------------------
local function Hurt(amount, why)
    S.hp = math.max(0, S.hp - amount)
    S.flash = 0.45
    S.failed = S.failed + 1
    if why then
        callOut:SetTextColor(1, 0.35, 0.3)
        callOut:SetText("MISSED: " .. why)
        S.callUntil = S.time + 1.6
    end
end

local function Credit(why)
    S.passed = S.passed + 1
    if why then
        callOut:SetTextColor(0.4, 1, 0.5)
        callOut:SetText(why)
        S.callUntil = S.time + 0.9
    end
end

--- Debuffs the player is carrying, by name, with the time they lapse.
---
--- The trainer had no notion of state that OUTLIVES a mechanic, and that
--- is what a split soak is made of: soaking marks you, and being marked
--- is the reason to sit the next one out. Without somewhere to keep that
--- between two casts, "then switch" cannot be expressed at all.
local function HasDebuff(name)
    return (S.debuffs[name] or 0) > S.time
end

local function ApplyDebuff(name, dur)
    S.debuffs[name] = S.time + (dur or 12)
end

local function AddStack(n)
    local mech = S.scenario and S.scenario.stacks
    if not mech then return end
    S.stacks = math.max(0, S.stacks + (n or 1))
    if S.stacks >= (S.heroic and mech.heroicMax or mech.max) then
        S.hp = 0
        S.flash = 0.6
        callOut:SetTextColor(1, 0.3, 0.3)
        callOut:SetText("MISSED: " .. mech.name .. " hit maximum stacks")
        S.callUntil = S.time + 2
    end
end

--- The encounter timer some fights carry: a bar that fills and wipes the
--- raid at the top.
---
--- Separate from the round clock because it is a MECHANIC -- something
--- the player pushes back against by playing well. On Nek'zali its rate
--- is zero and it is fed entirely by adds reaching the well, so the bar
--- is a record of mistakes rather than a countdown.
local function TickEnergy(dt)
    local e = S.scenario and S.scenario.energy
    if not e then return end
    -- A phase can override the rate. Nek'zali's bar is fed purely by
    -- adds reaching the well for two phases and then starts climbing on
    -- its own in the last one, which is the whole reason that phase is
    -- a race rather than a repeat of the first.
    local phase = CurrentPhase()
    local rate = (phase and phase.energyRate) or e.rate or 0
    S.energy = math.min(e.max or 100, S.energy + rate * dt)
    if S.energy >= (e.max or 100) then
        S.hp = 0
        callOut:SetTextColor(1, 0.3, 0.3)
        callOut:SetText(e.name .. " reached full energy -- the raid wipes")
        S.callUntil = S.time + 2
    end
end


------------------------------------------------------------
-- The rest of the raid
--
-- These are not decoration. They hold a formation, they shoot what the
-- guide says to shoot, they get out of what is about to land, and they
-- take the soaks they are assigned rather than every soak on the floor.
--
-- Two things they deliberately do NOT do. They do not die -- health bars
-- on five allies would make every distance-to-raid mechanic quietly
-- change meaning as they dropped, so they flash and stop shooting for a
-- moment instead. And they do not follow the player: the TANK walks the
-- boss and the formation turns with it, because dragging melee off the
-- boss to chase somebody is the one thing that never happens on a pull.
------------------------------------------------------------
local ALLY_COUNT    = 6
local ALLY_SPEED    = 40
local ALLY_FIRE_CD  = 0.8
-- Deliberately small. The raid is pressure and company, not the thing
-- killing the boss -- anything generous here makes the player a
-- spectator at their own encounter.
local ALLY_DAMAGE   = 3
-- How far they stand off what they are shooting. Closer for an add than
-- for the boss, so a pack spawning visibly pulls the raid over to it.
local ALLY_STANDOFF = 44
local ALLY_ADD_STANDOFF = 24
-- How hard a hazard shoves an ally's intended heading around. Well above
-- 1, because avoiding the thing that is about to land always beats
-- getting to where they were going.
local DANGER_WEIGHT = 2.6
-- How close to the wall the raid is allowed to get.
--
-- Needed because DangerPush has no upper bound: an ally with a puddle
-- behind it keeps being shoved outward every frame, and with nothing to
-- stop it the raid ends up pressed against the rim -- the same
-- "everyone ran to the edge" picture, by a different route.
local ALLY_WALL_PAD = 24

-- How fast the tank can drag the boss, and how far from the middle it
-- can be taken. Slower than a player on purpose: repositioning a boss is
-- a commitment you make several seconds ahead of needing it.
local BOSS_MOVE_SPEED = 20
local BOSS_LEASH = 66
-- And how it turns when it is NOT being walked anywhere. Frontals are
-- aimed down the boss's facing, at the tank -- correct, and on a
-- stationary boss it made them nothing to do with the player, because
-- the safe side never moved. Real tanks reposition constantly.
local BOSS_TURN_RATE = 0.55
local BOSS_REAIM_EVERY = 9

--- Where each of the raid stands relative to the boss, and what it is.
---
--- Evenly spaced around a circle was wrong twice over: no raid stands
--- like that, and it threw away the one thing the layout could carry for
--- free. A real pull has a shape -- tank in front, melee piled in
--- behind, ranged and healer clumped off to one side -- and once the
--- formation looks like that, "the boss faces the tank" and "melee are
--- behind it" stop needing to be explained anywhere.
local TANK_ANGLE = math.pi / 2
local FORMATION = {
    { role = "TANK",   angle = TANK_ANGLE,          dist = 17 },
    { role = "MELEE",  angle = -math.pi / 2 - 0.45, dist = 15 },
    { role = "MELEE",  angle = -math.pi / 2 + 0.45, dist = 15 },
    { role = "RANGED", angle = 0.10,                dist = 44 },
    { role = "RANGED", angle = -0.06,               dist = 48 },
    { role = "HEALER", angle = 0.26,                dist = 48 },
}

-- What each role looks like, and what colour it is.
--
-- Double-coded on purpose: shape carries the role at any size, colour
-- carries it before the shape has resolved. Either alone fails at
-- fifteen pixels -- four silhouettes in one grey take a moment to tell
-- apart, and four colours with no shape is the row of dots this whole
-- set replaced.
local ROLE_ART = {
    TANK = "shield", HEALER = "cross", MELEE = "sword", RANGED = "bow",
}
local ROLE_TINT = {
    TANK   = { 0.44, 0.64, 0.94 },
    HEALER = { 0.38, 0.88, 0.52 },
    MELEE  = { 0.96, 0.74, 0.42 },
    RANGED = { 0.74, 0.68, 0.96 },
}

local function ResetAllies()
    wipe(S.allies)
    for i = 1, ALLY_COUNT do
        local spot = FORMATION[i] or FORMATION[#FORMATION]
        S.allies[i] = {
            role = spot.role,
            formAngle = spot.angle,
            formDist = spot.dist,
            -- A separate evenly-spaced angle, used only when they gather
            -- on an ADD. The formation angles are clustered by design and
            -- reusing them would pile the whole ranged camp into one spot.
            slot = (i / ALLY_COUNT) * math.pi * 2,
            -- Which soak group they belong to. The tank is left out: it
            -- has its own soaks and is never in the raid's rotation.
            soakGroup = ((i - 2) % 3) + 1,
            -- When this ally last soaked a marking soak. Same rule
            -- as the player's: singed people sit the next one out.
            soakedUntil = 0,
            x = math.cos(spot.angle) * spot.dist,
            y = math.sin(spot.angle) * spot.dist,
            aim = spot.angle + math.pi,
            fireCd = math.random() * ALLY_FIRE_CD,
            stagger = 0,
            label = nil, marked = false, hold = false,
        }
    end
end

local function AllyPos(a) return a.x, a.y end

local function NearestAllyDist()
    local best = 999
    for _, a in ipairs(S.allies) do
        local d = dist(S.px, S.py, a.x, a.y)
        if d < best then best = d end
    end
    return best
end

--- Where the raid actually is, averaged over where they actually stand.
---
--- Replaces a stored anchor point, which was fine while they orbited it
--- and became a lie the moment they started moving.
local function RaidCentre()
    local n, sx, sy = 0, 0, 0
    for _, a in ipairs(S.allies) do
        sx, sy, n = sx + a.x, sy + a.y, n + 1
    end
    if n == 0 then return 0, 0 end
    return sx / n, sy / n
end

--- A push away from everything dangerous near a point.
---
--- Returned as a raw vector rather than a destination, so it can be
--- added to whatever the ally was already trying to do. An ally running
--- to a soak should still bend around a puddle on the way rather than
--- choosing between the two.
local function DangerPush(x, y)
    local px, py = 0, 0

    local function repel(cx, cy, radius)
        local dx, dy = x - cx, y - cy
        local d = math.sqrt(dx * dx + dy * dy)
        if d >= radius then return end
        if d < 0.001 then
            px, py = px + 1, py
            return
        end
        local strength = (radius - d) / radius
        px, py = px + dx / d * strength, py + dy / d * strength
    end

    -- The boss's front, always. "Nobody but the tank stands in the cone"
    -- is a position the raid holds for the whole fight, not a thing it
    -- reacts to when a cast starts -- and reacting was too late anyway,
    -- because the frontals here have a two-second warning.
    local b = S.bossActor
    if b then
        local dx, dy = x - b.x, y - b.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d > 0.001 and d < 78 then
            local off = math.abs(((atan2(dy, dx) - (b.facing or 0) + math.pi)
                % (math.pi * 2)) - math.pi)
            if off < 0.65 then
                local strength = (0.65 - off) / 0.65
                px, py = px + (-math.sin(b.facing or 0)) * strength * 1.4,
                         py + (math.cos(b.facing or 0)) * strength * 1.4
            end
        end
    end

    -- The well. Standing in it is what the whole fight forbids, and it
    -- is not an actor -- it is a hole in the floor -- so nothing in the
    -- loop below would ever have kept the raid off it.
    if S.scenario and S.scenario.well then
        repel(0, 0, 26)
    end

    for _, a in ipairs(S.actors) do
        if a.dead then
            -- nothing
        elseif a.kind == "projectile" then
            -- The lane a spirit is taking, or is about to. Each one pops
            -- on the FIRST body it touches, so an ally standing in the
            -- line does not merely take a hit -- it takes the hit that
            -- was going to miss everyone, and stops the spirit reaching
            -- the far wall where it would have been harmless.
            local along, across = alongAcross(x, y, a.x, a.y, a.dir)
            local half = a.r + 12
            if along >= -6 and across < half then
                local nx, ny = -math.sin(a.dir), math.cos(a.dir)
                local side = ((x - a.x) * nx + (y - a.y) * ny) >= 0 and 1 or -1
                local strength = (half - across) / half
                px, py = px + nx * side * strength * 1.6,
                         py + ny * side * strength * 1.6
            end
        elseif a.kind == "dodge" and not a.resolved then
            repel(a.x, a.y, a.r + 7)
        elseif a.kind == "puddle" then
            repel(a.x, a.y, a.r + 5)
        elseif a.kind == "chaser" and a.intercept then
            -- Deliberately no repulsion. You are meant to be in its way.
        elseif a.kind == "chaser" or a.kind == "stalker" then
            repel(a.x, a.y, a.r + 8)
        elseif (a.kind == "line" and not a.resolved) or a.kind == "beam" then
            -- Pushed sideways off the axis, not backwards down it: the
            -- way out of a line is across it.
            local along, across = alongAcross(x, y, a.x, a.y, a.dir)
            local half = a.width / 2 + 7
            if along >= 0 and along <= a.len and across < half then
                local nx, ny = -math.sin(a.dir), math.cos(a.dir)
                local side = ((x - a.x) * nx + (y - a.y) * ny) >= 0 and 1 or -1
                local strength = (half - across) / half
                px, py = px + nx * side * strength, py + ny * side * strength
            end
        elseif a.kind == "wave" then
            local perp = a.dir + math.pi / 2
            local along, across = alongAcross(x, y, a.x, a.y, perp)
            local half = a.width / 2 + 9
            if math.abs(along) <= a.len / 2 and across < half then
                -- Ahead of the wave, so run with it rather than into it.
                local strength = (half - across) / half
                px = px + math.cos(a.dir) * strength
                py = py + math.sin(a.dir) * strength
            end
        end
    end
    return px, py
end

--- How bad the ground is in a cone pointing `dir` from the boss.
---
--- Used to pick which way it should face. Lower is cleaner.
local function ConeCost(bx, by, dir, rx, ry)
    local cost = 0
    -- Pointing it anywhere near the raid is the worst thing it can do.
    local toRaid = atan2(ry - by, rx - bx)
    local off = math.abs(((dir - toRaid + math.pi) % (math.pi * 2)) - math.pi)
    if off < 1.1 then cost = cost + (1.1 - off) * 40 end
    -- And a cone swept across bad ground is a cone nobody can stand in
    -- to do anything else.
    for _, a in ipairs(S.actors) do
        if not a.dead and (a.kind == "puddle" or a.kind == "dodge") then
            local along, across = alongAcross(a.x, a.y, bx, by, dir)
            if along > 0 and along < 90 and across < (a.r or 10) + 18 then
                cost = cost + 8
            end
        end
    end
    return cost
end

--- Turn and walk the boss, for reasons the player can follow.
---
--- The tank is understood to be doing both. It used to re-aim at RANDOM
--- every nine seconds, which is why this was hard to read: the cone
--- swung somewhere for no reason, and there was nothing to anticipate.
---
--- Now the facing is chosen: away from the raid, and away from ground
--- that is already ruined. That is exactly what a tank does, and it
--- means the safe side is always "where everyone else is standing" --
--- a rule the player can hold rather than a direction they must watch.
--- It still moves, because the raid moves and the floor keeps changing.
---
--- The boss also WALKS off bad ground rather than only turning on it.
local function UpdateBossPosition(dt)
    local b = S.bossActor
    if not b then return end
    b.facing = b.facing or TANK_ANGLE

    local rx, ry = RaidCentre()

    if S.scenario and S.scenario.bossFollowsTank then
        -- Vashnik: the PLAYER steers, because where the boss stands
        -- picks the altars. Faces the player, who is leading it.
        local dx, dy = S.px - b.x, S.py - b.y
        if (dx * dx + dy * dy) > 16 then b.facing = atan2(dy, dx) end
        local gx, gy = clampToArena(S.px, S.py, ARENA_R - BOSS_LEASH)
        local mx, my = gx - b.x, gy - b.y
        local d = math.sqrt(mx * mx + my * my)
        local step = BOSS_MOVE_SPEED * dt
        if d <= step then
            b.x, b.y = gx, gy
        elseif d > 0.001 then
            b.x, b.y = b.x + mx / d * step, b.y + my / d * step
        end
        return
    end

    -- Re-aimed on a cadence rather than every frame, so the cone holds
    -- still long enough to be read and to be stood behind.
    if not b.reaimAt or S.time >= b.reaimAt then
        local best, bestCost
        for k = 0, 11 do
            local cand = (k / 12) * math.pi * 2
            local cost = ConeCost(b.x, b.y, cand, rx, ry)
            if not bestCost or cost < bestCost then best, bestCost = cand, cost end
        end
        b.facingGoal = best or b.facing
        b.reaimAt = S.time + BOSS_REAIM_EVERY
    end

    local diff = (b.facingGoal or b.facing) - b.facing
    -- Shortest way round, or a turn from 350 degrees to 10 takes the long
    -- way and swings the cone through the whole raid on its way.
    while diff > math.pi do diff = diff - math.pi * 2 end
    while diff < -math.pi do diff = diff + math.pi * 2 end
    local step = BOSS_TURN_RATE * dt
    if math.abs(diff) <= step then
        b.facing = b.facingGoal or b.facing
    else
        b.facing = b.facing + (diff > 0 and step or -step)
    end

    -- A phase can call it somewhere. The intermission drags Nek'zali
    -- onto the well to channel, which is also what makes her immune --
    -- so the boss walking to the middle IS the phase starting, and the
    -- player should see it happen rather than find her there.
    local phase = CurrentPhase()
    if phase and phase.bossAt == "centre" then
        local d = math.sqrt(b.x * b.x + b.y * b.y)
        local step = BOSS_MOVE_SPEED * dt
        if d <= step then
            b.x, b.y = 0, 0
        elseif d > 0.001 then
            b.x, b.y = b.x - b.x / d * step, b.y - b.y / d * step
        end
        return
    end

    -- And step off anything it is standing in. Slowly, and only far
    -- enough to get clear -- a boss that fled every puddle would drag
    -- melee around the room all fight.
    local px, py = 0, 0
    for _, a in ipairs(S.actors) do
        if not a.dead and a.kind == "puddle" then
            local dx, dy = b.x - a.x, b.y - a.y
            local d = math.sqrt(dx * dx + dy * dy)
            local reach = (a.r or 10) + b.r
            if d < reach and d > 0.001 then
                px, py = px + dx / d, py + dy / d
            end
        end
    end
    -- The well counts as ground to stay off, for the boss as much as
    -- for anybody: melee stand on it if she does.
    if S.scenario and S.scenario.well then
        local d = math.sqrt(b.x * b.x + b.y * b.y)
        if d < 34 then
            if d < 0.001 then
                px, py = px + 1, py
            else
                px, py = px + b.x / d * 1.5, py + b.y / d * 1.5
            end
        end
    end

    local plen = math.sqrt(px * px + py * py)
    if plen > 0.001 then
        local step2 = BOSS_MOVE_SPEED * 0.7 * dt
        b.x, b.y = clampToArena(b.x + px / plen * step2,
                                b.y + py / plen * step2, 30)
    end
end

--- What an ally should be shooting.
---
--- Priority first, distance second. Every guide in this raid says the
--- same thing about casters -- kick order, priority target, stop the
--- cast -- so a caster is worth crossing the room for and an add
--- wandering past is not.
local function AllyTarget(ally)
    -- The tank holds the boss and does not chase adds. One fewer body on
    -- the pack, and it keeps the formation legible.
    if ally.role == "TANK" then return S.bossActor end
    local RANK = { caster = 3, chaser = 2, stalker = 1 }
    local best, bestD, bestRank
    for _, a in ipairs(S.actors) do
        if a.enemy and not a.dead and a.hp and a.hp > 0 then
            local rank = RANK[a.kind] or 1
            local d = dist(ally.x, ally.y, a.x, a.y)
            if not bestRank or rank > bestRank or (rank == bestRank and d < bestD) then
                best, bestD, bestRank = a, d, rank
            end
        end
    end
    return best or S.bossActor
end

--- Put a couple of allies on collection duty.
---
--- Capped at two, which is the guides' own number ("two or three players
--- on box duty"). Uncapped, the raid would hoover every orb on the floor
--- and the player would arrive to find the job done.
local ORB_COLLECTORS = 2

local function AssignOrbs()
    for _, ally in ipairs(S.allies) do ally.orbTarget = nil end
    local sent = 0
    for _, act in ipairs(S.actors) do
        if sent >= ORB_COLLECTORS then break end
        if act.kind == "orb" and not act.dead then
            local best, bestD
            for _, ally in ipairs(S.allies) do
                if ally.role ~= "TANK" and not ally.runOut and not ally.hold
                    and not ally.orbTarget then
                    local d = dist(ally.x, ally.y, act.x, act.y)
                    if not bestD or d < bestD then best, bestD = ally, d end
                end
            end
            if best then
                best.orbTarget = act
                sent = sent + 1
            end
        end
    end
end

--- Where an ally wants to be standing, before danger is considered.
---
--- Ordered by priority, and the order is the raid's: a mechanic on YOU
--- outranks a mechanic on the group, which outranks damage.
local function AllyGoal(ally, index)
    -- Which soak, if any, this ally is actually going to. Recorded
    -- rather than inferred: counting bodies inside a circle cannot tell
    -- an assignment from somebody who happened to be standing there, and
    -- once the raid started getting shoved out of the boss's cone it
    -- could not tell them apart at all.
    ally.goalSoak = nil

    -- 1. Something is on them personally. The destination was fixed when
    --    the mechanic landed -- see AssignRunOut for why it is not
    --    recomputed.
    if ally.runOut then
        return ally.runOutX or ally.x, ally.runOutY or ally.y
    end

    -- 2. Holding position for a mechanic that needs them findable. The
    --    crosswind partner and the number game both ask the PLAYER to
    --    reach a specific ally, and an ally that keeps walking turns a
    --    reaction test into a chase.
    if ally.hold then return ally.x, ally.y end

    -- 3. Goalie: get between it and what it is walking at.
    for _, a in ipairs(S.actors) do
        if a.kind == "chaser" and a.intercept and not a.dead then
            local d = math.sqrt(a.x * a.x + a.y * a.y)
            if d > 0.001 then
                local back = math.max(d - 10, 0)
                return a.x / d * back, a.y / d * back
            end
        end
    end

    -- 4. Box duty. See AssignOrbs.
    if ally.orbTarget and not ally.orbTarget.dead then
        return ally.orbTarget.x, ally.orbTarget.y
    end

    -- 5. A group mechanic.
    for _, a in ipairs(S.actors) do
        if not a.dead and not a.resolved then
            if a.kind == "soak" and (
                    a.soakBy == "tank" and ally.role == "TANK"
                    or a.soakBy == "melee"
                        and (ally.role == "TANK" or ally.role == "MELEE")
                    -- No soakBy: the raid takes it, minus the tank, and
                    -- filtered by group. An UNGROUPED soak is a
                    -- whole-raid soak and everybody goes; a grouped one
                    -- is an assignment and only its group does.
                    or a.soakBy == nil and ally.role ~= "TANK"
                        and (a.group == nil or a.group == ally.soakGroup)
                ) and not (a.marks and S.time < (ally.soakedUntil or 0)) then
                ally.goalSoak = a
                return a.x, a.y
            elseif a.kind == "refuge" then
                local best, bestD
                for _, sp in ipairs(a.spots) do
                    local d = dist(ally.x, ally.y, sp.x, sp.y)
                    if not bestD or d < bestD then best, bestD = sp, d end
                end
                if best then return best.x, best.y end
            elseif a.kind == "stack" then
                if a.atCentre then return 0, 0 end
                return RaidCentre()
            end
        end
    end

    -- 6. Otherwise, hold station on whatever they are shooting.
    --
    --    On the BOSS that means the formation, rotated to its facing so
    --    the tank stays in front and melee stay behind whichever way it
    --    has been walked. On an add it means closing to their own range
    --    around it, fanned by their slot so they do not stack up.
    local t = ally.target
    if not t then return ally.x, ally.y end

    if t == S.bossActor then
        local rot = (t.facing or TANK_ANGLE) - TANK_ANGLE
        local reach = ally.formDist
        if ally.role == "TANK" then
            -- Barrage hits harder the closer you are, so the tank walks
            -- out while it winds up and steps back once it has fired.
            -- The boss keeps the facing it already had, which is how the
            -- spirits end up pointed away from the raid rather than
            -- through it.
            for _, act in ipairs(S.actors) do
                if act.kind == "projectile" and not act.dead
                    and S.time < (act.launchAt or 0) then
                    reach = 52
                    break
                end
            end
        end
        return t.x + math.cos(ally.formAngle + rot) * reach,
               t.y + math.sin(ally.formAngle + rot) * reach
    end

    local reach = (ally.role == "RANGED" or ally.role == "HEALER")
        and ALLY_ADD_STANDOFF or 12
    return t.x + math.cos(ally.slot) * reach,
           t.y + math.sin(ally.slot) * reach
end

-- Assigned with the shooting section below, which the raid also uses.
local FireShot

local function UpdateAllies(dt)
    local bx, by = 0, 0
    if S.bossActor then bx, by = S.bossActor.x, S.bossActor.y end

    AssignOrbs()

    for i, ally in ipairs(S.allies) do
        ally.stagger = math.max(0, ally.stagger - dt)
        ally.target = AllyTarget(ally)

        local gx, gy = AllyGoal(ally, i)
        local dx, dy = gx - ally.x, gy - ally.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d > 0.001 then dx, dy = dx / d, dy / d else dx, dy = 0, 0 end

        local px, py = DangerPush(ally.x, ally.y)
        local weight = (ally.role == "TANK") and (DANGER_WEIGHT * 0.35) or DANGER_WEIGHT
        if ally.role == "TANK" then
            -- The tank does not dodge frontals at all. It is the one the
            -- cone is aimed at, and standing in it is the job -- so the
            -- repulsion that was fighting its formation slot every frame
            -- goes away, and with it the jitter. It still avoids puddles
            -- and adds, which a tank genuinely does.
            px, py = 0, 0
            for _, act in ipairs(S.actors) do
                if not act.dead and (act.kind == "puddle" or act.kind == "chaser"
                    or act.kind == "stalker") then
                    local dx2, dy2 = ally.x - act.x, ally.y - act.y
                    local d2 = math.sqrt(dx2 * dx2 + dy2 * dy2)
                    local radius = (act.r or 6) + 5
                    if d2 < radius and d2 > 0.001 then
                        local strength = (radius - d2) / radius
                        px = px + dx2 / d2 * strength
                        py = py + dy2 / d2 * strength
                    end
                end
            end
        end
        if ally.runOut then
            -- Somebody carrying a mechanic commits to their spot. Full
            -- avoidance was enough to stop them arriving at all, and the
            -- circles ended up overlapping -- the exact thing the
            -- run-out exists to prevent.
            weight = weight * 0.35
        end
        dx, dy = dx + px * weight, dy + py * weight

        local len = math.sqrt(dx * dx + dy * dy)
        -- A small dead zone so an ally standing on its mark does not
        -- vibrate against it.
        if len > 0.05 and (d > 2 or px ~= 0 or py ~= 0) then
            ally.x = ally.x + dx / len * ALLY_SPEED * dt
            ally.y = ally.y + dy / len * ALLY_SPEED * dt
            ally.x, ally.y = clampToArena(ally.x, ally.y, ALLY_WALL_PAD)
        end

        -- Standing in a marking soak counts as having taken it, so they
        -- sit the next one out and the swap is visible.
        for _, act in ipairs(S.actors) do
            if not act.dead and act.kind == "soak" and act.marks
                and dist(ally.x, ally.y, act.x, act.y) <= act.r then
                ally.soakedUntil = S.time + (act.marksFor or 14)
            end
        end

        -- Standing in something. They do not have health, but a raid that
        -- walks through a puddle with no consequence reads as scenery.
        for _, act in ipairs(S.actors) do
            if not act.dead and act.kind == "puddle"
                and dist(ally.x, ally.y, act.x, act.y) <= act.r then
                ally.stagger = math.max(ally.stagger, 0.7)
            end
        end

        -- Face whatever they are shooting, and shoot it.
        local t = ally.target
        if t then
            ally.aim = atan2(t.y - ally.y, t.x - ally.x)
        else
            ally.aim = atan2(by - ally.y, bx - ally.x)
        end
        ally.fireCd = ally.fireCd - dt
        -- Not during the countdown. The raid was opening fire on three,
        -- two, one -- and those shots were spawned before UpdateShots
        -- runs, so they were created and never moved.
        if S.countdown <= 0 and ally.fireCd <= 0 and ally.stagger <= 0
            and t and (t.hp or 0) > 0 then
            FireShot(ally.x, ally.y, ally.aim, ALLY_DAMAGE, true)
            ally.fireCd = ALLY_FIRE_CD
        end
    end
end

--- Send `count` allies out with the mechanic the player just got.
---
--- TARGETED, not universal. The first version had every ally react to a
--- spread, so the whole raid sprinted for the wall the moment the player
--- was debuffed -- which is not the mechanic, and teaches the player to
--- expect a room that empties.
---
--- `puddle` is a spec table, not a flag, so the raid leaves the SAME
--- ground the player does -- including a permanent one.
local function AssignRunOut(count, duration, puddle, reach, tag, awayFromCentre)
    -- Ranged first, melee only if the ranged are already busy. Not
    -- cosmetic: a melee sent to the wall crosses the room twice and
    -- spends the mechanic out of position.
    local chosen = {}
    for _, order in ipairs({ "RANGED", "HEALER", "MELEE" }) do
        for _, ally in ipairs(S.allies) do
            if #chosen >= count then break end
            -- Never the tank. It is holding the boss.
            if ally.role == order and not ally.runOut and not ally.hold then
                chosen[#chosen + 1] = ally
            end
        end
    end
    if #chosen == 0 then return end

    local cx, cy = RaidCentre()
    local base = 0
    local pdx, pdy = S.px - cx, S.py - cy
    if (pdx * pdx + pdy * pdy) > 1 then base = atan2(pdy, pdx) end

    -- Destinations chosen greedily, keeping whichever candidate is
    -- furthest from everyone already placed.
    --
    -- Even arcs around the raid's centre only separate people if the
    -- player happens to stand on the same circle -- and once the raid
    -- started moving to collect orbs, that assumption quietly stopped
    -- holding and the circles overlapped again. Optimising the distance
    -- directly cannot drift: it is the quantity the mechanic is judged on.
    local CANDIDATES = 16
    local placed = { { x = S.px, y = S.py } }
    for _, ally in ipairs(chosen) do
        local bestAngle, bestScore
        for k = 0, CANDIDATES - 1 do
            local angle = base + (k / CANDIDATES) * math.pi * 2
            local cxx = cx + math.cos(angle) * (reach or 30)
            local cyy = cy + math.sin(angle) * (reach or 30)
            local worst
            for _, pt in ipairs(placed) do
                local d = dist(cxx, cyy, pt.x, pt.y)
                if not worst or d < worst then worst = d end
            end
            if not bestScore or worst > bestScore then
                bestScore, bestAngle = worst, angle
            end
        end
        local angle = bestAngle or base
        placed[#placed + 1] = {
            x = cx + math.cos(angle) * (reach or 30),
            y = cy + math.sin(angle) * (reach or 30),
        }

        ally.runOut = true
        ally.runOutUntil = S.time + duration
        ally.runOutPuddle = puddle
        ally.runOutTag = tag
        if awayFromCentre then
            -- Nek'zali's rule: Essence Rend's puddle is permanent, so it
            -- goes against the WALL and never near the middle. Measured
            -- from the ARENA's centre rather than the raid's, or a group
            -- already standing off to one side gets sent back through
            -- the room.
            ally.runOutX, ally.runOutY = clampToArena(
                math.cos(angle) * (ARENA_R - ALLY_WALL_PAD),
                math.sin(angle) * (ARENA_R - ALLY_WALL_PAD), ALLY_WALL_PAD)
        else
            -- Resolved here, against the centre as it stands NOW, and
            -- then left alone. Recomputing per frame is a feedback loop:
            -- the runners are part of the raid, so each step drags the
            -- centre after them and pushes their own goal out again.
            ally.runOutX, ally.runOutY = clampToArena(
                cx + math.cos(angle) * (reach or 30),
                cy + math.sin(angle) * (reach or 30), ALLY_WALL_PAD)
        end
    end
end

local function TickAllyTimers()
    for _, ally in ipairs(S.allies) do
        if ally.runOut and S.time >= (ally.runOutUntil or 0) then
            ally.runOut = false
            local spec = ally.runOutPuddle
            if spec then
                -- The raid leaves the same ground the player does. These
                -- were hardcoded small and short-lived, which was fine
                -- until a mechanic turned out to be permanent -- and the
                -- player's staying while the raid's evaporated taught
                -- that the rule applied to them personally.
                Spawn({
                    kind = "puddle", name = spec.name, school = spec.school,
                    r = spec.r or 8, life = spec.life or 9, dps = spec.dps or 8,
                    permanent = spec.permanent,
                    where = { x = ally.x, y = ally.y },
                })
            end
        end
    end
end

------------------------------------------------------------
-- Phases
--
-- Every fight in this raid is built out of phases -- push to fifty, kill
-- two Echoes, come back down harder -- and a single flat timeline cannot
-- say that. What it produced instead was every mechanic from every phase
-- averaged into one minute, which is not a simplification of the fight
-- so much as a different fight.
--
-- A phase owns its own event list and its own clock, and names the
-- condition that ends it:
--
--   duration    seconds, for a phase on a timer
--   untilPct    boss health percent, for a push
--   untilClear  every enemy dead AND every event spawned, for an
--               intermission you finish by killing what it sent
--
-- Scenarios without `phases` are wrapped in a single one at Start, so
-- nothing had to migrate all at once.
------------------------------------------------------------

--- The phase list for a scenario, old shape or new.
local function PhasesOf(sc)
    if sc.phases then return sc.phases end
    return { { name = sc.title or "", events = sc.events, duration = sc.duration } }
end

function CurrentPhase()
    return S.phases and S.phases[S.phaseIndex]
end

--- Has this phase finished?
local function PhaseComplete(p)
    if not p then return true end
    if p.untilClear then
        if S.nextEvent <= #(p.events or {}) then return false end
        for _, a in ipairs(S.actors) do
            if a.enemy and not a.dead then return false end
        end
        return true
    end
    -- Conditions are OR'd, not tried in order. A push phase carries both
    -- a health threshold and a duration: the threshold is how the fight
    -- really ends it, and the duration is the backstop for a player who
    -- cannot put out that much damage. Checking only the first would
    -- strand them in phase one forever.
    local pct = p.untilPct or p.hpFloor
    if pct and S.bossActor
        and (S.bossActor.hp / S.bossActor.maxHp * 100) <= pct
        -- A floor alone does not end a phase; the phase's own clock still
        -- has to run, or an intermission would be skipped by a raid that
        -- reached the transition early.
        and (not p.duration or S.phaseTime >= p.duration) then
        return true
    end
    if p.duration and S.phaseTime >= p.duration then return true end
    if p.untilPct or p.duration then return false end
    return S.nextEvent > #(p.events or {})
end

------------------------------------------------------------
-- Tunnels and cysts
--
-- Sszorak's actual fight, and the trainer had none of it. What was here
-- was the reaction to the wind; what the guide spends its longest
-- paragraph on is the PREPARATION -- read the orb count in each tunnel
-- to learn the order they will blow, then place a cyst on the marker
-- OPPOSITE each one, so the wind throws you into it instead of off the
-- platform.
--
-- That is two mechanics separated by a minute, and the first one is
-- invisible unless you were told to look. It is also the clearest
-- example of the thing that was missing generally: a mechanic that uses
-- the whole room rather than the six yards around the player.
------------------------------------------------------------
local TUNNEL_R = 86
local CYST_R   = 66
local CYST_REACH = 13

local tunnelTex, tunnelPip, cystTex = {}, {}, {}
for i = 1, 3 do
    tunnelTex[i] = arena:CreateTexture(nil, "ARTWORK", nil, 4)
    cystTex[i]   = arena:CreateTexture(nil, "ARTWORK", nil, 4)
    tunnelPip[i] = {}
    for k = 1, 3 do
        tunnelPip[i][k] = arena:CreateTexture(nil, "OVERLAY", nil, 2)
    end
end

local function ResetTunnels(sc)
    S.tunnels = nil
    for i = 1, 3 do
        tunnelTex[i]:Hide(); cystTex[i]:Hide()
        for k = 1, 3 do tunnelPip[i][k]:Hide() end
    end
    if not (sc and sc.tunnels) then return end

    -- The order is shuffled every round. It has to be READ, and an order
    -- that never changed would be memorised once and never read again.
    local order = { 1, 2, 3 }
    for i = 3, 2, -1 do
        local j = math.random(i)
        order[i], order[j] = order[j], order[i]
    end

    S.tunnels = {}
    for i = 1, 3 do
        -- Rotated off the cardinals on purpose. At a base of pi/2 the
        -- cyst marker opposite the first tunnel lands at (0, -66) -- six
        -- units from where the player spawns -- so standing perfectly
        -- still placed a cyst for free, and whether it happened depended
        -- on a shuffle. A mechanic must never be completable by not
        -- having moved yet.
        local angle = math.pi / 2 + math.pi / 6 + (i - 1) * (2 * math.pi / 3)
        S.tunnels[i] = {
            angle = angle,
            x = math.cos(angle) * TUNNEL_R,
            y = math.sin(angle) * TUNNEL_R,
            -- Where its cyst belongs: directly across the room.
            cx = -math.cos(angle) * CYST_R,
            cy = -math.sin(angle) * CYST_R,
            order = order[i],
            cyst = false,
        }
    end
end

--- The tunnel that blows `step`-th, or nil.
local function TunnelByOrder(step)
    for _, t in ipairs(S.tunnels or {}) do
        if t.order == step then return t end
    end
end

local function DrawTunnels(s)
    if not S.tunnels then return end
    for i, t in ipairs(S.tunnels) do
        local live = S.windStep and t.order == S.windStep
        put(tunnelTex[i], "hex", t.x, t.y, 15, s,
            live and { 1, 0.85, 0.4 } or { 0.55, 0.75, 1 }, live and 1 or 0.75)
        -- The count IS the mechanic: one pip blows first, two second.
        for k = 1, 3 do
            local pip = tunnelPip[i][k]
            if k <= t.order then
                put(pip, "diamond", t.x + (k - 2) * 7, t.y, 6, s, { 1, 1, 1 }, 0.95)
            else
                pip:Hide()
            end
        end
        -- And where its cyst goes, drawn from the start so the pairing
        -- is visible rather than something to work out under pressure.
        if t.cyst then
            put(cystTex[i], "spike", t.cx, t.cy, 20, s, { 0.6, 1, 0.7 }, 0.95,
                S.time * 0.4)
        else
            put(cystTex[i], "ring", t.cx, t.cy, CYST_REACH * 2, s,
                { 0.45, 0.7, 1 }, 0.4)
        end
    end
end

------------------------------------------------------------
-- Altars
--
-- Vashnik's whole fight, and it was missing: the boss draws power from
-- the two altars nearest the raid, so WHERE THE GROUP STANDS decides
-- which adds it spawns and how hard they hit. Every other mechanic on
-- that boss is downstream of this one, and without it the encounter was
-- being taught as a pile of unrelated adds.
--
-- Modelled as: three fixed altars, ranked every frame by distance to the
-- raid's centre. Nearest takes two stacks, second takes one, the far one
-- is dormant. The tank walks the boss -- see BOSS_MOVE_SPEED above -- so
-- the choice is a real one made with the feet, which is exactly the
-- decision the written guide spends its longest paragraph on.
------------------------------------------------------------
local ALTAR_R = 62
local ALTAR_SPEC = {
    { school = "fire",   name = "Fire" },
    { school = "shadow", name = "Shadow" },
    { school = "blood",  name = "Blood" },
}

local altarTex, altarRing, altarLabel = {}, {}, {}
for i = 1, #ALTAR_SPEC do
    altarTex[i]   = arena:CreateTexture(nil, "ARTWORK", nil, 4)
    altarRing[i]  = arena:CreateTexture(nil, "ARTWORK", nil, 3)
    altarLabel[i] = arena:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
end

local function ResetAltars(sc)
    S.altars = nil
    for i = 1, #ALTAR_SPEC do
        altarTex[i]:Hide(); altarRing[i]:Hide(); altarLabel[i]:SetText("")
    end
    if not (sc and sc.altars) then return end
    S.altars = {}
    for i, spec in ipairs(ALTAR_SPEC) do
        local angle = math.pi / 2 + (i - 1) * (2 * math.pi / 3)
        S.altars[i] = {
            school = spec.school, name = spec.name,
            x = math.cos(angle) * ALTAR_R,
            y = math.sin(angle) * ALTAR_R,
            stacks = 0,
        }
    end
end

--- Re-rank the altars by how close the raid is standing.
---
--- Run every frame rather than only when the boss casts, so the player
--- can SEE the empowerment shift as they walk. A mechanic whose state
--- only reveals itself at the moment it matters is a mechanic nobody
--- learns to steer.
local function RankAltars()
    if not S.altars then return nil end
    -- Measured from the BOSS, not from the raid. The guide is specific:
    -- Vashnik draws power from the two altars nearest HIM, and the raid
    -- only decides that indirectly by where it makes the tank stand.
    -- Ranking off the group's centre worked, but it taught the mechanic
    -- backwards.
    local cx, cy = 0, 0
    if S.bossActor then cx, cy = S.bossActor.x, S.bossActor.y end
    local order = {}
    for _, alt in ipairs(S.altars) do
        order[#order + 1] = { alt = alt, d = dist(cx, cy, alt.x, alt.y) }
    end
    table.sort(order, function(a, b) return a.d < b.d end)
    for i, e in ipairs(order) do
        e.alt.stacks = (i == 1) and 2 or ((i == 2) and 1 or 0)
    end
    return order
end

local function DrawAltars(s)
    if not S.altars then return end
    for i, alt in ipairs(S.altars) do
        local col = SCHOOL[alt.school] or C.add
        local lit = alt.stacks > 0
        local size = 13 + alt.stacks * 3
        put(altarTex[i], "star", alt.x, alt.y, size, s, col,
            lit and 1 or 0.35, S.time * (0.3 + 0.35 * alt.stacks))
        put(altarRing[i], "ring", alt.x, alt.y, size * 1.7, s, col,
            lit and (0.45 + 0.25 * alt.stacks) or 0.18)
        altarLabel[i]:SetPoint("CENTER", arena, "CENTER",
            alt.x * s, (alt.y - 13) * s)
        if lit then
            altarLabel[i]:SetText(("|cffffffff%s +%d|r"):format(alt.name, alt.stacks))
        else
            altarLabel[i]:SetText(("|cff777777%s|r"):format(alt.name))
        end
    end
end

------------------------------------------------------------
-- Actors
------------------------------------------------------------
local KINDS = {}

function Spawn(ev)
    local a = {}
    for k, v in pairs(ev) do a[k] = v end
    a.born = S.time
    a.cast = a.cast or 0
    a.resolveAt = S.time + a.cast
    a.dead = false

    if a.where == "player" then
        a.x, a.y = S.px, S.py
    elseif a.where == "centre" then
        a.x, a.y = 0, 0
    elseif a.where == "boss" then
        -- Distinct from "centre" now that a boss can be walked away from
        -- it. A frontal that still came from the middle of the room
        -- after the tank moved would be a cone from nowhere.
        a.x, a.y = 0, 0
        if S.bossActor then a.x, a.y = S.bossActor.x, S.bossActor.y end
    elseif a.where == "raid" then
        a.x, a.y = RaidCentre()
    elseif a.where == "edge" then
        a.x, a.y, a.spawnAngle = edgePoint()
    elseif type(a.where) == "table" then
        a.x, a.y = a.where.x, a.where.y
    else
        a.x, a.y = randomPoint(a.inset or 16)
    end

    local kind = KINDS[a.kind]
    if kind and kind.Init then kind.Init(a) end

    S.actors[#S.actors + 1] = a
    if a.call then
        callOut:SetTextColor(1, 0.85, 0.3)
        callOut:SetText(a.call)
        -- Waves and other instant mechanics have no cast to hang the
        -- text on, and those are exactly the ones a player cannot name
        -- from looking at them. A floor of a second and a half.
        S.callUntil = S.time + math.max(a.cast, 1.6)
    end
    return a
end

local function castProgress(a)
    if a.cast <= 0 then return 1 end
    return math.min(1, (S.time - a.born) / a.cast)
end

--- The ground telegraph every circular mechanic shares: a rim, a fill
--- that grows as the cast completes, and a swirl turning inside it.
---
--- The swirl is the part that earns its keep. A static ring says "there
--- is something here"; a ring that turns says "this is winding up", and
--- it does it in peripheral vision, which is where the player actually
--- is while they are aiming at something else.
local function DrawGroundCircle(a, s, col, fillAlpha, live)
    local p = castProgress(a)
    local d = a.r * 2
    local fill = schoolOf(a, col)

    put(V(a, 1, "ARTWORK", 0), "disc", a.x, a.y, d * (live and 1 or p), s,
        fill, live and 0.85 or fillAlpha)
    -- The ring keeps the semantic colour whatever the school is. It is
    -- the half that answers "in or out", and that answer must never be
    -- something the player has to decode a palette to get.
    put(V(a, 2, "ARTWORK", 2), "ring", a.x, a.y, d, s, col, live and 1 or 0.9)
    put(V(a, 3, "ARTWORK", 1), "swirl", a.x, a.y, d * 0.92, s, fill,
        live and 0.9 or (0.35 + 0.4 * p),
        S.time * 2.2 * (a.spinDir or 1))
end

------------------------------------------------------------
-- dodge / soak -- the two halves of the same shape
------------------------------------------------------------
KINDS.dodge = {
    Init = function(a) a.spinDir = (math.random() < 0.5) and -1 or 1 end,
    Resolve = function(a)
        if dist(S.px, S.py, a.x, a.y) <= a.r then
            Hurt(a.damage or 22, a.name)
            if a.stack then AddStack(a.stack) end
        else
            Credit(a.name .. " dodged")
        end
        -- Some of these leave ground behind. Spawning the puddle as the
        -- CONSEQUENCE of something the player watched land is the whole
        -- difference between area denial that makes sense and a pool
        -- that appeared out of nowhere while they were looking
        -- elsewhere.
        if a.leaves then
            Spawn({
                kind = "puddle", name = a.name, school = a.school,
                r = a.leaves.r or a.r, life = a.leaves.life or 16,
                dps = a.leaves.dps or 12,
                where = { x = a.x, y = a.y },
            })
        end
        a.flashUntil = S.time + 0.25
    end,
    Draw = function(a, s)
        DrawGroundCircle(a, s, C.bad, 0.28, a.flashUntil and S.time < a.flashUntil)
    end,
}

KINDS.soak = {
    Init = function(a)
        a.spinDir = (math.random() < 0.5) and -1 or 1
        -- Read once, at cast time, and remembered: the mark can lapse
        -- mid-cast and a circle that changed its mind halfway through
        -- would be worse than one that was simply wrong.
        a.notMine = a.marks and HasDebuff(a.marks) or false
        if a.notMine then
            a.call = ("You are %s -- stay OUT of %s and take the Flames")
                :format(a.marks, a.name)
        end
    end,
    -- A soak with `marks` is a SPLIT soak, and it has four outcomes
    -- rather than two.
    --
    -- Hungering Pyre is the case: soak it and the damage splits, but you
    -- are singed and should let somebody else take the next one --
    -- and everybody who does NOT soak is set alight instead, which is
    -- itself a job rather than a punishment. Scoring it as
    -- in-good / out-bad threw away the whole mechanic, and the raid
    -- alternating was invisible because nothing recorded who had just
    -- gone.
    Resolve = function(a)
        local inside = dist(S.px, S.py, a.x, a.y) <= a.r
        -- The state as it was when the circle appeared, not as it is
        -- now. Judging against a mark that lapsed during the cast would
        -- punish a player for doing exactly what they were told.
        local marked = a.notMine

        if inside and marked then
            -- The one real mistake, and it has to hurt more than the job
            -- you were avoiding. Set gently, always soaking came out
            -- CHEAPER than alternating -- the mark cost nothing, so the
            -- correct play was to ignore it.
            Hurt((a.damage or 20) * 3,
                a.name .. " -- you are still " .. a.marks .. ", let someone else take it")
        elseif inside then
            Credit(a.name .. " soaked")
            if a.marks then ApplyDebuff(a.marks, a.marksFor or 14) end
            if a.clears then AddStack(-a.clears) end
        elseif marked then
            -- Correctly sitting it out. Still catches the follow-up,
            -- because everybody outside the circle does.
            Credit("Sat out " .. a.name .. " -- correct")
        else
            Hurt(a.damage or 20, a.name)
        end

        -- What happens to everyone who stayed out, whether they were
        -- right to or not.
        if not inside and a.onMiss then
            local ev = {}
            for k, v in pairs(a.onMiss) do ev[k] = v end
            ev.where = "player"
            Spawn(ev)
        end
        a.flashUntil = S.time + 0.25
    end,
    Draw = function(a, s)
        -- Amber, not green, when it is somebody else's turn. The ring
        -- means "what do I do about this", and the honest answer for a
        -- Singed player is "not this one".
        local col = a.notMine and { 1.0, 0.72, 0.25 } or C.good
        DrawGroundCircle(a, s, col, 0.25, a.flashUntil and S.time < a.flashUntil)
    end,
}

------------------------------------------------------------
-- puddle -- persistent area denial
------------------------------------------------------------
KINDS.puddle = {
    Init = function(a)
        -- Some ground never fades. Nek'zali's Essence Rend is the case
        -- the guide is emphatic about -- take it to the wall, never leave
        -- one in the middle -- and that instruction only means anything
        -- if the puddle stays there. Expiring it after half a minute
        -- quietly turned "this is forever" into "this is inconvenient",
        -- which is the opposite lesson.
        --
        -- A permanent puddle lasts the phase; EnterPhase clears the
        -- field, which is the right lifetime for it.
        a.expireAt = a.permanent and math.huge or (S.time + (a.life or 30))
        a.resolveAt = nil
    end,
    Tick = function(a, dt)
        -- Invoke sets the void zones wandering, which turns a floor you
        -- had learned into one you have to keep re-reading. A phase says
        -- so and every puddle in the room drifts.
        local phase = CurrentPhase()
        if phase and phase.movingPuddles then
            a.heading = (a.heading or (math.random() * math.pi * 2))
                + (math.random() - 0.5) * dt * 2.2
            local speed = phase.puddleSpeed or 9
            local nx = a.x + math.cos(a.heading) * speed * dt
            local ny = a.y + math.sin(a.heading) * speed * dt
            -- Turned back at the wall rather than clamped to it, or they
            -- all end up parked around the rim within a few seconds.
            if (nx * nx + ny * ny) > (ARENA_R - a.r) ^ 2 then
                a.heading = a.heading + math.pi
            else
                a.x, a.y = nx, ny
            end
        end
        if dist(S.px, S.py, a.x, a.y) <= a.r then
            S.hp = math.max(0, S.hp - (a.dps or 14) * dt)
            S.flash = math.max(S.flash, 0.18)
        end
        if S.time > a.expireAt then a.dead = true end
    end,
    Draw = function(a, s)
        local fade = math.min(1, (a.expireAt - S.time) / 2)
        -- A blob rather than a disc. Puddles are the one ground effect
        -- that is not a cast -- it has spilled rather than been aimed --
        -- and the irregular edge is what says so without a label.
        local col = schoolOf(a, C.goo)
        put(V(a, 1, "ARTWORK", 0), "blob", a.x, a.y, a.r * 2, s, col, 0.45 * fade)
        put(V(a, 2, "ARTWORK", 2), "blob", a.x, a.y, a.r * 2.05, s, col, 0.30 * fade,
            S.time * 0.15)
    end,
}

------------------------------------------------------------
-- drop -- you are the mechanic
------------------------------------------------------------
KINDS.drop = {
    Resolve = function(a)
        local ok
        if a.away == "centre" then
            ok = dist(S.px, S.py, 0, 0) >= (a.minDist or 60)
        else
            ok = NearestAllyDist() >= (a.minDist or 26)
        end
        if ok then
            Credit(a.name .. " dropped safely")
        else
            Hurt(a.damage or 18, a.name .. " dropped on the raid")
        end
        if a.burns then
            -- The point of carrying it. Cremating the bodies is the job,
            -- and it is scored as one rather than as damage avoided.
            local n = BurnCorpses(S.px, S.py, (a.r or 13) + 4)
            if n > 0 then
                Credit(("Burned %d corpse%s"):format(n, n == 1 and "" or "s"))
            end
        end
        Spawn({
            kind = "puddle", name = a.name, school = a.school,
            r = a.r or 13, life = a.life or 20, permanent = a.permanent,
            dps = a.dps or 12, where = { x = S.px, y = S.py },
        })
    end,
    Init = function(a)
        -- Two of the raid get it as well, and visibly go and deal with
        -- it. A mechanic that only ever lands on the player reads as a
        -- spotlight rather than as something the fight is doing.
        AssignRunOut(2, a.cast or 4, {
            name = a.name, school = a.school,
            r = (a.r or 13) * 0.8, life = a.life, dps = a.dps,
            permanent = a.permanent,
        }, 56, a.name, a.away == "centre")
    end,
    Draw = function(a, s)
        local p = castProgress(a)
        local d = (a.r or 13) * 2 * (1.6 - 0.6 * p)
        local col = schoolOf(a, { 0.9, 0.5, 1 })
        put(V(a, 1, "ARTWORK", 2), "ring", S.px, S.py, d, s, col, 0.9)
        put(V(a, 2, "ARTWORK", 1), "swirl", S.px, S.py, d * 0.9, s, col,
            0.5, -S.time * 3)
        local slot = 2
        for _, ally in ipairs(S.allies) do
            if ally.runOut and ally.runOutTag == a.name then
                slot = slot + 1
                put(V(a, slot, "ARTWORK", 2), "ring", ally.x, ally.y, d, s, col, 0.55)
            end
        end
    end,
}

------------------------------------------------------------
-- line / beam / wave -- the bar family
------------------------------------------------------------
KINDS.line = {
    Init = function(a)
        if not a.dir then
            if a.where == "boss" and S.bossActor then
                -- Down the boss's facing, which is where the tank has
                -- walked it. "Tank her facing away, the raid stands
                -- behind her" only teaches anything if the cone actually
                -- goes that way -- fired at random, the formation was
                -- decoration. A little jitter, so the safe lane behind
                -- the boss has to be held rather than parked in.
                a.dir = (S.bossActor.facing or TANK_ANGLE)
                    + (math.random() - 0.5) * 0.5
            else
                a.dir = math.random() * math.pi * 2
            end
        end
        if a.aimAtPlayer then a.dir = atan2(S.py - a.y, S.px - a.x) end
        a.len = a.len or distanceToWall(a.x, a.y, a.dir)
        a.width = a.width or 24
    end,
    Resolve = function(a)
        local along, across = alongAcross(S.px, S.py, a.x, a.y, a.dir)
        -- Tested against the CONE, matching what is drawn. A rectangular
        -- test under a tapered drawing would clip people who were
        -- visibly outside it near the caster, which is the worst kind of
        -- unfair: the shape lied.
        if along >= 0 and along <= a.len
            and across <= a.width / 2 * coneFrac(along, a.len) then
            Hurt(a.damage or 25, a.name)
            if a.stack then AddStack(a.stack) end
        else
            Credit(a.name .. " avoided")
        end
        a.flashUntil = S.time + 0.22
        a.expireAt = a.flashUntil
    end,
    Draw = function(a, s)
        local live = a.flashUntil and S.time < a.flashUntil
        local p = castProgress(a)
        -- Telegraph in the school's colour, then flash red as it fires:
        -- while it is winding up the useful fact is what it is, and at
        -- the moment it lands the only useful fact is that it hurts.
        local col = live and C.bad or schoolOf(a, { 1, 0.85, 0.3 })
        local alpha = live and 0.85 or (0.14 + 0.22 * p)

        -- Drawn as a few widening segments rather than one bar, so it
        -- reads as a cone spreading from the caster. One uniform plank
        -- across the whole room looks like a wall and badly overstates
        -- how much floor the mechanic actually takes.
        -- Enough slices that the taper reads as an edge rather than as a
        -- staircase, and each one overlapping its neighbour so no seams
        -- show between them. Five was visibly stepped.
        local SEGMENTS = 16
        for i = 1, SEGMENTS do
            local t0 = (i - 1) / SEGMENTS * a.len
            local t1 = i / SEGMENTS * a.len
            local mid = (t0 + t1) * 0.5
            local w = a.width * coneFrac(mid, a.len)
            local tex = V(a, i, "OVERLAY", 1)
            tex:SetTexture(WHITE)
            tex:SetSize((t1 - t0 + 1.2) * s, w * s)
            tex:ClearAllPoints()
            tex:SetPoint("CENTER", arena, "CENTER",
                (a.x + math.cos(a.dir) * mid) * s,
                (a.y + math.sin(a.dir) * mid) * s)
            tex:SetVertexColor(col[1], col[2], col[3], alpha)
            tex:SetRotation(a.dir)
        end

        -- A dart at the caster end, pointing the way it will fire. The
        -- cone is symmetrical about its axis and does not say which end
        -- is the source.
        put(V(a, 17, "OVERLAY", 2), "dart", a.x, a.y, 9, s, col,
            live and 1 or 0.7, a.dir + SPRITE_FACING)
    end,
}

KINDS.beam = {
    Init = function(a)
        a.dir = a.dir or (math.random() * math.pi * 2)
        a.spin = (a.spin or 0.9) * (math.random() < 0.5 and -1 or 1)
        -- Same overshoot the frontals had. A sweeping beam recomputes it
        -- every frame instead of once, because the distance from its
        -- origin to the wall changes as it turns -- fixing it at spawn
        -- would be right in one direction and wrong in every other.
        a.len = a.len or distanceToWall(a.x, a.y, a.dir)
        a.width = a.width or 20
        a.expireAt = S.time + (a.life or 8)
        a.resolveAt = nil
    end,
    Tick = function(a, dt)
        a.dir = a.dir + a.spin * dt
        a.len = distanceToWall(a.x, a.y, a.dir)
        local along, across = alongAcross(S.px, S.py, a.x, a.y, a.dir)
        if along >= 0 and along <= a.len and across <= a.width / 2 then
            S.hp = math.max(0, S.hp - (a.dps or 30) * dt)
            S.flash = math.max(S.flash, 0.3)
            a.touched = true
        end
        if S.time > a.expireAt then
            a.dead = true
            -- Judged once, at the end: a sweeping beam is one mechanic
            -- lasting eight seconds, not eight separate ones.
            if a.touched then Hurt(0, a.name) else Credit(a.name .. " outrun") end
        end
    end,
    Draw = function(a, s)
        putBar(V(a, 1, "OVERLAY", 1), a.x, a.y, a.dir, a.len, a.width, s,
            schoolOf(a, C.beam), 0.75)
    end,
}

KINDS.wave = {
    Init = function(a)
        a.dir = a.dir or (math.random() * math.pi * 2)
        a.width = a.width or 16
        a.len = a.len or ARENA_R * 2.2
        a.speed = a.speed or 46
        a.x = -math.cos(a.dir) * (ARENA_R + 12)
        a.y = -math.sin(a.dir) * (ARENA_R + 12)
        a.travelled = 0
        a.resolveAt = nil
    end,
    Tick = function(a, dt)
        local step = a.speed * dt
        a.x = a.x + math.cos(a.dir) * step
        a.y = a.y + math.sin(a.dir) * step
        a.travelled = a.travelled + step
        local perp = a.dir + math.pi / 2
        local along, across = alongAcross(S.px, S.py, a.x, a.y, perp)
        if math.abs(along) <= a.len / 2 and across <= a.width / 2 and not a.hit then
            a.hit = true
            Hurt(a.damage or 16, a.name)
            if a.stack then AddStack(a.stack) end
        end
        if a.travelled > (ARENA_R * 2 + 24) then
            a.dead = true
            if not a.hit then Credit(a.name .. " dodged") end
        end
    end,
    Draw = function(a, s)
        -- Cut to the CHORD of the arena it is currently crossing, rather
        -- than a fixed length longer than the room. A wall that runs on
        -- past the floor and out over the window frame is the thing that
        -- made these unreadable: there was no telling where it ended, so
        -- there was no telling where to stand.
        local d = a.x * math.cos(a.dir) + a.y * math.sin(a.dir)
        local half = math.sqrt(math.max(ARENA_R * ARENA_R - d * d, 0))
        a.len = math.max(half * 2, 1)
        local t = V(a, 1, "OVERLAY", 1)
        t:SetTexture(WHITE)
        t:SetSize(a.len * s, a.width * s)
        t:ClearAllPoints()
        t:SetPoint("CENTER", arena, "CENTER", a.x * s, a.y * s)
        local col = schoolOf(a, C.wave)
        t:SetVertexColor(col[1], col[2], col[3], 0.8)
        t:SetRotation(a.dir + math.pi / 2)
    end,
}

------------------------------------------------------------
-- Enemies you shoot
--
-- The trainer used to kill an add by having the player stand on it,
-- which was a stand-in for damage and read as one. With a gun in the
-- game they have health and you shoot them, which is both the obvious
-- thing and the more honest one: it costs you the time you spend aimed
-- at the add rather than at the floor, which is the actual trade a real
-- pull asks you to make.
------------------------------------------------------------
local function DrawEnemy(a, s, art, col)
    local frac = a.hp / a.maxHp
    put(V(a, 1, "OVERLAY", 3), art, a.x, a.y, a.r * 2, s, col, 0.95,
        (a.spin or 0) * S.time)
    put(V(a, 2, "OVERLAY", 2), "ring", a.x, a.y, a.r * 2.5, s, col, 0.35)
    -- A health pip above it. Two textures: the track, then the fill.
    local bw, bh = a.r * 2.4, 1.4
    local by = a.y + a.r + 3
    local track = V(a, 3, "OVERLAY", 4)
    track:SetTexture(WHITE)
    track:SetSize(bw * s, bh * s)
    track:ClearAllPoints()
    track:SetPoint("CENTER", arena, "CENTER", a.x * s, by * s)
    track:SetVertexColor(0, 0, 0, 0.7)
    track:SetRotation(0)
    local fill = V(a, 4, "OVERLAY", 5)
    fill:SetTexture(WHITE)
    fill:SetSize(math.max(bw * frac, 0.01) * s, bh * s)
    fill:ClearAllPoints()
    fill:SetPoint("LEFT", arena, "CENTER", (a.x - bw / 2) * s, by * s)
    fill:SetVertexColor(1, 0.35, 0.3, 0.95)
    fill:SetRotation(0)
end

KINDS.chaser = {
    Init = function(a)
        a.speed = a.speed or 13
        a.r = a.r or 6
        a.maxHp = a.hp or 70
        a.hp = a.maxHp
        a.spin = 0.6
        a.resolveAt = nil
        a.expireAt = S.time + (a.life or 30)
        a.enemy = true
    end,
    Tick = function(a, dt)
        local gx, gy = 0, 0
        if a.goal == "player" then gx, gy = S.px, S.py end
        local d = dist(a.x, a.y, gx, gy)
        if d > 1 then
            a.x = a.x + (gx - a.x) / d * a.speed * dt
            a.y = a.y + (gy - a.y) / d * a.speed * dt
        end
        if a.goal ~= "player" and d <= (a.r + 4) then
            a.dead = true
            Hurt(a.damage or 30, a.name .. " reached the middle")
            if a.feeds and S.scenario and S.scenario.energy then
                S.energy = math.min((S.scenario.energy.max or 100),
                    S.energy + a.feeds)
            end
        elseif a.goal == "player" and dist(S.px, S.py, a.x, a.y) <= a.r + PLAYER_R then
            a.dead = true
            Hurt(a.damage or 26, a.name .. " reached you")
        elseif S.time > a.expireAt then
            a.dead = true
            Hurt(a.damage or 20, a.name .. " never died")
        end
    end,
    OnKilled = function(a)
        -- Silent when the raid got it on their own: not a pass, but not
        -- a miss either. The add was handled, just not by you.
        if a.playerHit then Credit(a.name .. " killed") end
        if a.leavesCorpse then AddCorpse(a.x, a.y) end
        -- One becomes two becomes four. Smaller and weaker each time, or
        -- the third wave is unkillable inside a sixty-second round.
        if a.splits and a.splits > 0 then
            for k = 1, 2 do
                Spawn({
                    kind = "chaser", name = a.name, school = a.school,
                    art = a.art, goal = a.goal, speed = (a.speed or 10) + 1,
                    hp = math.max(24, math.floor((a.maxHp or 90) * 0.55)),
                    r = math.max(3.6, (a.r or 6) * 0.78),
                    damage = math.max(10, (a.damage or 24) - 6),
                    life = a.life, splits = a.splits - 1,
                    where = { x = a.x + (k == 1 and -7 or 7), y = a.y },
                })
            end
        end
        if a.deathPuddle then
            Spawn({ kind = "puddle", name = a.name, school = a.school,
                    r = a.deathPuddle, life = 12, dps = 10,
                    where = { x = a.x, y = a.y } })
        end
    end,
    -- Tinted by school too, so Vashnik's Burning Venoms are visibly the
    -- fire adds rather than three purple blobs you have to name.
    Draw = function(a, s) DrawEnemy(a, s, a.art or "hex", schoolOf(a, C.add)) end,
}

KINDS.stalker = {
    Init = function(a)
        a.speed = a.speed or 15
        a.r = a.r or 5
        a.maxHp = a.hp or 90
        a.hp = a.maxHp
        a.spin = -0.5
        a.resolveAt = nil
        a.expireAt = S.time + (a.life or 14)
        a.enemy = true
    end,
    Tick = function(a, dt)
        -- Malacrass's spirits freeze while you look at them. There is no
        -- facing in a top-down arena, so the trainer swaps the input: it
        -- freezes while you STOP MOVING. Same lesson -- there is a thing
        -- you can do that stops it -- and now that the player has a gun
        -- it is a real trade rather than a curiosity, because standing
        -- still is also when you shoot best.
        if S.moving then
            local d = dist(a.x, a.y, S.px, S.py)
            if d > 1 then
                a.x = a.x + (S.px - a.x) / d * a.speed * dt
                a.y = a.y + (S.py - a.y) / d * a.speed * dt
            end
        end
        if dist(S.px, S.py, a.x, a.y) <= a.r + PLAYER_R then
            a.dead = true
            Hurt(a.damage or 30, a.name .. " caught you")
        elseif S.time > a.expireAt then
            a.dead = true
            Hurt(a.damage or 20, a.name .. " never died")
        end
    end,
    OnKilled = function(a)
        if a.playerHit then Credit(a.name .. " destroyed") end
    end,
    Draw = function(a, s)
        DrawEnemy(a, s, "blob", S.moving and schoolOf(a, C.add) or { 0.5, 0.75, 1 })
    end,
}

------------------------------------------------------------
-- projectile -- a thing that travels and pops on the first body
--
-- NOT a cone, and the difference matters. Possession Barrage "sends four
-- spirits out at the tank... each pops on the FIRST player it touches",
-- which is a completely different problem from a frontal: a cone is a
-- region you stand outside of, a projectile is an object whose path you
-- clear -- and one that stops at whoever it hits, so standing in it
-- takes the hit off somebody else and puts it on you.
--
-- This was drawn as a cone because the source data labelled it
-- "Frontal", which is raid-tools shorthand for "something aimed" rather
-- than a shape. Reading a shape out of that label is the mistake.
------------------------------------------------------------
KINDS.projectile = {
    Init = function(a)
        a.r = a.r or 4
        a.speed = a.speed or 58
        if not a.dir then
            local base = (S.bossActor and S.bossActor.facing) or TANK_ANGLE
            a.dir = base + (a.fan or 0)
        end
        a.travelled = 0
        a.resolveAt = nil
        -- A wind-up before it travels. Without one there is nothing to
        -- react to -- the spirits simply existed and were already moving
        -- -- and the tank has no moment in which to back off, which is
        -- the whole reason the mechanic reduces damage by distance.
        a.launchAt = S.time + (a.cast or 0)
    end,
    Tick = function(a, dt)
        if S.time < a.launchAt then return end
        local step = a.speed * dt
        a.x = a.x + math.cos(a.dir) * step
        a.y = a.y + math.sin(a.dir) * step
        a.travelled = a.travelled + step

        if dist(S.px, S.py, a.x, a.y) <= a.r + PLAYER_R then
            a.dead = true
            -- "Each one hits the whole raid harder the closer you are."
            -- Scaled by where it popped, so intercepting one early --
            -- next to the boss -- is worse than letting it run.
            local near = 1 - math.min(dist(a.x, a.y, 0, 0) / ARENA_R, 1)
            Hurt((a.damage or 20) * (0.6 + 0.8 * near), a.name .. " popped on you")
            return
        end
        if (a.x * a.x + a.y * a.y) > ARENA_R * ARENA_R or a.travelled > ARENA_R * 2.2 then
            a.dead = true
            Credit(a.name .. " let through")
        end
    end,
    Draw = function(a, s)
        local col = schoolOf(a, C.bad)
        if S.time < a.launchAt then
            -- Winding up: the dart sits on the caster with the lane it is
            -- about to take drawn faintly ahead of it, so the raid can
            -- clear that lane before it is a lane.
            local lead = distanceToWall(a.x, a.y, a.dir)
            putBar(V(a, 3, "OVERLAY", 1), a.x, a.y, a.dir, lead, a.r * 2.4, s,
                col, 0.20)
        end
        put(V(a, 1, "OVERLAY", 3), "dart", a.x, a.y, a.r * 3, s, col, 1,
            a.dir + SPRITE_FACING)
        -- A short tail, so the direction of travel reads while it moves.
        put(V(a, 2, "ARTWORK", 2), "ring", a.x, a.y, a.r * 3.4, s, col, 0.35)
    end,
}

------------------------------------------------------------
-- caster -- kill it before the cast lands
--
-- The interrupt, expressed as something a lone player in an arena can
-- actually do. A kick order is a raid-leader instruction and belongs in
-- the written guide; what a player DOES about it is drop everything and
-- burn the caster, and that is a decision about where your damage goes
-- under a deadline, which is exactly what this models.
------------------------------------------------------------
KINDS.caster = {
    Init = function(a)
        a.r = a.r or 5.5
        a.maxHp = a.hp or 110
        a.hp = a.maxHp
        a.castLen = a.castLen or 7
        a.castEnd = S.time + a.castLen
        a.enemy = true
        a.resolveAt = nil
        a.expireAt = nil
    end,
    Tick = function(a)
        if S.time >= a.castEnd then
            a.dead = true
            Hurt(a.damage or 30, a.name .. " finished casting")
        end
    end,
    OnKilled = function(a)
        if a.playerHit then
            Credit(a.name .. " interrupted")
        end
    end,
    Draw = function(a, s)
        local col = schoolOf(a, { 1, 0.85, 0.3 })
        local frac = a.hp / a.maxHp
        put(V(a, 1, "OVERLAY", 3), a.art or "hex", a.x, a.y, a.r * 2, s, col, 0.95,
            S.time * 0.5)
        -- Two bars: health above, cast progress below. The cast is the
        -- one the player is racing, so it is the wider and brighter of
        -- the two.
        local function bar(idx, yOff, w, frac2, r, g, b)
            local t = V(a, idx, "OVERLAY", 5)
            t:SetTexture(WHITE)
            t:SetSize(math.max(w * frac2, 0.01) * s, 1.6 * s)
            t:ClearAllPoints()
            t:SetPoint("LEFT", arena, "CENTER", (a.x - w / 2) * s, (a.y + yOff) * s)
            t:SetVertexColor(r, g, b, 0.95)
            t:SetRotation(0)
        end
        bar(2, a.r + 3, a.r * 2.4, frac, 1, 0.35, 0.3)
        bar(3, a.r + 6, a.r * 3.0, (a.castEnd - S.time) / a.castLen, 1, 0.8, 0.2)
    end,
}

------------------------------------------------------------
-- carry -- pick it up, take it somewhere
--
-- The Lost Explorers' fish, and every "move this object into position"
-- mechanic in the raid. Two beats rather than one: reach it, then get it
-- where it has to go before the timer -- which is the shape of a job
-- somebody in the raid is assigned, and the first mechanic here that
-- asks the player to do something OTHER than stand in the right place.
------------------------------------------------------------
KINDS.carry = {
    Init = function(a)
        a.r = a.r or 5
        a.held = false
        a.resolveAt = nil
        a.expireAt = S.time + (a.window or 16)
    end,
    Tick = function(a)
        if not a.held then
            if dist(S.px, S.py, a.x, a.y) <= a.r + PLAYER_R then
                a.held = true
                S.carrying = a
                callOut:SetTextColor(1, 0.9, 0.4)
                callOut:SetText(a.deliverCall or ("Carry the " .. a.name .. " to the boss"))
                S.callUntil = S.time + 2.5
            end
        else
            a.x, a.y = S.px, S.py
            local tx, ty = 0, 0
            if a.to == "boss" and S.bossActor then
                tx, ty = S.bossActor.x, S.bossActor.y
            elseif a.to == "front" and S.bossActor then
                -- In FRONT of the boss, along its facing -- which is
                -- where the tank's cone goes. "Carry them into a pile
                -- and let the tank clear several with one cone" is the
                -- guide's instruction, and this is that pile: it moves
                -- as the boss turns, so the player has to keep track of
                -- where the cone will actually be rather than dropping
                -- them wherever is nearest.
                local f = S.bossActor.facing or 0
                tx = S.bossActor.x + math.cos(f) * (a.frontDist or 34)
                ty = S.bossActor.y + math.sin(f) * (a.frontDist or 34)
            end
            if dist(S.px, S.py, tx, ty) <= (a.reach or 18) then
                a.dead = true
                S.carrying = nil
                Credit(a.name .. " delivered")
                -- What delivering it is FOR. The mechanic is only worth
                -- carrying because of this.
                if a.drainEnergy then
                    S.energy = math.max(0, S.energy - a.drainEnergy)
                end
            end
        end
        if S.time > a.expireAt then
            a.dead = true
            if S.carrying == a then S.carrying = nil end
            Hurt(a.damage or 20, a.name .. " was lost")
        end
    end,
    Draw = function(a, s)
        local col = schoolOf(a, { 0.4, 0.9, 1 })
        put(V(a, 1, "OVERLAY", 4), "star", a.x, a.y, a.r * 2.4, s, col, 1, S.time * 2)
        if a.held then
            -- Where it has to go, drawn only while you are holding it.
            local tx, ty = 0, 0
            if a.to == "boss" and S.bossActor then
                tx, ty = S.bossActor.x, S.bossActor.y
            elseif a.to == "front" and S.bossActor then
                local fa = S.bossActor.facing or 0
                tx = S.bossActor.x + math.cos(fa) * (a.frontDist or 34)
                ty = S.bossActor.y + math.sin(fa) * (a.frontDist or 34)
            end
            put(V(a, 2, "ARTWORK", 2), "ring", tx, ty, (a.reach or 18) * 2, s, col, 0.8)
            put(V(a, 3, "ARTWORK", 1), "swirl", tx, ty, (a.reach or 18) * 1.6, s,
                col, 0.55, S.time * 1.8)
        else
            local left = math.max((a.expireAt - S.time) / (a.window or 16), 0)
            put(V(a, 2, "ARTWORK", 2), "ring", a.x, a.y,
                a.r * 2 * (1 + 1.8 * left), s, col, 0.6)
        end
    end,
}

------------------------------------------------------------
-- orb -- touch it before it expires
------------------------------------------------------------
KINDS.orb = {
    Init = function(a)
        a.r = a.r or 4.5
        a.expireAt = S.time + (a.window or 9)
        a.resolveAt = nil
    end,
    Tick = function(a)
        if dist(S.px, S.py, a.x, a.y) <= a.r + PLAYER_R then
            a.dead = true
            Credit(a.name .. " collected")
            if a.stack then AddStack(a.stack) end
            if a.spikes then
                -- Fires from where it was popped, at the boss. So WHERE
                -- you clear one matters as much as whether you do.
                local bx, by = 0, 0
                if S.bossActor then bx, by = S.bossActor.x, S.bossActor.y end
                Spawn({
                    kind = "line", name = a.name .. " spike", school = a.school,
                    where = { x = a.x, y = a.y }, dir = atan2(by - a.y, bx - a.x),
                    cast = 1.4, width = 14, damage = 16,
                })
            end
            return
        end
        -- The raid can clear them too, and has to: an ally sent on box
        -- duty that walked to a box and then stood next to it would look
        -- broken. Silent -- no credit and no miss -- because the player
        -- did not do it, which is the same rule add kills follow.
        for _, ally in ipairs(S.allies) do
            if ally.orbTarget == a and dist(ally.x, ally.y, a.x, a.y) <= a.r + ALLY_R then
                a.dead = true
                return
            end
        end
        if S.time > a.expireAt then
            a.dead = true
            Hurt(a.damage or 14, a.name .. " expired")
            -- Leaving one is a stack too, and the guide is explicit that
            -- it is a stack for the WHOLE raid rather than just for the
            -- person who ignored it. So there is no way to dodge the
            -- stack -- only a choice between taking it cleanly and taking
            -- it along with the damage. That is the mechanic, and without
            -- this the poison meter could never actually reach its cap.
            if a.stack then AddStack(a.stack) end
        end
    end,
    Draw = function(a, s)
        local left = math.max((a.expireAt - S.time) / (a.window or 9), 0)
        put(V(a, 1, "OVERLAY", 3), "star", a.x, a.y, a.r * 2.4, s,
            schoolOf(a, C.orb), 0.95, S.time * 1.4)
        -- The closing ring stays orb-yellow whatever the school: it is
        -- the "collect me" signal, not part of what the thing is.
        put(V(a, 2, "ARTWORK", 2), "ring", a.x, a.y, a.r * 2 * (1 + 1.6 * left), s,
            C.orb, 0.6)
    end,
}

------------------------------------------------------------
-- refuge -- everywhere hurts except these
------------------------------------------------------------
KINDS.refuge = {
    Init = function(a)
        a.spots = {}
        for i = 1, (a.count or 3) do
            local x, y = randomPoint(28)
            a.spots[i] = { x = x, y = y }
        end
        a.r = a.r or 11
    end,
    Resolve = function(a)
        local safe = false
        for _, sp in ipairs(a.spots) do
            if dist(S.px, S.py, sp.x, sp.y) <= a.r then safe = true break end
        end
        if safe then Credit(a.name .. " survived") else Hurt(a.damage or 35, a.name) end
        a.flashUntil = S.time + 0.3
        a.expireAt = a.flashUntil
    end,
    Draw = function(a, s)
        for i, sp in ipairs(a.spots) do
            put(V(a, i * 2 - 1, "ARTWORK", 0), "disc", sp.x, sp.y, a.r * 2, s,
                C.good, 0.3)
            put(V(a, i * 2, "ARTWORK", 2), "ring", sp.x, sp.y, a.r * 2, s, C.good, 1)
        end
        -- The floor reddening as the cast completes is the warning that
        -- everything outside those circles is about to be lethal.
        local p = castProgress(a)
        floorTex:SetVertexColor(0.07 + 0.35 * p, 0.07, 0.09, 1)
    end,
    Cleanup = function() floorTex:SetVertexColor(0.07, 0.07, 0.09, 1) end,
}

------------------------------------------------------------
-- spread / stack -- where you stand relative to people
------------------------------------------------------------
KINDS.spread = {
    Init = function(a)
        -- Two others get it too, and only those two move. See
        -- AssignRunOut for why this is not everybody. No puddle: Plague
        -- Rot and Blink Nova fire waves outward, they do not leave
        -- ground behind. A short reach, because a spread wants
        -- separation and not an evacuation.
        AssignRunOut(2, a.cast or 3, false, (a.minDist or 24) * 2.0, a.name)
    end,
    Resolve = function(a)
        if NearestAllyDist() >= (a.minDist or 24) then
            Credit(a.name .. " spread")
        else
            Hurt(a.damage or 20, a.name .. " clipped the raid")
        end
    end,
    Draw = function(a, s)
        local p = castProgress(a)
        local col = schoolOf(a, { 1, 0.6, 0.2 })
        -- DIAMETER equal to the required separation, so each ring has a
        -- radius of half of it.
        --
        -- This was drawn at twice the size, which was not just too big --
        -- it made the rings a worse instruction than no rings at all.
        -- Sized like this, two people are correctly spread exactly when
        -- their circles do not touch, which is how every WoW player
        -- already reads a spread marker. The picture and the rule become
        -- the same thing and nothing has to be explained.
        local d = (a.minDist or 24)
        put(V(a, 1, "ARTWORK", 2), "ring", S.px, S.py, d, s, col, 0.4 + 0.5 * p)
        -- And one on every ally carrying the same debuff.
        --
        -- Without this, a mechanic that lands on several people looked
        -- like it had landed only on the player, and the allies wandering
        -- off looked unmotivated. Seeing three circles is what makes it
        -- read as "we all got this, everybody separate" -- which is the
        -- thing the mechanic is actually asking.
        local slot = 1
        for _, ally in ipairs(S.allies) do
            if ally.runOut and ally.runOutTag == a.name then
                slot = slot + 1
                put(V(a, slot, "ARTWORK", 2), "ring", ally.x, ally.y, d, s, col,
                    0.30 + 0.35 * p)
            end
        end
    end,
}

KINDS.stack = {
    Resolve = function(a)
        if a.atCentre then
            -- Judged against the middle of the room, not against the
            -- group. On Sszorak the raid stacking somewhere is not the
            -- mechanic; the raid stacking THERE is.
            if dist(S.px, S.py, 0, 0) <= (a.maxDist or 16) then
                Credit(a.name .. " -- stacked in the middle")
            else
                Hurt(a.damage or 24, a.name .. " -- you were not in the middle")
            end
            return
        end
        if NearestAllyDist() <= (a.maxDist or 16) then
            Credit(a.name .. " stacked")
        else
            Hurt(a.damage or 24, a.name .. " -- you were not stacked")
        end
    end,
    Draw = function(a, s)
        local p = castProgress(a)
        local d = (a.maxDist or 16) * 2
        local cx, cy = RaidCentre()
        if a.atCentre then cx, cy = 0, 0 end
        put(V(a, 1, "ARTWORK", 0), "disc", cx, cy, d * p, s, C.good, 0.18)
        put(V(a, 2, "ARTWORK", 2), "ring", cx, cy, d, s, C.good, 0.4 + 0.5 * p)
    end,
}

------------------------------------------------------------
-- meet -- reach one specific person
------------------------------------------------------------
KINDS.meet = {
    Init = function(a)
        for _, ally in ipairs(S.allies) do
            ally.marked = false; ally.label = nil
            -- Held for the duration. See AllyGoal: this mechanic asks
            -- the PLAYER to reach a specific ally, and an ally that
            -- keeps walking turns a reaction test into a chase.
            ally.hold = true
        end
        a.target = S.allies[math.random(#S.allies)]
        a.target.marked = true
        if a.labels then
            -- The Sentinels puzzle: your number plus theirs must make
            -- four. Everyone else gets a number that does not work, so
            -- the answer is arithmetic rather than "follow the glow".
            a.mine = math.random(1, 3)
            a.target.label = tostring(4 - a.mine)
            for _, ally in ipairs(S.allies) do
                if not ally.marked then
                    local wrong = math.random(1, 3)
                    if wrong == 4 - a.mine then wrong = (wrong % 3) + 1 end
                    ally.label = tostring(wrong)
                end
            end
            a.target.marked = false
        end
    end,
    Resolve = function(a)
        local tx, ty = AllyPos(a.target)
        if dist(S.px, S.py, tx, ty) <= (a.reach or 9) then
            Credit(a.name .. " -- correct partner")
        else
            Hurt(a.damage or 22, a.name)
        end
    end,
    Cleanup = function()
        for _, ally in ipairs(S.allies) do
            ally.marked = false; ally.label = nil; ally.hold = false
        end
    end,
    Draw = function(a, s)
        local tx, ty = AllyPos(a.target)
        put(V(a, 1, "ARTWORK", 2), "ring", tx, ty, (a.reach or 9) * 2, s,
            { 0.4, 0.8, 1 }, a.labels and 0.25 or 0.9)
    end,
}

------------------------------------------------------------
-- tax -- a stack you cannot avoid
--
-- The one exception to "everything is avoidable", and it earns it. Twin
-- Fangs applies a poison stack to the whole raid on a timer, and the
-- entire fight is built on top of that: the reason you must not waste a
-- soak is that the meter is filling whether you play well or not.
-- Modelling the soak without the pressure would teach the wrong fight.
--
-- Scored as neither a pass nor a miss, because the player did not do
-- anything either way. What it does is make the clears matter.
------------------------------------------------------------
KINDS.tax = {
    Init = function(a) a.resolveAt = S.time end,
    Resolve = function(a)
        AddStack(a.stack or 1)
        callOut:SetTextColor(0.75, 1, 0.4)
        callOut:SetText(a.name .. " -- everyone gains a stack")
        S.callUntil = S.time + 1.4
    end,
}

------------------------------------------------------------
-- place -- put the thing where it has to go
--
-- Venomous Surge, done properly. The debuff is not the mechanic; WHERE
-- you are standing when it ends is, and the right place is a marker
-- across the room from a tunnel you were supposed to have read.
--
-- The first half of a mechanic whose second half arrives a minute later
-- in the intermission, which is why it was worth building rather than
-- collapsing into another "walk away from the raid".
------------------------------------------------------------
KINDS.place = {
    Init = function(a)
        -- The lowest-order tunnel still without a cyst, so the player is
        -- walked through them in the order they will blow.
        for step = 1, 3 do
            local t = TunnelByOrder(step)
            if t and not t.cyst then a.tunnel = t break end
        end
    end,
    Resolve = function(a)
        local t = a.tunnel
        if not t then return end
        if dist(S.px, S.py, t.cx, t.cy) <= CYST_REACH then
            t.cyst = true
            Credit("Cyst placed opposite tunnel " .. t.order)
        else
            Hurt(a.damage or 22, a.name .. " -- cyst dropped in the wrong place")
        end
    end,
    Draw = function(a, s)
        local t = a.tunnel
        if not t then return end
        local p = castProgress(a)
        -- The target, and the tunnel it belongs to, lit together. The
        -- pairing is the lesson.
        put(V(a, 1, "ARTWORK", 2), "ring", t.cx, t.cy, CYST_REACH * 2, s,
            { 0.5, 1, 0.6 }, 0.5 + 0.5 * p)
        put(V(a, 2, "ARTWORK", 1), "swirl", t.cx, t.cy, CYST_REACH * 1.7, s,
            { 0.5, 1, 0.6 }, 0.6, S.time * 2)
        put(V(a, 3, "ARTWORK", 2), "ring", t.x, t.y, 26, s, { 1, 0.85, 0.4 }, 0.9)
        put(V(a, 4, "ARTWORK", 2), "ring", S.px, S.py, 12, s, { 0.5, 1, 0.6 }, 0.7)
    end,
}

------------------------------------------------------------
-- wind -- the payoff
--
-- One tunnel blows, and the only safe place is the cyst opposite it. A
-- tunnel whose cyst was never placed has no safe place at all, which is
-- the honest consequence and the reason the placement phase matters.
------------------------------------------------------------
KINDS.wind = {
    Init = function(a)
        a.tunnel = TunnelByOrder(a.step or 1)
        S.windStep = a.step or 1
    end,
    Resolve = function(a)
        local t = a.tunnel
        if not t then return end
        if not t.cyst then
            Hurt(a.damage or 36, "No cyst opposite tunnel " .. t.order)
        elseif dist(S.px, S.py, t.cx, t.cy) <= CYST_REACH + 3 then
            Credit("Wind " .. t.order .. " -- rode the cyst")
        else
            Hurt(a.damage or 36, "Wind " .. t.order .. " -- you were not on the cyst")
        end
    end,
    Cleanup = function() S.windStep = nil end,
    Draw = function(a, s)
        local t = a.tunnel
        if not t then return end
        local p = castProgress(a)
        -- A bar from the tunnel across the room, so which way it blows
        -- is something you can see rather than something you remember.
        putBar(V(a, 1, "OVERLAY", 1), t.x, t.y,
            atan2(-t.y, -t.x), TUNNEL_R + CYST_R, 18, s,
            { 0.6, 0.85, 1 }, 0.18 + 0.3 * p)
        local col = t.cyst and { 0.5, 1, 0.6 } or { 1, 0.35, 0.3 }
        put(V(a, 2, "ARTWORK", 2), "ring", t.cx, t.cy, CYST_REACH * 2, s, col, 1)
    end,
}

------------------------------------------------------------
-- imbibe -- the altars pay out
--
-- Not scored. The player did not pass or fail anything by standing
-- somewhere; they chose what the next twenty seconds will be made of,
-- and the consequence IS the score, arriving later as adds they either
-- handle or do not.
------------------------------------------------------------
KINDS.imbibe = {
    Resolve = function(a)
        local order = RankAltars()
        if not order then return end
        local lit = {}
        for _, e in ipairs(order) do
            local alt = e.alt
            if alt.stacks > 0 then
                lit[#lit + 1] = ("%s +%d"):format(alt.name, alt.stacks)
                if alt.school == "fire" then
                    -- Pulse damage while alive and a hit when they die,
                    -- so they must be taken one at a time.
                    for k = 1, alt.stacks + 1 do
                        Spawn({
                            kind = "chaser", name = "Burning Venom",
                            school = "fire", art = "blob", goal = "player",
                            speed = 8, hp = 72, r = 5.5, damage = 22, life = 18,
                            deathPuddle = 10,
                            where = { x = alt.x + (k - 2) * 9, y = alt.y },
                        })
                    end
                elseif alt.school == "shadow" then
                    for k = 1, alt.stacks do
                        Spawn({
                            kind = "dodge", name = "Shadow spray",
                            school = "shadow", cast = 2.4, r = 14, damage = 18,
                            leaves = { r = 16, life = 20, dps = 12 },
                        })
                    end
                elseif alt.school == "blood" then
                    -- The splitting add. One becomes two becomes four,
                    -- and none of them can be slowed or stunned.
                    Spawn({
                        kind = "chaser", name = "Blood Fragment",
                        school = "blood", art = "hex", goal = "player",
                        speed = 10, hp = 90, r = 6, damage = 24, life = 22,
                        splits = alt.stacks,
                        where = { x = alt.x, y = alt.y },
                    })
                end
            end
        end
        if #lit > 0 then
            callOut:SetTextColor(1, 0.75, 0.3)
            callOut:SetText("Imbibe: " .. table.concat(lit, "  "))
            S.callUntil = S.time + 2.2
        end
    end,
    Draw = function(a, s)
        -- A ring gathering on each lit altar while it channels.
        if not S.altars then return end
        local slot = 0
        local p = castProgress(a)
        for _, alt in ipairs(S.altars) do
            if alt.stacks > 0 then
                slot = slot + 1
                put(V(a, slot, "ARTWORK", 2), "swirl", alt.x, alt.y,
                    30 - 12 * p, s, SCHOOL[alt.school] or C.add, 0.85,
                    S.time * 2.5)
            end
        end
    end,
}

------------------------------------------------------------
-- The boss
------------------------------------------------------------

local function SetupBoss(sc)
    -- Off the middle when the middle is a mechanic. Nek'zali is tanked
    -- at the entrance precisely because nothing may stand in the Soul
    -- Well -- and a boss parked on top of it put the whole raid there
    -- too, which is the one thing the fight forbids.
    local sx, sy = 0, 0
    if sc.well then sx, sy = 0, 46 end
    if sc.bossStart then sx, sy = sc.bossStart.x, sc.bossStart.y end
    S.bossActor = {
        x = sx, y = sy,
        maxHp = sc.bossHp or 1400,
        hp = sc.bossHp or 1400,
        r = 13,
    }
end

local function DrawBoss(s)
    local b = S.bossActor
    if not b then
        bossSkull:Hide(); bossFace:Hide(); bossGaze:Hide()
        return
    end
    local f = b.facing or 0
    local phase = CurrentPhase()
    local immune = phase and phase.bossImmune

    -- The gaze first, so the skull and the arrow both sit on top of it.
    -- Short and faint: it says which way, not how far -- the cone's real
    -- length is the frontal's business and drawing it here would be a
    -- permanent telegraph for a mechanic that is not casting.
    local reach = 34
    putBar(bossGaze, b.x, b.y, f, reach, 7, s, C.boss, 0.16)

    if immune then
        -- Greyed and behind a turning ward, because "your damage is
        -- doing nothing right now" is the single most useful thing the
        -- screen can say during an intermission -- and a boss that
        -- merely stopped losing health said it far too quietly.
        put(bossSkull, "skull", b.x, b.y, b.r * 2.2, s, { 0.62, 0.66, 0.74 }, 0.85)
        put(bossWard, "swirl", b.x, b.y, b.r * 3.4, s, { 0.55, 0.75, 1.0 },
            0.75, S.time * 1.4)
        put(bossWardRing, "ring", b.x, b.y, b.r * 3.4, s, { 0.55, 0.75, 1.0 }, 0.85)
        bossFace:Hide()
        bossGaze:Hide()
    else
        bossWard:Hide()
        bossWardRing:Hide()
        put(bossSkull, "skull", b.x, b.y, b.r * 2.2, s, { 1, 0.93, 0.90 }, 1)
        put(bossFace, "dart", b.x + math.cos(f) * (b.r + 6),
            b.y + math.sin(f) * (b.r + 6), 12, s, C.boss, 1, f + SPRITE_FACING)
    end
end

------------------------------------------------------------
-- Shooting
------------------------------------------------------------
local shotPool = {}

--- Assigned to the forward declaration above the raid AI, which fires
--- these too. Damage rides on the shot rather than being a constant,
--- because an ally's round is worth half of the player's -- six of them
--- shooting at a shared constant would make the player a spectator at
--- their own boss.
function FireShot(x, y, dir, damage, friendly)
    local shot = table.remove(shotPool) or {}
    shot.x, shot.y = x, y
    shot.dir = dir
    shot.damage = damage or SHOT_DAMAGE
    shot.friendly = friendly
    shot.life = SHOT_LIFE
    shot.tex = shot.tex or arena:CreateTexture(nil, "OVERLAY", nil, 5)
    shot.tex:SetTexture(ART.dart)
    -- Deliberately NOT shown here. UpdateShots reveals it once it has a
    -- position; a sprite that is visible before anything has placed it
    -- draws wherever it happened to be last.
    shot.tex:Hide()
    S.shots[#S.shots + 1] = shot
end

--- Every live thing a bullet can hit, boss included.
local function HitScan(shot)
    local b = S.bossActor
    local phase = S.phases and S.phases[S.phaseIndex]
    if phase and phase.bossImmune then b = nil end
    if b and b.hp > 0 and dist(shot.x, shot.y, b.x, b.y) <= b.r + SHOT_R then
        -- A phase's health floor. Damage stops at it, exactly as a real
        -- encounter does -- you burn the boss to the transition and it
        -- goes there, you do not skip the intermission by hitting hard.
        --
        -- Without this the whole rebuild was decorative: with the trigger
        -- held, phase one killed the boss outright and every later phase
        -- was unreachable, in a round that still looked completely
        -- normal from the outside.
        local floor = ((phase and phase.hpFloor) or 0) / 100 * b.maxHp
        b.hp = math.max(floor, b.hp - shot.damage)
        return true
    end
    for _, a in ipairs(S.actors) do
        if a.enemy and not a.dead and dist(shot.x, shot.y, a.x, a.y) <= a.r + SHOT_R then
            a.hp = a.hp - shot.damage
            -- Remembered so the kill can be attributed. Now that six
            -- allies also shoot adds, crediting the player for every add
            -- that happens to die would hand out a rising score to
            -- somebody who never fired -- which is exactly the free pass
            -- the harness's "a motionless player missed nothing" check
            -- exists to catch.
            if not shot.friendly then a.playerHit = true end
            if a.hp <= 0 then
                a.dead = true
                local kind = KINDS[a.kind]
                if kind and kind.OnKilled then kind.OnKilled(a) end
            end
            return true
        end
    end
    return false
end

local function UpdateShots(dt, s)
    if S.firing then
        S.fireCd = S.fireCd - dt
        if S.fireCd <= 0 then
            FireShot(S.px, S.py, S.aim, SHOT_DAMAGE, false)
            S.fireCd = FIRE_COOLDOWN
        end
    else
        S.fireCd = 0
    end

    for i = #S.shots, 1, -1 do
        local shot = S.shots[i]
        shot.x = shot.x + math.cos(shot.dir) * SHOT_SPEED * dt
        shot.y = shot.y + math.sin(shot.dir) * SHOT_SPEED * dt
        shot.life = shot.life - dt

        local gone = shot.life <= 0
            or (shot.x * shot.x + shot.y * shot.y) > ARENA_R * ARENA_R
            or HitScan(shot)

        if gone then
            shot.tex:Hide()
            table.remove(S.shots, i)
            shotPool[#shotPool + 1] = shot
        else
            if shot.friendly then
                put(shot.tex, "dart", shot.x, shot.y, SHOT_R * 2, s, C.ally, 0.7,
                    shot.dir + SPRITE_FACING)
            else
                put(shot.tex, "dart", shot.x, shot.y, SHOT_R * 3, s, C.shot, 1,
                    shot.dir + SPRITE_FACING)
            end
            shot.tex:Show()
        end
    end
end

local function ClearShots()
    for _, shot in ipairs(S.shots) do
        shot.tex:Hide()
        shotPool[#shotPool + 1] = shot
    end
    wipe(S.shots)
end

------------------------------------------------------------
-- Input
------------------------------------------------------------
local held = {}
local MOVE = {
    W = { 0, 1 }, S = { 0, -1 }, A = { -1, 0 }, D = { 1, 0 },
    UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 },
}

f:EnableKeyboard(true)
f:SetPropagateKeyboardInput(true)

f:SetScript("OnKeyDown", function(self, key)
    -- Only OUR keys, and only while a round is live. Everything else --
    -- Escape, chat, every ability binding -- passes straight through,
    -- which is the whole reason this is safe to leave open in a raid.
    local capture = MOVE[key] and S.running and not S.paused
    self:SetPropagateKeyboardInput(not capture)
    if capture then held[key] = true end
end)

f:SetScript("OnKeyUp", function(self, key)
    -- Swallowed if and only if the down was. Letting one through without
    -- the other is how a frame leaves the client believing a key is
    -- still held.
    local capture = MOVE[key] and held[key] or false
    self:SetPropagateKeyboardInput(not capture)
    held[key] = nil
end)

arena:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then S.firing = true end
end)
arena:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" then S.firing = false end
end)

local function ReleaseInput()
    wipe(held)
    S.firing = false
    S.moving = false
end

f:SetScript("OnShow", function() tinsert(UISpecialFrames, "YippYappRaidTrainer") end)
f:SetScript("OnHide", function()
    T:Stop()
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "YippYappRaidTrainer" then
            table.remove(UISpecialFrames, i)
            break
        end
    end
end)

--- Where the mouse is, in arena units.
local function CursorArena()
    local mx, my = GetCursorPosition()
    local es = arena:GetEffectiveScale() or 1
    local acx, acy = arena:GetCenter()
    if not acx then return 0, 0 end
    local s = scale()
    return (mx / es - acx) / s, (my / es - acy) / s
end

local function MovePlayer(dt)
    local dx, dy = 0, 0
    for key in pairs(held) do
        local v = MOVE[key]
        if v then dx, dy = dx + v[1], dy + v[2] end
    end

    S.moving = (dx ~= 0 or dy ~= 0)
    if S.moving then
        -- Normalised, so holding two keys is not a 41% speed bonus on
        -- the diagonal. Every twin-stick game that skips this ends up
        -- being played entirely diagonally.
        local len = math.sqrt(dx * dx + dy * dy)
        S.px = S.px + dx / len * PLAYER_SPEED * dt
        S.py = S.py + dy / len * PLAYER_SPEED * dt
        S.px, S.py = clampToArena(S.px, S.py, PLAYER_R)
    end

    local cx, cy = CursorArena()
    local adx, ady = cx - S.px, cy - S.py
    -- Aim only updates when the cursor is meaningfully off the player,
    -- or the ship spins wildly whenever they walk over their own cursor.
    if (adx * adx + ady * ady) > 1 then S.aim = atan2(ady, adx) end
end

------------------------------------------------------------
-- Drawing the cast
------------------------------------------------------------
local function DrawDots(s)
    local r, g, b = 1, 1, 1
    local _, classFile = UnitClass("player")
    local cc = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
    if cc and cc.r then r, g, b = cc.r, cc.g, cc.b end

    put(playerTex, "ship", S.px, S.py, PLAYER_R * 3.2, s, { r, g, b }, 1,
        S.aim + SPRITE_FACING)
    put(playerRing, "ring", S.px, S.py, PLAYER_R * 3.6, s, { 1, 1, 1 }, 0.55)

    for i, a in ipairs(S.allies) do
        local t = allyTex[i]
        -- State beats role: somebody who has just eaten something, or
        -- is carrying a mechanic, needs to read as THAT first.
        local col = ROLE_TINT[a.role] or C.ally
        if a.marked then
            col = { 0.4, 0.85, 1 }
        elseif a.stagger > 0 then
            col = { 1, 0.45, 0.4 }
        elseif a.runOut then
            col = { 0.9, 0.6, 1 }
        end
        -- Upright, never rotated.
        --
        -- These carry internal detail -- a crossguard, a bowstring, the
        -- shoulders of a shield -- and SetRotation distorts art with
        -- detail in a way it cannot distort a solid arrow. The role is
        -- the information; where an ally is aiming is not, and the
        -- player keeps the one rotating sprite so their own facing still
        -- reads.
        put(t, ROLE_ART[a.role] or "hex", a.x, a.y, ALLY_R * 3.1, s, col, 0.95)
        t.label:SetPoint("CENTER", arena, "CENTER", a.x * s, a.y * s + 13)
        t.label:SetText(a.label or "")
    end

    -- The badge follows the player, so it is read where they are looking.
    local carried, soonest = nil, nil
    for name, expiry in pairs(S.debuffs) do
        if expiry > S.time and (not soonest or expiry < soonest) then
            carried, soonest = name, expiry
        end
    end
    if carried then
        debuffText:SetPoint("CENTER", arena, "CENTER",
            S.px * s, (S.py + PLAYER_R * 4) * s)
        debuffText:SetText(("|cffffcc44%s %.0f|r"):format(carried, soonest - S.time))
        debuffText:Show()
    else
        debuffText:Hide()
    end

    if S.scenario and S.scenario.well then
        put(wellTex, "ring", 0, 0, 18, s, C.well, 0.9, -S.time * 0.6)
    else
        wellTex:Hide()
    end

    DrawCorpses(s)
    DrawAltars(s)
    DrawTunnels(s)
    DrawBoss(s)
end

------------------------------------------------------------
-- The loop
------------------------------------------------------------
-- Forward-declared: EnterPhase clears the field, and ClearActors is
-- built with the control functions at the foot of the file. Third time
-- this file has needed one of these, and every time the symptom is a nil
-- global thrown from somewhere unrelated.
local ClearActors

--- Move into phase `i`, clearing what the last one left behind.
---
--- Telegraphs and adds go; the phase that spawned them is over and a
--- cast resolving into a phase that no longer exists is a mechanic from
--- nowhere. Ground effects go with them, because every one of these
--- fights resets its floor at a phase boundary.
local function EnterPhase(i)
    -- What the Ritual raises, worked out BEFORE the field is cleared and
    -- spawned AFTER it.
    --
    -- Spawning them here and then calling ClearActors below deleted them
    -- in the same breath -- eight bodies went in, nothing came out, and
    -- the phase looked exactly as it should from the outside. The count
    -- has to survive the clear even though the actors cannot.
    local raise = 0
    local leaving = S.phases and S.phases[S.phaseIndex]
    if leaving and leaving.raisesCorpses and #S.corpses > 0 then
        raise = #S.corpses
    end

    S.phaseIndex = i
    S.phaseTime = 0
    S.nextEvent = 1
    ClearActors()

    if raise > 0 then
        -- One add back on its feet per body nobody burned, from where it
        -- fell, walking at the well again.
        for _, c in ipairs(S.corpses) do
            Spawn({
                kind = "chaser", name = "Raised Amani", school = "shadow",
                goal = "centre", speed = 12, hp = 60, art = "hex",
                damage = 26, feeds = 5, leavesCorpse = true,
                where = { x = c.x, y = c.y },
            })
        end
        wipe(S.corpses)
        Hurt(0, ("%d corpse%s raised -- they were never burned"):format(
            raise, raise == 1 and "" or "s"))
    end

    local p = CurrentPhase()
    if p then
        phaseText:SetTextColor(1, 0.85, 0.35)
        phaseText:SetText(p.name or "")
        if p.call then
            callOut:SetTextColor(1, 0.85, 0.3)
            callOut:SetText(p.call)
            S.callUntil = S.time + 3
        end
    end
end

local function Finish(victory)
    S.running = false
    ReleaseInput()
    -- Cleared here rather than left to decay, because the loop that
    -- decays it is the one that just stopped.
    S.flash = 0
    hurt:SetVertexColor(1, 0, 0, 0)
    countText:SetText("")
    local total = S.passed + S.failed
    local pct = total > 0 and math.floor(S.passed / total * 100) or 0
    if victory then
        bigText:SetTextColor(0.4, 1, 0.5)
        bigText:SetText("VICTORY")
    elseif S.hp <= 0 then
        bigText:SetTextColor(1, 0.35, 0.3)
        bigText:SetText("DEAD")
    elseif pct >= 90 then
        bigText:SetTextColor(0.4, 1, 0.5)
        bigText:SetText("CLEAN")
    else
        bigText:SetTextColor(1, 0.85, 0.3)
        bigText:SetText("SURVIVED")
    end
    local b = S.bossActor
    resultText:SetText(("%d of %d mechanics handled  (%d%%)\nYour health: %d%%   Boss: %d%%")
        :format(S.passed, total, pct, math.floor(S.hp),
            b and math.floor(b.hp / b.maxHp * 100) or 0))
    callOut:SetText("")
end

local function Update(_, elapsed)
    if not S.running then return end

    if S.paused then
        -- The keys are given back on the way in, so the player can
        -- actually fight whatever pulled them into combat.
        ReleaseInput()
        bigText:SetTextColor(1, 0.85, 0.3)
        bigText:SetText("PAUSED")
        resultText:SetText("You are in combat. The trainer waits.")
        return
    end

    local s = scale()

    if S.countdown > 0 then
        S.countdown = S.countdown - elapsed
        local n = math.ceil(S.countdown)
        countText:SetTextColor(1, 1, 1)
        countText:SetText(n > 0 and tostring(n) or "|cff66ff88GO|r")
        MovePlayer(elapsed)
        UpdateBossPosition(elapsed)
        UpdateAllies(elapsed)
        DrawDots(s)
        return
    end
    countText:SetText("")
    bigText:SetText("")
    resultText:SetText("")

    S.time = S.time + elapsed
    S.phaseTime = S.phaseTime + elapsed
    TickEnergy(elapsed)
    MovePlayer(elapsed)

    UpdateBossPosition(elapsed)
    UpdateAllies(elapsed)
    TickAllyTimers()
    RankAltars()

    local phase = CurrentPhase()
    local events = (phase and phase.events) or {}
    -- Event times are relative to the PHASE, not the round, so a phase
    -- reads as its own script and can be reordered or retimed without
    -- renumbering everything after it.
    while S.nextEvent <= #events and events[S.nextEvent].at <= S.phaseTime do
        local ev = events[S.nextEvent]
        S.nextEvent = S.nextEvent + 1
        -- Both directions. Some mechanics are heroic additions, and some
        -- are the EASIER normal version of a heroic one -- five mushrooms
        -- instead of three -- so one timeline needs to be able to drop an
        -- event either way.
        local skip = (ev.heroicOnly and not S.heroic) or (ev.normalOnly and S.heroic)
        if not skip then Spawn(ev) end
    end

    UpdateShots(elapsed, s)

    for i = #S.actors, 1, -1 do
        local a = S.actors[i]
        local kind = KINDS[a.kind]
        if kind then
            if not a.dead and kind.Tick then kind.Tick(a, elapsed) end
            if not a.dead and a.resolveAt and S.time >= a.resolveAt and not a.resolved then
                a.resolved = true
                if kind.Resolve then kind.Resolve(a) end
                if not a.expireAt then a.dead = true end
            end
            if not a.dead and a.expireAt and S.time > a.expireAt then a.dead = true end
            if not a.dead and kind.Draw then
                a.visUsed = 0
                kind.Draw(a, s)
                HideSurplus(a)
            end
        end
        if a.dead then
            if kind and kind.Cleanup then kind.Cleanup(a) end
            releaseVis(a)
            table.remove(S.actors, i)
        end
    end

    DrawDots(s)

    hp:SetValue(S.hp)
    local frac = S.hp / MAX_HP
    hp:SetStatusBarColor(frac > 0.5 and 0.3 or 0.9, frac > 0.25 and 0.85 or 0.25, 0.35)
    hp.text:SetText(math.floor(S.hp) .. "%")

    local b = S.bossActor
    if b then
        bossBar:SetValue(b.hp / b.maxHp * 100)
        bossBar.text:SetText(("Boss  %d%%"):format(math.floor(b.hp / b.maxHp * 100)))
    end

    if S.flash > 0 then
        S.flash = math.max(0, S.flash - elapsed * 2)
        hurt:SetVertexColor(1, 0, 0, S.flash * 0.35)
    end
    if S.time > S.callUntil then callOut:SetText("") end

    local total = 0
    for _, ph in ipairs(S.phases or {}) do total = total + (ph.duration or 25) end
    local left = math.max(0, total - S.time)
    local energyLine = ""
    if S.scenario.energy then
        local e = S.scenario.energy
        local pct = S.energy / (e.max or 100) * 100
        energyBar:Show()
        energyBar:SetValue(pct)
        energyBar:SetStatusBarColor(1.0, pct >= 70 and 0.35 or 0.80, 0.15)
        energyBar.text:SetText(("%s  %d%%"):format(e.name, math.floor(pct)))
    else
        energyBar:Hide()
    end

    if phase and phase.bloodlust then
        -- Blinking, because a phase you are meant to empty every
        -- cooldown into should not be a thing you notice afterwards.
        lustText:Show()
        local on = (math.floor(S.time * 2) % 2) == 0
        lustText:SetText(on and "|cffff5533BLOODLUST|r" or "|cff884433BLOODLUST|r")
    else
        lustText:Hide()
    end
    local stackLine = ""
    if S.scenario.stacks then
        local max = S.heroic and S.scenario.stacks.heroicMax or S.scenario.stacks.max
        stackLine = ("   |cffaaff44%s %d/%d|r"):format(S.scenario.stacks.name, S.stacks, max)
    end
    scoreText:SetText(("|cff44ff66%d handled|r   |cffff4444%d missed|r   |cff888888%ds left|r%s%s")
        :format(S.passed, S.failed, math.ceil(left), energyLine, stackLine))

    if b and b.hp <= 0 and not (phase and phase.bossImmune) then
        Finish(true)
    elseif S.hp <= 0 then
        Finish(false)
    elseif PhaseComplete(phase) then
        if S.phaseIndex < #S.phases then
            EnterPhase(S.phaseIndex + 1)
        else
            Finish(false)
        end
    end
end

f:SetScript("OnUpdate", Update)

------------------------------------------------------------
-- Combat guard
------------------------------------------------------------
local guard = CreateFrame("Frame")
guard:RegisterEvent("PLAYER_REGEN_DISABLED")
guard:RegisterEvent("PLAYER_REGEN_ENABLED")
guard:SetScript("OnEvent", function(_, event)
    -- A flag only. The next keypress reads it and stops capturing; see
    -- the note at the top about never touching keyboard propagation
    -- outside a key handler.
    if event == "PLAYER_REGEN_DISABLED" then
        S.paused = true
        ReleaseInput()
    else
        S.paused = false
        bigText:SetText("")
        resultText:SetText("")
    end
end)

------------------------------------------------------------
-- Control
------------------------------------------------------------
function ClearActors()
    for _, a in ipairs(S.actors) do
        local kind = KINDS[a.kind]
        if kind and kind.Cleanup then kind.Cleanup(a) end
        releaseVis(a)
    end
    wipe(S.actors)
    ClearShots()
    floorTex:SetVertexColor(0.07, 0.07, 0.09, 1)
end

function T:Stop()
    S.running = false
    ReleaseInput()
    ClearActors()
end

--- Start a round for a boss id.
function T:Start(bossId, heroic)
    local scenarios = ns.RaidTrainerScenarios
    local sc = scenarios and scenarios[bossId]
    if not sc then return false end

    local boss = ns.RaidGuide and ns.RaidGuide:Get(bossId)
    S.scenario, S.boss = sc, boss
    S.heroic = heroic and true or false
    S.running = true
    S.paused = InCombatLockdown and InCombatLockdown() or false
    S.time, S.hp = 0, MAX_HP
    S.px, S.py, S.aim = 0, -60, math.pi / 2
    S.nextEvent, S.passed, S.failed, S.stacks = 1, 0, 0, 0
    S.flash, S.callUntil, S.fireCd = 0, 0, 0
    wipe(S.debuffs)
    wipe(S.corpses)
    S.countdown = 3.2

    S.phases = PhasesOf(sc)
    S.phaseIndex, S.phaseTime = 1, 0
    S.energy, S.carrying = 0, nil

    ReleaseInput()
    -- Belt and braces on the overlay: Finish clears it, but a round can
    -- also be restarted from a state Finish never ran on -- switching
    -- difficulty mid-fight does exactly that.
    hurt:SetVertexColor(1, 0, 0, 0)
    ClearActors()
    ResetAllies()
    ResetAltars(sc)
    ResetTunnels(sc)
    S.windStep = nil
    SetupBoss(sc)
    EnterPhase(1)

    title:SetText((boss and boss.name) or sc.title or "Practice")
    subtitle:SetText(sc.intro or "")
    StyleDifficulty()
    if S.heroic then
        diffBadge:SetText("|cffff6a59HEROIC|r")
    else
        diffBadge:SetText("|cff8a8a92NORMAL|r")
    end
    hp:SetValue(MAX_HP)
    hp.text:SetText("100%")
    bossBar:SetValue(100)
    bossBar.text:SetText("Boss  100%")
    callOut:SetText("")
    countText:SetText("")
    resultText:SetText("")
    scoreText:SetText("")

    f:Show()
    return true
end

retryBtn:SetScript("OnClick", function()
    if S.scenario then T:Start(S.scenario.bossId, S.heroic) end
end)

normalBtn:SetScript("OnClick", function()
    if S.scenario and S.heroic then T:Start(S.scenario.bossId, false) end
end)

heroicBtn:SetScript("OnClick", function()
    if S.scenario and not S.heroic then T:Start(S.scenario.bossId, true) end
end)

function T:HasScenario(bossId)
    return (ns.RaidTrainerScenarios and ns.RaidTrainerScenarios[bossId]) and true or false
end
