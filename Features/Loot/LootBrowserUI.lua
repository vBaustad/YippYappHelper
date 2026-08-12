local _, ns = ...

------------------------------------------------------------
-- Constants
------------------------------------------------------------
local PAD           = 14
local ICON_SIZE     = 34
local ICON_GAP      = 10
local ROW_H         = 54
local ROW_GAP       = 0
local SOURCE_W      = 200
local ITEMS_LEFT    = 248
local FILTER_H      = 38
local VIEW_TAB_H    = 28
local HEADER_H      = 34

------------------------------------------------------------
-- Difficulty border color lookup (by diffID)
------------------------------------------------------------

-- Muted tan for mount rewards — visually distinct from any quality.
local MOUNT_BORDER_COLOR = { r = 0.60, g = 0.45, b = 0.22 }

-- Item-quality border colour, matching Blizzard's own item colouring.
-- Falls back to epic while the item's data is still loading: raid and
-- dungeon drops are epic, so an uncoloured flash of grey would be wrong
-- more often than not.
local EPIC_BORDER = { r = 0.64, g = 0.21, b = 0.93 }

-- Quality must be read from the LINK, not the itemID.
--
-- The base item in the client database is Rare; the difficulty-specific
-- versions are promoted to Epic by their bonus IDs. Querying by itemID
-- returned Rare for everything, which is why epic dungeon loot rendered
-- with blue borders.
-- Rewrite the tooltip's own "Item Level" and "Upgrade Level" lines to the
-- difficulty selected in the browser.
--
-- The Encounter Journal has no keystone loot table, so every M+ selection
-- links the Mythic 0 item — its tooltip reads "Item Level 292 /
-- Champion 1/6" no matter which key level you picked, directly
-- contradicting the line we add below it. Rather than leave two numbers
-- disagreeing, swap the numbers in place and tag the line with the
-- difficulty so it is obvious the value is difficulty-adjusted.
--
-- Only the digits are replaced, so colour codes and localisation survive.
local function RewriteTooltipIlvl(tooltip, ilvl, rankText, diffLabel)
    if not ilvl or not tooltip or not tooltip.GetName then return end
    local name = tooltip:GetName()
    if not name or not ITEM_LEVEL then return end

    -- "Item Level %d" -> "Item Level". The literal "%d" has to be matched
    -- as two characters (%%d); "%d" on its own is the digit class and
    -- would leave the placeholder in place.
    local prefix = ITEM_LEVEL:gsub("%%d", ""):gsub("%s+$", "")
    if prefix == "" then return end

    local tag = diffLabel and ("  |cff888888(%s)|r"):format(diffLabel) or ""
    local didIlvl, didRank = false, false

    for i = 2, math.min(tooltip:NumLines(), 8) do
        local fs = _G[name .. "TextLeft" .. i]
        local text = fs and fs:GetText()
        if text then
            local _, ePos = text:find(prefix, 1, true)
            if not didIlvl and ePos then
                -- Substitute only after the prefix. Colour escapes like
                -- |cff00ff00 contain digits, so a blind gsub on the whole
                -- line could rewrite the colour instead of the number.
                local head, tail = text:sub(1, ePos), text:sub(ePos + 1)
                if tail:find("%d") then
                    fs:SetText(head .. tail:gsub("%d+", tostring(ilvl), 1) .. tag)
                    didIlvl = true
                end
            elseif not didRank and rankText and text:find("%a+%s+%d+/%d+") then
                fs:SetText((text:gsub("%a+%s+%d+/%d+", rankText, 1)))
                didRank = true
            end
        end
    end
    return didIlvl, didRank
end

-- Shared with the Best in Slot page, which has the same problem from the
-- other direction: it knows the rank an item tops out at, but the
-- tooltip it can build shows the item's base level. Reporting whether
-- each line was actually replaced lets that caller add a rank line when
-- the item has no upgrade track of its own to rewrite.
ns.RewriteTooltipIlvl = RewriteTooltipIlvl

local function QualityBorderColor(itemID, itemLink)
    local quality
    if itemLink then
        quality = select(3, GetItemInfo(itemLink))
    end
    if quality == nil and itemID then
        quality = select(3, GetItemInfo(itemID))
    end
    if quality == nil then return EPIC_BORDER end
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if c then return { r = c.r, g = c.g, b = c.b } end
    return EPIC_BORDER
end

-- Item-class helpers. Enum.ItemClass.Miscellaneous == 15, Recipe == 9.
-- Miscellaneous subclasses we keep: 2 Companion Pet, 5 Mount, 6 Mount Equipment.
-- Everything else in that class (junk, holiday, other) is hidden.
local HIDDEN_MISC_SUBCLASSES = { [0] = true, [3] = true, [4] = true }

-- Housing decor got its own item class in Midnight (20). Before that it
-- lived in Miscellaneous and was caught by the subclass list above, and
-- its tooltip carried a "Housing Decor" header we could match on. Both
-- of those stopped being true, which is how a decor item started showing
-- up under Sszorak.
--
-- Class is the right signal: GetItemInfoInstant reads the client's
-- static item database synchronously, so this filters correctly even
-- before the item's full data has cached — unlike the tooltip scan,
-- which silently passes items through until they load.
local HIDDEN_ITEM_CLASSES = {
    [9]  = true,   -- Recipe
    [20] = true,   -- Housing decor
}

-- Name prefixes that indicate a profession recipe / housing blueprint.
-- Backup for items where classID info hasn't loaded yet.
local HIDDEN_NAME_PREFIXES = {
    "Pattern:", "Formula:", "Design:", "Recipe:", "Technique:",
    "Schematic:", "Plans:", "Manual:", "Blueprint:",
}

local function GetItemClassPair(itemID)
    if not itemID then return nil, nil end
    local _, _, _, _, _, classID, subClassID = GetItemInfoInstant(itemID)
    return classID, subClassID
end

local function IsMountItem(itemID)
    local classID, subClassID = GetItemClassPair(itemID)
    return classID == 15 and subClassID == 5
end

local function NameHasHiddenPrefix(name)
    if not name then return false end
    for _, prefix in ipairs(HIDDEN_NAME_PREFIXES) do
        if name:sub(1, #prefix) == prefix then return true end
    end
    return false
end

-- Substrings found anywhere in the tooltip that mark an item as hidden.
-- Only a backstop now that the class check does the real work — kept
-- because Blizzard has already renamed these lines once.
local HIDDEN_TOOLTIP_SUBSTRINGS = {
    "Housing Decor",
    "to your House Chest",   -- "Use: Add this Decor to your House Chest."
    "House XP",              -- "First-Time Collection Bonus: +10 House XP"
}

local tooltipHiddenCache = {}
local tooltipHiddenCacheSize = 0
local TOOLTIP_CACHE_MAX = 2048

local function TooltipMarksHidden(itemID)
    local cached = tooltipHiddenCache[itemID]
    if cached ~= nil then return cached end
    local data = C_TooltipInfo and C_TooltipInfo.GetItemByID and C_TooltipInfo.GetItemByID(itemID)
    if not data or not data.lines then return false end  -- not caching nil yet (may resolve later)
    -- Simple bounded cache: wipe when we hit the cap rather than implementing
    -- full LRU. Loot browser sessions rarely see more than a few thousand items.
    if tooltipHiddenCacheSize >= TOOLTIP_CACHE_MAX then
        wipe(tooltipHiddenCache)
        tooltipHiddenCacheSize = 0
    end
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if text then
            for _, sub in ipairs(HIDDEN_TOOLTIP_SUBSTRINGS) do
                if text:find(sub, 1, true) then
                    tooltipHiddenCache[itemID] = true
                    tooltipHiddenCacheSize = tooltipHiddenCacheSize + 1
                    return true
                end
            end
        end
    end
    tooltipHiddenCache[itemID] = false
    tooltipHiddenCacheSize = tooltipHiddenCacheSize + 1
    return false
end

function ns:IsLootBrowserHidden(itemID)
    if not itemID then return false end

    local classID, subClassID = GetItemClassPair(itemID)
    -- Recipes (9) and housing decor (20)
    if classID and HIDDEN_ITEM_CLASSES[classID] then return true end
    -- Miscellaneous junk/holiday/other
    if classID == 15 and HIDDEN_MISC_SUBCLASSES[subClassID] then return true end

    if TooltipMarksHidden(itemID) then return true end

    local name = GetItemInfo(itemID)
    if NameHasHiddenPrefix(name) then return true end

    return false
end

------------------------------------------------------------
-- Frame/Icon/Label Pools
------------------------------------------------------------
local rowPool      = {}
local iconPool     = {}
local labelPool    = {}
local activeRows   = {}
local activeIcons  = {}
local activeLabels = {}

local function AcquireRow(parent)
    local row = table.remove(rowPool)
    if not row then
        row = CreateFrame("Frame", nil, parent, "YippYappLootRowTemplate")

        -- bg and dungBg/dungBgMask come from the XML template
        row.dungBg:Hide()

        local srcLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
        srcLabel:SetPoint("LEFT", row, "LEFT", 12, 4)
        srcLabel:SetWidth(SOURCE_W - 20)
        srcLabel:SetJustifyH("LEFT")
        srcLabel:SetWordWrap(false)
        ns.ApplyTextShadow(srcLabel)
        row.srcLabel = srcLabel

        -- Count label (used in favorites view / item count)
        local countLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        countLabel:SetPoint("TOPLEFT", srcLabel, "BOTTOMLEFT", 0, -1)
        countLabel:SetWidth(SOURCE_W - 16)
        countLabel:SetJustifyH("LEFT")
        countLabel:SetWordWrap(false)
        countLabel:SetTextColor(unpack(ns.COLORS.TEXT_TERTIARY))
        ns.ApplyTextShadow(countLabel)
        row.countLabel = countLabel

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.03)
        hl:SetBlendMode("ADD")

        row:EnableMouse(true)

        -- Scroll arrows (persistent, shown only when row overflows)
        local function MakeArrow(dir)
            local b = CreateFrame("Button", nil, row)
            b:SetSize(18, 28)
            local tex = b:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
            if dir == "right" then tex:SetTexCoord(1, 0, 0, 1) end
            b.tex = tex
            b:SetScript("OnEnter", function(s) s.tex:SetVertexColor(1, 0.9, 0.3) end)
            b:SetScript("OnLeave", function(s) s.tex:SetVertexColor(1, 1, 1) end)
            b:Hide()
            return b
        end
        row.leftArrow  = MakeArrow("left")
        row.rightArrow = MakeArrow("right")
        row._scrollIdx = 0
        row._itemFrames = {}
    end

    row:SetParent(parent)
    row:ClearAllPoints()
    row.countLabel:SetText("")
    row.countLabel:Hide()
    row.dungBg:Hide()
    row.leftArrow:Hide()
    row.rightArrow:Hide()
    row._scrollIdx = 0
    wipe(row._itemFrames)
    row:Show()
    table.insert(activeRows, row)
    return row
