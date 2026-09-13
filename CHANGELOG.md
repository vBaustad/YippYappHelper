# YippYapp Helper - Changelog

## v3.4.0 - Pins to the quest givers, and what the weeklies pay (2026-09-13)

### Added
- **A pin button on the weeklies that lead somewhere.** Asked for on
  CurseForge: something to click that puts an arrow on the screen, the
  way Azeroth Pilot Reloaded does. It does not draw one -- the game
  already has an arrow, a minimap marker and a map waypoint, and all
  three follow whatever is super tracked -- so a click hands the game a
  target and gets out of the way. Click it again to let go.

  **It opens the world map too**, on the map the target is actually on.
  A waypoint you cannot see is a direction without a distance -- the
  arrow says which way, the map says how far and what is in between, and
  "where do I pick this up" is asking the second one. Not in combat: the
  pin is still placed, the map stays shut.

  The button sits at the right-hand end of the row and **is only there
  on rows that lead somewhere**. A crest cap is not a place you walk to,
  so it has no button rather than a button that does nothing.

- **Five quest givers ship with the addon**, so the pins are there on a
  fresh install rather than after a week of play. Lady Liadrin, Halduron
  Brightwing, Vereesa Windrunner, Archmage Aethas Sunreaver and
  Warleader Abdumati, from Wowhead's datamined `g_mapperData` -- which
  carries its own uiMapId, so the map is not being inferred from a zone
  name. Each NPC was reached through a quest id the addon already ships
  rather than by searching a name, and the Silvermoon map id was
  confirmed a second time against a live client. Anything the client
  learns overrides them.

- **The addon learns where each quest giver stands.** The four Silvermoon
  rows carry a family of quest ids -- sixteen for Lady Liadrin, eight for
  Halduron -- one of which is this week's, and nothing in the client says
  which. Rather than answer that question, the addon stops asking it:
  **you have to be standing next to the NPC to accept or hand in a
  quest**, so the player's own position at that moment is the giver's,
  and it is recorded against the ROW rather than the quest. Take any one
  of Lady Liadrin's sixteen and her row knows where she stands from then
  on -- every week after, and on every character on the account, because
  an NPC is in the same place for all of them.

  Nothing is written down in the addon and nothing is read off a website.
  Only while a quest window is open, too: `QUEST_ACCEPTED` also fires for
  quests the game hands you for walking into a zone, and those would
  record wherever you happened to be standing as a quest giver's spot --
  a confident pin in the wrong place, which is worse than no pin.

  **Three ways in**, so the page is useful before you have done the
  week's chores rather than after. Best observation wins, and none of
  them overwrites a better one:

  - you say where it is -- `/yh where set liadrinweekly` on the NPC, or
    `/yh where set liadrinweekly 47.9 51.6` from anywhere in the zone,
    which takes a published coordinate and reads the map id off the
    client. Percentages and fractions are both accepted and the result
    is echoed back, because every database writes one and the game
    wants the other;
  - you accept or hand in one of the row's quests, as above;
  - the world map already knew where the offer was, taken for free on
    walking into the zone. A coordinate outside 0..1 is dropped rather
    than converted -- map positions come as fractions and as
    percentages, and guessing which is how a pin ends up wrong half the
    time.

  `/yh where forget` throws the lot away if a record is ever wrong; they
  rebuild themselves the next time each quest is picked up.

- A weekly that leads somewhere but has no pin yet **says so on hover**.
  An empty right-hand edge is otherwise indistinguishable from a crest
  cap, which is not a place and never will be.

  The question behind the request was never "which quest is it", it was
  **where do I pick this up**, so a row points at whichever of these it
  can:

  - the quest, when it is in your log -- super tracked by id, so the
    arrow follows the objective rather than the giver;
  - **the NPC who hands it over**, when it is not. Lady Liadrin stands
    in the same spot whichever of her sixteen she is offering this week,
    which is exactly why the giver is the answer that works;
  - the client's own quest-offer pin -- the blue exclamation mark -- on
    a row whose single outstanding quest can be identified.

  **A family of quest ids is never guessed at.** Halduron offers one of
  eight dungeons a week and nothing in the client says which, so the
  offer-pin route refuses a row it cannot narrow to one rather than
  picking whichever sorted first. The giver route is what carries those
  rows, and it carries them without needing to know the answer.

- **Weekly rows say what they pay**, with the game's own icons. The other
  half of the same request.
  Hovering a row that names a quest now lists its rewards under the
  objective: the currency first, because on a weekly the currency is
  usually the whole point, then items in the game's own rarity colours,
  then the pick-one list under a heading of its own -- a weekly paying a
  thousand reputation with a faction you choose is five lines that each
  mean "or", and an unmarked list of five reads as a quest handing over
  all five.

  Each line carries the reward's icon, its name in the game's rarity
  colour, and the count in a right-hand column of its own rather than
  glued to the end of the name -- the count is the part you compare
  between two weeklies, and ninety crests against one spark should line
  up. Large numbers go through the client's own separator, so a thousand
  reputation reads as 1,000.

  Read off the client rather than written down here, so a quest retuned
  this patch reads correctly the day it is retuned, and a reward that
  scales reads as what this character would actually be paid.

  **And before you accept anything**, which is when the question gets
  asked. Most rows resolve no quest at all until it is in your log, so
  the rewards used to appear only once it was too late to be deciding.
  A row offering one of sixteen now simply says what it pays -- "Spark
  of Tides" -- because that is a fact about the row whichever variant
  comes up, and the row's own description has said so all along.

  The moment a quest IS in your log the client's answer takes over,
  with its real icons and amounts.

  Archmage Aethas Sunreaver's row shows two lines, because his set pays
  two different things: a Cache of Amani or Quel'Thalas Treasures for
  the dungeon, delve and Timewalking weeklies, and Conquest with Honor
  for the battleground and arena ones.

- The world boss now sits with the other chores, above the Vaults of
  Atal'Utek weekly, so the weeklies you pick up from a quest giver --
  and their map pins -- form one block instead of being split in two.

### Changed
- The weekly row's own click is unchanged -- it still ticks the rows that
  are ticked by hand, and nothing else. Pointing at a quest lives on its
  own button because it applies to a much smaller set of rows than
  ticking does, and putting both on one click made most of the page
  answer a click by doing nothing.
- The pin lights up while the game is pointing there, so the page agrees
  with the arrow out in the world.

### Fixed
- **Veteran Mistcrests could read from a dead currency row.** Every
  crest tier exists twice in the client under the same name, and only
  one row is live. The addon picked whichever row held MORE -- a rule
  from the week it had been pointed at the empty block -- but a dead row
  is not always empty. One Priest held 80 on dead 3438 and 50 on live
  3443; Blizzard showed 50, the addon showed 80, and the affordability
  and upgrade suggestions were computed from the 80.

  The resolver now takes the row the character sheet's Currency tab
  lists, which is the game's own answer, and otherwise the verified
  order. A balance is never treated as evidence. What the listing found
  is remembered, so collapsing a header in the Currency tab -- which
  hides its rows from the list -- cannot flip the addon back. All five
  tiers go through the same path; Veteran is where it showed.

  The unlisted twin is still reached when the game lists it instead of
  the usual row, which is what a patch swapping the live block would
  look like. It is never reached any other way: with nothing listed the
  answer is the verified id, even if that id reads nothing. A live row
  showing zero is visibly wrong; a twin showing 80 is not.

- **Reward items read "Item" on the first hover.** A quest's reward list
  and an item's name are separate loads, so the tooltip could know which
  item a weekly pays before knowing what it is called -- and nothing
  redrew it when the name arrived. The name is now filled from the item
  cache where it is already known, asked for where it is not, shown as
  "Loading..." meanwhile, and the open tooltip redraws itself the moment
  the name lands.

- **A pin that opened the wrong zone.** There was a third route that
  super-tracked the client's own quest-offer pin for a weekly you had
  not accepted. The only map it can name for an un-accepted quest is the
  QUEST's -- where the objectives are, not where the giver stands -- so
  the one row it reliably fired on was the one it sent to the wrong
  place, on a line reading "Pick up Vereesa's weekly in Silvermoon".

  It has been removed rather than patched. What it was for is exactly
  what the giver does, with a position somebody has actually checked,
  and it was the only route never seen working in game.

  **A row's pin and its label now always agree**: while the quest is in
  your log the row reads "Complete Midnight: Prey" and the pin follows
  the objective; before that it reads "Pick up Lady Liadrin's weekly"
  and the pin is Lady Liadrin. A row that says "pick up" and points at a
  delve is lying, and that cannot happen now.

### Removed
- A dead "Map waypoints" block in `Core/Data.lua` -- its body went in
  "Sweep the code nothing calls" and left behind a header comment and two
  unused constants. The map-pin art it named is now used by the thing
  that actually drops a pin.

## v3.3.2 - Durability off the channel everyone is already on (2026-09-10)

### Fixed
- **The minimap button could take itself out on load.** LibDBIcon and
  LibDataBroker are optional dependencies -- another addon may supply
  them, or nothing may -- but they were being asked for in the form that
  throws when they are missing, once for LibStub itself being absent and
  once for LibStub not having the library. Both are now silent lookups,
  and with them gone the addon simply has no minimap button; `/yh`, the
  key binding and every page are unaffected.
- **The Dur column filled for nobody.** Durability was shared over this
  addon's own `YYHDUR` prefix, so a raider's percentage only ever
  appeared if they also ran YippYapp -- and the column looked like it
  worked, because your own row always did. It also never filled at all in
  a dungeon-finder or LFR group: those need `INSTANCE_CHAT`, and the
  broadcast only ever went to `RAID` or `PARTY`.

  Moved to **LibDurability**, the shared library on the `LibDRBLT`
  prefix that BigWigs and Method Raid Tools both embed. Its own frame
  answers a ready check from file load, without the host addon having to
  do anything, so a raid full of BigWigs users answers -- which is every
  raid. This is the same fix the Guild keystone tab got in v3.2.0, for
  the same reason.

- **A broken weapon reads green no longer.** One dead item among
  seventeen healthy pieces still totals in the nineties, so the number
  alone said everything was fine. Broken items are counted separately now
  and turn the cell red whatever the total says, with the count in the
  tooltip.

### Changed
- The durability cell has a tooltip. It used to fall through to the
  buff-column wording and hover as "out of range or not applicable" --
  off a cell showing 84%. A blank cell now says the honest thing, which
  is that the player is running no addon that shares durability, rather
  than pointing at a range problem that is not there.
- Opening the window by hand now asks the group for durability instead of
  only announcing your own. It used to sit full of dashes until somebody
  started a ready check.

## v3.3.1 - The ring that paid for the other one (2026-09-02)

### Fixed
- **A second copy of a ring is not a second ring.** A ring or trinket
  slot remembers a line it takes two pieces to build, and they have to be
  two DIFFERENT pieces. Away from the upgrade vendor the client answers
  nothing, so the addon falls back to what it can see -- worn gear plus
  anything bound in the bags -- and it counted a spare copy of the ring
  already worn as the second half of its own pair. One Hero ring at 311
  with its twin in the bags, and the Champion ring on the other finger
  was told "Free upgrade! All remaining ranks are free". The vendor
  charges for those ranks.

  Counted once per item now. The client itself was right all along: with
  a 311 ring and a 295 ring worn, it reports 295 for the finger line --
  the good ring alone buys the other finger nothing.

- **"1 free via Champion" was never free.** The grey note beside a piece
  sitting in its track's overlap band claimed the first ranks cost
  nothing. Those ranks are free only as a PROMOTION -- take a Champion
  piece to 6/6 and it arrives at Hero 2/6 without a Hero crest. A piece
  that dropped at Hero 1/6 has no promotion left to collect and pays Hero
  crests for the next rank like any other; the vendor prices by the
  item's own track, not by the item level the rank lands on.

  It now reads "(1 rank Champion also reaches)", which is the true part
  and the part the row's own "Wasteful crest spend" status is built on.

- **An enchant no longer makes a piece "crafted".** Crafted was detected
  by looking for the profession quality atlas anywhere in the tooltip
  text, and an enchant carries one -- "Enchanted: Enchant Helm -
  Empowered Rune of Avoidance" brings the enchant's own quality rank with
  it, so an ordinary helm read as crafted. On the character this was
  found on, ten of sixteen slots came back crafted; two of them were, and
  the other eight were the enchanted ones.

  It cost more than a label: a crafted piece counts as the craft already
  done, so every slot with a good enchant quietly dropped off the list of
  things to make. Crafted is now read off the item itself, through
  `C_TradeSkillUI.GetItemCraftedQualityByItemInfo`, and the tooltip scan
  is only a fallback for a client that cannot answer.

- **`/yh marks` prints every bucket the client keeps.** It looped over
  the sixteen this addon was written against, so a bucket the client
  gained since could not appear on the one screen that exists to show
  what is actually there.

## v3.3.0 - Trinket tier lists, the upgrade-mark fixes, and the Battle Res Timer out (2026-09-02)

### Removed
- **The Battle Res Timer is gone.** EllesmereUI draws one, so does
  BigWigs, and all three read the same pool the game itself publishes --
  so for most raiders this was a second copy of a number already on
  screen. It was also on screen during a pull, which is where there is
  least room for one.

  Out with it: `Features/Raid/BattleResTimer.lua`, its two options
  (Battle Res Timer, and Show between pulls), the "Battle Res Timer"
  settings section, and `/yh brez`. The roster's "who can combat res"
  column is a different thing and stays -- that lives in
  `Features/Raid/SpecMeta.lua` and feeds the raid page.

  Its saved settings and its Edit Mode position are cleared on next
  login, so nothing is left behind in the SavedVariables file.

  **Edit Mode now has nothing to place.** The timer was its last frame:
  every other window in the addon moves itself, dragged where you want it
  while it is open, and only the timer -- up mid-pull, when dragging is
  the last thing you want to be doing -- needed a mode of its own. The
  "Appearance and position" section and its Open Edit Mode button have
  gone with it, and `/yh edit` says so instead of opening an empty
  manager. The integration itself is left in place: it is machinery
  rather than a feature, and one table entry brings it back.

### Added
- **Best in Slot now survives the Catalyst.** Feeding a piece to the
  Catalyst destroys it, so a row you had done exactly what the page told
  you to do with flipped from collected back to missing at the moment it
  was most finished -- the item ID it was tracking no longer existed.

  What survives the conversion is the secondary stats: class set armour
  inherits them from whatever went in. So a set piece worn in one of the
  five class-set slots, whose secondaries match the armour that slot's
  row names, is now read as that row, converted. It counts toward
  "collected", carries the Catalyst's purple and a `cat` tag on the doll,
  and the slot summary gains a "2 converted" segment on characters who
  have any.

  It is shown as an inference rather than as a tick, because that is what
  it is: a set piece that dropped directly rolls its own secondaries and
  can land on the same pair by chance. The tooltip says what was actually
  seen -- "you are wearing class set armour at 311 with this item's
  secondaries" -- rather than claiming to know which piece was fed in.
  Anything the client can state outright wins: wearing the row's own item
  reads as equipped, a copy in the bags reads as bagged, and a row already
  tagged `+cat` is never inferred at all, since there the item ID answers
  on its own.

- **Trinkets now carry the guide's verdict, not just the sim's.** Hovering
  a trinket has always shown where bloodmallet ranks it. It now also
  shows the letter grade your spec's Wowhead guide gives it, the content
  it drops from, and the author's own note on it -- "syncs perfectly with
  DRW as San'layn", "not great, honestly, careful while using it" -- the
  kind of thing a throughput number cannot say.

  The two are shown side by side rather than blended. A percentage and a
  letter are different claims: the sim ranks by damage against one
  dummy, and the guide ranks knowing which on-use wants pairing with
  which cooldown, which drop is Vault-only, and which pair nobody would
  wear together. Averaging them would produce a number neither source
  stands behind.

  **Augmentation Evoker has trinket advice for the first time.**
  bloodmallet does not sim it and QE Live covers only healers, so the
  spec had nothing at all. Its guide grades trinkets like every other,
  and that is what the new tab and the tooltip read.

  **A Guide tab on the Trinkets page**, beside My Spec and Loot Council.
  It draws the ladder in bands rather than as a numbered list, because
  within a tier the guide states no order and numbering three S-tier
  trinkets 1, 2, 3 would invent a ranking the author declined to give.
  Every band is drawn, never a top-N: the lower bands are where the "do
  not bother" information lives, which is most of what a tier list is
  for. The pairing advice sits above it, and each author note under the
  trinket it is about. No bars, no percentages, no item level stepper --
  none of those are what a letter grade is made of -- and the fight
  style buttons are hidden there, since the guide grades a spec once
  rather than once per target count.

- **The Guide tab leads for specs whose sims are behind.** bloodmallet
  re-sims a season a few specs at a time, and Balance Druid, Feral,
  Guardian, Devastation and Retribution are still on last tier's
  numbers -- they have no opinion at all on anything that has dropped
  since, and the page opened on them anyway. For those specs the Guide
  tab is now first, so the page lands on advice that is about this
  season. It is a reorder, not a redirect: My Spec is one click away,
  still says what it is, and a remembered choice still beats both.
  Hiding the sim outright would be a bigger claim than "this one is out
  of date", which is all that is known. The stale-data warning on My
  Spec now points at the tab that is current instead of only saying the
  numbers are old.

  909 graded trinkets and 301 author notes across all 40 specs, from
  `Tools/scrape_trinket_tiers.py`. The tier list lives on the same
  `/bis-gear` page the class-guide scrape already fetches, so keeping it
  current costs no extra requests.

