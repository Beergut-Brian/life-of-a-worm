## W-10 / W-11: every ring tile is eaten by a worm big enough for its ring and becomes air
## (World.eat_tile, the one eating rule); loose things (pebbles, prop chunks, props) fall toward the
## core with the disk's gravity and rest on the first solid tile; a surface prop (the crate,
## data/props/crate.tres) bonks a small worm, cracks under a big one's bites, knocks out chunk
## foods that fall and can be eaten, breaks with a cue and a camera nudge, and stays broken in the
## tin. Every physics case is staged (a dug shaft, one body at a time), never a pile.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const CRATE := preload("res://data/props/crate.tres")
const PEBBLE := preload("res://data/foods/pebble.tres")
const PLANET := preload("res://scenes/levels/planet.tscn")
const DT := 1.0 / 60.0
const UP := -PI / 2.0
const JUICE_STUB := preload("res://scripts/worm/stubs/juice_stub.gd")


func before() -> void:
	SuiteSandbox.enter("world_destruct")


func after() -> void:
	for p in Audio._pool:
		p.stop()
	SuiteSandbox.leave()


func before_test() -> void:
	JUICE_STUB.clear_cache()


func _world() -> PolarWorld:
	var w := PolarWorld.new()
	w.setup_planet(RINGS, 160, 7)
	add_child(w)
	w.set_physics_process(false)
	return auto_free(w)


func _pebble(w: PolarWorld, cell: Vector2i) -> RingPickup:
	var f := RingPickup.new()
	f.data = PEBBLE
	f.position = w.shape.center_of(cell)
	add_child(f)
	var lf := LooseFall.new()
	lf.name = "Fall"
	lf.world = w
	f.add_child(lf)
	lf.set_physics_process(false)
	return auto_free(f)


func _settle(lf: LooseFall, max_steps := 600) -> int:
	for i in max_steps:
		if not lf.step(DT) and lf.resting:
			return i
	return max_steps


func _destruct(w: PolarWorld, saved := {}) -> WorldDestruct:
	var d := WorldDestruct.new()
	add_child(d)
	auto_free(d)
	var foods := Node2D.new()
	add_child(foods)
	auto_free(foods)
	d.setup(w, Vector2.from_angle(UP) * 1000.0, saved, foods)
	for p in d.props.values():
		p.set_physics_process(false)
		p.fall.set_physics_process(false)
	return d


func _crate(d: WorldDestruct) -> SurfaceProp:
	return d.props["crate_0"]


# --- W-10: every tile destructible ----------------------------------------------------------------

func test_every_ring_tile_is_eaten_from_its_stage_and_becomes_air() -> void:
	var w := _world()
	var dir := Vector2.from_angle(UP + 0.3)   # off the Strangestone seam (y ~ 0)
	var inner := 0.0
	for ring in RINGS.rings:
		var mid := (inner + ring.outer) * 0.5 * 160.0 * 16.0
		inner = ring.outer
		var cell := w.shape.cell_at(dir * mid)
		assert_str(String(w.ring_of(cell).id)).is_equal(String(ring.id))
		assert_bool(w.is_solid(cell)).override_failure_message("%s starts solid" % ring.id).is_true()
		if ring.edible_from > 1:
			w.set_stage(0, ring.edible_from - 1)
			assert_bool(w.eat_tile(cell, 0)).override_failure_message("%s too small" % ring.id).is_false()
			assert_bool(w.is_solid(cell)).is_true()
		w.set_stage(0, ring.edible_from)
		assert_bool(w.eat_tile(cell, 0)).override_failure_message("%s big enough" % ring.id).is_true()
		assert_int(w.get_tile(cell)).is_equal(0)
	# The one exception the contract keeps: Strangestone is never eaten.
	w.set_stage(0, 7)
	assert_bool(w.eat_tile(Vector2i(0, 0), 0)).is_false()


func test_a_pebble_rests_then_falls_toward_the_core_when_the_tile_under_it_is_eaten() -> void:
	var w := _world()
	# A dirt shaft at x 2..4: open -120..-111, a one-tile plug at -110, open -109..-100, floor -99.
	for x in range(2, 5):
		for y in range(-120, -99):
			if y != -110:
				w.set_tile(Vector2i(x, y), 0)
	var plug := Vector2i(3, -110)
	var f := _pebble(w, Vector2i(3, -116))
	var lf: LooseFall = f.get_node("Fall")
	# First step: the disk's own gravity, toward the core.
	var p0 := f.position
	lf.step(DT)
	assert_float(lf.velocity.normalized().dot(-p0.normalized())).is_greater(0.999)
	assert_float(lf.velocity.length()).is_equal_approx(w.shape.gravity * DT, 0.01)
	_settle(lf)
	assert_bool(lf.resting).is_true()
	var on_plug := f.position.length()
	assert_float(on_plug).is_greater(w.shape.center_of(plug).length())
	assert_float(on_plug).is_less(p0.length())
	# It stays put while the plug is there.
	for i in 30:
		lf.step(DT)
	assert_float(f.position.length()).is_equal_approx(on_plug, 0.01)
	# A big enough worm eats the plug: it becomes air and the pebble falls to the floor.
	w.set_stage(0, 7)
	assert_bool(w.eat_tile(plug, 0)).is_true()
	assert_bool(lf.step(DT)).is_true()
	_settle(lf)
	assert_bool(lf.resting).is_true()
	var floor_top := w.shape.center_of(Vector2i(3, -99)).length() + 8.0
	assert_float(f.position.length()).is_between(floor_top, floor_top + PEBBLE.radius + 6.0)
	assert_int(lf.landings).is_greater_equal(1)
	assert_int(int(Audio.played.get(LooseFall.LAND_CUE, 0))).is_greater_equal(1)


