# REPORT: worm-start-fresh-1 (branch `feature/worm-start-fresh-1`)

K-11 (S8, Start fresh) moves from **partial** to **built**. Kaden's standing rule: with a save present the menu shows
Continue and New world. New asks with a held A, backs up the old save first (and never deletes it) and starts a
fresh world. Settings offers Restore old world. The pause menu's Main menu reaches all of this.

## Where Worm's "menu" is
Worm keeps three saves per profile, its bait tins (`<profile>_tin<N>.json`). The menu that loads a save is the
**bait-tin dock**: lobby, ready-up, then the dock, where you pick a tin. The rule's Continue / New world therefore sits
under the focused played tin on the dock. The lobby keeps all its own buttons (Play, Settings, Back to Open Jar), and
the dock keeps its own (left/right pick, A open, B back).

## What changed
- **Dock: Continue / New world** (`scripts/planet/tin_fresh.gd`). Under a played tin there are two bars: `[a] Continue`
  (the tin itself; A opens it as before) and below it `[y] New world`. Down lights New world and takes the pad from the
  dock. On New world, A or Y asks; up or B goes back to Continue; left/right goes to the next tin. Y on Continue also
  asks. Down on an empty tin plays a "no" beep (an empty tin is already new). `[x] Restore` still shows on a tin that
  has a backup.
- **Hold-A card.** The card uses the template's `HoldConfirm`: 1.5 s on a ring in the asker's colour, with a tick as it
  starts and while it fills. A tap drains it with a back tick, and B keeps the save. The copy is "START A NEW WORLD?"
  and "Tin N's planet is kept safe: Settings > Restore old world brings it back."
- **Backups** (`scripts/planet/bait_tins.gd`). A backup is now a copy, written to
  `user://saves/backups/<profile>_tin<N>--<UTC stamp>-<n>.json` and read back to check it is whole. Only then is the
  tin emptied. If the copy cannot be made (the folder cannot be created, the write fails, or the read-back differs),
  `start_fresh` returns "" and the tin is left byte for byte as it was; the card beeps no and nothing opens.
  Backups are never removed. Backups in the old layout (`<profile>_tin<N>.old<k>.json` beside the tin, from the
  partial K-11 on dev) are moved into the folder the first time the tin's backups are listed.
  - **Naming deviation:** the rule says `<profile>--<stamp>-<n>.json`. Worm has three saves per profile, so the tin is
    in the name (`p1_tin2--20261113T101500-000.json`) so that Restore knows which tin a backup belongs to. The backup's
    contents are the tin file's own JSON, unchanged.
- **Restore** copies a backup back into its tin. The planet in the tin is backed up first. If that backup fails,
  Restore refuses and changes nothing. Because the old backup is kept and the replaced planet becomes the newest
  backup, a second Restore undoes the first.
- **Settings > Restore old world** (`scenes/ui/settings_panel.gd`). The panel has a new fifth row, which shows only
  while `restore_check` returns true. A on that row emits `restore_asked(player)`. `TinFresh.hook_settings` wires it
  for the lobby's panel only: the row shows while any tin has a backup, and it asks with the same held-A card. It
  brings the newest backup of any tin back into its own tin (`BaitTins.restore_newest`), backing up first. The pause
  menu's panel never gets a `restore_check`, so restoring the open world mid-game is impossible. Settings is a
  template-structured file. The change is additive and does nothing in a game that never sets `restore_check`.
- **Pause, then Main menu** (unchanged, already on dev): `Game.to_lobby()` saves and closes the tin. The lobby, then
  the dock, then show Continue / New world again. Covered end to end by `::test_through_the_boot_scene_new_then_pause_back_to_restore`.
- **`Save.replace(dict)`** (`scripts/autoload/Save.gd`): replaces the open save whole and writes it now. Tests use
  `Save.replace({})` to start empty.

