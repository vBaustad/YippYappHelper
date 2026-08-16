local _, ns = ...

------------------------------------------------------------
-- Mythic+ Utility Advisor
-- Shows per-dungeon utility advice with spell icons filtered
-- to the player's class and spec. Hover any icon for a
-- full tooltip.
--
-- Data model (DUNGEONS[instanceMapID]):
--   header, lead, description,
--   byClass = { CLASS = { spellID | { id=, talent=, note= }, ... } },
--   bySpec  = { [specID] = { ... } }          -- merged on top of byClass
--
-- Data sourced from MythicPlusUtility's tag-matching model:
-- each class's utility toolkit matched against the utility
-- tags tracked for every dungeon mechanic.
------------------------------------------------------------

ns.UtilityAdvisor = ns.UtilityAdvisor or {}
local UA = ns.UtilityAdvisor

------------------------------------------------------------
-- Data
------------------------------------------------------------

UA.DUNGEONS = {
    -- =====================================================
    [2526] = { -- Algeth'ar Academy
        header      = "Algeth'ar Academy",
        lead        = "Caster-heavy: interrupt Monotonous Lecture, dispel enrages, cleanse poisons/bleeds.",
        description = "Raging Screech (pre-Peacock) and Agitation need enrage removal — Soothe, Tranquilizing Shot, or Shiv. Lasher Toxin on Overgrown Ancient is a magic-categorized poison dispel. Branch Out/Peck/Vile Bite drop stacking bleeds. Power Vacuum (last boss) is mitigated by jumping or movement-immunity. Monotonous Lecture casters want interrupt or hard CC (stun/incap/grip).",
        byClass = {
            DEATHKNIGHT = {
                47528,                                                                     -- Mind Freeze
                221562,                                                                    -- Asphyxiate
                49576,                                                                     -- Death Grip
                48265,                                                                     -- Death's Advance
                { id = 207167, talent = true, note = "AoE incap — lock down Lecture casters" }, -- Blinding Sleet
            },
            DEMONHUNTER = {
                183752,                                                                    -- Disrupt
                { id = 179057, talent = true, note = "Havoc/Veng — AoE stun on caster packs" }, -- Chaos Nova
                207684,                                                                    -- Sigil of Misery
                217832,                                                                    -- Imprison
                131347,                                                                    -- Glide (Power Vacuum)
            },
            DRUID = {
                106839,                                                                    -- Skull Bash
                { id = 2908, talent = true, note = "Critical — removes Raging Screech / Agitation enrage" }, -- Soothe
                { id = 2782, talent = true, note = "Cleanse Lasher Toxin poison" }, -- Remove Corruption
                22570,                                                                     -- Maim
                { id = 132469, talent = true, note = "Knock Lecture casters out of range" }, -- Typhoon
                99,                                                                        -- Incapacitating Roar
            },
            EVOKER = {
                351338,                                                                    -- Quell
                { id = 374346, talent = true, note = "Removes Raging Screech enrage" },    -- Overawe
                374251,                                                                    -- Cauterizing Flame (bleeds + poisons)
                368970,                                                                    -- Tail Swipe
                357214,                                                                    -- Wing Buffet
                360806,                                                                    -- Sleep Walk (CC)
            },
            HUNTER = {
                147362,                                                                    -- Counter Shot
                { id = 19801, talent = true, note = "Removes Raging Screech enrage and purges magic" }, -- Tranquilizing Shot
                187650,                                                                    -- Freezing Trap (CC Lecture caster)
                109248,                                                                    -- Binding Shot
                5384,                                                                      -- Feign Death (Vicious Ambush)
            },
            MAGE = {
                2139,                                                                      -- Counterspell
                118,                                                                       -- Polymorph
                122,                                                                       -- Frost Nova
                { id = 113724, talent = true, note = "AoE incap — shut down Lecture casters" }, -- Ring of Frost
                { id = 31661, talent = true, note = "Incap + interrupt combo" },           -- Dragon's Breath
                110959,                                                                    -- Greater Invisibility (Vicious Ambush dodge)
            },
            MONK = {
                116705,                                                                    -- Spear Hand Strike
                115078,                                                                    -- Paralysis
                119381,                                                                    -- Leg Sweep
                { id = 450432, talent = true, note = "Pressure Points — dispel Raging Screech enrage" },
                { id = 218164, talent = true, note = "Cleanse Lasher Toxin poison" }, -- Detox (Brew/WW)
                116841,                                                                    -- Tiger's Lust (free Plungegrip-style roots later, AA no-op)
            },
            PALADIN = {
                96231,                                                                     -- Rebuke
                853,                                                                       -- Hammer of Justice
                { id = 115750, talent = true, note = "AoE incap on caster pulls" },        -- Blinding Light
                { id = 1022, talent = true, note = "BoP removes Branch Out bleed" },
                { id = 1044, talent = true, note = "Freedom — ignore Vicious Ambush root effects" },
                642,                                                                       -- Divine Shield (clears sleep, etc.)
            },
            PRIEST = {
                { id = 15487, talent = true, note = "Shadow — Silence for Lecture caster" }, -- Silence
                32375,                                                                     -- Mass Dispel (baseline magic purge)
                528,                                                                       -- Dispel Magic
                8122,                                                                      -- Psychic Scream (trash panic)
                { id = 9484, talent = true, note = "Niche — Shackle on add pulls" },       -- Shackle
            },
            ROGUE = {
                1766,                                                                      -- Kick
                408,                                                                       -- Kidney Shot
                2094,                                                                      -- Blind
                31224,                                                                     -- Cloak of Shadows
                1856,                                                                      -- Vanish
                { id = 5938, talent = true, note = "Dispel Raging Screech enrage" },       -- Shiv
            },
            SHAMAN = {
                57994,                                                                     -- Wind Shear
                192058,                                                                    -- Capacitor Totem
                { id = 383013, talent = true, note = "AoE cleanse Lasher Toxin" },        -- Poison Cleansing Totem
                { id = 8143, talent = true, note = "Removes Monotonous Lecture sleep" }, -- Tremor Totem
                51514,                                                                     -- Hex
                192063,                                                                    -- Gust of Wind (Power Vacuum)
            },
            WARLOCK = {
                19647,                                                                     -- Spell Lock (pet)
                30283,                                                                     -- Shadowfury
                6789,                                                                      -- Mortal Coil
                5782,                                                                      -- Fear
                6358,                                                                      -- Seduction (Succubus, on Lecture pack)
            },
            WARRIOR = {
                6552,                                                                      -- Pummel
                107570,                                                                    -- Storm Bolt
                46968,                                                                     -- Shockwave
                18499,                                                                     -- Berserker Rage (self-clears Lecture sleep)
                6544,                                                                      -- Heroic Leap (Power Vacuum)
            },
        },
        bySpec = {
            [250] = { { id = 108199, talent = true, note = "Blood — grip Lecture casters into cleave" } }, -- Gorefiend's Grasp
            [252] = { { id = 1263569, talent = true, note = "Unholy — Abomination Limb gripping utility" } },
            [105] = { { id = 392378, talent = true, note = "Resto — Improved Nature's Cure adds magic" } },
        },
    },

    -- =====================================================
    [2811] = { -- Magisters' Terrace
        header      = "Magisters' Terrace",
        lead        = "Heavy purge/dispel dungeon. Interrupt hard; break LoS on Terror Wave.",
        description = "Arcane Blades and Priest of Rukhmar's Power Word: Shield must be purged — every pull. Hastening Ward on Vexallus is a required purge. Ethereal Shackles (boss1) and Entropy Orb (boss3) leave magic-categorized roots/snares. Terror Wave is an interruptible fear with an LoS option. Consuming Shadows applies Mortal Wounds — use a healing-reduction ability to pressure the caster.",
        byClass = {
            DEATHKNIGHT = {
                47528,                                                                     -- Mind Freeze
                221562,                                                                    -- Asphyxiate
                49576,                                                                     -- Death Grip
                48792,                                                                     -- Icebound Fortitude (fear immunity)
                49039,                                                                     -- Lichborne (self-cleanse fear)
            },
            DEMONHUNTER = {
                183752,                                                                    -- Disrupt
                { id = 278326, talent = true, note = "Core purge — Arcane Blades / PW:Shield" }, -- Consume Magic
                179057,                                                                    -- Chaos Nova
                207684,                                                                    -- Sigil of Misery (fear pack)
                217832,                                                                    -- Imprison
            },
            DRUID = {
                106839,                                                                    -- Skull Bash
                22570,                                                                     -- Maim
                { id = 2782, talent = true, note = "Removes Ethereal Shackles root (magic)" }, -- Remove Corruption (non-Resto has no magic; keep for Resto path)
                339,                                                                       -- Entangling Roots
                { id = 132469, talent = true, note = "Typhoon interrupt/knockback" },
            },
            EVOKER = {
                351338,                                                                    -- Quell
                { id = 374251, talent = true, note = "Useful multi-cleanse" },             -- Cauterizing Flame
                368970,                                                                    -- Tail Swipe
                357214,                                                                    -- Wing Buffet
                358385,                                                                    -- Landslide
            },
            HUNTER = {
                147362,                                                                    -- Counter Shot
                { id = 19801, talent = true, note = "Purge — great into Arcane Blades" },  -- Tranquilizing Shot
                187650,                                                                    -- Freezing Trap
                109248,                                                                    -- Binding Shot
                5384,                                                                      -- Feign Death
            },
            MAGE = {
                2139,                                                                      -- Counterspell
                { id = 30449, talent = true, note = "Spellsteal Hastening Ward / PW:Shield" }, -- Spellsteal
                475,                                                                       -- Remove Curse (generic magic utility)
                118,                                                                       -- Polymorph
                122,                                                                       -- Frost Nova
                110959,                                                                    -- Greater Invisibility
            },
            MONK = {
                116705,                                                                    -- Spear Hand Strike
                115078,                                                                    -- Paralysis
                119381,                                                                    -- Leg Sweep
                116841,                                                                    -- Tiger's Lust (break Ethereal Shackles root)
                { id = 218164, talent = true, note = "Detox — various poison/disease" },
            },
            PALADIN = {
                96231,                                                                     -- Rebuke
                853,                                                                       -- Hammer of Justice
                { id = 1044, talent = true, note = "BoF — break Shackles/Entropy root" },
                { id = 115750, talent = true, note = "Blinding Light on caster packs" },
                642,                                                                       -- Divine Shield (self-cleanse fear)
            },
            PRIEST = {
                { id = 15487, talent = true, note = "Shadow interrupt" },                  -- Silence
                { id = 528 },                                                              -- Dispel Magic — primary purge tool
                32375,                                                                     -- Mass Dispel (AoE purge)
                8122,                                                                      -- Psychic Scream
            },
            ROGUE = {
                1766,                                                                      -- Kick
                408,                                                                       -- Kidney Shot
                2094,                                                                      -- Blind (Terror Wave self-save)
                31224,                                                                     -- Cloak of Shadows (clears fear / magic debuffs)
                1856,                                                                      -- Vanish
                8679,                                                                      -- Wound Poison (Consuming Shadows caster)
            },
            SHAMAN = {
                57994,                                                                     -- Wind Shear
                { id = 370, talent = true, note = "Core purge for Arcane Blades / Wards" }, -- Purge
                192058,                                                                    -- Capacitor Totem
                { id = 8143, talent = true, note = "Removes Terror Wave fear" },           -- Tremor Totem
                51514,                                                                     -- Hex
                58875,                                                                     -- Spirit Walk (break Shackles)
            },
            WARLOCK = {
                19647,                                                                     -- Spell Lock (pet)
                { id = 19505, talent = true, note = "Devour Magic purges Arcane Blades" },
                30283,                                                                     -- Shadowfury
                6789,                                                                      -- Mortal Coil
                5782,                                                                      -- Fear
            },
            WARRIOR = {
                6552,                                                                      -- Pummel
                107570,                                                                    -- Storm Bolt
                46968,                                                                     -- Shockwave
                18499,                                                                     -- Berserker Rage (clears Terror Wave fear)
                { id = 384100, talent = true, note = "Berserker Shout — AoE fear dispel" },
                { id = 12294, talent = true, note = "Arms — Mortal Strike on Consuming Shadows" },
            },
        },
        bySpec = {
            [66] = { { id = 204018, note = "Prot — BoSW immunes magic debuffs" } },      -- Blessing of Spellwarding
            [105] = { { id = 392378, talent = true, note = "Resto — Nature's Cure clears Ethereal Shackles" } },
            [264] = { { id = 370, note = "Resto Shaman — Purge spam every pull" } },
        },
    },

    -- =====================================================
    [2874] = { -- Maisara Caverns
        header      = "Maisara Caverns",
        lead        = "Remove snares/roots constantly. Purge Grim Ward. Dispel Blood Frenzy enrage.",
        description = "Cries of the Fallen, Frost Nova, and especially Ritual Sacrifice (super important) lock players in place — bring movement freedom. Open Wound and Rending Gore stack heavy bleeds. Grim Ward is a major purge. Blood Frenzy is a removable enrage. Reanimation needs a stun/incap/grip before it resolves. Regeneratin' demands Mortal Wounds pressure. Infected Pinions applies removable disease.",
        byClass = {
            DEATHKNIGHT = {
                47528, 221562, 49576, 48265,
                { id = 207167, talent = true, note = "AoE incap on Reanimation pulls" },
            },
            DEMONHUNTER = {
                183752, 179057, 207684, 217832, 198793,                                    -- Vengeful Retreat (self snare)
            },
            DRUID = {
                106839, 22570,
                { id = 2908, talent = true, note = "Critical — dispel Blood Frenzy enrage" },
                { id = 2782, talent = true, note = "Dispel Infected Pinions disease" },
                768,                                                                       -- Cat Form (break snares)
                { id = 99, talent = true, note = "AoE incap on Reanimation packs" },
            },
            EVOKER = {
                351338,
                { id = 374251, talent = true, note = "Cauterizing Flame — bleed + disease in one" },
                { id = 374346, talent = true, note = "Overawe removes Blood Frenzy enrage" },
                357214, 368970,
                357210,                                                                    -- Deep Breath (movement immune)
            },
            HUNTER = {
                147362,
                { id = 19801, talent = true, note = "Core — removes Blood Frenzy enrage" },
                187650, 109248, 5384,
                { id = 459517, talent = true, note = "Self-cleanse disease/poison" },
            },
            MAGE = {
                2139, 118, 122,
                { id = 113724, talent = true, note = "Incap Reanimation packs" },
                45438,                                                                     -- Ice Block (clears bleeds)
                110959,
            },
            MONK = {
                116705, 115078, 119381,
                116841,                                                                    -- Tiger's Lust (core — ignore snares)
                { id = 450432, talent = true, note = "Pressure Points — Blood Frenzy dispel" },
                { id = 218164, talent = true, note = "Detox Infected Pinions" },
            },
            PALADIN = {
                96231, 853,
                { id = 1044, talent = true, note = "BoF — ignore Ritual Sacrifice / Frost Nova" },
                { id = 1022, talent = true, note = "BoP clears Open Wound bleed" },
                { id = 213644, talent = true, note = "Cleanse Toxins — Infected Pinions" },
                115750,
            },
            PRIEST = {
                { id = 15487, talent = true, note = "Shadow interrupt" },
                528, 32375, 8122,
                1250691,                                                                   -- Void Tendrils (root Reanimation)
                { id = 213634, talent = true, note = "Shadow — Purify Disease" },
            },
            ROGUE = {
                1766, 408, 2094, 31224, 1856,
                { id = 5938, talent = true, note = "Shiv removes Blood Frenzy enrage" },
                8679,                                                                      -- Wound Poison vs Regeneratin' caster
            },
            SHAMAN = {
                57994, 192058,
                { id = 462817, talent = true, note = "Jet Stream / Wind Rush for Ritual Sacrifice escape" },
                { id = 8143, talent = true, note = "Utility — passive fear/sleep cleanse" },
                51514, 58875,                                                              -- Spirit Walk
            },
            WARLOCK = {
                19647, 30283, 6789, 5782, 6358,
                268358,                                                                    -- Demonic Circle (teleport out of Ritual Sacrifice)
            },
            WARRIOR = {
                6552, 107570, 46968, 18499, 6544,
                { id = 12323, talent = true, note = "Piercing Howl on Reanimation pulls" },
                { id = 12294, talent = true, note = "Arms — Mortal Strike on Regeneratin' caster" },
            },
        },
        bySpec = {
            [105] = { { id = 392378, talent = true, note = "Resto Druid — Nature's Cure" } },
            [65]  = { { id = 393024, talent = true, note = "Holy — Improved Cleanse dispels Infected Pinions" } },
            [264] = { { id = 383016, talent = true, note = "Resto Shaman — Improved Purify Spirit" } },
            [270] = { { id = 107428, note = "MW — Rising Sun Kick applies Mortal Wounds" } },
        },
    },

    -- =====================================================
    [2915] = { -- Nexus-Point Xenas
        header      = "Nexus-Point Xenas",
        lead        = "Suppression Field is the defining mechanic — bring snare removals or Wind Rush.",
        description = "Suppression Field is an important magic-categorized snare that only one ability per player removes for the group (snare_jet via Wind Rush). Creeping Void is a curse — dispel priority. Holy Echo needs purge. Dusk Frights applies a removable fear. Arcane Explosion and Leech Veil casts respond to stun/fear/incap/grip before they finish. Smudge NPC must be slowed or gripped before reaching its target.",
        byClass = {
            DEATHKNIGHT = {
                47528, 221562, 49576,
                { id = 273952, talent = true, note = "Grip of the Dead slows Smudge NPC" },
                48265,
            },
            DEMONHUNTER = {
                183752, 179057, 207684, 217832,
                { id = 278326, talent = true, note = "Consume Magic purges Holy Echo" },
            },
            DRUID = {
                106839, 22570,
                { id = 2782, talent = true, note = "Removes Creeping Void curse" },
                339,
                { id = 102793, talent = true, note = "Ursol's Vortex for Smudge NPC" },
                132469,
            },
            EVOKER = {
                351338, 368970, 357214, 358385,
                { id = 374251, talent = true, note = "Cauterizing Flame clears curses" },
                360806,
            },
            HUNTER = {
                147362, 187650, 109248, 5384,
                187698,                                                                    -- Tar Trap (slow Smudge NPC)
                { id = 19801, talent = true, note = "Purge — Holy Echo" },
            },
            MAGE = {
                2139, 475,                                                                 -- Remove Curse (core — Creeping Void)
                118, 122, 120,                                                             -- Cone of Cold (slow Smudge)
                { id = 30449, talent = true, note = "Spellsteal Holy Echo" },
            },
            MONK = {
                116705, 115078, 119381, 116841,                                            -- Tiger's Lust (snare removal)
                116095,                                                                    -- Disable (slow Smudge)
                198898,                                                                    -- Song of Chi-Ji
            },
            PALADIN = {
                96231, 853,
                { id = 1044, talent = true, note = "BoF — removes Suppression Field snare" },
                115750,
                { id = 469304, talent = true, note = "Steed of Liberty — self-snare cleanse" },
            },
            PRIEST = {
                { id = 15487, talent = true, note = "Shadow interrupt" },
                528, 32375, 8122,
                108942,                                                                    -- Phantasm (self-snare break)
                1250691,                                                                   -- Void Tendrils (slow Smudge)
            },
            ROGUE = {
                1766, 408, 2094, 31224, 1856,
                3408,                                                                      -- Crippling Poison (slow Smudge)
            },
            SHAMAN = {
                57994, 192058,
                { id = 462817, talent = true, note = "Core — Jet Stream removes Suppression Field for everyone" },
                { id = 51485, talent = true, note = "Earthgrab — root Smudge NPC" },
                51514, 58875,
                { id = 51886, talent = true, note = "Cleanse Spirit for Creeping Void curse" },
            },
            WARLOCK = {
                19647,
                { id = 334275, talent = true, note = "Curse of Exhaustion slows Smudge" },
                30283, 5484, 6358,
            },
            WARRIOR = {
                6552, 107570, 46968,
                { id = 12323, talent = true, note = "Piercing Howl slows Smudge NPC" },
                { id = 5246, talent = true, note = "Intimidating Shout fear packs" },
                18499,
            },
        },
        bySpec = {
            [102] = { { id = 2782, note = "Balance baseline — Creeping Void curse dispel" } },
            [105] = { { id = 392378, talent = true, note = "Resto — Nature's Cure" } },
            [262] = { { id = 51886, note = "Ele — Cleanse Spirit on Creeping Void" } },
            [264] = { { id = 383016, talent = true, note = "Resto Shaman — Improved Purify Spirit" } },
        },
    },

    -- =====================================================
    [658] = { -- Pit of Saron
        header      = "Pit of Saron",
        lead        = "Snare/root storm. Dispel curses, diseases, enrage. Stun Plungegrip before immunity.",
        description = "Plungegrip rooters must be stunned/incap'd/gripped BEFORE their self-buff applies (they go CC-immune mid-cast). Permeating Cold, Cryoshards, and the boss Shadowbind layer snares/roots — bring cleanses or Wind Rush. Shadowbind is super-important (curse+magic snare). Curse of Torment demands curse removal. Rotting Strikes (boss and trash) is a removable disease. Necromantic Infusion is a required purge. Plague Frenzy enrage dispel. Torrent of Misery targeted avoid.",
        byClass = {
            DEATHKNIGHT = {
                47528, 221562, 49576, 48265, 48792,                                        -- Icebound Fortitude
                { id = 212552, talent = true, note = "Wraith Walk breaks snares" },
            },
            DEMONHUNTER = {
                183752, 179057, 207684, 217832, 198793,
                { id = 1266316, talent = true, note = "Burn It Out — self disease cleanse" },
                { id = 1266496, talent = true, note = "Soul Cleanse — self curse cleanse" },
            },
            DRUID = {
                106839, 22570,
                { id = 2908, talent = true, note = "Dispel Plague Frenzy enrage" },
                { id = 2782, talent = true, note = "Curse of Torment / Shadowbind curse" },
                768,                                                                       -- Cat Form
                { id = 132469, talent = true, note = "Knockback Plungegrip casters" },
            },
            EVOKER = {
                351338,
                { id = 374251, talent = true, note = "Cauterizing Flame — curse + disease" },
                { id = 374346, talent = true, note = "Overawe — Plague Frenzy enrage" },
                368970, 357214, 357210,
            },
            HUNTER = {
                147362,
                { id = 19801, talent = true, note = "Removes Plague Frenzy enrage, purges Necromantic Infusion" },
                187650, 109248, 5384,
                { id = 459517, talent = true, note = "Self disease cleanse" },
            },
            MAGE = {
                2139, 475,                                                                 -- Remove Curse
                118, 122, 120, 45438,
                { id = 30449, talent = true, note = "Spellsteal Necromantic Infusion" },
            },
            MONK = {
                116705, 115078, 119381, 116841,
                { id = 450432, talent = true, note = "Pressure Points — Plague Frenzy enrage" },
                { id = 218164, talent = true, note = "Detox Rotting Strikes disease" },
            },
            PALADIN = {
                96231, 853,
                { id = 1044, talent = true, note = "BoF — snare/root immunity (Permeating Cold etc.)" },
                { id = 213644, talent = true, note = "Cleanse Rotting Strikes disease" },
                { id = 469321, talent = true, note = "Righteous Protection — poison/disease aura" },
                642,
            },
            PRIEST = {
                { id = 15487, talent = true, note = "Shadow — Silence Plungegrip cast" },
                528, 32375, 8122,
                { id = 213634, talent = true, note = "Shadow — Purify Disease" },
            },
            ROGUE = {
                1766, 408, 2094, 31224, 1856,
                { id = 5938, talent = true, note = "Shiv removes Plague Frenzy enrage" },
            },
            SHAMAN = {
                57994, 192058,
                { id = 462817, talent = true, note = "Core — Jet Stream breaks Permeating Cold / Cryoshards" },
                { id = 51886, talent = true, note = "Cleanse Spirit — Curse of Torment, Shadowbind curse" },
                { id = 370, talent = true, note = "Purge Necromantic Infusion" },
                51514, 58875,
            },
            WARLOCK = {
                19647,
                { id = 19505, talent = true, note = "Devour Magic purges Necromantic Infusion" },
                30283, 6789, 5782,
                268358,
            },
            WARRIOR = {
                6552, 107570, 46968, 18499, 6544,
                { id = 12294, talent = true, note = "Arms — Mortal Strike utility" },
            },
        },
        bySpec = {
            [105] = { { id = 392378, talent = true, note = "Resto — Nature's Cure (curse/poison, plus magic baseline)" } },
            [65]  = { { id = 393024, talent = true, note = "Holy — Improved Cleanse dispels disease/poison" } },
            [66]  = { { id = 204018, note = "Prot — BoSW for Shadowbind magic phase" } },
            [262] = { { id = 51490, note = "Ele — Thunderstorm knocks Plungegrip casters" } },
        },
    },

    -- =====================================================
    [1753] = { -- Seat of the Triumvirate
        header      = "Seat of the Triumvirate",
        lead        = "Purge Abyssal Enhancement every time. CC void aberrations. Snare cleanses for Chains.",
        description = "Abyssal Enhancement on Ambassador L'ura trash is super-important — purge or kill it immediately. Coalesced Void NPCs on boss 1 need slows/grips and respond to CC (aberration). Chains of Subjugation (important snare) — bring Wind Rush or cleanses. Battle Rage enrage dispel. Shadow Pounce/Shadowmend casters want stun or fear. Devouring Frenzy mob needs Mortal Wounds. Mind Flay and Void Infusion are targeted avoid.",
        byClass = {
            DEATHKNIGHT = {
                47528, 221562, 49576,
                { id = 111673, talent = true, note = "Control Undead — niche on select mobs" },
                48265, 48792,
            },
            DEMONHUNTER = {
                183752,
                { id = 278326, talent = true, note = "Core — purge Abyssal Enhancement" },
                179057, 207684, 217832,
            },
            DRUID = {
                106839, 22570,
                { id = 2908, talent = true, note = "Dispel Battle Rage enrage" },
                339,
                { id = 33786, talent = true, note = "Cyclone single-target CC (aberrations)" },
                { id = 132469, talent = true, note = "Typhoon Coalesced Void NPCs" },
            },
            EVOKER = {
                351338,
                { id = 374346, talent = true, note = "Overawe — Battle Rage enrage" },
                368970, 357214, 358385, 360806,
            },
            HUNTER = {
                147362,
                { id = 19801, talent = true, note = "Core — purges Abyssal Enhancement and enrage" },
                187650, 109248, 5384,
            },
            MAGE = {
                2139, 118, 122,
                { id = 30449, talent = true, note = "Core — Spellsteal Abyssal Enhancement" },
                45438, 110959,                                                             -- Greater Invis for Mind Flay
            },
            MONK = {
                116705, 115078, 119381, 116841,
                { id = 450432, talent = true, note = "Pressure Points — Battle Rage" },
                116844,                                                                    -- Ring of Peace (push Coalesced Void)
            },
            PALADIN = {
                96231, 853,
                { id = 10326, talent = true, note = "Turn Evil on Coalesced Void (aberration)" },
                { id = 1044, talent = true, note = "BoF — ignore Chains of Subjugation" },
                115750, 642,
            },
            PRIEST = {
                { id = 15487, talent = true, note = "Shadow interrupt" },
                { id = 528 },
                32375,                                                                     -- Core — Mass Dispel purges Abyssal Enhancement
                8122,
                { id = 9484, talent = true, note = "Shackle aberrations/undead" },
            },
            ROGUE = {
                1766, 408, 2094, 31224, 1856,
                { id = 5938, talent = true, note = "Shiv — Battle Rage enrage" },
                8679,                                                                      -- Wound Poison for Devouring Frenzy
            },
            SHAMAN = {
                57994, 192058,
                { id = 370, talent = true, note = "Core — Purge Abyssal Enhancement" },
                { id = 462817, talent = true, note = "Wind Rush breaks Chains of Subjugation" },
                51514, 58875,
            },
            WARLOCK = {
                19647,
                { id = 19505, talent = true, note = "Devour Magic purges Abyssal Enhancement" },
                30283, 6789, 5782,
                { id = 710, talent = true, note = "Banish Coalesced Void aberration" },
            },
            WARRIOR = {
                6552, 107570, 46968, 18499, 6544,
                { id = 12294, talent = true, note = "Arms — Mortal Strike on Devouring Frenzy" },
            },
        },
        bySpec = {
            [105] = { { id = 392378, talent = true, note = "Resto — Nature's Cure" } },
            [66]  = { { id = 204018, note = "Prot — BoSW pre-Mind Flay cast" } },
            [269] = { { id = 107428, note = "WW — Rising Sun Kick on Devouring Frenzy" } },
            [270] = { { id = 107428, note = "MW — Rising Sun Kick applies Mortal Wounds" } },
        },
    },

    -- =====================================================
    [1209] = { -- Skyreach
        header      = "Skyreach",
        lead        = "Slow Sunwings. Stun Solar Zealots. Purge Solar Barrier. Interrupt Mark of Death.",
        description = "Sunwings NPCs (boss 3) need slows/grips. Solar Zealot must be stunned/feared on the last boss (they also knock you off — be ready to jump back). Mark of Death is an important interruptible. Solar Barrier and Rushing Winds require purge. Wrathful Wind is a removable enrage. Blade Rush jumps deliver a stacking bleed — dispel or BoP. Fan of Blades (first boss) also applies bleed. Wind Maze skip via jump/movement-immunity.",
        byClass = {
            DEATHKNIGHT = {
                47528, 221562, 49576,
                { id = 273952, talent = true, note = "Grip of the Dead slows Sunwings" },
                48265,
            },
            DEMONHUNTER = {
                183752,
                { id = 278326, talent = true, note = "Consume Magic purges Solar Barrier" },
                179057, 207684, 217832, 131347,
            },
            DRUID = {
                106839, 22570,
                { id = 2908, talent = true, note = "Dispel Wrathful Wind enrage" },
                339,
                { id = 102793, talent = true, note = "Ursol's Vortex on Sunwings" },
                { id = 5211, talent = true, note = "Mighty Bash stun Solar Zealot" },
            },
            EVOKER = {
                351338,
                { id = 374346, talent = true, note = "Overawe — Wrathful Wind enrage" },
                368970, 357214, 358385, 358733,
                { id = 374251, talent = true, note = "Cauterizing Flame clears Blade Rush bleed" },
            },
            HUNTER = {
                147362,
                { id = 19801, talent = true, note = "Removes Wrathful Wind; purges Solar Barrier" },
                187650, 109248, 187698,
                781,                                                                       -- Disengage (Wind Maze / Solar Zealot knock)
            },
            MAGE = {
                2139, 118,
                { id = 157980, talent = true, note = "Supernova knocks Sunwings down" },
                { id = 113724, talent = true, note = "Ring of Frost on Solar Zealots" },
                { id = 30449, talent = true, note = "Spellsteal Solar Barrier / Rushing Winds" },
                1953,                                                                      -- Blink (Wind Maze skip)
            },
            MONK = {
                116705, 115078, 119381, 116841,
                { id = 450432, talent = true, note = "Pressure Points — Wrathful Wind" },
                { id = 449582, talent = true, note = "Lighter Than Air — Wind Maze jump utility" },
            },
            PALADIN = {
                96231, 853,
                { id = 1022, talent = true, note = "BoP removes Blade Rush / Fan of Blades bleed" },
                { id = 1044, talent = true, note = "BoF snare immunity" },
                115750, 642,
            },
            PRIEST = {
                { id = 15487, talent = true, note = "Shadow interrupt" },
                528, 32375, 8122,
                1250691,                                                                   -- Void Tendrils on Sunwings
            },
            ROGUE = {
                1766, 408, 2094, 31224, 1856,
                3408,                                                                      -- Crippling Poison Sunwings
            },
            SHAMAN = {
                57994, 192058,
                { id = 370, talent = true, note = "Purge Solar Barrier / Rushing Winds" },
                { id = 51485, talent = true, note = "Earthgrab roots Sunwings" },
                51514, 192063,                                                             -- Gust of Wind (Wind Maze skip)
            },
            WARLOCK = {
                19647,
                { id = 19505, talent = true, note = "Devour Magic purges Solar Barrier" },
                30283, 6789, 5484,
                { id = 334275, talent = true, note = "Curse of Exhaustion slows Sunwings" },
            },
            WARRIOR = {
                6552, 107570, 46968,
                { id = 12323, talent = true, note = "Piercing Howl slows Sunwings" },
                { id = 5246, talent = true, note = "Intimidating Shout fears Solar Zealot" },
                6544,                                                                      -- Heroic Leap (Wind Maze / Solar Zealot knock)
            },
        },
        bySpec = {
            [262] = { { id = 51490, note = "Ele — Thunderstorm Sunwings knockdown" } },
        },
    },

    -- =====================================================
    [2805] = { -- Windrunner Spire
        header      = "Windrunner Spire",
        lead        = "Curse of Darkness cleanse is mandatory. Enrage dispel on Bloodlust. Purge Bolstering Flames.",
        description = "Curse of Darkness (boss 2) is super-important — every curse dispel in the group should be ready. Ephemeral Bloodlust (trash) is an important enrage; Bloodlust Axemaster pack often wipes groups that don't dispel. Poison Blades and Poison Spray apply removable poison (magic-categorized). Throw Axe, Puncturing Bite, Shred Flesh stack bleeds — BoP/cleanse matters. Bolstering Flames on drakes must be purged. Intimidating Shout is a removable fear. Fire Spit / Arrow Rain / Gore Whirl channels respond to stun/grip/incap/fear before completing.",
        byClass = {
            DEATHKNIGHT = {
                47528, 221562, 49576, 48265, 49039,                                        -- Lichborne (self fear cleanse)
            },
            DEMONHUNTER = {
                183752,
                { id = 278326, talent = true, note = "Consume Magic purges Bolstering Flames" },
                179057, 207684, 217832,
                { id = 1266496, talent = true, note = "Soul Cleanse — self Curse of Darkness" },
            },
            DRUID = {
                106839, 22570,
                { id = 2908, talent = true, note = "Dispel Ephemeral Bloodlust enrage" },
                { id = 2782, talent = true, note = "Core — Curse of Darkness + Poison Blades" },
                339, 132469,
            },
            EVOKER = {
                351338,
                { id = 374346, talent = true, note = "Overawe — Ephemeral Bloodlust" },
                { id = 374251, talent = true, note = "Cauterizing Flame clears curse + bleed + poison" },
                365585,                                                                    -- Expunge (poison baseline)
                368970, 357214,
            },
            HUNTER = {
                147362,
                { id = 19801, talent = true, note = "Core — Bloodlust enrage + Bolstering Flames purge" },
                187650, 109248, 5384,
                { id = 459517, talent = true, note = "Self poison cleanse" },
            },
            MAGE = {
                2139, 475,                                                                 -- Remove Curse (Curse of Darkness!)
                118, 122, 45438,
                { id = 30449, talent = true, note = "Spellsteal Bolstering Flames" },
            },
            MONK = {
                116705, 115078, 119381, 116841,
                { id = 450432, talent = true, note = "Pressure Points — Bloodlust enrage" },
                { id = 218164, talent = true, note = "Detox Poison Blades / Poison Spray" },
            },
            PALADIN = {
                96231, 853,
                { id = 1022, talent = true, note = "BoP removes Throw Axe / Puncturing Bite / Shred Flesh bleed" },
                { id = 213644, talent = true, note = "Cleanse Toxins for Poison Blades" },
                { id = 469321, talent = true, note = "Righteous Protection poison aura" },
                642,
            },
            PRIEST = {
                { id = 15487, talent = true, note = "Shadow interrupt" },
                528, 32375, 8122,
                108942,                                                                    -- Phantasm (fear self-cleanse)
            },
            ROGUE = {
                1766, 408, 2094, 31224, 1856,                                              -- Cloak clears Curse of Darkness for self
                { id = 5938, talent = true, note = "Shiv removes Ephemeral Bloodlust" },
            },
            SHAMAN = {
                57994, 192058,
                { id = 370, talent = true, note = "Purge Bolstering Flames" },
                { id = 383013, talent = true, note = "Poison Cleansing Totem" },
                { id = 51886, talent = true, note = "Cleanse Spirit — Curse of Darkness" },
                { id = 8143, talent = true, note = "Tremor Totem clears Intimidating Shout fear" },
            },
            WARLOCK = {
                19647,
                { id = 19505, talent = true, note = "Devour Magic purges Bolstering Flames" },
                30283, 6789, 5782,
            },
            WARRIOR = {
                6552, 107570, 46968, 18499,                                                -- Berserker Rage clears Intimidating Shout
                { id = 384100, talent = true, note = "Berserker Shout — AoE fear dispel" },
                6544,
            },
        },
        bySpec = {
            [105] = { { id = 392378, talent = true, note = "Resto Druid — Nature's Cure also handles Poison Blades" } },
            [65]  = { { id = 393024, talent = true, note = "Holy — Improved Cleanse" } },
            [66]  = { { id = 204018, note = "Prot — BoSW on incoming magic phases" } },
            [264] = { { id = 383016, talent = true, note = "Resto Shaman — Improved Purify Spirit (Curse of Darkness)" } },
        },
    },
}

