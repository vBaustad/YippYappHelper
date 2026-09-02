local _, ns = ...

------------------------------------------------------------
-- Trinket tier list per class/spec, from Wowhead's class guides.
--
-- GENERATED FILE - do not hand-edit.
-- Regenerate with:  python Tools/scrape_trinket_tiers.py
--
-- This is the editorial answer, not the simulated one. It knows
-- what a sim cannot: that a trinket wants pairing with a specific
-- cooldown, that another only drops from the Great Vault, that two
-- that both sim well are never worn together. Read alongside
-- TrinketData.lua rather than instead of it -- and note this is
-- the only trinket data Augmentation Evoker has at all, since
-- bloodmallet does not sim it and QE Live covers only healers.
--
-- `rank` is 1 for the top tier downward. Sort on that, not on the
-- label: the forty specs use six different ladders between them
-- (S-D mostly, but also S+ and A+ at the top and F and G below D),
-- and the labels are the authors' own wording, kept verbatim.
--
-- `from` is the content the trinket drops from, worded as the
-- guide words it. `note` is the author's hover note, present on
-- the trinkets they chose to annotate and nil on the rest.
--
-- Item names are NOT stored. They resolve from the ID at runtime,
-- which localises for free and survives a rename.
------------------------------------------------------------

ns.TrinketTiers = {}
ns.TRINKET_TIER_SOURCE = "Wowhead class guides"
ns.TRINKET_TIER_TARGET_SEASON = "Midnight Season 2"
ns.TRINKET_TIER_SCRAPED_AT = "2026-09-02"

ns.TrinketTiers["DEATHKNIGHT_BLOOD"] = {
    season = "Midnight Season 2",
    intro = "Trinkets this tier are very monotonous: if it does not come from the Venomous Abyss, you pretty much will only use it as a short-term stopover. We've ranked them below.\n\nIn practice, you will want one active on-use on 1:30 cooldown (if San'layn; Deathbringer also likes 2min CDs due to playing Reaper's Onslaught while Echoing Fury is bugged), and a passive proc trinket.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270173, from = "Raid", note = "Primarily a ST choice until you get the weapon, at which point it also functions amazingly in all content types" },
            { id = 270175, from = "Raid", note = "Syncs perfectly with DRW as San'layn and Mark as Deathbringer" },
        } },
        { label = "A", rank = 2, items = {
            { id = 270165, from = "Raid", note = "Another pretty good passive trinket." },
            { id = 273796, from = "Mythic Plus", note = "Send on CD as Deathbringer, send on CD but hold for the last DRW as SL" },
            { id = 250238, from = "Mythic Plus" },
            { id = 250259, from = "Mythic Plus" },
            { id = 193762, from = "Mythic Plus", note = "Send on CD as Deathbringer, send on CD but hold for the last DRW as SL" },
            { id = 273797, from = "Mythic Plus", note = "Send on CD with DRW. Bonus value in M+ if you kill something under it." },
            { id = 270164, from = "Raid", note = "A lot of its effects are positively overtuned to account for the negative self-dealing effects, which are irrelevant on a tank." },
            { id = 274493, from = "Delves" },
            { id = 158367, from = "Mythic Plus", note = "You can walk while channelling this thanks to Death's Advance. Drop a D&D below the pack and spew at them from a distance." },
        } },
        { label = "B", rank = 3, items = {
            { id = 250245, from = "Mythic Plus" },
            { id = 270168, from = "Raid", note = "Not great, honestly. Careful while using it." },
            { id = 270163, from = "Raid" },
            { id = 251783, from = "Delves" },
            { id = 250228, from = "Mythic Plus" },
        } },
        { label = "C", rank = 4, items = {
            { id = 273795, from = "Mythic Plus" },
            { id = 250229, from = "Mythic Plus" },
        } },
        { label = "D", rank = 5, items = {
            { id = 250244, from = "Mythic Plus" },
        } },
    },
}

ns.TrinketTiers["DEATHKNIGHT_FROST"] = {
    season = "Midnight Season 2",
    intro = "Raid trinkets are noticeably strong this season. In general, Frost is looking for one passive stat trinket and one on-use trinket. There are a few trinkets that defy the usual expectations, so make sure you are checking sims for your character. If a trinket is not included here, it is too weak to be seriously considered.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270173, from = "Raid" },
            { id = 270164, from = "Raid" },
            { id = 270175, from = "Raid" },
        } },
        { label = "A", rank = 2, items = {
            { id = 273797, from = "Mythic Plus" },
            { id = 250259, from = "Mythic Plus" },
            { id = 250238, from = "Mythic Plus" },
        } },
        { label = "B", rank = 3, items = {
            { id = 270165, from = "Raid" },
            { id = 273796, from = "Mythic Plus" },
        } },
        { label = "C", rank = 4, items = {
            { id = 270168, from = "Raid" },
            { id = 250228, from = "Mythic Plus" },
            { id = 193762, from = "Mythic Plus" },
        } },
        { label = "D", rank = 5, items = {
            { id = 250229, from = "Mythic Plus" },
            { id = 193757, from = "Mythic Plus" },
            { id = 158367, from = "Mythic Plus" },
            { id = 273795, from = "Mythic Plus" },
            { id = 270163, from = "Raid" },
        } },
    },
}

ns.TrinketTiers["DEATHKNIGHT_UNHOLY"] = {
    season = "Midnight Season 2",
    intro = "Unholy Death Knights trinket preferences in Midnight Season 2 are fairly simple. If it gives Crit, Mastery or Strength, it is quite good. Being a burst specialization, Unholy tends to want an on use trinket, paired with a passive proc trinket. This combo of trinket types works incredibly well to enhance Unholy's burst windows, while making sure that sustained damage doesn't take too much of a hit for it.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270175, from = "Raid", note = "Heart of Ula'tek is far and away Unholy's best trinket. It is a great 1.5 minute on use, syncronizing with our cooldowns and enhancing our already strong burst damage windows." },
            { id = 270173, from = "Raid", note = "Zul'jin's Guillotine Technique is an incredibly potent trinket for 1-2 target scenarios, and compliments Heart of Ula'tek to complete our BiS trinket pair. The major downside to this trinket is it is only good at these low target counts. in AoE, its easily surpassed by stat trinkets, making it the lowest priority of all the incredible items from this raid." },
        } },
        { label = "A", rank = 2, items = {
            { id = 270164, from = "Raid", note = "Gebbo's Bottomless Bag is a solid alternative to Zul'jin's Guillotine Technique that instead provides stats instead of damage. This trinket tends to actually work better htan Zul'jin's in Mythic+, Delves, and open world content due to Zul'jin's not scaling very well into AoE." },
            { id = 250228, from = "Mythic Plus", note = "Bellowstone is another great alternative to Zul'jin's, for similar reasons to Gebbos, may even be preferred in M+, Delves and other world content." },
            { id = 273797, from = "Mythic Plus", note = "The closest alternative trinket we have to Heart of Ula'tek from Mythic+. This trinket can take its palce for Mythic+ Dungeons, World Content, Delves, etc. Basically any scenario where you will be frequently killing enemies. Due to this requirement to get the full power from this trinket though, it tends to fall behind in Raid content." },
            { id = 245829, from = "Crafting", note = "Darkmoon Deck: Hunt is easily the most potent Darkmoon Deck and crafted trinket in general in Season 1 of Midnight. Though this doesn't quite compete with the trinkets higher on this list, it can be a solid craft for alts with more sparks than they know what to do with." },
        } },
        { label = "B", rank = 3, items = {
            { id = 251783, from = "Delves" },
            { id = 245855, from = "Crafting", note = "While this trinket is a passive stat proc trinket, it's a bit undertuned, will often give us our worst stat, and requires us to use our limited Sparks to craft it. While the allied player death effect on this does make it have some niche uses if you expect your party/raid to die a LOT, it's just not reliable. Due to these factors, I would never recommend crafting this trinket." },
            { id = 193757, from = "Mythic Plus" },
            { id = 250229, from = "Mythic Plus" },
            { id = 251792, from = "Delves" },
            { id = 274497, from = "Delves" },
        } },
        { label = "C", rank = 4, items = {
            { id = 245750, from = "Crafting", note = "While this trinket is a passive stat proc trinket, it's a bit undertuned, gives us our worst stat, and requires us to use our limited Sparks to craft it. Due to these factors, I would never recommend crafting this trinket." },
            { id = 251782, from = "Delves" },
            { id = 250238, from = "Mythic Plus" },
            { id = 270163, from = "Raid" },
            { id = 250462, from = "Raid" },
            { id = 274493, from = "Delves" },
            { id = 270168, from = "Raid" },
            { id = 274496, from = "Delves" },
            { id = 273796, from = "Mythic Plus" },
            { id = 193762, from = "Mythic Plus" },
            { id = 250259, from = "Mythic Plus" },
            { id = 250245, from = "Mythic Plus" },
            { id = 158367, from = "Mythic Plus" },
            { id = 280123, from = "Delves" },
        } },
        { label = "D", rank = 5, items = {
            { id = 251791, from = "Delves" },
            { id = 251787, from = "Delves" },
            { id = 241340, from = "Crafting", note = "While this trinket is a passive Strength proc trinket, its a bit undertuned, and requires us to use our limited Sparks to craft it. Due to these factors, I would never recommend crafting this trinket." },
            { id = 245846, from = "Crafting", note = "Another passive damage proc trinket, which Unholy doesn't favor at all, it's also undertuned, and requires us to use our limited Sparks to craft it. Due to these factors, I would never recommend crafting this trinket." },
        } },
    },
}

ns.TrinketTiers["DEMONHUNTER_DEVOURER"] = {
    season = "Midnight Season 2",
    intro = "Devourer Demon Hunter primarily looks to grab a powerful on-use cooldown to pair with Void Metamorphosis, which is where most of your damage occurs. To accompany this, we look to use a strong passive stat proc trinket. From trinkets, Devourer is looking to gain Intellect, Mastery, or Crit. Double on-use is not the worst for Devourer, as you enter your cooldowns fairly often, but should generally be avoided in favour of one on-use and one passive trinket.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 250215, from = "Mythic Plus", note = "There are not many on-use options available this tier, but flask is by far the strongest, providing a large amount of crit (a great stat for us) which synchs up roughly with every 2nd to 3rd usage of Void Metamorphosis." },
            { id = 270164, from = "Raid", note = "Following the nerfs, Gebbo's is not as powerful as it once was. While still a very strong trinket, and our best option in M+, it has fallen behind Wavecaller's Seastone for raid." },
            { id = 270167, from = "Raid", note = "This trinket is quite powerful, and after the buffs is our best option for Raid. Its quite close in m+, but is slightly behind Gebbos in that environment, and features a ramp up time." },
        } },
        { label = "A", rank = 2, items = {
            { id = 273796, from = "Mythic Plus", note = "While worse than Flask, this is our 2nd best option for an on-use this tier, should you not have flask yet." },
            { id = 270161, from = "Raid", note = "A very strong passive proc trinket, especially due to the high APM of Devourer. While worse than raid options, this is still a very strong passive option." },
            { id = 193757, from = "Mythic Plus", note = "This is a strong passive available from Mythic plus, should you never raid. Ideal usage of this trinket is to train it 4 times in the crit buff (target yourself when standing alone) and 2 times in the haste buff (target yourself when standing amongst a group of allies). For more information on How To Train Your Dragon, refer to the guide on WoWhead." },
            { id = 250224, from = "Mythic Plus", note = "This is another strong passive from dungeons, and does not require you to Train Your Dragon. However, it provides no stats baseline and can be inconsistent." },
            { id = 270169, from = "Raid", note = "Following the trinket tuning, this trinket is now quite reasonable. It allows you a flexible damage amp to utilize wherever you want, and thus can be powerful in certain situations, especially so if you are playing Annihilator. The downside of losing primary stat is very real however, and keeps this from being a blanket recommendation." },
        } },
        { label = "B", rank = 3, items = {
            { id = 251792, from = "Delves" },
            { id = 250259, from = "Mythic Plus" },
            { id = 273649, from = "Mythic Plus" },
            { id = 270170, from = "Raid" },
            { id = 270168, from = "Raid" },
        } },
        { label = "C", rank = 4, items = {
            { id = 251785, from = "Delves" },
            { id = 251783, from = "Delves" },
            { id = 273794, from = "Mythic Plus" },
            { id = 246304, from = "Crafting" },
            { id = 251786, from = "Delves" },
        } },
        { label = "D", rank = 5, items = {
            { id = 246305, from = "Crafting" },
            { id = 246306, from = "Crafting" },
            { id = 246307, from = "Crafting" },
            { id = 241340, from = "Crafting" },
            { id = 250214, from = "Mythic Plus", note = "While this trinket looks good on paper, and sims quite well, the trinket itself is nearly impossible to get full value out of by standing in it's beam. Additionally, the proc of the beam can cancel your Void Ray should it proc while channeling, making this trinket incredibly bad untill that is fixed. Stay away from this trinket untill then." },
            { id = 274493, from = "Delves" },
            { id = 251787, from = "Delves" },
            { id = 251784, from = "Delves" },
            { id = 274495, from = "Delves" },
            { id = 280123, from = "Delves" },
            { id = 274496, from = "Delves" },
            { id = 274497, from = "Delves" },
        } },
    },
}

