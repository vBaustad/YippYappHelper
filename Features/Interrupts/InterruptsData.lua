local _, ns = ...

------------------------------------------------------------
-- Interrupts Data (ExwindTools-style)
--
-- Design principle: never touch party members' secret-tainted
-- spellIDs or GUIDs. We only need two things:
--   1) Unit tokens (party1..4) — untainted, usable directly.
--   2) Nameplate interrupt events — fire reliably.
--
-- Flow:
--   * Player's own UNIT_SPELLCAST_SUCCEEDED → plain spellID (own
--     data isn't secret), look up CD and start timer for self.
--   * Party UNIT_SPELLCAST_SUCCEEDED → ignore spellID entirely,
--     record just `partyCasts[unit] = { t = GetTime() }`.
--   * Nameplate UNIT_SPELLCAST_INTERRUPTED → find the party
--     unit whose cast landed within MATCH_WINDOW of the interrupt,
--     start their CD using the class-default interrupt table.
--
-- Tradeoff: party "air-kicks" (interrupts that don't hit anything)
-- don't register. Same limitation ExwindTools/IntFeed accept in
-- Midnight — no software workaround exists.
------------------------------------------------------------

ns.Interrupts = ns.Interrupts or {}
local I = ns.Interrupts

-- class -> default interrupt spellID (used for rest icon + CD lookup)
I.DEFAULT_INTERRUPT_BY_CLASS = {
    WARRIOR     = 6552,
    ROGUE       = 1766,
    MAGE        = 2139,
    DEATHKNIGHT = 47528,
    PALADIN     = 96231,
    DEMONHUNTER = 183752,
    HUNTER      = 147362,
    DRUID       = 106839,
    SHAMAN      = 57994,
    PRIEST      = 15487,
    MONK        = 116705,
    EVOKER      = 351338,
    WARLOCK     = nil,
}

-- Some classes interrupt with different spells depending on spec, so a
-- single default is wrong for half of them. Druids are the clearest
-- case: Skull Bash is Feral and Guardian, while Balance and Restoration
-- use Solar Beam. Listed most-likely-first for when we cannot ask.
I.INTERRUPT_CANDIDATES = {
    DRUID  = { 78675, 106839 },   -- Solar Beam, Skull Bash
    PRIEST = { 15487 },           -- Silence: Shadow only
}

--- The interrupt to show for a unit.
---
--- For the player we can simply ask the game which one is known, which
--- settles talents and spec in one call. For anyone else the spellbook
--- is not readable without an inspect, so the first candidate stands in
--- until they actually cast something -- at which point the real spell
--- id arrives with the combat log event and replaces it.
function I:GetDefaultInterrupt(class, unit)
    local candidates = self.INTERRUPT_CANDIDATES[class or ""]
    if candidates then
        if not unit or UnitIsUnit(unit, "player") then
            for _, spellID in ipairs(candidates) do
                if IsPlayerSpell and IsPlayerSpell(spellID) then return spellID end
            end
        end
        return candidates[1]
    end
    return self.DEFAULT_INTERRUPT_BY_CLASS[class or ""]
end

-- spellID -> baseline CD (used for player's own direct lookup)
I.SPELLS = {
    [78675]  = 60,  -- Druid: Solar Beam (Balance / Restoration)
    [6552]   = 15,  -- Warrior: Pummel
    [1766]   = 15,  -- Rogue: Kick
    [2139]   = 24,  -- Mage: Counterspell
    [47528]  = 15,  -- Death Knight: Mind Freeze
    [96231]  = 15,  -- Paladin: Rebuke
    [183752] = 15,  -- Demon Hunter: Disrupt
    [187707] = 15,  -- Hunter: Muzzle
    [147362] = 24,  -- Hunter: Counter Shot
    [106839] = 15,  -- Druid (Feral): Skull Bash
    [78675]  = 60,  -- Druid (Balance): Solar Beam
    [57994]  = 12,  -- Shaman: Wind Shear
    [15487]  = 45,  -- Priest: Silence
    [116705] = 15,  -- Monk: Spear Hand Strike
    [351338] = 20,  -- Evoker: Quell
}

------------------------------------------------------------
-- Runtime state
------------------------------------------------------------

-- [unitGUID] = { name=, class=, unit=, spellID=, cdBase=, readyAt=, lastCastAt= }
I.state = {}

-- Per-party-unit last-cast timestamp. Not a ring buffer — we only
-- care about the most recent cast per unit.
-- [unit] = { t = GetTime() }
local partyCasts = {}

local MATCH_WINDOW = 0.15 -- seconds; ExwindTools uses 0.050, we're a
                          -- touch looser to cover high-latency players.

local function now() return GetTime() end

------------------------------------------------------------
-- Public API
------------------------------------------------------------

function I:GetState() return self.state end
function I:GetUnitEntry(guid) return self.state[guid] end

-- Starts (or refreshes) a CD timer for `unit` using `spellID`. Used by:
--   * player's own cast path (spellID is plain)
--   * nameplate attribution (spellID = class-default, plain)
function I:OnFriendlyInterruptCast(unit, spellID)
    local cd = self.SPELLS[spellID]
    if not cd then return end
    local guid = UnitGUID(unit)
    if not guid then return end

    local entry = self.state[guid]
    if not entry then
        local _, class = UnitClass(unit)
        entry = { name = UnitName(unit), class = class, unit = unit }
        self.state[guid] = entry
    end
    entry.unit = unit
    entry.spellID = spellID
    entry.cdBase = cd
    entry.lastCastAt = now()
    entry.readyAt = entry.lastCastAt + (entry.cdOverride or cd)

    if ns.InterruptsUI and ns.InterruptsUI.OnCast then
        ns.InterruptsUI:OnCast(guid, entry)
    end
end

-- When an enemy nameplate cast is interrupted, attribute it to whichever
-- party unit cast something within MATCH_WINDOW of the event. We never
-- read spellID or GUID content — only unit tokens and timestamps.
function I:OnNameplateInterrupted(nameplateUnit)
    local t = now()
    local bestUnit, bestDt
    for unit, rec in pairs(partyCasts) do
        local dt = t - rec.t
        if dt >= 0 and dt <= MATCH_WINDOW and (not bestDt or dt < bestDt) then
            bestUnit, bestDt = unit, dt
        end
    end
    if not bestUnit then
        if self._debug then
            print(("|cff00ff00YYH|r attribute: %s — no party cast in window"):format(tostring(nameplateUnit)))
        end
        return
    end

    local _, class = UnitClass(bestUnit)
    local spellID = self:GetDefaultInterrupt(class, bestUnit)
    if not spellID then return end

    -- Consume the cast so a single kick can't be attributed twice.
    partyCasts[bestUnit] = nil

    if self._debug then
        print(("|cff00ff00YYH|r attribute: %s → %s (%s, dt=%.3f)"):format(
            tostring(nameplateUnit), bestUnit, class or "?", bestDt))
    end

    self:OnFriendlyInterruptCast(bestUnit, spellID)

    if ns.InterruptsUI and ns.InterruptsUI.OnAttributed then
        local guid = UnitGUID(bestUnit)
        ns.InterruptsUI:OnAttributed(guid, nameplateUnit, spellID)
    end
end

------------------------------------------------------------
-- Roster seeding (so UI rows exist before the first cast)
------------------------------------------------------------

function I:RefreshUnitCD(unit) end -- future talent-inspect hook

local function seedRoster()
    for _, u in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
        if UnitExists(u) then
            local guid = UnitGUID(u)
            if guid and not I.state[guid] then
                local _, class = UnitClass(u)
                I.state[guid] = { name = UnitName(u), class = class, unit = u }
            end
        end
    end
end

------------------------------------------------------------
-- Debug helpers
------------------------------------------------------------

I._debug = false
SLASH_YYHINTLOG1 = "/yyhintlog"
SlashCmdList.YYHINTLOG = function()
    I._debug = not I._debug
    print(("|cff00ff00YippYapp|r interrupt log: %s"):format(I._debug and "ON" or "OFF"))
end

------------------------------------------------------------
-- Events
------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player",
                    "party1", "party2", "party3", "party4")
f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")

f:SetScript("OnEvent", function(_, event, ...)
    if ns.InterruptsSettings and ns.InterruptsSettings.Get
        and not ns.InterruptsSettings:Get("enabled") then return end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _castID, spellID = ...

        if unit == "player" then
            -- Own data isn't tainted — direct lookup works.
            local ok, cd = pcall(function() return I.SPELLS[spellID] end)
            if I._debug then
                print(("|cff00ff00YYH|r cast: unit=player spellID=%s hit=%s"):format(
                    tostring(spellID), (ok and cd) and "yes" or "no"))
            end
            if ok and cd then
                I:OnFriendlyInterruptCast("player", spellID)
            end
            return
        end

        -- Party cast — spellID may be secret-tainted. Don't touch it.
        -- Just record that this unit cast something at this time.
        partyCasts[unit] = { t = now() }
        if I._debug then
            print(("|cff00ff00YYH|r cast: unit=%s (timestamp only)"):format(tostring(unit)))
        end

    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit = ...
        if I._debug then
            print(("|cff00ff00YYH|r interrupt: unit=%s"):format(tostring(unit)))
        end
        if unit and type(unit) == "string" and unit:sub(1, 9) == "nameplate" then
            I:OnNameplateInterrupted(unit)
        end

    elseif event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        seedRoster()
        -- Drop I.state entries whose GUIDs are no longer in the party.
        -- Without this the table grows by every unique player seen
        -- across pugs / queue pops over a long session. Keep debug
        -- fakes (prefix "YYH-DEBUG-") so /yyhintdebug stays functional.
        local currentGUIDs = {}
        for _, u in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
            if UnitExists(u) then
                local g = UnitGUID(u)
                if g then currentGUIDs[g] = true end
            end
        end
        for guid in pairs(I.state) do
            if not currentGUIDs[guid] and not (type(guid) == "string" and guid:sub(1, 10) == "YYH-DEBUG-") then
                I.state[guid] = nil
            end
        end
        -- Clear stale party cast timestamps on roster change.
        for u in pairs(partyCasts) do
            if not UnitExists(u) then partyCasts[u] = nil end
        end
    end
end)
