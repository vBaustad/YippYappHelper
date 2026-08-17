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
-- 1. PRIMARY, and the one that overrules the rest: Automatic Jack's
--    "Venomous Abyss Raid Boss Guide" (youtu.be/ktdXrfmJYZg), a full
--    PTR walkthrough of every boss that was tested. Supplied 2026-08-17.
--
--    This replaced an earlier pass built from a much worse transcript,
--    and it corrected a lot -- some of it embarrassing. Kept as a list
--    rather than quietly fixed, because every one of these was written
--    down confidently and was wrong:
--      * the Sentinels are the BLOOD and the BREATH of Ula'tek. They
--        were recorded here as a "green golem" and a "red golem".
--      * Vitriolic Stasis IS the intermission -- the venom-orb maths and
--        the healing of the weaker boss are one event, not two -- and
--        the orbs are a single count summing to FOUR, not two colours.
--      * Trader Gebbo should die LAST. This file said first.
--      * Frostfire Volley's Elemental Explosion is caused BY clearing,
--        so the clears are staggered. This file had it as a punishment
--        for failing to clear, which is close to backwards.
--      * Mutilate is a frontal cone aimed AT the raid, not a circle.
--      * Ravenous Feast removes ONE stack per cast, not one per soak.
--      * the kill-them-together enrage belongs to the Coiled Altar.
--      * "Zul'jin is resurrected where he died" appears in no source
--        that survived, and is gone.
--
-- 2. NorthernSkyRaidTools' saved variables, read by Tools/extract_nsrt.py.
--    The structural half: which phase an ability belongs to, and
--    seconds-from-pull timers. It independently corroborates the guide
--    above -- the Sentinels' events are named BloodSoak / PoisonAdd (not
--    green and red), their intermission is labelled "Number Game", and
--    Sszorak and the Twin Fangs are single-phase fights with a Damage
--    Amp / Watch Side window rather than true intermissions.
--
-- 3. Names come from the client, not from any video -- see below.
--
-- All of the above is PTR footage. Tuning numbers may have moved, and
-- the Twin Fangs was reworked after the footage was taken -- flagged on
-- that boss rather than left as a general disclaimer nobody reads.
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

------------------------------------------------------------
-- The instances this page covers.
--
-- More than one now, because The Tidebound Grotto is a LAIR -- an
-- instanced world boss that fills the raid row of the Great Vault -- and
-- a player who has to go somewhere else to read about the only other
-- thing that drops raid gear this patch is being sent on an errand for
-- no reason.
--
-- Bosses carry an `instance` key. Anything without one belongs to the
-- Venomous Abyss, so the seven that were written before this existed did
-- not all have to be touched to add an eighth.
------------------------------------------------------------
G.instances = {
    { key = "va", order = 1, name = "The Venomous Abyss",  kind = "Raid" },
    { key = "tg", order = 2, name = "The Tidebound Grotto", kind = "Lair" },
}

function G:InstanceOf(boss)
    local key = boss and boss.instance or "va"
    for _, inst in ipairs(self.instances) do
        if inst.key == key then return inst end
    end
    return self.instances[1]
