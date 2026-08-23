local _, ns = ...

------------------------------------------------------------
-- Finding out which of our own functions ate the frame.
--
-- Written after a freeze that only happened after a loading screen and
-- only with this addon enabled. Nothing in the usual toolkit helps with
-- that: a hang throws no error, so !BugGrabber has nothing to catch, and
-- SavedVariables are only flushed on a clean exit -- so anything written
-- for a post-mortem is lost the moment the player has to kill the
-- client.
--
-- What IS available is the frame before the bad one. A stall is almost
-- never instantaneous: it builds as the same work gets more expensive,
-- and the calls either side of it are visible to anything counting. So
-- this counts.
--
-- Two things are recorded per wrapped function: how long it took, and
-- how many times it was called. The second is the one that found the
-- real problem here -- a single panel draw asking the client for a
-- slot's item 1285 times is not slow because any one call is slow.
--
-- Deliberately off unless asked for, and persisted when it is, because
-- the window worth watching is the one right after a reload and there is
-- no way to switch this on during it.
------------------------------------------------------------

local Trace = {
    on      = false,
    stats   = {},   -- [label] = { calls, ms, worst }
    current = nil,  -- what we are inside, if anything is mid-call
    depth   = 0,
    -- Milliseconds spent inside our own wrapped code since the last
    -- frame the watchdog saw, and the biggest single contributor to it.
    -- See the watchdog below for why `current` alone was useless.
    frameOurs = 0,
    frameTop  = nil,
    frameTopMs = 0,
}
ns.Trace = Trace

--- Anything slower than this gets said out loud, not just counted.
---
--- 50ms is about three frames at 60fps: slow enough that nobody hits it
--- by accident, fast enough to catch the thing while it is still merely
--- bad rather than once it has become a freeze.
local LOUD_MS = 50

--- The frame watchdog's own threshold, which has to be much higher.
---
--- The frames right after a loading screen are legitimately long -- the
--- client is streaming a zone -- so 50ms there would print a wall of
--- noise on every load and bury the one line worth reading. A quarter of
--- a second is past anything normal, and anything that deserves the word
--- "freeze" clears it by an order of magnitude.
local STALL_MS = 250

--- ...and the point where it stops being a stutter and starts being the
--- thing we are hunting.
local FREEZE_MS = 2000

local function Stat(label)
    local s = Trace.stats[label]
    if not s then
        s = { calls = 0, ms = 0, worst = 0 }
        Trace.stats[label] = s
    end
    return s
end

------------------------------------------------------------
-- Wrapping.
--
-- Done at PLAYER_LOGIN rather than at file scope: most of these do not
-- exist yet while this file is being read, and a wrapper installed over
-- a nil is just a nil with extra steps.
--
-- The wrapper stays installed whether tracing is on or not. Swapping
-- functions in and out at runtime means a caller that captured the old
-- one keeps calling it, and the cost when off is a boolean test.
------------------------------------------------------------
local function Wrap(owner, key, label)
    local real = owner and owner[key]
    if type(real) ~= "function" then return false end

    owner[key] = function(...)
        if not Trace.on then return real(...) end

        local parent = Trace.current
        Trace.current = label
        Trace.depth = Trace.depth + 1
        local started = debugprofilestop()

        -- No pcall: it would swallow errors this addon needs to see, and
        -- Lua 5.1 cannot yield across one -- which would break the loot
        -- scanner's coroutine the moment it was traced.
        local a, b, c, d = real(...)

        local took = debugprofilestop() - started
        Trace.depth = Trace.depth - 1
        Trace.current = parent

        local s = Stat(label)
        s.calls = s.calls + 1
        -- Only the outermost frame's time is added to the total. Nested
        -- calls are already inside their parent's clock, and summing
        -- both makes a report where the percentages add up to 400%.
        if Trace.depth == 0 then
            s.ms = s.ms + took
            Trace.frameOurs = Trace.frameOurs + took
            if took > Trace.frameTopMs then
                Trace.frameTopMs, Trace.frameTop = took, label
            end
        end
        if took > s.worst then s.worst = took end

        if took >= LOUD_MS and Trace.depth == 0 then
            print(string.format(
                "|cff00ff00YippYapp|r |cffff8800trace|r: %s took %.0fms",
                label, took))
        end
        return a, b, c, d
    end
    return true
end

