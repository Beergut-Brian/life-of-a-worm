# Kid check: every system against the kid test (S-20)

GAME.md "Two depths": the kid's layer is actions (move, A to burst, eat); Kaden's layer is
consequences (traits, the burrow, the shop, the book). This page asks four questions of every
system in the game. The Reviewer re-checks a row whenever a PR touches that system, and adds a
row for every new system.

- **Act**: every input the kid makes does something, with a sound and a visual; at most three
  buttons matter, and the rest are harmless.
- **Seen**: whenever the system changes play, the kid can see why. There is no hidden state.
- **Chomp**: the kid can reach stage 6 and the planet chomp by moving and eating alone. Nothing
  from Kaden's layer is required.
- **Kind**: nothing takes away earned progress (stage, traits, slots). There is no fail state, no
  countdown, no forced movement, and nothing dark or scary.

"yes (decided)" means the behaviour looks like a "no" at first, but GAME.md already decided it
(cited) and it passes the kid test as written. Every "no" names its file and line. **Fixed** means
this branch fixed it. **Note** means it is left for the owner because the fix is bigger than data
or one line, or is a design call.

Audited 2026-11-13 on `feature/worm-gap-close-25` (dev at 0dfd962 + X-08). Two related guardrails
were written as tests on local `feature/worm-gap-close-6` but are not on dev:
`tests/test_kaden_layer_optional.gd` (the chomp is reachable with every trait off) and
`tests/test_kid_novelty.gd`.

## Table

| # | System | Main files | Act | Seen | Chomp | Kind | Passes? |
|---|---|---|---|---|---|---|---|
| 1 | Movement and burst | `scripts/worm/worm.gd`, `pull_drag.gd`, `worm_rules.gd` | yes (N1 fixed) | yes | yes | yes | fixed |
| 2 | Digging | `scripts/world/polar_world.gd`, `world_destruct.gd`, `loose_fall.gd`, `surface_prop.gd`, `disk_edge.gd`, `scripts/gameplay/crust_burst.gd` | yes | yes | yes | yes | yes |
| 3 | Eating and growth | `scripts/creatures/gulp.gd`, `scripts/worm/worm_growth.gd`, `food_voice.gd`, `scripts/rings/ring_pickup.gd`, `scripts/worm/juice.gd` | yes | yes | yes | yes (decided) | yes |
| 4 | Stages and apexes | `scripts/worm/stage_table.gd`, `scripts/planet/apex_beetle.gd`, `apex_call.gd`, `scripts/gameplay/stage_beat.gd`, `stage_why.gd` | yes | yes | yes | yes (decided) | yes |
| 5 | Traits and the trait wall | `scripts/worm/trait_wall.gd`, `star_traits.gd`, `scripts/traits/*.gd`, `scripts/gameplay/trait_beat.gd`, `trait_why.gd`, `scripts/burrow/burrow.gd` | no (N2) | yes | yes | yes | note |
| 6 | Castings and gardens | `scripts/worm/castings_hook.gd`, `scripts/world/castings_trail.gd`, `scripts/rings/castings_sprouts.gd`, `topsoil_dressing.gd` | yes | yes | yes | yes | yes |
| 7 | Co-op: shared growth and catch-up | `scripts/worm/worm.gd`, `worm_growth.gd`, `scripts/planet/planet_level.gd` | yes | yes (N3 fixed) | yes | yes | fixed |
| 8 | Creatures and threats | `scripts/creatures/*.gd`, `scripts/gameplay/eaten_beat.gd` | yes | yes | yes | yes (decided) | yes |
| 9 | Living rings and regrowth | `scripts/rings/ring_ecology.gd`, `population_rule.gd`, `rings_director.gd` | yes | yes (N4 fixed) | yes | yes | fixed |
| 10 | Secrets and cameo spots | `scripts/rings/secret_spot.gd`, `secret_halls.gd`, `secret_look.gd`, `cameo_stands.gd` | yes | yes | yes | yes | yes |
| 11 | Sky: balloon and flocks | `scripts/rings/sky_balloon.gd`, `sky_flock.gd` | yes | yes | yes | yes | yes |
| 12 | Pets | `scripts/pets/*.gd`, `scripts/burrow/burrow.gd` | yes | no (N5) | yes | yes | note |
| 13 | The Mole and the swap shop | `scripts/swap_shop/swap_shop.gd`, `mole_visit.gd`, `mole_look.gd` | yes | no (F1) | yes | yes | **fixed** |
| 14 | Burrow, carrying, trophies | `scripts/burrow/*.gd`, carry in `scripts/worm/worm.gd` | yes | yes | yes | yes | yes |
| 15 | Lighting and ambience | `scripts/lighting/*.gd`, `scripts/audio/ring_ambience.gd` | yes | yes | yes | yes | yes |
| 16 | Saves and bait tins | `scripts/autoload/Save.gd`, `scripts/planet/bait_tins.gd`, autosave in `planet_level.gd` | yes | no (N6) | yes | yes | note |
| 17 | The dock, story and opening | `scripts/planet/dock.gd`, `scripts/story/*.gd`, `worm_egg.gd`, `worm_podium.gd` | yes | yes | yes | yes | yes |
| 18 | Planet chomp and jars | `scripts/chomp/*.gd`, `scripts/jars/*.gd` | yes | no (N7) | yes | no (N8) | note |
| 19 | Space | `scripts/space/*.gd` | yes | yes | yes | yes (decided) | yes |
| 20 | Tackle box and the book | `scripts/tackle/*.gd`, `scripts/ui/book*.gd` | yes | yes | yes | yes | yes |
| 21 | Players, drop-in, co-op camera | `scripts/autoload/Players.gd`, `solo_marker.gd`, `scripts/planet/far_camera.gd`, `scripts/world/polar_camera.gd`, `scenes/main.gd` | no (N9) | yes | yes | yes (decided) | note |
| 22 | HUD, pause and menus | `scripts/planet/planet_hud.gd`, `scenes/ui/` | yes | yes | yes | yes | yes |
| 23 | Debug and test-only paths | `scripts/planet/greybox_demo.gd`, `scripts/arena/*.gd`, `scripts/autoload/Debug.gd` | yes | yes | yes | yes | yes |

