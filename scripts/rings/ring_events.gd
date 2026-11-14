## Plays the rings' visible events (RingEvent, data in RingLife.events) for the worms in them
## (D105 content). A RingsDirector child, stepped from RingsDirector.tick on the planet clock: each
## event counts the planet seconds some worm of its stage spends in its ring, and when the count
## reaches first_after (then every) it happens beside that worm. The foods it brings are ordinary
## RingPickups (not saved; at most MAX_FOODS about, the oldest goes first). Signal happened(id, at).
class_name RingEvents
extends Node

signal happened(id: StringName, at: Vector2)

const MAX_FOODS := 24
## FALL: px above the landing spot a falling food starts, and how long it takes to land.
const FALL_FROM := 150.0
const FALL_TIME := 0.9

var director: RingsDirector
var events: Array[RingEvent] = []
var foods: Array[RingPickup] = []
## id -> planet seconds counted toward the next one; id -> times it happened this session.
var waited: Dictionary = {}
var times: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func setup(d: RingsDirector, lives: Array, seed_value := 1) -> void:
	director = d
	_rng.seed = seed_value * 31 + 5
	for life in lives:
		for e: RingEvent in life.events:
			events.append(e)
			waited[e.id] = 0.0
			times[e.id] = 0


static func all_events(lives: Array) -> Array[RingEvent]:
	var out: Array[RingEvent] = []
	for life in lives:
		if life is RingLife:
			out.append_array((life as RingLife).events)
	return out


func step(dt: float) -> void:
	if director == null or director.world == null:
		return
	for e in events:
		var w := worm_for(e)
		if w == null:
			continue
		if e.after_rain and not director.raining:
			continue
		waited[e.id] = float(waited[e.id]) + dt
		var due := e.first_after if int(times[e.id]) == 0 else e.every
		if float(waited[e.id]) >= due:
			play(e, w)


## A worm whose head is in e's ring and whose stage is at least e.stage_from (null: none).
func worm_for(e: RingEvent) -> Worm:
	var band := director.ring_band(e.ring)
	for w in director._worms():
		if w.model.stage < e.stage_from:
			continue
		var d := director.depth_of(director.world.to_local(w.head_position()))
		if d >= band.x and d <= band.y:
			return w
	return null


## Makes e happen beside w now. Returns the foods it brought.
func play(e: RingEvent, w: Worm) -> Array[RingPickup]:
	waited[e.id] = 0.0
	times[e.id] = int(times[e.id]) + 1
	var head := director.world.to_local(w.head_position())
	var up := director.up_at(head)
	var side := up.orthogonal() * (1.0 if _rng.randf() < 0.5 else -1.0)
	var centre := _in_band(head + side * e.distance, e.ring)
	var out: Array[RingPickup] = []
	for i in e.count:
		var at: Vector2
		match e.shape:
			RingEvent.Shape.RING:
				at = _in_band(head + Vector2.from_angle(TAU * i / maxf(1.0, e.count)) * e.distance, e.ring)
			RingEvent.Shape.FALL:
				at = _in_band(centre + side * (float(i) - (e.count - 1) * 0.5) * 18.0, e.ring)
			_:
				at = _in_band(centre + Vector2.from_angle(TAU * i / maxf(1.0, e.count) + _rng.randf() * 0.5) * 22.0, e.ring)
		out.append(_bring(e, at, up))
	director._pop_fx(centre, e.fx)
	if e.shape != RingEvent.Shape.FALL:
		for p in out:
			director._pop_fx(p.position, e.fx)
	Audio.play(e.cue)
	print("ring_event: %s" % e.id)
	happened.emit(e.id, centre)
	return out


func _bring(e: RingEvent, at: Vector2, up: Vector2) -> RingPickup:
	while foods.size() >= MAX_FOODS:
		var old: RingPickup = foods.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var p := RingPickup.new()
	p.data = e.food
	p.set_meta("ring_event", e.id)
	director.actors.add_child(p)
	p.home = at
	p.taken.connect(func(f: Node2D) -> void:
		foods.erase(f)
		f.queue_free())
	foods.append(p)
	if e.shape == RingEvent.Shape.FALL:
		p.position = at + up * FALL_FROM
		p.create_tween().tween_property(p, "position", at, FALL_TIME).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	else:
		p.position = at
		p.scale = Vector2(0.2, 0.2)
		p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	return p


## p pulled into the ring's band (same angle), so a food never lands in a ring the worm can't bite.
func _in_band(p: Vector2, ring: StringName) -> Vector2:
	var band := director.ring_band(ring) * director.planet_radius_px
	var l := clampf(p.length(), band.x + 8.0, band.y - 8.0)
	return p.normalized() * l if p != Vector2.ZERO else p


func _exit_tree() -> void:
	for p in foods:
		if is_instance_valid(p):
			p.queue_free()
	foods.clear()