end

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
            "Never stand in the well in the middle. It hurts enormously AND feeds "
                .. "her energy, which is the one bar that ends the pull.",
            "Kill the Restless Amani before they reach the well. Breaking their "
                .. "shield stops them fixating on it and lets a tank pick them up.",
            "Essence Rend leaves a PERMANENT void zone where it ends. Get knocked to "
                .. "the edge and drop it there -- never in the middle.",
        },

        phases = {
            {
                name = "Phase one",
                tag  = "100% to 50%",
                lines = {
                    "Tank her at the entrance, facing away. The raid stands behind "
                        .. "her, and nobody stands in the well.",
                    "Soul Coil Ignition opens the fight: a big raid hit that also "
                        .. "spawns void zones which knock you back. Healing cooldown.",
                    "Essence Rend puts a ghost on several players. It drags you for a "
                        .. "moment, then attaches and knocks you back along the line it "
                        .. "came from.",
                    "Ride that knockback to the EDGE. Then dispel -- personals or mass "
                        .. "dispel -- and the latent cultist void zone lands out there "
                        .. "instead of in the raid.",
                    "Restless Amani spawn at the edges and walk at the well. Grip and "
                        .. "knock them into PILES, because where they die matters later.",
                    "Break their shields as fast as you can. A shieldless Amani stops "
                        .. "fixating on the well and can simply be tanked.",
                    "Possession Barrage fires souls out at the tank. They hurt more the "
                        .. "closer you are to where they land, and nobody but the tank "
                        .. "should meet them.",
                    "Hollowing Strikes cuts the tank's healing and absorbs by 5% a "
                        .. "stack. Swap somewhere around 8 to 10.",
                },
            },
            {
                name = "Intermission",
                tag  = "at 50% -- burn the piles",
                lines = {
                    "She hides in the Soulcoil Well and turns immune. Jawae appears and "
                        .. "starts producing Echoes of herself around the room.",
                    "Both Echoes are up at once. Kill them and the intermission ends.",
                    "Soul Transfer is a 15-second cast at unlimited range: Jawae pours "
                        .. "her essence into an Echo, and the surge at the end hits "
                        .. "anyone caught in the blast. You cannot stop it, so just be "
                        .. "out of it.",
                    "Reposition the raid ON TOP of the Amani piles you made in phase "
                        .. "one. That is the whole job here.",
                    "Hungering Pyre splits fire damage between everyone soaking it, so "
                        .. "melee stack for it -- on a pile of bodies.",
                    "Everybody who does NOT soak gets Slithering Flame instead. Ranged "
                        .. "spread out and walk theirs over the other piles.",
                    "Either flame touching a corpse cremates it. You get two rounds of "
                        .. "Pyre and two Echoes, and that is all the cleanup you ever "
                        .. "get.",
                },
            },
            {
                name = "Phase two",
                tag  = "50% to 0%, and the clock is her energy",
                lines = {
                    "Uncoiling stacks a permanent raid-wide dot that runs until she "
                        .. "dies. The damage only goes up from here.",
                    "Invoke wakes the latent cultist void zones you dropped at the "
                        .. "edges and sends them moving across the room.",
                    "Only SOME of them empower on each cast, so keep watching -- do "
                        .. "not assume the whole floor is moving.",
                    "Everything from phase one keeps happening, adds included, and "
                        .. "there is no way left to burn a corpse.",
                    "If she caps her energy she gains 500% damage, moves 150% faster "
                        .. "and cannot be taunted. Hero here and race it.",
                },
            },
        },

        heroic = {
            "Corpses and Raised Amani were both seen on a live pull, so treat the "
                .. "reawakening as something that happens to you and not as a heroic "
                .. "extra -- one source called it heroic-only and it is the weaker "
                .. "claim of the two.",
            "Either way heroic is where it bites, because there is more of everything "
                .. "and less room to park a pile out of the way.",
        },

        roles = {
            DAMAGER = {
                "Break the Amani shields first. A held or tanked add is one that is "
                    .. "not walking at the well.",
                "Stuns, slows, roots and grips all work -- use them to build piles, "
                    .. "not just to stop one add.",
                "In the intermission, cleave the Echo and whatever is standing on the "
                    .. "corpses together.",
            },
            HEALER = {
                "Essence Rend is a dispel, but the void zone lands where that player "
                    .. "is standing. Let the knockback finish first.",
                "Mass dispel works beautifully here as long as the group is at the "
                    .. "edge when you do it.",
                "Phase two adds a permanent stacking dot on top of everything else. "
                    .. "Save a cooldown for it.",
            },
            TANK = {
                "Possession Barrage: stand well out and pointed away. The souls hurt "
                    .. "by proximity to where they land.",
                "Hollowing Strikes is 5% less healing per stack -- swap at 8 to 10.",
                "Hungering Pyre lands on you in the intermission. Stand on the biggest "
                    .. "pile of bodies for it.",
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
        oneLiner = "Two bosses, one health bar between them -- and then the raid does maths.",
        shape   = "2 sides, swapped at each intermission",
        bring   = "poison and magic dispels",

        rules = {
            "Two bosses: the Blood of Ula'tek and the Breath of Ula'tek. Half the raid "
                .. "on each, and they must die together.",
            "Each one stacks its own 40-second dot on anyone within 40 yards. Standing "
                .. "between them to hit both gives you both.",
            "At maximum energy they go into Vitriolic Stasis. Your venom orbs plus one "
                .. "other player's must add up to exactly FOUR.",
        },

        phases = {
            {
                name = "The Blood side",
                tag  = "soak, then get to the edge",
                lines = {
                    "Blood Venom Injection is the tank hit and it stacks. You swap "
                        .. "bosses at maximum energy, so expect three or four.",
                    "Soak the Toxic Droplet puddles on your side as soon as they land.",
                    "Unstable Miasma drops a pool of blood and the whole side has to "
                        .. "soak it together.",
                    "Then get to the EDGE and stack with your allies, because what you "
                        .. "just soaked comes back as puddles under all of you.",
                    "Blighted Blood is a magic debuff on random players. Healers "
                        .. "dispel it promptly.",
                },
            },
            {
                name = "The Breath side",
                tag  = "the droplets travel",
                lines = {
                    "This side sends Toxic Droplets out across the room, and tanks "
                        .. "should soak as many as they can reach.",
                    "DPS and healers help, with a personal up -- soaking these quickly "
                        .. "is the difference between a chore and a wipe.",
                    "Venom Coagulation spawns an add that radiates damage the whole "
                        .. "time it lives. It arrives about once a minute and can hold "
                        .. "on for 20 to 30 seconds.",
                    "That add is the highest damage in the fight. Priority target, "
                        .. "every time, and healers cycle a cooldown through it.",
                    "Empowering Slam is this side's tank hit: heavy physical, and it "
                        .. "ramps his follow-up attacks.",
                },
            },
            {
                name = "Intermission",
                tag  = "Vitriolic Stasis -- make four",
                lines = {
                    "Both bosses take 99% reduced damage AND heal the weaker of the "
                        .. "two, so a side that raced ahead just gave that damage back.",
                    "Damage is worthless here. Getting everyone clear quickly is the "
                        .. "only thing that shortens it.",
                    "Look at how many venom orbs are circling your character.",
                    "Find one player whose count plus yours makes exactly four. Three "
                        .. "looks for one, two looks for two, one looks for three.",
                    "You get 30 seconds. That is a lot of time -- look around, walk, "
                        .. "and do not panic.",
                    "Fail a combine and Cultivated Burst hits you hard and leaves a dot "
                        .. "running for the next minute.",
                    "When it ends the tanks swap bosses and everybody returns to their "
                        .. "original side.",
                },
            },
        },

        heroic = {
            "After soaking Unstable Miasma you keep Clinging Murk. When it fades it "
                .. "drops blood pools, which is why that soak happens at the edge with "
                .. "the side stacked.",
            "Toxic Droplets from the Blood side travel back to the Breath of Ula'tek "
                .. "and crash into it. Keep a clear lane through the middle so no "
                .. "player intercepts one.",
        },

        roles = {
            DAMAGER = {
                "Venom Coagulation first, every time, no exceptions.",
                "Soak the droplets on your side, and keep out of the lane the far "
                    .. "side's droplets travel down.",
                "Watch your side's health against the other -- Vitriolic Stasis heals "
                    .. "the weaker boss, so racing is wasted damage.",
            },
            HEALER = {
                "Blighted Blood is a magic dispel and it goes out constantly.",
                "Unstable Miasma is a whole-side soak. If your side is late, the "
                    .. "target dies.",
                "Both bosses' dots sit on everyone in range for 40 seconds and only "
                    .. "fall off after you swap sides.",
            },
            TANK = {
                "Keep the two bosses apart. Half the raid goes with each of you.",
                "Swap bosses at maximum energy -- the Blood side's injection is "
                    .. "stacking on you until you do.",
                "On the Breath side, soak as many travelling droplets as you can "
                    .. "reach. That is genuinely your job.",
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
            "Never let all three tortollans stack together -- they take 99% reduced "
                .. "damage. Two in cleave range is fine.",
            "Break Gebbo's crates. One hides the rotting fish, and a crate nobody "
                .. "soaks explodes for heavy damage.",
            "Feed the fish to a tortollan to break Mor'zai's control. You can only "
                .. "feed each one once, so you get three.",
        },

        phases = {
            {
                name = "Mor'zai",
                tag  = "the one you never fight",
                unsure = true,
                lines = {
                    "He cannot be touched. The three tortollans are mind-controlled by "
                        .. "him, and breaking that control is the whole loop.",
                    "Gebbo drops crates around the room. Walk over one to break it -- "
                        .. "you pick up a small bleed -- and eventually one uncovers the "
                        .. "rotting fish.",
                    "A crate nobody soaks explodes for heavy raid damage, so crate duty "
                        .. "is a real assignment.",
                    "Feed the fish to a tortollan and it breaks free and turns friendly "
                        .. "for a moment.",
                    "Then Mor'zai seizes it back. Fishy Feedback radiates damage for "
                        .. "about 12 seconds, and that tortollan comes out EMPOWERED.",
                    "One feed each, so you will empower all three before this is over. "
                        .. "The order is your choice.",
                },
            },
            {
                name = "Scrollsage Iku",
                tag  = "the caster",
                lines = {
                    "Blink Nova marks one player, teleports to them and hits the raid "
                        .. "reduced by distance. If it is you, run out; if it is not, "
                        .. "get away from them.",
                    "Icebound Flames is heavy damage and a slow, and it CAN be "
                        .. "interrupted. Set a kick order and keep it covered.",
                    "Shredding Shards fires a volley of shards into her tank -- around "
                        .. "seven of them -- each stacking +50% damage taken from the "
                        .. "next.",
                    "Tanks swap after a volley lands. Holding for a second volley means "
                        .. "fourteen stacks and an unhealable dot.",
                },
            },
            {
                name = "First Mate Nama",
                tag  = "the shells",
                lines = {
                    "Shell Spin hurls three spinning shells across the room, and being "
                        .. "hit STUNS you as well as hurting.",
                    "That is worse than it sounds, because a stun can hold you under a "
                        .. "crate that is about to land on your head.",
                    "Her melee adds 4% physical damage taken to her tank with every "
                        .. "hit.",
                },
            },
            {
                name = "Trader Gebbo",
                tag  = "the one walking in circles",
                lines = {
                    "Not tanked, and not tankable. He wanders the room dropping crates "
                        .. "near players.",
                    "Walking over a crate breaks it and gives you a small bleed. One of "
                        .. "them is hiding the fish.",
                    "Put two or three players on crate duty, ideally ones who can shed "
                        .. "a bleed or tank one.",
                },
            },
            {
                name = "Iku empowered",
                tag  = "Frostfire Volley -- the scary one",
                lines = {
                    "Fire lands on some players and frost on others, each dropping a "
                        .. "patch of its element and a dot that runs a full minute.",
                    "The frost one also slows you. The fire one just burns.",
                    "You clear your dot by walking into the OPPOSITE patch -- fire "
                        .. "walks into frost, frost walks into fire.",
                    "But clearing it TRIGGERS an Elemental Explosion. That is what "
                        .. "wiped the PTR raids, over and over.",
                    "So do not all clear at once. Stagger them, and have raid cooldowns "
                        .. "running while you do.",
                    "This was the highest damage in the whole raid on test. Personals "
                        .. "as well as raid cooldowns.",
                },
            },
            {
                name = "Nama empowered",
                tag  = "Mighty Thud",
                lines = {
                    "Three players get marked and she leaps to each of them.",
                    "Huge physical damage at the landing, split with anyone standing "
                        .. "within about six yards. So it needs bodies in it.",
                    "Each landing knocks players back. Watch where you are standing, "
                        .. "because being knocked off the platform ends your evening.",
                },
            },
            {
                name = "Gebbo empowered",
                tag  = "mushrooms and a bomb",
                lines = {
                    "Mushroom Toss comes first, scattering bouncy mushrooms around the "
                        .. "room.",
                    "Then a bomb lands on one player and sends out a wave of fire.",
                    "Get onto a mushroom to bounce over the wave. A blink, leap or "
                        .. "teleport does the same job.",
                },
            },
            {
                name = "Feed order, and the kill",
                tag  = "decide this before you pull",
                lines = {
                    "Feeding Gebbo EARLY is the comfortable opener -- mushrooms and a "
                        .. "bomb is the gentlest of the three ultimates to carry for "
                        .. "the rest of the fight.",
                    "Iku's Frostfire Volley is the one to schedule. Try to take it "
                        .. "where your healing cooldowns will be back up.",
                    "All three must die at close to the same time, because each has an "
                        .. "ultimate that can wipe you if it is left alone.",
                    "If one has to die LAST, make it Gebbo. His is a shovel: single "
                        .. "target into the tank plus a knockback.",
                    "The other two are far worse alone. Iku throws a cataclysmic bomb "
                        .. "that wipes the raid, and Nama gains 100% damage every "
                        .. "second.",
                },
            },
        },

        heroic = {
            "All three tortollans stacked together take 99% reduced damage, so spread "
                .. "them -- two in cleave range is fine, three is not.",
        },

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
            "At maximum energy Imbibe drinks from the TWO NEAREST fountains. Where the "
                .. "raid stands is what picks them, so move as a group.",
            "Every add walks for the venomous cavity in the middle. If one reaches it, "
                .. "it explodes and wipes you.",
            "Each empowerment lasts two minutes. To drop a stack you have to empower "
                .. "the OTHER two fountains twice in a row.",
        },

        phases = {
            {
                name = "The three fountains",
                tag  = "and the cavity in the middle",
                lines = {
                    "Each Imbibe hits the raid hard, once per fountain he drinks from.",
                    "Every stack a fountain holds increases the damage of future "
                        .. "Imbibes AND the health of the adds that fountain spawns.",
                    "So the useful trick is deliberate: empower the same two fountains "
                        .. "back to back to let the third one's stack fall off.",
                    "Most raids do that to the blood fountain, because blood adds "
                        .. "cannot be crowd controlled and extra health on those is the "
                        .. "worst kind.",
                },
            },
            {
                name = "The adds",
                tag  = "what each fountain sends at the cavity",
                lines = {
                    "Clotting Venom carries Sanguine Fortitude and cannot be crowd "
                        .. "controlled at all. It splits when killed, so keep killing "
                        .. "until the floor is clear.",
                    "Shrouded Venom can be held, and drops a shadow void zone where it "
                        .. "dies. Kill them somewhere you do not need to stand.",
                    "Burning Venom radiates damage the whole time it lives, and casts "
                        .. "Caustic Surge when it dies -- a short dot that STACKS with "
                        .. "other adds dying near it.",
                    "So do not kill two Burning Venoms together. Hold one, or line the "
                        .. "kills up so the first dot falls off before the second lands.",
                    "Everything except the clotting venoms hurts the raid on death. "
                        .. "Those death windows are where the healing cooldowns go.",
                },
            },
            {
                name = "The infections",
                tag  = "which ones you get depends on the fountains",
                lines = {
                    "Siphoning Infection puts a big red circle on a player, and they "
                        .. "heal themselves by LEECHING off everyone else.",
                    "If it is you, run into melee and stand in the group. If it is not "
                        .. "you, stay where they can reach you.",
                    "Stygian Infection is a large healing absorb plus a dot on one "
                        .. "player. Top them off fast, and pop a defensive if it is "
                        .. "you.",
                    "Exploding Infection marks a player as a bomb. It was supposed to "
                        .. "be dispellable and was not on the PTR, so treat it as "
                        .. "something to spread out for.",
                },
            },
            {
                name = "Everything else",
                tag  = "the casts that never stop",
                lines = {
                    "Plague Froth marks several players and sends venomous waves out "
                        .. "from where they stand. Walk out of the group first, and "
                        .. "never point one through melee.",
                    "Dripping Fangs is the tank hit: very heavy physical, a nature dot "
                        .. "for 32 seconds, and +100% physical damage taken. Swap every "
                        .. "cast.",
                    "Imbibe itself is a large predictable raid hit and a good place for "
                        .. "a personal or a raid damage reduction.",
                },
            },
        },

        heroic = {
            "Malignant Catalyst is the orb of venom above the cavity. It explodes and "
                .. "launches Catalytic Bile, which must land on at least one player -- "
                .. "if it hits nobody the whole raid eats it.",
            "This did not reliably show on the PTR, so watch for a soak appearing here "
                .. "on live.",
        },

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
            "Two frontal cones, and they go in opposite directions. The poisonous one "
                .. "(Mutilate) is aimed AT the raid; the physical one (Ravage) is "
                .. "aimed away.",
            "Split into two halves before you pull. Mutilate must not hit the same "
                .. "half twice in a row.",
            "The tunnels on the rim show wind orbs. The number of orbs is the order "
                .. "they blow -- one, then two, then three.",
        },

        phases = {
            {
                name = "The tank combo",
                tag  = "two cones, opposite jobs",
                lines = {
                    "Ravage is the tank buster and it is a cone. Point it AWAY from "
                        .. "everybody.",
                    "Mutilate is also a cone, but it has to be pointed INTO the raid, "
                        .. "because it splits between everyone it hits.",
                    "Easy way to hold it: the poisonous-looking one goes at the raid, "
                        .. "the physical-looking one goes away from it.",
                    "On heroic, being hit by Mutilate increases your damage from the "
                        .. "next one -- so the tank alternates which half of the raid "
                        .. "each cone lands on.",
                    "Tanks swap afterwards. Note that a taunt can change the target "
                        .. "mid-cast, which is occasionally exactly what you want.",
                    "Tempest sends poisonous tornadoes wandering out of the boss, and "
                        .. "anyone clipped picks up a poison dot. Cleansing totems earn "
                        .. "their spot here.",
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
                name = "Howling Maelstrom",
                tag  = "after two full sets",
                lines = {
                    "The boss digs in and takes 30% more damage. This is the burn "
                        .. "window and it repeats on a clean timer.",
                    "Everybody stacks in the middle. Being off to one side is what "
                        .. "starts the disasters here.",
                    "Each wind blows the raid from the tunnel it came from toward the "
                        .. "opposite side -- an orb at 12 o'clock blows you south.",
                    "That is why the cyst goes at 6 o'clock: you get blown into it, it "
                        .. "kills the knockback and leaves you wind-resistant, and you "
                        .. "keep hitting the boss through the amp.",
                    "Three winds, in the order the orbs told you.",
                },
            },
        },

        heroic = {
            "Mutilate leaves increased damage from the next Mutilate, which is the "
                .. "entire reason the raid splits in half and the tank alternates.",
        },

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
            "Eternal Venom stacks all fight. Eleven stacks stuns you on normal; ten "
                .. "KILLS you on heroic. Watch the number, not your health bar.",
            "Every player soaks the acid globules. Any left unsoaked put a stack on "
                .. "the ENTIRE raid instead of on one person.",
            "Ravenous Feast removes exactly ONE stack per cast, no matter how many of "
                .. "its three pops you stand in.",
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
                name = "Caustic Deluge",
                tag  = "the opener, and where the stacks come from",
                lines = {
                    "It lands on one tank, stacking nature damage on them, and ejects "
                        .. "acid globules all over the room.",
                    "EVERY player soaks a globule. One left on the floor puts a stack "
                        .. "of Eternal Venom on the whole raid instead.",
                    "That is the arithmetic of the fight: soaked globules cost one "
                        .. "person a stack, ignored ones cost twenty.",
                    "Further waves of adds arrive through the fight and add more "
                        .. "Eternal Venom, plus frontal lines you point away from the "
                        .. "raid.",
                },
            },
            {
                name = "Stonebreaker",
                tag  = "and why the tanks cannot walk away",
                lines = {
                    "Three physical circles land and the tanks soak them -- one tank "
                        .. "takes two, the other takes the third.",
                    "The catch is that both tanks must stay in range of the boss they "
                        .. "are holding.",
                    "Step out of range and you eat Congealed Gore or Concentrated "
                        .. "Spittle for very heavy damage.",
                    "So the soaks have to be taken without abandoning your boss, which "
                        .. "is the whole puzzle.",
                },
            },
            {
                name = "Ravenous Feast",
                tag  = "the only way stacks come off",
                lines = {
                    "It lands on a tank's position and strikes three times, splitting "
                        .. "the damage between everyone soaking.",
                    "You only ever remove ONE stack of Eternal Venom per cast. Standing "
                        .. "in all three pops does not remove three.",
                    "On heroic, soaking more than one pop gives you 800% increased "
                        .. "damage from it and you will simply die.",
                    "So split into three groups, one per pop. On normal everyone can "
                        .. "soak, but it is still one stack.",
                },
            },
            {
                name = "Coiling Ichor",
                tag  = "the deadliest thing for non-tanks",
                lines = {
                    "It goes out on several players and ramps up over about 12 seconds "
                        .. "as the pool of blood shrinks onto you.",
                    "When it expires it deals its maximum damage and leaves a Congealed "
                        .. "Gore puddle behind.",
                    "Take it to the edge of the room and use a real defensive. This is "
                        .. "where DPS and healers die.",
                },
            },
            {
                name = "The intermission",
                tag  = "about two and a half minutes in",
                lines = {
                    "Both bosses submerge and move to another corner of the triangular "
                        .. "room. One surfaces in the middle and channels Vile Flood, a "
                        .. "rotating beam.",
                    "The orbs spinning around it tell you which way the beam will turn.",
                    "If it is going to sweep right, stand just to the LEFT of its head. "
                        .. "The beam then starts on your side and travels away from you.",
                    "Then follow it around toward where the next boss is waiting.",
                    "Grips and movement speed are how you rescue anyone who read the "
                        .. "spin wrong.",
                },
            },
        },

        heroic = {
            "Ten stacks of Eternal Venom kills you outright. On normal eleven stacks "
                .. "only stuns.",
            "Soaking more than one pop of a Ravenous Feast gives you 800% increased "
                .. "damage from it, so three separate soak groups is mandatory rather "
                .. "than tidy.",
        },

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
            "Phase one is orbs. Carry them in front of Zul'jin so his Sever frontal "
                .. "destroys them -- but each one destroyed stacks Venom Rupture on "
                .. "the raid, so take two or three at a time on heroic.",
            "Do NOT push Zul'jin while a lot of orbs are on the floor. They all burst "
                .. "at once when he dies.",
            "In the last phase, both bosses must die together or the survivor enrages "
                .. "for 100% more damage.",
        },

        phases = {
            {
                name = "Phase one",
                tag  = "Zul'jin",
                lines = {
                    "Fangs of the Crucible fills half the room with venom and scatters "
                        .. "acid orbs that radiate damage until they are destroyed.",
                    "Run over an orb to pick it up. It sticks to you until the debuff "
                        .. "expires, then drops where you are standing.",
                    "So mobile ranged carry them in front of the boss, and the tank's "
                        .. "Sever destroys the pile. An off-tank not currently tanking "
                        .. "is ideal for this.",
                    "Every orb destroyed stacks Venom Rupture on the raid. On normal "
                        .. "you can grab everything; on heroic, two or three per Sever.",
                    "Guillotine throws an axe at a player. Half the raid soaks it on "
                        .. "heroic, and it leaves a huge void zone -- a warlock gateway "
                        .. "is the clean way out.",
                    "Loose axes fly around the room all phase. They ignore armour, so "
                        .. "getting clipped hurts far more than it looks like it should.",
                    "Time the kill. Another wave of orbs comes about every 80 to 90 "
                        .. "seconds, and killing him on a full floor bursts all of them "
                        .. "at once.",
                },
            },
            {
                name = "Phase two  --  Hex Lord Malacrass",
                unsure = true,
                tag  = "positioning is the whole fight",
                lines = {
                    "Dread March mind-controls players and walks them off the edge of "
                        .. "the platform. Damage breaks them out.",
                    "So mark a spot nearest an edge and stand there, and the "
                        .. "controlled players walk somewhere your DPS can reach them "
                        .. "instantly.",
                    "Manifestations of Dread fixate players and cannot be damaged. "
                        .. "Look AWAY and they chase you; stare straight at one and it "
                        .. "freezes.",
                    "So walk them to a spot, freeze them together, and the tank's Soul "
                        .. "Sever destroys the pile.",
                    "Put that spot PERPENDICULAR to the Dread March spot. Freeing "
                        .. "someone into a frontal is a very silly way to lose a player.",
                    "Gloom Bomb marks players with a void zone to take out of the raid. "
                        .. "A good moment for a personal.",
                    "Eternal Nightfall shields him and starts pulsing AoE and dropping "
                        .. "more void zones. Pool damage for it and watch your feet.",
                },
            },
            {
                name = "Intermission",
                tag  = "the soul bind -- 30 seconds",
                lines = {
                    "Malacrass dies, binds with Zul'jin and starts healing him -- but "
                        .. "Zul'jin takes 100% increased damage while it happens.",
                    "This is the Bloodlust window, and it runs 30 seconds, so you get "
                        .. "another 10 seconds of Hero after it ends.",
                    "Spirits converge on Zul'jin from all around the room and heal him "
                        .. "if they arrive. Stand in the way.",
                    "Body-blocking them pulses damage onto the group, so stack up and "
                        .. "use a raid cooldown -- and hold one back, because the next "
                        .. "phase is worse.",
                },
            },
            {
                name = "Phase three",
                tag  = "both at once",
                lines = {
                    "Defilement pulses AoE, stacks a healing absorb on the raid, and "
                        .. "brings back the acid orbs from phase one.",
                    "So it is phase one and phase two together: orbs to carry, ghosts "
                        .. "to freeze, and Dread March on top.",
                    "Put the orbs and the ghosts in the SAME place and the Dread March "
                        .. "spot somewhere else. One frontal, both problems, nobody "
                        .. "freed into it.",
                    "Blighted Sever takes a while to come round, so you can hold your "
                        .. "orbs and wait for the shadow puddles to recede before you "
                        .. "commit.",
                    "Anyone not fetching orbs stays stacked. Anyone who is fetching "
                        .. "needs a personal or an external, because they are out of "
                        .. "healer range.",
                    "About 90 seconds in, Defilement of the Crucible fires again for a "
                        .. "fresh wave of orbs and a lot of raid damage. Empty the bag.",
                },
            },
        },

        heroic = {
            "Every orb destroyed by Sever stacks Venom Rupture higher, so two or three "
                .. "per cast rather than the whole floor.",
            "If Zul'jin dies with a lot of orbs out, they instantly burst for all their "
                .. "damage at once. If he is low as Fangs of the Crucible goes off, "
                .. "stop damage, clear a round with one Sever, and then kill him.",
            "Guillotine needs half the raid to soak it.",
            "Soul Coiler adds cast Wail of Terror, a 5-second fear. DPS cover those "
                .. "interrupts.",
        },

        roles = {
            DAMAGER = {
                "Phase one: mobile ranged carry orbs into the pile. It is a real job, "
                    .. "not a spare moment.",
                "Phase two: break the mind-controlled players out fast, before they "
                    .. "reach the edge.",
                "Phase two: pool damage for the Eternal Nightfall shield, and cover "
                    .. "the Wail of Terror interrupts on heroic.",
                "Phase three: swap between the two bosses so they die together. One "
                    .. "dying early enrages the other for 100% more damage.",
            },
            HEALER = {
                "Venom Rupture from destroyed orbs is the pace-setter for phase one. "
                    .. "Tell them when the next batch is affordable.",
                "The orb burst when Zul'jin dies is a scripted raid hit -- and entirely "
                    .. "avoidable by clearing first.",
                "Venom Fang leaves poison on several players at once. Cleansing totem "
                    .. "if you have one.",
                "The intermission is stack-and-chain-cooldowns, and phase three needs "
                    .. "you to have saved one.",
            },
            TANK = {
                "The tank not currently tanking does the orb-moving.",
                "Aim Sever at the orb pile in phase one, and Soul Sever at the frozen "
                    .. "ghosts in phase two.",
                "In phase three it is one frontal for both, so tank where the pile and "
                    .. "the ghosts meet -- and away from where Dread March lands.",
                "Twin Fang Toxin stacks extra nature damage onto every melee you take. "
                    .. "Factor it into your swaps.",
            },
        },

        lust = "the intermission, while Zul'jin takes double damage",
    },

    ----------------------------------------------------------
    -- The Tidebound Grotto's one boss.
    --
    -- Same discipline as the raid: mechanics from the walkthrough, name
    -- from the client. Three sources agree on the spelling and none of
    -- them is a video -- Plumber's EncounterData (journal 2849),
    -- RaiderIO's RAID_BOSS_TG_1, and this addon's own ProgressionData.
    -- The captions render her "Nimissa Waveller", which is why the
    -- client wins.
    --
    -- No combat-log encounterID recorded, because nothing on this
    -- machine states one and a guessed ID is a number that is silently
    -- wrong. The trainer has no scenario for her yet either -- the guide
    -- comes first, the way it did for the raid.
    --
    -- A Lair scales World -> Flexible Mythic. The page has Normal and
    -- Heroic, so the heroic block carries what the source flags as
    -- heroic and the mythic differences are called out inline where they
    -- change what you DO, rather than pretending a third tab exists.
    ----------------------------------------------------------
    {
        id       = "nymrissa",
        instance = "tg",
        order    = 1,
        name     = "Nymrissa Wavecaller",
        ejID     = 2849,
        accent   = { 0.45, 0.80, 1.00 },
        oneLiner = "Soak every frost orb. One left to shatter ends the pull.",
        shape    = "1 phase, on a loop",
        bring    = "crowd control, and a way to reach the murlocs",

        rules = {
            "Soak every frost orb Frost Barrage leaves. An orb nobody touches "
                .. "shatters for massive raid damage and usually ends the pull.",
            "Kill the murlocs before they finish turning into berserkers at the "
                .. "bubble. They can be stunned, slowed and gripped -- but not mind "
                .. "controlled.",
            "When the whirlpools converge, be standing on the safe stretch of "
                .. "shoreline. Getting knocked into the water means sharks and a "
                .. "stacking bleed.",
        },

        phases = {
            {
                name = "The tank hit",
                tag  = "Ice Blade Flurry",
                lines = {
                    "Six slashes over a six-second channel, and each one raises her "
                        .. "damage by 45%.",
                    "That ramp is the whole tank mechanic -- the sixth slash lands on "
                        .. "a tank taking far more than the first.",
                    "On mythic this becomes Water Jet instead, and it is a TOOL: it is "
                        .. "how you clear the frozen patches Frost Barrage leaves on the "
                        .. "floor.",
                },
            },
            {
                name = "Frost Barrage",
                tag  = "the orbs, and the whole fight",
                lines = {
                    "It targets several players, chills them and slows them, and "
                        .. "scatters frost orbs across the floor.",
                    "Every orb has to be soaked. Run them over.",
                    "An orb left alone shatters for enormous raid-wide damage, and "
                        .. "that is the thing that wipes you.",
                    "On heroic the orbs stack damage on whoever soaks them, so spread "
                        .. "the job around rather than sending the same player twice.",
                    "On mythic they hit the whole raid as they are soaked instead, "
                        .. "which is why it becomes a healing problem rather than a "
                        .. "personal one.",
                    "This is where personal defensives go on both difficulties.",
                },
            },
            {
                name = "The constant damage",
                tag  = "Abyssal Rain and Unending Tides",
                lines = {
                    "Abyssal Rain is raid-wide AoE pulsing for a few seconds. On heroic "
                        .. "it is very heavy and it is what your healing cooldowns are "
                        .. "for.",
                    "Unending Tides puts Drenched on the entire raid -- constant ticking "
                        .. "damage that never stops.",
                    "On mythic the Rain matters less on its own and more because it "
                        .. "overlaps the first round of orbs.",
                },
            },
            {
                name = "Alluring Bubble",
                tag  = "the murlocs",
                lines = {
                    "She puts a bubble in the middle and it drags the murlocs in from "
                        .. "the edges of the room.",
                    "Any that reach it start becoming berserkers, which pulse AoE until "
                        .. "they die.",
                    "Stuns, slows and grips all work. Mind control does not -- it was "
                        .. "tried on the PTR and simply fails.",
                    "On mythic a Bubblefin Frostscale turns up with a shield that gives "
                        .. "nearby murlocs 99% damage reduction. Something has to "
                        .. "priority-target it or the whole pack is unkillable.",
                },
            },
            {
                name = "Swirling Whirlpools",
                tag  = "and where the safe ground is",
                lines = {
                    "Whirlpools are dragged from the edges of the room into the bubble "
                        .. "in the middle.",
                    "Look at the shoreline. One stretch of it has no disturbed water -- "
                        .. "that is the safe spot, and it is readable well in advance.",
                    "Put a demonic circle, a teleport or anything similar there before "
                        .. "it starts.",
                    "When they hit the middle they pop the bubble, deal some raid "
                        .. "damage, and try to knock everybody into the water.",
                    "The water is not a wipe but it is not survivable either: sharks "
                        .. "eat you and stack a bleed for as long as you are in it.",
                },
            },
        },

        heroic = {
            "Ice Blade Flurry is the tank hit here -- six slashes, +45% damage each. "
                .. "The tanks plan around the sixth, not the first.",
            "Frost orbs stack damage on the player soaking them, so orb duty rotates "
                .. "rather than falling to the same people.",
            "Abyssal Rain is the single heaviest planned hit, and the obvious place "
                .. "for a raid cooldown.",
        },

        roles = {
            DAMAGER = {
                "Orbs first, always. Nothing else you are doing outweighs an orb that "
                    .. "is about to shatter.",
                "The murlocs are the other real job. Hold them with stuns, slows and "
                    .. "grips before they reach the bubble.",
                "On mythic, kill the Bubblefin Frostscale first -- its shield makes "
                    .. "every murloc near it take 99% less damage.",
            },
            HEALER = {
                "Drenched ticks on everybody all fight, underneath everything else.",
                "Abyssal Rain on heroic is the planned burst. On mythic, save the "
                    .. "cooldowns for each round of orbs instead -- they come round "
                    .. "every 30 to 45 seconds.",
                "The first wave is the nastiest, because the Rain is pulsing while the "
                    .. "orbs are going out. Stack for it.",
                "Overhealing is not wasted here. The raid-wide damage on mythic is "
                    .. "high enough that a topped-off raid is the only safe one.",
            },
            TANK = {
                "Ice Blade Flurry ramps 45% a slash across six slashes. That is your "
                    .. "swap.",
                "On mythic, Water Jet is yours to aim -- it is what clears the frozen "
                    .. "ground, so treat it as a job rather than a hit.",
                "Keep her away from the shoreline the raid is going to need when the "
                    .. "whirlpools land.",
            },
        },
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

--- Bosses in pull order, instance by instance.
function G:Ordered()
    local out = {}
    for i, b in ipairs(self.bosses) do out[i] = b end
    table.sort(out, function(a, b)
        local ia, ib = self:InstanceOf(a).order, self:InstanceOf(b).order
        if ia ~= ib then return ia < ib end
        return a.order < b.order
    end)
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
