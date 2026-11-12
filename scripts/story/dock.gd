## The grey-box dock set for every story scene: the bank with Old Reel's shed, the dock over the
## pond, the far shore with the hill and the tree, the sky with the moon, and the dirt under the
## bank where Gulp and Burp land. One background lit four ways (dawn / noon / dusk / night) by a
## tint, plus the warm flashback grade. Placeholder shapes only (look pick D92 is open).
##
## Background clues are numbers in `state` that the scenes tween (`clue`). `prepare(id)` sets what
## the world already looks like when a scene starts (a tree eaten in stage 3 stays gone after).
## The Strangestone under the bait tin always pulses softly; nobody ever mentions it.
class_name StoryDock
extends Node2D

const ORDER: Array[StringName] = [&"opening", &"stage_2", &"stage_3", &"stage_4", &"stage_5", &"stage_6", &"stage_7", &"ending"]
const TINTS := {
	"dawn": Color(1.0, 0.86, 0.82),
	"noon": Color(1, 1, 1),
	"dusk": Color(1.0, 0.72, 0.58),
	"night": Color(0.42, 0.48, 0.78),
}
const SKY := {
	"dawn": [Color("f7b39a"), Color("ffe2b8")],
	"noon": [Color("6fc3ff"), Color("c4ecff")],
	"dusk": [Color("5b3f7a"), Color("ff9a62")],
	"night": [Color("0c1030"), Color("2a2f5e")],
}
const WARM := Color(1.12, 0.9, 0.62)
const INK := Color("3a2a44")
const STRANGE := Color("7ff0d0")

## Clue and lighting state. Every value is tweenable.
var state := {}
var tod := "dawn"
var _t := 0.0
var _tweens: Array[Tween] = []

@onready var camera: Camera2D = $Camera
@onready var tint: CanvasModulate = $Tint
@onready var grade: ColorRect = $Grade/Vignette


func _init() -> void:
	reset()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_time("dawn", 0.0)
	set_warm(false, 0.0)


func reset() -> void:
	state = {"tree": 1.0, "shed_sink": 0.0, "hill": 1.0, "hill_bite": 0.0, "curve": 0.0, "star": 1.0,
			"moon_bite": 0.0, "long_x": -1.0, "ripple": 0.0, "town": 0.0, "warm": 0.0}


## What the world looks like at the start of scene `id`: every earlier scene's clue has happened.
func prepare(id: StringName) -> void:
	reset()
	var i := ORDER.find(id)
	if i > 2:
		state.tree = 0.0
	if i > 3:
		state.shed_sink = 0.9
	if i > 4:
		state.hill_bite = 1.0
	if i > 5:
		state.hill = 0.0
		state.curve = 1.0
	if i > 6:
		state.star = 0.0
	queue_redraw()


func anchor(n: String) -> Vector2:
	var m := get_node_or_null(NodePath("Anchors/" + n))
	return (m as Node2D).position if m != null else Vector2.INF


func set_time(of: String, secs := 1.0) -> void:
	tod = of
	var c: Color = TINTS.get(of, Color.WHITE)
	if state.warm > 0.5:
		c = c * WARM
	_to(tint, "color", c, secs)


func set_warm(on: bool, secs := 0.6) -> void:
	state.warm = 1.0 if on else 0.0
	var c: Color = TINTS.get(tod, Color.WHITE)
	_to(tint, "color", c * WARM if on else c, secs)
	_to(grade, "modulate:a", 1.0 if on else 0.0, secs)


## Tween a clue value (see `state`) to `to` over `secs`.
func clue(what: String, to: float, secs := 1.5) -> void:
	if not state.has(what):
		push_warning("StoryDock: unknown clue '%s'" % what)
		return
	if secs <= 0.0 or not is_inside_tree():
		state[what] = to
		return
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: state[what] = v, float(state[what]), to, secs)
	_tweens.append(tw)


func _to(node: Object, prop: String, v, secs: float) -> void:
	if node == null:
		return
	if secs <= 0.0 or not is_inside_tree():
		node.set_indexed(prop, v)
		return
	create_tween().tween_property(node, prop, v, secs)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


