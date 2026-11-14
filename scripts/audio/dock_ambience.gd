## Dock bed (U-16): a quiet looping bed under the bait-tin dock (the start screen, the tin select
## and the jar shelf), and nothing once a planet is open. GAME.md wants "one guitar, water, gulls";
## no such file exists yet, so it plays the first cue in CUES that has a file: `amb_dock` (for the
## Audio lane to make: guitar, water, gulls) else the library's open-air bed `amb_surface` (wind in
## gusts, far-away birds). No file at all: silent, no placeholder beep.
## A child of main.tscn's root (main.gd makes it): it reads the root's `level` and fades in while
## it is null, out while a planet (the dirt) is open. The demo has no dock, so it stays silent.
## Never moves or steers anything.
class_name DockAmbience
extends Node

## Tried in order; the first with a file in assets/audio/sfx/ is the bed.
const CUES: Array[String] = ["amb_dock", "amb_surface"]
## How loud the bed plays (dB on the SFX bus), the same as a ring bed (RingAmbience.LEVEL_DB).
const LEVEL_DB := RingAmbience.LEVEL_DB
## Seconds for a full fade in or out.
const FADE := RingAmbience.FADE
const SILENT_DB := RingAmbience.SILENT_DB

var bed: AudioStreamPlayer
## True while the dock is on screen (the bed fades in), false while a planet is open.
var on_dock := false


## The bed's cue, or "" when no file exists.
static func cue() -> String:
	for c in CUES:
		if ResourceLoader.exists(Audio.SFX_DIR + c + ".ogg"):
			return c
	return ""


func _ready() -> void:
	name = "DockAmbience"
	process_mode = Node.PROCESS_MODE_ALWAYS     # the lobby and the dock run while paused too


## Whether the host shows the dock now: no planet open and not the demo.
func wanted() -> bool:
	var host := get_parent()
	if host == null or Game.demo:
		return false
	return host.get("level") == null


## Point the bed at the dock (true) or away (false); moves its volume one step.
func step(delta: float) -> void:
	on_dock = wanted()
	if on_dock and bed == null:
		var c := cue()
		if c == "":
			return
		bed = Audio.loop_player(c)
		bed.name = "Bed"
		bed.volume_db = SILENT_DB
		bed.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(bed)
	if bed == null:
		return
	if on_dock and not bed.playing:
		bed.play()
	var target := LEVEL_DB if on_dock else SILENT_DB
	bed.volume_db = move_toward(bed.volume_db, target, (LEVEL_DB - SILENT_DB) / FADE * delta)
	if not on_dock and bed.volume_db <= SILENT_DB and bed.playing:
		bed.stop()


func _process(delta: float) -> void:
	step(delta)


func _exit_tree() -> void:
	if bed != null:
		bed.stop()
