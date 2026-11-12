## The stage-6 question as a picture, no text. Left to right: the worm's open mouth on the planet (what
## will happen), an arrow from the planet into a jar holding its copy (the jar keeps it safe), the A
## glyph with a ring that fills while A is held (the choice: hold to chomp), and under it a small B
## glyph beside the whole planet (the other choice: not yet). Stands in for PictoBubble (openjar-addons).
class_name ConfirmPicture
extends Node2D

const OUTLINE := Color("2a1a14")
const PAPER := Color("fff6e0")
const SIZE := Vector2(560, 280)

var planet_texture: Texture2D
var progress := 0.0
var holding := false
## The copy is in the jar (after the hold fills): the jar in the picture gets its planet and a tick.
var jarred := false
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-SIZE / 2.0, SIZE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = OUTLINE
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(36)
	draw_style_box(sb, rect)
	# tail pointing left, at the worm and planet
	var tail := PackedVector2Array([Vector2(-SIZE.x / 2 + 3, -20), Vector2(-SIZE.x / 2 - 46, 30), Vector2(-SIZE.x / 2 + 3, 30)])
	draw_colored_polygon(tail, PAPER)
	draw_polyline(tail, OUTLINE, 6.0)
	# 1. what will happen: the worm's mouth closing on the planet
	var pc := Vector2(-175, 20)
	_planet(pc, 62.0)
	var hc := pc + Vector2(-38, -76)
	var gape := 0.45 + 0.25 * sin(_t * 6.0)
	draw_circle(hc, 44, OUTLINE)
	draw_circle(hc, 38, Color("3cc24a"))
	draw_colored_polygon([hc, hc + Vector2(44, 0).rotated(0.9 - gape), hc + Vector2(44, 0).rotated(0.9 + gape)], Color("5a1420"))
	draw_circle(hc + Vector2(-8, -14), 13, Color.WHITE)
	draw_circle(hc + Vector2(-4, -12), 6, Color("1b1b2a"))
	# 2. the safety net: an arrow from the planet into a jar that keeps its copy
	var jc := Vector2(-20, 30)
	var bob := sin(_t * 3.0) * 4.0
	_arrow(pc + Vector2(66, -30), jc + Vector2(-46, -40 + bob))
	_jar(jc, jarred or fmod(_t, 2.4) > 1.2)
	# 3. the choice: hold A (the ring fills) ...
	var gc := Vector2(165, -38)
	var pulse := 1.0 + (0.06 * sin(_t * 5.0) if not holding else 0.0)
	draw_arc(gc, 62, 0, TAU, 48, Color(0, 0, 0, 0.18), 16.0)
	if progress > 0.0:
		draw_arc(gc, 62, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, Color("3cc24a"), 16.0)
	draw_circle(gc, 40 * pulse + 5, OUTLINE)
	draw_circle(gc, 40 * pulse, Color("4cc26a") if not holding else Color("7be08f"))
	var font := ThemeDB.fallback_font
	draw_string(font, gc + Vector2(-15, 17), "A", HORIZONTAL_ALIGNMENT_CENTER, -1, 48, Color.WHITE)
	# ... or B: the planet stays whole, not yet
	var bc := Vector2(130, 90)
	draw_circle(bc, 27, OUTLINE)
	draw_circle(bc, 22, Color("e4393c"))
	draw_string(font, bc + Vector2(-9, 10), "B", HORIZONTAL_ALIGNMENT_CENTER, -1, 28, Color.WHITE)
	_planet(bc + Vector2(66, 0), 24.0)


func _planet(c: Vector2, r: float) -> void:
	draw_circle(c, r + 4.0, OUTLINE)
	if planet_texture:
		draw_texture_rect(planet_texture, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
	else:
		draw_circle(c, r, Color("8a5a34"))


func _arrow(from: Vector2, to: Vector2) -> void:
	var mid := (from + to) / 2.0 + Vector2(0, -34)
	var pts := PackedVector2Array()
	for i in 13:
		var k := i / 12.0
		pts.append(from.lerp(mid, k).lerp(mid.lerp(to, k), k))
	draw_polyline(pts, OUTLINE, 7.0)
	var dir := (to - pts[10]).normalized()
	draw_colored_polygon(PackedVector2Array([to + dir * 6.0, to - dir * 18.0 + dir.orthogonal() * 13.0,
			to - dir * 18.0 - dir.orthogonal() * 13.0]), OUTLINE)


func _jar(c: Vector2, full: bool) -> void:
	var body := Rect2(c + Vector2(-42, -46), Vector2(84, 96))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.75, 0.9, 1.0, 0.5)
	sb.border_color = OUTLINE
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(20)
	draw_style_box(sb, body)
	if full:
		_planet(c + Vector2(0, 8), 26.0)
	draw_rect(Rect2(c + Vector2(-36, -64), Vector2(72, 20)), OUTLINE)
	draw_rect(Rect2(c + Vector2(-31, -60), Vector2(62, 12)), Color("c9a23a"))
	draw_line(c + Vector2(-28, -30), c + Vector2(-28, 30), Color(1, 1, 1, 0.7), 5.0)
	if jarred:
		# a tick on the jar: it is safe in there
		draw_polyline(PackedVector2Array([c + Vector2(18, 40), c + Vector2(30, 54), c + Vector2(56, 20)]), Color("3cc24a"), 9.0)
