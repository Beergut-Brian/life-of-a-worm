# REPORT: worm-d105-content-s37-1 (D105 content, stages 3 to 7)

Branch `feature/worm-d105-content-s37-1`, based on origin/dev `774c528` (merge of origin/dev at the
start: already up to date). Not pushed.

## What changed
- **Sync:** no existing row could be proven to move. Every partial/missing row is art, audio, a GTX
  1060 run, pacing (D105), a milestone tag or a design call (same finding as the s12 lane a few hours
  ago; nothing landed on dev since). So there is no separate sync commit: the one commit adds row
  D105-2 and recounts the Totals line.
- **140 new things for stages 3 to 7** (stage 3: 29, stage 4: 26, stage 5: 33, stage 6: 27, stage 7: 25),
  each pinned by `tests/test_d105_stage37.gd` (exists, opens at its stage, met in play on a real
  PolarWorld + RingsDirector, or on the real space stage). One line each, with stage and test name, in
  GAME.md "D105 content (stages 3 to 7)"; the table is `tests/d105_stage37_table.gd`.
- Small code to carry the data (`scripts/rings/` only; contract appended to `docs/contracts.md`):
  - `RingLife.later_scatter` / `later_scatter_count`: this slice's foods are placed after every s12 late
    food, in `RingsDirector.all_lives()` order (tile rings, then the sky, then the surface), so a tin
    saved on dev today keeps every static slot (`::test_older_tins_keep_their_static_slots`).
  - `PopulationRule.stage_from`: a new creature of an older ring spawns only near a worm of its stage,
    and goes away if that worm shrinks below it (`::test_new_creatures_wait_for_their_stage_then_spawn_near_a_worm`,
    `::test_a_worm_that_shrinks_below_the_gate_sees_them_go`). Old counters are unchanged (0).
  - `RingEvent` shapes TRAIL (a line popping up in turn), ROLL (rolls in from the side, turning), RISE
    (bobs up from below) (`::test_the_new_shapes_trail_roll_and_rise`); `RingEvents` now plays the sky's
    and the surface's events too.
  - `SpaceSight` / `SpaceSightSet` (data `data/rings/space_sights.tres`) and `SpaceSights`, a new child
    node of `scenes/levels/space_stage.tscn`: it brings each sight's bodies in round the worms as
    `SpaceDrift` smalls of kind `sight`, so the stage's own rule eats or bumps them. **No file in
    `scripts/space/` changed.**
