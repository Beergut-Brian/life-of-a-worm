## The geode cathedral at the core (X-05, X-01 for the core) and the core ring in play (W-02, K-08):
## a sealed hall in the core rock a stage-5 worm digs into, its unique food, its tackle-box page and
## its find beat (the camera holds on the hall, the bubble opens with the cause: the worm biting
## through the wall). The core's own chain (core crystals) now runs in play, and the core is lit and
## colourful, never dark.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const RADIUS := 300
const ID := &"geode_cathedral"

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


func _enter() -> void:
	_worm.head.global_position = _dir.cities[ID]
	_dir.frame(0.1)
	_dir.frame(0.1)


func _spot() -> SecretSpot:
	return _dir.get_node("Secret_%s" % ID)


func test_the_cathedral_is_data_the_director_loads() -> void:
	var s := RingsDirector.secret(ID)
	assert_object(s).is_not_null()
	assert_bool(s is SecretData).is_true()
	assert_str(String(s.ring)).is_equal("core")
	assert_str(String(s.page)).is_equal("secret_geode_cathedral")
	assert_str(String(s.food)).is_equal("geode_heart")
	assert_str(s.cue).is_not_empty()
	assert_int(s.carve_stage).is_equal(5)
	assert_bool(SecretLook.has(ID)).is_true()


func test_it_is_a_sealed_hall_in_the_core_rock_dug_into_from_stage_5() -> void:
	var s := RingsDirector.secret(ID)
	var c: Vector2 = _dir.cities[ID]
	var band := _dir.ring_band(&"core")
	var reach := (s.radius_tiles + 4.0) * 16.0 / _dir.planet_radius_px
	assert_float(_dir.depth_of(c)).is_between(band.x + reach, band.y - reach)
	_worm.head.global_position = c
	_world.update_chunks(-1)
	assert_str(String(_world.ring_of(_world.shape.cell_at(c)).id)).is_equal("core")
	# the hall and its side rooms are dug and kept
	var cells: Array[Vector2i] = [_world.shape.cell_at(c)]
	for r in RingsDirector.rooms_of(s, c):
		cells.append(_world.shape.cell_at(c + Vector2(r.x, r.y)))
	for cell in cells:
		assert_bool(_world.is_solid(cell)).override_failure_message("not carved at %s" % cell).is_false()
		assert_bool(_world.in_keep_zone(cell)).is_true()
	# sealed: a ring of solid core rock round it (found by digging, never by a tunnel left open),
	# which a stage-4 worm cannot bite and a stage-5 worm can
	var up := c.normalized()
	var wall := _world.shape.cell_at(c + up * (s.radius_tiles + 2.0) * 16.0)
	assert_bool(_world.is_solid(wall)).is_true()
	assert_bool(_world.is_edible_by(4, wall)).is_false()
	assert_bool(_world.is_edible_by(5, wall)).is_true()
	# far from the start and the other hidden places
	assert_float(c.distance_to(_dir.spawn_point)).is_greater(30.0 * 16.0)
	for other in RingsDirector.SECRETS:
		if other.id != ID:
			assert_float(c.distance_to(_dir.cities[other.id])).is_greater(30.0 * 16.0)


func test_the_strangestone_seam_stays_whole() -> void:
	var s := RingsDirector.secret(ID)
	var c: Vector2 = _dir.cities[ID]
	var stone_r := RINGS.strangestone_radius * 16.0
	# nothing of the hall reaches the seam (its rooms included), and the seam is never dug
	assert_float(c.length() - (s.radius_tiles + 3.0) * 16.0).is_greater(stone_r)
	for r in RingsDirector.rooms_of(s, c):
		assert_float((c + Vector2(r.x, r.y)).length() - r.z - 32.0).is_greater(stone_r)
	_worm.head.global_position = Vector2.ZERO
	_world.update_chunks(-1)
	for cell in [Vector2i(0, 0), Vector2i(-1, -1), Vector2i(4, 0), Vector2i(-5, 0)]:
		assert_bool(_world.is_solid(cell)).is_true()
		assert_bool(_world.is_edible_by(9, cell)).override_failure_message("seam edible at %s" % cell).is_false()


func test_it_is_found_once_by_getting_in() -> void:
	var ids := []
	_dir.secret_found.connect(func(id: StringName) -> void: ids.append(id))
	_dir.frame(0.1)
	assert_array(ids).is_empty()
	_enter()
	_enter()
	assert_array(ids).is_equal([ID])
	assert_int(Audio.played.get("secret_found", 0)).is_equal(1)


func test_the_find_shows_its_cause_with_a_camera_beat_and_a_why_bubble() -> void:
	var spot := _spot()
	var cam := PolarCamera.new()
	add_child(cam)
	cam.max_fit_index = 3   # a stage-5 worm's cap (the level rewrites it every frame)
	cam.min_fit_index = 0
	spot.camera = cam
	_enter()
	assert_int(cam.lean_in).is_equal(1)   # one step closer while it holds
	cam.targets = [_worm.head]
	cam.position = spot.global_position
	assert_int(cam.fit_index()).is_equal(4)
	# the bubble opens with the cause (the worm biting through the wall), then the place, its food
	# and the tackle box; every picture is drawn, none is a fallback dot
	assert_object(spot.get_node_or_null("FoundBubble")).is_not_null()
	assert_array(spot.beat_pictures()).is_equal([&"secret_dig", &"secret:geode_cathedral", &"secret_food:geode_heart", &"secret_box"])
	for pic in spot.beat_pictures():
		assert_bool(PictoBubble.has_picture(pic)).override_failure_message("%s draws as a gold dot" % pic).is_true()
	# the camera holds on the hall for the beat, then hands back to the worms
	assert_object(cam.centre_override).is_not_null()
	assert_vector(cam.centre_override as Vector2).is_equal_approx(spot.global_position, Vector2.ONE)
	for i in 30:
		spot._process(0.1)
	assert_object(cam.centre_override).is_null()   # back after the 2.5 s hold, bubble still up
	assert_int(cam.lean_in).is_equal(0)
	assert_float(spot.beat_t).is_greater_equal(0.0)
	for i in 30:
		spot._process(0.1)
	assert_float(spot.beat_t).is_less(0.0)
	# an older hidden place keeps its plain beat: no lead picture, no camera hold
	var row: SecretSpot = _dir.get_node("Secret_sunken_rowboat")
	assert_array(row.beat_pictures()).is_equal([&"secret:sunken_rowboat", &"secret_food:ship_biscuit", &"secret_box"])
	cam.free()


