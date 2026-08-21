---
name: yeeper-voice
description: Write or review dialogue for Mr. Yeeper, the in-addon commentator in YippYapp Helper (Features/Fun/Advisor.lua, Snark.lua). Use this whenever writing, rewriting, or critiquing any Yeeper line, aside, rule text or tip — and also whenever asked for "jokes", "snark", "roast lines", "teasing", or commentary for the addon, even if Yeeper is not named. Contains the voice rules, the register split, and a diagnosed list of failure modes that make addon humour read as generic AI output.
---

# Mr. Yeeper's voice

## Why this skill exists

Yeeper lines written without constraints come out bad in a specific, diagnosable
way: flat, hedged, and structurally identical to each other. They read like an
awkward person doing one-liners at a party where they know nobody. The form of a
joke arrives; the content never does.

There's a mechanism behind this. Language models are trained to predict the most
probable next token — the objective is minimising surprise. Humour is a
calibrated *departure* from the expected. So unconstrained output lands in the
worst available spot: probable enough to be predictable, and predictable is the
definition of unfunny.

"Try harder to be funny" does not fix this, because the failure is in the
default, not the effort. What fixes it is structure that pushes away from the
probable. That's what the rest of this file is.

## The one rule everything else serves

**The joke is the exaggeration of a real number. It is never a pivot away from
one.**

Yeeper has a snapshot of true facts about the player. Every good line takes one
of those facts and gets bigger, meaner or more specific about *that fact*. Every
bad line abandons the fact halfway through and reaches for atmosphere instead.

This is also the addon's stated design, at the top of `Features/Fun/Advisor.lua`:
the snapshot gathers facts, the rules reason, and personality is applied **last,
to a conclusion already reached on evidence**. A line that invents its own
evidence has the pipeline backwards.

## Banned moves

These are diagnosed from real failures, not hypotheticals.

**Vague menace.** "I think you are on a list." "I have seen things." "That is a
choice." These gesture at something ominous or knowing without naming anything.
They're the shape of a punchline with nothing inside. If a line implies a threat,
the threat has to be specific enough to picture.

**Hedges.** "I think", "at this point", "surely", "starting to think", "I
suppose", "somehow", "apparently". Every one of these softens the pivot, and the
pivot is the whole joke. Yeeper commits or says nothing.

**One mechanism, ten times.** This is the failure that keeps coming back, and it
is the most important thing in this file.

Fixing a bad template does not fix the problem — it relocates it. A batch written
as "flat numbers, then a wry clause" gets corrected, and the next batch comes back
as "observation → negation → verdict" in nine cases out of ten:

> You're not broke. You're just like this.
> You didn't push. You commuted.
> You're not undergeared. You're archaeological.
> You didn't join a guild, you joined a list.

Individually fine. As a batch, that's one joke with different nouns, and it reads
worse than any single line in it. Converging on the highest-scoring shape and
mass-producing it is precisely what minimising surprise looks like in practice,
so it will happen again unless something structural prevents it.

**The rule: every line in a batch uses a different mechanism.** Not different
data — a different machine. Pick from these, or invent others, but do not use one
twice in a batch:

| Mechanism | Shape |
|---|---|
| Reframe | "Not X. Y." — *now overused; rest it* |
| Question | Ask the obvious thing and stop |
| Faint praise | Congratulate the wrong achievement |
| Self-implication | Yeeper talks about his own experience of watching |
| Mock-clinical | Bureaucratic report language, no affect |
| Escalation | Pile figures on until it collapses |
| Imperative | Give an order, refuse to explain |
| Confusion | He genuinely does not understand the behaviour |
| Concrete analogy | Compare to something physical and absurd |
| Refusal | Announce that he will not be commenting |
| Repetition | Say the number again. And again. |
| Anticlimax | Build, then deflate to nothing |

Before presenting a batch, label each line with its mechanism. If two share one,
one of them is rewritten. If the labels are hard to assign, the batch is
homogeneous and needs redoing.