- Tests adjusted for the new data (each assumed the old shape): `test_d105_stage12` (older-tin slots:
  leave this slice's foods out of both runs), `test_d105_novelty` (respect `stage_from`),
  `test_secrets_3` (this slice's foods come last), `test_rings_content` (core and deep-rock chains
start with their own species, then the D105 ones), `test_sky_ring` (count only the sky's first
  scatter), `test_surface_ring` (the grass now has creature bodies), `test_book_long_tail` (later
  scatter is a planet source).
- New finds join trophy families by flavour (shinies, stones, snacks).
- Creature radii follow their size class like the existing ones (size 3: 14.5 px, 4: 16.5, 5: 18.8,
  6: 20.8), so "bigger than me" reads from size alone (K-01, `test_kid_checks::test_k01_...`, which
  caught my first, smaller radii on the full run).
- **Pacing untouched:** no edit to `data/stages.tres`, `worm_rules.tres` or `data/BALANCE.md`. The stage
  times `test_balance_stages` prints are identical to dev's (checked on a clean dev worktree).

## The new things (140)
| stage | foods | creatures | ring events | space sights | total |
| --- | --- | --- | --- | --- | --- |
| 3 (dirt + topsoil, size 3) | 12 | 6 | 11 | | 29 |
| 4 (deep rock) | 12 | 4 | 10 | | 26 |
| 5 (core, surface, sky) | 15 | 4 | 14 | | 33 |
| 6 (size 6, every ring) | 12 | 3 | 12 | | 27 |
| 7 (space) | | | | 25 | 25 |
| all | 51 | 17 | 47 | 25 | 140 |

- Stage 3 foods: turnip, toy car, flower pot, big bone, flint chip, tulip bulb (plants a root garden),
  tin can, garden glove, rubber duck, pine cone, pickle, sunflower head. Creatures: earwig (threat),
  millipede, June bug, slug, grasshopper, toad (threat). Events: turnip heave, toy box, old dig, flint
  vein, pot tumble, duck wash (rain), glove drop, cone drop, can roll, sunflower ring, pickle trail.
- Stage 4: coal lump, thunder egg, ammonite, pick head, cave pearl, glow cap, salt crystal, spring
  bubble, miner lamp, cart wheel, rail spike, moss ball; cave cricket, gem beetle (threat), cave fish,
  crystal crab; coal seam, thunder crack, pearl drip, spring bubbles, cart roll, glow ring, fossil
  trail, rail line, lamp drop, salt heave.
- Stage 5: fire opal, lava rock, glow seed (plants a crystal garden), magma bubble, iron ball (core);
  pumpkin, corn cob, watermelon, newspaper, garden gnome, bird house (surface); kite, soap bubble,
  dandelion puff, snowflake (sky); magma newt, fire beetle (threat), frog, hedgehog; magma burst,
  ember rise, crystal sprout, lava roll, pumpkin roll, harvest heap, paper blow, melon drop, gnome
  ring, bird house fall, kite string, bubble rise, snow fall (rain), dandelion drift.
- Stage 6: hay bale, bathtub, rusty anchor, old piano, hot air balloon, rain cloud, blimp, star chip,
  magma gem, dino skull, time capsule (in the dirt), old wheelbarrow; old tortoise, magma eel,
  jackrabbit; cloud bank, balloon race, blimp pass, star fall, hay roll, yard sale, anchor drop, piano
  tumble, magma geyser, big dig, capsule rise, barrow tip.
- Stage 7 space sights: asteroid drift, meteor shower, stardust ring, satellite, ice chunks,
  moonlets, rocket bits, nebula puffs, space jelly, gold asteroid, star seeds, comet crumbs, lost
  telescope, space sock, lost lunchbox, rogue moon (too big: bumps), crystal shards, space cloud, glass
  planets, cosmic bubbles, ring rocks, dust bunnies, star noodle, sun sparks, last light.

Honest notes on likeness (so the producer can judge padding):
- Events reuse six shapes (BURST, FALL, RING, TRAIL, ROLL, RISE), each with its own food, cue, puff and
  ring; e.g. pearl drip and lamp drop are both FALL in the deep rock, the four RING events differ by
  food and ring.
- Space sights are four shapes of round bodies in their own colour and size (code-drawn like the
  moons). Closest pairs: stardust ring / cosmic bubbles / last light (rings round the worms, different
  size, colour, timing); meteor shower / comet crumbs / sun sparks (streaks); satellite / lost telescope
  / lost lunchbox / space sock (single drifting junk). These are the thinnest of the 140; I kept them
  because each arrives at a different point of space (after 0 to 5 planets) and the kid sees each
  as its own thing, but they are the first to cut if the producer counts them as copies.
- The size-6 "big finds" share the "come back bigger" idea across rings (as the s12 potato/walnut did).

## Kid rule: something new at least every 15 minutes (stages 3 to 7)
`tests/test_d105_novelty37.gd`, seeds 1 to 5, kid and adult, signals only: **worst gap 4.0 min**
(8.5 min counting only older things in the same runs). Per-seed table and the sim's model of space in
`handoff/content.md`. Under 15, so nothing was added for the rule. On dev's short stages a kid meets 71
to 85 of the 140 by the sun; with the proposed longer stages (a what-if in the test only) every
creature, event and sight is met at least once across the seeds.
Side effect: the stage 1-2 novelty test still passes, worst gap 4.3 min (dev 4.0), because the sim
draws the size-3 finds in the dirt and topsoil as bonks. Details for the pacing lane in
`handoff/content.md`.

## Art and sound (no files added)
Every new thing reuses a code-drawn placeholder look and an existing cue. Closest-existing picks to
flag for the Art Director:
- Creatures take the look of their behaviour: **trundlers wear the beetle's round shell** (earwig, toad,
  gem beetle, crystal crab, fire beetle, hedgehog, old tortoise), **wavers the centipede's wave**
  (millipede, cave fish, magma newt, magma eel), **hoppers the lava blob's bouncy blob** (June bug,
  grasshopper, cave cricket, frog, jackrabbit: the weakest fit), the slug the grub's blobs. No toad,
  frog, hedgehog, tortoise, fish or rabbit sprite exists.