------------------------------------------------------------
-- UI
------------------------------------------------------------

local win
local ICON_SIZE = 48   -- default; overridden per-player below

-- Full shows the dungeon writeup; compact shows only the recommended
-- abilities. Mid-key nobody reads prose -- what you actually re-check is
-- "which of my buttons matters here", and that is the icon row.
local FULL_W    = 420
local COMPACT_W = 300
local ICON_PAD  = 6
local BORDER_SIZE = 2

local function styleBox(f, bgA)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    f:SetBackdropColor(0.04, 0.04, 0.04, bgA or 0.95)
    f:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
end

-- Position persistence. Save anchor + offset on drag-stop and restore
-- on first build, so the user only positions the window once.
local DEFAULT_POS = { anchor = "LEFT", relativePoint = "LEFT", x = 40, y = -40 }

local function posDB()
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.utilityAdvisor = YippYappHelperDB.utilityAdvisor or {}
    local d = YippYappHelperDB.utilityAdvisor
    if type(d.position) ~= "table" then
        d.position = {
            anchor = DEFAULT_POS.anchor, relativePoint = DEFAULT_POS.relativePoint,
            x = DEFAULT_POS.x, y = DEFAULT_POS.y,
        }
    end
    if type(d.locked) ~= "boolean" then d.locked = true end
    if type(d.compact) ~= "boolean" then d.compact = false end
    if type(d.iconSize) ~= "number" then d.iconSize = ICON_SIZE end
    if d.iconSize < 24 then d.iconSize = 24 elseif d.iconSize > 64 then d.iconSize = 64 end
    return d
