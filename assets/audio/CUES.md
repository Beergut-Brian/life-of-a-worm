# Audio cues

Every file in `assets/audio/sfx/` is made by `scripts/tools/make_cues.py` (seeded synthesis, Python
stdlib + ffmpeg, Ogg Vorbis q5 44.1 kHz mono, -16 LUFS minus a per-cue trim, true peak <= -1 dBTP).
Regenerate with `python3 scripts/tools/make_cues.py --table .scratch/loudness.md`. `Audio.play("x")`
plays `sfx/x.ogg`, or one of `sfx/x_1.ogg..x_N.ogg` at random. `tests/test_worm_audio.gd` reads every
cue name from the code and fails if one has no file or anything plays a placeholder beep.

Kid rules: friendly, never a scare, no pain sounds, no minor stingers; `stage_up` is the loudest cue.

| Cue (`Audio.play`) | Plays when | Feel | File(s) in `sfx/` |
| --- | --- | --- | --- |
| **GAME.md cue table** | | | |
| `chomp_1` | `Worm.feed()` (`scripts/worm/worm.gd`), food 2+ stages smaller than you | crisp little crunch | chomp_1_1.ogg, chomp_1_2.ogg, chomp_1_3.ogg |
| `chomp_2` | `Worm.feed()`, food one stage smaller | munch-munch | chomp_2_1.ogg, chomp_2_2.ogg, chomp_2_3.ogg |
| `chomp_3` | `Worm.feed()`, food your size | a big CRUNCH | chomp_3_1.ogg, chomp_3_2.ogg, chomp_3_3.ogg |
| `chomp_4` | `Worm.feed()`, food one stage bigger | bite, then a cartoon gulp and a bloop | chomp_4.ogg |
| `chomp_5` | `Worm.feed()`, food 2+ stages bigger | planet-swallowing boom, with stars | chomp_5.ogg |
| `tunnel` | `Audio.loop_player("tunnel")` in `planet_level.gd`, pitched by speed, fades with digging | soft scrunch, 2 s seamless loop | tunnel.ogg |
| `burst` | `worm.gd` boost | zip: slide whistle up through a whoosh | burst.ogg |
| `wiggle` | `Worm._wiggle()` dance | two worm chirps and tiny maracas | wiggle.ogg |
| `stage_up` | `Worm._on_stage_changed()` | rising swell, C-major arpeggio, bell chord, happiest chirp. **The loudest cue in the game** (checked by the tool) | stage_up.ogg |
| `threat_near` | `creature.gd` / `apex_beetle.gd` when a bigger bug notices you | one second of soft low rumble and a rising tuba 'bom... bom?'; a question, never a scare | threat_near.ogg |
| `eaten` | `worm.gd` gulped by a bug | cartoon gulp, pop out the other end, dizzy-stars jingle. No pain sound | eaten.ogg |
| `now_i_eat_you` | `planet_level.gd` first bite of a former threat | ta-ta-TAAA brass fanfare and a grin-chirp | now_i_eat_you.ogg |
| `breakthrough` | **no call site yet** (crust broken at stage 4; see REPORT Needs other lanes) | crumble, then birds scatter: flutters and tweets | breakthrough.ogg |
| `planet_gone` | `PlanetChomp` final chomp (`scripts/chomp/planet_chomp.gd`, via ProtoSfx) | huge gulp, real silence, tiny burp at exactly 2.2 s (`BURP_AT`) | planet_gone.ogg |
| `space_drift` | **no call site yet** (stage 7 ambience; Needs other lanes) | sparse synth: open C-G pad breathing, far bell pings. 16 s loop | space_drift.ogg |
| **Ring ambience beds** (16 s seamless loops, quiet; no hook yet, see REPORT) | | | |
| `amb_dirt` | camera in the dirt ring | warm hush, slow drips with a little cave echo | amb_dirt.ogg |
| `amb_topsoil` | topsoil ring | breeze through the roots, the odd far cricket | amb_topsoil.ogg |
| `amb_deep_rock` | deep rock ring | humming crystals, slowly beating, rare glassy ping | amb_deep_rock.ogg |
| `amb_core` | core ring | warm low glow, lazy lava bubbles | amb_core.ogg |
| `amb_surface` | surface ring | wind in gusts, far-away birds | amb_surface.ogg |
| **The worm** | | | |
| `carry` | `worm.gd` X picks something up | bloop up and a wood tick | carry.ogg |
| `drop` | `worm.gd` X puts it down | bloop down and a soft pat | drop.ogg |
| `bonk` | `worm.gd`, `planet_level.gd`, tackle box, book, trait wall: can't do that | hollow wood knock, spring, twinkles | bonk.ogg |
| `boop` | `worm.gd` two worms pass through each other; book / tackle box on an unseen entry | soft round boop-boop and a heart's ting | boop.ogg |
| `segment_pop` | `Worm._on_segment_added()` | small pop and a xylophone note | segment_pop.ogg |
| `hatch` | `Worm.hatch()` drop-in | shell crack, unfold pop, tiny 'hi!' chirp | hatch.ogg |
| `egg_crack` | `worm_egg.gd` P2's egg cracking | two little cracks | egg_crack.ogg |
| `warp` | `Worm.warp_to()` wormhole pull / B home | swirl rising, pop and sparkle | warp.ogg |
| `warp_charge` | `worm.gd` holding B to warp home | rising, wobbling hum, 0.5 s | warp_charge.ogg |
| `tackle_box` | `worm.gd` the worm opens the tackle box | latch clack, lures rattle, a ding | tackle_box.ogg |
| `wall_open` / `wall_close` | `worm.gd` trait wall shown / hidden | xylophone run up / down with a swish | wall_open.ogg, wall_close.ogg |
| `trait_swap` | `Worm._on_traits_changed()` | fwip-fwip and a click | trait_swap.ogg |
| `trait_drill_head` | `Worm._on_trait_earned()` (TraitData.cue) | drill whirr, then the earned bell (C6-G6) | trait_drill_head.ogg |
| `trait_glow` | trait earned | shimmering bell chord and sparkles, earned bell | trait_glow.ogg |
| `trait_green_thumb` | trait earned | leafy rustle, sprout pluck, earned bell | trait_green_thumb.ogg |
| `trait_magnet` | trait earned | magnetic vwoom and a clink, earned bell | trait_magnet.ogg |
| `trait_slick` | trait earned | slippery fwee and bubbles, earned bell | trait_slick.ogg |
| `trait_stone_head` | trait earned | stone clonk, earned bell | trait_stone_head.ogg |
| `trait_wriggle` | trait earned | wobbly kazoo, chirp, maracas, earned bell | trait_wriggle.ogg |
| `trait_floaty` / `trait_skater` / `trait_garden_cart` | trait earned (hybrids from stages-traits) | cloud puff floating up / blade swish / wheel squeak, rattle and a sprout; each ends on the earned bell | trait_floaty.ogg, trait_skater.ogg, trait_garden_cart.ogg |
| `ring_open` | `scripts/gameplay/stage_beat.gd` a new ring opens after a stage-up | wide shimmering whoomp, bell chord, sparkles | ring_open.ogg |
| `solo_focus` | `planet_level.gd` camera focuses one worm | small swish and a ding | solo_focus.ogg |
| **Burrow, pets, garden, swap shop** | | | |
| `sleep` | `burrow.gd` into bed | lullaby E-D-C and two sleepy breaths | sleep.ogg |
| `burrow_grow` | `burrow.gd` the room grows after a stage-up | soft dig-out rumble, rising marimba | burrow_grow.ogg |
| `home_seed` / `home_trophy` | `burrow.gd` a seed / trophy put down at home | pat and a two-note pip / marimba and bells | home_seed.ogg, home_trophy.ogg |
| `pet_home` / `pet_away` / `pet_fetch` | `burrow.gd` / `pet.gd` ladybird arrives, flies off, fetches | wing buzz with a happy two-note / buzz fading away / buzz, pop, ta-da | pet_home.ogg, pet_away.ogg, pet_fetch.ogg |
| `pet_meet` / `pet_hello` | `Pet.meet()` first of a kind / `burrow.gd` a kind at its cap says hello | buzz, 'hello!' chirp, heart twinkle / two-note hi | pet_meet.ogg, pet_hello.ogg |
| `pet_walk` / `pet_tend` / `pet_lamp` | `pet.gd` the ant crew trots / nudges a seed bed; the glow-worm lights up | tiny tip-tap feet (quiet, it repeats) / rustle and a growing pip / warm plink and hum | pet_walk.ogg, pet_tend.ogg, pet_lamp.ogg |
| `garden_plant` | `rings_director.gd` a seed planted | pat-pat and a sprout | garden_plant.ogg |
| `secret_found` | `RingsDirector.discover()` (SecretData.cue) | sparkle glissando, bell chord, wow-chirp | secret_found.ogg |
| `mole_pop` / `mole_hide` | `swap_shop.gd` the Mole pops out / hides | dirt and a pop / a dive and a pat | mole_pop.ogg, mole_hide.ogg |
| `mole_sorry` | `swap_shop.gd` the Mole can't take that | sheepish wordless 'oh-dear' hum (not his library voice) | mole_sorry.ogg |
| `swap` | `swap_shop.gd` a trade | counter knock and a ta-ding | swap.ogg |
| **Creatures** (one bark each, from `data/creatures/*.tres`) | | | |
| `grub_squeak` / `ant_hup` / `beetle_blink` / `rock_beetle_clack` / `lava_blob_blorp` | `creature.gd` bark | rubber squeak / tiny 'hup!' / glassy blink / stone clack-clack / bubbly blorp | grub_squeak.ogg, ant_hup.ogg, beetle_blink.ogg, rock_beetle_clack.ogg, lava_blob_blorp.ogg |
| `bird_tweet` / `boot_rumble` | `bird.gd` / `boot_shadow.gd` bark | two-note tweet / two soft far thuds | bird_tweet.ogg, boot_rumble.ogg |
| `beetle_windup` / `rock_beetle_windup` / `lava_blob_swell` / `bird_peck` | `creature.gd`, `apex_beetle.gd`, `bird.gd` windup (CreatureData.windup_cue) | ratchet and slide whistle / grinding ratchet / swelling bubbles / peck-peck | beetle_windup.ogg, rock_beetle_windup.ogg, lava_blob_swell.ogg, bird_peck.ogg |
| `beetle_lunge` | `creature.gd` / `apex_beetle.gd` the lunge | whoosh and a clack | beetle_lunge.ogg |
| `creature_munch` | `creature.gd` a creature eats something | small low munch | creature_munch.ogg |
| `bird_gulp` / `boing` / `bird_offended` | `bird.gd` the bird swallows / a worm springs off / the bird is offended | gulp / spring boing / huffy 'hmph-awk' | bird_gulp.ogg, boing.ogg, bird_offended.ogg |
| **Tackle box and book** | | | |
| `box_open` / `box_close` | `tackle_box.gd` | latch, lid up, lures / lid down, clack | box_open.ogg, box_close.ogg |
| `box_flip` / `box_tick` / `box_play` | `tackle_box.gd` page turn / found entry / replay a cutscene | page swish / xylophone tick / projector click and chime | box_flip.ogg, box_tick.ogg, box_play.ogg |
| `box_why` | `tackle_box.gd` the box opens on the page that explains what just happened | curious 'look!' run and chirp | box_why.ogg |
| `page_new` / `lure_pin` | `tackle_log.gd` a new page / a lure pinned | page in and ding-ding / metal tink | page_new.ogg, lure_pin.ogg |
| `book_open` / `book_close` / `book_flip` / `book_look` / `book_tick` | `scripts/ui/book.gd` | paper and a thump / page swish / 'ooh' ding / tick | book_open.ogg, book_close.ogg, book_flip.ogg, book_look.ogg, book_tick.ogg |
| **Planet chomp, space, polar world** (ProtoSfx / WorldSfx play these through Audio once a file exists) | | | |
| `chomp_bite` | `planet_chomp.gd` each bite of the long chomp | deep crunch | chomp_bite.ogg |
| `confirm_hold` / `confirm_cancel` / `confirm_yes` | `planet_chomp.gd` hold A, let go, confirmed | short rising hum / falling boop / two-note chime | confirm_hold.ogg, confirm_cancel.ogg, confirm_yes.ogg |
| `jar_clink` | `jar_view.gd` the planet lands in its jar | glass ting | jar_clink.ogg |
| `space_bite` / `space_bump` | `space.gd` eat a small planet / bump a big one | munch with a sparkle / soft boing | space_bite.ogg, space_bump.ogg |
| `world_munch` / `world_seed` / `world_blocked` / `world_regrow` / `world_sprout` | `disk_level.gd`, `standin_eater.gd` | tiny dry munch / pip / dull tok / soft rustle up / sprout pip | world_munch.ogg, world_seed.ogg, world_blocked.ogg, world_regrow.ogg, world_sprout.ogg |
| **Template cues** | | | |
| `round_start` / `round_end` / `pause` | `Game.gd` | marimba run up / down, two-note pause | round_start.ogg, round_end.ogg, pause.ogg |
| `solo_on` / `solo_off` | `Players.gd` | octave up / down | solo_on.ogg, solo_off.ogg |
| `jump` / `action` | `scenes/players/player.gd` (template player) | chirp up / tick | jump.ogg, action.ogg |
| `ui_move` / `ui_confirm` / `player_join` | trait wall, `Players.gd` | no file on purpose: the shared UiSound menu kit's designed synth (GreyBeep hands them over) | (UiSound) |

