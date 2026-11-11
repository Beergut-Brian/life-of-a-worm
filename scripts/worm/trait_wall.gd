## Placeholder trait wall: a row of pictures (each earned trait's part on a tile in its colour),
## sockets for the slots, a cursor in the player's colour. No text. The burrow replaces it later.
class_name TraitWall
extends CanvasLayer

const TILE := 96.0
const GAP := 18.0

var worm: Worm
var cursor := 0
var _root: Control
var _shake := 0.0


func _ready() -> void:
	layer = 50
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_wall)
	add_child(_root)
	visible = false


func set_open(on: bool) -> void:
	visible = on
	cursor = clampi(cursor, 0, maxi(0, worm.model.earned.size() - 1))
	_root.queue_redraw()


## nav -1 / +1 moves, confirm toggles the picture under the cursor, back closes.
func handle(nav: int, confirm: bool, back: bool) -> void:
	var earned := worm.model.earned
	if nav != 0 and not earned.is_empty():
		cursor = wrapi(cursor + nav, 0, earned.size())
		Audio.play("ui_move")
	if confirm and not earned.is_empty():
		if worm.model.toggle(earned[cursor]):
			Audio.play("ui_confirm")
		else:
			_shake = 0.3
			Audio.play("bonk")
	if back:
		worm.set_wall_open(false)
	_root.queue_redraw()


func _process(delta: float) -> void:
	if visible and _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		_root.queue_redraw()


func _draw_wall() -> void:
	var model := worm.model
	var col: Color = Players.COLOR[worm.player]
	var n := maxi(model.earned.size(), 1)
	var w := n * (TILE + GAP) + GAP
	var vp := _root.get_viewport_rect().size
	var x0 := (vp.x - w) * 0.5
	var y0 := vp.y - TILE * 2.4 - (0.0 if worm.player == 0 else TILE * 2.6)
	_root.draw_rect(Rect2(x0 - 8, y0 - 8, w + 16, TILE * 2.0 + 16), Color(0.16, 0.1, 0.07, 0.92))
	_root.draw_rect(Rect2(x0 - 8, y0 - 8, w + 16, TILE * 2.0 + 16), col, false, 6.0)
	for i in model.earned.size():
		var t := model.rules.find_trait(model.earned[i])
		var on := model.is_active(t.id)
		var r := Rect2(x0 + GAP + i * (TILE + GAP), y0 + GAP * 0.5, TILE, TILE)
		if i == cursor and _shake > 0.0:
			r.position.x += sin(_shake * 80.0) * 6.0
		var bg := t.color.darkened(0.15 if on else 0.65)
		_root.draw_rect(r, bg)
		var tex := t.part_texture(model.stage)
		if tex != null:
			var s := floorf(TILE * 0.7 / maxf(tex.get_width(), tex.get_height()))
			var size := tex.get_size() * s
			var tint := Color.WHITE if on else Color(0.5, 0.5, 0.5)
			_root.draw_texture_rect(tex, Rect2(r.get_center() - size * 0.5, size), false, tint)
		if on:
			_root.draw_rect(r, Color(1, 1, 0.8), false, 4.0)
		if i == cursor:
			_root.draw_rect(r.grow(8.0), col, false, 6.0)
	# Slot sockets under the row: filled for each active trait.
	var slots := model.slots()
	var sx := x0 + (w - slots * 40.0) * 0.5
	for i in slots:
		var c := Vector2(sx + i * 40.0 + 20.0, y0 + TILE + GAP * 2.0 + 20.0)
		_root.draw_circle(c, 14.0, Color(0, 0, 0, 0.6))
		if i < model.active.size():
			_root.draw_circle(c, 11.0, model.rules.find_trait(model.active[i]).color)
		_root.draw_arc(c, 14.0, 0.0, TAU, 24, col, 3.0)
