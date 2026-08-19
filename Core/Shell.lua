local _, ns = ...

------------------------------------------------------------
-- The shell.
--
-- One persistent frame that owns the chrome, and a content region that
-- swaps when you change page. Pages register a definition and are handed
-- a host frame plus a context; they never build a title bar, a tab strip
-- or a backdrop of their own.
--
-- This exists because an audit of the nine pages found five of them
-- hand-rolling a tab bar, three placing their own filter controls, and
-- two capturing the frame width at load while the rest read it at
-- render. The Trinkets page is the clearest case: it grew a tab bar, a
-- fight-style toggle, a search box, an item level stepper and a checkbox
-- purely because there was nowhere to put them, and then needed its own
-- magnification pass to make the result fit. All of that is furniture
-- every page wants and none of them should be inventing.
--
-- The contract has one hard rule, and the skin system depends on it:
--
--   PAGES DO NOT DRAW CHROME.
--
-- No SetBackdrop, no border colours, no frame art. A page asks the shell
-- for a styled panel and fills it. That is the only way two skins can
-- exist without becoming two layouts -- regions and sizes are shared,
-- and a skin changes nothing but appearance.
------------------------------------------------------------

ns.Shell = ns.Shell or {}
local Shell = ns.Shell

------------------------------------------------------------
-- Regions
--
-- Derived from the layout audit rather than chosen: the Best in Slot
-- doll cannot shrink below 300 and needs its list beside it, and the
-- Trinkets rows need room for a bar at ~44% plus a name and a value
-- column. Both land near 700, so that is the floor the content region
-- guarantees and the width everything else is sized around.
------------------------------------------------------------
--
-- The spacing was measured against Vaultloom after the shell was called
-- flat, and every value here was exactly half of its equivalent there:
-- padding 7 against 16, gap 7 against 14, hero 56 against 112, nav 170
-- against 268. That is most of what "no character" meant. Cramped is not
-- a style, and no amount of frame art fixes it -- so these moved first
-- and the skins were rebuilt around them.
Shell.TITLE_H   = 28

------------------------------------------------------------
-- Two columns, not three.
--
-- The addon looked like a copy of Vaultloom because it was arranged
-- like one: nav column, content, currency rail. That is their
-- signature, and no amount of restyling survives keeping it.
--
-- So the left column is the CHARACTER -- portrait, item level, stats,
-- and the wallet beneath them -- which is the game's own paper-doll
-- idiom and the thing the addon is actually about. Navigation moves to
-- tabs hanging off the outer right edge, drawn with Blizzard's
-- common-sidetab art, which is a shape Vaultloom does not use at all.
--
-- CHAR_W is 300 because the crest strip needs five tiles across it and
-- the stat rows need a label plus a value without wrapping.
------------------------------------------------------------
Shell.CHAR_W    = 300
Shell.SIDETAB_W = 32
Shell.SIDETAB_H = 46

-- Kept as an alias so the pages that ask for nav width during the
-- migration still get an answer. Nothing new should use it.
Shell.NAV_W     = 300

-- The medallion, taken verbatim from PortraitFrameTemplate in
-- Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml: a 62px portrait
-- at TOPLEFT (-5, 7), masked circular by TempPortraitAlphaMask. Copied
-- rather than eyeballed because the gold ring is painted into the frame's
-- corner atlas at exactly this position -- a few pixels out and the
-- portrait sits beside its own ring.
-- Blizzard's exact values, and they stay that way. The ring is painted
-- into the corner atlas at a fixed offset, so the portrait's position is
-- not a free choice -- nudging it to (-9, 11) to cover a corner left the
-- portrait sitting low inside its own ring, because the ring did not
-- move with it. The two are one piece of art in two textures.
Shell.MEDALLION_SIZE = 62
Shell.MEDALLION_X    = -5
Shell.MEDALLION_Y    = 7
Shell.MEDALLION_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
Shell.RAIL_W    = 300
Shell.CONTENT_MIN = 700
Shell.HERO_H    = 112
Shell.SUBTAB_H  = 28
Shell.FILTER_H  = 30
Shell.GAP       = 14
Shell.PAD       = 16

