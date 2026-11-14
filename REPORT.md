# REPORT: worm-gap-close-41 (branch `feature/worm-gap-close-41`)

Gap-close lane, sixth fill. Code logic only: no image, audio, data or scene-art files, and no
pacing or tuning numbers.

## Moved rows

| Row | From | To | Proof |
| --- | --- | --- | --- |
| L-20 | (new, audit) | **built** | `tests/test_outgrown_bird_boot.gd` (6 bird cases); frames `handoff/frames/gc41-l20-bird-hovers.png`, `gc41-l20-bird-dives.png`, `gc41-l20-bird-eaten-grin.png` |
| L-21 | (new, audit) | **built** | `tests/test_outgrown_bird_boot.gd` (4 boot cases); frame `handoff/frames/gc41-l21-boot-eaten-grin.png` |
| L-17 | built | built (moved on) | the note says the data-only test hid that three creatures were never food in play; bird and boot fixed, lawnmower left (contract) |
| S-10 | partial | partial (sync note only) | re-check of every partial/missing row; the shelf is still only on the local `feature/worm-jar-2` |

Totals: 269 rows: 205 built, 31 partial, 21 missing, 5 superseded, 4 dropped, 3 later.

## What changed

1. **Sync (first commit, `plan: sync content rows for gap-close-41`).** Every partial and
   missing row on dev is still blocked:
   - art, audio or voice (the A, U and P-25 rows);
   - D105 pacing (S-01, S-19, W-24);
   - the GTX 1060 runs (W-09, W-23, R-01);
   - folders this lane may not touch: roster (P-18), store (A-15, A-16, P-24), jars (S-10), space
     (S-18) and story (Y-*);
   - milestones (R-*).

   No row moves on sync. There is one sync note, on S-10.
2. **Audit: L-17 was true only in data.** GAME.md says "every creature except a Jarling becomes
   food eventually". `test_creatures_size.gd::test_every_creature_except_a_jarling_becomes_food_eventually`
   checks only `CreatureSense.is_food` on the `.tres` files. In play, three creatures left the
   `food` group in `_ready` and were never available, so no worm could ever eat them: the bird, the
   gardener's boot and the lawnmower. Found by checking 18 GAME.md promises against live wiring.
   The other 15 are wired. Float and the bug telegraph are partial, but those are recorded design
   reads, not gaps.
3. **L-20, the bird is food once outgrown (Gary's pick, GAME.md decisions).**
   - `scripts/creatures/bird.gd`: the bird stays in the food group. It is available only while
     the worm nearest it has outgrown it, so a small worm under its shadow never bonks off it.
     Tested: the peck still lands the one eaten way.
   - It notes the worms it looms over in `Outgrown`, so the first one eaten plays
     `now_i_eat_you` and the grin.
   - When outgrown, its shadow is drawn at half size (K-01).
   - A carried bird rides in the mouth. When let go, the worm's 0.8 s drop block (`DROP_BLOCK`) applies and it flies
     off.
   - `scripts/rings/rings_director.gd`: `send_bird` still prefers a smaller worm, then a beetle
     near the top. Next comes the new `bird_meal_target`, a worm near the top that has outgrown
     birds: the bird swoops at it, cowering, and dives into its mouth if it stays put. An eaten
     bird (`Bird.eaten`, not one that flew off) comes off the topsoil bird counter, so eating
     birds lets the beetles boom (L-01).
4. **L-21, the boot is food once outgrown (Gary's pick).**
   - `scripts/creatures/boot_shadow.gd`: the boot is food only from its stomp while the sole is
     down, and only to a worm that has outgrown it (stage 5 and up).
   - An outgrown boot stays down for 1.2 s (`OUTGROWN_SHOW`) instead of 0.5 s.
   - Before the stomp it is only a shadow, and nothing can bite it.
   - The first one eaten plays the sting and the grin.
   - A carried boot waits in the mouth and does not fade mid-carry.
   - The gardener is still never seen.

## Seen in real frames

Frames were staged by `.scratch/gc41_shot.tscn -- --mode=bird|boot`: a real `planet.tscn`, a
stage-4 or stage-5 worm just under the grass, and a bird or boot sent by the level's own
RingsDirector.

- **Bird.** It hovers over the grass and dives at the worm with a small target ring. It was
  swallowed at 2.7 s, and the grin close-up shows it as a sweating blue bird.
- **Boot.** It was swallowed one frame after its stomp, and the grin shows it.

Two things for Art and the Reviewer:
- At stage-5 zoom the outgrown boot, drawn at 0.25x (K-01, unchanged), is almost invisible before
  the bite.
- In the grin close-up the boot is a plain grey ball (GrinCloseup's generic prey look).

## Skipped

Skipped because sibling lanes own the rows or files:
- **gap-close-40** (running, `~/openjar/work/life-of-a-worm--feature_worm-gap-close-40`):
  - rows T-01, T-05, W-10, W-35 and P-21;
  - files `scripts/tackle/*`, `scripts/ui/book*.gd`, `scenes/ui/book.tscn`,
    `scripts/world/surface_prop.gd`, `scripts/world/world_destruct.gd` and `docs/contracts.md`.
  - None of these were touched here.
- **gap-close-39** (shipping, `feature/worm-gap-close-39`, not on `origin/dev` yet):
  - rows B-09 and X-10;
  - files `scripts/swap_shop/swap_shop.gd` and `data/trophies/*`.
- **Unmerged local branches** (`feature/worm-jar-2`, `stages-1`, `ambience-1`, `big-planet-1`,
  `gap-close-2`, `-4`, `-6`, `-8`, `kid-checks-1`, `star-traits-1`, and the art branches): none
  of them touch `bird.gd`, `boot_shadow.gd`, `rings_director.gd` or the creature tests, except
  `art-rings-1`, which only adds `bird.png`.

Not built:
- **The lawnmower stays never food.** `docs/contracts.md` (Lawnmower, worm-lawnmower-1) says
  "Never food". CLAUDE.md requires a contract change in its own PR first, and that is Kaden's or
  Gary's call. The L-17 note says so.
- **The sky flocks** stay never food (W-07, gap-close-11's choice: they startle and fly off).

Expect merge conflicts:
- **GAME.md**: gap-close-40 also adds decision lines at the end of the same list (keep both).
- **PLAN-STATUS.md**: the Totals line.

## Tests

- New: `tests/test_outgrown_bird_boot.gd`, 10 cases.
- Full suite on a clean import (`rm -rf .godot`, `--import`, then the CLAUDE.md command):
  **904 cases, 0 failures, 0 errors** (138 suites).
- An earlier run with `--fixed-fps 30` failed 8 cases in `test_music_layers.gd` and
  `test_story_dock_2.gd`. Those are timing suites. Both pass with the plain command (16/16), and
  this change touches neither.

## Commits

- `e72216e` plan: sync content rows for gap-close-41 (none left to move)
- `84768be` gameplay: outgrown bird and boot become food (L-20, L-21)
- (this one) report: gap-close-41
