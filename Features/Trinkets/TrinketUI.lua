local _, ns = ...

------------------------------------------------------------
-- Trinkets page.
--
-- Two views over the same bloodmallet data:
--   "My Spec"      — what should I equip, ranked.
--   "Loot Council" — pick a trinket, see which specs actually want it,
--                    so a raid lead can say "only Frost DKs roll on this"
--                    without alt-tabbing.
------------------------------------------------------------

ns.TrinketUI = ns.TrinketUI or {}
local UI = ns.TrinketUI
local T = ns.Trinkets

-- Padding comes from the shell, not from here. Eight pages had picked
-- their own -- 12 in four of them, 14 in three -- so every page sat to a
-- different rhythm from the chrome around it and from each other. One
-- source means a spacing change lands everywhere at once.
local PAD = (ns.Shell and ns.Shell.PAD) or 12
local ROW_H = 22
local TABS = {
    { id = "spec",    label = "My Spec" },
    { id = "council", label = "Loot Council" },
}

local ACCENT = { 0.45, 0.85, 1.0 }

-- Fight style applies to both views, so it is a separate control rather
-- than four tabs: "My Spec / AoE" and "Loot Council / AoE" are the same
-- question asked of two different lists.
local STYLES = {
    { id = "ST",  label = "Single Target" },
    { id = "AOE", label = "AoE" },
}

-- nil ilvl means "each trinket at the best item level it reaches",
-- which is the ranking bloodmallet publishes. A number means "rank
-- these as if everything were this item level", which is a different
-- and often differently-ordered question.
local state = { tab = "spec", selected = nil, style = "ST",
                search = "", showAll = false, ilvl = nil, showOld = false }

------------------------------------------------------------
-- Scaling bars
--
-- One bar per trinket, split at every item level it was simmed at, the
-- way bloodmallet draws it. Length is the gain over an empty trinket
-- slot; each segment is what the next item level added.
--
-- The point is the shape, not the length: a trinket whose segments keep
-- coming is still climbing, and one that stops early has run out of
-- item levels to gain from. That is the whole reason two of them trade
-- places partway up.
------------------------------------------------------------
-- Width follows the panel: the page is resizable and a bar fixed at a
-- few dozen pixels wastes most of a wide window, which is where the
-- shape of the curve is actually readable.
local BAR_MIN, BAR_MAX, BAR_SHARE = 195, 470, 0.44

-- Width of the trailing "344  -3.5%" column. Snug on purpose: the
-- column is left-aligned so the item levels line up, which means its
-- left edge is where the text starts, and every spare unit of width is
-- dead space between the number and the edge of the frame. Sized for
-- the widest it holds -- three digits, a gap, and a signed percentage.
local VALUE_W = 66

-- Loot Council carries no bars, so its trailing column holds more --
-- the expand marker, the item level and the best rank -- and is sized
-- for that rather than for "344  -3.5%".
local COUNCIL_VALUE_W = 124

-- Clear space between the end of a bar and the item level beside it.
-- Without it the longest bar runs straight into the number and the two
-- read as one smeared column.
local BAR_GAP = 14

-- The first segment is everything the trinket is worth at its lowest
-- item level, so it dwarfs the rest and is drawn as ground rather than
-- as a step. The palette after it is indexed by the item level's
-- position in the spec's ladder, so a given item level is the same
-- colour on every row and the columns line up by eye.
local BASE_COLOR = { 0.33, 0.56, 0.83 }
local STEP_COLORS = {
    { 0.55, 0.78, 0.42 }, { 0.91, 0.63, 0.31 }, { 0.62, 0.55, 0.89 },
    { 0.93, 0.45, 0.51 }, { 0.28, 0.68, 0.66 }, { 0.56, 0.86, 0.81 },
    { 0.76, 0.42, 0.81 }, { 0.34, 0.72, 0.55 }, { 0.89, 0.79, 0.37 },
    { 0.86, 0.36, 0.36 },
}

-- A ranked list is a top-N question, but ten was answering a narrower
-- one than the page had room for: both views left the bottom half of
-- the panel empty and still said "+18 more". Twenty fills the region
-- without forcing a scrollbar at the sizes the shell gives this page,
-- and the tail is still one click away.
--
-- Shared by both views deliberately. My Spec and Loot Council are the
-- same question asked from two directions, and a list that changes
-- length when you switch tabs reads as one of them being truncated.
local TOP_N = 20
local MAX_SEARCH_ROWS = 20
local MAX_SUGGEST = 5

-- The ranked rows are laid out for roughly this many units across, and
-- the magnification is whatever makes the frame that wide.
--
-- Applied to the trinket rows alone. The caveat, the spec header and
-- the attribution are prose and read fine at the size everything else
-- in the addon uses; it is the bars, the icons and the numbers beside
-- them that are worth the room. Magnifying the whole page just makes
-- the paragraph at the top shout.
--
-- Taken from the frame and never from the content, so searching,
-- switching spec, stepping an item level or pressing Show all leaves
-- the size exactly where it was. A list that resizes while you read it
-- is worse than a small one.
-- The panel is not one size everywhere: ns:GetAppFrameSize gives it
-- between 700 and 960 units depending on the screen. Scaling the rows
-- by their share of this design width keeps every part of the page --
-- bar, name column, item level, icons -- at the same fraction of the
-- panel whatever that panel measures, which is the same thing the rest
-- of the addon does through ns:GetUIScale.
--
-- Hence a floor below 1: clamping there made the page proportional on
-- a wide screen and slightly oversized on a narrow one, which is
-- exactly the inconsistency this is meant to avoid. The floor is only a
-- guard for a degenerate measurement, since the panel itself never goes
-- narrow enough to reach it.
local DESIGN_W = 700
local MIN_SCALE, MAX_SCALE = 0.85, 1.75

------------------------------------------------------------
-- Search
------------------------------------------------------------
-- Names live in the sim data, so matching needs no item API and works
-- for items this client has never seen.
--
-- Lowercased once and cached on the entry itself. The alternative --
-- string.lower over every trinket on every keystroke -- is essentially
-- the entire cost of having a search box, and it buys nothing: the data
-- is static for the session.
local function lowerName(entry)
    local lc = entry._lc
    if not lc then
        lc = (entry.name or ""):lower()
        entry._lc = lc
    end
    return lc
end

--- Plain-text find, not a pattern match: trinket names contain "(", "-"
--- and "'", any of which would either error or silently mean something
--- else as a Lua pattern.
local function matches(entry, needle)
    if needle == "" then return true end
    return lowerName(entry):find(needle, 1, true) ~= nil
end

--- Whatever the active tab is listing, for search and suggestions.
local function currentEntries()
    if state.tab == "spec" then
        local specKey = T:GetPlayerSpecKey()
        if not specKey then return {} end
        if state.ilvl then
            local at = T:GetAtItemLevel(specKey, state.style, state.ilvl)
            if at then return at end
        end
        return T:GetForSpec(specKey, state.style) or {}
    end
    return T:GetAllTrinkets(state.style, state.showOld) or {}
end

--- The item levels the player's own spec was simmed at, which is what
--- the stepper walks. Different specs and fight styles have different
--- ladders, so this is asked fresh rather than cached on the control.
local function currentSteps()
    if state.tab ~= "spec" then return nil end
    local specKey = T:GetPlayerSpecKey()
    if not specKey then return nil end
    local _, steps = T:GetCurve(specKey, state.style)
    if not steps or #steps == 0 then return nil end
    return steps
end

-- Where the name starts, from the row's left edge: the icon sits at 4
-- and is 18 wide, the rank follows 6 later and is 28 wide, and the name
-- is 4 after that. Kept as one number because the hover region has to
-- agree with those anchors and nothing else depends on them.
local TEXT_X = 60

