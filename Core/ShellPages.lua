local _, ns = ...

------------------------------------------------------------
-- The pages, on the shell contract.
--
-- Eight of the nine already followed one pattern: a standalone frame,
-- an app-mode setter that resizes it, and a refresh. That is a page
-- definition with different words, so they are adapted here rather than
-- rewritten in place -- eight files edited at once is eight chances to
-- break something, and none of them needs to change to satisfy the
-- contract.
--
-- Trinkets is the exception and registers itself, because it was the
-- migration that proved the contract and its controls genuinely moved
-- into shell furniture. The rest keep drawing their own insides for
-- now; the contract only asks them to stop deciding where they live.
--
-- Rewriting their internals is the layout redesign, and it happens one
-- page at a time against a shell that already works.
------------------------------------------------------------

local Shell = ns.Shell
if not Shell then return end

--- A page whose frame is built elsewhere and reparented into ours.
---
--- `frameKey` is looked up on ns at Build time, not now: several of
--- these frames are created lazily on first use, and capturing nil at
--- load would leave the page permanently blank.
local function Adapt(def)
    Shell:RegisterPage({
        id       = def.id,
        label    = def.label,
        accent   = def.accent,
        order    = def.order,
        subTabs  = def.subTabs,
        -- Forwarded so an adapted page can act on a sub-tab
        -- change. Without it the shell drew the strip and
        -- clicking a tab did nothing.
        OnSubTab = def.OnSubTab,

        Build = function(host)
            if def.create and not ns[def.frameKey] then
                local fn = ns[def.create]
                if type(fn) == "function" then fn(ns) end
            end
            local f = ns[def.frameKey]
            if not f then return end

            -- Mounting this page is what makes the window protected --
            -- its tiles are SecureActionButtonTemplate frames, and a
            -- frame holding a protected frame is protected itself -- so
            -- it is also the moment the window needs a way to close
            -- during a fight. See the note in Core\ShellFrame.lua.
            if def.secure and Shell.EnableCombatClose then
                Shell:EnableCombatClose()
            end

            f.inAppMode = true
            if def.appMode and type(ns[def.appMode]) == "function" then
                if def.sizeless then
                    ns[def.appMode](ns, true)
                else
                    ns[def.appMode](ns, true, host:GetWidth(), host:GetHeight())
                end
            end
            f:SetParent(host)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
            f:Show()
        end,

        Refresh = function(ctx)
            local f = ns[def.frameKey]
            if f then
                -- Re-anchored on every refresh because the host can
                -- change size: the shell resizes with the window, and a
                -- frame anchored once at build time keeps the width it
                -- was born with.
                f:SetParent(ctx.content)
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", 0, 0)
                if def.appMode and type(ns[def.appMode]) == "function" then
                    if def.sizeless then
                        -- Progression sizes itself from its parent and
                        -- takes no dimensions.
                        ns[def.appMode](ns, true)
                    else
                        ns[def.appMode](ns, true, ctx.width, ctx.height)
                    end
                end
                f:Show()
            end
            if def.refresh and type(ns[def.refresh]) == "function" then
                ns[def.refresh](ns)
            end
            for _, extra in ipairs(def.also or {}) do
                if type(ns[extra]) == "function" then ns[extra](ns) end
            end
        end,
    })
end

-- Gear Upgrades registers itself in Features/Gear/GearPage.lua.
--
-- It was adapted here like the rest, reparenting ns.MainFrame into the
-- content region. That frame is a 440x500 paper doll whose height binds
-- before its width in a 700x480 region, so it could never fill the
-- shell however it was scaled. The shell version is a separate page
-- built from the same data; ns.MainFrame stays as the standalone window
-- and the upgrade-vendor frame, where its proportions are right.