end

local function AcquireIcon(parent)
    local icon = table.remove(iconPool)
    if not icon then
        icon = CreateFrame("Button", nil, parent)
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:EnableMouse(true)

        -- 2px border: background fills full area, item texture inset on top
        local borderTex = icon:CreateTexture(nil, "BACKGROUND")
        borderTex:SetAllPoints()
        icon.borderTex = borderTex

        local tex = icon:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", 2, -2)
        tex:SetPoint("BOTTOMRIGHT", -2, 2)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon.tex = tex

        local tierBadge = icon:CreateFontString(nil, "OVERLAY")
        local fontPath = GameFontNormal:GetFont()
        tierBadge:SetFont(fontPath, 10, "OUTLINE")
        tierBadge:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 2, 2)
        tierBadge:Hide()
        icon.tierBadge = tierBadge

        -- Favorite star (larger, yellow border style)
        local favStar = icon:CreateTexture(nil, "OVERLAY", nil, 2)
        favStar:SetSize(18, 18)
        favStar:SetPoint("TOPLEFT", icon, "TOPLEFT", -4, 4)
        favStar:SetAtlas("PetJournal-FavoritesIcon")
        favStar:SetVertexColor(1.0, 0.82, 0.0)
        favStar:Hide()
        icon.favStar = favStar

        -- Upgrade marker: how many item levels this drop gains over what
        -- you have equipped in that slot. Sits bottom-left so it never
        -- collides with the tier badge or the favourite star.
        local upgradeText = icon:CreateFontString(nil, "OVERLAY", nil, 3)
        upgradeText:SetFont(GameFontNormal:GetFont(), 10, "OUTLINE")
        upgradeText:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -2, -3)
        upgradeText:Hide()
        icon.upgradeText = upgradeText

        icon:SetScript("OnEnter", function(self)
            if self.itemLink or self.itemID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                -- Prefer the journal's link: it carries the bonus IDs that
                -- give the difficulty-correct item level. But an
                -- uncached item makes SetHyperlink produce nothing at
                -- all, which is why some rows looked un-hoverable until
                -- the item happened to load. Fall back to the itemID and
                -- request a load so the next hover is right.
                local resolved = false
                if self.itemLink then
                    GameTooltip:SetHyperlink(self.itemLink)
                    resolved = GameTooltip:NumLines() > 0
                end
                if not resolved and self.itemID then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetItemByID(self.itemID)
                    if C_Item and C_Item.RequestLoadItemDataByID then
                        C_Item.RequestLoadItemDataByID(self.itemID)
                    end
                end
                if self._upgrade then
                    local u = self._upgrade
                    -- Bring Blizzard's own item level line in line with the
                    -- selected difficulty before we add our own.
                    if u.expected then
                        RewriteTooltipIlvl(GameTooltip, u.expected, u.rank, u.diffLabel)
                    end
                    local at = u.diffLabel and (" on " .. u.diffLabel) or ""
                    -- Show the upgrade track rank too: "Champion 3/6" is
                    -- how players actually reason about a drop's worth.
                    local rank = u.rank and ("  |cff888888(%s)|r"):format(u.rank) or ""
                    GameTooltip:AddLine(" ")
                    if u.equipped == 0 then
                        GameTooltip:AddLine(("|cff40ff40Drops at %d%s|r%s — that slot is empty.")
                            :format(u.expected, at, rank))
                    elseif u.isUpgrade then
                        GameTooltip:AddLine(("|cff40ff40Drops at %d%s — +%d over your %d.|r%s")
                            :format(u.expected, at, u.delta, u.equipped, rank))
                    elseif u.delta == 0 then
                        GameTooltip:AddLine(("|cffffcc00Drops at %d%s — same as equipped.|r%s")
                            :format(u.expected, at, rank))
                    else
                        GameTooltip:AddLine(("|cff888888Drops at %d%s — %d below your %d.|r%s")
                            :format(u.expected, at, -u.delta, u.equipped, rank))
                    end
                    if u.journalIlvl then
                        GameTooltip:AddLine(("|cff888888Encounter Journal says %d for this key level.|r")
                            :format(u.journalIlvl))
                    end
                    if u.vault and u.vault ~= u.expected then
                        GameTooltip:AddLine(("|cff888888From the Great Vault: %d%s.|r")
                            :format(u.vault,
                                u.vaultRank and (" (" .. u.vaultRank .. ")") or ""))
                    end
                    if u.mythNine then
                        GameTooltip:AddLine("|cffff8000Myth 9 boss|r — highest item level in the raid.")
                    end
                end
                if self.itemID then
                    GameTooltip:AddLine(" ")
                    if ns:IsLootFavorite(self.itemID) then
                        GameTooltip:AddLine("|cffFFD100Click to unfavorite|r")
                    else
                        GameTooltip:AddLine("|cffFFD100Click to favorite|r")
                    end
                end
                GameTooltip:Show()
            end
        end)
        icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

        icon:RegisterForClicks("LeftButtonUp")
        icon:SetScript("OnClick", function(self, button)
            if IsModifiedClick("CHATLINK") and self.itemLink then
                ChatEdit_InsertLink(self.itemLink)
                return
            end
            if self.itemID then
                ns:ToggleLootFavorite(self.itemID)
                local isFav = ns:IsLootFavorite(self.itemID)
                if isFav then
                    self.favStar:Show()
                    self.borderTex:SetColorTexture(1.0, 0.82, 0.0, 1.0)
                else
                    self.favStar:Hide()
                    -- Restore difficulty border
                    local diffColor = self._diffColor
                    if diffColor then
                        self.borderTex:SetColorTexture(diffColor.r, diffColor.g, diffColor.b, 1.0)
                    else
                        self.borderTex:SetColorTexture(0.3, 0.3, 0.3, 1.0)
                    end
                end
                -- Refresh if in favorites mode
                if ns.lootBrowserState.isFavoritesMode and ns.LootBrowser_RefreshDisplay then
                    C_Timer.After(0, function() ns:LootBrowser_RefreshDisplay() end)
                end
                -- Update slot dropdown badge
                if ns.LootBrowser_UpdateSlotDropdown then ns:LootBrowser_UpdateSlotDropdown() end
            end
        end)
    end

    icon:SetParent(parent)
    icon:ClearAllPoints()

    -- Full state reset. Boss portraits are drawn from this same pool and
    -- mutate size, mouse handling, border tint and tex coords; without
    -- resetting all four, a recycled portrait reappears as an item icon
    -- that is uncropped, mis-sized and — because EnableMouse was left
    -- false — silently un-hoverable.
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:EnableMouse(true)
    icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.tex:SetTexture(nil)
    icon.borderTex:SetColorTexture(0.3, 0.3, 0.3, 1.0)

    icon.tierBadge:Hide()
    icon.favStar:Hide()
    icon.upgradeText:Hide()
    icon.itemID = nil
    icon.itemLink = nil
    icon._upgrade = nil
    icon._mythNine = nil
    icon._diffID = nil
    icon._diffColor = nil
    icon:Show()
    table.insert(activeIcons, icon)
    return icon
end

local function AcquireLabel(parent)
    local label = table.remove(labelPool)
    if not label then
        label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    end
    label:SetParent(parent)
    label:ClearAllPoints()
    label:SetText("")
    label:SetWidth(0)
    label:SetWordWrap(false)
    label:Show()
    table.insert(activeLabels, label)
    return label
end

