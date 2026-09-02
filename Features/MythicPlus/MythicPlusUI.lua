local _, ns = ...

------------------------------------------------------------
-- Mythic Plus UI: keystones, ratings, and dungeon scores
------------------------------------------------------------
-- Padding comes from the shell, not from here. Eight pages had picked
-- their own -- 12 in four of them, 14 in three -- so every page sat to a
-- different rhythm from the chrome around it and from each other. One
-- source means a spacing change lands everywhere at once.
local PAD = (ns.Shell and ns.Shell.PAD) or 12
local ROW_H = 18
local SECTION_GAP = 10

------------------------------------------------------------
-- Main frame (standalone)
------------------------------------------------------------
local frame = CreateFrame("Frame", "YippYappMythicPlus", UIParent, "BackdropTemplate")
local MPLUS_W, MPLUS_H = ns:GetAppFrameSize()
frame:SetSize(MPLUS_W, MPLUS_H)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetClampedToScreen(true)
frame:SetFrameStrata("HIGH")
ns.Widgets:Apply(frame, "panel")
ns.SmoothFrame(frame)
frame:Hide()
ns.MythicPlusFrame = frame

-- Quick slash command to jump straight to the Mythic+ page.
-- /keys is gone: far too generic a global for one addon to hold, and
-- several Mythic+ addons register it, so whoever loaded last won.
SLASH_YYHKEYS1 = "/yhkeys"
SlashCmdList.YYHKEYS = function()
    -- Keyed off OpenTo rather than off a specific window: gating on one
    -- meant this went nowhere in a session where the shell had loaded
    -- and the old window had not.
    if ns.OpenTo then ns:OpenTo("mythicplus") end
end

-- ESC to close, and only while this is a window of its own.
--
-- Mounted into the shell the frame is the page CONTENT, and a
-- registration made from here lands in UISpecialFrames after the
-- shell's own -- so Escape hid the page and left the window standing
-- empty around it, which took two presses to close and looked broken
-- on the first. It also defeated the shell's combat guard: the shell
-- takes itself out of the list in combat precisely because this page
-- protects it, and this entry put the protected frame straight back.
frame:SetScript("OnShow", function()
    if frame.inAppMode then return end
    tinsert(UISpecialFrames, "YippYappMythicPlus")
end)
frame:SetScript("OnHide", function()
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "YippYappMythicPlus" then
            table.remove(UISpecialFrames, i)
            break
        end
    end
end)

-- Title
local titleIcon, titleFs = ns.MakeWindowHeader(frame, "|cff00d4ffMythic+|r", nil, PAD)

-- Close button
local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -2, -2)

------------------------------------------------------------
-- Tabs
------------------------------------------------------------
local activeTab = "home"
local TAB_H = 22
local TAB_W = 90
local TAB_GAP = 4
local TAB_Y = -36
-- The vault chips get a row to themselves in app mode. In the standalone
-- window they share the tab row, but the shell draws the tabs, so here
-- the content has to start below the chips instead of behind them.
local testMode = false

local tabDefs = {
    { id = "home",  label = "Home" },
    { id = "guild", label = "Guild" },
}

local tabButtons = {}
for i, def in ipairs(tabDefs) do
    local tab = ns.CreateUnderlineTab(frame, def.label, { 0.0, 0.83, 1.0 })
    tab:SetSize(TAB_W, TAB_H)
    tab:SetPoint("TOPLEFT", PAD + (i - 1) * (TAB_W + TAB_GAP), TAB_Y)
    tab._id = def.id
    tab:SetScript("OnClick", function()
        activeTab = def.id
        ns:RefreshMythicPlus()
    end)
    tabButtons[def.id] = tab
end

--- Switch view from outside.
---
--- The shell owns the sub-tab strip -- that is the contract's whole
--- point, and five pages were each drawing their own row of tabs a few
--- pixels from where the shell puts them. This is the entry point it
--- drives; the internal row survives for the standalone window.
function ns:SetMythicPlusTab(id)
    if not tabButtons[id] or activeTab == id then return end
    activeTab = id
    ns:RefreshMythicPlus()
end

--- The tabs the shell should offer for this page.
function ns:GetMythicPlusTabs()
    local out = {}
    for i, def in ipairs(tabDefs) do
        out[i] = { id = def.id, label = def.label, width = 96 }
    end
    return out
end

-- Temporary slash command to toggle the fake-group test mode.
-- TODO: remove once real data flows cover all the layout edge cases.
SLASH_YYHMPLUSTEST1 = "/yyhmplustest"
SlashCmdList.YYHMPLUSTEST = function()
    testMode = not testMode
    print("|cff00ff00YippYapp|r M+ test mode: " .. (testMode and "ON" or "OFF"))
    if frame:IsShown() and ns.RefreshMythicPlus then ns:RefreshMythicPlus() end
end

local function UpdateTabHighlights()
    for id, tab in pairs(tabButtons) do
        if id == activeTab then ns.SetTabActive(tab)
        else ns.SetTabInactive(tab) end
    end
end

------------------------------------------------------------
-- The vault strip used to live here.
--
-- Removed rather than restyled: the dashboard already draws the Great
-- Vault, in more detail and where a player looks for it, so this was
-- the same three numbers a second time -- and it was charging a whole
-- row of height for them on the page with the worst vertical pressure
-- in the addon. That row now goes to the cards, which is what was
-- overflowing.
--
-- Nothing is left behind to hide. A frame kept only as an anchor for
-- the Guild tab's Refresh button is how the last dead thing on this
-- page survived three sweeps.
------------------------------------------------------------


