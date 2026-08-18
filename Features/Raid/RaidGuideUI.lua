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
-- Difficulty works the same way. Heroic mechanics are genuinely extra
-- things on top rather than different fights, so Normal shows the fight
-- and Heroic adds one more page at the end of it.
--
------------------------------------------------------------
-- ONE PHASE AT A TIME.
--
-- This page used to print the whole fight in one column: every phase,
-- every line, one after another. That is a correct document and a bad
-- pre-pull read -- it looked like an essay, and the reader's job became
-- finding their place in it rather than learning a phase.
--
-- So the fight is paged. The rules and your own job stay pinned at the
-- top, because those are the three things you read while the timer runs;
-- under them is one phase, given room to breathe, with a numbered strip
-- to step or jump through the rest. Same words, a third of the height,
-- and the reader is never scrolling to find where phase three started.
--
-- The controls moved to the left rail for the same reason. Seven bosses
-- in a 196px column leaves half that column empty, and the role and
-- difficulty toggles were spending a full row of the reading column on
-- something the eye only needs when it is choosing -- not when it is
-- reading.
------------------------------------------------------------

ns.RaidGuideUI = ns.RaidGuideUI or {}
local UI = ns.RaidGuideUI

local LIST_W  = 196
local GUTTER  = 14
local ROW_H   = 30
-- From the shell, not chosen here. At 12 this view sat four pixels
-- further left than every other page, which is exactly the drift the
-- shared constant exists to stop -- and visible as the content shifting
-- when you change page.
local PAD     = (ns.Shell and ns.Shell.PAD) or 12

-- Vertical budget.
--
-- The page was built out of one SectionCard per block, and a card costs
-- its heading, its ornament, its inner padding and the gap to the next
-- one -- about fifty pixels before a word is drawn. Eleven of them on
-- The Lost Explorers spent more height on chrome than on the guide.
--
-- A card now marks a KIND of thing -- what to know, and the phase you
-- are on -- and everything else is a sub-heading, which costs a line.
local CARD_GAP    = 10   -- between cards
local BODY_TOP    = 6    -- inside a card, above its first line
local BODY_BOT    = 12   -- and under its last
local SUBHEAD_TOP = 7    -- air above a sub-heading, when it is not the first
local SUBHEAD_BOT = 3
local LINE_GAP    = 2

-- The phase page is the one place that is deliberately NOT dense. It
-- holds one phase, it has the room, and six bullets set two pixels apart
-- is the wall of text this rewrite exists to stop being.
local LINE_GAP_WIDE = 7

-- The pager strip.
local CHIP_W, CHIP_H, CHIP_GAP = 24, 20, 3
local STEP_W = 46

local W = ns.Widgets

local ROLE_LABEL = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }
local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }

-- The mark on a name the source guide was not sure about.
--
-- This was the words "(name unconfirmed)" appended to the boss header
-- AND to every phase title carrying the flag -- four of them on The Lost
-- Explorers, one of which ran off the right edge because the titles do
-- not wrap. The honesty is worth keeping and the repetition is not, so
-- it is a glyph on the name and one footnote at the foot of the page.
local UNSURE = "?"
local function Flagged(text, isUnsure)
    if not isUnsure then return text end
    return text .. W:Tint("faint", "\194\160" .. UNSURE)
end

------------------------------------------------------------
-- Saved state
------------------------------------------------------------
local function Store()
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.raidGuide = YippYappHelperDB.raidGuide or {}
    return YippYappHelperDB.raidGuide
end

--- The role to open on.
---
--- Group assignment first, because if you are in a raid that is the
--- role you are about to play whatever your spec says. Spec second, for
--- reading the guide alone at the bank. The saved choice wins over both
--- -- somebody deliberately reading the tank column should not have it
--- taken off them by joining a group as DPS.
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
-- remembered page is a stale reading position, and opening a boss on
-- phase four because that is where you stopped last week is not what
-- anybody meant. It resets to 1 whenever the boss or difficulty changes.
------------------------------------------------------------
local page, pageBoss, pageHeroic = 1, nil, nil

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
        fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
        fsPool[fsIdx] = fs
    else
        fs:SetFontObject(font or "GameFontNormalSmall")
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
--- PREVIOUS text and the error is a few pixels, so it survives review.
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
    local dot = AcquireFS(parent, "GameFontNormalSmall")
    dot:SetWidth(10)
    dot:SetText(W:Tint("faint", "-"))
    dot:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return Paragraph(parent, x + 12, y, width - 12, text,
        "GameFontNormalSmall", colourKey, gap)