local function ReleaseAll()
    GameTooltip:Hide()
    for _, r in ipairs(activeRows) do r:Hide(); r:ClearAllPoints(); r.dungBg:Hide(); table.insert(rowPool, r) end
    wipe(activeRows)
    for _, ic in ipairs(activeIcons) do ic:Hide(); ic:ClearAllPoints(); ic.itemLink = nil; ic.itemID = nil; ic._diffColor = nil; ic:SetSize(ICON_SIZE, ICON_SIZE); ic.tierBadge:Hide(); ic.favStar:Hide(); ic.tex:SetTexture(nil); table.insert(iconPool, ic) end
    wipe(activeIcons)
    for _, lb in ipairs(activeLabels) do lb:Hide(); lb:ClearAllPoints(); table.insert(labelPool, lb) end
    wipe(activeLabels)
end

------------------------------------------------------------
-- Helper: create a filter chip button
------------------------------------------------------------
local function MakeChip(parent, text, width, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, 24)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    btn:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
    ns.SmoothFrame(btn)
    ns.AddGlowHighlight(btn, 0.06)

    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("CENTER")
    lbl:SetText(text)
    lbl:SetTextColor(unpack(ns.COLORS.TEXT_SECONDARY))
    ns.ApplyTextShadow(lbl)
    btn.label = lbl

    btn:SetScript("OnClick", onClick)
    return btn
end

------------------------------------------------------------
-- Layout helper
------------------------------------------------------------
local function UpdateLayout(f)
    -- In-app mode: nest inside the page's inner panel (starts at -10 from
    -- page top). Offset the filter card a bit below that so it fits cleanly.
    local topY = f.inAppMode and 10 or HEADER_H
    local hPad = f.inAppMode and 0 or PAD

    f._filterCard:ClearAllPoints()
    f._filterCard:SetPoint("TOPLEFT", f, "TOPLEFT", hPad, -topY)
    f._filterCard:SetPoint("TOPRIGHT", f, "TOPRIGHT", -hPad, -topY)

    -- In-app mode: no card border/background — just a bottom divider line.
    if f.inAppMode then
        f._filterCard:SetBackdrop(nil)
        if not f._filterDivider then
            local div = f._filterCard:CreateTexture(nil, "OVERLAY")
            div:SetColorTexture(0.35, 0.35, 0.35, 0.8)
            div:SetHeight(1)
            div:SetPoint("BOTTOMLEFT", f._filterCard, "BOTTOMLEFT", 0, 0)
            div:SetPoint("BOTTOMRIGHT", f._filterCard, "BOTTOMRIGHT", 0, 0)
            f._filterDivider = div
        end
        f._filterDivider:Show()
    else
        f._filterCard:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets   = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        f._filterCard:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
        f._filterCard:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
        if f._filterDivider then f._filterDivider:Hide() end
    end

    f._viewTabBar:ClearAllPoints()
    local tabGap = f.inAppMode and 0 or -4
    f._viewTabBar:SetPoint("TOPLEFT", f._filterCard, "BOTTOMLEFT", 0, tabGap)
    f._viewTabBar:SetPoint("TOPRIGHT", f._filterCard, "BOTTOMRIGHT", 0, tabGap)

    f._content:ClearAllPoints()
    f._content:SetPoint("TOPLEFT", f._viewTabBar, "BOTTOMLEFT", -hPad, -2)
    f._content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 4)
    f._content:SetClipsChildren(true)
end

