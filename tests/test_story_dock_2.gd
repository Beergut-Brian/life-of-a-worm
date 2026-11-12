## Dock story follow-up (worm-story-2): every beat's data loads and matches GAME.md's beat table;
## every line a dock scene speaks has a library-sound fallback; the camera is on each background
## clue when it happens (the cause on screen); each scene is 15 to 30 s; every scene skips and plays
## again (the tackle box lists it); no line names a real place; the trait beat shows its cause with
## a camera lean and the why bubble. Saves go to this suite's own sandbox profile.
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")
const TITLES := {
	&"stage_2": "It got hungry", &"stage_3": "It started to change", &"stage_4": "It came up",
	&"stage_5": "Nobody fished that year", &"stage_6": "The big one", &"ending": "Still out there",
}
## Where each background clue happens in the dock set (scripts/story/dock.gd draws it there).
const CLUE_AT := {
	"ripple": Vector2(230, 6), "tree": Vector2(200, -20), "shed_sink": Vector2(-120, -20),
	"hill_bite": Vector2(-170, -40), "hill": Vector2(-200, -20), "star": Vector2(-60, -190),
}
const VIEW := Vector2(1920, 1080)
## Words that would make a line name a real place. Lines may only use invented, generic places.
const REAL_PLACES := ["america", "usa", "texas", "ohio", "florida", "california", "alaska", "york",
	"london", "paris", "chicago", "boston", "dallas", "seattle", "denver", "canada", "mexico",
	"england", "france", "germany", "japan", "china", "australia", "europe", "africa", "minnesota",
	"michigan", "wisconsin", "oklahoma", "kansas", "missouri", "tennessee", "kentucky", "georgia",
	"carolina", "virginia", "arizona", "nevada", "oregon", "montana", "iowa", "nebraska", "utah",
	"colorado", "mississippi", "louisiana", "arkansas", "alabama", "indiana", "illinois", "street",
	"avenue", "lake ", "river", "county", "earth", "walmart", "mcdonald"]
## Capitalised words a line may use mid-sentence: the cast and the family words. ALL-CAPS words
## are shouted emphasis ("THIS big"), not names.
const NAMES := ["Reel", "Bobber", "Gulp", "Burp", "Grandpa", "Grandma", "It", "I", "Nuh"]

var _done: Array = []


func before() -> void:
	SuiteSandbox.enter("story_dock_2")


func after() -> void:
	Save.wipe()
	for p in Audio._pool:
		p.stop()
	SuiteSandbox.leave()


func before_test() -> void:
	_done.clear()


func _lines() -> Dictionary:
	var out := {}
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/lines.json"))
	for l in d.lines:
		out[String(l.id)] = l
	return out


func _story(speed := 30.0) -> Story:
	var s := Story.new()
	s.persist = false
	s.speed = speed
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


func _anchor(dock: StoryDock, n: String) -> Vector2:
	var m := dock.get_node_or_null(NodePath(n))
	if m is Node2D and not (m is Camera2D):
		return (m as Node2D).position
	return dock.anchor(n)


func test_each_beat_loads_with_its_title_clue_and_lines() -> void:
	var lines := _lines()
	for id in TITLES:
		var sc := CutscenePlayer.load_scene(id)
		assert_bool(sc.is_empty()).override_failure_message("%s did not load" % id).is_false()
		assert_str(String(sc.get("title", ""))).is_equal(TITLES[id])
		assert_str(String(sc.get("clue", ""))).is_not_empty()
		var spoken := 0
		for st in sc.steps:
			if st.get("do") == "line":
				spoken += 1
				assert_bool(lines.has(String(st.line))).override_failure_message("%s: no line %s" % [id, st.line]).is_true()
				assert_array(st.get("pics", [])).override_failure_message("%s: %s has no picture bubble" % [id, st.line]).is_not_empty()
		assert_int(spoken).is_greater_equal(3)


func test_every_dock_scene_line_has_a_library_sound_fallback() -> void:
	var lines := _lines()
	for id in Story.SCENES:
		for st in CutscenePlayer.load_scene(id).steps:
			if st.get("do") != "line":
				continue
			var l: Dictionary = lines[String(st.line)]
			var fb := String(l.get("fallback", ""))
			assert_bool(fb.begins_with("bark:") and StoryVoice.CUES.has(fb.substr(5))) \
					.override_failure_message("%s: %s fallback '%s'" % [id, st.line, fb]).is_true()
			# and the fallback really makes a sound with no voice file
			assert_object(StoryVoice.bark_stream(String(l.character), fb.substr(5))).is_not_null()


## The cause on screen: when a scene tweens a background clue, the camera's last target shows it.
func test_the_camera_is_on_every_background_clue_when_it_happens() -> void:
	var dock: StoryDock = auto_free(load(Story.DOCK_SCENE).instantiate())
	var checked := 0
	for id in Story.SCENES:
		var cam := Vector2.ZERO
		var zoom := 4.0
		for st in CutscenePlayer.load_scene(id).steps:
			if st.get("do") == "camera":
				cam = _anchor(dock, String(st.to)) + Vector2(float(st.get("dx", 0)), float(st.get("dy", 0)))
				zoom = float(st.get("zoom", zoom))
			elif st.get("do") == "call" and st.get("fn") == "clue":
				var what := String(st.args.what)
				if not CLUE_AT.has(what) or float(st.args.get("secs", 1.0)) <= 0.0:
					continue
				var half := VIEW / zoom * 0.5 - Vector2(8, 8)
				var d: Vector2 = (CLUE_AT[what] - cam).abs()
				assert_bool(d.x <= half.x and d.y <= half.y) \
						.override_failure_message("%s: camera at %s x%.1f misses the %s at %s" % [id, cam, zoom, what, CLUE_AT[what]]).is_true()
				checked += 1
	assert_int(checked).is_greater_equal(6)


