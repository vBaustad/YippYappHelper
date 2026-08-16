local _, ns = ...

------------------------------------------------------------
-- Best in Slot page.
--
-- Laid out like the Gear Upgrades sheet, and for the same reason: a
-- character's gear is a shape people already know. Reading "Head, Neck,
-- Shoulders..." down a list means translating a list back into that
-- shape in your head; putting the icons where the character panel puts
-- them skips the translation.
--
-- Doll on the left, the same items as a named list on the right. The
-- doll answers "how far off am I" at a glance; the list answers "what
-- is that and where does it come from", which an icon cannot.
--
-- The value over a browser tab is the equipped check. A BiS list on a
-- website is seventeen names to verify by hand; here the addon already
-- knows what is in every slot.
------------------------------------------------------------

ns.BisUI = ns.BisUI or {}
local UI = ns.BisUI

-- Padding comes from the shell, not from here. Eight pages had picked
-- their own -- 12 in four of them, 14 in three -- so every page sat to a
-- different rhythm from the chrome around it and from each other. One
-- source means a spacing change lands everywhere at once.
local PAD = (ns.Shell and ns.Shell.PAD) or 12
-- Sized so the whole page fits without scrolling: 8 doll rows at
-- ICON+GAP must not exceed 16 list rows at ROW_H, and the pair has
-- to leave room for the stat block and the caveat underneath.
local ROW_H = 20
local ICON = 34
-- Ceiling for the scaled doll icon: past this the slot art is being
-- magnified rather than shown, and the rows drift apart.
local ICON_MAX = 46
-- Everything on the page that is not the doll: the header above it and
-- the stat priority block below.
local BIS_CHROME_H = 190
local GAP = 4
local DOLL_W = 380
-- Two lines of stat text, and the build name above them.
local STAT_LINES_H = 26
local NAME_H = 15
local NAME_GAP = 9
-- Gold, and deliberately not the page's green ACCENT.
--
-- Blizzard's hero talent picker rims the tree you have taken in gold, so
-- that is the colour people already read as "this is the one you
-- picked". ACCENT is spoken for: the heading above these cards uses it
-- to mean "this section", and one colour saying two different things is
-- how a page stops being readable at a glance.
local LIT = { 0.96, 0.78, 0.30 }
-- The card's own padding, and the gap between two cards.
--
-- Both exist because the first version had neither: the text was placed
-- first and the card drawn 12px out around it, so the gap between two
-- columns had to exceed 24 before their cards stopped overlapping -- and
-- it was 14, so they overlapped by ten. Anchoring the CARD and insetting
-- the text makes that arithmetic impossible to get wrong.
local CARD_PAD = 12
local CARD_GAP = 12
-- The hero talent medallion. Sized to be the card's subject rather than
-- a badge on its heading: at the 22px it started as, the art the card is
-- about was the smallest thing on it.
local HERO_ART = 40
local CIRCLE_MASK = "Interface\\AddOns\\YippYappHelper\\Media\\CircleMask"
local CIRCLE_RING = "Interface\\AddOns\\YippYappHelper\\Media\\CircleRing"
-- Enough to read as a card, not so much that a 62px block starts
-- looking like a pill.
local CARD_RADIUS = 8
local ACCENT = { 0.45, 1.0, 0.55 }
local ACCENT_HEX = "ff73ff8c"

-- The character-panel arrangement, matching the Gear sheet: left column
-- top-down, right column top-down, weapons centred beneath. Slot IDs are
-- the game's own so the equipped check needs no second mapping.
local DOLL = {
    { slot = 1,  side = "L", row = 1, name = "Head"      },
    { slot = 2,  side = "L", row = 2, name = "Neck"      },
    { slot = 3,  side = "L", row = 3, name = "Shoulders" },
    { slot = 15, side = "L", row = 4, name = "Back"      },
    { slot = 5,  side = "L", row = 5, name = "Chest"     },
    { slot = 9,  side = "L", row = 6, name = "Wrist"     },
    { slot = 13, side = "L", row = 7, name = "Trinket 1" },
    { slot = 10, side = "R", row = 1, name = "Hands"     },
    { slot = 6,  side = "R", row = 2, name = "Waist"     },
    { slot = 7,  side = "R", row = 3, name = "Legs"      },
    { slot = 8,  side = "R", row = 4, name = "Feet"      },
    { slot = 11, side = "R", row = 5, name = "Ring 1"    },
    { slot = 12, side = "R", row = 6, name = "Ring 2"    },
    { slot = 14, side = "R", row = 7, name = "Trinket 2" },
    { slot = 16, side = "W", row = 8, name = "Main Hand" },
    { slot = 17, side = "W", row = 8, name = "Off Hand"  },
}

-- Which inventory slots a guide's slot wording can land in, in order.
-- The guides say "Ring" twice rather than "Ring 1" and "Ring 2", so the
-- first unclaimed slot wins and the second Ring falls through to 12.
local SLOT_INV = {
    ["Head"] = { 1 }, ["Neck"] = { 2 }, ["Shoulders"] = { 3 },
    ["Back"] = { 15 }, ["Chest"] = { 5 }, ["Wrist"] = { 9 },
    ["Hands"] = { 10 }, ["Waist"] = { 6 }, ["Legs"] = { 7 },
    ["Feet"] = { 8 },
    ["Ring"] = { 11, 12 }, ["Ring 1"] = { 11 }, ["Ring 2"] = { 12 },
    ["Trinket"] = { 13, 14 }, ["Trinket 1"] = { 13 }, ["Trinket 2"] = { 14 },
    ["Weapon"] = { 16, 17 }, ["Main Hand"] = { 16 }, ["Off Hand"] = { 17 },
}

------------------------------------------------------------
-- Which spec are we looking at
------------------------------------------------------------
--- Returns the ClassGuideData key and a class-coloured display name.
---
--- Both come from the live API rather than from the trinket module.
--- Its GetPlayerSpecKey validates against bloodmallet's coverage and
--- returns nil for specs it has no sims for, which would blank this page
--- for an unrelated reason; and its SPEC_LABEL maps a key to
--- { class, spec, role } -- a table, not a string -- so using it as a
--- title threw on every spec. GetSpecializationInfo has the localised
--- name right here, which is both correct and one fewer dependency.
local function PlayerSpec()
    local className, classFile = UnitClass("player")
    if not classFile then return nil end
    local idx = GetSpecialization and GetSpecialization()
    if not idx then return nil end
    local _, specName = GetSpecializationInfo(idx)
    if not specName then return nil end

    local key = classFile:upper() .. "_" .. specName:upper():gsub("[^A-Z]", "")
    local display = specName .. " " .. (className or "")
    local colour = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if colour and colour.WrapTextInColorCode then
        display = colour:WrapTextInColorCode(display)
    end
    return key, display
end

------------------------------------------------------------
-- Pools
------------------------------------------------------------
local function AcquireFS(self, parent, template)
    self._fs = self._fs or {}
    self._fsIdx = (self._fsIdx or 0) + 1
    local fs = self._fs[self._fsIdx]
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
        self._fs[self._fsIdx] = fs
    end
    fs:SetParent(parent)
    -- The font goes on at every acquire, not only at creation. The pool
    -- is indexed, so which FontString a caller gets depends on how many
    -- were taken before it -- and that count moves with the guide, since
    -- "Also listed" only appears for some specs and pinning an item can
    -- make it appear. Set once, a heading could come back wearing the
    -- small font a stat line left on it.
    local font = type(template) == "string" and _G[template] or template
    if font and fs.SetFontObject then fs:SetFontObject(font) end
    fs:ClearAllPoints()
    fs:SetWidth(0)
    fs:SetWordWrap(false)
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(1, 1, 1, 1)
    fs:SetText("")
    fs:Show()
    return fs