end

--- Player-configurable icon size. Read through a function rather than a
--- constant so a change takes effect on the next render without a reload.
local function iconSize() return posDB().iconSize or ICON_SIZE end

local function ApplySavedPosition(f)
    local p = posDB().position
    f:ClearAllPoints()
    f:SetPoint(p.anchor, UIParent, p.relativePoint, p.x, p.y)
end

local function build()
    if win then return win end
    win = CreateFrame("Frame", "YippYappUtilityAdvisor", UIParent, "BackdropTemplate")
    win:SetSize(FULL_W, 240)
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self)
        if not posDB().locked then self:StartMoving() end
    end)
    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        local p = posDB().position
        p.anchor = point
        p.relativePoint = relPoint
        p.x = math.floor(x + 0.5)
        p.y = math.floor(y + 0.5)
    end)
    win:SetFrameStrata("MEDIUM")
    styleBox(win)
    ApplySavedPosition(win)
    win:Hide()

    -- Drag overlay: cyan border + faint fill + "drag to move" label,
    -- shown whenever the window is unlocked. Mirrors the Interrupt
    -- Tracker's unlock affordance.
    local overlay = CreateFrame("Frame", nil, win, "BackdropTemplate")
    overlay:SetAllPoints(win)
    overlay:SetFrameLevel(win:GetFrameLevel() + 10)
    overlay:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    overlay:SetBackdropColor(0, 0.6, 1.0, 0.12)
    overlay:SetBackdropBorderColor(0, 0.8, 1.0, 0.9)
    overlay:EnableMouse(false)
    local oLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmallOutline")
    oLabel:SetPoint("CENTER")
    oLabel:SetText("drag to move")
    oLabel:SetTextColor(0, 0.9, 1.0)
    overlay:SetShown(not posDB().locked)
    win.lockOverlay = overlay

    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -8)
    win.title = title

    local close = CreateFrame("Button", nil, win, "BackdropTemplate")
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -4, -4)
    styleBox(close, 0.9)
    local cl = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cl:SetPoint("CENTER"); cl:SetText("x")
    close:SetScript("OnClick", function() win:Hide() end)

    local desc = win:CreateFontString(nil, "OVERLAY")
    desc:SetFont(STANDARD_TEXT_FONT, 12, "")
    desc:SetPoint("TOPLEFT", 14, -34)
    desc:SetPoint("TOPRIGHT", -14, -34)
    desc:SetJustifyH("LEFT")
    desc:SetSpacing(3)
    desc:SetWordWrap(true)
    desc:SetTextColor(0.92, 0.92, 0.92)
    win.desc = desc

    local div = win:CreateTexture(nil, "OVERLAY")
    div:SetColorTexture(0.35, 0.35, 0.35, 0.6)
    div:SetHeight(1)
    win.div = div

    local legend = win:CreateFontString(nil, "OVERLAY")
    legend:SetFont(STANDARD_TEXT_FONT, 10, "")
    legend:SetJustifyH("LEFT")
    legend:SetTextColor(0.55, 0.55, 0.55)
    legend:SetText("|cff33ff33Green|r = baseline      |cffffd100Gold T|r = talent")
    win.legend = legend

    local iconRow = CreateFrame("Frame", nil, win)
    iconRow:SetPoint("TOPLEFT", 14, -100)
    iconRow:SetPoint("TOPRIGHT", -14, -100)
    iconRow:SetHeight(iconSize() + 8)
    win.iconRow = iconRow

    local fallback = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fallback:SetPoint("BOTTOMLEFT", 12, 20)
    fallback:SetPoint("BOTTOMRIGHT", -12, 20)
    fallback:SetJustifyH("LEFT")
    fallback:SetTextColor(0.55, 0.55, 0.55)
    fallback:SetWordWrap(true)
    win.fallback = fallback

    return win
