local _, ns = ...

------------------------------------------------------------
-- The Venomous Abyss, one mechanic at a time.
--
-- The unit here is a MECHANIC, not a paragraph: a spell, what kind of
-- thing it is, one imperative you can act on, and at most two lines of
-- why. That shape is deliberate. A pre-pull read is a scan, not a
-- study, and the old file -- eight bullets of prose per phase -- was a
-- correct document that nobody could use with a timer running.
--
-- Every mechanic carries its real `spell` id, so the page draws the
-- client's own icon and the client's own tooltip. Nothing is described
-- here that the tooltip already says; the lines are for the part the
-- tooltip never tells you, which is what to DO.
--
-- Difficulty is a property of the MECHANIC, not a chapter at the end.
--   `diff = "heroic"` -- does not exist on Normal
--   `diff = "mythic"` -- does not exist below Mythic
--   `heroic = "..."`  -- exists everywhere, but Heroic changes it
--   `mythic = "..."`  -- exists everywhere, but Mythic changes it
-- The page badges those in place. A player reading Heroic sees the
-- difference next to the thing it changes, rather than in a summary
-- page they have already scrolled past.
--
------------------------------------------------------------
-- SOURCES.
--
-- 1. mythictrap.com (Warcraft Logs), per-boss guides, read 2026-08-20.
--    Now the structural source: a real spellID for every ability, the
--    phase each belongs to, and -- the part nothing else on this
--    machine had -- an explicit list of what Heroic and what Mythic
--    change, boss by boss.
--
--    Its wording is theirs and is NOT reproduced. Every line below is
--    written here, from the mechanics it describes.
--
--    Two names it settles that were flagged `unsure` for months: the
--    Twin Fangs are VEXHUL and ITHRAZ, and Malacrass is corroborated
--    by a source that is not the video his name came from.
--
--    Where it disagrees with us the disagreement is recorded at the
--    boss, not silently resolved -- search for `CONFLICT`.
--
-- 2. Automatic Jack's PTR walkthrough (youtu.be/ktdXrfmJYZg), the
--    primary source for the previous pass, and still the reason
--    several "what to do" lines say more than a spell list can. Where
--    both cover a mechanic, mythictrap's naming wins and Jack's advice
--    survives.
--
-- 3. NorthernSkyRaidTools' saved variables (Tools/extract_nsrt.py) for
--    phase structure and timers, and the client itself -- BigWigs,
--    Plumber, RaiderIO -- for boss names, journal IDs and pull order.
--    RaidGuideEJ now matches our mechanics to the Encounter Journal by
--    SPELL ID rather than by word overlap.
--
-- Tuning numbers came from pre-launch guides and may have moved. The
-- mechanics are the part that holds.
------------------------------------------------------------

ns.RaidGuide = ns.RaidGuide or {}
local G = ns.RaidGuide

------------------------------------------------------------
-- The instances this page covers.
--
-- More than one, because The Tidebound Grotto is a LAIR -- an
-- instanced world boss that fills the raid row of the Great Vault --
-- and sending a player elsewhere to read about the only other thing
-- that drops raid gear this patch is an errand for no reason.
--
-- Bosses carry an `instance` key; anything without one is Venomous
-- Abyss.
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
    instanceID = 3004,
    ejInstanceID = nil,
    note = "Normal, Heroic and Mythic. Written from pre-launch guides, so "
        .. "tuning numbers may have moved -- the mechanics are the part "
        .. "that holds.",
}

------------------------------------------------------------
-- Difficulties.
--
-- Ordered, because "does this mechanic exist yet" is a threshold
-- question: a heroic mechanic is also a mythic one.
------------------------------------------------------------
G.DIFFS = {
    { key = "normal", label = "Normal", rank = 1, tone = { 0.45, 0.85, 1.00 } },
    { key = "heroic", label = "Heroic", rank = 2, tone = { 1.00, 0.42, 0.35 } },
    { key = "mythic", label = "Mythic", rank = 3, tone = { 0.78, 0.45, 1.00 } },
}

local RANK = {}
for _, d in ipairs(G.DIFFS) do RANK[d.key] = d.rank end

--- The rank of a difficulty key, defaulting to Normal.
function G:Rank(diff) return RANK[diff] or 1 end

--- Is `mech` present at difficulty `diff`?
function G:MechanicShows(mech, diff)
    if not mech then return false end
    if not mech.diff then return true end
    return (RANK[diff] or 1) >= (RANK[mech.diff] or 1)
end