end

local function AcquireIcon(self, parent)
    self._icons = self._icons or {}
    self._iconIdx = (self._iconIdx or 0) + 1
    local b = self._icons[self._iconIdx]
    if not b then
        b = CreateFrame("Button", nil, parent, "BackdropTemplate")
        b:SetSize(ICON, ICON)
        b:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
        })
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetPoint("TOPLEFT", 2, -2)
        b.tex:SetPoint("BOTTOMRIGHT", -2, 2)
        b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.tick = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.tick:SetPoint("BOTTOMRIGHT", 1, -1)
        self._icons[self._iconIdx] = b
    end
    b:SetParent(parent)
    b:ClearAllPoints()
    b:SetScript("OnEnter", nil)
    b:SetScript("OnLeave", nil)
    b.tick:SetText("")
    b:Show()
    return b
end

local function AcquireRow(self, parent)
    self._rows = self._rows or {}
    self._rowIdx = (self._rowIdx or 0) + 1
    local row = self._rows[self._rowIdx]
    if not row then
        row = CreateFrame("Button", nil, parent)
        row:SetHeight(ROW_H)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", 0, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        -- No slot column. The doll on the left already says which slot
        -- each row is, in the place people actually read slots, so
        -- repeating "Head / Neck / Shoulders" down the list spends a
        -- third of the width restating the layout.
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
        row.name:SetJustifyH("LEFT")
        row.source = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.source:SetPoint("RIGHT", 0, 0)
        row.source:SetJustifyH("RIGHT")
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.06)
        hl:SetBlendMode("ADD")
        self._rows[self._rowIdx] = row
    end
    row:SetParent(parent)
    row:ClearAllPoints()
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)
    row.icon:SetTexture(nil)
    row.source:SetText("")
    row:Show()
    return row
end

--- A skinned surface behind a column.
---
--- The doll and the list were two ungrouped piles of widgets side by
--- side on the page's own background, so nothing said where one ended
--- and the other began. A surface under each says it without a caption.
---
--- Skinned on acquire rather than on create, because the skin can change
--- between one render and the next.
local function AcquirePanel(self, parent)
    self._panels = self._panels or {}
    self._panelIdx = (self._panelIdx or 0) + 1
    local p = self._panels[self._panelIdx]
    if not p then
        p = CreateFrame("Frame", nil, parent)
        self._panels[self._panelIdx] = p
    else
        p:SetParent(parent)
    end
    if ns.Widgets then ns.Widgets:Apply(p, "inset") end
    p:ClearAllPoints()
    -- Behind the icons and rows that sit on it, not over them.
    p:SetFrameLevel(math.max((parent:GetFrameLevel() or 1), 1))
    p:Show()
    return p
end

--- A rounded card, on its own pool.
---
--- Not AcquirePanel's. That pool hands the same frame to whichever
--- caller asks next, so a doll panel that had been a stat card last
--- render would come back square with its corners still rounded --
--- ns.Widgets:Rounded and W:Apply each undo the other's painting, but
--- only when they are told, and a shared pool never tells them.
--- The card for the build you are actually specced into.
---
--- Blizzard's hero talent picker says which is which by lighting the
--- whole panel behind the one you have taken, and that is the part worth
--- borrowing: two priorities side by side with no mark between them
--- makes the reader work out which one is theirs every time they open
--- the page, and they already answered that question in the talent tree.
---
--- Mixed from the skin's own inset colour rather than replacing it, so
--- the highlight follows a skin change instead of being a green card
--- sitting in a brown window.
--- How a card is painted, lit or not.
---
--- The wash is the part doing the work. A flat tint reads as "this card
--- is a different colour"; a fade running out from under the medallion
--- reads as the art lighting the card it sits on, which is what
--- Blizzard's picker does and why the chosen one there is unmistakable.
---
--- Both states are mixed from the skin's OWN inset colour rather than
--- replacing it, so the pair follows a skin change instead of being a
--- gold card sitting in someone else's grey window.
local function CardColours(lit)
    local fill = ns.Widgets and ns.Widgets:Surface("inset")
    if not fill then return nil end
    if not lit then
        -- Not a dimmer card -- the same card, with the faintest sheen so
        -- the unpicked build reads as an alternative rather than as
        -- something switched off.
        return { wash = { 0.60, 0.60, 0.66, 0.10 } }
    end
    local function mix(i) return fill[i] + (LIT[i] - fill[i]) * 0.10 end
    return {
        fill = { mix(1), mix(2), mix(3), fill[4] or 1 },
        edge = { LIT[1], LIT[2], LIT[3], 0.70 },
        wash = { LIT[1], LIT[2], LIT[3], 0.28 },
    }
end

local function AcquireCard(self, parent)
    self._cards = self._cards or {}
    self._cardIdx = (self._cardIdx or 0) + 1
    local c = self._cards[self._cardIdx]
    if not c then
        c = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        self._cards[self._cardIdx] = c
    else
        c:SetParent(parent)
    end
    c:ClearAllPoints()
    -- Behind the text that sits on it, not over it.
    c:SetFrameLevel(math.max((parent:GetFrameLevel() or 1), 1))
    c:Show()
    return c
end

--- The hero tree's art as the game itself draws it: the icon cut to a
--- circle, inside a rim.
---
--- Blizzard's hero talent picker is exactly this shape -- a round
--- medallion, gold-rimmed for the tree you have taken and grey for the
--- one you have not -- so it is what people already recognise as a hero
--- talent, and matching it costs a mask and a ring.
---
--- The rim is drawn OVER the medallion at the same size rather than
--- around it. A masked circle frays over its last pixel or two, and the
--- rim landing on that edge is what hides it.
local function AcquireMedallion(self, parent)
    self._meds = self._meds or {}
    self._medIdx = (self._medIdx or 0) + 1
    local m = self._meds[self._medIdx]
    if not m then
        m = {}
        m.icon = parent:CreateTexture(nil, "ARTWORK")
        -- CLAMPTOBLACKADDITIVE on both axes: outside the tile the mask
        -- has to read as "hide", not repeat the disc across the icon.
        m.mask = parent:CreateMaskTexture()
        m.mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m.mask:SetAllPoints(m.icon)
        m.icon:AddMaskTexture(m.mask)
        m.ring = parent:CreateTexture(nil, "OVERLAY")
        m.ring:SetTexture(CIRCLE_RING)
        m.ring:SetAllPoints(m.icon)
        self._meds[self._medIdx] = m
    end
    m.icon:SetParent(parent)
    m.ring:SetParent(parent)
    m.icon:ClearAllPoints()
    m.icon:SetTexCoord(0, 1, 0, 1)
    m.icon:SetDesaturated(false)
    m.icon:Show()
    m.ring:Show()
    return m
end

--- Draw a piece of art that may be either kind of handle.
---
--- The talent API calls its field an "element ID", which is a file ID on
--- some builds and an atlas name on others, and the two calls do not
--- accept each other's argument -- SetTexture given an atlas name draws
--- nothing at all, silently, which is exactly what the first version of
--- this did. The type decides.
---
--- Cropping is only for file textures. An atlas already carries the
--- texture coordinates of its slice out of a sheet, so re-cropping one
--- does not trim its border, it shows a different part of the sheet.
local function SetArt(tex, art, crop)
    if type(art) == "string" then
        if tex:SetAtlas(art) == false then return false end
        return true
    end
    tex:SetTexture(art)
    if crop then tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    return true
end

