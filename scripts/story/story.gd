## The story host: plays Old Reel's dock scenes over the game. Not an autoload: the game adds one
## `Story` node (scenes/story/story.tscn, or `Story.new()`) and keeps it for the session.
##
##   var story := Story.find(get_tree())        # the one in group "story"
##   story.play(&"opening")                     # any scene in data/cutscenes/<id>.json
##   story.watch(worm)                          # anything with stage_changed(player, from, to)
##   story.handoff.connect(...)                 # "follow_worm_underground" after the opening
##
## A scene is drawn in its own SubViewport on a CanvasLayer above everything (the dock set,
## scenes/story/dock.tscn), so the game world underneath is never touched. Any button skips
## (after the player's 0.5 s grace); the cutscene player also skips itself past 90 s, so nothing
## here can softlock. Seen scene ids are kept in the tin's save (`story_seen`) for the tackle box.
## Lines are voiced, not written: subtitles (the line's script, for Kaden) show only when the
## `subtitles` setting is on, and it is off by default. Off, nothing on screen is ever text.
class_name Story
extends Node

signal started(id: StringName)
signal finished(id: StringName, skipped: bool)
## Contract name (GAME.md technical plan): a scene ended, watched or skipped.
signal cutscene_finished(id: StringName)
## The scene hands control back with a request: "follow_worm_underground" (the opening).
signal handoff(id: StringName, what: String)
## Lock / unlock every player's input (the grey-box lane listens).
signal input_locked(on: bool)

const DOCK_SCENE := "res://scenes/story/dock.tscn"
const SCENES: Array[StringName] = [&"opening", &"stage_2", &"stage_3", &"stage_4", &"stage_5", &"stage_6", &"stage_7", &"ending", &"new_tin"]
## Stage -> the dock scene that marks reaching it (stage 1 is the start: the opening).
const STAGE_SCENES := {1: &"opening", 2: &"stage_2", 3: &"stage_3", 4: &"stage_4", 5: &"stage_5", 6: &"stage_6", 7: &"stage_7"}
const SAVE_KEY := "story_seen"
const LAYER := 90
## Save setting that turns subtitles on (default off, GAME.md "Rules for cutscenes").
const SUBTITLES_SETTING := "subtitles"
## Y-09: Reel's excuses told in this tin, oldest first (tin key), so the next one can differ.
const EXCUSE_KEY := "story_excuses"
## An excuse never repeats any of the last this-many he told (rewatches included).
const EXCUSE_FRESH := 2
## The told list keeps only the newest this-many (enough to know which is oldest of six).
const EXCUSE_LOG := 24

## Keep `seen` in Save (off in tests).
var persist := true
## Play speed (tests and previews speed scenes up).
var speed := 1.0
## Show each line's script as a subtitle. Off by default; `_ready` reads the Save setting.
var subtitles := false
## Scene ids already watched this tin, in order.
var seen: Array[StringName] = []
## Lines the last scene voiced: [line id, character, "file" | "bark" | "sfx" | "none"].
var said: Array = []
## Excuse ids Reel has told in this tin, oldest first (Y-09). Saved under EXCUSE_KEY.
var excuses_told: Array[StringName] = []
## Host calls the last scene made: [fn, args].
var calls: Array = []

var player: CutscenePlayer
var dock: StoryDock
var _layer: CanvasLayer
var _viewport: SubViewport
var _queue: Array[StringName] = []
var _pressed := false
var _locked := false
var _subtitle: Label


static func find(tree: SceneTree) -> Story:
	return tree.get_first_node_in_group(&"story") as Story if tree != null else null


static func scene_for_stage(stage: int) -> StringName:
	return STAGE_SCENES.get(stage, &"")


func _init() -> void:
	name = "Story"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	add_to_group(&"story")
	StoryPictures.register_all()
	if _save() != null:
		subtitles = bool(_save().call("get_setting", SUBTITLES_SETTING, false))
	if persist and _save() != null:
		for id in _save().call("get_value", SAVE_KEY, []):
			if not seen.has(StringName(id)):
				seen.append(StringName(id))
		for e in _save().call("get_value", EXCUSE_KEY, []):
			excuses_told.append(StringName(e))


func _exit_tree() -> void:
	_close()
	StoryVoice.clear_cache()


# --- API -----------------------------------------------------------------------------------------

## Plays scene `id` now, or after the current one. False when there is no such scene.
func play(id: StringName) -> bool:
	if CutscenePlayer.load_scene(id).is_empty():
		push_warning("Story: no scene '%s'" % id)
		return false
	if is_playing():
		if not _queue.has(id):
			_queue.append(id)
		return true
	_open(id)
	return true


func is_playing() -> bool:
	return player != null and player.is_playing()


func current() -> StringName:
	return player.current() if player != null else &""


func skip() -> void:
	if is_playing():
		player.skip()


## The subtitle on screen now: "" whenever subtitles are off or nobody is talking.
func subtitle_text() -> String:
	return _subtitle.text if _subtitle != null and is_instance_valid(_subtitle) and _subtitle.visible else ""