ns.TrinketTiers["DEMONHUNTER_HAVOC"] = {
    season = "Midnight Season 2",
    intro = "Havoc Demon Hunter typically prefers 2 minute cooldown trinkets to align to meta, however there are zero strong trinkets like that this season and our best 1.5 minute trinket is better used on cooldown rather than holding. Zul'jin's Guillotine Technique due to the set bonus with Aman'muso, Warlord's Vengeance is INCREDIBLY strong and BiS for all content.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270173, from = "Raid", note = "When paired with Aman'muso, Warlord's Vengeance, Guillotine is our BiS trinket for all content putting out an incredible amount of damage and working on 2 targets." },
            { id = 270168, from = "Raid", note = "Font was previously not too strong of a trinket, however a Simulations and in-game tooltip bug had it missing 25% of its damage which has moved it up to S tier for Havoc." },
        } },
        { label = "A", rank = 2, items = {
            { id = 270175, from = "Raid", note = "Heart of Ula'tek is powerful used on CD in single target and held for Metamorphosis in AoE." },
        } },
        { label = "B", rank = 3, items = {
            { id = 270166, from = "Raid" },
            { id = 270165, from = "Raid" },
        } },
        { label = "C", rank = 4, items = {
            { id = 270164, from = "Raid", note = "Gebbo's was overnerfed for Havoc leaving many more valueable trinkets beating it out." },
            { id = 250225, from = "Mythic Plus" },
            { id = 250462, from = "Delves" },
            { id = 250214, from = "Mythic Plus" },
            { id = 159617, from = "Mythic Plus" },
            { id = 273796, from = "Mythic Plus" },
            { id = 158374, from = "Mythic Plus" },
            { id = 250228, from = "Mythic Plus" },
            { id = 246304, from = "Crafting" },
            { id = 193757, from = "Mythic Plus" },
        } },
        { label = "D", rank = 5, items = {
            { id = 250259, from = "Mythic Plus", note = "Sapling oversims as the lasher is NOT actually hasted in game but is in sims, and moves slow losing damage on movement. Avoid despite sims." },
            { id = 251785, from = "Delves" },
            { id = 274493, from = "Delves" },
            { id = 250215, from = "Mythic Plus" },
            { id = 246307, from = "Crafting" },
            { id = 246305, from = "Crafting" },
        } },
        { label = "F", rank = 6, items = {
            { id = 251783, from = "Delves" },
            { id = 273797, from = "Mythic Plus" },
            { id = 251784, from = "Delves" },
            { id = 274497, from = "Delves" },
            { id = 274496, from = "Delves" },
            { id = 241340, from = "Crafting" },
            { id = 246306, from = "Crafting" },
        } },
    },
}

ns.TrinketTiers["DEMONHUNTER_VENGEANCE"] = {
    season = "Midnight Season 2",
    intro = "Vengeance typically wants any trinkets that give outsized value over anything else. Depending on the situation, various trinkets may be preferred, whether it's stats in general, powerful procs, or on-use defensives. Unfortunately, this season that tends to mostly be specific stat trinkets. Additionally, most of the trinkets from Delves are quite lackluster, so they are not listed in the following chart.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270175, from = "Raid", note = "Strongest on-use trinket for stats and for overall damage." },
            { id = 270173, from = "Raid", note = "Strongest ST and 2T trinket for raw damage despite the tank penalty. Has extra item level. Pairs well with the cantrip weapon due to set bonus." },
        } },
        { label = "A", rank = 2, items = {
            { id = 270164, from = "Raid", note = "3 RPPM of 6 different procs (each secondary or all 4 secondaries or a penalty). ~60% uptime. Gives similar average stat to other stat trinkets, even with the random duds." },
            { id = 270165, from = "Raid", note = "6 RPPM haste proc (120% uptime), solid option with slightly more than average stats but less value due to DR" },
            { id = 270168, from = "Raid", note = "Insane damage, but still a trinket with a 4 minute cooldown and requires channeling, during which you cannot dodge or parry. Be very careful when using it." },
            { id = 250245, from = "Mythic Plus", note = "3 Hasted RPPM of a split damage and healing proc. Affected by tank penalty but surprisingly strong regardless." },
            { id = 250228, from = "Mythic Plus", note = "1 RPPM proc, gives more crit than average." },
        } },
        { label = "B", rank = 3, items = {
            { id = 159617, from = "Mythic Plus", note = "2 min on-use Vers. Gives less than average stat." },
            { id = 250225, from = "Mythic Plus", note = "2m CD granting Haste and stacking Crit. Grants lower than average stat." },
            { id = 250215, from = "Mythic Plus", note = "1.5m on-use. Gives only crit but is weaker than other options." },
            { id = 273796, from = "Mythic Plus", note = "2m on-use. Gives less average stat than other trinkets after accounting for penalty. Unfortunately since the stat is random, it's not reliable." },
            { id = 273797, from = "Mythic Plus", note = "1.5m on-use. Extends duration each time an enemy dies while active. Requires at least 2 extensions for it to match better trinkets, so it's not reliable. Weaker if you don't have enemies to kill quickly." },
            { id = 270166, from = "Raid", note = "15 Hasted RPPM damage proc. Has tank penalty. Deals decent damage but there are better options." },
            { id = 250462, from = "Delves", note = "Permanent secondary, solid option but limited by item level due to dropping from World only" },
            { id = 246304, from = "Crafting", note = "Decent crafted option if you have no better trinkets. The stats can vary." },
            { id = 250244, from = "Mythic Plus", note = "Incredibly strong trinket if you can maintain the stacks. However, if you consistently drop stacks it's not very good." },
            { id = 270174, from = "Raid", note = "2 RPPM avoiding attacks grants mainstat with occasional guaranteed proc that doesn't affect the proc rate. Decent in M+." },
        } },
        { label = "C", rank = 4, items = {
            { id = 270160, from = "Raid", note = "1.5m on-use shield. Weaker than stat trinkets." },
            { id = 250243, from = "Mythic Plus", note = "1.5m on-use partial shield. Another weak option even defensively." },
            { id = 193757, from = "Mythic Plus", note = "1.01 RPPM of specific procs - ST damage, AoE damage, Crit buff, ST heal, AoE Heal, or Haste. Not the best, but stats are the way to go." },
            { id = 158374, from = "Mythic Plus", note = "20 Hasted RPPM damage proc. Affected by tank penalty." },
            { id = 250214, from = "Mythic Plus", note = "Permanent Mastery + 1.25 RPPM Mastery proc. Grants more than average, but it's mastery." },
            { id = 250259, from = "Mythic Plus", note = "2 Hasted RPPM of a raw damage proc. Not very strong and has tank penalty." },
            { id = 246307, from = "Crafting", note = "3 RPPM Vers proc, pretty decent for crafted" },
            { id = 241340, from = "Crafting", note = "2.5 RPPM main stat proc, solid early choice for Alchemists" },
        } },
        { label = "D", rank = 5, items = {
            { id = 159618, from = "Mythic Plus", note = "1m on-use shield. Does not block much." },
            { id = 246305, from = "Crafting", note = "1.1 RPPM, but it grants our worst secondary" },
            { id = 246306, from = "Crafting", note = "Very weak effect and has tank multiplier to make it even worse." },
        } },
    },
}

ns.TrinketTiers["DRUID_BALANCE"] = {
    season = "Midnight Season 2",
    intro = "The trinket situation for Balance Druid in Midnight Season 2 offers you a choice of two passive trinkets: Wavecaller's Seastone or Gebbo's Bottomless Bag. Both of these passive trinkets are good when paired with an On-Use and they perform equally well.\n\nFor your On-Use trinket, the choice is between Freightrunner's Flask or Vile Vial of Volatile Venom. Since both of them have different cooldowns you will have to alter some of your cooldown timings to match their cadence.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270164, from = "Raid", note = "The best passive trinket from the raid. It has the chance to proc 6 different buffs, and buffs can overlap. Some of them are negative effects, but are massively outweighed by the positive effect procs." },
            { id = 270167, from = "Raid", note = "This trinket and the Gebbo's Bottomless Bag are very close in power, and whichever one you decide to use depends on what drops for you. There can be differences between the trinkets based on talents, but you should sim them opposite each other to figure out which one to use." },
            { id = 273796, from = "Mythic Plus", note = "2 minute trinket from Mythic+. Currently the best simming on-use trinket available. Alters your cooldown planning a little to accomodate the cooldown. This trinket can alter which stat you get from Potion of Recklessness if you are using that, so remember to press the Potion before the trinket!" },
        } },
        { label = "A", rank = 2, items = {
            { id = 250215, from = "Mythic Plus", note = "90 second trinket from Mythic+. Gives a decent Critical Strike buff when used. Alters your cooldown planning a little to accomodate the cooldown." },
            { id = 250214, from = "Mythic Plus", note = "Solid passive trinket alternative from Mythic+. Potentially strong if you manage to stand inside the light zone." },
        } },
        { label = "B", rank = 3, items = {
            { id = 270169, from = "Raid", note = "The signature on-use trinket from the season. Gradually gains stacks up to 30, and caps out around 3 minutes into the fight. Potentially very strong trinket for late raid bosses and for big burst moments. Currently very undertuned and not worth using over other trinkets, but will surely get tuned up." },
            { id = 193757, from = "Mythic Plus" },
            { id = 270168, from = "Raid" },
        } },
        { label = "C", rank = 4, items = {
            { id = 270161, from = "Raid" },
            { id = 270170, from = "Raid" },
            { id = 250259, from = "Mythic Plus" },
            { id = 250224, from = "Mythic Plus" },
        } },
        { label = "D", rank = 5, items = {
            { id = 250462, from = "Delves" },
            { id = 270162, from = "Raid" },
            { id = 250255, from = "Mythic Plus" },
            { id = 273794, from = "Mythic Plus" },
            { id = 273649, from = "Mythic Plus" },
        } },
    },
}

ns.TrinketTiers["DRUID_FERAL"] = {
    season = "Midnight Season 2",
    intro = "Feral will want too aim too use one strong on use trinket combined with a secondary trinket, that secondary trinket can be an on use damage trinket or it can be a strong proc trinket. Feral will sync the on use trinket with their strongest cooldowns, Berserk and Convoke the Spirits. There are a variety of options for on use trinkets for this tier but there is one that is undeniably strongest.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270175, from = "Raid", note = "Heart is the strongest on use stat trinket available. Despite not perfectly syncing with our cooldowns it's still our strongest option." },
            { id = 270173, from = "Raid", note = "Guilotine is a simple trinket, it's just a damage proc however it's tuned strong enough that it's our strongest option in single target." },
            { id = 270164, from = "Raid", note = "Outside of single target Grebbo's is our best secondary trinket, it's a strong stat proc trinket." },
        } },
        { label = "A", rank = 2, items = {
            { id = 159617, from = "Mythic Plus", note = "You'll allways want a strong on use trinket, While Heart is the strongest option this is a close competitor." },
            { id = 273796, from = "Mythic Plus", note = "You'll allways want a strong on use trinket, While Heart is the strongest option this is a close competitor." },
            { id = 270165, from = "Raid", note = "Keeper's is another strong secondary stat trinket, if you haven't gotten Guilotine or Grebbo's yet this is a strong option." },
        } },
        { label = "B", rank = 3, items = {
            { id = 250215, from = "Mythic Plus" },
            { id = 250214, from = "Mythic Plus" },
            { id = 270166, from = "Mythic Plus" },
            { id = 250225, from = "Mythic Plus" },
        } },
        { label = "C", rank = 4, items = {
            { id = 250259, from = "Mythic Plus" },
            { id = 250228, from = "Mythic Plus" },
            { id = 273797, from = "Mythic Plus" },
        } },
        { label = "D", rank = 5, items = {
            { id = 158374, from = "Mythic Plus" },
            { id = 270168, from = "Raid" },
        } },
    },
}

ns.TrinketTiers["DRUID_GUARDIAN"] = {
    season = "Midnight Season 2",
    intro = "Guardian is very flexible when it comes to trinkets. Offensively we enjoy pairing a powerful 2 minute on-use with our Incarnation: Guardian of Ursoc, but 2 passive trinkets can be equally as strong if they are tuned well. We also need to keep a lookout for tanking trinkets that can help us survive if necessary.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270164, from = "Raid", note = "Strong Overall Trinket" },
            { id = 270173, from = "Raid", note = "Very Strong Trinket for DPS" },
            { id = 270175, from = "Raid" },
            { id = 270165, from = "Raid" },
            { id = 270168, from = "Raid" },
        } },
        { label = "A", rank = 2, items = {
            { id = 270166, from = "Raid" },
            { id = 273796, from = "Mythic Plus" },
            { id = 273797, from = "Mythic Plus" },
            { id = 250215, from = "Mythic Plus" },
            { id = 250245, from = "Mythic Plus" },
        } },
        { label = "B", rank = 3, items = {
            { id = 250228, from = "Mythic Plus" },
            { id = 250214, from = "Mythic Plus" },
            { id = 159617, from = "Mythic Plus" },
            { id = 250259, from = "Mythic Plus" },
        } },
        { label = "C", rank = 4, items = {
            { id = 246304, from = "Crafting" },
            { id = 246305, from = "Crafting" },
            { id = 246306, from = "Crafting" },
            { id = 246307, from = "Crafting" },
            { id = 241340, from = "Crafting" },
            { id = 250225, from = "Mythic Plus" },
            { id = 193757, from = "Mythic Plus" },
        } },
        { label = "D", rank = 5, items = {
            { id = 158374, from = "Mythic Plus" },
        } },
    },
}

