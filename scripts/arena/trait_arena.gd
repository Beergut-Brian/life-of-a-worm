## Risk prototype R-c arena: open dirt room, plain walls, a puddle, food of every flavour in
## clusters (regrows), boulders that need a bigger worm or a harder head. Spawns a worm per joined
## player; a late joiner hatches next to the first worm one stage smaller.
## Run: godot --path . res://scenes/levels/trait_arena.tscn [-- --demo-traits | --perf-traits]
extends Node2D

const WORM_SCENE := preload("res://scenes/players/worm.tscn")
const ArenaFoodScript := preload("res://scripts/arena/arena_food.gd")
const DemoFeeder := preload("res://scripts/arena/demo_feeder.gd")
const SIZE := Vector2(960, 540)
const WALL := 16.0
const REGROW := 8.0
const WALL_COLOR := Color("6b5a4e")
const DIRT := Color("5a3d2b")
const INNER_WALLS := [Rect2(300, 60, 18, 150), Rect2(640, 340, 18, 150), Rect2(560, 120, 90, 18)]
## Food path -> cluster centres.
const CLUSTERS := {
	"res://data/foods/grub.tres": [Vector2(170, 140)],
	"res://data/foods/pebble.tres": [Vector2(170, 410)],
	"res://data/foods/crystal.tres": [Vector2(470, 440)],
	"res://data/foods/bottle_cap.tres": [Vector2(800, 130)],
	"res://data/foods/droplet.tres": [Vector2(800, 420)],
	"res://data/foods/seed.tres": [Vector2(450, 90)],
}
const BOULDERS := {
	"res://data/foods/boulder.tres": [Vector2(330, 300), Vector2(560, 330), Vector2(250, 250)],
	"res://data/foods/big_boulder.tres": [Vector2(600, 220)],
}

@onready var camera: ArenaCamera = $Camera
@onready var worms_root: Node2D = $Worms
@onready var food_root: Node2D = $Food

var demo := false
var perf := false
var feeder: DemoFeeder
var _rng := RandomNumberGenerator.new()
var _perf_samples: Array[float] = []
var _perf_t := 0.0
var _clock := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	demo = args.has("--demo-traits")
	perf = args.has("--perf-traits")
	_rng.seed = 4
	_build_walls()
	_spawn_food()
	Players.player_joined.connect(_on_player_joined)
	Players.player_left.connect(_on_player_left)
	if Game.state != Game.State.PLAYING:
		Game.start_round()
	if demo or perf:
		feeder = DemoFeeder.new()
		feeder.arena = self
		add_child(feeder)
		Players.join_virtual(Players.P1)
		if perf:
			Players.join_virtual(Players.P2)
			feeder.setup_perf()
	for p in Players.active_players():
		spawn(p)


func _process(delta: float) -> void:
	_clock += delta
	if perf and _clock > 2.0:
		_perf_samples.append(delta)
		_perf_t += delta
		if _perf_t >= 6.0:
			_report_perf()


func spawn(player: int) -> Worm:
	var existing := Worm.of(player)
	if existing != null:
		return existing
	var w: Worm = WORM_SCENE.instantiate()
	w.player = player
	w.name = "Worm%d" % (player + 1)
	var first: Worm = null
	for o in Worm.all():
		first = o
		break
	w.model = WormGrowth.new()
	if first != null:
		w.model.start_at_stage(maxi(1, first.model.stage - 1))
		w.position = first.head_position() + Vector2(0, -36)
	else:
		w.position = Vector2(400, 270)
	if feeder != null:
		w.autopilot = feeder.drive
	worms_root.add_child(w)
	w.trait_earned.connect(func(_p: int, _id: StringName) -> void: camera.punch(8.0))
	w.stage_changed.connect(func(_p: int, _a: int, _b: int) -> void:
		camera.flash()
		camera.punch(5.0))
	if first != null:
		w.scale = Vector2.ZERO
		create_tween().tween_property(w, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
		Audio.play("hatch")
	return w


func _on_player_joined(player: int, _device: int) -> void:
	spawn(player)


func _on_player_left(player: int) -> void:
	var w := Worm.of(player)
	if w != null:
		w.queue_free()


func _on_food_taken(f: ArenaFood) -> void:
	get_tree().create_timer(REGROW).timeout.connect(f.respawn)


func _build_walls() -> void:
	var rects: Array = [
		Rect2(-WALL, -WALL, SIZE.x + WALL * 2, WALL), Rect2(-WALL, SIZE.y, SIZE.x + WALL * 2, WALL),
		Rect2(-WALL, 0, WALL, SIZE.y), Rect2(SIZE.x, 0, WALL, SIZE.y)]
	rects.append_array(INNER_WALLS)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for r: Rect2 in rects:
		var shape := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = r.size
		shape.shape = rs
		shape.position = r.get_center()
		body.add_child(shape)
	add_child(body)


func _spawn_food() -> void:
	for path in CLUSTERS:
		var data: FoodData = load(path)
		for c: Vector2 in CLUSTERS[path]:
			for i in 12:
				var a := TAU * i / 12.0 + _rng.randf() * 0.4
				var r := 14.0 + (i % 3) * 16.0 + _rng.randf() * 6.0
				_add_food(data, c + Vector2.from_angle(a) * r)
	for path in BOULDERS:
		var data: FoodData = load(path)
		for c: Vector2 in BOULDERS[path]:
			_add_food(data, c)


func _add_food(data: FoodData, at: Vector2) -> void:
	var f: ArenaFood = ArenaFoodScript.new()
	f.data = data
	f.position = at
	f.taken.connect(_on_food_taken)
	food_root.add_child(f)


func _draw() -> void:
	draw_rect(Rect2(-SIZE, SIZE * 3.0), WALL_COLOR.darkened(0.3))
	draw_rect(Rect2(Vector2.ZERO, SIZE), DIRT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 420:
		var p := Vector2(rng.randf() * SIZE.x, rng.randf() * SIZE.y)
		var c := DIRT.lightened(0.12) if i % 3 else DIRT.darkened(0.18)
		draw_rect(Rect2(p.floor(), Vector2(2, 2) if i % 5 else Vector2(3, 2)), c)
	var walls: Array = [
		Rect2(-WALL, -WALL, SIZE.x + WALL * 2, WALL), Rect2(-WALL, SIZE.y, SIZE.x + WALL * 2, WALL),
		Rect2(-WALL, 0, WALL, SIZE.y), Rect2(SIZE.x, 0, WALL, SIZE.y)]
	walls.append_array(INNER_WALLS)
	for r: Rect2 in walls:
		draw_rect(r, WALL_COLOR)
		draw_rect(r.grow(-3), WALL_COLOR.lightened(0.12))
		draw_rect(r, Color("2a1a14"), false, 2.0)


func _report_perf() -> void:
	var n := _perf_samples.size()
	var total := 0.0
	var worst := 0.0
	for s in _perf_samples:
		total += s
		worst = maxf(worst, s)
	var segs := 0
	var traits := 0
	for w in Worm.all():
		segs += w.model.segments.size()
		traits += w.model.active.size()
	print("perf-traits: worms=%d segments=%d active_traits=%d frames=%d avg_frame_ms=%.2f worst_frame_ms=%.2f process_ms=%.3f physics_ms=%.3f renderer=%s" % [
		Worm.all().size(), segs, traits, n, total / maxf(n, 1) * 1000.0, worst * 1000.0,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		DisplayServer.get_name()])
	perf = false
	get_tree().quit()