Also vary length for its own sake. Three words is a valid line. So is four
sentences. A batch where every entry is the same length is the same failure
wearing a different hat.

**Invented facts.** "A ring you already had, in a worse colour" — items don't
come in colours in WoW. Details borrowed from generic writing rather than from
the game are the loudest possible tell, and they also make the line unbuildable,
because the addon has no such field.

**Numbers that don't mean anything.** This is the subtlest failure and the worst,
because it survives a casual read. Before a line ships, say out loud what each
number *measures* and *in what unit* — and if the line compares two numbers, they
must share a denominator.

> Your drop rate this raid is 9%. The trinket you are farming drops at 15%. You
> are being outperformed by a trinket.

Sounds clever, means nothing. A player has no "drop rate": in group loot the raid
receives a fixed item count per boss and distributes it. The trinket's 15% is the
chance it appears among those items — a different denominator entirely. Two
unrelated figures placed side by side is not a comparison, and the joke rests on
a relationship that does not exist.

> Eleven bosses, zero items. Twelve if we count the one you wiped on, and I am
> counting it.

False premise. Wiping adds no boss and changes no loot; killing it on the ninth
pull pays exactly what the first pull would have. The line only works if wipes
count toward something, and they count toward nothing.

**States that cannot coexist.** Every field can be real and the *combination*
still impossible, because fields are wired to each other by game mechanics:

> Eleven bosses, no loot, and an empty vault. That's a clean sweep!

The Great Vault's raid row fills on boss kills. Eleven kills fills it completely,
so "eleven bosses" and "empty vault" cannot both be true — the line describes a
state the game will never produce. Same flaw in "zero drops and two vault slots
filled" after eight kills: those kills alone fill three.

Checking each number individually is not enough. When a line joins two fields,
ask what mechanic connects them and whether the picture it paints can exist at
once. Common couplings worth knowing: vault progress is driven by kills and
dungeon completions; crest income is capped weekly; idle crests imply no
upgradeable gear on that track; item level is a function of the gear that
produced it.

Getting this wrong is expensive in a specific way — it's the error that makes a
player conclude the addon does not actually understand the game, which is fatal
for a tool whose whole pitch is explaining the game better than the game does.

Naming a plausible-sounding field is not anchoring. The *claim* has to be true
about how the game works. In an addon whose whole pitch is surfacing economics
the game hides, a line that misunderstands the mechanics costs more than a line
that isn't funny.

**Mind-reading.** Yeeper reads a snapshot of numbers. He does not know what you
believe, what you told yourself, what you meant to do, or what you were looking
at. Lines that report your inner life are inventing data as surely as the colour
of a ring:

> ...You have been farming rating and **calling it gearing**.
> I built an entire warning for this. **You are looking straight through it.**
> You are not saving up. **You are just not doing it.**

The first attributes a claim the player never made. The second asserts he saw the
warning and ignored it — unknowable. The third narrates his self-deception.

The permitted version is *over-reading the numbers as an accusation*, which is
obviously a comic deduction rather than a report:

> A guild of ninety, fourteen online, and not one run with any of them. You are
> queueing with strangers **on purpose**.

Nobody thinks Yeeper has evidence of intent. The joke is that he's drawn the most
damning possible conclusion from three real figures and stated it as settled.

**Abstractions in the last position.** The line should land on something
concrete — an image, a scene, or an accusation. The lines that work end on
"sitting in your bag being nothing", "we will both have to look at it", "on
purpose". The ones that die end on "just not doing it" or "calling it gearing" —
abstractions where a picture should be.

**Stock internet phrases doing the work alone.** "Go outside." "Touch grass."
"Big yikes." Fine as seasoning on top of a real observation, worthless as the
observation itself.

## Gloating, not exasperation

The most persistent failure after the written/spoken one, and they look similar
enough to be confused constantly.

**Exasperation** is a friend frustrated *on your behalf*. It shouts, it repeats,
it capitalises — and it is fundamentally on your side.

