## The trait jobs in the planet's rock and water, as the player feels them (TraitKnacks,
## FloodPools, GeodeSeams; all keyed on stats, hooked from the worm scene):
##  - D-05 Stone head bites the deep rock a stage early (a plain stage-3 worm cannot), and with
##    Glow it cracks a shimmering seam into a geode it swallows.
##  - D-06 Glow: hidden seams shimmer through the rock near a glowing worm, never for a plain one.
##  - D-08 Slick: flooded pockets in the dirt slow a plain worm; Slick swims them at nearly full
##    speed. Every splash is heard and seen.
## Events are counted through signals; every worm is staged on its own spot.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const RADIUS := 300

var _world: PolarWorld
var _worms: Array[Worm] = []


func before() -> void:
	SuiteSandbox.enter("trait_knacks")


func after() -> void:
	for p in Audio._pool:
		p.stop()   # stings still playing at exit leak their playbacks
	for i in 3:
		await get_tree().process_frame
	for p in Audio._pool:
		p.stream = null
	SuiteSandbox.leave()


func before_test() -> void:
	Audio.played.clear()
	_world = PolarWorld.new()
	_world.build_overview = false
	_world.setup_planet(RINGS, RADIUS, 4)
	add_child(_world)
	_world.set_physics_process(false)
	TraitKnacks._attach(_world)   # what the first worm's Knacks does


func after_test() -> void:
	for w in _worms:
		if is_instance_valid(w):
			remove_child(w)
			w.free()
	_worms.clear()
	if is_instance_valid(_world):
		remove_child(_world)
		_world.free()


func _r_px() -> float:
	return float(RADIUS * _world.shape.cell_size)


func _worm(p: int, stage: int, at: Vector2, traits: Array = []) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = p
	w.model = WormGrowth.new()
	w.model.start_at_stage(stage)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	w.position = at
	add_child(w)
	_worms.append(w)
	for id in traits:
		w.model.grant(StringName(id))
	w.set_world(_world)
	_world.track(w.head)
	_world.update_chunks(-1)
	return w


func _steer(w: Worm, dir: Vector2) -> void:
	w.heading = dir.angle()
	w.autopilot = func(_w: Worm) -> Dictionary: return {"move": dir}


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		_world.update_chunks(-1)


func _deep_rock_bites(cells: Array) -> int:
	var n := 0
	for c in cells:
		if _world.ring_of(c).id == &"deep_rock":
			n += 1
	return n


# --- D-05: rock a stage early ------------------------------------------------------------------

func test_d05_stone_head_bites_deep_rock_at_stage_3_and_a_plain_worm_cannot() -> void:
	var edge := RINGS.rings[1].outer * _r_px()   # deep rock's outer edge
	var plain := _worm(Players.P1, 3, Vector2.from_angle(0.4) * (edge + 20.0))
	var stone := _worm(Players.P2, 3, Vector2.from_angle(2.4) * (edge + 20.0), ["stone_head"])
	var eaten := {Players.P1: [], Players.P2: []}
	_world.tile_eaten.connect(func(c: Vector2i, _b: StringName, p: int) -> void:
		if eaten.has(p):
			eaten[p].append(c))
	_steer(plain, -Vector2.from_angle(0.4))   # straight down toward the core
	_steer(stone, -Vector2.from_angle(2.4))
	await _frames(90)
	assert_int(_deep_rock_bites(eaten[Players.P1])).is_equal(0)
	assert_int(_deep_rock_bites(eaten[Players.P2])).is_greater(5)
	var knacks: TraitKnacks = stone.get_node("Knacks")
	assert_int(knacks.rock_bites).is_greater(5)
	assert_int(int(stone.moments.get(&"stone_head", 0))).is_greater(0)   # its sting and ring
	assert_bool(Audio.played.has("trait_stone_head")).is_true()
	# Nobody else ever sees the raised stage: it is back to 3 between steps.
	assert_int(_world.stage_of(Players.P2)).is_equal(3)
	assert_float((stone.head.global_position).length()).is_less(edge - 10.0)


# --- D-06 and the D-05 combo: seams ------------------------------------------------------------

