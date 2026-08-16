local _, ns = ...

------------------------------------------------------------
-- The outer shell window.
--
-- Two regions that never move, plus tabs below: the character down the
-- left, the page filling the rest, navigation along the bottom edge.
-- Changing page swaps the middle and nothing else.
--
-- Deliberately NOT three columns. Nav-content-rail is Vaultloom's
-- arrangement, and while the addon kept it no amount of restyling
-- stopped it reading as a copy. The left column carries the CHARACTER
-- instead -- which is what the addon is about -- and navigation went to
-- Blizzard's own bottom tabs, which hang outside the frame and so cost
-- the layout no width at all.
--
-- Sized from Core/Shell.lua rather than from a constant here: the Best
-- in Slot doll cannot go below 300 and needs its list beside it, so the
-- content region guarantees 700 and the window is that plus the
-- character column.
--
-- Deliberately additive. AppFrame still exists and still works; this is
-- a second front door onto the same pages, so the nine of them can move
-- across one at a time instead of in one jump that has to be right
-- first time.
------------------------------------------------------------

local Shell = ns.Shell
if not Shell then return end

local W = Shell:PreferredWidth()
local H = 760
local PAD, GAP = Shell.PAD, Shell.GAP

-- Space between bottom tabs. Blizzard butts theirs together; ours are
-- separated so nine of them read as nine choices.
local TAB_GAP = 6
-- Height of the tab strip, and the margin it keeps from the window's
-- left and right edges.
local TAB_H = 32
local TAB_EDGE = 12

local frame

local function Panel(parent, role)
    local skin = ns.Skin and ns.Skin:Active()
    if skin and skin.Panel then return skin:Panel(parent, role) end
    return CreateFrame("Frame", nil, parent)
end

