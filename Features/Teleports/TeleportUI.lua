local _, ns = ...

------------------------------------------------------------
-- Teleport UI: clickable dungeon & raid teleport tiles
------------------------------------------------------------
-- Padding comes from the shell, not from here. Eight pages had picked
-- their own -- 12 in four of them, 14 in three -- so every page sat to a
-- different rhythm from the chrome around it and from each other. One
-- source means a spacing change lands everywhere at once.
local PAD = (ns.Shell and ns.Shell.PAD) or 12
local TILE_SIZE = 48
local TILE_GAP = 5
-- The heading's height is the section widget's business now, and comes
-- back from ns.Widgets:SectionTitleHeight rather than being guessed at
-- separately here.
local SECTION_GAP = 12
-- Breathing room between a group's panel edge and its tiles.
local PANEL_PAD = 10

------------------------------------------------------------
-- Teleport data lives in Features\Teleports\TeleportData.lua, which
-- loads ahead of the Mythic+ page so both can read the same table. It
-- used to live here, and the Mythic+ page kept a second copy of it --
-- see the note at the top of that file for what that cost.
------------------------------------------------------------
local DISPLAY_GROUPS = ns.TELEPORT_DISPLAY_GROUPS or {}
local TELEPORT_GROUPS = ns.TELEPORT_GROUPS or {}
local EntryKnown = ns.TeleportEntryKnown

------------------------------------------------------------
-- Main frame
------------------------------------------------------------
local frame = CreateFrame("Frame", "YippYappTeleports", UIParent, "BackdropTemplate")
local TELE_W, TELE_H = ns:GetAppFrameSize()
frame:SetSize(TELE_W, TELE_H)
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
ns.TeleportFrame = frame

frame:SetScript("OnShow", function()
    tinsert(UISpecialFrames, "YippYappTeleports")
end)
frame:SetScript("OnHide", function()
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "YippYappTeleports" then
            table.remove(UISpecialFrames, i)
            break
        end
    end
end)

local titleIcon, titleFs = ns.MakeWindowHeader(frame, "|cff88ccffTeleports|r", nil, PAD)

local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -2, -2)

------------------------------------------------------------
-- Scroll frame
------------------------------------------------------------
local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", PAD, -38)
scrollFrame:SetPoint("BOTTOMRIGHT", -PAD - 22, PAD)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(1, 1)
scrollFrame:SetScrollChild(content)

------------------------------------------------------------
-- Object pools
------------------------------------------------------------
local btnPool = {}
local btnPoolIdx = 0

local function AcquireBtn(parent)
    btnPoolIdx = btnPoolIdx + 1
    local btn = btnPool[btnPoolIdx]
    if not btn then
        btn = CreateFrame("Button", nil, parent, "BackdropTemplate,SecureActionButtonTemplate")
        btn:RegisterForClicks("AnyUp", "AnyDown")
        btnPool[btnPoolIdx] = btn

        btn._icon = btn:CreateTexture(nil, "ARTWORK")
        btn._icon:SetPoint("TOPLEFT", 3, -3)
        btn._icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 15)
        btn._icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        btn._overlay = btn:CreateTexture(nil, "ARTWORK", nil, 1)
        btn._overlay:SetAllPoints(btn._icon)
        btn._overlay:SetColorTexture(0, 0, 0, 0.35)

        btn._label = btn:CreateFontString(nil, "OVERLAY")
        btn._label:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE")
        btn._label:SetPoint("BOTTOM", btn, "BOTTOM", 0, 3)
        btn._label:SetWidth(TILE_SIZE - 4)
        btn._label:SetJustifyH("CENTER")
        btn._label:SetWordWrap(false)
    else
        btn:SetParent(parent)
    end
    btn:ClearAllPoints()
    btn:SetScript("OnEnter", nil)
    btn:SetScript("OnLeave", nil)
    -- Attributes on a secure button cannot be written in combat: the
    -- call is blocked and throws. The Mythic+ tiles already guard this;
    -- these did not, so opening Teleports mid-combat errored.
    if not InCombatLockdown() then
        btn:SetAttribute("type", nil)
        btn:SetAttribute("spell", nil)
        btn:SetAttribute("macrotext", nil)
    end
    btn:Show()
    return btn
end

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
    fs:ClearAllPoints()
    fs:Show()
    return fs
end

local texPool = {}
local texPoolIdx = 0

-- Group sections.
--
-- Each expansion sits on its own surface rather than under a rule. A
-- divider says "a new list starts here"; a panel says "this is one
-- thing", which is what an expansion's teleports are, and it is most of
-- why Vaultloom's lists read as sections instead of one long column.
--
-- One widget now, not two. The heading's ornamental rule and the panel's
-- top border used to be separate things drawn a few pixels apart, so
-- every expansion carried two horizontal lines saying the same thing.
-- ns.Widgets:SectionCard puts the ornament ON the card's top edge, which
-- is the shape the rest of the addon can use as well.
--
-- Pooled like everything else here, and skinned on acquire rather than
-- on create: the skin can change between refreshes.
local sectionPool, sectionPoolIdx = {}, 0