> Eleven bosses and you came out with nothing. NOTHING. Eleven!

**Gloating** is someone enjoying your misfortune *at* you. Same facts, opposite
emotion.

> HAHA. Eleven bosses, zero items. Hope it was fun.

Emphatic restatement is not mockery. Capitals and exclamation marks make a line
louder, not crueller. If the line would work coming from someone who wants you to
do well, it isn't a roast yet.

Ingredients that produce actual glee:

- **Laughter, written out.** HAHA. Hahaha. It reads as delight in a way no
  amount of punctuation does.
- **Saying he's enjoying it.** "I'm going to enjoy this." "I've stopped watching
  your gear, I'm just here for this now."
- **Imagined social humiliation.** "Imagine explaining that to someone."
- **Predicting the repeat.** "And you'll go back next week. HAHAHA." Mocking the
  future is crueller than mocking the past.
- **Unfavourable comparison.** Everyone else got something. You got a repair bill.

Note that gloating still obeys every rule above it: no invented facts, no motive,
no meaningless numbers, and nothing that sneers at legitimate play. Cruelty is not
a licence to be wrong.

## Spoken, not written

The most common failure in this file's history, and the hardest to see: lines
come out as *prose* when they need to be *speech*. Yeeper is a voice shouting at
one person. He is not a caption under a photograph.

| Written (wrong) | Spoken (right) |
|---|---|
| Eighty thousand gold. Four unenchanted slots. What is the gold for? | Mate, you've got 700k gold and you still haven't enchanted your gear? |
| I've started to feel watched. | You stalking me, or what? |

The written versions aren't badly built — that's the trap. Sentence fragments,
cool detachment and a rhetorical question aimed at nobody all read as *good
writing*, which is precisely why they get chosen and precisely why they're wrong
here.

Markers of the spoken register:

- **Direct address.** "Mate." "You." He is talking *to* the player, not
  describing them to a third party.
- **Full sentences with normal grammar.** Fragments are a literary device.
- **Real exasperation** — question marks, exclamation marks, repetition,
  capitals. "ELEVEN percent?!"
- **Blunt words over clever ones.** "Get off your lazy ass" beats any elegant
  construction. Reaching for the elegant phrasing is the tell.
- **Comic threats and deadlines.** "Fix it or I'm telling the guild. You have one
  day." Absurd stakes, delivered seriously.

If a line would look at home as a caption, rewrite it as something a person would
actually say out loud with their voice raised.

## Behaviour is knowable. Motive is not.

A subtler relative of mind-reading, and easy to miss because the *facts* are all
real. Run counts are real, drop tables are real, the spec's best trinket is real.
The fabrication is the word joining them:

> Nine runs of Murder Row. Four and a half hours in the same corridor **for one
> trinket**.

Nobody runs a dungeon nine times for a trinket. They run it for rating, crests,
the vault slot, the weekly, or because that is the keystone they were handed —
Mythic+ barely lets you choose the dungeon. The line assigns a purpose the player
never had, and a player who was there for score reads it as the addon not
understanding the game.

**Two safe options:**

*State the facts and claim nothing.* Put the numbers side by side and let the
player make the connection themselves — it's funnier anyway, because they do the
work.

> Fourteen runs of Altar of Fangs. The best trinket for your spec drops in there
> and you're still not wearing it.

*Or use declared intent.* `YippYappHelperDB.lootFavorites` is the player
explicitly marking an item as wanted. That is a stated goal, so lines built on it
may assign motive freely, and they land harder for being specific:

> You've favourited that trinket. Fourteen runs of the dungeon it drops in. Still
> nothing.

Generally: prefer stating two true facts adjacently over asserting the causal
link between them.

## Low-yield mechanisms

*Refusal* ("I'm not saying anything. I've said enough.") reliably underperforms.
Announcing you won't comment and then commenting is a tired construction, and it
spends a whole line on a joke about withholding rather than on the data. Reach
for it rarely, if at all.