------------------------------------------------------------
-- Build
------------------------------------------------------------
local function Build()
    if frame then return frame end

    -- Restored here rather than at load: saved variables do not exist
    -- until after the addon's files run, so asking earlier gets nil and
    -- the saved choice is silently ignored -- which it was.
    if ns.Skin and ns.Skin.Restore then ns.Skin:Restore() end

    frame = CreateFrame("Frame", "YippYappShell", UIParent, "BackdropTemplate")
    frame:SetSize(W, H)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    if ns.SmoothFrame then ns.SmoothFrame(frame) end

    -- The window itself is the one piece of chrome the shell draws, and
    -- it asks the skin for it like everything else does.
    local bg = Panel(frame, "window")
    bg:SetAllPoints(frame)
    frame.bg = bg

    tinsert(UISpecialFrames, "YippYappShell")

    ------------------------------------------------------------
    -- Title bar and medallion
    --
    -- The band spans the window and the title is centred in it, which is
    -- what every Blizzard frame does and what the addon was not doing:
    -- a label floating at the top left with a close button opposite reads
    -- as a debug panel rather than a window.
    ------------------------------------------------------------
    local skin = ns.Skin and ns.Skin:Active()
    local chromeInset = (skin and skin.chromeInset) or { top = 0, side = 0 }

    local title = CreateFrame("Frame", nil, frame)
    title:SetPoint("TOPLEFT", chromeInset.side or 0, -(chromeInset.top or 0))
    title:SetPoint("TOPRIGHT", -(chromeInset.side or 0), -(chromeInset.top or 0))
    title:SetHeight(Shell.TITLE_H)
    frame.titleBar = title

    -- Only when the skin does not already paint one. The Blizzlike
    -- window's nine-slice includes its own title bar art, and laying a
    -- filled header over it just muddies the metal.
    if not (skin and skin.chromeInset) then
        local band = Panel(frame, "header")
        band:SetAllPoints(title)
        frame.titleBand = band
    end

    -- One colour, one name. Two-tone branding in a window title reads as
    -- a logo squeezed into a text field, and the page name beside it was
    -- redundant the moment the tabs along the bottom started saying which
    -- page you are on.
    local name = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    -- Centred on the WINDOW, not on the title bar.
    --
    -- They are the same span today, but the title bar is inset by the
    -- skin's chromeInset and the medallion overhangs the left corner, so
    -- centring on the bar makes the title drift the moment either
    -- changes. The window is the thing a title should look centred in.
    -- One anchor. TOP centres horizontally on the window and fixes the
    -- vertical in the same call; adding CENTER as well would constrain
    -- the vertical twice. Anchored to the window rather than the title
    -- bar because the bar is inset by the skin and the medallion
    -- overhangs its left corner, so a title centred on the bar drifts
    -- the moment either changes.
    name:SetPoint("TOP", frame, "TOP", 0, -7)
    name:SetText("YippYapp Helper")
    if ns.ApplyTextShadow then ns.ApplyTextShadow(name) end
    frame.titleText = name


    -- On the corner, not inside it. Anchored to the frame with a small
    -- positive offset the way Blizzard's own panels do, so it overlaps
    -- the metal edge instead of floating in the window's body -- which
    -- is where the old chromeInset arithmetic had pushed it.
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(28, 28)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() ns.Shell:Close() end)
    frame.closeButton = close

    -- The medallion lives on its own frame above the background, not as
    -- a texture on the window.
    --
    -- Blizzard can put theirs straight on the frame because their
    -- background is a Texture in a Layer. Ours is a child Frame, since
    -- the skin hands back frames rather than textures -- and a child
    -- frame draws above every texture its parent owns, whatever layer
    -- they are on. So the portrait was rendering behind the window
    -- background: an empty gold ring with the picture underneath it.
    local host = CreateFrame("Frame", nil, frame)
    host:SetPoint("TOPLEFT")
    host:SetSize(1, 1)
    host:SetFrameLevel((bg:GetFrameLevel() or 1) + 5)

    local medallion = host:CreateTexture(nil, "ARTWORK")
    medallion:SetSize(Shell.MEDALLION_SIZE, Shell.MEDALLION_SIZE)
    medallion:SetPoint("TOPLEFT", frame, "TOPLEFT",
        Shell.MEDALLION_X, Shell.MEDALLION_Y)
    if host.CreateMaskTexture then
        local mask = host:CreateMaskTexture()
        mask:SetTexture(Shell.MEDALLION_MASK,
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetPoint("TOPLEFT", medallion, 2, 0)
        mask:SetPoint("BOTTOMRIGHT", medallion, -2, 4)
        medallion:AddMaskTexture(mask)
    end
    frame.medallion = medallion
    frame.medallionHost = host

    ------------------------------------------------------------
    -- Regions
    ------------------------------------------------------------
    local top = -((chromeInset.top or 0) + Shell.TITLE_H + GAP)

    -- The character column. Everything that is true of you rather than
    -- of the page you happen to be looking at.
    -- The "inset" surface, not "panel". This is the one that used to sit
    -- behind the hero card: a dark plate with a gold edge. It was the
    -- right surface, just applied to a 112px card instead of the whole
    -- column, so it read as a box around the sign rather than as the
    -- background for everything under it.
    local char = Panel(frame, "inset")
    char:SetPoint("TOPLEFT", PAD, top)
    char:SetPoint("BOTTOMLEFT", PAD, PAD)
    char:SetWidth(Shell.CHAR_W)
    frame.char = char
    frame.nav = char   -- migration alias

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", char, "TOPRIGHT", GAP, 0)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD)
    frame.content = content

    ns.Shell:BuildCharacter(char)
    ns.Shell:BuildBottomTabs(frame)

    -- Retried on show and whenever the client says portraits changed,
    -- because one call at build time can land before the model is
    -- resident and leaves the medallion empty with nothing to fix it.
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PORTRAITS_UPDATED")
    frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "player")
    frame:SetScript("OnEvent", function() ns.Shell:RefreshMedallion() end)
    frame:HookScript("OnShow", function() ns.Shell:RefreshMedallion() end)

    ns.Shell:RefreshMedallion()
    return frame
end

