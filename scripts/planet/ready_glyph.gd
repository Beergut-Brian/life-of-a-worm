## The blinking controller glyph over a worm's head when an interaction is ready (X: carry this;
## Y: the trait wall in the burrow). Upright on screen whatever the camera's rotation; constant
## screen size whatever the zoom.
class_name ReadyGlyph
extends Node2D

var worm: Worm
var camera: Camera2D
var token := ""
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	visible = token != "" and worm != null and is_instance_valid(worm)
	if not visible:
		return
	position = worm.cam_position()
	if camera:
		rotation = camera.rotation
		scale = Vector2.ONE / camera.zoom.x
	queue_redraw()


func _draw() -> void:
	if token == "":
		return
	var a := 0.35 + 0.65 * absf(sin(_t * 5.0))   # blink
	var up := Vector2(0, -70)
	draw_circle(up, 26.0, Color(0, 0, 0, 0.35 * a))
	UiStyle.draw_glyph(self, up, 40.0, token, a)
