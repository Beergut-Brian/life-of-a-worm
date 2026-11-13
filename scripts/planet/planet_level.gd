## The grey-box game scene (scenes/levels/planet.tscn): one bait tin's planet. The real worm
## (scripts/worm/) tunnels through the real polar world (scripts/world/), eating tiles, food
## pickups and grubs; the dirt ring's apex beetle; the burrow; the shared rotating camera that zooms
## to fit; the HUD; autosave. scenes/main.gd hosts it under Arena and spawns the worms.
## Reads and writes the open tin through Save (BaitTins picks the slot before this is added).
class_name PlanetLevel
extends Node2D

signal worm_spawned(worm: Worm)

const RINGS := preload("res://data/rings/rings.tres")
const WORM_SCENE := preload("res://scenes/players/worm.tscn")
const FOOD_SCRIPT := preload("res://scripts/arena/arena_food.gd")
const SKY := Color("0d1430")
const BACK_WALL := Color("1b1712")
const RADIUS := 300
const START_DEPTH := 0.76
const AUTOSAVE := 30.0
## Planet seconds before an eaten pickup grows back where it was.
const FOOD_REGROW := 90.0
## Partner further than this (px) and the warp goes to the partner, not home.
const PARTNER_FAR := 420.0
const APEX_FOOD := preload("res://data/foods/grub.tres")
const FOOD_IDS: Array[StringName] = [&"grub", &"pebble", &"seed"]
## The worm names (Docket D90, Kaden, 2026-11-11): green (P1) Gulp, red (P2) Burp.
const WORM_NAMES := ["Gulp", "Burp"]

var world: PolarWorld
var camera: PolarCamera
## P-07: frames both worms up to the widest zoom, then follows one (the other gets an edge arrow).
var far_camera := FarCamera.new()
var burrow: Burrow
var beetle: ApexBeetle
## The stage-up beat (scripts/gameplay/stage_beat.gd; zoom caps per stage come from data/stages.tres).
var stage_beat: StageBeat
## The crust burst (scripts/gameplay/crust_burst.gd; the crust ring and its stage come from data/stages.tres).
var crust: CrustBurst
var hud: PlanetHud
## Stage 6 and the hand-off to space (scripts/chomp/chomp_director.gd).
var chomp: ChompDirector
## The home half of the vertical slice (scripts/burrow/home_slice.gd): trophies, pets, tackle box,
## the Mole's swap shop and their hints.
var home_slice: HomeSlice
var actors: Node2D
var foods_root: Node2D
var planet_seed := 4
var played := 0.0
var spawn_point := Vector2.ZERO
var autosave_every := AUTOSAVE
var saves := 0
## Off in tests that drive frames by hand.
var auto_spawn_demo := true
var _autosave_t := 0.0
var _tunnel: AudioStreamPlayer
var _glyphs := {}
var _worm_data := {}
var _bonk_t := 0.0
var _foods: Array[Dictionary] = []   # {node, home, gone_at}
var _demo: Node