--- The player's own portrait in the medallion.
---
--- Deliberately the character rather than an addon logo: the window is
--- about one character's gear, and the frame saying which one is the
--- cheapest character detail available. A logo can replace it once one
--- exists that is worth the space.
---
--- Called on show and on the portrait events, not just once at build.
--- SetPortraitTexture needs the unit's model resident, and asking for it
--- while the frame is still being assembled -- which is what the first
--- version did, and only that -- silently leaves the texture unset. That
--- is the empty gold ring: the frame art drew, the portrait never
--- arrived, and nothing retried.
function Shell:RefreshMedallion()
    if not (frame and frame.medallion) then return end
    if not SetPortraitTexture then return end
    local ok = pcall(SetPortraitTexture, frame.medallion, "player")
    -- A fallback beats an empty circle. The class emblem is always
    -- available, where the portrait can still be loading.
    if not ok or not frame.medallion:GetTexture() then
        local _, classFile = UnitClass("player")
        if classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile] then
            frame.medallion:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
            frame.medallion:SetTexCoord(unpack(CLASS_ICON_TCOORDS[classFile]))
        end
    end
end
------------------------------------------------------------
-- Navigation: tabs along the bottom
--
-- Blizzard's PanelTabButtonTemplate, inherited rather than imitated, so
-- the art, the hit areas and the selected/deselected states are the
-- game's own. PanelTemplates_TabResize sizes each tab to its label,
-- which is why these can carry full page names where the side tabs
-- could only fit an initial.
--
-- They hang below the frame the way every Blizzard tabbed window does,
-- so like the side tabs they cost the layout no width -- the left column
-- stays the character's.
------------------------------------------------------------
function Shell:BuildBottomTabs(parent)
    local defs = self:GetPages()
    local buttons = {}

    -- Tabs live on their own bar so the whole row can be scaled to fit.
    --
    -- Ten tabs sized to their labels came to more than the window is
    -- wide and ran off the right edge. Picking a smaller padding by hand
    -- only moves where it breaks -- a longer page name, or a locale with
    -- longer words, overflows again. Measuring the row and scaling it is
    -- the version that cannot overflow.
    local bar = parent._yyhTabBar
    if not bar then
        bar = CreateFrame("Frame", nil, parent)
        parent._yyhTabBar = bar
    end
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, 2)
    bar:SetHeight(TAB_H)

    local x = 0
    for i, def in ipairs(defs) do
        local tab = CreateFrame("Button", "YippYappShellTab" .. i, bar,
            "PanelTabButtonTemplate")
        tab:SetID(i)
        tab:SetText(def.label or "?")

        -- Sized to its own text. Padding is modest now: the row is
        -- scaled to fit afterwards, so buying room with padding here
        -- would only force a smaller scale later.
        if PanelTemplates_TabResize then
            pcall(PanelTemplates_TabResize, tab, 10, nil, 40, 150)
        end

        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
        -- PLUS a gap, not minus an overlap. Blizzard's tabs are drawn to
        -- butt together like folder tabs, so any subtraction keeps them
        -- touching -- going -14 to -6 made the overlap smaller, not a
        -- gap. GetWidth() after TabResize is the full visible tab
        -- including its end caps, so separation has to be added.
        x = x + (tab:GetWidth() or 90) + TAB_GAP

        tab:SetScript("OnClick", function() ns.Shell:Open(def.id) end)
        buttons[def.id] = tab
    end

    local total = math.max(x - TAB_GAP, 1)
    bar:SetWidth(total)

    -- Scale down only. A short tab list should sit at its natural size
    -- rather than being stretched across the window.
    local budget = (parent:GetWidth() or total) - TAB_EDGE * 2
    local scale = math.min(1, budget / total)
    bar:SetScale(scale)

    -- Left inset is in the bar's own units, which is why it is applied
    -- after the scale rather than baked into x above.
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", TAB_EDGE / scale, 2 / scale)

    self._navButtons = buttons
    self._tabBar = bar
end

