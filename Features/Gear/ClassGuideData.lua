local _, ns = ...

------------------------------------------------------------
-- Per-spec stat priority and best-in-slot, from Wowhead's class
-- guides.
--
-- GENERATED FILE - do not hand-edit.
-- Regenerate with:  python Tools/scrape_class_guides.py
--
-- statPriority is per HERO TALENT BUILD. Builds that agree are
-- merged and list both names, so the UI can say which builds a
-- priority covers instead of implying a spec-wide consensus.
--
-- bis rows carry `bonus` (colon-joined bonus IDs) where the guide
-- specifies an upgrade rank. Without those the item resolves at
-- its base item level, not the one the list actually means.
--
-- bis rows carry catalystFrom when the piece is a Catalyst
-- conversion: that is the item you feed in to get this one.
--
-- Item names are NOT stored. They are resolved from the ID at
-- runtime, which localises for free and survives a rename.
------------------------------------------------------------

ns.ClassGuideData = {}
ns.CLASS_GUIDE_SOURCE = "Wowhead class guides"
ns.CLASS_GUIDE_TARGET_SEASON = "Midnight Season 2"
ns.CLASS_GUIDE_SCRAPED_AT = "2026-08-11"

ns.ClassGuideData["DEATHKNIGHT_BLOOD"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "San'layn" },
            context = "",
            stats = {
                "Strength",
                "Haste",
                "Mastery / Critical Strike / Versatility",
            },
        },
        {
            builds = { "Deathbringer" },
            context = "",
            stats = {
                "Strength",
                "Critical Strike",
                "Mastery / Versatility",
                "Haste",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 268213,   source = "The Coiled Altar",            },
        { slot = "Head",        itemID = 271474,   source = "Nek'zali the Soulcoiler",     catalystFrom = 268229, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271472,   source = "Temple of Sethraliss",        catalystFrom = 239037, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271477,   source = "The Coiled Altar",            catalystFrom = 268222, },
        { slot = "Wrist",       itemID = 237834,   source = "Crafting",                    },
        { slot = "Hands",       itemID = 271475,   source = "King's Rest",                 catalystFrom = 159413, },
        { slot = "Waist",       itemID = 268259,   source = "The Coiled Altar",            },
        { slot = "Legs",        itemID = 271878,   source = "Ula'tek",                     },
        { slot = "Feet",        itemID = 273777,   source = "Altar of Fangs",              },
        { slot = "Ring",        itemID = 240949,   source = "Crafting",                    },
        { slot = "Ring",        itemID = 268249,   source = "Vashnik the Malignant",       },
        { slot = "Ring",        itemID = 251194,   source = "Blinding Vale",               },
        { slot = "Trinket",     itemID = 270175,   source = "Ula'tek",                     },
        { slot = "Trinket",     itemID = 270173,   source = "The Coiled Altar",            },
        { slot = "Ring",        itemID = 159459,   source = "King's Rest",                 },
        { slot = "Ring",        itemID = 252258,   source = "Voidscar Arena",              },
    },
}

ns.ClassGuideData["DEATHKNIGHT_FROST"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Deathbringer", "Rider of the Apocalypse" },
            context = "",
            stats = {
                "Strength",
                "Critical Strike",
                "Mastery",
                "Haste",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 268202,   source = "Ula'tek",                     },
        { slot = "Off Hand",    itemID = 268202,   source = "Ula'tek",                     },
        { slot = "Head",        itemID = 271474,   source = "Tier Set",                    },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271472,   source = "Tier Set",                    },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 268222,   source = "The Coiled Altar",            },
        { slot = "Wrist",       itemID = 237834,   source = "Crafting/Misc",               bonus = "8793:8960:12214:13454:13750:13751:13836:12497", },
        { slot = "Hands",       itemID = 271475,   source = "Tier Set",                    },
        { slot = "Waist",       itemID = 268259,   source = "The Coiled Altar",            },
        { slot = "Legs",        itemID = 271878,   source = "Ula'tek",                     },
        { slot = "Feet",        itemID = 268260,   source = "Vashnik the Malignant",       },
        { slot = "Ring",        itemID = 268249,   source = "Vashnik the Malignant",       },
        { slot = "Ring",        itemID = 251513,   source = "Crafting/Misc",               },
        { slot = "Trinket",     itemID = 270173,   source = "The Coiled Altar",            },
        { slot = "Trinket",     itemID = 270175,   source = "Ula'tek",                     },
    },
}

ns.ClassGuideData["DEATHKNIGHT_UNHOLY"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "San'layn", "Rider of the Apocalypse" },
            context = "",
            stats = {
                "Strength",
                "Mastery",
                "Crit",
                "Haste",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 268213,   source = "Ula'tek",                     },
        { slot = "Head",        itemID = 271474,   source = "Tier Set",                    },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271472,   source = "Tier Set",                    },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271477,   source = "Tier Set",                    },
        { slot = "Wrist",       itemID = 237834,   source = "Crafting",                    },
        { slot = "Hands",       itemID = 271475,   source = "Tier Set",                    },
        { slot = "Waist",       itemID = 268259,   source = "Ula'tek",                     },
        { slot = "Legs",        itemID = 271878,   source = "Ula'tek",                     },
        { slot = "Feet",        itemID = 237828,   source = "Crafting",                    },
        { slot = "Ring",        itemID = 273792,   source = "Altar of Fangs",              },
        { slot = "Ring",        itemID = 252258,   source = "Voidscar Arena",              },
        { slot = "Trinket",     itemID = 270175,   source = "Ula'tek",                     },
        { slot = "Trinket",     itemID = 270173,   source = "The Coiled Altar",            },
    },
}

ns.ClassGuideData["DEMONHUNTER_HAVOC"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Fel-Scarred", "Aldrachi Reaver" },
            context = "",
            stats = {
                "Agility",
                "Critical Strike",
                "Mastery",
                "Haste",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 268209,   source = "The Coiled Altar",            },
        { slot = "Off Hand",    itemID = 237840,   source = "Crafting/Misc",               },
        { slot = "Head",        itemID = 271875,   source = "Ula'tek",                     },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271535,   source = "Vashnik the Malignant",       catalystFrom = 268246, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271540,   source = "King's Rest",                 catalystFrom = 239048, },
        { slot = "Wrist",       itemID = 244576,   source = "Crafting/Misc",               },
        { slot = "Hands",       itemID = 271538,   source = "Entombed Sentinels",          },
        { slot = "Waist",       itemID = 268256,   source = "The Coiled Altar",            },
        { slot = "Legs",        itemID = 271536,   source = "The Coiled Altar",            catalystFrom = 268225, },
        { slot = "Feet",        itemID = 159327,   source = "Temple of Sethraliss",        },
        { slot = "Ring",        itemID = 268249,   source = "Vashnik the Malignant",       },
        { slot = "Ring",        itemID = 158366,   source = "Temple of Sethraliss",        },
        { slot = "Trinket",     itemID = 270173,   source = "The Coiled Altar",            },
        { slot = "Trinket",     itemID = 270175,   source = "Ula'tek",                     },
    },
}

ns.ClassGuideData["DEMONHUNTER_VENGEANCE"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Aldrachi Reaver", "Annihilator" },
            context = "",
            stats = {
                "Item Level (Agility+Stamina)",
                "Haste",
                "Crit",
                "Versatility",
                "Mastery",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 268209,   source = "The Coiled Altar",            },
        { slot = "Off Hand",    itemID = 237840,   source = "Crafted",                     },
        { slot = "Head",        itemID = 271537,   source = "Ula'tek",                     catalystFrom = 271875, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271535,   source = "Voidscar Arena",              catalystFrom = 251223, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271540,   source = "Vashnik the Malignant",       },
        { slot = "Wrist",       itemID = 244576,   source = "Crafted",                     },
        { slot = "Hands",       itemID = 271538,   source = "Murder Row",                  catalystFrom = 251124, },
        { slot = "Waist",       itemID = 268256,   source = "The Coiled Altar",            },
        { slot = "Legs",        itemID = 271536,   source = "The Coiled Altar",            catalystFrom = 268225, },
        { slot = "Feet",        itemID = 251153,   source = "Den of Nalorakk",             },
        { slot = "Ring",        itemID = 268252,   source = "Sszorak",                     },
        { slot = "Ring",        itemID = 159459,   source = "King's Rest",                 },
        { slot = "Trinket",     itemID = 270164,   source = "The Lost Explorers",          },
        { slot = "Trinket",     itemID = 270175,   source = "Ula'tek",                     },
        { slot = "Trinket",     itemID = 270173,   source = "The Coiled Altar",            },
    },
}