func test_a_carried_or_eaten_pebble_never_falls() -> void:
	var w := _world()
	for y in range(-120, -100):
		w.set_tile(Vector2i(3, y), 0)
	var f := _pebble(w, Vector2i(3, -116))
	var lf: LooseFall = f.get_node("Fall")
	f.set_carried(true)
	var at := f.position
	assert_bool(lf.step(DT)).is_false()
	assert_vector(f.position).is_equal(at)
	f.set_carried(false)
	f.take()
	assert_bool(lf.step(DT)).is_false()
	assert_vector(f.position).is_equal(at)


func test_world_destruct_makes_pebbles_loose_and_nothing_else() -> void:
	var w := _world()
	var pebble := RingPickup.new()
	pebble.data = PEBBLE
	add_child(pebble)
	auto_free(pebble)
	var seed_food := RingPickup.new()
	seed_food.data = load("res://data/foods/seed.tres")
	add_child(seed_food)
	auto_free(seed_food)
	var d := _destruct(w)
	d.sweep_loose()
	assert_bool(pebble.get_node_or_null(^"Fall") is LooseFall).is_true()
	assert_object(seed_food.get_node_or_null(^"Fall")).is_null()


# --- W-11: props ----------------------------------------------------------------------------------

func test_every_prop_is_prop_data_with_a_chunk_food_and_a_scene() -> void:
	var all := WorldDestruct.load_props()
	assert_int(all.size()).is_greater_equal(1)
	for d in all:
		assert_bool(d is PropData).is_true()
		assert_bool(d.chunk is FoodData).override_failure_message("%s chunk" % d.id).is_true()
		assert_int(d.chunks).is_greater_equal(d.hits)
		assert_int(d.size.x * d.size.y).is_greater(1)   # multi-tile
		assert_bool(ResourceLoader.exists("res://scenes/props/%s.tscn" % d.id)).is_true()
		var s := (load("res://scenes/props/%s.tscn" % d.id) as PackedScene).instantiate()
		assert_bool(s is SurfaceProp).is_true()
		s.free()
	assert_bool(CRATE.chunk is RingFood).is_true()


func test_a_crate_stands_upright_on_the_surface() -> void:
	var w := _world()
	var d := _destruct(w)
	assert_int(d.props.size()).is_equal(CRATE.angles.size())
	var c := _crate(d)
	var up := Vector2.from_angle(UP + CRATE.angles[0])
	assert_float(c.position.normalized().dot(up)).is_greater(0.9999)
	assert_bool(w.is_solid(w.shape.cell_at(c.position - up * 2.0))).is_true()
	assert_bool(w.is_solid(w.shape.cell_at(c.position + up * 2.0))).is_false()
	assert_float(Vector2.UP.rotated(c.rotation).dot(up)).is_greater(0.9999)
	# Standing on the ground, it does not fall.
	assert_bool(c.fall.step(DT)).is_false()


func test_a_small_worm_bonks_off_and_nothing_breaks() -> void:
	var w := _world()
	var c := _crate(_destruct(w))
	assert_bool(w.is_edible_by(CRATE.size_stage, c)).is_false()
	assert_bool(c.bite(0, CRATE.size_stage)).is_false()
	assert_int(c.hp).is_equal(CRATE.hits)
	assert_bool(c.broken).is_false()
	assert_int(c.chunks_out.size()).is_equal(0)
	assert_int(int(Audio.played.get(SurfaceProp.BONK_CUE, 0))).is_greater_equal(1)


