local _, ns = ...

------------------------------------------------------------
-- Mythic+ Utility Advisor
-- Shows per-dungeon utility advice with spell icons filtered
-- to the player's class and spec. Hover any icon for a
-- full tooltip.
--
-- The data lives in Features/MythicPlus/UtilityData.lua, which is
-- GENERATED -- see Tools/build_utility.py for where the per-dungeon
-- mechanic-to-utility mapping comes from and what is ours. It used to
-- sit inline here, which meant a thousand lines of data in front of the
-- three hundred that draw it, and no way to say when it was last built.
------------------------------------------------------------

ns.UtilityAdvisor = ns.UtilityAdvisor or {}
local UA = ns.UtilityAdvisor

------------------------------------------------------------
-- Data
------------------------------------------------------------

--- Falls back to an empty table rather than nil: every reader here
--- indexes it by instanceMapID, and a missing data file should mean a
--- quiet advisor rather than an error on entering a dungeon.
UA.DUNGEONS = ns.UTILITY_DUNGEONS or {}

------------------------------------------------------------
-- UI
------------------------------------------------------------

local win
local ICON_SIZE = 48   -- default; overridden per-player below

-- Full shows the dungeon writeup; compact shows only the recommended
-- abilities. Mid-key nobody reads prose -- what you actually re-check is
-- "which of my buttons matters here", and that is the icon row.
local FULL_W    = 420
local COMPACT_W = 300
local ICON_PAD  = 6
local BORDER_SIZE = 2

local function styleBox(f, bgA)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    f:SetBackdropColor(0.04, 0.04, 0.04, bgA or 0.95)
    f:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
end

-- Appearance persistence. Position and the lock moved to the shared
-- situation window (Core/Hud.lua); what is left here -- compact view and
-- icon size -- is about how this panel draws itself, which is still its
-- own business.

local function posDB()
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.utilityAdvisor = YippYappHelperDB.utilityAdvisor or {}
    local d = YippYappHelperDB.utilityAdvisor
    if type(d.compact) ~= "boolean" then d.compact = false end
    if type(d.iconSize) ~= "number" then d.iconSize = ICON_SIZE end
    if d.iconSize < 24 then d.iconSize = 24 elseif d.iconSize > 64 then d.iconSize = 64 end
    return d
end

--- Player-configurable icon size. Read through a function rather than a
--- constant so a change takes effect on the next render without a reload.
local function iconSize() return posDB().iconSize or ICON_SIZE end