ns.ClassGuideData["DEMONHUNTER_DEVOURER"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Annihilator" },
            context = "",
            stats = {
                "Intellect",
                "Haste",
                "Mastery",
                "Critical Strike",
                "Versatility",
            },
        },
        {
            builds = { "Void-Scarred" },
            context = "",
            stats = {
                "Intellect",
                "Haste (until 800/18%-20%)",
                "Critical Strike",
                "Mastery",
                "Versatility",
                "Haste (above 800/18%-20%).",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 271092,   source = "Ula'tek",                     },
        { slot = "Off Hand",    itemID = 268211,   source = "The Coiled Altar",            },
        { slot = "Head",        itemID = 271537,   source = "Ula'tek",                     catalystFrom = 271875, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271535,   source = "Voidscar Arena",              catalystFrom = 251223, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271540,   source = "Den of Nalorakk",             catalystFrom = 251159, },
        { slot = "Wrist",       itemID = 244576,   source = "Crafting/Misc",               },
        { slot = "Hands",       itemID = 271538,   source = "Tier Set",                    },
        { slot = "Waist",       itemID = 268256,   source = "The Coiled Altar",            },
        { slot = "Legs",        itemID = 271536,   source = "The Coiled Altar",            catalystFrom = 268225, },
        { slot = "Feet",        itemID = 244569,   source = "Crafting/Misc",               },
        { slot = "Ring",        itemID = 268249,   source = "Vashnik the Malignant",       },
        { slot = "Ring",        itemID = 158366,   source = "Temple of Sethraliss",        },
        { slot = "Trinket",     itemID = 250215,   source = "Murder Row",                  },
        { slot = "Trinket",     itemID = 270164,   source = "The Lost Explorers",          },
    },
}

ns.ClassGuideData["DRUID_BALANCE"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Keeper of the Grove" },
            context = "",
            stats = {
                "Intellect",
                "Mastery",
                "Haste = Critical Strike",
                "Versatility",
            },
        },
        {
            builds = { "Elune's Chosen" },
            context = "",
            stats = {
                "Intellect",
                "Mastery",
                "Haste",
                "Critical Strike",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 271092,   source = "Ula'tek",                     },
        { slot = "Off Hand",    itemID = 245769,   source = "Crafting/Misc",               bonus = "8791:13771:8960:13751:12497:13836", },
        { slot = "Head",        itemID = 271875,   source = "Ula'tek",                     bonus = "13848:13847:13750", },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     bonus = "13848:13708", },
        { slot = "Shoulders",   itemID = 244572,   source = "Crafting/Misc",               bonus = "8791:13836:13751:13836:9627:8960:12384", },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            bonus = "13848:13708", },
        { slot = "Chest",       itemID = 251159,   source = "Den of Nalorakk",             },
        { slot = "Wrist",       itemID = 268240,   source = "Nek'zali the Soulcoiler",     bonus = "13750", },
        { slot = "Hands",       itemID = 268234,   source = "Tier Set",                    },
        { slot = "Waist",       itemID = 268256,   source = "The Coiled Altar",            bonus = "13750:13848:13708", },
        { slot = "Legs",        itemID = 268225,   source = "The Coiled Altar",            bonus = "13848:13708", },
        { slot = "Feet",        itemID = 251153,   source = "Den of Nalorakk",             },
        { slot = "Ring",        itemID = 252258,   source = "Voidscar Arena",              bonus = "13750", },
        { slot = "Ring",        itemID = 268249,   source = "Vashnik the Malignant",       bonus = "13750", },
        { slot = "Trinket",     itemID = 270164,   source = "The Lost Explorers",          },
        { slot = "Trinket",     itemID = 273796,   source = "Altar of Fangs",              },
    },
}

ns.ClassGuideData["DRUID_FERAL"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Druid of the Claw" },
            context = "",
            stats = {
                "Agility",
                "Mastery",
                "Haste",
                "Critical Strike",
                "Versatility",
            },
        },
        {
            builds = { "Wildstalker" },
            context = "",
            stats = {
                "Agility",
                "Mastery",
                "Critical Strike",
                "Haste",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 268215,   source = "Ula'tek",                     },
        { slot = "Head",        itemID = 271528,   source = "Catalyst",                    },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271526,   source = "Catalyst",                    },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271531,   source = "Vashnik the Malignant",       },
        { slot = "Wrist",       itemID = 244576,   source = "Crafting/Misc",               },
        { slot = "Hands",       itemID = 244575,   source = "Crafting/Misc",               },
        { slot = "Waist",       itemID = 268256,   source = "The Coiled Altar",            },
        { slot = "Legs",        itemID = 271527,   source = "Catalyst",                    },
        { slot = "Feet",        itemID = 268261,   source = "The Twin Fangs",              },
        { slot = "Ring",        itemID = 268249,   source = "Vashnik the Malignant",       },
        { slot = "Ring",        itemID = 252258,   source = "Voidscar Arena",              },
        { slot = "Trinket",     itemID = 270173,   source = "The Coiled Altar",            },
        { slot = "Trinket",     itemID = 270175,   source = "Ula'tek",                     },
    },
}

ns.ClassGuideData["DRUID_GUARDIAN"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Survivability", "DPS" },
            context = "",
            stats = {
                "Agility",
                "Haste",
                "Versatility",
                "Critical Strike",
                "Mastery",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 268215,   source = "Ula'tek",                     },
        { slot = "Head",        itemID = 271875,   source = "Ula'tek",                     },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271526,   source = "Tier Set",                    },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271531,   source = "Tier Set",                    },
        { slot = "Wrist",       itemID = 268240,   source = "Nek'zali the Soulcoiler",     },
        { slot = "Hands",       itemID = 271529,   source = "Tier Set",                    },
        { slot = "Waist",       itemID = 268256,   source = "The Coiled Altar",            },
        { slot = "Legs",        itemID = 271527,   source = "Tier Set",                    },
        { slot = "Feet",        itemID = 268261,   source = "The Twin Fangs",              },
        { slot = "Ring",        itemID = 268252,   source = "Sszorak",                     },
        { slot = "Ring 2",      itemID = 268249,   source = "Vashnik the Malignant",       },
        { slot = "Trinket",     itemID = 270164,   source = "The Lost Explorers",          },
        { slot = "Trinket 2",   itemID = 270173,   source = "The Coiled Altar",            },
    },
}

ns.ClassGuideData["DRUID_RESTORATION"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Keeper of the Grove", "Wildstalker" },
            context = "",
            stats = {
                "Intellect",
                "Haste",
                "Mastery",
                "Versatility",
                "Critical Strike",
            },
        },
    },
    bis = {
        { slot = "Head",        itemID = 271528,   source = "Ula'tek (Raid) & Catalyst",   catalystFrom = 271875, },
        { slot = "Neck",        itemID = 268251,   source = "The Twin Fangs (Raid)",       },
        { slot = "Shoulders",   itemID = 244572,   source = "",                            },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Alter (Raid)",     },
        { slot = "Chest",       itemID = 271531,   source = "Nek'zali the Soulcoiler (Raid) & Catalyst", catalystFrom = 268235, },
        { slot = "Wrist",       itemID = 244576,   source = "",                            },
        { slot = "Hands",       itemID = 271529,   source = "Entomed Sentinels (Raid)",    },
        { slot = "Waist",       itemID = 268256,   source = "The Coiled Alter (Raid)",     },
        { slot = "Legs",        itemID = 271527,   source = "The Coiled Alter (Raid) & Catalyst", catalystFrom = 268225, },
        { slot = "Feet",        itemID = 244569,   source = "",                            },
        { slot = "Ring",        itemID = 268266,   source = "Nymrissa Wavebinder (Raid)",  },
        { slot = "Ring",        itemID = 252258,   source = "Voidscar Arena",              },
        { slot = "Trinket",     itemID = 270167,   source = "Nymrissa Wavebinder (Raid)",  },
        { slot = "Trinket",     itemID = 270162,   source = "Nek'zali the Soulcoiler (Raid)", },
        { slot = "Weapon",      itemID = 271092,   source = "Ula'tek (Raid)",              },
        { slot = "Off Hand",    itemID = 268197,   source = "Entomed Sentinels (Raid)",    },
        { slot = "Neck",        itemID = 251142,   source = "Murder Row",                  },
        { slot = "Back",        itemID = 251190,   source = "The Blinding Vale",           },
        { slot = "Waist",       itemID = 159317,   source = "Temple of Sethraliss",        },
        { slot = "Feet",        itemID = 251153,   source = "Den of Nalorakk",             },
        { slot = "Ring",        itemID = 159459,   source = "Kings Rest",                  },
        { slot = "Trinket",     itemID = 250214,   source = "The Blinding Vale",           },
        { slot = "Trinket",     itemID = 250255,   source = "Murder Row",                  },
        { slot = "Weapon",      itemID = 159636,   source = "Temple of Sethraliss",        },
    },
}