ns.TrinketTiers["DRUID_RESTORATION"] = {
    season = "Midnight Season 2",
    intro = "Here is a list of most trinkets available this season. Note that these could change in the first few weeks of season.",
    tiers = {
        { label = "S+", rank = 1, items = {
            { id = 270162, from = "Raid", note = "An extremely powerful healing trinket in both raid and dungeon." },
        } },
        { label = "A", rank = 2, items = {
            { id = 270167, from = "Raid", note = "A solid Haste / Intellect stat stick. Available off the new Lair boss." },
            { id = 270164, from = "Raid" },
        } },
        { label = "B", rank = 3, items = {
            { id = 250214, from = "Mythic Plus" },
            { id = 249343, from = "Raid" },
        } },
        { label = "C", rank = 4, items = {
            { id = 270169, from = "Raid" },
            { id = 248583, from = "Delves" },
            { id = 251792, from = "Delves" },
            { id = 273649, from = "Mythic Plus" },
            { id = 273796, from = "Mythic Plus" },
            { id = 250215, from = "Mythic Plus" },
            { id = 250248, from = "Mythic Plus" },
            { id = 193757, from = "Mythic Plus" },
            { id = 264507, from = "Delves", note = "Despite featuring weaker stats for us, this is a good starter trinket since it is acquirable without stepping foot in a raid or dungeon." },
            { id = 250254, from = "Mythic Plus" },
            { id = 250255, from = "Mythic Plus" },
        } },
        { label = "D", rank = 5, items = {
            { id = 251788, from = "Delves" },
            { id = 251789, from = "Delves" },
        } },
        { label = "F", rank = 6, items = {
            { id = 270171, from = "Raid" },
            { id = 264701, from = "Delves" },
            { id = 252957, from = "Delves" },
            { id = 264694, from = "Delves" },
            { id = 193748, from = "Mythic Plus" },
        } },
    },
}

ns.TrinketTiers["EVOKER_AUGMENTATION"] = {
    season = "Midnight Season 2",
    intro = "In Midnight Season 2, the strongest trinkets for Augmentation generally provide secondary stats most aligned with the spec's buff-oriented stat priority, or otherwise deal reasonable direct damage through their various effects.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 250224, from = "Mythic Plus", note = "Recommended for Raid and Mythic+.\n\nMindpiercer's Sigil is a passive trinket with no baseline stats, instead providing direct damage and an Intellect proc. This trinket loses some value in high target counts, but on average is one of the strongest trinkets available for Augmentation in Season 2." },
            { id = 270164, from = "Raid", note = "Recommended for Raid and Mythic+.\n\nGebbo's Bottomless Bag provides passive Intellect and a variety of different stat-based proc effects. Although this trinket is not particularly impressive for pure Single Target, its stat-based effects scale well into AoE, and it should be considered a top pick for most Season 2 content." },
            { id = 270167, from = "Raid", note = "Recommended for Raid and Mythic+.\n\nWavecaller's Seastone is expected to be a solid overall passive trinket in both Raid and Mythic+ in Season 2, particularly shining in higher target counts where stat effects typically outscale direct damage." },
            { id = 270161, from = "Raid", note = "Recommended for Raid and Mythic+.\n\nFang of Umbral Malignance deals reasonable stacking damage in low target count situations, but truly shines in Mythic+ where the on-death effect provides substantial value. This trinket is particularly effective when chain-pulling mobs, as low-health mobs from the first pull will detonate and apply stacks to mobs from the second pull." },
            { id = 250215, from = "Mythic Plus", note = "Recommended for Mythic+.\n\nFreightrunner's Flask is one of the only on-use stat trinkets available in Season 2, providing Critical Strike on a 1.5 minute cooldown. While this effect is reasonably solid for raid encounters, this trinket is more likely to see use in Mythic+ for higher target counts." },
        } },
        { label = "A", rank = 2, items = {
            { id = 249346, from = "Raid", note = "Vaelgor's Final Stare is a Season 1 trinket and cannot be obtained at a competitive item level in Season 2. The trinket's on-use Mastery effect was nerfed in pre-season tuning, but even afterwards this trinket at item level 298 remains particularly viable\\u2014especially in Raids\\u2014and is only outclassed by Season 2 trinkets on Myth track." },
            { id = 270168, from = "Raid", note = "Font of Venomous Rage is a highly situational burst damage trinket providing massive on-use single-target damage on a long 4-minute cooldown. This trinket can be obtained at item level 344 from Mythic Ula'tek and is currently the strongest trinket available for pure Single Target, particularly if burst damage is valuable or required. This trinket scales poorly however in AoE when it comes to overall damage, and there are limited raid encounters in Season 2 featuring a pure single-target damage profile." },
            { id = 250214, from = "Mythic Plus", note = "Lightspire Core is expected to be a solid overall passive trinket in both Raid and Mythic+ in Season 2, particularly shining in higher target counts where stat effects typically outscale direct damage. It should be noted that the bonus effect from this trinket always spawns on top of you, but do not expect to get full value from this effect every time it activates." },
            { id = 270170, from = "Raid", note = "Vexhul's Everflowing Gland is a particularly strong on-use single-target damage effect, but is outscaled quickly when multiple targets are in play. That said, encounters with adds may trigger the cooldown reduction effect, providing quite a bit of additional value." },
        } },
        { label = "B", rank = 3, items = {
            { id = 273796, from = "Raid" },
            { id = 270169, from = "Raid" },
            { id = 250259, from = "Mythic Plus" },
            { id = 273794, from = "Mythic Plus" },
            { id = 246304, from = "Crafting" },
            { id = 248583, from = "Delves" },
        } },
        { label = "C", rank = 4, items = {
            { id = 193757, from = "Mythic Plus" },
            { id = 158368, from = "Mythic Plus" },
            { id = 273649, from = "Mythic Plus" },
            { id = 274493, from = "Delves" },
            { id = 251792, from = "Delves" },
            { id = 246305, from = "Crafting" },
        } },
        { label = "D", rank = 5, items = {
            { id = 251786, from = "Delves" },
            { id = 274497, from = "Delves" },
            { id = 274496, from = "Delves" },
            { id = 246306, from = "Crafting" },
            { id = 246307, from = "Crafting" },
            { id = 241340, from = "Crafting" },
            { id = 251783, from = "Delves" },
            { id = 251787, from = "Delves" },
            { id = 251784, from = "Delves" },
            { id = 251785, from = "Delves" },
            { id = 280123, from = "Delves" },
        } },
    },
}

ns.TrinketTiers["EVOKER_DEVASTATION"] = {
    season = "Midnight Season 2",
    intro = "Devastation is a bit flexible with its trinkets due to the length of its cooldown, Dragonrage. The current best setup are two passive trinkets, but you can also run an on-use. You can technically run double on-use (and use them back to back), but it is not optimal currently.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270164, from = "Raid", note = "Passive Trinket. Overall Best." },
            { id = 273796, from = "Mythic Plus", note = "On-use trinket that is used with cooldowns when available. Provides a very high amount of a random secondary stat, then lowers a random stat after. Myth track version is tied for Best-in-Slot, despite the random nature of this trinket." },
            { id = 270167, from = "Raid", note = "Passive trinket. Second best raid option." },
        } },
        { label = "A", rank = 2, items = {
            { id = 250214, from = "Mythic Plus", note = "Passive trinket that provides Mastery. Standing in the light circle provides additional stats." },
            { id = 270170, from = "Raid" },
            { id = 250215, from = "Mythic Plus" },
            { id = 250224, from = "Mythic Plus" },
            { id = 270169, from = "Raid", note = "On-use trinket that passively drains stats. Must be used on cooldown, otherwise it drops to C tier. Do not attempt to pair this with another on-use trinket." },
        } },
        { label = "B", rank = 3, items = {
            { id = 273649, from = "Mythic Plus" },
            { id = 193757, from = "Mythic Plus" },
            { id = 250259, from = "Mythic Plus" },
            { id = 251792, from = "Delves" },
        } },
        { label = "C", rank = 4, items = {
            { id = 270161, from = "Raid" },
            { id = 270168, from = "Raid" },
            { id = 273794, from = "Mythic Plus" },
            { id = 274493, from = "Delves" },
        } },
        { label = "D", rank = 5, items = {
            { id = 246305, from = "Crafting" },
            { id = 246304, from = "Crafting" },
            { id = 246306, from = "Crafting" },
            { id = 246307, from = "Crafting" },
            { id = 241340, from = "Crafting" },
            { id = 251786, from = "Delves" },
            { id = 274497, from = "Delves" },
            { id = 274496, from = "Delves" },
            { id = 250462, from = "Delves" },
            { id = 251783, from = "Delves" },
            { id = 251787, from = "Delves" },
            { id = 251784, from = "Delves" },
            { id = 251785, from = "Delves" },
            { id = 280123, from = "Delves" },
        } },
    },
}

ns.TrinketTiers["EVOKER_PRESERVATION"] = {
    season = "Midnight Season 2",
    intro = "Preservation is really hunting for some of the more powerful stat sticks from the raid. They just offer the most overall value. One also happens to be an on-use, which we'll be able to combine with our Stasis or Dream Flight windows for even more power.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270162, from = "Raid", note = "An extremely heavy hitter that dominates both raid and mythic+ selections. Drops off the first boss so should be obtainable by most people - even if Raid isn't really your bag." },
        } },
        { label = "A", rank = 2, items = {
            { id = 270164, from = "Raid" },
            { id = 270167, from = "Raid" },
            { id = 250214, from = "Mythic Plus" },
        } },
        { label = "B", rank = 3, items = {
            { id = 248583, from = "Delves" },
            { id = 251792, from = "Delves" },
            { id = 250215, from = "Mythic Plus" },
            { id = 273796, from = "Mythic Plus" },
            { id = 264507, from = "Delves", note = "While this loses to a lot of Myth-track alternatives, it's extremely easy to get and punches well above its item level." },
            { id = 270169, from = "Raid" },
            { id = 273649, from = "Mythic Plus" },
            { id = 250248, from = "Mythic Plus" },
            { id = 193757, from = "Mythic Plus" },
            { id = 250254, from = "Mythic Plus" },
            { id = 250255, from = "Mythic Plus" },
            { id = 249343, from = "Delves" },
        } },
        { label = "C", rank = 4, items = {
            { id = 251788, from = "Delves" },
            { id = 251789, from = "Delves" },
        } },
        { label = "D", rank = 5, items = {
            { id = 270171, from = "Raid" },
        } },
        { label = "F", rank = 6, items = {
            { id = 252957, from = "Delves" },
            { id = 193748, from = "Mythic Plus" },
        } },
        { label = "G", rank = 7, items = {
            { id = 264701, from = "Delves" },
        } },
    },
}

ns.TrinketTiers["HUNTER_BEASTMASTERY"] = {
    season = "Midnight Season 2",
    intro = "In general, Beast Mastery has no specific preferences in terms of trinkets, it mostly enjoy the ones that provide the largest quantity of secondary stats, whether that be passive trinkets or on-use trinkets.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270173, from = "Raid" },
            { id = 270175, from = "Raid" },
            { id = 270165, from = "Raid" },
        } },
        { label = "A", rank = 2, items = {
            { id = 270168, from = "Raid" },
            { id = 159617, from = "Mythic Plus" },
            { id = 273796, from = "Mythic Plus" },
            { id = 270164, from = "Raid" },
            { id = 250215, from = "Mythic Plus" },
        } },
        { label = "B", rank = 3, items = {
            { id = 270166, from = "Raid" },
            { id = 273797, from = "Mythic Plus" },
            { id = 250228, from = "Mythic Plus" },
            { id = 193757, from = "Mythic Plus" },
            { id = 246304, from = "Crafting" },
        } },
        { label = "C", rank = 4, items = {
            { id = 274493, from = "Delves" },
            { id = 250214, from = "Mythic Plus" },
            { id = 250259, from = "Mythic Plus" },
            { id = 250225, from = "Mythic Plus" },
            { id = 158374, from = "Mythic Plus" },
            { id = 246305, from = "Crafting" },
            { id = 246307, from = "Crafting" },
            { id = 274496, from = "Delves" },
            { id = 274497, from = "Delves" },
        } },
        { label = "D", rank = 5, items = {
            { id = 241340, from = "Crafting" },
            { id = 246306, from = "Crafting" },
            { id = 280123, from = "Delves" },
        } },
    },
}

