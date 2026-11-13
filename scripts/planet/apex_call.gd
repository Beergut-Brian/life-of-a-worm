## P-16 "a visible reason": a worm that is long enough for its next stage but has not eaten that
## ring's apex yet stays at its stage. That wait needs a cause on screen, with no words, so a little
## picture bubble bobs beside the worm's head: the apex it still has to eat (its shell colour as the
## player met it, wide eyes, a sweat drop) and an arrow pointing the way to it. It plays
## `beetle_blink` once when it first shows for a worm at a stage. It hides when the apex is close
## enough to see (ApexBeetle.NOTICE), when the apex is gone, and in a gate-free (demo) worm. It never
## moves or steers anything. One per PlanetLevel (child of the level, drawn above the actors).
class_name ApexCall
extends Node2D

const CUE := "beetle_blink"
## px from the head centre to the bubble, and the bubble radius, at stage-1 size (x size_factor).
const OFFSET := 46.0
const BUBBLE := 17.0

var level: PlanetLevel
## player -> the stage it last called at (the cue plays once per worm per stage).
var _called := {}
var _t := 0.0


func _ready() -> void:
	z_index = 20


## The apex this worm is waiting on, or null: long enough, gate on, the apex still there and far.
func waiting_on(w: Worm) -> ApexBeetle:
	if level == null or w == null or w.model == null or not w.model.apex_gate:
		return null
	if w.model.stage >= w.rules.max_stage() or w.model.apex_cap() > w.model.stage:
		return null
	for a in level.apexes:
		if a.ring_stage == w.model.stage and not a.is_gone() and a.is_food_for(w):
			if a.global_position.distance_to(w.cam_position()) > ApexBeetle.NOTICE:
				return a
	return null


func _process(delta: float) -> void:
	step(delta)


## One tick (tests call it directly).
func step(delta: float) -> void:
	_t += delta
	for w in Worm.all():
		if waiting_on(w) != null and _called.get(w.player, 0) != w.model.stage:
			_called[w.player] = w.model.stage
			Audio.play(CUE)
	queue_redraw()


func _draw() -> void:
	for w in Worm.all():
		var a := waiting_on(w)
		if a == null:
			continue
		var k := w.size_factor()
		var head := to_local(w.cam_position())
		var dir := (to_local(a.global_position) - head).normalized()
		var bob := sin(_t * 3.0) * 2.0 * k
		var c := head + dir * (OFFSET * k + bob)
		var r := BUBBLE * k
		var rim := Color("2a1a14")
		# The arrow: a fat triangle past the bubble, pointing the way.
		var side := dir.orthogonal()
		var tip := c + dir * (r * 1.9)
		var tri := PackedVector2Array([tip, c + dir * r * 0.9 + side * r * 0.65, c + dir * r * 0.9 - side * r * 0.65])
		draw_colored_polygon(tri, rim)
		var tri_in := PackedVector2Array([tip - dir * 2.0 * k, c + dir * r * 1.05 + side * r * 0.4, c + dir * r * 1.05 - side * r * 0.4])
		draw_colored_polygon(tri_in, Color(1, 0.92, 0.6))
		# The bubble, in the player's colour ring.
		draw_circle(c, r + 2.0 * k, rim)
		draw_circle(c, r + 1.0 * k, Players.COLOR.get(w.player, Color.WHITE))
		draw_circle(c, r, Color(1, 0.98, 0.92))
		# The apex inside it, in the colour the player met it in, wide-eyed and sweating (it knows).
		var shell := ApexBeetle.shell_color(a.look, false)
		var br := r * 0.55
		draw_circle(c, br + 1.5 * k, rim)
		draw_circle(c, br, shell)
		for sgn in [-1.0, 1.0]:
			var e := c + Vector2(sgn * br * 0.4, -br * 0.15)
			draw_circle(e, br * 0.32, Color.WHITE)
			draw_circle(e, br * 0.16, Color.BLACK)
		draw_circle(c + Vector2(br * 0.9, -br * 0.9 + sin(_t * 9.0) * k), br * 0.22, Color("7fd6ff"))
