# Roadmap

Ideas accepted but not built. Written down while the reasoning is fresh —
each entry should say enough that picking it up later does not mean
re-deriving whether it is possible.

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
- Mr. Yeeper's `bisHave` / `bisTotal`, since the Advisor now counts through
  the same bag-aware path

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

- **No model of time.** `ns.CREST_WEEKLY_INCREMENT` is defined and read by
  nothing. Caps make this a throughput problem, so "you need 380 more
  Champion" is only actionable as "that is two weeks of overflow".
- **The hover is where the reasoning lives; the page has none of it.** The
  row is one line and the tooltip carries the rest, but a player who never
  hovers sees only the verdict. The track's finish line — "3 pieces and you
  are done with Champion" — is the strongest sentence the addon produces and
  it is hidden behind a mouse.
- **The whole-set view is only half wired.** `ns:GetGearCensus`,
  `ns:GetTrackPolicy` and `ns:GetTrackPolicyLine` exist and the hover prints
  the policy line, but nothing above the list says it. A track budget is a
  fact about sixteen slots and one wallet, and it belongs at the top of the
  page, not inside a tooltip on one row.
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
