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

-- Row metrics. The height used to be a flat 42 with a 46 stride, which
-- is correct for exactly one line of reason text and clips every other.
-- TITLE_H covers the slot name and the gap under it; ROW_PAD is the
-- breathing room below the sentence.
local TITLE_H = 25
local ROW_PAD = 11
local ROW_GAP = 4

local PAD, GAP = Shell.PAD, Shell.GAP

-- Floor and ceiling. Cards size themselves to the column between
-- these; below the floor the two text lines collide, above the
-- ceiling they are mostly padding.
local CARD_H      = 40
local CARD_MAX_H  = 76
local PER_COLUMN  = 8
local CARD_GAP    = 4
-- The improvements list's share of the page, and the least it can be.
-- It is budgeted before the cards: the cards are a reference you glance
-- at, the list is the part you read.
local IMPROVE_MIN = 240
local IMPROVE_SHARE = 0.38
local IMPROVE_TITLE_H = 26

-- Left column, then right, from the shared doll layout.
--
-- These were written out here as well, and had drifted from the
-- best-in-slot page's copy: Hands and Waist sat at the bottom of the
-- left column here and at the top of the right column there, so the
-- same character read differently depending on which page you opened.
-- ns.DOLL_LAYOUT is the one order now and this derives from it.
local LEFT_SLOTS, RIGHT_SLOTS = ns:GetDollColumns()

local TRACK_COLORS = {
    Adventurer = "ff1eff00",
    Veteran    = "ff0070dd",
    Champion   = "ffa335ee",
    Hero       = "ffff8000",
    Myth       = "ffff0000",
}

-- The colour the whole addon uses for a rank that costs nothing:
-- ns.RECOMMEND.FREE_UPGRADE is ff00ffff and Core/UI.lua's vendor glow is
-- the same cyan. A third opinion about what free looks like would be one
-- too many.
local FREE_R, FREE_G, FREE_B = 0.0, 1.0, 1.0

local ui

--- Slot name by inventory id, taken from the same table the rest of the
--- addon uses so the two cannot drift apart.
local function slotName(slotID)
    for _, s in ipairs(ns.SLOT_IDS or {}) do
        if s.slot == slotID then return s.name end
    end
    return tostring(slotID)
end

--- How many ranks of this slot are already paid for.
---
--- The same arithmetic RULE 0 does in Features/Gear/Recommend.lua, and
--- deliberately not the recommendation itself: that returns
--- FREE_UPGRADE for a piece still sitting tradeable in the bags too,
--- which is a rank one decision AWAY from free. A border promising
--- something the vendor will not hand over today is worse than no
--- border.
local function FreeRanks(slotID, ilvl)
    if not (ns.CanUpgradeItem and ns.GetFreeUpgradeIlvl) then return 0 end
    local canUpgrade, up = ns:CanUpgradeItem(slotID)
    if not (canUpgrade and up) then return 0 end

    local levels = up.track and ns.GEAR_TRACKS[up.track]
    if not levels then return 0 end

    local mark = ns:GetFreeUpgradeIlvl(slotID) or 0
    if mark <= (ilvl or up.currIlvl or 0) then return 0 end

    local n = 0
    for r = (up.currUpgrade or 0) + 1, (up.maxUpgrade or 0) do
        if levels[r] and levels[r] <= mark then n = n + 1 else break end
    end
    return n
end