ns.TrinketTiers["HUNTER_MARKSMANSHIP"] = {
    season = "Midnight Season 2",
    intro = "Marksmanship wants one trinket that lines up with Trueshot and one that is simply tuned well. Voracious Heart of Ula'tek is the on-use to pair with your Trueshot, and Zul'jin's Guillotine Technique is the passive that goes in the other slot. Until you have Guillotine, Font of Venomous Rage is the strongest stand-in even though it doubles up on on-uses; Keeper's Seething Core is the closest passive replacement. From Mythic+, Lustrous Golden Plumage takes the on-use slot until you have the Heart from the Raid.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270175, from = "Raid", note = "Our best on-use Trinket. Hold it for Trueshot." },
            { id = 270173, from = "Raid", note = "An excellent passive Trinket." },
            { id = 270168, from = "Raid" },
        } },
        { label = "A", rank = 2, items = {
            { id = 273796, from = "Mythic Plus" },
            { id = 159617, from = "Mythic Plus" },
        } },
        { label = "B", rank = 3, items = {
            { id = 250225, from = "Mythic Plus" },
            { id = 250215, from = "Mythic Plus" },
            { id = 270165, from = "Raid" },
            { id = 273797, from = "Mythic Plus" },
            { id = 270164, from = "Raid", note = "There are various procs it can do, most of them being secondary stat buffs, and one actually being a debuff." },
            { id = 270166, from = "Raid" },
            { id = 250214, from = "Mythic Plus" },
        } },
        { label = "C", rank = 4, items = {
            { id = 193757, from = "Mythic Plus" },
            { id = 250228, from = "Mythic Plus" },
            { id = 158374, from = "Mythic Plus" },
            { id = 246304, from = "Crafting" },
        } },
        { label = "D", rank = 5, items = {
            { id = 250259, from = "Mythic Plus" },
        } },
    },
}

ns.TrinketTiers["HUNTER_SURVIVAL"] = {
    season = "Midnight Season 2",
    intro = "in Midnight Season 2, we are generally looking for raw stats, with Zul'jin's Guillotine Technique being (somewhat) of an exception. Trinkets that rely on procs to deal damage generally cannot keep up if they do not carry the item level advantage that Zul'jin's Guillotine Technique has.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270173, from = "Raid", note = "A single target powerhouse trinkets that is also execute weighted, perfect for progression raiding. When paired with either Maze-roa, Warlord's Fury or Aman'muso, Warlord's Vengeance, it also shreds 2-target bosses." },
            { id = 270175, from = "Raid", note = "Works wonderfully with 90 second builds for ST and AoE, but it even keeps up using 60 second builds in Single Target too. When using this trinket on a 60 second build, you use it as its own independant cooldown so that it lines up with the first and third use of Takedown" },
        } },
        { label = "A", rank = 2, items = {
            { id = 270165, from = "Raid", note = "As a stat stick this scales far beyond the 2-target cap of Zul'jin's Guillotine Technique, and as a result will outperform it for strictly AoE purposes." },
            { id = 270164, from = "Raid", note = "Very decent stat stick trinket that is powerful for ST and AoE alike. Especially given that it is relatively easy to obtain on Myth item levels versus some of the other options out there." },
        } },
        { label = "B", rank = 3, items = {
            { id = 159617, from = "Mythic Plus", note = "Although we don't really like Versatility, it lines up perfectly with ordinary 60 second builds, allowing it to still perform well for those builds, though they fit a more niche role within our meta, and are generally only used when the cooldowns line up exceptionally well with an encounter mechanic." },
            { id = 250214, from = "Mythic Plus", note = "Technically performs well, but as a melee you might struggle staying inside of the tiny light, especially if it happens to proc when your mythic+ group is still gathering (and moving) the mobs." },
            { id = 250215, from = "Mythic Plus", note = "Pairs really well with Sentinel's 90 second AoE builds, but falls behind harshly anywhere else." },
            { id = 273796, from = "Mythic Plus", note = "Works reasonably well for 60 second builds, allowing it to still perform well for those builds, though they fit a more niche role within our meta, and are generally only used when the cooldowns line up exceptionally well with an encounter mechanic. With that said, it just isn't tuned well enough to be competitive with some of the A or S tier offerings." },
        } },
        { label = "C", rank = 4, items = {
            { id = 250225, from = "Mythic Plus", note = "Lines up well in theory, but its effect is too dilluted over its relatively long 20 second duration. At best, our cooldown lasts half as long." },
            { id = 193757, from = "Mythic Plus", note = "Can be trained to provide different kind of effects, but none are truly worth pursueing." },
            { id = 250259, from = "Mythic Plus", note = "This is too single target focused, and does its job fairly poorly at that. It can work in a pinch, but it's not too impressive." },
            { id = 270166, from = "Raid", note = "The stack-building effect is very awkward to use, and performs pretty poorly compared to ordinary stat trinkets simply buffing your entire AoE kit instead." },
            { id = 250228, from = "Mythic Plus", note = "It looks fairly decent at a glance, but it is sadly a little too undertuned to work well. Its constant uptime also risks your highest stat shifting away from Mastery to Crit more frequently, making it harder to optimise." },
        } },
        { label = "D", rank = 5, items = {
            { id = 158374, from = "Mythic Plus", note = "Every time this trinket shows up in any M+ season, it is just wildly undertuned for some reason. This season is no exception." },
            { id = 250245, from = "Mythic Plus", note = "Has a lot of its weight moved into healing, which isn't really our role." },
            { id = 270168, from = "Raid", note = "Has a bizarrely long cooldown for how little damage it does. On paper, blasting a target for 1 million damage sounds great, but you're also stuck channeling for a bit, and you are losing any Agility that would ordinarily be on a trinket like this." },
        } },
    },
}

ns.TrinketTiers["MAGE_ARCANE"] = {
    season = "Midnight Season 2",
    intro = "Overall, use trinkets are a bit weaker than usual, largely attributed to our loss of burst.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270164, from = "Raid", note = "Simply the highest output trinket. Cool." },
        } },
        { label = "A+", rank = 2, items = {
            { id = 250215, from = "Mythic Plus", note = "Pairs perfectly with Arcane Surge." },
            { id = 270167, from = "Raid", note = "Another solid passive if you can't get Gebbo's." },
        } },
        { label = "A", rank = 3, items = {
            { id = 250214, from = "Mythic Plus", note = "Decent until you get better, lots of passive trinkets this season." },
            { id = 273796, from = "Mythic Plus", note = "Not terrible but 2-minute trinkets lose some value since we only want to pair them with Arcane Surge." },
            { id = 250224, from = "Mythic Plus", note = "Woo another passive, I'm just going to note \"Accept Tuning\" on the rest of these." },
            { id = 251792, from = "Delves/Open World", note = "Accept Tuning" },
        } },
        { label = "B", rank = 4, items = {
            { id = 270170, from = "Raid", note = "One of those trinkets that should be fun and cool but is just never tuned competitively enough to want to use. Sad!" },
            { id = 270169, from = "Raid", note = "New Spymasters, unfortunately tuned low, we're also a different spec now and the natural synergy with execute just isn't there anymore." },
            { id = 273649, from = "Mythic Plus", note = "Simply, elegant, but 2-minutes so still meh. Remember to pair with Arcane Surge." },
            { id = 250259, from = "Mythic Plus", note = "Accept Tuning" },
            { id = 273794, from = "Mythic Plus", note = "Accept Tuning" },
            { id = 193757, from = "Mythic Plus", note = "Accept Tuning" },
            { id = 270161, from = "Raid", note = "Accept Tuning" },
        } },
        { label = "C", rank = 5, items = {
            { id = 270603, from = "Delves/Open World", note = "Accept Tuning" },
            { id = 251785, from = "Delves/Open World", note = "Accept Tuning" },
            { id = 251784, from = "Delves/Open World", note = "Accept Tuning" },
            { id = 264878, from = "Delves/Open World", note = "Just use it off cooldown, whatever!" },
            { id = 270602, from = "Delves/Open World", note = "Pair with Arcane Surge, held back by ilevel restrictions." },
        } },
        { label = "F", rank = 6, items = {
            { id = 250462, from = "Delves/Open World", note = "Accept Tuning" },
            { id = 270168, from = "Raid", note = "Use it off cooldown!" },
            { id = 251786, from = "Delves/Open World", note = "Use it with Arcane Surge." },
            { id = 251783, from = "Delves/Open World", note = "Accept Tuning" },
            { id = 251787, from = "Delves/Open World", note = "This trinket is hot trash unless you can completely nullify the stun and even then, its just not good." },
            { id = 274493, from = "Delves/Open World", note = "Accept Tuning" },
            { id = 274496, from = "Delves/Open World", note = "Use it off cooldown!" },
            { id = 274497, from = "Delves/Open World", note = "Use it off cooldown!" },
            { id = 246305, from = "Crafting", note = "Not only does this take up a trinket slot that could be something way better, but it also cost an embellishment! Not worth!" },
            { id = 246304, from = "Crafting", note = "Not only does this take up a trinket slot that could be something way better, but it also cost an embellishment! Not worth!" },
            { id = 246306, from = "Crafting", note = "Not only does this take up a trinket slot that could be something way better, but it also cost an embellishment! Not worth!" },
            { id = 246307, from = "Crafting", note = "Not only does this take up a trinket slot that could be something way better, but it also cost an embellishment! Not worth!" },
            { id = 241340, from = "Crafting", note = "Not only does this take up a trinket slot that could be something way better, but it also cost an embellishment! Not worth!" },
        } },
    },
}

ns.TrinketTiers["MAGE_FIRE"] = {
    season = "Midnight Season 2",
    intro = "Fire Mage is looking for trinkets that boost Intellect, Haste, or Mastery. Ideally, you have one passive trinket and an on-use trinket to pair with Combustion or two passive trinkets. Keep in mind that Combustion can be used while casting, but trinkets cannot. This means you need to remember to press your trinket (or macro) again once your cast finishes.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270164, from = "Raid", note = "Passive Trinket. Overall Best." },
            { id = 273796, from = "Mythic Plus", note = "On-use trinket that is used with cooldowns when available. Provides a very high amount of a random secondary stat, then lowers a random stat after. Myth track version is Best-in-Slot, despite the random nature of this trinket." },
            { id = 270167, from = "Raid", note = "Passive trinket. Second best raid option." },
        } },
        { label = "A", rank = 2, items = {
            { id = 250214, from = "Mythic Plus", note = "Passive trinket that provides Mastery. Standing in the light circle provides additional stats." },
            { id = 270170, from = "Raid" },
            { id = 250259, from = "Mythic Plus" },
        } },
        { label = "B", rank = 3, items = {
            { id = 250224, from = "Mythic Plus" },
            { id = 270169, from = "Raid", note = "On-use trinket that passively drains stats. Can be used for a stat increase. Best used on cooldown." },
            { id = 273649, from = "Mythic Plus" },
        } },
        { label = "C", rank = 4, items = {
            { id = 270161, from = "Raid" },
            { id = 270168, from = "Raid" },
            { id = 273794, from = "Mythic Plus" },
            { id = 274493, from = "Delves" },
            { id = 251792, from = "Delves" },
        } },
        { label = "D", rank = 5, items = {
            { id = 193757, from = "Mythic Plus" },
            { id = 250215, from = "Mythic Plus" },
            { id = 246305, from = "Crafting" },
            { id = 246304, from = "Crafting" },
            { id = 246306, from = "Crafting" },
            { id = 246307, from = "Crafting" },
            { id = 241340, from = "Crafting" },
            { id = 251786, from = "Delves" },
            { id = 274497, from = "Delves" },
            { id = 274496, from = "Delves" },
            { id = 250462, from = "Delves" },
            { id = 251783, from = "Delves" },
            { id = 251787, from = "Delves" },
            { id = 251784, from = "Delves" },
            { id = 251785, from = "Delves" },
            { id = 280123, from = "Delves" },
        } },
    },
}

ns.TrinketTiers["MAGE_FROST"] = {
    season = "Midnight Season 2",
    intro = "In Season 2, Frost Mage doesn't really need an on-use trinket. There are a lot of good passive trinkets and due to the nerfs to burst in the Ray of Frost window, having an on-use trinket there isn't as necessary anymore. Because Mastery and Critical Strike are Frost's best stats you may want to look for those, but in general trinket tuning is far more important than the specific secondary stats that show up on them.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270164, from = "Raid", note = "This is just a strong stat trinket in all situations for Season 2." },
            { id = 270167, from = "Raid", note = "While not always the second best option, this is just a good stat trinket that works well in all situations." },
        } },
        { label = "A", rank = 2, items = {
            { id = 273796, from = "Mythic Plus" },
            { id = 273649, from = "Mythic Plus" },
            { id = 250224, from = "Mythic Plus" },
            { id = 250215, from = "Mythic Plus" },
            { id = 270170, from = "Raid" },
            { id = 270168, from = "Raid" },
        } },
        { label = "B", rank = 3, items = {
            { id = 250259, from = "Mythic Plus" },
            { id = 193757, from = "Mythic Plus" },
            { id = 250214, from = "Mythic Plus" },
            { id = 270161, from = "Raid" },
            { id = 270169, from = "Raid" },
            { id = 251792, from = "Delves" },
            { id = 274493, from = "Delves" },
            { id = 248583, from = "Delves" },
            { id = 246305, from = "Crafting" },
            { id = 246304, from = "Crafting" },
        } },
        { label = "C", rank = 4, items = {
            { id = 273794, from = "Mythic Plus" },
            { id = 158368, from = "Mythic Plus" },
            { id = 246306, from = "Crafting" },
            { id = 246307, from = "Crafting" },
            { id = 241340, from = "Crafting" },
            { id = 251785, from = "Delves" },
            { id = 251784, from = "Delves" },
            { id = 251786, from = "Delves" },
            { id = 274496, from = "Delves" },
            { id = 274497, from = "Delves" },
            { id = 251783, from = "Delves" },
        } },
    },
}

