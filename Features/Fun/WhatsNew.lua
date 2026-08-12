local _, ns = ...

------------------------------------------------------------
-- What's New.
--
-- Shown once per version, on the first login after updating. Most of
-- what shipped for Season 2 is invisible until you happen to open the
-- right panel -- an addon that quietly rewrote its settings, moved every
-- frame into Edit Mode and grew a mascot should probably mention it.
--
-- Mr. Yeeper delivers it, because a changelog nobody reads becomes a
-- changelog somebody reads when it is rude to them.
--
-- Deliberately one-shot: it records the version it showed and never
-- shows that version again. Nothing is more irritating than an update
-- notice that reappears.
------------------------------------------------------------

ns.WhatsNew = ns.WhatsNew or {}
local WN = ns.WhatsNew

local VERSION = C_AddOns and C_AddOns.GetAddOnMetadata
    and C_AddOns.GetAddOnMetadata("YippYappHelper", "Version") or "3.0.0"

WN.INTRO = "You are back. I have been busy while you were not looking."

WN.ITEMS = {
    { "Season 2 data", "Gear tracks, crest costs, dungeon and raid item "
        .. "levels, and the new keystone pool -- all rebuilt for 12.1." },
    { "Crest warnings", "Hero 5/6 and Myth 1/6 both cost 20 crests to "
        .. "upgrade and both land on 321. Only one of those currencies "
        .. "is still worth anything in a month. I will say so first." },
    { "Omnium Folio", "A page that tracks the five-step Rune chain from "
        .. "your real quest log, with clickable map pins." },
    { "Settings, rewritten", "Now Blizzard's own options panel under "
        .. "AddOns, instead of a hand-drawn imitation of one." },
    { "Edit Mode", "Every movable frame -- the interrupt tracker, brez "
        .. "timer, ready check, completion popup and utility advisor -- "
        .. "now positions through Edit Mode with proper settings dialogs." },
    { "Loot Browser", "Grouped by boss, with a difficulty selector, and it "
        .. "marks what is actually an upgrade over what you are wearing." },
    { "Me", "I am new. I read your gear, crests, vault and keys, and I "
        .. "tell you what is worth doing. Occasionally I tell a joke. "
        .. "The jokes are not mine and I resent delivering them." },
}

WN.OUTRO = "That is everything. Go and press something."

------------------------------------------------------------
-- Frame
------------------------------------------------------------

local frame

local function Build()
    if frame then return frame end

    frame = CreateFrame("Frame", "YippYappWhatsNew", UIParent, "BackdropTemplate")
    frame:SetSize(460, 400)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:Hide()

    local portrait = frame:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(54, 54)
    portrait:SetPoint("TOPLEFT", 22, -20)
    portrait:SetTexture("Interface\\AddOns\\YippYappHelper\\Media\\Yeeper")
    -- Left half of the two-frame sheet: eyes open.
    portrait:SetTexCoord(0, 0.5, 0, 1)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", portrait, "TOPRIGHT", 12, -4)
    title:SetText("|cffb885ffMr. Yeeper|r")

    local version = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    version:SetTextColor(0.5, 0.48, 0.58)
    version:SetText("YippYapp Helper " .. VERSION .. " -- Midnight Season 2")

    local intro = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    intro:SetPoint("TOPLEFT", 22, -86)
    intro:SetWidth(410)
    intro:SetJustifyH("LEFT")
    intro:SetTextColor(0.92, 0.92, 0.95)
    intro:SetText(WN.INTRO)

    local y = -116
    for _, item in ipairs(WN.ITEMS) do
        local head = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        head:SetPoint("TOPLEFT", 26, y)
        head:SetText("|cffb885ff-|r  |cffffffff" .. item[1] .. "|r")

        local body = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        body:SetPoint("TOPLEFT", 40, y - 15)
        body:SetWidth(392)
        body:SetJustifyH("LEFT")
        body:SetSpacing(2)
        body:SetTextColor(0.68, 0.66, 0.74)
        body:SetText(item[2])

        y = y - 17 - (body:GetStringHeight() or 12) - 8
    end

    local outro = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    outro:SetPoint("BOTTOMLEFT", 24, 46)
    outro:SetTextColor(0.6, 0.58, 0.68)
    outro:SetText(WN.OUTRO)

    local ok = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    ok:SetSize(120, 24)
    ok:SetPoint("BOTTOMRIGHT", -24, 20)
    ok:SetText("Fine")
    ok:SetScript("OnClick", function() frame:Hide() end)

    -- Height from the content, so adding an item does not clip the button.
    frame:SetHeight(math.abs(y) + 100)

    tinsert(UISpecialFrames, "YippYappWhatsNew")   -- Escape closes it
    return frame
end

function WN:Show()
    Build():Show()
end

--- Shows once per version, then records it and stays quiet.
function WN:ShowIfNew()
    YippYappHelperDB = YippYappHelperDB or {}
    if YippYappHelperDB.lastSeenVersion == VERSION then return end
    YippYappHelperDB.lastSeenVersion = VERSION
    -- A beat after login, so it does not fight the loading screen.
    C_Timer.After(4, function() WN:Show() end)
end

-- Login only. Nothing about opening the addon shows this -- /yh whatsnew
-- is the only manual route. PLAYER_ENTERING_WORLD is a second chance in
-- case PLAYER_LOGIN already fired before this file loaded; ShowIfNew is
-- idempotent, so whichever arrives first wins and the other does nothing.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    WN:ShowIfNew()
end)
