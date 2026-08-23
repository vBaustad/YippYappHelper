local _, ns = ...

------------------------------------------------------------
-- Weekly checklist.
--
-- The things a character is supposed to do each week that the vault does
-- not already account for -- a world boss, a spark, a catalyst charge --
-- and which of them are done.
--
-- Split by how they are known, because the two halves have very
-- different failure modes:
--
--   `auto`   asks the client. Cannot be wrong, cannot be argued with,
--            and needs no storage. Every item that can be answered this
--            way is, and its tick is not clickable.
--
--   manual   the player says so. Needed because a good deal of weekly
--            content leaves no readable trace -- there is no API for
--            "did you kill the world boss on this character" that is
--            reliable across a whole expansion of world boss designs.
--
-- A manual tick is a claim about the player, so it is stored per
-- character, and it expires on its own at the weekly reset rather than
-- being something to remember to clear. A checklist that has to be
-- reset by hand is a checklist that quietly reads as "all done" forever.
------------------------------------------------------------

ns.Weekly = ns.Weekly or {}
local Wk = ns.Weekly

------------------------------------------------------------
-- Storage
------------------------------------------------------------
--- Per character, because almost nothing weekly is account-wide, and a
--- tick that covered every character would silently hide the same job on
--- the four alts that still owe it.
local function charKey()
    local name = UnitName("player") or "?"
    local realm = GetRealmName and GetRealmName() or "?"
    return name .. "-" .. realm
end

--- The store for this character, with anything from last week dropped.
---
--- Expiry is checked on read rather than on a timer. A timer only fires
--- while the addon is loaded, and the common case is logging in on
--- Wednesday to a checklist that has been stale since Tuesday night.
---
--- `resetAt` is an absolute time stamped when a tick is made, from the
--- client's own countdown. Storing the countdown itself would be storing
--- a number that is wrong one second later.
local function store()
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.weekly = YippYappHelperDB.weekly or {}

    local key = charKey()
    local mine = YippYappHelperDB.weekly[key]
    local now = time and time() or 0

    if mine and mine.resetAt and now > 0 and now >= mine.resetAt then
        mine = nil
    end
    if not mine then
        mine = { done = {}, resetAt = nil }
        YippYappHelperDB.weekly[key] = mine
    end
    mine.done = mine.done or {}
    return mine
end

--- When this week's ticks stop counting. Nil if the client cannot say,
--- in which case a tick simply never expires on its own -- wrong, but
--- wrong in the direction the player can see and undo.
local function nextResetAt()
    local left = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
        and C_DateAndTime.GetSecondsUntilWeeklyReset()
    if not (left and left > 0 and time) then return nil end
    return time() + left
end

------------------------------------------------------------
-- Quest flags
--
-- The third way of knowing, and the best one available to this file.
-- The client remembers which quests a character has completed and
-- forgets them at the reset, so a quest id answers "did you do this
-- week's thing" exactly as correctly as the game itself, per character,
-- with nothing stored on our side.
--
-- Most of the manual rows below are manual because nobody had written
-- down the id behind them, not because the answer is unavailable. Each
-- one that gets an id stops being a claim about the player and becomes
-- a fact about the character.
------------------------------------------------------------