------------------------------------------------------------
-- Content area (below tabs)
------------------------------------------------------------
-- A surface under the content area (standalone window only -- app mode
-- hides it, because the shell's content region already is one).
--
-- Creation order does not put it behind anything. That is true of
-- regions inside one frame, not of sibling FRAMES, and frame level beats
-- draw layer -- so this has to say outright that it is below the frame
-- whose content it backs. Same mistake, four times, elsewhere in the
-- addon.
local contentSurface = ns.Widgets and ns.Widgets:Panel(frame, "inset")
if contentSurface then
    contentSurface:SetPoint("TOPLEFT", PAD - 8, TAB_Y - TAB_H + 2)
    contentSurface:SetPoint("BOTTOMRIGHT", -PAD + 8, PAD - 6)
    contentSurface:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
end

local content = CreateFrame("Frame", nil, frame)
content:SetPoint("TOPLEFT", PAD, TAB_Y - TAB_H - 4)
content:SetPoint("BOTTOMRIGHT", -PAD, PAD)

------------------------------------------------------------
-- Object pools
------------------------------------------------------------
local fsPool = {}
local fsPoolIdx = 0

local function AcquireFS(parent, template)
    fsPoolIdx = fsPoolIdx + 1
    local fs = fsPool[fsPoolIdx]
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
        fsPool[fsPoolIdx] = fs
    else
        fs:SetFontObject(template or "GameFontNormalSmall")
        fs:SetParent(parent)
    end
    fs:SetTextColor(1, 1, 1)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:SetWidth(0)  -- reset; callers may SetWidth after acquiring
    fs:ClearAllPoints()
    fs:Show()
    return fs
end

local texPool = {}
local texPoolIdx = 0

-- Exposed for Tools/loadcheck.py, like _sections below and for a reason
-- the sections could not cover: the geometry check reads card frames,
-- and the group's keystone rows are raw textures drawn straight onto the
-- content frame. So the check passed while a fourth keystone was being
-- drawn through the bottom of the page and into the tab strip.
frame._texs = texPool

local function AcquireTex(parent)
    texPoolIdx = texPoolIdx + 1
    frame._texCount = texPoolIdx
    local tex = texPool[texPoolIdx]
    if not tex then
        tex = parent:CreateTexture(nil, "ARTWORK")
        texPool[texPoolIdx] = tex
    else
        tex:SetParent(parent)
    end
    tex:ClearAllPoints()
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetAlpha(1)
    tex:SetDesaturated(false)
    tex:SetDrawLayer("ARTWORK", 0)
    tex:Show()
    return tex
end

-- Regular buttons (player cards, vault, etc.)
local btnPool = {}
local btnPoolIdx = 0

local function AcquireBtn(parent)
    btnPoolIdx = btnPoolIdx + 1
    local btn = btnPool[btnPoolIdx]
    if not btn then
        btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
        btnPool[btnPoolIdx] = btn
    else
        btn:SetParent(parent)
    end
    btn:ClearAllPoints()
    -- Re-levelled on every acquire, not just on creation. A pooled frame
    -- carries whatever level it last had, and SetParent re-deriving it
    -- is not something to depend on.
    btn:SetFrameLevel((parent:GetFrameLevel() or 1) + 1)
    btn:SetScript("OnClick", nil)
    btn:SetScript("OnEnter", nil)
    btn:SetScript("OnLeave", nil)
    btn:Show()
    return btn
end

-- Secure buttons (dungeon icon teleport tiles)
local secBtnPool = {}
local secBtnPoolIdx = 0

local function AcquireSecureBtn(parent)
    secBtnPoolIdx = secBtnPoolIdx + 1
    local btn = secBtnPool[secBtnPoolIdx]
    if not btn then
        btn = CreateFrame("Button", nil, parent, "BackdropTemplate,SecureActionButtonTemplate")
        btn:RegisterForClicks("AnyUp", "AnyDown")
        secBtnPool[secBtnPoolIdx] = btn
    else
        btn:SetParent(parent)
    end
    btn:ClearAllPoints()
    if not InCombatLockdown() then
        btn:SetAttribute("type", nil)
        btn:SetAttribute("macrotext", nil)
    end
    btn:SetScript("OnEnter", nil)
    btn:SetScript("OnLeave", nil)
    btn:SetScript("PostClick", nil)
    -- Cast art left over from whichever dungeon this frame showed last
    -- time. An in-flight cast is re-targeted by the driver on its next
    -- frame; this is only so nothing stale is on screen in between.
    if btn._castSweep then btn._castSweep:Hide() end
    if btn._castFlash then
        btn._castFlash:SetAlpha(0)
        btn._castFlash:Hide()
    end
    btn:Show()
    return btn
end

-- Section cards, pooled like everything else on the page.
--
-- The bottom of the Home view drew a bare 1px rule across the page and
-- then two grey labels under it -- a line, and separately some text near
-- it. SectionCard makes that rule the top edge of the card its content
-- sits on, which is the shape the rest of the addon now uses.
local secPool, secPoolIdx = {}, 0

-- Exposed for Tools/loadcheck.py, which reads the cards' real
-- coordinates back off a render rather than reconstructing them. Same
-- contract the Best in Slot page publishes for the same check.
frame._sections = secPool

local function AcquireSection(parent)
    secPoolIdx = secPoolIdx + 1
    local sec = secPool[secPoolIdx]
    if not sec then
        sec = ns.Widgets:SectionCard(parent)
        secPool[secPoolIdx] = sec
    else
        sec:SetParent(parent)
    end
    sec:ClearAllPoints()
    sec:SetValue("")
    sec:Show()
    frame._sectionCount = secPoolIdx
    return sec
end

-- Which tile is currently showing which dungeon, so a cast event can
-- find the tile it belongs to. Rebuilt every render: these are pooled
-- frames, and the one showing Kings' Rest this time is not necessarily
-- the one that showed it last time.
local tilesByDungeon = {}

-- Published for Tools/loadcheck.py. The lookup is by name across two
-- tables that are keyed independently -- the client's map names on one
-- side, the teleport table's on the other -- and a mismatch does not
-- error, it just never animates.
frame._tilesByDungeon = tilesByDungeon

local function ResetPools()
    wipe(tilesByDungeon)
    for i = 1, secPoolIdx do secPool[i]:Hide() end
    secPoolIdx = 0
    frame._sectionCount = 0
    for i = 1, fsPoolIdx do fsPool[i]:Hide() end
    fsPoolIdx = 0
    for i = 1, texPoolIdx do texPool[i]:Hide() end
    texPoolIdx = 0
    frame._texCount = 0
    for i = 1, btnPoolIdx do btnPool[i]:Hide() end
    btnPoolIdx = 0
    for i = 1, secBtnPoolIdx do secBtnPool[i]:Hide() end
    secBtnPoolIdx = 0
end

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
-- Four fake teammates (self is prepended separately in test mode).
local TEST_MEMBERS = {
    { name = "Tankicus",   class = "WARRIOR",     unit = "player" },
    { name = "Healzorz",   class = "PRIEST",      unit = "player" },
    { name = "Sneakybois", class = "ROGUE",       unit = "player" },
    { name = "Evoksnoke",  class = "EVOKER",      unit = "player" },
}

-- Deterministic stand-in map/level pairs for the 4 test teammates.
local TEST_KEYSTONES = {
    { mapID = 2811, level = 10 }, -- Magisters' Terrace
    { mapID = 658,  level = 14 }, -- Pit of Saron
    { mapID = 1209, level = 11 }, -- Skyreach
    { mapID = 2805, level = 13 }, -- Windrunner Spire
}

local function GetGroupMembers()
    if testMode then
        local out = {}
        -- Real player first so their own keystone + real scores are preserved.
        table.insert(out, {
            name = UnitName("player"),
            class = select(2, UnitClass("player")),
            unit = "player",
        })
        for i, m in ipairs(TEST_MEMBERS) do
            table.insert(out, { name = m.name, class = m.class, unit = m.unit, _testIdx = i })
        end
        return out
    end

    local members = {}
    local playerName = UnitName("player")
    local _, playerClass = UnitClass("player")

    table.insert(members, { name = playerName, class = playerClass, unit = "player" })

    local numGroup = GetNumGroupMembers()
    if numGroup <= 1 then return members end

    -- Always use the 5-man party slots regardless of whether the character
    -- is currently in a raid. M+ group views should only show the key group.
    do
        for i = 1, 4 do
            local unit = "party" .. i
            local name = UnitName(unit)
            local _, class = UnitClass(unit)
            if name then
                table.insert(members, { name = name, class = class, unit = unit })
            end
        end
    end

    return members
end

--- The dungeon's own art, with the teleport spell icon only as a
--- fallback.
---
--- Every list on this page had it the other way round, and the Focus
--- rows are where it showed: a dungeon whose teleport this character has
--- not earned resolves to the same generic Hero's Path glyph, so three
--- of four rows in the column that exists to tell dungeons apart carried
--- one identical icon. The tiles along the top never had the problem
--- because they use map.icon, which is this.
local function DungeonIcon(mapID)
    local _, _, _, mapTex = C_ChallengeMode.GetMapUIInfo(mapID)
    if mapTex then return mapTex end
    local spellID = ns:GetDungeonTeleportSpell(mapID)
    return (spellID and C_Spell.GetSpellTexture(spellID)) or 134400
end

local tooltip = GameTooltip

------------------------------------------------------------
-- Teleport cast feedback
------------------------------------------------------------
-- A secure button gives back no signal at all: the click either starts a
-- cast or is swallowed in silence -- in combat, on cooldown, or the
-- teleport simply not learned. That was survivable while the window was
-- small and the tile sat under the cursor. Across a full-width page the
-- tile is nowhere near where the eye ends up, and a dead click is
-- indistinguishable from a missed one.
--
-- Driven off the cast events and not off the click, deliberately. The
-- click is not the interesting event; whether a cast actually started
-- is, and those two come apart often enough to be worth the difference.
local castToast, castToastSeq = nil, 0

local function EnsureCastToast()
    if castToast then return castToast end

    -- On UIParent, not on the page.
    --
    -- Parented to the page it could only ever appear while that page was
    -- open, which is precisely when it is least needed -- and a teleport
    -- is very often cast from the Teleports page, or from a bar, with
    -- Mythic+ nowhere on screen. A hidden parent hides its children no
    -- matter what the handler decides, so no guard could have rescued
    -- this; it had to stop being a child.
    local t = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    t:SetSize(280, 44)
    t:SetFrameStrata("DIALOG")
    ns.Widgets:Apply(t, "panel")
    t:Hide()

    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetSize(28, 28)
    t.icon:SetPoint("LEFT", t, "LEFT", 8, 0)
    t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    t.label = t:CreateFontString(nil, "OVERLAY")
    t.label:SetPoint("TOPLEFT", t.icon, "TOPRIGHT", 8, -2)
    t.label:SetPoint("RIGHT", t, "RIGHT", -8, 0)
    t.label:SetJustifyH("LEFT")
    t.label:SetFont(STANDARD_TEXT_FONT, 12, "")

    t.barBg = t:CreateTexture(nil, "ARTWORK")
    t.barBg:SetHeight(6)
    t.barBg:SetPoint("BOTTOMLEFT", t.icon, "BOTTOMRIGHT", 8, 3)
    t.barBg:SetPoint("RIGHT", t, "RIGHT", -8, 0)
    t.barBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)

    t.barFill = t:CreateTexture(nil, "OVERLAY")
    t.barFill:SetHeight(6)
    t.barFill:SetPoint("TOPLEFT", t.barBg, "TOPLEFT", 0, 0)
    t.barFill:SetColorTexture(0.0, 0.83, 1.0, 0.9)

    castToast = t
    frame._castToast = t   -- for Tools/loadcheck.py
    return t
end

--- state is "casting", "done", "failed" or "locked".
local function ShowCastToast(state, dungeonName, icon)
    local t = EnsureCastToast()

    -- Sits under the page when the page is up, so it reads as belonging
    -- to the tiles above it; otherwise clear of the action bars.
    t:ClearAllPoints()
    if frame:IsShown() then
        t:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)
    else
        t:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 180)
    end
    t.icon:SetTexture(icon or 134400)

    castToastSeq = castToastSeq + 1
    local seq = castToastSeq

    if state == "casting" then
        t.label:SetText("Teleporting to |cffffffff" .. dungeonName .. "|r")
        t.barBg:Show()
        t.barFill:Show()
        -- Read off UnitCastingInfo rather than assuming a duration.
        -- These spells do not all share one cast time, and a bar that
        -- finishes before the cast does is worse than no bar.
        t:SetScript("OnUpdate", function(self)
            local _, _, _, startMS, endMS = UnitCastingInfo("player")
            if not startMS or not endMS then
                self:SetScript("OnUpdate", nil)
                return
            end
            local pct = (GetTime() * 1000 - startMS) / math.max(endMS - startMS, 1)
            pct = math.min(math.max(pct, 0), 1)
            self.barFill:SetWidth(math.max((self.barBg:GetWidth() or 1) * pct, 1))
        end)
    else
        t:SetScript("OnUpdate", nil)
        t.barBg:Hide()
        t.barFill:Hide()
        if state == "done" then
            t.label:SetText("|cff00cc00Teleporting to|r |cffffffff" .. dungeonName .. "|r")
        elseif state == "locked" then
            t.label:SetText("|cffff8800Teleport not unlocked|r\n|cff888888" .. dungeonName .. "|r")
        else
            t.label:SetText("|cffff4444Teleport interrupted|r")
        end
        -- Sequence-guarded so a timer from the previous cast cannot
        -- close the toast belonging to the next one.
        C_Timer.After(state == "locked" and 2.5 or 1.5, function()
            if castToastSeq == seq then t:Hide() end
        end)
    end

    t:Show()
end

------------------------------------------------------------
-- The same cast, on the tile that started it
------------------------------------------------------------
-- The toast says what is happening; this says where. Feedback that
-- appears somewhere other than the thing you clicked makes you check
-- whether you clicked the right one, which is most of what the missing
-- feedback cost in the first place.
--
-- Everything is driven from one OnUpdate on one driver frame rather than
-- a script per tile. There is only ever one cast.
local FLASH_TIME = 0.6
local ACCENT_R, ACCENT_G, ACCENT_B = 0.0, 0.83, 1.0

local castTile, castDungeon, castBorder, castFlashLeft = nil, nil, nil, 0

local castDriver = CreateFrame("Frame")
castDriver:Hide()

local function EnsureTileCastArt(tile)
    if tile._castSweep then return end

    -- Grows from the bottom of the tile as the cast runs. Inset by the
    -- same 3px the icon is, so it fills the art and not the border.
    local sweep = tile:CreateTexture(nil, "OVERLAY", nil, 1)
    sweep:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 3, 3)
    sweep:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -3, 3)
    sweep:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.3)
    sweep:SetHeight(1)
    sweep:Hide()
    tile._castSweep = sweep

    -- White, and tinted per outcome at the moment it fires -- one
    -- texture rather than one per colour.
    local flash = tile:CreateTexture(nil, "OVERLAY", nil, 2)
    flash:SetPoint("TOPLEFT", tile, "TOPLEFT", 3, -3)
    flash:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -3, 3)
    flash:SetColorTexture(1, 1, 1, 1)
    flash:SetAlpha(0)
    flash:Hide()
    tile._castFlash = flash
end

-- Hand the tile back the border colour the render gave it. The border
-- carries a meaning of its own -- green means this dungeon matches a
-- keystone in the group -- so the pulse has to be a loan, not a repaint.
--
-- `restore` is false when letting go because the page re-rendered. The
-- render has already painted this tile's border for whatever dungeon it
-- now shows, and putting the saved colour back would overwrite a fresh
-- value with a stale one.
local function ReleaseTile(restore)
    local tile = castTile
    if not tile then return end
    if tile._castSweep then tile._castSweep:Hide() end
    if restore ~= false and castBorder and tile.SetBackdropBorderColor then
        tile:SetBackdropBorderColor(castBorder[1], castBorder[2],
                                    castBorder[3], castBorder[4])
    end
    castTile, castBorder = nil, nil