## Check that the demand is possible before making it

A big number is not a reason to shout. Before a line orders the player to do
something, confirm the action exists and that the snapshot condition genuinely
implies it. Two real failures:

**"Go and spend them."** `idleAmount` fires only when `need[track] == 0`, and
`need` counts upgradeable equipped items. So idle crests mean *nothing you own
can absorb them* — the one thing the player cannot do with those crests is spend
them at the upgrade vendor. The honest version sends them at a crafting order or
a drop, because those are the sinks that actually exist.

**"No. Put it down."** Implies watching a click as it happens. Yeeper renders in
the home dashboard (`Core/AppFrame.lua`) and nowhere else — he is not at the
upgrade vendor and cannot see an imminent purchase. `ns.upgradeVendorOpen` exists
if a vendor-gated line is ever wanted, but without that gate the framing is a
fabrication about what he can observe.

Ask of every imperative: *can they actually do this right now, and does the
condition that fired the line really mean what the line says it means?* Where the
addon's own recommendation engine has an opinion on the same crests, Yeeper must
not contradict it — being shouted at to spend while the gear page says hold makes
the whole addon look like it disagrees with itself.

## Never sneer at legitimate play

Some behaviour looks wasteful from a spreadsheet and is completely correct in the
game. Mocking it makes Yeeper sound like he doesn't play.

The clearest case: **pushing keys above the vault ceiling is not a mistake.**
Rating is the point of Mythic+ for most players and gear is the byproduct. A line
implying those runs were pointless — or that the player hadn't realised — is both
condescending and factually wrong about how people play.

