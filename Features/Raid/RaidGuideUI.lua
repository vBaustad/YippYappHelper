local _, ns = ...

------------------------------------------------------------
-- The Guide view, inside Raid Tools.
--
-- A boss list on the left, and on the right the same boss explained for
-- the role you are actually playing. The role filter is the whole point:
-- the reason raid guides are hard to read before a pull is that four
-- fifths of any page is addressed to somebody else, and a player
-- skimming for their own instruction has to do the filtering in their
-- head while the pull timer runs.
--
-- So the page picks your role for you -- from your group assignment if
-- you have one, from your specialisation if you do not -- and shows that
-- column first. The other two are one click away and nothing is hidden,
-- but the default is the one you need.
--
------------------------------------------------------------
-- THE UNIT ON THE PAGE IS A MECHANIC.
--
-- This page used to print phases as bullet points of prose. That is a
-- correct document and a bad pre-pull read: everything looked the same,
-- so nothing could be found. A mechanic now draws as a ROW --
--
--     [icon]  Essence Rend  ·  Dispel
--             Take it to the edge first
--             you get pulled, then knocked back...
--
-- -- with the client's own spell icon, the client's own tooltip on
-- hover, and a shift-click that links the spell into chat. The icon is
-- not decoration: it is the thing a player recognises mid-pull, when
-- they have seen the art on a debuff bar and cannot remember the name.
--
-- The imperative sits on its own line, in its own colour, directly
-- under the name. If a reader takes one line off a mechanic it should
-- be that one, so it is the line the eye lands on.
--
------------------------------------------------------------
-- DIFFICULTY IS SHOWN WHERE IT HAPPENS.
--
-- Heroic used to be a page at the end -- "what Heroic adds" -- which is
-- the wrong shape for the question a player actually has. Nobody wants
-- a list of heroic changes; they want to know whether THIS mechanic,
-- the one they are reading, is different tonight.
--
-- So a mechanic that only exists above Normal carries a badge on its
-- name, and a mechanic that merely CHANGES carries a badged line under
-- it. Selecting Normal hides both. The boss-wide summary still exists,
-- but it is pinned at the top with the rules, where it is read before
-- the pull rather than found after it.
--
-- Three difficulties, because the Lair and the raid both go to Mythic
-- and sending a player elsewhere for the third column is the same
-- errand this page exists to save them.
------------------------------------------------------------

ns.RaidGuideUI = ns.RaidGuideUI or {}
local UI = ns.RaidGuideUI

local LIST_W  = 196
local GUTTER  = 14
local ROW_H   = 30
-- From the shell, not chosen here. At 12 this view sat four pixels
-- further left than every other page, which is exactly the drift the
-- shared constant exists to stop.
local PAD     = (ns.Shell and ns.Shell.PAD) or 12

-- Vertical budget.
--
-- A SectionCard costs its heading, its ornament, its inner padding and
-- the gap to the next one -- about fifty pixels before a word is drawn.
-- A card marks a KIND of thing (what to know, and the phase you are
-- on); everything inside it is a sub-heading or a mechanic row.
local CARD_GAP    = 10
local BODY_TOP    = 6
local BODY_BOT    = 12
local SUBHEAD_TOP = 8
local SUBHEAD_BOT = 4
local LINE_GAP    = 3

-- Inside a mechanic row.
local MECH_ICON   = 26   -- the spell icon
local MECH_TEXTX  = MECH_ICON + 9
local MECH_GAP    = 9    -- between one mechanic and the next
local MECH_TIGHT  = 1    -- name to imperative
local MECH_LINE   = 2    -- between body lines

------------------------------------------------------------
-- Type
--
-- Everything on this page used to be GameFontNormalSmall, which is ten
-- point. It is a page you read in a hurry, often while something else
-- is happening, so the body moved up to twelve and only the labels --
-- tags, badges, the rail's captions -- stayed small. Small is now a
-- deliberate signal that a thing is a label rather than a sentence.
------------------------------------------------------------
local FONT_BODY  = "GameFontHighlight"      -- 12pt, the reading size
local FONT_NAME  = "GameFontNormal"         -- 12pt, for a mechanic's name
local FONT_HEAD  = "GameFontNormal"         -- sub-headings inside a card
local FONT_LABEL = "GameFontNormalSmall"    -- tags, badges, rail captions

local W = ns.Widgets

local ROLE_LABEL = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }
local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }

-- The mark on a name no source could confirm. Two bosses carried this
-- for months; both were settled on 2026-08-20 and it is kept because the
-- next patch will produce another one.
local UNSURE = "?"
local function Flagged(text, isUnsure)
    if not isUnsure then return text end
    return text .. W:Tint("faint", "\194\160" .. UNSURE)
end

-- A spell with no icon. Preferred over leaving the texture blank,
-- because a missing icon and a mechanic we have no spell id for are the
-- same thing to a reader and both mean "the client could not tell us".
local ICON_UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark"

--- The client's icon for a spell, or the question mark.
local function SpellIcon(spellID)
    if not spellID then return ICON_UNKNOWN end
    local tex = C_Spell and C_Spell.GetSpellTexture
        and C_Spell.GetSpellTexture(spellID)
    return tex or ICON_UNKNOWN
end