local function AcquireSection(parent)
    sectionPoolIdx = sectionPoolIdx + 1
    local s = sectionPool[sectionPoolIdx]
    if not s then
        s = ns.Widgets:SectionCard(parent)
        sectionPool[sectionPoolIdx] = s
    else
        s:SetParent(parent)
    end
    s:ClearAllPoints()
    s:Show()
    return s
end

local function ResetPools()
    for i = 1, btnPoolIdx do btnPool[i]:Hide() end
    btnPoolIdx = 0
    for i = 1, fsPoolIdx do fsPool[i]:Hide() end
    fsPoolIdx = 0
    for i = 1, texPoolIdx do texPool[i]:Hide() end
    texPoolIdx = 0
    for i = 1, sectionPoolIdx do sectionPool[i]:Hide() end
    sectionPoolIdx = 0
end

------------------------------------------------------------
-- Refresh
------------------------------------------------------------
local tooltip = GameTooltip

-- Combat deferral, for the same reason as Features/MythicPlus/MythicPlusUI.lua.
--
-- The dungeon tiles here are SecureActionButtonTemplate frames, and a
-- redraw re-parents them, re-anchors them, shows them and hides them
-- again through ResetPools. Every one of those is blocked while the
-- player is in combat -- not just the SetAttribute calls AcquireBtn
-- already guarded, which is why guarding only those left the page half
-- drawn instead of fixed. The blocks are silent unless scriptErrors is
-- on, so the visible symptom is a teleport tile that stops responding.
local refreshPending = false