local function build()
    if win then return win end
    win = CreateFrame("Frame", "YippYappUtilityAdvisor", UIParent, "BackdropTemplate")
    win:SetSize(FULL_W, 240)
    win:EnableMouse(true)
    styleBox(win)
    win:Hide()

    -- A panel of the shared situation window; it owns where this sits,
    -- so the drag handler and the "drag to move" overlay are gone.

    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -8)
    win.title = title

    local close = CreateFrame("Button", nil, win, "BackdropTemplate")
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -4, -4)
    styleBox(close, 0.9)
    local cl = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cl:SetPoint("CENTER"); cl:SetText("x")
    close:SetScript("OnClick", function() win:Hide() end)

    -- "Stop showing me this", in the corner of the thing being shown.
    --
    -- The setting already existed in the options panel, but nobody goes
    -- looking for a settings page to turn off a window they are annoyed
    -- by right now -- they close it, it comes back next dungeon, and the
    -- addon looks like it does not listen. The close button means "not
    -- now"; this means "not again".
    --
    -- Top LEFT because the close button owns the top right, and putting
    -- a permanent switch under the cursor that just came off a dismiss
    -- button is how people turn a feature off by accident.
    local mute = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
    mute:SetSize(20, 20)
    mute:SetPoint("TOPLEFT", 8, -5)
    mute:SetHitRectInsets(0, -76, 0, 0)   -- the label is part of the target
    win.mute = mute

    local muteLabel = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    muteLabel:SetPoint("LEFT", mute, "RIGHT", 1, 0)
    muteLabel:SetText("Don't show this")
    muteLabel:SetTextColor(0.55, 0.55, 0.58)

    mute:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Don't show this")
        GameTooltip:AddLine("Stops the utility notes opening when you enter a "
            .. "Mythic+ dungeon.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Turn it back on under Options - AddOns - "
            .. "YippYapp Helper.", 0.5, 0.5, 0.5, true)
        GameTooltip:Show()
    end)
    mute:SetScript("OnLeave", GameTooltip_Hide)

    mute:SetScript("OnClick", function(self)
        if not self:GetChecked() then return end
        if ns.SetModuleEnabled then ns.SetModuleEnabled("utilityAdvisor", false) end
        -- Say where the switch is on the way out. Once this window is
        -- gone there is nothing left to un-tick, so a checkbox with no
        -- route back would just be a trap with a nice label on it.
        print("|cff00ff00YippYapp|r utility notes off. Options - AddOns - "
            .. "YippYapp Helper to bring them back.")
        UA:Hide()
    end)

    local desc = win:CreateFontString(nil, "OVERLAY")
    desc:SetFont(STANDARD_TEXT_FONT, 12, "")
    desc:SetPoint("TOPLEFT", 14, -34)
    desc:SetPoint("TOPRIGHT", -14, -34)
    desc:SetJustifyH("LEFT")
    desc:SetSpacing(3)
    desc:SetWordWrap(true)
    desc:SetTextColor(0.92, 0.92, 0.92)
    win.desc = desc

    local div = win:CreateTexture(nil, "OVERLAY")
    div:SetColorTexture(0.35, 0.35, 0.35, 0.6)
    div:SetHeight(1)
    win.div = div

    local legend = win:CreateFontString(nil, "OVERLAY")
    legend:SetFont(STANDARD_TEXT_FONT, 10, "")
    legend:SetJustifyH("LEFT")
    legend:SetTextColor(0.55, 0.55, 0.55)
    legend:SetText("|cff33ff33Green|r = baseline      |cffffd100Gold T|r = talent")
    win.legend = legend

    local iconRow = CreateFrame("Frame", nil, win)
    iconRow:SetPoint("TOPLEFT", 14, -100)
    iconRow:SetPoint("TOPRIGHT", -14, -100)
    iconRow:SetHeight(iconSize() + 8)
    win.iconRow = iconRow

    local fallback = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fallback:SetPoint("BOTTOMLEFT", 12, 20)
    fallback:SetPoint("BOTTOMRIGHT", -12, 20)
    fallback:SetJustifyH("LEFT")
    fallback:SetTextColor(0.55, 0.55, 0.55)
    fallback:SetWordWrap(true)
    win.fallback = fallback

    -- Adopted by the shared situation window, at the bottom of the
    -- order. These are notes for a dungeon you are standing in: useful,
    -- never urgent, and the one of the three that can afford to wait --
    -- which is exactly why it is the one that comes back afterwards.
    if ns.Hud then
        ns.Hud:Register("utilityAdvisor", win, {
            label   = "Dungeon utility",
            aliases = { "utility", "advisor", "notes" },
            -- Left edge, out of the way: this is reference material you
            -- glance at on the way in, not something to read over the
            -- top of the pull.
            default = { point = "LEFT", relativePoint = "LEFT", x = 40, y = -40 },
            preview = function(arg) UA:PreviewCommand(arg) end,
        })
    end

    return win
end

-- Persistent icon pool. Icons are created once and re-styled on each
-- show — without this we'd leak ~5-10 frames per advisor refresh.
local iconPool = {}

local function clearIcons(row)
    for _, btn in ipairs(iconPool) do btn:Hide() end
end

local function normalizeSpell(entry)
    if type(entry) == "number" then return { id = entry } end
    return entry
end