------------------------------------------------------------
-- Saved state
------------------------------------------------------------
local function Store()
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.raidGuide = YippYappHelperDB.raidGuide or {}
    local s = YippYappHelperDB.raidGuide
    -- Migration, once. The page held a boolean when it had two
    -- difficulties; a returning player's saved `heroic = true` has to
    -- mean Heroic rather than silently resetting them to Normal.
    if s.diff == nil then
        s.diff = s.heroic and "heroic" or "normal"
    end
    return s
end

--- The selected difficulty key, always one the data knows about.
local function CurrentDiff()
    local G = ns.RaidGuide
    local want = Store().diff
    for _, d in ipairs(G and G.DIFFS or {}) do
        if d.key == want then return d.key end
    end
    return "normal"
end

--- The tone a difficulty is drawn in.
local function DiffTone(key)
    for _, d in ipairs(ns.RaidGuide and ns.RaidGuide.DIFFS or {}) do
        if d.key == key then return d.tone end
    end
    return { 0.45, 0.85, 1.0 }
end

--- The role to open on.
---
--- Group assignment first, because if you are in a raid that is the
--- role you are about to play whatever your spec says. Spec second, for
--- reading the guide alone at the bank. The saved choice wins over both.
local function DefaultRole()
    local saved = Store().role
    if saved and ROLE_LABEL[saved] then return saved end

    local assigned = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    if assigned and ROLE_LABEL[assigned] then return assigned end

    if GetSpecialization then
        local idx = GetSpecialization()
        if idx then
            local role = select(5, GetSpecializationInfo(idx))
            if role and ROLE_LABEL[role] then return role end
        end
    end
    return "DAMAGER"
end

------------------------------------------------------------
-- Which page of the fight is open
--
-- Deliberately NOT saved. A remembered role is a preference; a
-- remembered page is a stale reading position. It resets to 1 whenever
-- the boss or the difficulty changes.
------------------------------------------------------------
local page, pageBoss, pageDiff = 1, nil, nil

--- Set the open page. Exposed so Tools\loadcheck.py can walk all of them.
function UI:SetPage(n)
    page = math.max(1, math.floor(tonumber(n) or 1))
    self:Refresh()
end

function UI:GetPageCount() return self._pageCount or 1 end

------------------------------------------------------------
-- Text pool
--
-- Paragraphs are measured rather than assumed: every one of these is
-- wrapped body text whose height depends on the width it was given, and
-- a page that advanced its cursor by a fixed line height would overlap
-- the moment a sentence wrapped to three lines instead of two.
------------------------------------------------------------
local fsPool, fsIdx = {}, 0

local function AcquireFS(parent, font)
    fsIdx = fsIdx + 1
    local fs = fsPool[fsIdx]
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", font or FONT_BODY)
        fsPool[fsIdx] = fs
    else
        fs:SetFontObject(font or FONT_BODY)
    end
    fs:SetParent(parent)
    fs:ClearAllPoints()
    fs:SetWordWrap(true)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetTextColor(W:Color("text"))
    fs:Show()
    return fs
end

local function ReleaseAll()
    for i = 1, fsIdx do fsPool[i]:Hide() end
    fsIdx = 0
end

--- Measured height of a wrapped string.
---
--- GetStringHeight is only correct once the text and the width are both
--- set, which is why this exists as a helper rather than as two lines at
--- each call site -- getting the order wrong returns the height of the
--- PREVIOUS text, and the error is a few pixels, so it survives review.
local function Paragraph(parent, x, y, width, text, font, colourKey, gap)
    local fs = AcquireFS(parent, font)
    fs:SetWidth(width)
    fs:SetText(text or "")
    if colourKey then fs:SetTextColor(W:Color(colourKey)) end
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return y - math.max(fs:GetStringHeight() or 12, 12) - (gap or LINE_GAP)
end

--- A bulleted line. The bullet is a separate string so wrapped lines
--- hang under the text rather than under the dot.
local function Bullet(parent, x, y, width, text, colourKey, gap)
    local dot = AcquireFS(parent, FONT_BODY)
    dot:SetWidth(10)
    dot:SetText(W:Tint("faint", "-"))
    dot:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return Paragraph(parent, x + 12, y, width - 12, text,
        FONT_BODY, colourKey, gap)
end

--- A sub-heading inside a card.
local function SubHead(parent, x, y, width, text, accent, font)
    local fs = AcquireFS(parent, font or FONT_HEAD)
    fs:SetWidth(width)
    fs:SetText(text or "")
    if accent then fs:SetTextColor(accent[1], accent[2], accent[3]) end
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return y - math.max(fs:GetStringHeight() or 12, 12) - SUBHEAD_BOT
end

------------------------------------------------------------
-- Cards
------------------------------------------------------------
local cardPool, cardIdx = {}, 0

local function AcquireCard(parent)
    cardIdx = cardIdx + 1
    local c = cardPool[cardIdx]
    if not c then
        c = W:SectionCard(parent, 8)
        cardPool[cardIdx] = c
    end
    c:SetParent(parent)
    c:ClearAllPoints()
    c:Show()
    return c
end

local function ReleaseCards()
    for i = 1, cardIdx do cardPool[i]:Hide() end
    cardIdx = 0
end

-- Handed to Tools\loadcheck.py, the same way BisUI exposes its own, so
-- the geometry phase can measure these cards rather than trust them.
UI._cards = cardPool

