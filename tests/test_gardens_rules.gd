## Gardens and castings in the living rings: a carried seed dropped in castings plants a patch of its
## flavour that keeps growing (one seed per slice flavour: root, bug, stone); food regrows faster in
## castings, twice as fast again with Green thumb; garden bites give growth in the garden's flavour
## (twice with Green thumb); rain makes gardens grow faster. Real PolarWorld, planet clock only.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const RADIUS := 160
const SLICE_FLAVOURS: Array[StringName] = [&"root", &"bug", &"stone"]

var _world: PolarWorld
var _dir: RingsDirector
var _worm: Worm


func before_test() -> void:
	Audio.played.clear()
	_world = PolarWorld.new()
	_world.build_overview = false
	_world.setup_planet(RINGS, RADIUS, 7)
	add_child(_world)
	_world.set_physics_process(false)
	var start := Vector2.from_angle(-PI / 2.0) * RADIUS * 16.0 * 0.76
	_worm = WORM.instantiate()
	_worm.player = Players.P1
	_worm.model = WormGrowth.new()
	_worm.set_meta("start_pos", start + Vector2(0, 200))
	_worm.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(_worm)
	_worm.set_physics_process(false)
	_world.track(_worm.head)
	_world.update_chunks(-1)
	_dir = RingsDirector.new()
	_dir.auto_tick = false
	add_child(_dir)
	_dir.setup(_world, start, 7, {})
	_dir.hook_worm(_worm)


func after_test() -> void:
	for n in [_dir, _worm, _world]:
		if is_instance_valid(n):
			remove_child(n)
			n.free()


## A tunnel of castings the worm ate: cells along +x from the start, away from the worm.
func _tunnel(len := 8) -> Vector2i:
	var c := _world.shape.cell_at(_dir.spawn_point)
	for x in len:
		_world.eat_tile(c - Vector2i(x, 0), Players.P1)
	return c


func _advance(seconds: float) -> void:
	for i in int(seconds * 2.0):
		_world.advance(0.5)
	_world.regrow_pass(-1)


func test_one_seed_per_slice_flavour() -> void:
	var seeds := {}
	for f in DirAccess.get_files_at("res://data/foods"):
		if f.ends_with(".tres"):
			var food = load("res://data/foods/" + f)
			if food is RingFood and food.plants != &"":
				seeds[food.plants] = food.id
	for flavour in SLICE_FLAVOURS:
		assert_bool(seeds.has(flavour)).override_failure_message("no seed plants %s" % flavour).is_true()
		assert_bool(RINGS.garden_tiles.has(flavour)).is_true()


func test_seed_dropped_in_castings_grows_a_patch_that_keeps_growing() -> void:
	var c := _tunnel(10)
	var seed := _dir.add_static(load("res://data/foods/seed.tres"), _world.shape.center_of(c - Vector2i(2, 0)))
	# the worm let go of it there (Worm.dropped): within reach of its mouth
	_worm.head.global_position = seed.global_position - Vector2(10, 0)
	_worm.dropped.emit(Players.P1, &"seed")
	assert_int(_world.gardens().size()).is_equal(1)
	assert_str(String(_world.gardens()[0].flavour)).is_equal("root")
	assert_bool(seed.is_available()).is_false()
	_worm.head.global_position = _dir.spawn_point + Vector2(0, 600)   # out of the way
	_advance(12.0)
	var n1 := _world.garden_cells(0).size()
	_advance(20.0)
	var n2 := _world.garden_cells(0).size()
	assert_int(n1).is_greater(1)
	assert_int(n2).is_greater(n1)


func test_a_seed_dropped_in_plain_dirt_does_nothing() -> void:
	var at := _dir.spawn_point + Vector2(-400, 0)
	var seed := _dir.add_static(load("res://data/foods/seed.tres"), at)
	_worm.head.global_position = at - Vector2(10, 0)
	_worm.dropped.emit(Players.P1, &"seed")
	assert_int(_world.gardens().size()).is_equal(0)
	assert_bool(seed.is_available()).is_true()


func test_castings_regrow_faster_and_green_thumb_doubles_it() -> void:
	var c := _tunnel(2)
	var plain := _world.regrow_time(c + Vector2i(0, 5))
	var cast := _world.regrow_time(c)
	assert_float(cast).is_less(plain)
	_worm.model.start_at_stage(2)
	_worm.model.grant(&"green_thumb")
	assert_bool(_worm.model.is_active(&"green_thumb")).is_true()
	_dir.tick()
	assert_float(_dir.castings_speed).is_equal(2.0)
	assert_float(_world.regrow_time(c)).is_equal_approx(cast / 2.0, 0.01)
	# and it really comes back sooner on the planet clock
	_worm.head.global_position = _dir.spawn_point + Vector2(0, 600)
	_advance(cast / 2.0 + 2.0)
	assert_bool(_world.is_solid(c)).is_true()


func test_garden_bites_give_their_flavour_and_green_thumb_doubles_it() -> void:
	var c := _tunnel(3)
	assert_bool(_dir.plant_at(_world.shape.center_of(c), &"bug")).is_true()
	var cell: Vector2i = _world.gardens()[0].cell
	var g0 := _worm.model.growth
	_world.eat_tile(cell, Players.P1)
	var plain_gain := _worm.model.growth - g0
	assert_float(plain_gain).is_greater(RingsDirector.GARDEN_BONUS * 0.9)
	assert_float(float(_worm.model.pending.get(&"bug", 0.0))).is_greater(0.0)
	_worm.model.start_at_stage(2)
	_worm.model.grant(&"green_thumb")
	_world.set_tile(cell, _world.id_of(&"garden_bug"))
	var g1 := _worm.model.growth
	_world.eat_tile(cell, Players.P1)
	assert_float(_worm.model.growth - g1).is_greater(plain_gain + RingsDirector.GARDEN_BONUS * 0.9)


func test_rain_makes_gardens_grow_faster() -> void:
	var c := _tunnel(12)
	_worm.head.global_position = _dir.spawn_point + Vector2(0, 600)
	_dir.plant_at(_world.shape.center_of(c - Vector2i(3, 0)), &"stone")
	_dir.tick()
	assert_bool(_dir.raining).is_false()
	_advance(16.0)
	var dry := _world.garden_cells(0).size()
	_dir._rain_t = RingsDirector.RAIN_EVERY - RingsDirector.RAIN_LONG + 1.0
	_dir._last_clock = _world.clock
	_dir.tick()
	assert_bool(_dir.raining).is_true()
	assert_float(_world.garden_speed).is_equal(RingsDirector.RAIN_GARDEN)
	_advance(16.0)
	var wet := _world.garden_cells(0).size() - dry
	print("rings: garden cells dry %d (incl. sprout), rain added %d" % [dry, wet])
	assert_int(wet).is_greater(dry - 1)