------------------------------------------------------------
-- Create Main Loot Browser Frame
------------------------------------------------------------
function ns:CreateLootBrowserFrame()
    if ns.LootBrowserFrame then return end

    local FRAME_W, FRAME_H = ns:GetAppFrameSize()

    local f = CreateFrame("Frame", "YippYappLootBrowser", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
    f:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    ns.SmoothFrame(f)
    f:Hide()
    ns.LootBrowserFrame = f

    -- Standalone header
    local titleIcon, titleFs = ns.MakeWindowHeader(f, "|cff00ccffLoot Browser|r", nil, PAD)
    f._titleFs = titleFs
    f._titleIcon = titleIcon

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    f._closeBtn = closeBtn

    -- ================================================================
    -- FILTER CARD (spec dropdown + slot dropdown + stats in one row)
    -- ================================================================
    local filterCard = CreateFrame("Frame", nil, f, "BackdropTemplate")
    filterCard:SetHeight(FILTER_H)
    filterCard:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -HEADER_H)
    filterCard:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -HEADER_H)
    filterCard:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    filterCard:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    filterCard:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
    ns.SmoothFrame(filterCard)
    f._filterCard = filterCard

    -- ============ CLASS DROPDOWN ============
    -- No "Class:" / "Spec:" / "Slot:" / "Stats:" captions. Each control
    -- already shows its own value ("Druid", "Balance", "All Slots"), so
    -- the labels only cost horizontal space.

    local classBtn = CreateFrame("Button", nil, filterCard, "BackdropTemplate")
    classBtn:SetSize(130, 24)
    classBtn:SetPoint("LEFT", 10, 0)
    classBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    classBtn:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
    classBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
    ns.SmoothFrame(classBtn)
    ns.AddGlowHighlight(classBtn, 0.06)

    local classNameFs = classBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    classNameFs:SetPoint("LEFT", 6, 0)
    ns.ApplyTextShadow(classNameFs)
    classBtn._nameFs = classNameFs
    f._classBtn = classBtn

    local classArrow = classBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    classArrow:SetPoint("RIGHT", -4, 0)
    classArrow:SetTextColor(unpack(ns.COLORS.TEXT_TERTIARY))
    classArrow:SetText("v")

    local classDropdown = CreateFrame("Frame", "YippYappLootClassDropdown", UIParent, "BackdropTemplate")
    classDropdown:SetSize(160, 10)
    classDropdown:SetFrameStrata("DIALOG")
    classDropdown:SetClampedToScreen(true)
    classDropdown:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    classDropdown:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
    classDropdown:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    ns.SmoothFrame(classDropdown)
    classDropdown:EnableMouse(true)
    classDropdown:Hide()
    f._classDropdown = classDropdown

    classDropdown:SetScript("OnShow", function() tinsert(UISpecialFrames, "YippYappLootClassDropdown") end)
    classDropdown:SetScript("OnHide", function()
        for i = #UISpecialFrames, 1, -1 do
            if UISpecialFrames[i] == "YippYappLootClassDropdown" then
                table.remove(UISpecialFrames, i); break
            end
        end
    end)

    local classRows = {}
    do
        local y = 6
        for ci = 1, GetNumClasses() do
            local className, classFile, classID = GetClassInfo(ci)
            if className and classID then
                local row = CreateFrame("Button", nil, classDropdown)
                row:SetSize(148, 22)
                row:SetPoint("TOPLEFT", 6, -y)
                local hl = row:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.05); hl:SetBlendMode("ADD")
                local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                fs:SetPoint("LEFT", 6, 0)
                local hex = (RAID_CLASS_COLORS[classFile] and RAID_CLASS_COLORS[classFile].colorStr) or "ffffffff"
                fs:SetText("|c" .. hex .. className .. "|r")
                row._check = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row._check:SetPoint("RIGHT", -4, 0)
                row.classID = classID
                row:SetScript("OnClick", function(self)
                    classDropdown:Hide()
                    ns:LootBrowser_SwitchClass(self.classID)
                end)
                table.insert(classRows, row)
                y = y + 22
            end
        end
        classDropdown:SetHeight(y + 4)
    end

    classBtn:SetScript("OnClick", function(self)
        if classDropdown:IsShown() then
            classDropdown:Hide()
        else
            for _, row in ipairs(classRows) do
                row._check:SetText(row.classID == ns.lootBrowserState.selectedClassID and "|cff00ccff>|r" or "")
            end
            classDropdown:ClearAllPoints()
            classDropdown:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
            classDropdown:Show()
        end
    end)
    classBtn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.0, 0.8, 1.0, 0.6) end)
    classBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5) end)

    local classDiv = filterCard:CreateTexture(nil, "ARTWORK")
    classDiv:SetSize(1, 20)
    classDiv:SetPoint("LEFT", classBtn, "RIGHT", 10, 0)
    classDiv:SetColorTexture(0.25, 0.25, 0.25, 0.5)

    -- ============ SPEC DROPDOWN ============
    local specBtn = CreateFrame("Button", nil, filterCard, "BackdropTemplate")
    specBtn:SetSize(140, 24)
    specBtn:SetPoint("LEFT", classDiv, "RIGHT", 10, 0)
    specBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    specBtn:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
    specBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
    ns.SmoothFrame(specBtn)
    ns.AddGlowHighlight(specBtn, 0.06)

    local specIcon = specBtn:CreateTexture(nil, "ARTWORK")
    specIcon:SetSize(16, 16)
    specIcon:SetPoint("LEFT", 4, 0)
    specIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    specBtn._icon = specIcon

    local specNameFs = specBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    specNameFs:SetPoint("LEFT", specIcon, "RIGHT", 4, 0)
    ns.ApplyTextShadow(specNameFs)
    specBtn._nameFs = specNameFs

    local specArrow = specBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    specArrow:SetPoint("RIGHT", -4, 0)
    specArrow:SetTextColor(unpack(ns.COLORS.TEXT_TERTIARY))
    specArrow:SetText("v")
    f._specBtn = specBtn

    -- Spec dropdown popup
    local specDropdown = CreateFrame("Frame", "YippYappLootSpecDropdown", UIParent, "BackdropTemplate")
    specDropdown:SetSize(160, 10)
    specDropdown:SetFrameStrata("DIALOG")
    specDropdown:SetClampedToScreen(true)
    specDropdown:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    specDropdown:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
    specDropdown:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    ns.SmoothFrame(specDropdown)
    specDropdown:EnableMouse(true)
    specDropdown:Hide()
    f._specDropdown = specDropdown

    specDropdown:SetScript("OnShow", function()
        tinsert(UISpecialFrames, "YippYappLootSpecDropdown")
    end)
    specDropdown:SetScript("OnHide", function()
        for i = #UISpecialFrames, 1, -1 do
            if UISpecialFrames[i] == "YippYappLootSpecDropdown" then
                table.remove(UISpecialFrames, i)
                break
            end
        end
    end)

    local specRows = {}
    local ddY = 6
    for si = 1, 4 do
        local row = CreateFrame("Button", nil, specDropdown)
        row:SetSize(148, 26)
        row:SetPoint("TOPLEFT", 6, -ddY)

        local rowHl = row:CreateTexture(nil, "HIGHLIGHT")
        rowHl:SetAllPoints()
        rowHl:SetColorTexture(1, 1, 1, 0.05)
        rowHl:SetBlendMode("ADD")

        local rowIcon = row:CreateTexture(nil, "ARTWORK")
        rowIcon:SetSize(18, 18)
        rowIcon:SetPoint("LEFT", 4, 0)
        rowIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row._icon = rowIcon

        local rowName = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rowName:SetPoint("LEFT", rowIcon, "RIGHT", 6, 0)
        ns.ApplyTextShadow(rowName)
        row._nameFs = rowName

        local rowCheck = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rowCheck:SetPoint("RIGHT", -4, 0)
        row._check = rowCheck

        row.specIndex = si
        row:SetScript("OnClick", function(self)
            specDropdown:Hide()
            ns:LootBrowser_SwitchSpec(self.specIndex)
        end)
        row:Hide()
        specRows[si] = row
        ddY = ddY + 26
    end
    specDropdown:SetHeight(ddY + 4)
    f._specRows = specRows

    specBtn:SetScript("OnClick", function(self)
        if specDropdown:IsShown() then
            specDropdown:Hide()
        else
            local classID = ns.lootBrowserState.selectedClassID
            local numSpecs = classID and GetNumSpecializationsForClassID(classID) or 0
            local ddH = 6
            for i = 1, 4 do
                local row = specRows[i]
                if i <= numSpecs then
                    local specID, specName, _, specIcon2 = GetSpecializationInfoForClassID(classID, i)
                    if specID then
                        row._icon:SetTexture(specIcon2)
                        local isActive = (ns.lootBrowserState.selectedSpecIndex == i)
                        if isActive then
                            row._nameFs:SetText("|cff00ccff" .. specName .. "|r")
                            row._check:SetText("|cff00ccff>|r")
                        else
                            row._nameFs:SetText("|cffaaaaaa" .. specName .. "|r")
                            row._check:SetText("")
                        end
                        row:Show()
                        ddH = ddH + 26
                    else
                        row:Hide()
                    end
                else
                    row:Hide()
                end
            end
            specDropdown:SetHeight(ddH + 4)
            specDropdown:ClearAllPoints()
            specDropdown:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
            specDropdown:Show()
        end
    end)
    specBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.0, 0.8, 1.0, 0.6)
    end)
    specBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
    end)

    -- Divider between spec and slot
    local div1 = filterCard:CreateTexture(nil, "ARTWORK")
    div1:SetSize(1, 20)
    div1:SetPoint("LEFT", specBtn, "RIGHT", 10, 0)
    div1:SetColorTexture(0.25, 0.25, 0.25, 0.5)

    -- ============ SLOT DROPDOWN ============
    local slotBtn = CreateFrame("Button", nil, filterCard, "BackdropTemplate")
    slotBtn:SetSize(120, 24)
    slotBtn:SetPoint("LEFT", div1, "RIGHT", 10, 0)
    slotBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    slotBtn:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
    slotBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
    ns.SmoothFrame(slotBtn)
    ns.AddGlowHighlight(slotBtn, 0.06)

    local slotBtnFs = slotBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotBtnFs:SetPoint("LEFT", 6, 0)
    ns.ApplyTextShadow(slotBtnFs)
    slotBtnFs:SetText("|cff00ccffHead|r")
    slotBtn._nameFs = slotBtnFs

    local slotArrow = slotBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotArrow:SetPoint("RIGHT", -4, 0)
    slotArrow:SetTextColor(unpack(ns.COLORS.TEXT_TERTIARY))
    slotArrow:SetText("v")
    f._slotBtn = slotBtn

    -- Slot dropdown popup
    local slotDropdown = CreateFrame("Frame", "YippYappLootSlotDropdown", UIParent, "BackdropTemplate")
    slotDropdown:SetSize(160, 10)
    slotDropdown:SetFrameStrata("DIALOG")
    slotDropdown:SetClampedToScreen(true)
    slotDropdown:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    slotDropdown:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
    slotDropdown:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    ns.SmoothFrame(slotDropdown)
    slotDropdown:EnableMouse(true)
    slotDropdown:Hide()
    f._slotDropdown = slotDropdown

    slotDropdown:SetScript("OnShow", function()
        tinsert(UISpecialFrames, "YippYappLootSlotDropdown")
    end)
    slotDropdown:SetScript("OnHide", function()
        for i = #UISpecialFrames, 1, -1 do
            if UISpecialFrames[i] == "YippYappLootSlotDropdown" then
                table.remove(UISpecialFrames, i)
                break
            end
        end
    end)

    -- Build slot dropdown rows: Favorites + separator + 14 slots
    -- Favorites is a toggle of its own (see the star button below), not a
    -- slot — burying it in a list of equipment slots made it hard to find
    -- and impossible to flick on and off.
    local SLOT_DD_ENTRIES = {
        { name = "All Slots", filter = "ALL_SLOTS", isAllSlots = true },
    }
    for _, sf in ipairs(ns.LOOT_SLOT_FILTERS) do
        table.insert(SLOT_DD_ENTRIES, { name = sf.name, filter = sf.filter })
    end

    local slotDDRows = {}
    local sdY = 6
    for idx, entry in ipairs(SLOT_DD_ENTRIES) do
        -- Separator after special entries (Favorites + All Slots)
        if idx == 2 then
            local sep = slotDropdown:CreateTexture(nil, "ARTWORK")
            sep:SetHeight(1)
            sep:SetPoint("TOPLEFT", 8, -sdY)
            sep:SetPoint("TOPRIGHT", -8, -sdY)
            sep:SetColorTexture(0.25, 0.25, 0.25, 0.5)
            sdY = sdY + 6
        end

        local row = CreateFrame("Button", nil, slotDropdown)
        row:SetSize(148, 22)
        row:SetPoint("TOPLEFT", 6, -sdY)

        local rowHl = row:CreateTexture(nil, "HIGHLIGHT")
        rowHl:SetAllPoints()
        rowHl:SetColorTexture(1, 1, 1, 0.05)
        rowHl:SetBlendMode("ADD")

        local rowName = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rowName:SetPoint("LEFT", 6, 0)
        ns.ApplyTextShadow(rowName)
        row._nameFs = rowName

        local rowCheck = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rowCheck:SetPoint("RIGHT", -4, 0)
        row._check = rowCheck

        -- Badge for favorites count
        local rowBadge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rowBadge:SetPoint("RIGHT", rowCheck, "LEFT", -4, 0)
        rowBadge:SetTextColor(unpack(ns.COLORS.TEXT_TERTIARY))
        rowBadge:Hide()
        row._badge = rowBadge

        row._entry = entry
        row:SetScript("OnClick", function(self)
            slotDropdown:Hide()
            ns:LootBrowser_SwitchSlot(self._entry.filter, self._entry.name)
        end)

        slotDDRows[idx] = row
        sdY = sdY + 22
    end
    slotDropdown:SetHeight(sdY + 6)
    f._slotDDRows = slotDDRows

    slotBtn:SetScript("OnClick", function(self)
        if slotDropdown:IsShown() then
            slotDropdown:Hide()
        else
            for _, row in ipairs(slotDDRows) do
                local entry = row._entry
                local isActive
                -- Favorites is no longer a dropdown row; it lives on the
                -- star toggle beside this button.
                if entry.isAllSlots then
                    isActive = ns.lootBrowserState.isAllSlots
                    row._badge:Hide()
                else
                    isActive = (not ns.lootBrowserState.isFavoritesMode and not ns.lootBrowserState.isAllSlots and ns.lootBrowserState.selectedSlot == entry.filter)
                    row._badge:Hide()
                end

                if isActive then
                    row._nameFs:SetText("|cff00ccff" .. entry.name .. "|r")
                    row._check:SetText("|cff00ccff>|r")
                else
                    row._nameFs:SetText("|cffaaaaaa" .. entry.name .. "|r")
                    row._check:SetText("")
                end
            end

            slotDropdown:ClearAllPoints()
            slotDropdown:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
            slotDropdown:Show()
        end
    end)
    slotBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.0, 0.8, 1.0, 0.6)
    end)
    slotBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
    end)

    -- ============ FAVORITES TOGGLE ============
    local favBtn = CreateFrame("Button", nil, filterCard, "BackdropTemplate")
    favBtn:SetSize(30, 24)
    favBtn:SetPoint("LEFT", slotBtn, "RIGHT", 6, 0)
    favBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    ns.SmoothFrame(favBtn)
    ns.AddGlowHighlight(favBtn, 0.06)

    local favStar = favBtn:CreateTexture(nil, "ARTWORK")
    favStar:SetSize(16, 16)
    favStar:SetPoint("CENTER", 0, 0)
    favStar:SetAtlas("PetJournal-FavoritesIcon")
    favBtn._star = favStar

    local favCount = favBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    favCount:SetPoint("BOTTOMRIGHT", favBtn, "BOTTOMRIGHT", -2, 1)
    favBtn._count = favCount

    favBtn:SetScript("OnClick", function()
        local st = ns.lootBrowserState
        if st.isFavoritesMode then
            -- Toggling off returns to All Slots rather than a random slot.
            ns:LootBrowser_SwitchSlot("ALL_SLOTS", "All Slots")
        else
            ns:LootBrowser_SwitchSlot("FAVORITES", "Favorites")
        end
    end)
    favBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Favorites")
        GameTooltip:AddLine("Show only items you have starred.", 1, 1, 1, true)
        GameTooltip:AddLine("Click any item icon to star it.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    favBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f._favBtn = favBtn

    -- Divider between slot and stats
    local div2 = filterCard:CreateTexture(nil, "ARTWORK")
    div2:SetSize(1, 20)
    div2:SetPoint("LEFT", favBtn, "RIGHT", 10, 0)
    div2:SetColorTexture(0.25, 0.25, 0.25, 0.5)

    -- ============ STAT FILTER CHIPS ============
    local statAllBtn = MakeChip(filterCard, "All", 36, function() ns:LootBrowser_ClearStats() end)
    statAllBtn:SetPoint("LEFT", div2, "RIGHT", 10, 0)
    f._statAllBtn = statAllBtn

    local statButtons = {}
    for i, statInfo in ipairs(ns.LOOT_SECONDARY_STATS) do
        local btn = MakeChip(filterCard, statInfo.short, 52, function(self)
            ns:LootBrowser_ToggleStat(self.statKey)
        end)
        btn.statKey = statInfo.key
        if i == 1 then
            btn:SetPoint("LEFT", statAllBtn, "RIGHT", 4, 0)
        else
            btn:SetPoint("LEFT", statButtons[i - 1], "RIGHT", 4, 0)
        end
        statButtons[i] = btn
    end
    f._statButtons = statButtons

    -- ================================================================
    -- VIEW TABS (Dungeons / Raids)
    -- ================================================================
    local viewTabBar = CreateFrame("Frame", nil, f)
    viewTabBar:SetHeight(VIEW_TAB_H)
    viewTabBar:SetPoint("TOPLEFT", filterCard, "BOTTOMLEFT", 0, -4)
    viewTabBar:SetPoint("TOPRIGHT", filterCard, "BOTTOMRIGHT", 0, -4)
    f._viewTabBar = viewTabBar

    local dungeonTab = ns.CreateUnderlineTab(viewTabBar, "Dungeons", { 0.0, 0.8, 1.0 })
    dungeonTab:SetSize(100, VIEW_TAB_H)
    dungeonTab:SetPoint("TOPLEFT", 4, 0)
    dungeonTab:SetScript("OnClick", function()
        ns:LootBrowser_SwitchView("dungeon")
    end)
    f._dungeonTab = dungeonTab

    local raidTab = ns.CreateUnderlineTab(viewTabBar, "Raids", { 0.0, 0.8, 1.0 })
    raidTab:SetSize(100, VIEW_TAB_H)
    raidTab:SetPoint("TOPLEFT", dungeonTab, "TOPRIGHT", 4, 0)
    raidTab:SetScript("OnClick", function()
        ns:LootBrowser_SwitchView("raid")
    end)
    f._raidTab = raidTab

    -- ============ DIFFICULTY SELECTOR (right-aligned) ============
    -- Drives the item level every drop is priced at, and therefore the
    -- upgrade comparison. Without it the browser only ever showed the
    -- journal's fixed value (M0 for dungeons), which stops being useful
    -- the moment you run keys.
    local diffBtn = MakeChip(viewTabBar, "Mythic 0", 118, function(self)
        local dd = f._diffDropdown
        if dd:IsShown() then dd:Hide() else
            ns:LootBrowser_BuildDifficultyDropdown()
            dd:Show()
        end
    end)
    diffBtn:SetPoint("RIGHT", viewTabBar, "RIGHT", -6, 0)
    diffBtn.tooltipText = "Pick the difficulty to price drops at. Upgrade markers compare against it."
    f._diffBtn = diffBtn

    -- "Drops at:" described the effect but not the control, so it read as
    -- part of the value rather than as a label. Name the thing.
    local diffLabel = viewTabBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    diffLabel:SetPoint("RIGHT", diffBtn, "LEFT", -6, 0)
    diffLabel:SetTextColor(unpack(ns.COLORS.TEXT_TERTIARY))
    diffLabel:SetText("Difficulty:")
    ns.ApplyTextShadow(diffLabel)

    local upgradesChip = MakeChip(viewTabBar, "Upgrades", 78, function(self)
        YippYappHelperDB = YippYappHelperDB or {}
        local cur = YippYappHelperDB.lootShowUpgrades
        if type(cur) ~= "boolean" then cur = true end
        YippYappHelperDB.lootShowUpgrades = not cur
        ns:LootBrowser_UpdateDisplayToggles()
        ns:LootBrowser_RefreshDisplay()
    end)
    upgradesChip:SetPoint("RIGHT", diffLabel, "LEFT", -10, 0)
    upgradesChip.tooltipText = "Mark drops that beat what you have equipped in that slot."
    f._upgradesChip = upgradesChip

    for _, chip in ipairs({ upgradesChip, diffBtn }) do
        chip:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(self.tooltipText, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- Difficulty dropdown panel (rows rebuilt per view)
    local diffDropdown = CreateFrame("Frame", "YippYappLootDiffDropdown", f,
        "BackdropTemplate")
    diffDropdown:SetSize(150, 40)
    diffDropdown:SetPoint("TOPRIGHT", diffBtn, "BOTTOMRIGHT", 0, -2)
    diffDropdown:SetFrameStrata("DIALOG")
    diffDropdown:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    diffDropdown:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
    diffDropdown:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    ns.SmoothFrame(diffDropdown)
    diffDropdown:EnableMouse(true)
    diffDropdown:Hide()
    diffDropdown._rows = {}
    f._diffDropdown = diffDropdown

    diffDropdown:SetScript("OnShow", function()
        tinsert(UISpecialFrames, "YippYappLootDiffDropdown")
    end)
    diffDropdown:SetScript("OnHide", function()
        for i = #UISpecialFrames, 1, -1 do
            if UISpecialFrames[i] == "YippYappLootDiffDropdown" then
                table.remove(UISpecialFrames, i)
                break
            end
        end
    end)

    -- ================================================================
    -- CONTENT AREA (no scroll — content fits within frame)
    -- ================================================================
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", viewTabBar, "BOTTOMLEFT", 0, -4)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 8)
    f._content = content

    local loadingText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    loadingText:SetPoint("CENTER")
    loadingText:SetText("|cff555555Scanning loot...|r")
    loadingText:Hide()
    f._loadingText = loadingText

    local noItemsText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    noItemsText:SetPoint("CENTER")
    noItemsText:Hide()
    f._noItemsText = noItemsText

    -- ESC + cleanup
    f:SetScript("OnShow", function()
        if f.inAppMode then return end
        tinsert(UISpecialFrames, "YippYappLootBrowser")
    end)
    f:SetScript("OnHide", function()
        ReleaseAll()
        GameTooltip:Hide()
        if f._specDropdown then f._specDropdown:Hide() end
        if f._slotDropdown then f._slotDropdown:Hide() end
        for i = #UISpecialFrames, 1, -1 do
            if UISpecialFrames[i] == "YippYappLootBrowser" then
                table.remove(UISpecialFrames, i)
                break
            end
        end
    end)
end

------------------------------------------------------------
-- Update filter card state
------------------------------------------------------------
function ns:LootBrowser_UpdateSpecBar()
    local f = ns.LootBrowserFrame
    if not f then return end
    local state = ns.lootBrowserState
    if f._classBtn and state.selectedClassID then
        local className = GetClassInfo(state.selectedClassID)
        local hex = (RAID_CLASS_COLORS[state.selectedClassFile] and
            RAID_CLASS_COLORS[state.selectedClassFile].colorStr) or "ffffffff"
        f._classBtn._nameFs:SetText("|c" .. hex .. (className or "?") .. "|r")
    end
    if f._specBtn and state.selectedClassID and state.selectedSpecIndex then
        local specID, specName, _, specIcon =
            GetSpecializationInfoForClassID(state.selectedClassID, state.selectedSpecIndex)
        if specID then
            f._specBtn._icon:SetTexture(specIcon)
            f._specBtn._nameFs:SetText("|cff00ccff" .. specName .. "|r")
        end
    end
end

function ns:LootBrowser_UpdateSlotDropdown()
    local f = ns.LootBrowserFrame
    if not f or not f._slotBtn then return end
    local state = ns.lootBrowserState

    -- Favorites star: lit gold when active, dim when not, with the number
    -- of starred items tucked into the corner.
    if f._favBtn then
        local count = ns:GetFavoritesCount()
        if state.isFavoritesMode then
            f._favBtn:SetBackdropColor(0.28, 0.22, 0.02, 0.95)
            f._favBtn:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.9)
            f._favBtn._star:SetVertexColor(1.0, 0.82, 0.0)
            f._favBtn._star:SetDesaturated(false)
        else
            f._favBtn:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
            f._favBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
            f._favBtn._star:SetVertexColor(0.55, 0.55, 0.55)
            f._favBtn._star:SetDesaturated(true)
        end
        f._favBtn._count:SetText(count > 0
            and ("|cffFFD100" .. count .. "|r") or "")
    end

    if state.isFavoritesMode then
        local count = ns:GetFavoritesCount()
        if count > 0 then
            f._slotBtn._nameFs:SetText("|cffFFD100Favorites|r |cff888888(" .. count .. ")|r")
        else
            f._slotBtn._nameFs:SetText("|cffFFD100Favorites|r")
        end
    elseif state.isAllSlots then
        f._slotBtn._nameFs:SetText("|cff00ccffAll Slots|r")
    else
        f._slotBtn._nameFs:SetText("|cff00ccff" .. (state.selectedSlotName or "Head") .. "|r")
    end
end

function ns:LootBrowser_UpdateStatBar()
    local f = ns.LootBrowserFrame
    if not f then return end
    local stats = ns.lootBrowserState.selectedStats
    local numSel = #stats

    if numSel == 0 then
        f._statAllBtn:SetBackdropBorderColor(0.0, 0.8, 1.0, 0.6)
        f._statAllBtn.label:SetTextColor(0.0, 0.8, 1.0)
    else
        f._statAllBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
        f._statAllBtn.label:SetTextColor(unpack(ns.COLORS.TEXT_SECONDARY))
    end

    for _, btn in ipairs(f._statButtons) do
        local isSel = false
        for _, key in ipairs(stats) do
            if key == btn.statKey then isSel = true; break end
        end
        if isSel then
            btn:SetBackdropBorderColor(0.0, 0.8, 1.0, 0.6)
            btn.label:SetTextColor(0.0, 0.8, 1.0)
        elseif numSel >= 2 then
            btn:SetBackdropBorderColor(0.15, 0.15, 0.15, 0.5)
            btn.label:SetTextColor(unpack(ns.COLORS.TEXT_TERTIARY))
        else
            btn:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
            btn.label:SetTextColor(unpack(ns.COLORS.TEXT_SECONDARY))
        end
    end
end

function ns:LootBrowser_UpdateViewTabs()
    local f = ns.LootBrowserFrame
    if not f then return end
    local view = ns.lootBrowserState.selectedView
    if view == "dungeon" then
        ns.SetTabActive(f._dungeonTab)
        ns.SetTabInactive(f._raidTab)
    else
        ns.SetTabInactive(f._dungeonTab)
        ns.SetTabActive(f._raidTab)
    end
end

------------------------------------------------------------
-- Show / Refresh
------------------------------------------------------------
------------------------------------------------------------
-- Difficulty dropdown + display toggles
------------------------------------------------------------
function ns:LootBrowser_BuildDifficultyDropdown()
    local f = ns.LootBrowserFrame
    if not f or not f._diffDropdown then return end
    local dd = f._diffDropdown

    local view = ns.lootBrowserState.selectedView or "dungeon"
    local choices = ns:GetLootDifficultyChoices(view)
    local current = ns:GetSelectedLootDifficulty(view)

    for _, row in ipairs(dd._rows) do row:Hide() end

    local y = 6
    for i, choice in ipairs(choices) do
        local row = dd._rows[i]
        if not row then
            row = CreateFrame("Button", nil, dd)
            row:SetSize(138, 20)
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.06)
            hl:SetBlendMode("ADD")
            row._name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row._name:SetPoint("LEFT", 6, 0)
            row._ilvl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row._ilvl:SetPoint("RIGHT", -6, 0)
            dd._rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 6, -y)

        local isCurrent = current and current.key == choice.key
        row._name:SetText(choice.label)
        row._name:SetTextColor(isCurrent and 0.4 or 0.85,
                               isCurrent and 0.85 or 0.85,
                               isCurrent and 1.0 or 0.85)
        row._ilvl:SetText("|cff888888" .. tostring(choice.ilvl or "?") .. "|r")

        row._key = choice.key
        row:SetScript("OnClick", function(self)
            ns:SetSelectedLootDifficulty(view, self._key)
            dd:Hide()
            ns:LootBrowser_UpdateDisplayToggles()
            ns:LootBrowser_RefreshDisplay()
        end)
        row:Show()
        y = y + 20
    end

    dd:SetHeight(y + 6)