local function acquireIcon(parent, idx)
    local btn = iconPool[idx]
    if btn then return btn end
    btn = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    btn:SetSize(iconSize(), iconSize())
    btn:EnableMouse(true)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = BORDER_SIZE,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    btn:SetBackdropColor(0, 0, 0, 0)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    btn.icon:SetPoint("BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- Talent "T" badge stays hidden unless this icon represents a talent.
    btn.talentBadge = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLargeOutline")
    btn.talentBadge:SetPoint("BOTTOMRIGHT", 2, -2)
    btn.talentBadge:SetText("T")
    btn.talentBadge:SetTextColor(1, 0.82, 0)
    btn.talentBadge:Hide()
    iconPool[idx] = btn
    return btn
end

local function styleIcon(btn, parent, entry, xOffset, yOffset)
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(entry.id)
    local tex = info and info.iconID

    btn:SetParent(parent)
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)

    if entry.talent then
        btn:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
        btn.talentBadge:Show()
    else
        btn:SetBackdropBorderColor(0.15, 0.95, 0.35, 1.0)
        btn.talentBadge:Hide()
    end

    btn.icon:SetTexture(tex or 134400)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(entry.id)
        if entry.note then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(entry.note, 0.0, 0.8, 1.0, true)
        end
        if entry.talent then
            GameTooltip:AddLine("|cffffd100Talent — pick this up for this dungeon|r")
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    btn:Show()
end

-- Deduplicate by spell id (bySpec entries win over byClass)
local function buildEntryList(data, class, specID)
    local seen, list = {}, {}
    local function pushAll(src)
        if not src then return end
        for _, raw in ipairs(src) do
            local e = normalizeSpell(raw)
            if e and e.id and not seen[e.id] then
                seen[e.id] = true
                table.insert(list, e)
            end
        end
    end
    if data.bySpec and specID and data.bySpec[specID] then
        pushAll(data.bySpec[specID])
    end
    if data.byClass and class and data.byClass[class] then
        pushAll(data.byClass[class])
    end
    return list
end

--- Lay out icons, balanced across rows. Returns total height used.
---
--- Greedy wrapping packed each row to the edge and left the remainder
--- stranded -- six icons then one, which reads as a mistake. Instead work
--- out the fewest rows that fit, then spread evenly over them, so seven
--- icons become 4+3 rather than 6+1.
local function layoutIcons(row, entries, rowWidth)
    local size = iconSize()
    local stride = size + ICON_PAD
    local n = #entries
    if n == 0 then return stride end

    local perRow = math.max(1, math.floor((rowWidth + ICON_PAD) / stride))
    local rows = math.ceil(n / perRow)
    perRow = math.ceil(n / rows)          -- even out the last row

    local i = 0
    for r = 0, rows - 1 do
        local count = math.min(perRow, n - i)
        -- Centre each row so a short final row does not hang left.
        local rowW = count * stride - ICON_PAD
        local startX = math.max(0, (rowWidth - rowW) / 2)
        for c = 0, count - 1 do
            i = i + 1
            styleIcon(acquireIcon(row, i), row, entries[i],
                startX + c * stride, -r * stride)
        end
    end
    return rows * stride
end

-- Keyword → color table. Patterns use bracketed first-letter class so we
-- catch both sentence-start and mid-sentence capitalization without a
-- second pass. Order matters for multi-word phrases — longer matches
-- listed first so they aren't broken up by a shorter keyword's gsub.
local DESC_KEYWORD_COLORS = {
    { "([Mm]agic%-categorized)",         "ff6ac8ff" },
    { "([Mm]ortal [Ww]ounds)",            "ffff8060" },
    { "([Pp]urges?)",                    "ff66ddff" },
    { "([Pp]urged)",                     "ff66ddff" },
    { "([Dd]ispels?)",                   "ff6ac8ff" },
    { "([Dd]ispelled)",                  "ff6ac8ff" },
    { "([Cc]leanses?)",                  "ff6ac8ff" },
    { "([Ii]nterruptible)",              "ffffe066" },
    { "([Ii]nterrupts?)",                "ffffe066" },
    { "([Ii]nterrupted)",                "ffffe066" },
    { "([Ee]nrages?)",                   "ffff6262" },
    { "([Cc]urses?)",                    "ffc266ff" },
    { "([Cc]ursed)",                     "ffc266ff" },
    { "([Dd]iseases?)",                  "ffa98b6f" },
    { "([Pp]oisons?)",                   "ff66dd66" },
    { "([Bb]leeds?)",                    "ffcc4444" },
    { "([Ss]tuns?)",                     "ffffcc33" },
    { "([Ss]tunned)",                    "ffffcc33" },
    { "([Ff]ears?)",                     "ffc06aff" },
    { "([Ff]eared)",                     "ffc06aff" },
    { "([Ss]lows?)",                     "ff8fd4ff" },
    { "([Ss]nares?)",                    "ff8fd4ff" },
    { "([Ii]ncap'?d?)",                  "ffffa0e0" },
    { "([Gg]rips?)",                     "ffd6a04f" },
    { "([Gg]ripped)",                    "ffd6a04f" },
}

