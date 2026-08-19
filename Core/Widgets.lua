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

--- The inverse of Hex, for colours the addon stores as escape codes.
---
--- Accepts "aarrggbb" or "rrggbb" and returns r, g, b as floats, or nil
--- if it is neither. ns.CRESTS keeps its track colours as "ff1eff00"
--- because their commonest use is string concatenation, but a texture
--- tint needs numbers, and parsing them at each call site is how two
--- copies of this drift apart.
function W:HexToRGB(hex)
    if type(hex) ~= "string" then return nil end
    if #hex == 8 then hex = hex:sub(3) end
    if #hex ~= 6 then return nil end
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    if not (r and g and b) then return nil end
    return r / 255, g / 255, b / 255
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

-- Assigned in the rounded-surfaces section below. Apply has to be able
-- to strip the corner art off a pooled frame before repainting it
-- square, and it sits above the thing that does the rounding.
local unround

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
    -- A pooled frame that was a rounded card last render is a square
    -- panel this one, and its corners do not go away on their own.
    if unround then unround(frame) end
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

--- Set an atlas only if this client actually ships it, and say whether
--- it took.
---
--- Asked of C_Texture first rather than just pcall'd: SetAtlas with an
--- unknown name can succeed and leave the texture blank, which is a
--- silent hole rather than a caught failure. Callers use the return to
--- choose a fallback, which is the whole point -- every atlas in this
--- addon has to survive not existing.
function W:TrySetAtlas(tex, name)
    if not (tex and name) then return false end
    if C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo(name) then
        return false
    end
    local ok = pcall(tex.SetAtlas, tex, name)
    return (ok and tex:GetAtlas() ~= nil) and true or false
end

--- A chosen colour fading to nothing along one axis.
---
--- The private `gradient` above is black-only, for shading. This is the
--- same three-step guard for an arbitrary colour, because a surface
--- tinted by its state wants the tint to fall away rather than sit
--- there as a flat panel of colour competing with its own contents.
function W:ColourWash(tex, orientation, r, g, b, fromAlpha, toAlpha)
    tex:SetTexture("Interface\\Buttons\\WHITE8x8")
    local applied = false
    if tex.SetGradient and CreateColor then
        applied = pcall(tex.SetGradient, tex, orientation,
            CreateColor(r, g, b, fromAlpha), CreateColor(r, g, b, toAlpha))
    end
    if not applied and tex.SetGradientAlpha then
        applied = pcall(tex.SetGradientAlpha, tex, orientation,
            r, g, b, fromAlpha, r, g, b, toAlpha)
    end
    if not applied then
        tex:SetColorTexture(r, g, b, (fromAlpha + toAlpha) * 0.5)
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
-- Rounded surfaces
--
-- A corner is art, not geometry. There is no radius to set on a frame,
-- so a rounded card is a rectangle whose own fill stops short of its
-- corners with a quarter-disc dropped into each gap.
--
-- The tiles are ours -- Tools/make_round_corners.py -- rather than one
-- of Blizzard's mask atlases, because those names drift between builds.
-- Baganator ships a runtime check choosing between "common-mask-circle"
-- and "CircleMaskScalable" depending on which one the client has, and an
-- atlas that resolves to nothing leaves a square corner nobody notices
-- until a patch day.
--
-- Both tiles are white with the shape in their alpha, so the colour is
-- whatever the skin hands over for that role. The rule holds: the skin
-- still decides what a surface looks like, and this only decides the
-- shape it is cut to.
------------------------------------------------------------
local ROUND_FILL = "Interface\\AddOns\\YippYappHelper\\Media\\RoundFill"
local ROUND_EDGE = "Interface\\AddOns\\YippYappHelper\\Media\\RoundEdge"

-- One tile drawn four ways. The file is a rounded rectangle's top-left
-- corner; the other three are the same art with its texture coordinates
-- flipped, which is why there is one file and not four.
local CORNER_UV = {
    TOPLEFT     = { 0, 1, 0, 1 },
    TOPRIGHT    = { 1, 0, 0, 1 },
    BOTTOMLEFT  = { 0, 1, 1, 0 },
    BOTTOMRIGHT = { 1, 0, 1, 0 },
}
local CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }

local WHITE8 = "Interface\\Buttons\\WHITE8x8"

