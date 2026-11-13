## Regrowth (G-02, G-04; worm-regrow-1): the whole world regrows on its own at each ring's regrow
## time from data/rings/rings.tres, and a ring is never exhausted for a worm still in it (30
## simulated minutes per ring at balance numbers); food regrows faster and bigger in castings
## (RingDef.castings_size), a big tile is worth more growth; regrowth stops in the jar view.
## Real PolarWorld and planet clock; the jar-view case boots planet.tscn in its own sandbox profile,
## its own bait tin files and a scratch jar shelf.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const PLANET := preload("res://scenes/levels/planet.tscn")
const JAR_DIR := "user://test_regrowth_rings_jars"
const SIM_SECONDS := 1800.0   # 30 planet minutes
const SIM_DT := 0.25

var _world: PolarWorld
var _worm: Worm
var _level: PlanetLevel


func before() -> void:
	SuiteSandbox.enter("regrowth_rings")


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	_hush()
	SuiteSandbox.leave()


func after_test() -> void:
	_hush()
	if is_instance_valid(_level):
		for p in _level.find_children("*", "AudioStreamPlayer", true, false):
			(p as AudioStreamPlayer).stop()
		remove_child(_level)
		_level.free()
	_level = null
	for n in [_worm, _world]:
		if is_instance_valid(n):
			remove_child(n)
			n.free()
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _hush() -> void:
	for p in Audio._pool:
		p.stop()
		p.stream = null


## A small real world with a real worm (its eating feeds the worm through tile_eaten).
func _small_world() -> Vector2i:
	Audio.played.clear()
	_world = PolarWorld.new()
	_world.build_overview = false
	_world.setup_planet(RINGS, 160, 7)
	add_child(_world)
	_world.set_physics_process(false)
	_worm = WORM.instantiate()
	_worm.player = Players.P1
	_worm.model = WormGrowth.new()
	var start := Vector2.from_angle(-PI / 2.0) * 160 * 16.0 * 0.70
	_worm.set_meta("start_pos", start + Vector2(0, 400))
	_worm.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(_worm)
	_worm.set_physics_process(false)
	_worm.set_world(_world)
	_world.track(_worm.head)
	_world.update_chunks(-1)
	return _world.shape.cell_at(start)


func _advance(w: PolarWorld, seconds: float) -> void:
	for i in int(seconds * 2.0):
		w.advance(0.5)
	w.regrow_pass(-1)


func test_every_ring_has_its_regrow_numbers_in_data() -> void:
	for r in RINGS.rings:
		assert_float(r.regrow_time).override_failure_message("%s never regrows" % r.id).is_greater(0.0)
		assert_int(r.castings_size).override_failure_message("%s castings food is not bigger" % r.id).is_greater(1)
	assert_float(RINGS.castings_factor).is_less(1.0)
	assert_float(RINGS.size_growth).is_greater(0.0)
	assert_float(RINGS.scarce_factor).is_less(1.0)
	# the file says it, not a script default
	var text := FileAccess.get_file_as_string("res://data/rings/rings.tres")
	assert_int(text.count("regrow_time = ")).is_equal(RINGS.rings.size())
	assert_int(text.count("castings_size = ")).is_equal(RINGS.rings.size())


