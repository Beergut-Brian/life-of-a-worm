## The living rings on a real PolarWorld (RingsDirector): live bodies spawn only into live chunks and
## never on top of a worm; never more than 40 creatures however big the counters get; a worm eating a
## live beetle takes its share off the counter; the ant city is carved, kept, and found once
## (secret_found); birds only go for worms near the top.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const RADIUS := 300

var _world: PolarWorld
var _dir: RingsDirector
var _worm: Worm


func before_test() -> void:
	Audio.played.clear()
	_world = PolarWorld.new()
	_world.build_overview = false
	_world.setup_planet(RINGS, RADIUS, 4)
	add_child(_world)
	_world.set_physics_process(false)
	var start := Vector2.from_angle(-PI / 2.0) * RADIUS * 16.0 * 0.76
	_worm = _make_worm(start)
	_world.track(_worm.head)
	_world.update_chunks(-1)
	_dir = RingsDirector.new()
	_dir.auto_tick = false
	add_child(_dir)
	_dir.setup(_world, start, 4, {})


func after_test() -> void:
	for n in [_dir, _worm, _world]:
		if is_instance_valid(n):
			remove_child(n)
			n.free()


func _make_worm(at: Vector2, stage := 1) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = Players.P1
	w.model = WormGrowth.new()
	if stage > 1:
		w.model.start_at_stage(stage)
	w.set_meta("start_pos", at)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	w.set_physics_process(false)
	return w


func _all_live() -> Array:
	var out := []
	for id in _dir.ecology.rules:
		out.append_array(_dir.live_of(id))
	return out


func test_live_bodies_spawn_only_into_live_chunks_away_from_the_worm() -> void:
	for i in 10:
		_dir.fit_live()
	var all := _all_live()
	assert_int(all.size()).is_greater(10)
	for n in all:
		assert_bool(_world.is_loaded(_world.shape.cell_at(n.position))).is_true()
		if not (n is Creature and n.data.behaviour == CreatureData.Behaviour.MARCH):
			assert_float(n.position.distance_to(_worm.head_position())).is_greater_equal(RingsDirector.SPAWN_NEAR)


func test_never_more_than_40_creatures() -> void:
	for id in _dir.ecology.rules.keys():
		var r: PopulationRule = _dir.ecology.rules[id].duplicate()
		r.live_max = 100
		_dir.ecology.rules[id] = r
		_dir.ecology.counts[id] = 5000.0
	for i in 60:
		_dir.fit_live()
	assert_int(_dir.creature_count()).is_equal(RingsDirector.MAX_CREATURES)
	_dir.send_bird()
	_dir.send_boot()
	assert_int(_dir.creature_count()).is_less_equal(RingsDirector.MAX_CREATURES)


func test_eating_a_live_beetle_takes_its_share_off_the_counter() -> void:
	_dir.ecology.counts[&"beetle"] = 8.0
	for i in 6:
		_dir.fit_live()
	var beetles := _dir.live_of(&"beetle")
	assert_int(beetles.size()).is_greater(0)
	var before := _dir.ecology.count(&"beetle")
	beetles[0].take()
	var rule: PopulationRule = _dir.ecology.rules[&"beetle"]
	assert_float(_dir.ecology.count(&"beetle")).is_equal_approx(before - 1.0 / rule.live_scale, 0.01)


func test_ant_city_is_carved_kept_and_found_once() -> void:
	var city: Vector2 = _dir.cities[&"ant_city"]
	assert_bool(_world.is_solid(_world.shape.cell_at(city))).is_false()
	assert_bool(_world.in_keep_zone(_world.shape.cell_at(city))).is_true()
	var ids := []
	_dir.secret_found.connect(func(id: StringName) -> void: ids.append(id))
	_dir.frame(0.1)
	assert_array(ids).is_empty()   # the start is far from the city: it is hidden, never required
	_worm.head.global_position = city
	_dir.frame(0.1)
	_dir.frame(0.1)
	assert_array(ids).is_equal([&"ant_city"])
	assert_int(Audio.played.get("secret_found", 0)).is_equal(1)
	# its unique food is there
	var honeydew := 0
	for f in get_tree().get_nodes_in_group(&"food"):
		if f.data.id == &"honeydew" and f.global_position.distance_to(city) < 120.0:
			honeydew += 1
	assert_int(honeydew).is_equal(5)


func test_the_ant_trail_leads_from_the_start_to_the_city() -> void:
	var start_d := _dir.trail[0].distance_to(_dir.spawn_point)
	assert_float(start_d).is_less(16.0 * 14.0)
	var city: Vector2 = _dir.cities[&"ant_city"]
	var near := INF
	for p in _dir.trail:
		near = minf(near, p.distance_to(city))
	assert_float(near).is_less(16.0 * 6.0)
	assert_float(_dir.trail[_dir.trail.size() - 1].length()).is_greater_equal(_dir.ground_top() - 1.0)


func test_birds_only_go_for_worms_near_the_top() -> void:
	assert_object(_dir.bird_target()).is_null()
	assert_object(_dir.send_bird()).is_null()
	_worm.head.global_position = _dir.polar(0.0, 0.0) + Vector2.from_angle(_dir.spawn_point.angle()) * (_dir.topsoil_top() - 32.0)
	assert_object(_dir.bird_target()).is_same(_worm)
	var bird := _dir.send_bird()
	assert_object(bird).is_not_null()
	_worm.model.start_at_stage(3)
	assert_object(_dir.bird_target()).is_null()