------------------------------------------------------------
-- Spell icons
--
-- Pooled buttons rather than plain textures, because the icon is the
-- interactive part of a mechanic row: hovering it gives the client's own
-- tooltip -- the real numbers, in the player's own locale -- and
-- shift-clicking links the spell into chat, which is how a raid leader
-- actually says "this one".
--
-- The tooltip is the client's, never ours. Anything we wrote about the
-- mechanic is already on the page next to it; repeating a worse version
-- of the game's own text in a tooltip would be the only place on this
-- page where the addon competes with the client instead of adding to it.
------------------------------------------------------------
local iconPool, iconIdx = {}, 0

local function AcquireIcon(parent)
    iconIdx = iconIdx + 1
    local b = iconPool[iconIdx]
    if not b then
        b = CreateFrame("Button", nil, parent)
        b:SetSize(MECH_ICON, MECH_ICON)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        -- Icon art carries a border in its outer few percent; left
        -- untrimmed it reads as a smudge at this size.
        b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        b.edge = b:CreateTexture(nil, "OVERLAY")
        b.edge:SetPoint("TOPLEFT", -1, 1)
        b.edge:SetPoint("BOTTOMRIGHT", 1, -1)
        b.edge:SetColorTexture(0, 0, 0, 0)

        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetAllPoints()
        b.hl:SetColorTexture(1, 1, 1, 0.16)

        b:SetScript("OnEnter", function(self)
            if not self.spellID then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            -- pcall because a spell id from a pre-launch guide may not
            -- exist on this client, and a tooltip must cost us a hover
            -- rather than the render.
            local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID)
            if not ok then
                GameTooltip:SetText(self.spellName or "")
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Shift-click to link it in chat.", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(self)
            if not (self.spellID and IsShiftKeyDown and IsShiftKeyDown()) then return end
            local link = C_Spell and C_Spell.GetSpellLink
                and C_Spell.GetSpellLink(self.spellID)
            if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
        end)
        iconPool[iconIdx] = b
    end
    b:SetParent(parent)
    b:ClearAllPoints()
    b:Show()
    return b
end

local function ReleaseIcons()
    for i = 1, iconIdx do iconPool[i]:Hide() end
    iconIdx = 0
end

------------------------------------------------------------
-- The pager strip
------------------------------------------------------------
local CHIP_W, CHIP_H, CHIP_GAP = 24, 20, 3
local STEP_W = 46

local chipPool, chipIdx = {}, 0

local function AcquireChip(parent)
    chipIdx = chipIdx + 1
    local b = chipPool[chipIdx]
    if not b then
        b = CreateFrame("Button", nil, parent, "BackdropTemplate")
        b:SetSize(CHIP_W, CHIP_H)
        b.text = b:CreateFontString(nil, "OVERLAY", FONT_LABEL)
        b.text:SetAllPoints()
        ns.AddGlowHighlight(b, 0.10)
        b:SetScript("OnEnter", function(self)
            if not self.tip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.tip)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        chipPool[chipIdx] = b
    end
    b:SetParent(parent)
    b:ClearAllPoints()
    b:Show()
    return b
end

local function ReleaseChips()
    for i = 1, chipIdx do chipPool[i]:Hide() end
    chipIdx = 0
end

------------------------------------------------------------
-- Build
------------------------------------------------------------
local host, listFrame, detail, scroll
local rowButtons = {}
local roleButtons = {}
local diffButtons
local lustLabel, lustIcon, lustText, lustBaseY

--- A small muted caption over a group of controls in the rail.
local function RailLabel(parent, text, y)
    local fs = W:Label(parent, FONT_LABEL)
    fs:SetPoint("TOPLEFT", 2, y)
    fs:SetTextColor(W:Color("faint"))
    fs:SetText(text)
    return fs
end

------------------------------------------------------------
-- Bloodlust
--
-- Always "Bloodlust", on both factions, with the Bloodlust icon. This
-- used to follow the player's faction and show Alliance players
-- "Heroism"; that was wrong about how people talk. Raids of both
-- factions call it Bloodlust, and so does every line in our own data.
------------------------------------------------------------
local LUST_HORDE    = 2825      -- Bloodlust
local LUST_ALLIANCE = 32182     -- Heroism
local LUST_OTHERS   = { 80353, 264667, 390386 }
local LUST_FALLBACK = "Interface\\Icons\\Spell_Nature_BloodLust"