# --- drawing -------------------------------------------------------------------------------------

func _draw() -> void:
	_draw_sky()
	_draw_far_shore()
	_draw_shed()
	_draw_pond()
	_draw_bank()
	_draw_tunnels()
	_draw_dock()
	_draw_rods()


func _draw_sky() -> void:
	var cols: Array = SKY.get(tod, SKY.noon)
	for i in 12:
		var f := i / 11.0
		draw_rect(Rect2(-480, -330 + i * 28, 960, 29), (cols[0] as Color).lerp(cols[1], f))
	if tod == "night" or tod == "dusk":
		var a := 1.0 if tod == "night" else 0.35
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 40:
			var p := Vector2(rng.randf_range(-440, 440), rng.randf_range(-320, -40))
			draw_rect(Rect2(p, Vector2(1, 1)), Color(1, 1, 0.9, a * (0.5 + 0.5 * sin(_t * 2.0 + i))))
		# The one bright star that winks out in stage 7.
		var s := float(state.star)
		if s > 0.01:
			var c := Vector2(-60, -190)
			draw_rect(Rect2(c - Vector2(1, 1) * 1.5 * s, Vector2(3, 3) * s), Color(1, 1, 0.8, a))
			draw_line(c - Vector2(4, 0) * s, c + Vector2(4, 0) * s, Color(1, 1, 0.8, a * 0.7), 1.0)
			draw_line(c - Vector2(0, 4) * s, c + Vector2(0, 4) * s, Color(1, 1, 0.8, a * 0.7), 1.0)
	# Moon (a bite missing at the ending).
	var mc := Vector2(130, -150)
	draw_circle(mc, 14, Color("fff4d0") if tod != "noon" else Color(1, 1, 1, 0.5))
	var mb := float(state.moon_bite)
	if mb > 0.01:
		var cols2: Array = SKY.get(tod, SKY.noon)
		var bite_col: Color = (cols2[0] as Color).lerp(cols2[1], 0.62)
		for k in 3:
			draw_circle(mc + Vector2(11, -7) + Vector2(k * 2 - 2, k * 3 - 3), 6.0 * mb, bite_col)
	# The long shape drifting past the stars (ending): a segmented silhouette with one sleepy eye.
	var lx := float(state.long_x)
	if lx >= 0.0:
		var x0 := lerpf(-520, 520, lx)
		for i in 14:
			var p := Vector2(x0 - i * 13, -232 + sin(i * 0.7 + _t * 1.5) * 9)
			draw_circle(p, 8.0 - i * 0.25, Color("10122a"))
		draw_circle(Vector2(x0 + 3, -235 + sin(_t * 1.5) * 9), 1.3, Color("ffd23f"))


func _draw_far_shore() -> void:
	var y := -8.0
	var curve := float(state.curve)
	var land := Color("4f8a3c")
	# Far shore strip; in stage 6 the horizon bends (the planet is getting small).
	var pts := PackedVector2Array()
	for i in 25:
		var x := -480 + i * 40.0
		pts.append(Vector2(x, y + curve * pow(x / 480.0, 2) * 46.0))
	pts.append(Vector2(480, 200))
	pts.append(Vector2(-480, 200))
	draw_colored_polygon(pts, land)
	# The hill (stage 5 bite, stage 6 gone).
	var h := float(state.hill)
	if h > 0.05:
		var hc := Vector2(-200, y)
		var hp := PackedVector2Array()
		for i in 21:
			var a := PI * i / 20.0
			hp.append(hc + Vector2(cos(a) * 90, -sin(a) * 58 * h))
		draw_colored_polygon(hp, Color("5d9a46"))
		var hb := float(state.hill_bite)
		if hb > 0.01:
			var cols: Array = SKY.get(tod, SKY.noon)
			var bite_col: Color = (cols[0] as Color).lerp(cols[1], 0.85)
			for k in 3:
				draw_circle(hc + Vector2(30 + k * 10, -50 * h + k * 6), 14.0 * hb, bite_col)
	# Townsfolk watching the hill (stage 5 flashback): little silhouettes on the far shore.
	var town := float(state.town)
	if town > 0.01:
		for i in 9:
			var p := Vector2(-110 + i * 9, y - 1)
			var hop := absf(sin(_t * 6.0 + i)) * 1.5 if i == 4 else 0.0
			draw_rect(Rect2(p + Vector2(-2, -7 - hop), Vector2(4, 7)), Color(INK, town))
			draw_circle(p + Vector2(0, -9 - hop), 2.0, Color(INK, town))
	# The tree on the far shore (eaten in stage 3: it sinks into the ground).
	var t := float(state.tree)
	if t > 0.01:
		var tb := Vector2(200, y + (1.0 - t) * 30)
		draw_rect(Rect2(tb + Vector2(-2, -18), Vector2(4, 18)), Color("6b4a2e"))
		draw_circle(tb + Vector2(0, -24), 11, Color("2f6b2a"))
		draw_circle(tb + Vector2(-6, -20), 7, Color("2f6b2a"))
		draw_circle(tb + Vector2(6, -20), 7, Color("2f6b2a"))
		draw_rect(Rect2(150, y, 100, 30), land)   # ground covers the sinking part