end

-- Persistent icon pool. Icons are created once and re-styled on each
-- show — without this we'd leak ~5-10 frames per advisor refresh.
local iconPool = {}

local function clearIcons(row)
    for _, btn in ipairs(iconPool) do btn:Hide() end
end

local function normalizeSpell(entry)
    if type(entry) == "number" then return { id = entry } end
    return entry
end

local function acquireIcon(parent, idx)
    local btn = iconPool[idx]
    if btn then return btn end
    btn = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    btn:SetSize(iconSize(), iconSize())
    btn:EnableMouse(true)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = BORDER_SIZE,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    btn:SetBackdropColor(0, 0, 0, 0)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    btn.icon:SetPoint("BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- Talent "T" badge stays hidden unless this icon represents a talent.
    btn.talentBadge = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLargeOutline")
    btn.talentBadge:SetPoint("BOTTOMRIGHT", 2, -2)
    btn.talentBadge:SetText("T")
    btn.talentBadge:SetTextColor(1, 0.82, 0)
    btn.talentBadge:Hide()
    iconPool[idx] = btn
    return btn
end

local function styleIcon(btn, parent, entry, xOffset, yOffset)
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(entry.id)
    local tex = info and info.iconID

    btn:SetParent(parent)
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)

    if entry.talent then
        btn:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
        btn.talentBadge:Show()
    else
        btn:SetBackdropBorderColor(0.15, 0.95, 0.35, 1.0)
        btn.talentBadge:Hide()
    end

    btn.icon:SetTexture(tex or 134400)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(entry.id)
        if entry.note then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(entry.note, 0.0, 0.8, 1.0, true)
        end
        if entry.talent then
            GameTooltip:AddLine("|cffffd100Talent — pick this up for this dungeon|r")
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    btn:Show()
end