func _ready() -> void:
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
		pts.append(Vector2.from_angle(TAU * i / 128.0) * RADIUS * 16.0)
	wall.polygon = pts
	wall.color = BACK_WALL
	wall.z_index = -4
	add_child(wall)
	var saved: Dictionary = Save.get_value("planet", {})
	planet_seed = int(Save.get_value("seed", planet_seed if Game.demo else randi() % 100000))
	world = PolarWorld.new()
	world.name = "World"
	world.add_to_group(&"world")
	# The crust ring is edible only from its stage and never regrows (data/stages.tres crust_ring).
	world.setup_planet(StageTable.default_table().apply_crust(RINGS), RADIUS, planet_seed, 32)
	add_child(world)
	if not saved.is_empty():
		world.load_save(saved)
	spawn_point = Vector2.from_angle(-PI / 2.0) * RADIUS * START_DEPTH * 16.0
	world.dig_blocked.connect(_on_dig_blocked)
	burrow = Burrow.new()
	burrow.name = "Burrow"
	burrow.world = world
	burrow.z_index = 1
	add_child(burrow)
	burrow.home_set.connect(func(_p: int, _at: Vector2) -> void: save_now())
	foods_root = Node2D.new()
	foods_root.name = "Foods"
	foods_root.z_index = 2
	add_child(foods_root)
	actors = Node2D.new()
	actors.name = "Actors"
	actors.z_index = 3
	add_child(actors)
	beetle = ApexBeetle.new()
	beetle.name = "ApexBeetle"
	beetle.world = world
	beetle.home = local_point(-20, 2)
	beetle.position = beetle.home
	actors.add_child(beetle)
	beetle.eaten.connect(_on_apex_eaten)
	beetle.ate_worm.connect(_on_worm_eaten)
	if saved.is_empty():
		_new_planet()
	else:
		burrow.from_dict(Save.get_value("burrow", {}))
		beetle.from_dict(Save.get_value("apex", {}))
		_load_foods(Save.get_value("foods", []))
		played = float(Save.get_value("played", 0.0))
		var wd: Dictionary = Save.get_value("worms", {})
		for k in wd:
			_worm_data[int(k)] = wd[k]
	camera = PolarCamera.new()
	camera.name = "Camera"
	camera.fit = true
	camera.max_fit_index = WormRules.default_rules().stage_info(1).zoom_index
	camera.zoom_index = camera.max_fit_index
	camera.position = spawn_point
	add_child(camera)
	camera.rotation = PolarCamera.up_rotation(spawn_point)
	camera.make_current()
	stage_beat = StageBeat.new()
	stage_beat.camera = camera
	stage_beat.world = world
	add_child(stage_beat)
	crust = CrustBurst.new()
	crust.camera = camera
	add_child(crust)
	crust.watch(world)
	crust.breakthrough.connect(func(_p: int) -> void: save_now())
	if not saved.is_empty():
		crust.from_dict(Save.get_value(CrustBurst.SAVE_KEY, {}))
	hud = PlanetHud.new()
	hud.level = self
	add_child(hud)
	home_slice = HomeSlice.new()
	home_slice.level = self
	add_child(home_slice)
	# Quitting at any moment loses nothing: save on quit (before Save.flush) and on pause.
	Game.quit_requested.connect(save_now)
	Game.state_changed.connect(func(_f: int, to: int) -> void:
		if to == Game.State.PAUSED:
			save_now())
	_tunnel = Audio.loop_player("tunnel")
	_tunnel.volume_db = -60.0
	add_child(_tunnel)
	chomp = ChompDirector.new()
	chomp.name = "Chomp"
	chomp.level = self
	add_child(chomp)
	if Game.demo and auto_spawn_demo:
		_demo = GreyboxDemo.new()
		_demo.name = "Demo"
		_demo.level = self
		add_child(_demo)


## A point in the start area's frame: x tiles to the right of the spawn, y tiles up (away from the core).
func local_point(x_tiles: float, y_tiles: float) -> Vector2:
	var up := spawn_point.normalized()
	var right := -up.orthogonal()
	return spawn_point + right * x_tiles * 16.0 + up * y_tiles * 16.0