end

--- A sub-heading inside a card: the block addressed to your role, or the
--- name of the phase you are reading.
---
--- It wraps, because a heading that cannot wrap is a heading that runs
--- off the right edge -- which is exactly what "(name unconfirmed)"
--- appended to a phase title used to do.
local function SubHead(parent, x, y, width, text, accent, font)
    local fs = AcquireFS(parent, font or "GameFontNormalSmall")
    fs:SetWidth(width)
    fs:SetText(text or "")
    if accent then fs:SetTextColor(accent[1], accent[2], accent[3]) end
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return y - math.max(fs:GetStringHeight() or 12, 12) - SUBHEAD_BOT
end

------------------------------------------------------------
-- Cards
--
-- Pooled, because the page redraws whenever the boss, role, difficulty
-- or page changes and that is often.
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
-- Cards sized around measured text is precisely the arrangement that
-- goes wrong quietly.
UI._cards = cardPool

------------------------------------------------------------
-- The pager strip
--
-- Pooled buttons: the number of pages is the number of phases, which
-- changes with the boss and with the difficulty.
------------------------------------------------------------
local chipPool, chipIdx = {}, 0

local function AcquireChip(parent)
    chipIdx = chipIdx + 1
    local b = chipPool[chipIdx]
    if not b then
        b = CreateFrame("Button", nil, parent, "BackdropTemplate")
        b:SetSize(CHIP_W, CHIP_H)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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
local diffButtons, trainButton
local headerName, headerLine
local lustLabel, lustIcon, lustText, lustBaseY

--- A small muted caption over a group of controls in the rail.
local function RailLabel(parent, text, y)
    local fs = W:Label(parent, "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", 2, y)
    fs:SetTextColor(W:Color("faint"))
    fs:SetText(text)
    return fs
end

------------------------------------------------------------
-- Bloodlust
--
-- Always "Bloodlust", on both factions, with the Bloodlust icon.
--
-- This used to follow the player's faction and show Alliance players
-- "Heroism", on the reasoning that a Horde player who saw a blue hand
-- would have to translate. That reasoning was wrong about how people
-- talk: raids of both factions call the effect Bloodlust or just "lust",
-- including the Alliance ones, and every guide and every callout in the
-- data says Bloodlust. Renaming it per faction made this one row
-- disagree with the entire rest of the page.
--
-- Spell IDs in preference order, and the texture comes from whichever
-- one the client answers for. The path fallback is a classic icon name
-- rather than a file ID, because a file ID guessed from outside the
-- client is a number that is wrong silently.
------------------------------------------------------------
local LUST_HORDE    = 2825      -- Bloodlust
local LUST_ALLIANCE = 32182     -- Heroism
local LUST_OTHERS   = { 80353, 264667, 390386 }  -- Time Warp, Primal Rage, Fury of the Aspects
local LUST_FALLBACK = "Interface\\Icons\\Spell_Nature_BloodLust"