func test_a_big_worm_bites_the_crate_into_chunks_that_fall_and_are_eaten() -> void:
	var w := _world()
	var d := _destruct(w)
	var c := _crate(d)
	var big := CRATE.size_stage + 1
	assert_bool(w.is_edible_by(big, c)).is_true()
	var broke := []
	c.broke.connect(func(_p: SurfaceProp, pl: int, chunks: Array) -> void: broke.append([pl, chunks.size()]))
	var cracks0 := int(Audio.played.get(SurfaceProp.CRACK_CUE, 0))
	for i in CRATE.hits - 1:
		assert_bool(c.bite(1, big)).is_true()
		assert_int(c.hp).is_equal(CRATE.hits - 1 - i)
		assert_int(c.chunks_out.size()).is_equal(i + 1)   # one chunk knocked out per bite
		assert_int(c._cracks.size()).is_equal(i + 1)      # and a new crack you can see
	assert_int(int(Audio.played.get(SurfaceProp.CRACK_CUE, 0)) - cracks0).is_equal(CRATE.hits - 1)
	assert_bool(c.broken).is_false()
	var breaks0 := int(Audio.played.get(SurfaceProp.BREAK_CUE, 0))
	assert_bool(c.bite(1, big)).is_true()
	assert_bool(c.broken).is_true()
	assert_array(broke).is_equal([[1, CRATE.chunks]])
	assert_int(int(Audio.played.get(SurfaceProp.BREAK_CUE, 0)) - breaks0).is_equal(1)
	assert_int(d.to_dict().props["crate_0"]).is_equal(0)
	assert_bool(d.props.has("crate_0")).is_false()
	# The chunks are food, flying out then falling to the surface.
	var ground := WorldDestruct.surface_distance(w, UP + CRATE.angles[0])
	for f in c.chunks_out:
		assert_bool(f.is_in_group(&"food")).is_true()
		assert_bool(f.data == CRATE.chunk).is_true()
		var lf: LooseFall = f.get_node("Fall")
		lf.set_physics_process(false)
		_settle(lf)
		assert_bool(lf.resting).is_true()
		assert_bool(lf.supported_at(w.to_local(f.global_position))).is_true()
		assert_float(f.position.length()).is_between(ground - 34.0, ground + 24.0)
	# A worm big enough to break it can eat them (the worm's food rule), and eating takes one.
	var edible := StageTable.default_table().at(big).edible_size
	assert_int(CRATE.chunk.size_stage).is_less_equal(edible)
	var first: RingPickup = c.chunks_out[0]
	assert_bool(first.is_available()).is_false()   # knocked out: seen landing before it is eaten
	first._process(SurfaceProp.CHUNK_BLOCK + 0.01)
	assert_bool(first.is_available()).is_true()
	first.take()
	assert_bool(first.is_available()).is_false()
	assert_bool(first.is_in_group(&"food")).is_false()
	# The prop pops away.
	await await_millis(400)
	assert_bool(is_instance_valid(c)).is_false()


func test_the_break_shows_its_cause() -> void:
	var w := _world()
	var c := _crate(_destruct(w))
	var big := CRATE.size_stage + 1
	c.bite(0, big)
	var after_bite := JUICE_STUB.calls.map(func(e: Array) -> String: return e[0])
	assert_array(after_bite).contains(["chomp", "debris"])
	assert_array(after_bite).not_contains(["shake"])
	for i in CRATE.hits - 1:
		c.bite(0, big)
	var all := JUICE_STUB.calls.map(func(e: Array) -> String: return e[0])
	assert_array(all).contains(["shake"])   # the camera nudge, only on the break
	assert_float(c._wobble).is_greater(0.0)


func test_bites_are_spaced_by_the_cooldown_in_play() -> void:
	var w := _world()
	var c := _crate(_destruct(w))
	c.bite(0, CRATE.size_stage + 1)
	assert_float(c._cool[0]).is_equal(SurfaceProp.BITE_COOLDOWN)
	c._physics_process(SurfaceProp.BITE_COOLDOWN)
	assert_float(c._cool[0]).is_equal(0.0)


func test_a_prop_falls_when_the_ground_under_it_is_eaten() -> void:
	var w := _world()
	var c := _crate(_destruct(w))
	var up := c.position.normalized()
	var side := up.orthogonal()
	var top := c.position.length()
	# Eat a 3-wide, 5-deep pit under its middle.
	w.set_stage(0, 7)
	for k in range(-1, 2):
		for depth in range(0, 5):
			w.eat_tile(w.shape.cell_at(c.position + side * (k * 16.0) - up * (depth * 16.0 + 8.0)), 0)
	assert_bool(c.fall.step(DT)).is_true()
	_settle(c.fall)
	assert_bool(c.fall.resting).is_true()
	assert_float(c.position.length()).is_less(top - 60.0)


func test_broken_and_bitten_props_are_kept_in_the_tin() -> void:
	var w := _world()
	var d := _destruct(w, { "props": { "crate_0": 0, "crate_1": 2 } })
	assert_bool(d.props.has("crate_0")).is_false()
	assert_int(d.props["crate_1"].hp).is_equal(2)
	assert_int(d.props["crate_1"]._cracks.size()).is_equal(CRATE.hits - 2)
	d.props["crate_1"].bite(0, CRATE.size_stage + 1)
	assert_dict(d.to_dict()).is_equal({ "props": { "crate_0": 0, "crate_1": 1 } })


func test_the_planet_scene_hooks_world_destruct() -> void:
	var p := PLANET.instantiate()
	var n := p.get_node_or_null(^"Destruct")
	assert_bool(n is WorldDestruct).is_true()
	p.free()
