local _, ns = ...

------------------------------------------------------------
-- Omnium Folio
--
-- A five-STEP player-power chain introduced in 12.0.7, whose Runes last
-- the rest of Midnight.
--
-- It gated one step per week on release. In 12.1 it is catch-up: every
-- step is available at once, so the whole thing is an evening rather
-- than five weeks. Nothing here is time-gated any more, and an alt that
-- never started it is behind by one evening, not by a month -- worth
-- knowing before writing any advice that leans on urgency.
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
OF.INTRO_QUEST = 96223          -- The Magisters' Call — chain STARTS here
OF.UNLOCK_QUEST = 96233         -- The Omnium Reawakens — chain ENDS here
OF.ACHIEVEMENT = 63325          -- Omnium Folio Studies (earn 5 Motes)

-- One achievement per week, and they are ACCOUNT-WIDE — which the quest
-- flags are not. That difference is the whole point: an alt that never
-- touched the chain has no quest completions, so a purely quest-based
-- read shows it 0/5 and nags about work the character cannot do and the
-- account has already finished.
--
-- Confirmed as the five criteria of 63325 rather than guessed: that meta
-- ("earn 5 Motes") references exactly 62606-62610 and nothing else.
--
-- Caveat worth keeping: Wowhead's guide says 62606 "The Sunstrider
-- Omnium" is granted by the unlock quest, yet it also sits in the meta
-- as one of the five motes. Both may be true — the unlock hands over the
-- first mote. So it is mapped to week 1 for progress, but the unlock
-- gate deliberately does NOT hang on it; that stays on quest 96233,
-- which is per-character and is the thing that decides whether this
-- character can pick the weeklies up at all.
OF.WEEK_ACHIEVEMENTS = { 62606, 62607, 62608, 62609, 62610 }

-- The unlock is a questline, not a single quest, and IsUnlocked() used
-- to test the quest that STARTS it. Finish the first step and the addon
-- declared the Folio open and pointed at Week 1 — while the player was
-- still eight quests from the thing existing. It reported "unlocked" to
-- someone sitting on "Return to the Omnium", two steps short.
--
-- Blizzard allocated the chain contiguously from the intro, and the
-- guide is explicit that "The Omnium Reawakens" is the one that opens
-- the Folio, so that is the quest the gate hangs on.
--
-- 96224/96225 share a name and 96238 duplicates "Return to the Omnium";
-- they look like alternates or an alt-skip path. Progress is therefore
-- measured by the FURTHEST step reached rather than by counting
-- completions, so a player who only ever sees one of a pair does not
-- get a progress bar that can never fill.
OF.INTRO_CHAIN = {
    { id = 96223, name = "The Magisters' Call" },
    { id = 96224, name = "The Magisters' Conundrum" },
    { id = 96226, name = "Omnium Anomalies" },
    { id = 96227, name = "Lycaneum Chaos" },
    { id = 96228, name = "The Shadowed Spire" },
    { id = 96229, name = "The Void Reveals" },
    { id = 96230, name = "Unraveling the Wards" },
    { id = 96231, name = "The Grand Magister's Key Cipher" },
    { id = 96232, name = "Return to the Omnium" },
    { id = 96233, name = "The Omnium Reawakens" },
}

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

-- The five steps, in order. Called "weeks" by the game's own quest
-- titles ("Seeking Knowledge Week 1 of 5") even though 12.1 no longer
-- makes you wait between them. `items` are tracked so the page can
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
--- Achievements are account-wide, which is the whole reason this exists
--- alongside the per-character quest checks above.
---
--- Declared here, with the other helpers, because Lua locals are not
--- hoisted: defined below GetStepStatus it would resolve to a nil global
--- inside it, and the call only fires on an alt — so the error would
--- have waited for exactly the case this was written for.
local function achievementEarned(achieveID)
    if not achieveID or not GetAchievementInfo then return false end
    local ok, _, _, _, completed = pcall(GetAchievementInfo, achieveID)
    return (ok and completed) and true or false
end

local function bagCount(itemID)
    if not itemID or not C_Item or not C_Item.GetItemCount then return nil end
    local ok, count = pcall(C_Item.GetItemCount, itemID, true)
    if ok then return count end
    return nil
end

function OF:IsUnlocked()
    return questCompleted(self.UNLOCK_QUEST)
end

--- How far into the unlock questline the character has got: the index of
--- the furthest step completed or currently taken, plus the chain length
--- and that step's own entry.
---
--- Furthest-reached rather than a count, because the chain has alternate
--- steps (see INTRO_CHAIN) and counting would strand the display one
--- short forever for anyone who only saw one of a pair.
function OF:GetIntroProgress()
    local furthest, step = 0, nil
    for i, entry in ipairs(self.INTRO_CHAIN) do
        if questCompleted(entry.id) or questInLog(entry.id) then
            furthest, step = i, entry
        end
    end
    return furthest, #self.INTRO_CHAIN, step
end

--- The unlock step to point the player at: the one they are holding, or
--- the next one they have not finished. nil once the Folio is open.
function OF:GetIntroNextStep()
    if self:IsUnlocked() then return nil end
    for _, entry in ipairs(self.INTRO_CHAIN) do
        if questInLog(entry.id) then return entry, true end
    end
    for _, entry in ipairs(self.INTRO_CHAIN) do
        if not questCompleted(entry.id) then return entry, false end
    end
    return nil
end

--- Status for one step: "done" | "account" | "active" | "todo", plus a
--- progress line.
---
--- "account" means another character finished this week. Motes and Runes
--- are account-wide, so the reward is already banked and there is
--- nothing here for this character to do — but the quest flag is
--- per-character, so without this an alt reads the whole chain as "not
--- started" and looks like five weeks of outstanding work.
function OF:GetStepStatus(step)
    if questCompleted(step.questID) then
        return "done", nil
    end

    local objText, finished = questObjectiveText(step.questID)
    if objText then
        return "active", objText, finished
    end

    -- Checked after the quest log so a character actively working the
    -- step still shows its live objective text rather than being told
    -- someone else already did it.
    local achieveID = self.WEEK_ACHIEVEMENTS and self.WEEK_ACHIEVEMENTS[step.week]
    if achieveID and achievementEarned(achieveID) then
        return "account", "Done on another character"
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

--- Weeks finished anywhere on the account.
---
--- Achievements are account-wide, so this is the honest answer to "has
--- this been done" on any character. GetProgress() answers the narrower
--- "did THIS character do it", which is what the weekly quest pickup
--- actually depends on.
function OF:GetAccountProgress()
    local done = 0
    for _, achieveID in ipairs(self.WEEK_ACHIEVEMENTS or {}) do
        if achievementEarned(achieveID) then done = done + 1 end
    end
    return done, #(self.WEEK_ACHIEVEMENTS or {})
end

--- True once the account has all five Motes, by the meta achievement or
--- by having every week's achievement. Checking both because the meta
--- can lag behind its own criteria.
function OF:IsAccountComplete()
    if achievementEarned(self.ACHIEVEMENT) then return true end
    local done, total = self:GetAccountProgress()
    return total > 0 and done >= total
end

--- Completed weeks and how many Runes rows that unlocks.
---
--- Per-character on purpose: this drives "what can you do this week",
--- and the weeklies can only be taken on a character that finished the
--- unlock chain. Use GetAccountProgress for "is this done at all".
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
