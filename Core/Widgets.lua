local _, ns = ...

------------------------------------------------------------
-- Widgets.
--
-- The vocabulary pages build from. This is the layer that was missing:
-- the shell told pages not to draw their own chrome, then offered them
-- nothing but a backdrop, so they kept drawing their own progress bars,
-- headings and icon borders and the shell just wrapped the result in a
-- box. A skin has nothing to change unless the things being skinned are
-- shared.
--
-- Every widget asks ns.Skin for its colours and surfaces. Nothing here
-- hardcodes one, so a skin swap repaints the addon rather than only its
-- window frame.
------------------------------------------------------------

ns.Widgets = ns.Widgets or {}
local W = ns.Widgets

-- Blizzard's tintable icon frame, from their own item buttons.
local ICON_FRAME = "Interface\\Common\\WhiteIconFrame"

local function skin()
    return ns.Skin and ns.Skin:Active()
end

--- A skin colour, with a sane fallback so a provider that implements
--- none still renders something readable.
local FALLBACK = {
    accent  = { 0.45, 0.85, 1.00 },
    text    = { 0.92, 0.92, 0.95 },
    muted   = { 0.62, 0.62, 0.68 },
    -- Below muted: present but not yet earned. Needed because
    -- collapsing "some" and "none" into one tone loses a real
    -- distinction the pages were already drawing.
    faint   = { 0.42, 0.40, 0.38 },
    good    = { 0.35, 0.90, 0.45 },
    warn    = { 1.00, 0.78, 0.28 },
    danger  = { 0.85, 0.32, 0.28 },
    track   = { 0.16, 0.16, 0.18 },
}

function W:Color(key)
    local s = skin()
    if s and s.Color then
        local r, g, b = s:Color(key)
        if r then return r, g, b end
    end
    local c = FALLBACK[key] or FALLBACK.text
    return c[1], c[2], c[3]
end

--- A skin colour as an escape-code hex, for text built by concatenation.
---
--- The pages are full of literals like |cff888888 and |cffdddddd, which
--- is the same problem the hardcoded backdrops were: a colour the skin
--- cannot reach. Those sites cannot take r, g, b -- they are building a
--- string -- so they get the hex instead.
function W:Hex(key)
    local r, g, b = self:Color(key)
    return ("%02x%02x%02x"):format(
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5))
end

--- Wrap text in a skin colour.
---
--- The companion to Hex, for the commonest shape in the pages: a whole
--- string literal that is nothing but a colour code, some text, and the
--- terminator. Reads better than the format call at those sites and
--- keeps the escape codes in one place.
function W:Tint(key, text)
    return ("|cff%s%s|r"):format(self:Hex(key), text or "")
end

--- Tint an icon border by item quality.
---
--- Blue for rare, purple for epic, and so on -- the same colours the
--- game uses everywhere else, so a border carries rarity without a
--- legend. Falls back to the faint tone when a thing has no quality,
--- which is most currencies.
function W:SetIconQuality(border, quality)
    if not border then return end
    local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if c and c.r then
        border:SetVertexColor(c.r, c.g, c.b, 1)
    else
        border:SetVertexColor(self:Color("faint"))
    end
end

--- A surface. Roles are the skin's, not ours.
function W:Panel(parent, role)
    local s = skin()
    if s and s.Panel then return s:Panel(parent, role or "panel") end
    return CreateFrame("Frame", nil, parent)
end

--- Restyle a frame the caller already built.
---
--- This is how the feature pages join the skin system. They create their
--- frames for their own reasons -- scroll children, pooled rows, frames
--- that existed before any of this -- so `Panel` is no use to them.
--- Replacing a page's SetBackdrop block with one W:Apply call is a small
--- enough edit to do across nine files without rewriting any of them.
---
--- Returns the frame, so it drops into an existing expression.
function W:Apply(frame, role)
    if not frame then return frame end
    local s = skin()
    if s and s.Apply then return s:Apply(frame, role or "panel") end
    return frame
end