--- Paint a piece a flat colour.
---
--- Every piece is white art, so the vertex colour is the whole of its
--- colour -- alpha included, which is what lets one tile serve a surface
--- drawn at 0.8 and one drawn opaque.
local function solidPaint(r, g, b, a)
    return function(tex) tex:SetVertexColor(r, g, b, a) end
end

--- Paint a piece its slice of a fade running left to right.
---
--- Strongest at the left and falling away, which is where a card wants
--- it: the art sits on the left and the wash is what carries its colour
--- out under the text rather than stopping at the icon's edge.
---
--- Eased rather than linear. A straight ramp keeps too much colour in
--- the middle of the card and reads as a card that is simply tinted,
--- which is the thing the fade exists to avoid.
local function washPaint(r, g, b, peak)
    local function at(t) return peak * (1 - t) ^ 1.6 end
    return function(tex, t0, t1)
        if tex.SetGradient and CreateColor then
            local ok = pcall(tex.SetGradient, tex, "HORIZONTAL",
                CreateColor(r, g, b, at(t0)), CreateColor(r, g, b, at(t1)))
            if ok then return end
        end
        -- No gradient on this client: a flat wash at the fade's average
        -- is duller than the real thing but still says which card is
        -- which, which is the job.
        tex:SetVertexColor(r, g, b, (at(t0) + at(t1)) * 0.5)
    end
end

--- The four corner tiles of one rounded rectangle.
local function cornerArt(region, store, path, layer, sub, radius, paint, t0, t1)
    for _, k in ipairs(CORNERS) do
        local tex = store[k]
        if not tex then
            tex = region:CreateTexture(nil, layer, nil, sub)
            tex:SetTexture(path)
            tex:SetTexCoord(unpack(CORNER_UV[k]))
            store[k] = tex
        end
        tex:ClearAllPoints()
        tex:SetPoint(k, region, k, 0, 0)
        tex:SetSize(radius, radius)
        -- Left-hand corners take the left end of the span, right-hand
        -- ones the right end.
        if k == "TOPLEFT" or k == "BOTTOMLEFT" then
            paint(tex, t0, t1)
        else
            paint(tex, 1 - t1, 1 - t0)
        end
        tex:Show()
    end
end

--- The body of a rounded rectangle: everything but its corners, painted
--- by `paint`.
---
--- Three rects, not a cross of two. These surfaces are semi-transparent
--- and where a full-width band crosses a full-height one the overlap
--- paints itself twice, which reads as a brighter cross through the
--- middle of the card.
---
--- `paint` is handed each piece and where that piece sits across the
--- shape -- 0 at the left edge, 1 at the right. A flat colour ignores
--- the span; a fade needs it, because seven separate textures only read
--- as one continuous gradient if each picks the ramp up exactly where
--- the piece before it left off.
local function roundedLayer(region, key, layer, sub, radius, width, paint)
    local s = region[key]
    if not s then
        s = { corners = {} }
        for _, k in ipairs({ "mid", "left", "right" }) do
            s[k] = region:CreateTexture(nil, layer, nil, sub)
            -- White art plus a vertex colour, never SetColorTexture: a
            -- gradient replaces the vertex colour, and a piece that had
            -- its colour baked into the texture would ignore it.
            s[k]:SetTexture(WHITE8)
        end
        region[key] = s
    end

    -- Full height, between the two columns of corners.
    s.mid:ClearAllPoints()
    s.mid:SetPoint("TOPLEFT", region, "TOPLEFT", radius, 0)
    s.mid:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -radius, 0)

    -- The strips either side of it, stopping short of the corner tiles.
    s.left:ClearAllPoints()
    s.left:SetPoint("TOPLEFT", region, "TOPLEFT", 0, -radius)
    s.left:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 0, radius)
    s.left:SetWidth(radius)

    s.right:ClearAllPoints()
    s.right:SetPoint("TOPRIGHT", region, "TOPRIGHT", 0, -radius)
    s.right:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, radius)
    s.right:SetWidth(radius)

    -- Where each piece sits across the shape. The corner columns are
    -- `radius` wide at both ends, so the middle runs between them.
    local w = math.max(width or region:GetWidth() or 0, 1)
    local t = math.min(radius / w, 0.5)

    paint(s.left, 0, t)
    paint(s.mid, t, 1 - t)
    paint(s.right, 1 - t, 1)
    for _, k in ipairs({ "mid", "left", "right" }) do s[k]:Show() end
    cornerArt(region, s.corners, ROUND_FILL, layer, sub, radius, paint, 0, t)