--- A pulsing outline for a card whose ranks are already owned.
---
--- The only animated thing on this page, and it earns that by being the
--- only state that is different in KIND rather than in degree. Every
--- other card says how good a slot is; this one says there is item
--- level sitting at a vendor with the player's name on it, and a still
--- border in a grid of sixteen still borders is exactly how that went
--- unnoticed for as long as it did.
---
--- Four thin textures, not a Blizzard highlight atlas. Those are cut
--- for square action buttons and stretch into a smear across a card
--- three times as wide as it is tall.
---
--- On its own frame ABOVE the card rather than as textures on it.
--- Frame level beats draw layer, so a glow drawn around a card has to
--- outrank the card -- being created later is not enough, and that
--- assumption has cost this addon four separate invisible-content bugs.
local function BuildFreeGlow(card)
    local glow = CreateFrame("Frame", nil, card)
    glow:SetAllPoints(card)
    glow:SetFrameLevel(card:GetFrameLevel() + 5)
    glow:Hide()

    local T = 2
    local edges = {}
    local function edge(p1, p2, w, h)
        local t = glow:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(FREE_R, FREE_G, FREE_B, 1)
        t:SetPoint(p1)
        t:SetPoint(p2)
        if w then t:SetWidth(w) end
        if h then t:SetHeight(h) end
        edges[#edges + 1] = t
        return t
    end
    edge("TOPLEFT", "TOPRIGHT", nil, T)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, T)
    edge("TOPLEFT", "BOTTOMLEFT", T, nil)
    edge("TOPRIGHT", "BOTTOMRIGHT", T, nil)
    glow.edges = edges

    -- BOUNCE rather than REPEAT: a sawtooth snaps back to bright at the
    -- end of every cycle, which reads as a blink and pulls the eye off
    -- whatever it was on. Breathing is noticeable without being a
    -- distress signal, and there can be several of these on screen.
    glow.anim = glow:CreateAnimationGroup()
    glow.anim:SetLooping("BOUNCE")
    local fade = glow.anim:CreateAnimation("Alpha")
    fade:SetFromAlpha(1.0)
    fade:SetToAlpha(0.25)
    fade:SetDuration(0.9)
    fade:SetSmoothing("IN_OUT")

    return glow
end

--- Turn the border on or off, without restarting a running animation.
---
--- Re-Play() on every refresh would jump every card back to full bright
--- in step, and the gear page refreshes on inventory changes, bag
--- changes and currency changes -- which is to say constantly, and all
--- at once.
local function SetFreeGlow(card, on)
    local glow = card.freeGlow
    if not glow then return end
    if on then
        glow:Show()
        if not glow.anim:IsPlaying() then glow.anim:Play() end
    else
        if glow.anim:IsPlaying() then glow.anim:Stop() end
        glow:Hide()
    end
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

    card.freeGlow = BuildFreeGlow(card)

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
        -- An empty slot cannot have ranks waiting on it, and a border
        -- left running from the piece that used to be there would be
        -- the addon pointing at nothing.
        SetFreeGlow(card, false)
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
    local free = FreeRanks(card.slotID, info.ilvl)
    SetFreeGlow(card, free > 0)

    if free > 0 then
        -- The left edge is the card's state in one colour, and "already
        -- paid for" outranks "could be upgraded". Same cyan as the
        -- border around it, so the two read as one thing rather than as
        -- two overlapping opinions.
        card.edge:SetColorTexture(FREE_R, FREE_G, FREE_B, 1)
        card.edge:SetAlpha(1)
    elseif canUpgrade then
        card.edge:SetColorTexture(W:Color("good"))
        card.edge:SetAlpha(0.9)
    else
        card.edge:SetColorTexture(W:Color("faint"))
        card.edge:SetAlpha(0.35)
    end
end

--- The icon grows with the card.
---
--- Fixed at 30 it looked marooned once the cards filled the column at
--- around 75px; the art is the first thing read on a card and should
--- scale with it. Capped so it does not crowd the two text lines beside
--- it.
local function SizeCardIcon(card, cardH)
    local size = math.max(26, math.min(cardH - 16, 46))
    card.icon:SetSize(size, size)
end

