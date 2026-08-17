local _, ns = ...

------------------------------------------------------------
-- The fights, in phases.
--
-- Read by Features\Raid\RaidTrainer.lua. A scenario is a list of PHASES,
-- each with its own clock and its own event list, and each naming the
-- condition that ends it (`duration`, `untilPct`, `untilClear`) plus the
-- health floor damage stops at (`hpFloor`).
--
------------------------------------------------------------
-- WHERE THIS COMES FROM.
--
-- Two sources, and they answer different questions.
--
-- 1. Features\Raid\RaidGuideData.lua -- the per-boss guides. This is the
--    authority for WHAT A MECHANIC IS AND WHAT YOU DO ABOUT IT: that
--    Blightburn fires out and then back, that an unsoaked Stonebreaker
--    swirly is the raid hit rather than a thing to dodge, that Nek'zali's
--    energy is fed by adds reaching the well rather than by a clock.
--    Every correction in this file traces to a line in that one.
--
-- 2. Tools/extract_nsrt.py -- a raid-tools addon's saved variables, for
--    the ability's real name, WHICH PHASE it belongs to, and the
--    seconds-from-pull it fires at. That is the structural half, and it
--    is the half no written guide supplies.
--
------------------------------------------------------------
-- TWO THINGS ARE DELIBERATELY NOT FAITHFUL.
--
-- TIME IS COMPRESSED. Real cycles run 60 to 90 seconds and a real pull
-- runs eight minutes. Each phase keeps the real ORDER and the real
-- RELATIVE SPACING and scales them down to something like thirty to
-- forty-five seconds. What is being practised is the sequence -- what
-- follows what, and how much room you get between them -- and that
-- survives scaling.
--
-- SOME MECHANICS ARE ABSENT ON PURPOSE. Anything whose answer is a
-- dispel, a defensive, a taunt swap or a raid-leader assignment is not
-- here. They are real, they are in the written guide, and none is a
-- thing a lone dot in an arena can practise. Inventing a shape for them
-- would be inventing a fight.
--
-- BUILT SINCE, and worth recording because each was listed here as
-- impractical and turned out not to be:
--   * Frostfire Volley's paired clearing. See KINDS.volley/cleanse.
--   * two boss actors, which the Sentinels and the Twin Fangs both
--     needed and which their headline rules are made of.
--   * every add on Vashnik walking for the pool, and feeding the bar
--     when it arrives.
--   * an add that BECOMES something when it arrives (`becomes`), which
--     is what a murloc reaching the Alluring Bubble does.
--   * refuge ground on the RIM rather than the open floor (`atRim`).
--
-- Covers The Tidebound Grotto as well as the raid now; see the foot of
-- the file. A Lair is a different kind of instance and the same kind of
-- scenario.
--
-- Still missing that COULD be built, in order of value:
--   * carrying venom orbs into a PILE for the tank's cone (Coiled
--     Altar). The carry verb exists; the pile does not.
--   * Sszorak's tunnel orbs -- reading a count BEFORE the intermission
--     to learn the wind order. Needs a readable-tell verb.
------------------------------------------------------------

ns.RaidTrainerScenarios = ns.RaidTrainerScenarios or {}
local SC = ns.RaidTrainerScenarios