## Each "no"

**F1 (fixed): the Mole took a carried creature.** At `scripts/swap_shop/swap_shop.gd:137`,
`can_trade` turned away only pets and seeds, which contradicts its own comment (line 131) and
GAME.md ("carry anything except a seed or a creature"). Trading a creature called
`Creature.take()`, which plays that creature's one-time "now I eat you" sting and grin close-up
(`scripts/creatures/creature.gd:389-392`) on a trade instead of on a bite. The one-line fix adds
`or c is Creature`. `tests/test_swap_shop.gd::test_seeds_and_creatures_are_not_for_swapping` now
also checks a carried creature; it is red without the fix.

**N1 (note): pressing A while the burst recharges does nothing.** At `scripts/worm/worm.gd:446`
(`if intent.burst and _burst_cool <= 0.0:`), a press during the cooldown plays no sound and shows
no visual. This breaks "every input plays a sound". The fix needs an `else` branch with its own
quiet cue and a small puff, and the cue needs an Audio-lane file, so it is more than one line.
Owner: Systems (worm).
**Fixed (worm-gap-close-30):** `BurstNudge` (`scripts/gameplay/burst_nudge.gd`, a child of
`scenes/players/worm.tscn`, so worm.gd is untouched): a press during the recharge puffs three dust
specks behind the head, plays the burst cue small and high on its own quiet player (no new sound
file), and shows a ring round the head that fills as the burst comes back. At most one every
0.12 s; never while the trait wall has the buttons. `tests/test_kid_feedback.gd` (5 cases);
`handoff/frames/c06-burst-nudge-ring*.png`.

