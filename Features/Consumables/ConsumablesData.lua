local _, ns = ...

------------------------------------------------------------
-- Consumables & Enchant data per class/spec
-- Key format: "CLASS_SPEC" (e.g. "ROGUE_SUBTLETY")
--
-- GENERATED FILE — do not hand-edit.
-- Regenerate with:  python Tools/scrape_consumables.py
-- Source: Wowhead per-spec enchants/gems/consumables guides.
--
-- Each spec records the season its guide was written for. The
-- Consumables page shows a staleness banner when that is behind
-- ns.CONSUMABLES_TARGET_SEASON, so out-of-date advice is visible
-- in-game instead of silently wrong.
------------------------------------------------------------

ns.ConsumablesDB = {}
ns.CONSUMABLES_TARGET_SEASON = "Midnight Season 2"
ns.CONSUMABLES_SCRAPED_AT = "2026-08-11"

ns.ConsumablesDB["DEATHKNIGHT_BLOOD"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Head",        itemID = 243981 },
        { slot = "Shoulders",   itemID = 243963 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 244641 },
        { slot = "Boots",       itemID = 244009 },
        { slot = "Ring",        itemID = 243987 },
    },
    enchantGuide = "The best temporary weapon enchant for Blood Death Knights is Thalassian Phoenix Oil, due to the sheer bonus value it provides compared to whetstones.",
    gems = {
        { label = "Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240890 },
        { label = "Gem", itemID = 240908 },
    },
    gemGuide = "In general, you will want to use Indecipherable Eversong Diamond as your unique Jewelecrafting gem. Unlike prior expansions, this gem does not require a number of other gems to empower it further.\n\nAll other gem slots should be filled with whichever gem provides the most value for you. As a sensible default, San'layn players may opt for Flawless Deadly Peridot, while Deathbringer players should opt for Flawless Masterful Garnet.",
    consumables = {
        { label = "Flask", itemID = 241324, alt = { itemID = 241326 } },
        { label = "Combat Potion", itemID = 241288 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 242273 },
    },
    consumableGuide = "The best Flask for Blood Death Knights is Flask of the Blood Knights or Flask of the Shattered Sun. Unlike prior expansions, no consumables or other effects are tied to the use of a flask.\n\nIf you are specifically after damage reduction in order to guarantee survival on something, and you are certain that a flask will offset this, Flask of Thalassian Resistance is available. In addition to this, stacking versatility to just enough so that it is your first stat by rating allows you to use Potion of Recklessness as a direct defensive cooldown.\n\nThere are a couple of different potions that have different useful scenarios for Blood Death Knights:\n\nRaiding: Potion of Recklessness/Potion of Recklessness\nMythic+: Potion of Recklessness/Potion of Recklessness\n\nIf you are after a direct damage reduction solution to a predictable upfront hit, and you are willing to forsake some general throughput and indirect defensive value from other stats, stacking versatility to just enough so that it is your first stat by rating allows you to use Potion of Recklessness as a direct defensive cooldown.\n\nThe only healing potion available for Blood Death Knights is Concentrated Silvermoon Health Potion.\n\nIf you have a warlock in your group, don't forget your healthstones!\n\nThe best temporary weapon enchant for Blood Death Knights is Thalassian Phoenix Oil, due to the sheer bonus value it provides compared to whetstones.\n\nWith Midnight, the new Augment Rune is Void-Touched Augment Rune.\n\nBlood Death Knights have two choices at their disposal in Midnight: a primary stat feast, and a secondary stat feast. The secondary stat feat gives slightly more rating and will typically be better, but this is not always guaranteed.\n\nPrimary stat: Harandar Celebration\nSecondary stats: Blooming Feast\n\nWe strongly recommend simming these choices.",
}

ns.ConsumablesDB["DEATHKNIGHT_FROST"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Shoulders",   itemID = 243963 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Head",        itemID = 243981 },
        { slot = "Legs",        itemID = 244641 },
        { slot = "Boots",       itemID = 244009 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "Rune of the Fallen Crusader is used at all times as it is our most powerful Runeforge option. Builds that play Shattering Blade will want to use Rune of Razorice on their main-hand weapon so abilities that only strike once like Frostscythe apply Razorice. All other dual-wielding builds can rely on Glacial Advance to apply Razorice, and so they can take Rune of the Stoneskin Gargoyle instead.",
    gems = {
        { label = "Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240908 },
        { label = "Gem", itemID = 240967 },
        { label = "Amethyst", itemID = 240898 },
        { label = "Peridot", itemID = 240890 },
        { label = "Lapi", itemID = 240914 },
    },
    gemGuide = "For maximum damage, you will want to use Indecipherable Eversong Diamond as your Diamond; the increased Strength means it outweighs Powerful Eversong Diamond.\n\nIf you are using one of the embellishments that deals with gem colors, double-check that your gems are the colors you need.\n\nAmethyst: Flawless Deadly Amethyst\nGarnet: Flawless Masterful Garnet\nPeridot: Flawless Deadly Peridot\nLapid: Flawless Deadly Lapis",
    consumables = {
        { label = "Flask", itemID = 241326 },
        { label = "Combat Potion", itemID = 241308 },
        { label = "Health Potion", itemID = 241304 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 242275 },
    },
    consumableGuide = "The best Flask for Frost Death Knight is Flask of the Shattered Sun.\n\nThe best combat potion is Light's Potential. Another option is Draught of Rampant Abandon. The void zone dropped is fairly easy to play around as a melee DPS, but in hectic situations, you may not notice fast enough to start moving out and will lose a GCD, making it no longer worth it.\n\nThe best healing potion for Frost Death Knight is Silvermoon Health Potion.\n\nFrost Death Knights should always use Thalassian Phoenix Oil.\n\nWith The War Within, the new Augment Rune is Void-Touched Augment Rune.\n\nThe differences between the food buffs are very slight; do not worry too much about which one it is as long as you have one.\n\nFeast: Hearty Silvermoon Parade/Hearty Quel'dorei Medley\nPersonal Food: Royal Roast",
}

ns.ConsumablesDB["DEATHKNIGHT_UNHOLY"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Shoulders",   itemID = 243963 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 244641 },
        { slot = "Boots",       itemID = 244009 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "With Death Knight specific Runeforge enchants, there's often one that's just far and away better than the others. Currently, the best is Rune of the Apocalypse.",
    gems = {
        { label = "Diamond", itemID = 240983, alt = 240966 },
        { label = "Other Gems", itemID = 240908, alt = 240898 },
        { label = "Gem", itemID = 240898 },
    },
    gemGuide = "You'll want to use Indecipherable Eversong Diamond as your Diamond. In all other sockets, the most common choices will be Flawless Masterful Garnet or Flawless Deadly Amethyst, though realistically could be any non-versatility gem depending on your current stat balance. Due to this, you should always sim your character to find the best gems for you specifically.",
    consumables = {
        { label = "Helmet", itemID = 243981 },
        { label = "Flask", itemID = 241322, alt = { itemID = 241326 } },
        { label = "Combat Potion", itemID = 241288, alt = { itemID = 241308 } },
        { label = "Health Potion", itemID = 241304 },
        { label = "Weapon Buff", itemID = 243734, alt = { itemID = 237371 } },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255845, alt = { itemID = 242275 } },
    },
    consumableGuide = "The best Flask for Unholy Death Knights depends on your current stats. If Mastery is high enough to where using Flask of the Shattered Sun keeps Mastery higher, use this. Instead, if you need some extra Mastery to keep it as your highest stat (by rating), use Flask of the Magisters.\n\nPotion of Recklessness is always the best option for Unholy Death Knights, as our love for secondary stats knows no bounds. If Light's Potential is cheaper, it can be used instead, as Strength is still plenty valuable for us.\n\nThe best healing potion for Unholy Death Knights is Silvermoon Health Potion.\n\nFor their weapons, Unholy Death Knights have a few options. The best one is generally Thalassian Phoenix Oil, as the secondary stats this provides are quite good. Alternatively, you can use Refulgent Whetstone or Refulgent Weightstone, depending on your weapon type. Make sure that you buy the correct one - Whetstone for Swords and Axes, Weightstone for Maces.\n\nWith Midnight, the new Augment Rune is Void-Touched Augment Rune.\n\nUnholy Death Knights are most likely using primary stat foods in Midnight. As always, sim your character to check which food is the best for your configuration of secondary stats.\n\nFeast: Silvermoon Parade\nPersonal Food: Royal Roast",
}

ns.ConsumablesDB["DEMONHUNTER_HAVOC"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 243971 },
        { slot = "Head",        itemID = 244007 },
        { slot = "Shoulders",   itemID = 243991 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 244641 },
        { slot = "Boots",       itemID = 243953 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "Enchant Weapon - Jan'alai's Precision is the best weapon enchant, using one each of Enchant Weapon - Jan'alai's Precision and Enchant Weapon - Arcane Mastery can be better depending on your characters stats.",
    gems = {
        { label = "Eversong Diamond", itemID = 240967 },
        { label = "Other Gems", itemID = 240908 },
        { label = "Gem", itemID = 240904 },
        { label = "Gem", itemID = 240898 },
        { label = "Gem", itemID = 240890 },
        { label = "Gem", itemID = 240914 },
    },
    gemGuide = "Havoc Demon Hunter will want to use Powerful Eversong Diamond as their single Unique Eversong Diamond. To buff it, one each of Flawless Deadly Garnet, Flawless Deadly Amethyst, Flawless Deadly Peridot, and Flawless Deadly Lapis. Fill any remaining gem sockets with Flawless Deadly Garnet",
    consumables = {
        { label = "Flask", itemID = 241326 },
        { label = "Combat Potion", itemID = 241288 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 242275, alt = { itemID = 242747 } },
    },
    consumableGuide = "The best Flask for Havoc Demon Hunter is Flask of the Shattered Sun, though this depends on your precise gear and Flask of the Magisters can be used if you need Mastery more than Critical Strike.\n\nCurrently for Havoc Demon Hunter your best combat potion is Potion of Recklessness in best gear. This provides an INCREDIBLE amount of stats and is strongest if put towards Critical Strike.\n\nThe best healing potion for Havoc Demon Hunter is Concentrated Silvermoon Health Potion.\n\nFor their weapons, Havoc Demon Hunters will always use Thalassian Phoenix Oil.\n\nWith Midnight, the new Augment Rune is Void-Touched Augment Rune. While these provide a DPS increase, they are often expensive and considered optional.\n\nIn Midnight, Havoc Demon Hunters currently prefer Primary Stat food. The Feast Hearty Harandar Celebration is preferred as it also gives Stamina.\n\nFeast: Hearty Harandar Celebration\nPersonal Food: Royal Roast / Hearty Royal Roast",
}

ns.ConsumablesDB["DEMONHUNTER_VENGEANCE"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Head",        itemID = 243981, alt = 244007 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Shoulders",   itemID = 243963, alt = 243991 },
        { slot = "Legs",        itemID = 244641, alt = 244643 },
        { slot = "Boots",       itemID = 244009, alt = 243953 },
        { slot = "Ring",        itemID = 243957, alt = 244015 },
    },
    enchantGuide = "For Weapons, since we have several different options, I've listed them here. Note that the best option may vary depending on your current gear setup so it's best to sim them yourself:\n\nDouble Enchant Weapon - Acuity of the Ren'dorei defensively.\nAny combination of the secondary enchants offensively (Enchant Weapon - Berserker's Rage, Enchant Weapon - Jan'alai's Precision, Enchant Weapon - Worldsoul Tenacity, Enchant Weapon - Arcane Mastery)\n\nNote: It does not matter what weapon you enchant with which effect. Procs occur at the same rate for main-hand and off-hand weapons. The effect is doubled with the same proc rate, if used on both.",
    gems = {
        { label = "Eversong Diamond", itemID = 240983, alt = 240967 },
        { label = "Other Gems", itemID = 240890, alt = 240894 },
        { label = "Gem", itemID = 240967 },
        { label = "Gem", itemID = 240894 },
        { label = "Lapi", itemID = 240916 },
        { label = "Garnet", itemID = 240906 },
        { label = "Amethyst", itemID = 240900 },
    },
    gemGuide = "For maximum damage, you will want to use Powerful Eversong Diamond as your Eversong Diamond, and a combination of at least 1 of each gem type, then Flawless Deadly Peridot or Flawless Versatile Peridot in all other sockets.\n\nPeridot: Flawless Versatile Peridot\nLapis: Flawless Quick Lapis\nGarnet: Flawless Quick Garnet\nAmethyst: Flawless Quick Amethyst\n\nAs the damage increase provided by Powerful Eversong Diamond is so low, you should likely opt instead for Indecipherable Eversong Diamond as the consistent mainstat also provides more defensive benefit. As always, sim yourself, just in case.",
    consumables = {
        { label = "Flask", itemID = 241325 },
        { label = "Combat Potion", itemID = 241308 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255846, alt = { itemID = 242273 } },
    },
    consumableGuide = "The best Flask for Vengeance Demon Hunters is Flask of the Blood Knights, though any Flask can be good depending on your personal sim.\n\nWhile there are many options for potions, Vengeance Demon Hunters will nearly always use Light's Potential. Draught of Rampant Abandon grants more stat but can get you killed due to the silence, so it's not worth the risk. Meanwhile, Potion of Recklessness will practically get you to the stat cap, so it can have niche uses.\n\nThe best healing potion for Vengeance Demon Hunters is Concentrated Silvermoon Health Potion.\n\nThalassian Phoenix Oil is a good option for Vengeance Demon Hunters because it provides both of our preferred Secondary stats. However, if you want to focus purely on damage, you can use Smuggler's Enchanted Edge for single-target or Refulgent Weightstone/Refulgent Whetstone depending on your weapon type for AoE.\n\nWith The War Within, the new Augment Rune is Void-Touched Augment Rune.\n\nIn Midnight, Vengeance Demon Hunters are most likely using the Primary feast due to the outsized value of Primary stat in early expansion. As always, sim your character to check which food is the best for your configuration of Secondary stats.\n\nSecondary stat food: Blooming Feast/Quel'dorei Medley (Feast), Champion's Bento/Flora Frenzy/Jester's Board/Beledar's Bounty(Individual Food)\nAgility Feast: Harandar Celebration/Silvermoon Parade",
}

