# Life of a Worm: main-character sub-decision A-002 (AD, 2026-11-12)

Gate 1 approved the B+A mix (A-001). This is the pick for the player worm's design inside that look.
Both players use the same worm: the slot colour (green / red) is the collar and glow, per A-001.

## What was made
`compare.png` (all three side by side), plus one sheet per candidate: `c1-annelid.png`,
`c2-lamplit.png` and `c3-plated.png`. Each sheet has the side view at 1x and 3x (plain, P1, P2),
the worm at 3x in the Gate-1 mix frame (the real stage-1 camera), and a stage 1→5 size strip at
true screen size, including the stage-5 slot glow. The 1x sprites are in `sprites/`, and the ΔE and
size measurements in `deltae.json`. They were made by `art/tools/worm_master_candidates.py` from the
three Gate-1 proof worms (`proofs/{a,b,mix}-worm-plain.png`, derived from Kaden's P2-1 and P5-1).
The script straightens, resamples, remaps to the v1.0 flesh ramp, and adds the game-rule collar,
separators, eye pixel and outline. No new look is invented in code.

All three meet the A-001 conditions:
- Body thickness at stage 1: C1 9, C2 10, C3 10 art px. Lengths are 48 / 46 / 44.
- Every flesh colour is ΔE00 ≥ 20 from P2 red. The closest is `#c4917c` at 21.3.
- There is a 1 px dark separator either side of the collar.
- One 1 px eye, no mouth.

**What these are:** proportion, colour, collar and scale tests. They are not the final drawing. They
are straight because the game curves the worm by its segment chain. The hand-drawn quality comes from
the master concept (`PROMPT-PACK.md`) and the 1x clean-up after it.

## Candidates
| | C1 Annelid | C2 Lamplit | C3 Plated |
|---|---|---|---|
| From | P2-1's slender ringed annelid (A's worm) | the Gate-1 mix proof worm (P5's warm ramp and top light on P2's body) | P5-1's segments, legs removed, flattened |
| Read at 3x | most clearly an earthworm: thin rings, a saddle you can see | strongest presence: a warm lit top and a dark belly, the brightest form in the frame, smooth | bluntest and most "game sprite"; the segments read even at stage 4 |
| Collar | sits on the saddle; reads | cleanest: a smooth body around a sharp band | reads, but competes with the plate lines |
| Risks | the busiest at 1x; the ring stripes get noisy and the tail is spindly; the weakest at 0.5x | can read as a smooth larva or sausage without a hint of rings; needs the master to add ringing | regular plates edge toward a caterpillar (the brief's "toy" risk); the least like P2, which Kaden kept for anatomy |
| Stage 5 at 0.5x | 64x8 on screen; the glow carries it | 64x9; holds its light/dark split best | 59x9; the plates turn to stripes |
| Production | the hardest to animate cleanly (rings must slide with the crawl) | the easiest: the ramp follows the light, so the crawl is a squash wave | easy: segment sprites on the chain |

**AD recommendation: C2 Lamplit**, with C1's fine rings added faintly in its master (1 px shadow
lines every 3-4 px, only on the lit top). C2's master prompt already asks for them, so this is not a
separate option. C2 keeps the B half of the mix (P5's light) and C1's rings keep the A half
(P2's anatomy). It holds best at 0.5x, it is the cheapest to animate, and its smooth body makes the
collar the cleanest read for both players. The faint rings answer its one risk (sausage/larva).

## Two smaller questions that ride along (both change the sprite set)
1. **P2's eyes.** GAME.md gives P2 "two small eyes, a little cross-eyed". In side view that is one
   extra pixel above and behind the near eye. Keep it (recommended: a cheap personality read that is
   not colour-only, which also helps a colour-blind viewer) or have both worms identical apart from
   colour?
2. **Stage features** (bow/cap at 3, monocle at 5, crown of stars at 7). In this look they risk the
   mascot read. Options: (a) keep them, drawn as natural parts (a leaf-bow sprout, a lens-like
   dewdrop over the eye, a halo of tiny orbiting moons); (b) swap them for anatomy (horn plates, a lamp
   organ, a star-speckled saddle); (c) decide at stage 3. Recommendation: (a). It keeps GAME.md's jokes
   and makes them belong to this world.

## A-002 question for the producer to post (text for Kaden)
> **Life of a Worm: pick the worm (A-002).** Three worms in the look you approved, at the real game
> size, with your green and red as the collar (sheet attached: `compare.png`).
> - **C1 Annelid:** slender and ringed, closest to your P2 worm.
> - **C2 Lamplit (recommended):** smooth, warm and lit from above, the brightest thing on screen (from the
>   Gate-1 test screen); faint rings get added in its master image.
> - **C3 Plated:** chunkier, with visible flat segments, the most "game sprite".
>
> Reply with one: **C1 / C2 / C3 / revise one (say which and what to
> change) / hold.**
> Also, if you like: P2 gets a second tiny eye pixel (**yes / no**), and stage features (bow,
> monocle, crown of stars) are **kept as natural parts / swapped for anatomy / decide later**.
> Next: one short Midjourney step for the picked worm's master image (prompts attached), then
> everything else is made from that master without you.

Log the answer in `art/approvals.md` as A-002 (quoted). Silence is `no decision` and the pick stays
open.

Provenance: the candidate images and sprites come from `art/tools/worm_master_candidates.py`
(builder subagent under the AD lane, 2026-11-12). They are derivatives of Kaden's round-1 Midjourney
picks via the Gate-1 proofs, and are internal concepts, not shipping assets. One line per file is in
`art/provenance/generation-jobs.jsonl`. This file was written by the AD lane (Claude, Opus 5.5).
