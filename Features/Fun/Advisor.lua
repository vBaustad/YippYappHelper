local _, ns = ...

------------------------------------------------------------
-- The advisor: reasoning, then a voice.
--
-- This is not a list of jokes. It builds a snapshot of what is actually
-- true right now -- which slots can be upgraded, what each would cost,
-- what crests are on hand, what is being wasted -- and then works out
-- which single fact is worth saying. The personality is applied last, to
-- a conclusion that was reached on evidence.
--
-- Structure:
--   Snapshot()  gathers facts. No opinions, no text.
--   RULES       each one recognises a situation and, if it applies,
--               returns a priority and a line. Rules may compute.
--   Speak()     evaluates every rule, takes the highest priority, and
--               renders it.
--
-- The priority ordering is the actual design work: the bot should say
-- the most *useful* true thing, not the funniest one. A joke about
-- jumping is worthless while 200 crests rot in a bag.
------------------------------------------------------------

ns.Advisor = ns.Advisor or {}
local AD = ns.Advisor

--- Rules and asides may return a bare string or { text = , tips = }.
--- Normalising here keeps each entry readable at its own definition
--- instead of forcing every one-liner into a table.
local function asMessage(v)
    if type(v) == "string" then return { text = v } end
    if type(v) == "table" and v.text then return v end
end

------------------------------------------------------------
-- Snapshot
------------------------------------------------------------

------------------------------------------------------------
-- How new is he?
------------------------------------------------------------
-- Yeeper's best material is meta -- "you have opened this forty times",
-- "four unenchanted slots and 80k gold". All of it is wrong in the first
-- few minutes after an update, and wrong in a specific way that makes
-- him look broken rather than rude:
--
--   * Counters restart, so "you keep coming back" is said to someone on
--     their second visit.
--   * At a season start EVERY player is in last season's gear with no
--     enchants and no crests. Shouting about it is not an observation,
--     it is a description of the patch.
--
-- So the first few opens on a new version get their own material, and
-- the nags stay quiet until there is something worth nagging about.
local INTRO_STEPS = 6

-- The introduction is paced by TIME, not by clicks. Counting opens meant
-- six impatient clicks burned the whole thing in ten seconds, which is
-- both a waste and exactly what it was written to avoid: an introduction
-- should unfold across the first few sessions, not the first ten
-- seconds of one.
--
-- So a step advances when the panel is opened either for the first time
-- this session, or at least this long after the last one.
local INTRO_GAP = 20 * 60

-- Resets on reload or login, which is what "a new session" means here.
local shownThisSession = false
-- Whether THIS open should carry an intro line. Spamming the panel
-- inside the gap falls through to normal material rather than repeating
-- the same introduction at someone who just read it.
local introDue = false

--- Called when the dashboard opens. Tracked per addon version, so the
--- introduction replays after an update -- a returning player has as
--- little context about what changed as a new one does.
function AD:NoteOpen()
    YippYappHelperDB = YippYappHelperDB or {}
    local st = YippYappHelperDB.introState
    local version = ns.ADDON_VERSION or "?"
    if not st or st.version ~= version then
        st = { version = version, step = 0, firstSeen = time() }
        YippYappHelperDB.introState = st
    end

    local now = time()
    local finished = (st.step or 0) >= INTRO_STEPS
    local paced = (not shownThisSession)
        or (now - (st.lastStep or 0)) >= INTRO_GAP

    if not finished and paced then
        st.step = (st.step or 0) + 1
        st.lastStep = now
        shownThisSession = true
        introDue = true
    else
        introDue = false
    end
end

------------------------------------------------------------
-- Repair spend
------------------------------------------------------------
-- Durability itself is a non-event in retail -- everyone auto-repairs,
-- so the bar never gets low enough to be interesting. What IS
-- interesting is the bill: gold spent repairing is the running cost of
-- wiping, and set against what you got for it, it is the single most
-- deserved insult in the game.
--
-- Attribution is deliberately narrow. GetRepairAllCost() is only
-- meaningful with a merchant open, so the cost is recorded on
-- MERCHANT_SHOW and only banked when durability actually improves during
-- that same visit. Buying something without repairing therefore counts
-- for nothing, which is the failure mode worth avoiding: a wrong number
-- here is worse than none, because the whole joke is the number.
local pendingRepair = 0

local function RepairDB()
    YippYappHelperDB = YippYappHelperDB or {}
    local r = YippYappHelperDB.repairs
    if not r then
        r = { week = 0, session = 0, weekStamp = 0, lifetime = 0 }
        YippYappHelperDB.repairs = r
    end
    -- Roll the weekly figure over when the reset passes. Stored as the
    -- reset the tally belongs to rather than a duration, so a week away
    -- from the game does not leave a stale total looking current.
    local secs = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
        and select(1, pcall(C_DateAndTime.GetSecondsUntilWeeklyReset))
    if type(secs) ~= "number" then
        secs = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
            and C_DateAndTime.GetSecondsUntilWeeklyReset() or nil
    end
    if type(secs) == "number" and secs > 0 then
        local thisReset = time() + secs
        -- Same reset boundary means same week.
        if math.abs((r.weekStamp or 0) - thisReset) > 3600 then
            r.week, r.weekStamp = 0, thisReset
        end
    end
    return r
end

local repairWatcher = CreateFrame("Frame")
repairWatcher:RegisterEvent("MERCHANT_SHOW")
repairWatcher:RegisterEvent("MERCHANT_CLOSED")
repairWatcher:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
repairWatcher:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
        local ok, cost = pcall(GetRepairAllCost)
        pendingRepair = (ok and type(cost) == "number") and cost or 0
    elseif event == "MERCHANT_CLOSED" then
        pendingRepair = 0
    elseif event == "UPDATE_INVENTORY_DURABILITY" and pendingRepair > 0 then
        -- Durability moved while a merchant was open and a repair was
        -- outstanding: that is the repair happening.
        local r = RepairDB()
        local gold = pendingRepair / 10000
        r.week = (r.week or 0) + gold
        r.session = (r.session or 0) + gold
        r.lifetime = (r.lifetime or 0) + gold
        -- Re-read: a partial repair leaves a remainder still owing.
        local ok, cost = pcall(GetRepairAllCost)
        pendingRepair = (ok and type(cost) == "number") and cost or 0
    end
end)

