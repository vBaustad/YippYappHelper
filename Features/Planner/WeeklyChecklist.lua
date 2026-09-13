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

--- Lady Liadrin's weekly is ONE quest, and this is not it.
---
--- 93744 Unity Against the Void is the weekly: a meta quest she hands over
--- that offers a choice of the Midnight: X quests below and completes
--- itself the moment you finish any one of them. The sixteen are its
--- CHILDREN, not sixteen weeklies, which is the thing this file had wrong.
--- Source: warcraft.wiki.gg/wiki/Unity_Against_the_Void, and the id shows
--- up flagged alongside its children on a character who has done it.
---
--- That explains the flags. A meta closing closes every option it was
--- offering, so one hand-in flags the lot -- read in game 2026-08-26, the
--- second week of the season, where eleven of the sixteen were flagged on
--- a character who could have done at most one. Any-of over the children
--- therefore answers "has the meta ever closed", never "is this week's
--- done", so the children NAME the row and LIADRIN_META answers it.
---
--- All sixteen variants below.
---
--- ONE EXCLUSIVE GROUP, which is the whole difficulty in reading them.
--- She shows four or five, you accept one, and that hand-in closes the
--- rest for the week -- which the client records by flagging all sixteen
--- complete, not only the one you did. So any-of over this list does not
--- answer "which did I do this week". It answers "is the group closed",
--- and nothing narrower is available from these ids.
---
--- AND THEY DO NOT CLEAR AT RESET, which is why nothing here answers the
--- row. Read in game 2026-08-26, the second week of the season: eleven of
--- the sixteen were flagged on a character who could have done at most one
--- or two, they were still flagged after the reset, and Lady Liadrin had
--- nothing to offer that character while an alt on the same account could
--- take one freely.
---
--- So any-of over this list does not mean "this week is done". It means
--- "this character has taken one at some point", which is true from week
--- one onward and stays true. A row answered by that is green forever.
---
--- Hence questsNameOnly on the row: the ids name the quest while it is in
--- the log and the tick is the player's. Replacing that with a real answer
--- needs a hidden per-week lockout id in the style of BOUNTY_USED_QUEST
--- above. Narrowed once already: of the unnamed ids that scan as complete
--- near this family, 93891, 93893, 93908 and 93916-93919 are set on a
--- locked character and clear on one she will still talk to. 93880 and
--- 93881 are set on both and are ruled out.
---
--- Seven is too many for a single "you spent this week's pick", and they
--- interleave with the visible metas -- 93891 between Abundance and
--- Stormarion, 93908 immediately before Delves -- which reads like a
--- hidden partner per meta rather than one shared lockout. Narrowing
--- further needs a scan either side of a hand-in on a character who can
--- still take one, and then a scan after the following reset to see which
--- of them clears. Nothing shorter will do it: a lockout has to be both
--- set by the hand-in AND cleared by the reset, and one week of samples
--- cannot show the second half.
---
--- Two theories died on the way here, both worth not reviving: that she
--- skips weeks entirely (an alt had her quest the same week), and that the
--- sixteen are once-per-character and this one had exhausted them (it was
--- week two).
---
--- Four of the sixteen were checked directly and every one pays a Spark
--- of Tides -- 93910, 93911, 93766 and 98232. The other twelve are
--- assumed to match because they are the same quest family from the same
--- giver.
--- The meta itself. One id, weekly, and the only thing here whose flag
--- means what the row is asking.
---
--- ON ONE CHARACTER IT SURVIVED A RESET, and that is almost certainly the
--- Blizzard bug rather than a fact about metas. Unity Against the Void has
--- been missing since Silvermoon shipped in 12.1 -- NA first, then EU --
--- reported on some characters while alts on the same account still get it
--- (Kaivax, 2026-08-18, checking "it's being offered by Lady Liadrin as
--- intended"). A completion flag stuck on means she has nothing to offer,
--- which is what an affected character looks like from here.
---
--- Green is the right screen for that. The quest cannot be obtained, so a
--- row nagging weekly for it would be worse than one that stays quiet, and
--- the same read is correct on a character who really did it.
---
--- STILL OWED: an unaffected character completing it and clearing at the
--- following reset. That is the one case never observed, and it is what
--- separates "this character is stuck" from "the meta never clears" -- the
--- second would put the row back to green-forever for everyone.
local LIADRIN_META = { 93744 }   -- Unity Against the Void

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

--- What each quest pays, once it has been worked out. See
--- Wk:GetQuestRewards further down for what is in an entry.
---
--- NOT ABOUT SPEED. Reading a quest's currency rewards means pointing
--- the quest log at that entry first -- the log is the only thing the
--- currency getters will answer about -- and the quest log is a frame
--- the player may also have open. A tooltip that re-ran that every time
--- the cursor crossed a row would be reaching into their UI several
--- times a second. Once per quest is enough: rewards do not change
--- between hand-ins, and the one thing that does change them is the
--- data arriving, which already has an event.
---
--- On Wk rather than a file local so the load handler just below can
--- drop an entry when fresh data lands.
Wk._rewards = {}

--- Item ids a reward line is waiting on a name for.
---
--- A quest's reward data and an ITEM's name are two separate loads. The
--- quest can be fully loaded -- so the reader has an itemID -- while the
--- item itself is not, and GetQuestLogRewardInfo hands back a nil name.
--- That is why the first hover read "Item" and the second read the real
--- thing: by the second, somebody had loaded the item.
---
--- Kept so GET_ITEM_INFO_RECEIVED, a global event, can be filtered to
--- the handful of items this file is actually waiting for.
Wk._wantItem = {}

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
        -- Whatever was worked out before the data landed was worked out
        -- from an empty quest. Dropped rather than refreshed here: the
        -- next hover asks again, and nothing is gained by computing an
        -- answer for a page that may be shut.
        Wk._rewards[id] = nil
        -- An open tooltip was drawn from the empty version of this quest.
        if ns.OnWeeklyRewardDataArrived then pcall(ns.OnWeeklyRewardDataArrived) end
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
--- `namesQuest = "active"` drops that second half, for a row whose completed
--- flags cannot single one out. Lady Liadrin's sixteen are the case: one
--- hand-in flags all sixteen, so the fallback named whichever sorted first
--- and put "Midnight: Abundance" on the row for no better reason than the
--- A -- a coin toss among sixteen presented as the thing you did. A row
--- like that says nothing rather than guessing, and falls back to its own
--- label.
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
    local logOnly = (item.namesQuest == "active")

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

    if Q.IsQuestFlaggedCompleted and not logOnly then
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
--- `pays` is what the row is known to hand over, in words.
---
--- Only for the rows whose quest cannot be named before you accept it.
--- Where the client can be asked about an actual quest it is asked, and
--- its answer -- real icons, real amounts, correct after a retune -- is
--- better than anything written here.
---
--- Every entry is already stated in the row's own `detail` a few lines
--- below it, in prose. This is the same fact in a form the tooltip can
--- put under a heading. Nothing new is being claimed, and the sourcing
--- for the Spark ones is recorded on LIADRIN_WEEKLY: four of the
--- sixteen were checked directly and every one paid a Spark of Tides.
---
--- Aethas has two, because his set does: the PvE weeklies pay a cache
--- and the PvP ones pay Conquest. That one is sourced from Wowhead rather
--- than from the row's own description -- see the note on his row.
---
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
--- Items are in two runs: the chores you do anywhere -- crests, spark,
--- bounty map, world boss -- and then the weeklies you pick up from a
--- giver, kept together so the pins down the right-hand edge form one
--- block rather than being split by a row with nothing to point at.
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
    {
        id = "vaultweekly",
        pays = { "Trovehunter's Bounty" },
        giver = { map = 2509, x = 0.4720, y = 0.6080, name = "Warleader Abdumati" },  -- npc 262798
        -- Only the fallback: with the quest resolved the row draws the
        -- client's own title instead, which is the actual name of the
        -- thing and searchable. This is what shows before the client has
        -- loaded the quest, or on a character that has never seen it.
        label = "Pick up the Vaults of Atal'Utek weekly",
        detail = "In the Vaults of Atal'Utek. Temple patrols, strikes, "
            .. "incursions and ancient foes all count towards it. Hands over "
            .. "the Trovehunter's Bounty.",
        category = "delves",
        -- The first of the weeklies you pick up from somebody, so it sits
        -- with them rather than with the chores above -- the world boss
        -- used to be between this and Lady Liadrin, which split the
        -- pick-ups in two. Still below the map it grants, whose own
        -- description says it comes from "the Vaults weekly below".
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
        pays = { "Spark of Tides" },
        giver = { map = 2393, x = 0.4900, y = 0.6440, name = "Lady Liadrin" },  -- npc 256203
        label = "Pick up Lady Liadrin's weekly",
        detail = "Lady Liadrin, Silvermoon City. She shows you four or five "
            .. "and you accept one; whichever you take is your week, and it "
            .. "pays a Spark of Tides.",
        category = "delves",
        -- The sixteen NAME this row; the meta ANSWERS it. Naming from the
        -- children is the useful half -- "Complete Midnight: Prey" is a
        -- thing you can go and do, where the meta's own title is not -- and
        -- answering from them is the half that was wrong. See the note on
        -- LIADRIN_WEEKLY.
        namesQuest = "active",
        questsNameOnly = true,
        quests = LIADRIN_WEEKLY,
        auto = function() return questsDone(LIADRIN_META) end,
    },
    {
        id = "halduronweekly",
        pays = { "1,000 reputation with a faction you choose" },
        giver = { map = 2393, x = 0.4900, y = 0.6440, name = "Halduron Brightwing" },  -- npc 256210
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
        pays = { "Spark of Tides" },
        giver = { map = 2393, x = 0.4900, y = 0.6440, name = "Vereesa Windrunner" },  -- npc 270645
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
        -- Two lines, because his set pays two different things and a
        -- single line would be false for half of it.
        --
        -- PvE: EITHER of two caches, so the line names both. Seen in game
        -- 2026-09-13, Emissary of War's quest window offered a Cache of
        -- Amani Treasures -- "Rewards a piece of Hero equipment for your
        -- Loot Specialization". Wowhead lists a Cache of Quel'Thalas
        -- Treasures for the same quest, and lists BOTH caches on A Call to
        -- Delves. The user's read is that it can be either, which squares
        -- all three; what decides which one is offered is not known here.
        -- Do not read the in-game sighting as Wowhead being wrong.
        --
        -- PvP, from Wowhead only and NOT confirmed: A Call to Battle and
        -- The Arena Calls list Conquest with Honor or Marks of Honor.
        pays = { "Cache of Amani or Quel'Thalas Treasures (PvE)", "Conquest and Honor (PvP)" },
        giver = { map = 2393, x = 0.4880, y = 0.6440, name = "Archmage Aethas Sunreaver" },  -- npc 256212
        label = "Pick up Aethas Sunreaver's weekly",
        detail = "Archmage Aethas Sunreaver, Silvermoon City. Timewalking, "
            .. "battleground and dungeon weeklies. A separate week's work to "
            .. "Liadrin's, and none of it pays a spark.",
        category = "delves",
        -- A different set entirely: the Timewalking "Path Through Time"
        -- quests -- read off a live quest log rather than guessed, and the
        -- gaps in 93607-93613 mean the set is probably not complete -- the Call to / Emissary / Arena weeklies, and a
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
        -- The Timewalking entries are typed Weekly and stay, but they
        -- are only OFFERED during a Timewalking week. That is fine
        -- for any-of and it is the part to suspect first if this row ever
        -- reads wrong.
        namesQuest = true,
        quests = {
            93497,  -- A Soaring Path Through Time
            93607,  -- An Original Path Through Time
            93608,  -- A Burning Path Through Time
            93610,  -- A Frozen Path Through Time
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
    --
    -- Unless the row says its ids cannot carry that. `questsNameOnly` is
    -- for a family whose flags are set together and never cleared: they
    -- still identify the quest for the label, and answering the week with
    -- them would pin the row green from the first hand-in on. See
    -- LIADRIN_WEEKLY.
    local answer
    if not item.questsNameOnly then answer = questsDone(item.quests) end
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

        -- Asked of the tracker rather than inferred from `questID`: the
        -- two resolve differently on purpose. A row NAMES the quest it
        -- can single out for the label, and POINTS at whatever the game
        -- can navigate to -- which may be a quest, and may be the NPC
        -- who hands it over. Lady Liadrin's row names the one in your
        -- log while you are on it, and points at Lady Liadrin before you
        -- have taken one, which is the state the question was asked in.
        local trackTarget, trackHow = self:GetTrackTarget(item)
        local canTrack = trackTarget ~= nil
        local tracking = canTrack and self:IsTrackingTarget(trackTarget, trackHow) or false

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
            -- Whether the game can be pointed at this row, and whether
            -- it already is. Resolved here rather than at click time
            -- because the tooltip has to say what a click will do
            -- before the click happens -- and because a row that cannot
            -- be pointed at has to go on meaning what it meant before,
            -- which is a manual tick.
            canTrack = canTrack, tracking = tracking,
            -- A row that IS a place but has no pin yet, as opposed to a
            -- row that is not a place at all. The two look identical on
            -- the page -- an empty right-hand edge -- and only one of
            -- them is waiting on something the player can do.
            needsGiver = (not canTrack)
                and (item.quests ~= nil and #item.quests > 0) or false,
            -- What a click will actually do, so the tooltip can say it
            -- in words: "point the arrow at Lady Liadrin" is a different
            -- sentence from "track this quest", and a row that promised
            -- the wrong one would be worse than a row that promised
            -- nothing.
            trackKind = trackHow,
            trackName = (trackHow == "giver") and trackTarget.name or nil,
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


--- What a ROW pays, which is not the same question as what a quest pays.
---
--- Before you accept anything the row is the only thing that exists,
--- and "is this one worth my evening" is asked before rather than
--- after. So a row that cannot name a single quest still answers.
---
--- In order:
---
---   the quest the row NAMES, where there is one. The client's own
---   answer about the actual quest, with its icons and amounts. Same
---   quest the label is built from, so the tooltip can never describe
---   one quest while listing another's rewards.
---
---   the row's only quest, where it has one. Nothing to disambiguate.
---
---   what the row SAYS it pays -- `pays` on the item, below. For a row
---   offering one of sixteen there is no quest to ask about until you
---   have taken one, and the answer is known anyway.
---
--- THIS REPLACED AN INTERSECTION, which is worth recording because it
--- looked clever. It loaded every variant's rewards, kept what they had
--- in common, dropped amounts they disagreed on, refused to speak on
--- one variant's word alone, and rationed the loading so sixteen quests
--- did not get requested at once. It worked. It was also a machine for
--- deriving a fact already written three lines up in this file -- every
--- one of Lady Liadrin's sixteen pays a Spark of Tides, and the row's
--- own `detail` has said so all along. The derivation needed the client
--- to have loaded at least two variants before it would say anything,
--- so the common case was a tooltip that stayed blank until you hovered
--- it a few times. Saying the known thing is instant and always right.
---
--- @return table|nil rewards, boolean pending
function Wk:GetRowRewards(item)
    if not item then return nil, false end

    local pending = false
    local function fromQuest(id)
        local r = self:GetQuestRewards(id)
        if r and not r.empty then return r end
        if r and r.pending then pending = true end
        return nil
    end

    local named = self:ResolveQuest(item)
    if named then
        local r = fromQuest(named)
        if r then return r, false end
    end

    local ids = item.quests
    if ids and #ids == 1 then
        local r = fromQuest(ids[1])
        if r then return r, false end
    end

    -- Declared, and preferred over saying "loading" -- the row knows the
    -- answer whether or not the client has got round to it.
    if item.pays and #item.pays > 0 then
        return { declared = item.pays }, false
    end

    return nil, pending
end

------------------------------------------------------------
-- Pointing at it
--
-- Asked for on CurseForge, alongside the rewards below: click the row
-- and get a navigation arrow, the way Azeroth Pilot Reloaded does it.
--
-- NOTHING HERE DRAWS AN ARROW. The game already has one -- super
-- tracking is what puts the distance marker on the minimap, the
-- waypoint on the map and the arrow at the top of the screen -- so the
-- job is to hand it a target and get out of the way. An arrow of our
-- own would be a second one pointing the same way, and it would be the
-- one that goes wrong the week Blizzard moves a quest giver.
--
-- TWO TARGETS, and which one applies is decided by the same thing that
-- decides what the row SAYS.
--
--   "log"    the quest is in your log. The row reads "Complete Midnight:
--            Prey", so the pin points at the objective -- super tracked
--            by id, and the client knows where that is. No narrowing
--            needed: being in the log is itself the proof that this is
--            the one of the sixteen you were offered. When the quest is
--            ready to hand in the game's own arrow turns back towards
--            the giver, which is the right answer for free.
--
--   "giver"  you have not picked it up. The row reads "Pick up Lady
--            Liadrin's weekly", so the pin points at Lady Liadrin.
--
-- Label and pin therefore never disagree, which is the property worth
-- keeping: a row that says "pick up" and points at a delve is lying.
--
-- A THIRD TARGET WAS TRIED AND REMOVED. It super-tracked the client's
-- own quest-offer pin -- the blue exclamation mark -- for an un-accepted
-- quest, by id. It went because it could not clear that bar: the only
-- map it can name for an un-accepted quest is the QUEST's map, from
-- GetQuestUiMapID, and that is where the objectives are rather than
-- where the giver stands. Vereesa is in Silvermoon; Trailing Xal'atath
-- sends you to dungeons, delves and rares all over the place. So the
-- one row it reliably fired on was the one it sent to the wrong zone,
-- on a line reading "Pick up Vereesa's weekly in Silvermoon".
--
-- It was also the only branch never seen working in game. Between those
-- two facts there was nothing left to keep: what it was for is what the
-- giver does, exactly, and with a position somebody has actually
-- checked.
--
-- GIVER OUTRANKS OFFER, which is not the order it looks like it should
-- be. The offer pin is the game's own and points at the real thing;
-- the giver is a coordinate we wrote down. But the offer pin has two
-- ways to quietly do nothing -- the quest has to be on offer right now,
-- and the pin has to exist for the client to track -- and a click that
-- silently does nothing is the worst outcome on the page. A coordinate
-- read off a live client and pasted in is exact, and it goes to the
-- same NPC. Revisit once the offer branch has actually been watched
-- working; see ROADMAP.md.
--
-- AND NOTHING HERE EVER ASKS WHICH OF THE FAMILY IS LIVE. Most rows
-- carry several ids: eight dungeons for Halduron, sixteen for Lady
-- Liadrin. One of them is the one you were offered and nothing in the
-- client says which -- which used to be the central problem and is now
-- simply not a question that comes up. Before pickup the pin is the
-- NPC, and she stands in the same spot for all sixteen. After pickup
-- the log says which one it is. That is why the giver is keyed by ROW.
------------------------------------------------------------

------------------------------------------------------------
-- Learning where the giver stands
--
-- The giver tables cannot be filled in from outside the game and there
-- are four of them, which made this feature depend on somebody walking
-- a lap of Silvermoon and pasting coordinates. That is a bad dependency
-- for a thing every user needs and only the author can do.
--
-- So the addon learns it instead, from the one moment it is free: YOU
-- HAVE TO BE STANDING NEXT TO THE NPC TO ACCEPT OR HAND IN A QUEST.
-- At that instant the player's own position is the giver's position to
-- within interaction range -- a few yards, which on a city map is a
-- fraction of a percent and far inside what a map pin needs.
--
-- KEYED BY ROW, NOT BY QUEST, and that is what makes it beat every
-- other approach tried here. The row is "Lady Liadrin's weekly"; she
-- stands in the same spot whichever of her sixteen she is offering. So
-- accepting ANY ONE of them teaches the row for good, and the
-- narrowing problem that blocks the offer pin never comes up.
--
-- ACCOUNT-WIDE, because an NPC is in the same place for every character
-- and making an alt re-learn it would be storing a fact about the world
-- as though it were a fact about the character.
--
-- Only while a quest frame is open. QUEST_ACCEPTED also fires for
-- quests the game hands you for walking into a zone, and those would
-- record wherever you happened to be standing as the giver's spot --
-- a wrong pin, confidently placed, which is worse than no pin. Seeing
-- the quest detail window first is the proof that there was somebody to
-- talk to.
--
-- THREE WAYS IN, because waiting on the one above means a checklist
-- that does nothing until the player has already done the thing it is
-- reminding them about. In precedence order, best observation first:
--
--   "set"    the player stood on the NPC and said so. Exact, immediate,
--            and depends on no API anyone has to trust.
--   "quest"  accepted or handed in next to them, as above.
--   "map"    the world map already knew where the offer was, picked up
--            for free on walking into the zone. Fills empty slots only.
--
-- All three write the same record and any of them is enough.
------------------------------------------------------------

--- Everything learned, account-wide. id -> { map, x, y, name, at }.
local function givers()
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.givers = YippYappHelperDB.givers or {}
    return YippYappHelperDB.givers
end

--- Who we are talking to, while we are talking to them.
---
--- `UnitName("npc")` only answers while one of the quest frames is up,
--- so the name is caught then and spent when the quest is accepted.
--- Cleared when the window closes, so a name cannot survive to be
--- attached to an unrelated quest picked up minutes later.
local talking = nil

--- Which row a quest belongs to, or nil.
local function rowForQuest(questID)
    if not questID then return nil end
    for _, item in ipairs(ITEMS) do
        for _, id in ipairs(item.quests or {}) do
            if id == questID then return item end
        end
    end
    return nil
end

--- Write down where this row's quest was handed over.
local function learnGiver(questID)
    if not talking then return end
    local item = rowForQuest(questID)
    if not item then return end
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end

    local map = C_Map.GetBestMapForUnit("player")
    if not map then return end

    local ok, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
    if not (ok and pos) then return end

    local x, y
    if pos.GetXY then
        local gotXY, px, py = pcall(pos.GetXY, pos)
        if gotXY then x, y = px, py end
    end
    x, y = x or pos.x, y or pos.y
    if not (x and y) then return end

    -- What an instance answers, and what an unmapped spot answers. A pin
    -- at the top-left corner of a map is not a useful wrong answer.
    if x == 0 and y == 0 then return end

    givers()[item.id] = {
        map = map, x = x, y = y,
        name = talking.name,
        at = time and time() or nil,
        -- Where the record came from, so the dump can say and so the
        -- cheaper seeds know not to overwrite this one. Standing next to
        -- somebody is the most direct observation available.
        from = "quest",
    }
end

do
    -- An item name arriving for a reward line that is waiting on one.
    --
    -- GET_ITEM_INFO_RECEIVED is global and busy -- every item anything
    -- asks about -- so it is filtered to Wk._wantItem before anything
    -- happens. What passes is a handful of items, once each.
    local f = CreateFrame("Frame")
    f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    f:SetScript("OnEvent", function(_, _, itemID)
        if not (itemID and Wk._wantItem[itemID]) then return end
        Wk._wantItem[itemID] = nil
        if ns.OnWeeklyRewardDataArrived then pcall(ns.OnWeeklyRewardDataArrived) end
    end)
end

do
    local f = CreateFrame("Frame")
    -- The three frames that mean "you are talking to somebody", and the
    -- two that mean the conversation produced a quest.
    f:RegisterEvent("QUEST_DETAIL")
    f:RegisterEvent("QUEST_PROGRESS")
    f:RegisterEvent("QUEST_COMPLETE")
    f:RegisterEvent("QUEST_ACCEPTED")
    f:RegisterEvent("QUEST_TURNED_IN")
    f:RegisterEvent("QUEST_FINISHED")
    f:SetScript("OnEvent", function(_, event, questID)
        if event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN" then
            learnGiver(questID)
            return
        end
        if event == "QUEST_FINISHED" then
            talking = nil
            return
        end
        local name = UnitName and UnitName("npc")
        talking = {
            name = (type(name) == "string" and name ~= "") and name or nil,
        }
    end)
end

--- Record a row's quest giver: where you stand, or where you say.
---
--- The fastest seed there is, and the only one that does not depend on
--- an API nobody has watched work.
---
--- WITH COORDINATES, it does not need you to walk anywhere -- stand
--- anywhere in the right zone and type the numbers off a database.
--- That is the difference between five trips across Silvermoon and four
--- lines pasted from one spot, and it is why the argument exists: the
--- coordinates are published in a dozen places, and the uiMapID is
--- published nowhere current. So the client supplies the map and you
--- supply the position.
---
--- BOTH CONVENTIONS ACCEPTED. Map positions are written as fractions
--- (0.479) and as percentages (47.9) depending on where you read them,
--- and databases overwhelmingly use the second. Anything above 1 is
--- taken as a percentage. That is a rule about what a PERSON typed, not
--- a guess about what an API returned -- and the answer is echoed back
--- as a fraction, so a misread is visible immediately rather than
--- becoming a pin nobody checks.
---
--- The name comes from whatever is targeted, falling back to whoever is
--- being talked to -- so naming the row while targeting the NPC labels
--- the pin. Both are the client's own spelling, which matters: a
--- hand-typed name would be English on a German client.
---
--- @param rowID string the checklist row
--- @param x number|nil position across, fraction or percentage
--- @param y number|nil position down, fraction or percentage
--- @return string a sentence for the player, always.
function Wk:SetGiverHere(rowID, x, y)
    rowID = strtrim(rowID or "")
    if rowID == "" then return nil end

    local item
    for _, candidate in ipairs(ITEMS) do
        if candidate.id == rowID then item = candidate break end
    end
    if not item then
        local names = {}
        for _, candidate in ipairs(ITEMS) do
            if candidate.quests then names[#names + 1] = candidate.id end
        end
        return "|cffff5555no such row.|r rows that can take a giver: |cffffffff"
            .. table.concat(names, ", ") .. "|r"
    end

    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
        return "|cffff5555this client will not say where you are standing|r"
    end

    local map = C_Map.GetBestMapForUnit("player")
    if not map then return "|cffff5555no map here|r" end

    local given = (x ~= nil and y ~= nil)
    if given then
        -- Percentages, as every database writes them, become fractions.
        if x > 1 or y > 1 then x, y = x / 100, y / 100 end
        if x <= 0 or x >= 1 or y <= 0 or y >= 1 then
            return ("|cffff5555%s, %s is not a position on a map|r"):format(
                tostring(x), tostring(y))
        end
    else
        local ok, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
        if not (ok and pos) then return "|cffff5555no position here|r" end

        if pos.GetXY then
            local gotXY, px, py = pcall(pos.GetXY, pos)
            if gotXY then x, y = px, py end
        end
        x, y = x or pos.x, y or pos.y
        if not (x and y) or (x == 0 and y == 0) then
            return "|cffff5555no position here -- instances do not have one|r"
        end
    end

    local name = UnitName and (UnitName("target") or UnitName("npc"))
    if type(name) ~= "string" or name == "" then name = nil end

    givers()[item.id] = {
        map = map, x = x, y = y, name = name,
        at = time and time() or nil,
        from = "set",
    }

    return ("|cff00ff00recorded|r %s for |cffffffff%s|r at %.4f %.4f on map %d%s"):format(
        name or (given and "that spot" or "this spot"), item.id, x, y, map,
        given and " |cff888888(map taken from where you are standing)|r" or "")
end

--- Any of our quests the world map can already place, taken for free.
---
--- The other seed, and the one that costs the player nothing at all:
--- walk into the zone and the offers are on the map already. If
--- GetQuestsOnMap reports an un-accepted weekly with a position -- the
--- open question from the start of this -- then the giver is known
--- without anybody accepting anything.
---
--- FILLS EMPTY SLOTS ONLY. A record made by standing next to the NPC is
--- exact; this one is wherever the client thinks the pin goes, which is
--- the same place but arrived at less directly. Never overwrite the
--- better answer with the cheaper one.
---
--- Coordinates are required to be strictly inside 0..1. That is not
--- paranoia about nil -- it is the one thing that could make this place
--- a confidently wrong pin. Map coordinates come in two conventions,
--- fractions and percentages, and a "47.9" read as a fraction is a pin
--- off the edge of the world. Anything outside the range is simply not
--- the convention this wants, so it is dropped rather than converted:
--- guessing which convention a number is in is how you get a pin that
--- is wrong half the time.
local function scanMapForGivers()
    local Q = C_QuestLog
    if not (Q and Q.GetQuestsOnMap and C_Map and C_Map.GetBestMapForUnit) then return end

    -- Nothing left to find is the common case after the first week, and
    -- this runs on every zone change -- including every sub-zone, which
    -- in a city is constantly. Answering "already done" first keeps the
    -- walk over every row's id list off the hot path entirely.
    local wanted = false
    local known = givers()
    for _, item in ipairs(ITEMS) do
        if item.quests and #item.quests > 0 and not known[item.id] then
            wanted = true
            break
        end
    end
    if not wanted then return end

    local map = C_Map.GetBestMapForUnit("player")
    if not map then return end

    local ok, quests = pcall(Q.GetQuestsOnMap, map)
    if not (ok and type(quests) == "table") then return end

    for _, entry in ipairs(quests) do
        if type(entry) == "table" and entry.questID then
            local item = rowForQuest(entry.questID)
            if item and not givers()[item.id] then
                local x, y = entry.x, entry.y
                if x and y and x > 0 and x < 1 and y > 0 and y < 1 then
                    givers()[item.id] = {
                        map = map, x = x, y = y,
                        at = time and time() or nil,
                        from = "map",
                    }
                end
            end
        end
    end
end

do
    local f = CreateFrame("Frame")
    -- Rare events on purpose. The scan walks every quest the map knows
    -- about against every row's id list, and the answer only changes
    -- when the player changes zone.
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- The sub-zone ones too, and they are the point rather than padding.
    -- A quest giver stands in a district of a city, and walking between
    -- districts fires only these -- so a player who logs in inside
    -- Silvermoon and walks to the bank would otherwise never scan the
    -- map they are standing on. The early-out above is what makes the
    -- extra frequency free.
    f:RegisterEvent("ZONE_CHANGED")
    f:RegisterEvent("ZONE_CHANGED_INDOORS")
    f:SetScript("OnEvent", function() pcall(scanMapForGivers) end)
end

--- Where this row's giver stands: what this client knows, then what
--- shipped.
---
--- LEARNED WINS, and the order matters more now that rows actually ship
--- with a giver. A shipped coordinate is a snapshot taken when the
--- addon was built; a learned one came off the player's own client,
--- either because they stood next to the NPC or because they said so.
--- The live observation is the better one, it is the one that is right
--- if Blizzard moves somebody mid-patch, and it is the one the player
--- can fix. Shipping data that could not be overridden would turn a
--- stale number into a bug nobody can work around.
---
--- `/yh where forget` drops the learned side, which puts a row back on
--- the shipped position -- so a bad learning is recoverable in both
--- directions.
local function giverFor(item)
    local rec = item and (givers()[item.id] or item.giver)
    if not (rec and rec.map and rec.x and rec.y) then return nil end
    return rec
end

--- Forget everything learned, for when a record is wrong.
---
--- One command rather than one per row: the records rebuild themselves
--- the next time each quest is picked up, so the expensive half of
--- being wrong is already cheap.
function Wk:ForgetGivers()
    local n = 0
    for _ in pairs(givers()) do n = n + 1 end
    YippYappHelperDB.givers = {}
    return n
end

--- What has been learned so far, for the dump.
function Wk:GetLearnedGivers()
    return givers()
end

--- Where a row's quest giver stands, for the rows that record one.
---
--- Five of them, and every number is sourced rather than remembered.
---
--- WHERE THEY CAME FROM, because that is the only thing that makes a
--- hardcoded coordinate acceptable here: Wowhead's `g_mapperData`, read
--- off each NPC's page on 2026-09-12. That structure is datamined out
--- of the client -- it is the same class of thing as the class-guide
--- tables in Features/Gear/ClassGuideData.lua, not the editorial prose
--- next to it -- and it carries its OWN uiMapId, so the map is not
--- being inferred from a zone name either.
---
--- Each NPC was reached through a quest id this file already ships,
--- rather than by searching for a name: 93751 names Halduron, 98172
--- names Vereesa, 93598 names Aethas, 95520 names Warleader Abdumati.
--- So the link from row to NPC is the row's own data, and a wrong NPC
--- would have to be a wrong quest id first.
---
--- uiMapId 2393 was confirmed a second time, against a live client
--- standing in Silvermoon. The published uiMapID lists are three years
--- stale and still name 110, which is the pre-Midnight city -- so the
--- agreement between Wowhead's number and the game's own is the thing
--- that settles it, not either alone.
---
--- FOUR OF THE FIVE SIT ON TOP OF EACH OTHER, within a fifth of a
--- percent. That is not a copy-paste error: they are the weekly quest
--- givers and they stand together, which the rows' own `detail` lines
--- have said all along -- Vereesa's names the Great Vault.
---
--- A LEARNED RECORD OUTRANKS ALL OF THIS. See giverFor below: these are
--- a snapshot taken at build time and the player's client is live, so
--- the moment anyone picks one of these quests up, their own
--- observation wins. That is also the repair path if Blizzard moves
--- somebody mid-patch.
---
--- English names, like every other string in this addon. The learned
--- path can do better -- it takes the client's own spelling -- and
--- does, as soon as there is a learned record.
---
--- `name` is what the waypoint is called on the map, so a player who
--- opens it later sees who they were walking to rather than a bare pin.
---
---   giver = { map = 0, x = 0.0000, y = 0.0000, name = "Lady Liadrin" }
---
--- The zeros are deliberate. That is a SHAPE, not an example with real
--- numbers in it -- a plausible-looking uiMapID sitting in a comment is
--- exactly how an unchecked value ends up copied into a row.
---
--- `map` is a uiMapID and `x`/`y` are 0..1 map fractions, which is what
--- both C_Map.GetPlayerMapPosition returns and UiMapPoint wants -- no
--- multiplying by a hundred anywhere, in either direction.

--- Whether the map's one user waypoint is the one we put there.
---
--- Compared rather than remembered, and that is the whole point. There
--- is exactly ONE user waypoint and whoever wrote it last owns it, so a
--- remembered "we set one" goes stale the moment the player drops their
--- own -- and clearing a pin they placed by hand is the kind of thing
--- an addon gets uninstalled for. Comparing costs nothing and cannot be
--- wrong in that direction.
local function waypointIsOurs(giver)
    if not (giver and C_Map and C_Map.HasUserWaypoint and C_Map.GetUserWaypoint) then
        return false
    end
    local ok, has = pcall(C_Map.HasUserWaypoint)
    if not (ok and has) then return false end

    local gotPoint, point = pcall(C_Map.GetUserWaypoint)
    if not (gotPoint and type(point) == "table") then return false end
    if point.uiMapID ~= giver.map then return false end

    -- The position is a Vector2D, which answers to GetXY() and also
    -- carries x and y as fields. Both are read because a mixin losing
    -- one of the two is a silent nil rather than an error.
    local x, y
    local pos = point.position
    if type(pos) == "table" then
        if pos.GetXY then
            local gotXY, px, py = pcall(pos.GetXY, pos)
            if gotXY then x, y = px, py end
        end
        x, y = x or pos.x, y or pos.y
    end
    if not (x and y) then return false end

    -- A tenth of a percent of the map, which is a couple of yards in a
    -- city and far tighter than anything a player would place by hand
    -- on the same spot by accident.
    return math.abs(x - giver.x) < 0.001 and math.abs(y - giver.y) < 0.001
end

--- Drop a map pin on the giver and point the arrow at it.
---
--- Modelled on a working native-waypoint path rather than assembled
--- from the call names: the map is asked whether it takes a pin at all
--- BEFORE anything is cleared, because a restricted map refuses and the
--- player should not lose the waypoint they had to find that out. On
--- 12.1.0 and up SetUserWaypoint reports whether it took, so that is
--- read rather than assumed.
---
--- @return string|nil "on", "off", or nil when it could not be placed
local function pointAtGiver(giver)
    if not (giver and C_Map and C_Map.SetUserWaypoint
        and UiMapPoint and UiMapPoint.CreateFromCoordinates) then return nil end

    -- Already ours: a second click lets go, and only of ours.
    if waypointIsOurs(giver) then
        if C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, false)
        end
        return "off"
    end

    if C_Map.CanSetUserWaypointOnMap then
        local ok, allowed = pcall(C_Map.CanSetUserWaypointOnMap, giver.map)
        if not (ok and allowed) then return nil end
    end

    local built, point = pcall(UiMapPoint.CreateFromCoordinates,
        giver.map, giver.x, giver.y)
    if not (built and point) then return nil end

    local ok, placed = pcall(C_Map.SetUserWaypoint, point)
    -- `placed` is nil on a client whose setter returns nothing, false
    -- when it refused, and true when it took. Only the refusal is a
    -- failure -- treating "returned nothing" as one would break the
    -- branch on every client older than the one it was written against.
    if not ok or placed == false then return nil end

    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end
    return "on"
end

--- Which map a target lives on, or nil.
---
--- GetQuestUiMapID is a bare GLOBAL, not a C_QuestLog member -- TomTom
--- and Plumber both call it that way and the namespaced spelling does
--- not exist. Worth writing down because the rest of this file reaches
--- for quest functions through C_QuestLog, so the odd one out looks
--- like a typo.
---
--- A giver needs none of that: the row already says which map it is on,
--- which is the third time that table has turned out to be the simple
--- answer to a question the client makes complicated.
local function targetMap(target, how)
    if how == "giver" then return target.map end
    -- Only ever asked about a quest in the log now. For one of those it
    -- is the zone the objective is in, which is where the row is sending
    -- you. Asked about an un-accepted quest it answers the objective's
    -- zone too, which is why nothing asks it about one any more.
    if type(GetQuestUiMapID) ~= "function" then return nil end
    local ok, mapID = pcall(GetQuestUiMapID, target)
    -- Zero is the client's "no map", and passing it on opens the world
    -- map on whatever it was last showing -- which looks like the
    -- feature working and is not.
    if ok and mapID and mapID ~= 0 then return mapID end
    return nil
end

--- Put the world map in front of the player, on the right map.
---
--- Part of pointing rather than a separate action. A waypoint you
--- cannot see is a direction without a distance -- the arrow tells you
--- which way, the map tells you how far and what is between you and it,
--- and somebody asking "where do I pick this up" wants the second one.
---
--- NOT IN COMBAT. ShowUIPanel runs inside FramePositionDelegate, and the
--- world map throwing itself over a pull is unwanted even where it is
--- allowed.
---
--- C_Map.OpenWorldMap first because it is the C entry point and carries
--- no Lua taint. The fallback goes through securecall for the reason
--- Core/EditMode.lua sets out at length: calling ShowUIPanel straight
--- from addon code taints the panel system for the session, and the
--- symptom is a keybind that quietly stops working somewhere else
--- entirely. Showing a panel never needed the taint to begin with.
local function openMapAt(mapID)
    if not mapID then return false end
    if InCombatLockdown and InCombatLockdown() then return false end

    if C_Map and C_Map.OpenWorldMap then
        local ok = pcall(C_Map.OpenWorldMap, mapID)
        if ok then return true end
    end

    if WorldMapFrame and securecall then
        securecall("ShowUIPanel", WorldMapFrame)
        if WorldMapFrame.SetMapID then
            pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID)
        end
        return true
    end
    return false
end

--- What the game could point at for this row, and how.
---
--- Returns target, how -- where `how` says what `target` is: a quest id
--- for "log" and "offer", the row's giver table for "giver". nil covers
--- every case where there is nothing to point at.
function Wk:GetTrackTarget(item)
    if not item then return nil end

    local Q = C_QuestLog
    local ids = item.quests

    if Q and C_SuperTrack and ids and #ids > 0
        and Q.GetLogIndexForQuestID and C_SuperTrack.SetSuperTrackedQuestID then
        for _, id in ipairs(ids) do
            local ok, idx = pcall(Q.GetLogIndexForQuestID, id)
            if ok and idx then return id, "log" end
        end
    end

    local giver = giverFor(item)
    if giver and C_Map and C_Map.SetUserWaypoint then
        return giver, "giver"
    end

    return nil
end

--- Whether the game is already pointing at an already-resolved target.
---
--- Split from IsTracking below so GetList can ask both questions off
--- ONE call to GetTrackTarget. Resolving a target walks the row's whole
--- id list -- sixteen of them on Lady Liadrin's -- and that list is
--- already walked three times a refresh by IsDone and ResolveQuest. A
--- fourth walk to re-derive a value the caller is holding is the kind
--- of thing that is free until the day it is not.
---
function Wk:IsTrackingTarget(target, how)
    if not target then return false end

    if how == "giver" then return waypointIsOurs(target) end

    local get = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID
    if not get then return false end
    local ok, current = pcall(get)
    return (ok and current == target) and true or false
end

--- The same question, from the row.
function Wk:IsTracking(item)
    local target, how = self:GetTrackTarget(item)
    return self:IsTrackingTarget(target, how)
end

--- Point the game at this row, or stop pointing at it.
---
--- A second click clears it, which is what a tracking toggle does
--- everywhere else in the game. The quest cases clear with
--- ClearAllSuperTracked rather than by setting the id to zero: zero is
--- the quest setter's "none" and means nothing at all to the pin
--- setter, so one call covers both and neither needs a magic number.
---
--- @return string|nil "on", "off", or nil when there was nothing to
--- point at -- which the caller wants, because a click that did nothing
--- should not redraw the page as though it had.
function Wk:Track(item)
    local target, how = self:GetTrackTarget(item)
    if not target then return nil end

    local result
    if how == "giver" then
        result = pointAtGiver(target)
    else
        if self:IsTrackingTarget(target, how) and C_SuperTrack.ClearAllSuperTracked then
            if pcall(C_SuperTrack.ClearAllSuperTracked) then result = "off" end
        end
        if not result then
            local ok = pcall(C_SuperTrack.SetSuperTrackedQuestID, target)
            result = ok and "on" or nil
        end
    end

    -- Only on the way ON. Letting go of a waypoint should not throw a
    -- window at you, and neither should a click that placed nothing --
    -- a map opening on a failure is the clearest possible way to report
    -- success that did not happen.
    if result == "on" then openMapAt(targetMap(target, how)) end
    return result
end

------------------------------------------------------------
-- What it pays
--
-- The other half of the same CurseForge request, and the half that
-- turns the list from chores into reasons: a row that says "Complete
-- Midnight: Dungeons" and a row that says it pays a Spark of Tides are
-- not the same row.
--
-- Read off the CLIENT, never written down here. A quest retuned in the
-- current patch reads as its old self on every database for weeks, and
-- a reward that scales -- with level, with season, with which
-- difficulty flagged it -- is one number there and another one here.
-- The client is answering about this character tonight.
------------------------------------------------------------

--- Which of our own currencies an id belongs to, as a short label, or nil.
---
--- So a crest reward reads as "Hero Mistcrest" rather than as a bare
--- 3445 the reader has to go and look up. The names come from
--- Features/Gear/Crests.lua, which is where they are already recorded
--- and already re-checked each season.
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
--- THE SELECTION DANCE IS THE WHOLE TRICK, and it is the reason this is
--- one function rather than four call sites. The reward getters look
--- like one family and are two: GetNumQuestLogRewards takes a quest id
--- and answers about the id it is handed, while
--- GetNumQuestLogRewardCurrencies answers about whichever entry the
--- quest log has SELECTED and ignores the argument entirely. Reading
--- both without selecting comes back holding a quest's items and none
--- of its currencies -- which on a weekly is the half that matters,
--- since the currency usually IS the reward. So the log is pointed at
--- the entry first and put back afterwards.
---
--- A getter that is not there goes in `missing` rather than counting as
--- zero. The two are indistinguishable from outside -- either way the
--- reward goes unread and the quest looks like it pays nothing -- and a
--- reader that cannot tell "pays nothing" from "asked the wrong
--- question" is worse than none, because it is believed.
---
--- Reward data arrives with the quest, so a quest the client has not
--- loaded answers zero to all of it. That case asks for the load and
--- comes back `pending`, not `empty`: "nothing yet" and "nothing at
--- all" are different sentences for a tooltip to print, and the request
--- goes through the same `requested` table as the titles above so
--- QUEST_DATA_LOAD_RESULT redraws the page when it lands.
---
--- @return table|nil { currencies, items, choices, money, xp, missing,
--- empty, pending }. Every list is present and may be empty; a choice
--- entry carries isCurrency when it is a reputation rather than an item.
function Wk:GetQuestRewards(id)
    if not id then return nil end

    local cached = self._rewards[id]
    if cached then return cached end

    local out = {
        currencies = {}, items = {}, choices = {},
        money = 0, xp = 0, missing = {},
    }

    if type(HaveQuestRewardData) == "function" then
        local ok, ready = pcall(HaveQuestRewardData, id)
        if ok and not ready then
            out.pending = true
            if not requested[id] and C_QuestLog and C_QuestLog.RequestLoadQuestByID then
                requested[id] = true
                pcall(C_QuestLog.RequestLoadQuestByID, id)
            end
        end
    end

    local Q = C_QuestLog
    local restore = Q and Q.GetSelectedQuest and Q.GetSelectedQuest()
    if Q and Q.SetSelectedQuest then pcall(Q.SetSelectedQuest, id) end

    local function count(fn, name, ...)
        if type(fn) ~= "function" then
            out.missing[#out.missing + 1] = name .. " (no such function)"
            return 0
        end
        local ok, n = pcall(fn, ...)
        if not ok then
            out.missing[#out.missing + 1] = name .. " (errored)"
            return 0
        end
        return tonumber(n) or 0
    end

    -- One currency reward, however this client hands it back. Both
    -- shapes are read because the getter has had two: a flat
    -- name/texture/quantity/id/quality list, and a single table.
    -- Guessing wrong fails silently -- every field reads nil and the
    -- reward disappears rather than erroring.
    local function currency(j, isChoice)
        local ok, a, b, c, d, e = pcall(GetQuestLogRewardCurrencyInfo, j, id, isChoice)
        if not ok then return nil end
        local name, texture, quantity, currencyID, quality
        if type(a) == "table" then
            name       = a.name
            texture    = a.texture
            quantity   = a.totalRewardAmount or a.quantity or a.numItems
            currencyID = a.currencyID
            quality    = a.quality
        else
            name, texture, quantity, currencyID, quality = a, b, c, d, e
        end
        if not currencyID then return nil end
        -- The texture was discarded here for a while, and the cost was
        -- invisible until the tooltip started drawing icons: a weekly's
        -- currency IS its reward, so the one line that most needed art
        -- was the only one without any.
        return {
            isCurrency = true, currencyID = currencyID,
            name = name, texture = texture,
            quantity = quantity, quality = quality,
            known = knownCurrency(currencyID),
        }
    end

    -- Currencies first: on a weekly, they are the reason to do it.
    for j = 1, count(GetNumQuestLogRewardCurrencies, "GetNumQuestLogRewardCurrencies", id) do
        local info = currency(j)
        if info then out.currencies[#out.currencies + 1] = info end
    end

    -- One item reward, with the name filled in from the item cache when
    -- the quest's own answer left it out -- and a load asked for when
    -- the cache does not have it either. Marks the whole answer
    -- incomplete in that case, so it is not cached with a hole in it.
    local function itemReward(itemID, name, texture, quantity, quality)
        if (not name or name == "") and C_Item then
            if C_Item.GetItemNameByID then
                local got, cached = pcall(C_Item.GetItemNameByID, itemID)
                if got and type(cached) == "string" and cached ~= "" then name = cached end
            end
            if not name or name == "" then
                out.incomplete = true
                Wk._wantItem[itemID] = true
                if C_Item.RequestLoadItemDataByID then
                    pcall(C_Item.RequestLoadItemDataByID, itemID)
                end
            end
        end
        if not texture and C_Item and C_Item.GetItemIconByID then
            local got, icon = pcall(C_Item.GetItemIconByID, itemID)
            if got then texture = icon end
        end
        return {
            itemID = itemID, name = name, texture = texture,
            quantity = quantity or 1, quality = quality,
        }
    end

    for j = 1, count(GetNumQuestLogRewards, "GetNumQuestLogRewards", id) do
        local ok, name, texture, quantity, quality, _, itemID = pcall(GetQuestLogRewardInfo, j, id)
        if ok and itemID then
            out.items[#out.items + 1] = itemReward(itemID, name, texture, quantity, quality)
        end
    end

    -- The pick-one list, which is where the reputation weeklies live.
    --
    -- Two readers per slot, because a choice is not always an item. A
    -- quest offering five reputations offers five CURRENCIES, and
    -- GetQuestLogChoiceInfo describes items -- it hands back no itemID
    -- for a currency slot, so an item-only loop reads nothing at all
    -- and the quest looks like it pays nothing. Ask for the item first,
    -- and fall back to the currency reader with isChoice set.
    --
    -- The count has to include currencies or the loop never reaches
    -- them: without the flag GetNumQuestLogChoices answers with the
    -- item choices only, which for these quests is zero.
    for j = 1, count(GetNumQuestLogChoices, "GetNumQuestLogChoices", id, true) do
        local ok, name, texture, quantity, quality, _, itemID = pcall(GetQuestLogChoiceInfo, j)
        if ok and itemID then
            out.choices[#out.choices + 1] = itemReward(itemID, name, texture, quantity, quality)
        else
            local info = currency(j, true)
            if info then out.choices[#out.choices + 1] = info end
        end
    end

    out.money = count(GetQuestLogRewardMoney, "GetQuestLogRewardMoney", id)
    out.xp    = count(GetQuestLogRewardXP, "GetQuestLogRewardXP", id)

    -- The selection is a thing the player can see, so hand it back.
    if Q and Q.SetSelectedQuest and restore then pcall(Q.SetSelectedQuest, restore) end

    out.empty = #out.currencies == 0 and #out.items == 0 and #out.choices == 0
        and out.money == 0 and out.xp == 0

    -- A pending answer is not an answer. Caching one would pin "loading"
    -- on the row for the session, because the event that would have
    -- cleared it is the same event that has already fired by then.
    --
    -- Nor is an answer with a nameless item in it. Caching that is exactly
    -- how "Item" would stick on the tooltip for the rest of the session.
    if not (out.pending or out.incomplete) then self._rewards[id] = out end
    return out
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

--- Where you are standing, and what the client thinks is on this map.
---
--- Two jobs in one command, because they are asked in the same place --
--- standing in front of a quest giver, wondering how to get the addon
--- to point at them.
---
--- FIRST, the paste-ready giver line. The `giver` tables above cannot be
--- filled in from outside the game: a uiMapID is not derivable and a
--- coordinate off a website is a coordinate nobody checked. Stand on the
--- NPC, run this, copy the line. Same method the quest ids came in by,
--- for the same reason -- this addon has shipped a run of invented ids
--- before and every one of them was dead, silently.
---
--- SECOND, what C_QuestLog.GetQuestsOnMap hands back here. That is the
--- open question behind the whole feature: if an un-accepted weekly
--- shows up in it WITH a position, the client can say which of Lady
--- Liadrin's sixteen is this week's and the giver tables are not needed
--- at all. Printed field by field rather than as the fields I expect,
--- because the shape is the thing being asked about.
function Wk:DumpHere()
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not map then
        print("|cffff5555YippYapp:|r the client will not say which map this is")
        return
    end

    local name = "?"
    if C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, map)
        if ok and type(info) == "table" then name = info.name or name end
    end

    print(("|cff00ff00=== %s |cffffd100(uiMapID %d)|r|cff00ff00 ===|r"):format(name, map))

    local x, y
    if C_Map.GetPlayerMapPosition then
        local ok, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
        if ok and pos then
            if pos.GetXY then
                local gotXY, px, py = pcall(pos.GetXY, pos)
                if gotXY then x, y = px, py end
            end
            x, y = x or pos.x, y or pos.y
        end
    end

    if x and y then
        -- The line as it goes into ITEMS, not as a pair of numbers to
        -- reformat by hand. Four decimals is about a yard in a city and
        -- is what the client itself is accurate to.
        print(("       |cffffffffgiver = { map = %d, x = %.4f, y = %.4f, name = \"\" },|r")
            :format(map, x, y))
        print("       |cff888888paste that onto the row, and put the NPC's name in the quotes|r")
    else
        print("       |cff888888no player position on this map|r")
    end

    if C_Map.CanSetUserWaypointOnMap then
        local ok, allowed = pcall(C_Map.CanSetUserWaypointOnMap, map)
        print("       waypoints here: " .. ((ok and allowed) and "|cff00ff00yes|r"
            or "|cffff5555no -- this map refuses user pins|r"))
    end

    -- The open question. Anything with a questID AND an x/y that is not
    -- already in the log is an offer the client can locate, which is the
    -- answer that makes the giver tables unnecessary.
    local onMap = C_QuestLog and C_QuestLog.GetQuestsOnMap
    if not onMap then
        print("       |cff888888C_QuestLog.GetQuestsOnMap is absent on this client|r")
        self:DumpTargets()
        return
    end
    local ok, quests = pcall(onMap, map)
    if not (ok and type(quests) == "table") then
        print("       |cff888888GetQuestsOnMap answered nothing here|r")
        return
    end

    print(("       |cffffd100GetQuestsOnMap: %d entr%s|r"):format(
        #quests, #quests == 1 and "y" or "ies"))
    for i, entry in ipairs(quests) do
        if type(entry) == "table" then
            local fields = {}
            for k, v in pairs(entry) do
                fields[#fields + 1] = tostring(k) .. "=" .. tostring(v)
            end
            table.sort(fields)
            local id = entry.questID
            local inLog = id and C_QuestLog.GetLogIndexForQuestID
                and C_QuestLog.GetLogIndexForQuestID(id) and " |cff00ff00[in log]|r" or ""
            print(("         [%d] %s%s"):format(i, table.concat(fields, "  "), inLog))
            if id then
                local title = questTitle(id)
                if title then print("             " .. title) end
            end
        end
    end

    self:DumpLearnedGivers()
    self:DumpTargets()
end

--- Every giver the account has learned.
---
--- Worth printing next to the rest because it is the answer to both
--- "why does that row have no pin" and "why is that pin in the wrong
--- place" -- the first is an absent line here, the second is a line
--- with coordinates you can compare against where you are standing.
function Wk:DumpLearnedGivers()
    local learned = self:GetLearnedGivers()
    local any = false
    for _ in pairs(learned) do any = true break end

    print("|cffffd100learned givers|r")
    if not any then
        print("       |cff888888none yet -- they arrive as you pick the quests up|r")
        return
    end
    for id, rec in pairs(learned) do
        print(("   %-16s |cffffffff%s|r map %d  %.4f %.4f  |cff888888(%s)|r"):format(
            tostring(id), tostring(rec.name or "?"),
            rec.map or 0, rec.x or 0, rec.y or 0,
            tostring(rec.from or "?")))
    end
end

--- Every row, and what it would point at.
---
--- The answer to "nothing happens when I click". A row has no pin button
--- when there is nowhere to send you, and there are four different
--- reasons for that -- no quest behind the row at all, a family of ids
--- that cannot be narrowed, a giver nobody has recorded yet, or a quest
--- already handed in. From the page they all look identical, so this
--- says which.
---
--- Printed as part of /yh where because that is the command you are
--- already running when you want to fix it: the rows reported as
--- "no giver recorded" are exactly the ones the line above is for.
function Wk:DumpTargets()
    print("|cff00ff00=== weekly rows: where each one points ===|r")

    local Q = C_QuestLog
    for _, item in ipairs(ITEMS) do
        local target, how = self:GetTrackTarget(item)
        local verdict

        if how == "log" then
            verdict = ("|cff00ff00quest %d, in your log|r"):format(target)
        elseif how == "giver" then
            verdict = ("|cff00ff00map pin: %s (%d) %.4f %.4f|r"):format(
                tostring(target.name or "?"), target.map, target.x, target.y)
        elseif how == "offer" then
            verdict = ("|cff00ff00offer pin for quest %d|r"):format(target)
        else
            -- Which of the four, specifically. A row that says "nothing"
            -- and a row that says "eight candidates, none of them
            -- narrowable" are the same on screen and completely
            -- different to fix.
            local ids = item.quests
            if not (ids and #ids > 0) then
                verdict = "|cff888888nothing to point at -- this row is not a place|r"
            elseif not item.giver then
                local open = 0
                if Q and Q.IsQuestFlaggedCompleted then
                    for _, id in ipairs(ids) do
                        local ok, done = pcall(Q.IsQuestFlaggedCompleted, id)
                        if ok and not done then open = open + 1 end
                    end
                end
                if open == 0 then
                    verdict = "|cff888888all " .. #ids
                        .. " of its quests are flagged done -- nothing on offer|r"
                else
                    -- Every one of these fixes itself. Pick the quest up
                    -- once, next to whoever hands it out, and the row
                    -- knows where they stand from then on -- for every
                    -- character on the account, and for every week
                    -- after, whichever of the family is live.
                    verdict = ("|cffffd100%d outstanding, no giver yet -- "
                        .. "/yh where set %s|r |cff888888(on the NPC), or "
                        .. "/yh where set %s <x> <y> from anywhere in the zone|r")
                        :format(open, tostring(item.id), tostring(item.id))
                end
            else
                verdict = "|cffff5555has a giver but it did not resolve -- "
                    .. "check its map, x and y|r"
            end
        end

        print(("   %-16s %s"):format(tostring(item.id), verdict))
    end
end

--- The same rewards, printed.
---
--- Everything it knows comes from Wk:GetQuestRewards above -- this is a
--- formatter, not a second reader. It used to be the only reader, and
--- splitting it is what let the checklist tooltip show the same answer
--- without the selection dance being written down twice and getting it
--- right once.
function Wk:DumpQuestRewards(id)
    if not id then return end

    local rewards = self:GetQuestRewards(id)
    if not rewards then return end

    local printed = false
    local function header()
        if printed then return end
        printed = true
        print("       |cffffd100rewards|r")
    end

    local function currencyLine(info, isChoice)
        header()
        local known = knownCurrency(info.currencyID)
        print(("         %scurrency %d x%s  %s%s"):format(
            isChoice and "choice " or "",
            info.currencyID,
            tostring(info.quantity or "?"),
            tostring(info.name or "?"),
            known and (" |cff00ff00<- " .. known .. "|r") or ""))
    end

    for _, info in ipairs(rewards.currencies) do currencyLine(info) end

    for _, info in ipairs(rewards.items) do
        header()
        print(("         item %d x%s  %s"):format(
            info.itemID, tostring(info.quantity or 1), tostring(info.name or "?")))
    end

    for _, info in ipairs(rewards.choices) do
        if info.isCurrency then
            currencyLine(info, true)
        else
            header()
            print(("         choice item %d x%s  %s"):format(
                info.itemID, tostring(info.quantity or 1), tostring(info.name or "?")))
        end
    end

    if rewards.money > 0 then
        header()
        local ok, coins = pcall(GetCoinTextureString, rewards.money)
        print("         money " .. ((ok and coins) or (rewards.money .. "c")))
    end

    if rewards.xp > 0 then
        header()
        print("         xp " .. rewards.xp)
    end

    if not printed then
        -- Not the same as "pays nothing". Reward data arrives with the
        -- quest and a quest the client has not fully loaded answers zero
        -- to all of the above, so say which of the two this might be --
        -- and the reader now knows the difference, so say which it is.
        print("       |cff888888no rewards reported -- "
            .. (rewards.pending
                and "the client has not loaded this quest's data yet, so ask again in a moment"
                or "it pays none") .. "|r")
    end

    if #rewards.missing > 0 then
        print("       |cffff5555could not be read on this client:|r |cff888888"
            .. table.concat(rewards.missing, ", ") .. "|r")
    end
end
