## Story data: every dock scene loads, uses only real line ids, pictures, actors and anchors; every
## line has a speaker; a scene exists for stages 1 to 7 plus the opening and the ending; Reel's
## excuse is different every time and the Strangestone is never said out loud.
extends GdUnitTestSuite

const LINES := "res://data/story/lines.json"
const DOCK := "res://scenes/story/dock.tscn"
const STEP_KINDS := ["camera", "camera_back", "spawn", "walk", "hop", "face", "show", "hide", "line", "bubble",
		"item", "hold", "drop", "sound", "fade", "bars", "call", "wait"]
const CALLS := ["time", "warm", "clue", "hands", "pose", "shake", "handoff"]


func _lines() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(LINES))


func _line_ids() -> Dictionary:
	var out := {}
	for l in _lines().lines:
		out[String(l.id)] = l
	return out


func _scene(id: StringName) -> Dictionary:
	return CutscenePlayer.load_scene(id)


func test_a_scene_for_every_stage_plus_opening_and_ending() -> void:
	for stage in range(1, 8):
		var id := Story.scene_for_stage(stage)
		assert_str(String(id)).override_failure_message("no scene for stage %d" % stage).is_not_empty()
		assert_bool(_scene(id).is_empty()).override_failure_message("missing data/cutscenes/%s.json" % id).is_false()
	assert_str(String(Story.scene_for_stage(1))).is_equal("opening")
	assert_bool(_scene(&"ending").is_empty()).is_false()
	assert_int(Story.SCENES.size()).is_equal(9)   # + new_tin (S-12, after the sun)


func test_every_scene_loads_and_uses_only_known_lines_steps_and_pictures() -> void:
	StoryPictures.register_all()
	var ids := _line_ids()
	var dock: StoryDock = auto_free(load(DOCK).instantiate())
	for sid in Story.SCENES:
		var d := _scene(sid)
		assert_bool(d.get("steps") is Array and not d.steps.is_empty()).override_failure_message("%s has no steps" % sid).is_true()
		assert_str(String(d.get("id", ""))).is_equal(String(sid))
		for s: Dictionary in d.steps:
			var kind := String(s.get("do", ""))
			assert_bool(STEP_KINDS.has(kind)).override_failure_message("%s: unknown step %s" % [sid, kind]).is_true()
			if kind == "line":
				assert_bool(ids.has(String(s.line))).override_failure_message("%s: unknown line %s" % [sid, s.line]).is_true()
			if s.has("who") and String(s.who) != "":
				assert_object(dock.get_node_or_null(NodePath(String(s.who)))).override_failure_message("%s: no actor %s" % [sid, s.who]).is_not_null()
			for key in ["to", "toward"]:
				if s.get(key) is String and kind != "fade":
					var n := String(s[key])
					var known := dock.get_node_or_null(NodePath(n)) != null or dock.has_node(NodePath("Anchors/" + n))
					assert_bool(known).override_failure_message("%s: unknown point %s" % [sid, n]).is_true()
			for p in s.get("pics", []):
				assert_bool(PictoBubble.has_picture(StringName(p))).override_failure_message("%s: unknown picture %s" % [sid, p]).is_true()
			if kind == "call":
				assert_bool(CALLS.has(String(s.fn))).override_failure_message("%s: unknown call %s" % [sid, s.fn]).is_true()
				if String(s.fn) == "clue":
					assert_bool(dock.state.has(String(s.args.what))).override_failure_message("%s: unknown clue %s" % [sid, s.args.what]).is_true()


func test_every_line_has_a_speaker_text_and_fallback_and_is_used() -> void:
	var d := _lines()
	var speakers: Dictionary = d.speakers
	var used := {}
	for sid in Story.SCENES:
		for s in _scene(sid).steps:
			if s.do == "line":
				used[String(s.line)] = true
	var seen := {}
	for l in d.lines:
		var id := String(l.id)
		assert_bool(seen.has(id)).override_failure_message("duplicate line id " + id).is_false()
		seen[id] = true
		assert_bool(speakers.has(String(l.get("character", "")))).override_failure_message(id + " has no known speaker").is_true()
		assert_str(String(l.get("text", ""))).is_not_empty()
		var fb := String(l.get("fallback", ""))
		assert_bool(fb.begins_with("bark:") and StoryVoice.CUES.has(fb.substr(5))).override_failure_message(id + " bad fallback " + fb).is_true()
		assert_bool(used.has(id)).override_failure_message(id + " is in no scene").is_true()


func test_every_scene_has_a_background_clue_and_a_time_of_day() -> void:
	for sid in Story.SCENES:
		var d := _scene(sid)
		assert_str(String(d.get("clue", ""))).is_not_empty()
		var lit := false
		for s in d.steps:
			if s.do == "call" and s.fn == "time":
				lit = true
		assert_bool(lit).override_failure_message(sid + " sets no time of day").is_true()


