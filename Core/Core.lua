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

------------------------------------------------------------
-- The tooltip lines that mean an item has not bound yet.
--
-- Binding is what marks a slot, and there are two ways it happens:
-- putting the piece on binds it, and so does letting its trade timer
-- run out. Either way the slot has the item level from that moment.
--
-- Which leaves exactly one way not to get the mark, and it is a thing
-- the player has to actively do: hand the piece to somebody else before
-- it binds.
--
-- Which makes "unbound" a state the advisor has to be able to see. A
-- Hero drop sitting in the bags with time left on it has NOT put its
-- item level on the slot, so anything priced against the slot's mark
-- while it sits there is priced against a number that is about to
-- change.
--
-- Read positively, off the two lines that say so, rather than inferred
-- from "this is above the mark, so it must be unbound". That inference
-- is wrong exactly where it would matter most: rings and trinkets share
-- one mark between two slots, so a bound piece can sit above it without
-- ever having been unbound.
--
-- Taken from the client's own globals so this survives a locale, with
-- English fallbacks for the load harness, which has no client strings.
-- Matched on the fixed part before the first substitution.
local UNBOUND_LINES = {}
do
    for _, s in ipairs({
        BIND_TRADE_TIME_REMAINING
            or "You may trade this item with players that were also eligible",
        ITEM_BIND_ON_EQUIP or "Binds when equipped",
    }) do
        local fixed = s:match("^(.-)%%") or s
        -- A format string whose very first token is a substitution
        -- would leave nothing to match on, and a zero-length needle
        -- finds itself in every line.
        if fixed ~= "" then
            UNBOUND_LINES[#UNBOUND_LINES + 1] = fixed
        end
    end
end

--- Read the upgrade line off whatever was last put in the scan tooltip.
---
--- Split out of ScanUpgradeTrack because the same three numbers have to
--- be read off items that are NOT equipped. Every rule in this addon
--- reasoned about sixteen worn pieces, and the one move that spends a
--- cheap crest where an expensive one was wanted is made with a piece
--- sitting in a bag -- see ns:GetBagSpares below.
---
--- nil means the tooltip had no lines at all, which is item data that
--- has not arrived yet rather than an item with no track.
local function ParseUpgradeTooltip()
    -- A tooltip with no lines means the item data was not ready, not that
    -- the item has no upgrade track. Caching that would be permanent
    -- (the cache only clears on inventory change), and now that
    -- CanUpgradeItem refuses to guess a track, a cached blank would hide
    -- a genuinely upgradeable item until the player swapped gear.
    local numLines = upgradeScanTooltip:NumLines()
    if numLines == 0 then
        return nil
    end

    local found = { crafted = false }

    for i = 1, numLines do
        local line = _G["YYHUpgradeScanTooltipTextLeft" .. i]
        if line then
            local text = line:GetText() or ""
            -- Still the player's to give away, which means it has not
            -- marked anything yet. See UNBOUND_LINES for why this is
            -- read off the tooltip rather than assumed.
            for _, prefix in ipairs(UNBOUND_LINES) do
                if text:find(prefix, 1, true) then found.unbound = true end
            end
            -- Match "Upgrade Level: Champion 3/5" or similar
            if not found.track then
                local trackName, currRank, maxRank = text:match("Upgrade Level:%s+(%S+)%s+(%d+)/(%d+)")
                if trackName then
                    found.track   = trackName
                    found.rank    = tonumber(currRank)
                    found.maxRank = tonumber(maxRank)
                end
            end
            -- Detect crafted items: quality tier atlas icons (Professions-Icon-Quality-*)
            -- or crafted-by line
            if text:find("Professions%-Icon%-Quality") or text:find("Professions%-ChatIcon%-Quality") then
                found.crafted = true
            end
        end
    end

    return found
end

local function ScanUpgradeTrack(slotID)
    -- Return cached result if available
    if scanCache[slotID] then
        return scanCache[slotID].track, scanCache[slotID].rank, scanCache[slotID].maxRank, scanCache[slotID].crafted
    end
    upgradeScanTooltip:ClearLines()
    local ok = pcall(upgradeScanTooltip.SetInventoryItem, upgradeScanTooltip, "player", slotID)
    if not ok then return nil, nil, nil, false end

    local found = ParseUpgradeTooltip()
    if not found then return nil, nil, nil, false end

    scanCache[slotID] = found
    return found.track, found.rank, found.maxRank, found.crafted
end

------------------------------------------------------------
-- Spare pieces in the bags, by the slot they would go in.
--
-- A slot remembers the highest item level it has ever held, and any
-- upgrade up to that level costs no crests. That makes a lower-track
-- piece for a slot the only exchange rate between two crest tiers there
-- is:
--
--   The slot is wearing a Hero 1/6, so it has already reached 305. A
--   Champion piece for that same slot walks from 292 all the way to 305
--   for nothing -- every one of those ranks is under what the slot has
--   already seen -- and only its last rank, 305 to 308, costs anything.
--   Twenty Champion. The slot has now reached 308, so the Hero piece
--   goes 305 to 308 free. Twenty Champion bought a rank that was going
--   to cost twenty Hero.
--
-- That Champion piece is never equipped: the Hero drop is in the slot
-- and the Champion one is in a bag. So it was invisible to every rule
-- here, and the one move that spends the crest a player has too many of
-- could not be advised at all.
--
-- Only pieces carrying this season's upgrade track come back, finished
-- ones included. A Champion 6/6 in a bag has no rank left to buy and is
-- still the biggest thing in the bags: bound, it has taken the slot to
-- 308, and everything the slot holds is free up to there.
------------------------------------------------------------

--- Which equipment slots an item's inventory type can be worn in.
---
--- Rings, trinkets and one-handers belong to two slots each and both are
--- listed: a spare ring is a spare for whichever of the two the question
--- happens to be about.
local INVTYPE_SLOTS = {
    INVTYPE_HEAD           = { 1 },
    INVTYPE_NECK           = { 2 },
    INVTYPE_SHOULDER       = { 3 },
    INVTYPE_CLOAK          = { 15 },
    INVTYPE_CHEST          = { 5 },
    INVTYPE_ROBE           = { 5 },
    INVTYPE_WRIST          = { 9 },
    INVTYPE_HAND           = { 10 },
    INVTYPE_WAIST          = { 6 },
    INVTYPE_LEGS           = { 7 },
    INVTYPE_FEET           = { 8 },
    INVTYPE_FINGER         = { 11, 12 },
    INVTYPE_TRINKET        = { 13, 14 },
    INVTYPE_WEAPON         = { 16, 17 },
    INVTYPE_2HWEAPON       = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_RANGED         = { 16 },
    INVTYPE_RANGEDRIGHT    = { 16 },
    INVTYPE_WEAPONOFFHAND  = { 17 },
    INVTYPE_SHIELD         = { 17 },
    INVTYPE_HOLDABLE       = { 17 },
}

-- Built on demand and dropped whenever the bags move. Walking every bag
-- slot and building a tooltip for each is not work to repeat once per
-- gear row.
local bagSpareCache = nil

function ns:InvalidateBagSpares()
    bagSpareCache = nil
end

local function ScanBagUpgradeTrack(bag, slot)
    upgradeScanTooltip:ClearLines()
    local ok = pcall(upgradeScanTooltip.SetBagItem, upgradeScanTooltip, bag, slot)
    if not ok then return nil end
    return ParseUpgradeTooltip()
end

local function ScanBagSpares()
    local out = {}
    local C = C_Container
    if not (C and C.GetContainerNumSlots and C.GetContainerItemID) then return out end
    if not GetItemInfoInstant then return out end

    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, last do
        for slot = 1, (C.GetContainerNumSlots(bag) or 0) do
            local itemID = C.GetContainerItemID(bag, slot)
            local slots
            if itemID then
                local ok, _, _, _, equipLoc = pcall(GetItemInfoInstant, itemID)
                if ok and equipLoc then slots = INVTYPE_SLOTS[equipLoc] end
            end
            if slots then
                local found = ScanBagUpgradeTrack(bag, slot)
                local levels = found and found.track and ns.GEAR_TRACKS[found.track]
                local rank = found and found.rank
                local maxRank = found and found.maxRank
                if levels and rank and maxRank and rank <= maxRank then
                    local link = C.GetContainerItemLink and C.GetContainerItemLink(bag, slot)
                    local ilvl
                    if link and GetDetailedItemLevelInfo then
                        local okLvl, lvl = pcall(GetDetailedItemLevelInfo, link)
                        if okLvl then ilvl = lvl end
                    end
                    -- The same cross-check CanUpgradeItem makes on worn
                    -- gear, for the same reason: track names repeat every
                    -- season, so a piece whose track was stripped at the
                    -- patch can still carry a line that parses. If the
                    -- item level is not what this track's rank should be,
                    -- it is not this season's gear and no crest moves it.
                    if ilvl and levels[rank] == ilvl then
                        local spare = {
                            itemID  = itemID,
                            link    = link,
                            track   = found.track,
                            rank    = rank,
                            maxRank = maxRank,
                            ilvl    = ilvl,
                            crafted = found.crafted,
                            unbound = found.unbound or false,
                            -- Rings, trinkets and one-handers go in two
                            -- slots, and the pair keeps ONE memory
                            -- between them -- one that follows the
                            -- lower of the two. So a third piece
                            -- better than one of them changes nothing:
                            -- the lower of the top two is still the
                            -- lower of the top two. Anything reasoning
                            -- about what a piece did to a slot has to
                            -- know this and decline.
                            shared  = #slots > 1,
                        }
                        for _, slotID in ipairs(slots) do
                            out[slotID] = out[slotID] or {}
                            table.insert(out[slotID], spare)
                        end
                    end
                end
            end
        end
    end
    return out
end

--- Pieces in the bags that belong in this slot.
---
--- Always a table, never nil: every caller wants to iterate it.
---
--- Callers that are pricing a spare have to skip the finished ones
--- themselves -- a piece at its last rank cannot be bought any further,
--- but it still counts for what it has already done to the slot.
function ns:GetBagSpares(slotID)
    if not bagSpareCache then
        bagSpareCache = ScanBagSpares()
    end
    return bagSpareCache[slotID] or {}
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
-- Kept across sessions, in SavedVariables.
--
-- It was a plain table, and RefreshWatermarks only ran while the
-- upgrade vendor was open -- so on any fresh login away from a vendor
-- every mark read zero, GetFreeUpgradeIlvl returned zero, and RULE 0
-- could not fire. That rule is the highest-priority advice the addon
-- has: ranks the player already owns, for no crests at all. It was
-- silently unreachable for most of the time the addon is open.
--
-- Restored in ADDON_LOADED, written through on every successful query.
ns.watermarkCache = {}

--- Ask the client how high this slot has been. Zero for no answer.
---
--- Both of these take an ITEM, not a location:
---
---   bad argument #1 to '?' (Usage: local characterHighWatermark,
---   accountHighWatermark = C_ItemUpgrade.GetHighWatermarkForItem(itemInfo))
---
--- itemInfo is the link/name/id form. An ItemLocation is what nearly
--- everything else in C_Item wants, which is how it got in here, and
--- passing one does not return zero -- it THROWS. Wrapped in the pcall
--- three lines down, a throw and an honest "this slot has been nowhere"
--- are the same value, so the whole free-rank half of the addon was
--- switched off in a way nothing could see: /yh debug printed wm:none
--- down all sixteen slots and every row priced its ranks as paid.
---
--- Which is the real lesson, and it is in the harness now: the stub
--- used to accept the location happily, so no check could ever have
--- caught this. It throws like the client does now.
local function QueryWatermark(slotID)
    if not C_ItemUpgrade then return 0 end

    -- GetSlotInfo rather than GetInventoryItemLink so a slot that has
    -- been stood in for -- by the harness, or by anything else that
    -- answers for gear -- is asked the same question as a real one.
    local info = ns.GetSlotInfo and ns:GetSlotInfo(slotID)
    local itemLink = info and info.link
    if not itemLink then return 0 end

    if C_ItemUpgrade.GetHighWatermarkForItem then
        local ok, charMark, accountMark =
            pcall(C_ItemUpgrade.GetHighWatermarkForItem, itemLink)
        if ok then
            local mark = math.max(charMark or 0, accountMark or 0)
            if mark > 0 then return mark end
        end
    end

    -- Fallback: whatever redundancy slot this item belongs to. Rings and
    -- trinkets answer here as a pair rather than one slot each.
    if C_ItemUpgrade.GetHighWatermarkSlotForItem and C_ItemUpgrade.GetHighWatermarkForSlot then
        local ok1, redundancySlot = pcall(C_ItemUpgrade.GetHighWatermarkSlotForItem, itemLink)
        if ok1 and redundancySlot then
            local ok2, charMark, accountMark =
                pcall(C_ItemUpgrade.GetHighWatermarkForSlot, redundancySlot)
            if ok2 then
                return math.max(charMark or 0, accountMark or 0)
            end
        end
    end

    return 0