-- Wrap sequences of two consecutive Title-Cased words (e.g. "Raging
-- Screech", "Power Vacuum", "Blade Rush") in white so ability names
-- pop against the body text. Run BEFORE keyword coloring so keyword
-- colors aren't smothered inside nested |c…|r tags.
local function descBoldAbilities(text)
    return text:gsub("(%u%l+)([ %-'])(%u%l+)", "|cffffffff%1%2%3|r")
end

local function descColorizeKeywords(text)
    for _, pair in ipairs(DESC_KEYWORD_COLORS) do
        text = text:gsub(pair[1], "|c" .. pair[2] .. "%1|r")
    end
    return text
end

-- Split a dense description paragraph into one bulleted line per
-- sentence so the user can scan mechanic-by-mechanic instead of
-- parsing a wall of prose. Sentence boundaries are "." "!" "?" — and
-- we trim whitespace at both edges of each fragment.
local function descBulletize(text)
    local out = {}
    -- Trimmed into a fresh local rather than back onto the loop
    -- variable. Identical under the client's Lua 5.1, but 5.5 makes a
    -- for-in control variable const -- and Tools/loadcheck.py runs on
    -- 5.5, so this one line was skipping the whole file there.
    for raw in text:gmatch("([^%.%?!]+[%.%?!]?)") do
        local fragment = raw:gsub("^%s+", ""):gsub("%s+$", "")
        if fragment ~= "" then
            table.insert(out, "|cff66b5ff›|r  " .. fragment)
        end
    end
    return table.concat(out, "\n")
end

local function formatDescription(text)
    if not text or text == "" then return "" end
    local styled = descBoldAbilities(text)
    styled = descColorizeKeywords(styled)
    return descBulletize(styled)
end

local function renderDungeon(mapID)
    local w = build()
    -- Cleared on every render, which is the one thing both show paths
    -- have in common. The window only ever appears while the module is
    -- on, so a ticked box would be describing something untrue -- and it
    -- stays ticked otherwise, because nothing unticks it: the click
    -- hides the window rather than waiting around to be undone.
    if w.mute then w.mute:SetChecked(false) end
    local data = UA.DUNGEONS[mapID]
    if not data then
        w.title:SetText("No notes")
        w.desc:SetText("|cffff8080No data for instanceMapID " .. tostring(mapID) .. "|r")
        w.fallback:SetText("")
        w.div:Hide(); w.legend:Hide()
        clearIcons(w.iconRow)
        return
    end

    w.title:SetText(data.header or "Utility")

    local compact = posDB().compact
    w:SetWidth(compact and COMPACT_W or FULL_W)

    if compact then
        -- Title + icons only. Everything else is reference material that
        -- belongs in the full view.
        w.desc:SetText("")
        w.desc:Hide()
        w.div:Hide()
        w.legend:Hide()
        w.fallback:SetText("")

        clearIcons(w.iconRow)
        local _, cls = UnitClass("player")
        local specIdx = GetSpecialization and GetSpecialization()
        local sID = specIdx and GetSpecializationInfo and GetSpecializationInfo(specIdx)
        local list = buildEntryList(data, cls, sID)

        w.iconRow:ClearAllPoints()
        w.iconRow:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -30)
        w.iconRow:SetPoint("TOPRIGHT", w, "TOPRIGHT", -14, -30)

        if #list == 0 then
            w.fallback:SetText(ns.Widgets:Tint("muted", "No recommendations for this spec yet"))
            w:SetHeight(72)
            return
        end
        local h = layoutIcons(w.iconRow, list, COMPACT_W - 28)
        w.iconRow:SetHeight(h)
        w:SetHeight(30 + h + 14)
        return
    end

    w.desc:Show()

    -- Description: bulleted, color-coded. Lead still gets the stylized
    -- italic-esque intro look (slightly softer white, no bullet) so the
    -- user reads one-line orientation before the per-mechanic bullets.
    local formattedDesc = formatDescription(data.description or "")
    local body
    if data.lead and data.lead ~= "" then
        body = ("|cffe8e8e8%s|r\n\n%s"):format(data.lead, formattedDesc)
    else
        body = formattedDesc
    end
    w.desc:SetText(body)
    w.desc:SetSpacing(5)

    clearIcons(w.iconRow)
    local _, class = UnitClass("player")
    local specIndex = GetSpecialization and GetSpecialization()
    local specID
    if specIndex and GetSpecializationInfo then
        specID = GetSpecializationInfo(specIndex)
    end

    local entries = buildEntryList(data, class, specID)

    local descBottom = -34 - w.desc:GetStringHeight() - 8
    w.div:ClearAllPoints()
    w.div:SetPoint("TOPLEFT", w, "TOPLEFT", 14, descBottom)
    w.div:SetPoint("TOPRIGHT", w, "TOPRIGHT", -14, descBottom)
    w.div:Show()

    w.legend:ClearAllPoints()
    w.legend:SetPoint("TOPLEFT", w, "TOPLEFT", 14, descBottom - 6)
    w.legend:Show()

    w.iconRow:ClearAllPoints()
    w.iconRow:SetPoint("TOPLEFT", w, "TOPLEFT", 14, descBottom - 26)
    w.iconRow:SetPoint("TOPRIGHT", w, "TOPRIGHT", -14, descBottom - 26)

    if #entries == 0 then
        w.fallback:SetText(("|cff%sNo recommendations seeded for %s yet — add entries to UA.DUNGEONS[%d].byClass.%s|r"):format(ns.Widgets:Hex("muted"), class or "your class", mapID, class or ""))
        w:SetHeight(math.max(180, 120 + (w.desc:GetStringHeight() or 40)))
        return
    end

    w.fallback:SetText("")
    local rowWidth = w:GetWidth() - 28
    local iconsHeight = layoutIcons(w.iconRow, entries, rowWidth)
    w.iconRow:SetHeight(iconsHeight)

    local descH = w.desc:GetStringHeight() or 40
    local totalH = 34 + descH + 8 + 1 + 14 + 12 + iconsHeight + 20
    w:SetHeight(math.max(180, totalH))
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------