ns.ConsumablesDB["DEMONHUNTER_DEVOURER"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244031 },
        { slot = "Off Hand",    itemID = 244031 },
        { slot = "Head",        itemID = 244007 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Shoulders",   itemID = 243991 },
        { slot = "Legs",        itemID = 240133 },
        { slot = "Boots",       itemID = 243953 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "For Season Two, Devourer seeks to use Enchant Weapon - Arcane Mastery on both its weapons! Mastery is a very powerful stat for us, but its possible other enchants can be better depending on your gear. It's important to sim yourself as you gear to ensure you're always using the best!",
    gems = {
        { label = "Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240898 },
        { label = "Gem", itemID = 240900 },
    },
    gemGuide = "For maximum damage, you will want to use Indecipherable Eversong Diamond as your Diamond, and then either Flawless Deadly Amethyst or Flawless Quick Amethyst in the other sockets! As always, sim yourself for the most accurate results!.",
    consumables = {
        { label = "Flask", itemID = 241322, alt = { itemID = 241326 } },
        { label = "Combat Potion", itemID = 241288 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 275266, alt = { itemID = 242274 } },
    },
    consumableGuide = "The best Flask for Devourer Demon Hunters is Flask of the Magisters, though Flask of the Blood Knights can be useful for Annihilator. Flask of the Shattered Sun can also be useful, should you have much higher Mastery relative to your Critical Strike.\n\nWhile there are many options for potions, Devourer Demon Hunters will use Potion of Recklessness. The potion gives you a large amount of your most common secondary stat (by raw stat value). Void-Scarred does not care if this potion procs Crit or Mastery, while Annihilator prefers that it always procs Mastery. No matter the build, ensure you are NOT proccing haste.\n\nThe best healing potion for Devourer Demon Hunters is Concentrated Silvermoon Health Potion.\n\nFor their weapons, Devourer Demon Hunters will always use Thalassian Phoenix Oil.\n\nThe best Augment run for Devourer Demon Hunter is Void-Touched Augment Rune.\n\nIn Midnight, Devourer Demon Hunters are looking to use secondary stat buffs when possible, as the relative value of secondary stats have raised in this season.\n\nFeast: Silvermoon Parade\nPersonal Food: Royal Roast",
}

ns.ConsumablesDB["DRUID_BALANCE"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244031 },
        { slot = "Head",        itemID = 244007 },
        { slot = "Shoulders",   itemID = 243991 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 240133 },
        { slot = "Boots",       itemID = 243953 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "The option for weapon enchants comes down to flat secondary stats in Thalassian Phoenix Oil or a damage proc in Smuggler's Enchanted Edge. The damage proc is currently simming quite low, so we opt for the secondary stats instead.",
    gems = {
        { label = "Eversong Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240900 },
        { label = "Gem", itemID = 251487 },
        { label = "Garnet", itemID = 240908 },
        { label = "Peridot", itemID = 240892 },
        { label = "Lapi", itemID = 240918 },
    },
    gemGuide = "Due to differences in stat distribution you may want to use gems with different stats on them. Generally Balance always opt into ones with Mastery. There are also effects like Prismatic Focusing Iris that increases in power the more different colored gems you have.\n\nGarnet: Flawless Masterful Garnet\nPeridot: Flawless Masterful Peridot\nAmethyst: Flawless Quick Amethyst\nLapis: Flawless Masterful Lapis",
    consumables = {
        { label = "Flask", itemID = 241322 },
        { label = "Combat Potion", itemID = 241308, alt = { itemID = 241288 } },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243733 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255847, alt = { itemID = 242274 } },
    },
    consumableGuide = "You should sim your character to determine the best Flask option for you.\n\nThe available flasks are:\nFlask of the Shattered Sun\nFlask of the Blood Knights\nFlask of the Magisters\nFlask of Thalassian Resistance\n\nYou should sim your character to pick the best option for you here. If you don't want to to do then you can safely opt into Light's Potential either or Potion of Recklessness\n\nThe best healing potion for Balance Druid is Concentrated Silvermoon Health Potion.\n\nFor their weapons, Balance Druid will always use Thalassian Phoenix Oil.\n\nWith Midnight, the new Augment Rune is Void-Touched Augment Rune.\n\nIn Midnight you have a choice between secondary stat food or Intellect food. There are personal food and feast versions of both. Generally you want to opt for the food that gives Intellect over the ones that give secondary stat.\n\nFeast: Impossibly Royal Roast\nPersonal Food: Champion's Bento",
}

ns.ConsumablesDB["DRUID_FERAL"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Head",        itemID = 244007 },
        { slot = "Shoulders",   itemID = 243991 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 244641 },
        { slot = "Boots",       itemID = 243953 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "",
    gems = {
        { label = "Eversong Diamond", itemID = 240967 },
        { label = "Other Gems", itemID = 240900 },
        { label = "Peridot", itemID = 240891 },
        { label = "Garnet", itemID = 240908 },
        { label = "Lapi", itemID = 240918 },
    },
    gemGuide = "For maximum damage, you will want to use Powerful Eversong Diamond as your Eversong Diamond. The remaining slots are filled with either of the ones listed below:\n\nAmethyst: Flawless Quick Amethyst\nPeridot: Flawless Masterful Peridot\nGarnet: Flawless Masterful Garnet\nLapis: Flawless Masterful Lapis\n\nWhich ones you use does not matter, however you'll want to use one of each colour. The gem selction can differ depending on your stats, so always use a simulation if you want the optimal result.",
    consumables = {
        { label = "Weapon - Main Hand", itemID = 244029 },
        { label = "Flask", itemID = 241326, alt = { itemID = 241322 } },
        { label = "Combat Potion", itemID = 241288 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255846, alt = { itemID = 242275 } },
    },
    consumableGuide = "The best Flask for Feral Druids is bewteen Flask of the Shattered Sun and Flask of the Magisters. Which one is better will usually depend on your gear, and its best to use a simulation to compare.\n\nWhile there are many options for potions, Feral Druids will use Draught of Rampant Abandon. The void pools spawned by this poiton silence you, which means you need to actively run out of them. Switching to Light's Potential is advised if the void pool mechanism becomes overwhelming.\n\nThe best healing potion for Feral Druids is Silvermoon Health Potion.\n\nFor Feral Druids weapons the best option is listed below:\n\nMain Hand: Thalassian Phoenix Oil\n\nWith The War Within, the new Augment Rune is Void-Touched Augment Rune.\n\nIn Midnight, Feral Druids will use Feasts where possible due to the relative strength of agility to Secondary stats. As always, sim your character to check which food is the best for your configuration of Secondary stats.\n\nFeast: Blooming Feast\nPersonal Food: Crimson Calamari\n\nIt's also worth noting that you can use Taa's such as Sanguithorn Tea alongside a regular food buff for a 5% speed increase.",
}

ns.ConsumablesDB["DRUID_GUARDIAN"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 243973 },
        { slot = "Shoulders",   itemID = 243963 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Head",        itemID = 243981 },
        { slot = "Legs",        itemID = 244641 },
        { slot = "Boots",       itemID = 244009 },
        { slot = "Ring",        itemID = 244015 },
    },
    enchantGuide = "Enchant Weapon - Berserker's Rage is going to be the most effective weapon enchant overall.",
    gems = {
        { label = "Algari Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240894 },
    },
    gemGuide = "Guardian Druid opts to gem Flawless Versatile Peridot in all sockets.",
    consumables = {
        { label = "Flask", itemID = 241324 },
        { label = "Combat Potion", itemID = 241292, alt = { itemID = 241308 } },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255845, alt = { itemID = 255846 } },
    },
    consumableGuide = "The best Flask for Guardian Druids is Flask of the Blood Knights. Although all 4 of our stats are fairly close and if you find you have too much haste you can opt for another secondary stat comfortably.\n\nThe best stat boosting potion for Guardian Druids is Draught of Rampant Abandon or Light's Potential if the void zones are too bothersome.\n\nThe best healing potion for Guardian Druids is Concentrated Silvermoon Health Potion.\n\nFor their weapons, Guardian Druids will always use Thalassian Phoenix Oil.\n\nWith Midnight, the new Augment Rune is Void-Touched Augment Rune.\n\nIn Midnight, Guardian Druid eats the feast (Silvermoon Parade) for buffs because primary stat is always the highest increase for us.",
}

ns.ConsumablesDB["DRUID_RESTORATION"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244029 },
        { slot = "Head",        itemID = 243951 },
        { slot = "Shoulders",   itemID = 244021 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 240155 },
        { slot = "Boots",       itemID = 243983 },
        { slot = "Ring",        itemID = 244015 },
    },
    enchantGuide = "",
    gems = {
        { label = "Diamond (one of)", itemID = 240983 },
        { label = "Other Gems", itemID = 240892 },
    },
    gemGuide = "",
    consumables = {
        { label = "Flask", itemID = 241324 },
        { label = "Combat Potion", itemID = 241288, alt = { itemID = 241300 } },
        { label = "Health Potion", itemID = 241304 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255846 },
    },
    consumableGuide = "In raid, you will use Flask of the Blood Knights on all fights.\n\nThere are a couple of different potions that can be useful for us:\n\nRaiding: Lightfused Mana Potion or Potion of Recklessness. The secondary stat potion is stronger overall and serves as a semi-cooldown. It does require you identify the most dangerous moments of the fight, so it can feel more complex to play. The mana potion is an acceptable fallback.\nMythic+: Potion of Recklessness.\n\nYou'll use Silvermoon Health Potion as your Health potion. Make sure you keybind it and use it often!\n\nYou'll put Thalassian Phoenix Oil on your weapon in both content types. Oil of Dawn is not very good.\n\nThe Augment Rune in Midnight is called Void-Touched Augment Rune. These can be expensive, so you are not expected to have one active at all times.",
}

