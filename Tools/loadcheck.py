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
import re
import sys
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
Region.__index = function(t, k)
    local f = rawget(Region, k)
    if f then return f end
    -- Only CamelCase names get the no-op. A frame's DATA fields must
    -- still read as nil, or idioms like `self._scripts or {}` get a
    -- function instead of a table and the harness invents its own bugs
    -- instead of finding the addon's.
    if type(k) == "string" and k:match("^%u") then
        return function(self, ...) return self end
    end
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
-- Only the common case: both a left-ish and a right-ish anchor onto the
-- same parent. Anything else falls back, so a resolved number is either
-- right or absent, never invented.
local function edgeX(pts, side)
    for _, p in ipairs(pts or {}) do
        local point = tostring(p.p or "")
        if point:find(side, 1, true) or point == side then
            return p.x, p.rel
        end
    end
    return nil
end

function Region.GetWidth(self)
    if self._w then return self._w end
    local lx, lrel = edgeX(self._pts, "LEFT")
    local rx, rrel = edgeX(self._pts, "RIGHT")
    if lx and rx then
        local parent = lrel or rrel or self._parent
        if parent and parent ~= self and parent.GetWidth then
            local pw = parent:GetWidth()
            if pw and pw > 0 then
                local w = pw + rx - lx
                if w > 0 then return w end
            end
        end
    end
    return 700
end
function Region.GetHeight(self) return self._h or 480 end
function Region.GetSize(self) return self:GetWidth(), self:GetHeight() end
function Region.SetWidth(self, w) self._w = w; return self end
function Region.SetHeight(self, h) self._h = h; return self end
function Region.SetSize(self, w, h) self._w = w; self._h = h; return self end
function Region.GetFrameLevel(self) return self._lvl or 1 end
function Region.SetFrameLevel(self, l) self._lvl = l; return self end
function Region.GetStringHeight(self) return 12 end
function Region.GetStringWidth(self) return 60 end
function Region.GetText(self) return self._text or "" end
function Region.SetText(self, t) self._text = t; return self end
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
    return self
end
function Region.ClearAllPoints(self) self._pts = nil; return self end
function Region.IsObjectType(self, t) return t == self._type end
function Region.GetObjectType(self) return self._type or "Frame" end
function Region.GetRegions(self) return end
function Region.GetChildren(self) return end
function Region.GetScript(self) return nil end
function Region.SetScript(self, e, fn) self._scripts = self._scripts or {}; self._scripts[e] = fn; return self end
function Region.GetLeft(self) return 0 end
function Region.GetNormalTexture(self) return NewRegion("Texture") end
function Region.GetParent(self) return self._parent end
function Region.GetAttribute(self) return nil end
function Region.GetNumPoints(self) return 0 end
function Region.GetPoint(self) return "TOPLEFT", nil, "TOPLEFT", 0, 0 end

function NewRegion(kind, parent)
    local r = setmetatable({ _type = kind or "Frame", _parent = parent }, Region)
    return r
end

function Region.CreateTexture(self, n, layer) return NewRegion("Texture", self) end
function Region.CreateFontString(self, n, layer) return NewRegion("FontString", self) end
function Region.CreateMaskTexture(self) return NewRegion("MaskTexture", self) end
function Region.CreateAnimationGroup(self) return NewRegion("AnimationGroup", self) end

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
function GetRealmName() return "Realm" end
function GetSpecialization() return 1 end
function GetSpecializationInfo() return 102, "Balance", "", 136096, "DAMAGER" end
function GetSpecializationInfoByID() return 102, "Balance", "", 136096, "DAMAGER" end
function GetItemInfo() return nil end
function GetInventoryItemID() return nil end
function GetInventoryItemLink() return nil end
function GetDetailedItemLevelInfo() return 0 end
function InCombatLockdown() return false end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function IsModifiedClick() return false end
function GetTime() return 0 end
function time() return 0 end
function date() return "2026-08-16" end
function print() end
function geterrorhandler() return function() end end
function hooksecurefunc() end
function tinsert(t, ...) return table.insert(t, ...) end
function tremove(t, ...) return table.remove(t, ...) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function strsplit(sep, s) return s end
function strjoin(sep, ...) return table.concat({ ... }, sep) end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function format(...) return string.format(...) end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
function GetLocale() return "enUS" end
function C_Timer_After() end
function SetPortraitTexture() end
function SetPortraitToTexture() end
function PlaySound() end
function securecall(fn, ...) if fn then return fn(...) end end
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
C_PartyInfo = { GetInviteConfirmationInvalidQueues = function() return {} end }
C_UIWidgetManager = {}
C_Reputation = {}
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end }
C_Calendar = {}
C_DateAndTime = { GetCurrentCalendarTime = function()
                      return { year = 2026, month = 8, monthDay = 16,
                               hour = 12, minute = 0 } end,
                  GetServerTimeLocal = function() return 0 end }