ns.ClassGuideData["EVOKER_DEVASTATION"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Flameshaper", "Scalecommander" },
            context = "",
            stats = {
                "Intellect",
                "Critical Strike",
                "Mastery",
                "Haste",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 271092,   source = "Ula'tek",                     },
        { slot = "Off Hand",    itemID = 245769,   source = "Crafting",                    bonus = "13836:9627:13771:8960:8791", },
        { slot = "Head",        itemID = 271501,   source = "Tier Set",                    catalystFrom = 268230, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271499,   source = "Tier Set",                    catalystFrom = 268231, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271504,   source = "Tier Set",                    catalystFrom = 271876, },
        { slot = "Wrist",       itemID = 244584,   source = "Crafting",                    bonus = "13667:12497:8960:12384:13836:8791", },
        { slot = "Hands",       itemID = 271502,   source = "Tier Set",                    catalystFrom = 193752, },
        { slot = "Waist",       itemID = 268254,   source = "Vashnik the Malignant",       },
        { slot = "Legs",        itemID = 271500,   source = "Tier Set",                    catalystFrom = 268237, },
        { slot = "Feet",        itemID = 268233,   source = "Sszorak",                     },
        { slot = "Ring",        itemID = 268249,   source = "Vashnik the Malignant",       },
        { slot = "Ring",        itemID = 158366,   source = "Temple of Sethraliss",        },
        { slot = "Trinket",     itemID = 270164,   source = "The Lost Explorers",          },
        { slot = "Trinket",     itemID = 270167,   source = "Nymrissa Wavecaller",         },
    },
}

ns.ClassGuideData["EVOKER_PRESERVATION"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Flameshaper" },
            context = "",
            stats = {
                "Intellect",
                "Mastery",
                "Crit",
                "Haste",
                "Versatility",
            },
        },
        {
            builds = { "Chronowarden" },
            context = "",
            stats = {
                "Intellect",
                "Mastery",
                "Crit (Haste better in Mythic+)",
                "Haste",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Head",        itemID = 271501,   source = "Temple of Sethraliss & Catalyst", catalystFrom = 239035, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek (Raid)",              },
        { slot = "Shoulders",   itemID = 271499,   source = "The Coiled Altar (Raid) & Catalyst", catalystFrom = 268231, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar (Raid)",     },
        { slot = "Chest",       itemID = 271504,   source = "Ula'tek (Raid) & Catalyst",   catalystFrom = 271876, },
        { slot = "Wrist",       itemID = 268217,   source = "Nymrissa Wavebinder (Raid)",  },
        { slot = "Hands",       itemID = 271502,   source = "Kings Rest & Catalyst",       catalystFrom = 160213, },
        { slot = "Waist",       itemID = 268254,   source = "Vashnik the Malignant (Raid)", },
        { slot = "Legs",        itemID = 271500,   source = "The Coiled Altar (Raid) & Catalyst", catalystFrom = 268237, },
        { slot = "Feet",        itemID = 159388,   source = "Temple of Sethraliss",        },
        { slot = "Ring",        itemID = 268249,   source = "Vashnik the Malignant (Raid)", },
        { slot = "Ring",        itemID = 158366,   source = "Temple of Sethraliss",        },
        { slot = "Trinket",     itemID = 270164,   source = "The Lost Explorers (Raid)",   },
        { slot = "Trinket",     itemID = 270162,   source = "Nek'zali the Soulcoiler (Raid)", },
        { slot = "Weapon",      itemID = 271092,   source = "Ula'tek (Raid)",              },
        { slot = "Off Hand",    itemID = 268197,   source = "Entomed Sentinels (Raid)",    },
    },
}

ns.ClassGuideData["EVOKER_AUGMENTATION"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Chronowarden", "Scalecommander" },
            context = "",
            stats = {
                "Intellect",
                "Mastery",
                "Critical Strike",
                "Haste",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 271092,   source = "Ula'tek",                     },
        { slot = "Off Hand",    itemID = 245769,   source = "Crafting",                    bonus = "13836:9627:13771:8960:8791", },
        { slot = "Head",        itemID = 271501,   source = "Tier Set",                    catalystFrom = 239035, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271499,   source = "Tier Set",                    catalystFrom = 268231, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271504,   source = "Tier Set",                    catalystFrom = 271876, },
        { slot = "Wrist",       itemID = 244584,   source = "Crafting",                    bonus = "13667:12497:8960:12384:13836:8791", },
        { slot = "Hands",       itemID = 271502,   source = "Tier Set",                    catalystFrom = 193752, },
        { slot = "Waist",       itemID = 268254,   source = "Vashnik the Malignant",       },
        { slot = "Legs",        itemID = 271500,   source = "Tier Set",                    catalystFrom = 268237, },
        { slot = "Feet",        itemID = 268233,   source = "Sszorak",                     },
        { slot = "Ring",        itemID = 268249,   source = "Vashnik the Malignant",       },
        { slot = "Ring",        itemID = 158366,   source = "Temple of Sethraliss",        },
        { slot = "Trinket",     itemID = 270164,   source = "The Lost Explorers",          },
        { slot = "Trinket",     itemID = 250215,   source = "Murder Row",                  },
    },
}

ns.ClassGuideData["HUNTER_BEASTMASTERY"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Pack Leader", "Dark Ranger" },
            context = "",
            stats = {
                "Agility",
                "Mastery",
                "Critical Strike",
                "Haste",
                "Versatility",
            },
        },
        {
            builds = { "Dark Ranger" },
            context = "",
            stats = {
                "Agility",
                "Critical Strike",
                "Mastery",
                "Haste",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 268207,   source = "Ula'tek",                     bonus = "13848:13708", },
        { slot = "Head",        itemID = 271492,   source = "The Twin Fangs",              },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     bonus = "13848:13708", },
        { slot = "Shoulders",   itemID = 271490,   source = "The Coiled Altar",            catalystFrom = 268231, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271495,   source = "Ula'tek",                     catalystFrom = 271876, },
        { slot = "Wrist",       itemID = 244584,   source = "",                            bonus = "13751:12497:13836:12384:8793", },
        { slot = "Hands",       itemID = 271493,   source = "King's Rest",                 catalystFrom = 160213, },
        { slot = "Waist",       itemID = 244581,   source = "",                            bonus = "13751:12497:13836:12384:8793", },
        { slot = "Legs",        itemID = 271491,   source = "The Coiled Altar",            catalystFrom = 268237, },
        { slot = "Feet",        itemID = 268233,   source = "Sszorak",                     },
        { slot = "Ring",        itemID = 268249,   source = "Vashnik the Malignant",       },
        { slot = "Ring",        itemID = 252258,   source = "Voidscar Arena",              },
        { slot = "Trinket",     itemID = 270173,   source = "The Coiled Altar",            },
        { slot = "Trinket",     itemID = 270175,   source = "Ula'tek",                     },
        { slot = "Trinket",     itemID = 270164,   source = "The Lost Explorers",          },
    },
}

ns.ClassGuideData["HUNTER_MARKSMANSHIP"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Sentinel", "Dark Ranger" },
            context = "",
            stats = {
                "Agility",
                "Critical Strike",
                "Mastery",
                "Versatility",
                "Haste",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 268207,   source = "Ula'tek",                     bonus = "12806:13335", },
        { slot = "Head",        itemID = 271492,   source = "Catalyst the Nek'zali the Soulcoiler Head", catalystFrom = 268230, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     bonus = "12806:13335", },
        { slot = "Shoulders",   itemID = 271490,   source = "Catalyst the The Coiled Altar Shoulders", catalystFrom = 268231, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            bonus = "12806:13335", },
        { slot = "Chest",       itemID = 271495,   source = "Catalyst the Ula'tek Chest",  catalystFrom = 271876, },
        { slot = "Wrist",       itemID = 244584,   source = "Crafting/Misc",               bonus = "12214:8960:12497:12066:13622:13667", },
        { slot = "Hands",       itemID = 271493,   source = "Catalyst the Ruby Life Pools Gloves", catalystFrom = 193752, },
        { slot = "Waist",       itemID = 244581,   source = "Crafting/Misc",               bonus = "12214:8960:12497:12066:13622:13667", },
        { slot = "Legs",        itemID = 271491,   source = "Catalyst the The Coiled Altar Legs", catalystFrom = 268237, },
        { slot = "Feet",        itemID = 268233,   source = "Sszorak",                     bonus = "12806:13335", },
        { slot = "Ring",        itemID = 251136,   source = "Murder Row",                  bonus = "12806", },
        { slot = "Ring",        itemID = 268249,   source = "Vashnik the Malignant",       bonus = "12806:13335", },
        { slot = "Trinket",     itemID = 270175,   source = "Ula'tek",                     bonus = "12806:13335", },
        { slot = "Trinket",     itemID = 270173,   source = "The Coiled Altar",            bonus = "12806:13335", },
    },
}