## A line's script without its [voice directions], for the subtitle.
static func spoken_text(line_id: String) -> String:
	var t := String(CutscenePlayer.line(line_id).get("text", ""))
	var re := RegEx.create_from_string("\\[[^\\]]*\\]\\s*")
	return re.sub(t, "", true).strip_edges()


func has_seen(id: StringName) -> bool:
	return seen.has(id)


## Listen to a node's `stage_changed(player, from, to)` (the worm lane's contract signal).
func watch(source: Object) -> void:
	if source != null and source.has_signal(&"stage_changed") and not source.is_connected(&"stage_changed", on_stage_changed):
		source.connect(&"stage_changed", on_stage_changed)


## Plays the dock scene for reaching stage `to`, once per tin: the second worm reaching the same
## stage, or a stage going down, plays nothing.
func on_stage_changed(_player: int, from: int, to: int) -> void:
	if to <= from:
		return
	var id := scene_for_stage(to)
	if id == &"" or seen.has(id) or _queue.has(id) or current() == id:
		return
	play(id)


# --- running a scene -----------------------------------------------------------------------------

func _open(id: StringName) -> void:
	_close()
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(box)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(get_viewport().get_visible_rect().size)
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	box.add_child(_viewport)
	dock = load(DOCK_SCENE).instantiate()
	_viewport.add_child(dock)
	dock.prepare(id)
	var ui := CanvasLayer.new()
	ui.layer = 5
	_viewport.add_child(ui)
	player = CutscenePlayer.new()
	player.host = self
	player.speed = speed
	player.cues = {"start": "story_start", "skip": "story_skip", "hop": "story_hop", "item": "story_item", "no_bark": "story_blip"}
	ui.add_child(player)
	_subtitle = null
	if subtitles:
		_subtitle = Label.new()
		_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_subtitle.add_theme_font_size_override("font_size", maxi(18, _viewport.size.y / 30))
		_subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
		_subtitle.add_theme_constant_override("outline_size", 6)
		_subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_subtitle.offset_top = -_viewport.size.y * 0.2
		_subtitle.offset_bottom = -_viewport.size.y * 0.12
		_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_subtitle.visible = false
		ui.add_child(_subtitle)
		player.beat.connect(_on_beat)
	player.beat.connect(_on_excuse_beat)
	player.finished.connect(_on_finished)
	said = player.said
	calls.clear()
	_pressed = false
	player.play_data(script_for(id), {}, id)
	started.emit(id)


func _on_beat(kind: String, detail: String) -> void:
	if _subtitle == null or not is_instance_valid(_subtitle):
		return
	if kind == "line":
		_subtitle.text = spoken_text(detail)
		_subtitle.visible = _subtitle.text != ""
	elif kind in ["fade", "end", "skip"]:
		_subtitle.visible = false


# --- Y-09: a different excuse every time he is asked ------------------------------------------

## Every excuse step in story order: [{excuse, line, pics, scene}], one per scene that asks
## "what happened?". The pool a rewatch draws from.
static func excuse_pool() -> Array:
	var out := []
	for sid in SCENES:
		for s in CutscenePlayer.load_scene(sid).get("steps", []):
			if s is Dictionary and s.get("do", "") == "line":
				var e := excuse_of(String(s.get("line", "")))
				if e != &"":
					out.append({"excuse": e, "line": String(s.line), "pics": s.get("pics", []), "scene": sid})
	return out


## The excuse a line gives (its `excuse` field in lines.json), or &"".
static func excuse_of(line_id: String) -> StringName:
	return StringName(str(CutscenePlayer.line(line_id).get("excuse", ""))) if line_id != "" else &""


## The excuse to tell where the script says `own`: `own` itself unless he told it among the last
## EXCUSE_FRESH, else the pool excuse told longest ago (never-told first, in story order).
func pick_excuse(own: StringName) -> StringName:
	var recent := excuses_told.slice(maxi(0, excuses_told.size() - EXCUSE_FRESH))
	if not recent.has(own):
		return own
	var best := own
	var best_at := INF
	for p in excuse_pool():
		var e: StringName = p.excuse
		if recent.has(e):
			continue
		var at := float(excuses_told.rfind(e))   # -1 when never told
		if at < best_at:
			best_at = at
			best = e
	return best


## Scene `id`'s data with each excuse line swapped for pick_excuse's (line and its pictures; the
## speaker and every other step stay). The first time through, in story order, nothing changes.
func script_for(id: StringName) -> Dictionary:
	var d := CutscenePlayer.load_scene(id).duplicate(true)
	var pool := {}
	for p in excuse_pool():
		pool[p.excuse] = p
	for s in d.get("steps", []):
		if not (s is Dictionary and s.get("do", "") == "line"):
			continue
		var own := excuse_of(String(s.get("line", "")))
		if own == &"":
			continue
		var e := pick_excuse(own)
		if e != own and pool.has(e):
			s["line"] = pool[e].line
			s["pics"] = pool[e].pics.duplicate()
	return d