--- Shrink the tooltip region to the name actually drawn.
---
--- The name column is a fixed width so the bars line up, but the text in
--- it is whatever length it is. Covering the column means a row is
--- "hovered" for hundreds of pixels of blank space, which is what makes
--- the tooltip feel like it follows the mouse everywhere.
local function fitHover(row)
    local w = row.text:GetStringWidth() or 0
    -- A name too long for its column is truncated on screen, so the
    -- region stops where the column does rather than where the full
    -- string would have ended.
    local cap = row.text:GetWidth() or 0
    if cap > 0 and w > cap then w = cap end
    row.hover:SetWidth(TEXT_X + w + 4)
end

--- Start a full-width row's text at the trinket icons' left edge.
---
--- The header and the attribution carry no icon and no rank, so left to
--- the shared row layout their text begins in the name column, indented
--- past a rank and an icon that are not there. Aligned with the icons
--- they read as headings for the list rather than as another entry in
--- it. `rowScale` converts because the icon sits on a magnified row and
--- these do not.
local function alignToIcons(row, rowScale)
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", row, "LEFT", 4 * (rowScale or 1), 0)
end

--- Left-align the trailing column at a fixed edge.
---
--- Right-aligned, every row's item level starts wherever its own text
--- happened to end -- "344 best" and "331 -3.4%" are different lengths,
--- so the numbers sit in a ragged column and cannot be read down. Given
--- a left edge they line up.
---
--- `w` is in the coordinate space of `row`, which for a magnified row is
--- not the same as the page's: the header passes its own width scaled
--- to match, so the column label sits over the column.
local function placeValue(row, w)
    row.value:ClearAllPoints()
    row.value:SetPoint("LEFT", row, "RIGHT", -w, 0)
    row.value:SetWidth(w)
    row.value:SetJustifyH("LEFT")
end

--- Hover without swallowing clicks.
---
--- A child frame with the mouse fully enabled eats the click meant for
--- the row button underneath it, which in the Loot Council view is the
--- click that expands the trinket. Motion is all these overlays need.
local function enableHover(frame)
    if frame.SetMouseMotionEnabled then
        frame:SetMouseMotionEnabled(true)
        if frame.SetMouseClickEnabled then
            frame:SetMouseClickEnabled(false)
        end
    else
        frame:EnableMouse(true)
    end

    -- Not optional, and not only for the EnableMouse path. A frame with
    -- motion enabled is still a hit-test target: the click lands on it
    -- and is dropped unless it is told to pass it on. That is what stopped
    -- Loot Council rows expanding -- the overlay covers the icon and the
    -- name, which is exactly where the click goes.
    if frame.SetPropagateMouseClicks then
        frame:SetPropagateMouseClicks(true)
    end
end

--- Left-click keeps whatever the row already did; right-click raises the
--- shared item menu.
---
--- A menu rather than the plain favourite toggle this used to be: there
--- are two things worth doing to a trinket and they are not the same
--- one. Favouriting says "I am hunting this" and several can be true at
--- once; pinning says "this goes in that slot" and only one can. The
--- menu offers both without either standing in for the other.
---
--- RegisterForClicks is explicit because a Button listens for left only
--- by default, so without it the right-click never arrives.
local function bindClicks(row, onLeft)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if ns.ShowItemMenu and row._itemID then
                ns:ShowItemMenu(row, row._itemID, {
                    title = row.itemName,
                    onChange = function() UI:Refresh() end,
                })
            end
        elseif onLeft then
            onLeft()
        end
    end)
end

------------------------------------------------------------
-- Row pool
------------------------------------------------------------
local function AcquireRow(self, parent)
    self._rows = self._rows or {}
    self._rowIdx = (self._rowIdx or 0) + 1
    local row = self._rows[self._rowIdx]
    if not row then
        row = CreateFrame("Button", nil, parent, "BackdropTemplate")
        row:SetHeight(ROW_H)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 4, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.rank:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.rank:SetWidth(28)
        row.rank:SetJustifyH("LEFT")
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.text:SetPoint("LEFT", row.rank, "RIGHT", 4, 0)
        row.text:SetJustifyH("LEFT")
        -- One line, cut with an ellipsis when it will not fit. Wrapping
        -- is the default and is worse here: the row is a fixed height,
        -- so a name long enough to need a second line loses it to the
        -- clip instead, and "Thalassian Competitor's Insignia of" simply
        -- stops mid-phrase with no sign it was cut. The full name is a
        -- hover away regardless.
        row.text:SetWordWrap(false)
        row.value = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.value:SetPoint("RIGHT", -8, 0)
        row.value:SetJustifyH("RIGHT")
        -- Segments live on their own frame so the row's highlight does
        -- not sit on top of them, and so hiding the whole bar is one
        -- call rather than a loop over however many steps.
        row.bar = CreateFrame("Frame", nil, row)
        row.bar:SetSize(BAR_MIN, 10)
        row.bar:SetPoint("RIGHT", row, "RIGHT", -(VALUE_W + BAR_GAP), 0)
        row.bar:Hide()
        row.segs = {}

        -- The item tooltip belongs to the icon and the name, not to the
        -- whole row. Hung off the row, the row's own width put it under
        -- the bar as well, so crossing a bar raised the item tooltip
        -- over the segment tooltip and buried the thing being pointed
        -- at. A FontString cannot take scripts, hence a frame tracking
        -- the text's own edge.
        row.hover = CreateFrame("Frame", nil, row)
        row.hover:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.hover:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        -- Width comes from FitHover once the name is in, not from an
        -- anchor to the fontstring: the name column is a fixed width and
        -- on a wide window that is several hundred pixels of empty space
        -- after a short name, all of it raising the item tooltip.
        row.hover:SetWidth(1)
        enableHover(row.hover)
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
    row:SetScript("OnClick", nil)
    row.hover:SetScript("OnEnter", nil)
    row.hover:SetScript("OnLeave", nil)
    row.hover:SetWidth(1)
    -- Back to page size and to a right-aligned trailing column. Only the
    -- ranked trinket rows opt out of both, and this pool is shared with
    -- the council view, the notes and the header.
    row:SetScale(1)
    row.value:ClearAllPoints()
    row.value:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.value:SetJustifyH("RIGHT")
    -- alignToIcons moves this, and the pool would carry that over to
    -- the next row to reuse the frame.
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", row.rank, "RIGHT", 4, 0)
    row.value:SetText("")
    row.rank:SetText("")
    -- Cleared with the rest of the per-item state: the click handler
    -- reads it when the click happens, and a pooled row that kept the
    -- last trinket's id would shortlist the wrong item.
    row._itemID = nil
    -- Cleared here rather than by each caller that has no icon. Rows
    -- come from a pool, so a footer reusing a trinket's frame inherited
    -- its icon, and once the header and the attribution moved left to
    -- line up with the icon column the leftover sat directly under
    -- their text. applyItem sets it again for the rows that have one.
    row.icon:SetTexture(nil)
    -- The pool is shared with the council view and the plain rows, so
    -- everything the bar layout changes has to go back as it was.
    row.bar:Hide()
    row.text:SetWidth(0)
    row.value:SetWidth(0)
    row:Show()
    return row
end