end

local function AttachTile(tile)
    EnsureTileCastArt(tile)
    castTile = tile
    castBorder = { tile:GetBackdropBorderColor() }
    tile._castSweep:SetHeight(1)
    tile._castSweep:Show()
end

local function StartTileCast(dungeonName)
    ReleaseTile()
    castDungeon, castFlashLeft = dungeonName, 0

    local tile = tilesByDungeon[dungeonName]
    if not tile or not tile:IsShown() then return end
    AttachTile(tile)
    castDriver:Show()
end

local function FinishTileCast(ok)
    if not castTile then
        castDungeon = nil
        return
    end
    if castTile._castSweep then castTile._castSweep:Hide() end

    local flash = castTile._castFlash
    if flash then
        if ok then flash:SetVertexColor(0.25, 1.0, 0.4)
        else flash:SetVertexColor(1.0, 0.25, 0.25) end
        flash:SetAlpha(0.75)
        flash:Show()
    end
    castFlashLeft = FLASH_TIME
    castDungeon = nil
    castDriver:Show()
end

castDriver:SetScript("OnUpdate", function(self, elapsed)
    local tile = castTile
    if not tile then
        self:Hide()
        return
    end

    -- Fading out after the cast ended, one way or the other.
    if castFlashLeft > 0 then
        castFlashLeft = castFlashLeft - elapsed
        local flash = tile._castFlash
        if castFlashLeft <= 0 then
            if flash then flash:SetAlpha(0) flash:Hide() end
            ReleaseTile()
            self:Hide()
        elseif flash then
            flash:SetAlpha(0.75 * (castFlashLeft / FLASH_TIME))
        end
        return
    end

    -- A refresh mid-cast hands this dungeon a different pooled frame, or
    -- none at all. Re-target rather than animating a tile that has since
    -- been recycled onto another dungeon.
    local live = castDungeon and tilesByDungeon[castDungeon]
    if live ~= tile then
        ReleaseTile(false)
        if not live or not live:IsShown() then
            self:Hide()
            return
        end
        AttachTile(live)
        tile = live
    end

    local _, _, _, startMS, endMS = UnitCastingInfo("player")
    if not startMS or not endMS then return end   -- the events end this

    local pct = (GetTime() * 1000 - startMS) / math.max(endMS - startMS, 1)
    pct = math.min(math.max(pct, 0), 1)
    tile._castSweep:SetHeight(math.max((tile:GetHeight() - 6) * pct, 1))

    -- A pulse rather than a solid colour: a static border already means
    -- something here, and movement is what separates "casting now" from
    -- "this one is special".
    local a = 0.55 + 0.45 * math.abs(math.sin(GetTime() * 4))
    tile:SetBackdropBorderColor(ACCENT_R, ACCENT_G, ACCENT_B, a)
end)

local castWatch = CreateFrame("Frame")
-- Published so Tools/loadcheck.py can fire a cast at it. Nothing else
-- reaches this path offline: no event ever arrives, so every line of the
-- toast and the tile animation is otherwise unexecuted.
frame._castWatch = castWatch
castWatch:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
castWatch:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
castWatch:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
castWatch:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
castWatch:SetScript("OnEvent", function(_, event, _, _, spellID)
    -- No check that the page is open. It was here, and it was the whole
    -- bug: LeaveCurrentPage hides this frame the moment you navigate off
    -- Mythic+, so casting a teleport from anywhere else returned on this
    -- line. Every cast the character makes reaches this handler, so the
    -- filter that belongs here is the spell -- and only the spell.
    local dungeon = ns:GetDungeonForTeleportSpell(spellID)
    if not dungeon then return end

    local icon = C_Spell.GetSpellTexture(spellID)
    if event == "UNIT_SPELLCAST_START" then
        ShowCastToast("casting", dungeon, icon)
        StartTileCast(dungeon)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- Also the only event an instant cast fires, so this doubles as
        -- the whole story for one. StartTileCast first so the flash has
        -- a tile to land on even when no START ever arrived.
        if not castTile then StartTileCast(dungeon) end
        ShowCastToast("done", dungeon, icon)
        FinishTileCast(true)
    else
        ShowCastToast("failed", dungeon, icon)
        FinishTileCast(false)
    end
end)

------------------------------------------------------------
-- Refresh
------------------------------------------------------------
-- Guild tab: show guild members' keystones
local function RefreshGuildTab()
    local cw = content:GetWidth()
    if cw < 10 then cw = (ns:GetAppFrameSize()) - PAD * 2 end
    local y = 0

    local hdr = AcquireFS(content, "GameFontNormal")
    hdr:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    hdr:SetFont(STANDARD_TEXT_FONT, 13, "")
    hdr:SetText("|cffbbbbbbGuild Keystones|r")
    y = y - 22

    -- Collect guild keystone data from addon comms
    local guildKeys = {}
    for pName, ks in pairs(ns:GetGuildKeystones()) do
        table.insert(guildKeys, {
            name = pName,
            mapID = ks.mapID,
            level = ks.level,
            dungeonName = ks.name,
        })
    end

    ------------------------------------------------------------
    -- No Refresh button. Opening the tab is the request.
    --
    -- It was parented to the whole window rather than to this tab's
    -- content, and nothing hid it again -- so once the Guild tab had
    -- been opened the button stayed on screen over the Home tab's
    -- dungeon tiles for the rest of the session. That was survivable
    -- while it sat beside the vault strip; removing the strip left it
    -- in the middle of the row.
    --
    -- It is also a button for something the addon can do on its own.
    -- Asking is one throttled addon message, the answers arrive over the
    -- next few seconds, and the panel already redraws when they land --
    -- so the only thing the click ever added was the player knowing they
    -- had to click it.
    --
    -- Throttled here as well as in the library: switching tabs back and
    -- forth should not queue a request per switch, and LibKeystone's own
    -- three seconds is per channel rather than per caller.
    ------------------------------------------------------------
    local now = GetTime()
    if (now - (frame._lastGuildAsk or 0)) > 10 then
        frame._lastGuildAsk = now
        if ns.RequestGuildKeystones then ns:RequestGuildKeystones() end
        -- Replies land over the next second or two, and nothing else
        -- would redraw this tab once they do.
        C_Timer.After(2, function()
            if ns.RefreshMythicPlus then ns:RefreshMythicPlus() end
        end)
    end

    if #guildKeys == 0 then
        local cx = math.floor(cw / 2)
        local empty = AcquireTex(content)
        empty:SetSize(56, 56)
        empty:SetPoint("TOP", content, "TOP", 0, y - 14)
        empty:SetTexture(525134)  -- INV_Relics_Hourglass (neutral "waiting" feel)
        empty:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        empty:SetVertexColor(0.6, 0.6, 0.6, 0.9)
        empty:SetDrawLayer("ARTWORK", 0)

        local line1 = AcquireFS(content)
        line1:SetPoint("TOP", empty, "BOTTOM", 0, -10)
        line1:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
        line1:SetText("|cffbbbbbbNo guild keystones yet|r")

        local line2 = AcquireFS(content)
        line2:SetPoint("TOP", line1, "BOTTOM", 0, -6)
        line2:SetFont(STANDARD_TEXT_FONT, 11, "")
        line2:SetWidth(cw - 20)
        line2:SetJustifyH("CENTER")
        if IsInGuild() then
            -- No longer "install this addon". Keys now come over
            -- LibKeystone, the shared library BigWigs, DBM and
            -- EllesmereUI all embed, so anyone running any of those
            -- answers whether or not they have ever heard of
            -- YippYapp. Telling a player to go and evangelise an
            -- addon was asking them to fix a problem that was ours.
            line2:SetText("|cff888888Asking the guild now. Anyone running "
                .. "BigWigs, DBM or EllesmereUI answers, and replies arrive over "
                .. "the next few seconds.|r")
        else
            line2:SetText(ns.Widgets:Tint("muted", "You're not in a guild."))
        end
        return
    end

    -- Sort by key level descending
    table.sort(guildKeys, function(a, b) return a.level > b.level end)

    local KS_CARD_W = math.floor((cw - 6) / 2)
    local KS_CARD_H = 34
    local KS_CARD_GAP = 3
    local KS_ICON_SIZE = 26

    for ki, ks in ipairs(guildKeys) do
        local col = (ki - 1) % 2
        local row = math.floor((ki - 1) / 2)
        local kx = col * (KS_CARD_W + 6)
        local ky = y - row * (KS_CARD_H + KS_CARD_GAP)

        local cc = ks.class and RAID_CLASS_COLORS[ks.class]

        -- Card background
        local ksBg = AcquireTex(content)
        ksBg:SetSize(KS_CARD_W, KS_CARD_H)
        ksBg:SetPoint("TOPLEFT", content, "TOPLEFT", kx, ky)
        ksBg:SetColorTexture(0.09, 0.09, 0.09, 0.7)
        ksBg:SetDrawLayer("BACKGROUND", 1)

        -- Class accent
        if cc then
            local ksAccent = AcquireTex(content)
            ksAccent:SetSize(3, KS_CARD_H)
            ksAccent:SetPoint("TOPLEFT", ksBg, "TOPLEFT", 0, 0)
            ksAccent:SetColorTexture(cc.r, cc.g, cc.b, 0.8)
            ksAccent:SetDrawLayer("BACKGROUND", 2)
        end

        -- Dungeon icon
        local ksIcon = AcquireTex(content)
        ksIcon:SetSize(KS_ICON_SIZE, KS_ICON_SIZE)
        ksIcon:SetPoint("LEFT", ksBg, "LEFT", 8, 0)
        ksIcon:SetDrawLayer("ARTWORK", 0)
        ksIcon:SetTexture(DungeonIcon(ks.mapID))
        ksIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        -- Key level
        local ksLvl = AcquireFS(content)
        ksLvl:SetPoint("LEFT", ksIcon, "RIGHT", 5, 0)
        ksLvl:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
        ksLvl:SetText("|cff00d4ff+" .. ks.level .. "|r")

        -- Player name
        local ksName = AcquireFS(content)
        ksName:SetPoint("TOPLEFT", ksIcon, "TOPRIGHT", 42, -1)
        ksName:SetWidth(KS_CARD_W - KS_ICON_SIZE - 56)
        ksName:SetFont(STANDARD_TEXT_FONT, 10, "")
        ksName:SetText(cc and cc:WrapTextInColorCode(ks.name) or ks.name)

        -- Dungeon name
        local ksDung = AcquireFS(content)
        ksDung:SetPoint("BOTTOMLEFT", ksIcon, "BOTTOMRIGHT", 42, 1)
        ksDung:SetWidth(KS_CARD_W - KS_ICON_SIZE - 56)
        ksDung:SetFont(STANDARD_TEXT_FONT, 9, "")
        ksDung:SetText("|cff" .. ns.Widgets:Hex("muted") .. ks.dungeonName .. "|r")
    end
