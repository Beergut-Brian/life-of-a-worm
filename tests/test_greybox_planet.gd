## The grey-box planet (PlanetLevel) with the real world and worm: tunnelling eats tiles and grows
## segments, sleeping in a hollow sets home, carried things become trophies, hold-B warps home, the
## apex bite stages up and pulls the camera back, drop-in hatches at the partner's stage minus one,
## every bait tin round-trips through save/load on its own, quitting at any moment loses nothing,
## and solo is never restored from a saved true. Runs in its own Save profile (SuiteSandbox).
class_name TestGreyboxPlanet
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")

var _level: PlanetLevel
var _move := Vector2.ZERO
var _carry := false


func before() -> void:
	SuiteSandbox.enter("greybox")


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	SuiteSandbox.leave()


func before_test() -> void:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	_move = Vector2.ZERO
	_carry = false
	Audio.played.clear()


func after_test() -> void:
	_free_level()
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _open(tin: int, fresh := true) -> PlanetLevel:
	BaitTins.open(tin)
	if fresh:
		Save.wipe()
	_level = PLANET.instantiate()
	add_child(_level)
	return _level


func _free_level() -> void:
	if is_instance_valid(_level):
		remove_child(_level)
		_level.free()
	_level = null


func _p1() -> Worm:
	var w := _level.spawn_worm(Players.P1)
	w.autopilot = func(_w: Worm) -> Dictionary: return { "move": _move, "carry": _carry }
	return w


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _hollow(at: Vector2, r := 40.0) -> void:
	var c := _level.world.shape.cell_at(at)
	for y in range(-4, 5):
		for x in range(-4, 5):
			var cell := c + Vector2i(x, y)
			if _level.world.shape.center_of(cell).distance_to(at) <= r:
				_level.world.dig(cell)


func test_tunnelling_eats_tiles_and_grows() -> void:
	_open(0)
	var w := _p1()
	var growth_before := w.model.growth + w.model.segments.size() * w.rules.growth_per_segment
	_move = Vector2.RIGHT
	await _frames(90)
	assert_int(w.tiles_total).is_greater(5)
	var growth_after := w.model.growth + w.model.segments.size() * w.rules.growth_per_segment
	assert_float(growth_after).is_greater(growth_before)
	assert_float(w.cam_position().x).is_greater(_level.spawn_point.x + 40.0)
	assert_int(Audio.played.get("chomp_1", 0)).is_greater(0)


func test_sleeping_in_a_hollow_sets_home_and_saves() -> void:
	_open(0)
	var w := _p1()
	_hollow(w.cam_position())
	var saves := _level.saves
	w.still_time = Burrow.SLEEP_STILL + 0.1
	await _frames(2)
	assert_bool(_level.burrow.has_home).is_true()
	assert_float(_level.burrow.home.distance_to(w.cam_position())).is_less(4.0)
	assert_bool(w.asleep).is_true()
	assert_int(_level.saves).is_greater(saves)
	assert_bool(Save.get_value("burrow", {}).get("has_home", false)).is_true()
	assert_int(Audio.played.get("sleep", 0)).is_equal(1)


func test_standing_still_in_a_tunnel_is_not_a_burrow() -> void:
	_open(0)
	var w := _p1()
	_level.world.dig(_level.world.shape.cell_at(w.cam_position()))   # spawn pocket only
	w.warp_to(_level.local_point(40, 0))   # solid dirt round it, one cell
	_level.world.dig(_level.world.shape.cell_at(w.cam_position()))
	w.still_time = Burrow.SLEEP_STILL + 0.1
	await _frames(2)
	assert_bool(_level.burrow.has_home).is_false()


func test_hold_b_warps_home() -> void:
	_open(0)
	var w := _p1()
	_level.burrow.set_home(_level.spawn_point)
	w.warp_to(_level.local_point(30, 0))
	Audio.played.clear()
	w.autopilot = func(_w: Worm) -> Dictionary: return { "hold_b": true }
	# Wait for the warp to land (bounded), not for a fixed frame count: a slower CI runner
	# needs more physics frames for the same hold.
	var waited := 0
	while w.cam_position().distance_to(_level.spawn_point) >= 4.0 and waited < 900:
		await get_tree().physics_frame
		waited += 1
	assert_float(w.cam_position().distance_to(_level.spawn_point)).is_less(4.0)
	assert_int(Audio.played.get("warp", 0)).is_equal(1)


func test_carried_home_becomes_a_trophy() -> void:
	_open(0)
	var w := _p1()
	_level.burrow.set_home(_level.local_point(30, 0))
	var pebble := _level._add_food(&"pebble", w.mouth_position() + Vector2(2, 0))
	_carry = true
	await _frames(3)
	assert_object(w.carrying).is_same(pebble)
	assert_int(Audio.played.get("carry", 0)).is_equal(1)
	_level.burrow.set_home(_level.spawn_point)   # home is right here now
	await _frames(3)
	assert_array(_level.burrow.trophies).contains([&"pebble"])
	assert_bool(pebble.visible).is_false()


