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
