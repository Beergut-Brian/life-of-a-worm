## Plays the space sights (SpaceSight rows in data/rings/space_sights.tres, D105 content for stage 7):
## a child of scenes/levels/space_stage.tscn that never edits the stage. Each sight counts the space
## seconds the stage runs (step, from _process; tests call step directly) and when the count reaches
## first_after (then every) it brings its bodies in round the worms' centre as SpaceDrift smalls of
## kind &"sight", so the stage's own eaten path (bigger eats smaller, bump if bigger) handles them.
## At most MAX_BODIES about; the oldest goes first. Signal happened(id, at).
class_name SpaceSights
extends Node

signal happened(id: StringName, at: Vector2)

const DATA_PATH := "res://data/rings/space_sights.tres"
const KIND := &"sight"
const MAX_BODIES := 30

var sights: Array[SpaceSight] = []
var bodies: Array[SpacePlanet] = []
var waited := {}
var times := {}
var auto := true
var _rng := RandomNumberGenerator.new()


static func all_sights() -> Array[SpaceSight]:
	var set_ := load(DATA_PATH) as SpaceSightSet
	return set_.sights if set_ else ([] as Array[SpaceSight])


func _ready() -> void:
	sights = all_sights()
	for s in sights:
		waited[s.id] = 0.0
		times[s.id] = 0
	_rng.seed = int(Save.get_value("seed", 1)) * 53 + 11


func stage() -> SpaceStage:
	return get_parent() as SpaceStage


func _process(delta: float) -> void:
	if auto:
		step(delta)


func step(dt: float) -> void:
	var st := stage()
	if st == null or st.drift == null or st.worms.is_empty():
		return
	for s in sights:
		if st.drift.done.size() < s.after_planets:
			continue
		waited[s.id] = float(waited[s.id]) + dt
		var due := s.first_after if int(times[s.id]) == 0 else s.every
		if float(waited[s.id]) >= due:
			play(s)


## Brings s in now. Returns its bodies.
func play(s: SpaceSight) -> Array[SpacePlanet]:
	waited[s.id] = 0.0
	times[s.id] = int(times[s.id]) + 1
	var st := stage()
	var c := st.worms_centre()
	var a := _rng.randf() * TAU
	var from := c + Vector2.from_angle(a) * s.distance
	# aim past the worms, never straight at them
	var aim := c + Vector2.from_angle(a + PI / 2.0) * 160.0
	var dir := (aim - from).normalized()
	var out: Array[SpacePlanet] = []
	for i in s.count:
		var at: Vector2
		var vel := dir * s.speed
		match s.shape:
			SpaceSight.Shape.RING:
				var ang := TAU * i / maxf(1.0, s.count)
				at = c + Vector2.from_angle(ang) * s.distance
				vel = Vector2.from_angle(ang + PI / 2.0) * s.speed
			SpaceSight.Shape.STREAK, SpaceSight.Shape.TRAIL:
				var gap := s.food.radius * (3.0 if s.shape == SpaceSight.Shape.TRAIL else 2.2)
				at = from - dir * gap * i
			_:
				at = from + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, 70.0)
				vel = dir.rotated(_rng.randf_range(-0.3, 0.3)) * s.speed * _rng.randf_range(0.8, 1.2)
		out.append(_bring(s, at, vel))
	Audio.play(s.cue)
	print("space_sight: %s" % s.id)
	happened.emit(s.id, from if s.shape != SpaceSight.Shape.RING else c)
	return out


func _bring(s: SpaceSight, at: Vector2, vel: Vector2) -> SpacePlanet:
	bodies = bodies.filter(func(b): return is_instance_valid(b) and not b.eaten)
	while bodies.size() >= MAX_BODIES:
		var old: SpacePlanet = bodies.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var p := stage().drift._small(KIND, s.food, at, vel)
	p.set_meta("space_sight", s.id)
	bodies.append(p)
	return p
