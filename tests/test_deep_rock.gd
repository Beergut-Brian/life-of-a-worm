## The deep-rock hooks (W-03) and the lava blob's bounce (W-02), feature/worm-deep-rock-1:
## rock beetles have a body and live near a worm in the deep rock; deep_rock_life runs in play
## (fossils scattered, ore nuggets and beetles from the counters); ore nuggets and fossils have their
## own placeholder looks; a lava blob knocks a smaller worm's head away on contact (a squash, a
## boing, a push, never a steer); feature/worm-lava-blob-1: lava blobs spawn live in the core and its
## rim, bounce stage 1-4 worms and are food (cowering) from stage 5.
## Saves: the suite runs in its own sandbox profile (SuiteSandbox), never the family's tin.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const WORM := preload("res://scenes/players/worm.tscn")
const ROCK_BEETLE := preload("res://scenes/creatures/rock_beetle.tscn")
const LAVA_BLOB := preload("res://scenes/creatures/lava_blob.tscn")
const RADIUS := 300

var _world: PolarWorld
var _dir: RingsDirector
var _worm: Worm
var _extra: Array[Node] = []


func before() -> void:
	SuiteSandbox.enter("deep_rock")


func after() -> void:
	SuiteSandbox.leave()


func before_test() -> void:
	Audio.played.clear()
	_extra.clear()


func after_test() -> void:
	for n in _extra + [_dir, _worm, _world]:
		if is_instance_valid(n):
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.free()
	_dir = null
	_worm = null
	_world = null


func _make_worm(at: Vector2, stage: int) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = Players.P1
	w.model = WormGrowth.new()
	w.model.start_at_stage(stage)
	w.set_meta("start_pos", at)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	w.set_physics_process(false)
	w.head.global_position = at
	return w


## A planet with the rings on it and a worm sitting in the middle of `ring`.
func _planet(ring: StringName, stage: int) -> void:
	_world = PolarWorld.new()
	_world.build_overview = false
	_world.setup_planet(RINGS, RADIUS, 4)
	add_child(_world)
	_world.set_physics_process(false)
	var start := Vector2.from_angle(-PI / 2.0) * RADIUS * 16.0 * 0.76
	_worm = _make_worm(start, stage)
	_dir = RingsDirector.new()
	_dir.auto_tick = false
	add_child(_dir)
	_dir.setup(_world, start, 4, {})
	var band := _dir.ring_band(ring)
	_worm.head.global_position = _dir.polar(0.0, (band.x + band.y) * 0.5)
	_world.track(_worm.head)
	_world.update_chunks(-1)


# --- W-03: the rock beetle's body ----------------------------------------------------------------

func test_the_rock_beetle_scene_loads_from_its_data() -> void:
	var c: Creature = ROCK_BEETLE.instantiate()
	_extra.append(c)
	assert_object(c.data).is_not_null()
	assert_str(String(c.data.id)).is_equal("rock_beetle")
	assert_int(c.data.behaviour).is_equal(CreatureData.Behaviour.TRUNDLE)
	assert_float(c.data.telegraph_time()).is_equal_approx(1.4, 0.001)
	assert_str(String(c.data.ring)).is_equal("deep_rock")
	assert_bool(c.data.is_threat_to(3)).is_true()
	assert_bool(c.data.is_threat_to(4)).is_false()


