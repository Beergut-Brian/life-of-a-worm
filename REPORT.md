# REPORT: worm-gap-close-36 (branch `feature/worm-gap-close-36`)

Three player-visible fixes, each pinned by headless tests. Rows D-13, K-14, C-08 and K-11 stay **built**; each has a
"Moved on (worm-gap-close-36)" note with its proof. Kid-check N2 is closed (`docs/kid-check.md`). There is one Gary's
pick, in GAME.md "Decisions made without Kaden".

## Sync
There are no unmerged `origin/feature/worm-*` or `origin/fix/*` branches; only the held art branches (`art-rings-1`,
`art-worms-1`) are unmerged. All partial and missing rows on dev are still blocked: art, sound, voice, D105 pacing, the
GTX 1060 runs, perf lanes W-09 / W-23, or Kaden's picks. None changed status. An audit agent checked the built rows'
classes, methods, signals and input paths in burrow, rings, creatures, pets, traits, gameplay, swap_shop and world for
live wiring and silent inputs, and found no new gap. The three gaps below came from kid-check N2 and from looking at
real frames of the pause path.

## What changed
1. **The stick lets go of the trait wall (kid-check N2, D-13 / K-14). Gary's pick.** Sleep opens the wall by itself
   when a trait is waiting, and until now the stick then did nothing until B or Y. Now a firm push up or down on the
   stick or d-pad (at least 0.6, more up/down than sideways), held 0.25 s (`BurrowWall.LEAVE_HOLD`), shuts the wall
   with `wall_close` and wakes the worm, which moves off on the next frame. Left / right still picks a picture; a tap
   or a soft nudge does not shut it. If the player never chose, leaving by stick still auto-equips the waiting trait
   into a free slot. File: `scripts/burrow/burrow_wall.gd`. Tests: `tests/test_wall_lets_go.gd` (4).
2. **Nothing in play draws over the pause menu (C-08).** A real frame showed the trait wall (CanvasLayer 50) and the
   planet HUD glyph strip (20) on top of the PAUSED menu: `main.gd` only hides layers under `PROCESS_MODE_ALWAYS`
   nodes. The new `PauseCover` (`scripts/ui/pause_cover.gd`, a child of `UI` in `scenes/main.tscn`) hides every
   visible arena CanvasLayer above the menu's layer while Game is PAUSED. On resume it shows exactly those layers again.
   The sky layers (-10 / -9) stay. It covers the space and chomp overlays too. Tests: `tests/test_pause_cover.gd`
   (4 pause cases, including over the tackle box and Main menu from pause).
3. **The dock's tin choices no longer hang over play (K-11).** Found in the same frame. `TinFresh` drew
   "[a] Continue / [y] New world" under a played tin, then stopped redrawing once the dock closed. The last drawing
   stayed on screen over the planet for the whole session, and over the pause menu. It now redraws once when the dock
   goes. File: `scripts/planet/tin_fresh.gd`. Test:
   `tests/test_pause_cover.gd::test_the_tin_choices_are_wiped_when_the_planet_opens`.

I kept `main.gd`, `dock.gd`, `worm.gd`, `planet_level.gd` and `planet_chomp.gd` untouched. Local unmerged branches
edit them (`feature/worm-jar-2`, `feature/stages-1`, `feature/worm-gap-close-2` / `-4`, `feature/art-worms-1`).

## Moved row IDs
D-13, K-14, C-08, K-11 (built → built, each with a new proof note), plus kid-check N2 (note → fixed).

## Skipped
- Kid-check N6 dock picture of a damaged tin: `scripts/planet/dock.gd` is changed on local `feature/worm-jar-2`.
- Kid-check N7 (a jar failure says yes): `scripts/chomp/planet_chomp.gd` is on local `feature/worm-jar-2`.
- Kid-check N8 / S-10 jar shelf: on local `feature/worm-jar-2`, and in `scripts/jars/` (gap-close-34's area).
- Kid-check N9 for space worms: `scripts/space/` is off-limits (gap-close-34).
- Swapping shelf trophies at the Mole (`Burrow.remove_trophy` has no live caller): GAME.md says "not swappable
  yet", so this is a design call for Kaden.
- W-09, W-23 (streaming and perf): these need their own lane. All A-*, U-*, P-25 rows (art, sound, voice): off-limits.
  S-01, S-19, W-24 (D105 pacing): held.

## Tests
Full suite on a clean import (`rm -rf .godot`, `--import`, then gdUnit `-a tests`): **874 test cases, 134 suites,
0 errors, 0 failures, 0 orphans.** That includes 9 new cases.

## Frames (real renders, `scripts/tools/shots.sh` with `.scratch/gc36_shot.tscn` and `.scratch/gc36_pause.tscn`)
- `handoff/frames/n2-wall-open-asleep.png`: asleep in a hollow, the wall opened by itself.
- `handoff/frames/n2-stick-up-shuts-wall-worm-moves.png`: stick up held, the wall is shut, Stone head is equipped
  (bubble), and the worm digs off upward.
- `handoff/frames/c08-pause-nothing-over-the-menu.png`: paused with the wall open. Only the menu is on top; the
  wall and the HUD strip are gone.
- `handoff/frames/k11-no-tin-choices-left-in-play.png`: in play after picking a played tin. No Continue / New
  world is left on screen.