func _on_excuse_beat(kind: String, detail: String) -> void:
	if kind != "line":
		return
	var e := excuse_of(detail)
	if e == &"":
		return
	excuses_told.append(e)
	if excuses_told.size() > EXCUSE_LOG:
		excuses_told = excuses_told.slice(excuses_told.size() - EXCUSE_LOG)
	if persist and _save() != null:
		_save().call("set_value", EXCUSE_KEY, excuses_told.map(func(x): return String(x)))


func _close() -> void:
	_subtitle = null
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	player = null
	dock = null


func _on_finished(id: StringName, skipped: bool) -> void:
	if not seen.has(id):
		seen.append(id)
		if persist and _save() != null:
			_save().call("set_value", SAVE_KEY, seen.map(func(s): return String(s)))
	said = player.said.duplicate() if player != null else said
	_close()
	if _locked:
		_locked = false
		input_locked.emit(false)
	finished.emit(id, skipped)
	cutscene_finished.emit(id)
	if not _queue.is_empty():
		_open(_queue.pop_front())


func _input(event: InputEvent) -> void:
	if not is_playing():
		return
	if (event is InputEventJoypadButton or event is InputEventKey or event is InputEventMouseButton) and event.is_pressed() and not event.is_echo():
		_pressed = true
		get_viewport().set_input_as_handled()


func _save() -> Node:
	return get_node_or_null(^"/root/Save") if is_inside_tree() else null


func _audio() -> Node:
	return get_node_or_null(^"/root/Audio") if is_inside_tree() else null


# --- CutscenePlayer host interface (addons/openjar/docs/cutscene-format.md) ----------------------

func cutscene_actor(n: String) -> Node2D:
	return dock.get_node_or_null(NodePath(n)) as Node2D if dock != null and n != "" else null


func cutscene_spawn(n: String, sheet: String, _scene: String, pos: Vector2) -> Node2D:
	var a := StoryActor.new()
	a.kind = sheet if sheet != "" else n
	a.position = pos
	dock.add_child(a)
	return a


func cutscene_anchor(n: String) -> Vector2:
	return dock.anchor(n) if dock != null else Vector2.INF


func cutscene_views() -> Array:
	if dock == null or _viewport == null:
		return []
	return [{"camera": dock.camera, "rect": Rect2(Vector2.ZERO, Vector2(_viewport.size))}]


func cutscene_lock(on: bool) -> void:
	if on != _locked:
		_locked = on
		input_locked.emit(on)


func cutscene_skip_pressed() -> bool:
	var p := _pressed
	_pressed = false
	return p


func cutscene_character(actor: String) -> String:
	match actor:
		"Reel", "YoungReel":
			return "old_reel"
		"Bobber":
			return "bobber"
	return ""


func cutscene_head(actor: String) -> Vector2:
	match actor:
		"Bobber":
			return Vector2(0, -26)
		"Gulp", "Burp":
			return Vector2(0, -6)
	return Vector2(0, -34)


func cutscene_anim(actor: String, anim: String) -> void:
	var a := cutscene_actor(actor)
	if a is StoryActor and actor == "Bobber":
		var st := a as StoryActor
		# Only swap walk <-> idle: a pose the scene set (asleep, arms crossed) wins.
		if anim == "walk" and st.pose == "idle":
			st.pose = "walk"
		elif anim != "walk" and st.pose == "walk":
			st.pose = "idle"


func cutscene_call(fn: String, args: Dictionary) -> void:
	calls.append([fn, args])
	if dock == null:
		if fn == "handoff":
			handoff.emit(current(), String(args.get("what", "")))
		return
	var secs := float(args.get("secs", 1.0)) / maxf(0.01, speed)
	match fn:
		"time":
			dock.set_time(String(args.get("of", "noon")), secs)
		"warm":
			dock.set_warm(bool(args.get("on", true)), secs)
		"clue":
			dock.clue(String(args.get("what", "")), float(args.get("to", 1.0)), secs)
		"hands":
			var a := cutscene_actor(String(args.get("who", "Reel")))
			if a is StoryActor:
				create_tween().tween_property(a, "hands", float(args.get("w", 0.0)), minf(secs, 0.5))
		"pose":
			var a := cutscene_actor(String(args.get("who", "")))
			if a is StoryActor:
				(a as StoryActor).pose = String(args.get("pose", "idle"))
		"shake":
			var amp := float(args.get("amp", 2.0))
			var tw := create_tween()
			for i in int(maxf(1.0, secs / 0.05)):
				tw.tween_property(dock.camera, "offset", Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.05)
			tw.tween_property(dock.camera, "offset", Vector2.ZERO, 0.05)
		"handoff":
			handoff.emit(current(), String(args.get("what", "")))
		_:
			push_warning("Story: unknown call '%s'" % fn)


func cutscene_sound(cue: String) -> void:
	var a := _audio()
	if a != null and ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % cue):
		a.call("play", cue)
		return
	_play_stream(StoryVoice.blip(cue))


func cutscene_duck(_db: float, _secs: float) -> void:
	pass   # Worm has no music under the dock yet; the Audio lane adds ducking with the dock theme.


func cutscene_bark(character: String, cue: String) -> AudioStream:
	return StoryVoice.bark_stream(character, cue)


func _play_stream(st: AudioStream) -> void:
	if st == null or player == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	player.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