func test_reels_excuse_differs_every_time_and_strangestone_is_never_said() -> void:
	var excuses := []
	for l in _lines().lines:
		assert_bool(String(l.text).to_lower().contains("strange")).override_failure_message(String(l.id) + " says it out loud").is_false()
		if l.has("excuse"):
			assert_bool(excuses.has(l.excuse)).override_failure_message("excuse repeats: " + String(l.excuse)).is_false()
			excuses.append(l.excuse)
	assert_int(excuses.size()).is_greater_equal(5)
	for e in ["comet", "chili", "purple_rock"]:
		assert_bool(excuses.has(e)).is_true()


func test_hands_get_wider_every_stage() -> void:
	var last := 0.0
	for sid in [&"opening", &"stage_2", &"stage_3", &"stage_4", &"stage_5", &"stage_6"]:
		var widest := 0.0
		for s in _scene(sid).steps:
			if s.do == "call" and s.fn == "hands":
				widest = maxf(widest, float(s.args.w))
		assert_float(widest).override_failure_message("%s hands %s not wider than %s" % [sid, widest, last]).is_greater(last)
		last = widest


func test_opening_hands_off_to_the_worm_underground_even_when_skipped() -> void:
	var found := false
	for s in _scene(&"opening").steps:
		if s.do == "call" and s.fn == "handoff":
			found = bool(s.get("always", false)) and String(s.args.what) == "follow_worm_underground"
	assert_bool(found).is_true()


func test_voice_files_expected_one_per_line() -> void:
	var files := StoryVoice.expected_files()
	assert_int(files.size()).is_equal(_line_ids().size())
	for id in files:
		assert_str(String(files[id])).is_equal("res://assets/story/voice/%s.ogg" % id)


## Y-01: the opening plays the design's beats in order (GAME.md "Opening"): dawn dock, the sandwich
## on the hook, "worms were small", two fingers apart, the warm flashback, the worm plops into the
## dirt, the camera follows it underground, then the handoff that gives the player the stick.
func test_opening_has_every_beat_in_order() -> void:
	var steps: Array = _scene(&"opening").steps
	var beats := {
		"dawn": func(s): return s.do == "call" and s.fn == "time" and String(s.args.of) == "dawn",
		"sandwich_on_the_hook": func(s): return s.do == "line" and String(s.line) == "op_bobber_why" and s.get("pics", []).has("sandwich"),
		"worms_were_small": func(s): return s.do == "line" and String(s.line) == "op_reel_worms",
		"two_fingers_apart": func(s): return s.do == "call" and s.fn == "hands" and float(s.args.w) > 0.0,
		"warm_flashback": func(s): return s.do == "call" and s.fn == "warm" and bool(s.args.on),
		"plop_into_the_dirt": func(s): return s.do == "sound" and String(s.cue) == "story_plop",
		"camera_follows_underground": func(s): return s.do == "camera" and String(s.to) == "burrow",
		"you_have_the_stick": func(s): return s.do == "call" and s.fn == "handoff" and bool(s.get("always", false)) and String(s.args.what) == "follow_worm_underground",
	}
	var at := -1
	for name: String in beats:
		var found := -1
		for i in range(at + 1, steps.size()):
			if beats[name].call(steps[i]):
				found = i
				break
		assert_int(found).override_failure_message("opening: beat '%s' missing or out of order" % name).is_greater(at)
		at = maxi(at, found)
	assert_str(String(_scene(&"opening").time_of_day)).is_equal("dawn")
	assert_str(String(_line_ids()["op_reel_worms"].text).to_lower()).contains("little")
	# The handoff is the last step, so nothing plays after the player has the stick.
	assert_int(at).is_equal(steps.size() - 1)


## Y-09: played in story order, every scene that asks "what happened?" gets a different excuse
## from the one before; any three in a row are all different. No line, script or direction
## names the Strangestone.
func test_excuse_changes_every_time_reel_is_asked_in_story_order() -> void:
	var lines := _line_ids()
	var asked: Array = []
	for sid in StoryDock.ORDER:
		for s in _scene(sid).steps:
			if s.do == "line" and lines.has(String(s.line)) and lines[String(s.line)].has("excuse"):
				asked.append(String(lines[String(s.line)].excuse))
	assert_int(asked.size()).is_greater_equal(3)
	for i in range(1, asked.size()):
		assert_str(asked[i]).override_failure_message("excuse %d repeats the last: %s" % [i, asked[i]]).is_not_equal(asked[i - 1])
	for i in range(2, asked.size()):
		assert_int({asked[i - 2]: 1, asked[i - 1]: 1, asked[i]: 1}.size()).override_failure_message("three in a row repeat at %d" % i).is_equal(3)
	for l in _lines().lines:
		for k in ["text", "delivery"]:
			assert_bool(String(l.get(k, "")).to_lower().contains("strange")).override_failure_message("%s %s names the Strangestone" % [l.id, k]).is_false()
