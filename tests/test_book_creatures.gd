## T-01 / T-03 / L-03: the creatures page of Old Reel's tackle box holds every creature a worm can
## meet, and every sketch on it can be found. The ring apexes (ApexBeetle) have their own pages
## (data/apexes/*.tres) that match the apexes the planet makes, met when one comes near or is eaten;
## the Mole has its page (data/jarlings/mole.tres); the pets the book draws (glowworm, ant crew) can
## be met. The tackle log and the book read the same list. Own Save profile (SuiteSandbox).
class_name TestBookCreatures
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")

var _level: PlanetLevel
var _unlocked: Array[StringName] = []


func before() -> void:
	SuiteSandbox.enter("book_creatures")


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	SuiteSandbox.leave()


func before_test() -> void:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	Audio.played.clear()
	_unlocked.clear()


func after_test() -> void:
	_free_level()
	get_tree().paused = false
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _open(fresh := true) -> PlanetLevel:
	BaitTins.open(0)
	if fresh:
		Save.wipe()
		Save.set_value("seed", 4)
	_level = PLANET.instantiate()
	add_child(_level)
	_level.home_slice.box.pause_tree = false
	_log().unlocked.connect(func(page: StringName, id: StringName) -> void:
		if page == &"creatures":
			_unlocked.append(id))
	return _level


func _free_level() -> void:
	for p in Audio._pool:
		p.stop()
	if is_instance_valid(_level):
		for n in _level.find_children("*", "AudioStreamPlayer", true, false):
			n.stop()
		remove_child(_level)
		_level.free()
	_level = null


func _log() -> TackleLog:
	return _level.home_slice.tlog


func _worm(stage: int) -> Worm:
	var w := _level.spawn_worm(Players.P1, null, stage)
	w.autopilot = func(_w: Worm) -> Dictionary: return { "move": Vector2.ZERO }
	return w


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _apex(look: StringName) -> ApexBeetle:
	for a in _level.apexes:
		if a.look == look:
			return a
	return null


func _book_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for e in BookCatalog.entries(&"creatures"):
		out.append(e.id)
	return out


func test_every_apex_the_planet_makes_has_its_own_page() -> void:
	_open()
	var files: Array = Array(BookCatalog.files(&"creatures")).filter(func(p: String) -> bool: return p.begins_with("res://data/apexes/"))
	assert_int(_level.apexes.size()).is_equal(5)
	assert_int(files.size()).is_equal(_level.apexes.size())   # no page for an apex that isn't there
	var ids := {}
	for a in _level.apexes:
		var path := "res://data/apexes/%s.tres" % a.id
		assert_bool(ResourceLoader.exists(path)).override_failure_message("no page for %s" % a.id).is_true()
		var d := load(path) as CreatureData
		assert_object(d).is_not_null()
		assert_str(String(d.id)).is_equal(String(a.id))
		assert_int(d.size_stage).is_equal(a.size_stage)
		assert_float(d.radius).is_equal_approx(a.radius, 0.01)
		assert_bool(d.jarling).is_false()
		# The sketch wears the apex's own threat colour, so the page looks like the thing you met.
		var shell := ApexBeetle.shell_color(a.look, false)
		assert_float(d.color.r).is_equal_approx(shell.r, 0.01)
		assert_float(d.color.g).is_equal_approx(shell.g, 0.01)
		assert_float(d.color.b).is_equal_approx(shell.b, 0.01)
		ids[a.id] = true
	assert_int(ids.size()).is_equal(5)   # five different pages, one per ring apex


func test_the_log_and_the_book_list_the_same_creatures() -> void:
	_open()
	var book := _book_ids()
	var log_list: Array = _log().entries[&"creatures"]
	for id in book:
		assert_bool(log_list.has(id)).override_failure_message("book sketch %s can never be found" % id).is_true()
	for id in log_list:
		assert_bool(book.has(id)).override_failure_message("log entry %s has no sketch" % id).is_true()
	for id in [&"mole", &"glowworm", &"ant_crew", &"ladybird", &"apex_topsoil", &"apex_ember"]:
		assert_bool(book.has(id)).override_failure_message("%s missing from the page" % id).is_true()