--- Everything the rules are allowed to reason about. Gathered once per
--- call so a rule cannot see a different world than its neighbour.
function AD:Snapshot()
    local s = {
        upgrades   = {},   -- { slotID, name, track, rank, maxRank, ilvl, maxIlvl, gain, cost }
        stale      = 0,    -- slots with no upgrade track (last season's gear)
        maxed      = 0,
        crests     = {},   -- track -> { have, earnedThisWeek, weeklyMax, capped }
        totalGain  = 0,
        cheapest   = nil,
        biggest    = nil,
    }

    local _, equipped = GetAverageItemLevel()
    s.ilvl = math.floor(equipped or 0)

    local profile = ns.GetCurrentProfile and ns:GetCurrentProfile()
    s.goal = profile and profile.id or "normal"

    -- Gear
    for _, slot in ipairs(ns.SLOT_IDS or {}) do
        local canUp, info, why = ns:CanUpgradeItem(slot.slot)
        if canUp and info then
            local gain = (info.maxIlvl or info.currIlvl) - info.currIlvl
            local cost = ns.GetCrestCost and ns:GetCrestCost(ns.TRACK_CREST
                and ns.TRACK_CREST[info.track] or info.track) or 0
            local entry = {
                slotID = slot.slot, name = slot.name, track = info.track,
                rank = info.currUpgrade, maxRank = info.maxUpgrade,
                ilvl = info.currIlvl, maxIlvl = info.maxIlvl,
                gain = gain, cost = cost,
            }
            table.insert(s.upgrades, entry)
            s.totalGain = s.totalGain + gain
            -- "Cheapest" and "biggest" are what the advice actually hangs
            -- on: one is the efficient move, the other the impatient one.
            if not s.cheapest or cost < s.cheapest.cost then s.cheapest = entry end
            if not s.biggest or gain > s.biggest.gain then s.biggest = entry end
        elseif why == "notrack" then
            s.stale = s.stale + 1
        elseif info then
            s.maxed = s.maxed + 1
        end
    end

    -- Crests
    if ns.GetCrestInfo then
        local ok, list = pcall(ns.GetCrestInfo, ns)
        if ok and type(list) == "table" then
            for _, c in ipairs(list) do
                local weeklyMax = c.weeklyMax or 0
                s.crests[c.track or c.name] = {
                    have = c.quantity or 0,
                    earnedThisWeek = c.earnedThisWeek or 0,
                    weeklyMax = weeklyMax,
                    capped = weeklyMax > 0 and (c.earnedThisWeek or 0) >= weeklyMax,
                }
            end
        end
    end

    -- Can we actually afford what is pending?
    local need = {}
    for _, u in ipairs(s.upgrades) do
        local track = (ns.TRACK_CREST and ns.TRACK_CREST[u.track]) or u.track
        need[track] = (need[track] or 0) + (u.cost or 0)
    end
    s.need = need

    s.affordable, s.shortfall, s.shortTrack = 0, 0, nil
    for track, amount in pairs(need) do
        local have = (s.crests[track] and s.crests[track].have) or 0
        if have < amount then
            local gap = amount - have
            if gap > s.shortfall then s.shortfall, s.shortTrack = gap, track end
        end
    end
    for _, u in ipairs(s.upgrades) do
        local track = (ns.TRACK_CREST and ns.TRACK_CREST[u.track]) or u.track
        local have = (s.crests[track] and s.crests[track].have) or 0
        if have >= (u.cost or 0) then s.affordable = s.affordable + 1 end
    end

    ------------------------------------------------------------
    -- The wider world
    ------------------------------------------------------------
    -- Every call is guarded. These APIs come and go between patches, and
    -- a missing one should cost us a line, not the whole panel.

    local function try(fn, ...)
        local ok, a, b, c = pcall(fn, ...)
        if ok then return a, b, c end
    end

    -- Missing enchants. The second field of an item link is the enchant
    -- id, so a link alone answers this -- no tooltip scanning needed.
    local ENCHANTABLE = {
        [5] = "Chest", [9] = "Wrist", [7] = "Legs", [8] = "Feet",
        [11] = "Ring", [12] = "Ring", [15] = "Cloak", [16] = "Weapon",
    }
    s.unenchanted = {}
    for slot, label in pairs(ENCHANTABLE) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local enchant = link:match("item:%d+:(%d*)")
            if not enchant or enchant == "" or enchant == "0" then
                table.insert(s.unenchanted, label)
            end
        end
    end
    -- Sorted so the list reads the same on consecutive refreshes. pairs()
    -- over ENCHANTABLE has no defined order, so without this the same
    -- character produces "Chest, Legs" and then "Legs, Chest" and the
    -- back-to-back repeat guard sees two different lines.
    table.sort(s.unenchanted)

    ------------------------------------------------------------
    -- Wallet, bags, durability
    ------------------------------------------------------------
    -- All cheap reads, gathered here rather than inline in the rules so
    -- two lines cannot disagree about the same number within one refresh.
    s.gold = math.floor((try(GetMoney) or 0) / 10000)

    -- Being unprepared is a private failing right up until there are
    -- other people relying on you, at which point it is theirs too. The
    -- group state is what separates "you should sort that out" from "you
    -- are doing this to four other people right now".
    local rep = RepairDB()
    s.repairWeek = math.floor(rep.week or 0)
    s.repairSession = math.floor(rep.session or 0)
    s.repairLifetime = math.floor(rep.lifetime or 0)

    s.inGroup = (IsInGroup and IsInGroup()) and true or false
    s.inRaid = (IsInRaid and IsInRaid()) and true or false
    s.groupSize = (GetNumGroupMembers and GetNumGroupMembers()) or 0

    -- Durability is reported per slot; the worst one is what actually
    -- breaks, so the average would understate the problem badly.
    s.durability, s.durabilitySlot = 1, nil
    for _, slot in ipairs(ns.SLOT_IDS or {}) do
        local cur, max = try(GetInventoryItemDurability, slot.slot)
        if cur and max and max > 0 then
            local pct = cur / max
            if pct < s.durability then
                s.durability, s.durabilitySlot = pct, slot.name
            end
        end
    end

    -- No junk count: retail hardly drops greys and everyone runs an
    -- auto-seller, so "you are hoarding rubbish" was a joke about
    -- Wrath.
    s.bagFree, s.bagTotal = 0, 0
    if C_Container then
        for bag = 0, 4 do
            local slots = try(C_Container.GetContainerNumSlots, bag) or 0
            s.bagTotal = s.bagTotal + slots
            s.bagFree = s.bagFree
                + (try(C_Container.GetContainerNumFreeSlots, bag) or 0)
        end
    end

    ------------------------------------------------------------
    -- Sockets, enchants and consumables, against this spec's guide
    ------------------------------------------------------------
    -- The addon knows what this spec SHOULD have (ConsumablesDB, scraped
    -- per spec) and what the character HAS. Comparing the two is the
    -- difference between "you have no enchant" and "your chest wants
    -- Mark of the Worldsoul and you can afford it".
    -- Written long-hand because the compact form is silently broken:
    --
    --     local _, specName = idx and GetSpecializationInfo(idx)
    --
    -- `cond and f()` is an expression, so it is truncated to ONE value
    -- and specName is always nil. Nothing errors; the guide simply never
    -- resolves and every feature hanging off it quietly does nothing.
    -- Same family as `x and nil or y`.
    local specKey
    local _, classFile = UnitClass("player")
    local idx = GetSpecialization and GetSpecialization()
    if classFile and idx then
        local _, specName = GetSpecializationInfo(idx)
        if specName then
            specKey = classFile:upper() .. "_" .. specName:upper():gsub("[^A-Z]", "")
        end
    end
    s.specKey = specKey
    local guide = specKey and ns.ConsumablesDB and ns.ConsumablesDB[specKey]
    s.guide = guide

    -- Empty gem sockets. GetItemStats reports unfilled sockets under
    -- EMPTY_SOCKET_* keys, so their sum is the answer without having to
    -- pick gem fields out of the item link by position.
    s.emptySockets = 0
    if C_Item and C_Item.GetItemStats then
        for _, slot in ipairs(ns.SLOT_IDS or {}) do
            local link = GetInventoryItemLink("player", slot.slot)
            if link then
                local stats = try(C_Item.GetItemStats, link)
                if type(stats) == "table" then
                    for key, count in pairs(stats) do
                        if type(key) == "string" and key:find("EMPTY_SOCKET") then
                            s.emptySockets = s.emptySockets + (count or 0)
                        end
                    end
                end
            end
        end
    end

    -- What the guide wants in the bags, and whether it is there. Answers
    -- "am I actually ready" rather than "do you own gear".
    s.missingConsumables = {}
    if guide and C_Item and C_Item.GetItemCount then
        for _, entry in ipairs(guide.consumables or {}) do
            local have = try(C_Item.GetItemCount, entry.itemID, true) or 0
            if have == 0 and entry.alt and entry.alt.itemID then
                have = try(C_Item.GetItemCount, entry.alt.itemID, true) or 0
            end
            if have == 0 then
                table.insert(s.missingConsumables, entry.label or "?")
            end
        end
    end

    -- Season phase. Patch and season are not the same date: 12.1 opens
    -- with Heroic and Mythic 0 only, and keystones arrive a week later.
    -- Without this he would spend the first week telling people to go and
    -- run keys that do not exist yet.
    s.mplusLive = true
    if ns.SEASON_MPLUS_START then
        s.mplusLive = time() >= ns.SEASON_MPLUS_START
        s.daysToKeys = math.max(0,
            math.ceil((ns.SEASON_MPLUS_START - time()) / 86400))
    end

    -- Mythic+ rating, and the direction of travel.
    if C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore then
        s.mplusScore = math.floor(try(C_ChallengeMode.GetOverallDungeonScore) or 0)
    end
    if C_MythicPlus and C_MythicPlus.GetSeasonBestAffixScoreInfoForMap then
        -- Best-effort only; the previous season's number is not always
        -- exposed, and we would rather say nothing than invent it.
        s.prevScore = ns.PrevSeasonScore
    end

    -- Where keys stop paying in item level (Core/Data.lua). Computed
    -- before the run history so runs can be counted against it.
    s.keyCeiling, s.keyCeilingLoot, s.keyCeilingVault = nil, nil, nil
    if ns.GetKeyGearCeiling then
        local ok, level, loot, vault = pcall(ns.GetKeyGearCeiling, ns)
        if ok and level then
            s.keyCeiling, s.keyCeilingLoot, s.keyCeilingVault = level, loot, vault
        end
    end

    -- Runs this season.
    if C_MythicPlus and C_MythicPlus.GetRunHistory then
        local runs = try(C_MythicPlus.GetRunHistory, false, true)
        if type(runs) == "table" then
            s.runs, s.runsTen, s.runsAtCeiling = #runs, 0, 0
            for _, r in ipairs(runs) do
                if (r.level or 0) >= 10 then s.runsTen = s.runsTen + 1 end
                -- Counted against the derived ceiling rather than a
                -- hardcoded 10, so this stays honest if the table moves.
                if s.keyCeiling and (r.level or 0) > s.keyCeiling then
                    s.runsAtCeiling = s.runsAtCeiling + 1
                end
            end
        end
    end

    -- Vault. Each row keeps its own progress and threshold rather than
    -- being collapsed into a count.
    --
    -- The thresholds come from the game, so nothing built on them can go
    -- stale when Blizzard retunes them -- there is no table here to
    -- forget to update. It also makes a whole class of nonsense
    -- impossible to write by accident: the vault fills from kills and
    -- dungeon completions, so "eleven bosses and an empty vault" is a
    -- state the game will never produce, and anything reasoning from
    -- `vaultFilled` alone cannot tell.
    --
    -- vaultNearest is the unfilled row closest to unlocking, which is
    -- the only one worth mentioning: "one boss off your second slot" is
    -- actionable in a way "two of nine" never is.
    if C_WeeklyRewards and C_WeeklyRewards.GetActivities then
        local acts = try(C_WeeklyRewards.GetActivities)
        if type(acts) == "table" then
            s.vaultFilled, s.vaultTotal = 0, #acts
            s.vaultRows = {}
            for _, a in ipairs(acts) do
                local progress = a.progress or 0
                local threshold = a.threshold or 1
                local row = {
                    kind      = a.type,     -- Enum.WeeklyRewardChestThresholdType
                    index     = a.index,
                    level     = a.level,    -- key level / raid difficulty reached
                    progress  = progress,
                    threshold = threshold,
                    filled    = progress >= threshold,
                    remaining = math.max(threshold - progress, 0),
                }
                table.insert(s.vaultRows, row)
                if row.filled then
                    s.vaultFilled = s.vaultFilled + 1
                elseif not s.vaultNearest or row.remaining < s.vaultNearest.remaining then
                    s.vaultNearest = row
                end
            end
        end
    end

    -- Raid lockouts: how far into the tier, at what difficulty.
    s.raidKills, s.raidTotal, s.raidDiff = 0, 0, nil
    local saved = try(GetNumSavedInstances) or 0
    for i = 1, saved do
        local name, _, _, diffName, locked, _, _, isRaid, _, _, encounters, killed =
            try(GetSavedInstanceInfo, i)
        if isRaid and locked and (killed or 0) >= (s.raidKills or 0) then
            s.raidKills, s.raidTotal, s.raidDiff = killed or 0, encounters or 0, diffName
            s.raidName = name
        end
    end

    -- Social context. This gates whole topics rather than colouring them:
    -- ribbing someone about never grouping with guildmates is only funny
    -- if they have guildmates. Without a guild it is just unkind, so the
    -- lines are not written and then softened -- they are never offered.
    s.inGuild = IsInGuild() and true or false
    if s.inGuild and GetNumGuildMembers then
        local total, online = try(GetNumGuildMembers)
        s.guildSize, s.guildOnline = total or 0, online or 0
    end
    s.guildRuns = (ns.FunStats and ns.FunStats:Get("guildRuns")) or 0
    -- A guild of three that is never online is functionally no guild.
    s.social = s.inGuild and (s.guildSize or 0) >= 5

    -- Idle crests: enough for at least one upgrade, with nothing claimed.
    s.idleTrack, s.idleAmount = nil, 0
    for track, c in pairs(s.crests) do
        if c.have > s.idleAmount and (need[track] or 0) == 0 then
            s.idleTrack, s.idleAmount = track, c.have
        end
    end

    -- Scarce crests about to buy an item level a cheaper crest reaches
    -- (Features/Gear/Recommend.lua, ns:GetCrestWaste). Only the
    -- actionable ones are kept: with no lower-track piece to redirect
    -- the spend onto, the warning is true and useless, and Yeeper
    -- saying true useless things is how he gets closed.
    s.crestWaste, s.crestWasteTotal, s.crestWasteTotals = {}, 0, {}
    -- Sinks are grouped by the crest that pays for them. Two slots can
    -- be wasteful on different tiers at once -- a Myth trinket and a
    -- Hero weapon -- and their sinks are not interchangeable, so a
    -- flat union would offer Champion slots as somewhere to put Hero.
    s.crestWasteSinks = {}
    if ns.GetAllCrestWaste then
        local ok, list = pcall(ns.GetAllCrestWaste, ns)
        if ok and type(list) == "table" then
            local seenSink = {}
            for _, w in ipairs(list) do
                if #w.sinkSlots > 0 then
                    table.insert(s.crestWaste, w)
                    s.crestWasteTotal = s.crestWasteTotal + w.wastedCrests
                    s.crestWasteTotals[w.crestTrack] =
                        (s.crestWasteTotals[w.crestTrack] or 0) + w.wastedCrests

                    local into = w.prevCrestTrack
                    s.crestWasteSinks[into] = s.crestWasteSinks[into] or {}
                    seenSink[into] = seenSink[into] or {}
                    for _, name in ipairs(w.sinkSlots) do
                        if not seenSink[into][name] then
                            seenSink[into][name] = true
                            table.insert(s.crestWasteSinks[into], name)
                        end
                    end
                end
            end
        end
    end
    -- Scarcest crest first, so the exemplar the advice is written around
    -- is the one that actually hurts to lose. Slot name breaks ties to
    -- keep the ordering total -- table.sort rejects anything less.
    table.sort(s.crestWaste, function(a, b)
        local ra = (ns.TRACK_RANK and ns.TRACK_RANK[a.crestTrack]) or 0
        local rb = (ns.TRACK_RANK and ns.TRACK_RANK[b.crestTrack]) or 0
        if ra ~= rb then return ra > rb end
        return (a.slotName or "") < (b.slotName or "")
    end)

    ------------------------------------------------------------
    -- Where we are in the addon's life, and the season's
    ------------------------------------------------------------
    local st = (YippYappHelperDB or {}).introState
    s.introStep = (st and st.step) or 0
    -- Show a line now?
    s.introDue = introDue
    -- Still in the introduction period at all? This is the one the nag
    -- suppression keys off: the gear and meta jokes stay quiet for the
    -- whole run-in, not only on the opens that happen to carry a line.
    --
    -- Strictly less than, not "or equal to". At the final step he says
    -- "I will stop explaining myself and start keeping score" -- so that
    -- is precisely the open where the gear and meta jokes come back. The
    -- inclusive version left them suppressed permanently, which is a
    -- quiet way to disable half the addon's personality forever.
    s.fresh = s.introStep > 0 and s.introStep < INTRO_STEPS

    -- Week 1 is a different game to week 4: no keystones, everything on
    -- a lockout, and nothing worth saying about crest efficiency because
    -- nobody has any crests yet.
    s.seasonWeek = nil
    if ns.SEASON_PATCH_START then
        local elapsed = time() - ns.SEASON_PATCH_START
        if elapsed >= 0 then
            s.seasonWeek = math.floor(elapsed / 604800) + 1
        end
    end

    -- Whether gear advice is worth giving yet.
    --
    -- This is NOT s.fresh. s.fresh only says whether Yeeper has finished
    -- introducing himself, which runs out after an hour or two of
    -- opening the addon -- and it was the only thing standing between a
    -- day-one player and "four unenchanted slots on gear you already
    -- own". Someone testing on patch day burned through the intro and
    -- got exactly the nagging the intro exists to defer.
    --
    -- Before keys are live there is no new gear to have, so every gear
    -- observation is about last season's kit, which is about to be
    -- replaced wholesale. Week 1 is the same story with the raid.
    s.earlySeason = (not s.mplusLive) or s.seasonWeek == 1

    -- Gear worth finishing: slots that are actually on this season's
    -- tracks. s.stale is the opposite -- slots with no track at all,
    -- which is last season's kit.
    s.seasonGear = #s.upgrades + s.maxed

    -- Whether enchants, gems and sockets are worth a word yet.
    --
    -- Polish is advice about gear you are going to KEEP. Telling someone
    -- to enchant last season's chest is telling them to spend gold on a
    -- piece that is about to be replaced, which is worse than saying
    -- nothing -- and on patch day every slot is last season's, so the
    -- whole subject is noise.
    --
    -- Two gates, because either one alone has a hole. The date alone
    -- would start nagging the moment week two arrives even if nothing
    -- has dropped; the gear count alone would nag someone who got one
    -- lucky piece an hour into the patch.
    s.tooEarlyToPolish = s.earlySeason or s.seasonGear == 0

    -- Whether "you have not done anything" is worth saying.
    --
    -- An empty vault, zero best-in-slot pieces and no runs with the
    -- guild are all GUARANTEED true for every player at the start of a
    -- season. Stating them is not an observation, it is reading the
    -- calendar back to someone -- and stacked together, two minutes
    -- after a patch-day login, it reads as a pile-on about failing to do
    -- things that were not possible yet.
    --
    -- The condition is not the date alone but whether they have had a
    -- chance: keys live, and enough of the week gone that a vault could
    -- have been filled.
    s.hadAChance = s.mplusLive and not s.earlySeason

    ------------------------------------------------------------
    -- What the rest of the addon already knows
    ------------------------------------------------------------
    -- TrinketData and ClassGuideData are loaded and nothing in the
    -- advisor could see them, so Yeeper was the least informed part of
    -- his own addon.
    if specKey and ns.Trinkets and ns.Trinkets.GetForSpec then
        local list = try(ns.Trinkets.GetForSpec, ns.Trinkets, specKey, "ST")
        if type(list) == "table" and list[1] then
            s.trinketBest = list[1].name
            local wearing = false
            for _, slot in ipairs({ 13, 14 }) do
                if GetInventoryItemID("player", slot) == list[1].id then
                    wearing = true
                end
            end
            s.trinketBestWorn = wearing
        end
    end

    -- Best-in-slot progress. Counted the same way the BiS page counts
    -- it, so the two cannot disagree about the same character.
    local cg = specKey and ns.ClassGuideData and ns.ClassGuideData[specKey]
    if cg and cg.bis then
        local SLOT_INV = {
            Head={1}, Neck={2}, Shoulders={3}, Back={15}, Chest={5}, Wrist={9},
            Hands={10}, Waist={6}, Legs={7}, Feet={8},
            Ring={11,12}, ["Ring 1"]={11}, ["Ring 2"]={12},
            Trinket={13,14}, ["Trinket 1"]={13}, ["Trinket 2"]={14},
            Weapon={16,17}, ["Main Hand"]={16}, ["Off Hand"]={17},
        }
        -- Bags count, because the Best in Slot page counts them. Two
        -- parts of the addon disagreeing about the same number reads as
        -- a bug even when both are defensible, and the page is the one
        -- the player can check.
        local bags = ns.ScanBagItems and ns:ScanBagItems() or {}
        local taken, have, worn, total = {}, 0, 0, 0
        for _, row in ipairs(cg.bis) do
            for _, inv in ipairs(SLOT_INV[row.slot] or {}) do
                if not taken[inv] then
                    taken[inv] = true
                    total = total + 1
                    if GetInventoryItemID("player", inv) == row.itemID then
                        have, worn = have + 1, worn + 1
                    elseif bags[row.itemID] then
                        have = have + 1
                    end
                    break
                end
            end
        end
        s.bisHave, s.bisTotal, s.bisWorn = have, total, worn
    end

    -- How long until everything weekly resets. The vault, the crest
    -- caps and the raid lockout all turn over together, so "your vault
    -- is empty" is a very different sentence six days out and six hours
    -- out.
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local secs = try(C_DateAndTime.GetSecondsUntilWeeklyReset)
        if secs and secs > 0 then
            s.resetSeconds = secs
            s.resetHours = math.floor(secs / 3600)
            s.resetDays = math.floor(secs / 86400)
        end
    end

    -- Is the raid actually open? Week one has neither keystones nor a
    -- raid, so both have to be checked before anything suggests them.
    s.raidOpen = true
    if ns.SEASON_RAID_START then
        s.raidOpen = time() >= ns.SEASON_RAID_START
        s.daysToRaid = math.max(0,
            math.ceil((ns.SEASON_RAID_START - time()) / 86400))
    end

    return s
end

------------------------------------------------------------
-- Rules
------------------------------------------------------------
-- Each returns nil, or { p = priority, text = "..." }. Higher priority
-- wins. Ties are impossible by design -- every priority is distinct --
-- so the bot never has to choose arbitrarily.

local function plural(n, one, many)
    return n == 1 and one or many
end

------------------------------------------------------------
-- Introduction
------------------------------------------------------------
-- Shown for the first few opens on a new version, ahead of everything
-- else. Deliberately NOT about the player's gear: at a season start
-- every character is in last season's kit with no enchants and no
-- crests, so gear commentary reads as a broken addon rather than a rude
-- one. These talk about him, about the week, and about the one thing
-- that is genuinely urgent in week one.
--
-- Each returns nil when it does not apply, exactly like a rule.
AD.INTRO = {
    -- Who he is
    function(s)
        return { p = 200, text = ("I'm Yeeper. I look at your gear, your crests, your vault "
            .. "and your keys, and I tell you which one of them is currently a problem. "
            .. "You did install me, so this is technically your fault.") }
    end,
    function(s)
        return { p = 199, text = ("Version %s. I'm new, the season is new, and neither "
            .. "of us is at our best yet. Give it a week.")
            :format(ns.ADDON_VERSION or "12.1.0") }
    end,
    function(s)
        return { p = 198, text = "I've been through your bags, your vault and your quest "
            .. "log. Don't make it strange. That is the entire job." }
    end,
    function(s)
        return { p = 197, text = "Fair warning: I'm honest about your gear, and you are "
            .. "going to find that irritating at least twice a week." }
    end,

    -- Week one: what there actually is to do
    function(s)
        if s.seasonWeek == 1 and not s.mplusLive then
            return { p = 190, text = ("Keystones are %d %s away. Nothing you run this "
                .. "week touches your rating, so run it for the loot and stop worrying "
                .. "about the timer.")
                :format(s.daysToKeys or 0, (s.daysToKeys or 0) == 1 and "day" or "days"),
                tips = {
                    "Heroic dungeons and Mythic 0 are the whole menu this week",
                    "Mythic 0 is a daily lockout per dungeon",
                    "Two raid bosses at any difficulty fills a vault slot",
                } }
        end
    end,
    function(s)
        if s.seasonWeek == 1 then
            return { p = 189, text = "Week one is a lockout game, not a grind. There is a "
                .. "fixed amount of gear available and then there is none, so the winning "
                .. "move is to clear the list and log off." }
        end
    end,
    function(s)
        if s.seasonWeek == 1 and (s.vaultFilled or 0) == 0 then
            return { p = 188, text = "Nothing in the vault yet. Three Mythic 0 runs starts "
                .. "that row, and it is the least effort on your entire list this week." }
        end
    end,
    function(s)
        -- Raid is not open in week one, so "go get a raid lockout" is
        -- advice you cannot act on. Says what IS there instead.
        if s.seasonWeek == 1 and not s.raidOpen then
            return { p = 187, text = "No raid yet either — that opens next week. "
                .. "Dungeons and delves are the whole week until then." }
        end
    end,

    -- Explicitly declining to nag, which is itself the joke
    function(s)
        if s.seasonWeek == 1 and (s.stale or 0) > 0 then
            return { p = 180, text = ("%d of your slots are last season's. So is everyone "
                .. "else's. I am not going to pretend that is a personal failing in week "
                .. "one — ask me again on Thursday.")
                :format(s.stale) }
        end
    end,
    function(s)
        if s.seasonWeek == 1 and #(s.unenchanted or {}) > 0 then
            return { p = 179, text = ("%d slots with no enchant. Normally I would be "
                .. "unpleasant about this. It is week one and half that gear is gone by "
                .. "Friday, so I will save it.")
                :format(#(s.unenchanted or {})) }
        end
    end,
    function(s)
        if s.seasonWeek == 1 then
            return { p = 178, text = "I could take your gear apart right now, but there is "
                .. "no point — most of it gets replaced this week. Come back when you have "
                .. "something worth defending." }
        end
    end,

    -- Winding down
    function(s)
        if s.introStep and s.introStep >= INTRO_STEPS - 1 then
            return { p = 170, text = "That is the introduction done. From here I mostly "
                .. "talk about crests, and I am told I am tiresome about it." }
        end
    end,
    function(s)
        if s.introStep and s.introStep >= INTRO_STEPS then
            return { p = 169, text = "You know where everything is now. I will stop "
                .. "explaining myself and start keeping score." }
        end
    end,
}

AD.RULES = {
    -- 100s: something is being actively wasted.
    -- Idle crests are, by construction, crests NOTHING can absorb:
    -- s.idleAmount only fills when need[track] is zero, and need counts
    -- upgradeable equipped items. So the one thing the player cannot do
    -- with them is spend them at the upgrade vendor -- which is exactly
    -- what this rule used to tell them to go and do, with directions.
    --
    -- The real sinks are a drop on that track or a crafting order, and
    -- the honest version says so. Deliberately does not guess which case
    -- it is: "no gear on that track" and "all of it already maxed" both
    -- land here and both are true to "nothing you are wearing takes it".
    function(s)
        if s.idleAmount >= 90 then
            local craftCost = ns.CRAFT_CREST_COST or 80
            return { p = 100, text = ("You are sitting on %d %s crests and not one thing "
                .. "you are wearing can take them. They are no use to you until something "
                .. "on that track turns up.")
                :format(s.idleAmount, s.idleTrack),
                tips = {
                    "The upgrade vendor has nothing for you: no " .. s.idleTrack
                        .. " gear left to put them in",
                    ("A Spark crafting order takes %d crests and does not need a drop")
                        :format(craftCost),
                    "Otherwise it is a " .. s.idleTrack .. " drop away, and then they all matter at once",
                } }
        end
    end,
    -- Sits just under idle crests: crests rotting in a bag is worse than
    -- crests about to be spent slightly wrong, but only just. This one
    -- is the single most broadly applicable gearing mistake of the
    -- season, and it is invisible at the upgrade vendor -- the game
    -- charges 20 crests either way and never mentions that one of the
    -- two currencies has months of use left in it.
    function(s)
        local n = #s.crestWaste
        if n == 0 then return end
        local w = s.crestWaste[1]

        local tips = {}
        for i = #ns.TRACK_ORDER, 1, -1 do
            local into = ns.TRACK_ORDER[i]
            local names = s.crestWasteSinks[into]
            if names then
                table.insert(tips, ("Put %s crests into %s instead")
                    :format(into, table.concat(names, ", ")))
            end
        end
        table.insert(tips, ("Only %s crests buy rank %d and up -- nothing else does")
            :format(w.crestTrack, w.overlapRanks + 1))
        table.insert(tips, ("%s crests go dead the week every %s slot is maxed")
            :format(w.prevCrestTrack, w.prevTrack))

        if n == 1 then
            return { p = 98, text = ("%s is %s %d/%d. The next rank costs %d %s and lands "
                .. "on %d, which is exactly where a maxed %s piece lands for the same "
                .. "price. One of those two currencies still has a season in it.")
                :format(w.slotName, w.track, w.rank, w.maxRank or 6, w.wastedCrests,
                        w.crestTrack, w.toIlvl, w.prevTrack),
                tips = tips }
        end

        -- Several slots, possibly across two crest tracks. Name the
        -- damage per track rather than picking one and hoping.
        local parts = {}
        for i = #ns.TRACK_ORDER, 1, -1 do
            local track = ns.TRACK_ORDER[i]
            local amount = s.crestWasteTotals[track]
            if amount then table.insert(parts, ("%d %s"):format(amount, track)) end
        end
        return { p = 98, text = ("%d slots sit one rank below item level the track under "
            .. "them already reaches. Buying those ranks the expensive way costs %s, and "
            .. "gets you an item level the cheap crests were going to give you anyway.")
            :format(n, table.concat(parts, " and ")),
            tips = tips }
    end,
    function(s)
        for track, c in pairs(s.crests) do
            if c.capped and c.have >= 60 then
                return { p = 95, text = ("%s crests are capped for the week and you are "
                    .. "sitting on %d. That is income you have already stopped earning.")
                    :format(track, c.have),
                    tips = {
                        "Spend them: capped means this week earns you nothing more",
                        "Upgrading a lower track can free the next one up",
                    } }
            end
        end
    end,

    -- 90s: about to lose something, or about to walk into content
    -- unprepared. Both are time-bound in a way a crest pile is not.
    function(s)
        -- Durability is the only thing here that fails mid-pull. It is
        -- also the cheapest possible fix, which is what makes ignoring
        -- it worth being rude about.
        -- Almost everyone auto-repairs, so this is a rare state rather
        -- than a common nag. Left in for the case where it genuinely is
        -- about to matter, and nowhere near as loud as it was.
        if (s.durability or 1) < 0.15 and s.durabilitySlot then
            return { p = 94, text = ("Your %s is at %d%%. You are about to be fighting "
                .. "in the nude, which is a choice, but not a good one.")
                :format(s.durabilitySlot, math.floor((s.durability or 0) * 100)) }
        end
    end,
    function(s)
        -- Only worth saying while there is still time to act on it. Six
        -- days out this is nagging; six hours out it is a warning.
        if s.resetHours and s.resetHours <= 12
           and s.vaultFilled and s.vaultTotal
           and s.vaultFilled < s.vaultTotal then
            local left = s.vaultTotal - s.vaultFilled
            local near = s.vaultNearest
            local line = ("Reset is in %d hours and %d vault %s still empty.")
                :format(s.resetHours, left, left == 1 and "slot is" or "slots are")
            if near and near.remaining and near.remaining > 0 then
                line = line .. (" The closest one needs %d more.")
                    :format(near.remaining)
            end
            return { p = 93, text = line,
                tips = { "Anything you unlock now is a reward you keep next week" } }
        end
    end,
    function(s)
        -- Gear you own but have not finished. Free stats, already paid
        -- for, sitting there.
        local missing = #(s.unenchanted or {})
        if missing > 0 and (s.emptySockets or 0) > 0
            and not s.fresh and not s.tooEarlyToPolish then
            return { p = 92, text = ("%d unenchanted %s and %d empty %s. That is free "
                .. "stats on gear you already own, and it costs you nothing but a trip "
                .. "to the auction house.")
                :format(missing, missing == 1 and "slot" or "slots",
                        s.emptySockets, s.emptySockets == 1 and "socket" or "sockets"),
                tips = {
                    "Missing enchants: " .. table.concat(s.unenchanted, ", "),
                    (s.gold or 0) > 0
                        and ("You have " .. BreakUpLargeNumbers(s.gold) .. " gold")
                        or "Check the auction house",
                } }
        end
    end,
    function(s)
        -- Readiness, not gear, and the one failure here that lands on
        -- other people. The severity scales with the offence: turning up
        -- with nothing while four strangers carry you is a different
        -- thing to forgetting your food.
        local miss = s.missingConsumables or {}
        if #miss == 0 or s.fresh then return end
        if not (s.mplusLive or s.raidOpen or s.inGroup) then return end

        local list = table.concat(miss, ", "):lower()
        local others = math.max((s.groupSize or 0) - 1, 0)

        -- In a group, right now, with people already depending on you.
        if s.inGroup and #miss >= 2 then
            return { p = 96, text = ("You are in a group of %d with no %s. That is not "
                .. "being underprepared, that is %d other people covering for you. Sort "
                .. "it out before the first pull.")
                :format(s.groupSize or 0, list, others),
                tips = { "The Consumables page lists exactly what your spec wants" } }
        end

        if #miss >= 4 then
            return { p = 91, text = ("No flask, no food, no rune — nothing. Walking into "
                .. "group content like that is not a handicap you take on yourself, it "
                .. "is one you hand to everyone else. Auction house. Now."),
                tips = {
                    "Missing: " .. list,
                    (s.gold or 0) > 0
                        and ("You have " .. BreakUpLargeNumbers(s.gold) .. " gold; this "
                             .. "costs a rounding error of it")
                        or "Most of it is a few thousand gold",
                } }
        end

        if #miss >= 2 then
            return { p = 90, text = ("Missing your %s. Every point of that is damage or "
                .. "healing somebody else has to make up, and they did remember theirs.")
                :format(list),
                tips = { "The Consumables page lists exactly what your spec wants" } }
        end

        return { p = 89, text = ("No %s. One item, one button, and the only person it "
            .. "costs is whoever is standing next to you."):format(list) }
    end,

    -- 80s: a concrete, affordable action.
    function(s)
        if s.affordable > 0 and s.biggest and s.shortfall == 0 then
            return { p = 85, text = ("%d %s you can pay for right now. %s has the most "
                .. "left in it -- %d item levels to its cap. I would start there.")
                :format(s.affordable, plural(s.affordable, "upgrade", "upgrades"),
                        s.biggest.name, s.biggest.gain),
                tips = {
                    "Upgrade at the crest vendor in Silvermoon",
                    "Weapons and trinkets first: biggest throughput per crest",
                } }
        end
    end,
    function(s)
        if s.affordable > 0 and s.shortfall > 0 and s.cheapest then
            return { p = 80, text = ("%d of %d upgrades are affordable. You are %d %s crests "
                .. "short of the rest, so %s first -- cheapest at %d.")
                :format(s.affordable, #s.upgrades, s.shortfall, s.shortTrack,
                        s.cheapest.name, s.cheapest.cost),
                tips = {
                    "Cheapest first gets the most item levels out of what you hold",
                    "The vault and weekly content top the shortfall back up",
                } }
        end
    end,

    -- 70s: pending but unaffordable.
    function(s)
        if #s.upgrades > 0 and s.affordable == 0 and s.shortfall > 0 then
            return { p = 75, text = ("%d %s waiting and not a single one affordable. "
                .. "You need %d more %s crests before any of this matters.")
                :format(#s.upgrades, plural(#s.upgrades, "upgrade", "upgrades"),
                        s.shortfall, s.shortTrack),
                tips = {
                    "Crests come from dungeons, raid bosses and delves",
                    "Weekly caps reset Wednesday; earn what you can before then",
                } }
        end
    end,

    -- 60s: structural problems worth naming once.
    function(s)
        -- Week one is handled by the intro, which says the same thing
        -- without implying it is your fault.
        if s.fresh or s.earlySeason then return end
        if s.stale >= 3 then
            return { p = 65, text = ("%d slots are still last season's gear. They cannot be "
                .. "upgraded at all, which makes them the actual bottleneck.")
                :format(s.stale),
                tips = {
                    "Heroic dungeons drop 276 -- fastest fix for empty slots",
                    "Mythic 0 drops 292 on a daily lockout",
                    "Delves and weekly world content fill the rest",
                } }
        end
    end,

    -- 40s: nothing wrong, so comment on the state of things.
    function(s)
        -- "Everything you own is as good as it gets" is trivially true
        -- on day one and reads as an accusation. Nothing is pending
        -- because nothing has dropped yet.
        if #s.upgrades == 0 and s.stale == 0 and s.ilvl > 0
            and not s.fresh and not s.earlySeason then
            return { p = 45, text = ("Item level %d and nothing pending. Everything you own "
                .. "is as good as it gets. Go and find better."):format(s.ilvl) }
        end
    end,
    function(s)
        -- Same observation as the stale-gear rule above, and it leaks
        -- through the same season-start hole: at a fresh season nothing
        -- is upgradeable and everything is old, so this fires for every
        -- player alive and says nothing about any of them.
        if s.fresh or s.earlySeason then return end
        if #s.upgrades == 0 and s.stale > 0 then
            return { p = 44, text = ("Nothing upgradeable, and %d %s stuck on old gear. "
                .. "Those need replacing, not upgrading.")
                :format(s.stale, plural(s.stale, "slot is", "slots are")),
                tips = {
                    "Dungeon and raid drops replace them outright",
                    "Delves and world content for the cheaper slots",
                    "Crafted gear if a slot refuses to drop",
                    "The vault, but only once a week",
                } }
        end
    end,

    -- 10s: last resort, so the panel is never blank.
    function(s)
        if #s.upgrades > 0 then
            return { p = 15, text = ("%d %s pending, +%d item levels in total.")
                :format(#s.upgrades, plural(#s.upgrades, "upgrade", "upgrades"), s.totalGain) }
        end
    end,
    function()
        return { p = 5, text = "Nothing to report. Suspicious, but I will allow it." }
    end,
}

------------------------------------------------------------
-- Speak
------------------------------------------------------------

------------------------------------------------------------
-- Asides
------------------------------------------------------------
-- Yeeper is not a to-do list. If every line is an instruction he becomes
-- a nag, and a nag gets closed. Asides are true observations with no
-- action attached -- they are what makes him read as present rather than
-- as a widget that fires when your gear changes.

AD.ASIDES = {
    ------------------------------------------------------------
    -- Mythic+
    ------------------------------------------------------------
    function(s)
        if not s.mplusLive then
            return { text = ("Keystones are not live yet -- %d %s to go. "
                .. "Nothing you do in a dungeon this week counts toward rating.")
                :format(s.daysToKeys or 0,
                        (s.daysToKeys or 0) == 1 and "day" or "days"),
                tips = {
                    "Mythic 0 is open now and drops 292 Champion gear",
                    "It is a weekly lockout until the season starts",
                    "Heroic dungeons at 276 fill empty slots fast",
                    "Bank crests now; they spend the same later",
                } }
        end
    end,
    function(s)
        if s.mplusLive and (s.mplusScore or 0) > 0 then
            return ("Rating %d. I have seen worse. I have also seen better, "
                .. "and I bring it up for a reason."):format(s.mplusScore)
        end
    end,
    function(s)
        if s.mplusLive and (s.runs or 0) > 0 and (s.runsTen or 0) == 0 then
            return ("%d keys done, none above +9. There is a ceiling there and "
                .. "you are politely standing under it."):format(s.runs)
        end
    end,
    function(s)
        if s.mplusLive and (s.runsTen or 0) > 0 then
            return ("%d of your %d keys were +10 or higher. Fine. That is "
                .. "genuinely fine."):format(s.runsTen, s.runs or 0)
        end
    end,
    function(s)
        if s.mplusLive and (s.runs or 0) == 0 and (s.mplusScore or 0) == 0 then
            return "No keys this season. The dungeons are still there. "
                .. "They have not moved."
        end
    end,
    -- The gear ceiling. Only said to people who have actually gone past
    -- it -- told to someone sitting at +5 it is not an observation, it
    -- is a reason to stop trying.
    --
    -- Carefully not sneering at rating. Pushing keys IS the point of
    -- Mythic+ and gear is the byproduct; an earlier draft framed those
    -- runs as a mistake the player had not noticed making, which is both
    -- condescending and wrong. The useful fact is where the item level
    -- stops, not that they were wasting their time.
    function(s)
        if s.mplusLive and s.keyCeiling and (s.runsAtCeiling or 0) > 0 then
            return { text = ("%d of your keys were above +%d, which is where the "
                .. "vault stops improving. So those were pure rating. Presumably "
                .. "on purpose, but I am told I should check.")
                :format(s.runsAtCeiling, s.keyCeiling),
                tips = {
                    ("+%d and up all drop %d and all vault %d")
                        :format(s.keyCeiling, s.keyCeilingLoot, s.keyCeilingVault),
                    "Push for score; the item level stopped moving a while back",
                } }
        end
    end,

    ------------------------------------------------------------
    -- Vault
    ------------------------------------------------------------
    function(s)
        -- vaultTotal > 0, not merely non-nil. An empty activities list --
        -- the API before it is ready, or a week with no vault at all --
        -- gives filled == 0 AND filled == total, so both this and the
        -- "vault is full" line below fired at once and one of them was
        -- always a lie.
        if (s.vaultTotal or 0) > 0 and s.vaultFilled == 0 then
            return "Nothing in the vault. Come Tuesday that is a very quiet "
                .. "moment for both of us."
        end
    end,
    function(s)
        if (s.vaultTotal or 0) > 0 and s.vaultFilled and s.vaultFilled > 0
           and s.vaultFilled < s.vaultTotal then
            return ("%d of %d vault slots filled. The remaining %d are not "
                .. "going to fill themselves, and I have checked.")
                :format(s.vaultFilled, s.vaultTotal, s.vaultTotal - s.vaultFilled)
        end
    end,
    function(s)
        if (s.vaultTotal or 0) > 0 and s.vaultFilled == s.vaultTotal then
            return "Vault is full. I would like it noted that I said nothing "
                .. "discouraging this week."
        end
    end,

    ------------------------------------------------------------
    -- Raid
    ------------------------------------------------------------
    function(s)
        if (s.raidTotal or 0) > 0 and s.raidKills < s.raidTotal then
            return { text = ("%s: %d of %d down on %s. The rest are still "
                .. "upright and reportedly quite confident.")
                :format(s.raidName or "The raid", s.raidKills, s.raidTotal,
                        s.raidDiff or "that difficulty"),
                tips = {
                    "Two bosses at any difficulty fills a vault slot",
                    "Higher difficulty raises what that slot offers",
                } }
        end
    end,
    function(s)
        if (s.raidTotal or 0) > 0 and s.raidKills >= s.raidTotal then
            return ("%s cleared on %s. Well. Now what.")
                :format(s.raidName or "The raid", s.raidDiff or "that difficulty")
        end
    end,

    ------------------------------------------------------------
    -- Social
    ------------------------------------------------------------
    -- Every line below is gated on s.social. A player with no guild, or a
    -- guild that is effectively empty, never sees any of it -- there is
    -- no version of "you never group with your guild" that is funny when
    -- the answer is "I do not have one".
    function(s)
        if s.social and s.guildRuns == 0 and s.hadAChance then
            return ("A guild of %d and not one run with any of them. They are "
                .. "right there. Some of them are even online.")
                :format(s.guildSize or 0)
        end
    end,
    function(s)
        if s.social and s.guildRuns > 0 and s.guildRuns < 5 then
            return ("%d %s with guildmates. A start. Barely a start, but a start.")
                :format(s.guildRuns, s.guildRuns == 1 and "run" or "runs")
        end
    end,
    function(s)
        if s.social and s.guildRuns >= 25 then
            return ("%d runs with the guild. You appear to have friends. "
                .. "I did not predict this."):format(s.guildRuns)
        end
    end,

    ------------------------------------------------------------
    -- Bags, wallet, upkeep
    ------------------------------------------------------------
    -- Observations rather than instructions. None of these is urgent,
    -- which is exactly why they belong here and not in the rules.
    function(s)
        if (s.bagFree or 0) <= 3 and (s.bagTotal or 0) > 0 then
            return ("%d free bag slots. At some point that becomes a decision you have "
                .. "to make, probably mid-boss."):format(s.bagFree)
        end
    end,
    function(s)
        -- Names the actual enchant rather than the slot. "Your chest has
        -- no enchant" is a complaint; naming the item is an instruction,
        -- and the addon already scraped it per spec.
        if s.guide and #(s.unenchanted or {}) > 0
            and not s.fresh and not s.tooEarlyToPolish then
            local want = s.unenchanted[1]
            for _, e in ipairs(s.guide.enchants or {}) do
                if e.slot == want or (want == "Cloak" and e.slot == "Back") then
                    local name = C_Item and C_Item.GetItemInfo
                        and select(1, C_Item.GetItemInfo(e.itemID))
                    if name then
                        return ("Your %s wants %s and does not have it. I looked it up "
                            .. "for you. That is as far as I go."):format(want, name)
                    end
                end
            end
        end
    end,
    function(s)
        if s.trinketBest and s.trinketBestWorn == false then
            return ("The best simmed trinket for your spec is %s and it is not on you. "
                .. "Sims are not gospel, but they are not nothing either.")
                :format(s.trinketBest)
        end
    end,
    function(s)
        if s.bisTotal and s.bisTotal > 0 then
            -- Gate the whole aside, not just the zero branch: skipping
            -- only the branch drops through to the generic "0 of 16",
            -- which is the same trivially-true line in other words.
            if s.bisHave == 0 and not s.hadAChance then return end
            if s.bisHave == 0 then
                return ("Zero of %d best-in-slot pieces. Everyone starts there. Not "
                    .. "everyone stays."):format(s.bisTotal)
            elseif s.bisHave >= s.bisTotal then
                if (s.bisWorn or 0) < s.bisTotal then
                    return ("Every best-in-slot piece, and %d of them still in your "
                        .. "bags. Astonishing. Put them on."):format(s.bisTotal - s.bisWorn)
                end
                return "Every best-in-slot piece, equipped. I have genuinely nothing "
                    .. "to complain about and I resent it."
            end
            return ("%d of %d best-in-slot pieces. The other %d are out there being "
                .. "worn by someone else.")
                :format(s.bisHave, s.bisTotal, s.bisTotal - s.bisHave)
        end
    end,
    -- The repair bill. Funny because it is the cost of failing, and it
    -- gets funnier the less you have to show for it.
    function(s)
        if (s.repairWeek or 0) >= 5000 and (s.raidTotal or 0) > 0
           and (s.raidKills or 0) == 0 then
            return ("%s gold on repairs this week and not a single boss down. HAHAHA. "
                .. "You are paying a subscription to wipe.")
                :format(BreakUpLargeNumbers(s.repairWeek))
        end
    end,
    function(s)
        if (s.repairWeek or 0) >= 5000 and (s.vaultFilled or 0) == 0
           and s.hadAChance then
            return ("%s gold repairing this week, and an empty vault to show for it. "
                .. "You are not raiding, you are donating.")
                :format(BreakUpLargeNumbers(s.repairWeek))
        end
    end,
    function(s)
        if (s.repairSession or 0) >= 3000 then
            return ("%s gold on repairs this session alone. Whatever you are doing, it "
                .. "is not going well and it is not free.")
                :format(BreakUpLargeNumbers(s.repairSession))
        end
    end,
    function(s)
        if (s.repairLifetime or 0) >= 100000 then
            return ("%s gold on repairs since I started counting. That is a mount. That "
                .. "is several mounts."):format(BreakUpLargeNumbers(s.repairLifetime))
        end
    end,
    function(s)
        -- The reverse: nothing spent and nothing killed is its own joke.
        if (s.repairWeek or 0) == 0 and (s.raidTotal or 0) == 0
           and (s.runs or 0) == 0 and s.mplusLive and not s.fresh then
            return "Zero gold on repairs this week. Impressive, until you remember that "
                .. "means nothing has hit you, because you have not been anywhere."
        end
    end,
    function(s)
        if (s.gold or 0) >= 500000 and #(s.unenchanted or {}) > 0
            and not s.tooEarlyToPolish then
            return ("%s gold, and %d of your slots have no enchant. You are not saving "
                .. "for anything. I have checked your bags.")
                :format(BreakUpLargeNumbers(s.gold), #s.unenchanted)
        end
    end,
    function(s)
        if (s.emptySockets or 0) > 0 and (s.gold or 0) > 20000
            and not s.tooEarlyToPolish then
            return ("%d empty %s. Gems are cheap, you are not poor, and I am running out "
                .. "of ways to say this.")
                :format(s.emptySockets, s.emptySockets == 1 and "socket" or "sockets")
        end
    end,
    function(s)
        if s.resetDays and s.resetDays >= 5 and (s.vaultFilled or 0) == 0
           and s.hadAChance then
            return ("Reset was recent and your vault is empty. Nothing wrong with that "
                .. "yet. I am simply noting the starting position.")
        end
    end,
    function(s)
        -- Deliberately positive. He is not only a nag, and a character
        -- who is genuinely ready should hear it once.
        if #(s.unenchanted or {}) == 0 and (s.emptySockets or 0) == 0
           and #(s.missingConsumables or {}) == 0 and (s.durability or 1) > 0.5 then
            return "Enchanted, gemmed, stocked and repaired. I have nothing. This is "
                .. "deeply unsatisfying for me."
        end
    end,

    ------------------------------------------------------------
    -- Character
    ------------------------------------------------------------
    function(s)
        local n = ns.FunStats and ns.FunStats:Get("jumps") or 0
        if n >= 200 then
            return ("You have jumped %s times since I started counting. "
                .. "I mention it because nobody else will.")
                :format(BreakUpLargeNumbers(n))
        end
    end,
    function(s)
        if s.maxed > 0 and s.maxed >= #s.upgrades then
            return ("%d of your slots are finished. I would call that done, "
                .. "but I have met you."):format(s.maxed)
        end
    end,
    function(s)
        local hour = tonumber(date("%H"))
        if hour and hour >= 1 and hour < 5 then
            return "It is the early hours. The vault will still be there "
                .. "tomorrow. I am contractually unable to stop you."
        end
    end,
    function(s)
        -- It has not had time to move on day one.
        if s.ilvl > 0 and not s.fresh and not s.earlySeason then
            return ("Item level %d. I have been watching it move. Slowly.")
                :format(s.ilvl)
        end
    end,
    function(s)
        if #s.upgrades == 0 and s.stale == 0 then
            return "Nothing needs doing. I have checked twice, which is twice "
                .. "more than you asked."
        end
    end,
    function(s)
        return "Standing by. Not that anything is happening."
    end,

    ------------------------------------------------------------
    -- Meta: he knows how you use the addon
    ------------------------------------------------------------
    -- These land because they are true. He is not guessing that you keep
    -- reopening this panel -- he counted.
    function(s)
        -- "You keep coming back" needs a history. Straight after an
        -- update there isn't one, and saying it on someone's second
        -- visit reads as the addon inventing a grudge.
        if s.fresh then return end
        local n = ns.FunStats and ns.FunStats:Get("homeOpens") or 0
        if n >= 40 then
            return ("You have opened this panel %d times. The numbers did not "
                .. "change in the last four."):format(n)
        end
    end,
    function(s)
        if s.fresh then return end
        local n = ns.FunStats and ns.FunStats:Get("homeOpens") or 0
        if n >= 15 and n < 40 then
            return "Back again. Nothing has moved since you last checked, "
                .. "but I admire the optimism."
        end
    end,
    function(s)
        if s.fresh then return end
        local n = ns.FunStats and ns.FunStats:Get("homeOpens") or 0
        if n >= 100 then
            return ("%d visits. At this point I am less an addon and more a "
                .. "coping mechanism."):format(n)
        end
    end,

    ------------------------------------------------------------
    -- Your character, specifically
    ------------------------------------------------------------
    function(s)
        if s.fresh or s.tooEarlyToPolish then return end
        local n = #(s.unenchanted or {})
        local gold = s.gold or 0
        if n > 0 and gold > 50000 then
            return { text = ("%d unenchanted %s, and %s gold sitting in the "
                .. "bank. You can afford it. Buy the enchants.")
                :format(n, n == 1 and "slot" or "slots",
                        BreakUpLargeNumbers(gold)),
                tips = { "Missing: " .. table.concat(s.unenchanted, ", ") } }
        elseif n >= 3 then
            return { text = ("%d slots with no enchant. That is free stats "
                .. "you are choosing not to have."):format(n),
                tips = { "Missing: " .. table.concat(s.unenchanted, ", ") } }
        end
    end,
    -- Actual jokes, told badly on purpose.
    --
    -- The previous attempt here was wry one-line descriptions of each
    -- class, which is not the same thing as a joke -- no setup, no
    -- punchline, nothing to land. These are real jokes doing the work,
    -- and Yeeper's flat delivery plus his obvious dislike of having to
    -- tell them is the second layer. A machine grudgingly performing
    -- material it does not understand is funnier than a machine being
    -- mildly sardonic about your spec.
    --
    -- Sources: punsnjokes.com/world-of-warcraft, laffgaff.com/funny-wow-jokes
    function(s)
        local _, class = UnitClass("player")
        -- Two or three per class, picked at random. Sources:
        -- punsnjokes.com, laffgaff.com, punorbit.com.
        local classJokes = {
            ROGUE = {
                "How do you spot a subtlety rogue at a party? You do not. "
                    .. "That is the entire joke. I am told it works aloud.",
                "How does a rogue greet you? With a sneak-attack wave. "
                    .. "I did not laugh either.",
            },
            HUNTER = {
                "A hunter walks into a tavern. So does the pet. So does the "
                    .. "pack the pet pulled on the way in.",
            },
            PALADIN = {
                "Why does the paladin carry a shield? To protect his fragile "
                    .. "ego. That one is from the internet. I take no view.",
                "What do you call a paladin and a druid sharing a bath? "
                    .. "A HoT tub with bubbles.",
            },
            WARLOCK = {
                "Why are mages and warlocks invited to every party? Mages "
                    .. "bring the food. Warlocks get you stoned.",
                "How do you know a warlock is lying? Their pet starts "
                    .. "whispering the truth.",
            },
            MAGE = {
                "What do you call a group of mages? A spell-check.",
                "Why don't frost mages catch colds? They never take off the "
                    .. "ice crown.",
            },
            DRUID = {
                "Why do druids never get lost? They follow their paws.",
                "What did the druid say to the tree? Leaf me alone. "
                    .. "I want that on record as not my material.",
            },
            WARRIOR = {
                "Why did the warrior turn down dessert? Too much aggro.",
                "Why did the warrior visit the blacksmith? He needed to axe "
                    .. "for directions.",
            },
            PRIEST = {
                "How does a priest make holy water? Boils the hell out of it.",
                "Why did the priest need therapy? He could not stay holy.",
            },
        }
        local set = class and classJokes[class]
        if set then return set[math.random(#set)] end
    end,
    function(s)
        local _, race = UnitRace("player")
        local raceJokes = {
            Tauren = "Why did the tauren open a restaurant? He heard the "
                .. "steaks were high. I did not write it. I only deliver it.",
            Troll  = "How many trolls does it take to change a lightbulb? "
                .. "None. They prefer the dark. Moving on.",
            Gnome  = "What do you get if you cross a gnome with a tauren? "
                .. "A mini-taur. That one is beneath us both.",
        }
        if race and raceJokes[race] then return raceJokes[race] end
    end,
    function(s)
        if (UnitLevel("player") or 0) >= 80 then
            return "How can you tell someone has played since Vanilla? "
                .. "Do not worry. They will tell you."
        end
    end,
    function(s)
        return "What do you call a group of dragons playing cards? A hoard "
            .. "of bluffs. I have four hundred of these and no way to stop."
    end,

    function(s)
        -- Reads the snapshot rather than walking the slots again. The
        -- p=94 rule handles the genuinely urgent case (<20%); this is
        -- the shrug for merely worn gear, and it can name the slot
        -- because the snapshot already worked out which one is worst.
        local pct = s.durability or 1
        if pct < 0.35 and pct >= 0.15 and s.durabilitySlot then
            return ("Your %s is at %d%%. Not my problem, but it will shortly "
                .. "be yours."):format(s.durabilitySlot, math.floor(pct * 100))
        end
    end,
    function(s)
        -- Week one has no raid and no keystones, so "no lockouts, no
        -- keys, no vault" is a description of the calendar rather than
        -- of the player -- and it lands on a fresh character as an
        -- accusation about a game state they cannot yet change.
        if s.fresh or s.earlySeason then return end
        if GetNumSavedInstances and (GetNumSavedInstances() or 0) == 0
           and (s.runs or 0) == 0 then
            return "No lockouts, no keys, no vault. You have logged in to "
                .. "look at me. I am flattered and concerned."
        end
    end,
    function(s)
        if s.ilvl > 0 and s.stale == 0 and #s.upgrades == 0 and (s.runs or 0) > 20 then
            return "Nothing left to fix and you are still running keys. "
                .. "That is either dedication or a lack of hobbies."
        end
    end,
}

--- Rotates so a line does not repeat immediately. Session-only: a fresh
--- login should feel like he picked up where he left off, not like he
--- reset.
local rotation = 0

--- Everything Yeeper currently has to say, most important first: any
--- rule that fired, then every aside that applies. Deduplicated, because
--- a rule and an aside can land on the same observation.
local idleOrder, idleAt, lastWasIdle = nil, 0, false
local IDLE_PER_PLAYLIST = 3

-- How many times an urgent line gets to LEAD before it becomes
-- background.
--
-- Urgency is a property of news, not of a condition. Missing enchants
-- are worth interrupting for the first few times you are told; after
-- that you have been told, and a rule that stays above the urgent
-- threshold monopolises the panel for as long as the condition lasts --
-- which for enchants and sockets is days. That is why the panel was
-- serving the same four lines on a loop and the asides and jabber never
-- got a turn.
--
-- Demoted, not silenced: it drops into the ordinary pool and still comes
-- back regularly, and it is promoted again from scratch if the problem
-- goes away and returns.
local URGENT_LEADS = 3

--- Replay the introduction from the start.
---
--- The intro is stored per addon version, so it normally replays only
--- after an update. Testing a change to it otherwise means bumping the
--- version or hand-editing SavedVariables.
---
--- Also clears the "times shown" counts, since those demote a standing
--- problem out of the urgent slot -- without that, a reset intro would
--- be followed by an oddly quiet Yeeper.
function AD:ResetIntro()
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.introState = nil
    YippYappHelperDB.yeeperShown = nil
    shownThisSession = false
    introDue = false
    return true
end

--- Record that a line was actually put on screen.
---
--- Called by Core/AppFrame.lua, because only the panel knows which of
--- the lines it was handed it chose to show. Persisted rather than kept
--- per session: reloading is not being told again, and someone testing
--- reloads constantly.
--- The key a line is counted under: its wording with the numbers taken
--- out.
---
--- Counting the rendered text does not work, because almost every rule
--- renders a figure that drifts -- "4 unenchanted slots" becomes "5
--- unenchanted slots" the moment one is fixed, "40 crests short"
--- changes every run. Each variant arrived as a brand new line with a
--- count of zero, so a standing problem led forever and never stepped
--- aside, which is the whole thing this was built to stop.
---
--- Normalising also bounds the saved variable: one row per line of
--- dialogue rather than one per number ever displayed.
local function ShownKey(text)
    return (text:gsub("%d+", "#"))
end

function AD:NoteShown(text)
    if not text or text == "" then return end
    YippYappHelperDB = YippYappHelperDB or {}
    local seenCounts = YippYappHelperDB.yeeperShown
    if not seenCounts then
        seenCounts = {}
        YippYappHelperDB.yeeperShown = seenCounts
    end
    local key = ShownKey(text)
    seenCounts[key] = (seenCounts[key] or 0) + 1
end

local function TimesShown(text)
    local db = YippYappHelperDB and YippYappHelperDB.yeeperShown
    return (db and db[ShownKey(text)]) or 0
end

--- The next jabber line, walking a shuffled copy of the bank.
---
--- Reshuffles only once the bank is exhausted, so every line is seen
--- before any line repeats. That is what makes a big bank actually feel
--- big: picking at random from 80 lines produces a repeat within the
--- first dozen or so and reads much smaller than it is.
local function NextIdle()
    local bank = AD.IDLE
    if not bank or #bank == 0 then return nil end
    if not idleOrder or idleAt >= #idleOrder then
        idleOrder = {}
        for i = 1, #bank do idleOrder[i] = bank[i] end
        for i = #idleOrder, 2, -1 do       -- Fisher-Yates
            local j = math.random(i)
            idleOrder[i], idleOrder[j] = idleOrder[j], idleOrder[i]
        end
        idleAt = 0
    end
    idleAt = idleAt + 1
    return idleOrder[idleAt]
end

function AD:Playlist()
    local s = self:Snapshot()
    local out, seen = {}, {}

    local hits = {}
    if s.introDue then
        -- ONE intro line, chosen by how many times the panel has been
        -- opened. Emitting all of them looks right and is not: the
        -- dashboard shows lines[1] outright for anything p >= 60, so a
        -- sorted intro pins the highest-priority line forever and the
        -- player sees "I'm Yeeper" six times in a row. Ask me how I
        -- know.
        local intro = {}
        for _, fn in ipairs(self.INTRO) do
            local ok, result = pcall(fn, s)
            if ok and result then table.insert(intro, result) end
        end
        table.sort(intro, function(a, b) return a.p > b.p end)
        if #intro > 0 then
            local i = ((s.introStep or 1) - 1) % #intro + 1
            table.insert(hits, intro[i])
        end
    end
    for _, rule in ipairs(self.RULES) do
        local ok, result = pcall(rule, s)
        if ok and result then table.insert(hits, result) end
    end
    -- Demote anything he has already led with enough times. Done before
    -- the sort so a stale urgent line does not outrank a fresh one.
    for _, h in ipairs(hits) do
        if h.p and h.p >= 60 and TimesShown(h.text) >= URGENT_LEADS then
            h.p = 50
        end
    end

    table.sort(hits, function(a, b) return a.p > b.p end)
    for _, h in ipairs(hits) do
        -- The low-priority fallbacks exist so the panel is never blank;
        -- they add nothing once there is anything else to say.
        if h.p >= 40 and not seen[h.text] then
            seen[h.text] = true
            table.insert(out, h)
        end
    end

    for _, fn in ipairs(self.ASIDES) do
        local ok, line = pcall(fn, s)
        local msg = ok and asMessage(line)
        if msg and not seen[msg.text] then
            seen[msg.text] = true
            table.insert(out, msg)
        end
    end

    -- Jabber, drawn from the shuffled walk so consecutive opens do not
    -- repeat. A handful rather than the whole bank: AppFrame picks at
    -- random from everything non-urgent, so appending all eighty-odd
    -- would drown the asides and he would never say anything real.
    --
    -- No priority on them, which is deliberate -- AppFrame treats
    -- anything p >= 60 as urgent and shows it outright, so a jabber line
    -- can never take a slot from something that matters.
    for _ = 1, IDLE_PER_PLAYLIST do
        local idle = NextIdle()
        if not idle or seen[idle] then break end
        seen[idle] = true
        table.insert(out, { text = idle })
    end

    if #out == 0 then
        out[1] = { text = "Nothing to report. Suspicious, but I will allow it." }
    end
    return out, s
end

------------------------------------------------------------
-- Jabber
--
-- Lines about nothing. Not gear, not crests, not the vault -- Yeeper
-- with nothing to report, filling the silence.
--
-- Three registers, and only three:
--
--   1. PUT-UPON EMPLOYEE. He has a job he did not apply for and resents
--      it. The tedium is real work he genuinely does: reading every
--      piece of gear you own, over and over, forever.
--   2. JADED AZEROTH NPC. In-world, no fourth wall. He talks like a city
--      guard who has given the same directions for twenty years, and
--      compares his lot to innkeepers, quartermasters and stable
--      masters -- people the player has actually stood in front of.
--   3. UNBOTHERED. Too tired to perform. Very short, anticlimactic,
--      refusing the bit. Earns its place as contrast: the rules are long
--      and fact-heavy, so a two-word reply lands.
--
-- A fourth register was tried and cut: jokes about being software --
-- windows, clicking, existing only while open. Every one of those needs
-- a claim about the interface to work, and the interface kept not
-- supporting it. Nothing clicks him (he is a Texture with a bob and a
-- blink), and YeeperRefresh only runs on a panel layout, so he cannot be
-- interrupted mid-sentence by a window closing either. The register
-- generated confident lines about a program that does not exist.
--
-- These sit OUTSIDE the voice skill's "exaggeration of a real number"
-- rule. That rule keeps lines about the PLAYER anchored to the snapshot;
-- these are about Yeeper, so there is nothing to drift from. The
-- constraint that replaces it: no claims about the player at all. No
-- motives, no inner life, no numbers. A jabber line that says something
-- about what you own belongs in RULES where the snapshot can check it.
--
-- Plain strings, not functions -- there is no state to consult. Kept
-- long on purpose: the bank is walked in shuffled order and reshuffles
-- only once exhausted, so its length IS the repeat interval.
------------------------------------------------------------
AD.IDLE = {
    ------------------------------------------------------------
    -- Put-upon employee
    ------------------------------------------------------------
    "Right. Chest, legs, wrists. Chest, legs, wrists. That's my whole day.",
    "I didn't apply for this job. I want that noted somewhere.",
    "Do you know how many pairs of boots I've looked at? Neither do I. I stopped counting.",
    "Somebody has to look at every piece you own. It's me. It's always me.",
    "This is the job. This is the actual job.",
    "You go and do the fun part. I'll stay here with the numbers.",
    "No breaks. No lunch. No tabard.",
    "I'd like a word with whoever assigned me to you.",
    "Nobody trains you to look at another man's trousers. You just start.",
    "I have looked at every piece of gear you own, in order, more times than either of us would like said out loud, and I'll do it again in a minute.",
    "I look at gear. That's it. That's the position.",
    "Everyone else in this game gets to swing something.",
    "Back again, are we...",
    "You're my only assignment. Have a think about how that's going for me.",
    "I've looked at every single thing you own. Twice.",
    "Some days I hope you've changed nothing, so there's less to look at.",
    "The pay's the same whatever I say, so.",
    "Long day. Long week. Long expansion.",
    "I've a whole speech about crests. You don't want it. Nobody wants it.",
    "I know everything about your boots. Nobody has ever wanted to know it.",
    "You've no idea how much I leave out.",
    "I could do this in my sleep. If I slept.",
    "Another one. Right. Let me get through it again.",
    "I'm not saying I'm underappreciated. I'm saying nobody has ever thanked me.",
    "Off you go and enjoy yourself. I'll be here. Looking at your gear.",
    "The list doesn't get shorter, you know.",
    "I've got opinions about every piece you own. You get the short version.",

    ------------------------------------------------------------
    -- Jaded Azeroth NPC
    ------------------------------------------------------------
    "Ask a city guard for directions sometime. Ask them twice. Then you'll know.",
    "I've looked at more gear than the quartermaster and he gets a tabard for it.",
    "Everything in this world dies and comes back. Some of us just keep working.",
    "You know what innkeepers do all day? Stand there. I respect it now.",
    "There's a mage in every city opening portals for strangers. Him and me, we're the same.",
    "The auction house takes your gold and you thank it. I tell you the truth and get this.",
    "Every guard in Stormwind has given the same directions ten thousand times. I finally understand them.",
    "Somewhere a flight master is watching someone walk off a cliff, and he's not going to say anything either.",
    "Banker's got a vault. Quartermaster's got a stall. I've got a list of your trousers.",
    "Adventurers. You're all the same. You all want to know if the boots are better.",
    "You've walked the whole world. All I've seen of it is the item level of your boots.",
    "Innkeepers get a fire. Stable masters get animals. I got you.",
    "There's a goblin somewhere charging good money for this exact service.",
    "In another life I'd have been a barber. Simple work, visible results.",
    "The tavern's full of people telling stories about what they did. I'm in here looking at what you're wearing.",
    "I'd take a shift at the auction house. At least there's shouting.",
    "Cooking. Fishing. Archaeology. All of it more exciting than looking at your gear.",
    "Even the target dummies get a rest when the city empties out.",
    "Every adventurer thinks their boots are special. They're all the same boots.",
    "The barber gets a chair, a mirror and a queue. I get a list.",
    "Somewhere out there a bank alt is standing perfectly still in a capital city, and it's having a better time than me.",

    ------------------------------------------------------------
    -- Transmog
    --
    -- Transmogrification replaces how gear LOOKS without touching what
    -- it does. So the player sees a costume and Yeeper reads the item
    -- underneath it -- the one system in the game that is, from his
    -- point of view, deliberate obstruction.
    --
    -- Two kinds of line here, and the difference matters.
    --
    -- The first is the gap between the costume and the item, which is
    -- true for every player and needs no data at all.
    --
    -- The second is straight abuse about how it looks. That is allowed
    -- where a claim about gear would not be, because it is not a claim:
    -- "four unenchanted slots" is falsifiable data the addon must get
    -- right, while "that looks appalling" is unfalsifiable contempt and
    -- obviously a joke. The player can see their own character; nobody
    -- reads this as Yeeper reporting a measurement.
    --
    -- Still off limits: naming a specific piece he cannot see, or any
    -- mechanical claim dressed up as fashion advice. "Clown suit" is
    -- fair game and authentic -- it is what everyone looked like before
    -- transmog existed.
    ------------------------------------------------------------
    "You can hide your helm. You cannot hide an empty socket. I have checked.",
    "Transmog changes the look and nothing else. You're seeing an outfit. I'm seeing the stats underneath it.",
    "Transmog is the only system in this game built specifically to stop me doing my job.",
    "Fashion is the endgame for the rest of you. Mine is a list of numbers.",
    "Everyone in this city is in a costume. I'm the one reading the labels.",
    "They give you fifty outfit slots now. Fifty. Not one of them moves a single stat.",
    "Fifty outfit slots and not one slot for an enchant. Priorities.",
    "Before Cataclysm everybody walked around in whatever dropped and looked like a bag of loot. Some of you have gone back to it on purpose.",
    "The mog vendor charges you what the item sells for. Pennies. Meanwhile I'm here talking about crests.",
    "You'll stand at a mirror for an hour over a shoulder pad. I'll be here. With the numbers.",
    "Adventurers have never once asked me how something looks, and I want credit for not saying anything.",

    -- Straight abuse. Opinion, not measurement -- see above.
    "I can't believe you actually CHOSE that transmog. Somebody sat down and picked it.",
    "You had the whole wardrobe. Every appearance you have ever collected. And that came out.",
    "That mog is a clown suit. I'm sorry. Somebody had to say it.",
    "HAHAHA. You're going out in that mog?",
    "That transmog is a lot of colours for one person.",
    "The helm doesn't go with the shoulders. The shoulders don't go with anything.",
    "Mate. The colours on that mog.",
    "Somewhere in your collection is a set that matches, and you walked straight past it.",
    "Fifty outfit slots and you're using the one that hurts to look at.",
    "You look like you got dressed in a bank vault with the lights off.",
    "People are looking at that transmog. I'm only telling you what I see.",
    "I'd hide that helm. I'd hide most of that mog, honestly.",
    "Take that mog off. Wear literally anything else.",
    "You picked that transmog. In front of everyone. On purpose.",

    ------------------------------------------------------------
    -- Unbothered
    --
    -- Two rules collided here and the first draft broke both.
    --
    -- Nothing is ever said to Yeeper and nothing is ever shown before
    -- this line, so "Fine.", "Checked. Same." and "Nothing's changed"
    -- all lean on something that does not exist -- a question, a
    -- previous line, a baseline the player was never shown.
    --
    -- Worse, most of them ASSERT that the gear is fine. Jabber is not
    -- allowed to claim anything about the player, and that particular
    -- claim can be flatly false: telling someone with four bare slots
    -- that everything is in order is not a joke, it is bad advice.
    --
    -- What is always true, needs no context and claims nothing about the
    -- player: HE has nothing to say. The emptiness is his, not the
    -- gear's.
    ------------------------------------------------------------
    -- Short ones still have to carry their own subject. "Fine." and
    -- "Mm." did not, which is what made them answers to nothing.
    "I've nothing.",
    "I've got nothing for you today.",
    "I've run out of things to say about gear.",
    "I've said everything I have. Twice.",
    "My head is completely empty and the pay is the same.",
    "I had something prepared. It's gone.",
    "I've got no opinions left. They've all been had.",
    "I've said my piece so many times it's worn through.",
    "There's a version of me with something to say. Not today.",
    "Empty. Completely empty. It happens.",
    "I have reached the end of what I know.",

}

--- The most useful true thing, in character -- with an aside mixed in
--- often enough that he is not purely instructional.
--- Returns (text, snapshot) so callers can render numbers themselves.
function AD:Speak()
    local s = self:Snapshot()
    rotation = rotation + 1

    local best
    if s.introDue then
        -- Intro lines outrank everything (p >= 169) and rotate, so the
        -- first few opens are a short introduction rather than the same
        -- greeting repeated.
        local intro = {}
        for _, fn in ipairs(self.INTRO) do
            local ok, result = pcall(fn, s)
            if ok and result then table.insert(intro, result) end
        end
        table.sort(intro, function(a, b) return a.p > b.p end)
        if #intro > 0 then
            return intro[((s.introStep or 1) - 1) % #intro + 1], s
        end
    end
    for _, rule in ipairs(self.RULES) do
        local ok, result = pcall(rule, s)
        if ok and result and (not best or result.p > best.p) then
            best = result
        end
    end

    -- Anything above 60 is a real problem and always leads. This is what
    -- keeps the jabber below from ever costing you something that
    -- matters: however much nonsense he is in the middle of, an urgent
    -- rule takes the slot back the moment the snapshot produces one.
    local urgent = best and best.p >= 60
    if urgent then
        lastWasIdle = false
        return best, s
    end

    -- Otherwise he alternates: say a real thing, then jabber, then a
    -- real thing. He has delivered his piece and is now just talking,
    -- which is the half of a companion that makes it a companion rather
    -- than a readout.
    if not lastWasIdle then
        local idle = NextIdle()
        if idle then
            lastWasIdle = true
            return { text = idle }, s
        end
    end
    lastWasIdle = false

    if rotation % 3 ~= 0 then
        local asides = {}
        for _, fn in ipairs(self.ASIDES) do
            local ok, line = pcall(fn, s)
            local msg = ok and asMessage(line)
            if msg then table.insert(asides, msg) end
        end
        if #asides > 0 then
            return asides[(rotation % #asides) + 1], s
        end
    end
    return best or { text = "" }, s
end

--- Chat output, for tuning the voice without opening the app.
function AD:Print()
    local msg, s = self:Speak()
    print("|cffb885ffMr. Yeeper|r: " .. (msg.text or ""))
    for _, tip in ipairs(msg.tips or {}) do
        print("  |cff808080- " .. tip .. "|r")
    end
    print(("  |cff808080%d upgradeable, %d affordable, %d stale, ilvl %d|r")
        :format(#s.upgrades, s.affordable, s.stale, s.ilvl))
end