ns.TrinketTiers["MONK_BREWMASTER"] = {
    season = "Midnight Season 2",
    intro = "As Brewmaster Monks are Tanks, they often do not benefit as much from trinkets offering boosts to Secondary stats compared to those offering raw damage effects. Ideally, these raw-damage trinkets are also on-use, allowing you to reliably apply extra burst damage on demand and generate additional threat at the same time. There is a cost to this, unfortunately, as DPS-oriented raw damage effects are reduced by 33% when used by a Tank specialization. Despite this penalty, however, raw damage trinkets may still be your preference for offensive power.\n\nTrinkets are also perhaps the most significant choice you can make when it comes to optimizing for a more offensive or defensive playstyle. It is best to keep a few options of either type so you can switch them around as the situation calls for them.\n\nAs a final note, this section will not discuss trinkets available from dungeons that are not available in the Midnight Season 2 dungeon pool. Remember as well that trinkets from Delves can only be obtained at a maximum item level of 321 (Hero Track) compared to the 334 (Myth Track) cap of dungeon/raid trinkets and the 344 (Elevated Myth Track) of a few select items. This will naturally devalue their potential ranking, though some may still place surprisingly well with this limitation.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270175, from = "Raid", note = "Containing a potent combination of static Critical Strike, on-use Agility every 90 seconds, bonus Physical damage to be amplified by your tier set and the Shado-Pan talents, and a potential Elevated Mythic item level, this trinket has everything a Brewmaster could want.\n\nEven on Heroic, it remains one of your strongest choices." },
            { id = 270173, from = "Raid", note = "Although this trinket has an additional set effect when combined with Aman'muso, Warlord's Vengeance, its baseline 3ppm effect remains more than capable of dealing great damage.\n\nNot to mention, its damage being physical creates synergy with both the Shado-Pan Hero Talents and your tier set bonus, while also being available at the Elevated Mythic item level." },
            { id = 270168, from = "Raid", note = "The 4-minute cooldown of this trinket is steep, as is your inability to dodge attacks during its channel. However, this trinket makes up for it by decimating your foes in bursts of damage, both in single-target and AoE.\n\nIt also is available at an Elevated Mythic item level." },
            { id = 250245, from = "Mythic Plus", note = "While it may be a tank trinket, this item boasts surprisingly potent damage in addition to its stream of healing at a rate of 3ppm. Despite splitting its damage in AoE, the total amount dealt also increasing maintains its power as a passive and \"hybrid\" option across target counts." },
        } },
        { label = "A", rank = 2, items = {
            { id = 159617, from = "Mythic Plus", note = "What is likely to be your preferred on-use trinket if unable to access an Elevated Mythic Voracious Heart of Ula'tek, this item grants you 20 seconds of increased Versatility every 2 minutes; this duration lines up nicely with Invoke Niuzao, the Black Ox when used by Master of Harmony Brewmasters in particular." },
            { id = 158374, from = "Mythic Plus", note = "No less strong than it was in its Battle for Azeroth debut, this trinket's ability to gain roughly 20 charges per minute results in decent uptime of its AoE chain lightning effect which triggers every 12 charges accumulated. The scaling nature of this effect makes it useful across many target counts." },
            { id = 250215, from = "Mythic Plus", note = "This trinket's power is greater for Shado-Pan Brewmasters, whose shorter cooldown on Invoke Niuzao, the Black Ox will readily line up with its on-demand Critical Strike every 90 seconds.\n\nHowever, it still remains incredibly potent for Master of Harmony players, too." },
            { id = 270164, from = "Raid", note = "There are six different effects this trinket can trigger, all at a rate of 3ppm:\n\nSeriously Sharp Seashell - 12-second self-bleed with a ramping Critical Strike bonus\nSlick and Slimy Gralstone - 12-second Haste and movement speed buff\nTattered Tortollan Scroll - 12-second Mastery buff that decays over its duration\nBrittle Torga Totem - Versatility buff that decays with every ability used\nRotting Voidfin - Reduce all secondary stats for 12 seconds\n50-Lb Midnight Salmon - Increase all secondary stats for 12 seconds\n\nWhile there may be a potential \"bad\" effect or two, these buffs are otherwise excellent and scale nicely across target counts. This easily makes it your strongest raid trinket among those that cannot reach the Elevated Mythic item level of 344." },
            { id = 250228, from = "Mythic Plus" },
            { id = 270166, from = "Raid", note = "It may be a bit boring, but this trinket's damage, dealt roughly once per minute, has bonuses when striking either one enemy or multiple. This combines to make it a convenient passive choice, though you will feel a pang of regret if the damage doesn't line up when you want it to." },
            { id = 250259, from = "Mythic Plus" },
            { id = 250214, from = "Mythic Plus", note = "You can see exceptional amounts of Mastery when wearing this trinket, but only if you are able to reliably stand in the light beams it creates, which may not always be possible in the middle of combat." },
            { id = 248583, from = "Delves" },
            { id = 270165, from = "Raid", note = "Despite being a Haste-focused trinket, this item performs surprisingly well for Brewmasters in the season largely due to its potential to scale your AoE damage in particular. It does so by reducing the cooldown of Keg Smash to more regularly trigger your tier set bonuses; throw in a generous proc rate of 6ppm and you also frequently benefit from the 20% bonus to its Haste for having multiple stacks at once." },
            { id = 270160, from = "Raid" },
            { id = 265657, from = "Delves" },
        } },
        { label = "B", rank = 3, items = {
            { id = 273796, from = "Mythic Plus" },
            { id = 251785, from = "Delves" },
            { id = 159618, from = "Mythic Plus" },
            { id = 274493, from = "Delves" },
            { id = 250225, from = "Mythic Plus" },
            { id = 193757, from = "Mythic Plus", note = "There is a surprising amount of depth to the mechanics of this trinket, which greatly modifies its potential for players. This is due to there being 6 different effects that can occur; through training it over the course of a week to prioritize your desired buff you will gain a deceptively powerful item above its usual ranking. The 6 effects are:\n\nFire Shot - single-target damage\nLobbing Fire Nova - AoE damage\nUnder Red Wings - 12-second Haste buff\nSleepy Ruby Warmth - 12-second Critical Strike buff\nCuring Whiff - single-target heal\nMending Breath - AoE heal\n\nIt is recommended to train your whelp for AoE damage by activating its on-use while fighting AoE training dummies." },
            { id = 273797, from = "Mythic Plus" },
            { id = 250243, from = "Mythic Plus" },
            { id = 251792, from = "Delves" },
            { id = 250244, from = "Mythic Plus" },
            { id = 246307, from = "Crafting", note = "While crafted Darkmoon Dominion trinkets quickly lose power as your item level increases due to their static value, they are uniquely enhanced in Midnight when worn with a crafted weapon using a matching Darkmoon Sigil embellishment (such as Darkmoon Sigil: Void).\n\nThis can result in better performance than you would otherwise expect, but still won't reach the heights of the best-in-slot options." },
            { id = 241340, from = "Crafting", note = "The ever-present Alchemist Stone trinket of every expansion is stronger than normal this time around. However, it counts as one of your two pieces of embellished gear, rendering it undesirable in spite of its potency." },
        } },
        { label = "C", rank = 4, items = {
            { id = 274498, from = "Delves" },
            { id = 251790, from = "Delves" },
            { id = 251783, from = "Delves" },
            { id = 246306, from = "Crafting" },
            { id = 274499, from = "Delves" },
            { id = 274497, from = "Delves" },
            { id = 270174, from = "Raid" },
        } },
        { label = "D", rank = 5, items = {
            { id = 274496, from = "Delves" },
            { id = 246304, from = "Crafting" },
            { id = 264694, from = "Delves" },
            { id = 246305, from = "Crafting" },
        } },
    },
}

ns.TrinketTiers["MONK_MISTWEAVER"] = {
    season = "Midnight Season 2",
    intro = "Mistweaver Monk has a wide variety of trinkets to choose from in Midnight Season 2, however there are clear outliers (listed below) - this patch, our Best in Slot trinkets come in the form of both an active and passive with some closeby alternatives.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270162, from = "Raid", note = "A healer Manic Grieftorch. Crazy concept! Short 2-sec cast to shield your allies, that automatically shields again (and reduces the remaining CD of the trinket) when an ally dies. Phenomenal for prog, phenomenal in general." },
        } },
        { label = "A", rank = 2, items = {
            { id = 270167, from = "Raid", note = "High haste stat stick with an increasingly larger effect bonus that ebbs and flows its Intellect gain while active." },
            { id = 270169, from = "Raid", note = "Another high haste trinket, but this time comes with an on-use and passive effect. A modern day Spymaster's Web - try to use this on cooldown (with cooldowns) in order to not lose too much Intellect from the negative part of the trinket." },
            { id = 270164, from = "Raid", note = "Mysterious as this trinket may be, it's quite simple with high uptime on a few different stats gains.\n\nRamping Crit\nHaste + movement speed\nReverse Vers ramp\nReverse Mastery ramp\nAll secondary buff\nand a negative to all secondary stats debuff\n\nGreat overall, just has a small negative to it. Solidly A tier." },
        } },
        { label = "B", rank = 3, items = {
            { id = 248583, from = "Delves" },
            { id = 251792, from = "Delves" },
            { id = 273796, from = "Mythic Plus" },
            { id = 250248, from = "Mythic Plus" },
        } },
        { label = "C", rank = 4, items = {
            { id = 274493, from = "Delves" },
            { id = 250215, from = "Mythic Plus" },
            { id = 193757, from = "Mythic Plus" },
            { id = 250255, from = "Mythic Plus" },
            { id = 250254, from = "Mythic Plus" },
            { id = 250214, from = "Mythic Plus", note = "Much better for Chi-Ji builds, high A tier. Would never use with Yu'lon." },
            { id = 264507, from = "Delves", note = "From renown (not actually from delves!). A very powerful crit / leech stat stick that gets stronger with completed world content in Voidstorm. Incredibly overbudget and low item level is comparable to Mythic-ilvl trinkets." },
        } },
        { label = "D", rank = 5, items = {
            { id = 273649, from = "Mythic Plus", note = "Pair with your 2-minute Invoke Yu'lon, the Jade Serpent or Invoke Chi-Ji, the Red Crane. Has a non-hasted 2 second cast time to get the haste bonus, but you cannot move while casting (unlike Soulcoiler's Vessel) and will lose the effect and be put on cooldown if you cancel the channel. Useless." },
            { id = 251789, from = "Delves" },
            { id = 270171, from = "Raid" },
            { id = 251788, from = "Delves" },
            { id = 280091, from = "Delves" },
            { id = 274495, from = "Delves" },
        } },
        { label = "F", rank = 6, items = {
            { id = 252957, from = "Delves" },
            { id = 193748, from = "Mythic Plus" },
            { id = 264694, from = "Delves" },
            { id = 274494, from = "Delves" },
            { id = 264701, from = "Delves" },
        } },
    },
}

ns.TrinketTiers["MONK_WINDWALKER"] = {
    season = "Midnight Season 2",
    intro = "Windwalker Monks are mainly looking for one powerful on use trinket to pair with their cooldowns and a supplementary either proc or flat stat trinket. Because the cooldown of Zenith can be flexible based on talents, Windwalker can adapt to many different trinkets with different cooldown durations.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270175, from = "Raid" },
            { id = 270173, from = "Raid" },
        } },
        { label = "A", rank = 2, items = {
            { id = 250215, from = "Mythic Plus" },
            { id = 273796, from = "Mythic Plus" },
            { id = 250225, from = "Mythic Plus" },
            { id = 270164, from = "Raid" },
        } },
        { label = "B", rank = 3, items = {
            { id = 250259, from = "Mythic Plus" },
            { id = 270168, from = "Raid" },
            { id = 159617, from = "Mythic Plus" },
        } },
        { label = "D", rank = 4, items = {
            { id = 270165, from = "Raid" },
            { id = 250214, from = "Mythic Plus" },
            { id = 241340, from = "Crafting" },
            { id = 273797, from = "Mythic Plus" },
            { id = 270166, from = "Raid" },
        } },
        { label = "F", rank = 5, items = {
            { id = 250228, from = "Mythic Plus" },
            { id = 193757, from = "Mythic Plus" },
            { id = 158374, from = "Mythic Plus" },
        } },
    },
}

