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


## Y-01: a button pressed on the opening's very first frame skips the whole opening (the press is
## kept through the player's short grace), unlocks input and still hands off underground.
func test_opening_skips_from_the_first_frame() -> void:
	var story := _story(1.0)
	var asked: Array = []
	var locks: Array = []
	story.handoff.connect(func(id, what): asked.append([id, what]))
	story.input_locked.connect(func(on): locks.append(on))
	assert_bool(story.play(&"opening")).is_true()
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_A
	ev.pressed = true
	story._input(ev)
	var ended: bool = await _until(func(): return not _done.is_empty(), 2.0)
	assert_bool(ended).override_failure_message("opening ignored a first-frame press").is_true()
	assert_array(_done[0]).is_equal([&"opening", true])
	assert_array(asked).is_equal([[&"opening", "follow_worm_underground"]])
	assert_bool(story.is_playing()).is_false()
	if not locks.is_empty():
		assert_bool(locks.back()).is_false()


## Y-10: subtitles are off by default (no setting saved), and then a line with no voice file
## plays its bark: fallback while nothing on screen is text.
func test_subtitles_off_by_default_and_unvoiced_lines_bark_without_text() -> void:
	var fresh := Story.new()
	assert_bool(fresh.subtitles).is_false()
	fresh.free()
	var save := get_node_or_null(^"/root/Save")
	var old_path := ""
	if save != null:
		old_path = save.settings_path
		save.settings_path = "user://test_story_subtitles_settings.json"
		save.wipe_settings()
	var story := _story(30.0)
	assert_bool(story.subtitles).is_false()
	story.play(&"opening")
	var texts: Array = []
	while not story.is_playing() and _done.is_empty():
		await get_tree().process_frame
	while _done.is_empty():
		if story.subtitle_text() != "":
			texts.append(story.subtitle_text())
		if story._viewport != null and is_instance_valid(story._viewport):
			assert_int(story._viewport.find_children("*", "Label", true, false).size()).is_equal(0)
		await get_tree().process_frame
	if save != null:
		save.settings_path = old_path
		save.reload_settings()
	assert_array(texts).is_empty()
	assert_int(story.said.size()).is_greater(0)
	for s in story.said:
		var l := CutscenePlayer.line(String(s[0]))
		var file := ResourceLoader.exists("res://assets/story/voice/%s.ogg" % s[0])
		assert_bool(String(l.fallback).begins_with("bark:")).is_true()
		assert_str(String(s[2])).override_failure_message("%s played %s" % [s[0], s[2]]).is_equal("file" if file else "bark")


## Y-10: turned on (for Kaden), a subtitle shows the line's script without its [directions].
func test_subtitles_on_show_the_script_without_directions() -> void:
	assert_str(Story.spoken_text("op_reel_worms")).is_equal("Worms? Heh. Back in my day, worms were little.")
	var story := _story(1.0)
	story.subtitles = true
	story.play(&"opening")
	var seen := await _until(func(): return story.subtitle_text() != "", 15.0)
	assert_bool(seen).is_true()
	assert_bool(story.subtitle_text().contains("[")).is_false()
	story.skip()
	await _until(func(): return not _done.is_empty(), 3.0)
	assert_str(story.subtitle_text()).is_equal("")
