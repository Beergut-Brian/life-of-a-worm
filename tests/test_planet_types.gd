## S-18, one test per space planet type (worm-gap-close-27): each of ice, jungle, junk, candy and
## clockwork loads from data/planets/, has its own foods (no food shared with another type, all
## edible to the stage-7 worm, and only its own foods drift round it in play), its own Star (eaten
## with the planet, nowhere else), and its own page in the collection book (grey until eaten whole,
## then found, and eating it pops that page). The order across a run is test_space_planets'.
## Contacts are resolved directly (resolve_contact), never through a pile of bodies.
class_name TestPlanetTypes
extends GdUnitTestSuite

const SPACE := "res://scenes/levels/space_stage.tscn"
const IDS := [&"ice", &"jungle", &"junk", &"candy", &"clockwork"]

var _pops: Array[StringName] = []


func before() -> void:
	SuiteSandbox.enter("planet_types")


func after() -> void:
	for p in Audio._pool:
		p.stop()
	for i in 3:
		await get_tree().process_frame
	for p in Audio._pool:
		p.stream = null
	SuiteSandbox.leave()


func before_test() -> void:
	Save.wipe()
	_pops.clear()
	get_tree().paused = false


func test_ice_planet() -> void:
	await _check(&"ice")


func test_jungle_planet() -> void:
	await _check(&"jungle")


func test_junk_planet() -> void:
	await _check(&"junk")


func test_candy_planet() -> void:
	await _check(&"candy")


func test_clockwork_planet() -> void:
	await _check(&"clockwork")


## A run seed whose first planet is `id` (the order is SpaceDrift.shuffled from the tin's seed).
func _seed_first(id: StringName) -> int:
	var life: SpaceLife = load(SpaceDrift.LIFE_PATH)
	for s in 500:
		if SpaceDrift.shuffled(life.planets, s)[0].id == id:
			return s
	return -1


func _stage() -> SpaceStage:
	var s: SpaceStage = load(SPACE).instantiate()
	s.players.append(Players.P1)
	add_child(s)
	s.set_process(false)          # no stick
	s.drift.set_process(false)    # no spawning or drifting off; _top_up is stepped by hand
	s.child_entered_tree.connect(func(n: Node) -> void:
		if n is PlanetPagePop:
			_pops.append((n as PlanetPagePop).data.id))
	return auto_free(s)


func _other_foods(id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for other in IDS:
		if other == id:
			continue
		for f in (load("res://data/planets/%s.tres" % other) as PlanetData).foods:
			out.append(f.id)
	return out


func _check(id: StringName) -> void:
	# --- it loads ---
	var path := "res://data/planets/%s.tres" % id
	assert_bool(ResourceLoader.exists(path)).override_failure_message("no %s" % path).is_true()
	var d = load(path)
	assert_bool(d is PlanetData).override_failure_message("%s is not PlanetData" % id).is_true()
	assert_str(String(d.id)).is_equal(String(id))
	assert_bool(load(SpaceDrift.LIFE_PATH).planets.has(d)).override_failure_message("%s not in space_life" % id).is_true()
	assert_int(d.meal).is_greater(0)

	# --- its own foods ---
	var others := _other_foods(id)
	var own: Array[StringName] = []
	assert_int(d.foods.size()).is_greater_equal(2)
	for f in d.foods:
		assert_bool(f is FoodData).is_true()
		assert_str(String(f.id)).is_not_empty()
		assert_bool(f.id in others).override_failure_message("%s food %s is another planet's" % [id, f.id]).is_false()
		assert_bool(f.id in own).override_failure_message("%s food %s twice" % [id, f.id]).is_false()
		assert_int(f.size_stage).is_less(7)          # food for the stage-7 worm
		assert_float(f.growth).is_greater(0.0)
		assert_float(f.radius).is_greater(0.0)
		own.append(f.id)

	# --- its own Star (only from eating the planet itself) ---
	var star: TraitData = d.star_trait
	assert_object(star).is_not_null()
	assert_bool(star.star).is_true()
	assert_str(String(star.star_planet)).is_equal(String(id))
	assert_float(d.star_chance).is_equal(0.0)

	# --- its page: one entry in the book's planets section, drawn from this very file ---
	var entries: Array = BookCatalog.entries(&"planets").filter(func(e): return e.id == id)
	assert_int(entries.size()).override_failure_message("%s has %d pages" % [id, entries.size()]).is_equal(1)
	assert_str((entries[0].data as Resource).resource_path).is_equal(path)
	assert_bool(BookCatalog.found_set()[&"planets"].has(id)).is_false()   # grey until eaten

	# --- in play: it comes first for this seed, only its own foods drift round it ---
	var seed_value := _seed_first(id)
	assert_int(seed_value).override_failure_message("no seed puts %s first" % id).is_greater_equal(0)
	Save.set_value("seed", seed_value)
	var s := _stage()
	var big := s.drift.big
	assert_object(big).is_not_null()
	assert_object(big.data).is_same(d)
	for i in d.live_foods + 2:
		s.drift._top_up(s.worms_centre())
	var round_it := s.drift.smalls(&"food")
	assert_int(round_it.size()).is_equal(d.live_foods)
	for f in round_it:
		assert_bool(f.data == d).is_true()
		assert_bool(own.has(f.food.id)).override_failure_message("%s spawned %s" % [id, f.food.id]).is_true()
	# Eating one of its foods fills one pip; it is not found yet.
	var w := s.worms[0]
	assert_int(s.resolve_contact(w, round_it[0])).is_equal(StageRule.FOOD)
	assert_int(big.pips_full).is_equal(1)
	assert_bool(BookCatalog.found_set()[&"planets"].has(id)).is_false()
	# Eaten whole: its Star on the worm, its page found and popped.
	big.ripen(d.ripe_stage)
	assert_int(s.resolve_contact(w, big)).is_equal(StageRule.FOOD)
	assert_bool(w.has_star(star.id)).is_true()
	assert_array(BookCatalog.found_set()[&"planets"]).is_equal([id])
	assert_array(_pops).is_equal([id])
	await get_tree().process_frame
