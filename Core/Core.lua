local addonName, ns = ...

ns.upgradeVendorOpen = false

ns.SLOT_IDS = {
    { slot = 1,  name = "Head",      anchor = "TOPLEFT",  x = 24,  y = -78  },
    { slot = 2,  name = "Neck",      anchor = "TOPLEFT",  x = 24,  y = -118 },
    { slot = 3,  name = "Shoulder",  anchor = "TOPLEFT",  x = 24,  y = -158 },
    { slot = 15, name = "Back",      anchor = "TOPLEFT",  x = 24,  y = -198 },
    { slot = 5,  name = "Chest",     anchor = "TOPLEFT",  x = 24,  y = -238 },
    { slot = 9,  name = "Wrist",     anchor = "TOPLEFT",  x = 24,  y = -278 },
    { slot = 10, name = "Hands",     anchor = "TOPRIGHT", x = -24, y = -78  },
    { slot = 6,  name = "Waist",     anchor = "TOPRIGHT", x = -24, y = -118 },
    { slot = 7,  name = "Legs",      anchor = "TOPRIGHT", x = -24, y = -158 },
    { slot = 8,  name = "Feet",      anchor = "TOPRIGHT", x = -24, y = -198 },
    { slot = 11, name = "Ring 1",    anchor = "TOPRIGHT", x = -24, y = -238 },
    { slot = 12, name = "Ring 2",    anchor = "TOPRIGHT", x = -24, y = -278 },
    { slot = 13, name = "Trinket 1", anchor = "TOPLEFT",  x = 24,  y = -318 },
    { slot = 14, name = "Trinket 2", anchor = "TOPRIGHT", x = -24, y = -318 },
    { slot = 16, name = "Main Hand", anchor = "BOTTOMLEFT",  x = 24,  y = 60   },
    { slot = 17, name = "Off Hand",  anchor = "BOTTOMRIGHT", x = -24, y = 60   },
}

------------------------------------------------------------
-- Hidden tooltip for scanning upgrade track info
------------------------------------------------------------
local upgradeScanTooltip = CreateFrame("GameTooltip", "YYHUpgradeScanTooltip", nil, "GameTooltipTemplate")
upgradeScanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Cache tooltip scan results; invalidated on UNIT_INVENTORY_CHANGED
local scanCache = {}
function ns:InvalidateScanCache()
    wipe(scanCache)
end

local function ScanUpgradeTrack(slotID)
    -- Return cached result if available
    if scanCache[slotID] then
        return scanCache[slotID].track, scanCache[slotID].rank, scanCache[slotID].maxRank, scanCache[slotID].crafted
    end
    upgradeScanTooltip:ClearLines()
    local ok = pcall(upgradeScanTooltip.SetInventoryItem, upgradeScanTooltip, "player", slotID)
    if not ok then return nil, nil, nil, false end

    local foundTrack, foundRank, foundMax
    local isCrafted = false

    -- A tooltip with no lines means the item data was not ready, not that
    -- the item has no upgrade track. Caching that would be permanent
    -- (the cache only clears on inventory change), and now that
    -- CanUpgradeItem refuses to guess a track, a cached blank would hide
    -- a genuinely upgradeable item until the player swapped gear.
    local numLines = upgradeScanTooltip:NumLines()
    if numLines == 0 then
        return nil, nil, nil, false
    end

    for i = 1, numLines do
        local line = _G["YYHUpgradeScanTooltipTextLeft" .. i]
        if line then
            local text = line:GetText() or ""
            -- Match "Upgrade Level: Champion 3/5" or similar
            if not foundTrack then
                local trackName, currRank, maxRank = text:match("Upgrade Level:%s+(%S+)%s+(%d+)/(%d+)")
                if trackName then
                    foundTrack = trackName
                    foundRank = tonumber(currRank)
                    foundMax = tonumber(maxRank)
                end
            end
            -- Detect crafted items: quality tier atlas icons (Professions-Icon-Quality-*)
            -- or crafted-by line
            if text:find("Professions%-Icon%-Quality") or text:find("Professions%-ChatIcon%-Quality") then
                isCrafted = true
            end
        end
    end

    scanCache[slotID] = { track = foundTrack, rank = foundRank, maxRank = foundMax, crafted = isCrafted }
    return foundTrack, foundRank, foundMax, isCrafted
