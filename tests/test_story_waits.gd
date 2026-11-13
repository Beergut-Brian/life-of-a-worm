## Y-11: the world under a dock scene waits. While a stage scene plays over the planet, the level stops
## processing (no worm steers or bursts on the skip press, nothing hunts behind the picture) and it
## picks up where it was when the last queued scene ends; a scene played anywhere else holds nothing.
## Y-08: a tin opened again replays the newest planet stage scene it reached but never finished.
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")

var _level: PlanetLevel


func before() -> void:
	SuiteSandbox.enter("story_waits")


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	for p in Audio._pool:
		p.stop()
	SuiteSandbox.leave()


func before_test() -> void:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	BaitTins.open(0)
	Save.wipe()
	_level = PLANET.instantiate()
	add_child(_level)
	_level.stage_beat.make_story = false


func after_test() -> void:
	if is_instance_valid(_level):
		remove_child(_level)
		_level.free()
	_level = null
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _story(speed := 25.0) -> Story:
	var s := Story.new()
	s.persist = false
	s.speed = speed
	_level.add_child(s)
	return s


func _until(cond: Callable, secs := 20.0) -> bool:
	var end := Time.get_ticks_msec() + int(secs * 1000)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _grow(w: Worm, stage: int) -> void:
	w.model.apex_gate = false
	while w.model.stage < stage:
		w.model.add_segment(&"")


func test_the_planet_waits_while_a_stage_scene_plays_and_wakes_after() -> void:
	var w := _level.spawn_worm(Players.P1)
	var story := _story()
	var mode := _level.process_mode
	assert_bool(story.play(&"stage_3")).is_true()
	assert_object(story.held()).is_same(_level)
	assert_bool(_level.can_process()).override_failure_message("the planet ran behind the scene").is_false()
	assert_bool(w.can_process()).is_false()
	assert_bool(story.can_process()).override_failure_message("the scene itself must still run").is_true()
	# The worm cannot steer: its physics does not run, so a pushed stick moves nothing.
	var at := w.head_position()
	w.autopilot = func(_w) -> Dictionary: return {"move": Vector2.RIGHT, "burst": true}
	for i in 10:
		await get_tree().physics_frame
	assert_vector(w.head_position()).is_equal(at)
	story.skip()
	assert_bool(await _until(func(): return not story.is_playing(), 5.0)).is_true()
	assert_object(story.held()).is_null()
	assert_int(_level.process_mode).is_equal(mode)
	assert_bool(_level.can_process()).is_true()
	for i in 10:
		await get_tree().physics_frame
	assert_bool(w.head_position().distance_to(at) > 0.5).override_failure_message("the worm never woke up").is_true()
	w.autopilot = Callable()


func test_queued_scenes_keep_the_planet_waiting_until_the_last_one_ends() -> void:
	_level.spawn_worm(Players.P1)
	var story := _story()
	var woke: Array = []
	story.finished.connect(func(id, _s): woke.append([id, _level.can_process()]))
	story.play(&"stage_2")
	story.play(&"stage_3")
	story.skip()
	assert_bool(await _until(func(): return story.current() == &"stage_3", 5.0)).is_true()
	assert_bool(_level.can_process()).override_failure_message("woke between two queued scenes").is_false()
	story.skip()
	assert_bool(await _until(func(): return woke.size() == 2, 5.0)).is_true()
	assert_array(woke).is_equal([[&"stage_2", false], [&"stage_3", true]])


func test_a_scene_outside_a_level_holds_nothing() -> void:
	var s := Story.new()
	s.persist = false
	s.speed = 25.0
	add_child(s)
	assert_bool(s.play(&"stage_2")).is_true()
	assert_object(s.held()).is_null()
	assert_bool(can_process()).is_true()
	s.skip()
	await _until(func(): return not s.is_playing(), 5.0)
	s.free()


func test_a_freed_level_under_a_scene_is_let_go_cleanly() -> void:
	var story := _story()
	story.play(&"stage_4")
	assert_object(story.held()).is_same(_level)
	remove_child(_level)
	_level.free()
	_level = null
	await get_tree().process_frame
	# Nothing left locked: the next level runs.
	_level = PLANET.instantiate()
	add_child(_level)
	_level.stage_beat.make_story = false
	assert_bool(_level.can_process()).is_true()


func test_a_reopened_tin_replays_the_newest_stage_scene_it_never_finished() -> void:
	var w := _level.spawn_worm(Players.P1)
	_grow(w, 4)
	var story := _story()
	story.seen.assign([&"opening", &"stage_2", &"stage_3"])
	assert_bool(_level.stage_beat.catch_up()).is_true()
	assert_object(Story.find(get_tree())).is_same(story)
	assert_str(String(story.current())).is_equal("stage_4")
	story.skip()
	assert_bool(await _until(func(): return not story.is_playing(), 5.0)).is_true()
	assert_bool(story.has_seen(&"stage_4")).is_true()
	# Once: the next opening of the tin plays nothing.
	assert_bool(_level.stage_beat.catch_up()).is_false()
	assert_bool(story.is_playing()).is_false()


func test_catch_up_plays_only_the_newest_missed_scene_and_never_a_seen_or_space_one() -> void:
	var story := Story.new()
	story.persist = false
	add_child(story)
	assert_bool(story.catch_up(1)).is_false()         # stage 1 is the opening's (Y-01)
	assert_bool(story.catch_up(7)).is_false()         # stage 7 plays in space
	story.seen.assign([&"stage_5"])
	assert_bool(story.catch_up(5)).is_false()         # already told
	assert_bool(story.catch_up(6)).is_true()
	assert_str(String(story.current())).is_equal("stage_6")
	assert_bool(story._queue.is_empty()).override_failure_message("older missed scenes must not pile up").is_true()
	assert_bool(story.catch_up(6)).is_false()         # not twice while it plays
	story.skip()
	await _until(func(): return not story.is_playing(), 5.0)
	story.free()


func test_a_new_tin_and_the_demo_never_catch_up() -> void:
	_level.spawn_worm(Players.P1)
	assert_bool(_level.stage_beat.catch_up()).is_false()   # a stage-1 worm: the opening's job
	assert_object(Story.find(get_tree())).is_null()
	var w := Worm.of(Players.P1)
	_grow(w, 3)
	Game.demo = true
	assert_bool(_level.stage_beat.catch_up()).is_false()
	Game.demo = false


func test_the_game_switches_catch_up_on_and_suites_switch_it_off() -> void:
	assert_bool(StageBeat.catch_up_enabled).override_failure_message("SuiteSandbox should switch it off").is_false()
	SuiteSandbox.leave()
	assert_bool(StageBeat.catch_up_enabled).is_true()
	SuiteSandbox.enter("story_waits")
