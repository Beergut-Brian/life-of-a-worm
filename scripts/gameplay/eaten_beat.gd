## The eaten camera beat (P-14): when something bigger gulps this worm, the shared camera moves to
## the bite, no words:
##   t = 0     the camera's centre slides to the middle of the bite (the worm and whatever ate it),
##             so the creature that did it is on screen, drawn mid-gulp; one whole-pixel step closer
##             (PolarCamera.lean_in), the fit still never cuts a worm off; a small extra shake;
##   t = LIFE  the camera lets go and drifts back to the worms.
## The worm is never moved by the beat (the gulp itself already pops it out, Gulp / Worm.get_eaten,
## which also plays the `eaten` cue and the dizzy stars). Only a PolarCamera is steered; a camera
## somebody else is centring (the planet chomp shot) is left alone.
## A child of worm.tscn, so every level that uses the worm gets it without new level code.
class_name EatenBeat
extends Node

signal beat(player: int, creature: StringName, eater: Node2D)

## Seconds the camera holds on the bite.
const LIFE := 1.2
## px (times the worm's size factor): the nearest creature this close to the worm is the eater.
const REACH := 220.0
## Extra camera shake at the bite.
const SHAKE := 0.45
## Camera meta naming the EatenBeat that is steering it now.
const OWNER := &"eaten_beat"

## Every beat played: {player, creature, eater (bool: one was found), centre}.
var history: Array[Dictionary] = []
## The camera to steer; found from the viewport when null.
var camera: PolarCamera

var _t := -1.0
var _eater: Node2D
var _bite := Vector2.ZERO   # the eater's position (the head when none was found)
var _centre := Vector2.ZERO
var _cam: PolarCamera


func _ready() -> void:
	# Before the camera's own _process, so the centre it steps toward this frame is ours.
	process_priority = -10
	var w := get_parent()
	if w != null and w.has_signal(&"eaten_by"):
		w.eaten_by.connect(_on_eaten)


func _exit_tree() -> void:
	_release()


func is_playing() -> bool:
	return _t >= 0.0


func _on_eaten(player: int, creature: StringName) -> void:
	var w := get_parent() as Node2D
	var cam := camera
	if cam == null and is_inside_tree():
		cam = get_viewport().get_camera_2d() as PolarCamera
	if w == null or cam == null:
		return
	var head: Vector2 = w.head_position() if w.has_method("head_position") else w.global_position
	_eater = find_eater(w, head)
	_bite = head if _eater == null else _eater.global_position
	if cam.centre_override != null and not cam.has_meta(OWNER):
		return   # someone else's shot owns the camera
	var prev = cam.get_meta(OWNER) if cam.has_meta(OWNER) else null
	if prev is EatenBeat and prev != self and is_instance_valid(prev):
		prev._handed_over()
	elif prev == null:
		cam.lean_in += 1
	_cam = cam
	_cam.set_meta(OWNER, self)
	_cam.shake = maxf(_cam.shake, SHAKE)
	_t = 0.0
	_centre = centre_for(_cam, _bite)
	_cam.centre_override = _centre
	history.append({ "player": player, "creature": creature, "eater": _eater != null, "centre": _centre })
	beat.emit(player, creature, _eater)


## The creature that just bit: the nearest one in the `creatures` group within REACH of the head.
static func find_eater(w: Node2D, head: Vector2) -> Node2D:
	var k: float = w.size_factor() if w.has_method("size_factor") else 1.0
	var best: Node2D = null
	var best_d := REACH * maxf(1.0, k)
	for c in w.get_tree().get_nodes_in_group(&"creatures"):
		if not (c is Node2D) or not c.is_inside_tree():
			continue
		var d: float = c.global_position.distance_to(head)
		if d < best_d:
			best_d = d
			best = c
	return best


## Where the camera centres: the middle of the box round every worm the camera frames and the
## creature that bit (`bite`: its position, or the worm's head when none was found), so the bite is
## in view and a partner far away still pulls the centre toward them.
static func centre_for(cam: PolarCamera, bite: Vector2) -> Vector2:
	var lo := bite
	var hi := bite
	for t in cam.targets:
		if is_instance_valid(t):
			var p := PolarCamera._tpos(t)
			lo = lo.min(p)
			hi = hi.max(p)
	return (lo + hi) * 0.5


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	if _cam == null or not is_instance_valid(_cam) or _cam.get_meta(OWNER, null) != self:
		_t = -1.0
		_cam = null
		return
	_t += delta
	if _t >= LIFE:
		_release()
		return
	# A creature that walks on stays on screen; the worm is never touched.
	if _eater != null and is_instance_valid(_eater) and _eater.is_inside_tree():
		_bite = _eater.global_position
	if _cam.centre_override == _centre:
		_centre = centre_for(_cam, _bite)
		_cam.centre_override = _centre
	else:
		_release()   # another shot took the camera: let it


## Another worm got eaten mid-beat: it takes the camera (and our lean step) over.
func _handed_over() -> void:
	_t = -1.0
	_cam = null


func _release() -> void:
	if _cam != null and is_instance_valid(_cam) and _cam.get_meta(OWNER, null) == self:
		if _cam.centre_override == _centre:
			_cam.centre_override = null
		_cam.lean_in = maxi(0, _cam.lean_in - 1)
		_cam.remove_meta(OWNER)
	_cam = null
	_t = -1.0