-- Deduplicate by spell id (bySpec entries win over byClass)
local function buildEntryList(data, class, specID)
    local seen, list = {}, {}
    local function pushAll(src)
        if not src then return end
        for _, raw in ipairs(src) do
            local e = normalizeSpell(raw)
            if e and e.id and not seen[e.id] then
                seen[e.id] = true
                table.insert(list, e)
            end
        end
    end
    if data.bySpec and specID and data.bySpec[specID] then
        pushAll(data.bySpec[specID])
    end
    if data.byClass and class and data.byClass[class] then
        pushAll(data.byClass[class])
    end
    return list
end

--- Lay out icons, balanced across rows. Returns total height used.
---
--- Greedy wrapping packed each row to the edge and left the remainder
--- stranded -- six icons then one, which reads as a mistake. Instead work
--- out the fewest rows that fit, then spread evenly over them, so seven
--- icons become 4+3 rather than 6+1.
local function layoutIcons(row, entries, rowWidth)
    local size = iconSize()
    local stride = size + ICON_PAD
    local n = #entries
    if n == 0 then return stride end

    local perRow = math.max(1, math.floor((rowWidth + ICON_PAD) / stride))
    local rows = math.ceil(n / perRow)
    perRow = math.ceil(n / rows)          -- even out the last row

    local i = 0
    for r = 0, rows - 1 do
        local count = math.min(perRow, n - i)
        -- Centre each row so a short final row does not hang left.
        local rowW = count * stride - ICON_PAD
        local startX = math.max(0, (rowWidth - rowW) / 2)
        for c = 0, count - 1 do
            i = i + 1
            styleIcon(acquireIcon(row, i), row, entries[i],
                startX + c * stride, -r * stride)
        end
    end
    return rows * stride
