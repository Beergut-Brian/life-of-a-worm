## S-17: space remembers the worms. A child of the SpaceStage scene (scenes/levels/space_stage.tscn)
## that keeps, in the tin's `space_worms` key, how long each worm has grown in space (SpaceWorm
## segments: every bite adds one), the shape of its body (its trail), where the worms are from each
## other, and where the drifting planet (or the sun) is from them and how it is moving. Reopening the
## tin puts it all back, so a worm that grew long out there is still long, curled the same way, with
## the same planet beside it. The drift's visit, meal and ecology were already kept (SpaceDrift).
##
## Space has no landmarks (the starfield tiles round the camera), so positions are kept relative to
## the worms' centre and put back round the stage's own start point: the arrival shot still opens
## where the planet was eaten and eases to the worms, exactly as on a first visit.
##
## Saved on every bite, every SAVE_EVERY seconds and when the stage leaves the tree. It moves
## worms only once, while the stage is being built, before the first physics step (collisions off
## for that step, so nothing gets launched); after that it only reads them.
class_name SpaceKeep
extends Node

const SAVE_KEY := "space_worms"
const SAVE_EVERY := 5.0
## Every Nth trail point is saved (the trail keeps a point per ~2 px; segments sit ~38 px apart).
const TRAIL_STEP := 6
## Trail points kept per worm, after the step (enough for the longest body the trail can draw).
const TRAIL_KEEP := 100

var stage: SpaceStage
## True once a saved state was put back this visit (tests and frames read it).
var restored := false
var _t := 0.0
var _hooked := false


func _ready() -> void:
	name = "SpaceKeep"
	stage = get_parent() as SpaceStage
	if stage == null:
		return
	if stage.is_node_ready():
		_hook()
	else:
		stage.ready.connect(_hook, CONNECT_ONE_SHOT)


func _hook() -> void:
	_hooked = true
	restore(Save.get_value(SAVE_KEY, {}))
	stage.ate.connect(func(_p, _w, _g): save())
	if stage.drift != null:
		stage.drift.arrived.connect(func(_b): save())


func _process(delta: float) -> void:
	if not _hooked:
		return
	_t += delta
	if _t >= SAVE_EVERY:
		_t = 0.0
		save()


func _exit_tree() -> void:
	if _hooked:
		save()


## The state as the tin keeps it: {"worms": {player: {seg, at, trail, face}}, "big": {...}}.
func to_save() -> Dictionary:
	var c := stage.worms_centre()
	var worms := {}
	for w in stage.worms:
		if not is_instance_valid(w):
			continue
		var trail: Array = []
		var tr: PackedVector2Array = w._trail
		for i in range(0, mini(tr.size(), TRAIL_STEP * TRAIL_KEEP), TRAIL_STEP):
			var p := tr[i] - w.global_position
			trail.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1)])
		worms[str(w.player)] = {
			"seg": w.segments,
			"at": _v(w.position - c),
			"face": _v(w._facing),
			"trail": trail,
		}
	var out := {"worms": worms}
	var b := _big()
	if b != null:
		out["big"] = {"id": _big_id(b), "at": _v(b.position - c), "vel": _v(b.linear_velocity)}
	return out


func save() -> void:
	if stage == null or stage.worms.is_empty():
		return
	Save.set_value(SAVE_KEY, to_save())


## Put a saved state back (called once while the stage is being built).
func restore(saved) -> void:
	if not (saved is Dictionary) or saved.is_empty() or stage.worms.is_empty():
		return
	var c := stage.worms_centre()
	var wd: Dictionary = saved.get("worms", {})
	var moved: Array[CollisionObject2D] = []
	for w in stage.worms:
		var s = wd.get(str(w.player))
		if not (s is Dictionary):
			continue
		w.segments = maxi(w.segments, int(s.get("seg", w.segments)))
		_quiet(w, moved)
		w.position = c + _vec(s.get("at"), w.position - c)
		var face := _vec(s.get("face"), Vector2.RIGHT)
		if face.length() > 0.01:
			w._facing = face.normalized()
		w._trail = _trail(w, s.get("trail", []))
		w.queue_redraw()
		restored = true
	var bs = saved.get("big")
	var b := _big()
	if bs is Dictionary and b != null and String(bs.get("id", "")) == _big_id(b):
		_quiet(b, moved)
		b.position = c + _vec(bs.get("at"), b.position - c)
		var vel := _vec(bs.get("vel"), b.linear_velocity)
		b.linear_velocity = vel
		b.drift = vel
	if not moved.is_empty():
		_wake_later(moved)


## A full 2 px trail behind the head through the saved points (straight behind the face if none).
func _trail(w: SpaceWorm, pts: Array) -> PackedVector2Array:
	var keys: Array[Vector2] = [w.global_position]
	for p in pts:
		if p is Array and p.size() == 2:
			keys.append(w.global_position + Vector2(float(p[0]), float(p[1])))
	var need := (w.segments + 2) * w.seg_radius
	var have := 0.0
	for i in range(1, keys.size()):
		have += keys[i].distance_to(keys[i - 1])
	if have < need:   # too short for the body: carry on straight from the tail end
		var last := keys[keys.size() - 1]
		var back := (last - keys[keys.size() - 2]).normalized() if keys.size() > 1 else -w._facing
		if back.length() < 0.5:
			back = -w._facing
		keys.append(last + back * (need - have))
	var out := PackedVector2Array()
	for i in range(1, keys.size()):
		var a := keys[i - 1]
		var d := keys[i].distance_to(a)
		var n := maxi(1, roundi(d / 2.0))
		for k in n:
			out.append(a.lerp(keys[i], float(k) / n))
	out.append(keys[keys.size() - 1])
	if out.size() > 600:
		out.resize(600)
	return out


func _big() -> SpacePlanet:
	var d := stage.drift
	if d == null:
		return null
	var b: SpacePlanet = d.big if d.big != null else d.sun
	return b if is_instance_valid(b) and not b.eaten else null


func _big_id(b: SpacePlanet) -> String:
	return "sun" if b.kind == &"sun" else (String(b.data.id) if b.data != null else String(b.theme))


## Collisions off while it is placed, back on after the first physics steps.
func _quiet(o: CollisionObject2D, moved: Array[CollisionObject2D]) -> void:
	o.set_meta(&"keep_layers", Vector2i(o.collision_layer, o.collision_mask))
	o.collision_layer = 0
	o.collision_mask = 0
	moved.append(o)


func _wake_later(moved: Array[CollisionObject2D]) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	for o in moved:
		if is_instance_valid(o) and o.has_meta(&"keep_layers"):
			var l: Vector2i = o.get_meta(&"keep_layers")
			o.collision_layer = l.x
			o.collision_mask = l.y
			o.remove_meta(&"keep_layers")


static func _v(v: Vector2) -> Array:
	return [snappedf(v.x, 0.1), snappedf(v.y, 0.1)]


static func _vec(a, fallback: Vector2) -> Vector2:
	if a is Array and a.size() == 2:
		return Vector2(float(a[0]), float(a[1]))
	return fallback