------------------------------------------------------------
-- Naming work that is not a function on `ns`.
--
-- The wrap list can only reach things hanging off the namespace, and the
-- most expensive stretch in the addon is not one: the loot sweep runs
-- inside a coroutine driven by an OnUpdate script, and the cache it
-- builds is a file-local. So the first real stall this caught -- nine
-- and a half seconds -- reported "not inside anything we wrap", which
-- was true and useless.
------------------------------------------------------------

--- Time a block and name it. For code that runs to completion.
---
--- No pcall anywhere near this: Lua 5.1 cannot yield across a C call,
--- and the first thing this is used on is a coroutine driver.
function Trace:Section(label, fn, ...)
    if not self.on then return fn(...) end

    local parent = self.current
    self.current = label
    self.depth = self.depth + 1
    local started = debugprofilestop()

    local a, b, c, d = fn(...)

    local took = debugprofilestop() - started
    self.depth = self.depth - 1
    self.current = parent

    local s = Stat(label)
    s.calls = s.calls + 1
    if self.depth == 0 then
        s.ms = s.ms + took
        self.frameOurs = self.frameOurs + took
        if took > self.frameTopMs then
            self.frameTopMs, self.frameTop = took, label
        end
    end
    if took > s.worst then s.worst = took end
    if took >= LOUD_MS and self.depth == 0 then
        print(string.format(
            "|cff00ff00YippYapp|r |cffff8800trace|r: %s took %.0fms",
            label, took))
    end
    return a, b, c, d
end

--- Name a stretch WITHOUT timing it, for code that yields.
---
--- A coroutine's elapsed time spans every frame it was parked across, so
--- timing it reports the wall clock rather than the work. What is worth
--- having is the label: the frame watchdog reads `current`, so a stall
--- inside a parked sweep still says which stretch it was in.
function Trace:Mark(label)
    local parent = self.current
    self.current = label
    return parent
end

function Trace:Unmark(parent)
    self.current = parent
end

--- Everything worth suspecting when the client stalls after a load.
---
--- Ordered roughly outside-in, so a report reads as a call tree: the
--- panel draws first, then what they spend their time in.
local TARGETS = {
    { "RefreshSuggestions",      "panel: suggestions" },
    { "RefreshAllSlots",         "panel: slots"       },
    { "RefreshCrests",           "panel: crests"      },
    { "RefreshGearViews",        "panel: gear views"  },
    { "RefreshMythicPlus",       "panel: mythic+"     },
    { "GetAllRecommendations",   "advice: all slots"  },
    { "GetRankedRecommendations","advice: ranked"     },
    { "GetCrestPlan",            "crest: plan"        },
    { "GetSeasonDemand",         "crest: season bill" },
    { "GetGearCensus",           "gear: census"       },
    { "GetTrackPolicy",          "gear: track policy" },
    -- The one that was actually the problem. Cheap per call and asked
    -- for over a thousand times per draw, which is only visible as a
    -- count.
    { "GetSlotInfo",             "gear: slot read"    },
    { "CanUpgradeItem",          "gear: can upgrade"  },
    { "GetBagSpares",            "bags: spares"       },
    { "GetFreeUpgradeIlvl",      "gear: watermark"    },
    { "GetInstanceCache",        "loot: instances"    },
    { "ScanLootBrowserSlot",     "loot: slot scan"    },
    -- Added after a 9.6s stall reported "not inside anything we wrap".
    -- These two redraw off item data streaming in, which is exactly what
    -- a bag full of new loot produces.
    { "LootBrowser_RefreshDisplay", "loot: redraw"    },
    { "RefreshWatermarks",       "gear: watermarks"   },
    -- Added after stalls of 3.6s and 6.1s landed on "Party converted to
    -- Raid" and an LFR zone-in rather than on a plain loading screen.
    -- Nothing on the raid path was being watched, which is why those
    -- also came back as "not inside anything we wrap".
    { "RefreshRaidPage",         "raid: page"         },
    { "RefreshRaidOverview",     "raid: overview"     },
    { "RefreshRaidDisplay",      "raid: display"      },
    { "RefreshRaidGroups",       "raid: groups"       },
    { "ScanRaid",                "raid: inspect scan" },
    { "GetSortedTierData",       "raid: tier sort"    },
    { "GetTierSummary",          "raid: tier summary" },
    { "BroadcastKeystone",       "m+: keystone send"  },
}