ns.TrinketTiers["PALADIN_HOLY"] = {
    season = "Midnight Season 2",
    intro = "Due to Holy Paladin's lack of large throughput cooldowns to pair on-use trinkets with, we tend to prefer so called stat-stick trinkets that simply give us as many stats as possible. This season our best trinket, Soulcoiler Ritual Vessel, is actually an on-use one, but not one that gives you stats so you should not pair it with your cooldowns.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270162, from = "Raid" },
            { id = 270164, from = "Raid" },
        } },
        { label = "A", rank = 2, items = {
            { id = 270167, from = "Raid" },
            { id = 250215, from = "Mythic Plus" },
            { id = 250214, from = "Mythic Plus" },
            { id = 270169, from = "Raid" },
        } },
        { label = "B", rank = 3, items = {
            { id = 273796, from = "Mythic Plus" },
            { id = 248583, from = "Delves" },
            { id = 251792, from = "Delves" },
            { id = 273649, from = "Mythic Plus" },
            { id = 250248, from = "Mythic Plus" },
            { id = 241340, from = "Crafting" },
            { id = 245829, from = "Crafting" },
        } },
        { label = "C", rank = 4, items = {
            { id = 250254, from = "Mythic Plus" },
            { id = 193757, from = "Mythic Plus" },
            { id = 250255, from = "Mythic Plus" },
        } },
        { label = "D", rank = 5, items = {
            { id = 270171, from = "Raid" },
            { id = 193748, from = "Mythic Plus" },
        } },
    },
}

ns.TrinketTiers["PALADIN_PROTECTION"] = {
    season = "Midnight Season 2",
    intro = "Protection Paladin is fairly flexible when it comes to trinkets. Aligning an on-use with our AW is nice, which generally is a 1/2min CD but two strong passive trinkets work equally as well.\nDefensive trinkets should also be kept in mind, you never know when a certain boss will really test your might.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270164, from = "Raid", note = "Strong Trinket" },
            { id = 270173, from = "Raid", note = "Very Strong Trinket" },
            { id = 270175, from = "Raid" },
            { id = 270165, from = "Raid" },
            { id = 270168, from = "Raid" },
        } },
        { label = "A", rank = 2, items = {
            { id = 273796, from = "Mythic Plus" },
            { id = 270163, from = "Raid" },
            { id = 273797, from = "Mythic Plus" },
            { id = 158367, from = "Mythic Plus" },
            { id = 250259, from = "Mythic Plus" },
            { id = 250245, from = "Mythic Plus" },
            { id = 250229, from = "Mythic Plus" },
        } },
        { label = "B", rank = 3, items = {
            { id = 250228, from = "Mythic Plus" },
            { id = 273795, from = "Mythic Plus" },
            { id = 193762, from = "Mythic Plus" },
        } },
        { label = "C", rank = 4, items = {
            { id = 241340, from = "Crafting" },
            { id = 250238, from = "Mythic Plus" },
            { id = 193757, from = "Mythic Plus" },
        } },
        { label = "D", rank = 5, items = {
            { id = 246304, from = "Crafting" },
            { id = 246305, from = "Crafting" },
            { id = 246306, from = "Crafting" },
            { id = 246307, from = "Crafting" },
        } },
    },
}

ns.TrinketTiers["PALADIN_RETRIBUTION"] = {
    season = "Midnight Season 2",
    intro = "Retribution tends to favor stat trinkets over direct damage ones. Because our cooldowns are relatively short and passive options are currently fairly powerful, most strong trinkets are passive options, but there are still strong on-use trinkets available as well.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270173, from = "Raid", note = "Requires the set bonus to be active to be really strong on cleave, but is the strongest option by far when it is." },
            { id = 270175, from = "Raid", note = "A solid on-use effect. When using it, you should hold it for Avenging Wrath's cooldown." },
        } },
        { label = "B", rank = 2, items = {
            { id = 270164, from = "Raid" },
            { id = 270165, from = "Raid" },
            { id = 273796, from = "Mythic Plus" },
            { id = 193762, from = "Mythic Plus" },
            { id = 250259, from = "Mythic Plus", note = "Although this is an ok single target option, it falls off on AoE." },
            { id = 251792, from = "Delves" },
            { id = 274493, from = "Delves" },
        } },
        { label = "C", rank = 3, items = {
            { id = 250228, from = "Mythic Plus" },
            { id = 158367, from = "Mythic Plus", note = "On pure AoE this is a solid option, but it is awful on single target." },
            { id = 250229, from = "Mythic Plus" },
            { id = 250238, from = "Mythic Plus" },
            { id = 273797, from = "Mythic Plus" },
            { id = 250245, from = "Mythic Plus" },
            { id = 246304, from = "Crafting", note = "Takes up an embellishment slot, so is not recommended." },
            { id = 246305, from = "Crafting", note = "Takes up an embellishment slot, so is not recommended." },
        } },
        { label = "D", rank = 4, items = {
            { id = 270168, from = "Raid" },
            { id = 270163, from = "Raid" },
            { id = 273795, from = "Mythic Plus" },
            { id = 193757, from = "Mythic Plus" },
            { id = 246307, from = "Crafting", note = "Takes up an embellishment slot, so is not recommended." },
            { id = 246306, from = "Crafting", note = "Takes up an embellishment slot, so is not recommended." },
            { id = 241340, from = "Crafting", note = "Takes up an embellishment slot, so is not recommended." },
        } },
    },
}

ns.TrinketTiers["PRIEST_DISCIPLINE"] = {
    season = "Midnight Season 2",
    intro = "Updated August 17 with latest tuning",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270167, from = "Raid", note = "BiS Raid/M+ Trinket" },
            { id = 270169, from = "Raid", note = "BiS Raid Trinket - Look to macro/use on cooldown" },
        } },
        { label = "A", rank = 2, items = {
            { id = 270162, from = "Raid", note = "BiS M+ and 3rd best Raid Trinket" },
            { id = 270164, from = "Raid", note = "Top Tier Passive Stat Bonus Effects" },
        } },
        { label = "B", rank = 3, items = {
            { id = 251792, from = "Delves", note = "Excellent Delve Trinket, Best non-raid item" },
            { id = 248583, from = "Delves", note = "Very Strong Delve Trinket" },
            { id = 230639, from = "Delves", note = "PvP Item that is solid for PvE" },
            { id = 250214, from = "Mythic Plus", note = "Good passive proc effect. Ideal to stand in the small light patch" },
        } },
        { label = "C", rank = 4, items = {
            { id = 273649, from = "Mythic Plus", note = "Solid Haste On-Use Trinket. Look to use close to on cooldown with your cooldowns" },
            { id = 273796, from = "Mythic Plus", note = "Random stats, mediocre on use." },
            { id = 250215, from = "Mythic Plus", note = "Solid On-Use Trinket that was nerfed before Season start - Macro with Evangelism" },
            { id = 250255, from = "Mythic Plus", note = "Weak/Niche single-target absorb trinket" },
        } },
    },
}

ns.TrinketTiers["PRIEST_HOLY"] = {
    season = "Midnight Season 2",
    intro = "Updated August 17th with latest tuning!",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270162, from = "Raid", note = "BiS for Raid/M+ - Channel to create shields" },
            { id = 270164, from = "Raid", note = "BiS Trinket, High Stat procs" },
        } },
        { label = "A", rank = 2, items = {
            { id = 270167, from = "Raid", note = "High statted, even with Haste being low value for HPriest" },
            { id = 270169, from = "Raid", note = "High value trinket, ideally using with Apotheosis or Hymn" },
            { id = 250214, from = "Mythic Plus", note = "Best Dungeon Trinket, Excellent Stats. Ideal to stand in the field if possible" },
            { id = 250215, from = "Mythic Plus", note = "Strong Crit bonus, pair with Hymn/Apoth" },
        } },
        { label = "B", rank = 3, items = {
            { id = 248583, from = "Delves", note = "Strong Delve Trinket" },
            { id = 251792, from = "Delves", note = "Delve Trinket with very high stats" },
        } },
        { label = "C", rank = 4, items = {
            { id = 230639, from = "Delves", note = "Solid Stat buff" },
            { id = 250255, from = "Mythic Plus", note = "Niche Single-Target Shield Trinket" },
            { id = 273649, from = "Mythic Plus", note = "On-Use Haste, worst stat for Holy" },
            { id = 273796, from = "Mythic Plus", note = "Poor Statted, and Random stats at that" },
        } },
    },
}

ns.TrinketTiers["PRIEST_SHADOW"] = {
    season = "Midnight Season 2",
    intro = "Trinkets in Season 2 of Midnight are in a pretty dire place right now, with very few standing up to what was on offer in Season 1 even despite the increase in item level. As always Shadow is looking for a strong stat based proc trinket and a stat based on use trinket. If a trinket is not mentioned on this list it is because it is so poor as to not be worth considering.",
    tiers = {
        { label = "A", rank = 1, items = {
            { id = 250215, from = "Mythic Plus", note = "One of Shadow's two on use trinket options. This one offers crit every 90 seconds which should be paired with Voidform and Power Infusion." },
            { id = 273796, from = "Mythic Plus", note = "Shadow's other on use trinket. This one offers random stats every 90 seconds to be paired with Voidform and Power Infusion." },
            { id = 270167, from = "Raid", note = "Shadow's other strongest passive trinket. Tied with Gebbos." },
            { id = 270164, from = "Raid", note = "Shadow's best passive trinket tied with seastone. Solid overall stats." },
        } },
        { label = "B", rank = 2, items = {
            { id = 270169, from = "Raid", note = "The 3rd option for an on use trinket. This one has potential to be extremely valuable due to its burst profile but overall is a little weaker than the dungeon options." },
            { id = 250214, from = "Mythic Plus", note = "Another passable option. This time offering flat mastery and an additional bonus if you can stand still in the beam." },
        } },
        { label = "C", rank = 3, items = {
            { id = 248583, from = "Delves", note = "Though unavailable at Myth track, this trinket at hero is equal to those in B until you have access to Mythic trinkets." },
            { id = 251792, from = "Delves", note = "Though unavailable at Myth track, this trinket at hero is equal to those in B until you have access to Mythic trinkets." },
        } },
        { label = "D", rank = 4, items = {
            { id = 249343, from = "Raid", note = "Shadow's stronges trinket from season 1. At 298 ilvl this trinket beats everything else in D or below at heroic ilvl. You will struggle to replace this trinket initially if you have it." },
            { id = 250224, from = "Mythic Plus", note = "These four new trinkets in D are a step below the others at heroic ilvl, but can be acquired at Mythic. You should not try to acquire them at mythic ilvl." },
            { id = 193757, from = "Mythic Plus", note = "These four new trinkets in D are a step below the others at heroic ilvl, but can be acquired at Mythic. You should not try to acquire them at mythic ilvl." },
            { id = 270170, from = "Mythic Plus", note = "These four new trinkets in D are a step below the others at heroic ilvl, but can be acquired at Mythic. You should not try to acquire them at mythic ilvl." },
            { id = 270161, from = "Raid", note = "These four new trinkets in D are a step below the others at heroic ilvl, but can be acquired at Mythic. You should not try to acquire them at mythic ilvl." },
        } },
        { label = "F", rank = 5, items = {
            { id = 270168, from = "Raid", note = "This trinket is abysmally bad, even accounting for their higher item level. Luckily by rolling on this boss in Holy loot spec you can completely avoid this one." },
        } },
    },
}