function Shell:MarkNav(id)
    for pageId, tab in pairs(self._navButtons or {}) do
        if pageId == id then
            if PanelTemplates_SelectTab then pcall(PanelTemplates_SelectTab, tab) end
        elseif PanelTemplates_DeselectTab then
            pcall(PanelTemplates_DeselectTab, tab)
        end
    end
end

--- Wallet rows are pooled: the currency list changes as headers are
--- collapsed and currencies discovered, and rebuilding frames on every
--- refresh would leak one set per page change.
local function acquireWalletRow(self, index, kind)
    local W = ns.Widgets
    local row = self._walletRows[index]
    if not row then
        row = {
            header = W:Label(self._walletScroll.content, "GameFontNormalSmall"),
            entry  = W:IconRow(self._walletScroll.content, 22),
        }
        -- The game's own currency tooltip. The id is stashed per refresh
        -- rather than captured here, because rows are pooled and outlive
        -- the currency they happened to show last time.
        local e = row.entry
        e:EnableMouse(true)
        e:SetScript("OnEnter", function(self2)
            if not self2._currencyID then return end
            GameTooltip:SetOwner(self2, "ANCHOR_LEFT")
            GameTooltip:SetCurrencyByID(self2._currencyID)
            GameTooltip:Show()
        end)
        e:SetScript("OnLeave", function() GameTooltip:Hide() end)

        e.hl = e:CreateTexture(nil, "HIGHLIGHT")
        e.hl:SetAllPoints()
        e.hl:SetColorTexture(1, 1, 1, 0.06)

        self._walletRows[index] = row
    end
    row.header:SetShown(kind == "header")
    row.entry:SetShown(kind == "entry")
    return row
end

------------------------------------------------------------
-- The character column
--
-- Replaces both the old nav list and the currency rail. Everything here
-- is true of the player rather than of the page: who you are, how
-- geared, and what you are holding. It never changes when you switch
-- view, which is what makes the shell feel like a window rather than a
-- set of pages that happen to share a border.
------------------------------------------------------------
local CREST_TILE = 30
local STAT_ROWS = {
    { key = "crit",    label = "Critical Strike" },
    { key = "haste",   label = "Haste" },
    { key = "mastery", label = "Mastery" },
    { key = "vers",    label = "Versatility" },
}

-- A scenic backdrop for the whole character column.
--
-- Plumber uses this one, so it is known to be live in the client rather
-- than guessed from an atlas listing. Drawn very faint and clipped to
-- the column: the point is to give the stats and the wallet something
-- with depth behind them instead of a flat fill, not to compete with
-- the text sitting on it.

