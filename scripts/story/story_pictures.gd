## Worm's own PictoBubble pictures for the dock scenes (procedural, no textures, no words).
## `StoryPictures.register_all()` once before a scene; safe to call again.
class_name StoryPictures
extends RefCounted

const INK := Color("3a2a44")
const GREEN := Color("3cc24a")
const RED := Color("e4393c")
const IDS: Array[StringName] = [&"worm", &"worm_tiny", &"worm_two", &"worm_big", &"worm_huge", &"worm_up",
		&"stone_worm", &"sandwich", &"hook", &"fish", &"comet", &"chili", &"purple_rock", &"socks",
		&"lightning", &"wish", &"planet", &"planet_bite", &"moon_bite", &"shed_sink", &"hill_bite",
		&"eat", &"no", &"burp", &"dock"]


static func register_all() -> void:
	for id in IDS:
		PictoBubble.register(id, _draw)


static func _ink(a: float) -> Color:
	return Color(INK, a)


static func _worm(ci: CanvasItem, c: Vector2, len: float, u: float, col: Color, a: float, head := Color.TRANSPARENT) -> void:
	var pts := PackedVector2Array()
	for i in 7:
		var f := i / 6.0
		pts.append(c + Vector2((f - 0.5) * len, sin(f * TAU) * 2.0) * u)
	ci.draw_polyline(pts, Color(col.darkened(0.45), a), 4.0 * u)
	ci.draw_polyline(pts, Color(col, a), 2.6 * u)
	if head.a > 0.0:
		ci.draw_rect(Rect2(pts[6] + Vector2(-1, -3.5) * u, Vector2(6, 7) * u), Color(head, a))
	else:
		ci.draw_circle(pts[6] + Vector2(0.5, -0.6) * u, 0.8 * u, _ink(a))


