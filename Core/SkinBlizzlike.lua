local _, ns = ...

------------------------------------------------------------
-- The Blizzlike skin.
--
-- Blizzard's own frame art, for people running the default UI who want
-- the addon to look like part of the game rather than a panel bolted
-- onto it.
--
-- Built on NineSliceUtil, which is how Blizzard's current frames are
-- assembled: a layout names an atlas per corner and edge, and the util
-- creates the textures on whatever frame you hand it. That matters
-- because the first version of this file used
-- Interface\DialogFrame\UI-DialogBox-Border -- art that has not changed
-- since 2004. It was Blizzlike for the wrong Blizzard, and next to a
-- current frame it read as the quest popup rather than as the game.
--
-- Layouts come from Blizzard_SharedXML/Mainline/NineSliceLayouts.lua
-- rather than from guesswork, so the atlas names are the ones the client
-- actually ships:
--
--   window  PortraitFrameTemplate -- the only borrowed layout, and the
--           only one that can be: it carries the medallion ring in its
--           top-left corner atlas, and it is drawn for a frame this big.
--
-- Everything else gets a tiled background and a gold hairline. See
-- BORDER below for why frame art stops at the window.
--
-- Not the default in the long run, and not a replacement. Anyone running
-- ElvUI or Ellesmere has deliberately removed this look from their
-- interface, so the addon's own dark panels stay available and this is a
-- choice -- see Skin.TESTING_DEFAULT for why it is currently the one you
-- get out of the box.
------------------------------------------------------------

if not ns.Skin then return end

local Blizzlike = {
    displayName = "Blizzlike",
    description = "Blizzard's current frame art, for the default UI.",
    beta = true,
}

-- Blizzard's own tiling backgrounds. Both are referenced by
-- PortraitFrameTexturedBaseTemplate, so they are known to exist and
-- known to tile.
local MARBLE = "Interface\\FrameGeneral\\UI-Background-Marble"
local ROCK   = "Interface\\FrameGeneral\\UI-Background-Rock"

-- Surfaces are drawn with SetBackdrop's own tiling rather than a texture
-- plus SetHorizTile. The hand-rolled version rendered as flat black on
-- every surface in the addon -- the whole window read as an empty box
-- with the widgets missing -- and SetBackdrop with tile/tileSize is the
-- path the nine feature pages have used successfully all along. Not
-- worth being clever about.
--
-- Backgrounds are drawn at full brightness. Both textures are already
-- dark brown, and every tint this table has tried has multiplied them
-- into the background instead of shading them: first darker with each
-- level of nesting until the hero card was black, then inverted but with
-- the window still at 0.34, which is not a dark brown, it is nothing.
-- Layers separate by choosing a different TEXTURE now, not by dimming
-- the same one. Vaultloom does the same thing -- its panels are drawn at
-- (1, 1, 1, 1) and the art carries the colour.
-- Texture on the two outer surfaces, solid fills inside them.
--
-- Tiling marble through every card is what read as "smokey": a mottled
-- pattern behind small blocks of text is noise at that size, and nine
-- vault tiles each showing a different part of the tile made the page
-- look dirty rather than textured. The window and the column keep their
-- grain -- that is where texture reads as material -- and everything
-- nested inside them gets a flat, warm, opaque fill.
local SURFACE = {
    -- Rock, as it was. The warm brown fill tried here was the hero
    -- card's colour spread across the whole window, and it read as one
    -- large flat surface rather than as a frame -- the neutral stone
    -- gives the content something to sit on without competing with it.
    window = { bg = ROCK, alpha = 1.00 },
    panel  = { bg = MARBLE, alpha = 1.00 },   -- marble reads lighter
    inset  = { flat = { 0.105, 0.088, 0.070, 0.97 } },
    header = { flat = { 0.16,  0.13,  0.10,  0.55 } },
    row    = { flat = { 0.135, 0.115, 0.092, 0.55 } },
}

-- The window, and nothing else.
--
-- PerksProgramHoldPanelTemplate was tried here for `panel` and broke the
-- addon visibly: its corner atlases are drawn at their own size, and
-- they are sized for the Trading Post's one large panel. On a 196px nav
-- rail each corner is bigger than the frame it is bordering, so the art
-- hangs outside as grey slabs and the window looks smashed.
--
-- That is the general trap with borrowing a nine-slice: a layout is
-- built for the frame it ships on. PortraitFrameTemplate is safe here
-- because the window IS a big frame, which is what it was drawn for.
-- Anything smaller gets a tinted hairline, which scales to any size
-- because it has no art to scale.
local BORDER = {
    window = "PortraitFrameTemplate",
}

