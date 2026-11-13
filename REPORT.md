# REPORT: worm-rules-audit-1 (Kaden's standing game-feel rules)

Branch `feature/worm-rules-audit-1`, based on `origin/dev` 2de7d78 (dev had not moved at the last
check). Not pushed.

## Audit table

| # | Rule | Before | Now | Where |
| --- | --- | --- | --- | --- |
| 1a | Start fresh: with a save present the menu shows Continue and New | **FAIL** | fixed | Before: `scripts/planet/dock.gd:54-58` had only A (open) and B (back). A played tin could never be emptied, so a family with three full tins could not start a new planet. Now `scripts/planet/tin_fresh.gd` shows `A Continue  Y New` under a played tin |
| 1b | New asks first with a hold-A confirm | **FAIL** | fixed | `tin_fresh.gd` card: "START A NEW PLANET?". You hold A for 1.5 s while a ring fills, with a tick beep every 0.25 s. B, or letting go, keeps the planet |
| 1c | New keeps the old save as a backup and never deletes it | **FAIL** (there was no New) | fixed | `BaitTins.start_fresh` (`scripts/planet/bait_tins.gd`) moves the tin's file to `<profile>_tin<N>.old<k>.json`. `k` counts up and is never written over |
| 1d | Settings offers Restore | **FAIL** | Worm side fixed; Settings part is a template gap | On the dock, `X Restore` appears on a tin that has a backup (same hold-A card). `BaitTins.restore` swaps the newest backup in, and the planet that was in the tin becomes a backup, so nothing is lost. The Settings menu itself is template-owned: see Template gaps |
| 1e | The pause menu reaches that menu | PASS | — | Pause → "Main menu" (`scenes/main.gd:39`) → lobby → ready-up → the dock. Test: `test_tin_fresh::test_through_the_boot_scene_new_then_pause_back_to_restore` |
| 1f | Checked headless with a save file present | PASS | — | A headless boot with a played tin in a throwaway profile printed 0 errors. The boot-scene gdUnit test above runs lobby → dock → held-A New → new planet → pause → Main menu → dock offers Restore |
| 2 | Solo: one pad or keyboard plays both; `--solo` or Select + Start 2 s; small icon; never on by default; a remembered setting does not restore at boot; tests use their own settings | PASS | — | `scripts/autoload/Players.gd:15-17` (2 s hold), `:43-44` (`--solo`), `:132-170` (`set_solo`, the keyboard is `VIRTUAL`), `solo_marker.gd` (icon). `settings_panel.gd:120` stores the setting, but nothing reads it at boot. Tests: `test_worm_session::test_saved_solo_never_restores_at_boot`, `test_lobby::test_saved_solo_stays_off_at_boot`, `test_greybox_planet::test_solo_is_never_restored_from_a_saved_true`. Every suite uses `SuiteSandbox` settings and picks paths |
| 3 | Pause: a big icon back to the launcher; quitting never needs a force-close | PASS | — | `scenes/ui/pause_menu.tscn:136-143` (128 px door `IconButton`); `Game.gd:31,36-37` (a window close quits); `Game.gd:104-108` (flush, then quit, with no await). Frame: `handoff/frames/pause_main_menu_and_door.png` |
| 4a | No forced movement, no auto-steering | PASS | — | Worm motion comes only from the stick or a burst (`worm.gd:462-487`). The autopilot runs only in the demo (`greybox_demo.gd:90-92`). The warp is a held B the player chooses. Knock-backs are short, decaying one-offs. The space drift never moves a worm (`space_drift.gd:9`) |
| 4b | No stick-only requirement | **FAIL** | fixed | `project.godot` `[input]` bound `p*_move_*` to stick axes and keys only, so on a pad the d-pad did nothing in play, the dock, pause, the tackle box or the trait wall (only the template lobby read it raw, `lobby.gd:193`). `project.godot` is off-limits, so `Players.add_dpad()` adds the d-pad buttons at boot. They follow the pad assignment and solo like the stick does |
| 4c | Buttons work everywhere | PASS once 4b was fixed | — | All menus and gameplay read actions (`Players.move_vector`, `menu_input.gd`), so keyboard and d-pad now both reach every screen |
| 5a | Every action beeps | **FAIL** | fixed | (1) X with nothing in reach was silent (`worm.gd:546-605` only sounds X when it picks something up). Now `scripts/gameplay/carry_miss.gd`, a child of `worm.tscn`, plays a low quiet `carry` cue and shows two little jaws clapping shut at the mouth. (2) The trait wall with no traits earned was silent on stick and A (`trait_wall.gd:36,39`). Now the wall shakes and bonks |
| 5b | Select alone | PASS (by design) | — | GAME.md:15 says "Select does nothing alone" (supersedes the old restart). kid-design allows "ignored" for extra buttons |
| 5c | Every effect shows its cause (curses, stolen tools, story beats: reveal, camera beat, "that's why" callback) | PASS / N/A | — | Worm has no curses or theft (`star_traits.gd:4` says "never a curse"; grep for steal, stole, curse, lose found none; the Mole trade is the player's own pick). Getting eaten has the creature on screen, the `eaten` cue, dizzy stars and the camera beat (`eaten_beat.gd`). Stage-ups, traits, the breakthrough and the chomp have camera beats and dock cutscenes (Y-16 / P-14) |
| 6 | Gameplay text-free; menus may carry text and glyphs | PASS | — | No Label, RichTextLabel or `draw_string` in levels, players, HUD, bubbles or space. Story subtitles are off by default (`story.gd:50`). The chomp confirm (`confirm_picture.gd:61,66`) draws only the A and B button glyphs on coloured buttons. The new dock text is menu text |

## What changed (Worm-owned code only)
- `scripts/planet/bait_tins.gd`: `backups`, `has_backup`, `start_fresh`, `restore`. Backups are numbered and never overwritten.
- `scripts/planet/tin_fresh.gd` (new) plus a `TinFresh` node in `scenes/main.tscn`: Continue, New and Restore on the dock, each with a hold-A card. It hooks the dock from beside it, so `dock.gd` and `main.gd` are untouched; the local `feature/worm-jar-2` branch is rewriting both.
- `scripts/autoload/Players.gd`: `add_dpad()` at boot.
- `scripts/gameplay/carry_miss.gd` (new) plus a `CarryMiss` node in `scenes/players/worm.tscn`.
- `scripts/worm/trait_wall.gd`: the empty wall bonks and shakes.
- Tests: `tests/test_tin_fresh.gd` (12), `tests/test_dpad_moves.gd` (5), `tests/test_carry_miss.gd` (4).

## PLAN-STATUS rows moved
New source S8 (this brief). New rows: K-11 (partial), K-12 (built), K-13 (built), K-14 (built),
K-15 (built), K-16 (built). P-12's proof and notes are updated with the d-pad.

## Tests
- Clean import (`rm -rf .godot`, then `--import`): 0 script errors.
- Full gdUnit4 run (`-a tests --continue`), twice after the clean import:
  `Overall Summary: 857 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |` on both runs.
  An earlier run before the last test was added: 856 cases, 0 failures.
- Headless boot (`--quit-after 600`, throwaway profile, once with a played tin present): exit 0, 0 errors.
- No test or scripted run wrote the real settings, picks or tins. Suites use `SuiteSandbox`. Frames and boots used throwaway profiles (`rulesaudit_*`), and those files were deleted afterwards.

## Frames (`handoff/frames/`)
- `start_dock_continue_new.png`: the start screen's tin select with a played tin, `A Continue  Y New`.
- `start_dock_continue_new_restore.png`: a tin with a backup also shows `X Restore`.
- `new_confirm_hold_a.png`: the New card mid-hold, ring half full.
- `restore_confirm_hold_a.png`: the Restore card.
- `pause_main_menu_and_door.png`: pause with "Main menu" (back to the start screen) and the door icon.

## Template gaps (not edited; for a template lane)
- **Settings has no Restore row** (`scenes/ui/settings_panel.gd`, `Row { MUSIC, SOUND, SHAKE, SOLO }`). Worm offers Restore on the dock instead. A template Restore would need a hook for each game's save model; Worm's is `BaitTins.restore(i)`.
- **The template start screen has no Continue / New** (`scenes/ui/lobby.gd`). Worm covers it on its own tin dock; other games built on the template have no start-fresh path.
- **The template input map binds `move_*` to the stick and keys, not the d-pad** (`project.godot`). Only the lobby reads the d-pad itself (`lobby.gd:193`). Worm adds it at runtime in `Players.add_dpad()`. The template should bind it in `project.godot`, and the raw read in the lobby then becomes redundant (harmless: the same press gives the same direction).

## Still open / Skipped
- K-11 stays `partial` until the template Settings gets a Restore row.
- No frame of the CarryMiss jaws (a 14 px clap at the mouth). The tests cover the cue, the visual state and the cap on mashing. Item 5 frames were not asked for.
- The three commits were tested together as the final tree (two clean full runs). Each earlier commit holds only part of the final tree.
- The headless `-s` script attempt to drive main.tscn could not resolve class names in `-s` mode (a known gotcha). The same path runs as a gdUnit test instead.
