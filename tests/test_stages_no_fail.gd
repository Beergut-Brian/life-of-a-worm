## No fail state (S-13), for everything the stages add, on dev's stage table: a stage is never lost
## (getting eaten, losing every segment, a save and reload, a lower drop-in start, the crust burst),
## earned traits and slots stay, and no row of data/stages.tres takes size, reach or slots away as a
## stage rises.
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")

var _level: PlanetLevel


func before() -> void:
	SuiteSandbox.enter("stages_nofail")


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	_hush()
	SuiteSandbox.leave()


func after_test() -> void:
	_close()
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _open(fresh: bool) -> PlanetLevel:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	Audio.played.clear()
	BaitTins.open(0)
	if fresh:
		Save.wipe()
		Save.set_value("seed", 77)   # a pinned planet, never randi()
	_level = PLANET.instantiate()
	_level.autosave_every = 9999.0
	add_child(_level)
	_level.stage_beat.make_story = false
	return _level


func _hush() -> void:
	for p in Audio._pool:
		p.stop()
		p.stream = null


func _close() -> void:
	_hush()
	if is_instance_valid(_level):
		for p in _level.find_children("*", "AudioStreamPlayer", true, false):
			(p as AudioStreamPlayer).stop()
		remove_child(_level)
		_level.free()
	_level = null


func _grow_to(w: Worm, stage: int) -> void:
	while w.model.stage < stage:
		if w.model.size_stage() > w.model.stage:
			w.model.eat_apex(w.model.stage)
		else:
			w.model.add_segment(&"")


func _crust_cell() -> Vector2i:
	var world := _level.world
	var up := _level.spawn_point.normalized()
	var r := float(world.shape.radius) * float(world.shape.cell_size)
	for i in range(0, 400):
		var c: Vector2i = world.shape.cell_at(up * (r - float(i)))
		if world.shape.contains(c) and world.is_solid(c) and world.ring_of(c).id == StageTable.default_table().crust_ring():
			return c
	return Vector2i.ZERO


func test_growth_is_never_lost_in_the_body_model() -> void:
	for s in range(2, 7):
		var m := WormGrowth.new()
		m.start_at_stage(s)
		for f in [&"bug", &"root", &"stone"]:
			for i in 6:
				m.add_segment(f)
		var stage := m.stage
		var earned := m.earned.duplicate()
		var slots := m.slots()
		for i in m.segments.size() + 10:
			m.lose_segment()
		assert_int(m.stage).is_equal(stage)
		assert_int(m.slots()).is_equal(slots)
		assert_array(m.earned).is_equal(earned)
		assert_int(m.segments.size()).is_equal(1)   # never below one segment
		m.start_at_stage(1)                        # a lower start never lowers the stage
		assert_int(m.stage).is_equal(stage)
		var back := WormGrowth.new()
		back.from_dict(m.to_dict())                # a save below the threshold keeps the stage
		assert_int(back.stage).is_equal(stage)
		assert_array(back.earned).is_equal(earned)


func test_no_stage_takes_size_or_reach_away() -> void:
	var table := StageTable.default_table()
	for n in range(2, table.max_stage() + 1):
		var a := table.at(n - 1)
		var b := table.at(n)
		assert_int(b.segments).is_greater_equal(a.segments)
		assert_float(b.size).is_greater_equal(a.size)
		assert_float(b.collision_radius).is_greater_equal(a.collision_radius)
		assert_int(b.slots).is_greater_equal(a.slots)
		assert_int(b.edible_size).is_greater_equal(a.edible_size)
		assert_int(b.zoom_index).is_less_equal(a.zoom_index)   # the camera only ever pulls back


func test_eaten_burst_and_reloaded_the_planet_worm_keeps_its_stage() -> void:
	var crust_stage := StageTable.default_table().crust_stage()
	_open(true)
	var w := _level.spawn_worm(Players.P1)
	await get_tree().physics_frame
	_grow_to(w, crust_stage)
	var segs := w.model.segments.size()
	w.get_eaten(&"fake_big_bug")
	assert_int(w.model.stage).is_equal(crust_stage)
	assert_int(w.model.segments.size()).is_equal(segs - 1)
	var g := w.model.growth
	var n := w.model.segments.size()
	assert_bool(_level.world.eat_tile(_crust_cell(), Players.P1)).is_true()   # the breakthrough
	assert_array(_level.crust.broken).contains([Players.P1])
	assert_int(w.model.stage).is_equal(crust_stage)
	# a bite of crust only ever adds
	assert_bool(w.model.segments.size() > n or w.model.growth >= g).is_true()
	assert_int(w.model.segments.size()).is_greater_equal(n)
	segs = w.model.segments.size()
	_level.save_now()
	_close()
	_open(false)
	var back := _level.spawn_worm(Players.P1)
	assert_int(back.model.stage).is_equal(crust_stage)
	assert_int(back.model.segments.size()).is_equal(segs)
	assert_array(_level.crust.broken).contains([Players.P1])