ns.ConsumablesDB["EVOKER_DEVASTATION"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244029 },
        { slot = "Head",        itemID = 244007 },
        { slot = "Shoulders",   itemID = 243991 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 240133 },
        { slot = "Boots",       itemID = 243953 },
        { slot = "Ring",        itemID = 243987 },
    },
    enchantGuide = "Early on, Enchant Weapon - Acuity of the Ren'dorei is going to be your weapon enchant. As the expansion goes on, secondary stat-based weapon enchants will likely pull ahead. Use Raidbots to sim your own character.",
    gems = {
        { label = "Gems", itemID = 240983 },
        { label = "Gem", itemID = 240906 },
        { label = "Gem", itemID = 240908 },
        { label = "Gem", itemID = 240967 },
        { label = "Peridot", itemID = 240890 },
        { label = "Amethyst", itemID = 240898 },
        { label = "Lapi", itemID = 240914 },
    },
    gemGuide = "For maximum damage, you will want to use Indecipherable Eversong Diamond as your Diamond, and a mix of Flawless Quick Garnet and Flawless Masterful Garnet in all other sockets.\n\nPowerful Eversong Diamond is also very close, but requires a combination of at least 1 Peridot, 1 Lapis, 1 Garnet, and 1 Amethyst. Indecipherable Eversong Diamond does not require as many gem slots. As always, sim yourself.\n\nPeridot: Flawless Deadly Peridot\nAmethyst: Flawless Deadly Amethyst\nGarnet: Flawless Quick Garnet\nLapis: Flawless Deadly Lapis",
    consumables = {
        { label = "Flask", itemID = 241326, alt = { itemID = 241322 } },
        { label = "Combat Potion", itemID = 241288 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255846, alt = { itemID = 242272 } },
    },
    consumableGuide = "The best Flask for Devastation Evokers is Flask of the Shattered Sun. Flask of the Magisters and Flask of the Blood Knights can also be good to push your Haste and Mastery above Versatility for Potion of Recklessness.\n\nWhen it comes to combat potions, they are both close. Potion of Recklessness is best if your stats are good. Light's Potential is slightly worse, but does not have any special requirements.\n\nThe best healing potion for Devastation Evokers is Silvermoon Health Potion.\n\nFor their weapons, Devastation Evokers will always use Thalassian Phoenix Oil.\n\nIn Midnight, the new Augment Rune is Void-Touched Augment Rune. These provide a small gain, but are likely to be expensive. Augment runes are not necessary for most players!\n\nIn Midnight, personal stat food is no better than feast buffs. Intellect food is equivalent to Secondary stats. As always, sim your character to check which food is the best for your configuration of Secondary stats.\n\nFeast: Harandar Celebration and Quel'dorei Medley are equal\nPersonal Food: Champion's Bento\n\nIn addition to food, you can also consume any tea (ex: Sanguithorn Tea) for a movement speed increase that stacks with your food buff.",
}

ns.ConsumablesDB["EVOKER_PRESERVATION"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244029 },
        { slot = "Head",        itemID = 243951 },
        { slot = "Shoulders",   itemID = 244021 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 240155 },
        { slot = "Boots",       itemID = 243983 },
        { slot = "Ring",        itemID = 243959 },
    },
    enchantGuide = "",
    gems = {
        { label = "Diamond (one of)", itemID = 240983 },
        { label = "Other Gems", itemID = 240900 },
    },
    gemGuide = "",
    consumables = {
        { label = "Flask", itemID = 241322 },
        { label = "Combat Potion", itemID = 241288, alt = { itemID = 241300 } },
        { label = "Health Potion", itemID = 241304 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255846 },
    },
    consumableGuide = "In raid, you will use Flask of the Magisters on all fights. Flask of the Blood Knights is a reasonable alternative in Mythic+, or when you value increasing your damage over adding more healing.\n\nThere are a couple of different potions that can be useful for us:\n\nRaiding: Lightfused Mana Potion or Potion of Recklessness. The secondary stat potion is stronger overall but requires identifying the most dangerous moments of the fight so it can feel more complex to play. The mana potion is an acceptable fallback.\nMythic+: Potion of Recklessness.\n\nYou'll use Silvermoon Health Potion as your Health potion. Make sure you keybind it!\n\nYou'll put Thalassian Phoenix Oil on your weapon in both content types. Oil of Dawn is not competitive.\n\nThe Augment Rune this expansion is called Void-Touched Augment Rune. These can be expensive, so you are not expected to have one active at all times.",
}

ns.ConsumablesDB["EVOKER_AUGMENTATION"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244031 },
        { slot = "Head",        itemID = 244007 },
        { slot = "Shoulders",   itemID = 243991 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 240133 },
        { slot = "Boots",       itemID = 243953 },
        { slot = "Ring",        itemID = 243959 },
    },
    enchantGuide = "Enchant Weapon - Acuity of the Ren'dorei is the best overall choice of weapon enchant in PVE content for Augmentation Evoker.",
    gems = {
        { label = "Eversong Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240898 },
    },
    gemGuide = "For your Eversong Diamond, Indecipherable Eversong Diamond is the best overall option for Augmentation Evoker.\n\nAs for your other gems, Flawless Deadly Amethyst offers stats best aligned with Augmentation's stat priority, but you may consider alternative gem combinations as needed to best round out your stats.",
    consumables = {
        { label = "Flask", itemID = 241322 },
        { label = "Combat Potion", itemID = 241288 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 266985 },
    },
    consumableGuide = "The best Flask for Augmentation Evokers is Flask of the Magisters.\n\nThe best combat potion for Augmentation Evokers in all content is Potion of Recklessness.\n\nThe best healing potion for Augmentation Evokers is Concentrated Silvermoon Health Potion.\n\nFor their weapons, Augmentation Evokers will always use Thalassian Phoenix Oil.\n\nThe augment rune available for Augmentation Evoker is Void-Touched Augment Rune.\n\nAugmentation Evokers will likely prefer to use feasts which provide Intellect over other alternative food options. Personal food can be used instead of a feast, but this comes at the cost of bonus Stamina.\n\nFeast: Hearty Silvermoon Parade\nPersonal Food: Hearty Royal Roast",
}

