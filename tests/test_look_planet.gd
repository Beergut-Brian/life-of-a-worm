## Look B on the real planet (A-02, A-04, A-14): ambient darkness per ring from data, the lantern on
## the worm's head, sprites on food, a daylight shaft through a hole eaten in the crust (closed again
## when it grows back), the day tinting the topsoil but not the deep dirt, rain soaking in and
## drying, and a bite sending crumbs. Own Save profile (SuiteSandbox).
class_name TestLookPlanet
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")

var _level: PlanetLevel


func before() -> void:
	SuiteSandbox.enter("look")


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	SuiteSandbox.leave()


func before_test() -> void:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	BaitTins.open(0)
	Save.wipe()
	_level = PLANET.instantiate()
	_level.auto_spawn_demo = false
	add_child(_level)


func after_test() -> void:
	if is_instance_valid(_level):
		remove_child(_level)
		_level.free()
	_level = null
	Juice.host = null
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _look() -> LookDirector:
	return _level.get_node("Look") as LookDirector


func test_planet_is_lit_with_lanterns_and_sprites() -> void:
	var w := _level.spawn_worm(Players.P1)
	await get_tree().process_frame
	var look := _look()
	look._scan()
	assert_object(_level.world.tile_art).is_instanceof(RingTileArt)
	assert_object(look.modulate_node).is_not_null()
	assert_object(w.head.get_node_or_null("Lantern")).is_instanceof(PointLight2D)
	var faced := 0
	for n in get_tree().get_nodes_in_group(&"food"):
		if _level.is_ancestor_of(n) and n.get_meta(&"face_sprite", null) != null:
			faced += 1
	assert_int(faced).is_greater(0)
	assert_int(look.light_counts().lanterns).is_equal(1)


func test_rings_get_darker_with_depth_and_only_the_top_sees_the_day() -> void:
	var look := _look()
	var R := look.surface_px
	look.fixed_phase = 0.3
	look._update(0.0, true)
	var top_day := look.ambient_at(R * 0.97).get_luminance()
	var dirt_day := look.ambient_at(R * 0.6).get_luminance()
	assert_float(top_day).is_greater(dirt_day + 0.3)
	look.fixed_phase = 0.8
	look._update(0.0, true)
	var top_night := look.ambient_at(R * 0.97).get_luminance()
	var dirt_night := look.ambient_at(R * 0.6).get_luminance()
	assert_float(top_night).is_less(top_day - 0.2)
	assert_float(absf(dirt_night - dirt_day)).is_less(0.15)
	assert_float(dirt_night).is_greater(0.12)  # never black


func test_a_hole_through_the_crust_lets_daylight_in_until_it_grows_back() -> void:
	var look := _look()
	var world := _level.world
	world.set_stage(9, 9)
	var up := Vector2.from_angle(-PI / 2.0 + 0.3)
	var cells: Array[Vector2i] = []
	var r := look.crust_px - 40.0
	while r < look.surface_px + 16.0:
		var p := up * r
		var c := world.shape.cell_at(p)
		if world.shape.contains(c) and world.is_solid(c):
			world.eat_tile(c, 9)
			cells.append(c)
		r += 8.0
	assert_int(look.shafts.size()).is_equal(1)
	var top: Vector2i = cells[cells.size() - 1]
	world._regrow(top)
	await get_tree().process_frame
	assert_int(look.shafts.size()).is_equal(0)


func test_rain_soaks_in_and_dries() -> void:
	var look := _look()
	look.rings_director.set(&"raining", true)
	for i in 30:
		look._update(1.0)
	assert_float(look.wetness).is_greater(0.9)
	look.rings_director.set(&"raining", false)
	for i in 70:
		look._update(1.0)
	assert_float(look.wetness).is_equal(0.0)


func test_a_bite_sends_crumbs_in_the_food_colour() -> void:
	var w := _level.spawn_worm(Players.P1)
	await get_tree().process_frame
	_look()._scan()
	var before := Juice.chomps
	w.ate.emit(Players.P1, &"seed", 1.0)
	assert_int(Juice.chomps).is_equal(before + 1)
