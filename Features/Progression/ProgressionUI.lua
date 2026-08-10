local _, ns = ...

------------------------------------------------------------
-- Progression Dashboard: card-based single-page overview
------------------------------------------------------------

-- Layout constants
local FRAME_W, FRAME_H = ns:GetAppFrameSize()
local PAD         = 14
local CARD_GAP    = 10
local SECTION_GAP = 14
local uiScale     = ns:GetUIScale()
local CARD_H      = math.floor(100 * uiScale)
local TITLE_H     = 22
local CONTENT_TOP = -34
local CW          = FRAME_W - PAD * 2                        -- 932
local COLS        = 4
local CARD_W      = math.floor((CW - (COLS - 1) * CARD_GAP) / COLS) -- ~225

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
ns.ProgressionFrame = f

-- Header
-- Season moves to the subtitle slot, matching the app frame's header.
-- Capture the subtitle too: app mode hides the standalone chrome, and a
-- subtitle left behind sits under the app's own page title.
local headerIcon, header, headerSub = ns.MakeWindowHeader(f, "|cffaaaaaaProgression|r",
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
        f:SetBackdrop(nil)
    else
        header:Show()
        if headerSub then headerSub:Show() end
        closeBtn:Show()
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
        ns.SmoothFrame(f)
    end
end

------------------------------------------------------------
-- Y cursor  (increases downward; actual anchor = CONTENT_TOP - Y)
------------------------------------------------------------
local Y = 0

------------------------------------------------------------
-- Card factory
------------------------------------------------------------
local function MakeCard(col, yPos, crestType)
    local x = (col - 1) * (CARD_W + CARD_GAP)
    local card = CreateFrame("Frame", nil, f, "BackdropTemplate")
    card:SetSize(CARD_W, CARD_H)
    card:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + x, CONTENT_TOP - yPos)
    card:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    card:SetBackdropColor(0.10, 0.10, 0.10, 0.9)
    ns.SmoothFrame(card)

    local c = crestType and CC[crestType]
    if c then
        card:SetBackdropBorderColor(c.r * 0.6, c.g * 0.6, c.b * 0.6, 0.7)
        local stripe = card:CreateTexture(nil, "OVERLAY")
        stripe:SetSize(3, CARD_H - 10)
        stripe:SetPoint("LEFT", 4, 0)
        stripe:SetColorTexture(c.r, c.g, c.b, 0.85)
        ns.DisableSharpening(stripe)
    else
        card:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.5)
    end
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
    v:SetPoint("TOPLEFT", 62, -yOff)
    v:SetWidth(CARD_W - 74)
    v:SetJustifyH("LEFT")
    v:SetWordWrap(false)
    if hex then
        v:SetText("|c" .. hex .. value .. "|r")
    else
        v:SetText(value)
    end
end

local function SectionLabel(yPos, text)
    local s = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, CONTENT_TOP - yPos)
    s:SetText(text)
    ns.ApplyTextShadow(s)
end

------------------------------------------------------------
-- Section 1: Mythic+   (breakpoints: M0, +4, +9, +12)
------------------------------------------------------------
SectionLabel(Y, "|cff00aaffMythic+|r")
Y = Y + TITLE_H

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
    local function FormatIlvlRange(lo, hi)
        local hiTrack = ns:GetTrackFromIlvl(hi)
        local tHex = hiTrack and CC[hiTrack] and CC[hiTrack].hex or "ffffffff"
        local short = hiTrack or ""
        if lo == hi then
            return "|cffffffff" .. lo .. "|r |c" .. tHex .. short .. "|r"
        else
            return "|cffffffff" .. lo .. "|r - |cffffffff" .. hi .. "|r |c" .. tHex .. short .. "|r"
        end
    end

    CardLine(card, 1, "Loot", FormatIlvlRange(loLoot, hiLoot))
    CardLine(card, 2, "Vault", FormatIlvlRange(loVault, hiVault))

    CardLine(card, 3, "Crest", crestType, hex)
end
Y = Y + CARD_H + SECTION_GAP

