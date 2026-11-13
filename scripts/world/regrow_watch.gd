## G-04 / G-05 / kid-check N4: ground that grows back, and garden cells that fill, twinkle where they
## grow (RegrowSparkles) and, near a worm, play `world_regrow` / `world_sprout` (at most one of each
## every CUE_GAP s, so a regrowth pass is one soft sound, not a burst). The disk test level had
## this; the real planet was silent. One per world, made by CastingsHook (a worm.tscn child), so no
## level script has to know about it.
class_name RegrowWatch
extends Node2D

const CUE_GAP := 0.4
const HEAR_TILES := 40.0     # a worm within this many tiles hears it

var world: PolarWorld
var sparkles: RegrowSparkles
var sparkled := 0           # per call counters, for tests
var cues := 0

var _gap := {}              # cue -> seconds left


## The world's watch, made on first ask.
static func ensure(w: PolarWorld) -> RegrowWatch:
	if w == null:
		return null
	if w.has_meta(&"regrow_watch") and is_instance_valid(w.get_meta(&"regrow_watch")):
		return w.get_meta(&"regrow_watch")
	var r := RegrowWatch.new()
	r.name = "RegrowWatch"
	r.world = w
	r.z_index = 2
	w.set_meta(&"regrow_watch", r)
	w.add_child(r)
	return r


func _ready() -> void:
	sparkles = RegrowSparkles.new()
	sparkles.name = "Sparkles"
	add_child(sparkles)
	world.tile_regrown.connect(func(cell: Vector2i, _b: StringName) -> void: grew(cell, "world_regrow"))
	world.garden_grew.connect(func(cell: Vector2i, _f: StringName) -> void: grew(cell, "world_sprout"))


func grew(cell: Vector2i, cue: String) -> void:
	var at := world.shape.center_of(cell)
	sparkles.add(at)
	sparkled += 1
	if float(_gap.get(cue, 0.0)) <= 0.0 and _heard(at):
		_gap[cue] = CUE_GAP
		Audio.play(cue)
		cues += 1


func _heard(at: Vector2) -> bool:
	var reach := HEAR_TILES * float(world.shape.cell_size)
	for w in Worm.all():
		if w.world == world and world.to_local(w.head.global_position).distance_to(at) < reach:
			return true
	return false


func _process(delta: float) -> void:
	for k in _gap.keys():
		_gap[k] = maxf(0.0, float(_gap[k]) - delta)
