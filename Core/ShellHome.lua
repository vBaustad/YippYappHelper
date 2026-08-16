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
-- `unit` is what a slot's threshold counts, which differs per category
-- and is the difference between "4" and "raid bosses 4".
local VAULT_ROWS = {
    { key = "mplus", label = "Mythic+", accent = "accent", unit = "dungeons" },
    { key = "raid",  label = "Raid",    accent = "warn",   unit = "bosses"   },
    { key = "world", label = "World",   accent = "good",   unit = "world"    },
}

local PLAN_ROWS = 6

-- The vault is three categories of three rewards. Read from the data
-- where possible, but the row has to be built before the data is asked
-- for, so three is the shape and a category returning more is clamped.
local VAULT_SLOTS = 3
local VAULT_ROW_H = 52
local VAULT_LABEL_W = 76


local ui

local function Build(host)
    ui = { host = host }
    -- Published so the widgets this page builds can be inspected from
    -- outside it -- by the test harness, and by anyone debugging a
    -- layout in game. Read-only by convention; nothing here reads it
    -- back.
    ns.ShellHomeUI = ui

    -- No hero card here. The character column carries the portrait,
    -- name, item level and stats on every page, so repeating it on the
    -- dashboard put the same face on screen twice.
    --
    -- `anchor` stands in for it as the thing the first section hangs
    -- from, so the rest of the page keeps its shape.
    ui.top = CreateFrame("Frame", nil, host)
    ui.top:SetHeight(1)
    ui.top:SetPoint("TOPLEFT", PAD, -PAD)
    ui.top:SetPoint("RIGHT", host, "RIGHT", -PAD, 0)

    ------------------------------------------------------------
    -- Great Vault
    ------------------------------------------------------------
    ui.vaultTitle = W:SectionTitle(host, "great vault")
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
        local row = CreateFrame("Frame", nil, host)
        row:SetHeight(VAULT_ROW_H)
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, i == 1 and -10 or -GAP)
        row:SetPoint("RIGHT", ui.top, "RIGHT", 0, 0)

        row.label = W:Label(row, "GameFontNormal")
        row.label:SetPoint("TOPLEFT", 2, -4)
        row.label:SetWidth(VAULT_LABEL_W)
        row.label:SetText(def.label)

        row.tally = W:Label(row, "GameFontNormalSmall")
        row.tally:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
        row.tally:SetWidth(VAULT_LABEL_W)
        row.tally:SetTextColor(W:Color("muted"))

        row.slots = {}
        for s = 1, VAULT_SLOTS do
            -- A card, not a row. On the `row` role these were a fill at
            -- 0.35 alpha with no edge, so nine of them read as loose text
            -- floating on the page rather than as nine reward slots.
            local tile = W:Panel(row, "inset")

            tile.caption = W:Label(tile, "GameFontNormalSmall")
            tile.caption:SetPoint("TOPLEFT", 10, -8)
            tile.caption:SetTextColor(W:Color("muted"))

            tile.state = W:Label(tile, "GameFontNormalLarge")
            tile.state:SetPoint("BOTTOMLEFT", 10, 8)

            -- A left stripe carrying the category's colour. It is the one
            -- thing that tells the three rows apart at a glance, and it
            -- costs less attention than three coloured headings.
            tile.stripe = tile:CreateTexture(nil, "OVERLAY")
            tile.stripe:SetPoint("TOPLEFT", 2, -2)
            tile.stripe:SetPoint("BOTTOMLEFT", 2, 2)
            tile.stripe:SetWidth(3)
            tile.stripe:SetColorTexture(W:Color(def.accent))
            tile.stripe:SetAlpha(0.30)

            row.slots[s] = tile
        end

        ui.rows[def.key] = row
        anchor = row
    end

    ------------------------------------------------------------
    -- This week
    ------------------------------------------------------------
    ui.statTitle = W:SectionTitle(host, "this week")
    ui.statTitle:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -GAP * 2)
    ui.statTitle:SetPoint("RIGHT", ui.top, "RIGHT", 0, 0)

    -- One surface, not three. Three tiles side by side was three
    -- bordered boxes for three numbers that belong together, on a page
    -- that had a box around every single thing on it.
    -- "vault unlocked", not "crests banked".
    --
    -- Two things were wrong with the old middle cell. The label had been
    -- left saying "crests banked" after the value was swapped to Mythic+
    -- rating, so the cell was captioned with one thing and showing
    -- another. And rating is not a weekly number -- this strip is "this
    -- week", and how much of the vault you have earned is, so it belongs
    -- here and comes from the snapshot the page already reads.
    ui.stats = W:StatStrip(host, { "keystone", "vault unlocked", "resets in" })
    -- Width is set on refresh, not here: the host has no width until the
    -- shell has laid it out, and a strip sized from zero stays that size.

    ------------------------------------------------------------
    -- Tonight
    ------------------------------------------------------------
    ui.planTitle = W:SectionTitle(host, "worth doing tonight")
    ui.planTitle:SetPoint("TOPLEFT", ui.stats, "BOTTOMLEFT", 0, -GAP * 3)
    ui.planTitle:SetPoint("RIGHT", ui.top, "RIGHT", 0, 0)

    ui.plan = {}
    anchor = ui.planTitle
    for i = 1, PLAN_ROWS do
        local card = W:Panel(host, "inset")
        card:SetHeight(46)
        card:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, i == 1 and -10 or -6)
        card:SetPoint("RIGHT", ui.top, "RIGHT", 0, 0)

        card.stripe = card:CreateTexture(nil, "OVERLAY")
        card.stripe:SetPoint("TOPLEFT", 3, -3)
        card.stripe:SetPoint("BOTTOMLEFT", 3, 3)
        card.stripe:SetWidth(3)

        card.title = W:Label(card, "GameFontNormal")
        card.title:SetPoint("TOPLEFT", 16, -8)
        card.title:SetPoint("RIGHT", card, "RIGHT", -12, 0)

        card.detail = W:Label(card, "GameFontNormalSmall")
        card.detail:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -3)
        card.detail:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        card.detail:SetTextColor(W:Color("muted"))

        ui.plan[i] = card
        anchor = card
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
    local rowW = (ctx and ctx.width or ui.host:GetWidth() or 0) - PAD * 2
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
                tile.stripe:SetAlpha(0.12)
            else
                local progress  = tonumber(slot.progress) or 0
                local threshold = tonumber(slot.threshold) or 0
                -- Lifted from |cff888888. On a dark brown surface that
                -- grey was reading as barely-there rather than as
                -- secondary, which is most of why the page was hard to
                -- read at a glance.
                tile.caption:SetText(("|cffa8a29a%s %d|r"):format(
                    def.unit or "runs", threshold))
                if slot.unlocked then
                    -- The reward's item level is the thing you actually
                    -- want off an unlocked slot; the count that earned it
                    -- stops mattering the moment it is earned.
                    local lvl = tonumber(slot.level)
                    tile.state:SetText(lvl and lvl > 0
                        and ("|cff6ee88a+%d|r"):format(lvl)
                        or "|cff6ee88aunlocked|r")
                    tile.stripe:SetAlpha(0.85)
                else
                    tile.state:SetText(("|cffffffff%d|r|cff8a8a92/%d|r")
                        :format(progress, threshold))
                    tile.stripe:SetAlpha(progress > 0 and 0.5 or 0.18)
                end
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

    ui.empty:SetShown(shown == 0)
    if shown == 0 then
        ui.empty:SetText(plan and "Nothing pressing. Go and press something."
            or "|cff888888The planner has not run yet.|r")
    end

    ------------------------------------------------------------
    -- This week
    ------------------------------------------------------------
    local w = (ctx and ctx.width or ui.host:GetWidth() or 0) - PAD * 2
    if w > 60 then
        ui.stats:ClearAllPoints()
        ui.stats:SetWidth(w)
        ui.stats:SetPoint("TOPLEFT", ui.statTitle, "BOTTOMLEFT", 0, -10)
        ui.stats:Layout()
    end

    local keyName, keyLevel
    if C_MythicPlus and C_MythicPlus.GetOwnedKeystoneMapID then
        local mapID = C_MythicPlus.GetOwnedKeystoneMapID()
        if mapID and C_ChallengeMode then
            keyName = C_ChallengeMode.GetMapUIInfo(mapID)
            keyLevel = C_MythicPlus.GetOwnedKeystoneLevel
                and C_MythicPlus.GetOwnedKeystoneLevel()
        end
    end
    ui.stats.cells[1]:SetValue(keyName and ("+" .. (keyLevel or 0) .. " " .. keyName)
        or "no key", keyName and "text" or "muted")

    -- Vault slots earned, from the snapshot already read above. No new
    -- API call, and it cannot be blank the way rating was for anyone who
    -- has not run a key this season.
    local dash = string.char(226, 128, 148)
    local unlocked, slots = 0, 0
    if type(snap) == "table" then
        for _, def in ipairs(VAULT_ROWS) do
            local track = snap[def.key]
            if type(track) == "table" then
                unlocked = unlocked + (tonumber(track.filled) or 0)
                slots = slots + (tonumber(track.total) or 0)
            end
        end
    end
    ui.stats.cells[2]:SetValue(
        slots > 0 and ("%d of %d"):format(unlocked, slots) or dash,
        unlocked > 0 and "text" or "muted")

    local left = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
        and C_DateAndTime.GetSecondsUntilWeeklyReset()
    if left and left > 0 then
        -- Floored rather than left to %d: whole days and hours is the
        -- intent, and a float reaching %d is an error in newer Lua even
        -- though the client's 5.1 quietly truncates it.
        ui.stats.cells[3]:SetValue(("%dd %dh"):format(
            math.floor(left / 86400), math.floor((left % 86400) / 3600)))
    else
        ui.stats.cells[3]:SetValue("\226\128\148", "muted")
    end
end

Shell:RegisterPage({
    id = "home", label = "Dashboard", order = 0,
    accent = { 0.45, 0.85, 1.0 },
    Build = function(host) Build(host) end,
    Refresh = Refresh,
})
