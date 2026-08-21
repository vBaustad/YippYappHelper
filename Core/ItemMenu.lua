local _, ns = ...

------------------------------------------------------------
-- Item context menu.
--
-- One menu, shared by every page that shows an item: the trinket lists,
-- the best-in-slot doll and the loot browser. Right-click an item and
-- the same actions appear wherever you are, which is the whole reason
-- this is not three separate handlers.
--
-- It replaced a plain right-click-to-favourite on the trinket page.
-- That gesture could only ever do one thing, and there are two things
-- worth doing to an item: marking it as one you want, and pinning it to
-- a slot. Those are deliberately separate -- a favourite is "I am
-- hunting this" and there can be several per slot, while a pin is "this
-- one goes here" and there is exactly one. A menu can offer both
-- without either pretending to be the other.
--
-- Modelled on the profile dropdown in Core/AppFrame.lua rather than on
-- Blizzard's menu API, which has been rewritten twice in recent
-- expansions and would date this file faster than the game does.
------------------------------------------------------------

local MENU_W = 224
local ROW_H  = 22
local PAD    = 8

-- Numeric inventory slots, named the way the character sheet names them.
-- Static game facts, kept here rather than imported so the menu does not
-- depend on a feature file having loaded first.
local SLOT_LABEL = {
    [1] = "Head",     [2] = "Neck",      [3] = "Shoulders",
    [5] = "Chest",    [6] = "Waist",     [7] = "Legs",
    [8] = "Feet",     [9] = "Wrist",     [10] = "Hands",
    [11] = "Ring 1",  [12] = "Ring 2",   [13] = "Trinket 1",
    [14] = "Trinket 2", [15] = "Back",   [16] = "Main Hand",
    [17] = "Off Hand",
}

local menu = CreateFrame("Frame", "YippYappItemMenu", UIParent, "BackdropTemplate")
menu:SetSize(MENU_W, 10)
menu:SetFrameStrata("FULLSCREEN_DIALOG")
menu:SetClampedToScreen(true)
menu:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 },
})
menu:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
menu:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
if ns.SmoothFrame then ns.SmoothFrame(menu) end
menu:EnableMouse(true)
menu:Hide()

-- Escape closes it, and only while it is up: leaving the name in
-- UISpecialFrames permanently would have Escape swallowed by a hidden
-- frame for the rest of the session.
menu:SetScript("OnShow", function()
    tinsert(UISpecialFrames, "YippYappItemMenu")
end)
menu:SetScript("OnHide", function()
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "YippYappItemMenu" then
            table.remove(UISpecialFrames, i)
            break
        end
    end
end)

-- Clicking anywhere else dismisses it. A menu that only closes on its
-- own entries is a menu you have to fight.
local catcher = CreateFrame("Button", nil, UIParent)
catcher:SetAllPoints(UIParent)
catcher:SetFrameStrata("FULLSCREEN_DIALOG")
catcher:SetFrameLevel(math.max((menu:GetFrameLevel() or 1) - 1, 0))
catcher:RegisterForClicks("AnyUp")
catcher:Hide()
catcher:SetScript("OnClick", function() menu:Hide() end)
menu:HookScript("OnShow", function() catcher:Show() end)
menu:HookScript("OnHide", function() catcher:Hide() end)

local rows = {}
local function AcquireRow(i)
    local row = rows[i]
    if not row then
        row = CreateFrame("Button", nil, menu)
        row:SetSize(MENU_W - PAD * 2, ROW_H)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.text:SetPoint("LEFT", 6, 0)
        row.text:SetPoint("RIGHT", -6, 0)
        row.text:SetJustifyH("LEFT")
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.10)
        rows[i] = row
    end
    row:SetScript("OnClick", nil)
    row:Show()
    return row
end

--- Build the entry list for one item.
---
--- `pinnedTo` is the slot this item already holds, if any. A slot it
--- already holds is offered as nothing at all rather than as "set" --
--- picking it would be a no-op -- while the other eligible slots read as
--- "move to", because that is what choosing one does: the pin leaves the
--- slot it was in and the pick it was overriding comes back.
local function BuildEntries(itemID, opts)
    local out = {}
    local specID = ns.GetPlayerSpecID and ns:GetPlayerSpecID()

    if ns.ToggleLootFavorite and specID then
        local on = ns:IsLootFavorite(itemID, specID)
        out[#out + 1] = {
            text = on and "|cffffd100Remove from favourites|r" or "Add to favourites",
            act  = function() ns:ToggleLootFavorite(itemID, specID) end,
        }
    end

    local slots = ns.GetItemSlots and ns:GetItemSlots(itemID)
    if slots and ns.SetBisPin then
        local pins = ns:GetBisPins(specID)
        local pinnedTo
        for slot, id in pairs(pins) do
            if id == itemID then pinnedTo = slot end
        end

        for _, invSlot in ipairs(slots) do
            if invSlot ~= pinnedTo then
                local label = SLOT_LABEL[invSlot] or ("slot " .. invSlot)
                local occupied = pins[invSlot]
                local verb = pinnedTo and "Move to" or "Set as best in slot:"
                out[#out + 1] = {
                    text = ("%s %s%s"):format(verb, label,
                        occupied and " |cff888888(swaps)|r" or ""),
                    act = function()
                        if pinnedTo then
                            ns:MoveBisPin(pinnedTo, invSlot, specID)
                        else
                            ns:SetBisPin(invSlot, itemID, specID)
                        end
                    end,
                }
            end
        end

        if pinnedTo then
            out[#out + 1] = {
                text = "|cffff8080Remove as best in slot|r",
                act  = function() ns:ClearBisPin(pinnedTo, specID) end,
            }
        end
    end

    if opts and opts.extra then
        for _, e in ipairs(opts.extra) do out[#out + 1] = e end
    end
    return out
end

--- Open the menu for an item, anchored to whatever was right-clicked.
---
--- `opts.onChange` is called after any entry runs, so the page that
--- opened the menu redraws itself. The menu deliberately does not know
--- how to refresh anything: it is shared by three pages that each redraw
--- differently.
function ns:ShowItemMenu(anchor, itemID, opts)
    if not itemID then return end
    opts = opts or {}

    local entries = BuildEntries(itemID, opts)
    if #entries == 0 then return end

    -- Reopening on the same item closes instead, so right-clicking twice
    -- is not a menu that will not go away.
    if menu:IsShown() and menu.itemID == itemID then
        menu:Hide()
        return
    end
    menu.itemID = itemID

    -- One numeric pool, title included, so the leftovers to hide are
    -- everything past the last index used.
    local y, used = PAD, 0
    local function nextRow()
        used = used + 1
        local row = AcquireRow(used)
        row:SetPoint("TOPLEFT", PAD, -y)
        y = y + ROW_H
        return row
    end

    if opts.title then
        local head = nextRow()
        head:EnableMouse(false)
        head.text:SetText(opts.title)
    end

    for _, entry in ipairs(entries) do
        local row = nextRow()
        row:EnableMouse(true)
        row.text:SetText(entry.text)
        row:SetScript("OnClick", function()
            entry.act()
            menu:Hide()
            if opts.onChange then opts.onChange() end
        end)
    end

    for i = used + 1, #rows do rows[i]:Hide() end

    menu:SetHeight(y + PAD)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor or UIParent, "BOTTOMLEFT", 0, -2)
    menu:Show()
end
