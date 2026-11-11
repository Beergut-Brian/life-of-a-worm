## Shared camera for the arena: fits every worm, zooms in whole pixel steps (3x, 2x), and punches
## (a short kick) on a trait reveal or a stage up. Never moves a worm.
class_name ArenaCamera
extends Camera2D

const ZOOMS := [3.0, 2.0]
const MARGIN := 80.0

var _kick := Vector2.ZERO
var _shake := 0.0
var _flash: ColorRect


func _ready() -> void:
	zoom = Vector2(ZOOMS[0], ZOOMS[0])
	var layer := CanvasLayer.new()
	layer.layer = 40
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)
	add_child(layer)


func punch(strength := 6.0) -> void:
	_kick = Vector2.from_angle(randf() * TAU) * strength
	_shake = 0.25 if SettingsPanel.screen_shake() else 0.0


func flash() -> void:
	_flash.color.a = 0.85
	create_tween().tween_property(_flash, "color:a", 0.0, 0.25).set_delay(0.033)


func _process(delta: float) -> void:
	var worms := get_tree().get_nodes_in_group("worms")
	if worms.is_empty():
		return
	var box := Rect2(worms[0].head.global_position, Vector2.ZERO)
	for w in worms:
		box = box.expand(w.head.global_position)
	var target := box.get_center()
	global_position = global_position.lerp(target, minf(1.0, delta * 4.0))
	var vp := get_viewport_rect().size
	var z: float = ZOOMS[ZOOMS.size() - 1]
	for cand in ZOOMS:
		if box.size.x + MARGIN * 2.0 <= vp.x / cand and box.size.y + MARGIN * 2.0 <= vp.y / cand:
			z = cand
			break
	zoom = Vector2(z, z)
	_kick = _kick.lerp(Vector2.ZERO, minf(1.0, delta * 10.0))
	_shake = maxf(0.0, _shake - delta)
	offset = _kick + (Vector2(randf_range(-2, 2), randf_range(-2, 2)) if _shake > 0.0 else Vector2.ZERO)