func test_the_camera_beat_never_steals_a_camera_someone_else_moved() -> void:
	var spot := _spot()
	var cam := PolarCamera.new()
	add_child(cam)
	spot.camera = cam
	_enter()
	cam.centre_override = Vector2(5, 5)   # another beat took the camera meanwhile
	for i in 40:
		spot._process(0.1)
	assert_object(cam.centre_override).is_equal(Vector2(5, 5))
	assert_int(cam.lean_in).is_equal(0)
	cam.free()


func test_its_unique_food_is_there_and_waits_for_stage_5() -> void:
	var s := RingsDirector.secret(ID)
	var d: RingFood = load("res://data/foods/geode_heart.tres")
	assert_bool(d is RingFood).is_true()
	assert_str(String(d.ring)).is_equal("core")
	assert_int(d.size_stage).is_equal(5)
	assert_int(d.look).is_equal(RingFood.Look.GEODE)
	var near := 0
	var all := 0
	for f in get_tree().get_nodes_in_group(&"food"):
		if f.get("data") and f.data.id == &"geode_heart":
			all += 1
			if f.global_position.distance_to(_dir.cities[ID]) < s.radius_tiles * 16.0:
				near += 1
	assert_int(near).is_equal(s.food_count)
	assert_int(all).is_equal(s.food_count)
	for life in RingsDirector.LIVES:
		for f in life.scatter:
			assert_str(String(f.id)).is_not_equal("geode_heart")
	_worm.model.start_at_stage(4)
	assert_bool(_worm.can_eat(d)).is_false()
	_worm.model.start_at_stage(5)
	assert_bool(_worm.can_eat(d)).is_true()


func test_it_gives_its_tackle_box_page() -> void:
	var tlog := TackleLog.new()
	add_child(tlog)
	assert_array(tlog.entries[&"secrets"]).contains([ID])
	assert_array(tlog.entries[&"foods"]).contains([&"geode_heart"])
	_dir.secret_found.connect(tlog.note_secret)
	_enter()
	assert_bool(tlog.is_found(&"secrets", ID)).is_true()
	assert_int(Audio.played.get("page_new", 0)).is_equal(1)
	tlog.free()


# --- W-02: the core in play --------------------------------------------------------------------

func test_core_crystals_are_scattered_in_the_core_in_play() -> void:
	var lives: Array[StringName] = []
	for l in RingsDirector.LIVES:
		lives.append(l.ring)
	assert_array(lives).contains([&"core"])
	var band := _dir.ring_band(&"core")
	var n := 0
	for f in get_tree().get_nodes_in_group(&"food"):
		if f.get("data") and f.data.id == &"core_crystal":
			n += 1
			assert_float(_dir.depth_of(f.position)).is_between(band.x, band.y)
	assert_int(n).is_greater_equal(4)
	assert_int((load("res://data/foods/core_crystal.tres") as RingFood).look).is_equal(RingFood.Look.CRYSTAL)


func test_lava_blobs_are_counted_but_never_spawned_without_a_body() -> void:
	assert_bool(_dir.ecology.rules.has(&"lava_blob")).is_true()
	assert_int(_dir.wanted(_dir.ecology.rules[&"lava_blob"])).is_equal(0)
	assert_bool(_dir.ecology.rules.has(&"core_crystal")).is_true()


func test_an_old_tin_keeps_eaten_foods_only_in_their_own_slots() -> void:
	# saved before the core chain: slot 0 says "a crumb was eaten", but slot 0 now holds whatever
	# the first chain scatters; a mismatched id starts uneaten instead of hiding the wrong food
	var again := RingsDirector.new()
	again.auto_tick = false
	add_child(again)
	again.setup(_world, _dir.spawn_point, 4, { "built": true, "found": [], "eco": {}, "statics": [["not_a_food", 1.0]] })
	var first: Dictionary = again._statics[0]
	assert_float((first.node as RingPickup).gone_at).is_less(0.0)
	remove_child(again)
	again.free()


# --- K-08: lit and colourful ---------------------------------------------------------------------

func test_the_cathedral_is_lit_and_colourful_never_dark() -> void:
	for col in SecretSpot.GEMS:
		assert_float(col.v).override_failure_message("%s too dark" % col).is_greater(0.8)
		assert_float(col.s).override_failure_message("%s too grey" % col).is_greater(0.4)
	var hues := {}
	for col in SecretSpot.GEMS:
		hues[int(col.h * 6.0)] = true
	assert_int(hues.size()).is_greater_equal(4)
	var core: RingDef = null
	for r in RINGS.rings:
		if r.id == &"core":
			core = r
	assert_float(core.hue.v).is_greater(0.6)
	assert_float(core.alt_hue.v).is_greater(0.6)
