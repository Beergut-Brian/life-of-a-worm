## Stage 7's drifting planets (S-11, S-18, W-08, L-19): five themed planet types as data in a seeded
## random order, small things are food through the stage's eaten path, a big planet bumps (and shows
## it), its pips fill until it ripens, star traits ride on some foods, and the sun is the last meal.
extends GdUnitTestSuite

const SPACE := "res://scenes/levels/space_stage.tscn"
const IDS: Array[StringName] = [&"ice", &"jungle", &"junk", &"candy", &"clockwork"]


func before() -> void:
	SuiteSandbox.enter("space_planets")


func after() -> void:
	SuiteSandbox.leave()


func before_test() -> void:
	Save.wipe()
	Save.set_value("seed", 4242)


func _stage() -> SpaceStage:
	var s: SpaceStage = load(SPACE).instantiate()
	s.players.append(Players.P1)
	add_child(s)
	s.set_process(false)          # no stick
	s.drift.set_process(false)    # no spawning or drifting off unless a test asks
	return auto_free(s)


## Everything but `keep` goes far away, so a contact never hinges on a pile.
func _clear_except(s: SpaceStage, keep: Array) -> void:
	for c in s.drift.get_children():
		if c is SpacePlanet and not c in keep:
			c.position += Vector2(20000, 20000)
			c.linear_velocity = Vector2.ZERO


func _eat_planet(s: SpaceStage) -> void:
	var w := s.worms[0]
	var big := s.drift.big
	big.ripen(big.data.ripe_stage)
	assert_int(s.resolve_contact(w, big)).is_equal(StageRule.FOOD)
	s.drift.begin()


func test_five_planet_types_are_data() -> void:
	var seen: Array[StringName] = []
	for id in IDS:
		var d = load("res://data/planets/%s.tres" % id)
		assert_bool(d is PlanetData).override_failure_message("%s is not PlanetData" % id).is_true()
		assert_str(String(d.id)).is_equal(String(id))
		assert_int(d.size_stage).is_greater(7)          # bigger than the worm: it bumps
		assert_int(d.ripe_stage).is_less(7)
		assert_int(d.foods.size()).is_greater_equal(2)
		for f in d.foods:
			assert_bool(f is FoodData).is_true()
			assert_int(f.size_stage).is_less(7)
			assert_bool(f.id in seen).override_failure_message("food %s twice" % f.id).is_false()
			seen.append(f.id)
		assert_bool(d.star_trait is TraitData).is_true()
		assert_int(d.meal).is_greater(0)
	var radii := {}
	for id in IDS:
		radii[load("res://data/planets/%s.tres" % id).radius] = true
	assert_int(radii.size()).is_equal(5)                   # each its own size


func test_space_ring_uses_the_rings_pattern() -> void:
	var life = load(SpaceDrift.LIFE_PATH)
	assert_bool(life is SpaceLife).is_true()
	assert_bool(life is RingLife).is_true()
	assert_str(String(life.ring)).is_equal("space")
	assert_int(life.planets.size()).is_equal(5)
	var ids: Array[StringName] = []
	for r in life.species:
		ids.append(r.id)
	for want in [&"moon", &"comet", &"planet", &"sun"]:
		assert_bool(want in ids).override_failure_message("no %s species" % want).is_true()
	assert_int(life.moon.size_stage).is_less(7)
	assert_int(life.comet.size_stage).is_less(7)
	assert_int(life.sun_stage).is_less(7)                  # food once it comes (after all five)
	var e := RingEcology.from_lives([life], 1)
	e.step(60.0)
	assert_float(e.count(&"moon")).is_greater(0.0)


func test_order_is_random_per_run_and_seeded() -> void:
	var life: SpaceLife = load(SpaceDrift.LIFE_PATH)
	var a := SpaceDrift.shuffled(life.planets, 7)
	var b := SpaceDrift.shuffled(life.planets, 7)
	assert_array(a).is_equal(b)
	var orders := {}
	for seed_value in 12:
		var ids := SpaceDrift.shuffled(life.planets, seed_value).map(func(d): return String(d.id))
		var sorted := ids.duplicate()
		sorted.sort()
		assert_int(ids.size()).is_equal(5)
		assert_array(sorted).is_equal(["candy", "clockwork", "ice", "jungle", "junk"])
		orders[",".join(ids)] = true
	assert_int(orders.size()).is_greater(3)


func test_a_big_planet_drifts_with_no_gravity() -> void:
	var s := _stage()
	assert_bool(s.gravity_on()).is_false()
	assert_object(s.planet).is_same(s.drift.big)
	assert_int(StageRule.relation(s.worms[0].size_stage, s.planet.size_stage)).is_equal(StageRule.THREAT)
	assert_float(s.planet.gravity_scale).is_equal(0.0)
	var start := s.planet.position
	for i in 20:
		await get_tree().physics_frame
	assert_float(s.planet.position.distance_to(start)).is_greater(3.0)


