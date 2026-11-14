## Secrets (X-01 / X-06): the balloon stuck in the sky is a hidden place of its own. It is data
## (data/secrets/stuck_balloon.tres), stands exactly where SkyBalloon hangs, is reached by a worm
## that can live in the sky (the find fires at the balloon's tie, the thing a stage-5 worm bites),
## is found once with its own picture and sound, fills its tackle-box page, and holds the sky's
## party sweets: a food nothing else on the planet puts down. Older tins keep their statics.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const RADIUS := 300
const ID := &"stuck_balloon"
const FOOD := &"party_sweet"

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


func _at(p: Vector2) -> void:
	_worm.head.global_position = p
	_dir.frame(0.1)
	_dir.frame(0.1)


func _sweets() -> Array[RingPickup]:
	var out: Array[RingPickup] = []
	for st in _dir._statics:
		if st.food.id == FOOD:
			out.append(st.node)
	return out


func test_it_loads_from_data_in_the_sky_at_the_stuck_balloon() -> void:
	var s := RingsDirector.secret(ID)
	assert_object(s).override_failure_message("stuck_balloon not loaded from data/secrets").is_not_null()
	assert_str(String(s.ring)).is_equal("sky")
	assert_str(String(s.page)).is_equal("secret_stuck_balloon")
	assert_str(String(s.food)).is_equal(String(FOOD))
	assert_str(s.cue).is_not_empty()
	assert_bool(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % s.cue)).is_true()
	# one place, one spot: the hidden place sits on the balloon SkyLife already hangs
	var sky := RingsDirector.SKY
	assert_float(s.angle_from_start).is_equal_approx(sky.balloon_angle, 0.0001)
	assert_float(s.depth).is_equal_approx(sky.balloon_height, 0.0001)
	assert_vector(_dir.cities[ID]).is_equal_approx(_dir.balloon.position, Vector2(0.5, 0.5))
	# added after every other hidden place, so an older tin's statics keep their slots
	assert_bool(RingsDirector.LATE_SECRETS.back() == ID).is_true()
	assert_bool(SecretHalls.draws(ID)).is_true()
	assert_bool(_dir.get_node("Secret_%s" % ID) is SecretHalls).is_true()


func test_it_is_reachable_from_the_sky() -> void:
	var s := RingsDirector.secret(ID)
	var sky := RingsDirector.SKY
	var c: Vector2 = _dir.cities[ID]
	# in the open air of the sky band, nothing to dig
	assert_float(_dir.depth_of(c)).is_between(sky.inner, sky.outer)
	assert_bool(_world.shape.contains(_world.shape.cell_at(c))).is_false()
	# its sweets are sky food: a worm that can live up there (stage SkyLife.edible_from) eats them
	var d := load("res://data/foods/%s.tres" % FOOD) as RingFood
	assert_int(d.size_stage).is_equal(sky.edible_from)
	for p in _sweets():
		assert_float(_dir.depth_of(p.position)).is_between(sky.inner, sky.outer)
	# the find fires where a worm bites the balloon's tie (SkyBalloon), and not from the grass below
	var found := []
	_dir.secret_found.connect(func(id: StringName) -> void: found.append(id))
	_at(_dir.polar(s.angle_from_start, 1.0))
	assert_array(found).not_contains([ID])
	_at(_dir.balloon.to_global(_dir.balloon.tie.position))
	assert_array(found).contains([ID])


func test_it_is_found_once_with_its_picture_sound_and_page() -> void:
	var tlog := TackleLog.new()
	add_child(tlog)
	assert_array(tlog.entries[&"secrets"]).contains([ID])
	assert_array(tlog.entries[&"foods"]).contains([FOOD])
	_dir.secret_found.connect(tlog.note_secret)
	var ids := []
	_dir.secret_found.connect(func(id: StringName) -> void: ids.append(id))
	_at(_dir.cities[ID])
	_at(_dir.cities[ID])
	assert_array(ids).is_equal([ID])
	assert_int(Audio.played.get("secret_found", 0)).is_equal(1)
	assert_bool(tlog.is_found(&"secrets", ID)).is_true()
	var spot: SecretSpot = _dir.get_node("Secret_%s" % ID)
	assert_float(spot.beat_t).is_greater_equal(0.0)
	assert_bool(SecretLook.has(ID)).override_failure_message("draws as a gold star").is_true()
	for pic in spot.beat_pictures():
		assert_bool(PictoBubble.has_picture(pic)).override_failure_message("%s draws as a gold dot" % pic).is_true()
	assert_bool(_dir.to_dict().found.has(String(ID))).is_true()
	tlog.free()


func test_its_party_sweets_are_unique_and_tied_on_while_the_balloon_is_up() -> void:
	var s := RingsDirector.secret(ID)
	var sweets := _sweets()
	assert_int(sweets.size()).is_equal(s.food_count)
	# nothing else scatters it and no other hidden place hands it out
	for life in RingsDirector.LIVES + [RingsDirector.SKY, RingsDirector.SURFACE]:
		for f in life.scatter:
			assert_str(String(f.id)).is_not_equal(String(FOOD))
	for o in RingsDirector.SECRETS:
		if o.id != ID:
			assert_str(String(o.food)).is_not_equal(String(FOOD))
			assert_str(String(o.extra_food)).is_not_equal(String(FOOD))
	# each sweet hangs round the balloon, clear of its body
	for p in sweets:
		assert_float(p.position.distance_to(_dir.cities[ID])).is_greater(SkyBalloon.RADII.y + 10.0)
	var spot: SecretHalls = _dir.get_node("Secret_%s" % ID)
	assert_bool(spot.balloon_up()).is_true()
	assert_int(spot.sweets().size()).is_equal(s.food_count)
	sweets[0].take()
	assert_int(spot.sweets().size()).is_equal(s.food_count - 1)
	# popped: the sweets stay where they are, no ribbons hang from nothing
	_dir.balloon.pop()
	assert_bool(spot.balloon_up()).is_false()
	assert_bool(sweets[1].visible).is_true()


func test_an_older_tin_gains_it_and_keeps_its_statics() -> void:
	var statics: Array = _dir.to_dict().statics
	var n := RingsDirector.secret(ID).food_count
	var late := RingsDirector.late_food_count()   # D105 ring foods come after it
	var old := statics.slice(0, statics.size() - n - late)
	old[0] = [old[0][0], 7.0]
	var again := RingsDirector.new()
	again.auto_tick = false
	add_child(again)
	again.setup(_world, _dir.spawn_point, 4, { "built": true, "found": [], "eco": {}, "statics": old,
			"carved": ["ant_city", "fossil_hall", "geode_cathedral", "sunken_rowboat", "picnic_basket",
				"cloud_nest", "hollow_stump"] })
	var now: Array = again.to_dict().statics
	assert_int(now.size()).is_equal(statics.size())
	assert_float(float(now[0][1])).is_equal(7.0)
	for i in n:
		assert_str(String(now[now.size() - 1 - late - i][0])).is_equal(String(FOOD))
		assert_float(float(now[now.size() - 1 - late - i][1])).is_less(0.0)
	assert_bool(again.to_dict().carved.has(String(ID))).is_true()
	remove_child(again)
	again.free()
