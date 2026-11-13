## D-06 "Crystal -> Glow: lights dark rings": a worm wearing Glow (light_radius from the trait)
## has its head light on, in the trait's colour, sized by the stat; a plain worm's light is off.
## Staged on its own spot in a bare PolarWorld; read after the worm's own physics frames.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const GLOW := preload("res://data/traits/glow.tres")
const RADIUS := 300

var _world: PolarWorld
var _worms: Array[Worm] = []


func before() -> void:
	SuiteSandbox.enter("glow_head_light")


func after() -> void:
	for p in Audio._pool:
		p.stop()
	for i in 3:
		await get_tree().process_frame
	for p in Audio._pool:
		p.stream = null
	SuiteSandbox.leave()


func before_test() -> void:
	_world = PolarWorld.new()
	_world.build_overview = false
	_world.setup_planet(RINGS, RADIUS, 4)
	add_child(_world)
	_world.set_physics_process(false)


func after_test() -> void:
	for w in _worms:
		if is_instance_valid(w):
			remove_child(w)
			w.free()
	_worms.clear()
	remove_child(_world)
	_world.free()


func _worm(p: int, at: Vector2, traits: Array) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = p
	w.model = WormGrowth.new()
	w.model.start_at_stage(4)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	w.position = at
	add_child(w)
	_worms.append(w)
	for id in traits:
		w.model.grant(StringName(id))
	w.set_world(_world)
	return w


func test_d06_glow_turns_the_head_light_on_and_a_plain_worm_stays_unlit() -> void:
	var cs := float(_world.shape.cell_size)
	var deep := Vector2.from_angle(0.7) * 0.3 * RADIUS * cs   # deep rock: a dark ring
	var plain := _worm(Players.P1, deep, [])
	var lit := _worm(Players.P2, deep + Vector2(0, 40), ["glow"])
	for i in 3:
		await get_tree().physics_frame
	assert_float(lit.model.stats.value("light_radius")).is_greater(0.0)
	assert_bool(lit.light.enabled).is_true()
	assert_float(lit.light.texture_scale).is_equal_approx(lit.model.stats.value("light_radius"), 0.001)
	assert_bool(lit.light.color.is_equal_approx(GLOW.color.lerp(Color.WHITE, 0.35))).is_true()
	assert_float(plain.model.stats.value("light_radius")).is_equal(0.0)
	assert_bool(plain.light.enabled).is_false()