func test_rock_beetles_are_live_bodies_in_the_deep_rock() -> void:
	_planet(&"deep_rock", 3)
	var rule: PopulationRule = _dir.ecology.rules[&"rock_beetle"]
	assert_str(rule.live).is_equal("res://scenes/creatures/rock_beetle.tscn")
	assert_int(_dir.wanted(rule)).is_greater(0)
	for i in 6:
		_dir.fit_live()
	var bodies := _dir.live_of(&"rock_beetle")
	assert_int(bodies.size()).is_greater(0)
	assert_int(bodies.size()).is_less_equal(rule.live_max)
	var band := _dir.ring_band(&"deep_rock")
	for b in bodies:
		assert_bool(b is Creature).is_true()
		assert_str(String(b.data.id)).is_equal("rock_beetle")
		assert_str(String(b.species)).is_equal("rock_beetle")
		assert_float(_dir.depth_of(b.position)).is_between(band.x, band.y)
		assert_float(b.position.distance_to(_worm.head_position())).is_greater_equal(RingsDirector.SPAWN_NEAR - 1.0)
	# eating one thins the counter (and thinner beetles let the ore nuggets build up:
	# tests/test_rings_content.gd::test_thinning_rock_beetles_lets_ore_nuggets_build_up)
	var before_n := _dir.ecology.count(&"rock_beetle")
	(bodies[0] as Creature).take()
	assert_float(_dir.ecology.count(&"rock_beetle")).is_less(before_n)


# --- W-03: deep rock life in play ----------------------------------------------------------------

func test_deep_rock_life_is_in_lives_and_scatters_its_pickups() -> void:
	assert_bool(RingsDirector.LIVES.has(preload("res://data/rings/deep_rock_life.tres"))).is_true()
	_planet(&"deep_rock", 4)
	assert_bool(_dir.ecology.rules.has(&"ore_nugget")).is_true()
	var band := _dir.ring_band(&"deep_rock")
	var fossils := 0
	for s in _dir._statics:
		if s.food.id == &"fossil":
			fossils += 1
			assert_float(_dir.depth_of(s.node.position)).is_between(band.x, band.y)
	assert_int(fossils).is_equal(5)
	# ore nuggets come live from their counter, near the worm
	for i in 6:
		_dir.fit_live()
	var nuggets := _dir.live_of(&"ore_nugget")
	assert_int(nuggets.size()).is_greater(0)
	for n in nuggets:
		assert_bool(n is RingPickup).is_true()
		assert_float(_dir.depth_of(n.position)).is_between(band.x, band.y)
	# a stage-4 worm can eat both
	assert_bool(_worm.can_eat(load("res://data/foods/fossil.tres"))).is_true()
	assert_bool(_worm.can_eat(load("res://data/foods/ore_nugget.tres"))).is_true()


func test_a_scattered_fossil_grows_back_where_it_was() -> void:
	_planet(&"deep_rock", 4)
	var slot: Dictionary = {}
	for s in _dir._statics:
		if s.food.id == &"fossil":
			slot = s
			break
	var p: RingPickup = slot.node
	var home := p.home
	p.take()
	assert_float(p.gone_at).is_greater_equal(0.0)
	_world.clock += (slot.food as RingFood).regrow_time + 1.0
	_dir.tick()
	assert_bool(p.is_available()).is_true()
	assert_vector(p.position).is_equal_approx(home, Vector2(0.5, 0.5))


# --- the placeholder looks -----------------------------------------------------------------------

func test_nugget_and_fossil_have_their_own_looks_that_differ() -> void:
	var nugget := load("res://data/foods/ore_nugget.tres") as RingFood
	var fossil := load("res://data/foods/fossil.tres") as RingFood
	assert_int(nugget.look).is_equal(RingFood.Look.NUGGET)
	assert_int(fossil.look).is_equal(RingFood.Look.FOSSIL)
	assert_int(RingFood.Look.NUGGET).is_not_equal(RingFood.Look.FOSSIL)
	var a := RingPickup.look_shape(RingFood.Look.NUGGET, 14.0)
	var b := RingPickup.look_shape(RingFood.Look.FOSSIL, 14.0)
	assert_int(a.size()).is_greater_equal(6)
	assert_int(b.size()).is_greater_equal(6)
	assert_bool(a == b).is_false()
	# the nugget is a closed lumpy outline (not a circle); the fossil curls in toward the middle
	var lo := INF
	var hi := 0.0
	for p in a:
		lo = minf(lo, p.length())
		hi = maxf(hi, p.length())
	assert_float(hi - lo).is_greater(14.0 * 0.15)
	assert_float(b[b.size() - 1].length()).is_less(b[0].length() * 0.3)
	assert_bool(RingPickup.look_shape(RingFood.Look.BLOB, 14.0).is_empty()).is_true()