------------------------------------------------------------
-- Depth
--
-- Four gradients inside a panel's edges, black fading to nothing. This
-- is the single reason Vaultloom's panels look recessed and ours looked
-- printed on: a flat fill with a one-pixel border has no depth cue at
-- all, and no amount of colour choice fixes that.
--
-- Lives here rather than in a skin because both skins want it and one
-- implementation is enough. A skin decides whether to call it and how
-- strongly, which keeps the rule intact -- the skin still decides what
-- things look like.
------------------------------------------------------------

--- Black-to-transparent along one axis.
---
--- SetGradient first: SetGradientAlpha was removed from retail, so
--- trying the old name first would take the fallback path on every
--- current client and lose the gradient entirely.
local function gradient(tex, orientation, fromAlpha, toAlpha)
    tex:SetTexture("Interface\\Buttons\\WHITE8x8")
    local applied = false
    if tex.SetGradient and CreateColor then
        applied = pcall(tex.SetGradient, tex, orientation,
            CreateColor(0, 0, 0, fromAlpha), CreateColor(0, 0, 0, toAlpha))
    end
    if not applied and tex.SetGradientAlpha then
        applied = pcall(tex.SetGradientAlpha, tex, orientation,
            0, 0, 0, fromAlpha, 0, 0, 0, toAlpha)
    end
    if not applied then
        tex:SetColorTexture(0, 0, 0, math.max(fromAlpha, toAlpha) * 0.5)
    end
end

--- A one-pixel edge, drawn as four textures.
---
--- Exists because the alternative was Blizzard's InsetFrameTemplate
--- nine-slice, and putting that recessed metal border around every card
--- on every page reads as scrappy rather than as WoW: Blizzard uses it
--- for one or two regions per window, not for every block inside them.
--- Vaultloom draws no frame art at all on its inner surfaces -- its
--- panels are painted with a soft edge -- and a hairline is the closest
--- honest equivalent without shipping art.
---
--- Idempotent for the same reason InnerShadow is: skins repaint.
function W:Hairline(region, r, g, b, a)
    if not (region and region.CreateTexture) then return end
    local e = region._yyhEdge
    if not e then
        e = {}
        for _, k in ipairs({ "top", "bottom", "left", "right" }) do
            e[k] = region:CreateTexture(nil, "BORDER", nil, 6)
        end
        region._yyhEdge = e
    end

    e.top:ClearAllPoints()
    e.top:SetPoint("TOPLEFT")
    e.top:SetPoint("TOPRIGHT")
    e.top:SetHeight(1)

    e.bottom:ClearAllPoints()
    e.bottom:SetPoint("BOTTOMLEFT")
    e.bottom:SetPoint("BOTTOMRIGHT")
    e.bottom:SetHeight(1)

    e.left:ClearAllPoints()
    e.left:SetPoint("TOPLEFT")
    e.left:SetPoint("BOTTOMLEFT")
    e.left:SetWidth(1)

    e.right:ClearAllPoints()
    e.right:SetPoint("TOPRIGHT")
    e.right:SetPoint("BOTTOMRIGHT")
    e.right:SetWidth(1)

    for _, tex in pairs(e) do
        tex:SetColorTexture(r, g, b, a)
        tex:SetShown(a > 0)
    end
    return region
end