## A fresh planet: a small pocket to start in and pickups round the start (seeded, same every time
## for a seed); the rest of the ring is plain dirt to tunnel.
func _new_planet() -> void:
	_carve(spawn_point, 18.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = planet_seed
	for i in 10:   # a grub trail, past the beetle
		_add_food(&"grub", local_point(-28.0 - i * 1.6, rng.randf_range(-1.0, 1.0)))
	_add_food(&"pebble", local_point(7, 0))
	_add_food(&"seed", local_point(9, 2))
	for i in 4:
		_add_food(&"pebble", local_point(12 + i * 2.0, rng.randf_range(-2.0, 2.0)))
	for i in 60:   # scattered round the ring near the start
		var a := -PI / 2.0 + rng.randf_range(-0.35, 0.35)
		var r := RADIUS * rng.randf_range(0.5, 0.8) * 16.0
		var id: StringName = [&"grub", &"grub", &"pebble", &"seed"][rng.randi() % 4]
		var p := Vector2.from_angle(a) * r
		if p.distance_to(spawn_point) > 80.0 and p.distance_to(beetle.home) > 100.0:
			_add_food(id, p)


func _carve(at: Vector2, r: float) -> void:
	var c := world.shape.cell_at(at)
	var n := ceili(r / 16.0)
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			var cell := c + Vector2i(x, y)
			if world.shape.center_of(cell).distance_to(at) <= r and world.is_edible_by(1, cell):
				world.dig(cell)


func _add_food(id: StringName, at: Vector2, gone_at := -1.0, home := Vector2.INF) -> Node2D:
	var f: Node2D = FOOD_SCRIPT.new()
	f.data = load("res://data/foods/%s.tres" % id)
	f.position = at
	foods_root.add_child(f)
	f.home = at if home == Vector2.INF else home
	var entry := { "node": f, "gone_at": gone_at }
	_foods.append(entry)
	f.taken.connect(func(_n: Node2D) -> void: entry.gone_at = world.clock)
	if gone_at >= 0.0:
		f.take()
		entry.gone_at = gone_at
	return f


func _load_foods(list: Array) -> void:
	for e in list:
		if e is Array and e.size() >= 6:
			_add_food(StringName(e[0]), Vector2(e[3], e[4]), float(e[5]), Vector2(e[1], e[2]))


func _foods_to_save() -> Array:
	var out := []
	for e in _foods:
		var f: Node2D = e.node
		out.append([String(f.data.id), f.home.x, f.home.y, f.position.x, f.position.y, e.gone_at])
	return out


# --- worms --------------------------------------------------------------------------------------

## Adds this player's worm: its saved body if the tin has one, else a fresh stage-1 worm at the
## start (P2 next to P1). Returns the worm.
func spawn_worm(player: int, at = null, start_stage := 0) -> Worm:
	var have := Worm.of(player)
	if have != null and have.get_parent() == actors:
		return have
	var w: Worm = WORM_SCENE.instantiate()
	w.player = player
	w.wall_anywhere = false
	var model := WormGrowth.new()
	model.apex_gate = true
	w.model = model
	if _worm_data.has(player):
		w.from_dict(_worm_data[player])
		model.apex_gate = true
	elif start_stage > 1:
		model.start_at_stage(start_stage)
	var pos: Vector2 = spawn_point + Vector2(0, 0) if player == Players.P1 else spawn_point + (spawn_point.normalized().orthogonal() * 14.0)
	if at is Vector2:
		pos = at
	elif _worm_data.has(player) and _worm_data[player].has("pos"):
		pos = Vector2(_worm_data[player].pos[0], _worm_data[player].pos[1])
	w.set_meta("start_pos", pos)
	w.heading = 0.0 if player == Players.P1 else PI
	actors.add_child(w)
	w.set_world(world)
	world.track_eater(w.head)
	w.warp_requested.connect(_on_warp_requested)
	w.stage_changed.connect(_on_stage_changed)
	var g := ReadyGlyph.new()
	g.worm = w
	g.camera = camera
	g.z_index = 40
	add_child(g)
	_glyphs[player] = g
	_refresh_camera_targets()
	worm_spawned.emit(w)
	return w


## Drop-in: a second worm hatches from an egg next to the first, at the first's stage minus one
## (or its own saved body, if it played in this tin before).
func drop_in(player: int) -> WormEgg:
	var first: Worm = null
	for w in Worm.all():
		if w.player != player and w.get_parent() == actors:
			first = w
	if Worm.of(player) != null:
		return null
	var at := spawn_point
	var stage := 1
	if first:
		var up := first.cam_position().normalized()
		at = first.cam_position() + up.orthogonal() * 18.0
		stage = maxi(1, first.model.stage - 1)
	var egg := WormEgg.new()
	egg.player = player
	egg.position = at
	egg.z_index = 4
	add_child(egg)
	egg.hatched.connect(func() -> void:
		var w := spawn_worm(player, at, stage)
		w.hatch())
	return egg


func remove_worm(player: int) -> void:
	var w := Worm.of(player)
	if w == null:
		return
	_worm_data[player] = w.to_dict()
	world.untrack_eater(w.head)
	if _glyphs.has(player):
		_glyphs[player].queue_free()
		_glyphs.erase(player)
	w.get_parent().remove_child(w)
	w.queue_free()
	_refresh_camera_targets()


## Both worms while they fit the widest zoom; past it, only the anchor worm (FarCamera, P-07).
func _refresh_camera_targets() -> void:
	var t: Array[Node2D] = []
	for w in Worm.all():
		if w.get_parent() == actors and not w.is_queued_for_deletion():
			t.append(w)
	camera.targets = far_camera.step(camera, t, Players.solo_focus if Players.solo else -1)


func max_stage() -> int:
	var s := 1
	for w in Worm.all():
		s = maxi(s, w.model.stage)
	return s


# --- frame -------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	played += delta
	if chomp and chomp.busy():
		# the planet shot or space owns the screen; the disk waits, and the tin still autosaves
		_tunnel_step(false, delta)
		_autosave_t += delta
		if _autosave_t >= autosave_every:
			save_now()
		return
	var any_carry := false
	var any_burrow := false
	var digging := 0
	for w in Worm.all():
		if w.get_parent() != actors:
			continue
		w.view_rotation = camera.rotation
		var local := world.to_local(w.head_position())
		var in_room := burrow.in_room(local)
		# The trait wall is the bed's: Y opens it while asleep at home; awake, Y is the tackle box.
		w.in_burrow = in_room and (w.asleep or w.wall_open)
		burrow.note_pickup(w, in_room)
		if burrow.world and burrow.can_sleep(w):
			burrow.sleep(w)
		if w.carrying != null and is_instance_valid(w.carrying) and in_room and burrow.should_bring(w):
			burrow.bring(w, w.carrying)
		any_carry = any_carry or w.carry_ready or w.carrying != null
		any_burrow = any_burrow or w.in_burrow
		digging += w.tiles_this_frame
		if _glyphs.has(w.player):
			var tok := ""
			if w.carry_ready and w.carrying == null:
				tok = "x"
			elif w.in_burrow and not w.wall_open:
				tok = "y"
			_glyphs[w.player].token = tok
	hud.set_context(any_carry, burrow.has_home, any_burrow)
	crust.steer_camera(stage_beat.zoom_cap())
	_refresh_camera_targets()
	_tunnel_step(digging > 0, delta)
	_bonk_t = maxf(0.0, _bonk_t - delta)
	for e in _foods:
		if e.gone_at >= 0.0 and world.clock >= e.gone_at + FOOD_REGROW:
			e.gone_at = -1.0
			e.node.respawn()
	_autosave_t += delta
	if _autosave_t >= autosave_every:
		save_now()


func _tunnel_step(on: bool, delta: float) -> void:
	if on and not _tunnel.playing:
		_tunnel.play()
	var want := -8.0 if on else -60.0
	_tunnel.volume_db = move_toward(_tunnel.volume_db, want, delta * (160.0 if on else 60.0))
	if _tunnel.playing and _tunnel.volume_db <= -59.0:
		_tunnel.stop()


func _unhandled_input(event: InputEvent) -> void:
	# Solo playtest: Select hands the pad to the other worm (Select alone does nothing otherwise).
	if Players.solo and event.is_action_pressed("restart") and Worm.all().size() > 1:
		Players.set_solo_focus(Players.P2 if Players.solo_focus == Players.P1 else Players.P1)
		Audio.play("solo_focus")
		var w := Worm.of(Players.solo_focus)
		if w:
			w._pop(w.look, 1.5)


func _on_dig_blocked(_cell: Vector2i, _block: StringName, player: int) -> void:
	if player >= 0 and _bonk_t <= 0.0:
		_bonk_t = 0.6
		Audio.play("bonk")
		var w := Worm.of(player)
		if w:
			w._pop(w.look, 0.85)


func _on_warp_requested(player: int) -> void:
	var w := Worm.of(player)
	if w == null:
		return
	var partner: Worm = null
	for o in Worm.all():
		if o != w and o.get_parent() == actors:
			partner = o
	var to = null
	if partner and partner.cam_position().distance_to(w.cam_position()) > PARTNER_FAR and w.model.stage <= partner.model.stage:
		to = partner.cam_position() + partner.cam_position().normalized().orthogonal() * 16.0
	elif burrow.has_home:
		to = burrow.home
	elif partner and partner.cam_position().distance_to(w.cam_position()) > PARTNER_FAR:
		to = partner.cam_position() + partner.cam_position().normalized().orthogonal() * 16.0
	if to == null:
		Audio.play("bonk")
		w._pop(w.look, 0.8)
		return
	w.warp_to(to)


func _on_apex_eaten(player: int) -> void:
	var w := Worm.of(player)
	if w == null:
		return
	Audio.play("now_i_eat_you")
	w.feed(APEX_FOOD)
	w.model.eat_apex(beetle.ring_stage)
	save_now()


func _on_worm_eaten(_player: int) -> void:
	if SettingsPanel.screen_shake():
		camera.shake = maxf(camera.shake, 0.4)


## The stage-up beat (StageBeat: swell, flash, shake, the "why" picture, camera pull-back, the new
## ring's pulse, the dock cutscene), then a save.
func _on_stage_changed(player: int, from: int, to: int) -> void:
	var w := Worm.of(player)
	if w and to > from and w.model.last_cause != &"hatch":
		stage_beat.play(w, from, to)
	print("stage_up: %s %d -> %d (%s)" % [WORM_NAMES[player], from, to, w.model.last_cause if w else &""])
	save_now()


# --- save ---------------------------------------------------------------------------------------

## Writes the whole tin (planet, worms, burrow, apex, pickups) and flushes it to disk.
func save_now() -> void:
	_autosave_t = 0.0
	saves += 1
	Save.set_value("seed", planet_seed)
	Save.set_value("planet", world.to_save())
	var worms := {}
	for p in _worm_data:
		worms[str(p)] = _worm_data[p]
	for w in Worm.all():
		if w.get_parent() == actors:
			worms[str(w.player)] = w.to_dict()
	Save.set_value("worms", worms)
	Save.set_value("stage", 7 if ChompDirector.eaten() else max_stage())
	Save.set_value("burrow", burrow.to_dict())
	Save.set_value("apex", beetle.to_dict())
	Save.set_value("foods", _foods_to_save())
	Save.set_value("played", played)
	if crust:
		Save.set_value(CrustBurst.SAVE_KEY, crust.to_dict())
	if home_slice:
		Save.set_value(HomeSlice.SAVE_KEY, home_slice.to_dict())
	Save.flush()
