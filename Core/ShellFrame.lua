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

------------------------------------------------------------
-- Escape, and why it needs a combat guard
--
-- The window is a plain frame, but the Mythic+ and Teleports pages mount
-- SecureActionButtonTemplate tiles inside it, and a frame holding a
-- protected frame is itself protected: once either page has been opened,
-- YippYappShell:Show and :Hide are protected calls for the rest of the
-- session. In combat the client refuses them outright, which is the
-- ADDON_ACTION_BLOCKED reported against 'YippYappShell:Show()'.
--
-- UISpecialFrames is the client hiding the window for us on Escape, so
-- while it is listed, every Escape press in combat is another blocked
-- call charged to this addon. Core/AppFrame.lua guards its entry the
-- same way; the shell never got the same treatment.
------------------------------------------------------------
local function registerSpecialFrame()
    for _, n in ipairs(UISpecialFrames) do if n == "YippYappShell" then return end end
    tinsert(UISpecialFrames, "YippYappShell")
end

local function unregisterSpecialFrame()
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "YippYappShell" then table.remove(UISpecialFrames, i); break end
    end
end

-- Set when a close was asked for during combat, so the window can go
-- away the moment the fight ends rather than the request being lost.
local closePending = false

------------------------------------------------------------
-- Closing while the client is refusing Hide
--
-- The window is only protected once a page with secure tiles has been
-- mounted -- Mythic+ or Teleports -- so `securePages` records whether
-- that has happened rather than assuming it. Before it does, an
-- ordinary Hide works mid-fight and there is nothing to work around.
--
-- After it does, insecure code cannot hide the window at all. What CAN
-- is a secure handler: a snippet running inside the restricted
-- environment may hide a frame it holds a reference to, in combat, the
-- same way a state driver hides an action bar. So the X button gets an
-- invisible secure button laid over it, and the click goes there.
--
-- Laid over rather than made from the template. A frame inheriting a
-- secure handler template is itself protected, and a protected child is
-- what makes its parent protected -- building one into the window
-- unconditionally would protect the window for people who never open
-- either page, and take their combat dragging away to fix a problem
-- they do not have. It is created when the window is already protected
-- and not before.
--
-- Only the button. A slash command or a minimap click still cannot
-- close the window mid-fight: the snippet needs a real click on the
-- handler to run, and Click() on a protected button is itself blocked.
-- Those keep the deferral, and the notice now says where the X is.
--
-- Escape is left alone deliberately. Routing it here means an override
-- binding, and clearing an override binding is blocked in combat too --
-- so a window closed mid-fight would go on swallowing Escape until the
-- fight ended, and the game menu with it. A key that stops working is
-- worse than a key that does nothing.
------------------------------------------------------------
local securePages = false
local closer

local combatGuard = CreateFrame("Frame")
combatGuard:RegisterEvent("PLAYER_REGEN_DISABLED")
combatGuard:RegisterEvent("PLAYER_REGEN_ENABLED")
combatGuard:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        unregisterSpecialFrame()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if closePending then
            closePending = false
            if frame then frame:Hide() end
            return
        end
        if frame and frame:IsShown() then registerSpecialFrame() end
    end
end)

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

    -- On every Show, not once at build. OnHide takes the window back out
    -- of UISpecialFrames, so registering only here meant Escape worked
    -- for the first open of the session and never again.
    frame:HookScript("OnShow", function()
        if not InCombatLockdown() then registerSpecialFrame() end
    end)
    frame:HookScript("OnHide", unregisterSpecialFrame)
    if frame:IsShown() and not InCombatLockdown() then registerSpecialFrame() end

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
    -- A rebuild drops the old button, so the overlay that sat on it has
    -- to be rebuilt too rather than pointing at a frame nobody can see.
    if closer then
        closer = nil
        Shell:EnableCombatClose()
    end

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
-- The window's own mark, not the player's face.
--
-- The medallion showed the character portrait, and the hero card two
-- inches below it shows the same portrait -- so the window opened with
-- one face on it twice. The dashboard already made this argument about
-- itself and dropped its own hero card for the same reason.
--
-- The logo is the thing that makes the window identifiably this addon's,
-- and this is the one place on screen that is shaped for a badge.
local LOGO_TEXTURE = "Interface\\AddOns\\YippYappHelper\\Media\\LogoRound"