--- Whether any of these quests is already completed this week.
---
--- Returns true, false, or nil for "nothing to go on" -- an empty list, or
--- a client with no quest API. That nil is the important one: a row whose
--- ids are not filled in yet keeps its manual tick and behaves exactly as
--- it did before, which is what makes these safe to add one at a time.
---
--- A LIST rather than one id, and ANY completion finishing the row, because
--- that is how the game actually pays these out. A chore is routinely
--- several ids -- per-faction variants, one Blizzard reissues under a new id
--- each patch -- and a weekly allowance is routinely claimable from any of
--- several quests, where taking it from one closes the rest until the reset.
--- Both cases want the same answer: did any of them fire.
---
--- Deliberately NOT a count. An earlier version of this could also count a
--- list, on the reading that several sources meant several pickups. That was
--- a one-week catch-up bump read as the steady state -- the sources are
--- interchangeable routes to a single weekly allowance, so counting them
--- over-counts. Any-of is the whole mechanism.
local function questsDone(ids)
    if not (ids and #ids > 0) then return nil end
    local flagged = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
    if not flagged then return nil end
    for _, id in ipairs(ids) do
        local ok, done = pcall(flagged, id)
        if ok and done then return true end
    end
    -- The call worked and found nothing, which is a real "not yet"
    -- rather than a shrug.
    return false
end

--- The Trovehunter's Bounty, as the client records it.
---
--- USED is a hidden tracking quest: it has no title, no log entry, and no
--- Wowhead page, and it exists so the server can refuse a second bounty in
--- one week. Confirmed by running the check in game on a character that had
--- spent theirs. Hidden ids are the normal way to read a weekly lockout and
--- there is no better source for one -- but they are also unsearchable, so
--- the way it was found is worth recording: /run print(
--- C_QuestLog.IsQuestFlaggedCompleted(86371)).
---
--- SOURCE is the visible weekly that hands the map over, and it backs the
--- fallback path.
local BOUNTY_USED_QUEST   = 86371
local BOUNTY_SOURCE_QUEST = 95520

--- Lady Liadrin's rotating weekly, all sixteen variants.
---
--- Hoisted because TWO rows read it and a copy each would drift: the
--- Liadrin row asks whether the weekly is done, and the spark row asks
--- whether this week's spark is in, and doing one of these is the same
--- event answering both. Two lists would eventually disagree on screen
--- about a single quest hand-in, which is worse than either being
--- slightly wrong on its own.
---
--- Four of the sixteen were checked directly and every one pays a Spark
--- of Tides -- 93910, 93911, 93766 and 98232. The other twelve are
--- assumed to match because they are the same quest family from the same
--- giver. That assumption is what this list rests on, and it is the first
--- thing to test if the spark row ever reads done without a spark.
local LIADRIN_WEEKLY = {
    93890,  -- Midnight: Abundance
    93767,  -- Midnight: Arcantina
    94457,  -- Midnight: Battlegrounds
    93909,  -- Midnight: Delves
    93911,  -- Midnight: Dungeons
    93769,  -- Midnight: Housing
    96727,  -- Midnight: Offworld Showdowns
    93910,  -- Midnight: Prey
    93912,  -- Midnight: Raid
    95843,  -- Midnight: Ritual Sites
    93889,  -- Midnight: Saltheril's Soiree
    93892,  -- Midnight: Stormarion Assault
    98232,  -- Midnight: Vaults of Atal'Utek
    95842,  -- Midnight: Void Assaults
    93913,  -- Midnight: World Boss
    93766,  -- Midnight: World Quests
}

--- Halduron Brightwing's rotating dungeon weekly, all eight variants.
---
--- One dungeon a week, cleared on any difficulty, paying 1000 reputation
--- with a faction you pick at hand-in. The id changes with the dungeon,
--- so the row needs all eight and ResolveQuest picks whichever is live.
---
--- Only ever one at a time. An unfinished one carries over rather than
--- being replaced -- you can hand last week's in this week, you just do
--- not get a new one for it -- so the log holds at most one of these and
--- any-of cannot double-count.
---
--- These are the eight Midnight dungeons, which is NOT the Season 2
--- Mythic+ pool. Four of them -- Murder Row, Den of Nalorakk, The
--- Blinding Vale and Voidscar Arena -- are in DUNGEON_ORDER over in
--- Features/MythicPlus/MythicPlusData.lua; the other four are not, and
--- Altar of Fangs is in the key pool but has no quest here. So some weeks
--- this sends you somewhere your keystone does not care about, and that
--- is the quest being older than the season rather than a mistake.
---
--- Names are comments only, never shown: the row draws the client's own
--- quest title, which is the dungeon name anyway.
local HALDURON_WEEKLY = {
    93751,  -- Windrunner Spire
    93752,  -- Murder Row
    93753,  -- Magisters' Terrace
    93754,  -- Maisara Caverns
    93755,  -- Den of Nalorakk
    93756,  -- The Blinding Vale
    93757,  -- Voidscar Arena
    93758,  -- Nexus-Point Xenas
}

--- Sparks obtained this season, against how many were obtainable.
---
--- Tidal Spark Dust is residue: one grain per Spark of Tides OBTAINED,
--- and it does not go down when the spark is spent. That is the whole
--- reason it can answer a question the sparks themselves cannot --
--- holding zero of them is equally consistent with "not collected" and
--- "collected and already crafted with".
---
--- Read off the client on 2026-08-21 rather than assumed, because
--- guessing at an API's shape is how the high-water query spent a
--- season returning a silent zero:
---
---   name                     Tidal Spark Dust
---   totalEarned              4      the Total the tooltip shows
---   maxQuantity              4      its "Current Season Maximum"
---   useTotalEarnedForMaxQty  true   so totalEarned is the number
---   isAccountWide            false  this character, which is what a
---                                   per-character chore list wants
---   quantityEarnedThisWeek   0      unusable, see below
---   maxWeeklyQuantity        0
---
--- The weekly pair reads zero on a character holding four, so this
--- currency does not meter itself by week and there is no "did you get
--- one THIS week" field to read.
---
--- What there is is better. A season total against a season ceiling
--- says how far behind you are rather than yes or no, and it counts the
--- catch-up routes -- Delves, Mythic+, raids, instanced PvP, some
--- outdoor events -- that a list of seven quest ids had never heard of.
--- Behind is behind whether it happened this week or three weeks ago,
--- and catching up is the part the player can act on.
---
--- nil rather than a guess when the client has not answered: the row
--- falls back to a manual tick, which is what it did before any of this.
local SPARK_DUST = 3509

local function sparkProgress()
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return nil end
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, SPARK_DUST)
    if not (ok and type(info) == "table") then return nil end

    local max = info.maxQuantity or 0
    if max <= 0 then return nil end

    local have = info.useTotalEarnedForMaxQty and info.totalEarned or info.quantity
    return have or 0, max
end

------------------------------------------------------------
-- What `label` is for
--
-- On a row that names its quest, `label` is NOT the row's name -- it is
-- what shows in the one state where there is no quest to name: you have
-- not picked it up and you have not done it. Every other state draws the
-- client's own title instead.
--
-- So a label is written as an INSTRUCTION TO GO AND GET IT, and it names
-- whoever hands it over. "Hand in Aethas Sunreaver's weekly" was exactly
-- backwards: it appeared only on the character who had nothing to hand
-- in. The verb changing between states is the useful part -- "Pick up
-- Aethas Sunreaver's weekly" becomes "Complete Emissary of War" the
-- moment it is in the log.
--
-- Rows with no quest behind them keep a plain imperative, because their
-- label is what shows always rather than only in a gap.
------------------------------------------------------------

------------------------------------------------------------
-- Naming the quest
--
-- A row backed by quest ids can say which quest, and it should: "Complete
-- Purging the Vaults" sends someone to a thing they can search for, where
-- "Fill the Vault of Atal'Utek bar" describes a bar they have to recognise.
--
-- The name comes from the CLIENT and is never written down here. Storing
-- titles would mean shipping an English list that goes stale on the first
-- rename and is wrong on every non-English client from the start. The id is
-- ours; the words are Blizzard's.
------------------------------------------------------------

--- Quest titles the client has handed over, id -> title.
---
--- Cached because GetTitleForQuestID answers nil for a quest the client has
--- not loaded, and the fix is asynchronous: ask for it, carry on drawing,
--- and pick the answer up on QUEST_DATA_LOAD_RESULT. Without a cache the
--- page would re-request on every refresh and never settle.
local titles = {}
local requested = {}

