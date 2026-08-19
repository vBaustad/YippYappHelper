local _, ns = ...

----------------------------------------------------------
-- Mythic+ utility, per dungeon and per class.
--
-- GENERATED -- do not hand-edit. Regenerate with:
--     python Tools/build_utility.py
--
-- The prose and the notes are ours. The mechanic-to-utility
-- mapping under them is derived from Mythic Plus Utility's
-- curated tags (by Nikyou); the generator's header says exactly
-- what is read from that addon and what is not.
--
-- Data model, per instanceMapID:
--   header, lead, description,
--   byClass = { CLASS = { spellID | { id=, talent=, note= } } },
--   bySpec  = { [specID] = { ... } }   -- merged on top of byClass
----------------------------------------------------------

ns.UTILITY_BUILT_AT = "2026-08-19"

ns.UTILITY_DUNGEONS = {
    -- =====================================================
    [2993] = { -- Altar of Fangs
        header      = "Altar of Fangs",
        lead        = "Hard CC on Evolve, poison dispels behind the interrupts, one enrage to "
                      .. "strip.",
        description = "Evolve is the channel that defines the pull -- stun, fear, incapacitate "
                      .. "or grip it, and it is a humanoid, so humanoid CC works too. Envenom and "
                      .. "Mass Envenom are interruptible poisons, and whatever lands wants a "
                      .. "poison dispel. Regurgitate on the first boss carries a disease as well "
                      .. "as a snare, and it can be sidestepped entirely. Toxic Atrophy on the "
                      .. "second boss is interruptible. Ravenous Claws is a removable enrage, and "
                      .. "Gorge is a self-buff that wants Mortal Wounds on it.",
        byClass = {
            DEATHKNIGHT = {
                47528,    -- Mind Freeze
                49576,    -- Death Grip
                221562,   -- Asphyxiate
                { id = 207167, talent = true, note = "AoE incap straight into an Evolve channel" },   -- Blinding Sleet
                45524,    -- Chains of Ice
                { id = 273952, talent = true },   -- Grip of the Dead
                { id = 454786, talent = true },   -- Ice Prison
            },
            DEMONHUNTER = {
                183752,   -- Disrupt
                207684,   -- Sigil of Misery
                217832,   -- Imprison
                198793,   -- Vengeful Retreat
                { id = 1266316, talent = true },   -- Burn It Out
            },
            DRUID = {
                106839,   -- Skull Bash
                5211,     -- Mighty Bash
                22570,    -- Maim
                { id = 99, talent = true, note = "AoE incap on the Evolve packs" },   -- Incapacitating Roar
                { id = 132469, talent = true },   -- Typhoon
                768,      -- Cat Form (as a general shapeshift)
                { id = 2908, talent = true, note = "Ravenous Claws is the enrage worth the talent here" },   -- Soothe
            },
            EVOKER = {
                351338,   -- Quell
                365585,   -- Expunge
                368970,   -- Tail Swipe
                374251,   -- Cauterizing Flame
                357210,   -- Deep Breath
                { id = 374346, talent = true },   -- Overawe
                { id = 387341, talent = true },   -- Walloping Blow
            },
            HUNTER = {
                147362,   -- Counter Shot
                109215,   -- Posthaste
                195645,   -- Wing Clip
                { id = 19801, talent = true, note = "Tranquilizing Shot -- Ravenous Claws" },   -- Tranquilizing Shot
                { id = 187698, talent = true },   -- Tar Trap
                { id = 459517, talent = true },   -- Emergency Salve
            },
            MAGE = {
                2139,     -- Counterspell
                { id = 31661, talent = true },   -- Dragon's Breath
                { id = 113724, talent = true },   -- Ring of Frost
                { id = 157980, talent = true },   -- Supernova
                120,      -- Cone of Cold
                { id = 386828, talent = true },   -- Energized Barriers
            },
            MONK = {
                116705,   -- Spear Hand Strike
                116841,   -- Tiger's Lust
                119381,   -- Leg Sweep
                { id = 116844, talent = true },   -- Ring of Peace
                { id = 198898, talent = true },   -- Song of Chi-Ji
                { id = 116095, talent = true },   -- Disable
                { id = 450432, talent = true },   -- Pressure Points
            },
            PALADIN = {
                96231,    -- Rebuke
                853,      -- Hammer of Justice
                { id = 1044, talent = true },   -- Blessing of Freedom
                { id = 115750, talent = true },   -- Blinding Light
                { id = 469321, talent = true },   -- Righteous Protection
                { id = 469304, talent = true },   -- Steed of Liberty
            },
            PRIEST = {
                { id = 15487, talent = true, note = "Shadow interrupt" },   -- Silence
                8122,     -- Psychic Scream
                { id = 108942, talent = true },   -- Phantasm
            },
            ROGUE = {
                1766,     -- Kick
                408,      -- Kidney Shot
                8679,     -- Wound Poison
                1856,     -- Vanish
                3408,     -- Crippling Poison
                { id = 5938, note = "Shiv strips Ravenous Claws" },   -- Shiv
                31224,    -- Cloak of Shadows
            },
            SHAMAN = {
                57994,    -- Wind Shear
                192058,   -- Capacitor Totem
                { id = 383013, talent = true },   -- Poison Cleansing Totem
                { id = 462817, talent = true },   -- Jet Stream for Wind Rush Totem  [snare_jet]
                2484,     -- Earthbind Totem
                58875,    -- Spirit Walk
                { id = 51485, talent = true },   -- Earthgrab Totem
            },
            WARLOCK = {
                19647,    -- Spell Lock
                5782,     -- Fear
                6789,     -- Mortal Coil
                30283,    -- Shadowfury
                { id = 5484, talent = true },   -- Howl of Terror
                { id = 268358, talent = true },   -- Demonic Circle
                { id = 334275, talent = true },   -- Curse of Exhaustion
            },
            WARRIOR = {
                6552,     -- Pummel
                46968,    -- Shockwave
                107570,   -- Storm Bolt
                { id = 5246, talent = true },   -- Intimidating Shout
                1271925,  -- Fearless
                { id = 12323, talent = true },   -- Piercing Howl
            },
        },
        bySpec = {
            [65] = {
                { id = 393024, talent = true },   -- Improved Cleanse
            },
            [66] = {
                204018,   -- Blessing of Spellwarding
                { id = 213644, talent = true },   -- Cleanse Toxins
            },
            [70] = {
                { id = 213644, talent = true },   -- Cleanse Toxins
            },
            [71] = {
                12294,    -- Mortal Strike
            },
            [102] = {
                { id = 2782, talent = true },   -- Remove Corruption
            },
            [103] = {
                { id = 2782, talent = true },   -- Remove Corruption
            },
            [104] = {
                { id = 2782, talent = true },   -- Remove Corruption
            },
            [105] = {
                { id = 392378, talent = true },   -- Improved Nature's Cure
            },
            [250] = {
                { id = 108199, talent = true },   -- Gorefiend's Grasp
                { id = 1263569, talent = true },   -- Abomination Limb
            },
            [253] = {
                19577,    -- Intimidation
                { id = 53271, talent = true },   -- Master's Call (pet)
            },
            [254] = {
                474421,   -- Intimidation
            },
            [255] = {
                19577,    -- Intimidation
                { id = 53271, talent = true },   -- Master's Call (pet)
            },
            [256] = {
                { id = 390632, talent = true },   -- Improved Purify
            },
            [257] = {
                { id = 390632, talent = true },   -- Improved Purify
            },
            [258] = {
                { id = 47585, talent = true },   -- Dispersion
                { id = 213634, talent = true },   -- Purify Disease
            },
            [262] = {
                51490,    -- Thunderstorm
            },
            [266] = {
                89766,    -- Axe Toss (pet)
            },
            [268] = {
                { id = 218164, talent = true },   -- Detox
            },
            [269] = {
                107428,   -- Rising Sun Kick
                { id = 218164, talent = true },   -- Detox
            },
            [270] = {
                { id = 388874, talent = true },   -- Improved Detox
            },
            [577] = {
                179057,   -- Chaos Nova
            },
            [581] = {
                179057,   -- Chaos Nova
            },
            [1468] = {
                403631,   -- Dream Flight
            },
            [1473] = {
                403631,   -- Breath of Eons
            },
            [1480] = {
                1234195,  -- Void Nova
            },
        },
    },

    -- =====================================================
    [2825] = { -- Den of Nalorakk
        header      = "Den of Nalorakk",
        lead        = "Freedom from roots and snares, a curse dispel, and two enrages worth "
                      .. "stripping.",
        description = "Glacial Tomb and Rime Detonation lock you in place, and the answer is "
                      .. "movement freedom or a root break rather than a health bar. Frigid Roar "
                      .. "and Healing Breeze are both interruptible, and Healing Breeze is a purge "
                      .. "target that also wants Mortal Wounds on the caster. Insatiable Hunger is "
                      .. "a curse. Toxic Spores on the first boss is a poison. Bestial Wrath and "
                      .. "Mother's Wrath are both removable enrages, and Razor Dive keeps a bleed "
                      .. "rolling underneath all of it.",
        byClass = {
            DEATHKNIGHT = {
                47528,    -- Mind Freeze
                { id = 212552, talent = true },   -- Wraith Walk
            },
            DEMONHUNTER = {
                183752,   -- Disrupt
                { id = 278326, talent = true },   -- Consume Magic
                198793,   -- Vengeful Retreat
                { id = 1266496, talent = true },   -- Soul Cleanse
            },
            DRUID = {
                106839,   -- Skull Bash
                768,      -- Cat Form (as a general shapeshift)
                { id = 2908, talent = true, note = "Two enrages here: Bestial Wrath and Mother's Wrath" },   -- Soothe
            },
            EVOKER = {
                351338,   -- Quell
                365585,   -- Expunge
                374251,   -- Cauterizing Flame
                357210,   -- Deep Breath
                { id = 374346, talent = true },   -- Overawe
            },
            HUNTER = {
                147362,   -- Counter Shot
                { id = 19801, talent = true, note = "Tranquilizing Shot covers both enrages" },   -- Tranquilizing Shot
                109215,   -- Posthaste
                { id = 459517, talent = true },   -- Emergency Salve
            },
            MAGE = {
                2139,     -- Counterspell
                { id = 475, talent = true, note = "Remove Curse -- Insatiable Hunger" },   -- Remove Curse
                { id = 30449, talent = true },   -- Spellsteal
                1953,     -- Blink
                { id = 386828, talent = true },   -- Energized Barriers
            },
            MONK = {
                116705,   -- Spear Hand Strike
                116841,   -- Tiger's Lust
                { id = 450432, talent = true },   -- Pressure Points
                { id = 450622, talent = true },   -- Swift Art
            },
            PALADIN = {
                96231,    -- Rebuke
                { id = 1044, talent = true, note = "Blessing of Freedom beats Glacial Tomb outright" },   -- Blessing of Freedom
                { id = 469321, talent = true },   -- Righteous Protection
                { id = 1022, talent = true },   -- Blessing of Protection
                { id = 469304, talent = true },   -- Steed of Liberty
            },
            PRIEST = {
                { id = 15487, talent = true, note = "Shadow interrupt" },   -- Silence
                32375,    -- Mass Dispel
                { id = 528, talent = true },   -- Dispel Magic
                { id = 108942, talent = true },   -- Phantasm
            },
            ROGUE = {
                1766,     -- Kick
                8679,     -- Wound Poison
                1856,     -- Vanish
                5938,     -- Shiv
                31224,    -- Cloak of Shadows
            },
            SHAMAN = {
                57994,    -- Wind Shear
                { id = 370, talent = true },   -- Purge
                { id = 383013, talent = true },   -- Poison Cleansing Totem
                { id = 462817, talent = true },   -- Jet Stream for Wind Rush Totem  [snare_jet]
                58875,    -- Spirit Walk
                { id = 378075, talent = true },   -- Thunderous Paws
            },
            WARLOCK = {
                19647,    -- Spell Lock
                19505,    -- Devour Magic (pet)
                { id = 268358, talent = true },   -- Demonic Circle
            },
            WARRIOR = {
                6552,     -- Pummel
                1271925,  -- Fearless
            },
        },
        bySpec = {
            [65] = {
                { id = 393024, talent = true },   -- Improved Cleanse
            },
            [66] = {
                204018,   -- Blessing of Spellwarding
                { id = 213644, talent = true },   -- Cleanse Toxins
            },
            [70] = {
                { id = 213644, talent = true },   -- Cleanse Toxins
            },
            [71] = {
                12294,    -- Mortal Strike
            },
            [102] = {
                { id = 2782, talent = true, note = "Insatiable Hunger is a curse, not a poison" },   -- Remove Corruption
            },
            [103] = {
                { id = 2782, talent = true, note = "Insatiable Hunger is a curse, not a poison" },   -- Remove Corruption
            },
            [104] = {
                { id = 2782, talent = true, note = "Insatiable Hunger is a curse, not a poison" },   -- Remove Corruption
            },
            [105] = {
                { id = 392378, talent = true },   -- Improved Nature's Cure
            },
            [253] = {
                { id = 53271, talent = true },   -- Master's Call (pet)
            },
            [255] = {
                { id = 53271, talent = true },   -- Master's Call (pet)
            },
            [258] = {
                { id = 47585, talent = true },   -- Dispersion
            },
            [262] = {
                { id = 51886, talent = true },   -- Cleanse Spirit
            },
            [263] = {
                { id = 51886, talent = true },   -- Cleanse Spirit
            },
            [264] = {
                { id = 383016, talent = true },   -- Improved Purify Spirit
            },
            [268] = {
                { id = 218164, talent = true },   -- Detox
            },
            [269] = {
                107428,   -- Rising Sun Kick
                { id = 218164, talent = true },   -- Detox
            },
            [270] = {
                { id = 388874, talent = true },   -- Improved Detox
            },
            [1468] = {
                403631,   -- Dream Flight
            },
            [1473] = {
                403631,   -- Breath of Eons
            },
        },
    },

    -- =====================================================
    [1762] = { -- Kings' Rest
        header      = "Kings' Rest",
        lead        = "Purge Bind Soul, strip Ancestral Fury, dispel Wretched Discharge. Then "
                      .. "the curses.",
        description = "Three casts outrank everything else in here, and a group missing them "
                      .. "notices: Bind Soul is a purge, Ancestral Fury is an enrage, Wretched "
                      .. "Discharge is a disease. Hex and Hex Volley are curses. Unholy Mending "
                      .. "and Healing Tide Totem are heals to pressure -- Mortal Wounds, then kill "
                      .. "the totem. Overload wants a grip. Deathly Roar and Pit of Despair are "
                      .. "fears. Bleeds never stop: Severing Axe, Whirling Axe, Impaling Spear, "
                      .. "Savage Maul, Mortal Bleed and Sudden Rupture.",
        byClass = {
            DEATHKNIGHT = {
                47528,    -- Mind Freeze
                45524,    -- Chains of Ice
                49576,    -- Death Grip
                221562,   -- Asphyxiate
                { id = 273952, talent = true },   -- Grip of the Dead
                { id = 454786, talent = true },   -- Ice Prison
                49039,    -- Lichborne
            },
            DEMONHUNTER = {
                183752,   -- Disrupt
                { id = 278326, talent = true, note = "Consume Magic -- Bind Soul" },   -- Consume Magic
                { id = 1266316, talent = true },   -- Burn It Out
                { id = 1266496, talent = true },   -- Soul Cleanse
                198793,   -- Vengeful Retreat
            },
            DRUID = {
                106839,   -- Skull Bash
                5211,     -- Mighty Bash
                22570,    -- Maim
                { id = 2908, talent = true, note = "Ancestral Fury -- the enrage that matters most in here" },   -- Soothe
                { id = 102793, talent = true },   -- Ursol's Vortex
                { id = 132469, talent = true },   -- Typhoon
                768,      -- Cat Form (as a general shapeshift)
            },
            EVOKER = {
                351338,   -- Quell
                368970,   -- Tail Swipe
                374251,   -- Cauterizing Flame
                { id = 374346, talent = true },   -- Overawe
                { id = 387341, talent = true },   -- Walloping Blow
                365585,   -- Expunge
                357210,   -- Deep Breath
            },
            HUNTER = {
                147362,   -- Counter Shot
                195645,   -- Wing Clip
                { id = 19801, talent = true, note = "Tranquilizing Shot -- Ancestral Fury" },   -- Tranquilizing Shot
                { id = 187698, talent = true },   -- Tar Trap
                5384,     -- Feign Death
                { id = 459517, talent = true },   -- Emergency Salve
                109215,   -- Posthaste
            },
            MAGE = {
                2139,     -- Counterspell
                120,      -- Cone of Cold
                { id = 475, talent = true, note = "Hex and Hex Volley are both curses" },   -- Remove Curse
                { id = 30449, talent = true },   -- Spellsteal
                { id = 157980, talent = true },   -- Supernova
                { id = 110959, talent = true },   -- Greater Invisibility
                { id = 386828, talent = true },   -- Energized Barriers
            },
            MONK = {
                116705,   -- Spear Hand Strike
                119381,   -- Leg Sweep
                { id = 116095, talent = true },   -- Disable
                { id = 116844, talent = true },   -- Ring of Peace
                { id = 450432, talent = true },   -- Pressure Points
                { id = 450595, talent = true },   -- Spirit's Essence
                116841,   -- Tiger's Lust
            },
            PALADIN = {
                96231,    -- Rebuke
                853,      -- Hammer of Justice
                { id = 1022, talent = true },   -- Blessing of Protection
                { id = 469321, talent = true },   -- Righteous Protection
                { id = 1044, talent = true },   -- Blessing of Freedom
                { id = 469304, talent = true },   -- Steed of Liberty
            },
            PRIEST = {
                { id = 15487, talent = true, note = "Shadow interrupt" },   -- Silence
                { id = 32375, note = "Mass Dispel answers Bind Soul across a pack" },   -- Mass Dispel
                { id = 528, talent = true, note = "Bind Soul is the purge that matters" },   -- Dispel Magic
                { id = 108942, talent = true },   -- Phantasm
            },
            ROGUE = {
                1766,     -- Kick
                408,      -- Kidney Shot
                3408,     -- Crippling Poison
                { id = 5938, note = "Shiv -- Ancestral Fury" },   -- Shiv
                8679,     -- Wound Poison
                1856,     -- Vanish
                31224,    -- Cloak of Shadows
            },
            SHAMAN = {
                57994,    -- Wind Shear
                2484,     -- Earthbind Totem
                192058,   -- Capacitor Totem
                { id = 370, talent = true },   -- Purge
                { id = 51485, talent = true },   -- Earthgrab Totem
                { id = 8143, talent = true },   -- Tremor Totem
                { id = 383013, talent = true },   -- Poison Cleansing Totem
            },
            WARLOCK = {
                19647,    -- Spell Lock
                19505,    -- Devour Magic (pet)
                30283,    -- Shadowfury
                { id = 334275, talent = true },   -- Curse of Exhaustion
                { id = 268358, talent = true },   -- Demonic Circle
            },
            WARRIOR = {
                6552,     -- Pummel
                46968,    -- Shockwave
                107570,   -- Storm Bolt
                { id = 12323, talent = true },   -- Piercing Howl
                18499,    -- Berserker Rage
                { id = 384100, talent = true },   -- Berserker Shout
                1271925,  -- Fearless
            },
        },
        bySpec = {
            [65] = {
                { id = 393024, talent = true },   -- Improved Cleanse
            },
            [66] = {
                204018,   -- Blessing of Spellwarding
                { id = 213644, talent = true },   -- Cleanse Toxins
            },
            [70] = {
                { id = 213644, talent = true },   -- Cleanse Toxins
            },
            [71] = {
                12294,    -- Mortal Strike
            },
            [102] = {
                { id = 2782, talent = true, note = "Hex Volley goes out to the whole group" },   -- Remove Corruption
            },
            [103] = {
                { id = 2782, talent = true, note = "Hex Volley goes out to the whole group" },   -- Remove Corruption
            },
            [104] = {
                { id = 2782, talent = true, note = "Hex Volley goes out to the whole group" },   -- Remove Corruption
            },
            [105] = {
                { id = 392378, talent = true },   -- Improved Nature's Cure
            },
            [250] = {
                { id = 108199, talent = true },   -- Gorefiend's Grasp
                { id = 1263569, talent = true },   -- Abomination Limb
            },
            [253] = {
                19577,    -- Intimidation
                { id = 53271, talent = true },   -- Master's Call (pet)
            },
            [254] = {
                474421,   -- Intimidation
            },
            [255] = {
                19577,    -- Intimidation
                { id = 53271, talent = true },   -- Master's Call (pet)
            },
            [256] = {
                { id = 390632, talent = true },   -- Improved Purify
            },
            [257] = {
                { id = 390632, talent = true },   -- Improved Purify
            },
            [258] = {
                { id = 213634, talent = true },   -- Purify Disease
                { id = 47585, talent = true },   -- Dispersion
            },
            [262] = {
                51490,    -- Thunderstorm
                { id = 51886, talent = true },   -- Cleanse Spirit
            },
            [263] = {
                { id = 51886, talent = true },   -- Cleanse Spirit
            },
            [264] = {
                { id = 383016, talent = true },   -- Improved Purify Spirit
            },
            [266] = {
                89766,    -- Axe Toss (pet)
            },
            [268] = {
                { id = 218164, talent = true },   -- Detox
            },
            [269] = {
                107428,   -- Rising Sun Kick
                { id = 218164, talent = true },   -- Detox
            },
            [270] = {
                { id = 388874, talent = true },   -- Improved Detox
            },
            [577] = {
                179057,   -- Chaos Nova
            },
            [581] = {
                179057,   -- Chaos Nova
            },
            [1468] = {
                403631,   -- Dream Flight
            },
            [1473] = {
                403631,   -- Breath of Eons
            },
            [1480] = {
                1234195,  -- Void Nova
            },
        },
    },

    -- =====================================================
    [2813] = { -- Murder Row
        header      = "Murder Row",
        lead        = "Curse of Doom decides the pull. Poison cleanses and enrage removal "
                      .. "behind it.",
        description = "Curse of Doom is flagged above everything else here, and a group with no "
                      .. "curse dispel will feel it on every pull. Heartstop Poison comes off the "
                      .. "boss and off trash, so poison removal is close behind. Seduction is a "
                      .. "sleep cast by a demon: interrupt it, or CC the demon -- one of the few "
                      .. "places Imprison and Banish are literally the right button. Fel Rage and "
                      .. "Back to Work! are enrages, Fel Crazed is a purge, and Health Funnel "
                      .. "wants Mortal Wounds and a body out of the beam.",
        byClass = {
            DEATHKNIGHT = {
                47528,    -- Mind Freeze
                49576,    -- Death Grip
                221562,   -- Asphyxiate
                { id = 207167, talent = true },   -- Blinding Sleet
                49039,    -- Lichborne
            },
            DEMONHUNTER = {
                183752,   -- Disrupt
                207684,   -- Sigil of Misery
                { id = 217832, note = "Imprison genuinely applies: Seduction is cast by a demon" },   -- Imprison
                { id = 278326, talent = true },   -- Consume Magic
                { id = 1266496, talent = true },   -- Soul Cleanse
            },
            DRUID = {
                106839,   -- Skull Bash
                5211,     -- Mighty Bash
                22570,    -- Maim
                { id = 99, talent = true },   -- Incapacitating Roar
                { id = 2908, talent = true, note = "Fel Rage and Back to Work!" },   -- Soothe
                { id = 132469, talent = true },   -- Typhoon
            },
            EVOKER = {
                351338,   -- Quell
                365585,   -- Expunge
                368970,   -- Tail Swipe
                374251,   -- Cauterizing Flame
                { id = 374346, talent = true },   -- Overawe
            },
            HUNTER = {
                147362,   -- Counter Shot
                { id = 19801, talent = true },   -- Tranquilizing Shot
                { id = 459517, talent = true },   -- Emergency Salve
                5384,     -- Feign Death
            },
            MAGE = {
                2139,     -- Counterspell
                { id = 475, talent = true, note = "Curse of Doom -- the dispel this dungeon is built around" },   -- Remove Curse
                { id = 31661, talent = true },   -- Dragon's Breath
                { id = 113724, talent = true },   -- Ring of Frost
                { id = 157980, talent = true },   -- Supernova
                { id = 30449, talent = true },   -- Spellsteal
                { id = 110959, talent = true },   -- Greater Invisibility
            },
            MONK = {
                116705,   -- Spear Hand Strike
                119381,   -- Leg Sweep
                { id = 116844, talent = true },   -- Ring of Peace
                { id = 198898, talent = true },   -- Song of Chi-Ji
                { id = 450432, talent = true },   -- Pressure Points
            },
            PALADIN = {
                96231,    -- Rebuke
                853,      -- Hammer of Justice
                { id = 115750, talent = true },   -- Blinding Light
                { id = 469321, talent = true },   -- Righteous Protection
                { id = 1022, talent = true },   -- Blessing of Protection
            },
            PRIEST = {
                { id = 15487, talent = true, note = "Shadow interrupt" },   -- Silence
                8122,     -- Psychic Scream
                32375,    -- Mass Dispel
                { id = 528, talent = true },   -- Dispel Magic
            },
            ROGUE = {
                1766,     -- Kick
                408,      -- Kidney Shot
                5938,     -- Shiv
                8679,     -- Wound Poison
                31224,    -- Cloak of Shadows
                1856,     -- Vanish
            },
            SHAMAN = {
                57994,    -- Wind Shear
                192058,   -- Capacitor Totem
                { id = 8143, talent = true },   -- Tremor Totem
                { id = 383013, talent = true },   -- Poison Cleansing Totem
                { id = 370, talent = true },   -- Purge
            },
            WARLOCK = {
                19647,    -- Spell Lock
                5782,     -- Fear
                6789,     -- Mortal Coil
                30283,    -- Shadowfury
                { id = 5484, talent = true },   -- Howl of Terror
                19505,    -- Devour Magic (pet)
            },
            WARRIOR = {
                6552,     -- Pummel
                46968,    -- Shockwave
                107570,   -- Storm Bolt
                { id = 5246, talent = true },   -- Intimidating Shout
            },
        },
        bySpec = {
            [65] = {
                { id = 393024, talent = true },   -- Improved Cleanse
            },
            [66] = {
                204018,   -- Blessing of Spellwarding
                { id = 213644, talent = true },   -- Cleanse Toxins
            },
            [70] = {
                { id = 213644, talent = true },   -- Cleanse Toxins
            },
            [71] = {
                12294,    -- Mortal Strike
            },
            [102] = {
                { id = 2782, talent = true, note = "Curse of Doom, before anything else" },   -- Remove Corruption
            },
            [103] = {
                { id = 2782, talent = true, note = "Curse of Doom, before anything else" },   -- Remove Corruption
            },
            [104] = {
                { id = 2782, talent = true, note = "Curse of Doom, before anything else" },   -- Remove Corruption
            },
            [105] = {
                { id = 392378, talent = true },   -- Improved Nature's Cure
            },
            [250] = {
                { id = 108199, talent = true },   -- Gorefiend's Grasp
                { id = 1263569, talent = true },   -- Abomination Limb
            },
            [253] = {
                19577,    -- Intimidation
            },
            [254] = {
                474421,   -- Intimidation
            },
            [255] = {
                19577,    -- Intimidation
            },
            [262] = {
                51490,    -- Thunderstorm
                { id = 51886, talent = true, note = "Cleanse Spirit -- Curse of Doom" },   -- Cleanse Spirit
            },
            [263] = {
                { id = 51886, talent = true, note = "Cleanse Spirit -- Curse of Doom" },   -- Cleanse Spirit
            },
            [264] = {
                { id = 383016, talent = true },   -- Improved Purify Spirit
            },
            [266] = {
                89766,    -- Axe Toss (pet)
            },
            [268] = {
                { id = 218164, talent = true, note = "Detox -- Heartstop Poison" },   -- Detox
            },
            [269] = {
                { id = 218164, talent = true, note = "Detox -- Heartstop Poison" },   -- Detox
                107428,   -- Rising Sun Kick
            },
            [270] = {
                { id = 388874, talent = true },   -- Improved Detox
            },
            [577] = {
                179057,   -- Chaos Nova
            },
            [581] = {
                179057,   -- Chaos Nova
            },
            [1480] = {
                1234195,  -- Void Nova
            },
        },
    },

    -- =====================================================
    [2521] = { -- Ruby Life Pools
        header      = "Ruby Life Pools",
        lead        = "Stop Flaming Barrage with hard CC, purge the shields, walk out of "
                      .. "Inferno.",
        description = "Flaming Barrage is the cast that kills people, and every kind of hard "
                      .. "control works on it -- stun, fear, incapacitate or grip the humanoid "
                      .. "casting it. Blaze of Glory and Stormcloud Barrier are purges, and Ice "
                      .. "Shield sits on a humanoid you can simply CC instead. Inferno is pure "
                      .. "movement. Cold Claws snares and Blazing Rush bleeds, but neither decides "
                      .. "a pull. Light on dispels, heavy on control.",
        byClass = {
            DEATHKNIGHT = {
                47528,    -- Mind Freeze
                49576,    -- Death Grip
                221562,   -- Asphyxiate
                { id = 207167, talent = true },   -- Blinding Sleet
            },
            DEMONHUNTER = {
                183752,   -- Disrupt
                207684,   -- Sigil of Misery
                217832,   -- Imprison
                { id = 278326, talent = true, note = "Consume Magic -- Blaze of Glory and Stormcloud Barrier" },   -- Consume Magic
                198793,   -- Vengeful Retreat
            },
            DRUID = {
                106839,   -- Skull Bash
                5211,     -- Mighty Bash
                22570,    -- Maim
                { id = 99, talent = true },   -- Incapacitating Roar
                { id = 132469, talent = true },   -- Typhoon
                768,      -- Cat Form (as a general shapeshift)
            },
            EVOKER = {
                351338,   -- Quell
                368970,   -- Tail Swipe
                374251,   -- Cauterizing Flame
                357210,   -- Deep Breath
            },
            HUNTER = {
                147362,   -- Counter Shot
                5384,     -- Feign Death
                { id = 19801, talent = true },   -- Tranquilizing Shot
                109215,   -- Posthaste
            },
            MAGE = {
                2139,     -- Counterspell
                { id = 31661, talent = true },   -- Dragon's Breath
                { id = 113724, talent = true },   -- Ring of Frost
                { id = 157980, talent = true },   -- Supernova
                { id = 30449, talent = true, note = "Spellsteal -- Stormcloud Barrier is worth taking" },   -- Spellsteal
                { id = 110959, talent = true },   -- Greater Invisibility
                { id = 386828, talent = true },   -- Energized Barriers
            },
            MONK = {
                116705,   -- Spear Hand Strike
                { id = 119381, note = "Leg Sweep into Flaming Barrage" },   -- Leg Sweep
                { id = 116844, talent = true },   -- Ring of Peace
                { id = 198898, talent = true },   -- Song of Chi-Ji
                116841,   -- Tiger's Lust
                { id = 450622, talent = true },   -- Swift Art
            },
            PALADIN = {
                96231,    -- Rebuke
                853,      -- Hammer of Justice
                { id = 115750, talent = true },   -- Blinding Light
                { id = 1022, talent = true },   -- Blessing of Protection
                { id = 1044, talent = true },   -- Blessing of Freedom
                { id = 469304, talent = true },   -- Steed of Liberty
            },
            PRIEST = {
                { id = 15487, talent = true, note = "Shadow interrupt" },   -- Silence
                8122,     -- Psychic Scream
                32375,    -- Mass Dispel
                { id = 528, talent = true, note = "Two shields worth purging" },   -- Dispel Magic
                { id = 108942, talent = true },   -- Phantasm
            },
            ROGUE = {
                1766,     -- Kick
                408,      -- Kidney Shot
                1856,     -- Vanish
                31224,    -- Cloak of Shadows
            },
            SHAMAN = {
                57994,    -- Wind Shear
                192058,   -- Capacitor Totem
                { id = 370, talent = true },   -- Purge
                { id = 462817, talent = true },   -- Jet Stream for Wind Rush Totem  [snare_jet]
                58875,    -- Spirit Walk
                { id = 378075, talent = true },   -- Thunderous Paws
            },
            WARLOCK = {
                19647,    -- Spell Lock
                5782,     -- Fear
                6789,     -- Mortal Coil
                30283,    -- Shadowfury
                { id = 5484, talent = true },   -- Howl of Terror
                19505,    -- Devour Magic (pet)
                { id = 268358, talent = true },   -- Demonic Circle
            },
            WARRIOR = {
                6552,     -- Pummel
                { id = 46968, note = "Shockwave -- the Flaming Barrage packs" },   -- Shockwave
                107570,   -- Storm Bolt
                { id = 5246, talent = true },   -- Intimidating Shout
                1271925,  -- Fearless
            },
        },
        bySpec = {
            [66] = {
                204018,   -- Blessing of Spellwarding
            },
            [250] = {
                { id = 108199, talent = true },   -- Gorefiend's Grasp
                { id = 1263569, talent = true },   -- Abomination Limb
            },
            [253] = {
                19577,    -- Intimidation
                { id = 53271, talent = true },   -- Master's Call (pet)
            },
            [254] = {
                474421,   -- Intimidation
            },
            [255] = {
                19577,    -- Intimidation
                { id = 53271, talent = true },   -- Master's Call (pet)
            },
            [258] = {
                { id = 47585, talent = true },   -- Dispersion
            },
            [262] = {
                51490,    -- Thunderstorm
            },
            [266] = {
                89766,    -- Axe Toss (pet)
            },
            [577] = {
                { id = 179057, note = "Chaos Nova into Flaming Barrage" },   -- Chaos Nova
            },
            [581] = {
                { id = 179057, note = "Chaos Nova into Flaming Barrage" },   -- Chaos Nova
            },
            [1468] = {
                403631,   -- Dream Flight
            },
            [1473] = {
                403631,   -- Breath of Eons
            },
            [1480] = {
                1234195,  -- Void Nova
            },
        },
    },

    -- =====================================================
    [1877] = { -- Temple of Sethraliss
        header      = "Temple of Sethraliss",
        lead        = "Poison dispels throughout, a curse on Addle Mind, CC for the snakes and "
                      .. "archers.",
        description = "Poison is the through-line: Poison Spit on the boss, Cytotoxin and "
                      .. "Poisoned Cheap Shot from trash. Addle Mind is the curse. A Knot of "
                      .. "Snakes is a beast pack, so beast CC and grips gather it. Arrow Barrage "
                      .. "wants the archer stunned and everyone out of the line, which makes it a "
                      .. "control check and a movement check at once. Accumulate Charge is a "
                      .. "purge, Serrated Charge bleeds, and Shrouded Fang patrols stealthed if "
                      .. "you keep getting jumped on the way in.",
        byClass = {
            DEATHKNIGHT = {
                47528,    -- Mind Freeze
                45524,    -- Chains of Ice
                49576,    -- Death Grip
                221562,   -- Asphyxiate
                { id = 207167, talent = true },   -- Blinding Sleet
                { id = 273952, talent = true },   -- Grip of the Dead
                { id = 454786, talent = true },   -- Ice Prison
            },
            DEMONHUNTER = {
                183752,   -- Disrupt
                207684,   -- Sigil of Misery
                217832,   -- Imprison
                188501,   -- Spectral Sight
                { id = 278326, talent = true },   -- Consume Magic
                { id = 1266496, talent = true },   -- Soul Cleanse
            },
            DRUID = {
                106839,   -- Skull Bash
                5211,     -- Mighty Bash
                22570,    -- Maim
                { id = 99, talent = true },   -- Incapacitating Roar
                { id = 102793, talent = true },   -- Ursol's Vortex
                { id = 132469, talent = true },   -- Typhoon
            },
            EVOKER = {
                351338,   -- Quell
                365585,   -- Expunge
                368970,   -- Tail Swipe
                374251,   -- Cauterizing Flame
                { id = 387341, talent = true },   -- Walloping Blow
            },
            HUNTER = {
                147362,   -- Counter Shot
                195645,   -- Wing Clip
                { id = 187698, talent = true },   -- Tar Trap
                1543,     -- Flare
                5384,     -- Feign Death
                { id = 19801, talent = true },   -- Tranquilizing Shot
                { id = 459517, talent = true },   -- Emergency Salve
            },
            MAGE = {
                2139,     -- Counterspell
                120,      -- Cone of Cold
                { id = 475, talent = true, note = "Addle Mind is a curse" },   -- Remove Curse
                { id = 31661, talent = true },   -- Dragon's Breath
                { id = 113724, talent = true },   -- Ring of Frost
                { id = 157980, talent = true },   -- Supernova
                { id = 30449, talent = true },   -- Spellsteal
            },
            MONK = {
                116705,   -- Spear Hand Strike
                119381,   -- Leg Sweep
                { id = 116095, talent = true },   -- Disable
                { id = 116844, talent = true },   -- Ring of Peace
                { id = 198898, talent = true },   -- Song of Chi-Ji
                { id = 450595, talent = true },   -- Spirit's Essence
            },
            PALADIN = {
                96231,    -- Rebuke
                853,      -- Hammer of Justice
                { id = 1022, talent = true },   -- Blessing of Protection
                { id = 115750, talent = true },   -- Blinding Light
                { id = 469321, talent = true },   -- Righteous Protection
            },
            PRIEST = {
                { id = 15487, talent = true, note = "Shadow interrupt" },   -- Silence
                8122,     -- Psychic Scream
                32375,    -- Mass Dispel
                { id = 528, talent = true },   -- Dispel Magic
            },
            ROGUE = {
                1766,     -- Kick
                408,      -- Kidney Shot
                3408,     -- Crippling Poison
                1856,     -- Vanish
                31224,    -- Cloak of Shadows
            },
            SHAMAN = {
                57994,    -- Wind Shear
                2484,     -- Earthbind Totem
                192058,   -- Capacitor Totem
                { id = 51485, talent = true },   -- Earthgrab Totem
                { id = 383013, talent = true },   -- Poison Cleansing Totem
                { id = 370, talent = true },   -- Purge
            },
            WARLOCK = {
                19647,    -- Spell Lock
                5782,     -- Fear
                6789,     -- Mortal Coil
                30283,    -- Shadowfury
                { id = 5484, talent = true },   -- Howl of Terror
                { id = 334275, talent = true },   -- Curse of Exhaustion
                19505,    -- Devour Magic (pet)
            },
            WARRIOR = {
                6552,     -- Pummel
                46968,    -- Shockwave
                107570,   -- Storm Bolt
                { id = 5246, talent = true },   -- Intimidating Shout
                { id = 12323, talent = true },   -- Piercing Howl
            },
        },
        bySpec = {
            [65] = {
                { id = 393024, talent = true },   -- Improved Cleanse
            },
            [66] = {
                204018,   -- Blessing of Spellwarding
                { id = 213644, talent = true, note = "Cleanse Toxins -- poison is everywhere here" },   -- Cleanse Toxins
            },
            [70] = {
                { id = 213644, talent = true, note = "Cleanse Toxins -- poison is everywhere here" },   -- Cleanse Toxins
            },
            [102] = {
                { id = 2782, talent = true, note = "Addle Mind and the poisons, on one talent" },   -- Remove Corruption
            },
            [103] = {
                { id = 2782, talent = true, note = "Addle Mind and the poisons, on one talent" },   -- Remove Corruption
            },
            [104] = {
                { id = 2782, talent = true, note = "Addle Mind and the poisons, on one talent" },   -- Remove Corruption
            },
            [105] = {
                { id = 392378, talent = true },   -- Improved Nature's Cure
            },
            [250] = {
                { id = 108199, talent = true },   -- Gorefiend's Grasp
                { id = 1263569, talent = true },   -- Abomination Limb
            },
            [253] = {
                19577,    -- Intimidation
            },
            [254] = {
                474421,   -- Intimidation
            },
            [255] = {
                19577,    -- Intimidation
            },
            [262] = {
                51490,    -- Thunderstorm
                { id = 51886, talent = true },   -- Cleanse Spirit
            },
            [263] = {
                { id = 51886, talent = true },   -- Cleanse Spirit
            },
            [264] = {
                { id = 383016, talent = true },   -- Improved Purify Spirit
            },
            [266] = {
                89766,    -- Axe Toss (pet)
            },
            [268] = {
                { id = 218164, talent = true, note = "Detox -- Cytotoxin and Poison Spit" },   -- Detox
            },
            [269] = {
                { id = 218164, talent = true, note = "Detox -- Cytotoxin and Poison Spit" },   -- Detox
            },
            [270] = {
                { id = 388874, talent = true },   -- Improved Detox
            },
            [577] = {
                179057,   -- Chaos Nova
            },
            [581] = {
                179057,   -- Chaos Nova
            },
            [1480] = {
                1234195,  -- Void Nova
            },
        },
    },

    -- =====================================================
    [2859] = { -- The Blinding Vale
        header      = "The Blinding Vale",
        lead        = "The bleed dungeon. Freedom for Bloodthorn Roots, a poison dispel for "
                      .. "Toxic Spew.",
        description = "Bleeds define this place. Thornblade, Incise, Grievous Thrash, "
                      .. "Thornspike and Grievous Gash all stack physical damage that most classes "
                      .. "cannot dispel at all, so the real answers are the immunities: Blessing "
                      .. "of Protection, Ice Block, Cloak of Shadows. Bloodthorn Roots pins you, "
                      .. "so bring freedom. Toxic Spew is the poison. Lightbloom Pollination is a "
                      .. "heal that wants Mortal Wounds, Lightmaw Beams is movement, and "
                      .. "Potad-Toss goes on an elemental, so elemental CC applies.",
        byClass = {
            DEATHKNIGHT = {
                47528,    -- Mind Freeze
                49576,    -- Death Grip
                221562,   -- Asphyxiate
                { id = 207167, talent = true },   -- Blinding Sleet
                { id = 212552, talent = true },   -- Wraith Walk
            },
            DEMONHUNTER = {
                183752,   -- Disrupt
                207684,   -- Sigil of Misery
                198793,   -- Vengeful Retreat
            },
            DRUID = {
                106839,   -- Skull Bash
                768,      -- Cat Form (as a general shapeshift)
                5211,     -- Mighty Bash
                22570,    -- Maim
                { id = 99, talent = true },   -- Incapacitating Roar
                { id = 132469, talent = true },   -- Typhoon
            },
            EVOKER = {
                351338,   -- Quell
                365585,   -- Expunge
                { id = 374251, note = "Cauterizing Flame -- bleed and poison in one" },   -- Cauterizing Flame
                357210,   -- Deep Breath
                368970,   -- Tail Swipe
            },
            HUNTER = {
                147362,   -- Counter Shot
                5384,     -- Feign Death
                109215,   -- Posthaste
                { id = 459517, talent = true },   -- Emergency Salve
            },
            MAGE = {
                2139,     -- Counterspell
                1953,     -- Blink
                { id = 31661, talent = true },   -- Dragon's Breath
                { id = 110959, talent = true },   -- Greater Invisibility
                { id = 113724, talent = true },   -- Ring of Frost
                { id = 157980, talent = true },   -- Supernova
                { id = 386828, talent = true },   -- Energized Barriers
            },
            MONK = {
                116705,   -- Spear Hand Strike
                116841,   -- Tiger's Lust
                119381,   -- Leg Sweep
                { id = 116844, talent = true },   -- Ring of Peace
                { id = 198898, talent = true },   -- Song of Chi-Ji
                { id = 450622, talent = true },   -- Swift Art
            },
            PALADIN = {
                96231,    -- Rebuke
                { id = 1022, talent = true, note = "Blessing of Protection clears the bleed stack outright" },   -- Blessing of Protection
                { id = 1044, talent = true, note = "Blessing of Freedom -- Bloodthorn Roots" },   -- Blessing of Freedom
                { id = 469321, talent = true },   -- Righteous Protection
                853,      -- Hammer of Justice
                { id = 115750, talent = true },   -- Blinding Light
                { id = 469304, talent = true },   -- Steed of Liberty
            },
            PRIEST = {
                { id = 15487, talent = true, note = "Shadow interrupt" },   -- Silence
                8122,     -- Psychic Scream
                { id = 108942, talent = true },   -- Phantasm
            },
            ROGUE = {
                1766,     -- Kick
                8679,     -- Wound Poison
                408,      -- Kidney Shot
                1856,     -- Vanish
                { id = 31224, note = "Cloak of Shadows clears the bleed stack" },   -- Cloak of Shadows
            },
            SHAMAN = {
                57994,    -- Wind Shear
                { id = 383013, talent = true },   -- Poison Cleansing Totem
                58875,    -- Spirit Walk
                192058,   -- Capacitor Totem
                { id = 462817, talent = true },   -- Jet Stream for Wind Rush Totem  [snare_jet]
                { id = 378075, talent = true },   -- Thunderous Paws
            },
            WARLOCK = {
                19647,    -- Spell Lock
                5782,     -- Fear
                6789,     -- Mortal Coil
                30283,    -- Shadowfury
                { id = 5484, talent = true },   -- Howl of Terror
                { id = 268358, talent = true },   -- Demonic Circle
            },
            WARRIOR = {
                6552,     -- Pummel
                46968,    -- Shockwave
                107570,   -- Storm Bolt
                1271925,  -- Fearless
                { id = 5246, talent = true },   -- Intimidating Shout
            },
        },
        bySpec = {
            [65] = {
                { id = 393024, talent = true },   -- Improved Cleanse
            },
            [66] = {
                204018,   -- Blessing of Spellwarding
                { id = 213644, talent = true },   -- Cleanse Toxins
            },
            [70] = {
                { id = 213644, talent = true },   -- Cleanse Toxins
            },
            [71] = {
                12294,    -- Mortal Strike
            },
            [102] = {
                { id = 2782, talent = true },   -- Remove Corruption
            },
            [103] = {
                { id = 2782, talent = true },   -- Remove Corruption
            },
            [104] = {
                { id = 2782, talent = true },   -- Remove Corruption
            },
            [105] = {
                { id = 392378, talent = true },   -- Improved Nature's Cure
            },
            [250] = {
                { id = 108199, talent = true },   -- Gorefiend's Grasp
                { id = 1263569, talent = true },   -- Abomination Limb
            },
            [253] = {
                { id = 53271, talent = true },   -- Master's Call (pet)
                19577,    -- Intimidation
            },
            [254] = {
                474421,   -- Intimidation
            },
            [255] = {
                { id = 53271, talent = true },   -- Master's Call (pet)
                19577,    -- Intimidation
            },
            [258] = {
                { id = 47585, talent = true },   -- Dispersion
            },
            [262] = {
                51490,    -- Thunderstorm
            },
            [266] = {
                89766,    -- Axe Toss (pet)
            },
            [268] = {
                { id = 218164, talent = true },   -- Detox
            },
            [269] = {
                107428,   -- Rising Sun Kick
                { id = 218164, talent = true },   -- Detox
            },
            [270] = {
                { id = 388874, talent = true },   -- Improved Detox
            },
            [577] = {
                179057,   -- Chaos Nova
            },
            [581] = {
                179057,   -- Chaos Nova
            },
            [1468] = {
                403631,   -- Dream Flight
            },
            [1473] = {
                403631,   -- Breath of Eons
            },
            [1480] = {
                1234195,  -- Void Nova
            },
        },
    },

    -- =====================================================
    [2923] = { -- Voidscar Arena
        header      = "Voidscar Arena",
        lead        = "Three separate enrages, poison throughout, and Shell Guard wants beast "
                      .. "CC.",
        description = "Bloodsurge, Bolster and Feral Rage are three different enrages, which is "
                      .. "what turns a Soothe or a Tranquilizing Shot from nice-to-have into a "
                      .. "slot worth spending. Poison Splash and Mind-Numbing Poison come off the "
                      .. "boss and Corrosive Essence off trash. Devour and Mending Void are "
                      .. "channels -- stop them, and put Mortal Wounds on whatever is healing. "
                      .. "Shell Guard sits on a beast, so beast CC and Cyclone both apply. Mad "
                      .. "Shriek is a physical fear, Void Beam is movement.",
        byClass = {
            DEATHKNIGHT = {
                47528,    -- Mind Freeze
                45524,    -- Chains of Ice
                49576,    -- Death Grip
                221562,   -- Asphyxiate
                { id = 207167, talent = true },   -- Blinding Sleet
                { id = 273952, talent = true },   -- Grip of the Dead
                { id = 454786, talent = true },   -- Ice Prison
            },
            DEMONHUNTER = {
                183752,   -- Disrupt
                207684,   -- Sigil of Misery
                217832,   -- Imprison
                198793,   -- Vengeful Retreat
            },
            DRUID = {
                106839,   -- Skull Bash
                339,      -- Entangling Roots
                5211,     -- Mighty Bash
                22570,    -- Maim
                { id = 99, talent = true },   -- Incapacitating Roar
                { id = 2637, talent = true, note = "Hibernate -- Shell Guard is on a beast" },   -- Hibernate
                { id = 2908, talent = true, note = "Three enrages in here. Take it" },   -- Soothe
            },
            EVOKER = {
                351338,   -- Quell
                365585,   -- Expunge
                374251,   -- Cauterizing Flame
                358385,   -- Landslide
                368970,   -- Tail Swipe
                { id = 374346, talent = true },   -- Overawe
                { id = 387341, talent = true },   -- Walloping Blow
            },
            HUNTER = {
                147362,   -- Counter Shot
                109248,   -- Binding Shot
                195645,   -- Wing Clip
                { id = 1513, talent = true },   -- Scare Beast
                { id = 19801, talent = true, note = "Tranquilizing Shot -- three enrages" },   -- Tranquilizing Shot
                { id = 187698, talent = true },   -- Tar Trap
                { id = 459517, talent = true },   -- Emergency Salve
            },
            MAGE = {
                2139,     -- Counterspell
                118,      -- Polymorph
                120,      -- Cone of Cold
                122,      -- Frost Nova
                { id = 31661, talent = true },   -- Dragon's Breath
                { id = 113724, talent = true },   -- Ring of Frost
                { id = 157980, talent = true },   -- Supernova
            },
            MONK = {
                116705,   -- Spear Hand Strike
                116841,   -- Tiger's Lust
                119381,   -- Leg Sweep
                { id = 116095, talent = true },   -- Disable
                { id = 116844, talent = true },   -- Ring of Peace
                { id = 198898, talent = true },   -- Song of Chi-Ji
                { id = 450432, talent = true },   -- Pressure Points
            },
            PALADIN = {
                96231,    -- Rebuke
                { id = 469321, talent = true },   -- Righteous Protection
                853,      -- Hammer of Justice
                { id = 1022, talent = true },   -- Blessing of Protection
                { id = 1044, talent = true },   -- Blessing of Freedom
                { id = 115750, talent = true },   -- Blinding Light
                { id = 469304, talent = true },   -- Steed of Liberty
            },
            PRIEST = {
                { id = 15487, talent = true, note = "Shadow interrupt" },   -- Silence
                8122,     -- Psychic Scream
                { id = 1250691, talent = true },   -- Void Tendrils
                { id = 108942, talent = true },   -- Phantasm
            },
            ROGUE = {
                1766,     -- Kick
                8679,     -- Wound Poison
                408,      -- Kidney Shot
                3408,     -- Crippling Poison
                { id = 5938, note = "Shiv -- three enrages" },   -- Shiv
                31224,    -- Cloak of Shadows
                1856,     -- Vanish
            },
            SHAMAN = {
                57994,    -- Wind Shear
                { id = 383013, talent = true },   -- Poison Cleansing Totem
                2484,     -- Earthbind Totem
                192058,   -- Capacitor Totem
                { id = 8143, talent = true },   -- Tremor Totem
                { id = 51485, talent = true },   -- Earthgrab Totem
                { id = 51514, talent = true },   -- Hex
            },
            WARLOCK = {
                19647,    -- Spell Lock
                5782,     -- Fear
                6789,     -- Mortal Coil
                30283,    -- Shadowfury
                { id = 5484, talent = true },   -- Howl of Terror
                { id = 334275, talent = true },   -- Curse of Exhaustion
                { id = 268358, talent = true },   -- Demonic Circle
            },
            WARRIOR = {
                6552,     -- Pummel
                46968,    -- Shockwave
                107570,   -- Storm Bolt
                { id = 5246, talent = true },   -- Intimidating Shout
                { id = 12323, talent = true },   -- Piercing Howl
                { id = 384100, talent = true },   -- Berserker Shout
                18499,    -- Berserker Rage
            },
        },
        bySpec = {
            [65] = {
                { id = 393024, talent = true },   -- Improved Cleanse
            },
            [66] = {
                204018,   -- Blessing of Spellwarding
                { id = 213644, talent = true },   -- Cleanse Toxins
            },
            [70] = {
                { id = 213644, talent = true },   -- Cleanse Toxins
            },
            [71] = {
                12294,    -- Mortal Strike
            },
            [102] = {
                { id = 2782, talent = true },   -- Remove Corruption
            },
            [103] = {
                { id = 2782, talent = true },   -- Remove Corruption
            },
            [104] = {
                { id = 2782, talent = true },   -- Remove Corruption
            },
            [105] = {
                { id = 392378, talent = true },   -- Improved Nature's Cure
            },
            [250] = {
                { id = 108199, talent = true },   -- Gorefiend's Grasp
                { id = 1263569, talent = true },   -- Abomination Limb
            },
            [253] = {
                19577,    -- Intimidation
                { id = 53271, talent = true },   -- Master's Call (pet)
            },
            [254] = {
                474421,   -- Intimidation
            },
            [255] = {
                19577,    -- Intimidation
                { id = 53271, talent = true },   -- Master's Call (pet)
            },
            [258] = {
                { id = 47585, talent = true },   -- Dispersion
            },
            [262] = {
                51490,    -- Thunderstorm
            },
            [266] = {
                89766,    -- Axe Toss (pet)
            },
            [268] = {
                { id = 218164, talent = true, note = "Detox -- poison on the boss and the trash" },   -- Detox
            },
            [269] = {
                107428,   -- Rising Sun Kick
                { id = 218164, talent = true, note = "Detox -- poison on the boss and the trash" },   -- Detox
            },
            [270] = {
                { id = 388874, talent = true },   -- Improved Detox
            },
            [577] = {
                179057,   -- Chaos Nova
            },
            [581] = {
                179057,   -- Chaos Nova
            },
            [1468] = {
                403631,   -- Dream Flight
            },
            [1473] = {
                403631,   -- Breath of Eons
            },
            [1480] = {
                1234195,  -- Void Nova
            },
        },
    },

}

