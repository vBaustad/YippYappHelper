local _, ns = ...

------------------------------------------------------------
-- The Venomous Abyss, in words a first-timer can act on.
--
-- Everything here is a mechanic and what to DO about it -- deliberately
-- not a spell list. The Encounter Journal already tells you that Essence
-- Rend deals shadow damage over 15 seconds; what it does not tell you is
-- "walk out of the middle before your healer dispels you, because the
-- puddle it leaves is permanent", and that is the sentence that matters.
--
-- Written at one reading level on purpose. The ask was "explain it like
-- the player is five", and the useful reading of that is not baby talk --
-- it is: one idea per line, name the thing, say what it does to you, say
-- what you do about it, in that order. No jargon that is not defined on
-- the same screen.
--
------------------------------------------------------------
-- SOURCES, and what each one is good for.
--
-- 1. Per-boss guides (Method, via transcript) for Nek'zali, the
--    Sentinels, the Explorers, Vashnik, Sszorak and the Twin Fangs.
--    These are the authority for MECHANICS: they name the abilities,
--    give the numbers, and say what the raid does about each one. Where
--    they disagreed with the earlier all-boss preview, they won.
--
-- 2. An all-boss preview covering the whole raid, which is the only
--    source for The Coiled Altar until a full guide exists.
--
-- Both are PTR footage. Tuning numbers may have moved, and the Twin
-- Fangs was reworked after the footage was taken -- flagged on that
-- boss rather than left as a general disclaimer nobody reads.
--
-- 3. Names come from the client, not from any video -- see below.
--
------------------------------------------------------------
-- A NOTE ON NAMES.
--
-- Auto-generated captions are reliable for mechanics and useless for
-- proper nouns. The first pass at this file was written from them, and
-- gave us "Nexxus-Asol", "Sister Rag" and "Scroll Sage Ik'kinu" -- the
-- same boss spelled three ways inside one minute. The bosses are now
-- named from three sources already sitting on this machine, none of
-- which is a video:
--
--   * BigWigs_TheVenomousAbyss  -- one module per boss, each declaring
--     BigWigs:NewBoss(name, 3004, journalID) and SetEncounterID.
--   * Plumber's ExpansionLandingPage\EncounterData.lua -- the same eight
--     journal IDs, each commented with its boss name.
--   * RaiderIO's enUS locale -- RAID_BOSS_VA_1..8, which also settles
--     the PULL ORDER, since journal ID order does not.
--
-- All three agree on the names. Where two disagreed -- BigWigs calls
-- journal 2883 "The Bargained Crown", the other two "The Coiled Altar"
-- -- the majority won, and it is the name this addon's Progression page
-- already used.
--
-- The NPCs inside an encounter are a harder problem, because no journal
-- encounter name reaches them. Those come from
-- NorthernSkyRaidTools' saved variables, whose alert conditions are
-- hand-typed by its authors and name them outright ("Trader Gebbo",
-- "First Mate Nama", "Scrollsage Iku"), corroborated where possible by
-- loot in this addon's own trinket data ("Gebbo's Bottomless Bag",
-- "Zul'jin's Guillotine Technique", "Hex Lord's Dooming Idol").
--
-- Anything still resting on a caption alone carries `unsure = true`, the
-- page marks it with one dim `?` and explains it once at the foot. Two
-- are left: Hex Lord Malacrass, and the twins' own names.
--
-- Zul'jin, not "Zul'jan": the captions render it both ways, and the item
-- name in TrinketData.lua does not.
--
-- The IDs are recorded per boss so RaidGuideEJ can select the encounter
-- outright instead of guessing at it by name, and read its abilities.
-- `/yh ejdump abilities` prints what the client holds against what we
-- wrote, including the abilities we never mention.
------------------------------------------------------------

ns.RaidGuide = ns.RaidGuide or {}
local G = ns.RaidGuide

G.instance = {
    name   = "The Venomous Abyss",
    season = "Midnight Season 2",
    -- 3004, from every BigWigs module's LoadOn-InstanceId and its
    -- NewBoss call. Still confirmed at runtime by name -- the ID is a
    -- head start, not a thing to trust blindly -- but it is no longer a
    -- number nobody outside the client could check.
    instanceID = 3004,
    ejInstanceID = nil,
    note = "Normal and Heroic. Written from pre-launch guides, so tuning "
        .. "numbers may have moved -- the mechanics are the part that holds.",
}

-- Difficulty tags a mechanic can carry.
--   "both"   -- happens on normal and heroic
--   "heroic" -- heroic only, ignore it on normal
--   "normal" -- the easier normal-only version of a heroic mechanic
G.DIFF = { BOTH = "both", HEROIC = "heroic", NORMAL = "normal" }

