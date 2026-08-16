local _, ns = ...

------------------------------------------------------------
-- Progression Dashboard: card-based single-page overview
------------------------------------------------------------

-- Layout constants
local FRAME_W, FRAME_H = ns:GetAppFrameSize()
-- Padding comes from the shell, not from here. Every page had picked
-- its own -- 12 in four, 14 in three -- so each sat to a different
-- rhythm from the chrome around it and from the others. One source
-- means a spacing change lands everywhere at once.
local PAD         = (ns.Shell and ns.Shell.PAD) or 14
local CARD_GAP    = 10
local SECTION_GAP = 14
local uiScale     = ns:GetUIScale()
local CARD_H      = math.floor(100 * uiScale)
local TITLE_H     = (ns.Widgets and ns.Widgets:SectionTitleHeight()) or 22
local CONTENT_TOP = -34
-- In the shell there is no window header to clear, only the page's own
-- breathing room.
local APP_CONTENT_TOP = -6
-- Clamped to the shell content region, not the standalone frame width.
-- GetAppFrameSize is screen-derived and returns around 960, so the four
-- cards below were laid out to about 930px and rendered into the
-- shell's 700 -- roughly 230px of overflow off the right edge. This is
-- the page overflowing its region, not the cards being too wide.
local SHELL_CW    = ns.Shell and ns.Shell.CONTENT_MIN or FRAME_W
local CW          = math.min(FRAME_W, SHELL_CW) - PAD * 2
-- Breathing room between a section card's edge and the cards on it.
local SECTION_PAD = 10
local COLS        = 4
-- The row of cards sits INSIDE a section card now, so it is narrower
-- than the page by that card's padding at both ends.
local INNER_W     = CW - SECTION_PAD * 2
local CARD_W      = math.floor((INNER_W - (COLS - 1) * CARD_GAP) / COLS)

-- Track names abbreviated for the value column.
--
-- Four cards across a 700px page leaves each value about 80px, and
-- "295 - 302 Champion" is half as wide again -- which is why the page
-- was showing "295 - 302 ..." and cutting off the very thing it exists
-- to tell you. The Crest line keeps the full word; it has the width.
local TRACK_SHORT = {
    Adventurer = "Adv",
    Veteran    = "Vet",
    Champion   = "Champ",
    Hero       = "Hero",
    Myth       = "Myth",
}

-- Crest colour table (hex for text, rgb for borders/stripes)
local CC = {
    Adventurer = { hex = "ff1eff00", r = 0.12, g = 1.00, b = 0.00 },
    Veteran    = { hex = "ff0070dd", r = 0.00, g = 0.44, b = 0.87 },
    Champion   = { hex = "ffa335ee", r = 0.64, g = 0.21, b = 0.93 },
    Hero       = { hex = "ffff8000", r = 1.00, g = 0.50, b = 0.00 },
    Myth       = { hex = "ffff0000", r = 1.00, g = 0.00, b = 0.00 },
}

------------------------------------------------------------
-- Main frame  (same name / namespace hook as before)
------------------------------------------------------------
local f = CreateFrame("Frame", "YippYappProgressionFrame", UIParent, "BackdropTemplate")
f:SetSize(FRAME_W, FRAME_H)
f:SetPoint("CENTER")
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:SetClampedToScreen(true)
f:SetFrameStrata("HIGH")
ns.Widgets:Apply(f, "panel")
ns.SmoothFrame(f)
f:Hide()
ns.ProgressionFrame = f

-- Everything on the page hangs off this rather than off the frame, so
-- the whole block can move as one piece.
--
-- App mode hides the window header, and the content should ride up into
-- the space it leaves instead of starting 34px down against nothing --
-- which is the band of empty page above "Mythic+". With every section
-- anchored individually to the frame that would have meant re-anchoring
-- all of them on every mode switch.
local root = CreateFrame("Frame", nil, f)
root:SetPoint("TOPLEFT", f, "TOPLEFT", 0, CONTENT_TOP)
root:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

-- Header
-- Season moves to the subtitle slot, matching the app frame's header.
-- Capture the subtitle too: app mode hides the standalone chrome, and a
-- subtitle left behind sits under the app's own page title.
local headerIcon, header, headerSub = ns.MakeWindowHeader(f, ns.Widgets:Tint("muted", "Progression"),
    ns.SEASON_NAME or "Midnight Season 2", PAD)

-- ESC to close (skipped when inside the app shell)
f:SetScript("OnShow", function()
    if f.inAppMode then return end
    tinsert(UISpecialFrames, "YippYappProgressionFrame")
end)
f:SetScript("OnHide", function()
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "YippYappProgressionFrame" then
            table.remove(UISpecialFrames, i)
            break
        end
    end
end)

