## Secrets 3 (X-01, one hidden place per ring): the topsoil's buried picnic basket and the sky's
## cloud nest. Each is data the director loads, sits inside its own ring away from the start and
## the other places, is found exactly once by entering (the find beat with its own picture), gives
## its unique food and its tackle-box page, and an older tin keeps its statics in order.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const RADIUS := 300
const NEW: Array[StringName] = [&"picnic_basket", &"cloud_nest"]
const FOOD := { &"picnic_basket": &"jam_drop", &"cloud_nest": &"rainbow_drop" }
const RING := { &"picnic_basket": &"topsoil", &"cloud_nest": &"sky" }

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
	_dir.flock.set_process(false)


func after_test() -> void:
	for n in [_dir, _worm, _world]:
		if is_instance_valid(n):
			remove_child(n)
			n.free()


func _make_worm(at: Vector2) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = Players.P1
	w.model = WormGrowth.new()
	w.set_meta("start_pos", at)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	w.set_physics_process(false)
	return w


func _enter(id: StringName) -> void:
	_worm.head.global_position = _dir.cities[id]
	_dir.frame(0.1)
	_dir.frame(0.1)


func test_both_are_data_in_their_own_rings() -> void:
	var rings := {}
	for s in RingsDirector.SECRETS:
		rings[s.ring] = true
	for id in NEW:
		var s := RingsDirector.secret(id)
		assert_object(s).override_failure_message("%s not loaded from data/secrets" % id).is_not_null()
		assert_str(String(s.ring)).is_equal(String(RING[id]))
		assert_str(String(s.page)).is_equal("secret_%s" % id)
		assert_str(String(s.food)).is_equal(String(FOOD[id]))
		assert_str(s.cue).is_not_empty()
		assert_bool(id in RingsDirector.LATE_SECRETS).is_true()
	# one hidden place in every ring: the five tile rings and the sky
	for ring in [&"core", &"deep_rock", &"dirt", &"topsoil", &"sky"]:
		assert_bool(rings.has(ring)).override_failure_message("no hidden place in %s" % ring).is_true()


func test_each_sits_inside_its_ring_far_from_the_start_and_the_others() -> void:
	for id in NEW:
		var s := RingsDirector.secret(id)
		var c: Vector2 = _dir.cities[id]
		var band := _dir.ring_band(s.ring)
		var reach := (s.radius_tiles + 4.0) * 16.0 / _dir.planet_radius_px
		assert_float(_dir.depth_of(c)).override_failure_message("%s not inside its ring" % id) \
			.is_between(band.x + reach, band.y - reach)
		assert_float(c.distance_to(_dir.spawn_point)).is_greater(30.0 * 16.0)
		for other in RingsDirector.SECRETS:
			if other.id != id:
				assert_float(c.distance_to(_dir.cities[other.id])).override_failure_message("%s too close to %s" % [id, other.id]) \
					.is_greater(30.0 * 16.0)
	# the basket is dug into the topsoil and kept; the nest is in open air (no tiles to dig)
	var pc: Vector2 = _dir.cities[&"picnic_basket"]
	var cell := _world.shape.cell_at(pc)
	assert_str(String(_world.ring_of(cell).id)).is_equal("topsoil")
	assert_bool(_world.is_solid(cell)).is_false()
	assert_bool(_world.in_keep_zone(cell)).is_true()
	assert_bool(_world.shape.contains(_world.shape.cell_at(_dir.cities[&"cloud_nest"]))).is_false()


func test_each_is_found_exactly_once_with_its_own_picture() -> void:
	var ids := []
	_dir.secret_found.connect(func(id: StringName) -> void: ids.append(id))
	_dir.frame(0.1)
	assert_array(ids).is_empty()
	_enter(&"picnic_basket")
	_enter(&"cloud_nest")
	_enter(&"picnic_basket")
	_enter(&"cloud_nest")
	assert_array(ids).is_equal([&"picnic_basket", &"cloud_nest"])
	assert_int(Audio.played.get("secret_found", 0)).is_equal(2)
	for id in NEW:
		var spot: SecretSpot = _dir.get_node("Secret_%s" % id)
		assert_bool(spot is SecretHalls).is_true()
		assert_float(spot.beat_t).is_greater_equal(0.0)   # the find beat is playing
		assert_bool(SecretLook.has(id)).override_failure_message("%s draws as a gold star" % id).is_true()
		for pic in spot.beat_pictures():
			assert_bool(PictoBubble.has_picture(pic)).override_failure_message("%s draws as a gold dot" % pic).is_true()
	# the first four keep their own drawing
	assert_bool(_dir.get_node("Secret_ant_city") is SecretHalls).is_false()