ns.TrinketTiers["ROGUE_ASSASSINATION"] = {
    season = "Midnight Season 2",
    intro = "For trinkets, Assassination is mostly looking for items that will grant either on-use stats, or strong passive stats. A strong on-use is always desireable to push more damage into your cooldowns, and can be macro'd to your cooldowns.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270175, from = "Raid", note = "Higher item level due to dropping from Ula'tek, and a great on-use" },
            { id = 270168, from = "Raid", note = "Font is the strongest single AoE trinket available. It is not worth seeking out for boss damage or raid damage, but adds a large amount of burst if there are stacked enemies. Due to the multiple damage amp effects in the raid, stacked cleave/aoe, and many add spawns that are part of the encounters, this is reasonably the best practical trinket." },
        } },
        { label = "A", rank = 2, items = {
            { id = 193701, from = "Mythic Plus", note = "Season 2 trinkets as a whole are really bad, and so you will want to use your Season 1 puzzle box until you can get a roughly 324 item level, a.k.a 6/6 hero track Voracious Heart of Ula'tek." },
            { id = 270165, from = "Raid", note = "A decent haste proc that can be used as a second trinket, especially in situations with less adds were Font of Venomous Rage might not be ideal." },
            { id = 270173, from = "Raid", note = "Guillotine is a trinket that is only good in 1-2 target cleave. Due to the fact that Assassination Rogues cannot complete the set effect, the Guillotine doesn't scale with more targets, making it quite weak in higher target cleave and mythic+ situations" },
            { id = 270164, from = "Raid", note = "Gebbo's is a very strong passive trinket granting a good amount of secondary stats, but gets outshined by at least one other trinket depending on situation. A good all-around option if you do not want to swap trinkets" },
        } },
        { label = "B", rank = 3, items = {
            { id = 159617, from = "Mythic Plus", note = "The strongest non-raid on-use trinket available" },
            { id = 250215, from = "Mythic Plus" },
            { id = 250228, from = "Mythic Plus" },
            { id = 273796, from = "Mythic Plus" },
            { id = 250225, from = "Mythic Plus", note = "A usable on-use trinket as well if Voracious Heart isn't available to you" },
            { id = 270166, from = "Raid" },
            { id = 250259, from = "Mythic Plus", note = "After some further testing and comparisons, the Sapling that spawns from this seems much weaker than first thought, making it just okay or even unwanted." },
        } },
        { label = "C", rank = 4, items = {
            { id = 193757, from = "Mythic Plus" },
            { id = 273797, from = "Mythic Plus" },
            { id = 250214, from = "Mythic Plus", note = "Sims incredibly high, but requires the user to stand in a beam of light to receive effects. Nearly impossible to play around in actual gameplay, which makes it unusable." },
        } },
        { label = "D", rank = 5, items = {
            { id = 158374, from = "Mythic Plus" },
            { id = 250462, from = "Delves" },
            { id = 250245, from = "Mythic Plus" },
            { id = 251783, from = "Delves" },
            { id = 251782, from = "Delves" },
            { id = 251792, from = "Delves" },
            { id = 251791, from = "Delves" },
            { id = 251787, from = "Delves" },
            { id = 251784, from = "Delves" },
            { id = 251785, from = "Delves" },
            { id = 280123, from = "Delves" },
            { id = 274496, from = "Delves" },
            { id = 274497, from = "Delves" },
            { id = 274493, from = "Delves" },
        } },
    },
}

ns.TrinketTiers["ROGUE_OUTLAW"] = {
    season = "Midnight Season 2",
    intro = "With the spec lacking a major cooldown, our best trinket options are mostly passive trinkets, unless they are extremely over-budgeted.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270173, from = "Raid", note = "An extremely strong passive trinket that works great with our already BiS weapon." },
            { id = 270175, from = "Raid", note = "Despite Outlaw not usually wanting an on use trinket, this trinket is very over-budgeted. It might be a highly contested trinket, but you will want to grab one eventually." },
            { id = 270164, from = "Raid", note = "The textbox sounds gimmicky but this is a very high uptime stat buff trinket." },
            { id = 270165, from = "Raid", note = "Another good passive trinket option. This one shouldn't be as highly contested, so grabbing this at a higher ilvl could be a good choice." },
        } },
        { label = "A", rank = 2, items = {
            { id = 159617, from = "Mythic Plus" },
            { id = 273796, from = "Mythic Plus" },
            { id = 250225, from = "Mythic Plus" },
            { id = 250214, from = "Mythic Plus" },
            { id = 250215, from = "Mythic Plus" },
        } },
        { label = "B", rank = 3, items = {
            { id = 273797, from = "Mythic Plus" },
            { id = 250228, from = "Mythic Plus" },
            { id = 158374, from = "Mythic Plus" },
        } },
        { label = "C", rank = 4, items = {
            { id = 193757, from = "Mythic Plus" },
            { id = 250245, from = "Mythic Plus" },
            { id = 270166, from = "Raid" },
        } },
        { label = "D", rank = 5, items = {
            { id = 250259, from = "Mythic Plus" },
            { id = 270168, from = "Raid" },
            { id = 250462, from = "Delves" },
            { id = 246305, from = "Crafting" },
            { id = 246304, from = "Crafting" },
            { id = 246306, from = "Crafting" },
            { id = 246307, from = "Crafting" },
            { id = 241340, from = "Crafting" },
            { id = 251783, from = "Delves" },
            { id = 251782, from = "Delves" },
            { id = 251792, from = "Delves" },
            { id = 251791, from = "Delves" },
            { id = 251787, from = "Delves" },
            { id = 251784, from = "Delves" },
            { id = 251785, from = "Delves" },
            { id = 274493, from = "Delves" },
            { id = 280123, from = "Delves" },
            { id = 274496, from = "Delves" },
            { id = 274497, from = "Delves" },
        } },
    },
}

ns.TrinketTiers["ROGUE_SUBTLETY"] = {
    season = "Midnight Season 2",
    intro = "Trinkets are fairly simple this season; we try to get Voracious Heart of Ula'tek and Zul'jin's Guillotine Technique from raid. The on-use trinket offers a noticeable main stat boost and lines up well with our cooldowns; we pair it with passive options, Gebbo's Bottomless Bag and Sapling of the Dawnroot are strong alternatives.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270175, from = "Raid", note = "The strongest trinket of the patch. The 90-second cooldown is ideal. Line it up with every Shadow Blades cast. The trinket can be put in a macro with Shadow Dance." },
            { id = 270173, from = "Raid", note = "The best Passive trinket option in the patch; the main downside is the single-target focus. This isn't a big problem in the raid, as most fights benefit from high-priority target damage. But we look at alternatives for Mythic+. The trinket also benefits from Find Weakness." },
        } },
        { label = "A", rank = 2, items = {
            { id = 270164, from = "Raid", note = "The best alternative to Zul'jin's Guillotine Technique, which works well with multiple targets too. This is the ideal passive option for mixed target fights or Mythic+." },
            { id = 270165, from = "Raid", note = "Solid passive trinket option. Haste is in general a good stat." },
            { id = 273797, from = "Mythic Plus" },
            { id = 250215, from = "Mythic Plus", note = "The cooldown lines up well with our major cooldowns, but it can't compete with the main stat from Heart. This is a solid option early on, but is unlikely to be used long term." },
        } },
        { label = "B", rank = 3, items = {
            { id = 250214, from = "Mythic Plus", note = "The trinket is a good passive option. The beams spawn close to you (within 6-8 yards) but are visually easy to miss. If you play this trinket, pay attention to your surroundings to benefit from the beams." },
            { id = 270166, from = "Raid" },
            { id = 250259, from = "Mythic Plus" },
            { id = 159617, from = "Mythic Plus", note = "A strong on-use trinket, which sadly has a bad cooldown for Subtlety. Use the trinket as if it were a 3-minute trinket." },
            { id = 251785, from = "Mythic Plus" },
            { id = 270168, from = "Raid", note = "The trinket is generally not good because of the long cooldown. But could be valuable on certain fights where the burst lines up well with add spawns or to help with burst damage requirements." },
        } },
        { label = "C", rank = 4, items = {
            { id = 273796, from = "Mythic Plus", note = "The randomness and long cooldown make this trinket undesirable." },
            { id = 251792, from = "Delves" },
            { id = 250225, from = "Mythic Plus", note = "Another promising trinket which is sadly not good because of a two-minute cooldown timer." },
            { id = 193757, from = "Mythic Plus", note = "This trinket needs to be trained to be good; the pure damage effects seem weak. But the stat procs both seem potent. Train for either Haste or Critical Strike. The trinket needs 6 days to fully train. If you want to be flexible, you can train 4 days of Haste and 2 days of Critical Strike. You can train your dragon by targeting yourself and using the trinket. If you have 3 or more allies nearby, you gain one rank in Haste; if you have fewer than 3, you gain one rank in Critical Strike. The total of training ranks you can have is 6; using the trinket again on the 7th day replaces the training from the first day. (You are done by training it 6 days in a row)" },
            { id = 274493, from = "Delves" },
            { id = 158374, from = "Mythic Plus" },
            { id = 250228, from = "Mythic Plus" },
            { id = 248583, from = "Delves" },
        } },
        { label = "D", rank = 5, items = {
            { id = 265657, from = "Delves" },
            { id = 251783, from = "Raid" },
            { id = 246304, from = "Crafting", note = "Crafting Trinkets fall short in comparison to other trinket options and should not be considered. The raid offers multiple strong trinket options which don't compete with your crafting budget." },
            { id = 241340, from = "Crafting", note = "Crafting Trinkets fall short in comparison to other trinket options and should not be considered. The raid offers multiple strong trinket options which don't compete with your crafting budget." },
            { id = 246305, from = "Crafting", note = "Crafting Trinkets fall short in comparison to other trinket options and should not be considered. The raid offers multiple strong trinket options which don't compete with your crafting budget." },
            { id = 246306, from = "Crafting", note = "Crafting Trinkets fall short in comparison to other trinket options and should not be considered. The raid offers multiple strong trinket options which don't compete with your crafting budget." },
            { id = 246307, from = "Crafting", note = "Crafting Trinkets fall short in comparison to other trinket options and should not be considered. The raid offers multiple strong trinket options which don't compete with your crafting budget." },
            { id = 274497, from = "Delves" },
            { id = 274496, from = "Delves" },
        } },
    },
}

ns.TrinketTiers["SHAMAN_ELEMENTAL"] = {
    season = "Midnight Season 2",
    intro = "A lot of Elemental's damage is condensed into their Ascendance, which synergizes well with on-use trinkets to line up with the cooldowns 2 or 3 minute cooldown. The second trinket is usually more consistent and preferably provides Intellect, Critical Strike or Haste.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 273796, from = "Mythic Plus", note = "This is the best on-use trinket on average, but suffers from the fact that it gives a random stat which means it has high variance." },
            { id = 250215, from = "Mythic Plus", note = "A more consistent on-use trinket. On average this is slightly weaker than the vial but performs reasonably close." },
            { id = 270164, from = "Raid", note = "Best consistent option. Even though this is a high variance option because of the random stats being chosen and stats being so imbalanced, this still works out better than all alternatives." },
        } },
        { label = "A", rank = 2, items = {
            { id = 270167, from = "Raid", note = "Second best consistent trinket. Usually not worth to play around but if there is nothing else to hold your cooldowns for, feel free to track the stacks." },
            { id = 250214, from = "Mythic Plus", note = "While this is a good alternative for the consistent trinket slot, this trinket is really annoying to use and play around. Generally would advise against it, even if it sims high." },
        } },
        { label = "B", rank = 3, items = {
            { id = 246304, from = "Crafting" },
            { id = 250259, from = "Mythic Plus" },
            { id = 270170, from = "Raid" },
            { id = 250224, from = "Mythic Plus" },
            { id = 273649, from = "Mythic Plus" },
        } },
        { label = "C", rank = 4, items = {
            { id = 246305, from = "Crafting" },
            { id = 270161, from = "Raid" },
            { id = 273794, from = "Mythic Plus" },
            { id = 193757, from = "Mythic Plus" },
        } },
        { label = "D", rank = 5, items = {
            { id = 270169, from = "Raid" },
            { id = 270168, from = "Raid" },
            { id = 158368, from = "Mythic Plus" },
            { id = 246306, from = "Crafting" },
            { id = 241340, from = "Crafting" },
        } },
    },
}

ns.TrinketTiers["SHAMAN_ENHANCEMENT"] = {
    season = "Midnight Season 2",
    intro = "Much like in Season 1, both Stormbringer and Totemic still have very intense burst windows, so it always seeks to have one on-use trinket to go with their respective cooldowns - Ascendance or Doom Winds. Since on-use trinkets share a cooldown, we then fill out the other slot with the strongest passive effect or proc available in the season.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270175, from = "Raid" },
            { id = 270173, from = "Raid" },
            { id = 270164, from = "Raid" },
        } },
        { label = "A", rank = 2, items = {
            { id = 273796, from = "Mythic Plus" },
            { id = 270165, from = "Raid" },
            { id = 250225, from = "Mythic Plus" },
            { id = 250228, from = "Mythic Plus" },
        } },
        { label = "B", rank = 3, items = {
            { id = 250215, from = "Mythic Plus" },
            { id = 250214, from = "Mythic Plus" },
            { id = 159617, from = "Mythic Plus" },
            { id = 248583, from = "Delves" },
            { id = 251792, from = "Delves" },
            { id = 270166, from = "Raid" },
        } },
        { label = "C", rank = 4, items = {
            { id = 270168, from = "Raid" },
            { id = 265657, from = "Delves" },
            { id = 274493, from = "Delves" },
            { id = 250259, from = "Mythic Plus" },
            { id = 158374, from = "Mythic Plus" },
            { id = 273797, from = "Mythic Plus" },
        } },
        { label = "D", rank = 5, items = {
            { id = 251785, from = "Delves" },
            { id = 274496, from = "Delves" },
            { id = 274497, from = "Delves" },
            { id = 246304, from = "Crafting" },
            { id = 241340, from = "Crafting" },
        } },
        { label = "F", rank = 6, items = {
            { id = 251784, from = "Delves" },
            { id = 251783, from = "Delves" },
            { id = 246306, from = "Crafting" },
            { id = 246307, from = "Crafting" },
            { id = 246305, from = "Crafting" },
        } },
    },
}

