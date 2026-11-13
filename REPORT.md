# Determinism lane report (feature/worm-camera-determinism-1)

Only `tests/test_worm_session.gd` changed. No `scripts/` or `scenes/` change: no new hook was needed.
No PLAN-STATUS row belongs to this lane (C-03, C-14 and P-07 name the test, and its name is unchanged).

## What changed

Two helpers at `tests/test_worm_session.gd` (`_until`, `_camera_settled`, beside `_frames`):

- `_until(done: Callable, limit: int) -> int` awaits physics frames until `done` is true and stops after
  `limit` frames. It returns the frame count, or -1 on a timeout. Every call asserts the result is not -1,
  so a timeout fails as a timeout and not as a confusing position assert later on.
- `_camera_settled(cam)` is true when the camera has caught up with its targets: centred within 1 px,
  `zoom_index == fit_index()`, and rotation within 0.01 rad of the targets' mean up. These are the three
  things `PolarCamera.step` eases each process frame.

`test_camera_fits_both_then_follows_one_and_arrows_the_far_worm`:

| Step | Before | After |
| --- | --- | --- |
| Both worms framed | fixed `_frames(3)`, then split off and 2 targets | wait until `targets.size() == 2` (bound 30), then split off, 2 targets and `FarCamera.fits(cam, [a, b])` true |
| Far split | fixed `_frames(90)`, then assert | wait until `far_camera.split` (bound 30), then until `_camera_settled` (bound 300); then assert split on **and** `FarCamera.fits(cam, [a, b])` false, using the worms' current positions |
| Tie keeps P1 | `targets == [a]` | unchanged |
| Arrow on the far worm | `not cam.sees(b, 30)` | unchanged, with a comment that this is exactly PlanetHud's own arrow condition (`_draw_hud`: `not cam.sees(w.cam_position(), 30.0)`) |
| Warp lands by the partner | `distance(b, a) < 40.0` | `b.cam_position() ≈ landing` within 0.01 px. `landing = a + a.normalized().orthogonal() * 16` is the formula in `PlanetLevel._on_warp_requested`, computed from where `a` stands at the warp |
| Partner does not move | `distance(a, a_before_warp) < 1.0` | `a.cam_position() == a_before_warp` (exact: the warp is synchronous) |
| Split clears | fixed `_frames(3)`, then split off and 2 targets | wait until split off (bound 30), then `FarCamera.fits(cam, [a, b], REJOIN)` true and 2 targets |

`test_far_camera_follows_the_bigger_worm` also waited a fixed `_frames(3)` for the physics-frame
split. It now waits on the split (bound 30) and also asserts `FarCamera.fits` is false. The anchor and
target asserts are unchanged.

**No bound got looser.** Two got tighter. The warp went from `< 40 px` to exact (16 px from the code's
formula, ±0.01). "Partner does not move" went from `< 1 px` to exact. The wait bounds come from the code,
not from failing runs:
- The split is computed every physics frame (`FarCamera.step`, called from
  `PlanetLevel._refresh_camera_targets`), so it is due on the next frame. A bound of 30 is plenty.
- The camera ease is `follow = 6/s`, starting at most half the worms' 48 px spread (24 px) from its target:
  ln(24)/6 = 0.53 s, about 32 frames. No zoom step is needed (`fit_hold` is 0.4 s per step). A bound of
  300 is about 10× that.

## Before and after values (this box, measured with a per-frame probe that was then deleted)

- Split on: frame 0 after the warp (the old test waited 90 frames).
- Camera lag to its centre: 2.3 px → 0.9 px (frame 5) → 0.2 px (frame 17) → 0.0 px (frame 29). Zoom
  stayed at index 6 (= want), and rotation reached up within 5 frames.
- Worms between the warp and the asserts: a moved 0.00 px a frame and b moved 0.00 px a frame.
- Warp: `distance(b, a) = 16.0`, against the old bound `< 40` and the new exact 16 ± 0.01.
  Partner move: 0.0, against the old bound `< 1.0` and the new exact 0.
- After the warp, the split cleared on the first physics frame (b then settles to 9.9 px from a, well
  inside REJOIN).