ns.ConsumablesDB["HUNTER_BEASTMASTERY"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244031 },
        { slot = "Head",        itemID = 244007 },
        { slot = "Shoulders",   itemID = 243991 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 244641 },
        { slot = "Boots",       itemID = 243953 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "Your best Weapon enchants for most situations is Enchant Weapon - Arcane Mastery. Other enchants can win in specific scenarios.",
    gems = {
        { label = "Gems", itemID = 240967 },
        { label = "Gem", itemID = 240898 },
        { label = "Gem", itemID = 240918 },
        { label = "Gem", itemID = 240892 },
        { label = "Gem", itemID = 240908 },
        { label = "Gem", itemID = 240900 },
    },
    gemGuide = "You should use one Powerful Eversong Diamond and one each of Flawless Deadly Amethyst, Flawless Masterful Lapis, Flawless Masterful Peridot and Flawless Masterful Garnet.\n\nFill the rest with Flawless Deadly Amethyst or Flawless Quick Amethyst, depending on your sim.",
    consumables = {
        { label = "Flask", itemID = 241322 },
        { label = "Combat Potion", itemID = 241308, alt = { itemID = 241288 } },
        { label = "Health Potion", itemID = 271884 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Food", itemID = 275266, alt = { itemID = 275258 } },
    },
    consumableGuide = "The best flask for Beast Mastery Hunters is Flask of the Magisters, for all scenarios, as it is our best stat.\n\nThe best choice combat potion in Midnight Season 2 is Light's Potential, until you are at a higher level of gear with low versatility, then it becomes Potion of Recklessness.\n\nThe best healing potion for Beast Mastery Hunters is Concentrated Silvermoon Health Potion, as this is healing potion with the highest amount of healing.\n\nBeast Mastery Hunters use Thalassian Phoenix Oil as their temporary weapon buff in all scenarios.\n\nWith Midnight Season 2, the newest and best Augment Rune is the Void-Touched Augment Rune.\n\nYour best food in all situations is Feast of Knowledge, or an equivalent. If you want personal food you can use Venom-Spiced Cutlets, or an equivalent",
}

ns.ConsumablesDB["HUNTER_MARKSMANSHIP"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 243971 },
        { slot = "Head",        itemID = 243951 },
        { slot = "Shoulders",   itemID = 244021 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 244641 },
        { slot = "Boots",       itemID = 243983 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "Enchant Weapon - Jan'alai's Precision is going to be strongest.",
    gems = {
        { label = "Diamond", itemID = 240967 },
        { label = "Other Gems", itemID = 240890 },
        { label = "Gem", itemID = 240908 },
        { label = "Amethyst", itemID = 240898 },
        { label = "Lapi", itemID = 240914 },
        { label = "Lapi", itemID = 240983 },
    },
    gemGuide = "If you have 5 sockets or more in your gear, you can make use of Powerful Eversong Diamond as your Eversong Diamond, and a combination of at least 1 Peridot, 1 Amethyst, 1 Garnet, and 1 Lapis, then Flawless Masterful Garnet in all other sockets. This fully stacks up the Crit Damage Effect of the Eversong Diamond, which is particularly potent for us as Marksmanship Hunters, since we have tons of Crit naturally, and our Aimed Shot is guaranteed to Crit.\n\nPeridot: Flawless Deadly Peridot\nAmethyst: Flawless Deadly Amethyst\nGarnet: Flawless Masterful Garnet\nLapis: Flawless Deadly Lapis\n\nIf you do not have the sockets required to fully realize the Powerful Eversong Diamond, simply use Indecipherable Eversong Diamond instead.",
    consumables = {
        { label = "Flask", itemID = 241326 },
        { label = "Combat Potion", itemID = 241288 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255846, alt = { itemID = 255845 } },
        { label = "Food", itemID = 242747 },
    },
    consumableGuide = "The best Flask for Marksmanship Hunters is Flask of the Shattered Sun.\n\nMarksmanship Hunters should use Potion of Recklessness, which gives you a large amount of your highest secondary stat for 30 seconds and wants to be synced with your cooldowns. It is sensitive to Critical Strike actually being your highest stat when you press it, so if your gear has not got there yet, use Light's Potential instead.\n\nThe best healing potion for Marksmanship Hunters is Concentrated Silvermoon Health Potion.\n\nFor their weapons, Marksmanship Hunters will always use Thalassian Phoenix Oil.\n\nThe best Augment Rune in Midnight is Void-Touched Augment Rune.\n\nMarksmanship Hunters prefers eating Agility food (such as Feasts) over secondary stat foods when given the option.\n\nFeast: Harandar Celebration or Silvermoon Parade\nPersonal Food: Hearty Royal Roast",
}

ns.ConsumablesDB["HUNTER_SURVIVAL"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244031 },
        { slot = "Head",        itemID = 244007 },
        { slot = "Shoulders",   itemID = 243991 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 244641 },
        { slot = "Boots",       itemID = 243953 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "For our weapon, we recommend Enchant Weapon - Arcane Mastery, as it provides our best stat, mastery.",
    gems = {
        { label = "Gems", itemID = 240983 },
        { label = "Gem", itemID = 240898 },
        { label = "Gem", itemID = 240900 },
        { label = "Gem", itemID = 241288 },
    },
    gemGuide = "Generally, for all of our gems, we recommend Flawless Deadly Amethyst as it has our best stats on one package, but there are some edge cases where this is not true.\n\nFor example, if you happen to have 1140 crit and 1120 mastery, it might be in your best interest to swap your Flawless Deadly Amethyst to Flawless Quick Amethyst, to ensure Potion of Recklessness picks Mastery over Crit.",
    consumables = {
        { label = "Flask", itemID = 245933 },
        { label = "Combat Potion", itemID = 241288 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Food", itemID = 255845 },
    },
    consumableGuide = "The best flask for Survival Hunters is Fleeting Flask of the Magisters, for all scenarios, as it is our best stat.\n\nThe best choice combat potion in Midnight Season 2 is Potion of Recklessness for all scenarios.\nIdeally, we want Mastery or Crit to be our highest stat when using this potion. This can get slightly more complex than usual in Midnight Season 2, given how many random stat procs we can trigger in the form of Venomcursed items, folio buffs, weapon enchants and trinket procs.\n\nThe best healing potion for Survival Hunters is Concentrated Silvermoon Health Potion, as this is Healing Potion with the highest amount of healing.\n\nSurvival Hunters use Thalassian Phoenix Oil as their temporary weapon buff in all scenarios.\n\nWith Midnight Season 2, the new and best Augment Rune is the Void-Touched Augment Rune.\n\nWe recommend Silvermoon Parade for the primary stat. You can also get away with Quel'dorei Medley if you're very close to BiS. You can also \"Snapshot\" Quel'dorei Medley by unequipping certain items to force it to grant a particular stat, which may come in useful to make sure mastery remains your highest stat.",
}

ns.ConsumablesDB["MAGE_ARCANE"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244029 },
        { slot = "Head",        itemID = 244007 },
        { slot = "Shoulders",   itemID = 244021 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 240155 },
        { slot = "Boots",       itemID = 243983 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "Enchant Weapon - Acuity of the Ren'dorei is most likely going to be the best weapon enchant option for people, however any one of the other max level options are just as well off.",
    gems = {
        { label = "Eversong Diamond", itemID = 240967 },
        { label = "Other Gems", itemID = 240900 },
        { label = "Peridot", itemID = 240892 },
        { label = "Garnet", itemID = 240908 },
        { label = "Lapi", itemID = 240918 },
    },
    gemGuide = "For maximum damage, you will want to use Powerful Eversong Diamond as your Eversong Diamond, and a combination of at least 1 of each other gem type, then Flawless Quick Amethyst in all remaining sockets. As always though, sim for best results!\n\nAmethyst: Flawless Quick Amethyst\nPeridot: Flawless Masterful Peridot\nGarnet: Flawless Masterful Garnet\nLapis: Flawless Masterful Lapis",
    consumables = {
        { label = "Flask", itemID = 241324 },
        { label = "Combat Potion", itemID = 241308 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255845 },
    },
    consumableGuide = "The best Flask for Arcane Mages is Flask of the Blood Knights, overall the other options are completely useable too though.\n\nWhile there are many options for potions, Arcane Mages will always use Light's Potential.\n\nThe best healing potion for Arcane Mages is Concentrated Silvermoon Health Potion.\n\nFor their weapons, Arcane Mages will always use Thalassian Phoenix Oil.\n\nThe new Augment Rune this expansion is Void-Touched Augment Rune.\n\nWe'll just use whatever max level primary stat food is available for this season!\n\nFeast: Silvermoon Parade\nPersonal Food: Anything that gives max stats is basically useable, sim for best results!",
}

ns.ConsumablesDB["MAGE_FIRE"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244029 },
        { slot = "Head",        itemID = 244007 },
        { slot = "Shoulders",   itemID = 243991 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 240133 },
        { slot = "Boots",       itemID = 243953 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "Early on, Enchant Weapon - Acuity of the Ren'dorei is going to be your weapon enchant. As the expansion goes on, secondary stat-based weapon enchants will likely pull ahead.",
    gems = {
        { label = "Gems", itemID = 240967 },
        { label = "Gem", itemID = 240900 },
        { label = "Peridot", itemID = 240892 },
        { label = "Garnet", itemID = 240906 },
        { label = "Lapi", itemID = 240916 },
        { label = "Lapi", itemID = 240983 },
    },
    gemGuide = "For maximum damage, you will want to use Powerful Eversong Diamond as your Diamond, and a combination of at least 1 Peridot, 1 Lapis, 1 Garnet, and 1 Amethyst, then Flawless Quick Amethyst in all other sockets.\n\nPeridot: Flawless Masterful Peridot\nAmethyst: Flawless Quick Amethyst\nGarnet: Flawless Quick Garnet\nLapis: Flawless Quick Lapis\n\nAs the damage increase provided by Powerful Eversong Diamond is low, and some Fire Mages may opt for Indecipherable Eversong Diamond instead, since it does not require as many gem slots. As always, sim yourself.",
    consumables = {
        { label = "Flask", itemID = 241322, alt = { itemID = 241324 } },
        { label = "Combat Potion", itemID = 241308 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255846, alt = { itemID = 242272 } },
    },
    consumableGuide = "The best Flask for Fire Mages is Flask of the Magisters, though Flask of the Blood Knights can be better depending on your stats. Flask of Thalassian Resistance is also a decent option for Pyroclasm builds (if they get buffed).\n\nWhen it comes to combat potions, Fire Mage uses Light's Potential.\n\nNotes:\nSunfuryLight's Potential Int pot\nFrostfirePotion of Recklessness Reckless pot\n\nThe best healing potion for Fire Mages is Silvermoon Health Potion.\n\nFor their weapons, Fire Mages will always use Thalassian Phoenix Oil.\n\nIn Midnight, the new Augment Rune is Void-Touched Augment Rune. These provide a small gain, but are likely to be expensive. Augment runes are not necessary for most players!\n\nIn Midnight, personal stat food is no better than feast buffs. Intellect food is equivalent to Secondary stats. As always, sim your character to check which food is the best for your configuration of Secondary stats.\n\nFeast: Harandar Celebration and Quel'dorei Medley are equal\nPersonal Food: Champion's Bento",
}

ns.ConsumablesDB["MAGE_FROST"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244029 },
        { slot = "Head",        itemID = 244007 },
        { slot = "Shoulders",   itemID = 243991 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 240133 },
        { slot = "Boots",       itemID = 243953 },
        { slot = "Ring",        itemID = 256739 },
    },
    enchantGuide = "Enchant Weapon - Acuity of the Ren'dorei is the best primary stat weapon enchant and will typically be the best enchantment early on in the expansion.",
    gems = {
        { label = "Thalassian Diamond", itemID = 240967 },
        { label = "Other Gems", itemID = 240898 },
        { label = "Garnet", itemID = 240908 },
        { label = "Peridot", itemID = 240892 },
        { label = "Lapi", itemID = 240918 },
    },
    gemGuide = "For maximum damage, you will want to use Powerful Eversong Diamond as your Thalassian Diamond, and a combination of at least 1 Amethyst, 1 Garnet, 1 Peridot, and 1 Lapis.\n\nAmethyst: Flawless Deadly Amethyst\nGarnet: Flawless Masterful Garnet\nPeridot: Flawless Masterful Peridot\nLapis: Flawless Masterful Lapis",
    consumables = {
        { label = "Flask", itemID = 241322 },
        { label = "Combat Potion", itemID = 241308, alt = { itemID = 241288 } },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255846, alt = { itemID = 242274 } },
        { label = "Tea", itemID = 242298, alt = { itemID = 242299 } },
    },
    consumableGuide = "The best Flask for Frost Mages is Flask of the Magisters.\n\nFrost Mages should use Potion of Recklessness as their combat potion in most cases, but in rare cases you may want to use Light's Potential with your specific gear. You should simulate the two options if you want to know which is best for you. Keep in mind that if you are using Vantus Rune: Radiant, it may make Potion of Recklessness significantly worse by causing it to grant versatility.\n\nThe best healing potion for Frost Mages is Concentrated Silvermoon Health Potion.\n\nFor their weapons, Frost Mages will always use Thalassian Phoenix Oil.\n\nWith The War Within, the new Augment Rune is Void-Touched Augment Rune. If you've farmed enough Renown, you can also use Ethereal Augment Rune or Soulgorged Augment Rune.\n\nIn Midnight, Frost Mages are most likely using personal stat food instead of feast buffs because the large item level jump has reduced the value of Intellect relative to Secondary stats. As always, sim your character to check which food is the best for your configuration of Secondary stats.\n\nFeast: Harandar Celebration\nPersonal Food: Champion's Bento\n\nIn addition to food, you can also consume tea for a gathering profession and movement speed increase that stacks with your food buff.\n\nArgentleaf Tea\nSanguithorn Tea\nAzeroot Tea",
}

