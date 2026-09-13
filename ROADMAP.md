# Roadmap

Ideas accepted but not built. Written down while the reasoning is fresh —
each entry should say enough that picking it up later does not mean
re-deriving whether it is possible.

---

## Weekly checklist: keeping the giver coordinates honest

**Status:** done and shipped. Kept here for the sourcing, because the
next person to touch these numbers needs to know where they came from.

Five rows ship a `giver` in `Features/Planner/WeeklyChecklist.lua`:
Lady Liadrin, Halduron Brightwing, Vereesa Windrunner, Archmage Aethas
Sunreaver (all uiMapID 2393, Silvermoon City) and Warleader Abdumati
(2509, Vaults of Atal'Utek).

### Where they came from, and why that was acceptable

Wowhead's `g_mapperData`, read off each NPC page on 2026-09-12. That is
datamined client data -- the same class as the class-guide tables -- not
the editorial prose beside it, which is the distinction that matters
against the rule about third-party sourcing.

Two things made it safe rather than a repeat of the invented teleport
ids:

- **The map id came with the data.** `g_mapperData` carries `uiMapId`
  itself, so nothing was inferred from a zone name. It was then
  confirmed a second time against a live client standing in Silvermoon,
  which is what settles it -- the published UiMapID lists are stale at
  patch 10.1.7 and still name 110, the pre-Midnight city.
- **Each NPC was reached through a quest id this addon already ships**
  (93751, 98172, 93598, 95520), not by searching a name. A wrong NPC
  would have to be a wrong quest id first.

### What stops them going stale badly

A learned record outranks a shipped one. Shipped is a snapshot from
build time; anything in the saved variables came off the player's own
client, so a giver that moves in a patch corrects itself the first time
anyone picks that quest up. `/yh where forget` goes back the other way.

`Tools/loadcheck.py` asserts the shape of every shipped giver -- a map
id, and a position strictly inside 0..1 -- because these are
hand-transcribed numbers and a percentage left unconverted does not
error, it just puts a pin somewhere wrong on every install. It also
requires that **every** quest-backed row ships one. "At least one"
passed on a page where eight rows out of nine had nothing to click,
which is the state this feature shipped in twice.

### Still unverified

`C_QuestLog.GetQuestsOnMap` including un-accepted offers with positions.
The map-scan seed uses it where it works and silently does nothing where
it does not; coordinates outside 0..1 are dropped rather than converted,
so the failure mode is no pin rather than a wrong one.

## Weekly checklist: quest ids instead of ticks

**Status:** plumbing built, ids missing. Blocked on one thing only, and that
thing has to come out of the game.

Asked for on CurseForge: a tree of the weekly quests you have not done,
grouped by zone. The tree is the wrong shape and the thing underneath it is
right — the weekly checklist should know which quests it is talking about
instead of asking you.

### Why not the tree

`Features/Planner/WeeklyChecklist.lua` states the membership test at the top
of `ITEMS`: *does skipping it this week cost you something you cannot get
back?* That test is why the list is seven lines instead of forty, and it is
written down there because an earlier version discovered rows instead of
naming them and filled with things nobody cared about. An expansion-wide zone
tree is the same mistake wearing a different hat — a collapsed node is still a
row to scroll past, and the reason this list gets read is that there is
nothing in it to scroll past.

### What is built

`questsDone` and a `quests = { ... }` field per row. `Wk:IsDone` consults it
ahead of both the bespoke `auto` checks and the player's own tick, because
where a quest id exists it is the client's record of this character's week and
outranks anything else on the page.

An empty list returns nil, meaning "nothing to go on", so a row with no id yet
keeps its manual tick and behaves exactly as it did before. That is the point
of the design: ids go in one at a time, and a row that has not been confirmed
is not a row that is wrong.

The list is a list rather than one id because a single chore is routinely
several — a quest with per-faction or per-zone variants, one Blizzard reissues
under a new id each patch, or a choice of three where doing any one is the
week done.

`Tools/loadcheck.py` drives all of it through a synthetic row: completed,
outstanding, second-id-in-the-list, empty list, and a stale manual tick losing
to a live flag. Deliberately not through a shipped row — those are empty until
someone confirms ids, so a check written against them would test nothing today
and break the day they are filled in.

### What the ids turned out to be

Read off Wowhead's own quest and item pages, and in one case off a Blizzard
statement. Three rows are settled and in the file:

```
spark        quests = { 98232, 98172, 93426, 96726 }
             98232 Midnight: Vaults of Atal'Utek   PvE meta
             98172 Trailing Xal'atath              PvE meta, Silvermoon
             93426 Sparks of War: Voidstorm        PvP, War Mode
             96726 Sparks of War: Naigtal          PvP, War Mode
vaultweekly  quests = { 95520 }  Purging the Vaults
bountymap    itemID = 274374     Trovehunter's Bounty. Fully automatic from
                                 the bag count AND 95520's flag together --
                                 earned this week and not in the bag means
                                 spent. Neither fact answers it alone, which
                                 is why this row was written off as
                                 half-trackable for longer than it deserved.
```

Two of the supplied ids were sub-steps of `95520` rather than rows of their
own and are unused: `96639` Patrolling the Temple and `96642` Decisive
Incursions. `96643` From Whence It Came is a daily and fails the membership
test outright.

### Two mistakes worth not repeating

**A reward list is not evidence.** `96995` Turn Back the Surge lists Spark of
Tides in its rewards and does not award one — Blizzard say it is a bug. It
was one edit from being written in as a confirmed source, on the strength of
that list.

**A catch-up bump is not the steady state.** Blizzard raised the weekly spark
maximum to four at the reset on 2026-08-18, as a one-off to level characters
that had picked up an unintended third. Reading that as the ongoing model
produced a whole counting mechanism — a second `questsAll` field, a
"2 of 4" row tag, and the harness to go with it — for a row that is a tick.
The real rule is one spark a week from any one source, taking it from one
closing the rest until the reset, which is what `quests` already expresses.
All of it came back out. Anything time-bounded to a single week does not
belong in a data table that has no concept of a date.

### Sparks: what is worth deriving, and what is not

Proposed: read the season's cumulative allowance from the week number, count
Sparks of Tides in the bags, find the Tidal Crafted gear the player is wearing
and add back what it cost, and report how many sparks they are owed.

The allowance half is cheap and correct. `ns.SEASON_PATCH_START` and the
`seasonWeek` derivation in `Features/Fun/Advisor.lua` already exist, and four
this week rising by one a week is a formula rather than a table.

**The spend half does not work, and it fails in the nagging direction.** A
gear scan sees equipped items and bags. It cannot see a crafted piece that has
since been replaced, vendored or disenchanted, one sitting on an alt, or
anything in void storage. So spent-sparks is a FLOOR, which makes acquired a
floor, which makes "you are owed N" an over-estimate. A player five weeks in
who has replaced two crafted pieces is told they are two sparks behind, every
week, permanently. That is the failure this whole design has been avoiding.

Two things would have to be settled before any of it could be trusted, and
both are load-bearing:

- **What a crafted item costs.** Wowhead's own reporting says two sparks for
  most items and four for a two-hander; the proposal says one and two. The
  ratio agrees and the multiplier does not, which smells like a whole-versus-
  fragment unit confusion. Every derived number doubles or halves on it.
- **Whether recrafting spends another spark.** If it does, one visible item
  can represent one spark or several and nothing distinguishes them.

Detection is the smaller problem but not free: "Tidal Crafted" is a tooltip
property, so finding it means tooltip scanning, which is locale-dependent. A
bonus id would be robust but has to be datamined.

**What is sound is also most of the value.** Two exact numbers, no inference:

- *Did you take this week's spark?* Quest flags, already answered correctly by
  the `spark` row.
- *How many can you spend right now?* `C_Item.GetItemCount` on 274476, which
  is exact. Include the account bank in the call -- the item is bind-on-pickup
  and the warband bank holds those, so a count that omits it under-reports.

Those two plus the allowance formula answer the question a player actually
has, which is not "how many have I earned" but "when can I craft the
two-hander". Holding is exact, the weekly flag is exact, and the arithmetic
between them needs no gear scan at all. Build that; leave the season total
alone.

### The two weekly-quest givers, and what they mean for three rows

Lady Liadrin (npc 256203) offers a **selection of four** "Midnight: ..."
quests each week, of which a character completes **one**. Sixteen variants
exist. Every one checked pays a Spark of Tides, which makes her weekly the
spark route for most players.

Archmage Aethas Sunreaver (npc 256212) also gives one weekly, from a
different and larger set -- the Timewalking "Path Through Time" quests, and
the Call to Delves / World Awaits / Emissary of War family. Checked two of
them and **neither pays a spark**, so his set is a separate chore, not a
spark route. Worth a decision on its own merits rather than folding in here.

Three consequences for the list, none of them safe to act on without a call:

- **`weeklyquest` is probably the spark row wearing a different hat.** "The
  recurring quest in the season's zone" was written before anyone knew what
  it referred to. It refers to the Liadrin weekly -- which is exactly what
  grants the spark, and the spark is the thing you cannot get back. Two rows
  for one action fails the list's own rule. Deleting `weeklyquest` and
  letting `spark` carry it is the tidier answer.
- **`prey` cannot become a quest row as it stands.** `93910` Midnight: Prey
  is one of Liadrin's sixteen, so it is only offered some weeks. Wired to
  that id the row would sit permanently unticked AND unclickable on every
  week it is not in the selection -- strictly worse than the manual tick it
  has now. It only survives as its own row if prey hunts carry a weekly cap
  independent of the meta quest, which is what its detail line claims and
  what nobody has confirmed.
- **A row per offered quest is not the answer either.** Four are offered and
  one is completable, so four rows would report three permanent failures.

### Cracked Keystone (92600) does not belong in the checklist

One-time, gated behind a level 11 delve, and it pays crests that do not count
against the weekly cap. Worth telling people about; wrong shape for this list.

The membership test at the top of `ITEMS` is *does skipping it this week cost
you something you cannot get back?* A one-time quest costs nothing this week
-- it is there next week too. As a checklist row it would either nag forever
on a character that has not done it or sit permanently ticked on one that
has, and neither is a weekly chore.

It wants a one-shot notice rather than a row: gate on
`IsQuestFlaggedCompleted(92600)` being false and it appears for someone who
has not done it and disappears for good the moment they do. That home used
to be Mr. Yeeper, who has been removed along with the pre-shell window he
lived in -- so this needs somewhere new before it can be built. The
shell's home page is the obvious candidate.

### Still open

```
prey         this week's prey hunts; nothing at all yet
weeklyquest  98172 is already in the spark row and is the strong candidate
             here too, so check first whether these are two chores or one.
             Wowhead marks 98172 Side: Alliance and no second quest of that
             name exists -- either the split is a datamining artefact or the
             Horde id is under another name.
```

### The zone half, if it is still wanted afterwards

`C_Map.GetBestMapForUnit("player")` gives the current map, and that map's group
sorts first. That is the whole of "changes with the zone you're in", and it
should be a sort key rather than a filter — someone in Valdrakken still needs
to see that the season's zone has one outstanding.

Grouping only earns its keep once there are enough rows to group. At seven,
group headers are chrome over a list that reads fine flat. Revisit if the list
grows.

### Names come from the client, not from us

If a row ever wants to name its quest rather than describe it,
`C_QuestLog.GetTitleForQuestID` returns the real localised title, and
`C_QuestLog.RequestLoadQuestByID` plus `QUEST_DATA_LOAD_RESULT` fills the cache
for a quest not currently in the log. Storing titles would mean shipping an
English list that goes stale on the first rename. Store the id; the zone is the
only fact about a quest that the client cannot hand back from an id alone.

---

## Editable Best in Slot list

**Status:** wanted, not started. Feasible.

Let the player put their own choice in a Best in Slot row, set from the Loot
Browser rather than edited on the page itself. The scraped guide stays as the
fallback for every slot the player has not overridden.

### Why it is worth doing

The list is scraped from Wowhead's class guides, and those are one opinion at
one point in time. Sims disagree, guides lag a tuning pass, and a player who
has actually simmed themselves knows better than the page does. Right now
their only options are to ignore the disagreement or ignore the page.

### Storage

Overrides keyed by spec, in SavedVariables:

```
YippYappHelperDB.bisOverrides[specKey][slot] = itemID
```

Per spec rather than per character — a second Balance Druid should inherit
the same considered choice.

They must survive `Features/Gear/ClassGuideData.lua` being regenerated,
which happens on every scrape. That means storing the item, not an index
into the guide's rows, and keeping an override whose slot no longer appears
in the guide rather than silently dropping it.

### Choosing the replacement: the Loot Browser, not a new picker

Do **not** build an item search into the Best in Slot page. The Loot Browser
is already a browsable, filtered, tooltip'd view of every item that drops
this season, grouped by boss and difficulty. Adding a second way to look at
the same data would mean maintaining two.

Instead, give a browser icon an **"Add as BiS"** action alongside the
existing favourite, and let it write the override. The Best in Slot page
then has no picker at all — it reads whatever has been set.

**Where it hooks.** `Features/Loot/LootBrowserUI.lua` around line 400: each
icon has an `OnClick` that calls `ns:ToggleLootFavorite(self.itemID)`, and
`RegisterForClicks("LeftButtonUp")` — so **right-click is unused and free**.
Right-click to set as BiS mirrors left-click to favourite, needs no modifier
key, and needs no new UI.

Mark it on the icon the way favourites already are: `favStar` is an overlay
texture plus a border tint (`PetJournal-FavoritesIcon`, gold). A second
marker in the same style, in the accent green the BiS page uses, reads as
the same kind of thing.

**Which slot it fills.** `GetItemInfoInstant` returns the item's equip
location, which maps to the guide's slot names — the reverse of `SLOT_INV`
in `BisUI.lua`. Rings and trinkets have two slots each, so those need either
a choice or a rule (fill the first free one, replace the older otherwise).

**Sources the browser cannot reach** — crafted gear, catalyst output, tier
tokens — still need a fallback. A pasted or shift-clicked item link gives an
itemID directly and is cheap to accept.

### Fallback, not replacement

The scraped guide list stays as the default. An override applies to **one
slot**; every slot without one keeps the guide's recommendation. That is
what makes this safe to ship: a player who never touches it sees exactly
what they see now, and the guide regenerating on the next scrape cannot
clobber choices that live in SavedVariables.

### Storage note

Favourites are keyed `YippYappHelperDB.lootFavorites[charKey][specID]` —
per character **and** per spec. Overrides are proposed per spec only, so a
second character of the same spec inherits the choice. That is a deliberate
difference and worth a moment's thought before building: matching the
favourites convention would be more consistent, and inheriting is more
useful. Pick one on purpose rather than by accident.

### What comes for free

Overrides only need to be applied where `AssignToSlots` reads the guide's
rows. Everything downstream already flows from that:

- the paper doll, the list, and the equipped/collected marks
- the "N / M collected" counter
- anything else counting collected pieces, since it all reads the same
  bag-aware path

So this is one insertion point, not a feature threaded through the page.

### Details worth not forgetting

- **Per-row revert and a reset-all.** An edited list with no way back is
  worse than no editing.
- **Show that a row is overridden.** A quiet marker, so a player does not
  later mistake their own choice for the guide's recommendation and report
  the guide as wrong.
- **Item level and rank still come from `maxRankIlvl`**, so an overridden
  row keeps its `Myth 6/6` label without special casing.
- The journal index is built lazily and throttled on failure — see
  `GetJournalItemLink`. A picker opening for the first time may need to
  handle "not indexed yet" rather than showing an empty list.

---

## Crest advice: rebuild around promotion, not per-rank greed

**Status:** part built. The drop band, promotion-aware planning and the
reason strings are in. What is left is listed under "Still missing" —
none of it blocks the rest, and each piece is independently useful.

The Improvements list told a +10 / Heroic-raid character to spend 160
Champion crests, in an order that put two rows under "Spend here first",
reported a 200-crest wallet as 160, and warned that one 302 trinket would be
overtaken while staying silent about a weapon in exactly the same position.
Chasing each of those found one engine that cannot express what it knows.

### The four structural causes

**The cascade means one fact per slot.** `ns:GetRecommendation` is nine rules
that return early, so which fact a slot gets to state depends on rule order,
not importance. `isFirst` returns at the top of rules 6-8 before the
`overtaken` branch three lines below is ever reached — which is exactly why
the weapon and the trinket, in identical positions, got opposite advice.

**Every wallet plans alone.** `GetCrestPlan` is per-track and the panel merges
by label, so five independent plans each contribute a "first" and a
priority-2 Wrist can outrank two priority-4 trinkets. *Half done:* each
lead now names its wallet ("Best Champion spend"), so the rows no longer
contradict each other. One global order across wallets is still open.

**Scarcity is declared, not derived.** `preciousCrests` / `freeCrests` are
static per-profile lists. The real income model — which content pays which
crest — is `ns.PROGRESSION.CREST_SOURCES`, and nothing reads it.

**Two ceilings disagree.** `GetDropCeiling` uses the raid track's entry level
and excludes the vault; `GetReplacementRisk` uses the raid track's max and
folds the vault in. So "will this stick" is judged against one number and "is
this slot at risk" against another, 10 item levels apart. *Worked around:*
the plan reads the band and no longer orders on risk at all, so the two
cannot contradict each other in the output. `GetReplacementRisk` is still
wrong and still feeds the reserve's at-risk count — reconcile it against
the band and the reserve gets a reachable live path again.

### The model that replaces it

**Score, don't cascade.** Every slot gets a score and a *set* of applicable
facts; the label comes from the score band and the reason names the one or
two facts moving it most. A row can then say "yes, but temporary" instead of
having to pick.

**Plan once, globally.** One order over all slots, annotated with which wallet
pays. Only one row can say "do this first".

**The drop band replaces the single ceiling.** *(built: `ns:GetDropBand`)* Two numbers, not one: the
lowest and highest item level the player's own content hands out. For a
Heroic / +10 character that is 305 (raid entry) and 311 (end of dungeon).
Three bands follow, and they are the whole scoring model:

| Band | A crest buys |
| --- | --- |
| below the low drop | rental stats only — the mark it sets is dead on arrival |
| between low and high | mark value: cashes in when the weaker source fills the slot |
| above the high drop | permanent item level |

`GetDropCeiling` already computes both numbers and throws the low one away.

**Rank 6 is a breakpoint, not a rank.** *(built: runs, `ns.PLAN_VALUE`,
`MarkRebate`)* — and the payoff is on the SLOT, not the item. An item does
not move onto the next track: a Champion piece at 6/6 is 308 and is
finished. What carries on is the slot's high-water mark, so the next Hero
piece to land there is lifted to 308 for free. The crests saved are Hero
crests, on an item the player does not own yet. Completing a track promotes the piece
onto the next track at rank 2 (`ns.TRACK_FREE_RANKS`, 2 ranks on every track
in Season 2), so finishing a track pre-pays 40 crests of the tier above. This
is the only crest conversion in the game — Vaskarn does not trade upward.

The plan walk bought **one rank at a time, re-picking the best slot after
each**, which is structurally incapable of saving toward a breakpoint. On the
panel that started this: 160 Champion bought one promotion and two trinkets
stranded mid-track. The unit of planning is now a *run* — every candidate
offers every run it could still buy, scored on value kept per crest, and the
best run wins whole. Runs are chosen whole but recorded rank by rank, so the
steps list, the running total and the paid/unpaid line are unchanged.
`Tools/loadcheck.py` pins the outcome on the original numbers: 200 Champion
carries Main Hand and Trinket 1 to the cap and puts the change on Trinket 2.

**Achievement for dead wallets, power for live ones.** These run at the same
time, not in sequence:

- A wallet whose track max sits under the drop floor can never buy a
  permanent item level. The "of the Mist" achievement is the only durable
  return left in it — chase completion, which flattens the set.
- A wallet at or above the drop floor should chase power: weapon, trinkets,
  tier. The achievement is far off and irrelevant.

Rule 5.5 chases the *lowest* missing achievement and breaks. But a 50%
discount is worth exactly the crests still to be spent on that track, so the
lowest missing one is usually the least valuable. Rank by remaining spend.

Neither half is built. `ns:IsCrestOutgrown` is the classifier they both want
and it already exists — it is what gates the reserve and what the "arrives as
overflow now" note reads.

**Overflow is the income model.** Capping a track pushes income down a tier,
so the fastest route to outgrowing Champion runs entirely through content
that never pays Champion. The advice is never "run M0s for Champion" — it is
"run the highest thing you can, cap top-down, spend what spills."

### Still missing

- ~~**No model of time.**~~ Built: `GetTrackCompletion` reads
  `CREST_WEEKLY_INCREMENT` and separates a shortfall inside this season's
  allowance (content not yet run) from one beyond it (resets). What it still
  cannot do is date an *outgrown* track, whose income is whatever spills out
  of a higher one capping — so it says the condition instead of inventing a
  week count.
- **The hover is where the reasoning lives; the page has none of it.** The
  row is one line and the tooltip carries the rest, but a player who never
  hovers sees only the verdict. The track's finish line — "3 pieces and you
  are done with Champion" — is the strongest sentence the addon produces and
  it is hidden behind a mouse.
- ~~**The whole-set view is only half wired.**~~ Built, and it was worse than
  half: `ns:GetTrackPolicyLine` had no caller at all — not the hover either,
  whatever this said. `ns:GetTrackOutlook` now picks the three highest tracks
  with something left to buy and both renderers of the improvements list draw
  them above it. The budget it reads is crests held *plus what the season cap
  still allows*, which is the half a balance cannot show, and the two are
  stated apart: "you hold 40 and the cap allows 200 more" rather than one
  summed figure described as income. The same `funded` flag now splits the
  per-slot advice into farmable this week, waiting on a reset, and — only on
  an outgrown track — wants a drop.
  - Still measured against *this week's* cap, which rises every reset. So a
    slot outside it says "waits on a reset", never "out of reach".
    `GetTrackCompletion` is the one that counts the weeks; the outlook does
    not, and the two have not been joined up.
- ~~**Demand is counted over worn pieces, not over slots.**~~ Built:
  `ns:GetSeasonDemand` prices a crest tier across all sixteen slots off the
  watermark — ranks above a slot's mark, whatever is in it now and whether or
  not anything is. A slot wearing a higher track, or marked past this track's
  cap, drops off the bill entirely, which is why collecting Myth pieces shrinks
  the Hero one. `abundant` (budget covers the whole bill) stands the reserve
  and the hold-for-a-drop bet down.
  - An upper bound in three places — every unfilled slot assumed to take a
    piece at the *bottom* of the track, every slot assumed to get a piece at
    all, an unread mark charging for ranks that may already be paid — and
    deliberately not one in a fourth: a slot holding a lower-track piece is
    priced from that track's CAP, because the piece is going to be maxed
    first and doing so lifts the slot's mark. That is what makes the Champion
    slot in "500 hero + 100 champion + 80 hero" cost four Hero ranks rather
    than five. A player who ignores the cheap upgrade is short by the overlap
    — one rank, only where two bands meet.
  - What it still cannot do is weight a slot by how likely its drop is. Six
    bare slots on a character running +10s are not six equal bets, and the bill
    treats them as such. Wants the per-slot drop-likelihood table that is
    already on this list.
- **No per-slot drop LEVEL.** The band is one pair of numbers for the whole
  character, but raid item level is per boss: the same slot comes off an early
  boss low and a late one high, and which bosses a player kills decides whether
  a mark ever pays. `Features/Loot/LootBrowserData.lua` already scans the
  Encounter Journal per boss, per spec, per slot — that is the data. Caution:
  it is also the scan a previous probe got wrong by reading item level off an
  unresolved link (see the note above `ns.DUNGEON_LOOT`), so it wants a careful
  pass, not a quick one.
- **No per-slot drop likelihood.** The strongest rule in every community
  guide is *solve the slots your content will not* — a slot your keys fill
  weekly is a poor crest target; one nothing has offered in three weeks is
  where the same crests are worth most. Wants a static table shaped like
  `ns.SLOT_PRIORITY`.
- **No set-bonus awareness.** A lower-track piece completing 4pc beats
  another week without it, and the recommender has no concept of tier.
- **Trinkets ranked by item level alone.** `Features/Trinkets/TrinketData.lua`
  exists and the recommender never consults it, so a bad trinket at 308 is
  advised over a good one at 295.

### Verify before building on it

The Myth "of the Mist" threshold may be 331 rather than the track max of 334
that `GetAchievementProgress` assumes. Sourced from a boost-site guide, which
is the genre of source that got the crest exchange backwards in the first
place — check the achievement in game before acting on it.