------------------------------------------------------------
-- Build
------------------------------------------------------------
local function Build(host)
    ui = { host = host, cards = {} }
    ns.GearPageUI = ui

    -- No page heading. The tab along the bottom already says Gear
    -- Upgrades, and a rule spanning all three columns sat at a different
    -- height to the improvements rule inside the middle one -- two
    -- horizontal lines at unrelated heights, which is what looked wrong.
    -- The columns start at the top instead, and the height it was using
    -- goes to the cards.
    ui.top = CreateFrame("Frame", nil, host)
    ui.top:SetHeight(1)
    ui.top:SetPoint("TOPLEFT", PAD, -PAD)
    ui.top:SetPoint("RIGHT", host, "RIGHT", -PAD, 0)

    for _, slotID in ipairs(LEFT_SLOTS) do
        ui.cards[slotID] = BuildCard(host, slotID)
    end
    for _, slotID in ipairs(RIGHT_SLOTS) do
        ui.cards[slotID] = BuildCard(host, slotID)
    end

    ------------------------------------------------------------
    -- Below the cards: what to do about them
    --
    -- No totals strip. Equipped, upgradeable and average item level are
    -- three numbers you can read off the cards themselves, and the
    -- improvements list is the part that says something the cards do
    -- not. The height it was using goes to the cards and the list.
    ------------------------------------------------------------

    ui.improveTitle = W:SectionTitle(host, "Improvements")

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
        row:EnableMouse(true)

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
        -- Wrapped, not clipped. The width is set on refresh so the
        -- string can be measured; anchoring RIGHT as well would leave
        -- GetStringHeight reporting one line however much text there is,
        -- and the row would size itself to the wrong answer.
        --
        -- This was SetWordWrap(false), which silently cut every sentence
        -- long enough to need the space -- the advice that had most to
        -- say was the advice you could not read. The other renderer of
        -- this same list (Core/UI.lua) has wrapped all along.
        row.reason:SetWordWrap(true)
        row.reason:SetJustifyH("LEFT")
        row.reason:SetTextColor(W:Color("muted"))

        -- The row is one line; the reasoning behind it is not. Hover
        -- carries the arithmetic, the drop band and the state of the
        -- whole track, none of which fits a third of a screen.
        row:SetScript("OnEnter", function(self)
            if not self.detail or #self.detail == 0 then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.slotLabel or "", 1, 1, 1)
            if self.tagLabel then
                GameTooltip:AddLine(self.tagLabel, nil, nil, nil, true)
            end
            GameTooltip:AddLine(" ")
            for _, line in ipairs(self.detail) do
                GameTooltip:AddLine(line, 0.82, 0.82, 0.82, true)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

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
    local top = ui.top
    local colW = math.floor((avail - GAP) / 2)

    -- The page is cards on top, totals and improvements beneath. The
    -- lower block is budgeted first because it has a floor -- a
    -- scrolling list shorter than a few rows is not a list -- and the
    -- cards take what is left.
    -- Everything below the cards, counted in full: the gap, the heading
    -- and the list's own minimum. An earlier version left the heading
    -- and a gap out, so the cards claimed 40px they did not have and the
    -- list was squeezed under its floor to pay for it.
    -- The improvements take a share of the page, not a leftover.
    --
    -- They were budgeted at a bare minimum and the cards took the rest,
    -- which is backwards: sixteen cards are a reference you glance at,
    -- and the list is the part you actually read. It now claims its
    -- share first and grows with the window; the cards take what is
    -- left, down to a floor where their two text lines still fit.
    local improveH = math.max(IMPROVE_MIN, math.floor((height - PAD * 2) * IMPROVE_SHARE))
    local lowerH = GAP + IMPROVE_TITLE_H + improveH
    local colH = height - PAD * 2 - lowerH
    local cardH = math.floor((colH - CARD_GAP * (PER_COLUMN - 1)) / PER_COLUMN)
    cardH = math.max(CARD_H, math.min(cardH, CARD_MAX_H))

    -- What the cards actually took, so the block below starts where they
    -- end rather than at a guess.
    local cardsUsed = cardH * PER_COLUMN + CARD_GAP * (PER_COLUMN - 1)

    for i, slotID in ipairs(LEFT_SLOTS) do
        local card = ui.cards[slotID]
        card:ClearAllPoints()
        card:SetSize(colW, cardH)
        card:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0,
            -(i - 1) * (cardH + CARD_GAP))
        SizeCardIcon(card, cardH)
    end
    for i, slotID in ipairs(RIGHT_SLOTS) do
        local card = ui.cards[slotID]
        card:ClearAllPoints()
        card:SetSize(colW, cardH)
        card:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT", 0,
            -(i - 1) * (cardH + CARD_GAP))
        SizeCardIcon(card, cardH)
    end

    ui.improveTitle:ClearAllPoints()
    ui.improveTitle:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -(cardsUsed + GAP))
    ui.improveTitle:SetPoint("RIGHT", top, "RIGHT", 0, 0)

    local listTop = cardsUsed + GAP + IMPROVE_TITLE_H
    local listH = math.max(height - PAD * 2 - listTop, 60)
    ui.improveScroll:ClearAllPoints()
    ui.improveScroll:SetSize(avail - 18, listH)
    ui.improveScroll:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -listTop)

    ------------------------------------------------------------
    -- Cards
    ------------------------------------------------------------
    for _, card in pairs(ui.cards) do
        RefreshCard(card)
    end

    ------------------------------------------------------------
    -- Improvements
    ------------------------------------------------------------
    -- Ranked, not in equipment order. This walked ns.SLOT_IDS, which put
    -- the one slot actually worth spending on today wherever Feet sits
    -- in the paper doll -- below three rows of advice that say to wait.
    -- ns:GetRankedRecommendations is shared with the vendor panel so the
    -- two cannot disagree about what comes first.
    local list = ns.GetRankedRecommendations and ns:GetRankedRecommendations() or {}

    ------------------------------------------------------------
    -- The rows, and nothing above them.
    --
    -- Three per-wallet sentences used to head this list -- what each
    -- crest tier could do, before the first slot it would be spent on.
    -- They were true and they were in the wrong place: a list titled
    -- Improvements is read for the next thing to click, and a paragraph
    -- about Champion is not a thing to click. Everything they said
    -- about a SLOT is on that slot's row and its hover; what is only
    -- true of a wallet is on the crest tile beside the doll, where the
    -- balance already is.
    ------------------------------------------------------------
    local y = 0

    for i, r in ipairs(list) do
        local row = AcquireImproveRow(i)
        row:ClearAllPoints()
        row:SetWidth(avail - 18)
        row:SetPoint("TOPLEFT", ui.improveScroll.content, "TOPLEFT", 0, -y)

        local rec = r.recommendation or {}
        local hex = rec.color or "ff888888"
        row.slot:SetText(r.slotName or "")
        row.tag:SetText(("|c%s%s|r"):format(hex, rec.label or ""))

        -- Measured, not assumed. The label starts 12 in and the tag
        -- column takes 10 off the right, so that is the room a sentence
        -- has; give it exactly that and the height it reports is the
        -- height the row needs.
        row.reason:SetWidth(math.max((avail - 18) - 22, 40))
        row.reason:SetText(r.reason or "")

        row.detail = r.detail
        row.slotLabel = r.slotName
        row.tagLabel = rec.label

        local textH = math.max(row.reason:GetStringHeight() or 0, 10)
        local rowH = math.max(TITLE_H + textH + ROW_PAD, 42)
        row:SetHeight(rowH)

        local cr = tonumber(hex:sub(3, 4), 16)
        local cg = tonumber(hex:sub(5, 6), 16)
        local cb = tonumber(hex:sub(7, 8), 16)
        if cr and cg and cb then
            row.edge:SetColorTexture(cr / 255, cg / 255, cb / 255, 0.85)
        else
            row.edge:SetColorTexture(W:Color("faint"))
        end
        y = y + rowH + ROW_GAP
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
