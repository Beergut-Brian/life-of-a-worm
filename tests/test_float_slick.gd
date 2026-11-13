## D-08 Slick and D-09 Float, as the player feels them: clouds in the sky carry the cloud flavour,
## so Float is earned by eating them, and a Float burst carries the worm farther across open
## air; in water (a SlowZone of kind water) Slick swims at nearly full speed where a plain worm
## wades at less than half.
class_name TestFloatSlick
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")


func before() -> void:
	SuiteSandbox.enter("float_slick")


func after() -> void:
	for p in Audio._pool:
		p.stop()   # stings still playing at exit leak their playbacks
	for i in 3:
		await get_tree().process_frame
	for p in Audio._pool:
		p.stream = null
	SuiteSandbox.leave()


func _rules() -> WormRules:
	return WormRules.default_rules()


func _worm(stage: int, p: int, at: Vector2, traits: Array = []) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = p
	w.model = WormGrowth.new()
	w.model.apex_gate = true
	w.model.start_at_stage(stage)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	w.position = at
	add_child(w)
	auto_free(w)
	for id in traits:
		w.model.grant(StringName(id))
	return w


## Every worm holds the stick right for `frames` physics frames (burst on the first); returns how
## far each head went.
func _run(worms: Array, frames: int, burst := false) -> Array:
	var start := []
	for w in worms:
		start.append(w.head.global_position)
		w.autopilot = func(_w: Worm) -> Dictionary: return {"move": Vector2.RIGHT, "burst": burst}
	await get_tree().physics_frame
	await get_tree().physics_frame   # the signal comes before the nodes' step: two make sure
	for w in worms:
		w.autopilot = func(_w: Worm) -> Dictionary: return {"move": Vector2.RIGHT}
	for i in frames:
		await get_tree().physics_frame
	var out := []
	for i in worms.size():
		out.append(worms[i].head.global_position.distance_to(start[i]))
	return out


func test_the_sky_has_cloud_food_and_it_earns_float() -> void:
	var cloud: FoodData = load("res://data/foods/cloud_puff.tres")
	assert_str(String(cloud.flavour)).is_equal("cloud")
	var sky: Resource = load("res://data/rings/sky_life.tres")
	assert_bool(cloud in sky.scatter).is_true()
	var floaty := _rules().find_trait(&"floaty")
	assert_str(String(floaty.requires.keys()[0])).is_equal("cloud")
	# Eaten the honest way: a stage-5 worm bites clouds (the sky is edible from 5) until Float comes.
	var m := WormGrowth.new()
	m.apex_gate = true
	m.start_at_stage(sky.edible_from)
	var bites := 0
	while not &"floaty" in m.earned and bites < 20:
		m.add_growth(cloud.growth, cloud.flavour)
		bites += 1
	assert_bool(&"floaty" in m.earned).is_true()
	assert_int(bites).is_less_equal(4)   # a few clouds, not a grind
	assert_int(m.flavour_count(&"cloud")).is_greater_equal(4)   # the stripes show why


func test_a_float_burst_carries_farther_across_open_air() -> void:
	var plain := _worm(5, 0, Vector2(0, 0))
	var floaty := _worm(5, 1, Vector2(0, 600), ["floaty"])
	var d: Array = await _run([plain, floaty], 30, true)
	# half a second after one burst in the open: the floater has coasted on its long burst
	assert_float(d[1]).is_greater(d[0] * 1.15)


func test_slick_swims_where_a_plain_worm_wades() -> void:
	var pool := SlowZone.new()
	pool.kind = &"water"
	pool.drag = 0.6
	pool.size = Vector2(6000, 2000)
	add_child(pool)
	auto_free(pool)
	var dry := _worm(3, 0, Vector2(0, -3000))   # outside the pool
	var wet := _worm(3, 1, Vector2(0, -300))
	var slick := _worm(3, 0, Vector2(0, 300), ["slick"])
	var d: Array = await _run([dry, wet, slick], 40)
	assert_float(d[1]).is_less(d[0] * 0.5)      # plain in water: under half speed
	assert_float(d[2]).is_greater(d[0] * 0.95)  # Slick in water: about full speed (x1.1, drag x0.1)
	assert_float(d[2]).is_greater(d[1] * 2.0)


func test_skater_and_lamp_fish_wade_less_than_a_plain_worm() -> void:
	var pool := SlowZone.new()
	pool.kind = &"water"
	pool.drag = 0.6
	pool.size = Vector2(6000, 3000)
	add_child(pool)
	auto_free(pool)
	var wet := _worm(3, 0, Vector2(0, -600))
	var skater := _worm(3, 1, Vector2(0, 0), ["skater"])
	var lamp := _worm(3, 0, Vector2(0, 600), ["lamp_fish"])
	var d: Array = await _run([wet, skater, lamp], 40)
	assert_float(d[1]).is_greater(d[0] * 1.3)
	assert_float(d[2]).is_greater(d[0] * 1.3)
