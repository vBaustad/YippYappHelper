local _, ns = ...

------------------------------------------------------------
-- Delves page.
--
-- Three things, in the order they answer questions:
--
--   Your companion, because that is the one delve fact with nowhere
--   else to live and the one the game hides behind a portrait click.
--
--   This week, because coffer keys are the gate on everything else and
--   they expire.
--
--   The tier ladder, because "which tier is worth running" is the
--   question delves actually raise, and the answer is a table.
--
-- What is NOT here, and why: curios and the Delver's Journey. Both are
-- visible in the game and neither is reachable from any API in use by
-- any addon on this machine. A section that cannot be filled is worse
-- than a section that is not there, so they are absent until the
-- reading is real -- see DelvesData.lua.
------------------------------------------------------------

local Shell, W = ns.Shell, ns.Widgets
if not (Shell and W) then return end

local PAD, GAP = Shell.PAD, Shell.GAP
local SCROLLBAR_W = 20
local ROW_H = 22
-- The section panel, and the banner sitting inside it.
--
-- The banner is a cut of the game's own Journeys companion row, so both
-- its height AND its width are the art's, not a layout choice. Stretched
-- across the page it stopped reading as the button it is in the game and
-- became a letterboxed bar with a face in the corner.
local COMP_CARD_H = 123
local BANNER_W = 341

-- Media/CompanionBanner.tga, cut by Tools/make_companion_banner.py.
--
-- ONE texture at its native size, not a stretched three-slice. The
-- companion's name is part of the art, so nothing may resample it --
-- and with nothing stretching there is no reason to slice, which is
-- what removed the seams and the flattened middle both.
local BANNER = "Interface\\AddOns\\YippYappHelper\\Media\\CompanionBanner"
local BANNER_H  = 103
local BANNER_TC = { 0, 0.666016, 0, 0.804688 }

-- The baked name's own left edge, measured off the cut. Everything this
-- file writes onto the banner lines up with it rather than with the
-- frame, so the overlay reads as one block with the name instead of as
-- text placed near it.
local BANNER_TEXT_X = 114
-- Right margin: clear of the chevron ornament.
local BANNER_TEXT_R = 42
local ui

