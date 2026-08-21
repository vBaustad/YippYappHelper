# YippYapp Helper

An all-in-one companion addon for **World of Warcraft: Midnight —
Season 2 (Curse of Ula'tek)**.

The goal is simple: **everything you'd normally alt-tab to a website for,
available in-game.** Gear upgrade advice, what drops where and whether
it's actually an upgrade, trinket sim rankings, keystone planning,
consumables, and dungeon teleports — in one window.

Season 2 also moves every frame the addon owns into **Blizzard's Edit
Mode**.

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

### Best in Slot
Each spec's best-in-slot list from Wowhead's class guides, laid out as a
paper doll so the icons sit where the character panel puts them.

- **Bags count as collected.** Four states per slot: missing, sitting in
  your bags, owned at a lower rank, and owned at the target rank.
- Item level and upgrade rank come from the same gear-track data the Loot
  Browser uses, so the two pages cannot disagree.
- Items resolve through the Encounter Journal, so tooltips show the real
  item rather than its base entry.
- Stat priority per spec.

A guide is one opinion at one point in time. Sim your own character —
the page says so itself.

### Trinkets
SimulationCraft rankings from [bloodmallet.com](https://bloodmallet.com),
and healer rankings from [QE Live](https://questionablyepic.com/live/trinkets)
— bloodmallet sims damage and publishes nothing for the healing specs.

- **My Spec** — your trinkets ranked, each showing how far behind the
  best pick it sims, at the item level it was simmed at. Trinkets no
  longer share one item level: a crafted trinket caps lower than a raid
  drop, so each is ranked at its own ceiling, which is what bloodmallet's
  own chart does.
- **Scaling bars** — every row carries a bar split at each item level
  that trinket was simmed at. Length is the gain over an empty slot,
  each segment is what the next item level added, and hovering a segment
  gives the level, the gain and where the trinket drops. The rows are
  drawn to suit the width of the frame rather than leaving a wide window
  half empty — the same size in every view, so nothing resizes as you
  search or switch spec.
- **Item level stepper** — step through the item levels and the list
  re-ranks at each one, so you can see where two trinkets trade places
  rather than only which wins at its own ceiling. Only trinkets simmed
  at exactly that level appear; the top 15 per spec keep this detail.
- **Loot Council** — pick a trinket and see *every* spec that sims it,
  best rank first, at the item level it is ranked at — its own ceiling,
  the top of the Myth track for wherever it drops. The "only Frost DKs
  should roll on this" view. Lists
  this season's dungeon and raid drops only — crafted, PvP and older
  trinkets are left out, though they still answer a tooltip and
  **Show older trinkets** brings them back. bloodmallet keeps simming
  items from previous content; they are told apart by whether they have
  an upgrade ladder or sit at one fixed item level. Expanding a trinket
  separates the specs that have been re-simmed from the ones still
  awaiting it, so a spec nobody has asked yet does not read as a spec
  that passed. Damage specs and healers are listed under their own
  subheads, with yours first — their percentages divide by different
  things (a share of total DPS against a share of the best trinket's
  healing), so a single sorted column would rank by which project simmed
  you rather than by who wants the item.
- **Shortlist what you're after** — right-click any row to add or remove
  a trinket; shortlisted ones carry a star. It writes to the same list
  the Loot Browser's favourites star uses, so the two pages cannot
  drift. A shortlist rather than a slot assignment: when two trinkets
  are within a percent of each other, "I want this" is true of both and
  only one of them is going to drop.
- **Tooltip integration** — hover any trinket anywhere (loot window,
  bags, chat links, Encounter Journal) to see which specs want it and
  where it lands for you. Toggle in Settings → General → Trinkets.

Coverage is 38 of 40 specs: 31 from bloodmallet and the seven healers
from QE Live. Augmentation and Brewmaster are in neither.

The two sources measure different things — DPS against HPS — so nothing
compares a number from one with a number from the other; every ranking
is within one spec. QE splits by content rather than by target count, so
for a healer the two tabs read **Raid** and **Dungeon** instead of
single target and AoE, and the footer names whichever site the list on
screen came from.

bloodmallet re-sims a new season a few specs at a time, so the file holds
both while that runs. 21 of its 31 specs are fully on Season 2 numbers;
the other 10 keep a Season 1 ranking for at least one fight style rather
than being dropped, and say so in the list, on the loot council rows and
in the tooltip. This is per fight style — a spec can be Season 2 on
single target and Season 1 on 5-target.

### Mythic+ Helper
- Season 2 dungeon overview with clickable teleports.
- **Party-scoped** — always your 5-man, even with the raid frame up.
- Party rating grid, group keystones auto-synced via addon comms, Great
  Vault tracker, rating goals (2000 / 2500 / 3000) with focus dungeons.
- Guild keystones tab, refreshable on demand.
- `/yyhmplustest` fills the view with five dummy teammates so you can
  preview the layout solo.

### Mythic+ Completion Popup
On keystone completion, shows your new rating and the party's new keys.
Click a row to teleport straight there.

### Utility Advisor
On entering a mythic keystone, a compact window lists your class's
recommended utility spells for that dungeon plus a short mechanic note.
Gold border marks talent-dependent picks.

### Interrupt Tracker
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

### Dungeon Teleports
Every Hero's Path teleport from MoP through Midnight, filed under the
expansion its dungeon came from, with the current season shown first.
A dungeon brought back for a new season appears in both places and is the
same entry, so it cannot read as unlocked in one and locked in the other.
Unlearned teleports are greyed out.

### Dashboard
Character bar, crest overview with weekly caps, an activity planner built
from your vault progress and crest headroom, and a farm guide for which
crests to chase and where.

The character bar also carries a jump counter, which serves no purpose
whatsoever and is not going anywhere.

---

## Slash Commands

| Command | Description |
|---|---|
| `/yh` | Open the app (also `/yippyapp`) |
| `/yh help` | List the commands |
| `/yh shell <page>` | Open a specific page |
| `/yh settings` | Open the options panel (also `options`, `opts`) |
| `/yh skin [id]` | List or choose a skin |
| `/yh guide` | Boss guide for the current raid |
| `/yh test [panel]` | Show a pop-up window with sample content (`/yh test off` to dismiss) |
| `/yh brez` | Battle Res Timer options (also `battleres`) |
| `/yh edit` | Open Edit Mode to move frames |
| `/yh profile [name]` | Switch profile (normal / heroic / mythic) |
| `/yh discount <track>` | Toggle a crest discount |
| `/yh discounts` | Show current discount status |

Pages for `/yh shell`: `home`, `gear`, `bis`, `trinkets`, `consumables`,
`progression`, `loot`, `mythicplus`, `raid`, `teleports`, `delves`.

| Shortcut | Description |
|---|---|
| `/yhkeys` | Open the Mythic+ page |
| `/yyhopts` | Open settings |
| `/yyhmplustest` | Toggle M+ test mode (5 fake teammates) |
| `/yyhintlog` | Toggle interrupt debug logging |

### Developer commands

Deliberately absent from `/yh help` — these print the addon's working, not
anything a player needs.

| Command | Description |
|---|---|
| `/yh debug` | Crest and slot state dumped to chat |
| `/yh icon [size] [x] [y]` | Tune the minimap icon fit |
| `/yh editdebug` | Why a frame has no Edit Mode outline |
| `/yh ejdump [abilities]` | What the Encounter Journal calls these bosses |

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
| `Features/Trinkets/TrinketDataHealer.lua` | QE Live healer charts | capture with `Tools/qe_capture.js`, then `python Tools/scrape_healer_trinkets.py` |
| `Features/Raid/RaidGuideData.lua` | mythictrap.com (Warcraft Logs) for structure, spell IDs and per-difficulty changes; a PTR video walkthrough for tactics | Hand-written per boss |
| Gear tracks, crests, progression tables | In-game currency descriptions + community sheets | Hand-verified per season |

The raid guide is the one generated file whose *prose* is not generated.
mythictrap supplies the skeleton — which mechanics exist, which phase
each belongs to, the real spell ID for every one, and an explicit list
of what Heroic and Mythic change. Their wording is theirs and is not
reproduced; every sentence on the page is written here from the mechanic
being described. The spell IDs are what let the page draw the client's
own icon and the client's own tooltip, so the numbers a player reads
come from the game rather than from a guide that may have been written
against the PTR.

Both scrapers record the season/tier their data came from, and the addon
says so in-game when that's behind the current season. Neither ships to
CurseForge — `Tools/` is excluded via `.pkgmeta` and `.gitignore`.

Gear track item levels were cross-checked against two independent
sources that agree exactly: the in-game Mistcrest currency descriptions
(e.g. Hero Mistcrest reads "up to item levels 308-321") and norumu's
community gearing sheet.

## Known gaps

- **Utility Advisor** has no entries for the Season 2 dungeons yet.
  Wowhead's per-dungeon guides were still unpublished at launch, and the
  notes are only worth having if they are right — a wrong dispel type is
  worse than none. The dungeon list, map IDs and timers are already in
  place for when they land. It degrades gracefully until then.
- **Great Vault item levels** for delves are estimates. The journal has
  no vault preview, so they can only be confirmed from the Great Vault UI
  once slots are filled. The Mythic+ column is now sourced and correct —
  M9 previously claimed 318, which was wrong; Myth 1/6 starts at M10.
- **Crafting item levels** in the progression tables are inferred and
  want verifying against the crafting order UI in-game.
- **Trinket data** is mid-transition upstream: 17 specs have been
  re-simmed for Season 2, the rest still carry Season 1 rankings and are
  labelled as such in-game. Re-run the scraper as bloodmallet works
  through the roster — it merges, so a partial run updates what is
  published without dropping what is not.
- **Best in Slot and Consumables** are scraped from class guides, which
  lag tuning passes. Both say so on the page.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full history. Latest:
**v3.0.6** — Season 2 trinket sims for 17 specs, single target and
5-target, with five of them gaining an AoE list. Trinkets are now ranked
at their own item level rather than a shared one, because bloodmallet
stopped simming them over a common range; each row carries a hoverable
scaling bar, and a stepper re-ranks the list at any item level so you can
see where two trinkets trade places. Specs still waiting on a re-sim keep
their Season 1 ranking instead of disappearing.

**v3.0.0** — Mr. Yeeper on the dashboard, a new Best in Slot page, every
movable frame migrated to Blizzard's Edit Mode, and settings rebuilt on
Blizzard's own Settings API. Also the fix that matters most: the addon
was reading the wrong crest currency, so every affordability and upgrade
number was computed against an empty wallet.

## Feedback

Bug reports and feature requests welcome on the project page.
