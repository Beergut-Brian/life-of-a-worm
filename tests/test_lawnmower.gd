## L-12 the lawnmower (data/creatures/lawnmower.tres, scripts/creatures/lawnmower.gd): it drives
## back and forth on the surface line and stays there, is never food and never eats a worm, mows
## grass and nothing else, bumps a worm off the grass (after its warning) with the cause beat, and
## every cue it plays is a real file. It spawns from the surface ring's own counter only.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const MOWER := preload("res://scenes/creatures/lawnmower.tscn")
const GRUB := preload("res://scenes/creatures/grub.tscn")
const DATA_PATH := "res://data/creatures/lawnmower.tres"
const SFX_DIR := "res://assets/audio/sfx/"
const RADIUS := 300
const DT := 1.0 / 60.0
const UP := -PI / 2.0

var _nodes: Array[Node] = []


func before() -> void:
	SuiteSandbox.enter("lawnmower")


func after() -> void:
	for p in Audio._pool:
		p.stop()
	SuiteSandbox.leave()


func before_test() -> void:
	Audio.played.clear()


func after_test() -> void:
	for i in range(_nodes.size() - 1, -1, -1):
		var n := _nodes[i]
		if is_instance_valid(n):
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.free()
	_nodes.clear()
	for p in Audio._pool:
		p.stop()


func _keep(n: Node) -> Node:
	_nodes.append(n)
	return n


func _world() -> PolarWorld:
	var w := PolarWorld.new()
	w.build_overview = false
	w.setup_planet(RINGS, RADIUS, 7)
	add_child(w)
	w.set_physics_process(false)
	return _keep(w)


func _worm(at: Vector2, stage := 1, player := Players.P1) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = player
	w.model = WormGrowth.new()
	if stage > 1:
		w.model.start_at_stage(stage)
	w.set_meta("start_pos", at)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	w.set_physics_process(false)
	w.head.global_position = at
	return _keep(w)


func _mower(at: Vector2, world: PolarWorld = null) -> Lawnmower:
	var m: Lawnmower = MOWER.instantiate()
	m.world = world
	m.position = at
	add_child(m)
	m.set_physics_process(false)
	m.drive_dir = 1.0
	m._place()
	return _keep(m)


func _steps(m: Lawnmower, n: int) -> void:
	for i in n:
		m.step(DT)


func _r0() -> float:
	return float(RADIUS) * 16.0


static func _has_file(cue: String) -> bool:
	return ResourceLoader.exists(SFX_DIR + cue + ".ogg") or ResourceLoader.exists(SFX_DIR + cue + "_1.ogg")


# --- data --------------------------------------------------------------------------------------

func test_the_mower_is_data_with_size_speed_bump_and_cues() -> void:
	var d = load(DATA_PATH)
	assert_bool(d is LawnmowerData).is_true()
	assert_str(String(d.id)).is_equal("lawnmower")
	assert_str(String(d.ring)).is_equal("surface")
	assert_int(d.size_stage).is_equal(5)
	assert_float(d.radius).is_greater(0.0)
	assert_float(d.speed).is_greater(0.0)
	assert_float(d.bump).is_greater(0.0)
	assert_float(d.telegraph_time()).is_greater_equal(1.0)
	assert_bool(d.jarling).is_false()
	assert_str(d.scene).is_equal("res://scenes/creatures/lawnmower.tscn")


func test_every_mower_cue_resolves_to_a_real_file() -> void:
	var d: LawnmowerData = load(DATA_PATH)
	for cue in [d.cue, d.bark, d.bump_cue]:
		assert_str(cue).is_not_empty()
		assert_bool(_has_file(cue)).override_failure_message("no file for cue '%s'" % cue).is_true()
		assert_object(Audio._resolve(Audio.SFX_DIR, cue, true)).is_not_null()
	# the engine loop is the real file, not the grey placeholder beep
	var p := Audio.loop_player(d.cue)
	assert_bool(p.stream is AudioStreamOggVorbis).is_true()
	p.free()


# --- it stays on the surface -----------------------------------------------------------------