func test_castings_regrow_faster_and_bigger() -> void:
	var c := _small_world()
	var plain := c + Vector2i(0, 6)
	assert_bool(_world.eat_tile(c, Players.P1)).is_true()     # a worm ate it: castings
	assert_bool(_world.dig(plain).is_empty()).is_false()                # something else took it: no castings
	assert_bool(_world.has_castings(c)).is_true()
	assert_bool(_world.has_castings(plain)).is_false()
	var fast := _world.regrow_time(c)
	var slow := _world.regrow_time(plain)
	assert_float(fast).is_equal_approx(slow * RINGS.castings_factor, 0.01)
	_worm.head.global_position = _world.to_global(_world.shape.center_of(c)) + Vector2(0, 900)
	_advance(_world, fast + 1.0)
	assert_bool(_world.is_solid(c)).is_true()
	assert_bool(_world.is_solid(plain)).is_false()             # faster
	assert_int(_world.food_size(c)).is_equal(_world.ring_of(c).castings_size)   # bigger
	_advance(_world, slow)
	assert_bool(_world.is_solid(plain)).is_true()
	assert_int(_world.food_size(plain)).is_equal(1)            # plain ground comes back plain
	# a big one is worth more growth, says so with a cue, and is plain again once eaten
	var heard := []
	_world.big_tile_eaten.connect(func(cell: Vector2i, _p: int, size: int) -> void: heard.append([cell, size]))
	var g0 := _worm.model.growth
	_world.eat_tile(plain, Players.P1)
	var plain_gain := _worm.model.growth - g0
	var g1 := _worm.model.growth
	_world.eat_tile(c, Players.P1)
	var big_gain := _worm.model.growth - g1
	assert_float(plain_gain).is_greater(0.0)
	assert_float(big_gain).is_equal_approx(plain_gain * (1.0 + RINGS.size_growth), 0.0001)
	assert_int(heard.size()).is_equal(1)
	assert_bool(Audio.played.has("chomp_bite")).is_true()
	assert_int(_world.food_size(c)).is_equal(1)


func test_green_thumb_castings_are_faster_still_and_just_as_big() -> void:
	var c := _small_world()
	_world.eat_tile(c, Players.P1)
	var normal := _world.regrow_time(c)
	_world.castings_speed = 2.0    # RingsDirector sets this for Green thumb (test_gardens_rules)
	assert_float(_world.regrow_time(c)).is_equal_approx(normal / 2.0, 0.01)
	_worm.head.global_position = _world.to_global(_world.shape.center_of(c)) + Vector2(0, 900)
	_advance(_world, normal / 2.0 + 1.0)
	assert_bool(_world.is_solid(c)).is_true()
	assert_int(_world.food_size(c)).is_equal(_world.ring_of(c).castings_size)


func test_big_food_is_kept_in_the_tin_and_drawn() -> void:
	var c := _small_world()
	_world.eat_tile(c, Players.P1)
	_worm.head.global_position = _world.to_global(_world.shape.center_of(c)) + Vector2(0, 900)
	_advance(_world, _world.regrow_time(c) + 1.0)
	assert_int(_world.food_size(c)).is_equal(2)
	var layers := _world.find_children("Sizes_*", "TileMapLayer", false, false)
	assert_bool(layers.any(func(l: TileMapLayer) -> bool: return l.get_cell_source_id(c) == 0)).is_true()
	var data := JSON.parse_string(JSON.stringify(_world.to_save())) as Dictionary
	var w2 := PolarWorld.new()
	w2.build_overview = false
	w2.setup_planet(RINGS, 160, 7)
	w2.load_save(data)
	assert_int(w2.food_size(c)).is_equal(2)
	assert_int(w2.big_tile_count()).is_equal(_world.big_tile_count())
	assert_int(w2.ring_eaten(_world._gen.ring_index(c))).is_equal(_world.ring_eaten(_world._gen.ring_index(c)))
	w2.free()
	# a tin from before food sizes loads with every tile plain
	data.erase("sizes")
	var w3 := PolarWorld.new()
	w3.build_overview = false
	w3.setup_planet(RINGS, 160, 7)
	w3.load_save(data)
	assert_int(w3.big_tile_count()).is_equal(0)
	w3.free()


