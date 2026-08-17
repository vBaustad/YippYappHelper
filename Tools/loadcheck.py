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
function Region.SetText(self, t) self._text = t; return self end
-- A crude proxy for font metrics: no real glyph widths here, but code
-- that lays out against measured text has to get SOMETHING that grows
-- with the string, or every such branch collapses to its zero case and
-- reads as tested. Colour escapes do not occupy space.
function Region.GetStringWidth(self)
    local t = (self._text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return #t * 8
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
                     return { name = "Valeera Sanguinar", reaction = "Trusty Delve Companion",
                              standing = 1700, reactionThreshold = 1500,
                              nextThreshold = 2500 }
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
C_DateAndTime = { GetCurrentCalendarTime = function()
                      return { year = 2026, month = 8, monthDay = 16,
                               hour = 12, minute = 0 } end,
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
C_Traits = { GetSubTreeInfo = function(_, id)
    return { ID = id, name = "Keeper of the Grove", iconElementID = 5651754,
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
    [152] = { "Challenger's Peril",
              "Each player death subtracts 15 seconds from the dungeon timer." },
    [148] = { "Xal'atath's Guile",
              "Xal'atath assaults the party with a barrage of shadow energy." },
}

C_ChallengeMode = { GetMapUIInfo = function(id)
                        -- Unknown ids keep the old generic answer; other
                        -- pages pass ids that are not this season's.
                        return (MPLUS_MAPS[id] or "Dungeon"), id or 1, 1800, 134400
                    end,
                    GetMapTable = function() return MPLUS_ORDER end,
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
                 -- Ten, against a card that shows eight: the overflow
                 -- line is a branch too, and a silent truncation is
                 -- exactly the kind of thing that should not pass.
                 GetRunHistory = function()
                     local out = {}
                     for i = 1, 10 do
                         out[i] = { mapChallengeModeID = MPLUS_ORDER[((i - 1) % 8) + 1],
                                    level = 15 - i,
                                    completed = (i % 4 ~= 0),
                                    runWeek = 1, thisWeek = true }
                     end
                     return out
                 end,
                 GetSeasonBestAffixScoreInfoForMap = function() return nil end,
                 RequestMapInfo = function() end,
                 GetCurrentAffixes = function()
                     return { { id = 9, seasonID = 1 }, { id = 152, seasonID = 1 },
                              { id = 148, seasonID = 1 } }
                 end }
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
    -- One weekly-capped currency, part-earned, so the checklist's
    -- automatic branch resolves to a real "not done yet" rather than
    -- falling through to a manual tick and looking the same either way.
    { name = "Restored Coffer Key", currencyID = 3512, quantity = 0,
      weekly = { earned = 2, cap = 6 } },
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
    report("BiS stat priority cards", parse(pool_rects(bis_pool, bis_n)), None)

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
                # No region width: the cards live in a scroll frame whose
                # width the stub reports as the page's, and overlap is
                # the claim worth making here.
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
            local h = (boss and boss.lust) and (UI._lustText:GetStringHeight() or 12) or 0
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
            local P = ns.Planner
            if not (P and P.BuildPlan) then return "no planner" end
            local ok, built = pcall(P.BuildPlan, P)
            if not ok then return "BuildPlan failed: " .. tostring(built) end
            local items = (built and built.items) or {}
            if #items == 0 then return "the plan came back empty" end

            local upgrade
            for _, it in ipairs(items) do
                if tostring(it.title or ""):match("reward %d+ to %d+") then upgrade = it end
            end
            if not upgrade then
                return "nothing in the plan offers to improve a reward"
            end
            -- A currency threshold the client cannot be asked about, so
            -- the number is written down and the currency is found by
            -- NAME -- a guessed id reads zero rather than erroring, and
            -- would turn this into a confidently wrong suggestion.
            local accolade
            for _, it in ipairs(items) do
                if tostring(it.title or ""):match("Field Accolade") then accolade = it end
            end
            if not accolade then
                return "nothing in the plan mentions Field Accolades"
            end
            -- 483 banked against 750 in the fixture: 267 short.
            if not accolade.title:match("267") then
                return "accolades read '" .. accolade.title .. "'; expected 267 short"
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
            if not upgrade.title:match("302") then
                return "upgrade reads '" .. upgrade.title .. "'; expected the item level it buys"
            end
            -- Delves must stay silent: the client returns no data for
            -- them, and a made-up rung would be worse than nothing.
            for _, it in ipairs(items) do
                if it.category == "world" and tostring(it.title):match("reward %d+ to %d+") then
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

            -- And the empty state: no companion must not mean level 0.
            local realGet = ns.Delves.GetCompanion
            ns.Delves.GetCompanion = function() return nil end
            local ok3 = pcall(page.Refresh, { content = host, width = 700, height = 620 })
            ns.Delves.GetCompanion = realGet
            if not ok3 then return "refresh failed with no companion" end
            local txt = tostring(ui.compCard.level:GetText() or "")
            if txt:match("0") then
                return "an unknown companion rendered as level '" .. txt .. "'"
            end
            return "ok"
        end
    """)(ns)
    if delves == "ok":
        print("  ok   delves: companion read as a friendship rank, ladder shared "
              "with Progression, empty state honest")
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

            -- Coffer keys are detected from the client's own weekly
            -- counter, not asked about and not measured against a number
            -- copied from a guide. The fixture has 2 of 6 earned, so
            -- this must come back automatic AND outstanding: automatic
            -- but "done" would pass just as happily on a lookup that
            -- silently found nothing.
            local keys
            for _, r in ipairs(rows) do
                if r.id == "cur:3512" then keys = r end
            end
            if not keys then
                return "a weekly-capped currency did not become a checklist row"
            end
            -- Discovery finds what the client caps, which is not the
            -- same as what is worth doing. A row the player hides must
            -- stay hidden, and hiding must refuse the fixed items -- a
            -- filter that could delete deliberate content is a settings
            -- screen, not a nuisance filter.
            if Wk:Hide("crests") then
                return "a fixed checklist item could be hidden"
            end
            if not Wk:Hide("cur:3512") then
                return "a discovered row refused to be hidden"
            end
            local stillThere = false
            for _, r in ipairs(Wk:GetList()) do
                if r.id == "cur:3512" then stillThere = true end
            end
            if stillThere then return "a hidden row came back" end
            Wk:UnhideAll()
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

            if not tostring(keys.label):match("Restored Coffer Key") then
                return "the discovered row reads '" .. tostring(keys.label)
                    .. "'; it should carry the name the client gave it"
            end
            if keys.manual then
                return "coffer keys fell back to a manual tick; the weekly counter was not read"
            end
            if keys.done then
                return "coffer keys read as done at 2 of 6 earned"
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
        print("  ok   weekly: manual ticks stick, expire at reset, and cannot "
              "override what the client knows")
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
                if not sc then
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

            -- And reaching the partner is worth something.
            local before = S.passed
            for _ = 1, 400 do
                S.hp, S.firing = 100, false
                S.px, S.py = meet.target.x, meet.target.y
                for _, b in ipairs(S.bossActors) do b.hp = b.maxHp end
                update(f, 0.05)
                if meet.dead or S.phaseIndex > 2 then break end
                if not S.running then break end
            end
            local credited = S.passed > before
            T:Stop()
            if not credited then
                problems[#problems + 1] =
                    "standing on the correct partner scored nothing"
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
            local function play(follow)
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
                            if (a.kind == "place" or a.kind == "wind") and a.tunnel then
                                S.px, S.py = a.tunnel.cx, a.tunnel.cy
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
            return string.format("ok:%d cysts placed, %d misses against %d",
                good.placed, good.missed, bad.missed)
        end
    """)(ns)
    if twostage and str(twostage).startswith("ok:"):
        print("  ok   trainer cysts: placing them is what makes the wind survivable (%s)"
              % str(twostage)[3:])
    else:
        print("  FAIL trainer cysts: %s" % twostage)
        failures.append(("trainer cysts", str(twostage)))

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
            for _, id in ipairs({ "twinfangs", "sisterrag", "sentinels", "alteredfangs" }) do
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
                            if act.group then
                                if n > mostInGrouped then mostInGrouped = n end
                            elseif not act.marks and not act.soakBy then
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

            settle(S.altars[1], 220)
            if stacksOf(S.altars[1]) ~= 2 then
                T:Stop()
                return string.format("stood at the %s altar and it took %d stacks, not 2",
                    S.altars[1].name, stacksOf(S.altars[1]))
            end
            local bad = shapeIsWrong()
            if bad then T:Stop(); return "at the first altar: " .. bad end

            settle(S.altars[2], 220)
            if stacksOf(S.altars[2]) ~= 2 then
                T:Stop()
                return string.format("walked to the %s altar but %s still held the empowerment",
                    S.altars[2].name, S.altars[1].name)
            end

            bad = shapeIsWrong()
            if bad then T:Stop(); return "at the second altar: " .. bad end

            -- And Imbibe must actually pay out, in the schools that are lit.
            local lit = {}
            for _, alt in ipairs(S.altars) do
                if alt.stacks > 0 then lit[alt.school] = true end
            end
            local spawned, wrongSchool = 0, nil
            for _ = 1, 700 do
                S.hp, S.firing = 100, false
                S.energy = 0
                if S.bossActor then S.bossActor.hp = S.bossActor.maxHp end
                S.px, S.py = S.altars[2].x * 0.75, S.altars[2].y * 0.75
                update(f, 0.05)
                for _, act in ipairs(S.actors) do
                    if act.school and (act.kind == "chaser" or act.kind == "dodge") then
                        spawned = spawned + 1
                        if not lit[act.school] then wrongSchool = act.school end
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

    return failures


if __name__ == "__main__":
    sys.exit(1 if main() else 0)