ns.ConsumablesDB["MONK_BREWMASTER"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Head",        itemID = 243951 },
        { slot = "Shoulders",   itemID = 244021 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 244641 },
        { slot = "Boots",       itemID = 243983 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "In general, a Brewmaster can decide between a slightly more offensive or defensive set of weapon enchants by opting for either Enchant Weapon - Acuity of the Ren'dorei or a secondary stat effect such as Enchant Weapon - Worldsoul Tenacity as desired. If you are dual-wielding, you get two weapons to enchant, whereas using a 2-handed weapon only gives you one weapon to enchant; which hand your weapon enchants are on ultimately does not matter. If you use different enchants on each weapon, their procs will be independent of each other. With two of the same enchant, the proc rate stays the same, but its effect will be increased. What this all means is that any combination of the enchants above could prove useful to you, but none of them will be what ultimately determines your performance. They may be freely mixed and matched based on what your own character needs with the help of simulations.",
    gems = {
        { label = "Eversong Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240914 },
        { label = "Gem", itemID = 240910 },
        { label = "Gem", itemID = 240898 },
        { label = "Gem", itemID = 263897 },
    },
    gemGuide = "You will generally want to equip gems that grant Versatility or Critical Strike, such as the Flawless Deadly Lapis or Flawless Versatile Garnet, in any available gem slots. At higher gear levels, the Flawless Deadly Amethyst may also be appropriate. Sim yourself, just in case. Note that in Midnight all jewelry automatically comes with one socket, and you may add a socket to any Helm, Bracer, or Belt with a Radiant Jewelbinder from the Great Vault. Some rare items may even have two!\n\nMeanwhile, although there are multiple Eversong Diamonds available, stick to the Indecipherable Eversong Diamond by default. The alternatives require extra work for inferior results.",
    consumables = {
        { label = "Weapons (2h & Dual-Wield)", itemID = 244029 },
        { label = "Flask", itemID = 241320 },
        { label = "Combat Potion", itemID = 241308 },
        { label = "Health Potion", itemID = 271884, alt = { itemID = 5512 } },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Food", itemID = 255845, alt = { itemID = 255846 } },
        { label = "Augment Rune", itemID = 259085 },
    },
    consumableGuide = "Flask of Thalassian Resistance is your default flask choice in Midnight, offering the most generally useful stat of Critical Strike. However, both the Flask of the Shattered Sun and Flask of the Magisters can also be potent or even superior depending on your current gear.\n\nRemember, you can also acquire conjured versions of these flasks from a Cauldron of Sin'dorei Flasks, provided the Alchemist who placed it knows the recipes!\n\nLight's Potential acts as your most consistently useful combat potion, providing a large burst of Agility for a long period of time, though there are a number of competitive options in Midnight. There is also the Draught of Rampant Abandon, which offers more Agility at the cost of potentially spawning puddles of The Void's Toll under your feet to silence and pacify your character.\n\nRaid: Light's Potential\nMythic+: Light's Potential/Draught of Rampant Abandon\n\nAs with flasks, you may obtain temporary conjured versions of any of these potions from an Alchemist's Voidlight Potion Cauldron, assuming they know the recipes.\n\nConcentrated Silvermoon Health Potion is the default healing potion for Brewmaster Monks, offering improved healing over a regular Silvermoon Health Potion. As a staple craft of Alchemists seeking to level the profession, you should have access to plenty of this consumable at a reasonable price, though only one may be used every 5 minutes.\n\nIn addition, remember that a Warlock's Healthstone is considered a separate healing item and will not share a cooldown with the healing potion above. Use it as another resource once per encounter!\n\nBrewmaster Monks should use a Thalassian Phoenix Oil as their preferred weapon buff item, giving a substantial amount of both Critical Strike and Haste for 2 hours. Remember to apply it to both weapons if dual wielding!\n\nFeast: (Hearty) Silvermoon Parade/Harandar Celebration\nPersonal Food: There are two food items that provide the same effect of increasing your Agility: Royal Roast or Impossibly Royal Roast. Find whichever is cheapest to acquire, or consider an alternative such as Champion's Bento which increases your highest secondary stat instead.\n\nMidnight Season 2 additionally features \"hearty\" versions of food items, which can be created by combining multiples of a given item together (such as the Hearty Silvermoon Parade). These items, in addition to being warband-bound, keep their buffs through death. Seek them out for use in areas where you are likely to die and lose an otherwise normal food buff.\n\nThough less important for your success in group content, Void-Touched Augment Rune offers a small amount of additional Agility. However, the effect will be lost on death, making this a very expensive consumable effect to maintain. All the same, aim to keep a few of these handy for those moments when you need to eke out every bit of damage from your character.\n\nShould you need access to a Bloodlust effect and a class with the ability is not available, you may also wish to hold on to a small number of drums consumables. These allow you to trigger a slightly weaker version of the bonus Haste from these spells, but that is still better than not having it at all! For Level 90 characters, the only drums that are usable are the Void-Touched Drums.\n\nFinally, you have access to a battle-resurrection consumable: Emergency Soul Link. Although these have a cast time (during which you cannot dodge), they are indispensable if your group is otherwise missing this utility. Have a few on hand, just in case, and make sure to use the higher-ranked version to remove the otherwise small chance of the effect failing!",
}

ns.ConsumablesDB["MONK_MISTWEAVER"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244029 },
        { slot = "Shoulders",   itemID = 244021 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 240133 },
        { slot = "Boots",       itemID = 243983 },
        { slot = "Ring",        itemID = 244015 },
    },
    enchantGuide = "The best weapon enchant for Mistweaver Monks will be Enchant Weapon - Acuity of the Ren'dorei in nearly all cases.\n\nThe Intellect boost it provides makes it the stronger choice throughout the season, even before you've acquired your best-in-slot gear. Once you're fully geared, it's worth checking QE Live's weapon enchant recommendations to see whether Enchant Weapon - Berserker's Rage pulls ahead at that point.\n\nMistweaver Monk Stat Priority",
    gems = {
        { label = "Eversong Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240890 },
    },
    gemGuide = "For our Eversong Diamond, you will want to use Indecipherable Eversong Diamond to maximize your Intellect gain (as the other Eversong Diamond secondary effects are just not worth the loss in Intellect) alongside filling all your other socket slots with Flawless Deadly Peridot.\n\nAs always, double check your stats and gem recommendations through QE Live to ensure you're making the best decision for your gearing situation.",
    consumables = {
        { label = "Helmet", itemID = 243951 },
        { label = "Flask", itemID = 241324 },
        { label = "Combat Potion", itemID = 241288 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Combat Potion", itemID = 241302 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Group Feast", itemID = 266996 },
        { label = "Food", itemID = 242747 },
    },
    consumableGuide = "The best Flask for Mistweaver Monks in Midnight Season 2 is Flask of the Blood Knights, though Flask of the Shattered Sun can be used if you find yourself with too much Haste. Again, please use QE LIve to determine this for your current needs.\n\nFor Mistweaver Monks, the best combat potion is Potion of Recklessness.\n\nI do not recommend using mana potions in any form of combat, but if you decide against this advice, the potion you're looking for is the Lightfused Mana Potion.\n\nThe best healing potion for Mistweaver Monks is Concentrated Silvermoon Health Potion.\n\nFor our weapons, Mistweaver Monks will always use Thalassian Phoenix Oil. While there is an option that has a chance to apply shields onto an ally you heal, the output just isn't worth the loss of secondary stat.\n\nWith Cooking in Midnight, there are different methods of increasing your stats through food! Both feasts and personal food can increase either your Intellect or your highest secondary stat, with personal food having more combination of options albeit at a lower stat gain. By combining the same dish with itself you can make Hearty variants, that act as if you had a weaker version of the Alchemical Flavor Pocket from Dragonflight, allowing the buff from food to persist through death.\n\nFor Mistweaver food options, we'll be going with Intellect-increasing foods below:\n\nFeast: Hearty Harandar Celebration\nPersonal Food: Hearty Royal Roast (or the Vegetarian option, Hearty Impossibly Royal Roast)\n\nIn Midnight Season 2, healers will focus on gaining Mana water from Cooking! There are several options that stack very high and replenish the most amount of mana per second:\n\nArgentleaf Tea\nSanguithorn Tea\nAzeroot Tea\nMana Lily Tea\nTranquility Bloom Tea\n\nPersonally, I'd suggest choosing whichever is the cheapest on the Auction House at the time, since they offer virtually no difference with the latter two not having the movement speed increase buff on them.",
}

ns.ConsumablesDB["MONK_WINDWALKER"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244029 },
        { slot = "Head",        itemID = 244007 },
        { slot = "Shoulders",   itemID = 243991 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 244641 },
        { slot = "Boots",       itemID = 243953 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "Enchant Weapon - Acuity of the Ren'dorei will be the safest weapon enchant for all content. Like what gems to select, this decision is the easiest, and one of the more important, decisions to use Raidbots to sim the different options.",
    gems = {
        { label = "Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240890 },
        { label = "Amethyst", itemID = 240900 },
        { label = "Garnet", itemID = 240906 },
    },
    gemGuide = "For maximum damage, you will want to use Indecipherable Eversong Diamond as your Diamond, and fill the rest of the slots with gems that increase whatever stats you need the most. This decision is the easiest, and one of the more important, decisions to use Raidbots to sim the different options.\n\nPeridot: Flawless Deadly Peridot\nAmethyst: Flawless Quick Amethyst\nGarnet: Flawless Quick Garnet",
    consumables = {
        { label = "Flask", itemID = 241324 },
        { label = "Combat Potion", itemID = 241288 },
        { label = "Health Potion", itemID = 271883 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255846, alt = { itemID = 255845 } },
    },
    consumableGuide = "Overall the best Flask for Windwalker Monks is Flask of the Blood Knights. Any of the Flasks that give Haste, Critical Strike, or Mastery will be viable options, just be sure that your sims are using the one you want and it will adjust your gems and enchants if needed.\n\nWhile there are many options for potions, Windwalker Monks will always use Potion of Recklessness.\n\nThe best healing potion for Windwalker Monks is Concentrated Silvermoon Health Potion.\n\nFor their weapons, Windwalker Monks will always use Thalassian Phoenix Oil.\n\nWith Midnight, the new Augment Rune is Void-Touched Augment Rune.",
}

ns.ConsumablesDB["PALADIN_HOLY"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244029 },
        { slot = "Shoulders",   itemID = 244021 },
        { slot = "Chest",       itemID = 244003 },
        { slot = "Legs",        itemID = 240155 },
        { slot = "Boots",       itemID = 243983 },
        { slot = "Ring",        itemID = 243959 },
    },
    enchantGuide = "Enchant Weapon - Acuity of the Ren'dorei is the best weapon enchant in all content for Holy Paladin.",
    gems = {
        { label = "Eversong Diamond", itemID = 240969 },
        { label = "Other Gems", itemID = 240900 },
        { label = "Gem", itemID = 240983 },
        { label = "Garnet", itemID = 240908 },
        { label = "Peridot", itemID = 240892 },
        { label = "Lapi", itemID = 240918 },
    },
    gemGuide = "The best Everson Diamond is Telluric Eversong Diamond as it gives a bit of mana. Indecipherable Eversong Diamond provides more direct throughput increase as it gives more Intellect, but the difference is very minor.\nBeyond that, you want to use at least 1 Garnet, 1 Lapis, and 1 Perido, then Flawless Quick Amethyst in all other sockets.\n\nAmethyst: Flawless Quick Amethyst\nGarnet: Flawless Masterful Garnet\nPeridot: Flawless Masterful Peridot\nLapis: Flawless Masterful Lapis",
    consumables = {
        { label = "Helmet", itemID = 243951 },
        { label = "Flask", itemID = 241322 },
        { label = "Combat Potion", itemID = 241308 },
        { label = "Combat Potion", itemID = 241300 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 242747, alt = { itemID = 266985 } },
    },
    consumableGuide = "The best Flask for Holy Paladins is Flask of the Magisters in all content.\n\nHoly Paladins will use Light's Potential to help with throughput.\nIf you really need mana you can use Lightfused Mana Potion.\n\nThe best healing potion for Holy Paladins is Concentrated Silvermoon Health Potion.\n\nFor their weapons, Holy Paladins will use Thalassian Phoenix Oil as Herald, and Rite of Sanctification as Lightsmith.\n\nThe best Augment Rune is Void-Touched Augment Rune, but it is a very minor bonus, so only buy them if you don't know what else to spend your gold on.\n\nIn Midnight Season 2, Holy Paladins prefer using Primary stat foods.\n\nFeast: Hearty Silvermoon Parade or Hearty Harandar Celebration\nPersonal Food: Hearty Royal Roast or Hearty Impossibly Royal Roast\nMana Drink: Sanguithorn Tea. Grants the most mana of any drink and stacks to 1000.",
}

ns.ConsumablesDB["PALADIN_PROTECTION"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 243973 },
        { slot = "Shoulders",   itemID = 243963 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Head",        itemID = 243981 },
        { slot = "Legs",        itemID = 244641 },
        { slot = "Boots",       itemID = 244009 },
        { slot = "Ring",        itemID = 244015 },
    },
    enchantGuide = "Enchant Weapon - Berserker's Rage is going to be the most effective weapon enchant overall.",
    gems = {
        { label = "Algari Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240894 },
    },
    gemGuide = "Protection Paladin opts to gem Flawless Versatile Peridot in all sockets.",
    consumables = {
        { label = "Flask", itemID = 241324 },
        { label = "Combat Potion", itemID = 241292, alt = { itemID = 241308 } },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255845, alt = { itemID = 255846 } },
    },
    consumableGuide = "The best Flask for Protection Paladin is Flask of the Blood Knights.\n\nThe best stat boosting potions for Prot Paladins are Draught of Rampant Abandon or Light's Potential.\n\nThe best healing potion for Protection Paladin is Concentrated Silvermoon Health Potion.\n\nFor their weapons, Protection Paladins will always use Thalassian Phoenix Oil.\n\nIn Midnight, the new Augment Rune is Void-Touched Augment Rune.\n\nIn Midnight, Protection Paladin eats the feast (Silvermoon Parade) for buffs because primary stat is always the highest increase for us.",
}