------------------------------------------------------------
-- The frame watchdog.
--
-- Catches the stall that happens somewhere NOT on the list above. An
-- OnUpdate cannot fire during a hang -- that is the whole nature of one
-- -- but it does fire on the frame after, and the gap it measures is how
-- long the frame before it took.
--
-- It cannot see inside a loop that never ends. Nothing in Lua can; for
-- that the only tool is bisecting the .toc between restarts.
------------------------------------------------------------
local watchdog = CreateFrame("Frame")
local lastFrameAt = nil

-- Hidden until tracing is switched on. A parentless frame is SHOWN by
-- default, so this used to run its handler on every frame of every
-- session just to read a boolean and return -- a diagnostic that is
-- supposed to cost nothing when off, quietly costing something. Trace
-- itself would never have caught it: it does not wrap its own watchdog.
watchdog:Hide()

watchdog:SetScript("OnUpdate", function()
    if not Trace.on then
        lastFrameAt = nil
        return
    end
    local now = debugprofilestop()
    if lastFrameAt then
        local gap = now - lastFrameAt
        if gap >= STALL_MS then
            local s = Stat("(frame)")
            s.calls = s.calls + 1
            if gap > s.worst then s.worst = gap end

            ------------------------------------------------------------
            -- How much of that frame was OURS, not where we were.
            --
            -- This used to print Trace.current, and that was worse than
            -- nothing: an OnUpdate runs BETWEEN frames, after every
            -- wrapped call has already returned and put `current` back
            -- to nil. So it said "not inside anything we wrap" every
            -- single time, by construction, and a whole afternoon of
            -- stalls got read as evidence that the addon was innocent.
            --
            -- A running total cannot lie the same way. Every wrapped
            -- call adds its own elapsed time as it finishes, so whatever
            -- ran during the frame that just stalled is still counted
            -- when the next frame finally arrives.
            ------------------------------------------------------------
            local ours = Trace.frameOurs
            local share = gap > 0 and (ours / gap * 100) or 0
            local blame
            if ours < 1 then
                blame = " |cff888888— none of it ours|r"
            else
                blame = string.format(
                    " |cffffffff— %.0fms of it ours (%.0f%%)%s|r",
                    ours, share,
                    Trace.frameTop and (", worst " .. Trace.frameTop) or "")
            end
            print(string.format(
                "|cff00ff00YippYapp|r |cff%s%s|r: a frame took %.0fms%s",
                gap >= FREEZE_MS and "ff4444" or "ff8800",
                gap >= FREEZE_MS and "STALL" or "trace",
                gap, blame))
        end
    end
    Trace.frameOurs, Trace.frameTop, Trace.frameTopMs = 0, nil, 0
    lastFrameAt = now
end)