local function LustLook()
    local label = "Bloodlust"
    local order = { LUST_HORDE, LUST_ALLIANCE }
    for _, id in ipairs(LUST_OTHERS) do order[#order + 1] = id end
    for _, id in ipairs(order) do
        local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
        if tex then return label, tex end
    end
    return label, LUST_FALLBACK
end

function UI:BuildInto(parent)
    if host then
        host:SetParent(parent)
        host:ClearAllPoints()
        host:SetAllPoints(parent)
        return
    end

    host = CreateFrame("Frame", nil, parent)
    host:SetAllPoints(parent)
    -- For Tools/render.py, same convention as UI._cards.
    UI._host = host

    ------------------------------------------------------------
    -- Boss list
    ------------------------------------------------------------
    listFrame = CreateFrame("Frame", nil, host)
    listFrame:SetPoint("TOPLEFT", 0, 0)
    listFrame:SetPoint("BOTTOMLEFT", 0, 0)
    listFrame:SetWidth(LIST_W)

    local listTitle = W:Label(listFrame, FONT_LABEL)
    listTitle:SetPoint("TOPLEFT", 2, -2)
    listTitle:SetTextColor(W:Color("muted"))
    listTitle:SetText((ns.RaidGuide and ns.RaidGuide.instance.name) or "Raid")

    local G = ns.RaidGuide
    local bosses = G and G:Ordered() or {}

    -- Grouped by instance, with a heading whenever it changes. The rail
    -- lists more than one place now -- the raid, and the Lair that is
    -- the only other source of raid gear this patch. Without a heading
    -- the Grotto's single boss appears as another "1" under the last of
    -- the eight, which reads as a numbering bug.
    local gap = G and G.missing and G.missing[1]
    local vaCount = 0
    for _, b in ipairs(bosses) do
        if G:InstanceOf(b).key == "va" then vaCount = vaCount + 1 end
    end

    local function AddMissingRow(y)
        if not gap then return y end
        local row = CreateFrame("Frame", nil, listFrame)
        row:SetSize(LIST_W - 4, ROW_H)
        row:SetPoint("TOPLEFT", 0, y)
        row:EnableMouse(true)

        local num = W:Label(row, FONT_LABEL, "CENTER")
        num:SetPoint("LEFT", 7, 0)
        num:SetWidth(14)
        num:SetText(tostring(vaCount + 1))
        num:SetTextColor(W:Color("faint"))

        local name = W:Label(row, FONT_LABEL)
        name:SetPoint("LEFT", 25, 0)
        name:SetPoint("RIGHT", -6, 0)
        name:SetWordWrap(false)
        name:SetTextColor(W:Color("faint"))
        name:SetText(Flagged(gap.name, gap.unsure) .. W:Tint("faint", "  --  no guide"))

        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(gap.name)
            GameTooltip:AddLine(gap.why, 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return y - (ROW_H + 3)
    end

    local rowsBottom = -18
    local lastKey = G and G:InstanceOf(bosses[1]).key or nil
    for i, boss in ipairs(bosses) do
        local inst = G and G:InstanceOf(boss)
        if inst and inst.key ~= lastKey then
            if lastKey == "va" then rowsBottom = AddMissingRow(rowsBottom) end
            rowsBottom = rowsBottom - 8
            local head = W:Label(listFrame, FONT_LABEL)
            head:SetPoint("TOPLEFT", 2, rowsBottom)
            head:SetTextColor(W:Color("muted"))
            head:SetText(inst.name)
            rowsBottom = rowsBottom - 16
            lastKey = inst.key
        end

        local b = CreateFrame("Button", nil, listFrame, "BackdropTemplate")
        b:SetSize(LIST_W - 4, ROW_H)
        b:SetPoint("TOPLEFT", 0, rowsBottom)
        rowsBottom = rowsBottom - (ROW_H + 3)

        b.num = W:Label(b, FONT_LABEL, "CENTER")
        b.num:SetPoint("LEFT", 7, 0)
        b.num:SetWidth(14)
        b.num:SetText(tostring(boss.order))
        b.num:SetTextColor(W:Color("faint"))

        b.name = W:Label(b, FONT_BODY)
        b.name:SetPoint("LEFT", 25, 0)
        b.name:SetPoint("RIGHT", -6, 0)
        b.name:SetWordWrap(false)

        ns.AddGlowHighlight(b, 0.08)
        b.bossId = boss.id
        b:SetScript("OnClick", function()
            Store().boss = boss.id
            UI:Refresh()
        end)
        rowButtons[i] = b
    end

    if lastKey == "va" then rowsBottom = AddMissingRow(rowsBottom) end

    ------------------------------------------------------------
    -- Role and difficulty, under the list
    --
    -- These change what the page SAYS rather than which rows it lists,
    -- so they do not belong in the shell's filter strip -- and they do
    -- not belong across the top of the reading column either, which is
    -- where they were. The rail already has the room.
    ------------------------------------------------------------
    local y = rowsBottom - 14

    RailLabel(listFrame, "Reading it as", y)
    y = y - 15

    local x = 0
    for _, role in ipairs(ROLE_ORDER) do
        local b = CreateFrame("Button", nil, listFrame, "BackdropTemplate")
        b:SetSize(62, 20)
        b:SetPoint("TOPLEFT", x, y)
        b.text = b:CreateFontString(nil, "OVERLAY", FONT_LABEL)
        b.text:SetAllPoints()
        b.text:SetText(ROLE_LABEL[role])
        ns.AddGlowHighlight(b, 0.08)
        b.role = role
        b:SetScript("OnClick", function()
            Store().role = role
            UI:Refresh()
        end)
        roleButtons[#roleButtons + 1] = b
        x = x + 64
    end
    y = y - 28

    RailLabel(listFrame, "Difficulty", y)
    y = y - 15

    -- All three on screen rather than one button showing the current
    -- one, which reads either as "you are here" or as "click for this"
    -- depending on who is looking. They fit the rail at the same width
    -- as the role row, so the two strips line up.
    diffButtons = {}
    x = 0
    for _, def in ipairs((G and G.DIFFS) or {}) do
        local b = CreateFrame("Button", nil, listFrame, "BackdropTemplate")
        b:SetSize(62, 20)
        b:SetPoint("TOPLEFT", x, y)
        b.text = b:CreateFontString(nil, "OVERLAY", FONT_LABEL)
        b.text:SetAllPoints()
        b.text:SetText(def.label)
        ns.AddGlowHighlight(b, 0.08)
        b.diff = def.key
        b.label = def.label
        b:SetScript("OnClick", function()
            Store().diff = def.key
            UI:Refresh()
        end)
        -- The count on the tooltip replaced a whole card. Reading the
        -- fight on Normal used to end with a card whose only line was
        -- "4 extra things happen on Heroic, switch the button above" --
        -- fifty pixels of chrome to point at a control already on
        -- screen.
        if def.key ~= "normal" then
            b:SetScript("OnEnter", function(self)
                if not self.count or self.count == 0 then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.label)
                GameTooltip:AddLine(("%d things on this fight change or are "
                    .. "added. Everything below still happens."):format(self.count),
                    0.7, 0.7, 0.7, true)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        diffButtons[#diffButtons + 1] = b
        x = x + 64
    end
    y = y - 30

    ------------------------------------------------------------
    -- Bloodlust, under the difficulty
    --
    -- It is not a rule -- it is a plan, decided before the pull and then
    -- not thought about again -- so it belongs with the other things you
    -- set before you read: your role and your difficulty.
    --
    -- The block reflows: its text wraps to two or three lines in a 170px
    -- rail depending on the boss, so the button under it is anchored in
    -- Refresh against the measured height rather than at a fixed offset.
    ------------------------------------------------------------
    local lustName, lustTexture = LustLook()
    lustBaseY = y
    lustLabel = RailLabel(listFrame, lustName, y)

    lustIcon = listFrame:CreateTexture(nil, "ARTWORK")
    lustIcon:SetSize(20, 20)
    lustIcon:SetPoint("TOPLEFT", 2, y - 16)
    lustIcon:SetTexture(lustTexture)
    lustIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    lustText = W:Label(listFrame, FONT_LABEL)
    lustText:SetPoint("TOPLEFT", 28, y - 16)
    lustText:SetWidth(LIST_W - 32)
    lustText:SetJustifyV("TOP")

    ------------------------------------------------------------
    -- Detail column
    ------------------------------------------------------------
    detail = CreateFrame("Frame", nil, host)
    detail:SetPoint("TOPLEFT", listFrame, "TOPRIGHT", GUTTER, 0)
    detail:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)

    -- No header.
    --
    -- This column used to open with the boss's name in large type and
    -- its one-liner under it, costing 44px before a word of the guide
    -- was drawn. The rail on the left already names every boss and
    -- highlights the selected one in its own accent colour, so the
    -- header was answering a question the page had answered before the
    -- reader looked at it -- and it was answering it in the most
    -- expensive part of the window, the top of the reading column.
    --
    -- The one-liner survives; it is the only part that was ever content
    -- rather than a label, and it moved into the pinned card where it
    -- costs one line instead of a banner.
    scroll = W:ScrollList(detail)
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -22, 4)
end

------------------------------------------------------------
-- Refresh
------------------------------------------------------------
local function StyleToggle(button, on, accent)
    W:Apply(button, on and "inset" or "row")
    if on then
        button.text:SetTextColor(accent[1], accent[2], accent[3])
    else
        button.text:SetTextColor(W:Color("muted"))
    end
end

--- A coloured badge, for a difficulty word sitting inside a line of
--- text. Small caps rather than a bracket, so it reads as a label and
--- not as part of the sentence.
local function Badge(text, tone)
    return ("|cff%02x%02x%02x%s|r"):format(
        math.floor(tone[1] * 255 + 0.5),
        math.floor(tone[2] * 255 + 0.5),
        math.floor(tone[3] * 255 + 0.5), text)
end

function UI:Refresh()
    if not host then return end
    local G = ns.RaidGuide
    if not G then return end

    -- The Encounter Journal gets a chance to correct anything the
    -- written source was unsure about, the first time the page is
    -- looked at.
    if G.EnrichFromJournal and not G._enriched then
        pcall(G.EnrichFromJournal, G)
    end

    local store = Store()
    local bosses = G:Ordered()
    if not store.boss or not G:Get(store.boss) then
        store.boss = bosses[1] and bosses[1].id
    end
    local boss = G:Get(store.boss)
    if not boss then return end

    -- Let the client name this boss's mechanics and hand us their spell
    -- ids. Per boss and once, and pcall'd for the same reason the
    -- footnote below is: a journal that answers oddly must cost us
    -- icons, not the render.
    if G.ResolveMechanics then pcall(G.ResolveMechanics, G, boss) end

    local role = DefaultRole()
    local diff = CurrentDiff()
    local accent = boss.accent or { 0.45, 0.85, 1.0 }

    -- A different boss or difficulty is a different fight; the page you
    -- were on does not carry over to it.
    if pageBoss ~= boss.id or pageDiff ~= diff then
        page, pageBoss, pageDiff = 1, boss.id, diff
    end

    ------------------------------------------------------------
    -- List
    ------------------------------------------------------------
    for _, b in ipairs(rowButtons) do
        local rowBoss = G:Get(b.bossId)
        local selected = b.bossId == store.boss
        W:Apply(b, selected and "inset" or "row")
        if selected then
            local c = rowBoss and rowBoss.accent or accent
            b.name:SetTextColor(c[1], c[2], c[3])
        else
            b.name:SetTextColor(W:Color("text"))
        end
        b.name:SetText(rowBoss
            and Flagged(rowBoss.name, rowBoss.unsure) or "")
    end

    ------------------------------------------------------------
    -- Controls
    ------------------------------------------------------------
    -- With the header gone the rail is the only place a boss is named,
    -- so a name nobody could confirm has to carry its mark there.
    local flagged = boss.unsure and true or false

    for _, b in ipairs(roleButtons) do
        StyleToggle(b, b.role == role, accent)
    end

    -- How much a difficulty changes about THIS boss: mechanics that
    -- only exist at it, plus mechanics it modifies, plus the boss-wide
    -- summary lines. Counted rather than stated, so it cannot drift
    -- from the data.
    local function ChangeCount(key)
        local n = #(G:ChangesFor(boss, key) or {})
        for _, phase in ipairs(boss.phases or {}) do
            for _, mech in ipairs(phase.mechanics or {}) do
                if mech.diff == key then n = n + 1
                elseif mech[key] then n = n + 1 end
            end
        end
        return n
    end

    for _, b in ipairs(diffButtons) do
        StyleToggle(b, b.diff == diff, DiffTone(b.diff))
        if b.diff ~= "normal" then
            local n = ChangeCount(b.diff)
            b.count = n
            b.text:SetText(n > 0
                and (b.label .. W:Tint("faint", " +" .. n))
                or b.label)
        end
    end

    ------------------------------------------------------------
    -- Bloodlust, and the button that follows it down the rail
    ------------------------------------------------------------
    local railY = lustBaseY
    if boss.lust then
        lustText:SetText((boss.lust:gsub("^%l", string.upper)))
        lustText:SetTextColor(W:Color("text"))
        lustLabel:Show()
        lustIcon:Show()
        lustText:Show()
        -- Measured, not assumed: "on pull" is one line and "the
        -- intermission, while Zul'jin takes double damage" is three.
        local textH = math.max(lustText:GetStringHeight() or 12, 12)
        railY = lustBaseY - 16 - math.max(textH, 20) - 12
    else
        lustLabel:Hide()
        lustIcon:Hide()
        lustText:Hide()
        railY = lustBaseY - 4
    end

    UI._lustTop, UI._lustText, UI._railY = lustBaseY - 16, lustText, railY
    ------------------------------------------------------------
    -- Body
    ------------------------------------------------------------
    ReleaseAll()
    ReleaseCards()
    ReleaseChips()
    ReleaseIcons()

    local content = scroll.content
    local width = math.max((scroll:GetWidth() or 460), 200)
    content:SetWidth(width)
    local inner = width - PAD * 2
    local y = 0

    --- Draw one mechanic and return the cursor under it.
    ---
    --- Everything is measured on the way down, because the row's height
    --- is the sum of wrapped strings and the icon has to be placed
    --- against the row's TOP once that top is known -- which it is,
    --- immediately, so the icon goes down first and the text after it.
    local function Mechanic(x, cursor, w, mech)
        local top = cursor
        local textX = x + MECH_TEXTX
        local textW = w - MECH_TEXTX

        -- The client's answer wins over ours, on both counts. `ejSpell`
        -- and `ejName` are filled by RaidGuideEJ:ResolveMechanics --
        -- see there for how confident it has to be before it renames
        -- anything.
        local spellID = mech.ejSpell or mech.spell
        local mechName = mech.ejName or mech.name or ""

        local icon = AcquireIcon(content)
        icon:SetPoint("TOPLEFT", content, "TOPLEFT", x, top + 1)
        icon.tex:SetTexture(SpellIcon(spellID))
        icon.spellID = spellID
        icon.spellName = mechName
        -- No spell id means the client has nothing to show, so the
        -- button should not pretend to be interactive.
        icon:EnableMouse(spellID and true or false)

        -- Name, with its kind after it and its difficulty badge before
        -- the kind. One string, so a long name wraps under itself
        -- rather than colliding with a right-anchored tag.
        local title = mechName
        if mech.diff then
            title = title .. "  " .. Badge(mech.diff == "mythic"
                and "MYTHIC ONLY" or "HEROIC+", DiffTone(mech.diff))
        end
        if mech.tag then
            title = title .. W:Tint("faint", "  \194\183  " .. mech.tag)
        end
        local fs = AcquireFS(content, FONT_NAME)
        fs:SetWidth(textW)
        fs:SetText(title)
        fs:SetTextColor(accent[1], accent[2], accent[3])
        fs:SetPoint("TOPLEFT", content, "TOPLEFT", textX, cursor)
        cursor = cursor - math.max(fs:GetStringHeight() or 12, 12) - MECH_TIGHT

        -- The imperative. Its own line, its own colour, directly under
        -- the name -- if a reader takes one line off a mechanic it
        -- should be this one.
        if mech.todo then
            cursor = Paragraph(content, textX, cursor, textW, mech.todo,
                FONT_BODY, "warn", MECH_LINE)
        end

        for _, line in ipairs(mech.lines or {}) do
            cursor = Paragraph(content, textX, cursor, textW, line,
                FONT_BODY, "muted", MECH_LINE)
        end

        -- What this difficulty changes about this mechanic, badged and
        -- sitting with the thing it changes.
        for _, note in ipairs(G:MechanicNotes(mech, diff)) do
            local tone = DiffTone(note.key)
            cursor = Paragraph(content, textX, cursor, textW,
                Badge(note.key == "mythic" and "MYTHIC" or "HEROIC", tone)
                .. "  " .. note.text,
                FONT_BODY, "text", MECH_LINE)
        end

        -- The icon is 26 tall and a one-line mechanic is shorter than
        -- that, so the row cannot end above its own icon.
        local used = top - cursor
        if used < MECH_ICON then cursor = top - MECH_ICON end
        return cursor - MECH_GAP
    end

    --- Lay a card and advance the cursor.
    ---
    --- A block is `{ head, lines, mechanics, colour, plain, gap }`: an
    --- optional sub-heading, and under it either plain lines or
    --- mechanic rows.
    ---
    --- Two passes: the body is drawn first to find out how tall it came
    --- out, then the card is sized around it. The alternative --
    --- guessing a height and hoping -- is the bug the layout checks in
    --- Tools/loadcheck.py exist to catch.
    local function Card(titleText, valueText, blocks)
        local drew = false
        for _, block in ipairs(blocks) do
            if (block.lines and #block.lines > 0)
                or (block.mechanics and #block.mechanics > 0) then
                drew = true
                break
            end
        end
        if not drew then return end

        local card = AcquireCard(content)
        local top = y
        local cursor = top - W:SectionTitleHeight() - BODY_TOP
        local startedAt = cursor

        for _, block in ipairs(blocks) do
            local hasLines = block.lines and #block.lines > 0
            local hasMechs = block.mechanics and #block.mechanics > 0
            if hasLines or hasMechs then
                if block.head then
                    -- Air above every sub-heading but the first: the
                    -- first already has the card's own top padding.
                    if cursor ~= startedAt then cursor = cursor - SUBHEAD_TOP end
                    cursor = SubHead(content, PAD + 10, cursor, inner - 20,
                        block.head, block.accent or accent)
                end
                for _, line in ipairs(block.lines or {}) do
                    if block.plain then
                        cursor = Paragraph(content, PAD + 10, cursor, inner - 20,
                            line, FONT_BODY, block.colour, block.gap)
                    else
                        cursor = Bullet(content, PAD + 10, cursor, inner - 20,
                            line, block.colour, block.gap)
                    end
                end
                for _, mech in ipairs(block.mechanics or {}) do
                    cursor = Mechanic(PAD + 10, cursor, inner - 20, mech)
                end
            end
        end

        local bodyH = (startedAt - cursor) + BODY_BOT
        card:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, top)
        card:SetText(titleText)
        card:SetValue(valueText)
        card:Layout(inner, bodyH)
        y = top - card:GetHeight() - CARD_GAP
    end

    ------------------------------------------------------------
    -- Pinned: what you need to know before the pull.
    --
    -- The raid-wide rules and your own job are one card, because a
    -- player reads them as one thought -- "what wipes us" and "what I
    -- do about it". They stay on screen while you page through the
    -- fight.
    --
    -- The difficulty summary sits between them. It is the one piece of
    -- heroic information that is genuinely PRE-pull rather than
    -- in-pull, and it is two or three lines, so it costs a sub-heading
    -- rather than the page it used to cost.
    ------------------------------------------------------------
    local pinned = {
        -- The fight in one sentence, where the header used to put it.
        -- Dim and plain, so it frames the three rules under it rather
        -- than competing with them.
        { lines = { boss.oneLiner }, plain = true, colour = "muted", gap = 8 },
        { lines = boss.rules, colour = "text" },
    }
    if boss.changesUnknown and diff ~= "normal" then
        -- Said out loud, because the alternative is silence and silence
        -- reads as "nothing changes" -- a claim no source has made about
        -- this fight. Printed once rather than per difficulty: it is a
        -- fact about the source, not about Heroic.
        pinned[#pinned + 1] = {
            head = "What " .. (diff == "mythic" and "Mythic" or "Heroic")
                .. " changes",
            accent = DiffTone(diff),
            lines = {
                "Not recorded. The only guide that covers this fight never "
                    .. "separated the difficulties, so read this as unknown "
                    .. "rather than as nothing.",
            },
            plain = true,
            colour = "faint",
        }
    else
        for _, key in ipairs({ "heroic", "mythic" }) do
            if G:Rank(diff) >= G:Rank(key) then
                local lines = G:ChangesFor(boss, key)
                if lines then
                    pinned[#pinned + 1] = {
                        head = "What " .. (key == "mythic" and "Mythic" or "Heroic")
                            .. " changes",
                        accent = DiffTone(key),
                        lines = lines,
                        colour = "text",
                    }
                end
            end
        end
    end
    pinned[#pinned + 1] = {
        head = "You, as " .. ROLE_LABEL[role],
        lines = G:RoleLines(boss, role),
        colour = "text",
    }
    Card("Before you pull", boss.bring, pinned)

    ------------------------------------------------------------
    -- The pages: one per phase.
    --
    -- No Heroic page any more. It was a summary of differences read
    -- after the fight it describes, and every line of it now lives on
    -- the mechanic it changes -- except the two or three boss-wide
    -- ones, which moved UP into the pinned card where they are read
    -- before the pull instead of after it.
    ------------------------------------------------------------
    local pages = {}
    for _, phase in ipairs(boss.phases or {}) do
        local shown = {}
        for _, mech in ipairs(phase.mechanics or {}) do
            if G:MechanicShows(mech, diff) then shown[#shown + 1] = mech end
        end
        pages[#pages + 1] = {
            name = Flagged(phase.name, phase.unsure),
            tag = phase.tag,
            mechanics = shown,
            unsure = phase.unsure,
        }
    end

    self._pageCount = math.max(#pages, 1)
    if page > #pages then page = math.max(#pages, 1) end

    if #pages > 0 then
        ------------------------------------------------------------
        -- The strip: Prev, a chip per page, Next.
        ------------------------------------------------------------
        local stripY = y - 2
        local cx = PAD

        local function Step(label, target, enabled)
            local b = AcquireChip(content)
            b:SetSize(STEP_W, CHIP_H)
            b:SetPoint("TOPLEFT", content, "TOPLEFT", cx, stripY)
            b.text:SetText(label)
            b.tip = nil
            W:Apply(b, "row")
            b.text:SetTextColor(W:Color(enabled and "muted" or "faint"))
            b:SetEnabled(enabled and true or false)
            b:SetScript("OnClick", function() UI:SetPage(target) end)
            cx = cx + STEP_W + CHIP_GAP
        end

        Step("Prev", page - 1, page > 1)

        for i, p in ipairs(pages) do
            local b = AcquireChip(content)
            b:SetSize(CHIP_W, CHIP_H)
            b:SetPoint("TOPLEFT", content, "TOPLEFT", cx, stripY)
            b.text:SetText(tostring(i))
            b.tip = p.name
            b:SetEnabled(true)
            local on = (i == page)
            W:Apply(b, on and "inset" or "row")
            if on then
                b.text:SetTextColor(accent[1], accent[2], accent[3])
            else
                b.text:SetTextColor(W:Color("muted"))
            end
            b:SetScript("OnClick", function() UI:SetPage(i) end)
            cx = cx + CHIP_W + CHIP_GAP
        end

        Step("Next", page + 1, page < #pages)

        y = stripY - CHIP_H - 8

        ------------------------------------------------------------
        -- The page itself, with room to read.
        ------------------------------------------------------------
        local p = pages[page]
        if p.unsure then flagged = true end
        local blocks = {}
        if p.tag then
            blocks[#blocks + 1] = {
                lines = { W:Tint("faint", p.tag) },
                plain = true,
                gap = 7,
            }
        end
        if #p.mechanics > 0 then
            blocks[#blocks + 1] = { mechanics = p.mechanics }
        else
            -- Reachable: a phase whose every mechanic is gated above
            -- the selected difficulty. Saying so is better than an
            -- empty card, which reads as a rendering fault.
            blocks[#blocks + 1] = {
                lines = { "Nothing in this phase changes at this difficulty." },
                plain = true,
                colour = "faint",
            }
        end
        Card(p.name, ("%d of %d"):format(page, #pages), blocks)
    end

    ------------------------------------------------------------
    -- Footnotes: the things that qualify the page rather than the phase.
    ------------------------------------------------------------

    -- What the client lists and this guide does not.
    --
    -- The guide is written from other people's guides, so the mechanic
    -- it is most likely to miss is the one THEY skipped. The Encounter
    -- Journal has the real list, so the page can say out loud that
    -- there is more -- rather than presenting its mechanics as if they
    -- were all of them.
    --
    -- pcall because this is the only thing on the page that reads the
    -- journal during a draw, and a client that answers oddly must cost
    -- us a footnote rather than the render.
    if G.UnmentionedAbilities then
        local ok, extra = pcall(G.UnmentionedAbilities, G, boss)
        if ok and type(extra) == "table" and #extra > 0 then
            local shown, cap = {}, 12
            for i = 1, math.min(#extra, cap) do shown[i] = extra[i] end
            local text = table.concat(shown, ",  ")
            if #extra > cap then
                text = text .. (",  and %d more"):format(#extra - cap)
            end
            y = Paragraph(content, PAD, y - 2, inner,
                W:Tint("muted", "Also in the Encounter Journal:") .. "  " .. text,
                FONT_LABEL, "faint")
        end
    end

    -- The footnote for every `?` on the page, drawn once and only when
    -- there is one.
    if flagged then
        y = Paragraph(content, PAD, y - 2, inner,
            UNSURE .. "  --  a name no source could confirm. The mechanics are "
            .. "not in doubt; the spelling is.",
            FONT_LABEL, "faint")
    end

    UI._cardIdx = cardIdx
    scroll:SetContentHeight(-y + 8)
end

------------------------------------------------------------
-- Sub-tab plumbing for the shell
--
-- Raid Tools was an adapted page with no sub-tabs at all, so both of
-- these are new. The names are deliberately not ns.SetRaidTab, which
-- already exists and switches the standalone raid window's internal
-- view -- quietly overloading it would have made the two switch each
-- other.
------------------------------------------------------------
--- Boss Guide first, and first means default: Shell:InitialSubTab
--- falls back to tabs[1].id when there is no remembered tab, so the
--- order of this list decides both where the tabs sit and which one
--- opens.
---
--- The guide is the half of this page that works alone. The overview
--- needs a group before it has anything to say, so leading with it
--- meant most visits opened on an empty state.
function ns:GetRaidPageTabs()
    return {
        { id = "guide",    label = "Boss Guide", width = 110 },
        { id = "overview", label = "Overview", width = 100 },
    }
end