end

-- Keyword → color table. Patterns use bracketed first-letter class so we
-- catch both sentence-start and mid-sentence capitalization without a
-- second pass. Order matters for multi-word phrases — longer matches
-- listed first so they aren't broken up by a shorter keyword's gsub.
local DESC_KEYWORD_COLORS = {
    { "([Mm]agic%-categorized)",         "ff6ac8ff" },
    { "([Mm]ortal [Ww]ounds)",            "ffff8060" },
    { "([Pp]urges?)",                    "ff66ddff" },
    { "([Pp]urged)",                     "ff66ddff" },
    { "([Dd]ispels?)",                   "ff6ac8ff" },
    { "([Dd]ispelled)",                  "ff6ac8ff" },
    { "([Cc]leanses?)",                  "ff6ac8ff" },
    { "([Ii]nterruptible)",              "ffffe066" },
    { "([Ii]nterrupts?)",                "ffffe066" },
    { "([Ii]nterrupted)",                "ffffe066" },
    { "([Ee]nrages?)",                   "ffff6262" },
    { "([Cc]urses?)",                    "ffc266ff" },
    { "([Cc]ursed)",                     "ffc266ff" },
    { "([Dd]iseases?)",                  "ffa98b6f" },
    { "([Pp]oisons?)",                   "ff66dd66" },
    { "([Bb]leeds?)",                    "ffcc4444" },
    { "([Ss]tuns?)",                     "ffffcc33" },
    { "([Ss]tunned)",                    "ffffcc33" },
    { "([Ff]ears?)",                     "ffc06aff" },
    { "([Ff]eared)",                     "ffc06aff" },
    { "([Ss]lows?)",                     "ff8fd4ff" },
    { "([Ss]nares?)",                    "ff8fd4ff" },
    { "([Ii]ncap'?d?)",                  "ffffa0e0" },
    { "([Gg]rips?)",                     "ffd6a04f" },
    { "([Gg]ripped)",                    "ffd6a04f" },
}