ns.ClassGuideData["HUNTER_SURVIVAL"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Pack Leader" },
            context = "",
            stats = {
                "Agility",
                "Mastery",
                "Critical Strike and Haste",
                "Versatility",
            },
        },
        {
            builds = { "Sentinel" },
            context = "",
            stats = {
                "Agility",
                "Mastery",
                "Critical Strike",
                "Haste",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 268215,   source = "Ula'tek",                     },
        { slot = "Head",        itemID = 271492,   source = "Tier Set|Voidscar Arena",     catalystFrom = 251220, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271490,   source = "Tier Set|The Coiled Altar",   catalystFrom = 268231, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271876,   source = "Ula'tek",                     },
        { slot = "Wrist",       itemID = 244584,   source = "Crafting",                    bonus = "13836:13751:9627:13750:8793:8960:12384", },
        { slot = "Hands",       itemID = 271493,   source = "Tier Set|King's Rest",        catalystFrom = 160213, },
        { slot = "Waist",       itemID = 244581,   source = "Crafting",                    bonus = "13836:13751:9627:13750:8793:8960:12384", },
        { slot = "Legs",        itemID = 271491,   source = "Tier Set|The Coiled Altar",   catalystFrom = 268237, },
        { slot = "Feet",        itemID = 268233,   source = "Sszorak",                     },
        { slot = "Ring",        itemID = 273792,   source = "The Coiled Altar",            },
        { slot = "Ring",        itemID = 252258,   source = "Voidscar Arena",              },
        { slot = "Trinket",     itemID = 270175,   source = "Ula'tek",                     },
        { slot = "Trinket",     itemID = 270173,   source = "The Coiled Altar",            },
    },
}

ns.ClassGuideData["MAGE_ARCANE"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Realistically here, these values will change based on your personal gear, though haste should always be strong for Season 2 Arcane. Spellslinger" },
            context = "",
            stats = {
                "Intellect",
                "Haste",
                "Mastery",
                "Critical Strike",
                "Versatility",
            },
        },
        {
            builds = { "Sunfury" },
            context = "",
            stats = {
                "Intellect",
                "Haste",
                "Versatility",
                "Critical Strike",
                "Mastery",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 271092,   source = "Ula'tek",                     },
        { slot = "Off Hand",    itemID = 159667,   source = "King's Rest",                 },
        { slot = "Head",        itemID = 271564,   source = "Ula'tek",                     catalystFrom = 271874, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271562,   source = "The Twin Fangs",              catalystFrom = 268241, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271567,   source = "Altar of Fangs",              catalystFrom = 273785, },
        { slot = "Wrist",       itemID = 239648,   source = "Crafting",                    },
        { slot = "Hands",       itemID = 271565,   source = "The Coiled Altar",            catalystFrom = 268243, },
        { slot = "Waist",       itemID = 239664,   source = "Crafting",                    },
        { slot = "Legs",        itemID = 271563,   source = "Nek'zali the Soulcoiler",     catalystFrom = 268236, },
        { slot = "Feet",        itemID = 268255,   source = "The Coiled Altar",            },
        { slot = "Ring",        itemID = 268266,   source = "Nymrissa Wavecaller",         },
        { slot = "Ring",        itemID = 251148,   source = "Den of Nalorakk",             },
        { slot = "Trinket",     itemID = 250215,   source = "Murder Row",                  },
        { slot = "Trinket",     itemID = 270164,   source = "The Lost Explorers",          },
    },
}

ns.ClassGuideData["MAGE_FIRE"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Sunfury", "Frostfire" },
            context = "",
            stats = {
                "Intellect",
                "Haste",
                "Mastery",
                "Versatility",
                "Critical Strike",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 271092,   source = "Ula'tek",                     },
        { slot = "Off Hand",    itemID = 245769,   source = "Crafting",                    },
        { slot = "Head",        itemID = 271564,   source = "Tier Set",                    catalystFrom = 271874, },
        { slot = "Neck",        itemID = 251142,   source = "Murder Row",                  },
        { slot = "Shoulders",   itemID = 271562,   source = "Tier Set",                    catalystFrom = 268241, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271567,   source = "Tier Set",                    catalystFrom = 273785, },
        { slot = "Wrist",       itemID = 239648,   source = "Crafting/Misc",               },
        { slot = "Hands",       itemID = 271565,   source = "Tier Set",                    catalystFrom = 268243, },
        { slot = "Waist",       itemID = 268257,   source = "Sszorak",                     },
        { slot = "Legs",        itemID = 271563,   source = "Tier Set",                    catalystFrom = 268236, },
        { slot = "Feet",        itemID = 268255,   source = "The Coiled Altar",            },
        { slot = "Ring",        itemID = 268266,   source = "Nymrissa Wavecaller",         },
        { slot = "Ring",        itemID = 159459,   source = "King's Rest",                 },
        { slot = "Trinket",     itemID = 273796,   source = "Altar of Fangs",              },
        { slot = "Trinket",     itemID = 270164,   source = "The Lost Explorers",          },
    },
}

ns.ClassGuideData["MAGE_FROST"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Frostfire", "Spellslinger" },
            context = "",
            stats = {
                "Intellect",
                "Mastery",
                "Critical Strike",
                "Haste",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 271092,   source = "Ula'tek",                     },
        { slot = "Off Hand",    itemID = 268263,   source = "Nymrissa Wavecaller",         },
        { slot = "Head",        itemID = 271564,   source = "Tier Set",                    catalystFrom = 271874, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271562,   source = "Tier Set",                    catalystFrom = 239031, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271567,   source = "Tier Set",                    catalystFrom = 273785, },
        { slot = "Wrist",       itemID = 239648,   source = "Crafting/Misc",               bonus = "8791:8960:12214:12384:13668:13751", },
        { slot = "Hands",       itemID = 271565,   source = "Tier Set",                    catalystFrom = 268243, },
        { slot = "Waist",       itemID = 239649,   source = "Crafting/Misc",               bonus = "8791:8960:12214:12384:13668:13751", },
        { slot = "Legs",        itemID = 271563,   source = "Tier Set",                    catalystFrom = 159234, },
        { slot = "Feet",        itemID = 268255,   source = "The Coiled Altar",            },
        { slot = "Ring",        itemID = 268249,   source = "Vashnik the Malignant",       },
        { slot = "Ring",        itemID = 158366,   source = "Temple of Sethraliss",        },
        { slot = "Trinket",     itemID = 270164,   source = "The Lost Explorers",          },
        { slot = "Trinket",     itemID = 270167,   source = "Nymrissa Wavecaller",         },
    },
}

