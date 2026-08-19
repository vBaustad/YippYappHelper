local _, ns = ...

------------------------------------------------------------
-- Dashboard.
--
-- The first page, and the first one built entirely out of ns.Widgets
-- rather than out of frames it draws itself. That is the point of it:
-- if the dashboard cannot be made from the vocabulary, the vocabulary is
-- wrong, and better to find that out on one page than on nine.
--
-- Says who you are, what the vault owes you, and what is worth doing
-- tonight. Currencies are deliberately absent -- they live in the rail,
-- on every page, and having them here as well is what put two crest
-- panels on screen at once.
--
-- Every number on this page comes from a function that exists. The first
-- version called ns.GetVaultProgress(ns, key) expecting three return
-- values, ns.CountUpgradeableSlots and ns.Advisor:GetLine -- the last two
-- were invented outright and the first has a different signature
-- entirely: ns:GetVaultProgress() takes no arguments and returns a table.
-- Comparing that table to a number threw on the first vault row, so the
-- page rendered its hero and then stopped, which is why it looked empty
-- rather than broken. The real sources are ns.Planner:GetVaultSnapshot
-- and ns.Planner:BuildPlan, both of which already existed.
------------------------------------------------------------

local Shell, W = ns.Shell, ns.Widgets
if not (Shell and W) then return end

-- Taken from the shell rather than chosen here, so the page breathes to
-- the same rhythm as the chrome around it. Two pages picking their own
-- padding is how the old dashboard ended up a different shape to
-- everything it sat next to.
local PAD, GAP = Shell.PAD, Shell.GAP

-- Keys match ns.Planner:GetVaultSnapshot's return table.
--
-- `unit` is what a slot's threshold counts, which differs per category
-- and is the difference between "4" and "raid bosses 4".
--
-- No per-category accent. Each row carried one and the tile stripes were
-- painted with it, which spent the strongest signal on the one fact
-- already spelled out in words immediately to the left. See SLOT_STATE.
--
-- `art` is the client's own Great Vault category scene.
--
-- These went in, looked terrible, came out, and are back -- because the
-- art was never the problem. Measured against the vault itself, the
-- numbers around it were: the column was 118px for a wide panorama that
-- wants about 210, and the veil over it ran 0.35 to 0.75 across the
-- whole strip instead of only its right edge, which is very nearly
-- opaque black over most of the picture. Two mistakes that between them
-- guaranteed a black rectangle whatever art went behind them.
local VAULT_ROWS = {
    { key = "mplus", label = "Mythic+", unit = "dungeons",
      art = "evergreen-weeklyrewards-category-dungeons" },
    { key = "raid",  label = "Raid",    unit = "bosses",
      art = "evergreen-weeklyrewards-category-raids" },
    { key = "world", label = "World",   unit = "world",
      art = "evergreen-weeklyrewards-category-world" },
}

-- Deliberately NOT the vault's own slot faces.
--
-- EllesmereUI's skin strips exactly those -- fifteen StripTexture calls,
-- and `frame.Background` on every reward frame is one of them -- and
-- leaves the category scenes alone. Its cards are flat dark panels with
-- a thin bar, which is what ours already are. Following the skin means
-- keeping our own panel here and spending the art budget on the scenes.
local CHECK_ATLAS = "activities-icon-checkmark"
local LOCK_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-LOCK"

-- What a slot's stripe means, and the only thing it means.
--
-- Hue used to be the category and alpha the state. Both were wrong.
-- The category is named in the row label beside it, so the colour was
-- redundant -- and worse than redundant, because World's category
-- colour was `good`, the same green used for a finished slot. A locked
-- world slot sitting at 7/8 therefore wore the exact colour of an
-- unlocked one, and the row header said "2 of 3" while three tiles
-- looked done. Meanwhile the distinction anyone actually wants was
-- 0.5 versus 0.85 alpha on a three-pixel stripe.
--
-- Now: dim is untouched, amber is started, green is yours. Three
-- states, three colours, identical in every row.
local SLOT_STATE = {
    none     = { role = "faint", alpha = 0.15 },
    locked   = { role = "faint", alpha = 0.40 },
    progress = { role = "warn",  alpha = 0.90 },
    unlocked = { role = "good",  alpha = 1.00 },
}

--- Paint a vault slot's bottom fill for its state and how far along it
--- is, and record both. The record is what lets Tools/loadcheck.py
--- assert that two slots in the same state look identical whichever row
--- they sit in -- the property the old category-coloured stripe broke.
---
--- `pct` is clamped rather than trusted: a slot can report progress past
--- its own threshold (nine dungeons against a threshold of eight) and a
--- fill wider than its track would spill out of the card.
local function SetSlotFill(tile, state, pct)
    local s = SLOT_STATE[state] or SLOT_STATE.locked
    local r, g, b = W:Color(s.role)
    tile.fill:SetColorTexture(r, g, b, 1)
    tile.fill:SetAlpha(s.alpha)

    -- The unfilled remainder, in the same hue and barely there.
    --
    -- This used the `track` role -- {0.16, 0.16, 0.18} -- on a card that
    -- is already about that dark, so the empty part of the bar was
    -- invisible and "1 of 8" drew as a lone nub floating at the left
    -- edge with nothing to be a fraction OF. A bar without its track is
    -- half a bar.
    tile.track:SetColorTexture(r, g, b, 1)
    tile.track:SetAlpha(0.16)

    pct = math.min(math.max(tonumber(pct) or 0, 0), 1)
    local w = tile.track:GetWidth() or 0
    -- Widths are zero until the frame has been laid out, and a texture
    -- given a width of zero is simply invisible -- so an unlocked slot
    -- would draw no bar at all on the first pass. Anchoring the right
    -- edge for a full bar sidesteps the measurement entirely, which is
    -- also the common case worth getting right.
    tile.fill:ClearAllPoints()
    tile.fill:SetPoint("BOTTOMLEFT", tile.track, "BOTTOMLEFT", 0, 0)
    if pct >= 1 then
        tile.fill:SetPoint("BOTTOMRIGHT", tile.track, "BOTTOMRIGHT", 0, 0)
    else
        tile.fill:SetWidth(math.max(w * pct, pct > 0 and 1 or 0))
    end

    tile._slotState, tile._slotPct = state, pct