ns.ConsumablesDB["PALADIN_RETRIBUTION"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244031 },
        { slot = "Head",        itemID = 244007 },
        { slot = "Shoulders",   itemID = 243990 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 244641 },
        { slot = "Boots",       itemID = 243952 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "For weapon enchant, Enchant Weapon - Arcane Mastery is recommended. Other secondary stat enchants can also be competitive as well.",
    gems = {
        { label = "Eversong Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240892 },
        { label = "Gem", itemID = 251513 },
    },
    gemGuide = "For maximum damage, you will want to use Indecipherable Eversong Diamond as your Eversong Diamond, and Flawless Masterful Peridot in all other sockets. Depending on your stats, other secondary stat gems can be reasonable alternatives, so sim your options just in case. If you have Loa Worshiper's Band, you will always want to use a Peridot gem in every non-Diamond slot.",
    consumables = {
        { label = "Flask", itemID = 241322 },
        { label = "Combat Potion", itemID = 241288 },
        { label = "Health Potion", itemID = 271883 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 242275, alt = { itemID = 255846 } },
    },
    consumableGuide = "The best Flask for Retribution Paladins is Flask of the Magisters. Other secondary stats can be reasonable alternatives.\n\nPotion of Recklessness is the strongest potion generally, but requires you to have stats that accommodate it. Either Critical Strike or Mastery is fine to have as your highest stat for it, but if it's Haste then Light's Potential is better.\n\nThe best healing potion for Retribution Paladins is Concentrated Silvermoon Health Potion.\n\nFor their weapons, Retribution Paladins will always use Thalassian Phoenix Oil.\n\nIn Midnight, the best Augment Rune is Void-Touched Augment Rune.\n\nIn Midnight Season 2, Retribution Paladins will prefer going back to Strength food, such as Royal Roast or Harandar Celebration.",
}

ns.ConsumablesDB["PRIEST_DISCIPLINE"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 243973 },
        { slot = "Shoulders",   itemID = 244021 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Head",        itemID = 243951 },
        { slot = "Legs",        itemID = 240133 },
        { slot = "Boots",       itemID = 243983 },
        { slot = "Ring",        itemID = 244015 },
    },
    enchantGuide = "Enchant Weapon - Berserker's Rage is your best option for a weapon enchant.",
    gems = {
        { label = "Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240890 },
    },
    gemGuide = "",
    consumables = {
        { label = "Flask", itemID = 241324 },
        { label = "Combat Potion", itemID = 241288, alt = { itemID = 241308 } },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255846 },
    },
    consumableGuide = "The best Flask for Discipline Priests is Flask of the Blood Knights.\n\nThere are a couple of different potions that have different useful scenarios for Discipline Priests:\n\nRaiding: Potion of Recklessness/Light's Potential\nMythic+: Potion of Recklessness, Light's Potential or Void-Shrouded Tincture for invisibility skips\n\nThe best healing potion for Discipline Priests is Concentrated Silvermoon Health Potion.\n\nDiscipline Priests should use Thalassian Phoenix Oil for their weapon buff.\n\nWith Midnight, the new Augment Rune is Void-Touched Augment Rune",
}

ns.ConsumablesDB["PRIEST_HOLY"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244029 },
        { slot = "Shoulders",   itemID = 244021 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Head",        itemID = 243951 },
        { slot = "Legs",        itemID = 240133 },
        { slot = "Boots",       itemID = 243983 },
        { slot = "Ring",        itemID = 243987 },
    },
    enchantGuide = "Enchant Weapon - Acuity of the Ren'dorei is your best option for a weapon enchant.",
    gems = {
        { label = "Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240910 },
    },
    gemGuide = "",
    consumables = {
        { label = "Flask", itemID = 241326 },
        { label = "Combat Potion", itemID = 241288, alt = { itemID = 241308 } },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255846 },
    },
    consumableGuide = "The best Flask for Holy Priests is Flask of the Shattered Sun.\n\nThere are a couple of different potions that have different useful scenarios for Holy Priests:\n\nRaiding: Potion of Recklessness/Light's Potential\nMythic+: Potion of Recklessness, Light's Potential or Void-Shrouded Tincture for invisibility skips\n\nThe best healing potion for Holy Priests is Concentrated Silvermoon Health Potion.\n\nFor their weapons, Holy Priests will always use Thalassian Phoenix Oil.\n\nWith Midnight, the new Augment Rune is Void-Touched Augment Rune\n\nIn Midnight\n\nFeast: Harandar Celebration\nPersonal Food: Royal Roast",
}