------------------------------------------------------------
-- Build
------------------------------------------------------------
local function Build(host)
    ui = { host = host }
    ns.DelvesUI = ui

    ui.scroll = W:ScrollList(host)
    ui.scroll:SetPoint("TOPLEFT", 0, 0)
    ui.scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR_W, 0)
    local page = ui.scroll.content
    ui.page = page

    ui.top = CreateFrame("Frame", nil, page)
    ui.top:SetHeight(1)
    ui.top:SetPoint("TOPLEFT", PAD, -PAD)
    ui.top:SetPoint("RIGHT", page, "RIGHT", -PAD, 0)

    ------------------------------------------------------------
    -- Companion
    ------------------------------------------------------------
    ui.compTitle = W:SectionTitle(page, "Companion")
    ui.compTitle:SetPoint("TOPLEFT", ui.top, "BOTTOMLEFT", 0, 0)
    ui.compTitle:SetPoint("RIGHT", ui.top, "RIGHT", 0, 0)

    -- The section's own surface, full width like every other section on
    -- the page. The banner is a thing sitting ON it, not a replacement
    -- for it -- which is the difference between the companion looking
    -- like an element of this page and looking like a bar bolted across it.
    local card = W:Panel(page, "inset")
    card:SetPoint("TOPLEFT", ui.compTitle, "BOTTOMLEFT", 0, -10)
    card:SetPoint("RIGHT", ui.top, "RIGHT", 0, 0)
    card:SetHeight(COMP_CARD_H)
    ui.compCard = card

    ------------------------------------------------------------
    -- The banner, one texture, at the size it was cut.
    ------------------------------------------------------------
    local banner = CreateFrame("Frame", nil, card)
    banner:SetSize(BANNER_W, BANNER_H)
    banner:SetPoint("LEFT", card, "LEFT", 12, 0)
    card.banner = banner

    card.art = banner:CreateTexture(nil, "BACKGROUND")
    card.art:SetTexture(BANNER)
    card.art:SetTexCoord(unpack(BANNER_TC))
    card.art:SetAllPoints(banner)

    -- Set once and read back. A texture the client cannot load draws
    -- nothing and reports nothing, so without this the banner would be
    -- an invisible frame with text floating in it -- harder to
    -- recognise than a missing picture.
    card.bannerOK = card.art:GetTexture() ~= nil
    if not card.bannerOK then card.art:Hide() end

    -- No name drawn here. It is painted into the banner, along with the
    -- portrait, so writing our own would put a second one over the top
    -- -- and painting it OUT of the art, which is what the previous cut
    -- did, is what wrecked the texture.
    --
    -- Everything below is parented to the BANNER, not the card. A child
    -- frame draws above every region its parent owns whatever the draw
    -- layer, so text owned by the card would sit behind the art. That is
    -- the trap ShellFrame.lua records for the window medallion, and the
    -- reason the sign came up blank once already.
    local function overlay(font, yOff)
        local fs = W:Label(banner, font)
        fs:SetPoint("TOPLEFT", banner, "TOPLEFT", BANNER_TEXT_X, yOff)
        fs:SetPoint("RIGHT", banner, "RIGHT", -BANNER_TEXT_R, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        -- The banner is bright gold and these sit directly on it, so
        -- they carry the same shadow the baked name does. Without it
        -- light text on light art has no edge at all.
        if ns.ApplyTextShadow then ns.ApplyTextShadow(fs) end
        return fs
    end

    -- Under the baked name: the title the game gives the companion, then
    -- the rank. The name is at y 31..45 in the art, so these clear it.
    card.title = overlay("GameFontNormalSmall", -50)
    card.rank  = overlay("GameFontNormalSmall", -68)

    card.track = banner:CreateTexture(nil, "ARTWORK")
    card.track:SetPoint("TOPLEFT", banner, "TOPLEFT", BANNER_TEXT_X, -88)
    card.track:SetPoint("RIGHT", banner, "RIGHT", -BANNER_TEXT_R, 0)
    card.track:SetHeight(4)

    card.fill = banner:CreateTexture(nil, "OVERLAY")
    card.fill:SetPoint("TOPLEFT", card.track, "TOPLEFT", 0, 0)
    card.fill:SetHeight(4)

    ------------------------------------------------------------
    -- This week
    ------------------------------------------------------------
    ui.weekTitle = W:SectionTitle(page, "This Week")
    ui.weekTitle:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -GAP * 2)
    ui.weekTitle:SetPoint("RIGHT", ui.top, "RIGHT", 0, 0)

    ui.weekRows = {}
    for i = 1, 3 do
        local row = CreateFrame("Frame", nil, page)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", ui.weekTitle, "BOTTOMLEFT", 0,
            -8 - (i - 1) * (ROW_H + 2))
        row:SetPoint("RIGHT", ui.top, "RIGHT", 0, 0)

        row.label = W:Label(row, "GameFontNormalSmall")
        row.label:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.label:SetTextColor(W:Color("muted"))

        row.value = W:Label(row, "GameFontNormal", "RIGHT")
        row.value:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        ui.weekRows[i] = row
    end

    ------------------------------------------------------------
    -- Tiers
    ------------------------------------------------------------
    ui.tierTitle = W:SectionTitle(page, "Tier Rewards")
    ui.tierTitle:SetPoint("TOPLEFT", ui.weekRows[3], "BOTTOMLEFT", 0, -GAP * 2)
    ui.tierTitle:SetPoint("RIGHT", ui.top, "RIGHT", 0, 0)

    -- One header row plus a row per tier. Built to the length of the
    -- shared table rather than to a number typed here, so a season with
    -- a different ladder does not lose its tail.
    ui.tierRows = {}
    for i = 0, #((ns.PROGRESSION and ns.PROGRESSION.DELVES) or {}) do
        local row = CreateFrame("Frame", nil, page)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", ui.tierTitle, "BOTTOMLEFT", 0,
            -8 - i * (ROW_H - 2))
        row:SetPoint("RIGHT", ui.top, "RIGHT", 0, 0)

        row.cells = {}
        for c = 1, 4 do
            local fs = W:Label(row, "GameFontNormalSmall", c == 1 and "LEFT" or "RIGHT")
            row.cells[c] = fs
        end

        -- A gate marker, left of the tier, on the two rows that change
        -- what you can DO rather than how much you get. Drawn in the
        -- margin so it cannot push the columns around.
        row.gate = W:Label(row, "GameFontNormalSmall")
        row.gate:SetPoint("RIGHT", row, "LEFT", -2, 0)
        row.gate:SetText(W:Tint("warn", "\194\187"))
        row.gate:Hide()

        ui.tierRows[i] = row
    end

    -- What those markers mean, under the table rather than in it: two
    -- short lines beat an extra column that is empty on nine rows.
    ui.gateNotes = {}
    for i = 1, 2 do
        local fs = W:Label(page, "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", ui.tierRows[#((ns.PROGRESSION
            and ns.PROGRESSION.DELVES) or {})], "BOTTOMLEFT", 4,
            -8 - (i - 1) * 16)
        fs:SetTextColor(W:Color("muted"))
        ui.gateNotes[i] = fs
    end
