## Why the world just changed, in a picture (no text): the bitten planet, an equals sign, then a down
## arrow struck through beside a floating worm. "The planet is eaten, so nothing pulls you down."
class_name WhyBubble
extends Node2D

const OUTLINE := Color("2a1a14")
const PAPER := Color("fff6e0")
const SIZE := Vector2(400, 170)

var _left := 0.0
var _t := 0.0


func show_for(seconds: float) -> void:
	_left = seconds
	visible = true
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_showing() -> bool:
	return visible and _left > 0.0


func _process(delta: float) -> void:
	_t += delta
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			var tw := create_tween()
			tw.tween_property(self, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.tween_callback(hide)
	queue_redraw()


func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = OUTLINE
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(32)
	draw_style_box(sb, Rect2(-SIZE / 2.0, SIZE))
	var tail := PackedVector2Array([Vector2(-24, SIZE.y / 2 - 3), Vector2(0, SIZE.y / 2 + 40), Vector2(24, SIZE.y / 2 - 3)])
	draw_colored_polygon(tail, PAPER)
	draw_polyline(tail, OUTLINE, 6.0)
	# the planet, with a big bite out of it
	var pc := Vector2(-125, 0)
	draw_circle(pc, 50, OUTLINE)
	draw_circle(pc, 44, Color("8a5a34"))
	draw_circle(pc, 26, Color("c9572e"))
	draw_circle(pc + Vector2(34, -26), 34, PAPER)
	draw_arc(pc + Vector2(34, -26), 34, PI * 0.55, PI * 1.25, 12, OUTLINE, 5.0)
	# equals
	draw_rect(Rect2(-52, -16, 36, 9), OUTLINE)
	draw_rect(Rect2(-52, 6, 36, 9), OUTLINE)
	# no pull: a down arrow, struck through
	var ac := Vector2(35, 0)
	draw_line(ac + Vector2(0, -48), ac + Vector2(0, 28), Color("6b6f80"), 11.0)
	draw_colored_polygon(PackedVector2Array([ac + Vector2(-24, 22), ac + Vector2(24, 22), ac + Vector2(0, 52)]), Color("6b6f80"))
	draw_line(ac + Vector2(-38, -40), ac + Vector2(38, 42), Color("e4393c"), 12.0)
	# the worm, floating (bobs)
	var wc := Vector2(130, sin(_t * 2.5) * 10.0)
	for i in 4:
		draw_circle(wc + Vector2(-16 * i, 10 * sin(_t * 3.0 + i)), 17 - i * 2 + 4, OUTLINE)
		draw_circle(wc + Vector2(-16 * i, 10 * sin(_t * 3.0 + i)), 17 - i * 2, Color("3cc24a"))
	draw_circle(wc + Vector2(6, -8), 7, Color.WHITE)
	draw_circle(wc + Vector2(8, -8), 3.5, Color("1b1b2a"))
