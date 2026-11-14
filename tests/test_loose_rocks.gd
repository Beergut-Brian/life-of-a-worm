## W-35 (feature/worm-gap-close-40): rocks of every size are loose. Before, only pebbles and apples
## fell; a boulder, an ore nugget, a fossil or the core's big boulder hung in mid-air when a worm
## ate the ground from under it. Now each rests where it lies and drops down the tunnel eaten under
## it, lands once with LooseFall's cue, squash and dust, and a big one near a worm nudges the camera.
## Nothing moves when a planet is first built (a rock only falls once something is eaten under it).
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const FOODS := "res://data/foods/%s.tres"
const ROCKS: Array[StringName] = [&"boulder", &"big_boulder", &"ore_nugget", &"fossil"]
const DT := 1.0 / 60.0
const UP := -PI / 2.0

var _keep: Array[Node] = []


func before() -> void:
	SuiteSandbox.enter("loose_rocks")


func after() -> void:
	for p in Audio._pool:
		p.stop()
	SuiteSandbox.leave()


func after_test() -> void:
	for i in range(_keep.size() - 1, -1, -1):
		var n := _keep[i]
		if is_instance_valid(n):
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.free()
	_keep.clear()


func _world(radius := 160) -> PolarWorld:
	var w := PolarWorld.new()
	w.build_overview = false
	w.setup_planet(RINGS, radius, 7)
	add_child(w)
	w.set_physics_process(false)
	_keep.append(w)
	return w


func _destruct(w: PolarWorld) -> WorldDestruct:
	var d := WorldDestruct.new()
	add_child(d)
	_keep.append(d)
	d.set_physics_process(false)
	d.world = w   # no props: only the loose sweep is under test
	return d


func _food(id: StringName, at: Vector2) -> RingPickup:
	var f := RingPickup.new()
	f.data = load(FOODS % id)
	f.position = at
	add_child(f)
	_keep.append(f)
	return f


func _fall(f: Node) -> LooseFall:
	var lf := f.get_node_or_null(^"Fall") as LooseFall
	if lf:
		lf.set_physics_process(false)
	return lf


func _settle(lf: LooseFall, max_steps := 900) -> void:
	for i in max_steps:
		if not lf.step(DT) and lf.resting:
			return


## A shaft three tiles wide in the dirt: open above and below a one-tile plug, a floor under it.
func _shaft(w: PolarWorld) -> Vector2i:
	for x in range(2, 5):
		for y in range(-120, -99):
			if y != -110:
				w.set_tile(Vector2i(x, y), 0)
	return Vector2i(3, -110)


func test_every_rock_is_loose_and_soft_foods_are_not() -> void:
	var w := _world()
	var d := _destruct(w)
	var rocks: Array[RingPickup] = []
	for id in ROCKS:
		assert_bool(d.loose_foods.has(id)).override_failure_message("%s is not loose" % id).is_true()
		rocks.append(_food(id, Vector2(40, -1700)))
	var soft: Array[RingPickup] = []
	for id: StringName in [&"seed", &"mushroom", &"root", &"crystal", &"honeydew"]:
		soft.append(_food(id, Vector2(40, -1700)))
	d.sweep_loose()
	for f in rocks:
		assert_bool(_fall(f) != null).override_failure_message("%s got no Fall" % f.data.id).is_true()
	for f in soft:
		assert_object(f.get_node_or_null(^"Fall")).override_failure_message("%s falls" % f.data.id).is_null()
	# Every rock on the list is a real stone food (a renamed file would silently stop falling).
	for id in ROCKS:
		assert_str(String((load(FOODS % id) as FoodData).flavour)).is_equal("stone")


