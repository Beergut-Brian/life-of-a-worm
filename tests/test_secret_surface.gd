## X-01, the surface's hidden place: the hollow stump. The crust is only a few tiles thick, so the
## place stands on the grass on the far meadow (opposite the town) instead of being carved. It is
## data the director loads, sits just above the surface away from the start, the town's props and
## the other places, is reached only once the worm bites through the crust (stage 5), is found
## exactly once by entering, gives its unique food (golden acorns, stage 5) and its tackle-box
## page, and comes last in the statics so older tins keep theirs.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const RADIUS := 300
const ID := &"hollow_stump"
const FOOD := &"golden_acorn"

var _world: PolarWorld
var _dir: RingsDirector
var _worm: Worm


func before_test() -> void:
	Audio.played.clear()
	_world = PolarWorld.new()
	_world.build_overview = false
	_world.setup_planet(StageTable.default_table().apply_crust(RINGS), RADIUS, 4)
	add_child(_world)
	_world.set_physics_process(false)
	var start := Vector2.from_angle(-PI / 2.0) * RADIUS * 16.0 * 0.76
	_worm = WORM.instantiate()
	_worm.player = Players.P1
	_worm.model = WormGrowth.new()
	_worm.set_meta("start_pos", start)
	_worm.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(_worm)
	_worm.set_physics_process(false)
	_world.track(_worm.head)
	_world.update_chunks(-1)
	_dir = RingsDirector.new()
	_dir.auto_tick = false
	add_child(_dir)
	_dir.setup(_world, start, 4, {})
	_dir.flock.set_process(false)


func after_test() -> void:
	for n in [_dir, _worm, _world]:
		if is_instance_valid(n):
			remove_child(n)
			n.free()


func _enter() -> void:
	_worm.head.global_position = _dir.cities[ID]
	_dir.frame(0.1)
	_dir.frame(0.1)


func test_it_is_data_in_the_surface_ring_and_comes_last() -> void:
	var s := RingsDirector.secret(ID)
	assert_object(s).override_failure_message("hollow_stump not loaded from data/secrets").is_not_null()
	assert_str(String(s.ring)).is_equal("surface")
	assert_str(String(s.page)).is_equal("secret_hollow_stump")
	assert_str(String(s.food)).is_equal(String(FOOD))
	assert_str(s.cue).is_not_empty()
	assert_int(RingsDirector.LATE_SECRETS.find(ID)).override_failure_message("added after the cloud nest") \
			.is_greater(RingsDirector.LATE_SECRETS.find(&"cloud_nest"))
	assert_bool(SecretHalls.draws(ID)).is_true()
	assert_bool(SecretLook.has(ID)).override_failure_message("draws as a gold star").is_true()
	# now every ring has its hidden place
	var rings := {}
	for x in RingsDirector.SECRETS:
		rings[x.ring] = true
	for ring in [&"core", &"deep_rock", &"dirt", &"topsoil", &"surface", &"sky"]:
		assert_bool(rings.has(ring)).override_failure_message("no hidden place in %s" % ring).is_true()


func test_it_stands_on_the_grass_far_from_the_town_and_the_others() -> void:
	var s := RingsDirector.secret(ID)
	var c: Vector2 = _dir.cities[ID]
	var r := s.radius_tiles * 16.0
	# above the crust, close enough that the drawn stump's foot is on the grass
	var above := c.length() - _dir.planet_radius_px
	assert_float(above).is_between(r, r + 2.0 * 16.0)
	# the hall's circle is open air: nothing to carve, nothing dug out of the crust
	for k in 12:
		var cell := _world.shape.cell_at(c + Vector2.from_angle(TAU * k / 12.0) * r)
		assert_bool(_world.shape.contains(cell) and _world.is_solid(cell)).is_false()
	# the spot straight below the stump is still crust (the stump didn't eat the ground)
	var below := _world.shape.cell_at(c.normalized() * (_dir.planet_radius_px - 8.0))
	assert_bool(_world.is_solid(below)).is_true()
	assert_float(c.distance_to(_dir.spawn_point)).is_greater(30.0 * 16.0)
	for other in RingsDirector.SECRETS:
		if other.id != ID:
			assert_float(c.distance_to(_dir.cities[other.id])).override_failure_message("too close to %s" % other.id) \
				.is_greater(30.0 * 16.0)
	# far from every surface prop (houses, trees, hills...): the meadow is its own
	for f in DirAccess.get_files_at("res://data/props/"):
		if not f.ends_with(".tres"):
			continue
		var p = load("res://data/props/" + f)
		if not (p is PropData):
			continue
		for a in p.angles:
			assert_float(absf(angle_difference(float(a), s.angle_from_start)) * _dir.planet_radius_px) \
				.override_failure_message("%s stands on the stump" % p.id).is_greater(40.0 * 16.0)