end

-- Returns item info for an equipment slot
function ns:GetSlotInfo(slotID)
    local itemLink = GetInventoryItemLink("player", slotID)
    if not itemLink then
        return nil
    end

    local icon = GetInventoryItemTexture("player", slotID)
    local itemLevel = 0
    local itemQuality = 1

    -- Try multiple APIs for item level
    local itemLocation = ItemLocation:CreateFromEquipmentSlot(slotID)
    if C_Item.DoesItemExist(itemLocation) then
        local ok, lvl = pcall(C_Item.GetCurrentItemLevel, itemLocation)
        if ok and lvl then
            itemLevel = lvl
        end
        local ok2, qual = pcall(C_Item.GetItemQuality, itemLocation)
        if ok2 and qual then
            itemQuality = qual
        end
    end

    -- Fallback to GetDetailedItemLevelInfo
    if itemLevel == 0 then
        local ok, lvl = pcall(GetDetailedItemLevelInfo, itemLink)
        if ok and lvl then itemLevel = lvl end
    end

    -- Scan tooltip for actual upgrade track and crafted status
    local trackName, currRank, maxRank, isCrafted = ScanUpgradeTrack(slotID)

    return {
        link = itemLink,
        ilvl = itemLevel,
        quality = itemQuality,
        icon = icon,
        track = trackName,
        rank = currRank,
        maxRank = maxRank,
        crafted = isCrafted,
    }
end

-- Check if an item can be upgraded
-- Returns: canUpgrade (bool), upgradeInfo table { currUpgrade, maxUpgrade, track, currIlvl, maxIlvl }
function ns:CanUpgradeItem(slotID)
    local info = ns:GetSlotInfo(slotID)
    if not info then return false, nil end

    local ilvl = info.ilvl
    if not ilvl or ilvl == 0 then return false, nil end

    -- The tooltip's "Upgrade Level: <Track> n/m" line is the ONLY
    -- trustworthy source for an item's track.
    --
    -- We used to fall back to guessing the track from item level when
    -- that line was missing. That is actively wrong across a season
    -- boundary: last season's gear has its upgrade track stripped at
    -- patch launch, so it has no line — and its item level happily lands
    -- inside a current-season band. A locked Season 1 Mythic 272 piece
    -- was being read as Season 2 "Adventurer 3/6" and recommended for
    -- upgrade. No line means the item cannot be upgraded with crests,
    -- which is exactly what the game's own upgrade UI enforces.
    if not info.track or not ns.GEAR_TRACKS[info.track] then
        return false, nil, "notrack"
    end

    local track   = info.track
    local rank    = info.rank
    local maxRank = info.maxRank

    if not rank or not maxRank then return false, nil, "notrack" end

    -- Track names repeat every season, so a stale line would still parse.
    -- Cross-check the item level against what this track/rank should be;
    -- if they disagree the item is not on the current season's track.
    --
    -- Only enforced below max rank: an Ascendant Venomstone pushes a
    -- fully upgraded piece above its track's top item level while the
    -- tooltip still reads "6/6", and that item is legitimately done.
    --
    -- The "mismatch" reason is surfaced in the UI and /yh debug rather
    -- than swallowed: if ns.GEAR_TRACKS ever carries a wrong number, this
    -- guard would quietly hide real upgrades, and a visible label makes
    -- that diagnosable instead of mysterious.
    local levels = ns.GEAR_TRACKS[track]
    if rank < maxRank and levels and levels[rank] and levels[rank] ~= ilvl then
        return false, nil, "mismatch"
    end

    local maxIlvl = ns:GetMaxIlvlForTrack(track)
    local canUpgrade = rank < maxRank

    return canUpgrade, {
        currUpgrade = rank,
        maxUpgrade = maxRank,
        track = track,
        currIlvl = ilvl,
        maxIlvl = maxIlvl,
    }
end