ns.ClassGuideData["MONK_BREWMASTER"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Shado-Pan Defensive Priority", "Master of Harmony Defensive Priority" },
            context = "Defensive Brewmaster Monk Stat Priority",
            stats = {
                "Item Level / Agility / Armor / Stamina",
                "Versatility = Critical Strike = Mastery",
                "Haste",
            },
        },
        {
            builds = { "Shado-Pan Offensive Priority", "Master of Harmony Offensive Priority" },
            context = "Offensive Brewmaster Monk Stat Priority",
            stats = {
                "Item Level / Agility",
                "Critical Strike",
                "Versatility = Mastery",
                "Haste",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 268215,   source = "Ula'tek",                     bonus = "13848:13846", },
        { slot = "Weapon",      itemID = 268209,   source = "The Coiled Altar Sszorak",    bonus = "13848", },
        { slot = "Head",        itemID = 271519,   source = "Catalyst|Raid|Vault",         bonus = "13848:13847:10835", catalystFrom = 271875, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     bonus = "13848:13708:10835", },
        { slot = "Shoulders",   itemID = 271517,   source = "Catalyst|Mythic+|Vault",      catalystFrom = 273774, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            bonus = "13848", },
        { slot = "Chest",       itemID = 271522,   source = "Catalyst|Mythic+|Vault",      catalystFrom = 251226, },
        { slot = "Wrist",       itemID = 244576,   source = "Leatherworking",              bonus = "13751:12497:13836:10835:8795:13454", },
        { slot = "Hands",       itemID = 271520,   source = "Catalyst|Mythic+|Vault",      catalystFrom = 193758, },
        { slot = "Waist",       itemID = 268256,   source = "The Coiled Altar",            bonus = "13848", },
        { slot = "Legs",        itemID = 271518,   source = "Catalyst|Raid|Vault",         bonus = "13848", catalystFrom = 268225, },
        { slot = "Feet",        itemID = 159304,   source = "Kings' Rest",                 },
        { slot = "Ring",        itemID = 251148,   source = "Den of Nalorakk",             },
        { slot = "Ring",        itemID = 251513,   source = "Jewelcrafting",               bonus = "13751:12497:13836", },
        { slot = "Trinket",     itemID = 270175,   source = "Ula'tek",                     bonus = "13848", },
        { slot = "Trinket",     itemID = 270173,   source = "The Coiled Altar",            bonus = "13848", },
        { slot = "Trinket",     itemID = 270160,   source = "The Lost Explorers",          },
        { slot = "Trinket",     itemID = 159617,   source = "Kings' Rest",                 },
    },
}

ns.ClassGuideData["MONK_MISTWEAVER"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Raid" },
            context = "",
            stats = {
                "Intellect",
                "Haste",
                "Critical Strike",
                "Versatility",
                "Mastery",
            },
        },
        {
            builds = { "Mythic+" },
            context = "",
            stats = {
                "Intellect",
                "Haste",
                "Mastery",
                "Critical Strike",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Head",        itemID = 271519,   source = "Ula'tek (Raid) & Catalyst",   catalystFrom = 271875, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek (Raid)",              },
        { slot = "Shoulders",   itemID = 271517,   source = "Den of Nalorakk & Catalyst",  catalystFrom = 251146, },
        { slot = "Back",        itemID = 193763,   source = "Ruby Life Pools",             },
        { slot = "Chest",       itemID = 271522,   source = "Voidscar Arena & Catalyst",   catalystFrom = 251226, },
        { slot = "Wrist",       itemID = 251135,   source = "Murder Row",                  },
        { slot = "Hands",       itemID = 271520,   source = "Murder Row & Catalyst",       catalystFrom = 251124, },
        { slot = "Waist",       itemID = 251189,   source = "The Blinding Vale",           },
        { slot = "Legs",        itemID = 271518,   source = "Kings Rest & Catalyst",       catalystFrom = 159313, },
        { slot = "Feet",        itemID = 268247,   source = "Nymrissa Wavebinder (Raid)",  },
        { slot = "Ring",        itemID = 268266,   source = "Nymrissa Wavebinder (Raid)",  },
        { slot = "Ring",        itemID = 159459,   source = "Kings Rest",                  },
        { slot = "Trinket",     itemID = 270164,   source = "The Lost Explorers (Raid)",   },
        { slot = "Trinket",     itemID = 270162,   source = "Nek'zali the Soulcoiler (Raid)", },
        { slot = "Weapon",      itemID = 158369,   source = "Temple of Sethraliss",        },
        { slot = "Off Hand",    itemID = 159667,   source = "Kings Rest",                  },
    },
}

ns.ClassGuideData["MONK_WINDWALKER"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Shado-pan" },
            context = "",
            stats = {
                "Agility",
                "Haste",
                "Critical Strike",
                "Mastery",
                "Versatility",
            },
        },
        {
            builds = { "Conduit of the Celestials" },
            context = "",
            stats = {
                "Agility",
                "Haste",
                "Mastery",
                "Critical Strike",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 268215,   source = "Ula'tek",                     },
        { slot = "Head",        itemID = 271875,   source = "Ula'tek",                     },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271517,   source = "Tier Set",                    },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 268235,   source = "Nek'zali the Soulcoiler",     },
        { slot = "Wrist",       itemID = 244576,   source = "Crafting",                    },
        { slot = "Hands",       itemID = 251124,   source = "Murder Row",                  },
        { slot = "Waist",       itemID = 268256,   source = "The Coiled Altar",            },
        { slot = "Legs",        itemID = 268225,   source = "The Coiled Altar",            },
        { slot = "Feet",        itemID = 244569,   source = "Crafting",                    },
        { slot = "Ring",        itemID = 158366,   source = "Temple of Sethraliss",        },
        { slot = "Ring",        itemID = 252258,   source = "Voidscar Arena",              },
        { slot = "Trinket 1",   itemID = 270175,   source = "Ula'tek",                     },
        { slot = "Trinket 2",   itemID = 270173,   source = "The Coiled Altar",            },
    },
}

ns.ClassGuideData["PALADIN_HOLY"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Herald of the Sun", "Lightsmith" },
            context = "",
            stats = {
                "Intellect",
                "Mastery",
                "Haste = Crit",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 268211,   source = "The Coiled Altar",            },
        { slot = "Off Hand",    itemID = 268262,   source = "Nymrissa Wavecaller",         },
        { slot = "Head",        itemID = 271465,   source = "Nek'zali the Soulcoiler",     catalystFrom = 268229, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271463,   source = "Murder Row",                  catalystFrom = 251138, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271468,   source = "The Coiled Altar",            catalystFrom = 268222, },
        { slot = "Wrist",       itemID = 268239,   source = "The Lost Explorers",          },
        { slot = "Hands",       itemID = 271466,   source = "Entombed Sentinels",          },
        { slot = "Waist",       itemID = 268259,   source = "The Coiled Altar",            },
        { slot = "Legs",        itemID = 271464,   source = "Ula'tek",                     catalystFrom = 271878, },
        { slot = "Feet",        itemID = 268260,   source = "Vashnik the Malignant",       },
        { slot = "Ring",        itemID = 268249,   source = "Vashnik the Malignant",       },
        { slot = "Ring",        itemID = 252258,   source = "Voidscar Arena",              },
        { slot = "Trinket",     itemID = 270162,   source = "Nek'zali the Soulcoiler",     },
        { slot = "Trinket",     itemID = 270164,   source = "The Lost Explorers",          },
    },
}

ns.ClassGuideData["PALADIN_PROTECTION"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Survivability" },
            context = "",
            stats = {
                "Strength",
                "Haste",
                "Mastery",
                "Critical Strike",
                "Versatility",
            },
        },
        {
            builds = { "DPS" },
            context = "",
            stats = {
                "Strength",
                "Haste",
                "Critical Strike",
                "Mastery",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 268209,   source = "The Coiled Altar",            },
        { slot = "Off Hand",    itemID = 268196,   source = "The Lost Explorers",          },
        { slot = "Head",        itemID = 271465,   source = "Tier Set",                    },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271463,   source = "Tier Set",                    },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271468,   source = "Tier Set",                    },
        { slot = "Wrist",       itemID = 237834,   source = "Crafting Blacksmithing",      },
        { slot = "Hands",       itemID = 271466,   source = "Tier Set",                    },
        { slot = "Waist",       itemID = 268259,   source = "The Coiled Altar",            },
        { slot = "Legs",        itemID = 271878,   source = "Ula'tek",                     },
        { slot = "Feet",        itemID = 237828,   source = "Crafting Blacksmithing",      },
        { slot = "Ring",        itemID = 268252,   source = "Sszorak",                     },
        { slot = "Ring 2",      itemID = 268249,   source = "Vashnik the Malignant",       },
        { slot = "Trinket",     itemID = 270173,   source = "The Coiled Altar",            },
        { slot = "Trinket 2",   itemID = 270175,   source = "Ula'tek",                     },
    },
}