end

-- Redrawing this page re-parents, re-anchors and re-attributes the
-- dungeon teleport tiles, and those are SecureActionButtonTemplate
-- frames. Every one of those calls is blocked while the player is in
-- combat, and the block is SILENT: the client suppresses the "interface
-- action failed" message unless scriptErrors is on, so the only symptom
-- is a keybind that quietly stops working for the rest of the session.
--
-- GROUP_ROSTER_UPDATE fires on every death and every roster change, so
-- inside a key this ran mid-pull, repeatedly. Defer instead. The page is
-- redrawn the instant combat drops, and nobody reads their vault
-- progress during a boss.
local refreshPending = false

function ns:RefreshMythicPlus()
    if not frame:IsShown() then return end
    if InCombatLockdown() then
        refreshPending = true
        return
    end
    refreshPending = false

    ResetPools()
    UpdateTabHighlights()

    if activeTab == "guild" then
        RefreshGuildTab()
        return
    end

    local cw = content:GetWidth()
    if cw < 10 then cw = (ns:GetAppFrameSize()) - PAD * 2 end

    -- This page does not scroll, so the last card down has to know where
    -- the floor is. Read rather than assumed: the shell hands this page
    -- a very different height on a 450px window than on a 580, and the
    -- difference is several rows' worth.
    local contentH = content:GetHeight()
    if contentH < 10 then
        contentH = select(2, ns:GetAppFrameSize()) - PAD * 2
    end
    local floorY = -contentH
    -- The same budget the layout below spends, published so
    -- Tools/loadcheck.py can check the result against it rather than
    -- against a number of its own.
    frame._contentH = contentH

    local y = 0

    local members = GetGroupMembers()
    local maps = ns:GetSeasonMaps()
    if #maps == 0 then return end
    local partyKeys = ns:GetPartyKeystones()
    local ownSummary = ns:GetUnitMPlusSummary("player")

    -- Collect keystones
    local keystones = {}
    local keyMapIDs = {}

    if testMode then
        -- Real player's real keystone first
        local ownKs = ns:GetOwnKeystone()
        if ownKs then
            table.insert(keystones, {
                name = UnitName("player"),
                class = select(2, UnitClass("player")),
                mapID = ownKs.mapID, level = ownKs.level, dungeonName = ownKs.name,
            })
            keyMapIDs[ownKs.mapID] = true
        end
        -- Then the 4 fake teammates with test keystones
        for _, m in ipairs(members) do
            if m._testIdx then
                local t = TEST_KEYSTONES[m._testIdx]
                if t then
                    local mapName = C_ChallengeMode.GetMapUIInfo(t.mapID) or "Unknown"
                    table.insert(keystones, {
                        name = m.name, class = m.class,
                        mapID = t.mapID, level = t.level, dungeonName = mapName,
                    })
                    keyMapIDs[t.mapID] = true
                end
            end
        end
    else
        local ownKs = ns:GetOwnKeystone()
        if ownKs then
            table.insert(keystones, {
                name = UnitName("player"),
                class = select(2, UnitClass("player")),
                mapID = ownKs.mapID, level = ownKs.level, dungeonName = ownKs.name,
            })
            keyMapIDs[ownKs.mapID] = true
        end
        -- Build a name→class lookup once so the inner loop becomes O(1).
        local membersByName = {}
        for _, m in ipairs(members) do membersByName[m.name] = m.class end
        local selfName = UnitName("player")
        for pName, ks in pairs(partyKeys) do
            if pName ~= selfName then
                table.insert(keystones, {
                    name = pName, class = membersByName[pName],
                    mapID = ks.mapID, level = ks.level, dungeonName = ks.name,
                })
                keyMapIDs[ks.mapID] = true
            end
        end
    end

    local ownRating = ns:GetOwnMPlusRating()

    -- Index keystones by mapID so per-tile OnEnter tooltips don't have to
    -- linearly scan the list on every mouse move.
    local keystonesByMapID = {}
    for _, ks in ipairs(keystones) do
        local bucket = keystonesByMapID[ks.mapID]
        if not bucket then
            bucket = {}
            keystonesByMapID[ks.mapID] = bucket
        end
        bucket[#bucket + 1] = ks
    end

    -- ── Dungeon Icon Headers with names above ──
    local numMaps = math.max(#maps, 1)
    -- Scale icon size to fit available width (leave room for name column)
    local NAME_AREA = 110
    local ICON_GAP = 6
    local maxIconW = math.floor((cw - NAME_AREA - (numMaps - 1) * ICON_GAP) / numMaps)
    -- 96, not 74. maxIconW already works out what the width allows, so
    -- the cap was the only thing stopping the row using it -- eight
    -- dungeons across a 700px page fit comfortably at 74 and left a band
    -- of empty page beside them. The floor stays: below 48 the dungeon
    -- art stops being recognisable, which is the whole point of showing
    -- art rather than a list of names.
    local ICON_SIZE = math.min(96, math.max(maxIconW, 48))
    local totalIconW = numMaps * ICON_SIZE + (numMaps - 1) * ICON_GAP
    local iconStartX = math.max(NAME_AREA, math.floor((cw - totalIconW) / 2))

    -- ── Your character info beside dungeon icons ──
    -- Name + rating on the left, dungeon icons to the right — this IS your row
    local playerName = UnitName("player")
    local _, playerClass = UnitClass("player")
    local playerCC = playerClass and RAID_CLASS_COLORS[playerClass]

    -- Name + rating vertically centered against the icon row (14px names + 74px icons = 88px)
    local iconRowH = 14 + ICON_SIZE  -- dungeon names + icons
    local nameBlockH = 28  -- approx height of name + rating
    local nameOffsetY = math.floor((iconRowH - nameBlockH) / 2)

    -- Class color accent bar for own row
    if playerCC then
        local myAccent = AcquireTex(content)
        myAccent:SetSize(3, iconRowH)
        myAccent:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        myAccent:SetColorTexture(playerCC.r, playerCC.g, playerCC.b, 0.8)
        myAccent:SetDrawLayer("BACKGROUND", 2)
    end

    local myNameFs = AcquireFS(content)
    myNameFs:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y - nameOffsetY)
    myNameFs:SetWidth(iconStartX - 16)
    myNameFs:SetFont(STANDARD_TEXT_FONT, 14, "")
    myNameFs:SetText(playerCC and playerCC:WrapTextInColorCode(playerName) or playerName)

    local myRatingFs = AcquireFS(content)
    myRatingFs:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y - nameOffsetY - 16)
    myRatingFs:SetFont(STANDARD_TEXT_FONT, 12, "")
    if ownRating > 0 then
        local rr, rg, rb = ns:GetRatingColor(ownRating)
        myRatingFs:SetText(tostring(ownRating))
        myRatingFs:SetTextColor(rr, rg, rb)
    else
        myRatingFs:SetText("No rating")
        myRatingFs:SetTextColor(0.35, 0.35, 0.35)
    end

    -- Dungeon names above icons
    for i, map in ipairs(maps) do
        local ix = iconStartX + (i - 1) * (ICON_SIZE + ICON_GAP)
        local nameFs = AcquireFS(content)
        nameFs:SetPoint("TOPLEFT", content, "TOPLEFT", ix, y)
        nameFs:SetWidth(ICON_SIZE)
        nameFs:SetJustifyH("CENTER")
        nameFs:SetFont(STANDARD_TEXT_FONT, 10, "")
        -- Two-word names: show first word on top, rest below
        local short = map.name
        -- Trim "The " prefix
        if short:sub(1, 4) == "The " then short = short:sub(5) end
        -- If more than ~10 chars, abbreviate
        if #short > 12 then
            -- Take first word + initial of rest
            local first = short:match("^(%S+)") or short
            if #first < #short then
                short = first
            end
        end
        if keyMapIDs[map.mapID] then
            nameFs:SetText("|cff00cc00" .. short .. "|r")
        else
            nameFs:SetText("|cff" .. ns.Widgets:Hex("muted") .. short .. "|r")
        end
    end
    y = y - 14

    -- Icons
    for i, map in ipairs(maps) do
        local ix = iconStartX + (i - 1) * (ICON_SIZE + ICON_GAP)

        local runData = ownSummary and ownSummary.runs[map.mapID]
        local score = runData and runData.score or 0
        local level = runData and runData.level or 0
        local canTele = ns:CanTeleportToDungeon(map.mapID)

        local tile = AcquireSecureBtn(content)
        tile:SetSize(ICON_SIZE, ICON_SIZE)
        tile:SetPoint("TOPLEFT", content, "TOPLEFT", ix, y)
        -- Keyed by name because that is what a cast event resolves to.
        tilesByDungeon[map.name] = tile
        -- Left on its own backdrop deliberately: transparent fill, and
        -- the border is the signal (this dungeon matches your keystone).
        -- See the matching tile in Features/Teleports/TeleportUI.lua.
        tile:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets   = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        tile:SetBackdropColor(0, 0, 0, 0)

        if keyMapIDs[map.mapID] then
            tile:SetBackdropBorderColor(0.0, 0.8, 0.0, 0.8)
        else
            tile:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
        end

        local icon = AcquireTex(tile)
        icon:SetPoint("TOPLEFT", tile, "TOPLEFT", 3, -3)
        icon:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -3, 3)
        icon:SetTexture(map.icon)
        icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        icon:SetDrawLayer("ARTWORK", 0)
        if not canTele then icon:SetAlpha(0.4) end

        local overlay = AcquireTex(tile)
        overlay:SetAllPoints(icon)
        overlay:SetColorTexture(0, 0, 0, 0.4)
        overlay:SetDrawLayer("ARTWORK", 1)

        -- Key level (top)
        local lvlFs = AcquireFS(tile)
        lvlFs:SetPoint("TOP", tile, "TOP", 0, -8)
        lvlFs:SetJustifyH("CENTER")
        lvlFs:SetWidth(ICON_SIZE)
        local lvlFontSize = math.max(math.floor(ICON_SIZE * 0.27), 12)
        lvlFs:SetFont(STANDARD_TEXT_FONT, lvlFontSize, "OUTLINE")
        lvlFs:SetText(level > 0 and ("|cffffffff" .. level .. "|r") or "")

        -- Score (bottom)
        local scoreFs = AcquireFS(tile)
        scoreFs:SetPoint("BOTTOM", tile, "BOTTOM", 0, 6)
        scoreFs:SetJustifyH("CENTER")
        scoreFs:SetWidth(ICON_SIZE)
        local scoreFontSize = math.max(math.floor(ICON_SIZE * 0.19), 10)
        scoreFs:SetFont(STANDARD_TEXT_FONT, scoreFontSize, "OUTLINE")
        if score > 0 then
            local r, g, b = ns:GetRatingColor(score)
            scoreFs:SetText(tostring(score))
            scoreFs:SetTextColor(r, g, b)
        else
            scoreFs:SetText(ns.Widgets:Tint("faint", "—"))
        end

        -- Tooltip + teleport
        local mapID = map.mapID
        local mapName = map.name
        tile:SetScript("OnEnter", function(self)
            self:SetBackdropColor(1, 1, 1, 0.15)
            tooltip:SetOwner(self, "ANCHOR_TOP")
            tooltip:AddLine(mapName, 1, 1, 1)
            if level > 0 then tooltip:AddLine("Best: +" .. level, 0.7, 0.7, 0.7) end
            if score > 0 then
                local r, g, b = ns:GetRatingColor(score)
                tooltip:AddLine("Score: " .. score, r, g, b)
            end
            local bucket = keystonesByMapID[mapID]
            if bucket then
                for _, ks in ipairs(bucket) do
                    local kcc = ks.class and RAID_CLASS_COLORS[ks.class]
                    local kName = kcc and kcc:WrapTextInColorCode(ks.name) or ks.name
                    tooltip:AddLine(kName .. " has +" .. ks.level, 0, 0.8, 0)
                end
            end
            tooltip:AddLine(canTele and "\nClick to teleport" or "\nTeleport not unlocked",
                canTele and 0 or 0.5, canTele and 0.8 or 0.5, canTele and 0 or 0.5)
            tooltip:Show()
        end)
        tile:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0, 0, 0, 0)
            tooltip:Hide()
        end)

        -- Secure teleport via macro attribute
        local tileIcon = map.icon
        if canTele then
            local spellName = C_Spell.GetSpellName(ns:GetDungeonTeleportSpell(mapID))
            if spellName then
                tile:SetAttribute("type", "macro")
                tile:SetAttribute("macrotext", "/cast " .. spellName)
            end
        end

        -- A tile whose teleport is not learned carries no macrotext, so
        -- the click does nothing and nothing says why -- which looks
        -- exactly like a broken button. PostClick sits outside the
        -- secure path, so it is free to answer.
        tile:SetScript("PostClick", function()
            if not canTele then
                ShowCastToast("locked", mapName, tileIcon)
            end
        end)
    end

    y = y - (ICON_SIZE + 6)

    -- ── Group Member Cards (skip self — already shown as dungeon icons) ──
    local CARD_H = 38
    local CARD_GAP = 4
    local CELL_W = ICON_SIZE
    local CELL_H = CARD_H - 4

    -- Build group member list (excluding self). In test mode, include the
    -- fake teammates (those marked with _testIdx) but still skip the real
    -- player since they're already shown in the row above.
    local groupMembers = {}
    for _, member in ipairs(members) do
        if member._testIdx or (not testMode and member.unit ~= "player") then
            table.insert(groupMembers, member)
        end
    end

    for _, member in ipairs(groupMembers) do
        local summary
        if testMode and member._testIdx then
            -- Synthesize per-dungeon run data so the cells populate with
            -- plausible scores for layout preview.
            local runs = {}
            local seed = member._testIdx
            for mi, map in ipairs(maps) do
                local lvl = 8 + ((seed + mi) % 7)
                local score = 100 + lvl * 15 + (seed * 7)
                runs[map.mapID] = { score = score, level = lvl, success = true }
            end
            summary = { rating = 2400 + member._testIdx * 120, runs = runs }
        else
            summary = member.unit and ns:GetUnitMPlusSummary(member.unit)
        end
        local mRating = summary and summary.rating or 0
        local cc = member.class and RAID_CLASS_COLORS[member.class]

        -- Card background
        local cardBg = AcquireTex(content)
        cardBg:SetHeight(CARD_H)
        cardBg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        cardBg:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
        cardBg:SetColorTexture(0.07, 0.07, 0.07, 0.6)
        cardBg:SetDrawLayer("BACKGROUND", 1)

        -- Class color accent bar
        if cc then
            local accent = AcquireTex(content)
            accent:SetSize(3, CARD_H)
            accent:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            accent:SetColorTexture(cc.r, cc.g, cc.b, 0.8)
            accent:SetDrawLayer("BACKGROUND", 2)
        end

        -- Name
        local nfs = AcquireFS(content)
        nfs:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y - 3)
        nfs:SetWidth(iconStartX - 16)
        nfs:SetFont(STANDARD_TEXT_FONT, 13, "")
        nfs:SetText(cc and cc:WrapTextInColorCode(member.name) or member.name)

        -- Rating below name
        local rfs = AcquireFS(content)
        rfs:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y - 19)
        rfs:SetFont(STANDARD_TEXT_FONT, 12, "")
        if mRating > 0 then
            local r, g, b = ns:GetRatingColor(mRating)
            rfs:SetText(tostring(mRating))
            rfs:SetTextColor(r, g, b)
        else
            rfs:SetText("No rating")
            rfs:SetTextColor(0.35, 0.35, 0.35)
        end

        -- Score cells aligned under icons
        for mi, map in ipairs(maps) do
            local runData = summary and summary.runs[map.mapID]
            local mScore = runData and runData.score or 0
            local bestLevel = runData and runData.level or 0
            local cx = iconStartX + (mi - 1) * (ICON_SIZE + ICON_GAP)

            -- Cell background
            local cellBg = AcquireTex(content)
            cellBg:SetSize(CELL_W, CELL_H)
            cellBg:SetPoint("TOPLEFT", content, "TOPLEFT", cx, y - 2)
            cellBg:SetDrawLayer("ARTWORK", 0)

            if mScore > 0 then
                local r, g, b = ns:GetRatingColor(mScore)
                cellBg:SetColorTexture(r * 0.3, g * 0.3, b * 0.3, 0.9)
            else
                cellBg:SetColorTexture(0.04, 0.04, 0.04, 0.9)
            end

            -- Red tint for keys we have but player hasn't done
            if keyMapIDs[map.mapID] and mScore == 0 then
                local cellHL = AcquireTex(content)
                cellHL:SetSize(CELL_W + 2, CELL_H + 2)
                cellHL:SetPoint("CENTER", cellBg, "CENTER", 0, 0)
                cellHL:SetColorTexture(0.8, 0.15, 0.15, 0.25)
                cellHL:SetDrawLayer("BACKGROUND", 2)
            end

            -- Key level (top)
            if bestLevel > 0 then
                local lvlFs = AcquireFS(content)
                lvlFs:SetPoint("TOP", cellBg, "TOP", 0, -3)
                lvlFs:SetJustifyH("CENTER")
                lvlFs:SetWidth(CELL_W)
                lvlFs:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
                lvlFs:SetText("|cffffffff" .. bestLevel .. "|r")
            end

            -- Score (bottom)
            local sFs = AcquireFS(content)
            sFs:SetPoint("BOTTOM", cellBg, "BOTTOM", 0, 3)
            sFs:SetJustifyH("CENTER")
            sFs:SetWidth(CELL_W)
            sFs:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
            if mScore > 0 then
                local r, g, b = ns:GetRatingColor(mScore)
                sFs:SetText(tostring(mScore))
                sFs:SetTextColor(r, g, b)
            else
                sFs:SetText(keyMapIDs[map.mapID] and "|cffff4444—|r" or "|cff333333—|r")
            end
        end

        y = y - (CARD_H + CARD_GAP)
    end

    -- ── Bottom: two columns, each flowing its own stack of cards ──
    --
    -- Not a grid. These cards have nothing to say about each other's
    -- heights -- Group Keystones is empty most nights, This Week is
    -- empty every Tuesday -- and a grid makes every card as tall as the
    -- worst one beside it. Two independent cursors let each column close
    -- up behind whatever it actually holds.
    y = y - SECTION_GAP

    local SEC_H = ns.Widgets:SectionTitleHeight()
    local SEC_PAD = 8

    -- Not an even split. The left column is a fixed affix list and short
    -- keystone rows; the right carries three progress bars, the focus
    -- list under them, and the week's runs, and it was the one whose
    -- text had to wrap.
    --
    -- Each column leads with the card that does not change -- affixes
    -- are set for the week, the rating goals are set for the season --
    -- and puts the one that fills up over the week underneath it, where
    -- it has somewhere to grow into.
    local leftX,  leftW  = 0, math.floor(cw * 0.42) - 6
    local rightX = leftW + 12
    local rightW = cw - rightX
    local leftY,  rightY = y, y

    -- Every card below is the same shape: a heading, a card under it,
    -- contents inset by SEC_PAD on all four sides. Written once, because
    -- hand-rolled copies is how the left column ended up flush against
    -- its card edges while the right column beside it was inset 8px --
    -- invisible until the group actually carried a key.
    --
    -- The card is acquired first and sized last: it has to exist before
    -- the rows so it draws behind them, but how tall it needs to be is
    -- not known until they have been laid out.
    local function BeginCard(x, cursorY, title)
        local sec = AcquireSection(content)
        sec:SetPoint("TOPLEFT", content, "TOPLEFT", x, cursorY)
        sec:SetText(ns.Widgets:Tint("muted", title))
        return sec, cursorY - SEC_H - SEC_PAD
    end

    -- Returns where the NEXT card in this column starts. The card's own
    -- bottom edge lands SEC_PAD past the last row, so the gap between
    -- two cards is measured edge to edge rather than from the content
    -- inside them.
    local function EndCard(sec, w, topY, cursorY)
        sec:Layout(w, (topY - cursorY) + SEC_PAD * 2)
        return cursorY - SEC_PAD - SECTION_GAP
    end

    -- The last card in each column runs to the floor instead of stopping
    -- at its contents, so both columns end on the same line and the page
    -- is the size it actually is. Two short cards finishing halfway down
    -- an empty page is what made the old layout read as unfinished.
    --
    -- The card grows; the rows do not spread out. Contents stay at the
    -- top and the slack falls below them, which is also what leaves room
    -- for a card to fill up over the week rather than jumping in height
    -- every time a run lands.
    local function EndCardToFloor(sec, w, topY, cursorY, emptyFs)
        local natural = (topY - cursorY) + SEC_PAD * 2
        -- Body top sits SEC_PAD above topY, so this is its distance to
        -- the bottom of the content region.
        local toFloor = (topY + SEC_PAD) - floorY
        sec:Layout(w, math.max(natural, toFloor))
        -- A stretched card with nothing in it leaves its one line of
        -- text in the top corner of a tall void, which reads as content
        -- that failed to load rather than as an empty section. Centred
        -- on the second pass because the final height is not known until
        -- Layout has run.
        if emptyFs then
            emptyFs:ClearAllPoints()
            emptyFs:SetPoint("CENTER", sec.body, "CENTER", 0, 0)
            emptyFs:SetJustifyH("CENTER")
        end
        return math.min(cursorY - SEC_PAD, floorY)
    end

    ------------------------------------------------------------
    -- Left column, card 1: this week's affixes
    ------------------------------------------------------------
    -- The page has listened for MYTHIC_PLUS_CURRENT_AFFIX_UPDATE since
    -- it was written and never drew the affixes it was refreshing for.
    -- ns:GetCurrentAffixes had no caller anywhere in the addon.
    -- Only the affixes that differ from last week -- in practice the
    -- week's Xal'atath's Bargain. The other four are up every week
    -- (Fortified and Tyrannical included; they are both always present
    -- and only trade keystone levels), and those rows are worth more to
    -- the group's keystones underneath. See ns:GetAffixSplit -- which
    -- ones those are is learned from watching, not written down.
    local affixes, standing, learned = ns:GetAffixSplit()
    local afSec, afTop = BeginCard(leftX, leftY, "Affixes")
    local afY = afTop
    local afInnerX = leftX + SEC_PAD
    local afInnerW = leftW - SEC_PAD * 2

    if #affixes > 0 then
        local AF_ROW_H, AF_ICON = 28, 22
        for _, af in ipairs(affixes) do
            local row = AcquireBtn(content)
            row:SetSize(afInnerW, AF_ROW_H)
            row:SetPoint("TOPLEFT", content, "TOPLEFT", afInnerX, afY)

            local afIcon = AcquireTex(row)
            afIcon:SetSize(AF_ICON, AF_ICON)
            afIcon:SetPoint("LEFT", row, "LEFT", 0, 0)
            afIcon:SetTexture(af.icon or 134400)
            afIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            -- Room held back for the level badge, so a long affix name
            -- ellipsises rather than running under the number.
            local afLvlText = ns.GetAffixLevelText and ns:GetAffixLevelText(af)
            local afName = AcquireFS(row)
            afName:SetPoint("LEFT", afIcon, "RIGHT", 8, 0)
            afName:SetWidth(afInnerW - AF_ICON - 8 - (afLvlText and 52 or 0))
            afName:SetJustifyH("LEFT")
            afName:SetFont(STANDARD_TEXT_FONT, 12, "")
            -- The +10 row names both affixes: from that level Fortified
            -- and Tyrannical stop alternating and are up together, and a
            -- row naming only one of them reads as the other having been
            -- replaced.
            local label = (ns.GetAffixLabel and ns:GetAffixLabel(af, affixes))
                or af.name
            afName:SetText("|cff" .. ns.Widgets:Hex("text") .. label .. "|r")

            -- The keystone levels it applies over. Absent rather than
            -- zeroed when the season's thresholds are not recorded.
            if afLvlText then
                local afLvl = AcquireFS(row)
                afLvl:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                afLvl:SetJustifyH("RIGHT")
                afLvl:SetFont(STANDARD_TEXT_FONT, 11, "")
                afLvl:SetText("|cff00d4ff" .. afLvlText .. "|r")
            end

            -- The description is two or three sentences of rules text.
            -- Inline it and the card's height stops being predictable
            -- from the affix count; on hover it costs no layout at all,
            -- and hovering an affix is where people look for it anyway.
            local hoverName, hoverDesc = af.name, af.desc
            row:SetScript("OnEnter", function(self)
                tooltip:SetOwner(self, "ANCHOR_RIGHT")
                tooltip:AddLine(hoverName, 1, 1, 1)
                if hoverDesc and hoverDesc ~= "" then
                    tooltip:AddLine(hoverDesc, 0.8, 0.8, 0.8, true)
                end
                tooltip:Show()
            end)
            row:SetScript("OnLeave", function() tooltip:Hide() end)

            afY = afY - AF_ROW_H
        end

        -- The rest are hidden, not dropped. One muted line says how many
        -- and holds them on hover, so the card is smaller without the
        -- week's other affixes becoming unreadable from here.
        if learned and #standing > 0 then
            local moreRow = AcquireBtn(content)
            moreRow:SetSize(afInnerW, 16)
            moreRow:SetPoint("TOPLEFT", content, "TOPLEFT", afInnerX, afY)

            local moreFs = AcquireFS(moreRow)
            moreFs:SetPoint("LEFT", moreRow, "LEFT", 0, 0)
            moreFs:SetWidth(afInnerW)
            moreFs:SetFont(STANDARD_TEXT_FONT, 10, "")
            -- "every week", not "seasonal": two of these are Fortified
            -- and Tyrannical, which are not seasonal affixes at all.
            -- What they have in common is only that they are always up.
            moreFs:SetText("|cff" .. ns.Widgets:Hex("faint") .. "+" .. #standing
                .. " every week|r")

            local hidden = {}
            for _, af in ipairs(standing) do
                local lt = ns.GetAffixLevelText and ns:GetAffixLevelText(af)
                hidden[#hidden + 1] = {
                    af.name .. (lt and ("  |cff00d4ff" .. lt .. "|r") or ""),
                    af.desc,
                }
            end
            moreRow:SetScript("OnEnter", function(self)
                tooltip:SetOwner(self, "ANCHOR_RIGHT")
                tooltip:AddLine("Up every week", 1, 1, 1)
                for _, pair in ipairs(hidden) do
                    tooltip:AddLine(" ")
                    tooltip:AddLine(pair[1], 1, 0.82, 0)
                    if pair[2] and pair[2] ~= "" then
                        tooltip:AddLine(pair[2], 0.8, 0.8, 0.8, true)
                    end
                end
                tooltip:Show()
            end)
            moreRow:SetScript("OnLeave", function() tooltip:Hide() end)
            afY = afY - 18
        end
    else
        local noAf = AcquireFS(content)
        noAf:SetPoint("TOPLEFT", content, "TOPLEFT", afInnerX, afY)
        noAf:SetText(ns.Widgets:Tint("faint", "No affixes this week"))
        afY = afY - ROW_H
    end
    leftY = EndCard(afSec, leftW, afTop, afY)

    ------------------------------------------------------------
    -- Right column, card 1: Rating Goals
    ------------------------------------------------------------
    local goalSec, goalTop = BeginCard(rightX, rightY, "Rating Goals")
    local goalY = goalTop
    local goalX = rightX + SEC_PAD
    local goalW = rightW - SEC_PAD * 2

    local MILESTONES = { 2000, 2500, 3000 }
    local ownScore = ownRating

    -- Score-per-key-level table (timed, based on real data)
    local SCORE_BY_LEVEL = {
        [2] = 100, [3] = 120, [4] = 145, [5] = 185,
        [6] = 245, [7] = 275, [8] = 285, [9] = 307, [10] = 330,
        [11] = 350, [12] = 365, [13] = 380, [14] = 395, [15] = 410,
    }

    local function KeyLevelForScore(targetScore)
        for lvl = 2, 15 do
            if (SCORE_BY_LEVEL[lvl] or 0) >= targetScore then return lvl end
        end
        return 15
    end

    local BAR_H = 18
    local BAR_GAP = 6
    -- Use highest milestone as the bar max for consistent scaling
    local barMax = MILESTONES[#MILESTONES]

    ------------------------------------------------------------
    -- Only the goals still ahead.
    --
    -- A full bar reading "2000 Done" is a row spent on something the
    -- player cannot act on, in the card whose whole job is what to do
    -- next -- and it pushed the focus list under it further down a page
    -- that was already running out of room. The rating beside the
    -- player's name says where they are; this says where they are
    -- going.
    --
    -- Every milestone passed still leaves the last one on screen, so a
    -- player at 3000 sees "3000 Done" rather than an empty card. Nothing
    -- left to chase is itself worth one row.
    ------------------------------------------------------------
    local goals = {}
    for _, target in ipairs(MILESTONES) do
        if ownScore < target then goals[#goals + 1] = target end
    end
    if #goals == 0 then goals = { MILESTONES[#MILESTONES] } end

    for _, target in ipairs(goals) do
        local achieved = ownScore >= target
        local r, g, b = ns:GetRatingColor(target)
        local pct = math.min(ownScore / target, 1)

        -- Bar background
        local barBg = AcquireTex(content)
        barBg:SetSize(goalW, BAR_H)
        barBg:SetPoint("TOPLEFT", content, "TOPLEFT", goalX, goalY)
        barBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        barBg:SetDrawLayer("ARTWORK", 0)

        -- Bar fill
        local barFill = AcquireTex(content)
        barFill:SetSize(math.max((goalW - 2) * pct, 1), BAR_H - 2)
        barFill:SetPoint("TOPLEFT", barBg, "TOPLEFT", 1, -1)
        barFill:SetDrawLayer("ARTWORK", 1)

        if achieved then
            barFill:SetColorTexture(r * 0.5, g * 0.5, b * 0.5, 0.8)
        else
            barFill:SetColorTexture(r * 0.35, g * 0.35, b * 0.35, 0.7)
        end

        -- Target label on left of bar
        local targetFs = AcquireFS(content)
        targetFs:SetPoint("LEFT", barBg, "LEFT", 6, 0)
        targetFs:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
        targetFs:SetJustifyH("LEFT")

        if achieved then
            targetFs:SetText(string.format("|cff%02x%02x%02x%d|r  |cff00ff00Done|r",
                r * 255, g * 255, b * 255, target))
        else
            local deficit = target - ownScore
            local targetAvg = math.ceil(target / numMaps)
            local neededLvl = KeyLevelForScore(targetAvg)
            targetFs:SetText(string.format("|cff%02x%02x%02x%d|r",
                r * 255, g * 255, b * 255, target))

            -- Right side: key level hint
            local hintFs = AcquireFS(content)
            hintFs:SetPoint("RIGHT", barBg, "RIGHT", -6, 0)
            hintFs:SetJustifyH("RIGHT")
            hintFs:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
            hintFs:SetText(string.format("|cffaaaaaaall +%d|r", neededLvl))
        end

        goalY = goalY - (BAR_H + BAR_GAP)
    end

    -- Below bars: show weakest dungeons to focus on (for next unachieved milestone)
    for _, target in ipairs(MILESTONES) do
        if ownScore < target then
            local targetAvg = math.ceil(target / numMaps)
            local neededLvl = KeyLevelForScore(targetAvg)
            local tr, tg, tb = ns:GetRatingColor(target)

            -- Gather and sort dungeon scores
            local dungeonScores = {}
            for _, map in ipairs(maps) do
                local runData = ownSummary and ownSummary.runs[map.mapID]
                local score = runData and runData.score or 0
                table.insert(dungeonScores, {
                    name = map.name,
                    score = score,
                    -- map.icon is already the dungeon's art; the lookup
                    -- is only here for a map that arrived without one.
                    icon = map.icon or DungeonIcon(map.mapID),
                })
            end
            table.sort(dungeonScores, function(a, b) return a.score < b.score end)

            goalY = goalY - 2

            local focusHdr = AcquireFS(content)
            focusHdr:SetPoint("TOPLEFT", content, "TOPLEFT", goalX, goalY)
            focusHdr:SetFont(STANDARD_TEXT_FONT, 13, "")
            focusHdr:SetText(string.format("|cffbbbbbbFocus for |cff%02x%02x%02x%d|r",
                tr * 255, tg * 255, tb * 255, target))
            goalY = goalY - 20

            local FOCUS_ROW_H = 24
            local FOCUS_ICON = 20
            local shown = 0
            for _, ds in ipairs(dungeonScores) do
                if ds.score < targetAvg and shown < 4 then
                    shown = shown + 1

                    -- Row background
                    local rowBg = AcquireTex(content)
                    rowBg:SetSize(goalW, FOCUS_ROW_H)
                    rowBg:SetPoint("TOPLEFT", content, "TOPLEFT", goalX, goalY)
                    rowBg:SetColorTexture(0.08, 0.08, 0.08, 0.5)
                    rowBg:SetDrawLayer("BACKGROUND", 1)

                    -- Dungeon icon
                    local dIcon = AcquireTex(content)
                    dIcon:SetSize(FOCUS_ICON, FOCUS_ICON)
                    dIcon:SetPoint("LEFT", rowBg, "LEFT", 4, 0)
                    dIcon:SetTexture(ds.icon or 134400)
                    dIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    dIcon:SetDrawLayer("ARTWORK", 0)

                    -- Dungeon name
                    local short = ds.name
                    if short:sub(1, 4) == "The " then short = short:sub(5) end
                    if #short > 14 then short = short:match("^(%S+)") or short end

                    local nameFs = AcquireFS(content)
                    nameFs:SetPoint("LEFT", dIcon, "RIGHT", 5, 0)
                    nameFs:SetFont(STANDARD_TEXT_FONT, 11, "")
                    nameFs:SetWidth(goalW - FOCUS_ICON - 70)
                    nameFs:SetText("|cff" .. ns.Widgets:Hex("text") .. short .. "|r")

                    -- Target key level on right
                    local lvlFs = AcquireFS(content)
                    lvlFs:SetPoint("RIGHT", rowBg, "RIGHT", -6, 0)
                    lvlFs:SetJustifyH("RIGHT")
                    lvlFs:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")

                    if ds.score > 0 then
                        local cr, cg, cb = ns:GetRatingColor(ds.score)
                        lvlFs:SetText(string.format("|cff%02x%02x%02x%d|r |cff666666>|r |cff00d4ff+%d|r",
                            cr * 255, cg * 255, cb * 255, ds.score, neededLvl))
                    else
                        lvlFs:SetText(string.format("|cffff4444-|r |cff666666>|r |cff00d4ff+%d|r", neededLvl))
                    end

                    goalY = goalY - (FOCUS_ROW_H + 2)
                end
            end

            break  -- only show focus for the next unachieved milestone
        end
    end
    rightY = EndCard(goalSec, rightW, goalTop, goalY)

    ------------------------------------------------------------
    -- Right column, card 2: This Week
    ------------------------------------------------------------
    local weekRuns = ns:GetWeeklyRuns()
    -- Where the This Week card starts. Group Keystones is drawn after
    -- this one so it can begin at the same line, which it cannot do
    -- while it runs first -- the right column's height is not known
    -- until Rating Goals has been laid out.
    local wkCardTop = rightY
    local wkSec, wkTop = BeginCard(rightX, rightY, "This Week")
    local wkY = wkTop
    local wkInnerX = rightX + SEC_PAD
    local wkInnerW = rightW - SEC_PAD * 2
    local wkEmptyFs

    if #weekRuns > 0 then
        local WK_ICON = 18
        -- Two heights: one line, or one with score, margin and deaths
        -- under it. Which is used is decided below, once it is known
        -- how many runs there are to fit.
        local WK_ROW_PLAIN, WK_ROW_DETAIL = 22, 33

        -- Shared with the hover text, so the margin on the row and the
        -- margin in the tooltip cannot come out formatted two ways.
        local function Clock(sec) return ns:ClockText(sec) end

        -- Eight is what the vault counts and what a full week looks
        -- like; past that the list is history rather than information.
        --
        -- But this is the last card down a column on a page that does
        -- not scroll, so the real ceiling is whatever room is left under
        -- everything above it. Rows are no longer a fixed height, so the
        -- budget is spent row by row rather than divided up front.
        local room = wkY - floorY - (SEC_PAD * 2 + 18)

        wkSec:SetValue(ns.Widgets:Tint("faint",
            #weekRuns .. (#weekRuns == 1 and " run" or " runs")))

        -- Second lines are what spare room buys, and the week comes
        -- first: a night of twelve runs fills the card with rows rather
        -- than pushing four of them off it to make space for margins
        -- and score. Nothing is lost either way -- the hover says all
        -- of it, on every row.
        local detailed = (#weekRuns * (WK_ROW_DETAIL + 2)) <= room

        local shown = 0
        for i = 1, #weekRuns do
            local run = weekRuns[i]
            local d = run.detail

            -- The second line, worked out before the row is drawn,
            -- because whether there is one decides how tall it is.
            local bits = {}
            if run.gain and run.gain > 0 then
                bits[#bits + 1] = "|cffffd100+" .. run.gain .. "|r score"
            end
            if run.durationSec and run.limit and run.limit > 0 then
                local delta = run.limit - run.durationSec
                if delta >= 0 then
                    bits[#bits + 1] = Clock(delta) .. " under"
                else
                    bits[#bits + 1] = "|cffff6644" .. Clock(delta) .. "|r over"
                end
            end
            if d and (d.deaths or 0) > 0 then
                bits[#bits + 1] = d.deaths
                    .. (d.deaths == 1 and " death" or " deaths")
            end

            local rowH = (detailed and #bits > 0) and WK_ROW_DETAIL or WK_ROW_PLAIN
            -- Room is the only limit. There used to be a hard cap of
            -- eight on the grounds that eight is what the vault counts,
            -- but the card runs to the bottom of the page now and a
            -- "+3 more this week" under half a screen of empty card is
            -- withholding rows it has the space to draw.
            if room < rowH + 2 then break end
            room = room - (rowH + 2)
            shown = shown + 1

            local rowBg = AcquireTex(content)
            rowBg:SetSize(wkInnerW, rowH)
            rowBg:SetPoint("TOPLEFT", content, "TOPLEFT", wkInnerX, wkY)
            rowBg:SetColorTexture(0.08, 0.08, 0.08, 0.5)
            rowBg:SetDrawLayer("BACKGROUND", 1)

            local rIcon = AcquireTex(content)
            rIcon:SetSize(WK_ICON, WK_ICON)
            rIcon:SetPoint("TOPLEFT", rowBg, "TOPLEFT", 3, -2)
            rIcon:SetTexture(DungeonIcon(run.mapID))
            rIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            rIcon:SetDrawLayer("ARTWORK", 0)

            local short = run.name
            if short:sub(1, 4) == "The " then short = short:sub(5) end

            local rName = AcquireFS(content)
            rName:SetPoint("TOPLEFT", rIcon, "TOPRIGHT", 5, -3)
            rName:SetWidth(wkInnerW - WK_ICON - 96)
            rName:SetJustifyH("LEFT")
            rName:SetFont(STANDARD_TEXT_FONT, 11, "")
            rName:SetText("|cff" .. ns.Widgets:Hex("text") .. short .. "|r")

            local rLvl = AcquireFS(content)
            rLvl:SetPoint("TOPRIGHT", rowBg, "TOPRIGHT", -6, -4)
            rLvl:SetJustifyH("RIGHT")
            rLvl:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")

            if run.timed ~= nil then
                -- The keystone's own verdict. Chests are the levels the
                -- key gained, and a run can beat the timer by too little
                -- to gain any, so "in time" has to be its own case
                -- rather than "0 chest".
                if run.timed then
                    local chest = (run.chests or 0) > 0
                        and (run.chests .. " chest") or "in time"
                    rLvl:SetText(string.format("|cff00d4ff+%d|r  |cff00cc00%s|r",
                        run.level, chest))
                else
                    rLvl:SetText(string.format("|cff888888+%d|r  |cffff6644over time|r",
                        run.level))
                end
            elseif run.completed then
                -- No duration on this entry, so the only fact left is
                -- the vault's: a finished key filled a slot whether or
                -- not it beat the timer, and saying more would be
                -- inventing a result.
                rLvl:SetText(string.format("|cff00d4ff+%d|r  |cff777777finished|r",
                    run.level))
            else
                rLvl:SetText(string.format("|cff888888+%d|r  |cffff4444depleted|r",
                    run.level))
            end

            if detailed and #bits > 0 then
                local rSub = AcquireFS(content)
                rSub:SetPoint("TOPLEFT", rIcon, "BOTTOMRIGHT", 5, -1)
                rSub:SetPoint("RIGHT", rowBg, "RIGHT", -6, 0)
                rSub:SetJustifyH("LEFT")
                rSub:SetFont(STANDARD_TEXT_FONT, 9, "")
                rSub:SetText("|cff" .. ns.Widgets:Hex("muted")
                    .. table.concat(bits, "  ") .. "|r")
            end

            -- The row in full, on hover. The line on the card is as much
            -- as fits beside a dungeon name; the clock time, the par it
            -- was measured against, when the run happened and what it
            -- was worth live here instead of being cut.
            local hover = AcquireBtn(content)
            hover:SetSize(wkInnerW, rowH)
            hover:SetPoint("TOPLEFT", rowBg, "TOPLEFT", 0, 0)
            hover:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            hover:SetBackdropColor(1, 1, 1, 0)
            local lines = ns:DescribeRun(run)
            hover:SetScript("OnEnter", function(self)
                self:SetBackdropColor(1, 1, 1, 0.06)
                tooltip:SetOwner(self, "ANCHOR_RIGHT")
                for _, line in ipairs(lines) do
                    if line.blank then
                        tooltip:AddLine(" ")
                    else
                        tooltip:AddLine(line.text, line.r, line.g, line.b)
                    end
                end
                tooltip:Show()
            end)
            hover:SetScript("OnLeave", function(self)
                self:SetBackdropColor(1, 1, 1, 0)
                tooltip:Hide()
            end)

            wkY = wkY - (rowH + 2)
        end

        if #weekRuns > shown then
            local more = AcquireFS(content)
            more:SetPoint("TOPLEFT", content, "TOPLEFT", wkInnerX + 3, wkY - 2)
            more:SetFont(STANDARD_TEXT_FONT, 10, "")
            more:SetText(ns.Widgets:Tint("faint",
                string.format("+%d more this week", #weekRuns - shown)))
            wkY = wkY - 16
        end
    else
        wkEmptyFs = AcquireFS(content)
        wkEmptyFs:SetPoint("TOPLEFT", content, "TOPLEFT", wkInnerX, wkY)
        wkEmptyFs:SetText(ns.Widgets:Tint("faint", "No runs since the reset"))
        wkY = wkY - ROW_H
    end
    rightY = EndCardToFloor(wkSec, rightW, wkTop, wkY, wkEmptyFs)

    ------------------------------------------------------------
    -- Left column, card 2: Group Keystones
    --
    -- Drawn last, but positioned beside This Week rather than
    -- under the affixes. Both columns' second card starts on the
    -- same line that way, instead of the left one floating up
    -- wherever the affix card happened to end.
    ------------------------------------------------------------
    local ksSec, ksTop = BeginCard(leftX, wkCardTop, "Group Keystones")
    local ksY = ksTop
    local ksInnerX = leftX + SEC_PAD
    local ksInnerW = leftW - SEC_PAD * 2
    local ksEmptyFs

    if #keystones > 0 then
        ------------------------------------------------------------
        -- Sized to what is actually in the group, not to what used to
        -- be.
        --
        -- The rows were drawn at one fixed height however many there
        -- were, while the card around them stops at the bottom of the
        -- page -- so a group holding four keys ran the fourth one out
        -- through the floor and into the tab strip underneath.
        --
        -- Invisible until the keys started arriving. This list only ever
        -- saw other YippYapp users, so in practice it held one entry or
        -- none; moving keystone sharing onto LibKeystone filled it up
        -- and the layout met a full group for the first time.
        --
        -- Two presets, the way the This Week card beside it already
        -- picks between a plain row and a detailed one: the roomy row
        -- while it fits, a tighter one when it does not. Five is the
        -- most a group can ever hold, so the tight preset is the end of
        -- it -- the truncation below is a backstop against a short page,
        -- not the normal path.
        ------------------------------------------------------------
        local ROOMY = { h = 36, gap = 3, icon = 28, lvl = 18, name = 10, dung = 9 }
        local TIGHT = { h = 27, gap = 2, icon = 21, lvl = 14, name =  9, dung = 8 }

        local room = ksY - floorY
        local function fitCount(p) return math.floor((room + p.gap) / (p.h + p.gap)) end

        local pre = ROOMY
        if fitCount(ROOMY) < #keystones then pre = TIGHT end

        local KS_CARD_H   = pre.h
        local KS_CARD_GAP = pre.gap
        local KS_ICON_SIZE = pre.icon
        local ksCardW = ksInnerW

        -- Still short? Then say so rather than stopping mid-list. A list
        -- that quietly ends at three reads as "the group holds three
        -- keys", which is a different and wrong fact -- and the count in
        -- the card's own heading would contradict it.
        local MORE_H = 13
        local shown = #keystones
        local fits = fitCount(pre)
        if shown > fits then shown = math.max(fits - 1, 1) end

        for ki = 1, shown do
            local ks = keystones[ki]
            local cc = ks.class and RAID_CLASS_COLORS[ks.class]

            local ksBg = AcquireTex(content)
            ksBg:SetSize(ksCardW, KS_CARD_H)
            ksBg:SetPoint("TOPLEFT", content, "TOPLEFT", ksInnerX, ksY)
            ksBg:SetColorTexture(0.09, 0.09, 0.09, 0.7)
            ksBg:SetDrawLayer("BACKGROUND", 1)

            if cc then
                local ksAccent = AcquireTex(content)
                ksAccent:SetSize(3, KS_CARD_H)
                ksAccent:SetPoint("TOPLEFT", ksBg, "TOPLEFT", 0, 0)
                ksAccent:SetColorTexture(cc.r, cc.g, cc.b, 0.8)
                ksAccent:SetDrawLayer("BACKGROUND", 2)
            end

            local ksIcon = AcquireTex(content)
            ksIcon:SetSize(KS_ICON_SIZE, KS_ICON_SIZE)
            ksIcon:SetPoint("LEFT", ksBg, "LEFT", 8, 0)
            ksIcon:SetDrawLayer("ARTWORK", 0)
            ksIcon:SetTexture(DungeonIcon(ks.mapID))
            ksIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            local ksLvl = AcquireFS(content)
            ksLvl:SetPoint("LEFT", ksIcon, "RIGHT", 6, 0)
            ksLvl:SetFont(STANDARD_TEXT_FONT, pre.lvl, "OUTLINE")
            ksLvl:SetText("|cff00d4ff+" .. ks.level .. "|r")

            local ksName = AcquireFS(content)
            ksName:SetPoint("TOPLEFT", ksIcon, "TOPRIGHT", 58, -1)
            ksName:SetWidth(ksCardW - KS_ICON_SIZE - 74)
            ksName:SetFont(STANDARD_TEXT_FONT, pre.name, "")
            ksName:SetText(cc and cc:WrapTextInColorCode(ks.name) or ks.name)

            local ksDung = AcquireFS(content)
            ksDung:SetPoint("BOTTOMLEFT", ksIcon, "BOTTOMRIGHT", 58, 1)
            ksDung:SetWidth(ksCardW - KS_ICON_SIZE - 74)
            ksDung:SetFont(STANDARD_TEXT_FONT, pre.dung, "")
            ksDung:SetText("|cff" .. ns.Widgets:Hex("muted") .. ks.dungeonName .. "|r")

            ksY = ksY - (KS_CARD_H + KS_CARD_GAP)
        end

        if shown < #keystones then
            local moreFs = AcquireFS(content)
            moreFs:SetPoint("TOPLEFT", content, "TOPLEFT", ksInnerX, ksY)
            moreFs:SetWidth(ksCardW)
            moreFs:SetFont(STANDARD_TEXT_FONT, 9, "")
            moreFs:SetText(ns.Widgets:Tint("faint",
                "+" .. (#keystones - shown) .. " more, no room to show"))
            ksY = ksY - MORE_H
        end
    else
        ksEmptyFs = AcquireFS(content)
        ksEmptyFs:SetPoint("TOPLEFT", content, "TOPLEFT", ksInnerX, ksY)
        ksEmptyFs:SetText(ns.Widgets:Tint("faint", "No keystones in group"))
        ksY = ksY - ROW_H
    end
    if #keystones > 0 then ksSec:SetValue(tostring(#keystones)) end
    -- Floored, so it runs to the bottom of the page alongside This
    -- Week. Hugging its content left a short box beside a tall one,
    -- which reads as the card having failed to draw rather than as
    -- the group holding one key.
    leftY = EndCardToFloor(ksSec, leftW, ksTop, ksY, ksEmptyFs)

    -- Past whichever column ran longer: the two sit side by side and
    -- anything added below has to clear both.
    y = math.min(leftY, rightY)
end

------------------------------------------------------------
-- App mode (embedded in AppFrame)
------------------------------------------------------------
function ns:SetMythicPlusAppMode(enabled, contentWidth, contentHeight)
    if enabled then
        ns.Widgets:Unskin(frame)
        closeBtn:Hide()
        -- The shell's strip replaces this one.
        for _, tab in pairs(tabButtons) do tab:Hide() end
        titleFs:Hide()
        frame:SetMovable(false)
        frame:EnableMouse(false)
        local dw, dh = ns:GetAppFrameSize()
        frame:SetSize(contentWidth or dw, contentHeight or (dh - 34))

        -- The page's own Home/Guild tabs stay hidden. They were hidden
        -- four lines above and then re-anchored and re-shown right here,
        -- which is why the page carried two identical tab rows: the
        -- shell draws one from the subTabs it registers, and this drew
        -- the other a few pixels from it. Hiding a control and then
        -- showing it again is not a migration.
        --
        local appTopY = -6

        content:ClearAllPoints()
        -- Starts at the top now. It used to clear the vault strip, and
        -- that strip was the dashboard's vault drawn a second time -- so
        -- the row it was reserving goes back to the cards, which is the
        -- page that needed it most.
        content:SetPoint("TOPLEFT", PAD, appTopY)
        content:SetPoint("BOTTOMRIGHT", -PAD, PAD)

        -- The shell's content region already IS a surface. A second one
        -- painted inside it is the recessed panel-within-a-panel that
        -- made the page look indented, and it was still anchored to the
        -- standalone tab row it no longer has.
        if contentSurface then contentSurface:Hide() end
    else
        ns.Widgets:Apply(frame, "panel")
        closeBtn:Show()
        titleFs:Show()
        frame:SetMovable(true)
        frame:EnableMouse(true)
        local sw, sh = ns:GetAppFrameSize()
        frame:SetSize(sw, sh)
        for id, tab in pairs(tabButtons) do
            tab:ClearAllPoints()
            local idx = (id == "home") and 0 or 1
            tab:SetPoint("TOPLEFT", PAD + idx * (TAB_W + TAB_GAP), TAB_Y)
            tab:Show()
        end
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", PAD, TAB_Y - TAB_H - 4)
        content:SetPoint("BOTTOMRIGHT", -PAD, PAD)
        -- Standalone draws its own window, so it needs its own surface
        -- back and its own tab row with it.
        if contentSurface then
            contentSurface:ClearAllPoints()
            contentSurface:SetPoint("TOPLEFT", PAD - 8, TAB_Y - TAB_H + 2)
            contentSurface:SetPoint("BOTTOMRIGHT", -PAD + 8, PAD - 6)
            contentSurface:Show()
        end
    end
end

------------------------------------------------------------
-- Events: auto-refresh when group changes
------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
eventFrame:RegisterEvent("MYTHIC_PLUS_CURRENT_AFFIX_UPDATE")
-- This page draws the Great Vault's progress and its example rewards
-- from C_WeeklyRewards, and nothing in the addon listened for the vault
-- changing. Finishing a key filled a slot the page kept showing empty.
eventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
-- The run that just filled it. CHALLENGE_MODE_MAPS_UPDATE covers the
-- keystone changing, which is not the same thing and does not always
-- follow a completion.
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")

-- The other half of the combat deferral above: whatever we refused to
-- draw mid-pull gets drawn the moment the lockdown lifts.
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if refreshPending and frame:IsShown() then
            ns:RefreshMythicPlus()
        end
        return
    end
    if frame:IsShown() then
        C_Timer.After(0.5, function()
            if frame:IsShown() then
                ns:RefreshMythicPlus()
            end
        end)
    end
end)
