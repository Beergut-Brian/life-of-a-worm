## Y-11 "short": every dock scene ends on its own, unskipped, well inside its budget: the opening
## within OPENING_MAX (GAME.md: ~60 s), every other scene within SCENE_MAX (Y-08: 15 to 30 s a
## stage). The cutscene player's own 90 s cap is the safety net, never the way a scene ends.
## (Skippable with any button: test_story_host.gd; rewatchable: test_tackle_box.gd.)
extends GdUnitTestSuite

const SPEED := 20.0
const OPENING_MAX := 60.0
const SCENE_MAX := 30.0

var _done: Array = []


func _story() -> Story:
	var s := Story.new()
	s.persist = false
	s.speed = SPEED
	add_child(s)
	s.finished.connect(func(id, skipped): _done.append([id, skipped]))
	return auto_free(s)


func test_every_scene_ends_on_its_own_inside_its_budget() -> void:
	var story := _story()
	var lengths := {}
	for sid in Story.SCENES:
		_done.clear()
		var t0 := Time.get_ticks_usec()
		story.play(sid)
		var end := Time.get_ticks_msec() + int(CutscenePlayer.MAX_SECS / SPEED * 1000.0) + 4000
		while _done.is_empty() and Time.get_ticks_msec() < end:
			await get_tree().process_frame
		var secs := (Time.get_ticks_usec() - t0) / 1e6 * SPEED
		lengths[sid] = snappedf(secs, 0.1)
		assert_array(_done).override_failure_message("%s never ended" % sid).is_not_empty()
		if _done.is_empty():
			continue
		assert_bool(_done[0][1]).override_failure_message("%s was skipped, not watched" % sid).is_false()
		var cap := OPENING_MAX if sid == &"opening" else SCENE_MAX
		assert_float(secs).override_failure_message("%s runs %.1f s, budget %.0f s" % [sid, secs, cap]).is_less(cap)
		assert_float(secs).override_failure_message("%s hit the player's hard cap" % sid).is_less(CutscenePlayer.MAX_SECS - 1.0)
	print("story lengths (s): ", lengths)
