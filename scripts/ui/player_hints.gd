## One player's in-play hint panel (P-13 / C-24), text-free: a column of rows, each a controller
## glyph and a little picture of what that button does right now, edged in the player's colour.
## Rows ready this moment pulse. The rules are HintRules (pure); this node only draws them.
## The panel folds down to its lit rows after HintRules.QUIET_AFTER seconds with no change, so it
## stays out of the play area; a new context, Select or a refused press opens it again (wake()).
##   var p := PlayerHints.new(); p.player = Players.P2; hud.add_child(p)
##   p.show_context({ "carry_ready": true })   # each frame
class_name PlayerHints
extends Control

const ROW_H := 58.0
const WIDE := 150.0
const EDGE := 6.0
const MARGIN := 40.0
## How long a refused press shakes the panel.
const SHAKE_TIME := 0.45

var player := Players.P1
var ctx: Dictionary = {}
var rows: Array = []
var hot: Dictionary = {}
## Seconds the panel has left before it folds.
var awake_left := HintRules.QUIET_AFTER
var _sig: Array = []
var _shake := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Feed this player's context (HintRules ctx keys) each frame.
func show_context(next: Dictionary) -> void:
	ctx = next
	var sig := HintRules.signature(next)
	if sig != _sig:
		_sig = sig
		wake()
	hot = HintRules.hot_for(next)
	_relayout()


## Open the full panel again for QUIET_AFTER seconds.
func wake() -> void:
	awake_left = HintRules.QUIET_AFTER
	_relayout()


## A press that did nothing: open the panel and give it a little shake.
func refuse() -> void:
	wake()
	_shake = SHAKE_TIME


func is_awake() -> bool:
	return awake_left > 0.0


func is_hot(what: String) -> bool:
	return hot.get(what, false)


func tokens() -> Array:
	return rows.map(func(r: Array) -> String: return r[0])


func pictures() -> Array:
	return rows.map(func(r: Array) -> String: return r[1])


func shaking() -> bool:
	return _shake > 0.0


func panel_size() -> Vector2:
	if rows.is_empty():
		return Vector2(WIDE, EDGE)
	return Vector2(WIDE, ROW_H * rows.size() + 12.0)


## Where the panel sits in a view: P1 bottom-left, P2 bottom-right, clear of the stage icons.
func place_in(view: Vector2) -> void:
	var s := panel_size()
	var x := MARGIN if player == Players.P1 else view.x - s.x - MARGIN
	position = Vector2(x, view.y - s.y - MARGIN)
	size = s


func _relayout() -> void:
	rows = HintRules.visible_rows(ctx, is_awake())
	var parent_c := get_parent_control()
	place_in(parent_c.size if parent_c else get_viewport_rect().size)


func _process(delta: float) -> void:
	_t += delta
	var was := is_awake()
	awake_left = maxf(0.0, awake_left - delta)
	_shake = maxf(0.0, _shake - delta)
	if was != is_awake():
		_relayout()
	else:
		var parent_c := get_parent_control()
		place_in(parent_c.size if parent_c else get_viewport_rect().size)
	queue_redraw()


func _draw() -> void:
	var off := Vector2.ZERO
	if _shake > 0.0:
		off.x = sin(_t * 60.0) * 6.0 * (_shake / SHAKE_TIME)
	var s := panel_size()
	var edge: Color = Players.COLOR[player]
	if rows.is_empty():   # folded with nothing lit: just a thin tab in the player's colour
		draw_rect(Rect2(off + Vector2(WIDE * 0.3, 0), Vector2(WIDE * 0.4, EDGE)), Color(edge, 0.7))
		return
	draw_rect(Rect2(off, s), Color(0.08, 0.06, 0.1, 0.55))
	draw_rect(Rect2(off, Vector2(s.x, EDGE)), edge)   # whose panel: green or red
	for k in rows.size():
		var row: Array = rows[k]
		var cy := EDGE + ROW_H * k + ROW_H * 0.5
		var lit: bool = hot.get(row[1], false)
		var a := 0.8
		if lit:
			a = 0.65 + 0.35 * absf(sin(_t * 5.0))
			draw_rect(Rect2(off + Vector2(4, cy - ROW_H * 0.45), Vector2(WIDE - 8, ROW_H * 0.9)), Color(1, 1, 1, 0.12))
		UiStyle.draw_glyph(self, off + Vector2(36.0, cy), 40.0, row[0], a)
		if row[2]:   # hold: a ring round the glyph
			draw_arc(off + Vector2(36.0, cy), 25.0, -PI / 2, -PI / 2 + TAU * fmod(_t * 0.5, 1.0), 24, Color(1, 1, 1, 0.7), 3.0)
		_draw_picture(off + Vector2(105.0, cy), row[1], a)


