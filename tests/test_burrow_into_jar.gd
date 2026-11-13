## B-07 (feature/worm-gap-close-10): the burrow rides along into the jar at the planet chomp, end
## to end in the real planet: a home with a trophy, a pet and a pantry seed, then the stage-6 chomp
## (the real hold) writes the jar; the jar file carries the burrow and the home slice's shop but not
## Old Reel's tackle box (the found-set stays with the tin); opening the jar brings the same home
## back, and the tackle box is lent in. Own sandbox profile, tins and jar shelf (scratch dir).
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")
const JAR_DIR := "user://test_burrow_into_jar_jars"
const DT := 1.0 / 60.0

var _level: PlanetLevel
var _jars: JarStore


func before() -> void:
	SuiteSandbox.enter("burrow_into_jar")


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	_hush()
	SuiteSandbox.leave()


func before_test() -> void:
	_jars = auto_free(JarStore.new())
	_jars.dir = JAR_DIR
	add_child(_jars)
	_jars.clear()


func after_test() -> void:
	_close()
	if _jars.is_in_jar():
		_jars.close()
	_jars.clear()
	get_tree().paused = false
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _hush() -> void:
	for p in Audio._pool:
		p.stop()
		p.stream = null


func _open(fresh: bool) -> PlanetLevel:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	if fresh:
		BaitTins.open(1)
		Save.wipe()
		Save.set_value("seed", 91)   # a pinned planet, never randi()
	_level = PLANET.instantiate()
	_level.autosave_every = 9999.0
	add_child(_level)
	_level.stage_beat.make_story = false
	_level.home_slice.box.pause_tree = false
	_level.chomp.jar_dir = JAR_DIR
	_level.chomp.set_physics_process(false)   # the test steps the director by hand
	return _level


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


func _hollow(at: Vector2, r := 40.0) -> void:
	var c := _level.world.shape.cell_at(at)
	var n := ceili(r / 16.0) + 1
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			var cell := c + Vector2i(x, y)
			if _level.world.shape.center_of(cell).distance_to(at) <= r:
				_level.world.dig(cell)


func _watch(seconds: float) -> void:
	for i in int(seconds / DT):
		_level.chomp._watch(DT)


func _hold(seconds: float, held: bool) -> void:
	var c := _level.chomp.chomp
	for i in int(seconds / DT):
		c.advance(DT, held)


func test_the_burrow_rides_into_the_jar_and_comes_back_out() -> void:
	_open(true)
	var w := _level.spawn_worm(Players.P1)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	# a home: a dug room, a trophy on its ledge, a pet, a pantry seed, a swap on the Mole's shelf
	_hollow(w.cam_position(), 40.0)
	_level.burrow.set_home(w.cam_position())
	var home := _level.burrow.home
	var f := _level._add_food(&"crystal", w.mouth_position() + Vector2(2, 0))
	w.carrying = f
	f.set_carried(true)
	_level.burrow.note_pickup(w, false)
	_level.burrow.bring(w, f)
	_level.burrow.add_pet(&"ladybird")
	_level.burrow.add_pantry()
	_level.home_slice.shop.kept.append(&"bottle_cap")
	_level.home_slice.tlog.found[&"foods"].append(&"grub")   # Old Reel's tackle box has a find
	assert_array(_level.burrow.trophies).contains_exactly([&"crystal"])
	# the chomp: a stage-6 worm out past the surface, the real hold
	_grow_to(w, 6)
	w.head.global_position = _level.world.to_global(Vector2.UP * (_level.chomp.surface_px() + 60.0))
	_watch(1.0)
	assert_int(_level.chomp.state).is_equal(ChompDirector.State.SHOT)
	var c := _level.chomp.chomp
	c.set_process(false)
	var id := StringName(_level.chomp.planet_id())
	var tin_slot := Save.slot
	_hold(2.1, true)
	_hold(20.0, false)
	_level.chomp._physics_process(DT)
	_close()
	# the jar file holds the home, and not the tin's tackle box
	var path := JAR_DIR + "/" + String(id) + ".json"
	assert_bool(FileAccess.file_exists(path)).is_true()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_bool(bool(data.burrow.has_home)).is_true()
	assert_array(data.burrow.trophies).contains_exactly(["crystal"])
	assert_int((data.burrow.pets as Array).size()).is_equal(1)
	assert_int(int(data.burrow.pantry)).is_equal(1)
	assert_array(data[HomeSlice.SAVE_KEY].shop.kept).contains_exactly(["bottle_cap"])
	assert_bool((data[HomeSlice.SAVE_KEY] as Dictionary).has("tackle")).is_false()
	# the tin still has its tackle box
	assert_str(Save.slot).is_equal(tin_slot)
	assert_array(Save.get_value(HomeSlice.SAVE_KEY).tackle.found.foods).contains([&"grub"])
	# open the jar: the same home is back, and the tackle box is lent in
	assert_bool(_jars.open(id)).is_true()
	_open(false)
	await get_tree().process_frame
	var b := _level.burrow
	assert_bool(b.has_home).is_true()
	assert_float(b.home.distance_to(home)).is_less(1.0)
	assert_array(b.trophies).contains_exactly([&"crystal"])
	assert_array(b.pet_ids()).contains_exactly([&"ladybird"])
	assert_int(b.pantry.size()).is_equal(1)
	assert_array(_level.home_slice.shop.kept).contains_exactly([&"bottle_cap"])
	assert_array(_level.home_slice.tlog.found[&"foods"]).contains([&"grub"])
	_close()
	_jars.close()
	assert_str(Save.slot).is_equal(tin_slot)
