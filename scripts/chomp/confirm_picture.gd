## The stage-6 question as a picture, no text: a bubble showing the worm's open mouth and the planet,
## and the A glyph with a ring that fills while A is held. Stands in for PictoBubble (openjar-addons).
class_name ConfirmPicture
extends Node2D

const OUTLINE := Color("2a1a14")
const SIZE := Vector2(380, 250)

var planet_texture: Texture2D
var progress := 0.0
var holding := false
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-SIZE / 2.0, SIZE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fff6e0")
	sb.border_color = OUTLINE
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(36)
	draw_style_box(sb, rect)
	# tail pointing left, at the worm and planet
	draw_colored_polygon([Vector2(-SIZE.x / 2 + 3, -20), Vector2(-SIZE.x / 2 - 46, 30), Vector2(-SIZE.x / 2 + 3, 30)], Color("fff6e0"))
	draw_polyline([Vector2(-SIZE.x / 2 + 3, -20), Vector2(-SIZE.x / 2 - 46, 30), Vector2(-SIZE.x / 2 + 3, 30)], OUTLINE, 6.0)
	# picture: worm mouth about to close on the planet
	var pc := Vector2(-90, -20)
	if planet_texture:
		draw_texture_rect(planet_texture, Rect2(pc - Vector2(62, 62), Vector2(124, 124)), false)
	var hc := pc + Vector2(-40, -78)
	var gape := 0.45 + 0.25 * sin(_t * 6.0)
	draw_circle(hc, 44, OUTLINE)
	draw_circle(hc, 38, Color("3cc24a"))
	draw_colored_polygon([hc, hc + Vector2(44, 0).rotated(0.9 - gape), hc + Vector2(44, 0).rotated(0.9 + gape)], Color("5a1420"))
	draw_circle(hc + Vector2(-8, -14), 13, Color.WHITE)
	draw_circle(hc + Vector2(-4, -12), 6, Color("1b1b2a"))
	# A glyph with the fill ring
	var gc := Vector2(105, 0)
	var pulse := 1.0 + (0.06 * sin(_t * 5.0) if not holding else 0.0)
	draw_arc(gc, 70, 0, TAU, 48, Color(0, 0, 0, 0.18), 18.0)
	if progress > 0.0:
		draw_arc(gc, 70, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, Color("3cc24a"), 18.0)
	draw_circle(gc, 46 * pulse + 5, OUTLINE)
	draw_circle(gc, 46 * pulse, Color("4cc26a") if not holding else Color("7be08f"))
	var font := ThemeDB.fallback_font
	draw_string(font, gc + Vector2(-17, 19), "A", HORIZONTAL_ALIGNMENT_CENTER, -1, 56, Color.WHITE)
