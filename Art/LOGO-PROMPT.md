# Logo prompt — YippYapp Helper

Two assets are wanted, from the same design:

| file | size | where it is drawn | how big on screen |
|---|---|---|---|
| `Media/LogoRound.tga` | 1024² master → 256² | the app window's top-left medallion | ~46px |
| `Media/YippYappHelper.tga` | 1024² master → 128² | the minimap button | **~20px** |

Both are cropped to a **circle** at runtime — `Shell.MEDALLION_MASK` for the
medallion, and the minimap button is round. Anything in the corners is thrown
away, so the design has to be circular by construction rather than a square
badge that happens to be round-ish.

The existing icon (`Art/icon-master.png`) fails at both, for two reasons worth
keeping in mind while judging what comes back:

- It is an **octagon**. The circular mask slices the flat top, bottom and sides,
  so it reads as an octagon with its edges shaved rather than as a round badge.
- It is **too finely detailed for 20px**. The rune carvings, the bevels and the
  inner disc all collapse into noise, and the chevron in the middle disappears
  entirely.

## Brand colours, sampled from the existing master

- gold: `#F0D050` highlight, `#F0C040` mid, `#D08010` shade
- purple: `#401070` field, `#300060` deep, `#401060` rim
- outline: near-black violet, around `#1A0E28`

---

## Prompt

> A circular game addon icon in the painted World of Warcraft style. A round
> stone medallion with a thick bevelled rim, filled with a deep violet-purple
> field, and a single bold gold four-pointed star centred on it — the star's
> points reaching almost to the rim but not touching it. Chunky sculpted gold
> with warm highlights on the upper-left edges and deep shade beneath, ringed by
> a dark violet outline that separates it cleanly from the purple behind. Rich
> hand-painted fantasy game art, high contrast, strong readable silhouette.
> Gold `#F0D050` to `#D08010`, purple `#401070` to `#300060`, near-black violet
> outline. Centred, symmetrical, filling the frame edge to edge. Transparent
> background outside the circle. Square canvas.
>
> Negative: no text, no lettering, no runes, no small carved detail, no thin
> lines, no inner ring or secondary disc, no octagon or square frame, no drop
> shadow outside the circle, no gradient background, not flat vector, not
> minimalist, no photorealism, no clutter.

## What to check on what comes back

1. **Shrink it to 20px.** If the star stops reading as a four-pointed star, it
   is too detailed — send it back with "simpler, bolder, fewer shapes".
2. **Mask it to a circle.** Nothing important should be lost. If the rim is
   clipped anywhere, the art is not truly circular.
3. **Squint at it.** Two tones should survive: gold shape, purple ground. If a
   third element competes at that distance, it is a candidate for removal.

## Variants worth asking for in the same style

- **Minimap-only, simplified.** Same medallion, but the star noticeably thicker
  and the rim thinner, so more of the 20px is the mark itself.
- **Chevron centre.** The current icon's gold disc with a purple chevron, if the
  plain star reads as too generic — but only if it survives step 1 above, which
  the current one does not.

## Dropping the files in

Save as 32-bit uncompressed TGA with power-of-two dimensions, into `Media/`.
`Core/ShellFrame.lua` already looks for `Media/LogoRound` and falls back to
`Media/YippYappHelper`, then to the player portrait, so the addon keeps working
before the art lands and picks it up the moment it does.