end

--- Mark a slot earned or not: checkmark or padlock, and the lines its
--- hover should carry.
local function SetSlotMark(tile, earned, need, ilvl, progress, notes)
    local checked = (earned and tile._hasCheck and true) or false
    tile.lock:SetShown(not earned)
    tile.check:SetShown(checked)

    -- The caption starts clear of the checkmark when there is one.
    -- Anchored at a flat 9px it ran straight under the tick, so the
    -- first word of every earned slot was struck through by it.
    tile.caption:ClearAllPoints()
    tile.caption:SetPoint("TOPLEFT", checked and 27 or 9, -8)
    tile.caption:SetPoint("RIGHT", tile, "RIGHT", -9, 0)

    tile._need, tile._ilvl, tile._progress, tile._notes =
        need, ilvl, progress, notes
    tile._hasReward = ilvl ~= nil
end

--- What `activityInfo.level` means, which is not one thing.
---
--- It is the level of the runs that qualified a slot, and each category
--- counts in its own units: a keystone level for Mythic+, a delve tier
--- for World, and a difficulty ID -- 14, 15, 16 -- for Raid. One "+%d"
--- across all three was right for Mythic+ only. It rendered delve tier 5
--- as "+5" where the vault itself writes "Tier 5", and would have shown
--- Heroic raid as "+15", which is not a thing anyone has ever said.
local function QualifierText(kind, level)
    level = tonumber(level)
    if not level or level <= 0 then return nil end
    if kind == "world" then
        return ("Tier %d"):format(level)
    elseif kind == "raid" then
        -- The client names its own difficulties; the numbers are an
        -- internal detail and not worth a lookup table that goes stale.
        local name = GetDifficultyInfo and GetDifficultyInfo(level)
        return name or ("Difficulty %d"):format(level)
    end
    return ("+%d"):format(level)
end

--- `long` adds the qualifier -- the keystone level, delve tier or raid
--- difficulty. Only the tooltip asks for it: on the card it has to share
--- one line with the fraction, and at this width the tier is what pushed
--- the two into each other. The hover has room and no competition.
--- The item level written out, for the hover.
---
--- Named here, unlike on the card: a tooltip line is read, not glanced
--- at, and the qualifier -- keystone level, delve tier, raid difficulty
--- -- has room beside it that the card cannot spare.
local function RewardText(slot, kind, long)
    -- Read off the snapshot rather than asked of the client again. The
    -- planner needs the same figure to say "289 -> 302", and two places
    -- resolving it separately is two places that can disagree.
    local ilvl = tonumber(slot and slot.rewardIlvl)
    local qualifier = long and QualifierText(kind, slot and slot.level) or nil
    if ilvl and ilvl > 0 then
        if qualifier then
            return ("|cff8a8a92Item level|r |cff6ee88a%d|r |cff8a8a92%s|r")
                :format(ilvl, qualifier)
        end
        return ("|cff8a8a92Item level|r |cff6ee88a%d|r"):format(ilvl)
    end
    if qualifier then return ("|cff6ee88a%s|r"):format(qualifier) end
    return "|cff6ee88aready|r"
end

local PLAN_ROWS = 6
local PLAN_ROW_H = 46
-- Headroom over the fixed checklist items for the weekly-capped
-- currencies the client discovers. Two this season; the ceiling is here
-- so a season with more does not silently lose the tail.
local WEEKLY_ROWS = 12
local WEEKLY_ROW_H = 24
-- Two columns, because these are one-line rows and a full-width one
-- wastes two thirds of itself on empty space. Eight of them stacked ran
-- off the bottom of the page and into the tab strip; side by side they
-- take half the height and read no worse -- a checklist is scanned down
-- a column, and two short columns scan faster than one long one.
local WEEKLY_COLS = 2
-- The room UIPanelScrollFrameTemplate's bar wants down the right. Taken
-- off the scroll frame rather than off each section, so the sections go
-- on measuring themselves against a width that is really theirs.
local SCROLLBAR_W = 20