end

--- Persist a mark, so a later session can still see it.
---
--- Marks only ever go up, so a remembered one is never wrong -- at
--- worst it is behind, and the live query corrects it the moment it
--- answers. That asymmetry is what makes caching safe here.
local function RememberWatermark(slotID, mark)
    ns.watermarkCache[slotID] = mark
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.watermarks = YippYappHelperDB.watermarks or {}
    YippYappHelperDB.watermarks[slotID] = mark
end

--- Read the stored marks back at login.
function ns:LoadWatermarks()
    local stored = YippYappHelperDB and YippYappHelperDB.watermarks
    if type(stored) ~= "table" then return 0 end
    local n = 0
    for slotID, mark in pairs(stored) do
        if type(slotID) == "number" and type(mark) == "number" and mark > 0 then
            ns.watermarkCache[slotID] = mark
            n = n + 1
        end
    end
    return n
end

-- Refresh all watermarks. Worth trying wherever gear changes, not only
-- at the vendor: if the API answers away from one the cache fills on its
-- own, and if it does not, nothing is lost by asking.
function ns:RefreshWatermarks()
    for _, slotInfo in ipairs(ns.SLOT_IDS) do
        local mark = QueryWatermark(slotInfo.slot)
        if mark > 0 then
            RememberWatermark(slotInfo.slot, mark)
        end
    end