function ns:RefreshTeleports()
    if not frame:IsShown() then return end
    if InCombatLockdown() then
        refreshPending = true
        return
    end
    refreshPending = false

    ResetPools()

    local cw = scrollFrame:GetWidth() - 10
    if cw < 10 then cw = (ns:GetAppFrameSize()) - PAD * 2 end
    local y = 0

    -- Fitted to the panel's interior, not the scroll width: the tiles now
    -- sit inside a padded surface, and sizing them to the full width put
    -- the last column of every row under the panel's right edge.
    local tileArea = cw - PANEL_PAD * 2
    local tilesPerRow = math.floor((tileArea + TILE_GAP) / (TILE_SIZE + TILE_GAP))
    if tilesPerRow < 1 then tilesPerRow = 1 end

    -- Count how many teleports the player has
    local knownCount = 0
    local totalCount = 0
    -- Counted over the canonical groups, never the display list: a
    -- dungeon shown under both its expansion and the current season is
    -- still one teleport, and counting the display list would have read
    -- "8 / 82" for someone who owns seven.
    for _, group in ipairs(TELEPORT_GROUPS) do
        for _, entry in ipairs(group.entries) do
            totalCount = totalCount + 1
            if EntryKnown(entry) then knownCount = knownCount + 1 end
        end
    end

    -- Summary line
    local summaryFs = AcquireFS(content, "GameFontNormalSmall")
    summaryFs:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    summaryFs:SetText("|cff" .. ns.Widgets:Hex("muted") .. knownCount .. " / " .. totalCount .. " teleports unlocked|r")
    y = y - 18

    for _, group in ipairs(DISPLAY_GROUPS) do
        -- Per-group tally. The page already counted the whole collection
        -- for the summary; saying "6 / 9" per expansion is what turns a
        -- wall of tiles into something you can act on, because it names
        -- which expansion still owes you ports.
        local groupKnown = 0
        for _, entry in ipairs(group.entries) do
            if EntryKnown(entry) then groupKnown = groupKnown + 1 end
        end
        local anyKnown = groupKnown > 0

        -- Heading, tally and card as one thing. The heading sits above
        -- the card and the divider is the card's own top edge, so the
        -- title is not cut off from what it titles and there is one line
        -- between them instead of two.
        --
        -- The row count depends on the window width, so the card's
        -- height is worked out before it is laid out rather than after.
        local rowsNeeded = math.ceil(#group.entries / tilesPerRow)
        local bodyH = rowsNeeded * (TILE_SIZE + 12 + TILE_GAP) - TILE_GAP + PANEL_PAD * 2

        local complete = groupKnown == #group.entries
        local section = AcquireSection(content)
        section:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        section:SetText(("|cff%s%s|r"):format(
            ns.Widgets:Hex(anyKnown and "text" or "faint"), group.header))
        section:SetValue(("|cff%s%d / %d|r"):format(
            ns.Widgets:Hex(complete and "good" or anyKnown and "muted" or "faint"),
            groupKnown, #group.entries))
        section:Layout(cw, bodyH)

        -- Into the card: past the heading, then past the card's own top
        -- padding. The tiles below are still anchored to `content`, so
        -- this cursor has to land where the card's interior starts.
        y = y - ns.Widgets:SectionTitleHeight() - PANEL_PAD

        -- Tiles
        for i, entry in ipairs(group.entries) do
            local col = (i - 1) % tilesPerRow
            local row = math.floor((i - 1) / tilesPerRow)
            local tx = PANEL_PAD + col * (TILE_SIZE + TILE_GAP)
            local ty = y - row * (TILE_SIZE + 12 + TILE_GAP)

            -- spellID, not entry.id: a returning dungeon has more than
            -- one, and the tile has to cast the one they actually own.
            local known, spellID = EntryKnown(entry)
            local spellIcon = C_Spell.GetSpellTexture(spellID)

            local tile = AcquireBtn(content)
            tile:SetSize(TILE_SIZE, TILE_SIZE + 12)
            tile:SetPoint("TOPLEFT", content, "TOPLEFT", tx, ty)
            -- Left on its own backdrop deliberately. The fill is
            -- transparent and the BORDER is the state -- known teleports
            -- are outlined, unknown ones are not -- so this is a signal
            -- drawn with backdrop calls, not a surface. Routing it
            -- through the skin would both make it opaque and leave the
            -- SetBackdropBorderColor below with no backdrop to colour.
            tile:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 8,
                insets   = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            tile:SetBackdropColor(0, 0, 0, 0)

            if known then
                tile:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
            else
                tile:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.3)
            end

            -- Icon
            tile._icon:SetTexture(spellIcon or 134400)
            if known then
                tile._icon:SetDesaturated(false)
                tile._icon:SetAlpha(1)
                tile._overlay:SetColorTexture(0, 0, 0, 0.25)
            else
                tile._icon:SetDesaturated(true)
                tile._icon:SetAlpha(0.35)
                tile._overlay:SetColorTexture(0, 0, 0, 0.5)
            end

            -- Label
            local short = entry.name
            if #short > 10 then
                -- Try first word
                local first = short:match("^(%S+)")
                if first and #first >= 3 then short = first end
            end
            tile._label:SetText(known and ("|cff" .. ns.Widgets:Hex("text") .. short .. "|r") or ("|cff444444" .. short .. "|r"))

            -- Secure click to cast
            if known then
                local spellName = C_Spell.GetSpellName(spellID)
                if spellName and not InCombatLockdown() then
                    tile:SetAttribute("type", "macro")
                    tile:SetAttribute("macrotext", "/cast " .. spellName)
                end
            end

            -- Tooltip
            local spellName = entry.name
            tile:SetScript("OnEnter", function(self)
                if known then
                    self:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
                    self:SetBackdropColor(1, 1, 1, 0.1)
                end
                tooltip:SetOwner(self, "ANCHOR_RIGHT")
                tooltip:AddLine(spellName, 1, 1, 1)
                if known then
                    tooltip:AddLine("Click to teleport", 0, 0.8, 0)
                else
                    tooltip:AddLine("Not unlocked", 0.5, 0.5, 0.5)
                end
                tooltip:Show()
            end)
            tile:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0, 0, 0, 0)
                if known then
                    self:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
                else
                    self:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.3)
                end
                tooltip:Hide()
            end)
        end

        -- Past the tiles, then past the panel's bottom padding. y was
        -- already moved down by the top padding before the tiles were
        -- placed, so only the bottom one is left to account for here.
        y = y - rowsNeeded * (TILE_SIZE + 12 + TILE_GAP) + TILE_GAP
            - PANEL_PAD - SECTION_GAP
    end

    content:SetWidth(cw)
    content:SetHeight(math.abs(y) + 20)
end

------------------------------------------------------------
-- App mode
------------------------------------------------------------
function ns:SetTeleportAppMode(enabled, contentWidth, contentHeight)
    if enabled then
        ns.Widgets:Unskin(frame)
        closeBtn:Hide()
        titleFs:Hide()
        frame:SetMovable(false)
        frame:EnableMouse(false)
        local dw, dh = ns:GetAppFrameSize()
        frame:SetSize(contentWidth or dw, contentHeight or (dh - 34))
        scrollFrame:SetPoint("TOPLEFT", PAD, -18)
    else
        ns.Widgets:Apply(frame, "panel")
        closeBtn:Show()
        titleFs:Show()
        frame:SetMovable(true)
        frame:EnableMouse(true)
        local sw, sh = ns:GetAppFrameSize()
        frame:SetSize(sw, sh)
        scrollFrame:SetPoint("TOPLEFT", PAD, -38)
    end
end

------------------------------------------------------------
-- Combat
------------------------------------------------------------

-- Draws whatever the guard in RefreshTeleports refused, the moment the
-- lockdown lifts. Declared down here rather than beside the frame: it
-- closes over `refreshPending`, and a watcher written above that local
-- would have captured a nil global and quietly never fired.
local combatWatcher = CreateFrame("Frame")
combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
combatWatcher:SetScript("OnEvent", function()
    if refreshPending and frame:IsShown() and ns.RefreshTeleports then
        ns:RefreshTeleports()
    end
end)
