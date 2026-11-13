## D-07, the pull trait's later half: "drag big objects". A worm whose stats pull (`pull_radius`,
## from whichever trait gives it) sticks a piece of junk that is too big to eat onto the horseshoe on its tail and
## drags it along on a short beam. Small junk still drifts to the mouth (worm.gd); this is only for
## the big ones. One at a time. Nothing is forced: the worm goes where the stick says; the junk
## follows. Resting still for REST_LET_GO seconds lets it go (a clunk, the beam pops off).
## Every grab and let-go is heard and seen: the trait's sting + a ring on grab (Worm._trait_moment),
## `drop` + a puff on let go, a wobbly beam in the trait's colour while dragging.
class_name PullDrag
extends Node2D

## Pixels past touching the tail (tail reach + junk radius) that still grab.
const GRAB_GAP := 10.0
## Beam length past the junk's radius: closer than this the junk does not move.
const SLACK := 16.0
## Seconds the worm must hold still to let go.
const REST_LET_GO := 1.5
## Head movement per physics frame below which the worm counts as resting.
const REST_SPEED := 0.2

var worm: Worm
## The junk on the beam (null: nothing).
var held: ArenaFood = null
## Seconds the worm has held still while dragging.
var _rest := 0.0
## The junk just let go: not grabbed again until the tail has moved off it.
var _dropped: ArenaFood = null
var _last_head := Vector2.ZERO
var _t := 0.0
## Grabs and let-gos (tests read these).
var grabs := 0
var let_gos := 0


func _ready() -> void:
	worm = get_parent() as Worm
	top_level = true   # the beam is drawn in world space
	z_index = 8


## The horseshoe's spot: the last body point (world space).
func tail_position() -> Vector2:
	var pts := worm.fit_points()
	return pts[1]


## The trait that gives the pull (its cue and colour); never named here (no special cases).
func _trait() -> TraitData:
	return worm._trait_for("pull_radius")


func beam_color() -> Color:
	var t := _trait()
	return t.color if t != null else Color(0.9, 0.76, 0.16)


func pull_radius() -> float:
	if worm == null or worm.model == null:
		return 0.0
	return worm.model.stats.value("pull_radius")


## Junk the worm cannot eat yet: the only things the pull drags.
func can_drag(f: Node) -> bool:
	if not f is ArenaFood or f == worm.carrying or f in worm.cart:
		return false
	var data: FoodData = (f as ArenaFood).data
	return data != null and data.flavour == &"junk" and not worm.can_eat(data) \
			and (f as ArenaFood).is_available()


func _physics_process(delta: float) -> void:
	if worm == null or worm.model == null or not is_instance_valid(worm.head):
		return
	_t += delta
	if held != null and (not is_instance_valid(held) or held._gone or pull_radius() <= 0.0 \
			or worm.can_eat(held.data)):
		let_go()
	var tail := tail_position()
	if held == null:
		if pull_radius() > 0.0:
			_try_grab(tail)
	else:
		_drag(tail, delta)
	_last_head = worm.head_position()
	queue_redraw()


func _try_grab(tail: Vector2) -> void:
	var reach := worm.model.stats.value("mouth_radius", 8.0)
	if _dropped != null and (not is_instance_valid(_dropped) \
			or _dropped.global_position.distance_to(tail) > reach + _dropped.data.radius + GRAB_GAP * 2.0):
		_dropped = null
	for f in get_tree().get_nodes_in_group("food"):
		if f == _dropped or not can_drag(f):
			continue
		var d: float = f.global_position.distance_to(tail)
		if d <= reach + f.data.radius + GRAB_GAP:
			held = f
			held.set_carried(true)   # off limits to bites and bonks while on the beam
			_rest = 0.0
			grabs += 1
			var cooling := worm._moment_cool > 0.0
			worm._trait_moment("pull_radius")   # the pulling trait's sting and a ring in its colour
			var t := _trait()   # null when the pull is only from shiny trophies (B-05)
			if cooling or t == null:
				Audio.play(t.cue if t != null else "carry")   # never a silent grab
			return


func _drag(tail: Vector2, delta: float) -> void:
	var moved := worm.head_position().distance_to(_last_head)
	_rest = _rest + delta if moved < REST_SPEED else 0.0
	if _rest >= REST_LET_GO:
		let_go()
		return
	var leash: float = held.data.radius + SLACK
	var off := held.global_position - tail
	if off.length() > leash:
		held.global_position = tail + off.normalized() * leash


func let_go() -> void:
	if held != null and is_instance_valid(held):
		held.set_carried(false, 0.6)
		held.home = held.position   # it stays where it was dragged (regrows there too)
		Audio.play("drop")
		var ring := WormRing.new()
		ring.color = beam_color()
		ring.life = 0.3
		ring.max_radius = 14.0
		ring.position = held.position
		held.get_parent().add_child(ring)
		let_gos += 1
		_dropped = held
	held = null
	_rest = 0.0


func _exit_tree() -> void:
	if held != null and is_instance_valid(held):
		held.set_carried(false)
	held = null


func _draw() -> void:
	if held == null or not is_instance_valid(held) or worm == null:
		return
	var a := tail_position()
	var b := held.global_position
	var n := 6
	var side := (b - a).orthogonal().normalized()
	var pts := PackedVector2Array()
	for i in n + 1:
		var k := float(i) / n
		var wob := sin(_t * 18.0 + k * TAU) * 1.5 * sin(k * PI)
		pts.append(a.lerp(b, k) + side * wob)
	var c := beam_color()
	draw_polyline(pts, c.darkened(0.45), 3.5)
	draw_polyline(pts, c, 1.8)
	draw_circle(b, 2.5, c.lightened(0.4))
