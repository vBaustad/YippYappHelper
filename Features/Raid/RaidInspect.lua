local _, ns = ...

------------------------------------------------------------
-- Tier set slots (equipment slot IDs)
------------------------------------------------------------
local TIER_SLOTS = {
    { slot = 1,  name = "Head"     },
    { slot = 3,  name = "Shoulder" },
    { slot = 5,  name = "Chest"    },
    { slot = 7,  name = "Legs"     },
    { slot = 10, name = "Hands"    },
}

------------------------------------------------------------
-- Hidden tooltip for scanning set bonus text
------------------------------------------------------------
local scanTooltip = CreateFrame("GameTooltip", "YYHScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local function IsSetItem(unit, slotID)
    scanTooltip:ClearLines()
    local ok = pcall(scanTooltip.SetInventoryItem, scanTooltip, unit, slotID)
    if not ok then return false end

    for i = 1, scanTooltip:NumLines() do
        local line = _G["YYHScanTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and text:find("Set:") then
                return true
            end
        end
    end
    return false
end

------------------------------------------------------------
-- Raid inspection state
------------------------------------------------------------
ns.RaidInspectData = {}
local inspectQueue = {}
local inspectBusy = false
local inspectTimer = nil
-- Retry buffer for units that failed CanInspect on the first pass
-- (usually out-of-range in the pre-pull staging area). We re-queue
-- them once after the main queue drains, so a player who zoned in
-- late or ran back from the vendor still gets inspected. Retried
-- flag prevents an infinite loop when a player is permanently
-- unreachable (AFK in garrison, different phase, etc.).
local retryQueue = {}
local retriedThisScan = false

-- GUID -> unit token map, rebuilt on roster change. Avoids O(n) scans
-- on every INSPECT_READY which becomes costly in full 30-man raids.
local unitByGUID = {}

local function RefreshUnitByGUID()
    wipe(unitByGUID)
    local playerGUID = UnitGUID("player")
    if playerGUID then unitByGUID[playerGUID] = "player" end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local u = "raid" .. i
            if UnitExists(u) then
                local g = UnitGUID(u)
                if g then unitByGUID[g] = u end
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do
            local u = "party" .. i
            if UnitExists(u) then
                local g = UnitGUID(u)
                if g then unitByGUID[g] = u end
            end
        end
    end
end

local function ProcessNextInspect()
    if #inspectQueue == 0 then
        -- Main queue drained. If any units deferred on the first pass
        -- (out of range, etc.) and we haven't retried yet, flush the
        -- retry buffer back into the queue and keep going.
        if #retryQueue > 0 and not retriedThisScan then
            retriedThisScan = true
            for _, u in ipairs(retryQueue) do
                table.insert(inspectQueue, u)
            end
            wipe(retryQueue)
            ProcessNextInspect()
            return
        end
        inspectBusy = false
        if ns.RefreshRaidDisplay then
            ns:RefreshRaidDisplay()
        end
        return
    end

    inspectBusy = true
    local unit = table.remove(inspectQueue, 1)

    if not UnitExists(unit) or not UnitIsConnected(unit) or not CanInspect(unit) then
        -- Defer to the retry buffer on the first pass; on the retry
        -- pass, drop the unit entirely so a permanently unreachable
        -- player doesn't stall the scan.
        if not retriedThisScan then
            table.insert(retryQueue, unit)
        end
        C_Timer.After(0.1, ProcessNextInspect)
        return
    end

    NotifyInspect(unit)

    -- Timeout fallback in case INSPECT_READY never fires
    if inspectTimer then inspectTimer:Cancel() end
    inspectTimer = C_Timer.NewTimer(2, function()
        ProcessNextInspect()
    end)
end

-- Event handler for inspect results
local inspectFrame = CreateFrame("Frame")
inspectFrame:RegisterEvent("INSPECT_READY")
inspectFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
inspectFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
inspectFrame:SetScript("OnEvent", function(self, event, guid)
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        RefreshUnitByGUID()
        return
    end
    if event ~= "INSPECT_READY" then return end

    local unit = unitByGUID[guid]
    -- Fallback: roster may have changed between NotifyInspect and the
    -- reply. Refresh once and retry before giving up.
    if not unit or not UnitExists(unit) or UnitGUID(unit) ~= guid then
        RefreshUnitByGUID()
        unit = unitByGUID[guid]
    end

    if unit then
        local name = UnitName(unit)
        local _, class = UnitClass(unit)
        local tierCount = 0
        local tierSlots = {}

        for _, tierSlot in ipairs(TIER_SLOTS) do
            local hasSet = IsSetItem(unit, tierSlot.slot)
            if hasSet then
                tierCount = tierCount + 1
                table.insert(tierSlots, tierSlot.name)
            end
        end

        -- Capture spec + ilvl in the same inspect pass so consumers don't
        -- have to issue a second NotifyInspect for them.
        local specID = GetInspectSpecialization and GetInspectSpecialization(unit) or 0
        local ilvl   = 0
        if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
            ilvl = C_PaperDollInfo.GetInspectItemLevel(unit) or 0
        end

        ns.RaidInspectData[guid] = {
            name = name,
            class = class,
            tierCount = tierCount,
            tierSlots = tierSlots,
            unit = unit,
            guid = guid,
            specID = specID,
            ilvl = ilvl,
        }

        -- Update display if visible
        if ns.RaidFrame and ns.RaidFrame:IsShown() then
            ns:RefreshRaidDisplay()
        end
    end

    if inspectTimer then inspectTimer:Cancel() end
    C_Timer.After(0.3, ProcessNextInspect)
end)

------------------------------------------------------------
-- Start a full raid scan
------------------------------------------------------------
function ns:ScanRaid()
    wipe(ns.RaidInspectData)
    wipe(inspectQueue)
    wipe(retryQueue)
    retriedThisScan = false

    local numMembers = GetNumGroupMembers()

    -- Add player first
    local playerGUID = UnitGUID("player")
    local playerName = UnitName("player")
    local _, playerClass = UnitClass("player")
    local playerTier = 0
    local playerSlots = {}
    for _, tierSlot in ipairs(TIER_SLOTS) do
        if IsSetItem("player", tierSlot.slot) then
            playerTier = playerTier + 1
            table.insert(playerSlots, tierSlot.name)
        end
    end

    -- The player's own data reads from equipped gear directly; no inspect needed.
    local playerSpecID = 0
    if GetSpecialization and GetSpecializationInfo then
        local idx = GetSpecialization()
        if idx then playerSpecID = select(1, GetSpecializationInfo(idx)) or 0 end
    end
    local playerIlvl = 0
    if GetAverageItemLevel then
        local _, equipped = GetAverageItemLevel()
        playerIlvl = equipped or 0
    end
    ns.RaidInspectData[playerGUID] = {
        name = playerName,
        class = playerClass,
        tierCount = playerTier,
        tierSlots = playerSlots,
        unit = "player",
        guid = playerGUID,
        specID = playerSpecID,
        ilvl = playerIlvl,
    }

    -- Queue everyone else
    local prefix = IsInRaid() and "raid" or "party"
    if IsInRaid() then
        for i = 1, numMembers do
            local unit = prefix .. i
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                table.insert(inspectQueue, unit)
            end
        end
    else
        for i = 1, numMembers - 1 do
            local unit = prefix .. i
            if UnitExists(unit) then
                table.insert(inspectQueue, unit)
            end
        end
    end

    print("|cff00ff00YippYapp Helper|r: Scanning " .. (#inspectQueue + 1) .. " players (tier, spec, iLvl, gear quality)...")

    if ns.RaidFrame then
        ns:RefreshRaidDisplay()
        ns.RaidFrame:Show()
    end

    ProcessNextInspect()
end

------------------------------------------------------------
-- Get sorted tier data (fewest pieces first = highest loot prio)
------------------------------------------------------------
function ns:GetSortedTierData()
    local sorted = {}
    for guid, data in pairs(ns.RaidInspectData) do
        table.insert(sorted, data)
    end
    table.sort(sorted, function(a, b)
        if a.tierCount ~= b.tierCount then
            return a.tierCount > b.tierCount
        end
        return a.name < b.name
    end)
    return sorted
end

------------------------------------------------------------
-- Tier distribution summary
------------------------------------------------------------
function ns:GetTierSummary()
    local counts = { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0 }
    local total = 0
    local with2set = 0
    local with4set = 0

    for _, data in pairs(ns.RaidInspectData) do
        local c = data.tierCount
        counts[c] = (counts[c] or 0) + 1
        total = total + 1
        if c >= 2 then with2set = with2set + 1 end
        if c >= 4 then with4set = with4set + 1 end
    end

    return {
        counts = counts,
        total = total,
        with2set = with2set,
        with4set = with4set,
    }
end