- **A trinket the guide does not list now says so.** Previously a hover
  that found nothing looked exactly like a hover on an item the addon
  had never heard of. It now says "not on the Fire Mage trinket list"
  -- but only for a trinket some other spec ranks or grades, which is
  what proves it is a current trinket worth having an opinion about. An
  item nobody ranks still says nothing, because the guide's silence
  there is about its own scope rather than about the item.

- **The trinket tooltip answers your question first, and only yours
  when you are alone.** It used to open with five other specs' rankings
  on every hover. On a character whose own sim is a tier behind, that
  was the entire tooltip: eight lines about specs you are not playing, a
  "+29 more specs", and nothing whatsoever about you.

  Your spec now comes first -- the guide's grade, the author's note, and
  a single `Sim #7` line for where the sim puts it -- and the other
  specs are shown only when you are in a group, cut from five to three.
  "Who else wants this" is a real question, but it is the loot council's
  question and it needs a council; the page's Loot Council tab has
  always held the full list. The duplicate source attribution in the
  header is gone too: the group headings underneath already said it.

- **The consumables popout meets the Auction House.** The small popout
  exists for one place -- standing at an auctioneer with fifteen names to
  shift-click -- and it did not know when you were there, so every visit
  started by opening the app, finding the Consumables page and pressing
  Popout. Now it opens itself when the Auction House does, pinned against
  the top right of it.

  The top right corner rather than any other: it hangs off the side so
  nothing is covered, and anchoring the *top* keeps the window still when
  its height changes -- Gems is a third the length of Consumables, and
  paging the arrows from a bottom anchor would have it jump every time.

  Pinned is the default, and a **Pin to Auction House** box on the window
  itself is the unlock. Untick it and the window stays exactly where it
  is -- unlocked in place, not thrown back to wherever it last sat loose
  -- and drags anywhere you like from there. The box only shows while the
  Auction House is open, because that is the only time it means anything.
  Dragging a pinned window is refused outright rather than allowed and
  snapped back, which looks like the window fighting the cursor.

  Only a window the Auction House opened is closed again when you leave.
  One you popped out by hand before walking over is left alone.

  Off in **Options - AddOns - YippYapp Helper - Consumables at the
  Auction House** if you would rather open it yourself.

  **`/yh ah`** walks that whole path and says what it found at each step
  -- whether the watcher is armed, whether the page is built, whether the
  setting is on, whether the Auction House frame has ever loaded -- and
  then runs it. Every one of those failing looks identical from the
  chair, which is nothing happening.

### Developer
- **The load harness counts globals.** Every global the addon creates
  is snapshotted around the load pass and diffed. A Lua assignment that
  forgets `local` lands in `_G`, Blizzard's own code reads globals, and
  reading one an addon wrote carries that addon's taint into the secure
  path -- the "interface action failed" class, which then gets blamed on
  whichever addon the player looks at first. Nine exist today and all
  nine are legitimate: named frames, the keybinding strings, the saved
  variables table and the bundled libraries' own globals. The tenth will
  fail the run.

- **`/yh marks` — the whole high-water state, read rather than
  inferred.** Every one of the seventeen redundancy buckets the client
  keeps, named from the client's own enum, character and account side by
  side; then which bucket each worn piece answers to, with crafted and
  off-stat pieces flagged.

  Everything else in the addon reaches these marks one item at a time,
  which is the right shape for pricing a rank and the wrong shape for
  answering "why did this not go free" -- it can only ever show one
  bucket and never the sixteen it sits among.

  It exists because the rules here are not documented anywhere and the
  player reports contradict each other. Run it, change one piece, run it
  again: whatever moved is the rule. Two runs settle questions no amount
  of reading settles.


### Changed
- **The Auction House list has room, and answers a click instead of the
  cursor.** The window beside the auctioneer was 250 wide with 22px rows,
  and the names in it are the longest in the addon -- a weapon enchant
  wrapped onto a second line inside a one-line row, so it was drawn
  through the name under it. It is wider now, a line taller, and a name
  too long for the row is cut short rather than wrapped.

  **No more tooltip on hover.** This window sits on top of the Auction
  House and the cursor crosses it on the way to something else; a
  tooltip that opened itself on the way past covered the auction list
  underneath, repeatedly, for nobody. Now:

  - **Click** an item and its tooltip opens beside the window -- on
    whichever side has the room -- and stays there until you click it
    again, so it can be read without holding the mouse still.
  - **Shift-click** and the Auction House searches for it: the name goes
    into Blizzard's own search bar and the search runs. Away from an
    auctioneer, shift-click still links to chat as it always did.

  A line at the bottom of the window says which is which, and says
  "search" or "link" depending on where you are standing.

- **Steps get a number, not a question mark.** A row with no spell
  behind it used to draw `INV_Misc_QuestionMark`, on the reasoning that
  a missing icon and a missing spell id look the same to a reader. That
  reasoning was wrong about half the rows: "The split", "The quadrants",
  "The egg fall", "Platform eggs" are not abilities at all. They are
  steps, done in order, and there was never going to be a spell id for
  them -- so the question mark was reporting a lookup failure that had
  not happened.

  Those rows now show a numbered box: the step's place in its phase,
  after the difficulty filter, so the number matches what is on screen.
  It reads as sequence, which is what a step is. An ability we genuinely
  have no id for gets one too -- "here is where this comes" is true,
  where "something went wrong" was not.
- **"Before you pull" answers per difficulty.** One flag covered both,
  so a boss whose Heroic notes existed and whose Mythic ones did not
  printed "Not recorded" over the top of the Heroic notes it had -- a
  claim of ignorance the same card disproves two lines further down.
  Each difficulty answers for itself now: what is written, or an
  admission for that one alone. Silence still means "nothing changes",
  which is a real answer and a different one.
- **Ula'tek's guide, rewritten against a real source.** He was written
  from two video transcripts because nothing covered him in text.
  mythictrap has published him now, which adds the half a transcript
  cannot: real spell IDs for Mother's Wrath, Unchecked Rage, Necrotic
  Vapors, Anguished Cry and Vicious Echoes, so those five draw the
  client's own icon and tooltip instead of being matched by name.

  Two phase-one abilities nobody had captioned are in: **Unchecked
  Rage** is the reason both tanks hold their targets — let either drift
  out of melee and the raid takes it — and **Necrotic Vapors** is the
  rot running underneath the phase. Both interrupts are named now, one
  per later phase.

  Heroic changes go on the two mechanics they change. Mythic stays
  unknown, because mythictrap publishes a Heroic block for this boss and
  no Mythic one.

  The transcripts held up everywhere else, including the two things they
  were most likely to have invented — eggs breaking weak or hatching
  strong, and phase three's marked players being soaked rather than run
  from.
- **Class guide data refreshed** (Wowhead, 2026-09-02). 29 of 40 specs
  moved since the last release, over two passes. Stat priorities changed
  for Unholy Death Knight, Subtlety Rogue, Enhancement Shaman and
  Preservation Evoker -- Enhancement's two hero builds no longer agree,
  so the page now shows Stormbringer and Totemic separately instead of
  one merged list. Best-in-slot moved in most of the rest, most heavily
  Restoration Shaman, Enhancement Shaman, Subtlety Rogue, Preservation
  Evoker and Restoration Druid.
- **Consumables data refreshed** (Wowhead, 2026-09-01). 16 of 40 specs
  moved since the last release. Most of it is one story: a new temporary
  weapon enchant, Rite of the Hash'ey, which 14 specs now recommend over
  the old oils and stat enchants. Havoc Demon Hunter also dropped from
  five gems to two and changed its diamond, and Assassination's flask
  and combat potion became three-way ties rather than single picks.

### Fixed
- **The Auction House list read `item:273072` until you closed it.** Walk
  up to an auctioneer for the first time in a session and the popout
  came up as a column of red question marks and raw item IDs. Closing it
  and opening it again fixed it, which is the tell: the client had not
  sent those items yet, and the names landed a moment later with nobody
  listening.

  The redraw that runs when an item's data arrives was wired to the
  Consumables page, and beside the Auction House the page is shut -- so
  it checked, found the page hidden, and did nothing. The popout now
  counts as being on screen in its own right, and gets its own redraw
  when the page is not up to pass one down.

- **A free rank that was not free.** An off hand at 305 wore a cyan
  "Free upgrade!" and read "free to 308", and the vendor charged crests
  for the rank.

  The client answers the high-water query twice over: how high THIS
  character has been in the slot, and how high the account has. The
  addon took the larger of the two and called every rank under it free.
  Only the character's own figure carries a free rank; the account
  figure is how far the rest of the warband has got, which is a
  different statement about a different character. That is now the only
  number a free rank may be quoted from, with the account one kept as a
  fallback for the client not answering in that shape at all.

  Marks written under the old rule are on disk and nothing about a
  stored number says which half it came from, so they are cleared once
  at login and re-read within a few frames.

  Wrong in the safe direction from here on, which is the rule the whole
  free-rank half of the addon is built on: a mark that is too low hands
  out too few free ranks, and a row that holds back a rank that turned
  out to be free costs a walk to the vendor. Too high spends crests that
  do not come back.
- **The raid scan kept everybody you ever grouped with.** It is written
  from `INSPECT_READY`, which fires for a group member whoever asked for
  the inspect -- this addon or any other -- it was cleared only by
  starting another scan, and it was saved to disk on every logout.
  Measured on a real account: **673 players, 152KB**, three times the
  size of everything else in the saved variables file put together, and
  nearly all of it strangers from pugs weeks earlier.

  It prunes to the current group on every roster change now, and saves
  nothing at all when you log out ungrouped. An empty roster reads as
  "ask again later" rather than "you are alone", so a loading screen
  cannot blank the page for a raid that is still there.
- **The durability cache is bounded.** Same shape, smaller: fed by
  addon messages from other players, one entry per distinct sender name,
  and nothing ever removed one. Entries past their ten-minute TTL are
  already ignored on read, so they are now swept once the table grows
  past a group's worth. It matters mainly because the feed is remote --
  a table that only ever grows, filled by input from outside, is worth
  bounding whether or not anyone is being clever with it.

- **The crest discount is re-read the moment it is earned.** It is an
  achievement, and an account-wide one: cross an item level in every
  slot on any character and every character pays ten crests a rank
  instead of twenty. The addon checked once at login and cached the
  answer, so a discount earned with the panel open left every price
  doubled until a reload -- at exactly the moment the numbers matter
  most, with somebody deciding what to spend next having just crossed a
  threshold. `ACHIEVEMENT_EARNED` clears it now.

- **Off-stat gear sets no line.** The high-water mark follows gear that
  is class-appropriate, not everything a character can physically
  equip -- and the addon was counting anything bound with a high enough
  item level. A shaman reported spending sixty Hero crests taking an
  Agility staff from 311 to 321 with the watermark never moving; a
  shaman can hold a staff, and an Agility staff is nobody's shaman
  weapon.

  That is the piece a player is most likely to be sitting on, too: the
  off-stat one kept because the item level is high. Every place the
  addon works a mark out for itself now checks -- what is worn, what is
  bound in the bags, a spare worth finishing, a tradeable piece worth
  keeping.

  Excluded on positive evidence only: this spec's primary stat read off
  the guide, the item's read off the item, and the two different.
  Anything unknown still counts, so the rule cannot quietly swallow the
  pieces that have no primary stat at all -- most necks, rings and
  trinkets -- or every spec whose guide the addon has not got.

- **Your alt was reading someone else's marks.** The saved variables
  file is account-wide -- one table, every character on the account
  writing into it -- and the high-water mark cache was keyed by slot
  alone. A mark is a fact about ONE character's slot, so every character
  after the first read whatever the last one left behind.

  And it read them in exactly the situation the cache exists for: away
  from the upgrade vendor, where the live query answers nothing and the
  read falls through to disk. A druid logging in after a demon hunter
  inherited the demon hunter's weapon line and was told ranks were free
  that its own vendor charges for.

  Marks and their item links are now filed under the character's GUID --
  stable across a rename or a transfer, and unique where two characters
  on different realms share a name. What was already on disk cannot be
  attributed to anyone, so it is cleared once at login and re-read.

- **Two one-handers share a line, and the addon now knows it.** This is
  the rest of the free-rank bug above, and it takes two one-handers to
  see: `Enum.ItemRedundancySlot` keeps the one-hand marks as a ranked
  PAIR -- `OnehandWeapon` (14) and `OnehandWeaponSecond` (15) -- the same
  shape rings and trinkets have, and there for the same reason. One good
  one-hander must not hand the other hand free ranks.

  `GetHighWatermarkForItem` answers about the item's own bucket, which
  is the higher of the two. Handed to the second hand it is a promise
  about a weapon the player is not upgrading: a 331 in the main hand
  answered 331 for an off hand sitting at 305, and every rank to 308 was
  offered for nothing.

  So the two weapon slots are now a pair -- but only while both hands
  hold a one-hander. A two-hander, a shield or a holdable sits in a
  bucket of its own and pairs with nothing, which is why this never
  showed up on anything but dual-wield. When they do pair, the free line
  comes from the second bucket, asked for by name, and the bags follow
  the same second-highest rule rings and trinkets have always used.

- **`/yh debug` can be pointed at a slot** -- `/yh debug 17` for the off
  hand, Feet as before with no argument. It asks the high-water query
  about that slot and prints both figures the client hands back beside
  what the addon concluded from them, so a row promising a rank the
  vendor charges for can be taken apart from the chair. Equipped crafted
  pieces are marked `[crafted]` in the dump.

## v3.2.0 - Crest advice, shared keystones, and a lighter addon (2026-08-24)

### Removed
- **The Delves tab is gone.** A whole page to restate a companion's
  friendship rank, a key count and a tier ladder -- none of which the
  game hides, and two of which this addon already says elsewhere. It came
  out entirely: `Features/Delves/`, its shell page, its entry in
  `/yh shell <page>`, and the client stubs in the harness that nothing
  else used (`C_DelvesUI`, the `C_GossipInfo` friendship pair,
  `C_PartyInfo.IsDelveInProgress`, `C_Reputation`).

  Delves themselves are not gone from the addon, only their tab. The
  weekly checklist still lists delve chores, the Dashboard still advises
  "run a tier N delve" when that is the cheapest upgrade going, the
  Progression page keeps its delve tier section, and the vault's World
  row is still filled by them.
- **The interrupt tracker is gone.** It had not worked for the whole of
  12.1, and it could not be repaired in place. The tracker never saw
  which spell a party member cast -- the client stopped handing that over
  once party spell IDs became secret-tainted -- so the party half of it
  was inference: note that a teammate cast *something*, and when an enemy
  is interrupted within 150ms, assume it was that teammate's class
  default kick. Every layer of the file was scar tissue from working
  around that (`pcall` on every lookup, `UnitIsUnit` instead of comparing
  GUIDs because enemy nameplate GUIDs came back secret too), and the
  guess at the bottom was the part that could not be fixed.

  Making it genuinely work means a different data source -- the combat
  log's `SPELL_INTERRUPT` names the kicker and the spell outright -- which
  is a rewrite rather than a repair, and it would add the one event class
  this addon has deliberately stayed clear of. OmniCD already does that
  job well. Removed rather than left on screen lying.

  Its saved settings and Edit Mode position are cleared on next login, so
  nothing is left behind in the SavedVariables file.

### Performance
- **The watermark sweep still froze the client, and the test said it
  didn't.** `ns:RefreshWatermarks` was fixed once already -- it asks the
  client about one slot per frame instead of sixteen at once -- and it
  went on producing multi-second frames anyway, most recently 5.3 seconds
  on a spec change. Only half of it had been spread. To decide which
  slots were worth queueing it called `ns:GetSlotInfo` on all sixteen up
  front, synchronously, and that is the expensive half: `GetSlotInfo`
  ends in a real `SetInventoryItem` tooltip build, and the
  `UNIT_INVENTORY_CHANGED` handler driving it wipes the scan cache
  immediately beforehand -- so every one of the sixteen is guaranteed
  cold, on item data the client may still be loading. The decision moved
  into the per-frame runner; the caller now does no slot reads at all.
- **...and the check that was supposed to catch it stubbed the slow
  half.** The harness counted `C_ItemUpgrade` calls and asserted none
  landed in the calling frame, while replacing `GetSlotInfo` with a
  trivial stub -- so it proved the cheap half was spread and never
  measured the sixteen synchronous reads at all. It counts slot reads
  now too, and the assertion is controlled: reinstate the old
  queue-builder and it reports "read 16 slots in the frame that called
  it".

A sweep for work the addon does during ordinary play. None of these were
features; all of them were the addon spending frames on questions nobody
had asked.

- **The login loot prewarm no longer caps the client at 30fps.** The
  Encounter Journal sweep gives the frame back once it has used its
  budget, and the budget was one whole frame at 60fps -- correct for the
  scan somebody is watching a spinner for, and exactly backwards for the
  one that runs unasked a few seconds after a loading screen. The prewarm
  now takes 4ms rather than 16ms. It finishes later; nothing is waiting
  on it.