## Y-08: one dock scene per stage, 15 to 30 s with the placeholder voices.
func test_each_stage_scene_runs_15_to_30_seconds() -> void:
	var story := _story(8.0)
	for id in [&"stage_2", &"stage_3", &"stage_4", &"stage_5", &"stage_6", &"stage_7", &"ending"]:
		_done.clear()
		var t0 := Time.get_ticks_msec()
		story.play(id)
		await _until(func(): return not _done.is_empty(), 10.0)
		var secs := (Time.get_ticks_msec() - t0) / 1000.0 * story.speed
		assert_bool(_done.is_empty()).is_false()
		assert_bool(_done[0][1]).override_failure_message("%s ended by skip" % id).is_false()
		assert_float(secs).override_failure_message("%s ran %.1f s" % [id, secs]).is_between(15.0, 30.0)


func test_every_scene_skips_and_can_be_watched_again() -> void:
	var story := _story(1.0)
	var log := TackleLog.new()
	for id in Story.SCENES:
		assert_array(log.entries[&"cutscenes"]).contains([id])
		for watch in 2:   # first watch, then again (the tackle box's rewatch is the same play())
			_done.clear()
			assert_bool(story.play(id)).is_true()
			assert_str(String(story.current())).is_equal(String(id))
			await get_tree().process_frame
			story.skip()
			var ended: bool = await _until(func(): return not _done.is_empty(), 3.0)
			assert_bool(ended).override_failure_message("%s watch %d did not skip" % [id, watch]).is_true()
			assert_bool(_done[0][1]).is_true()
		assert_bool(story.has_seen(id)).is_true()
	log.free()


func test_seen_scenes_are_saved_in_the_sandbox_tin() -> void:
	assert_str(Save.profile).starts_with(SuiteSandbox.PROFILE_PREFIX)
	Save.wipe()
	var story := Story.new()
	story.speed = 30.0
	add_child(story)
	story.finished.connect(func(id, skipped): _done.append([id, skipped]))
	story.play(&"stage_4")
	await get_tree().process_frame
	story.skip()
	await _until(func(): return not _done.is_empty(), 3.0)
	assert_array(Save.get_value(Story.SAVE_KEY, [])).contains(["stage_4"])
	story.free()


func test_no_line_names_a_real_place() -> void:
	var rx := RegEx.create_from_string("[^.!?\\s]\\s+([A-Z][A-Za-z]*)")
	for l in _lines().values():
		var text := String(l.text)
		var low := text.to_lower()
		for p in REAL_PLACES:
			assert_bool(low.contains(p)).override_failure_message("%s names '%s'" % [l.id, p]).is_false()
		var bare := RegEx.create_from_string("\\[[^\\]]*\\]").sub(text, "", true)
		for m in rx.search_all(bare):
			if m.get_string(1) == m.get_string(1).to_upper():
				continue
			assert_array(NAMES).override_failure_message("%s: unknown proper noun '%s'" % [l.id, m.get_string(1)]).contains([m.get_string(1)])


# --- the trait beat (Y-16 / P-14) ----------------------------------------------------------------

func _worm() -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = Players.P1
	var m := WormGrowth.new()
	m.start_at_stage(2)
	w.model = m
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	w.set_physics_process(false)
	return auto_free(w)


func test_a_trait_shows_its_cause_with_a_camera_lean_and_the_why_bubble() -> void:
	var w := _worm()
	var cam: PolarCamera = auto_free(PolarCamera.new())
	add_child(cam)
	var host: Node2D = auto_free(Node2D.new())
	add_child(host)
	var tb := TraitBeat.new()
	tb.camera = cam
	host.add_child(tb)
	tb.play(w, &"stone_head")
	assert_int(cam.lean_in).is_equal(1)
	var why: TraitWhy = null
	for c in host.get_children():
		if c is TraitWhy:
			why = c
	assert_object(why).is_not_null()
	var stone := w.rules.flavour_color(&"stone")
	assert_array(why.recipe()).is_equal([[stone, 4]])
	assert_int(tb.history.size()).is_equal(1)
	await get_tree().create_timer(TraitBeat.LEAN + 0.2).timeout
	assert_int(cam.lean_in).is_equal(0)


func test_a_trait_during_a_stage_up_waits_its_turn() -> void:
	var w := _worm()
	var host: Node2D = auto_free(Node2D.new())
	add_child(host)
	var tb := TraitBeat.new()
	host.add_child(tb)
	tb.watch(w)
	tb.hold(0.4)
	w.trait_earned.emit(w.player, &"wriggle")
	assert_int(tb.history.size()).is_equal(0)
	await get_tree().create_timer(0.6).timeout
	assert_int(tb.history.size()).is_equal(1)
	assert_str(String(tb.history[0].trait)).is_equal("wriggle")


func test_the_stage_beat_hooks_every_worm_for_trait_beats() -> void:
	var sb: StageBeat = auto_free(StageBeat.new())
	sb.make_story = false
	add_child(sb)
	var w := _worm()
	assert_bool(w.trait_earned.is_connected(sb.trait_beat._on_trait_earned)).is_true()
