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