- Foods: turnip, rail spike, corn cob = root; toy car, flower pot, coal lump, cart wheel, lava rock,
  garden gnome, old piano, old wheelbarrow = pebble; big bone, ammonite, dino skull = fossil curl; flint
  chip, salt crystal, fire opal, snowflake, star chip = crystal; tulip bulb, pine cone, glow seed =
  seed; tin can, pick head, bird house, rusty anchor, time capsule = ore nugget; garden glove, rubber
  duck, cave pearl, moss ball, iron ball, pumpkin = blob; pickle, spring bubble, magma bubble, soap
  bubble = honeydew drop; sunflower head, glow cap = mushroom; thunder egg, magma gem = geode; miner
  lamp, watermelon, bathtub, hot air balloon = egg; newspaper, hay bale = crumb; kite, blimp = toy
  plane; dandelion puff, rain cloud = cloud. (Old piano, bathtub and wheelbarrow as pebble/egg are the
  weakest fits.)
- Space sights: the moons' code-drawn round body (`SpacePlanet` small), in each sight's colour and size.
- Cues (all existing): beetle_blink, beetle_windup, bird_tweet, boing, bonk, book_flip, boop, burst,
  drop, egg_crack, grub_squeak, home_seed, jar_clink, lava_blob_blorp, lava_blob_swell, ring_open,
  rock_beetle_clack, rock_beetle_windup, secret_found, space_bump, space_drift, warp, wiggle,
  world_munch, world_seed, world_sprout.

## Skipped
- `git branch -r --no-merged origin/dev`: only `origin/feature/art-rings-1` and
  `origin/feature/art-worms-1` (art, held; ignored per the brief). No unmerged `origin/feature/worm-*`
  or `origin/fix/*` branch, so no row was skipped for a remote branch.
- Local unpushed branches (not in the brief's check, listed for the producer): none touches a file this
  lane edits except PLAN-STATUS.md (append conflict only). `feature/worm-gap-close-43` (a sibling, live
  now) edits planet_chomp / polar_world / polar_shape. Local `feature/worm-star-traits-1` (32 h old)
  edits `scripts/space/space_drift.gd`: `SpaceSights` calls `SpaceDrift._small`, `done` and
  `SpaceStage.worms_centre()`; if that branch lands and renames them, `test_d105_stage37`'s space tests
  go red first.
- Not done (other lanes): applying the pacing proposal; surface props for stages 5 and 6 (their tests
  pin each prop's look to its own id and its size to 3 or 4, so a new prop is art plus a test change).

## Moved row IDs
- Added: **D105-2** (built). No existing row changed status. Totals line recounted (275 rows: 212 built,
  30 partial, 21 missing, 5 superseded, 4 dropped, 3 later).

## Tests
Full suite from a clean import (`rm -rf .godot`, `--import`), gdUnit `--continue`, run twice:
- run 1: 978 test cases, 4 failures: `test_rings_content` x2 (pinned each ring's exact species list;
  fixed), `test_kid_checks::test_k01_...` (my first creature radii were too small to read as bigger;
  fixed by radius per size class), `test_greybox_planet::test_hold_b_warps_home` (the known
  first-run-after-import flake; passed on rerun).
- run 2 (with the fixes): **978 test cases, 0 failures, 0 errors**, no "ObjectDB leaked" line
  (dev base after s12: 955; +19 `test_d105_stage37`, +4 `test_d105_novelty37`). The three fixed suites
  also pass on their own after the radius change (`.scratch/run_h.txt`).
Logs: `.scratch/full1.txt`, `.scratch/full2.txt`.

## Frames (looked at)
- `handoff/frames/d105_s37_deep/t002.6s.png`: a stage-4 worm in a dug pocket in the deep rock. The glow
  ring of blue cave mushrooms round it, the rail line of spikes leading off to its right, cart wheels
  rolled in, spring bubbles risen from below; a gem beetle (purple, the stage-4 threat) beside it,
  crystal crabs (orange), cave crickets and cave fish about, coal, ammonites and a miner lamp, and the
  fossil hall to the right. `t001.4s.png` is the same a second earlier, the bubbles and wheels still bunched by the head.
- Driver: `.scratch/s37_shot.tscn -- --mode=deep|core` (throwaway profile under `.scratch/`).