NineSliceUtil = { ApplyLayoutByName = function() end }

-- ── C_* namespaces ──────────────────────────────────────────
C_Timer = { After = function() end, NewTimer = function() return NewRegion() end,
            NewTicker = function() return NewRegion() end }
C_Item = { GetItemIconByID = function() return 134400 end,
           RequestLoadItemDataByID = function() end,
           GetItemInfoInstant = function() return nil end,
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
    local known = { ["ui-journeys-renown-divider"] = true,
                    ["ui-journeys-renown-button"] = true,
                    ["perks-list-mask"] = true }
    return known[a] and { width = 64, height = 16 } or nil
end }
C_Traits = { GetSubTreeInfo = function(_, id)
    return { ID = id, name = "Keeper of the Grove", iconElementID = 5651754,
             isActive = (id == 1), traitTreeID = 1 }
end, GetConfigInfo = function() return { ID = 1 } end }
C_ClassTalents = { GetActiveConfigID = function() return 1 end,
                   GetHeroTalentSpecsForClassSpec = function() return { 1, 2 } end,
                   GetActiveHeroTalentSpec = function() return 1 end }
C_ChallengeMode = { GetMapUIInfo = function() return "Dungeon", 1, 30, 134400 end,
                    GetMapTable = function() return {} end,
                    GetOwnedKeystoneChallengeMapID = function() return nil end }
C_MythicPlus = { GetOwnedKeystoneLevel = function() return nil end,
                 GetRunHistory = function() return {} end,
                 GetSeasonBestAffixScoreInfoForMap = function() return nil end,
                 RequestMapInfo = function() end,
                 GetCurrentAffixes = function() return {} end }
C_WeeklyRewards = { GetActivities = function() return {} end,
                    HasAvailableRewards = function() return false end }
C_CurrencyInfo = { GetCurrencyInfo = function()
                       return { name = "C", quantity = 0, iconFileID = 134400 } end,
                   GetCurrencyListSize = function() return 0 end }
C_EncounterJournal = { GetInstanceInfo = function() return "Instance" end }
C_AddOns = { GetAddOnMetadata = function() return "3.0.6" end,
             IsAddOnLoaded = function() return true end,
             LoadAddOn = function() return true end }
C_UnitAuras = { GetAuraDataByIndex = function() return nil end }
C_Map = { GetBestMapForUnit = function() return 1 end }
C_TooltipInfo = { GetItemByID = function() return nil end }
C_PlayerInfo = { GetName = function() return "Tester" end }
C_Widget = { IsFrameWidget = function() return true end }
C_ScriptedAnimations = {}
C_Social = {}
C_LFGList = {}
Enum = setmetatable({}, { __index = function() return setmetatable({}, {
    __index = function() return 1 end }) end })
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
        ("SetLootBrowserAppMode",     True, 760, 520),
        ("SetRaidAppMode",            True, 760, 520),
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

    def report(label, boxes, region_w):
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
    report("BiS stat priority cards", parse(pool_rects(bis_pool, bis_n)), None)

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

    return failures


if __name__ == "__main__":
    sys.exit(1 if main() else 0)