## A worm that never leaves its ring, tunnelling all the time (worse than the balance "adult" 60%)
## at its stage's real speed and bite (Worm stats, BITE_RADIUS, DIG_SPEED), wandering the whole
## band in loops so it meets old tunnels and fresh ground. Over 30 planet minutes the ring never
## runs out: tiles are left in the ring and there is always food within reach of the head.
func _resident_run(ring_id: StringName, stage: int) -> Dictionary:
	var w := PolarWorld.new()
	w.build_overview = false
	w.setup_planet(RINGS, PlanetLevel.RADIUS, 77)
	add_child(w)
	w.set_physics_process(false)
	var ri := -1
	for i in RINGS.rings.size():
		if RINGS.rings[i].id == ring_id:
			ri = i
	var inner := (RINGS.rings[ri - 1].outer if ri > 0 else 0.0) * PlanetLevel.RADIUS + RINGS.strangestone_radius + 3.0
	var outer := RINGS.rings[ri].outer * PlanetLevel.RADIUS - 2.0
	var model := WormGrowth.new()
	model.start_at_stage(stage)
	var size: float = model.stage_info().size
	var speed: float = model.stats.value("speed") * Worm.DIG_SPEED
	var bite := Worm.BITE_RADIUS * size
	w.set_stage(Players.P1, stage)
	var head := Node2D.new()
	head.set("radius_px", bite)
	w.add_child(head)
	w.track_eater(head)
	var cs := float(w.shape.cell_size)
	var mid := (inner + outer) * 0.5 * cs
	var amp := maxf(0.0, (outer - inner) * 0.5 * cs - bite)
	var ang := 0.0
	var wob := 0.0
	var min_reach := 1 << 30
	var min_left := 1 << 30
	var max_share := 0.0
	var eaten := 0
	var t := 0.0
	var next_check := 0.0
	while t < SIM_SECONDS:
		# the wobble sweeps the band 3 times a lap; along the path the head moves at `speed`
		var r := mid + amp * sin(wob)
		head.position = Vector2.from_angle(ang) * r
		eaten += w.eat_circle(head.position, bite, Players.P1)
		var step := speed * SIM_DT
		ang += step / maxf(r, 1.0) * 0.8
		wob += step / maxf(r, 1.0) * 3.0 + 0.002
		w.update_chunks(-1)
		w.advance(SIM_DT)
		t += SIM_DT
		if t >= next_check:
			next_check += 10.0
			min_left = mini(min_left, w.food_left(ri))
			max_share = maxf(max_share, w.ring_eaten_share(ri))
			min_reach = mini(min_reach, _food_near(w, head.position, stage, 10))
	head.free()
	remove_child(w)
	w.free()
	print("regrow resident %s s%d: ate %d tiles in %d s, most eaten at once %.0f%%, least left %d, least in reach %d" \
			% [ring_id, stage, eaten, int(SIM_SECONDS), max_share * 100.0, min_left, min_reach])
	return { "eaten": eaten, "left": min_left, "reach": min_reach, "share": max_share }


## Edible tiles within `tiles` of p (px, world local).
func _food_near(w: PolarWorld, p: Vector2, stage: int, tiles: int) -> int:
	var c := w.shape.cell_at(p)
	var n := 0
	for y in range(-tiles, tiles + 1):
		for x in range(-tiles, tiles + 1):
			var cell := c + Vector2i(x, y)
			if x * x + y * y <= tiles * tiles and w.is_edible_by(stage, cell):
				n += 1
	return n


func test_a_ring_never_runs_out_for_a_resident_worm_over_30_minutes() -> void:
	# each tile ring with the stage that lives in it (the surface is food from 4 until the crust)
	for run in [[&"dirt", 1], [&"topsoil", 2], [&"deep_rock", 4], [&"surface", 4], [&"core", 5]]:
		var res := _resident_run(run[0], run[1])
		assert_int(int(res.eaten)).override_failure_message("%s: the worm ate nothing" % run[0]).is_greater(500)
		assert_int(int(res.left)).override_failure_message("%s ran out" % run[0]).is_greater(0)
		assert_int(int(res.reach)).override_failure_message("%s: no food in reach" % run[0]).is_greater(0)