end

--- The hairline around one, with its corners turned.
---
--- A ring rather than a second filled disc under the fill: these
--- surfaces are semi-transparent, so a disc behind one shows its border
--- colour through the whole card instead of only at the edge.
local function roundedEdge(region, radius, r, g, b, a)
    local s = region._yyhRoundEdge
    if not s then
        s = { corners = {} }
        for _, k in ipairs({ "top", "bottom", "left", "right" }) do
            s[k] = region:CreateTexture(nil, "BORDER", nil, 6)
        end
        region._yyhRoundEdge = s
    end

    s.top:ClearAllPoints()
    s.top:SetPoint("TOPLEFT", region, "TOPLEFT", radius, 0)
    s.top:SetPoint("TOPRIGHT", region, "TOPRIGHT", -radius, 0)
    s.top:SetHeight(1)

    s.bottom:ClearAllPoints()
    s.bottom:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", radius, 0)
    s.bottom:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -radius, 0)
    s.bottom:SetHeight(1)

    s.left:ClearAllPoints()
    s.left:SetPoint("TOPLEFT", region, "TOPLEFT", 0, -radius)
    s.left:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 0, radius)
    s.left:SetWidth(1)

    s.right:ClearAllPoints()
    s.right:SetPoint("TOPRIGHT", region, "TOPRIGHT", 0, -radius)
    s.right:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, radius)
    s.right:SetWidth(1)

    local paint = solidPaint(r, g, b, a)
    for _, k in ipairs({ "top", "bottom", "left", "right" }) do
        s[k]:SetColorTexture(r, g, b, a)
        s[k]:Show()
    end
    cornerArt(region, s.corners, ROUND_EDGE, "BORDER", 6, radius, paint, 0, 1)
end

local function hideRoundKey(region, key)
    local s = region[key]
    if not s then return end
    for k, tex in pairs(s) do
        if k == "corners" then
            for _, c in pairs(tex) do c:Hide() end
        else
            tex:Hide()
        end
    end
end

-- Forward-declared above Apply. See the note there.
function unround(frame)
    if not frame then return end
    hideRoundKey(frame, "_yyhRoundFill")
    hideRoundKey(frame, "_yyhRoundWash")
    hideRoundKey(frame, "_yyhRoundEdge")
end

--- The skin's flat colours for a role: fill first, then edge.
---
--- nil when the skin paints that role with tiled art instead. A corner
--- tile has one colour to be, so rounding the Blizzlike window would
--- mean throwing its marble away -- and the grain is the entire reason
--- that surface reads as material. Better to leave it square.
function W:Surface(role)
    local s = skin()
    if s and s.Surface then
        local fill, edge = s:Surface(role or "inset")
        if fill then return fill, edge end
    end
    return nil
end