local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -2, -2)

-- App mode: hide standalone chrome so the app shell provides it
function ns:SetProgressionAppMode(enabled)
    if enabled then
        header:Hide()
        if headerSub then headerSub:Hide() end
        closeBtn:Hide()
        f:SetMovable(false)
        f:EnableMouse(false)
        ns.Widgets:Unskin(f)
        -- Up into the space the hidden header left. CONTENT_TOP clears a
        -- title bar this page does not draw in app mode, and leaving it
        -- put a band of empty page above the first section.
        root:ClearAllPoints()
        root:SetPoint("TOPLEFT", f, "TOPLEFT", 0, APP_CONTENT_TOP)
        root:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    else
        header:Show()
        if headerSub then headerSub:Show() end
        closeBtn:Show()
        f:SetMovable(true)
        f:EnableMouse(true)
        ns.Widgets:Apply(f, "panel")
        ns.SmoothFrame(f)
        root:ClearAllPoints()
        root:SetPoint("TOPLEFT", f, "TOPLEFT", 0, CONTENT_TOP)
        root:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    end
end

------------------------------------------------------------
-- Y cursor  (increases downward; actual anchor is -Y against `root`,
-- which carries whichever top offset the current mode wants)
------------------------------------------------------------
local Y = 0

------------------------------------------------------------
-- Card factory
------------------------------------------------------------
local function MakeCard(col, yPos, crestType)
    local x = (col - 1) * (CARD_W + CARD_GAP)
    local card = CreateFrame("Frame", nil, f, "BackdropTemplate")
    card:SetSize(CARD_W, CARD_H)
    card:SetPoint("TOPLEFT", root, "TOPLEFT", PAD + SECTION_PAD + x, -yPos)
    ns.Widgets:Apply(card, "row")
    ns.SmoothFrame(card)

    -- The crest colour rides on the stripe alone now. It used to tint the
    -- card's backdrop border as well, which no longer works once the skin
    -- owns the surface -- a skin that draws its border from a nine-slice
    -- has no backdrop for SetBackdropBorderColor to reach. The stripe was
    -- always the clearer of the two signals anyway, so it stays and the
    -- border tint goes.
    local c = crestType and CC[crestType]
    local stripe = card:CreateTexture(nil, "OVERLAY")
    stripe:SetSize(3, CARD_H - 10)
    stripe:SetPoint("LEFT", 4, 0)
    if c then
        stripe:SetColorTexture(c.r, c.g, c.b, 0.85)
    else
        stripe:SetColorTexture(0.35, 0.35, 0.38, 0.55)
    end
    ns.DisableSharpening(stripe)
    return card
end

local function CardTitle(card, text, hex)
    local s = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s:SetPoint("TOPLEFT", 12, -8)
    s:SetText(hex and ("|c" .. hex .. text .. "|r") or ("|cffffffff" .. text .. "|r"))
    ns.ApplyTextShadow(s)
end