func test_apex_bite_stages_up_and_pulls_the_camera_back() -> void:
	_open(0)
	var w := _p1()
	while w.model.segments.size() < w.rules.stage_segments[2]:
		w.model.add_segment(&"")
	assert_int(w.model.stage).is_equal(1)
	var zoom_cap := _level.camera.max_fit_index
	_level.beetle.bitten_by(w)
	assert_int(w.model.stage).is_equal(2)
	assert_int(_level.camera.max_fit_index).is_less(zoom_cap)
	assert_int(Audio.played.get("now_i_eat_you", 0)).is_equal(1)
	assert_int(Audio.played.get("stage_up", 0)).is_equal(1)
	assert_bool(Save.get_value("apex", {}).get("gone", false)).is_true()


func test_drop_in_hatches_next_to_the_first_at_its_stage_minus_one() -> void:
	_open(0)
	var w := _p1()
	w.model.start_at_stage(3)
	var egg := _level.drop_in(Players.P2)
	assert_object(egg).is_not_null()
	assert_float(egg.position.distance_to(w.cam_position())).is_less(30.0)
	egg.hatched.emit()
	var p2 := Worm.of(Players.P2)
	assert_object(p2).is_not_null()
	assert_int(p2.model.stage).is_equal(2)
	assert_float(p2.cam_position().distance_to(w.cam_position())).is_less(30.0)


func test_drop_in_of_a_stage_one_worm_hatches_at_stage_one() -> void:
	_open(0)
	_p1()
	var egg := _level.drop_in(Players.P2)
	egg.hatched.emit()
	assert_int(Worm.of(Players.P2).model.stage).is_equal(1)


func test_each_tin_round_trips_on_its_own() -> void:
	var want := {}
	for tin in BaitTins.COUNT:
		_open(tin)
		var w := _p1()
		for k in tin + 2:
			w.model.add_segment(&"bug")
		w.warp_to(_level.local_point(5 + tin * 3, 0))
		_level.world.eat_circle(_level.local_point(5 + tin * 3, 0), 30.0, Players.P1)
		_level.burrow.set_home(_level.local_point(tin, 0))
		_level.save_now()
		want[tin] = { "segs": w.model.segments.duplicate(), "edits": _level.world.to_save().edits.size(),
			"home": _level.burrow.home, "seed": _level.planet_seed }
		_free_level()
		Save.use_slot("")
	for tin in BaitTins.COUNT:
		assert_dict(BaitTins.summary(tin)).is_not_empty()
		_open(tin, false)
		var w := _p1()
		assert_array(w.model.segments).is_equal(want[tin].segs)
		assert_int(_level.planet_seed).is_equal(want[tin].seed)
		assert_int(_level.world.to_save().edits.size()).is_equal(want[tin].edits)
		assert_vector(_level.burrow.home).is_equal_approx(want[tin].home, Vector2.ONE * 0.01)
		_free_level()
		Save.use_slot("")


func test_quitting_at_any_moment_loses_nothing() -> void:
	_open(1)
	var w := _p1()
	_level.save_now()
	# Things happen after the last autosave...
	w.model.add_segment(&"stone")
	_level.world.eat_circle(_level.local_point(12, 0), 24.0, Players.P1)
	_level.burrow.set_home(_level.local_point(2, 0))
	var segs := w.model.segments.duplicate()
	var edits: int = _level.world.to_save().edits.size()
	Game.quit()   # quit_exits is off: everything but the exit
	_free_level()
	Save.use_slot("")
	var path := ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(1)))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_array(data.worms["0"].segments).is_equal(segs.map(func(f): return String(f)))
	assert_int((data.planet.edits as Array).size()).is_equal(edits)
	assert_bool(data.burrow.has_home).is_true()


func test_pause_saves_the_tin() -> void:
	_open(2)
	var w := _p1()
	w.model.add_segment(&"root")
	var saves := _level.saves
	Game._set_state(Game.State.PLAYING)
	Game.pause()
	Game.resume()
	assert_int(_level.saves).is_greater(saves)
	Game._set_state(Game.State.LOBBY)


func test_solo_is_never_restored_from_a_saved_true() -> void:
	Save.set_setting(SettingsPanel.SOLO, true)
	_open(0)
	Save.set_value("solo", true)
	_level.save_now()
	_free_level()
	Save.use_slot("")
	_open(0, false)
	_p1()
	assert_bool(Players.solo).is_false()
	assert_bool(Players.solo_from_args(PackedStringArray([]))).is_false()
	Save.set_setting(SettingsPanel.SOLO, false)
