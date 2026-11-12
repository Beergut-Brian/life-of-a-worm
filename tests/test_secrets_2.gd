## Secrets 2 (X-03, X-04): Old Reel's sunken rowboat in the aquifer pool at the foot of the dirt, and
## the fossil hall in the deep rock. Each is carved into its ring, found exactly once by entering,
## gives its unique food and its tackle-box page, plays the find beat (picture bubble, then the
## tackle box opens on its sketch), and never regrows over itself.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const RADIUS := 300
const NEW: Array[StringName] = [&"sunken_rowboat", &"fossil_hall"]
const FOOD := { &"sunken_rowboat": &"ship_biscuit", &"fossil_hall": &"amber" }

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


func _cells_of(id: StringName) -> Array[Vector2i]:
	var s := RingsDirector.secret(id)
	var c: Vector2 = _dir.cities[id]
	var out: Array[Vector2i] = [_world.shape.cell_at(c)]
	for r in RingsDirector.rooms_of(s, c):
		out.append(_world.shape.cell_at(c + Vector2(r.x, r.y)))
	return out


func test_both_secrets_are_data_the_director_loads() -> void:
	var ids: Array[StringName] = []
	for s in RingsDirector.SECRETS:
		ids.append(s.id)
	assert_array(ids).contains(NEW)
	assert_array(ids).contains([&"ant_city"])
	for id in NEW:
		var s := RingsDirector.secret(id)
		assert_str(String(s.page)).is_equal("secret_%s" % id)
		assert_str(String(s.food)).is_equal(String(FOOD[id]))
		assert_str(s.cue).is_not_empty()


func test_each_is_carved_into_its_ring() -> void:
	assert_str(String(RingsDirector.secret(&"sunken_rowboat").ring)).is_equal("dirt")
	assert_str(String(RingsDirector.secret(&"fossil_hall").ring)).is_equal("deep_rock")
	for id in NEW:
		var s := RingsDirector.secret(id)
		var c: Vector2 = _dir.cities[id]
		var band := _dir.ring_band(s.ring)
		var reach := (s.radius_tiles + 4.0) * 16.0 / _dir.planet_radius_px
		assert_float(_dir.depth_of(c)).override_failure_message("%s not inside its ring" % id) \
			.is_between(band.x + reach, band.y - reach)
		assert_str(String(_world.ring_of(_world.shape.cell_at(c)).id)).is_equal(String(s.ring))
		for cell in _cells_of(id):
			assert_bool(_world.is_solid(cell)).override_failure_message("%s not carved at %s" % [id, cell]).is_false()
			assert_bool(_world.in_keep_zone(cell)).is_true()
		# hidden: far from the start and from each other
		assert_float(c.distance_to(_dir.spawn_point)).is_greater(30.0 * 16.0)
	assert_float((_dir.cities[&"sunken_rowboat"] as Vector2).distance_to(_dir.cities[&"fossil_hall"])).is_greater(30.0 * 16.0)


func test_each_is_found_exactly_once_by_entering() -> void:
	var ids := []
	_dir.secret_found.connect(func(id: StringName) -> void: ids.append(id))
	_dir.frame(0.1)
	assert_array(ids).is_empty()   # never found from the start: hidden, never required
	_enter(&"sunken_rowboat")
	assert_array(ids).is_equal([&"sunken_rowboat"])
	_enter(&"fossil_hall")
	assert_array(ids).is_equal([&"sunken_rowboat", &"fossil_hall"])
	_enter(&"sunken_rowboat")
	_enter(&"fossil_hall")
	assert_array(ids).is_equal([&"sunken_rowboat", &"fossil_hall"])
	assert_int(Audio.played.get("secret_found", 0)).is_equal(2)
	assert_bool(_dir.found.has(&"sunken_rowboat") and _dir.found.has(&"fossil_hall")).is_true()


func test_the_find_plays_the_picture_beat() -> void:
	var spot: SecretSpot = _dir.get_node("Secret_sunken_rowboat")
	assert_float(spot.beat_t).is_less(0.0)
	_enter(&"sunken_rowboat")
	assert_float(spot.beat_t).is_greater_equal(0.0)
	assert_object(spot.get_node_or_null("FoundBubble")).is_not_null()
	assert_array(spot.beat_pictures()).is_equal([&"secret:sunken_rowboat", &"secret_food:ship_biscuit", &"secret_box"])
	for pic in spot.beat_pictures():
		assert_bool(PictoBubble.has_picture(pic)).override_failure_message("%s draws as a gold dot" % pic).is_true()
	# it plays, then goes
	for i in 80:
		spot._process(0.1)
	assert_float(spot.beat_t).is_less(0.0)
	# the other spot did not play
	var other: SecretSpot = _dir.get_node("Secret_fossil_hall")
	assert_float(other.beat_t).is_less(0.0)


func test_each_gives_its_unique_food() -> void:
	for id in NEW:
		var food: StringName = FOOD[id]
		var d: RingFood = load("res://data/foods/%s.tres" % food)
		assert_str(String(d.ring)).is_equal(String(RingsDirector.secret(id).ring))
		# unique: only this secret places it, nowhere else on the planet, and no ring life spawns it
		var near := 0
		var all := 0
		for f in get_tree().get_nodes_in_group(&"food"):
			if f.get("data") and f.data.id == food:
				all += 1
				if f.global_position.distance_to(_dir.cities[id]) < RingsDirector.secret(id).radius_tiles * 16.0:
					near += 1
		assert_int(near).is_equal(RingsDirector.secret(id).food_count)
		assert_int(all).is_equal(RingsDirector.secret(id).food_count)
		for life in RingsDirector.LIVES:
			for f in life.scatter:
				assert_str(String(f.id)).is_not_equal(String(food))
	# not the scattered fossil: a different id, so the deep-rock fossil counts stay honest
	assert_str(String(FOOD[&"fossil_hall"])).is_not_equal("fossil")
	var ids := {}
	for s in RingsDirector.SECRETS:
		assert_bool(ids.has(s.food)).override_failure_message("two secrets share %s" % s.food).is_false()
		ids[s.food] = true


