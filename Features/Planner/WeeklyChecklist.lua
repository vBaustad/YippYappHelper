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
--- A currency's quantity, or nil if the client has nothing to say.
local function currency(id)
    if not (id and id > 0 and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then
        return nil
    end
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
    if not ok or type(info) ~= "table" then return nil end
    return tonumber(info.quantity)
end

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
        id = "catalyst",
        label = "Spend a catalyst charge",
        detail = "Charges accumulate, but an unspent charge is a tier piece you do not have.",
        category = "crests",
        auto = function()
            -- Deliberately the opposite reading to the others: charges
            -- accrue rather than deplete, so "done" is having none left
            -- to spend, not having some.
            local n = currency(ns.CATALYST_CURRENCY_ID)
            if n == nil then return nil end
            return n == 0
        end,
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
        label = "Hand in the weekly quest",
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

--- Every currency the client caps weekly, as checklist items.
---
--- Discovered rather than named. Three attempts at naming these were
--- wrong in three different ways -- "Restored Coffer Key" is not the
--- capped one, the shards are; nothing matching prey hunts is a currency
--- at all; and a season I have never seen will have its own. The client
--- already knows which currencies it caps and how far along this
--- character is, so the list asks it instead of carrying a table that is
--- wrong the day a patch ships.
---
--- Ordered by id so the rows do not reshuffle between refreshes.
local function currencyItems()
    local out = {}
    if not (ns.GetCurrencyGroups and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then
        return out
    end
    local hidden = (YippYappHelperDB and YippYappHelperDB.weeklyHidden) or {}
    for _, group in ipairs(ns:GetCurrencyGroups() or {}) do
        for _, entry in ipairs(group.items or {}) do
            local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, entry.currencyID)
            local cap = ok and type(info) == "table"
                and (tonumber(info.maxWeeklyQuantity) or 0) or 0
            -- Discovery finds everything the client caps, which is not
            -- the same as everything worth doing -- Shard of Dundun is
            -- capped and nobody cares. There is no property that sorts
            -- those two apart, so the player says. Hidden rows are
            -- account-wide: a currency that does not matter on one
            -- character does not matter on the next.
            if cap > 0 and not hidden[tostring(entry.currencyID)] then
                local earned = tonumber(info.quantityEarnedThisWeek) or 0
                out[#out + 1] = {
                    id = "cur:" .. tostring(entry.currencyID),
                    _sort = entry.currencyID or 0,
                    label = ("Cap %s"):format(entry.name or "?"),
                    detail = ("%d of %d earned this week."):format(earned, cap),
                    category = "crests",
                    auto = function() return earned >= cap end,
                }
            end
        end
    end
    table.sort(out, function(a, b) return a._sort < b._sort end)
    return out
end

--- The whole list with its state resolved, for rendering.
---
--- Fixed items first, then whatever the client caps. The fixed ones are
--- the judgement calls; the discovered ones are facts, and facts can
--- appear and disappear between seasons without disturbing the order of
--- anything above them.
function Wk:GetList()
    local out = {}
    local all = {}
    for _, item in ipairs(ITEMS) do all[#all + 1] = item end
    for _, item in ipairs(currencyItems()) do all[#all + 1] = item end

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

--- Stop showing a discovered currency row. Only discovered ones: the
--- fixed items are the ones deliberately chosen, and hiding those would
--- be a settings screen rather than a nuisance filter.
function Wk:Hide(id)
    local key = tostring(id or ""):match("^cur:(%d+)$")
    if not key then return false end
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.weeklyHidden = YippYappHelperDB.weeklyHidden or {}
    YippYappHelperDB.weeklyHidden[key] = true
    return true
end

--- Bring them all back, for when a season changes and the judgement
--- that hid one no longer applies.
function Wk:UnhideAll()
    if YippYappHelperDB then YippYappHelperDB.weeklyHidden = nil end
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
