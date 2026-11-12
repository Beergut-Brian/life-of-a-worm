# Lawnmower lane report (feature/worm-lawnmower-1)

## Rows moved

- **L-12** Lawnmower (5): `missing` → `built`.

## What I built

- `data/creatures/lawnmower.tres` (`LawnmowerData`, new `scripts/creatures/lawnmower_data.gd`): size
  stage 5, radius 24 px, speed 28 px/s, bump 90 px, drive 240 px either side, telegraph 1.2 s,
  engine cue `boot_rumble`, warning bark `threat_near`, bump cue `space_bump`, one live at a time.
- `scripts/creatures/lawnmower.gd` (`Lawnmower extends Creature`) + `scenes/creatures/lawnmower.tscn`:
  - **Drives** back and forth on the ground line, turning round at the ends of its stretch. It
    never turns toward a worm. Its line is the highest ground under both wheels, so it straddles
    a narrow hole and does not sink into the strip it mowed.
  - **Very loud:** the engine loop plays the whole time it drives: +6 dB beside a worm, fading to
    silent by 900 px. A worm it could bump that is ahead of it on the grass gets the warning bark
    and a honk (wide headlight eyes and sound lines).
  - **Eats grass only:** it digs the top `grass` tile under it, which regrows at the ring's rate.
    It never takes a food, a creature or a worm. It is never in the `food` group, and `take()`
    does nothing.
  - **Bumps** a worm of its size or smaller, and only after the 1.2 s telegraph. The worm goes up
    off the grass and away, 90 px over about 0.4 s. The push is added to the head on top of the
    stick: the worm is never steered and keeps all its segments.
  - **The cause beat:** the shadow ahead darkens while it warns and flashes on the bump, with a
    boing star, `space_bump`, and a camera beat (shake 0.35 when screen shake is on, `lean_in` +1
    for 0.6 s, released after).
  - The same worm cannot be bumped again for 1.6 s. A bigger worm makes it honk and turn round.
- **Hooked in through the surface ring's own spawn list:** `surface_life.tres` already counts a
  `lawnmower` species with no body (live_max 0). `data/rings/` is read-only for this lane, so
  `RingsDirector.setup` calls `LAWNMOWER.give_body(ecology)`, which swaps in a copy of that rule
  with the mower scene, live_max 1 and a spawn band just under the grass. The ring data and
  `test_surface_ring` are unchanged. Nothing else spawns it.
- `tests/test_lawnmower.gd`, 10 cases:
  - it stays on the surface line and turns round;
  - it never turns toward a worm;
  - it is never food and never eats a worm (stages 1, 4, 5, 7);
  - it mows grass and nothing else (an apple and a grub in its way are untouched);
  - the bump knocks the worm up and off after the telegraph, with the beat, cue, shake and lean;
  - a bigger worm is never bumped;
  - no juggling;
  - every cue resolves to a real `.ogg`, and the engine loop is the real file, not the grey beep;
  - the surface counter spawns exactly one mower, on the grass.
- `docs/contracts.md`: appended `### Lawnmower (worm-lawnmower-1)`.

## Tests

I deleted `.godot`, ran a clean import, then ran the full gdUnit4 suite twice with `--continue`.
Both runs gave the same line:
`Overall Summary: 441 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
The count includes the 10 new lawnmower cases. Up to 10 other lanes' gdUnit runs were on the box at the same time.

## Frames

`handoff/shots/lawnmower/` comes from a scratch scene (`.scratch/mower_shot.tscn`): the real planet,
a stage-4 worm on the grass, the mower driving at it, and the camera held close for the frames.
`contact_bump.png` puts the four frames side by side:
- 0.8 s: honking (wide eyes, sound lines);
- 1.6 s: the bump (boing star, worm launching);
- 2.0 s and 2.4 s: the worm up off the grass while the mower carries on.

The full frames are `t000.8s.png` to `t002.9s.png`. I held the camera myself for the frames, so the
camera beat itself (shake and lean) is not visible in them. The test checks it.

## What I could not check

- **The sound on a real speaker.** The engine loop's loudness, how `boot_rumble` sounds looped, and
  whether +6 dB is "very loud" without drowning the chomps. The headless box has no audio out.
- How the camera beat feels in real play. Tests only check that it is requested and released.
- Mowed tiles are real holes in the grass (the tiles are dug and regrow in 120 s). On a saved tin,
  a strip mowed in an earlier session is a one-tile-deep lane until it regrows, and a mower that
  spawns over it rides in it. It reads as "its mowed lane" in frames, but Kaden may want mowing to
  be shallower.

## Notes for other lanes / Hermes

- The W-06 row still says "**Missing:** the lawnmower threat (body and behaviour, creatures lane)";
  L-12 now covers it.
- `surface_life.tres` could carry the mower's `live` and `live_max` directly (owner: the rings and
  surface lane). `give_body` already leaves a rule alone when its `live` is set.
- Like the boot, the mower's data passes `test_every_creature_except_a_jarling_becomes_food_eventually`
  (size stage 5 < 7), but its body is never edible, per GAME.md ("eats grass only; bumps you, does not
  eat you").
