## G-01: where a worm eats it leaves castings you can see. A real PolarWorld (radius 160) with a
## CastingsTrail stepped by hand: every eaten tile drops a warm brown pile on the tunnel floor, the
## piles pop in, stay capped at MAX_PILES, go when the tile grows back, refill from the saved layer
## round a worm, and every worm hands its world exactly one trail. Counts come from the trail's own
## per-call counters (added / dropped), never from polling a frame.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const RADIUS := 160

var _world: PolarWorld
var _trail: CastingsTrail
var _worms: Array[Worm] = []
var _eye: Node2D


func before_test() -> void:
	_world = PolarWorld.new()
	_world.build_overview = false
	_world.setup_planet(RINGS, RADIUS, 7)
	add_child(_world)
	_world.set_physics_process(false)
	_eye = Node2D.new()
	_eye.position = Vector2.from_angle(-PI / 2.0) * RADIUS * 16.0 * 0.9
	_world.add_child(_eye)
	_world.track(_eye)   # loads the chunks round the test tunnels
	_world.update_chunks(-1)
	_world.set_stage(Players.P1, 2)   # topsoil is edible from stage 2
	_trail = CastingsTrail.ensure(_world)
	_trail.set_process(false)


func after_test() -> void:
	for w in _worms:
		if is_instance_valid(w):
			remove_child(w)
			w.free()
	_worms.clear()
	if is_instance_valid(_world):
		remove_child(_world)
		_world.free()


func _topsoil_cell() -> Vector2i:
	return _world.shape.cell_at(Vector2.from_angle(-PI / 2.0) * RADIUS * 16.0 * 0.9)


func _worm_at(p: Vector2, stage := 2) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = Players.P1
	w.model = WormGrowth.new()
	w.model.start_at_stage(stage)
	w.set_meta("start_pos", p)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	w.set_physics_process(false)
	_worms.append(w)
	return w


func test_eating_a_tile_drops_one_pile_that_pops_in() -> void:
	var c := _topsoil_cell()
	assert_bool(_world.eat_tile(c, Players.P1)).is_true()
	assert_int(_trail.added).is_equal(1)
	assert_bool(_trail.piles.has(c)).is_true()
	assert_float(float(_trail.piles[c].born)).is_greater_equal(0.0)   # fresh: it pops in
	# The pile sits on the floor side of its cell (toward the planet's centre).
	var mid := _world.shape.center_of(c)
	var pos: Vector2 = _trail.piles[c].pos
	assert_float(pos.length()).is_less(mid.length())


func test_the_castings_are_warm_brown_and_never_dark() -> void:
	for col: Color in [CastingsTrail.SOIL, CastingsTrail.SOIL_LIGHT, CastingsTrail.SOIL_SHINE]:
		assert_float(col.get_luminance()).is_greater(0.3)   # nothing dark or creepy in the dirt
		assert_bool(col.r > col.g and col.g > col.b).is_true()   # warm brown
		assert_float(col.s).is_greater(0.3)


func test_a_tunnel_leaves_a_trail_of_spaced_piles() -> void:
	var c := _topsoil_cell()
	for x in range(-8, 9):
		_world.eat_tile(c + Vector2i(x, 0), Players.P1)
	# Stage 2: one pile every other cell or so, never two touching.
	assert_int(_trail.added).is_between(6, 9)
	for p: Vector2i in _trail.piles:
		for q: Vector2i in _trail.piles:
			if p != q:
				assert_int(maxi(absi(p.x - q.x), absi(p.y - q.y))).is_greater(_trail.gap_for(2))


func test_castings_fall_to_the_tunnel_floor() -> void:
	# A shaft three cells deep at the top of the planet: the core is +y. Eaten bottom first, every
	# pile settles on the floor cell, so the shaft holds one pile at its bottom.
	var c := _topsoil_cell()
	for dy in [2, 1, 0]:
		_world.eat_tile(c + Vector2i(0, dy), Players.P1)
	assert_int(_trail.piles.size()).is_equal(1)
	assert_bool(_trail.piles.has(c + Vector2i(0, 2))).is_true()
	assert_object(_trail.settle(c)).is_equal(c + Vector2i(0, 2))


func test_the_number_of_piles_is_capped() -> void:
	var c := _topsoil_cell()
	var tries := 0
	for y in range(0, 60, 3):
		for x in range(-60, 60, 3):
			_trail.add_pile(c + Vector2i(x, y), 1, true)
			tries += 1
	assert_int(tries).is_greater(CastingsTrail.MAX_PILES * 2)
	assert_int(_trail.piles.size()).is_equal(CastingsTrail.MAX_PILES)
	assert_int(_trail.dropped).is_equal(_trail.added - CastingsTrail.MAX_PILES)


func test_with_a_worm_the_far_piles_go_first() -> void:
	var c := _topsoil_cell()
	var w := _worm_at(_world.to_global(_world.shape.center_of(c)))
	w.set_world(_world)
	for y in range(0, 60, 3):
		for x in range(-60, 60, 3):
			_trail.add_pile(c + Vector2i(x, y), 1, true)
	assert_int(_trail.piles.size()).is_equal(CastingsTrail.MAX_PILES)
	# The pile on the worm's own cell outlived the far ones added after it.
	assert_bool(_trail.piles.has(c)).is_true()


func test_a_regrown_tile_covers_its_pile() -> void:
	var c := _topsoil_cell()
	_world.eat_tile(c, Players.P1)
	assert_bool(_trail.piles.has(c)).is_true()
	_world._regrow(c)
	assert_bool(_trail.piles.has(c)).is_false()
	assert_bool(_world.has_castings(c)).is_true()   # the saved layer stays: eaten again, fast regrow


func test_old_castings_round_a_worm_show_again() -> void:
	# Castings from a loaded tin: in the saved layer, no piles yet. A worm nearby refills them.
	var c := _topsoil_cell()
	for x in range(-4, 5):
		_world.eat_tile(c + Vector2i(x, 0), Players.P1)
	_trail.piles.clear()
	var before := _trail.added
	var w := _worm_at(_world.to_global(_world.shape.center_of(c)))
	w.set_world(_world)
	_trail.refill()
	assert_int(_trail.added - before).is_greater(0)
	for p: Vector2i in _trail.piles:
		assert_bool(_world.has_castings(p)).is_true()
		assert_float(float(_trail.piles[p].born)).is_equal(-1.0)   # settled, no pop


func test_every_worm_gives_its_world_one_trail() -> void:
	var w2 := PolarWorld.new()
	w2.build_overview = false
	w2.setup_planet(RINGS, RADIUS, 9)
	add_child(w2)
	w2.set_physics_process(false)
	var p := Vector2.from_angle(-PI / 2.0) * RADIUS * 16.0 * 0.9
	var a := _worm_at(p)
	var b := _worm_at(p)
	a.set_world(w2)
	b.set_world(w2)
	assert_object(w2.get_node_or_null(NodePath(CastingsTrail.NODE_NAME))).is_null()
	for hook in [a.get_node("CastingsHook"), b.get_node("CastingsHook")]:
		hook._physics_process(1.0 / 60.0)
	var n := 0
	for ch in w2.get_children():
		if ch is CastingsTrail:
			n += 1
	assert_int(n).is_equal(1)
	remove_child(w2)
	w2.free()
