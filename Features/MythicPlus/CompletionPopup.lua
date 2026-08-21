local _, ns = ...

------------------------------------------------------------
-- Mythic+ completion popup: shows your new M+ rating + the
-- party's keystones with click-to-teleport.
------------------------------------------------------------

local win

local function styleBox(f, bgA, borderA)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, bgA or 0.97)
    f:SetBackdropBorderColor(0.35, 0.35, 0.35, borderA or 1)
end

local function classColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then return 0.85, 0.85, 0.85 end
    return c.r, c.g, c.b
end

-- Position, scale and the lock all belong to the shared situation
-- window now (Core/Hud.lua). Nothing here reads
-- YippYappHelperDB.mplusCompletion any more; the key is left in place so
-- a rollback still finds the position it saved.

local function build()
    if win then return win end
    win = CreateFrame("Frame", "YippYappMPlusCompletion", UIParent, "BackdropTemplate")
    win:SetSize(320, 310)
    win:EnableMouse(true)
    win:SetFrameStrata("HIGH")
    styleBox(win)
    win:Hide()

    -- No unlock overlay and no drag handler of its own: Core/Hud.lua
    -- makes this draggable whenever it is open and remembers where it
    -- was dropped, so the old "drag to move" hint -- which only appeared
    -- after unlocking it in a settings panel that covered it -- has
    -- nothing left to explain.

    -- ESC to close via local key (avoid UISpecialFrames taint)
    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Mythic+ Complete")

    -- X close
    local close = CreateFrame("Button", nil, win, "BackdropTemplate")
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", -6, -6)
    styleBox(close, 0.9)
    local cLabel = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cLabel:SetPoint("CENTER"); cLabel:SetText("x")
    close:SetScript("OnClick", function() win:Hide() end)

    -- Rating text
    local rating = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rating:SetPoint("TOP", title, "BOTTOM", 0, -12)
    win.rating = rating

    -- Party key list container
    local keysHeader = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    keysHeader:SetPoint("TOPLEFT", 14, -66)
    keysHeader:SetText("Party keystones")
    keysHeader:SetTextColor(1, 0.82, 0)

    local list = CreateFrame("Frame", nil, win)
    list:SetPoint("TOPLEFT", keysHeader, "BOTTOMLEFT", 0, -4)
    list:SetPoint("TOPRIGHT", win, "TOPRIGHT", -14, 0)
    list:SetPoint("BOTTOM", win, "BOTTOM", 0, 40)
    win.list = list

    -- Open full M+ button
    local openBtn = CreateFrame("Button", nil, win, "BackdropTemplate")
    openBtn:SetSize(150, 22)
    openBtn:SetPoint("BOTTOM", 0, 10)
    styleBox(openBtn, 0.9)
    local oLabel = openBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    oLabel:SetPoint("CENTER"); oLabel:SetText("Open Mythic+ window")
    openBtn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0, 0.8, 1, 1) end)
    openBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.35, 0.35, 0.35, 1) end)
    openBtn:SetScript("OnClick", function()
        win:Hide()
        if not (ns.OpenTo and ns:OpenTo("mythicplus")) and ns.MythicPlusFrame then
            ns.MythicPlusFrame:Show()
        end
    end)

    -- Adopted by the shared situation window. It ranks below the ready
    -- check and above the dungeon notes: a key you just finished is over
    -- and its summary can wait 30 seconds, but the notes for a dungeon
    -- you already cleared cannot possibly matter more than this.
    if ns.Hud then
        ns.Hud:Register("mplusCompletion", win, {
            label   = "After a key",
            aliases = { "key", "completion", "mplus", "afterkey" },
            -- Left of centre, which is where it has always opened. It
            -- appears three seconds after a key ends, when the middle of
            -- the screen belongs to the run's own completion banner.
            default = { point = "LEFT", relativePoint = "LEFT", x = 40, y = 100 },
            preview = function()
                if ns.ShowCompletionPopupTest then ns.ShowCompletionPopupTest() end
            end,
        })
    end

    return win
end

local ROW_H = 36
local ICON_SIZE = 28
local MAX_ROWS = 5

-- Secure-button pool, created once in a fresh context (PLAYER_LOGIN) so
-- anchoring doesn't fail when the popup is later shown from a tainted path
-- like the settings Preview button.
local securePool = {}
local securePoolReady = false

