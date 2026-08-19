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
        detail = "The weekly crest allowance does not carry over.",
        category = "crests",
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
        label = "Collect this week's spark fragment",
        detail = "Two fragments make a spark, and sparks gate crafted gear.",
        category = "crests",
        -- No auto: holding zero fragments is equally consistent with
        -- "not collected" and "collected and already spent", and the
        -- second is the normal case for anyone who crafts.
    },
    {
        id = "bountymap",
        label = "Spend your Trove Hunter's Bounty",
        detail = "In a tier 8+ delve. A guaranteed Hero-track piece, once a week.",
        category = "delves",
        -- Manual. The map is an item and its use is a delve completion;
        -- neither leaves anything a currency or lockout query can see.
        -- Worth a row regardless: it is one guaranteed Hero piece a
        -- week, it expires with the reset, and it is the easiest thing
        -- on this list to forget because nothing in the game nags you.
    },
    {
        id = "vaultweekly",
        label = "Fill the Vault of Atal'Utek bar",
        -- Named as the game names it. Renaming a thing the player has
        -- to go and find in the world is a kindness that costs them
        -- the search.
        detail = "Strikes, incursions, ancient foes and patrols all count. Rewards the bounty map.",
        category = "delves",
        -- Listed above the map it grants, because doing this is how you
        -- get one.
    },
    {
        id = "prey",
        label = "Run this week's prey hunts",
        detail = "Champion-track gear, capped per week.",
        category = "delves",
        -- Manual, and not for want of trying. Dumping every currency the
        -- client caps weekly returns exactly two, and neither is this.
        -- Whatever tracks prey hunts is not a capped currency, so a
        -- guess here would be a row reading "not done" all week.
    },
    {
        id = "worldboss",
        label = "Kill the weekly world boss",
        detail = "Tidebound Grotto. Instanced now rather than out in the world.",
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
        id = "weeklyquest",
        label = "Hand in this week's quest",
        detail = "The recurring quest in the season's zone.",
        category = "delves",
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
    if item.auto then
        local ok, answer = pcall(item.auto)
        if ok and answer ~= nil then return answer and true or false, false end
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
        out[i] = {
            id = item.id, label = item.label, detail = item.detail,
            category = item.category, done = done, manual = manual,
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