--- Recess `region`. Idempotent -- called again on the same frame it
--- reuses the textures rather than stacking a second set, which matters
--- because a skin swap re-skins panels that may already have one.
function W:InnerShadow(region, inset, thickness, alpha)
    if not (region and region.CreateTexture) then return end
    inset     = inset or 3
    thickness = thickness or 6
    alpha     = alpha or 0.35

    local s = region._yyhShadow
    if not s then
        s = {}
        for _, k in ipairs({ "top", "bottom", "left", "right" }) do
            s[k] = region:CreateTexture(nil, "BACKGROUND", nil, 7)
        end
        region._yyhShadow = s
    end

    s.top:ClearAllPoints()
    s.top:SetPoint("TOPLEFT", region, "TOPLEFT", inset, -inset)
    s.top:SetPoint("TOPRIGHT", region, "TOPRIGHT", -inset, -inset)
    s.top:SetHeight(thickness)
    gradient(s.top, "VERTICAL", 0, alpha)

    s.bottom:ClearAllPoints()
    s.bottom:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", inset, inset)
    s.bottom:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -inset, inset)
    s.bottom:SetHeight(thickness)
    gradient(s.bottom, "VERTICAL", alpha, 0)

    s.left:ClearAllPoints()
    s.left:SetPoint("TOPLEFT", region, "TOPLEFT", inset, -inset)
    s.left:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", inset, inset)
    s.left:SetWidth(thickness)
    gradient(s.left, "HORIZONTAL", alpha, 0)

    s.right:ClearAllPoints()
    s.right:SetPoint("TOPRIGHT", region, "TOPRIGHT", -inset, -inset)
    s.right:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -inset, inset)
    s.right:SetWidth(thickness)
    gradient(s.right, "HORIZONTAL", 0, alpha)

    for _, tex in pairs(s) do tex:Show() end
    return region
end

