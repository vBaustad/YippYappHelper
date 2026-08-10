local _, ns = ...

------------------------------------------------------------
-- Omnium Folio
--
-- A five-week player-power chain introduced in 12.0.7 whose Runes last
-- the rest of Midnight — so it stays worth finishing well into Season 2,
-- and an alt that never started it is permanently behind.
--
-- Progress is read from the quest log rather than stored by us: each
-- step is a real quest ID, so completion survives reinstalls, works on
-- every character, and cannot drift out of sync with the game.
------------------------------------------------------------

ns.OmniumFolio = ns.OmniumFolio or {}
local OF = ns.OmniumFolio

-- Unlock chain. The intro can be skipped on alts once any character on
-- the account has finished it, but the weekly quests still have to be
-- picked up on a character that completed it.
OF.INTRO_QUEST = 96223          -- The Magisters' Call
OF.ACHIEVEMENT = 63325          -- Omnium Folio Studies (earn 5 Motes)

OF.INTRO = {
    name = "The Magisters' Call",
    questID = OF.INTRO_QUEST,
    where = "Silvermoon City — floating Magister's Missive by the Ritual Site vendors",
    waypoint = "/way #2393 47.9 51.6",
    detail = "Unlocks the Omnium Folio. Once one character finishes it, alts can skip the intro — but the weekly quests still need picking up on a character that completed the chain.",
}

-- Where the weeklies come from once unlocked.
OF.QUEST_GIVER = {
    name = "Magister Umbric",
    where = "The Lycaneum, inside Magisters' Terrace (Isle of Quel'Danas) — not the dungeon",
    waypoint = "/way #2424 63.7 18.6",
    portals = "Portals in Silvermoon: Thalassian University, and the upper bazaar by the Ritual Site vendors",
}

-- The five weekly steps, in order. `items` are tracked so the page can
-- show "3/8 collected" from your bags when the quest is not in the log.
OF.STEPS = {
    {
        week = 1,
        questID = 96410,
        title = "The Omnium Folio",
        task = "Retrieve the Omnium Folio from Grand Magister Rommath",
        where = "Magisters' Terrace, Isle of Quel'Danas",
    },
    {
        week = 2,
        questID = 96441,
        title = "Ritualized Arcana",
        task = "Collect 8 Ritualized Arcana from elites inside Ritual Sites",
        where = "Ritual Sites",
        hint = "Two full Ritual Site runs covers all 8",
        itemID = 274576,
        itemCount = 8,
    },
    {
        week = 3,
        questID = 96442,
        title = "Ley Line Assaults",
        task = "Collect 5 Dark-Ley Coalescence from Void Assaults",
        where = "Void Assaults and Void Incursions",
        hint = "One per Void Assault or Void Incursion",
        itemID = 274577,
        itemCount = 5,
    },
    {
        week = 4,
        questID = 96443,
        title = "Magical Primessence",
        task = "Loot 1 Primessence of Magic from a final boss",
        where = "Any final dungeon or delve boss, or any Raid Finder wing boss",
        hint = "Remember to actually loot the boss",
    },
    {
        week = 5,
        questID = 96444,
        title = "Off-World Magic",
        task = "Defeat Imperator Pertinax (Val) or Nexus-Captain Leth'ir (Naigtal), plus 3 world quests",
        where = "Val or Naigtal",
        hint = "The 3 world quests must be on Val or Naigtal too",
    },
}

