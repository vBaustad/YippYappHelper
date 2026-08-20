#!/usr/bin/env python3
"""Load every addon file in .toc order against a stub WoW API.

    python Tools/loadcheck.py

This is not a test suite. It answers one question: does the addon get
through load without throwing, and can each page's entry points be
called? That is the class of bug that had Consumables showing nothing --
a local declared below the function that used it, so the name resolved
to a nil global and pairs() threw before a single row was drawn. Nothing
about the call site looked wrong, and no amount of reading it caught it.

The stubs are deliberately a CURATED list of Blizzard globals rather
than a catch-all metatable that answers to any name. A permissive stub
would have made the Consumables bug invisible: `pairs(tabButtons)` on an
auto-created stub table succeeds. Anything this file does not name stays
nil, so an addon-level mistake still surfaces as an error.

Getters return numbers where the addon does arithmetic on them. A stub
that returned another stub from GetWidth() would fail at the subtraction
instead of at the thing actually being tested.
"""

import os
import pathlib
import re
import sys
import xml.parsers.expat
from lupa import LuaRuntime

# Windows consoles default to cp1252, which cannot print the bytes a
# Lua error message may carry. Losing the error to an encoding crash is
# the worst possible failure mode for a diagnostic tool.
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PRELUDE = r"""
-- ── Frame / region stubs ────────────────────────────────────
local function num(n) return function() return n end end

local Region = {}
-- One shared no-op, not a fresh closure per lookup.
--
-- This used to build a new function every time an unimplemented
-- CamelCase method was called, which is thousands of closures a second
-- under Tools/profile.py -- harness garbage that shows up as if the
-- addon had allocated it. Behaviourally identical: it ignores its
-- arguments and returns self either way.
local NOOP = function(self) return self end
-- Memoised, because `k:match` allocates a string on every hit and these
-- lookups are the hottest thing in the stub.
local isMethod = {}
Region.__index = function(t, k)
    local f = rawget(Region, k)
    if f then return f end
    -- Only CamelCase names get the no-op. A frame's DATA fields must
    -- still read as nil, or idioms like `self._scripts or {}` get a
    -- function instead of a table and the harness invents its own bugs
    -- instead of finding the addon's.
    local known = isMethod[k]
    if known == nil then
        known = type(k) == "string" and k:match("^%u") ~= nil
        isMethod[k] = known
    end
    if known then return NOOP end
    return nil
end

-- Width resolved from anchors when it was never set explicitly.
--
-- Half this addon's frames are sized by anchoring both edges to a parent
-- rather than by SetWidth, and returning a constant for those made every
-- horizontal number the harness reported meaningless -- it could check
-- that cards stacked correctly but not that they FIT. Since a stray
-- offset on one edge is exactly the bug that had the Consumables surface
-- hanging 22px off the page, that was the dimension worth resolving.
--
------------------------------------------------------------
-- Layout, solved rather than guessed.
--
-- The old version answered GetWidth from ONE level of anchors and
-- returned 700 for anything it could not work out. That was enough for
-- "do these two boxes overlap", which only needs relative positions --
-- and wrong for anything that depends on how wide something actually
-- is. A guide card about 530 wide in game reported 168, so every
-- paragraph inside it wrapped roughly three times too often and every
-- measured height inflated to match.
--
-- This resolves a rect properly: WIDTH first, from the anchor graph,
-- walking to whatever a region is anchored to and on up to the screen;
-- HEIGHT afterwards, because a wrapped string's height cannot be known
-- until its width is. Hence two passes rather than one.
--
-- Coordinates here are TOP-DOWN (y grows downward), converted once at
-- the anchor. WoW's own origin is bottom-left, and carrying both
-- conventions through a solver is how sign errors get in. Checks that
-- want raw anchor offsets still read _pts directly, which is what the
-- overlap checks do.
------------------------------------------------------------
local SOLVE_W, SOLVE_H = 1024, 768

-- Bumped whenever geometry changes, so a resolved rect can be cached
-- within a pass and dropped the moment anything moves. Without it a page
-- that re-lays out would keep its first answer forever.
local LAYOUT_GEN = 0
local function layoutChanged() LAYOUT_GEN = LAYOUT_GEN + 1 end

local function fracX(point)
    point = tostring(point or "")
    if point:find("LEFT", 1, true) then return 0 end
    if point:find("RIGHT", 1, true) then return 1 end
    return 0.5
end
local function fracY(point)
    point = tostring(point or "")
    if point:find("TOP", 1, true) then return 0 end
    if point:find("BOTTOM", 1, true) then return 1 end
    return 0.5
end

local resolveRect
-- Defined with the font metrics below; declared here because the
-- solver above them needs both to size a string.
local metricsOf, plainText

--- The rect an anchor point is measured against.
local function relRect(p, self, depth)
    local rel = p and p.rel or self._parent
    if rel == self then rel = self._parent end
    if type(rel) ~= "table" then return 0, 0, SOLVE_W, SOLVE_H end
    return resolveRect(rel, depth + 1)
end

--- Spread of anchor points along one axis, as (lowest, highest) pairs of
--- {fraction of this region, absolute position}. Two anchors at
--- different fractions pin a size.
local function spread(pts, self, depth, isX)
    local lo, hi
    for _, p in ipairs(pts) do
        local rl, rt, rw, rh = relRect(p, self, depth)
        local at, f
        if isX then
            at = rl + fracX(p.relP) * rw + (p.x or 0)
            f = fracX(p.p)
        else
            at = rt + fracY(p.relP) * rh - (p.y or 0)
            f = fracY(p.p)
        end
        if not lo or f < lo.f then lo = { f = f, at = at } end
        if not hi or f > hi.f then hi = { f = f, at = at } end
    end
    if lo and hi and (hi.f - lo.f) > 0.01 then
        local got = (hi.at - lo.at) / (hi.f - lo.f)
        if got > 0 then return got end
    end
    return nil
end

--- left, top, width, height -- absolute, y growing downward.
function resolveRect(self, depth)
    depth = depth or 0
    if type(self) ~= "table" then return 0, 0, SOLVE_W, SOLVE_H end
    if self._rectGen == LAYOUT_GEN and self._rect then
        local r = self._rect
        return r[1], r[2], r[3], r[4]
    end
    -- Cycles are legal in WoW (two frames anchored to each other) and
    -- unresolvable here; depth also stops a chain that is merely long.
    if depth > 24 or self._solving then
        return 0, 0, self._w or SOLVE_W, self._h or SOLVE_H
    end
    self._solving = true

    local pts = self._pts or {}

    -- PASS ONE: width.
    local w = self._w
    if not w and self._all then
        local _, _, aw = resolveRect(self._all, depth + 1)
        w = aw
    end
    if not w and #pts >= 2 then w = spread(pts, self, depth, true) end
    if not w and self._type == "FontString" then
        w = #plainText(self) * metricsOf(self).w
    end
    if not w then
        -- The PARENT's width, not a constant. A frame with one anchor
        -- and no size is nearly always a container being filled, and 700
        -- was a number that happened to be near the truth once.
        local _, _, pw = relRect(pts[1], self, depth)
        w = pw
    end

    -- PASS TWO: height, which for text needs the width settled above.
    local h = self._h
    if not h and self._all then
        local _, _, _, ah = resolveRect(self._all, depth + 1)
        h = ah
    end
    if not h and #pts >= 2 then h = spread(pts, self, depth, false) end
    if not h and self._type == "FontString" then
        local m = metricsOf(self)
        local text = plainText(self)
        if text == "" then
            h = 0
        elseif self._wrap == false or not w or w <= 0 then
            h = m.h
        else
            h = math.max(1, math.ceil((#text * m.w) / w)) * m.h
        end
    end
    if not h then
        local _, _, _, ph = relRect(pts[1], self, depth)
        h = ph
    end

    -- Position, from the first anchor.
    local left, top
    if pts[1] then
        local rl, rt, rw, rh = relRect(pts[1], self, depth)
        left = rl + fracX(pts[1].relP) * rw + (pts[1].x or 0) - fracX(pts[1].p) * w
        top = rt + fracY(pts[1].relP) * rh - (pts[1].y or 0) - fracY(pts[1].p) * h
    elseif self._all then
        left, top = resolveRect(self._all, depth + 1)
    else
        left, top = relRect(nil, self, depth)
    end

    self._solving = nil
    self._rect = { left, top, w, h }
    self._rectGen = LAYOUT_GEN
    return left, top, w, h
end

function Region.GetWidth(self)
    local _, _, w = resolveRect(self)
    return w
end
function Region.GetHeight(self)
    local _, _, _, h = resolveRect(self)
    return h
end
function Region.GetSize(self) return self:GetWidth(), self:GetHeight() end
function Region.SetWidth(self, w)
    self._w = w; layoutChanged(); return self
end
function Region.SetHeight(self, h)
    self._h = h; layoutChanged(); return self
end
function Region.SetSize(self, w, h)
    self._w = w; self._h = h; layoutChanged(); return self
end
function Region.GetFrameLevel(self) return self._lvl or 1 end
function Region.SetFrameLevel(self, l) self._lvl = l; return self end
-- Recorded, not discarded. There are no pixels here, but "these two
-- things were painted the same colour" is a claim about the code's
-- own numbers and is perfectly decidable -- and it is exactly the claim
-- a state-encoded stripe makes.
function Region.SetColorTexture(self, r, g, b, a)
    self._rgba = { r, g, b, a }
    return self
end
function Region.SetVertexColor(self, r, g, b, a)
    self._rgba = { r, g, b, a }
    return self
end
function Region.GetColorKey(self)
    local c = self._rgba
    if not c then return "none" end
    return string.format("%.3f/%.3f/%.3f", c[1] or 0, c[2] or 0, c[3] or 0)
end
-- Recorded, so a check can ask which of two states a label was left in.
-- Selection is carried by brightness now as well as by the underline,
-- and an assertion that only looked at the underline would miss half of
-- what changed.
function Region.SetTextColor(self, r, g, b, a)
    self._textRGBA = { r, g, b, a }
    return self
end
function Region.GetTextColor(self)
    local c = self._textRGBA
    if not c then return nil end
    return c[1], c[2], c[3], c[4]
end
function Region.GetText(self) return self._text or "" end

-- Checkboxes remember. Without these, GetChecked fell through to the
-- CamelCase no-op, which returns the frame -- so every checkbox in the
-- addon read as permanently ticked and no check could tell a box that
-- was on from one that was off.
function Region.SetChecked(self, on) self._checked = on and true or false; return self end
function Region.GetChecked(self) return self._checked and true or false end
function Region.SetText(self, t)
    self._text = t; layoutChanged(); return self
end
-- Font metrics, close enough to catch a wrapping bug.
--
-- These were a flat eight pixels a character and a flat twelve pixels
-- high, which made every wrap invisible: a paragraph that ran to three
-- lines in game measured one line here, so a page that advances its
-- cursor by measured height -- which is most of this addon -- packed its
-- cards as if nothing wrapped and the harness saw no overlap. The bug
-- and the check disagreed, and the check won.
--
-- Not real glyph widths: no font files here, and per-character widths
-- vary. What matters is that the numbers GROW WITH THE FONT and that
-- height depends on the width the string was given, because that is the
-- relationship every layout bug of this kind is made of. Averages taken
-- from WoW's default fonts at their usual sizes.
local FONT_METRICS = {
    GameFontNormalSmall  = { w = 5.4, h = 12 },
    GameFontNormal       = { w = 6.4, h = 14 },
    GameFontNormalLarge  = { w = 8.2, h = 18 },
    GameFontNormalHuge   = { w = 11.0, h = 24 },
    GameFontHighlight    = { w = 6.4, h = 14 },
    GameFontHighlightSmall = { w = 5.4, h = 12 },
    GameFontDisable      = { w = 6.4, h = 14 },
}
local FONT_DEFAULT = { w = 6.4, h = 14 }

function metricsOf(self)
    return FONT_METRICS[self._font or ""] or FONT_DEFAULT
end

function Region.SetFontObject(self, f)
    self._font = (type(f) == "string") and f or self._font
    return self
end
function Region.GetFontObject(self) return self._font end
-- Wrapping is ON unless something turns it off, which is WoW's default
-- and the case that matters -- a title with wrap off is exactly the
-- thing that must NOT be measured as three lines.
function Region.SetWordWrap(self, on) self._wrap = on and true or false; return self end

--- Visible length, with colour escapes removed: they occupy no space.
function plainText(self)
    return (self._text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

function Region.GetStringWidth(self)
    return #plainText(self) * metricsOf(self).w
end

--- Height AFTER wrapping to whatever width the string was given.
---
--- This is the whole point of the exercise. A layout that asks how tall
--- a paragraph is, and is always told one line, cannot overlap in the
--- model however badly it overlaps on screen.
function Region.GetStringHeight(self)
    local m = metricsOf(self)
    local text = plainText(self)
    if text == "" then return 0 end
    local width = self._w
    if self._wrap == false or not width or width <= 0 then return m.h end
    local lines = math.max(1, math.ceil((#text * m.w) / width))
    return lines * m.h
end
function Region.GetAtlas(self) return self._atlas end
function Region.SetAtlas(self, a) self._atlas = a; return true end
-- Real Show/Hide state, not a no-op.
--
-- This is what lets the harness check the thing the pages were actually
-- wrong about: "the indented background is gone" is not a matter of
-- taste, it means the skin's inner-shadow textures are hidden. Falling
-- through to the CamelCase no-op would have made every region claim to
-- be visible forever and the check meaningless.
function Region.Show(self) self._shown = true; return self end
function Region.Hide(self) self._shown = false; return self end
function Region.SetShown(self, v) self._shown = v and true or false; return self end
function Region.IsShown(self) return self._shown ~= false end
function Region.IsVisible(self) return self._shown ~= false end

-- Geometry, recorded so the layout can be inspected after a draw.
function Region.SetPoint(self, p, rel, relP, x, y)
    self._pts = self._pts or {}
    -- Three call shapes in the wild: (point, x, y) with the parent
    -- implied, (point, rel, relPoint, x, y), and (point, rel) alone.
    -- Getting this wrong silently shifts every resolved width.
    if type(rel) == "number" then
        x, y, rel, relP = rel, relP, nil, p
    elseif type(relP) == "number" then
        x, y, relP = relP, x, p
    end
    table.insert(self._pts, { p = p, relP = relP, x = x or 0, y = y or 0,
                              rel = rel or self._parent })
    layoutChanged()
    return self
end
function Region.ClearAllPoints(self)
    self._pts = nil; self._all = nil; layoutChanged(); return self
end
-- Recorded rather than ignored. It used to fall through to the no-op
-- catch-all, which meant a full-bleed background had no geometry at all
-- and any check that asked about one got a silent wrong answer.
function Region.SetAllPoints(self, rel)
    self._all = rel or self._parent; layoutChanged(); return self
end
function Region.IsObjectType(self, t) return t == self._type end
function Region.GetObjectType(self) return self._type or "Frame" end
function Region.GetRegions(self) return end
function Region.GetChildren(self) return end
-- Honest, where it used to answer nil to everything.
--
-- A stub that always says "no handler" is the permissive kind this file
-- exists to avoid: BisUI's hookMenu reads the previous OnClick back and
-- chains onto it, so under the old stub the chaining branch could not
-- run and nothing that asks whether a frame is wired could be checked
-- at all.
function Region.GetScript(self, e)
    return self._scripts and self._scripts[e] or nil
end
function Region.SetScript(self, e, fn) self._scripts = self._scripts or {}; self._scripts[e] = fn; return self end
function Region.GetLeft(self) return 0 end
function Region.GetNormalTexture(self) return NewRegion("Texture") end
function Region.GetParent(self) return self._parent end
-- Attributes and frame refs are stored rather than swallowed. The
-- window's combat close is a secure handler -- a frame ref to the shell
-- and an "_onclick" snippet that hides it -- and with a GetAttribute
-- that always answered nil there was no way to tell a wired-up handler
-- from one that had never been given its snippet.
function Region.SetAttribute(self, k, v)
    self._attr = self._attr or {}
    self._attr[k] = v
end
function Region.GetAttribute(self, k)
    return self._attr and self._attr[k] or nil
end
function Region.SetFrameRef(self, k, f)
    self._frefs = self._frefs or {}
    self._frefs[k] = f
end
function Region.GetFrameRef(self, k)
    return self._frefs and self._frefs[k] or nil
end
function Region.GetNumPoints(self) return 0 end
-- Reports what was actually set, which it did not used to: it returned
-- a fixed TOPLEFT 0,0 whatever the frame had been anchored to. Anything
-- asking a frame where it sits -- saving a dragged window's position,
-- for one -- got the same answer before and after moving it, so the
-- round trip could not be tested at all. The constant survives as the
-- answer for a frame with no points, which is what the client does too.
function Region.GetPoint(self, index)
    local pt = self._pts and self._pts[index or 1]
    if not pt then return "TOPLEFT", nil, "TOPLEFT", 0, 0 end
    return pt.p, pt.rel, pt.relP or pt.p, pt.x or 0, pt.y or 0
end
-- Real numbers, because the raid trainer converts the cursor into arena
-- coordinates and does arithmetic on the result. The CamelCase no-op
-- would hand it the frame itself, and "attempt to perform arithmetic on
-- a table" is not the bug anyone is looking for.
function Region.GetCenter(self) return 0, 0 end
function Region.GetEffectiveScale(self) return 1 end

function NewRegion(kind, parent)
    local r = setmetatable({ _type = kind or "Frame", _parent = parent }, Region)
    return r
end

function Region.CreateTexture(self, n, layer) return NewRegion("Texture", self) end
function Region.CreateFontString(self, n, layer, template)
    local r = NewRegion("FontString", self)
    r._font = template
    return r
end
function Region.CreateMaskTexture(self) return NewRegion("MaskTexture", self) end
function Region.CreateAnimationGroup(self) return NewRegion("AnimationGroup", self) end

-- Events, really registered and really dispatched.
--
-- RegisterEvent used to fall through to the CamelCase no-op, which made
-- everything a module does at login untestable here: two of the three
-- panels of the situation window build themselves on PLAYER_LOGIN, so
-- under this harness they simply never existed -- indistinguishable from
-- a module that had broken.
local eventFrames, tracked = {}, {}

function Region.RegisterEvent(self, event)
    self._events = self._events or {}
    self._events[event] = true
    if not tracked[self] then
        tracked[self] = true
        eventFrames[#eventFrames + 1] = self
    end
    return self
end

--- The unit-filtered form, which is a different registration entirely.
---
--- It used to fall through to the CamelCase no-op, so anything
--- registered this way -- the interrupt tracker's whole cast feed, for
--- one -- was invisible here: FireEvent had nothing listening and a
--- check could not tell that apart from a module that ignored the event.
---
--- The filter is honoured rather than waved through, because "does this
--- frame hear about party1" is exactly the question worth asking.
function Region.RegisterUnitEvent(self, event, ...)
    self._events = self._events or {}
    self._events[event] = true
    local units = {}
    for i = 1, select("#", ...) do units[select(i, ...)] = true end
    self._unitFilter = self._unitFilter or {}
    self._unitFilter[event] = next(units) and units or nil
    if not tracked[self] then
        tracked[self] = true
        eventFrames[#eventFrames + 1] = self
    end
    return self
end

function Region.UnregisterEvent(self, event)
    if self._events then self._events[event] = nil end
    return self
end

function Region.UnregisterAllEvents(self)
    self._events = nil
    return self
end

function Region.IsEventRegistered(self, event)
    return (self._events and self._events[event]) and true or false
end

--- Fires one event at every frame listening for it.
---
--- Returns how many handlers ran and a list of the ones that threw, so
--- a check can tell "nothing happened" from "nothing was listening".
---
--- Each handler is pcall-ed, because an event reaches EVERY module that
--- registered for it: one of them touching a Blizzard global this file
--- has not stubbed would otherwise abort a check about something else
--- entirely. The failures are returned rather than swallowed -- a caller
--- that cares can insist on an empty list.
function FireEvent(event, ...)
    local n, errs = 0, {}
    for _, fr in ipairs(eventFrames) do
        if fr._events and fr._events[event] then
            -- For UNIT_ events the first payload argument is the unit, so
            -- a frame that filtered on party1 must not hear about party3.
            local filter = fr._unitFilter and fr._unitFilter[event]
            local pass = true
            if filter then
                local unit = ...
                pass = unit ~= nil and filter[unit] or false
            end
            local h = pass and fr._scripts and fr._scripts.OnEvent
            if h then
                n = n + 1
                local ok, err = pcall(h, fr, event, ...)
                if not ok then errs[#errs + 1] = tostring(err) end
            end
        end
    end
    return n, errs
end

function CreateFrame(kind, name, parent, template)
    local f = NewRegion(kind or "Frame", parent)
    -- WoW's actual default: a new frame sits ONE LEVEL ABOVE its parent.
    -- Modelling this matters -- without it every frame reported level 1
    -- and the card-layering check passed whether the fix was present or
    -- not. A check that cannot fail is worse than no check, because it
    -- reads as evidence.
    if parent and parent.GetFrameLevel then
        f._lvl = (parent:GetFrameLevel() or 0) + 1
    else
        f._lvl = 1
    end
    if name then _G[name] = f end
    return f
end

UIParent = NewRegion("Frame")
Minimap = NewRegion("Minimap")
MinimapCluster = NewRegion("Frame")
WorldFrame = NewRegion("Frame")
GameTooltip = NewRegion("GameTooltip")
UISpecialFrames = {}

-- Seeded, and seeded FIXED.
--
-- Lua 5.4 and later seed math.random randomly at startup, so anything
-- here that simulates -- the raid trainer spawns its events at random --
-- played a different round every run. The stack-meter check failed
-- roughly one run in seven and passed the rest, which is worse than a
-- check that always fails: an intermittent red makes every green
-- ambiguous and trains you to re-run until it is quiet.
--
-- The number itself is arbitrary. What matters is that it never moves,
-- so a failure here is a change in the addon and not a change in the
-- weather.
math.randomseed(20260817)

-- ── Constants the pages read ────────────────────────────────
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
NUM_BAG_SLOTS = 4
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
RAID_CLASS_COLORS = setmetatable({}, { __index = function()
    return { r = 1, g = 1, b = 1, colorStr = "ffffffff",
             WrapTextInColorCode = function(self, t) return t end }
end })
ITEM_QUALITY_COLORS = setmetatable({}, { __index = function()
    return { r = 1, g = 1, b = 1, hex = "|cffffffff" }
end })

-- ── Plain function stubs ────────────────────────────────────
function UnitClass() return "Druid", "DRUID" end
function UnitName() return "Tester" end
function UnitLevel() return 80 end
-- overall, equipped, pvp. Equipped is deliberately BELOW the fixture's
-- vault rewards (282-302) so the "not an upgrade" branch is reachable
-- from the other side too -- a fixture where everything is an upgrade
-- cannot tell a working comparison from one that never fires.
function GetAverageItemLevel() return 291, 289, 289 end
function GetRealmName() return "Realm" end
function GetSpecialization() return 1 end
function GetSpecializationInfo() return 102, "Balance", "", 136096, "DAMAGER" end
function GetSpecializationInfoByID() return 102, "Balance", "", 136096, "DAMAGER" end
function GetItemInfo() return nil end
function GetInventoryItemID() return nil end
function GetInventoryItemLink() return nil end
function GetDetailedItemLevelInfo() return 0 end
function InCombatLockdown() return false end
-- In a guild, so the Guild tab draws its "waiting for replies" empty
-- state rather than the "you're not in a guild" one -- the branch with
-- something in it. Nothing had called this: that tab was unreachable
-- until the sub-tab switch below started exercising it.
function IsInGuild() return true end
-- The client names its own raid difficulties. Only the ones the vault
-- can hand back; an unknown id must come back nil so the caller's
-- fallback is reachable.
function GetDifficultyInfo(id)
    local names = { [14] = "Normal", [15] = "Heroic", [16] = "Mythic", [17] = "Looking For Raid" }
    return names[id]
end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function IsModifiedClick() return false end
function GetTime() return 0 end
-- A plausible epoch, not 0. Code that stamps an expiry and compares it
-- against `now` has to guard against a client that cannot tell the time,
-- and at 0 every such guard trips -- so the expiry path was unreachable
-- and read as covered. Fixed here rather than by loosening the guard.
function time() return 1786000000 end
-- date("*t") is a table, and the week list asks for one to work out
-- whether a run happened today. Every other format keeps the old string.
function date(fmt)
    if fmt == "*t" then
        return { year = 2026, month = 8, day = 16, hour = 20, min = 30,
                 sec = 0, wday = 1, yday = 228, isdst = false }
    end
    return "2026-08-16"
end
function print() end
function geterrorhandler() return function() end end
function hooksecurefunc() end
function tinsert(t, ...) return table.insert(t, ...) end
function tremove(t, ...) return table.remove(t, ...) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
-- Really splits, because it used to hand the string back whole -- which
-- silently made every "/yh <command> <argument>" untestable here: the
-- command matched only when it was typed with no argument at all.
function strsplit(sep, s, limit)
    s = tostring(s or "")
    local out, start = {}, 1
    while not (limit and #out == limit - 1) do
        local a, b = s:find("[" .. sep .. "]", start)
        if not a then break end
        out[#out + 1] = s:sub(start, a - 1)
        start = b + 1
    end
    out[#out + 1] = s:sub(start)
    return (table.unpack or unpack)(out)
end
function strjoin(sep, ...) return table.concat({ ... }, sep) end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function format(...) return string.format(...) end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
function GetLocale() return "enUS" end
function C_Timer_After() end
function SetPortraitTexture() end
function SetPortraitToTexture() end
function PlaySound() end
-- The real securecall takes either a function or the NAME of a global
-- one, and the addon uses the name form for ShowUIPanel/HideUIPanel.
-- A stub that only handled functions turned that into a "attempt to call
-- a string" the moment anything here reached those paths.
function securecall(fn, ...)
    if type(fn) == "string" then fn = _G[fn] end
    if fn then return fn(...) end
end
function issecurevariable() return true end
function GetAddOnMetadata() return nil end
function BackdropTemplateMixin() end
function Mixin(t) return t end
function CreateFromMixins() return {} end
function nop() end

-- WoW runs Lua 5.1, where `unpack` is a global. Lua 5.5 moved it to
-- table.unpack, so without this every unpack() call in the addon looks
-- like a bug that only exists in the harness.
unpack = table.unpack
loadstring = load
strmatch = string.match
strfind = string.find
strsub = string.sub
strlower = string.lower
strupper = string.upper
strrep = string.rep
strbyte = string.byte
strchar = string.char
gsub = string.gsub
StaticPopupDialogs = {}
function StaticPopup_Show() end
function StaticPopup_Hide() end
function GetNumClasses() return 13 end
function GetClassInfo(i)
    local names = { "Warrior", "Paladin", "Hunter", "Rogue", "Priest",
                    "Death Knight", "Shaman", "Mage", "Warlock", "Monk",
                    "Druid", "Demon Hunter", "Evoker" }
    local files = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
                    "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK",
                    "DRUID", "DEMONHUNTER", "EVOKER" }
    return names[i] or "Warrior", files[i] or "WARRIOR", i
end
function GetNumSpecializationsForClassID() return 3 end
function GetSpecializationInfoForClassID(_, i)
    return 100 + i, "Spec" .. i, "", 136096, "DAMAGER"
end
function GetItemSubClassInfo() return "Sub" end
function GetItemClassInfo() return "Class" end
function GetInventorySlotInfo() return 1, 134400 end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
function GetPhysicalScreenSize() return 1920, 1080 end
function UnitAffectingCombat() return false end
function IsInGroup() return false end
function IsInRaid() return false end
function GetNumGroupMembers() return 0 end
-- Solo, and a DPS. The raid guide picks the column it opens on from
-- this, so it needs an answer rather than a no-op -- and "no assigned
-- role" is the honest state for a player reading the guide outside a
-- group, which is the case worth exercising.
function UnitGroupRolesAssigned() return "NONE" end
function GetCursorPosition() return 0, 0 end
function UnitGUID() return "Player-1-00000000" end
function UnitIsPlayer() return true end
function GetPlayerInfoByGUID() return "DRUID", "DRUID", "Balance" end
function CopyTable(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end
function ReloadUI() end
function GetCVar() return "0" end
function SetCVar() end

Item = { CreateFromItemID = function()
             return setmetatable({}, { __index = function() return function() end end }) end }
function IsSpellKnown() return false end
function IsPlayerSpell() return false end
function GetSpellInfo() return "Spell", nil, 134400 end

-- Encounter Journal deliberately NOT stubbed.
--
-- A stub set was tried here so the Loot Browser would build its instance
-- cache offline. It did -- and then the scan loop ran away, because the
-- real API terminates on conditions the stubs could not honestly model.
-- A harness that hangs is worse than one with a known blind spot, so the
-- blind spot is documented instead: this page's list cannot be rendered
-- outside the client, and layering there has to be reasoned about rather
-- than measured.

C_ChatInfo = { RegisterAddonMessagePrefix = function() return true end,
               SendAddonMessage = function() end }
C_PartyInfo = { GetInviteConfirmationInvalidQueues = function() return {} end,
                IsDelveInProgress = function() return false end }

-- The delve companion.
--
-- Modelled as a FRIENDSHIP, which is what it is: Valeera reads level 57
-- with a percentage toward 58, not a reputation standing and not a
-- character level. Ranks come from one call and the bar within the rank
-- from another, and either can be absent on its own -- a companion at
-- maximum rank has no next threshold -- so the fixture gives both and
-- the code has to cope when it does not.
local COMPANION_FACTION = 2640
C_DelvesUI = { GetFactionForCompanion = function() return COMPANION_FACTION end,
               HasActiveDelve = function() return false end,
               GetCurrentDelvesSeasonNumber = function() return 2 end }
C_GossipInfo = { GetFriendshipReputation = function(id)
                     if id ~= COMPANION_FACTION then return nil end
                     -- `texture` is the companion's face. Without it
                     -- here the portrait resolver has nothing to read
                     -- and every check about the medallion passes on
                     -- the empty path, which is how the first version
                     -- shipped a gold ring with a hole in it.
                     return { name = "Valeera Sanguinar", reaction = "Trusty Delve Companion",
                              standing = 1700, reactionThreshold = 1500,
                              nextThreshold = 2500, texture = 4622270 }
                 end,
                 GetFriendshipReputationRanks = function(id)
                     if id ~= COMPANION_FACTION then return nil end
                     return { currentLevel = 57, maxLevel = 60 }
                 end }
C_UIWidgetManager = {}
C_Reputation = { GetFactionDataByID = function(id)
                     return { factionID = id, name = "Valeera Sanguinar" }
                 end }
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end }
C_Calendar = {}
COMPLETION_INFO = nil

C_DateAndTime = { GetCurrentCalendarTime = function()
                      return { year = 2026, month = 8, monthDay = 16,
                               hour = 12, minute = 0 } end,
                  -- Three days to the reset, so "this week" starts four
                  -- days ago. The run journal prunes against this, and
                  -- with the call absent it cannot prune at all -- so
                  -- leaving it out would quietly skip that branch.
                  GetSecondsUntilWeeklyReset = function() return 3 * 24 * 60 * 60 end,
                  GetServerTimeLocal = function() return 0 end }

NineSliceUtil = { ApplyLayoutByName = function() end }

-- ── C_* namespaces ──────────────────────────────────────────
C_Timer = { After = function() end, NewTimer = function() return NewRegion() end,
            NewTicker = function() return NewRegion() end }
-- Answers only for something that looks like an item; a stub that hands
-- back an icon for nil or "" would let "every slot drew a reward" pass
-- on nine slots that have no reward.
C_Item = { GetItemIconByID = function(item)
               if item == nil or item == "" then return nil end
               return 134400
           end,
           RequestLoadItemDataByID = function() end,
           GetItemInfoInstant = function() return nil end,
           -- Reads the item level back out of the fake vault link below,
           -- so the reward text exercises its item-level branch instead
           -- of quietly taking the fallback and looking tested anyway.
           --
           -- THREE return values, like the real one: effective level,
           -- isPreview, base level. Returning just the first hid a live
           -- crash -- `tonumber(GetDetailedItemLevelInfo(link))` spills
           -- all three into tonumber, which takes the boolean as its
           -- base and raises. A stub that returns fewer values than the
           -- API it stands in for cannot see that class of bug at all.
           GetDetailedItemLevelInfo = function(link)
               local n = tonumber(tostring(link or ""):match("ilvl(%d+)"))
               if not n then return nil end
               return n, false, n
           end,
           DoesItemExistByID = function() return true end }
C_Container = { GetContainerNumSlots = function() return 0 end,
                GetContainerItemID = function() return nil end,
                GetContainerItemLink = function() return nil end }
C_Spell = { GetSpellTexture = function() return 134400 end,
            GetSpellName = function() return "Spell" end,
            GetSpellInfo = function() return { name = "Spell", iconID = 134400 } end,
            IsSpellKnown = function() return false end }
C_SpellBook = { IsSpellKnown = function() return false end }
C_Texture = { GetAtlasInfo = function(a)
    -- Only the atlases this client would actually ship. Answering yes to
    -- everything would hide a bad atlas name, which is the exact failure
    -- the corner tiles were generated to avoid.
    -- The Great Vault set is verified: EllesmereUI's vault skin and
    -- Vaultloom both address these by name against a live client, which
    -- is a stronger source than picking a plausible-looking string.
    local known = { ["ui-journeys-renown-divider"] = true,
                    ["ui-journeys-renown-button"] = true,
                    ["perks-list-mask"] = true,
                    ["evergreen-weeklyrewards-category-raids"] = true,
                    ["evergreen-weeklyrewards-category-dungeons"] = true,
                    ["evergreen-weeklyrewards-category-world"] = true,
                    ["evergreen-weeklyrewards-reward-locked"] = true,
                    ["evergreen-weeklyrewards-reward-unlocked"] = true,
                    ["activities-icon-checkmark"] = true }
    return known[a] and { width = 64, height = 16 } or nil
end }
-- Balance druid's two hero talents, under the names the class guide
-- data uses, with Keeper of the Grove the one taken.
--
-- Both subtrees used to answer "Keeper of the Grove", which is not a
-- shape any client produces: a spec's trees have distinct names. It
-- also made every question that turns on WHICH tree you are in
-- unanswerable, since one name cannot pick between two guide entries.
local SUBTREES = { [1] = "Keeper of the Grove", [2] = "Elune's Chosen" }
C_Traits = { GetSubTreeInfo = function(_, id)
    return { ID = id, name = SUBTREES[id] or "Keeper of the Grove",
             iconElementID = 5651754,
             isActive = (id == 1), traitTreeID = 1 }
end, GetConfigInfo = function() return { ID = 1 } end }
C_ClassTalents = { GetActiveConfigID = function() return 1 end,
                   GetHeroTalentSpecsForClassSpec = function() return { 1, 2 } end,
                   GetActiveHeroTalentSpec = function() return 1 end }
-- The season's eight dungeons, under the names Features/MythicPlus
-- actually sorts and resolves teleports by.
--
-- GetMapTable returned an empty list, and RefreshMythicPlus opens with
-- `if #maps == 0 then return end` -- so every "ok ns:RefreshMythicPlus"
-- above was reporting on four lines and an early return. The icon row,
-- the group table and both bottom columns had never executed once. A
-- single "Dungeon" for every id would have brought back almost as
-- little: the sort order, the teleport-by-name lookup and each tile's
-- identity are only observable when the ids differ.
local MPLUS_ORDER = { 2810, 2811, 2812, 2813, 2814, 2815, 2816, 2817 }
local MPLUS_MAPS = {
    [2810] = "Altar of Fangs",       [2811] = "Murder Row",
    [2812] = "Den of Nalorakk",      [2813] = "The Blinding Vale",
    [2814] = "Voidscar Arena",       [2815] = "Kings' Rest",
    [2816] = "Ruby Life Pools",      [2817] = "Temple of Sethraliss",
}
-- Three, and never Tyrannical alongside Fortified: a fake week that
-- cannot happen is a fake week whose layout proves nothing.
local MPLUS_AFFIXES = {
    [9]   = { "Tyrannical",
              "Bosses have 30% more health and inflict up to 15% increased damage." },
    [10]  = { "Fortified",
              "Non-boss enemies have 20% more health and inflict increased damage." },
    [152] = { "Challenger's Peril",
              "Each player death subtracts 15 seconds from the dungeon timer." },
    [148] = { "Xal'atath's Guile",
              "Xal'atath assaults the party with a barrage of shadow energy." },
    [160] = { "Lindormi's Guidance",
              "Lindormi aids the party." },
    -- Two different Bargains, so a second week can differ by identity
    -- rather than only by order.
    [162] = { "Xal'atath's Bargain: Pulsar", "A bargain is struck." },
    [163] = { "Xal'atath's Bargain: Voidbound", "A different bargain is struck." },
}

-- This week's affixes, settable so a test can advance the week. The
-- ORDER is the data under test: the index an affix sits at is the
-- keystone level it switches on at, and Fortified/Tyrannical swapping
-- places is a change the card has to notice.
AFFIX_WEEK = {
    { id = 160, seasonID = 2 },   -- standing
    { id = 162, seasonID = 2 },   -- the week's Bargain
    { id = 10,  seasonID = 2 },   -- swaps with Tyrannical
    { id = 9,   seasonID = 2 },
    { id = 148, seasonID = 2 },   -- standing
}

C_ChallengeMode = { GetMapUIInfo = function(id)
                        -- Unknown ids keep the old generic answer; other
                        -- pages pass ids that are not this season's.
                        return (MPLUS_MAPS[id] or "Dungeon"), id or 1, 1800, 134400
                    end,
                    GetMapTable = function() return MPLUS_ORDER end,
                    -- The run that just finished, settable so a test can
                    -- stage one. Nil means "no run", which is what the
                    -- real call returns outside a completion.
                    GetCompletionInfo = function()
                        local c = COMPLETION_INFO
                        if not c then return nil end
                        -- Return ORDER matters and is the thing most
                        -- easily got wrong; verified against
                        -- RaiderIO/core.lua, which is maintained against
                        -- a live client.
                        return c.mapID, c.level, c.ms, c.onTime, c.chests,
                               c.practice, c.oldScore, c.newScore
                    end,
                    GetDeathCount = function()
                        local c = COMPLETION_INFO
                        return (c and c.deaths) or 0
                    end,
                    GetAffixInfo = function(id)
                        local a = MPLUS_AFFIXES[id]
                        if not a then return nil end
                        return a[1], a[2], 134400
                    end,
                    GetOverallDungeonScore = function() return 2180 end,
                    -- 0 and 1 only, and not for lack of imagination.
                    -- The pages write colours as string.format("%02x",
                    -- r * 255), which Lua 5.1 -- the client's runtime --
                    -- truncates happily. lupa gives 5.5, which rejects a
                    -- float with no exact integer representation, and
                    -- c * 255 is only exact for c = 0 or c = 1. A
                    -- prettier purple aborts the render mid-page and the
                    -- geometry below then reads half a layout. Colour is
                    -- not decidable here regardless: no pixels.
                    GetDungeonScoreRarityColor = function()
                        return { r = 1, g = 0, b = 1 }
                    end }
-- GetOwnedKeystoneChallengeMapID sat on C_ChallengeMode here for as long
-- as this file has existed. The addon reads it off C_MythicPlus, which
-- was nil -- and nothing noticed, because the only caller sits past the
-- early return that the hidden frame guaranteed.
C_MythicPlus = { -- A key in hand, so Group Keystones renders a row and
                 -- not only its empty state. The padding bug there was
                 -- invisible for exactly that reason: the empty state is
                 -- all that branch had ever drawn.
                 GetOwnedKeystoneChallengeMapID = function() return 2815 end,
                 GetOwnedKeystoneLevel = function() return 12 end,
                 -- Ten runs this week, against a card that shows eight:
                 -- the overflow line is a branch too, and a silent
                 -- truncation is exactly the kind of thing that should
                 -- not pass. Two more from before the reset, which must
                 -- stay off a card headed "This Week" while still
                 -- setting the score bar the week's runs are measured
                 -- against.
                 --
                 -- Index 1 is the OLDEST, the client's own order, and
                 -- levels deliberately do not fall with time -- a list
                 -- sorted by key level would pass a fixture where the
                 -- newest run is also the highest.
                 --
                 -- Field names read off BigWigs/Tools/Keystones.lua.
                 -- The timer is 1800 for every map here, so 1080 and
                 -- 1440 are the 3- and 2-chest thresholds.
                 GetRunHistory = function(includePreviousWeeks)
                     local rows = {
                         -- level, seconds, score, this week, monthDay, map
                         { 10, 1500, 210, false, 11, 1 },
                         { 12, 1200, 180, false, 12, 2 },
                         {  8, 1700, 150, true,  15, 3 },
                         { 12, 1100, 215, true,  15, 1 },  -- beats the 210
                         {  9, 1650, 160, true,  15, 4 },
                         { 11, 1900, 170, true,  16, 5 },  -- over the timer
                         { 10, 1430, 190, true,  16, 6 },
                         { 13, 1000, 240, true,  16, 7 },
                         {  9, 1560, 165, true,  17, 8 },
                         { 12, 1250, 205, true,  17, 1 },  -- under its own 215
                         { 10, 1790, 175, true,  17, 2 },
                         { 11, 1050, 225, true,  17, 3 },
                     }
                     local out = {}
                     for i, r in ipairs(rows) do
                         if r[4] or includePreviousWeeks then
                             out[#out + 1] = {
                                 mapChallengeModeID = MPLUS_ORDER[r[6]],
                                 level = r[1],
                                 durationSec = r[2],
                                 runScore = r[3],
                                 completed = r[2] <= 1800,
                                 thisWeek = r[4],
                                 completionDate = { year = 2026, month = 8,
                                                    monthDay = r[5],
                                                    weekday = ((r[5] - 1) % 7) + 1,
                                                    hour = 20, minute = (i * 7) % 60 },
                             }
                         end
                     end
                     return out
                 end,
                 GetSeasonBestAffixScoreInfoForMap = function() return nil end,
                 RequestMapInfo = function() end,
                 GetCurrentAffixes = function() return AFFIX_WEEK end }
-- A real half-finished vault week, one activity type at a time.
--
-- This returned {} for everything, which meant the dashboard's nine
-- tiles all rendered as "no data" and the Mythic+ page's vault chips
-- returned before drawing anything. Both looked tested and neither was.
--
-- Mixed on purpose, and it took a failing check to get the mix right:
-- with Raid sitting at 1 run the fixture produced only "unlocked" and
-- "in progress", and a check that never sees a locked slot cannot tell
-- a state encoding from one that paints everything alike. Raid is now
-- untouched for the week, which is both the missing state and what a
-- character who has not raided actually looks like.
--
-- Progress is uniform within a category on purpose too: you run N
-- dungeons and each slot measures that same N against its own
-- threshold. Slots of one category never disagree about it.
local VAULT_ACTIVITIES = {
    [1] = {   -- Activities (Mythic+)
        -- A keystone level, so the Mythic+ qualifier renders as "+10".
        { id = 11, index = 1, type = 1, activityTierID = 1, threshold = 1, progress = 1, level = 10 },
        { id = 12, index = 2, type = 1, threshold = 4, progress = 1, level = 0 },
        { id = 13, index = 3, type = 1, threshold = 8, progress = 1, level = 0 },
    },
    [2] = {   -- World (delves)
        { id = 21, index = 1, type = 2, threshold = 2, progress = 2, level = 5 },
        { id = 22, index = 2, type = 2, threshold = 4, progress = 4, level = 4 },
        { id = 23, index = 3, type = 2, threshold = 8, progress = 7, level = 0 },
    },
    [3] = {   -- Raid: nothing killed this week
        { id = 31, index = 1, type = 3, threshold = 2, progress = 0, level = 0 },
        { id = 32, index = 2, type = 3, threshold = 4, progress = 0, level = 0 },
        { id = 33, index = 3, type = 3, threshold = 6, progress = 0, level = 0 },
    },
}
-- Item level per unlocked activity, matching the fixture above: the one
-- Mythic+ slot and the two World slots that are actually earned.
local VAULT_REWARD_ILVL = { [11] = 285, [21] = 292, [22] = 289 }

C_WeeklyRewards = { GetActivities = function(t)
                        return VAULT_ACTIVITIES[t or 1] or {}
                    end,
                    -- Only an unlocked activity offers an example
                    -- reward. A locked one returns nothing, and code
                    -- that assumes otherwise has to cope with that.
                    -- hasData, nextTierID, nextLevel, nextItemLevel.
                    -- Answers only for Mythic+; Plumber records that the
                    -- real one returns false for Delves, and a stub that
                    -- answered for everything would hide that branch.
                    GetNextActivitiesIncrease = function(tierID, level)
                        if tierID ~= 1 or not level or level <= 0 then return false end
                        return true, tierID, level + 2, 302
                    end,
                    GetExampleRewardItemHyperlinks = function(id)
                        local ilvl = VAULT_REWARD_ILVL[id]
                        return ilvl
                            and ("|Hitem:1::::::::80:::ilvl" .. ilvl .. "|h[Vault Reward]|h")
                            or ""
                    end,
                    HasAvailableRewards = function() return false end }
local CURRENCY_LIST = {
    { isHeader = true, name = "Midnight" },
    { name = "Field Accolade", currencyID = 3510, quantity = 483 },
    -- Two weekly-capped currencies, one the character is engaged with
    -- and one it is not. Neither may become a checklist row: what the
    -- client meters is not what the player owes, and the section that
    -- confuses the two fills with chores nobody asked for. Kept in the
    -- fixture because the crest and currency pages DO read these, and
    -- because a filter has to be shown refusing the tempting case as
    -- well as the obvious one.
    { name = "Restored Coffer Key", currencyID = 3512, quantity = 0,
      weekly = { earned = 2, cap = 6 } },
    { name = "Shard of Dundun", currencyID = 3598, quantity = 0,
      weekly = { earned = 0, cap = 10 } },
    { name = "Voidlight Marl", currencyID = 3511, quantity = 41033 },
    -- The five crests, capped CUMULATIVELY: no weekly cap at all, a
    -- season total in maxQuantity, and totalEarned measured against it.
    -- That is how the live client reports them -- dumping the weekly
    -- caps returns two currencies and no crest is either -- and a
    -- fixture without it cannot reach the branch that reads them, so
    -- "have you capped" answered no on a character that had.
    { name = "Adventurer Mistcrest", currencyID = 3442, quantity = 90,
      season = { earned = 300, cap = 300 } },
    { name = "Veteran Mistcrest", currencyID = 3443, quantity = 120,
      season = { earned = 300, cap = 300 } },
    { name = "Champion Mistcrest", currencyID = 3444, quantity = 100,
      season = { earned = 180, cap = 300 } },
}
C_CurrencyInfo = { GetCurrencyInfo = function(id)
                       -- Weekly fields, which the LIST info does not
                       -- carry: quantityEarnedThisWeek against
                       -- maxWeeklyQuantity is how the client tracks a
                       -- weekly allowance, and it is worth more than any
                       -- cap copied out of a guide.
                       for _, e in ipairs(CURRENCY_LIST) do
                           if e.currencyID == id then
                               return { name = e.name, quantity = e.quantity or 0,
                                        iconFileID = 134400,
                                        maxWeeklyQuantity =
                                            e.weekly and e.weekly.cap or 0,
                                        quantityEarnedThisWeek =
                                            e.weekly and e.weekly.earned or 0,
                                        maxQuantity =
                                            e.season and e.season.cap or 0,
                                        totalEarned =
                                            e.season and e.season.earned or 0,
                                        useTotalEarnedForMaxQty =
                                            e.season ~= nil }
                           end
                       end
                       return { name = "C", quantity = 0, iconFileID = 134400 } end,
                   -- A short list with one entry the planner looks up by
                   -- name. At length zero every name lookup answers nil,
                   -- so the lookup and everything built on it would read
                   -- as covered while never having matched anything.
                   GetCurrencyListSize = function() return #CURRENCY_LIST end,
                   GetCurrencyListInfo = function(i)
                       local e = CURRENCY_LIST[i]
                       if not e then return nil end
                       return { name = e.name, currencyID = e.currencyID,
                                quantity = e.quantity or 0,
                                isHeader = e.isHeader or false,
                                isTypeUnused = false, iconFileID = 134400 }
                   end }
C_EncounterJournal = { GetInstanceInfo = function() return "Instance" end }
C_AddOns = { GetAddOnMetadata = function() return "3.0.6" end,
             IsAddOnLoaded = function() return true end,
             LoadAddOn = function() return true end }
C_UnitAuras = { GetAuraDataByIndex = function() return nil end }
C_Map = { GetBestMapForUnit = function() return 1 end }
C_TooltipInfo = { GetItemByID = function() return nil end }
C_PlayerInfo = { GetName = function() return "Tester" end,
                 -- Scores on every map, so the icon row, the group
                 -- cells and the Rating Goals focus list each have
                 -- something to lay out instead of eight dashes.
                 GetPlayerMythicPlusRatingSummary = function()
                     local runs = {}
                     for i, id in ipairs(MPLUS_ORDER) do
                         runs[i] = { challengeModeID = id,
                                     mapScore = 180 + i * 20,
                                     bestRunLevel = 8 + i,
                                     finishedSuccess = true }
                     end
                     return { currentSeasonScore = 2180, runs = runs }
                 end }
C_Widget = { IsFrameWidget = function() return true end }
C_ScriptedAnimations = {}
C_Social = {}
C_LFGList = {}
-- The catch-all answers 1 to every enum member, which is harmless until
-- code uses several members of one enum to tell things APART. The vault
-- reads three activity types out of this one; all three came back as 1,
-- so Mythic+, Raid and World were literally the same query and the
-- dashboard could not have shown three different rows even with data.
local ENUM_EXACT = {
    WeeklyRewardChestThresholdType = { Activities = 1, World = 2, Raid = 3 },
}
Enum = setmetatable({}, { __index = function(_, k)
    if ENUM_EXACT[k] then return ENUM_EXACT[k] end
    return setmetatable({}, { __index = function() return 1 end })
end })
Settings = { RegisterAddOnCategory = function() end,
             RegisterCanvasLayoutCategory = function() return { ID = 1 } end,
             OpenToCategory = function() end }
SlashCmdList = {}
"""


# Things Lua 5.5 rejects that Lua 5.1 -- the client's runtime -- accepts.
# The only one so far: 5.5 makes a for-in control variable const, and
# reassigning one inside the loop is ordinary 5.1 code.
DIVERGENCES = (
    "attempt to assign to const variable",
)


def is_version_divergence(err):
    return any(d in str(err) for d in DIVERGENCES)


LC_DATA_FILES = [
    os.path.join("Features", "Raid", "RaidGuideData.lua"),
    os.path.join("Features", "Raid", "RaidTrainerScenarios.lua"),
]


def toc_files():
    toc = os.path.join(ROOT, "YippYappHelper.toc")
    out = []
    for line in open(toc, encoding="utf-8-sig"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.lower().endswith(".lua"):
            out.append(line.replace("\\", os.sep))
    return out


def main():
    L = LuaRuntime(unpack_returned_tuples=False)
    L.execute("_G = _G or _ENV")
    L.execute(PRELUDE)
    # One shared namespace table for every file, exactly as the client's
    # own `local _, ns = ...` hands each addon file the same table.
    ns = L.eval("{}")

    # Both helpers hand back a single string (the error) or nil. Keeping
    # every Lua->Python boundary single-valued is what stops lupa's
    # tuple marshalling from surfacing as a fake addon failure.
    compile_lua = L.eval("""
        function(src, name)
            local chunk, err = load(src, name)
            if chunk then return nil end
            return tostring(err)
        end
    """)
    run_lua = L.eval("""
        function(src, name, ns)
            local chunk = load(src, name)
            if not chunk then return "could not compile" end
            local ok, err = pcall(chunk, "YippYappHelper", ns)
            if ok then return nil end
            return tostring(err)
        end
    """)

    files = toc_files()
    failures = []
    for rel in files:
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            print("MISSING  %s" % rel)
            failures.append((rel, "file not found"))
            continue
        src = open(path, encoding="utf-8-sig").read()
        # Addon files are varargs chunks: `local _, ns = ...`
        # Both steps return a single string or nil, never a tuple: lupa
        # cannot marshal Lua's multiple returns back to Python cleanly,
        # and a marshalling failure here would read as an addon error.
        syntax_err = compile_lua(src, "@" + rel)
        if syntax_err and is_version_divergence(syntax_err):
            # Not an addon bug. lupa gives us Lua 5.5; WoW runs 5.1, and
            # the two disagree on a couple of points that are legal in
            # the client. Reporting these would push someone into
            # "fixing" code that works.
            print("SKIP     %s\n         5.1/5.5 divergence: %s" % (rel, syntax_err))
            continue
        if syntax_err:
            print("SYNTAX   %s\n         %s" % (rel, syntax_err))
            failures.append((rel, "syntax: %s" % syntax_err))
            continue

        load_err = run_lua(src, "@" + rel, ns)
        if load_err:
            print("LOAD     %s\n         %s" % (rel, load_err))
            failures.append((rel, load_err))

    print("\n%d/%d files loaded clean" % (len(files) - len(failures), len(files)))

    # ── Phase 2: actually draw the pages ────────────────────────
    #
    # Loading proves the files parse and their top-level code runs. It
    # does NOT touch the render functions, which is where the layout
    # work lives -- and a page can load perfectly and still throw the
    # moment it is asked to draw.
    print("\nrender paths:")
    call = L.eval("""
        function(ns, path, a, b, c)
            local fn, recv = ns, nil
            for part in path:gmatch("[^%.]+") do
                recv = fn
                fn = fn and fn[part]
                if fn == nil then return "absent" end
            end
            if type(fn) ~= "function" then return "not a function" end
            local ok, err = pcall(fn, recv, a, b, c)
            if ok then return nil end
            return tostring(err)
        end
    """)

    host = L.eval("""
        (function()
            local h = CreateFrame("Frame")
            h:SetSize(760, 520)
            return h
        end)()
    """)

    # Mythic+ and Teleports both open their refresh with
    #   if not frame:IsShown() then return end
    # and both frames are created hidden. Every "ok" those two have ever
    # printed was a pcall over that one line -- the check could not fail,
    # which is worse than not having it. Show them first, so the refresh
    # below is a render and the geometry read afterwards has something
    # real to read.
    L.eval("""
        function(ns)
            for _, key in ipairs({ "MythicPlusFrame", "TeleportFrame" }) do
                local f = ns[key]
                if f and f.Show then f:Show() end
            end
        end
    """)(ns)

    # Every page whose layout this change touched, plus the ones that
    # share the widgets it changed.
    checks = [
        # Built lazily on first use, so it has to be asked for before
        # anything downstream can look at it.
        ("CreateLootBrowserFrame",    None, None, None),
        ("BisUI.BuildInto",           host, None, None),
        ("BisUI.Refresh",             None, None, None),
        ("SetConsumablesAppMode",     True, 760, 520),
        ("RefreshConsumables",        None, None, None),
        ("SetProgressionAppMode",     True, None, None),
        ("SetTeleportAppMode",        True, 760, 520),
        ("RefreshTeleports",          None, None, None),
        ("SetMythicPlusAppMode",      True, 760, 520),
        ("RefreshMythicPlus",         None, None, None),
        # Both sub-tabs, and Home last on purpose: the tab switch redraws
        # the page, and the geometry phase below reads whatever the final
        # render left behind. Guild draws no section cards, so ending
        # there would leave that check with nothing to measure.
        ("SetMythicPlusTab",          "guild", None, None),
        ("SetMythicPlusTab",          "home", None, None),
        ("SetLootBrowserAppMode",     True, 760, 520),
        ("SetRaidAppMode",            True, 760, 520),
        # The Boss Guide builds lazily on its first sub-tab open, so this
        # is the only call that constructs it. Guide last, then back to
        # Overview: the guide's card layout is what the geometry phase
        # below should be reading, but leaving the page on a tab the
        # player never chose would misrepresent the default state to
        # every check after it.
        ("SetRaidPageTab",            "guide", None, None),
        ("SetRaidPageTab",            "overview", None, None),
    ]
    for path, a, b, c in checks:
        err = call(ns, path, a, b, c)
        if err == "absent":
            print("  --   ns:%s (not defined)" % path)
        elif err:
            print("  FAIL ns:%s\n       %s" % (path, err))
            failures.append((path, str(err)))
        else:
            print("  ok   ns:%s" % path)

    # ── Phase 3: is the indented background actually gone? ──────
    #
    # The complaint was that pages carried a recessed panel of their own
    # inside the shell's. The cause was SetBackdrop(nil) leaving the
    # skin's inner shadow behind -- four gradient textures that are not
    # part of the backdrop. So this is checkable rather than a matter of
    # taste: after a page enters app mode, none of those textures may
    # still be shown.
    print("\nindented background (skin leftovers after app mode):")

    # Negative control, first. A check that cannot fail proves nothing,
    # and this one would pass vacuously if the stubs never recorded a
    # shadow as shown. So: skin a frame, confirm the check SEES the
    # leftover, then Unskin it and confirm the leftover goes.
    control = L.eval("""
        function(ns)
            local probe = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            probe:SetSize(200, 100)
            ns.Widgets:Apply(probe, "panel")
            local skinned = probe._yyhShadow ~= nil
            local shownAfterSkin = false
            if probe._yyhShadow then
                for _, t in pairs(probe._yyhShadow) do
                    if t:IsShown() then shownAfterSkin = true end
                end
            end
            ns.Widgets:Unskin(probe)
            local shownAfterUnskin = false
            if probe._yyhShadow then
                for _, t in pairs(probe._yyhShadow) do
                    if t:IsShown() then shownAfterUnskin = true end
                end
            end
            if not skinned then return "skin drew no shadow -- check is vacuous" end
            if not shownAfterSkin then return "shadow never showed -- check is vacuous" end
            if shownAfterUnskin then return "Unskin did NOT hide the shadow" end
            return nil
        end
    """)
    ctl = control(ns)
    if ctl:
        print("  FAIL control: %s" % ctl)
        failures.append(("control", str(ctl)))
    else:
        print("  ok   control: skin shows shadow, Unskin hides it")
    leftovers = L.eval("""
        function(ns, key)
            local f = ns[key]
            if not f then return "absent" end
            local bad = {}
            local function count(store, label)
                if not store then return end
                for k, tex in pairs(store) do
                    if k ~= "corners" and type(tex) == "table"
                       and tex.IsShown and tex:IsShown() then
                        table.insert(bad, label)
                        return
                    end
                end
            end
            count(f._yyhShadow, "innerShadow")
            count(f._yyhEdge, "hairline")
            if f._yyhFill and f._yyhFill:IsShown() then
                table.insert(bad, "fill")
            end
            if #bad == 0 then return nil end
            return table.concat(bad, ", ")
        end
    """)
    for key in ("ConsumablesFrame", "ProgressionFrame", "TeleportFrame",
                "MythicPlusFrame", "LootBrowserFrame", "RaidFrame"):
        bad = leftovers(ns, key)
        if bad == "absent":
            print("  --   ns.%s (not built)" % key)
        elif bad:
            print("  FAIL ns.%s still showing: %s" % (key, bad))
            failures.append((key, "skin leftover: %s" % bad))
        else:
            print("  ok   ns.%s clean" % key)

    # ── Phase 4: geometry, from the addon's own numbers ─────────
    #
    # Not a mockup. These are the coordinates the page actually computed
    # during the render above, read back off the stub frames. It is the
    # closest thing to looking at the page that is available without the
    # client, and it catches precisely the bugs that were reported:
    # cards overlapping each other, and content running past its region.
    print("\ngeometry (from the render above, not a reconstruction):")

    rects = L.eval("""
        function(pool, n)
            -- Each of these is anchored TOPLEFT to its content frame and
            -- then given an explicit size, so the rect is readable
            -- straight off the recorded anchor without a full solver.
            local out = {}
            for i = 1, n do
                local f = pool[i]
                if f and f:IsShown() and f._pts and f._pts[1] then
                    local p = f._pts[1]
                    out[#out + 1] = string.format("%d,%d,%d,%d",
                        math.floor(p.x), math.floor(p.y),
                        math.floor(f:GetWidth() or 0), math.floor(f:GetHeight() or 0))
                end
            end
            return table.concat(out, ";")
        end
    """)

    def parse(blob):
        if not blob:
            return []
        return [tuple(int(v) for v in r.split(",")) for r in blob.split(";")]

    def report(label, boxes, region_w, region_h=None):
        if not boxes:
            print("  --   %s (nothing drawn)" % label)
            return
        # Default every box into one group when no parent tag is present.
        boxes = [b if len(b) == 5 else (b + (0,)) for b in boxes]
        bad = []
        for i, (x1, y1, w1, h1, g1) in enumerate(boxes):
            if region_w and x1 + w1 > region_w + 1:
                bad.append("box %d runs %dpx past the %dpx region"
                           % (i + 1, x1 + w1 - region_w, region_w))
            # y counts downward from 0 as a negative number, so a box's
            # bottom is -(y - h). None of these pages scroll: past the
            # bottom edge is simply not drawn, and filling a page is
            # precisely the change most likely to run off it.
            if region_h and -(y1 - h1) > region_h + 1:
                bad.append("box %d runs %dpx below the %dpx region"
                           % (i + 1, -(y1 - h1) - region_h, region_h))
            for j, (x2, y2, w2, h2, g2) in enumerate(boxes[i + 1:], i + 1):
                if g1 != g2:
                    continue    # different containers; only one is ever shown
                # y is negative-downward in WoW's anchor space.
                xo = min(x1 + w1, x2 + w2) - max(x1, x2)
                yo = min(y1, y2) - max(y1 - h1, y2 - h2)
                if xo > 1 and yo > 1:
                    bad.append("box %d and %d overlap by %dx%dpx"
                               % (i + 1, j + 1, xo, yo))
        if bad:
            for b in bad:
                print("  FAIL %s: %s" % (label, b))
            failures.extend((label, b) for b in bad)
        else:
            print("  ok   %s: %d boxes, no overlap, none past the region"
                  % (label, len(boxes)))

    # Tagged with a parent id. A pool can be shared across sibling
    # containers -- Consumables draws Enchants, Gems and Consumables into
    # three separate frames, only one visible at a time -- and cards in
    # DIFFERENT parents occupying the same coordinates are not
    # overlapping, they are alternatives. Comparing across parents
    # reports a page-wide collision that does not exist.
    pool_rects = L.eval("""
        function(pool, n)
            local out, ids, next_id = {}, {}, 0
            for i = 1, n do
                local f = pool[i]
                if f and f:IsShown() and f._pts and f._pts[1] then
                    local p = f._pts[1]
                    local par = f:GetParent()
                    if par and not ids[par] then
                        next_id = next_id + 1
                        ids[par] = next_id
                    end
                    out[#out + 1] = string.format("%d,%d,%d,%d,%d",
                        math.floor(p.x or 0), math.floor(p.y or 0),
                        math.floor(f:GetWidth() or 0), math.floor(f:GetHeight() or 0),
                        par and ids[par] or 0)
                end
            end
            return table.concat(out, ";")
        end
    """)

    # The Best in Slot stat priority cards: the row that was overlapping
    # by ten pixels because the card was drawn around the text instead of
    # the text being inset into the card.
    # Control: the geometry the OLD code produced. The card was anchored
    # 12px out around its text while the gap between text columns was
    # only 14, so two cards bled into each other by ten pixels. If the
    # detector below cannot see that, it cannot vouch for the fix either.
    inner, old_gap, old_pad = 756, 14, 12
    old_col_w = (inner - old_gap) // 2
    old_boxes = [(12 + i * (old_col_w + old_gap) - old_pad, 0,
                  old_col_w + old_pad * 2, 62) for i in range(2)]
    before = len(failures)
    report("control (old overlapping layout)", old_boxes, None)
    if len(failures) > before:
        print("       ^ expected: the detector sees the old bug, so a pass below is real")
        del failures[before:]
    else:
        print("  FAIL control did NOT catch the known overlap -- check is vacuous")
        failures.append(("geometry control", "detector missed a known overlap"))

    bis_n = L.eval("function(ns) return (ns.BisUI and ns.BisUI._cardIdx) or 0 end")(ns)
    bis_pool = L.eval("function(ns) return (ns.BisUI and ns.BisUI._cards) or {} end")(ns)
    report("BiS cards (Catalyst note, then stat priority)",
           parse(pool_rects(bis_pool, bis_n)), None)

    # The stat priority has to be ON the page, not below it.
    #
    # Rendered for RESTORATION druid, not the Balance the stub player is.
    # That distinction is the whole check. The BiS list is drawn beside
    # the doll and the cards go under whichever column runs longer, so
    # the failure needs a long list -- and list length is guide data,
    # which differs per spec. Balance ships exactly 16 entries for 16
    # slots and overflows by nothing, so every geometry check this
    # harness has ever run on this page was run against the one spec
    # that cannot exhibit the bug. Restoration ships 24 for 16 and is
    # the worst in the file; Mistweaver is next at 22.
    #
    # Height, not width: this is the one page whose overflow runs
    # downward, and the region is the host it was rendered into.
    spec_swap = L.eval("""
        function(ns, key)
            local real = ns.PlayerSpecKey
            ns.PlayerSpecKey = function() return key, key end
            if ns.BisUI and ns.BisUI.Refresh then pcall(ns.BisUI.Refresh, ns.BisUI) end
            return real
        end
    """)
    spec_restore = L.eval("""
        function(ns, real)
            ns.PlayerSpecKey = real
            if ns.BisUI and ns.BisUI.Refresh then pcall(ns.BisUI.Refresh, ns.BisUI) end
        end
    """)

    real_spec = spec_swap(ns, "DRUID_RESTORATION")
    worst_n = L.eval("function(ns) return (ns.BisUI and ns.BisUI._cardIdx) or 0 end")(ns)
    worst_pool = L.eval("function(ns) return (ns.BisUI and ns.BisUI._cards) or {} end")(ns)
    worst_rows = L.eval("function(ns) return (ns.BisUI and ns.BisUI._rowIdx) or 0 end")(ns)
    report("BiS stat priority stays on the page (Restoration druid, worst list)",
           parse(pool_rects(worst_pool, worst_n)), None, 520)
    # The row count is the assertion behind the assertion: 16 wearable
    # slots and nothing pinned means 16 rows. If "Also listed" ever
    # starts carrying the guide's surplus again this goes to 24 and the
    # geometry above follows it off the page.
    if worst_rows == 16:
        print("  ok   BiS list is the slot count, not the guide's surplus (16 rows)")
    else:
        print("  FAIL BiS list drew %d rows for 16 slots with nothing pinned" % worst_rows)
        failures.append(("BiS also-listed", "%d rows for 16 slots" % worst_rows))

    # The list's two columns have to share the row, not overlap in it.
    #
    # The name was sized against a flat 46px reserve for the source while
    # the source had no width at all -- it was anchored to the right edge
    # and grew leftward under the name. And neither had word wrap turned
    # off, so a long name wrapped to a second line inside a ROW_H row and
    # printed it through the row below. Both halves of that are what the
    # screenshot of a Restoration list showed.
    row_fit = L.eval("""
        function(ns)
            local rows, n = ns.BisUI._rows or {}, ns.BisUI._rowIdx or 0
            local bad, checked = {}, 0
            for i = 1, n do
                local r = rows[i]
                if r and r:IsShown() and r.name and r.source then
                    checked = checked + 1
                    local w = r:GetWidth() or 0
                    local used = 26 + (r.name:GetWidth() or 0) + (r.source:GetWidth() or 0)
                    if used > w + 1 then
                        bad[#bad + 1] = ("row %d: %dpx of text in a %dpx row"):format(i, used, w)
                    end
                    if r.name._wrap ~= false then
                        bad[#bad + 1] = ("row %d: name still wraps"):format(i)
                    end
                    local txt = r.source:GetText() or ""
                    if txt:find("(Raid)", 1, true) then
                        bad[#bad + 1] = ("row %d: source still says (Raid)"):format(i)
                    end
                    -- Colour codes are |c/|r and legitimate. A bare pipe
                    -- anywhere else is guide data reaching the renderer
                    -- as an escape sequence.
                    local stripped = txt:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                    if stripped:find("|", 1, true) then
                        bad[#bad + 1] = ("row %d: raw pipe in source %q"):format(i, stripped)
                    end
                end
            end
            if checked == 0 then return "no rows drawn" end
            if #bad > 0 then return table.concat(bad, "; ") end
            return "ok:" .. checked
        end
    """)(ns)
    if isinstance(row_fit, str) and row_fit.startswith("ok:"):
        print("  ok   BiS rows: name and source share the row (%s rows, no wrap, "
              "no (Raid), no raw pipes)" % row_fit[3:])
    else:
        print("  FAIL BiS rows: %s" % row_fit)
        failures.append(("BiS row fit", str(row_fit)))


    # The tooltip fires over the item NAME, not over the whole row.
    #
    # A row is the width of the column; a name is not. Hung off the row,
    # the tooltip fired over the empty half of every line -- and it made
    # a second hoverable thing in the same row impossible, which is what
    # a clickable source column would need.
    hover_fit = L.eval("""
        function(ns)
            local rows, n = ns.BisUI._rows or {}, ns.BisUI._rowIdx or 0
            local bad, checked, slack = {}, 0, 0
            for i = 1, n do
                local r = rows[i]
                if r and r:IsShown() and r.name then
                    local h = r.name._yyHover
                    if not h or not h:IsShown() then
                        bad[#bad + 1] = ("row %d: no hover target on the name"):format(i)
                    elseif not h:IsMouseEnabled() then
                        bad[#bad + 1] = ("row %d: hover target takes no mouse"):format(i)
                    elseif (h:GetFrameLevel() or 0) <= (r:GetFrameLevel() or 0) then
                        bad[#bad + 1] = ("row %d: hover target is not above the row"):format(i)
                    else
                        checked = checked + 1
                        -- The point of the change: narrower than the row.
                        local rw, hw = r:GetWidth() or 0, h:GetWidth() or 0
                        if hw > rw - 20 then
                            bad[#bad + 1] = ("row %d: hover is %dpx of a %dpx row"):format(i, hw, rw)
                        end
                        slack = slack + (rw - hw)
                    end
                    if r:GetScript("OnEnter") then
                        bad[#bad + 1] = ("row %d: the row itself still opens a tooltip"):format(i)
                    end
                end
            end
            -- Faults first. Reporting "no rows drawn" ahead of them hid
            -- the actual reason: a run with no hover targets at all
            -- never increments `checked`, so the count is zero BECAUSE
            -- of the fault, not instead of it.
            if #bad > 0 then return table.concat(bad, "; ") end
            if checked == 0 then return "no rows drawn" end
            return ("ok:%d:%d"):format(checked, math.floor(slack / checked))
        end
    """)(ns)
    if isinstance(hover_fit, str) and hover_fit.startswith("ok:"):
        n_rows, avg = hover_fit[3:].split(":")
        print("  ok   BiS hover follows the item name (%s rows, %spx of each row "
              "no longer triggers it)" % (n_rows, avg))
    else:
        print("  FAIL BiS hover target: %s" % hover_fit)
        failures.append(("BiS hover target", str(hover_fit)))

    spec_restore(ns, real_spec)

    # The Catalyst note is drawn in the doll's middle column, in the gap
    # between the two runs of slot icons -- and that gap is measured off
    # iconSize, which scales with the region. So it closes the moment the
    # icons grow, which is exactly the class of arithmetic that left a
    # whole empty row under the doll for as long as it did.
    #
    # Cards and icons are both parented to the page's content frame, so
    # the two pools land in one group and comparing them is fair.
    icon_n = L.eval("function(ns) return (ns.BisUI and ns.BisUI._iconIdx) or 0 end")(ns)
    icon_pool = L.eval("function(ns) return (ns.BisUI and ns.BisUI._icons) or {} end")(ns)
    report("BiS Catalyst note clears the doll's slots",
           parse(pool_rects(bis_pool, bis_n))
           + parse(pool_rects(icon_pool, icon_n)), None)

    # The Mythic+ Home cards. Two columns that each flow their own stack,
    # so the failure worth catching is a column cursor that does not
    # clear the card above it.
    #
    # Control: what that page produces if EndCard hands back the content
    # cursor instead of the card's bottom edge. A card's body runs
    # SEC_PAD past its last row, so the next card in the column starts
    # eight pixels inside the one above it -- a clean overlap, and small
    # enough that a detector could plausibly miss it.
    sec_title, sec_pad = 24, 8
    bad_boxes, cy = [], 0
    for body in (60, 90):
        bad_boxes.append((0, cy, 300, sec_title + body + sec_pad * 2))
        cy -= sec_title + body + sec_pad        # the card's own bottom pad, dropped
    #
    # Run against a deliberately small region as well, so the same
    # control also proves the width and bottom-edge detectors fire. The
    # bottom one is new, and a page being filled up is exactly when an
    # overflow check has to work.
    before = len(failures)
    report("control (column cursor short by the card's bottom pad)",
           bad_boxes, 200, 100)
    caught = [b for _, b in failures[before:]]
    del failures[before:]
    if (any("overlap" in b for b in caught) and any("past" in b for b in caught)
            and any("below" in b for b in caught)):
        print("       ^ expected: overlap, past-width and below-bottom all seen")
    else:
        print("  FAIL control missed one of overlap/width/bottom -- check is vacuous")
        failures.append(("mplus geometry control", "detector missed a known failure"))

    mp_n = L.eval(
        "function(ns) return (ns.MythicPlusFrame and ns.MythicPlusFrame._sectionCount) or 0 end")(ns)
    mp_pool = L.eval(
        "function(ns) return (ns.MythicPlusFrame and ns.MythicPlusFrame._sections) or {} end")(ns)
    # Width from the frame; height from the budget the page itself
    # spent, so the check measures the layout against its own stated
    # room rather than against a second guess at what that room was.
    mp_w = L.eval("""
        function(ns)
            local f = ns.MythicPlusFrame
            local pad = (ns.Shell and ns.Shell.PAD) or 12
            return f and math.floor((f:GetWidth() or 0) - pad * 2) or 0
        end
    """)(ns)
    mp_h = L.eval(
        "function(ns) return math.floor((ns.MythicPlusFrame or {})._contentH or 0) end")(ns)
    report("Mythic+ Home cards", parse(pool_rects(mp_pool, mp_n)),
           mp_w or None, mp_h or None)

    # The Boss Guide. Two cards whose heights are solved from measured
    # wrapped text -- the pinned rules, and the one phase you are reading
    # -- laid into a scroll frame, with a pager strip between them.
    #
    # Every boss, both difficulties, and EVERY PAGE. The page count comes
    # from the data, so a boss with eight phases has eight arrangements
    # and only one of them is the default; a phase card sized around the
    # wrong cursor would be invisible on page one.
    #
    # The pager itself is checked by arithmetic rather than by eye: the
    # last page must be reachable, one past it must clamp back to it, and
    # the Heroic page must exist exactly when the boss has heroic lines
    # or is marked as unrecorded.
    print("\nboss guide pages (every boss, both difficulties, every page):")
    guide_pool = L.eval("function(ns) return (ns.RaidGuideUI and ns.RaidGuideUI._cards) or {} end")(ns)
    pick = L.eval("""
        function(ns, bossId, heroic, page)
            local UI = ns.RaidGuideUI
            if not (UI and UI.SetPage) then return "absent" end
            YippYappHelperDB = YippYappHelperDB or {}
            YippYappHelperDB.raidGuide = YippYappHelperDB.raidGuide or {}
            YippYappHelperDB.raidGuide.boss = bossId
            YippYappHelperDB.raidGuide.heroic = heroic
            -- Refresh first: the page resets to 1 when the boss changes,
            -- and SetPage on the boss we are LEAVING would be measured
            -- against the wrong data.
            local ok, err = pcall(UI.Refresh, UI)
            if not ok then return tostring(err) end
            ok, err = pcall(UI.SetPage, UI, page)
            if not ok then return tostring(err) end
            return (UI._cardIdx or 0) .. "," .. (UI:GetPageCount() or 0)
        end
    """)
    plan = L.eval("""
        function(ns)
            local out = {}
            for _, b in ipairs(ns.RaidGuide and ns.RaidGuide:Ordered() or {}) do
                local phases = b.phases and #b.phases or 0
                local heroicLines = b.heroic and #b.heroic or 0
                out[#out + 1] = table.concat({
                    b.id, phases, heroicLines,
                    b.heroicUnknown and 1 or 0,
                }, ":")
            end
            return table.concat(out, ",")
        end
    """)(ns)
    for spec in (plan or "").split(","):
        if not spec:
            continue
        boss_id, phases, heroic_lines, unknown = spec.split(":")
        phases, heroic_lines, unknown = int(phases), int(heroic_lines), int(unknown)
        for heroic in (False, True):
            want = phases + (1 if heroic and (heroic_lines or unknown) else 0)
            label = "%s/%s" % (boss_id, "heroic" if heroic else "normal")
            # One past the end on purpose: the clamp is the thing that
            # stops Next walking off a shorter boss's page list.
            for page in range(1, want + 2):
                got = pick(ns, boss_id, heroic, page)
                if not isinstance(got, str) or "," not in got:
                    print("  FAIL %s page %d: %s" % (label, page, got))
                    failures.append((label, str(got)))
                    continue
                n, count = (int(v) for v in got.split(","))
                if count != want:
                    msg = "%d pages, expected %d" % (count, want)
                    print("  FAIL %s: %s" % (label, msg))
                    failures.append((label, msg))
                    break
                # Overlap only, and deliberately.
                #
                # A vertical fit assertion was tried here and taken out
                # again: the cards sit inside a ScrollFrame, so content
                # taller than the view scrolls rather than being lost,
                # and the check failed on every page for a thing that is
                # not a defect.
                #
                # It also could not have been trusted even where it did
                # apply. The stub under-resolves widths -- a card that is
                # about 530 wide in game reports 168 -- so paragraphs
                # wrap about three times too often and every measured
                # height is inflated to match. Fixing that means a real
                # two-pass layout solver, not a better guess.
                boxes = parse(pool_rects(guide_pool, n))
                if len(boxes) < 2 and want > 0:
                    msg = "page %d drew %d cards" % (page, len(boxes))
                    print("  FAIL %s: %s" % (label, msg))
                    failures.append((label, msg))
                    break
                bad_before = len(failures)
                report("guide %s page %d/%d" % (label, min(page, want), want),
                       boxes, None)
                if len(failures) > bad_before:
                    break

    # The rail's Bloodlust block, and the button that follows it.
    #
    # Everything else in the rail sits at an offset decided at build
    # time. This one block wraps to a different height per boss -- "on
    # pull" against "the intermission, while Zul'jin takes double damage"
    # -- so the button under it is re-anchored on every render against a
    # measured string. That is the arrangement that silently drifts, so
    # the claim is checked: the button must always start below the text.
    print("\nrail reflow (Bloodlust block -> practise button):")
    rail = L.eval("""
        function(ns, bossId)
            local UI = ns.RaidGuideUI
            if not (UI and UI.Refresh) then return "absent" end
            YippYappHelperDB = YippYappHelperDB or {}
            YippYappHelperDB.raidGuide = YippYappHelperDB.raidGuide or {}
            YippYappHelperDB.raidGuide.boss = bossId
            local ok, err = pcall(UI.Refresh, UI)
            if not ok then return tostring(err) end
            local boss = ns.RaidGuide:Get(bossId)
            -- -1 means "this boss has no Bloodlust row at all", which is
            -- not the same as "its row is zero high". The button moves UP
            -- into the space when there is nothing to sit below, so there
            -- is no overlap to check for -- and comparing against the
            -- hidden label's old anchor measured the PREVIOUS boss.
            local h = (boss and boss.lust)
                and (UI._lustText:GetStringHeight() or 12) or -1
            -- y counts downward as a negative number, so "below" is less.
            return string.format("%d,%d,%d", UI._lustTop or 0, h, UI._railY or 0)
        end
    """)
    seen_offsets = set()
    for spec in (plan or "").split(","):
        if not spec:
            continue
        boss_id = spec.split(":")[0]
        got = rail(ns, boss_id)
        if not isinstance(got, str) or "," not in got:
            print("  FAIL %s: %s" % (boss_id, got))
            failures.append(("rail reflow", str(got)))
            continue
        top, text_h, button_y = (int(v) for v in got.split(","))
        if text_h < 0:
            # No Bloodlust row on this boss, so nothing for the button to
            # clear. Still counted as a distinct offset, because "the
            # button moved up into the empty space" is itself part of the
            # reflow this check exists to prove.
            seen_offsets.add(button_y)
            continue
        floor = top - max(text_h, 20)
        if button_y > floor:
            msg = ("%s: button at %d, above the text's bottom at %d"
                   % (boss_id, button_y, floor))
            print("  FAIL %s" % msg)
            failures.append(("rail reflow", msg))
        else:
            seen_offsets.add(button_y)
    if seen_offsets:
        print("  ok   %d bosses, button always below the text (%d distinct offsets)"
              % (len(plan.split(",")), len(seen_offsets)))

    # ── Phase 5: behaviour, not appearance ──────────────────────
    #
    # Two of the reported problems are not visual at all. "The loot
    # council order is wrong" is a claim about a sort, and "trinkets can
    # show more than ten" is a claim about a limit. Both are decidable
    # here against the real data file, with no client involved.
    print("\nbehaviour:")

    # Loot Council: every spec list must run from the strongest claim
    # down. rel is negative-or-zero (0 == this spec's best trinket), so
    # the list is correct when it never increases as you read down it.
    order = L.eval("""
        function(ns)
            local T = ns.Trinkets
            if not (T and T.GetAllTrinkets) then return "Trinkets index absent" end
            pcall(T.Rebuild, T)
            local ok, all = pcall(T.GetAllTrinkets, T, "ST", true)
            if not ok or type(all) ~= "table" then return "no trinket data" end
            local checked, worst = 0, nil
            for _, bucket in ipairs(all) do
                local prev = nil
                for _, e in ipairs(bucket.specs or {}) do
                    if prev and e.rel > prev + 0.0001 then
                        worst = string.format("%s: %.2f%% after %.2f%%",
                            tostring(bucket.name), e.rel, prev)
                    end
                    prev = e.rel
                end
                checked = checked + 1
            end
            if worst then return "OUT OF ORDER " .. worst end
            if checked == 0 then return "no buckets to check" end
            return "ok:" .. checked
        end
    """)(ns)
    if order and str(order).startswith("ok:"):
        print("  ok   loot council: %s trinkets, every spec list descends by rel"
              % str(order)[3:])
    else:
        print("  FAIL loot council: %s" % order)
        failures.append(("loot council order", str(order)))

    # Healers come from QE Live, whose numbers are HPS scores rather than
    # bloodmallet's percent-over-empty. Two things can go wrong quietly
    # and neither shows up as an error: a healer block that never merged
    # into the table at all (the page just says "no sims for you"), and
    # an item-level ranking that ran QE's scores through the percentage
    # arithmetic, which yields plausible-looking numbers that are wrong
    # by a factor of a hundred. Both are decidable here.
    healers = L.eval("""
        function(ns)
            local T = ns.Trinkets
            if not (T and T.GetForSpec) then return "Trinkets index absent" end
            local want = { "DRUID_RESTORATION", "EVOKER_PRESERVATION",
                           "MONK_MISTWEAVER", "PALADIN_HOLY",
                           "PRIEST_DISCIPLINE", "PRIEST_HOLY",
                           "SHAMAN_RESTORATION" }
            local n = 0
            for _, key in ipairs(want) do
                for _, style in ipairs({ "ST", "AOE" }) do
                    local block = T:GetBlock(key, style)
                    if not block then return key .. "/" .. style .. " missing" end
                    if block.provider ~= "qe" then
                        return key .. "/" .. style .. " is not QE data"
                    end
                    local want_profile = (style == "ST") and "Raid" or "Dungeon"
                    if block.profile ~= want_profile then
                        return key .. "/" .. style .. " profile is "
                            .. tostring(block.profile)
                    end
                    if T:StyleLabel(key, style) ~= want_profile then
                        return key .. "/" .. style .. " tab would say "
                            .. tostring(T:StyleLabel(key, style))
                    end
                    -- Ranked at one item level, which is where the unit
                    -- matters. Percent-behind has to stay a percentage:
                    -- QE's raw scores differ by thousands, so anything
                    -- past -100 means the score went out as the answer.
                    local at = T:GetAtItemLevel(key, style, 334)
                    if not at or #at < 2 then
                        return key .. "/" .. style .. " has no 334 ranking"
                    end
                    local prev
                    for _, r in ipairs(at) do
                        if r.rel > 0.0001 or r.rel < -100 then
                            return string.format("%s/%s ranks %s at %.2f%%",
                                key, style, tostring(r.name), r.rel)
                        end
                        if prev and r.rel > prev + 0.0001 then
                            return key .. "/" .. style .. " 334 list is out of order"
                        end
                        prev = r.rel
                    end
                    n = n + 1
                end
            end
            -- A DPS spec must still read as a target count, or the tab
            -- labels have been rewritten for everyone.
            if T:StyleLabel("MAGE_FIRE", "AOE") ~= "AoE" then
                return "a DPS spec's tab stopped saying AoE"
            end
            -- And the two sources have to meet: a trinket both a healer
            -- and a damage spec rank is what makes the tooltip credit
            -- both, and if the ids never overlap the merge is cosmetic.
            local mixed
            for _, bucket in ipairs(T:GetAllTrinkets("ST", true) or {}) do
                local qe, bm = false, false
                for _, e in ipairs(bucket.specs or {}) do
                    if e.provider == "qe" then qe = true else bm = true end
                end
                if qe and bm then mixed = bucket.name break end
            end
            if not mixed then return "no trinket is ranked by both sources" end
            return string.format("ok:%d:%s", n, mixed)
        end
    """)(ns)
    if healers and str(healers).startswith("ok:"):
        n, mixed = str(healers)[3:].split(":", 1)
        print("  ok   healer trinkets: %s QE blocks, percentages stay "
              "percentages, both sources meet on %s" % (n, mixed))
    else:
        print("  FAIL healer trinkets: %s" % healers)
        failures.append(("healer trinkets", str(healers)))

    # An equipped character, so the advisor has something to advise on.
    #
    # The client stubs return no equipment at all, which every check
    # below would happily "pass" against: an empty doll produces an
    # empty plan and an empty panel, and neither the budget arithmetic
    # nor the layout is touched. Overriding ns:GetSlotInfo stubs exactly
    # one thing -- the tooltip scan of a live item -- and leaves
    # CanUpgradeItem, the plan walk, the rules and the render running
    # for real above it.
    #
    # The set is deliberately lopsided: most of it sits on Veteran, at
    # ranks spread across the track, with two slots on Champion. That
    # gives the Veteran wallet more demand than it can meet, which is
    # the only state in which the funded/unfunded split -- the thing the
    # panel is built around -- actually exists.
    fixture = L.eval("""
        function(ns)
            local T = ns.GEAR_TRACKS
            if not (T and T.Veteran and T.Champion) then return "no gear tracks" end

            -- slotID, track, current rank. Ranks below max so every
            -- entry is a live upgrade candidate.
            local SET = {
                { 16, "Veteran",  2 },   -- Main Hand, priority 5
                {  5, "Veteran",  1 },   -- Chest,     priority 4
                {  7, "Veteran",  3 },   -- Legs,      priority 4
                { 13, "Veteran",  1 },   -- Trinket 1, priority 4
                { 11, "Veteran",  4 },   -- Ring 1,    priority 3
                {  2, "Veteran",  5 },   -- Neck,      priority 2
                {  1, "Champion", 1 },   -- Head,      priority 4
                {  6, "Champion", 2 },   -- Waist,     priority 2
                -- Adventurer is the only fixture track that is both
                -- capped and has no uncapped quest-box income, so it is
                -- the only one that can reach the reserve branch. Two
                -- slots, because the reserve is sized per at-risk slot.
                {  3, "Adventurer", 1 }, -- Shoulder,  priority 3
                {  8, "Adventurer", 2 }, -- Feet,      priority 3
                -- A slot parked at rank 1 of a track, with pieces on the
                -- track below it to absorb the cheaper crests: that is
                -- the shape ns:GetCrestWaste fires on, and without it
                -- every check about where warnings sort passes because
                -- no warning is ever produced.
                { 15, "Hero", 1 },       -- Back,      priority 2
            }
            local bySlot = {}
            for _, e in ipairs(SET) do
                local levels = T[e[2]]
                bySlot[e[1]] = {
                    link = "|cffa335ee|Hitem:1::::::::80:::::|h[Fixture]|h|r",
                    ilvl = levels[e[3]], quality = 4, icon = 134400,
                    track = e[2], rank = e[3], maxRank = #levels,
                    crafted = false,
                }
            end

            ns._realGetSlotInfo = ns.GetSlotInfo
            ns.GetSlotInfo = function(self, slotID) return bySlot[slotID] end
            if ns.InvalidateCrestPlans then ns:InvalidateCrestPlans() end

            -- Prove the override actually reaches the advisor, or every
            -- check below is testing the empty case with extra steps.
            local live = 0
            for _, si in ipairs(ns.SLOT_IDS or {}) do
                if (ns:CanUpgradeItem(si.slot)) then live = live + 1 end
            end
            if live < 9 then
                return "only " .. live .. " of 11 fixture slots read as upgradeable"
            end
            return "ok:" .. live
        end
    """)(ns)
    if fixture and str(fixture).startswith("ok:"):
        print("  ok   gear fixture: %s upgradeable slots across four crest tracks"
              % str(fixture)[3:])
    else:
        print("  FAIL gear fixture: %s" % fixture)
        failures.append(("gear fixture", str(fixture)))

    # The crest budget, and the panel built on it.
    #
    # The old advisor asked "can I afford this" once per slot, from a
    # fresh scan of the other fifteen, so sixteen slots held sixteen
    # private opinions about one wallet -- and none of them answered the
    # question a capped player actually has, which is which upgrades the
    # crests in hand reach. ns:GetCrestPlan spends the budget once and
    # records the order; these check that the record is internally
    # consistent, because every string in the panel is derived from it.
    plan = L.eval("""
        function(ns)
            if not ns.GetCrestPlan then return "GetCrestPlan absent" end

            local checked = 0
            for _, crest in ipairs(ns.CRESTS or {}) do
                local p = ns:GetCrestPlan(crest.track)
                if not p then return "no plan for " .. tostring(crest.track) end
                if p.slotCount == 0 then
                    -- Nothing on this track; there is no budget to test.
                else
                    checked = checked + 1

                    -- Demand must equal what the walk actually queued.
                    -- These are computed by different loops, so a drift
                    -- between them means one of the two is lying.
                    if #p.steps * p.cost ~= p.demand then
                        return crest.track .. ": " .. #p.steps .. " ranks at "
                            .. p.cost .. " is not the stated demand " .. p.demand
                    end

                    -- The walk must be monotonic in cost and must never
                    -- mark a step paid after an unpaid one -- the panel
                    -- draws a single rule at that boundary, so a second
                    -- crossing would put funded rows below the line.
                    local prev, seenUnpaid = 0, false
                    for i, st in ipairs(p.steps) do
                        if st.cumulative ~= prev + p.cost then
                            return crest.track .. ": step " .. i
                                .. " jumps to " .. st.cumulative .. " from " .. prev
                        end
                        prev = st.cumulative
                        if st.paid and seenUnpaid then
                            return crest.track .. ": step " .. i
                                .. " is affordable after one that is not"
                        end
                        if not st.paid then seenUnpaid = true end
                        -- paid implies funded: held is a subset of budget.
                        if st.paid and not st.funded then
                            return crest.track .. ": step " .. i
                                .. " is paid but not funded"
                        end
                    end

                    -- The affordable count is what the panel prints in
                    -- its header, so it must match the steps the walk
                    -- actually marked payable, not a separate division.
                    if p.paidSteps ~= math.min(p.affordableNow, #p.steps) then
                        return crest.track .. ": header says "
                            .. p.affordableNow .. " affordable, the plan paid for "
                            .. p.paidSteps .. " of " .. #p.steps
                    end

                    -- Priority must actually drive the order: the first
                    -- rank bought cannot go to a slot that a higher
                    -- priority slot was also waiting on.
                    local first = p.steps[1]
                    if first then
                        local topPri = ns.SLOT_PRIORITY[first.slotID] or 2
                        for slotID, sum in pairs(p.slots) do
                            if sum.wantedRanks > 0 and (sum.priority or 2) > topPri then
                                return crest.track .. ": spent first on "
                                    .. first.slotName .. " while "
                                    .. sum.slotName .. " ranked higher"
                            end
                        end
                    end

                    -- Per-slot totals have to reconcile with the steps.
                    for slotID, sum in pairs(p.slots) do
                        if sum.paidRanks * p.cost ~= sum.paidCost then
                            return crest.track .. "/" .. sum.slotName
                                .. ": " .. sum.paidRanks .. " paid ranks priced at "
                                .. sum.paidCost
                        end
                        if sum.paidRanks > sum.wantedRanks then
                            return crest.track .. "/" .. sum.slotName
                                .. ": paid for more ranks than it wants"
                        end
                    end
                end
            end
            if checked == 0 then return "no track had anything to upgrade" end
            return "ok:" .. checked
        end
    """)(ns)
    if plan and str(plan).startswith("ok:"):
        print("  ok   crest plan: %s tracks, spend order is priority-first and the "
              "affordable line is where the steps say" % str(plan)[3:])
    else:
        print("  FAIL crest plan: %s" % plan)
        failures.append(("crest plan", str(plan)))

    # The season cap is not the ceiling for Veteran.
    #
    # Quest-box crests do not count against `useTotalEarnedForMaxQty`,
    # so a Veteran track reading 300/300 can still be handed a couple of
    # hundred more this week. Reading the cap alone had the addon tell a
    # capped player to hoard against a wall they were about to walk
    # through. The plan has to carry that headroom separately -- folding
    # it into the affordable count would be a different lie.
    caps = L.eval("""
        function(ns)
            if not ns.GetUncappedCrestIncome then
                return "GetUncappedCrestIncome absent"
            end
            local vet = ns:GetCrestPlan("Veteran")
            if not vet then return "no Veteran plan" end

            -- The fixture has Veteran at 300 of 300 earned.
            if not vet.seasonCapped then
                return "Veteran at 300/300 does not report as capped"
            end
            if (vet.uncapped or 0) <= 0 then
                return "a capped Veteran track reports no uncapped income, so the "
                    .. "panel will tell the player to hoard"
            end
            -- Headroom must stay OUT of the spendable budget: it is an
            -- upper bound over weeklies the addon cannot see the state
            -- of, and spending against it would be inventing crests.
            if vet.budget ~= vet.held + vet.seasonEarnable then
                return "uncapped headroom leaked into the spendable budget"
            end
            local perUpgrade = vet.cost
            if perUpgrade > 0 and vet.affordableNow ~= math.floor(vet.held / perUpgrade) then
                return "affordable count does not match the crests actually held"
            end

            -- A track with no such income must not claim any.
            local champ = ns:GetCrestPlan("Champion")
            if champ and (champ.uncapped or 0) ~= 0 then
                return "Champion claims uncapped income it does not have"
            end
            -- And Champion at 180/300 must not read as capped, or the
            -- capped branch is just answering yes to everything.
            if champ and champ.seasonCapped then
                return "Champion at 180 of 300 reports as capped"
            end
            return "ok"
        end
    """)(ns)
    if caps == "ok":
        print("  ok   crest caps: a capped Veteran track still reports its uncapped "
              "quest-box headroom, and the headroom stays out of the budget")
    else:
        print("  FAIL crest caps: %s" % caps)
        failures.append(("crest caps", str(caps)))

    # Don't hold crests back on a wallet the content has outgrown.
    #
    # The reserve was added for a real failure: crests all spent on deep
    # upgrades, then a capped week with nothing left to put on a new
    # drop. But it protects a FUTURE purchase, and a track whose crests
    # can no longer buy any piece the player will be handed has no
    # future purchase to protect -- every drop arrives on a higher track
    # than those crests are valid for. Holding there just retires item
    # levels the player could be wearing.
    #
    # Worth stating plainly: with the risk thresholds as they stand the
    # live half of this branch is unreachable. The reserve needs a track
    # that is capped, has no uncapped income, and owns a "high" risk
    # slot -- and risk is a gap of 20+ against a ceiling that includes
    # the raid track's MAX, so no Hero slot (305 and up against 321) or
    # Myth slot can ever qualify. Every wallet that could reach the
    # branch was one the player had outgrown, which is precisely where
    # reserving is wrong. The gate stays because it is the correct
    # semantic and the risk model is due to be reconciled against the
    # drop band; the check below pins the gate itself rather than
    # pretending a live reserve can currently be constructed.
    reserve = L.eval("""
        function(ns)
            local adv = ns:GetCrestPlan("Adventurer")
            if not adv then return "no Adventurer plan" end
            -- The preconditions the reserve branch used to fire on are
            -- all still true; only the outgrown gate stops it now. If
            -- any of these stopped holding, this check would be passing
            -- for the wrong reason.
            if not adv.seasonCapped then
                return "the fixture's capped track does not read as capped"
            end
            if (adv.uncapped or 0) ~= 0 then
                return "Adventurer claims uncapped income, so the reserve branch "
                    .. "is unreachable and this check is vacuous"
            end
            if not adv.outgrown then
                return "Adventurer does not read as outgrown, so the gate under "
                    .. "test is not the thing holding the reserve at zero"
            end
            if (adv.reserve or 0) ~= 0 then
                return "an outgrown wallet held " .. adv.reserve
                    .. " back for a drop its crests can never pay for"
            end
            -- The freed crests have to actually reach the plan, or the
            -- fix is cosmetic.
            if adv.spendable ~= adv.held then
                return "outgrown wallet holds " .. adv.held .. " but plans only "
                    .. adv.spendable
            end
            if adv.affordableNow ~= math.floor(adv.held / adv.cost) then
                return "the header advertises " .. adv.affordableNow
                    .. " upgrades from " .. adv.held .. " held"
            end

            -- The gate reads off the drop band, so pin the band too --
            -- a band that collapsed to one number would classify every
            -- track the same way and this would still pass.
            local low, high, lowTrack = ns:GetDropBand()
            if not (low and high and low < high) then
                return "drop band is " .. tostring(low) .. "-" .. tostring(high)
                    .. ", not two distinct sources"
            end
            if ns:GetDropCeiling() ~= high then
                return "the band's high end and GetDropCeiling disagree"
            end
            -- Heroic profile: the raid hands out 305 and a +10 hands out
            -- 311, so everything below Hero is outgrown and Hero itself
            -- is not.
            for _, t in ipairs({ "Adventurer", "Veteran", "Champion" }) do
                if not ns:IsCrestOutgrown(t) then
                    return t .. " should be outgrown at a " .. low .. " drop floor"
                end
            end
            for _, t in ipairs({ "Hero", "Myth" }) do
                if ns:IsCrestOutgrown(t) then
                    return t .. " should not be outgrown at a " .. low .. " drop floor"
                end
            end

            -- Unchanged, and still the other half of the rule: a track
            -- that still earns holds nothing back either.
            local vet = ns:GetCrestPlan("Veteran")
            if vet and (vet.reserve or 0) ~= 0 then
                return "Veteran held crests back despite uncapped income still coming"
            end
            local champ = ns:GetCrestPlan("Champion")
            if champ and (champ.reserve or 0) ~= 0 then
                return "an uncapped track held crests back"
            end
            return string.format("ok:%d:%d:%s", low, high, lowTrack)
        end
    """)(ns)
    if reserve and str(reserve).startswith("ok:"):
        low, high, lowTrack = str(reserve)[3:].split(":")
        print("  ok   crest reserve: content hands out %s-%s (%s), so the three "
              "tracks under it plan every crest and keep none" % (low, high, lowTrack))
    else:
        print("  FAIL crest reserve: %s" % reserve)
        failures.append(("crest reserve", str(reserve)))

    # What is standing between the player and the next discount.
    #
    # GetAchievementProgress splits the remaining slots into ones crests
    # can fix and ones needing a drop, and Rule 5.5 only speaks when the
    # second set is empty -- so the addon computed the blockers and then
    # went silent in exactly the case a player most needs naming. The
    # split is now readable; this pins that it stays coherent, because a
    # blocker quietly reclassified as upgradeable would put the advisor
    # back to promising an achievement that crests cannot reach.
    achieve = L.eval("""
        function(ns)
            local chase = ns:GetChasedAchievement()
            if not chase then return "nothing left to chase on the fixture" end

            local blockers, remaining, cost, upgradeable =
                ns:GetAchievementBlockers(chase.track)
            if remaining ~= chase.remaining then
                return "the chase and the blocker query disagree on how many "
                    .. "slots remain (" .. chase.remaining .. " vs " .. remaining .. ")"
            end
            -- Every remaining slot is one or the other. If these stop
            -- adding up, a slot has gone missing from the advice.
            if #blockers + upgradeable ~= remaining then
                return #blockers .. " blocked plus " .. upgradeable
                    .. " upgradeable is not the " .. remaining .. " remaining"
            end
            -- The fixture leaves most of the doll empty, and an empty
            -- slot cannot be bought up to a threshold. Blockers being
            -- zero here would mean needsReplacement never got set and
            -- the check is passing vacuously.
            if #blockers == 0 then
                return "no slot needs a drop, so the blocked branch is untested"
            end
            for _, b in ipairs(blockers) do
                if not b.slotName or b.slotName == "" then
                    return "a blocker came back without a slot name to print"
                end
                if b.crestCost then
                    return b.slotName .. " is filed as blocked but carries a "
                        .. "crest cost, so it is really upgradeable"
                end
            end
            if cost < 0 then return "negative crest cost" end

            -- The season's own name for the achievement. The ids were
            -- rolled to Season 2 and these strings were not, so the
            -- addon told players to look up an achievement that no
            -- longer matches the one it checks.
            if chase.name ~= chase.track .. " " .. ns.DISCOUNT_ACHIEVEMENT_SUFFIX then
                return "achievement name '" .. chase.name .. "' is not built "
                    .. "from the shared suffix"
            end
            return string.format("ok:%s:%d:%d", chase.track, remaining, #blockers)
        end
    """)(ns)
    if achieve and str(achieve).startswith("ok:"):
        track, remaining, blocked = str(achieve)[3:].split(":")
        print("  ok   achievement blockers: %s is %s slots out, %s of them "
              "wanting a drop rather than crests" % (track, remaining, blocked))
    else:
        print("  FAIL achievement blockers: %s" % achieve)
        failures.append(("achievement blockers", str(achieve)))

    # The panel that started all of this, replayed.
    #
    # A Heroic raider on +10s, 200 Champion in the wallet, and the exact
    # gear the screenshot showed. The shipped advisor spent 160 of it as
    # 60 on the weapon, 60 on one trinket and 40 on the other -- one
    # piece carried to its track cap and two stranded mid-track, which is
    # what a one-rank-at-a-time walk does when it re-picks the best slot
    # after every rank.
    #
    # The same crests finish two pieces and still have change. This is
    # the whole point of planning in runs, so it is pinned as an outcome
    # on real numbers rather than as a property of the scoring.
    accept = L.eval("""
        function(ns)
            local T = ns.GEAR_TRACKS
            local realSlot, realCount = ns.GetSlotInfo, ns.GetCrestCountByTrack

            -- slotID, track, rank -- read off the screenshot.
            local SET = {
                -- Hero, not Champion. Hero caps at 321, above the 311
                -- this character farms in every slot, so its mark
                -- survives and there is a rebate for the pair rule to
                -- withhold. On Champion there is nothing to withhold.
                { 16, "Hero", 3 },   -- Main Hand 311, priority 5
                {  8, "Hero", 3 },   -- Feet      311, priority 3
                { 13, "Hero", 1 },   -- Trinket 1 305, priority 4
                { 14, "Hero", 1 },   -- Trinket 2 305, priority 4
                { 12, "Hero", 1 },   -- Ring 2    305, priority 3
            }
            local bySlot = {}
            for _, e in ipairs(SET) do
                local levels = T[e[2]]
                bySlot[e[1]] = {
                    link = "|cffa335ee|Hitem:1::::::::80:::::|h[Shot]|h|r",
                    ilvl = levels[e[3]], quality = 4, icon = 134400,
                    track = e[2], rank = e[3], maxRank = #levels,
                    crafted = false,
                }
            end
            ns.GetSlotInfo = function(self, slotID) return bySlot[slotID] end
            local wallet = 200
            ns.GetCrestCountByTrack = function(self, track)
                return track == "Hero" and wallet or 0
            end
            ns:InvalidateCrestPlans()

            local function restore(msg)
                ns.GetSlotInfo, ns.GetCrestCountByTrack = realSlot, realCount
                ns:InvalidateCrestPlans()
                return msg
            end

            local p = ns:GetCrestPlan("Hero")
            if not p then return restore("no Hero plan") end
            if p.cost ~= 20 then
                return restore("fixture cost is " .. p.cost .. ", not the 20 the "
                    .. "screenshot's arithmetic assumes")
            end
            -- The reserve fix, seen from the panel: the wallet the plan
            -- talks about is the wallet the player has.
            if p.spendable ~= 200 then
                return restore("plans " .. p.spendable .. " of a 200 crest wallet")
            end

            -- Every crest in hand is allocated, and to whole pieces.
            local paidCost, promoted, byName = 0, {}, {}
            for _, st in ipairs(p.steps) do
                if st.paid then
                    paidCost = paidCost + p.cost
                    byName[st.slotName] = st.toIlvl
                    if st.promotes then
                        promoted[#promoted + 1] = st.slotName
                    end
                end
            end
            if paidCost ~= 200 then
                return restore("spent " .. paidCost .. " of 200 in hand")
            end
            if #promoted ~= 2 then
                return restore("carried " .. #promoted .. " piece(s) to the "
                    .. "Champion cap, not the 2 the same crests reach")
            end
            -- WHICH two is the whole point, and it is not the obvious
            -- pair. Rings and trinkets share one mark taken from the
            -- lower of the two, so carrying a single trinket to 308
            -- while its partner sits at 292 moves nothing -- a hundred
            -- crests for item level on one item and no rebate at all.
            -- Feet is worth less by slot priority and more by outcome,
            -- because Feet is a slot of one.
            if byName["Main Hand"] ~= 321 then
                return restore("Main Hand ends at " .. tostring(byName["Main Hand"])
                    .. ", not the 321 cap")
            end
            if byName["Feet"] ~= 321 then
                return restore("Feet ends at " .. tostring(byName["Feet"])
                    .. ", not the 321 cap -- an unpaired slot is the only "
                    .. "kind that can move a mark on its own here")
            end
            for _, paired in ipairs({ "Trinket 1", "Trinket 2", "Ring 2" }) do
                if byName[paired] == 321 then
                    return restore(paired .. " was carried to its cap alone, "
                        .. "which moves no mark while its partner is lower")
                end
            end
            -- And the change still goes somewhere rather than nowhere.
            if byName["Trinket 1"] ~= 318 then
                return restore("Trinket 1 ends at " .. tostring(byName["Trinket 1"])
                    .. ", not the 318 the last 80 crests reach")
            end

            -- Given enough for BOTH halves, the pair is worth finishing
            -- and the plan says so. Without this the rule above could be
            -- passing by never funding a trinket at all.
            wallet = 600
            ns:InvalidateCrestPlans()
            local rich = ns:GetCrestPlan("Hero")
            local capped = {}
            for _, st in ipairs(rich.steps) do
                if st.paid and st.rank >= st.maxRank then
                    capped[st.slotName] = true
                end
            end
            if not (capped["Trinket 1"] and capped["Trinket 2"]) then
                return restore("with 600 in hand the trinkets are still not "
                    .. "finished together")
            end

            -- The band is what drove it. If these collapsed to one
            -- verdict the ordering above would be luck.
            local bands = {}
            for _, st in ipairs(p.steps) do
                if st.paid then bands[st.band] = (bands[st.band] or 0) + 1 end
            end
            if not (bands.banked and bands.permanent) then
                return restore("every paid rank landed in one band, so the drop "
                    .. "band is not separating them")
            end
            -- Champion tops out at 308 under a 311 key drop, so nothing
            -- on this track can ever be permanent. A permanent rank here
            -- would mean the band is being read against the wrong number.
            -- Hero climbs past the band, so permanent ranks are the
            -- point. Rental ones would mean the band moved.
            if not bands.permanent then
                return restore("no Hero rank came out permanent above a "
                    .. p.bandHigh .. " drop ceiling")
            end

            return restore(string.format("ok:%s+%s:%d",
                promoted[1], promoted[2], bands.banked + bands.permanent))
        end
    """)(ns)
    if accept and str(accept).startswith("ok:"):
        who, ranks = str(accept)[3:].split(":")
        print("  ok   promotion planning: 200 Hero carries %s to the track "
              "cap over %s ranks, none left idle" % (who, ranks))
    else:
        print("  FAIL promotion planning: %s" % accept)
        failures.append(("promotion planning", str(accept)))

    # The sentences the player actually reads, on the same scenario.
    #
    # The plan being right is not the same as the panel saying so. The
    # shipped strings chose between "spend here first" and the clause
    # explaining whether the spend survives a drop, and first won -- so
    # a weapon and a trinket in identical positions were described in
    # opposite terms, and two rows on one panel each claimed to be the
    # one to do first.
    wording = L.eval("""
        function(ns)
            local T = ns.GEAR_TRACKS
            local realSlot, realCount = ns.GetSlotInfo, ns.GetCrestCountByTrack
            local SET = {
                { 16, "Champion", 3 }, { 13, "Champion", 1 }, { 14, "Champion", 1 },
                {  8, "Champion", 1 }, { 12, "Champion", 1 },
                -- Veteran caps at 295, ten below the worst thing this
                -- character is handed, so nothing on it can outlive a
                -- drop -- not even its last rank.
                {  9, "Veteran",  3 },
            }
            local bySlot = {}
            for _, e in ipairs(SET) do
                local levels = T[e[2]]
                bySlot[e[1]] = {
                    link = "|cffa335ee|Hitem:1::::::::80:::::|h[Shot]|h|r",
                    ilvl = levels[e[3]], quality = 4, icon = 134400,
                    track = e[2], rank = e[3], maxRank = #levels, crafted = false,
                }
            end
            ns.GetSlotInfo = function(self, slotID) return bySlot[slotID] end
            ns.GetCrestCountByTrack = function(self, track)
                if track == "Champion" or track == "Veteran" then return 200 end
                return 0
            end
            ns:InvalidateCrestPlans()

            local function restore(msg)
                ns.GetSlotInfo, ns.GetCrestCountByTrack = realSlot, realCount
                ns:InvalidateCrestPlans()
                return msg
            end

            local said, deep = {}, {}
            for _, e in ipairs(SET) do
                local _, reason, detail = ns:GetRecommendation(e[1])
                said[e[1]] = reason or ""
                deep[e[1]] = detail
            end

            -- The row is one line in a panel a third of a screen wide,
            -- and it was clipping mid-sentence -- so the advice with
            -- most to say was the advice you could not read. Character
            -- count is a proxy for pixels, but a loose one is worth
            -- more than none: it catches a sentence growing by half.
            for slot, reason in pairs(said) do
                if #reason > 100 then
                    return restore("slot " .. slot .. " writes " .. #reason
                        .. " characters onto one row: " .. reason)
                end
            end

            -- One wallet, one best spend, and it says which wallet.
            local leads = 0
            for _, reason in pairs(said) do
                if reason:find("Best Champion:", 1, true) then
                    leads = leads + 1
                end
                if reason:find("Spend here first", 1, true) then
                    return restore("a row still claims to be first without "
                        .. "naming the wallet it is first for")
                end
            end
            if leads ~= 1 then
                return restore(leads .. " rows lead the Champion wallet")
            end

            -- The two runs that reach the cap say so, and say what it
            -- buys -- which is a rebate on a piece the player does not
            -- own yet, in a currency they do not spend here.
            --
            -- An item does NOT move onto the next track. A Champion
            -- piece at 6/6 is 308 and is finished. What carries on is
            -- the SLOT: its mark now sits at 308, so the next Hero piece
            -- to land there is lifted to 308 for nothing. An earlier
            -- pass of this file had the item climbing onto the Hero
            -- track and said so on the panel, which is why the mechanic
            -- is pinned rather than left to read well.
            -- Champion caps at 308 and this character farms 311 in any
            -- slot from a +10, so the mark it sets is overtaken
            -- everywhere sooner or later. The row must not sell a rebate
            -- it cannot keep -- it used to promise "next Hero free to
            -- 308" on a mark that never survives.
            for _, slot in ipairs({ 16 }) do
                if not said[slot]:find("tops out at 308; you farm 311 in every slot",
                                       1, true) then
                    return restore("slot " .. slot .. " reaches the Champion cap "
                        .. "without saying it is farmed past: " .. said[slot])
                end
                for _, sold in ipairs({ "free to 308", "you never spend",
                                        "starts at 2/6" }) do
                    if said[slot]:find(sold, 1, true) then
                        return restore("slot " .. slot .. " sells a mark the "
                            .. "player farms past: '" .. sold .. "'")
                    end
                end
                for _, wrong in ipairs({ "moves to Hero", "keep climbing",
                                         "promotes to", "moves onto" }) do
                    if said[slot]:find(wrong, 1, true) then
                        return restore("slot " .. slot .. " claims the item itself "
                            .. "changes track: " .. said[slot])
                    end
                end
            end

            -- And the run that stops short is warned about rather than
            -- quietly listed as an upgrade like any other.
            -- Trinket 2 stops at 298, under the 305 floor -- but
            -- Champion reaches 308, so this is a stopgap the player can
            -- fix. Saying only "a drop replaces it" states the problem
            -- and withholds the answer.
            -- The same fact reaches the rows that stop mid-track, and
            -- as a statement about the TRACK -- "caps at 308" on a row
            -- that only reaches 298 claims something the run does not.
            if not said[14]:find("tops out at 308", 1, true) then
                return restore("a partial Champion row does not carry the "
                    .. "track's ceiling: " .. said[14])
            end
            if said[14]:find("caps at", 1, true) then
                return restore("a row reaching 298 claims to cap: " .. said[14])
            end

            -- And the case that prompted this. On Veteran, "under your
            -- 305 floor" named a Hero raid drop that has nothing to do
            -- with the piece, and was vacuously true besides: Veteran
            -- stops at 295, so no rank of it can ever clear 305 and the
            -- sentence fired on every row without telling them apart.
            -- Worse, the row that DID reach 295 said "caps the track",
            -- which reads as an achievement.
            if not said[9]:find("Veteran tops out under everything you loot",
                                1, true) then
                return restore("a Veteran row does not say the whole track "
                    .. "lands under the drop floor: " .. said[9])
            end
            if said[9]:find("305", 1, true) then
                return restore("a Veteran row quotes the Hero drop floor: "
                    .. said[9])
            end
            if said[14]:find("caps the track", 1, true) then
                return restore("Trinket 2 claims a cap it does not reach")
            end

            -- Every funded row prices itself, in crests, and names the
            -- wallet it is spending -- its OWN, not whichever one the
            -- page happens to be mostly about.
            for slot, reason in pairs(said) do
                if reason:find(" for ", 1, true) then
                    local named = false
                    for _, t in ipairs(ns.TRACK_ORDER) do
                        if reason:find(t, 1, true) then named = true break end
                    end
                    if not named then
                        return restore("slot " .. slot .. " spends without "
                            .. "naming the currency: " .. reason)
                    end
                end
            end

            -- What the short line had to drop has to land somewhere, or
            -- shortening it just destroyed the reasoning.
            local d = deep[16]
            if not d or #d < 3 then
                return restore("the lead row carries "
                    .. (d and #d or 0) .. " lines of detail")
            end
            local joined = table.concat(d, " ")

            -- Nobody hovers a recommendation to find out how the game
            -- works; they hover it to find out why THIS one. An earlier
            -- pass filled this with true sentences about tracks and
            -- marks -- a rules lecture dressed as advice -- so the
            -- shapes that read as teaching are refused outright.
            for _, lecture in ipairs({
                "tops out at", "does not move onto", "What carries on",
                "A rank above", "cannot upgrade", "is replaced by the next drop",
            }) do
                if joined:find(lecture, 1, true) then
                    return restore("the hover explains the system instead of "
                        .. "this upgrade: '" .. lecture .. "'")
                end
            end

            -- It has to be about THIS slot, by name.
            if not joined:find("Main Hand", 1, true) then
                return restore("the hover never names the slot it is about")
            end
            -- The free ranks on the next piece, which is the whole
            -- reason to carry a lower track to its cap -- and said in
            -- RANKS, because that is how the game shows gear and how
            -- players talk about it. "308 instead of 305" is the same
            -- fact in a unit nobody carries in their head.
            if not joined:find("overtaken", 1, true) then
                return restore("the hover never says the mark gets farmed "
                    .. "past: " .. joined)
            end
            if not joined:find("in any slot it likes", 1, true) then
                return restore("the hover never says end-of-dungeon loot is "
                    .. "not slot-specific: " .. joined)
            end
            -- Where the player stands on being DONE with the track, and
            -- what that means in weeks or drops -- the shortfall stated
            -- as a decision rather than left as a number.
            --
            -- The running "N of your 16 slots" count this replaced read
            -- as filler at best and absurd at worst: on a character with
            -- none of the track finished it announced "0 of your 16, and
            -- this makes 1".
            if not (joined:find("more Champion pieces to max would cost", 1, true)
                and joined:find("and you have", 1, true)) then
                return restore("the hover never says what the rest of the track "
                    .. "costs against what is in hand")
            end
            -- The shortfall ends in a decision, and the thing that
            -- decides it is the CAP.
            --
            -- This used to assert the opposite: that an outgrown track
            -- refuses a week count and points at drops, because "you
            -- only earn Champion once Hero caps". That is false --
            -- Champion is on offer all season from M0, low keys and
            -- delves, and a player 60 short will find those 60 without
            -- help. The allowance grows at the same rate on every track,
            -- so the answer has the same shape on all of them.
            if not (joined:find("The cap allows", 1, true)
                and joined:find("weeks", 1, true)) then
                return restore("the shortfall does not resolve to a wait the "
                    .. "cap explains: " .. joined)
            end
            for _, gate in ipairs({ "only earn", "overflow", "trickles" }) do
                if joined:find(gate, 1, true) then
                    return restore("the hover claims the crest itself is gated: "
                        .. "'" .. gate .. "'")
                end
            end
            -- Six lines of reasoning was a briefing, not a tip.
            if #d > 4 then
                return restore("the hover runs to " .. #d .. " lines")
            end

            return restore("ok:" .. said[16])
        end
    """)(ns)
    if wording and str(wording).startswith("ok:"):
        print("  ok   improvement wording: %s" % str(wording)[3:])
    else:
        print("  FAIL improvement wording: %s" % wording)
        failures.append(("improvement wording", str(wording)))

    # The whole set, counted once.
    #
    # "Can I finish this track at all" is a fact about sixteen slots and
    # one wallet, and no per-slot rule can reach it -- so the panel would
    # happily open a 100-crest climb on the fifth Champion piece while
    # four others sat in the same state and the wallet held 200. Every
    # row true; the set of them describing a plan that cannot happen.
    census = L.eval("""
        function(ns)
            local c = ns:GetGearCensus()
            if not c then return "no census" end
            if c.slots ~= #ns.SLOT_IDS then
                return "counted " .. c.slots .. " of " .. #ns.SLOT_IDS .. " slots"
            end

            -- Every slot is accounted for exactly once: on a track, or
            -- empty, or carrying something off this season's ladder. A
            -- slot that fell out of all three is demand the budget will
            -- never see coming.
            local onTrack = 0
            for _, t in pairs(c.tracks) do
                onTrack = onTrack + t.count
                if #t.pieces ~= t.count then
                    return t.track .. " counts " .. t.count .. " pieces but "
                        .. "lists " .. #t.pieces
                end
                local ranks = 0
                for _, piece in ipairs(t.pieces) do ranks = ranks + piece.left end
                if ranks ~= t.ranksLeft then
                    return t.track .. " totals " .. t.ranksLeft
                        .. " ranks left against " .. ranks .. " on its pieces"
                end
                local cost = ns:GetCrestCost(ns.TRACK_CREST[t.track] or t.track)
                if t.demand ~= ranks * cost then
                    return t.track .. " prices " .. ranks .. " ranks at " .. t.demand
                end
            end
            if onTrack + #c.empty + #c.untracked ~= c.slots then
                return onTrack .. " tracked + " .. #c.empty .. " empty + "
                    .. #c.untracked .. " untracked does not reach " .. c.slots
            end
            -- The fixture deliberately leaves most of the doll bare, so
            -- a zero here means the empty case is going unclassified.
            if #c.empty == 0 then
                return "no slot read as empty, so that branch is untested"
            end

            -- The policy is what the hover prints. Its arithmetic has to
            -- hold against the census it came from.
            local checked = 0
            for _, crest in ipairs(ns.CRESTS or {}) do
                local pol = ns:GetTrackPolicy(crest.track)
                if pol then
                    checked = checked + 1
                    if pol.demand ~= c.tracks[crest.track].demand then
                        return crest.track .. ": policy and census disagree on demand"
                    end
                    if #pol.canFinish > pol.wanting then
                        return crest.track .. ": claims to finish more pieces "
                            .. "than want ranks"
                    end
                    -- Completions are only offered while the crests in
                    -- hand cover them; "enough for 2" that needs 300 is
                    -- the exact promise this whole layer exists to stop.
                    if pol.finishCost > pol.held then
                        return crest.track .. ": offers " .. pol.finishCost
                            .. " of completions against " .. pol.held .. " held"
                    end
                    -- Cheapest first, or the count is not the most the
                    -- wallet can actually carry home.
                    local prev = 0
                    for _, piece in ipairs(pol.canFinish) do
                        if piece.left < prev then
                            return crest.track .. ": finishes a "
                                .. piece.left .. "-rank piece after a " .. prev
                        end
                        prev = piece.left
                    end
                    if not ns:GetTrackPolicyLine(crest.track) then
                        return crest.track .. ": policy with nothing to say"
                    end
                end
            end
            if checked == 0 then return "no track produced a policy" end

            -- The finish line the hover counts down to. Every slot is
            -- done, climbing, or waiting on a drop -- and if those three
            -- stop adding up, the "N pieces left" the panel promises is
            -- measured against a set that does not exist.
            for _, crest in ipairs(ns.CRESTS or {}) do
                local f = ns:GetTrackCompletion(crest.track)
                if f then
                    if f.done + f.needCrest + f.needDrop ~= f.slots then
                        return crest.track .. ": " .. f.done .. " done + "
                            .. f.needCrest .. " climbing + " .. f.needDrop
                            .. " waiting is not " .. f.slots .. " slots"
                    end
                    if f.finished ~= (f.needCrest == 0) then
                        return crest.track .. ": calls itself finished with "
                            .. f.needCrest .. " pieces still climbing"
                    end
                    -- A track nothing is climbing costs nothing to
                    -- finish; anything else would price phantom ranks.
                    if f.needCrest == 0 and f.cost ~= 0 then
                        return crest.track .. ": nothing left to buy but "
                            .. f.cost .. " to finish"
                    end
                    if f.canFinish ~= (f.cost > 0 and f.held >= f.cost) then
                        return crest.track .. ": disagrees with itself about "
                            .. "whether " .. f.held .. " covers " .. f.cost
                    end
                end
            end
            return string.format("ok:%d:%d:%d", onTrack, #c.empty, checked)
        end
    """)(ns)
    if census and str(census).startswith("ok:"):
        tracked, empty, checked = str(census)[3:].split(":")
        print("  ok   gear census: %s pieces across %s tracks and %s bare slots, "
              "every one accounted for" % (tracked, checked, empty))
    else:
        print("  FAIL gear census: %s" % census)
        failures.append(("gear census", str(census)))

    # "120 short" is a number, not a decision.
    #
    # The same shortfall is an evening's work or half a season depending
    # on where the season cap sits, and the panel used to state it and
    # stop. A cap the player has not reached yet is not a wait at all --
    # those crests are in content they have not run -- so only the part
    # beyond this season's allowance costs resets, at
    # CREST_WEEKLY_INCREMENT a week.
    timing = L.eval("""
        function(ns)
            local T = ns.GEAR_TRACKS
            local realSlot, realCount = ns.GetSlotInfo, ns.GetCrestCountByTrack
            local SET = {
                { 16, "Champion", 3 }, { 13, "Champion", 1 }, { 14, "Champion", 1 },
                {  8, "Champion", 1 }, { 12, "Champion", 1 },
            }
            local bySlot = {}
            for _, e in ipairs(SET) do
                local levels = T[e[2]]
                bySlot[e[1]] = {
                    link = "|cffa335ee|Hitem:1::::::::80:::::|h[Shot]|h|r",
                    ilvl = levels[e[3]], quality = 4, icon = 134400,
                    track = e[2], rank = e[3], maxRank = #levels, crafted = false,
                }
            end
            ns.GetSlotInfo = function(self, slotID) return bySlot[slotID] end

            local wallet = 0
            ns.GetCrestCountByTrack = function(self, track)
                return track == "Champion" and wallet or 0
            end

            local function restore(msg)
                ns.GetSlotInfo, ns.GetCrestCountByTrack = realSlot, realCount
                ns:InvalidateCrestPlans()
                return msg
            end
            local function at(n)
                wallet = n
                ns:InvalidateCrestPlans()
                return ns:GetTrackCompletion("Champion")
            end

            -- Five pieces: one three ranks from its cap, four at the
            -- bottom of the track. 3 + 4x5 = 23 ranks at 20.
            local base = at(0)
            if base.cost ~= 460 then
                return restore("fixture costs " .. base.cost .. " to finish, not 460")
            end
            if base.needCrest ~= 5 then
                return restore(base.needCrest .. " pieces climbing, not 5")
            end
            -- The shape, which is what decides drops against crests.
            if base.nearest ~= 3 or base.deepest ~= 5 then
                return restore("shape reads " .. base.nearest .. "-" ..
                    base.deepest .. " ranks, not 3-5")
            end

            -- The season allowance the fixture's Champion row leaves:
            -- 180 earned against a 300 cap.
            local earnable = ns:GetEarnableCrests("Champion")
            if earnable ~= 120 then
                return restore("fixture allowance is " .. earnable .. ", not 120")
            end

            -- Enough in hand: no shortfall, and nothing to wait for.
            local rich = at(600)
            if not rich.canFinish or rich.short ~= 0 or rich.weeks ~= nil then
                return restore("600 in hand still reports a wait")
            end
            if rich.surplus ~= 140 then
                return restore("600 against 460 leaves " .. rich.surplus)
            end

            -- Short, but inside the allowance: content not yet run, not
            -- a wait. This is the distinction the whole branch exists
            -- for -- telling someone to come back next week when the
            -- crests are sitting in a dungeon they have not done.
            local close = at(400)
            if close.short ~= 60 then
                return restore("400 against 460 is short " .. close.short)
            end
            -- Inside the allowance: one week, and flagged as content to
            -- run rather than a wait. Those are different sentences and
            -- the distinction is the point of the flag.
            if close.weeks ~= 1 or not close.withinAllowance then
                return restore("a 60 shortfall inside a 120 allowance reads "
                    .. tostring(close.weeks) .. " weeks, within="
                    .. tostring(close.withinAllowance))
            end

            -- Short beyond the allowance: now it is resets, and the
            -- count is only the part the cap has to grow into.
            local poor = at(200)
            if poor.short ~= 260 then
                return restore("200 against 460 is short " .. poor.short)
            end
            -- 260 short with 120 still allowed: this week takes 120, then
            -- 100, then the last 40 -- three weeks, which is what a
            -- player means by "how long until I can max these".
            local want = 1 + math.ceil((260 - 120) / ns.CREST_WEEKLY_INCREMENT)
            if poor.weeks ~= want or poor.withinAllowance then
                return restore("260 short with 120 allowed reads "
                    .. tostring(poor.weeks) .. " weeks, not " .. want)
            end

            return restore(string.format("ok:%d:%d:%d",
                base.cost, close.weeks, poor.weeks))
        end
    """)(ns)
    if timing and str(timing).startswith("ok:"):
        cost, near, far = str(timing)[3:].split(":")
        print("  ok   shortfall timing: %s to finish the track — %s week inside "
              "the allowance, %s beyond it" % (cost, near, far))
    else:
        print("  FAIL shortfall timing: %s" % timing)
        failures.append(("shortfall timing", str(timing)))

    # The week you lose by spending in the wrong order.
    #
    # Reported from a real season: advice to max trinkets drained the
    # wallet, and a Hero piece sitting one rank from its cap could not be
    # finished -- with the season cap already reached there was no way to
    # go back for it, and the Myth piece that wanted that slot's mark had
    # to wait a reset. Twenty crests, a week late.
    #
    # Run scoring makes this rare on its own, because a one-rank
    # completion is the best value per crest on any page. It is not
    # impossible: a high-priority deep run can still outbid one. That is
    # exactly when the row has to say so.
    strand = L.eval("""
        function(ns)
            local T = ns.GEAR_TRACKS
            local realSlot, realCount = ns.GetSlotInfo, ns.GetCrestCountByTrack
            -- Two pieces, both one rank from the Champion cap, and only
            -- enough for one of them. The weapon outranks the ring.
            local SET = { { 16, "Hero", 5 }, { 12, "Hero", 5 } }
            local bySlot = {}
            for _, e in ipairs(SET) do
                bySlot[e[1]] = {
                    link = "|cffa335ee|Hitem:1::::::::80:::::|h[Shot]|h|r",
                    ilvl = T[e[2]][e[3]], quality = 4, icon = 134400,
                    track = e[2], rank = e[3], maxRank = #T[e[2]], crafted = false,
                }
            end
            ns.GetSlotInfo = function(self, slotID) return bySlot[slotID] end
            ns.GetCrestCountByTrack = function(self, track)
                return track == "Hero" and 20 or 0
            end
            ns:InvalidateCrestPlans()
            local function restore(msg)
                ns.GetSlotInfo, ns.GetCrestCountByTrack = realSlot, realCount
                ns:InvalidateCrestPlans()
                return msg
            end

            local _, reason, detail = ns:GetRecommendation(16)
            if not reason:find("caps it", 1, true) then
                return restore("the weapon did not take the only affordable "
                    .. "completion: " .. reason)
            end
            local joined = table.concat(detail or {}, " ")
            if not joined:find("Leaves Ring 2 20 short", 1, true) then
                return restore("nothing warns that the ring is left one rank "
                    .. "from its cap: " .. joined)
            end

            -- And it does not cry wolf: the ring's own row is the one
            -- being left behind, so it has nothing to warn about.
            local _, _, ringDetail = ns:GetRecommendation(12)
            if table.concat(ringDetail or {}, " "):find("Leaves ", 1, true) then
                return restore("the stranded slot warns about itself")
            end
            return restore("ok")
        end
    """)(ns)
    if strand == "ok":
        print("  ok   stranded completion: a slot left one rank from its cap is "
              "named on the row that outbid it")
    else:
        print("  FAIL stranded completion: %s" % strand)
        failures.append(("stranded completion", str(strand)))

    # The season name, guarded at the source.
    #
    # Season 1's "of the Dawn" outlived the id table it belonged to and
    # sat in two files printing the wrong achievement. One shared suffix
    # replaced both; this stops a third copy being typed out by hand.
    stale = []
    for luafile in sorted(pathlib.Path(".").rglob("*.lua")):
        if "Libs" in luafile.parts:
            continue
        body = luafile.read_text(encoding="utf-8", errors="replace")
        for n, line in enumerate(body.splitlines(), 1):
            # Comments are where the reason for the rename is written
            # down, so they are the one place the old name belongs.
            if line.lstrip().startswith("--"):
                continue
            if 'of the Dawn"' in line or "of the Dawn)" in line:
                stale.append("%s:%d" % (luafile.as_posix(), n))
    if not stale:
        print("  ok   season naming: the outgrown achievement is named from one "
              "shared suffix, no Season 1 copies left")
    else:
        print("  FAIL season naming: stale 'of the Dawn' at %s" % ", ".join(stale))
        failures.append(("season naming", ", ".join(stale)))

    # A crest spent above what your content drops is banked by the slot's
    # high-water mark; one spent below it is overtaken by the next piece
    # that falls there. The advisor used to warn hardest about the first
    # kind, which is exactly backwards.
    sticky = L.eval("""
        function(ns)
            local ceiling = ns:GetDropCeiling()
            if not ceiling or ceiling <= 0 then return "no drop ceiling" end
            local checked = 0
            for _, crest in ipairs(ns.CRESTS or {}) do
                local p = ns:GetCrestPlan(crest.track)
                if p and p.slotCount > 0 then
                    if p.ceiling ~= ceiling then
                        return crest.track .. " planned against a different ceiling"
                    end
                    for _, st in ipairs(p.steps) do
                        checked = checked + 1
                        if st.sticks ~= (st.toIlvl > ceiling) then
                            return crest.track .. ": a rank landing at " .. st.toIlvl
                                .. " against a " .. ceiling .. " ceiling is marked "
                                .. tostring(st.sticks)
                        end
                    end
                    for _, sum in pairs(p.slots) do
                        if sum.stickyRanks > sum.paidRanks then
                            return crest.track .. "/" .. sum.slotName
                                .. ": more banked ranks than paid ones"
                        end
                    end
                end
            end
            if checked == 0 then return "no ranks to classify" end
            return "ok:" .. checked
        end
    """)(ns)
    if sticky and str(sticky).startswith("ok:"):
        print("  ok   watermark: %s planned ranks split correctly into banked "
              "(above the drop ceiling) and overtaken" % str(sticky)[3:])
    else:
        print("  FAIL watermark: %s" % sticky)
        failures.append(("watermark", str(sticky)))

    # Most worth doing, first -- in both panels.
    #
    # The shell's Improvements list did not sort at all. It walked the
    # equipment list, so the single slot actually worth spending on
    # today drew below three rows of "hold crests", which is the exact
    # opposite of what a ranked list is for. Both panels now read one
    # ordering, so this checks the ordering AND that nothing has quietly
    # gone back to slot order.
    order = L.eval("""
        function(ns)
            if not ns.GetRankedRecommendations then
                return "GetRankedRecommendations absent"
            end
            local list = ns:GetRankedRecommendations()
            if #list < 4 then return "only " .. #list .. " rows to rank" end

            -- The primary key must be monotonic. Anything else means a
            -- tiebreak is escaping its bucket.
            local prev, prevLabel = 0, nil
            for _, r in ipairs(list) do
                local o = ns.RECOMMEND_ORDER[r.recommendation] or 99
                if o < prev then
                    return "'" .. tostring(r.recommendation.label)
                        .. "' sorted after '" .. tostring(prevLabel) .. "'"
                end
                prev, prevLabel = o, r.recommendation.label
            end

            -- Actionable advice must lead. If a row telling the player
            -- to do nothing outranks one telling them to spend, the
            -- list is worse than unsorted -- it looks authoritative.
            local cut = ns.RECOMMEND_ACTIONABLE_MAX
            if not cut then return "RECOMMEND_ACTIONABLE_MAX absent" end
            local firstDoNothing, lastActionable = nil, nil
            for i, r in ipairs(list) do
                local o = ns.RECOMMEND_ORDER[r.recommendation] or 99
                if o <= cut then lastActionable = i end
                if o > cut and not firstDoNothing then firstDoNothing = i end
            end
            if firstDoNothing and lastActionable and lastActionable > firstDoNothing then
                return "an actionable row at " .. lastActionable
                    .. " sits below a wait-and-see row at " .. firstDoNothing
            end

            -- A "do not spend here" row must never outrank a "spend
            -- here" one. This is the reported bug: the only red row on
            -- the page sat at the top of a list where position already
            -- means importance.
            local dontSpend = {
                [ns.RECOMMEND.WASTED_CREST] = true,
                [ns.RECOMMEND.USE_LOWER_TRACK] = true,
                [ns.RECOMMEND.BAD_INVESTMENT] = true,
                [ns.RECOMMEND.SAVE_FOR_DROP] = true,
            }
            local firstWarning, warnCount = nil, 0
            for i, r in ipairs(list) do
                if dontSpend[r.recommendation] then
                    warnCount = warnCount + 1
                    if not firstWarning then firstWarning = i end
                end
                if firstWarning and (ns.RECOMMEND_ORDER[r.recommendation] or 99) <= cut then
                    return "'" .. tostring(r.recommendation.label) .. "' at row " .. i
                        .. " sits below a keep-crests-out warning at row " .. firstWarning
                end
            end

            -- The fixture must actually produce one. Without a warning
            -- row the loop above is a no-op that reports success, which
            -- is how this check passed while the bug was live.
            if warnCount == 0 then
                return "no keep-crests-out row in the fixture -- the ordering "
                    .. "check above cannot fire and proves nothing"
            end

            -- Sorting must be stable across calls, or the panel
            -- reshuffles under the cursor on every refresh.
            local first = {}
            for i, r in ipairs(list) do first[i] = r.slotID end
            local again = ns:GetRankedRecommendations()
            for i, r in ipairs(again) do
                if r.slotID ~= first[i] then
                    return "row " .. i .. " changed slot between two identical calls"
                end
            end

            -- And it must actually differ from equipment order, or the
            -- reported bug would still be present and passing.
            local slotOrder, k = {}, 0
            for _, si in ipairs(ns.SLOT_IDS) do
                for _, r in ipairs(list) do
                    if r.slotID == si.slot then k = k + 1; slotOrder[k] = si.slot end
                end
            end
            local identical = true
            for i = 1, #first do
                if first[i] ~= slotOrder[i] then identical = false break end
            end
            if identical then
                return "the ranked list is still in equipment order"
            end
            return "ok:" .. #list
        end
    """)(ns)
    if order and str(order).startswith("ok:"):
        print("  ok   improvement order: %s rows, spend advice above every "
              "keep-crests-out warning, stable between refreshes" % str(order)[3:])
    else:
        print("  FAIL improvement order: %s" % order)
        failures.append(("improvement order", str(order)))

    # The panel itself: render it and read the boxes back.
    #
    # This is the layout the report was about -- cards colliding and
    # text running off the right edge. Rendering it here means the
    # geometry below is measured, not assumed.
    suggest = L.eval("""
        function(ns)
            if not ns.RefreshSuggestions then return "RefreshSuggestions absent" end
            local ok, err = pcall(ns.RefreshSuggestions, ns)
            if not ok then return "render failed: " .. tostring(err) end
            local n = #(ns.SuggestEntries or {})
            if n == 0 then return "the panel drew nothing at all" end
            return "ok:" .. n
        end
    """)(ns)
    if suggest and str(suggest).startswith("ok:"):
        print("  ok   suggestions render: %s elements" % str(suggest)[3:])
    else:
        print("  FAIL suggestions render: %s" % suggest)
        failures.append(("suggestions render", str(suggest)))

    # Every drawn element, in one list, checked for overlap and overrun.
    # Cards, budget headers and rules are separate pools stacked on one
    # cursor, so a mis-measured header shows up as the next card sitting
    # on top of it.
    sug_boxes = L.eval("""
        function(ns)
            local out = {}
            for _, f in ipairs(ns.SuggestEntries or {}) do
                if f.IsShown and f:IsShown() and f._pts and f._pts[1] then
                    local p = f._pts[1]
                    local w = f._w or (f.GetWidth and f:GetWidth()) or 0
                    local h = f._h or (f.GetHeight and f:GetHeight()) or 0
                    -- FontStrings report their measured height; frames
                    -- carry the height the layout gave them. Either way
                    -- a zero-height element cannot collide, so skip it
                    -- rather than reporting a phantom.
                    if h > 0 then
                        out[#out + 1] = string.format("%d,%d,%d,%d",
                            math.floor(p.x or 0), math.floor(p.y or 0),
                            math.floor(w), math.floor(h))
                    end
                end
            end
            return table.concat(out, ";")
        end
    """)(ns)
    report("suggestions panel", parse(sug_boxes), 340 - 42)

    L.eval("""
        function(ns)
            if ns._realGetSlotInfo then
                ns.GetSlotInfo = ns._realGetSlotInfo
                ns._realGetSlotInfo = nil
            end
            if ns.InvalidateCrestPlans then ns:InvalidateCrestPlans() end
        end
    """)(ns)


    # Which affixes are worth a row.
    #
    # Two of five are furniture: the same affix in the same slot every
    # Tuesday. The other three all say something -- the Bargain changes
    # identity, and Fortified/Tyrannical are both up every week but swap
    # which keystone level they gate. Presence alone cannot tell the pair
    # from the furniture, which is why the slot is tracked too.
    affix = L.eval("""
        function(ns)
            if not ns.GetAffixSplit then return "GetAffixSplit absent" end
            YippYappHelperDB = YippYappHelperDB or {}
            YippYappHelperDB.affixObs = nil
            ns.AFFIX_FURNITURE[2] = nil

            -- One week of data cannot tell furniture from news, and with
            -- no seed for this season it must show everything.
            local moving, standing, learned = ns:GetAffixSplit()
            if learned then return "claimed to know the split after one week" end
            if #moving ~= 5 or #standing ~= 0 then
                return "week one showed " .. #moving .. "/" .. #standing
                    .. "; it must show everything until it has learned"
            end

            -- Week two: a different Bargain, and Fortified/Tyrannical
            -- trade slots. The season's own two hold their places.
            AFFIX_WEEK = {
                { id = 160, seasonID = 2 },
                { id = 163, seasonID = 2 },   -- different Bargain
                { id = 9,   seasonID = 2 },   -- swapped with Fortified
                { id = 10,  seasonID = 2 },
                { id = 148, seasonID = 2 },
            }
            moving, standing, learned = ns:GetAffixSplit()
            if not learned then return "still had not learned after two weeks" end

            local shown, hidden = {}, {}
            for _, a in ipairs(moving) do shown[a.id] = true end
            for _, a in ipairs(standing) do hidden[a.id] = true end

            if not shown[163] then return "the week's Bargain was hidden" end

            -- Fortified and Tyrannical are present in BOTH weeks, so a
            -- presence-only rule files them as furniture. They are shown
            -- because their slot moved, and the slot is the keystone
            -- level -- which is the whole reason the index is tracked.
            if not (shown[9] and shown[10]) then
                return "Fortified/Tyrannical hidden -- the slot swap was missed, "
                    .. "so only presence is being watched"
            end

            -- And the furniture must actually be hidden, or none of this
            -- bought the keystones any room.
            if not (hidden[160] and hidden[148]) then
                return "an affix that never moves was still shown"
            end
            if #moving ~= 3 then
                return "showed " .. #moving .. " affixes, expected 3"
            end

            ------------------------------------------------------------
            -- The keystone level each slot applies over.
            ------------------------------------------------------------
            local lv = ns.AFFIX_LEVELS and ns.AFFIX_LEVELS[0]
            if type(lv) ~= "table" or #lv ~= 5 then
                return "the season 0 level table is missing or not 5 slots"
            end
            -- Slots 3 and 4 must NOT share a threshold. Below +10 only
            -- one of Fortified/Tyrannical is up and the pair alternates;
            -- from +10 both are. Collapsing them to one number was the
            -- first version of this table and it makes the weekly swap
            -- meaningless, which is the whole reason the pair is shown.
            if lv[3][1] == lv[4][1] then
                return "slots 3 and 4 share a threshold; the +7/+10 split is gone"
            end
            local function lt(i)
                return ns:GetAffixLevelText({ index = i, seasonID = 0 })
            end
            if lt(2) ~= "+5-11" then
                return "slot 2 reads " .. tostring(lt(2)) .. ", not +5-11"
            end
            if lt(3) ~= "+7+" or lt(4) ~= "+10+" then
                return "the Fortified/Tyrannical slots read " .. tostring(lt(3))
                    .. " and " .. tostring(lt(4)) .. ", not +7+ and +10+"
            end
            -- The badges say when each affix STARTS. A "+10+" beside a
            -- single name reads as that affix having replaced the other,
            -- when in fact both are up from there -- so the +10 row
            -- names both.
            local pair = {
                { index = 3, name = "Fortified", seasonID = 0 },
                { index = 4, name = "Tyrannical", seasonID = 0 },
            }
            if ns:GetAffixLabel(pair[2], pair) ~= "Fortified + Tyrannical" then
                return "the +10 row reads '"
                    .. tostring(ns:GetAffixLabel(pair[2], pair))
                    .. "', not both affixes"
            end
            -- Borrowed only when the partner is actually up. A week that
            -- did not field it must not have its name invented.
            if ns:GetAffixLabel(pair[2], { pair[2] }) ~= "Tyrannical" then
                return "a name was borrowed from a slot that is not up"
            end
            -- And every other row is left alone.
            if ns:GetAffixLabel(pair[1], pair) ~= "Fortified" then
                return "an ordinary affix row had a name grafted onto it"
            end
            if ns.AFFIX_COMBINE[99] ~= nil then
                return "an unrecorded season carries a combine rule it cannot have"
            end

            -- An unrecorded season must answer nothing rather than zero:
            -- a badge reading "+0" is worse than no badge.
            if ns:GetAffixLevelText({ index = 1, seasonID = 99 }) ~= nil then
                return "an unrecorded season produced a level label anyway"
            end

            -- A season roll must not poison the record. New ids against
            -- an old week count would never reach it, so every affix
            -- would read as news for ever.
            AFFIX_WEEK = {
                { id = 160, seasonID = 3 },
                { id = 162, seasonID = 3 },
                { id = 10,  seasonID = 3 },
            }
            local m3, s3, l3 = ns:GetAffixSplit()
            if l3 then return "a fresh season claimed knowledge it cannot have" end
            if #m3 ~= 3 then return "a fresh season did not show all its affixes" end

            ------------------------------------------------------------
            -- The seed, so a fresh install is not blind for a week.
            ------------------------------------------------------------
            -- The shipped one is for the live season. Pin it: it is
            -- hand-recorded from a client dump, and a typo is invisible
            -- until someone notices the wrong row missing.
            local live = ns.AFFIX_FURNITURE and ns.AFFIX_FURNITURE[0]
            if type(live) ~= "table" or #live ~= 2 then
                return "the shipped seed for season 0 is missing or not 2 affixes"
            end

            YippYappHelperDB.affixObs = nil
            ns.AFFIX_FURNITURE[2] = { 160, 148 }
            AFFIX_WEEK = {
                { id = 160, seasonID = 2 },
                { id = 162, seasonID = 2 },
                { id = 10,  seasonID = 2 },
                { id = 9,   seasonID = 2 },
                { id = 148, seasonID = 2 },
            }
            local c, st, l = ns:GetAffixSplit()
            if not l then
                ns.AFFIX_FURNITURE[2] = nil
                return "the seed did not answer on week one, so a fresh install "
                    .. "still shows every affix"
            end
            if #c ~= 3 or #st ~= 2 then
                ns.AFFIX_FURNITURE[2] = nil
                return "seeded week one showed " .. #c .. " and hid " .. #st
                    .. "; expected 3 and 2"
            end

            -- Observation must OVERRIDE the seed the moment it can
            -- answer, or a seed left behind by a season roll would hide
            -- the wrong affix for ever. 163 is deliberately IN the seed
            -- and demonstrably not furniture: it appears in one week only.
            ns.AFFIX_FURNITURE[2] = { 160, 148, 163 }
            AFFIX_WEEK = {
                { id = 160, seasonID = 2 },
                { id = 163, seasonID = 2 },
                { id = 9,   seasonID = 2 },
                { id = 10,  seasonID = 2 },
                { id = 148, seasonID = 2 },
            }
            c, st, l = ns:GetAffixSplit()
            ns.AFFIX_FURNITURE[2] = nil
            if not l then return "two weeks in and it still had not learned" end
            local ch = {}
            for _, a in ipairs(c) do ch[a.id] = true end
            if not ch[163] then
                return "the seed still hid an affix that observation shows "
                    .. "changing -- a stale seed can never be corrected"
            end
            return "ok"
        end
    """)(ns)
    if affix == "ok":
        print("  ok   affixes: Bargain and the Fortified/Tyrannical pair shown "
              "with distinct +7/+10 ranges, furniture hidden, seed overridden")
    else:
        print("  FAIL affixes: %s" % affix)
        failures.append(("affixes", str(affix)))
    # The week list: its order, and what a row can say without the
    # journal.
    #
    # The card is read the way a night is remembered -- the run that just
    # happened at the top -- and the history carries far more than the
    # "it finished" this addon once believed was all of it. Both are easy
    # to regress into a level sort that happens to look right.
    weeklist = L.eval("""
        function(ns)
            local runs = ns:GetWeeklyRuns()
            if #runs ~= 10 then
                return #runs .. " runs on a week that had 10 (last week leaked in?)"
            end

            -- Newest first. The fixture's last run is a +11 in 17:30 and
            -- its highest key is a +13, so a list sorted by level puts
            -- the wrong one on top.
            if runs[1].level ~= 11 or runs[1].durationSec ~= 1050 then
                return "the top row is not the most recent run (+"
                    .. runs[1].level .. " in " .. tostring(runs[1].durationSec) .. "s)"
            end
            if runs[#runs].level ~= 8 then
                return "the bottom row is not the oldest run"
            end
            local descending = true
            for i = 2, #runs do
                if runs[i].level > runs[i - 1].level then descending = false end
            end
            if descending then return "the list is still sorted by key level" end

            -- Timed, and by how much, off the history's own clock: no
            -- journal entry exists for any of these.
            local top = runs[1]
            if top.detail then return "the fixture's runs should carry no journal detail" end
            if top.timed ~= true then return "a 17:30 run against a 30:00 timer read as untimed" end
            if top.chests ~= 3 then
                return "1050s of 1800 is a 3-chest run, read as " .. tostring(top.chests)
            end

            local over, twoChest, oneChest
            for _, r in ipairs(runs) do
                if r.durationSec == 1900 then over = r end
                if r.durationSec == 1430 then twoChest = r end
                if r.durationSec == 1790 then oneChest = r end
            end
            if not (over and twoChest and oneChest) then
                return "the fixture lost a run"
            end
            if over.timed ~= false then return "a run over the timer read as timed" end
            if (over.chests or 0) > 0 then return "a depleted key was credited with chests" end
            if twoChest.chests ~= 2 then
                return "1430s of 1800 is a 2-chest run, read as " .. tostring(twoChest.chests)
            end
            if oneChest.chests ~= 1 then
                return "1790s of 1800 is a 1-chest run, read as " .. tostring(oneChest.chests)
            end

            -- Score gained is what the run beat that dungeon's previous
            -- best by, and last week's runs set that bar even though
            -- they are not on the card.
            local newBest, noBest
            for _, r in ipairs(runs) do
                if r.score == 215 then newBest = r end
                if r.score == 205 then noBest = r end
            end
            if not (newBest and noBest) then return "the fixture lost a score" end
            if newBest.gain ~= 5 then
                return "215 over last week's 210 is worth 5, read as " .. tostring(newBest.gain)
            end
            if noBest.gain ~= 0 then
                return "a run under your own best for the dungeon gained "
                    .. tostring(noBest.gain)
            end

            -- When it happened, which is what the hover leads with.
            if not (top.date and top.date.hour) then
                return "the run carries no completion date"
            end

            -- The hover text. Every line stands on a fact the run
            -- actually has, so the check is that the facts reach it and
            -- that a run missing them says less rather than saying
            -- something invented.
            local function Joined(r)
                local parts = {}
                for _, line in ipairs(ns:DescribeRun(r)) do
                    parts[#parts + 1] = line.blank and "|" or line.text
                end
                return table.concat(parts, " / ")
            end

            local text = Joined(top)
            for _, want in ipairs({ "Keystone +11", "at 20:", "Finished in 17:30",
                                    "timer 30:00", "12:30 under the timer",
                                    "Key upgraded 3 levels, to +14",
                                    "Worth 225 score", "75 rating" }) do
                if not text:find(want, 1, true) then
                    return 'the hover text is missing ' .. want .. ': ' .. text
                end
            end

            local overText = Joined(over)
            if not overText:find("1:40 over the timer", 1, true) then
                return "a depleted run does not say how far over: " .. overText
            end
            if overText:find("upgraded", 1, true) then
                return "a depleted run was described as an upgrade: " .. overText
            end
            if not Joined(noBest):find("No rating gained", 1, true) then
                return "a run that beat nothing claimed rating for it"
            end

            -- A run the client answered "finished" about and nothing
            -- else -- what everything on this card looked like before
            -- the history was read properly.
            local bare = Joined({ name = "Kings' Rest", level = 10, completed = true })
            if bare:find("timer", 1, true) or bare:find("under", 1, true) then
                return "a run with no clock was given one: " .. bare
            end
            if not bare:find("No time was kept", 1, true) then
                return "a run with no clock does not say so: " .. bare
            end

            return "ok"
        end
    """)(ns)
    if weeklist == "ok":
        print("  ok   week list: newest run first, chests and margin read off the "
              "history's own clock, score gained measured against the season, "
              "hover says only what the run knows")
    else:
        print("  FAIL week list: %s" % weeklist)
        failures.append(("week list", str(weeklist)))

    # The run journal.
    #
    # GetRunHistory answers only whether a run finished. Everything the
    # week list now shows -- chests, margin, score, deaths -- exists for
    # one moment in GetCompletionInfo and has to be written down as it
    # happens. Untested, a journal that silently records nothing looks
    # exactly like a week of runs that predate it.
    journal = L.eval("""
        function(ns)
            if not ns.RecordCompletedRun then return "RecordCompletedRun absent" end
            YippYappHelperDB = YippYappHelperDB or {}
            YippYappHelperDB.runJournal = nil
            COMPLETION_INFO = nil

            -- Outside a completion there is nothing to record, and
            -- asking must not invent a row.
            ns:RecordCompletedRun()
            if #ns:GetRunJournal() ~= 0 then
                return "a run was recorded with no completion info"
            end

            -- Aim at a run the history actually contains, so the merge
            -- below has something to match.
            local runs = ns:GetWeeklyRuns()
            if #runs == 0 then return "no weekly runs in the fixture" end
            local target = runs[1]

            COMPLETION_INFO = {
                mapID = target.mapID, level = target.level,
                ms = 1500 * 1000, onTime = true, chests = 2, practice = false,
                oldScore = 2000, newScore = 2018, deaths = 3,
            }
            ns:RecordCompletedRun()
            local j = ns:GetRunJournal()
            if #j ~= 1 then return "recorded " .. #j .. " entries for one run" end
            local e = j[1]
            if not e.onTime or e.chests ~= 2 then
                return "the run's own verdict was not recorded"
            end
            if e.gain ~= 18 then
                return "score gain recorded as " .. tostring(e.gain) .. ", not 18"
            end
            if e.deaths ~= 3 then
                return "deaths recorded as " .. tostring(e.deaths) .. ", not 3"
            end
            -- The par time is captured AT record time; without it the
            -- week list cannot say how far under or over the run was.
            if e.limit ~= 1800 then
                return "the dungeon timer was not captured (" .. tostring(e.limit) .. ")"
            end

            -- A practice run is not a real one.
            COMPLETION_INFO.practice = true
            ns:RecordCompletedRun()
            if #ns:GetRunJournal() ~= 1 then
                return "a practice run was written into the journal"
            end
            COMPLETION_INFO.practice = false

            -- The merge: detail must reach the matching run and no other.
            runs = ns:GetWeeklyRuns()
            local hit, others = nil, 0
            for _, r in ipairs(runs) do
                if r.detail then
                    if r.mapID == target.mapID and r.level == target.level then
                        hit = r
                    else
                        others = others + 1
                    end
                end
            end
            if not hit then return "the recorded run got no detail on the week list" end
            if others > 0 then
                return others .. " unrelated runs were given detail that is not theirs"
            end
            if hit.detail.chests ~= 2 then return "the wrong entry was attached" end

            -- Two runs of the same key must not both show the first
            -- one's time. Entries are consumed as they match.
            YippYappHelperDB.runJournal = nil
            COMPLETION_INFO.chests = 3
            ns:RecordCompletedRun()
            COMPLETION_INFO.chests = 1
            ns:RecordCompletedRun()
            if #ns:GetRunJournal() ~= 2 then
                return "two runs of one key collapsed into a single entry"
            end

            -- Pruning: last week's runs must not survive into a list
            -- headed "This Week".
            local stale = ns:GetRunJournal()
            stale[#stale + 1] = { mapID = target.mapID, level = 99, at = 1 }
            ns:PruneRunJournal()
            for _, x in ipairs(ns:GetRunJournal()) do
                if x.level == 99 then
                    return "a run from before the reset survived the prune"
                end
            end

            COMPLETION_INFO = nil
            YippYappHelperDB.runJournal = nil
            return "ok"
        end
    """)(ns)
    if journal == "ok":
        print("  ok   run journal: completion detail recorded, practice runs "
              "skipped, merged to the right run, pruned at the reset")
    else:
        print("  FAIL run journal: %s" % journal)
        failures.append(("run journal", str(journal)))

    # Closing the window mid-fight. Once a page with secure tiles has
    # been mounted the window is protected and insecure code cannot hide
    # it at all, so the X carries a secure handler that can. Two halves
    # to get wrong: the handler has to actually be wired to the window,
    # and everything that CANNOT be made to work in combat -- the slash
    # command, the minimap -- has to keep deferring rather than silently
    # doing nothing. And before any secure page is mounted, none of this
    # should apply: a plain Hide is allowed and nobody should be made to
    # wait for the fight to end.
    combatclose = L.eval("""
        function(ns)
            local Shell = ns.Shell
            if not (Shell and Shell.Close and Shell.EnableCombatClose) then
                return "shell close absent"
            end
            local realCombat = InCombatLockdown
            local fighting = false
            InCombatLockdown = function() return fighting end

            local function finish(msg)
                InCombatLockdown = realCombat
                return msg
            end

            -- Unprotected window: combat is no reason to defer.
            local ok, err = pcall(Shell.Open, Shell)
            if not ok then return finish("open failed: " .. tostring(err)) end
            if not Shell:IsOpen() then return finish("window did not open") end
            fighting = true
            Shell:Close()
            if Shell:IsOpen() then
                return finish("a window with no secure page was made to wait")
            end

            -- Now the case that needs the handler.
            fighting = false
            pcall(Shell.Open, Shell)
            Shell:EnableCombatClose()
            local closer = _G.YippYappShellCloser
            if not closer then return finish("no secure closer was built") end
            local snippet = closer:GetAttribute("_onclick")
            if type(snippet) ~= "string" or not snippet:find("Hide", 1, true) then
                return finish("closer has no snippet that hides anything")
            end
            if closer:GetFrameRef("shell") ~= _G.YippYappShell then
                return finish("closer does not hold the window it closes")
            end

            -- The paths that cannot run a snippet keep their promise.
            fighting = true
            Shell:Close()
            if not Shell:IsOpen() then
                return finish("a protected window was hidden by insecure code")
            end
            fighting = false
            FireEvent("PLAYER_REGEN_ENABLED")
            if Shell:IsOpen() then
                return finish("the deferred close never happened")
            end
            return finish("ok")
        end
    """)(ns)
    if combatclose == "ok":
        print("  ok   combat close: the X carries a secure handler, and only "
              "the paths that cannot use it still wait for the fight")
    else:
        print("  FAIL combat close: %s" % combatclose)
        failures.append(("combat close", str(combatclose)))

    # Sub-tab sync: the shell restores a remembered sub-tab on mount.
    # If it does not tell the page, the strip and the content disagree
    # until you click away and back. Simulate arriving with "council"
    # remembered and check the page actually switched to it.
    subtab = L.eval("""
        function(ns)
            local Shell = ns.Shell
            if not (Shell and Shell.RegisterPage) then return "shell absent" end
            YippYappHelperDB = YippYappHelperDB or {}
            YippYappHelperDB.shellSubTab = { probe = "second" }

            local told = nil
            Shell:RegisterPage({
                id = "probe", label = "Probe", order = 999,
                subTabs = function()
                    return { { id = "first", label = "First" },
                             { id = "second", label = "Second" } }
                end,
                OnSubTab = function(id) told = id end,
                Build = function() end,
                Refresh = function() end,
            })
            local host = CreateFrame("Frame")
            host:SetSize(700, 480)
            local ok, err = pcall(Shell.Mount, Shell, "probe", host)
            if not ok then return "mount failed: " .. tostring(err) end
            if told == nil then
                return "page never told which sub-tab -- strip and content will disagree"
            end
            if told ~= "second" then
                return "page told '" .. tostring(told) .. "', strip shows 'second'"
            end
            return "ok"
        end
    """)(ns)
    if subtab == "ok":
        print("  ok   sub-tab sync: remembered tab pushed to the page on mount")
    else:
        print("  FAIL sub-tab sync: %s" % subtab)
        failures.append(("sub-tab sync", str(subtab)))

    # Show all: the limit must actually lift past the default.
    showall = L.eval("""
        function(ns)
            local T = ns.Trinkets
            if not (T and T.GetForSpec) then return "Trinkets index absent" end
            local key = T:GetPlayerSpecKey() or "DRUID_BALANCE"
            local ok, list = pcall(T.GetForSpec, T, key, "ST")
            if not ok or type(list) ~= "table" then return "no list for " .. key end
            if #list <= 10 then
                return "only " .. #list .. " trinkets -- cannot prove >10"
            end
            return "ok:" .. #list
        end
    """)(ns)
    if showall and str(showall).startswith("ok:"):
        print("  ok   show all: spec list holds %s trinkets, past the 10-row default"
              % str(showall)[3:])
    else:
        print("  --   show all: %s" % showall)

    # The healer path through the page itself, played as a Holy Priest.
    # The data check above proves the blocks are there; this proves the
    # page reads them as QE's -- the tabs stop claiming to be target
    # counts, and the attribution stops sending a healer to a site that
    # has never published their spec. Both are strings assembled at draw
    # time from the block, so nothing but a draw can prove them.
    healerpage = L.eval("""
        function(ns)
            local UI = ns.TrinketUI
            if not (UI and UI.BuildContent and UI.BuildFilters) then
                return "Trinkets page absent"
            end
            local realClass, realSpec = UnitClass, GetSpecializationInfo
            UnitClass = function() return "Priest", "PRIEST" end
            GetSpecializationInfo = function()
                return 257, "Holy", "", 135920, "HEALER"
            end
            local host = CreateFrame("Frame")
            host:SetSize(700, 480)
            local bar = CreateFrame("Frame", nil, host)
            bar:SetSize(700, 24)
            -- The filter strip is built on its own and allowed to fail
            -- part way: it ends with a SearchBoxTemplate edit box, whose
            -- Instructions font string this stub does not provide. The
            -- style tabs are built before that, so the labels this check
            -- is about exist either way, and pretending otherwise would
            -- mean testing nothing rather than testing the tabs.
            pcall(UI.BuildFilters, UI, bar, {})
            local ok, err = pcall(function()
                UI:BuildContent(host, { subTab = "spec" })
                UI:Refresh()
            end)
            -- Read off the frames the player would be looking at, not
            -- recomputed: recomputing would just re-run the function
            -- under test and agree with itself.
            local labels = {}
            for id, btn in pairs(UI._styleButtons or {}) do
                labels[#labels + 1] = id .. "=" ..
                    tostring(btn.label and btn.label:GetText())
            end
            table.sort(labels)
            UnitClass, GetSpecializationInfo = realClass, realSpec
            if not ok then return "draw failed: " .. tostring(err) end
            local said = table.concat(labels, " ")
            if said ~= "AOE=Dungeon ST=Raid" then
                return "style tabs read '" .. said .. "'"
            end

            local key = "PRIEST_HOLY"
            if ns.Trinkets:StyleLabel(key, "ST") ~= "Raid"
                or ns.Trinkets:StyleLabel(key, "AOE") ~= "Dungeon" then
                return "healer tabs would still say single target / AoE"
            end
            local info = ns.Trinkets:ProviderInfo(ns.Trinkets:Provider(key, "ST"))
            if info.site ~= "questionablyepic.com" then
                return "healer list credited to " .. tostring(info.site)
            end
            local list, _, stamp = ns.Trinkets:GetForSpec(key, "ST")
            if not list or not stamp or stamp == "" then
                return "no dated healer list to attribute"
            end
            return "ok:" .. stamp
        end
    """)(ns)
    # The council list mixes both sources on one trinket, and the two
    # percentages divide by different things -- total DPS against the
    # best trinket's healing. Sorted into one column by that number, a
    # Holy Priest's 4th best (-16.4%) lands below an Arcane Mage's 16th
    # (-2.0%), which ranks by which project simmed you rather than by
    # who wants the item. They must come back grouped, in order, with
    # the player's own group first.
    grouping = L.eval("""
        function(ns)
            local T = ns.Trinkets
            if not (T and T.GroupedSpecsFor) then return "grouping absent" end
            local realClass, realSpec = UnitClass, GetSpecializationInfo
            local function play(class, file, id, spec, role)
                UnitClass = function() return class, file end
                GetSpecializationInfo = function()
                    return id, spec, "", 1, role
                end
            end
            -- Hex Lord's Dooming Idol: ranked by both sides, which is
            -- the case the grouping exists for.
            local item = 270169
            local function check()
                local groups = T:GroupedSpecsFor(item, "ST")
                if not groups then return nil, "no groups for the item" end
                local units = {}
                for _, g in ipairs(groups) do
                    if units[g.unit] then return nil, "unit " .. g.unit .. " split across groups" end
                    units[g.unit] = true
                    local prev
                    for _, e in ipairs(g.entries) do
                        local u = T:ProviderInfo(e.provider).unit
                        if u ~= g.unit then
                            return nil, tostring(e.key) .. " is " .. u .. " inside a " .. g.unit .. " group"
                        end
                        if prev and e.rel > prev + 0.0001 then
                            return nil, g.unit .. " group is out of order at " .. tostring(e.key)
                        end
                        prev = e.rel
                    end
                end
                return groups
            end

            play("Priest", "PRIEST", 257, "Holy", "HEALER")
            local healer, err = check()
            play("Mage", "MAGE", 63, "Fire", "DAMAGER")
            local damage, err2 = check()
            UnitClass, GetSpecializationInfo = realClass, realSpec

            if not healer then return "as a healer: " .. tostring(err) end
            if not damage then return "as a mage: " .. tostring(err2) end
            if #healer ~= 2 then
                return "expected two groups, got " .. #healer
            end
            if healer[1].unit ~= "score" then
                return "a healer sees the " .. healer[1].unit .. " group first"
            end
            if damage[1].unit ~= "percent" then
                return "a mage sees the " .. damage[1].unit .. " group first"
            end
            return string.format("ok:%d+%d", #healer[1].entries,
                #healer[2].entries)
        end
    """)(ns)
    if grouping and str(grouping).startswith("ok:"):
        print("  ok   council grouping: %s specs split by what the percentage "
              "measures, player's own group first" % str(grouping)[3:])
    else:
        print("  FAIL council grouping: %s" % grouping)
        failures.append(("council grouping", str(grouping)))

    if healerpage and str(healerpage).startswith("ok:"):
        print("  ok   healer page: draws as Holy Priest, tabs read raid/dungeon, "
              "credited to QE Live (%s)" % str(healerpage)[3:])
    else:
        print("  FAIL healer page: %s" % healerpage)
        failures.append(("healer page", str(healerpage)))

    cons_n = L.eval("function(ns) return ns.__consSecIdx or 0 end")(ns)
    if cons_n and cons_n > 0:
        report("Consumables sections",
               parse(pool_rects(L.eval("function(ns) return ns.__consSecPool end")(ns), cons_n)),
               None)

    # A section card must never sit ABOVE the frame its rows are
    # anchored to. Frame level beats draw layer, so a card one level up
    # paints its fill straight over the content it is supposed to sit
    # behind -- the rows are still drawn, just underneath a rectangle.
    layer = L.eval("""
        function(ns)
            local pool, n = ns.__consSecPool, ns.__consSecIdx or 0
            if n == 0 then return "no sections drawn" end
            for i = 1, n do
                local sec = pool[i]
                local host = sec:GetParent()
                if host then
                    local hl = host:GetFrameLevel() or 0
                    if (sec:GetFrameLevel() or 0) > hl then
                        return string.format(
                            "card %d is %d level(s) above its content frame",
                            i, sec:GetFrameLevel() - hl)
                    end
                    if (sec.body:GetFrameLevel() or 0) > hl then
                        return string.format(
                            "card %d body is %d level(s) above its content frame",
                            i, sec.body:GetFrameLevel() - hl)
                    end
                end
            end
            return "ok:" .. n
        end
    """)(ns)
    if layer and str(layer).startswith("ok:"):
        print("  ok   card layering: %s cards sit at or below their content frame"
              % str(layer)[3:])
    else:
        print("  FAIL card layering: %s" % layer)
        failures.append(("card layering", str(layer)))

    # A cast event resolves a spell ID to a dungeon NAME, and the tile
    # animation looks that name up in a table the render keyed off
    # C_ChallengeMode's names. Two independently keyed tables meeting on
    # a string: a mismatch does not error anywhere, it just quietly never
    # animates. Walk every season map through the round trip.
    #
    # The negative control is built in -- a bogus spell ID has to come
    # back nil. Without it this passes just as happily against a lookup
    # that returns something for everything.
    tele = L.eval("""
        function(ns)
            if ns:GetDungeonForTeleportSpell(2147483) then
                return "control: a bogus spell ID resolved to a dungeon"
            end
            local reg = (ns.MythicPlusFrame or {})._tilesByDungeon or {}
            local n, missing = 0, {}
            for _, map in ipairs(ns:GetSeasonMaps()) do
                local spellID = ns:GetDungeonTeleportSpell(map.mapID)
                local name = spellID and ns:GetDungeonForTeleportSpell(spellID)
                if not name then
                    missing[#missing + 1] = map.name .. " (no teleport spell)"
                elseif not reg[name] then
                    missing[#missing + 1] = map.name .. " -> '" .. name .. "' has no tile"
                else
                    n = n + 1
                end
            end
            if #missing > 0 then return table.concat(missing, "; ") end
            return "ok:" .. n
        end
    """)(ns)
    if tele and str(tele).startswith("ok:"):
        print("  ok   teleport cast -> tile: %s dungeons round-trip spell->name->tile"
              % str(tele)[3:])
    else:
        print("  FAIL teleport cast -> tile: %s" % tele)
        failures.append(("teleport cast -> tile", str(tele)))

    # Fire an actual cast at the page. Registering for an event and
    # handling it are two different claims, and nothing offline had ever
    # made the second one -- the toast and the tile animation were whole
    # features that had never executed a line.
    #
    # Control first: a spell that is not a teleport must leave the page
    # untouched, or "the toast appeared" proves only that it appears for
    # everything.
    cast = L.eval("""
        function(ns)
            local f = ns.MythicPlusFrame
            local w = f._castWatch
            if not w then return "no _castWatch published" end
            local h = w._scripts and w._scripts.OnEvent
            if not h then return "no OnEvent handler registered" end

            local KINGS_REST = 1289778
            local tile = f._tilesByDungeon["Kings' Rest"]
            if not tile then return "no tile registered for Kings' Rest" end

            -- Control: Fireball is not a teleport.
            h(w, "UNIT_SPELLCAST_START", "player", "cast-0", 133)
            if f._castToast and f._castToast:IsShown() then
                return "control: a non-teleport spell raised the toast"
            end
            if tile._castSweep and tile._castSweep:IsShown() then
                return "control: a non-teleport spell animated a tile"
            end

            h(w, "UNIT_SPELLCAST_START", "player", "cast-1", KINGS_REST)
            if not (f._castToast and f._castToast:IsShown()) then
                return "START did not raise the toast"
            end
            if not (tile._castSweep and tile._castSweep:IsShown()) then
                return "START did not animate the Kings' Rest tile"
            end

            h(w, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", KINGS_REST)
            if tile._castSweep:IsShown() then
                return "SUCCEEDED left the cast sweep running"
            end
            if not (tile._castFlash and tile._castFlash:IsShown()) then
                return "SUCCEEDED did not flash the tile"
            end

            -- The page closed, which is the normal case: a teleport is
            -- usually cast from the Teleports page or a bar. The toast
            -- has to survive that -- it did not, and nothing offline
            -- noticed because every check ran with the page open.
            f._castToast:Hide()
            f:Hide()
            h(w, "UNIT_SPELLCAST_START", "player", "cast-2", KINGS_REST)
            local survived = f._castToast:IsShown()
            f:Show()
            if not survived then
                return "toast did not appear while the page was hidden"
            end
            return "ok"
        end
    """)(ns)
    if cast == "ok":
        print("  ok   teleport cast: START raises toast + tile sweep, "
              "SUCCEEDED flashes and clears")
    else:
        print("  FAIL teleport cast: %s" % cast)
        failures.append(("teleport cast", str(cast)))

    # The character rail: section rules, and the crest track colours.
    #
    # Nothing built this offline before, so both were shipped unexecuted.
    rail = L.eval("""
        function(ns)
            local W, Shell = ns.Widgets, ns.Shell
            if not (Shell and Shell.BuildCharacter) then return "no BuildCharacter" end

            -- Controls first: the parser has to reject what is not a
            -- colour, or "every crest parsed" says nothing.
            if W:HexToRGB(nil) or W:HexToRGB("zzzzzz") or W:HexToRGB("ff00") then
                return "control: HexToRGB accepted a non-colour"
            end
            local r, g, b = W:HexToRGB("ff1eff00")
            if math.abs(r - 30/255) > 0.001 or g ~= 1 or b ~= 0 then
                return "control: HexToRGB('ff1eff00') gave " .. r .. "," .. g .. "," .. b
            end

            -- Every crest must yield a colour, and a distinct one. A
            -- single unparseable entry silently falls back to rarity,
            -- which is the look this replaced.
            local seen = {}
            for i, def in ipairs(ns.CRESTS or {}) do
                local cr, cg, cb = W:HexToRGB(def.color)
                if not cr then
                    return "crest " .. i .. " (" .. tostring(def.track)
                        .. ") has no parseable colour: " .. tostring(def.color)
                end
                local key = string.format("%.3f/%.3f/%.3f", cr, cg, cb)
                if seen[key] then
                    return "crests " .. seen[key] .. " and " .. i .. " share a colour"
                end
                seen[key] = i
            end

            local col = CreateFrame("Frame")
            col:SetSize(300, 700)
            local ok, err = pcall(Shell.BuildCharacter, Shell, col)
            if not ok then return "rail build failed: " .. tostring(err) end
            if #(Shell._crestTiles or {}) ~= #(ns.CRESTS or {}) then
                return "rail drew " .. #(Shell._crestTiles or {}) .. " crest tiles"
            end

            -- The rule sits under the heading and spans its full width,
            -- so it starts at x = 0 and below the text's line box -- and
            -- crucially it is the same for every heading, whatever the
            -- word above it happens to be.
            local xs, ys = {}, {}
            for _, key in ipairs({ "_railCrests", "_railWallet" }) do
                local h = Shell[key]
                local p = h and h.rule and h.rule._pts and h.rule._pts[1]
                if not p then return key .. " has no anchored rule" end
                if p.x ~= 0 then
                    return key .. " rule starts at x=" .. p.x .. ", not flush left"
                end
                if not (p.y < 0) then
                    return key .. " rule sits at y=" .. p.y .. ", not below the text"
                end
                xs[#xs + 1] = p.x
                ys[#ys + 1] = p.y
            end
            if xs[1] ~= xs[2] or ys[1] ~= ys[2] then
                return "section rules do not agree between headings"
            end

            -- The heading length must no longer move the rule at all --
            -- that dependency was the whole defect.
            local h = Shell._railWallet
            local before = h.rule._pts[1].x
            h:SetText("A Heading Far Longer Than Any Of The Others")
            local after = h.rule._pts[1].x
            h:SetText("Currencies")
            if before ~= after then
                return "heading length still moves the rule: " .. before .. " -> " .. after
            end
            return "ok"
        end
    """)(ns)
    if rail == "ok":
        print("  ok   rail: 5 distinct crest colours, rules full-width under "
              "each heading and independent of it")
    else:
        print("  FAIL rail: %s" % rail)
        failures.append(("rail", str(rail)))

    # Stat priority: the parse, and the one row it lights.
    #
    # The parser is the part worth pinning down. What the guide holds is
    # not a list of stats but prose that happens to be short, and every
    # one of these lines broke a version of it: a slash inside a
    # qualifier, a rank written with "and", a primary stat that must not
    # take rank 1, and ">=" which orders where "=" ties.
    #
    # BuildCharacter runs above but RefreshCharacter never did, so the
    # accent would otherwise ship unexecuted -- and it is the whole
    # feature.
    stats = L.eval("""
        function(ns)
            local Shell = ns.Shell
            if not ns.ParseStatPriority then return "no ParseStatPriority" end

            local function ranks(lines)
                local r = ns:ParseStatPriority(lines)
                if not r then return "nil" end
                local out = {}
                for _, k in ipairs({ "crit", "haste", "mastery", "vers" }) do
                    out[#out + 1] = k .. "=" .. tostring(r[k])
                end
                return table.concat(out, " ")
            end
            local cases = {
                -- The primary opens every list and owns no rank, or
                -- Blood reads Haste as second best.
                { "Strength|Haste|Mastery / Critical Strike / Versatility",
                  "crit=2 haste=1 mastery=2 vers=2" },
                -- The slash is INSIDE the bracket. Splitting before
                -- stripping turns one stat into two non-stats.
                { "Agility|Haste (until 800/18%-20%)|Critical Strike|Mastery|Versatility",
                  "crit=2 haste=1 mastery=3 vers=4" },
                -- "and" ties, and so does "=".
                { "Agility|Mastery|Critical Strike and Haste|Versatility",
                  "crit=2 haste=2 mastery=1 vers=3" },
                -- ">=" orders. Treating it as a tie would rank Crit
                -- level with Mastery, which is the opposite of what it
                -- says.
                { "Intellect|Haste|Mastery>=Critical Strike|Versatility",
                  "crit=3 haste=1 mastery=2 vers=4" },
                -- A line naming no secondary consumes no rank.
                { "Item Level / Agility / Armor / Stamina|Versatility = Critical Strike = Mastery|Haste",
                  "crit=1 haste=2 mastery=1 vers=1" },
                -- Named twice: the priority is the first mention, the
                -- footnote is not a second rank.
                { "Agility|Haste (until 800)|Critical Strike|Haste (above 800).",
                  "crit=2 haste=1 mastery=nil vers=nil" },
            }
            for _, case in ipairs(cases) do
                local lines = {}
                for piece in (case[1] .. "|"):gmatch("([^|]*)|") do
                    lines[#lines + 1] = piece
                end
                local got = ranks(lines)
                if got ~= case[2] then
                    return "parse " .. case[1] .. "\\n    wanted " .. case[2]
                        .. "\\n    got    " .. got
                end
            end

            -- Blood's two builds lead with different stats and the
            -- guide names no tree the stub client is in, so the honest
            -- answer is no rank at all rather than the first entry.
            local blood = ns:StatPriorityRanks("DEATHKNIGHT_BLOOD")
            if blood and blood.haste == 1 then
                return "Blood picked San'layn's Haste over Deathbringer's Crit"
            end
            if blood and blood.crit == 1 then
                return "Blood picked Deathbringer's Crit over San'layn's Haste"
            end

            -- Protection paladin's two entries disagree below the top
            -- and agree at it. Agreement is not a guess, so Haste still
            -- lights.
            local prot = ns:StatPriorityRanks("PALADIN_PROTECTION")
            if not (prot and prot.haste == 1) then
                return "Protection lost the Haste both its builds lead with"
            end
            if prot.crit or prot.mastery then
                return "Protection kept a rank its two builds disagree on"
            end

            -- The stubbed client is a Balance druid in Keeper of the
            -- Grove, one of that spec's two builds. Both lead with
            -- Mastery, so the lit row alone cannot show the right entry
            -- was picked -- they part lower down, where Keeper ties
            -- Crit with Haste at 2 and Elune's Chosen puts it at 3.
            local bal, balEntry, balBuild = ns:StatPriorityRanks("DRUID_BALANCE")
            if not (bal and bal.crit == 2) then
                return "Balance resolved to " .. tostring(balBuild)
                    .. " with crit=" .. tostring(bal and bal.crit)
                    .. ", wanted Keeper of the Grove at crit=2"
            end
            if not balEntry then
                return "Balance fell back to consensus with a known build"
            end

            local ok, err = pcall(Shell.RefreshCharacter, Shell)
            if not ok then return "RefreshCharacter failed: " .. tostring(err) end

            local ar, ag, ab = ns.Widgets:Color("accent")
            local lit = {}
            for key, row in pairs(Shell._statRows or {}) do
                local r, g, b = row.label:GetTextColor()
                if r == ar and g == ag and b == ab then lit[#lit + 1] = key end
            end
            if #lit ~= 1 or lit[1] ~= "mastery" then
                return "accented " .. (#lit == 0 and "nothing"
                    or table.concat(lit, "+")) .. ", wanted mastery alone"
            end

            local link = Shell._statLink
            if not (link and link:GetScript("OnClick")) then
                return "the Stats heading is not a way into Best in Slot"
            end
            if not link._entry then
                return "the heading has no priority to show on hover"
            end
            local okHover, hoverErr = pcall(link:GetScript("OnEnter"), link)
            if not okHover then return "hover failed: " .. tostring(hoverErr) end

            -- And it must go dark again when the guide cannot say. A
            -- lit row left over from the last character is worse than
            -- an unlit one.
            local realRanks = ns.StatPriorityRanks
            ns.StatPriorityRanks = function() return nil end
            pcall(Shell.RefreshCharacter, Shell)
            ns.StatPriorityRanks = realRanks
            for key, row in pairs(Shell._statRows or {}) do
                local r, g, b = row.label:GetTextColor()
                if r == ar and g == ag and b == ab then
                    return key .. " stayed accented with no priority to justify it"
                end
            end
            return "ok"
        end
    """)(ns)
    if stats == "ok":
        print("  ok   stat priority: 6 parses; Blood's disagreement marks "
              "nothing and Protection's agreement still marks Haste; "
              "Balance resolves to the tree it took, lights Mastery alone, "
              "and goes dark again when the guide cannot say")
    else:
        print("  FAIL stat priority: %s" % stats)
        failures.append(("stat priority", str(stats)))

    # The dashboard's Great Vault grid. Nothing built this offline
    # either, so the stripe encoding had never run.
    #
    # The invariant is the one the old code broke on screen: a row that
    # says "2 of 3" must show exactly two tiles reading as unlocked. The
    # category-coloured stripe made three of them look done because
    # World's category colour happened to be the same green.
    vault = L.eval("""
        function(ns)
            local Shell = ns.Shell
            local page = Shell and Shell.GetPage and Shell:GetPage("home")
            if not page then return "no dashboard page registered" end

            local host = CreateFrame("Frame")
            host:SetSize(700, 620)
            local ok, err = pcall(page.Build, host)
            if not ok then return "dashboard build failed: " .. tostring(err) end
            if page.Refresh then
                local ok2, err2 = pcall(page.Refresh, { content = host,
                    width = 700, height = 620 })
                if not ok2 then return "dashboard refresh failed: " .. tostring(err2) end
            end

            local ui = ns.ShellHomeUI
            if not (ui and ui.rows) then return "no vault rows built" end

            local VALID = { none = true, locked = true, progress = true, unlocked = true }
            local rows, unlocked = 0, {}
            for key, row in pairs(ui.rows) do
                rows = rows + 1
                unlocked[key] = 0
                for s, tile in ipairs(row.slots or {}) do
                    local st = tile._slotState
                    if not VALID[st] then
                        return key .. " slot " .. s .. " has state "
                            .. tostring(st) .. ", which is not one of the four"
                    end
                    if st == "unlocked" then unlocked[key] = unlocked[key] + 1 end
                end
            end
            if rows ~= 3 then return "built " .. rows .. " vault rows" end

            -- The tally the row prints, against the tiles it drew.
            for key, row in pairs(ui.rows) do
                local said = tostring(row.tally:GetText() or ""):match("^(%d+)")
                if said and tonumber(said) ~= unlocked[key] then
                    return key .. " says '" .. row.tally:GetText()
                        .. "' but " .. unlocked[key] .. " tiles read unlocked"
                end
            end

            -- The actual fix. Two slots in the same state must be the
            -- same colour whichever row they sit in, and two slots in
            -- different states must not be. The old stripe failed the
            -- first half -- an unlocked Mythic+ slot was cyan and an
            -- unlocked World slot green -- and half-failed the second,
            -- because World's locked slots were that same green.
            local byState, states = {}, 0
            for key, row in pairs(ui.rows) do
                for s, tile in ipairs(row.slots or {}) do
                    local st, colour = tile._slotState, tile.fill:GetColorKey()
                    if byState[st] and byState[st] ~= colour then
                        return "two '" .. st .. "' slots differ in colour ("
                            .. byState[st] .. " vs " .. colour .. ")"
                    end
                    if not byState[st] then
                        byState[st] = colour
                        states = states + 1
                    end
                end
            end
            local seenColour = {}
            for st, colour in pairs(byState) do
                if seenColour[colour] then
                    return "states '" .. st .. "' and '" .. seenColour[colour]
                        .. "' share colour " .. colour
                end
                seenColour[colour] = st
            end
            if states < 3 then
                return "only " .. states .. " distinct states drawn; the fixture "
                    .. "cannot tell a state encoding from a flat one"
            end

            -- The bar's LENGTH is the new half of the encoding, and it
            -- has to track progress rather than just state. Raid is
            -- untouched (0), Mythic+ slot 2 is 1 of 4, and every
            -- unlocked slot is full.
            local function pctOf(key, s) return ui.rows[key].slots[s]._slotPct end
            if pctOf("raid", 1) ~= 0 then
                return "an untouched slot drew a bar at " .. pctOf("raid", 1)
            end
            if math.abs(pctOf("mplus", 2) - 0.25) > 0.001 then
                return "1 of 4 drew a bar at " .. pctOf("mplus", 2) .. ", not 0.25"
            end
            if pctOf("world", 1) ~= 1 or pctOf("mplus", 1) ~= 1 then
                return "an unlocked slot drew a bar short of full"
            end

            -- And the reward text: the item level the client offers for
            -- that activity, not the key level. Falling back to "+N"
            -- silently is the failure worth catching, because it looks
            -- exactly like the old behaviour working.
            -- The item level lives at the foot of the card, not in the
            -- fraction on the right.
            local got = ui.rows.world.slots[1].big:GetText() or ""
            if not got:match("292") then
                return "unlocked world slot reads '" .. got .. "', without its item level"
            end
            if (ui.rows.raid.slots[1].big:GetText() or "") ~= "" then
                return "a locked slot claims a reward it has not earned"
            end

            -- The card carries the bare figure in the middle; the name
            -- and the qualifier live in the hover. Both halves asserted,
            -- because the two labels that used to share the bottom
            -- corner overran each other the moment the text grew.
            local wt = ui.rows.world.slots[1]
            if got:match("Tier") or got:match("Item level") then
                return "world card reads '" .. got
                    .. "'; only the number belongs on the card"
            end
            if not (wt._ilvl or ""):match("Tier 5") then
                return "world hover reads '" .. tostring(wt._ilvl)
                    .. "'; tier 5 should read as a Tier"
            end

            -- activityInfo.level counts in different units per category,
            -- and one "+%d" across all three was right only for Mythic+.
            -- The fixture gives Mythic+ a keystone 10 and World tier 5.
            local mp = ui.rows.mplus.slots[1]._ilvl or ""
            if not mp:match("%+10") then
                return "mythic+ hover reads '" .. mp .. "'; keystone 10 should read as +10"
            end
            -- Raid's branch (a difficulty id through GetDifficultyInfo)
            -- is NOT exercised: raid has to stay untouched in the
            -- fixture so a "locked" state exists at all, and an
            -- untouched row earns nothing to label.

            -- And the structural half of the overlap fix: the reward
            -- label's right edge is pinned to the fraction's left, so it
            -- truncates instead of running underneath whatever the text
            -- turns out to be.
            if wt.big:GetText() ~= "292" then
                return "the card's item level reads '" .. tostring(wt.big:GetText())
                    .. "'; it should be the bare number"
            end

            -- The card's art. An earned slot shows what it is holding;
            -- an unearned one shows an empty socket. Both directions
            -- matter: an icon on every card would mean the reward
            -- lookup is answering for slots that have no reward.
            -- A region anchored to one edge AND to a centre has its
            -- height decided by those anchors, and SetHeight is ignored
            -- -- silently. The label's backing band was BOTTOMLEFT plus
            -- RIGHT, so it covered the whole scene instead of 34px of
            -- it, and looked like the art had been faded on purpose.
            for key, row in pairs(ui.rows) do
                for _, pair in ipairs({ { "artFoot", row.artFoot },
                                        { "artFade", row.artFade } }) do
                    local name, tex = pair[1], pair[2]
                    for _, pt in ipairs((tex and tex._pts) or {}) do
                        local p = tostring(pt.p or "")
                        if p == "LEFT" or p == "RIGHT" or p == "CENTER"
                            or p == "TOP" or p == "BOTTOM" then
                            return key .. " " .. name .. " is anchored by '" .. p
                                .. "', which fixes a centre and overrides its size"
                        end
                    end
                end
            end

            -- The category scenes are back, so assert what actually
            -- went wrong with them last time: three rows must draw three
            -- DIFFERENT scenes, and each must have one.
            local scenes = {}
            for key, row in pairs(ui.rows) do
                local a = row.art and row.art:GetAtlas()
                if not a then return key .. " row drew no category scene" end
                if scenes[a] then
                    return "rows " .. scenes[a] .. " and " .. key
                        .. " drew the same scene: " .. a
                end
                scenes[a] = key

                for s, tile in ipairs(row.slots or {}) do
                    local earned = tile._slotState == "unlocked"
                    -- The padlock is shown on exactly the slots that
                    -- are not yours. There is no reward icon to check
                    -- against it any more -- the reward is words at the
                    -- foot of the card and the item on hover.
                    if tile.lock:IsShown() ~= (not earned) then
                        return key .. " slot " .. s .. " lock does not match its state"
                    end
                    -- The hover has to have something to say either way,
                    -- or a card is dead to the mouse.
                    if not (tile._need and tile._progress) then
                        return key .. " slot " .. s .. " has no tooltip content"
                    end
                    -- And it must never carry an item link. The reward
                    -- is random until claimed; the example the API
                    -- returns is only good for its item level, and a
                    -- tooltip built from it would promise a drop the
                    -- vault has not chosen.
                    if tile._link then
                        return key .. " slot " .. s .. " stashed an item link for its tooltip"
                    end
                    if earned ~= (tile._ilvl ~= nil) then
                        return key .. " slot " .. s .. " state and reward text disagree"
                    end
                    -- The caption has to clear the checkmark.
                    local capX = tile.caption._pts and tile.caption._pts[1]
                        and tile.caption._pts[1].x
                    if tile.check:IsShown() and (capX or 0) < 20 then
                        return key .. " slot " .. s
                            .. " caption starts at " .. tostring(capX) .. ", under its checkmark"
                    end
                end
            end
            return "ok"
        end
    """)(ns)
    if vault == "ok":
        print("  ok   vault grid: tallies, state colours, bar lengths and "
              "banked item levels agree; three distinct scenes")
    else:
        print("  FAIL vault grid: %s" % vault)
        failures.append(("vault grid", str(vault)))

    # The plan has to talk about improving a reward, not only unlocking
    # one. Those are different jobs and it only ever spoke about the
    # second -- once a slot is yours the count stops mattering and the
    # level starts.
    plan = L.eval("""
        function(ns)
            local GUILLEMET = string.char(0xC2, 0xBB)
            local P = ns.Planner
            if not (P and P.BuildPlan) then return "no planner" end
            local ok, built = pcall(P.BuildPlan, P)
            if not ok then return "BuildPlan failed: " .. tostring(built) end
            local items = (built and built.items) or {}
            if #items == 0 then return "the plan came back empty" end

            local upgrade
            for _, it in ipairs(items) do
                if tostring(it.detail or ""):match("reward goes from %d+ to %d+") then
                    upgrade = it
                end
            end
            if not upgrade then
                return "nothing in the plan offers to improve a reward"
            end

            -- Every row is an instruction, and an instruction leads
            -- with the doing.
            --
            -- The titles used to be "2 more M+ runs " .. GUILLEMET ..
            -- " unlocks vault slot 1": the payoff in the bold line and
            -- the actual advice stranded in brackets underneath. A
            -- panel called Worth Doing Tonight should lead with the
            -- action, so the split is now title = what to do, detail =
            -- what it buys, and both halves have to be there.
            for _, it in ipairs(items) do
                local t = tostring(it.title or "")
                if t:find(GUILLEMET, 1, true) then
                    return "a plan title still packs two facts into one line: '" .. t .. "'"
                end
                if (it.detail or "") == "" then
                    return "a plan row says what to do and not what it buys: '" .. t .. "'"
                end
            end

            -- Nothing may offer a trip that changes nothing.
            --
            -- At the top of a reward ladder the next rung sits inside
            -- the same bracket, and this rendered on a live character
            -- as an offer to raise a reward from 318 to 318: go and run
            -- something in order to stand still. It is the plan at its
            -- least trustworthy, because it is the one row anyone can
            -- check against the vault in front of them.
            for _, it in ipairs(items) do
                local from, to = tostring(it.detail or ""):match(
                    "reward goes from (%d+) to (%d+)")
                if from and tonumber(to) <= tonumber(from) then
                    return "the plan offers an upgrade from " .. from .. " to " .. to
                end
            end

            -- A currency threshold the client cannot be asked about, so
            -- the number is written down and the currency is found by
            -- NAME -- a guessed id reads zero rather than erroring, and
            -- would turn this into a confidently wrong suggestion.
            --
            -- Built, but held back: 483 of 750 is a savings balance
            -- that fills itself while you do the rows above it, so on a
            -- week with real work in it the panel must not spend a card
            -- on it. `deferred` is where it goes, and looking there
            -- rather than only checking it is absent is what tells
            -- "correctly demoted" apart from "never built".
            local accolade
            for _, it in ipairs(built.deferred or {}) do
                if tostring(it.title or ""):match("Field Accolade") then accolade = it end
            end
            if not accolade then
                return "nothing in the plan mentions Field Accolades"
            end
            if not accolade.title:match("483 of 750") then
                return "accolades read '" .. accolade.title .. "'; expected 483 of 750"
            end
            if not tostring(accolade.detail or ""):match("267") then
                return "accolades do not say 267 more buys the piece"
            end
            for _, it in ipairs(items) do
                if tostring(it.title or ""):match("Field Accolade") then
                    return "a savings balance took a card on a week with " .. #items
                        .. " real things to do"
                end
            end
            -- ...and the demotion must not be a delete. A thin week is
            -- exactly when a counter earns its row, so the floor has to
            -- let it back in.
            if #items < 3 then
                return "the plan is " .. #items .. " rows and did not pad from " ..
                    #(built.deferred or {}) .. " held back"
            end

            if not (ns.FindCurrencyByName and ns:FindCurrencyByName("Field Accolade")) then
                return "the currency lookup found nothing to build that on"
            end
            if ns:FindCurrencyByName("No Such Currency") then
                return "control: the currency lookup matched a name that does not exist"
            end

            -- Plan titles have to fit one line of a half-width card.
            -- Wrapping pushed them through the detail line underneath,
            -- and the cards are half the width they were built for.
            -- 46 characters is roughly what a ~347px card holds at
            -- GameFontNormal; the margin is deliberate, not measured to
            -- the pixel.
            for _, it in ipairs(items) do
                local t = tostring(it.title or "")
                if #t > 46 then
                    return "a plan title is " .. #t .. " characters and will not fit: '" .. t .. "'"
                end
            end

            -- The fixture's Mythic+ slot qualified at +10 and the stub
            -- offers +12 for item level 302.
            if not upgrade.title:match("%+12") then
                return "upgrade reads '" .. upgrade.title .. "'; expected the next key level"
            end
            if not upgrade.detail:match("302") then
                return "upgrade detail reads '" .. upgrade.detail ..
                    "'; expected the item level it buys"
            end
            -- Delves must stay silent: the client returns no data for
            -- them, and a made-up rung would be worse than nothing.
            for _, it in ipairs(items) do
                if it.category == "world"
                    and tostring(it.detail):match("reward goes from") then
                    return "a delve upgrade was invented; the client has no data for it"
                end
            end

            -- A reward you would not wear is not urgent, whatever it
            -- fills. The fixture wears 289 and the upgrade pays 302, so
            -- that one must NOT be demoted...
            if upgrade.notUpgrade then
                return "a 302 reward was called worthless to a character wearing 289"
            end
            -- ...and the same call on a reward at or below what is worn
            -- must be, or the comparison never fires and every plan
            -- looks identical on a geared character.
            local probe = { priority = 1, detail = "x" }
            local ranked = P._RankByReward and P._RankByReward(probe, 285)
            if not ranked then return "no reward ranking to test" end
            if not ranked.notUpgrade then
                return "a 285 reward was called an upgrade to a character wearing 289"
            end
            if ranked.priority <= 1 then
                return "a non-upgrade kept its place at the top of the plan"
            end
            return "ok"
        end
    """)(ns)
    if plan == "ok":
        print("  ok   plan: offers the next key level and what it raises the reward to")
    else:
        print("  FAIL plan: %s" % plan)
        failures.append(("plan", str(plan)))

    # Which raids the Loot Browser calls current.
    #
    # The Encounter Journal lists a tier's raids oldest first, so the one
    # anyone is running came LAST and the page opened on retired loot.
    # The split is decidable here: it reads a name out of the progression
    # data file and cuts the journal's list on it. Worth pinning, because
    # both halves of it are silent when they go wrong -- a name that
    # stopped matching leaves the whole list "current", and an off-by-one
    # on the cut folds the season's raid away behind the disclosure.
    tiers = L.eval("""
        function(ns)
            if not ns.SplitRaidsByTier then return "no SplitRaidsByTier" end
            local season = ns.PROGRESSION and ns.PROGRESSION.RAID_NAME
            if not season then return "no season raid named in PROGRESSION" end

            local lair = ns.PROGRESSION.LAIRS and ns.PROGRESSION.LAIRS.name
            if not lair then return "no Lair named in PROGRESSION" end

            -- The journal's order for the two current instances is not
            -- ours: the Lair is one boss filling the same vault row, so
            -- it goes under the raid whichever way round they arrive.
            local list = {
                { name = "Two Tiers Ago" },
                { name = lair },
                { name = "Last Tier" },
                { name = season },
            }
            local cur, prev = ns:SplitRaidsByTier(list)
            if #cur ~= 2 then
                return "expected the raid and the Lair to be current, got " .. #cur
            end
            if cur[1].name ~= season or cur[2].name ~= lair then
                return "current order is '" .. tostring(cur[1].name) .. "' then '" ..
                    tostring(cur[2].name) .. "', wanted the raid then the Lair"
            end
            -- Newest of the retired raids on top, or the fold opens on
            -- the oldest content in the game.
            if #prev ~= 2 or prev[1].name ~= "Last Tier" then
                return "retired raids came back in the wrong order"
            end

            -- A raid the journal knows and the data file does not is
            -- newer than ours, not older: it must not be folded away.
            local ahead = {
                { name = "Last Tier" },
                { name = season },
                { name = "Whatever Comes Next" },
            }
            local cur2, prev2 = ns:SplitRaidsByTier(ahead)
            if #cur2 ~= 2 or #prev2 ~= 1 then
                return "a raid listed after the season's was folded away"
            end

            -- No match at all: the journal's own ordering still says the
            -- last one is current. Falling through to "all previous"
            -- would hide every raid on the page.
            local stale = { { name = "A" }, { name = "B" } }
            local cur3, prev3 = ns:SplitRaidsByTier(stale)
            if #cur3 ~= 1 or cur3[1].name ~= "B" or #prev3 ~= 1 then
                return "an unrecognised raid list left nothing current"
            end

            -- The journal's string is the one that has to match, and
            -- ours came off patch notes. A leading "The" must not be
            -- what decides whether the Lair is current.
            local article = {
                { name = (lair:gsub("^The%s+", "")) },
                { name = "The " .. (season:gsub("^The%s+", "")) },
            }
            local cur4 = ns:SplitRaidsByTier(article)
            if #cur4 ~= 2 then
                return "a leading 'The' decided whether an instance was current"
            end

            local none, nonePrev = ns:SplitRaidsByTier({})
            if #none ~= 0 or #nonePrev ~= 0 then return "empty list not handled" end
            return "ok:" .. season .. " + " .. lair
        end
    """)(ns)
    if tiers and str(tiers).startswith("ok:"):
        print("  ok   raid tiers: %s lead, older raids fold behind the disclosure"
              % str(tiers)[3:])
    else:
        print("  FAIL raid tiers: %s" % tiers)
        failures.append(("raid tiers", str(tiers)))

    # Glyphs the client's font cannot draw.
    #
    # U+2192 shipped to screen as an empty box in the middle of a vault
    # suggestion, and a grep found the identical mistake already sitting
    # in Recommend.lua -- written independently, months apart. That is a
    # trap rather than a slip, so it gets a check.
    #
    # A blocklist, not an allowlist: the font's real coverage is not
    # knowable from here, and guessing at it would either ban half the
    # em dashes the addon already relies on or wave everything through.
    # These are the ones observed or strongly suspected to fail.
    BANNED = {
        0x2192: "RIGHTWARDS ARROW (seen as an empty box in game)",
        0x2190: "LEFTWARDS ARROW",
        0x21D2: "RIGHTWARDS DOUBLE ARROW",
        0x2713: "CHECK MARK",
        0x2714: "HEAVY CHECK MARK",
        0x2718: "HEAVY BALLOT X",
    }
    print("\nglyphs:")
    lua_files = toc_files()   # already only .lua, relative to ROOT
    offenders = []
    for path in lua_files:
        try:
            text = open(os.path.join(ROOT, path), encoding="utf-8").read()
        except (OSError, UnicodeDecodeError):
            continue
        for lineno, line in enumerate(text.split("\n"), 1):
            if line.lstrip().startswith("--"):
                continue        # commentary, never drawn
            for ch in line:
                if ord(ch) in BANNED:
                    offenders.append("%s:%d %s"
                                     % (path, lineno, BANNED[ord(ch)]))
    # Control: the detector has to see one when it is there.
    if not any(ord(c) in BANNED for c in "a→b"):
        print("  FAIL control: the glyph detector cannot see U+2192")
        failures.append(("glyphs", "detector is vacuous"))
    else:
        print("       ^ control: the detector sees U+2192 in a test string")
    if offenders:
        for o in offenders[:8]:
            print("  FAIL glyph the client cannot draw: %s" % o)
        failures.extend(("glyphs", o) for o in offenders)
    else:
        print("  ok   no un-drawable glyphs in %d drawn strings" % len(lua_files))

    # The Best in Slot doll's two columns must be inset by the same
    # amount. They were positioned from PAD and DOLL_W separately while
    # the panel around them starts at PAD-6 and is DOLL_W+4 wide -- so
    # the arithmetic agreed with nothing and the doll sat 10px in on the
    # left and 2px in on the right. Two numbers that have to match are
    # worth asserting rather than hoping.
    doll = L.eval("""
        function(ns)
            local ins = ns.BisUI and ns.BisUI._dollInsets
            if not ins then return "the doll never published its insets" end
            if not (ins.left and ins.right) then return "insets incomplete" end
            if math.abs(ins.left - ins.right) > 0.5 then
                return string.format("left inset %.0f, right inset %.0f",
                    ins.left, ins.right)
            end
            if ins.left < 4 then
                return string.format("both insets are only %.0f; the doll is against its edges",
                    ins.left)
            end
            return "ok:" .. tostring(math.floor(ins.left))
        end
    """)(ns)
    if doll and str(doll).startswith("ok:"):
        print("  ok   BiS doll: both columns inset %spx from the panel" % str(doll)[3:])
    else:
        print("  FAIL BiS doll: %s" % doll)
        failures.append(("BiS doll", str(doll)))

    # The Delves page. Built and refreshed, not merely loaded.
    #
    # The claims worth pinning are the ones the page was scoped around:
    # the companion is read as a FRIENDSHIP rank rather than a level or a
    # reputation, the tier ladder is the shared Progression table rather
    # than a second copy, and a companion the player has not unlocked
    # draws an honest empty state instead of a row of zeroes.
    delves = L.eval("""
        function(ns)
            local page = ns.Shell and ns.Shell.GetPage and ns.Shell:GetPage("delves")
            if not page then return "no delves page registered" end

            local host = CreateFrame("Frame")
            host:SetSize(700, 620)
            local ok, err = pcall(page.Build, host)
            if not ok then return "build failed: " .. tostring(err) end
            local ok2, err2 = pcall(page.Refresh, { content = host, width = 700, height = 620 })
            if not ok2 then return "refresh failed: " .. tostring(err2) end

            local ui = ns.DelvesUI
            if not ui then return "the page published nothing" end

            -- Friendship rank, from the ranks call -- not a character
            -- level and not a reputation standing.
            local c = ui._companion
            if not c then return "the companion was not read at all" end
            if c.level ~= 57 or c.maxLevel ~= 60 then
                return "companion reads level " .. tostring(c.level) .. "/"
                    .. tostring(c.maxLevel) .. ", not 57/60"
            end
            -- 1700 of a 1500..2500 rank is a fifth of the way through
            -- it. Measuring from zero instead of from the rank's own
            -- floor would read 68%, which is the classic way to get a
            -- friendship bar wrong.
            if not c.pct or math.abs(c.pct - 0.2) > 0.001 then
                return "companion bar reads " .. tostring(c.pct)
                    .. "; 1700 within a 1500-2500 rank is 0.2"
            end

            -- The ladder is the shared table, so the row count follows
            -- it. A second hand-typed copy would drift the first time a
            -- season changed.
            local tiers = ns.PROGRESSION and ns.PROGRESSION.DELVES or {}
            if #tiers == 0 then return "no tier data to draw" end
            local drawn = 0
            for i, row in pairs(ui.tierRows or {}) do
                if i > 0 and row:IsShown() then drawn = drawn + 1 end
            end
            if drawn ~= #tiers then
                return "drew " .. drawn .. " tier rows for " .. #tiers .. " tiers"
            end

            ------------------------------------------------------------
            ------------------------------------------------------------
            -- The banner.
            --
            -- One texture at the size it was cut, never stretched. The
            -- companion's name and portrait are painted into the art,
            -- so any resampling shows on both -- which is why the size
            -- is asserted here rather than left to the layout.
            ------------------------------------------------------------
            local card = ui.compCard
            if not card.art then return "the companion card has no banner art" end
            if not card.bannerOK then
                return "the banner texture did not load"
            end
            if (card.banner._w or 0) ~= 341 or (card.banner._h or 0) ~= 103 then
                return "the banner is " .. tostring(card.banner._w) .. "x"
                    .. tostring(card.banner._h) .. ", not the 341x103 it was cut at"
            end

            -- The name is part of the art. Drawing our own would put a
            -- second one over the top of it.
            if card.name then
                return "the card draws its own name over the one baked into the art"
            end

            -- Everything written onto the banner must BELONG to it. A
            -- child frame draws above every region its parent owns, so
            -- an overlay owned by the card sits behind the art and the
            -- sign renders blank -- which is exactly what shipped once,
            -- and what no anchor check could have caught.
            for _, pair in ipairs({ { "title", card.title },
                                    { "rank", card.rank },
                                    { "track", card.track },
                                    { "fill", card.fill } }) do
                local label, region = pair[1], pair[2]
                if not region then return "the banner has no " .. label end
                if region._parent ~= card.banner then
                    return label .. " is parented to the card, so the banner "
                        .. "draws on top of it"
                end
            end

            -- And they must clear the baked portrait, which occupies the
            -- left 103px of the art.
            for _, pair in ipairs({ { "title", card.title },
                                    { "rank", card.rank },
                                    { "track", card.track } }) do
                local label, region = pair[1], pair[2]
                local x = nil
                for _, pt in ipairs(region._pts or {}) do
                    if pt.rel == card.banner and tostring(pt.p or ""):find("LEFT") then
                        x = pt.x
                    end
                end
                if not x then
                    return label .. " has no left anchor on the banner"
                end
                if x < 103 then
                    return label .. " starts at " .. x
                        .. ", over the portrait baked into the art"
                end
            end

            -- And the empty state: no companion must not mean rank 0,
            -- and must not leave Valeera's face and name standing in for
            -- a companion the player does not have.
            local realGet = ns.Delves.GetCompanion
            ns.Delves.GetCompanion = function() return nil end
            local ok3 = pcall(page.Refresh, { content = host, width = 700, height = 620 })
            ns.Delves.GetCompanion = realGet
            if not ok3 then return "refresh failed with no companion" end
            if card.art:IsShown() then
                return "the banner still shows Valeera with no companion known"
            end
            local txt = tostring(card.rank:GetText() or "")
                .. tostring(card.title:GetText() or "")
            if txt:match("Rank 0") or txt:match("of 0") then
                return "an unknown companion rendered as '" .. txt .. "'"
            end

            return "ok"
        end
    """)(ns)
    if delves == "ok":
        print("  ok   delves: companion banner is one texture at its cut size, "
              "overlay owned by it, empty state honest")
    else:
        print("  FAIL delves: %s" % delves)
        failures.append(("delves", str(delves)))

    # Tabs. Every strip in the addon goes through these three functions,
    # so the contract is worth stating: a tab reads as selected by TWO
    # signals, and it sits on a rail whether or not its container drew
    # one. Underline alone was the old design and the complaint.
    tabs = L.eval("""
        function(ns)
            if not ns.CreateUnderlineTab then return "no tab constructor" end
            local strip = CreateFrame("Frame")
            strip:SetSize(300, 28)
            local accent = { 0, 0.67, 1 }
            local a = ns.CreateUnderlineTab(strip, "Overview", accent)
            local b = ns.CreateUnderlineTab(strip, "Boss Guide", accent)

            -- The rail, on every tab, always.
            for name, t in pairs({ a = a, b = b }) do
                if not t.baseLine then
                    return "tab " .. name .. " has no baseline to sit on"
                end
                if not t.baseLine:IsShown() then
                    return "tab " .. name .. "'s baseline is hidden"
                end
            end

            ns.SetTabActive(a)
            ns.SetTabInactive(b)

            if not a.selectedBar:IsShown() then return "the active tab has no marker" end
            if b.selectedBar:IsShown() then return "an inactive tab is marked" end

            -- And brightness, which is the half a marker-only check
            -- would miss. The active label must be lighter than the
            -- inactive one, not merely a different hue -- colour alone
            -- was what the old design relied on.
            local ar = select(1, a.label:GetTextColor())
            local br = select(1, b.label:GetTextColor())
            if not (ar and br) then return "tab labels never set a colour" end
            if ar <= br then
                return string.format(
                    "the active label (%.2f) is no brighter than the inactive one (%.2f)",
                    ar, br)
            end

            -- The strip's own continuous rule, and only one of it.
            if not ns.TabBaseline then return "no strip baseline helper" end
            local one = ns.TabBaseline(strip)
            local two = ns.TabBaseline(strip)
            if not one then return "the strip got no rule" end
            if one ~= two then return "a second call drew a second rule over the first" end
            return "ok"
        end
    """)(ns)
    if tabs == "ok":
        print("  ok   tabs: rail on every tab, marker and brightness both move, "
              "one rule per strip")
    else:
        print("  FAIL tabs: %s" % tabs)
        failures.append(("tabs", str(tabs)))

    # The weekly checklist. Two things worth pinning: the client's answer
    # is not the player's to override, and a manual tick expires on its
    # own -- a checklist you have to clear by hand reads as "all done"
    # forever, which is the failure that makes one useless.
    weekly = L.eval("""
        function(ns)
            local Wk = ns.Weekly
            if not (Wk and Wk.GetList) then return "no weekly checklist" end
            YippYappHelperDB = {}

            local rows = Wk:GetList()
            if #rows == 0 then return "the checklist is empty" end

            -- The page has to fit the room the shell gives it at the
            -- default window size. It scrolls, so overflowing is no
            -- longer invisible -- but needing to scroll a dashboard to
            -- see half of it is still the thing that was wrong, and the
            -- budget is worth keeping.
            local Sh = ns.Shell
            local budget = 760 - ((Sh.TITLE_H or 28) + (Sh.GAP or 14)) - (Sh.PAD or 16)
            local ui = ns.ShellHomeUI
            if not (ui and ui._pageH) then return "the page never measured itself" end
            if ui._pageH > budget then
                return string.format(
                    "the page is %dpx in a %dpx region; it needs scrolling to read",
                    ui._pageH, budget)
            end

            -- Nothing may hang off a hidden frame. Hiding does not free
            -- the space: the anchors still resolve, so a section chained
            -- to a plan card that has no content starts a card-height
            -- below the last visible thing -- and on a short plan that
            -- was enough to push this whole section off the page.
            -- Everything that lost its build-time RIGHT anchor when the
            -- two sections went side by side must be given a width on
            -- refresh instead. A frame at zero width draws nothing at
            -- all -- no text, no rule, no card -- and that is not an
            -- error, it is just an absence. The plan's heading was
            -- missed and took the whole lower half of the page with it.
            for _, pair in ipairs({ { "planTitle", ui and ui.planTitle },
                                    { "weekTitle", ui and ui.weekTitle },
                                    { "plan card", ui and ui.plan and ui.plan[1] } }) do
                local name, f = pair[1], pair[2]
                if not f then return "no " .. name .. " built" end
                -- _w, not GetWidth(). GetWidth falls back to 700 for a
                -- frame it cannot resolve, which is a reasonable default
                -- for the harness and exactly wrong here: it reports a
                -- comfortable width for the frame that has none, hiding
                -- the bug this check exists for.
                local w = f._w or 0
                local twoSided = false
                for _, pt in ipairs(f._pts or {}) do
                    local p = tostring(pt.p or "")
                    if p:find("RIGHT") then twoSided = true end
                end
                if w <= 1 and not twoSided then
                    return name .. " has neither a width nor a right anchor, so it draws nothing"
                end
            end

            local anchor = ui and ui.weekTitle and ui.weekTitle._pts
                and ui.weekTitle._pts[1] and ui.weekTitle._pts[1].rel
            if not anchor then return "the weekly section is not anchored" end
            if anchor.IsShown and not anchor:IsShown() then
                return "the weekly section hangs off a hidden frame"
            end

            local manual, auto
            for _, r in ipairs(rows) do
                if r.manual then manual = manual or r else auto = auto or r end
            end
            if not manual then return "no manual item; nothing is tickable" end
            if not auto then return "no automatic item; everything asks the player" end

            -- Every row is a deliberate entry, and nothing is
            -- discovered.
            --
            -- The checklist used to append every currency the client
            -- caps weekly, on the reasoning that the client knows its
            -- own caps and a written-down list rots. True about
            -- currencies, false about chores: what the game meters is
            -- not what a player owes, so the section filled with rows
            -- like "Cap Shard of Dundun" -- metered by the client,
            -- wanted by nobody -- and each one counted against the
            -- "N of N left" tally above it.
            --
            -- The fixture keeps both a currency the character is
            -- engaged with (Restored Coffer Key, 2 of 6 earned) and one
            -- it is not (Shard of Dundun, untouched), because the rule
            -- being pinned is that NEITHER earns a row. A test that
            -- only excluded the untouched one would pass on a filter
            -- that still lets half the noise through.
            for _, r in ipairs(rows) do
                if tostring(r.id or ""):match("^cur:") then
                    return "a currency was discovered into the checklist: '"
                        .. tostring(r.label) .. "'"
                end
            end
            for _, name in ipairs({ "Dundun", "Coffer Key" }) do
                for _, r in ipairs(rows) do
                    if tostring(r.label):find(name, 1, true) then
                        return "'" .. name .. "' is metered by the client, not owed by the player"
                    end
                end
            end

            -- ...and the list is the curated one, entire. Pinned as a
            -- count because the failure this guards against is silent
            -- in both directions: a filter that eats a real row leaves
            -- a checklist that quietly stops asking for something.
            if #rows ~= #(Wk.ITEMS or {}) then
                return "the checklist is " .. #rows .. " rows against "
                    .. #(Wk.ITEMS or {}) .. " deliberate ones"
            end

            -- Nothing can be hidden any more, and that has to be the
            -- answer rather than an error. Hiding existed to delete the
            -- noise discovery produced; with no noise, a filter that
            -- could remove a deliberate row is a settings screen. Old
            -- saved variables still name rows that no longer exist, so
            -- the call has to refuse rather than throw.
            if Wk:Hide("crests") or Wk:Hide("cur:3512") or Wk:Hide(nil) then
                return "a deliberate checklist row could still be hidden"
            end
            -- Crests are capped for the SEASON, not the week, so
            -- reading only the weekly fields gave every crest a cap of
            -- zero -- and "have you capped this week" could then never
            -- answer yes on a character that had.
            local wk = ns:GetCrestWeeklyInfo("Adventurer")
            if not (wk and (wk.weeklyMax or 0) > 0) then
                return "a crest reports no cap at all; the cumulative one was not read"
            end
            if (wk.weeklyRemaining or 1) ~= 0 then
                return "a crest at 300 of 300 still reports "
                    .. tostring(wk.weeklyRemaining) .. " remaining"
            end
            if not wk.cumulative then
                return "a season cap was reported as a weekly one"
            end
            -- And a crest that is NOT capped must still say so, or the
            -- fallback is just answering yes to everything.
            local part = ns:GetCrestWeeklyInfo("Champion")
            if (part.weeklyRemaining or 0) ~= 120 then
                return "a crest at 180 of 300 reports "
                    .. tostring(part.weeklyRemaining) .. " remaining, not 120"
            end

            -- Ticking a manual item sticks, and unticking undoes it.
            if manual.done then return "a fresh character starts with something ticked" end
            Wk:Toggle(manual.item)
            if not (Wk:IsDone(manual.item)) then return "a manual tick did not stick" end
            Wk:Toggle(manual.item)
            if (Wk:IsDone(manual.item)) then return "a manual tick could not be undone" end

            -- An automatic item ignores the player entirely: the answer
            -- does not change, AND nothing is written down. The second
            -- half matters on its own -- IsDone prefers the client's
            -- answer regardless, so a Toggle that wrote anyway would
            -- leave a tick in the store that silently becomes the answer
            -- the day the client stops being able to tell.
            local before = Wk:IsDone(auto.item)
            Wk:Toggle(auto.item)
            if Wk:IsDone(auto.item) ~= before then
                return "an automatic item was overridden by a click"
            end
            for _, rec in pairs(YippYappHelperDB.weekly or {}) do
                if (rec.done or {})[auto.id] then
                    return "clicking an automatic item wrote a tick to the store"
                end
            end

            -- Quest flags: the third way of knowing, and the one that
            -- outranks the other two.
            --
            -- Driven through a synthetic row rather than a shipped one
            -- on purpose. The shipped lists are empty until somebody
            -- confirms ids in game, and a check written against them
            -- would either test nothing today or break the day they are
            -- filled in. What IS asserted about the real rows is that
            -- the field reached the data at all -- plumbing wired to
            -- nothing is the failure this would otherwise miss.
            local wired, filled = 0, 0
            for _, item in ipairs(Wk.ITEMS) do
                if item.quests then
                    wired = wired + 1
                    if #item.quests > 0 then filled = filled + 1 end
                end
            end
            if wired == 0 then
                return "no checklist row carries a quests field; the plumbing is unused"
            end
            -- At least one row has to be answered by real ids, or every
            -- check below this is about a synthetic row and the shipped
            -- list is still entirely hand-ticked.
            if filled == 0 then
                return "no checklist row has any real quest ids in it"
            end

            local realFlagged = C_QuestLog.IsQuestFlaggedCompleted
            local probe = { id = "harnessquest", label = "probe", quests = { 111 } }

            C_QuestLog.IsQuestFlaggedCompleted = function(id) return id == 111 end
            local done, isManual = Wk:IsDone(probe)
            if not done then
                C_QuestLog.IsQuestFlaggedCompleted = realFlagged
                return "a completed quest did not read as done"
            end
            if isManual then
                C_QuestLog.IsQuestFlaggedCompleted = realFlagged
                return "a row answered by the client was still offered as a click"
            end

            -- Any id in the list counts, because one chore is routinely
            -- several ids and only one of them gets completed.
            probe.quests = { 111, 222 }
            C_QuestLog.IsQuestFlaggedCompleted = function(id) return id == 222 end
            if not (Wk:IsDone(probe)) then
                C_QuestLog.IsQuestFlaggedCompleted = realFlagged
                return "only the first id in the list was consulted"
            end

            -- None completed is a real "not yet", not a shrug.
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            local notYet, stillManual = Wk:IsDone(probe)
            if notYet then
                C_QuestLog.IsQuestFlaggedCompleted = realFlagged
                return "an outstanding quest read as done"
            end
            if stillManual then
                C_QuestLog.IsQuestFlaggedCompleted = realFlagged
                return "an outstanding quest fell back to a manual tick"
            end

            -- An empty list is "nothing to go on", which is what keeps a
            -- row that has no id yet behaving exactly as it did before.
            probe.quests = {}
            local _, emptyManual = Wk:IsDone(probe)
            if not emptyManual then
                C_QuestLog.IsQuestFlaggedCompleted = realFlagged
                return "a row with no ids stopped falling back to its manual tick"
            end

            -- And a tick left in the store from before an id existed
            -- must not go on being the answer once one does.
            -- Flag set here rather than inherited from the block above,
            -- so inserting a check between the two cannot silently turn
            -- this one into an assertion about the wrong thing.
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            probe.quests = { 111 }
            Wk:Toggle(manual.item)
            local storeKey
            for k in pairs(YippYappHelperDB.weekly) do storeKey = k end
            YippYappHelperDB.weekly[storeKey].done["harnessquest"] = true
            local stale = Wk:IsDone(probe)
            YippYappHelperDB.weekly[storeKey].done["harnessquest"] = nil
            Wk:Toggle(manual.item)
            C_QuestLog.IsQuestFlaggedCompleted = realFlagged
            if stale then
                return "a stale manual tick outranked the client's quest flag"
            end

            -- And last week's ticks are gone this week. resetAt is set
            -- when the tick is made, so backdating it is exactly what a
            -- reset looks like from the store's point of view.
            Wk:Toggle(manual.item)
            local key
            for k in pairs(YippYappHelperDB.weekly) do key = k end
            if not key then return "a tick was not written to the store" end
            YippYappHelperDB.weekly[key].resetAt = 1
            if Wk:IsDone(manual.item) then
                return "a tick from a previous week survived the reset"
            end
            return "ok"
        end
    """)(ns)
    if weekly == "ok":
        print("  ok   weekly: manual ticks stick, expire at reset, and lose to "
              "both the client's answer and a quest flag")
    else:
        print("  FAIL weekly: %s" % weekly)
        failures.append(("weekly", str(weekly)))

    # ── The raid trainer, actually played ───────────────────────
    #
    # Every other check in this file inspects a page after one render.
    # The trainer is not a page -- it is sixty seconds of a loop whose
    # branches are chosen by where a dot happens to be, and none of that
    # executes at load. A scenario with a misspelled `kind`, a mechanic
    # whose Resolve divides by a nil radius, or an event list left out of
    # time order would all sail through every check above.
    #
    # So: run all seven scenarios, on both difficulties, at a fixed step,
    # for longer than their own duration. The player never moves, which
    # is deliberate -- a stationary dot fails almost everything, and the
    # failure paths are the ones with the arithmetic in them.
    #
    # The claims are then: nothing errored, every event in every timeline
    # actually spawned, and the scoring reached a verdict.
    trainer = L.eval("""
        function(ns)
            local T = ns.RaidTrainer
            if not (T and T.Start) then return "RaidTrainer absent" end
            local S = T.state
            local f = ns.RaidTrainerFrame
            local update = f and f._scripts and f._scripts.OnUpdate
            if not update then return "no OnUpdate handler registered" end

            local played, problems = 0, {}
            local totalFailed = 0
            for _, boss in ipairs(ns.RaidGuide:Ordered()) do
                local sc = ns.RaidTrainerScenarios[boss.id]
                -- A boss can legitimately have a guide and no arena.
                --
                -- The guide comes first for every fight -- it did for the
                -- whole raid -- so "written up but not yet playable" is a
                -- real state and not a defect. The trainer already hides
                -- its own button for these, so nothing offers the player
                -- something that is not there.
                if not sc and boss.guideOnly then
                    -- Nothing to play. Not counted, not complained about.
                elseif not sc then
                    problems[#problems + 1] = boss.id .. ": no scenario"
                else
                    -- Timelines are walked with a cursor that stops at the
                    -- first event not yet due, so an unsorted list silently
                    -- drops everything after the first late entry. Checked
                    -- per phase, because each phase owns its own clock.
                    local phases = sc.phases or { { name = "-", events = sc.events } }
                    local totalEvents = 0
                    for pi, ph in ipairs(phases) do
                        if not ph.events or #ph.events == 0 then
                            problems[#problems + 1] = string.format(
                                "%s phase %d (%s) has no events", boss.id, pi,
                                tostring(ph.name))
                        end
                        local prev = -1
                        for i, ev in ipairs(ph.events or {}) do
                            totalEvents = totalEvents + 1
                            if ev.at < prev then
                                problems[#problems + 1] = string.format(
                                    "%s phase %d: event %d at %.1fs follows %.1fs",
                                    boss.id, pi, i, ev.at, prev)
                            end
                            if not ev.kind then
                                problems[#problems + 1] = string.format(
                                    "%s phase %d: event %d has no kind", boss.id, pi, i)
                            end
                            prev = ev.at
                        end
                        -- A phase with no way to end would strand the round.
                        if not (ph.duration or ph.untilPct or ph.untilClear) then
                            problems[#problems + 1] = string.format(
                                "%s phase %d (%s) has no end condition", boss.id, pi,
                                tostring(ph.name))
                        end
                    end
                    if totalEvents == 0 then
                        problems[#problems + 1] = boss.id .. ": no events at all"
                    end

                    for _, heroic in ipairs({ false, true }) do
                        if not T:Start(boss.id, heroic) then
                            problems[#problems + 1] = boss.id .. ": Start refused"
                        else
                            S.countdown = 0  -- skip the 3-2-1
                            local budget = 0
                            for _, ph in ipairs(sc.phases or {}) do
                                budget = budget + (ph.duration or 45)
                            end
                            if budget == 0 then budget = sc.duration or 60 end
                            local steps = math.ceil((budget + 60) / 0.05)
                            for _ = 1, steps do
                                -- Topped up every step, and this is the
                                -- point of the run rather than a fudge.
                                -- A dot that never moves is dead about
                                -- twenty seconds in, and a dead player
                                -- correctly stops the timeline -- so
                                -- without a healer the back half of
                                -- every scenario would never execute and
                                -- this check would only ever have tested
                                -- the opening. Damage is still computed;
                                -- only the death is undone.
                                S.hp = 100
                                -- And the poison meter, for the same
                                -- reason: Twin Fangs kills on stacks
                                -- rather than on damage, so a health
                                -- top-up alone still ends that round
                                -- early. The stack death is worth
                                -- testing and is tested on its own,
                                -- below, rather than being allowed to
                                -- cut this sweep short.
                                S.stacks = 0
                                S.energy = 0
                                -- Trigger held down for the whole run,
                                -- so the projectile spawn, travel and
                                -- hit-scan actually execute. Left off,
                                -- the entire combat half of the trainer
                                -- would be unreached by every check in
                                -- this file.
                                S.firing = true
                                -- And the boss kept alive, for the same
                                -- reason the health and the poison meter
                                -- are: shots fly straight at it from the
                                -- spawn point, so an un-topped boss dies
                                -- in the first few seconds and takes the
                                -- rest of the timeline with it.
                                if S.bossActor then
                                    S.bossActor.hp = S.bossActor.maxHp
                                end
                                local ok, err = pcall(update, f, 0.05)
                                if not ok then
                                    problems[#problems + 1] = string.format(
                                        "%s (%s): %s", boss.id,
                                        heroic and "heroic" or "normal", tostring(err))
                                    break
                                end
                                -- Revived AFTER the frame as well as
                                -- topped up before it. Death is judged
                                -- at the end of an update, so a pre-emptive
                                -- top-up cannot stop a lethal mechanic --
                                -- Twin Fangs' Stonebreaker deals more than
                                -- the whole health pool by design -- and
                                -- one unlucky landing would end the round
                                -- and silently skip the rest of the
                                -- timeline. Which is exactly the flake this
                                -- check would otherwise have shipped with.
                                if not S.running and S.phaseIndex < #(S.phases or {}) then
                                    S.running, S.hp = true, 100
                                end
                            end
                            -- A round that neither killed the player nor ran
                            -- its timeline out has stalled somewhere.
                            if S.running then
                                problems[#problems + 1] = boss.id .. ": never finished"
                            end
                            if S.passed + S.failed == 0 then
                                problems[#problems + 1] = boss.id .. ": scored nothing"
                            end
                            totalFailed = totalFailed + S.failed
                            -- The phase-shaped version of "everything ran":
                            -- the round has to have reached the last phase
                            -- and exhausted its timeline.
                            local nPhases = #(S.phases or {})
                            if S.phaseIndex < nPhases then
                                problems[#problems + 1] = string.format(
                                    "%s stalled in phase %d of %d (%s)", boss.id,
                                    S.phaseIndex, nPhases,
                                    tostring((S.phases[S.phaseIndex] or {}).name))
                            end
                            played = played + 1
                        end
                        T:Stop()
                    end
                end
            end
            -- See the note above: aggregate, not per boss.
            if totalFailed == 0 then
                problems[#problems + 1] =
                    "a motionless player missed nothing across every round"
            end
            if #problems > 0 then return table.concat(problems, "; ") end
            return "ok:" .. played
        end
    """)(ns)
    if trainer and str(trainer).startswith("ok:"):
        print("  ok   trainer: %s rounds played to a verdict, every event spawned"
              % str(trainer)[3:])
    else:
        print("  FAIL trainer: %s" % trainer)
        failures.append(("trainer", str(trainer)))

    # Twin Fangs kills on the poison meter rather than on damage, which
    # is the one mechanic in the trainer that can end a round while the
    # player is at full health. The sweep above holds the meter at zero
    # so the rest of that timeline gets to run, so this is the only place
    # the stack death is exercised at all.
    #
    # Health is topped up here too: the claim under test is specifically
    # that STACKS kill, and a round that ended because a motionless dot
    # stood in a puddle would prove nothing.
    stacks = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate
            local sc = ns.RaidTrainerScenarios.twinfangs
            if not (sc and sc.stacks) then return "twinfangs has no stack meter" end

            -- Several rounds, and the claim is that the meter CAN fill.
            --
            -- The trainer spawns its casts at random, so a single round
            -- may legitimately not throw enough poison -- roughly one in
            -- seven did not. Asserting a lucky round made this fail
            -- intermittently, which is worse than failing always: an
            -- occasional red makes every green ambiguous and teaches you
            -- to re-run until it goes quiet. The seed is fixed as well,
            -- so this is reproducible rather than merely likely.
            -- Reseeded HERE, not only at startup.
            --
            -- A seed fixed once makes a run reproducible but leaves
            -- this outcome hostage to how many random numbers every
            -- file loaded before it happened to consume. An edit in
            -- an unrelated page shifted the sequence and turned this
            -- red. Seeding at the point of use makes these rounds
            -- depend on the trainer and on nothing else.
            math.randomseed(20260817)
            local best, killed = 0, false
            for _ = 1, 5 do
                T:Start("twinfangs", false)
                S.countdown = 0
                local peak = 0
                local budget = 0
                for _, ph in ipairs(sc.phases or {}) do
                    budget = budget + (ph.duration or 45)
                end
                for _ = 1, math.ceil((budget + 60) / 0.05) do
                    S.hp = 100
                    update(f, 0.05)
                    if S.stacks > peak then peak = S.stacks end
                    if not S.running and S.phaseIndex < #(S.phases or {}) then
                        S.running, S.hp = true, 100
                    end
                    if not S.running then break end
                end
                if peak >= sc.stacks.max and S.hp <= 0 then killed = true end
                if peak > best then best = peak end
                T:Stop()
                if killed then break end
            end

            if best < sc.stacks.max then
                return string.format(
                    "over five rounds the meter only reached %d of %d, so it can never kill",
                    best, sc.stacks.max)
            end
            if not killed then
                return "the meter filled but no round ended"
            end
            return "ok:" .. best
        end
    """)(ns)
    if stacks and str(stacks).startswith("ok:"):
        print("  ok   trainer: Twin Fangs' poison meter fills to %s and kills"
              % str(stacks)[3:])
    else:
        print("  FAIL trainer stacks: %s" % stacks)
        failures.append(("trainer stacks", str(stacks)))

    # Shooting, end to end. The sweep above holds the boss at full health
    # so the rest of each timeline gets to run, which means nothing there
    # ever proves a bullet can actually finish something -- only that the
    # code runs without erroring.
    #
    # A control comes first: with the trigger released, the boss must
    # take no damage at all. Without it, "the boss died" would be
    # consistent with the boss dying of something else entirely.
    guns = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate

            -- Control: trigger up AND the raid silenced -- nothing at all
            -- is shooting, so the boss must be untouched. The raid has to
            -- be silenced explicitly now that it fires on its own; without
            -- that, "the boss lost health" would be true no matter what
            -- the player did and the control would prove nothing.
            local function silenceRaid()
                for _, ally in ipairs(S.allies) do ally.stagger = 999 end
            end

            T:Start("soulcoiler", false)
            S.countdown = 0
            for _ = 1, 400 do
                S.hp, S.firing = 100, false
                silenceRaid()
                update(f, 0.05)
            end
            if S.bossActor.hp < S.bossActor.maxHp then
                T:Stop()
                return "control: the boss lost health with nothing shooting"
            end
            T:Stop()

            -- The raid alone must land damage, or "allies attack the
            -- boss" is a claim nothing in this file checks.
            T:Start("soulcoiler", false)
            S.countdown = 0
            for _ = 1, 400 do
                S.hp, S.firing = 100, false
                update(f, 0.05)
            end
            local raidOnly = S.bossActor.maxHp - S.bossActor.hp
            T:Stop()
            if raidOnly <= 0 then
                return "the raid never damaged the boss"
            end

            -- Held fire, aimed at the centre where the boss stands.
            --
            -- Seeded, because these checks share one RNG stream and this
            -- one had no margin: it finished the boss with about three
            -- percent of the bar to spare, so ANY change to how many
            -- random numbers an earlier check consumed re-rolled the
            -- whole pull and it failed on a file it never touched.
            -- Adding a second boss to the Twin Fangs did exactly that
            -- and the failure surfaced on Nek'zali.
            math.randomseed(20260817)
            T:Start("soulcoiler", false)
            S.countdown = 0
            local killed, adds = false, 0
            for _ = 1, 3000 do
                S.hp, S.firing = 100, true
                -- Stand diametrically opposite the boss, so the firing
                -- line runs through it.
                --
                -- The harness's cursor is pinned at the arena centre, so
                -- the player always aims at the middle -- which used to
                -- hit a boss that was always parked there. Now that the
                -- boss is tanked off the well and shoved around by
                -- puddles, "shots reach the boss" has to be arranged
                -- rather than assumed, or this measures the boss's
                -- position instead of the gun.
                local b = S.bossActor
                if b then
                    local d = math.sqrt(b.x * b.x + b.y * b.y)
                    if d > 1 then
                        S.px, S.py = -b.x / d * 60, -b.y / d * 60
                    else
                        S.px, S.py = 0, -60
                    end
                end
                update(f, 0.05)
                if S.bossActor.hp <= 0 then killed = true end
                if not S.running then break end
            end
            for _ = 1, #S.actors do adds = adds + 1 end
            T:Stop()

            if not killed then
                return string.format(
                    "sustained fire never killed the boss (phase %d/%d, hp %.0f/%.0f, running %s)",
                    S.phaseIndex, #S.phases, S.bossActor.hp, S.bossActor.maxHp,
                    tostring(S.running))
            end
            return "ok:" .. math.floor(raidOnly)
        end
    """)(ns)
    # The raid AI, which had shipped once looking like scenery: six
    # allies parked in a ring, not moving and not reacting, because the
    # only group mechanic on that boss was a spread and they had no
    # response to one. "They look busy" is not testable, but the three
    # things underneath it are, and all three are checked with the
    # player's trigger RELEASED so nothing here can be the player's doing.
    raid = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate

            -- Vashnik on purpose: adds plus a spread, and no soak on
            -- normal. It is the scenario the idle-raid bug showed up on.
            T:Start("vashnik", false)
            S.countdown = 0

            local moved, addDamage, spreadSeen = 0, 0, false
            local mostOut, tankOut, tankStray = 0, false, 0
            local meleeOut, runOutFar = 0, 0
            local worstGap, spreadNeed = nil, 0
            local prev = {}
            for i, a in ipairs(S.allies) do prev[i] = { a.x, a.y } end

            for _ = 1, 1200 do
                S.hp, S.firing = 100, false
                if S.bossActor then S.bossActor.hp = S.bossActor.maxHp end
                update(f, 0.05)

                local out = 0
                for i, a in ipairs(S.allies) do
                    moved = moved + math.sqrt((a.x-prev[i][1])^2 + (a.y-prev[i][2])^2)
                    prev[i][1], prev[i][2] = a.x, a.y
                    if a.runOut then
                        out = out + 1
                        if a.role == "TANK" then tankOut = true end
                        if a.role == "MELEE" then meleeOut = meleeOut + 1 end
                        -- How far from the middle a run-out actually
                        -- reaches. The complaint was that a spread sent
                        -- people to the wall; the arena's radius is 100.
                        local far = math.sqrt(a.x * a.x + a.y * a.y)
                        if far > runOutFar then runOutFar = far end
                    end
                    if a.role == "TANK" and S.bossActor then
                        local d = math.sqrt((a.x-S.bossActor.x)^2 + (a.y-S.bossActor.y)^2)
                        if d > tankStray then tankStray = d end
                    end
                end
                if out > mostOut then mostOut = out end

                for _, act in ipairs(S.actors) do
                    if act.kind == "spread" and not act.resolved then
                        spreadSeen = true
                        -- The point of a spread is that everybody
                        -- carrying it ends up apart. Measured over the
                        -- player AND every ally who has it, because the
                        -- reported bug was three circles sitting on top
                        -- of each other while the mechanic reported
                        -- itself handled.
                        spreadNeed = act.minDist or 24
                        local pts = { { S.px, S.py } }
                        for _, a in ipairs(S.allies) do
                            if a.runOut and a.runOutTag == act.name then
                                pts[#pts + 1] = { a.x, a.y }
                            end
                        end
                        -- Only once they have had time to get there.
                        if S.time - act.born > (act.cast or 3) * 0.9 then
                            for i = 1, #pts do
                                for j = i + 1, #pts do
                                    local g = math.sqrt((pts[i][1]-pts[j][1])^2
                                                      + (pts[i][2]-pts[j][2])^2)
                                    if not worstGap or g < worstGap then worstGap = g end
                                end
                            end
                        end
                    end
                    if act.enemy and act.maxHp and act.hp < act.maxHp then
                        addDamage = addDamage + 1
                    end
                end
                if not S.running then break end
            end
            T:Stop()

            if moved < 200 then
                return string.format("the raid barely moved (%.0f units over a round)", moved)
            end
            if addDamage == 0 then
                return "the raid never damaged an add"
            end
            if not spreadSeen then
                return "no spread happened, so the reaction to one was never tested"
            end
            -- The reported bug: a spread landed and the ENTIRE raid
            -- sprinted for the wall. A couple of them going is the
            -- mechanic; all of them going is not, and both look like
            -- "the raid reacted" unless the count is checked.
            if mostOut == 0 then
                return "nobody in the raid ever took a spread"
            end
            if mostOut > 3 then
                return string.format("%d allies ran out at once -- the whole raid is reacting", mostOut)
            end
            if tankOut then
                return "the tank abandoned the boss for a raid mechanic"
            end
            -- The tank holds the boss, so it should never be found out
            -- near the wall. Generous bound: this is checking that it
            -- stays tanking, not that it stands perfectly still.
            if tankStray > 45 then
                return string.format("the tank wandered %.0f units from the boss", tankStray)
            end
            -- The arena's radius is 100. A spread wants separation, not
            -- an evacuation, and the reported bug was melee crossing the
            -- whole room and back for a mechanic that needed a few steps.
            if runOutFar > 78 then
                return string.format("a run-out reached %.0f of the 100-unit radius -- that is the wall", runOutFar)
            end
            -- Ranged step aside and step back; melee would have to leave
            -- the boss entirely. With three ranged free, no melee should
            -- ever be picked.
            if meleeOut > 0 then
                return "melee were sent out while ranged were available"
            end
            -- Circles are drawn at a diameter of minDist, so "not
            -- touching" and "correctly spread" are the same statement.
            -- Anything under minDist is overlapping circles on screen.
            if not worstGap then
                return "never measured a spread at resolution time"
            end
            if worstGap < spreadNeed then
                return string.format(
                    "spread left two of them %.0f apart, inside the %d they needed -- the circles overlap",
                    worstGap, spreadNeed)
            end
            return string.format(
                "ok:%.0f units moved, at most %d out at once (none melee), spread gap %.0f >= %d, tank held within %.0f",
                moved, mostOut, worstGap, spreadNeed, tankStray)
        end
    """)(ns)
    if raid and str(raid).startswith("ok:"):
        print("  ok   trainer raid: %s; adds take fire" % str(raid)[3:])
    else:
        print("  FAIL trainer raid: %s" % raid)
        failures.append(("trainer raid", str(raid)))

    # Boss one, end to end.
    #
    # Nek'zali is the test case for the rebuild: it exercises the raid AI
    # in every mode that matters -- a formation with one of each role,
    # adds walked to the well, a targeted personal mechanic that goes to
    # the wall, an intermission that ends when the field is clear, and a
    # boss that turns so the frontal has somewhere new to point.
    #
    # Named checks rather than a sweep, because when this one fails the
    # useful output is WHICH of those stopped working.
    bossone = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate
            local sc = ns.RaidTrainerScenarios.soulcoiler
            local problems = {}

            T:Start("soulcoiler", false)

            -- The formation: one of each role, and a healer at all.
            local seen = {}
            for _, a in ipairs(S.allies) do
                seen[a.role] = (seen[a.role] or 0) + 1
            end
            for _, role in ipairs({ "TANK", "HEALER", "MELEE", "RANGED" }) do
                if not seen[role] then
                    problems[#problems + 1] = "no " .. role .. " in the raid"
                end
            end
            if seen.TANK ~= 1 then
                problems[#problems + 1] = "expected exactly one tank"
            end

            S.countdown = 0
            local fired, reached, facings = {}, 1, {}
            local budget = 0
            for _, ph in ipairs(sc.phases) do budget = budget + (ph.duration or 45) end

            for _ = 1, math.ceil((budget + 90) / 0.05) do
                S.hp, S.firing = 100, true
                update(f, 0.05)
                if S.phaseIndex > reached then reached = S.phaseIndex end
                for _, a in ipairs(S.actors) do
                    fired[tostring(a.name)] = true
                end
                if S.bossActor then
                    -- Rounded, so a turning boss produces several buckets
                    -- and a stuck one produces exactly one.
                    facings[math.floor((S.bossActor.facing or 0) * 2)] = true
                end
                if not S.running and S.phaseIndex < #S.phases then
                    S.running, S.hp = true, 100
                end
                if not S.running then break end
            end
            T:Stop()

            if reached < #sc.phases then
                problems[#problems + 1] = string.format(
                    "only reached phase %d of %d", reached, #sc.phases)
            end
            for _, want in ipairs({
                "Restless Amani", "Possession Barrage", "Essence Rend",
                "Echo of Jawae", "Hungering Pyre",
            }) do
                if not fired[want] then
                    problems[#problems + 1] = want .. " never fired"
                end
            end

            local turns = 0
            for _ in pairs(facings) do turns = turns + 1 end
            if turns < 3 then
                problems[#problems + 1] =
                    "the boss barely turned, so the frontal never moved"
            end

            if #problems > 0 then return table.concat(problems, "; ") end
            return string.format("ok:%d phases, %d facings, one of each role", reached, turns)
        end
    """)(ns)
    if bossone and str(bossone).startswith("ok:"):
        print("  ok   trainer boss one: %s" % str(bossone)[3:])
    else:
        print("  FAIL trainer boss one: %s" % bossone)
        failures.append(("trainer boss one", str(bossone)))

    # Hungering Pyre's split.
    #
    # Soaking marks you Singed and you should sit the next one out;
    # everybody who stays out is set alight instead, and the Flames are a
    # job rather than a punishment. Scored in-good/out-bad the mechanic
    # collapsed to two outcomes and the alternation was invisible.
    #
    # This checks the STRUCTURE -- that the mark is applied, that staying
    # out sets you alight, and that soaking while still marked costs more
    # than soaking clean. It deliberately does NOT try to prove
    # alternating is the optimal line: total misses in that phase are
    # dominated by the adds and the Echoes, so a score comparison there
    # measures everything except the mechanic. Proving that needs
    # per-mechanic scoring, which the trainer does not keep.
    split = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate

            --- Run to the intermission and hand back the live Pyre.
            local function toPyre()
                T:Start("soulcoiler", false)
                S.countdown = 0
                for _ = 1, 4000 do
                    S.hp = 100
                    if S.bossActor then
                        S.bossActor.hp = S.bossActor.maxHp * 0.5
                    end
                    update(f, 0.05)
                    if not S.running then return nil end
                    if S.phaseIndex >= 2 then
                        for _, a in ipairs(S.actors) do
                            if a.kind == "soak" and a.marks and not a.resolved then
                                return a
                            end
                        end
                    end
                end
                return nil
            end

            -- 1. Soaking marks you.
            local pyre = toPyre()
            if not pyre then T:Stop(); return "never reached a Hungering Pyre" end
            local clean
            for _ = 1, 400 do
                S.hp = 100
                S.px, S.py = pyre.x, pyre.y
                local before = S.hp
                update(f, 0.05)
                if pyre.resolved then clean = before - S.hp break end
                if not S.running then break end
            end
            local singed = (S.debuffs["Singed"] or 0) > S.time
            -- And nothing was set alight by the cast we just soaked.
            -- "I soaked, got Singed, and still got the circle" is the
            -- report this exists to settle, and reasoning about it from
            -- the source was not good enough twice running.
            local flamesOnSoaker = false
            for _, a in ipairs(S.actors) do
                if a.name == "Slithering Flames" then flamesOnSoaker = true end
            end
            T:Stop()
            if not singed then return "soaking did not apply the Singed mark" end
            if flamesOnSoaker then
                return "soaking the Pyre set the soaker alight anyway"
            end

            -- 2. Staying out sets you alight.
            pyre = toPyre()
            if not pyre then return "never reached a second Hungering Pyre" end
            local flames = false
            for _ = 1, 400 do
                S.hp = 100
                -- Somewhere genuinely outside the circle, but still on
                -- the floor: parking off the platform is not a test of
                -- staying out of a soak.
                local d = math.sqrt(pyre.x * pyre.x + pyre.y * pyre.y)
                if d < 1 then
                    S.px, S.py = 0, -70
                else
                    S.px, S.py = -pyre.x / d * 72, -pyre.y / d * 72
                end
                update(f, 0.05)
                if pyre.resolved then
                    -- Checked in the SAME frame it resolves. Scanning a
                    -- few frames later races the phase: this
                    -- intermission ends when the field is clear, and
                    -- clearing the field takes the Flames with it.
                    for _, a in ipairs(S.actors) do
                        if a.name == "Slithering Flames" then flames = true end
                    end
                    break
                end
                if not S.running then break end
            end
            T:Stop()
            if not flames then return "staying out of the Pyre set nobody alight" end

            -- 3. Soaking while still marked costs more than soaking clean.
            pyre = toPyre()
            if not pyre then return "never reached a third Hungering Pyre" end
            -- Marked as of when the circle APPEARED, which is the state
            -- the mechanic captures. Setting the debuff alone would be
            -- too late: the soak reads it at cast time on purpose, so a
            -- mark that lapses mid-cast cannot change the answer under
            -- the player.
            S.debuffs["Singed"] = S.time + 30
            pyre.notMine = true
            pyre.call = nil
            local marked
            for _ = 1, 400 do
                S.hp = 100
                S.px, S.py = pyre.x, pyre.y
                local before = S.hp
                update(f, 0.05)
                if pyre.resolved then marked = before - S.hp break end
                if not S.running then break end
            end
            T:Stop()

            if not (clean and marked) then
                return "could not measure both soaks"
            end
            if marked <= clean then
                return string.format(
                    "soaking while Singed cost %.0f and soaking clean cost %.0f -- the mark is free",
                    marked, clean)
            end
            return string.format("ok:Singed applied, Flames spawned, %.0f vs %.0f damage",
                marked, clean)
        end
    """)(ns)
    if split and str(split).startswith("ok:"):
        print("  ok   trainer split soak: %s" % str(split)[3:])
    else:
        print("  FAIL trainer split soak: %s" % split)
        failures.append(("trainer split soak", str(split)))

    # Corpses, which are what the Flames are for.
    #
    # Restless Amani leave bodies, the Ritual raises every one still
    # lying there, and Slithering Flames is how they get cremated. Until
    # this existed the Flames were half a mechanic -- a debuff you
    # carried away for no reason, arriving right after you had been told
    # you played correctly, which reads as a punishment for soaking.
    #
    # Two claims: killing adds leaves bodies, and burning them is what
    # stops the Ritual raising them.
    corpses = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate

            --- Play phase one, shooting everything, and count the bodies.
            local function toIntermission(burn)
                T:Start("soulcoiler", false)
                S.countdown = 0
                local peak, raised, after, atEnd = 0, 0, 0, -1
                local mostAtOnce = 0
                for _ = 1, 4000 do
                    S.hp, S.firing = 100, true
                    if S.bossActor then
                        S.bossActor.hp = S.bossActor.maxHp * 0.5
                    end
                    if burn then
                        -- Stand on a corpse, so the Flames land on it.
                        local c = S.corpses[1]
                        if c then S.px, S.py = c.x, c.y end
                    else
                        -- Shoot the nearest add from the far side of the
                        -- room, rather than standing next to it.
                        --
                        -- Parking on top of the adds was not a control:
                        -- corpses form where adds die, so the player's
                        -- own Flames were burning them incidentally and
                        -- the "nobody burned anything" run burned
                        -- everything.
                        local near, nd
                        for _, a in ipairs(S.actors) do
                            if a.enemy and not a.dead then
                                local d = math.sqrt(a.x * a.x + a.y * a.y)
                                if not nd or d < nd then near, nd = a, d end
                            end
                        end
                        if near then
                            local d = math.sqrt(near.x * near.x + near.y * near.y)
                            if d > 1 then
                                S.px, S.py = -near.x / d * 78, -near.y / d * 78
                            end
                        end
                    end
                    update(f, 0.05)
                    if #S.corpses > peak then peak = #S.corpses end
                    local thisFrame = 0
                    for _, a in ipairs(S.actors) do
                        if a.name == "Raised Amani" and not a.counted then
                            a.counted = true
                            raised = raised + 1
                            thisFrame = thisFrame + 1
                        end
                    end
                    if thisFrame > mostAtOnce then mostAtOnce = thisFrame end
                    -- Kept running a little past the transition. The
                    -- Ritual raises the bodies as the phase ENDS, so
                    -- breaking the moment the index changes counts none
                    -- of them and reports that nothing was raised.
                    if S.phaseIndex >= 3 then
                        if after == 0 then atEnd = #S.corpses end
                        after = after + 1
                        -- Long enough for the whole queue to get up.
                        --
                        -- The bodies rise one at a time now rather than
                        -- all on one frame, so a three-second window
                        -- counted the first two and reported that
                        -- burning corpses achieves nothing.
                        if after > 500 then break end
                    end
                    if not S.running then break end
                end
                local gotTo = S.phaseIndex
                T:Stop()
                return peak, raised, atEnd, gotTo, mostAtOnce
            end

            local peak, raised, _, _, burst = toIntermission(false)
            if peak == 0 then
                return "adds died and left no corpses at all"
            end
            if raised == 0 then
                -- Measured as adds that got back up, not as corpses left
                -- on the floor: the Ritual empties the list when it
                -- fires, so counting survivors afterwards compares zero
                -- with zero and passes whatever the Flames did.
                return "corpses were never burned and the Ritual raised nobody"
            end
            -- And they must get up ONE AT A TIME.
            --
            -- Raising every un-burned body on a single frame killed the
            -- player outright the moment the Amani started arriving in
            -- packs: a dozen adds appeared together in a round that had
            -- otherwise handled 41 of 45 mechanics. A punishment nobody
            -- can react to is not a lesson.
            if burst > 2 then
                return string.format(
                    "%d bodies got up on one frame -- the raise is not staggered", burst)
            end

            local peakB, raisedB = toIntermission(true)
            if raisedB >= raised then
                return string.format(
                    "burning raised %d and ignoring them raised %d -- the Flames do nothing",
                    raisedB, raised)
            end
            return string.format("ok:%d bodies at peak, %d raised when burned against %d when not",
                peak, raisedB, raised)
        end
    """)(ns)
    if corpses and str(corpses).startswith("ok:"):
        print("  ok   trainer corpses: %s" % str(corpses)[3:])
    else:
        print("  FAIL trainer corpses: %s" % corpses)
        failures.append(("trainer corpses", str(corpses)))

    # Nymrissa's murlocs BECOME something.
    #
    # A murloc that reaches the Alluring Bubble does not merely hit you
    # and vanish -- it turns into a berserker that pulses until somebody
    # kills it. Folding that into the arrival hit would have made letting
    # one through a moment of damage rather than a problem you now have,
    # which is the opposite of what the fight is about.
    grotto = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate
            math.randomseed(2849)

            T:Start("nymrissa", false)
            S.countdown = 0
            local sawMurloc, berserkers, whirlAtRim = false, 0, nil
            for _ = 1, 2600 do
                -- Never shoot and stand at the wall, so every murloc
                -- gets through and every orb is left to shatter.
                S.hp, S.firing = 100, false
                S.px, S.py = 0, -88
                if S.bossActor then S.bossActor.hp = S.bossActor.maxHp end
                update(f, 0.05)
                for _, a in ipairs(S.actors) do
                    if a.name == "Murloc" then sawMurloc = true end
                    if a.name == "Berserker" and not a.counted then
                        a.counted = true
                        berserkers = berserkers + 1
                    end
                    -- The whirlpools' safe ground is shoreline.
                    if a.kind == "refuge" and a.spots and a.spots[1] and not whirlAtRim then
                        local d = math.sqrt(a.spots[1].x ^ 2 + a.spots[1].y ^ 2)
                        whirlAtRim = d
                    end
                end
                if not S.running then break end
            end
            T:Stop()

            if not sawMurloc then return "no murlocs ever spawned" end
            if berserkers == 0 then
                return "murlocs reached the bubble and no Berserker appeared"
            end
            if not whirlAtRim then return "the whirlpools never cast" end
            if whirlAtRim < 60 then
                return string.format(
                    "the whirlpools' safe ground sat %.0f from the middle,"
                    .. " which is open floor rather than shoreline", whirlAtRim)
            end
            return string.format("ok:%d berserkers from murlocs that got through;"
                .. " safe shore %.0f out", berserkers, whirlAtRim)
        end
    """)(ns)
    if grotto and str(grotto).startswith("ok:"):
        print("  ok   trainer grotto: %s" % str(grotto)[3:])
    else:
        print("  FAIL trainer grotto: %s" % grotto)
        failures.append(("trainer grotto", str(grotto)))

    # More than one instance in the rail.
    #
    # The guide covers the raid and the Lair, and they have to stay
    # separated: the Grotto's single boss is "1", and so is Nek'zali.
    # Ordered() must group them, and the Lair must not be claiming to be
    # part of the raid.
    inst = L.eval("""
        function(ns)
            local G = ns.RaidGuide
            if not (G and G.instances) then return "no instances declared" end
            local ordered = G:Ordered()
            if #ordered < 2 then return "fewer than two bosses" end

            -- Grouped: an instance never reappears after another starts.
            local seen, order, last = {}, {}, nil
            for _, b in ipairs(ordered) do
                local key = G:InstanceOf(b).key
                if key ~= last then
                    if seen[key] then
                        return "instance " .. key .. " appears in two separate blocks"
                    end
                    seen[key] = true
                    order[#order + 1] = key
                    last = key
                end
            end
            if #order < 2 then
                return "every boss resolved to one instance (" .. (order[1] or "?") .. ")"
            end
            if order[1] ~= "va" then
                return "the raid is not first in the rail"
            end

            -- A boss written up but not yet playable is a real state, and
            -- the trainer must not offer a button for it.
            local guideOnly = 0
            for _, b in ipairs(ordered) do
                if b.guideOnly then
                    guideOnly = guideOnly + 1
                    if ns.RaidTrainer:HasScenario(b.id) then
                        return b.id .. " is marked guideOnly but has a scenario"
                    end
                end
            end
            return string.format("ok:%d instances, %d bosses, %d guide-only",
                #order, #ordered, guideOnly)
        end
    """)(ns)
    if inst and str(inst).startswith("ok:"):
        print("  ok   guide instances: %s" % str(inst)[3:])
    else:
        print("  FAIL guide instances: %s" % inst)
        failures.append(("guide instances", str(inst)))

    # A garbage budget for the trainer's frame.
    #
    # The trainer is the only thing in this addon with a permanent
    # OnUpdate, so it is the only thing that can make the game stutter.
    # What does that is not CPU -- it is ALLOCATION: Lua collects when
    # allocation crosses a threshold, so a loop that allocates every
    # frame does not cost a little all the time, it buys a pause,
    # periodically, forever.
    #
    # This caught a real one. `repel` was a closure declared inside
    # DangerPush, which runs per ally per frame, so the loop was building
    # a few hundred function objects a second for a helper whose body
    # never changes. Hoisting it cut the frame's garbage by about 44%.
    #
    # The stub's own SetPoint is swapped out while measuring, because it
    # records every anchor for the layout checks -- two tables per call,
    # on every sprite, every frame. Left in, it dwarfs the addon and the
    # number means nothing. In the client these are C functions that
    # allocate no Lua garbage at all.
    BUDGET = 5000
    perf = L.eval("""
        function(ns, budget)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate
            local mt = getmetatable(UIParent)
            local realPoint, realClear = mt.SetPoint, mt.ClearAllPoints
            local noop = function(self) return self end
            rawset(mt, "SetPoint", noop)
            rawset(mt, "ClearAllPoints", noop)

            local worst, worstBoss = 0, "?"
            for _, boss in ipairs(ns.RaidGuide:Ordered()) do
                if ns.RaidTrainerScenarios[boss.id] then
                    T:Start(boss.id, false)
                    S.countdown = 0
                    -- Warm up, so one-off pool and font-string setup is
                    -- not charged to the steady-state frame.
                    for _ = 1, 120 do S.hp, S.firing = 100, true; update(f, 0.016) end
                    collectgarbage('collect')
                    local before = collectgarbage('count')
                    for _ = 1, 400 do S.hp, S.firing = 100, true; update(f, 0.016) end
                    local per = (collectgarbage('count') - before) * 1024 / 400
                    T:Stop()
                    if per > worst then worst, worstBoss = per, boss.id end
                end
            end

            rawset(mt, "SetPoint", realPoint)
            rawset(mt, "ClearAllPoints", realClear)
            if worst > budget then
                return string.format("%s allocates %.0f bytes a frame, over the %d budget",
                    worstBoss, worst, budget)
            end
            return string.format("ok:worst frame %.0f bytes (%s), budget %d",
                worst, worstBoss, budget)
        end
    """)(ns, BUDGET)
    if perf and str(perf).startswith("ok:"):
        print("  ok   trainer garbage: %s" % str(perf)[3:])
    else:
        print("  FAIL trainer garbage: %s" % perf)
        failures.append(("trainer garbage", str(perf)))

    # Permanent textures must come BACK.
    #
    # A whole class of bug lived here: every long-lived texture in the
    # trainer is drawn by one branch and hidden by another, and `put`
    # did not Show. So anything hidden once stayed hidden for the rest
    # of the session however many times it was drawn again -- and the
    # Entombed Sentinels lost their second boss to it, because every
    # single-boss fight hides bossSkull[2]. Health bar, name on the
    # floor, working collision, no skull.
    #
    # Invisible to every other check in this file, because they all
    # reason about state rather than about pixels.
    reshow = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate
            if not T._bossSkull then return "the trainer exposes no boss skulls" end

            -- A one-boss fight first, which is what hides the second.
            T:Start("soulcoiler", false)
            S.countdown = 0
            for _ = 1, 40 do S.hp = 100; update(f, 0.05) end
            if T._bossSkull[2]:IsShown() then
                T:Stop()
                return "a one-boss fight left the second skull shown"
            end
            T:Stop()

            -- Then a two-boss fight, which must bring it back.
            T:Start("sentinels", false)
            S.countdown = 0
            for _ = 1, 40 do S.hp = 100; update(f, 0.05) end
            local one, two = T._bossSkull[1]:IsShown(), T._bossSkull[2]:IsShown()
            T:Stop()
            if not one or not two then
                return string.format(
                    "after a one-boss fight the Sentinels drew skull1=%s skull2=%s",
                    tostring(one), tostring(two))
            end
            return "ok:both skulls return after a one-boss fight"
        end
    """)(ns)
    if reshow and str(reshow).startswith("ok:"):
        print("  ok   trainer redraw: %s" % str(reshow)[3:])
    else:
        print("  FAIL trainer redraw: %s" % reshow)
        failures.append(("trainer redraw", str(reshow)))

    # The raid SPLITS on a two-boss fight, and stays split.
    #
    # Every ally used to hold formation on S.bossActor, which is the
    # PLAYER's boss -- so the whole raid moved to whichever golem you
    # were standing on and the far one was left alone. That is the exact
    # thing the Sentinels forbid.
    split = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate
            math.randomseed(3445)

            local function census()
                local near = { 0, 0 }
                for _, a in ipairs(S.allies) do
                    local best, bd
                    for i, b in ipairs(S.bossActors) do
                        local d = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
                        if not bd or d < bd then best, bd = i, d end
                    end
                    if best then near[best] = near[best] + 1 end
                end
                return near[1], near[2]
            end

            T:Start("sentinels", false)
            S.countdown = 0
            -- Sit on ONE golem the whole time. If the raid follows the
            -- player, everybody ends up on that side.
            local sideOne, sideTwo
            for _ = 1, 600 do
                S.hp, S.firing = 100, false
                S.px, S.py = S.bossActors[1].x, S.bossActors[1].y
                for _, b in ipairs(S.bossActors) do b.hp = b.maxHp end
                update(f, 0.05)
            end
            sideOne, sideTwo = census()
            local phaseAt = S.phaseIndex
            T:Stop()

            if sideOne == 0 or sideTwo == 0 then
                return string.format(
                    "the raid piled %d/%d onto the two golems -- it is not split",
                    sideOne, sideTwo)
            end
            -- Each ally keeps the side it was given, MOST of the time.
            --
            -- Sampled across the round rather than snapshotted at the
            -- end: a whole-raid soak or a stack legitimately pulls
            -- everybody across the room for a few seconds, and catching
            -- one of those moments says nothing about where the raid
            -- lives. What matters is that they go back.
            local onSide, samples = 0, 0
            T:Start("sentinels", false)
            S.countdown = 0
            for _ = 1, 600 do
                S.hp, S.firing = 100, false
                S.px, S.py = 0, -80
                for _, b in ipairs(S.bossActors) do b.hp = b.maxHp end
                update(f, 0.05)
                -- Not during Vitriolic Stasis. The pairing sends the raid
                -- to spots that have nothing to do with either golem --
                -- that IS the mechanic -- so counting those frames
                -- measures the number game and calls it drift. Two
                -- stasis phases in a round is a fifth of it.
                local pairing = false
                for _, a in ipairs(S.allies) do
                    if a.meetSpot then pairing = true break end
                end
                if not pairing then
                    for _, a in ipairs(S.allies) do
                        local own, other = S.bossActors[a.side], S.bossActors[3 - a.side]
                        if own and other then
                            samples = samples + 1
                            local dOwn = math.sqrt((a.x - own.x) ^ 2 + (a.y - own.y) ^ 2)
                            local dOther = math.sqrt((a.x - other.x) ^ 2 + (a.y - other.y) ^ 2)
                            if dOwn <= dOther then onSide = onSide + 1 end
                        end
                    end
                end
            end
            T:Stop()
            -- And a mechanic on one golem's side is only handled by
            -- that side. The far half used to abandon its golem every
            -- time a circle landed on yours, take a mechanic that was
            -- never theirs, and walk back.
            local crossed = 0
            T:Start("sentinels", false)
            S.countdown = 0
            for _ = 1, 900 do
                S.hp, S.firing = 100, false
                S.px, S.py = 0, -80
                for _, b in ipairs(S.bossActors) do b.hp = b.maxHp end
                update(f, 0.05)
                for _, a in ipairs(S.allies) do
                    local g = a.goalSoak
                    if g then
                        local own = S.bossActors[a.side]
                        local other = S.bossActors[3 - a.side]
                        local dOwn = math.sqrt((g.x - own.x) ^ 2 + (g.y - own.y) ^ 2)
                        local dOther = math.sqrt((g.x - other.x) ^ 2 + (g.y - other.y) ^ 2)
                        if dOther < dOwn then crossed = crossed + 1 end
                    end
                end
            end
            T:Stop()
            if crossed > 0 then
                return string.format(
                    "allies took a mechanic on the other golem's side %d times", crossed)
            end

            local held = samples > 0 and (onSide / samples) or 0
            if held < 0.75 then
                return string.format(
                    "allies were on their own golem only %.0f%% of the time", held * 100)
            end
            return string.format("ok:%d/%d across the two golems, on-side %.0f%%, no cross-side mechanics (phase %d)",
                sideOne, sideTwo, held * 100, phaseAt)
        end
    """)(ns)
    if split and str(split).startswith("ok:"):
        print("  ok   trainer raid split: %s" % str(split)[3:])
    else:
        print("  FAIL trainer raid split: %s" % split)
        failures.append(("trainer raid split", str(split)))

    # The Sentinels' number game has to be PLAYABLE.
    #
    # It was not. The raid held station in a heap under the boss with
    # their numbers drawn on top of each other, nobody paired with
    # anybody, and reaching the correct partner produced no visible
    # result until the cast ended. Every one of those is checkable.
    stasis = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate
            local problems = {}
            math.randomseed(3445)

            T:Start("sentinels", false)
            S.countdown = 0
            local meet
            for _ = 1, 1400 do
                S.hp, S.firing = 100, false
                S.px, S.py = 0, -80
                for _, b in ipairs(S.bossActors) do b.hp = b.maxHp end
                update(f, 0.05)
                for _, a in ipairs(S.actors) do
                    if a.kind == "meet" then meet = a end
                end
                if meet then break end
                if not S.running then break end
            end
            if not meet then T:Stop(); return "Vitriolic Stasis never cast" end

            -- You are 1 and your partner is 3, every time.
            if meet.mine ~= 1 or meet.target.label ~= "3" then
                problems[#problems + 1] = string.format(
                    "you were %s and your partner %s, not 1 and 3",
                    tostring(meet.mine), tostring(meet.target.label))
            end

            -- Let them walk to their spots.
            for _ = 1, 90 do
                S.hp, S.firing = 100, false
                S.px, S.py = 0, -80
                for _, b in ipairs(S.bossActors) do b.hp = b.maxHp end
                update(f, 0.05)
            end

            -- The partner waits in the MIDDLE.
            local pd = math.sqrt(meet.target.x ^ 2 + meet.target.y ^ 2)
            if pd > 18 then
                problems[#problems + 1] = string.format(
                    "your partner ended %.0f from the middle instead of waiting there", pd)
            end

            -- And nobody is piled under a boss any more.
            local underBoss = 0
            for _, ally in ipairs(S.allies) do
                for _, b in ipairs(S.bossActors) do
                    if math.sqrt((ally.x - b.x) ^ 2 + (ally.y - b.y) ^ 2) < 22 then
                        underBoss = underBoss + 1
                    end
                end
            end
            if underBoss > 1 then
                problems[#problems + 1] = string.format(
                    "%d allies were still stacked on a boss during the pairing", underBoss)
            end

            -- Everyone else is standing WITH somebody, adding to four.
            local paired = 0
            for _, ally in ipairs(S.allies) do
                if ally ~= meet.target and ally.label then
                    for _, other in ipairs(S.allies) do
                        if other ~= ally and other.label
                            and math.sqrt((ally.x - other.x) ^ 2 + (ally.y - other.y) ^ 2) < 22
                            and (tonumber(ally.label) + tonumber(other.label)) == 4 then
                            paired = paired + 1
                            break
                        end
                    end
                end
            end
            if paired < 4 then
                problems[#problems + 1] = string.format(
                    "only %d allies found a partner adding to four", paired)
            end

            -- And reaching the partner is worth something, IMMEDIATELY.
            --
            -- It used to wait out the whole ten-second cast even once
            -- you were standing on the right person, so the correct play
            -- was followed by eight seconds of nothing and then a
            -- verdict -- which reads as the game not having noticed.
            local before = S.passed
            local waited = 0
            for _ = 1, 400 do
                S.hp, S.firing = 100, false
                S.px, S.py = meet.target.x, meet.target.y
                for _, b in ipairs(S.bossActors) do b.hp = b.maxHp end
                update(f, 0.05)
                waited = waited + 0.05
                if S.passed > before then break end
                if meet.dead or S.phaseIndex > 2 then break end
                if not S.running then break end
            end
            local credited = S.passed > before
            T:Stop()
            if not credited then
                problems[#problems + 1] =
                    "standing on the correct partner scored nothing"
            elseif waited > 1.0 then
                problems[#problems + 1] = string.format(
                    "combining took %.1fs to register -- it should be on contact", waited)
            end

            if #problems > 0 then return table.concat(problems, "; ") end
            return string.format(
                "ok:you are 1 and your partner 3 waiting in the middle;"
                .. " %d others paired to four, none stacked on a boss", paired)
        end
    """)(ns)
    if stasis and str(stasis).startswith("ok:"):
        print("  ok   trainer stasis: %s" % str(stasis)[3:])
    else:
        print("  FAIL trainer stasis: %s" % stasis)
        failures.append(("trainer stasis", str(stasis)))

    # Possession Barrage is ONE lane.
    #
    # It was built as a fan of four separate lines, which turns "keep
    # this lane clear" -- something the raid does once -- into four
    # dodges, and doubles the floor the mechanic covers. Reported from
    # watching the fight.
    lane = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate
            math.randomseed(3470)

            T:Start("soulcoiler", false)
            S.countdown = 0
            local mostAtOnce, spread = 0, 0
            for _ = 1, 1200 do
                S.hp, S.firing = 100, false
                S.px, S.py = 0, -86
                if S.bossActor then S.bossActor.hp = S.bossActor.maxHp end
                update(f, 0.05)
                local dirs, n = {}, 0
                for _, a in ipairs(S.actors) do
                    if a.name == "Possession Barrage" and not a.dead and a.dir then
                        n = n + 1
                        dirs[#dirs + 1] = a.dir
                    end
                end
                if n > mostAtOnce then mostAtOnce = n end
                -- How far apart the live spirits' headings are.
                if n >= 2 then
                    local lo, hi = dirs[1], dirs[1]
                    for _, d in ipairs(dirs) do
                        if d < lo then lo = d end
                        if d > hi then hi = d end
                    end
                    if (hi - lo) > spread then spread = hi - lo end
                end
                if not S.running then break end
            end
            T:Stop()

            if mostAtOnce < 2 then
                return "never saw two spirits in the air at once, so nothing was tested"
            end
            -- The fan was 0.6 radians corner to corner. One lane is zero.
            if spread > 0.02 then
                return string.format(
                    "%d spirits in the air and their headings differ by %.2f rad"
                    .. " -- that is a fan, not a lane", mostAtOnce, spread)
            end
            return string.format("ok:%d spirits share one heading", mostAtOnce)
        end
    """)(ns)
    if lane and str(lane).startswith("ok:"):
        print("  ok   trainer barrage: %s" % str(lane)[3:])
    else:
        print("  FAIL trainer barrage: %s" % lane)
        failures.append(("trainer barrage", str(lane)))

    # Two bosses.
    #
    # Both of these fights are built on a rule about the RELATIONSHIP
    # between two health bars, and each rule is worth failing on
    # separately -- a second skull on the floor that nothing consults is
    # decoration, which is exactly what the first version of the raid AI
    # was before it got its own check.
    two = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate
            local problems = {}

            -- Both fights declare two, and both are shootable.
            for _, id in ipairs({ "sentinels", "twinfangs" }) do
                T:Start(id, false)
                S.countdown = 0
                if #S.bossActors ~= 2 then
                    problems[#problems + 1] = id .. " built " ..
                        #S.bossActors .. " bosses, not 2"
                else
                    -- Shoot each in turn from point-blank and check the
                    -- bar that moves is the one aimed at.
                    for i = 1, 2 do
                        local b = S.bossActors[i]
                        local other = S.bossActors[3 - i]
                        local hpBefore, otherBefore = b.hp, other.hp
                        -- Stand OUTSIDE the boss, on the line from the
                        -- arena centre through it.
                        --
                        -- The harness pins the cursor at the centre, so
                        -- the trainer recomputes aim from it every frame
                        -- and whatever S.aim is set to here is discarded.
                        -- Standing beside a boss and setting aim by hand
                        -- fired at the middle of the room instead, which
                        -- happened to cross Vexil and happened to miss
                        -- Itras -- so one of the two "took no damage".
                        local d = math.sqrt(b.x * b.x + b.y * b.y)
                        local ox, oy = b.x / d, b.y / d
                        for _ = 1, 40 do
                            -- Kept alive and unstacked, or the Twin
                            -- Fangs' poison meter ends the round during
                            -- the first boss and the second is never
                            -- shot at all -- which reads exactly like a
                            -- boss that cannot be damaged.
                            S.hp, S.stacks = 100, 0
                            S.px, S.py = b.x + ox * 22, b.y + oy * 22
                            S.firing = true
                            -- The raid has to be silenced explicitly or
                            -- this measures six allies picking their own
                            -- targets rather than where the player is
                            -- pointing -- and with two bosses on the
                            -- floor they cheerfully shoot the other one.
                            for _, ally in ipairs(S.allies) do ally.stagger = 999 end
                            update(f, 0.05)
                        end
                        if b.hp >= hpBefore then
                            problems[#problems + 1] = string.format(
                                "%s: %s took no damage when shot", id, b.name)
                        end
                        -- The Sentinels' off-team damages the other one
                        -- on purpose, so this only has to hold where
                        -- there is no off-team.
                        if not S.scenario.otherTeam and other.hp < otherBefore then
                            problems[#problems + 1] = string.format(
                                "%s: shooting %s also damaged %s", id, b.name, other.name)
                        end
                    end
                end
                T:Stop()
            end

            -- Vitriolic Stasis refunds the gap, and refunds nothing when
            -- the bars are level.
            --
            -- Driven by pushing the phase over, not by filling the energy
            -- bar: the stasis is a PHASE, and the number game and the
            -- healing are one event inside it. Setting the bar to full
            -- used to trigger the heal on its own, which fired it twice
            -- a cycle in the middle of a golem phase.
            local function stasisFrom(loFrac, hiFrac)
                math.randomseed(3445)
                T:Start("sentinels", false)
                S.countdown = 0
                local a, b = S.bossActors[1], S.bossActors[2]
                a.hp, b.hp = a.maxHp * loFrac, b.maxHp * hiFrac
                -- Run the opening phase out so the stasis begins, and
                -- take the miss count across the TRANSITION FRAME only.
                --
                -- Totalling the phase measured ninety seconds of
                -- droplets and miasma, which came out identical for both
                -- pairs and said nothing about the heal.
                local missed = 0
                for _ = 1, 900 do
                    S.hp, S.firing = 100, false
                    -- Silenced, or six allies shooting drag both bars
                    -- to the phase floor and there is no gap left to
                    -- measure.
                    for _, ally in ipairs(S.allies) do ally.stagger = 999 end
                    a.hp = math.min(a.hp, a.maxHp * loFrac)
                    b.hp = math.min(b.hp, b.maxHp * hiFrac)
                    local before = S.failed
                    update(f, 0.05)
                    if S.phaseIndex >= 2 then
                        missed = S.failed - before
                        break
                    end
                end
                local healed = a.hp / a.maxHp
                local reached = S.phaseIndex
                T:Stop()
                return healed, missed, reached
            end

            local healed, gapMissed, reached = stasisFrom(0.40, 0.90)
            if reached < 2 then
                problems[#problems + 1] = "the Sentinels never reached Vitriolic Stasis"
            elseif healed <= 0.41 then
                problems[#problems + 1] = string.format(
                    "Vitriolic Stasis left the weaker boss at %.0f%% -- it never healed",
                    healed * 100)
            end
            -- And level bars cost nothing: no miss is scored for the heal.
            local levelHealed, levelMissed = stasisFrom(0.50, 0.50)
            if levelMissed >= gapMissed then
                problems[#problems + 1] = string.format(
                    "a level pair was charged %d misses against %d for a wide gap"
                    .. " (healed to %.0f%% vs %.0f%%)",
                    levelMissed, gapMissed, levelHealed * 100, healed * 100)
            end

            -- Both dots: only in the middle, never on a side.
            --
            -- Summed frame by frame rather than read off the health bar
            -- at the end. Every other mechanic on the fight is also
            -- landing during these windows, so a single before/after
            -- reading measures the round, not the rule; resetting to full
            -- each frame and adding up what was taken isolates it.
            local function costAt(px, py)
                local total = 0
                for _ = 1, 60 do
                    S.hp = 100
                    S.px, S.py = px, py
                    -- Held still: the raid AI does not move the player,
                    -- but a live round pushes them off a mark otherwise.
                    update(f, 0.05)
                    total = total + (100 - S.hp)
                end
                return total
            end
            T:Start("sentinels", false)
            S.countdown = 0
            local onSide = costAt(S.bossActors[1].x, S.bossActors[1].y)
            local mid = costAt(0, 10)
            T:Stop()
            -- A real margin, not a hair. Both windows take incidental
            -- damage from everything else on the floor, so "slightly
            -- more" would pass on noise alone.
            if mid < onSide * 1.5 + 5 then
                problems[#problems + 1] = string.format(
                    "standing between both golems cost %.1f against %.1f on a side",
                    mid, onSide)
            end

            -- The kill-together enrage: only after one dies, never while
            -- both live.
            --
            -- Checked on the COILED ALTAR, which is the boss whose guide
            -- states it. It was recorded on the Twin Fangs from a source
            -- that did not survive, and the Fangs only ask to be cleaved
            -- down together -- which two bars already say.
            T:Start("alteredfangs", false)
            S.countdown = 0
            S.hp = 100
            for _ = 1, 20 do S.hp = 100; update(f, 0.05) end
            local bothAlive = S.rot
            S.bossActors[2].hp = 0
            for _ = 1, 60 do S.hp = 100; update(f, 0.05) end
            local rotting = S.rot
            T:Stop()
            if bothAlive ~= nil then
                problems[#problems + 1] = "the enrage ran while both bosses were alive"
            end
            if not rotting or rotting <= 0 then
                problems[#problems + 1] = "killing one boss first started no enrage"
            end

            if #problems > 0 then return table.concat(problems, "; ") end
            return string.format("ok:two bars each take their own fire; stasis refunds the gap;"
                .. " the middle costs %.1f against %.1f on a side;"
                .. " rot runs %.1fs after a first kill", mid, onSide, rotting)
        end
    """)(ns)
    if two and str(two).startswith("ok:"):
        print("  ok   trainer two bosses: %s" % str(two)[3:])
    else:
        print("  FAIL trainer two bosses: %s" % two)
        failures.append(("trainer two bosses", str(two)))

    # Vashnik's pool.
    #
    # "Every add walks for the green pool in the middle" is the boss's
    # headline rule, and the scenario expressed none of it -- the adds
    # Imbibe spawned chased the PLAYER. Two claims worth failing on: they
    # walk to the middle, and getting there feeds the bar. Plus the
    # leech, whose whole point is that standing near one straggler is not
    # the same as standing in a camp.
    vash = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate
            local problems = {}
            math.randomseed(4550)

            -- Run the fight with the player parked far from the middle
            -- and never shooting. Adds that walk at the PLAYER would
            -- close on them; adds that walk at the pool close on it.
            T:Start("vashnik", false)
            S.countdown = 0
            local sawAdd, closedOnPool, closedOnPlayer = false, 0, 0
            local fed = 0
            for _ = 1, 900 do
                S.hp, S.firing = 100, false
                S.px, S.py = 0, -86
                if S.bossActor then S.bossActor.hp = S.bossActor.maxHp end
                local before = S.energy
                update(f, 0.05)
                if S.energy > before then fed = fed + (S.energy - before) end
                for _, a in ipairs(S.actors) do
                    if a.kind == "chaser" and a.enemy and not a.dead then
                        sawAdd = true
                        local dPool = math.sqrt(a.x * a.x + a.y * a.y)
                        local dYou = math.sqrt((a.x - S.px) ^ 2 + (a.y - S.py) ^ 2)
                        if a.lastPool and dPool < a.lastPool - 0.001 then
                            closedOnPool = closedOnPool + 1
                        end
                        if a.lastYou and dYou < a.lastYou - 0.001 then
                            closedOnPlayer = closedOnPlayer + 1
                        end
                        a.lastPool, a.lastYou = dPool, dYou
                    end
                end
                if S.energy >= 99 then break end
                if not S.running then break end
            end
            T:Stop()

            if not sawAdd then
                problems[#problems + 1] = "Imbibe spawned no adds at all"
            elseif closedOnPool <= closedOnPlayer then
                problems[#problems + 1] = string.format(
                    "adds closed on the player %d frames against %d on the pool",
                    closedOnPlayer, closedOnPool)
            end
            if fed <= 0 then
                problems[#problems + 1] =
                    "adds reached the pool and Toxic Vapor never moved"
            end

            -- The leech: inside a camp clears it, next to nobody does not.
            local function leechAt(where)
                T:Start("vashnik", false)
                S.countdown = 0
                local passed, missed = 0, 0
                for _ = 1, 1400 do
                    S.hp, S.firing, S.energy = 100, false, 0
                    if S.bossActor then S.bossActor.hp = S.bossActor.maxHp end
                    if where == "camp" then
                        -- Stand on the biggest cluster of allies.
                        local bx, by, best = 0, 0, -1
                        for _, c in ipairs(S.allies) do
                            local n = 0
                            for _, o in ipairs(S.allies) do
                                local d = math.sqrt((c.x - o.x) ^ 2 + (c.y - o.y) ^ 2)
                                if d <= 14 then n = n + 1 end
                            end
                            if n > best then bx, by, best = c.x, c.y, n end
                        end
                        S.px, S.py = bx, by
                    else
                        S.px, S.py = 0, -92
                    end
                    -- Attributed to the LEECH, not to the round.
                    --
                    -- Counting every credit the frame handed out would
                    -- compare two positions on a floor full of other
                    -- mechanics -- the camp is also where the raid is
                    -- dodging well -- so the contrast would look right
                    -- for reasons that have nothing to do with this
                    -- verb. A leech that vanished during an update
                    -- resolved during it, and that frame's delta is its
                    -- own.
                    local live = {}
                    for _, a in ipairs(S.actors) do
                        if a.kind == "leech" then live[a] = true end
                    end
                    local p, m = S.passed, S.failed
                    update(f, 0.05)
                    local stillHere = {}
                    for _, a in ipairs(S.actors) do
                        if a.kind == "leech" then stillHere[a] = true end
                    end
                    local resolved = false
                    for a in pairs(live) do
                        if not stillHere[a] then resolved = true end
                    end
                    if resolved then
                        passed = passed + (S.passed - p)
                        missed = missed + (S.failed - m)
                    end
                    if not S.running then break end
                end
                T:Stop()
                return passed, missed
            end
            local campPass, campMiss = leechAt("camp")
            local alonePass, aloneMiss = leechAt("alone")
            if campPass + campMiss == 0 then
                problems[#problems + 1] = "no Siphoning Infection ever resolved"
            end
            if campPass <= alonePass or aloneMiss <= campMiss then
                problems[#problems + 1] = string.format(
                    "Siphoning Infection: in a camp %d handled / %d missed;"
                    .. " alone at the wall %d handled / %d missed",
                    campPass, campMiss, alonePass, aloneMiss)
            end

            if #problems > 0 then return table.concat(problems, "; ") end
            return string.format(
                "ok:adds walk at the pool (%d frames closing on it against %d on the player),"
                .. " leaks fed %.0f vapor; Siphoning cleared %d/%d in a camp"
                .. " against %d/%d at the wall",
                closedOnPool, closedOnPlayer, fed,
                campPass, campPass + campMiss, alonePass, alonePass + aloneMiss)
        end
    """)(ns)
    if vash and str(vash).startswith("ok:"):
        print("  ok   trainer vashnik: %s" % str(vash)[3:])
    else:
        print("  FAIL trainer vashnik: %s" % vash)
        failures.append(("trainer vashnik", str(vash)))

    # Frostfire Volley's pairing.
    #
    # The one mechanic in the trainer whose answer is a distance from the
    # RIGHT thing rather than from a thing, so all three halves are worth
    # asserting separately: the opposite puddle clears you, your own does
    # not, and taking a second element while carrying the first is the
    # explosion the guide is frightened of.
    volley = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate
            local problems = {}
            math.randomseed(3497)

            --- Run the Iku phase until the player is carrying an element,
            --- then hand control back.
            local function untilCarrying()
                T:Start("explorers", false)
                S.countdown = 0
                -- Straight to the empowered phase; the volley lives there.
                for _ = 1, 4000 do
                    S.hp, S.firing = 100, false
                    S.px, S.py = 0, -88
                    if S.bossActor then S.bossActor.hp = S.bossActor.maxHp end
                    S.energy = 0
                    update(f, 0.05)
                    if S.element then return true end
                    if not S.running then break end
                end
                return false
            end

            if not untilCarrying() then
                T:Stop()
                return "Frostfire Volley never handed the player an element"
            end

            --- Walk onto the nearest cleanse puddle of a given school and
            --- see whether the debuff survives.
            local function stepOnto(school)
                local best, bd
                for _, a in ipairs(S.actors) do
                    if a.kind == "cleanse" and a.school == school and not a.dead then
                        local d = math.sqrt(a.x * a.x + a.y * a.y)
                        if not bd or d < bd then best, bd = a, d end
                    end
                end
                if not best then return nil end
                for _ = 1, 20 do
                    S.hp, S.firing = 100, false
                    S.energy = 0
                    S.px, S.py = best.x, best.y
                    update(f, 0.05)
                end
                return S.element == nil
            end

            local mine = S.element.school
            local opp = (mine == "fire") and "frost" or "fire"

            -- Your own element does nothing.
            --
            -- The nil case is a failure, not a pass: if the volley left
            -- no puddle of your own element there was nothing to stand
            -- in, and "it did not clear you" would be true of an empty
            -- floor. Half this check is that BOTH kinds are on the
            -- ground and only one of them works.
            local clearedBySame = stepOnto(mine)
            if clearedBySame == nil then
                problems[#problems + 1] =
                    "the volley left no puddle of your own element to test against"
            elseif clearedBySame == true then
                problems[#problems + 1] =
                    "standing in your OWN element cleared the debuff"
            end
            -- The opposite one clears it.
            local clearedByOpp = stepOnto(opp)
            if clearedByOpp == nil then
                problems[#problems + 1] =
                    "the volley left no puddle of the opposite element to use"
            elseif clearedByOpp == false then
                problems[#problems + 1] =
                    "standing in the OPPOSITE element did not clear the debuff"
            end
            T:Stop()

            -- And the half that matters: CLEARING is what explodes.
            --
            -- Two runs of the same seeded phase. One clears the instant
            -- it can; one waits for the window to go cold. The eager
            -- player has to come off worse, because "clear it early,
            -- every time" is the instinct this fight punishes and the
            -- one the first version of this mechanic taught.
            --- `during` true clears only while the HOLD warning is up;
            --- false clears only once it has gone cold.
            ---
            --- Testing "clears as soon as possible" against "waits"
            --- proved nothing: the player who steps straight onto a patch
            --- clears BEFORE any ally has started, which is genuinely
            --- safe and should be. What the rule actually says is that
            --- the warning means something, so the two runs have to
            --- differ on the warning and nothing else.
            local function clearingRun(during)
                math.randomseed(3497)
                T:Start("explorers", false)
                S.countdown = 0
                local exploded, clean = 0, 0
                for _ = 1, 4000 do
                    S.firing, S.hp, S.energy = false, 100, 0
                    if S.bossActor then S.bossActor.hp = S.bossActor.maxHp end
                    local hot = S.lastClear
                        and (S.time - S.lastClear) < 3.0 or false
                    if S.element and hot == during then
                        -- Walk onto the nearest opposite-element patch.
                        local want = (S.element.school == "fire") and "frost" or "fire"
                        local best, bd
                        for _, a in ipairs(S.actors) do
                            if a.kind == "cleanse" and a.school == want and not a.dead then
                                local d = math.sqrt((a.x - S.px) ^ 2 + (a.y - S.py) ^ 2)
                                if not bd or d < bd then best, bd = a, d end
                            end
                        end
                        if best then S.px, S.py = best.x, best.y end
                    else
                        S.px, S.py = 0, -88
                    end
                    local p, m = S.passed, S.failed
                    local had = S.element ~= nil
                    update(f, 0.05)
                    if had and not S.element then
                        -- Resolved this frame, one way or the other.
                        if S.failed > m then exploded = exploded + 1 end
                        if S.passed > p then clean = clean + 1 end
                    end
                    if not S.running then break end
                end
                T:Stop()
                return exploded, clean
            end

            local hotBoom, hotOk = clearingRun(true)
            local coldBoom, coldOk = clearingRun(false)
            if hotBoom + hotOk == 0 then
                problems[#problems + 1] =
                    "never managed to clear during a HOLD window, so nothing was tested"
            end
            if coldBoom + coldOk == 0 then
                problems[#problems + 1] = "no Frostfire debuff ever cleared cleanly"
            end
            if hotBoom <= coldBoom then
                problems[#problems + 1] = string.format(
                    "clearing during the HOLD window exploded %d times and clearing"
                    .. " after it exploded %d -- the stagger is doing nothing",
                    hotBoom, coldBoom)
            end

            if #problems > 0 then return table.concat(problems, "; ") end
            return string.format(
                "ok:opposite patch clears and your own does not;"
                .. " clearing during the HOLD window exploded %d times against %d after it",
                hotBoom, coldBoom)
        end
    """)(ns)
    if volley and str(volley).startswith("ok:"):
        print("  ok   trainer frostfire: %s" % str(volley)[3:])
    else:
        print("  FAIL trainer frostfire: %s" % volley)
        failures.append(("trainer frostfire", str(volley)))

    # Alternating soaks.
    #
    # Sszorak's Mutilate and the Twin Fangs' Ravenous Feast both leave a
    # debuff that makes the NEXT one lethal, and both were plain soaks --
    # so standing in every circle scored perfectly, and on Ravenous Feast
    # it also cleared six stacks, which made the most dangerous play in
    # the fight the highest-scoring one.
    #
    # The check drives two players through the same rounds: one who soaks
    # everything, one who sits out whatever they are marked for. The
    # second has to come out ahead, or the mark is decoration.
    alt = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate
            local problems = {}

            local function run(id, mark, obeyMark)
                math.randomseed(3421)
                T:Start(id, false)
                S.countdown = 0
                local soaked, satOut = 0, 0
                local passed, failed = 0, 0
                for _ = 1, 2400 do
                    S.firing = false
                    -- Health and the poison meter both pinned: the
                    -- subject here is the mark, and a Twin Fangs driver
                    -- that never shoots hits eleven stacks in phase one
                    -- and dies before Ravenous Feast exists -- which
                    -- reported nought against nought and passed nothing.
                    S.hp, S.stacks = 100, 0
                    if S.bossActor then S.bossActor.hp = S.bossActor.maxHp end
                    for _, bi in ipairs(S.bossActors) do bi.hp = bi.maxHp end
                    -- The nearest soak circle that is currently casting.
                    -- Split soaks, whatever SHAPE they are.
                    --
                    -- Mutilate became a cone you stand in rather than a
                    -- circle, because the two frontals pointing opposite
                    -- ways is the whole fight. Matching on kind == soak
                    -- then found nothing on Sszorak and the check passed
                    -- while testing one boss instead of two.
                    local best, bd
                    for _, a in ipairs(S.actors) do
                        local isSplit = (a.kind == "soak")
                            or (a.kind == "line" and a.soakIn)
                        if isSplit and not a.dead then
                            local d = math.sqrt((a.x - S.px) ^ 2 + (a.y - S.py) ^ 2)
                            if not bd or d < bd then best, bd = a, d end
                        end
                    end
                    local marked = (S.debuffs[mark] or 0) > S.time
                    if best then
                        if obeyMark and marked then
                            -- Walk out of it, and stay out.
                            --
                            -- A cone and a circle need leaving in
                            -- different directions: stepping radially
                            -- away from a cone's APEX can stay inside
                            -- it the whole way, because the apex is the
                            -- boss and the shape opens out from there.
                            if best.kind == "line" then
                                local perp = (best.dir or 0) + math.pi / 2
                                local out = (best.width or 24) + 26
                                S.px = best.x + math.cos(perp) * out
                                S.py = best.y + math.sin(perp) * out
                            else
                                local dx, dy = S.px - best.x, S.py - best.y
                                local d = math.sqrt(dx * dx + dy * dy)
                                if d < 0.001 then dx, dy, d = 1, 0, 1 end
                                local out = (best.r or 16) + 22
                                S.px = best.x + dx / d * out
                                S.py = best.y + dy / d * out
                            end
                            satOut = satOut + 1
                        else
                            -- Into it. For a cone that means a little
                            -- way down its axis, not on top of the
                            -- caster.
                            if best.kind == "line" then
                                local along = math.min(30, (best.len or 60) * 0.4)
                                S.px = best.x + math.cos(best.dir or 0) * along
                                S.py = best.y + math.sin(best.dir or 0) * along
                            else
                                S.px, S.py = best.x, best.y
                            end
                            soaked = soaked + 1
                        end
                    end
                    -- Attributed to the SOAK, not to the round.
                    --
                    -- The driver walks the player in and out of circles,
                    -- so the two runs stand in different places and eat
                    -- different amounts of everything else on the floor.
                    -- Totalling the round's misses measured that, and
                    -- reported the alternating player as worse while the
                    -- mark was working perfectly.
                    local function isSplitSoak(a)
                        return a.kind == "soak"
                            or (a.kind == "line" and a.soakIn)
                    end
                    -- Attributed on the frame a soak RESOLVES, spotted
                    -- by it gaining `flashUntil`.
                    --
                    -- Watching for the actor to disappear instead worked
                    -- for circles and silently failed for cones: a line
                    -- lingers about a fifth of a second after it fires,
                    -- so by the time it vanished the score had moved two
                    -- frames earlier and the delta was always zero.
                    local pending = {}
                    for _, a in ipairs(S.actors) do
                        if isSplitSoak(a) and not a.flashUntil then
                            pending[a] = true
                        end
                    end
                    local p, m = S.passed, S.failed
                    update(f, 0.05)
                    local resolved = false
                    for a in pairs(pending) do
                        if a.flashUntil then resolved = true end
                    end
                    if resolved then
                        passed = passed + (S.passed - p)
                        failed = failed + (S.failed - m)
                    end
                    if not S.running then break end
                end
                T:Stop()
                return passed, failed
            end

            local told = {}
            for _, case in ipairs({
                { id = "sisterrag", mark = "Mutilated", label = "Mutilate" },
                { id = "twinfangs", mark = "Gorged",    label = "Ravenous Feast" },
            }) do
                local greedyPass, greedyFail = run(case.id, case.mark, false)
                local smartPass, smartFail = run(case.id, case.mark, true)
                told[#told + 1] = string.format("%s %d->%d missed",
                    case.label, greedyFail, smartFail)
                if greedyFail == 0 then
                    problems[#problems + 1] = case.label ..
                        ": soaking every circle was never punished at all"
                end
                -- Judged on MISSES, not on passes. Sitting one out is
                -- itself credited, so both players accumulate passes;
                -- what separates them is that the greedy one is punished
                -- for soaking while marked, and that is the whole claim.
                if smartFail >= greedyFail then
                    problems[#problems + 1] = string.format(
                        "%s: soaking everything missed %d and alternating missed %d",
                        case.label, greedyFail, smartFail)
                end
            end

            if #problems > 0 then return table.concat(problems, "; ") end
            return "ok:" .. table.concat(told, ", ")
        end
    """)(ns)
    if alt and str(alt).startswith("ok:"):
        print("  ok   trainer alternating soaks: %s" % str(alt)[3:])
    else:
        print("  FAIL trainer alternating soaks: %s" % alt)
        failures.append(("trainer alternating soaks", str(alt)))

    # The Coiled Altar's three cross-phase rules, none of which had a
    # consequence attached before: orbs left on the floor explode at the
    # push, destroying them in a rush costs more than doing it in
    # batches, and Zul'jin comes back exactly where he died.
    altar = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate
            local problems = {}

            --- Play phase one, either ignoring the orbs or collecting
            --- them, and report the damage taken AT THE PUSH.
            local function phaseOne(collect, holdBossAt)
                math.randomseed(3429)
                T:Start("alteredfangs", false)
                S.countdown = 0
                local atPush, orbsLeft = 0, 0
                for _ = 1, 1600 do
                    S.firing = false
                    S.hp = 100
                    -- The boss is parked, so "where he died" is decided
                    -- by this check rather than by the puddle-avoidance
                    -- walk. Its position is the subject of the third
                    -- claim below.
                    if S.bossActor then
                        S.bossActor.hp = S.bossActor.maxHp * 0.99
                        if holdBossAt then
                            S.bossActor.x, S.bossActor.y = holdBossAt[1], holdBossAt[2]
                        end
                    end
                    if collect then
                        -- Walk to the nearest loose orb, or to the drop
                        -- point while holding one.
                        local target
                        if S.carrying then
                            local b = S.bossActor
                            local fa = (b and b.facing) or 0
                            target = { b.x + math.cos(fa) * 34, b.y + math.sin(fa) * 34 }
                        else
                            local bd
                            for _, a in ipairs(S.actors) do
                                if a.kind == "carry" and not a.dead and not a.held then
                                    local d = math.sqrt((a.x - S.px) ^ 2 + (a.y - S.py) ^ 2)
                                    if not bd or d < bd then target, bd = { a.x, a.y }, d end
                                end
                            end
                        end
                        if target then S.px, S.py = target[1], target[2] end
                    else
                        S.px, S.py = 0, -80
                    end
                    local was = S.phaseIndex
                    local hp = S.hp
                    update(f, 0.05)
                    if S.phaseIndex > was then
                        -- The push frame. Everything the boundary did is
                        -- on this one update.
                        atPush = hp - S.hp
                        break
                    end
                    if not S.running then break end
                end
                for _, a in ipairs(S.actors) do
                    if a.kind == "carry" and not a.dead then orbsLeft = orbsLeft + 1 end
                end
                local revive = S.revive
                T:Stop()
                return atPush, orbsLeft, revive
            end

            local ignored = phaseOne(false, { 0, 0 })
            local cleared = phaseOne(true, { 0, 0 })
            if ignored <= 0 then
                problems[#problems + 1] =
                    "leaving every orb on the floor cost nothing at the push"
            end
            if cleared >= ignored then
                problems[#problems + 1] = string.format(
                    "the push cost %.0f after clearing orbs and %.0f after ignoring them",
                    cleared, ignored)
            end

            -- The intermission's spirits walk at ZUL'JIN rather than at
            -- the room's centre.
            --
            -- This used to also assert that he was resurrected wherever
            -- he was pushed. That rule is gone: it rested on a source
            -- that did not survive, and no guide says it -- Malacrass
            -- binds with him and heals him where he already stands.
            math.randomseed(3429)
            T:Start("alteredfangs", false)
            S.countdown = 0
            -- How close the spirits get to HIM against how close they
            -- get to the middle of the room.
            --
            -- Measured as two minima rather than as a per-frame "is it
            -- closing" test: a spirit walking from the rim toward a boss
            -- parked at x=70 is often reducing both distances at once
            -- for part of its trip, so the frame-by-frame version was
            -- true of a spirit heading for the centre as well.
            local minToBoss, minToMid, sawSpirit = 1e9, 1e9, false
            local endedAt = 0
            for _ = 1, 2600 do
                S.firing, S.hp = false, 100
                S.px, S.py = 0, -80
                if S.bossActor then
                    S.bossActor.hp = S.bossActor.maxHp * 0.99
                    if S.phaseIndex == 1 then S.bossActor.x, S.bossActor.y = 70, 0 end
                end
                update(f, 0.05)
                if S.phaseIndex == 3 then
                    local b = S.bossActor
                    if b then endedAt = b.x end
                    for _, a in ipairs(S.actors) do
                        if a.name == "Drifting Spirit" and not a.dead and b then
                            sawSpirit = true
                            local dBoss = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
                            local dMid = math.sqrt(a.x * a.x + a.y * a.y)
                            if dBoss < minToBoss then minToBoss = dBoss end
                            if dMid < minToMid then minToMid = dMid end
                        end
                    end
                end
                if not S.running then break end
            end
            T:Stop()
            if not sawSpirit then
                problems[#problems + 1] = "the intermission spawned no Drifting Spirits"
            elseif math.abs(endedAt) < 40 then
                problems[#problems + 1] = string.format(
                    "Zul'jin died at x=70 but the intermission had him at x=%.0f", endedAt)
            elseif minToBoss >= minToMid then
                problems[#problems + 1] = string.format(
                    "spirits got within %.0f of Zul'jin and %.0f of the middle"
                    .. " -- they are walking at the room, not at him",
                    minToBoss, minToMid)
            end

            if #problems > 0 then return table.concat(problems, "; ") end
            return string.format(
                "ok:the push cost %.0f with orbs left against %.0f cleared;"
                .. " the intermission's spirits walk at Zul'jin (x=%.0f), not the room",
                ignored, cleared, endedAt)
        end
    """)(ns)
    if altar and str(altar).startswith("ok:"):
        print("  ok   trainer coiled altar: %s" % str(altar)[3:])
    else:
        print("  FAIL trainer coiled altar: %s" % altar)
        failures.append(("trainer coiled altar", str(altar)))

    # Ranged and healers hold still.
    #
    # The formation used to rotate wholesale with the boss's facing,
    # which is geometrically unfair: melee sit fifteen units out and
    # barely shift on a turn, while ranged sit at forty-six and swing
    # seventy units for the same turn. They were sprinting laps every
    # time the tank repositioned.
    #
    # Compared per ally rather than in total, since there are more of
    # them -- and against melee rather than a fixed number, because what
    # is wrong is the RATIO: the people furthest out were moving most.
    camps = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate

            T:Start("soulcoiler", false)
            S.countdown = 0
            local os_diag = false
            local moved, count, prev = {}, {}, {}
            local frames, backMoveFrames, resites = 0, 0, 0
            local lastCamp = {}
            for i, a in ipairs(S.allies) do prev[i] = { a.x, a.y } end

            for _ = 1, 2200 do
                S.hp, S.firing = 100, false
                if S.bossActor then S.bossActor.hp = S.bossActor.maxHp end
                update(f, 0.05)
                frames = frames + 1
                for i, a in ipairs(S.allies) do
                    local d = math.sqrt((a.x - prev[i][1])^2 + (a.y - prev[i][2])^2)
                    moved[a.role] = (moved[a.role] or 0) + d
                    if (a.role == "RANGED" or a.role == "HEALER") then
                        if d > 0.01 then backMoveFrames = backMoveFrames + 1 end
                        if a.camp then
                            local key = math.floor(a.camp.x) .. "," .. math.floor(a.camp.y)
                            if lastCamp[i] and lastCamp[i] ~= key then
                                resites = resites + 1
                            end
                            lastCamp[i] = key
                        end
                    end
                    prev[i][1], prev[i][2] = a.x, a.y
                end
                if not S.running and S.phaseIndex < #(S.phases or {}) then
                    S.running, S.hp = true, 100
                end
                if not S.running then break end
            end
            for _, a in ipairs(S.allies) do
                count[a.role] = (count[a.role] or 0) + 1
            end
            T:Stop()
            if os_diag then
                return string.format("DIAG frames=%d backMoveFrames=%d resites=%d",
                    frames, backMoveFrames, resites)
            end

            local function per(role)
                if not count[role] or count[role] == 0 then return nil end
                return (moved[role] or 0) / count[role]
            end
            local melee = per("MELEE")
            local ranged = per("RANGED")
            local healer = per("HEALER")
            if not (melee and ranged and healer) then
                return "a role was missing from the raid"
            end
            local back = math.max(ranged, healer)
            -- A real margin, not a hair. The first version of this
            -- passed at 2606 against 2701, which is not "holding
            -- station" by any reading -- it is the same churn with a
            -- rounding error on top.
            if back >= melee * 0.75 then
                return string.format(
                    "ranged/healers moved %.0f each against melee %.0f -- the back is still churning",
                    back, melee)
            end
            return string.format("ok:%.0f per ranged against %.0f per melee", back, melee)
        end
    """)(ns)
    if camps and str(camps).startswith("ok:"):
        print("  ok   trainer camps: ranged hold station (%s)" % str(camps)[3:])
    else:
        print("  FAIL trainer camps: %s" % camps)
        failures.append(("trainer camps", str(camps)))

    # Phases.
    #
    # The whole point of the rebuild, and the one claim nothing else here
    # makes: a fight has to actually MOVE through its phases. A scenario
    # that stalls in phase one still plays -- mechanics spawn, the score
    # ticks up, the round ends on the clock -- and looks entirely normal
    # while teaching a third of the encounter.
    #
    # Also checks that an intermission's immunity really holds, because
    # "the boss cannot be damaged here" is the thing that makes an
    # intermission a phase rather than a lull.
    phases = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate
            local problems, checked = {}, 0

            for _, boss in ipairs(ns.RaidGuide:Ordered()) do
                local sc = ns.RaidTrainerScenarios[boss.id]
                if sc and sc.phases and #sc.phases > 1 then
                    T:Start(boss.id, false)
                    S.countdown = 0
                    local reached, immuneTested, immuneLeak = 1, false, false
                    local budget = 0
                    for _, ph in ipairs(sc.phases) do budget = budget + (ph.duration or 45) end

                    for _ = 1, math.ceil((budget + 60) / 0.05) do
                        S.hp, S.firing, S.energy = 100, true, 0
                        local ph = S.phases[S.phaseIndex]
                        -- Snapshotted PER BOSS, by index.
                        --
                        -- Sampling S.bossActor alone was wrong the moment
                        -- a fight could have two: on the Sentinels that
                        -- pointer switches to the other golem when the
                        -- phase swaps your side, and comparing one
                        -- golem's health against the other's read as the
                        -- boss taking damage through its own immunity.
                        local before = {}
                        for i, b in ipairs(S.bossActors) do before[i] = b.hp end
                        update(f, 0.05)
                        if S.phaseIndex > reached then reached = S.phaseIndex end
                        if ph and ph.bossImmune then
                            immuneTested = true
                            for i, b in ipairs(S.bossActors) do
                                if before[i] and b.hp < before[i] then
                                    immuneLeak = true
                                end
                            end
                        end
                        -- Kept alive so the round is not cut short by the
                        -- player dying in phase one.
                        for _, b in ipairs(S.bossActors) do
                            b.hp = math.max(b.hp, 1)
                        end
                        if not S.running then break end
                    end
                    T:Stop()

                    if reached < #sc.phases then
                        problems[#problems + 1] = string.format(
                            "%s only reached phase %d of %d", boss.id, reached, #sc.phases)
                    end
                    if immuneLeak then
                        problems[#problems + 1] = boss.id ..
                            ": the boss took damage during an immune phase"
                    end
                    checked = checked + 1
                end
            end

            if #problems > 0 then return table.concat(problems, "; ") end
            if checked == 0 then return "no multi-phase fights to check" end
            return "ok:" .. checked
        end
    """)(ns)
    if phases and str(phases).startswith("ok:"):
        print("  ok   trainer phases: %s fights run end to end, immunity holds"
              % str(phases)[3:])
    else:
        print("  FAIL trainer phases: %s" % phases)
        failures.append(("trainer phases", str(phases)))

    # Sszorak's two-stage mechanic actually gates.
    #
    # Placing cysts and riding the wind are a minute apart, and the whole
    # point is that the second is impossible if you skipped the first.
    # A version where the wind was survivable anyway would look identical
    # on screen and teach nothing, so this plays the fight twice -- once
    # doing the preparation, once ignoring it -- and requires the scores
    # to differ.
    twostage = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate
            local sc = ns.RaidTrainerScenarios.sisterrag
            if not sc.tunnels then return "Sszorak has no tunnels" end

            local budget = 0
            for _, ph in ipairs(sc.phases) do budget = budget + (ph.duration or 45) end
            local steps = math.ceil((budget + 60) / 0.05)

            --- Play a round. `follow` walks to whatever the mechanic
            --- currently wants; otherwise the player never moves.
            ---
            --- `onCyst` plays it the way the old version of the wind
            --- rewarded: place everything correctly, then stand ON the
            --- cyst when the gale lands. Contact bursts a cyst, so that
            --- is the mistake, and this file has to be able to tell the
            --- two plays apart or the correction is not being tested.
            local function play(follow, onCyst)
                T:Start("sisterrag", false)
                S.countdown = 0
                local orders = {}
                for _, t in ipairs(S.tunnels or {}) do
                    orders[t.order] = (orders[t.order] or 0) + 1
                end
                for step = 1, 3 do
                    if orders[step] ~= 1 then
                        T:Stop()
                        return nil, "tunnel orders are not 1/2/3 exactly once"
                    end
                end

                for _ = 1, steps do
                    S.hp = 100
                    if S.bossActor then S.bossActor.hp = S.bossActor.maxHp end
                    if follow then
                        for _, a in ipairs(S.actors) do
                            if a.kind == "place" and a.tunnel then
                                -- The cyst is dropped on the marker
                                -- across the room from its tunnel.
                                S.px, S.py = a.tunnel.cx, a.tunnel.cy
                            elseif a.kind == "wind" and a.tunnel then
                                -- And ridden from BETWEEN the tunnel and
                                -- that marker. The middle of the room is
                                -- on the line between them, which is why
                                -- the pixel stack put everyone there.
                                if onCyst then
                                    S.px, S.py = a.tunnel.cx, a.tunnel.cy
                                else
                                    S.px, S.py = 0, 0
                                end
                            elseif a.kind == "stack" then
                                S.px, S.py = 0, 0
                            end
                        end
                    end
                    update(f, 0.05)
                    if not S.running and S.phaseIndex < #(S.phases or {}) then
                        S.running, S.hp = true, 100
                    end
                    if not S.running then break end
                end
                local placed = 0
                for _, t in ipairs(S.tunnels or {}) do
                    if t.cyst then placed = placed + 1 end
                end
                local missed = S.failed
                T:Stop()
                return { placed = placed, missed = missed }
            end

            local good, err = play(true)
            if err then return err end
            local onCyst = play(true, true)
            local bad = play(false)

            if good.placed == 0 then
                return "playing the mechanic correctly placed no cysts at all"
            end
            if bad.placed > 0 then
                return "cysts appeared without anybody placing them"
            end
            if good.missed >= bad.missed then
                return string.format(
                    "doing the preparation missed %d and ignoring it missed %d -- it changes nothing",
                    good.missed, bad.missed)
            end
            if good.missed >= onCyst.missed then
                return string.format(
                    "riding the corridor missed %d and standing on the cyst missed %d -- contact is not bursting it",
                    good.missed, onCyst.missed)
            end
            return string.format(
                "ok:%d cysts placed, %d misses riding it against %d standing on it and %d ignoring it",
                good.placed, good.missed, onCyst.missed, bad.missed)
        end
    """)(ns)
    if twostage and str(twostage).startswith("ok:"):
        print("  ok   trainer cysts: placing them is what makes the wind survivable (%s)"
              % str(twostage)[3:])
    else:
        print("  FAIL trainer cysts: %s" % twostage)
        failures.append(("trainer cysts", str(twostage)))

    # The utility advisor knows the dungeons people are actually running.
    #
    # This is the failure it already had once: the data was written for
    # one keystone pool, the pool rolled over, and the window went quiet
    # in every dungeon without anything looking broken. There is no error
    # to catch -- ShowForCurrentInstance simply returns when the map is
    # not in the table -- so the only way to notice is to ask.
    utility = L.eval("""
        function(ns)
            local d = ns.UTILITY_DUNGEONS
            if not d then return "UtilityData.lua published nothing" end
            if not ns.UTILITY_BUILT_AT then return "no build date on the utility data" end

            local n, thin = 0, {}
            for mapID, entry in pairs(d) do
                n = n + 1
                if not entry.header or entry.header == "" then
                    return mapID .. " has no header"
                end
                if not entry.lead or not entry.description then
                    return entry.header .. " is missing its lead or description"
                end
                -- Thirteen classes, because a class with no entry shows
                -- an empty window to whoever plays it.
                local classes = 0
                for _ in pairs(entry.byClass or {}) do classes = classes + 1 end
                if classes ~= 13 then
                    table.insert(thin, string.format("%s has %d classes", entry.header, classes))
                end
                for class, list in pairs(entry.byClass or {}) do
                    if #list == 0 then
                        return entry.header .. ": " .. class .. " has no abilities at all"
                    end
                    for _, raw in ipairs(list) do
                        local id = type(raw) == "table" and raw.id or raw
                        if type(id) ~= "number" then
                            return entry.header .. ": " .. class .. " has a malformed entry"
                        end
                    end
                end
            end
            if n == 0 then return "the utility data is empty" end
            if #thin > 0 then return table.concat(thin, "; ") end

            -- And the preview has to land on something real, which is
            -- exactly what broke last time.
            local UA = ns.UtilityAdvisor
            if UA and UA.ShowTest then
                UA:ShowTest()
                local shown = UA._lastShownMapID
                if not shown or not d[shown] then
                    return "the preview samples a dungeon the data does not have"
                end
            end

            -- Stepping through has to actually reach all of them. The
            -- point of the command is checking every dungeon renders
            -- without running a season of keystones, so a cycle that
            -- silently skipped one would defeat its only purpose.
            if UA and UA.CycleTest then
                local seen, first = {}, nil
                UA._lastShownMapID = nil
                for i = 1, n do
                    UA:CycleTest(1)
                    local at = UA._lastShownMapID
                    if not at or not d[at] then
                        return "step " .. i .. " landed on a dungeon the data does not have"
                    end
                    if seen[at] then
                        return string.format("step %d revisited %s before covering all %d",
                            i, d[at].header, n)
                    end
                    seen[at] = true
                    first = first or at
                end
                UA:CycleTest(1)
                if UA._lastShownMapID ~= first then
                    return "the cycle does not wrap back to the first dungeon"
                end
                UA:CycleTest(-1)
                if UA._lastShownMapID == first then
                    return "stepping back from the first did not wrap to the last"
                end
                -- And by name, on a fragment rather than the whole title.
                for _, entry in pairs(d) do
                    local word = entry.header:match("(%a%a%a%a+)")
                    if word and UA:FindTestDungeon(word) == nil then
                        return "no dungeon matched its own name fragment " .. word
                    end
                end
            end
            if UA and UA.Hide then UA:Hide() end

            return string.format("ok:%d dungeons, 13 classes each, all reachable by name, built %s",
                n, ns.UTILITY_BUILT_AT)
        end
    """)(ns)
    if utility and str(utility).startswith("ok:"):
        print("  ok   utility advisor: every dungeon is complete and the preview lands (%s)"
              % str(utility)[3:])
    else:
        print("  FAIL utility advisor: %s" % utility)
        failures.append(("utility advisor", str(utility)))

    # Nothing here uses a Lua the client does not have.
    #
    # This file runs on 5.5 and the game runs 5.1, which makes the
    # harness BLIND in one specific direction: anything added to Lua
    # after 5.1 works perfectly here and is "attempt to call a nil value"
    # in game. That is not hypothetical -- coroutine.isyieldable() got
    # into the loot scanner exactly this way, passed every check, and
    # broke the moment it ran for real.
    #
    # Static, because the point is to catch the call that is never
    # reached during a load test as well as the one that is.
    POST_51 = (
        "coroutine.isyieldable", "coroutine.close",
        "math.type", "math.tointeger", "math.maxinteger", "math.mininteger",
        "math.ult", "table.move", "table.pack",
        "string.pack", "string.unpack", "string.packsize",
        "rawlen", "utf8.",
    )

    def strip_lua_comments(src):
        # Block comments first, then line comments. Our own explanation
        # of this bug names the very functions it looks for, so scanning
        # comments would flag the documentation rather than the code.
        # Written with chr() rather than escapes on purpose: this
        # block is generated through tooling that has eaten a
        # backslash more than once, and a mangled escape here turns
        # into a syntax error in the file that checks everything else.
        src = re.sub(re.escape("--[[") + ".*?" + re.escape("]]"), "", src, flags=re.S)
        return re.sub("--[^" + chr(10) + "]*", "", src)

    modern = []
    for rel in toc_files():
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path) or rel.startswith("Libs"):
            continue
        code = strip_lua_comments(open(path, encoding="utf-8-sig").read())
        for name in POST_51:
            if name in code:
                line = code[:code.index(name)].count(chr(10)) + 1
                modern.append("%s uses %s (Lua 5.2+), around line %d" % (rel, name, line))
    if modern:
        print("  FAIL lua 5.1: %s" % "; ".join(modern))
        failures.append(("lua 5.1", "; ".join(modern)))
    else:
        print("  ok   lua 5.1: no post-5.1 standard library calls in %d addon file(s)"
              % len([r for r in toc_files() if not r.startswith("Libs")]))

    # The loot scan does not run for a whole frame.
    #
    # It is thousands of Encounter Journal calls -- every tier of every
    # expansion, then every boss at every difficulty -- and as one
    # synchronous pass it grew past the client's watchdog and died with
    # "script ran too long", blamed on whichever EJ call happened to be
    # executing. What matters now is that it yields, and that it still
    # finishes with the same answer.
    loot = L.eval("""
        function(ns)
            if not (ns.ScanLootBrowserSlot and ns.LootScanRunner) then
                return "the loot scanner is not published"
            end
            local saved = {}
            local function stub(name, fn) saved[name] = _G[name]; _G[name] = fn end
            -- A millisecond per journal call, against an 8ms budget, so
            -- the yield fires after a handful of them. The real timings
            -- depend on how much the journal holds; what is being tested
            -- is that exceeding the budget hands the frame back at all.
            local calls, clock = 0, 0
            local function tick() calls = calls + 1; clock = clock + 1 end
            stub("debugprofilestop", function() return clock end)

            -- A pcall that behaves like the client's.
            --
            -- Lua 5.1 cannot yield across a C call, and pcall is one --
            -- so wrapping yielding work in a pcall dies in game with
            -- "attempt to yield across metamethod/C-call boundary". This
            -- file runs 5.5, where pcall IS yieldable, so that mistake
            -- passed every check and shipped. Running the target on its
            -- own coroutine and refusing a suspend reproduces the 5.1
            -- rule exactly.
            stub("pcall", function(fn, ...)
                local co = coroutine.create(fn)
                local res = table.pack(coroutine.resume(co, ...))
                if res[1] and coroutine.status(co) == "suspended" then
                    return false, "attempt to yield across metamethod/C-call boundary"
                end
                return table.unpack(res, 1, res.n)
            end)
            stub("UnitClass", function() return "Warrior", "WARRIOR", 1 end)
            stub("GetSpecializationInfoForClassID", function() return 71 end)
            stub("GetItemInfo", function()
                return "x", "|cffa335ee|Hitem:1|h[x]|h|r", 4, 0, 0, "", "", 1, "", 1, 0, 0, 0, 0, 0, 0, 0
            end)
            local TIERS, tier = 11, 1
            local NAMES = { "Altar of Fangs", "Den of Nalorakk", "Kings' Rest", "Murder Row",
                            "Ruby Life Pools", "Temple of Sethraliss", "The Blinding Vale",
                            "Voidscar Arena" }
            -- Mutated in place, not replaced. LootBrowserData.lua does
            -- `local CEJ = C_EncounterJournal` at load, so swapping the
            -- global afterwards leaves the module holding the old table
            -- and the sweep silently finds nothing -- which reads as
            -- "it finished in one frame" rather than "the stub missed".
            local CEJ = _G.C_EncounterJournal
            local savedCEJ = {}
            local function ej(name, fn) savedCEJ[name] = CEJ[name]; CEJ[name] = fn end
            for name, fn in pairs({
                GetCurrentTier = function() tick() return TIERS end,
                GetNumTiers = function() tick() return TIERS end,
                SelectTier = function(x) tick() tier = x end,
                GetInstanceByIndex = function(i)
                    tick()
                    if i > 20 then return nil end
                    if tier == TIERS and i <= #NAMES then return 1000 + i, NAMES[i] end
                    return 2000 + tier * 100 + i, "Old Instance " .. i
                end,
                SelectInstance = function() tick() end,
                GetEncounterInfoByIndex = function(i)
                    tick()
                    if i > 4 then return nil end
                    return "Boss " .. i, nil, 5000 + i
                end,
                SelectEncounter = function() tick() end,
                SetDifficulty = function() tick() end,
                GetDifficulty = function() tick() return 8 end,
                SetLootFilter = function() tick() end,
                SetSlotFilter = function() tick() end,
                GetSlotFilter = function() tick() return 0 end,
                GetLootFilter = function() tick() return 1, 1 end,
                GetNumLoot = function() tick() return 3 end,
                GetLootInfoByIndex = function(i)
                    tick()
                    if i > 3 then return nil end
                    return { name = "Item " .. i, itemID = 200000 + i, icon = 1,
                             link = "|cffa335ee|Hitem:1|h[x]|h|r" }
                end,
            }) do ej(name, fn) end

            local function finish(msg)
                for name, fn in pairs(saved) do _G[name] = fn end
                for name, fn in pairs(savedCEJ) do CEJ[name] = fn end
                if ns.ClearAllLootBrowserCaches then ns:ClearAllLootBrowserCaches() end
                return msg
            end

            ns.lootBrowserState = ns.lootBrowserState or {}
            ns.lootBrowserState.selectedClassID = 1
            ns.lootBrowserState.selectedSpecID = 71
            -- The instance cache too, not just the loot cache: with it
            -- already warm the sweep is a fraction of its real size and
            -- the test would be measuring almost nothing.
            if ns.ClearAllLootBrowserCaches then ns:ClearAllLootBrowserCaches() end

            local first = ns:ScanLootBrowserSlot(1, 0)
            if #first > 0 then
                return finish("the first ask returned rows synchronously, so it did not yield")
            end
            if not ns:IsLootScanRunning() then return finish("no pass was started") end

            local drive = ns.LootScanRunner:GetScript("OnUpdate")
            if not drive then return finish("the scan runner has no OnUpdate") end
            local frames = 0
            while ns:IsLootScanRunning() and frames < 5000 do
                frames = frames + 1
                drive(ns.LootScanRunner)
            end
            if ns:IsLootScanRunning() then return finish("the pass never finished") end
            if frames < 2 then
                return finish("the whole sweep fitted in one frame, so it is not yielding")
            end

            local second = ns:ScanLootBrowserSlot(1, 0)
            if #second == 0 then return finish("the finished pass cached nothing") end

            -- A request made while the login prewarm is working must not
            -- be dropped. It used to be: the pass that finished was the
            -- prewarm's, nothing ever started the one that was asked
            -- for, and the browser sat there showing the wrong filter.
            ns:ClearAllLootBrowserCaches()
            ns:ScanLootBrowserSlot(1, 0, true)          -- prewarm, nobody waiting
            for _ = 1, 3 do drive(ns.LootScanRunner) end
            if not ns:IsLootScanRunning() then
                return finish("the prewarm finished too early to test cancellation")
            end
            ns:ScanLootBrowserSlot(1, 5)                -- the player opens the browser
            if not ns:IsLootScanRunning() then
                return finish("asking during a prewarm started no pass at all")
            end
            local n = 0
            while ns:IsLootScanRunning() and n < 5000 do
                n = n + 1
                drive(ns.LootScanRunner)
            end
            if #ns:ScanLootBrowserSlot(1, 5) == 0 then
                return finish("the filter asked for during a prewarm was never scanned")
            end

            return string.format(
                "ok:%d journal calls over %d frames, %d rows cached, a prewarm yields to a real ask",
                calls, frames, #second)
        end
    """)(ns)
    if loot and str(loot).startswith("ok:"):
        print("  ok   loot scan: spread across frames, not one long block (%s)"
              % str(loot)[3:])
    else:
        print("  FAIL loot scan: %s" % loot)
        failures.append(("loot scan", str(loot)))

    # Bindings.xml points at things that exist -- and is a file the
    # client will actually read.
    #
    # The client loads that file itself, so nothing here parses it and a
    # binding whose body calls a renamed global fails the quietest way
    # possible: the key does nothing, in a panel where "nothing happened"
    # reads as "I must have bound it wrong". The names it depends on are
    # globals set in Lua, which is exactly what this file can check.
    bindings_path = os.path.join(ROOT, "Bindings.xml")
    if not os.path.exists(bindings_path):
        print("  ok   bindings: none declared")
    else:
        # Not named `xml`: that is the module this now parses with, and
        # the local shadowed it.
        source = open(bindings_path, encoding="utf-8").read()
        g = L.globals()
        problems = []
        # Well-formedness FIRST, with a real parser.
        #
        # This check used to go straight to the regex below, which meant
        # it read a file the client refuses to load and reported it
        # healthy. A malformed Bindings.xml is not a partial failure: the
        # client drops the whole file, so the binding stops existing and
        # the Key Bindings panel simply has nothing in it.
        #
        # The way it actually broke is worth naming, because it is a
        # habit rather than a typo. XML forbids a double hyphen inside a
        # comment body, and every Lua file in this addon uses one as an
        # em-dash -- like this -- so writing the header comment in the
        # house style is enough to break the file. expat catches it;
        # nothing else here would, least of all the regex that strips
        # comments before looking at anything.
        try:
            xml.parsers.expat.ParserCreate().Parse(source.encode("utf-8"), True)
        except xml.parsers.expat.ExpatError as e:
            problems.append("Bindings.xml is not well-formed (%s); the client "
                            "drops the whole file, so the binding does not exist" % e)
        # Comments stripped only now, and only for the name matching
        # below: the explanation above the bindings names the very
        # globals being looked for, and matching those would check the
        # comment rather than the code.
        body = re.sub(r"<!--.*?-->", "", source, flags=re.S)
        found = re.findall(r"<Binding\s+([^>]*)>(.*?)</Binding>", body, flags=re.S)
        if not found:
            problems.append("Bindings.xml declares no bindings")
        for attrs, code in found:
            name = re.search(r'name="([^"]+)"', attrs)
            if not name:
                problems.append("a binding has no name")
                continue
            name = name.group(1)
            if g["BINDING_NAME_" + name] is None:
                problems.append("%s has no BINDING_NAME_ global, so it shows as its raw id" % name)
            header = re.search(r'header="([^"]+)"', attrs)
            if header and g["BINDING_HEADER_" + header.group(1)] is None:
                problems.append("%s files under header %s, which has no BINDING_HEADER_ global"
                                % (name, header.group(1)))
            # Everything the body calls has to be a global function --
            # the body runs in the global environment and cannot see an
            # addon's namespace.
            for fn in re.findall(r"([A-Za-z_][\w]*)\s*\(", code):
                if g[fn] is None:
                    problems.append("%s calls %s(), which does not exist" % (name, fn))
                elif not callable(g[fn]):
                    problems.append("%s calls %s(), which is not a function" % (name, fn))
        if problems:
            print("  FAIL bindings: %s" % "; ".join(problems))
            failures.append(("bindings", "; ".join(problems)))
        else:
            print("  ok   bindings: %d binding(s), each named and pointing at a real function"
                  % len(found))

    # Other people's interrupts land on the tracker.
    #
    # The tracker cannot read a party member's spell id -- it is secret
    # once tainted -- so somebody else's kick is inferred: their cast is
    # noted by timestamp, and an enemy's interrupt event within a moment
    # of it is attributed to them. That makes WHICH unit tokens count the
    # whole mechanism, and it used to be nameplates alone, which fails
    # entirely for anyone with enemy nameplates off.
    interrupts = L.eval("""
        function(ns)
            local I, S = ns.Interrupts, ns.InterruptsSettings
            if not (I and S) then return "the interrupt tracker is not loaded" end

            local saved = {}
            local function stub(name, fn) saved[name] = _G[name]; _G[name] = fn end
            local clock = 1000
            stub("GetTime", function() return clock end)
            stub("IsInGroup", function() return true end)
            stub("UnitExists", function(u)
                return u == "player" or u == "party1" or u == "party2"
                    or u == "target" or u == "nameplate1" or u == "nameplate2"
            end)
            stub("UnitName", function(u) return u end)
            stub("UnitClass", function(u)
                if u == "party1" then return "Shaman", "SHAMAN" end
                if u == "party2" then return "Mage", "MAGE" end
                return "Warrior", "WARRIOR"
            end)
            local function creature(u)
                if u == "target" or u == "nameplate1" then return "Creature-1" end
                if u == "nameplate2" then return "Creature-2" end
                return "P-" .. tostring(u)
            end
            stub("UnitGUID", creature)
            -- The tracker deduplicates with unit tokens now, because enemy
            -- guids come back secret in Midnight. Same two mobs, asked the
            -- way the addon asks.
            stub("UnitIsUnit", function(a, b) return creature(a) == creature(b) end)

            local wasEnabled = S:Get("enabled")
            S:Set("enabled", true)
            FireEvent("GROUP_ROSTER_UPDATE")

            local function onCd(unit)
                local e = I.state[UnitGUID(unit)]
                return (e and e.readyAt and e.readyAt > clock) and true or false
            end
            local function kick(caster, enemy)
                clock = clock + 60
                FireEvent("UNIT_SPELLCAST_SUCCEEDED", caster, "c", 57994)
                clock = clock + 0.05
                FireEvent("UNIT_SPELLCAST_INTERRUPTED", enemy)
            end
            local function finish(msg)
                S:Set("enabled", wasEnabled)
                for name, fn in pairs(saved) do _G[name] = fn end
                return msg
            end

            if onCd("party1") then return finish("a cooldown was running before anybody kicked") end

            kick("party1", "nameplate1")
            if not onCd("party1") then
                return finish("a party kick reported on a nameplate was not attributed")
            end

            kick("party2", "target")
            if not onCd("party2") then
                return finish("a party kick reported on the target was ignored -- "
                    .. "nameplates are not the only way this event arrives")
            end

            -- One kick, reported on both tokens for the same enemy. The
            -- duplicate must not consume a second player's cast.
            clock = clock + 60
            FireEvent("UNIT_SPELLCAST_SUCCEEDED", "party1", "c", 57994)
            FireEvent("UNIT_SPELLCAST_SUCCEEDED", "party2", "c", 2139)
            clock = clock + 0.05
            FireEvent("UNIT_SPELLCAST_INTERRUPTED", "nameplate1")
            FireEvent("UNIT_SPELLCAST_INTERRUPTED", "target")
            if onCd("party1") and onCd("party2") then
                return finish("one interrupt reported twice put two people on cooldown")
            end
            if not (onCd("party1") or onCd("party2")) then
                return finish("one interrupt reported twice attributed to nobody")
            end

            -- The other side of the same window: two DIFFERENT mobs kicked
            -- close together are two kicks, and dropping the second would
            -- leave a real cooldown untracked.
            clock = clock + 300
            FireEvent("UNIT_SPELLCAST_SUCCEEDED", "party1", "c", 57994)
            FireEvent("UNIT_SPELLCAST_SUCCEEDED", "party2", "c", 2139)
            clock = clock + 0.05
            FireEvent("UNIT_SPELLCAST_INTERRUPTED", "nameplate1")
            FireEvent("UNIT_SPELLCAST_INTERRUPTED", "nameplate2")
            if not (onCd("party1") and onCd("party2")) then
                return finish("two enemies kicked in the same window counted as one")
            end

            return finish("ok:nameplate and target both attribute, duplicates charge "
                .. "one player, two enemies charge two")
        end
    """)(ns)
    if interrupts and str(interrupts).startswith("ok:"):
        print("  ok   interrupts: other players' kicks are attributed (%s)"
              % str(interrupts)[3:])
    else:
        print("  FAIL interrupts: %s" % interrupts)
        failures.append(("interrupts", str(interrupts)))

    # The ready check survives being refused the aura list.
    #
    # This has now moved twice. 11.x made aura FIELDS secret, so
    # comparing or indexing with one threw; 12.x put the wall in front of
    # the door, and GetAuraDataByIndex itself raises "Auras cannot be
    # accessed when secret while tainted". An addon is tainted by
    # definition, so there is no version of this we can win -- the only
    # question is whether the window dies, quietly lies, or says it does
    # not know. It has to be the third, and only rendering can show which.
    auras = L.eval("""
        function(ns)
            if not (ns.ReadyCheck and ns.ReadyCheck.Preview) then
                return "no ready check to render"
            end
            local frame = _G.YippYappReadyCheck
            if not (frame and frame._fullRows) then return "the row pool is not published" end

            -- Everything the roster walk needs, kept local to this check
            -- and put back afterwards so nothing else inherits a group.
            local saved = {}
            local function stub(name, fn)
                saved[name] = _G[name]
                _G[name] = fn
            end
            stub("IsInGroup", function() return true end)
            stub("IsInRaid", function() return false end)
            stub("GetNumGroupMembers", function() return 1 end)
            stub("UnitExists", function(u) return u == "player" end)
            stub("UnitIsUnit", function(a, b) return a == b end)
            stub("UnitClass", function() return "Warrior", "WARRIOR" end)
            stub("UnitName", function() return "Tester" end)
            stub("Ambiguate", function(n) return n end)
            stub("GetReadyCheckStatus", function() return "ready" end)
            stub("UnitIsConnected", function() return true end)
            stub("UnitIsDeadOrGhost", function() return false end)
            stub("GetInventoryItemDurability", function() return 100, 100 end)
            stub("GetInventoryItemLink", function() return nil end)
            stub("IsInInstance", function() return false, "none" end)

            local realAuras = C_UnitAuras
            local refusing = true
            local calls = 0
            C_UnitAuras = {
                GetAuraDataByIndex = function(_, i)
                    if refusing then
                        calls = calls + 1
                        error("Auras cannot be accessed when secret while tainted by 'YippYappHelper'")
                    end
                    if i == 1 then
                        return { spellId = 21562, name = "Power Word: Fortitude", icon = 1 }
                    end
                    return nil
                end,
                GetAuraDataBySpellName = function() return nil end,
            }

            local function columns()
                for _, row in ipairs(frame._fullRows) do
                    if row:IsShown() then
                        local counts = { have = 0, missing = 0, unknown = 0, na = 0 }
                        for _, btn in ipairs(row.icons or {}) do
                            if btn._present == true then counts.have = counts.have + 1
                            elseif btn._present == false then counts.missing = counts.missing + 1
                            elseif btn._blocked then counts.unknown = counts.unknown + 1
                            else counts.na = counts.na + 1 end
                        end
                        return counts
                    end
                end
            end

            local function finish(msg)
                C_UnitAuras = realAuras
                for name, fn in pairs(saved) do _G[name] = fn end
                if ns.ReadyCheck.Hide then ns.ReadyCheck.Hide() end
                return msg
            end

            -- Refused.
            local ok, err = pcall(ns.ReadyCheck.Preview, false)
            if not ok then
                return finish("a refused aura scan still errors the render: " .. tostring(err))
            end
            if calls == 0 then return finish("the aura API was never called") end
            local c = columns()
            if not c then return finish("nothing rendered while refused") end
            if c.missing > 0 then
                return finish(string.format(
                    "%d column(s) read as MISSING while auras were unreadable -- that is an accusation, not a reading",
                    c.missing))
            end
            if c.unknown == 0 then return finish("no column reported unknown") end
            local blockedUnknown = c.unknown

            -- Allowed, so the two are provably different renders rather
            -- than one grey window that always looks the same.
            ns.ReadyCheck.Hide()
            refusing = false
            FireEvent("GROUP_ROSTER_UPDATE")
            local ok2 = pcall(ns.ReadyCheck.Preview, false)
            if not ok2 then return finish("the normal render broke") end
            local c2 = columns()
            if not c2 then return finish("nothing rendered when allowed") end
            if c2.unknown > 0 then
                return finish(string.format(
                    "%d column(s) still read unknown after access came back", c2.unknown))
            end
            if c2.have == 0 then
                return finish("the buff that was there did not register when readable")
            end

            return finish(string.format("ok:%d columns unknown when refused, %d found when allowed",
                blockedUnknown, c2.have))
        end
    """)(ns)
    if auras and str(auras).startswith("ok:"):
        print("  ok   ready check: a refused aura scan says unknown, not missing (%s)"
              % str(auras)[3:])
    else:
        print("  FAIL ready check auras: %s" % auras)
        failures.append(("ready check auras", str(auras)))

    # Every self-opening window can be raised from chat, and owns itself.
    #
    # The three windows it hosts cannot be summoned in normal play -- you
    # cannot start a ready check to see where it sits -- so "/yh test" is
    # the only way to look at one without finishing a keystone. Two of
    # them also build themselves at PLAYER_LOGIN, which is exactly the
    # wiring most likely to rot silently, so this fires that event and
    # then drives the command for real rather than calling the API
    # underneath it.
    panels = L.eval("""
        function(ns)
            if not ns.Hud then return "the situation window is not loaded" end
            if FireEvent("PLAYER_LOGIN") == 0 then
                return "nothing was listening for PLAYER_LOGIN"
            end

            local order, modes = ns.Hud:Modes()
            local seen = {}
            for _, id in ipairs(order) do seen[id] = true end
            for _, want in ipairs({ "readyCheck", "mplusCompletion", "utilityAdvisor" }) do
                if not seen[want] then
                    return want .. " never registered with the situation window"
                end
            end

            local yh = SlashCmdList.YIPPYAPPHELPER
            if not yh then return "no /yh handler" end

            local tried = 0
            for _, id in ipairs(order) do
                local m = modes[id]
                if not m.aliases or #m.aliases == 0 then
                    return id .. " registered no chat alias, so nobody can raise it"
                end
                -- Every alias, and the id itself, has to reach the panel.
                for _, word in ipairs(m.aliases) do
                    if ns.Hud:Find(word) ~= id then
                        return string.format("alias %s resolves to %s, not %s",
                            word, tostring(ns.Hud:Find(word)), id)
                    end
                end
                if ns.Hud:Find(id) ~= id then return id .. " cannot be found by its own id" end

                -- And the command has to put that window on screen.
                yh("test " .. m.aliases[1])
                if not ns.Hud:IsShown(id) then
                    return string.format("/yh test %s did not raise it", m.aliases[1])
                end

                -- Each one owns its position now, so each has to be
                -- anchored somewhere of its own rather than parented
                -- into a shared host.
                if not m.frame:GetPoint() then
                    return id .. " is not anchored anywhere"
                end
                if m.frame:GetParent() ~= UIParent then
                    return id .. " is parented to something other than UIParent"
                end
                if not m.frame:IsMovable() then
                    return id .. " cannot be dragged"
                end
                tried = tried + 1
            end

            -- Independent windows: raising every one leaves every one up,
            -- which is the whole point of splitting them.
            local up = ns.Hud:Shown()
            if #up ~= tried then
                return string.format("%d windows raised but %d are showing", tried, #up)
            end

            yh("test off")
            if #ns.Hud:Shown() > 0 then
                return "/yh test off left something on screen"
            end
            if ns.Hud:Find("wobble") ~= nil then return "an unknown word matched a window" end

            return string.format(
                "ok:%d windows, each raised by name, each on its own anchor, all dismissed", tried)
        end
    """)(ns)
    if panels and str(panels).startswith("ok:"):
        print("  ok   windows: each moves itself and is testable from chat (%s)"
              % str(panels)[3:])
    else:
        print("  FAIL panels: %s" % panels)
        failures.append(("panels", str(panels)))

    # Opening itself when the game loads, and the three times it must not.
    #
    # The event this rides on fires on every loading screen, so the
    # interesting case is the one that must do nothing: walking through
    # an instance door is a PLAYER_ENTERING_WORLD with both flags false,
    # and a window that reopened on each of those would be unusable.
    # That is the negative control here, alongside the setting being off.
    #
    # C_Timer.After is swapped for one that keeps the callback, because
    # the real open is five seconds behind the login and the stub is a
    # no-op -- so without this the check would assert the gate and call
    # it a feature.
    login = L.eval("""
        function(ns)
            if not ns.OpenOnLoginIfWanted then return "open on login is not wired up" end
            if not (ns.Shell and ns.Shell.IsOpen) then return "no shell to open" end
            if ns.Shell:IsOpen() then ns.Shell:Close() end

            local realAfter = C_Timer.After
            local queued
            C_Timer.After = function(_, fn) queued = fn end

            --- One loading screen. Returns what it scheduled, if anything.
            local function load(isLogin, isReload)
                queued = nil
                local scheduled = ns.OpenOnLoginIfWanted(isLogin, isReload)
                return scheduled, queued
            end

            local function done(msg)
                C_Timer.After = realAfter
                ns.SetOpenOnLogin(false)
                return msg
            end

            ns.SetOpenOnLogin(false)
            if load(true, false) then return done("opened on login with the setting off") end

            ns.SetOpenOnLogin(true)
            if load(false, false) then return done("opened on a zone change") end
            if not load(false, true) then return done("did not open on a /reload") end

            local scheduled, open = load(true, false)
            if not (scheduled and open) then return done("nothing was scheduled on login") end
            open()
            if not ns.Shell:IsOpen() then return done("the window never opened") end
            local page = ns.Shell._lastPage
            if page ~= "home" then
                return done("opened on " .. tostring(page) .. ", not the dashboard")
            end

            -- Already open, so a second load must leave it alone rather
            -- than re-mounting the page underneath the player.
            local reopened = false
            local hook = ns.OpenTo
            ns.OpenTo = function(...) reopened = true; return hook(...) end
            local _, again = load(true, false)
            if again then again() end
            ns.OpenTo = hook
            if reopened then return done("reopened a window that was already up") end

            ns.Shell:Close()
            return done("ok:shut when off, shut through a door, open on the dashboard on login and reload")
        end
    """)(ns)
    if login and str(login).startswith("ok:"):
        print("  ok   open on login: %s" % str(login)[3:])
    else:
        print("  FAIL open on login: %s" % login)
        failures.append(("open on login", str(login)))

    # The gale moves you, and where it moves you is the mechanic.
    #
    # "Stack between the wind and the cyst" is not a position check --
    # standing still and being scored is what the old version did. The
    # gale has to CARRY you: into the cyst if you were in its corridor,
    # which bursts and throws you back toward the boss, and into the rim
    # if you were not. So this drives one gale twice and looks at where
    # the player was left, because a knockback that scores correctly and
    # moves nobody would pass a scoring test and teach nothing.
    gale = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate

            --- Play until the first gale lands with the player parked
            --- either in its corridor or well off the axis, then let the
            --- knockback finish and report where they were left.
            local function ride(inCorridor)
                T:Start("sisterrag", false)
                S.countdown = 0
                local settle, credited, dist0 = nil, nil, nil
                for step = 1, math.ceil(160 / 0.05) do
                    S.hp = 100
                    if S.bossActor then S.bossActor.hp = S.bossActor.maxHp end

                    local wind
                    if not settle then
                        for _, a in ipairs(S.actors) do
                            if a.kind == "place" and a.tunnel then
                                S.px, S.py = a.tunnel.cx, a.tunnel.cy
                            elseif a.kind == "stack" then
                                S.px, S.py = 0, 0
                            elseif a.kind == "wind" and a.tunnel and a.ux then
                                wind = a
                                if inCorridor then
                                    -- The middle of the room, which is on
                                    -- the line from the tunnel to its cyst.
                                    S.px, S.py = 0, 0
                                else
                                    -- The same way down the room, 30 units
                                    -- off the axis: not stacked.
                                    S.px, S.py = -a.uy * 30, a.ux * 30
                                end
                            end
                        end
                    end

                    local wasResolved = wind and wind.resolved
                    local p0, f0 = S.passed, S.failed
                    update(f, 0.05)

                    if wind and wind.resolved and not wasResolved then
                        credited = S.passed > p0
                        if not credited and S.failed == f0 then
                            return nil, "the gale neither credited nor faulted"
                        end
                        dist0 = math.sqrt(S.px * S.px + S.py * S.py)
                        settle = step + 20   -- let the push play out
                    end
                    if settle and step >= settle then
                        return {
                            credited = credited,
                            moved = math.abs(math.sqrt(S.px * S.px + S.py * S.py) - dist0),
                            out = math.sqrt(S.px * S.px + S.py * S.py),
                        }
                    end
                    if not S.running and S.phaseIndex < #(S.phases or {}) then
                        S.running, S.hp = true, 100
                    end
                    if not S.running then break end
                end
                T:Stop()
                return nil, "no gale ever landed"
            end

            local rode, err = ride(true)
            if err then return err end
            local wide, err2 = ride(false)
            if err2 then return err2 end
            T:Stop()

            if not rode.credited then
                return "standing in the corridor was not credited"
            end
            if wide.credited then
                return "standing 30 units off the axis was credited anyway"
            end
            if rode.moved < 5 then
                return string.format(
                    "the gale credited but barely moved anyone (%.0f units)", rode.moved)
            end
            if wide.out <= rode.out then
                return string.format(
                    "off the line left you at %.0f and riding it left you at %.0f -- the wrong way round",
                    wide.out, rode.out)
            end
            return string.format("ok:rode it to %.0f from centre, blown wide to %.0f",
                rode.out, wide.out)
        end
    """)(ns)
    if gale and str(gale).startswith("ok:"):
        print("  ok   trainer gale: the wind carries you -- into the cyst, or into the rim (%s)"
              % str(gale)[3:])
    else:
        print("  FAIL trainer gale: %s" % gale)
        failures.append(("trainer gale", str(gale)))

    # The raid plays to the assignment, not to instinct.
    #
    # The guides split soaks into groups and are explicit about why:
    # soaking Ravenous Feast leaves +800% damage from the NEXT pop, so
    # everybody piling into all three is the wipe rather than the safe
    # play. The raid AI was doing exactly that, and it looked fine --
    # circles full of allies always look right.
    #
    # An UNGROUPED soak is a whole-raid soak and everybody should still
    # go, so both halves of the rule are checked.
    tactics = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate

            -- Who is GOING to it, not who happens to be standing in it.
            --
            -- The geometric version could not tell an assignment from a
            -- coincidence: Ravenous Feast is sixteen units across and
            -- lands on the raid, and once allies started being pushed
            -- clear of the boss's cone they drifted through soaks they
            -- were never assigned. The AI records its own intent now.
            local function inSoak(act)
                local n = 0
                for _, a in ipairs(S.allies) do
                    if a.goalSoak == act then n = n + 1 end
                end
                return n
            end

            -- Seeded, for the same reason the sustained-fire check is:
            -- every check here shares one RNG stream, and this one turns
            -- on whether an ally happened to be assigned a soak during a
            -- sampled window. Editing Nek'zali's intermission re-rolled
            -- it and it failed on four bosses it does not touch.
            math.randomseed(20260817)
            local mostInGrouped, mostInOpen = 0, 0
            -- The Sentinels and the Coiled Altar are in this list for
            -- the CONTROL half of it.
            --
            -- Debilitating Miasma and Guillotine are the only plain
            -- whole-raid soaks left in the raid: once Mutilate and
            -- Ravenous Feast gained their marks, every soak on the two
            -- fights this check used to sample was either grouped or
            -- split, and "everybody still goes to an ungrouped one" had
            -- nothing left to be true of.
            for _, id in ipairs({ "twinfangs", "sisterrag", "sentinels",
                                  "alteredfangs", "vashnik", "explorers" }) do
                T:Start(id, false)
                S.countdown = 0
                local budget = 0
                for _, ph in ipairs(ns.RaidTrainerScenarios[id].phases) do
                    budget = budget + (ph.duration or 45)
                end
                for _ = 1, math.ceil((budget + 40) / 0.05) do
                    S.hp, S.stacks, S.energy = 100, 0, 0
                    if S.bossActor then S.bossActor.hp = S.bossActor.maxHp end
                    update(f, 0.05)
                    for _, act in ipairs(S.actors) do
                        -- Sampled just BEFORE it lands, not after. A soak
                        -- resolves and dies in the same frame, so by the
                        -- time this loop runs there is nothing left to
                        -- count -- which is why the first version of this
                        -- check reported that nobody ever soaked anything.
                        if act.kind == "soak" and not act.resolved
                            and (S.time - act.born) > (act.cast or 1) * 0.75 then
                            local n = inSoak(act)
                            -- A grouped soak counts however else it is
                            -- tagged -- grouping is what is being
                            -- measured, and Mutilate is both grouped and
                            -- split.
                            --
                            -- The OPEN sample is the fussy one. It is
                            -- the control, and it only means anything
                            -- for a soak the whole raid should go to, so
                            -- a split soak (whoever just took one stays
                            -- out) and a tank soak (one body by
                            -- definition) are both disqualified. Letting
                            -- a marked one in measured the mark working
                            -- and reported it as grouping failing.
                            -- Grouping measured WITHOUT marks in the way.
                            --
                            -- A grouped soak that also marks conflates
                            -- two rules: on the Twin Fangs both group-one
                            -- allies were legitimately still Gorged when
                            -- their pop came round, so the group drew
                            -- nobody and the check read that as grouping
                            -- being broken. Vashnik's Catalyst and the
                            -- Explorers' Mighty Thud are grouped and
                            -- unmarked, which is what this wants.
                            if act.group and not act.marks then
                                if n > mostInGrouped then mostInGrouped = n end
                            elseif not act.group and not act.marks and not act.soakBy then
                                if n > mostInOpen then mostInOpen = n end
                            end
                        end
                    end
                    if not S.running and S.phaseIndex < #(S.phases or {}) then
                        S.running, S.hp = true, 100
                    end
                    if not S.running then break end
                end
                T:Stop()
            end

            -- Compared against an UNGROUPED soak rather than judged
            -- against a fixed number.
            --
            -- Counting bodies inside a circle cannot tell an assignment
            -- from a coincidence: Ravenous Feast is sixteen units across
            -- and lands on the raid, so allies are sometimes simply
            -- standing where it appeared. What is decidable is the
            -- comparison -- if grouping a soak does not draw fewer
            -- people than not grouping one, the groups are doing nothing.
            if mostInGrouped == 0 then
                return "no ally ever took an assigned soak"
            end
            if mostInOpen == 0 then
                return "no ungrouped soak was seen, so there is nothing to compare against"
            end
            if mostInGrouped >= mostInOpen then
                return string.format(
                    "an assigned soak drew %d and an open one %d -- grouping changed nothing",
                    mostInGrouped, mostInOpen)
            end
            return string.format("ok:%d in an assigned soak against %d in an open one",
                mostInGrouped, mostInOpen)
        end
    """)(ns)
    if tactics and str(tactics).startswith("ok:"):
        print("  ok   trainer tactics: soak groups are respected (%s)" % str(tactics)[3:])
    else:
        print("  FAIL trainer tactics: %s" % tactics)
        failures.append(("trainer tactics", str(tactics)))

    # Every mechanic introduces itself.
    #
    # A wave has no cast bar and no telegraph -- it simply slides in from
    # off-screen -- so without a line of text it is an anonymous wall and
    # the player has no way to learn what it was. The complaint from the
    # client was exactly that. Checked for every instant mechanic that
    # can take health off you.
    named = L.eval("""
        function(ns)
            local anon = {}
            for _, boss in ipairs(ns.RaidGuide:Ordered()) do
                local sc = ns.RaidTrainerScenarios[boss.id]
                for pi, ph in ipairs((sc or {}).phases or {}) do
                    for _, ev in ipairs(ph.events or {}) do
                        local instant = (ev.cast or 0) <= 0
                        local hurts = (ev.damage or 0) > 0 or ev.dps or ev.stack
                        -- Orbs and carries draw their own countdown ring,
                        -- and adds are self-evidently things to shoot.
                        local selfEvident = ev.kind == "orb" or ev.kind == "carry"
                            or ev.kind == "chaser" or ev.kind == "stalker"
                            or ev.kind == "caster" or ev.kind == "puddle"
                            or ev.kind == "tax" or ev.kind == "imbibe"
                        if instant and hurts and not selfEvident and not ev.call then
                            anon[#anon + 1] = string.format("%s phase %d: %s (%s)",
                                boss.id, pi, tostring(ev.name), tostring(ev.kind))
                        end
                    end
                end
            end
            if #anon > 0 then return table.concat(anon, "; ") end
            return "ok"
        end
    """)(ns)
    if named == "ok":
        print("  ok   trainer call-outs: every instant mechanic names itself")
    else:
        print("  FAIL trainer call-outs: %s" % named)
        failures.append(("trainer call-outs", str(named)))

    # Nothing is drawn off the floor.
    #
    # Every frontal defaulted to a length of ARENA_R * 2 -- the arena's
    # DIAMETER, measured from wherever the cast started. From the boss in
    # the middle that is twice as far as the wall, so the bars ran out
    # across the corners of the frame, drawn over scenery they could
    # never reach. It looked like a rendering fault rather than a number.
    #
    # Checked by playing every scenario and measuring the far end of each
    # directional mechanic against the arena's radius.
    onfloor = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate
            local R, worst, worstName, checked = 100, 0, nil, 0

            for _, boss in ipairs(ns.RaidGuide:Ordered()) do
                local sc = ns.RaidTrainerScenarios[boss.id]
                if sc then
                    T:Start(boss.id, true)
                    S.countdown = 0
                    local budget = 0
                    for _, ph in ipairs(sc.phases or {}) do
                        budget = budget + (ph.duration or 45)
                    end
                    for _ = 1, math.ceil((budget + 60) / 0.05) do
                        S.hp, S.stacks, S.energy = 100, 0, 0
                        if S.bossActor then S.bossActor.hp = S.bossActor.maxHp end
                        update(f, 0.05)
                        for _, a in ipairs(S.actors) do
                            if (a.kind == "line" or a.kind == "beam") and a.len and a.dir then
                                checked = checked + 1
                                local ex = a.x + math.cos(a.dir) * a.len
                                local ey = a.y + math.sin(a.dir) * a.len
                                local d = math.sqrt(ex * ex + ey * ey)
                                if d > worst then worst, worstName = d, a.name end
                            end
                        end
                        if not S.running and S.phaseIndex < #(S.phases or {}) then
                            S.running, S.hp = true, 100
                        end
                        if not S.running then break end
                    end
                    T:Stop()
                end
            end

            if checked == 0 then return "no directional mechanics were seen" end
            -- A couple of units of slack for the rounding in the ray
            -- solve; anything real overshoots by tens.
            if worst > R + 3 then
                return string.format("%s reached %.0f units out, past the %d-unit wall",
                    tostring(worstName), worst, R)
            end
            return string.format("ok:%d checked, furthest end %.0f of %d", checked, worst, R)
        end
    """)(ns)
    if onfloor and str(onfloor).startswith("ok:"):
        print("  ok   trainer geometry: %s" % str(onfloor)[3:])
    else:
        print("  FAIL trainer geometry: %s" % onfloor)
        failures.append(("trainer geometry", str(onfloor)))

    # The countdown.
    #
    # Every other trainer check sets S.countdown = 0 to get to the
    # interesting part, so until now nothing exercised the three seconds
    # before a pull at all -- which is exactly where the raid was found
    # opening fire early. Worse, those shots were spawned by a path that
    # runs before UpdateShots, so they were created and shown but never
    # positioned: art on the field before the round existed.
    countdown = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate

            T:Start("soulcoiler", false)
            if S.countdown <= 0 then T:Stop(); return "no countdown to test" end
            local full = S.bossActor.maxHp

            -- Most of the countdown, but not past it.
            local frames = math.floor((S.countdown - 0.4) / 0.05)
            for _ = 1, frames do
                S.firing = true          -- trigger held down through it
                update(f, 0.05)
            end

            if S.countdown <= 0 then T:Stop(); return "the countdown ran out early" end
            if #S.shots > 0 then
                T:Stop()
                return string.format("%d shots were fired during the countdown", #S.shots)
            end
            if S.bossActor.hp < full then
                T:Stop()
                return "the boss took damage before the round started"
            end
            if #S.actors > 0 then
                T:Stop()
                return string.format("%d mechanics spawned during the countdown", #S.actors)
            end

            -- And it does start once the countdown clears.
            for _ = 1, 200 do
                S.hp, S.firing = 100, true
                update(f, 0.05)
            end
            local fired = (#S.shots > 0) or (S.bossActor.hp < full)
            T:Stop()
            if not fired then return "nothing fired after the countdown either" end
            return "ok"
        end
    """)(ns)
    if countdown == "ok":
        print("  ok   trainer countdown: nothing fires or spawns until GO")
    else:
        print("  FAIL trainer countdown: %s" % countdown)
        failures.append(("trainer countdown", str(countdown)))

    # "Try again" on a round that already finished.
    #
    # Every other trainer check starts from a fresh Start on a frame that
    # was never played, which is the one path that is always clean. The
    # bug reported from the client was the other path: finish a round,
    # press the button, and the new fight comes up wearing the last one's
    # leftovers -- a stuck red overlay, sprites still lit where they died,
    # and shots that no longer register. All three are state that Start
    # has to actively clear rather than merely overwrite, and nothing here
    # was exercising it.
    restart = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate

            -- Round one, played to a real finish rather than stopped.
            T:Start("soulcoiler", false)
            S.countdown = 0
            for _ = 1, 3000 do
                S.firing = true
                update(f, 0.05)
                if not S.running then break end
            end
            if S.running then T:Stop(); return "round one never finished" end

            local leftShots = #S.shots
            local leftActors = #S.actors

            -- Round two, from the button's own code path.
            T:Start("soulcoiler", false)
            if #S.shots > 0 then
                T:Stop()
                return string.format("%d shots carried into the new round", #S.shots)
            end
            if #S.actors > 0 then
                T:Stop()
                return string.format("%d mechanics carried into the new round", #S.actors)
            end
            if S.firing then T:Stop(); return "the trigger was still held" end
            if S.hp ~= 100 then T:Stop(); return "health did not reset" end
            if not S.bossActor or S.bossActor.hp ~= S.bossActor.maxHp then
                T:Stop()
                return "the boss came back already damaged, or absent"
            end

            -- And the thing the report was actually about: do attacks
            -- still land in round two?
            S.countdown = 0
            local before = S.bossActor.hp
            for _ = 1, 300 do
                S.hp, S.firing = 100, true
                update(f, 0.05)
                if not S.running then break end
            end
            local dealt = before - S.bossActor.hp
            T:Stop()
            if dealt <= 0 then
                return "shots did no damage at all in the round after a restart"
            end
            return string.format("ok:%d/%d left behind, %d damage dealt after restart",
                leftShots, leftActors, dealt)
        end
    """)(ns)
    if restart and str(restart).startswith("ok:"):
        print("  ok   trainer restart: clean state and attacks land again (%s)"
              % str(restart)[3:])
    else:
        print("  FAIL trainer restart: %s" % restart)
        failures.append(("trainer restart", str(restart)))

    # The layout solver itself.
    #
    # Everything that measures text rests on this, and when it was wrong
    # it was wrong QUIETLY: a guide card about 530 wide in game resolved
    # to 168, so paragraphs wrapped three times too often, every measured
    # height inflated to match, and no check noticed because they all
    # compared inflated numbers against each other.
    #
    # Two claims, because the failure had two halves. Widths must come
    # out near the truth, and heights must respond to how much text there
    # actually is -- a stub that returns a constant satisfies neither and
    # looks fine from the outside.
    solver = L.eval("""
        function(ns)
            local UI = ns.RaidGuideUI
            if not (UI and UI.BuildInto) then return "no guide UI" end
            local host = CreateFrame("Frame")
            host:SetSize(760, 520)
            YippYappHelperDB = { raidGuide = { boss = "soulcoiler", role = "DAMAGER" } }
            UI:BuildInto(host); UI:Refresh(); UI:SetPage(1)

            local card = (UI._cards or {})[1]
            if not card then return "no cards drawn" end
            local w = card:GetWidth()

            -- The reading column is the host minus the rail, its gutter
            -- and a scrollbar, so a card lands somewhere near two thirds
            -- of the page. Generous bounds on purpose: this is guarding
            -- against 168 and against a constant, not pinning a pixel.
            if w < host:GetWidth() * 0.45 then
                return string.format(
                    "a guide card resolved to %.0f of a %.0f page -- widths are"
                    .. " collapsing again", w, host:GetWidth())
            end
            if w > host:GetWidth() then
                return string.format("a guide card resolved to %.0f, wider than its"
                    .. " %.0f page", w, host:GetWidth())
            end

            -- And height has to follow the text. Same font, same width,
            -- one string much longer than the other.
            local fs = host:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetWidth(200)
            fs:SetText("short")
            local lo = fs:GetStringHeight()
            fs:SetText(string.rep("a good deal more text than that ", 12))
            local hi = fs:GetStringHeight()
            if not (hi > lo * 2) then
                return string.format(
                    "a string twelve times longer measured %.0f against %.0f --"
                    .. " wrapping is not reaching the height", hi, lo)
            end

            -- Wrap off means one line however long it is.
            fs:SetWordWrap(false)
            local flat = fs:GetStringHeight()
            if flat >= hi then
                return "SetWordWrap(false) still measured as wrapped"
            end
            return string.format("ok:card %.0f of %.0f page; %.0f -> %.0f as text grows,"
                .. " %.0f with wrap off", w, host:GetWidth(), lo, hi, flat)
        end
    """)(ns)
    if solver and str(solver).startswith("ok:"):
        print("  ok   layout solver: %s" % str(solver)[3:])
    else:
        print("  FAIL layout solver: %s" % solver)
        failures.append(("layout solver", str(solver)))

    # Glued string joins.
    #
    # Long guide lines are written as "..." .. "..." across several source
    # lines, and if the first half does not end with a space the two words
    # run together -- "reaches" .. "the cavity" renders as "reachesthe
    # cavity". Nothing else here would ever catch it: the string is valid,
    # the layout is fine, the page renders, and it is only wrong to a
    # reader. Found by rewriting eight DPS blocks with a generator that
    # forgot the trailing space.
    glued = []
    for rel in LC_DATA_FILES:
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            continue
        lines = open(path, encoding="utf-8-sig").read().splitlines()
        for i in range(len(lines) - 1):
            nxt = lines[i + 1].lstrip()
            if not nxt.startswith('.. "'):
                continue
            cur = lines[i].rstrip()
            if not cur.endswith('"'):
                continue
            before = cur[:-1]
            after = nxt[4:]
            if before and after and before[-1].isalpha() and after[0].isalpha():
                glued.append("%s:%d  ...%s | %s..."
                             % (rel, i + 1, before[-18:], after[:18]))
    if glued:
        print("  FAIL glued joins: %d place(s) run two words together" % len(glued))
        for g in glued[:5]:
            print("       %s" % g)
        failures.append(("glued joins", glued[0]))
    else:
        print("  ok   no glued string joins in the guide data")

    # Vashnik's altars. The claim is that WHERE THE PLAYER STANDS decides
    # which two altars empower, via a raid that follows them -- so the
    # test walks the player to one altar, checks it lit, walks them to
    # another, and checks the empowerment actually moved. A system that
    # ranked altars but never changed its answer would look identical on
    # screen until someone tried to steer it.
    altars = L.eval("""
        function(ns)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate

            T:Start("vashnik", false)
            S.countdown = 0
            if not S.altars or #S.altars ~= 3 then
                T:Stop(); return "vashnik has no altars"
            end

            local function settle(target, frames)
                for _ = 1, frames do
                    S.hp, S.firing = 100, false
                    -- Toxic Vapor held at zero for the same reason the
                    -- player's health and the boss's are: this check is
                    -- about which altars empower, and it drives a player
                    -- who never shoots. Now that leaked adds feed the
                    -- bar, that player fills it and wipes -- the round
                    -- ended before the check reached its own subject,
                    -- and reported that Imbibe spawned nothing.
                    S.energy = 0
                    if S.bossActor then S.bossActor.hp = S.bossActor.maxHp end
                    -- Parked on the altar; the raid should lean after us.
                    S.px, S.py = target.x * 0.75, target.y * 0.75
                    update(f, 0.05)
                end
            end
            local function stacksOf(alt) return alt.stacks end
            -- Exactly one empowered, one half, one dormant -- always,
            -- wherever the raid is standing.
            local function shapeIsWrong()
                local counts = { [0] = 0, [1] = 0, [2] = 0 }
                for _, alt in ipairs(S.altars) do
                    counts[alt.stacks] = (counts[alt.stacks] or 0) + 1
                end
                if counts[2] ~= 1 or counts[1] ~= 1 or counts[0] ~= 1 then
                    return string.format("altar stacks came out %d at +2, %d at +1, %d dormant",
                        counts[2], counts[1], counts[0])
                end
                return nil
            end

            -- The TANK's route decides which pair is lit, not the player.
            --
            -- This check used to walk the player to an altar and assert
            -- the empowerment followed them. That was the old design and
            -- it was wrong about the fight: the boss trailed the player
            -- around the room and the guide's rotation never happened,
            -- because nothing drove it but where somebody wandered. He
            -- is walked a fixed route between the fountains now, so what
            -- is worth asserting is that the pair actually ROTATES and
            -- that every fountain gets a turn at being the dormant one.
            local dormant, bad = {}, nil
            for _ = 1, 1400 do
                S.hp, S.firing, S.energy = 100, false, 0
                if S.bossActor then S.bossActor.hp = S.bossActor.maxHp end
                S.px, S.py = 0, -80
                update(f, 0.05)
                bad = bad or shapeIsWrong()
                for _, alt in ipairs(S.altars) do
                    if alt.stacks == 0 then dormant[alt.name] = true end
                end
                if not S.running then break end
            end
            local rested = 0
            for _ in pairs(dormant) do rested = rested + 1 end
            if bad then T:Stop(); return "on the tank's route: " .. bad end
            if rested < 3 then
                T:Stop()
                return string.format(
                    "only %d of 3 fountains ever went dormant -- the route is not rotating",
                    rested)
            end

            -- And Imbibe must pay out only in the schools lit AT THE
            -- TIME, judged when each mechanic first appears.
            --
            -- Snapshotting the lit pair once and checking every actor
            -- against it was fine while the player parked next to an
            -- altar and nothing moved. The tank now walks a rotation, so
            -- an add spawned perfectly legally from a then-lit fountain
            -- is still on the floor after the route has moved on -- and
            -- the old form read that as a dormant altar firing.
            local spawned, wrongSchool = 0, nil
            local seen = {}
            for _ = 1, 700 do
                S.hp, S.firing = 100, false
                S.energy = 0
                if S.bossActor then S.bossActor.hp = S.bossActor.maxHp end
                S.px, S.py = 0, -80
                update(f, 0.05)
                local litNow = {}
                for _, alt in ipairs(S.altars) do
                    if alt.stacks > 0 then litNow[alt.school] = true end
                end
                for _, act in ipairs(S.actors) do
                    -- Only what Imbibe itself put on the floor.
                    --
                    -- A Clotting Venom splits when killed, and its
                    -- halves arrive whenever that happens -- which is
                    -- routinely after the tank has walked on and blood
                    -- has gone dormant. They are children of a spawn
                    -- that was legal at the time, not a dormant fountain
                    -- firing.
                    if act.fromImbibe and not seen[act] then
                        seen[act] = true
                        spawned = spawned + 1
                        if not litNow[act.school] then wrongSchool = act.school end
                    end
                end
                if not S.running then break end
            end
            T:Stop()

            if spawned == 0 then return "Imbibe never spawned anything" end
            if wrongSchool then
                return "a dormant altar's " .. wrongSchool .. " mechanic spawned anyway"
            end
            return "ok"
        end
    """)(ns)
    if altars == "ok":
        print("  ok   trainer altars: empowerment follows the raid, and only lit altars spawn")
    else:
        print("  FAIL trainer altars: %s" % altars)
        failures.append(("trainer altars", str(altars)))

    if guns and str(guns).startswith("ok:"):
        print("  ok   trainer: raid alone lands %s damage; held fire finishes the boss"
              % str(guns)[3:])
    else:
        print("  FAIL trainer shooting: %s" % guns)
        failures.append(("trainer shooting", str(guns)))

    # ------------------------------------------------------------
    # The generated guide data is normalised before it ships.
    # ------------------------------------------------------------
    # Read as text rather than through Lua on purpose: this is a check on
    # the SCRAPER's output, and the failure it guards against is a future
    # regenerate that skips canonical_sources. That would put "The Coiled
    # Alter" back beside "The Coiled Altar" -- displaying a misspelling
    # and sorting one place as two, both silently.
    import difflib as _difflib
    _guide = os.path.join(ROOT, "Features", "Gear", "ClassGuideData.lua")
    try:
        _raw = open(_guide, encoding="utf-8", errors="replace").read()
    except OSError as exc:
        _raw = None
        print("  FAIL guide data: %s" % exc)
        failures.append(("guide data", str(exc)))
    if _raw:
        _fields = re.findall(r'source = "([^"]*)"', _raw)
        _segs = {}
        for _f in _fields:
            for _part in _f.split("/"):
                _part = _part.strip()
                if _part:
                    _segs[_part] = _segs.get(_part, 0) + 1
        _bad = []
        for _f in _fields:
            if "(Raid)" in _f:
                _bad.append("%r still carries (Raid)" % _f)
            if "|" in _f:
                _bad.append("%r still carries a pipe, which is a FontString escape" % _f)

        def _key(n):
            n = n.lower().replace("’", "'").replace("'", "")
            return re.sub(r"^the\s+", "", n).strip()

        # Anything the scraper would have merged must already be merged.
        _names = sorted(_segs, key=lambda n: -_segs[n])
        for _i, _a in enumerate(_names):
            for _b in _names[_i + 1:]:
                _r = _difflib.SequenceMatcher(None, _key(_a), _key(_b)).ratio()
                if _r >= 0.88:
                    _bad.append("%r (%d) and %r (%d) are the same place at %.3f"
                                % (_a, _segs[_a], _b, _segs[_b], _r))
        # And the corrections that no ratio could have made.
        for _wrong in ("Nymrissa Wavebinder",):
            if _wrong in _segs:
                _bad.append("%r is the guides' misspelling; the journal says otherwise"
                            % _wrong)
        if _bad:
            for _b in _bad[:6]:
                print("  FAIL guide sources: %s" % _b)
            failures.append(("guide sources", _bad[0]))
        else:
            print("  ok   guide sources: %d fields, %d distinct places, one spelling each"
                  % (len(_fields), len(_segs)))

    return failures


if __name__ == "__main__":
    sys.exit(1 if main() else 0)