-- Wrap sequences of two consecutive Title-Cased words (e.g. "Raging
-- Screech", "Power Vacuum", "Blade Rush") in white so ability names
-- pop against the body text. Run BEFORE keyword coloring so keyword
-- colors aren't smothered inside nested |c…|r tags.
local function descBoldAbilities(text)
    return text:gsub("(%u%l+)([ %-'])(%u%l+)", "|cffffffff%1%2%3|r")
end

local function descColorizeKeywords(text)
    for _, pair in ipairs(DESC_KEYWORD_COLORS) do
        text = text:gsub(pair[1], "|c" .. pair[2] .. "%1|r")
    end
    return text
end

-- Split a dense description paragraph into one bulleted line per
-- sentence so the user can scan mechanic-by-mechanic instead of
-- parsing a wall of prose. Sentence boundaries are "." "!" "?" — and
-- we trim whitespace at both edges of each fragment.
local function descBulletize(text)
    local out = {}
    for fragment in text:gmatch("([^%.%?!]+[%.%?!]?)") do
        fragment = fragment:gsub("^%s+", ""):gsub("%s+$", "")
        if fragment ~= "" then
            table.insert(out, "|cff66b5ff›|r  " .. fragment)
        end
    end
    return table.concat(out, "\n")
end

local function formatDescription(text)
    if not text or text == "" then return "" end
    local styled = descBoldAbilities(text)
    styled = descColorizeKeywords(styled)
    return descBulletize(styled)
end

local function renderDungeon(mapID)
    local w = build()
    local data = UA.DUNGEONS[mapID]
    if not data then
        w.title:SetText("No notes")
        w.desc:SetText("|cffff8080No data for instanceMapID " .. tostring(mapID) .. "|r")
        w.fallback:SetText("")
        w.div:Hide(); w.legend:Hide()
        clearIcons(w.iconRow)
        return
    end

    w.title:SetText(data.header or "Utility")

    local compact = posDB().compact
    w:SetWidth(compact and COMPACT_W or FULL_W)

    if compact then
        -- Title + icons only. Everything else is reference material that
        -- belongs in the full view.
        w.desc:SetText("")
        w.desc:Hide()
        w.div:Hide()
        w.legend:Hide()
        w.fallback:SetText("")

        clearIcons(w.iconRow)
        local _, cls = UnitClass("player")
        local specIdx = GetSpecialization and GetSpecialization()
        local sID = specIdx and GetSpecializationInfo and GetSpecializationInfo(specIdx)
        local list = buildEntryList(data, cls, sID)

        w.iconRow:ClearAllPoints()
        w.iconRow:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -30)
        w.iconRow:SetPoint("TOPRIGHT", w, "TOPRIGHT", -14, -30)

        if #list == 0 then
            w.fallback:SetText(ns.Widgets:Tint("muted", "No recommendations for this spec yet"))
            w:SetHeight(72)
            return
        end
        local h = layoutIcons(w.iconRow, list, COMPACT_W - 28)
        w.iconRow:SetHeight(h)
        w:SetHeight(30 + h + 14)
        return
    end

    w.desc:Show()

    -- Description: bulleted, color-coded. Lead still gets the stylized
    -- italic-esque intro look (slightly softer white, no bullet) so the
    -- user reads one-line orientation before the per-mechanic bullets.
    local formattedDesc = formatDescription(data.description or "")
    local body
    if data.lead and data.lead ~= "" then
        body = ("|cffe8e8e8%s|r\n\n%s"):format(data.lead, formattedDesc)
    else
        body = formattedDesc
    end
    w.desc:SetText(body)
    w.desc:SetSpacing(5)

    clearIcons(w.iconRow)
    local _, class = UnitClass("player")
    local specIndex = GetSpecialization and GetSpecialization()
    local specID
    if specIndex and GetSpecializationInfo then
        specID = GetSpecializationInfo(specIndex)
    end

    local entries = buildEntryList(data, class, specID)

    local descBottom = -34 - w.desc:GetStringHeight() - 8
    w.div:ClearAllPoints()
    w.div:SetPoint("TOPLEFT", w, "TOPLEFT", 14, descBottom)
    w.div:SetPoint("TOPRIGHT", w, "TOPRIGHT", -14, descBottom)
    w.div:Show()

    w.legend:ClearAllPoints()
    w.legend:SetPoint("TOPLEFT", w, "TOPLEFT", 14, descBottom - 6)
    w.legend:Show()

    w.iconRow:ClearAllPoints()
    w.iconRow:SetPoint("TOPLEFT", w, "TOPLEFT", 14, descBottom - 26)
    w.iconRow:SetPoint("TOPRIGHT", w, "TOPRIGHT", -14, descBottom - 26)

    if #entries == 0 then
        w.fallback:SetText(("|cff%sNo recommendations seeded for %s yet — add entries to UA.DUNGEONS[%d].byClass.%s|r"):format(ns.Widgets:Hex("muted"), class or "your class", mapID, class or ""))
        w:SetHeight(math.max(180, 120 + (w.desc:GetStringHeight() or 40)))
        return
    end

    w.fallback:SetText("")
    local rowWidth = w:GetWidth() - 28
    local iconsHeight = layoutIcons(w.iconRow, entries, rowWidth)
    w.iconRow:SetHeight(iconsHeight)

    local descH = w.desc:GetStringHeight() or 40
    local totalH = 34 + descH + 8 + 1 + 14 + 12 + iconsHeight + 20
    w:SetHeight(math.max(180, totalH))
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------

