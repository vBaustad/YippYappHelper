local _, ns = ...

------------------------------------------------------------
-- Teleport UI: clickable dungeon & raid teleport tiles
------------------------------------------------------------
local PAD = 12
local TILE_SIZE = 48
local TILE_GAP = 5
local HEADER_H = 20
local SECTION_GAP = 8

------------------------------------------------------------
-- Teleport data.
--
-- Every teleport has ONE canonical home: the expansion its dungeon comes
-- from. That is the whole organising rule, and it is why a dungeon that
-- returns for a new season is not filed under that season -- Ruby Life
-- Pools is a Dragonflight dungeon in Midnight Season 2 exactly as much
-- as it was in Dragonflight Season 1.
--
-- The current season is then a VIEW over those canonical entries rather
-- than a copy of them (see CURRENT_SEASON). A returning dungeon appears
-- twice on the page -- once at the top under the season, once under its
-- expansion -- but it is the same entry both times, so it cannot read as
-- unlocked in one place and locked in the other, and it is counted only
-- once in the summary.
--
-- When the season rolls over, the season list is replaced and the page
-- reorganises itself: nothing has to be moved between groups, because
-- nothing was ever filed under a season to begin with.
--
-- { id | ids, name }
------------------------------------------------------------
local TELEPORT_GROUPS = {
    {
        header = "Midnight",
        entries = {
            { id = 1289772, name = "Altar of Fangs" },
            -- These three read like older-expansion dungeons and are
            -- not. Midnight rebuilds the zones they sit in, so what
            -- looks like a returning dungeon is new content wearing a
            -- familiar name: Murder Row is not the Suramar street,
            -- Zul'Aman is a new Midnight zone built over the old one,
            -- and Magisters' Terrace is a new version of the Quel'Thalas
            -- original rather than the Burning Crusade one.
            --
            -- The test for filing a dungeon is whether Midnight remade
            -- it, not whether the name predates Midnight. Leave them.
            { id = 1289775, name = "Murder Row" },
            { id = 1289773, name = "Den of Nalorakk" },
            { id = 1254572, name = "Magisters' Terrace" },
            { id = 1289776, name = "The Blinding Vale" },
            { id = 1289777, name = "Voidscar Arena" },
            { id = 1254400, name = "Windrunner Spire" },
            { id = 1254563, name = "Nexus-Point Xenas" },
            { id = 1254559, name = "Maisara Caverns" },
        },
    },
    {
        header = "The War Within",
        entries = {
            { id = 1216786, name = "Operation: Floodgate" },
            { id = 1237215, name = "Eco-Dome Al'dani" },
            { id = 445417,  name = "Ara-Kara, City of Echoes" },
            { id = 445414,  name = "The Dawnbreaker" },
            { id = 445444,  name = "Priory of the Sacred Flame" },
            { id = 445416,  name = "City of Threads" },
            { id = 445269,  name = "The Stonevault" },
            { id = 445440,  name = "Cinderbrew Meadery" },
            { id = 445441,  name = "Darkflame Cleft" },
            { id = 445443,  name = "The Rookery" },
        },
    },
    {
        header = "Dragonflight",
        entries = {
            { id = 393267,  name = "Brackenhide Hollow" },
            { id = 393283,  name = "Halls of Infusion" },
            { id = 393276,  name = "Neltharus" },
            { id = 393222,  name = "Uldaman: Legacy of Tyr" },
            { id = 424197,  name = "Dawn of the Infinite" },
            { id = 393279,  name = "The Azure Vault" },
            { id = 393262,  name = "The Nokhud Offensive" },
            { id = 393273,  name = "Algeth'ar Academy" },
            -- Two spells for one dungeon. A returning dungeon can be
            -- unlocked from the expansion it came from OR from the season
            -- that brought it back, and either one means you have the
            -- port. That is the bug this fixes: the season tile checked
            -- only the season's spell, so it read as locked for anyone
            -- who earned the Dragonflight version years ago.
            { ids = { 393256, 1289780 }, name = "Ruby Life Pools" },
        },
    },
    {
        header = "Shadowlands",
        entries = {
            { id = 354462,  name = "The Necrotic Wake" },
            { id = 354463,  name = "Plaguefall" },
            { id = 354464,  name = "Mists of Tirna Scithe" },
            { id = 354466,  name = "Spires of Ascension" },
            { id = 354467,  name = "Theater of Pain" },
            { id = 354468,  name = "De Other Side" },
            { id = 354469,  name = "Sanguine Depths" },
            { id = 367416,  name = "Tazavesh" },
            { id = 354465,  name = "Halls of Atonement" },
        },
    },
    {
        header = "Battle for Azeroth",
        entries = {
            { id = 410071,  name = "Freehold" },
            { id = 410074,  name = "The Underrot" },
            { id = 424167,  name = "Waycrest Manor" },
            { id = 424187,  name = "Atal'Dazar" },
            { id = 373274,  name = "Operation: Mechagon" },
            { id = 445418,  name = "Siege of Boralus" },
            { id = 272268,  name = "The MOTHERLODE!!" },
            { id = 1289778, name = "Kings' Rest" },
            { id = 1289782, name = "Temple of Sethraliss" },
        },
    },
    {
        header = "Legion",
        entries = {
            { id = 410078,  name = "Neltharion's Lair" },
            { id = 424153,  name = "Black Rook Hold" },
            { id = 424163,  name = "Darkheart Thicket" },
            { id = 393764,  name = "Halls of Valor" },
            { id = 393766,  name = "Court of Stars" },
            { id = 373262,  name = "Return to Karazhan" },
            { id = 1254551, name = "Seat of the Triumvirate" },
        },
    },
    {
        header = "Warlords of Draenor",
        entries = {
            { id = 159901,  name = "The Everbloom" },
            { id = 159900,  name = "Grimrail Depot" },
            { id = 159896,  name = "Iron Docks" },
            { id = 159897,  name = "Auchindoun" },
            { id = 159895,  name = "Bloodmaul Slag Mines" },
            { id = 159899,  name = "Shadowmoon Burial Grounds" },
            { id = 159902,  name = "Upper Blackrock Spire" },
            { id = 159898,  name = "Skyreach" },
        },
    },
    {
        header = "Cataclysm",
        entries = {
            { id = 410080,  name = "The Vortex Pinnacle" },
            { id = 424142,  name = "Throne of the Tides" },
            { id = 445424,  name = "Grim Batol" },
        },
    },
    {
        header = "Mists of Pandaria",
        entries = {
            { id = 131204,  name = "Temple of the Jade Serpent" },
            { id = 131205,  name = "Stormstout Brewery" },
            { id = 131206,  name = "Shado-Pan Monastery" },
            { id = 131225,  name = "Gate of the Setting Sun" },
            { id = 131222,  name = "Mogu'shan Palace" },
            { id = 131228,  name = "Siege of Niuzao Temple" },
            { id = 131232,  name = "Scholomance" },
            { id = 131231,  name = "Scarlet Halls" },
            { id = 131229,  name = "Scarlet Monastery" },
        },
    },
    {
        header = "Wrath of the Lich King",
        entries = {
            { id = 1254555, name = "Pit of Saron" },
        },
    },
}