--- The window size the regions add up to. Kept as a function because
--- the rail collapses to icons on a narrow screen and the answer
--- changes with it.
---
--- Deliberately not ns:GetAppFrameSize's 700..960 clamp. That clamp
--- predates a three-region layout and would leave the content region
--- under 500 -- narrower than the Trinkets page uses today.
--- The window size the regions add up to.
---
--- Two columns now: the character panel and the content. The side tabs
--- hang OUTSIDE the frame, so they cost nothing here -- which is part of
--- why they were chosen over a third column.
---
--- The argument is ignored and kept only so callers written against the
--- three-column version do not error.
function Shell:PreferredWidth()
    return self.PAD * 2 + self.CHAR_W + self.GAP + self.CONTENT_MIN
end

------------------------------------------------------------
-- Page registry
------------------------------------------------------------
local pages, order = {}, {}

--- Register a page.
---
--- Fields the shell reads:
---
---   id        unique string, also the saved-variable key
---   label     nav label
---   accent    { r, g, b } -- tints the sub-tab underline and nav mark.
---             Pages keep their existing colours; the shell only decides
---             where the colour is applied, never what it is.
---   order     sort position in the nav
---   subTabs   optional list of { id, label }, or a function returning
---             one. A function because Loot Browser's tabs depend on
---             what the Encounter Journal actually has, and Trinkets
---             hides a fight style with no data for any spec.
---   filters   optional function(host, ctx) building the filter strip.
---             The shell provides the strip and its position; the page
---             fills it. Search boxes, dropdowns and toggles go here.
---   wantsRail defaults true. Pages that need every pixel can decline
---             the currency rail, and the shell gives the width to the
---             content region instead of leaving a gap.
---   minWidth  optional override of CONTENT_MIN.
---
--- Methods the shell calls:
---
---   Build(host, ctx)    once, when the page is first opened. Lazy on
---                       purpose: nine pages built at load is nine
---                       pages of frames for the eight you did not open.
---   Refresh(ctx)        whenever the page is shown, its sub-tab
---                       changes, or its data does.
---   OnSubTab(id, ctx)   optional. Called before Refresh when the
---                       sub-tab changed, for pages that keep state.
---
--- Everything is optional except id, label and Refresh. A page with no
--- Build is one whose Refresh is idempotent, which is fine.
function Shell:RegisterPage(def)
    if type(def) ~= "table" or type(def.id) ~= "string" or def.id == "" then
        return false
    end
    if pages[def.id] then
        -- Loud rather than silent: two pages sharing an id means one of
        -- them never renders, and that is a bug nobody would find by
        -- looking at either file.
        error("Duplicate YippYapp shell page: " .. def.id)
    end
    if type(def.Refresh) ~= "function" then
        error("Shell page " .. def.id .. " has no Refresh")
    end

    def.order = tonumber(def.order) or (#order + 1) * 10
    def.wantsRail = def.wantsRail ~= false
    def.minWidth = tonumber(def.minWidth) or self.CONTENT_MIN

    pages[def.id] = def
    order[#order + 1] = def.id
    table.sort(order, function(a, b)
        if pages[a].order ~= pages[b].order then
            return pages[a].order < pages[b].order
        end
        return a < b
    end)
    return true
end

function Shell:GetPage(id) return pages[id] end

--- Nav order. Returns definitions, not ids, so the caller does not have
--- to look each one up again to draw it.
function Shell:GetPages()
    local out = {}
    for i, id in ipairs(order) do out[i] = pages[id] end
    return out
end

--- The widest minimum any registered page asks for.
---
--- Asked rather than assumed: if a page ever needs more than the
--- audit's 700, the window should grow to fit it rather than that page
--- quietly rendering cramped.
function Shell:RequiredContentWidth()
    local w = self.CONTENT_MIN
    for _, def in pairs(pages) do
        if def.minWidth > w then w = def.minWidth end
    end
    return w
end

------------------------------------------------------------
-- Context
--
-- What a page is handed on Build and Refresh. A table rather than
-- arguments so fields can be added without touching every page -- there
-- are nine of them and they are migrating one at a time.
------------------------------------------------------------

--- ctx = {
---   content   frame to draw into. Already positioned and sized; a page
---             anchors to it and never to UIParent or the app frame.
---   width     content width in the page's own units.
---   height    likewise.
---   subTab    id of the active sub-tab, or nil.
---   skin      the active skin provider, for pages that need to ask
---             rather than be told (an icon that differs per skin).
---   Panel(parent, role)
---             a styled frame. Roles are the skin's vocabulary --
---             "panel", "row", "inset", "header". This is how a page
---             gets a background without knowing what one looks like.
--- }

--- Build the context for a page. `host` is the content frame.
function Shell:BuildContext(def, host, subTab)
    local skin = ns.Skin and ns.Skin:Active()
    return {
        content = host,
        width   = host:GetWidth(),
        height  = host:GetHeight(),
        subTab  = subTab,
        skin    = skin,
        Panel   = function(parent, role)
            if skin and skin.Panel then
                return skin:Panel(parent or host, role or "panel")
            end
            -- No skin loaded is not a reason to render nothing. A bare
            -- frame still lays out correctly; it is only undecorated.
            return CreateFrame("Frame", nil, parent or host)
        end,
    }
end

------------------------------------------------------------
-- Sub-tabs
--
-- The shell owns the strip; the page owns what is in it.
--
-- This is the correction that came out of looking at how Vaultloom
-- Ironveil does it: the sub-tabs sit inside the content region under
-- the hero, not up in the outer chrome. Putting them in the chrome
-- would mean the shell had to know about every page's views; putting
-- them nowhere is what produced two tab rows on one line in Trinkets.
------------------------------------------------------------
function Shell:ResolveSubTabs(def)
    local tabs = def.subTabs
    if type(tabs) == "function" then
        local ok, result = pcall(tabs, def)
        tabs = ok and result or nil
    end
    if type(tabs) ~= "table" or #tabs == 0 then return nil end
    return tabs
end

------------------------------------------------------------
-- Mounting
--
-- Builds the furniture around a page's content and drives its
-- lifecycle. Scoped to the content region on purpose: the nav and the
-- currency rail still belong to AppFrame today, and pages are migrating
-- one at a time. A page mounted here works inside the old chrome and
-- keeps working when the outer shell replaces it, because everything it
-- is handed comes through the context rather than from its parent.
------------------------------------------------------------
local mounted = {}

local function LayOut(m)
    local def, host = m.def, m.host
    local y = 0

    local tabs = Shell:ResolveSubTabs(def)
    if tabs then
        m.subTabBar:ClearAllPoints()
        m.subTabBar:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -y)
        m.subTabBar:SetPoint("RIGHT", host, "RIGHT", 0, 0)
        m.subTabBar:SetHeight(Shell.SUBTAB_H)
        m.subTabBar:Show()
        y = y + Shell.SUBTAB_H + 2
    else
        m.subTabBar:Hide()
    end

    if def.filters then
        m.filterBar:ClearAllPoints()
        m.filterBar:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -y)
        m.filterBar:SetPoint("RIGHT", host, "RIGHT", 0, 0)
        m.filterBar:SetHeight(Shell.FILTER_H)
        m.filterBar:Show()
        y = y + Shell.FILTER_H + 4
    else
        m.filterBar:Hide()
    end

    m.content:ClearAllPoints()
    m.content:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -y)
    m.content:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