-- Per-card fontstring pools keyed by template. cardResetFs marks all
-- pooled strings hidden + idx=0 so the next build pulls from the start.
local function cardAcquireFs(card, template)
    card._pools = card._pools or {}
    local pool = card._pools[template]
    if not pool then
        pool = { idx = 0 }
        card._pools[template] = pool
    end
    pool.idx = pool.idx + 1
    local fs = pool[pool.idx]
    if not fs then
        fs = card:CreateFontString(nil, "OVERLAY", template)
        pool[pool.idx] = fs
    end
    fs:Show()
    fs:ClearAllPoints()
    fs:SetText("")
    fs:SetTextColor(1, 1, 1, 1)
    fs:SetWidth(0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    return fs
end

local function cardResetFs(card)
    if not card._pools then return end
    for _, pool in pairs(card._pools) do
        for i = 1, pool.idx do
            if pool[i] then pool[i]:Hide() end
        end
        pool.idx = 0
    end
end

local function CardLine(card, row, label, value, hex)
    local yOff = 30 + (row - 1) * 19
    local l = cardAcquireFs(card, "GameFontNormal")
    l:SetPoint("TOPLEFT", 12, -yOff)
    l:SetTextColor(unpack(ns.COLORS.TEXT_SECONDARY))
    l:SetText(label)

    local v = cardAcquireFs(card, "GameFontHighlight")
    -- 54, not 62: "Vault" is the longest label and does not need fifty
    -- pixels. Every pixel the label column gives up is one the numbers
    -- were being truncated for.
    v:SetPoint("TOPLEFT", 54, -yOff)
    v:SetWidth(CARD_W - 62)
    v:SetJustifyH("LEFT")
    v:SetWordWrap(false)
    if hex then
        v:SetText("|c" .. hex .. value .. "|r")
    else
        v:SetText(value)
    end
    -- Last resort, and only when it is actually needed: a value still
    -- too wide drops a font size rather than losing its tail to an
    -- ellipsis. A number you can read small beats half a number.
    if v:GetStringWidth() > (CARD_W - 62) then
        v:SetFontObject("GameFontHighlightSmall")
    end
end

--- A section: its heading, and the card its cards sit on.
---
--- These were a title with an ornamental rule trailing off to the right
--- and the cards loose underneath, so a section read as a line with some
--- boxes near it rather than as one block -- and the rule stopped
--- nowhere in particular while the cards stopped somewhere else.
--- SectionCard makes that rule the card's own top edge, which groups the
--- cards and says where the section ends.
local function Section(yPos, text, bodyH)
    local s = ns.Widgets:SectionCard(f)
    s:SetPoint("TOPLEFT", root, "TOPLEFT", PAD, -yPos)
    s:SetText(text)
    s:Layout(CW, bodyH)
    return s
end

-- What a section costs above its cards -- the heading, then the card's
-- own top padding -- and below them, that padding again plus the gap to
-- whatever comes next.
local SECTION_TOP    = TITLE_H + SECTION_PAD
local SECTION_BOTTOM = SECTION_PAD + SECTION_GAP
-- One row of cards, padded top and bottom.
local ROW_BODY_H     = CARD_H + SECTION_PAD * 2

------------------------------------------------------------
-- Section 1: Mythic+   (breakpoints: M0, +4, +9, +12)
------------------------------------------------------------
Section(Y, "|cff00aaffMythic+|r", ROW_BODY_H)
Y = Y + SECTION_TOP

-- Group M+ keys into ranges
local mpGroups = {
    { from = 2, to = 5,  label = "+2 - +5" },
    { from = 6, to = 8,  label = "+6 - +8" },
    { from = 9, to = 9,  label = "+9" },
    { from = 10, to = 12, label = "+10 - +12" },
}

for i, mg in ipairs(mpGroups) do
    -- Collect entries in this range
    local loLoot, hiLoot, loVault, hiVault = 9999, 0, 9999, 0
    local crestType = nil
    for _, e in ipairs(ns.PROGRESSION.MYTHIC_PLUS) do
        if type(e.key) == "number" and e.key >= mg.from and e.key <= mg.to then
            if e.loot < loLoot then loLoot = e.loot end
            if e.loot > hiLoot then hiLoot = e.loot end
            if e.vault < loVault then loVault = e.vault end
            if e.vault > hiVault then hiVault = e.vault end
            crestType = crestType or e.crestType
        end
    end

    local c   = CC[crestType]
    local hex = c and c.hex or "ffffffff"
    local card = MakeCard(i, Y, crestType)
    CardTitle(card, mg.label, hex)

    -- Format ilvl + track, showing highest track
    -- Compact on purpose: an en-dash with no spaces around it, and the
    -- track abbreviated. "295-302 Champ" fits where "295 - 302 Champion"
    -- did not, and a range that fits beats a range with its track cut
    -- off -- the track is the half that says how far the item level can
    -- still be pushed.
    local function FormatIlvlRange(lo, hi)
        local hiTrack = ns:GetTrackFromIlvl(hi)
        local tHex = hiTrack and CC[hiTrack] and CC[hiTrack].hex or "ffffffff"
        local short = hiTrack and (TRACK_SHORT[hiTrack] or hiTrack) or ""
        local nums = (lo == hi) and tostring(lo)
            or ("%d-%d"):format(lo, hi)
        if short == "" then return "|cffffffff" .. nums .. "|r" end
        return ("|cffffffff%s|r |c%s%s|r"):format(nums, tHex, short)
    end

    CardLine(card, 1, "Loot", FormatIlvlRange(loLoot, hiLoot))
    CardLine(card, 2, "Vault", FormatIlvlRange(loVault, hiVault))

    CardLine(card, 3, "Crest", crestType, hex)
end
Y = Y + CARD_H + SECTION_BOTTOM

------------------------------------------------------------
-- Section 2: Raid
------------------------------------------------------------
-- Season 1 had three raid wings and a tab strip to filter between them.
-- Season 2 is one raid, so the tabs are gone — the raid's name goes in
-- the section label instead.
Section(Y, "|cffa335eeRaid|r  |cff888888" ..
    (ns.PROGRESSION.RAID_NAME or "") .. "|r", ROW_BODY_H)

Y = Y + SECTION_TOP

-- Container for raid cards
local raidCardContainer = CreateFrame("Frame", nil, f)
raidCardContainer:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -Y)
raidCardContainer:SetSize(FRAME_W, CARD_H)