ns.ClassGuideData["PALADIN_RETRIBUTION"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Templar", "Herald of the Sun" },
            context = "",
            stats = {
                "Strength",
                "Mastery",
                "Haste",
                "Critical Strike",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 268213,   source = "The Coiled Altar",            bonus = "13848", },
        { slot = "Head",        itemID = 271465,   source = "Tier Set",                    catalystFrom = 268229, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     bonus = "13848:13708", },
        { slot = "Shoulders",   itemID = 271463,   source = "Tier Set",                    catalystFrom = 251138, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            bonus = "13848", },
        { slot = "Chest",       itemID = 271468,   source = "Tier Set",                    catalystFrom = 268222, },
        { slot = "Wrist",       itemID = 237834,   source = "Blacksmithing",               bonus = "13751:12497:13836:8790:13454", },
        { slot = "Hands",       itemID = 271466,   source = "Tier Set",                    catalystFrom = 251214, },
        { slot = "Waist",       itemID = 268259,   source = "The Coiled Altar",            bonus = "13848", },
        { slot = "Legs",        itemID = 271464,   source = "Ula'tek",                     catalystFrom = 271878, },
        { slot = "Feet",        itemID = 268260,   source = "Vashnik the Malignant",       bonus = "12854", },
        { slot = "Ring",        itemID = 252258,   source = "Voidscar Arena",              bonus = "12854", },
        { slot = "Ring",        itemID = 251513,   source = "Jewelcrafting",               bonus = "13751:12497:13836", },
        { slot = "Trinket",     itemID = 270173,   source = "The Coiled Altar",            bonus = "13848", },
        { slot = "Trinket",     itemID = 270175,   source = "Ula'tek",                     bonus = "13848", },
    },
}

ns.ClassGuideData["PRIEST_DISCIPLINE"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Oracle" },
            context = "Raid",
            stats = {
                "Intellect",
                "Haste",
                "Mastery",
                "Critical Strike",
                "Versatility",
            },
        },
        {
            builds = { "Voidweaver" },
            context = "Raid",
            stats = {
                "Haste",
                "Intellect",
                "Mastery",
                "Critical Strike",
                "Versatility",
            },
        },
        {
            builds = { "Oracle", "Voidweaver" },
            context = "Dungeons",
            stats = {
                "Intellect",
                "Haste",
                "Mastery",
                "Critical Strike",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 271092,   source = "",                            },
        { slot = "Off Hand",    itemID = 159667,   source = "",                            },
        { slot = "Head",        itemID = 271874,   source = "",                            },
        { slot = "Neck",        itemID = 268265,   source = "",                            },
        { slot = "Shoulders",   itemID = 268241,   source = "",                            },
        { slot = "Back",        itemID = 268253,   source = "",                            },
        { slot = "Chest",       itemID = 251139,   source = "",                            },
        { slot = "Wrist",       itemID = 239648,   source = "Crafting",                    },
        { slot = "Hands",       itemID = 268243,   source = "",                            },
        { slot = "Waist",       itemID = 239649,   source = "Crafting",                    },
        { slot = "Legs",        itemID = 271554,   source = "",                            },
        { slot = "Feet",        itemID = 268255,   source = "",                            },
        { slot = "Ring",        itemID = 268266,   source = "",                            },
        { slot = "Ring",        itemID = 252258,   source = "",                            },
        { slot = "Trinket",     itemID = 270167,   source = "",                            },
        { slot = "Trinket",     itemID = 270162,   source = "",                            },
    },
}

ns.ClassGuideData["PRIEST_HOLY"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Archon", "Oracle" },
            context = "Raid",
            stats = {
                "Intellect",
                "Crit",
                "Versatility = Mastery",
                "Haste",
            },
        },
        {
            builds = { "Archon", "Oracle" },
            context = "Dungeons/Mythic+",
            stats = {
                "Intellect",
                "Versatility",
                "Critical Strike",
                "Haste",
                "Mastery",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 271092,   source = "",                            },
        { slot = "Off Hand",    itemID = 268263,   source = "",                            },
        { slot = "Head",        itemID = 271874,   source = "",                            },
        { slot = "Neck",        itemID = 268265,   source = "",                            },
        { slot = "Shoulders",   itemID = 271553,   source = "",                            },
        { slot = "Back",        itemID = 251132,   source = "",                            },
        { slot = "Chest",       itemID = 268221,   source = "",                            },
        { slot = "Wrist",       itemID = 239648,   source = "Crafting",                    },
        { slot = "Hands",       itemID = 271556,   source = "",                            },
        { slot = "Waist",       itemID = 239649,   source = "Crafting",                    },
        { slot = "Legs",        itemID = 159234,   source = "",                            },
        { slot = "Feet",        itemID = 268218,   source = "",                            },
        { slot = "Ring",        itemID = 268252,   source = "",                            },
        { slot = "Ring",        itemID = 251148,   source = "",                            },
        { slot = "Trinket",     itemID = 270164,   source = "",                            },
        { slot = "Trinket",     itemID = 270162,   source = "",                            },
    },
}

ns.ClassGuideData["PRIEST_SHADOW"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Archon", "Voidweaver" },
            context = "",
            stats = {
                "Intellect",
                "Haste",
                "Mastery",
                "Critical Strike",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 271092,   source = "Ula'tek",                     bonus = "13848", },
        { slot = "Off Hand",    itemID = 245769,   source = "Crafting/Misc",               bonus = "8793:13751:12497:13836:13771:8960", },
        { slot = "Head",        itemID = 271555,   source = "Ula'tek",                     bonus = "13848:13846:10835", catalystFrom = 271874, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     bonus = "13708:13750:13848", },
        { slot = "Shoulders",   itemID = 239045,   source = "King's Rest",                 bonus = "12854", },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            bonus = "13848", },
        { slot = "Chest",       itemID = 271558,   source = "Vashnik the Malignant",       },
        { slot = "Wrist",       itemID = 239648,   source = "Crafting/Misc",               bonus = "8793:12384:8960:13750:13751:12497:13836", },
        { slot = "Hands",       itemID = 271556,   source = "The Coiled Altar",            bonus = "13848", catalystFrom = 268243, },
        { slot = "Waist",       itemID = 268257,   source = "Sszorak",                     bonus = "10835:12854", },
        { slot = "Legs",        itemID = 271554,   source = "Den of Nalorakk",             catalystFrom = 251160, },
        { slot = "Feet",        itemID = 268255,   source = "The Coiled Altar",            bonus = "13848", },
        { slot = "Ring",        itemID = 252258,   source = "Voidscar Arena",              bonus = "10835:12854", },
        { slot = "Ring",        itemID = 268252,   source = "Sszorak",                     bonus = "10835:12854", },
        { slot = "Trinket",     itemID = 270164,   source = "The Lost Explorers",          },
        { slot = "Trinket",     itemID = 250215,   source = "Murder Row",                  bonus = "12854", },
    },
}

ns.ClassGuideData["ROGUE_ASSASSINATION"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Fatebound", "Deathstalker" },
            context = "",
            stats = {
                "Agility",
                "Critical Strike",
                "Haste",
                "Mastery",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 271093,   source = "Ula'tek",                     },
        { slot = "Off Hand",    itemID = 237837,   source = "Crafting/Misc",               bonus = "12214:13836:13751:9627:13771:8960", },
        { slot = "Head",        itemID = 271510,   source = "Ula'tek",                     catalystFrom = 271875, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271508,   source = "Voidscar Arena",              catalystFrom = 251223, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271513,   source = "Den of Nalorakk",             catalystFrom = 251159, },
        { slot = "Wrist",       itemID = 244576,   source = "Crafting/Misc",               bonus = "12214:13836:13751:9627:13750:8790:8960:12384", },
        { slot = "Hands",       itemID = 271511,   source = "Entombed Sentinels",          },
        { slot = "Waist",       itemID = 268256,   source = "The Coiled Altar",            },
        { slot = "Legs",        itemID = 271509,   source = "The Coiled Altar",            catalystFrom = 268225, },
        { slot = "Feet",        itemID = 251153,   source = "Den of Nalorakk",             },
        { slot = "Ring",        itemID = 268252,   source = "Sszorak",                     },
        { slot = "Ring",        itemID = 268249,   source = "Vashnik the Malignant",       },
        { slot = "Trinket",     itemID = 270175,   source = "Ula'tek",                     },
        { slot = "Trinket",     itemID = 270164,   source = "The Lost Explorers",          },
    },
}