## Tiny placeholder pictures, one per action (Art lane replaces them with icons).
func _draw_picture(c: Vector2, what: String, a: float) -> void:
	var ink := Color(1, 0.96, 0.9, a)
	var mine: Color = Players.COLOR[player]
	mine.a = a
	match what:
		"worm":
			for k in 4:
				draw_circle(c + Vector2(-15 + k * 9, sin(_t * 4.0 + k) * 3.0), 7.0 if k == 3 else 6.0, mine)
		"zip":
			for k in 3:
				draw_line(c + Vector2(-22, -8 + k * 8), c + Vector2(6 - k * 6, -8 + k * 8), ink, 3.0)
			draw_circle(c + Vector2(14, 0), 8.0, mine)
		"notes":
			draw_circle(c + Vector2(-8, 8), 5.0, ink)
			draw_line(c + Vector2(-4, 8), c + Vector2(-4, -12), ink, 3.0)
			draw_circle(c + Vector2(10, 4), 5.0, ink)
			draw_line(c + Vector2(14, 4), c + Vector2(14, -14), ink, 3.0)
			draw_line(c + Vector2(-4, -12), c + Vector2(14, -14), ink, 3.0)
		"home":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-18, -2), c + Vector2(0, -18), c + Vector2(18, -2)]), ink)
			draw_rect(Rect2(c + Vector2(-13, -2), Vector2(26, 18)), ink)
			draw_rect(Rect2(c + Vector2(-4, 6), Vector2(8, 10)), Color(0.2, 0.15, 0.1, a))
		"partner":   # the other worm, in its colour, with a pull-in arrow
			var other: Color = Players.COLOR[Players.P2 if player == Players.P1 else Players.P1]
			other.a = a
			for k in 3:
				draw_circle(c + Vector2(4 + k * 8, sin(_t * 4.0 + k) * 2.0), 6.0 if k == 2 else 5.0, other)
			draw_line(c + Vector2(-22, 0), c + Vector2(-6, 0), ink, 3.0)
			draw_line(c + Vector2(-11, -5), c + Vector2(-6, 0), ink, 3.0)
			draw_line(c + Vector2(-11, 5), c + Vector2(-6, 0), ink, 3.0)
		"mouth":
			draw_circle(c + Vector2(-4, 0), 13.0, mine)
			draw_circle(c + Vector2(6, 0), 6.0, Color(0.15, 0.05, 0.05, a))
			draw_circle(c + Vector2(12, 0), 5.0, Color(1, 0.62, 0.11, a))
		"box":
			draw_rect(Rect2(c + Vector2(-18, -8), Vector2(36, 22)), Color(0.35, 0.55, 0.4, a))
			draw_rect(Rect2(c + Vector2(-18, -14), Vector2(36, 8)), Color(0.45, 0.7, 0.5, a))
			draw_rect(Rect2(c + Vector2(-4, -4), Vector2(8, 6)), ink)
		"drop":
			draw_circle(c + Vector2(-6, -4), 13.0, mine)
			draw_circle(c + Vector2(4, -4), 6.0, Color(0.15, 0.05, 0.05, a))
			draw_circle(c + Vector2(10, 12 + 3.0 * sin(_t * 6.0)), 5.0, Color(1, 0.62, 0.11, a))
			draw_line(c + Vector2(18, 2), c + Vector2(18, 14), ink, 2.0)
			draw_line(c + Vector2(15, 11), c + Vector2(18, 14), ink, 2.0)
			draw_line(c + Vector2(21, 11), c + Vector2(18, 14), ink, 2.0)
		"swap":
			draw_circle(c + Vector2(-14, 0), 7.0, Color(0.55, 0.6, 0.68, a))
			draw_circle(c + Vector2(14, -5), 4.5, Color(0.63, 0.44, 0.24, a))
			draw_circle(c + Vector2(14, 6), 4.5, Color(0.63, 0.44, 0.24, a))
			draw_line(c + Vector2(-5, -3), c + Vector2(6, -3), ink, 2.0)
			draw_line(c + Vector2(3, -6), c + Vector2(6, -3), ink, 2.0)
			draw_line(c + Vector2(6, 3), c + Vector2(-5, 3), ink, 2.0)
			draw_line(c + Vector2(-2, 6), c + Vector2(-5, 3), ink, 2.0)
		"wall":
			draw_rect(Rect2(c + Vector2(-20, -14), Vector2(40, 28)), Color(0.3, 0.2, 0.14, a))
			for k in 3:
				draw_circle(c + Vector2(-11 + k * 11, 0), 5.0, [Color("ff9f1c"), Color("8d99ae"), Color("6ff0ff")][k] * Color(1, 1, 1, a))
