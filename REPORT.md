# Centipede lane report (feature/worm-centipede-1, 2026-11-12)

## Rows moved
None. **W-04** stays partial with a new note: the centipede part is built, the Mole is still open. L-08 was already built.

## Found
The centipede data, script and `dirt_life.tres` row were already on dev from worm-creatures-2: stage 3, a 1.1 s wind-up, a 3 s chase, gives up past 200 px, live_max 2. I left the data alone and added the missing parts.

## New on this branch
- **Wind-up wave:** a lifted, lighter hump runs from head to tail twice over the telegraph and reaches the tail as it lunges (`windup_wave()`).
- **Give-up beat:** the first give-up only leans the camera in one step for 0.8 s, with no shake (`gave_up_beat`).
- **K-01 fix:** at worm stage 3 the centipede counts as food but never cowered, so it was drawn 1.10x a stage-3 head. It now cowers (0.85x) like the bird.
- No new cues, art or forced movement (a bite still goes through `Gulp`).

## Tests
`tests/test_centipede.gd` has 6 new tests (14 total): the wave before every lunge, the hump position, a single camera beat that gets released, never moving a worm, never bigger than a stage-3 or stage-4 head, and counter spawns only in the dirt band up to live_max. The suite runs in `SuiteSandbox.enter("centipede")`.
Full suite after a clean import, run twice: **460 cases, 0 errors, 0 failures** both times, with no leak line.

## Frames (`handoff/shots/centipede/`)
From a scratch scene with no world. The green blob behind the tail is the worm's body, left behind because the head is teleported.
- `t000.9s`: the chase, along a wavy path.
- `t001.2s`/`t001.6s`/`t002.0s`: the wind-up. Jaws open, the pale hump moves down the body, then the second pass reaches the tail.
- `t002.3s`: the lunge.
- `t002.7s`/`t003.1s`: the give-up. Eyes shut, antennae drooped, greyed, huffing.
The camera beat is not in the frames; only a test covers it.

## Outside owned files
`docs/contracts.md` (appended section) and the `PLAN-STATUS.md` W-04 row.

## Follow-ups
- The Mole in the dirt ring.
- The sneakers from dev are still drawn while gear and art are held. Keep them or not?
- A centipede give-up cue (it borrows `bird_offended`).
- A real-planet frame of the camera beat.