function Shell:BuildCharacter(col)
    local W = ns.Widgets
    local pad = 14


    ------------------------------------------------------------
    -- Who
    ------------------------------------------------------------
    local hero = W:HeroCard(col)
    hero:SetPoint("TOPLEFT", pad, -pad)
    hero:SetPoint("RIGHT", col, "RIGHT", -pad, 0)
    self._charHero = hero

    ------------------------------------------------------------
    -- Stats
    ------------------------------------------------------------
    local statTitle = W:SectionTitle(col, "stats")
    statTitle:SetPoint("TOPLEFT", hero, "BOTTOMLEFT", 0, -14)
    statTitle:SetPoint("RIGHT", hero, "RIGHT", 0, 0)

    self._statRows = {}
    local anchor = statTitle
    for i, def in ipairs(STAT_ROWS) do
        local row = CreateFrame("Frame", nil, col)
        row:SetHeight(20)
        -- 0, not 2. Stat rows were indented two pixels past the
        -- heading above them, which is exactly enough to look wrong
        -- and not enough to look deliberate.
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, i == 1 and -8 or -2)
        -- Flush right with the rules above, so the percentages line up
        -- with the end of the divider rather than stopping short of it.
        row:SetPoint("RIGHT", hero, "RIGHT", 0, 0)

        row.label = W:Label(row, "GameFontNormal")
        row.label:SetPoint("LEFT")
        row.label:SetText(def.label)
        row.label:SetTextColor(W:Color("muted"))

        row.value = W:Label(row, "GameFontNormal", "RIGHT")
        row.value:SetPoint("RIGHT")

        self._statRows[def.key] = row
        anchor = row
    end

    ------------------------------------------------------------
    -- Crests
    ------------------------------------------------------------
    local crestTitle = W:SectionTitle(col, "item upgrades")
    crestTitle:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
    crestTitle:SetPoint("RIGHT", hero, "RIGHT", 0, 0)
    self._railCrests = crestTitle

    -- Centred, not left-packed. Five tiles across a 300px column left a
    -- ragged 60px of dead space on the right, so the strip read as
    -- misaligned with the headings above and below it rather than as a
    -- row of its own.
    local count = ns.CRESTS and #ns.CRESTS or 0
    local CREST_GAP = 14
    local strip = count > 0
        and (count * (CREST_TILE + 6) + (count - 1) * (CREST_GAP - 6)) or 0
    local startX = math.max(math.floor(((Shell.CHAR_W - pad * 2) - strip) / 2), 0)

    local tiles = {}
    for i = 1, count do
        tiles[i] = W:IconTile(col, CREST_TILE)
        tiles[i]:SetPoint("TOPLEFT", crestTitle, "BOTTOMLEFT",
            startX + (i - 1) * (CREST_TILE + CREST_GAP), -8)
    end
    self._crestTiles = tiles

    ------------------------------------------------------------
    -- Wallet
    ------------------------------------------------------------
    local wallet = W:SectionTitle(col, "currencies")
    wallet:SetPoint("TOPLEFT", crestTitle, "BOTTOMLEFT", 0, -(CREST_TILE + 34))
    wallet:SetPoint("RIGHT", hero, "RIGHT", 0, 0)
    self._railWallet = wallet

    self._walletScroll = W:ScrollList(col)
    self._walletScroll:SetPoint("TOPLEFT", wallet, "BOTTOMLEFT", 0, -6)
    self._walletScroll:SetPoint("BOTTOMRIGHT", col, "BOTTOMRIGHT", -pad - 18, pad)
    self._walletRows = {}

    self:RefreshRail()
end

--- Ratings, read straight from the client.
local function statPercents()
    local out = {}
    if GetCritChance then out.crit = GetCritChance() end
    if GetHaste then out.haste = GetHaste() end
    if GetMasteryEffect then out.mastery = GetMasteryEffect()
    elseif GetMastery then out.mastery = GetMastery() end
    if GetCombatRatingBonus and CR_VERSATILITY_DAMAGE_DONE then
        out.vers = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE)
    end
    return out
end

function Shell:RefreshCharacter()
    if self._charHero then self._charHero:Refresh() end
    if not self._statRows then return end
    local pct = statPercents()
    for key, row in pairs(self._statRows) do
        local v = tonumber(pct[key])
        row.value:SetText(v and ("%.2f%%"):format(v) or "|cff8a8a92--|r")
    end
end