end

--- Put a registered page inside `parent` and return its mount.
---
--- Idempotent: mounting twice refreshes rather than building a second
--- set of frames. AppFrame calls this every time the page is shown.
function Shell:Mount(id, parent)
    local def = pages[id]
    if not def or not parent then return nil end

    local m = mounted[id]
    if not m then
        m = { def = def, host = parent }
        m.subTabBar = CreateFrame("Frame", nil, parent)
        m.filterBar = CreateFrame("Frame", nil, parent)
        m.content   = CreateFrame("Frame", nil, parent)
        m.subTabButtons = {}
        mounted[id] = m

        YippYappHelperDB = YippYappHelperDB or {}
        YippYappHelperDB.shellSubTab = YippYappHelperDB.shellSubTab or {}
        m.subTab = self:InitialSubTab(def, YippYappHelperDB.shellSubTab[id])

        LayOut(m)
        self:BuildSubTabs(m)

        if def.filters then
            def.filters(m.filterBar, self:BuildContext(def, m.content, m.subTab))
        end
        if def.Build then
            def.Build(m.content, self:BuildContext(def, m.content, m.subTab))
        end

        -- Tell the page which sub-tab it is on, once, before its first
        -- draw.
        --
        -- Without this the strip and the content disagreed on arrival:
        -- the shell restores the remembered sub-tab and marks it, but a
        -- page keeps its own idea of the current view in a local, and
        -- that local still held whatever it was initialised to. So
        -- Trinkets could show "Loot Council" underlined with My Spec's
        -- rows beneath it. Clicking the OTHER tab and back was the only
        -- cure, because SetSubTab returns early when the id already
        -- matches -- clicking the tab that was already lit did nothing.
        --
        -- After Build, not before: OnSubTab reaches into the page's own
        -- frames, and the pages that build lazily have none until Build
        -- has run.
        if def.OnSubTab and m.subTab then
            def.OnSubTab(m.subTab, self:BuildContext(def, m.content, m.subTab))
        end
    end

    self:RefreshPage(id)
    return m
