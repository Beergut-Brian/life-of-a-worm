## The planet scene hosts the living rings (scenes/levels/planet.tscn node "Rings"): it hooks itself
## to the level's world, and its counters and found secrets go into the bait tin and come back.
## Runs in its own Save profile (SuiteSandbox).
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")


func before() -> void:
	SuiteSandbox.enter("rings")


func after() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(2))))
	Save.use_slot("")
	SuiteSandbox.leave()


func before_test() -> void:
	Game.demo = false
	Players.reset()


func test_planet_scene_hosts_the_rings_and_saves_them() -> void:
	BaitTins.open(2)
	Save.wipe()
	var level: PlanetLevel = PLANET.instantiate()
	add_child(level)
	var rings: RingsDirector = level.get_node("Rings")
	assert_object(rings.world).is_same(level.world)
	assert_object(rings.ecology).is_not_null()
	rings.ecology.counts[&"grub"] = 77.0
	rings.found[&"ant_city"] = true
	rings._store()
	level.save_now()
	remove_child(level)
	level.free()
	BaitTins.open(2)
	level = PLANET.instantiate()
	add_child(level)
	rings = level.get_node("Rings")
	assert_float(rings.ecology.count(&"grub")).is_equal_approx(77.0, 0.01)
	assert_bool(rings.found.has(&"ant_city")).is_true()
	remove_child(level)
	level.free()