-- Gold, not grey. This is the single thing that separates Vaultloom's
-- panels from ours, and it is not the shape of the border: every surface
-- it draws is edged in the same dim gold (its Theme calls the colour
-- goldDim, 0.40/0.31/0.10) at an edgeSize of 4 for cards and 2 for the
-- big structural regions. A grey line around a dark panel is what reads
-- as a scrappy old addon; the same line in gold reads as WoW.
--
-- Thin for the same reason theirs is thin. The version before this put
-- Blizzard's InsetFrameTemplate nine-slice around every block, which is
-- a recessed metal border Blizzard spends on one or two regions per
-- window -- twenty of them stacked up looked like a tray of tins.
local GOLD_EDGE = { 0.38, 0.31, 0.13, 0.75 }

local EDGE = {
    panel  = { 0.50, 0.41, 0.17, 0.85 },
    inset  = GOLD_EDGE,
    header = { 0.38, 0.31, 0.13, 0.35 },
    row    = nil,   -- rows are separated by tone, not by lines
}

-- Zero, and the reasoning behind the previous 16 was backwards. The
-- layout's corners sit at y = +16: the art hangs ABOVE the frame's own
-- top edge, outward, rather than eating 16px of it. So the frame's top
-- edge is already inside the painted metal bar and the title belongs
-- there -- which is exactly where Blizzard puts its own TitleContainer,
-- at y = -1. Insetting by 16 pushed the title and the close button down
-- into the window's body, away from the corner they belong in.
--
-- Present but zeroed rather than removed: the shell reads this to know
-- the skin paints its own title bar and it should not lay a filled
-- header strip over the metal.
Blizzlike.chromeInset = { top = 0, side = 0 }
Blizzlike.hasMedallion = true

-- Panels only. Shading every card as well as every panel was the other
-- half of the clutter: depth reads as depth when a few things have it,
-- and as noise when everything does.
local SHADOW = {
    panel = { inset = 1, thickness = 8, alpha = 0.32 },
}

--- Dress a frame that already exists. See Default:Apply for why this is
--- split out: it is what lets the feature pages adopt the skin with one
--- line at each SetBackdrop site instead of a rewrite.
---
--- Idempotent. Pages refresh far more often than they rebuild, and a
--- second call has to repaint rather than stack another background
--- texture and another nine-slice on top of the first.
local WHITE = "Interface\\Buttons\\WHITE8x8"


--- The flat colours behind a role: fill, then edge.
---
--- nil for the two textured roles, and deliberately. The window and the
--- panel are tiled rock and marble; a corner tile has exactly one colour
--- to be, so rounding those would mean replacing the grain with an
--- average of it -- and the grain is the whole reason they read as
--- material rather than as paint. ns.Widgets:Rounded takes the nil and
--- leaves them square.
function Blizzlike:Surface(role)
    role = ns.Skin.ROLES[role] and role or "panel"
    local s = SURFACE[role]
    if not (s and s.flat) then return nil end
    return s.flat, EDGE[role]
end

