## Placeholder food pickup for the trait arena: a blob in the food's colour with a face that goes
## wide-eyed when a worm that can eat it comes near, and smug when one that can't bonks it.
## Duck-typed for Worm (group "food"): data, is_available(), take(), set_carried(), drift_toward(),
## hop_toward(), smug(). The tile world's food nodes provide the same.
class_name ArenaFood
extends Node2D

signal taken(food: ArenaFood)

const INK := Color("2a1a14")

@export var data: FoodData
var home := Vector2.ZERO
var _gone := false
var _carried := false
var _block := 0.0
var _smug := 0.0
var _scared := false
var _pulled := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("food")
	home = position
	_t = randf() * 10.0


func is_available() -> bool:
	return not _gone and not _carried and _block <= 0.0


func take() -> void:
	_gone = true
	visible = false
	remove_from_group("food")
	taken.emit(self)


func respawn() -> void:
	position = home
	_gone = false
	_carried = false
	_block = 0.0
	visible = true
	scale = Vector2.ZERO
	add_to_group("food")
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func set_carried(on: bool, block := 0.0) -> void:
	_carried = on
	_block = block
	z_index = 30 if on else 0


func drift_toward(p: Vector2, amount: float) -> void:
	global_position = global_position.move_toward(p, amount)
	_pulled = 0.15


func hop_toward(p: Vector2, dist: float) -> void:
	var to := global_position.move_toward(p, dist)
	var tw := create_tween()
	tw.tween_property(self, "global_position", to, 0.25).set_trans(Tween.TRANS_QUAD)
	var up := create_tween()
	up.tween_property(self, "scale", Vector2(0.8, 1.3), 0.1)
	up.tween_property(self, "scale", Vector2.ONE, 0.15)


func smug() -> void:
	_smug = 1.2


func _process(delta: float) -> void:
	_t += delta
	_block = maxf(0.0, _block - delta)
	_smug = maxf(0.0, _smug - delta)
	_pulled = maxf(0.0, _pulled - delta)
	_scared = false
	for w in get_tree().get_nodes_in_group("worms"):
		if w.head.global_position.distance_to(global_position) < 48.0 and w.can_eat(data):
			_scared = true
			break
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	var r := data.radius
	var bob := Vector2(0, sin(_t * 3.0) * 0.6)
	if _scared and not _carried:
		bob.x = sin(_t * 40.0) * 0.7
	draw_circle(bob, r + 1.0, INK)
	draw_circle(bob, r, data.color)
	draw_circle(bob + Vector2(-r * 0.35, -r * 0.4), maxf(1.0, r * 0.25), data.color.lightened(0.45))
	var e := maxf(1.0, r * 0.22)
	var ey := bob + Vector2(0, -r * 0.1)
	for sx in [-1.0, 1.0]:
		var c := ey + Vector2(sx * r * 0.38, 0)
		if _scared or _carried:
			draw_circle(c, e + 1.0, Color.WHITE)
			draw_circle(c, e * 0.5, INK)
		elif _smug > 0.0:
			draw_line(c + Vector2(-e, 0), c + Vector2(e, 0), INK, 1.0)
		else:
			draw_circle(c, e * 0.6, INK)
	if _pulled > 0.0:
		for i in 3:
			var a := _t * 9.0 + i * TAU / 3.0
			draw_circle(bob + Vector2.from_angle(a) * (r + 3.0), 1.0, Color(1, 0.95, 0.5))
