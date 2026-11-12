## Stage 6 in the real planet (S-09, S-10, S-16, C-04, S-17 prototype): the picture only opens for a
## stage-6 worm out past the surface, a tap never chomps and a full hold does, B is "not yet", the
## jar is the real tin and plays again with stage 6 off, and the space stage has no gravity, a camera
## that never rotates and nothing that steers the worm. Own profile, tins and jar shelf.
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")
const SPACE := preload("res://scenes/levels/space_stage.tscn")
const JAR_DIR := "user://test_chomp_planet_jars"
const DT := 1.0 / 60.0

var _level: PlanetLevel
var _jars: JarStore


func before() -> void:
	SuiteSandbox.enter("chomp_planet")


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
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _open(fresh: bool) -> PlanetLevel:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	if fresh:
		BaitTins.open(0)
		Save.wipe()
		Save.set_value("seed", 77)   # a pinned planet, never randi()
	_level = PLANET.instantiate()
	_level.autosave_every = 9999.0
	add_child(_level)
	_level.stage_beat.make_story = false
	_level.chomp.jar_dir = JAR_DIR
	_level.chomp.set_physics_process(false)   # the tests step the director by hand
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


## Put the worm's head this many px from the planet's centre, straight up.
func _head_at(w: Worm, r: float) -> void:
	w.head.global_position = _level.world.to_global(Vector2.UP * r)


func _watch(seconds: float) -> void:
	for i in int(seconds / DT):
		_level.chomp._watch(DT)


func _hold(seconds: float, held: bool) -> void:
	var c := _level.chomp.chomp
	for i in int(seconds / DT):
		c.advance(DT, held)


func _stage6_outside() -> Worm:
	var w := _level.spawn_worm(Players.P1)
	_grow_to(w, 6)
	_head_at(w, _level.chomp.surface_px() + 60.0)
	return w