end

function ns:LootBrowser_UpdateDisplayToggles()
    local f = ns.LootBrowserFrame
    if not f or not f._upgradesChip then return end

    YippYappHelperDB = YippYappHelperDB or {}

    local function style(chip, on)
        if on then
            chip:SetBackdropColor(0.05, 0.20, 0.28, 0.9)
            chip:SetBackdropBorderColor(0.0, 0.8, 1.0, 0.8)
            chip.label:SetTextColor(0.6, 0.9, 1.0)
        else
            chip:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
            chip:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
            chip.label:SetTextColor(unpack(ns.COLORS.TEXT_SECONDARY))
        end
    end

    style(f._upgradesChip, YippYappHelperDB.lootShowUpgrades ~= false)

    -- The button shows the chosen difficulty and what it drops at, so the
    -- number every upgrade marker is measured against is always on screen.
    if f._diffBtn then
        local view = ns.lootBrowserState.selectedView or "dungeon"
        local c = ns:GetSelectedLootDifficulty(view)
        if c then
            f._diffBtn.label:SetText(("%s  |cff888888%d|r")
                :format(c.label, c.ilvl or 0))
            f._diffBtn.label:SetTextColor(0.85, 0.85, 0.85)
        end
        if f._diffDropdown and f._diffDropdown:IsShown() then
            ns:LootBrowser_BuildDifficultyDropdown()
        end
    end