end

--- The highest item level a SOULBOUND piece in the bags has given this
--- slot.
---
--- Binding is what sets the level, and a piece binds in a bag as
--- readily as on the body: letting a drop's trade timer run out does it
--- without the player touching anything. So a bound spare sitting above
--- what the slot is said to have reached is not a contradiction, it is
--- the client not having been asked since the drop landed -- the live
--- query wants the upgrade vendor open, and away from one this falls
--- back to a value written before the loot.
---
--- Which is the whole bug: a pair of boots better than the worn ones
--- lands, binds, and the free rank it just handed the worn pair goes
--- unmentioned until the player next stands at a vendor -- the one
--- place they no longer need to be told.
---
--- Slots that keep ONE memory between the two of them.
---
--- Which changes what it takes to move it: the shared line follows the
--- LOWER of the pair, so one good ring is worth nothing and two are
--- worth everything. Exactly the difference between a 295 trinket
--- landing on a 292 and a 292 -- top two are 295 and 292, the lower is
--- the 292 it always was -- and a SECOND 295 landing after it, where
--- the top two are 295 and 295 and both worn trinkets go free to 295.
---
--- Weapons are deliberately not in here. Whether main hand and off hand
--- share a line is not something this addon has established, and the
--- one-handers that could go in either are declined below instead.
local PAIRED_SLOTS = {
    [11] = { 11, 12 },  -- rings
    [12] = { 11, 12 },
    [13] = { 13, 14 },  -- trinkets
    [14] = { 13, 14 },
}

