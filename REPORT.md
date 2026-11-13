# REPORT: worm-star-trait-1 (2026-11-12)

Branch `feature/worm-star-trait-1`, not pushed. Ended: **complete**.

## Rows moved
**D-10** missing → built. D-13 stays partial (note added: Stars show on the wall).

## The Star traits (`data/traits/*_star.tres`)
| Star | Planet | Felt in space | Seen |
| --- | --- | --- | --- |
| frost_star | ice | top speed +110 | snowflake |
| vine_star | jungle | mouth +26 px (ring) | leaf |
| anchor_star | junk | half knock-back | hex nut |
| sugar_star | candy | small food within 280 px drifts in (dotted ring) | pinwheel sweet |
| tick_star | clockwork | sharper turns (accel x2.2) | cog |

Each planet shows its Star (gold star plus part) before it is eaten. Eating the planet earns it,
once per run, via SpaceDrift's existing `star_earned`. `StarAward` (in `space_stage.tscn`) plays the
sting and two rings, leans the camera in for 1.8 s and flies the part into orbit. The Star is then
written onto the planet worm and into the tin. It shows on the trait wall with a gold star corner
and toggles like any trait. It never comes from flavours, it is never a curse, and foods never carry it.
Parts are code-drawn (`StarParts`) and have no text.

## Tests
`tests/test_star_traits.gd`, 7 cases, with contacts resolved directly (no pile). After a clean
import I ran the full suite twice: **461 cases, 0 errors, 0 failures** both times. Both runs print
"20 ObjectDB instances were leaked at exit" (stings still playing at exit).

## Frames (`handoff/shots/star-trait/`)
1. `1-before`: the worm next to the ripe jungle planet, with the gold Star and leaf on the planet's rim.
2. `2-reveal`: the camera leans in, a big gold star with the leaf above the head, and rings.
3. `3-after`: the leaf on a small gold star orbiting the head, with the reach ring at the mouth.
4. `4-wall`: the trait wall with the vine and frost tiles marked with gold stars, and their parts on the worm.

## Outside my files
- `trait_data.gd` (`part_shape`, `star`, `star_planet`), `trait_wall.gd` (marker), `worm_rules.tres`.
- `data/planets/*.tres` (star trait → file, `star_chance` 0), `make_space_data.gd` to match.
- `space_stage.tscn` (+ `StarAward` node). No `scripts/space/` or `scripts/chomp/` edits.
- `test_traits_rules` skips Stars; `test_space_planets` accepts `space_turn`/`space_pull`.

## Follow-ups
- **The cues are borrowed** from the slice traits (slick, green_thumb, magnet, floaty, drill_head) because assets/ was off-limits. The Audio lane needs to add five `trait_<id>` files, then change `cue` in each .tres.
- The `space_*` stats do nothing on the planet worm. Decide this with S-12.
- This replaces the unmerged `feature/worm-star-traits-1` (it reused its `StarParts`). Merge only one of them.