- **...and it no longer runs while you are inside a dungeon.** There was
  already a guard for this, and it had never once executed: it lived
  inside the closure the load gate only calls under `/yh loadtest loot`,
  which is the by-hand path where the guard is least wanted. On the
  normal path -- the one every session takes -- the gate says "go ahead"
  and the closure is never called, so thousands of journal calls ran on
  the way into keys exactly as before. The guard is now where it reads
  like it was: ahead of the work, on the path that does the work.
- **The battle-res timer stopped listening to your own cooldowns.**
  `SPELL_UPDATE_CHARGES` fires for every charge-based spell the character
  owns, so a Monk rolling around a world quest woke the handler several
  times a second -- and the handler re-validates the entire saved
  settings table and calls `GetInstanceInfo` before concluding "not in a
  raid, draw nothing". The event is now registered only while the icon is
  actually on screen; the events that can put it there were already
  covered.
- **The home page stopped rebuilding for other addons' quests.**
  `QUEST_DATA_LOAD_RESULT` is global -- it reports every quest anything in
  the UI asks for, and quest addons ask in the hundreds. Each one with a
  resolvable title triggered a full home-page relayout, and because a page
  stays mounted after the window closes, it did so on a window nobody was
  looking at. Now only the quests this addon asked about count, and only
  while the window is open.
- **Crest IDs are resolved once a second at most, not once per coin.**
  `CURRENCY_DISPLAY_UPDATE` is a gameplay event -- every turn-in, every
  boss, every mob that drops anything -- and each one ran ten `pcall`ed
  currency lookups and handed ten result tables to the collector, to
  re-answer a question whose answer changes about once a season. Anything
  that draws a crest still resolves on the spot, so nothing shows a stale
  row.
- **`/yh trace` costs nothing while it is off.** Its frame watchdog is a
  parentless frame, which the client shows by default, so its `OnUpdate`
  ran every frame of every session to read one boolean and return. Trace
  could never have caught this: it does not wrap its own watchdog. The
  frame is hidden now until tracing is switched on.
- **`UNIT_INVENTORY_CHANGED` is filtered to the player.** The handler
  already discarded everyone else's -- but in Lua, after being woken for
  each of them. The client does that filtering for free.


### Mythic+
- **One redraw per burst of keystone replies, not one per reply.** The
  page redrew on every incoming key, which was survivable while the only
  repliers were other YippYapp users -- in practice none. On the shared
  channel a single request into a large guild returns hundreds of replies
  inside a second, and this asked for hundreds of full page renders to
  draw a list that changed once. The library throttles what we send;
  nothing throttles what arrives.
- **Keystones now arrive on the channel everyone is already on.** Keys
  were shared over YippYapp's own addon prefix, so the Guild tab only
  ever listed people who also ran YippYapp -- in practice nobody, and
  its empty state told the player to go and evangelise an addon to fix
  it. The addon now embeds `LibKeystone`, the library BigWigs, DBM and
  EllesmereUI all carry. Its frame answers a request the moment the file
  loads, whether or not the host addon displays anything, so a guild or
  party full of BigWigs users answers. Party keys populate from the same
  callback. The old prefix still works, so nothing is lost for anyone
  who does run YippYapp.
  - **Needs a full client restart, not a `/reload`** -- it is a .toc
    change, and the Lua guards on the library being absent so a reload
    degrades to the old behaviour rather than erroring.
  - M+ rating rides along for free on this channel and is now recorded,
    though nothing displays it yet.

### Mythic+ page
- **A full group's keystones no longer run off the bottom of the page.**
  The card grows to the floor and stops; the rows inside it were laid out
  at one fixed height however many there were, so a fourth key was drawn
  through the page and into the tab strip underneath. Two row heights
  now, the way the This Week card beside it already picks between a plain
  row and a detailed one -- roomy while it fits, tighter when it does
  not, and a "+N more" line as a backstop rather than a list that
  silently stops. Never seen before because this list only ever showed
  other YippYapp users; moving keystones onto LibKeystone filled it up
  and the layout met a full group for the first time.
- **The Guild tab's Refresh button is gone; opening the tab asks.** The
  button was parented to the whole window rather than to the tab's
  content and nothing hid it again, so once the Guild tab had been opened
  it stayed on screen over the Home tab's dungeon tiles for the rest of
  the session. It was also a button for something the addon can do on its
  own: asking is one throttled addon message, the replies arrive over the
  next few seconds, and the panel already redraws when they land — so the
  only thing the click ever added was the player having to know to click
  it. Throttled to one ask per ten seconds so flipping between tabs does
  not queue a request per switch.
- **The vault strip above the page is gone.** The dashboard already draws
  the Great Vault, in more detail and where a player looks for it, so
  this was the same three numbers a second time -- charging a whole row
  of height for them on the page with the worst vertical pressure in the
  addon. That row goes back to the cards, which is what was overflowing.
- **Rating goals you have already passed are hidden.** A full bar reading
  "2000 Done" is a row spent on something you cannot act on, in the card
  whose whole job is what to do next, and it pushed the focus list under
  it further down. The last milestone stays when every one is passed, so
  the card is never empty.

### Loot browser
- **A pass is refused if the journal ever answered for a boss we did not
  ask about.** Every loot row names the encounter it belongs to, so a row
  naming a different one is proof the journal's single global selection
  moved between our `EJ_SelectEncounter` and our read — which is the
  actual mechanism behind the identical-loot bug. Checked per row, and
  tolerant of clients that do not supply the field: absent means "cannot
  verify", not "wrong".
  - This catches the case the shape check cannot: a selection that moves
    part-way through a sweep corrupts some rows and not others, which
    looks entirely plausible and would be cached and served as fact.
- **A pass where every boss drops the same thing is refused, saved or
  loaded.** That is not loot — it is one encounter's list copied across
  every row, which happens because the Encounter Journal has a single
  global selection and anything that re-selects underneath a running
  sweep makes `EJ_GetLootInfoByIndex` answer for whichever encounter won.
  Prevented upstream by never sweeping while the Adventure Guide is open,
  but prevention is a guess about every way the selection can move and
  this is a fact about the result. Checked on the way **in** as well as
  out, so a bad pass already written to disk is thrown away rather than
  only being prevented for players who never had one.
- **`/yh lootreset`** throws away all saved loot browser data — on disk
  as well as in memory — and rebuilds on the next open. The ordinary
  cache clear deliberately keeps the saved copy, which is right for
  routine invalidation and exactly wrong when the saved copy is the
  problem.
- **The instance list is written down instead of rediscovered every
  session.** Which raids and dungeons exist, and which bosses are in
  them, does not change until the game patches — yet finding it out cost
  a walk through every tier of every expansion in the Encounter Journal,
  once per login, whether or not anybody opened the panel. It is now
  saved and stamped with the game's interface version plus the addon's
  own, so a patch or an addon update looks again and nothing else does. A
  copy that is stale, malformed or empty is rebuilt rather than trusted,
  and an ordinary cache clear keeps it — only an explicit forget drops
  it.
- **The loot itself is written down too, so a reload does not refetch
  it.** Which items a boss drops is as fixed as which bosses exist, and
  fetching it is the bulk of the sweep — the instance walk finds a few
  dozen bosses, then every one of them is asked at every difficulty.
  Saved under the same stamp as the instance list, so a patch or an addon
  update invalidates both together and nothing else invalidates either.
  Stored whole, links included: the compact form would be item ids with
  the rest rebuilt on load, and that trades disk for a panel that renders
  blank until the client returns item data.
- **The journal link index is written down too.** `GetJournalItemLink`
  maps an item id to the journal's own link for it, and building that
  index is a third walk of the Encounter Journal — lazily, the first time
  the Best in Slot or Trinkets page asks about a row. Which item the
  journal lists for a boss changes when the game patches and at no other
  time. Saved under the same stamp as the instance list and the rows, so
  all three invalidate together and nothing else invalidates any of them.
  An empty index is still never accepted, saved or built: the journal is
  not always populated when first asked, and an empty one served as fact
  leaves every page showing base items with no way back.
- **The login prewarm no longer runs while you are inside an instance.**
  It is a nicety — it makes the first panel open feel instant — and it is
  thousands of Encounter Journal calls fired five seconds after a loading
  screen, on a client that is still busy with one. Zoning into a dungeon
  is the version of that where you can least afford it. It now waits
  until you are somewhere quiet.
- **Redrawing the list no longer hides whatever tooltip you were
  reading.** `ReleaseAll` called a bare `GameTooltip:Hide()`, and
  GameTooltip is one frame shared by the entire UI — so every redraw hid
  a bag item's tooltip, a spell's, another addon's panel. The list
  redraws on `ITEM_DATA_LOAD_RESULT`, which fires once per item as data
  streams in, so after a loading screen it fired in batches for as long
  as the client took to catch up. It now hides the tooltip only when the
  owner is inside the loot browser.
- **Half the journal sweep never yielded.** The instance cache is built
  inside a coroutine with a 16ms frame budget, and the dungeon walk hands
  the frame back at each tier and each instance -- but the raid walk did
  not yield anywhere at all, so every raid of every expansion, and every
  boss inside each one, ran in a single unbroken stretch. Neither boss
  loop yielded either. The budget the scanner is built around simply did
  not apply to half its work, and this runs a few seconds after a loading
  screen. Measured: the same sweep now spreads over 141 frames instead of
  132.
- **Bounded the journal walks.** Each was a `while true` whose only exit
  was the Encounter Journal returning nil for the next index — the
  documented shape, and also a hang if the journal ever declines to say
  no, which is a real risk on the API least settled right after a loading
  screen. The caps sit far above anything the game ships (verified as
  having no effect on what is scanned); they are the difference between a
  bug that stops and one that takes the client with it.

### Diagnostics
- **`/yh trace`** — times the addon's own functions and says, on screen,
  when one of them eats a frame. Built for a freeze that only happened
  after a loading screen: a hang throws no error so !BugGrabber has
  nothing to catch, and SavedVariables only flush on a clean exit, so
  anything written for the next login is lost when the client has to be
  killed. Counting as it happens is what is left. The setting survives a
  `/reload`, because the window worth watching is the one right after
  one. `/yh trace report` for totals — call counts as well as time,
  since the problem below was never a slow call.
  - It cannot see inside a loop that never returns; nothing in Lua can.
    That is what the load gate below is for.
  - **The loot sweep is now named.** The first real stall this caught was
    9.6 seconds and reported "not inside anything we wrap" — true, and
    useless: the sweep runs in a coroutine driven by an OnUpdate script
    and the cache it builds is a file-local, so neither is reachable from
    a list of functions hanging off the namespace. `Trace:Section` times
    a block that runs to completion (the coroutine driver, where the
    frames are actually spent) and `Trace:Mark` names one that yields
    without timing it, since a parked coroutine's elapsed time is wall
    clock rather than work. A stall now says `loot: sweep slice`,
    `loot: instance cache` or `loot: journal sweep`.
  - **The raid path is now watched too.** Stalls of 3.6s and 6.1s landed
    on "Party converted to Raid" and an LFR zone-in rather than a plain
    loading screen, and nothing on that path was instrumented. Added
    `RefreshRaidPage/Overview/Display/Groups`, `ScanRaid` and the tier
    data helpers, plus `interrupts: rebuild` and `readycheck: roster` —
    both locals, named at the call site, both firing on every roster
    change.
  - `LootBrowser_RefreshDisplay` and `RefreshWatermarks` added to the
    wrap list — both redraw off item data streaming in, which is exactly
    what a bag full of new loot produces.
  - **The frame watchdog now reports what share of a stalled frame was
    ours**, instead of which function we were inside. The old version was
    broken by construction: an `OnUpdate` runs *between* frames, after
    every wrapped call has returned and cleared that field, so it printed
    "not inside anything we wrap" every single time — and a run of real
    multi-second stalls got read as the addon being innocent. Every
    wrapped call now adds its elapsed time to a per-frame total that
    clears between frames, so whatever ran during the frame that stalled
    is still counted when the next one arrives.
  - It reports at 250ms rather than 50ms.
    The frames right after a loading screen are legitimately long, so the
    lower threshold printed a wall of noise on every load and buried the
    one line worth reading.
- **`/yh loadtest`** — holds back the expensive jobs that normally run
  themselves a few seconds after a loading screen, gives each one a name,
  and runs them by hand from a client that is already up. Whichever
  command does not come back is the one, and it is the whole bisect in a
  single session rather than a restart per guess. Currently names
  `loot` (walks every tier of every expansion through the Encounter
  Journal), `keystones` (a guild request now returns a reply from every
  BigWigs user in it) and `window` (opening on login builds the dashboard
  and whatever page it lands on).
  - **`/yh loadtest only <name>`** is the mode that actually reproduces
    a loading screen: it lets exactly one job run where it normally runs,
    at the moment it normally runs, with the rest still held. One reload
    per job. Running a job by hand cannot reproduce load conditions and
    should not be read as if it does -- by then the caches it fills are
    already full, the journal has settled, item data has arrived and
    nothing else is competing for the frame.
  - By-hand runs now clear the job's own caches first and wait for its
    asynchronous tail, reporting the worst frame seen while waiting. The
    first version timed the handoff rather than the work and reported
    0ms for every job -- a diagnostic that clears everything is worse
    than none.
  - Why a flag rather than a post-mortem: SavedVariables are flushed on a
    clean exit and a killed client never has one, so nothing a frozen
    session learns about its own death survives it. A flag set *before*
    the freeze does survive, because the `/reload` that triggers it
    writes the file on the way out.

### Performance
- **The six-second freeze, found and fixed.** `ns:RefreshWatermarks` was
  measured taking **5911ms of a 6314ms frame — 94% of it** — on a player
  zoning between a dungeon and the world. Sixteen slots in a single pass,
  each up to three `C_ItemUpgrade` calls, and those are not cheap while
  the item data behind them is still loading, which is exactly the state
  after a loading screen. It runs from the `UNIT_INVENTORY_CHANGED`
  handler, which fires when you zone.
  - It now asks about **one slot per frame** instead of all sixteen at
    once, so even a cold pass costs a slot per frame rather than a stall.
  - And it only asks about slots whose item actually **changed** since
    the last answer — which on a zone is usually none of them. A slot's
    mark is the client's answer about the item in it; with the same item
    equipped, the previous answer stands.
  - Marks only ever go up and are persisted, so arriving a few frames
    late costs nothing.
  - **And a reload now asks nothing at all.** The marks always survived a
    reload; what did not was the record of *which item* each one was an
    answer about, so every session re-asked all sixteen from scratch. A
    reload cannot change what is equipped, so a mark recorded last
    session against the piece still in the slot is still the client's
    answer. Only a slot whose item genuinely changed is asked.
  - A mark can also rise from a piece binding in the bags, which does not
    change the equipped item — that case is covered separately by
    `BoundBagFloor`, which reads the bags directly rather than asking the
    client.
- **One draw of the suggestions panel asked the client for a slot's item
  over a thousand times.** `ns:GetSlotInfo` is the bottom of nearly every
  gear question the addon asks, and only the tooltip half of it was
  cached -- the item link, the ItemLocation and two pcall'd `C_Item`
  reads ran every single time, measured at 1285 calls for one refresh.
  It is now cached on exactly the same lifetime as the tooltip scan it
  wraps, empty slots included, since both go stale together.
- **...and none of it was being cached in the window where it hurt.**
  `ScanUpgradeTrack` records a result only when the tooltip parses. Right
  after a loading screen the item data has not arrived, so *nothing*
  parses, nothing is cached, and every one of those thousand-odd reads
  builds a full `SetInventoryItem` tooltip -- while several panel draws
  land in that same window as currency, bag and roster events arrive
  together. That is a stall that happens specifically after a loading
  screen and nowhere else. A read taken before the client is ready is now
  held for the current frame only: a burst inside one frame collapses to
  sixteen reads, and the next frame asks again and gets the real answer
  as soon as there is one.

### Gear
- **The advisor knows you can craft the thing.** Several specs are told
  by their own best-in-slot list to MAKE a piece rather than kill
  something for it, and every rule in the upgrade advisor priced the
  vendor route only -- so it would happily talk you into spending the
  exact 80 crests the craft you are saving for needs. A slot the guide
  says to craft now reads "Craft instead", with what it costs, what it
  lands at and why that beats anything crests can do to what is in the
  slot today; the other rows on that tier say where the 80 went rather
  than quietly reporting less to spend. Gated on a Spark of Tides
  actually being in your bags -- sparks are the half that does not
  refill, and advice to hold crests for a craft you cannot start is just
  advice to stop spending. One craft held for at a time, and the tier it
  aims at is the best one this season's cap can still reach, not the
  first one you happen to be able to afford tonight.
  - A bare slot the list says to craft used to say nothing at all: the
    improvements list drops empty slots, which is exactly where a craft
    is the whole answer.
- **The strip of per-wallet sentences above Improvements is gone.** Three
  paragraphs about crest tiers sat between the player and the list of
  slots they were about -- on a page read for the next thing to click.
  Everything they said about a slot is on that slot's row and its hover.
  What is only true of a whole wallet -- how far the tier gets, how many
  weeks the shortfall is, what a craft has taken off the top -- moved
  onto the crest tiles beside the paper doll, where the balance already
  lives. Hover one.