--- A surface with rounded corners.
---
--- Same contract as Apply: hand it a frame you already built, get the
--- frame back. Idempotent for the same reason, too -- pages refresh far
--- more often than they rebuild, and a second call has to repaint rather
--- than lay a second set of corners over the first.
---
--- Falls back to a square Apply when the skin has no flat colour for the
--- role, so a caller never has to ask which skin is running.
---
--- `opts.fill` and `opts.edge` override the skin's colours for one
--- frame, and `opts.wash` = { r, g, b, peak } lays a fade across it,
--- strongest at the left. All three are for STATE -- the card of the
--- build you are specced into, a row that failed -- and not for taste: a
--- caller that wants a different colour because it prefers one is the
--- thing the whole skin layer exists to stop. Callers are expected to
--- derive the override from W:Surface so it still moves with the skin.
---
--- Call this AFTER sizing the frame. The wash divides the shape by its
--- width to know where each piece sits in the fade, so a frame still at
--- its default size gets a gradient scaled to the wrong card.
function W:Rounded(frame, role, radius, opts)
    if not (frame and frame.CreateTexture) then return frame end
    role = role or "inset"
    local fill, edge = self:Surface(role)
    if not fill then return self:Apply(frame, role) end
    if opts then
        fill = opts.fill or fill
        edge = opts.edge or edge
    end

    radius = radius or 8
    -- The square painting goes first, or its backdrop draws a right
    -- angle straight across every corner we are about to round.
    if frame.SetBackdrop then frame:SetBackdrop(nil) end
    if frame._yyhFill then frame._yyhFill:Hide() end
    if frame._yyhEdge then
        for _, tex in pairs(frame._yyhEdge) do tex:Hide() end
    end
    -- The inner shadow too. It is four straight gradients, so inside a
    -- rounded card it reads as a square shadow floating in one.
    if frame._yyhShadow then
        for _, tex in pairs(frame._yyhShadow) do tex:Hide() end
    end

    local width = frame:GetWidth()
    roundedLayer(frame, "_yyhRoundFill", "BACKGROUND", -8, radius, width,
        solidPaint(fill[1], fill[2], fill[3], fill[4] or 1))

    -- Over the fill and under the edge, on the same shape, so the fade
    -- reaches the corners instead of stopping in a square short of them.
    local w = opts and opts.wash
    if w then
        roundedLayer(frame, "_yyhRoundWash", "BACKGROUND", -7, radius, width,
            washPaint(w[1], w[2], w[3], w[4] or 0.25))
    else
        hideRoundKey(frame, "_yyhRoundWash")
    end

    if edge then
        roundedEdge(frame, radius, edge[1], edge[2], edge[3], edge[4] or 1)
    else
        hideRoundKey(frame, "_yyhRoundEdge")
    end
    frame._yyhSkinned = role
    return frame
end

--- Strip a surface back to nothing.
---
--- SetBackdrop(nil) is what the pages were all using, and it is half the
--- job. A skinned panel is a backdrop PLUS an inner shadow, and that
--- shadow is four gradient textures living on the frame -- nothing to do
--- with the backdrop, and completely untouched by clearing it.
---
--- So every page that went into the shell cleared its backdrop and kept
--- its shading: a dark vignette drawn inside a region that was supposed
--- to be flush with the shell around it. That is the indented background
--- that appeared on page after page, and why it survived each page being
--- "fixed" individually -- the leftover was never the backdrop.
function W:Unskin(frame)
    if not frame then return frame end
    if frame.SetBackdrop then frame:SetBackdrop(nil) end
    if frame._yyhFill then frame._yyhFill:Hide() end
    if frame._yyhEdge then
        for _, tex in pairs(frame._yyhEdge) do tex:Hide() end
    end
    if frame._yyhShadow then
        for _, tex in pairs(frame._yyhShadow) do tex:Hide() end
    end
    if unround then unround(frame) end
    frame._yyhSkinned = nil
    return frame
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

--- A mouse target the width of a FontString's TEXT, not of its row.
---
--- Rows are as wide as their column, and their text almost never is. A
--- tooltip hung off the row therefore fires anywhere along it -- three
--- inches of empty space to the right of a short item name still counts
--- as hovering that item -- which makes the whole list feel like one
--- twitchy surface and makes a second thing in the same row (a source, a
--- count, a link) impossible to hover on its own.
---
--- FontStrings cannot take mouse input themselves, so this is the frame
--- that stands in for one. It is re-fitted on every call because the
--- text changes with every render and its width changes with it.
---
--- Clicks pass through to the row.
---
--- The target sits ON TOP of the row to receive the mouse, and a
--- mouse-enabled frame consumes clicks as well as motion -- the same
--- thing that made the battle-res timer eat keybinds. A row that carries
--- a right-click menu would have lost it over exactly the text people
--- aim at, so anything landing here is forwarded to the row's own
--- handler.
---
--- Pass `pad` where the text is followed by something you want included
--- in the same target (a trailing marker, say).
function W:TextHover(fs, pad)
    if not fs then return nil end
    local row = fs:GetParent()
    if not row then return nil end

    local hover = fs._yyHover
    if not hover then
        hover = CreateFrame("Button", nil, row)
        hover:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        hover:SetScript("OnClick", function(self, button, ...)
            local owner = self._row
            local fn = owner and owner:GetScript("OnClick")
            if fn then fn(owner, button, ...) end
        end)
        fs._yyHover = hover
    end

    hover._row = row
    hover:SetParent(row)
    -- Above the row, or the row's own surface takes the mouse first.
    -- See the frame-level rule: strata and level decide who gets the
    -- pointer, and draw layer has nothing to do with it.
    hover:SetFrameLevel((row:GetFrameLevel() or 1) + 1)
    hover:ClearAllPoints()
    hover:SetPoint("TOPLEFT", fs, "TOPLEFT", 0, 0)

    -- The text's own extent, clamped to the room the FontString was
    -- given: GetStringWidth reports what the string WOULD take, which on
    -- a truncated name is wider than what is drawn.
    local textW = fs:GetStringWidth() or 0
    local boxW = fs:GetWidth() or 0
    if boxW > 0 and textW > boxW then textW = boxW end
    hover:SetWidth(math.max(textW + (pad or 0), 1))
    hover:SetHeight(math.max(fs:GetStringHeight() or 0, 10))

    hover:EnableMouse(true)
    hover:Show()
    return hover