**N2 (note): sleeping can open the trait wall and freeze the worm.** Holding still for 2 s in any
open hollow puts the worm to sleep (`scripts/planet/planet_level.gd:391-392`). If a trait is
waiting for a slot, sleep opens the wall by itself (`scripts/burrow/burrow.gd:129-132`). While the
wall is open, the stick does not move the worm (`scripts/worm/worm.gd:436-437`), A toggles traits
(`scripts/worm/trait_wall.gd:39-41`), and only B or Y lets go. The auto-open is decided
(GAME.md 2026-11-11 slice-burrow-1: "a newly earned trait waiting for a slot opens the wall by
itself"), so changing it is Gary's or Kaden's call. Options: open it only in the home bed, or let
any stick push close it.

**N3 (note): the partner's growth from dug tiles shows no cause.** Each tile one worm eats also
grows the other (`scripts/worm/worm.gd:231-233`,
`w.model.add_growth(g * rules.partner_share, &"")`). Food bites show the share as a star
(`worm.gd:388-390`), but tiles do not, so the partner's segments can pop for no visible reason.
The fix calls `receive_share()` there with a throttle so a tunnel does not throw a star per tile.
That is several lines in `worm.gd`. Owner: Systems (worm).
**Fixed (worm-gap-close-30):** `PartnerStars` (`scripts/gameplay/partner_stars.gd`, a worm.tscn
child) floats the same share star off this worm's head while another worm digs, at most one every
0.6 s, so a tunnel is a steady twinkle. Digging by anything that is not a worm shows nothing.
`tests/test_kid_feedback.gd` (2 cases); `handoff/frames/c18-partner-star*.png`.

**N4 (note): ground regrows in play with no sparkle or sound.** `RegrowSparkles` and the
`world_regrow` cue are wired only in the disk test level (`scripts/world/disk_level.gd:67-71`,
`:89`), not in `scripts/planet/planet_level.gd`. Regrowth on the real planet is silent (only Green
thumb leaves show, `scripts/rings/rings_director.gd:445`). This is harmless, because the kid just
eats through it. The fix is a few lines in `planet_level.gd`, which other in-flight branches are
editing (gap-close-3/4/8), so it is left for the planet owner.
**Fixed (worm-gap-close-30):** without touching `planet_level.gd`: `CastingsHook` (a worm.tscn child)
now also makes one `RegrowWatch` per world (`scripts/world/regrow_watch.gd`), which twinkles
(`RegrowSparkles`) where ground grows back or a garden cell fills and, near a worm, plays
`world_regrow` / `world_sprout` once per 0.4 s (a regrowth pass is one soft sound).
`tests/test_kid_feedback.gd` (3 cases); `handoff/frames/g04-regrow-sparkles*.png` (staged: 15 cells
grown round the worm).

**N5 (note): a second pet of a kind vanishes quietly.** If home already has that kind of pet, a
carried one is taken (`scripts/burrow/burrow.gd:203-210`, then `:218` `food.call("take")`). Only
the resident pet's hello shows. Nothing shows the newcomer "back to the wild", as the comment
says. The fix needs a small run-off animation (Gameplay plus Art), so it is more than one line.

**N6 (note): a damaged or unwritable tin is silent.** At `scripts/autoload/Save.gd:130`
(`_data = parsed if parsed is Dictionary else {}`), a corrupt file reads as empty. The dock then
shows that tin as a new planet (`scripts/planet/bait_tins.gd:32-33` returns `{}`, `scripts/planet/dock.gd:102` labels it "New planet"), and the next autosave
writes over it. A failed write only logs a warning (`Save.gd:57`). This is rare, but it is the one
place play can lose progress unseen. The fix (keep the unreadable file as `.bak`, show the tin as
damaged) is a few lines in a Systems autoload.

**N7 (note): a jar failure says "yes" and then does nothing.** `scripts/chomp/planet_chomp.gd:240-245`
plays `confirm_yes` before it tries `jars.snapshot()`. If that fails, the ring quietly resets with
only a `push_warning`. The fix moves the yes cue after the check and plays a bonk or cancel with a
jar shake on failure. That is a few lines. Owner: Chomp.

**N8 (note): a chomped planet cannot be visited again yet.** After the chomp, the tin reopens in
space (`scripts/chomp/chomp_director.gd:35-36,162`). Nothing in play opens a jar
(`scripts/jars/jar_open_view.gd` is used only by its demo scene). The jar keeps everything, so
nothing is deleted, but the kid cannot get back to their burrow and trophies. PLAN-STATUS S-10
already tracks this (the jar shelf on the dock), so it is a bigger build.

**N9 (note): a pad that disconnects removes its worm with no sound or picture.** At
`scripts/planet/planet_level.gd:338-347` (`remove_worm`, called from `scenes/main.gd`), the worm is
simply freed. The fix is a cue plus a puff: one or two lines, but in `planet_level.gd`, which other
branches are editing (see N4). Owner: Systems.

## Checked and passed (looked like a "no")

- **Eaten costs one segment and moves the worm** (`scripts/creatures/gulp.gd:26`,
  `scripts/worm/worm.gd:403`): this is decided in GAME.md (no fail state; getting eaten costs a
  segment, never a stage, S-13 and L-15). The cause is shown: the worm drawn inside the eater, the
  camera on it, and a star pop (`scripts/gameplay/eaten_beat.gd:61-75`).
- **Apexes hunt a smaller worm** (`scripts/planet/apex_beetle.gd:99-103`): decided, with a
  telegraph and a 1 s wind-up first. It costs one segment, never a stage.
- **Lava blob bounce, lawnmower bump, space planet knock** (`scripts/creatures/creature.gd:314`,
  `scripts/creatures/lawnmower.gd:257`, `scripts/space/space_stage.gd:199`): decided in GAME.md
  (Rings table "bounce you, no damage", Creatures table "bumps you", 2026-11-11 proto R-b "a
  physical bounce, not steering"). The worm keeps steering, and a boing shows each one. The
  strength is data (`data/creatures/lava_blob.tres` `bounce`, `lawnmower.tres` `bump`,
  `data/rings/space_life.tres` `bump_speed`) if a playtest says it is too much.
- **Bonk on food that is too big** shoves the head back 6 px (`scripts/worm/worm.gd:583`). It
  comes with the bonk cue, a pop and the food's smug face, and it is not steering.
- **The co-op camera follows the bigger worm past its zoom cap** (`scripts/planet/far_camera.gd:62-72`).
  This is decided (GAME.md "No forced movement": the edge arrow plus held-B warp replaced the
  wormhole pull). Not every 5-year-old will find held-B on their own, which is worth watching in
  the next playtest.
- **Y opens the tackle box anywhere** (`scripts/worm/worm.gd:428-431`). It is Kaden's button
  (decided, slice-burrow-1): it has a sound and a picture, pauses both players, and B or Y closes
  it, so it is harmless to the kid.
- **The chomp hold** is 2.0 s on either player's A (`scripts/chomp/hold_confirm.gd:10`) and drains
  slowly. It is reachable by the kid alone. Lowering it is one line if a playtest says it is too
  long.
- **Restart** is one press and asks nothing (`scenes/ui/pause_menu.gd:88-90`). The tin is saved
  on pause, so nothing is lost.
- **Creature despawn** happens only beyond 900 px (`scripts/rings/rings_director.gd:50`). At high
  stage zoom one might vanish on screen. This was not confirmed; check it in frames when the
  creatures lane next touches it.