- **A crest tier is now counted over slots, not over the pieces you are
  wearing on it.** Every demand figure in the addon priced the pieces
  currently on a track, which is the wrong set: a Champion crest is spent
  on every slot that will ever hold a Champion item, including the ones
  still wearing Veteran, still wearing nothing, or waiting on a drop.
  Counting only what was worn made the bill look small, the wallet look
  scarce, and every rule downstream reach for "hold".
  `ns:GetSeasonDemand` prices it forward instead, off the watermark:
  ranks at or under a slot's mark are free, so the cost of taking a slot
  to a track's cap is the ranks above its mark -- whatever is in it now,
  and whether or not anything is. A Myth piece takes a whole slot off the
  Hero bill, because the mark it sets is past the Hero cap. Ten Myth
  pieces leave six slots at five ranks each, and 600 Hero crests covers
  the lot.
- **"Enough available to max all 6 slots without worrying about running
  short."** When everything a tier could ever want fits inside what you
  can still get, the tier is not scarce, and the rules that ration it
  stand down: the reserve keeps nothing back, the hold-for-a-drop bet
  stops firing (with crests for every slot, both happen), "Hold crests"
  becomes "Upgrade later -- this one is covered too", and the overlap
  warnings -- find a Champion piece to skip the first Hero rank -- go
  quiet, because that trick saves crests and there is nothing to save.
  The sentence says which promise it is making: *in hand* is spend it
  tonight, *available* is you will not be short by the time the drops
  land.
- **A slot's bill is priced off the mark it will have, not the one it
  has.** A slot wearing a Champion 1/6 reads as five Hero ranks, but
  that piece gets taken to the Champion cap first -- the addon says so
  on its own row -- which marks the slot at 308 and leaves four. Ten
  Myth, five Hero and one Champion at 1/6 is 500 + 100 Champion + 80,
  not 600; the addon had been disagreeing with the player's arithmetic
  about an upgrade it had already recommended.
- **A track you own no pieces of can now be advised on.** Wearing nothing
  on a track ended the answer, which silenced exactly the case worth
  hearing: 600 Hero crests and no Hero piece yet means the crests are
  already sorted and only the drops are missing.
- **The improvements list now says what a whole wallet can do, not only
  which slot is next.** Three lines head it — the highest crest tracks
  with something left to buy — each answering the question a capped
  player actually opens the panel with: how much this track wants, what
  is in the wallet, and whether the season cap still allows the rest.
  The arithmetic has been in `ns:GetTrackPolicyLine` since it was
  written and nothing had ever called it.
- **Held crests and earnable crests are stated apart.** The budget they
  add up to was printed as one number described as income -- "120 to
  finish them all and 240 coming" -- which counted crests already in the
  bags as though none of them were there. It now reads "you hold 40 and
  the cap allows 200 more".
- **"Need 80 more Champion" now says where the 80 comes from.** Every
  rank in the spend plan carries a flag for whether the season cap
  reaches it, and nothing read it, so a slot two keys from affordable
  and one the cap cannot cover this week gave the same line. Three
  answers now: farmable this week, waiting on a reset, or -- only on a
  track the content has outgrown, where crests arrive as overflow from
  capping something higher -- wanting a drop instead.

## v3.1.1 - Closing the window in combat (2026-08-19)

### Fixed
- **The X closes the window mid-fight.** Once the Mythic+ or Teleports
  page has been opened, the window holds secure action tiles and a frame
  holding a protected frame is protected itself, so the client refuses
  to hide it and the close had to wait for the fight to end. The X now
  carries a secure handler, which is allowed to hide a frame it holds a
  reference to in combat -- the same mechanism that hides an action bar
  on a state driver.
- **A window with no secure page open no longer waits either.** Before
  Mythic+ or Teleports has been mounted nothing about the window is
  protected and an ordinary hide is legal mid-fight, but the close was
  deferred anyway, on the assumption rather than the fact.
- `/yh`, the minimap button and anything else script-driven still close
  at the end of the fight, because a snippet only runs off a real click
  and clicking a protected button from code is blocked in turn. The
  notice says where the X is rather than only promising to close later.
- Escape is unchanged and still does nothing mid-fight. Making it work
  means an override binding, and those cannot be cleared in combat
  either, so a window closed during a pull would go on swallowing
  Escape -- and the game menu with it -- until the fight ended.

## v3.1.0 - The raid guide, the boss trainer, and healer trinkets (2026-08-19)

### Raid
- **A boss guide for the current raid, `/yh guide`.** Every boss rewritten
  against a real per-boss source rather than paraphrased generalities:
  the Tidebound Grotto added, Nymrissa made playable, Nek'zali written by
  someone who actually watched the fight, Vashnik's three phases stated
  plainly as the guide's own sections, and the Soulcoil Well and Jawae's
  Echoes named as the fight names them. Laid out by a solver, so a card
  grows with its text instead of being guessed at a fixed width.
- **A boss trainer, `/yh train [boss]`.** Practise the mechanics without
  the raid: eight fights run end to end, the two-boss encounters get
  their second boss, the Sentinels' stasis is a solvable puzzle rather
  than a coin flip, alternating soaks alternate, Frostfire Volley carries
  one element and clears in the other, and the Coiled Altar's orbs
  survive the push. Difficulty comes off one dial rather than forty.
  Nothing fires or spawns before the countdown says GO, ranged hold
  station instead of running into melee, and every instant mechanic
  names itself as it happens. Per-frame garbage cut by 44%, measured.

### Trinkets
- **Healer rankings, from QE Live.** bloodmallet sims damage and
  publishes nothing for the seven healing specs, so those now come from
  questionablyepic.com instead -- raid and dungeon, ranked at each
  trinket's own ceiling with the item-level curve that goes with it.
  Coverage goes from 31 specs to 38 of 40; Augmentation and Brewmaster
  are in neither source.
- **The loot council list splits damage specs from healers.** The two
  sources divide by different things to reach "percent behind your best"
  -- a share of total DPS against a share of the best trinket's healing
  -- so one sorted column ranked by which project simmed you rather than
  by who wants the item, and buried a Holy Priest's fourth best trinket
  under an Arcane Mage's sixteenth. Each side now has its own subhead
  saying what its percentages measure, with yours first. The colours
  follow the same split: the healer bands are the cutoffs that put the
  same share of rows in each colour as the damage bands do.
- Trinket tooltips split their five lines between the two sources, so a
  healer hovering a trinket is no longer shown five damage specs, and
  the attribution names whichever project ranked what you are reading.
- **Re-scraped from bloodmallet.** 21 specs came back with fresh runs.
  Assassination gained a single-target list it did not have, and
  Assassination AoE, both Outlaw lists, both Demonology lists and
  Protection Warrior's AoE moved onto this season's numbers. Eleven
  specs still carry last season's ranking for at least one fight style
  and say so, rather than being dropped.

### Delves
- **A Delves page.** Your companion and where its next upgrade sits, the
  week's coffer keys, and the tier ladder. Everything is asked of the
  client at runtime -- no companion, faction, curio or season ids are
  written down, because a stale one does not error, it reads as zero and
  turns the page into a confident lie.

### Elsewhere
- **The windows that open on their own now share a home.** Ready check,
  dungeon utility notes and the after-key summary can be dragged
  wherever you like whenever they are open, and each remembers its own
  place.
- **A key binding** to toggle the window, under Blizzard's own bindings.
- **Stat priority is answered in one place.** The Best in Slot page can
  afford to show two hero builds disagreeing; the character column has
  four rows and has to pick the build you are actually specced into.
  Both read the same parse of the same guide.
- **Mythic+ utility notes per dungeon and class**, generated rather than
  hand-kept. The mechanic-to-utility mapping is derived from Mythic Plus
  Utility's curated tags (by Nikyou); the prose is ours.

## v3.0.6 - Post-tuning re-sim, and trinket shortlisting (2026-08-15)

### Data
- **Trinkets re-scraped after the 14 August trinket tuning.** Twenty-four
  trinkets were retuned and the rankings moved a long way with them:
  Gebbo's Bottomless Bag (secondary effects -29%) falls from 1st to 6th
  for Shadow and 2nd to 7th for Fire, Hex Lord's Dooming Idol climbs to
  2nd for Fire off its rework, and Vexhul's Everflowing Gland goes 17th
  to 4th. Gaze of the Alnseer (-20% primary) drops out of the list
  entirely for some specs. Thirty-four blocks carry today's sim.
- Zul'jin's Guillotine Technique now ranks for tanks, following the
  hotfix that let them roll Need on it -- top pick for Vengeance and
  Protection Paladin, second for Blood.
- Class guides re-scraped: a stat priority reorder, corrected boss
  sources, restructured Preservation Evoker builds and new bonus IDs.
- Consumables re-scraped: gem, food and health potion changes.

### Trinkets
- **Right-click a trinket to add it to your list.** Shortlisted trinkets
  carry a star in both tabs. It is the same list the Loot Browser's
  favourites star writes to, so the two pages cannot drift -- and a
  shortlist rather than a slot assignment, because "I want this" is true
  of several trinkets at once when two of them are within a percent of
  each other and only one is going to drop.

### Fixed
- **Favourites were stored against the wrong specialization.** The store
  read the Loot Browser's own dropdown, so a mark made from anywhere else
  landed under whichever spec that page happened to be showing, or went
  nowhere at all if it had never been opened. It now takes the spec
  explicitly, and pages outside the Loot Browser mark against the spec
  being played.

## v3.0.5 - Season 2 trinket sims for 17 specs (2026-08-13)

### Trinkets
- **Season 2 rankings, single target and 5-target.** bloodmallet has
  re-simmed 17 specs for the new season so far: all three Death Knight
  specs, Vengeance, all three Hunters, all three Mages, Protection
  Paladin, Shadow, Subtlety, Elemental, Enhancement, Affliction and
  Destruction. The rest are still on Season 1 numbers upstream and say
  so per spec rather than being dropped.
- Blood, Vengeance, Fire, Protection Paladin and Shadow gained a
  5-target list they did not have, so the AoE tab no longer sends them
  back to single target.
- **Scaling bars, and an item level stepper.** Each row now carries a
  bar split at every item level that trinket was simmed at, the way
  bloodmallet draws it: length is the gain over an empty trinket slot,
  each segment is what the next item level added, and hovering a segment
  names the level, the gain and where the trinket drops. A stepper above
  the list walks the item levels and re-ranks everything at the one
  picked, so "this beats that at 311, and loses to it at 331" is a
  question the page can answer instead of only ever showing the best
  case. It is a stepper rather than a dropdown because the useful move
  is walking the ladder and watching rows overtake each other -- picking
  a number from a menu means guessing which number to pick.
- Ranking at a chosen item level only lists trinkets simmed at exactly
  that level, which is often a short list. Filling it out from each
  trinket's nearest step would rank a 331 against a 318 and present the
  item level gap as trinket quality. Item-level detail is kept for the
  top 15 per spec and fight style, and specs still on Season 1 have
  none -- that detail was never scraped and only a re-sim brings it back.
- **Each trinket is ranked at its own item level.** bloodmallet stopped
  simming everything over one shared range -- a crafted trinket caps
  lower than a raid drop, and a few items exist at exactly one item level
  -- so the scraper's old rule of comparing at the highest level every
  trinket shares matched nothing and returned an empty list for all 40
  specs. Each trinket is now taken at its own ceiling, which is what
  bloodmallet's own chart ranks by, and that item level is printed on
  each row: two trinkets a hair apart can be a fair fight or a 13-item-
  level head start, and only the number beside them says which.
- **Fixed: the ranking disagreed with its own numbers.** Rows could read
  "#7 -2.7%, #8 -2.1%", ranking a trinket below one it beats. The order
  came from bloodmallet's ranking, which sorts by each trinket's own top
  item level, while the percentage was computed at the one item level
  they all shared -- two different questions. Affected every spec still
  on Season 1 data; on Balance Druid it had Crucible of Erratic Energies
  sitting at #22 on a number that belonged at #6.
- **Loot Council lists this season's dungeon and raid drops only.** It
  listed everything in the file: last season's trinkets, crafted ones,
  conquest gear and a world boss drop -- 73 items in single target where
  37 of them are things a council actually hands out. Crafted and PvP
  trinkets sim fine and some of them are strong, but none of them is
  going to be linked in raid chat with five people typing "need".
  Everything else still answers a tooltip: hovering one, you already
  know it exists, and which specs ranked it is still worth saying.
- **Trinkets from older content are hidden, with a checkbox to show
  them.** bloodmallet goes on simming last tier's trinkets, and a couple
  from expansions ago -- Emberwing Feather, Algeth'ar Puzzle Box, even a
  Legion one -- so being in a current run does not mean an item drops
  now. What separates them is the upgrade ladder: a trinket from this
  season is simmed from 292 up to 331, 334 or 344, while anything
  carried forward sits at the single item level it capped out at. Ten
  of the 37 single-target entries went that way. "Show older trinkets"
  brings them back, marked, for anyone still wearing one.
- **Trinket rows show the item that actually drops, not its base
  entry.** Rows were built from the bare item ID, which resolves to the
  base item -- Rare quality, +7 Intellect, "Item Level 28" under a row
  ranking it at 334. They now use the Encounter Journal's link, the same
  source the Best in Slot page uses, so a trinket renders Epic with real
  stats and its own upgrade line. The item level is then rewritten to the
  level the page ranks it at and the rank named in place, "Upgrade Level:
  Myth 6/6", rather than tacked on at the bottom. Falls back to the bare
  item if the journal has not indexed yet -- it builds lazily and can
  miss the first ask.
- Raid trinkets sim at 344, which is above the top of the Myth track
  (334), so there is no rank to name and none is invented. Those say
  "above Myth 6/6" instead, rather than leaving a rewritten item level
  with nothing to read it against.
- Loot Council rows show the item level each trinket is ranked at --
  its own ceiling, the top of the Myth track for wherever it drops, so
  321, 334 and 344 all appear. Fixed rather than adjustable: that view
  answers "who should roll on this", and a ranking that reorders under a
  council mid-discussion is answering a different question badly. The
  item level stepper stays on My Spec, where the question is "which of
  these is better, and from what point".
- **Expanding a trinket separates the specs that have been re-simmed
  from the ones that have not.** Ranked specs are listed as before;
  underneath, every spec still awaiting a re-sim is named as "Not simmed
  for this season yet". Read as one list, a spec missing from the
  ranking looks like a spec that passed on the item, when the truth is
  that nobody has asked it yet. That group is the specs themselves, not
  the ones that ranked this particular trinket: this season's items were
  never in last season's lists, so the per-trinket version would come
  out empty for 28 of the 34 trinkets where the caveat is worth making.
  Browse order and the "best: #N" summary now come from the best
  re-simmed spec too, rather than from a placing made against last
  season's set of trinkets.
- **Fixed: stat variants rendered as identical rows.** Some trinkets are
  simmed once per stat -- "Drum of Renewed Bonds [Haste]", "[Crit]",
  "[Mastery]" -- and share a single item ID, so once the client resolved
  the real item name three separately-ranked rows became three identical
  ones. The suffix is kept.
- **Fixed: the attribution line was drawn over a leftover icon.** Rows
  come from a pool and the icon was only cleared by the callers that
  remembered to; once the header and the "Simmed ..." line moved left to
  align with the icon column, whichever trinket had used that frame last
  left its icon sitting under the text. Cleared centrally instead.
- **The page keeps its proportions at any panel width.** The panel is
  700 to 960 units wide depending on the screen, and the row scale was
  clamped so it could never go below native size -- proportional on a
  wide screen, slightly oversized on a narrow one. It now scales with
  the panel throughout, so the bar, the name column and the item level
  occupy the same share of the page on every setup.
- **Fixed: a scaling bar grew past the gain it represents.** Sim noise
  puts some item levels slightly below the one before them -- 23 such
  steps in the current data. That step was drawn as a sliver, correctly,
  but the drop was then handed back to the next segment, which drew
  wider than the item level actually gained. Bars are meant to be
  proportional to one another, so a trinket with a few noisy steps read
  as stronger than one with the same final gain and none.
- **Fixed: Loot Council rows could not be expanded.** The overlay that
  scopes the item tooltip to the icon and the name was swallowing the
  click meant for the row underneath it. Enabling mouse motion on a
  frame still makes it a hit-test target, so the click lands there and
  is dropped unless the frame is explicitly told to pass it on.
- The item tooltip is now raised by the icon and the name only, and the
  region is measured from the name actually drawn rather than from the
  column it sits in. It used to hang off the whole row -- which included
  the bar, so crossing a segment replaced the segment's own tooltip with
  the item's -- and then off the full name column, which on a wide
  window is several hundred pixels of blank row.
- **The ranked rows are drawn to suit the frame.** Ten rows left half a
  wide window empty, which is the half that would have made the bars
  readable. Those rows now magnify to the width of the frame, up to
  1.75x, so the bars, item icons and the numbers beside them grow
  together. The caveat, the spec header and the attribution stay at the
  size the rest of the addon uses -- they are prose, and magnifying them
  only makes the paragraph at the top shout. Loot Council is a lookup
  rather than a chart and is left at normal size throughout.
- The magnification comes from the frame and never from the content, so
  searching, switching spec, stepping an item level or pressing Show all
  leaves it exactly where it was: a list that resizes while you read it
  is worse than a small one. Resizing the window is the only thing that
  moves it, and it never shrinks below normal size.
- Bars follow the panel width rather than sitting at a fixed 130px in a
  window several times that wide, and are around 30% wider again.