-- BigWigs uses InsecureActionButtonTemplate for their keystone teleports —
-- it supports the `type=spell` attribute but isn't protected, so anchoring
-- works from any context (including tainted settings-click paths).
local function ensureSecurePool()
    if securePoolReady or not win then return end
    for i = 1, MAX_ROWS do
        local b = CreateFrame("Button", nil, win.list, "InsecureActionButtonTemplate")
        b:SetPoint("TOPLEFT", win.list, "TOPLEFT", 0, -(i - 1) * (ROW_H + 4))
        b:SetSize(win.list:GetWidth(), ROW_H)
        b:RegisterForClicks("AnyUp", "AnyDown")
        b:Hide()
        securePool[i] = b
    end
    securePoolReady = true
end

-- Persistent visual-row pool, parallel to securePool. Rows are created
-- once and re-populated on each refresh — without this we'd leak ~5
-- frames per M+ completion popup show.
local rowPool = {}

local function ensureRowFrame(index)
    if rowPool[index] then
        -- showTest() clears the list by calling SetParent(nil) on its
        -- children, which includes these pooled rows. Re-adopt before
        -- reuse: a parentless row still draws, at whatever screen
        -- position it last had, floating free of the popup.
        local existing = rowPool[index]
        if win and win.list and existing:GetParent() ~= win.list then
            existing:SetParent(win.list)
            existing:ClearAllPoints()
            existing:SetPoint("TOPLEFT", 0, -(index - 1) * (ROW_H + 4))
        end
        return existing
    end
    local parent = win.list
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(parent:GetWidth(), ROW_H)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * (ROW_H + 4))

    row.bg = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.bg:SetAllPoints()

    row.accent = row:CreateTexture(nil, "BACKGROUND", nil, 2)
    row.accent:SetSize(3, ROW_H)
    row.accent:SetPoint("TOPLEFT", row.bg, "TOPLEFT", 0, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.lvl = row:CreateFontString(nil, "OVERLAY")
    row.lvl:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.lvl:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")

    row.nameFS = row:CreateFontString(nil, "OVERLAY")
    row.nameFS:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 40, -1)
    row.nameFS:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -4)
    row.nameFS:SetJustifyH("LEFT")
    row.nameFS:SetFont(STANDARD_TEXT_FONT, 11, "")

    row.dungFS = row:CreateFontString(nil, "OVERLAY")
    row.dungFS:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 40, 2)
    row.dungFS:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 4)
    row.dungFS:SetJustifyH("LEFT")
    row.dungFS:SetFont(STANDARD_TEXT_FONT, 10, "")
    row.dungFS:SetTextColor(0.6, 0.6, 0.6)

    row:Hide()
    rowPool[index] = row
    return row
end

local function hideAllVisualRows()
    for _, row in ipairs(rowPool) do row:Hide() end
end

local function populateKeyRow(index, data)
    local row = ensureRowFrame(index)
    row.bg:SetColorTexture(0.09, 0.09, 0.09, 0.7)

    local r, g, b = classColor(data.class)
    row.accent:SetColorTexture(r, g, b, 0.9)

    local spellID = data.mapID and ns.GetDungeonTeleportSpell and ns:GetDungeonTeleportSpell(data.mapID)
    local tex
    if spellID then tex = C_Spell.GetSpellTexture(spellID) end
    if not tex and data.mapID then
        local _, _, _, mapTex = C_ChallengeMode.GetMapUIInfo(data.mapID)
        tex = mapTex
    end
    row.icon:SetTexture(tex or 134400)

    row.lvl:SetText("|cff00d4ff+" .. (data.level or "?") .. "|r")
    row.nameFS:SetTextColor(r, g, b)
    row.nameFS:SetText(data.playerName or "?")
    row.dungFS:SetText(data.dungeonName or "")

    row:SetScript("OnEnter", function(self)
        row.bg:SetColorTexture(0.14, 0.14, 0.14, 0.85)
        if spellID and IsSpellKnown(spellID) then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Teleport to " .. (data.dungeonName or ""))
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        row.bg:SetColorTexture(0.09, 0.09, 0.09, 0.7)
        GameTooltip:Hide()
    end)
    row:Show()

    local secure = securePool[index]
    if secure then
        if spellID and IsSpellKnown(spellID) then
            -- BigWigs passes the spellID directly (number) as the `spell`
            -- attribute on InsecureActionButtonTemplate.
            secure:SetAttribute("type", "spell")
            secure:SetAttribute("spell", spellID)
        else
            secure:SetAttribute("type", nil)
        end
        secure:SetScript("OnEnter", function(self)
            row.bg:SetColorTexture(0.14, 0.14, 0.14, 0.85)
            if spellID and IsSpellKnown(spellID) then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Teleport to " .. (data.dungeonName or ""))
                GameTooltip:Show()
            end
        end)
        secure:SetScript("OnLeave", function()
            row.bg:SetColorTexture(0.09, 0.09, 0.09, 0.7)
            GameTooltip:Hide()
        end)
        secure:Show()
    end