## Measured loudness (last build)

Short cues (< 0.6 s) are measured looped 10x ("as loud as the rest while it sounds").

| file | kind | seconds | LUFS (active) | true peak dBTP |
| --- | --- | --- | --- | --- |
| chomp_1_1.ogg | sfx | 0.22 | -20.3 | -7.6 |
| chomp_2_1.ogg | sfx | 0.45 | -18.8 | -5.2 |
| chomp_3_1.ogg | sfx | 0.60 | -16.7 | -1.5 |
| chomp_1_2.ogg | sfx | 0.22 | -19.7 | -5.7 |
| chomp_2_2.ogg | sfx | 0.45 | -19.1 | -5.9 |
| chomp_3_2.ogg | sfx | 0.60 | -16.9 | -1.4 |
| chomp_1_3.ogg | sfx | 0.22 | -20.6 | -4.0 |
| chomp_2_3.ogg | sfx | 0.45 | -19.1 | -4.3 |
| chomp_3_3.ogg | sfx | 0.60 | -16.6 | -1.3 |
| chomp_4.ogg | sfx | 0.75 | -17.4 | -1.2 |
| chomp_5.ogg | sfx | 1.60 | -16.8 | -1.0 |
| tunnel.ogg | loop | 2.00 | -25.0 | -10.9 |
| burst.ogg | sfx | 0.36 | -18.3 | -8.6 |
| wiggle.ogg | sfx | 0.60 | -17.0 | -2.0 |
| stage_up.ogg | sfx | 2.60 | -15.2 | -1.2 |
| threat_near.ogg | sfx | 1.05 | -19.0 | -5.6 |
| eaten.ogg | sfx | 1.70 | -17.1 | -2.6 |
| now_i_eat_you.ogg | sfx | 1.50 | -16.0 | -2.0 |
| breakthrough.ogg | sfx | 2.20 | -16.9 | -1.1 |
| planet_gone.ogg | sfx | 2.65 | -16.8 | -1.2 |
| space_drift.ogg | loop | 16.00 | -28.0 | -16.4 |
| amb_dirt.ogg | loop | 16.00 | -32.3 | -11.0 |
| amb_topsoil.ogg | loop | 16.00 | -32.1 | -16.2 |
| amb_deep_rock.ogg | loop | 16.00 | -32.0 | -21.2 |
| amb_core.ogg | loop | 16.00 | -31.9 | -18.3 |
| amb_surface.ogg | loop | 16.00 | -32.2 | -18.8 |
| carry.ogg | sfx | 0.25 | -19.3 | -7.5 |
| drop.ogg | sfx | 0.32 | -18.8 | -6.3 |
| sleep.ogg | sfx | 2.00 | -20.0 | -6.8 |
| warp.ogg | sfx | 0.90 | -17.5 | -8.9 |
| warp_charge.ogg | sfx | 0.50 | -20.9 | -10.7 |
| segment_pop.ogg | sfx | 0.25 | -20.4 | -6.8 |
| hatch.ogg | sfx | 1.00 | -17.0 | -5.5 |
| egg_crack.ogg | sfx | 0.40 | -19.9 | -1.4 |
| bonk.ogg | sfx | 0.90 | -18.5 | -1.2 |
| boop.ogg | sfx | 0.55 | -19.1 | -9.4 |
| home_trophy.ogg | sfx | 1.40 | -18.0 | -5.1 |
| home_seed.ogg | sfx | 0.80 | -18.9 | -6.8 |
| burrow_grow.ogg | sfx | 1.30 | -17.9 | -5.7 |
| solo_focus.ogg | sfx | 0.60 | -19.9 | -7.9 |
| wall_open.ogg | sfx | 0.70 | -18.9 | -6.1 |
| wall_close.ogg | sfx | 0.70 | -18.9 | -5.3 |
| trait_swap.ogg | sfx | 0.40 | -19.0 | -2.2 |
| tackle_box.ogg | sfx | 0.60 | -18.5 | -1.6 |
| trait_drill_head.ogg | sfx | 0.90 | -17.7 | -6.6 |
| trait_glow.ogg | sfx | 1.00 | -17.5 | -5.6 |
| trait_green_thumb.ogg | sfx | 0.90 | -17.7 | -5.9 |
| trait_magnet.ogg | sfx | 0.90 | -17.9 | -5.6 |
| trait_slick.ogg | sfx | 0.90 | -18.0 | -5.8 |
| trait_stone_head.ogg | sfx | 0.90 | -18.0 | -4.4 |
| trait_wriggle.ogg | sfx | 1.00 | -17.5 | -4.2 |
| trait_floaty.ogg | sfx | 1.00 | -17.5 | -5.3 |
| trait_skater.ogg | sfx | 0.90 | -17.6 | -4.6 |
| trait_garden_cart.ogg | sfx | 1.00 | -18.0 | -5.1 |
| pet_home.ogg | sfx | 0.90 | -18.5 | -8.3 |
| pet_away.ogg | sfx | 0.80 | -20.1 | -4.3 |
| pet_fetch.ogg | sfx | 1.00 | -18.7 | -8.0 |
| pet_meet.ogg | sfx | 1.20 | -18.0 | -6.2 |
| pet_hello.ogg | sfx | 0.60 | -17.5 | -6.0 |
| pet_walk.ogg | sfx | 0.30 | -24.7 | -10.6 |
| pet_tend.ogg | sfx | 0.60 | -21.9 | -10.2 |
| pet_lamp.ogg | sfx | 0.90 | -21.0 | -4.8 |
| ring_open.ogg | sfx | 1.60 | -17.3 | -1.1 |
| bird_gulp.ogg | sfx | 0.40 | -18.0 | -2.8 |
| boing.ogg | sfx | 0.55 | -17.9 | -6.7 |
| bird_offended.ogg | sfx | 0.60 | -18.2 | -7.9 |
| bird_peck.ogg | sfx | 0.35 | -18.9 | -2.4 |
| bird_tweet.ogg | sfx | 0.40 | -20.0 | -11.0 |
| creature_munch.ogg | sfx | 0.35 | -20.8 | -8.4 |
| ant_hup.ogg | sfx | 0.20 | -20.7 | -7.4 |
| beetle_blink.ogg | sfx | 0.35 | -21.2 | -7.4 |
| boot_rumble.ogg | sfx | 1.10 | -18.9 | -3.7 |
| grub_squeak.ogg | sfx | 0.22 | -20.8 | -10.5 |
| lava_blob_blorp.ogg | sfx | 0.35 | -20.1 | -8.6 |
| lava_blob_swell.ogg | sfx | 1.00 | -18.8 | -8.8 |
| rock_beetle_clack.ogg | sfx | 0.35 | -20.2 | -3.6 |
| rock_beetle_windup.ogg | sfx | 1.05 | -18.9 | -3.9 |
| beetle_windup.ogg | sfx | 1.05 | -18.9 | -7.0 |
| beetle_lunge.ogg | sfx | 0.50 | -18.3 | -1.3 |
| garden_plant.ogg | sfx | 0.70 | -19.0 | -8.0 |
| secret_found.ogg | sfx | 1.80 | -16.5 | -2.1 |
| mole_hide.ogg | sfx | 0.50 | -19.8 | -8.2 |
| mole_pop.ogg | sfx | 0.50 | -18.7 | -3.5 |
| mole_sorry.ogg | sfx | 0.80 | -19.0 | -5.1 |
| swap.ogg | sfx | 0.80 | -17.1 | -4.8 |
| box_open.ogg | sfx | 0.60 | -17.8 | -1.6 |
| box_close.ogg | sfx | 0.40 | -19.2 | -3.1 |
| box_flip.ogg | sfx | 0.30 | -21.5 | -8.3 |
| box_tick.ogg | sfx | 0.25 | -21.3 | -8.0 |
| box_play.ogg | sfx | 0.90 | -18.3 | -5.5 |
| box_why.ogg | sfx | 0.80 | -19.0 | -7.9 |
| lure_pin.ogg | sfx | 0.50 | -19.9 | -5.9 |
| page_new.ogg | sfx | 1.00 | -18.1 | -5.9 |
| book_open.ogg | sfx | 0.50 | -19.0 | -3.1 |
| book_close.ogg | sfx | 0.50 | -19.0 | -1.6 |
| book_flip.ogg | sfx | 0.30 | -21.1 | -7.0 |
| book_look.ogg | sfx | 0.60 | -20.0 | -3.5 |
| book_tick.ogg | sfx | 0.25 | -21.3 | -7.6 |
| jump.ogg | sfx | 0.22 | -19.7 | -11.6 |
| action.ogg | sfx | 0.30 | -19.2 | -3.3 |
| round_start.ogg | sfx | 1.20 | -18.0 | -5.2 |
| round_end.ogg | sfx | 1.30 | -18.0 | -5.4 |
| pause.ogg | sfx | 0.50 | -19.0 | -6.1 |
| solo_on.ogg | sfx | 0.68 | -18.9 | -6.7 |
| solo_off.ogg | sfx | 0.68 | -18.9 | -6.7 |
| chomp_bite.ogg | sfx | 0.50 | -17.9 | -3.6 |
| confirm_hold.ogg | sfx | 0.55 | -20.1 | -12.3 |
| confirm_cancel.ogg | sfx | 0.30 | -19.1 | -9.9 |
| confirm_yes.ogg | sfx | 1.00 | -17.9 | -2.1 |
| jar_clink.ogg | sfx | 0.90 | -19.0 | -4.2 |
| space_bite.ogg | sfx | 0.70 | -18.0 | -2.0 |
| space_bump.ogg | sfx | 0.40 | -19.1 | -6.8 |
| world_blocked.ogg | sfx | 0.30 | -21.2 | -4.8 |
| world_munch.ogg | sfx | 0.12 | -22.3 | -10.7 |
| world_seed.ogg | sfx | 0.35 | -21.2 | -8.8 |
| world_regrow.ogg | sfx | 0.50 | -24.0 | -11.8 |
| world_sprout.ogg | sfx | 0.20 | -23.5 | -13.7 |
