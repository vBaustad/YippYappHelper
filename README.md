# YippYapp Helper

An all-in-one companion addon for **World of Warcraft: Midnight —
Season 2 (Curse of Ula'tek)**.

The goal is simple: **everything you'd normally alt-tab to a website for,
available in-game.** Gear upgrade advice, what drops where and whether
it's actually an upgrade, trinket sim rankings, keystone planning,
consumables, and dungeon teleports — in one window.

---

## Season 2 at a glance

| | |
|---|---|
| Patch 12.1 live | **11 Aug 2026** (12 Aug EU) |
| Season 2 starts | **18 Aug 2026** — one week later |
| Raid | The Venomous Abyss (8 bosses) |
| New dungeon | Altar of Fangs (3 bosses) |
| Lair | The Tidebound Grotto — counts toward the **Raid** vault row |
| Upgrade currency | Mistcrests (Dawncrests are Season 1) |

Keys, Bountiful Delves, the raid and the M+ season all gate on the
**18th**, not on patch day.

### Gear tracks

Season 2 tracks are perfectly regular — each starts four rungs up a
shared ladder and runs six ranks, so every track overlaps the next by
exactly **2 free ranks** (Veteran was 1 in Season 1).

| Track | Item levels | Crest |
|---|---|---|
| Adventurer | 266 – 282 | Adventurer Mistcrest |
| Veteran | 279 – 295 | Veteran Mistcrest |
| Champion | 292 – 308 | Champion Mistcrest |
| Hero | 305 – 321 | Hero Mistcrest |
| Myth | 318 – 334 | Myth Mistcrest |

Above that sit Ascended Hero (328), Ascended Myth (341, the "Myth 8"
cap) and **Myth 9 (344)** for Very Rare items and the last two Mythic
bosses. Upgrades cost a flat 20 crests per rank.

The headline change: a **Heroic raid vault slot is now a Myth 1/6
(318)**, and the Mythic vault always hands out a fully upgraded Myth 6/6
(334).

Drops land at different ranks depending on the content: **raids drop at
rank 4/6** of their track (Raid Finder 289, Normal 302, Heroic 315,
Mythic 328), while **dungeons walk up one rank per keystone step** from
Champion 1/6 at Mythic 0 to Hero 3/6 at +10 and above.

---

## Features

### Gear Upgrade Advisor
Per-slot verdicts — **Upgrade Now**, **Hold Crests**, **Save for Drop**,
**Free Upgrade** — weighing crest scarcity, slot priority, replacement
risk and track promotion. Auto-opens beside the upgrade vendor; click a
slot to send it straight into the upgrade UI.

### Loot Browser
Reads the Encounter Journal live, so it always matches the content
actually in your client.

- **Difficulty selector.** Pick the content level you actually run —
  Normal through M+12 for dungeons, Raid Finder through Mythic for raids.
  Every drop is priced at that difficulty, and the item tooltip follows,
  so the numbers you read match the content you're doing.
- **Grouped by boss.** Dungeon loot sits under a dungeon header with one
  row per boss (with portraits), the same shape raids use. Bosses with
  nothing for your current filter are hidden in dungeon view; raids list
  every boss so the pull order stays readable.
- **Upgrade marking.** Anything that beats your equipped piece gets a
  green `+13` badge (`new` if the slot is empty), with the full
  comparison, the upgrade rank ("Champion 3/6") and the Great Vault value
  in the tooltip. Paired slots (rings, trinkets, weapons) compare against
  the weaker of the two — the one you'd actually replace.
- **Myth 9 badges** on the penultimate and final raid bosses and on any
  Very Rare item, the only above-Myth-6/6 sources in the instance.
- **Favourites star** beside the slot dropdown — one click to filter to
  your starred items, with a count on the button.
- Class dropdown to inspect any class's loot table, slot and secondary-
  stat filters, and a distinct border for mount rewards.
- Icon borders show **item quality**, and housing decor and profession
  recipes are filtered out by item class.

The dungeon pool resolves from the live Mythic+ map table, so it follows
the season rollover instead of needing a code change.

> The Encounter Journal has no keystone loot table, so on M+ selections
> the linked item is the Mythic 0 version. Its item level and upgrade-rank
> lines are rewritten to the level you picked and tagged with it, rather
> than left contradicting the rest of the tooltip.

### Trinkets
SimulationCraft rankings from [bloodmallet.com](https://bloodmallet.com).

- **My Spec** — your trinkets ranked, each showing how far behind the
  best pick it sims.
- **Loot Council** — pick a trinket and see *every* spec that sims it,
  best rank first. The "only Frost DKs should roll on this" view.
- **Tooltip integration** — hover any trinket anywhere (loot window,
  bags, chat links, Encounter Journal) to see which specs want it and
  where it lands for you. Toggle in Settings → General → Trinkets.

Coverage is 29 of 40 specs; bloodmallet publishes no trinket data for the
six healer specs, nor for Augmentation, Brewmaster, Windwalker or
Assassination this tier.

### Mythic+ Helper
- Season 2 dungeon overview with clickable teleports.
- **Party-scoped** — always your 5-man, even with the raid frame up.
- Party rating grid, group keystones auto-synced via addon comms, Great
  Vault tracker, rating goals (2000 / 2500 / 3000) with focus dungeons.
- Guild keystones tab, refreshable on demand.
- `/yyhmplustest` fills the view with five dummy teammates so you can
  preview the layout solo.

### Mythic+ Completion Popup (BETA)
On keystone completion, shows your new rating and the party's new keys.
Click a row to teleport straight there.

### Utility Advisor (BETA)
On entering a mythic keystone, a compact window lists your class's
recommended utility spells for that dungeon plus a short mechanic note.
Gold border marks talent-dependent picks.

### Interrupt Tracker (BETA)
Party-wide kick cooldown bars, with a time-correlation attribution model
that works under Midnight's secret-value system. Class-coloured fills and
borders, icon mode, drag-to-move, and a multi-context visibility filter.

### Ready Check Window
Opens on every ready check. One row per raider:
Food · Flask · Vantus · Int · AP · Vers · Stam · Haste · Move · Durability %

Live-updates as buffs land, with a countdown and a compact toggle.
Optimised for 30-man raids — single-pass aura scanner, debounced
`UNIT_AURA`, coalesced durability comms.

### Raid Tools
Group roster by subgroup with role prefixes, composition counts, a
raid-buff strip (present lit, missing greyed), a consumable audit naming
who's missing flask/food/rune, and a tier-set piece scan.

### Battle Res Timer
Combat-res charges with cooldown swipe and countdown, driven by the
game's own brez pool. Shows in raid difficulties and keystones, hidden
where no pool exists. Draggable and scalable.

### Progression Reference
Item level and crest payout for every source: M+ keys, the raid by
difficulty and boss, delves, Trovehunter's Bounty, preys, world content,
crafting, Ascendant Venomstones and Great Vault rules.

### Consumables Guide
Enchants, gems, flasks, food and potions for all 40 specs, with the
guide text inline.

> Each spec records the season its guide was written for. Wowhead has not
> published Season 2 enchant/gem guides yet, so specs currently show a
> banner saying the advice is written for Season 1 — visible rather than
> silently stale.

### Omnium Folio
The five-week Rune chain from 12.0.7, tracked from your actual quest log
rather than a checklist you tick yourself.

- Progress bar and per-week status: done, in progress, or not started.
- Live objective text when a step is in your log ("3/8 Ritualized
  Arcana"), and a bag count when it isn't but you're already hoarding
  the drops.
- Where each step is done, who gives the quests (Magister Umbric, in the
  Lycaneum inside Magisters' Terrace), and **clickable coordinates** that
  drop a real map pin and super-track it.
- Hoverable item chips for the collectibles, with full item tooltips.
- A **Runes** tab listing all five rows and every choice, greyed until
  the week that unlocks them.

Its Runes last the rest of Midnight, so an unfinished Folio follows you
into Season 2 — which is why it gets its own page rather than a line on
the dashboard.

### Dungeon Teleports
Every Hero's Path teleport from MoP through Midnight, grouped by
expansion, with Season 2 first. Unlearned teleports are greyed out.

### Dashboard
Character bar, crest overview with weekly caps, an activity planner built
from your vault progress and crest headroom, and a farm guide for which
crests to chase and where.

### Mr. Yeeper
The dashboard's advisor. He reads your gear, crests, vault, keystones,
raid lockouts and guild activity, works out which single fact is worth
saying, and says it — rudely.

He is a reasoning layer rather than a quote list: a snapshot gathers
facts, rules recognise situations and compute, and the personality is
applied last to a conclusion already reached on evidence. Priority
decides what he says, so something actively being wasted always outranks
entertainment. Actionable messages carry tips underneath.

He is also aware of context that ought to change the joke:

- **Season phase.** Keystones go live a week after the patch, so in the
  first week he points at Mythic 0 and Heroic rather than at content that
  does not exist yet.
- **Whether you have a guild.** Remarks about never grouping with
  guildmates are gated behind actually having one with people in it —
  those lines are never generated rather than written and softened.

Jokes are sourced from the community
([Puns N Jokes](https://punsnjokes.com/world-of-warcraft/),
[LaffGaff](https://laffgaff.com/funny-wow-jokes/),
[PunOrbit](https://punorbit.com/wow-jokes/)) and keyed to your class,
race and level.

---

## Slash Commands

| Command | Description |
|---|---|
| `/yh` | Open the app (also `/yippyapp`) |
| `/yh help` | List all commands |
| `/yh mplus` | Open the Mythic+ page |
| `/yh raid` | Open raid tools |
| `/yh loot` | Open the loot browser |
| `/yh brez` | Battle Res Timer options |
| `/yh crests` | Show which Mistcrest currency ID resolved per track |
| `/yh profile [name]` | Switch profile (normal / heroic / mythic) |
| `/yh discount <track>` | Toggle a crest discount |
| `/yh discounts` | Show current discount status |
| `/yh whatsnew` | What changed this patch |
| `/yh advisor` | What Mr. Yeeper would say, plus the facts behind it |
| `/yh edit` | Open Edit Mode to move frames |
| `/yh fun` | Fun stat counters (`/yh fun reset` to clear) |
| `/yh debug` | Dump slot data to chat |
| `/yh lootdebug` | Loot Browser difficulty state and per-boss data |
| `/yh ejtest` | Probe the Encounter Journal's keystone item levels |
| `/keys`, `/yhkeys` | Open the Mythic+ page |
| `/yyhopts`, `/yyhsettings` | Open settings |
| `/yyhrc` | Preview the ready-check window |
| `/yyhmplustest` | Toggle M+ test mode (5 fake teammates) |
| `/yyhutility` | Preview the utility advisor |
| `/yyhmpluspopup` | Preview the M+ completion popup |
| `/yyhintlog` | Toggle interrupt debug logging |
| `/yyhintdebug` | Fire a fake interrupt cast |

### Settings
**Escape → Options → AddOns → YippYapp Helper**, or the Settings button
on the app header, or `/yyhopts`.

Built on Blizzard's own Settings API, so the controls are the game's —
including the Defaults button, keyboard navigation and options search.
One page: what each feature does and when it appears. Anything about how
a frame *looks* lives in Edit Mode instead, where you can see the change
as you make it.

### Edit Mode
Every movable frame — interrupt tracker, battle res timer, ready check
overview, Mythic+ summary and utility advisor — positions through
Blizzard's Edit Mode, with native selection outlines, grid snapping and
per-frame settings dialogs. Uses
[LibEditMode](https://github.com/p3lim-wow/LibEditMode), embedded.

Entering Edit Mode conjures each frame with sample content, since most
only exist during their own encounter and cannot be positioned otherwise.
A small panel beside the Edit Mode manager picks which ones appear.
Positions are stored per layout, so a raid layout and a solo layout can
place the same frame differently.

---

## Data provenance

Most of the addon reads live game APIs. Three things can't be, and are
generated instead:

| File | Source | Refresh |
|---|---|---|
| `Features/Consumables/ConsumablesData.lua` | Wowhead per-spec guides | `python Tools/scrape_consumables.py` |
| `Features/Trinkets/TrinketData.lua` | bloodmallet.com sims | `python Tools/scrape_trinkets.py` |
| Gear tracks, crests, progression tables | In-game currency descriptions + community sheets | Hand-verified per season |

Both scrapers record the season/tier their data came from, and the addon
says so in-game when that's behind the current season. Neither ships to
CurseForge — `Tools/` is excluded via `.pkgmeta` and `.gitignore`.

Gear track item levels were cross-checked against two independent
sources that agree exactly: the in-game Mistcrest currency descriptions
(e.g. Hero Mistcrest reads "up to item levels 308-321") and norumu's
community gearing sheet.

## Known gaps

- **Utility Advisor** has no entries for the Season 2 dungeons yet — they
  only finished PTR testing days before launch. It degrades gracefully
  until then.
- **Great Vault item levels** for dungeons and delves are estimates. The
  journal has no vault preview, so they can only be confirmed from the
  Great Vault UI once slots are filled.
- **Crafting item levels** in the progression tables are inferred and
  want verifying against the crafting order UI in-game.
- **Consumables and trinket data** are still Season 1 upstream; both
  surface a warning in-game and need a rescrape once updated.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full history. Latest:
**v2.12.0** — PTR shakedown: raid and dungeon item levels corrected
against the game, a difficulty selector for the Loot Browser, quality
borders, a favourites toggle, and fixes for Season 1 gear being offered
as upgradeable and the `/yh` macro failing to create.

## Feedback

Bug reports and feature requests welcome on the project page.