local function questTitle(id)
    if not id then return nil end
    if titles[id] then return titles[id] end

    local Q = C_QuestLog
    if not Q then return nil end

    local title = Q.GetTitleForQuestID and Q.GetTitleForQuestID(id)
    if type(title) == "string" and title ~= "" then
        titles[id] = title
        return title
    end

    -- Not resident yet. Ask once, and let the event bring it back.
    if not requested[id] and Q.RequestLoadQuestByID then
        requested[id] = true
        pcall(Q.RequestLoadQuestByID, id)
    end
    return nil
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("QUEST_DATA_LOAD_RESULT")
    f:SetScript("OnEvent", function(_, _, id, success)
        if not (success and id) then return end
        ------------------------------------------------------------
        -- Only quests THIS file asked about.
        --
        -- QUEST_DATA_LOAD_RESULT is a global event: it reports every
        -- quest any addon or the game itself requests, and questing
        -- addons request them in the hundreds. Without this line a
        -- quest-log addon populating its cache had us relaying its
        -- traffic into a full home-page rebuild, once per quest.
        ------------------------------------------------------------
        if not requested[id] then return end
        local Q = C_QuestLog
        local title = Q and Q.GetTitleForQuestID and Q.GetTitleForQuestID(id)
        if type(title) == "string" and title ~= "" then
            titles[id] = title
            -- The page is only redrawn if the window is open. A title
            -- arriving while it is shut is cached and used next time.
            --
            -- "Open" has to be asked of the window, not of the page.
            -- Shell:RefreshPage only checks that the page is MOUNTED,
            -- and a page stays mounted after the window closes -- so
            -- once the player had visited Home this rebuilt it on a
            -- closed window for the rest of the session.
            if ns.Shell and ns.Shell.RefreshPage
               and ns.Shell.IsOpen and ns.Shell:IsOpen() then
                ns.Shell:RefreshPage("home")
            end
        end
    end)
end