------------------------------------------------------------
-- Hero talent art
------------------------------------------------------------
--- Hero talent name -> the game's own icon for that tree.
---
--- The guide stores a build as a bare string -- "San'layn", "Mountain
--- Thane" -- because that is what the source calls it. The client knows
--- those as trait subtrees and ships art for each, so the card can show
--- the tree instead of only naming it.
---
--- Keyed by lowercased name, and English-only in practice: the guide
--- data is scraped from an English source while the API answers in the
--- client's locale. A mismatched locale simply finds nothing and the
--- card renders as it did before, which is the right failure -- an icon
--- guessed from a near-match would be the wrong tree's art, and a
--- picture is read faster than the name beside it.
local function HeroTalentArt()
    local out = {}
    if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID
            and C_ClassTalents.GetHeroTalentSpecsForClassSpec
            and C_Traits and C_Traits.GetSubTreeInfo) then
        return out
    end

    local ok, configID = pcall(C_ClassTalents.GetActiveConfigID)
    if not ok or not configID then return out end

    local idx = GetSpecialization and GetSpecialization()
    local specID = idx and GetSpecializationInfo(idx)
    if not specID then return out end

    local okIDs, ids = pcall(C_ClassTalents.GetHeroTalentSpecsForClassSpec,
        configID, specID)
    if not okIDs or type(ids) ~= "table" then return out end

    -- Which tree you actually took. Asked for directly where the client
    -- offers it, since that is the question, and read back off each
    -- subtree otherwise. Neither is guaranteed, and an unknown active
    -- tree simply leaves every card unlit rather than lighting a guess.
    local activeID
    if C_ClassTalents.GetActiveHeroTalentSpec then
        local okA, id = pcall(C_ClassTalents.GetActiveHeroTalentSpec)
        if okA then activeID = id end
    end

    for _, subTreeID in ipairs(ids) do
        local okInfo, info = pcall(C_Traits.GetSubTreeInfo, configID, subTreeID)
        if okInfo and type(info) == "table" and info.name then
            -- Zero is not an icon, and in Lua it is not false either --
            -- which is how the first version of this reserved space for
            -- a tile, indented the label past it, and drew nothing.
            local icon = info.iconElementID
            if type(icon) == "number" and icon <= 0 then icon = nil end
            out[info.name:lower()] = {
                icon   = icon,
                active = (activeID ~= nil and subTreeID == activeID)
                          or info.isActive == true,
            }
        end
    end
    return out
end

local function Release(self)
    for i = 1, (self._cardIdx or 0) do
        if self._cards[i] then self._cards[i]:Hide() end
    end
    self._cardIdx = 0
    for i = 1, (self._medIdx or 0) do
        local m = self._meds[i]
        -- The mask goes with the icon it is attached to; hiding it
        -- separately would unmask the icon rather than hide it.
        if m then m.icon:Hide(); m.ring:Hide() end
    end
    self._medIdx = 0
    for i = 1, (self._panelIdx or 0) do
        if self._panels[i] then self._panels[i]:Hide() end
    end
    self._panelIdx = 0
    for i = 1, (self._rowIdx or 0) do
        if self._rows[i] then self._rows[i]:Hide() end
    end
    self._rowIdx = 0
    for i = 1, (self._fsIdx or 0) do
        if self._fs[i] then self._fs[i]:Hide() end
    end
    self._fsIdx = 0
    for i = 1, (self._iconIdx or 0) do
        if self._icons[i] then self._icons[i]:Hide() end
    end
    self._iconIdx = 0
end

------------------------------------------------------------
-- Item lookup, async-safe
------------------------------------------------------------
-- Names come from the ID at runtime rather than the data file, so the
-- page localises itself and survives a rename. An uncached item returns
-- nothing on the first look, hence the request and the redraw on
-- GET_ITEM_INFO_RECEIVED.
--- Name, icon and quality colour. Quality is read from the LINK when we
--- have one, for the same reason the Loot Browser reads it that way: the
--- base item in the client database is Rare, and the bonus IDs are what
--- promote it to Epic. Asking by itemID returns Rare for everything,
--- which is why best-in-slot epics were rendering blue.
local function itemInfo(itemID, link)
    local name, quality
    if link then name, _, quality = GetItemInfo(link) end
    if quality == nil then
        local n2, _, q2 = GetItemInfo(itemID)
        name, quality = name or n2, q2
    end
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
    local hex = "|cffffffff"
    if quality and ITEM_QUALITY_COLORS[quality] then
        hex = ITEM_QUALITY_COLORS[quality].hex
    end
    return name, icon, hex
end

