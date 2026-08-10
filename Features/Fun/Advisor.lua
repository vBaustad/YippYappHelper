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

    -- Runs this season.
    if C_MythicPlus and C_MythicPlus.GetRunHistory then
        local runs = try(C_MythicPlus.GetRunHistory, false, true)
        if type(runs) == "table" then
            s.runs, s.runsTen = #runs, 0
            for _, r in ipairs(runs) do
                if (r.level or 0) >= 10 then s.runsTen = s.runsTen + 1 end
            end
        end
    end

    -- Vault.
    if C_WeeklyRewards and C_WeeklyRewards.GetActivities then
        local acts = try(C_WeeklyRewards.GetActivities)
        if type(acts) == "table" then
            s.vaultFilled, s.vaultTotal = 0, #acts
            for _, a in ipairs(acts) do
                if (a.progress or 0) >= (a.threshold or 1) then
                    s.vaultFilled = s.vaultFilled + 1
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

AD.RULES = {
    -- 100s: something is being actively wasted.
    function(s)
        if s.idleAmount >= 90 then
            return { p = 100, text = ("%d %s crests and nothing queued to spend them on. "
                .. "They are not doing anything in there.")
                :format(s.idleAmount, s.idleTrack),
                tips = {
                    "Crest vendor sits in Silvermoon by the Ritual Site",
                    "Spend down before the weekly cap wastes new income",
                } }
        end
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
        if #s.upgrades == 0 and s.stale == 0 and s.ilvl > 0 then
            return { p = 45, text = ("Item level %d and nothing pending. Everything you own "
                .. "is as good as it gets. Go and find better."):format(s.ilvl) }
        end
    end,
    function(s)
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

    ------------------------------------------------------------
    -- Vault
    ------------------------------------------------------------
    function(s)
        if s.vaultTotal and s.vaultFilled == 0 then
            return "Nothing in the vault. Come Tuesday that is a very quiet "
                .. "moment for both of us."
        end
    end,
    function(s)
        if s.vaultTotal and s.vaultFilled and s.vaultFilled > 0
           and s.vaultFilled < s.vaultTotal then
            return ("%d of %d vault slots filled. The remaining %d are not "
                .. "going to fill themselves, and I have checked.")
                :format(s.vaultFilled, s.vaultTotal, s.vaultTotal - s.vaultFilled)
        end
    end,
    function(s)
        if s.vaultTotal and s.vaultFilled == s.vaultTotal then
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
        if s.social and s.guildRuns == 0 then
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
        if s.ilvl > 0 then
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
        local n = ns.FunStats and ns.FunStats:Get("homeOpens") or 0
        if n >= 40 then
            return ("You have opened this panel %d times. The numbers did not "
                .. "change in the last four."):format(n)
        end
    end,
    function(s)
        local n = ns.FunStats and ns.FunStats:Get("homeOpens") or 0
        if n >= 15 and n < 40 then
            return "Back again. Nothing has moved since you last checked, "
                .. "but I admire the optimism."
        end
    end,
    function(s)
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
        local n = #(s.unenchanted or {})
        local gold = floor((GetMoney() or 0) / 10000)
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
        local durability = 0
        for slot = 1, 18 do
            local cur, max = GetInventoryItemDurability(slot)
            if cur and max and max > 0 then
                local pct = cur / max
                if durability == 0 or pct < durability then durability = pct end
            end
        end
        if durability > 0 and durability < 0.35 then
            return ("Your gear is at %d%% durability. Not my problem, but it "
                .. "will shortly be yours."):format(floor(durability * 100))
        end
    end,
    function(s)
        if GetNumSavedInstances and (GetNumSavedInstances() or 0) == 0
           and (s.runs or 0) == 0 then
            return "No lockouts, no keys, no vault. You have logged in to "
                .. "look at me. I am flattered and concerned."
        end
    end,
    function(s)
        local bags = 0
        for bag = 0, 4 do
            bags = bags + (C_Container and C_Container.GetContainerNumFreeSlots
                and C_Container.GetContainerNumFreeSlots(bag) or 0)
        end
        if bags <= 4 then
            return ("%d free bag slots. At some point that becomes a decision "
                .. "you have to make."):format(bags)
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
function AD:Playlist()
    local s = self:Snapshot()
    local out, seen = {}, {}

    local hits = {}
    for _, rule in ipairs(self.RULES) do
        local ok, result = pcall(rule, s)
        if ok and result then table.insert(hits, result) end
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

    if #out == 0 then
        out[1] = { text = "Nothing to report. Suspicious, but I will allow it." }
    end
    return out, s
end

--- The most useful true thing, in character -- with an aside mixed in
--- often enough that he is not purely instructional.
--- Returns (text, snapshot) so callers can render numbers themselves.
function AD:Speak()
    local s = self:Snapshot()
    rotation = rotation + 1

    local best
    for _, rule in ipairs(self.RULES) do
        local ok, result = pcall(rule, s)
        if ok and result and (not best or result.p > best.p) then
            best = result
        end
    end

    -- Anything above 60 is a real problem and always leads. Below that he
    -- is only narrating, so let an aside take the slot most of the time.
    local urgent = best and best.p >= 60
    if not urgent and rotation % 3 ~= 0 then
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