end

--- Puts a text hover away with the row that owned it.
---
--- Pools hide the row, and a child hidden by its parent is fine -- but a
--- re-used row is re-fitted before it is shown again, and a target left
--- at the previous render's width would take the mouse over text that is
--- no longer there.
function W:ClearTextHover(fs)
    local hover = fs and fs._yyHover
    if hover then
        hover:EnableMouse(false)
        hover:Hide()
    end
end

-- The heading's own line box, above the rule that sits under it.
local RULE_TOP = 18

--- A section heading with the rule under it. One call rather than the
--- four every page currently writes, which is why no two of them line
--- up to the same baseline.
function W:SectionTitle(parent, text)
    local holder = CreateFrame("Frame", nil, parent)
    -- The text's line box plus the rule under it. Callers stack their
    -- content off this frame's bottom, so the rule has to be inside the
    -- height rather than hanging out of it.
    holder:SetHeight(RULE_TOP + 14)

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

    -- Under the heading, and the full width of it.
    --
    -- Beside the heading the rule could only ever start where that
    -- heading's text ended, so its length was decided by how long the
    -- word happened to be -- "Stats" got a long one, "Item Upgrades" a
    -- short one -- and this ornament carries its motif at its own
    -- centre, which put a row of diamonds at as many different offsets
    -- as there were headings. Underneath, every rule is the same length
    -- and every motif lands on one vertical line, because none of it
    -- depends on the text any more.
    holder.rule:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -RULE_TOP)
    holder.rule:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, -RULE_TOP)

    -- A right-aligned aside on the heading's own line, for the one fact
    -- that qualifies a whole section. SectionCard has had this since it
    -- was written; SectionTitle did not, so pages that wanted it were
    -- spending a whole section -- heading, rule and a row of cells -- on
    -- something that fits in six words.
    holder.value = self:Label(holder, "GameFontNormalSmall", "RIGHT")
    holder.value:SetPoint("TOPRIGHT", 0, -3)
    holder.value:SetTextColor(self:Color("muted"))

    function holder:SetText(t) holder.text:SetText(t) end
    function holder:SetValue(t) holder.value:SetText(t or "") end
    return holder
end

-- The heading's own height, above the card it introduces.
local SECTION_TITLE_H = 24