-- GetDetailedItemLevelInfo moved under C_Item in newer clients; the
-- diagnostics below must not error on either.
local function SafeItemLevel(link)
    if not link then return nil end
    local fn = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
    if not fn then return nil end
    local ok, lvl = pcall(fn, link)
    return ok and lvl or nil
end
ns.SafeItemLevel = SafeItemLevel

------------------------------------------------------------
-- Launcher macro ("/yh"), used by the drag-to-actionbar handle.
--
-- Deliberately does NOT consult MAX_ACCOUNT_MACROS. That global lives
-- with Blizzard_MacroUI, which is LoadOnDemand — at login it is nil, and
-- comparing a number against it threw
--   "attempt to compare number with nil"
-- which aborted macro creation entirely. That is why the drag handle had
-- nothing to pick up.
--
-- Instead: try to create it and check whether it actually appeared. That
-- is correct whether or not the constant exists, and covers a full macro
-- list without needing to know the cap.
------------------------------------------------------------
local MACRO_NAME = "YippYapp"
local MACRO_ICON = 1998635
local MACRO_BODY = "/yh"

function ns:EnsureLauncherMacro(verbose)
    if InCombatLockdown() then
        if verbose then
            print("|cff00ff00YippYapp Helper|r: Can't touch macros in combat.")
        end
        return nil
    end

    local idx = GetMacroIndexByName(MACRO_NAME)
    if idx and idx > 0 then
        pcall(EditMacro, idx, MACRO_NAME, MACRO_ICON, MACRO_BODY)
        return idx
    end

    -- perCharacter = false -> account macro
    pcall(CreateMacro, MACRO_NAME, MACRO_ICON, MACRO_BODY, false)
    idx = GetMacroIndexByName(MACRO_NAME)
    if idx and idx > 0 then return idx end

    if verbose then
        print("|cff00ff00YippYapp Helper|r: Couldn't create the /yh macro — "
            .. "your macro list is probably full. Type |cff00ff00/yh|r instead.")
    end
    return nil
end

-- Send an equipped item directly into the upgrade window
function ns:SendItemToUpgrade(slotID)
    -- Protected APIs below (PickupInventoryItem, button :Click()); the
    -- upgrade vendor can't open in combat in practice, but guard anyway
    -- since the right-click path into this function bypasses the caller's
    -- combat check.
    if InCombatLockdown() then return end
    if not ns.upgradeVendorOpen then
        print("|cff00ff00YippYapp Helper|r: Upgrade vendor is not open.")
        return
    end

    local itemLocation = ItemLocation:CreateFromEquipmentSlot(slotID)
    if not C_Item.DoesItemExist(itemLocation) then return end

    if C_ItemUpgrade and C_ItemUpgrade.SetItemUpgradeFromLocation then
        C_ItemUpgrade.SetItemUpgradeFromLocation(itemLocation)
    else
        ClearCursor()
        PickupInventoryItem(slotID)
        if ItemUpgradeFrame and ItemUpgradeFrame.ItemSlot then
            ItemUpgradeFrame.ItemSlot:Click()
        elseif ItemUpgradeFrame then
            local slot = ItemUpgradeFrame.LeftItemFrame or ItemUpgradeFrame.ItemButton
            if slot then
                slot:Click()
            end
        end
        ClearCursor()
    end
end

------------------------------------------------------------
-- High-water mark: query the game for the highest ilvl ever
-- reached in a slot. Upgrades below this are free (0 crests).
-- The API may only work when the upgrade vendor is open,
-- so we cache results for use when the vendor is closed.
------------------------------------------------------------
ns.watermarkCache = {}