--- The difficulty-specific notes on `mech` the reader is high enough to
--- be affected by. A Mythic reader still sees the Heroic change --
--- heroic changes do not stop applying because you went up.
function G:MechanicNotes(mech, diff)
    local out = {}
    if not mech then return out end
    local rank = RANK[diff] or 1
    if mech.heroic and rank >= 2 then
        out[#out + 1] = { key = "heroic", text = mech.heroic }
    end
    if mech.mythic and rank >= 3 then
        out[#out + 1] = { key = "mythic", text = mech.mythic }
    end
    return out
end

--- The boss-wide "what this difficulty adds" lines, or nil.
function G:ChangesFor(boss, diff)
    if not (boss and boss.changes) then return nil end
    local lines = boss.changes[diff]
    if lines and #lines > 0 then return lines end
    return nil
end

--- Every mechanic of a boss that shows at `diff`, phase by phase.
--- Exposed because both the page and RaidGuideEJ need the same answer,
--- and two copies of this filter would drift.
function G:MechanicsAt(boss, diff)
    local out = {}
    for _, phase in ipairs(boss and boss.phases or {}) do
        for _, mech in ipairs(phase.mechanics or {}) do
            if self:MechanicShows(mech, diff) then out[#out + 1] = mech end
        end
    end
    return out
end

------------------------------------------------------------
-- The bosses.
--
-- `rules` is the part that matters: if a player reads three lines
-- before a pull, these are the three -- what wipes the raid, not what
-- hurts. `phases` is one page each in the UI.
--
-- `bring` is the comp note, and only ever the DIFFERENCE from a
-- standard two tanks / four healers / fourteen DPS.
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
        lust    = "phase two -- it is a race against her energy bar",

        rules = {
            "Watch her energy bar. Every Soulcoil Ignition channel gives her 25 "
                .. "and every add that reaches the well gives 5, and she enrages "
                .. "when it fills.",
            "Kill the skeletons before they reach the well. Breaking their shields "
                .. "stops them walking, and a tank can then pick them up.",
            "Ride the Essence Rend knockback out to the edge before you get "
                .. "dispelled. The puddle it leaves sits there for the rest of the "
                .. "fight.",
        },

        changes = {
            heroic = {
                "Every dot also stacks a 15% vulnerability, so the same damage "
                    .. "lands much harder.",
                "Dead skeletons leave corpses, and a corpse you do not burn "
                    .. "stands back up.",
            },
            mythic = {
                "Someone has to go INTO the well to kill a Drowned Echo.",
                "Invoke now interrupts anyone casting when it lands.",
            },
        },

        phases = {
            {
                name = "Phase one",
                tag  = "100% to 50%",
                mechanics = {
                    {
                        name = "Uncoiled Rage", spell = 1284034,
                        tag = "Enrage", todo = "Do not let her cap energy",
                        lines = {
                            "Her channel gives 25 energy. Each add that reaches "
                                .. "the well gives 5 more.",
                            "At a full bar she hits for five times as much and "
                                .. "cannot be taunted, which ends most pulls.",
                        },
                    },
                    {
                        name = "Soulcoil Ignition", spell = 1285681,
                        tag = "Raid damage", todo = "Healing cooldown, then dodge",
                        lines = {
                            "She ports to the middle, channels, and puts five "
                                .. "stacks of her dot on everyone.",
                            "Circles land under the raid while she does it.",
                        },
                    },
                    {
                        name = "Soulcoil Well", spell = 1284032,
                        tag = "Adds", todo = "Break the shields",
                        lines = {
                            "Skeletons rise from the glowing coffins and walk for "
                                .. "the middle.",
                            "The shield is what makes them walk. Break it and a "
                                .. "tank can simply pick them up.",
                        },
                        heroic = "Grip and stun them into PILES -- you have to burn "
                            .. "the corpses later, and you cannot burn a queue.",
                    },
                    {
                        name = "Essence Rend", spell = 1287426,
                        tag = "Dispel", todo = "Take it to the edge first",
                        lines = {
                            "You get pulled, then knocked back, then left with a "
                                .. "dispellable debuff.",
                            "Where it ends is where a permanent floor hazard lands. "
                                .. "Ride the knockback out and dispel there.",
                        },
                    },
                    {
                        name = "Possession Barrage", spell = 1284103,
                        tag = "Fall-off damage", todo = "Tank stands well out",
                        lines = {
                            "Ghosts fire down one lane at the tank and hurt more "
                                .. "the closer you are when they land.",
                            "The raid stands behind her, out of the lane.",
                        },
                    },
                    {
                        name = "Corpse Blight", spell = 1294729,
                        tag = "Damage over time", todo = "Heal through it",
                        lines = {
                            "Anyone within 15 yards of a dying skeleton catches a "
                                .. "15-second dot.",
                        },
                    },
                    {
                        name = "Hollowing Strikes", spell = 1284110,
                        tag = "Tank debuff", todo = "Swap around 8 stacks",
                        lines = {
                            "Her melee stacks a dot and cuts the tank's healing "
                                .. "received by 15% a stack.",
                        },
                    },
                    {
                        name = "Vessel of Awakening", spell = 1295263,
                        tag = "Resurrection", todo = "Burn the corpses",
                        diff = "heroic",
                        lines = {
                            "Skeletons now leave a body behind, and a body that is "
                                .. "not burned gets back up.",
                            "Only the intermission's flames burn one. Pile the "
                                .. "bodies where those will land.",
                        },
                    },
                    {
                        name = "Grasping Depths", spell = 1293212,
                        tag = "Assignment", todo = "Send a group into the well",
                        diff = "mythic",
                        lines = {
                            "A Drowned Echo spawns in another phase, and the whole "
                                .. "raid is dragged inward and rotted while it lives.",
                            "You reach it by entering the well. Everyone who does "
                                .. "takes a vulnerability, so assign groups.",
                        },
                    },
                },
            },
            {
                name = "Intermission",
                tag  = "at 50% -- burn the piles",
                mechanics = {
                    {
                        name = "Echo of Jawae", spell = 1289696,
                        tag = "Boss immune", todo = "Kill both Echoes",
                        lines = {
                            "Two spawn on opposite sides. She is immune until both "
                                .. "are down, and killing them ends the phase.",
                        },
                    },
                    {
                        name = "Soul Transfer", spell = 1292248,
                        tag = "Line", todo = "Get out from between them",
                        lines = {
                            "A 15-second channel from Jawae into Nek'zali that ends "
                                .. "in a blast along that line.",
                            "You cannot stop it. Just do not be standing in it.",
                        },
                    },
                    {
                        name = "Hungering Pyre", spell = 1289855,
                        tag = "Soak", todo = "Melee soak it, on the bodies",
                        lines = {
                            "A circle on the active tank, split between everyone "
                                .. "standing in it.",
                            "It cremates corpses underneath, so put it on the "
                                .. "biggest pile you made.",
                        },
                    },
                    {
                        name = "Cremation", spell = 1289875,
                        tag = "Puddle", todo = "Walk yours over a corpse",
                        lines = {
                            "Everyone who did not soak gets a flame instead. It "
                                .. "burns bodies too.",
                            "Ranged spread and drag theirs across the other piles. "
                                .. "Two rounds is all the cleanup you get.",
                        },
                        heroic = "On Heroic the flame explodes when it ends, and that "
                            .. "blast is what actually destroys the corpses in it.",
                    },
                },
            },
            {
                name = "Phase two",
                tag  = "50% to 0%, and her energy is the timer",
                mechanics = {
                    {
                        name = "Invoke", spell = 1299673,
                        tag = "Moving hazards", todo = "Watch the floor move",
                        lines = {
                            "Every puddle you dropped in phase one gets up and "
                                .. "repositions across the room.",
                            "Not all of them move on every cast, so keep looking.",
                        },
                        mythic = "It also interrupts anyone mid-cast when it lands.",
                    },
                    {
                        name = "Soulcoil Well", spell = 1284032,
                        tag = "Adds", todo = "Same job, less room",
                        lines = {
                            "Adds keep coming, and there is no way left to burn a "
                                .. "corpse.",
                        },
                    },
                    {
                        name = "Essence Rend", spell = 1287426,
                        tag = "Dispel", todo = "Still the edge",
                        lines = {
                            "The floor is filling up. Every puddle placed badly is "
                                .. "one you dodge for the rest of the pull.",
                        },
                    },
                    {
                        name = "Possession Barrage", spell = 1284103,
                        tag = "Fall-off damage", todo = "Tank far, raid behind",
                        lines = {
                            "Unchanged, but the room is smaller now.",
                        },
                    },
                    {
                        name = "Hollowing Strikes", spell = 1284110,
                        tag = "Tank debuff", todo = "Keep swapping",
                        lines = {
                            "Use Bloodlust here and push her down before her "
                                .. "energy bar fills.",
                        },
                    },
                },
            },
        },

        roles = {
            DAMAGER = {
                "Shields first. A shieldless skeleton stops walking at the well.",
                "Stun, slow and grip them into piles -- the intermission burns "
                    .. "bodies, and you cannot burn a queue.",
                "In the intermission, cleave the Echoes and the corpses together.",
                "Hold cooldowns for phase two and push her down before her energy "
                    .. "bar fills.",
            },
            HEALER = {
                "Essence Rend is a dispel, but the puddle lands where the player "
                    .. "is standing. Let the knockback finish first.",
                "Mass dispel is excellent here as long as they are at the edge.",
                "Phase two adds a permanent stacking dot on top of everything.",
            },
            TANK = {
                "Possession Barrage: stand well out, pointed away.",
                "Hollowing Strikes is 15% less healing a stack. Swap near 8.",
                "The Pyre lands on you. Stand on the biggest pile of bodies.",
            },
        },
    },

    ----------------------------------------------------------
    -- CONFLICT: our previous pass had the intermission orbs as a
    -- venom count "summing to four" with no name. mythictrap names the
    -- puzzle Helical Toxins and describes the same arithmetic, so the
    -- mechanic was right and only the name was missing.
    --
    -- TWO CORRECTIONS FROM THE PLAYER, 2026-08-20, both from a real
    -- pull and both beating what mythictrap says.
    --
    -- 1. Unstable Miasma does NOT leave a puddle under the players who
    --    soak it. mythictrap says soakers are debuffed and drop a
    --    circle of their own; on Normal they do not, so the line
    --    telling the raid to soak at the edge and scatter afterwards is
    --    gone -- it was sending people to the rim for no reason and
    --    costing them position on the droplets.
    --
    --    UNVERIFIED ON HEROIC. It is deliberately not written as a
    --    heroic delta, because nobody has looked: "the player saw
    --    Normal not do it" is evidence about Normal only, and inventing
    --    a heroic-only version would be dressing a guess as a source.
    --    Worth one glance on the next heroic clear.
    --
    -- 2. THE BOSSES DO NOT MOVE AT THE INTERMISSION. This was written
    --    as "tanks swap Sentinels", which reads as dragging your boss
    --    across the room to trade. What actually happens is that the
    --    two GROUPS swap sides while the Sentinels stay where they are,
    --    and each tank taunts whichever one their group has just walked
    --    up to.
    --
    --    Worth knowing that the trainer already had this right -- its
    --    Sentinels phases move the PLAYER between sides rather than
    --    changing the fight -- so the arena and the guide disagreed and
    --    the arena was correct.
    ----------------------------------------------------------
    {
        id      = "sentinels",
        order   = 2,
        name    = "Entombed Sentinels",
        ejID    = 2874,
        encounterID = 3445,
        accent  = { 0.45, 0.90, 0.40 },
        oneLiner = "Two bosses, kept apart, and then the raid does maths.",
        shape   = "2 targets + a puzzle intermission",
        bring   = "poison and magic dispels",

        rules = {
            "Half the raid on each Sentinel, and keep the two bosses apart. While "
                .. "the Blood and the Breath are close together they take almost no "
                .. "damage.",
            "Run over every Toxic Droplet to squash it. Any you leave behind "
                .. "explode for heavy raid-wide damage.",
            "In Vitriolic Stasis, pair up with one other player so your green orbs "
                .. "add to exactly four. You get 30 seconds to find them.",
        },

        changes = {
            heroic = {
                "Blood puddles have to go to the edges or you run out of floor.",
                "Venom projectiles now fire back across the room. Do not stand "
                    .. "in their path.",
            },
            mythic = {
                "Some players get marked with a circle and have to touch each "
                    .. "other -- and avoid everyone who is not marked.",
            },
        },

        phases = {
            {
                name = "Both sides",
                tag  = "half the raid on each Sentinel",
                mechanics = {
                    {
                        name = "Toxic Droplets", spell = 1284434,
                        tag = "Run over", todo = "Squash them all",
                        lines = {
                            "Small green droplets land around your side. Run over "
                                .. "one to pop it.",
                            "Any that survive explode for heavy raid damage.",
                        },
                    },
                    {
                        name = "Unstable Miasma", spell = 1288232,
                        tag = "Soak", todo = "Your whole side stands in it",
                        lines = {
                            "One player is marked and bursts after a moment. "
                                .. "Everyone on that side soaks it to split the "
                                .. "damage.",
                        },
                    },
                    {
                        name = "Blood Venom", spell = 1284208,
                        tag = "Puddles", todo = "Drop them at the edge",
                        lines = {
                            "The debuff leaves a puddle wherever you are standing "
                                .. "when it ends.",
                        },
                        heroic = "Walk to the rim before it drops. Heroic leaves you "
                            .. "very little clean floor to fight on.",
                    },
                    {
                        name = "Blighted Blood", spell = 1284471,
                        tag = "Dispel", todo = "Dispel it, or take it out",
                        lines = {
                            "A magic dot on several players that leaves a puddle if "
                                .. "it expires on its own.",
                            "Anyone not dispelled walks theirs to the edge first.",
                        },
                    },
                    {
                        name = "Venom Coagulation", spell = 1284251,
                        tag = "Add", todo = "Kill the slime",
                        lines = {
                            "A large slime spawns and pulses raid-wide damage for "
                                .. "as long as it is alive.",
                        },
                    },
                    {
                        name = "Bloodvenom Injection", spell = 1284487,
                        tag = "Tankbuster", todo = "Blood's tank hit",
                        lines = {
                            "Physical damage plus a stacking dot. You swap at every "
                                .. "intermission, so expect three or four.",
                        },
                    },
                    {
                        name = "Empowering Slam", spell = 1284458,
                        tag = "Tankbuster", todo = "Breath's tank hit",
                        lines = {
                            "Big physical hit that leaves the boss 15% stronger "
                                .. "until it swings at somebody else.",
                        },
                    },
                    {
                        name = "Living Venom", spell = 1284207,
                        tag = "Projectile", todo = "Stay out of the lane",
                        diff = "heroic",
                        lines = {
                            "Venom now travels back across the room to the Breath, "
                                .. "hurting anyone it passes through.",
                        },
                    },
                    {
                        name = "Shifting Protovenom", spell = 1296878,
                        tag = "Pair up", todo = "Marked players touch each other",
                        diff = "mythic",
                        lines = {
                            "Marked players have to reach another marked player.",
                            "Touching an UNMARKED player knocks you both back and "
                                .. "hurts. Everyone else spreads out.",
                        },
                    },
                },
            },
            {
                name = "Vitriolic Stasis",
                tag  = "the intermission -- 30 seconds of maths",
                mechanics = {
                    {
                        name = "Helical Toxins", spell = 1284590,
                        tag = "Puzzle", todo = "Pair up to exactly four",
                        lines = {
                            "Everyone gets orbs over their head. Green orbs are your "
                                .. "stack count.",
                            "Find one partner whose count plus yours makes FOUR. "
                                .. "Wrong, and you eat a huge hit and a long dot.",
                            "Coming out of it the two groups swap sides. The "
                                .. "Sentinels do not move, so each tank taunts "
                                .. "whichever one is now next to their group.",
                        },
                    },
                },
            },
        },

        roles = {
            DAMAGER = {
                "Droplets before damage, every time.",
                "Do not take the two bosses close together to cleave them. It is "
                    .. "their distance from each other that matters, and close "
                    .. "together they take almost nothing.",
                "You standing in the middle to hit both is fine if you can carry "
                    .. "it -- you pick up a stacking dot from each Sentinel you are "
                    .. "within 40 yards of, so you get both.",
                "Know your orb count before the intermission lands. Thirty seconds "
                    .. "is not long to go looking.",
            },
            HEALER = {
                "Two dispel types here: poison off the droplets, magic off "
                    .. "Blighted Blood.",
                "The Miasma soak is a planned raid hit. Everyone on that side is "
                    .. "in it.",
                "Failed puzzle pairs take a huge hit and then a dot. Watch for who "
                    .. "got it wrong rather than for the cast.",
            },
            TANK = {
                "After each intermission your group walks to the other side. The "
                    .. "Sentinels stay put, so taunt whichever one you arrive next "
                    .. "to rather than dragging yours across.",
                "Keep the two Sentinels on opposite sides of the room. They take "
                    .. "almost no damage while they are close together.",
                "Empowering Slam leaves the Breath buffed until it hits someone "
                    .. "else, so the swap matters more than the stacks.",
            },
        },
    },

    ----------------------------------------------------------
    -- Pull order is RaiderIO's (RAID_BOSS_VA_1..8), which puts the
    -- Explorers third. mythictrap lists Vashnik before them; journal-ID
    -- order settles neither, and the client locale is the better source
    -- for what the raid actually walks into first.
    ----------------------------------------------------------
    {
        id      = "explorers",
        order   = 3,
        name    = "The Lost Explorers",
        ejID    = 2894,
        encounterID = 3497,
        accent  = { 1.00, 0.72, 0.30 },
        oneLiner = "Three turtles, one fish, and a wipe on a timer.",
        shape   = "council, single phase",
        bring   = "interrupts, and someone who will carry the fish",
        lust    = "on pull -- the fight does not get easier later",

        rules = {
            "Tanks keep only one other turtle near Nama at a time. With two there, "
                .. "all three take 99% less damage.",
            "Run over the boxes to break them open and find the fish. Smacking a "
                .. "turtle with it is the only way to stop Final Ascension, which "
                .. "otherwise wipes the raid.",
            "Bring all three down at the same time, so pace your damage rather "
                .. "than killing whichever one is in front of you.",
        },

        changes = {
            heroic = {
                "The one-turtle-near-Nama rule is enforced properly: Iku or Gebbo, "
                    .. "never both.",
            },
            mythic = {
                "The Splinter dot from breaking boxes now hits the whole raid "
                    .. "instead of just the person who broke it.",
            },
        },

        phases = {
            {
                name = "The fight",
                tag  = "all three are up the whole time",
                mechanics = {
                    {
                        name = "United Defense", spell = 1297646,
                        tag = "Positioning", todo = "One turtle at a time near Nama",
                        lines = {
                            "Tanks keep only one other turtle near Nama at a time. "
                                .. "With two there, all three take 99% less damage.",
                            "Tanks walk Nama to Gebbo or Iku, never both, aiming to "
                                .. "finish all three together.",
                        },
                    },
                    {
                        name = "Dark Whispers", spell = 1295451,
                        tag = "Wipe timer", todo = "Fish before the cast lands",
                        lines = {
                            "Mor'zahi's energy fills all fight. At full he casts "
                                .. "Final Ascension and you die.",
                            "Hitting a turtle with the fish stops it -- and that "
                                .. "turtle gets its ultimate next.",
                            "Gebbo, then Nama, then Iku is the order that works.",
                        },
                    },
                    {
                        name = "Throw Junk", spell = 1291933,
                        tag = "Boxes", todo = "Run the boxes over",
                        lines = {
                            "Boxes land on marked spots and flatten anyone under "
                                .. "them. Run one over to clear it.",
                            "Each box you clear gives you a stacking dot, and any "
                                .. "left after 25 seconds explode. One holds the fish.",
                        },
                        mythic = "The dot from clearing a box now goes out raid-wide, "
                            .. "so spread the clearing around.",
                    },
                    {
                        name = "Disgusting Fish", spell = 1292490,
                        tag = "The fish", todo = "Pick it up, hit a turtle",
                        lines = {
                            "Somebody has to be carrying it before the cast. Decide "
                                .. "who before the pull, not during it.",
                            "The raid takes some rot damage after each smack.",
                        },
                    },
                    {
                        name = "Explosive Surprise", spell = 1297625,
                        tag = "Gebbo's ultimate", todo = "Bomb to the edge, then bounce",
                        lines = {
                            "A bomb is thrown at a marked player. Take it to the rim "
                                .. "-- it leaves a large fire and sends out a wave.",
                            "Mushrooms spawn to bounce you over the wave. Touch one "
                                .. "too early and it is gone when you need it.",
                        },
                    },
                    {
                        name = "Mighty Thud", spell = 1296092,
                        tag = "Nama's ultimate", todo = "Split across three soaks",
                        lines = {
                            "Three circles, in quick succession, each knocking you "
                                .. "back. Nobody can cover two.",
                            "Assign a group per circle before it happens. The leaps "
                                .. "leave puddles behind.",
                        },
                    },
                    {
                        name = "Frostfire Volley", spell = 1295893,
                        tag = "Iku's ultimate", todo = "Fire one side, frost the other",
                        lines = {
                            "You get fire or frost, and drop that puddle when it "
                                .. "expires. Touching the OPPOSITE element while you "
                                .. "still carry yours wipes the raid.",
                            "Drop yours on your side, then clear your dot by walking "
                                .. "into an opposite puddle -- after you have dropped, "
                                .. "never before.",
                        },
                    },
                    {
                        name = "Shell Spin", spell = 1296061,
                        tag = "Bait", todo = "Melee bait it outward",
                        lines = {
                            "Nama fires three shells at a random melee. Bait them "
                                .. "toward the rim, away from ranged.",
                        },
                    },
                    {
                        name = "Blink Nova", spell = 1292793,
                        tag = "Fall-off damage", todo = "Marked player runs out",
                        lines = {
                            "Iku blinks to the marked player and the blast is "
                                .. "reduced by distance from the raid.",
                        },
                    },
                    {
                        name = "Evil Eyes", spell = 1292388,
                        tag = "Swirls", todo = "Keep moving",
                        lines = {
                            "Circles land around the room throughout.",
                        },
                    },
                    {
                        name = "Icebound Flames", spell = 1286921,
                        tag = "Interrupt", todo = "Kick it, or dispel after",
                        lines = {
                            "Iku casts a bolt at a random player. If it lands, the "
                                .. "dot it leaves can be dispelled.",
                        },
                    },
                    {
                        name = "Shredding Shards", spell = 1295854,
                        tag = "Tank debuff", todo = "Swap after every cast",
                        lines = {
                            "Iku's dot also puts 50% extra magic damage taken on the "
                                .. "tank.",
                        },
                    },
                    {
                        name = "Steady Strikes", spell = 1291930,
                        tag = "Tank debuff", todo = "Watch your stacks",
                        lines = {
                            "Nama's melee stacks 4% physical vulnerability on "
                                .. "whoever it is hitting.",
                        },
                    },
                },
            },
        },

        roles = {
            DAMAGER = {
                "Boxes are a job, not a distraction. The fish is in one of them "
                    .. "and the wipe is on a timer.",
                "Watch which turtle the tanks have paired. Damage on a turtle that "
                    .. "is not the target is 99% wasted.",
                "Frostfire Volley: know your element before you move. Wrong side "
                    .. "with the wrong colour is a raid wipe, not a death.",
            },
            HEALER = {
                "Box clearing stacks a dot on whoever does it, so it lands on your "
                    .. "melee over and over.",
                "Mighty Thud is three separate soaks in a row. Pre-plan cooldowns "
                    .. "rather than reacting three times.",
                "The rot after each fish smack is small and constant. It adds up "
                    .. "across a long fight.",
            },
            TANK = {
                "Walk Nama to one other turtle at a time, and never let a third "
                    .. "get close.",
                "Swap on Shredding Shards -- it is 50% more magic damage taken, "
                    .. "not a stack count.",
                "Bait Shell Spin outward if you are the one holding Nama.",
            },
        },
    },

    ----------------------------------------------------------
    {
        id      = "vashnik",
        order   = 4,
        name    = "Vashnik the Malignant",
        ejID    = 2882,
        encounterID = 3455,
        accent  = { 0.85, 0.35, 0.85 },
        oneLiner = "You choose which two fountains he drinks. Choose differently each time.",
        shape   = "1 phase, driven by where the tank stands",
        bring   = "an add plan, and healers who can chase absorbs",

        rules = {
            "Kill every add before it reaches the pool in the middle. Each one "
                .. "that arrives makes the rest of the fight harder.",
            "The tank walks him to whichever fountains you want lit, because the "
                .. "two nearest him are the two that empower him.",
            "Light a different pair on each Imbibe. He gains a lasting buff to "
                .. "whatever he drinks twice.",
        },

        changes = {
            heroic = {
                "Malignant Catalyst adds soak circles that wipe you if nobody is "
                    .. "standing in them.",
                "Burning Venom adds now hit the whole raid with a stacking dot as "
                    .. "they die, so kill them a few seconds apart.",
            },
            mythic = {
                "Malignant Tumors grow around the room and only Plague Froth waves "
                    .. "destroy them. Miss any and the raid dies.",
                "Siphoning Infection hits considerably harder.",
            },
        },

        phases = {
            {
                name = "The fight",
                tag  = "one phase, on the Imbibe cycle",
                mechanics = {
                    {
                        name = "Imbibe", spell = 1283164,
                        tag = "Fountains", todo = "Park him at the pair you want",
                        lines = {
                            "Three fountains: fire, blood, shadow. The two closest "
                                .. "light up and give him their abilities.",
                            "Lighting one is a raid-wide hit, and an active fountain "
                                .. "spawns its own kind of add.",
                        },
                    },
                    {
                        name = "Toxic Vapor", spell = 1284561,
                        tag = "Ramping damage", todo = "Heal through, and hurry",
                        lines = {
                            "Constant raid-wide damage that steps up with every "
                                .. "Imbibe cast, so a long pull becomes unhealable.",
                        },
                    },
                    {
                        name = "Splitting Clot", spell = 1286631,
                        tag = "Blood adds", todo = "Kill the pieces too",
                        lines = {
                            "Slow, uncontrollable adds that split when they die. "
                                .. "Killing the parent is not finishing the job.",
                        },
                    },
                    {
                        name = "Burning Presence", spell = 1305902,
                        tag = "Fire adds", todo = "Stagger the kills",
                        lines = {
                            "They pulse damage while alive and hit the raid again "
                                .. "when they die.",
                            "After a minute they stop being controllable and speed "
                                .. "up, so do not sit on them forever either.",
                        },
                        heroic = "Each death now leaves a stacking raid-wide dot. Kill "
                            .. "them a few seconds apart, never together.",
                    },
                    {
                        name = "Miasmic Coating", spell = 1312366,
                        tag = "Shadow adds", todo = "Burn through the absorb",
                        lines = {
                            "Shrouded Venom adds arrive with a large shield and "
                                .. "leave swirls behind when they die.",
                        },
                    },
                    {
                        name = "Siphoning Infection", spell = 1299941,
                        tag = "Stand close", todo = "Crowd the marked player",
                        lines = {
                            "The marked player cannot be healed and instead drains "
                                .. "life from anyone nearby.",
                            "Standing near them IS the heal. Stay until the absorb "
                                .. "is gone.",
                        },
                        mythic = "It hits much harder here, so send more people and go "
                            .. "sooner.",
                    },
                    {
                        name = "Stygian Infection", spell = 1294994,
                        tag = "Absorb", todo = "Heal it off fast",
                        lines = {
                            "A dot and a large healing absorb. Swirls keep landing "
                                .. "around that player until the absorb is cleared.",
                        },
                    },
                    {
                        name = "Exploding Infection", spell = 1295173,
                        tag = "Fall-off damage", todo = "Marked player runs out",
                        lines = {
                            "The blast is reduced by distance. Get properly away, "
                                .. "not just out of melee.",
                        },
                    },
                    {
                        name = "Plague Froth", spell = 1281907,
                        tag = "Spread", todo = "Spread, then dodge the waves",
                        lines = {
                            "You get a circle with lines across it, and waves fire "
                                .. "along those lines when it goes off.",
                        },
                        mythic = "These waves are also the only thing that destroys "
                            .. "the Tumors. Aim them, do not just avoid them.",
                    },
                    {
                        name = "Dripping Fangs", spell = 1280935,
                        tag = "Tankbuster", todo = "Swap on it",
                        lines = {
                            "A hit, then a dot and 100% extra damage taken. Not a "
                                .. "stack count -- swap every time.",
                        },
                    },
                    {
                        name = "Malignant Catalyst", spell = 1282525,
                        tag = "Soak", todo = "A body in every circle",
                        diff = "heroic",
                        lines = {
                            "Raid-wide damage that leaves circles behind. Any circle "
                                .. "nobody stands in explodes.",
                        },
                    },
                    {
                        name = "Malignant Tumor", spell = 1304459,
                        tag = "Wipe risk", todo = "Pop them with Plague Froth",
                        diff = "mythic",
                        lines = {
                            "Tumors appear after every Imbibe and only the Froth "
                                .. "waves destroy them.",
                            "Leave any standing when the phase turns over and the "
                                .. "raid dies.",
                        },
                    },
                },
            },
        },

        roles = {
            DAMAGER = {
                "Adds are the fight. Nothing you do to the boss matters if one "
                    .. "reaches the pool.",
                "Clotting Venom cannot be crowd controlled -- plan for the split "
                    .. "rather than trying to hold them.",
                "Go and stand next to the Siphoning Infection player until their "
                    .. "absorb is gone. They cannot be healed any other way.",
            },
            HEALER = {
                "Toxic Vapor rises all fight. Your cooldowns are worth more at the "
                    .. "end than at the start.",
                "Clear the Stygian Infection absorb quickly. Swirls keep landing "
                    .. "around that player until it is gone.",
                "You cannot heal a Siphoning Infection target. Send bodies instead.",
            },
            TANK = {
                "You steer the fight. The two fountains nearest you are the two he "
                    .. "drinks.",
                "Rotate the pairs. Drinking the same one twice is what makes him "
                    .. "dangerous.",
                "Dripping Fangs is 100% extra damage taken. Swap on every cast.",
            },
        },
    },

    ----------------------------------------------------------
    -- The `id` is "sisterrag" and stays that way. It is a saved-variable
    -- key and a trainer scenario key, and the name it came from was a
    -- mangled caption -- renaming it would orphan both for nothing.
    ----------------------------------------------------------
    {
        id      = "sisterrag",
        order   = 5,
        name    = "Sszorak",
        ejID    = 2871,
        encounterID = 3420,
        accent  = { 0.40, 0.80, 0.95 },
        oneLiner = "The wind will throw you off. The cysts are how you stay on.",
        shape   = "1 phase, with damage windows",
        bring   = "movement, and people who can count to three",
        lust    = "the first wind window -- he takes 30% more during it",

        rules = {
            "Read the wind tunnels around the rim. They show the three directions "
                .. "the wind is about to push you, in order.",
            "Drop your Viscous Cyst opposite a marked tunnel, then pop it as the "
                .. "wind hits. Its knockback cancels the push that would have "
                .. "thrown you off the platform.",
            "On Raging Crosswinds, find a player whose line points the opposite "
                .. "way and stand against them. The two knockbacks cancel.",
        },

        changes = {
            heroic = {
                "Mutilate leaves a 500% vulnerability, so the same group cannot "
                    .. "soak twice in a row. Alternate.",
                "Caustic Claws covers far more of the floor in venom.",
            },
            mythic = {
                "Serpent's Fury needs 14 people in one circle or he enrages.",
                "Everyone who soaks it then drops a puddle, so the floor is "
                    .. "permanently short of space.",
            },
        },

        phases = {
            {
                name = "The fight",
                tag  = "one phase, on the wind cycle",
                mechanics = {
                    {
                        name = "Howling Maelstrom", spell = 1285732,
                        tag = "Winds", todo = "Read the tunnels early",
                        lines = {
                            "Three pushes in three directions, shown above the "
                                .. "tunnels before they arrive.",
                            "He takes 30% more damage while they blow, so hold your "
                                .. "cooldowns for it.",
                        },
                    },
                    {
                        name = "Venomous Surge", spell = 1305959,
                        tag = "Place the cysts", todo = "Opposite the marked tunnels",
                        lines = {
                            "Marked players drop a Viscous Cyst where they stand "
                                .. "when the debuff ends.",
                            "Touching one pops it, knocking everyone back and slowing "
                                .. "them. That push is what saves you from the wind.",
                            "They pop on their own after two minutes. Clear spares "
                                .. "somewhere safe before they do it for you.",
                        },
                    },
                    {
                        name = "Raging Crosswinds", spell = 1285419,
                        tag = "Knockback", todo = "Find your opposite",
                        lines = {
                            "Your circle has a line pointing the way you are about "
                                .. "to be thrown, and it is a long way.",
                            "Stand against someone pointing back at you and the two "
                                .. "cancel.",
                        },
                    },
                    {
                        name = "Apex Predator", spell = 1277025,
                        tag = "Tank sequence", todo = "Five casts, three moves",
                        lines = {
                            "A random order of Ravage, Mutilate and Tempest. You can "
                                .. "taunt while he is already casting.",
                        },
                    },
                    {
                        name = "Ravage", spell = 1277002,
                        tag = "Frontal", todo = "Point it AWAY",
                        lines = {
                            "Solo tank hit with a 300% vulnerability. It does not "
                                .. "split, so nobody helps.",
                            "Twice per sequence.",
                        },
                    },
                    {
                        name = "Mutilate", spell = 1277027,
                        tag = "Frontal soak", todo = "Point it AT the raid",
                        lines = {
                            "The opposite of Ravage: it splits, so the raid stands "
                                .. "in it.",
                            "Twice per sequence. Swap after the first.",
                        },
                        heroic = "Now leaves a 500% vulnerability, so you need two soak "
                            .. "groups taking turns.",
                    },
                    {
                        name = "Tempest", spell = 1287072,
                        tag = "Tornadoes", todo = "Dodge them",
                        lines = {
                            "Tornadoes fire out from him and leave a dot on anyone "
                                .. "they clip. Once per sequence.",
                        },
                    },
                    {
                        name = "Caustic Claws", spell = 1305998,
                        tag = "Puddles", todo = "Leave the circles alone",
                        lines = {
                            "Circles mark where venom lands and stays.",
                        },
                        heroic = "Far more of them, and the floor you have left is also "
                            .. "the floor you need for the winds.",
                    },
                    {
                        name = "Corroding Venom", spell = 1282869,
                        tag = "Tank debuff", todo = "Swap on stacks",
                        lines = {
                            "Every melee swing stacks 3% more damage taken.",
                        },
                    },
                    {
                        name = "Ula'tek's Presence", spell = 1285961,
                        tag = "Rot", todo = "Heal through it",
                        lines = {
                            "Passive raid-wide damage for the whole fight.",
                        },
                    },
                    {
                        name = "Serpent's Fury", spell = 1297367,
                        tag = "Mass soak", todo = "14 people in the circle",
                        diff = "mythic",
                        lines = {
                            "He gains rage until it is activated, and full rage is "
                                .. "an enrage.",
                            "It needs fourteen players standing in the circle, so "
                                .. "somebody has to call it out.",
                        },
                    },
                    {
                        name = "Virulence", spell = 1297707,
                        tag = "Spread", todo = "Take it to the rim",
                        diff = "mythic",
                        lines = {
                            "Everyone who soaked the Fury bursts shortly after, "
                                .. "spreads the debuff to anyone nearby, and leaves a "
                                .. "puddle.",
                            "Scatter to the edges before it bursts, or you spread "
                                .. "the debuff and lose the floor as well.",
                        },
                    },
                },
            },
        },

        roles = {
            DAMAGER = {
                "Save everything for the wind window. He takes 30% more damage "
                    .. "while it blows.",
                "Your cyst is a tool for the raid, not a debuff to dump. Place it "
                    .. "where the next push comes FROM.",
                "Find your Crosswinds partner early. Looking for them after the "
                    .. "bar fills is too late.",
            },
            HEALER = {
                "Ula'tek's Presence never stops, so your baseline is already busy.",
                "Mutilate is a planned group hit -- on Heroic it is two groups "
                    .. "alternating, so cooldowns line up with the rotation.",
                "Anyone thrown off the platform is a battle res, so pre-empt the "
                    .. "wind rather than healing after it.",
            },
            TANK = {
                "Ravage away, Mutilate at the raid. Getting those two the wrong "
                    .. "way round kills people either way.",
                "You can taunt mid-sequence. Swap after the first Mutilate.",
                "Corroding Venom stacks on swings, so it climbs faster than it "
                    .. "looks during a long sequence.",
            },
        },
    },

    ----------------------------------------------------------
    -- The twins finally have names. mythictrap gives VEXHUL (the one
    -- that submerges and sweeps the beam) and ITHRAZ (the one that
    -- smashes), which is the second independent source for them, so the
    -- `unsure` flag this boss carried is gone.
    ----------------------------------------------------------
    {
        id      = "twinfangs",
        order   = 6,
        name    = "The Twin Fangs",
        ejID    = 2887,
        encounterID = 3421,
        accent  = { 0.95, 0.45, 0.45 },
        oneLiner = "Every mistake is a stack of venom, and the stacks are the timer.",
        shape   = "2 bosses, 1 phase, with a relocation",
        bring   = "one tank who will take every Stone Breaker",

        rules = {
            "Dodge everything you can. Almost every mechanic here adds a stack of "
                .. "Eternal Venom, and only Ravenous Feast takes them back off.",
            "Run over every Caustic Globule to soak it. An orb left to explode "
                .. "puts a stack on the whole raid instead of on one player.",
            "Bring both down together. Whichever twin is left alive on its own "
                .. "keeps gaining damage until it kills you.",
        },

        changes = {
            heroic = {
                "Ten stacks of Eternal Venom kills you outright.",
                "Ravenous Feast leaves a vulnerability, so you only get one soak "
                    .. "per set.",
                "Sanguine Storm now leaves puddles behind during the beam, while "
                    .. "you are already running.",
            },
            mythic = {
                "Ithraz shields the Globules as they spawn -- crowd control breaks "
                    .. "the shield before anyone can soak.",
                "Tainted Blood adds red orbs that need several people each, and "
                    .. "wipe the raid if they are missed.",
            },
        },

        phases = {
            {
                name = "The fight",
                tag  = "Vexhul and Ithraz, both up",
                mechanics = {
                    {
                        name = "Caustic Deluge", spell = 1289192,
                        tag = "Soak orbs", todo = "Soak them fast",
                        lines = {
                            "Vexhul dots the tank and scatters Globules nearby. They "
                                .. "blow after ten seconds.",
                            "Run one over and only YOU take the venom stack. Let it "
                                .. "pop and everybody does.",
                        },
                    },
                    {
                        name = "Ravenous Feast", spell = 1290516,
                        tag = "Soak", todo = "Soak to lose a stack",
                        lines = {
                            "Ithraz smashes the same circle three times, splitting "
                                .. "the damage among everyone in it.",
                            "Each smash removes one stack of Eternal Venom from "
                                .. "everyone standing in it. Nothing else takes "
                                .. "stacks off.",
                        },
                        heroic = "A vulnerability now means one soak per set each. Two "
                            .. "groups, taking turns.",
                    },
                    {
                        name = "Stone Breaker", spell = 1288538,
                        tag = "Tank soak", todo = "One tank, all three, in order",
                        lines = {
                            "Three circles appear in the order they must be taken, "
                                .. "and everyone else is shoved away.",
                            "Miss one and the raid eats it. Each costs the tank 33% "
                                .. "vulnerability for 90 seconds.",
                        },
                    },
                    {
                        name = "Venomous Emergence", spell = 1291404,
                        tag = "Adds", todo = "Kill them, dodge the lines",
                        lines = {
                            "Three Spawn of Vexhul arrive and everyone gains a "
                                .. "stack.",
                            "They fire lines at players; anyone clipped gains "
                                .. "another.",
                        },
                    },
                    {
                        name = "Coiling Ichor", spell = 1290809,
                        tag = "Move out", todo = "Take it to the edge",
                        lines = {
                            "The dot gets worse the longer it runs and leaves a "
                                .. "puddle where it ends.",
                        },
                    },
                    {
                        name = "Stir the Depths", spell = 1290956,
                        tag = "Waves", todo = "Dodge, do not tank them",
                        lines = {
                            "Raid-wide pulses plus waves crossing the room. Each wave "
                                .. "you eat is another venom stack.",
                        },
                    },
                    {
                        name = "Vile Flood", spell = 1294293,
                        tag = "Sweeping beam", todo = "Run with it, not into it",
                        lines = {
                            "Vexhul submerges, reappears in the middle and sweeps a "
                                .. "beam slowly around the room.",
                            "It ends with both bosses at a new corner, so you are "
                                .. "relocating while you dodge.",
                        },
                    },
                    {
                        name = "Sanguine Storm", spell = 1306872,
                        tag = "Swirls", todo = "Dodge while you relocate",
                        lines = {
                            "Ithraz dives at the same time and swirls land all over "
                                .. "the path you are running.",
                        },
                        heroic = "Those swirls now leave puddles, so the route out is "
                            .. "narrower every time it happens.",
                    },
                    {
                        name = "Toxic Fumes", spell = 1295049,
                        tag = "Rot", todo = "Heal through it",
                        lines = {
                            "Constant raid-wide damage underneath everything else.",
                        },
                    },
                    {
                        name = "Envenomed", spell = 1310360,
                        tag = "Tank debuff", todo = "Watch the stacks",
                        lines = {
                            "Vexhul's dot adds 10% vulnerability to the tank for that "
                                .. "mechanic.",
                        },
                    },
                    {
                        name = "Clotted Bolt", spell = 1295115,
                        tag = "Tank bolt", todo = "Stay in range",
                        lines = {
                            "They bolt a tank standing out of range, so stay in "
                                .. "melee on whichever twin you have.",
                        },
                    },
                    {
                        name = "Uncoiled Wrath", spell = 1308583,
                        tag = "Enrage", todo = "Finish them together",
                        lines = {
                            "Whichever twin is left alone keeps gaining damage until "
                                .. "it kills you.",
                        },
                    },
                    {
                        name = "Blood Torrent", spell = 1303230,
                        tag = "Shielded orbs", todo = "Crowd control, then soak",
                        diff = "mythic",
                        lines = {
                            "Ithraz shields every Globule as it spawns. Crowd control "
                                .. "breaks the shield.",
                            "Nobody can soak until that is done, and the ten-second "
                                .. "timer does not wait.",
                        },
                    },
                    {
                        name = "Tainted Blood", spell = 1310099,
                        tag = "Group soak", todo = "Several bodies per orb",
                        diff = "mythic",
                        lines = {
                            "Red orbs after each Feast, each needing several people "
                                .. "and each giving a healing absorb.",
                            "One left unsoaked wipes the raid.",
                        },
                    },
                    {
                        name = "Rouse the Brood", spell = 1308356,
                        tag = "Mass interrupt", todo = "Kick every single one",
                        diff = "mythic",
                        lines = {
                            "Around fourteen Broodlings, each casting a raid-wide "
                                .. "burst.",
                            "Every one has to be interrupted. Assign kicks by name "
                                .. "before the pull.",
                        },
                    },
                },
            },
        },

        roles = {
            DAMAGER = {
                "Orbs beat damage. A missed Globule costs the whole raid a stack "
                    .. "and you only get stacks back from Ravenous Feast.",
                "Stand in the Ravenous Feast circle. Each smash takes a stack of "
                    .. "Eternal Venom off everyone in it.",
                "Kill them evenly -- watch both health bars, not the one you are "
                    .. "targeting.",
            },
            HEALER = {
                "Toxic Fumes runs all fight, so the baseline never drops.",
                "The beam relocation is where people die: they are running, "
                    .. "dodging swirls and out of range at once.",
                "On Heroic, ten stacks is lethal. Track venom stacks as a health "
                    .. "bar, because that is what they are.",
            },
            TANK = {
                "One tank takes every Stone Breaker, all three circles, in the "
                    .. "marked order. Splitting them is how the raid gets hit.",
                "Stay in melee or you get bolted for it.",
                "The 33% vulnerability lasts 90 seconds, so the other tank is doing "
                    .. "real work between sets.",
            },
        },
    },

    ----------------------------------------------------------
    -- CONFLICT, recorded rather than resolved: mythictrap spells the
    -- troll "Zul'jan". This addon says Zul'jin, because TrinketData.lua
    -- carries an item called "Zul'jin's Guillotine Technique" and an
    -- item name is client data. A guide's spelling does not outrank it.
    --
    -- Malacrass, on the other hand, is no longer a guess: he is named
    -- by mythictrap independently of the video, and by our own
    -- "Hex Lord's Dooming Idol". The `unsure` flag is gone.
    ----------------------------------------------------------
    {
        id      = "alteredfangs",
        order   = 7,
        name    = "The Coiled Altar",
        ejID    = 2883,
        encounterID = 3429,
        accent  = { 0.80, 0.30, 0.35 },
        oneLiner = "Push everything into a pile, then let the tank cleave the pile.",
        shape   = "3 phases + intermission",
        bring   = "interrupts, and someone watching the edge",
        lust    = "the intermission, while Zul'jin takes double damage",

        rules = {
            "Pick up the orbs and kite the ghosts into loose clumps. The tank's "
                .. "frontal cone is what destroys them, not your damage.",
            "Break the shield on a mind-controlled ally before they walk off the "
                .. "edge.",
            "Bring both bosses down together. Whichever one is left alone "
                .. "enrages.",
        },

        changes = {
            heroic = {
                "Destroying orbs now stacks a dot on the raid, so you cannot cleave "
                    .. "them all at once.",
                "The axes never despawn. The floor only gets worse.",
                "Guillotine leaves a 500% vulnerability -- two soak groups, taking "
                    .. "turns.",
                "A Spiteful Soulcoiler joins phases two and three and fears the raid "
                    .. "unless it is interrupted.",
            },
            mythic = {
                "A purple orb is added that must not touch any other orb, and wipes "
                    .. "the raid if it survives the phase.",
                "Picking up any orb gives you 200% vulnerability for 10 seconds.",
                "Only the player a ghost is chasing can see it, and contact is "
                    .. "lethal rather than a mind control.",
                "Blocking souls in the intermission stacks 20% vulnerability on the "
                    .. "whole raid.",
            },
        },

        phases = {
            {
                name = "Phase one",
                tag  = "Zul'jin alone -- orbs",
                mechanics = {
                    {
                        name = "Coalesced Venom", spell = 1282403,
                        tag = "Orbs", todo = "Carry them into clumps",
                        lines = {
                            "Orbs land on marked spots. Walk over one to carry it for "
                                .. "five seconds, then it drops again.",
                            "Carrying gives you a dot. Use those five seconds to put "
                                .. "it next to the others.",
                        },
                        mythic = "Every pickup now costs 200% vulnerability for 10 "
                            .. "seconds, so rotate who carries.",
                    },
                    {
                        name = "Sever", spell = 1299680,
                        tag = "Tank frontal", todo = "Aim it at the clump",
                        lines = {
                            "The cone destroys orbs. Each orb destroyed is a burst of "
                                .. "raid damage, so a huge pile is as bad as none.",
                            "Anything still on the floor at the end of the phase goes "
                                .. "off anyway.",
                        },
                        heroic = "Destroying them also stacks a dot on the raid. Take "
                            .. "them in smaller batches.",
                    },
                    {
                        name = "Fangs of the Coiled Altar", spell = 1282487,
                        tag = "Raid damage", todo = "Cooldown, and clear the pools",
                        lines = {
                            "Heavy pulsing damage that floods two large pools onto "
                                .. "the platform.",
                            "They fade, but each cast leaves bigger ones than the "
                                .. "last.",
                        },
                    },
                    {
                        name = "Guillotine", spell = 1283594,
                        tag = "Soak", todo = "Five in, then run",
                        lines = {
                            "The axe splits its damage among soakers and needs at "
                                .. "least five.",
                            "It explodes shortly after landing and reaches 50 yards. "
                                .. "Soak, then leave immediately.",
                        },
                        heroic = "500% vulnerability afterwards, so you need two groups "
                            .. "alternating.",
                    },
                    {
                        name = "Axegrinder", spell = 1283832,
                        tag = "Dodge", todo = "Keep clear of the axes",
                        lines = {
                            "Thrown axes spin around the room for three minutes.",
                        },
                        heroic = "They never leave. Plan on the floor shrinking for the "
                            .. "rest of the fight.",
                    },
                    {
                        name = "Venomfang", spell = 1282287,
                        tag = "Dispel", todo = "Poison dispel",
                        lines = {
                            "A dispellable poison dot on random players.",
                        },
                    },
                },
            },
            {
                name = "Phase two",
                tag  = "Malacrass joins -- ghosts",
                mechanics = {
                    {
                        name = "Manifestation of Dread", spell = 1285911,
                        tag = "Ghosts", todo = "Look away to kite, look at it to stop",
                        lines = {
                            "A ghost fixates you and only moves while you are not "
                                .. "looking at it.",
                            "Kite it into the pile with your back turned, then face "
                                .. "it to park it there.",
                            "Contact mind controls you.",
                        },
                        mythic = "Only the person being chased can see their ghost, and "
                            .. "touching it kills rather than controls.",
                    },
                    {
                        name = "Soul Sever", spell = 1286620,
                        tag = "Tank frontal", todo = "Aim it at the ghosts",
                        lines = {
                            "Same idea as Sever, for ghosts. 200% vulnerability and a "
                                .. "dot on anyone caught in it.",
                        },
                    },
                    {
                        name = "Dreadmarch", spell = 1285643,
                        tag = "Mind control", todo = "Break the shield",
                        lines = {
                            "Controlled players walk toward the nearest edge. The "
                                .. "shield is what you have to break, and quickly.",
                        },
                    },
                    {
                        name = "Eternal Nightfall", spell = 1286918,
                        tag = "Wipe cast", todo = "Break the shield, dodge the swirls",
                        lines = {
                            "Malacrass shields himself and starts a long cast that "
                                .. "kills the raid if it finishes.",
                            "Breaking the shield stops it. Swirls land throughout and "
                                .. "the raid gains a stacking healing absorb.",
                        },
                    },
                    {
                        name = "Dreadful Presence", spell = 1288624,
                        tag = "Rot", todo = "Heal through it",
                        lines = {
                            "Constant damage for the whole phase.",
                        },
                    },
                    {
                        name = "Spiritcackle", spell = 1286441,
                        tag = "Interrupt", todo = "Kick it, then kill it",
                        diff = "heroic",
                        lines = {
                            "A Spiteful Soulcoiler spams a raid-wide fear that must be "
                                .. "interrupted every time.",
                            "It moves away after each kick, so ranged own it. At full "
                                .. "energy it stops being interruptible.",
                        },
                    },
                    {
                        name = "Spirit Shield", spell = 1309105,
                        tag = "Damage reduction", todo = "Hit it with Gloombomb",
                        diff = "mythic",
                        lines = {
                            "The Soulcoiler takes 99% less damage until a Gloombomb "
                                .. "circle lands on it.",
                            "Interrupting its fear also makes the ghosts visible to "
                                .. "everyone for a moment.",
                        },
                    },
                    {
                        name = "Gloombomb", spell = 1310882,
                        tag = "Clones", todo = "Move out, then collect yourself",
                        diff = "mythic",
                        lines = {
                            "You explode, and the blast splits off clones that run "
                                .. "loose nearby.",
                            "Run into every clone quickly or you die. The circles are "
                                .. "also the tool for the Soulcoiler's shield.",
                        },
                    },
                },
            },
            {
                name = "Intermission",
                tag  = "the damage window",
                mechanics = {
                    {
                        name = "Soulbinding", spell = nil,
                        tag = "Damage amp", todo = "Hero, and hit Zul'jin",
                        lines = {
                            "Malacrass binds himself to Zul'jin and heals them both. "
                                .. "He is immune; Zul'jin takes double damage.",
                        },
                    },
                    {
                        name = "Fragment of Malacrass", spell = 1287722,
                        tag = "Souls", todo = "Body-block them, but not all at once",
                        lines = {
                            "Every soul that reaches Zul'jin heals both bosses.",
                            "Standing in one stops it and hurts the raid, so share the "
                                .. "job rather than racing.",
                        },
                        mythic = "Each block now stacks 20% vulnerability on everyone, "
                            .. "which caps how many you can afford.",
                    },
                },
            },
            {
                name = "Phase three",
                tag  = "both of them, and both mechanics",
                mechanics = {
                    {
                        name = "Blighted Sever", spell = 1307279,
                        tag = "Tank frontal", todo = "Line up orbs AND ghosts",
                        lines = {
                            "One cone now clears both. Park them near each other so a "
                                .. "single swing does the work.",
                        },
                    },
                    {
                        name = "Defilement of the Crucible", spell = 1298381,
                        tag = "Tank swap", todo = "Swap to drop stacks",
                        lines = {
                            "The melee buff becomes a stacking dot on the tank instead "
                                .. "of a damage boost.",
                        },
                    },
                    {
                        name = "Dread Bolt", spell = 1307184,
                        tag = "Tank bolt", todo = "Expected damage",
                        lines = {
                            "Shadow damage at whoever is tanking.",
                        },
                    },
                    {
                        name = "Soulbound", spell = 1309987,
                        tag = "Enrage", todo = "Finish them together",
                        lines = {
                            "Leave one alive on its own and it enrages.",
                        },
                    },
                },
            },
        },

        roles = {
            DAMAGER = {
                "You gather, the tank kills. Carrying an orb or kiting a ghost "
                    .. "outranks your rotation.",
                "Watch the edge. Someone mind controlled is walking off it right "
                    .. "now.",
                "Save everything for the intermission -- Zul'jin takes double "
                    .. "damage and Malacrass cannot be touched.",
            },
            HEALER = {
                "Guillotine and Eternal Nightfall are the two planned raid hits.",
                "The healing absorb from Nightfall stacks while you are also "
                    .. "dodging, so clear it early rather than efficiently.",
                "Phase three runs both phases' damage at once. It is the heaviest "
                    .. "part of the fight.",
            },
            TANK = {
                "Your frontal is the raid's cleanup tool. Point it at clumps, not "
                    .. "at the boss.",
                "Sever leaves 200% vulnerability on anyone it clips, so check "
                    .. "behind the clump before you swing.",
                "Phase three swaps on the dot, not on a big hit.",
            },
        },
    },

    ----------------------------------------------------------
    -- Ula'tek, written 2026-08-20 from two video transcripts, because no
    -- written guide covered him -- not ours, not mythictrap's, whose page
    -- for him was empty at the time.
    --
    -- UPDATED 2026-08-28: mythictrap has published him. What that added,
    -- and it is the half transcripts cannot give:
    --
    --   * Real spell ids for Mother's Wrath, Unchecked Rage, Necrotic
    --     Vapors, Anguished Cry and Vicious Echoes. Those five draw the
    --     client's own icon and tooltip now instead of being matched by
    --     name through RaidGuideEJ:ResolveMechanics.
    --   * Two phase-one abilities nobody had captioned: Unchecked Rage
    --     is WHY both tanks hold their targets -- drift out of melee and
    --     the raid eats it -- and Necrotic Vapors is the rot underneath
    --     the phase.
    --   * The interrupts, by name, one per later phase.
    --   * Heroic changes, which go on the two mechanics they change.
    --     `changesUnknown` STAYS anyway: mythictrap publishes a Heroic
    --     block for this boss and no Mythic one.
    --
    -- It corroborated the transcripts everywhere else, including the two
    -- things they were most likely to have invented: the eggs breaking
    -- weak or hatching strong, and phase three's marked players being
    -- soaked rather than run from. `unsure` STAYS: the timers and the
    -- pickup order in phase two are still transcript-only, and those are
    -- the parts a pull actually runs on.
    --
    -- The second transcript (Squishy's, explicitly a NORMAL guide) is the
    -- primary one. It is sequenced, specific and internally consistent,
    -- and it corrected five things taken from the first pass -- worth
    -- listing, because every one of them was written down confidently:
    --
    --   * The thing you tank on the side is HER TAIL, which shares her
    --     health. The first transcript called it a "Gore Rattler", which
    --     is either an NPC name it heard or a name it invented.
    --   * Eggs hatch on a CAST TIMER as well as on contact with venom,
    --     and can be broken by DAMAGE as well as by a soak. The first
    --     source had only the venom half, which makes the eggs sound
    --     safe if you simply leave them alone. They are not.
    --   * The tank swap is during Caustic Waves, not after a knockback
    --     ring.
    --   * Phase two has hard timers -- 90 seconds to lift the doomscale
    --     egg, 20 more to deliver it -- and a pickup ORDER, because
    --     lifting the big egg starts every other egg on that side
    --     hatching. Neither was in the first source, and both are the
    --     phase.
    --   * Phase three's marked players are a mechanic other people SOAK
    --     (Serpent's Bite), not one they run away from. The first source
    --     had the raid running from the people it needs to stand on.
    --
    -- Kept from the first transcript only where the second is silent
    -- rather than contradictory: Mother's Wrath and the tail's ring.
    -- Dropped: its tank-swap timing, and its account of phase three's
    -- circles.
    --
    -- Still no `spell` ids -- both sources are auto-captioned, and
    -- inventing an id would attach a real tooltip to a heard name --
    -- so `unsure = true`, and RaidGuideEJ:ResolveMechanics closes the
    -- gap in the client by matching these names against the Encounter
    -- Journal.
    --
    -- `changesUnknown` because the good source says out loud that it is
    -- the Normal guide. `guideOnly` because the trainer has no arena.
    ----------------------------------------------------------
    {
        id      = "ulatek",
        order   = 8,
        name    = "Ula'tek",
        ejID    = 2895,
        encounterID = 3492,
        accent  = { 0.95, 0.85, 0.35 },
        oneLiner = "Break every egg yourself, before it hatches on its own.",
        shape   = "3 phases + intermission",
        bring   = "interrupts, a poison dispel, and two tanks",
        lust    = "the first Rage of the Shackled -- her heart takes double damage",
        unsure  = true,
        guideOnly = true,
        -- HEROIC is written: in the block below for the pre-pull summary,
        -- and on the two mechanics it changes for the in-phase badges.
        -- MYTHIC is not. mythictrap publishes a Heroic Changes block for
        -- this boss and no Mythic one, and inventing the deltas would be
        -- worse than admitting to none -- so the flag stays and the page
        -- now applies it per difficulty rather than to both at once.
        changesUnknown = true,

        changes = {
            heroic = {
                "Very little moves. The adds that come out of the eggs pick up "
                    .. "a few small abilities of their own.",
                "Breaking the phase two tether hits the WHOLE raid with a "
                    .. "damage-over-time instead of only the tethered player.",
            },
        },

        rules = {
            "Pick the eggs up by walking over them and keep them away from any "
                .. "venom. Break them on purpose and you get a weak add; let one "
                .. "hatch and you get a powerful one.",
            "An egg hatches when its own cast finishes OR when venom touches it, "
                .. "so leaving one alone is not safe.",
            "One tank stays on Ula'tek and one stays on her tail for the whole of "
                .. "phase one. They share a health pool, so damage both.",
        },

        phases = {
            {
                name = "Phase one",
                tag  = "two minutes, then the heart",
                mechanics = {
                    {
                        name = "Ula'tek's Eggs",
                        tag = "Carry", todo = "Walk over them to pick them up",
                        lines = {
                            "Eggs appear near the middle on the pull and once more "
                                .. "during the phase. Carry them and keep them out "
                                .. "of the waves until the tail casts Spectral "
                                .. "Coils.",
                            "You can also break an egg by damaging it to zero "
                                .. "health, which gives the same weak add.",
                            "Broken on purpose you get a Blightscale Rawling, which "
                                .. "dies to any cleave. Hatched by venom you get a "
                                .. "Blightscale Viper. One Viper is survivable; "
                                .. "several is the wipe.",
                        },
                        heroic = "The adds that come out of the eggs pick up a few "
                            .. "small abilities of their own. Nothing that changes "
                            .. "how the eggs are handled.",
                    },
                    {
                        name = "Ula'tek's tail",
                        tag = "Second target", todo = "One tank stays on it",
                        lines = {
                            "It spawns to her left or her right and shares her "
                                .. "health bar, so hit whichever is in front of you.",
                            "It also throws out a wide ring that launches anyone it "
                                .. "catches a long way. Step out of it.",
                        },
                    },
                    {
                        name = "Spectral Coils",
                        tag = "Soak", todo = "Everyone soaks except her tank",
                        lines = {
                            "The tail spawns a coil to either side of itself. Stand "
                                .. "in them with your egg.",
                            "The slam breaks every egg being carried and leaves weak "
                                .. "adds for the raid to AoE down.",
                        },
                    },
                    {
                        name = "Caustic Waves",
                        tag = "Dodge", todo = "Watch the wing she reaches back with",
                        lines = {
                            "That side gets waves first and the other side follows a "
                                .. "moment later. The tail then fires the last set, "
                                .. "so turn and check it.",
                            "Any wave that touches an egg hatches it into the "
                                .. "powerful add. Move the eggs, not just yourself.",
                            "Tanks swap during this cast.",
                        },
                    },
                    {
                        name = "Mother's Wrath", spell = 1298367,
                        tag = "Tank soak", todo = "Tank stands in the red circle",
                        lines = {
                            "She hits the tank, knocks them back a little and marks "
                                .. "a red circle for them to stand in and take "
                                .. "several hits.",
                            "Miss it and the debuff lands on the whole raid and hits "
                                .. "more times, which wipes you.",
                        },
                    },
                    {
                        name = "Unchecked Rage", spell = 1286945,
                        tag = "Stay close", todo = "Somebody in range at all times",
                        lines = {
                            "Leave Ula'tek with nobody in range and she casts. It "
                                .. "is a wipe, not chip damage -- which is why the "
                                .. "two tanks hold their targets rather than kite, "
                                .. "and why neither leaves to chase an egg.",
                            "The second target has its own version of the same "
                                .. "rule, so both need somebody standing there.",
                        },
                    },
                    {
                        name = "Necrotic Vapors", spell = 1286834,
                        tag = "Soft enrage", todo = "Push the phase, do not sit in it",
                        lines = {
                            "Raid-wide rot that STACKS and keeps climbing for as "
                                .. "long as the fight runs. Nothing to dodge, and "
                                .. "not a flat cost either -- it is the clock.",
                            "A phase one that drags is a phase one the healers lose "
                                .. "on their own.",
                        },
                    },
                    {
                        name = "Rage of the Shackled",
                        tag = "Burn window", todo = "Hit the heart, cleave onto her",
                        lines = {
                            "At the end of the phase her heart opens. It shares her "
                                .. "health and takes double damage.",
                            "Stand where you can hit the heart and cleave her at the "
                                .. "same time, and keep dodging the swirls.",
                        },
                    },
                },
            },
            {
                name = "Phase two",
                tag  = "split sides, and two hard timers",
                mechanics = {
                    {
                        name = "The split",
                        tag = "Positioning", todo = "One tank and an even share each side",
                        lines = {
                            "Assign the two groups before the pull. Cross the gap "
                                .. "once the barrier drops and find the Doomscale "
                                .. "Cauldron on your side.",
                            "Finishing early only brings her back early. The second "
                                .. "burn phase lands at 4:45 either way and is the "
                                .. "same as the first.",
                        },
                    },
                    {
                        name = "Doomscale Warden",
                        tag = "Add", todo = "Interrupt Malice, run out the tether",
                        lines = {
                            "Malice needs a kick every cast. The tether is broken by "
                                .. "the tethered player running away from it.",
                            "Partway through it teleports and starts hatching eggs. "
                                .. "Kill those eggs to break them before it finishes.",
                        },
                        heroic = "Breaking the tether puts a damage-over-time on the "
                            .. "WHOLE raid rather than only the player who was "
                            .. "tethered, so break it when the healers are not "
                            .. "already holding something together.",
                    },
                    {
                        name = "Anguished Cry", spell = 1305650,
                        tag = "Interrupt", todo = "Kick every cast",
                        lines = {
                            "The interrupt to keep somebody on for the whole of "
                                .. "phase two.",
                        },
                    },
                    {
                        name = "The doomscale egg",
                        tag = "Order matters", todo = "Small eggs first, big one last",
                        lines = {
                            "Once the Warden is dead you can lift the remaining eggs "
                                .. "on your side.",
                            "Picking up the big egg at the back starts every other "
                                .. "egg on that side hatching, so it goes last, "
                                .. "carried by whoever is left.",
                        },
                    },
                    {
                        name = "Doomscale Cauldron",
                        tag = "Deliver", todo = "Walk up to it to throw the egg in",
                        lines = {
                            "You get 90 seconds to lift the doomscale egg and 20 "
                                .. "more to get it into the cauldron.",
                            "Miss either timer and the empowered add hatches and "
                                .. "wipes the group.",
                        },
                    },
                    {
                        name = "Weakened Doomscale",
                        tag = "Interrupt", todo = "Kick it, then drag it to the middle",
                        lines = {
                            "Bring every add back to the centre platform so both "
                                .. "sides AoE them down together and end the phase "
                                .. "at the same time.",
                        },
                    },
                },
            },
            {
                name = "Intermission",
                tag  = "gather, soak, AoE",
                mechanics = {
                    {
                        name = "The egg fall",
                        tag = "Carry", todo = "Pick up every egg",
                        lines = {
                            "Eggs drop from the ceiling across the platform. Spread "
                                .. "out and clear them quickly.",
                        },
                    },
                    {
                        name = "The soaks",
                        tag = "Soak", todo = "Everyone into each circle",
                        lines = {
                            "Circles appear around the platform. Standing in one "
                                .. "breaks the eggs the raid is carrying.",
                            "AoE the adds down as you move from one soak to the "
                                .. "next.",
                        },
                    },
                },
            },
            {
                name = "Phase three",
                tag  = "quadrants, one fewer each cycle",
                mechanics = {
                    {
                        name = "The quadrants",
                        tag = "Positioning", todo = "Follow her to whichever she surfaces on",
                        lines = {
                            "She splits the platform into quarters and comes up at "
                                .. "one of them. Melee jump across, tanks pick her "
                                .. "up.",
                        },
                    },
                    {
                        name = "Platform eggs",
                        tag = "Kill them", todo = "Break every egg on sight",
                        lines = {
                            "Each cycle starts with an egg on every platform. Kill "
                                .. "them to break them, then group the adds up and "
                                .. "AoE them down.",
                        },
                    },
                    {
                        name = "Vicious Echoes", spell = 1310764,
                        tag = "Interrupt", todo = "Kick every cast",
                        lines = {
                            "Phase three's interrupt. Keep it covered while the "
                                .. "soak groups are moving.",
                        },
                    },
                    {
                        name = "Serpent's Bite",
                        tag = "Soak", todo = "Stand in the marked player's circle",
                        lines = {
                            "Three players get a 15-second debuff that kills them "
                                .. "unless other people soak enough of its ticks.",
                            "Spread the three out and put a group on each until it "
                                .. "fades. Overlapping the circles soaks faster but "
                                .. "is not needed.",
                        },
                    },
                    {
                        name = "The wave orbs",
                        tag = "Dodge", todo = "Stand where there are no orbs",
                        lines = {
                            "Orbs line up in front of her showing where the waves "
                                .. "are about to go. The gaps between them are safe.",
                        },
                    },
                    {
                        name = "The venom purge",
                        tag = "Spread", todo = "Five seconds to get clear",
                        lines = {
                            "When the soak finishes you have five seconds to spread "
                                .. "out and purge the venom without catching anyone "
                                .. "else in it.",
                        },
                    },
                    {
                        name = "Circling Prey",
                        tag = "Relocate", todo = "Leave the platform she is on",
                        lines = {
                            "She destroys whichever platform she is standing on, "
                                .. "then surfaces at another one.",
                            "Every platform lost drops its eggs straight into venom, "
                                .. "and those hatch empowered adds that hit harder "
                                .. "and need a poison dispel.",
                        },
                    },
                },
            },
        },

        roles = {
            DAMAGER = {
                "Her tail shares her health bar, so cleave both rather than picking "
                    .. "a target.",
                "Break eggs early. An egg you damage down gives a weak add; one "
                    .. "that finishes its cast gives an add that can wipe you.",
                "Hold cooldowns for Rage of the Shackled and hit the heart, "
                    .. "cleaving onto her at the same time.",
                "In phase three, go and stand in a Serpent's Bite circle. Those "
                    .. "three players die without you.",
            },
            HEALER = {
                "Serpent's Bite kills the marked players outright if nobody soaks "
                    .. "it, so watch who has help rather than who is low.",
                "Count healers on both sides before phase two splits you.",
                "The tank taking Mother's Wrath is meant to take several hits in a "
                    .. "row, so heal through it rather than expecting a swap.",
            },
            TANK = {
                "One of you is on Ula'tek and one is on her tail for all of phase "
                    .. "one. Swap during Caustic Waves.",
                "Ula'tek's tank is the one player who does NOT soak Spectral "
                    .. "Coils.",
                "Get into the red circle on Mother's Wrath. Missing it moves the "
                    .. "whole mechanic onto the raid.",
                "In phase two you are on the Doomscale Warden -- kick Malice and "
                    .. "keep it off the egg carriers.",
            },
        },
    },

    ----------------------------------------------------------
    -- The Tidebound Grotto -- a Lair, scaling World to Flexible Mythic.
    --
    -- CONFLICT, and a big one. Our previous pass called the orb
    -- mechanic "Frost Barrage" and had Unending Tides as a permanent
    -- raid-wide dot ("Drenched"). mythictrap has the orbs as CHILLING
    -- FROST and Unending Tides as the SIX MINUTE ENRAGE, and it carries
    -- spell ids for both. Both of ours came from an unnamed source with
    -- no ids attached, so the named, id-carrying version wins -- and the
    -- client settles it for good, because the tooltip on 1313393 and
    -- 1294867 is drawn from the game.
    --
    -- The shoreline, the sharks and the bleed are not in mythictrap's
    -- guide at all. They are not contradicted either, so they survive as
    -- positioning advice on the whirlpool rather than as a mechanic.
    ----------------------------------------------------------
    {
        id       = "nymrissa",
        instance = "tg",
        order    = 1,
        name     = "Nymrissa Wavecaller",
        ejID     = 2849,
        accent   = { 0.45, 0.80, 1.00 },
        oneLiner = "Soak every orb, kill every murloc, and beat the six-minute clock.",
        shape    = "1 phase, on a loop",
        bring    = "crowd control, and a way to reach the murlocs",
        lust     = "on pull -- there is a hard enrage at six minutes",

        rules = {
            "Kill the murlocs before they reach the bubble in the middle. Any that "
                .. "arrive are empowered when it pops and hit the whole raid.",
            "Run over every frost orb to soak it. They drop under players "
                .. "constantly and nothing else clears them.",
            "When the whirlpools sweep in, stand in the one stretch that has no "
                .. "whirlpool in it.",
        },

        changes = {
            heroic = {
                "Frost orbs explode on their own after 30 seconds, so soaking is on "
                    .. "a timer now.",
                "Every Abyssal Rain leaves her 3% stronger, which turns a long pull "
                    .. "into a losing one.",
            },
            mythic = {
                "Bubblefin Frostscale adds shield the rest by 99%. Kill those "
                    .. "first or nothing else dies.",
                "Soaking an orb now hits the whole raid, so soak them slowly and "
                    .. "deliberately.",
                "Water Jet replaces the simple tank hit and is the only way to "
                    .. "clear the ice off the floor.",
            },
        },

        phases = {
            {
                name = "The loop",
                tag  = "one phase, repeating, against a six-minute clock",
                mechanics = {
                    {
                        name = "Alluring Bubble", spell = 1257717,
                        tag = "Adds", todo = "Kill them before they arrive",
                        lines = {
                            "She raises a bubble in the middle and murlocs walk in "
                                .. "toward it from all around the room.",
                            "Any that reach it are empowered when it pops, and then "
                                .. "the raid takes the damage.",
                        },
                    },
                    {
                        name = "Swirling Whirlpools", spell = 1258668,
                        tag = "Avoid", todo = "Find the one safe gap",
                        lines = {
                            "Whirlpools form at the rim and sweep inward. Being "
                                .. "caught is enormous damage.",
                            "There is always exactly one gap with no whirlpool in it.",
                            "When they reach the bubble it pops: raid damage and a "
                                .. "knockback, so do not be near a drop.",
                        },
                    },
                    {
                        name = "Chilling Frost", spell = 1313393,
                        tag = "Soak orbs", todo = "Run the orbs over",
                        lines = {
                            "Several players get a dot, and every tick drops a frost "
                                .. "orb where they stand.",
                            "Soaking one costs you damage, a dot and a 15% slow per "
                                .. "orb, and leaves ice on the floor.",
                        },
                        heroic = "An orb nobody touches inside 30 seconds explodes. "
                            .. "Spread the soaking around -- the slow stacks.",
                        mythic = "Each soak now hits the whole raid, so pace them. "
                            .. "Soaking too fast is its own wipe.",
                    },
                    {
                        name = "Abyssal Rain", spell = 1260837,
                        tag = "Raid damage", todo = "Heal through it",
                        lines = {
                            "Pulsing raid-wide damage followed by a long dot on "
                                .. "everybody.",
                        },
                        heroic = "Each cast leaves her 3% stronger for the rest of the "
                            .. "pull. Every second you spend costs you.",
                    },
                    {
                        name = "Iceblade Flurry", spell = 1282937,
                        tag = "Tankbuster", todo = "Defensives, then swap",
                        lines = {
                            "A heavy dot on the tank plus 20% extra damage from the "
                                .. "next one.",
                        },
                    },
                    {
                        name = "Unending Tides", spell = 1294867,
                        tag = "Enrage", todo = "Be finished before six minutes",
                        lines = {
                            "At six minutes she pulses damage nothing survives. This "
                                .. "is a hard enrage, not a soft one.",
                        },
                    },
                    {
                        name = "Waterfog Shield", spell = 1273091,
                        tag = "Priority add", todo = "Kill the Frostscale first",
                        diff = "mythic",
                        lines = {
                            "Bubblefin Frostscale gives every murloc near it 99% "
                                .. "damage reduction.",
                            "Nothing else in the pack dies until it does.",
                        },
                    },
                    {
                        name = "Frost Burst", spell = 1313450,
                        tag = "Pacing", todo = "Do not soak all at once",
                        diff = "mythic",
                        lines = {
                            "Every orb soaked is a burst of raid-wide damage.",
                            "Soak them one at a time with a gap between, rather "
                                .. "than clearing the floor as fast as you can.",
                        },
                    },
                    {
                        name = "Water Jet", spell = 1258901,
                        tag = "Tank frontal", todo = "Sweep the ice with it",
                        diff = "mythic",
                        lines = {
                            "A beam at the tank that shoves anyone hit and stacks 20% "
                                .. "vulnerability every second.",
                            "It also erases the ice puddles, which makes it a tool. "
                                .. "Aim it at the worst of the floor.",
                        },
                    },
                },
            },
        },

        roles = {
            DAMAGER = {
                "Orbs first, always. Nothing you are doing outweighs one.",
                "Murlocs second. Stun, slow and grip them short of the bubble.",
                "On Mythic, kill the Bubblefin Frostscale first. Everything near it "
                    .. "takes 99% less damage until it dies.",
                "The safe gap is readable early. Be walking to it, not sprinting.",
            },
            HEALER = {
                "Abyssal Rain leaves a long dot on everyone, on top of the soak "
                    .. "dots your raid is collecting.",
                "On Heroic her damage climbs 3% a cast, so cooldowns are worth more "
                    .. "late than early.",
                "On Mythic the soaking itself is the raid damage. Heal the rhythm, "
                    .. "not the spike.",
            },
            TANK = {
                "Iceblade Flurry leaves 20% extra damage from the next one. Swap on "
                    .. "it.",
                "Keep her off the gap the raid will need when the whirlpools land.",
                "On Mythic, aim Water Jet across the worst of the ice puddles. "
                    .. "Nothing else clears them.",
            },
        },
    },
}

------------------------------------------------------------
-- Nothing is missing any more
------------------------------------------------------------
-- `G.missing` used to hold Ula'tek -- the raid's own namesake, with no
-- guide anywhere, drawn as a dim unclickable row at the foot of the
-- list. He now has an entry, so the list has no gap and the mechanism
-- is gone with it.
--
-- The UI still guards for `G.missing` being absent, deliberately. The
-- next raid will ship with a boss nobody has tested, exactly as this
-- one did, and the honest way to show that is a row that says so rather
-- than a boss quietly not appearing.
G.missing = nil

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

--- The role lines for a boss, for a role key.
---
--- Falls back to DAMAGER rather than to nothing: an unassigned player
--- reading the guide out of a group is far more likely to be a DPS than
--- to want an empty panel.
function G:RoleLines(boss, role)
    if not boss or not boss.roles then return {} end
    return boss.roles[role] or boss.roles.DAMAGER or {}
end