--- How high this slot is provably known to have been, from pieces the
--- addon can actually see: what is worn in it, and anything bound
--- sitting in the bags.
---
--- A floor and never a ceiling. It counts only pieces the tooltip
--- positively showed as bound -- an unbound one has given the slot
--- nothing yet, which is a different rule (see ns:GetBagLift) -- and
--- there are always pieces it cannot see, because a slot remembers
--- things sold, disenchanted or left behind three weeks ago.
---
--- On a paired slot it takes the SECOND highest, which is what "follows
--- the lower of the pair" means once both slots and the bags are one
--- population. On a single slot the second highest of one piece would
--- be nothing, so it takes the highest.
local function BoundBagFloor(slotID)
    local pair = PAIRED_SLOTS[slotID]
    local seen = {}

    -- Worn counts. It is bound by definition, and on a paired slot the
    -- twin's piece is half of what sets the line.
    for _, s in ipairs(pair or { slotID }) do
        local info = ns.GetSlotInfo and ns:GetSlotInfo(s)
        if info and info.ilvl and info.ilvl > 0 then
            seen[#seen + 1] = info.ilvl
        end
    end

    for _, spare in ipairs(ns:GetBagSpares(slotID)) do
        -- spare.shared is the one-hander case: it could go in either
        -- hand and nothing here knows which line it moved. On a slot
        -- that is genuinely paired, shared is the whole point.
        if not spare.unbound and (pair or not spare.shared)
            and spare.ilvl and spare.ilvl > 0 then
            seen[#seen + 1] = spare.ilvl
        end
    end

    table.sort(seen, function(a, b) return a > b end)
    return seen[pair and 2 or 1] or 0
end

--- What the CLIENT has said this slot reached. Zero for "it has not
--- said".
---
--- Kept separate from ns:GetFreeUpgradeIlvl below because the two
--- answers are not interchangeable, and which one a caller wants
--- depends entirely on which direction being wrong would hurt.
---
--- This is the one to use before quoting a price. A price is a
--- statement about what is ABOVE the line, and a floor cannot support
--- one: guess the line too low and the row confidently charges for
--- ranks the vendor would hand over. Silence is the right answer to a
--- price nobody read.
function ns:GetMarkRead(slotID)
    local mark = QueryWatermark(slotID)
    if mark > 0 then
        RememberWatermark(slotID, mark)
        return mark
    end
    return ns.watermarkCache[slotID] or 0
end

--- How high this slot is KNOWN to have been. Never an over-statement.
---
--- The client's answer where there is one, raised by anything bound in
--- the bags that says otherwise -- and standing on the bags alone when
--- the client says nothing at all, which on a character that has not
--- been to an upgrade vendor is every slot it has.
---
--- Safe in that direction and only that direction. Everything built on
--- this asks "is this rank at or under the line", and a line that is
--- too low hands out too FEW free ranks -- which is where the addon
--- already was, so it cannot make anything worse. Nothing here may be
--- read as "and everything above the line is paid": see ns:GetMarkRead.
function ns:GetFreeUpgradeIlvl(slotID)
    local mark = ns:GetMarkRead(slotID)

    -- Deliberately not written through to SavedVariables. Everything
    -- else in that cache came from the client; this is inference off a
    -- tooltip, and inference that outlives the bag it was read from is
    -- inference nothing can correct.
    local floor = BoundBagFloor(slotID)
    if floor > mark then return floor end
    return mark
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
-- The home page reports vault progress, and the vault filling is not
-- signalled by anything else the addon listens for.
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

        -- Free upgrades are only visible if the marks are, and the live
        -- query may want the upgrade vendor open.
        if ns.LoadWatermarks then ns:LoadWatermarks() end

        -- Validate discounts table
        if YippYappHelperDB.discounts and type(YippYappHelperDB.discounts) ~= "table" then
            YippYappHelperDB.discounts = nil
        end

        -- Drop settings belonging to features removed in 2.9.0 so they
        -- don't linger in the SavedVariables file forever.
        for _, dead in ipairs({
            "xaltoes", "lura", "nexusKingInterrupt", "piAssignments",
            "raidSplit", "releaseBlocker",
            -- The "what's new" notice, which has now been removed twice.
            -- It went in 2.9.0, came back in 2.13.0 -- which is why this
            -- key used to carry a comment explaining it must NOT be
            -- purged -- and is gone again for good. An update notice
            -- that interrupts a reload to recite a changelog is a thing
            -- nobody has ever wanted to read twice, and the changelog is
            -- in CHANGELOG.md where it can be read on purpose.
            "lastSeenVersion",
            -- Stamped by the Advisor to time how long Omnium Folio
            -- progress had been stalled. The Folio came out entirely,
            -- so nothing writes or reads this any more.
            "folio",
        }) do
            YippYappHelperDB[dead] = nil
        end

        print("|cff00ff00YippYapp Helper|r loaded \226\128\148 type |cff00ff00/yh|r to open")

        -- Create or update the /yh macro
        C_Timer.After(2, function()
            ns:EnsureLauncherMacro()
        end)

        -- Suppress CharacterFrame when upgrade vendor is open
        -- (our slot buttons handle equipping instead)
        if CharacterFrame and not characterFrameHooked then
            CharacterFrame:HookScript("OnShow", function()
                if ns.upgradeVendorOpen then
                    -- securecall for the same reason as Core/EditMode.lua:
                    -- HideUIPanel runs inside the secure
                    -- FramePositionDelegate, and calling it from a hook we
                    -- installed taints panel management for the session.
                    securecall("HideUIPanel", CharacterFrame)
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
            -- Not gated on the vendor any more. A mark that only
            -- refreshes in front of an NPC is a mark the advice cannot
            -- use for the rest of the session.
            if ns.RefreshWatermarks then ns:RefreshWatermarks() end
            -- Was gated on MainFrame being shown, so equipping a piece
            -- while on the app's Gear Upgrades page changed nothing.
            ns:RefreshGearViews()
        end)
    elseif event == "CURRENCY_DISPLAY_UPDATE"
        or event == "ITEM_UPGRADE_MASTER_UPDATE"
        or event == "BAG_UPDATE_DELAYED"
        or event == "WEEKLY_REWARDS_UPDATE"
        or event == "CHALLENGE_MODE_COMPLETED" then
        -- A bagged spare is a drop that has not been equipped yet, so
        -- the advice that reads one is exactly the advice that goes
        -- stale the moment the bags move.
        if event == "BAG_UPDATE_DELAYED" then ns:InvalidateBagSpares() end
        ns:RefreshGearViews()
    end
end)

--- Opens the addon's main window: the one thing "open YippYapp" means.
---
--- The chain matters. The front door is the shell; the old app frame and
--- the dashboard are fallbacks, and they still have to be, because a
--- .toc change needs a full client restart -- somebody who only reloaded
--- after an update will not have Core/Shell.lua loaded at all, and
--- "nothing happens" is the worst possible answer to a key press.
--- Whether the main window is on screen right now.
---
--- There used to be three of these and this had to ask each in turn.
--- The pre-shell window and the dashboard are gone; the shell is the
--- window.
local function mainIsOpen()
    if ns.Shell and ns.Shell.IsOpen and ns.Shell:IsOpen() then return true end
    return false
end

--- One line in chat about what combat is stopping, throttled.
---
--- Throttled because the things that call it are things you press: a
--- keybinding, a macro on the bars, the close button. One line per press
--- turns a small annoyance into a wall of chat, and the second press is
--- almost always the same person trying the same thing again.
local combatNagAt = 0
function ns.CombatNotice(what)
    local now = GetTime()
    if now - combatNagAt < 2 then return end
    combatNagAt = now
    print("|cff00ff00YippYapp Helper|r: " .. what)
end

--- Refuses to open the window in combat, and says so.
---
--- Not caution for its own sake. The Mythic+ and Teleports pages mount
--- SecureActionButtonTemplate tiles inside the window, and a frame
--- holding a protected frame is protected itself, so once either page
--- has been opened the window's own Show is a protected call for the
--- rest of the session. Opening mid-fight is refused by the client and
--- charged to us:
---
---   [ADDON_ACTION_BLOCKED] AddOn 'YippYappHelper' tried to call the
---   protected function 'YippYappShell:Show()'
---
--- Blocked calls are silent unless scriptErrors is on or an error
--- grabber is installed, so without this the key press simply did
--- nothing and the addon looked broken rather than busy.
---
--- Closing is protected for the same reason, and is handled where it
--- happens: Core/ShellFrame.lua defers the hide to the end of combat.
local function blockedByCombat()
    if not InCombatLockdown() then return false end
    ns.CombatNotice("can't open in combat — try again after the fight.")
    return true
end

function ns:OpenMain()
    if not mainIsOpen() and blockedByCombat() then return end
    if ns.Shell and ns.Shell.Toggle then
        ns.Shell:Toggle()
    end
end

--- Opens the main window on a particular page.
---
--- The same front door as OpenMain, for the callers that know where
--- they want to land.
---
--- Everything that wanted a specific page used to reach past OpenMain
--- and drive the pre-shell window directly -- the minimap icon, the
--- Group Finder tab, the after-key summary, half the slash commands --
--- so clicking one handed you a different-looking addon than the one
--- you had just been using. Routing them all through here is what fixed
--- that; deleting the window it fell back to is what finished it.
function ns:OpenTo(id)
    if not mainIsOpen() and blockedByCombat() then return false end
    if ns.Shell and ns.Shell.Open then
        ns.Shell:Open(id)
        return true
    end
    return false
end


------------------------------------------------------------
-- Opening by itself when the game loads
--
-- The window's first page is the Great Vault, and what somebody wants to
-- know at the start of an evening is what the vault still owes them. For
-- a player who opens the addon every session anyway, having it already
-- open is one fewer keypress and the same information sooner.
--
-- Off unless asked for. An addon that puts itself on screen uninvited is
-- the kind that gets uninstalled, so nothing here happens until the box
-- in the options is ticked.
------------------------------------------------------------

--- Whether the window opens itself when the game loads.
function ns.GetOpenOnLogin()
    YippYappHelperDB = YippYappHelperDB or {}
    return YippYappHelperDB.openOnLogin and true or false
end

function ns.SetOpenOnLogin(v)
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.openOnLogin = v and true or false
end

-- A beat after the loading screen. The vault's own data arrives from the
-- server a moment after login, so opening immediately shows slots that
-- fill in a second later.
--
-- It used to be five seconds rather than a shorter wait because the
-- What's New notice took the screen at four. That notice is gone, so the
-- delay is now only about the vault -- worth knowing before anyone tunes
-- it, since the number no longer has a second constraint on it.
local OPEN_ON_LOGIN_DELAY = 5

--- Opens the window if this loading screen is one that warrants it.
---
--- A named function rather than the body of the handler below so the
--- load harness can put every case through it -- setting off, zone
--- change, window already open -- without having to fake an event that
--- by design only ever fires once. That is also why the two flags are
--- re-tested here rather than trusted from the caller.
---
--- Returns whether an open was scheduled, which is the only thing about
--- it that can be observed synchronously.
function ns.OpenOnLoginIfWanted(isInitialLogin, isReloadingUi)
    if not (isInitialLogin or isReloadingUi) then return false end
    if not ns.GetOpenOnLogin() then return false end

    C_Timer.After(OPEN_ON_LOGIN_DELAY, function()
        if mainIsOpen() then return end
        -- Deliberately not through ns:OpenMain. Nobody pressed anything,
        -- so its "can't open in combat" line would be the addon
        -- complaining in chat about a key the player never touched.
        -- Logging straight into a fight is rare, and it is exactly when
        -- that notice is least welcome.
        if InCombatLockdown() then return end
        if ns.OpenTo then ns:OpenTo("home") end
    end)
    return true
end

-- PLAYER_ENTERING_WORLD rather than PLAYER_LOGIN, for its two arguments.
-- The event itself fires on every loading screen: every zone change,
-- every instance door, every hearthstone. A window that reopened on all
-- of those would be unusable, and isInitialLogin / isReloadingUi are the
-- only way to tell "the game loaded" from "you walked through a door".
--
-- Wrapped in a do block so the frame does not add a file-scope local to
-- a chunk that is already carrying a lot of them.
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(self, _, isInitialLogin, isReloadingUi)
        if not (isInitialLogin or isReloadingUi) then return end
        -- Every later one is a doorway, and this only wanted the first.
        self:UnregisterAllEvents()
        ns.OpenOnLoginIfWanted(isInitialLogin, isReloadingUi)
    end)
