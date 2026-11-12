## Why the sun could be eaten, in a picture (no text), shown the moment it is: the five planets
## eaten this run (each in its colour, ticked), an equals sign, then the sun inside a worm.
## "You ate all five planets, so the sun was yours: the last meal."
class_name SunBubble
extends WhyBubble

const WIDE := Vector2(560, 170)

var colors: Array[Color] = []
var worm_color := Color("3cc24a")


func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = OUTLINE
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(32)
	draw_style_box(sb, Rect2(-WIDE / 2.0, WIDE))
	var tail := PackedVector2Array([Vector2(-24, WIDE.y / 2 - 3), Vector2(0, WIDE.y / 2 + 40), Vector2(24, WIDE.y / 2 - 3)])
	draw_colored_polygon(tail, PAPER)
	draw_polyline(tail, OUTLINE, 6.0)
	# the five planets, ticked, in two staggered rows
	for i in colors.size():
		var c := Vector2(-230 + i * 42, -28 if i % 2 == 0 else 28)
		draw_circle(c, 25, OUTLINE)
		draw_circle(c, 20, colors[i])
		draw_polyline(PackedVector2Array([c + Vector2(-9, 0), c + Vector2(-2, 8), c + Vector2(11, -9)]), Color("2e9e3a"), 6.0)
	# equals
	draw_rect(Rect2(-14, -16, 36, 9), OUTLINE)
	draw_rect(Rect2(-14, 6, 36, 9), OUTLINE)
	# the sun inside a worm (the worm curls round it, bobbing)
	var wc := Vector2(150, sin(_t * 2.5) * 6.0)
	for i in 7:
		var a := PI * 0.9 + i * 0.75
		var sc := wc + Vector2.from_angle(a) * 52.0
		draw_circle(sc, 20 + 4, OUTLINE)
		draw_circle(sc, 20, worm_color)
	draw_circle(wc, 34, OUTLINE)
	draw_circle(wc, 30, Color("ffc93a"))
	for i in 8:
		var a := i * TAU / 8.0 + _t
		draw_line(wc + Vector2.from_angle(a) * 22, wc + Vector2.from_angle(a) * 30, Color("ff8a1e"), 5.0)