local function QueryWatermark(slotID)
    if not C_ItemUpgrade then return 0 end

    local itemLocation = ItemLocation:CreateFromEquipmentSlot(slotID)
    if not C_Item.DoesItemExist(itemLocation) then return 0 end

    -- Try item-based watermark first
    if C_ItemUpgrade.GetHighWatermarkForItem then
        local ok, charMark, accountMark = pcall(C_ItemUpgrade.GetHighWatermarkForItem, itemLocation)
        if ok then
            local mark = math.max(charMark or 0, accountMark or 0)
            if mark > 0 then return mark end
        end
    end

    -- Fallback: slot-based watermark
    if C_ItemUpgrade.GetHighWatermarkSlotForItem and C_ItemUpgrade.GetHighWatermarkForSlot then
        local ok1, redundancySlot = pcall(C_ItemUpgrade.GetHighWatermarkSlotForItem, itemLocation)
        if ok1 and redundancySlot then
            local ok2, charMark, accountMark = pcall(C_ItemUpgrade.GetHighWatermarkForSlot, redundancySlot)
            if ok2 then
                return math.max(charMark or 0, accountMark or 0)
            end
        end
    end

    return 0
end

-- Refresh all watermarks (call when upgrade vendor opens)
function ns:RefreshWatermarks()
    for _, slotInfo in ipairs(ns.SLOT_IDS) do
        local mark = QueryWatermark(slotInfo.slot)
        if mark > 0 then
            ns.watermarkCache[slotInfo.slot] = mark
        end
    end
end

function ns:GetFreeUpgradeIlvl(slotID)
    -- Try live query first
    local mark = QueryWatermark(slotID)
    if mark > 0 then
        ns.watermarkCache[slotID] = mark
        return mark
    end
    -- Fall back to cached value
    return ns.watermarkCache[slotID] or 0
end

-- Anchor the helper frame relative to upgrade vendor or free-floating
function ns:AnchorFrame()
    local f = ns.MainFrame
    if not f then return end

    f:ClearAllPoints()

    if ns.upgradeVendorOpen and ItemUpgradeFrame and ItemUpgradeFrame:IsShown() then
        f:SetPoint("TOPLEFT", ItemUpgradeFrame, "TOPRIGHT", 2, 0)
    else
        f:SetPoint("CENTER")
    end
end

------------------------------------------------------------
-- Initialization & Events
------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
-- Actually spending crests on an upgrade fires this and nothing else the
-- addon was listening for, so the sheet you just upgraded from sat
-- stale.
eventFrame:RegisterEvent("ITEM_UPGRADE_MASTER_UPDATE")
-- Loot landing in your bags. The Best in Slot page counts bags towards
-- "collected", so a piece dropping has to redraw it. DELAYED rather than
-- BAG_UPDATE: the latter fires once per bag per change.
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
-- The dashboard and Mr. Yeeper both report vault progress, and the vault
-- filling is not signalled by anything else the addon listens for.
eventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")