--- The effect's name, and an icon to match. The same on both factions.
local function LustLook()
    local label = "Bloodlust"

    -- Bloodlust's own icon first, so the word and the picture agree.
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
        -- Rebuilt into a new parent when the shell remounts the page.
        host:SetParent(parent)
        host:ClearAllPoints()
        host:SetAllPoints(parent)
        return
    end

    host = CreateFrame("Frame", nil, parent)
    host:SetAllPoints(parent)

    ------------------------------------------------------------
    -- Boss list
    ------------------------------------------------------------
    listFrame = CreateFrame("Frame", nil, host)
    listFrame:SetPoint("TOPLEFT", 0, 0)
    listFrame:SetPoint("BOTTOMLEFT", 0, 0)
    listFrame:SetWidth(LIST_W)

    local listTitle = W:Label(listFrame, "GameFontNormalSmall")
    listTitle:SetPoint("TOPLEFT", 2, -2)
    listTitle:SetTextColor(W:Color("muted"))
    listTitle:SetText((ns.RaidGuide and ns.RaidGuide.instance.name) or "Raid")

    local G = ns.RaidGuide
    local bosses = G and G:Ordered() or {}

    -- Grouped by instance, with a heading whenever it changes.
    --
    -- The rail lists more than one place now -- the raid, and the Lair
    -- that is the only other source of raid gear this patch. Without a
    -- heading the Grotto's single boss simply appeared as another "1"
    -- under the last of the eight, which reads as a numbering bug rather
    -- than as a second instance.
    --
    -- The first group's heading is the title above the list, which is
    -- already there and already says the right thing.
    -- The boss the source guide never covered, said out loud in the list
    -- rather than left as a gap the player has to notice.
    --
    -- It belongs to the RAID, so it is emitted at the end of the raid's
    -- rows rather than at the end of the rail -- otherwise adding the
    -- Grotto quietly moved Ula'tek underneath a heading he has nothing
    -- to do with.
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

        local num = W:Label(row, "GameFontNormalSmall", "CENTER")
        num:SetPoint("LEFT", 7, 0)
        num:SetWidth(14)
        num:SetText(tostring(vaCount + 1))
        num:SetTextColor(W:Color("faint"))

        local name = W:Label(row, "GameFontNormalSmall")
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
            local head = W:Label(listFrame, "GameFontNormalSmall")
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

        b.num = W:Label(b, "GameFontNormalSmall", "CENTER")
        b.num:SetPoint("LEFT", 7, 0)
        b.num:SetWidth(14)
        b.num:SetText(tostring(boss.order))
        b.num:SetTextColor(W:Color("faint"))

        b.name = W:Label(b, "GameFontNormalSmall")
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

    -- And if the raid was the LAST group in the rail, its gap row still
    -- has to be emitted. A Frame rather than a Button because there is
    -- nothing to open, and a row that highlights and then does nothing
    -- is worse than one that plainly cannot be clicked.
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
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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

    -- Both difficulties on screen, rather than one button showing the
    -- current one -- which reads either as "you are here" or as "click
    -- for this" depending on who is looking.
    diffButtons = {}
    x = 0
    for _, def in ipairs({
        { heroic = false, label = "Normal" },
        { heroic = true,  label = "Heroic" },
    }) do
        local b = CreateFrame("Button", nil, listFrame, "BackdropTemplate")
        b:SetSize(94, 20)
        b:SetPoint("TOPLEFT", x, y)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.text:SetAllPoints()
        b.text:SetText(def.label)
        ns.AddGlowHighlight(b, 0.08)
        b.heroic = def.heroic
        b.label = def.label
        b:SetScript("OnClick", function()
            Store().heroic = def.heroic
            UI:Refresh()
        end)
        -- The count on the button replaced a whole card.
        --
        -- Reading the fight on Normal used to end with a card whose only
        -- line was "4 extra things happen on Heroic, switch the button
        -- above" -- fifty pixels of chrome to point at a control that is
        -- already on screen. The button can say it itself.
        if def.heroic then
            b:SetScript("OnEnter", function(self)
                if not self.count or self.count == 0 then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Heroic")
                GameTooltip:AddLine(("%d extra mechanics on this fight. "
                    .. "Everything on Normal still happens."):format(self.count),
                    0.7, 0.7, 0.7, true)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        diffButtons[#diffButtons + 1] = b
        x = x + 96
    end
    y = y - 30

    ------------------------------------------------------------
    -- Bloodlust, under the difficulty
    --
    -- It was one line inside the pinned card, competing with the three
    -- rules for the same eye. It is not a rule -- it is a plan, decided
    -- before the pull and then not thought about again -- so it belongs
    -- with the other things you set before you read: your role and your
    -- difficulty.
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
    -- The same trim the battle-res timer uses: icon art carries a border
    -- in its outer few percent, and left untrimmed it reads as a smudge
    -- at this size.
    lustIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    lustText = W:Label(listFrame, "GameFontNormalSmall")
    lustText:SetPoint("TOPLEFT", 28, y - 16)
    lustText:SetWidth(LIST_W - 32)
    lustText:SetJustifyV("TOP")

    trainButton = CreateFrame("Button", nil, listFrame, "BackdropTemplate")
    trainButton:SetSize(LIST_W - 4, 22)
    trainButton:SetPoint("TOPLEFT", 0, y)
    trainButton.text = trainButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    trainButton.text:SetAllPoints()
    trainButton.text:SetText("|cff44ff88Test my knowledge|r")
    ns.AddGlowHighlight(trainButton, 0.12)
    trainButton:SetScript("OnClick", function()
        local id = Store().boss
        if ns.RaidTrainer and id then
            ns.RaidTrainer:Start(id, Store().heroic)
        end
    end)
    trainButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Practise this fight")
        GameTooltip:AddLine("A small arena. WASD or the arrow keys to move, "
            .. "aim with the mouse, hold left-click to shoot.", 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine("Dodge what is red. Stand in what is green.",
            0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    trainButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ------------------------------------------------------------
    -- Detail column
    ------------------------------------------------------------
    detail = CreateFrame("Frame", nil, host)
    detail:SetPoint("TOPLEFT", listFrame, "TOPRIGHT", GUTTER, 0)
    detail:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)

    headerName = W:Label(detail, "GameFontNormalLarge")
    headerName:SetPoint("TOPLEFT", 0, -2)
    headerName:SetPoint("RIGHT", detail, "RIGHT", -4, 0)
    headerName:SetWordWrap(false)

    headerLine = W:Label(detail, "GameFontNormalSmall")
    headerLine:SetPoint("TOPLEFT", headerName, "BOTTOMLEFT", 0, -3)
    headerLine:SetPoint("RIGHT", detail, "RIGHT", -4, 0)
    headerLine:SetTextColor(W:Color("muted"))
    headerLine:SetWordWrap(false)

    scroll = W:ScrollList(detail)
    scroll:SetPoint("TOPLEFT", 0, -44)
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

function UI:Refresh()
    if not host then return end
    local G = ns.RaidGuide
    if not G then return end

    -- The Encounter Journal gets a chance to correct the names the
    -- transcript was unsure about, the first time the page is looked at.
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

    local role = DefaultRole()
    local heroic = store.heroic and true or false
    local accent = boss.accent or { 0.45, 0.85, 1.0 }

    -- A different boss or difficulty is a different fight; the page you
    -- were on does not carry over to it.
    if pageBoss ~= boss.id or pageHeroic ~= heroic then
        page, pageBoss, pageHeroic = 1, boss.id, heroic
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
        b.name:SetText(rowBoss and rowBoss.name or "")
    end

    ------------------------------------------------------------
    -- Header and controls
    ------------------------------------------------------------
    -- Said out loud rather than left as a silent risk -- a player who
    -- calls a boss by the wrong name in chat because our page told them
    -- to is a worse outcome than a mark on the name. But once, as a
    -- mark, with the sentence at the foot of the page.
    local flagged = boss.unsure and true or false
    headerName:SetText(Flagged(boss.name, boss.unsure))
    headerName:SetTextColor(accent[1], accent[2], accent[3])
    headerLine:SetText(boss.oneLiner)

    for _, b in ipairs(roleButtons) do
        StyleToggle(b, b.role == role, accent)
    end
    local heroicCount = boss.heroic and #boss.heroic or 0
    for _, b in ipairs(diffButtons) do
        StyleToggle(b, b.heroic == heroic,
            b.heroic and { 1.0, 0.42, 0.35 } or { 0.45, 0.85, 1.0 })
        if b.heroic then
            b.count = heroicCount
            b.text:SetText(heroicCount > 0
                and (b.label .. W:Tint("faint", "  +" .. heroicCount))
                or b.label)
        end
    end
    ------------------------------------------------------------
    -- Bloodlust, and the button that follows it down the rail
    ------------------------------------------------------------
    local railY = lustBaseY
    if boss.lust then
        -- Capitalised here rather than in the data. The fragment reads as
        -- a continuation of the label ("Bloodlust -- on pull") in prose
        -- and as a sentence of its own in the rail, and the rail is now
        -- the only place it is printed.
        lustText:SetText((boss.lust:gsub("^%l", string.upper)))
        lustText:SetTextColor(W:Color("text"))
        lustLabel:Show()
        lustIcon:Show()
        lustText:Show()
        -- Measured, not assumed: "on pull" is one line and "the
        -- intermission, while Zul'jin takes double damage" is three, and
        -- a fixed offset here would either overlap the button or leave a
        -- hole above it.
        local textH = math.max(lustText:GetStringHeight() or 12, 12)
        railY = lustBaseY - 16 - math.max(textH, 20) - 12
    else
        lustLabel:Hide()
        lustIcon:Hide()
        lustText:Hide()
        railY = lustBaseY - 4
    end

    trainButton:ClearAllPoints()
    trainButton:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, railY)
    -- For Tools\loadcheck.py: the rail's one reflowed anchor.
    UI._lustTop, UI._lustText, UI._railY = lustBaseY - 16, lustText, railY
    -- PAUSED, not removed.
    --
    -- The arena is built and every fight in it runs, but getting a
    -- mechanic subtly wrong there is worse than not offering it: a guide
    -- that is vague sends you to look something up, while a trainer that
    -- is confidently wrong teaches you the wrong reflex and you find out
    -- in the raid. Several of them were wrong in exactly that way -- the
    -- Frostfire explosion fired on the wrong half of the mechanic, the
    -- Sentinels' raid ignored its own split -- and each was only caught
    -- by somebody watching the real fight.
    --
    -- So the button is hidden while the written guides carry the load.
    -- Flip this to bring it back; the scenarios, the checks and the
    -- arena are all still here and still green.
    local TRAINER_READY = false
    trainButton:SetShown(TRAINER_READY
        and ns.RaidTrainer and ns.RaidTrainer:HasScenario(boss.id) or false)

    ------------------------------------------------------------
    -- Body
    ------------------------------------------------------------
    ReleaseAll()
    ReleaseCards()
    ReleaseChips()

    local content = scroll.content
    local width = math.max((scroll:GetWidth() or 460), 200)
    content:SetWidth(width)
    local inner = width - PAD * 2
    local y = 0

    --- Lay a card whose body is a list of BLOCKS, and advance the cursor.
    ---
    --- A block is `{ head, lines, colour, plain, gap }`: an optional
    --- sub-heading and the lines under it.
    ---
    --- Two passes: the lines are drawn first to find out how tall they
    --- came out, then the card is sized around them. The alternative --
    --- guessing a height and hoping -- is the bug the layout checks in
    --- Tools/loadcheck.py exist to catch, so it is not worth writing
    --- once even carefully.
    local function Card(titleText, valueText, blocks)
        local drew = false
        for _, block in ipairs(blocks) do
            if block.lines and #block.lines > 0 then drew = true; break end
        end
        if not drew then return end

        local card = AcquireCard(content)
        local top = y
        local cursor = top - W:SectionTitleHeight() - BODY_TOP
        local startedAt = cursor

        for _, block in ipairs(blocks) do
            if block.lines and #block.lines > 0 then
                if block.head then
                    -- Air above every sub-heading but the first: the
                    -- first one already has the card's own top padding.
                    if cursor ~= startedAt then cursor = cursor - SUBHEAD_TOP end
                    cursor = SubHead(content, PAD + 10, cursor, inner - 20,
                        block.head, block.accent or accent)
                end
                for _, line in ipairs(block.lines) do
                    if block.plain then
                        cursor = Paragraph(content, PAD + 10, cursor, inner - 20,
                            line, "GameFontNormalSmall", block.colour, block.gap)
                    else
                        cursor = Bullet(content, PAD + 10, cursor, inner - 20,
                            line, block.colour, block.gap)
                    end
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
    -- The raid-wide rules and your own job were two cards, which put a
    -- heading and an ornament between two lists a player reads as one
    -- thought -- "what wipes us" and "what I do about it". They stay on
    -- screen while you page through the fight, because they are the
    -- lines you are actually reading when the timer is running.
    ------------------------------------------------------------
    -- Bloodlust used to be the last line in here. It moved to the rail:
    -- it is a plan rather than a rule, and it was competing with the
    -- three lines that actually stop a wipe.
    Card("Before you pull", boss.bring, {
        { lines = boss.rules, colour = "text" },
        {
            head = "You, as " .. ROLE_LABEL[role],
            lines = G:RoleLines(boss, role),
            colour = "text",
        },
    })

    ------------------------------------------------------------
    -- The pages: one per phase, plus Heroic at the end of it.
    ------------------------------------------------------------
    local pages = {}
    for _, phase in ipairs(boss.phases or {}) do
        pages[#pages + 1] = {
            name = Flagged(phase.name, phase.unsure),
            tag = phase.tag,
            lines = phase.lines,
            unsure = phase.unsure,
            colour = "text",
        }
    end
    if heroic and heroicCount > 0 then
        pages[#pages + 1] = {
            name = "What Heroic adds",
            tag = "on top of everything else",
            lines = boss.heroic,
            colour = "text",
            heroic = true,
        }
    elseif heroic and boss.heroicUnknown then
        -- An empty Heroic page would be a claim -- "nothing extra" --
        -- that no source has made. Several of these fights are written
        -- from guides covering Normal and Heroic in one pass, which
        -- never separated them, and the honest answer is that we do not
        -- know rather than that there is nothing.
        pages[#pages + 1] = {
            name = "What Heroic adds",
            lines = {
                "Not recorded for this fight. The guide these notes come from "
                    .. "covers Normal and Heroic together and never separated "
                    .. "them, so read this as unknown rather than as nothing.",
            },
            colour = "faint",
            plain = true,
            heroic = true,
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
            -- The Heroic page is lettered, not numbered: it is not the
            -- ninth phase of the fight, it is a different kind of page.
            b.text:SetText(p.heroic and "H" or tostring(i))
            b.tip = p.name
            b:SetEnabled(true)
            local on = (i == page)
            W:Apply(b, on and "inset" or "row")
            local tone = p.heroic and { 1.0, 0.42, 0.35 } or accent
            if on then
                b.text:SetTextColor(tone[1], tone[2], tone[3])
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
                gap = 6,
            }
        end
        blocks[#blocks + 1] = {
            lines = p.lines,
            colour = p.colour,
            plain = p.plain,
            gap = LINE_GAP_WIDE,
        }
        Card(p.name, ("%d of %d"):format(page, #pages), blocks)
    end

    ------------------------------------------------------------
    -- Footnotes: the things that qualify the page rather than the phase.
    ------------------------------------------------------------

    -- What the client lists and this guide does not.
    --
    -- The guide is written from video guides, so the mechanic it is most
    -- likely to miss is the one the video never showed. The Encounter
    -- Journal has the real list, so the page can say out loud that there
    -- is more -- rather than presenting its phases as if they were all
    -- of them.
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
                "GameFontNormalSmall", "faint")
        end
    end

    -- The footnote for every `?` on the page, drawn once and only when
    -- there is one.
    if flagged then
        y = Paragraph(content, PAD, y - 2, inner,
            UNSURE .. "  --  a name taken from the video rather than from the "
            .. "client. The mechanics are not in doubt; the spelling is.",
            "GameFontNormalSmall", "faint")
    end

    UI._cardIdx = cardIdx
    scroll:SetContentHeight(-y + 8)
end

------------------------------------------------------------
-- Sub-tab plumbing for the shell
--
-- Raid Tools was an adapted page with no sub-tabs at all, so both of
-- these are new. The names are deliberately not ns.SetRaidTab, which
-- already exists and means something else -- it switches the standalone
-- raid window's internal view, and quietly overloading it would have
-- made the two switch each other.
------------------------------------------------------------
function ns:GetRaidPageTabs()
    return {
        { id = "overview", label = "Overview", width = 100 },
        { id = "guide",    label = "Boss Guide", width = 110 },
    }
end
