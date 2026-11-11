## Old Reel's tackle box (feature/slice-burrow-1): pages unlock from signals (food eaten, creature
## met, trait earned, secret_found from any node, cutscenes seen and finished); a completed page
## emits page_completed once and pins a lure; Y opens the box (the game waits), the stick turns
## pages, A on a seen cutscene plays it again, B shuts it; the log is saved in the tin.
class_name TestTackleBox
extends GdUnitTestSuite

const SUITE := "tackle"
const PLANET := preload("res://scenes/levels/planet.tscn")

var _level: PlanetLevel
var _intent := {}


func before() -> void:
	SuiteSandbox.enter(SUITE)


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	SuiteSandbox.leave()


func before_test() -> void:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	_intent = {}
	Audio.played.clear()


func after_test() -> void:
	_free_level()
	get_tree().paused = false
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _open(tin: int, fresh := true) -> PlanetLevel:
	BaitTins.open(tin)
	if fresh:
		Save.wipe()
	_level = PLANET.instantiate()
	add_child(_level)
	_level.home_slice.box.pause_tree = false
	return _level


func _free_level() -> void:
	# Stop every sound first: a placeholder beep freed mid-play leaks its playback at exit.
	for p in Audio._pool:
		p.stop()
	if is_instance_valid(_level):
		for n in _level.find_children("*", "AudioStreamPlayer", true, false):
			n.stop()
		remove_child(_level)
		_level.free()
	_level = null


func _p1() -> Worm:
	var w := _level.spawn_worm(Players.P1)
	w.autopilot = func(_w: Worm) -> Dictionary: return _intent
	return w


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Digs a round room at `at` (world px).
func _hollow(at: Vector2, r := 40.0) -> void:
	var c := _level.world.shape.cell_at(at)
	var n := ceili(r / 16.0) + 1
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			var cell := c + Vector2i(x, y)
			if _level.world.shape.center_of(cell).distance_to(at) <= r:
				_level.world.dig(cell)


class SecretSpot extends Node2D:
	signal secret_found(id: StringName)


func _log() -> TackleLog:
	return _level.home_slice.tlog


func test_eating_a_food_unlocks_its_sketch() -> void:
	_open(0)
	var w := _p1()
	assert_bool(_log().is_found(&"foods", &"grub")).is_false()
	w.feed(load("res://data/foods/grub.tres"))
	assert_bool(_log().is_found(&"foods", &"grub")).is_true()
	assert_int(_log().fresh).is_equal(1)
	assert_int(Audio.played.get("page_new", 0)).is_equal(1)
	w.feed(load("res://data/foods/grub.tres"))
	assert_int(_log().fresh).is_equal(1)   # once


func test_meeting_a_creature_unlocks_it() -> void:
	_open(0)
	var w := _p1()
	_level.beetle.position = w.cam_position() + Vector2(TackleLog.MEET_PX * 0.5, 0)
	await _frames(20)
	assert_bool(_log().is_found(&"creatures", &"beetle")).is_true()


func test_earning_a_trait_unlocks_it() -> void:
	_open(0)
	var w := _p1()
	w.model.start_at_stage(2)
	w.model.grant(&"wriggle")
	await _frames(1)
	assert_bool(_log().is_found(&"traits", &"wriggle")).is_true()


func test_secret_found_from_any_node_unlocks_a_secret() -> void:
	_open(0)
	var spot := SecretSpot.new()
	_level.add_child(spot)
	await _frames(1)
	spot.secret_found.emit(&"ant_city")
	assert_bool(_log().is_found(&"secrets", &"ant_city")).is_true()
	spot.secret_found.emit(&"sunken_rowboat")   # one the page didn't know: added and unlocked
	assert_bool(_log().is_found(&"secrets", &"sunken_rowboat")).is_true()
	assert_bool((_log().entries[&"secrets"] as Array).has(&"sunken_rowboat")).is_true()


func test_cutscenes_seen_come_from_the_story_node() -> void:
	_open(0)
	var story := Story.new()
	story.persist = false
	story.seen.append(&"opening")
	_level.add_child(story)
	await _frames(2)
	assert_bool(_log().is_found(&"cutscenes", &"opening")).is_true()
	story.cutscene_finished.emit(&"stage_2")
	assert_bool(_log().is_found(&"cutscenes", &"stage_2")).is_true()


func test_a_completed_page_pins_a_lure_once() -> void:
	_open(0)
	var got := []
	_log().page_completed.connect(func(id: StringName) -> void: got.append(id))
	for id in _log().entries[&"traits"]:
		assert_bool(_log().is_complete(&"traits")).is_false()
		_log().unlock(&"traits", id)
	assert_bool(_log().is_complete(&"traits")).is_true()
	assert_array(got).is_equal([&"traits"])
	assert_array(_log().lures).is_equal([&"traits"])
	assert_int(Audio.played.get("lure_pin", 0)).is_equal(1)
	_log().unlock(&"traits", _log().entries[&"traits"][0])
	assert_array(got).is_equal([&"traits"])


func test_y_opens_the_box_and_the_game_waits() -> void:
	_open(0)
	var w := _p1()
	var box := _level.home_slice.box
	box.pause_tree = true
	w.tackle_pressed.emit(Players.P1)
	assert_bool(box.is_open).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_int(Audio.played.get("box_open", 0)).is_equal(1)
	box.nav(0, 1)
	assert_str(String(box.page_id())).is_equal("creatures")
	assert_int(Audio.played.get("box_flip", 0)).is_equal(1)
	box.nav(1, 0)
	assert_int(box.cursor).is_equal(1)
	box.close()
	assert_bool(get_tree().paused).is_false()
	assert_int(Audio.played.get("box_close", 0)).is_equal(1)


func test_a_seen_cutscene_can_be_watched_again() -> void:
	_open(0)
	_p1()
	var box := _level.home_slice.box
	_log().unlock(&"cutscenes", &"stage_2")
	var asked := []
	box.rewatch.connect(func(id: StringName) -> void: asked.append(id))
	box.open(Players.P1)
	box.page = TackleLog.PAGES.find(&"cutscenes")
	box.cursor = (_log().entries[&"cutscenes"] as Array).find(&"opening")
	box.confirm()   # not seen yet: a wiggle, no film
	assert_array(asked).is_empty()
	assert_bool(box.is_open).is_true()
	box.cursor = (_log().entries[&"cutscenes"] as Array).find(&"stage_2")
	box.confirm()
	assert_array(asked).is_equal([&"stage_2"])
	assert_bool(box.is_open).is_false()
	var story := Story.find(get_tree())
	assert_object(story).is_not_null()
	assert_str(String(story.current())).is_equal("stage_2")
	story.skip()
	await _frames(5)
	assert_bool(story.is_playing()).is_false()


func test_the_log_is_saved_in_the_tin() -> void:
	_open(0)
	_p1()
	_log().unlock(&"foods", &"pebble")
	_log().note_secret(&"ant_city")
	for id in _log().entries[&"secrets"]:
		_log().note_secret(id)
	_level.save_now()
	_free_level()
	Save.use_slot("")
	_open(0, false)
	assert_bool(_log().is_found(&"foods", &"pebble")).is_true()
	assert_bool(_log().is_found(&"secrets", &"ant_city")).is_true()
	assert_array(_log().lures).contains([&"secrets"])
