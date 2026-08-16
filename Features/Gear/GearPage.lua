local _, ns = ...

------------------------------------------------------------
-- Gear Upgrades, on the shell.
--
-- Three columns: eight slot cards down each side, and between them the
-- summary and the improvements list. State on the outside, what to do
-- about it in the middle.
--
-- This replaces the paper doll for the shell only. Core/UI.lua still
-- owns ns.MainFrame and the standalone window, because that frame is
-- also what opens at an upgrade vendor and it works there.
--
-- The doll could not follow the shell. It is a 440x500 two-column block
-- and the content region is roughly 700x480, so its height binds before
-- its width does: even starving the panel beneath it to nothing only
-- reached 1.0x scale, while the width would have allowed 1.59x. No
-- amount of scaling arithmetic fills that gap -- the shape had to
-- change, and sixteen cards across three columns is the shape that
-- uses the room.
--
-- Every value here comes from the existing data layer. Nothing new is
-- computed: ns.SLOT_IDS, ns:GetSlotInfo, ns:CanUpgradeItem and
-- ns:GetAllRecommendations already back the standalone window.
------------------------------------------------------------

local Shell, W = ns.Shell, ns.Widgets
if not (Shell and W) then return end

local PAD, GAP = Shell.PAD, Shell.GAP

local CARD_H      = 46
local CARD_GAP    = 4
local SUMMARY_H   = 96

-- Left column, then right. Ordered head-down rather than by slot id so
-- the two columns read like a character sheet rather than like the
-- inventory indices behind them.
local LEFT_SLOTS  = { 1, 2, 3, 15, 5, 9, 10, 6 }
local RIGHT_SLOTS = { 7, 8, 11, 12, 13, 14, 16, 17 }

local TRACK_COLORS = {
    Adventurer = "ff1eff00",
    Veteran    = "ff0070dd",
    Champion   = "ffa335ee",
    Hero       = "ffff8000",
    Myth       = "ffff0000",
}

local ui

--- Slot name by inventory id, taken from the same table the rest of the
--- addon uses so the two cannot drift apart.
local function slotName(slotID)
    for _, s in ipairs(ns.SLOT_IDS or {}) do
        if s.slot == slotID then return s.name end
    end
    return tostring(slotID)
end