function Shell:RefreshMedallion()
    if not (frame and frame.medallion) then return end

    frame.medallion:SetTexCoord(0, 1, 0, 1)
    frame.medallion:SetTexture(LOGO_TEXTURE)
    if frame.medallion:GetTexture() then return end

    -- No round logo shipped yet, so fall back to the square one that is
    -- already here. It loses its corners to the mask, which is exactly
    -- why the round one is being drawn -- but a clipped badge beats an
    -- empty ring, and this keeps the addon working from the commit that
    -- changes the code to the commit that adds the art.
    frame.medallion:SetTexture("Interface\\AddOns\\YippYappHelper\\Media\\YippYappHelper")
    if frame.medallion:GetTexture() then return end

    -- And if even that is missing, the player's own portrait rather than
    -- an empty circle.
    if SetPortraitTexture then
        pcall(SetPortraitTexture, frame.medallion, "player")
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
        --
        -- The MINIMUM is 72, not 40, and that is not padding by another
        -- name. This template's art is three pieces -- a left cap, a
        -- stretched middle, a right cap -- and the caps are about twenty
        -- pixels each. At a 40px floor the middle has essentially no
        -- width to stretch into, and a short label lands there and draws
        -- as a smear with no proper end. "Raid" is four characters where
        -- the next shortest page is seven, so it was the only tab that
        -- reached the floor, and it did so the moment the label was
        -- shortened from "Raid Tools".
        --
        -- Raising the floor rather than the padding on purpose: padding
        -- widens every tab and the row is auto-scaled to fit, so paying
        -- for one short label there would shrink all ten.
        if PanelTemplates_TabResize then
            pcall(PanelTemplates_TabResize, tab, 10, nil, 72, 150)
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

