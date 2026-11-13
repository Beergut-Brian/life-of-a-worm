## W-20 on the real RingsDirector: one hand-tuned disk layout, and the tin's one seed varies only
## its details. The same seed rebuilds the same planet (tiles, scattered foods, hidden places); a
## different seed moves the sprinkle and the scattered foods but every ring keeps its boundary and
## its hidden-place slot, at the same spot.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const RADIUS := 300
const START := 0.76

var _made: Array[Node] = []


func after_test() -> void:
	for n in _made:
		if is_instance_valid(n):
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.free()
	_made.clear()


func _planet(seed_value: int) -> RingsDirector:
	var world := PolarWorld.new()
	world.build_overview = false
	world.setup_planet(RINGS, RADIUS, seed_value)
	add_child(world)
	world.set_physics_process(false)
	var dir := RingsDirector.new()
	dir.auto_tick = false
	add_child(dir)
	_made.append(dir)
	_made.append(world)
	dir.setup(world, Vector2.from_angle(-PI / 2.0) * RADIUS * 16.0 * START, seed_value, {})
	return dir


func _gen(seed_value: int) -> DiskGenerator:
	var g := DiskGenerator.new(RINGS)
	g.setup(DiskShape.new(RADIUS, 32), seed_value)
	return g


func _cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(-RADIUS, RADIUS, 7):
		for x in range(-RADIUS, RADIUS, 7):
			if Vector2(x, y).length() < RADIUS - 1:
				out.append(Vector2i(x, y))
	return out


func _statics(dir: RingsDirector) -> Array:
	var out := []
	for s in dir._statics:
		out.append([String(s.food.id), (s.node as Node2D).position.round()])
	return out


## Same seed, same planet: every tile, every scattered food and every hidden place.
func test_the_same_seed_rebuilds_the_same_layout() -> void:
	var cells := _cells()
	assert_array(Array(_gen(11).base_chunk(cells))).is_equal(Array(_gen(11).base_chunk(cells)))
	var a := _planet(11)
	var b := _planet(11)
	assert_array(_statics(a)).is_equal(_statics(b))
	assert_dict(a.cities).is_equal(b.cities)


## Another seed changes the details (tile sprinkle, where the scattered foods lie) but no cell
## changes ring and every scattered food stays inside its own ring's band.
func test_another_seed_varies_the_details_inside_the_same_rings() -> void:
	var cells := _cells()
	var ga := _gen(11)
	var gb := _gen(9000)
	var ta := ga.base_chunk(cells)
	var tb := gb.base_chunk(cells)
	var tiles_differ := 0
	for i in cells.size():
		assert_int(gb.ring_index(cells[i])).is_equal(ga.ring_index(cells[i]))
		if ta[i] != tb[i]:
			tiles_differ += 1
	assert_int(tiles_differ).is_greater(0)
	assert_int(tiles_differ).is_less(cells.size() / 2)

	var a := _planet(11)
	var b := _planet(9000)
	var sa := _statics(a)
	var sb := _statics(b)
	assert_int(sb.size()).is_equal(sa.size())
	var moved := 0
	for i in sa.size():
		assert_str(sb[i][0]).is_equal(sa[i][0])   # the same food in the same slot of the list
		if sa[i][1] != sb[i][1]:
			moved += 1
	assert_int(moved).is_greater(0)
	for dir in [a, b]:
		for s in dir._statics:
			var food: RingFood = s.food
			if food.ring == &"":
				continue
			var band: Vector2 = dir.ring_band(food.ring)
			var d: float = dir.depth_of((s.node as Node2D).position)
			assert_float(d).override_failure_message("%s left the %s ring (depth %.3f)" % [food.id, food.ring, d]) \
					.is_between(band.x - 0.01, maxf(band.y, 1.0) + 0.06)


## Every ring keeps its hidden-place slot whatever the seed: the hidden places are data (ring,
## angle, depth), sit at the same spot on both planets, and every ring has at least one.
func test_every_ring_keeps_its_hidden_place_slot_across_seeds() -> void:
	var a := _planet(11)
	var b := _planet(9000)
	var rings: Array[StringName] = [RingsDirector.SKY.ring]
	for r in RINGS.rings:
		rings.append(r.id)
	for ring in rings:
		var slots := RingsDirector.SECRETS.filter(func(s: SecretData) -> bool: return s.ring == ring)
		assert_int(slots.size()).override_failure_message("the %s ring has no hidden place" % ring).is_greater(0)
	for s in RingsDirector.SECRETS:
		assert_vector(b.cities[s.id]).is_equal_approx(a.cities[s.id], Vector2.ONE * 0.01)
		assert_vector(a.cities[s.id]).is_equal_approx(a.polar(s.angle_from_start, s.depth), Vector2.ONE * 0.01)
		assert_bool(a.carved.has(s.id) and b.carved.has(s.id)).is_true()
		var band: Vector2 = a.ring_band(s.ring)
		assert_float(s.depth).override_failure_message("%s sits outside the %s ring" % [s.id, s.ring]) \
				.is_between(band.x, maxf(band.y, 1.0) + 0.06)


## One planet per run: the planet level reads the tin's one seed, keeps it in the tin, and builds
## exactly one disk from it.
func test_one_seed_per_tin_builds_one_planet() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/planet/planet_level.gd")
	assert_bool(src.contains("Save.get_value(\"seed\"")).is_true()
	assert_bool(src.contains("Save.set_value(\"seed\", planet_seed)")).is_true()
	assert_int(src.count("setup_planet(")).is_equal(1)
