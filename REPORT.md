# REPORT: worm-gap-close-43 (gap-close lane, eighth fill)

Branch `feature/worm-gap-close-43`, based on origin/dev `774c528` (`git merge origin/dev` at the
start: already up to date; origin/dev had not moved at the end). Not pushed.

## What changed
- **Sync:** no row could move, so there is no sync commit. Every partial or missing row is still
  blocked on the reason its note gives: art (A-*, K-08's ground darkness, P-05), audio, music or
  voice (U-*, P-25, Y-10), pacing (S-01, S-19, W-24, S-18's 20 to 40 min meal), a GTX 1060 run
  (W-09, R-01, W-23), roster (P-18), story bibles (Y-13, Y-14, P-21, R-05) or a milestone tag
  (R-06 to R-10). The last sync (d105-content-s12-1) was this morning, and its Totals line still
  holds: no status changed.
- **W-23, streaming budget (`863c492`):** PolarWorld now streams a `PolarShape`
  (`scripts/world/polar_shape.gd`), a game-side `DiskShape` subclass. The shared addon is not
  touched. The chunk_radius-2 neighbourhood keeps the full reach of 2 sectors each side on the
  worm's own ring and the rings next to it. The outer edge row reaches 1 sector each side. The
  inner edge row, whose sectors are fewer and wider, keeps only the sectors over the worm's own
  chunk. Results:
  - Worst case per chunk ring, core to crust: 17, 21, 23, 25, 25, 23, 24, 25, 19, 13 chunks
    (was 19, 23, 28, 31, 31, 29, 30, 31, 23, 17).
  - Worst case in tiles: 25,320 (was 31,385).
  - The first chunk ring round the worm is always whole, for every chunk on the disk.
  - The stage 1 and 2 camera views (zoom 3x and 2x) never show an unstreamed chunk, checked at
    480 worm positions.
  - At the stage 3 to 6 zooms the trimmed chunks are screen corners about 60 tiles from the worm.
    FarGround's dimmed ring colour fills them, as it already did for the old square's corners.
  - W-23 stays **partial** for the GTX 1060 60 fps check only.
  - Tests: `tests/test_stream_budget.gd` caps lowered to 25 chunks / 26,000 tiles, plus 3 new
    tests: `::test_the_worst_neighbourhood_at_each_depth_is_locked_and_inside_the_brief`,
    `::test_the_first_chunk_ring_round_the_worm_is_always_whole`,
    `::test_stage_one_and_two_views_never_show_an_unstreamed_chunk`.
  - `tests/test_world_polar.gd::test_two_eaters_two_neighbourhoods` now expects the trimmed
    20 to 25 chunks instead of the full 25-plus square.
- **Kid-check N7 (`0bb8c7c`):** when the stage-6 chomp hold finished, the game played the "yes"
  sound before it tried to write the jar. If the write failed, nothing else happened.
  `PlanetChomp._on_confirmed` now writes the jar first and plays `confirm_yes` only on success. On
  failure, `_refuse()` plays the existing `bonk` cue, shakes the shot, wobbles the picture, shuts
  the worm's mouth, empties the ring so the kid can hold again, and emits `jar_refused`. Nothing
  is eaten. Test:
  `tests/test_chomp_sequence.gd::test_a_jar_that_cannot_be_written_bonks_instead_of_saying_yes`.
  Noted on the K-15 row (still built) and in `docs/kid-check.md`.
- **Kid-check N8 (`6c00064`, docs only):** marked fixed. The jar shelf (S-10, PR #95) re-opens a
  chomped planet (`tests/test_jars_shelf.gd`). System 18 in the kid-check table is now "yes".

## Moved row IDs
- None changed status. Notes added to W-23 (the 25-chunk part is built; stays partial for the
  GTX 1060 run) and K-15 (N7 fix; stays built).

## Skipped
- Nothing was skipped because of a sibling. `feature/worm-d105-content-s37-1` (running) changes
  only `data/rings/*`, `data/trophies/*`, `scripts/rings/*`, `scenes/levels/space_stage.tscn`,
  new creature/food data and its own tests. None of my files are in that list.
- `origin/feature/art-rings-1` (art, held) also edits `scripts/world/polar_world.gd`
  `setup_planet`, close to my two one-line edits (the `PolarShape.new` line and the
  `chunk_radius` comment). That branch's merge may need a small hand-resolve: keep
  `PolarShape.new`.
- Kid-check N6's second half (the dock should draw a damaged tin): not done. It is a dock picture,
  so it needs art direction, and Kaden would rarely see it.
- No other partial non-art row qualified (see Sync).

## Tests
- Clean import (`rm -rf .godot`, `--import`), then the full suite twice.
  - Run 1: 951 cases, 1 failure: `test_greybox_planet::test_hold_b_warps_home`. This is the
    known flake when another lane's gdUnit run shares `user://`; the sibling's suite was running
    at the same time.
  - Run 2: **959 cases, 0 failures**.
  - `tests/test_greybox_planet.gd` alone: 3 of 3 runs green.
- The clean import leaves untracked `assets/characters/*_face.png` etc. and
  `tests/test_burrow_chambers.gd.uid`. They are not from this lane and are not committed.

## Frames (real, llvmpipe; in `.scratch/`, not committed, because this brief adds no image files)
- W-23 before/after, the same staged spot, with and without the trim:
  - `.scratch/f_dirt_s4_trim/t006.0s.png` vs `.scratch/f_dirt_s4_plain/t006.0s.png`: stage 4 in
    the dirt. The ground looks the same.
  - `.scratch/f_deep_rock_s4_trim/t006.0s.png` vs `.scratch/f_deep_rock_s4_plain/t006.0s.png`:
    stage 4 in deep rock. The trimmed frame shows a stepped slate patch (FarGround) in the far
    top-left corner where the plain frame shows dirt tiles. Nothing changes near the worm.
  - `.scratch/f_topsoil_s2_trim/t006.0s.png`: stage 2, whole screen streamed.
  - Driver: `.scratch/w23_shot.tscn -- --ring=<id> --stage=N [--plain]`.
- N7: `.scratch/f_n7/t001.6s.png` (the ring filling) and `.scratch/f_n7/t002.6s.png` (just after
  the refusal: picture tipped, ring empty, mouth shut). Driver: `.scratch/n7_shot.tscn`.

## Still outstanding
- W-23 / W-09 / R-01: the GTX 1060 60 fps run. Use the F3 overlay on `scenes/levels/polar_stress.tscn`
  and on a stage 4 to 6 play planet.