--- Fill a row's bar from one trinket's curve.
---
--- `scale` is the largest total gain in the list, so bars are
--- proportional to each other rather than each normalised to itself --
--- self-normalised bars would draw the worst trinket as full width and
--- say the opposite of what is true.
--- `cap` truncates the bar at a chosen item level, so the picked level
--- shows what the trinket is worth there rather than what it will
--- eventually be worth.
local function drawCurve(row, points, steps, scale, source, cap, barW)
    if not points or not steps or not scale or scale <= 0 then return end
    barW = barW or BAR_MIN

    local have = {}
    for i, ilvl in ipairs(steps) do
        if points[ilvl] and (not cap or ilvl <= cap) then
            have[#have + 1] = { ilvl = ilvl, gain = points[ilvl], idx = i }
        end
    end
    if #have == 0 then return end

    row.bar:SetWidth(barW)
    row.bar:Show()
    local x, prev, used = 0, 0, 0
    for n, point in ipairs(have) do
        local seg = row.segs[n]
        if not seg then
            seg = CreateFrame("Frame", nil, row.bar)
            seg:SetPoint("TOP", row.bar, "TOP", 0, 0)
            seg:SetHeight(10)
            seg.tex = seg:CreateTexture(nil, "ARTWORK")
            seg.tex:SetAllPoints()
            -- A plain Frame receives no mouse events, so without this
            -- the segment tooltips silently never fire and the bar is
            -- decoration.
            enableHover(seg)
            row.segs[n] = seg
        end

        local w = (point.gain - prev) / scale * barW
        -- A step worth almost nothing still gets a sliver: dropping it
        -- would silently merge two item levels into one segment and the
        -- hover would then report the wrong level. Steps that come out
        -- negative land here too -- see the running maximum below.
        if w < 1 then w = 1 end
        seg:ClearAllPoints()
        seg:SetPoint("TOPLEFT", row.bar, "TOPLEFT", x, 0)
        seg:SetWidth(w)
        local c = (n == 1) and BASE_COLOR
            or STEP_COLORS[(point.idx - 1) % #STEP_COLORS + 1]
        seg.tex:SetColorTexture(c[1], c[2], c[3], 0.95)

        local ilvl, gain, step = point.ilvl, point.gain, point.gain - prev
        seg:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(row.itemName or "")
            GameTooltip:AddLine(("Item level %d"):format(ilvl), 1, 1, 1)
            GameTooltip:AddLine(("%+.2f%% over an empty slot"):format(gain),
                0.7, 0.9, 0.7)
            if n > 1 then
                GameTooltip:AddLine(("%+.2f%% from the previous step"):format(step),
                    0.6, 0.6, 0.66)
            end
            if source then
                GameTooltip:AddLine(source, 0.6, 0.6, 0.66)
            end
            GameTooltip:Show()
        end)
        seg:SetScript("OnLeave", function() GameTooltip:Hide() end)
        seg:Show()

        x = x + w
        -- A running maximum, not the step's own value. Sim noise makes
        -- some steps come out below the one before them -- 23 of them
        -- in the current data -- and assigning the lower number here
        -- would hand the drop back to the next segment, which then
        -- draws wider than the item level actually gained. Bars are
        -- meant to be proportional to each other, so a trinket with a
        -- few noisy steps would read as the strongest on the page.
        if point.gain > prev then prev = point.gain end
        used = n
    end

    for n = used + 1, #row.segs do row.segs[n]:Hide() end
end

-- Wrapped multi-line text. AcquireRow is a fixed 22px single line, and
-- the caveat needs to breathe: clipping it to one row would truncate a
-- warning into a confident-looking fragment, which is the exact failure
-- the caveat exists to prevent.
--
-- Returns the fontstring so the caller can measure it — the height
-- depends on how the text wraps at the current panel width.
local function AcquireNote(self, parent, width, text)
    self._notes = self._notes or {}
    self._noteIdx = (self._noteIdx or 0) + 1
    local fs = self._notes[self._noteIdx]
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        self._notes[self._noteIdx] = fs
    end
    fs:SetParent(parent)
    fs:ClearAllPoints()
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetTextColor(0.60, 0.60, 0.66)
    fs:SetText(text)
    fs:Show()
    return fs
end

local function ReleaseRows(self)
    for i = 1, (self._rowIdx or 0) do
        if self._rows[i] then self._rows[i]:Hide() end
    end
    self._rowIdx = 0
    for i = 1, (self._noteIdx or 0) do
        if self._notes and self._notes[i] then self._notes[i]:Hide() end
    end
    self._noteIdx = 0
end

------------------------------------------------------------
-- Item icon/name resolution (async-safe)
------------------------------------------------------------
--- `ilvl` is the level the list ranks this trinket at. The tooltip the
--- client builds from an item ID is the item's base level -- "Item
--- Level 28" for a trinket the page just ranked at 334 -- so the number
--- gets rewritten in place and the upgrade rank named, exactly as the
--- Best in Slot page does. Two numbers disagreeing on the same screen
--- is worse than either being absent.
local function applyItem(row, itemID, fallbackName, ilvl)
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
    row.icon:SetTexture(icon or 134400)

    -- The journal's link, not the bare item ID. An item ID on its own
    -- resolves to the base entry -- a real item nobody has ever seen
    -- drop, Rare quality with single-digit stats -- so the row rendered
    -- blue and the tooltip showed +7 Intellect under a rank of Myth 6/6.
    -- The journal's link carries the bonus IDs that make it render as
    -- what actually drops. Same source the Best in Slot page uses.
    local link
    if ns.GetJournalItemLink then
        local ok, found = pcall(ns.GetJournalItemLink, ns, itemID)
        if ok then link = found end
    end

    local name, quality
    if C_Item and C_Item.GetItemInfo then
        -- Asked of the link when there is one, so the colour comes from
        -- the version being ranked rather than the base entry.
        name, _, quality = C_Item.GetItemInfo(link or itemID)
    end
    local label = name or fallbackName or ("item:" .. tostring(itemID))

    -- bloodmallet sims some trinkets once per stat variant and names
    -- them "Drum of Renewed Bonds [Haste]", "... [Crit]" and so on.
    -- They share one item ID, so the client's own name collapses three
    -- separately-ranked rows into three identical-looking ones. Put the
    -- suffix back: it is the only thing telling them apart.
    -- Plain find, so the needle is a bracket rather than a pattern: with
    -- the fourth argument true the "%" is not an escape, it is half of a
    -- two-character string that never appears in an item name, and the
    -- guard silently never fired.
    local variant = fallbackName and fallbackName:match("(%[[^%]]+%])%s*$")
    if name and variant and not name:find("[", 1, true) then
        label = label .. " " .. variant
    end

    -- Kept uncoloured for the bar segments to title their tooltip with;
    -- an escape sequence in a tooltip line renders as literal text.
    row.itemName = label
    row._itemID = itemID

    if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
        label = ITEM_QUALITY_COLORS[quality].hex .. label .. "|r"
    end

    -- Prepended after the quality colour, not before: the colour wraps
    -- the name in its own escape and would swallow a star put inside it.
    -- A marker rather than a column, so a shortlisted trinket reads at a
    -- glance without costing the name any width.
    if ns.IsLootFavorite and ns.GetPlayerSpecID then
        local specID = ns:GetPlayerSpecID()
        if specID and ns:IsLootFavorite(itemID, specID) then
            label = "|cffffd100*|r " .. label
        end
    end
    row.text:SetText(label)

    row.hover:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        -- The link's own tooltip carries the upgrade line, so the rank
        -- gets rewritten where it belongs instead of appended at the
        -- bottom. Falls back to the bare item if the journal has not
        -- indexed yet -- it builds lazily and can miss the first ask.
        local shown = false
        if link then
            shown = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
        end
        if not shown then GameTooltip:SetItemByID(itemID) end

        if ilvl and ns.RewriteTooltipIlvl then
            local rank = ns.DescribeIlvlRank and ns:DescribeIlvlRank(ilvl)
            local _, didRank = ns.RewriteTooltipIlvl(GameTooltip, ilvl, rank)
            -- A trinket with no upgrade track of its own has no rank
            -- line to rewrite, so add one rather than leaving the
            -- rewritten item level unexplained.
            if rank and not didRank then
                GameTooltip:AddLine("Upgrade Level: " .. rank, 0.55, 0.78, 1)
            elseif not rank then
                -- Raid trinkets sim above the top of the Myth track --
                -- 344 against a ceiling of 334 -- so there is no rank to
                -- name and DescribeIlvlRank rightly says nothing. Place
                -- it relative to the track instead of leaving a
                -- rewritten item level with nothing to read it against.
                local order = ns.TRACK_ORDER
                local top = order and order[#order]
                local levels = top and ns.GEAR_TRACKS and ns.GEAR_TRACKS[top]
                local ceiling = levels and levels[#levels]
                if ceiling and ilvl > ceiling then
                    GameTooltip:AddLine(
                        ("Upgrade Level: above %s %d/%d"):format(
                            top, #levels, #levels), 0.55, 0.78, 1)
                end
            end
        end

        GameTooltip:Show()
    end)
    row.hover:SetScript("OnLeave", function() GameTooltip:Hide() end)

    if not name and C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
end

------------------------------------------------------------
-- Views
------------------------------------------------------------
local function relColor(rel)
    if rel >= -0.5 then return "|cff40ff40" end
    if rel >= -2.0 then return "|cffd0ff40" end
    if rel >= -5.0 then return "|cffffcc00" end
    return "|cffff8080"
end

function UI:RenderMySpec(content, width, viewH, rowScale)
    local y = -6
    rowScale = rowScale or 1
    local specKey = T:GetPlayerSpecKey()

    if not specKey then
        local fs = AcquireRow(self, content)
        fs:SetPoint("TOPLEFT", PAD, y)
        fs:SetWidth(width - PAD * 2)
        fs.text:SetText(ns.Widgets:Tint("muted", "Could not determine your specialization."))
        return y - ROW_H
    end

    local list, _, stamp, tier = T:GetForSpec(specKey, state.style)
    local curve, steps, source = T:GetCurve(specKey, state.style)

    -- Asking for a specific item level replaces the list with the one
    -- that holds there, which is shorter: only trinkets simmed at that
    -- exact level can be in it.
    local atLevel
    if list and state.ilvl then
        atLevel = T:GetAtItemLevel(specKey, state.style, state.ilvl)
        list = atLevel or list
    end

    if not list then
        local fs = AcquireRow(self, content)
        fs:SetPoint("TOPLEFT", PAD, y)
        fs:SetWidth(width - PAD * 2)
        -- Distinguish "not simmed at all" from "simmed, but not for this
        -- fight style" -- a few specs have single target only, and saying
        -- "no sims for you" there reads as a data failure.
        local otherStyle = (state.style == "ST") and "AOE" or "ST"
        if T:GetForSpec(specKey, otherStyle) then
            fs.text:SetText(("|cff%sbloodmallet has no %s sims for %s -- try the other tab.|r"):format(ns.Widgets:Hex("muted"), state.style == "ST" and "single-target" or "AoE", T:SpecName(specKey)))
        else
            fs.text:SetText(("|cff%sbloodmallet has no trinket sims for %s this tier.|r"):format(ns.Widgets:Hex("muted"), T:SpecName(specKey)))
        end
        return y - ROW_H
    end

    -- Above the list, not below it. A spec's ranking runs to 25 rows --
    -- roughly 550px against a 500px panel -- so a caveat placed after it
    -- sits permanently below the scroll fold, where it qualifies nothing
    -- because nobody reads it. It frames the numbers, so it goes first.
    local caveat = ns.GEAR_CAVEAT and ns.GEAR_CAVEAT.trinket
    if caveat then
        local note = AcquireNote(self, content, width - PAD * 2, caveat)
        note:SetPoint("TOPLEFT", PAD, y - 2)
        y = y - (note:GetStringHeight() or 30) - 10
    end

    -- Per spec, not per page. bloodmallet re-sims a tier a few specs at a
    -- time, so for the first weeks of a season one character's list is
    -- current and the next one's is not. The warning belongs on the list
    -- it applies to; the page-level banner only fires when nothing at all
    -- has been re-simmed yet.
    local warning
    if T:IsStaleTier(tier) and not T:IsStale() then
        warning = T:StaleSpecText(tier)
    end

    -- Without a curve there are no bars and no stepper, and dropping a
    -- whole feature with no explanation reads as a broken page rather
    -- than as missing data. Folded into the staleness line instead of
    -- stacking a third paragraph over the list: for every spec this
    -- currently affects, the reason is the same re-sim.
    if not curve or next(curve) == nil then
        local why = "There are no scaling bars or item level stepper for it either -- that detail arrives with the re-sim."
        warning = warning and (warning .. " " .. why)
            or (ns.Widgets:Tint("muted", "No item-level detail for this spec, so no scaling bars or item level stepper. bloodmallet publishes it with the next run."))
    end

    if warning then
        local note = AcquireNote(self, content, width - PAD * 2, warning)
        note:SetPoint("TOPLEFT", PAD, y - 2)
        y = y - (note:GetStringHeight() or 20) - 10
    end

    -- Asked for an item level nothing here was simmed at. Say which ones
    -- exist rather than showing the "best available" list under a header
    -- claiming to be that level.
    if state.ilvl and not atLevel then
        local note = AcquireNote(self, content, width - PAD * 2,
            ("|cffffcc00Nothing was simmed at item level %d.|r Trinkets are only simmed at the levels they can drop at, and no trinket in this list reaches that one. Step to a neighbouring level."):format(state.ilvl))
        note:SetPoint("TOPLEFT", PAD, y - 2)
        y = y - (note:GetStringHeight() or 30) - 10
    end

    local hdr = AcquireRow(self, content)
    hdr:SetPoint("TOPLEFT", PAD, y)
    hdr:SetWidth(width - PAD * 2)
    hdr.icon:SetTexture(nil)
    alignToIcons(hdr, rowScale)
    if atLevel then
        -- "of N with item-level detail", not "of the whole list": only
        -- the top rows keep a curve, so counting against all 25 would
        -- report trinkets as missing from this level when the truth is
        -- they were never eligible for the question.
        local detailed = 0
        for _ in pairs(curve) do detailed = detailed + 1 end
        hdr.text:SetText(("%s  |cff666666all at item level %d -- %d of the %d with item-level detail reach it|r")
            :format(T:ColorSpec(specKey), state.ilvl, #atLevel, detailed))
    else
        -- Not "at item level N". bloodmallet sims each trinket up to its
        -- own ceiling -- a crafted one stops lower than a raid drop -- so
        -- a single number in the header would be wrong for most of the
        -- rows beneath it. The ceiling that applies is on each row.
        hdr.text:SetText(("%s  |cff666666each at its highest simmed item level|r")
            :format(T:ColorSpec(specKey)))
    end
    -- The label belongs over the column, and the column lives on rows
    -- that are magnified while this header is not, so its width has to
    -- be taken up into page units to land in the same place.
    placeValue(hdr, VALUE_W * rowScale)
    hdr.value:SetText(ns.Widgets:Tint("faint", "ilvl / vs best"))
    y = y - ROW_H - 4

    -- Bars are drawn against the strongest total in the list, so they
    -- are proportional to one another. In item-level mode that is the
    -- best gain at that level; otherwise the best any trinket reaches.
    local scale
    if curve then
        if atLevel then
            scale = atLevel[1] and atLevel[1].gain
        else
            for _, row in ipairs(list) do
                local points = curve[row.id]
                local top = points and row.ilvl and points[row.ilvl]
                if top and (not scale or top > scale) then scale = top end
            end
        end
    end

    -- Everything from here down is in the magnified rows' own units, so
    -- the page width has to come down into them first.
    local rowW = (width - PAD * 2) / rowScale
    local barW = math.floor(rowW * BAR_SHARE)
    if barW < BAR_MIN then barW = BAR_MIN end
    if barW > BAR_MAX then barW = BAR_MAX end

    -- The name takes whatever the bar and the value column leave. A spec
    -- with no curve draws no bar, so its names get that room back rather
    -- than being cut short to clear space for something absent.
    local nameW = rowW - TEXT_X - VALUE_W - 8
    if scale then nameW = nameW - barW - BAR_GAP - 8 end

    -- Long-hand on purpose. `state.showAll and #list or TOP_N` reads
    -- fine and is wrong the moment #list is 0, because 0 is truthy in
    -- Lua and the fallback never fires.
    local needle = state.search
    local limit
    if needle ~= "" then
        limit = MAX_SEARCH_ROWS
    elseif state.showAll then
        limit = #list
    else
        limit = TOP_N
    end

    -- rank comes from the position in the FULL list, not from the loop
    -- counter. Filtering must not renumber things: a trinket that is
    -- 14th stays 14th when you search for it, or the number is a lie.
    local shown, hidden = 0, 0
    for rank, row in ipairs(list) do
        if matches(row, needle) then
            if shown < limit then
                local r = AcquireRow(self, content)
                -- Offsets divide by the scale for the same reason the
                -- width does: a magnified frame's anchor offsets are
                -- read in its own units, so an undivided PAD would
                -- indent this row further than the header above it.
                r:SetScale(rowScale)
                r:SetPoint("TOPLEFT", PAD / rowScale, y / rowScale)
                r:SetWidth(rowW)
                placeValue(r, VALUE_W)
                r.rank:SetText("|cff" .. ns.Widgets:Hex("muted") .. rank .. ".|r")
                -- My Spec rows have nothing to do on a left-click, so
                -- this is the right-click alone.
                bindClicks(r, nil)
                applyItem(r, row.id, row.name, row.ilvl)
                -- Always, not only when there are bars: the width is
                -- what gives the ellipsis something to cut against, and
                -- without it a long name runs under the value column.
                r.text:SetWidth(nameW)
                if scale then
                    drawCurve(r, curve[row.id], steps, scale,
                        source and source[row.id], state.ilvl, barW)
                end
                -- After the column width, or the clamp reads the old one.
                fitHover(r)
                -- The item level qualifies the percentage next to it: two
                -- rows a hair apart can be a fair fight or a 13-ilvl head
                -- start, and only this says which. In item-level mode
                -- every row is at the same level, so the header says it
                -- once instead of repeating it 25 times.
                local at = (not atLevel) and row.ilvl
                    and ("|cff%s%d|r  "):format(ns.Widgets:Hex("faint"), row.ilvl) or ""
                if rank == 1 then
                    r.value:SetText(at .. "|cff40ff40best|r")
                else
                    r.value:SetText(("%s%s%.1f%%|r"):format(at, relColor(row.rel), row.rel))
                end
                y = y - ROW_H * rowScale
                shown = shown + 1
            else
                hidden = hidden + 1
            end
        end
    end

    if shown == 0 then
        local fs = AcquireRow(self, content)
        fs:SetPoint("TOPLEFT", PAD, y)
        fs:SetWidth(width - PAD * 2)
        fs.text:SetText(ns.Widgets:Tint("muted", "No trinket matches that name."))
        y = y - ROW_H
    elseif hidden > 0 then
        local more = AcquireRow(self, content)
        more:SetPoint("TOPLEFT", PAD, y)
        more:SetWidth(width - PAD * 2)
        more.icon:SetTexture(nil)
        if needle ~= "" then
            more.text:SetText(("|cff%s%d more match — refine the search.|r"):format(ns.Widgets:Hex("muted"), hidden))
        else
            more.text:SetText(("|cff%s+%d more|r  |cffaaaaaaShow all|r"):format(ns.Widgets:Hex("muted"), hidden))
            more:SetScript("OnClick", function()
                state.showAll = true
                UI:Refresh()
            end)
        end
        y = y - ROW_H
    elseif state.showAll and needle == "" then
        local less = AcquireRow(self, content)
        less:SetPoint("TOPLEFT", PAD, y)
        less:SetWidth(width - PAD * 2)
        less.icon:SetTexture(nil)
        less.text:SetText(("|cff%sShow top %d only|r"):format(ns.Widgets:Hex("muted"), TOP_N))
        less:SetScript("OnClick", function()
            state.showAll = false
            UI:Refresh()
        end)
        y = y - ROW_H
    end

    if stamp and stamp ~= "" then
        -- Sits at the foot of the frame, not immediately under the last
        -- row: an attribution floating mid-panel with empty space below
        -- it reads as the page having failed to finish drawing.
        --
        -- y still advances by a normal row either way. It is what Draw
        -- measures to decide how far to magnify the page, and if pinning
        -- also reported the content as reaching the bottom, the content
        -- would always look full and never scale up at all.
        local fy = y - 6
        local bottom = viewH and viewH > 0 and -(viewH - ROW_H - 6)
        if bottom and fy > bottom then fy = bottom end

        local fs = AcquireRow(self, content)
        fs:SetPoint("TOPLEFT", PAD, fy)
        fs:SetWidth(width - PAD * 2)
        alignToIcons(fs, rowScale)
        fs.text:SetText("|cff666666Simmed " .. stamp .. " — bloodmallet.com|r")
        y = y - ROW_H - 6
    end

    return y
end

function UI:RenderCouncil(content, width, viewH)
    local y = -6
    local all = T:GetAllTrinkets(state.style, state.showOld)

    -- Above the list, not below it. A spec's ranking runs to 25 rows --
    -- roughly 550px against a 500px panel -- so a caveat placed after it
    -- sits permanently below the scroll fold, where it qualifies nothing
    -- because nobody reads it. It frames the numbers, so it goes first.
    local caveat = ns.GEAR_CAVEAT and ns.GEAR_CAVEAT.trinket
    if caveat then
        local note = AcquireNote(self, content, width - PAD * 2, caveat)
        note:SetPoint("TOPLEFT", PAD, y - 2)
        y = y - (note:GetStringHeight() or 30) - 10
    end


    if not all or #all == 0 then
        local fs = AcquireRow(self, content)
        fs:SetPoint("TOPLEFT", PAD, y)
        fs:SetWidth(width - PAD * 2)
        fs.text:SetText(ns.Widgets:Tint("muted", "No trinket data loaded."))
        return y - ROW_H
    end

    local intro = AcquireRow(self, content)
    intro:SetPoint("TOPLEFT", PAD, y)
    intro:SetWidth(width - PAD * 2)
    intro.icon:SetTexture(nil)
    intro.text:SetText(ns.Widgets:Tint("muted", "Click a trinket to expand it, click again to collapse."))
    placeValue(intro, COUNCIL_VALUE_W)
    intro.value:SetText(ns.Widgets:Tint("faint", "ilvl / best rank"))
    y = y - ROW_H - 2

    -- Read state.selected when the click happens, not when the row is
    -- built. Rows come from a pool and are rebuilt on every refresh, so a
    -- captured flag is one render out of date the moment anything else
    -- changes the selection.
    -- Written long-hand on purpose. The obvious `cond and nil or id` is
    -- broken in Lua: nil is falsy, so the `and` branch falls straight
    -- through to the `or` and the expression can never yield nil. That is
    -- why this row expanded but would not collapse.
    local function toggle(id)
        if state.selected == id then
            state.selected = nil
        else
            state.selected = id
        end
        UI:Refresh()
    end

    local needle = state.search
    local limit
    if needle ~= "" then
        limit = MAX_SEARCH_ROWS
    elseif state.showAll then
        limit = #all
    else
        limit = TOP_N
    end
    local shown, hidden = 0, 0

    for _, bucket in ipairs(all) do
      if matches(bucket, needle) then
       if shown >= limit then
        hidden = hidden + 1
       else
        shown = shown + 1
        local r = AcquireRow(self, content)
        r:SetPoint("TOPLEFT", PAD, y)
        r:SetWidth(width - PAD * 2)
        applyItem(r, bucket.id, bucket.name, bucket.ilvl)
        -- Marked while the checkbox is on. Unmarked they are
        -- indistinguishable from this season's drops, which is the
        -- confusion the checkbox exists to resolve rather than move.
        if state.showOld and not bucket.thisTier then
            r.text:SetText(r.text:GetText() .. "  |cff886600(older)|r")
        end
        fitHover(r)

        local isOpen = (state.selected == bucket.id)
        -- The item level every spec below ranks it at -- its own
        -- ceiling, the top of the Myth track for wherever it drops.
        -- Fixed, not adjustable: this view answers "who should roll on
        -- this", and a ranking that reorders under a loot council mid
        -- discussion is answering a different question badly.
        --
        -- Left-aligned at a fixed width for the same reason My Spec is:
        -- the numbers are only comparable if they are in a column.
        placeValue(r, COUNCIL_VALUE_W)
        -- bestRank, not specs[1]: the first entry can be a spec running
        -- on last season's data, and its placing was made against last
        -- season's set of trinkets.
        if bucket.bestRank and bucket.bestRank < 99 then
            r.value:SetText(("%s |cff666666%s|r  |cff888888best: #%d|r")
                :format(isOpen and ns.Widgets:Tint("muted", "-") or ns.Widgets:Tint("muted", "+"),
                        bucket.ilvl or "?", bucket.bestRank))
        end
        bindClicks(r, function() toggle(bucket.id) end)
        y = y - ROW_H

        if isOpen then
            -- Two groups, because they answer different questions. The
            -- ranked ones are "who wants this". Underneath them go the
            -- specs bloodmallet has not re-simmed at all, whose absence
            -- from the ranking is not evidence they do not want it --
            -- read as one list, a missing spec looks like a spec that
            -- passed on the item.
            --
            -- The second group is every spec awaiting a re-sim, not
            -- just the ones that ranked this trinket last season. This
            -- season's trinkets were never in last season's lists, so
            -- the per-trinket version comes out empty for exactly the
            -- items where the caveat is worth making.
            local pending = T:PendingSpecs(state.style)
            for _, entry in ipairs(bucket.specs) do
                if not T:IsStaleTier(entry.tier) then
                    local sr = AcquireRow(self, content)
                    sr:SetPoint("TOPLEFT", PAD + 26, y)
                    sr:SetWidth(width - PAD * 2 - 26)
                    sr.icon:SetTexture(nil)
                    sr.rank:SetText("|cff888888#" .. entry.rank .. "|r")
                    sr.text:SetText(T:ColorSpec(entry.key))
                    -- Collapse from the spec rows as well: with a long
                    -- list expanded, the header you opened it from can be
                    -- scrolled off, and clicking the block you are
                    -- looking at is the obvious way to close it.
                    sr:SetScript("OnClick", function() toggle(bucket.id) end)
                    if entry.rank == 1 then
                        sr.value:SetText("|cff40ff40top pick|r")
                    else
                        sr.value:SetText(("%s%.1f%%|r")
                            :format(relColor(entry.rel), entry.rel))
                    end
                    y = y - ROW_H
                end
            end

            if #pending > 0 then
                local hr = AcquireRow(self, content)
                hr:SetPoint("TOPLEFT", PAD + 26, y)
                hr:SetWidth(width - PAD * 2 - 26)
                hr.icon:SetTexture(nil)
                hr.text:SetText("|cff886600Not simmed for this season yet|r")
                y = y - ROW_H + 2

                -- Named as a group rather than a row each: the point is
                -- that nothing is known about them, and a rank apiece
                -- would dress last season's numbers up as this season's.
                local names = {}
                for _, key in ipairs(pending) do
                    names[#names + 1] = T:ColorSpec(key)
                end
                local note = AcquireNote(self, content,
                    width - PAD * 2 - 26 - TEXT_X, table.concat(names, ", "))
                note:SetPoint("TOPLEFT", PAD + 26 + TEXT_X, y)
                y = y - (note:GetStringHeight() or ROW_H) - 6
            end
            y = y - 4
        end
       end
      end
    end

    if shown == 0 then
        local fs = AcquireRow(self, content)
        fs:SetPoint("TOPLEFT", PAD, y)
        fs:SetWidth(width - PAD * 2)
        fs.text:SetText(ns.Widgets:Tint("muted", "No trinket matches that name."))
        y = y - ROW_H
    elseif hidden > 0 then
        local more = AcquireRow(self, content)
        more:SetPoint("TOPLEFT", PAD, y)
        more:SetWidth(width - PAD * 2)
        more.icon:SetTexture(nil)
        if needle ~= "" then
            more.text:SetText(("|cff%s%d more match — refine the search.|r"):format(ns.Widgets:Hex("muted"), hidden))
        else
            more.text:SetText(("|cff%s+%d more|r  |cffaaaaaaShow all|r"):format(ns.Widgets:Hex("muted"), hidden))
            more:SetScript("OnClick", function()
                state.showAll = true
                UI:Refresh()
            end)
        end
        y = y - ROW_H
    end

    return y
end

------------------------------------------------------------
-- Build
------------------------------------------------------------
--- Keep the stepper honest about the list under it. Hidden entirely
--- where it would do nothing: the council view is not one spec, and a
--- spec with no curve has no ladder to walk.
function UI:RefreshStepper()
    local bar = self._ilvlBar
    if not bar then return end

    -- The checkbox belongs to Loot Council and shares the stepper's
    -- slot, so it comes and goes with the tab.
    if self._oldBox then
        self._oldBox:SetShown(state.tab == "council")
        self._oldBox:SetChecked(state.showOld)
    end

    local steps = currentSteps()
    if not steps then
        -- Stale selection from a spec or style that did have a ladder.
        state.ilvl = nil
        bar:Hide()
        return
    end
    bar:Show()

    if state.ilvl then
        self._ilvlLabel:SetText(("|cffffffffItem level %d|r"):format(state.ilvl))
    else
        self._ilvlLabel:SetText(ns.Widgets:Tint("muted", "Best available"))
    end

    local i = 0
    for n, v in ipairs(steps) do
        if v == state.ilvl then
            i = n
            break
        end
    end
    if i <= 0 then self._ilvlPrev:Disable() else self._ilvlPrev:Enable() end
    if i >= #steps then self._ilvlNext:Disable() else self._ilvlNext:Enable() end
end

--- Lay the page out at one magnification.
---
--- Everything below works in logical units and is unaware of the scale;
--- the frame does the magnifying. That is the whole reason this is a
--- scale rather than bigger fonts and taller rows -- the bars, the item
--- icons, the header text and the spacing all grow by the same factor,
--- and no layout code has to know about it.
function UI:Draw(rowScale)
    ReleaseRows(self)

    local content, scroll = self._content, self._scroll
    -- The page itself is never magnified, only the ranked rows on it.
    content:SetScale(1)

    local width = scroll and scroll:GetWidth() or 0
    if width < 50 then width = 600 end
    content:SetWidth(width)
    local viewH = scroll and scroll:GetHeight() or 0

    local endY
    if state.tab == "spec" then
        endY = self:RenderMySpec(content, width, viewH, rowScale)
    else
        -- Loot Council is a lookup, not a chart. It carries no bars, and
        -- twenty-odd trinkets with their specs expanded underneath need
        -- the rows they have rather than bigger ones.
        endY = self:RenderCouncil(content, width, viewH)
    end

    -- Breathing room under a list that scrolls, but none for one that
    -- fits: the page is magnified to land exactly on the bottom edge,
    -- and padding added on top of that is a scrollbar for twelve units
    -- of nothing. The tolerance absorbs the rounding in that fit.
    local needed = -endY
    if viewH > 0 and needed <= viewH + 6 then
        needed = viewH
    else
        needed = needed + 12
    end
    content:SetHeight(math.max(needed, 100))
    return endY
end

function UI:Refresh()
    if not self._content then return end
    self:RefreshStepper()

    -- One pass, because the scale is known before anything is drawn.
    -- Zero width means the frame has not been laid out yet, which is
    -- true on the very first build; BuildInto schedules another refresh
    -- for once it has.
    local scroll = self._scroll
    local w = scroll and scroll:GetWidth() or 0
    local rowScale = 1
    if w > 0 then
        rowScale = w / DESIGN_W
        if rowScale > MAX_SCALE then rowScale = MAX_SCALE end
        if rowScale < MIN_SCALE then rowScale = MIN_SCALE end
    end

    self._scale = rowScale
    self:Draw(rowScale)
end

------------------------------------------------------------
-- Shell page
--
-- The tab bar this file used to build is gone: My Spec and Loot
-- Council are declared as sub-tabs and the shell draws them, in
-- the one place every page puts them. That is also what frees the
-- row the fight style used to share with them -- it is a modifier
-- on the view, not a third view, so it belongs in the filter strip
-- with the search box and the item level stepper.
------------------------------------------------------------

--- Controls that modify the list rather than choose it.
function UI:BuildFilters(bar, ctx)
    local host = bar
    self._filterBar = bar

    -- Fight style, right-aligned so it reads as a modifier on the view
    -- rather than a third view. Styles with no data anywhere are skipped
    -- outright instead of offered as a tab onto an empty list.
    local styleButtons = {}
    local function selectStyle(id)
        state.style = id
        state.selected = nil
        state.ilvl = nil
        for sid, btn in pairs(styleButtons) do
            if sid == id then ns.SetTabActive(btn) else ns.SetTabInactive(btn) end
        end
        self:Refresh()
    end

    local sx = 0
    for i = #STYLES, 1, -1 do
        local def = STYLES[i]
        if T:HasStyle(def.id) then
            local btn = ns.CreateUnderlineTab(bar, def.label, ACCENT)
            local w = (def.id == "ST") and 100 or 60
            btn:SetSize(w, 24)
            btn:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -sx, 0)
            btn:SetScript("OnClick", function() selectStyle(def.id) end)
            styleButtons[def.id] = btn
            sx = sx + w + 6
        end
    end
    -- Fall back to whatever style does exist, so the page is never blank.
    if not styleButtons[state.style] then
        state.style = next(styleButtons) or "ST"
    end
    if styleButtons[state.style] then selectStyle(state.style) end

    ------------------------------------------------------------
    -- Item level stepper
    --
    -- A stepper rather than a dropdown because the question is not
    -- "show me 311", it is "where does the order change" -- and walking
    -- up the ladder one level at a time and watching rows overtake each
    -- other answers that, where picking a number out of a menu makes
    -- you guess which number to pick.
    ------------------------------------------------------------
    local ilvlBar = CreateFrame("Frame", nil, host)
    ilvlBar:SetSize(196, 20)

    local ilvlLabel = ilvlBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ilvlLabel:SetPoint("CENTER", ilvlBar, "CENTER", 0, 0)
    ilvlLabel:SetJustifyH("CENTER")
    ilvlLabel:SetWidth(140)

    local function stepIndex(steps)
        if not state.ilvl then return 0 end
        for i, v in ipairs(steps) do
            if v == state.ilvl then return i end
        end
        return 0
    end

    local function setStep(delta)
        local steps = currentSteps()
        if not steps then return end
        -- Index 0 is "best available". Clamped rather than wrapped: at
        -- the top of the ladder the next press should do nothing, not
        -- silently jump back to the bottom.
        local i = stepIndex(steps) + delta
        if i < 0 then i = 0 end
        if i > #steps then i = #steps end
        -- Long-hand, like toggle() in the council view and for the same
        -- reason: `(i == 0) and nil or steps[i]` reads as "nil at zero"
        -- and cannot do it. nil is falsy, so the `and` branch falls
        -- straight through to `steps[i]`, and the only thing making it
        -- behave is that steps[0] happens to be empty.
        if i == 0 then
            state.ilvl = nil
        else
            state.ilvl = steps[i]
        end
        state.showAll = false
        self:Refresh()
    end

    local prevBtn = CreateFrame("Button", nil, ilvlBar, "UIPanelButtonTemplate")
    prevBtn:SetSize(22, 20)
    prevBtn:SetPoint("LEFT", ilvlBar, "LEFT", 0, 0)
    prevBtn:SetText("<")
    prevBtn:SetScript("OnClick", function() setStep(-1) end)

    local nextBtn = CreateFrame("Button", nil, ilvlBar, "UIPanelButtonTemplate")
    nextBtn:SetSize(22, 20)
    nextBtn:SetPoint("RIGHT", ilvlBar, "RIGHT", 0, 0)
    nextBtn:SetText(">")
    nextBtn:SetScript("OnClick", function() setStep(1) end)

    self._ilvlBar = ilvlBar
    self._ilvlLabel = ilvlLabel
    self._ilvlPrev = prevBtn
    self._ilvlNext = nextBtn

    ------------------------------------------------------------
    -- Older trinkets
    --
    -- bloodmallet keeps simming trinkets from previous content, and a
    -- couple from expansions ago. They are real items and someone may
    -- still be wearing one, so they are worth being able to see -- but
    -- they are not what is dropping tonight, which is the question the
    -- Loot Council view exists to answer. Off by default, one click on.
    ------------------------------------------------------------
    local oldBox = CreateFrame("CheckButton", nil, host, "UICheckButtonTemplate")
    oldBox:SetSize(22, 22)
    local oldLabel = oldBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    oldLabel:SetPoint("LEFT", oldBox, "RIGHT", 2, 0)
    oldLabel:SetText("Show older trinkets")
    oldLabel:SetTextColor(0.72, 0.72, 0.78)
    oldBox:SetScript("OnClick", function(btn)
        state.showOld = btn:GetChecked() and true or false
        state.selected = nil
        state.showAll = false
        self:Refresh()
    end)
    oldBox:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Show older trinkets")
        GameTooltip:AddLine(
            "bloodmallet still sims trinkets from previous content. They are hidden here because they are not what drops in this season's dungeons and raid.",
            0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    oldBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self._oldBox = oldBox

    ------------------------------------------------------------
    -- Search
    ------------------------------------------------------------
    local searchBox = CreateFrame("EditBox", nil, host, "SearchBoxTemplate")
    searchBox:SetPoint("LEFT", bar, "LEFT", 4, 0)
    searchBox:SetSize(220, 20)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(40)
    if searchBox.Instructions then
        searchBox.Instructions:SetText("Search trinkets")
    end
    -- Anchored here rather than at creation: it sits beside the search
    -- box, and the box's own offset depends on whether the staleness
    -- banner took a line above it.
    ilvlBar:SetPoint("LEFT", searchBox, "RIGHT", 16, 0)
    -- Same slot as the stepper: they belong to different tabs, so only
    -- ever one of them is showing.
    oldBox:SetPoint("LEFT", searchBox, "RIGHT", 14, 0)

    -- Suggestions hang off host rather than the scroll content so they
    -- float over the list instead of pushing it down, and so scrolling
    -- cannot carry them out of view while the box still has focus.
    local suggest = CreateFrame("Frame", nil, host, "BackdropTemplate")
    suggest:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 8, -2)
    suggest:SetWidth(260)
    suggest:SetFrameStrata("DIALOG")
    suggest:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
    })
    suggest:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
    suggest:SetBackdropBorderColor(0.30, 0.30, 0.34, 1)
    suggest:Hide()

    local suggestRows = {}
    local function suggestRow(i)
        local b = suggestRows[i]
        if not b then
            b = CreateFrame("Button", nil, suggest)
            b:SetHeight(18)
            b:SetPoint("TOPLEFT", 4, -2 - (i - 1) * 18)
            b:SetPoint("RIGHT", suggest, "RIGHT", -4, 0)
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            b.text:SetPoint("LEFT", 2, 0)
            b.text:SetJustifyH("LEFT")
            local hl = b:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.10)
            suggestRows[i] = b
        end
        return b
    end

    -- Stops at MAX_SUGGEST rather than collecting everything and
    -- trimming: with a few hundred trinkets in the council view the
    -- difference is the whole loop versus five iterations, on every
    -- keystroke.
    local applyingSuggestion = false

    local function updateSuggestions(text)
        local needle = text:lower()
        if needle == "" then suggest:Hide() return end

        local n = 0
        local seen = {}
        for _, entry in ipairs(currentEntries()) do
            local name = entry.name
            if name and not seen[name] and matches(entry, needle) then
                seen[name] = true
                n = n + 1
                local b = suggestRow(n)
                b.text:SetText(name)
                b:SetScript("OnClick", function()
                    -- Flagged so OnTextChanged does not immediately
                    -- rebuild the suggestion list we are about to hide.
                    applyingSuggestion = true
                    searchBox:SetText(name)
                    applyingSuggestion = false
                    searchBox:ClearFocus()
                    suggest:Hide()
                end)
                b:Show()
                if n >= MAX_SUGGEST then break end
            end
        end
        for i = n + 1, #suggestRows do suggestRows[i]:Hide() end
        if n == 0 then
            suggest:Hide()
        else
            suggest:SetHeight(n * 18 + 6)
            suggest:Show()
        end
    end

    -- Debounced. Typing "alnseer" is seven refreshes without this, each
    -- rebuilding every row; coalescing means one. The token guards
    -- against an earlier timer firing after a later keystroke.
    local searchToken = 0
    -- HookScript, NOT SetScript, on every script the template defines.
    --
    -- SearchBoxTemplate's own OnTextChanged is what hides the "Search"
    -- placeholder and shows the clear button; its OnEditFocusLost puts
    -- the placeholder back; its OnEscapePressed empties the box.
    -- Replacing them left the placeholder painted over whatever was
    -- typed and the clear button out of step with the field.
    searchBox:HookScript("OnTextChanged", function(box, userInput)
        -- Deliberately NOT gated on userInput.
        --
        -- SearchBoxTemplate's clear button empties the box
        -- programmatically, so userInput is false and the old guard
        -- dropped the event -- the text vanished while state.search kept
        -- its old needle and the list stayed filtered with no way back
        -- short of a reload. Clicking a suggestion had the same fault
        -- from the other side: it set the text and the search never
        -- applied.
        --
        -- Re-entrancy is handled by the applyingSuggestion flag and by
        -- the no-op check below, so the guard bought nothing.
        local text = box:GetText() or ""
        if not applyingSuggestion then updateSuggestions(text) end

        searchToken = searchToken + 1
        local mine = searchToken
        C_Timer.After(0.12, function()
            if mine ~= searchToken then return end
            local needle = text:lower()
            if needle == state.search then return end
            state.search = needle
            state.selected = nil
            UI:Refresh()
        end)
    end)

    searchBox:HookScript("OnEscapePressed", function(box)
        box:SetText("")
        box:ClearFocus()
        suggest:Hide()
        if state.search ~= "" then
            state.search = ""
            UI:Refresh()
        end
    end)
    searchBox:HookScript("OnEnterPressed", function(box)
        box:ClearFocus()
        suggest:Hide()
    end)
    searchBox:HookScript("OnEditFocusLost", function() suggest:Hide() end)

    self._searchBox = searchBox

    self._searchBox = searchBox
end

--- The scrolling list itself.
function UI:BuildContent(parent, ctx)
    local host = parent

    -- The rows sit on a surface rather than straight on the window.
    -- Created before the scroll frame so it stays behind it: siblings at
    -- the same frame level draw in creation order.
    local surface = ns.Widgets and ns.Widgets:Panel(host, "inset")
    if surface then
        surface:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 2)
        surface:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
        self._surface = surface
    end

    local scroll = CreateFrame("ScrollFrame", nil, host, "UIPanelScrollFrameTemplate")
    -- Fills the region the shell gave us, and anchors to nothing else.
    -- This used to hang off the search box, which is how the page ended
    -- up owning its own controls: move the box and the list moved with
    -- it. The shell positions the strips now, so the list only has to
    -- know where its own region starts.
    -- Inset from the surface behind it, so the first row does not sit on
    -- the panel's border art.
    scroll:SetPoint("TOPLEFT", host, "TOPLEFT", 10, -6)
    scroll:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -26, 8)
    scroll:SetScript("OnMouseWheel", function(sf, delta)
        local newVal = sf:GetVerticalScroll() - delta * 30
        newVal = math.max(0, math.min(newVal, sf:GetVerticalScrollRange()))
        sf:SetVerticalScroll(newVal)
    end)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(math.max(host:GetWidth() - 40, 400), 400)
    scroll:SetScrollChild(content)
    self._content = content
    self._scroll = scroll

    -- Re-fit when the window is resized. Guarded because Draw sets the
    -- content's own size, and an unguarded handler that redraws on a
    -- size change is one layout pass away from recursing forever.
    scroll:SetScript("OnSizeChanged", function()
        if self._fitting then return end
        self._fitting = true
        -- Cleared through an error, then the error is re-raised. Left
        -- to unwind on its own the flag would stay set, and every later
        -- resize would return here immediately -- one bad render would
        -- silently cost the page its re-fit for the rest of the
        -- session, with nothing after the first error to show for it.
        local ok, err = pcall(self.Refresh, self)
        self._fitting = false
        if not ok then error(err, 0) end
    end)

    -- At build time the scroll frame has not been laid out yet and
    -- measures zero, so the shell's first Refresh cannot know how much
    -- room it has. One more after the frame settles, or the page stays
    -- unscaled until something else happens to refresh it.
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() self:Refresh() end)
    end
