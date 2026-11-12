## The stage-up beat (S-03) on the real planet: the apex bite with enough segments plays the stage_up
## sting, the white flash, the shake, the swell and the "why" picture; the zoom cap drops to the new
## stage's data; the ring that opens (topsoil) pulses; the dock cutscene follows once per tin.
class_name TestStagesBeat
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")
const JUICE_STUB := preload("res://scripts/worm/stubs/juice_stub.gd")

var _level: PlanetLevel


func before() -> void:
	SuiteSandbox.enter("stages_beat")


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	for p in Audio._pool:
		p.stop()   # placeholder beeps still playing at exit leak their playbacks
	SuiteSandbox.leave()


func before_test() -> void:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	Audio.played.clear()
	JUICE_STUB.calls.clear()
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


func _ready_worm() -> Worm:
	var w := _level.spawn_worm(Players.P1)
	while w.model.segments.size() < w.rules.stage_segments[2]:
		w.model.add_segment(&"")
	return w


func _juice_fns() -> Array:
	return JUICE_STUB.calls.map(func(c: Array) -> String: return c[0])


func test_apex_bite_plays_the_whole_beat() -> void:
	var w := _ready_worm()
	assert_int(w.model.stage).is_equal(1)
	assert_int(_level.stage_beat.history.size()).is_equal(0)
	_level.beetle.bitten_by(w)
	assert_int(w.model.stage).is_equal(2)
	var b: Dictionary = _level.stage_beat.history[0]
	assert_int(b.to).is_equal(2)
	assert_str(String(b.cause)).is_equal("apex")
	assert_int(Audio.played.get("stage_up", 0)).is_equal(1)
	if WormHooks.juice_is_stub():
		assert_array(_juice_fns()).contains(["stage_flash", "shake", "chomp", "debris"])
	var why := _level.find_children("*", "StageWhy", true, false)
	assert_int(why.size()).is_equal(1)
	assert_str(String((why[0] as StageWhy).cause)).is_equal("apex")


func test_zoom_cap_and_opened_ring_come_from_the_stage_row() -> void:
	var w := _ready_worm()
	var d2 := StageTable.default_table().at(2)
	assert_int(_level.camera.max_fit_index).is_equal(StageTable.default_table().at(1).zoom_index)
	_level.beetle.bitten_by(w)
	assert_int(_level.camera.max_fit_index).is_equal(d2.zoom_index)
	assert_int(_level.stage_beat.history[0].zoom_cap).is_equal(d2.zoom_index)
	assert_str(String(_level.stage_beat.history[0].ring)).is_equal("topsoil")
	# topsoil starts where the dirt ends: its edge is the ring that pulses
	var dirt_outer := 0.0
	for r in _level.world.rings.rings:
		if r.id == &"dirt":
			dirt_outer = r.outer
	assert_float(_level.stage_beat._ring_radius(&"topsoil")).is_equal_approx(dirt_outer * _level.world.shape.radius * 16.0, 0.01)
	# the opened ring is food for this worm now
	assert_int(_level.world.stage_of(w.player)).is_equal(2)
	# the camera steps one whole-pixel step at a time down to the new cap
	var before := _level.camera.zoom_index
	for i in 120:
		_level.camera.step(1.0 / 60.0)
	assert_int(_level.camera.zoom_index).is_less_equal(d2.zoom_index)
	assert_int(before - _level.camera.zoom_index).is_greater_equal(1)
	assert_float(_level.camera.zoom.x).is_equal(PolarCamera.ZOOMS[_level.camera.zoom_index])


func test_segments_last_shows_the_body_as_the_reason() -> void:
	var w := _level.spawn_worm(Players.P1)
	w.model.eat_apex(1)                 # the apex first (too short to stage up yet)
	assert_int(w.model.stage).is_equal(1)
	while w.model.stage == 1:
		w.model.add_segment(&"")
	assert_str(String(_level.stage_beat.history[0].cause)).is_equal("segments")


func test_the_dock_scene_follows_once_per_tin() -> void:
	var w := _ready_worm()
	_level.stage_beat.make_story = true
	var story := Story.new()
	story.persist = false
	story.speed = 50.0
	_level.add_child(story)
	_level.beetle.bitten_by(w)
	assert_bool(story.is_playing()).is_false()       # the beat first, then the dock
	await get_tree().create_timer(StageBeat.STORY_DELAY + 0.2).timeout
	assert_bool(story.is_playing() or story.has_seen(&"stage_2")).is_true()
	assert_str(String(story.current())).is_equal("stage_2")
	story.skip()
