# Plan status: Life of a Worm

Format: `~/openjar/lanes/plan-status-format.md`. Lanes read this first and update their rows in the
same commit as the work. IDs are stable and never renumbered; new briefs add rows, and replaced
rows are marked `superseded` rather than deleted.

Sources (oldest first):
- S0 `~/openjar/WORM-PLAN-2026-11-09.md` (Kaden's first brief, read-only). **No rows.** I diffed it
  line by line against S1, and S1 replaces every S0 line (20 to 30 min run, eaten = one stage,
  400-tile disk, two-prototype week, old phases and first-playable definition, old open questions).
  The S0 lines that are still live are repeated verbatim in S1 and are tracked under S1.
- S1 `~/openjar/WORM-PLAN-2026-11-10.md` (Kaden's original plan, revised 2026-11-10, read-only).
  Byte-identical to `GAME.md` from "# Life of a Worm — Game Design & Build Plan" down (checked with
  `diff`). The growth-stages table is an embed (`[embedded content: growth stages · 7 stages, grub
  to star eater]`) whose rows are in neither file, so stage names other than Grub (stage 1) are
  unknown here.
- S2 `GAME.md` "Producer notes (Gary, 2026-11-10)": Where Worm stands, Standing rules, Stale
  lines, Decisions made without Kaden. Wins over S1 where they disagree.
- S3 `GAME.md` "Kaden's answers, 2026-11-10" (D86 to D89), plus D90 (worm names, 2026-11-11) on the same list.
- S4 Kaden chat 2026-11-10 22:41, quoted in GAME.md: priority order.
- S5 Kaden chat 2026-11-10, quoted in GAME.md: "no stick-only requirement anywhere".
- S6 Kaden chat 2026-11-10, quoted in GAME.md: "Characters are 3D-first".
- S7 Kaden, Docket D90 (2026-11-11), quoted in GAME.md Producer notes: worm names.
- No "Playtest ... changes" sections exist yet (`playtests/` has only `_TEMPLATE.md`).

**State on 2026-11-11.** The repo was created from `openjar-template` on 2026-11-10 (`886307a`), so
almost every row is `missing`, and that is expected. Template pieces the plan relies on are `partial`,
with a note on what Worm still has to hook in. What I checked myself:
- Test suite (`godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests`):
  **95 test cases, 0 failures**. All are template tests. There is no Worm test yet.
- Frames (real renders from `scripts/tools/shots.sh`, which I looked at):
  `.scratch/shots/lobby/t002.0s.png` (template lobby titled "LIFE OF A WORM" on the purple showtime
  backdrop, with chooser podiums showing Jeff and Chuck) and `.scratch/shots/pause/t002.0s.png` (template pause:
  Resume / Restart / Settings / Back to Open Jar).
- `openjar-addons` tag `v0.2.0` (`b074b4c`) exists and contains `tileworld/disk_shape.gd`, `cutscene/`,
  `picto_bubble/` and `split_screen/`. **This repo does not vendor it yet** (`addons/` holds only `gdUnit4`).

Proof shorthand for `missing` rows (each checked 2026-11-11):
- **∅code**: `scripts/gameplay/` holds only `.gitkeep`. There is no `scenes/levels/`, `scenes/creatures/` or `scenes/props/`,
  and `scenes/players/` has only the template `player.tscn`.
- **∅data**: `data/` holds only `roster.json`.
- **∅art**: `assets/sprites/`, `assets/models/`, `art/prompts/` and `store/` hold only `.gitkeep`.
- **∅audio**: `assets/audio/sfx/` and `assets/audio/music/` hold only `.gitkeep`. `assets/audio/CUES.md` lists template UI cues only.
- **∅tests**: no Worm test in `tests/`.
- **∅contract**: `docs/contracts.md` has no Worm signals (template `Game` / `Players` / `Roster` only).

## S Stages and core loop

| ID | Source | Item (short, Kaden's words where possible) | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| S-01 | S1 Growth stages | Seven stages, grub to star eater; each a chapter of 2 to 4 hours | missing | ∅code, ∅data | Stage names 2 to 7 are in the S1 embed, which isn't in either file |
| S-02 | S1 Core loop 5 | Stage up needs enough segments **and** the ring's apex creature eaten | built | `tests/test_greybox_rules.gd::test_stage_up_needs_segments_and_the_apex`, `::test_apex_before_enough_segments_waits_for_them` | Grey-box: `WormGrowth.apex_gate` + `eat_apex(ring_stage)`; the trait arena keeps the segments-only rule (feature/greybox-1) |
| S-03 | S1 Core loop 5 | Stage-up: worm swells, screen shakes, dock cutscene, camera pulls back, new ring edible; biggest sound and visual in the game | partial | `tests/test_greybox_planet.gd::test_apex_bite_stages_up_and_pulls_the_camera_back`; `handoff/shots/` | Swell (pop 2.2x), shake, 2 white frames, camera cap down a notch, topsoil becomes edible (data), `stage_up` beep. Dock cutscene: `Story.play("stage_N")` hook only (story lane) (feature/greybox-1) |
| S-04 | S1 Core loop 4 | Every few bites adds a visible segment; segments are the progress bar, on the worm, not the HUD | built | `tests/test_greybox_planet.gd::test_tunnelling_eats_tiles_and_grows`; `tests/test_worm_body.gd` | Segments pop on at the tail; the HUD shows stage only (feature/greybox-1) |
| S-05 | S1 Core loop 1 | Eating automatic on contact; mouth opens as food approaches | built | `tests/test_worm_body.gd`; `scripts/worm/worm.gd` `_eat_and_carry` | Prototype mouth (3 states) now in the planet (feature/greybox-1) |
| S-06 | S1 Core loop 1 | Anything smaller is food: dirt (slow growth), seeds, roots, grubs, pebbles, then beetles, then everything | partial | `tests/test_greybox_planet.gd::test_tunnelling_eats_tiles_and_grows`; `scripts/planet/planet_level.gd` | Dirt tiles (slow growth), seeds, grubs, pebbles and the apex beetle. Roots and later foods not yet (feature/greybox-1) |
| S-07 | S1 Core loop 3 | Avoid, then outgrow: bigger bugs chase lazily, slower in dirt; outgrown bug becomes food with a "now I eat YOU" sting | partial | `tests/test_greybox_rules.gd::test_apex_flips_from_threat_to_food` | Placeholder apex beetle stalks, telegraphs, eats; flips to food with `now_i_eat_you`. Other bugs: Gameplay lane (feature/greybox-1) |
| S-08 | S1 Core loop 6 | Past stage 4 the worm bursts through the crust and eats the surface; the disk visibly shrinks | missing | ∅code | |
| S-09 | S1 Core loop 7 | Stage 6 planet chomp: deliberate point of no return, shown as a picture, confirmed by holding the button, one long chomp | missing | ∅code | Confirmation uses PictoBubble (addons v0.2.0, not vendored) |
| S-10 | S1 Core loop 7 | Planet in a jar on Old Reel's shelf: snapshot to `jars/<planet>.json`, re-enter and play forever with stage 6 disabled | missing | ∅code | Risk prototype R-02 |
| S-11 | S1 Core loop 8 | Space (stage 7): themed planets drift by, eat small, dodge big, rare traits; the sun is the last meal | missing | ∅code | |
| S-12 | S1 Core loop 8 | After the sun, Old Reel offers another tin: new planet, one chosen trait kept as an heirloom | missing | ∅code | |
| S-13 | S1 Core loop | No fail state; the only irreversible act is the planet chomp, and the jar makes it safe | missing | ∅code | |
| S-14 | S1 Growth stages | Thresholds, zoom levels, feature sprites as data in `data/stages.tres` | missing | ∅data | |
| S-15 | S1 Tech: scale | Stages 1 to 5 in one disk scene; growth swaps segment sprite set and collision size; tile size never changes | missing | ∅code | |
| S-16 | S1 Tech: scale | Stage 6 scripted: disk rendered to texture, giant-worm sprite, shader-mask chomp, cross-fade to space | missing | ∅code | Risk prototype R-02 |
| S-17 | S1 Tech: scale | Stage 7 separate scene: no tiles, no gravity, planets as `RigidBody2D` with size stages and sleepy faces | missing | ∅code | |
| S-18 | S1 Space endgame | Five planet types (ice, jungle, junk, candy, clockwork), each a 20 to 40 min meal with its own foods, one Star trait, one page, random order | missing | ∅code, ∅data | `data/planets/*.tres` |
| S-19 | S1 Core loop | Loop scales: bite (seconds), outing 20 to 40 min, chapter 2 to 4 h, planet 15 to 25 h; a 5-year-old sees progress in any ten minutes | missing | ∅data | Tuned in `data/BALANCE.md` (W-24) |
| S-20 | S1 Two depths | His layer is actions, Kaden's layer is consequences. Nothing in Kaden's layer is required for the chomp; no system punishes; every system passes the kid test | missing | ∅code | Design guardrail. Reviewer checks it per system |

## D Diet and traits

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| D-01 | S1 Depth 1 | Every food has a flavour; eating tints the newest segments, so the diet is visible as stripes | missing | ∅code | Risk prototype R-03 |
| D-02 | S1 Depth 1 | Fill enough segments of one flavour and the worm grows a trait, visibly | built | `tests/test_traits_rules.gd`; `--demo` log (Wriggle earned in play) | Wriggle earned from grubs in the grey-box demo (feature/greybox-1) |
| D-03 | S1 Depth 1 | Root → Green thumb: castings regrow food twice as fast; gardens yield more | missing | ∅data | |
| D-04 | S1 Depth 1 | Bug → Wriggle: faster, longer burst | missing | ∅data | |
| D-05 | S1 Depth 1 | Stone → Stone head: bite rock a stage early; boulders stop bonking you (with Glow: finds geodes) | missing | ∅data | |
| D-06 | S1 Depth 1 | Crystal → Glow: lights dark rings; hidden seams and secrets shimmer | missing | ∅data | Needs real 2D light (A-02) |
| D-07 | S1 Depth 1 | Junk → Magnet: small food drifts to your mouth; later, drag big objects | missing | ∅data | |
| D-08 | S1 Depth 1 | Water → Slick: swim fast; flooded tunnels stop slowing you | missing | ∅data | |
| D-09 | S1 Depth 1 | Cloud → Float: glide between hills and across gaps | missing | ∅data | |
| D-10 | S1 Depth 1 | Star → one rare trait per space planet type | missing | ∅data | |
| D-11 | S1 Depth 1 | Hybrids from two filled flavours (Drill head, Skater, Garden cart); ~8 base traits and 10 hybrids at launch as `TraitData` | missing | ∅data | Only 3 hybrids are named. 7 still to design |
| D-12 | S1 Depth 1 | Trait slots grow with stage, 1 at stage 2 to 5 at stage 6; earned traits are never lost | missing | ∅code | |
| D-13 | S1 Depth 1 | Sleep in the burrow to choose active traits from a wall of pictures; the newest equips itself for players who never open it | partial | `scripts/worm/worm.gd` `wall_anywhere`; `handoff/shots/` | Y opens the trait wall only in the burrow; a placeholder plaque shows the traits there. PictoBubble wall later (feature/greybox-1) |
| D-14 | S1 Tech | `TraitData` (flavour requirements, modifiers, part sprite per stage, sound); per-segment flavour counts; one `WormStats` resolver, no special cases | missing | ∅code, ∅tests | R-03 proves it |
| D-15 | S2 Upgrades are felt | Every trait changes something visible and audible on the worm; no hidden-number traits; its part shows the moment it's earned | missing | ∅code | Sound side is U-16 |
| D-16 | S1 Data | `data/foods/*.tres` (flavour, growth, size stage, regrow time, sprite, sounds) and `data/traits/*.tres` | missing | ∅data | |

## G Castings and gardens

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| G-01 | S1 Depth 2 | Where a worm eats it leaves castings (dark rich soil), a second tile layer | partial | `scripts/world/polar_world.gd`; `tests/test_world_regrowth.gd::test_castings_regrow_faster_than_plain_digging`; `handoff/shots/` (R-a) | R-a: every `World.eat_tile` writes castings, a second layer drawn under the tiles and saved. Placeholder look |
| G-02 | S1 Depth 2 | Food regrows faster and bigger in castings | partial | `tests/test_world_regrowth.gd::test_castings_regrow_faster_than_plain_digging` | Faster done (`castings_factor` 0.25 in `data/rings/rings.tres`). "Bigger" not built: food sizes come with `data/foods/` |
| G-03 | S1 Depth 2 | Drop a carried seed in castings and a patch of that flavour grows and keeps growing; farming with no farm screen | partial | `tests/test_world_regrowth.gd::test_garden_grows_in_castings_and_keeps_growing` | World side built (R-a): `plant_seed(cell, flavour)` in castings grows a patch that refills and spreads through castings. Carrying a real seed comes with R-04 |
| G-04 | S1 Depth 2 | The whole world regrows slowly on its own; a ring is never exhausted until outgrown | partial | `tests/test_world_regrowth.gd::test_castings_regrow_faster_than_plain_digging` | Every ring has a `regrow_time` in data; tiles removed by anything but a worm regrow at the plain rate. Values untuned |
| G-05 | S1 Tech | Low-frequency regrowth pass over live chunks restores food tiles whose edit is older than the ring's regrow time; edits carry timestamps | built | `tests/test_world_regrowth.gd::test_eaten_dirt_regrows_on_the_simulated_clock`; `scenes/levels/polar_stress.tscn` | R-a: round robin over live chunks, at most 48 cells a frame, idle chunks skipped; worst regrowth frame < 2 ms in the 10-minute stress run |
| G-06 | S1 Art | Rain soaks into the topsoil and makes castings sprout (cosmetic first, light garden bonus second) | missing | ∅code | Pairs with A-04 |

## B Burrow and carrying

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| B-01 | S1 Core loop 2 | Eat it or keep it: hold X to carry instead of swallow, bring it home as trophy, seed or pet; optional, a kid who eats everything is fine | partial | `tests/test_greybox_planet.gd::test_carried_home_becomes_a_trophy` | Hold X carries; home turns it into a trophy, or a seed into a garden in castings. Pets missing (feature/greybox-1) |
| B-02 | S1 Depth 3 | Hollow out a chamber anywhere and sleep in it: that is home | built | `tests/test_greybox_planet.gd::test_sleeping_in_a_hollow_sets_home_and_saves`, `::test_standing_still_in_a_tunnel_is_not_a_burrow` | Hold still 2 s where 75% of cells within 2 tiles are air (feature/greybox-1) |
| B-03 | S1 Depth 3 | Carried things become trophies on shelves the worm digs itself | built | `tests/test_greybox_planet.gd::test_carried_home_becomes_a_trophy`; `handoff/shots/` | Placeholder: one dug notch per trophy on the burrow floor, drawn trophy blobs (feature/greybox-1) |
| B-04 | S1 Depth 3 | Pets with jobs: ladybird fetches seeds, glow-worm lamp, ant crew tends one garden | missing | ∅data | `data/pets/*.tres` |
| B-05 | S1 Depth 3 | Trophy families give small standing bonuses; decorating is also a build | missing | ∅data | `data/trophies/*.tres` |
| B-06 | S1 Depth 3 | Burrow grows with the worm; by stage 5 a cavern with a buried house for furniture | missing | ∅code | |
| B-07 | S1 Depth 3 | The burrow rides along into the jar at the planet chomp | missing | ∅code | Part of S-10 |
| B-08 | S1 Tech | Burrow = flagged chamber region, shelf slots, sleep spot, pet slots; trophies and pets are `Node2D`s saved by id | partial | `scripts/planet/burrow.gd` | Chamber = world keep zone (never regrows), shelf slots, sleep spot, trophies saved by id. No pet slots (feature/greybox-1) |

## L Living rings and creatures

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| L-01 | S1 Depth 4 | Each ring has a small food chain (plants regrow, grubs eat roots, beetles eat grubs, birds eat beetles); eat one link hard and the others shift | missing | ∅code | |
| L-02 | S1 Tech | Per-ring population counters with birth and predation rates, spawning into live chunks; nothing simulated outside them | missing | ∅code, ∅data | Rules live in `data/rings.tres` |
| L-03 | S1 Depth 4 | One apex creature per ring, outgrown and eaten to stage up: telegraphed, funny, never a fight | partial | `tests/test_greybox_rules.gd` | Dirt ring apex = placeholder big beetle (`scripts/planet/apex_beetle.gd`). Other rings later (feature/greybox-1) |
| L-04 | S1 Bugs | Bigger eats smaller: smaller things flee slowly, bigger amble toward you, equal size ignores you; no bestiary needed | partial | `tests/test_greybox_rules.gd::test_apex_flips_from_threat_to_food` | Apex flees slowly once outgrown, ambles toward a smaller worm (feature/greybox-1) |
| L-05 | S1 Bugs | Grub (stage 1): wiggles in place, adorable | missing | ∅data | |
| L-06 | S1 Bugs | Ant (1): marches in lines, cartoon march, tiny hats | missing | ∅data | |
| L-07 | S1 Bugs | Beetle (2): trundles toward smaller worms, slow in dirt; round, shiny, blinks | partial | `scripts/planet/apex_beetle.gd` | Round, shiny, blinks, trundles toward smaller worms; it is the grey-box apex (feature/greybox-1) |
| L-08 | S1 Bugs | Centipede (3): wavy chase, gives up fast; sneakers on every foot | missing | ∅data | |
| L-09 | S1 Bugs | Mole (3): a Jarling, never food, never a threat; pops out of walls, apologises, keeps the swap shop | missing | ∅code; Mole not in `data/roster.json` or `assets/characters/` | Mole exists in `~/openjar/openjar-characters/characters/mole/` (lead) |
| L-10 | S1 Bugs | Bird (3): pecks from the surface with a boing, flies off offended | missing | ∅data | |
| L-11 | S1 Bugs | Gardener's boot (4): stomps near the surface; the gardener is never seen | missing | ∅data | |
| L-12 | S1 Bugs | Lawnmower (5): drives the surface, very loud, eats grass only, bumps you | missing | ∅data | |
| L-13 | S1 Bugs | Big planet (7): drifts, bumps smaller worms, sleepy face | missing | ∅data | |
| L-14 | S1 Bugs | Threats telegraph with a shadow or rumble a full second before arriving | missing | ∅code | Kid check K-02 |
| L-15 | S1 Bugs / Co-op | Eaten: comic gulp, out the other end dizzy (stars, wobble), one segment shorter, next to the partner or nearest tunnel, 0.5 s invulnerability sparkle, never a pain sound | missing | ∅code | Kid check K-03 |
| L-16 | S1 Bugs | First bite of a former threat: special sting and close-up of the worm grinning | partial | `tests/test_greybox_planet.gd::test_apex_bite_stages_up_and_pulls_the_camera_back` | `now_i_eat_you` beep + worm pop + stage-up beat. No close-up yet (feature/greybox-1) |
| L-17 | S1 Bugs | Every creature except a Jarling becomes food eventually; Jarlings get a soft "friend" outline | missing | ∅code | |
| L-18 | S1 Tech | `CreatureData` .tres (stage, behaviour enum, sprite, bark, telegraph), one `scenes/creatures/*.tscn` each; max 40 live | missing | ∅code, ∅data | |
| L-19 | S1 Bugs | Nothing hunts you in space, apart from dodging big planets | missing | ∅code | |

## X Secrets

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| X-01 | S1 Depth 5 | One hidden place per ring, each with a unique food, a tackle-box page, sometimes the only source of a hybrid | missing | ∅data | `data/secrets/*.tres` |
| X-02 | S1 Depth 5 | Ant city in the dirt | missing | ∅data | In vertical slice (R-06) |
| X-03 | S1 Depth 5 | Old Reel's sunken rowboat and lost tackle in the aquifer | missing | ∅data | |
| X-04 | S1 Depth 5 | Fossil hall in the rock | missing | ∅data | |
| X-05 | S1 Depth 5 | Geode cathedral at the core | missing | ∅data | |
| X-06 | S1 Depth 5 | A balloon stuck in the sky | missing | ∅data | |
| X-07 | S1 Depth 5 / Decided | The Mole's swap shop in the dirt ring (trophies for seeds), the first Jarling cameo | missing | ∅code | In vertical slice. Uses PictoBubble |
| X-08 | S1 Decided | Secrets and the surface keep a few empty spots for later Jarling cameos | missing | ∅data | |
| X-09 | S2 Jarling cameos | Bloom becomes Worm's first cameo update (Gary's pick; Kaden can veto) | later | GAME.md:24 | After v1.0. `assets/characters/bloom/` is vendored by the template (as a playable chooser character) |

## T Old Reel's tackle box

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| T-01 | S1 Depth 6 | The collection book and the only menu: sketched, wordless pages for every food, creature, trait, secret, and cutscene | missing | ∅code | |
| T-02 | S1 Depth 6 | Each completed page pins a fishing lure to the lid | missing | ∅code | |
| T-03 | S1 Tech | A page per `FoodData`, `CreatureData`, `TraitData`, secret and cutscene, unlocked by signals | missing | ∅code, ∅contract | `page_completed` signal |
| T-04 | S1 Depth 6 | Completion is the long tail for a solo player after the planet is eaten | missing | ∅code | |

## W World, engine, save, data, contracts

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| W-01 | S1 World | The planet is a disk of tiles, gravity toward the centre, "down" is always toward the core | partial | `tests/test_world_polar.gd::test_gravity_points_at_the_core`; `scenes/levels/disk.tscn` | R-a disk, gravity and rotating camera. The game's disk level is Gameplay's |
| W-02 | S1 Rings | Core: glowing rock, crystals, unbreakable Strangestone seam; lava blobs bounce you; edible from 5 | missing | ∅data | |
| W-03 | S1 Rings | Deep rock: stone, ore; ore nuggets, fossils; rock beetles; edible from 4 | missing | ∅data | |
| W-04 | S1 Rings | Dirt: dirt, clay, roots; seeds, roots, grubs, pebbles; beetles, centipedes, moles; 1 to 3 | missing | ∅data | Mole listed as a threat here contradicts L-09 (see REPORT) |
| W-05 | S1 Rings | Topsoil: grass, mushrooms, burrows; mushrooms, ants, sandwich crumbs; birds, gardener's boot; 2 to 3 | missing | ∅data | |
| W-06 | S1 Rings | Surface: trees, fences, houses, cars, cows, hills, water tower; the lawnmower; 4 to 5 | missing | ∅data | |
| W-07 | S1 Rings | Sky: clouds, birds, planes, balloons; no threats; 5 to 6 | missing | ∅data | |
| W-08 | S1 Rings | Space: moons, planets, comets, the sun; big planets bump; 7 | missing | ∅data | |
| W-09 | S1 World | About 1,000 tiles across at 16 px (~785,000 tiles), streamed in polar chunks (ring x sector) | partial | `scenes/levels/polar_stress.tscn` (785,456 tiles) | R-a kept radius 500 and measured it on the software renderer; the GTX 1060 check is still to do |
| W-10 | S1 World | Every tile destructible; eaten tiles become air; loose things (pebbles, a cow) fall toward the core | missing | ∅code | |
| W-11 | S1 World | Surface props are multi-tile objects that break into edible chunks when a big enough worm bites | missing | ∅code, ∅data | `scenes/props/`, `data/props/*.tres` |
| W-12 | S1 World | The disk radius shrinks as it's eaten; stage-6 planet shot shows a lumpy bitten planet | missing | ∅code | |
| W-13 | S1 World | Generic small-town props: water tower, diner, basketball court, Old Reel's dock and shed by the pond; no real places | missing | ∅data | Also P-22 |
| W-14 | S1 Decided | Nothing is indestructible except the Strangestone seam at the core | built | `tests/test_world_regrowth.gd::test_strangestone_is_never_eaten` | Unbreakable seam at the centre (R-a) |
| W-15 | S1 Disk tech | Cartesian coords, core at origin, gravity `-position.normalized() * g`; worms cling to dirt while tunnelling | partial | `tests/test_world_polar.gd::test_gravity_points_at_the_core` | World side done. The worm's clinging is the worm lane's |
| W-16 | S1 Disk tech | Chunk = ring band x angular sector (~32x32); 5x5 live per worm; only edits saved, base disk from a seed | built | `tests/test_world_polar.gd::test_two_eaters_two_neighbourhoods`, `test_cell_chunk_round_trip_every_quadrant`, `tests/test_world_regrowth.gd::test_save_holds_only_edits_and_round_trips` | Band 32 chosen by R-a (see handoff report) |
| W-17 | S1 Disk tech | Eating a tile: set to air, record edit, chomp particle, add growth | built | `tests/test_greybox_planet.gd::test_tunnelling_eats_tiles_and_grows` | `World.tile_eaten` feeds the worm the ring flavour (0.05 growth a tile), throttled chomp + crumbs (feature/greybox-1) |
| W-18 | S1 Inherited | Take `tileworld` from `openjar-addons`: chunk key becomes ring/sector, gravity to core, edits get timestamps | built | `addons/openjar/VENDORED.md` (v0.2.0, `b074b4c`); `scripts/world/polar_world.gd` | R-a vendored the addon. The polar key was already in it; timestamps and castings are game-side; the upstream asks are in the R-a report |
| W-19 | S1 Inherited / S2 Stale | Split director available; try per-view rotation, decide by playtest | superseded | GAME.md:34 (S2) | S2: experiment only; the default is one shared rotating camera. `split_screen/` is in addons v0.2.0 |
| W-20 | S1 Out of scope | One hand-tuned disk layout with seeded variation; no procedural planets beyond one seed per run | missing | ∅data | |
| W-21 | S1 Save | Per bait tin: seed, timestamped edits, castings, each worm's stage/segments/flavours/traits, burrow, populations, secrets, pages, cutscenes seen, jars | partial | `tests/test_greybox_planet.gd::test_each_tin_round_trips_on_its_own` | Three tins (`Save.use_slot`), each: seed, edits + times, castings, gardens, both worms, burrow, apex, pickups. Populations, secrets, pages, cutscenes, jars not yet (feature/greybox-1) |
| W-22 | S1 Save | Autosave every 30 s and on sleep, pause, quit | built | `tests/test_greybox_planet.gd::test_quitting_at_any_moment_loses_nothing`, `::test_pause_saves_the_tin`, `::test_sleeping_in_a_hollow_sets_home_and_saves` | 30 s timer, sleep, pause, quit, back to lobby, stage-up (feature/greybox-1) |
| W-23 | S1 Perf | 25 live chunks (~25k tiles per worm) at 60 fps on a GTX 1060; ≤40 creatures; C# chunk serialiser only if streaming stutters | partial | R-a report measurements | Software renderer only (llvmpipe). GTX 1060 run outstanding |
| W-24 | S1 Data (2026-11-10) | `data/BALANCE.md` targets 2 to 4 h per stage, 15 to 25 h to the chomp, a segment every 2 min, something new every 15; shared-growth ratio 0.25 | missing | ∅data | |
| W-25 | S1 Data (2026-11-09 line) | `data/BALANCE.md`: 20 to 30 minute full run; one stage every 3 to 4 minutes | superseded | GAME.md:32 (S2 Stale lines) | Replaced by W-24 |
| W-26 | S1 Data | `data/rings.tres` (order, radii, tile set, dominant hue, edible-from, populations), `data/creatures/`, `data/props/`, `data/stages.tres`, plus foods, traits, secrets, pets, trophies, planets, cutscenes | partial | `data/rings/rings.tres` | R-a: ring order, radii, tiles, hue, edible-from, regrow time, flavour. Populations, creatures, props, stages still to come |
| W-27 | S1 Contracts | `ate`, `stage_changed`, `eaten_by`, `breakthrough`, `planet_eaten`, `World.is_edible_by`, `World.eat_tile` in `docs/contracts.md` | partial | `docs/contracts.md` "World: the polar disk" | `World.is_edible_by` and `World.eat_tile` documented (R-a); the worm signals belong to the worm lane |
| W-28 | S1 Contracts (2026-11-10) | `segment_added`, `trait_earned`, `traits_changed`, `carried`, `brought_home`, `garden_planted`, `secret_found`, `page_completed`, `cutscene_finished`, `planet_jarred`, `Worm.stats`, `World.regrow_time` | partial | `docs/contracts.md` "World: the polar disk" | `garden_planted` and `World.regrow_time` documented (R-a); the rest belongs to other lanes |
| W-29 | S1 Scenes | `scenes/levels/disk.tscn`, `space.tscn`, `planet_chomp.tscn`, `scenes/players/worm.tscn`, `scenes/creatures/`, `scenes/props/`, `scenes/ui/hud.tscn` | partial | `scenes/levels/planet.tscn` | Grey-box game scene hosts world, worms, apex, burrow; HUD built in code (`scripts/planet/planet_hud.gd`) (feature/greybox-1) |
| W-30 | S1 Scenes | HUD: size stage as a growing worm icon, no numbers | missing | ∅code | |
| W-31 | S1 Out of scope | A true 3D sphere | dropped | GAME.md "Out of scope for v1" | Kept out of v1 |
| W-32 | S1 Out of scope | Placing blocks or buildings from a menu; combat, hunger/survival meters, crafting screens, written quests or dialogue, a calendar | dropped | GAME.md "Out of scope for v1" | |
| W-33 | S1 Out of scope | Versus, scores, leaderboards | dropped | GAME.md "Out of scope for v1" | |
| W-34 | S1 Out of scope | Multiple space systems; space ends at the sun | dropped | GAME.md "Out of scope for v1" | |

## C Camera, controls, players and co-op

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| C-01 | S1 Camera | One shared `Camera2D` that rotates so "down" is toward the core; rotation rate capped, never spins fast | built | `tests/test_greybox_rules.gd::test_camera_rotation_is_capped_and_zoom_is_whole_pixel` | 1.2 rad/s cap (feature/greybox-1) |
| C-02 | S1 Camera | Zoom fits both worms; pulls back a notch each stage; zoom in whole pixel multiples | built | `tests/test_greybox_rules.gd::test_camera_rotation_is_capped_and_zoom_is_whole_pixel`, `tests/test_greybox_planet.gd::test_apex_bite_stages_up_and_pulls_the_camera_back` | Fits head and tail of every worm; cap 3x at stage 1, 2x at stage 2 (feature/greybox-1) |
| C-03 | S1 Camera | Worms on opposite sides: average "down", zoom out until both fit | partial | `scripts/world/polar_camera.gd` `fit_index` | Average up, zoom out to the cap; past it an edge arrow (P-07) (feature/greybox-1) |
| C-04 | S1 Camera | Stage 6 cuts to a fixed planet shot, then eases into space where gravity is off and the camera stops rotating | missing | ∅code | |
| C-05 | S1 Controls | Left stick steers the head, body follows snake-style; holding toward dirt tunnels | built | `tests/test_greybox_planet.gd::test_tunnelling_eats_tiles_and_grows` | Screen-relative stick (camera rotation) (feature/greybox-1) |
| C-06 | S1 Controls | A = Burst: short speed boost, dust trail, recharges fast, mashing is fine | built | `tests/test_worm_body.gd`; `--demo` | `burst` beep (feature/greybox-1) |
| C-07 | S1 Controls | B = Wiggle: dance and chirp, nearby food hops toward you | built | `tests/test_worm_body.gd`; `--demo` | `wiggle` beep, notes (feature/greybox-1) |
| C-08 | S1 Controls | Start = Pause | partial | `test_lobby::test_pause_shows_menu_and_resume`; `.scratch/shots/pause/t002.0s.png` | Template pause works. Its "Restart" bar has no meaning on a persistent planet and must go or be renamed (see P-08) |
| C-09 | S1 Controls | Select = Restart (double press) | superseded | GAME.md:15 (S2) | Replaced by P-08. Template still restarts on Select: `Game.gd` `_unhandled_input` → `restart()` on the `restart` action |
| C-10 | S1 Controls | Eating is automatic on contact; there is no bite button | built | `tests/test_worm_body.gd` | (feature/greybox-1) |
| C-11 | S1 Controls (2026-11-10) | Hold X = gentle bite (carry; release to drop) | built | `tests/test_greybox_planet.gd::test_carried_home_becomes_a_trophy` | `p*_carry` (X; Q / .) (feature/greybox-1) |
| C-12 | S1 Controls (2026-11-10) | Hold B (Wiggle) 2 s = warp home to the burrow | built | `tests/test_greybox_planet.gd::test_hold_b_warps_home` | Fill ring round the head, `warp_charge` then `warp` (feature/greybox-1) |
| C-13 | S1 Controls (2026-11-10) | Y opens Old Reel's tackle box | partial | `scripts/worm/worm.gd` `tackle_pressed` | Y outside the burrow: placeholder `tackle_box` beep + pop; in the burrow: trait wall (feature/greybox-1) |
| C-14 | S1 Controls (2026-11-10) | In co-op the smaller worm's held-B warp goes to its partner when the partner is far | partial | `scripts/planet/planet_level.gd` `_on_warp_requested` | Partner > 420 px away and not bigger than me: warp goes to the partner. Untested (feature/greybox-1) |
| C-15 | S1 Co-op | Far worm gently pulled to the other by a "wormhole" tunnel | superseded | GAME.md:14, :44 (S2) | Replaced by P-07 (no forced movement). The wormhole stays only as the warp's look |
| C-16 | S1 Co-op | One or two worms; complete solo; a second worm drops in or out of any save at any time | built | `tests/test_lobby.gd::test_late_joiner_hatches_from_an_egg` | Join hatches at once; leaving keeps the worm in the tin (feature/greybox-1) |
| C-17 | S1 Co-op | Shared world: what one eats is gone for both; a big worm can eat walls a small one is stuck behind | partial | one PolarWorld per tin | Shared tiles; a big worm eats topsoil a small one cannot (feature/greybox-1) |
| C-18 | S1 Co-op | Shared-ish growth: full amount to the eater, a quarter to the partner; smaller worm always catches up | built | `tests/test_worm_body.gd::test_bite_grows_eater_fully_and_partner_by_a_quarter` | Tiles share too (feature/greybox-1) |
| C-19 | S1 Co-op | Worms can't eat each other: pass through with a boop and a heart particle | built | `tests/test_worm_body.gd` | (feature/greybox-1) |
| C-20 | S1 Co-op | No split screen in this game | built | `scripts/planet/planet_level.gd` | One PolarCamera (feature/greybox-1) |
| C-21 | S1 Co-op | Drop-in: second worm hatches from an egg next to the first at its size minus one stage | built | `tests/test_greybox_planet.gd::test_drop_in_hatches_next_to_the_first_at_its_stage_minus_one` | Egg wobbles 1.2 s, `egg_crack`, `hatch` (feature/greybox-1) |
| C-22 | S1 Players | Saves are bait tins: three tins on the dock rail, each a planet (family vs Kaden's solo, independent) | partial | `tests/test_greybox_planet.gd::test_each_tin_round_trips_on_its_own`; `handoff/shots/` | Placeholder dock with three tins after the lobby; dock art A-06 (feature/greybox-1) |
| C-23 | S1 Players / S2 Chooser | Launcher's two-face profile picker decides who is green; green/red slot follows it | partial | `Save.profile_from_args`; `test_smoke::test_profile_from_args_accepts_both_forms`; `test_smoke::test_players_colors_are_green_and_red` | Profile arg and colours exist. Worm must map them to the worm slots with the chooser hidden (P-17) |

## A Art

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| A-01 | S1 Art | Chunky 2D pixel art in the spirit of Super Mega Worm (thick outlines, few big colours, exaggerated faces, meaty chomps) plus real lighting, depth, atmosphere; vibe only, no copying | missing | ∅art | |
| A-02 | S1 Art | 2D lights and normal-mapped tiles: glow lights tunnels, crystals cast colour, daylight shafts through eaten holes | missing | ∅art | |
| A-03 | S1 Art | Three parallax layers behind the dirt in every ring; more in sky and space | missing | ∅art | |
| A-04 | S1 Art | Slow day/night cycle and rain up top | missing | ∅code | See G-06 |
| A-05 | S1 Art | The worm shows its history: diet stripes, trait parts, stage features, trophies in the mouth; two worms never look alike | missing | ∅art | |
| A-06 | S1 Art | The dock: one hand-finished background at dawn, noon, dusk, night; Old Reel and the grandson are the most carefully animated sprites | missing | ∅art | Title, save select and every cutscene live here |
| A-07 | S1 Art technique | 16 px tiles; segments 16 px at stage 1, sprite swap per stage (no stretching); multi-tile props; 4 to 6 frame anims; nearest-neighbour, integer zoom | partial | `docs/art-direction.md` "Life of a Worm" section | Rule recorded, no sprites yet. Check `project.godot` default texture filter is nearest when the first sprite lands |
| A-08 | S1 Art / S3 D87 | Palette: each ring its own dominant hue (dirt brown, rock grey-blue, core orange, topsoil green, sky blue, space navy); worms' green and red distinct on every ring | missing | ∅art; `docs/art-direction.md` (D87 options brief) | Waiting on the D87 options lane (P-33) |
| A-09 | S1 Players | P1 worm: green segments, lighter belly stripe, one big eye with a lid for expressions | missing | ∅art | |
| A-10 | S1 Players | P2 worm: red segments, darker stripe, two small eyes, a little cross-eyed | missing | ∅art | |
| A-11 | S1 Art | Mouth opens wide as food approaches; segments squash when boosting | missing | ∅art | |
| A-12 | S1 Art / S2 | Stage features: stage 3 tiny bow or cap, stage 5 monocle, stage 7 crown of stars; part of each stage's sprite set, not gear | missing | ∅art | |
| A-13 | S1 Art | Everything edible has a face that goes wide-eyed when a bigger worm nears; threats look smug | partial | `scripts/planet/apex_beetle.gd`, `scripts/arena/arena_food.gd` | Placeholder faces: apex smug as a threat, wide-eyed and sweating as food (feature/greybox-1) |
| A-14 | S1 Art | Juice: chomp particles in the food's colour, shake scaled to bite size, 2-frame white stage-up flash, debris falls to the core | missing | ∅code | |
| A-15 | S1 Art | Store grid: worm bursting through the surface with a cow in its mouth; hero: worm in space mid-bite on a planet | missing | `store/` holds only `.gitkeep` | |
| A-16 | S2 Launcher jar | `store/jar.glb`: tiny text-free 3D diorama, a dock on a bitten little planet with a worm curling out | missing | `store/` holds only `.gitkeep` | Store-art lane |
| A-17 | S1 Art | Heroes (two worms) may be hand-drawn by Kaden; everything else from the Art lane's prompt pack, cleaned in Aseprite | missing | `art/prompts/` holds only `.gitkeep` | |
| A-18 | S2 / S6 Characters 3D-first | The worms: bespoke Jarling-style 3D creature master, then a hand-cleaned 16 px pixel set; Kaden's own pixel art wins if he draws them | missing | ∅art | |
| A-19 | S2 / S6 | Bobber: new Jarling on the standard body (kid build), 3D master, then pixel form drawn over low-res renders | missing | not in `data/roster.json` or `assets/characters/` | Bible drafted at `~/openjar/worm-sprint/characters/bobber-bible.md` (lead) |
| A-20 | S2 / S6 | Old Reel and the Mole pixel forms for Worm derived from their 3D masters | partial | `assets/characters/old_reel/old_reel.glb`, `pixel.png` (template-synced) | Old Reel's master is vendored. Its `pixel.png` is the chooser sprite, not a Worm-scale form. Mole not vendored |
| A-21 | S1 Cutscenes | Cutscenes in in-engine pixel art with a handful of hand-finished key frames per scene | missing | ∅art | |

## U Audio

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| U-01 | S1 Audio | `chomp_1..5` by food size relative to you: crunch, munch, CRUNCH, gulp, planet-swallowing boom | partial | `scripts/autoload/grey_beep.gd` | Placeholder beeps; Audio lane drops `chomp_1..5.ogg` (feature/greybox-1) |
| U-02 | S1 Audio | `tunnel`: looped soft scrunch pitched by speed | partial | `Audio.loop_player("tunnel")` | Placeholder loop, fades with digging (feature/greybox-1) |
| U-03 | S1 Audio | `burst`: zip | partial | `grey_beep.gd` | Placeholder beep (feature/greybox-1) |
| U-04 | S1 Audio | `wiggle`: chirp and tiny maracas | partial | `grey_beep.gd` | Placeholder beep (feature/greybox-1) |
| U-05 | S1 Audio | `stage_up`: rising swell, bell, happy chirp | partial | `grey_beep.gd` | Placeholder arpeggio (feature/greybox-1) |
| U-06 | S1 Audio | `threat_near`: low rumble, one second of warning | partial | `scripts/planet/apex_beetle.gd` | Placeholder rumble when the apex notices a smaller worm (feature/greybox-1) |
| U-07 | S1 Audio | `eaten`: cartoon gulp, pop, dizzy stars jingle | partial | `grey_beep.gd` | Placeholder beep (feature/greybox-1) |
| U-08 | S1 Audio | `now_i_eat_you`: triumphant sting | partial | `tests/test_greybox_planet.gd::test_apex_bite_stages_up_and_pulls_the_camera_back` | Placeholder sting (feature/greybox-1) |
| U-09 | S1 Audio | `breakthrough`: crumbling, birds scatter | missing | ∅audio | |
| U-10 | S1 Audio | `planet_gone`: huge gulp, silence, tiny burp | missing | ∅audio | |
| U-11 | S1 Audio | `space_drift`: sparse synth ambience | missing | ∅audio | |
| U-12 | S1 Audio / S1 Inherited | Music: one theme in seven layers, one added per stage (ukulele in the dirt → brass band on the surface → cosmic pad in space) | partial | `scripts/autoload/Audio.gd` `music(track, fade)` | **Template has single-track crossfade only, no layer stacking** (GAME.md calls it "already built"). Layering must be built. No music files |
| U-13 | S1 Audio | Barks: worms chirp, never speak; each bug has one bark (mole's apology, bird's offended squawk) | partial | `Audio.bark()` in `Audio.gd` | Template bark plumbing exists. No worm or bug barks |
| U-14 | S1 Audio (2026-11-10) | Each ring gets its own ambience bed (dripping aquifer, humming crystals, wind) | missing | ∅audio | |
| U-15 | S1 Audio (2026-11-10) | Each trait adds a small signature sound to the worm, so a build can be heard | missing | ∅audio | |
| U-16 | S1 Audio (2026-11-10) | Dock theme: one guitar, water, gulls | missing | ∅audio | |
| U-17 | S2 Music | Music via ElevenLabs: one track first with its real cost, then the rest | missing | ∅audio | Paid service: report the cost to Gary before the rest |
| U-18 | S2 Voices | Old Reel's voice is his library voice, the take Kaden picks on Docket D85 | missing | `assets/characters/old_reel/` has no `voice/` | Waiting on D85 |
| U-19 | S2 Voices | Bobber's voice follows `references/voices.md` after his bible is approved | missing | no Bobber assets | Bible approved (D89), so this is unblocked |
| U-20 | Grey-box / CLAUDE.md 7 | Every action beeps (sound and visual on every input) | built | `Audio.played`; `scripts/autoload/grey_beep.gd`; grey-box tests | Every cue without a file plays a synthesized beep; list in `handoff/REPORT.md` (feature/greybox-1) |

## Y Story and cutscenes

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| Y-01 | S1 Story | Opening (~60 s, skippable): dawn dock, sandwich on the hook, "worms were small", two fingers apart, warm flashback, worm plops into the dirt, camera follows underground, "you have the stick" | missing | ∅code | In vertical slice (R-06) |
| Y-02 | S1 Story | Stage 2 "It got hungry": it ate everything smaller. Grandson: "so do I" | missing | ∅data | |
| Y-03 | S1 Story | Stage 3 "It started to change": a sketch of a worm with a stone head | missing | ∅data | |
| Y-04 | S1 Story | Stage 4 "It came up": Reel's shed vanishes into the ground behind him mid-sentence | missing | ∅data | |
| Y-05 | S1 Story | Stage 5 "Nobody fished that year": the town watches a hill get eaten; Reel delighted | missing | ∅data | |
| Y-06 | S1 Story | Stage 6 "The big one": "...ate everything." "Then where are WE sitting?" "...It's a long story." | missing | ∅data | |
| Y-07 | S1 Story | Ending "Still out there": night, grandson asleep, a bite out of the moon, long shape past the stars, Reel tips his hat | missing | ∅data | |
| Y-08 | S1 Story | One dock scene of 15 to 30 s per stage; hands wider each time, grandson less convinced, background quietly confirms | missing | ∅data | |
| Y-09 | S1 Story / Decided | What happened: Reel gives a different silly reason each time (comet, wife's chili, odd rock); the truth is Strangestone under the bait tin, never said aloud | missing | ∅art | Strangestone glows under the tin in the dock background |
| Y-10 | S1 Cutscene rules | Voiced, not written: Reel narrates (library voice), grandson has a few lines; subtitles off by default; gameplay text-free | missing | ∅code | |
| Y-11 | S1 Cutscene rules | Short, skippable with any button, rewatchable from the tackle box | missing | ∅code | |
| Y-12 | S1 Cutscene rules | Built with the cutscene tool from `openjar-addons`; scenes are data (shots, poses, PictoBubbles, voice clips) in `data/cutscenes/*.tres` | partial | `openjar-addons` v0.2.0: `cutscene/cutscene_player.gd`, `docs/cutscene-format.md` | Tool is tagged upstream. Not vendored here. No Worm scenes |
| Y-13 | S1 Decided / S3 D89 | Old Reel's bible bends to the dock scenes: narrator, "he never did catch it, and he's glad" | partial | `~/openjar/worm-sprint/characters/old_reel-worm-revision.md` (lead); D89 approved | Approved per GAME.md. I didn't confirm it landed in `openjar-characters` (no `old_reel/` in the local checkout) |
| Y-14 | S1 Decided / S3 D89 | The grandson is Bobber, a new Jarling; bible approved | partial | `~/openjar/worm-sprint/characters/bobber-bible.md` (lead) | D89 says "approved as drafted (`openjar-characters`)", but the local `openjar-characters/characters/` has no `bobber/`. See A-19 |
| Y-15 | S1 Decided | No Jarlings besides Old Reel, Bobber and the Mole at launch | partial | `data/roster.json` | Template roster vendors 21 chooser characters. Worm must keep them out of play (P-17) |
| Y-16 | S2 Show the cause | Every stage-up, trait, getting eaten, the breakthrough and the planet chomp shown with a camera beat; the big ones are dock cutscenes | partial | same as P-14 | (feature/greybox-1) |

## K Kid-design checks (on top of `docs/kid-design.md`)

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| K-01 | S1 Kid checks | Bigger-than-me is obvious at a glance (size on screen, not a number or colour code) | missing | ∅code | Reviewer checks with frames once creatures exist |
| K-02 | S1 Kid checks | Every threat telegraphs for at least one second | built | `tests/test_greybox_rules.gd::test_apex_telegraphs_a_second_then_eats_one_segment_never_a_stage` | 1.0 s wind-up (feature/greybox-1) |
| K-03 | S1 Kid checks / S2 Stale | Being eaten costs one segment, never a stage | built | `tests/test_greybox_rules.gd::test_apex_telegraphs_a_second_then_eats_one_segment_never_a_stage` | (feature/greybox-1) |
| K-04 | S1 Kid checks | Camera rotation is capped; no fast spins | built | `tests/test_greybox_rules.gd::test_camera_rotation_is_capped_and_zoom_is_whole_pixel` | (feature/greybox-1) |
| K-05 | S1 Kid checks | The smaller worm catches up within a minute via shared growth | missing | ∅tests | |
| K-06 | S1 Kid checks | A segment at least every 2 min of ordinary eating; something new at least every 15 | missing | ∅data | |
| K-07 | S1 Kid checks | Autosaves continuously; quitting at any moment loses nothing | built | `tests/test_greybox_planet.gd::test_quitting_at_any_moment_loses_nothing` | (feature/greybox-1) |
| K-08 | S1 Kid checks | Nothing in the dirt is dark or creepy; deep rings are colourful, not black | missing | ∅art | |
| K-09 | S1 Kid checks | Eating a house, cow or car is cartoon mayhem: squeaks and pops, nobody inside | missing | ∅art, ∅audio | |
| K-10 | S2 Template pieces | Gameplay stays text-free (menus may use real type) | partial | `scripts/planet/planet_hud.gd`; `handoff/shots/` | HUD is glyphs and pictures only; debug logs use names (feature/greybox-1) |

## P Producer notes and Kaden's answers (every line)

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| P-01 | S2 Where Worm stands | Gate: The Hill first playable, and its `tileworld`, `split_screen`, cutscene player and PictoBubble moved into `openjar-addons` and tagged (target v0.2.0) | built | `openjar-addons` tag `v0.2.0` → `b074b4c` "Merge PR #1 feature/extract-hill-engine"; tree has `tileworld/`, `split_screen/`, `cutscene/`, `picto_bubble/` | GAME.md still says "being built". Worm hasn't vendored it (see W-18) |
| P-02 | S2 Where Worm stands | Repo created only when Kaden says go | built | commit `886307a` (repo exists); D86 = go | |
| P-03 | S2 / S4 Priority | Spaceballs, Junk Yard Zap and the launcher go first; The Hill and Worm only fill free slots | built | GAME.md:10; D86 (GAME.md:38) runs Worm prototypes "in slots the priority games leave free" | Scheduling rule, in force |
| P-04 | S2 Template pieces | Ready-up start screen and main menu from the template | built | `tests/test_lobby.gd`; `handoff/shots/` | Podiums show Gulp and Burp (feature/greybox-1) |
| P-05 | S2 Template pieces | The bait-tin dock is the start screen's backdrop and the save select; template lobby on top | partial | `scenes/main.gd` `dock_texture`, `scripts/planet/dock.gd`; `handoff/shots/` | Placeholder dock still as the lobby backdrop; the tin select is a dock screen after ready-up (feature/greybox-1) |
| P-06 | S2 Template pieces | Pause menu with the big back-to-launcher icon | partial | `test_lobby::test_pause_door_asks_then_quits`; `.scratch/shots/pause/t002.0s.png` | "Back to Open Jar" bar present. "Restart" bar must go for a persistent planet |
| P-07 | S2 No forced movement | No auto-steer: camera zooms to fit both up to a cap; beyond it the far worm gets an edge arrow in its colour; held B warps to the partner; the wormhole is only the warp's look | partial | `scripts/planet/planet_hud.gd` edge arrows; `_on_warp_requested` | Zoom to fit up to the cap, edge arrow in the worm colour, held B to the partner (feature/greybox-1) |
| P-08 | S2 Select | Select does nothing alone; Select + Start held 2 s = solo; a stuck worm warps home with held B | built | `tests/test_lobby.gd::test_demo_skips_lobby` (`Game.select_restarts` off) | Select alone: nothing (in solo it hands the pad to the other worm) (feature/greybox-1) |
| P-09 | S2 Template pieces | Solo playtest mode (`--solo` or hold Select + Start 2 s; session-only) | partial | `scripts/planet/planet_level.gd` `_unhandled_input` | Solo spawns both worms; Select switches which one the pad drives. Untested (feature/greybox-1) |
| P-10 | S2 Template pieces | Drop-in from the template | built | `tests/test_lobby.gd::test_late_joiner_hatches_from_an_egg` | (feature/greybox-1) |
| P-11 | S2 Template pieces | Menus are for Kaden: real type, labels, glyphs are fine; gameplay text-free | partial | `test_lobby::test_lobby_menu_has_text_labels` | Menu side built. Gameplay side is K-10 |
| P-12 | S2 / S5 Buttons | Stick, A, B are the whole game for the kid; X carry, held-B warp, Y tackle box are the depth layer; no stick-only requirement | built | `project.godot` `p*_carry`, `p*_tackle`; HUD panel | (feature/greybox-1) |
| P-13 | S2 Buttons | Context hint panel with glyphs (near carryable food: X; in the burrow: Y) plus a blinking glyph over the worm when an interaction is ready | built | `scripts/planet/planet_hud.gd`, `ready_glyph.gd`; `handoff/shots/` | Rows: stick, A, B, hold B (home), X (near food), Y (box / wall in burrow); blinking X or Y over the head (feature/greybox-1) |
| P-14 | S2 Show the cause | Every stage-up, trait, getting eaten, breakthrough, chomp shown with a camera beat | partial | stage-up and eaten beats | Stage-up: flash, shake, pull back; eaten: shake, stars. Breakthrough and chomp later (feature/greybox-1) |
| P-15 | S2 Upgrades felt | Every trait changes something visible and audible; no hidden-number traits | missing | ∅code | Same as D-15 |
| P-16 | S2 Progress earned | Rings gated by stage and apex creature; stage 1 starts slow | partial | `tests/test_greybox_rules.gd::test_stage_up_needs_segments_and_the_apex` | Stage 2 gated by the dirt apex (feature/greybox-1) |
| P-17 | S2 Chooser | Template chooser hidden in Worm; green/red slot follows the launcher's profile pick | built | `scenes/main.gd` (`lobby.chooser = false`); `handoff/shots/` | Profile pick still picks the slot colour (feature/greybox-1) |
| P-18 | S2 Chooser / S6 | The two worms are library entries with `playable: false` | missing | not in `data/roster.json` | |
| P-19 | S2 Characters 3D-first | Bobber 3D master then pixel form; Old Reel and Mole pixel forms from masters; worms bespoke creature master then 16 px set | missing | see A-18, A-19, A-20 | |
| P-20 | S2 Stage features | Bow/cap, monocle, crown are part of each stage's sprite set, not equipment | missing | see A-12 | |
| P-21 | S2 Old Reel's role | In Worm he is the narrator of the tall tale; "he never did catch it, and he's glad"; revised bible draft | partial | see Y-13 | |
| P-22 | S2 Jarling cameos | Only Old Reel, Bobber and the Mole at launch; Bloom is the first cameo update | later | GAME.md:24 | See X-09, Y-15 |
| P-23 | S2 No personal info | Dock, pond, shed and town are invented and generic | missing | ∅data | Reviewer checks every prop and cutscene |
| P-24 | S2 Launcher jar | `store/jar.glb` diorama, made in the store-art lane | missing | see A-16 | |
| P-25 | S2 Music and voices | ElevenLabs music (one track first with its real cost); Reel's library voice (D85 take); Bobber's voice per `references/voices.md` | missing | see U-17, U-18, U-19 | |
| P-26 | S2 Physics tests | Physics tests stage their objects so outcomes never hinge on a chaotic pile (falling debris, cows rolling to the core) | missing | ∅tests | Rule for the R-01 and grey-box tests |
| P-27 | S2 Plan status | `PLAN-STATUS.md` with one row per brief line before the first lane; every lane updates its rows | built | this file | Lanes: update your rows in the same commit |
| P-28 | S2 Stale lines | BALANCE 20 to 30 min / 3 to 4 min per stage superseded by 2 to 4 h a stage, 15 to 25 h to the chomp, segment every 2 min, new thing every 15 | built | W-25 marked superseded; W-24 tracks the new target | Recorded here |
| P-29 | S2 Stale lines | "About a minute of eating" and "one segment shorter" agree; kid check "never a stage" stands | built | K-03 | Recorded. See REPORT for the 1 min vs 2 min wording |
| P-30 | S2 Stale lines | Split director stays an experiment; default is one shared rotating camera, decided by playtest | built | W-19 marked superseded; C-20 | Recorded |
| P-31 | S2 Stale lines | Open questions current except Bobber's bible is drafted | superseded | S3 answers D88, D89, D87 | All three S1 open questions are now answered or in progress: palette (D87), names (D88), Bobber (D89) |
| P-32 | S3 D86 | Create the repo now and run the two tile-free risk prototypes (traits on a segmented worm; stage-6 chomp + jar + cut to space) in free slots; polar-chunk prototype waits for addons v0.2.0 | partial | repo exists (`886307a`); R-02 and R-03 missing | Addons v0.2.0 is now tagged, so R-01 is unblocked too |
| P-33 | S3 D87 | Palette by options lane: three different looks, one lit and Terraria-like; Kaden picks or edits | missing | `docs/art-direction.md` "Life of a Worm" records the brief; ∅art | No final art before his pick |
| P-34 | S3 D88 | Gary proposes three name pairs for the green and red worms; Kaden picks | built | P-41 | Kaden picked on D90 |
| P-35 | S3 D89 | Bobber's bible and Old Reel's dock-scene revision approved as drafted | built | GAME.md:41 (decision recorded) | Follow-through (landing in `openjar-characters`) is tracked on Y-13 and Y-14 |
| P-36 | S2 Decision | Wormhole pull dropped; edge arrow + held-B warp instead | built | C-15 superseded; P-07 tracks the build | Decision recorded |
| P-37 | S2 Decision | Select restart dropped; Select + Start = solo | built | C-09 superseded; P-08 tracks the build | Decision recorded. Code still restarts on Select |
| P-38 | S2 Decision | Worms are bespoke avatars (library entries, not playable elsewhere), unless Kaden draws them | built | A-18, P-18 track the build | Decision recorded |
| P-39 | S2 Decision | Bloom is a cameo update, not a launch character | built | X-09 `later` | Decision recorded |
| P-40 | S2 Decision | Build order: addons extraction now; tile-free prototypes as soon as the repo exists; polar-chunk prototype waits for v0.2.0 | built | addons v0.2.0 tagged; repo exists | Both preconditions met. All three prototypes can start |
| P-41 | S3 D90 | Worm names: Gulp (green) and Burp (red) (D90) | built | `test_worm_names::test_worm_display_names_are_gulp_and_burp`; `handoff/frames/names.png` | Shown in menu labels (pause "BURP PAUSED", lobby ready/waiting lines) via `WormNames`/`UiStyle.player_name`. Gameplay has no name tags (text-free). Chooser podium plates still show the Roster pick (chooser off-limits; hidden in Worm per S2) Grey-box also names them in `scenes/main.gd` and `PlanetLevel.WORM_NAMES` (feature/greybox-1). |

## R Risk prototypes and build phases

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| R-01 | S1 Phase 1a | Polar chunks with regrowth and castings at 60 fps on a 1,000-tile disk | partial | R-a report; `tests/test_world_polar.gd`, `tests/test_world_regrowth.gd`; `scenes/levels/polar_stress.tscn` | Prototype built and measured on the software renderer. The GTX 1060 60 fps check is outstanding. Not tagged |
| R-02 | S1 Phase 1b / S3 D86 | Stage-6 chomp, jar snapshot and cross-fade to space | missing | ∅code | Tile-free, can start now |
| R-03 | S1 Phase 1c / S3 D86 | Segmented worm with five stacked traits and no special cases (`WormStats` resolver) | missing | ∅code | Tile-free, can start now |
| R-04 | S1 Phase 2 | Grey-box: one worm, the dirt ring, eat and carry, segments, one trait, a sleepable burrow, every action beeps | built | `handoff/REPORT.md` (feature/greybox-1); `--demo` | Grey-box playable from the launcher once tagged (feature/greybox-1) |
| R-05 | S1 Phase 0 | Design sprint: doc becomes GAME.md; palette; worm and grandson names; story beats and the Reel explanation approved; Reel's bible updated | partial | GAME.md (`886307a`); D89 | Done: GAME.md, grandson = Bobber, explanation decided, Reel bible approved. Open: palette (D87), worm names (D88) |
| R-06 | S1 Phase 3 | Vertical slice `v0.1.0`: stages 1 and 2 at final quality (opening cutscene, dirt + topsoil with food chain, three traits, castings and one garden, burrow with trophies and a pet, ant city, tackle box, Mole's swap shop); Kaden plays alone for an evening and with his son for an afternoon | missing | ∅code | First playable is this slice, not a thin run through all seven stages |
| R-07 | S1 Phase 4 | Ring by ring, each a playable chapter with its cutscene: rock, core, surface, sky (`v0.2` to `v0.5`) | missing | ∅code | |
| R-08 | S1 Phase 5 | Stage 6, the jar, space with five planet types, ending cutscene, new tin with heirloom (`v0.6`) | missing | ∅code | |
| R-09 | S1 Phase 6 | Beauty pass: lighting, parallax, weather, ambience beds, the dock, store art, 1060 performance (`v0.9`) | missing | ∅code | |
| R-10 | S1 Phase 7 | Release on the TV main tile (`v1.0.0`) | missing | no tags | |
| R-11 | S1 Phases | If premium-model budget is available, spend it on the trait resolver, polar chunk design, story script and cutscene direction, and light/dock art direction | later | GAME.md "Build phases" | Applies when R-01, R-03 and the story work are assigned |

## Next up

Phase-1 risk prototypes first, then the grey-box, then the rest of the missing and partial rows, ranked by
how much Kaden will notice them in play. Sizes: S ≤ a session, M a few sessions, L a milestone.

1. **R-03** Segmented worm with five stacked traits through one `WormStats` resolver (D-01, D-02, D-14). Tile-free. **M**
2. **R-02** Stage-6 chomp: render-to-texture, shader-mask bite, jar snapshot, cross-fade to space (S-10, S-16). Tile-free. **M**
3. **R-01** Polar chunks + regrowth + castings at 60 fps on a 1,000-tile disk. Vendor `openjar-addons` v0.2.0 first (W-18). **L**
4. **R-04** Grey-box: worm head + segments (C-05, S-04), eat on contact (S-05, C-10), X carry (C-11, B-01), one trait, sleepable burrow (B-02), every action beeps (U-20), plus the Worm contracts doc PR (W-27, W-28). **L**
5. **P-08 / C-09** Unbind Select-alone restart and drop the pause "Restart" bar (P-06). A stray Select restarting a long planet is the first thing he'd notice. **S**
6. **P-17** Hide the template chooser and spawn worms by slot (Jeff and Chuck podiums show today). **S**
7. **P-33 / A-08** Palette options lane (three looks, one lit Terraria-like), so real art can start. **M**
8. **C-01 to C-03, P-07** Shared rotating camera with capped spin, fit-both zoom, edge arrow, held-B warp (C-12, C-14). **M**
9. **S-03 / A-14 / U-05** Stage-up moment: swell, shake, flash, pull-back, `stage_up` cue. **M**
10. **L-04, L-14, L-15** Bigger-eats-smaller, 1 s telegraph, funny eaten-and-spat-out (K-01 to K-03). **M**
11. **U-01, U-02** Chomp variants and the tunnel loop: "the chomp is the game". **S**
12. **A-09 to A-11, A-18, P-34** The two worms: names (D88), creature master, 16 px sets, mouth and squash. **L**
13. **P-05, C-22, A-06** Dock start screen with three bait tins as save slots. **M**
14. **W-21, W-22, K-07** Planet save per tin, 30 s autosave plus on pause and sleep. **M**
15. **C-16, C-21, P-10** Mid-planet drop-in hatching from an egg; solo pad drives worm 2 (P-09). **M**
16. **U-12** Layered music (template has single-track only), dirt-ring layer first; ElevenLabs cost first (U-17). **M**
17. **Y-01, Y-12** Opening dock cutscene on the addons cutscene tool; Old Reel voice after D85 (U-18). **L**
18. **P-13** In-game context hint panel and the blinking glyph over the worm. **S**
19. **D-03 to D-13, G-01 to G-04, B-03 to B-06, T-01 to T-03, X-02, X-07** Vertical-slice depth: three traits, castings and a garden, trophies and a pet, tackle box, ant city, swap shop (R-06). **L**
20. **A-19, U-19** Bobber's 3D master, pixel form and voice. **M**
