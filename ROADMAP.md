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