- Test time: 1.7 s before (the 90-frame wait), 0.25–0.31 s after.

The CI value "ratio ~3.9 vs 1.0" was the old `distance(a, a_at) < 1.0` check over the 90 frames. Commit
d082f70 had already moved it to measure only the warp. What was left was fixed waits: the split, the
camera's sees-checks and the split clearing were all read at fixed frame counts. I could not reproduce
the slide on this box, even with a 100 ms stall added to every process frame. So the asserts no longer
depend on whether the worms slide; they don't rely on it not happening.

**Mutation checks**, both reverted with `git checkout scripts/` (diff confirmed clean):
- Tie picks P2 (`players.min()` → `max()` in `far_camera.gd`): the test fails at `targets == [a]`.
- Warp lands 30 px off instead of 16 (`planet_level.gd`): the test fails at the landing assert. The old
  `< 40` bound would have passed this.

## Stability runs (`tests/test_worm_session.gd`, 10 cases, final code)

While these ran, 3 or 4 other lanes' gdUnit processes were running on the 6-core box.

| Run | Overall | solo-select | camera test | bigger-worm |
| --- | --- | --- | --- | --- |
| 1 | 10 cases, 0 errors, 0 failures | PASSED 272 ms | PASSED 248 ms | PASSED 242 ms |
| 2 | 10 cases, 0 errors, 0 failures | PASSED 234 ms | PASSED 245 ms | PASSED 233 ms |
| 3 | 10 cases, 0 errors, 0 failures | PASSED 251 ms | PASSED 248 ms | PASSED 232 ms |
| 4 | 10 cases, 0 errors, 0 failures | PASSED 353 ms | PASSED 295 ms | PASSED 296 ms |
| 5 | 10 cases, 0 errors, 0 failures | PASSED 266 ms | PASSED 252 ms | PASSED 238 ms |
| `taskset -c 0 nice -n 19` | 10 cases, 0 errors, 0 failures | PASSED 280 ms | PASSED 300 ms | PASSED 312 ms |

An earlier set of 5 runs plus a slow-CPU run, made before the solo-select fix, was also 10/10 green.

Each single-suite run aborts at process exit ("Aborted (core dumped)") *after* printing its Overall
Summary. This is the known exit crash in the build-box notes, and dev's own suites do it too.

**Full suite:** 471 test cases, 0 errors, 0 failures, 0 flaky, 0 orphans, exit 0. It ran twice after a
fresh `--import`; the second run is saved in `handoff/test-output.txt`.

## Audit of the other camera and split tests

- `tests/test_worm_session.gd::test_solo_select_hands_the_pad_and_the_camera_to_the_other_worm` had the
  same pattern: a warp, a fixed `_frames(3)`, then the split read, then a fixed `_frames(2)` for the
  anchor handover. It is fixed the same way. It now waits on the split, then on `anchor == P2`
  (bound 30 each). It also asserts `FarCamera.fits` is false and that the split stays on through the
  handover. Every other assert is unchanged.
- The one fixed wait left, `test_saved_solo_never_restores_at_boot` (`_frames(2)`), checks settings and
  lobby state, not a physics result, so I left it.
- `tests/test_greybox_rules.gd::test_camera_rotation_is_capped_and_zoom_is_whole_pixel` calls
  `cam.step(0.1)` by hand with no awaits. It is already deterministic, so it is unchanged.
- I did not edit the other suites that mention the camera (`test_kid_checks`, `test_worm_audio`,
  `test_art_lantern`), because the brief scopes the audit to these two files.

## Off-limits check

I ran `git diff --stat origin/dev...<branch>` against every branch in the serial ship chain that exists
on origin (`slice-burrow-1`, `worm-gap-close-1`, `worm-juice-1`, `worm-mayhem-1`). I also checked the
local-only ones (`worm-big-planet-1`, `worm-burrow-1`, `worm-centipede-1`, `worm-deep-rock-1`,
`worm-gap-close-6`, `worm-gap-close-7`, `worm-star-trait-1`, `worm-star-traits-1`). None of them touches
`tests/test_worm_session.gd` or `tests/test_greybox_rules.gd`. I did not touch any art, PR #15 or PR #17.
