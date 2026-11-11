## The Story host: skipping from any beat ends every scene (and unlocks input); any button skips;
## stage_changed plays the matching scene exactly once; missing voice files fall back to a bark or
## the placeholder babble.
extends GdUnitTestSuite

signal stage_changed(player: int, from: int, to: int)

var _done: Array = []
var _started: Array = []


func _story(speed := 25.0) -> Story:
	var s := Story.new()
	s.persist = false
	s.speed = speed
	add_child(s)
	s.finished.connect(func(id, skipped): _done.append([id, skipped]))
	s.started.connect(func(id): _started.append(id))
	return auto_free(s)


func before_test() -> void:
	_done.clear()
	_started.clear()


func _until(cond: Callable, secs := 20.0) -> bool:
	var end := Time.get_ticks_msec() + int(secs * 1000)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func test_skip_from_any_beat_ends_every_scene() -> void:
	var story := _story()
	var locks: Array = []
	story.input_locked.connect(func(on): locks.append(on))
	for sid in Story.SCENES:
		var n: int = CutscenePlayer.load_scene(sid).steps.size()
		for at in [0, n / 2, n - 1]:
			_done.clear()
			assert_bool(story.play(sid)).is_true()
			var beats := [0]
			story.player.beat.connect(func(_k, _d): beats[0] += 1)
			await _until(func(): return beats[0] > at or not story.is_playing())
			story.skip()
			var ended: bool = await _until(func(): return not _done.is_empty(), 3.0)
			assert_bool(ended).override_failure_message("%s did not end after skip at beat %d" % [sid, at]).is_true()
			assert_bool(story.is_playing()).is_false()
			assert_array(story.seen).contains([sid])
	assert_bool(locks.back()).override_failure_message("input left locked").is_false()


func test_any_button_skips() -> void:
	var story := _story(1.0)
	story.play(&"stage_3")
	await get_tree().create_timer(0.7).timeout
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_Y
	ev.pressed = true
	story._input(ev)
	var ended: bool = await _until(func(): return not _done.is_empty(), 3.0)
	assert_bool(ended).is_true()
	assert_array(_done[0]).is_equal([&"stage_3", true])


func test_skipped_opening_still_hands_off_underground() -> void:
	var story := _story(1.0)
	var asked: Array = []
	story.handoff.connect(func(id, what): asked.append([id, what]))
	story.play(&"opening")
	await get_tree().process_frame
	story.skip()
	await _until(func(): return not _done.is_empty(), 3.0)
	assert_array(asked).is_equal([[&"opening", "follow_worm_underground"]])


func test_stage_changed_plays_the_right_scene_once() -> void:
	var story := _story()
	story.watch(self)
	stage_changed.emit(0, 1, 2)
	assert_str(String(story.current())).is_equal("stage_2")
	stage_changed.emit(1, 1, 2)          # P2 reaches stage 2 during the scene: nothing new
	story.skip()
	await _until(func(): return not _done.is_empty(), 3.0)
	await get_tree().process_frame
	assert_bool(story.is_playing()).is_false()
	stage_changed.emit(1, 1, 2)          # and again after it: still nothing
	stage_changed.emit(0, 3, 2)          # going down: nothing
	assert_bool(story.is_playing()).is_false()
	stage_changed.emit(0, 2, 3)
	assert_str(String(story.current())).is_equal("stage_3")
	assert_array(_started).is_equal([&"stage_2", &"stage_3"])
	story.skip()
	await _until(func(): return _done.size() >= 2, 3.0)
	for stage in range(4, 8):
		_done.clear()
		stage_changed.emit(0, stage - 1, stage)
		assert_str(String(story.current())).is_equal(String(Story.scene_for_stage(stage)))
		story.skip()
		await _until(func(): return not _done.is_empty(), 3.0)


func test_a_stage_up_during_a_scene_queues_the_next_one() -> void:
	var story := _story()
	story.play(&"stage_4")
	story.on_stage_changed(0, 4, 5)
	assert_str(String(story.current())).is_equal("stage_4")
	story.skip()
	await _until(func(): return story.current() == &"stage_5", 3.0)
	assert_str(String(story.current())).is_equal("stage_5")
	story.skip()
	await _until(func(): return _done.size() >= 2, 3.0)


func test_missing_voice_files_fall_back_to_a_bark_or_blip() -> void:
	var story := _story(30.0)
	story.play(&"stage_2")
	await _until(func(): return not _done.is_empty(), 20.0)
	assert_bool(_done.is_empty()).is_false()
	assert_int(story.said.size()).is_equal(5)
	for s in story.said:
		var how := String(s[2])
		var file := ResourceLoader.exists("res://assets/story/voice/%s.ogg" % s[0])
		assert_str(how).is_equal("file" if file else "bark")
	for ch in ["old_reel", "bobber"]:
		var st := StoryVoice.bark_stream(ch, "wait")
		assert_object(st).is_not_null()
		assert_float(st.get_length()).is_greater(0.1)


func test_unknown_scene_is_refused() -> void:
	var story := _story()
	assert_bool(story.play(&"no_such_scene")).is_false()
	assert_bool(story.is_playing()).is_false()