end

------------------------------------------------------------
-- Registration
--
-- Everything the shell needs to draw this page's furniture. The tab
-- labels live here rather than in a tab bar this file builds, which is
-- the whole point of the migration: the page says what its views are,
-- the shell decides where they go and what they look like.
------------------------------------------------------------
if ns.Shell then
    ns.Shell:RegisterPage({
        id     = "trinkets",
        label  = "Trinkets",
        accent = ACCENT,
        order  = 30,
        -- The audit floor. Bars are a share of the row, so a narrower
        -- content region does not crop them, it just makes the shape of
        -- the curve unreadable -- which is the only reason to draw them.
        minWidth = 700,

        subTabs = function()
            local out = {}
            for _, def in ipairs(TABS) do
                out[#out + 1] = { id = def.id, label = def.label, width = 110 }
            end
            return out
        end,

        filters = function(bar, ctx) UI:BuildFilters(bar, ctx) end,
        Build   = function(host, ctx) UI:BuildContent(host, ctx) end,

        -- The item level ladder belongs to one spec and one fight style.
        -- Carrying a level across a view change means landing on one the
        -- new list was never simmed at, and an empty page is a worse
        -- answer than the default one.
        OnSubTab = function(id)
            state.tab = id
            state.selected = nil
            state.ilvl = nil
        end,

        -- ctx.content is the region the shell gave us; _content is the
        -- scroll child inside it that BuildContent created. Assigning
        -- one to the other would hand Draw the viewport in place of the
        -- thing that scrolls, and the list would never move.
        Refresh = function() UI:Refresh() end,
    })
end