function Blizzlike:Apply(f, role)
    role = ns.Skin.ROLES[role] and role or "panel"
    local surface = SURFACE[role]
    local edge = EDGE[role]
    local layout = BORDER[role]

    if layout then
        -- Nine-slice frames get a plain background texture and NEVER a
        -- backdrop. The two cannot share a frame: BackdropTemplate keeps
        -- its textures on self[pieceName] using the same names
        -- NineSliceUtil uses -- Blizzard's own Backdrop.lua says so at
        -- the textureUVs table, "keys have to match pieceNames in
        -- nineSliceSetup" -- so GetNineSlicePiece finds the backdrop's
        -- edge already sitting there and re-anchors it into the layout.
        -- That is what put the loose grey bars across the top of the
        -- window: they were the backdrop's own edges, hijacked.
        local bg = f._yyhFill or f:CreateTexture(nil, "BACKGROUND", nil, -8)
        f._yyhFill = bg
        -- Blizzard's own numbers for this exact frame art, from
        -- PortraitFrameTexturedBaseTemplate: 2px at the sides and bottom,
        -- 21px off the top. Both previous attempts guessed instead --
        -- SetAllPoints put background under the title bar and behind the
        -- corner, a uniform 5px inset left bare strips down the sides.
        -- The asymmetry is the point: the top gap is where the metal
        -- title bar sits.
        bg:ClearAllPoints()
        bg:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -21)
        bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
        -- Handles both shapes. This branch used to assume surface.bg was
        -- a texture path; switching the window to a flat fill would have
        -- passed nil to SetTexture and left the window transparent, which
        -- looks exactly like the black background it was replacing.
        if surface.flat then
            bg:SetTexture(nil)
            bg:SetColorTexture(unpack(surface.flat))
        else
            bg:SetTexture(surface.bg, "REPEAT", "REPEAT")
            bg:SetHorizTile(true)
            bg:SetVertTile(true)
        end
        -- Shown explicitly: W:Unskin hides this, and re-skinning has to
        -- bring it back.
        bg:Show()
        if NineSliceUtil and NineSliceUtil.ApplyLayoutByName then
            pcall(NineSliceUtil.ApplyLayoutByName, f, layout)
        end
        f._yyhSkinned = role
        return f
    end

    if f.SetBackdrop then
        -- SetBackdrop's own tiling, and a one-pixel WHITE8x8 edge that
        -- takes a colour. That edge plus SetBackdropBorderColor is the
        -- whole of Vaultloom's border technique -- a tintable line, not
        -- frame art -- and the only reason theirs looks better is that
        -- the tint is gold.
        f:SetBackdrop({
            bgFile   = surface.flat and WHITE or surface.bg,
            tile     = not surface.flat,
            tileSize = 64,
            edgeFile = edge and WHITE or nil,
            edgeSize = edge and 1 or nil,
        })
        if surface.flat then
            f:SetBackdropColor(unpack(surface.flat))
        else
            local d = surface.dim or 1
            f:SetBackdropColor(d, d, d, surface.alpha or 1)
        end
        if edge then
            f:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4])
        end
    elseif f.CreateTexture then
        -- No BackdropTemplate to work with. A flat fill and a drawn
        -- hairline is not the same surface, but it is a surface, and a
        -- page that renders plain beats one that renders nothing.
        local bg = f._yyhFill or f:CreateTexture(nil, "BACKGROUND", nil, -8)
        f._yyhFill = bg
        bg:SetAllPoints(f)
        if surface.flat then
            bg:SetColorTexture(unpack(surface.flat))
        else
            bg:SetColorTexture(0.09, 0.075, 0.06, surface.alpha or 1)
        end
        bg:Show()
        if edge and ns.Widgets then
            ns.Widgets:Hairline(f, edge[1], edge[2], edge[3], edge[4])
        end
    end

    local shadow = SHADOW[role]
    if shadow and ns.Widgets then
        ns.Widgets:InnerShadow(f, shadow.inset, shadow.thickness, shadow.alpha)
    end
    f._yyhSkinned = role
    return f
end

function Blizzlike:Panel(parent, role)
    -- BackdropTemplate on purpose: Apply's good path needs it, and the
    -- fallback exists for frames the pages already built, not for ones
    -- we are creating here.
    return self:Apply(CreateFrame("Frame", nil, parent, "BackdropTemplate"), role)
end

local COLORS = {
    accent = { 0.92, 0.76, 0.24 },   -- Blizzard's gold, not the addon's cyan
    text   = { 0.96, 0.94, 0.89 },   -- warm parchment rather than white
    -- Lifted from 0.64/0.59/0.50. Secondary text has to stay legible on
    -- a dark brown surface, and at the old value the captions and
    -- section headings were closer to invisible than to quiet.
    muted  = { 0.76, 0.71, 0.62 },
    faint  = { 0.46, 0.43, 0.38 },
    good   = { 0.42, 0.84, 0.44 },
    warn   = { 1.00, 0.78, 0.28 },
    danger = { 0.80, 0.30, 0.25 },
    track  = { 0.10, 0.08, 0.06 },
}

function Blizzlike:Color(key)
    local c = COLORS[key]
    if c then return c[1], c[2], c[3] end
end

ns.Skin:Register("blizzlike", Blizzlike)