--- What the accent on a stat row means, and where the rest of it lives.
---
--- Declared above BuildCharacter rather than beside the button that
--- uses it. A local defined below its call site is not an upvalue, it
--- is a nil global, and the call throws the first time anyone hovers.
local function StatPriorityTooltip(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:SetText("Stat Priority", 1, 1, 1)

    local entry = btn._entry
    if entry then
        if btn._build then GameTooltip:AddLine(btn._build, 0.45, 0.85, 1.00) end
        if entry.context and entry.context ~= "" then
            GameTooltip:AddLine(entry.context, 0.62, 0.62, 0.68)
        end
        for i, line in ipairs(entry.stats or {}) do
            GameTooltip:AddLine(("%d. %s"):format(i, line), 0.92, 0.92, 0.95)
        end
    elseif btn._why then
        GameTooltip:AddLine(btn._why, 0.62, 0.62, 0.68, true)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click for the full list.", 0.45, 0.85, 1.00)
    GameTooltip:Show()
end

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
    local statTitle = W:SectionTitle(col, "Stats")
    statTitle:SetPoint("TOPLEFT", hero, "BOTTOMLEFT", 0, -14)
    statTitle:SetPoint("RIGHT", hero, "RIGHT", 0, 0)

    -- The heading doubles as the way into the full priority list.
    --
    -- On the heading rather than beside it. This column has no other
    -- control in it, so a lone "stat prio" link floating among static
    -- rows reads as debris; hung off the heading it reads as what that
    -- heading is about. The rule under the text leaves the right end of
    -- the line box free, which is where the hint goes.
    local statLink = CreateFrame("Button", nil, statTitle)
    statLink:SetAllPoints(statTitle)
    statLink.hint = W:Label(statLink, "GameFontNormalSmall", "RIGHT")
    statLink.hint:SetPoint("TOPRIGHT", 0, -3)
    statLink.hint:SetText("Stat Priority >")
    statLink.hint:SetTextColor(W:Color("faint"))

    statLink:SetScript("OnEnter", function(btn)
        btn.hint:SetTextColor(W:Color("accent"))
        StatPriorityTooltip(btn)
    end)
    statLink:SetScript("OnLeave", function(btn)
        btn.hint:SetTextColor(W:Color("faint"))
        GameTooltip:Hide()
    end)
    statLink:SetScript("OnClick", function() Shell:Open("bis") end)
    -- Only where there is somewhere to go. Best in Slot registers in
    -- Core/ShellPages.lua, which loads after this file, so the question
    -- has to be asked at build time rather than at file scope.
    statLink:SetShown(Shell:GetPage("bis") ~= nil)
    self._statLink = statLink

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
    local crestTitle = W:SectionTitle(col, "Item Upgrades")
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
    local wallet = W:SectionTitle(col, "Currencies")
    wallet:SetPoint("TOPLEFT", crestTitle, "BOTTOMLEFT", 0, -(CREST_TILE + 34))
    wallet:SetPoint("RIGHT", hero, "RIGHT", 0, 0)
    self._railWallet = wallet

    self._walletScroll = W:ScrollList(col)
    self._walletScroll:SetPoint("TOPLEFT", wallet, "BOTTOMLEFT", 0, -6)
    self._walletScroll:SetPoint("BOTTOMRIGHT", col, "BOTTOMRIGHT", -pad - 18, pad)
    self._walletRows = {}

    ------------------------------------------------------------
    -- Keeping the accent honest
    --
    -- Which stat is lit depends on your spec and on which hero talent
    -- you took, and both can change with this window open -- comparing
    -- stats is a thing people do WHILE respeccing. Nothing else redraws
    -- this column: Shell:Open does, once, and a page switch deliberately
    -- does not touch it.
    --
    -- Coalesced, because TRAIT_CONFIG_UPDATED arrives in bursts as a
    -- loadout applies and there is no reason to re-read the guide once
    -- per trait.
    ------------------------------------------------------------
    local watcher = CreateFrame("Frame", nil, col)
    watcher:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    watcher:RegisterEvent("TRAIT_CONFIG_UPDATED")
    local pending = false
    watcher:SetScript("OnEvent", function()
        if pending or not col:IsShown() then return end
        pending = true
        C_Timer.After(0.25, function()
            pending = false
            if col:IsShown() then Shell:RefreshCharacter() end
        end)
    end)

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
    -- Local, and it has to be: W at this file's scope is the window
    -- WIDTH, a number. The same shadowing already cost RefreshRail a
    -- round of nil indexing.
    local W = ns.Widgets

    -- Which of the four the guide puts first, for the spec and hero
    -- talent this character is in. Nil is a real answer and the common
    -- one for a spec whose builds disagree, so every use below has to
    -- tolerate it rather than defaulting to a rank.
    local ranks, entry, build
    if ns.StatPriorityRanks then ranks, entry, build = ns:StatPriorityRanks() end

    local pct = statPercents()
    for key, row in pairs(self._statRows) do
        local v = tonumber(pct[key])
        row.value:SetText(v and ("%.2f%%"):format(v) or "|cff8a8a92--|r")

        -- One step of contrast, not four. The rows answer "how much
        -- crit do I have"; the question people open this column with is
        -- "should I care", and lighting the stat the guide leads with
        -- answers it without spending a row or a pixel of height. The
        -- rest of the order is a hover away on the heading.
        if ranks and ranks[key] == 1 then
            row.label:SetTextColor(W:Color("accent"))
            row.value:SetTextColor(W:Color("accent"))
        else
            row.label:SetTextColor(W:Color("muted"))
            row.value:SetTextColor(W:Color("text"))
        end
    end

    local link = self._statLink
    if link then
        link._entry, link._build = entry, build
        if entry then
            link._why = nil
        elseif ranks then
            -- Marked from agreement rather than from one build. Say so,
            -- because the alternative is a lit row the tooltip cannot
            -- account for.
            link._why = "Your hero talent builds rank the stats below "
                .. "this one differently. They agree on the one lit above."
        elseif ns.PlayerSpecKey and ns.ClassGuideData
            and ns.ClassGuideData[ns:PlayerSpecKey() or ""] then
            link._why = "Your hero talent builds want different stats, "
                .. "and this addon cannot tell which one you are in."
        else
            link._why = "No stat priority for this specialization yet."
        end
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

                -- Just the number held. The cap is on hover.
                --
                -- Two attempts at putting it on the tile both made it
                -- worse: "90/100" wrapped onto two lines under a 40px
                -- icon, and a bar under five icons added a row of rails
                -- to a strip whose whole job is to be glanceable. The
                -- tooltip is SetCurrencyByID -- Blizzard's own, with the
                -- cap and the season total already in it -- so there was
                -- never anything to add here, only something to point
                -- at.
                tile.count:SetText("|c" .. (def and def.color or "ffffffff")
                    .. tostring(data.quantity or data.count or 0) .. "|r")
                -- The track legend, not the currency's own rarity.
                --
                -- Rarity was the earlier choice and the argument for it
                -- was that a border is where quality belongs. It reads
                -- badly here: the five crests are a ladder, green
                -- through red, and that ladder is the only thing anyone
                -- looks at this strip to see. Item quality tells you
                -- almost nothing by comparison -- several of them share
                -- it -- so the border was spending the strongest signal
                -- on the least useful fact.
                local cr, cg, cb = W:HexToRGB(def and def.color)
                if cr then
                    tile:SetEdge(cr, cg, cb)
                else
                    W:SetIconQuality(tile.border, data.quality)
                end
                -- Stashed per refresh, not captured at build: which crest
                -- a tile shows can change when ResolveCrestIDs settles.
                tile._currencyID = data.currencyID or (def and def.id)
                -- Which wallet this is, so the hover can say what the
                -- whole tier can still do. A balance is what you have;
                -- that sentence is what it reaches, which is the half no
                -- number on the tile can show. Built on hover -- see
                -- W:IconTile -- because it costs a plan per track.
                tile._track = def and def.track or nil
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
--- The gate every way into the window passes through, in combat.
---
--- Here rather than only at ns:OpenMain because the nav tabs, the stat
--- link in the character column and the after-key summary all call Open
--- directly, and a guard the front door alone knows about is a guard
--- three callers walk around.
---
--- Changing page is refused as flatly as opening is, and for the same
--- reason: every host lives inside a window that counts as protected the
--- moment a secure page has been mounted in it, so showing one host and
--- hiding another are both protected calls. Refusing the whole switch is
--- the conservative reading -- a page of plain fontstrings may well swap
--- in fine -- but the failure mode for guessing wrong is a blocked-action
--- error mid-pull, and nobody is reading the Consumables page while the
--- boss is casting.
local function combatRefusesPage(self, id)
    if not InCombatLockdown() then return false end

    if not (frame and frame:IsShown()) then
        if ns.CombatNotice then
            ns.CombatNotice("can't open in combat — try again after the fight.")
        end
        return true
    end

    if id and id ~= self._lastPage then
        local def = self.GetPage and self:GetPage(id)
        local label = (def and def.label) or id
        if ns.CombatNotice then
            ns.CombatNotice("can't switch to " .. label .. " in combat — the window stays on this page until the fight ends.")
        end
        return true
    end

    -- Already open, already on that page. Nothing to do, and re-mounting
    -- would rebuild the very tiles the client is refusing to let us touch.
    return true
end

function Shell:Open(id)
    -- Before Build, not after: building in combat is legal but pointless
    -- when the Show at the end of it is going to be refused anyway.
    if combatRefusesPage(self, id) then return end

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
    --
    -- Only touched when the answer actually changes. SetShown on a frame
    -- already in that state still counts as a Show or Hide call, and the
    -- hosts holding teleport tiles are protected, so the unconditional
    -- version spent a blocked call per page on every switch.
    self._hosts = self._hosts or {}
    for pageId, host in pairs(self._hosts) do
        local want = (pageId == id)
        if host:IsShown() ~= want then host:SetShown(want) end
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
    self._charHero, self._statRows, self._statLink = nil, nil, nil
    self._railCrests, self._crestTiles = nil, nil
    self._railWallet, self._walletScroll, self._walletRows = nil, nil, nil
    self:ResetMounts()
    if wasShown then self:Open(page) end
end

--- Puts the secure overlay on the X, so a click closes mid-fight.
---
--- Called when a page with secure tiles is mounted, which is the moment
--- the window becomes protected and the moment the overlay stops being
--- a cost to everyone else. Attributes and frame refs cannot be set on
--- a protected frame in combat, so a call that lands mid-fight does
--- nothing and the next page mount picks it up.
function Shell:EnableCombatClose()
    securePages = true
    if closer or not frame or not frame.closeButton then return end
    if InCombatLockdown() then return end

    -- Guarded because the whole window rides on it. If the template is
    -- ever missing the frame is not built, the X keeps the plain path,
    -- and the deferral below is what closes the window -- which is the
    -- behaviour that was there before this existed. An error here would
    -- take the rest of Build with it.
    local built, made = pcall(CreateFrame, "Button", "YippYappShellCloser",
        frame, "SecureHandlerClickTemplate")
    if not built or not made then return end

    closer = made
    closer:SetAllPoints(frame.closeButton)
    closer:SetFrameLevel(frame.closeButton:GetFrameLevel() + 5)
    closer:SetFrameRef("shell", frame)
    closer:SetAttribute("_onclick", [[ self:GetFrameRef("shell"):Hide() ]])
    -- The button underneath never sees the mouse again, so its hover
    -- state is driven from here. Without this the X goes dead-looking
    -- the moment the overlay appears, which reads as the button having
    -- broken rather than having been reinforced.
    closer:SetScript("OnEnter", function()
        if frame and frame.closeButton then frame.closeButton:LockHighlight() end
    end)
    closer:SetScript("OnLeave", function()
        if frame and frame.closeButton then frame.closeButton:UnlockHighlight() end
    end)
    return closer
end

--- Closes the window, or promises to as soon as combat ends.
---
--- The deferral is for the paths that cannot be made to work in combat
--- at all -- /yh, the minimap button, anything script-driven -- and only
--- while the window is protected. Until a secure page has been mounted
--- the plain Hide is allowed mid-fight and there is no reason to make
--- anyone wait for it.
function Shell:Close()
    if not frame then return end
    if securePages and InCombatLockdown() and frame:IsShown() then
        closePending = true
        if ns.CombatNotice then
            ns.CombatNotice("can't close from a command in combat — click the X, or it will close itself when the fight ends.")
        end
        return
    end
    frame:Hide()
end

function Shell:Toggle(id)
    if frame and frame:IsShown() then self:Close() else self:Open(id) end
end

function Shell:IsOpen()
    return frame ~= nil and frame:IsShown()
end