func test_picture_opens_only_for_a_stage6_worm_past_the_surface() -> void:
	_open(true)
	var w := _level.spawn_worm(Players.P1)
	_grow_to(w, 5)
	_head_at(w, _level.chomp.surface_px() + 60.0)
	_watch(2.0)
	assert_int(_level.chomp.state).is_equal(ChompDirector.State.WATCH)   # stage 5: not yet a planet-eater
	_grow_to(w, 6)
	_head_at(w, _level.chomp.surface_px() - 200.0)
	_watch(2.0)
	assert_int(_level.chomp.state).is_equal(ChompDirector.State.WATCH)   # still inside the planet
	_head_at(w, _level.chomp.surface_px() + 60.0)
	_watch(0.3)
	assert_int(_level.chomp.state).is_equal(ChompDirector.State.WATCH)   # a moment, not yet OUT_TIME
	_watch(0.5)
	assert_int(_level.chomp.state).is_equal(ChompDirector.State.SHOT)
	var c := _level.chomp.chomp
	assert_object(c).is_not_null()
	c.set_process(false)
	# the fixed planet shot: its camera, not the rotating one; the disk is hidden, the worms wait
	assert_bool((c.get_node("Camera") as Camera2D).is_current()).is_true()
	assert_float((c.get_node("Camera") as Camera2D).global_rotation).is_equal(0.0)
	assert_bool(_level.world.visible).is_false()
	assert_int(_level.actors.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
	assert_int(c.phase).is_equal(PlanetChomp.Phase.CONFIRM)
	assert_bool(c.get_node("Picture").visible).is_true()
	# the chomp eats the real disk's picture (rendered to a texture), not the stand-in
	assert_int(c.planet_texture.get_width()).is_equal(_level.world.planet_texture().get_width())
	assert_float(c.worm_color.g).is_greater(c.worm_color.r)   # P1: green


func test_a_tap_does_not_chomp_and_a_full_hold_does() -> void:
	_open(true)
	_stage6_outside()
	_watch(1.0)
	var c := _level.chomp.chomp
	c.set_process(false)
	var id := StringName(_level.chomp.planet_id())
	for i in 3:                       # three taps (a quarter second each)
		_hold(0.25, true)
		_hold(0.5, false)
	assert_int(c.phase).is_equal(PlanetChomp.Phase.CONFIRM)
	assert_float(c.confirm.progress).is_equal(0.0)
	assert_bool(_jars.has_jar(id)).is_false()
	assert_bool(ChompDirector.eaten()).is_false()
	_hold(1.9, true)                  # nearly full, then let go: still nothing
	_hold(1.0, false)
	assert_int(c.phase).is_equal(PlanetChomp.Phase.CONFIRM)
	assert_bool(_jars.has_jar(id)).is_false()
	var eaten := [0]
	c.planet_eaten.connect(func(): eaten[0] += 1)
	_hold(2.05, true)                 # one full hold
	assert_int(c.phase).is_equal(PlanetChomp.Phase.JARRING)
	assert_bool(_jars.has_jar(id)).is_true()       # the jar is written before a single bite
	assert_int(eaten[0]).is_equal(0)
	_hold(20.0, false)
	assert_int(eaten[0]).is_equal(1)
	assert_int(c.phase).is_equal(PlanetChomp.Phase.DONE)
	_level.chomp._physics_process(DT)
	assert_int(_level.chomp.state).is_equal(ChompDirector.State.SPACE)
	assert_bool(ChompDirector.eaten()).is_true()
	assert_int(int(Save.get_value("stage"))).is_equal(7)
	_level.save_now()                 # the level's own save keeps stage 7, never back to 6
	assert_int(int(Save.get_value("stage"))).is_equal(7)
	assert_object(_level.chomp.space).is_not_null()
	assert_bool(is_instance_valid(c)).is_true()     # queued, freed next frame
	assert_object(_level.chomp.chomp).is_null()


func test_b_is_not_yet_and_the_picture_waits_for_the_next_visit() -> void:
	_open(true)
	var w := _stage6_outside()
	_watch(1.0)
	var c := _level.chomp.chomp
	c.set_process(false)
	var closed := [0]
	_level.chomp.shot_closed.connect(func(): closed[0] += 1)
	_hold(1.0, true)
	assert_bool(c.decline()).is_true()
	assert_int(closed[0]).is_equal(1)
	assert_int(_level.chomp.state).is_equal(ChompDirector.State.WATCH)
	assert_bool(_level.world.visible).is_true()
	assert_bool(_level.camera.is_current()).is_true()
	assert_int(_level.actors.process_mode).is_equal(Node.PROCESS_MODE_INHERIT)
	assert_bool(_jars.has_jar(StringName(_level.chomp.planet_id()))).is_false()
	assert_int(int(Save.get_value("stage"))).is_equal(6)
	_watch(3.0)                        # still outside: no nagging
	assert_int(_level.chomp.state).is_equal(ChompDirector.State.WATCH)
	_head_at(w, _level.chomp.surface_px() - 100.0)
	_watch(0.2)
	_head_at(w, _level.chomp.surface_px() + 60.0)
	_watch(1.0)
	assert_int(_level.chomp.state).is_equal(ChompDirector.State.SHOT)


func test_the_jar_is_the_real_tin_and_plays_again_with_stage6_off() -> void:
	_open(true)
	_stage6_outside()
	_watch(1.0)
	var c := _level.chomp.chomp
	c.set_process(false)
	var id := StringName(_level.chomp.planet_id())
	var tin_slot := Save.slot
	var planet_before: Dictionary = _level.world.to_save()
	_hold(2.1, true)
	_hold(20.0, false)
	_level.chomp._physics_process(DT)
	_close()
	# the jar file is the tin as it was at the chomp: same seed, same planet, the stage-6 worm
	assert_str(String(id)).contains(tin_slot)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(JAR_DIR + "/" + String(id) + ".json"))
	assert_int(int(data.seed)).is_equal(77)
	assert_int(int(data.stage)).is_equal(6)
	assert_bool(data.has("planet_eaten")).is_false()
	assert_bool(JSON.stringify(data.planet) == JSON.stringify(JSON.parse_string(JSON.stringify(planet_before)))).is_true()
	assert_int(int(data.worms["0"].stage)).is_equal(6)
	# revisit: open the jar, the planet loads with its worm at stage 6, and stage 6 never offers
	assert_bool(_jars.open(id)).is_true()
	assert_bool(JarStore.stage6_allowed()).is_false()
	_open(false)
	assert_int(_level.planet_seed).is_equal(77)
	var w := _level.spawn_worm(Players.P1)
	assert_int(w.model.stage).is_equal(6)
	_head_at(w, _level.chomp.surface_px() + 60.0)
	_watch(3.0)
	assert_int(_level.chomp.state).is_equal(ChompDirector.State.WATCH)
	assert_bool(_level.chomp.open_shot(w)).is_false()
	_level.save_now()
	_close()
	# leaving the jar returns to the tin, which is in space
	_jars.close()
	assert_str(Save.slot).is_equal(tin_slot)
	assert_bool(ChompDirector.eaten()).is_true()
	assert_int(int(Save.get_value("stage"))).is_equal(7)
	_open(false)
	await get_tree().process_frame
	assert_int(_level.chomp.state).is_equal(ChompDirector.State.SPACE)


func test_space_stage_has_no_gravity_no_rotation_and_no_auto_steer() -> void:
	var s: SpaceStage = SPACE.instantiate()
	s.players.append(Players.P1)
	add_child(s)
	auto_free(s)
	s.set_process(false)
	assert_bool(s.gravity_on()).is_false()
	assert_bool(s.planet is RigidBody2D).is_true()
	assert_float(s.planet.gravity_scale).is_equal(0.0)
	assert_bool(s.why.is_showing()).is_true()       # the cause, shown on arrival
	assert_int(s.worms.size()).is_equal(1)
	var worm := s.worms[0]
	worm.position = Vector2(600, 300)
	# C-04: opens on the fixed planet shot, holds, then eases out; never rotates
	s.step_camera(DT)
	assert_vector(s.camera.position).is_equal(Vector2.ZERO)
	assert_float(s.camera.zoom.x).is_equal(1.0)
	var start := s.planet.position
	for i in 30:
		await get_tree().physics_frame
	assert_vector(worm.position).is_equal_approx(Vector2(600, 300), Vector2(0.5, 0.5))   # no stick, no move
	assert_float(s.planet.position.distance_to(start)).is_greater(5.0)               # it drifts
	for i in int((SpaceStage.HOLD + SpaceStage.EASE + 0.2) / DT):
		s._t += DT
		s.step_camera(DT)
		assert_float(s.camera.rotation).is_equal(0.0)
	assert_vector(s.camera.position).is_equal_approx(worm.position, Vector2(1, 1))
	assert_float(s.camera.zoom.x).is_equal_approx(SpaceStage.SPACE_ZOOM, 0.001)