UA._lastShownMapID = nil

function UA:ShowForCurrentInstance(force)
    local _, instType, difficultyID, _, _, _, _, instanceMapID = GetInstanceInfo()
    if not force then
        if instType ~= "party" then
            self._lastShownMapID = nil
            return
        end
        if difficultyID ~= 8 and difficultyID ~= 23 then return end
        if self._lastShownMapID == instanceMapID then return end
        self._lastShownMapID = instanceMapID
    end
    if not self.DUNGEONS[instanceMapID] then
        if force then
            build().title:SetText("No notes")
            build().desc:SetText("No data for instanceMapID " .. tostring(instanceMapID))
            clearIcons(build().iconRow)
            build().fallback:SetText("")
            build():Show()
        end
        return
    end
    renderDungeon(instanceMapID)
    build():Show()
end

function UA:ShowTest()
    -- Record the sample map so SetCompact can re-render in place. Without
    -- it, toggling the view in Edit Mode does nothing visible.
    UA._lastShownMapID = 2526
    renderDungeon(2526)
    build():Show()
end

function UA:Hide() if win then win:Hide() end end

function UA:IsCompact() return posDB().compact and true or false end

--- Switching view re-renders in place so the change is visible at once,
--- rather than only on the next dungeon entry.
function UA:SetCompact(on)
    posDB().compact = not not on
    if win and win:IsShown() and UA._lastShownMapID then
        renderDungeon(UA._lastShownMapID)
    end
end

function UA:GetIconSize() return posDB().iconSize or ICON_SIZE end
function UA:SetIconSize(v)
    posDB().iconSize = math.max(24, math.min(64, tonumber(v) or ICON_SIZE))
    if win and win:IsShown() and UA._lastShownMapID then
        renderDungeon(UA._lastShownMapID)
    end
end

function UA:IsLocked() return posDB().locked and true or false end
function UA:SetLocked(on)
    posDB().locked = not not on
    if win and win.lockOverlay then
        win.lockOverlay:SetShown(not posDB().locked)
    end
    -- Locking clears the move affordance AND dismisses the preview so
    -- the window stays out of the way during normal play.
    if posDB().locked and win then win:Hide() end
end

------------------------------------------------------------
-- Events
------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("CHALLENGE_MODE_START")
f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:SetScript("OnEvent", function(_, event, isInitialLogin, isReloadingUi)
    if event == "PLAYER_ENTERING_WORLD" then
        if isInitialLogin or isReloadingUi then return end
        if ns.ModuleEnabled and not ns.ModuleEnabled("utilityAdvisor") then return end
        C_Timer.After(0.5, function() UA:ShowForCurrentInstance() end)
    elseif event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_COMPLETED" then
        UA:Hide()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        UA._lastShownMapID = nil
        if win and win:IsShown() then UA:ShowForCurrentInstance(true) end
    end
end)

SLASH_YYHUTILITY1 = "/yyhutility"
SlashCmdList.YYHUTILITY = function() UA:ShowTest() end
