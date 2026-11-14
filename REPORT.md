# REPORT: worm-jar-reconcile-1 (branch `feature/worm-jar-reconcile-1`)

Reconcile lane for S-10 (planet in a jar on Old Reel's shelf). The shelf was built on the local,
unmerged `feature/worm-jar-2` (`1798395`), which no longer merged into dev. I ported it onto current
dev (`e580551`) by hand. `feature/worm-jar-2` was read with `git diff 9be08bb 1798395` only; it was
not checked out, edited or moved. Not pushed.

## Moved rows

| Row | From | To | Proof |
| --- | --- | --- | --- |
| S-10 | partial | **built** | `tests/test_jars_shelf.gd` (7 cases), `tests/test_dock_tins.gd::test_the_shelf_spot_sits_right_of_the_tins_and_tin_choices_skip_it`; frames `handoff/frames/jar-shelf-on-dock.png`, `handoff/frames/jar-shelf-open.png` |

I updated the Totals line in the same commit, counting from the status column: **271 rows: 208 built,
30 partial, 21 missing, 5 superseded, 4 dropped, 3 later.** (The old line still had gap-close-39's
269 / 205; gap-close-40 had already predicted 271 / 207 after its own merge.)

## What was ported (jar-2's own changes, `9be08bb..1798395`)

Dev had not touched these since jar-2's base, so jar-2's diff applies to dev's version unchanged:
- `scripts/jars/jar_shelf.gd` (`JarShelf`, new): Old Reel's shelf. Each player walks a worm along
  the planks (the stick is the only thing that moves it, no snapping). The jar in reach lifts and
  shows A. A opens it and B goes back to the dock.
- `scripts/jars/jars.gd`: `open_id()`, `shelf()`, `open_entry()`, `recover()`, `RETURN_KEY`.
- `scripts/jars/jar_open_view.gd`: `show_close()` / `closed` (the planet goes back into its jar).
- `project.godot`: the `Jars` autoload. `planet_chomp.tscn` drops its own `Jars` child.
  `chomp_director.gd` and `planet_chomp.gd` now prefer a scratch store child named `Jars`, and fall
  back to the autoload.
- Tests: `tests/test_jars_shelf.gd` (new), plus jar-2's edits to `test_chomp_sequence.gd` and
  `test_jars_slots.gd`.

Files that both jar-2 and dev changed, merged by hand:
- `scenes/main.gd`: jar-2's shelf and jar fields, `open_jar` / `leave_jar`, `Jars.recover()` at
  boot (not under `--demo`) and `--preview-shelf`. Dev's `open_tin` (OpeningHook, Y-01) and its
  pause hold are kept as they are. The two sides did not touch the same lines.
- `scripts/planet/dock.gd`: **dev's tin pictures are kept as they are** (P-05 / C-22: the open tin
  with peeking worms, the stage pips, the twinkle on a new tin). I added jar-2's shelf to them:
  `signal shelf_requested`, `const SHELF := BaitTins.COUNT`, the stick wraps over `COUNT + 1`,
  A on the shelf emits `shelf_requested`, `_jar_slots` is read from `/root/Jars` in `refresh()`,
  and `_draw_shelf_spot` draws the shelf right of the tins. Both sides' doc comments are kept.
- `docs/contracts.md`: dev's new Mayhem section and jar-2's "Jar follow-ups" section are both kept.
  I added `Dock.SHELF` and `Dock.tin_x` to the jar section.
- `PLAN-STATUS.md`: dev's S-10 row is kept, with the move and a reconcile note added.

## Kept from dev, and the shelf adjusted (brief point 3)

- **TinFresh vs the shelf spot.** Dev's `TinFresh` (start-fresh-1, K-11) draws Continue / New
  world / Restore under the focused tin at a hard-coded `x = 0.25 + 0.25 * i`. It reads
  `dock.focus` as a tin index. jar-2 moves the tins to `0.18 + 0.2 * i` to make room for the shelf,
  so the choices would have drawn under the wrong tin. Also, focus 3 (the shelf) would have been
  read as a fourth tin, `tin4`. I kept dev's rule (choices sit under the focused played tin) and
  changed how the shelf fits it:
  - `Dock.tin_x(i, width)` is now the one place that sets a tin's x (and the shelf's, 0.82).
  - `TinFresh._draw_choices` uses `Dock.tin_x`.
  - `TinFresh.tin()` returns -1 while the shelf spot is lit, so the shelf never offers New world
    or Restore.

  The new test `test_dock_tins.gd::test_the_shelf_spot_sits_right_of_the_tins_and_tin_choices_skip_it`
  pins this.
- Every other dev rule passed with the shelf in place: `test_dock_tins`, `test_fresh_start`,
  `test_bait_tin_rail`, `test_next_tin_trip`, `test_pause_cover`, `test_lobby`. Nothing else
  needed adjusting.
- The shelf, the jars and the shelf worms are still jar-2's code-drawn placeholders. I added no
  image or audio files. jar-2's tests have no test doubles, so they needed no `Fake` prefixes.

## Tests

- Clean import (`rm -rf .godot`, `--import`), then the full suite.
  - **Run 2: 923 test cases, 0 failures, 0 errors.**
  - **Run 3: 923 test cases, 0 failures, 0 errors.**
- Run 1 had 11 failures in 3 suites that share `user://` bait-tin files:
  - `test_greybox_planet::test_each_tin_round_trips_on_its_own`
  - `test_chomp_planet::test_the_jar_is_the_real_tin_and_plays_again_with_stage6_off`
  - `test_bait_tin_rail::test_tin_1_keeps_its_own_planet`

  Run 1 counted 916 cases only because gdUnit stops a suite at its first failure. The same three
  suites passed alone (21/21) right after, and run 2 passed in full with no code change in
  between. This is the known shared-`user://` tin flake: other lanes on this box use the same
  project user dir.
- Shelf pieces on dev:
  - `test_jars_shelf` 7/7
  - `test_jars_slots` 6/6
  - `test_chomp_sequence` 4/4
  - `test_dock_tins` 5/5 (1 new)

## Frames

- `handoff/frames/jar-shelf-on-dock.png`: the tin dock with dev's tin pictures. Tins 1 and 3 are
  played and open with worms peeking out and pips; tin 2 is new, with the lid on and a twinkle.
  The shelf spot is lit right of the tins, with jars for tins 1 and 3 and an empty place for tin 2.
- `handoff/frames/jar-shelf-open.png`: the shelf itself. It shows two jarred planets with their tin
  lids, the empty dashed place, and P1's green worm on the planks.
- Driver: `.scratch/jar_reconcile_shot.tscn -- --mode=dock|shelf`. It uses a throwaway profile
  and jar dir, run through `godot-render ... -- --shots=1.5`.

## Not done / notes

- `tests/test_burrow_chambers.gd.uid` and `assets/characters/**` PNGs show as untracked after a
  clean import. They are by-products and not committed.