local ITEM_UPGRADE_INTERACTION = Enum.PlayerInteractionType.ItemUpgrade
local characterFrameHooked = false

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        YippYappHelperDB = YippYappHelperDB or {}

        -- Restore previous raid scan (with type validation)
        if type(YippYappHelperDB.raidInspect) == "table" then
            ns.RaidInspectData = YippYappHelperDB.raidInspect
        end

        -- Validate discounts table
        if YippYappHelperDB.discounts and type(YippYappHelperDB.discounts) ~= "table" then
            YippYappHelperDB.discounts = nil
        end

        -- Drop settings belonging to features removed in 2.9.0 so they
        -- don't linger in the SavedVariables file forever.
        for _, dead in ipairs({
            -- lastSeenVersion is NOT in this list: the old welcome notice
            -- was removed in 2.9.0 and its key purged, but 2.13.0 brought
            -- the notice back. Purging it here would reset the "already
            -- seen" flag on every login and show the popup every time.
            "xaltoes", "lura", "nexusKingInterrupt", "piAssignments",
            "raidSplit", "releaseBlocker",
        }) do
            YippYappHelperDB[dead] = nil
        end

        print("|cff00ff00YippYapp Helper|r loaded \226\128\148 type |cff00ff00/yh|r to open")

        -- Create or update the /yh macro
        C_Timer.After(2, function()
            ns:EnsureLauncherMacro()
        end)

        -- Read from the TOC rather than hardcoded. It was duplicated
        -- here and in WhatsNew, which is two strings that have to be
        -- bumped together and only ever get bumped once -- and Yeeper's
        -- introduction keys off this value, so a stale copy quietly
        -- replays or suppresses the intro at the wrong moment.
        ns.ADDON_VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata
            and C_AddOns.GetAddOnMetadata("YippYappHelper", "Version")) or "3.0.0"

        -- Suppress CharacterFrame when upgrade vendor is open
        -- (our slot buttons handle equipping instead)
        if CharacterFrame and not characterFrameHooked then
            CharacterFrame:HookScript("OnShow", function()
                if ns.upgradeVendorOpen then
                    HideUIPanel(CharacterFrame)
                end
            end)
            characterFrameHooked = true
        end

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and arg1 == ITEM_UPGRADE_INTERACTION then
        ns.upgradeVendorOpen = true

        -- Cache watermarks while vendor is open (API may require it)
        ns:RefreshWatermarks()

        if ns.MainFrame then
            -- Un-parent from the app if currently embedded
            if ns.MainFrame.inAppMode then
                ns.MainFrame.inAppMode = nil
                if ns.SetGearAppMode then ns:SetGearAppMode(false) end
                ns.MainFrame:SetParent(UIParent)
                -- Navigate the app away from the gear page
                if ns.AppFrame and ns.AppFrame:IsShown() and ns.currentAppPage == "gear" then
                    ns:ShowAppPage("home")
                end
            end
            ns:RefreshAllSlots()
            ns:RefreshCrests()
            ns:AnchorFrame()
            ns.MainFrame:Show()
        end

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" and arg1 == ITEM_UPGRADE_INTERACTION then
        ns.upgradeVendorOpen = false
        if ns.MainFrame then
            ns.MainFrame:Hide()
        end

    elseif event == "UNIT_INVENTORY_CHANGED" and arg1 == "player" then
        -- Always invalidate tooltip cache when gear changes
        ns:InvalidateScanCache()
        -- Item data lands a moment after the event, so anything scanned
        -- right now is stale. Invalidate a second time next to the
        -- redraw rather than before it.
        C_Timer.After(0.3, function()
            ns:InvalidateScanCache()
            if ns.upgradeVendorOpen and ns.RefreshWatermarks then
                ns:RefreshWatermarks()
            end
            -- Was gated on MainFrame being shown, so equipping a piece
            -- while on the app's Gear Upgrades page changed nothing.
            ns:RefreshGearViews()
        end)
    elseif event == "CURRENCY_DISPLAY_UPDATE"
        or event == "ITEM_UPGRADE_MASTER_UPDATE"
        or event == "BAG_UPDATE_DELAYED"
        or event == "WEEKLY_REWARDS_UPDATE"
        or event == "CHALLENGE_MODE_COMPLETED" then
        ns:RefreshGearViews()
    end
end)

SLASH_YIPPYAPPHELPER1 = "/yh"
SLASH_YIPPYAPPHELPER2 = "/yippyapp"
------------------------------------------------------------
-- Refreshing what is on screen
--
-- Crests, gear and upgrades are shown in several places, and the old
-- handler only refreshed two of them: the standalone upgrade sheet, and
-- the app's home page. Anyone sitting on the Gear Upgrades page inside
-- the app -- which is where you are when you spend crests -- saw nothing
-- change until they navigated away and back.
--
-- Routing every state change through one function means a new page only
-- has to be added here once, rather than to each event handler.
------------------------------------------------------------
local gearRefreshPending = false

function ns:RefreshGearViews()
    -- Debounced. BAG_UPDATE_DELAYED and CURRENCY_DISPLAY_UPDATE can
    -- arrive together when loot and crests land from the same source,
    -- and a full slot rebuild per event is wasteful.
    if gearRefreshPending then return end
    gearRefreshPending = true

    C_Timer.After(0.2, function()
        gearRefreshPending = false

        if ns.MainFrame and ns.MainFrame:IsShown() then
            if ns.RefreshCrests then ns:RefreshCrests() end
            if ns.RefreshAllSlots then ns:RefreshAllSlots() end
        end

        if not (ns.AppFrame and ns.AppFrame:IsShown()) then return end
        local page = ns.currentAppPage

        if page == "home" then
            if ns._refreshDashboard then ns._refreshDashboard() end
        elseif page == "gear" then
            if ns.RefreshAllSlots then ns:RefreshAllSlots() end
            if ns.RefreshCrests then ns:RefreshCrests() end
        end
        -- The Best in Slot page is not listed here on purpose: it owns
        -- its own watcher in Features/Gear/BisUI.lua, which already
        -- covers equipment, spec and bags. Two mechanisms redrawing one
        -- page is how they drift apart.
    end)
