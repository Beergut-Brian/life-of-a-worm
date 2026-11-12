# Contracts

Shared signals and APIs that lanes code against. Systems lane owns this file. Change it in its
own PR before changing code; every other lane reads the merged version.

## Autoloads (always available)

### `Game` (`scripts/autoload/Game.gd`)

State machine for the whole session. Boots into `LOBBY` (the start screen / main menu,
`scenes/ui/lobby.tscn`) unless `--demo` is passed, which skips straight to a round.

```gdscript
enum State { LOBBY, PLAYING, PAUSED, ROUND_END, TITLE = 0 }   # TITLE: old name of LOBBY, deprecated
var state: State
var round_index: int
var demo: bool                  # --demo: skip the lobby, both players join as virtual players
signal state_changed(from: State, to: State)
signal round_started(round_index: int)
signal round_ended(round_index: int, result: Dictionary)   # result is game-defined
signal lobby_ready(players: Array)   # the lobby countdown finished; players = who readied up
signal back_to_lobby()               # pause menu Restart: clear the level, show the lobby
signal quit_requested()              # emitted just before a clean quit; last chance to save

func start_round() -> void
func end_round(result: Dictionary = {}) -> void
func pause() -> void
func resume() -> void
func restart() -> void          # Select: back to a fresh round, no questions asked
func to_lobby() -> void         # back to the start screen; round_index resets to 0
func finish_lobby(players: Array) -> void   # the lobby calls this: emits lobby_ready, starts round 1
func quit(code: int = 0) -> void            # Save.flush(), then exit; the launcher resumes
```

Start (`pause`) toggles `PLAYING` <-> `PAUSED`. The pause menu (`scenes/ui/pause_menu.tscn`) is a
text menu over the blurred game: Resume, Restart (`to_lobby()`), Settings, Back to Open Jar
("Leave the game?" Stay / Leave, then `quit()`). It shows who paused (`paused_by`). Either pad
moves the cursor; A selects; B backs out of Settings / the question, else resumes; Start resumes.
Window close also goes through `quit()`. Menus are for the grown-up: see `docs/ui.md`.

### Lobby (`scenes/ui/lobby.tscn`, `scenes/ui/lobby.gd`)