------------------------------------------------------------
-- Best in Slot draws straight into the host rather than owning a frame,
-- so it registers directly instead of going through Adapt.
------------------------------------------------------------
Shell:RegisterPage({
    id = "bis", label = "Best in Slot", order = 20,
    accent = { 0.45, 1.0, 0.55 },
    -- The doll is 300 and its list needs the rest. This is the page
    -- that sets the floor every other page is measured against.
    minWidth = 700,
    Build = function(host)
        if ns.BisUI and ns.BisUI.BuildInto then ns.BisUI:BuildInto(host) end
    end,
    Refresh = function(ctx)
        -- ctx forwarded so the page can size to the region. Refresh
        -- reads it off its own content frame, but passing it keeps the
        -- page honest about where its dimensions come from.
        -- Named for the tracer. BisUI hangs its render off its own
        -- table rather than off `ns`, so the wrap list never saw it --
        -- and opening this tab inside a raid finder group was reported
        -- as a freeze that traced to "not inside anything we wrap".
        if ns.BisUI and ns.BisUI.Refresh then
            if ns.Trace and ns.Trace.on then
                ns.Trace:Section("bis: refresh", function()
                    ns.BisUI:Refresh(ctx)
                end)
            else
                ns.BisUI:Refresh(ctx)
            end
        end
    end,
})

-- Trinkets registers itself in Features/Trinkets/TrinketUI.lua, at
-- order 30, because unlike these it genuinely moved its controls into
-- the shell's strips.

Adapt({
    id = "consumables", label = "Consumables", order = 40,
    accent = { 1.0, 0.0, 1.0 },
    frameKey = "ConsumablesFrame",
    create = "CreateConsumablesFrame",
    appMode = "SetConsumablesAppMode",
    refresh = "RefreshConsumables",
    subTabs = function()
        return ns.GetConsumablesTabs and ns:GetConsumablesTabs() or nil
    end,
    OnSubTab = function(id)
        if ns.SetConsumablesTab then ns:SetConsumablesTab(id) end
    end,
})

Adapt({
    id = "progression", label = "Progression", order = 50,
    accent = { 1.0, 1.0, 0.0 },
    frameKey = "ProgressionFrame",
    create = "CreateProgressionFrame",
    appMode = "SetProgressionAppMode",
    -- Lays itself out from whatever it is parented to, and takes no
    -- dimensions.
    sizeless = true,
})

Adapt({
    id = "loot", label = "Loot Browser", order = 60,
    accent = { 0.0, 0.8, 1.0 },
    frameKey = "LootBrowserFrame",
    create = "CreateLootBrowserFrame",
    appMode = "SetLootBrowserAppMode",
    refresh = "LootBrowser_ShowPage",
    subTabs = function()
        return ns.GetLootBrowserTabs and ns:GetLootBrowserTabs() or nil
    end,
    OnSubTab = function(id)
        if ns.LootBrowser_SwitchView then ns:LootBrowser_SwitchView(id) end
    end,
})

Adapt({
    -- Secure: its dungeon teleport tiles are action buttons.
    secure = true,
    id = "mythicplus", label = "Mythic+", order = 70,
    accent = { 0.0, 0.83, 1.0 },
    frameKey = "MythicPlusFrame",
    appMode = "SetMythicPlusAppMode",
    refresh = "RefreshMythicPlus",
    -- Home / Guild move onto the shell's strip. The page drew its own a
    -- few pixels from where the shell puts one, which is two tab rows on
    -- one screen and exactly what the contract exists to stop.
    subTabs = function()
        return ns.GetMythicPlusTabs and ns:GetMythicPlusTabs() or nil
    end,
    OnSubTab = function(id)
        if ns.SetMythicPlusTab then ns:SetMythicPlusTab(id) end
    end,
})

Adapt({
    id = "raid", label = "Raid", order = 80,
    accent = { 0.0, 0.67, 1.0 },
    frameKey = "RaidFrame",
    appMode = "SetRaidAppMode",
    -- Dispatches on the active sub-tab rather than always redrawing the
    -- roster. See ns:RefreshRaidPage in Features\Raid\RaidUI.lua.
    refresh = "RefreshRaidPage",
    subTabs = function()
        return ns.GetRaidPageTabs and ns:GetRaidPageTabs() or nil
    end,
    OnSubTab = function(id)
        if ns.SetRaidPageTab then ns:SetRaidPageTab(id) end
    end,
})

Adapt({
    -- Secure: its dungeon teleport tiles are action buttons.
    secure = true,
    id = "teleports", label = "Teleports", order = 90,
    accent = { 0.53, 0.8, 1.0 },
    frameKey = "TeleportFrame",
    appMode = "SetTeleportAppMode",
    refresh = "RefreshTeleports",
})