--- Repeat an event on a fixed cadence, within a phase.
---
--- Times are relative to the PHASE, not the pull, so a phase reads as
--- its own script and can be retimed without renumbering what follows.
local function Every(first, interval, count, template)
    local out = {}
    for i = 0, count - 1 do
        local ev = {}
        for k, v in pairs(template) do ev[k] = v end
        ev.at = first + i * interval
        out[#out + 1] = ev
    end
    return out
end

--- A WAVE of the same thing, several at once, on a cadence.
---
--- Adds arrive in packs, not in single file. Nek'zali's Restless Amani
--- were spawning one at a time, which is why the guide's instruction --
--- grip and knock them into PILES so the intermission can burn them --
--- had nothing to act on: you cannot pile up a queue.
---
--- Spread slightly in time as well as position, so a pack reads as
--- several things arriving rather than one thing that got wider.
local function Pack(first, interval, waves, size, template)
    local out = {}
    for w = 0, waves - 1 do
        for k = 1, size do
            local ev = {}
            for key, v in pairs(template) do ev[key] = v end
            ev.at = first + w * interval + (k - 1) * 0.35
            out[#out + 1] = ev
        end
    end
    return out
end

--- Flatten cadences into one phase timeline, in time order.
---
--- Sorted because the trainer walks the list with a cursor and stops at
--- the first event not yet due. An unsorted list would silently drop
--- everything after the first late entry.
local function Timeline(...)
    local out = {}
    for _, group in ipairs({ ... }) do
        if group.at then
            out[#out + 1] = group
        else
            for _, ev in ipairs(group) do out[#out + 1] = ev end
        end
    end
    table.sort(out, function(a, b) return a.at < b.at end)
    return out
end

------------------------------------------------------------
-- 1. Nek'zali the Soulcoiler          encounterID 3470
--
-- Her energy bar is the fight, and it is fed by MISTAKES: every Restless
-- Amani that reaches the well gives her five. That is what `feeds` is
-- for, and why this scenario's energy has rate 0 -- a bar that ticked on
-- its own would teach the opposite of what this boss teaches.
------------------------------------------------------------
SC.soulcoiler = {
    bossId = "soulcoiler",
    title  = "Nek'zali the Soulcoiler",
    intro  = "Nothing reaches the well. Every add that does feeds her energy.",
    -- Down from 5200 when the Amani started arriving in packs. Three at
    -- a time is a lot more to shoot, so a lot less of the player's
    -- damage reaches her -- which is true of the real fight too, and is
    -- the reason her health had to come down rather than the packs.
    -- Down again with the raise stagger: bodies now get up over about
    -- twenty seconds of phase two, and every one of them soaks shots
    -- that used to reach her. Given deliberate headroom this time rather
    -- than trimmed to the exact number -- the sustained-fire check has
    -- now failed three times by under two percent, which is a sign the
    -- margin was too thin rather than that the number was wrong.
    bossHp = 4000,
    well   = true,
    wellName = "The Soulcoil Well",
    energy = { name = "Nek'zali", rate = 0, max = 100 },
    phases = {
        {
            name = "Phase One", untilPct = 55, hpFloor = 55, duration = 44,
            call = "Keep the Amani off the well",
            events = Timeline(
                -- A PACK at a time, which is what makes piling them up
                -- possible at all. See Pack.
                Pack(3, 11, 3, 3, {
                    kind = "chaser", name = "Restless Amani", school = "spirit",
                    where = "edge", goal = "centre", speed = 11, hp = 60,
                    art = "hex", damage = 26, feeds = 5, leavesCorpse = true,
                    call = "Restless Amani -- grip them into ONE pile",
                }),
                Pack(8, 11, 2, 2, {
                    kind = "chaser", name = "Restless Amani", school = "spirit",
                    where = "edge", goal = "centre", speed = 12, hp = 60,
                    art = "hex", damage = 26, feeds = 5, leavesCorpse = true,
                    heroicOnly = true,
                }),
                -- ONE line, four spirits running down it at the tank,
                -- one after another. Each pops on the first body it
                -- touches, so the lane has to be CLEAR rather than
                -- merely survivable -- and it is a single lane to clear,
                -- not four to dodge.
                Every(6, 12, 4, {
                    kind = "projectile", name = "Possession Barrage", school = "spirit",
                    where = "boss", cast = 2.0, lane = true, laneFor = 6,
                    speed = 56, damage = 22,
                    call = "Possession Barrage -- four spirits, ONE line. Clear it.",
                }),
                Every(6.5, 12, 4, {
                    kind = "projectile", name = "Possession Barrage", school = "spirit",
                    where = "boss", cast = 2.0, lane = true, speed = 56, damage = 22,
                }),
                Every(7.0, 12, 4, {
                    kind = "projectile", name = "Possession Barrage", school = "spirit",
                    where = "boss", cast = 2.0, lane = true, speed = 56, damage = 22,
                }),
                Every(7.5, 12, 4, {
                    kind = "projectile", name = "Possession Barrage", school = "spirit",
                    where = "boss", cast = 2.0, lane = true, speed = 56, damage = 22,
                }),
                -- The void zone lands when the debuff is REMOVED -- the
                -- healer dispels it -- so the whole job is being at the
                -- edge when that happens, not surviving the dot.
                Every(11, 13, 3, {
                    kind = "drop", name = "Essence Rend", school = "spirit",
                    cast = 4.5, away = "centre", minDist = 62, r = 14,
                    permanent = true, dps = 13, damage = 20,
                    call = "Essence Rend -- be at the EDGE when it is dispelled",
                })
            ),
        },
        {
            name = "Intermission -- Ritual of Awakening", untilClear = true,
            -- She walks onto the well to channel, and that channel is
            -- what makes her immune -- so the move and the immunity are
            -- one event the player watches happen rather than a state
            -- they find her already in.
            hpFloor = 55, bossImmune = true, bossAt = "centre",
            -- Anything still on the floor when this ends gets back up.
            raisesCorpses = true,
            call = "Kill both Echoes -- and burn every corpse before it ends",
            events = Timeline(
                -- BOTH Echoes are up together, and both are Echoes of
                -- JAWAE -- she is the caster who appears when Nek'zali
                -- hides in the Soulcoil Well, and the Echoes are hers,
                -- not Nek'zali's. Read off the boss frames in a
                -- screenshot of the pull: two "Echo of Jawae" at once.
                --
                -- Soul Transfer is a FIFTEEN second cast at unlimited
                -- range -- Jawae pours her essence into an Echo, and the
                -- surge at the end catches anyone standing in it. So it
                -- is long, it is unmissable, and the only job is not
                -- being in the blast when it lands.
                { at = 1, kind = "line", name = "Soul Transfer", school = "spirit",
                  where = "centre", cast = 9, width = 26, damage = 30,
                  call = "Soul Transfer -- 15 seconds, then a blast. Be out of it." },
                { at = 2, kind = "caster", name = "Echo of Jawae", school = "spirit",
                  hp = 240, castLen = 16, damage = 32, r = 7, art = "spike",
                  call = "Both Echoes up -- burn them" },
                { at = 3, kind = "caster", name = "Echo of Jawae", school = "spirit",
                  hp = 240, castLen = 18, damage = 32, r = 7, art = "spike" },
                { at = 20, kind = "line", name = "Soul Transfer", school = "spirit",
                  where = "centre", cast = 9, width = 26, damage = 30,
                  call = "Soul Transfer again -- out of the blast" },
                Every(8, 11, 3, {
                    kind = "soak", name = "Hungering Pyre", school = "fire",
                    cast = 3.2, r = 16, damage = 26,
                    -- Soaking marks you Singed; everybody who stays out
                    -- is set alight instead, and the Flames are how the
                    -- corpses get burned. Two jobs, and you alternate
                    -- between them.
                    marks = "Singed", marksFor = 14,
                    onMiss = {
                        kind = "drop", name = "Slithering Flames", school = "fire",
                        cast = 8, minDist = 26, r = 12, life = 10, dps = 12,
                        damage = 20,
                        burns = true,
                        call = "Slithering Flames -- YOURS. Go and burn the corpses.",
                    },
                    call = "Hungering Pyre -- split it, park it on the corpses",
                }),
                -- Everyone who does NOT soak the Pyre gets their own
                -- circle instead. A spread in all but name.
                Every(12, 11, 3, {
                    kind = "spread", name = "Slithering Flame", school = "fire",
                    cast = 3, minDist = 26, damage = 20,
                    call = "Slithering Flame -- if you did not soak, get out",
                }),
                Every(6, 10, 3, {
                    kind = "chaser", name = "Restless Amani", school = "spirit",
                    where = "edge", goal = "centre", speed = 11, hp = 60,
                    art = "hex", damage = 26, feeds = 5, leavesCorpse = true,
                })
            ),
        },
        {
            name = "Phase Two", duration = 44, hpFloor = 0,
            -- The last phase is a race, and three things say so: the
            -- void zones stop being furniture and start travelling, her
            -- energy begins climbing on its own instead of only when an
            -- add gets through, and this is where the raid empties its
            -- cooldowns.
            movingPuddles = true, puddleSpeed = 10,
            energyRate = 2.2,
            bloodlust = true,
            call = "Invoke sets every puddle travelling -- BLOODLUST",
            events = Timeline(
                Every(4, 8, 6, {
                    kind = "dodge", name = "Invoke", school = "spirit",
                    cast = 2.2, r = 15, damage = 24,
                    leaves = { r = 14, life = 14, dps = 12 },
                    call = "Invoke -- the puddles are moving now",
                }),
                Every(7.0, 12, 4, {
                    kind = "projectile", name = "Possession Barrage", school = "spirit",
                    where = "boss", cast = 2.0, fan = -0.22, speed = 58, damage = 20,
                    call = "Possession Barrage -- clear their path",
                }),
                Every(7.0, 12, 4, {
                    kind = "projectile", name = "Possession Barrage", school = "spirit",
                    where = "boss", cast = 2.0, fan = 0.22, speed = 58, damage = 20,
                    call = "Possession Barrage -- clear their path",
                }),
                Every(9, 10, 4, {
                    kind = "chaser", name = "Restless Amani", school = "spirit",
                    where = "edge", goal = "centre", speed = 13, hp = 60,
                    art = "hex", damage = 26, feeds = 5, leavesCorpse = true,
                }),
                Every(14, 15, 2, {
                    kind = "drop", name = "Essence Rend", school = "spirit",
                    cast = 4, away = "centre", minDist = 62, r = 14,
                    permanent = true, dps = 13, damage = 20,
                })
            ),
        },
    },
}

------------------------------------------------------------
-- 2. Entombed Sentinels               encounterID 3445
--
-- Blightburn fires OUT and then BACK, which the earlier version missed
-- entirely: the dodge is two beats, not one. The red side's puddles land
-- under the soakers a few seconds AFTER the soak, which is why the guide
-- says to walk somewhere useless immediately.
------------------------------------------------------------
--- The Breath of Ula'tek's side: droplets that travel, and the blob.
local function BreathSide(name, dur, floor)
    return {
        name = name, duration = dur, hpFloor = floor, side = 2,
        call = "Breath side -- soak every droplet",
        events = Timeline(
            Every(3, 5, 6, {
                kind = "orb", name = "Toxic Droplet", school = "nature",
                window = 12, damage = 20, r = 4, spikes = true,
                call = "Toxic Droplets -- soak them, tanks first",
            }),
            -- The highest damage in the fight, about once a minute, and
            -- it radiates the whole time it lives.
            Every(6, 16, 2, {
                kind = "chaser", name = "Venom Coagulation", school = "nature",
                goal = "player", speed = 9, hp = 130, art = "blob",
                r = 6, damage = 26, life = 18,
                call = "Venom Coagulation -- priority target, every time",
            }),
            Every(11, 13, 3, {
                kind = "line", name = "Empowering Slam", school = "physical",
                where = "boss", cast = 2.2, width = 22, damage = 22,
                call = "Empowering Slam -- out of it, and it ramps",
            })
        ),
    }
end

--- The Blood of Ula'tek's side: soak together, then get to the edge.
local function BloodSide(name, dur, floor)
    return {
        name = name, duration = dur, hpFloor = floor, side = 1,
        call = "Blood side -- soak the Miasma, then move to the edge",
        events = Timeline(
            Every(4, 12, 3, {
                kind = "soak", name = "Unstable Miasma", school = "blood",
                cast = 3.4, r = 16, damage = 24,
                call = "Unstable Miasma -- the whole side soaks",
            }),
            -- "Then get to the edge and stack, because what you just
            -- soaked comes back as puddles under all of you."
            Every(9, 12, 3, {
                kind = "dodge", name = "Clinging Murk", school = "blood",
                cast = 2.2, r = 14, damage = 18,
                leaves = { r = 15, life = 20, dps = 12 },
                call = "Clinging Murk fading -- blood lands under every soaker",
            }),
            Every(7, 11, 3, {
                kind = "drop", name = "Blighted Blood", school = "blood",
                cast = 4, minDist = 26, r = 13, life = 22, dps = 12, damage = 18,
                call = "Blighted Blood -- take the dispel away from the group",
            }),
            Every(6, 7, 4, {
                kind = "orb", name = "Toxic Droplet", school = "nature",
                window = 10, damage = 18, r = 4, spikes = true,
            })
        ),
    }
end

--- Vitriolic Stasis: the number game AND the healing, in one phase.
---
--- These were two separate things here, which was simply wrong -- the
--- bosses going 99% immune, the venom orbs, and the weaker boss being
--- healed back up are one event at maximum energy.
---
--- The orbs are a single count that must SUM TO FOUR with one other
--- player: three looks for one, two looks for two. Not two colours added
--- separately, which is what this used to say.
local function VitriolicStasis(name, floor)
    return {
        -- Thirty seconds in the real fight, and the guide is emphatic
        -- that this is plenty and nobody should panic -- so the cast is
        -- long on purpose here too.
        name = name, duration = 14, bossImmune = true, hpFloor = floor,
        healsWeaker = true,
        call = "Vitriolic Stasis -- your venom orbs plus theirs make FOUR",
        events = {
            -- The guide's own note is that thirty seconds is plenty and
            -- nobody should panic, so the cast is long and the circle is
            -- generous. "The circles only have to touch. Do not try to
            -- pixel-aim it."
            { at = 1, kind = "meet", name = "Vitriolic Stasis", school = "nature",
              cast = 10, labels = true, reach = 14, damage = 30,
              -- Failing the combine is Cultivated Burst: a big hit and a
              -- dot that runs for the next minute.
              onMiss = { kind = "puddle", name = "Cultivated Burst",
                         school = "nature", r = 15, life = 22, dps = 13 } },
        },
    }
end

SC.sentinels = {
    bossId = "sentinels",
    title  = "Entombed Sentinels",
    intro  = "Swap sides at every stasis. Your venom orbs plus theirs make four.",
    bossHp = 5400,

    -- TWO golems, forty yards apart, and they stay apart: the tanks hold
    -- that gap for the whole fight and it is the encounter's first rule.
    -- Neither walks.
    --
    -- The phases below are not the fight changing shape -- they are YOU
    -- changing sides at each intermission, which is what lets your dot
    -- stacks fall off. `side` on a phase says which golem your half of
    -- the raid is standing on.
    bosses = {
        { name = "Blood of Ula'tek",  at = { x = -40, y = 10 },
          colour = { 1.00, 0.35, 0.35 } },
        { name = "Breath of Ula'tek", at = { x = 40,  y = 10 },
          colour = { 0.55, 1.00, 0.50 } },
    },

    -- The bar is not a kill timer. A full bar means Vitriolic Stasis is
    -- due, and the stasis phase is what heals the weaker boss back up --
    -- see `healsWeaker` and the note on VitriolicStasis above.
    energy = { name = "Energy", rate = 3.0, max = 100 },
    evenHealth = { name = "Vitriolic Stasis" },

    -- The other half of the raid, working on the golem you are not
    -- standing on. Their rate is what yours has to match.
    otherTeam = { dps = 20 },

    -- "Standing in the middle to hit both bosses gives you both dots."
    -- The one rule on this fight a single player can obey alone.
    --
    -- The range has to EXCEED half the gap between them or there is no
    -- middle to punish -- at 44 against an 80-unit gap the band where
    -- both reach you was empty, and the mechanic silently did nothing.
    bothDots = { range = 52, dps = 5 },

    phases = {
        BloodSide("Your side: the Blood of Ula'tek", 32, 72),
        VitriolicStasis("Vitriolic Stasis -- swap sides", 72),
        BreathSide("Your side: the Breath of Ula'tek", 32, 42),
        VitriolicStasis("Vitriolic Stasis -- swap sides", 42),
        BloodSide("Your side: the Blood of Ula'tek", 30, 0),
    },
}

------------------------------------------------------------
-- 3. The Lost Explorers               encounterID 3497
--
-- Mor'zaki's bar is the kill timer and the fish is the only thing that
-- resets it -- three times, because you cannot feed the same turtle
-- twice. Icebound Flames is a genuine interrupt, which is what the
-- caster verb was built for.
------------------------------------------------------------
SC.explorers = {
    bossId = "explorers",
    title  = "The Lost Explorers",
    intro  = "Break boxes, feed the fish, survive each empowered turtle.",
    bossHp = 5200,
    energy = { name = "Mor'zaki", rate = 1.5, max = 100 },
    phases = {
        {
            name = "The Three Turtles", duration = 32, hpFloor = 74,
            call = "Break the boxes -- one of them holds the fish",
            events = Timeline(
                Every(2, 4, 8, {
                    kind = "orb", name = "Gebbo's Box", school = "physical",
                    window = 9, damage = 14, r = 4,
                }),
                { at = 9, kind = "carry", name = "Fish", school = "frost",
                  to = "boss", reach = 20, window = 16, damage = 24, drainEnergy = 40,
                  deliverCall = "Feed the fish to a turtle -- it resets Mor'zaki" },
                Every(6, 13, 3, {
                    kind = "caster", name = "Icebound Flames", school = "frost",
                    hp = 120, castLen = 8, damage = 30, r = 5.5, art = "hex",
                    call = "Icebound Flames -- stop the cast",
                }),
                Every(11, 12, 3, {
                    kind = "line", name = "Shell Spin", school = "physical",
                    cast = 1.9, width = 22, damage = 22, aimAtPlayer = true,
                    call = "Shells go where Nama is facing",
                }),
                Every(15, 14, 2, {
                    kind = "spread", name = "Blink Nova", school = "arcane",
                    cast = 3.2, minDist = 30, damage = 22,
                    call = "Blink Nova -- 30 yards out and it is nothing",
                })
            ),
        },
        {
            name = "Scrollsage Iku empowered", duration = 34, hpFloor = 50,
            call = "Frostfire Volley -- clear it in the OPPOSITE puddle",
            events = Timeline(
                -- The real mechanic, at last: you are handed fire or ice
                -- and you clear it by walking into somebody else's
                -- puddle of the other one. The sets are spaced so that
                -- carrying one into the next is possible but not
                -- inevitable -- which is the whole warning.
                -- Clearing is what sets off the explosion, so the raid
                -- staggers. `allyClears` is how many of the other five
                -- take their turn during your window; you have to find a
                -- gap between them.
                Every(4, 13, 3, {
                    kind = "volley", name = "Frostfire Volley",
                    cast = 3.4, carry = 18, life = 26, others = 2,
                    allyClears = 3, stagger = 3.0, explodeDamage = 34,
                    puddleR = 14,
                }),
                Every(5, 13, 2, {
                    kind = "caster", name = "Icebound Flames", school = "frost",
                    hp = 120, castLen = 8, damage = 30, r = 5.5, art = "hex",
                    call = "Icebound Flames -- stop the cast",
                }),
                { at = 24, kind = "carry", name = "Fish", school = "frost",
                  to = "boss", reach = 20, window = 16, damage = 24, drainEnergy = 40 }
            ),
        },
        {
            name = "First Mate Nama empowered", duration = 26, hpFloor = 26,
            call = "Mighty Thud -- three leaps, closest mark first",
            events = Timeline(
                -- Each landing leaves an aftershock, so the soak and the
                -- get-out are one continuous movement rather than two
                -- separate decisions.
                { at = 3,  kind = "soak", name = "Mighty Thud 1", school = "physical", group = 1,
                  cast = 3, r = 15, damage = 22, call = "First leap -- closest mark" },
                { at = 6,  kind = "dodge", name = "Aftershock", school = "physical",
                  cast = 1.6, r = 13, damage = 16,
                  leaves = { r = 13, life = 18, dps = 11 } },
                { at = 8,  kind = "soak", name = "Mighty Thud 2", school = "physical", group = 2,
                  cast = 3, r = 15, damage = 22, call = "Second" },
                { at = 11, kind = "dodge", name = "Aftershock", school = "physical",
                  cast = 1.6, r = 13, damage = 16,
                  leaves = { r = 13, life = 18, dps = 11 } },
                { at = 13, kind = "soak", name = "Mighty Thud 3", school = "physical", group = 3,
                  cast = 3, r = 15, damage = 22, call = "Third" },
                { at = 16, kind = "dodge", name = "Aftershock", school = "physical",
                  cast = 1.6, r = 13, damage = 16,
                  leaves = { r = 13, life = 18, dps = 11 } },
                { at = 19, kind = "carry", name = "Fish", school = "frost",
                  to = "boss", reach = 20, window = 15, damage = 24, drainEnergy = 40 },
                Every(5, 10, 2, {
                    kind = "line", name = "Shell Spin", school = "physical",
                    cast = 1.9, width = 22, damage = 22, aimAtPlayer = true,
                })
            ),
        },
        {
            name = "Trader Gebbo empowered", duration = 28, hpFloor = 0,
            call = "Blast wave -- bounce off a mushroom",
            events = Timeline(
                Every(5, 11, 2, {
                    kind = "refuge", name = "Explosive Surprise", school = "physical",
                    cast = 4.5, count = 5, r = 11, damage = 34, normalOnly = true,
                    call = "Blast wave -- get onto a mushroom",
                }),
                Every(5, 11, 2, {
                    kind = "refuge", name = "Explosive Surprise", school = "physical",
                    cast = 4.5, count = 3, r = 10, damage = 34, heroicOnly = true,
                    call = "Blast wave -- get onto a mushroom",
                }),
                Every(3, 5, 5, {
                    kind = "orb", name = "Gebbo's Box", school = "physical",
                    window = 8, damage = 14, r = 4,
                }),
                Every(9, 11, 2, {
                    kind = "spread", name = "Blink Nova", school = "arcane",
                    cast = 3.2, minDist = 30, damage = 22,
                })
            ),
        },
    },
}

------------------------------------------------------------
-- 4. Vashnik the Malignant            encounterID 3455
--
-- "Every add walks for the green pool in the middle. One arriving dots
-- the whole raid; two arriving is a wipe." That is rule two of three on
-- this boss, and for a long time nothing in this scenario expressed it:
-- there were no adds at all in the timeline, and the ones Imbibe spawned
-- chased the PLAYER, which is a mechanic from a different encounter.
--
-- They walk for the pool now, and every one that arrives feeds Toxic
-- Vapor -- the same shape as Nek'zali's well, because it is the same
-- idea: the bar is a record of what you let through.
--
-- Plague Rot is a spread and THEN waves, eight seconds later: walk out,
-- then dodge.
--
-- THE THREE PHASES BELOW ARE NOT ENCOUNTER PHASES. Vashnik is one phase
-- with three fountains, and the guide says so; its `shape` field reads
-- "1 phase, 3 fountains" and that is correct. These are the guide's own
-- SECTIONS -- the fountains, blood, and whatever is empowered -- used as
-- a teaching order, so a player meets Siphoning Infection on its own
-- instead of buried under two other schools on the first pull.
--
-- The same licence the whole file already takes with time, named here
-- because on this one boss a reader could mistake it for a claim about
-- the fight.
------------------------------------------------------------
SC.vashnik = {
    bossId = "vashnik",
    title  = "Vashnik the Malignant",
    intro  = "Two fountains at a time. Nothing may reach the pool.",
    bossHp = 3600,
    altars = true,
    bossFollowsTank = true,
    well   = true,
    -- Toxic Vapor grows with every drink AND with every add that gets
    -- through. The tick is slow on purpose: leaks are what fill it, and
    -- a bar that filled on its own would say the opposite.
    energy = { name = "Toxic Vapor", rate = 0.35, max = 100 },
    phases = {
        {
            name = "The Three Fountains", duration = 46, hpFloor = 52,
            call = "Imbibe drinks from the two nearest fountains",
            events = Timeline(
                Every(6, 17, 3, {
                    kind = "imbibe", name = "Imbibe", cast = 3.2,
                    call = "Imbibe -- the two nearest fountains empower",
                }),
                Every(9, 19, 3, {
                    kind = "spread", name = "Plague Rot", school = "nature",
                    cast = 4, minDist = 28, damage = 22,
                    call = "Plague Rot -- walk out, the waves follow",
                }),
                Every(17, 19, 3, {
                    kind = "wave", name = "Plague wave", school = "nature",
                    speed = 46, width = 17, damage = 18,
                    call = "Plague waves incoming -- move out of their path",
                }),
                Every(18, 19, 3, {
                    kind = "wave", name = "Plague wave", school = "nature",
                    speed = 46, width = 17, damage = 18,
                    call = "Second wave right behind it",
                }),
                Every(14, 16, 3, {
                    kind = "soak", name = "Malignant Catalyst", school = "shadow",
                    group = 1, cast = 3, r = 12, damage = 24,
                    call = "Malignant Catalyst -- one player per circle",
                }),
                Every(15, 16, 3, {
                    kind = "soak", name = "Malignant Catalyst", school = "shadow",
                    group = 2, cast = 3, r = 12, damage = 24, heroicOnly = true,
                })
            ),
        },
        {
            -- The blood fountain's own phase, because Siphoning
            -- Infection is the one mechanic on this boss that no amount
            -- of healing answers and it deserves to be met on its own
            -- rather than buried under three other schools.
            name = "Blood", duration = 34, hpFloor = 26,
            call = "Infected players walk into the nearest camp",
            events = Timeline(
                Every(4, 12, 3, {
                    kind = "leech", name = "Siphoning Infection", school = "blood",
                    cast = 5, reach = 15, need = 2, damage = 34,
                    call = "Siphoning Infection -- get INSIDE a camp, healing will not fix it",
                }),
                Every(8, 14, 2, {
                    kind = "imbibe", name = "Imbibe", cast = 3.2,
                }),
                Every(10, 15, 2, {
                    kind = "spread", name = "Plague Rot", school = "nature",
                    cast = 4, minDist = 28, damage = 22,
                }),
                Every(18, 15, 2, {
                    kind = "wave", name = "Plague wave", school = "nature",
                    speed = 46, width = 17, damage = 18,
                    call = "Plague wave crossing -- step out of its path",
                }),
                Every(13, 16, 2, {
                    kind = "soak", name = "Malignant Catalyst", school = "shadow",
                    group = 1, cast = 3, r = 12, damage = 24,
                })
            ),
        },
        {
            name = "Whatever is empowered", duration = 38, hpFloor = 0,
            -- Toxic Vapor has been growing with every drink all fight,
            -- and this is where it bites: the rate climbs on its own on
            -- top of whatever the adds have already fed it.
            energyRate = 1.1,
            bloodlust = true,
            call = "The casts never stop now -- BLOODLUST",
            events = Timeline(
                Every(4, 13, 3, {
                    kind = "imbibe", name = "Imbibe", cast = 3.0,
                    call = "Imbibe -- two more fountains live",
                }),
                Every(8, 14, 3, {
                    kind = "spread", name = "Plague Rot", school = "nature",
                    cast = 3.6, minDist = 28, damage = 22,
                    call = "Plague Rot -- walk out, the waves follow",
                }),
                Every(16, 14, 3, {
                    kind = "wave", name = "Plague wave", school = "nature",
                    speed = 48, width = 17, damage = 18,
                    call = "Plague waves incoming -- move out of their path",
                }),
                Every(17, 14, 3, {
                    kind = "wave", name = "Plague wave", school = "nature",
                    speed = 48, width = 17, damage = 18,
                    call = "Second wave right behind it",
                }),
                Every(11, 13, 3, {
                    kind = "leech", name = "Siphoning Infection", school = "blood",
                    cast = 4.5, reach = 15, need = 2, damage = 34,
                }),
                Every(6, 12, 3, {
                    kind = "soak", name = "Malignant Catalyst", school = "shadow",
                    group = 1, cast = 3, r = 12, damage = 24,
                }),
                Every(7, 12, 3, {
                    kind = "soak", name = "Malignant Catalyst", school = "shadow",
                    group = 2, cast = 3, r = 12, damage = 24, heroicOnly = true,
                })
            ),
        },
    },
}

------------------------------------------------------------
-- 5. Sszorak                          encounterID 3420
--
-- Two soak groups alternating on Mutilate, four cysts for three winds,
-- and a pixel stack in the middle for the intermission -- the guide is
-- explicit that being off to one side is what starts the disasters.
------------------------------------------------------------
local function SszorakPhase(dur, floor)
    return {
        name = "Sszorak", duration = dur, hpFloor = floor,
        call = "Apex Predator -- two Ravage, two Mutilate, one Tempest",
        events = Timeline(
            Every(4, 16, 3, {
                kind = "line", name = "Ravage", school = "physical",
                where = "boss", cast = 2, width = 34, damage = 26,
                call = "Ravage -- out of the cone",
            }),
            -- Mutilate ALTERNATES, and until now nothing said so.
            --
            -- "It splits between soakers and leaves +500% from the NEXT
            -- one for 22 seconds -- which is the whole reason for two
            -- groups." That sentence IS the mechanic, and this was a
            -- plain soak on a sixteen-second loop: soaking every single
            -- one of them scored perfectly, which is the play that kills
            -- you on the real boss.
            --
            -- `marks` is the machinery Hungering Pyre already uses. The
            -- duration sits just past the cadence, so being marked costs
            -- exactly the next cast and no more -- that is the
            -- alternation, expressed as something one player can feel.
            -- A CONE, aimed at the raid, that you are meant to be in.
            --
            -- It was a circle to stand in, which threw away the whole
            -- shape of this boss: the two frontals go in opposite
            -- directions and that IS the fight. Ravage is the tank
            -- buster and points away; Mutilate splits between everyone
            -- it hits and is deliberately swung into the raid.
            Every(8, 32, 2, {
                kind = "line", name = "Mutilate", school = "nature",
                where = "boss", cast = 3, width = 30, damage = 24,
                soakIn = true, aimAtPlayer = true,
                marks = "Mutilated", marksFor = 17,
                call = "Mutilate -- the poisonous cone. GET IN IT.",
            }),
            Every(24, 32, 1, {
                kind = "line", name = "Mutilate", school = "nature",
                where = "boss", cast = 3, width = 30, damage = 24,
                soakIn = true, aimAtPlayer = true,
                marks = "Mutilated", marksFor = 17,
                call = "Mutilate -- second group's turn",
            }),
            Every(11, 16, 3, {
                kind = "line", name = "Ravage", school = "physical",
                where = "boss", cast = 2, width = 34, damage = 26,
            }),
            Every(13, 16, 3, {
                kind = "dodge", name = "Tempest", school = "nature",
                cast = 2, r = 12, damage = 18,
                leaves = { r = 13, life = 14, dps = 15 },
                call = "Tempest -- the tornadoes wander, keep looking",
            }),
            -- Venomous Surge and Caustic Claws land together: place the
            -- cyst, and get out of the puddles around the boss.
            -- Venomous Surge is a PLACEMENT, not a run-away. The cyst
            -- goes on the marker across from a tunnel, and which tunnel
            -- is decided by the orb count you were meant to read.
            Every(6, 12, 3, {
                kind = "place", name = "Venomous Surge", school = "nature",
                cast = 5, damage = 24,
                call = "Venomous Surge -- drop it on the marker opposite the tunnel",
            }),
            Every(7, 15, 3, {
                kind = "dodge", name = "Caustic Claws", school = "nature",
                cast = 2.2, r = 13, damage = 18,
                leaves = { r = 13, life = 14, dps = 12 },
            }),
            Every(15, 15, 2, {
                kind = "meet", name = "Raging Crosswinds", school = "frost",
                cast = 5, reach = 9, damage = 26,
                call = "Crosswinds -- pair with the arrow pointing back at you",
            })
        ),
    }
end

SC.sisterrag = {
    bossId = "sisterrag",
    title  = "Sszorak",
    intro  = "Read the tunnel orbs, place a cyst opposite each, then ride them.",
    bossHp = 4600,
    -- Three tunnels on the rim, each showing how many winds go before
    -- it. See KINDS.place and KINDS.wind.
    tunnels = true,
    phases = {
        SszorakPhase(40, 58),
        {
            name = "Intermission -- the winds", duration = 20, bossImmune = true,
            hpFloor = 58,
            call = "Stack in the MIDDLE. Three winds, in the order the orbs showed.",
            events = Timeline(
                { at = 2, kind = "stack", name = "Pixel stack", school = "frost",
                  atCentre = true, cast = 3.5, maxDist = 14, damage = 24,
                  call = "Everybody stacks in the middle" },
                -- Three winds, in the order the orbs showed, each with
                -- exactly one safe place: the cyst across from it.
                { at = 6,  kind = "wind", name = "The Wind", school = "frost",
                  step = 1, cast = 3.5, damage = 36,
                  call = "First wind -- to the cyst opposite the single orb" },
                { at = 11, kind = "wind", name = "The Wind", school = "frost",
                  step = 2, cast = 3.5, damage = 36, call = "Second wind" },
                { at = 16, kind = "wind", name = "The Wind", school = "frost",
                  step = 3, cast = 3.5, damage = 36, call = "Third wind" }
            ),
        },
        SszorakPhase(36, 0),
    },
}

------------------------------------------------------------
-- 6. The Twin Fangs                   encounterID 3421
--
-- Stonebreaker is a SOAK, not a thing to dodge -- the swirly that hits
-- nobody is the heavy raid hit and the knockback. That was backwards
-- before, and it is the correction that matters most on this boss.
------------------------------------------------------------
SC.twinfangs = {
    bossId = "twinfangs",
    title  = "The Twin Fangs",
    intro  = "Everything green is a stack. Ten of them kills you.",
    bossHp = 4600,
    stacks = { name = "Eternal Venom", max = 11, heroicMax = 10 },

    -- Two bosses, two health bars, and they do not share. Neither can be
    -- moved, so neither walks -- the raid spreads loosely wherever it
    -- pulled and stays there.
    --
    -- The twins' own names are the one thing on this fight still resting
    -- on a caption rather than on the client; the guide page carries
    -- that caveat, and it is the reason they are not spelled any more
    -- confidently here than there.
    bosses = {
        { name = "Vexil", at = { x = -38, y = 16 },
          colour = { 0.60, 1.00, 0.45 } },
        { name = "Itras", at = { x = 38,  y = 16 },
          colour = { 1.00, 0.40, 0.45 } },
    },

    -- No `killTogether` here.
    --
    -- "Uncoiled Rot" was recorded on this boss from a source that did
    -- not survive; the enrage-if-one-dies-first rule belongs to the
    -- Coiled Altar, where the guide states it plainly. The Twin Fangs
    -- only ask that you cleave them down together, which the two bars
    -- already say on their own.

    phases = {
        {
            name = "Vexil and Itras", duration = 46, hpFloor = 58,
            call = "Watch the stack count, not your health",
            events = Timeline(
                Every(4, 11, 5, { kind = "tax", name = "Venomous Emergence", stack = 1 }),
                -- The three serpents that spawn with it, firing Corrosive
                -- Spit lines at random players.
                Every(5, 12, 4, {
                    kind = "caster", name = "Coiled Serpent", school = "nature",
                    hp = 100, castLen = 7, damage = 24, r = 5, art = "blob",
                    call = "Serpents up -- kill them before the lines land",
                }),
                Every(8, 12, 4, {
                    kind = "line", name = "Corrosive Spit", school = "nature",
                    where = "centre", cast = 2, width = 18, damage = 16, stack = 1,
                    call = "Corrosive Spit -- the target stands STILL",
                }),
                Every(6, 7, 6, {
                    kind = "orb", name = "Caustic Globule", school = "nature",
                    window = 9, damage = 18, stack = 1, r = 4.5,
                }),
                Every(11, 14, 3, {
                    kind = "soak", name = "Stonebreaker", school = "physical",
                    soakBy = "tank", cast = 2.6, r = 13, damage = 30,
                    call = "Stonebreaker -- SOAK it. An empty one hits everyone.",
                }),
                Every(13, 14, 3, {
                    kind = "soak", name = "Stonebreaker", school = "physical",
                    soakBy = "tank", cast = 2.6, r = 13, damage = 30,
                }),
                Every(16, 16, 2, {
                    kind = "drop", name = "Coiling Ichor", school = "blood",
                    cast = 5, minDist = 26, r = 12, life = 18, dps = 12, damage = 20,
                    call = "Coiling Ichor -- take it to the side of the room",
                }),
                -- The Depths carries no stacks itself; the green waves
                -- that follow it do.
                Every(20, 18, 2, {
                    kind = "wave", name = "The Depths", school = "nature",
                    speed = 46, width = 17, damage = 12, stack = 1,
                    call = "The Depths -- the green wave carries a stack",
                })
            ),
        },
        {
            name = "Ravenous Feast", duration = 18, hpFloor = 58,
            call = "Three pops -- soak ONE of them",
            events = Timeline(
                -- "Soaking leaves +800% damage from it for 8 seconds, so
                -- you take ONE pop and get out."
                --
                -- Without the mark this was three free stack-clears in a
                -- row: standing still through all of them cleared six
                -- stacks and scored three passes, which is the single
                -- most lethal thing a player can do on this boss and the
                -- trainer rewarded it. The mark runs past the third pop,
                -- so soaking any one of them sits you out of the rest.
                { at = 2,  kind = "soak", name = "Ravenous Feast 1", school = "blood", group = 1,
                  cast = 3, r = 16, damage = 20, clears = 1,
                  marks = "Gorged", marksFor = 9, call = "First pop -- soak ONE of the three" },
                { at = 6,  kind = "soak", name = "Ravenous Feast 2", school = "blood", group = 2,
                  cast = 3, r = 16, damage = 20, clears = 1,
                  marks = "Gorged", marksFor = 9, call = "Second pop" },
                { at = 10, kind = "soak", name = "Ravenous Feast 3", school = "blood", group = 3,
                  cast = 3, r = 16, damage = 20, clears = 1,
                  marks = "Gorged", marksFor = 9, call = "Third pop" },
                -- The stacks you cleared come back as a slime add.
                { at = 13, kind = "chaser", name = "Reclaimed Slime", school = "nature",
                  goal = "player", speed = 10, hp = 130, art = "blob", r = 6.5,
                  damage = 24, life = 14,
                  call = "The cleared stacks came back -- focus it" }
            ),
        },
        {
            name = "Intermission -- Wild Flood", duration = 32, hpFloor = 0,
            call = "Run against the spin, cross once, stay in that lane",
            events = Timeline(
                { at = 3, kind = "beam", name = "Wild Flood", school = "nature",
                  where = "boss", spin = 0.8, life = 14, dps = 26, width = 22,
                  call = "Wild Flood -- run AGAINST the spin, cross it once" },
                Every(5, 6, 5, {
                    kind = "dodge", name = "Sanguine Storm", school = "blood",
                    cast = 2, r = 12, damage = 18,
                }),
                Every(20, 5, 3, {
                    kind = "soak", name = "Ravenous Feast", school = "blood",
                    cast = 3, r = 16, damage = 20, clears = 1,
                    marks = "Gorged", marksFor = 9,
                }),
                Every(8, 8, 3, {
                    kind = "orb", name = "Caustic Globule", school = "nature",
                    window = 9, damage = 18, stack = 1, r = 4.5,
                }),
                Every(4, 9, 4, {
                    kind = "tax", name = "Venomous Emergence", stack = 1,
                })
            ),
        },
    },
}

------------------------------------------------------------
-- 7. The Coiled Altar                 encounterID 3429
--
-- The one fight here with no per-boss guide behind it, only the all-boss
-- preview -- so it is the one most likely to need correcting later.
------------------------------------------------------------
SC.alteredfangs = {
    bossId = "alteredfangs",
    title  = "The Coiled Altar",
    intro  = "Zul'jin, then the Hex Lord, then both. Hold still to freeze a spirit.",
    bossHp = 5600,

    -- Two bosses, and the last phase has both up at once. "If either
    -- boss dies early before the other, it enrages them and increases
    -- their damage by 100%" -- so the kill-together rule lives HERE. It
    -- was recorded on the Twin Fangs, which is the wrong boss.
    bosses = {
        { name = "Zul'jin",   at = { x = -34, y = 12 },
          colour = { 1.00, 0.55, 0.30 } },
        { name = "Malacrass", at = { x = 34,  y = 12 },
          colour = { 0.80, 0.45, 1.00 } },
    },
    killTogether = { gainPct = 100, every = 4, dps = 1.8 },

    phases = {
        {
            name = "Phase One -- Zul'jin", untilPct = 58, hpFloor = 58, duration = 38,
            -- The two things this phase is judged on, both at its very
            -- end: what is still lying on the floor, and where he was
            -- standing when he went down.
            -- `recordsDeathSpot` is gone. "Zul'jin is resurrected exactly
            -- where he died" came from a source that did not survive
            -- scrutiny, and no guide says it -- Malacrass binds with him
            -- and heals him where he already is.
            orbsExplode = true, orbDamage = 8,
            side = 1,
            call = "Clear the orbs -- every one still alive explodes at the push",
            events = Timeline(
                -- "Run over an orb to pick it up... carry them into a
                -- pile and let the tank clear several with one cone."
                -- The drop zone is in FRONT of the boss and moves as it
                -- turns, so the job is tracking where the cone will be.
                --
                -- They LINGER: an uncollected orb is not a miss on its
                -- own, it is one more in the pile that goes off at the
                -- push. And destroying them stacks a dot, so they come
                -- in batches -- clearing eight in six seconds is its own
                -- way to wipe.
                Every(3, 6, 6, {
                    kind = "carry", name = "Venom Orb", school = "nature",
                    to = "front", frontDist = 34, reach = 16,
                    lingers = true, rot = true, rotSafe = 2, rotFor = 7,
                    rotDamage = 9, damage = 18,
                    deliverCall = "Carry it in front of the boss, into the cone's path",
                }),
                Every(5, 9, 4, {
                    kind = "line", name = "Zul'jin's Frontal", school = "physical",
                    where = "boss", cast = 1.9, width = 26, damage = 22,
                    call = "The frontal clears whatever is piled in front of him",
                }),
                -- Soak it, then run from the blast: two beats, as the
                -- guide describes.
                Every(10, 14, 2, {
                    kind = "soak", name = "Guillotine", school = "physical",
                    cast = 3.4, r = 17, damage = 26,
                    call = "Guillotine -- soak, then run from the blast",
                }),
                Every(13, 14, 2, {
                    kind = "dodge", name = "Guillotine blast", school = "physical",
                    cast = 2, r = 22, damage = 24,
                }),
                Every(7, 8, 4, {
                    kind = "wave", name = "Axe Grinder", school = "physical",
                    speed = 52, width = 13, damage = 12,
                    call = "Axe Grinder -- a spinning axe crossing the room, step aside",
                })
            ),
        },
        {
            name = "Phase Two -- Hex Lord Malacrass", duration = 46, hpFloor = 26,
            side = 2,
            call = "Stop moving to freeze a spirit",
            events = Timeline(
                Every(4, 13, 3, {
                    kind = "stalker", name = "Manifestation", school = "shadow",
                    speed = 14, r = 5, holdTime = 2.0, life = 15, damage = 32, hp = 80,
                    call = "Manifestation -- STOP MOVING to freeze it",
                }),
                Every(8, 13, 3, {
                    kind = "stalker", name = "Manifestation", school = "shadow",
                    speed = 13, r = 5, holdTime = 2.0, life = 15, damage = 32,
                    hp = 80, heroicOnly = true,
                }),
                Every(6, 14, 3, {
                    kind = "caster", name = "Soul Boiler", school = "shadow",
                    hp = 130, castLen = 9, damage = 32, r = 5.5, art = "blob",
                    heroicOnly = true,
                    call = "Soul Boiler -- stop the cast",
                }),
                Every(11, 12, 3, {
                    kind = "drop", name = "Gloom Bomb", school = "shadow",
                    cast = 4, minDist = 26, r = 12, life = 12, dps = 12, damage = 20,
                    call = "Gloom Bomb -- out, then collect your three spirits",
                }),
                -- The three spirits it leaves, in a triangle, on a short
                -- fuse. Miss one and you die.
                Every(16.0, 12, 3, {
                    kind = "orb", name = "Gloom spirit", school = "shadow",
                    window = 6, damage = 20, r = 4,
                }),
                Every(16.2, 12, 3, {
                    kind = "orb", name = "Gloom spirit", school = "shadow",
                    window = 6, damage = 20, r = 4,
                }),
                Every(16.4, 12, 3, {
                    kind = "orb", name = "Gloom spirit", school = "shadow",
                    window = 6, damage = 20, r = 4,
                }),
                Every(9, 12, 3, {
                    kind = "line", name = "Hex Lord's Frontal", school = "shadow",
                    where = "boss", cast = 2, width = 24, damage = 22,
                }),
                Every(18, 18, 2, {
                    kind = "caster", name = "Eternal Nightfall", school = "shadow",
                    hp = 220, castLen = 11, damage = 40, r = 8, art = "spike",
                    where = "boss",
                    call = "Break the shield, THEN kick the cast",
                })
            ),
        },
        {
            name = "Intermission -- the burn", duration = 20, bossImmune = true,
            hpFloor = 26,
            -- He is standing exactly where he died, which the player
            -- chose. That is what makes rule three ("kill him in the
            -- MIDDLE") worth obeying: a Zul'jin resurrected against the
            -- wall gives the drifting spirits a short run and the goalie
            -- a long one.
            -- Malacrass binds with Zul'jin and heals him where he
            -- stands, and Zul'jin takes 100% more damage while it runs.
            -- Thirty seconds, and the guide is explicit that this is the
            -- Bloodlust window.
            side = 1,
            bloodlust = true,
            call = "Play goalie -- spirits reaching Zul'jin heal him. BLOODLUST.",
            events = Timeline(
                -- Goalie duty, using the chaser's goal-reached branch for
                -- something that is not a wipe: these heal the boss, and
                -- standing in the way is the whole job.
                Every(2, 4, 5, {
                    kind = "chaser", name = "Drifting Spirit", school = "shadow",
                    where = "edge", goal = "boss", speed = 10, hp = 70,
                    art = "blob", damage = 22, intercept = true,
                    call = "Body-block it -- do not let it reach him",
                }),
                { at = 6, kind = "stack", name = "Healing cooldowns", school = "holy",
                  cast = 4, maxDist = 15, damage = 20,
                  call = "Stack up for the healing" }
            ),
        },
        {
            name = "Phase Three -- both at once", duration = 34, hpFloor = 0,
            -- Same judgement as phase one, and the guide is blunt that
            -- this is the hardest thing in the raid with almost no room
            -- to do any of it.
            orbsExplode = true, orbDamage = 8,
            call = "Orbs onto the spirit pile. One cone, both problems.",
            events = Timeline(
                -- Phase three wants the orbs on the SAME spot the
                -- spirits are frozen: one cone, both problems.
                Every(3, 6, 5, {
                    kind = "carry", name = "Venom Orb", school = "nature",
                    to = "front", frontDist = 34, reach = 16,
                    lingers = true, rot = true, rotSafe = 2, rotFor = 7,
                    rotDamage = 9, damage = 18,
                    deliverCall = "Orbs onto the spirit pile -- in front of the boss",
                }),
                Every(5, 10, 3, {
                    kind = "line", name = "Zul'jin's Frontal", school = "physical",
                    where = "boss", cast = 1.9, width = 26, damage = 22,
                }),
                Every(8, 12, 2, {
                    kind = "stalker", name = "Manifestation", school = "shadow",
                    speed = 14, r = 5, holdTime = 2.0, life = 14, damage = 32, hp = 80,
                }),
                Every(12, 13, 2, {
                    kind = "soak", name = "Guillotine", school = "physical",
                    group = 2, cast = 3.4, r = 17, damage = 26, heroicOnly = true,
                }),
                Every(15, 13, 2, {
                    kind = "drop", name = "Gloom Bomb", school = "shadow",
                    cast = 4, minDist = 26, r = 12, life = 12, dps = 12,
                    damage = 20, heroicOnly = true,
                }),
                Every(19, 15, 2, {
                    kind = "caster", name = "Eternal Nightfall", school = "shadow",
                    hp = 200, castLen = 10, damage = 40, r = 8, art = "spike",
                    where = "boss",
                })
            ),
        },
    },
}

------------------------------------------------------------
-- The Tidebound Grotto
------------------------------------------------------------
-- 8. Nymrissa Wavecaller                journal 2849
--
-- A Lair rather than a raid boss, and ONE PHASE ON A LOOP -- the guide
-- says so and nothing here should pretend otherwise. The three phases
-- below are three turns of the same cycle, named as such: Frost Barrage,
-- then the Rain, then the murlocs, then the whirlpools, then again
-- harder. That is a real repetition, not invented structure.
--
-- No combat-log encounterID is recorded for her anywhere on this
-- machine, so the guide carries none and neither does this.
--
-- DELIBERATELY ABSENT, by the rule at the top of this file:
--   * Ice Blade Flurry. Six slashes ramping 45% each is a tank swap, and
--     a lone dot in an arena cannot practise a taunt.
--   * Unending Tides / Drenched. A permanent raid-wide dot is a healer's
--     problem and unavoidable by construction, and this file does not
--     ship damage the player cannot answer.
--   * Water Jet clearing frozen ground, which is mythic and is also the
--     tank's tool rather than yours.
------------------------------------------------------------
local function GrottoCycle(name, dur, floor, opts)
    opts = opts or {}
    return {
        name = name, duration = dur, hpFloor = floor,
        bloodlust = opts.bloodlust,
        call = opts.call or "Soak every orb. Nothing reaches the bubble.",
        events = Timeline(
            -- Frost Barrage. The orbs are the fight: one left to shatter
            -- is enormous raid damage, so they are worth more than
            -- anything else you could be doing.
            Every(3, 4, opts.orbs or 5, {
                kind = "orb", name = "Frost Orb", school = "frost",
                window = 9, damage = 30, r = 5,
                call = "Frost Barrage -- soak every orb, none may shatter",
            }),
            -- Abyssal Rain. Modelled as the thing the raid DOES about it
            -- -- stack up and eat it together -- rather than as chip
            -- damage nobody can answer.
            Every(11, opts.rainEvery or 19, opts.rains or 2, {
                kind = "stack", name = "Abyssal Rain", school = "frost",
                cast = 3.4, maxDist = 15, damage = 26,
                call = "Abyssal Rain -- stack up for it",
            }),
            -- The murlocs, dragged in from the edges toward the bubble.
            -- One that arrives becomes a berserker and pulses until it
            -- dies, which is what `becomes` is for.
            Pack(7, opts.packEvery or 15, opts.packs or 2, 3, {
                kind = "chaser", name = "Murloc", school = "frost",
                where = "edge", goal = "centre", speed = 10, hp = 62,
                art = "hex", damage = 24,
                becomes = {
                    kind = "caster", name = "Berserker", school = "frost",
                    hp = 150, castLen = 12, damage = 30, r = 6, art = "blob",
                    call = "A murloc got through -- kill the Berserker",
                },
                call = "Murlocs incoming -- hold them off the bubble",
            }),
            -- Bubblefin Frostscale: its shield gives every murloc near it
            -- 99% damage reduction, so it is the priority target and
            -- nothing else matters while it lives.
            Every(20, 22, opts.frostscales or 1, {
                kind = "caster", name = "Bubblefin Frostscale", school = "frost",
                hp = 170, castLen = 11, damage = 28, r = 6, art = "spike",
                heroicOnly = true,
                call = "Bubblefin Frostscale -- kill it or the pack is immune",
            }),
            -- Swirling Whirlpools. Dragged in from the rim, and the safe
            -- ground is the stretch of shore they are NOT coming from.
            Every(opts.whirlAt or 28, 26, opts.whirls or 1, {
                kind = "refuge", name = "Swirling Whirlpools", school = "frost",
                cast = 5, count = 3, r = 12, damage = 38, atRim = true,
                call = "Whirlpools -- get to the calm stretch of shore",
            })
        ),
    }
end

SC.nymrissa = {
    bossId = "nymrissa",
    title  = "Nymrissa Wavecaller",
    intro  = "Soak every frost orb. Nothing reaches the bubble.",
    bossHp = 4200,
    -- The Alluring Bubble sits in the middle and the murlocs walk at it,
    -- which is the same shape as Nek'zali's well and reuses it.
    well   = true,
    wellName = "The Alluring Bubble",
    phases = {
        GrottoCycle("First cycle", 40, 62),
        GrottoCycle("Second cycle", 40, 28, {
            orbs = 6, packs = 2, packEvery = 13, whirls = 2, whirlAt = 22,
        }),
        GrottoCycle("Third cycle", 38, 0, {
            orbs = 7, packs = 3, packEvery = 12, rains = 3, rainEvery = 14,
            whirls = 2, whirlAt = 20, frostscales = 2, bloodlust = true,
            call = "Everything at once now -- BLOODLUST",
        }),
    },
}