static func _draw(ci: CanvasItem, id: StringName, c: Vector2, s: float, a: float) -> void:
	var u := s / 22.0
	match id:
		&"worm":
			_worm(ci, c, 12.0, u, GREEN, a)
		&"worm_tiny":
			# Two fingers an inch apart with a tiny worm between them.
			ci.draw_rect(Rect2(c + Vector2(-8, -6) * u, Vector2(3, 12) * u), Color(Color("ffd9a8"), a))
			ci.draw_rect(Rect2(c + Vector2(5, -6) * u, Vector2(3, 12) * u), Color(Color("ffd9a8"), a))
			_worm(ci, c, 6.0, u, GREEN, a)
		&"worm_two":
			_worm(ci, c + Vector2(0, -4) * u, 11.0, u, GREEN, a)
			_worm(ci, c + Vector2(0, 5) * u, 11.0, u, RED, a)
		&"worm_big":
			_worm(ci, c, 18.0, u * 1.0, GREEN, a)
			ci.draw_line(c + Vector2(-10, 8) * u, c + Vector2(10, 8) * u, _ink(a), 1.2 * u)
		&"worm_huge":
			ci.draw_arc(c + Vector2(0, 4) * u, 9.0 * u, PI, TAU, 16, Color(GREEN, a), 5.0 * u)
			ci.draw_circle(c + Vector2(9, 2) * u, 1.2 * u, _ink(a))
		&"worm_up":
			_worm(ci, c + Vector2(-2, 4) * u, 12.0, u, GREEN, a)
			ci.draw_line(c + Vector2(7, 6) * u, c + Vector2(7, -8) * u, _ink(a), 1.6 * u)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(3, -6) * u, c + Vector2(7, -10) * u, c + Vector2(11, -6) * u]), _ink(a))
		&"stone_worm":
			_worm(ci, c + Vector2(-2, 0), 12.0, u, GREEN, a, Color("9aa3ad"))
		&"sandwich":
			ci.draw_rect(Rect2(c + Vector2(-8, -5) * u, Vector2(16, 4) * u), Color(Color("e8c27a"), a))
			ci.draw_rect(Rect2(c + Vector2(-8, -1) * u, Vector2(16, 2) * u), Color(Color("6cb14a"), a))
			ci.draw_rect(Rect2(c + Vector2(-8, 1) * u, Vector2(16, 4) * u), Color(Color("e8c27a"), a))
		&"hook":
			ci.draw_line(c + Vector2(2, -9) * u, c + Vector2(2, 4) * u, _ink(a), 1.6 * u)
			ci.draw_arc(c + Vector2(-1, 4) * u, 3.0 * u, 0.0, PI, 10, _ink(a), 1.6 * u)
		&"fish":
			ci.draw_circle(c, 6.0 * u, Color(Color("6fa8dc"), a))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(4, 0) * u, c + Vector2(10, -5) * u, c + Vector2(10, 5) * u]), Color(Color("6fa8dc"), a))
			ci.draw_circle(c + Vector2(-3, -1) * u, 1.0 * u, _ink(a))
		&"comet":
			ci.draw_line(c + Vector2(-9, 7) * u, c + Vector2(4, -4) * u, Color(Color("ffd23f"), a * 0.6), 4.0 * u)
			ci.draw_circle(c + Vector2(5, -5) * u, 4.0 * u, Color(Color("ffd23f"), a))
		&"chili":
			ci.draw_rect(Rect2(c + Vector2(-8, -1) * u, Vector2(16, 7) * u), Color(Color("9aa3ad"), a))
			ci.draw_circle(c + Vector2(0, -1) * u, 7.0 * u, Color(Color("c0392b"), a))
			for k in 3:
				ci.draw_line(c + Vector2(-4 + k * 4, -7) * u, c + Vector2(-3 + k * 4, -11) * u, Color(1, 1, 1, a * 0.7), 1.0 * u)
		&"purple_rock":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 5) * u, c + Vector2(-5, -4) * u, c + Vector2(4, -6) * u, c + Vector2(8, 2) * u, c + Vector2(4, 6) * u]), Color(Color("8e5bd1"), a))
		&"socks":
			ci.draw_rect(Rect2(c + Vector2(-6, -8) * u, Vector2(5, 11) * u), Color(Color("e4a33c"), a))
			ci.draw_rect(Rect2(c + Vector2(-6, 2) * u, Vector2(9, 5) * u), Color(Color("e4a33c"), a))
			ci.draw_rect(Rect2(c + Vector2(-6, -6) * u, Vector2(5, 2) * u), Color(Color("e4393c"), a))
		&"lightning":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(2, -10) * u, c + Vector2(-5, 1) * u, c + Vector2(0, 1) * u, c + Vector2(-2, 10) * u, c + Vector2(6, -2) * u, c + Vector2(1, -2) * u]), Color(Color("ffd23f"), a))
		&"wish":
			PictoBubble.picture(ci, &"star", c + Vector2(0, -2) * u, s * 0.7, a)
			ci.draw_line(c + Vector2(-9, 9) * u, c + Vector2(-3, 3) * u, Color(Color("ffd23f"), a * 0.6), 2.0 * u)
		&"planet":
			ci.draw_circle(c, 8.0 * u, Color(Color("5d9a46"), a))
			ci.draw_arc(c, 8.0 * u, 0.0, TAU, 20, _ink(a), 1.2 * u)
		&"planet_bite":
			ci.draw_circle(c, 8.0 * u, Color(Color("5d9a46"), a))
			ci.draw_circle(c + Vector2(7, -5) * u, 5.0 * u, Color(Color("fffaf0"), a))
		&"moon_bite":
			ci.draw_circle(c, 8.0 * u, Color(Color("fff4d0"), a))
			ci.draw_arc(c, 8.0 * u, 0.0, TAU, 20, _ink(a), 1.0 * u)
			ci.draw_circle(c + Vector2(6, -5) * u, 4.5 * u, Color(Color("fffaf0"), a))
		&"shed_sink":
			ci.draw_rect(Rect2(c + Vector2(-7, -2) * u, Vector2(14, 6) * u), Color(Color("8a5a3c"), a))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -2) * u, c + Vector2(0, -8) * u, c + Vector2(9, -2) * u]), Color(Color("a33b2e"), a))
			ci.draw_rect(Rect2(c + Vector2(-10, 4) * u, Vector2(20, 5) * u), Color(Color("6b4a2e"), a))
		&"hill_bite":
			ci.draw_arc(c + Vector2(0, 7) * u, 9.0 * u, PI, TAU, 16, Color(Color("5d9a46"), a), 6.0 * u)
			ci.draw_circle(c + Vector2(5, -2) * u, 4.0 * u, Color(Color("fffaf0"), a))
		&"eat":
			ci.draw_arc(c, 7.0 * u, 0.5, TAU - 0.5, 16, _ink(a), 2.0 * u)
			ci.draw_circle(c + Vector2(-1, -4) * u, 1.0 * u, _ink(a))
		&"no":
			ci.draw_line(c + Vector2(-6, -6) * u, c + Vector2(6, 6) * u, Color(RED, a), 2.4 * u)
			ci.draw_line(c + Vector2(6, -6) * u, c + Vector2(-6, 6) * u, Color(RED, a), 2.4 * u)
		&"burp":
			for k in 3:
				ci.draw_arc(c + Vector2(-4 + k * 4, 2 - k * 4) * u, (2.0 + k) * u, 0.0, TAU, 12, _ink(a), 1.2 * u)
		&"dock":
			ci.draw_rect(Rect2(c + Vector2(-9, -1) * u, Vector2(18, 3) * u), Color(Color("a07a4e"), a))
			ci.draw_rect(Rect2(c + Vector2(-9, 2) * u, Vector2(18, 6) * u), Color(Color("3a7fb5"), a))
			ci.draw_line(c + Vector2(-4, -1) * u, c + Vector2(-4, -8) * u, _ink(a), 1.4 * u)