func test_it_drives_back_and_forth_on_the_surface_and_stays_there() -> void:
	var world := _world()
	var m := _mower(Vector2.from_angle(UP) * _r0() * 0.99, world)
	var d: LawnmowerData = m.mower()
	var turned := 0
	var last_dir := m.drive_dir
	var start_angle := m.angle
	for i in 60 * 40:
		m.step(DT)
		if m.drive_dir != last_dir:
			turned += 1
			last_dir = m.drive_dir
		if i % 30 == 0:
			var ground := m.ground_r(m.angle)
			# on the ground line: its wheels on the grass, never sunk in, never flying
			assert_float(absf(m.position.length() - ground - m._body_h())).is_less(0.5)
			assert_float(ground).is_greater(_r0() * 0.985)
			assert_float(ground).is_less(_r0() * 1.02)
			# never further round than its drive reach (plus one frame)
			var off := absf(wrapf(m.angle - start_angle, -PI, PI)) * ground
			assert_float(off).is_less_equal(d.drive + d.speed * DT * 2.0)
	assert_int(turned).is_greater_equal(2)


func test_it_never_turns_toward_a_worm() -> void:
	var m := _mower(Vector2.from_angle(UP) * _r0())
	# a small worm behind it on the grass: it carries on its way, it does not hunt
	var behind := m.position - m.way() * 120.0
	_worm(behind, 2)
	var dir := m.drive_dir
	var a0 := m.angle
	_steps(m, 60)
	assert_float(m.drive_dir).is_equal(dir)
	assert_float(signf(wrapf(m.angle - a0, -PI, PI))).is_equal(dir)


# --- never food, never eats a worm -----------------------------------------------------------

func test_it_is_never_food_and_never_eats_a_worm() -> void:
	var m := _mower(Vector2.from_angle(UP) * _r0())
	var ate := [0]
	m.ate_worm.connect(func(_p: int) -> void: ate[0] += 1)
	assert_bool(m.is_in_group(&"food")).is_false()
	assert_bool(m.is_available()).is_false()
	for stage in [1, 4, 5, 7]:
		var w := _worm(m.position + m.way() * 2.0 + Vector2(stage * 0.01, 0), stage, Players.P1)
		assert_bool(m.can_be_eaten_by(w)).is_false()
		assert_bool(m.threatens(w)).is_false()
		var n := w.model.segments.size()
		_steps(m, 150)   # past the telegraph: small ones are bumped, none is eaten
		assert_int(w.model.segments.size()).is_equal(n)
		assert_int(w.model.stage).is_equal(stage)
		_nodes.erase(w)
		remove_child(w)
		w.free()
	m.take()   # even a stage-7 worm's bite does nothing
	assert_bool(m.is_queued_for_deletion()).is_false()
	assert_int(ate[0]).is_equal(0)
	assert_int(Audio.played.get("eaten", 0)).is_equal(0)


# --- eats grass only -------------------------------------------------------------------------

func test_it_mows_grass_and_nothing_else() -> void:
	var world := _world()
	var m := _mower(Vector2.from_angle(UP) * _r0() * 0.99, world)
	var blocks := {}
	world.tile_dug.connect(func(_c: Vector2i, block: StringName, _p: int) -> void:
		blocks[block] = int(blocks.get(block, 0)) + 1)
	# an apple on the grass in its way, and a grub beside it: neither is touched
	var apple := RingPickup.new()
	apple.data = load("res://data/foods/apple.tres")
	apple.position = m.position + m.way() * 60.0
	add_child(apple)
	_keep(apple)
	var grub: Creature = GRUB.instantiate()
	grub.position = m.position + m.way() * 90.0
	add_child(grub)
	grub.set_physics_process(false)
	_keep(grub)
	_steps(m, 60 * 8)
	assert_int(m.mowed_count).is_greater(3)
	assert_array(blocks.keys()).contains_exactly([&"grass"])
	assert_int(blocks[&"grass"]).is_equal(m.mowed_count)
	assert_bool(apple.is_available()).is_true()
	assert_bool(apple.is_queued_for_deletion()).is_false()
	assert_bool(grub.is_queued_for_deletion()).is_false()
	assert_bool(grub.is_available()).is_true()


# --- the bump and its cause beat -------------------------------------------------------------

