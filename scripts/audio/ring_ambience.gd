## Ring ambience (U-14): one looping bed per ring, keyed by RingDef.id. The bed is the cue
## "amb_<id>" (assets/audio/sfx/amb_<id>.ogg). While the followed worm's head is in a ring, that
## ring's bed plays under the music at LEVEL_DB; when the head moves to another ring the old bed
## fades out and the new one fades in over FADE seconds (both at once: a crossfade). A ring with no
## file (an unknown id, the sky until someone makes amb_sky) plays nothing: no placeholder beep, no
## warning. Above the grass by SkyLife.inner the head is in the sky (SKY_ID), same rule.
## Drop it into a level as a child of the node that owns `world` (planet.tscn): it finds the world
## and the worms itself and never moves or steers anything. While the level's chomp shot or space
## owns the screen (level.chomp.busy()) every bed fades out.
class_name RingAmbience
extends Node

## How loud a ring's bed plays (dB on the SFX bus). The beds are mastered quiet (about -32 LUFS).
const LEVEL_DB := -6.0
## Seconds for a full fade in or out; a ring change runs both at once.
const FADE := 1.5
## A bed at or below this is stopped.
const SILENT_DB := -60.0
const PREFIX := "amb_"
const SKY_ID := &"sky"
const SKY_LIFE := "res://data/rings/sky_life.tres"

var world: PolarWorld
## The ring whose bed is fading in or playing (&"" when none: no worm, an unknown ring, the shot).
var current: StringName = &""
## ring id -> AudioStreamPlayer, made the first time that ring is entered.
var beds: Dictionary = {}
## Where the sky starts, as a fraction of the planet radius.
var sky_from := 1.03

var _known: Dictionary = {}


func _ready() -> void:
	name = "RingAmbience"
	if ResourceLoader.exists(SKY_LIFE):
		var sky = load(SKY_LIFE)
		if sky is SkyLife:
			sky_from = sky.inner


## The cue a ring id plays, or "" when there is no file for it (silent).
func cue_for(id: StringName) -> String:
	if id == &"":
		return ""
	if not _known.has(id):
		var cue := PREFIX + String(id)
		_known[id] = cue if ResourceLoader.exists(Audio.SFX_DIR + cue + ".ogg") else ""
	return _known[id]


## The ring id at a position in the world's local space.
func ring_id_at(local: Vector2) -> StringName:
	if world == null or world.shape == null:
		return &""
	var r := float(world.shape.radius) * float(world.shape.cell_size)
	if local.length() > r * sky_from:
		return SKY_ID
	var ring := world.ring_of(world.shape.cell_at(local))
	return ring.id if ring != null else &""


## The worm whose head picks the bed: the lowest player number in this level (P1 if there is one).
func followed() -> Worm:
	var best: Worm = null
	var level := get_parent()
	for w in Worm.all():
		if not w.is_inside_tree() or (level != null and not level.is_ancestor_of(w)):
			continue
		if best == null or w.player < best.player:
			best = w
	return best


## Point the ambience at a ring: its bed fades in, every other bed fades out. Unknown ids fade
## everything out and play nothing.
func follow(id: StringName) -> void:
	if cue_for(id) == "":
		id = &""
	if id == current:
		return
	current = id
	if id != &"" and not beds.has(id):
		var p := Audio.loop_player(cue_for(id))
		p.name = "Bed_" + String(id)
		p.volume_db = SILENT_DB
		add_child(p)
		beds[id] = p
	if id != &"" and not (beds[id] as AudioStreamPlayer).playing:
		(beds[id] as AudioStreamPlayer).play()


## Moves every bed's volume one step toward its target (current at LEVEL_DB, the rest silent).
func step(delta: float) -> void:
	var rate := (LEVEL_DB - SILENT_DB) / FADE * delta
	for id in beds:
		var p: AudioStreamPlayer = beds[id]
		var target := LEVEL_DB if id == current else SILENT_DB
		p.volume_db = move_toward(p.volume_db, target, rate)
		if id != current and p.volume_db <= SILENT_DB and p.playing:
			p.stop()


func _process(delta: float) -> void:
	if world == null:
		var w = get_parent().get("world") if get_parent() else null
		if w is PolarWorld:
			world = w
	follow(_wanted())
	step(delta)


func _wanted() -> StringName:
	if world == null or not world.is_inside_tree():
		return &""
	var chomp = get_parent().get("chomp")
	if chomp != null and is_instance_valid(chomp) and chomp.has_method("busy") and chomp.busy():
		return &""
	var w := followed()
	if w == null:
		return &""
	return ring_id_at(world.to_local(w.head_position()))


func _exit_tree() -> void:
	for id in beds:
		(beds[id] as AudioStreamPlayer).stop()
