## The disk planet scene for prototype R-a: the polar world, two stand-in eaters, the rotating
## camera, a planet-shot zoom. Not the game's disk level yet (the gameplay lane builds that on top).
## CLI (after --): --demo-polar runs a scripted tour hands-free; --radius=<tiles> --seed=<n>.
## Play: P1 stick tunnels (screen-relative), P1 action drops a seed in castings, P1 jump toggles the
## planet shot. P2 follows a path on the far side so two neighbourhoods stream at once.
class_name DiskLevel
extends Node2D

const RINGS := preload("res://data/rings/rings.tres")
const SKY := Color("0d1430")
const BACK_WALL := Color("161a24")

@export var radius := 500
@export var planet_seed := 4
@export var band := 32
var demo := false

var world: PolarWorld
var camera: PolarCamera
var sfx: WorldSfx
var eaters: Array[StandInEater] = []
var overview: Sprite2D

var _t := 0.0
var _zoom_target := 5
var _zoom_acc := 0.0
var _demo_steps: Array = []
var _sparkles: Node2D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--demo-polar":
			demo = true
		elif a.begins_with("--radius="):
			radius = int(a.get_slice("=", 1))
		elif a.begins_with("--seed="):
			planet_seed = int(a.get_slice("=", 1))
	sfx = WorldSfx.new()
	sfx.name = "Sfx"
	add_child(sfx)
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	var sky := ColorRect.new()
	sky.color = SKY
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky_layer.add_child(sky)
	add_child(sky_layer)
	var wall := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 128:
		pts.append(Vector2.from_angle(TAU * i / 128.0) * radius * 16.0)
	wall.polygon = pts
	wall.color = BACK_WALL
	wall.z_index = -4
	add_child(wall)
	overview = Sprite2D.new()
	overview.z_index = -3
	add_child(overview)
	world = PolarWorld.new()
	world.name = "World"
	world.add_to_group(&"world")
	world.setup_planet(RINGS, radius, planet_seed, band)
	add_child(world)
	overview.texture = world.planet_texture()
	overview.scale = Vector2.ONE * PolarWorld.OVERVIEW_STEP * 16.0
	_sparkles = RegrowSparkles.new()
	_sparkles.z_index = 2
	add_child(_sparkles)
	world.tile_regrown.connect(func(cell: Vector2i, _b: StringName) -> void: _sparkles.add(world.shape.center_of(cell)))
	world.garden_grew.connect(func(cell: Vector2i, _f: StringName) -> void: _sparkles.add(world.shape.center_of(cell)))
	var actors := Node2D.new()
	actors.name = "Actors"
	actors.z_index = 1
	add_child(actors)
	camera = PolarCamera.new()
	camera.name = "Camera"
	var p1 := _eater(0, Players.COLOR[Players.P1], -PI / 2.0, StandInEater.Mode.PATH if demo else StandInEater.Mode.STICK)
	var p2 := _eater(1, Players.COLOR[Players.P2], PI / 2.0, StandInEater.Mode.PATH)
	for e in [p1, p2]:
		actors.add_child(e)
		world.track_eater(e)
	if not demo:
		p1.position = Vector2.from_angle(-PI / 2.0) * radius * 0.93 * 16.0
	camera.targets = [p1]
	add_child(camera)
	camera.snap()
	camera.make_current()
	world.tile_regrown.connect(func(cell: Vector2i, _b: StringName) -> void: _near_sfx(cell, "world_regrow"))
	world.garden_grew.connect(func(cell: Vector2i, _f: StringName) -> void: _near_sfx(cell, "world_sprout"))
	world.dig_blocked.connect(func(cell: Vector2i, _b: StringName, _p: int) -> void: _near_sfx(cell, "world_blocked"))
	if demo:
		# Planet time x4: topsoil castings regrow in ~11 s, gardens fill a cell a second.
		world.time_scale = 4.0
		p1.speed_tiles = 20.0
		camera.zoom_index = 4
		_zoom_target = 4
		_demo_steps = [
			[1.0, func() -> void: p1.drop_seed()],
			[1.6, func() -> void: p1.drop_seed()],
			[2.2, func() -> void: p1.drop_seed()],
			# Zigzag past the gardens, a little deeper each pass, so the camera stays on them while
			# the first tunnel regrows (sparkles) and the patches spread.
			[5.0, func() -> void:
				p1.path_dir = -1.0
				p1.path_radius -= 7.0],
			[9.5, func() -> void:
				p1.path_dir = 1.0
				p1.path_radius -= 7.0],
			[18.0, func() -> void: set_planet_shot(true)],
			[23.0, func() -> void: set_planet_shot(false)],
		]


func _eater(player: int, col: Color, angle: float, mode: StandInEater.Mode) -> StandInEater:
	var e := StandInEater.new()
	e.name = "Eater%d" % (player + 1)
	e.world = world
	e.sfx = sfx
	e.camera = camera
	e.player = player
	e.color = col
	e.mode = mode
	e.path_angle = angle
	e.path_radius = radius * 0.9
	e.path_wobble = radius * 0.05
	e.path_wobble_turns = 9.0
	return e


func set_planet_shot(on: bool) -> void:
	_zoom_target = 0 if on else (4 if demo else 5)
	camera.centre_override = Vector2.ZERO if on else null
	sfx.play("world_seed", 0.6 if on else 1.3)


func _near_sfx(cell: Vector2i, cue: String) -> void:
	if world.shape.center_of(cell).distance_to(camera.position) < 1400.0 / camera.zoom.x:
		sfx.play(cue)


func _process(delta: float) -> void:
	_t += delta
	while not _demo_steps.is_empty() and _t >= _demo_steps[0][0]:
		_demo_steps.pop_front()[1].call()
	if not demo and Input.is_action_just_pressed(Players.action(0, "jump")):
		set_planet_shot(_zoom_target != 0)
	_zoom_acc += delta
	if camera.zoom_index != _zoom_target and _zoom_acc >= 0.3:
		_zoom_acc = 0.0
		camera.zoom_index += signi(_zoom_target - camera.zoom_index)
	overview.modulate.a = clampf((0.5 - camera.zoom.x) / 0.25, 0.0, 1.0)
	# Zoomed right out, the overview (edits drawn in) stands in for the live chunks' tile grid.
	world.visible = camera.zoom.x > 0.2
