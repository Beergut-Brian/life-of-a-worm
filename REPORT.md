# REPORT: worm-gap-close-39 (branch `feature/worm-gap-close-39`)

Gap-close lane, fourth fill. World content only: code logic and data, no image or audio files.
Based on `origin/dev` 54f09bf (dev did not move during the run). Not pushed.

## Commits

1. `b7b478a` plan: sync content rows for gap-close-39 (all still blocked)
2. `dd04d2b` content: every find has a trophy family; Mole's seeds match the swap
3. `3ebc498` tests: sweet guard skips trophy families (they hand nothing out)
4. this report

## Sync (first commit)

Every partial or missing row about world content (food, creatures, hazards, book, swap shop,
secrets, castings) is either built or blocked. None could move to built. Sync notes added:

- **S-18** partial: the 20 to 40 min space meal is pacing (D105 open); real art held.
- **A-04** partial: no day/night clock; needs a night look first (Art, held).
- **A-13** partial: placeholder code faces in game; art held for direction.
- **K-08** partial: only ground luminance is left (Lantern textures, Art, held).

## Built (new rows, Gary's picks, written into GAME.md "Decisions made without Kaden")

Since no buildable content rows were left, I checked GAME.md's content promises against the data and found two gaps a player would notice:

- **B-09 (new, built): every find has a trophy family.** Only 8 of the 35 foods counted as
  trophies. A fossil, amber, honeydew, jam or anything from the surface or sky carried home sat on
  the shelf and did nothing. Now all 35 are each in exactly one family (stones, shinies, snacks), so
  every kept thing tags its shelf plank and adds its family's charm and bonus. The per-trophy
  bonuses and the cap of 3 are unchanged. Data only (`data/trophies/*.tres`).
  Proof: `tests/test_trophy_families_all.gd` (4 cases, incl. an in-level
  `::test_new_finds_carried_home_give_their_family_bonus`). The guard turns red if a new food has no family.
- **X-10 (new, built): the Mole's seeds match what you gave.** `SwapShop.seed_for` reads
  `data/foods`: a stone thing brings two pebbles (rock garden), a bug thing two bug eggs (bug
  garden). Anything else brings plain seeds, and so does a seed itself, so a swap never copies a
  seed. The crystal seed is the stage-5 core crystal, too big, so crystal things bring plain seeds.
  His offer bubble now shows the seed he will give. Loose gift seeds save their id; old tins load
  them as plain seeds.
  **Bug found in the frame and fixed:** the two seeds used to pop out toward the worm, and a worm
  waiting at the counter swallowed one the same frame (traced: `loose` went 2 → 1 in one frame), so a
  kid saw one seed for a swap. They now pop out behind the Mole.
  Proof: `tests/test_swap_seeds.gd` (6 cases). `::test_a_worm_waiting_at_the_counter_does_not_swallow_a_gift`
  fails on the old placement and passes on the new one (checked both).
- B-05 and X-07 got "Moved on" notes pointing at B-09 / X-10.
- `tests/test_sweet_tooth.gd` (gap-close-38's "jam is the only sweet thing" guard) now skips
  `data/trophies/`: it counted any file naming `jam_drop` as a source, and a trophy family hands
  nothing out.

## Moved row IDs

- Added built: **B-09**, **X-10**
- Notes only: **B-05**, **X-07** (moved on), **S-18**, **A-04**, **A-13**, **K-08** (sync, unchanged)
- Totals line recounted from the status column: 269 rows: 205 built, 31 partial, 21 missing,
  5 superseded, 4 dropped, 3 later.

## Skipped

- No sibling lane was open: `git branch -r --no-merged origin/dev` shows only
  `origin/feature/art-rings-1` and `origin/feature/art-worms-1` (art, held, ignored as briefed).
  gap-close-36/37/38 are merged. I edited no file those art branches change.
- Every other partial or missing row is blocked on art (A-*, P-19/20, A-12), audio and voice (U-*, P-25),
  Kaden's picks or a design call (S-18 meal / D105, S-01/S-19/W-24 pacing), GTX 1060 runs
  (W-09, W-23, R-01), unvendored characters (P-18, A-19, A-20, Y-13/14) or milestones (R-06..R-10).

## Tests

Full suite on a clean import (`rm -rf .godot && godot --headless --import`):
**904 test cases, 0 failures** (runs 3 and 5). Run 4 had one failure in
`test_greybox_planet::test_hold_b_warps_home`: it took 15 s instead of 2 s (the box stalled; a known
load flake). It passed 3 of 3 times alone and in the next full run. Logs: `.scratch/run3.txt`, `run4.txt`, `run5.txt`.

## Frames (looked at)

- `handoff/frames/x10_mole_offer_pebbles.png` (+ `_offer_crop2x`): carrying a boulder, his bubble reads
  boulder ⇄ pebble, pebble. `x10_mole_offer_pebbles_after*.png`: after the swap.
- `handoff/frames/x10_mole_offer_bug_eggs.png` (+ `_offer_crop2x`): honeydew ⇄ bug egg, bug egg.
  `x10_mole_offer_bug_eggs_after_crop2x.png`: happy Mole, both bug eggs lying behind him.
- Staged by `.scratch/gc39_mole.tscn -- --give=<food id>` via `scripts/tools/shots.sh`.
- B-09 is a data change with no new picture (the shelf tag and charm drawing already existed).
- Seen in passing, not mine: the A glyph shows twice over the Mole (the shop's own and the head
  ReadyGlyph), and the boulder and pebble are both grey, so that offer reads less clearly than the bug-egg one.