## Tests
- `tests/test_fresh_start.gd`: 20 cases (renamed from `test_tin_fresh.gd`, extended). Uses `SuiteSandbox`
  (its own profile `gdunit_fresh_start` and settings file), and every test starts with `Save.replace({})`. The
  failing-backup cases point `Save.dir` at a throwaway `user://test_fresh_start_broken` whose `backups` is a file, and
  remove it afterwards. Rule checks:
  - with a save present the menu shows Continue and New: `::test_with_a_save_present_the_menu_shows_continue_and_new_world`
  - New keeps a backup file and the old save still reads: `::test_new_keeps_a_backup_file_and_the_old_save_still_reads` (also checks the path pattern)
  - Restore brings back the newest and backs up the replaced world first: `::test_settings_restore_brings_the_newest_back_and_backs_up_the_world_first`, `::test_restore_brings_back_the_newest_and_keeps_the_current_one`
  - a failing backup stops New and leaves the save alone: `::test_a_backup_that_fails_stops_new_and_leaves_the_save_alone` (direct call and through the card), `::test_restore_refuses_when_the_world_it_replaces_cannot_be_backed_up`
- Clean import (`rm -rf .godot && godot --headless --import --path .`): exit 0, no script errors.
- Full suite (`--continue`): `Overall Summary: 865 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`, exit 0 (also in `handoff/test-output.txt`).
- After the runs, the real `user://saves/backups` was empty and no test folders were left behind.

## Frames (`handoff/frames/`, looked at each one)
These were taken with `scripts/tools/shots.sh` on a throwaway profile and folder (`user://startfresh_frames`, deleted
afterwards). The driver scene is `.scratch/fresh_frames.tscn`.
- `start_dock_continue_new.png`: "PICK A BAIT TIN". Tin 1 and Tin 2 are played and stand open with the green and red
  worms peeking out. Tin 3 has its lid on and reads "New planet". Under Tin 1 (focused, white frame), the dark
  `(A) Continue` bar sits above the wide yellow lit `(Y) New world` bar. The dock's own hint bar ("Pick / Open / Back")
  is at the bottom right. Nothing overlaps.
- `new_confirm_hold_a.png`: the dock is dimmed under a dark slanted card: "START A NEW WORLD?", "Tin 1's planet is kept
  safe: Settings > Restore old world brings it back.", and the A glyph in a ring half filled in P1 green. Below that:
  "Hold (A) Yes (B) Keep it".
- `settings_restore_old_world.png` (extra): the lobby with Settings open (Music 80, Sound 100, Screen shake ON, Solo
  playtest OFF), and the fifth bar "RESTORE OLD WORLD" focused (cream with the yellow chevrons). It sits just above the
  hint bar at the bottom and does not overlap it.
- The older frames from rules-audit-1 (`start_dock_continue_new_restore.png`, `restore_confirm_hold_a.png`) were not in
  this worktree's `handoff/` (handoff is excluded from git), so there was nothing to replace.

## Reference
`~/openjar/junk-yard-zap` was readable, but its `origin/dev` has no fresh-start files. The flow is on its branch
`origin/fix/jyz-rules-audit-1` (`scripts/levels/fresh_start.gd`, `scenes/ui/settings_panel.gd`). I read those to
follow the pattern: copy then wipe, a `backups/` folder with a UTC stamp, the newest backup restored after backing up,
and the Restore row only on the lobby's panel. I did not edit that repo, and I did not copy its names or copy
(Worm says world/planet and tin).

## PLAN-STATUS
- K-11: partial to **built**. The proof points at `tests/test_fresh_start.gd` and the three frames.
- The file had no totals line, so I added one under Sources: 264 rows: 198 built, 33 partial, 21 missing,
  5 superseded, 4 dropped, 3 later.

## Skipped / notes
- Nothing in the brief was skipped.
- The dock's own hint bar still says "A Open" while New world is lit (then A asks instead). `dock.gd` was left alone,
  because it is rewritten by the unmerged worm-jar-2 branch. The lit bar itself says `(Y) New world`.
- `tests/test_burrow_chambers.gd.uid` (made by the import) and the character face PNGs under `assets/characters/`
  are import output and not tracked; they are not in the commits.
- Not pushed (the producer ships).
