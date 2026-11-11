## A grey-box dock actor for the story scenes: Old Reel (his library pixel form), young Reel in
## the flashbacks, Bobber (drawn placeholder until his pixel form exists), and the two bait worms
## Gulp (green) and Burp (red). Feet at the origin. No final art (Kaden's look pick D92 is open).
class_name StoryActor
extends Node2D

const REEL_PIXEL := "res://assets/characters/old_reel/pixel.png"
const OUTLINE := Color("3a2a44")
const SKIN := Color("ffd9a8")
const P1_GREEN := Color("3cc24a")
const P2_RED := Color("e4393c")

## reel | young_reel | bobber | worm_green | worm_red
@export var kind := "reel"
var facing := 1:
	set(v):
		facing = v
		queue_redraw()
## Old Reel's hand span in pixels ("it was THIS big"); 0 hides the hands.
var hands := 0.0:
	set(v):
		hands = v
		queue_redraw()
## idle | squint | arms | sleep | tip_hat | point_up | cast | walk
var pose := "idle":
	set(v):
		pose = v
		queue_redraw()
var _t := 0.0
var _tex: Texture2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if kind in ["reel", "young_reel"] and ResourceLoader.exists(REEL_PIXEL):
		_tex = load(REEL_PIXEL)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	match kind:
		"reel", "young_reel":
			_draw_reel()
		"bobber":
			_draw_bobber()
		"worm_green":
			_draw_worm(P1_GREEN)
		"worm_red":
			_draw_worm(P2_RED)


func _draw_reel() -> void:
	var young := kind == "young_reel"
	if _tex != null:
		var sz := _tex.get_size()
		var r := Rect2(-sz.x * 0.5, -sz.y, sz.x, sz.y)
		if facing < 0:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
		# Young Reel: same form, a darker beard tone and a straighter back (placeholder).
		draw_texture_rect(_tex, r, false, Color(1.05, 0.95, 0.85) if young else Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if young:
			draw_rect(Rect2(-5, -14, 10, 4), Color("6b4a2e"))   # brown beard, not white
	else:
		draw_rect(Rect2(-7, -30, 14, 30), OUTLINE)
		draw_rect(Rect2(-6, -29, 12, 28), Color("c9a86a"))
	var chest := Vector2(0, -15)
	match pose:
		"tip_hat":
			var lift := 2.0 + 2.0 * sin(_t * 3.0)
			draw_line(chest + Vector2(5 * facing, 0), Vector2(4 * facing, -31 - lift), OUTLINE, 2.0)
			draw_circle(Vector2(4 * facing, -31 - lift), 2.0, SKIN)
		"point_up":
			draw_line(chest + Vector2(5 * facing, 0), Vector2(9 * facing, -38), OUTLINE, 2.0)
			draw_circle(Vector2(9 * facing, -38), 2.0, SKIN)
		_:
			if hands > 0.0:
				var w := hands * 0.5
				var wob := sin(_t * 5.0) * 0.6
				for sgn in [-1.0, 1.0]:
					var h: Vector2 = chest + Vector2(sgn * (w + wob), -2)
					draw_line(chest + Vector2(sgn * 4, 0), h, OUTLINE, 2.0)
					draw_circle(h, 2.2, OUTLINE)
					draw_circle(h, 1.6, SKIN)


func _draw_bobber() -> void:
	# Kid build, too-big yellow rain hat, teal-and-cream stripes, denim shorts (bible proposal).
	var sit := pose != "walk"
	var lean := 0.0
	if pose == "sleep":
		lean = 0.35 * facing   # head toward whoever he faces (Reel's shoulder)
	draw_set_transform(Vector2.ZERO, lean, Vector2(facing, 1))
	var base := -4.0 if sit else 0.0
	if sit:
		var swing := sin(_t * 3.0) * 2.0 if pose != "sleep" else 0.0
		draw_line(Vector2(-1, base), Vector2(1 + swing, base + 6), SKIN, 2.0)
		draw_line(Vector2(2, base), Vector2(4 - swing, base + 6), SKIN, 2.0)
	else:
		draw_rect(Rect2(-3, -5, 2, 5), SKIN)
		draw_rect(Rect2(1, -5, 2, 5), SKIN)
	draw_rect(Rect2(-4, base - 4, 8, 4), Color("3d5a88"))          # shorts
	for i in 4:
		draw_rect(Rect2(-4, base - 10 + i * 1.5, 8, 1.5), Color("2fa7a0") if i % 2 == 0 else Color("f1e7cf"))
	draw_circle(Vector2(0, base - 14), 4.0, SKIN)                     # head
	if pose == "sleep":
		draw_line(Vector2(-2, base - 14), Vector2(0, base - 14), OUTLINE, 1.0)
		draw_line(Vector2(1, base - 14), Vector2(3, base - 14), OUTLINE, 1.0)
	elif pose == "squint":
		draw_line(Vector2(-2, base - 14), Vector2(0, base - 14), OUTLINE, 1.0)
		draw_circle(Vector2(2, base - 14), 0.9, OUTLINE)
	else:
		draw_circle(Vector2(-1, base - 14), 0.9, OUTLINE)
		draw_circle(Vector2(2, base - 14), 0.9, OUTLINE)
	draw_rect(Rect2(-6, base - 18, 12, 2), Color("f6c833"))           # rain hat brim
	draw_rect(Rect2(-4, base - 21, 8, 3), Color("f6c833"))
	if pose == "arms":
		draw_line(Vector2(-4, base - 8), Vector2(4, base - 7), SKIN, 2.0)
		draw_line(Vector2(-4, base - 6), Vector2(4, base - 8), SKIN, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_worm(col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var x := (i - 2.5) * 2.0 * facing
		pts.append(Vector2(x, -2.0 + sin(_t * 9.0 + i * 0.9) * 1.4))
	draw_polyline(pts, col.darkened(0.45), 3.4)
	draw_polyline(pts, col, 2.2)
	draw_circle(pts[pts.size() - 1] + Vector2(0.4 * facing, -0.4), 0.6, OUTLINE)