The test: if the "mistake" is actually a goal someone might hold on purpose, the
joke has to be about something else. Yeeper can be rude about *neglect*
(unenchanted slots, rotting crests, last season's gear, unrepaired armour). He
does not get to be rude about *choices that are simply not his priority*.

## The genre: AI roast

The target is the "AI roasts your Spotify Wrapped / GitHub / LinkedIn" register.
Hold that in mind above every abstract rule in this file — it produces better
lines than the rules do, because it's a real thing with a real shape.

The move: **take mundane data, deliver a devastating verdict on the person.** The
comedy is the gap between how trivial the number is and how severe the conclusion
is, stated with total machine confidence and zero softening.

> You listened to the same four songs nine hundred times. You don't have a
> personality, you have a playlist.

Note what that does. It doesn't observe. It *concludes* — and the conclusion is
about who you are, not about the number. Yeeper has read your snapshot and he has
Decided Things About You.

This is compatible with the no-mind-reading rule and clarifies it: a damning
verdict inferred from visible numbers is the whole genre. Claiming to know
unobserved events — what you said, what you looked at, what you told yourself —
is still off limits. "You joined a list, not a guild" is a verdict. "You told
yourself you'd get to it" is a fabrication.

Lines should be **short**. Setup, then the verdict. Most of the good ones are two
sentences and the second one is shorter than the first.

The volume reference:

> HAHA, ZERO items??? Skill diff surely.

The limit is **not** subject matter, and it is not tone. It is this: *the
actionable fact has to survive the volume.* If a line carries advice, the player
must still know what to do after the shouting stops.

> TWO HUNDRED Hero crests. Two hundred. They do not gain interest. Go to
> Silvermoon.

Unhinged and perfectly actionable. An earlier version of this skill said
"deadpan for advice, unhinged for RNG" — that was over-cautious, and it quietly
confined the whole character to one topic. Volume is available everywhere; only
clarity is non-negotiable.

**Where the best material actually lives:** not luck. Bad rolls are safe to mock
but thin, because there's nothing to accuse anyone of. The rich seam is
*negligence and self-deception* — four unenchanted slots with 80,000 gold in the
bank, 200 crests rotting in a bag, five slots still wearing last season's gear,
six keys above the ceiling farmed in the belief they were gearing. Those are
choices, and a choice can be prosecuted. Spread the material across the whole
snapshot rather than parking it on loot.

## Who the target is

Always the person who installed the addon. Never a named other player.

"You got one, somebody in there got five" is fine. Naming Kordran and mocking
*him* is not — he didn't opt into this, and it turns a joke about your luck into
a screenshot about someone else. Aggregate other players; never single one out.

## The line bank

`references/lines.md` holds every line written so far — approved, unjudged, and
rejected-with-reasons — grouped by subject and labelled by mechanism. Read it
before writing new material: it shows which mechanisms are already spent on a
given subject, and the rejection table is the fastest way to see the failure
modes in their natural habitat rather than as abstract rules.

Add new lines there rather than letting them evaporate into a chat log.

## Real snapshot fields

Lines must be buildable. `AD:Snapshot()` in `Features/Fun/Advisor.lua` is the
authority — check it before writing, since it grows. As of now it carries:

**Gear** — `ilvl`, `upgrades[]` (slot, track, rank, maxRank, gain, cost),
`stale`, `maxed`, `totalGain`, `cheapest`, `biggest`, `unenchanted[]`
**Crests** — `crests[track]` (have, earnedThisWeek, weeklyMax, capped), `need`,
`affordable`, `shortfall`, `shortTrack`, `idleTrack`, `idleAmount`,
`crestWaste[]`, `crestWasteTotal`
**Mythic+** — `mplusLive`, `daysToKeys`, `mplusScore`, `runs`, `runsTen`,
`keyCeiling`, `runsAtCeiling`
**Vault / raid** — `vaultFilled`, `vaultTotal`, `raidName`, `raidKills`,
`raidTotal`, `raidDiff`
**Social** — `inGuild`, `guildSize`, `guildOnline`, `guildRuns`, `social`
**FunStats** — `jumps`, `homeOpens`

`homeOpens` is worth remembering: Yeeper counting how often you reopen the panel
is established, lands well, and is unavailable to any other addon.

## Lines that work, and why

From the shipped codebase:

> 200 Hero crests and nothing queued to spend them on. They are not doing
> anything in there.

The number is real. "Not doing anything in there" is a specific, slightly stupid
image — crests as idle objects in a container — rather than a general comment
about waste.

> You have jumped 4,000 times since I started counting. I mention it because
> nobody else will.

The punch isn't the number, it's Yeeper's reason for raising it. Attitude applied
to true data, which is the whole formula.

> Nothing left to fix and you are still running keys. That is either dedication
> or a lack of hobbies.

Late pivot. The last four words carry it, and nothing follows to dilute them.

## Lines that failed, and why

> Eleven bosses. Two items. One of them was a ring you already had, in a worse
> colour.

Invented a fact to reach a joke shape. Items have no colours. Unbuildable.

> Six bosses since anything dropped for you. Six. I think you are on a list.

Vague menace plus a hedge. "On a list" names nothing.

> At this point you are just doing cardio.

"At this point" is dilution, and the metaphor is generic — it would fit any
activity in any game.

## How to actually produce these

Roast writers do not write one good line. A single joke goes through ten or more
drafts, and professionals write forty to keep three. Match that:

1. **Pick one real field and get specific about it.** Not "you were unlucky" —
   "two items in eleven bosses while the raid averaged four".
2. **Write ten, not one.** The first three will be the probable ones. The
   interesting material starts after you've exhausted the obvious.
3. **Vary the structure deliberately across the batch.** Pure reaction. The
   "I'm not saying X, I'm saying [X]" move. Escalation. A three-word line. A
   callback to another field. If two lines in a batch share a rhythm, cut one.
4. **Read each one back and ask what fact it rests on.** If the answer is "a
   mood", it's dead.
5. **Present in batches of ten for a human to cut.** Judging funny and writing
   funny are different skills; the human has the first one. Expect seven of ten
   to die, and treat that as the process working rather than as failure.

When drafting in conversation rather than writing into a file, say so — chat
output isn't reviewed by anything, and that's where the sloppiest lines get
through.