------------------------------------------------------------
-- The bosses.
--
-- `rules` is the part that matters. If a player reads three lines before
-- a pull, these are the three -- the things that wipe the raid rather
-- than the things that hurt. `phases` is one page each in the UI, for
-- the player who has already wiped once and wants to know why.
--
-- `bring` is the comp note, and only ever the DIFFERENCE from a standard
-- two tanks / four healers / fourteen DPS. Repeating "standard comp" on
-- seven bosses tells nobody anything.
--
-- `heroicUnknown` marks a fight whose source covered Normal and Heroic
-- in one pass without separating them. An empty Heroic page would
-- otherwise read as "nothing extra happens", which is a claim no source
-- has made.
------------------------------------------------------------
G.bosses = {

    ----------------------------------------------------------
    {
        id      = "soulcoiler",
        order   = 1,
        name    = "Nek'zali the Soulcoiler",
        ejID    = 2888,
        encounterID = 3470,
        accent  = { 0.66, 0.45, 1.00 },
        oneLiner = "Nothing reaches the well in the middle. Including you.",
        shape   = "2 phases + intermission",

        rules = {
            "Kill the Restless Amani adds before they walk into the well. Magic "
                .. "damage strips their shield, then they die like normal adds.",
            "Every add that reaches the well feeds the boss 5 energy and dots the "
                .. "raid. At 100 energy she enrages and the pull is over.",
            "Essence Rend leaves a PERMANENT puddle where it ends. Walk to the "
                .. "side of the room first -- never leave one in the middle.",
        },

        phases = {
            {
                name = "Phase one",
                tag  = "100% to 50%",
                lines = {
                    "Tank her at the entrance, facing away. The raid stands behind "
                        .. "her, and nobody stands in the well.",
                    "Restless Amani spawn from the sides of the room and walk at the "
                        .. "well for as long as their shield holds. Magic damage is "
                        .. "what strips it.",
                    "Possession Barrage sends four spirits out at the tank. Each one "
                        .. "hits the whole raid harder the closer you are, and pops on "
                        .. "the first player it touches -- so the tank stands 30 yards "
                        .. "out and nobody else stands in the line.",
                    "Haunting Strikes cuts the tank's incoming healing. Taunt swap at "
                        .. "30-40% before the healers start shouting.",
                    "Essence Rend tugs you toward the middle for a moment, then ticks "
                        .. "for 15 seconds. It is dispellable, and it drops that "
                        .. "permanent puddle wherever you are when it ends.",
                    "Soul Coil Ignition is four raid hits back to back, on her own "
                        .. "timer. Healing cooldown.",
                },
            },
            {
                name = "Intermission",
                tag  = "at 50% -- cleanup duty",
                lines = {
                    "She goes to the middle and turns immune. Soul Transfer channels "
                        .. "into one side of the room for 15 seconds and spawns an "
                        .. "Echo. Do not be standing in the beam when it lands.",
                    "Two Echoes, one after the other. Kill both and the intermission "
                        .. "ends.",
                    "Hungering Pyre drops a big circle on the current tank. Soak it as "
                        .. "a group to split the damage -- melee are the ones to send.",
                    "Everybody who does not soak gets a Slithering Flame circle "
                        .. "instead.",
                    "Both of those BURN CORPSES, and that is the real job here: dead "
                        .. "Amani come back as empowered adds through Vessel of "
                        .. "Awakening.",
                    "So park the Pyre on the biggest pile of bodies and walk your own "
                        .. "circle over the leftovers.",
                },
            },
            {
                name = "Phase two",
                tag  = "50% to 0%, and the clock is her energy",
                lines = {
                    "Uncoiling is raid damage every second from here to the end. "
                        .. "Healers are working.",
                    "Invoke picks up every puddle from phase one and sets them "
                        .. "travelling around the well. Watch them move.",
                    "Everything from phase one keeps happening, adds included.",
                    "Hero here, and kill her before she reaches 100 energy.",
                },
            },
        },

        heroic = {
            "Every add that reaches the well also stacks Ritual Burn on the boss, so "
                .. "each raid hit after it lands harder. One add is a mistake; three "
                .. "in a row is a wipe.",
            "Get to Soul Coil Ignition with zero Ritual Burn stacks. That is the "
                .. "difference between a heal check and a reset.",
        },

        roles = {
            DAMAGER = {
                "Magic damage strips the add shields. If you have any, that is your "
                    .. "job on every spawn.",
                "Stuns, slows, roots and grips all work on them. One that is held is "
                    .. "one that is not walking.",
                "In the intermission, cleave the Echo and the adds together.",
            },
            HEALER = {
                "Essence Rend is a magic dispel, but the puddle lands wherever that "
                    .. "player is standing when it ends. Let them walk out first.",
                "Stacking the raid and mass dispelling works -- as long as you do it "
                    .. "away from the middle.",
                "Phase two is constant passive damage on top of everything else. Save "
                    .. "a cooldown for it.",
            },
            TANK = {
                "Possession Barrage: stand 30 yards out, pointed away. Its spirits "
                    .. "hurt by distance and pop on the first body they touch.",
                "Swap on Haunting Strikes at 30-40% healing reduction.",
                "Hungering Pyre lands on you in the intermission. Put it on the "
                    .. "corpses.",
            },
        },

        lust = "phase two -- it is a race against her energy bar",
    },

    ----------------------------------------------------------
    {
        id      = "sentinels",
        order   = 2,
        name    = "Entombed Sentinels",
        ejID    = 2874,
        encounterID = 3445,
        accent  = { 0.45, 0.90, 0.40 },
        oneLiner = "Two golems, 40 yards apart -- and then the raid does maths.",
        shape   = "1 phase + the maths",

        rules = {
            "Keep the two golems at least 40 yards apart or they take 99% reduced "
                .. "damage. One team left, one team right.",
            "Keep their health even. At 100 energy Vitriolic Stasis heals the lower "
                .. "one up to the higher, so a side that races ahead did that damage "
                .. "for nothing.",
            "In the intermission you get four orbs, red and green. Touch the player "
                .. "whose GREEN orbs plus yours make exactly four.",
        },

        phases = {
            {
                name = "The green golem",
                tag  = "droplets and the blob",
                lines = {
                    "Toxic Droplets scatters orbs across the floor. Run over each one "
                        .. "-- it hurts a little and leaves a small dot.",
                    "One left alone for 60 seconds is a massive raid hit instead, so "
                        .. "this is a real assignment and not a chore.",
                    "Venom Coagulation spawns a blob that pulses raid damage until it "
                        .. "dies. Priority target, every time.",
                    "Blightburn fires green lines out and then back to the boss. Dodge "
                        .. "them both ways.",
                    "Empowering Slam is the tank hit. It ramps on whoever it keeps "
                        .. "hitting and only resets when it lands on somebody else.",
                },
            },
            {
                name = "The red golem",
                tag  = "the harder side",
                lines = {
                    "Start this side in a corner. Everything here leaves a puddle, and "
                        .. "you will want the clean floor later.",
                    "Blood Venom drops a puddle when it expires OR when it is "
                        .. "dispelled. You get it from Blighted Blood, and from "
                        .. "soaking.",
                    "Debilitating Miasma lands on one player and has to be split by "
                        .. "the whole side. Everybody soaks, together.",
                    "Then walk somewhere useless before the puddles fall, because they "
                        .. "land under every soaker a few seconds later.",
                    "Injecting Strike is the tank hit -- the same ramp as the green "
                        .. "side, plus a large puddle when the debuff expires.",
                },
            },
            {
                name = "The dots",
                tag  = "why you swap sides at all",
                lines = {
                    "Each golem stacks its own dot on everyone in range, running 40 "
                        .. "seconds.",
                    "Swapping sides in the intermission is what lets those stacks fall "
                        .. "off. It is not a positioning gimmick.",
                    "Standing in the middle to hit both bosses gives you both dots. "
                        .. "Multi-dot classes: briefly, not for the whole phase.",
                },
            },
            {
                name = "Intermission",
                tag  = "Helical Toxins -- the maths bit",
                lines = {
                    "Both bosses go immune. There is far more time than it feels like "
                        .. "-- look around, and do not panic.",
                    "Four orbs over every head, split between red and green.",
                    "Find a player whose GREEN orbs added to yours make exactly four. "
                        .. "One green looks for three green.",
                    "Touch them and both debuffs clear.",
                    "Get it wrong, or run out of time, and you get Cultivated Burst: "
                        .. "little damage, big puddle. Take it to a corner nobody "
                        .. "needs.",
                    "When everyone is clear the bosses swap sides and the fight "
                        .. "repeats. The red team starts in the corner without "
                        .. "puddles.",
                },
            },
        },

        heroic = {
            "Popped droplets leave spikes that fire from where you popped them toward "
                .. "the boss. Clear them where that line will not cross the raid.",
            "A few seconds after Debilitating Miasma, every soaker drops blood that "
                .. "expands outward -- which is why that soak happens near the edge.",
            "Puddles everywhere means the raid slowly rotates around the room instead "
                .. "of standing still like it can on normal.",
        },

        roles = {
            DAMAGER = {
                "Venom Coagulation first, every time, no exceptions.",
                "Pop the droplets. They are a raid hit on a 60-second fuse.",
                "Watch your side's health against the other side -- Vitriolic Stasis "
                    .. "refunds the difference, so racing is wasted damage.",
            },
            HEALER = {
                "Blood Venom is dispellable, and dispelling it drops the puddle there "
                    .. "and then. Time it; do not just clear it.",
                "Debilitating Miasma is a whole-side soak. If your side is late, the "
                    .. "target dies.",
                "Both golems' dots sit on everyone in range and only fall off after "
                    .. "the swap.",
            },
            TANK = {
                "40 yards between the bosses at all times. That is the fight.",
                "Your slam ramps until it hits somebody else, so the tanks swap sides "
                    .. "in the intermission too.",
                "Coming off the red golem, walk somewhere safe before Injecting Strike "
                    .. "expires -- it leaves a large puddle.",
            },
        },

        lust = "on pull",
    },

    ----------------------------------------------------------
    {
        id      = "explorers",
        order   = 3,
        name    = "The Lost Explorers",
        ejID    = 2894,
        encounterID = 3497,
        accent  = { 1.00, 0.75, 0.30 },
        oneLiner = "Three turtles, a fish, and a troll's energy bar you keep resetting.",
        shape   = "3 bosses, one empowered at a time",
        bring   = "heavy cleave and multi-dot",

        rules = {
            "Never let all three turtles stack together -- United Defense makes them "
                .. "immune. Two in cleave range is fine.",
            "Break Gebbo's boxes. One holds the fish, and any box left 25 seconds is "
                .. "Rallying Roar, a heavy raid-wide hit.",
            "Feed the fish to a turtle before Mor'zaki fills his energy bar. Final "
                .. "Ascension is a wipe.",
        },

        phases = {
            {
                name = "Mor'zaki",
                tag  = "the one you never fight",
                unsure = true,
                lines = {
                    "He cannot be touched. Malevolent Presence is permanent raid "
                        .. "damage, and his energy bar is the fight timer.",
                    "Feeding the fish to a turtle resets that bar to zero and hits the "
                        .. "raid with Fishy Feedback.",
                    "His Command then empowers the turtle you fed, permanently. You "
                        .. "cannot feed the same one twice, so you get three resets.",
                    "The fourth time he fills there is no fish left. That is the "
                        .. "enrage, and it is your real kill timer.",
                },
            },
            {
                name = "Scrollsage Iku",
                tag  = "the caster",
                lines = {
                    "Blink Nova teleports her to a random player and hits the raid "
                        .. "reduced by distance. Be 30 yards from the group and it is "
                        .. "nothing.",
                    "Icebound Flames is heavy damage and a 50% slow, and it CAN be "
                        .. "interrupted. Set a kick order and keep it covered.",
                    "Shredding Shards stacks +50% damage from itself on her tank. Swap "
                        .. "with Nama's tank once it bites.",
                },
            },
            {
                name = "First Mate Nama",
                tag  = "the shells",
                lines = {
                    "He fires shells in the direction he is FACING. Getting hit is "
                        .. "damage and a 4-second stun, so move out of the line "
                        .. "wherever you happen to be standing.",
                    "His melee adds 4% physical damage taken to his tank with every "
                        .. "hit.",
                },
            },
            {
                name = "Trader Gebbo",
                tag  = "the one walking in circles",
                lines = {
                    "Not tanked, and not tankable. He wanders the room dropping boxes "
                        .. "near players.",
                    "Stepping on a box is a stacking bleed for 8 seconds. Break them "
                        .. "anyway.",
                    "Put two or three players on box duty, ideally ones who can shed a "
                        .. "bleed or tank one.",
                },
            },
            {
                name = "Iku empowered",
                tag  = "Frostfire Volley, three sets",
                lines = {
                    "Fire missiles on some players, ice on others. Each leaves a large "
                        .. "puddle and a one-minute dot.",
                    "Clear your dot by walking into the OPPOSITE puddle. That removes "
                        .. "the debuff and the puddle together.",
                    "Do it before the next set lands. If the other element hits you "
                        .. "while you still carry the first, Elemental Explosion very "
                        .. "likely wipes the raid.",
                    "This is the one to be scared of. Clear early, every time.",
                },
            },
            {
                name = "Nama empowered",
                tag  = "Mighty Thud",
                lines = {
                    "Three players get marked, and he leaps to them CLOSEST FIRST.",
                    "The marked player takes the damage, split with everybody standing "
                        .. "in it. Three soak groups, one per mark.",
                    "There is no soak debuff, so the same people could technically "
                        .. "take all three -- but each landing knocks back and the next "
                        .. "follows fast, so three groups is the safe setup.",
                    "Each landing leaves an aftershock puddle for 30 seconds. Soak, "
                        .. "then get out of it.",
                },
            },
            {
                name = "Gebbo empowered",
                tag  = "mushrooms and a bomb",
                lines = {
                    "Explosive Surprise hands one player a bomb to place. Put it at "
                        .. "the edge -- it leaves a big shrinking puddle behind.",
                    "Mushroom Toss drops a mushroom wherever a player is standing.",
                    "The bomb sends out a blast wave. Step onto a mushroom as it "
                        .. "arrives and you bounce over it; a blink, leap or teleport "
                        .. "does the same job.",
                    "Do not touch a mushroom early. The first person to touch it sets "
                        .. "it off, and it expires seconds later.",
                },
            },
            {
                name = "Feed order, and the kill",
                tag  = "decide this before you pull",
                lines = {
                    "Recommended: Iku first, then Nama, then Gebbo. The hardest "
                        .. "ultimate then runs for the shortest part of the fight.",
                    "All three turtles enrage the moment any ONE of them dies, so "
                        .. "bring the three health bars down together.",
                    "If you are forced to stagger: Gebbo, then Nama, then Iku.",
                    "Iku is by far the worst -- she explodes for raid-wide damage that "
                        .. "grows with every cast. Nama gains 100% damage a second. "
                        .. "Gebbo just ping-pongs the raid.",
                },
            },
        },

        heroicUnknown = true,

        roles = {
            DAMAGER = {
                "Boxes are a real assignment. Two or three of you, or the fish never "
                    .. "shows up and Rallying Roar does.",
                "You own the kick order on Iku's Icebound Flames.",
                "Three health bars, one kill. Watch the other two as much as your own "
                    .. "target.",
            },
            HEALER = {
                "The box bleed stacks across everyone on cleanup duty. Expect chip "
                    .. "damage all fight, on top of Malevolent Presence.",
                "Frostfire Volley's dot runs a full minute and there are three sets. "
                    .. "That is where your cooldowns go.",
                "Mighty Thud is three big split hits in a row -- one per group.",
            },
            TANK = {
                "You tank two of the three. Gebbo walks his own patrol and cannot be "
                    .. "picked up.",
                "Swap between Iku and Nama on Shredding Shards, and watch the 4% per "
                    .. "hit stacking from Nama's melee.",
                "Nama's shells go where he is FACING, so point him somewhere the raid "
                    .. "is not.",
            },
        },

        lust = "on pull",
    },

    ----------------------------------------------------------
    {
        id      = "vashnik",
        order   = 4,
        name    = "Vashnik the Malignant",
        ejID    = 2882,
        encounterID = 3455,
        accent  = { 1.00, 0.40, 0.30 },
        oneLiner = "Two fountains at a time, and nothing may reach the pool.",
        shape   = "1 phase, 3 fountains",

        rules = {
            "At 100 energy Imbibe drinks from the TWO NEAREST fountains. Where the "
                .. "raid stands is what picks them, so move as a group.",
            "Every add walks for the green pool in the middle. One arriving dots the "
                .. "whole raid; two arriving is a wipe.",
            "Rotation: blood + shadow, then shadow + fire, then fire + blood, repeat. "
                .. "Always pick up a fountain you did not just use.",
        },

        phases = {
            {
                name = "The three fountains",
                tag  = "blood at the back, shadow right, fire left",
                lines = {
                    "Each drink hits the raid, empowers those two fountains for 90 "
                        .. "seconds, and stacks Toxic Vapor on the boss.",
                    "Empowered means 200% explosion damage and adds with 50% more "
                        .. "health. There is always at least one empowered fountain "
                        .. "live, so the real choice is which one you would rather "
                        .. "handle.",
                    "Toxic Vapor is raid damage every two seconds and it grows with "
                        .. "every drink. That is the fight timer.",
                },
            },
            {
                name = "Blood",
                tag  = "the splitting add, and the leech",
                lines = {
                    "Clotting Venom cannot be crowd controlled, and splits into "
                        .. "smaller pieces when killed. Keep killing until the floor "
                        .. "is clear.",
                    "Siphoning Infection is a huge absorb with 100% healing reduction. "
                        .. "No amount of healing removes it.",
                    "It comes off by LEECHING: other players have to stand in that "
                        .. "player's circle.",
                    "So keep a melee camp and a ranged camp, and infected players walk "
                        .. "into the nearest one.",
                },
            },
            {
                name = "Shadow",
                tag  = "the easy adds",
                lines = {
                    "Shrouded Venom adds can be crowd controlled, and drop circles all "
                        .. "over the floor when they die. Kill them where you are not "
                        .. "standing.",
                    "Stygian Infection is a heal absorb with no healing reduction. "
                        .. "Heal it normally.",
                    "When the Stygian Burst circles appear around those players, they "
                        .. "walk away from everybody else.",
                },
            },
            {
                name = "Fire",
                tag  = "do not kill them together",
                lines = {
                    "Two Burning Venom adds pulse raid damage while they live and "
                        .. "stack a fire dot on the raid.",
                    "Killing both at once is a big raid hit plus dots on everyone. "
                        .. "Crowd control one and nuke the other, or line the kills up "
                        .. "so the second dies as the first debuff falls off.",
                    "Exploding Infection is a heavy dot that EXPLODES on the raid when "
                        .. "dispelled. Stagger the dispels, and never dispel into a "
                        .. "low raid.",
                },
            },
            {
                name = "Whatever is empowered",
                tag  = "the casts that never stop",
                lines = {
                    "Fire and shadow adds can be held -- for 60 seconds. Hardened "
                        .. "Venom then makes them immune and 50% faster, so do not "
                        .. "park them forever.",
                    "Malignant Catalyst is the orb above the pool: raid damage, then "
                        .. "soak circles. At least one player in each, or the raid eats "
                        .. "it instead.",
                    "Plague Rot turns several players into sprinklers hitting anything "
                        .. "within 5 yards, then fires waves in four directions after 8 "
                        .. "seconds. Walk out, then dodge.",
                    "Dripping Fangs is the tank hit: +100% physical damage taken for "
                        .. "32 seconds, so it is a swap every cast.",
                },
            },
        },

        heroicUnknown = true,

        roles = {
            DAMAGER = {
                "The adds ARE the fight. Nothing else you do matters if one reaches "
                    .. "the pool.",
                "Most of you go on blood -- it cannot be held, so it is pure damage.",
                "Two or three take the shadow adds with slows, away from the raid. "
                    .. "Whoever has a grip pulls the fire adds in one at a time.",
            },
            HEALER = {
                "Siphoning Infection cannot be healed off. Call those players into a "
                    .. "camp so they can leech it off instead.",
                "Stygian Infection is a normal absorb -- heal it, and watch them run "
                    .. "out when the burst circles land.",
                "Exploding Infection explodes on the raid when you dispel it. Stagger "
                    .. "them, and never at low raid health.",
            },
            TANK = {
                "Your position picks the fountains. Walk the route the raid agreed, "
                    .. "not to the nearest empty floor.",
                "Dripping Fangs is a swap every single cast.",
                "Keep the boss clear of the Plague Rot waves.",
            },
        },

        lust = "on pull",
    },

    ----------------------------------------------------------
    {
        -- The id stays `sisterrag`. It is a saved-variable key and a
        -- RaidTrainerScenarios key, and renaming it would silently lose
        -- the boss a player had selected. The NAME is what was wrong.
        id      = "sisterrag",
        order   = 5,
        name    = "Sszorak",
        ejID    = 2871,
        encounterID = 3420,
        accent  = { 0.55, 0.85, 1.00 },
        oneLiner = "Count the orbs in the tunnels -- that is the order the wind blows.",
        shape   = "1 phase + intermission",
        bring   = "a fifth healer earns its place",

        rules = {
            "Split into two soak groups before you pull, five players minimum each. "
                .. "Mutilate alternates between them.",
            "Drop cysts on the markers OPPOSITE the tunnels that will blow. Four "
                .. "cysts, three winds, one spare.",
            "The tunnels with white orbs inside are the ones that fire, and the "
                .. "number of orbs is the order: one, two, three.",
        },

        phases = {
            {
                name = "Apex Predator",
                tag  = "five casts in a random order",
                lines = {
                    "Two Ravage, two Mutilate, one Tempest -- any order, and the same "
                        .. "one can come twice in a row.",
                    "Ravage is the tank frontal. Anyone hit takes +400% from it for 25 "
                        .. "seconds, so the tanks swap before the next one.",
                    "Mutilate is the raid frontal. It splits between soakers and "
                        .. "leaves +500% from the NEXT one for 22 seconds -- which is "
                        .. "the whole reason for two groups.",
                    "Tempest sends tornadoes roaming out of the boss. They hit hard "
                        .. "and they wander, so keep looking.",
                    "Both cones aim at the current tank, so tank near the edge with "
                        .. "the raid behind the boss.",
                },
            },
            {
                name = "Venomous Surge",
                tag  = "the cysts, and where they go",
                lines = {
                    "Two players get a 10-second debuff. When it ends it hits the raid "
                        .. "reduced by distance, and leaves a Vicious Cyst where that "
                        .. "player stood.",
                    "Walking into a cyst knocks the raid back and makes it resistant "
                        .. "to the wind. That is how you survive the intermission.",
                    "So place them on the markers opposite the tunnels that lit up.",
                    "Caustic Claws drops puddles around the boss at the same time. "
                        .. "Dodge out, and move the boss to the next clean slice of "
                        .. "the room.",
                },
            },
            {
                name = "Raging Crosswinds",
                tag  = "find your partner",
                lines = {
                    "Several players get a circle with an arrow. You are about to be "
                        .. "thrown that way.",
                    "Point your arrow at somebody whose arrow points back at you, and "
                        .. "you collide in mid-air and cancel out.",
                    "The circles only have to touch. Do not try to pixel-aim it.",
                    "Miss everyone and you drift, possibly off the platform.",
                    "Do NOT use a knockback immunity. You save yourself and leave your "
                        .. "partner without one.",
                },
            },
            {
                name = "Intermission",
                tag  = "after two full sets",
                lines = {
                    "The boss digs into the middle and takes 30% more damage.",
                    "Everybody PIXEL STACKS in the middle. Being off to one side is "
                        .. "what starts the disasters here.",
                    "Each wind blows you into the cyst opposite it. That bounces you "
                        .. "back toward the boss and makes you wind-resistant, so you "
                        .. "keep hitting him through the amp.",
                    "Three winds, in the order the orbs told you.",
                    "After the third, walk to the leftover cyst and pop it on purpose "
                        .. "rather than letting it expire under somebody.",
                },
            },
        },

        heroicUnknown = true,

        roles = {
            DAMAGER = {
                "Read the tunnel orbs before anything else happens. Everything in the "
                    .. "intermission depends on getting that right.",
                "Line your two-minute cooldowns up with the intermission's 30% amp. It "
                    .. "is a clean, repeating timer.",
                "Know which soak group you are in, and be in it.",
            },
            HEALER = {
                "Constant raid damage all fight, plus a stacking physical debuff on "
                    .. "the tanks. This is the fight that wants the extra healer.",
                "Cysts hurt when they drop and again when they go off.",
                "Tempest leaves poison on anyone it clips -- poison dispels are "
                    .. "excellent here.",
            },
            TANK = {
                "Tank near the edge, boss facing out, raid behind it.",
                "Ravage comes twice per combo and forces a swap between them.",
                "Point each Mutilate at the group whose turn it is.",
            },
        },

        lust = "on pull, or the first intermission for the 30% amp",
    },

    ----------------------------------------------------------
    {
        id      = "twinfangs",
        order   = 6,
        name    = "The Twin Fangs",
        ejID    = 2887,
        encounterID = 3421,
        accent  = { 0.60, 1.00, 0.35 },
        oneLiner = "Everything green is a poison stack. Ten of them kills you.",
        shape   = "1 phase + intermission",
        bring   = "reliable two-target damage",

        rules = {
            "Eternal Venom stacks all fight and at 10 stacks you die. Watch the "
                .. "number, not your health bar.",
            "Ravenous Feast is the only stack removal in the fight, and the soak "
                .. "debuff means you take ONE of its three pops.",
            "Kill both bosses together. Killing one first triggers Uncoiled Rot, and "
                .. "the survivor gains 25% damage every 4 seconds.",
        },

        phases = {
            {
                name = "The two of them",
                tag  = "Vexil and Itras",
                unsure = true,
                lines = {
                    "Vexil is the poison twin, Itras the blood one. They do not share "
                        .. "health.",
                    "Neither can be moved, so the raid spreads loosely wherever you "
                        .. "pulled.",
                    "Somebody has to stay in melee range of each of them, or they "
                        .. "smack the whole raid for it.",
                    "This boss was reworked after the guide these notes come from was "
                        .. "recorded. Expect the shape to hold and the details to have "
                        .. "moved.",
                },
            },
            {
                name = "What gives you stacks",
                tag  = "anything green",
                lines = {
                    "Venomous Emergence: everybody gets a stack, and three serpents "
                        .. "spawn in the middle.",
                    "Those serpents fire Corrosive Spit lines at random players. The "
                        .. "target stands STILL; everybody else steps out of the line.",
                    "Caustic Globules spawn around the room. Soaking one is a stack "
                        .. "for you; leaving one is a stack for the entire raid after "
                        .. "10 seconds.",
                    "The Depths is raid damage with no stacks attached -- but the green "
                        .. "waves that cross the room afterwards do. Dodge those.",
                },
            },
            {
                name = "Ravenous Feast",
                tag  = "the only way stacks come off",
                lines = {
                    "A big red circle explodes three times in quick succession. The "
                        .. "damage splits between soakers, and each pop you stand in "
                        .. "removes a stack.",
                    "Soaking leaves +800% damage from it for 8 seconds, so you take "
                        .. "one pop and get out.",
                    "Three groups of seven or more, one per pop. Or two groups, with "
                        .. "immunities sent in for the last one.",
                    "The stacks you clear come back as a big slime add. Focus it down.",
                },
            },
            {
                name = "The tank mechanics",
                tag  = "and what happens if they are missed",
                lines = {
                    "Caustic Deluge stacks +10% of itself on Vexil's tank for 90 "
                        .. "seconds, so it forces a swap.",
                    "Stonebreaker drops three white swirlies that go off one at a "
                        .. "time. A tank soaks each set, alternating -- +33% from it "
                        .. "per soak.",
                    "A swirly that hits NOBODY is heavy raid damage and a knockback. "
                        .. "That is the one that ruins pulls.",
                },
            },
            {
                name = "Coiling Ichor",
                tag  = "and where to put it",
                lines = {
                    "A red circle on random players: heavy damage, and a slowing "
                        .. "puddle where it expires.",
                    "Walk to the side of the room and drop it there, without clipping "
                        .. "anyone on the way out.",
                },
            },
            {
                name = "The intermission",
                tag  = "after the second Feast",
                lines = {
                    "Both bosses submerge and swap sides. Vexil surfaces in the middle "
                        .. "and casts Wild Flood, a rotating laser.",
                    "The orbs spinning around the boss show which way it will turn.",
                    "Run against the spin, cross the laser once, and the spot you "
                        .. "crossed stays safe -- it does not sweep a full circle.",
                    "Sanguine Storm drops red circles the whole time. Dodge those as "
                        .. "well.",
                    "Then the bosses meet up again and the loop restarts, with the raid "
                        .. "carrying more stacks than last time.",
                },
            },
            {
                name = "The enrage",
                tag  = "third time at 100 energy",
                lines = {
                    "Both bosses move to the middle and cast Caustic Rain and Sanguine "
                        .. "Storm without stopping.",
                    "Every cycle before that is harder than the one before it, because "
                        .. "the raid never clears every stack it gained. That is the "
                        .. "soft enrage, and it is the real timer.",
                },
            },
        },

        heroicUnknown = true,

        roles = {
            DAMAGER = {
                "The three serpents in the middle are the priority. Every second they "
                    .. "live is another line and more stacks on the raid.",
                "Soak the globules near you, but do not hoover up other people's -- "
                    .. "each one is a stack.",
                "Both bosses have to die together, so watch the other target's health "
                    .. "as closely as your own.",
            },
            HEALER = {
                "Watch stack counts, not just health. Somebody on 9 is in more danger "
                    .. "than somebody at half health.",
                "Ravenous Feast is the biggest planned hit and it lands three times.",
                "Every unsoaked Stonebreaker swirly is an unplanned raid hit plus a "
                    .. "knockback.",
            },
            TANK = {
                "Caustic Deluge forces the swap on Vexil. Stonebreaker sets alternate "
                    .. "between the two of you.",
                "Never let a Stonebreaker swirly go unsoaked.",
                "After the intermission, whoever has Vexil owns where Wild Flood "
                    .. "starts. Point it away from where the raid is going.",
            },
        },

        lust = "on pull",
    },

    ----------------------------------------------------------
    {
        id      = "alteredfangs",
        order   = 7,
        name    = "The Coiled Altar",
        ejID    = 2883,
        encounterID = 3429,
        accent  = { 0.90, 0.30, 0.45 },
        -- Zul'jin and the Hex Lord are both corroborated by loot in this
        -- addon's own trinket data: item 270173 "Zul'jin's Guillotine
        -- Technique" -- and Guillotine is a phase-one mechanic below --
        -- and item 270169 "Hex Lord's Dooming Idol".
        --
        -- MALACRASS is the part still resting on a caption, so the flag
        -- sits on the phase that spells it out and nowhere else.
        --
        -- This is also the only fight here without a per-boss guide
        -- behind it -- only the all-boss preview -- so it is the one
        -- most worth re-checking.
        oneLiner = "Zul'jin, then the Hex Lord, then both of them at once.",
        shape   = "3 phases, 2 bosses",

        rules = {
            "Phase one is orbs. Pile them up, and the tank's frontal destroys them -- "
                .. "every orb destroyed stacks a dot on the raid, so take them in "
                .. "batches.",
            "Phase two: if a spirit is chasing you, LOOK AT IT. Staring freezes it so "
                .. "the tank's frontal can destroy it.",
            "Kill Zul'jin in the MIDDLE of the room. He is resurrected exactly where "
                .. "he died.",
        },

        phases = {
            {
                name = "Phase one",
                tag  = "Zul'jin",
                lines = {
                    "He throws green venom orbs out all phase, and every one still "
                        .. "alive when the phase ends explodes at once.",
                    "The tank's frontal destroys them. Each destroyed orb puts a "
                        .. "stacking dot on the raid, so the healers set the pace.",
                    "Run over an orb to pick it up. It sticks to you for a few seconds "
                        .. "and drops where you are.",
                    "So: carry them into a pile and let the tank clear several with "
                        .. "one cone. Mobile ranged do this as much as the off-tank.",
                    "Guillotine is a group soak near the edge. Soak it, then everybody "
                        .. "runs away from the blast.",
                    "Axe Grinder throws spinning axes around the room. Annoying rather "
                        .. "than lethal.",
                    "Clear as many orbs as you can before you push him, and stack for "
                        .. "the explosion when he dies.",
                },
            },
            {
                name = "Phase two  --  Hex Lord Malacrass",
                unsure = true,
                tag  = "red light, green light",
                lines = {
                    "Dread March mind-controls several players, and they walk straight "
                        .. "off the platform. Beat them out of it fast.",
                    "Every player you free spawns two spirits, and each spirit fixates "
                        .. "somebody. They cannot be damaged or crowd controlled.",
                    "A spirit FREEZES while you look straight at it.",
                    "So let them close in, freeze them together, and the tank's "
                        .. "frontal destroys the pile.",
                    "Gloom Bomb drops a circle on you. You, and anyone caught in it, "
                        .. "spawn three small spirits in a triangle -- collect all "
                        .. "three within about 12 seconds or you die.",
                    "The boss shields itself and starts a cast. Break the shield, THEN "
                        .. "kick the cast.",
                    "At 1 HP he stops and the intermission begins.",
                },
            },
            {
                name = "Intermission",
                tag  = "the burn",
                lines = {
                    "Malacrass resurrects Zul'jin and heals him -- but Zul'jin takes "
                        .. "100% increased damage. This is the Bloodlust window.",
                    "Damage here is not wasted: it sets the health Zul'jin starts the "
                        .. "last phase on.",
                    "Spirits drift toward Zul'jin and heal him if they arrive. Stand "
                        .. "in the way and play goalie.",
                    "Stack up for healing cooldowns while you do it.",
                },
            },
            {
                name = "Phase three",
                tag  = "both at once",
                lines = {
                    "Phase one and phase two together: orbs, spirits, and the shield.",
                    "Only Zul'jin has the frontal now, and it has to clear both the "
                        .. "orbs and the frozen spirits.",
                    "So the orb pile goes where the spirits are being frozen. One cone, "
                        .. "both problems.",
                    "On the PTR this was the hardest thing in the raid, with almost no "
                        .. "room to do any of it. Expect coordination -- and expect it "
                        .. "to have been tuned.",
                },
            },
        },

        heroic = {
            "Soul Boiler adds spawn every 40 seconds or so. They cannot be tanked, and "
                .. "their long cast has to be interrupted every time.",
            "But every interrupt teleports the Soul Boiler somewhere new -- so do not "
                .. "spam kicks. Kick it late, ideally where you can cleave it.",
            "A Soul Boiler that reaches 100 energy becomes immune to interrupts. Kill "
                .. "it before that.",
            "Guillotine stacks, so split the raid in half: one half soaks this one, "
                .. "the other half the next.",
            "A spirit that reaches you MIND CONTROLS you instead of just hitting you.",
            "The last phase gets Guillotine and Gloom Bombs on top of everything else, "
                .. "so the raid bounces from one side of the room to the other.",
        },

        roles = {
            DAMAGER = {
                "Phase one: mobile ranged carry orbs into the pile. It is a real job, "
                    .. "not a spare moment.",
                "Phase two: break the Hex Lord's shield fast, then kick the cast. "
                    .. "Anything with bonus damage to absorbs belongs here.",
                "Phase two: beat the mind-controlled players out of it before they "
                    .. "walk off the edge.",
                "Intermission: everything into Zul'jin, and body-block the spirits.",
            },
            HEALER = {
                "The dot from destroying orbs is the pace-setter for phase one. Tell "
                    .. "them when to take the next batch.",
                "The orb explosion when Zul'jin dies is a scripted raid hit. Have a "
                    .. "cooldown ready.",
                "Gloom Bomb kills people outright if they do not collect their "
                    .. "spirits. There is no healing through it -- call it out.",
                "The intermission is stack-and-chain-cooldowns.",
            },
            TANK = {
                "The tank not currently tanking does the orb-moving.",
                "Aim the cone at orbs in phase one, and at frozen spirits in phase "
                    .. "two.",
                "In phase three it is one cone for both, so tank where the pile and "
                    .. "the spirits meet.",
                "Kill Zul'jin in the centre so his resurrection point is central.",
            },
        },

        lust = "the intermission, while Zul'jin takes double damage",
    },
}