end

------------------------------------------------------------
-- Module toggles
--
-- Core/BlizzSettings.lua registers a checkbox per module and reads it
-- through these two. Neither was ever implemented, so opening the
-- Blizzard settings panel threw "attempt to call a nil value" on every
-- module row -- the settings page has never worked.
--
-- The two features that honour the flag guard with
-- `if ns.ModuleEnabled and not ns.ModuleEnabled(...)`, so the missing
-- function left them permanently on and the failure only showed up in
-- the settings UI.
--
-- Absent means ENABLED. A module nobody has touched should run, and the
-- checkbox defaults to on to match.
------------------------------------------------------------
function ns.ModuleEnabled(module)
    if not module then return true end
    local db = YippYappHelperDB and YippYappHelperDB.modules
    local stored = db and db[module]
    if stored == nil then return true end
    return stored and true or false
end

function ns.SetModuleEnabled(module, enabled)
    if not module then return end
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.modules = YippYappHelperDB.modules or {}
    YippYappHelperDB.modules[module] = enabled and true or false
end

SlashCmdList["YIPPYAPPHELPER"] = function(msg)
    msg = strtrim(msg or "")
    local cmd, arg = strsplit(" ", msg, 2)
    cmd = strlower(cmd or "")

    -- /yh help
    if cmd == "help" then
        print("|cff00ff00=== YippYapp Helper ===|r")
        print("  /yh — open dashboard")
        print("  /yh raid — scan raid/party for tier pieces")
        print("  /yh mplus — open Mythic+ helper")
        print("  /yh loot — open loot browser")
        print("  /yh profile — show/set player profile")
        print("  /yh profile <name> — set profile (normal, heroic, mythic)")
        print("  /yh discount <track> — toggle crest discount for a track (adventurer, veteran, champion, hero, myth)")
        print("  /yh discounts — show current discount status")
        print("  /yh brez — Battle Res Timer options")
        print("  /yh whatsnew — what changed this patch")
        print("  /yh fun — fun stat counters (/yh fun reset to clear)")
        print("  /yh introreset — replay Mr. Yeeper's introduction")
        print("  /yh edit — move YippYapp frames via Edit Mode")
        print("  /yh icon [size] [x] [y] — tune the minimap icon fit")
        print("  /yh debug — dump slot data to chat")
        return
    end

    -- /yh whatsnew — reopen the update notice
    if cmd == "whatsnew" then
        if ns.WhatsNew then ns.WhatsNew:Show() end
        return
    end

    -- /yh advisor — what the bot would say, plus the facts behind it
    if cmd == "advisor" then
        if ns.Advisor then ns.Advisor:Print() end
        return
    end

    -- /yh introreset — replay Mr. Yeeper's introduction
    if cmd == "introreset" then
        if ns.Advisor and ns.Advisor.ResetIntro then
            ns.Advisor:ResetIntro()
            print("|cff00ff00YippYapp|r Yeeper's introduction will replay from the "
                .. "start, one line per visit to the home screen.")
        end
        return
    end

    -- /yh fun — print the fun stat counters
    if cmd == "fun" then
        if ns.FunStats then
            if arg and strtrim(arg) == "reset" then ns.FunStats:Reset()
            else ns.FunStats:Print() end
        end
        return
    end

    -- /yh editdebug — why a frame has no Edit Mode outline
    if cmd == "editdebug" then
        if ns.EditModeDebug then ns.EditModeDebug()
        else print("|cffff5555YippYapp:|r LibEditMode not loaded") end
        return
    end

    -- /yh edit — open Edit Mode (or unlock frames if it is unavailable)
    if cmd == "edit" then
        if ns.EditMode then ns.EditMode:Open() end
        return
    end

    -- /yh icon [size] [offsetX] [offsetY] — dial in the minimap ring fit
    if cmd == "icon" then
        if ns.TuneMinimapIcon then
            local s, x, y = strsplit(" ", strtrim(arg or ""))
            ns:TuneMinimapIcon(tonumber(s), tonumber(x), tonumber(y))
        end
        return
    end

    -- /yh raid
    if cmd == "raid" then
        if ns.AppFrame then
            ns:ToggleApp()
            if ns.AppFrame:IsShown() then
                ns:ShowAppPage("raid")
            end
        elseif ns.RaidFrame then
            if ns.RaidFrame:IsShown() then
                ns.RaidFrame:Hide()
            else
                ns.RaidFrame:Show()
                if ns.RefreshRaidOverview then ns:RefreshRaidOverview() end
            end
        end
        return
    end

    -- /yh profile [name]
    if cmd == "profile" then
        if arg and strtrim(arg) ~= "" then
            local profileId = strlower(strtrim(arg))
            local found = false
            for _, profile in ipairs(ns.PROFILES) do
                if profile.id == profileId then
                    YippYappHelperDB.profile = profileId
                    print("|cff00ff00YippYapp Helper|r: Profile set to |cffffffff" .. profile.name .. "|r")
                    found = true
                    break
                end
            end
            if not found then
                print("|cff00ff00YippYapp Helper|r: Unknown profile. Options:")
                for _, p in ipairs(ns.PROFILES) do
                    print("  " .. p.id .. " — " .. p.name)
                end
            else
                -- Refresh if window is open
                if ns.MainFrame and ns.MainFrame:IsShown() then
                    ns:RefreshAllSlots()
                    ns:RefreshCrests()
                end
            end
        else
            local current = ns:GetCurrentProfile()
            print("|cff00ff00YippYapp Helper|r: Current profile: |cffffffff" .. current.name .. "|r")
            print("  Spend freely: " .. table.concat(current.freeCrests, ", "))
            print("  Precious: " .. table.concat(current.preciousCrests, ", "))
            print("Available profiles:")
            for _, p in ipairs(ns.PROFILES) do
                local marker = p.id == current.id and " |cff00ff00(active)|r" or ""
                print("  " .. p.id .. " — " .. p.name .. marker)
            end
        end
        return
    end

    -- /yh discount <track>
    if cmd == "discount" then
        if not arg or strtrim(arg) == "" then
            print("|cff00ff00YippYapp Helper|r: Usage: /yh discount <track>")
            print("  Tracks: adventurer, veteran, champion, hero, myth")
            return
        end
        local trackName = strtrim(arg)
        -- Capitalize first letter
        trackName = trackName:sub(1,1):upper() .. trackName:sub(2):lower()

        if not ns.GEAR_TRACKS[trackName] then
            print("|cff00ff00YippYapp Helper|r: Unknown track '" .. trackName .. "'")
            return
        end

        YippYappHelperDB.discounts = YippYappHelperDB.discounts or {}
        if YippYappHelperDB.discounts[trackName] then
            YippYappHelperDB.discounts[trackName] = nil
            print("|cff00ff00YippYapp Helper|r: " .. trackName .. " discount |cffff0000removed|r (20 crests per upgrade)")
        else
            YippYappHelperDB.discounts[trackName] = true
            print("|cff00ff00YippYapp Helper|r: " .. trackName .. " discount |cff00ff00enabled|r (10 crests per upgrade)")
        end

        if ns.MainFrame and ns.MainFrame:IsShown() then
            ns:RefreshAllSlots()
        end
        return
    end

    -- /yh discounts
    if cmd == "discounts" then
        print("|cff00ff00=== Crest Costs ===|r")
        for _, trackName in ipairs(ns.TRACK_ORDER) do
            local cost = ns:GetCrestCost(trackName)
            local hasAchieve = ns:HasDiscountAchievement(trackName)
            local db = YippYappHelperDB or {}
            local manualOverride = db.discounts and db.discounts[trackName]
            local source = ""
            if hasAchieve then
                source = " (achievement: " .. trackName .. " of the Dawn)"
            elseif manualOverride then
                source = " (manual override)"
            end
            local discounted = cost == ns.DISCOUNTED_CREST_COST
            local status = discounted
                and "|cff00ff0010 per rank|r" .. source
                or "20 per rank"
            print("  " .. trackName .. ": " .. status)
        end
        print("Use /yh discount <track> to manually toggle discounts")
        return
    end

    -- /yh loot
    if cmd == "loot" then
        if ns.AppFrame then
            ns:ToggleApp()
            if ns.AppFrame:IsShown() then
                ns:ShowAppPage("loot")
            end
        else
            if not ns.LootBrowserFrame then
                ns:CreateLootBrowserFrame()
            end
            if ns.LootBrowserFrame:IsShown() then
                ns.LootBrowserFrame:Hide()
            else
                ns:LootBrowser_DetectSpec()
                ns.LootBrowserFrame:Show()
                ns:LootBrowser_ShowPage()
            end
        end
        return
    end

    -- /yh mplus
    if cmd == "mplus" or cmd == "m+" or cmd == "mythicplus" then
        if ns.AppFrame then
            ns:ToggleApp()
            if ns.AppFrame:IsShown() then
                ns:ShowAppPage("mythicplus")
            end
        elseif ns.MythicPlusFrame then
            if ns.MythicPlusFrame:IsShown() then
                ns.MythicPlusFrame:Hide()
            else
                ns.MythicPlusFrame:Show()
                ns:RefreshMythicPlus()
            end
        end
        return
    end

    -- /yh brez [subcommand] — Battle Res Timer
    if cmd == "brez" or cmd == "battleres" then
        if ns.BattleResTimer and ns.BattleResTimer.HandleSlash then
            ns.BattleResTimer:HandleSlash(arg)
        else
            print("|cff00ff00YippYapp Helper|r: Battle Res Timer module not loaded.")
        end
        return
    end

    -- /yh debug
    if cmd == "debug" then
        print("|cff00ff00=== YippYapp Debug ===|r")
        local profile = ns:GetCurrentProfile()
        print("Profile: " .. profile.name)
        print("Free crests: " .. table.concat(profile.freeCrests, ", "))
        print("Precious crests: " .. table.concat(profile.preciousCrests, ", "))
        for _, trackName in ipairs(ns.TRACK_ORDER) do
            local count = ns:GetCrestCountByTrack(trackName)
            local cost = ns:GetCrestCost(trackName)
            print("  " .. trackName .. ": " .. count .. " crests, " .. cost .. " per upgrade, " .. ns:GetAffordableUpgrades(trackName) .. " upgrades affordable")
        end
        print("--- Equipped Slots ---")
        for _, slotInfo in ipairs(ns.SLOT_IDS) do
            local itemLink = GetInventoryItemLink("player", slotInfo.slot)
            if itemLink then
                local info = ns:GetSlotInfo(slotInfo.slot)
                local canUp, upInfo = ns:CanUpgradeItem(slotInfo.slot)
                local rec, reason = ns:GetRecommendation(slotInfo.slot)
                local upStr = "no data"
                if upInfo then
                    upStr = upInfo.track .. " " .. upInfo.currUpgrade .. "/" .. upInfo.maxUpgrade .. " (ilvl " .. upInfo.currIlvl .. "->" .. upInfo.maxIlvl .. ")"
                end
                local risk = ns:GetReplacementRisk(slotInfo.slot, info.ilvl)
                local watermark = ns:GetFreeUpgradeIlvl(slotInfo.slot)
                local wmStr = watermark > 0 and ("wm:" .. watermark) or "wm:none"
                print(string.format("  %s: %s | %s | risk: %s | %s | %s",
                    slotInfo.name, upStr, wmStr, risk, rec.label, reason))
            end
        end
        return
    end

    -- Default: toggle app
    if ns.ToggleApp then
        ns:ToggleApp()
    elseif ns.ToggleDashboard then
        ns:ToggleDashboard()
    end
end
