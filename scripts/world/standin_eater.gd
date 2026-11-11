## A stand-in eater for the polar prototype: a round "worm" head with a trail of segments that
## tunnels by calling World.eat_tile (through eat_circle). Not the real worm (scripts/worm/, another
## lane). Driven by the player's stick (screen-relative, so up is always away from the core) or by
## a scripted path round the disk. A (the "action" button) drops a seed in castings.
class_name StandInEater
extends Node2D

enum Mode { STICK, PATH }

signal seed_dropped(cell: Vector2i, flavour: StringName, took: bool)

var world: PolarWorld
var sfx: WorldSfx
var camera: Camera2D
var player := 0
var stage := 5
var mode := Mode.PATH
var radius_px := 40.0
var speed_tiles := 12.0
var color := Color("3cc24a")
## Path: circle round the core at path_radius tiles, wobbling path_wobble tiles in and out.
var path_angle := 0.0
var path_radius := 400.0
var path_wobble := 20.0
var path_wobble_turns := 6.0
var path_dir := 1.0
var seeds: Array[StringName] = [&"root", &"crystal", &"stone"]
var eaten_total := 0

var _seed_i := 0
var _trail: Array[Vector2] = []
var _crumbs: Array[Dictionary] = []
var _flash := 0.0
var _heading := Vector2.RIGHT


func _ready() -> void:
	if mode == Mode.PATH:
		position = path_point(path_angle)
	if world:
		world.set_stage(player, stage)


func path_point(angle: float) -> Vector2:
	var r := path_radius + path_wobble * sin(angle * path_wobble_turns)
	return Vector2.from_angle(angle) * r * 16.0


func _physics_process(delta: float) -> void:
	if world and world.is_physics_processing():
		step(delta)


## One tick: move, eat, update the trail and crumbs. The stress scene calls it directly.
func step(delta: float) -> void:
	var before := position
	if mode == Mode.PATH:
		var r := path_radius * 16.0
		path_angle += path_dir * speed_tiles * 16.0 * delta / r
		position = path_point(path_angle)
	else:
		var v := Players.move_vector(player)
		if camera:
			v = v.rotated(camera.rotation)
		position += v * speed_tiles * 16.0 * delta
		var lim := (world.shape as DiskShape).radius * 16.0 - radius_px
		if position.length() > lim:
			position = position.normalized() * lim
		if Input.is_action_just_pressed(Players.action(player, "action")):
			drop_seed()
	var moved := position - before
	if moved.length_squared() > 0.01:
		_heading = moved.normalized()
	if world:
		var n := world.eat_circle(position, radius_px, player)
		eaten_total += n
		if n > 0:
			if sfx:
				sfx.play("world_munch", randf_range(0.9, 1.15))
			_add_crumbs(n)
	if _trail.is_empty() or _trail[0].distance_to(position) > radius_px * 0.6:
		_trail.push_front(position)
		if _trail.size() > 7:
			_trail.pop_back()
	_flash = maxf(0.0, _flash - delta)
	for c in _crumbs:
		c.t -= delta
		c.p += c.v * delta
	_crumbs = _crumbs.filter(func(c): return c.t > 0.0)
	queue_redraw()


func drop_seed() -> bool:
	var flavour := seeds[_seed_i % seeds.size()]
	_seed_i += 1
	# Behind the head, where it just ate (castings).
	var cell := world.shape.cell_at(position - _heading * radius_px * 0.5)
	var took := world.plant_seed(cell, flavour)
	if sfx:
		sfx.play("world_seed" if took else "world_blocked")
	_flash = 0.4
	seed_dropped.emit(cell, flavour, took)
	return took


func _add_crumbs(n: int) -> void:
	if _crumbs.size() > 24:
		return
	for i in mini(n, 3):
		var a := randf() * TAU
		_crumbs.append({"p": position + _heading * radius_px * 0.8, "v": Vector2.from_angle(a) * randf_range(30, 90), "t": 0.35})


func _draw() -> void:
	# Trail segments (drawn in world space: subtract our position).
	for i in range(_trail.size() - 1, -1, -1):
		var k := 1.0 - float(i + 1) / (_trail.size() + 1)
		draw_circle(_trail[i] - position, radius_px * (0.55 + 0.35 * k), color.darkened(0.25))
	draw_circle(Vector2.ZERO, radius_px + 3.0, Color(0.05, 0.05, 0.05))
	draw_circle(Vector2.ZERO, radius_px, color)
	# Belly stripe, eye, mouth toward the heading.
	draw_circle(_heading * radius_px * 0.15, radius_px * 0.55, color.lightened(0.25))
	var side := _heading.orthogonal()
	draw_circle(_heading * radius_px * 0.35 + side * radius_px * 0.3, radius_px * 0.28, Color.WHITE)
	draw_circle(_heading * radius_px * 0.45 + side * radius_px * 0.3, radius_px * 0.13, Color.BLACK)
	draw_arc(_heading * radius_px * 0.55, radius_px * 0.3, _heading.angle() - 0.9, _heading.angle() + 0.9, 8, Color(0.1, 0.02, 0.02), 4.0)
	if _flash > 0.0:
		draw_arc(Vector2.ZERO, radius_px * (1.2 + (0.4 - _flash) * 2.0), 0, TAU, 24, Color(1, 1, 0.6, _flash * 2.0), 4.0)
	for c in _crumbs:
		draw_rect(Rect2(c.p - position - Vector2(3, 3), Vector2(6, 6)), Color(0.55, 0.38, 0.2, c.t * 2.5))