- The item level and "vs best" column is left-aligned, so the item level
  is in the same place on every row instead of starting wherever the
  text before it happened to end. Bars stop clear of it rather than
  running into the number.
- Long trinket names are cut with an ellipsis instead of wrapping into a
  second line the row is not tall enough to show -- which cut them just
  as short, but with nothing to say they had been cut.
- **Season is tracked per spec and fight style, not per file.** A new
  season's sims arrive a few specs at a time over weeks, so re-scraping
  mid-transition used to delete every spec that had not been re-simmed
  yet -- trading a stale ranking for no ranking, which is worse. Those
  keep their Season 1 list, labelled as such in the spec list, on the
  loot council rows and in the item tooltip. The page-wide warning now
  fires only when nothing in the file is current. A spec can be Season 2
  on single target and Season 1 on 5-target, and is marked per tab.

## v3.0.0 - Mr. Yeeper, Best in Slot, and a season's worth of gear maths (2026-08-12)

### Mr. Yeeper
- The Upgrade Summary is now a character. He reads your gear, crests,
  vault, keystones, raid lockouts and guild activity, works out which
  single fact is worth saying, and says it -- rudely.
- He is a reasoning layer, not a quote list. A snapshot gathers facts, a
  set of rules recognises situations and computes, and the personality is
  applied last to a conclusion that was already reached on evidence.
- Priority ordering decides what he says. Something being actively wasted
  (idle crests, a capped week) always outranks entertainment, because a
  joke is worthless while 200 crests rot in a bag.
- Actionable messages carry tips underneath: the "so what do I do" that a
  remark on its own leaves hanging.
- **Season aware.** Keystones go live a week after the patch, so during
  the first week he will not send you at Mythic+ content that does not
  exist yet, and points at Mythic 0 and Heroic instead.
- **Socially aware.** Remarks about never grouping with guildmates are
  gated behind actually having a guild with people in it. There is no
  version of that joke that lands when the honest answer is "I do not
  have one", so those lines are never generated rather than softened.
- Jokes are sourced from the community (punsnjokes.com, laffgaff.com,
  punorbit.com) and keyed to your class, race and level. His reluctance
  to deliver them is the second layer.
- Lines are picked at random with a short memory, so a strict rotation
  cannot make the running order predictable.
- **He knows where keys stop paying.** +10, +11 and +12 all drop 311 and
  all vault 318, so above +10 a higher key buys rating and nothing else.
  The game never says this and people grind +12s believing the vault is
  still climbing. The ceiling is derived from the key table rather than
  written down, so correcting a row moves the answer instead of leaving a
  stale number behind it, and he only raises it with players who have
  actually gone past it -- said to someone sitting at +5 it is not an
  observation, it is a reason to stop trying.

### Best in Slot (new page)
- Every spec's best-in-slot list, scraped from Wowhead's class guides,
  laid out as a paper doll: the icons sit where the character panel puts
  them, so "how far off am I" is one glance rather than reading a list
  and rebuilding the shape in your head.
- Items resolve through the Encounter Journal, so they render as what
  they actually are -- Epic quality, real stats, the right item level.
  A modern item's base entry is Rare at item level 28 with "+5
  Intellect", which is a real number answering a question nobody asked.
- Item level and upgrade rank come from the same GEAR_TRACKS the Loot
  Browser uses, so both pages can never disagree about what a rank means.
- **Bags count.** A drop you have not equipped yet is still a drop you
  got. The doll shows four states: missing, in your bags, have it at a
  lower rank, and have it at the target -- because "have it" and "have it
  at the rank this list means" are different answers.
- Stat priority per spec, and an honest caveat that this is a starting
  point rather than a substitute for simming.

### Crests
- **Fixed: the addon was reading the wrong currency.** There are two
  complete sets of Mistcrest rows in the client and the addon pointed at
  the dead one, so a character holding 80 Champion Mistcrests read as
  zero -- and affordability, the waste warning and every upgrade
  recommendation were computed against an empty wallet. Both rows of a
  pair share a name *and* a description, so nothing in the game
  distinguishes them.
- Crest IDs now re-resolve whenever the wallet changes rather than once
  at login. Resolving once was worst exactly when it mattered: on a fresh
  season you have none of either row, so the pick was a coin toss that
  then never got revisited.
- Warns *before* a wasteful crest spend, not only after. Hero 5->6 and
  Myth 1->2 cover the same item level band at the same price, so spending
  the scarce crest there is dominated by spending the one that goes dead
  in three weeks.

### Teleports
- Reorganised so every teleport has one home: the expansion its dungeon
  came from. The current season is a view over those same entries, not a
  copy, so a returning dungeon appears twice and cannot read as unlocked
  in one place and locked in the other.
- **Fixed: returning dungeons read as locked.** A dungeon brought back
  for a new season can be unlocked from either its original expansion or
  the current season, and only the season's spell was checked -- so a
  Ruby Life Pools port earned in Dragonflight showed as missing.
- Rolling to a new season is now editing one list of names.

### Trinkets
- Top ten by default with a search box and autocomplete, instead of every
  trinket at once.
- **Fixed: clearing the search did not reset the list.** The clear button
  empties the box programmatically, and the handler ignored anything that
  was not typed -- so the text vanished while the filter stayed, with no
  way back short of a reload. Clicking a suggestion failed the same way.
- **Fixed:** the "Search" placeholder drew on top of what you typed.

### Consumables
- Guides now scroll instead of running off the bottom of the panel.
- Tooltips follow the cursor rather than pinning to the far edge.

### Fixed
- **Blizzard settings panel threw on every module row.** The module
  toggles it reads were never implemented, so opening settings errored --
  and the two features that honour them were silently always on.
- **Views only refreshed on the home page.** Spending crests, upgrading
  an item or equipping something left the Gear Upgrades page unchanged
  until you navigated away and back. Every state change now reaches
  whichever view is actually on screen.
- The Great Vault filling was not signalled to anything, so a finished
  key left the Mythic+ page showing an empty slot.
- Omnium Folio's unlock check tested the first quest in its chain instead
  of the last, so it reported locked for anyone who had finished it.

### Edit Mode
- Every movable frame -- interrupt tracker, battle res timer, ready check
  overview, Mythic+ summary and utility advisor -- now positions through
  Blizzard's Edit Mode via LibEditMode, with native selection outlines,
  "Click to Edit", grid snapping and proper settings dialogs.
- The old per-frame Unlock/Lock buttons are gone. They could not work:
  the settings window is not movable and covers the screen, so you
  unlocked a frame and then could not see it.
- A toggle panel anchored to the Edit Mode manager picks which frames are
  conjured for editing, since showing five at once buries the screen.
- Positions are stored per Edit Mode layout, so a raid layout and a solo
  layout can place the same frame differently.

### Settings
- Rebuilt on Blizzard's Settings API. Real checkboxes, the Defaults
  button, keyboard navigation and options search -- inherited rather than
  reimplemented. Saved variables are untouched; every entry is a proxy
  over the existing getter and setter.
- One page instead of four subcategories. Once appearance and position
  moved to Edit Mode, what remained was a dozen switches.
- Appearance settings live in Edit Mode, where you can see the change as
  you make it. Each settings section points at it.

### Gear: crest-efficiency warnings
- **The addon now warns you before a wasteful crest spend.** Every Season
  2 track overlaps the one below it by two ranks, so Hero 5/6 -> 6/6 and
  Myth 1/6 -> 2/6 both land on 321 and both cost 20 crests. The game
  charges the same either way and never mentions that only one of those
  two currencies still has a season of use in it.
- Myth crests buy ranks 3-6 and nothing else does. Hero crests go dead the
  week every Hero-track slot is maxed, around week 3-4. Spending the
  scarcer crest inside the overlap is strictly dominated -- it buys an
  item level the cheaper crest was going to give you anyway.
- The same shape one tier down: Hero crests on Hero 1/6 -> 2/6 duplicate
  Champion 5/6 -> 6/6 at 308. That one only starts mattering once you are
  farming +10 keys and Champion crests have gone abundant, so it is gated
  on the profile rather than shown to everyone from day one.
- Slots get a red "Wasteful crest spend" verdict naming the crests at
  stake, the item level band, and which lower-track piece to put the cheap
  crests into instead. With nothing left on the lower track to spend on it
  softens back to the old "use cheaper crests" note -- the advice is still
  true, but there is no move to make.
- Mr. Yeeper reports it across the whole character, just under idle
  crests in priority. Several wasteful slots on different tiers are
  totalled per crest track, and the suggested sinks are grouped by which
  crest actually pays for them.
- Tracks whose crests are abundant for your profile are no longer nagged
  about at all. Veteran ranks used to draw the promotion note even though
  Veteran crests are free and there is nothing to save.

### Fixes
- **M9 great vault was wrong**: 318 corrected to 315 (Hero 4/6). Myth 1/6
  does not start until M10.
- That M9 correction only landed in one of the two key tables. The
  Progression page reads its own copy and went on showing 318, so the
  page and the upgrade advisor disagreed about the same key level. Both
  now say 315, with the duplicate pointed at the original as the source
  of truth.
- Mr. Yeeper claimed the vault was the only way to replace last season's
  gear. Dungeon and raid drops, delves, world content and crafting all
  do, and the tips now say so.
- "Biggest single jump" described an item's entire remaining track rather
  than one upgrade step, overstating it badly.
- The interrupt tracker never re-showed pooled slots after a rebuild, so
  the first rebuild worked and every one after it produced an empty
  frame.
- Test mode persisted across reloads, stranding the tracker showing five
  dummy bars with no switch left to turn it off.
- The tracker drew a bare bordered rectangle when it had nothing to show.
  It now hides when empty, and no longer draws an outer border at all --
  each bar already has one.
- Frames could end up off-screen: the Edit Mode handoff discarded the
  relative anchor point, so a frame anchoring its TOPLEFT to UIParent's
  CENTER moved by half a screen.
- The settings panel could not be opened from anywhere -- the category ID
  was being overwritten with a string, so OpenToCategory silently failed.
- Progression's subtitle leaked through the app frame's own page title.

### Out of beta
- The **Interrupt Tracker**, **Mythic+ summary** and **Utility Advisor**
  are no longer beta-flagged. They have been in use across a full season.

### Also
- A jump counter on the character bar, live-updating. It does nothing.
- This "what's new" notice, shown once per version. `/yh whatsnew`
  reopens it.


## v2.12.0 — Omnium Folio page + PTR shakedown (2026-08-09)

### New: Omnium Folio page
- Tracks the five-week Rune chain from your real quest state
  (`C_QuestLog`), not a checklist you maintain by hand — so it is correct
  on every character and cannot drift.
- Shows live objective progress when a step is in your log, and falls
  back to counting the drops already in your bags when it is not.
- Calls out the unlock chain separately when you have not started it, and
  points at Magister Umbric in the Lycaneum for the weeklies.
- A Runes tab lists all five rows and their choices, greyed until the
  step that unlocks them.
- **Clickable waypoints.** Coordinates are buttons that drop a real
  Blizzard map pin and super-track it, rather than a `/way` string you
  have to copy. Shared helper, so any page can use it.
- Card-based layout with status stripes and pills, five progress pips,
  and hoverable item chips with real tooltips for the collectibles.
- The "Week N" labels are Blizzard's quest titles from when the chain
  released one step per reset. Anyone starting now is catching up and can
  usually take several at once, so the page says so rather than implying
  you have to wait a week between steps.
- Included because the Runes last the rest of Midnight: an unfinished
  Folio is permanent lost power going into Season 2.

### New icon, and a 49 MB Media folder down to 82 KB
- New mark everywhere: a gold four-point compass rose on a runed purple
  plate, hand-painted in Blizzard icon style. Minimap button, app header,
  dashboard and the AddOns list all draw the same art.
- Four points, not eight: below ~24px each point needs roughly 3px of
  width to survive downsampling, and eight of them around a circle that
  small collapses into a cog.
- **The minimap button now fills its ring.** LibDBIcon draws the icon at
  18x18 inside a 31x31 button and shows only the middle 90% of the
  texture, which left the mark floating small inside the tracking border.
  It is now 20x20 with the full texture visible. Press feedback is kept
  but inverted — the icon dips inward while held rather than sitting
  permanently cropped and springing outward on click.
- One full-bleed texture everywhere, with each caller deciding its own
  spacing by sizing its box. A cut with a built-in margin was tried for
  the inline icons, but once those boxes grew the padding only made the
  mark look small — spacing belongs to the layout, not the texture.
- The header icon is 32px, up from 22, and the header itself is 2px
  shorter with 6px less dead space beneath it. It is centred on the band
  between the window edge and the content panel rather than on the header
  alone, which is what made it look like it was riding high.
- The 8% texcoord crops on the app header and dashboard icons were
  removed; against full-bleed art they sliced the octagon's flat sides.
- `/yh icon [size] [x] [y]` tunes the minimap icon's size and offset live,
  since ring fit can only be judged on screen.
- The icon texture was 844x880 (not a power of two) and 2.8 MB; it is now
  a 128x128 32-bit TGA at 64 KB.
- `bmc-logo-yellow.tga` was **3200x3200 and 39 MB**, displayed at 26x26.
  Resampled to 64x64 (16 KB).
- Removed `icon.tga`, `minimapbutton.tga` and `bmc-button.tga` — 7.3 MB
  that nothing in the addon referenced.
- `Art/icon-master.png` is the source of truth; `Tools/make_icon.py`
  re-cuts the whole set from it. Both are excluded from the packaged zip
  along with the CurseForge art.