-- The current season's dungeon pool, by name. Every name must match a
-- canonical entry above. One that does not is skipped and collected in
-- ns.TELEPORT_MISSING_SEASON, which the test suite asserts is empty --
-- a typo here would otherwise quietly shrink the section people look at
-- first, and a missing tile is not something you notice.
--
-- Rolling the season over means editing this list and nothing else.
local CURRENT_SEASON = {
    header = "Midnight Season 2 - Current",
    names = {
        "Altar of Fangs",
        "Murder Row",
        "Den of Nalorakk",
        "The Blinding Vale",
        "Voidscar Arena",
        "Kings' Rest",
        "Ruby Life Pools",
        "Temple of Sethraliss",
    },
}

------------------------------------------------------------
-- Derived views
------------------------------------------------------------
-- Normalise `id` into `ids` once, so everything downstream has a single
-- shape to handle instead of two.
for _, group in ipairs(TELEPORT_GROUPS) do
    for _, entry in ipairs(group.entries) do
        if not entry.ids then entry.ids = { entry.id } end
    end
end

local byName = {}
for _, group in ipairs(TELEPORT_GROUPS) do
    for _, entry in ipairs(group.entries) do
        byName[entry.name] = entry
    end
end

--- True when the player has this teleport, plus the spell to cast.
---
--- Any of the entry's spells counts. Returns the KNOWN spell when there
--- is one, so the tile casts what they actually have, and the first
--- otherwise, so a locked tile still has an icon and a tooltip.
local function EntryKnown(entry)
    for _, id in ipairs(entry.ids) do
        if IsSpellKnown(id) then return true, id end
    end
    return false, entry.ids[1]
end

