## W-21: each bait tin keeps its own living-ring populations, secrets found, tackle-box pages,
## cutscenes seen and jars. What one tin earns never shows up in another, and a reopened tin gets
## all of it back. (Seed, edits, worms and burrow are test_greybox_planet's round trip.)
## Runs in its own Save profile (SuiteSandbox).
class_name TestTinKeys
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")

var _level: PlanetLevel


func before() -> void:
	SuiteSandbox.enter("tin_keys")
	_remove_tins()


func after() -> void:
	_free_level()
	_remove_tins()
	Save.use_slot("")
	SuiteSandbox.leave()


func before_test() -> void:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()


func after_test() -> void:
	_free_level()
	Game.quit_exits = true
	Game._set_state(Game.State.LOBBY)
	Players.reset()
	Save.use_slot("")


func _remove_tins() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))


func _open(tin: int) -> PlanetLevel:
	BaitTins.open(tin)
	_level = PLANET.instantiate()
	add_child(_level)
	var w := _level.spawn_worm(Players.P1)
	w.autopilot = func(_w: Worm) -> Dictionary: return { "move": Vector2.ZERO }
	return _level


func _free_level() -> void:
	if is_instance_valid(_level):
		remove_child(_level)
		_level.free()
	_level = null


func _rings() -> RingsDirector:
	return _level.get_node("Rings") as RingsDirector


func _tlog() -> TackleLog:
	return _level.home_slice.tlog


## Leave the tin the way the game does: pause (saves everything), then close it.
func _close() -> void:
	Game._set_state(Game.State.PLAYING)
	Game.pause()
	Game.resume()
	Game._set_state(Game.State.LOBBY)
	_free_level()
	Save.use_slot("")


## Marks a tin with one of everything, each picked by `k` so two tins differ.
func _mark(k: int) -> Dictionary:
	var rings := _rings()
	var species: StringName = rings.ecology.counts.keys()[k]
	var before_kill := rings.ecology.count(species)
	rings.ecology.kill(species, before_kill * 0.9)
	var secret := StringName("tin_secret_%d" % k)
	rings.found[secret] = true
	var food: StringName = (_tlog().entries[&"foods"] as Array)[k]
	assert_bool(_tlog().unlock(&"foods", food)).is_true()
	var scene: StringName = Story.SCENES[k + 1]
	Save.set_value(Story.SAVE_KEY, [String(scene)])
	Save.set_value("jars", ["jar_of_tin_%d" % k])
	return { "species": species, "full": before_kill, "left": rings.ecology.count(species),
		"secret": secret, "food": food, "scene": scene, "jar": "jar_of_tin_%d" % k }


func _has(m: Dictionary) -> Dictionary:
	var rings := _rings()
	_tlog().sync_seen()
	return {
		"pop": rings.ecology.count(m.species) < m.full * 0.5,
		"secret": rings.found.has(m.secret),
		"page": _tlog().is_found(&"foods", m.food),
		"scene": (Save.get_value(Story.SAVE_KEY, []) as Array).has(String(m.scene)),
		"cutscene_page": _tlog().is_found(&"cutscenes", m.scene),
		"jar": (Save.get_value("jars", []) as Array).has(m.jar),
	}


func test_each_tin_keeps_its_own_populations_secrets_pages_cutscenes_and_jars() -> void:
	var all_true := { "pop": true, "secret": true, "page": true, "scene": true, "cutscene_page": true, "jar": true }
	var all_false := { "pop": false, "secret": false, "page": false, "scene": false, "cutscene_page": false, "jar": false }

	_open(0)
	var m0 := _mark(0)
	assert_dict(_has(m0)).is_equal(all_true)
	_close()

	# A different tin starts clean of tin 0's world and marks its own.
	_open(1)
	assert_dict(_has(m0)).is_equal(all_false)
	var m1 := _mark(1)
	_close()

	# Reopening each tin brings back exactly its own.
	_open(0)
	assert_dict(_has(m0)).is_equal(all_true)
	var m1_in_0 := _has(m1)
	assert_bool(m1_in_0.secret or m1_in_0.page or m1_in_0.scene or m1_in_0.jar).is_false()
	_close()

	_open(1)
	assert_dict(_has(m1)).is_equal(all_true)
	var m0_in_1 := _has(m0)
	assert_bool(m0_in_1.secret or m0_in_1.page or m0_in_1.scene or m0_in_1.jar).is_false()
	_close()