func test_each_rock_rests_then_drops_when_the_ground_under_it_is_eaten() -> void:
	for id in ROCKS:
		var w := _world()
		var d := _destruct(w)
		var plug := _shaft(w)
		var f := _food(id, w.shape.center_of(Vector2i(3, -116)))
		d.sweep_loose()
		var lf := _fall(f)
		var landed := []
		lf.landed.connect(func(_b: Node2D, speed: float) -> void: landed.append(speed))
		var cues0 := int(Audio.played.get(LooseFall.LAND_CUE, 0))
		_settle(lf)
		var on_plug := f.position.length()
		assert_bool(lf.resting).is_true()
		assert_float(on_plug).is_greater(w.shape.center_of(plug).length())
		for i in 30:   # it stays while the plug is there
			lf.step(DT)
		assert_float(f.position.length()).is_equal_approx(on_plug, 0.01)
		# The worm eats the plug: the rock drops toward the core and lands on the floor, once.
		w.set_stage(0, 7)
		assert_bool(w.eat_tile(plug, 0)).is_true()
		assert_bool(lf.step(DT)).override_failure_message("%s hangs in the air" % id).is_true()
		assert_float(lf.velocity.normalized().dot(-f.position.normalized())).is_greater(0.99)
		_settle(lf)
		var floor_top := w.shape.center_of(Vector2i(3, -99)).length() + 8.0
		assert_float(f.position.length()).override_failure_message("%s did not reach the floor" % id) \
				.is_between(floor_top, floor_top + f.data.radius + 6.0)
		assert_int(landed.size()).is_equal(2)   # onto the plug, then the floor: never a rattle
		assert_int(int(Audio.played.get(LooseFall.LAND_CUE, 0)) - cues0).is_equal(2)
		after_test()


func test_a_big_rock_landing_near_a_worm_nudges_the_camera_and_a_pebble_does_not() -> void:
	var w := _world()
	var d := _destruct(w)
	var plug := _shaft(w)
	var boulder := _food(&"boulder", w.shape.center_of(Vector2i(3, -109)))
	var pebble := _food(&"pebble", w.shape.center_of(Vector2i(2, -109)))
	d.sweep_loose()
	# Nobody near: the thud plays, the camera stays.
	var far := _food(&"boulder", w.shape.center_of(Vector2i(4, -109)))
	d.sweep_loose()
	_settle(_fall(far))
	assert_int(d.thumps).is_equal(0)
	var worm: Worm = WORM.instantiate()
	worm.model = WormGrowth.new()
	worm.model.start_at_stage(2)
	worm.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(worm)
	_keep.append(worm)
	worm.set_physics_process(false)
	worm.global_position = w.to_global(w.shape.center_of(Vector2i(8, -103)))
	_settle(_fall(pebble))
	assert_int(d.thumps).is_equal(0)   # a pebble is too small to thump
	_settle(_fall(boulder))
	assert_int(_fall(boulder).landings).is_equal(1)
	assert_int(d.thumps).is_equal(1)
	assert_int(plug.x).is_equal(3)


func test_nothing_drops_when_a_planet_is_first_built() -> void:
	var w := _world(300)
	var start := Vector2.from_angle(UP) * 300 * 16.0 * 0.76
	var dir := RingsDirector.new()
	dir.auto_tick = false
	add_child(dir)
	_keep.append(dir)
	dir.setup(w, start, 4, {})
	var d := _destruct(w)
	d.sweep_loose()
	var seen := {}
	var moved := 0
	for s in dir._statics:
		var id: StringName = s.food.id
		if not ROCKS.has(id):
			continue
		seen[id] = true
		var p: RingPickup = s.node
		var lf := _fall(p)
		assert_bool(lf != null).override_failure_message("planet %s got no Fall" % id).is_true()
		var at := p.position
		for i in 90:
			lf.step(DT)
		if p.position.distance_to(at) > 0.5:
			moved += 1
	assert_int(moved).override_failure_message("%d rocks fell at boot" % moved).is_equal(0)
	# The planet really lays the scattered rocks this covers (ore nuggets are live bodies).
	for id: StringName in [&"boulder", &"big_boulder", &"fossil"]:
		assert_bool(seen.has(id)).override_failure_message("no %s on the planet" % id).is_true()