Start screen and main menu in one, the Showtime menu kit (`docs/ui.md`): the game's slanted title
over a stage (sunburst, and the game's world blurred behind it if the skin asks), each player's
`Roster` pick (P1 green ring, left; P2 red, right; Jeff and Chuck by default) on podiums with name
plates and READY! stamps, and a wedge of slanted bars: Play / Settings / Back to Open Jar.

- A on a new pad: that pad joins and is ready; its podium lights up and its character waves.
- Left / right while joined and not ready: the character chooser (`Roster`, above).
- B: un-ready (or back out of Settings / the question). Both ready: a 3-beat countdown; on the last
  beat the stamps say GO!, both characters cheer, the three-stripe wipe covers the screen and
  `Game.finish_lobby(ready_players)` starts round 1 (with the skin's "ROUND 1" card). Un-readying
  cancels, except during the last beat.
- A held on Play for 1.5 s by a ready player starts without the other (Play fills up).
- Back to Open Jar asks "Leave the game?" (Stay focused first), Leave calls `Game.quit()`.
- Solo mode readies both. A pad that joins mid-game plays from the next round. Solo is never
  turned on at boot by the saved setting (playtest only): only `--solo` or Select + Start.

The look per game comes from one resource, `MenuSkin` (`scenes/ui/kit/menu_skin.gd`): title,
accent / sunburst / deep colours, the two character scenes and names, the backdrop
(`SUNBURST`, `SCENE` live world, `TEXTURE` still, `SCREEN` the level behind), the round card.
`res://data/menu_skin.tres` is used automatically; or `UiStyle.use_skin(skin)` in code.

```gdscript
@export var title_texture: Texture2D        # wins over the skin's title
@export var title_text: String              # wins over the skin's title
var round_card_subtitle: String             # "JEFF KICKS FIRST" under ROUND 1; set in code
var round_card_color: Color                 # its strip colour (default the skin's accent2)
signal player_readied(player: int, ready: bool)
signal countdown_started()
signal countdown_cancelled()
signal launching()                          # the last beat: the wipe is starting
# Spots/P1/Character, Spots/P2/Character: CharacterSlots hosting the skin's characters, by default
# the player's Roster pick; the lobby calls set_joined(on: bool), wave() and cheer() on the
# character if it has them, and set_character(id: String) when the pick changes.
# Backdrop, Wedge, TitleArt, Buttons/Play, Buttons/Settings, Buttons/Door, Settings, Confirm.
```

`ShowtimeWipe.run(on_cover, title, subtitle, color)` plays the same wipe anywhere (between rounds).
`UiSound.play(cue, pitch)` plays a menu cue: the `.ogg` in `assets/audio/sfx/` if there is one,
else a synthesized stand-in (cue list in `docs/ui.md`).

### Settings (`scenes/ui/settings_panel.gd`, class `SettingsPanel`)

Music volume, sound volume, screen shake, solo playtest mode; in the lobby and the pause menu.
Per install, through `Save.set_setting()`, written the moment a value changes.

```gdscript
const MUSIC := "music_volume"     # 0..1, default 0.8 -> Audio "Music" bus
const SOUND := "sound_volume"     # 0..1, default 1.0 -> Audio "SFX" bus
const SHAKE := "screen_shake"     # bool, default true
const SOLO := "solo_playtest"     # bool, default false; the toggle in Settings. Not restored at boot
static func screen_shake() -> bool  # games check this before shaking the camera
```

### `Roster` (`scripts/autoload/Roster.gd`)

Who each player is: the playable characters (from `openjar-characters`, vendored by
`scripts/tools/sync_characters.sh` into `assets/characters/<id>/` and `data/roster.json`) and each
slot's pick. Player colours stay with the slot (`Players.COLOR`), never the character.

```gdscript
signal pick_changed(player: int, id: String)
signal said(player: int, id: String, path: String)   # a voice line started; player -1: shared voice

var data_path := "res://data/roster.json"   # tests point this at a fixture, then reload()
var picks_path: String                       # the shared file; tests point this at user://
var characters_tag: String                   # the openjar-characters tag the roster came from

func roster() -> Array[String]               # playable ids in chooser order
func has(id: String) -> bool
func info(id: String) -> Dictionary          # {} if unknown, else:
	# id, name ("Jeff"), glb ("res://assets/characters/jeff/jeff.glb" or ""),
	# pixel ("res://assets/characters/jeff/pixel.png" or ""), voice ("res://.../voice/" or ""),
	# barks (Array of file stems in voice/), catchphrase ("res://.../voice/catchphrase.ogg" or ""),
	# default_for (1, 2 or 0)
func default_for(player: int) -> String      # data/roster.json defaults.P1 / .P2
func pick(player: int) -> String             # never "" while the roster has a character
func set_pick(player: int, id: String) -> bool   # false (no change) if unknown or the other's pick
func next_free(player: int, dir: int) -> String  # dir +1 / -1 through roster(), skipping the
                                                 # other player's pick; pick(player) if none free
func taken(id: String, by_other_than: int) -> bool
func reload() -> void                        # re-read roster.json, args, the shared file
func bark(id: String, player := -1) -> bool  # plays a random voice bark; false if it has none
func catchphrase(id: String, player := -1) -> bool  # the catchphrase, else bark(); false if neither
func voice_player(player := -1) -> AudioStreamPlayer  # P1 / P2: that slot's own panned voice
                                                 # (VoiceP1 / VoiceP2 bus); -1: the shared one.
                                                 # A new line cuts off only that voice's last one
var last_said: Dictionary                    # voice (player or -1) -> res:// path of its last line
```

**Resolving a slot** at start (`reload()`), first hit that is in `roster()`:
1. `--p1-char=<id>` / `--p2-char=<id>` (either side of `--`)
2. the shared file `players.json[Save.profile]["P1" | "P2"]`
3. `defaults.P1` / `defaults.P2`
4. the first roster id the other player has not got

Unknown, removed or resident ids are skipped, never an error. If both slots resolve to the same
id, P2 moves to `next_free(P2, 1)`. No two players are ever the same character.

**The shared picks file** (`picks_path`): `OS.get_data_dir() + "/openjar/players.json"` (Linux
`~/.local/share/openjar/players.json`), outside every game's `user://`. Shared with every Open Jar
game and the launcher:

```json
{ "p1": { "P1": "jeff", "P2": "chuck" }, "kid": { "P1": "chuck", "P2": "jeff" } }
```

Keyed by save profile, then slot. Written the moment a pick changes (`set_pick`): read the file,
change only this profile's slot, keep every other key, write `players.json.tmp`, rename over
`players.json` (folder created if missing). A missing or broken file reads as empty. Roster never
touches the game's own `user://` saves.

**Launch args**: the launcher passes `--profile=<id> --p1-char=<id> --p2-char=<id>`. They win over
the file; a pick changed in the game is still written to the file.

**Spawning the chosen character** (game code; `docs/ui.md` "Per game"):

```gdscript
var who := Roster.info(Roster.pick(player))
var body: Node = load(who.glb).instantiate()      # 3D; a pixel game uses load(who.pixel)
add_child(body)
```

**The chooser** (lobby): joined and not ready, left / right (stick or D-pad) calls
`Roster.set_pick(p, Roster.next_free(p, dir))`; the podium swaps with a squash/pop and a poof, the
plate shows the new name, the `char_swap` cue plays, and `SAY_SETTLE` (0.3 s) after the last step
the character says `Roster.catchphrase(id, p)` once (`docs/ui.md` "Chooser voice"). Ready: left / right does
nothing; B un-readies. Solo: Select picks which podium the pad drives (A, B and left / right).

### `Players` (`scripts/autoload/Players.gd`)

Who is holding which controller. Never read device ids directly.

```gdscript
const P1 := 0
const P2 := 1
const COLOR := { P1: Color("3cc24a"), P2: Color("e4393c") }   # green, red
const VIRTUAL := -2             # device of a keyboard or --demo player

signal player_joined(player: int, device: int)
signal player_left(player: int)
signal solo_changed(on: bool)

var solo: bool                  # playtest only: one pad plays both players
var solo_focus: int             # the player the solo pad drives right now; the game sets it

func is_active(player: int) -> bool
func device_of(player: int) -> int
func active_players() -> Array[int]
func action(player: int, action: String) -> String   # "p1_move_left" etc. for Input.*
func move_vector(player: int) -> Vector2
func join_virtual(player: int) -> void
func set_solo(on: bool, device: int = VIRTUAL) -> void
func set_solo_focus(player: int) -> void   # the game calls this when the other player's turn comes
func reset() -> void                       # tests: nobody joined, solo off, InputMap restored
```

Solo mode: `--solo` on the command line, or hold Select + Start together for 2 s on a pad (again
to turn it off). Both players join on that pad; only `solo_focus`'s actions get its events. A
two-heads icon shows top-left while it is on. A keyboard key from a player's action joins that player.

Input map actions (defined in `project.godot`, per player, prefix `p1_` / `p2_`):
`move_left`, `move_right`, `move_up`, `move_down`, `action`, `jump`, `carry` (X; keys Q / .), `tackle` (Y; keys E / /).
Global: `pause`, `restart`, `debug_overlay`, `debug_screenshot`.

### `Save` (`scripts/autoload/Save.gd`)

JSON under `user://saves/<profile>.json`. Autosave at every natural stopping point.

```gdscript
var profile: String                 # set by the launcher via --profile=<id>, default "p1"
signal saved()
signal loaded()

func get_value(key: String, default = null)
func set_value(key: String, value) -> void   # marks dirty
func flush() -> void                         # writes if dirty; Game.end_round() calls this
func wipe() -> void

# Per install, not per profile: user://settings.json, written on every set_setting().
var settings_path: String                    # tests point this elsewhere
func get_setting(key: String, default = null)
func set_setting(key: String, value) -> void
func reload_settings() -> void
func wipe_settings() -> void
```

### `Audio` (`scripts/autoload/Audio.gd`)

```gdscript
func play(cue: String, position = null) -> void   # cue = file stem in assets/audio/sfx/
func music(track: String, fade: float = 0.5) -> void
func stop_music(fade: float = 0.5) -> void
func bark(character: String, bark: String) -> void   # from openjar-characters voice packs
func set_volume(bus: String, linear: float) -> void  # "Music" / "SFX", 0..1; Settings calls it
func get_volume(bus: String) -> float
```

Audio creates the `Music` and `SFX` buses at start if the project has no bus layout, and applies
the saved volumes.

Every action must call `Audio.play`. Missing cue files log a warning, never crash.

Menu cues (Audio lane supplies the files): `ui_move`, `ui_confirm`, `ui_back`, `player_join`,
`player_ready`, `player_unready`, `count_tick`, `round_start`, `pause`, `solo_on`, `solo_off`.

### `Debug` (`scripts/autoload/Debug.gd`)

F3 toggles the overlay (fps, state, player count). F12 saves `user://screenshots/<timestamp>.png`
and prints the path. `--screenshot-after=<seconds>` CLI flag does it headlessly for the Reviewer.

## Launcher handshake

The launcher starts a game with `--profile=<id>` and expects the game to:

- read `store/openjar.json` at export time (name, version, card art, clip) — produced by CI;
- exit with code 0 on a clean quit (`Game.quit()`: the door button in the lobby or the pause menu);
- not change display mode (the launcher owns fullscreen).

## Game-specific contracts

Add this game's own signals and APIs below. Keep the same format.

### Planet chomp and jars (stage 6 → 7; risk prototype R-b, `feature/proto-chomp-1`)

Jars are per install, one file per eaten planet: `user://jars/<planet_id>.json`, a full copy of the
tin's save taken just before the chomp (seed + edits, so a few KB). `planet_id` is
`<profile>_<seed>`. The jar API lives in `scripts/jars/jars.gd` (class `JarStore`); it is meant to
become the autoload `Jars` (requested from Systems). Until then a scene instances it as a node
named `Jars`.

```gdscript
# JarStore (Jars)
signal planet_jarred(planet_id: StringName)       # after the jar file is written
var dir := "user://jars"                           # tests and the demo point this elsewhere
func snapshot(planet_id: StringName) -> String     # flush Save, copy it to <dir>/<planet_id>.json,
                                                   # add planet_id to Save "jars"; returns the path ("" on failure)
func list() -> Array[StringName]                   # jar ids on the shelf, sorted
func has_jar(planet_id: StringName) -> bool
func open(planet_id: StringName) -> bool           # load the jar as profile "jar_<planet_id>" with
                                                   # "jar": true and "stage6_disabled": true
func close() -> void                               # write the jar profile back into the jar, return
                                                   # to the tin that opened it
func is_in_jar() -> bool
static func stage6_allowed() -> bool               # false inside a jar (Save "stage6_disabled")

# PlanetChomp (scenes/levels/planet_chomp.tscn, scripts/chomp/planet_chomp.gd)
signal confirm_started()
signal confirm_cancelled()                         # the hold was released before it filled
signal planet_eaten()                              # exactly once, on the final gulp
func begin() -> bool                               # shows the picture; false if stage 6 is disabled
func advance(delta: float, held: bool) -> void     # the whole sequence; _process calls it with A held
var planet_texture: Texture2D                      # the remaining planet; the tile world provides it

# Save keys this section reads and writes (per tin)
#   "planet": { "id": String, "seed": int, "bites": [[angle, radius, size], ...] }   # stand-in edits
#   "stage": int          6 before the chomp, 7 after
#   "jars": Array[String] planet ids jarred from this tin
#   "jar": bool, "stage6_disabled": bool              # only inside a jar

# Space (scenes/levels/space.tscn, scripts/space/)
signal ate(player: int, what: StringName, growth: float)   # same signal as the disk worm
static func StageRule.relation(eater_stage: int, other_stage: int) -> int  # FOOD | THREAT | IGNORE
# Anything that can be eaten exposes `var size_stage: int`; bigger eats smaller, equal ignores.
```

### World: the polar disk (risk prototype R-a, `feature/proto-polar-1`)

The planet is a `PolarWorld` (`scripts/world/polar_world.gd`), a subclass of the addon's `TileWorld`
(`addons/openjar/tileworld/`, vendored v0.2.0) on a `DiskShape`. In `scenes/levels/disk.tscn` it is
the node named `World`, in group `&"world"`; find it with
`get_tree().get_first_node_in_group(&"world")`. It is not an autoload. Cells are `Vector2i` on one
Cartesian grid (16 px squares, y down, core at the origin); only chunk grouping is polar. Positions
are local to the world node; the world is translated, never rotated (the camera rotates).

Time is the world's own simulated clock (`clock`, seconds, saved), never the wall clock: regrowth and
gardens run on it, tests drive it with `advance()`.

```gdscript
# PolarWorld ("World")
signal tile_eaten(cell: Vector2i, block: StringName, player: int)   # after eat_tile removed it
signal tile_regrown(cell: Vector2i, block: StringName)              # a regrowth pass put it back
signal garden_planted(cell: Vector2i, flavour: StringName)          # a seed took in castings
signal garden_grew(cell: Vector2i, flavour: StringName)             # the patch filled one more cell
# inherited from TileWorld: chunk_loaded(key), chunk_freed(key), tile_dug, dig_blocked, ...

var clock: float                                   # simulated planet seconds
var rings: RingSet                                 # data/rings/rings.tres
func setup_planet(rings: RingSet, radius: int, seed: int, band := 32) -> void   # before add_child is fine
func advance(delta: float) -> void                 # clock += delta; regrowth and garden passes when due
                                                   # (_physics_process calls it; tests call it directly)
func set_stage(player: int, stage: int) -> void    # the worm lane tells the world each worm's stage
func stage_of(player: int) -> int                  # 1 until set
func is_edible_by(stage: int, thing) -> bool       # thing: a Vector2i cell, a StringName tile id, or any
                                                   # Object with `size_stage` (StageRule.relation == FOOD).
                                                   # Cells and tiles: breakable and ring.edible_from <= stage.
                                                   # Strangestone is never edible.
func eat_tile(cell: Vector2i, player: int) -> bool # true when eaten: air + timestamped edit + castings,
                                                   # tile_eaten emitted. False (nothing changes) when air,
                                                   # outside, or not edible by stage_of(player).
func eat_circle(pos: Vector2, radius_px: float, player: int) -> int   # eat_tile on every cell centre in
                                                   # the circle; returns how many were eaten
func regrow_time(cell: Vector2i) -> float          # seconds from being eaten to regrowing: the ring's
                                                   # regrow_time, x castings_factor in castings;
                                                   # INF = never (the Green thumb trait will scale
                                                   # castings_factor through WormStats, not here)
func has_castings(cell: Vector2i) -> bool
func plant_seed(cell: Vector2i, flavour: StringName) -> bool   # true only on an air cell with castings
                                                   # whose flavour is in rings.garden_tiles
func ring_of(cell: Vector2i) -> RingDef
func eaten_at(cell: Vector2i) -> float             # clock time of the edit, -1 if none
func track_eater(node: Node2D) -> void             # track() + regrowth never fills within
                                                   # keep_clear_tiles of it; untrack_eater(node) undoes it
func planet_texture() -> Texture2D                 # the whole disk, 1 px per 2 tiles, edits drawn in;
                                                   # the planet shot and the stage-6 chomp use it

# Chunks (the addon's WorldShape interface on DiskShape)
#   key = Vector2i(ring_band, sector): ring_band = int(dist / band), sectors_in(band) = max(4,
#   ceil(TAU * (band + 0.5))) so a sector is about `band` tiles of arc. band = 32 (R-a decision).
#   shape.chunk_of(cell) -> Vector2i, shape.chunk_cells(key) -> Array[Vector2i],
#   shape.neighbourhood(key, 2) -> the 5x5 kept live around each tracked node (chunk_radius = 2).
#   loaded_chunks() -> Array[Vector2i]; two eaters on opposite sides = two separate neighbourhoods.
#   Gravity: shape.gravity_at(pos) == -pos.normalized() * gravity; up for a body = pos.normalized().

# Save (inside the tin's "planet" key once Systems wires it; PolarWorld.to_save() / load_save())
#   {"seed": int, "radius": int, "band": int, "clock": float,
#    "edits": [x, y, id, ...],                    # addon EditStore, only differences from the seed
#    "times": [x, y, deciseconds, ...],           # when each still-edited cell was eaten
#    "castings": [x, y, ...],
#    "gardens": [[x, y, "flavour", planted_ds], ...], "water": [...]}
```

`RingSet` / `RingDef` (`scripts/world/ring_def.gd`, `ring_set.gd`; data in `data/rings/rings.tres`):
per ring `id`, `outer` (fraction of the radius), `tile` / `alt_tile` names, `hue`, `edible_from`
(stage), `regrow_time` (seconds, 0 = never), `flavour`. The set holds `castings_factor`,
`garden_interval`, `garden_max_radius`, `garden_tiles` ({flavour: tile name}) and
`strangestone_radius` (tiles). Regrow times are data; the Content lane tunes them there.
### Worm and traits (`scenes/players/worm.tscn`, `scripts/worm/`; risk prototype R-c)

One `Worm` node per player (class `Worm`, root of `worm.tscn`). Signals are on the worm node and
always carry its player, so a listener can connect to both worms the same way
(`Worm.of(Players.P1).ate.connect(...)`, or every node in group `worms`).

```gdscript
signal ate(player: int, what: StringName, growth: float)        # swallowed a FoodData (id)
signal segment_added(player: int, flavour: StringName)         # &"" = a plain segment
signal segment_lost(player: int)                               # eaten by a bigger thing
signal trait_earned(player: int, trait_id: StringName)         # once per trait, never lost
signal traits_changed(player: int, active: Array[StringName])  # equip / swap / slot growth
signal stage_changed(player: int, from: int, to: int)          # only ever goes up
signal carried(player: int, what: StringName)                  # hold X on food: in the mouth
signal dropped(player: int, what: StringName)                  # X released: back in the world
signal eaten_by(player: int, creature: StringName)
signal booped(player: int, other: int)                         # worms pass through each other

static func stats(player: int) -> WormStats   # resolved stats of that player's worm (base if none)
static func of(player: int) -> Worm            # null if that player has no worm
func feed(food: FoodData) -> void              # swallow: growth + flavour, partner gets the share
func get_eaten(creature: StringName) -> void   # one segment shorter, dizzy; never a stage
var player: int
var model: WormGrowth                          # segments, flavours, stage, earned/active traits
```

**Data.** `FoodData` (`data/foods/*.tres`): `id`, `flavour`, `growth`, `size_stage`, `color`.
`TraitData` (`data/traits/*.tres`): `id`, `requires` (flavour -> filled segments), `add` and `mul`
(stat -> number), `part_slot`, `part_textures` (one per stage, last one repeats), `part_priority`,
`cue`, `color`. A trait whose `requires` names two flavours is a hybrid; no other rule.
`WormRules` (`data/traits/worm_rules.tres`): `growth_per_segment`, `stage_segments`,
`slots_per_stage`, `partner_share` (0.25), `base_stats`, flavour colours.

**`WormStats`** (`scripts/worm/worm_stats.gd`). The only place trait modifiers meet:
`value(stat) = (base + sum of add) * product of mul` over the active traits, order-independent.
`parts` is slot -> the highest-priority active trait's part. Worm code reads stats by name
(`speed`, `burst_speed`, `burst_time`, `light_radius`, `pull_radius`, `sheen`, `bite_bonus/<flavour>`,
`drag/<zone kind>`, ...) and never names a trait.

**What the tile world must provide** (later, `openjar-addons` tileworld): food nodes in group
`food` with `data: FoodData` and `take()`; `World.is_edible_by(stage, thing)` honouring
`stage + stats.value("bite_bonus/" + flavour)`; `World.eat_tile(cell, player)` that calls
`Worm.of(player).feed(food_for_tile)`; slow zones in group `slow_zone` with `kind` and `drag`.

### Grey-box planet (`scenes/levels/planet.tscn`, `scripts/planet/`; `feature/greybox-1`)

The game scene. `scenes/main.gd` hosts it under `Arena` after the dock picks a tin, and calls
`spawn_worm(p)` for each active player; a mid-game join calls `drop_in(p)`. One `PlanetLevel` per
open bait tin; everything in it reads and writes that tin through `Save`.

```gdscript
# PlanetLevel (planet.tscn root)
signal worm_spawned(worm: Worm)
const WORM_NAMES := ["Gulp", "Burp"]          # D90; menus and logs, never in gameplay
var world: PolarWorld                         # also in group &"world"
var camera: PolarCamera                       # fit = true; max_fit_index drops a notch per stage
var burrow: Burrow
var beetle: ApexBeetle                        # the dirt ring's apex (placeholder)
var hud: PlanetHud
var spawn_point: Vector2                      # world px; local_point(x_tiles, y_tiles_up) is relative to it
func spawn_worm(player: int, at = null, start_stage := 0) -> Worm   # the tin's saved body if any
func drop_in(player: int) -> WormEgg          # hatches next to the first worm at its stage - 1
func remove_worm(player: int) -> void         # kept in the tin
func save_now() -> void                       # writes the tin and flushes (autosave 30 s, sleep, pause,
                                              # quit, back to lobby, stage-up, apex bite)
# Cutscene hook (story lane): on every stage-up, if /root/Story exists: Story.play("stage_<to>").

# Burrow (scripts/burrow/burrow.gd since feature/slice-burrow-1)
signal home_set(player: int, at: Vector2)
signal brought_home(player: int, what: StringName, kind: StringName)   # &"trophy" | &"seed" | &"pet"
var has_home: bool; var home: Vector2; var trophies: Array[StringName]
static func is_hollow(world, pos, tiles := 2.0, share := 0.75) -> bool
func in_room(pos: Vector2) -> bool            # within 4 tiles of home: Y opens the trait wall here
func can_sleep(w: Worm) -> bool               # still 2 s in a hollow
func bring(w: Worm, food: Node2D) -> StringName

# ApexBeetle (scripts/planet/apex_beetle.gd): one per ring, the stage gate
signal ate_worm(player: int)                  # the worm popped out the far end, one segment shorter
signal eaten(player: int)                     # the apex bite; the level calls Worm.model.eat_apex()
var size_stage := 2; var ring_stage := 1
func relation_to(w: Worm) -> int              # StageRule.FOOD once w.model.size_stage() >= size_stage
const WINDUP := 1.0                           # every lunge telegraphs this long (kid check)

# BaitTins (scripts/planet/bait_tins.gd): three Save slots per profile
static func open(i: int) -> void              # Save.use_slot("tin<i+1>")
static func open_demo() -> void               # slot "demo", wiped
static func summary(i: int) -> Dictionary     # {} empty, else {stage, segments, minutes, worms}
```

**Worm additions** (`scripts/worm/worm.gd`, `worm_growth.gd`):

```gdscript
signal warp_requested(player: int)            # B held Worm.WARP_HOLD (2 s); the level picks the target
signal tackle_pressed(player: int)            # Y outside the burrow
var world: PolarWorld                         # set_world(w): tunnels with World.eat_circle at the mouth
var wall_anywhere := true                     # false in the planet: the trait wall is the burrow's
var in_burrow, asleep, still_time, warp_charge, carry_ready, tiles_this_frame, view_rotation
func bite_tile(flavour: StringName) -> void   # World.tile_eaten for this player -> growth 0.05 (stat tile_growth)
func warp_to(pos: Vector2) -> void
func get_eaten(creature: StringName, out_at = null) -> void
func cam_position() -> Vector2; func fit_points() -> Array   # PolarCamera targets
func to_dict() -> Dictionary; func from_dict(d: Dictionary) -> void
# WormGrowth
var apex_gate := false                        # true in the planet: a stage needs its ring's apex eaten
var apex_eaten: Array[int]
func size_stage() -> int                      # what creatures compare against (segments, >= stage)
func eat_apex(ring_stage: int) -> bool        # true on a stage-up
func to_dict() / from_dict(d)
```

New base stats read by name (defaults in code, tune in `worm_rules.tres`): `tile_growth` (0.05),
`dig_speed` (0.65).

**Tin save keys** (per tin file `user://saves/<profile>_tin<N>.json`): `seed`, `planet`
(`PolarWorld.to_save()`), `worms` ({"0": Worm.to_dict(), "1": ...}), `stage` (highest),
`burrow`, `apex`, `foods` ([[id, home x, y, x, y, gone_at clock], ...]), `played` (seconds).
Never `solo`: solo is session-only.

**Template changes made for Worm, in code** (no `.tscn` overrides): `Save.slot` / `use_slot(id)` /
`path_for(slot)`; `Game.select_restarts` (false in Worm); `Lobby.chooser` (false in Worm);
`UiStyle.player_name()` uses the skin's fixed names; glyph token `[stick]`; `Audio.played` (cue ->
count), `Audio.loop_player(cue)`, and a synthesized placeholder (`GreyBeep`) for any cue with no file.
`scenes/main.gd` `template_only` (tests of the template kit only).

**Audio cues the grey-box plays** (file stem in `assets/audio/sfx/`, `_1.._N` variants allowed):
GAME.md table: `chomp_1`..`chomp_5`, `tunnel` (loop), `burst`, `wiggle`, `stage_up`, `threat_near`,
`eaten`, `now_i_eat_you`. Also: `carry`, `drop`, `sleep`, `warp_charge`, `warp`, `segment_pop`,
`egg_crack`, `hatch`, `bonk`, `boop`, `beetle_windup`, `beetle_lunge`, `home_trophy`, `home_seed`,
`tackle_box`, `solo_focus`, `trait_wriggle` (and each trait's `cue`), `wall_open`, `wall_close`,
`trait_swap`, `round_start`, `pause`.


### Home slice (`scripts/burrow/`, `scripts/pets/`, `scripts/tackle/`, `scripts/swap_shop/`; `feature/slice-burrow-1`)

`PlanetLevel.home_slice: HomeSlice` hosts it; tin key `home_slice` (tackle log, shop, wild pets);
the burrow keeps `burrow` (trophies + cells, pets by id, pantry, stage).

```gdscript
# Burrow additions
signal bonus_changed(bonus: Dictionary)       # stat -> add, applied to every worm by TrophyBonus
signal grew(stage: int)
func room_tiles() -> float                    # 4 + 1.5 per stage
func free_ledge(near: Vector2) -> Vector2i    # Vector2i(-99999, -99999) if none
func bonus() -> Dictionary; func family_counts() -> Dictionary
func remove_trophy(id := &"") -> StringName
func add_pet(id: StringName, t := 0.0) -> Node2D; func add_pantry() -> Node2D
func grow_to(stage: int) -> bool
func note_pickup(w, inside: bool); func should_bring(w) -> bool   # the level calls these each frame

# Anything a worm can "meet" for the tackle box: join group &"creature" and expose
# creature_id: StringName (property or meta). Secrets: any node with
signal secret_found(id: StringName)           # connected automatically when it enters the tree

# TackleLog
signal page_completed(id: StringName)         # &"foods" | &"creatures" | &"traits" | &"secrets" | &"cutscenes"
signal unlocked(page: StringName, id: StringName)
func unlock(page, id) -> bool; func meet(id); func note_secret(id); func note_cutscene(id)
# TackleBox: open(player), close(), nav(dx, dy), confirm(); signal rewatch(id)
# SwapShop: signal traded(player, gave, got); func can_trade(w) -> bool; func trade(w) -> bool
# PetData (data/pets/*.tres): id, food: FoodData (wild form), job &"fetch", fetch, every, trip, max_waiting
# TrophyFamily (data/trophies/*.tres): id, members, per_trophy {stat: add}, cap, color, charm
```

### Ring content (rings-content-1)

Data only (`feature/rings-content-1`, PLAN-STATUS W-02, W-03). Same classes as the dirt and
topsoil rings; nothing new in code. Ids are unique across all rings (the ecology keys on them).

```
# data/foods/ (RingFood)          ring        stage  flavour  growth  plants   look
core_crystal.tres                 core        5      crystal  6.0     crystal  PEBBLE
ore_nugget.tres                   deep_rock   4      stone    3.0     stone    PEBBLE
fossil.tres                       deep_rock   4      stone    4.0     &""      BLOB
# data/creatures/ (CreatureData)  ring        stage  behaviour  notes
rock_beetle.tres                  deep_rock   4      TRUNDLE    1.4 s wind-up; notice 170, strike 44
lava_blob.tres                    core        6      WIGGLE     notice 0, strike 0: never chases or eats;
                                                                 meant to bounce (no hook yet), food at 6
# data/rings/ (RingLife)
core_life.tres       species core_crystal (plant, live = core_crystal.tres), lava_blob (counter
                     only, live_max 0); scatter core_crystal x4
deep_rock_life.tres  species ore_nugget (plant, live = ore_nugget.tres), rock_beetle (eats
                     ore_nugget; counter only, live_max 0); scatter fossil x5
```

Hooks these files wait on (owned by other lanes): `RingsDirector.LIVES` to load the two lives; a
`scenes/creatures/` scene for each creature (then set `live` and `live_max`); a bounce behaviour
for the lava blob (knock-back on contact, never steering); `RingFood.Look` shapes for crystal,
nugget and fossil. Audio cues `rock_beetle_clack`, `rock_beetle_windup`, `lava_blob_blorp`,
`lava_blob_swell` have no files yet (grey beeps).
### Collection book (worm-book-1)

`scenes/ui/book.tscn` (`Book`, a CanvasLayer, layer 70) with one `scenes/ui/book_page.tscn` (`BookPage`)
per section, opened from the pause menu: `PauseMenu/Card/BookTab` (`BookTab`, a new child node; the
pause menu's own script and buttons are unchanged). Y (`tackle`) on the pause menu opens it for
whoever pressed; B or Y shuts it and the pause menu comes back. The pause menu hides while it is open.
The book reads, it never writes: entries from the data registries, the found-set from the tin.

```gdscript
# BookCatalog (scripts/ui/book_catalog.gd, static)
const SECTIONS = [&"foods", &"creatures", &"traits", &"secrets", &"cutscenes"]
func files(section) -> PackedStringArray     # every data file the section reads
func entries(section) -> Array[Dictionary]    # {id, data (Resource or cutscene Dictionary), path}
func found_set(tree) -> Dictionary            # section -> Array[StringName]; live TackleLog first,
                                              # else Save "home_slice" -> "tackle" -> "found";
                                              # cutscenes also take Save "story_seen" / Story.seen
func count(entries, found) -> int
# Sources: foods = data/foods FoodData; creatures = data/creatures CreatureData + data/pets PetData;
# traits = data/traits TraitData; secrets = data/secrets SecretData; cutscenes = data/cutscenes/*.json
# (Story.SCENES order). A new data file appears in the book with no code change.

# Book
signal opened(player: int); signal closed(); signal moved(section, cursor, on_tabs)
func open(player); func close(restore := true); func nav(dx, dy); func confirm()
var host: CanvasItem      # hidden while open (the pause menu)
var pause_tree := true    # the tree stays paused while the book is open: the stick never moves a worm
```

Cues (placeholder beeps until the Audio lane adds them): `book_open`, `book_close`, `book_flip`,
`book_tick`, `book_look`, and the existing `bonk` (cursor against an edge) and `boop` (A on an
unfound sketch).

### Planet jar audit (worm-jar-1)

Additions to `JarStore` (`scripts/jars/jars.gd`); the API above is unchanged.

```gdscript
# JarStore additions
const FOUND_SET := [["tackle"], ["home_slice", "tackle"]]    # Old Reel's tackle box: the tin's
const TIN_ONLY := FOUND_SET + [["solo"], ["settings"]]       # never written into a jar file
func peek(planet_id: StringName) -> Dictionary               # the jar's save without opening it ({} if none)
static func current_planet_id(seed: int) -> StringName       # "<profile>[_<slot>]_<seed>", e.g. p1_tin2_5150
static func strip_tin_only(data: Dictionary) -> Dictionary   # a copy without TIN_ONLY keys
static func found_set_of(data: Dictionary) -> Dictionary     # {"tackle": v, "home_slice/tackle": v}

# JarOpenView (scripts/jars/jar_open_view.gd, scenes/jars/jar_open.tscn): opening a jar, shown
signal entered(planet_id: StringName)        # after JarStore.open(): Save is now the jar's profile
@export var next_scene := ""                 # change to this scene after entered ("" = host decides)
func show_jar(store: JarStore, id: StringName) -> bool   # false if no such jar
func advance(delta: float) -> void           # shelf (clink) -> lid pops (jar_open) -> dive (jar_enter)
                                             # -> open at ENTER_AT (2.4 s). No words, no input needed.
```

- Snapshot and close read the **open save's slot file** (`Save.path_for(Save.slot)`), so a jar taken
  from bait tin 2 is tin 2's planet; close returns to the same profile **and slot**.
- The jar file never holds the found-set or settings. `open()` lends the opening tin's found-set into
  the jar profile; `close()` hands it back to the tin with whatever was found inside, so finds in a
  jar count in the tin's tackle box.
- `planet_id` for a tin is `<profile>_<slot>_<seed>` (was `<profile>_<seed>`, which let two tins
  with the same seed share one jar). `PlanetChomp` uses it when the planet has no id.
- Audio cues `jar_clink`, `jar_open`, `jar_enter` have no files yet (grey beeps).