end


--- Opens the game's Key Bindings panel, where our binding lives.
---
--- Guarded rather than assumed: the modern client files keybindings as a
--- Settings category, older ones had a panel of their own, and a button
--- that silently does nothing is worse than one that tells you where to
--- go. So each step is tried and the last resort is saying it out loud.
function ns.OpenKeybindings()
    if Settings and Settings.OpenToCategory and Settings.KEYBINDINGS_CATEGORY_ID then
        Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID)
        return true
    end
    if SettingsPanel and ShowUIPanel then
        ShowUIPanel(SettingsPanel)
        print("|cff00ff00YippYapp|r the binding is under Key Bindings - YippYapp Helper.")
        return true
    end
    print("|cff00ff00YippYapp|r bind it under Esc - Options - Key Bindings - YippYapp Helper.")
    return false
end

--- The keybinding's target, which has to be a global: Bindings.xml runs
--- its body in the global environment and cannot see our namespace.
---
--- Named for the addon rather than something short and grabbable --
--- every addon shares one global namespace, and a `YippYapp_Toggle` is
--- the kind of name two addons pick and one of them loses.
function YippYappHelper_Toggle()
    ns:OpenMain()
end

-- What the Key Bindings panel calls these. The header is the section it
-- files them under; without it the binding lands in a nameless block at
-- the bottom of the list.
BINDING_HEADER_YIPPYAPPHELPER = "YippYapp Helper"
BINDING_NAME_YIPPYAPPHELPER_TOGGLE = "Open YippYapp"

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
        print("  /yh — open the app")
        print("  /yh shell <page> — open a specific page")
        print("     |cff888888pages: home, gear, bis, trinkets, consumables,|r")
        print("     |cff888888progression, loot, mythicplus, raid, teleports, delves|r")
        print("  /yh guide — boss guide for the current raid")
        print("  /yh profile — show/set player profile")
        print("  /yh profile <name> — set profile (normal, heroic, mythic)")
        print("  /yh discount <track> — toggle crest discount for a track (adventurer, veteran, champion, hero, myth)")
        print("  /yh discounts — show current discount status")
        print("  /yh brez — Battle Res Timer options")
        print("  /yh settings — open the options panel")
        print("  /yh skin [id] — list or choose a skin")
        print("  /yh edit — move YippYapp frames via Edit Mode")
        print("  /yh test [panel] — show a panel with sample content (/yh test for the list)")
        return
    end

    -- /yh skin [id] — list or choose. Restoring here rather than at
    -- load because saved variables are not available until then.
    if cmd == "skin" then
        if not ns.Skin then return end
        if arg and arg ~= "" then
            if ns.Skin:SetActive(strlower(arg)) then
                print("|cff00ff00YippYapp|r skin: " .. strlower(arg))
            else
                print("|cff00ff00YippYapp|r no such skin: " .. arg)
            end
            return
        end
        print("|cff00ff00=== YippYapp skins ===|r")
        for _, info in ipairs(ns.Skin:GetProviders()) do
            local mark = (info.id == ns.Skin:ActiveID()) and "|cff00ff00*|r " or "  "
            print(mark .. info.id .. (info.beta and " |cff33aaff(beta)|r" or "")
                .. " |cff888888" .. info.description .. "|r")
        end
        return
    end

    -- /yh shell [page] — bare /yh opens this too. Kept as a named
    -- command because it is the only way to open a specific page from a
    -- macro.
    if cmd == "shell" then
        if ns.Shell and ns.Shell.Toggle then
            ns.Shell:Toggle(arg ~= "" and arg or nil)
        else
            print("|cff00ff00YippYapp|r shell not loaded — restart WoW, not /reload.")
        end
        return
    end

    -- /yh settings — the options panel.
    --
    -- New, and overdue. The only ways in used to be three global slash
    -- names -- /yyhopts, /yyhsettings and /yyhinterrupts -- all calling
    -- the same function, the last of them named after a single feature
    -- while opening the whole panel. Two are gone; settings live under
    -- the addon's own command now, like everything else.
    if cmd == "settings" or cmd == "options" or cmd == "opts" then
        if ns.OpenSettings then ns.OpenSettings()
        elseif ns.OpenBlizzardSettings then ns.OpenBlizzardSettings()
        else print("|cffff5555YippYapp:|r settings are not loaded.") end
        return
    end

    -- /yh test [panel] — put one of the situation window's panels on
    -- screen with sample content.
    --
    -- None of these three can be summoned in normal play: you cannot
    -- start a ready check to see where it sits, and the after-key
    -- summary needs a finished keystone. Edit Mode can show them, but
    -- Edit Mode also dims the world and locks out the rest of the UI --
    -- which is exactly wrong for "does this look right while I am
    -- playing". The panel list comes from the window itself, so a fourth
    -- panel is testable the day it registers.
    if cmd == "test" then
        if not ns.Hud then
            print("|cffff5555YippYapp:|r the situation window is not loaded.")
            return
        end
        -- Split once: the first word names the panel, the rest belongs
        -- to the panel. "/yh test utility next" is the utility notes
        -- being told "next", not a panel called "utility next".
        local want, rest = strsplit(" ", strtrim(arg or ""), 2)
        want = strtrim(want or "")
        if want == "off" or want == "hide" then
            ns.Hud:ReleaseAll()
            return
        end
        local id = ns.Hud:Find(want)
        if id then
            ns.Hud:PreviewMode(id, rest)
            -- The panel prints its own line when it has something to say
            -- about the argument -- which dungeon it landed on, say -- so
            -- only announce the bare case.
            if not rest or strtrim(rest) == "" then
                print("|cff00ff00YippYapp|r showing " .. id
                    .. " — |cff888888/yh test off|r to dismiss")
            end
            return
        end
        if want ~= "" then
            print("|cffff5555YippYapp:|r no panel called \"" .. want .. "\".")
        end
        print("|cff00ff00=== YippYapp panels ===|r")
        local order, modes = ns.Hud:Modes()
        for _, key in ipairs(order) do
            local m = modes[key]
            -- Led by the alias rather than the id: the id is how the
            -- code spells it, the alias is how a person would.
            local aliases = m.aliases or {}
            print(("  /yh test %-10s |cff888888%s|r"):format(aliases[1] or key, m.label or key))
            local names = key
            for i = 2, #aliases do names = names .. ", " .. aliases[i] end
            print(("     |cff666666or: %s|r"):format(names))
        end
        print("  /yh test off      |cff888888dismiss whatever is up|r")
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

    -- /yh icon [size] [offsetX] [offsetY] — dial in the minimap ring fit.
    -- Unlisted in /yh help: dialling in an icon's pixel fit is a thing
    -- only somebody working on the addon does.
    if cmd == "icon" then
        if ns.TuneMinimapIcon then
            local s, x, y = strsplit(" ", strtrim(arg or ""))
            ns:TuneMinimapIcon(tonumber(s), tonumber(x), tonumber(y))
        end
        return
    end

    -- /yh guide — Raid Tools, opened straight onto the Boss Guide.
    --
    -- Worth its own command rather than "open the app, find the page,
    -- find the tab": the moment somebody wants this is thirty seconds
    -- before a pull, and three clicks is two too many.
    if cmd == "guide" then
        ns:OpenTo("raid")
        if ns.Shell and ns.Shell.SetSubTab then ns.Shell:SetSubTab("raid", "guide") end
        return
    end

    -- /yh ejdump — what the Encounter Journal calls these bosses.
    --
    -- Deliberately absent from /yh help. It exists to check the guide's
    -- spelling against the client, which is a thing only a developer
    -- needs and only from inside the game.
    if cmd == "ejdump" then
        if ns.RaidGuide and ns.RaidGuide.DumpJournal then
            -- `/yh ejdump abilities` walks every section of every
            -- encounter and names the ones our guide never mentions.
            ns.RaidGuide:DumpJournal(arg and strlower(strtrim(arg)) or nil)
        end
        return
    end

    -- /yh questdump [id or words] -- this character's quest log, with ids.
    --
    -- Absent from /yh help for the same reason as ejdump above: it
    -- exists to get a fact out of the client that only the client can
    -- settle, which is a thing a developer needs and a player does not.
    -- Here it is the quest ids behind the weekly checklist's rows.
    --
    -- The argument narrows it to one quest and prints that quest's
    -- objectives as well. Bare, this would be a hundred lines of chat
    -- for four lines you wanted; and the objectives are only interesting
    -- once you know which quest you are asking about.
    if cmd == "questdump" or cmd == "questid" then
        if ns.Weekly and ns.Weekly.DumpQuestLog then
            ns.Weekly:DumpQuestLog(arg)
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
                -- Refresh whatever is actually on screen.
                --
                -- This only ever refreshed ns.MainFrame, so changing
                -- profile while the shell was open left the gear page
                -- showing the previous profile's advice until something
                -- else happened to redraw it.
                if ns.RefreshAllSlots then ns:RefreshAllSlots() end
                if ns.RefreshCrests then ns:RefreshCrests() end
                if ns.Shell and ns.Shell.IsOpen and ns.Shell:IsOpen()
                    and ns.Shell.RefreshPage and ns.Shell._lastPage then
                    ns.Shell:RefreshPage(ns.Shell._lastPage)
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
                source = " (achievement: "
                    .. ns:GetDiscountAchievementName(trackName) .. ")"
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

    -- /yh brez [subcommand] — Battle Res Timer
    if cmd == "brez" or cmd == "battleres" then
        if ns.BattleResTimer and ns.BattleResTimer.HandleSlash then
            ns.BattleResTimer:HandleSlash(arg)
        else
            print("|cff00ff00YippYapp Helper|r: Battle Res Timer module not loaded.")
        end
        return
    end

    -- /yh debug — crest and slot state, dumped to chat.
    -- Unlisted in /yh help, same as ejdump and editdebug: it prints the
    -- gear engine's working, which is a developer's question.
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
                -- Both numbers, because the gap between them is the
                -- thing worth seeing: what the client said, and what
                -- the bags prove regardless.
                local read = ns:GetMarkRead(slotInfo.slot)
                local known = ns:GetFreeUpgradeIlvl(slotInfo.slot)
                local wmStr = read > 0 and ("wm:" .. read) or "wm:none"
                if known > read then wmStr = wmStr .. " (bags:" .. known .. ")" end
                print(string.format("  %s: %s | %s | risk: %s | %s | %s",
                    slotInfo.name, upStr, wmStr, risk, rec.label, reason))
            end
        end

        -- Why the marks are missing, when they are.
        --
        -- Every free-rank rule in the addon is downstream of one query,
        -- and a whole character reading wm:none is not a gear problem,
        -- it is that query answering nothing. Which of the three ways
        -- it can answer nothing -- absent, erroring, or returning a
        -- flat zero -- decides whether this is fixable here at all, and
        -- there is no way to tell them apart from the outside.
        print("--- High-water query (Feet) ---")
        if not C_ItemUpgrade then
            print("  C_ItemUpgrade: MISSING")
        else
            local info = ns:GetSlotInfo(8)
            local link = info and info.link
            print("  item link: " .. tostring(link and link:gsub("|", "||")))
            print("  vendor open: " .. tostring(ns.upgradeVendorOpen or false))
            local function try(name, fn, arg)
                if type(fn) ~= "function" then
                    print("  " .. name .. ": MISSING")
                    return
                end
                local r = { pcall(fn, arg) }
                if not r[1] then
                    print("  " .. name .. ": ERROR " .. tostring(r[2]))
                    return
                end
                local out = {}
                for i = 2, math.max(#r, 2) do out[#out + 1] = tostring(r[i]) end
                print("  " .. name .. ": " .. (table.concat(out, ", ")))
            end
            try("GetHighWatermarkForItem", C_ItemUpgrade.GetHighWatermarkForItem, link)
            try("GetHighWatermarkSlotForItem", C_ItemUpgrade.GetHighWatermarkSlotForItem, link)
            local okSlot, redundancy = pcall(function()
                return C_ItemUpgrade.GetHighWatermarkSlotForItem
                    and C_ItemUpgrade.GetHighWatermarkSlotForItem(link)
            end)
            if okSlot and redundancy then
                try("GetHighWatermarkForSlot(" .. tostring(redundancy) .. ")",
                    C_ItemUpgrade.GetHighWatermarkForSlot, redundancy)
            else
                print("  GetHighWatermarkForSlot: no redundancy slot to ask about")
            end
        end
        print("  (run this again standing at an upgrade vendor -- if the "
            .. "numbers only appear there, the cache is the fix)")
        return
    end

    -- Default: the shell.
    ns:OpenMain()
end