func test_each_gives_its_unique_food() -> void:
	for id in NEW:
		var food: StringName = FOOD[id]
		var d: RingFood = load("res://data/foods/%s.tres" % food)
		assert_str(String(d.ring)).is_equal(String(RING[id]))
		var near := 0
		var all := 0
		for f in get_tree().get_nodes_in_group(&"food"):
			if f.get("data") and f.data.id == food:
				all += 1
				if f.global_position.distance_to(_dir.cities[id]) < RingsDirector.secret(id).radius_tiles * 16.0:
					near += 1
		assert_int(near).is_equal(RingsDirector.secret(id).food_count)
		assert_int(all).is_equal(RingsDirector.secret(id).food_count)
		for life in RingsDirector.LIVES + [RingsDirector.SKY, RingsDirector.SURFACE]:
			for f in life.scatter:
				assert_str(String(f.id)).is_not_equal(String(food))
	# jam is grub food (the topsoil opens at stage 2); the rainbow drop waits for a sky-sized worm
	# and is the planet's cloud-flavour food that only the sky has
	assert_bool(_worm.can_eat(load("res://data/foods/jam_drop.tres"))).is_true()
	var rainbow: RingFood = load("res://data/foods/rainbow_drop.tres")
	assert_bool(_worm.can_eat(rainbow)).is_false()
	assert_str(String(rainbow.flavour)).is_equal("cloud")
	_worm.model.start_at_stage(5)
	assert_bool(_worm.can_eat(rainbow)).is_true()


func test_each_gives_its_tackle_box_page() -> void:
	var tlog := TackleLog.new()
	add_child(tlog)
	for id in NEW:
		assert_array(tlog.entries[&"secrets"]).contains([id])
		assert_array(tlog.entries[&"foods"]).contains([FOOD[id]])
	_dir.secret_found.connect(tlog.note_secret)
	_enter(&"cloud_nest")
	assert_bool(tlog.is_found(&"secrets", &"cloud_nest")).is_true()
	assert_bool(tlog.is_found(&"secrets", &"picnic_basket")).is_false()
	assert_int(Audio.played.get("page_new", 0)).is_equal(1)
	tlog.free()


func test_their_foods_come_last_so_older_tins_keep_their_statics() -> void:
	var statics: Array = _dir.to_dict().statics
	var tail: Array[String] = []
	for id in RingsDirector.LATE_SECRETS:
		for i in RingsDirector.secret(id).food_count:
			tail.append(String(RingsDirector.secret(id).food))
	# the rings' D105 foods come after them, last of all
	for life in RingsDirector.LIVES:
		for i in life.late_scatter_count:
			if not life.late_scatter.is_empty():
				tail.append(String(life.late_scatter[i % life.late_scatter.size()].id))
	# and the second D105 slice (stages 3 to 7) after those
	for life in RingsDirector.all_lives():
		for i in life.later_scatter_count:
			if not life.later_scatter.is_empty():
				tail.append(String(life.later_scatter[i % life.later_scatter.size()].id))
	var got: Array[String] = []
	for e in statics.slice(statics.size() - tail.size()):
		got.append(String(e[0]))
	assert_array(got).is_equal(tail)
	# a tin saved before them: every earlier slot keeps its eaten state
	var old := statics.slice(0, statics.size() - tail.size())
	var eaten := old.size() - 1
	old[eaten] = [old[eaten][0], 12.0]
	var again := RingsDirector.new()
	again.auto_tick = false
	add_child(again)
	again.setup(_world, _dir.spawn_point, 4, { "built": true, "found": [], "eco": {}, "statics": old,
			"carved": ["ant_city", "fossil_hall", "geode_cathedral", "sunken_rowboat"] })
	var now: Array = again.to_dict().statics
	assert_int(now.size()).is_equal(statics.size())
	assert_float(float(now[eaten][1])).is_equal(12.0)
	for i in tail.size():
		assert_float(float(now[now.size() - 1 - i][1])).is_less(0.0)
	# the old tin gets the basket dug
	assert_bool(_world.is_solid(_world.shape.cell_at(again.cities[&"picnic_basket"]))).is_false()
	remove_child(again)
	again.free()