-- The season section, resolved to the same entry TABLES the expansion
-- groups hold -- not copies. That identity is what keeps the two
-- sections from ever disagreeing about a dungeon.
local seasonGroup, missingSeasonNames = nil, {}
do
    local entries = {}
    for _, name in ipairs(CURRENT_SEASON.names) do
        local entry = byName[name]
        if entry then
            entries[#entries + 1] = entry
        else
            missingSeasonNames[#missingSeasonNames + 1] = name
        end
    end
    if #entries > 0 then
        seasonGroup = { header = CURRENT_SEASON.header, entries = entries }
    end
end

-- What gets drawn: the current season first, then expansions newest
-- first. TELEPORT_GROUPS remains the list of canonical entries, so the
-- summary can count each teleport once however often it is shown.
local DISPLAY_GROUPS = {}
if seasonGroup then DISPLAY_GROUPS[#DISPLAY_GROUPS + 1] = seasonGroup end
for _, group in ipairs(TELEPORT_GROUPS) do
    DISPLAY_GROUPS[#DISPLAY_GROUPS + 1] = group
end

ns.TELEPORT_GROUPS = TELEPORT_GROUPS
ns.TELEPORT_DISPLAY_GROUPS = DISPLAY_GROUPS
ns.TELEPORT_MISSING_SEASON = missingSeasonNames
ns.TeleportEntryKnown = EntryKnown

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
frame:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
})
frame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
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

local function AcquireTex(parent)
    texPoolIdx = texPoolIdx + 1
    local tex = texPool[texPoolIdx]
    if not tex then
        tex = parent:CreateTexture(nil, "ARTWORK")
        texPool[texPoolIdx] = tex
    else
        tex:SetParent(parent)
    end
    tex:ClearAllPoints()
    tex:Show()
    return tex
end

local function ResetPools()
    for i = 1, btnPoolIdx do btnPool[i]:Hide() end
    btnPoolIdx = 0
    for i = 1, fsPoolIdx do fsPool[i]:Hide() end
    fsPoolIdx = 0
    for i = 1, texPoolIdx do texPool[i]:Hide() end
    texPoolIdx = 0
end

------------------------------------------------------------
-- Refresh
------------------------------------------------------------
local tooltip = GameTooltip

function ns:RefreshTeleports()
    if not frame:IsShown() then return end

    ResetPools()

    local cw = scrollFrame:GetWidth() - 10
    if cw < 10 then cw = (ns:GetAppFrameSize()) - PAD * 2 end
    local y = 0

    local tilesPerRow = math.floor((cw + TILE_GAP) / (TILE_SIZE + TILE_GAP))
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
    summaryFs:SetText("|cff888888" .. knownCount .. " / " .. totalCount .. " teleports unlocked|r")
    y = y - 18

    for _, group in ipairs(DISPLAY_GROUPS) do
        -- Check if any entry in group is known
        local anyKnown = false
        for _, entry in ipairs(group.entries) do
            if EntryKnown(entry) then anyKnown = true; break end
        end

        -- Header divider
        local div = AcquireTex(content)
        div:SetHeight(1)
        div:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        div:SetPoint("TOPRIGHT", content, "TOPLEFT", cw, y)
        div:SetColorTexture(0.2, 0.2, 0.2, 0.5)
        y = y - 4

        -- Header
        local hdr = AcquireFS(content, "GameFontNormal")
        hdr:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        if anyKnown then
            hdr:SetText("|cffdddddd" .. group.header .. "|r")
        else
            hdr:SetText("|cff555555" .. group.header .. "|r")
        end
        y = y - HEADER_H

        -- Tiles
        for i, entry in ipairs(group.entries) do
            local col = (i - 1) % tilesPerRow
            local row = math.floor((i - 1) / tilesPerRow)
            local tx = col * (TILE_SIZE + TILE_GAP)
            local ty = y - row * (TILE_SIZE + 12 + TILE_GAP)

            -- spellID, not entry.id: a returning dungeon has more than
            -- one, and the tile has to cast the one they actually own.
            local known, spellID = EntryKnown(entry)
            local spellIcon = C_Spell.GetSpellTexture(spellID)

            local tile = AcquireBtn(content)
            tile:SetSize(TILE_SIZE, TILE_SIZE + 12)
            tile:SetPoint("TOPLEFT", content, "TOPLEFT", tx, ty)
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
            tile._label:SetText(known and ("|cffcccccc" .. short .. "|r") or ("|cff444444" .. short .. "|r"))

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

        local numRows = math.ceil(#group.entries / tilesPerRow)
        y = y - numRows * (TILE_SIZE + 12 + TILE_GAP) + TILE_GAP - SECTION_GAP
    end

    content:SetWidth(cw)
    content:SetHeight(math.abs(y) + 20)
end

------------------------------------------------------------
-- App mode
------------------------------------------------------------
function ns:SetTeleportAppMode(enabled, contentWidth, contentHeight)
    if enabled then
        frame:SetBackdrop(nil)
        closeBtn:Hide()
        titleFs:Hide()
        frame:SetMovable(false)
        frame:EnableMouse(false)
        local dw, dh = ns:GetAppFrameSize()
        frame:SetSize(contentWidth or dw, contentHeight or (dh - 34))
        scrollFrame:SetPoint("TOPLEFT", PAD, -18)
    else
        frame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets   = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
        frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        closeBtn:Show()
        titleFs:Show()
        frame:SetMovable(true)
        frame:EnableMouse(true)
        local sw, sh = ns:GetAppFrameSize()
        frame:SetSize(sw, sh)
        scrollFrame:SetPoint("TOPLEFT", PAD, -38)
    end
end