func _draw_shed() -> void:
	var sink := float(state.shed_sink) * 40.0
	var b := Vector2(-120, 0 + sink)
	draw_rect(Rect2(b + Vector2(-22, -26), Vector2(44, 26)), Color("8a5a3c"))
	draw_rect(Rect2(b + Vector2(-6, -16), Vector2(12, 16)), Color("4a2e22"))
	draw_colored_polygon(PackedVector2Array([b + Vector2(-26, -26), b + Vector2(0, -40), b + Vector2(26, -26)]), Color("a33b2e"))
	draw_rect(Rect2(b + Vector2(10, -22), Vector2(7, 6)), Color("ffe9a0") if tod == "night" else Color("9ad0e8"))


func _draw_pond() -> void:
	draw_rect(Rect2(-20, 4, 500, 90), Color("3a7fb5"))
	draw_rect(Rect2(-20, 4, 500, 2), Color("8fd0ff"))
	draw_rect(Rect2(-20, 60, 500, 60), Color("2c4a5e"))
	var r := float(state.ripple)
	if r > 0.01:
		# Something big moves under the water: a long dark shape, rings spreading, bubbles popping.
		var c := Vector2(230, 6)
		for i in 8:
			var p := c + Vector2(-34 + i * 9 + sin(_t * 0.8) * 6, 22 + sin(_t * 2.0 + i * 0.6) * 2)
			draw_circle(p, (6.0 - absf(i - 3.5) * 0.6) * r, Color(0.08, 0.16, 0.24, 0.55 * r))
		for k in 3:
			var f := fmod(_t * 0.6 + k / 3.0, 1.0)
			var rad := 4.0 + f * 40.0
			draw_arc(c, rad, PI, TAU, 32, Color(0.85, 0.95, 1.0, r * (1.0 - f)), 2.0)
			draw_line(c + Vector2(-rad, 0), c + Vector2(rad, 0), Color(0.85, 0.95, 1.0, 0.5 * r * (1.0 - f)), 1.0)
		for k in 4:
			var f := fmod(_t * 0.9 + k / 4.0, 1.0)
			draw_arc(c + Vector2(-8 + k * 5, 18 - f * 16), 1.5, 0, TAU, 8, Color(0.9, 0.97, 1.0, r * (1.0 - f * 0.5)), 1.0)