func test_a_worm_can_eat_the_food_once_it_is_big_enough() -> void:
	var biscuit: RingFood = load("res://data/foods/ship_biscuit.tres")
	var amber: RingFood = load("res://data/foods/amber.tres")
	assert_bool(_worm.can_eat(biscuit)).is_true()   # the rowboat is open to a grub
	assert_bool(_worm.can_eat(amber)).is_false()    # amber waits for a worm that can bite rock
	_worm.model.start_at_stage(4)
	assert_bool(_worm.can_eat(amber)).is_true()


func test_each_gives_its_tackle_box_page() -> void:
	var tlog := TackleLog.new()
	add_child(tlog)
	for id in NEW:
		assert_array(tlog.entries[&"secrets"]).contains([id])
		assert_array(tlog.entries[&"foods"]).contains([FOOD[id]])
		assert_bool(tlog.is_found(&"secrets", id)).is_false()
	_dir.secret_found.connect(tlog.note_secret)
	_enter(&"fossil_hall")
	assert_bool(tlog.is_found(&"secrets", &"fossil_hall")).is_true()
	assert_bool(tlog.is_found(&"secrets", &"sunken_rowboat")).is_false()
	assert_int(Audio.played.get("page_new", 0)).is_equal(1)
	_enter(&"sunken_rowboat")
	assert_bool(tlog.is_found(&"secrets", &"sunken_rowboat")).is_true()
	assert_int(Audio.played.get("page_new", 0)).is_equal(2)
	tlog.free()


func test_the_tackle_box_opens_on_the_new_find() -> void:
	var tlog := TackleLog.new()
	add_child(tlog)
	var box := TackleBox.new()
	box.tlog = tlog
	box.pause_tree = false
	add_child(box)
	_dir.secret_found.connect(tlog.note_secret)
	_enter(&"sunken_rowboat")
	box.open(Players.P1)
	assert_str(String(box.page_id())).is_equal("secrets")
	assert_str(String(tlog.entries[&"secrets"][box.cursor])).is_equal("sunken_rowboat")
	assert_int(Audio.played.get("box_why", 0)).is_equal(1)
	box.close()
	box.nav(0, 1)   # turn away; a plain reopen stays where it was
	box.open(Players.P1)
	assert_str(String(box.page_id())).is_not_equal("secrets")
	assert_int(Audio.played.get("box_why", 0)).is_equal(1)
	box.close()
	box.free()
	tlog.free()


func test_neither_regrows_over_itself() -> void:
	for id in NEW:
		_worm.head.global_position = _dir.cities[id]
		_world.update_chunks(-1)
		# a control cell well outside the hall does regrow
		var c: Vector2 = _dir.cities[id]
		var out := _world.shape.cell_at(c + c.normalized().orthogonal() * (RingsDirector.secret(id).radius_tiles + 20.0) * 16.0)
		_world.dig(out)
		assert_bool(_world.is_solid(out)).is_false()
		for i in 40:
			_world.advance(60.0)
		_world.regrow_pass(-1)
		assert_bool(_world.is_solid(out)).override_failure_message("control cell should regrow").is_true()
		for cell in _cells_of(id):
			assert_bool(_world.is_solid(cell)).override_failure_message("%s grew shut at %s" % [id, cell]).is_false()


func test_found_survives_the_tin_and_never_fires_again() -> void:
	_enter(&"sunken_rowboat")
	var saved := _dir.to_dict()
	assert_array(saved.found).contains(["sunken_rowboat"])
	var again := RingsDirector.new()
	again.auto_tick = false
	add_child(again)
	again.setup(_world, _dir.spawn_point, 4, saved)
	var ids := []
	again.secret_found.connect(func(id: StringName) -> void: ids.append(id))
	_worm.head.global_position = again.cities[&"sunken_rowboat"]
	again.frame(0.1)
	assert_array(ids).is_empty()
	_worm.head.global_position = again.cities[&"fossil_hall"]
	again.frame(0.1)
	assert_array(ids).is_equal([&"fossil_hall"])
	remove_child(again)
	again.free()


func test_a_tin_from_before_these_secrets_gets_them_dug() -> void:
	var old_world := PolarWorld.new()
	old_world.build_overview = false
	old_world.setup_planet(RINGS, RADIUS, 4)
	add_child(old_world)
	old_world.set_physics_process(false)
	var old := RingsDirector.new()
	old.auto_tick = false
	add_child(old)
	# saved by the slice: built, the ant city found, no "carved" list yet
	old.setup(old_world, _dir.spawn_point, 4, { "built": true, "found": ["ant_city"], "eco": {}, "statics": [] })
	for id in NEW:
		var c: Vector2 = old.cities[id]
		assert_bool(old_world.is_solid(old_world.shape.cell_at(c))).override_failure_message("%s not dug in an old tin" % id).is_false()
	assert_array(old.to_dict().carved).contains(["ant_city", "sunken_rowboat", "fossil_hall"])
	for n in [old, old_world]:
		remove_child(n)
		n.free()
