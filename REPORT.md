# REPORT: worm-star-trait-1 (2026-11-12)

Branch `feature/worm-star-trait-1`, not pushed. Ended: **complete**.

## Rows moved
- **D-10** missing → **built**. **D-13** stays partial (note: Stars show on the wall with a gold star corner).

## The five Star traits (`data/traits/*_star.tres`, one per `data/planets/*.tres`)
| Star | Planet | Felt (one stat, space) | Seen |
| --- | --- | --- | --- |
| frost_star | ice | top speed +110 px/s | snowflake |
| vine_star | jungle | mouth +26 px (green ring) | leaf |
| anchor_star | junk | bumps knock half as far | hex nut |
| sugar_star | candy | small food within 280 px drifts to the mouth (dotted ring) | pinwheel sweet |
| tick_star | clockwork | steering accel x2.2, sharper turns | cog |

Earn: each planet wears its Star (gold star with the part, orbiting it) before it is eaten; eating the
planet earns it once per run through SpaceDrift's existing `star_earned` path. Reveal (`StarAward`,
child of `space_stage.tscn`): the trait's sting, two rings, a 1.8 s camera lean-in, the part flies
from a big gold star into orbit round the head. Then it's written into the planet worm and the
tin, listed on the trait wall with a gold star corner, and toggles like any trait. Never from
flavours (empty `requires`), never a curse (one positive add), foods never carry it (`star_chance` 0).
Parts are code-drawn (`StarParts`, no text, no files).

## Tests
`tests/test_star_traits.gd`, 7 cases (one Star per planet; each planet eaten gives exactly its own;
foods never carry one; never from flavours; reveal once per earn, cue once, camera beat, not again
after reload; turn and pull felt; record + re-equip + wall toggle). Contacts resolved directly, no pile.
Full suite after `rm -rf .godot` + import: run 1 **461 cases, 0 errors, 0 failures**; run 2 the same (461, 0, 0).
Both print "20 ObjectDB instances were leaked at exit" (known stings-at-exit line, see build notes).

## Frames (`handoff/shots/star-trait/`, looked at)
1. `1-before.png`: worm left of the ripe jungle planet; the planet's gold Star with the leaf on its rim.
2. `2-reveal.png`: camera leaned in; big gold star with the leaf above the head, green and gold rings, debris.
3. `3-after.png`: back to the normal view; leaf on a small gold star orbiting the head, green reach ring at the mouth.
4. `4-wall.png`: planet worm's trait wall: glow, vine and frost tiles, the two Stars with gold star corners; snowflake above the head, leaf on the tail.

## Changes outside my own files
- `scripts/worm/trait_data.gd` (`part_shape`, `star`, `star_planet`), `trait_wall.gd` (star marker), `worm_rules.tres` (+5).
- `data/planets/*.tres`: inline star trait → the trait file, `star_chance` 0; `scripts/tools/make_space_data.gd` matches.
- `scenes/levels/space_stage.tscn`: added the `StarAward` node. No `scripts/space/` or `scripts/chomp/` edits.
- Tests: `test_traits_rules` skips Stars; `test_space_planets` star check accepts `space_turn`/`space_pull`.

## Follow-ups for the producer
- **Cues are borrowed** (`trait_slick`, `trait_green_thumb`, `trait_magnet`, `trait_floaty`, `trait_drill_head`): assets/ was off-limits. Audio lane: five `trait_<id>` files, then change `cue` in each .tres.
- `space_*` stats do nothing on the planet worm (part shows only). Fine while there's no way back from space; decide for S-12 heirloom.
- Supersedes unmerged `feature/worm-star-traits-1` (random food rider, edits in scripts/space); reused its `StarParts`. Don't merge both.
