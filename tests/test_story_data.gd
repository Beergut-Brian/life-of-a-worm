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
