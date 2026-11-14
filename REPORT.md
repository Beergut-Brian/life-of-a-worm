# REPORT: worm-d105-content-s12-1 (D105 content, stages 1 and 2)

Branch `feature/worm-d105-content-s12-1`, based on origin/dev `4a3d96f` (merge of origin/dev at the
start: already up to date; origin/dev had not moved at the end). Not pushed.

## What changed
- **Sync (first commit `a972e3b`):** no row could move. Every partial/missing row is art, audio, a
  GTX 1060 run, pacing (D105) or a milestone tag. Recounted the Totals line and noted on R-08 that
  its jar piece (S-10) is built on dev since PR #95.
- **27 new things for stages 1 and 2** (15 foods, 6 creatures, 6 ring events), all data in the
  files the rings already use, each pinned by `tests/test_d105_stage12.gd` (exists, its stage, met
  in play on a real PolarWorld with the real RingsDirector). Listed one a line, with stage and test,
  in GAME.md "D105 content (stages 1 and 2)".
- Small code to carry the data:
  - `RingLife.late_scatter` / `late_scatter_count`: a ring's new foods are placed after every older
    static (after the sky, surface and late secrets), so a saved tin keeps its slots
    (`::test_older_tins_keep_their_static_slots`, `::test_a_worm_eats_a_new_food_and_a_tin_keeps_it_eaten`).
  - `RingEvent` (resource) + `RingEvents` (RingsDirector child, stepped from `tick()` on the planet
    clock): a visible event happens beside a worm of its stage in its ring after `first_after`, then
    every `every` planet seconds. BURST (foods pop out with a puff), FALL (foods seen falling from
    above), RING (round the worm). Existing cue and puff; never moves the worm; foods not saved, at
    most 24. Signal `happened(id, at)`. Contract appended to `docs/contracts.md`.
  - `SwapShop.seed_for`: the plain seed first among equal-size seeds, so the Mole keeps giving
    plain seeds for root things now that the cherry pit also plants a root garden.
- Tests adjusted for the late foods (the sweeps that assumed the late secrets' foods are the very
  last statics, and the book's "grows somewhere" source list): `test_secret_surface`,
  `test_secret_balloon`, `test_secrets_3`, `test_book_long_tail`. `RingsDirector.late_food_count()`.
- New trophy family members (every find in one family): shinies, stones, snacks.
- **Pacing untouched:** no edit to `data/stages.tres`, `worm_rules.tres` or `data/BALANCE.md`.

## The new things (27)
Foods (15): carrot tip, snail shell, marble, button, clay lump, potato (size 2), old spoon (size 2)
in the dirt (stage 1); wild berry, cherry pit (plants a root garden), clover leaf, lost coin, glass
bead, chalk bit, walnut (size 2), crayon (size 2) in the topsoil (stage 2).
Creatures (6): mite, wireworm (dirt); aphid, caterpillar, snail, shield bug (topsoil; the only new
threat, size 3, 1.2 s wind-up, hunts aphids).
Ring events (6): root burst, marble spill, egg clutch (dirt, stage 1); seed shower, fairy ring
(rain only), dew drip (topsoil, stage 2).

Honest notes on likeness: the marble spill and the root burst share the BURST shape (different
food, cue and puff); the seed shower and dew drip share FALL. The potato/walnut and spoon/crayon
pairs are the same idea (too big at stage 1) in two rings.

## Kid rule: something new at least every 15 minutes (stages 1 and 2)
`tests/test_d105_novelty.gd`, seeds 1 to 5, kid and adult, signals only: **worst gap 4.0 min**
(older things only, same runs: 5.0 min). Per-seed table in `handoff/content.md`. Under 15, so no
extra content was added for the rule. On dev's short pacing a kid meets 12 to 16 of the 27 inside
stages 1 and 2; all creatures and events are met in at least one seed.

## Art and sound (no files added)
Every new thing reuses a code-drawn placeholder look and an existing cue (no image, audio, voice or
music file). Closest-existing picks to flag for the Art Director:
- Creatures: mite, wireworm, aphid, caterpillar use the grub's three-blob look in their own colours;
  the **snail and shield bug use the beetle's round-shell look** (no snail or shield-bug sprite).
- Foods: snail shell = the fossil's curled-shell look; marble, clay lump, potato, wild berry = blob;
  button, lost coin, chalk bit, walnut = pebble; old spoon = ore nugget; glass bead = crystal
  cluster; crayon = crumb; carrot tip, clover leaf = root; cherry pit = seed.
- Cues: world_sprout, rock_beetle_clack, jar_clink, world_munch, boop, home_seed, creature_munch,
  world_seed, egg_crack, grub_squeak, beetle_blink, beetle_windup.

## Skipped
- `git branch -r --no-merged origin/dev`: only `origin/feature/art-rings-1` and
  `origin/feature/art-worms-1` (art, held; ignored per brief). No unmerged `origin/feature/worm-*`
  or `origin/fix/*` branch, so no row was skipped for a remote branch.
- Local unpushed branches still ahead of dev (stale, 13 to 35 h old): `feature/stages-1`,
  `worm-ambience-1`, `worm-big-planet-1`, `worm-gap-close-2/4/6/8/42`, `worm-jar-2`,
  `worm-kid-checks-1`, `worm-star-traits-1`. None builds D105 content; none touches the files this
  lane edits except the shared docs every lane edits (GAME.md: stages-1, star-traits-1;
  PLAN-STATUS.md: most; docs/contracts.md: ambience-1, big-planet-1, jar-2, star-traits-1). Expect
  only append conflicts there. Nothing in stages 3 to 7 and no pacing work was done (later lanes).

## Moved row IDs
- Added: **D105-1** (built). No existing row changed status. Totals line recounted (274 rows: 211
  built, 30 partial, 21 missing, 5 superseded, 4 dropped, 3 later). R-08: note only.

## Tests
Full suite from a clean import (`rm -rf .godot`, `--import`), gdUnit `--continue`, run twice:
**955 test cases, 0 failures, 0 errors** both times (dev base `4a3d96f`: 933). No "ObjectDB leaked"
line (the new suite drains the event cues in `after()`). Logs: `.scratch/run5.txt`, `.scratch/run6.txt`.

## Frames (looked at)
- `handoff/frames/d105_dirt/t001.0s.png`: a stage-1 worm in a dug pocket; the marble spill (blue
  marbles + confetti) and root burst (carrot tips) beside it, the wireworm (big yellow grub, too big
  to eat yet), a mite (red) and a snail shell. `t002.2s.png` the same a second later.
- `handoff/frames/d105_topsoil/t002.2s.png`: a stage-2 worm in the topsoil; the fairy ring of
  mushrooms round it, the seed shower's cherry pits landed in a line, caterpillar, snail, shield
  bug, aphid, wild berries, a crayon. (The topsoil apex stag beetle wandered into the staged pocket.)
- Driver: `.scratch/d105_shot.tscn -- --mode=dirt|topsoil` (throwaway profile under `.scratch/`).