func test_only_a_worm_past_the_crust_can_reach_it_and_eat_its_food() -> void:
	var s := RingsDirector.secret(ID)
	var crust := StageTable.default_table().crust_stage()
	assert_int(crust).is_equal(s.carve_stage)
	# the surface ring is not food before the crust stage: the worm can't get out to the stump
	var top := _world.shape.cell_at(_dir.cities[ID].normalized() * (_dir.planet_radius_px - 8.0))
	assert_str(String(_world.ring_of(top).id)).is_equal("surface")
	assert_bool(_world.is_edible_by(crust - 1, top)).is_false()
	assert_bool(_world.is_edible_by(crust, top)).is_true()
	var acorn: RingFood = load("res://data/foods/%s.tres" % FOOD)
	assert_str(String(acorn.ring)).is_equal("surface")
	_worm.model.start_at_stage(crust - 1)
	assert_bool(_worm.can_eat(acorn)).is_false()
	_worm.model.start_at_stage(crust)
	assert_bool(_worm.can_eat(acorn)).is_true()


func test_it_is_found_exactly_once_with_its_picture() -> void:
	var ids: Array[StringName] = []
	_dir.secret_found.connect(func(id: StringName) -> void: ids.append(id))
	_dir.frame(0.1)
	assert_array(ids).is_empty()
	# near but outside the hollow: not yet
	var c: Vector2 = _dir.cities[ID]
	_worm.head.global_position = c + c.normalized().orthogonal() * (RingsDirector.secret(ID).radius_tiles + 4.0) * 16.0
	_dir.frame(0.1)
	assert_array(ids).is_empty()
	_enter()
	_enter()
	assert_array(ids).is_equal([ID] as Array[StringName])
	assert_int(Audio.played.get("secret_found", 0)).is_equal(1)
	var spot: SecretSpot = _dir.get_node("Secret_%s" % ID)
	assert_bool(spot is SecretHalls).is_true()
	assert_float(spot.beat_t).is_greater_equal(0.0)
	for pic in spot.beat_pictures():
		assert_bool(PictoBubble.has_picture(pic)).override_failure_message("%s draws as a gold dot" % pic).is_true()


func test_its_unique_food_sits_in_the_hollow_and_nowhere_else() -> void:
	var s := RingsDirector.secret(ID)
	var near := 0
	var all := 0
	for f in get_tree().get_nodes_in_group(&"food"):
		if f.get("data") and f.data.id == FOOD:
			all += 1
			if f.global_position.distance_to(_dir.cities[ID]) < s.radius_tiles * 16.0:
				near += 1
	assert_int(near).is_equal(s.food_count)
	assert_int(all).is_equal(s.food_count)
	for life in RingsDirector.LIVES + [RingsDirector.SKY, RingsDirector.SURFACE]:
		for f in life.scatter:
			assert_str(String(f.id)).is_not_equal(String(FOOD))


func test_it_has_its_tackle_box_page() -> void:
	var tlog := TackleLog.new()
	add_child(tlog)
	assert_array(tlog.entries[&"secrets"]).contains([ID])
	assert_array(tlog.entries[&"foods"]).contains([FOOD])
	_dir.secret_found.connect(tlog.note_secret)
	_enter()
	assert_bool(tlog.is_found(&"secrets", ID)).is_true()
	tlog.free()


func test_an_older_tin_keeps_its_statics_and_gets_the_stump() -> void:
	var statics: Array = _dir.to_dict().statics
	var n := RingsDirector.secret(ID).food_count
	# hidden places added after the stump put their foods after its acorns
	var after := 0
	for id in RingsDirector.LATE_SECRETS.slice(RingsDirector.LATE_SECRETS.find(ID) + 1):
		after += RingsDirector.secret(id).food_count
	for e in statics.slice(statics.size() - after - n, statics.size() - after):
		assert_str(String(e[0])).is_equal(String(FOOD))
	# a tin saved before the stump: every earlier slot keeps its eaten state
	var old := statics.slice(0, statics.size() - after - n)
	var eaten := old.size() - 1
	old[eaten] = [old[eaten][0], 12.0]
	var again := RingsDirector.new()
	again.auto_tick = false
	add_child(again)
	again.setup(_world, _dir.spawn_point, 4, { "built": true, "found": [], "eco": {}, "statics": old,
			"carved": ["ant_city", "cloud_nest", "fossil_hall", "geode_cathedral", "picnic_basket", "sunken_rowboat"] })
	var now: Array = again.to_dict().statics
	assert_int(now.size()).is_equal(statics.size())
	assert_float(float(now[eaten][1])).is_equal(12.0)
	for i in n + after:
		assert_float(float(now[now.size() - 1 - i][1])).is_less(0.0)
	assert_bool(again.get_node("Secret_%s" % ID) is SecretHalls).is_true()
	assert_bool((again.to_dict().carved as Array).has(String(ID))).is_true()
	remove_child(again)
	again.free()