### Dashboard
- Upgrade Summary now counts slots holding gear with **no upgrade track**
  (last season's pieces). They were previously invisible — neither
  upgradeable nor maxed, just missing from every count.
- Upgrade Summary reports a crest **shortfall** when you cannot afford
  everything pending, excluding free watermark upgrades.
- Tonight's Plan surfaces the **Bonus Roll threshold**. Three filled vault
  slots unlocks it, counted across all rows combined, so it is easy to be
  one slot away without any single row hinting at it.

Everything below came out of testing against the live 12.1 PTR. Most of
it is corrections to data or assumptions that only broke once real
Season 2 content was in front of them.

### Item levels corrected against the game
- **Raid drops are rank 4/6 of their track, not rank 1.** Verified from
  in-game tooltips (Raid Finder reads "Veteran 4/6 / 289"; Mythic reads
  "Myth 4/6 / 328"). LFR 289, Normal 302, Heroic 315, Mythic 328.
- **Dungeon keystone levels** re-verified against the community sheet's
  Dungeons Drops column. They walk one upgrade rank per step from
  Champion 1/6 at M0 to Hero 3/6 at +10, anchored on M0 = 292 which an
  in-game tooltip confirms.
- Where tracks overlap (305 is both Champion 5/6 and Hero 1/6) the higher
  track wins, matching what the game itself reports.

### Loot Browser
- **Difficulty selector.** Pick the content level you actually run —
  Normal through M+12 for dungeons, Raid Finder through Mythic for raids —
  and every drop is priced at it. Previously every dungeon drop showed the
  Mythic 0 value forever.
- The selected difficulty now drives the item **link** too, so Blizzard's
  own tooltip agrees with ours. On keystones, where the journal has no
  scaled item to link, the tooltip's item level and upgrade-rank lines are
  rewritten in place and tagged with the difficulty.
- Tooltips show the upgrade rank ("Champion 3/6") alongside the item
  level, and the Great Vault value for that difficulty.
- **Icon borders show item quality, not difficulty.** Difficulty colouring
  was redundant once difficulty became a single global choice, and it read
  as an item-quality lie — epic raid loot rendered green on Raid Finder.
  Quality is read from the link, since the base item is Rare and the
  difficulty versions are promoted to Epic by their bonus IDs.
- **Favourites is its own star toggle** beside the slot dropdown instead
  of a row buried inside it, with a lit/dim state and a starred count.
- Removed the "Class:" / "Spec:" / "Slot:" / "Stats:" captions — every
  control already shows its own value.
- Housing decor is filtered by item class (20) instead of a tooltip
  string. Blizzard moved decor to its own class in Midnight and changed
  the tooltip wording, so a decor item was showing up under Sszorak.
- Fixed loot icons that rendered uncropped and could not be hovered: boss
  portraits share the icon pool and left `EnableMouse(false)`, a wrong
  texcoord and a wrong size behind on recycled frames.

### Gear Upgrades
- **Season 1 gear is no longer read as upgradeable.** Last season's items
  have their upgrade track stripped, and the code fell back to guessing
  the track from item level — so a locked S1 Mythic 272 piece was being
  offered as "Adventurer 3/6 → 282". The tooltip's track line is now the
  only accepted source; no line means not upgradeable.
- Added an off-track guard: if an item claims a track but its item level
  does not match that rank, it is flagged rather than silently trusted.
  Slots show "no track" or "off-track" instead of a bare row.

### Fixes
- **`MAX_ACCOUNT_MACROS` is nil at login** — it lives in the
  load-on-demand Blizzard_MacroUI addon. Comparing against it threw and
  aborted creation of the `/yh` macro, which is why the drag-to-actionbar
  handle had nothing to pick up. Macro creation no longer consults it.
- Season 2 Mythic+ teleports added to the Mythic+ page, which had none.
  Entries accept multiple spell IDs so a dungeon reissued for a new season
  works whether you earned the old or new teleport.
- Progression page: removed the Season 1 raid wing tabs (Voidspire /
  Dreamrift / Quel'Danas) — Season 2 is one raid. Fixed delve crests
  rendering as "999-0" when no amount was known.
- Season name comes from one constant; two pages still said "Season 1".

### Settings
- The settings panel is now also registered under **Escape → Options →
  AddOns**. It is one panel re-parented between hosts, not a duplicate, so
  your place in it follows you. Toggle which one opens by default under
  Settings → General.

### Diagnostics
- `/yh crests` — which Mistcrest currency ID resolved per track.
- `/yh lootdebug` — Loot Browser difficulty state and per-boss data.
- `/yh ejtest` — probe the Encounter Journal's keystone item levels.

## v2.11.0 — Loot Browser rework (2026-08-09)

### Season 2 dungeons now resolve at runtime
- The dungeon list was a hardcoded table of Season 1 Encounter Journal
  instance IDs, so the dungeon view would have gone **completely blank**
  on the season rollover. It now reads `C_ChallengeMode.GetMapTable()`
  (locale-correct and self-updating every season) unioned with a named
  fallback list, so it survives the next rollover without a code change.
- Row backgrounds fall back to each instance's own Encounter Journal art
  instead of a hand-maintained texture table, so new dungeons look right
  with no lookup.

### Grouped by boss
- Dungeon loot is now grouped boss-by-boss under a dungeon header, the
  same treatment raids already had, with boss portraits.
- Bosses with nothing for the current filter are hidden in dungeon view
  (a single-slot filter otherwise left ~30 empty rows to scroll past);
  raids still list every boss so the pull order stays readable.
- The old one-row-per-dungeon overview is still there behind the
  **By boss** toggle — it is the better shape for scanning many
  dungeons at once.

### Upgrade marking
- Every drop is compared against what you have equipped in that slot and
  upgrades get a green `+13` badge (`new` for an empty slot). The tooltip
  spells out the comparison.
- Paired slots (rings, trinkets, weapons) compare against the weaker of
  the two — the piece you would actually replace.
- Item levels come from the Season 2 tables in `Core/Data.lua` rather
  than the journal's item links, so the numbers are right immediately
  instead of waiting on item data to cache.
- Equipped item levels are cached per slot and dropped on gear change,
  so a refresh doesn't rescan your gear once per icon.
- Dungeon Mythic entries note that the journal figure is M0 and that
  keystones drop 295-311 — the journal has no concept of key levels.
- Toggle with the **Upgrades** chip.

### Myth 9 bosses
- The penultimate and final bosses of the current raid are badged
  **Myth 9** with their 344 item level, since they and Very Rare items
  are the only above-Myth-6/6 sources in the instance.

## v2.10.0 — Season 2 data (2026-08-09)

### Gearing rebuilt for Curse of Ula'tek
- **New gear tracks.** Adventurer 266-282, Veteran 279-295, Champion
  292-308, Hero 305-321, Myth 318-334. Cross-checked against the in-game
  Mistcrest currency descriptions and norumu's community sheet, which
  agree exactly. Season 2 tracks are perfectly regular, so every track
  now overlaps the next by 2 free ranks (Veteran was 1 in Season 1).
- **Above-Myth item levels** are modelled separately in `ns.ASCENDANT`:
  Ascended Hero 328, Ascended Myth 341, and Myth 9 (344) for Very Rare
  items and the last two Mythic bosses.
- **Great Vault raid rewards.** LFR/Normal/Heroic vault slots now jump to
  rank 1 of the next track (Heroic vault = Myth 1/6, 318) and the Mythic
  vault always gives Myth 6/6 (334).
- **Mistcrests replace Dawncrests.** Blizzard ships two currency IDs per
  crest tier, so the addon resolves the live one at login instead of
  betting on a hardcoded ID. `/yh crests` shows what resolved.
- Progression tables rebuilt: M+, Venomous Abyss (8 bosses), Lairs,
  Delves, Trovehunter's, Prey, world content, crafting, Venomstones and
  Great Vault notes.
- Season 2 M+ rotation and its eight teleports.

### Consumables
- **ConsumablesData.lua is now generated**, not hand-maintained. Rescrape
  all 40 specs with `python Tools/scrape_consumables.py`.
- Each spec records the season its guide was written for. Wowhead has not
  published Season 2 enchant/gem guides yet, so every spec currently
  shows a banner saying the advice is written for Season 1.

### Trinkets (new page)
- Trinket rankings for 29 specs scraped from bloodmallet.com.
- **My Spec** tab: your trinkets ranked, with how far each is behind the
  best pick.
- **Loot Council** tab: pick a trinket and see every spec that sims it,
  best rank first — the "only Frost DKs should roll on this" view.
- **Tooltip integration**: hovering any trinket anywhere (loot window,
  bags, chat links, Encounter Journal) lists the specs that want it and
  where it lands for you. Toggle in Settings → General → Trinkets.
- bloodmallet has no data for the six healer specs, nor for Augmentation,
  Brewmaster, Windwalker or Assassination in this tier.
- Its data is still tagged `MID1`, i.e. Season 1 sims, and the page and
  tooltips say so.

### Packaging
- `Tools/` is excluded from CurseForge builds via `.pkgmeta` and ignored
  by git, so the scrapers never ship inside the addon.

### Known gaps
- Utility Advisor has no entries for the Season 2 dungeons yet.
- Crafting item levels are inferred and need verifying in-game.

## v2.9.0 — Pre-12.1 strip-down (2026-08-09)

Clearing the decks before patch 12.1 (2026-08-12). Everything removed
here was either tied to a Midnight Season 1 encounter that stops
existing on the 12th, or was guild-raid management rather than the
"look it up in-game instead of googling it" job the addon is for.

### Removed — dead on 12.1
- **L'ura memory-game helper.** Hardcoded to encounter ID 3183
  (Midnight Falls). Gone along with `Lura.lua`, `LuraUI.lua`, the
  bundled pentagon symbol textures, the `/yh lura` command, and its
  Settings → Raid section.
- **Nexus-King Salhadaar interrupt marker.** Hardcoded to encounter ID
  3179. Gone along with `/yh nk` and its settings checkbox.

### Removed — off-mission
- **Power Infusion auto-assign.** All six `Features/PowerInfusion`
  files plus the PI target picker and PI-target column in Raid Tools.
  The scoring model needed a manual bloodmallet JSON re-paste every
  tier, which made it the highest-maintenance feature in the addon for
  the narrowest audience.
- **Raid split analysis and swap suggestions.** `RaidSwapLogic.lua`
  and the Split Balance / Suggested Swaps UI. The Raid Tools page keeps
  its group roster, composition counts, raid-buff strip and consumable
  audit.
- **Release Spirit blocker.** `ReleaseBlocker.lua`, `/yh release`, and
  its settings row.
- **Raid Addon Scanner.** `AddonScanner.lua`, the "Scan Addons" button
  and `/yyhscan`.
- **Welcome / What's New window.** `Integrations/Welcome.lua` and
  `/yh welcome`. It was a feature tour that went stale every patch.
- **Xal'atath's Toes.** The joke feature, its Settings → General "Fun"
  section, and `/yh toes`.

### Notes
- Gear-track item levels, crest IDs, the dungeon pool, and the raid
  progression tables are still carrying Midnight Season 1 values. Those
  get updated in a follow-up pass once 12.1 numbers are confirmed.
- Removed features leave their old `YippYappHelperDB` keys behind
  harmlessly; they're simply no longer read.

## v2.8.0 — Wipe-aware release blocker, M+ window movers, leak sweep (2026-05-13)

### Bug fixes
- **MoneyFrame "secret number" taint fix.** The Loot Browser's
  EJ-suppression helper was calling `SetScript("OnEvent", …)` /
  `Un/RegisterEvent` on the `EncounterJournal` frame to silence its
  bulk-scan event chatter. Those writes tainted the EJ frame, which
  then poisoned `MoneyFrame_Update` on item-sell-price tooltips
  inside the Encounter Journal. Drop the script/event manipulation
  entirely; keep the filter save/restore, which is taint-free.

### Mythic+
- **Battle Res Timer now shows in Mythic+ keystone runs.** Added
  difficulty ID 8 (Mythic Keystone) to the brez-difficulty whitelist
  and dropped the `IsInRaid()` gate, so the icon + cooldown swipe
  light up the moment you engage in a keystone.
- **New Mythic+ settings tab.** Completion Popup and Utility Advisor
  toggles moved off the General tab into their own dedicated tab,
  mirroring the Raid tab's grouping.
- **Lock / Unlock for the M+ windows.** Both the Completion Popup
  and the Utility Advisor now stay locked by default and grow a
  cyan border + "drag to move" overlay when unlocked — same
  affordance the Interrupt Tracker uses. Lock hides the overlay and
  dismisses the preview window so it doesn't linger on screen.

### Release Spirit Blocker — wipe-only redesign
- **Trigger moved from PLAYER_DEAD to PLAYER_REGEN_ENABLED.** Dying
  mid-fight no longer blocks the popup — you're free to release for
  a corpse run if that's what you want. The blocker engages only
  once combat has actually ended and the player is still dead in a
  raid instance.
- **Retry chain on popup-find race.** If the death `StaticPopup`
  hasn't rendered by the time the block tries to attach, retries
  at +0.25 s and +0.5 s before giving up. Cancels as soon as the
  player ungohosts.
- **Leader broadcast feature removed.** No more `YYH_RB` addon
  messages between raid leaders' clients — the setting is now
  strictly personal. Per-user checkbox in `Settings → Raid` is the
  only control surface; the raid-tools header button is gone.
- **Guild-majority check replaced with raid-instance check.** Simpler
  and works for pug raids too.

### Ready Check
- **Cramped down sizing.** Window scale `0.95 → 0.85`, row heights
  `26 → 22` (full) and `20 → 17` (compact), header height `38 → 30`,
  paddings + status icon + check icon all trimmed proportionally.
  Roughly 15–20 % shorter vertically on a 30-raider list.
- **Preview / Hide buttons in settings.** Test the window with a
  24-player dummy roster (or hide it again) without needing to type
  `/yyhrc`.

### L'ura helper
- **Cleaner panel.** Removed the duplicated inner title, every
  description/hint subtext block, and the "Solo Test (no raid
  required)" sub-section. Panel height dropped from 560 px to 360 px.
- **`/say debug mode` gone.** The `L:SetSayDebug` / `L:SayTest` /
  `L:IsSayDebugOn` helpers and `CHAT_MSG_SAY` listener are removed;
  `/yh lura say`/`saytest` sub-commands no longer exist.

### Nexus-King Interrupt
- **Stripped to one toggle.** Removed the marker-size slider, color
  picker stubs, and Preview/Clear UI. Marker is now a fixed 36 px
  orange triangle. Slash command trimmed to `/yh nk on|off`.

### Settings UI
- **Wider content area.** `SettingsContentWidth()` derives the
  panel width from the live AppFrame size (≈ 760 px on a typical
  screen) instead of the old hardcoded 500. Existing two-column
  layouts (Interrupt Tracker) and full-width panels both benefit.
- **Interrupt Tracker BETA banner removed.** Interrupt bars are no
  longer beta-flagged in the General sub-tab.

### Performance — memory-leak sweep
- **Interrupt Tracker slot pool.** `rebuild()` now reuses slots from
  per-mode pools (`bar`/`icon`) instead of `CreateFrame`-ing fresh
  ones on every `GROUP_ROSTER_UPDATE` / zone change. Previously each
  rebuild orphaned up to 5 frames.
- **Interrupt Tracker GUID-state pruning.** `I.state` now drops
  entries for GUIDs no longer in the party on roster updates, so
  long pug-M+ sessions stop accumulating one entry per unique player
  ever seen.
- **Pooled UI rebuilds.** Progression raid cards, M+ Completion
  Popup rows, Utility Advisor icons, and Addon Scanner rows are now
  all backed by persistent pools instead of being rebuilt with fresh
  `CreateFrame` calls each time.

## v2.7.1 — Upgrade advisor: fix "wait for 6/6" on Myth 2/6+ (2026-04-22)

- **Myth 2/6+ now recommends upgrade instead of "wait for raid
  drop."** The upgrade advisor was telling players with Myth 2/6
  (or any rank below 6/6) to save their crests because "Myth 6/6
  drops from Mythic raid." That's wrong on two counts: raid bosses
  drop a spread of ranks (3/6, 4/6, 5/6, only endbosses guarantee
  6/6), and even if they did all drop 6/6, a 2/6 Myth item is
  valuable enough to upgrade now rather than sit on precious
  crests waiting for a specific drop.
- **Root cause** was a fallback in `GetFarmableInfo` that assumed
  raid reliably drops `#levels` (= 6) in the item's track when no
  M+ source was available. The same bug affected Hero items at
  Heroic raid tier (Hero 2/6 said "Hero 6/6 drops from Heroic
  raid, save crests"). Both now flow to the slot-priority upgrade
  rules (Rule 6-8).
- **What Myth items recommend now:**

  | Rank       | Path                    | Message                                 |
  |------------|-------------------------|-----------------------------------------|
  | Myth 1/6   | Rule 3 (overlap promo)  | "Max a Hero piece → free promo to 2/6"  |
  | Myth 2-5/6 | Rule 6-8 (slot prio)    | "top priority" / "priority #N of X"     |
  | Myth 6/6   | Rule 5 (maxed)          | "Fully upgraded"                        |

- **No Myth-specific carve-out required.** M+ end-of-dungeon loot
  in Midnight S1 caps at ilvl 266 (M+12), which is below Myth 1/6
  (ilvl 272), so the same-track check can't enter a "wait for M+
  drop" path for Myth items by construction. If a future season
  adds M+ keys that drop Myth, the same-track rank-comparison
  branch would start firing again and recommend saving crests —
  behavior we'd probably want then anyway.

## v2.7.0 — Raid split balancer rewrite + PI manual-only (2026-04-22)

### Raid split balancer — group compaction rewrite

- **Compaction is now raid-wide, not per-split.** The old pass
  balanced each side (A / B) independently, which in odds mode
  produced the alternating `5,4,5,4,5,4` layout — side A filled to
  three fives, side B balanced to three fours. Visually it looked
  broken because the raid window isn't split-aware; it just shows a
  1..maxGroup list. New pass computes a single target across all
  groups.
- **Fill greedy, balance the last two groups.** Formula:
  `k = min(maxGroup - 2, floor(N / 5))` groups filled to 5 (or
  `k = maxGroup` when `N = 5 * maxGroup` exactly), then the
  remainder spread across the tail with `ceil`/`floor(remainder /
  tailCount)`. Result:

  | N  | 6-group layout  |
  |----|-----------------|
  | 22 | 5,5,5,5,1,1     |
  | 23 | 5,5,5,5,2,1     |
  | 24 | 5,5,5,5,2,2     |
  | 26 | 5,5,5,5,3,3     |
  | 27 | 5,5,5,5,4,3     |
  | 30 | 5,5,5,5,5,5     |

  And at smaller group counts: `N=6, g=2 → 3,3`; `N=11, g=3 →
  5,3,3`. The 2-tail shape is a consequence of the `g-2` clamp, not
  a hardcode — it generalizes.
- **Side-crossing accepted.** In odds mode a compaction move from
  G5 → G4 crosses sides, so split balance can shift by a body when
  the tail bridges the two halves. The balance panel rebalances on
  the next pass; the user's explicit ask was visual density.

### Raid split balancer — plan stickiness

- **Plan cached across refreshes.** Single-row swaps used to call
  `SwapRaidSubgroup`, wait 0.5s, then re-run `Suggest()` from
  scratch. Because the whole sequence was re-ranked against the new
  roster state, clicking step 1 could quietly rewrite steps 2 / 3
  into a different plan. The plan is now cached on `ns._raidSwap`,
  keyed by `(mode, maxGroup)`, serialized by player name so it
  survives raid-index shifts.
- **Reconcile on refresh, don't regenerate.** Each refresh walks
  the cached plan and drops entries whose players are gone or
  whose swap/move is already satisfied (someone got moved
  manually). If any live entries remain, they're re-rendered and
  `Suggest()` is skipped entirely. Regeneration only happens when
  the cache is empty or the mode/maxGroup changed.
- **Apply-All and Refresh flush.** Apply-All clears the cache
  after dispatch (in case any `SetRaidSubgroup` silently no-oped
  on a full destination) so the next pass replans any leftover.
  The Refresh button is now the explicit escape hatch when PI
  picks or manual moves should produce a brand-new ranking.

### Power Infusion — auto-assign dropped, manual only

- **Auto button removed.** WoW's inspect API is serial — one
  `NotifyInspect` at a time, ~0.6-2.3s per reply depending on the
  timeout path. In a 20-30-man raid the scan genuinely can't
  complete inside any reasonable UI budget, and the retry pass
  stacks on top. Auto-assign was printing "inspect data incomplete"
  more reliably than it was assigning PI. The scan-orchestration
  code (`PI:EnsureScan`, `PI:IsDataReady`, `PI:AutoAssign`,
  `PI:Recommend`, plus their helpers) is gone.
- **Manual picker unchanged.** Click a priest's row → pick a DPS
  target. When the tier / iLvl scan (run by ReadyCheck / the loot
  ranker) has happened, the picker still annotates rows with the
  bloodmallet ST score and a "(best)" tag; otherwise it falls
  back to alphabetical. Assignments still drive the swap
  balancer's "PI pairing" criterion.

### Bug fixes

- **ReadyCheck "secret value" taint crash.** The per-unit aura
  scan was comparing `a.spellId == 1459` (and four other stat
  IDs) in an if/elseif chain. In 11.x, aura fields from
  `C_UnitAuras.GetAuraDataByIndex` are marked "secret values" and
  a direct `==` compare while execution is tainted raises
  `attempt to compare local 'sid' (a secret number value, while
  execution tainted by 'YippYappHelper')`. Converted the chain
  to a `STAT_BUFF_IDS[sid]` table lookup — indexing with a secret
  key is safe, same pattern already used for `flaskSet` / `foodSet`
  / `bronzeSet`. Same class of crash as the L'ura `msg:match` fix
  in v2.6.0, just on the number side. Two unused helpers
  (`UnitHasAuraBySpellID`, `FindAuraBySpellID`) that would have
  tripped the same bug if wired up were removed.

### Under the hood

- **Inspect retry queue** in `RaidInspect.lua`. Units that fail
  `CanInspect` on the first pass (out-of-range at the repair
  vendor, cross-phase, recently joined) are deferred to a retry
  buffer and re-tried once after the main queue drains, rather
  than being silently dropped. Helps the tier / iLvl / gear-
  quality panel populate more completely without needing a manual
  Rescan.

## v2.6.0 — Tonight's Plan + L'ura revived (2026-04-19)

### L'ura Memory-Game Helper — back, and this time it survives combat

- **Root cause of the v2.0.x failure identified.** Midnight's encounter
  system wraps `CHAT_MSG_RAID` / `CHAT_MSG_RAID_LEADER` payloads as
  "secret string values" — any index op (`msg:match`, `msg:sub`,
  `msg:find`, `msg:lower`) trips taint and crashes the handler with
  `"attempt to index local 'msg' (a secret string value tainted by
  'YippYappHelper')"`. The v2.0.x code did `msg:match("YYL[1-5]")`,
  which is exactly the forbidden op.
- **Protocol rebuilt to NSRT's shape (with our symbols).** Macros
  broadcast a short code (`circle` / `diamond` / `t` / `triangle` /
  `x`) via `/raid`; the receiver bakes the texture-path prefix into
  its `SetFormattedText("|T<prefix>%s<suffix>|t", msg)` format
  string, so `msg` flows through without ever being indexed or
  concatenated. No taint. Uses our bundled symbol TGAs inside the
  addon folder — no `Interface\ICONS\` file-install hack like the
  NSRT+LuraMemoryFiles combo needs.
- **Raid-leader-only listener.** Only `CHAT_MSG_RAID_LEADER` drives
  the pentagon — regular raid chatter can't trigger a false render.
- **Encounter-scoped by default.** Listener is armed only during
  L'ura's memory-game windows (heroic: 10 / 80 / 150 s, mythic:
  33 / 95 / 157 s + phase-4 re-arms). Checkbox flips to "always
  listen" as a fallback for cross-realm / `/reload`-mid-pull cases.
- **Full UI in Raid Tools → L'ura tab.** Enable toggle, scope
  toggle, Preview / Simulate / Clear buttons, Unlock / Lock mover,
  `Create / refresh macros` button, reference table (slot number,
  symbol, name, macro name), and a `/say` debug mode for solo
  end-to-end testing without a raid group.
- **Macro generator.** Creates 5 macros named `YY_Lura_1..5` with
  body `/raid <code>` and a shared numeric icon FileDataID (not an
  addon path — those render transparently on macro slots). Deletes
  stale old-schema macros (`YY_1..5`, previous `YY_Lura_*`) before
  creating new ones so a broken prior save can't land on your bar.
- **Chat payload shrunk** from the full path
  `Interface\AddOns\YippYappHelper\Media\Textures\symbol_<name>`
  (~60 chars) to just the short code. The prefix lives in the
  receiver's format-string literal.

### Ready Check dismissal + hover-to-pause

- **Three-shape dismissal.** Combat start (`PLAYER_REGEN_DISABLED`)
  snap-closes with no fade — the fight is live and the panel is in
  the way. Raid pull countdown fires the fade immediately. Normal
  finish / everyone-answered paths linger 3 s before fading so the
  final status stays readable.
- **Hover-to-pause, both directions.** If the cursor is over the
  window when a fade is about to start, the fade is held. If the
  user moves the cursor back into an already-fading window, the
  fade stops and alpha restores to 1. The instant the cursor
  leaves the window, the fade plays. Combat snap always wins —
  hover does not pause a combat-start dismiss.
- **Ticker-based hover detection.** Frame `OnLeave` fires when the
  cursor moves onto a child row, even though `IsMouseOver()` still
  reports true for the parent — unreliable signal. A 100 ms ticker
  polls `IsMouseOver()` and self-cancels once neither a pending
  fade nor an active fade remains.
- **Position persistence fix.** `OnDragStop` was computing the
  anchor via `GetLeft/GetTop - UIParent:GetLeft/GetTop` — brittle
  math that could flip signs or diverge under differing effective
  scales. Rewritten to use `frame:GetPoint()` directly and save
  `point / relativePoint / x / y`; show path restores with the
  matching `SetPoint`. Legacy `anchorLeft / anchorTop` still read
  as fallback.
- **"X missing" summary removed.** The counter conflated offline
  members with players missing buffs — in a small test group you'd
  see `1/2 ready · 1 missing` where the "missing" was just the
  offline teammate. Per-row icons already show exactly which buffs
  / food / flask / durability are missing. Summary now just reads
  `X/Y ready`.

### Raid Tools UI

- **L'ura tab** lives next to Overview with its own purple accent.
- Header row shifted so the Overview / Release Block / Scan Addons
  buttons no longer slice the inner-panel border.

### Loot Browser bug fixes

- **Stale-texture pool bug fixed.** Icon pool entries cleared their
  `itemID` / `itemLink` on release but not the texture itself. When
  the pool handed a slot back out and the next row didn't explicitly
  set a texture, the old item's icon stayed visible — rendered with
  no tooltip and a dark-gray "unknown difficulty" border, which
  looked like an errant bag-slot icon. `ReleaseAll` now calls
  `SetTexture(nil)` on every pooled icon.
- **Filtered Encounter Journal rows with no itemID.** The EJ
  occasionally returns a loot entry that has a name and an icon but
  no itemID — unlinkable, untooltippable. Those entries now get
  dropped at scan time instead of rendering as a no-tooltip blank.

### New features

- **Tonight's Plan** — replaces the static Farm Guide on the home
  dashboard with a live activity planner. Shows vault progress as three
  dot-strips (M+, Raid, Delves) and up to three prioritized actions with
  inline progress bars — "1 more M+ run » unlocks vault slot 2",
  "2 raid bosses » unlocks raid slot 2", "40 Hero crests left this
  week". Driven by a new `Features/Planner/PlannerData.lua` module that
  reads `C_WeeklyRewards.GetActivities` and the profile's precious-crest
  list. Auto-refreshes on currency / inventory update bursts.

- **Utility Advisor description rewrite** — the dense per-dungeon prose
  paragraph is now bulleted per mechanic, with color-coded response
  keywords (interrupt = yellow, purge / dispel = cyan, enrage = red,
  curse = violet, poison = green, bleed = dark red, stun = gold,
  fear = violet, slow/snare = sky, grip = tan, incap = pink) and
  bolded ability names (two-word Title Case auto-detected). The "lead"
  one-liner still sits above the bullets as an intro.

### ReadyCheck rewrite (30-man perf pass)

- **Persistent rows** — removed the Acquire/Release pool churn; row
  frames are created once and reused in-place. Icons anchored at
  creation (previously 300 ClearAllPoints+SetPoint calls per render
  at 30 raiders). Header labels / column dividers anchored once at
  load instead of every render.
- **Per-unit aura cache** — `ScanUnitAuras` results cached per unit
  token, invalidated by `UNIT_AURA(arg1)` or `GROUP_ROSTER_UPDATE` or
  the start of a new `READY_CHECK` session. A UNIT_AURA for one unit
  now triggers a scan for that one unit; the other 29 hit the cache.
- **Pulse animation no longer thrashes** — `_pulsing` flag avoids
  the unconditional `Stop()` + `Play()` that restarted the eating
  animation every render.
- **Dismiss window on time** — removed the 3s post-finish delay and
  shortened the fade to ~1.5s, so the window visibly fades away
  "right as the 30 seconds end" instead of lingering with a tail.
- **Pull-timer dismiss** — registered `START_TIMER`; when a player
  countdown (`/cd`, `/countdown`, or BigWigs/DBM option to use the
  native countdown) starts, the window fades immediately.
- **Cross-realm name keys** — `readyStatus` now uses
  `Ambiguate(name, "short")` consistently at all read/write sites;
  previously mixed raw `UnitName` with short-ambiguated keys, causing
  the initiator's seed to be missed on cross-realm players.
- **OnHide unregister** — manual × close now stops UNIT_AURA tracking
  too; previously only the finish paths did.

### Interrupt Tracker

- Bars no longer dim when on cooldown. The draining StatusBar was
  already the cooldown signal — the extra 0.5/0.85 alpha just made
  the bar harder to read.
- Input values from SavedVariables are now type-validated and clamped
  to sane ranges (`barWidth` 40–600, `posY` –8000 to 8000, etc.), so
  a corrupted SV can't produce a 0-width bar or an off-screen frame.

### Settings

- **Quick Access sidebar tile** — the YippYapp macro drag icon is
  pinned to the bottom of the settings tab column, always visible
  regardless of which tab is open. "Drag to your bar, or type /yh"
  hint inline.
- **Slash commands reference** — new "Slash commands" section at the
  bottom of the General tab listing /yh, /keys, /yyhrc, /yyhopts,
  /yyhinterrupts, /yh toes off, /yh toes mover.

### Fun

- **Toes of the Harbinger** — Xal'atath's feet now hover at the top of
  your screen. Yes, the feet. Just the feet. No, we will not be
  answering questions. Drag them somewhere, rotate them upside-down,
  flip them, resize them until they are an ominous 2× or a tasteful
  0.5×. Saved across sessions, which is either charming or concerning
  depending on your relationship with cosmic horror. Turn them off in
  Settings → General → Fun when your raid group starts asking things,
  or type `/yh toes off` and pretend you never saw them. Inspired by
  Sakreble's [Xaltoes](https://www.curseforge.com/) addon, which itself
  is a structured version of a ModelScene one-liner by @Herotherogue
  on X.

### Safety & perf

- `ReleaseBlocker`'s mover overlay re-parented to `UIParent` (was
  parented to the DEATH StaticPopup's release button); insecure +
  mouse-enabled children on a frame whose OnClick runs protected
  code is a taint path. OnUpdate also throttled to 20Hz so holding
  CTRL for the override doesn't burn per-frame CPU during combat.
- `RaidInspect` GUID scan replaced with a GUID→unit map rebuilt on
  `GROUP_ROSTER_UPDATE` / `PLAYER_ENTERING_WORLD`. Fallback refresh
  on stale lookup. Previously O(n) scan per `INSPECT_READY` of up
  to 30 units.
- `MythicPlusData` guild-keystone reply uses a 15s cooldown
  (`lastGuildKSReplyAt`) so a burst of KSQ requests after a Tuesday
  reset doesn't schedule 100+ independent `C_Timer.After` reply
  timers.
- `PVETab` defers `PanelTemplates_DeselectTab` via `C_Timer.After(0, …)`
  so it never runs inline with Blizzard's click dispatch.
- `Core/Core.lua :SendItemToUpgrade` has an explicit
  `InCombatLockdown()` guard now (the right-click path into it was
  bypassing the caller's guard).
- `Welcome` `UISpecialFrames` insert is idempotent — fast Show/Hide/Show
  sequences no longer stack duplicate entries.
- Consolidated `CONSUMABLE_SPELL_IDS` (food / flask / bronze) into
  `Core/Data.lua` — RaidUI used to carry stale Dragonflight flask IDs
  that no longer matched Midnight S1 consumables.
- Dashboard crest-refresh builds a single `track → crestData` map
  per tick instead of nested scans (O(n²) → O(n)).
- `ScheduleRefresh` in the gear panel coalesces rapid clicks via a
  pending flag.
- Removed duplicate `ns.CREST_COST_PER_UPGRADE` constant (was dead
  code; `ns.BASE_CREST_COST` in Recommend.lua is the sole source).
- `CompletionPopup` party class lookup uses party-unit tokens instead
  of bare names — fixes missing class colors for cross-realm / out-of-
  range cached keystone senders.

## v2.5.0 - Midnight-ready (2026-04-15)

### New features

- **Interrupt Tracker (BETA)** — party-wide interrupt cooldown bars.
  - Per-member bars with class-colored fill, class-colored border option,
    icon, name, and countdown/elapsed timer.
  - Tracks the player's own casts directly; attributes party interrupts
    via a time-correlation model (ExwindTools-style) that sidesteps
    Midnight's secret-value wrapping on friendly spellIDs.
  - Fully configurable: bar/icon mode, texture, dimensions, orientation,
    grow direction, anchor, multi-context visibility filters, backdrop,
    and drag-to-move with an unlock overlay.
  - Slash commands: `/yyhintlog` debug log, `/yyhintdebug` class rotation.

- **Mythic+ completion popup (BETA)** — small window on
  `CHALLENGE_MODE_COMPLETED` showing your new M+ rating, the party's new
  keystones in Mythic+ page styling, and a button that navigates the
  app frame to the M+ page. Row click casts the teleport directly via
  `InsecureActionButtonTemplate` (BigWigs-style) so it works even when
  the popup was opened from a tainted click path.

- **Utility advisor (BETA)** — on entering a Mythic+ (or Mythic) dungeon,
  shows a small window with per-class recommended utility spells for
  that dungeon plus a short description. Spell icons hover to full
  Blizzard tooltips. Gold border marks talent-dependent picks.
  Show-once guard so it doesn't spam on reloads or re-entries.

- **Raid Addon Scanner** — button in the Raid Tools header that pings
  the party/raid via addon-comm and shows a modal listing who has
  YippYappHelper installed vs not.

### Settings overhaul

- Removed the Blizzard AddOn Options integration. All settings now live
  in the addon's own Settings page (accessible via the gear button,
  `/yyhopts`, `/yyhsettings`, or `/yyhinterrupts`).
- Top-level tabs (General / Interrupt Tracker) with vertical sub-nav
  inside Interrupt Tracker for its many sections.
- Feature-row widget with inline "Preview" buttons so you can test what
  a popup looks like before enabling it in live play.
- "Show in" visibility is now a multi-select (any of: Always / In a
  group / Dungeons & raids / Mythic+ / Raid / PvP).

### Mythic+ page

- Views are now **strictly party-scoped** (5-man) regardless of whether
  you're in a raid — no more raid-member keystones polluting the grid.
- Tabs restyled to underline tabs matching the Loot Browser.
- `/yyhmplustest` slash command injects 5 fake teammates with synthetic
  keystones and scores so you can preview the full group layout solo.
- Dungeon-tile tooltips now use an O(1) mapID-indexed lookup instead of
  rescanning the keystone list per hover.

### Raid Tools

- **L'ura Runes feature removed.** Midnight locks down chat text,
  addon-comm, raid markers, and custom channels during raid encounters
  — there is no unprivileged signaling primitive left that works cross-
  realm in a raid instance.
- Ready Check performance: single-pass aura scanner (replaces 8 separate
  FindAura calls per member — ~8x fewer `GetAuraDataByIndex` calls at
  30-man), UNIT_AURA debounced to 0.5s, READY_CHECK_CONFIRM throttled
  through `QueueRefresh`, CHAT_MSG_ADDON durability updates coalesced.
- Durability broadcast staggered 0–1.5s to avoid CHAT_MSG_ADDON flood
  on ready-check in full raids.
- Durability name-key mismatch fixed (cross-realm raiders no longer
  show as "not applicable").
- Early-finish detection: window fades as soon as everyone answers,
  rather than waiting the full 30s timer.
- "Hearty" and "Well Fed" prefix patterns added to food detection.
- ReadyCheck hide delay reduced 8s → 3s after everyone answers.
- `Respond()` now fires `ConfirmReadyCheck` before any UI state touches,
  plus optimistic local status update so the row flips instantly.

### UI consistency

- AppFrame uses a darker, flatter background (0.03 on black at 0.92
  alpha) with a 1px black border.
- Every page (Gear, Raid, Progression, Loot, Consumables, M+, Teleports,
  Settings, Home) gets the same inner bordered panel — unified look.
- Settings window lives inside the AppFrame as a page; Home-dashboard
  and AppFrame header both have a "Settings" button that routes there.
- Loot Browser and Consumables headers in app-mode dropped their card
  border in favor of a single 1px bottom divider under the filter row.
- All the in-addon widgets (checkbox, slider, dropdown, tab) rebuilt
  to match the addon's dark palette — no more WoW default styling.

### Performance

- Interrupt slot OnUpdate throttled to 20 Hz and caches settings-
  derived flags on the slot.
- Interrupt events short-circuit when the feature is disabled.
- Ready Check aura scanner batches 8+ independent aura iterations into
  a single pass per member per render.
- Mythic+ RefreshMythicPlus pre-builds `membersByName` and
  `keystonesByMapID` lookups to avoid inner-loop rescans.
- Loot Browser tooltipHiddenCache is now bounded (2048-entry cap with
  wipe-on-fill).
- AppFrame uses `UISpecialFrames` only out of combat to avoid the
  `ADDON_ACTION_BLOCKED` taint we hit at combat end.

### Bug fixes

- Interrupt bar no longer snaps back when dragging to a new position
  (atomic write + manual `applyPosition` instead of listener cascade).
- Interrupt bar no longer jumps out from under the cursor when
  GROUP_ROSTER_UPDATE fires mid-drag.
- Active interrupt cooldowns now survive a rebuild — reattaching state
  from `ns.Interrupts.state` to freshly-created slots so GROUP_ROSTER
  doesn't visually reset ongoing bars.
- Interrupt attribution flash no longer hides the slot (was passing
  `showWhenDone=false` to `UIFrameFlash`).
- Loot Browser filter row shifted down in app mode to clear the inner
  panel top edge.
- Consumables header matches Loot Browser styling in app mode.
- Teleports / Progression / M+ page layouts nudged to fit the new
  inner panel without gaps or overlaps.
- All the tainted-value handlers we had to add while chasing the
  Midnight secret-value system are removed now that we've landed on
  ExwindTools' taint-free attribution model.

---

## v2.0.1 - Polish pass (2026-04-14)

### L'ura Runes
- Macros renamed from `O D G T X` to `YY_1` - `YY_5` with a blank question-mark icon. Raid leader copies the bundled symbol TGAs into `Interface\ICONS\`, restarts WoW, then manually picks each symbol from the macro icon browser's Items tab.
- Tab fully redesigned into two full-width sections (Settings & Simulation, Raid Leader Macros) with a side-by-side reference table showing each macro number, its symbol icon, and the filename.
- Macro listener now only responds to `CHAT_MSG_RAID_LEADER`, not `CHAT_MSG_RAID` - so only raid leaders / assists can drive the pentagon display.
- Removed the per-slot icon picker; bundled symbol TGAs are the only display textures.
- Description now correctly states runes fill the pentagon right-to-left in press order.

### Ready Check
- Response tracking rewritten to capture `READY_CHECK_CONFIRM` arguments directly into an internal status map (MRT-style) instead of polling `GetReadyCheckStatus`, which could be stale for a tick after the event fired.
- Blizzard's own ready-check popup is now dismissed reliably (multi-tick safety sweep).
- Footer collapses after you respond so the window shrinks up to the bottom of the roster.

### UI polish
- Main app window close button restyled to match the Ready Check / Settings header buttons.
- Buy Me a Coffee icon moved to the home dashboard bottom-right with "if you want to support" label.
- Welcome / What's New window: Unicode em-dashes and arrows replaced with ASCII (no more square glyphs on certain fonts), and bullet wrapping estimator now strips color codes so long bullets stop overlapping.
- L'ura tab reference header reworded from "Reference" to "Pick this icon for each macro:" with explicit Items-tab instruction in the guide.

### Other
- `/keys` / `/yhkeys` slash command opens the Mythic+ page directly.
- Settings panel two-way sync: toggling the in-raid-frame Release Blocker button now updates the settings checkbox immediately.
- Guild keystone cache: 1-week TTL so stale entries from players who no longer have keys age out on their own.
- Loot Browser cache no longer invalidates while the panel is closed - keeps re-opens instant.
- Deleted orphaned `GetTrinketMythInfo` / `GetTrinketMaxIlvl` helpers left over after Trinket Rankings was retired.

## v2.0.0 - Raid companion rewrite (2026-04-13)

### New features
- **L'ura Memory-Game Helper** - live rune pentagon display, macro generator (`O D G T X`), per-slot icon picker, bundled rune symbol textures, and built-in simulation for dry-runs. Works in both Heroic and Mythic with press-order rendering.
- **Ready Check Window** - opens automatically on any ready check. Shows food, flask, vantus rune, Int/AP/Vers/Stam/Haste/Move, and durability % for every raider. Collapse/expand toggle, countdown timer, Ready/Not-Ready buttons, and live refresh as buffs change mid-check.
- **Settings Panel** - full entry in Blizzard's standard Options UI. Toggle Release Blocker, Ready Check, L'ura Runes, and the minimap button. `/yhopts` opens it directly.
- **Keys tab on the group-finder window** - opens the Mythic+ page without closing the current LFG panel.

### Major improvements
- Loot Browser: class dropdown (inspect any class), horizontal-scroll icon rows, housing decor + recipe filter, mount border distinction, and login prewarm so re-opens feel instant.
- Mythic+ Guild Keystones: auto-request on login, manual Refresh button that sits cleanly next to the Vault row.
- Raid Split Balance: added melee vs ranged DPS counts for each split.
- Dashboard panels restyled with accent underlines and consistent typography. Upgrade Summary rewritten into readable "Slot - Action (reason)" lines.
- Release Blocker simplified to work in any raid zone with guild-majority detection.
- New `YippYappHelper` logo used for the minimap button and in-app header.
- Full folder reorganization: `Core/`, `Features/`, `Integrations/`, `Media/`.

### Retired
- Trinket Rankings (too expensive to keep accurate via sim).
- Raid Tools - Tier Tracker tab.
- Raid Tools - Performance tab.

## v1.4.0 — Mythic+, Teleports & More (2026-03-30)

### Mythic+ Helper (new)
- Dungeon overview with clickable teleport icons showing your best key level and score
- Group ratings grid with color-coded per-dungeon scores for all party members
- Group keystones section with dungeon icons and class colors
- Great Vault tracker with Blizzard-native tooltips — click slots to open vault
- Rating goals (2000/2500/3000) with progress bars and focus dungeons
- Guild tab for viewing guild members' keystones (shared via addon comms)
- Home/Guild tab navigation
- Accessible from dashboard, app nav, and `/yh mplus`

### Dungeon Teleports (new)
- All Hero's Path dungeon teleports from MoP through Midnight
- Organized by expansion with clickable secure buttons
- Greyed-out icons for teleports not yet unlocked
- Accessible from dashboard, app nav

### Release Spirit Blocker (new)
- Hides the Release Spirit button in current expansion guild raids
- Hold CTRL for 1 second to override — progress bar shows hold time
- Does not interfere with combat resurrections
- Toggle with `/yh release` (enabled by default)

### Loot Browser
- Instance-aware filtering: detects current dungeon/raid and shows only that instance's loot
- Slot tabs grey out when no items match the instance + stat filter combo
- Auto-enables instance filter when entering a dungeon

### Dashboard
- Upgrade summary and farm guide now auto-refresh on gear/crest changes
- Top 3 actionable recommendations sorted by priority

### Trinket Rankings
- Fixed Hunter Beast Mastery spec key mismatch in "Your Spec" mode
- Fixed Rogue Assassination mapped to Outlaw rankings
- Added missing AOE trinket rankings for all Demon Hunter specs

### Raid Tools
- Fixed swap suggestions reusing the same player as swap partner across multiple triggers

### UI
- All frames use dynamic sizing based on screen resolution
- Responsive dungeon icons scale to fit available width
- Font sizes scale proportionally at different UI scales

## v1.3.6 — What's New Screen (2026-03-26)
- Updated What's New popup to show v1.3 and v1.3.5 highlights
- Removed features list from welcome screen, now shows only what's new

## v1.3.5 — Polish & Fixes (2026-03-26)

### Consumables
- Shift-click items to link in chat or search the Auction House

### Bug Fixes
- Fixed sub-panels (Gear, Raid Tools, Loot Browser, Consumables) being independently draggable when embedded in the app shell
- Fixed consumables icon pool contamination causing greyed-out icons
- Added nil-safety to consumables object pool functions

## v1.3.0 — Consumables Guide, Loot Browser & More (2026-03-26)

### Consumables Guide (new)
- Full enchant, gem, and consumable recommendations for every class and spec (all 40 specs)
- Three-tab layout: Enchants, Gems, Consumables — each with item icons, quality-colored links, and tooltips on hover
- Class dropdown and spec buttons to browse any spec's recommendations (defaults to your class/spec)
- Guide text below each tab with detailed reasoning (flask choices, potion tradeoffs, weapon buff notes, food comparisons)
- Alternative items shown inline with "or" label (e.g. flask alternatives)
- Accessible from dashboard, app nav bar, and integrated as full page in the app shell

### Loot Browser (new)
- Browse all dungeon, raid, and world boss loot by slot
- EJ-based scanning with spec and secondary stat filtering (Crit/Haste/Mastery/Vers)
- Two-row slot tabs: armor on top, accessories + weapons on bottom
- Difficulty columns (Normal/Heroic/Mythic for dungeons, LFR/N/H/M for raids)
- Item icons with difficulty-colored borders, tooltips on hover, shift-click to link
- Trinket tier badges (S/A/B) cross-referenced from SimC rankings
- Spec dropdown to browse loot for any spec
- Remembers selected slot across open/close (defaults to Head)
- Accessible from dashboard, app nav bar, and `/yh loot`

### Raid Tools
- Group display reordered: top row shows groups 1, 3, 5 and bottom row shows 2, 4, 6 for split visualization
- DK Grip distribution: suggests splitting Death Knights across raid splits for Mass Grip coverage
- Healer stacking fix: only suggests swaps when source split has 3+ healers (5-healer raids handled correctly)

### Profile System Simplified
- 6 profiles → 3: **Normal** (Casual/Delves/M+ up to 8), **Heroic** (Heroic Raid/M+ 10), **Mythic** (Mythic Raid/M+ 10+)
- Old profile IDs auto-migrate (heroic_raider → heroic, mplus_high → heroic, etc.)
- Each profile defines farmable track for smarter recommendations

### Recommendation Engine Improvements
- **SAVE_FOR_DROP**: "Hero drops from M+6-10 / Heroic raid — save Champion crests, wait for replacement"
  - Only triggers for low-rank items (1-3/6) with precious crests
  - Shows source hint (M+ key range + raid tier)
- **CREST_CAPPED**: "Need 20 Champion — capped until next reset"
  - Detects both weekly caps (Hero/Myth) and season cumulative caps
- Myth 2/6+ always recommended for upgrade (top track, nothing replaces it)
- Myth 1/6 still suggests using Hero crests for free promotion via overlap

### Trinket Rankings Refreshed
- Fresh SimC data: 60,000 iterations, 30 specs (ST + AOE), latest nightly profiles
- New spec: Rogue Assassination
- Item level shown on all trinket rows (Myth 6/6 = 289)
- Tooltips now show Myth 6/6 stats; shift-click links the Myth 6/6 version
- Removed legacy trinkets not in current loot pool

### UI Polish
- Unified underline tab style across all panels (Raid Tools, Consumables, Loot Browser)
- Dashboard app nav buttons in a 3x2 grid instead of single row
- Magisters' Terrace trinket sources corrected

## v1.2.0 — Raid Tools, Data Overhaul & Polish (2026-03-25)

### Recommendation System Reworked
- Crests can only be spent on their own track — addon no longer suggests "hold crests for higher track gear"
- Items now show explicit upgrade priority: "Upgrade 1st of 5 Champion", "Upgrade 2nd", etc.
- Priority based on slot value (weapons/chest/legs first, neck/wrist last)
- Crest scarcity calculated from total season budget (current + still earnable), not just inventory
- Overlap zone fix: "Use cheaper crests" only shows at rank 1 (not rank 2 where free ranks are already used)
- Profile changes instantly refresh all recommendations on the dashboard

### Raid Tools — Performance Tab (new)
- DPS rankings from Blizzard's built-in Damage Meter API (C_DamageMeter)
- Average DPS per player per split (A vs B) with imbalance detection
- Avoidable damage taken leaderboard
- Death count tracker
- Interrupt count tracker
- Uses current combat segment, falls back to overall

### Raid Tools — Overview Improvements
- Two-column layout: groups + swaps on left, composition + consumables on right
- Consumable checker: flask, food, augment rune status per player (spell ID based, taint-safe)
- Missing players listed by name next to each consumable type
- Raid buff list: one per line, cleaner layout
- Composition shown in large font with role breakdown
- Swap suggestions now show player names in bordered badges with class-colored borders
- "Swap All" button executes all suggested swaps via SwapRaidSubgroup API (raid leader/assistant only, out of combat)
- Debuff class distribution: suggests spreading Monk (Mystic Touch) and DH (Chaos Brand) across splits
- PI targets need same split (not same group) — corrected from 40yd range
- Player count balance: suggests moving healer if it fixes both size and healer imbalance
- Auto-refreshes on GROUP_ROSTER_UPDATE (instant update when players are moved)
- Group display always reserves 2 rows (no layout shift with fewer than 4 groups)

### Season 1 Data Updated
- Gear tracks: Champion 249/252/255, Hero 262/265/268, Myth 275/278/281 (ranks 2-4 corrected)
- Champion free ranks from Veteran: 2 (was 1)
- M+ crests: Heroic=Adventurer, M0=Champion, +2-3=Champion, +4-8=Hero, +9-12=Myth
- Raid: per-boss crest amounts, Void 6 bonus crest (20 base + 10 next tier), per-wing detail view
- Raid progression: clickable wing buttons (All / Voidspire / Dreamrift / Quel'Danas) with boss-by-boss detail
- Delves: Tiers 1-4 give Adventurer crests, Tier 10=Champion, Tier 11=Gilded Stash (10 Hero + 5 Myth)
- Delve cards grouped by crest type: Tier 1-4, 5-6, 7-10, 11
- Trovehunter's Bounty Map data added (tiers 4-11)
- Prey: Normal=Adventurer, Hard=Veteran, Nightmare=Champion
- Crafting: added Veteran tier, Spark of Radiance (no crests) tier
- M+ cards show ilvl ranges with track names (e.g. "259 - 263 Hero")
- M+ grouped as +2-5, +6-8, +9, +10-12

### Profile System
- Clickable dropdown on dashboard to switch profiles
- Profile change refreshes dashboard, gear recommendations, and suggestions instantly
- Hero crests now precious for Mythic Raider and M+ High profiles (weekly cap makes them limited)
- "What's New" window shows on version update with profile selector built in

### Trinket Panel — ChonkyCharacterSheet Support
- Trinket tab and panel now anchor to the actual visual right edge of the character frame
- Detects ChonkyCharacterSheet and anchors to CharacterFrameBg instead of CharacterFrame
- Panel inherits CharacterFrame scale when Chonky is active
- OnSizeChanged hook re-anchors on dynamic resize
- "All Specs" button collapses sidebar then opens app (no more panel stealing)

### Minimap Button — LibDBIcon
- Replaced custom minimap button with LibDBIcon-1.0
- Works correctly with ElvUI square minimap, SexyMap, and other minimap addons
- Draggable, position saved automatically by the library
- Embedded libraries: LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0

### Visual Polish (inspired by Plumber addon)
- DisableSharpening on all frame borders for smooth edges at any UI scale
- ADD blend mode highlights on hover (subtle glow instead of flat color change)
- Text shadows on all headers and titles for depth
- Consistent color hierarchy: primary (0.92), secondary (0.55), tertiary (0.35)
- All frames adapt to screen resolution (dynamic sizing via GetAppFrameSize)
- All popups clamped to screen (trinket detail, PI picker, profile dropdown)
- Frame z-ordering fixed: sub-panels normalized when inside app, no addon interleaving

### What's New Window
- Welcome screen now doubles as a "What's New" popup on version updates
- Shows "Welcome to YippYapp Helper" on first install, "What's New" on updates
- Features list + version-specific highlights
- Profile selector built in for immediate setup
- "Got it" saves the version — only shows again on next update
- `/yh whatsnew` to re-show

### Bug Fixes
- Frost DK and Devourer DH spec keys corrected for trinket rankings
- TIER_QUALITY defined before use (trinket detail popup quality borders)
- Swap badge frames and PI picker rows now pooled (memory leak fix)
- Tier tracker rows pooled (memory leak fix)
- Tainted aura name strings handled via spell ID lookup + pcall fallback
- Dashboard.lua removed call to nonexistent RefreshRaidTrinketDisplay
- quickBtnText dead references removed

---

## v1.1.0 — Midnight Season 1 Overhaul (2026-03-23)

### Unified App Window
- Replaced the old popup dashboard with a single unified app frame
- All features accessible from one window with back-button navigation
- Home page dashboard with character info, crest overview, upgrade summary, farm guide, and navigation buttons

### Gear Upgrades (redesigned in-app)
- Equipment panel scaled up for readability
- Info panel widened with 2-column crest display
- Suggestions redesigned as card-style rows
- New recommendation: "Use cheaper crests" for overlap zones

### Trinket Rankings (redesigned in-app)
- 3-column layout: S-Tier, A-Tier, B-Tier side by side
- Class/spec browser with ST/AOE toggle
- Fixed persistent "Loading..." issue
- Trinket data updated with latest SimC nightly

### Raid Tools (redesigned)
- Overview tab with composition, buffs, splits, PI assignments
- Tier Tracker tab (scan-on-demand)

### Progression Dashboard (redesigned)
- Card-based single-page layout
- M+ breakpoints, Raid by difficulty, Delve breakpoints, Prey, Crafting
- Crest Sources side panel

### Welcome Screen
- Draggable macro icon for action bar
- Macro auto-created on login

### Quality of Life
- Minimap button opens the unified app
- `/yh welcome` to reset welcome screen