--- How far along a quest in the log is, as "2/3", or nil.
---
--- Only for a single-objective quest. Every weekly these rows point at
--- counts one thing -- three prey hunts, a hundred voidwhispers -- and a
--- row that tried to summarise four objectives in the width of a checklist
--- line would be summarising them badly.
local function questProgress(id)
    local Q = C_QuestLog
    if not (id and Q and Q.GetQuestObjectives) then return nil end
    local ok, objectives = pcall(Q.GetQuestObjectives, id)
    if not (ok and type(objectives) == "table" and #objectives == 1) then return nil end
    local o = objectives[1]
    local have, need = o.numFulfilled, o.numRequired
    if not (have and need and need > 1) then return nil end
    -- The client's own sentence for it ("Prey Hunts completed: 1/3") comes
    -- back too, for the hover. The short form is all that fits on the row.
    return ("%d/%d"):format(have, need), o.text
end

--- Which of a row's quests is the one worth naming, and what state it is in.
---
--- Order matters. The quest in the log wins, because that is the one the
--- player can act on tonight and the one whose progress means anything. Only
--- if none is in the log does a completed one get named, which is what turns
--- a ticked row from "done" into "you did Midnight: Prey".
---
--- Returns id, state ("active" or "done"), title, progress. Everything after
--- id can be nil: a title the client has not loaded yet is a redraw away,
--- and the row has its own label to fall back on meanwhile.
function Wk:ResolveQuest(item)
    -- Opt-in, because "has quest ids" and "is a quest" are not the same
    -- thing. The spark row is answered BY quests and is not one: it asks
    -- whether this week's spark is in, and any of seven routes can settle
    -- that. Letting it name a route put "Complete Trailing Xal'atath" on a
    -- row about an item, picked for no better reason than being first in
    -- the array -- which is a coin toss presented as a fact.
    if not (item and item.namesQuest) then return nil end

    local ids = item.quests
    if not (ids and #ids > 0) then return nil end
    local Q = C_QuestLog
    if not Q then return nil end

    if Q.GetLogIndexForQuestID then
        for _, id in ipairs(ids) do
            local ok, idx = pcall(Q.GetLogIndexForQuestID, id)
            if ok and idx then
                local short, full = questProgress(id)
                return id, "active", questTitle(id), short, full
            end
        end
    end

    if Q.IsQuestFlaggedCompleted then
        for _, id in ipairs(ids) do
            local ok, done = pcall(Q.IsQuestFlaggedCompleted, id)
            if ok and done then return id, "done", questTitle(id) end
        end
    end

    return nil
end

------------------------------------------------------------
-- The list
------------------------------------------------------------
--- One test for membership: does skipping it this week cost you
--- something you cannot get back?
---
--- Everything here expires at the reset. The crest allowance does not
--- carry over, the bounty map is consumed or lost, the world boss
--- relocks, the quest resets. Miss one and the week is simply gone.
---
--- That rule is what threw out the rows this section had accumulated.
--- Catalyst charges accrue and keep accruing -- an unspent one is
--- waiting for you, not lost -- so "spend a catalyst charge" is a thing
--- you may want to do, which is not the same as a thing this week is
--- asking of you. Same for every currency the client happens to meter.
--- A checklist that lists what you COULD do has no end and stops being
--- read; one that lists what expires tonight is seven lines and gets
--- read every time.
---
--- Things that accumulate are not absent from the addon -- catalyst
--- charges and currency balances are on the rail and the gear page,
--- where a balance belongs. They are absent from the list of chores.
---
--- Items are ordered by how much they are worth doing, not by category.
---
--- `auto` returns true (done), false (outstanding) or nil ("cannot
--- tell"), and nil falls back to the manual tick. Three answers rather
--- than two on purpose: a check that cannot tell has to say so, because
--- reporting "not done" for something undetectable would nag forever.
local ITEMS = {
    {
        id = "crests",
        label = "Cap this week's crests",
        detail = "How much of the crest ceiling you have actually taken, "
            .. "across every track. The ceiling rises each week; what you "
            .. "leave behind does not come back.",
        category = "crests",

        -- The one row on this list that is a matter of degree rather than
        -- of yes or no. Every other entry is a thing you did or did not do;
        -- this one is five allowances filling at different rates, and
        -- "not done" says nothing about whether that means ten crests short
        -- or four hundred. So it carries a fraction and the page draws it.
        --
        -- Summed across tracks rather than reported per track. Five bars
        -- would be a page of its own -- which the rail already is -- and
        -- what belongs on a checklist is the single number that answers
        -- "how much of this week's ceiling have I actually taken".
        progress = function()
            if not ns.GetCrestWeeklyInfo or not ns.CRESTS then return nil end
            local have, max = 0, 0
            for _, def in ipairs(ns.CRESTS) do
                local info = ns:GetCrestWeeklyInfo(def.track)
                local cap = info and info.weeklyMax or 0
                if cap > 0 then
                    max = max + cap
                    -- Clamped: a track can report more earned than its cap
                    -- after a catch-up, and one overfull track must not
                    -- lend its overflow to a track still empty.
                    local earned = info.earnedThisWeek or 0
                    have = have + (earned > cap and cap or earned)
                end
            end
            if max == 0 then return nil end
            return have, max
        end,

        auto = function()
            if not ns.GetCrestWeeklyInfo or not ns.CRESTS then return nil end
            local anyKnown = false
            for _, def in ipairs(ns.CRESTS) do
                local info = ns:GetCrestWeeklyInfo(def.track)
                if info and (info.weeklyMax or 0) > 0 then
                    anyKnown = true
                    if (info.earnedThisWeek or 0) < info.weeklyMax then
                        return false
                    end
                end
            end
            if not anyKnown then return nil end
            return true
        end,
    },
    {
        id = "spark",
        label = "Collect this week's spark",
        detail = "One a week, from whichever source reaches you first -- "
            .. "any of the Silvermoon weeklies, or the War Mode one. Fall "
            .. "behind and max-level content pays catch-up sparks. Most "
            .. "crafted gear takes two.",
        category = "crests",

        -- Recorded because it is the thing the row is about, NOT because
        -- it decides the answer. Counting Sparks of Tides in the bags
        -- cannot: holding zero is equally consistent with "not collected"
        -- and "collected and already spent", and the second is the normal
        -- case for anyone who crafts.
        itemID = 274476,   -- Spark of Tides

        -- The answer comes from Tidal Spark Dust -- see sparkProgress
        -- above for what the client actually returns and why the weekly
        -- fields are no use.
        --
        -- This replaced an inference over seven quest ids: Liadrin's
        -- five, Trailing Xal'atath and the two War Mode ones, any of
        -- which finishing meant the spark was in. That worked, and was
        -- wrong at both edges. It could not see the catch-up routes, so
        -- somebody who made up a missed spark in a delve still read as
        -- owing one. And it needed 96995 Turn Back the Surge held OUT by
        -- hand, because the quest lists Spark of Tides among its rewards
        -- and does not award one -- a reward list being what a quest
        -- claims to give rather than what it gives.
        --
        -- The residue count has no edges to get wrong. It is the number
        -- of sparks this character has been paid, from anywhere, ever.
        auto = function()
            local have, max = sparkProgress()
            if not have then return nil end
            return have >= max
        end,

        -- No `progress` hook, though sparkProgress would feed one
        -- directly. Only the crest row measures itself on this page, and
        -- Tools/loadcheck.py enforces that: the renderer draws a bar for
        -- any row carrying a fraction, so a second one is a visible
        -- change to the page rather than a change to this row. Worth
        -- doing on purpose, not as a side effect of fixing the answer.
    },
    {
        id = "bountymap",
        label = "Spend your Trovehunter's Bounty",
        detail = "Use it inside a tier 8 or higher delve for a guaranteed "
            .. "Hero-track piece. It comes from the Vaults weekly below, and "
            .. "it does not survive the reset.",
        category = "delves",

        -- Spelled as the item is: one word. Taken from 95520's reward
        -- list, which is the item's own name rather than a guide writing
        -- about it. Change it back if the game disagrees.
        --
        -- Fully automatic, and the good half of it is a direct
        -- observation rather than an inference.
        --
        -- 86371 is the client's own record of the map having been USED --
        -- a hidden tracking quest, which is how Blizzard enforces a
        -- once-a-week item. Verified in game: it reads true on a character
        -- that has spent theirs. That beats anything derived from what is
        -- in the bag, because it answers the actual question instead of
        -- one adjacent to it, and it does not confuse a map that was
        -- destroyed or vendored with one that was used.
        --
        -- The bag is still consulted FIRST, and that ordering is what
        -- makes the row safe against the one thing not yet verified about
        -- 86371: whether it clears at the weekly reset. If it turns out to
        -- be a flag that never resets, holding next week's map still reads
        -- as "not spent" and overrides it. The stale case is a row that is
        -- briefly ticked between the reset and earning the next map, which
        -- corrects itself the moment the map lands.
        --
        -- 95520 is kept underneath both as the fallback it always was:
        -- earned this week and no longer holding it means used. It covers
        -- a client where the tracking flag is absent or has changed id.
        --
        --   holding             -> not spent, whichever week it came from
        --   used flag           -> spent
        --   earned, not holding -> spent
        --   none of those       -> no map yet; outstanding, and the row
        --                          below says how to get one
        --
        -- Worth a row regardless: one guaranteed Hero piece a week, it
        -- expires with the reset, and it is the easiest thing on this list
        -- to forget because nothing in the game nags you.
        itemID = 274374,   -- Trovehunter's Bounty
        auto = function()
            -- Bank and warband bank included: the map is bind-on-pickup
            -- and both of those hold bound items now, so a count that
            -- omitted them would call a parked map a spent one.
            local held = 0
            if C_Item and C_Item.GetItemCount then
                held = C_Item.GetItemCount(274374, true, false, true, true) or 0
            end
            if held > 0 then return false end

            local Q = C_QuestLog
            local flagged = Q and Q.IsQuestFlaggedCompleted
            if not flagged then return false end

            if flagged(BOUNTY_USED_QUEST) then return true end
            if flagged(BOUNTY_SOURCE_QUEST) then return true end
            return false
        end,
    },
    {
        id = "vaultweekly",
        -- Only the fallback: with the quest resolved the row draws the
        -- client's own title instead, which is the actual name of the
        -- thing and searchable. This is what shows before the client has
        -- loaded the quest, or on a character that has never seen it.
        label = "Pick up the Vaults of Atal'Utek weekly",
        detail = "In the Vaults of Atal'Utek. Temple patrols, strikes, "
            .. "incursions and ancient foes all count towards it. Hands over "
            .. "the Trovehunter's Bounty.",
        category = "delves",
        -- Listed above the map it grants, because doing this is how you
        -- get one.
        --
        -- Confirmed from the quest's own reward list rather than from a
        -- guide: 95520 is in the Vaults of Atal'Utek, its objectives are
        -- the four activities named above, and it hands over the
        -- Trovehunter's Bounty -- which is the row below this one, and the
        -- reason this one sits above it.
        --
        -- A flag answers "filled it" and not "halfway", which is the only
        -- state this row asks about. Partial progress is available now that
        -- there is an id: C_QuestLog.GetQuestObjectives on 95520 returns the
        -- counters. Left alone until somebody wants the row to show them.
        --
        -- Whether it is weekly is not stated anywhere I can check, and it
        -- does not need to be. A flag that never clears reads as done
        -- forever, which is the correct answer for a one-time quest and a
        -- quiet row rather than a wrong one.
        namesQuest = true,
        quests = { BOUNTY_SOURCE_QUEST },   -- Purging the Vaults
    },
    -- The prey row is gone, and it was the last hand-ticked one.
    --
    -- It read "Run this week's prey hunts" on the assumption that prey
    -- hunts were a weekly-capped activity of their own. They are not a
    -- separate chore: 93910 Midnight: Prey is one of the sixteen variants
    -- Lady Liadrin offers, you take ONE of the four or five she shows you,
    -- and that is the week. So prey hunts are what one possible Liadrin
    -- weekly asks for, and the row below hers already covers doing it.
    --
    -- Wired to 93910 it would have been worse than manual: unticked AND
    -- unclickable on every week the variant was not offered. Bring it back
    -- only if prey hunts turn out to carry a cap independent of the quest,
    -- which is what its detail line used to claim and nothing confirmed.

    {
        id = "worldboss",
        label = "Kill the weekly world boss",
        -- The map's own skull, most specific name first. These live in
        -- the vignette set, which is what the world map draws for a boss
        -- standing in a zone, and the raid-target skull is the fallback
        -- because it is a plain texture path and those do not move.
        iconAtlas = {
            "Vignetteskullelite",
            "Vignetteskull",
            "VignetteKillElite",
            "VignetteKill",
            "worldquest-icon-boss",
        },
        iconTexture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
        detail = "Tidebound Grotto. Instanced rather than standing out in "
            .. "the world, which is why this row can read it from your "
            .. "lockouts instead of asking you.",
        category = "delves",
        -- Detectable after all, because it is instanced.
        --
        -- A boss standing in a zone leaves nothing an addon can read
        -- without a quest id per boss per patch, which is why this was
        -- manual. An instanced one takes a saved lockout, and lockouts
        -- are enumerable -- so the answer is in GetSavedInstanceInfo
        -- rather than in a table someone has to maintain.
        --
        -- Matched on name because the instance id is not something I can
        -- verify from here, and a wrong id silently matches nothing.
        auto = function()
            if not (GetNumSavedInstances and GetSavedInstanceInfo) then return nil end
            local n = GetNumSavedInstances()
            if not n then return nil end
            for i = 1, n do
                local name, _, reset, _, locked = GetSavedInstanceInfo(i)
                if name and tostring(name):find("Tidebound Grotto")
                    and locked and (reset or 0) > 0 then
                    return true
                end
            end
            -- No lockout is a real "not yet", not a shrug: the call
            -- worked and simply found nothing saved.
            return false
        end,
    },
    ------------------------------------------------------------
    -- The two weekly quest givers
    --
    -- One row each, not one row per quest. Both NPCs offer a SELECTION
    -- each week and a character completes ONE of it -- Lady Liadrin
    -- shows four of her sixteen -- so a row per quest would report three
    -- permanent failures every week for work nobody was ever offered.
    --
    -- What the player actually wants to know is "have I done this
    -- week's", and any-of answers it exactly: whichever variant they
    -- were shown, completing it sets that variant's flag, and no other
    -- flag in the list needs to be true.
    --
    -- This replaces a row that read "Hand in this week's quest -- the
    -- recurring quest in the season's zone", written before anybody knew
    -- which quest that was. It turned out to be two givers, so it is two
    -- rows.
    ------------------------------------------------------------
    {
        id = "liadrinweekly",
        label = "Choose a weekly from Lady Liadrin",
        detail = "Lady Liadrin, Silvermoon City. She shows you four or five "
            .. "and you accept one; whichever you take is your week, and it "
            .. "pays a Spark of Tides.",
        category = "delves",
        namesQuest = true,
        quests = LIADRIN_WEEKLY,
    },
    {
        id = "halduronweekly",
        -- The fallback only. With the quest resolved the row draws the
        -- client's title instead, which names the actual dungeon.
        label = "Pick up Halduron's dungeon weekly",
        detail = "Silvermoon City. One dungeon a week, any difficulty -- 1000 rep with a faction you choose.",
        -- Filed under Mythic+ because it is a dungeon, not because it
        -- needs a key. Any difficulty counts, which the detail says.
        category = "mplus",
        namesQuest = true,
        quests = HALDURON_WEEKLY,
    },
    {
        id = "vereesaweekly",
        label = "Pick up Vereesa's weekly in Silvermoon",
        detail = "Vereesa Windrunner, Silvermoon City by the Great Vault. "
            .. "A hundred Fading Voidwhispers from dungeons, delves, treasures "
            .. "and rares. Pays a Spark of Tides.",
        category = "delves",
        -- One quest, not a family: she is the only giver here with nothing
        -- to rotate. So this row always names the same thing, which is fine
        -- -- it still draws the client's own title rather than the label
        -- above, and the label is only what shows before the quest loads.
        --
        -- IT COMPLETES PASSIVELY, and that is worth knowing before reading
        -- this row as broken. A hundred Fading Voidwhispers off dungeons,
        -- delves, treasures and rares is a thing an active week does to you
        -- rather than a thing you sit down to do, so the row turns itself
        -- green on a character whose owner does not remember visiting her.
        -- Confirmed in game: the flag read true for someone who had done it
        -- without noticing. A ticked row here is the checklist being right,
        -- not the flag failing to clear.
        namesQuest = true,
        quests = { 98172 },   -- Trailing Xal'atath
    },
    {
        id = "aethasweekly",
        label = "Pick up Aethas Sunreaver's weekly",
        detail = "Archmage Aethas Sunreaver, Silvermoon City. Timewalking, "
            .. "battleground and dungeon weeklies. A separate week's work to "
            .. "Liadrin's, and none of it pays a spark.",
        category = "delves",
        -- A different set entirely: the Timewalking "Path Through Time"
        -- quests, the Call to / Emissary / Arena weeklies, and a
        -- three-week training chain. Two were checked for a spark and
        -- neither pays one, which is what makes this its own row rather
        -- than more ids on the one above.
        --
        -- Weekly only. He also gives a three-week training chain and
        -- Gladiator's Distinction, and the client types those PvP rather
        -- than Weekly -- a chain that advances once a week is not a weekly
        -- quest, and any-of over the two together would let week 1 of a
        -- training chain tick the row for a weekly nobody did.
        --
        -- The eight Timewalking entries are typed Weekly and stay, but
        -- they are only OFFERED during a Timewalking week. That is fine
        -- for any-of and it is the part to suspect first if this row ever
        -- reads wrong.
        namesQuest = true,
        quests = {
            93497,  -- A Soaring Path Through Time
            93607,  -- An Original Path Through Time
            93608,  -- A Burning Path Through Time
            93611,  -- A Shattered Path Through Time
            93612,  -- A Shrouded Path Through Time
            93613,  -- A Savage Path Through Time
            93627,  -- A Scarred Path Through Time
            93628,  -- A Shadowed Path Through Time
            93593,  -- A Call to Battle
            93595,  -- A Call to Delves
            93598,  -- Emissary of War        (Weekly Dungeon)
            93599,  -- The Very Best
            93600,  -- The Arena Calls
            93605,  -- The World Awaits
        },
    },
}

Wk.ITEMS = ITEMS

------------------------------------------------------------
-- Reading and writing
------------------------------------------------------------
--- Whether an item is done, and whether the player is allowed to say.
---
--- Returns done, manual. `manual` is true when the answer came from the
--- player rather than the client, which is what the UI needs in order to
--- decide whether the row can be clicked.
function Wk:IsDone(item)
    -- Quest flags first. Where one exists it is the client's own record
    -- of this character's week, which beats both a bespoke auto check
    -- and anything the player has claimed.
    local answer = questsDone(item.quests)
    if answer ~= nil then return answer, false end

    if item.auto then
        local ok, autoAnswer = pcall(item.auto)
        if ok and autoAnswer ~= nil then return autoAnswer and true or false, false end
    end
    return store().done[item.id] and true or false, true
end

--- Toggle a manual tick. Auto items ignore this: the client's answer is
--- not the player's to override, and letting them do it would produce a
--- checklist that disagrees with the game.
function Wk:Toggle(item)
    local _, manual = self:IsDone(item)
    if not manual then return end

    local mine = store()
    if mine.done[item.id] then
        mine.done[item.id] = nil
    else
        mine.done[item.id] = true
        -- Stamped at the moment of ticking rather than on login, so a
        -- session that spans the reset still expires correctly.
        mine.resetAt = mine.resetAt or nextResetAt()
    end
end

--- The whole list with its state resolved, for rendering.
---
--- ITEMS and nothing else. There used to be a second half: every
--- currency the client caps weekly, discovered rather than named, on
--- the reasoning that the client already knows which currencies it caps
--- and a written-down list goes wrong the day a patch ships.
---
--- That reasoning was right about currencies and wrong about chores.
--- Discovery finds what the game meters, which is not what a player
--- owes -- so the list filled with rows like "Cap Shard of Dundun",
--- capped by the client and cared about by nobody, and every one of
--- them counted against the "N of N left" tally above the section. A
--- checklist you scroll past is worse than a shorter one that is wrong
--- about the edges, because the short one still gets read.
---
--- Currency caps have not gone anywhere -- they live in the rail, on
--- every page, which is where a meter belongs. What is left here is
--- eight deliberate entries, each of which someone decided was worth a
--- line.
function Wk:GetList()
    local out = {}
    local all = ITEMS

    for i, item in ipairs(all) do
        local done, manual = self:IsDone(item)
        local questID, questState, title, progress, objective = self:ResolveQuest(item)

        -- A row that measures itself rather than ticking. Guarded like
        -- every other reach into game data on this page: a progress
        -- function that throws leaves the row as an ordinary tick rather
        -- than taking the dashboard down with it.
        local fraction, fractionText
        if item.progress then
            local ok, have, max = pcall(item.progress)
            if ok and have and max and max > 0 then
                fraction = have / max
                if fraction > 1 then fraction = 1 end
                fractionText = ("%d%%"):format(math.floor(fraction * 100 + 0.5))
            end
        end
        out[i] = {
            id = item.id, label = item.label, detail = item.detail,
            category = item.category, done = done, manual = manual,
            -- Present only when a quest was resolved AND the client has
            -- handed over its name, so a caller can test `questTitle` to
            -- decide whether to draw a quest or fall back to the label.
            questID = questID, questState = questState,
            questTitle = title, questProgress = progress,
            questObjective = objective,
            -- What goes in front of the name, whatever state the quest is
            -- in. Overridable per row for the one that eventually wants a
            -- different verb; nothing needs it yet.
            questVerb = item.questVerb or "Complete",
            -- 0..1 and its percentage, present only on a row that reports
            -- a degree. Everything else is a tick and has neither.
            fraction = fraction, fractionText = fractionText,
            item = item,
        }
    end
    return out
end

--- Nothing here can be hidden any more, and the answer says so.
---
--- Hiding existed to let the player delete the noise that discovery
--- produced. With discovery gone there is no noise to delete: every row
--- is a deliberate entry, and a filter that could quietly remove one is
--- a settings screen rather than a nuisance filter. Kept as a function
--- that refuses rather than deleted outright, because a saved variable
--- from an older install still names rows that no longer exist and the
--- call site should get `false` rather than an error.
function Wk:Hide()
    return false
end

--- How many are outstanding, for the section heading.
function Wk:CountOutstanding()
    local left, total = 0, 0
    for _, row in ipairs(self:GetList()) do
        total = total + 1
        if not row.done then left = left + 1 end
    end
    return left, total
end


------------------------------------------------------------
-- Finding the ids
------------------------------------------------------------
--- Prints the quest log with ids, grouped by the zone headers the log
--- already groups it by.
---
--- The `quests` lists above cannot be filled in from outside the game.
--- Quest ids are not derivable, a wrong one does not error -- it reads
--- as "never completed" and nags all week -- and the third-party sites
--- that publish them are exactly the sourcing that has put wrong facts
--- in this addon before. The client knows, so ask the client: pick this
--- week's chores up, run this, and copy the numbers out.
---
--- Weekly entries are marked, because that is the frequency every row
--- in this file is looking for and it is the client saying so rather
--- than us guessing from the name.
---
--- Zone comes from the log's own headers. It is the one fact about a
--- quest that cannot be recovered later from an id alone, so it is
--- worth capturing at the same time as the number.
--- @param filter string|nil quest id, or words from a quest's title.
--- Given one, the dump narrows to the matching quests and prints their
--- objectives too -- the criteria a tracking row would have to read.
function Wk:DumpQuestLog(filter)
    local Q = C_QuestLog
    if not (Q and Q.GetNumQuestLogEntries and Q.GetInfo) then
        print("|cffff5555YippYapp:|r no quest log API on this client")
        return
    end

    local total = Q.GetNumQuestLogEntries()
    if not total or total == 0 then
        print("|cff00ff00YippYapp|r quest log is empty")
        return
    end

    -- A number is an id and matches exactly; anything else is matched
    -- against the title as plain text, so "world" finds "The World
    -- Awaits" without the caller escaping anything.
    filter = strtrim(filter or "")
    local wantID   = tonumber(filter)
    local wantText = (filter ~= "" and not wantID) and strlower(filter) or nil
    local detail   = filter ~= ""

    local weeklyFreq = Enum and Enum.QuestFrequency and Enum.QuestFrequency.Weekly
    local dailyFreq  = Enum and Enum.QuestFrequency and Enum.QuestFrequency.Daily

    print("|cff00ff00=== quest log ===|r")
    local shown = 0
    for i = 1, total do
        local ok, info = pcall(Q.GetInfo, i)
        if ok and info then
            if info.isHeader then
                -- Zone headers are only worth printing when the whole
                -- log is; against a filter they are noise between hits.
                if not detail then
                    print("|cffffd100" .. tostring(info.title or "?") .. "|r")
                end
            elseif info.questID then
                local match = true
                if wantID then
                    match = info.questID == wantID
                elseif wantText then
                    match = strfind(strlower(tostring(info.title or "")), wantText, 1, true) ~= nil
                end

                if match then
                    local mark = ""
                    if weeklyFreq and info.frequency == weeklyFreq then
                        mark = " |cff00ff00[weekly]|r"
                    elseif dailyFreq and info.frequency == dailyFreq then
                        mark = " |cff888888[daily]|r"
                    end
                    print(("  %d  %s%s"):format(info.questID, tostring(info.title or "?"), mark))
                    shown = shown + 1
                    if detail then
                        Wk:DumpQuestObjectives(info.questID)
                        Wk:DumpQuestRewards(info.questID)
                    end
                end
            end
        end
    end

    if shown == 0 then
        print(("|cff00ff00YippYapp|r nothing in the log matches \"%s\"."):format(filter))
        return
    end
    if detail then
        print(("|cff00ff00YippYapp|r %d quest(s) matched. The number on the "
            .. "left is the quest id; the number in brackets is the "
            .. "objective's index."):format(shown))
    else
        print(("|cff00ff00YippYapp|r %d quest(s). The weekly ones are what the "
            .. "checklist wants. Add a name or an id for its objectives."):format(shown))
    end
end

--- One quest's objectives, in the order GetQuestObjectives returns them.
---
--- The index is printed because that is how the objectives are addressed
--- and it is not readable off a guide or a Wowhead page -- a quest whose
--- text lists three things can hand back one criterion, or three in an
--- order nobody would have guessed. Type is printed for the same reason:
--- "monster" counts kills, "progressbar" hands back a percentage in
--- numFulfilled, and a row written for one is wrong for the other.
function Wk:DumpQuestObjectives(id)
    local Q = C_QuestLog
    if not (id and Q and Q.GetQuestObjectives) then return end

    if Q.ReadyForTurnIn and Q.ReadyForTurnIn(id) then
        print("       |cff00ff00ready to turn in|r")
    end

    local ok, objectives = pcall(Q.GetQuestObjectives, id)
    if not ok or not objectives or #objectives == 0 then
        -- Real, and worth saying rather than printing nothing: some
        -- quests carry no criteria at all and are done or not done.
        print("       |cff888888no objectives -- this one is a flag, not a count|r")
        return
    end

    for oi, o in ipairs(objectives) do
        print(("       [%d] %s |cff888888(%s, %s/%s%s)|r"):format(
            oi,
            tostring(o.text or "?"),
            tostring(o.type or "?"),
            tostring(o.numFulfilled or 0),
            tostring(o.numRequired or 0),
            o.finished and ", done" or ""))
    end
end

--- Which of our own currencies an id belongs to, as a short label, or nil.
---
--- So a crest reward reads as "Hero Mistcrest" in the dump rather than as
--- a bare 3445 the reader has to go and look up. The names come from
--- Features/Gear/Crests.lua, which is where they are already recorded and
--- already re-checked each season.
local function knownCurrency(id)
    if not id then return nil end
    for _, crest in ipairs(ns.CRESTS or {}) do
        if crest.id == id then return crest.name end
        for _, candidate in ipairs(crest.candidates or {}) do
            if candidate == id then return crest.name .. " (dead twin)" end
        end
    end
    for _, crest in ipairs(ns.LEGACY_CRESTS or {}) do
        if crest.id == id then return crest.name .. " (season 1)" end
    end
    if id == ns.CATALYST_CURRENCY_ID then return "Catalyst charge" end
    return nil
end

--- What the client says this quest pays.
---
--- Worth asking the client rather than a database. A quest retuned in the
--- current patch reads as its old self on every site for weeks, and a
--- reward that scales -- with level, with season, with which difficulty
--- flagged it -- is one number there and a different one here. The client
--- is answering about this character tonight, which is the only answer a
--- reward row can be built on.
---
--- The quest log is pointed at the entry first, and put back afterwards.
--- The reward getters look like one family and are two: GetNumQuestLogRewards
--- takes a quest id and answers about the id it is handed, while
--- GetNumQuestLogRewardCurrencies answers about whichever entry the log has
--- selected and ignores the argument. Reading both without selecting is how
--- a dump comes back holding a quest's items and none of its currencies.
function Wk:DumpQuestRewards(id)
    if not id then return end

    local Q = C_QuestLog
    local restore = Q and Q.GetSelectedQuest and Q.GetSelectedQuest()
    if Q and Q.SetSelectedQuest then pcall(Q.SetSelectedQuest, id) end

    -- A getter that is not there is reported, not counted as zero.
    --
    -- The two are indistinguishable from here: either way the reward
    -- goes unprinted and the quest reads as paying nothing. That is how
    -- this dump came back holding 93753's money and none of its five
    -- reputation choices, and said nothing was wrong. A diagnostic that
    -- cannot tell "pays nothing" from "asked the wrong question" is
    -- worse than no diagnostic, because it is believed.
    local missing = {}
    local function count(fn, name, ...)
        if type(fn) ~= "function" then
            missing[#missing + 1] = name .. " (no such function)"
            return 0
        end
        local ok, n = pcall(fn, ...)
        if not ok then
            missing[#missing + 1] = name .. " (errored)"
            return 0
        end
        return tonumber(n) or 0
    end

    local printed = false
    local function header()
        if printed then return end
        printed = true
        print("       |cffffd100rewards|r")
    end

    -- One currency reward, however this client hands it back. Read both
    -- shapes because the getter has had two: a flat
    -- name/texture/quantity/id list, and a single table. Guessing wrong
    -- fails silently -- every field reads nil and the line prints "?".
    local function currency(j, isChoice)
        local ok, a, _, c, d = pcall(GetQuestLogRewardCurrencyInfo, j, id, isChoice)
        if not ok then return end
        local name, quantity, currencyID
        if type(a) == "table" then
            name       = a.name
            quantity   = a.totalRewardAmount or a.quantity or a.numItems
            currencyID = a.currencyID
        else
            name, quantity, currencyID = a, c, d
        end
        if not currencyID then return end
        header()
        local known = knownCurrency(currencyID)
        print(("         %scurrency %d x%s  %s%s"):format(
            isChoice and "choice " or "",
            currencyID,
            tostring(quantity or "?"),
            tostring(name or "?"),
            known and (" |cff00ff00<- " .. known .. "|r") or ""))
        return true
    end

    -- Currencies first: on a weekly, they are the reason to do it.
    for j = 1, count(GetNumQuestLogRewardCurrencies, "GetNumQuestLogRewardCurrencies", id) do currency(j) end

    for j = 1, count(GetNumQuestLogRewards, "GetNumQuestLogRewards", id) do
        local ok, name, _, quantity, _, _, itemID = pcall(GetQuestLogRewardInfo, j, id)
        if ok and itemID then
            header()
            print(("         item %d x%s  %s"):format(itemID, tostring(quantity or 1), tostring(name or "?")))
        end
    end

    -- The pick-one list, which is where the reputation weeklies live.
    --
    -- Two readers per slot, because a choice is not always an item. A
    -- quest offering five reputations offers five currencies, and
    -- GetQuestLogChoiceInfo describes items -- it hands back no itemID
    -- for a currency slot, so an item-only loop prints nothing at all
    -- and the quest reads as paying nothing. Ask for the item first,
    -- and fall back to the currency reader with isChoice set.
    --
    -- The count has to include currencies or the loop never reaches
    -- them: without the flag GetNumQuestLogChoices answers with the item
    -- choices only, which for these quests is zero.
    for j = 1, count(GetNumQuestLogChoices, "GetNumQuestLogChoices", id, true) do
        local ok, name, _, quantity, _, _, itemID = pcall(GetQuestLogChoiceInfo, j)
        if ok and itemID then
            header()
            print(("         choice item %d x%s  %s"):format(itemID, tostring(quantity or 1), tostring(name or "?")))
        else
            currency(j, true)
        end
    end

    local money = count(GetQuestLogRewardMoney, "GetQuestLogRewardMoney", id)
    if money > 0 then
        header()
        local ok, coins = pcall(GetCoinTextureString, money)
        print("         money " .. ((ok and coins) or (money .. "c")))
    end

    local xp = count(GetQuestLogRewardXP, "GetQuestLogRewardXP", id)
    if xp > 0 then
        header()
        print("         xp " .. xp)
    end

    -- The selection is a thing the player can see, so hand it back.
    if Q and Q.SetSelectedQuest and restore then pcall(Q.SetSelectedQuest, restore) end

    if not printed then
        -- Not the same as "pays nothing". Reward data arrives with the
        -- quest and a quest the client has not fully loaded answers zero
        -- to all of the above, so say which of the two this might be.
        print("       |cff888888no rewards reported -- either it pays none, or the "
            .. "client has not loaded this quest's data yet|r")
    end

    if #missing > 0 then
        print("       |cffff5555could not be read on this client:|r |cff888888"
            .. table.concat(missing, ", ") .. "|r")
    end
end