## A ring dug almost bare (by anything) comes back long before its plain regrow time; the same
## ring with the floor turned off (scarce_factor 1) has nothing back yet. The floor eases off as
## the ring fills, so it refills fastest when it is emptiest.
func _bare_core_refill(set: RingSet, seconds: float) -> Dictionary:
	var w := PolarWorld.new()
	w.build_overview = false
	w.setup_planet(set, 160, 7)
	add_child(w)
	w.set_physics_process(false)
	var cells: Array[Vector2i] = []
	var r := int(set.rings[0].outer * 160)
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var cell := Vector2i(x, y)
			if w.shape.contains(cell) and w._gen.ring_index(cell) == 0 and w.base_tile_of(cell) != 1:
				cells.append(cell)
	var out := { "plain": w.regrow_time(cells[0]), "factor_full": w.scarcity_factor(0) }
	for cell in cells:
		w.dig(cell)
	out.share_bare = w.ring_eaten_share(0)
	out.factor_bare = w.scarcity_factor(0)
	out.time_bare = w.regrow_time(cells[0])
	var eye := Node2D.new()   # chunks load round a watcher (regrowth runs where the planet is played)
	w.add_child(eye)
	w.track(eye)
	w.update_chunks(-1)
	var left0 := w.food_left(0)
	_advance(w, seconds)
	out.back = w.food_left(0) - left0
	out.cells = cells.size()
	remove_child(w)
	w.free()
	return out


func test_a_nearly_eaten_ring_fills_faster() -> void:
	var wait := 900.0 * RINGS.scarce_factor * 1.2   # a fifth of the core's plain regrow time, and a bit
	var res := _bare_core_refill(RINGS, wait)
	assert_float(res.factor_full).is_equal(1.0)
	assert_float(res.share_bare).is_greater(0.9)
	assert_float(res.factor_bare).is_less(0.5)
	assert_float(res.time_bare).is_less(res.plain * 0.5)
	assert_int(int(res.back)).override_failure_message("bare core: %s" % res).is_greater(int(res.cells * 0.04))
	var off: RingSet = RINGS.duplicate()
	off.scarce_factor = 1.0
	var res_off := _bare_core_refill(off, wait)
	assert_int(int(res_off.back)).is_equal(0)


func test_regrowth_stops_while_frozen() -> void:
	var c := _small_world()
	_world.eat_tile(c, Players.P1)
	_worm.head.global_position = _world.to_global(_world.shape.center_of(c)) + Vector2(0, 900)
	_world.frozen = true
	var clock := _world.clock
	_advance(_world, _world.regrow_time(c) * 3.0)
	assert_float(_world.clock).is_equal(clock)
	assert_bool(_world.is_solid(c)).is_false()
	_world.frozen = false
	_advance(_world, _world.regrow_time(c) + 1.0)
	assert_bool(_world.is_solid(c)).is_true()


func test_regrowth_stops_in_the_jar_view() -> void:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	BaitTins.open(0)
	Save.wipe()
	Save.set_value("seed", 77)
	_level = PLANET.instantiate()
	_level.autosave_every = 9999.0
	add_child(_level)
	_level.stage_beat.make_story = false
	_level.chomp.jar_dir = JAR_DIR
	_level.chomp.set_physics_process(false)
	var w := _level.spawn_worm(Players.P1)
	while w.model.stage < 6:
		if w.model.size_stage() > w.model.stage:
			w.model.eat_apex(w.model.stage)
		else:
			w.model.add_segment(&"")
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	w.head.global_position = _level.world.to_global(Vector2.UP * (_level.chomp.surface_px() + 60.0))
	await get_tree().physics_frame
	var world := _level.world
	var c := world.shape.cell_at(world.to_local(w.head_position())) + Vector2i(0, 40)
	world.dig(c)
	assert_bool(_level.chomp.open_shot(w)).is_true()            # the planet shot: Old Reel's jar
	world.time_scale = world.regrow_time(c) * 60.0                  # one frame would be plenty
	var clock := world.clock
	for i in 5:
		await get_tree().physics_frame
	assert_float(world.clock).is_equal(clock)
	assert_bool(world.is_solid(c)).is_false()
	_level.chomp.close_shot()                                       # "not yet": back to the planet
	for i in 5:
		await get_tree().physics_frame
	assert_float(world.clock).is_greater(clock)
	world.time_scale = 1.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(JAR_DIR))
