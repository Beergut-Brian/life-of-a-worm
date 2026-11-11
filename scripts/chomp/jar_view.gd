## Old Reel's shelf, top left of the planet shot: a glass jar the planet's copy flies into at the
## snapshot, so the safety net is shown, not told.
extends Node2D

const OUTLINE := Color("2a1a14")

var planet_texture: Texture2D
var filled := 0.0          # 0 empty .. 1 the little planet sits in the jar
var _fly_from := Vector2.ZERO
var _fly_size := 0.0
var _fly := -1.0           # 0..1 while flying, -1 idle


func fly_in(from_global: Vector2, size: float, time: float) -> void:
	_fly_from = to_local(from_global)
	_fly_size = size
	_fly = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_fly", 1.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		_fly = -1.0
		filled = 1.0
		get_parent().get_node("Sfx").play("jar_clink"))
	tw.tween_property(self, "scale", Vector2.ONE * 1.15, 0.08)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# shelf plank
	draw_rect(Rect2(-110, 78, 220, 22), OUTLINE)
	draw_rect(Rect2(-104, 80, 208, 14), Color("a86b3c"))
	# jar body
	var body := Rect2(-62, -60, 124, 138)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.75, 0.9, 1.0, 0.28)
	sb.border_color = Color("e9f6ff")
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(28)
	draw_style_box(sb, body)
	if filled > 0.0 and planet_texture:
		draw_texture_rect(planet_texture, Rect2(-46, -34, 92, 92), false)
	draw_line(Vector2(-40, -40), Vector2(-40, 40), Color(1, 1, 1, 0.6), 6.0)
	# lid
	draw_rect(Rect2(-56, -86, 112, 30), OUTLINE)
	draw_rect(Rect2(-50, -82, 100, 22), Color("c9a23a"))
	if _fly >= 0.0 and planet_texture:
		var s := lerpf(_fly_size, 92.0, _fly)
		var c := _fly_from.lerp(Vector2(0, 12), _fly) + Vector2(0, -sin(_fly * PI) * 160.0)
		draw_texture_rect(planet_texture, Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), false)