ns.ClassGuideData["ROGUE_OUTLAW"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Trickster", "Fatebound" },
            context = "",
            stats = {
                "Agility",
                "Haste",
                "Critical Strike",
                "Versatility",
                "Mastery",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 268209,   source = "The Coiled Altar",            },
        { slot = "Off Hand",    itemID = 275070,   source = "Altar of Fangs",              },
        { slot = "Head",        itemID = 271875,   source = "Ula'tek",                     },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271508,   source = "Tier Set",                    },
        { slot = "Back",        itemID = 268248,   source = "Nek'zali the Soulcoiler",     },
        { slot = "Chest",       itemID = 271513,   source = "Tier Set",                    },
        { slot = "Wrist",       itemID = 268240,   source = "Nek'zali the Soulcoiler",     },
        { slot = "Hands",       itemID = 271511,   source = "Tier Set",                    catalystFrom = 251124, },
        { slot = "Waist",       itemID = 244573,   source = "Crafting/Misc",               bonus = "12214:8960:12497:12066:13622:13667:12214:8792:8960:12384", },
        { slot = "Legs",        itemID = 271509,   source = "Tier Set",                    },
        { slot = "Feet",        itemID = 244569,   source = "Crafting/Misc",               bonus = "12214:8960:12497:12066:13622:13667:12214:8792:8960:12384", },
        { slot = "Ring",        itemID = 268266,   source = "Nymrissa Wavecaller",         },
        { slot = "Ring",        itemID = 268252,   source = "Sszorak",                     },
        { slot = "Trinket",     itemID = 270173,   source = "The Coiled Altar",            },
        { slot = "Trinket",     itemID = 270175,   source = "Ula'tek",                     },
    },
}

ns.ClassGuideData["ROGUE_SUBTLETY"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Default" },
            context = "",
            stats = {
                "Agility",
                "Mastery",
                "Haste (~1100 Haste)",
                "Critical Strike",
                "Versatility",
            },
        },
        {
            builds = { "Default" },
            context = "",
            stats = {
                "Agility",
                "Mastery",
                "Haste (~700 Haste)",
                "Critical Strike",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Main Hand",   itemID = 271093,   source = "Ula'tek",                     },
        { slot = "Off Hand",    itemID = 237837,   source = "Crafting/Misc",               },
        { slot = "Head",        itemID = 271510,   source = "Tier Set - Ula'tek",          catalystFrom = 271875, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271508,   source = "Tier Set - Vashnik the Malignant", catalystFrom = 268246, },
        { slot = "Back",        itemID = 239656,   source = "Crafting/Misc",               },
        { slot = "Chest",       itemID = 271513,   source = "Tier Set - Den of Nalorakk",  catalystFrom = 251159, },
        { slot = "Wrist",       itemID = 271506,   source = "Catalyst",                    },
        { slot = "Hands",       itemID = 271511,   source = "Tier Set - Sszorak",          catalystFrom = 268234, },
        { slot = "Waist",       itemID = 268256,   source = "The Coiled Altar",            },
        { slot = "Legs",        itemID = 271509,   source = "The Coiled Altar",            catalystFrom = 268225, },
        { slot = "Feet",        itemID = 271512,   source = "Catalyst",                    },
        { slot = "Ring",        itemID = 252258,   source = "Voidscar Arena",              },
        { slot = "Ring",        itemID = 251194,   source = "Blinding Vale",               },
        { slot = "Trinket",     itemID = 270173,   source = "The Coiled Altar",            },
        { slot = "Trinket",     itemID = 270175,   source = "Ula'tek",                     },
    },
}

ns.ClassGuideData["SHAMAN_ELEMENTAL"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Farseer", "Stormbringer" },
            context = "",
            stats = {
                "Mastery to 1200 rating",
                "Haste/Crit",
                "Versatility",
                "Intellect",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 271092,   source = "Ula'tek",                     },
        { slot = "Off Hand",    itemID = 268262,   source = "Nymrissa Wavecaller",         },
        { slot = "Head",        itemID = 271483,   source = "Tier Set",                    },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271481,   source = "Tier Set",                    },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271486,   source = "Tier Set",                    },
        { slot = "Wrist",       itemID = 244584,   source = "Crafting",                    },
        { slot = "Hands",       itemID = 271484,   source = "Tier Set",                    },
        { slot = "Waist",       itemID = 268254,   source = "Vashnik the Malignant",       },
        { slot = "Legs",        itemID = 271482,   source = "Tier Set",                    },
        { slot = "Feet",        itemID = 244577,   source = "Crafting",                    },
        { slot = "Ring",        itemID = 268249,   source = "Vashnik the Malignant",       },
        { slot = "Ring",        itemID = 252258,   source = "Voidscar Arena",              },
        { slot = "Trinket",     itemID = 270164,   source = "The Lost Explorers",          },
        { slot = "Trinket",     itemID = 273796,   source = "Altar of Fangs",              },
    },
}

ns.ClassGuideData["SHAMAN_ENHANCEMENT"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Stormbringer", "Totemic" },
            context = "",
            stats = {
                "Agility",
                "Mastery = Haste",
                "Critical Strike",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Main Hand",   itemID = 268209,   source = "The Coiled Altar",            bonus = "13848", },
        { slot = "Off Hand",    itemID = 237850,   source = "",                            bonus = "13751:12497:13836:13771:8793", },
        { slot = "Head",        itemID = 271483,   source = "Catalyst - Voidscar Arena",   bonus = "12854", catalystFrom = 251220, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     bonus = "13848:13708:10835", },
        { slot = "Shoulders",   itemID = 271481,   source = "Catalyst - The Coiled Altar", bonus = "13848", catalystFrom = 268231, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            bonus = "13848", },
        { slot = "Chest",       itemID = 271486,   source = "Catalyst - Ula'tek",          bonus = "13848:13708", catalystFrom = 271876, },
        { slot = "Wrist",       itemID = 244584,   source = "",                            bonus = "13751:12497:13836:12384:8793", },
        { slot = "Hands",       itemID = 271484,   source = "Catalyst - King's Rest",      bonus = "12854", catalystFrom = 160213, },
        { slot = "Waist",       itemID = 268254,   source = "Vashnik the Malignant",       bonus = "12854", },
        { slot = "Legs",        itemID = 271482,   source = "Catalyst - The Coiled Altar", bonus = "13848", catalystFrom = 268237, },
        { slot = "Feet",        itemID = 268233,   source = "Sszorak",                     bonus = "12854", },
        { slot = "Ring 1",      itemID = 268249,   source = "Vashnik the Malignant",       bonus = "12854:10835", },
        { slot = "Ring 2",      itemID = 252258,   source = "Voidscar Arena",              bonus = "12854:10835", },
        { slot = "Trinket 1",   itemID = 270175,   source = "Ula'tek",                     bonus = "13848", },
        { slot = "Trinket 2",   itemID = 270173,   source = "The Coiled Altar",            bonus = "13848", },
    },
}

ns.ClassGuideData["SHAMAN_RESTORATION"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Farseer", "Totemic" },
            context = "",
            stats = {
                "Intellect",
                "Critical Strike",
                "Haste",
                "Versatility",
                "Mastery",
            },
        },
    },
    bis = {
        { slot = "Head",        itemID = 271483,   source = "Voidscar Arena & Catalyst",   catalystFrom = 251220, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek (Raid)",              },
        { slot = "Shoulders",   itemID = 271481,   source = "The Coiled Alter (Raid) & Catalyst", catalystFrom = 268231, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Alter (Raid)",     },
        { slot = "Chest",       itemID = 271486,   source = "Ula'tek (Raid) & Catalyst",   catalystFrom = 271876, },
        { slot = "Wrist",       itemID = 251200,   source = "The Blinding Vale",           },
        { slot = "Hands",       itemID = 271484,   source = "Raid | Vault",                },
        { slot = "Waist",       itemID = 159369,   source = "Kings Rest",                  },
        { slot = "Legs",        itemID = 271482,   source = "The Coiled Alter (Raid) & Catalyst", catalystFrom = 268237, },
        { slot = "Feet",        itemID = 251145,   source = "Den of Nalorakk",             },
        { slot = "Ring",        itemID = 251148,   source = "Den of Nalorakk",             },
        { slot = "Ring",        itemID = 273792,   source = "Alter of Fangs",              },
        { slot = "Trinket",     itemID = 270162,   source = "Nek'zali the Soulcoiler (Raid)", },
        { slot = "Trinket",     itemID = 250215,   source = "Murder Row",                  },
        { slot = "Weapon",      itemID = 271092,   source = "Ula'tek (Raid)",              },
        { slot = "Off Hand",    itemID = 268196,   source = "The Lost Explorers (Raid)",   },
    },
}

ns.ClassGuideData["WARLOCK_AFFLICTION"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Hellcaller", "Soul Harvester" },
            context = "",
            stats = {
                "Intellect",
                "Haste",
                "Critical Strike",
                "Versatility",
                "Mastery",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 271092,   source = "Ula'tek",                     },
        { slot = "Off Hand",    itemID = 273779,   source = "",                            },
        { slot = "Head",        itemID = 271874,   source = "Ula'tek",                     },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271544,   source = "The Lost Explorers",          },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271549,   source = "Vashnik the Malignant",       },
        { slot = "Wrist",       itemID = 239648,   source = "Crafting",                    },
        { slot = "Hands",       itemID = 271547,   source = "Entombed Sentinels",          },
        { slot = "Waist",       itemID = 239649,   source = "Crafting",                    },
        { slot = "Legs",        itemID = 271545,   source = "Sszorak",                     },
        { slot = "Feet",        itemID = 268255,   source = "The Coiled Altar",            },
        { slot = "Ring",        itemID = 268252,   source = "Sszorak",                     },
        { slot = "Ring",        itemID = 273792,   source = "The Coiled Altar",            },
        { slot = "Trinket",     itemID = 270164,   source = "The Lost Explorers",          },
        { slot = "Trinket",     itemID = 273649,   source = "",                            },
    },
}