------------------------------------------------------------
-- A slot card
------------------------------------------------------------
local function BuildCard(parent, slotID)
    local card = W:Panel(parent, "inset")
    card:SetHeight(CARD_H)
    card.slotID = slotID

    -- The left edge carries the card's state: red when the slot wants
    -- attention, quiet otherwise. It is the only thing on the card that
    -- can be read without focusing on it, which is what makes sixteen of
    -- them scannable.
    card.edge = card:CreateTexture(nil, "OVERLAY")
    card.edge:SetPoint("TOPLEFT", 2, -2)
    card.edge:SetPoint("BOTTOMLEFT", 2, 2)
    card.edge:SetWidth(3)

    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(30, 30)
    card.icon:SetPoint("LEFT", 9, 0)
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    card.iconEdge = card:CreateTexture(nil, "OVERLAY")
    card.iconEdge:SetTexture("Interface\\Common\\WhiteIconFrame")
    card.iconEdge:SetPoint("TOPLEFT", card.icon, -1, 1)
    card.iconEdge:SetPoint("BOTTOMRIGHT", card.icon, 1, -1)

    -- Item level sits right, so it is a column the eye can run down
    -- rather than a number buried at the end of a sentence.
    card.ilvl = W:Label(card, "GameFontNormal", "RIGHT")
    card.ilvl:SetPoint("TOPRIGHT", -10, -7)

    card.slot = W:Label(card, "GameFontNormalSmall")
    card.slot:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 9, -1)
    card.slot:SetPoint("RIGHT", card.ilvl, "LEFT", -6, 0)
    card.slot:SetWordWrap(false)
    card.slot:SetTextColor(W:Color("muted"))

    -- The name is kept on the card AND in the tooltip. It truncates at
    -- this width, which is deliberate: the card says which item, the
    -- tooltip says everything about it.
    card.name = W:Label(card, "GameFontNormalSmall")
    card.name:SetPoint("TOPLEFT", card.slot, "BOTTOMLEFT", 0, -2)
    card.name:SetPoint("RIGHT", card, "RIGHT", -10, 0)
    card.name:SetWordWrap(false)

    card.track = W:Label(card, "GameFontNormalSmall", "RIGHT")
    card.track:SetPoint("BOTTOMRIGHT", -10, 6)

    card:EnableMouse(true)
    card:SetScript("OnEnter", function(self)
        if not self.slotID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        -- The equipped item's own tooltip. Nothing to re-describe: it
        -- already carries the enchant, the sockets and the upgrade line.
        if GameTooltip:SetInventoryItem("player", self.slotID) then
            GameTooltip:Show()
        else
            GameTooltip:SetText(slotName(self.slotID))
            GameTooltip:AddLine("Nothing equipped.", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end
    end)
    card:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return card
end

local function RefreshCard(card)
    local info = ns.GetSlotInfo and ns:GetSlotInfo(card.slotID) or nil
    card.slot:SetText(slotName(card.slotID))

    if not info then
        card.icon:SetTexture("Interface\\Paperdoll\\UI-PaperDoll-Slot-Chest")
        card.icon:SetDesaturated(true)
        W:SetIconQuality(card.iconEdge, nil)
        card.name:SetText(W:Tint("faint", "Empty"))
        card.ilvl:SetText(W:Tint("faint", "--"))
        card.track:SetText("")
        -- An empty slot is a problem worth seeing, except off hand,
        -- which is empty for most specs and is not news.
        local r, g, b = W:Color(card.slotID == 17 and "faint" or "danger")
        card.edge:SetColorTexture(r, g, b, card.slotID == 17 and 0.3 or 0.9)
        return
    end

    card.icon:SetTexture(info.icon)
    card.icon:SetDesaturated(false)
    W:SetIconQuality(card.iconEdge, info.quality)

    local name = info.link and info.link:match("%[(.-)%]") or "Unknown"
    local hex = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[info.quality or 1]
    card.name:SetText(name)
    if hex and hex.r then
        card.name:SetTextColor(hex.r, hex.g, hex.b)
    else
        card.name:SetTextColor(W:Color("text"))
    end
    card.ilvl:SetText(tostring(info.ilvl or 0))

    -- Track and rank from the tooltip scan, never guessed from item
    -- level: last season's gear falls inside this season's bands, so a
    -- locked piece would read as upgradeable.
    if info.track then
        card.track:SetText(("|c%s%s %d/%d|r"):format(
            TRACK_COLORS[info.track] or "ffffffff", info.track,
            info.rank or 0, info.maxRank or 0))
    else
        card.track:SetText(W:Tint("faint", "no track"))
    end

    local canUpgrade = ns.CanUpgradeItem and select(1, ns:CanUpgradeItem(card.slotID))
    if canUpgrade then
        card.edge:SetColorTexture(W:Color("good"))
        card.edge:SetAlpha(0.9)
    else
        card.edge:SetColorTexture(W:Color("faint"))
        card.edge:SetAlpha(0.35)
    end
end

------------------------------------------------------------
-- Build
------------------------------------------------------------
local function Build(host)
    ui = { host = host, cards = {} }
    ns.GearPageUI = ui

    ui.summaryTitle = W:SectionTitle(host, "equipment")
    ui.summaryTitle:SetPoint("TOPLEFT", PAD, -PAD)
    ui.summaryTitle:SetPoint("RIGHT", host, "RIGHT", -PAD, 0)

    for _, slotID in ipairs(LEFT_SLOTS) do
        ui.cards[slotID] = BuildCard(host, slotID)
    end
    for _, slotID in ipairs(RIGHT_SLOTS) do
        ui.cards[slotID] = BuildCard(host, slotID)
    end

    ------------------------------------------------------------
    -- Middle: summary, then what to do about it
    ------------------------------------------------------------
    ui.summary = W:Panel(host, "inset")
    ui.summary:SetHeight(SUMMARY_H)

    ui.summaryRows = {}
    for i, label in ipairs({ "Equipped", "Upgradeable", "Average item level" }) do
        local row = CreateFrame("Frame", nil, ui.summary)
        row:SetHeight(20)
        row:SetPoint("TOPLEFT", 12, -12 - (i - 1) * 22)
        row:SetPoint("RIGHT", ui.summary, "RIGHT", -12, 0)

        row.label = W:Label(row, "GameFontNormalSmall")
        row.label:SetPoint("LEFT")
        row.label:SetText(label)
        row.label:SetTextColor(W:Color("muted"))

        row.value = W:Label(row, "GameFontNormal", "RIGHT")
        row.value:SetPoint("RIGHT")
        ui.summaryRows[i] = row
    end

    -- Parented to the page, not to the summary. Inside it, the heading
    -- sat within the summary's border while the list it labels sat
    -- outside below -- a caption on the wrong side of a box.
    ui.improveTitle = W:SectionTitle(host, "improvements")

    ui.improveScroll = W:ScrollList(host)
    ui.improveRows = {}
end

--- Pooled: the recommendation list changes length as gear changes, and
--- rebuilding frames on every refresh would leak a set per refresh.
local function AcquireImproveRow(index)
    local row = ui.improveRows[index]
    if not row then
        row = W:Panel(ui.improveScroll.content, "row")
        row:SetHeight(42)

        row.edge = row:CreateTexture(nil, "OVERLAY")
        row.edge:SetPoint("TOPLEFT", 2, -2)
        row.edge:SetPoint("BOTTOMLEFT", 2, 2)
        row.edge:SetWidth(3)

        row.slot = W:Label(row, "GameFontNormal")
        row.slot:SetPoint("TOPLEFT", 12, -6)

        row.tag = W:Label(row, "GameFontNormalSmall", "RIGHT")
        row.tag:SetPoint("TOPRIGHT", -10, -6)

        row.reason = W:Label(row, "GameFontNormalSmall")
        row.reason:SetPoint("TOPLEFT", row.slot, "BOTTOMLEFT", 0, -3)
        row.reason:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        row.reason:SetWordWrap(false)
        row.reason:SetTextColor(W:Color("muted"))

        ui.improveRows[index] = row
    end
    row:Show()
    return row
end

------------------------------------------------------------
-- Refresh
------------------------------------------------------------
local function Refresh(ctx)
    if not ui then return end

    local width = (ctx and ctx.width) or ui.host:GetWidth() or 0
    local height = (ctx and ctx.height) or ui.host:GetHeight() or 0
    local avail = width - PAD * 2
    if avail < 120 then return end

    -- Three columns. The middle is widest because it is the only one
    -- holding sentences; the side columns hold a name and two numbers.
    local sideW = math.floor((avail - GAP * 2) * 0.29)
    local midW = avail - GAP * 2 - sideW * 2
    local top = ui.summaryTitle

    for i, slotID in ipairs(LEFT_SLOTS) do
        local card = ui.cards[slotID]
        card:ClearAllPoints()
        card:SetWidth(sideW)
        card:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0,
            -8 - (i - 1) * (CARD_H + CARD_GAP))
    end
    for i, slotID in ipairs(RIGHT_SLOTS) do
        local card = ui.cards[slotID]
        card:ClearAllPoints()
        card:SetWidth(sideW)
        card:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT", 0,
            -8 - (i - 1) * (CARD_H + CARD_GAP))
    end

    ui.summary:ClearAllPoints()
    ui.summary:SetWidth(midW)
    ui.summary:SetPoint("TOPLEFT", top, "BOTTOMLEFT", sideW + GAP, -8)

    ui.improveTitle:ClearAllPoints()
    ui.improveTitle:SetPoint("TOPLEFT", ui.summary, "BOTTOMLEFT", 0, -GAP)
    ui.improveTitle:SetPoint("RIGHT", ui.summary, "RIGHT", 0, 0)

    local listTop = 8 + SUMMARY_H + GAP + 26
    local listH = math.max(height - PAD * 2 - listTop - 8, 60)
    ui.improveScroll:ClearAllPoints()
    ui.improveScroll:SetSize(midW - 18, listH)
    ui.improveScroll:SetPoint("TOPLEFT", top, "BOTTOMLEFT", sideW + GAP, -listTop)

    ------------------------------------------------------------
    -- Cards
    ------------------------------------------------------------
    local equipped, upgradeable, levelSum, levelCount = 0, 0, 0, 0
    for _, card in pairs(ui.cards) do
        RefreshCard(card)
        local info = ns.GetSlotInfo and ns:GetSlotInfo(card.slotID) or nil
        if info then
            equipped = equipped + 1
            levelSum = levelSum + (tonumber(info.ilvl) or 0)
            levelCount = levelCount + 1
            if ns.CanUpgradeItem and select(1, ns:CanUpgradeItem(card.slotID)) then
                upgradeable = upgradeable + 1
            end
        end
    end

    -- Off hand is counted out of the denominator rather than reported as
    -- missing: most specs never fill it, and "15/16" every single time
    -- is a number that only ever means "fine".
    local slots = #LEFT_SLOTS + #RIGHT_SLOTS
    if not (ns.GetSlotInfo and ns:GetSlotInfo(17)) then slots = slots - 1 end

    ui.summaryRows[1].value:SetText(("%d of %d"):format(equipped, slots))
    ui.summaryRows[2].value:SetText(upgradeable > 0
        and W:Tint("good", tostring(upgradeable))
        or W:Tint("muted", "0"))
    ui.summaryRows[3].value:SetText(levelCount > 0
        and tostring(math.floor(levelSum / levelCount + 0.5))
        or W:Tint("faint", "--"))

    ------------------------------------------------------------
    -- Improvements
    ------------------------------------------------------------
    local recs = ns.GetAllRecommendations and ns:GetAllRecommendations() or {}
    local list = {}
    for _, s in ipairs(ns.SLOT_IDS or {}) do
        local r = recs[s.slot]
        if r and r.recommendation
            and r.recommendation ~= ns.RECOMMEND.NO_ITEM
            and r.recommendation ~= ns.RECOMMEND.MAXED then
            list[#list + 1] = r
        end
    end

    local y = 0
    for i, r in ipairs(list) do
        local row = AcquireImproveRow(i)
        row:ClearAllPoints()
        row:SetWidth(midW - 18)
        row:SetPoint("TOPLEFT", ui.improveScroll.content, "TOPLEFT", 0, -y)

        local rec = r.recommendation or {}
        local hex = rec.color or "ff888888"
        row.slot:SetText(r.slotName or "")
        row.tag:SetText(("|c%s%s|r"):format(hex, rec.label or ""))
        row.reason:SetText(r.reason or "")

        local cr = tonumber(hex:sub(3, 4), 16)
        local cg = tonumber(hex:sub(5, 6), 16)
        local cb = tonumber(hex:sub(7, 8), 16)
        if cr and cg and cb then
            row.edge:SetColorTexture(cr / 255, cg / 255, cb / 255, 0.85)
        else
            row.edge:SetColorTexture(W:Color("faint"))
        end
        y = y + 46
    end
    for i = #list + 1, #ui.improveRows do ui.improveRows[i]:Hide() end
    ui.improveScroll:SetContentHeight(y)
end

Shell:RegisterPage({
    id = "gear", label = "Gear Upgrades", order = 10,
    accent = { 0.0, 1.0, 0.0 },
    Build = function(host) Build(host) end,
    Refresh = Refresh,
})