end

------------------------------------------------------------
-- Refresh
------------------------------------------------------------
local function Refresh(ctx)
    if not ui then return end
    local fullW = (ctx and ctx.width or ui.host:GetWidth() or 0) - PAD * 2 - SCROLLBAR_W
    if fullW < 60 then fullW = 600 end

    ------------------------------------------------------------
    -- Companion
    ------------------------------------------------------------
    local comp = ns.Delves and ns.Delves:GetCompanion()
    local card = ui.compCard

    if comp then
        -- The client's own title for the companion, but only when it
        -- says something the rank does not. For this one the reaction
        -- reads back as literally "Level 80", which under a rank line
        -- is the same number twice. A title like "Trusty Delve
        -- Companion" earns its place; a restatement of the number does not.
        local title = comp.standing
        if title and comp.level
            and tostring(title):find(tostring(comp.level), 1, true) then
            title = nil
        end
        card.title:SetText(title and ("|cffffd100" .. title .. "|r") or "")

        if comp.level and comp.maxLevel then
            local capped = comp.level >= comp.maxLevel
            card.rank:SetText(("|cffffffffRank %d|r|cffe8d5a8 of %d%s|r")
                :format(comp.level, comp.maxLevel, capped and " — maxed" or ""))
        else
            card.rank:SetText("")
        end

        if comp.pct then
            card.track:SetColorTexture(0, 0, 0, 1)
            card.track:SetAlpha(0.45)
            local r, g, b = W:Color("good")
            card.fill:SetColorTexture(r, g, b, 1)
            card.fill:SetWidth(math.max((card.track:GetWidth() or 1) * comp.pct, 1))
            card.track:Show()
            card.fill:Show()
        else
            -- At maximum rank there is no next threshold, and an empty
            -- bar would read as no progress rather than as finished.
            card.track:Hide()
            card.fill:Hide()
        end
    else
        -- The art is Valeera with her name on it, so it cannot stand in
        -- for "you have no companion". Hide it and say so plainly.
        card.art:Hide()
        card.title:SetText(W:Tint("muted", "No delve companion yet"))
        card.rank:SetText(W:Tint("faint",
            "Unlocked by starting the season's delve questline."))
        card.track:Hide()
        card.fill:Hide()
    end
    ui._companion = comp

    ------------------------------------------------------------
    -- This week
    ------------------------------------------------------------
    local keys = ns.Delves and ns.Delves:GetKeys()
    local track = ns.Delves and ns.Delves:GetVaultTrack()
    local dash = W:Tint("faint", "--")

    local rows = {
        { "Coffer key shards", keys and keys.shardCap and keys.shardCap > 0
            and ("%d / %d earned"):format(keys.shardEarned or 0, keys.shardCap)
            or (keys and keys.shards and tostring(keys.shards)) or dash },
        { "Restored keys", keys and keys.keys and tostring(keys.keys) or dash },
        { "Vault slots", track and ("%d of %d"):format(
            tonumber(track.filled) or 0, tonumber(track.total) or 0) or dash },
    }
    for i, row in ipairs(ui.weekRows) do
        row.label:SetText(rows[i][1])
        row.value:SetText(rows[i][2])
    end

    ------------------------------------------------------------
    -- Tiers
    ------------------------------------------------------------
    local tiers = (ns.Delves and ns.Delves:GetTiers()) or {}
    local gates = (ns.Delves and ns.Delves:GetTierGates()) or {}
    local colW = math.floor(fullW / 4)
    local head = { "Tier", "Loot", "Vault", "Crest" }
    for i, row in pairs(ui.tierRows) do
        local def = tiers[i]
        for c, fs in ipairs(row.cells) do
            fs:ClearAllPoints()
            fs:SetWidth(colW - 8)
            fs:SetPoint("LEFT", row, "LEFT", 4 + (c - 1) * colW, 0)
        end
        if i == 0 then
            for c, fs in ipairs(row.cells) do
                fs:SetText(W:Tint("faint", head[c]))
            end
            row:Show()
        elseif def then
            row.cells[1]:SetText(("Tier %d"):format(def.tier))
            row.cells[2]:SetText(tostring(def.loot or "-"))
            row.cells[3]:SetText(tostring(def.vault or "-"))
            -- The crest column carries the track colour the rest of the
            -- addon uses, so "Champion" means the same purple here as on
            -- the rail and the Progression page.
            local crest = def.crestType or ""
            local hex
            for _, c in ipairs(ns.CRESTS or {}) do
                if c.track == crest then hex = c.color end
            end
            row.cells[4]:SetText(crest ~= "" and
                (hex and ("|c%s%s|r"):format(hex, crest) or crest) or dash)
            row.gate:SetShown(gates[def.tier] ~= nil)
            row:Show()
        else
            row:Hide()
        end
    end

    -- The gate lines, in tier order so they read down the page the way
    -- the table above them does.
    local keys = {}
    for tier in pairs(gates) do keys[#keys + 1] = tier end
    table.sort(keys)
    for i, fs in ipairs(ui.gateNotes) do
        local tier = keys[i]
        -- Guillemet, not a bullet: U+00BB is Latin-1 and proven to
        -- render here, where U+2022 is neither. The em dash is fine
        -- -- the addon already uses it 180-odd times.
        fs:SetText(tier and ("|cffffc83c»|r  Tier %d — %s")
            :format(tier, gates[tier]) or "")
    end

    -- Measured from what was drawn, so the scroll knows how far the page
    -- runs without a constant to keep in step.
    local titleH = ui.compTitle:GetHeight() or 32
    local nTiers = #tiers
    ui._pageH = PAD
        + titleH + 10 + COMP_CARD_H
        + GAP * 2 + titleH + 8 + 3 * (ROW_H + 2)
        + GAP * 2 + titleH + 8 + (nTiers + 1) * (ROW_H - 2) + 8 + 2 * 16
        + PAD
    ui.scroll:SetContentHeight(ui._pageH)
end

Shell:RegisterPage({
    -- After Raid, not between Mythic+ and it.
    --
    -- 75 wedged this into the middle of the group content, splitting
    -- Mythic+ from Raid -- the two that belong next to each other. The
    -- run of tabs now goes group content, then solo, then travel, which
    -- is the order you actually pick between them in.
    id = "delves", label = "Delves", order = 85,
    accent = { 0.35, 0.85, 0.40 },
    Build = function(host) Build(host) end,
    Refresh = Refresh,
})