function Shell:RefreshRail()
    -- Local here too. W is a local inside BuildCharacter and
    -- acquireWalletRow, neither of which encloses this function, so
    -- referring to it from here resolved to a nil global.
    local W = ns.Widgets
    ------------------------------------------------------------
    -- Crests
    ------------------------------------------------------------
    if self._crestTiles then
        local info = ns.GetCrestInfo and ns:GetCrestInfo() or nil
        for i, tile in ipairs(self._crestTiles) do
            local data = info and info[i]
            local def = ns.CRESTS and ns.CRESTS[i]
            if data then
                tile.icon:SetTexture(data.icon)
                tile.count:SetText("|c" .. (def and def.color or "ffffffff")
                    .. tostring(data.quantity or data.count or 0) .. "|r")
                -- Rarity from the game, not from our track legend. Those
                -- two are not the same thing: the legend paints Hero
                -- orange and Myth red because that is how the gear tracks
                -- read, but the currencies themselves carry their own
                -- quality, and a border is where rarity belongs. The
                -- track colour stays on the count below it.
                W:SetIconQuality(tile.border, data.quality)
                -- Stashed per refresh, not captured at build: which crest
                -- a tile shows can change when ResolveCrestIDs settles.
                tile._currencyID = data.currencyID or (def and def.id)
                tile:Show()
            else
                tile:Hide()
            end
        end
    end

    ------------------------------------------------------------
    -- The wallet
    ------------------------------------------------------------
    if not self._walletScroll then return end
    local groups = ns.GetCurrencyGroups and ns:GetCurrencyGroups() or {}
    local content = self._walletScroll.content
    local index, y = 0, 0

    for _, group in ipairs(groups) do
        if group.header ~= "" then
            index = index + 1
            local row = acquireWalletRow(self, index, "header")
            row.header:ClearAllPoints()
            row.header:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -y)
            row.header:SetText("|cffffd100" .. group.header .. "|r")
            y = y + 20
        end
        for _, item in ipairs(group.items) do
            index = index + 1
            local row = acquireWalletRow(self, index, "entry")
            row.entry:ClearAllPoints()
            row.entry:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            row.entry:SetPoint("RIGHT", content, "RIGHT", 0, 0)
            row.entry._currencyID = item.currencyID
            row.entry.icon:SetTexture(item.icon)
            -- Rarity on the border. Currency.lua already reads `quality`
            -- off the currency list; it was being collected and thrown
            -- away, so every row had the same grey edge whether it held
            -- an epic or a common.
            W:SetIconQuality(row.entry.iconEdge, item.quality)
            row.entry.label:SetText(item.name or "")
            row.entry.value:SetText(BreakUpLargeNumbers
                and BreakUpLargeNumbers(item.quantity or 0)
                or tostring(item.quantity or 0))
            y = y + 24
        end
    end

    for i = index + 1, #self._walletRows do
        self._walletRows[i].header:Hide()
        self._walletRows[i].entry:Hide()
    end
    self._walletScroll:SetContentHeight(y)
end

------------------------------------------------------------
-- Open / close
------------------------------------------------------------
function Shell:Open(id)
    local f = Build()
    f:Show()

    local defs = self:GetPages()
    id = id or self._lastPage or (defs[1] and defs[1].id)
    if not id then return end

    self._lastPage = id
    self:MarkNav(id)

    -- Each page gets its own host inside the content region, built once
    -- and then shown or hidden. Re-parenting one shared frame would mean
    -- every page rebuilding on every switch, which is what the old
    -- dispatch did and why switching pages was not free.
    self._hosts = self._hosts or {}
    for pageId, host in pairs(self._hosts) do
        host:SetShown(pageId == id)
    end
    if not self._hosts[id] then
        local host = CreateFrame("Frame", nil, frame.content)
        host:SetAllPoints(frame.content)
        self._hosts[id] = host
    end
    self._hosts[id]:Show()

    self:Mount(id, self._hosts[id])
    self:RefreshRail()
    self:RefreshCharacter()
end

--- Throw the window away so the next Open rebuilds it.
---
--- The chrome is created once from the skin's Panel, so changing skin
--- has to discard it: refreshing the pages inside repaints their
--- contents and leaves the window, the nav and the rail wearing the old
--- look. That is why the first skin swap appeared to do nothing at all.
function Shell:DiscardChrome()
    if not frame then return end
    local wasShown, page = frame:IsShown(), self._lastPage
    frame:Hide()
    frame:SetParent(nil)
    frame = nil
    self._navButtons, self._hosts = nil, nil
    self._charHero, self._statRows = nil, nil
    self._railCrests, self._crestTiles = nil, nil
    self._railWallet, self._walletScroll, self._walletRows = nil, nil, nil
    self:ResetMounts()
    if wasShown then self:Open(page) end
end

function Shell:Close()
    if frame then frame:Hide() end
end

function Shell:Toggle(id)
    if frame and frame:IsShown() then self:Close() else self:Open(id) end
end

function Shell:IsOpen()
    return frame ~= nil and frame:IsShown()
end