------------------------------------------------------------
-- Not in here on purpose
------------------------------------------------------------
-- The name is no longer a guess -- it is the raid's namesake. This
-- addon's own season string is "Curse of Ula'tek" (Core\Data.lua) and
-- item 270175 is the "Voracious Heart of Ula'tek". Only the FIGHT is
-- missing, and that gap is now shown in the boss list rather than
-- described in a comment nobody reads.
G.missing = {
    {
        name = "Ula'tek",
        ejID = 2895,
        encounterID = 3492,
        why = "Blizzard never tested the last boss on the PTR, so no guide covers "
            .. "him -- ours included. Nothing written here would be better than a "
            .. "guess, and a guessed raid mechanic is worse than no entry.",
    },
}

------------------------------------------------------------
-- Lookups
------------------------------------------------------------
local byId
function G:Get(id)
    if not byId then
        byId = {}
        for _, b in ipairs(self.bosses) do byId[b.id] = b end
    end
    return byId[id]
end

--- Bosses in pull order.
function G:Ordered()
    local out = {}
    for i, b in ipairs(self.bosses) do out[i] = b end
    table.sort(out, function(a, b) return a.order < b.order end)
    return out
end

--- The role lines for a boss, for a role key, always including the
--- shared rules.
---
--- Falls back to DAMAGER rather than to nothing: an unassigned player
--- reading the guide out of a group is far more likely to be a DPS than
--- to want an empty panel, and "no role selected" is not a state worth
--- rendering a blank page for.
function G:RoleLines(boss, role)
    if not boss or not boss.roles then return {} end
    return boss.roles[role] or boss.roles.DAMAGER or {}
end