end

function ns:LootBrowser_ShowPage()
    local f = ns.LootBrowserFrame
    if not f then return end

    ns:LootBrowser_UpdateSpecBar()
    ns:LootBrowser_UpdateSlotDropdown()
    ns:LootBrowser_UpdateStatBar()
    ns:LootBrowser_UpdateViewTabs()
    ns:LootBrowser_UpdateDisplayToggles()
    ns:LootBrowser_RefreshDisplay()
end

------------------------------------------------------------
-- Render helper: source type color
------------------------------------------------------------
local SOURCE_COLORS = {
    dungeon   = { 0.12, 0.75, 0.12 },
    raid      = { 0.64, 0.21, 0.93 },
    worldboss = { 0.0,  0.44, 0.87 },
}

------------------------------------------------------------
-- Refresh Display
------------------------------------------------------------
function ns:LootBrowser_RefreshDisplay()
    local f = ns.LootBrowserFrame
    if not f then return end

    ReleaseAll()
    f._loadingText:Hide()
    f._noItemsText:Hide()

    local specIndex = ns.lootBrowserState.selectedSpecIndex
    if not specIndex then return end

    f._loadingText:Show()

    local isFavorites = ns.lootBrowserState.isFavoritesMode
    local isAllSlots = ns.lootBrowserState.isAllSlots
    local view = ns.lootBrowserState.selectedView

    -- Build a lookup of shaped data (items per instance name)
    local shapedLookup = {}  -- instanceName -> shaped entry
    -- For raid view, keep raw per-boss results too
    local rawResults = nil

    local statKeys = ns.lootBrowserState.selectedStats
    local hasStatFilter = statKeys and #statKeys > 0

    if isFavorites then
        local shaped = ns:ScanFavoritesLoot()
        if hasStatFilter then shaped = ns:FilterShapedLootByStats(shaped, statKeys) end
        for _, inst in ipairs(shaped) do
            shapedLookup[inst.instanceName] = inst
        end
    elseif isAllSlots then
        -- Scan directly rather than via ScanAllSlotsLoot so we keep the raw
        -- per-boss results. Without them, boss grouping fell back to the
        -- shaped data and every tooltip showed the hardest difficulty
        -- regardless of the difficulty dropdown.
        local results = ns:ScanLootBrowserSlot(specIndex,
            Enum.ItemSlotFilterType.NoFilter) or {}
        if hasStatFilter then
            results = ns:FilterLootByStats(results, statKeys)
        end
        rawResults = results

        local shaped = ns:ReshapeLootByInstance(results)
        for _, inst in ipairs(shaped) do
            shapedLookup[inst.instanceName] = inst
        end
    else
        local slotFilter = ns.lootBrowserState.selectedSlot
        if not slotFilter then
            f._loadingText:Hide()
            return
        end

        local results = ns:ScanLootBrowserSlot(specIndex, slotFilter)

        -- Apply stat filter
        if ns.lootBrowserState.selectedStats and #ns.lootBrowserState.selectedStats > 0 then
            results = ns:FilterLootByStats(results, ns.lootBrowserState.selectedStats)
        end

        -- Keep the raw per-boss results: both views now group by boss.
        rawResults = results

        local shaped = ns:ReshapeLootByInstance(results)
        for _, inst in ipairs(shaped) do
            shapedLookup[inst.instanceName] = inst
        end
    end

    f._loadingText:Hide()

    local cache = ns:GetInstanceCache()
    if not cache then
        f._noItemsText:SetText("|cff555555Could not load instance data. Try /reload.|r")
        f._noItemsText:Show()
        return
    end

    local contentW = f._content:GetWidth()
    if contentW <= 1 then contentW = 800 end
    local itemAreaW = contentW - ITEMS_LEFT - 10
    local maxIconsPerRow = math.floor(itemAreaW / (ICON_SIZE + ICON_GAP))
    if maxIconsPerRow < 1 then maxIconsPerRow = 1 end

    local yOff = 0
    local globalRowIdx = 0

    -- Comparing every drop against equipped gear costs an
    -- ItemLocation lookup per icon, so it is a user toggle rather than
    -- something forced on. Defaults on — it is the reason to open the
    -- browser at all.
    YippYappHelperDB = YippYappHelperDB or {}
    if type(YippYappHelperDB.lootShowUpgrades) ~= "boolean" then
        YippYappHelperDB.lootShowUpgrades = true
    end
    local showUpgrades = YippYappHelperDB.lootShowUpgrades

    -- Helper to render one item row
    local COMPACT_ROW_H = 44
    local COMPACT_ICON  = 30

    -- opts (all optional): sourceName, bossName, mythNine
    local function RenderRow(rowLabel, rowSubLabel, sourceType, bgTexture, items, showDimmed, compact, encounterID, opts)
        opts = opts or {}
        local rowSourceName = opts.sourceName
        local rowBossName   = opts.bossName
        -- Filter out hidden items (housing decor etc) before layout math
        local filtered = {}
        for _, it in ipairs(items or {}) do
            if not (it.itemID and ns:IsLootBrowserHidden(it.itemID)) then
                table.insert(filtered, it)
            end
        end
        items = filtered

        local numItems = #items
        local iconSz = compact and COMPACT_ICON or ICON_SIZE
        local gap    = compact and 8 or ICON_GAP
        local baseH  = compact and COMPACT_ROW_H or ROW_H
        -- Reserve room at both ends for scroll arrows (18px each + 4px padding).
        local ARROW_W = 22
        local trackLeft  = ITEMS_LEFT + ARROW_W
        local trackRight = contentW - ARROW_W
        local trackW = trackRight - trackLeft
        if trackW < iconSz then trackW = iconSz end
        local visibleCount = math.floor((trackW + gap) / (iconSz + gap))
        if visibleCount < 1 then visibleCount = 1 end
        local rowHeight = baseH  -- always single-row now

        local row = AcquireRow(f._content)
        row:SetSize(contentW, rowHeight)
        row:SetPoint("TOPLEFT", f._content, "TOPLEFT", 0, -yOff)

        if globalRowIdx % 2 == 0 then
            row.bg:SetColorTexture(1, 1, 1, 0.02)
        else
            row.bg:SetColorTexture(0, 0, 0, 0)
        end

        if bgTexture then
            row.dungBg:SetTexture(bgTexture)
            row.dungBg:Show()
        end

        -- Boss portrait for raid rows
        local labelXOff = 12
        if encounterID and compact then
            local portrait = AcquireIcon(row)
            local portraitSz = baseH - 8
            portrait:SetSize(portraitSz, portraitSz)
            portrait:SetPoint("LEFT", row, "LEFT", 8, 0)
            portrait.borderTex:SetColorTexture(0, 0, 0, 0)
            local ok, _, _, _, creatureDisplayID = pcall(EJ_GetCreatureInfo, 1, encounterID)
            if ok and creatureDisplayID and creatureDisplayID > 0 then
                SetPortraitTextureFromCreatureDisplayID(portrait.tex, creatureDisplayID)
                portrait.tex:SetTexCoord(0, 1, 0, 1)
            end
            portrait:EnableMouse(false)
            labelXOff = 8 + portraitSz + 6
        end

        if compact then
            row.srcLabel:SetFontObject("GameFontNormalSmall")
        else
            row.srcLabel:SetFontObject("GameFontHighlightMedium")
        end
        row.srcLabel:ClearAllPoints()
        row.srcLabel:SetPoint("LEFT", row, "LEFT", labelXOff, compact and 0 or 4)
        row.srcLabel:SetTextColor(1, 1, 1)
        row.srcLabel:SetText(rowLabel)
        row.srcLabel:SetAlpha(showDimmed and 0.4 or 1)

        if rowSubLabel then
            -- Section headers re-anchor countLabel to the right edge, and
            -- rows come from a shared pool, so restore the default
            -- under-the-title position every time.
            row.countLabel:ClearAllPoints()
            row.countLabel:SetPoint("TOPLEFT", row.srcLabel, "BOTTOMLEFT", 0, -1)
            row.countLabel:SetJustifyH("LEFT")
            row.countLabel:SetText(rowSubLabel)
            row.countLabel:Show()
        end

        -- Create icon frames for all items (positioned during Relayout below)
        local iconYBase = -math.floor((rowHeight - iconSz) / 2)
        for _, item in ipairs(items) do
            local iconFrame = AcquireIcon(row)
            if compact then iconFrame:SetSize(COMPACT_ICON, COMPACT_ICON) end

            if item.itemID and C_Item and C_Item.RequestLoadItemDataByID then
                C_Item.RequestLoadItemDataByID(item.itemID)
            end

            if item.icon then
                iconFrame.tex:SetTexture(item.icon)
            elseif item.itemID then
                local _, _, _, _, iconTex = GetItemInfoInstant(item.itemID)
                iconFrame.tex:SetTexture(iconTex)
            end

            iconFrame.itemLink = item.itemLink
            iconFrame.itemID = item.itemID

            -- Upgrade marker vs. what the player has equipped in that slot.
            -- Mounts and other non-equippable rewards resolve to no slot,
            -- so GetLootUpgradeInfo returns nil and nothing is drawn.
            local upgrade
            if item.itemID and showUpgrades then
                upgrade = ns:GetLootUpgradeInfo(item.itemID, view,
                    item.sourceName or rowSourceName, item.bossName or rowBossName,
                    item.veryRare, item.itemLink)
            end
            iconFrame._upgrade = upgrade
            iconFrame._mythNine = item.mythNine
            iconFrame._diffID = item.diffID
            if upgrade and upgrade.isUpgrade then
                if upgrade.equipped == 0 then
                    iconFrame.upgradeText:SetText("|cff40ff40new|r")
                else
                    iconFrame.upgradeText:SetText(("|cff40ff40+%d|r"):format(upgrade.delta))
                end
                iconFrame.upgradeText:Show()
            end

            -- Border shows ITEM QUALITY, not difficulty.
            --
            -- Difficulty-coloured borders made sense when a row mixed
            -- several difficulties together, but the difficulty is now a
            -- single global selection — so every border was the same and
            -- read as an item-quality lie (epic raid loot rendered green
            -- on Raid Finder). Quality is what a border on an item icon
            -- means everywhere else in the game.
            local isMount = item.itemID and IsMountItem(item.itemID)
            local diffColor = isMount and MOUNT_BORDER_COLOR
                or QualityBorderColor(item.itemID, item.itemLink)
            iconFrame._diffColor = diffColor
            local isFav = item.itemID and ns:IsLootFavorite(item.itemID)
            if isFav then
                iconFrame.borderTex:SetColorTexture(1.0, 0.82, 0.0, 1.0)
                iconFrame.favStar:Show()
            elseif diffColor then
                iconFrame.borderTex:SetColorTexture(diffColor.r, diffColor.g, diffColor.b, 1.0)
            else
                iconFrame.borderTex:SetColorTexture(0.3, 0.3, 0.3, 1.0)
            end

            table.insert(row._itemFrames, iconFrame)
        end

        -- Horizontal-scroll layout: show up to `visibleCount` starting at row._scrollIdx
        local function Relayout()
            local maxStart = math.max(0, numItems - visibleCount)
            if row._scrollIdx < 0 then row._scrollIdx = 0 end
            if row._scrollIdx > maxStart then row._scrollIdx = maxStart end
            for i, frame in ipairs(row._itemFrames) do
                local slot = i - 1 - row._scrollIdx
                if slot >= 0 and slot < visibleCount then
                    frame:ClearAllPoints()
                    frame:SetPoint("TOPLEFT", row, "TOPLEFT",
                        trackLeft + slot * (iconSz + gap), iconYBase)
                    frame:Show()
                else
                    frame:Hide()
                end
            end
            local overflow = numItems > visibleCount
            if overflow then
                row.leftArrow:ClearAllPoints()
                row.leftArrow:SetPoint("LEFT", row, "LEFT", ITEMS_LEFT, 0)
                row.leftArrow:SetAlpha(row._scrollIdx > 0 and 1 or 0.3)
                row.leftArrow:EnableMouse(row._scrollIdx > 0)
                row.leftArrow:Show()

                row.rightArrow:ClearAllPoints()
                row.rightArrow:SetPoint("LEFT", row, "LEFT", trackRight + 2, 0)
                row.rightArrow:SetAlpha(row._scrollIdx < maxStart and 1 or 0.3)
                row.rightArrow:EnableMouse(row._scrollIdx < maxStart)
                row.rightArrow:Show()
            else
                row.leftArrow:Hide()
                row.rightArrow:Hide()
            end
        end

        row.leftArrow:SetScript("OnClick", function()
            row._scrollIdx = row._scrollIdx - 1
            Relayout()
        end)
        row.rightArrow:SetScript("OnClick", function()
            row._scrollIdx = row._scrollIdx + 1
            Relayout()
        end)
        Relayout()

        yOff = yOff + rowHeight + ROW_GAP
        globalRowIdx = globalRowIdx + 1
    end

    -- Helper to render a section header (instance names)
    local SECTION_H = 18
    local function RenderSectionHeader(text, subText, tint)
        local row = AcquireRow(f._content)
        row:SetSize(contentW, SECTION_H)
        row:SetPoint("TOPLEFT", f._content, "TOPLEFT", 0, -yOff)
        tint = tint or { 0.12, 0.06, 0.18, 0.6 }
        row.bg:SetColorTexture(tint[1], tint[2], tint[3], tint[4])
        row.srcLabel:SetFontObject("GameFontNormal")
        row.srcLabel:ClearAllPoints()
        row.srcLabel:SetPoint("LEFT", row, "LEFT", 12, 0)
        row.srcLabel:SetTextColor(0.75, 0.45, 1.0)
        row.srcLabel:SetText(text)
        row.srcLabel:SetAlpha(1)
        if subText then
            -- Right-aligned in a header; RenderRow restores the default
            -- anchor when the pooled row is reused as an item row.
            row.countLabel:ClearAllPoints()
            row.countLabel:SetPoint("RIGHT", row, "RIGHT", -12, 0)
            row.countLabel:SetJustifyH("RIGHT")
            row.countLabel:SetText(subText)
            row.countLabel:Show()
        end
        yOff = yOff + SECTION_H
    end

    ------------------------------------------------------------
    -- Collect the items one boss drops, keeping the highest difficulty
    -- version of each item. Shared by both views now that dungeons are
    -- grouped by boss too.
    ------------------------------------------------------------
    local DIFF_PRIORITY = {
        [23] = 6, [2] = 5, [1] = 4,      -- dungeon: Mythic > Heroic > Normal
        [16] = 6, [15] = 5, [14] = 4, [17] = 3,  -- raid
        [0]  = 4,                        -- world boss
    }

    -- The Encounter Journal hands back a different item link per
    -- difficulty, each carrying that difficulty's item level. Prefer the
    -- link for whatever the difficulty dropdown is set to, so the item
    -- tooltip agrees with the number the browser is showing. Fall back to
    -- the highest difficulty the item exists at when it has no version
    -- for the current pick.
    -- Keystone selections read the Mythic 0 loot table (see
    -- GetSelectedEJDifficulty); the item level for the chosen key level
    -- comes from ns.DUNGEON_LOOT, not from the link.
    local preferredDiff = ns:GetSelectedEJDifficulty(view)

    local function CollectBossItems(instanceName, bossName)
        local out = {}
        if not rawResults then return out end

        local seen = {}
        for _, entry in ipairs(rawResults) do
            if entry.sourceName == instanceName and entry.bossName == bossName then
                for diffID, diffItems in pairs(entry.items) do
                    -- Exact match on the selected difficulty outranks
                    -- everything; otherwise fall back to "hardest available".
                    local priority = (diffID == preferredDiff)
                        and 100 or (DIFF_PRIORITY[diffID] or 0)
                    for _, item in ipairs(diffItems) do
                        local prev = seen[item.itemID]
                        if not prev or priority > prev._priority then
                            seen[item.itemID] = {
                                itemID = item.itemID, name = item.name,
                                icon = item.icon, itemLink = item.itemLink,
                                diffID = diffID, _priority = priority,
                                sourceName = instanceName, bossName = bossName,
                                veryRare = item.veryRare,
                                -- Myth 9 comes from either signal: the last
                                -- two bosses, or the journal's own Very Rare
                                -- flag, which can appear on any boss.
                                mythNine = ns:IsMythNineBoss(instanceName, bossName)
                                    or (item.veryRare or false),
                            }
                        end
                    end
                end
            end
        end
        for _, item in pairs(seen) do
            item._priority = nil
            table.insert(out, item)
        end
        return out
    end

    ------------------------------------------------------------
    -- Render every boss of one instance as its own row.
    ------------------------------------------------------------
    -- hideEmpty: skip bosses with nothing for the current filter. Used for
    -- dungeons, where a single-slot filter otherwise leaves ~30 blank rows
    -- to scroll past. Raids keep every boss so the pull order stays
    -- readable as a list.
    local function RenderBossRows(inst, sourceType, shapedFallback, hideEmpty)
        local rendered = 0
        for _, boss in ipairs(inst.bosses) do
            local bossItems = CollectBossItems(inst.name, boss.name)

            -- Favorites / all-slots modes come back shaped by instance
            -- rather than per boss, so fall back to filtering that.
            if #bossItems == 0 and shapedFallback then
                for _, item in ipairs(shapedFallback.items or {}) do
                    if item.bossName == boss.name then
                        table.insert(bossItems, item)
                    end
                end
            end

            -- The penultimate and final bosses of the current raid award
            -- Myth 9 (344) rather than the usual Mythic item level, both
            -- as drops and from the vault. Worth calling out: they are
            -- the only above-Myth-6/6 sources in the instance.
            local isMythNine = ns:IsMythNineBoss(inst.name, boss.name)
            local label, subLabel = boss.name, nil
            if isMythNine then
                label = label .. "  |cffff8000Myth 9|r"
                subLabel = ("|cffff8000%d|r"):format(ns.RAID_VERY_RARE_ILVL or 344)
            end

            if not (hideEmpty and #bossItems == 0) then
                RenderRow(label, subLabel, sourceType, nil, bossItems,
                    #bossItems == 0, true, boss.encounterID,
                    { sourceName = inst.name, bossName = boss.name,
                      mythNine = isMythNine })
                rendered = rendered + 1
            end
        end

        -- Say so explicitly rather than leaving a header with nothing
        -- under it, which reads as a loading failure.
        if hideEmpty and rendered == 0 then
            RenderRow("|cff555555No drops for this filter|r", nil, sourceType,
                nil, {}, true, true, nil, { sourceName = inst.name })
        end
    end

    if view == "dungeon" then
        -- Always grouped by boss: the whole point is seeing which boss
        -- drops the piece you want. ReshapeLootByInstance keeps bossName
        -- on every item, so this works in favorites and all-slots mode
        -- too (an earlier build gated it on a flag that was false by
        -- default, which just left a dead button on screen).
        for _, inst in ipairs(cache.dungeons) do
            local data = shapedLookup[inst.name]
            local count = data and #(data.items or {}) or 0
            RenderSectionHeader(inst.name,
                count > 0 and ("|cff888888%d item%s|r"):format(
                    count, count ~= 1 and "s" or "") or nil,
                { 0.06, 0.12, 0.18, 0.6 })
            RenderBossRows(inst, "dungeon", data, true)
        end

    elseif view == "raid" then
        -- Raid view: boss-by-boss rows grouped under raid headers.
        for _, raidInst in ipairs(cache.raids) do
            local data = shapedLookup[raidInst.name]
            local count = data and #(data.items or {}) or 0
            RenderSectionHeader(raidInst.name,
                count > 0 and ("|cff888888%d item%s|r"):format(
                    count, count ~= 1 and "s" or "") or nil)
            RenderBossRows(raidInst, "raid", data)
        end
    end
end

------------------------------------------------------------
-- App Mode (embedded in AppFrame)
------------------------------------------------------------
function ns:SetLootBrowserAppMode(enabled, contentWidth, contentHeight)
    local f = ns.LootBrowserFrame
    if not f then return end

    if enabled then
        f:SetMovable(false)
        f:EnableMouse(false)
        f:SetBackdrop(nil)
        local dw, dh = ns:GetAppFrameSize()
        f:SetSize(contentWidth or dw, contentHeight or (dh - 34))
        f._titleFs:Hide()
        f._closeBtn:Hide()
    else
        f:SetMovable(true)
        f:EnableMouse(true)
        f:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets   = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
        f:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
        local dw, dh = ns:GetAppFrameSize()
        f:SetSize(dw, dh)
        f._titleFs:Show()
        f._closeBtn:Show()
    end

    f.inAppMode = enabled
    UpdateLayout(f)
end