# --- W-02: the lava blob's bounce ----------------------------------------------------------------

func _blob_and_worm(stage: int, offset: Vector2) -> Creature:
	var blob: Creature = LAVA_BLOB.instantiate()
	blob.position = Vector2(400, 400)
	add_child(blob)
	_extra.append(blob)
	blob.set_physics_process(false)
	_worm = _make_worm(blob.global_position + offset, stage)
	return blob


func test_the_lava_blob_scene_bounces() -> void:
	var c: Creature = LAVA_BLOB.instantiate()
	_extra.append(c)
	assert_str(String(c.data.id)).is_equal("lava_blob")
	assert_int(c.data.behaviour).is_equal(CreatureData.Behaviour.BOUNCE)
	assert_float(c.data.bounce).is_greater(0.0)


func test_a_lava_blob_contact_pushes_the_worm_away_from_the_blob() -> void:
	var dir := Vector2(1, -0.4).normalized()
	var blob := _blob_and_worm(4, dir * 0.0)
	var r := blob.data.radius
	_worm.head.global_position = blob.global_position + dir * (r + 6.0)
	var d0 := _worm.head_position().distance_to(blob.global_position)
	var biggest_step := 0.0
	for i in 40:
		var was := _worm.head_position()
		blob.step(1.0 / 60.0)
		biggest_step = maxf(biggest_step, was.distance_to(_worm.head_position()))
	# a push the eye can follow: spread over frames, never a teleport, and only a short way back
	assert_float(biggest_step).is_less(blob.data.bounce * 0.2)
	assert_float(_worm.head_position().distance_to(blob.global_position) - d0).is_less(blob.data.bounce * 1.1)
	var moved := _worm.head_position() - (blob.global_position + dir * (r + 6.0))
	assert_int(blob.bounces).is_equal(1)
	assert_float(_worm.head_position().distance_to(blob.global_position)).is_greater(d0 + blob.data.bounce * 0.8)
	# straight away from the blob, not sideways
	assert_float(moved.normalized().dot(dir)).is_greater(0.98)
	# the cause on screen and in the ear: a squash and a cue that exists
	assert_int(Audio.played.get(Creature.BOUNCE_CUE, 0)).is_equal(1)
	assert_bool(FileAccess.file_exists("res://assets/audio/sfx/%s.ogg" % Creature.BOUNCE_CUE)).is_true()


func test_the_bounce_squashes_the_blob_and_swells_first() -> void:
	var blob := _blob_and_worm(4, Vector2(blob_r() + Creature.SWELL_RANGE * 0.5, 0))
	blob.step(1.0 / 60.0)
	assert_int(blob.bounces).is_equal(0)
	for i in 20:
		blob.step(1.0 / 60.0)
	assert_float(blob.draw_scale()).is_greater(1.0)   # it swells as the worm comes
	assert_int(Audio.played.get(blob.data.windup_cue, 0)).is_equal(1)
	_worm.head.global_position = blob.global_position + Vector2(blob_r() + 4.0, 0)
	blob.step(1.0 / 60.0)
	assert_int(blob.bounces).is_equal(1)
	assert_float(blob._squash).is_greater(0.0)


func blob_r() -> float:
	return (load("res://data/creatures/lava_blob.tres") as CreatureData).radius


func test_a_worm_big_enough_to_eat_the_blob_is_never_bounced() -> void:
	# stage 5 (the stage the core opens at) eats it, like the other core foods
	var blob := _blob_and_worm(5, Vector2(blob_r() + 4.0, 0))
	var at := _worm.head_position()
	for i in 30:
		blob.step(1.0 / 60.0)
	assert_int(blob.bounces).is_equal(0)
	assert_vector(_worm.head_position()).is_equal(at)
	assert_bool(blob.can_be_eaten_by(_worm)).is_true()
	assert_bool(_worm.can_eat(blob.data)).is_true()
	# it cowers, never swells: food never looks bigger than the worm that can eat it
	assert_float(blob.draw_scale()).is_equal_approx(0.85, 0.001)
	assert_int(Audio.played.get(blob.data.windup_cue, 0)).is_equal(0)


