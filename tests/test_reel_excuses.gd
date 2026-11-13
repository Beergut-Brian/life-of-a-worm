## Y-09: Old Reel gives a different silly reason every time he is asked "what happened?",
## rewatches from the tackle box included, and the tin remembers what he last said.
##  - played in story order the first time, every scene keeps its own excuse (nothing changes);
##  - watching a scene again swaps its excuse line (and its pictures) for another excuse, never
##    one of the last two he told (then the least recently told one); the speaker stays;
##  - the excuses told are kept in the tin (`story_excuses`) and read back by a new Story.
## Excuses are counted on the cutscene player's line beats (Story.excuses_told), not by polling.
extends GdUnitTestSuite

var _done: Array = []


func before() -> void:
	SuiteSandbox.enter("reel_excuses")


func after() -> void:
	SuiteSandbox.leave()


func before_test() -> void:
	_done.clear()
	Save.wipe()


func _story(persist := false) -> Story:
	var s := Story.new()
	s.persist = persist
	s.speed = 25.0
	add_child(s)
	s.finished.connect(func(id, skipped): _done.append([id, skipped]))
	return auto_free(s)


func _until(cond: Callable, secs := 20.0) -> bool:
	var end := Time.get_ticks_msec() + int(secs * 1000)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


## Plays `id` to its end and returns the excuses told while it played.
func _watch(story: Story, id: StringName) -> Array:
	var before_n := story.excuses_told.size()
	var n := _done.size()
	assert_bool(story.play(id)).is_true()
	var ended: bool = await _until(func(): return _done.size() > n, 30.0)
	assert_bool(ended).override_failure_message("%s never ended" % id).is_true()
	return story.excuses_told.slice(before_n)


func _excuse_steps(d: Dictionary) -> Array:
	return d.steps.filter(func(s): return s.get("do", "") == "line" and Story.excuse_of(String(s.line)) != &"")


func test_the_pool_has_one_excuse_per_asking_scene_all_different() -> void:
	var pool := Story.excuse_pool()
	assert_int(pool.size()).is_greater_equal(5)
	var ids := pool.map(func(p): return p.excuse)
	for e in ids:
		assert_int(ids.count(e)).is_equal(1)
	for p in pool:
		assert_array(p.pics).override_failure_message("%s has no picture" % p.line).is_not_empty()


func test_first_time_in_story_order_every_scene_keeps_its_own_excuse() -> void:
	var story := _story()
	for sid in Story.SCENES:
		var own := CutscenePlayer.load_scene(sid)
		var mine := story.script_for(sid)
		assert_array(mine.steps).is_equal(own.steps)
		for s in _excuse_steps(mine):
			story.excuses_told.append(Story.excuse_of(String(s.line)))   # as if he said it


func test_rewatching_a_scene_tells_a_different_excuse_every_time() -> void:
	var story := _story()
	var told: Array = []
	for i in 5:
		told.append_array(await _watch(story, &"stage_3"))
	assert_int(told.size()).is_equal(5)   # one excuse a viewing, counted on its line beat
	assert_str(String(told[0])).is_equal("comet")   # the first time is the scene's own
	for i in range(1, told.size()):
		assert_str(String(told[i])).override_failure_message("viewing %d repeats %s" % [i, told[i]]).is_not_equal(String(told[i - 1]))
		if i >= 2:
			assert_str(String(told[i])).is_not_equal(String(told[i - 2]))
	# his own excuse whenever it is not one of the last two, else the least recently told
	assert_array(told).is_equal([&"comet", &"chili", &"purple_rock", &"comet", &"lucky_socks"])


func test_a_swapped_excuse_brings_its_own_pictures_and_keeps_the_speaker() -> void:
	var story := _story()
	story.excuses_told.assign([&"chili", &"comet"])   # he just said comet and chili
	var own: Dictionary = _excuse_steps(CutscenePlayer.load_scene(&"stage_3"))[0]
	var got: Dictionary = _excuse_steps(story.script_for(&"stage_3"))[0]
	var e := Story.excuse_of(String(got.line))
	assert_bool([&"comet", &"chili"].has(e)).is_false()
	var pool := {}
	for p in Story.excuse_pool():
		pool[p.excuse] = p
	assert_array(got.pics).is_equal(pool[e].pics)
	assert_str(String(got.who)).is_equal(String(own.who))
	# every other step of the scene is untouched
	assert_int(story.script_for(&"stage_3").steps.size()).is_equal(CutscenePlayer.load_scene(&"stage_3").steps.size())


func test_a_scene_seen_after_a_rewatch_never_repeats_what_he_just_said() -> void:
	var story := _story()
	story.excuses_told.assign([&"comet", &"chili"])   # a rewatch of stage 3 told chili
	var got := Story.excuse_of(String(_excuse_steps(story.script_for(&"stage_4"))[0].line))
	assert_bool([&"comet", &"chili"].has(got)).is_false()


func test_the_tin_remembers_what_he_told() -> void:
	var story := _story(true)
	var told: Array = await _watch(story, &"stage_3")
	told.append_array(await _watch(story, &"stage_3"))
	assert_array(Save.get_value(Story.EXCUSE_KEY, [])).is_equal(told.map(func(x): return String(x)))
	var again := _story(true)
	assert_array(again.excuses_told).is_equal(story.excuses_told)
	var next: Array = await _watch(again, &"stage_3")
	assert_bool(told.has(next[0])).is_false()