end

local function hideAllSecureButtons()
    for _, b in ipairs(securePool) do
        if not InCombatLockdown() then b:SetAttribute("type", nil) end
        b:Hide()
    end
end

local function collectPartyKeys()
    local out = {}
    local selfName = UnitName("player")

    -- Self goes first.
    local own = ns.GetOwnKeystone and ns:GetOwnKeystone()
    if own then
        local _, class = UnitClass("player")
        table.insert(out, {
            playerName   = selfName,
            class        = class,
            mapID        = own.mapID,
            level        = own.level,
            dungeonName  = own.name,
        })
    end

    -- Then party members who have the addon. Skip self in case a stale
    -- self-entry snuck into the cache from an older build.
    local cache = ns.GetPartyKeystones and ns:GetPartyKeystones() or nil
    if cache then
        -- Build a short-name → unit token map so UnitClass is called with a
        -- real unit (party1..4 / player), not a bare name string — the latter
        -- returns nil for out-of-range / cached senders.
        local unitByShortName = {}
        for _, u in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
            if UnitExists(u) then
                local raw = UnitName(u)
                if raw then unitByShortName[Ambiguate(raw, "short")] = u end
            end
        end
        for playerName, ks in pairs(cache) do
            if ks and ks.mapID and playerName ~= selfName then
                local unit = unitByShortName[Ambiguate(playerName, "short")]
                local class = unit and select(2, UnitClass(unit)) or nil
                table.insert(out, {
                    playerName   = playerName,
                    class        = class,
                    mapID        = ks.mapID,
                    level        = ks.level,
                    dungeonName  = ks.name,
                })
            end
        end
    end

    return out
end

local function refresh()
    local w = build()
    local newScore = 0
    if C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore then
        newScore = C_ChallengeMode.GetOverallDungeonScore() or 0
    end
    w.rating:SetText(string.format("New M+ rating: |cffffd100%d|r", newScore))

    hideAllVisualRows()
    hideAllSecureButtons()
    local keys = collectPartyKeys()
    for i, k in ipairs(keys) do
        if i > MAX_ROWS then break end
        populateKeyRow(i, k)
    end
end

local function show()
    -- Ask the group before drawing. Their keys changed the moment this
    -- run ended, and a push-only scheme means whatever we have cached is
    -- from before it -- so the window would open listing the keystones
    -- everyone was holding on the way in.
    if ns.RequestPartyKeystones then ns:RequestPartyKeystones() end
    refresh()
    win:Show()
end

--- Redraws if it is up. Called when a keystone arrives over the addon
--- channel, because the replies to the request above land a moment after
--- the window is already on screen.
function ns.RefreshCompletionPopup()
    if win and win:IsShown() then refresh() end
end

local function showTest()
    local w = build()
    ensureSecurePool()
    w.rating:SetText("New M+ rating: |cffffd1003215|r")
    for _, c in ipairs({ w.list:GetChildren() }) do
        local isPooled = false
        for _, b in ipairs(securePool) do if b == c then isPooled = true; break end end
        if not isPooled then c:Hide(); c:SetParent(nil) end
    end
    hideAllSecureButtons()
    local sampleMapID = 2526
    if ns.GetOwnKeystone then
        local own = ns:GetOwnKeystone()
        if own and own.mapID then sampleMapID = own.mapID end
    end
    local sampleName = C_ChallengeMode and C_ChallengeMode.GetMapUIInfo(sampleMapID) or "Sample Dungeon"
    populateKeyRow(1, {
        playerName  = UnitName("player") or "You",
        class       = select(2, UnitClass("player")),
        mapID       = sampleMapID,
        level       = 12,
        dungeonName = sampleName,
    })
    w:Show()
end
ns.ShowCompletionPopupTest = showTest

------------------------------------------------------------
-- Event plumbing
------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        build()
        ensureSecurePool()
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        if ns.ModuleEnabled and not ns.ModuleEnabled("mplusCompletion") then return end
        C_Timer.After(3.0, show)
    end
end)