ns.TrinketTiers["SHAMAN_RESTORATION"] = {
    season = "Midnight Season 2",
    intro = "The best options this tier all come from the raid. There are very competitive alternatives from M+ but ideally you want to raid for the best trinkets. Soulcoiler Ritual Vessel is a bit of a special case in that on top of being very strong numbers wise it is also a very good healing format. Shields on demand are very good specially on M+ dungeons.\n\nYour ideal set up would have Soulcoiler Ritual Vessel and then either Gebbo's Bottomless Bag or Wavecaller's Seastone. Hex Lord's Dooming Idol is also very good but the issue is that pairing two active trinkets together can result in annoyances when trying to use them. The way Hex Lord's Dooming Idol works you usually want to press it almost on cooldown which means you have some limited windows where Soulcoiler Ritual Vessel won't be on cooldown from the shared trinket cd.\n\nRuby Whelp Shell is your best alternative from M+ but it requires you to spend 6 days training it. You can check the item page for more information on how training works and you want to train it for the critical strike buff, but the trinket does fall off considerably in power if you don't have it properly trained.\n\nDrum of Renewed Bonds and Glorious Crusader's Keepsake can be very good options as acquiring them on hero-track is relatively easy if you complete the delve journey for the season. For both of them you want them to proc critical strike.\n\nTo pick the best alternative between the options you have available, it is always recommended that you use Questionably Epic Live. The tool will consider all your available options and give you the most optimal suggestion from what you currently have.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270162, from = "Raid" },
            { id = 270164, from = "Raid" },
            { id = 270167, from = "Raid" },
            { id = 270169, from = "Raid" },
        } },
        { label = "A", rank = 2, items = {
            { id = 193757, from = "Mythic Plus" },
            { id = 250215, from = "Mythic Plus" },
            { id = 248583, from = "Delves" },
            { id = 251792, from = "Delves" },
            { id = 250255, from = "Mythic Plus" },
        } },
        { label = "B", rank = 3, items = {
            { id = 250214, from = "Mythic Plus" },
            { id = 273796, from = "Mythic Plus" },
        } },
        { label = "C", rank = 4, items = {
            { id = 250248, from = "Mythic Plus" },
        } },
        { label = "D", rank = 5, items = {
            { id = 273649, from = "Mythic Plus" },
            { id = 270171, from = "Raid" },
            { id = 250254, from = "Mythic Plus" },
        } },
        { label = "F", rank = 6, items = {
            { id = 193748, from = "Mythic Plus" },
            { id = 264701, from = "Delves" },
        } },
    },
}

ns.TrinketTiers["WARLOCK_AFFLICTION"] = {
    season = "Midnight Season 2",
    intro = "Affliction Warlock has a handful of powerful Equip and On-Use trinket options in 12.1. The unfortunate part is that some of the most \"powerful\" options are from dungeons, which means they will likely need to be coined for Myth track.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270164, from = "Raid", note = "Very Strong Passive Trinket option wanted by most DPS." },
            { id = 273649, from = "Mythic Plus", note = "Our strongest on-use trinket. Does have a 2 second channel time before full value is gained." },
            { id = 273796, from = "Mythic Plus", note = "A strong on-use option that can be farmed in Altar of Fangs." },
            { id = 270167, from = "Raid", note = "Another very Strong Passive Trinket option that comes from the Lair boss, may be splittable." },
        } },
        { label = "A", rank = 2, items = {
            { id = 250214, from = "Mythic Plus" },
            { id = 270170, from = "Raid" },
            { id = 250259, from = "Mythic Plus" },
            { id = 250215, from = "Mythic Plus", note = "Another strong on-use option that can be farmed in Murder Row." },
        } },
        { label = "B", rank = 3, items = {
            { id = 250224, from = "Mythic Plus" },
            { id = 270169, from = "Raid" },
            { id = 193757, from = "Mythic Plus" },
        } },
        { label = "C", rank = 4, items = {
            { id = 270161, from = "Raid" },
            { id = 273794, from = "Mythic Plus" },
            { id = 274493, from = "Delves" },
            { id = 251792, from = "Delves" },
        } },
        { label = "D", rank = 5, items = {
            { id = 251786, from = "Delves" },
            { id = 274497, from = "Delves" },
            { id = 274496, from = "Delves" },
        } },
    },
}

ns.TrinketTiers["WARLOCK_DEMONOLOGY"] = {
    season = "Midnight Season 2",
    intro = "Demonology Warlock has a handful of powerful Equip and On-Use trinket options in 12.1. The unfortunate part is that some of the most \"powerful\" options are from dungeons, which means they will likely need to be coined for Myth track.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270164, from = "Raid", note = "The best passive trinket, highly contested." },
            { id = 273796, from = "Mythic Plus", note = "Our best on-use trinket, can be farmed since it coems from Murder Row." },
        } },
        { label = "A", rank = 2, items = {
            { id = 270167, from = "Raid", note = "Another strong passive based trinket, drops from Lair boss." },
            { id = 250215, from = "Mythic Plus", note = "The second best on-use option, however does desync with cooldowns." },
            { id = 250214, from = "Mythic Plus" },
            { id = 270170, from = "Raid" },
            { id = 250259, from = "Mythic Plus" },
        } },
        { label = "B", rank = 3, items = {
            { id = 273649, from = "Mythic Plus" },
            { id = 250224, from = "Mythic Plus" },
            { id = 270169, from = "Raid" },
            { id = 193757, from = "Mythic Plus" },
        } },
        { label = "C", rank = 4, items = {
            { id = 270161, from = "Raid" },
            { id = 273794, from = "Mythic Plus" },
            { id = 274493, from = "Delves" },
            { id = 251792, from = "Delves" },
        } },
        { label = "D", rank = 5, items = {
            { id = 251786, from = "Delves" },
            { id = 274497, from = "Delves" },
            { id = 274496, from = "Delves" },
        } },
    },
}

ns.TrinketTiers["WARLOCK_DESTRUCTION"] = {
    season = "Midnight Season 2",
    intro = "Destruction Warlock has a handful of powerful Equip and On-Use trinket options in 12.1. The unfortunate part is that some of the most \"powerful\" options are from dungeons, which means they will likely need to be coined for Myth track.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270164, from = "Raid", note = "Very Strong Passive Trinket option wanted by most DPS." },
            { id = 270167, from = "Raid", note = "Another very Strong Passive Trinket option that comes from the Lair boss, may be splittable." },
            { id = 250215, from = "Mythic Plus", note = "Super strong farmable trinket. The cooldown of 1.5m fits perfectly with Infernal, and we scale very well with crit." },
        } },
        { label = "A", rank = 2, items = {
            { id = 250214, from = "Mythic Plus" },
            { id = 270170, from = "Raid" },
            { id = 250259, from = "Mythic Plus" },
        } },
        { label = "B", rank = 3, items = {
            { id = 273796, from = "Mythic Plus" },
            { id = 273649, from = "Mythic Plus" },
            { id = 250224, from = "Mythic Plus" },
            { id = 270169, from = "Raid" },
            { id = 193757, from = "Mythic Plus" },
        } },
        { label = "C", rank = 4, items = {
            { id = 270161, from = "Raid" },
            { id = 273794, from = "Mythic Plus" },
            { id = 274493, from = "Delves" },
            { id = 251792, from = "Delves" },
        } },
        { label = "D", rank = 5, items = {
            { id = 251786, from = "Delves" },
            { id = 274497, from = "Delves" },
            { id = 274496, from = "Delves" },
        } },
    },
}

ns.TrinketTiers["WARRIOR_ARMS"] = {
    season = "Midnight Season 2",
    intro = "In the modern game, DPS trinkets tend to be very straightforward, as their damage is not affected by class damage buffs such as Avatar or Colossus Smash. Therefore, direct-damage dealing trinkets should be used on cooldown as often as possible, unless aligned with specific boss damage taken increasing mechanics. Stat-increasing trinkets should similarly either be used on cooldown or aligned with burst phases.\n\nIt's advised to reference Bloodmallet for a list of how each trinket performs at various item levels, but here are the important trinkets to be aware of:",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270173, from = "Raid", note = "Forms a set with the matching weapon" },
            { id = 270175, from = "Raid", note = "large active buff" },
            { id = 270164, from = "Mythic Plus", note = "strong but RNG" },
        } },
        { label = "A", rank = 2, items = {
            { id = 273796, from = "Raid", note = "difficult to juggle two on use" },
            { id = 250259, from = "Mythic Plus", note = "strong, but pets can be unreliable" },
            { id = 250228, from = "Raid", note = "passive crit buff" },
            { id = 270165, from = "Raid", note = "passive haste buff" },
        } },
        { label = "B", rank = 3, items = {
            { id = 250238, from = "Mythic Plus", note = "difficult to juggle two on use" },
            { id = 250229, from = "Raid", note = "passive strength buff" },
            { id = 193757, from = "Mythic Plus", note = "strong, but requires tedious training" },
            { id = 193762, from = "Mythic Plus", note = "difficult to time effectively" },
        } },
        { label = "C", rank = 4, items = {
            { id = 270168, from = "Mythic Plus", note = "potentially bursty but has a very awkward cooldown" },
            { id = 273797, from = "Mythic Plus", note = "potentially useful if defeating a lot of enemies, but very niche" },
            { id = 270163, from = "Mythic Plus", note = "too rng" },
            { id = 273795, from = "Mythic Plus", note = "damage on use is mediocre" },
        } },
    },
}

ns.TrinketTiers["WARRIOR_FURY"] = {
    season = "Midnight Season 2",
    intro = "In the modern game, DPS trinkets tend to be very straightforward, as their damage is not affected by class damage buffs such as Avatar or Enrage. Therefore, direct-damage dealing trinkets should be used on cooldown as often as possible, unless aligned with specific boss damage taken increasing mechanics. Stat-increasing trinkets should similarly either be used on cooldown or aligned with burst phases.\n\nIt's advised to reference Bloodmallet for a list of how each trinket performs at various item levels, but here are the important trinkets to be aware of:",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270173, from = "Raid", note = "Forms a set with the matching weapon" },
            { id = 270175, from = "Raid", note = "large active buff" },
            { id = 270164, from = "Mythic Plus", note = "strong but RNG" },
        } },
        { label = "A", rank = 2, items = {
            { id = 273796, from = "Raid", note = "difficult to juggle two on use" },
            { id = 250259, from = "Mythic Plus", note = "strong, but pets can be unreliable" },
            { id = 250228, from = "Raid", note = "passive crit buff" },
            { id = 270165, from = "Raid", note = "passive haste buff" },
        } },
        { label = "B", rank = 3, items = {
            { id = 250238, from = "Mythic Plus", note = "difficult to juggle two on use" },
            { id = 250229, from = "Raid", note = "passive strength buff" },
            { id = 193757, from = "Mythic Plus", note = "strong, but requires tedious training" },
            { id = 193762, from = "Mythic Plus", note = "difficult to time effectively" },
        } },
        { label = "C", rank = 4, items = {
            { id = 270168, from = "Mythic Plus", note = "potentially bursty but has a very awkward cooldown" },
            { id = 273797, from = "Mythic Plus", note = "potentially useful if defeating a lot of enemies, but very niche" },
            { id = 270163, from = "Mythic Plus", note = "too rng" },
            { id = 273795, from = "Mythic Plus", note = "damage on use is mediocre" },
        } },
    },
}

ns.TrinketTiers["WARRIOR_PROTECTION"] = {
    season = "Midnight Season 2",
    intro = "Protection Warrior is extremely flexible when it comes to trinkets. We are open to a wide array of passive proc trinkets or powerful defensive trinkets.\nWe generally aim for one strong on-use and one passive proc. We love haste and primary stat, so as much of those as we can get on trinkets.",
    tiers = {
        { label = "S", rank = 1, items = {
            { id = 270164, from = "Raid", note = "Strong Trinket" },
            { id = 270173, from = "Raid", note = "Very Strong Trinket" },
            { id = 270175, from = "Raid" },
            { id = 270165, from = "Raid" },
            { id = 270168, from = "Raid" },
        } },
        { label = "A", rank = 2, items = {
            { id = 273796, from = "Mythic Plus" },
            { id = 270163, from = "Raid" },
            { id = 273797, from = "Mythic Plus" },
            { id = 158367, from = "Mythic Plus" },
            { id = 250259, from = "Mythic Plus" },
            { id = 250245, from = "Mythic Plus" },
            { id = 250229, from = "Mythic Plus" },
        } },
        { label = "B", rank = 3, items = {
            { id = 250228, from = "Mythic Plus" },
            { id = 273795, from = "Mythic Plus" },
            { id = 193762, from = "Mythic Plus" },
        } },
        { label = "C", rank = 4, items = {
            { id = 241340, from = "Crafting" },
            { id = 250238, from = "Mythic Plus" },
            { id = 193757, from = "Mythic Plus" },
        } },
        { label = "D", rank = 5, items = {
            { id = 246304, from = "Crafting" },
            { id = 246305, from = "Crafting" },
            { id = 246306, from = "Crafting" },
            { id = 246307, from = "Crafting" },
        } },
    },
}