-- Persistent card pool: one card per difficulty index. Cards live for
-- the addon's lifetime; their child fontstrings are pooled via
-- card._pools so rebuilds do not leak frames or fontstrings.
local raidCards = {}

local function ensureCard(i)
    if raidCards[i] then return raidCards[i] end
    local card = CreateFrame("Frame", nil, raidCardContainer, "BackdropTemplate")
    card:SetSize(CARD_W, CARD_H)
    card:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    ns.SmoothFrame(card)
    -- Stripe texture lives on the card permanently; we just re-tint
    -- or hide it on each rebuild.
    card._stripe = card:CreateTexture(nil, "OVERLAY")
    card._stripe:SetSize(3, CARD_H - 10)
    card._stripe:SetPoint("LEFT", 4, 0)
    ns.DisableSharpening(card._stripe)
    card._stripe:Hide()
    raidCards[i] = card
    return card
end

local function BuildRaidCards()
    -- Hide every pooled card before re-using only the ones we need.
    for _, card in ipairs(raidCards) do card:Hide() end

    for i, diff in ipairs(ns.PROGRESSION.RAID) do
        local c   = CC[diff.crestType]
        local hex = c and c.hex or "ffffffff"

        local x = (i - 1) * (CARD_W + CARD_GAP)
        local card = ensureCard(i)
        cardResetFs(card)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", raidCardContainer, "TOPLEFT", PAD + SECTION_PAD + x, 0)
        card:SetBackdropColor(0.10, 0.10, 0.10, 0.9)
        card:SetBackdropBorderColor(c and (c.r * 0.6) or 0.25, c and (c.g * 0.6) or 0.25, c and (c.b * 0.6) or 0.25, 0.7)

        if c then
            card._stripe:SetColorTexture(c.r, c.g, c.b, 0.85)
            card._stripe:Show()
        else
            card._stripe:Hide()
        end

        -- Title
        local titleFs = cardAcquireFs(card, "GameFontNormal")
        titleFs:SetPoint("TOPLEFT", 12, -8)
        local titleStr = "|c" .. hex .. diff.difficulty .. "|r"
        if diff.mythNine then
            titleStr = titleStr .. ("  |cffff8000%s*|r"):format(diff.mythNine)
        end
        titleFs:SetText(titleStr)
        ns.ApplyTextShadow(titleFs)

        -- One card per difficulty: what bosses drop, what the vault
        -- gives, and the crest you earn.
        --
        -- Myth 9 rides along on the Loot line rather than taking a fourth
        -- row — CardLine puts row 4 at y=87 in a 100px card, which would
        -- sit on the border.
        -- Myth 9 rides on the TITLE row, not on the Loot value. It is a
        -- property of the difficulty rather than of the drop, and the
        -- value column is the one place on the card with no room to
        -- spare -- squeezed in there it truncated to "328 344 l...",
        -- which reads as two broken numbers.
        CardLine(card, 1, "Loot", tostring(diff.loot))
        CardLine(card, 2, "Vault", tostring(diff.vault))
        CardLine(card, 3, "Crest", diff.crestType, hex)

        card:Show()
    end
end

BuildRaidCards()
Y = Y + CARD_H + SECTION_BOTTOM

------------------------------------------------------------
-- Section 3: Delves  (breakpoints: T4, T7, T10, T11)
------------------------------------------------------------
Section(Y, "|cff00ff00Delves|r", ROW_BODY_H)
Y = Y + SECTION_TOP

-- Group delve tiers by crest type into ranges
local delveGroups = {
    { from = 1, to = 4,  crestType = "Adventurer" },
    { from = 5, to = 6,  crestType = "Veteran" },
    { from = 7, to = 10, crestType = "Champion" },
    { from = 11, to = 11, crestType = "Hero" },
}