UA._lastShownMapID = nil

function UA:ShowForCurrentInstance(force)
    local _, instType, difficultyID, _, _, _, _, instanceMapID = GetInstanceInfo()
    if not force then
        -- Asked here rather than only at the event handler that usually
        -- calls this. "Don't show this" is a promise the window makes on
        -- its own face, and a promise kept by whoever happens to call is
        -- one broken by the next caller who forgets -- the spec-change
        -- re-render already reaches this function by another route.
        --
        -- `force` still gets through: turning the notes off means they
        -- stop appearing on their own, not that /yh test utility should
        -- refuse to show you what they look like.
        if ns.ModuleEnabled and not ns.ModuleEnabled("utilityAdvisor") then
            self._lastShownMapID = nil
            return
        end
        if instType ~= "party" then
            self._lastShownMapID = nil
            return
        end
        if difficultyID ~= 8 and difficultyID ~= 23 then return end
        if self._lastShownMapID == instanceMapID then return end
        self._lastShownMapID = instanceMapID
    end
    if not self.DUNGEONS[instanceMapID] then
        if force then
            build().title:SetText("No notes")
            build().desc:SetText("No data for instanceMapID " .. tostring(instanceMapID))
            clearIcons(build().iconRow)
            build().fallback:SetText("")
            build():Show()
        end
        return
    end
    renderDungeon(instanceMapID)
    build():Show()