--- A hyperlink carrying the guide's bonus IDs, or nil.
---
--- Bonus IDs encode the upgrade rank being recommended, so without them
--- an item resolves at its base level -- a different number to the one
--- the BiS list means. Only about one row in seven carries them: some
--- guide authors publish the rank, most do not, so this is best-effort
--- by design rather than a gap to be closed.
---
--- The field count before numBonusIDs is the fragile part, so callers
--- must treat a nil item level as "no answer" and fall back rather than
--- trusting the link blindly.
--- A link carrying the guide's own bonus IDs, or nil when it published
--- none. There is deliberately no fallback pair: a generic "upgraded"
--- bonus turned out to encode 289, which GEAR_TRACKS knows as Veteran
--- 4/6, so it quietly pinned two thirds of the list BELOW the rank it
--- claimed to show. The rank now comes from GEAR_TRACKS instead.
local function bonusLink(entry)
    local source = entry.bonus
    if not source or source == "" then return nil end

    local ids = {}
    for b in source:gmatch("%d+") do ids[#ids + 1] = b end
    if #ids == 0 then return nil end
    return ("item:%d%s%d:%s"):format(entry.itemID, string.rep(":", 12),
                                     #ids, table.concat(ids, ":"))
end

--- The best link we can get for a row, and nothing invented.
---
--- The journal's link first. It is the only source of the bonus IDs that
--- make an item render as what it actually is -- Epic rather than Rare,
--- +96 Intellect rather than +5, with an upgrade track. Without it the
--- tooltip shows the item's base entry, which is a real item nobody has
--- ever seen drop.
---
--- Then the guide's own bonuses, then nil for crafted gear and tier
--- tokens, which are in no loot table and have no link to find.
local function itemLink(entry)
    if ns.GetJournalItemLink then
        local ok, link = pcall(ns.GetJournalItemLink, ns, entry.itemID)
        if ok and link then return link end
    end
    return bonusLink(entry)
end

--- The item level this row tops out at, and its track rank -- "334",
--- "Myth 6/6" -- or nil when neither is knowable.
---
--- Same source of truth as the Loot Browser, which already resolves
--- every rank of every track: GEAR_TRACKS, with ns:DescribeIlvlRank
--- naming the rank. Two cases:
---
---  * The guide published bonus IDs. Trust the link -- but only if it
---    resolves at or above the season's floor, since plenty of bonus IDs
---    are sockets or tertiaries and resolve to the item's BASE level
---    instead. That is how a best-in-slot ring came out at 28.
---  * It did not. Then the ceiling is the top of the highest track,
---    which is what a best-in-slot row is a target for in the first
---    place. Crafted gear caps somewhere else and is left blank rather
---    than guessed at.
---
--- A rank of nil is normal, not a failure: Very Rares sit at 344, above
--- every track, so they get an item level and no rank.
local function maxRankIlvl(entry)
    local tracks, order = ns.GEAR_TRACKS, ns.TRACK_ORDER
    local floorLvl = tracks and tracks.Adventurer and tracks.Adventurer[1] or 0

    local link = bonusLink(entry)
    if link and GetDetailedItemLevelInfo then
        local ok, lvl = pcall(GetDetailedItemLevelInfo, link)
        if ok and lvl and lvl > 0 and lvl >= floorLvl then
            return lvl, ns.DescribeIlvlRank and ns:DescribeIlvlRank(lvl) or nil
        end
    end

    if (entry.source or ""):lower():find("craft", 1, true) then return nil end
    if not (tracks and order and #order > 0) then return nil end
    local top = tracks[order[#order]]
    if not top or #top == 0 then return nil end
    local lvl = top[#top]
    return lvl, ns.DescribeIlvlRank and ns:DescribeIlvlRank(lvl) or nil
end

--- Tooltip showing the rank the LIST shows, not the item's base entry.
---
--- Same treatment the Loot Browser gives keystone loot, for the same
--- reason: the link we can build does not carry the rank, so its tooltip
--- would read "Item Level 28" directly under a row saying 334 Myth 6/6.
--- ns.RewriteTooltipIlvl swaps the digits in place, keeping colours and
--- localisation intact.
---
--- A base item has no upgrade line to rewrite, so when the rank is not
--- replaced it is appended instead -- and only then, or an item that
--- genuinely has no track would be given one.
local ScanBags

local function linkIlvl(link)
    if not link or not GetDetailedItemLevelInfo then return nil end
    local ok, lvl = pcall(GetDetailedItemLevelInfo, link)
    if ok and lvl and lvl > 0 then return lvl end
    return nil
end

--- itemID -> best item level held in bags. Built once per render, not
--- once per row: this walks every bag slot the character has, and the
--- page asks about thirty-odd items.
---
--- Keeps the HIGHEST copy. Two of the same item in bags at different
--- ranks is normal after a catalyst or a vault pick, and the lower one
--- is not the answer to "how far along am I".
--- Exported: the Advisor wants a bag-aware view too, and two scanners
--- walking the same bags with different rules is how they drift.
function ns:ScanBagItems()
    return ScanBags()
end

function ScanBags()
    local found = {}
    local C = C_Container
    if not (C and C.GetContainerNumSlots and C.GetContainerItemID) then return found end

    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, last do
        local slots = C.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local itemID = C.GetContainerItemID(bag, slot)
            if itemID then
                local lvl = C.GetContainerItemLink
                    and linkIlvl(C.GetContainerItemLink(bag, slot)) or nil
                -- A known level always beats an unknown one, and a
                -- higher level beats a lower.
                local prev = found[itemID]
                if prev == nil or (lvl and (prev == true or lvl > prev)) then
                    found[itemID] = lvl or true
                end
            end
        end
    end
    return found
end

--- What the player has toward this row: their item level, its rank, and
--- whether it is on their character or sitting in a bag.
---
--- Bags count. A drop you have not equipped yet is still a drop you got,
--- and the page is a collection checklist as much as a gear check -- but
--- the two are worth telling apart, because one of them is doing nothing
--- for you.
---
--- Equipped wins when both exist, even if the bagged copy is higher:
--- what you are wearing is the honest answer to "where am I", and a
--- better one in the bag is a different problem the tooltip can mention.
local function ownedIlvl(slotID, entry, bags)
    if GetInventoryItemID("player", slotID) == entry.itemID then
        local lvl = linkIlvl(GetInventoryItemLink and GetInventoryItemLink("player", slotID))
        return "equipped", lvl, lvl and ns.DescribeIlvlRank and ns:DescribeIlvlRank(lvl) or nil
    end

    local bagged = bags and bags[entry.itemID]
    if bagged then
        local lvl = bagged ~= true and bagged or nil
        return "bags", lvl, lvl and ns.DescribeIlvlRank and ns:DescribeIlvlRank(lvl) or nil
    end
    return nil
end

--- Right-click any row on the page to reach the same item menu the
--- trinket lists use -- including "remove as best in slot", which has to
--- be reachable from the doll because that is where a pin is visible.
---
--- Only attached where the frame can take clicks at all: the doll draws
--- some slots as plain textures.
local function hookMenu(frame, itemID, title)
    if not (frame.RegisterForClicks and itemID) then return end
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local prev = frame:GetScript("OnClick")
    frame:SetScript("OnClick", function(s, button, ...)
        if button == "RightButton" then
            if ns.ShowItemMenu then
                ns:ShowItemMenu(s, itemID, {
                    title = title,
                    onChange = function() UI:Refresh() end,
                })
            end
        elseif prev then
            prev(s, button, ...)
        end
    end)
end

local function hookTooltip(frame, itemID, link, ilvl, rank, ownIlvl, owned)
    frame:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        if link then
            local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
            if not ok then GameTooltip:SetItemByID(itemID) end
        else
            GameTooltip:SetItemByID(itemID)
        end

        if ilvl and ns.RewriteTooltipIlvl then
            local _, didRank = ns.RewriteTooltipIlvl(GameTooltip, ilvl, rank)
            if rank and not didRank then
                GameTooltip:AddLine("Upgrade Level: " .. rank, 0.55, 0.78, 1)
            end
        end

        -- Where they actually stand on this row. Only worth a line when
        -- they own it; "you do not have this" is what the whole page
        -- already says.
        if owned == "bags" then
            GameTooltip:AddLine(ownIlvl
                and ("In your bags at %d - not equipped"):format(ownIlvl)
                or "In your bags - not equipped", 0.48, 0.72, 1)
        elseif ownIlvl then
            if ilvl and ownIlvl < ilvl then
                GameTooltip:AddLine(("Yours: %d - %d short of this"):format(
                    ownIlvl, ilvl - ownIlvl), 1, 0.78, 0.28)
            else
                GameTooltip:AddLine("Yours: this one, at max rank", 0.35, 0.9, 0.45)
            end
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- The reverse of SLOT_INV, for labelling a pinned row that has no guide
-- entry behind it to borrow a slot name from.
local SLOT_NAME = {}
for name, slots in pairs(SLOT_INV) do
    -- Skip the numbered aliases: "Trinket 1" and "Trinket" both map to
    -- 13, and the unnumbered one is what the guide data uses.
    if not name:find("%d$") then
        for _, invSlot in ipairs(slots) do
            SLOT_NAME[invSlot] = SLOT_NAME[invSlot] or name
        end
    end
end

------------------------------------------------------------
-- Your own picks
--
-- Deliberately not the favourites store. A favourite is "I am hunting
-- this" and there can be several for one slot; a pin is "this one goes
-- here" and there is exactly one per slot. Merging them would mean
-- starring a fifth trinket quietly rewrote the list.
--
-- Keyed by numeric inventory slot, the same key AssignToSlots and the
-- paper doll already use, so a pin needs no translation to be placed.
------------------------------------------------------------
local function PinTable(create, specID)
    YippYappHelperDB = YippYappHelperDB or {}
    if not YippYappHelperDB.bisPins then
        if not create then return nil end
        YippYappHelperDB.bisPins = {}
    end
    local charKey = ns.GetLootCharacterKey and ns:GetLootCharacterKey()
        or (UnitName("player") .. "-" .. GetRealmName())
    if not YippYappHelperDB.bisPins[charKey] then
        if not create then return nil end
        YippYappHelperDB.bisPins[charKey] = {}
    end
    specID = specID or (ns.GetPlayerSpecID and ns:GetPlayerSpecID())
    if not specID then return nil end
    if not YippYappHelperDB.bisPins[charKey][specID] then
        if not create then return nil end
        YippYappHelperDB.bisPins[charKey][specID] = {}
    end
    return YippYappHelperDB.bisPins[charKey][specID]
end

--- invSlot -> itemID for this spec. Never nil, so callers can index it.
function ns:GetBisPins(specID)
    return PinTable(false, specID) or {}
end

--- True when the item can actually go in that slot. Checked against the
--- item rather than against whatever asked to pin it.
function ns:CanPinToSlot(itemID, invSlot)
    local slots = ns.GetItemSlots and ns:GetItemSlots(itemID)
    if not slots then return false end
    for _, s in ipairs(slots) do
        if s == invSlot then return true end
    end
    return false
end

function ns:SetBisPin(invSlot, itemID, specID)
    if not (invSlot and itemID) then return false end
    if not ns:CanPinToSlot(itemID, invSlot) then return false end
    local tbl = PinTable(true, specID)
    if not tbl then return false end

    -- The same item cannot hold two slots. Pinning a trinket already
    -- pinned to the other slot is a move, not a second copy.
    for slot, id in pairs(tbl) do
        if id == itemID and slot ~= invSlot then tbl[slot] = nil end
    end
    tbl[invSlot] = itemID
    return true
end

function ns:ClearBisPin(invSlot, specID)
    local tbl = PinTable(false, specID)
    if tbl then tbl[invSlot] = nil end
end

--- Move a pin to the slot beside it.
---
--- With the far slot empty, the pin simply moves: it now overrides that
--- slot's guide pick, and the one it was overriding is shown again.
--- With both slots pinned the two trade places rather than one being
--- dropped -- you chose both, so neither should be discarded to make
--- room for a move.
function ns:MoveBisPin(fromSlot, toSlot, specID)
    if fromSlot == toSlot then return false end
    local tbl = PinTable(false, specID)
    local moving = tbl and tbl[fromSlot]
    if not moving then return false end
    if not ns:CanPinToSlot(moving, toSlot) then return false end

    local displaced = tbl[toSlot]
    if displaced and not ns:CanPinToSlot(displaced, fromSlot) then
        return false
    end

    tbl[toSlot] = moving
    tbl[fromSlot] = displaced or nil
    return true
end

------------------------------------------------------------
-- Assign BiS rows to inventory slots
------------------------------------------------------------
--- Returns invSlot -> entry, plus everything that would not fit.
---
--- Guides write "Ring" twice rather than numbering them, so each row
--- takes the first slot of its kind still free and a second Ring lands
--- in Ring 2 without the data saying so.
---
--- Several guides list more options than the character has slots —
--- Restoration Druid names eight extra pieces, mostly trinkets. There is
--- nowhere on a doll to draw a third trinket, but dropping those rows
--- silently would delete real advice from the page, so they come back
--- separately and are listed as alternatives.
--- `seed` is the player's own picks, already placed. The guide then
--- fills what is left, and whatever it can no longer place comes back as
--- an alternative -- the same route an over-long guide list already
--- takes, so a pick you override stays visible instead of vanishing.
local function AssignToSlots(bis, seed)
    local bySlot, spare = {}, {}
    for invSlot, entry in pairs(seed or {}) do
        bySlot[invSlot] = entry
    end
    for _, entry in ipairs(bis or {}) do
        local placed = false
        for _, invSlot in ipairs(SLOT_INV[entry.slot] or {}) do
            if not bySlot[invSlot] then
                bySlot[invSlot] = entry
                placed = true
                break
            end
        end
        if not placed then
            table.insert(spare, entry)
        end
    end
    return bySlot, spare
end

------------------------------------------------------------
-- Render
------------------------------------------------------------
--- itemID -> true for everything currently on the page.
---
--- The event watcher reads this to decide whether an incoming item
--- actually concerns us. GET_ITEM_INFO_RECEIVED is global, so without it
--- the page redraws for items belonging to other addons entirely.
UI._wantItem = UI._wantItem or {}

function UI:Render(content, width, height)
    Release(self)
    wipe(self._wantItem)
    local y = -8
    local inner = width - PAD * 2

    -- The doll's icons scale to the room it has.
    --
    -- ICON was a constant, so the doll was the same height in any
    -- region and the page stopped two thirds of the way down. Nine rows
    -- -- eight paired plus the weapons -- have to fit between the header
    -- and the stat priority block beneath, so the icon is whatever
    -- divides into that, floored where the slot art stops being legible.
    local iconSize = ICON
    if height and height > 0 then
        local room = height - BIS_CHROME_H
        -- Inverted from dollH, which is 9*icon + 8*GAP + 24: eight
        -- paired rows, the weapon row, and the panel's own padding.
        -- Dividing by nine without subtracting that padding overshot by
        -- 12px and the doll ran past the region it was sizing to.
        iconSize = math.floor((room - GAP * 8 - 24) / 9)
        iconSize = math.max(ICON, math.min(iconSize, ICON_MAX))
    end

    local specKey, specName = PlayerSpec()
    local data = specKey and ns.ClassGuideData and ns.ClassGuideData[specKey]

    if not data then
        local fs = AcquireFS(self, content, "GameFontNormal")
        fs:SetPoint("TOPLEFT", PAD, y)
        fs:SetWidth(inner)
        fs:SetWordWrap(true)
        fs:SetTextColor(0.7, 0.7, 0.75)
        fs:SetText(specKey
            and ("No guide data for " .. specKey
                 .. ". Regenerate with Tools/scrape_class_guides.py.")
            or "Could not read your specialization yet — try reopening this page.")
        return
    end

    -- ── Header ──────────────────────────────────────────────
    local title = AcquireFS(self, content, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD, y)
    -- Guarded to a string: this line concatenated a table and threw for
    -- every spec when the display name came from a map whose values were
    -- tables. A title is not worth an error, so anything unexpected
    -- degrades to the key.
    title:SetText(type(specName) == "string" and specName
        or ("|c" .. ACCENT_HEX .. specKey:gsub("_", " ") .. "|r"))
    ns.ApplyTextShadow(title)

    -- Your pins are placed first so the guide fills in around them.
    -- A pinned row carries `pinned` so the doll can mark it as yours and
    -- offer to move or clear it; it has no guide metadata of its own,
    -- which is the point -- it came from you, not from the guide.
    -- Both halves of the page read bySlot, so seeding it puts a pin on
    -- the doll and in the list at once and the guide's displaced pick
    -- falls through to "Also listed".
    --
    -- `source` is where a guide row says which boss drops it, and a pin
    -- has no guide behind it to ask. Left empty the column would render
    -- as an item level trailing off into nothing, with no way to tell
    -- your own choice from the guide's -- which is the one thing a pin
    -- has to be able to say.
    local seed = {}
    for invSlot, itemID in pairs(ns:GetBisPins()) do
        seed[invSlot] = {
            itemID = itemID,
            pinned = true,
            slot   = SLOT_NAME[invSlot],
            source = "|cffffd100your pick|r",
        }
    end

    local unresolved = 0
    local bySlot, spare = AssignToSlots(data.bis, seed)
    for _, entry in pairs(bySlot) do
        if entry.itemID then self._wantItem[entry.itemID] = true end
    end
    for _, entry in ipairs(spare) do
        if entry.itemID then self._wantItem[entry.itemID] = true end
    end
    local bags = ScanBags()
    local have, total, atMax = 0, 0, 0
    for _, def in ipairs(DOLL) do
        local entry = bySlot[def.slot]
        if entry then
            total = total + 1
            local owned, ownIlvl = ownedIlvl(def.slot, entry, bags)
            if owned then
                have = have + 1
                local target = maxRankIlvl(entry)
                -- Anything we cannot measure counts as done rather than
                -- pending: crafted rows have no target to fall short of,
                -- and an equipped item with no readable level is a gap
                -- in our data, not a gap in their gear. Better to
                -- under-nag than to invent a shortfall.
                if not target or not ownIlvl or ownIlvl >= target then
                    atMax = atMax + 1
                end
            end
        end
    end

    local count = AcquireFS(self, content, "GameFontNormal")
    count:SetPoint("TOPRIGHT", content, "TOPLEFT", PAD + inner, y - 2)
    count:SetJustifyH("RIGHT")
    -- The second number only earns its place once it disagrees with the
    -- first; "6 / 16 equipped, 6 at max rank" is the same fact twice.
    local countText = ("|cffffffff%d|r|cff888888 / %d collected|r"):format(have, total)
    if atMax < have then
        countText = countText .. ("|cff%s, |r|cffffc83c%d|r|cff888888 at max rank|r"):format(ns.Widgets:Hex("muted"), atMax)
    end
    count:SetText(countText)
    y = y - 22

    -- A guide still labelled with last season is not wrong so much as
    -- unrevised. Saying which season it claims beats hiding it.
    local stamp = AcquireFS(self, content, "GameFontNormalSmall")
    stamp:SetPoint("TOPLEFT", PAD, y)
    local seasonOK = data.season == ns.CLASS_GUIDE_TARGET_SEASON
    stamp:SetText(seasonOK
        and ("|cff" .. ns.Widgets:Hex("faint") .. (data.season or "") .. "  ·  updated "
             .. (ns.CLASS_GUIDE_SCRAPED_AT or "?") .. "|r")
        or ("|cffffcc00" .. (data.season or "unknown season") .. " — not yet updated for "
            .. (ns.CLASS_GUIDE_TARGET_SEASON or "") .. "|r"))
    y = y - 20

    y = y - 6
    local topY = y

    ------------------------------------------------------------
    -- Doll, left
    --
    -- Sits on its own surface. The height is the eight paired rows plus
    -- the weapon row underneath, which is the doll's fixed shape --
    -- unlike the list, it does not grow with the guide.
    ------------------------------------------------------------
    local dollH = 8 * (iconSize + GAP) + iconSize + 24
    local dollPanel = AcquirePanel(self, content)
    dollPanel:SetPoint("TOPLEFT", PAD - 6, topY + 8)
    dollPanel:SetSize(DOLL_W + 4, dollH)

    -- The list's surface is acquired here, with the doll's, and sized at
    -- the end once the guide's length is known. Acquiring it after the
    -- rows would be simpler and wrong: sibling frames at the same level
    -- draw in creation order, so a panel made last covers the rows it is
    -- supposed to sit under.
    local listPanel = AcquirePanel(self, content)

    local colL = PAD + 4
    local colR = PAD + DOLL_W - iconSize - 4
    local function dollPos(def)
        if def.side == "L" then
            return colL, topY - (def.row - 1) * (iconSize + GAP)
        elseif def.side == "R" then
            return colR, topY - (def.row - 1) * (iconSize + GAP)
        end
        -- Weapons sit centred under the two columns.
        local slotsOnRow = (def.slot == 16) and 0 or 1
        local centre = PAD + DOLL_W / 2 - iconSize - GAP / 2
        return centre + slotsOnRow * (iconSize + GAP),
               topY - (def.row - 1) * (iconSize + GAP) - 6
    end

    for _, def in ipairs(DOLL) do
        local entry = bySlot[def.slot]
        local b = AcquireIcon(self, content)
        local x, iy = dollPos(def)
        -- Sized here, not at creation: the buttons are pooled and the
        -- icon size now depends on the region.
        b:SetSize(iconSize, iconSize)
        b:SetPoint("TOPLEFT", x, iy)

        if entry then
            local link = itemLink(entry)
            local name, icon, hex = itemInfo(entry.itemID, link)
            b.tex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            b.tex:SetDesaturated(false)
            local dollIlvl, dollRank = maxRankIlvl(entry)
            local owned, ownIlvl = ownedIlvl(def.slot, entry, bags)

            -- Three states, not two. "Have it" and "have it at the rank
            -- this list means" are different answers, and collapsing
            -- them was what made a 311 look finished.
            if owned == "bags" then
                -- Collected but not worn. Blue reads as "this is on you
                -- to finish" without claiming it is either done or
                -- missing, and the item stays dimmed because it is.
                b:SetBackdropColor(0.05, 0.11, 0.19, 1)
                b:SetBackdropBorderColor(0.35, 0.62, 0.95, 0.95)
                b.tex:SetDesaturated(true)
                b.tick:SetText(ownIlvl and ("|cff7ab8ff%d|r"):format(ownIlvl)
                    or "|cff7ab8ff bag|r")
            elseif owned and dollIlvl and ownIlvl and ownIlvl < dollIlvl then
                b:SetBackdropColor(0.17, 0.13, 0.04, 1)
                b:SetBackdropBorderColor(0.95, 0.75, 0.25, 0.95)
                b.tick:SetText(("|cffffc83c%d|r"):format(ownIlvl))
            elseif owned then
                b:SetBackdropColor(0.06, 0.16, 0.07, 1)
                b:SetBackdropBorderColor(0.30, 0.85, 0.40, 0.95)
                b.tick:SetText(ownIlvl and ("|cff5cff78%d|r"):format(ownIlvl)
                    or "|cff40ff40*|r")
            else
                b:SetBackdropColor(0.10, 0.10, 0.12, 1)
                b:SetBackdropBorderColor(0.32, 0.32, 0.36, 0.9)
                -- Desaturated reads as "not yet" without needing a
                -- legend; the number marks the ones you have.
                b.tex:SetDesaturated(true)
            end
            hookTooltip(b, entry.itemID, link, dollIlvl, dollRank, ownIlvl, owned)
            hookMenu(b, entry.itemID, entry.name)
            b.tex:SetAlpha(1)
            local _ = name  -- name is shown in the list, not on the doll
        else
            -- An empty cell is information: the guide lists nothing for
            -- this slot. Drawing it keeps the doll's shape readable.
            b.tex:SetTexture(nil)
            b:SetBackdropColor(0.08, 0.08, 0.09, 0.8)
            b:SetBackdropBorderColor(0.20, 0.20, 0.22, 0.7)
        end
    end

    ------------------------------------------------------------
    -- Slot summary, under the doll
    --
    -- Arsenal pairs its two columns of slots with a line saying what is
    -- wrong across all of them, and that is the part worth borrowing: a
    -- doll shows you sixteen states at once and leaves you to add them
    -- up. The counts come from the same pass that drew the icons, so
    -- there is no second walk over the slots to disagree with the first.
    ------------------------------------------------------------
    local haveCount, bagCount, missingCount = 0, 0, 0
    for _, def in ipairs(DOLL) do
        local entry = bySlot[def.slot]
        if entry then
            local owned = ownedIlvl(def.slot, entry, bags)
            if owned == "bags" then bagCount = bagCount + 1
            elseif owned then haveCount = haveCount + 1
            else missingCount = missingCount + 1 end
        end
    end

    if not self._slotSummary then
        self._slotSummary = ns.Widgets:Label(content, "GameFontNormalSmall")
    end
    self._slotSummary:ClearAllPoints()
    self._slotSummary:SetPoint("TOPLEFT", PAD, topY - 8 * (iconSize + GAP) - 6)
    self._slotSummary:SetWidth(DOLL_W)
    self._slotSummary:SetText(("%s  %s  %s"):format(
        ("|cff%s%d equipped|r"):format(ns.Widgets:Hex("good"), haveCount),
        bagCount > 0 and ("|cff%s%d in bags|r"):format(ns.Widgets:Hex("warn"), bagCount)
            or ns.Widgets:Tint("faint", "0 in bags"),
        missingCount > 0 and ("|cff%s%d missing|r"):format(ns.Widgets:Hex("muted"), missingCount)
            or ns.Widgets:Tint("faint", "none missing")))
    self._slotSummary:Show()

    local dollBottom = topY - 8 * (iconSize + GAP) - 14

    ------------------------------------------------------------
    -- List, right
    ------------------------------------------------------------
    local listX = PAD + DOLL_W + 16
    local listW = math.max(inner - DOLL_W - 16, 200)
    local ly = topY

    for _, def in ipairs(DOLL) do
        local entry = bySlot[def.slot]
        if entry then
            local row = AcquireRow(self, content)
            row:SetPoint("TOPLEFT", listX, ly)
            row:SetWidth(listW)

            local link = itemLink(entry)
            local name, icon, hex = itemInfo(entry.itemID, link)
            if icon then row.icon:SetTexture(icon) end
            row.name:SetWidth(listW - 26 - 46)
            row.name:SetText(name and (hex .. name .. "|r")
                or ("|cff5a5a62item " .. entry.itemID .. "|r"))
            if not name then unresolved = unresolved + 1 end

            local src = entry.source or ""
            -- Source only. The item level and "Myth 6/6" were the same
            -- two values on almost every row -- this is a best-in-slot
            -- list, so of course they are all at max rank -- and they
            -- cost roughly 118px of the row. Where a piece drops is the
            -- part that differs, and the width goes to the doll.
            -- The Catalyst turns one item into another, so "which piece
            -- do I feed it" is a question only this column answers.
            if entry.catalystFrom then
                src = src ~= "" and (src .. " |cff9a6ad4+cat|r") or "|cff9a6ad4catalyst|r"
            end
            row.source:SetText("|cff6d6d77" .. src .. "|r")

            -- Equipped is marked on the name itself now that the slot
            -- column is gone, so the signal survives -- and it carries
            -- the same three-state colour as the doll, so the two halves
            -- of the page never disagree about a row.
            local owned, ownIlvl = ownedIlvl(def.slot, entry, bags)
            if owned then
                local mark = "|cff40ff40*|r"
                if owned == "bags" then
                    mark = ownIlvl and ("|cff7ab8ff%d|r"):format(ownIlvl) or "|cff7ab8ffbag|r"
                elseif ilvl and ownIlvl and ownIlvl < ilvl then
                    mark = ("|cffffc83c%d|r"):format(ownIlvl)
                elseif ownIlvl then
                    mark = ("|cff5cff78%d|r"):format(ownIlvl)
                end
                row.name:SetText((name and (hex .. name .. "|r")
                    or ("|cff777777item " .. entry.itemID .. "|r")) .. " " .. mark)
            end
            hookTooltip(row, entry.itemID, link, ilvl, rank, ownIlvl, owned)
            hookMenu(row, entry.itemID, entry.name)
            ly = ly - ROW_H
        end
    end

    -- Options the guide lists beyond what a character can wear at once
    -- (a third trinket, a spare ring). No doll cell can hold them, and
    -- silently dropping them would delete advice the guide gave.
    if #spare > 0 then
        ly = ly - 8
        local sh = AcquireFS(self, content, "GameFontNormalSmall")
        sh:SetPoint("TOPLEFT", listX, ly)
        sh:SetTextColor(0.55, 0.55, 0.62)
        sh:SetText("Also listed")
        ly = ly - 16

        for _, entry in ipairs(spare) do
            local row = AcquireRow(self, content)
            row:SetPoint("TOPLEFT", listX, ly)
            row:SetWidth(listW)
            local link = itemLink(entry)
            local name, icon, hex = itemInfo(entry.itemID, link)
            if icon then row.icon:SetTexture(icon) end
            row.name:SetWidth(listW - 26 - 46)
            row.name:SetText(name and (hex .. name .. "|r")
                or ("|cff777777item " .. entry.itemID .. "|r"))
            -- Source only, as in the main list above. These rows had
            -- their own copy of the item level and rank formatting, so
            -- trimming the one branch left "Also listed" still carrying
            -- "334 Myth 6/6" while everything above it had stopped.
            --
            -- sIlvl and sRank stay: the tooltip below still shows the
            -- item level a piece maxes at, which is worth knowing on
            -- hover even when it is noise in the row.
            local sIlvl, sRank = maxRankIlvl(entry)
            local sSrc = entry.source or ""
            row.source:SetText("|cff6d6d77" .. sSrc .. "|r")
            hookTooltip(row, entry.itemID, link, sIlvl, sRank)
            hookMenu(row, entry.itemID, entry.name)
            ly = ly - ROW_H
        end
    end

    -- Sized now that the guide's length is known; it was acquired up
    -- with the doll's panel so it sits behind the rows.
    listPanel:SetPoint("TOPLEFT", listX - 8, topY + 8)
    listPanel:SetSize(listW + 16, math.max((topY + 8) - ly + 4, 40))

    -- Below BOTH columns, with room to breathe.
    --
    -- dollBottom is the last icon row, not the bottom of the doll: the
    -- "0 equipped, 0 in bags, 16 missing" summary sits under it and the
    -- panel's own edge under that. Taking the min against it put the
    -- Stat Priority heading straight through the summary line.
    local dollPanelBottom = topY + 8 - dollH - 12
    y = math.min(dollPanelBottom, ly - 10) - GAP * 3

    ------------------------------------------------------------
    -- Stat priority
    ------------------------------------------------------------
    if data.statPriority and #data.statPriority > 0 then
        local h = AcquireFS(self, content, "GameFontNormal")
        h:SetPoint("TOPLEFT", PAD, y)
        h:SetTextColor(unpack(ACCENT))
        h:SetText("Stat Priority")
        -- Clear of the heading rather than tucked under it. The cards
        -- were anchored 12px ABOVE this cursor to make room for their
        -- own padding, which ran their top edge through the heading.
        y = y - 26

        -- Side by side rather than stacked. Two or three builds down the
        -- page pushed the caveat off the bottom and forced a scrollbar;
        -- across the width they cost one row however many there are, and
        -- comparing two priorities is easier when they are adjacent.
        --
        -- Measured as CARDS, with the text inset into them. The reverse
        -- -- columns of text with a card drawn around each -- is what let
        -- two cards overlap while their text was still neatly apart.
        local n = #data.statPriority
        local cardW = math.floor((inner - (n - 1) * CARD_GAP) / n)

        local heroArt = HeroTalentArt()

        -- Whether ANY card gets art, decided before any of them is
        -- drawn. Per-card would be the obvious way and the wrong one: a
        -- guide can name a build the client has no subtree for, and a
        -- row of cards where one is 8px taller than its neighbour reads
        -- as a mistake rather than as a difference.
        local anyArt = false
        for _, entry in ipairs(data.statPriority) do
            for _, build in ipairs(entry.builds or {}) do
                local a = heroArt[build:lower()]
                if a and a.icon then anyArt = true end
            end
        end
        -- Name over stats in a column beside the medallion, so the card
        -- is as tall as its text and the art sits centred against the
        -- whole of it rather than perching on the first line.
        local cardH = CARD_PAD * 2 + NAME_H + NAME_GAP + STAT_LINES_H
        if anyArt then cardH = math.max(cardH, CARD_PAD * 2 + HERO_ART) end
        local ringIdle = { ns.Widgets:Color("faint") }

        for i, entry in ipairs(data.statPriority) do
            local cardX = PAD + (i - 1) * (cardW + CARD_GAP)

            -- Lit when it is the build you are specced into. Read across
            -- every build the card covers, because two hero talents that
            -- want the same stats share one, and taking either of them
            -- makes that card the one that applies to you.
            local lit = false
            for _, build in ipairs(entry.builds or {}) do
                local a = heroArt[build:lower()]
                if a and a.active then lit = true end
            end
            -- Where the text starts: the card's corner, brought in by
            -- its padding. Every anchor below is off this pair, so the
            -- text cannot drift out of the card it belongs to.
            local tx, ty = cardX + CARD_PAD, y - CARD_PAD

            -- Each build sits on its own card, so two hero talents read
            -- as two things rather than as one paragraph with a gap in
            -- it. The surface comes from the skin like every other card
            -- on the page; the text keeps its own anchors and simply
            -- sits on top.
            local card = AcquireCard(self, content)
            card:SetPoint("TOPLEFT", cardX, y)
            card:SetSize(cardW, cardH)
            -- Painted after sizing, not on acquire: the wash divides the
            -- shape by its width to place each piece in the fade, so a
            -- card still at its default size would get a gradient
            -- squeezed into the wrong width.
            if ns.Widgets then
                ns.Widgets:Rounded(card, "inset", CARD_RADIUS, CardColours(lit))
            end

            -- One medallion per build the card covers. Two builds share
            -- a card when they want the same stats, and showing both
            -- says which two rather than making the reader parse the
            -- slash in the label.
            --
            -- Centred down the card rather than hung from its top edge,
            -- which is what makes the art the card's subject instead of
            -- a bullet in front of its heading.
            local artW = 0
            local medY = y - math.floor((cardH - HERO_ART) / 2)
            for _, build in ipairs(entry.builds or {}) do
                local art = heroArt[build:lower()]
                if art and art.icon then
                    local med = AcquireMedallion(self, content)
                    SetArt(med.icon, art.icon, true)
                    med.icon:SetSize(HERO_ART, HERO_ART)
                    med.icon:SetPoint("TOPLEFT", content, "TOPLEFT", tx + artW, medY)
                    -- The rim carries the same answer the card does, so
                    -- a card covering two trees still says which of them
                    -- is the one you took.
                    if art.active then
                        med.ring:SetVertexColor(LIT[1], LIT[2], LIT[3], 1)
                    else
                        med.ring:SetVertexColor(ringIdle[1], ringIdle[2], ringIdle[3], 0.9)
                    end
                    artW = artW + HERO_ART + 4
                end
            end

            -- The text column starts clear of the art, and runs to the
            -- card's far padding rather than to a width of its own -- so
            -- one medallion or two, it still ends where the card does.
            local colX = tx + (artW > 0 and (artW + 6) or 0)
            local colW = math.max(cardX + cardW - CARD_PAD - colX, 40)

            -- Builds are named rather than collapsed: where two hero
            -- talents want different stats, saying which is which is the
            -- whole reason they are stored apart. The name stays even
            -- with the art beside it -- the art tells them apart at a
            -- glance, the name is what they are called out loud.
            -- Set in caps, as Blizzard's picker sets them. A hero talent
            -- name is a proper noun for a thing you chose, and at the
            -- weight it had before -- small, grey, level with the stats
            -- under it -- it read as a caption on the priority rather
            -- than as the name of the build the priority belongs to.
            --
            -- Only the names. The context note stays in its own case:
            -- it is a sentence fragment, and shouting it makes it look
            -- like part of the title.
            local blabel = table.concat(entry.builds or {}, " / "):upper()
            if entry.context and entry.context ~= "" then
                blabel = blabel .. "  |cff666666(" .. entry.context .. ")|r"
            end

            local b = AcquireFS(self, content, "GameFontNormal")
            b:SetPoint("TOPLEFT", colX, ty)
            b:SetWidth(colW)
            -- Lit cards get the full text colour and unlit ones the
            -- muted tone, so the pair reads at a glance even before the
            -- gold registers.
            if lit then
                b:SetTextColor(ns.Widgets:Color("text"))
            else
                b:SetTextColor(ns.Widgets:Color("muted"))
            end
            b:SetText(blabel)
            ns.ApplyTextShadow(b)

            local sp = AcquireFS(self, content, "GameFontNormalSmall")
            sp:SetPoint("TOPLEFT", colX, ty - (NAME_H + NAME_GAP))
            sp:SetWidth(colW)
            sp:SetWordWrap(true)
            sp:SetText("|cffffffff" .. table.concat(entry.stats or {},
                "|r |cff555555>|r |cffffffff") .. "|r")
        end
        -- Off the card's own bottom edge, not off the tallest run of
        -- stat text. Measuring the text and ignoring the card is how the
        -- caveat underneath ended up two pixels inside it.
        y = y - cardH - 10
    end

    ------------------------------------------------------------
    -- Pending items
    ------------------------------------------------------------
    -- BiS lists are published against the incoming patch, so before it
    -- goes live the client has never heard of half these item IDs and
    -- GetItemInfo returns nothing for them. That is not a failure and
    -- should not look like one -- it resolves itself the moment the
    -- patch lands, and saying so beats a column of bare numbers.
    if unresolved > 0 then
        local pend = AcquireFS(self, content, "GameFontNormalSmall")
        pend:SetPoint("TOPLEFT", PAD, y)
        pend:SetWidth(inner)
        pend:SetWordWrap(true)
        pend:SetTextColor(0.70, 0.62, 0.35)
        pend:SetText(("%d of these items are not in your client's data yet — "
            .. "names and item levels fill in once the patch is live.")
            :format(unresolved))
        y = y - (pend:GetStringHeight() or 12) - 8
    end

    ------------------------------------------------------------
    -- Caveat
    ------------------------------------------------------------
    local caveat = ns.GEAR_CAVEAT and ns.GEAR_CAVEAT.bis
    if caveat then
        local note = AcquireFS(self, content, "GameFontNormalSmall")
        note:SetPoint("TOPLEFT", PAD, y - 6)
        note:SetWidth(inner)
        note:SetWordWrap(true)
        note:SetTextColor(0.60, 0.60, 0.66)
        note:SetText(caveat)
        y = y - (note:GetStringHeight() or 30) - 18
    end

end

function UI:Refresh()
    if self._content then
        -- Height as well as width. Render only ever took width, so the
        -- doll was drawn at a fixed size regardless of the region and
        -- left the bottom third of the page empty.
        self:Render(self._content, self._content:GetWidth(),
            self._content:GetHeight())
    end
end

function UI:BuildInto(parent)
    if parent._yyhBisBuilt then
        self:Refresh()
        return
    end
    parent._yyhBisBuilt = true

    local host = parent.inner or parent

    -- Plain frame, not a ScrollFrame. The page is a fixed sixteen slots
    -- plus a stat block, so it can be laid out to fit -- and a scrollbar
    -- on something that nearly fits is worse than either extreme,
    -- because it hides the last two rows behind a gesture.
    local content = CreateFrame("Frame", nil, host)
    content:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -8)
    content:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -8, 8)
    self._content = content

    -- Equipping a piece, changing spec, an item name arriving, or a
    -- piece landing in your bags all change what this page should say,
    -- so redraw rather than making the player reopen it.
    --
    -- Filtered and debounced, because the naive version made tooltips
    -- unusable. GET_ITEM_INFO_RECEIVED is a GLOBAL event: the client
    -- fires it once per item as data streams in, for every item anything
    -- asks about -- this addon, other addons, the game itself. Each one
    -- ran a full Refresh, and Refresh calls Release, which hides every
    -- pooled frame and re-shows it. Hovering a row while that happened
    -- fired OnLeave then OnEnter, so the tooltip vanished and came back
    -- several times a second. That is the flicker: not a tooltip bug, a
    -- redraw storm underneath it.
    local watcher = CreateFrame("Frame", nil, host)
    watcher:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    watcher:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    watcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    -- Bags count towards "collected", so a drop has to redraw the page.
    -- DELAYED rather than BAG_UPDATE, which fires once per bag per
    -- change and would rebuild the doll several times for one loot.
    watcher:RegisterEvent("BAG_UPDATE_DELAYED")

    local pending = false
    watcher:SetScript("OnEvent", function(_, event, itemID)
        if not parent:IsShown() then return end
        -- An item we are not drawing tells us nothing. This alone drops
        -- the great majority of the traffic, since most of it belongs to
        -- somebody else.
        if event == "GET_ITEM_INFO_RECEIVED"
           and itemID and not UI._wantItem[itemID] then
            return
        end
        if pending then return end
        pending = true
        -- Coalesce the burst into one redraw. A quarter second is below
        -- the threshold where a page feels stale and far above the gap
        -- between two of these events.
        C_Timer.After(0.25, function()
            pending = false
            if parent:IsShown() then UI:Refresh() end
        end)
    end)

    self:Refresh()
end