for i, dg in ipairs(delveGroups) do
    local c   = CC[dg.crestType]
    local hex = c and c.hex or "ffffffff"

    -- Find ilvl range and crest amounts from the data
    local loLoot, hiLoot, loVault, hiVault = 9999, 0, 9999, 0
    local minCrest, maxCrest = 999, 0
    local isGilded = false
    for _, e in ipairs(ns.PROGRESSION.DELVES) do
        if e.tier >= dg.from and e.tier <= dg.to then
            if e.loot then
                if e.loot < loLoot then loLoot = e.loot end
                if e.loot > hiLoot then hiLoot = e.loot end
                if e.vault < loVault then loVault = e.vault end
                if e.vault > hiVault then hiVault = e.vault end
            else
                isGilded = true
            end
            local amt = tonumber(e.crestAmount) or 0
            if amt > 0 then
                if amt < minCrest then minCrest = amt end
                if amt > maxCrest then maxCrest = amt end
            end
        end
    end

    local card = MakeCard(i, Y, dg.crestType)

    -- Title: "Tier 1 - 4" or "Tier 11"
    local titleStr = dg.from == dg.to and ("Tier " .. dg.from) or ("Tier " .. dg.from .. " - " .. dg.to)
    CardTitle(card, titleStr, hex)

    if isGilded then
        CardLine(card, 1, "", "Gilded Stash 4x/week")
        CardLine(card, 2, "Crest", "10 Hero + 5 Myth", hex)
    else
        local lootStr = loLoot == hiLoot and tostring(loLoot) or (loLoot .. " - " .. hiLoot)
        local vaultStr = loVault == hiVault and tostring(loVault) or (loVault .. " - " .. hiVault)
        CardLine(card, 1, "Loot", lootStr)
        CardLine(card, 2, "Vault", vaultStr)

        local crestStr = dg.crestType
        -- Guard on maxCrest, not minCrest: minCrest is seeded to 999 and
        -- only ever comes down when a real amount is found, so testing it
        -- rendered "999-0 Adventurer" whenever no amounts were known.
        -- Season 2 delve crest quantities are not confirmed, so those
        -- fields are empty and we show the crest type alone.
        if maxCrest > 0 then
            local amtStr = minCrest == maxCrest and tostring(minCrest) or (minCrest .. "-" .. maxCrest)
            crestStr = amtStr .. " " .. dg.crestType
        end
        CardLine(card, 3, "Crest", crestStr, hex)
    end
end
Y = Y + CARD_H + SECTION_BOTTOM

------------------------------------------------------------
-- Section 4: Bottom row — two wider mini-panels
------------------------------------------------------------
local PCOLS  = 2
local PGAP   = 10
local PW     = math.floor((CW - (PCOLS - 1) * PGAP) / PCOLS) -- ~461
local PLINE  = 18
-- Sized to their contents rather than to a guessed 110px.
--
-- Prey has three lines and Crafting three; at a fixed height both cards
-- ended less than half way down and the page finished on two mostly
-- empty boxes. A card that is taller than what it holds reads as
-- something failing to load.
local function PanelHeight(rows)
    return SECTION_PAD + math.max(rows, 1) * PLINE + SECTION_PAD
end

--- One of the two bottom panels, on the same section card as the rows
--- above it.
---
--- Their titles used to sit INSIDE the panel while every other section
--- on the page put its title above one, so the bottom of the page read
--- as a different kind of thing from the top. Returns the card's body,
--- which is what the lines below are anchored into.
local function MakePanel(panelCol, title, titleHex, rows)
    local x = (panelCol - 1) * (PW + PGAP)
    local sec = ns.Widgets:SectionCard(f)
    sec:SetPoint("TOPLEFT", root, "TOPLEFT", PAD + x, -Y)
    sec:SetText("|c" .. titleHex .. title .. "|r")
    sec:Layout(PW, PanelHeight(rows))
    return sec.body
end

local function PanelLine(panel, row, text)
    local s = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s:SetPoint("TOPLEFT", 10, -SECTION_PAD - (row - 1) * PLINE)
    s:SetWidth(PW - 20)
    s:SetJustifyH("LEFT")
    s:SetWordWrap(false)
    s:SetTextColor(0.75, 0.75, 0.75)
    s:SetText(text)
end

-- Panel 1 — Prey
local p1 = MakePanel(1, "Prey", "ffffff66", #ns.PROGRESSION.PREY)
for i, e in ipairs(ns.PROGRESSION.PREY) do
    local c   = CC[e.crestType]
    local hex = c and c.hex or "ffffffff"
    PanelLine(p1, i,
        e.difficulty .. "  " .. e.loot .. " / " .. e.vault .. "  |c" .. hex .. e.crestType .. "|r")
end

-- Panel 2 — Crafting (Spark tiers)
local p2 = MakePanel(2, "Crafting (Spark)", "ffff8000", #ns.PROGRESSION.CRAFTING_SPARK)
for i, spark in ipairs(ns.PROGRESSION.CRAFTING_SPARK) do
    local lo = spark.qualities[1]
    local hi = spark.qualities[#spark.qualities]
    PanelLine(p2, i,
        "|c" .. spark.color .. spark.label .. "|r  " .. lo .. " \226\128\147 " .. hi)
end

