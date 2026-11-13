## G-06: rain soaks into the topsoil and makes castings sprout. Shoots only come up in open topsoil
## castings near a worm while it rains, grow over a few seconds, play `garden_plant` once, and a grown
## shoot under a worm's mouth is a small root nibble (the light garden bonus). Real PolarWorld and
## RingsDirector, stepped by hand.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const RADIUS := 160

var _world: PolarWorld
var _dir: RingsDirector
var _worm: Worm
var _sp: CastingsSprouts


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
	_worm.model.start_at_stage(2)   # topsoil is edible from stage 2
	_worm.set_meta("start_pos", _topsoil_point())
	_worm.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(_worm)
	_worm.set_physics_process(false)
	_world.track(_worm.head)
	_world.update_chunks(-1)
	_world.set_stage(Players.P1, 2)
	_dir = RingsDirector.new()
	_dir.auto_tick = false
	add_child(_dir)
	_dir.setup(_world, start, 7, {})
	_dir.hook_worm(_worm)
	_sp = _dir.sprouts
	_sp.set_process(false)


func after_test() -> void:
	for n in [_dir, _worm, _world]:
		if is_instance_valid(n):
			remove_child(n)
			n.free()


func _topsoil_point() -> Vector2:
	return Vector2.from_angle(-PI / 2.0) * RADIUS * 16.0 * 0.9


## A sideways tunnel of castings the worm ate, centred on p.
func _tunnel(p: Vector2, half := 6) -> Array[Vector2i]:
	var c := _world.shape.cell_at(p)
	var out: Array[Vector2i] = []
	for x in range(-half, half + 1):
		_world.eat_tile(c + Vector2i(x, 0), Players.P1)
		out.append(c + Vector2i(x, 0))
	return out


func _steps(seconds: float) -> void:
	for i in int(seconds * 10.0):
		_sp.step(0.1)


func test_the_sprouts_node_is_part_of_the_rings() -> void:
	assert_object(_sp).is_not_null()
	assert_object(_sp.get_parent()).is_same(_dir)


func test_dry_castings_never_sprout() -> void:
	_tunnel(_topsoil_point())
	_dir.raining = false
	_steps(10.0)
	assert_int(_sp.sprouts.size()).is_equal(0)
	assert_int(Audio.played.get("garden_plant", 0)).is_equal(0)


func test_rain_makes_topsoil_castings_sprout_and_grow_with_a_sound() -> void:
	var cells := _tunnel(_topsoil_point())
	_dir.raining = true
	_steps(2.0)
	assert_int(_sp.sprouts.size()).is_greater(0)
	for cell in _sp.sprouts:
		assert_array(cells).contains([cell])
		assert_str(String(_world.ring_of(cell).id)).is_equal("topsoil")
	assert_int(Audio.played.get("garden_plant", 0)).is_equal(1)
	_steps(CastingsSprouts.GROW + 1.0)
	assert_int(_sp.grown()).is_greater(0)
	assert_int(Audio.played.get("garden_plant", 0)).is_less_equal(2)   # never a stream of beeps


func test_dirt_castings_do_not_sprout() -> void:
	var dirt := Vector2.from_angle(-PI / 2.0) * RADIUS * 16.0 * 0.7
	_tunnel(dirt)
	_worm.head.global_position = dirt
	_dir.raining = true
	_steps(5.0)
	assert_int(_sp.sprouts.size()).is_equal(0)


func test_shoots_stay_after_the_rain_but_stop_growing() -> void:
	_tunnel(_topsoil_point())
	_dir.raining = true
	_steps(1.0)
	var n := _sp.sprouts.size()
	assert_int(n).is_greater(0)
	_dir.raining = false
	_steps(CastingsSprouts.GROW + 2.0)
	assert_int(_sp.sprouts.size()).is_equal(n)
	assert_int(_sp.grown()).is_equal(0)


func test_a_grown_shoot_under_the_mouth_is_a_root_nibble() -> void:
	_tunnel(_topsoil_point())
	_dir.raining = true
	_steps(CastingsSprouts.GROW + 2.0)
	var cell: Vector2i = Vector2i.ZERO
	for c in _sp.sprouts:
		if _sp.sprouts[c].k >= 1.0:
			cell = c
			break
	assert_bool(_sp.sprouts.has(cell)).is_true()
	var at := _world.shape.center_of(cell)
	var offset := _worm.mouth_position() - _worm.head.global_position
	_worm.head.global_position = at - offset
	var before := _worm.model.growth
	var segs := _worm.model.segments.size()
	Audio.played.clear()
	_sp.step(0.1)
	assert_bool(_sp.sprouts.has(cell)).is_false()
	assert_bool(_worm.model.growth > before or _worm.model.segments.size() > segs).is_true()
	var chomps := 0
	for k in Audio.played:
		if String(k).begins_with("chomp_"):
			chomps += Audio.played[k]
	assert_int(chomps).is_greater(0)