func _draw_bank() -> void:
	# The bank and the ground under it: grass, topsoil, dirt (the rings the worms start in).
	draw_rect(Rect2(-480, 0, 460, 3), Color("5aa83e"))
	draw_rect(Rect2(-480, 3, 460, 30), Color("6b4a2e"))
	draw_rect(Rect2(-480, 33, 460, 300), Color("4e3424"))
	draw_rect(Rect2(-20, 3, 4, 330), Color("4e3424"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 60:
		var p := Vector2(rng.randf_range(-470, -30), rng.randf_range(8, 300))
		draw_rect(Rect2(p, Vector2(2, 2)), Color("3a261a"))
	# The Strangestone the bait tin sits on: softly pulsing, never said out loud.
	var sc := Vector2(-6, 0)
	var pulse := 0.55 + 0.45 * sin(_t * 1.7)
	draw_circle(sc + Vector2(0, 1), 9.0 + pulse * 2.0, Color(STRANGE, 0.12 * pulse))
	draw_colored_polygon(PackedVector2Array([sc + Vector2(-7, 2), sc + Vector2(-5, -4), sc + Vector2(3, -6), sc + Vector2(7, -1), sc + Vector2(5, 3)]), Color("2b5a5a"))
	draw_line(sc + Vector2(-3, -2), sc + Vector2(2, -4), Color(STRANGE, 0.5 + 0.5 * pulse), 1.0)
	# The bait tin on top.
	draw_rect(Rect2(sc + Vector2(-5, -11), Vector2(10, 6)), Color("9aa3ad"))
	draw_rect(Rect2(sc + Vector2(-5, -12), Vector2(10, 1.5)), Color("c7ced6"))


## Gulp and Burp dig in from where they plopped: a dark tunnel follows each one down.
func _draw_tunnels() -> void:
	var start := anchor("plop")
	if start == Vector2.INF:
		return
	for n in [^"Gulp", ^"Burp"]:
		var w := get_node_or_null(n) as Node2D
		if w != null and w.visible and w.position.y > start.y + 1.0:
			draw_line(start, w.position + Vector2(0, -2), Color("24160e"), 5.0)


func _draw_dock() -> void:
	draw_rect(Rect2(-24, -3, 170, 4), Color("a07a4e"))
	for i in 18:
		draw_line(Vector2(-24 + i * 10, -3), Vector2(-24 + i * 10, 1), Color("7a5a38"), 1.0)
	for x in [-10, 40, 90, 140]:
		draw_rect(Rect2(x, 1, 4, 40), Color("6b4a2e"))


func _draw_rods() -> void:
	# Fishing rods from the sitters to the water; Bobber's hook has a sandwich on it.
	var reel := get_node_or_null(^"Reel") as Node2D
	var bob := get_node_or_null(^"Bobber") as Node2D
	if bob != null and bob.visible and String(bob.get("pose")) != "sleep":
		var tip := bob.position + Vector2(18, -22)
		draw_line(bob.position + Vector2(2, -8), tip, Color("6b4a2e"), 1.0)
		var bait := Vector2(tip.x + 10, 5 + sin(_t * 2.0))
		draw_line(tip, bait + Vector2(0, -3), Color(1, 1, 1, 0.6), 1.0)
		draw_rect(Rect2(bait + Vector2(-3, -3), Vector2(6, 2)), Color("e8c27a"))   # bread
		draw_rect(Rect2(bait + Vector2(-3, -1), Vector2(6, 1)), Color("6cb14a"))   # lettuce
		draw_rect(Rect2(bait + Vector2(-3, 0), Vector2(6, 2)), Color("e8c27a"))
	var young := get_node_or_null(^"YoungReel") as Node2D
	var gulp := get_node_or_null(^"Gulp") as Node2D
	if young != null and young.visible and gulp != null and gulp.visible and gulp.position.y < -4:
		var tip3 := young.position + Vector2(22, -32)
		draw_line(young.position + Vector2(4, -12), tip3, Color("6b4a2e"), 1.0)
		draw_line(tip3, gulp.position + Vector2(0, -3), Color(1, 1, 1, 0.6), 1.0)
	if reel != null and reel.visible and float(reel.get("hands")) <= 0.0 and String(reel.get("pose")) == "idle":
		var tip2 := reel.position + Vector2(26, -30)
		draw_line(reel.position + Vector2(4, -12), tip2, Color("6b4a2e"), 1.0)
		draw_line(tip2, Vector2(tip2.x + 6, 6), Color(1, 1, 1, 0.5), 1.0)