ns.ConsumablesDB["PRIEST_SHADOW"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244031 },
        { slot = "Head",        itemID = 244007 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Shoulders",   itemID = 243963 },
        { slot = "Legs",        itemID = 240133 },
        { slot = "Boots",       itemID = 243953 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "",
    gems = {
        { label = "Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240906 },
        { label = "Peridot", itemID = 240892 },
        { label = "Amythyst", itemID = 240898 },
    },
    gemGuide = "Peridot: Flawless Masterful Peridot\nAmythyst: Flawless Deadly Amethyst\nGarnet: Flawless Quick Garnet\nDiamond: Indecipherable Eversong Diamond",
    consumables = {
        { label = "Flask", itemID = 241322 },
        { label = "Combat Potion", itemID = 241288 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 242273 },
    },
    consumableGuide = "The best Flask for Shadow Priests is Flask of the Blood Knights, though other stat flasks can still be used depending on your overall stat weighting.\n\nThere are a couple of different potions that have different useful scenarios for Shadow Priests:\n\nRaiding: Potion of Recklessness\nMythic+: Potion of Recklessness\n\nThe best healing potion for Shadow Priests is Concentrated Silvermoon Health Potion.\n\nFor their weapons, Shadow Priests will always use Thalassian Phoenix Oil.\n\nThe new Augment Rune is Void-Touched Augment Rune.\n\nShadow Priests are most likely using a feast buff over personal stat food due to stat allocation, but personal food is more than fine to use if feasts are not available.\n\nFeast: Blooming Feast\nPersonal Food: Royal Roast",
}

ns.ConsumablesDB["ROGUE_ASSASSINATION"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Head",        itemID = 243951 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Shoulders",   itemID = 244021 },
        { slot = "Legs",        itemID = 244641 },
        { slot = "Boots",       itemID = 243983 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "You'll want to use Enchant Weapon - Berserker's Rage generally, as Haste is one of our most important secondary stats. Other secondary stat enchants, such as crit, can be better in some situations, depending on your gear. Make sure to sim yourself using RaidBots to optimize this.",
    gems = {
        { label = "Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240892 },
        { label = "Gem", itemID = 240906 },
    },
    gemGuide = "You'll want to use Indecipherable Eversong Diamond as your Diamond, and then stack Flawless Quick Garnet gems. The additional damage from the crit diamond is generally not worth it.\n\nFor the remaining gem slots, always prioritize Critical Strike, Haste, and Mastery when possible. Depending on your Gear, you might have to make swaps to gems that are Haste focused or Mastery focused, instead of the recommended Flawless Quick Garnet gems. This is simply a part of the min-maxing during gearing and can occur when you have too much of a certain stat. Make sure to sim yourself using RaidBots to optimize this.",
    consumables = {
        { label = "Both Weapons", itemID = 243973 },
        { label = "Flask", itemID = 241324 },
        { label = "Combat Potion", itemID = 241308 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255845 },
    },
    consumableGuide = "The best Flask for Assassination Rogue is Flask of the Blood Knights, as it gives Haste, which is one of our best stats.\n\nThe best combat potion for Assassination Rogue is Light's Potential.\n\nThe best healing potion for Assassination Rogue is Concentrated Silvermoon Health Potion.\n\nThalassian Phoenix Oil will be the best weapon buff for Assassination Rogue, as it gives us our main secondary stats. Make sure to apply it to both daggers.\n\nWith Midnight, the new Augment Rune is Void-Touched Augment Rune.\n\nAssassination Rogue wants to eat feast buffs such as Silvermoon Parade for the Agility. Secondary stat food is competitive, but you will want to ensure you're getting Critical Strike and Haste.",
}

ns.ConsumablesDB["ROGUE_OUTLAW"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 243971 },
        { slot = "Shoulders",   itemID = 244021 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 244641 },
        { slot = "Boots",       itemID = 243983 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "As mentioned above, Haste can be a tricky thing to optimize perfectly for this spec which means that Enchant Weapon - Jan'alai's Precision or Enchant Weapon - Acuity of the Ren'dorei could swap value after even just a few gear upgrades. Always double check by simming with Raidbots to figure out optimal damage.",
    gems = {
        { label = "Thalassian Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240890 },
        { label = "Gem", itemID = 240967 },
        { label = "Gem", itemID = 240910 },
        { label = "Onyx", itemID = 240898 },
        { label = "Garnet", itemID = 240906 },
        { label = "Lapi", itemID = 240916 },
    },
    gemGuide = "For maximum damage, you will want to use Powerful Eversong Diamond as your Thalassian Diamond, and a combination of at least 1 Peridot, 1 Lapis, 1 Garnet, and 1 Amethyst, then probably Flawless Versatile Garnet in all other sockets.\n\nPeridot: Flawless Deadly Peridot\nOnyx: Flawless Deadly Amethyst\nGarnet: Flawless Quick Garnet\nLapis: Flawless Quick Lapis\n\nAs always, sim yourself as Haste can be a fickle thing to optimize perfectly.",
    consumables = {
        { label = "Helmet", itemID = 243951 },
        { label = "Flask", itemID = 241326, alt = { itemID = 241324 } },
        { label = "Combat Potion", itemID = 241309 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255846 },
    },
    consumableGuide = "The best Flask for Outlaw Rogue is Flask of the Shattered Sun or Flask of the Blood Knights and will depend entirely on if you need the haste from Flask of the Blood Knights to reach the important 21-23% breakpoint. If you don't need it then go for Flask of the Shattered Sun.\n\nThe best combat potion for Outlaw Rogue is Light's Potential.\n\nThe best healing potion for Outlaw Rogue is Concentrated Silvermoon Health Potion.\n\nThe best weapon buff for Outlaw Rogue is Thalassian Phoenix Oil.\n\nFor midnight, the new Augment Rune is Void-Touched Augment Rune.\n\nOutlaw Rogue is most likely using feast buffs in TWW due to how valuable Agility is for the class. As always, sim your character to see which food is best for your secondary stat configuration.\n\nFeast: Harandar Celebration\nPersonal Food: Hearty Royal Roast",
}

ns.ConsumablesDB["ROGUE_SUBTLETY"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Head",        itemID = 244007 },
        { slot = "Shoulders",   itemID = 243991 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 244641 },
        { slot = "Boots",       itemID = 243953 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "Higher gear levels in season two make secondary stat enchants the usually best option, this means we move away from Enchant Weapon - Acuity of the Ren'dorei.\nSingle Stat enchants (Enchant Weapon - Arcane Mastery, Enchant Weapon - Berserker's Rage, Enchant Weapon - Worldsoul Tenacity or Enchant Weapon - Jan'alai's Precision), will be used instead on both weapons. Mastery is typically the best of the secondary stat enchants early on, while others compete when we get closer to best in slot gear levels.\n\nMain Hand: Enchant Weapon - Arcane Mastery\nOff Hand: Enchant Weapon - Arcane Mastery",
    gems = {
        { label = "Eversong Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240900 },
        { label = "Amethyst", itemID = 240898 },
        { label = "Peridot", itemID = 240892 },
        { label = "Garnet", itemID = 240908 },
    },
    gemGuide = "For maximum damage, you will want to use Indecipherable Eversong Diamond as your Eversong Diamond. The remaining slots are filled with either of the ones listed below:\n\nAmethyst: Flawless Quick Amethyst / Flawless Deadly Amethyst\nPeridot: Flawless Masterful Peridot\nGarnet: Flawless Masterful Garnet\n\nWhich ones you use does not matter. The gem selection can differ depending on your stats, so always use a simulation if you want the optimal result.",
    consumables = {
        { label = "Weapon - Main Hand", itemID = 244031 },
        { label = "Weapon - Off Hand", itemID = 244031 },
        { label = "Flask", itemID = 241322, alt = { itemID = 241326 } },
        { label = "Combat Potion", itemID = 241308 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 275267 },
    },
    consumableGuide = "The best Flask for Subtlety Rogues is between Flask of the Shattered Sun and Flask of the Magisters. Which one is better will usually depend on your gear, and its best to use a simulation to compare. Flask of the Magisters is likely the better option.\n\nIf you are below the haste breakpoints (700 - 800 haste / 1100 haste), its advised to use Fleeting Flask of the Blood Knights instead.\n\nWhile there are many options for potions, Subtlety Rogues will use Light's Potential.\nFor Mychi+ Dungeons, use Potion of Recklessness if you get Mastery.\n\nThe technically best potion is Draught of Rampant Abandon, but its tricky to use. The void pools spawned by this poison silence you, which means you need to actively run out of them to use abilities. There is a short grace period before the silence effect applies. Using the potion, it seemed to proc roughly 3, often 4 times during the duration. Attacking a dummy was possible for the entire time, but it did need some practice and good positioning. The use of the potion is only recommended for encounters with big hitboxes, some amount of boss movement, or with a low amount of mechanical overhead to allow you to focus on avoiding the zones.\n\nThe best healing potion for Subtlety Rogues is Concentrated Silvermoon Health Potion.\n\nFor their weapons, Subtlety Rogues, the best option is listed below:\n\nMain Hand: Thalassian Phoenix Oil\nOff Hand: Thalassian Phoenix Oil\n\nNote: Adamantite Sharpening Stone technically perform slightly better as buff for your main hand weapon. It is likely unintentional for this item to still function on current gear, so could stop working with any hotfix. This option is only relevant at the start of the season before your first craft due to the Item Level restriction.\n\nWith Midnight, the new Augment Rune is Void-Touched Augment Rune.\n\nIn Midnight, Subtlety Rogues are most likely using personal stat food instead of feast buffs because the large item level jump has reduced the value of Agility relative to Secondary stats. As always, sim your character to check which food is the best for your configuration of Secondary stats.\n\nFeast: Hearty Amani Cornucopia\nPersonal Food: Royal Roast",
}

ns.ConsumablesDB["SHAMAN_ELEMENTAL"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 243973 },
        { slot = "Head",        itemID = 244007 },
        { slot = "Shoulders",   itemID = 243991 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 240133 },
        { slot = "Boots",       itemID = 243953 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "Enchant Weapon - Jan'alai's Precision or Enchant Weapon - Berserker's Rage are the most effective weapon enchant for Elemental Shaman in maxed out gear, more specfically when you get past roughly 1100 Mastery on your gear. Enchant Weapon - Arcane Mastery is better while you are still gearing up and lack Mastery from your Gear and other sources, but the lack of consistency on the proc works against us trying to stay as close to capped as possible for as long as possible. As usual, we recommend simming your character to get data tailored to your specific gear and character.",
    gems = {
        { label = "Thalassian Diamond", itemID = 240967 },
        { label = "Other Gems", itemID = 240908 },
        { label = "Gem", itemID = 240898 },
        { label = "Peridot", itemID = 240892 },
        { label = "Lapi", itemID = 240918 },
    },
    gemGuide = "For maximum damage, you will want to use Powerful Eversong Diamond as your Thalassian Diamond, and a combination of at least 1 Garnet, 1 Amethyst, 1 Peridot, and 1 Lapis, then Flawless Masterful Garnet or Flawless Deadly Amethyst in all other sockets.\n\nGarnet: Flawless Masterful Garnet\nPeridot: Flawless Masterful Peridot\nAmethyst: Flawless Deadly Amethyst\nLapis: Flawless Masterful Lapis",
    consumables = {
        { label = "Flask", itemID = 241322, alt = { itemID = 241326 } },
        { label = "Combat Potion", itemID = 241308 },
        { label = "Health Potion", itemID = 271883 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255846 },
    },
    consumableGuide = "The best Flask for Elemental Shamans is Flask of the Magisters. Mastery is our best stat so getting more of it is good. If you are capped out on mastery from your gear, Critical Strike or Haste flasks might be pulling ahead.\n\nYou should always use Light's Potential, which gives a plain main stat boost, which is especially good at the start of the expansion.\n\nThe best healing potion for Elemental Shamans is Concentrated Silvermoon Health Potion.\n\nIf you are talented into Flametongue Weapon, do not use any weapon oils, but instead use Flametongue Weapon to imbue your weapon. Otherwise you use Thalassian Phoenix Oil.\n\nThe Augment rune in Midnight is Void-Touched Augment Rune giving a minor main stat bonus which is lost on death.\n\nIn Midnight, Elemental Shamans will use Harandar Celebration as their feast of choice, giving some main stat which is especially good at the start of the expansion.",
}

ns.ConsumablesDB["SHAMAN_ENHANCEMENT"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244031 },
        { slot = "Off Hand",    itemID = 243973 },
        { slot = "Head",        itemID = 244007 },
        { slot = "Shoulders",   itemID = 243991 },
        { slot = "Bracers",     itemID = 275707 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Legs",        itemID = 244641 },
        { slot = "Boots",       itemID = 243953 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "In Midnight Season 2, with the rising value of secondary stats we've made the shift over, using Enchant Weapon - Arcane Mastery paired with Enchant Weapon - Berserker's Rage.",
    gems = {
        { label = "Eversong Diamo", itemID = 240967 },
        { label = "Other Gem", itemID = 240900 },
        { label = "Other Gem", itemID = 240892 },
        { label = "Other Gem", itemID = 240908 },
        { label = "Other Gem", itemID = 240918 },
        { label = "Eversong Diamo", itemID = 240983 },
    },
    gemGuide = "It's generally best to sim your character to find the absolute best gems to put in gear. Everyone has access to a minimum of 3, as each piece of jewellery always comes with one socket each. In Midnight, Agility is valued so highly that you should always be using an Eversong Diamond in your first socket. After that, you should mix gems based on gear needs:\n\nWith 5+ Sockets\nEversong Diamond &ndash; Powerful Eversong Diamond.\nOther Gems &ndash; one each of Flawless Quick Amethyst, Flawless Masterful Peridot, Flawless Masterful Garnet & Flawless Masterful Lapis\nWithout 5+ Sockets\nEversong Diamond &ndash; Indecipherable Eversong Diamond.\nOther Gems &ndash; a mix of Flawless Quick Amethyst & Flawless Masterful Peridot",
    consumables = {
        { label = "Belt", itemID = 275707 },
        { label = "Flask", itemID = 241324 },
        { label = "Combat Potion", itemID = 241288 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255845, alt = { itemID = 242275 } },
    },
    consumableGuide = "In Midnight Season 2, due to the limited amount of Haste available, the best general flask to use is Flask of the Blood Knights to help keep your stats in order. Depending on your current gear setup, Flask of the Magisters is also an option when lacking Mastery. You can also obtain these from a Cauldron of Sin'dorei Flasks if your group is using one.\n\nGoing into Season 2 of Midnight, due to a number of gear system changes we've switched over to Potion of Recklessness. We want this to trigger Mastery, so it may require some gear shifting to consistently do so. If you can't consistently trigger this stat, then Light's Potential\nis almost the same in value. These can also be obtained from an Voidlight Potion Cauldron if your group is using one.\n\nThe best healing potion for Enhancement Shaman is the new Concentrated Silvermoon Health Potion added in Patch 12.1.\n\nUnfortunately, due to the Weapon Imbues (Flametongue Weapon and Windfury Weapon) that Enhancement uses, it CANNOT use weapon enhancements such as oils or whetstones at the same time. Due to the way that Elemental Weapons works, opting out of these is not an option, so we do not use runes.\n\nThe Augment Rune available in Midnight is Void-Touched Augment Rune. These can be acquired from the weekly housing quest, but bear in mind they're lost on death and are very expensive!\n\nIn Midnight Season 2 Agility continues to be the most valuable stat, and while secondary stat foods give slightly more, it doesn't do enough to push it off the menu.\n\nFeast: Silvermoon Parade\nPersonal Food: Royal Roast",
}

ns.ConsumablesDB["SHAMAN_RESTORATION"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244029 },
        { slot = "Head",        itemID = 243951 },
        { slot = "Shoulders",   itemID = 244021 },
        { slot = "Chest",       itemID = 244003 },
        { slot = "Legs",        itemID = 240155 },
        { slot = "Boots",       itemID = 243983 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "Enchant Weapon - Acuity of the Ren'dorei is your best weapon enchant for all content. The absorption effect from Enchant Weapon - Worldsoul Cradle is not strong enough to compete and intellect is more valuable than secondary stats early on in the expansion.",
    gems = {
        { label = "Dazzling Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240909 },
        { label = "Gem", itemID = 244003 },
        { label = "Gem", itemID = 240155 },
        { label = "Gem", itemID = 240968 },
        { label = "Peridot", itemID = 240889 },
        { label = "Lapi", itemID = 240913 },
        { label = "Amethyst", itemID = 240897 },
    },
    gemGuide = "Due to how Resurgence works based on your maximum mana, effects that increase your mana and multiply each other like Primordial Capacity, Enchant Chest - Mark of the Magister, Arcanoweave Spellthread, and Telluric Eversong Diamond gain value. In any scenario where mana is a consideration you would run Telluric Eversong Diamond. If you are not having any issues with mana you can instead run Indecipherable Eversong Diamond.\n\nFor the rest of the sockets the Telluric diamond requires you to wear one of each color, while the Indecipherable diamond doesn't care and lets you simply run multiple Flawless Versatile Garnet.\n\nGarnet: Flawless Versatile Garnet\nPeridot: Flawless Deadly Peridot\nLapis: Flawless Deadly Lapis\nAmethyst: Flawless Deadly Amethyst",
    consumables = {
        { label = "Flask", itemID = 241326 },
        { label = "Combat Potion", itemID = 241300, alt = { itemID = 241288 } },
        { label = "Health Potion", itemID = 271883 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255845, alt = { itemID = 242275 } },
    },
    consumableGuide = "Flask of the Shattered Sun is your best option for a flask.\n\nIf your highest secondary stat is Critical Strike, then your best potion to use will always be Potion of Recklessness. The effect not only increases your healing output by a very high amount, but due to Resurgence you also gain a substantial amount of mana from this increase. While the mana by itself is not as much as what Lightfused Mana Potion gives, the combination of mana and more healing end up being better by a decent margin.\n\nThe best way to use this potion during raids is to pair with Ascendance. The effect of Ascendance makes Chain Heal heal more targets which translates into more Resurgence procs, and the reduced mana cost means you can cast it a lot without mana issues. This combination results in doing an incredibly high amount of raid healing for very little mana cost, saving you more mana in the long run than what a normal mana potion would.\n\nThe best healing potion for Restoration Shamans is Silvermoon Health Potion.\n\nRestoration Shamans have their own weapon buff in the form of Earthliving Weapon and you should always use it. You can't combine Earthliving with other temporary weapon buffs like oils and Earthliving is considerably stronger than them.\n\nThe new Augment Rune for Midnight is Void-Touched Augment Rune.\n\nMost of the time you will use feasts. If you don't have access to them or prefer a cheaper option you can go for personal food instead.\n\nFeast: Silvermoon Parade\nPersonal Food: Royal Roast",
}

ns.ConsumablesDB["WARLOCK_AFFLICTION"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 243971 },
        { slot = "Head",        itemID = 244007 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Shoulders",   itemID = 243961 },
        { slot = "Legs",        itemID = 240133 },
        { slot = "Boots",       itemID = 243953 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "",
    gems = {
        { label = "Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240906 },
        { label = "Peridot", itemID = 240892 },
        { label = "Amythyst", itemID = 240898 },
    },
    gemGuide = "Peridot: Flawless Masterful Peridot\nAmythyst: Flawless Deadly Amethyst\nGarnet: Flawless Quick Garnet\nDiamond: Indecipherable Eversong Diamond",
    consumables = {
        { label = "Flask", itemID = 241324 },
        { label = "Combat Potion", itemID = 241308 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255846, alt = { itemID = 242275 } },
    },
    consumableGuide = "The best Flask for Affliction Warlocks is Flask of the Magisters, though other stat flasks can still be used depending on your overall stat weighting.\n\nThere are a couple of different potions that have different useful scenarios for Affliction Warlocks:\n\nRaiding: Light's Potential\nMythic+: Light's Potential\n\nThe best healing potion for Affliction Warlocks is Concentrated Silvermoon Health Potion.\n\nFor their weapons, Affliction Warlocks will always use Thalassian Phoenix Oil.\n\nThe new Augment Rune is Void-Touched Augment Rune.\n\nAffliction Warlocks are most likely using a feast buff over personal stat food due to stat allocation, but personal food is more than fine to use if feasts are not available.\n\nFeast: Harandar Celebration\nPersonal Food: Royal Roast",
}

ns.ConsumablesDB["WARLOCK_DEMONOLOGY"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 243971 },
        { slot = "Head",        itemID = 244007 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Shoulders",   itemID = 243961 },
        { slot = "Legs",        itemID = 240133 },
        { slot = "Boots",       itemID = 243953 },
        { slot = "Ring",        itemID = 244015 },
    },
    enchantGuide = "",
    gems = {
        { label = "Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240906 },
        { label = "Peridot", itemID = 240892 },
        { label = "Amythyst", itemID = 240898 },
    },
    gemGuide = "Peridot: Flawless Masterful Peridot\nAmythyst: Flawless Deadly Amethyst\nGarnet: Flawless Quick Garnet\nDiamond: Indecipherable Eversong Diamond",
    consumables = {
        { label = "Flask", itemID = 241326 },
        { label = "Combat Potion", itemID = 241308 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 242275 },
    },
    consumableGuide = "The best Flask for Demonology Warlocks is Flask of the Shattered Sun, though other stat flasks can still be used depending on your overall stat weighting.\n\nThere are a couple of different potions that have different useful scenarios for Demonology Warlocks:\n\nRaiding: Light's Potential\nMythic+: Light's Potential\n\nThe best healing potion for Demonology Warlocks is Concentrated Silvermoon Health Potion.\n\nFor their weapons, Demonology Warlocks will always use Thalassian Phoenix Oil.\n\nThe new Augment Rune is Void-Touched Augment Rune.\n\nDemonology Warlocks are most likely using personal stat food over feast buffs as we value the baseline Intellect more than secondaries. As always, sim your character to check which food is the best for your configuration of secondary stats.\n\nFeast: Silvermoon Parade\nPersonal Food: Royal Roast",
}

ns.ConsumablesDB["WARLOCK_DESTRUCTION"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 244029 },
        { slot = "Head",        itemID = 244007 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Shoulders",   itemID = 243991 },
        { slot = "Legs",        itemID = 240133 },
        { slot = "Boots",       itemID = 243953 },
        { slot = "Ring",        itemID = 243957 },
    },
    enchantGuide = "",
    gems = {
        { label = "Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240906 },
        { label = "Peridot", itemID = 240892 },
        { label = "Amythyst", itemID = 240898 },
    },
    gemGuide = "Peridot: Flawless Masterful Peridot\nAmythyst: Flawless Deadly Amethyst\nGarnet: Flawless Quick Garnet\nDiamond: Indecipherable Eversong Diamond\n\nKeep in mind, the stats on your gems and ring enchants will vary depending on the gear you have. You should always sim your character to figure out what gives you the biggest gain.",
    consumables = {
        { label = "Flask", itemID = 241326 },
        { label = "Combat Potion", itemID = 241308 },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255846, alt = { itemID = 242275 } },
    },
    consumableGuide = "The best Flask for Destruction Warlocks is Flask of the Shattered Sun, though other stat flasks can still be used depending on your overall stat weighting. You can also sim these to figure out which one is best for your character specifically.\n\nThere are a couple of different potions that have different useful scenarios for Destruction Warlocks:\n\nRaiding: Light's Potential\nMythic+: Light's Potential\n\nThe best healing potion for Destruction Warlocks is Concentrated Silvermoon Health Potion.\n\nFor their weapons, Destruction Warlocks will always use Thalassian Phoenix Oil.\n\nThe new Augment Rune is Void-Touched Augment Rune.\n\nDestruction Warlocks are most likely using a feast buff over personal stat food due to stat allocation, but personal food is more than fine to use if feasts are not available.\n\nFeast: Harandar Celebration\nPersonal Food: Royal Roast",
}

ns.ConsumablesDB["WARRIOR_ARMS"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 243973, alt = 244029 },
        { slot = "Head",        itemID = 243951, alt = 244007 },
        { slot = "Shoulders",   itemID = 243991, alt = 244019 },
        { slot = "Chest",       itemID = 243977, alt = 243947 },
        { slot = "Legs",        itemID = 244643, alt = 244641 },
        { slot = "Boots",       itemID = 243953, alt = 243983 },
        { slot = "Ring",        itemID = 243957, alt = 244015 },
    },
    enchantGuide = "",
    gems = {
        { label = "Diamond", itemID = 240967, alt = 240983 },
        { label = "Other Gems", itemID = 240906, alt = 240890 },
        { label = "Gem", itemID = 240983 },
    },
    gemGuide = "The Powerful Eversong Diamond is just barely starting to become stronger than Indecipherable Eversong Diamond, though versatility gems are not worth using to maximize the bonus.",
    consumables = {
        { label = "Flask", itemID = 241324, alt = { itemID = 241326 } },
        { label = "Combat Potion", itemID = 241288, alt = { itemID = 241308 } },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 242273, alt = { itemID = 242274 } },
    },
    consumableGuide = "The best flask for Arms Warriors is Flask of the Shattered Sun or Flask of the Blood Knights.\n\nLight's Potential is recommended due to its ease of use, as Potion of Recklessness requires carefully balancing secondary stats to ensure that Critical Strike is always highest and Versatility is minimized, despite being very slightly stronger when not using Vantus Runes. Draught of Rampant Abandon also looks powerful, but the frequent need to move to avoid being silenced makes it weaker in practice.\n\nConcentrated Silvermoon Health Potion is the best healing potion in Midnight Season 2.\n\nArms Warriors should apply Thalassian Phoenix Oil to their weapon.\n\nVoid-Touched Augment Rune is the only new Augment Rune in Midnight Season 2.\n\nAny feast, with Blooming Feast, Champion's Bento, and Flora Frenzy all providing the maximum benefit.",
}

ns.ConsumablesDB["WARRIOR_FURY"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 243973, alt = 244031 },
        { slot = "Head",        itemID = 243951, alt = 244007 },
        { slot = "Shoulders",   itemID = 243991, alt = 244019 },
        { slot = "Chest",       itemID = 243977, alt = 243947 },
        { slot = "Legs",        itemID = 244643, alt = 244641 },
        { slot = "Boots",       itemID = 243953, alt = 243983 },
        { slot = "Ring",        itemID = 243959, alt = 244015 },
    },
    enchantGuide = "",
    gems = {
        { label = "Diamond", itemID = 240967, alt = 240983 },
        { label = "Other Gems", itemID = 240900, alt = 240892 },
        { label = "Gem", itemID = 240983 },
    },
    gemGuide = "The Powerful Eversong Diamond is just barely starting to become stronger than Indecipherable Eversong Diamond, though versatility gems are not worth using to maximize the bonus.",
    consumables = {
        { label = "Flask", itemID = 241324, alt = { itemID = 241322 } },
        { label = "Combat Potion", itemID = 241288, alt = { itemID = 241308 } },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 242273, alt = { itemID = 242274 } },
    },
    consumableGuide = "The best flask for Fury Warriors is Flask of the Magisters or Flask of the Blood Knights.\n\nLight's Potential is recommended due to its ease of use, as Potion of Recklessness requires carefully balancing secondary stats to ensure that Mastery is always highest and Versatility is minimized, despite being very slightly stronger when not using Vantus Runes. Draught of Rampant Abandon also looks powerful, but the frequent need to move to avoid being silenced makes it weaker in practice.\n\nConcentrated Silvermoon Health Potion is the best healing potion in Midnight Season 2.\n\nFury Warriors should apply Thalassian Phoenix Oil to both of their weapons.\n\nVoid-Touched Augment Rune is the only new Augment Rune in Midnight Season 2.\n\nAny feast, with Blooming Feast, Champion's Bento, and Flora Frenzy all providing the maximum benefit.",
}

ns.ConsumablesDB["WARRIOR_PROTECTION"] = {
    season = "Midnight Season 2",
    enchants = {
        { slot = "Weapon",      itemID = 243973 },
        { slot = "Shoulders",   itemID = 243963 },
        { slot = "Chest",       itemID = 243977 },
        { slot = "Head",        itemID = 243981 },
        { slot = "Legs",        itemID = 244641 },
        { slot = "Boots",       itemID = 244009 },
        { slot = "Ring",        itemID = 244015 },
    },
    enchantGuide = "Enchant Weapon - Berserker's Rage is going to be the most effective weapon enchant overall.",
    gems = {
        { label = "Algari Diamond", itemID = 240983 },
        { label = "Other Gems", itemID = 240894 },
    },
    gemGuide = "Protection Warrior opts to gem Flawless Versatile Peridot in all sockets.",
    consumables = {
        { label = "Flask", itemID = 241324 },
        { label = "Combat Potion", itemID = 241292, alt = { itemID = 241308 } },
        { label = "Health Potion", itemID = 271884 },
        { label = "Weapon Buff", itemID = 243734 },
        { label = "Augment Rune", itemID = 259085 },
        { label = "Food", itemID = 255845, alt = { itemID = 255846 } },
    },
    consumableGuide = "The best Flask for Protection Warriors is Flask of the Blood Knights.\n\nThe best stat boosting potions for Prot Warriors are Draught of Rampant Abandon or Light's Potential.\n\nThe best healing potion for Protection Warriors is Concentrated Silvermoon Health Potion.\n\nFor their weapons, Protection Warriors will always use Thalassian Phoenix Oil.\n\nIn Midnight, the new Augment Rune is Void-Touched Augment Rune.\n\nIn Midnight, Protection Warrior eats the feast (Silvermoon Parade) for buffs because primary stat is always the highest increase for us.",
}