------------------------------------------------------------
-- Text
------------------------------------------------------------
function W:Label(parent, template, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetTextColor(self:Color("text"))
    if ns.ApplyTextShadow then ns.ApplyTextShadow(fs) end
    return fs
end

--- A section heading with the rule under it. One call rather than the
--- four every page currently writes, which is why no two of them line
--- up to the same baseline.
function W:SectionTitle(parent, text)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetHeight(22)

    -- GameFontNormal, not Small. A section heading set smaller than the
    -- body text under it reads as a caption rather than as a heading,
    -- which is what made the page look like undifferentiated rows.
    holder.text = self:Label(holder, "GameFontNormalLarge")
    holder.text:SetPoint("TOPLEFT", 0, 0)
    holder.text:SetText(text or "")
    holder.text:SetTextColor(self:Color("muted"))

    -- Blizzard's own section divider, from the Journeys renown list, set
    -- BESIDE the heading rather than under it.
    --
    -- It is a tapered ornament with its motif at the centre. Stretched
    -- under a heading across a 700px page it became a hairline with a
    -- speck in the middle -- which is what makes the headers look thin
    -- and hand-drawn. Running it from the end of the text to the right
    -- edge halves the span, puts the motif where it reads, and gives the
    -- shape Blizzard uses for this anyway: label, then rule.
    holder.rule = holder:CreateTexture(nil, "ARTWORK")
    holder.rule:SetHeight(14)
    holder.rule:SetPoint("LEFT", holder.text, "RIGHT", 12, -1)
    holder.rule:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
    -- Guarded like the backdrops, and this one matters most: every
    -- section heading on every page goes through here, so an atlas the
    -- client does not ship would not spoil one decoration -- it would
    -- abort whichever page was mid-build when it hit.
    local ruleOk = pcall(holder.rule.SetAtlas, holder.rule,
        "ui-journeys-renown-divider")
    if not (ruleOk and holder.rule:GetAtlas()) then
        -- The atlas is Midnight-era; on a client without it a line still
        -- beats nothing.
        holder.rule:SetHeight(1)
        local r, g, b = self:Color("muted")
        holder.rule:SetColorTexture(r, g, b, 0.25)
    end
    holder.rule:SetAlpha(1)

    function holder:SetText(t) holder.text:SetText(t) end
    return holder
end

------------------------------------------------------------
-- Rows and tiles
------------------------------------------------------------

--- icon | label | value. The shape of a currency row, a crest row and a
--- consumable row, which are currently three implementations.
function W:IconRow(parent, height)
    height = height or 24
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(height)

    -- Icon derived from the row rather than fixed at 16: a taller row
    -- with a small icon reads as a mistake, and the rail rows grew.
    local art = math.max(height - 6, 14)
    -- Interface\Common\WhiteIconFrame -- the tintable frame Blizzard's
    -- own item buttons draw around their icons. Vaultloom does the same
    -- thing with a rounded border of its own art; this is the native
    -- equivalent, and it beats the flat square that was here because it
    -- has a shaped edge rather than a hard bounding box.
    row.iconEdge = row:CreateTexture(nil, "OVERLAY")
    row.iconEdge:SetTexture(ICON_FRAME)
    row.iconEdge:SetVertexColor(self:Color("faint"))

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(art, art)
    row.icon:SetPoint("LEFT", 2, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.iconEdge:SetPoint("TOPLEFT", row.icon, -1, 1)
    row.iconEdge:SetPoint("BOTTOMRIGHT", row.icon, 1, -1)

    row.label = self:Label(row, "GameFontNormal")
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 9, 0)

    row.value = self:Label(row, "GameFontNormal", "RIGHT")
    row.value:SetPoint("RIGHT", -4, 0)
    row.value:SetTextColor(self:Color("text"))
    return row
end

--- A titled box with a filled surface behind it.
---
--- The shell had section headings drawn straight onto the window, so
--- related things sat next to unrelated things with nothing but a gap
--- between them. Vaultloom puts a panel behind every group; that is most
--- of why its rail reads as three sections rather than one long column.
---
--- Returns the outer frame. Fill `.body`, which is inset from the panel
--- edge so content never collides with the border art.
function W:Group(parent, title, role)
    local group = CreateFrame("Frame", nil, parent)

    group.title = self:Label(group, "GameFontNormalSmall")
    group.title:SetPoint("TOPLEFT", 2, 0)
    group.title:SetText(title or "")
    group.title:SetTextColor(self:Color("muted"))

    group.panel = self:Panel(group, role or "inset")
    group.panel:SetPoint("TOPLEFT", group.title, "BOTTOMLEFT", -2, -5)
    group.panel:SetPoint("BOTTOMRIGHT", group, "BOTTOMRIGHT", 0, 0)

    group.body = CreateFrame("Frame", nil, group.panel)
    group.body:SetPoint("TOPLEFT", 8, -8)
    group.body:SetPoint("BOTTOMRIGHT", -8, 8)

    function group:SetTitle(t) group.title:SetText(t) end
    return group
end

--- An icon with its count underneath. The crest strip, and anything else
--- that wants to be read at a glance rather than line by line.
function W:IconTile(parent, size)
    size = size or 34
    local tile = CreateFrame("Frame", nil, parent)
    tile:SetSize(size + 6, size + 18)

    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetSize(size, size)
    tile.icon:SetPoint("TOP")
    tile.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- A visible edge by default, tinted by SetEdge where a colour means
    -- something. Previously transparent until something called SetEdge,
    -- so crest icons sat borderless on the panel.
    tile.border = tile:CreateTexture(nil, "OVERLAY")
    tile.border:SetTexture(ICON_FRAME)
    tile.border:SetPoint("TOPLEFT", tile.icon, -2, 2)
    tile.border:SetPoint("BOTTOMRIGHT", tile.icon, 2, -2)
    tile.border:SetVertexColor(self:Color("faint"))

    -- Mouse-enabled with a highlight. These are currency icons with
    -- tooltips worth reading -- weekly caps, season totals -- and a tile
    -- that does nothing on hover reads as decoration rather than data.
    tile:EnableMouse(true)
    tile.hl = tile:CreateTexture(nil, "HIGHLIGHT")
    tile.hl:SetPoint("TOPLEFT", tile.icon, -2, 2)
    tile.hl:SetPoint("BOTTOMRIGHT", tile.icon, 2, -2)
    tile.hl:SetColorTexture(1, 1, 1, 0.18)

    tile:SetScript("OnEnter", function(self2)
        if not self2._currencyID then return end
        GameTooltip:SetOwner(self2, "ANCHOR_RIGHT")
        GameTooltip:SetCurrencyByID(self2._currencyID)
        GameTooltip:Show()
    end)
    tile:SetScript("OnLeave", function() GameTooltip:Hide() end)

    tile.count = self:Label(tile, "GameFontNormalSmall", "CENTER")
    tile.count:SetPoint("TOP", tile.icon, "BOTTOM", 0, -3)
    tile.count:SetPoint("LEFT")
    tile.count:SetPoint("RIGHT")

    --- Tint the icon's edge. Used for crest track colours, which are the
    --- one place in the addon where a colour carries meaning the text
    --- does not repeat.
    function tile:SetEdge(r, g, b)
        if r then
            tile.border:SetVertexColor(r, g, b, 1)
        else
            tile.border:SetVertexColor(ns.Widgets:Color("faint"))
        end
    end
    return tile
end

--- A scrolling column. Anchor children to `.content`, then call
--- SetContentHeight so the scroll range matches what you put in it.
function W:ScrollList(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll.content = content

    function scroll:SetContentHeight(h)
        content:SetHeight(math.max(h, 1))
        content:SetWidth(math.max(scroll:GetWidth() or 1, 1))
    end
    return scroll
end

--- Several stats on one surface, divided by hairlines.
---
--- Replaces a row of StatTiles. Three tiles side by side is three
--- bordered boxes carrying three numbers that belong together; one
--- surface split by two thin rules says the same thing with a third of
--- the edges. The page had reached the point where every piece of
--- information sat in its own box, which is its own kind of noise.
---
--- Returns the strip. `strip.cells[i]` each have SetValue(text, colour).
function W:StatStrip(parent, labels)
    local strip = self:Panel(parent, "inset")
    strip:SetHeight(54)
    strip.cells = {}

    for i, label in ipairs(labels) do
        local cell = CreateFrame("Frame", nil, strip)
        cell.label = self:Label(cell, "GameFontNormalSmall")
        cell.label:SetPoint("TOPLEFT", 12, -9)
        cell.label:SetText(label)
        cell.label:SetTextColor(self:Color("muted"))

        cell.value = self:Label(cell, "GameFontNormalLarge")
        cell.value:SetPoint("BOTTOMLEFT", 12, 10)
        cell.value:SetPoint("RIGHT", cell, "RIGHT", -8, 0)
        cell.value:SetWordWrap(false)

        if i > 1 then
            cell.rule = cell:CreateTexture(nil, "ARTWORK")
            cell.rule:SetWidth(1)
            cell.rule:SetPoint("TOPLEFT", 0, -10)
            cell.rule:SetPoint("BOTTOMLEFT", 0, 10)
            local r, g, b = self:Color("muted")
            cell.rule:SetColorTexture(r, g, b, 0.22)
        end

        function cell:SetValue(text, colorKey)
            cell.value:SetText(text or "")
            cell.value:SetTextColor(ns.Widgets:Color(colorKey or "text"))
        end
        strip.cells[i] = cell
    end

    --- Cells are laid out on demand: the strip has no width until the
    --- page that owns it has been sized.
    function strip:Layout()
        local w = strip:GetWidth() or 0
        if w <= #strip.cells then return end
        local cw = w / #strip.cells
        for i, cell in ipairs(strip.cells) do
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", strip, "TOPLEFT", (i - 1) * cw, 0)
            cell:SetSize(cw, strip:GetHeight() or 54)
        end
    end
    return strip
end

------------------------------------------------------------
-- Hero card
--
-- Who you are, at the top of the page. The old dashboard never said,
-- which is fine when the addon is one character's gear sheet and wrong
-- the moment it is nine pages about a specific character.
------------------------------------------------------------
--- The hero card's backdrop.
---
--- ui-journeys-renown-button is the warm gold card from Blizzard's own
--- Journeys frame. It is authored at 374x112 and our hero card is 112
--- tall by contract, so it stretches on one axis only -- which is the
--- difference between borrowing a card texture and distorting one.
---
--- Deliberately NOT talents-background-<class>-<spec>. Those are good
--- art, but they are exactly what Vaultloom puts behind its character
--- card, and having the same painting in the same place is most of what
--- made the two addons look alike.
local HERO_ATLAS = "ui-journeys-renown-button"

function W:HeroCard(parent)
    -- A plain frame, NOT a skinned panel.
    --
    -- It used to ask for an "inset" surface, which drew its own fill and
    -- gold hairline behind the sign -- so the card came out as a box
    -- inside a box: the skin's panel, then the sign art's own plate, then
    -- the sign. The column now carries that plate as its background, so
    -- the card needs no surface of its own and the sign sits directly on
    -- it.
    local card = CreateFrame("Frame", nil, parent)
    local height = (ns.Shell and ns.Shell.HERO_H) or 112
    card:SetHeight(height)

    -- Painted spec art behind the card, faded out toward the right so
    -- the name and item level stay readable over it. Clipped to the card
    -- so a tall atlas does not spill onto the page.
    card:SetClipsChildren(true)
    card.art = card:CreateTexture(nil, "BACKGROUND", nil, 1)
    card.art:SetPoint("TOPLEFT", 1, -1)
    card.art:SetPoint("BOTTOMRIGHT", -1, 1)
    -- pcall for the same reason as the column backdrop: SetAtlas raises
    -- on an unknown name, and this runs while the card is being built,
    -- so an atlas that is not there would take the whole hero card with
    -- it rather than just its background.
    local heroOk = pcall(card.art.SetAtlas, card.art, HERO_ATLAS)
    card.art:SetShown(heroOk and card.art:GetAtlas() ~= nil)
    card.art:SetAlpha(0.9)

    -- Portrait sized from the card rather than fixed, so raising HERO_H
    -- grows the art instead of leaving a small icon in a tall box.
    local art = height - 44
    card.portrait = card:CreateTexture(nil, "ARTWORK")
    card.portrait:SetSize(art, art)
    card.portrait:SetPoint("LEFT", 20, 0)
    card.portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Circular, via the mask Blizzard's own portrait frames use. There is
    -- no standalone ring texture to borrow -- in PortraitFrameTemplate the
    -- gold ring is painted into the nine-slice corner atlas, so it only
    -- exists at that one size in that one corner.
    if card.CreateMaskTexture then
        local mask = card:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(card.portrait)
        card.portrait:AddMaskTexture(mask)
        card.portraitMask = mask
    end

    -- A ring, from the same Journeys family as the sign itself. A masked
    -- circle with no edge reads as a hole cut in the card; the ring gives
    -- it a rim and ties it to the art around it.
    card.ring = card:CreateTexture(nil, "OVERLAY")
    card.ring:SetPoint("CENTER", card.portrait, "CENTER", 0, 0)
    card.ring:SetSize(art * 1.18, art * 1.18)
    if not pcall(card.ring.SetAtlas, card.ring, "ui-journeys-delve-companion-ring")
        or not card.ring:GetAtlas() then
        card.ring:Hide()
    end

    -- Two lines, not three.
    --
    -- The card kept fighting itself over horizontal room: the name and
    -- the item level shared line one and collided, so the number moved to
    -- its own line at the bottom -- which then squeezed the spec down to
    -- "Balance..." and left an awkward gap. Two lines settle it. The name
    -- owns the first outright, and the second pairs the spec on the left
    -- with the item level on the right, which is a natural split because
    -- one is words and the other is a number.
    card.name = self:Label(card, "GameFontNormalLarge")
    card.name:SetPoint("TOPLEFT", card.portrait, "TOPRIGHT", 16, -14)
    card.name:SetPoint("RIGHT", card, "RIGHT", -44, 0)
    card.name:SetWordWrap(false)
    card.name:SetJustifyH("LEFT")

    card.ilvlLabel = self:Label(card, "GameFontNormalSmall", "RIGHT")
    card.ilvlLabel:SetPoint("TOPRIGHT", card.name, "BOTTOMRIGHT", 22, -7)
    card.ilvlLabel:SetText("ilvl")
    card.ilvlLabel:SetTextColor(self:Color("muted"))

    card.ilvlValue = self:Label(card, "GameFontNormal", "RIGHT")
    card.ilvlValue:SetPoint("RIGHT", card.ilvlLabel, "LEFT", -5, 0)

    card.meta = self:Label(card, "GameFontNormalSmall")
    card.meta:SetPoint("LEFT", card.name, "LEFT", 1, 0)
    card.meta:SetPoint("TOP", card.ilvlLabel, "TOP", 0, 0)
    card.meta:SetPoint("RIGHT", card.ilvlValue, "LEFT", -10, 0)
    card.meta:SetWordWrap(false)
    card.meta:SetTextColor(self:Color("muted"))

    -- Character switcher. A placeholder on purpose: the button and its
    -- corner are the part worth settling now, because where it sits
    -- changes the card's layout and the rest does not. It says so on
    -- hover rather than opening an empty menu, which is the difference
    -- between "not built yet" and "broken".
    card.swap = CreateFrame("Button", nil, card)
    card.swap:SetSize(22, 22)
    card.swap:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -12)

    card.swap.arrow = card.swap:CreateTexture(nil, "ARTWORK")
    card.swap.arrow:SetAllPoints()
    card.swap.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    card.swap.arrow:SetVertexColor(self:Color("muted"))

    card.swap:SetScript("OnEnter", function(self2)
        card.swap.arrow:SetVertexColor(ns.Widgets:Color("text"))
        GameTooltip:SetOwner(self2, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText("Switch character")
        GameTooltip:AddLine("Not wired up yet.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    card.swap:SetScript("OnLeave", function()
        card.swap.arrow:SetVertexColor(ns.Widgets:Color("muted"))
        GameTooltip:Hide()
    end)

    function card:Refresh()
        -- Re-read on refresh, not at build: the player can change spec
        -- with the window open, and the art should follow them.

        SetPortraitTexture(card.portrait, "player")
        local className, classFile = UnitClass("player")

        -- The sign takes the class colour. Blended halfway to white
        -- rather than applied straight: the card art is already a warm
        -- painted texture, and multiplying it by a saturated class
        -- colour turns it muddy. Half-strength reads as "tinted" and
        -- keeps the art's own shading.
        local cc = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
        if cc and cc.r then
            card.art:SetVertexColor(
                cc.r + (1 - cc.r) * 0.5,
                cc.g + (1 - cc.g) * 0.5,
                cc.b + (1 - cc.b) * 0.5)
        else
            card.art:SetVertexColor(1, 1, 1)
        end
        local specName
        if GetSpecialization then
            local idx = GetSpecialization()
            if idx then specName = select(2, GetSpecializationInfo(idx)) end
        end
        local colour = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
        local nameText = UnitName("player") or ""
        if colour and colour.WrapTextInColorCode then
            nameText = colour:WrapTextInColorCode(nameText)
        end
        card.name:SetText(nameText)

        -- Item level moved out of the meta line and onto its own figure,
        -- so the sentence reads as who you are and the number reads as
        -- where you are.
        local equipped
        if GetAverageItemLevel then
            local _, eq = GetAverageItemLevel()
            equipped = tonumber(eq)
        end
        card.ilvlValue:SetText(equipped and tostring(math.floor(equipped)) or "--")
        card.ilvlValue:SetTextColor(ns.Widgets:Color(equipped and "accent" or "muted"))
        card.ilvlLabel:SetShown(equipped ~= nil)

        -- Spec and class only. "Level 90 Balance Druid" does not fit the
        -- column and was rendering as "Level 90 Balance..." -- cutting
        -- the class, which is the half that identifies you. The level is
        -- the least interesting of the three at cap, so it goes, and it
        -- comes back only while it still means something.
        local level = UnitLevel("player") or 0
        local capped = not MAX_PLAYER_LEVEL or level >= MAX_PLAYER_LEVEL
        card.meta:SetText(capped
            and ("%s %s"):format(specName or "", className or "")
            or ("%s %s  |cff888888%d|r"):format(specName or "", className or "", level))
    end
    return card
end
