# Regrowth lane report (feature/worm-regrow-1, 2026-11-12)

## Rows moved
- **G-02** partial -> built: food regrows faster *and bigger* in castings.
- **G-04** partial -> built: the whole world regrows on its own; a ring is never exhausted until outgrown.

## What was built (all in `scripts/world/`, `data/rings/`, tests, contracts)
- **Food sizes per tile.** A tile that grows back in castings comes back at `RingDef.castings_size`
  (written as 2 for every ring in `data/rings/rings.tres`). It is drawn plump (a code-drawn shiny
  dome, `Sizes_*` TileMapLayer per live chunk, no art). Eaten, it gives the worm's normal tile growth
  plus `(size - 1) x RingSet.size_growth` (1.0) plain tiles more, in the ring flavour, with the
  existing cue `chomp_bite` (rate limited). Size never changes edibility, so the kid can always eat
  it. Plain ground (dug by anything but a worm) comes back size 1. Saved as `sizes` in the planet
  dict; older tins load with every tile plain. Frame: `handoff/shots/regrow/t001.0s.png` (left:
  regrown big tiles, right: open castings, around: plain dirt).
- **A ring never runs out.** `PolarWorld` now counts eaten-and-waiting cells per ring. Past
  `RingSet.scarce_share` (0.5) of a ring eaten, its regrow times shrink, down to `scarce_factor`
  (0.2x) when bare, so the emptier a ring is the faster it fills. The crust (regrow 0 once outgrown)
  is the only ring that can empty, by design.
- **Jar view.** The planet shot (ChompDirector) already disables the world node; a test now proves
  the clock and regrowth stand still there and resume on "not yet". `PolarWorld.frozen` is an
  explicit switch for any other view that shows the planet without playing it.

## Regrow numbers used (planet seconds, `data/rings/rings.tres`)
| Ring | Plain | In castings (x0.25) | Castings size |
| --- | --- | --- | --- |
| core | 900 | 225 | 2 |
| deep rock | 600 | 150 | 2 |
| dirt | 240 (now written in the file, was the script default) | 60 | 2 |
| topsoil | 180 | 45 | 2 |
| surface | 120 | 30 | 2 |

Green thumb halves the castings times again (unchanged, `test_gardens_rules.gd` still green).
`size_growth` 1.0, `scarce_share` 0.5, `scarce_factor` 0.2.

## 30-minute resident runs (real radius 300, stage speed and bite from Worm, tunnelling 100% of the time)
```
dirt s1:      ate 8474 tiles, most eaten at once 2%,  least left 130736, least in reach 191
topsoil s2:   ate 8336 tiles, most eaten at once 3%,  least left 82943,  least in reach 185
deep_rock s4: ate 17586 tiles, most eaten at once 4%, least left 51268,  least in reach 267
surface s4:   ate 4554 tiles, most eaten at once 14%, least left 5779,   least in reach 130
core s5:      ate 15463 tiles, most eaten at once 54%, least left 1862,  least in reach 96
```
The core is the one ring where a worm can really eat most of it in half an hour; the floor is what
keeps it fed.

## Not done / for other lanes
- Scattered ring *pickups* (`RingFood` in `*_life.tres`) are driven by `scripts/rings/rings_director.gd`,
  not my folder; untouched. `deep_rock_life.tres` is still not in `RingsDirector.LIVES`, so deep-rock
  pickups (ore nuggets, fossils) are never scattered (already noted on W-03). Tiles there regrow fine.
- Big tiles are not in `data/BALANCE.md`'s simulated runs (it models tunnelling new ground only);
  farming castings now pays twice. The Content lane may want to fold it in or lower `size_growth`.
- Values are untuned by play; the big-tile look is a placeholder until the Worm art round.
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
