## Regrowth on the planet clock (simulated, never wall time), castings speed-up, gardens, the
## Strangestone seam, edibility by stage, and the edits-only save round trip.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const DIRT := Vector2i(100, 7)    # radius ~100 of 160: the dirt ring (0.45..0.82)
const DIRT2 := Vector2i(100, 15)


func _world() -> PolarWorld:
	var w := PolarWorld.new()
	w.setup_planet(RINGS, 160, 7)
	add_child(w)
	w.set_physics_process(false)
	var anchor := Node2D.new()  # keeps chunks live; not an eater, so it never blocks regrowth
	anchor.position = w.shape.center_of(DIRT)
	add_child(anchor)
	auto_free(anchor)
	w.track(anchor)
	w.update_chunks(-1)
	return auto_free(w)


func _run(w: PolarWorld, seconds: float) -> void:
	var dt := 0.5
	for i in int(round(seconds / dt)):
		w.advance(dt)
	w.regrow_pass(-1)


func test_eaten_dirt_regrows_on_the_simulated_clock() -> void:
	var w := _world()
	assert_str(String(w.ring_of(DIRT).id)).is_equal("dirt")
	var base := w.get_tile(DIRT)
	assert_bool(w.eat_tile(DIRT, 0)).is_true()
	assert_int(w.get_tile(DIRT)).is_equal(0)
	assert_float(w.eaten_at(DIRT)).is_equal(0.0)
	var t := w.regrow_time(DIRT)
	assert_float(t).is_equal_approx(RINGS.rings[2].regrow_time * RINGS.castings_factor, 0.001)
	var regrown := []
	w.tile_regrown.connect(func(c: Vector2i, _b: StringName) -> void: regrown.append(c))
	_run(w, t - 1.0)
	assert_int(w.get_tile(DIRT)).is_equal(0)
	_run(w, 1.5)
	assert_int(w.get_tile(DIRT)).is_equal(base)
	assert_array(regrown).contains([DIRT])
	assert_bool(w.edits.tiles.has(DIRT)).is_false()  # back to base: no edit left
	assert_bool(w.has_castings(DIRT)).is_true()       # the soil stays rich


func test_castings_regrow_faster_than_plain_digging() -> void:
	var w := _world()
	w.eat_tile(DIRT, 0)                        # a worm: castings
	w.dig(DIRT2, [Vector2i.ZERO], -1)          # something else dug it: no castings
	assert_bool(w.has_castings(DIRT)).is_true()
	assert_bool(w.has_castings(DIRT2)).is_false()
	var fast := w.regrow_time(DIRT)
	var slow := w.regrow_time(DIRT2)
	assert_float(fast).is_equal_approx(slow * RINGS.castings_factor, 0.001)
	_run(w, fast + 1.0)
	assert_bool(w.is_solid(DIRT)).is_true()
	assert_bool(w.is_solid(DIRT2)).is_false()
	_run(w, slow - fast)
	assert_bool(w.is_solid(DIRT2)).is_true()


func test_regrowth_never_fills_next_to_an_eater() -> void:
	var w := _world()
	var eater := Node2D.new()
	eater.position = w.shape.center_of(DIRT)
	add_child(eater)
	auto_free(eater)
	w.track_eater(eater)
	w.eat_tile(DIRT, 0)
	_run(w, 1000.0)
	assert_int(w.get_tile(DIRT)).is_equal(0)
	eater.position = w.shape.center_of(DIRT + Vector2i(0, 20))
	_run(w, 1.0)
	assert_bool(w.is_solid(DIRT)).is_true()


func test_strangestone_is_never_eaten() -> void:
	var w := _world()
	var core := Node2D.new()
	add_child(core)
	auto_free(core)
	w.track(core)
	w.update_chunks(-1)
	w.set_stage(0, 99)
	assert_str(String(w.tile_def(w.get_tile(Vector2i.ZERO)).id)).is_equal("strangestone")
	assert_bool(w.is_edible_by(99, Vector2i.ZERO)).is_false()
	assert_bool(w.is_edible_by(99, &"strangestone")).is_false()
	assert_bool(w.eat_tile(Vector2i.ZERO, 0)).is_false()
	w.eat_circle(Vector2.ZERO, 8 * 16.0, 0)
	for c in [Vector2i(0, 0), Vector2i(-1, -1), Vector2i(2, 0), Vector2i(-5, 0)]:
		assert_str(String(w.tile_def(w.get_tile(c)).id)).is_equal("strangestone")
	assert_float(w.regrow_time(Vector2i.ZERO)).is_equal(INF)