------------------------------------------------------------
-- Reporting.
------------------------------------------------------------
function Trace:Report()
    local rows = {}
    for label, s in pairs(self.stats) do
        rows[#rows + 1] = { label = label, calls = s.calls, ms = s.ms, worst = s.worst }
    end
    if #rows == 0 then
        print("|cff00ff00YippYapp|r trace: nothing recorded yet."
            .. (self.on and "" or " Tracing is off — /yh trace on"))
        return
    end
    -- By total time, then by call count: the two ways a function ends up
    -- being the problem, and a report sorted by only one of them hides
    -- the other.
    table.sort(rows, function(a, b)
        if a.ms ~= b.ms then return a.ms > b.ms end
        return a.calls > b.calls
    end)

    print("|cff00ff00YippYapp|r trace — total ms, calls, worst single call:")
    for i, r in ipairs(rows) do
        if i > 15 then
            print(string.format("  |cff888888…and %d more|r", #rows - 15))
            break
        end
        print(string.format(
            "  |cffffffff%-22s|r %7.0fms  %6d calls  worst %5.0fms",
            r.label, r.ms, r.calls, r.worst))
    end
end

function Trace:Reset()
    wipe(self.stats)
    self.current, self.depth = nil, 0
end

function Trace:SetEnabled(on)
    self.on = on and true or false
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.trace = self.on or nil
    -- The frame watchdog only measures frames while it is on screen.
    if self.on then watchdog:Show() else watchdog:Hide() end
    if self.on then
        self:Reset()
        print("|cff00ff00YippYapp|r trace |cff00ff00on|r — survives a /reload, so "
            .. "reload now and let the loading screen finish.")
        print("  Anything over " .. LOUD_MS .. "ms says so as it happens. "
            .. "|cffffffff/yh trace report|r for the totals, "
            .. "|cffffffff/yh trace off|r when done.")
    else
        print("|cff00ff00YippYapp|r trace |cffff8800off|r.")
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    local wrapped = 0
    for _, t in ipairs(TARGETS) do
        if Wrap(ns, t[1], t[2]) then wrapped = wrapped + 1 end
    end
    Trace._wrapped = wrapped

    -- Restored before anything has had a chance to run, which is the
    -- point: the window worth watching is the one right after a reload,
    -- and there is no way to switch this on during it.
    if YippYappHelperDB and YippYappHelperDB.trace then
        Trace.on = true
        watchdog:Show()
        Trace:Reset()
        print("|cff00ff00YippYapp|r trace is |cff00ff00on|r ("
            .. wrapped .. " functions). |cffffffff/yh trace report|r")
    end
end)

------------------------------------------------------------
-- The load gate.
--
-- Tracing tells you what is slow. It cannot tell you anything about a
-- loop that never returns -- the print never reaches the screen and the
-- watchdog never gets another frame. And the usual fallback, writing a
-- breadcrumb for the next login, does not work either: SavedVariables
-- are flushed on a clean exit, and a client that has to be killed never
-- has one. Anything this session learns about its own death is lost with
-- it.
--
-- What DOES survive is a flag set before the freeze, because the
-- /reload that triggers it flushes the file on the way out. So the gate
-- is set once, and from then on the addon starts quiet: everything
-- expensive that normally runs itself a few seconds after a loading
-- screen is held back and given a name instead.
--
-- Then each one is run by hand, from a client that is already up, with
-- no reload between tries. Whichever command does not come back is the
-- one. That is the whole bisect in a single session rather than one
-- restart per guess.
------------------------------------------------------------
local gates, gateOrder = {}, {}

--- Register a piece of load-time work under a name.
---
--- Returns true when the caller should go ahead and run it now, false
--- when the gate is holding it for `/yh loadtest`. Written as a
--- question rather than a wrapper so a caller can keep its own timers
--- and arguments instead of surrendering them to this file.
--- `busy` is optional and reports whether the job's asynchronous tail is
--- still running. Without it a job that hands off to a coroutine, a
--- timer or the network returns instantly and reads as costing nothing
--- -- which is exactly what the first version of this reported for all
--- three of its jobs, and the reason it was worse than useless: it said
--- innocent about work it had not waited for.
function ns.LoadGateOpen(name, fn, busy, cold)
    if not gates[name] then gateOrder[#gateOrder + 1] = name end
    gates[name] = { run = fn, busy = busy, cold = cold }

    local db = YippYappHelperDB
    if not db then return true end
    -- "Only this one, at load" beats the blanket hold. This is the mode
    -- that answers the question the by-hand one cannot: it lets the job
    -- run where it normally runs, under the conditions it normally runs
    -- under, with every other job still held back.
    if db.loadOnly then return db.loadOnly == name end
    return not db.deferLoad
end

function ns.LoadGateList()
    return gateOrder, gates
end

--- Run one held-back piece of work, or say what there is.
function ns.LoadGateRun(name)
    if not name or name == "" then
        local held = YippYappHelperDB and YippYappHelperDB.deferLoad
        print("|cff00ff00YippYapp|r load work "
            .. (held and "|cffff8800held back|r" or "|cff00ff00running normally|r")
            .. ". Names:")
        for _, n in ipairs(gateOrder) do
            print("  |cffffffff/yh loadtest " .. n .. "|r")
        end
        if not held then
            print("  |cff888888Nothing is being held. |r|cffffffff/yh loadtest defer|r"
                .. "|cff888888, then /reload and restart.|r")
        end
        return
    end

    if name == "defer" or name == "on" then
        YippYappHelperDB = YippYappHelperDB or {}
        YippYappHelperDB.deferLoad = true
        YippYappHelperDB.loadOnly = nil
        print("|cff00ff00YippYapp|r load work will be |cffff8800held back|r from now on.")
        print("  |cffffffff/reload|r now — that writes the setting. If the reload "
            .. "itself still freezes, the cause is not on this list.")
        return
    end
    if name == "off" then
        YippYappHelperDB = YippYappHelperDB or {}
        YippYappHelperDB.deferLoad = nil
        YippYappHelperDB.loadOnly = nil
        print("|cff00ff00YippYapp|r load work runs normally again after the next reload.")
        return
    end

    ------------------------------------------------------------
    -- The mode that actually reproduces a loading screen.
    --
    -- Running a job by hand does not, and cannot: by then the caches it
    -- fills are already full, the journal has settled, item data has
    -- arrived and nothing else is competing for the frame. The loot
    -- sweep settling in 0.2s when a cold one takes seconds is that
    -- difference, measured.
    --
    -- So this lets exactly one job run where it normally runs, at the
    -- moment it normally runs, with the rest still held. One reload per
    -- job, three jobs -- and unlike the by-hand version, a freeze here
    -- is the real thing rather than an imitation of it.
    ------------------------------------------------------------
    local onlyName = name:match("^only%s+(%S+)$") or (name == "only" and "")
    if onlyName then
        if onlyName == "" or not gates[onlyName] then
            print("|cff00ff00YippYapp|r which one? |cffffffff/yh loadtest only "
                .. "<name>|r — " .. table.concat(gateOrder, ", "))
            return
        end
        YippYappHelperDB = YippYappHelperDB or {}
        YippYappHelperDB.deferLoad = true
        YippYappHelperDB.loadOnly = onlyName
        print("|cff00ff00YippYapp|r next load runs |cffffffff" .. onlyName
            .. "|r and nothing else.")
        print("  |cffffffff/reload|r now. If it freezes, that is the one. If it "
            .. "does not, |cffffffff/yh loadtest only <next>|r and reload again.")
        return
    end

    local job = gates[name]
    if not job then
        print("|cff00ff00YippYapp|r no load work called '" .. name
            .. "'. |cffffffff/yh loadtest|r for the list.")
        return
    end

    ------------------------------------------------------------
    -- Watch the whole job, not just the call.
    --
    -- Every one of these hands off -- to a coroutine, to a timer, to the
    -- network -- so the call itself always returns immediately and the
    -- cost lands afterwards. Timing the call measured nothing and
    -- reported 0ms for all three, which is the worst thing a diagnostic
    -- can do: clear them.
    --
    -- So tracing is switched on for the duration and the frame watchdog
    -- does the actual work. A job whose tail stalls the client shows up
    -- as a long frame while we are waiting on it, whether or not anyone
    -- knew where to look.
    ------------------------------------------------------------
    local wasTracing = Trace.on
    Trace.on = true
    -- The watchdog is hidden while tracing is off, and this measurement
    -- IS the watchdog -- see the comment above. Show it for the run.
    watchdog:Show()
    Trace:Reset()

    -- Emptied first, or the job finds its own caches already full and
    -- measures the cost of discovering there is nothing to do. This is
    -- still not a loading screen -- see `only` above -- but it is at
    -- least the same amount of work.
    if job.cold then job.cold() end

    print("|cff00ff00YippYapp|r running |cffffffff" .. name
        .. "|r — watching until it settles ...")
    print("  |cff888888(not a real loading screen: caches are cleared but the "
        .. "client is idle and settled. |r|cffffffff/yh loadtest only " .. name
        .. "|r|cff888888 reloads into the real thing.)|r")
    local started = debugprofilestop()
    job.run()
    local returned = debugprofilestop() - started

    local WAIT_MAX = 20
    local elapsed = 0
    local function settle()
        local worst = Trace.stats["(frame)"]
        local worstMs = worst and worst.worst or 0
        Trace.on = wasTracing
        if not wasTracing then watchdog:Hide() end
        print(string.format(
            "|cff00ff00YippYapp|r %s: call returned in %.0fms, settled after "
            .. "%.1fs. Worst frame while waiting: %.0fms.",
            name, returned, elapsed, worstMs))
        if worstMs >= 100 then
            print("  |cffff8800That is a visible stutter. If the client had "
                .. "more to do than this fixture, it is a candidate.|r")
        end
    end

    if not job.busy then
        -- Nothing to poll, so give the tail a moment to land and report
        -- what the watchdog saw rather than pretending the job is done.
        C_Timer.After(3, function() elapsed = 3 settle() end)
        return
    end

    local ticker
    ticker = C_Timer.NewTicker(0.25, function()
        elapsed = elapsed + 0.25
        if not job.busy() or elapsed >= WAIT_MAX then
            ticker:Cancel()
            settle()
        end
    end)
end
