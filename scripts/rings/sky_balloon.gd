## A balloon stuck in the sky (X-06), placed from data/rings/sky_life.tres (SkyLife.balloon_*).
## It bobs on its string just above the grass; the string ends in a tie (a RingPickup of
## data/foods/<balloon_tie>.tres, sky-sized: a smaller worm bonks off it and the tie looks smug).
## Eating the tie pops the balloon, once per tin (RingsDirector saves it under "balloon"):
## the cause is on screen where it happens: the string snaps at the worm's mouth and whips up, the
## balloon bursts into scraps and a ring, the camera gets a short nudge, the worm swells, and the
## "segment_pop" cue plays. Nothing moves the worm. Placeholder drawing, no new art.
class_name SkyBalloon
extends Node2D

signal popped(player: int)

const CUE := "segment_pop"
const POP_TIME := 1.3
const SHAKE := 0.45
const RADII := Vector2(26.0, 32.0)

var sky: SkyLife
var director: RingsDirector
var is_popped := false
## Seconds since the pop (< 0 when not playing).
var pop_t := -1.0
## The player whose bite popped it (-1: none yet).
var popped_by := -1
var tie: RingPickup

var _t := 0.0
var _scraps: Array[Vector2] = []


func _ready() -> void:
	z_index = 1
	_t = 1.7
	if not is_popped:
		_make_tie()


## Back up on its string with a fresh tie (frames and tests only; a popped balloon stays popped).
func reset() -> void:
	is_popped = false
	pop_t = -1.0
	popped_by = -1
	if not is_instance_valid(tie) or tie.is_queued_for_deletion():
		_make_tie()
	queue_redraw()


func _make_tie() -> void:
	tie = RingPickup.new()
	tie.name = "Tie"
	tie.data = load("res://data/foods/%s.tres" % sky.balloon_tie)
	tie.position = _tie_at()
	add_child(tie)
	tie.home = tie.position
	tie.taken.connect(_on_tie_taken)


## Up, away from the core, at the balloon (local frame: the string hangs toward the core).
func up() -> Vector2:
	return position.normalized() if position != Vector2.ZERO else Vector2.UP


func _tie_at() -> Vector2:
	return -up() * sky.balloon_string


func _on_tie_taken(_f: ArenaFood) -> void:
	var by := -1
	var best := INF
	for w in Worm.all():
		var d := w.mouth_position().distance_to(tie.global_position)
		if d < best:
			best = d
			by = w.player
	pop(by)


## Pops the balloon (the tie was eaten by player; -1 = nobody, e.g. a test).
func pop(player := -1) -> void:
	if is_popped:
		return
	is_popped = true
	popped_by = player
	pop_t = 0.0
	Audio.play(CUE)
	var juice := WormHooks.juice()
	juice.shake(SHAKE)
	var cam = director.level.get("camera") if director != null and director.level != null else null
	if cam is PolarCamera and SettingsPanel.screen_shake():
		cam.shake = maxf(cam.shake, SHAKE)
	_scraps.clear()
	for i in 14:
		_scraps.append(Vector2.from_angle(TAU * i / 14.0 + 0.3) * (0.7 + 0.3 * (i % 3)))
	var w := Worm.of(player) if player >= 0 else null
	if w:
		w.swell(1.4)
	if is_instance_valid(tie) and not tie.is_queued_for_deletion():
		tie.queue_free()
	if director:
		director.balloon_popped(player)
	popped.emit(player)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if pop_t >= 0.0:
		pop_t += delta
		if pop_t > POP_TIME:
			pop_t = -1.0
	if not is_popped or pop_t >= 0.0:
		queue_redraw()


func _draw() -> void:
	if sky == null:
		return
	var u := up()
	var side := u.orthogonal()
	var col := sky.balloon_color
	var ink := Color("1b1420")
	if is_popped:
		if pop_t < 0.0:
			return
		var k := pop_t / POP_TIME
		var a := 1.0 - k
		# the burst: a ring and scraps flying out of where the balloon was
		draw_arc(Vector2.ZERO, 16.0 + 150.0 * k, 0.0, TAU, 40, Color(1, 1, 1, a * 0.9), 5.0)
		draw_circle(Vector2.ZERO, 40.0 * (1.0 - k) * (1.0 - k), Color(1, 1, 0.85, a))
		for s in _scraps:
			var p := s * (24.0 + 170.0 * k) - u * 60.0 * k * k
			draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color(col, a))
		# the snapped string whips up toward where the balloon was, from the worm's bite
		var cut := _tie_at()
		var top := cut.lerp(Vector2.ZERO, minf(1.0, k * 2.5))
		var wob := side * sin(k * 30.0) * 6.0 * a
		draw_polyline(PackedVector2Array([cut, (cut + top) * 0.5 + wob, top]), Color(0.95, 0.95, 0.9, a), 3.0)
		draw_circle(cut, 10.0 + 22.0 * k, Color(1, 0.95, 0.6, a * 0.6))
		return
	var bob := u * sin(_t * 1.6) * 2.0 + side * sin(_t * 0.9) * 2.5
	var knot := bob - u * RADII.y
	# string: a gentle S down to the tie
	var tie_p := _tie_at()
	var pts := PackedVector2Array()
	for i in 9:
		var f := i / 8.0
		pts.append(knot.lerp(tie_p, f) + side * sin(f * PI * 2.0 + _t * 1.2) * 3.0 * (1.0 - f))
	draw_polyline(pts, ink, 2.5)
	draw_polyline(pts, Color(0.95, 0.95, 0.9), 1.2)
	# balloon: an oval along "up", a shine, a knot
	var outline := PackedVector2Array()
	var body := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		outline.append(bob + side * cos(a) * (RADII.x + 1.5) + u * sin(a) * (RADII.y + 1.5))
		body.append(bob + side * cos(a) * RADII.x + u * sin(a) * RADII.y)
	draw_colored_polygon(outline, ink)
	draw_colored_polygon(body, col)
	draw_circle(bob + side * -RADII.x * 0.4 + u * RADII.y * 0.45, 3.5, Color(1, 1, 1, 0.75))
	draw_colored_polygon(PackedVector2Array([knot, knot - u * 5.0 + side * 3.5, knot - u * 5.0 - side * 3.5]), col.darkened(0.25))