end

--- Samples whichever dungeon the data happens to hold.
---
--- It used to name a map id outright, and that id was Algeth'ar Academy
--- -- so the moment the pool rolled over, every preview of this window
--- drew nothing at all. Reading the first entry instead means the sample
--- cannot go stale ahead of the data it is sampling. Sorted, so the
--- preview is the same window twice rather than whatever the hash
--- happened to hand back.
--- Every dungeon we hold notes for, in a fixed order.
---
--- Sorted by map id rather than left in hash order, because the whole
--- point of stepping through them is that "next" means the same thing
--- twice. Rebuilt on each call: the table is generated and could be
--- reloaded under us, and eight entries is not worth caching.
function UA:TestDungeons()
    local list = {}
    for mapID in pairs(self.DUNGEONS) do list[#list + 1] = mapID end
    table.sort(list)
    return list
end

--- Renders one dungeon by map id, whether or not you are standing in it.
function UA:ShowTestFor(mapID)
    local data = self.DUNGEONS[mapID]
    if not data then return false end
    -- Recorded so SetCompact and SetIconSize can re-render in place.
    -- Without it, changing either in Edit Mode does nothing visible.
    self._lastShownMapID = mapID
    renderDungeon(mapID)
    build():Show()
    return true
end

--- Steps through the dungeons, one call at a time.
---
--- This exists because the notes cannot otherwise be read without eight
--- keystones: the window only appears on entering a dungeon we have data
--- for, so checking that all eight render -- and that the text fits, and
--- that nobody's class list is empty -- meant a season of running them.
--- `delta` of 1 is the next one, -1 the previous, and it wraps.
function UA:CycleTest(delta)
    local list = self:TestDungeons()
    if #list == 0 then
        print("|cffff5555YippYapp:|r no utility data is loaded to preview.")
        return
    end

    local at = 0
    for i, mapID in ipairs(list) do
        if mapID == self._lastShownMapID then at = i; break end
    end
    -- Zero-based arithmetic so the wrap is one modulo rather than two
    -- boundary tests, and so an unknown current dungeon starts at the
    -- first rather than the second.
    local next = ((at - 1 + (delta or 1)) % #list) + 1

    self:ShowTestFor(list[next])
    local data = self.DUNGEONS[list[next]]
    print(("|cff00ff00YippYapp|r %d/%d  %s   |cff888888/yh test utility next|r")
        :format(next, #list, (data and data.header) or tostring(list[next])))
end

--- Shows whatever was last previewed, or the first dungeon.
---
--- Deliberately does not advance: this is what Edit Mode and the panel
--- preview call, and a window that changed dungeon every time the Edit
--- Mode dialog refreshed would be unusable to position against.
function UA:ShowTest()
    if self._lastShownMapID and self:ShowTestFor(self._lastShownMapID) then return end
    self:CycleTest(0)
end

--- Finds a dungeon by name, on any distinctive part of it.
---
--- Matched plainly rather than by pattern, so "kings" finds Kings' Rest
--- without the apostrophe turning into a character class and "vale"
--- finds The Blinding Vale without typing the article.
function UA:FindTestDungeon(word)
    if type(word) ~= "string" or word == "" then return nil end
    word = word:lower()
    for _, mapID in ipairs(self:TestDungeons()) do
        local header = (self.DUNGEONS[mapID].header or ""):lower()
        if header:find(word, 1, true) then return mapID end
    end
    return nil
end

--- The chat side of all of the above: `next`, `prev`, `list`, or a name.
function UA:PreviewCommand(arg)
    arg = (type(arg) == "string" and arg:gsub("^%s+", ""):gsub("%s+$", "") or ""):lower()

    if arg == "" then
        self:ShowTest()
        return
    end
    if arg == "here" or arg == "." then
        -- Renders wherever you are standing, missing or not. This is the
        -- one place the "no data for instanceMapID N" panel is useful:
        -- it is how you find out which id a dungeon actually reports.
        self:ShowForCurrentInstance(true)
        return
    end
    if arg == "next" or arg == "n" then return self:CycleTest(1) end
    if arg == "prev" or arg == "p" or arg == "back" then return self:CycleTest(-1) end

    if arg == "list" then
        print("|cff00ff00=== Utility notes ===|r")
        for i, mapID in ipairs(self:TestDungeons()) do
            local data = self.DUNGEONS[mapID]
            local mark = (mapID == self._lastShownMapID) and "|cff00ff00*|r " or "  "
            print(("%s%d. %s"):format(mark, i, (data and data.header) or mapID))
        end
        print("  |cff888888/yh test utility next|r steps through them")
        return
    end

    local mapID = self:FindTestDungeon(arg)
    if mapID then
        self:ShowTestFor(mapID)
        print(("|cff00ff00YippYapp|r %s"):format(self.DUNGEONS[mapID].header or mapID))
        return
    end
    print(("|cffff5555YippYapp:|r no dungeon matching \"%s\". Try |cff888888/yh test utility list|r.")
        :format(arg))
end

function UA:Hide() if win then win:Hide() end end

function UA:IsCompact() return posDB().compact and true or false end

--- Switching view re-renders in place so the change is visible at once,
--- rather than only on the next dungeon entry.
function UA:SetCompact(on)
    posDB().compact = not not on
    if win and win:IsShown() and UA._lastShownMapID then
        renderDungeon(UA._lastShownMapID)
    end
end

function UA:GetIconSize() return posDB().iconSize or ICON_SIZE end
function UA:SetIconSize(v)
    posDB().iconSize = math.max(24, math.min(64, tonumber(v) or ICON_SIZE))
    if win and win:IsShown() and UA._lastShownMapID then
        renderDungeon(UA._lastShownMapID)
    end
end

------------------------------------------------------------
-- Events
------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("CHALLENGE_MODE_START")
f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
-- Payload names deliberately neutral: the third argument is
-- isInitialLogin for PLAYER_ENTERING_WORLD and a UNIT for
-- PLAYER_SPECIALIZATION_CHANGED, and naming it after one of them is how
-- the other got read as a boolean and ignored.
f:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "PLAYER_LOGIN" then
        -- Built at login purely so it can register itself with the
        -- shared situation window. This is the only one of the three
        -- that is otherwise never built outside a keystone dungeon, and
        -- an unregistered panel is one the Edit Mode preview cannot
        -- select -- so you could not position the notes without first
        -- walking into a key. The completion popup builds here for the
        -- same reason.
        build()
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = a1, a2
        if isInitialLogin or isReloadingUi then return end
        if ns.ModuleEnabled and not ns.ModuleEnabled("utilityAdvisor") then return end
        C_Timer.After(0.5, function() UA:ShowForCurrentInstance() end)
    elseif event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_COMPLETED" then
        UA:Hide()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- This event carries a UNIT, and in a group it fires over and
        -- over as party members' spec information resolves. Acting on
        -- somebody else's spec change is what made the window snap away
        -- from whatever you had just opened, a second after you opened
        -- it -- and snap to a diagnostic, because it forced a render of
        -- whatever instance you were standing in.
        if a1 ~= "player" then return end
        if not (win and win:IsShown()) then
            UA._lastShownMapID = nil
            return
        end
        -- Re-render what is ON SCREEN. The reason this handler exists is
        -- that the icons are filtered by spec and the spec changed, so
        -- the window that needs refiltering is the one being read --
        -- which is not necessarily the dungeon you are standing in, and
        -- is certainly not it while you are stepping through them.
        local shown = UA._lastShownMapID
        if shown and UA.DUNGEONS[shown] then
            UA:ShowTestFor(shown)
        else
            -- Nothing worth re-rendering, and an unbidden "no data for
            -- instanceMapID" panel mid-raid is noise rather than news.
            UA._lastShownMapID = nil
            UA:Hide()
        end
    end
end)

-- No slash command of its own. /yh test utility has called PreviewCommand
-- through the panel registry since it landed, so /yyhutility was a second
-- name for the same line of code.