func test_edible_by_stage() -> void:
	var w := _world()
	var rock := Vector2i(40, 3)  # deep rock, from stage 4
	assert_bool(w.is_edible_by(1, DIRT)).is_true()
	assert_bool(w.is_edible_by(1, rock)).is_false()
	assert_bool(w.is_edible_by(4, rock)).is_true()
	w.set_stage(0, 1)
	var blocked := []
	w.dig_blocked.connect(func(c: Vector2i, _b: StringName, _p: int) -> void: blocked.append(c))
	assert_bool(w.eat_tile(rock, 0)).is_false()
	assert_array(blocked).contains([rock])
	# Objects go through the shared StageRule: bigger eats smaller.
	var small := _Sized.new(2)
	var big := _Sized.new(5)
	assert_bool(w.is_edible_by(3, small)).is_true()
	assert_bool(w.is_edible_by(3, big)).is_false()
	assert_bool(w.is_edible_by(2, small)).is_false()


class _Sized:
	extends RefCounted
	var size_stage := 0
	func _init(s: int) -> void:
		size_stage = s


func test_garden_grows_in_castings_and_keeps_growing() -> void:
	var w := _world()
	assert_bool(w.plant_seed(DIRT, &"root")).is_false()  # solid, no castings
	for x in range(95, 106):
		w.eat_tile(Vector2i(x, 7), 0)
	var plain := Vector2i(100, 12)
	w.dig(plain, [Vector2i.ZERO], -1)
	assert_bool(w.plant_seed(plain, &"root")).is_false()  # open but no castings
	var planted := []
	w.garden_planted.connect(func(c: Vector2i, f: StringName) -> void: planted.append([c, f]))
	assert_bool(w.plant_seed(DIRT, &"root")).is_true()
	assert_array(planted).is_equal([[DIRT, &"root"]])
	var garden_tile := w.id_of(&"garden_root")
	assert_int(w.get_tile(DIRT)).is_equal(garden_tile)
	_run(w, RINGS.garden_interval * 4.0 + 0.1)
	var cells := w.garden_cells(0)
	assert_int(cells.size()).is_equal(5)
	for c in cells:
		assert_bool(w.has_castings(c)).is_true()
		assert_int(w.get_tile(c)).is_equal(garden_tile)
	# Eaten garden food comes back as garden, not as dirt, and the patch keeps spreading.
	w.eat_tile(cells[1], 0)
	_run(w, RINGS.garden_interval + 0.1)
	assert_int(w.get_tile(cells[1])).is_equal(garden_tile)
	_run(w, RINGS.garden_interval * 3.0)
	assert_int(w.garden_cells(0).size()).is_greater(5)


func test_save_holds_only_edits_and_round_trips() -> void:
	var w := _world()
	var fresh := w.to_save()
	assert_array(fresh.edits).is_empty()
	assert_array(fresh.castings).is_empty()
	assert_array(fresh.times).is_empty()
	for x in range(96, 105):
		w.eat_tile(Vector2i(x, 7), 0)
	w.dig(DIRT2, [Vector2i.ZERO], -1)
	w.plant_seed(DIRT, &"crystal")
	_run(w, 9.0)
	var data := w.to_save()
	assert_int(data.edits.size() / 3).is_equal(w.edits.tiles.size())
	var json := JSON.stringify(data)
	var w2 := PolarWorld.new()
	w2.setup_planet(RINGS, 160, 7)
	add_child(w2)
	auto_free(w2)
	w2.set_physics_process(false)
	w2.load_save(JSON.parse_string(json))
	assert_float(w2.clock).is_equal_approx(w.clock, 0.001)
	assert_dict(w2.edits.tiles).is_equal(w.edits.tiles)
	assert_int(w2.castings_count()).is_equal(w.castings_count())
	for x in range(96, 105):
		var c := Vector2i(x, 7)
		assert_bool(w2.has_castings(c)).is_true()
		assert_float(w2.eaten_at(c)).is_equal_approx(w.eaten_at(c), 0.051)
	assert_float(w2.eaten_at(DIRT2)).is_equal_approx(w.eaten_at(DIRT2), 0.051)
	assert_int(w2.gardens().size()).is_equal(1)
	assert_int(w2.garden_cells(0).size()).is_equal(w.garden_cells(0).size())
	assert_int(w2.get_tile(DIRT)).is_equal(w.id_of(&"garden_crystal"))