func test_d06_a_seam_shimmers_near_a_glowing_worm_and_never_for_a_plain_one() -> void:
	var seams: GeodeSeams = _world.get_node("GeodeSeams")
	assert_int(seams.seams.size()).is_equal(GeodeSeams.DEEP + GeodeSeams.LOW_DIRT)
	var seen := []
	seams.shimmered.connect(func(p: int, i: int) -> void: seen.append([p, i]))
	var s: Dictionary = seams.seams[0]
	var near: Vector2 = s.pos + Vector2.from_angle(1.0) * 6.0 * _world.shape.cell_size
	_worm(Players.P1, 3, near)   # a plain worm right beside it
	await _frames(30)
	assert_array(seen).is_empty()
	assert_float(float(s.glow)).is_equal(0.0)
	var glow := _worm(Players.P2, 3, near, ["glow"])
	await _frames(30)
	assert_int(seen.size()).is_equal(1)   # once per approach, not every frame
	assert_int(int(seen[0][1])).is_equal(0)
	assert_float(float(s.glow)).is_greater(0.5)
	assert_bool(Audio.played.has("trait_glow")).is_true()
	assert_bool(s.found).is_false()   # glow alone only shows it
	glow.head.global_position = s.pos
	await _frames(10)
	assert_bool(s.found).is_false()


func test_d05_glow_and_stone_head_crack_a_seam_into_a_geode() -> void:
	var seams: GeodeSeams = _world.get_node("GeodeSeams")
	var s: Dictionary = seams.seams[GeodeSeams.DEEP]   # a low-dirt one, in reach at stage 3
	var far: Vector2 = s.pos + Vector2.from_angle(1.0) * 30.0 * _world.shape.cell_size
	var w := _worm(Players.P1, 3, far, ["glow", "stone_head"])
	await _frames(2)
	var cracks := []
	seams.cracked.connect(func(p: int, i: int) -> void: cracks.append([p, i]))
	var ate := []
	w.ate.connect(func(_p: int, what: StringName, _g: float) -> void: ate.append(what))
	w.head.global_position = s.pos
	await _frames(10)
	assert_int(cracks.size()).is_equal(1)
	assert_int(int(cracks[0][1])).is_equal(GeodeSeams.DEEP)
	assert_bool(s.found).is_true()
	assert_array(ate).contains([&"geode_seam"])
	assert_bool(Audio.played.has("egg_crack")).is_true()
	await _frames(10)
	assert_int(cracks.size()).is_equal(1)   # a found seam stays found


# --- D-08: flooded pockets ---------------------------------------------------------------------

func test_d08_slick_swims_a_flooded_pocket_a_plain_worm_wades() -> void:
	var pools: FloodPools = _world.get_node("FloodPools")
	assert_int(pools.pools.size()).is_equal(FloodPools.POOLS)
	var pool: FloodPools.FloodPool = pools.pools[0]
	var along := Vector2.from_angle(pool.angle + PI / 2.0)
	var start := pool.centre() - along * 60.0
	var out := pool.centre().normalized()
	var probe := _worm(Players.P1, 2, start + out * 25.0)
	var slick := _worm(Players.P2, 2, start - out * 25.0, ["slick"])
	assert_bool(pool.contains(probe.head.global_position)).is_true()
	assert_bool(pool.contains(slick.head.global_position)).is_true()
	var splashes := []
	pools.splashed.connect(func(p: int, swims: bool) -> void: splashes.append([p, swims]))
	await _frames(2)
	var a0 := probe.head.global_position
	var b0 := slick.head.global_position
	_steer(probe, along)
	_steer(slick, along)
	await _frames(50)
	var plain_d := (probe.head.global_position - a0).length()
	var slick_d := (slick.head.global_position - b0).length()
	assert_float(plain_d).is_greater(5.0)
	assert_float(slick_d).is_greater(plain_d * 1.8)
	assert_bool(pool.contains(probe.head.global_position)).is_true()
	assert_int(splashes.size()).is_equal(2)
	for sp in splashes:
		assert_bool(sp[1]).is_equal(sp[0] == Players.P2)   # only Slick swims
	assert_bool(Audio.played.has("lava_blob_blorp")).is_true()
	assert_bool(Audio.played.has("trait_slick")).is_true()


func test_d08_pools_are_seeded_and_keep_off_the_spawn_side() -> void:
	var a: FloodPools = _world.get_node("FloodPools")
	var other := PolarWorld.new()
	other.build_overview = false
	other.setup_planet(RINGS, RADIUS, 4)
	var b := FloodPools.new()
	other.add_child(b)
	add_child(other)
	other.set_physics_process(false)
	for i in a.pools.size():
		assert_float(b.pools[i].angle).is_equal(a.pools[i].angle)
		assert_float(absf(angle_difference(a.pools[i].angle, -PI / 2.0))).is_greater_equal(FloodPools.SPAWN_CLEAR)
		var r := a.pools[i].radius / _r_px()
		assert_float(r).is_between(RINGS.rings[1].outer, RINGS.rings[2].outer)
	remove_child(other)
	other.free()