func test_the_bump_knocks_the_worm_off_the_grass_with_the_cause_beat() -> void:
	var cam := PolarCamera.new()
	add_child(cam)
	_keep(cam)
	cam.make_current()
	var m := _mower(Vector2.from_angle(UP) * _r0())
	var beat := []
	m.beat_requested.connect(func(p: int, at: Vector2) -> void: beat.append([p, at]))
	var w := _worm(m.global_position + m.way() * (m.data.radius + 4.0), 4)
	var n := w.model.segments.size()
	# the warning first: a bark, and no bump before the telegraph (a full second and more)
	m.step(DT)
	assert_int(Audio.played.get(m.data.bark, 0)).is_equal(1)
	var waited := DT
	while m.bumps == 0 and waited < 3.0:
		m.step(DT)
		waited += DT
	assert_int(m.bumps).is_equal(1)
	assert_float(waited).is_greater_equal(m.data.telegraph_time())
	# the cause beat was asked for: signal, camera shake and lean, the bump cue, the shadow flash
	assert_int(m.beats).is_equal(1)
	assert_int(beat.size()).is_equal(1)
	assert_int(beat[0][0]).is_equal(Players.P1)
	assert_int(Audio.played.get(m.mower().bump_cue, 0)).is_equal(1)
	assert_int(cam.lean_in).is_equal(1)
	if SettingsPanel.screen_shake():
		assert_float(cam.shake).is_greater(0.0)
	assert_float(m._flash).is_greater(0.0)
	# the knock: up off the grass and away from the mower, most of `bump` px in half a second
	var r_before := w.head_position().length()
	var d_before := w.head_position().distance_to(m.global_position)
	var at_bump := w.head_position()
	_steps(m, 30)
	assert_float(w.head_position().length() - r_before).is_greater(m.mower().bump * 0.5)
	assert_float(w.head_position().distance_to(m.global_position)).is_greater(d_before + 40.0)
	assert_float(w.head_position().distance_to(at_bump)).is_less_equal(m.mower().bump * 1.05)
	assert_float(w.head_position().distance_to(m.global_position)).is_greater(m.touch_range(w))
	# a bump, never a bite
	assert_int(w.model.segments.size()).is_equal(n)
	# the beat lets go of the camera
	_steps(m, 30)
	assert_int(cam.lean_in).is_equal(0)


func test_a_worm_bigger_than_the_mower_is_never_bumped() -> void:
	var m := _mower(Vector2.from_angle(UP) * _r0())
	var w := _worm(m.global_position + m.way() * 10.0, 7)
	var dir := m.drive_dir
	var at := w.head_position()
	_steps(m, 120)
	assert_int(m.bumps).is_equal(0)
	assert_float(m.drive_dir).is_equal(-dir)   # honks and turns round
	assert_vector(w.head_position()).is_equal(at)


func test_the_same_worm_is_not_juggled() -> void:
	var m := _mower(Vector2.from_angle(UP) * _r0())
	var w := _worm(m.global_position + m.way() * 10.0, 2)
	_steps(m, 60 * 2)
	assert_int(m.bumps).is_equal(1)
	# put it straight back in the way: a cooldown and a fresh warning before the next bump
	w.head.global_position = m.global_position + m.way() * 10.0
	_steps(m, 30)
	assert_int(m.bumps).is_equal(1)


# --- spawned by the surface ring's counter, only there ----------------------------------------

func test_the_surface_counter_spawns_one_mower_on_the_grass() -> void:
	var world := _world()
	var start := Vector2.from_angle(UP) * _r0() * 0.995
	var w := _worm(start, 4)
	world.track(w.head)
	world.update_chunks(-1)
	var dir := RingsDirector.new()
	dir.auto_tick = false
	add_child(dir)
	_keep(dir)
	dir.setup(world, start, 4, {})
	dir.hook_worm(w)
	var rule: PopulationRule = dir.ecology.rules[&"lawnmower"]
	assert_str(rule.live).is_equal("res://scenes/creatures/lawnmower.tscn")
	assert_str(String(rule.ring)).is_equal("surface")
	# the ring's own data is untouched (counted, no body there)
	assert_int((RingsDirector.SURFACE.species.filter(func(r): return r.id == &"lawnmower")[0] as PopulationRule).live_max).is_equal(0)
	# no other ring spawns it
	for id in dir.ecology.rules:
		if id != &"lawnmower":
			assert_bool(dir.ecology.rules[id].live.contains("lawnmower")).is_false()
	for i in 80:
		dir.fit_live()
		if not dir.live_of(&"lawnmower").is_empty():
			break
	var mowers := dir.live_of(&"lawnmower")
	assert_int(mowers.size()).is_equal(1)
	var m: Lawnmower = mowers[0]
	m.set_physics_process(false)
	assert_float(absf(m.position.length() - m.ground_r(m.angle) - m._body_h())).is_less(0.5)
	for i in 20:
		dir.fit_live()
	assert_int(dir.live_of(&"lawnmower").size()).is_equal(1)