--- A titled section: the heading, and the card its contents sit in,
--- with ONE line between them doing both jobs.
---
--- The pages that needed this were drawing two. Teleports put an
--- ornamental rule beside each expansion heading and then started a
--- bordered panel a few pixels underneath it, so every section carried
--- two horizontal lines a hair apart saying the same thing -- and the
--- rule said strictly less, because a panel edge also tells you where
--- the section ENDS. Here the divider sits ON the card's top edge, so
--- the ornament and the boundary are the same line.
---
--- The caller sizes it through Layout rather than by anchoring the
--- pieces, because the card is rounded and rounding has to be painted
--- after the width is known.
function W:SectionCard(parent, radius)
    local s = CreateFrame("Frame", nil, parent)

    s.title = self:Label(s, "GameFontNormalLarge")
    s.title:SetPoint("TOPLEFT", 0, 0)
    s.title:SetTextColor(self:Color("muted"))

    -- Right-aligned, for the count or progress a section usually wants
    -- to state. Optional: left empty it simply takes no room.
    s.value = self:Label(s, "GameFontNormalSmall", "RIGHT")
    s.value:SetPoint("TOPRIGHT", 0, -4)
    s.value:SetTextColor(self:Color("faint"))

    -- The title stops where the value starts, and does not wrap.
    --
    -- Both were anchored by one corner with nothing between them, so a
    -- long value grew leftward UNDER the title -- which is what put the
    -- raid guide's fight summary on top of the words "Before you pull".
    -- Bounded, the worst case is a title that ellipsises, which is a
    -- readable failure instead of two strings in the same pixels. Wrap
    -- stays off because the heading has a fixed 24px line to live in and
    -- a second line would print over the card's top edge.
    --
    -- Anchored corner to corner rather than by RIGHT to LEFT: a RIGHT
    -- anchor sets the vertical CENTRE, and a string already given its top
    -- by TOPLEFT would then be over-constrained and have its height
    -- solved from the two. The +4 cancels the value's own offset so both
    -- anchors agree the top is 0.
    s.title:SetWordWrap(false)
    s.title:SetPoint("TOPRIGHT", s.value, "TOPLEFT", -8, 4)

    s.body = CreateFrame("Frame", nil, s, "BackdropTemplate")
    s.body:SetPoint("TOPLEFT", s, "TOPLEFT", 0, -SECTION_TITLE_H)
    s.body:SetPoint("TOPRIGHT", s, "TOPRIGHT", 0, -SECTION_TITLE_H)

    -- Both pinned to the PARENT's frame level.
    --
    -- A child frame defaults to parent + 1, and frame level beats draw
    -- layer -- so the card sat a level above the content frame and its
    -- fill painted straight over every row anchored to that frame. The
    -- rows were still drawn; they were underneath a brown rectangle.
    --
    -- Pages that parent their rows INTO the body would not have noticed.
    -- The ones that anchor rows to a shared content frame and let the
    -- card slide behind them -- Consumables, Teleports, the Loot Browser
    -- -- are why this has to be said out loud rather than left to the
    -- default.
    -- BELOW the host, not level with it.
    --
    -- Level-with-it works only while every piece of content sits on the
    -- host itself or on a child above it, and that is an assumption
    -- about each caller rather than a property of this widget. A card
    -- that is one level under its host is behind ALL of it, whatever the
    -- caller does -- which is what a background is supposed to be.
    s._level = math.max((parent:GetFrameLevel() or 1) - 1, 0)
    s:SetFrameLevel(s._level)
    s.body:SetFrameLevel(s._level)

    -- Centred on the card's top edge, not above it. A 14px ornament
    -- anchored by its middle to the boundary is what makes the two read
    -- as one thing rather than as a rule with a box under it.
    s.rule = s:CreateTexture(nil, "OVERLAY")
    s.rule:SetHeight(14)
    s.rule:SetPoint("LEFT", s.body, "TOPLEFT", 0, 0)
    s.rule:SetPoint("RIGHT", s.body, "TOPRIGHT", 0, 0)
    local ruleOk = pcall(s.rule.SetAtlas, s.rule, "ui-journeys-renown-divider")
    if not (ruleOk and s.rule:GetAtlas()) then
        s.rule:SetHeight(1)
        local r, g, b = self:Color("muted")
        s.rule:SetColorTexture(r, g, b, 0.35)
    end

    --- Size the section and paint its card. `bodyH` is the room the
    --- caller needs inside; the section's own height comes back so the
    --- page can advance its cursor by it.
    function s:Layout(width, bodyH)
        -- Re-pinned every layout: these are pooled and reparented
        -- between renders, and a card that kept the level of a frame it
        -- no longer belongs to is back to covering its own contents.
        local host = s:GetParent()
        local lvl = math.max(((host and host:GetFrameLevel()) or 1) - 1, 0)
        s:SetFrameLevel(lvl)
        s.body:SetFrameLevel(lvl)

        s:SetWidth(width)
        s.body:SetHeight(math.max(bodyH, 1))
        s:SetHeight(SECTION_TITLE_H + math.max(bodyH, 1))
        -- After the width is set, never before: the rounded painter
        -- divides by the card's width to place its corners.
        W:Rounded(s.body, "inset", radius or 8)
        return s:GetHeight()
    end

    function s:SetText(t) s.title:SetText(t or "") end
    function s:SetValue(t) s.value:SetText(t or "") end
    return s
end

--- The heading height a page has to budget above a section's card.
function W:SectionTitleHeight() return SECTION_TITLE_H end

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