ns.ClassGuideData["WARLOCK_DEMONOLOGY"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Diabolist", "Soul Harvester" },
            context = "",
            stats = {
                "Intellect",
                "Haste=Critical Strike",
                "Mastery",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 271092,   source = "Ula'tek",                     },
        { slot = "Off Hand",    itemID = 268197,   source = "Entombed Sentinels",          },
        { slot = "Head",        itemID = 271874,   source = "Ula'tek",                     catalystFrom = 34252, },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271544,   source = "The Lost Explorers",          catalystFrom = 34262, },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271549,   source = "Vashnik the Malignant",       catalystFrom = 34264, },
        { slot = "Wrist",       itemID = 239648,   source = "Crafting",                    },
        { slot = "Hands",       itemID = 271547,   source = "Entombed Sentinels",          catalystFrom = 34251, },
        { slot = "Waist",       itemID = 239649,   source = "Crafting",                    },
        { slot = "Legs",        itemID = 271545,   source = "Sszorak",                     catalystFrom = 34264, },
        { slot = "Feet",        itemID = 268255,   source = "The Coiled Altar",            },
        { slot = "Ring",        itemID = 268252,   source = "Sszorak",                     },
        { slot = "Ring",        itemID = 158366,   source = "",                            },
        { slot = "Trinket",     itemID = 270164,   source = "The Lost Explorers",          },
        { slot = "Trinket",     itemID = 250215,   source = "",                            },
    },
}

ns.ClassGuideData["WARLOCK_DESTRUCTION"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Diabolist", "Hellcaller" },
            context = "",
            stats = {
                "Intellect",
                "Haste",
                "Mastery>=Critical Strike",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 271092,   source = "Ula'tek",                     },
        { slot = "Off Hand",    itemID = 273779,   source = "",                            },
        { slot = "Head",        itemID = 271874,   source = "Ula'tek",                     },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271544,   source = "The Lost Explorers",          },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271549,   source = "Vashnik the Malignant",       },
        { slot = "Wrist",       itemID = 239648,   source = "Crafting",                    },
        { slot = "Hands",       itemID = 271547,   source = "Entombed Sentinels",          },
        { slot = "Waist",       itemID = 239649,   source = "Crafting",                    },
        { slot = "Legs",        itemID = 271545,   source = "Sszorak",                     },
        { slot = "Feet",        itemID = 268255,   source = "The Coiled Altar",            },
        { slot = "Ring",        itemID = 268252,   source = "Sszorak",                     },
        { slot = "Ring",        itemID = 273792,   source = "The Coiled Altar",            },
        { slot = "Trinket",     itemID = 270164,   source = "The Lost Explorers",          },
        { slot = "Trinket",     itemID = 270167,   source = "Nymrissa Wavecaller",         },
    },
}

ns.ClassGuideData["WARRIOR_ARMS"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Colossus", "Slayer" },
            context = "",
            stats = {
                "Strength",
                "Critical Strike",
                "Haste",
                "Mastery",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Head",        itemID = 271456,   source = "",                            },
        { slot = "Neck",        itemID = 268265,   source = "",                            },
        { slot = "Shoulders",   itemID = 271454,   source = "",                            catalystFrom = 271444, },
        { slot = "Back",        itemID = 268253,   source = "",                            },
        { slot = "Chest",       itemID = 271459,   source = "",                            catalystFrom = 268222, },
        { slot = "Wrist",       itemID = 237834,   source = "",                            bonus = "12066:13622:9627:8791:8960:13767", },
        { slot = "Hands",       itemID = 271457,   source = "",                            },
        { slot = "Waist",       itemID = 268259,   source = "",                            },
        { slot = "Legs",        itemID = 271455,   source = "",                            catalystFrom = 271878, },
        { slot = "Feet",        itemID = 237828,   source = "",                            bonus = "12066:13622:9627:8791:8960:13767", },
        { slot = "Ring",        itemID = 252258,   source = "",                            },
        { slot = "Ring",        itemID = 273792,   source = "",                            },
        { slot = "Trinket",     itemID = 270173,   source = "",                            },
        { slot = "Trinket",     itemID = 270175,   source = "",                            },
        { slot = "Main Hand",   itemID = 268213,   source = "",                            },
    },
}

ns.ClassGuideData["WARRIOR_FURY"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Mountain Thane", "Slayer" },
            context = "",
            stats = {
                "Strength",
                "Haste",
                "Mastery",
                "Critical Strike",
                "Versatility",
            },
        },
    },
    bis = {
        { slot = "Head",        itemID = 271456,   source = "",                            catalystFrom = 251126, },
        { slot = "Neck",        itemID = 268265,   source = "",                            },
        { slot = "Shoulders",   itemID = 271454,   source = "",                            catalystFrom = 251138, },
        { slot = "Back",        itemID = 268253,   source = "",                            },
        { slot = "Chest",       itemID = 271459,   source = "",                            catalystFrom = 268222, },
        { slot = "Wrist",       itemID = 237834,   source = "",                            bonus = "12066:13622:9627:8791:8960:13767", },
        { slot = "Hands",       itemID = 271457,   source = "",                            catalystFrom = 251214, },
        { slot = "Waist",       itemID = 268259,   source = "",                            },
        { slot = "Legs",        itemID = 271455,   source = "",                            catalystFrom = 271878, },
        { slot = "Feet",        itemID = 237828,   source = "",                            bonus = "12066:13622:9627:8791:8960:13767", },
        { slot = "Ring",        itemID = 252258,   source = "",                            },
        { slot = "Ring",        itemID = 268249,   source = "",                            },
        { slot = "Trinket",     itemID = 270173,   source = "",                            },
        { slot = "Trinket",     itemID = 270175,   source = "",                            },
        { slot = "Main Hand",   itemID = 268213,   source = "",                            },
        { slot = "Off Hand",    itemID = 268214,   source = "",                            },
    },
}

ns.ClassGuideData["WARRIOR_PROTECTION"] = {
    season = "Midnight Season 2",
    statPriority = {
        {
            builds = { "Survivability", "DPS" },
            context = "",
            stats = {
                "Strength",
                "Haste",
                "Critical Strike",
                "Versatility",
                "Mastery",
            },
        },
    },
    bis = {
        { slot = "Weapon",      itemID = 268209,   source = "The Coiled Altar",            },
        { slot = "Off Hand",    itemID = 268196,   source = "The Lost Explorers",          },
        { slot = "Head",        itemID = 271456,   source = "Tier Set",                    },
        { slot = "Neck",        itemID = 268265,   source = "Ula'tek",                     },
        { slot = "Shoulders",   itemID = 271454,   source = "Tier Set",                    },
        { slot = "Back",        itemID = 268253,   source = "The Coiled Altar",            },
        { slot = "Chest",       itemID = 271459,   source = "Tier Set",                    },
        { slot = "Wrist",       itemID = 237834,   source = "Crafting Blacksmithing",      },
        { slot = "Hands",       itemID = 271457,   source = "Tier Set",                    },
        { slot = "Waist",       itemID = 268259,   source = "The Coiled Altar",            },
        { slot = "Legs",        itemID = 271878,   source = "Ula'tek",                     },
        { slot = "Feet",        itemID = 237828,   source = "Crafting Blacksmithing",      },
        { slot = "Ring",        itemID = 268252,   source = "Sszorak",                     },
        { slot = "Ring 2",      itemID = 268249,   source = "Vashnik the Malignant",       },
        { slot = "Trinket",     itemID = 270173,   source = "The Coiled Altar",            },
        { slot = "Trinket 2",   itemID = 270175,   source = "Ula'tek",                     },
    },
}