func test_a_stage_5_worm_eats_a_lava_blob_with_its_mouth() -> void:
	var blob := _blob_and_worm(5, Vector2(200, 0))
	var eaten := [0]
	blob.taken.connect(func(_c: Creature) -> void: eaten[0] += 1)
	var grew := [0]
	_worm.ate.connect(func(_p: int, _w: StringName, _g: float) -> void: grew[0] += 1)
	_worm.set_physics_process(true)
	blob.global_position = _worm.mouth_position()
	for i in 6:
		await get_tree().physics_frame
	assert_int(eaten[0]).is_equal(1)
	assert_int(grew[0]).is_greater_equal(1)
	# eaten, never bounced: no boing
	assert_int(Audio.played.get(Creature.BOUNCE_CUE, 0)).is_equal(0)


func test_the_bounce_never_steers_and_waits_between_bounces() -> void:
	var blob := _blob_and_worm(4, Vector2(blob_r() + 4.0, 0))
	var heading := _worm.heading
	blob.step(1.0 / 60.0)
	assert_int(blob.bounces).is_equal(1)
	# held against it, it bounces again only after the cooldown
	_worm.head.global_position = blob.global_position + Vector2(blob_r() + 4.0, 0)
	blob.step(1.0 / 60.0)
	assert_int(blob.bounces).is_equal(1)
	assert_float(_worm.heading).is_equal(heading)


func test_lava_blobs_spawn_live_in_the_core_near_a_worm() -> void:
	_planet(&"core", 5)
	var rule: PopulationRule = _dir.ecology.rules[&"lava_blob"]
	assert_str(rule.live).is_equal("res://scenes/creatures/lava_blob.tscn")
	assert_int(rule.live_max).is_greater(0)
	assert_int(_dir.wanted(rule)).is_greater(0)
	for i in 6:
		_dir.fit_live()
	var bodies := _dir.live_of(&"lava_blob")
	assert_int(bodies.size()).is_greater(0)
	assert_int(bodies.size()).is_less_equal(rule.live_max)
	var band := _dir.ring_band(&"core")
	var seam := float(RINGS.strangestone_radius) / RADIUS
	for b in bodies:
		assert_bool(b is Creature).is_true()
		assert_str(String(b.data.id)).is_equal("lava_blob")
		# in the core (or its rim), never inside the unbreakable seam
		assert_float(_dir.depth_of(b.position)).is_between(seam, band.y + 0.02)
		assert_float(b.position.distance_to(_worm.head_position())).is_greater_equal(RingsDirector.SPAWN_NEAR - 1.0)
	# eating one thins the counter
	var before_n := _dir.ecology.count(&"lava_blob")
	(bodies[0] as Creature).take()
	assert_float(_dir.ecology.count(&"lava_blob")).is_less(before_n)
	# core crystals still come live from the same life
	assert_int(_dir.live_of(&"core_crystal").size()).is_greater(0)


func test_lava_blobs_also_sit_on_the_core_rim_where_a_stage_4_worm_can_meet_one() -> void:
	_planet(&"deep_rock", 4)
	var band := _dir.ring_band(&"core")
	# a stage-4 worm digging the bottom of the deep rock, just above the core
	_worm.head.global_position = _dir.polar(0.0, band.y + 0.04)
	_world.track(_worm.head)
	_world.update_chunks(-1)
	var rule: PopulationRule = _dir.ecology.rules[&"lava_blob"]
	assert_float(rule.depth_max).is_greater(band.y)
	var rim := 0
	for attempt in 20:
		for b in _dir.live_of(&"lava_blob"):
			b.free()
		for i in 3:
			_dir.fit_live()
		for b in _dir.live_of(&"lava_blob"):
			if _dir.depth_of(b.position) > band.y:
				rim += 1
				assert_bool(b.can_bounce(_worm)).is_true()
	assert_int(rim).is_greater(0)