end

--- Draw the sub-tab strip. The shell owns the strip and its position;
--- the page only said what the tabs are.
function Shell:BuildSubTabs(m)
    local tabs = self:ResolveSubTabs(m.def)
    if not tabs then return end

    local accent = m.def.accent or { 0.45, 0.85, 1.0 }
    -- The rule the tabs sit on, across the whole strip rather than only
    -- under the tabs -- so the row reads as a rail with a segment lit,
    -- which is the part that makes it look like tabs at all.
    if ns.TabBaseline then ns.TabBaseline(m.subTabBar) end
    local x = 0
    for i, t in ipairs(tabs) do
        local btn = m.subTabButtons[i]
        if not btn then
            btn = ns.CreateUnderlineTab and ns.CreateUnderlineTab(m.subTabBar, t.label, accent)
                or CreateFrame("Button", nil, m.subTabBar)
            m.subTabButtons[i] = btn
        end
        btn:SetSize(t.width or 104, Shell.SUBTAB_H)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", m.subTabBar, "TOPLEFT", x, 0)
        btn:SetScript("OnClick", function() ns.Shell:SetSubTab(m.def.id, t.id) end)
        btn:Show()
        x = x + (t.width or 104) + 6
    end
    for i = #tabs + 1, #m.subTabButtons do m.subTabButtons[i]:Hide() end
    self:MarkSubTab(m)
end

function Shell:MarkSubTab(m)
    local tabs = self:ResolveSubTabs(m.def)
    if not tabs then return end
    for i, t in ipairs(tabs) do
        local btn = m.subTabButtons[i]
        if btn then
            if t.id == m.subTab then
                if ns.SetTabActive then ns.SetTabActive(btn) end
            elseif ns.SetTabInactive then
                ns.SetTabInactive(btn)
            end
        end
    end
end

--- Remembered per page, not globally: coming back to Trinkets on the
--- tab you left it on is the point, and the Loot Browser having its own
--- memory is what stops one page's choice moving another's.
function Shell:SetSubTab(id, subTab)
    local m = mounted[id]
    if not m or m.subTab == subTab then return end
    m.subTab = subTab
    YippYappHelperDB.shellSubTab[id] = subTab
    self:MarkSubTab(m)

    local ctx = self:BuildContext(m.def, m.content, subTab)
    if m.def.OnSubTab then m.def.OnSubTab(subTab, ctx) end
    m.def.Refresh(ctx)
end

function Shell:RefreshPage(id)
    local m = mounted[id]
    if not m then return end
    LayOut(m)
    m.def.Refresh(self:BuildContext(m.def, m.content, m.subTab))
end

--- Redraw everything mounted. Called when the skin changes, since every
--- page's panels came from the provider that just went away.
--- Drop every mount. Their frames belong to chrome that is about to be
--- discarded, so keeping them would hand the next Build a parent that no
--- longer exists.
function Shell:ResetMounts()
    mounted = {}
end

--- Called when the skin changes. Discarding the chrome rather than
--- refreshing the pages, because the window, nav and rail were built
--- from the provider that just went away.
function Shell:Rebuild()
    if self.DiscardChrome then self:DiscardChrome() end
end

--- The sub-tab a page should open on: the one it was last left on, if
--- that tab still exists.
---
--- The existence check matters. Trinkets hides a fight style with no
--- data for any spec and the Loot Browser's tabs follow the Encounter
--- Journal, so a remembered tab can legitimately vanish between
--- sessions. Restoring it blindly opens the page on nothing.
function Shell:InitialSubTab(def, remembered)
    local tabs = self:ResolveSubTabs(def)
    if not tabs then return nil end
    for _, t in ipairs(tabs) do
        if t.id == remembered then return remembered end
    end
    return tabs[1].id
end