-- Rune rows unlocked by each completed week. Row 1 and 3 are the Core and
-- Lingering runes everything else builds on; rows 2, 4 and 5 are choices.
OF.RUNES = {
    {
        row = 1, label = "Core Rune", pick = "choose one",
        runes = {
            { name = "Rune of Void-Touched Orbs", text = "Attract a void orb every 10 sec (max 5). Attacks fling them for Cosmic damage; heals send them to the lowest-health ally." },
            { name = "Rune of Unleashed Fire",    text = "Spells and abilities have a chance to call down a pillar of fire, damaging an enemy or healing an ally." },
        },
    },
    {
        row = 2, label = "Defensive", pick = "choose one",
        runes = {
            { name = "Rune of Self-Mending",       text = "Below 75% health, your Core Rune also heals you." },
            { name = "Rune of Void-Tainted Shell", text = "Struck for over 10% max health grants an absorb; half the absorbed damage lingers as damage over 10 sec." },
            { name = "Rune of Lynxlike Reflexes",  text = "Being struck in combat grants 77.5 Speed for 10 sec." },
        },
    },
    {
        row = 3, label = "Lingering Rune", pick = "automatic",
        runes = {
            { name = "Rune of Lingering", text = "Your Core Rune leaves a periodic effect for 8 sec. The Core Rune favours targets not already affected." },
        },
    },
    {
        row = 4, label = "Secondary stat", pick = "choose one",
        runes = {
            { name = "Rune of Critical Power",       text = "Core Rune effects grant 52.7 Critical Strike. Stacks." },
            { name = "Rune of Burning Haste",        text = "Core Rune effects grant 52.7 Haste. Stacks." },
            { name = "Rune of Masterful Cunning",    text = "Core Rune effects grant 52.7 Mastery. Stacks." },
            { name = "Rune of the Versatile Warrior", text = "Core Rune effects grant 52.7 Versatility. Stacks." },
        },
    },
    {
        row = 5, label = "Amplifier", pick = "choose one",
        runes = {
            { name = "Rune of Overload",         text = "Core Rune effectiveness increased by 100%." },
            { name = "Rune of Residual Energy",  text = "Rune of Lingering effectiveness increased by 100%." },
            { name = "Rune of Echoes",           text = "Core Rune curses the target; after 10 sec, 50% of all Core and Lingering damage and healing repeats." },
        },
    },
}

OF.NOTES = {
    "Runes last the rest of Midnight — this carries into Season 2",
    "Each completed step awards a Mote of Omnial Inquiry and unlocks the next Rune row",
    "The chain released one step per week, so catching up now usually means several are available at once",
    "Five Motes earns the Omnium Folio Studies achievement and its housing decor",
    "Once unlocked, open the Folio from the Omnium icon by your minimap",
}

------------------------------------------------------------
-- Progress
------------------------------------------------------------

local function questCompleted(questID)
    if not questID or not C_QuestLog then return false end
    local fn = C_QuestLog.IsQuestFlaggedCompleted
    if not fn then return false end
    local ok, done = pcall(fn, questID)
    return ok and done or false
end

local function questInLog(questID)
    if not questID or not C_QuestLog or not C_QuestLog.GetLogIndexForQuestID then
        return false
    end
    local ok, idx = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
    return ok and idx ~= nil
end

--- Objective text for a quest currently in the log, e.g. "3/8 Ritualized
--- Arcana". Returns nil when the quest is not taken.
local function questObjectiveText(questID)
    if not questInLog(questID) then return nil end
    if not C_QuestLog.GetQuestObjectives then return nil end
    local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
    if not ok or type(objectives) ~= "table" then return nil end
    for _, obj in ipairs(objectives) do
        if obj and obj.text and obj.text ~= "" then
            return obj.text, obj.finished
        end
    end
    return nil
end

--- Items already in your bags toward a step, for the case where the
--- quest is not in the log yet but the drops are hoarded.
local function bagCount(itemID)
    if not itemID or not C_Item or not C_Item.GetItemCount then return nil end
    local ok, count = pcall(C_Item.GetItemCount, itemID, true)
    if ok then return count end
    return nil
end

function OF:IsUnlocked()
    return questCompleted(self.INTRO_QUEST)
end

--- Status for one step: "done" | "active" | "todo", plus a progress line.
function OF:GetStepStatus(step)
    if questCompleted(step.questID) then
        return "done", nil
    end

    local objText, finished = questObjectiveText(step.questID)
    if objText then
        return "active", objText, finished
    end

    -- Not taken yet — show what you are already carrying, if anything.
    if step.itemID and step.itemCount then
        local have = bagCount(step.itemID)
        if have and have > 0 then
            return "todo", ("%d/%d already in bags"):format(
                math.min(have, step.itemCount), step.itemCount)
        end
    end
    return "todo", nil
end

--- Completed weeks and how many Runes rows that unlocks.
function OF:GetProgress()
    local done = 0
    for _, step in ipairs(self.STEPS) do
        if questCompleted(step.questID) then done = done + 1 end
    end
    return done, #self.STEPS
end

--- The step the player should do next, or nil when finished.
function OF:GetNextStep()
    for _, step in ipairs(self.STEPS) do
        if not questCompleted(step.questID) then return step end
    end
    return nil
end