-- The vault is three categories of three rewards. Read from the data
-- where possible, but the row has to be built before the data is asked
-- for, so three is the shape and a category returning more is clamped.
local VAULT_SLOTS = 3
-- Taller than it was, on purpose. At 52 the card was a 4:1 letterbox
-- with its caption in one corner and its value in the opposite one and
-- nothing in between -- Blizzard's arrangement at a proportion that
-- cannot carry it. The height buys the reward's own icon, which is what
-- fills that space in the vault this is modelled on.
-- Proportioned off the real vault rather than picked, since that is what
-- this is meant to read as. Its rows run about 150px against a 355px art
-- column in a ~1200px frame; our content region is roughly 750, so
-- everything below is that geometry divided by about 1.6.
local VAULT_ROW_H = 88
local VAULT_LABEL_W = 210
-- 19% of the card's height in the vault, which at that size is a quiet
-- mark rather than the loudest thing on screen. At 32px in a 74px card
-- -- 43% -- it became the only thing anyone saw, nine times over.
local VAULT_LOCK = 18
local VAULT_BAR_H = 4


local ui

local function Build(host)
    ui = { host = host }
    -- Published so the widgets this page builds can be inspected from
    -- outside it -- by the test harness, and by anyone debugging a
    -- layout in game. Read-only by convention; nothing here reads it
    -- back.
    ns.ShellHomeUI = ui

    -- The page scrolls.
    --
    -- Measured rather than assumed: the content region is 702 tall and
    -- the page ran to 845 -- so the checklist was simply not drawn, it
    -- was drawn past the bottom edge and into the tab strip. Two columns
    -- got a hundred pixels back and it still did not fit.
    --
    -- The alternative was shaving six constants until it did, which
    -- would have looked cramped and broken again the first time the
    -- planner had one more thing to say or the client capped one more
    -- currency. The content here is genuinely variable, so a fixed
    -- budget is a losing argument. With two columns the scroll stays
    -- short, which was the actual ask.
    ui.scroll = W:ScrollList(host)
    ui.scroll:SetPoint("TOPLEFT", 0, 0)
    ui.scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR_W, 0)
    local page = ui.scroll.content
    ui.page = page

    -- No hero card here. The character column carries the portrait,
    -- name, item level and stats on every page, so repeating it on the
    -- dashboard put the same face on screen twice.
    --
    -- `anchor` stands in for it as the thing the first section hangs
    -- from, so the rest of the page keeps its shape.
    ui.top = CreateFrame("Frame", nil, page)
    ui.top:SetHeight(1)
    ui.top:SetPoint("TOPLEFT", PAD, -PAD)
    ui.top:SetPoint("RIGHT", page, "RIGHT", -PAD, 0)

    ------------------------------------------------------------
    -- Great Vault
    ------------------------------------------------------------
    ui.vaultTitle = W:SectionTitle(page, "Great Vault")
    ui.vaultTitle:SetPoint("TOPLEFT", ui.top, "BOTTOMLEFT", 0, 0)
    ui.vaultTitle:SetPoint("RIGHT", ui.top, "RIGHT", 0, 0)

    -- One tile per vault slot, not one bar per category.
    --
    -- The bar version read "0/3  0/1 for slot 1", which is two unrelated
    -- numbers sharing a line and needing a paragraph to explain. The
    -- vault is nine discrete rewards and the only questions worth
    -- answering are which are unlocked and what the next one costs, so
    -- each slot gets its own tile saying exactly that.
    ui.rows = {}
    local anchor = ui.vaultTitle
    for i, def in ipairs(VAULT_ROWS) do
        local row = CreateFrame("Frame", nil, page)
        row:SetHeight(VAULT_ROW_H)
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, i == 1 and -10 or -GAP)
        row:SetPoint("RIGHT", ui.top, "RIGHT", 0, 0)

        -- The category's scene, at full strength and uncropped.
        row.art = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        row.art:SetPoint("TOPLEFT", 0, -1)
        row.art:SetPoint("BOTTOMRIGHT", row, "BOTTOMLEFT", VAULT_LABEL_W - 12, 1)
        if W:TrySetAtlas(row.art, def.art) then
            -- The left eighth cropped off, because the fade is painted
            -- into the art.
            --
            -- Two rounds of lightening my own washes did not shift it,
            -- and it survives on all three scenes identically -- which
            -- is not what a bug in one gradient looks like. In the
            -- vault these sit flush against the frame's left edge and
            -- are drawn to dissolve into it, so the darkness at that end
            -- is the atlas doing its job somewhere we are not. Cropping
            -- past it is the only way to get the picture without it,
            -- since the fade cannot be un-painted.
            row.art:SetTexCoord(0.13, 1, 0, 1)
            -- The veil covers the right third and nothing else. Its job
            -- is to let the picture meet the page without a seam, not to
            -- darken the picture -- which is what it was doing when it
            -- ran across the whole strip.
            row.artFade = row:CreateTexture(nil, "BACKGROUND", nil, 2)
            row.artFade:SetPoint("TOPRIGHT", row.art, "TOPRIGHT", 0, 0)
            row.artFade:SetPoint("BOTTOMLEFT", row.art, "BOTTOMRIGHT", -70, 0)
            W:ColourWash(row.artFade, "HORIZONTAL", 0, 0, 0, 0, 0.95)
            -- A second, much lighter one under the label only, so the
            -- text has something to sit on wherever the scene is bright.
            -- Both BOTTOM corners, not BOTTOMLEFT and RIGHT.
            --
            -- RIGHT fixes the vertical CENTRE, and a texture given both
            -- a bottom edge and a centre has its height decided by the
            -- anchors -- the art's full height -- with SetHeight quietly
            -- ignored. So this band was not a band: it was a full-height
            -- gradient over the whole picture, which is the wash across
            -- the art rather than under the label.
            row.artFoot = row:CreateTexture(nil, "BACKGROUND", nil, 3)
            row.artFoot:SetPoint("BOTTOMLEFT", row.art, "BOTTOMLEFT", 0, 0)
            row.artFoot:SetPoint("BOTTOMRIGHT", row.art, "BOTTOMRIGHT", 0, 0)
            row.artFoot:SetHeight(34)
            W:ColourWash(row.artFoot, "VERTICAL", 0, 0, 0, 0.75, 0)
        else
            row.art:Hide()
        end

        -- Over the scene, along its bottom edge, the way the vault sets
        -- its category names.
        row.label = W:Label(row, "GameFontNormalLarge")
        row.label:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 16)
        row.label:SetWidth(VAULT_LABEL_W - 20)
        row.label:SetText(def.label)

        row.tally = W:Label(row, "GameFontNormalSmall")
        row.tally:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 1, -1)
        row.tally:SetWidth(VAULT_LABEL_W - 20)
        row.tally:SetTextColor(W:Color("muted"))

        row.slots = {}
        for s = 1, VAULT_SLOTS do
            local tile = W:Panel(row, "inset")

            -- One line, and the bar under it.
            --
            -- Three passes went the other way -- reward icons, the
            -- vault's own slot faces, category scenes, padlocks -- and
            -- each one read worse than the last. The lesson was not that
            -- the art was wrong but that the goal was: this strip exists
            -- to say whether anything is waiting and what is closest,
            -- and the real Great Vault is one keypress away and already
            -- beautiful. A second, smaller copy of it was never going to
            -- beat the original, and every element added to chase it
            -- cost height and gave nothing back.
            -- Requirement across the top, reward in the far corner --
            -- the vault's own card, and it works at this proportion
            -- because the card is now nearly as tall as it is wide.
            tile.caption = W:Label(tile, "GameFontNormalSmall")
            tile.caption:SetPoint("TOPLEFT", 9, -8)
            tile.caption:SetPoint("RIGHT", tile, "RIGHT", -9, 0)
            tile.caption:SetTextColor(W:Color("muted"))

            -- No reward icon in the card.
            --
            -- A 34px item icon in the middle of a slot is a picture of
            -- one example roll, at a size too small to identify and in
            -- the position the padlock uses on every other card -- so
            -- the row read as "lock, lock, something". The reward is
            -- better said in words at the foot of the card and shown in
            -- full on hover, which is where the item actually belongs.
            tile.lock = tile:CreateTexture(nil, "ARTWORK")
            tile.lock:SetSize(VAULT_LOCK, VAULT_LOCK)
            tile.lock:SetPoint("CENTER", tile, "CENTER", 0, -2)
            tile.lock:SetTexture(LOCK_TEXTURE)
            tile.lock:SetAlpha(0.45)
            tile.lock:SetDesaturated(true)
            tile.lock:Hide()

            tile.check = tile:CreateTexture(nil, "OVERLAY", nil, 2)
            tile.check:SetSize(16, 16)
            tile.check:SetPoint("TOPLEFT", 6, -5)
            tile._hasCheck = W:TrySetAtlas(tile.check, CHECK_ATLAS)
            tile.check:Hide()

            -- Bottom left says what the slot pays; bottom right says how
            -- far along it is. Every card then has a fraction in the same
            -- corner, earned or not, which is what stops the row losing
            -- its shape at the one slot worth looking at.
            tile.state = W:Label(tile, "GameFontNormal", "RIGHT")
            tile.state:SetPoint("BOTTOMRIGHT", -9, VAULT_BAR_H + 6)

            -- The item level, large, in the middle -- exactly where the
            -- padlock sits on a slot you have not earned.
            --
            -- One position, two answers: locked shows the lock, earned
            -- shows what it is worth. That also retires the pair of
            -- labels that used to share the bottom corner, where the one
            -- on the left had nothing stopping it running under the one
            -- on the right. A number alone in the middle cannot collide
            -- with anything.
            --
            -- No "Item level" caption: it named the number when the
            -- number was small and tucked in a corner. At this size, in
            -- the centre of a vault slot, it is not ambiguous.
            tile.big = W:Label(tile, "GameFontNormalLarge", "CENTER")
            tile.big:SetPoint("CENTER", tile, "CENTER", 0, -2)
            tile.big:SetFont(STANDARD_TEXT_FONT, 22, "")
            -- Blizzard's own gold, taken from the client's constant
            -- rather than typed in, so it follows if they ever retune
            -- it. Green is still doing the "this one is yours" job on
            -- the checkmark and the bar underneath; the number itself is
            -- a value, and gold is what the game paints values.
            local gold = NORMAL_FONT_COLOR
            tile.big:SetTextColor(gold and gold.r or 1,
                                  gold and gold.g or 0.82,
                                  gold and gold.b or 0)

            -- Progress on hover, and deliberately NOT the item.
            --
            -- GetExampleRewardItemHyperlinks returns an EXAMPLE. The
            -- actual reward is chosen from a selection at the moment you
            -- claim it, so putting that item's tooltip on the card
            -- promises a specific drop the vault has not decided on --
            -- which is worse than showing nothing. The item LEVEL is
            -- fair game, because that is fixed by what earned the slot,
            -- and it is the only part of that link this page uses.
            tile:EnableMouse(true)
            tile:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(self._need or "Great Vault", 1, 0.82, 0)
                if self._ilvl then
                    GameTooltip:AddLine(self._ilvl, 0.43, 0.91, 0.54)
                end
                if self._progress then
                    GameTooltip:AddDoubleLine("Progress", self._progress,
                        0.7, 0.7, 0.72, 1, 1, 1)
                end
                for _, line in ipairs(self._notes or {}) do
                    GameTooltip:AddLine(line, 0.7, 0.7, 0.72, true)
                end
                GameTooltip:Show()
            end)
            tile:SetScript("OnLeave", function() GameTooltip:Hide() end)

            -- Colour says locked / started / yours; length says how far
            -- along. The track behind it is the same hue barely there,
            -- so a small fraction still reads as a fraction OF
            -- something rather than as a nub floating at the left edge.
            tile.track = tile:CreateTexture(nil, "ARTWORK")
            tile.track:SetPoint("BOTTOMLEFT", 2, 2)
            tile.track:SetPoint("BOTTOMRIGHT", -2, 2)
            tile.track:SetHeight(VAULT_BAR_H)

            tile.fill = tile:CreateTexture(nil, "OVERLAY")
            tile.fill:SetPoint("BOTTOMLEFT", tile.track, "BOTTOMLEFT", 0, 0)
            tile.fill:SetHeight(VAULT_BAR_H)
            SetSlotFill(tile, "none", 0)

            row.slots[s] = tile
        end

        ui.rows[def.key] = row
        anchor = row
    end

    ------------------------------------------------------------
    -- Tonight
    ------------------------------------------------------------
    -- The "This Week" section is gone.
    --
    -- It was a heading, a rule and three bordered cells -- about a
    -- hundred pixels of page -- for three facts, one of which ("vault
    -- unlocked, 3 of 9") simply restated the three row tallies directly
    -- above it. The other two qualify a section rather than standing on
    -- their own, so they now sit as the right-hand aside on the heading
    -- of the section each belongs to: the reset clock on the vault, the
    -- keystone on the plan. Same information, no section.
    ui.planTitle = W:SectionTitle(page, "Worth Doing Tonight")
    -- Left half of a two-column row. Both this and the checklist beside
    -- it get their width on refresh, from the split.
    ui.planTitle:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -GAP * 2)

    ui.plan = {}
    anchor = ui.planTitle
    for i = 1, PLAN_ROWS do
        local card = W:Panel(page, "inset")
        card:SetHeight(PLAN_ROW_H)
        card:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, i == 1 and -10 or -6)

        card.stripe = card:CreateTexture(nil, "OVERLAY")
        card.stripe:SetPoint("TOPLEFT", 3, -3)
        card.stripe:SetPoint("BOTTOMLEFT", 3, 3)
        card.stripe:SetWidth(3)

        -- One line each, and truncated rather than wrapped.
        --
        -- At full width these never wrapped, so nothing stopped them.
        -- Halved, the longer titles ran onto a second line and pushed
        -- straight through the detail underneath -- and a card that
        -- grows into its neighbour is worse than one that ends in an
        -- ellipsis, because the ellipsis tells you it was trimmed. The
        -- titles were also shortened so the real ones fit; this is the
        -- guard for the one I have not thought of.
        card.title = W:Label(card, "GameFontNormal")
        card.title:SetPoint("TOPLEFT", 16, -8)
        card.title:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        card.title:SetWordWrap(false)

        card.detail = W:Label(card, "GameFontNormalSmall")
        card.detail:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -3)
        card.detail:SetWordWrap(false)
        card.detail:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        card.detail:SetTextColor(W:Color("muted"))

        ui.plan[i] = card
        anchor = card
    end

    ------------------------------------------------------------
    -- Also this week
    ------------------------------------------------------------
    -- Shorter rows than the plan above, and deliberately so. The plan
    -- says what to do next; this is a list of chores, and a chore does
    -- not need a card the size of a recommendation.
    ui.weekTitle = W:SectionTitle(page, "Also This Week")
    -- Right half, level with the plan rather than under it. Anchored on
    -- refresh, because it sits beside a section whose own position and
    -- width are not known until then.

    -- A pool, not one row per fixed item. The list is the fixed items
    -- PLUS whatever weekly-capped currencies the client reports, which
    -- is not knowable at build time and changes between seasons and
    -- between characters. Spare rows hide.
    ui.week = {}
    for i = 1, WEEKLY_ROWS do
        local row = CreateFrame("Button", nil, page)
        row:SetHeight(WEEKLY_ROW_H)
        -- Positioned on refresh, not here. These go into two columns and
        -- which cell a row lands in depends on how many rows there are,
        -- which depends on what the client reports -- none of it known
        -- at build time.

        -- A box that is either ticked or empty. Not a Blizzard
        -- CheckButton: those bring their own metal frame and label
        -- spacing, and nine of them down a dark page is a different
        -- addon's furniture in the middle of this one.
        --
        -- Two textures, because one was not a box. It was a single flat
        -- square tinted `faint` at 0.12 alpha over a panel that is
        -- already nearly that colour, which is a smudge rather than a
        -- checkbox -- and a checklist whose empty state is invisible is
        -- a list of sentences with a stain down the left. The outer
        -- texture is the border and the inner one, inset a pixel, is
        -- the hole: dark when empty so the border reads as an outline,
        -- tinted when ticked so a done row is obvious from across the
        -- page even before the tick lands on it.
        row.box = row:CreateTexture(nil, "ARTWORK")
        row.box:SetSize(15, 15)
        row.box:SetPoint("LEFT", 4, 0)

        row.boxFill = row:CreateTexture(nil, "ARTWORK", nil, 1)
        row.boxFill:SetPoint("TOPLEFT", row.box, "TOPLEFT", 1, -1)
        row.boxFill:SetPoint("BOTTOMRIGHT", row.box, "BOTTOMRIGHT", -1, 1)

        row.tick = row:CreateTexture(nil, "OVERLAY")
        row.tick:SetSize(16, 16)
        row.tick:SetPoint("CENTER", row.box, "CENTER", 0, 0)
        row._hasTick = W:TrySetAtlas(row.tick, CHECK_ATLAS)
        row.tick:Hide()

        -- Which rows the player has to tick, said on the row instead of
        -- in a tooltip.
        --
        -- Roughly half this list answers itself from the client and
        -- half is the player's word, and nothing on screen said which
        -- was which -- so the honest reading of ten empty boxes was
        -- "ten things I have to remember to click", when it is closer
        -- to five. The tag goes on the manual ones because that is the
        -- shorter, more useful message: this is the set that will sit
        -- there unticked until you say otherwise, and it doubles as the
        -- hint that the row is clickable at all.
        row.manualTag = W:Label(row, "GameFontNormalSmall", "RIGHT")
        row.manualTag:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.manualTag:SetText(W:Tint("faint", "manual"))
        row.manualTag:Hide()

        row.label = W:Label(row, "GameFontNormalSmall")
        row.label:SetPoint("LEFT", row.box, "RIGHT", 9, 0)
        row.label:SetPoint("RIGHT", row.manualTag, "LEFT", -8, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)

        row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnClick", function(self)
            if not (ns.Weekly and self._item) then return end
            ns.Weekly:Toggle(self._item)
            if Shell.RefreshPage then Shell:RefreshPage("home") end
        end)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self._title or "", 1, 1, 1)
            if self._detail then
                GameTooltip:AddLine(self._detail, 0.7, 0.7, 0.72, true)
            end
            -- Said on every row, because a list where some rows are
            -- clickable and some are not is a list you have to poke at
            -- to find out which is which.
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(self._manual
                and "Click to mark this done. Clears at the weekly reset."
                or "Tracked automatically.", 0.5, 0.5, 0.55, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        ui.week[i] = row
    end

    ui.empty = W:Label(host, "GameFontNormal")
    ui.empty:SetPoint("TOPLEFT", ui.planTitle, "BOTTOMLEFT", 4, -14)
    ui.empty:SetTextColor(W:Color("muted"))
    ui.empty:Hide()

    -- is laid out, and a strip sized from zero stays that size.
end

------------------------------------------------------------
-- Data
--
-- Every accessor is defensive in the same way: the Planner owns this and
-- may not have run, and an empty dashboard is a better answer than a
-- broken page. That is a reason to check, not a reason to guess at the
-- signature -- see the header.
------------------------------------------------------------

local function VaultSnapshot()
    local P = ns.Planner
    if not (P and P.GetVaultSnapshot) then return nil end
    local ok, snap = pcall(P.GetVaultSnapshot, P)
    return ok and snap or nil
end

--- The Planner's suggestions, which live one level down.
---
--- BuildPlan returns { vault = ..., items = { ... }, resetDays = ... },
--- not an array. This read `plan[i]`, which is always nil, so the
--- section rendered "Nothing pressing" no matter what the Planner had
--- worked out -- and it works out plenty: how many more dungeons or
--- bosses unlock the next vault slot, which delve tier is next, how many
--- crests are left before the weekly cap.
---
--- Exactly the mistake made with ns:GetVaultProgress earlier in this
--- shell: assuming a function's return shape instead of reading it.
local function Plan()
    local P = ns.Planner
    if not (P and P.BuildPlan) then return nil end
    local ok, plan = pcall(P.BuildPlan, P)
    if not ok or type(plan) ~= "table" then return nil end
    return type(plan.items) == "table" and plan.items or nil
end

local function Refresh(ctx)
    if not ui then return end

    ------------------------------------------------------------
    -- Vault
    ------------------------------------------------------------
    local snap = VaultSnapshot()
    -- Tile geometry depends on the window width, which is not known
    -- until the shell has sized the page.
    -- Minus the scrollbar as well as the padding. The sections size
    -- themselves against this, and a width that ignored the bar would
    -- run every card under it.
    local rowW = (ctx and ctx.width or ui.host:GetWidth() or 0) - PAD * 2 - SCROLLBAR_W
    local tileW = math.floor((rowW - VAULT_LABEL_W - GAP * VAULT_SLOTS) / VAULT_SLOTS)

    for _, def in ipairs(VAULT_ROWS) do
        local row = ui.rows[def.key]
        local track = snap and snap[def.key]
        -- Coerced rather than trusted. This page already died once
        -- because a value that was supposed to be a count arrived as a
        -- table and got compared to a number; the cost of being wrong
        -- about a shape is the whole page going blank, so it is worth a
        -- tonumber. Bad data renders as "--", which is visible and
        -- reportable, rather than as an empty dashboard.
        local filled = tonumber(track and track.filled) or 0
        local total  = tonumber(track and track.total) or 0

        row.label:SetTextColor(W:Color(filled > 0 and "text" or "muted"))
        if total > 0 then
            row.tally:SetText(("%d of %d"):format(filled, total))
        else
            row.tally:SetText("|cff888888--|r")
        end

        local all = type(track) == "table" and type(track.all) == "table"
            and track.all or {}

        for s, tile in ipairs(row.slots) do
            if tileW > 40 then
                tile:ClearAllPoints()
                tile:SetSize(tileW, VAULT_ROW_H)
                tile:SetPoint("TOPLEFT", row, "TOPLEFT",
                    VAULT_LABEL_W + (s - 1) * (tileW + GAP), 0)
            end

            local slot = all[s]
            if type(slot) ~= "table" then
                -- No data for this slot. Drawn rather than hidden: the
                -- vault always has three, and a missing tile reads as a
                -- layout bug where an empty one reads as "not yet".
                tile.caption:SetText("|cff8a8a92slot " .. s .. "|r")
                tile.state:SetText("|cff8a8a92--|r")
                tile.big:SetText("")
                SetSlotMark(tile, false, "Great Vault", nil, nil,
                    { "No data for this slot yet." })
                SetSlotFill(tile, "none", 0)
            else
                local progress  = tonumber(slot.progress) or 0
                local threshold = tonumber(slot.threshold) or 0
                -- Lifted from |cff888888. On a dark brown surface that
                -- grey was reading as barely-there rather than as
                -- secondary, which is most of why the page was hard to
                -- read at a glance.
                tile.caption:SetText(("|cffa8a29a%s %d|r"):format(
                    def.unit or "runs", threshold))
                local pct = threshold > 0 and (progress / threshold) or 0

                local earned = slot.unlocked and true or false
                local unitWord = def.unit or "runs"

                -- The fraction goes bottom right on every card, earned
                -- or not, so the column reads straight down.
                tile.state:SetText(("|cff%s%d|r|cff8a8a92/%d|r"):format(
                    earned and "6ee88a" or "ffffff",
                    earned and threshold or progress, threshold))

                -- The middle of the card: the item level when it is
                -- yours, and nothing when it is not -- the padlock has
                -- that space instead.
                local ilvl = earned and tonumber(slot.rewardIlvl) or nil
                tile.big:SetText(ilvl and tostring(ilvl) or "")

                if earned then
                    SetSlotFill(tile, "unlocked", 1)
                else
                    SetSlotFill(tile, progress > 0 and "progress" or "locked", pct)
                end

                local short = math.max(threshold - progress, 0)
                local notes = {}
                if earned then
                    -- Said plainly, because the card shows an item level
                    -- and people reasonably read that as "this item".
                    notes[#notes + 1] =
                        "The item itself is chosen from a selection when you claim it."
                else
                    notes[#notes + 1] =
                        ("%d more to unlock this slot."):format(short)
                end
                SetSlotMark(tile, earned,
                    ("%s: %d"):format(unitWord, threshold),
                    earned and RewardText(slot, def.key, true) or nil,
                    ("%d/%d"):format(earned and threshold or progress, threshold),
                    notes)
            end
        end
    end

    ------------------------------------------------------------
    -- Tonight
    ------------------------------------------------------------
    local plan = Plan()
    local shown = 0
    for i, card in ipairs(ui.plan) do
        local entry = plan and plan[i]
        if entry then
            local cat = ns.Planner and ns.Planner.CATEGORIES
                and ns.Planner.CATEGORIES[entry.category]
            local a = cat and cat.accent
            if a then
                card.stripe:SetColorTexture(a[1], a[2], a[3], 1)
            else
                card.stripe:SetColorTexture(W:Color("muted"))
            end
            card.title:SetText(entry.title or "")
            card.detail:SetText(entry.detail or "")
            card:Show()
            shown = shown + 1
        else
            card:Hide()
        end
    end

    -- The two sections sit SIDE BY SIDE.
    --
    -- Stacked, they were the taller half of a page that already did not
    -- fit -- and they are not sequential: the plan is what to do next
    -- and the checklist is what is still owed this week, read together
    -- rather than one after the other. Beside each other they take the
    -- height of the taller one instead of the sum, which is most of the
    -- overflow gone without shrinking anything.
    local halfW = math.floor((rowW - GAP) / 2)
    -- The heading too, not just the cards under it. Moving the width
    -- from a build-time RIGHT anchor to a refresh-time SetWidth means
    -- every piece needs one, and a section title left at zero width
    -- draws nothing at all -- no text, no rule.
    ui.planTitle:SetWidth(halfW)
    for i = 1, shown do
        ui.plan[i]:SetWidth(halfW)
    end
    if ui.weekTitle then
        ui.weekTitle:ClearAllPoints()
        ui.weekTitle:SetPoint("TOPLEFT", ui.planTitle, "TOPLEFT", halfW + GAP, 0)
        ui.weekTitle:SetWidth(halfW)
    end

    ui.empty:SetShown(shown == 0)
    if shown == 0 then
        ui.empty:SetText(plan and "Nothing pressing. Go and press something."
            or "|cff888888The planner has not run yet.|r")
    end

    ------------------------------------------------------------
    -- The two facts that used to be a section of their own
    ------------------------------------------------------------
    local keyName, keyLevel
    if C_MythicPlus and C_MythicPlus.GetOwnedKeystoneMapID then
        local mapID = C_MythicPlus.GetOwnedKeystoneMapID()
        if mapID and C_ChallengeMode then
            keyName = C_ChallengeMode.GetMapUIInfo(mapID)
            keyLevel = C_MythicPlus.GetOwnedKeystoneLevel
                and C_MythicPlus.GetOwnedKeystoneLevel()
        end
    end
    ------------------------------------------------------------
    -- Also this week
    ------------------------------------------------------------
    if ui.week and ns.Weekly then
        local rows = ns.Weekly:GetList()

        -- Laid out on refresh into a grid, filling column by column
        -- rather than row by row: a checklist is read DOWN, so the
        -- first half of the list should be the left column, not every
        -- other item.
        -- One column now, not two. The section itself is the right-hand
        -- column of the page, so splitting it again would give four
        -- columns of very short rows.
        local colW = math.floor((rowW - GAP) / 2)
        local perCol = #rows

        for i, row in ipairs(ui.week) do
            local data = rows[i]
            if not data then
                row:Hide()
            else
                if colW > 40 then
                    row:ClearAllPoints()
                    row:SetWidth(colW)
                    row:SetPoint("TOPLEFT", ui.weekTitle, "BOTTOMLEFT",
                        0, -8 - (i - 1) * (WEEKLY_ROW_H + 2))
                end
                row._item, row._title, row._detail, row._manual =
                    data.item, data.label, data.detail, data.manual

                -- Done recedes, outstanding does not. The point of the
                -- list is what is left, so the finished rows have to
                -- stop competing with it -- struck through would be
                -- louder, not quieter.
                row.label:SetText(data.label)
                row.label:SetTextColor(W:Color(data.done and "faint" or "text"))

                -- Border first, then the hole. Empty is an outline over
                -- near-black; done is the same outline in green over a
                -- tint of itself.
                local r, g, b = W:Color(data.done and "good" or "muted")
                row.box:SetColorTexture(r, g, b, data.done and 0.9 or 0.55)
                if data.done then
                    -- Without the atlas the tint IS the tick, so it has
                    -- to carry the state on its own.
                    row.boxFill:SetColorTexture(r, g, b,
                        row._hasTick and 0.22 or 0.75)
                else
                    row.boxFill:SetColorTexture(0, 0, 0, 0.55)
                end
                row.tick:SetShown(data.done and row._hasTick and true or false)

                -- Hidden once it is ticked: at that point the row is
                -- finished and the tag is answering a question nobody
                -- is asking any more.
                row.manualTag:SetShown(data.manual and not data.done)

                -- Only a row the player can actually change lights up
                -- under the cursor.
                row:EnableMouse(true)
                row:SetAlpha(1)
                row:Show()
            end
        end

        -- Published so Tools/loadcheck.py can measure the page against
        -- the room it was given. This page does not scroll, so anything
        -- past the bottom is simply not there -- which is exactly how
        -- the checklist disappeared into the tab strip.
        ui._contentH = (ctx and ctx.height) or 0
        ui._weekRows = math.min(#rows, WEEKLY_ROWS)
        ui._weekPerCol = perCol

        -- How far the page actually runs, summed from the pieces that
        -- were just laid out rather than from a constant that would go
        -- stale. Everything here is chained top to bottom, so the total
        -- is the sections plus the gaps between them.
        local titleH = ui.vaultTitle:GetHeight() or 32
        -- The taller of the two columns, not their sum. They start on
        -- the same line, so the row is as deep as whichever runs longer.
        local bottomH = math.max(shown * (PLAN_ROW_H + 6),
                                 8 + perCol * (WEEKLY_ROW_H + 2))
        local h = PAD
            + titleH + 10 + #VAULT_ROWS * VAULT_ROW_H + (#VAULT_ROWS - 1) * GAP
            + GAP * 2 + titleH + 10 + bottomH
            + PAD
        ui._pageH = h
        ui.scroll:SetContentHeight(h)

        local left, total = ns.Weekly:CountOutstanding()
        ui.weekTitle:SetValue(left > 0
            and W:Tint("muted", ("%d of %d left"):format(left, total))
            or W:Tint("faint", "all done"))
    end

    ui.planTitle:SetValue(keyName
        and ("|cff%s+%d %s|r"):format(W:Hex("text"), keyLevel or 0, keyName)
        or W:Tint("faint", "no keystone"))

    local left = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
        and C_DateAndTime.GetSecondsUntilWeeklyReset()
    if left and left > 0 then
        -- Floored rather than left to %d: whole days and hours is the
        -- intent, and a float reaching %d is an error in newer Lua even
        -- though the client's 5.1 quietly truncates it.
        ui.vaultTitle:SetValue(W:Tint("muted", ("resets in %dd %dh"):format(
            math.floor(left / 86400), math.floor((left % 86400) / 3600))))
    else
        ui.vaultTitle:SetValue("")
    end
end

Shell:RegisterPage({
    id = "home", label = "Dashboard", order = 0,
    accent = { 0.45, 0.85, 1.0 },
    Build = function(host) Build(host) end,
    Refresh = Refresh,
})