func test_small_foods_are_eaten_and_fill_the_pips_then_the_planet_ripens() -> void:
	var s := _stage()
	var w := s.worms[0]
	var big := s.drift.big
	var d := big.data
	var ate: Array = []
	s.ate.connect(func(_p, what, _g): ate.append(what))
	var segs := w.segments
	for i in d.meal:
		s.drift._top_up(s.worms_centre())
		var foods := s.drift.smalls(&"food")
		assert_int(foods.size()).is_greater(0)
		assert_bool(big.ripe).is_false()
		assert_int(s.resolve_contact(w, foods[0])).is_equal(StageRule.FOOD)
		assert_bool(foods[0].eaten).is_true()
		assert_int(big.pips_full).is_equal(i + 1)            # the cause shows, one pip a bite
	assert_int(w.segments).is_equal(segs + d.meal)
	assert_int(ate.size()).is_equal(d.meal)
	assert_bool(big.ripe).is_true()
	assert_int(StageRule.relation(w.size_stage, big.size_stage)).is_equal(StageRule.FOOD)
	var done: Array = []
	s.drift.planet_done.connect(func(id): done.append(id))
	assert_int(s.resolve_contact(w, big)).is_equal(StageRule.FOOD)
	assert_array(done).is_equal([d.id])
	assert_int(s.drift.visit).is_equal(1)
	s.drift.begin()
	assert_object(s.drift.big).is_not_null()
	assert_object(s.drift.big.data).is_not_same(d)


func test_a_big_planet_bumps_the_worm_through_physics_and_shows_it() -> void:
	var s := _stage()
	var w := s.worms[0]
	var big := s.drift.big
	_clear_except(s, [big])
	big.linear_velocity = Vector2.ZERO
	w.position = Vector2.ZERO
	big.position = Vector2(w.seg_radius * 1.1 + 62.0 + big.radius - 10.0, 0)   # just inside the mouth
	var segs := w.segments
	var bumps: Array = []
	for i in 8:
		await get_tree().physics_frame
		if big.bump_showing():
			bumps.append(i)
	assert_bool(bumps.is_empty()).is_false()
	assert_bool(big.eaten).is_false()
	assert_int(w.segments).is_equal(segs)
	assert_float(w.velocity.x).is_less(-100.0)              # knocked back, away from the planet
	assert_float(big._bump_at.rotated(big.rotation).x).is_less(0.0)   # the ring shows on the worm's side


func test_a_star_trait_shows_on_the_worm_once() -> void:
	var s := _stage()
	var w := s.worms[0]
	var d := s.drift.big.data
	s.drift._top_up(s.worms_centre())
	var food: SpacePlanet = s.drift.smalls(&"food")[0]
	food.star_trait = d.star_trait
	var speed := w.max_speed
	var got: Array = []
	s.drift.star_earned.connect(func(p, id): got.append([p, id]))
	s.resolve_contact(w, food)
	assert_bool(w.has_star(d.star_trait.id)).is_true()
	assert_array(got).is_equal([[w.player, d.star_trait.id]])
	assert_bool(s.drift.star_taken(d.star_trait.id)).is_true()
	var changed: bool = w.max_speed != speed or w.knock_scale != 1.0 or d.star_trait.add.has("space_reach") \
			or d.star_trait.add.has("space_turn") or d.star_trait.add.has("space_pull")   # StarAward drives these
	assert_bool(changed).is_true()
	# no second one of this planet's star this run
	for i in 40:
		s.drift._top_up(s.worms_centre())
	for f in s.drift.smalls(&"food"):
		assert_object(f.star_trait).is_null()


func test_the_sun_comes_last_and_is_the_last_meal() -> void:
	var s := _stage()
	var w := s.worms[0]
	for i in 5:
		assert_object(s.drift.sun).is_null()
		_eat_planet(s)
	assert_int(s.drift.done.size()).is_equal(5)
	assert_object(s.drift.big).is_null()
	var sun := s.drift.sun
	assert_object(sun).is_not_null()
	assert_object(s.planet).is_same(sun)
	assert_bool(sun.ripe).is_true()
	assert_int(sun.pips).is_equal(5)
	assert_int(sun.pips_full).is_equal(5)                   # why it is food: all five, shown
	assert_int(StageRule.relation(w.size_stage, sun.size_stage)).is_equal(StageRule.FOOD)
	var fired: Array = []
	s.drift.sun_eaten.connect(func(p): fired.append(p))
	assert_int(s.resolve_contact(w, sun)).is_equal(StageRule.FOOD)
	assert_array(fired).is_equal([w.player])
	assert_bool(s.sun_why.is_showing()).is_true()           # the shown cause at that moment
	assert_array(s.sun_why.colors).has_size(5)
	assert_bool(Save.get_value("sun_eaten", false)).is_true()
	s.drift.begin()
	assert_object(s.drift.sun).is_null()
	assert_object(s.drift.big).is_null()


func test_space_is_kept_in_the_tin() -> void:
	var s := _stage()
	var order := s.drift.order.map(func(d): return d.id)
	_eat_planet(s)
	_eat_planet(s)
	var saved: Dictionary = Save.get_value(SpaceDrift.SAVE_KEY, {})
	assert_int(int(saved.get("visit", 0))).is_equal(2)
	s.queue_free()
	await get_tree().process_frame
	var t := _stage()
	assert_array(t.drift.order.map(func(d): return d.id)).is_equal(order)
	assert_int(t.drift.visit).is_equal(2)
	assert_object(t.drift.big.data).is_same(t.drift.order[2])


func test_nothing_steers_the_worm() -> void:
	var s := _stage()
	s.drift.set_process(true)
	var w := s.worms[0]
	w.position = Vector2(-300, -200)
	for i in 30:
		s.step_world(1.0 / 60.0)
		await get_tree().physics_frame
	assert_vector(w.position).is_equal_approx(Vector2(-300, -200), Vector2(0.5, 0.5))
	assert_vector(w.velocity).is_equal(Vector2.ZERO)