------------------------------------------------------------
-- Section 2: Raid
------------------------------------------------------------
-- Season 1 had three raid wings and a tab strip to filter between them.
-- Season 2 is one raid, so the tabs are gone — the raid's name goes in
-- the section label instead.
SectionLabel(Y, "|cffa335eeRaid|r  |cff888888" ..
    (ns.PROGRESSION.RAID_NAME or "") .. "|r")

Y = Y + TITLE_H

-- Container for raid cards
local raidCardContainer = CreateFrame("Frame", nil, f)
raidCardContainer:SetPoint("TOPLEFT", f, "TOPLEFT", 0, CONTENT_TOP - Y)
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
        card:SetPoint("TOPLEFT", raidCardContainer, "TOPLEFT", PAD + x, 0)
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
        titleFs:SetText("|c" .. hex .. diff.difficulty .. "|r")
        ns.ApplyTextShadow(titleFs)

        -- One card per difficulty: what bosses drop, what the vault
        -- gives, and the crest you earn.
        --
        -- Myth 9 rides along on the Loot line rather than taking a fourth
        -- row — CardLine puts row 4 at y=87 in a 100px card, which would
        -- sit on the border.
        local lootStr = tostring(diff.loot)
        if diff.mythNine then
            lootStr = lootStr .. "  |cffff8000" .. diff.mythNine .. " last 2|r"
        end
        CardLine(card, 1, "Loot", lootStr)
        CardLine(card, 2, "Vault", tostring(diff.vault))
        CardLine(card, 3, "Crest", diff.crestType, hex)

        card:Show()
    end
end

BuildRaidCards()
Y = Y + CARD_H + SECTION_GAP

------------------------------------------------------------
-- Section 3: Delves  (breakpoints: T4, T7, T10, T11)
------------------------------------------------------------
SectionLabel(Y, "|cff00ff00Delves|r")
Y = Y + TITLE_H

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
Y = Y + CARD_H + SECTION_GAP

------------------------------------------------------------
-- Section 4: Bottom row — two wider mini-panels
------------------------------------------------------------
local PCOLS  = 2
local PGAP   = 10
local PW     = math.floor((CW - (PCOLS - 1) * PGAP) / PCOLS) -- ~461
local PH     = math.floor(110 * uiScale)
local PLINE  = 18

local function MakePanel(panelCol, title, titleHex)
    local x = (panelCol - 1) * (PW + PGAP)
    local p = CreateFrame("Frame", nil, f, "BackdropTemplate")
    p:SetSize(PW, PH)
    p:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + x, CONTENT_TOP - Y)
    p:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    p:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    p:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.5)
    ns.SmoothFrame(p)

    local s = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s:SetPoint("TOPLEFT", 10, -8)
    s:SetText("|c" .. titleHex .. title .. "|r")
    ns.ApplyTextShadow(s)
    return p
end

local function PanelLine(panel, row, text)
    local s = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s:SetPoint("TOPLEFT", 10, -30 - (row - 1) * PLINE)
    s:SetWidth(PW - 20)
    s:SetJustifyH("LEFT")
    s:SetWordWrap(false)
    s:SetTextColor(0.75, 0.75, 0.75)
    s:SetText(text)
end

-- Panel 1 — Prey
local p1 = MakePanel(1, "Prey", "ffffff66")
for i, e in ipairs(ns.PROGRESSION.PREY) do
    local c   = CC[e.crestType]
    local hex = c and c.hex or "ffffffff"
    PanelLine(p1, i,
        e.difficulty .. "  " .. e.loot .. " / " .. e.vault .. "  |c" .. hex .. e.crestType .. "|r")
end

-- Panel 2 — Crafting (Spark tiers)
local p2 = MakePanel(2, "Crafting (Spark)", "ffff8000")
for i, spark in ipairs(ns.PROGRESSION.CRAFTING_SPARK) do
    local lo = spark.qualities[1]
    local hi = spark.qualities[#spark.qualities]
    PanelLine(p2, i,
        "|c" .. spark.color .. spark.label .. "|r  " .. lo .. " \226\128\147 " .. hi)
end