func test_the_mole_is_a_friend_page_not_a_ring_creature() -> void:
	var d := load("res://data/jarlings/mole.tres") as CreatureData
	assert_str(String(d.id)).is_equal("mole")
	assert_bool(d.jarling).is_true()
	# No ring life spawns it: it lives outside data/creatures/, which the ring and kid checks sweep.
	assert_bool(ResourceLoader.exists("res://data/creatures/mole.tres")).is_false()


func test_pets_the_book_draws_can_be_met() -> void:
	_open()
	for id in [&"glowworm", &"ant_crew"]:
		assert_bool(_log().is_found(&"creatures", id)).is_false()
		assert_bool(_log().meet(id)).is_true()
		assert_bool(BookCatalog.found_set(get_tree())[&"creatures"].has(id)).is_true()
	assert_array(_unlocked).contains_exactly([&"glowworm", &"ant_crew"])


func test_meeting_a_ring_apex_unlocks_its_own_page_with_a_sound() -> void:
	_open()
	var w := _worm(2)
	var a := _apex(&"topsoil")
	var pages0: int = Audio.played.get("page_new", 0)
	a.position = w.cam_position() + Vector2(TackleLog.MEET_PX * 0.5, 0)
	await _frames(20)
	assert_bool(_log().is_found(&"creatures", &"apex_topsoil")).is_true()
	assert_int(_unlocked.count(&"apex_topsoil")).is_equal(1)
	assert_bool(_log().is_found(&"creatures", &"beetle")).is_false()   # not the ring beetle's page
	assert_int(Audio.played.get("page_new", 0)).is_greater(pages0)


func test_eating_an_apex_unlocks_its_page_once() -> void:
	_open()
	var w := _worm(6)
	var a := _apex(&"ember")   # deep in the core, far from the spawn: not met on the way
	assert_float(a.global_position.distance_to(w.head.global_position)).is_greater(TackleLog.MEET_PX * 2.0)
	assert_bool(a.is_food_for(w)).is_true()
	a.bitten_by(w)
	assert_bool(a.is_gone()).is_true()
	assert_bool(_log().is_found(&"creatures", &"apex_ember")).is_true()
	a.bitten_by(w)   # already gone: nothing more
	assert_int(_unlocked.count(&"apex_ember")).is_equal(1)


func test_an_apex_eaten_before_its_page_existed_is_found_on_load() -> void:
	_open()
	var w := _worm(6)
	var a := _apex(&"pillbug")
	a.bitten_by(w)
	_level.save_now()
	# An older tin: the apex is gone but its log never had the page (strip it from the saved log).
	var tin: Dictionary = Save.get_value(BookCatalog.TIN_KEY, {})
	var found: Dictionary = tin[BookCatalog.LOG_KEY]["found"]
	found["creatures"] = (found.get("creatures", []) as Array).filter(func(id) -> bool: return String(id) != "apex_pillbug")
	Save.set_value(BookCatalog.TIN_KEY, tin)
	_free_level()
	_open(false)
	assert_bool(_apex(&"pillbug").is_gone()).is_true()
	assert_bool(_log().is_found(&"creatures", &"apex_pillbug")).is_false()
	_worm(2)
	await _frames(20)   # the log's meet scan runs every 0.25 s while a worm is out
	assert_bool(_log().is_found(&"creatures", &"apex_pillbug")).is_true()


func test_a_ring_creature_seen_but_not_eaten_is_met() -> void:
	_open()
	var w := _worm(1)
	# Staged: a ring creature bigger than the worm, held still beside its head (not a live pile).
	var c := Creature.new()
	c.data = load("res://data/creatures/bird.tres")
	c.set_physics_process(false)
	c.set_process(false)
	_level.actors.add_child(c)
	c.set_physics_process(false)
	c.set_process(false)
	c.global_position = w.head.global_position + Vector2(TackleLog.MEET_PX * 0.5, 0)
	assert_bool(c.is_in_group(&"creatures")).is_true()
	assert_bool(_log().is_found(&"creatures", &"bird")).is_false()
	await _frames(20)
	assert_int(_unlocked.count(&"bird")).is_equal(1)
	assert_bool(_log().is_found(&"foods", &"bird")).is_false()   # met, not eaten
