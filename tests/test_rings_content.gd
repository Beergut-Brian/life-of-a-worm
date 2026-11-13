## Ring content data (feature/rings-content-1, PLAN-STATUS W-02 core, W-03 deep rock): every new
## food, creature and ring food chain loads, sits in the right ring and is edible from the ring's
## stage; the two new food chains run on RingEcology without emptying or blowing up.
## Data only: nothing here spawns them (see PLAN-STATUS W-02 / W-03 for the missing hooks).
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const HEAD_R := 8.0   # a stage-1 worm's head; grows Worm.SIZE_STEP per stage (test_creatures_rules)


func _ring(id: StringName) -> RingDef:
	for r: RingDef in RINGS.rings:
		if r.id == id:
			return r
	return null


func _food(id: String) -> RingFood:
	var f = load("res://data/foods/%s.tres" % id)
	assert_object(f).override_failure_message("%s.tres should load as a RingFood" % id).is_instanceof(RingFood)
	return f


func _creature(id: String) -> CreatureData:
	var c = load("res://data/creatures/%s.tres" % id)
	assert_object(c).override_failure_message("%s.tres should load as CreatureData" % id).is_instanceof(CreatureData)
	return c


func _life(id: String) -> RingLife:
	var l = load("res://data/rings/%s_life.tres" % id)
	assert_object(l).override_failure_message("%s_life.tres should load as RingLife" % id).is_instanceof(RingLife)
	return l


## Bigger than every smaller worm by eye (the same check test_creatures_rules runs on its list).
func _looks_bigger_than_smaller_worms(id: StringName, radius: float, stage: int) -> void:
	for s in range(1, stage):
		var head := HEAD_R * (1.0 + Worm.SIZE_STEP * (s - 1))
		assert_float(radius).override_failure_message("%s should look bigger than a stage-%d worm" % [id, s]) \
			.is_greater_equal(head * 1.25)


# --- the rings themselves (rings.tres, read only) ----------------------------------------------

func test_core_and_deep_rock_rings_exist_with_their_stages() -> void:
	var core := _ring(&"core")
	var deep := _ring(&"deep_rock")
	assert_object(core).is_not_null()
	assert_object(deep).is_not_null()
	assert_int(core.edible_from).is_equal(5)
	assert_int(deep.edible_from).is_equal(4)
	assert_str(String(core.alt_tile)).is_equal("crystal")
	assert_str(String(deep.tile)).is_equal("stone")
	assert_str(String(deep.alt_tile)).is_equal("ore")
	# The unbreakable seam at the very centre is a RingSet field the world builds and never lets go.
	assert_float(RINGS.strangestone_radius).is_greater(0.0)


# --- W-02 core -----------------------------------------------------------------------------------

func test_core_crystal_is_a_big_core_food_from_stage_5() -> void:
	var f := _food("core_crystal")
	assert_str(String(f.id)).is_equal("core_crystal")
	assert_str(String(f.ring)).is_equal("core")
	assert_int(f.size_stage).is_equal(_ring(&"core").edible_from)
	assert_str(String(f.flavour)).is_equal("crystal")
	assert_str(String(f.plants)).is_equal("crystal")
	assert_bool(RINGS.garden_tiles.has(f.plants)).is_true()
	# "crystals (big growth)": more than any dirt or topsoil food, and more than the small crystal.
	assert_float(f.growth).is_greater(load("res://data/foods/boulder.tres").growth)
	assert_float(f.growth).is_greater(load("res://data/foods/crystal.tres").growth)
	assert_float(f.regrow_time).is_greater(0.0)
	_looks_bigger_than_smaller_worms(f.id, f.radius, f.size_stage)


func test_lava_blob_is_harmless_core_threat() -> void:
	var c := _creature("lava_blob")
	assert_str(String(c.id)).is_equal("lava_blob")
	assert_str(String(c.ring)).is_equal("core")
	# Bounces every worm that can get into the core (stage 5), food once the worm is stage 6.
	assert_int(c.size_stage).is_equal(6)
	assert_bool(c.is_threat_to(5)).is_true()
	assert_bool(c.is_threat_to(6)).is_false()
	# No damage, never steers: BOUNCE never lunges or eats a worm, and it never notices one; it
	# only knocks a smaller worm back on contact (tests/test_deep_rock.gd).
	assert_int(c.behaviour).is_equal(CreatureData.Behaviour.BOUNCE)
	assert_float(c.bounce).is_greater(0.0)
	assert_float(c.notice).is_equal(0.0)
	assert_float(c.strike).is_equal(0.0)
	assert_str(String(c.hunts)).is_empty()
	assert_float(c.telegraph_time()).is_greater_equal(1.0)
	assert_str(c.bark).is_not_empty()
	_looks_bigger_than_smaller_worms(c.id, c.radius, c.size_stage)


func test_core_life_chain() -> void:
	var l := _life("core")
	assert_str(String(l.ring)).is_equal("core")
	var ids := []
	for r in l.species:
		assert_str(String(r.ring)).is_equal("core")
		ids.append(String(r.id))
	assert_array(ids).contains_exactly(["core_crystal", "lava_blob"])
	assert_str(l.species[0].live).is_equal("res://data/foods/core_crystal.tres")
	assert_bool(ResourceLoader.exists(l.species[0].live)).is_true()
	# The lava blob has a body now (deep-rock-1) but live_max stays 0: counted, never spawned live
	# until Gary decides to spawn them.
	assert_str(l.species[1].live).is_equal("res://scenes/creatures/lava_blob.tscn")
	assert_int(l.species[1].live_max).is_equal(0)
	assert_int(l.scatter_count).is_greater(0)
	for f in l.scatter:
		assert_str(String(f.ring)).is_equal("core")


# --- W-03 deep rock ------------------------------------------------------------------------------

func test_ore_nugget_and_fossil_are_deep_rock_foods_from_stage_4() -> void:
	for id in ["ore_nugget", "fossil"]:
		var f := _food(id)
		assert_str(String(f.id)).is_equal(id)
		assert_str(String(f.ring)).is_equal("deep_rock")
		assert_int(f.size_stage).is_equal(_ring(&"deep_rock").edible_from)
		assert_str(String(f.flavour)).is_equal("stone")
		assert_float(f.growth).is_greater(0.0)
		assert_float(f.regrow_time).is_greater(0.0)
		_looks_bigger_than_smaller_worms(f.id, f.radius, f.size_stage)
	# Ore nuggets carried home grow a stone garden; fossils are trophies, not seeds.
	assert_str(String(_food("ore_nugget").plants)).is_equal("stone")
	assert_bool(RINGS.garden_tiles.has(&"stone")).is_true()
	assert_str(String(_food("fossil").plants)).is_empty()


func test_rock_beetle_is_a_stage_4_deep_rock_trundler() -> void:
	var c := _creature("rock_beetle")
	assert_str(String(c.id)).is_equal("rock_beetle")
	assert_str(String(c.ring)).is_equal("deep_rock")
	assert_int(c.size_stage).is_equal(4)
	assert_bool(c.is_threat_to(3)).is_true()
	assert_bool(c.is_threat_to(4)).is_false()
	assert_int(c.behaviour).is_equal(CreatureData.Behaviour.TRUNDLE)
	assert_float(c.telegraph_time()).is_greater_equal(1.0)
	assert_str(c.bark).is_not_empty()
	assert_str(c.windup_cue).is_not_empty()
	assert_float(c.notice).is_greater(c.strike)
	_looks_bigger_than_smaller_worms(c.id, c.radius, c.size_stage)


func test_deep_rock_life_chain() -> void:
	var l := _life("deep_rock")
	assert_str(String(l.ring)).is_equal("deep_rock")
	var ids := []
	for r in l.species:
		assert_str(String(r.ring)).is_equal("deep_rock")
		ids.append(String(r.id))
	assert_array(ids).contains_exactly(["ore_nugget", "rock_beetle"])
	assert_bool(l.species[1].eats.has(&"ore_nugget")).is_true()
	assert_str(l.species[0].live).is_equal("res://data/foods/ore_nugget.tres")
	assert_bool(ResourceLoader.exists(l.species[0].live)).is_true()
	# The rock beetle's body (deep-rock-1): a few live near a worm, from the counter.
	assert_str(l.species[1].live).is_equal("res://scenes/creatures/rock_beetle.tscn")
	assert_bool(ResourceLoader.exists(l.species[1].live)).is_true()
	assert_int(l.species[1].live_max).is_greater(0)
	assert_float(l.species[1].live_scale).is_greater(0.0)
	assert_int(l.scatter_count).is_greater(0)
	for f in l.scatter:
		assert_str(String(f.ring)).is_equal("deep_rock")
		assert_str(String(f.id)).is_equal("fossil")


# --- the two chains on the real counters ---------------------------------------------------------

func _eco() -> RingEcology:
	var e := RingEcology.from_lives([_life("core"), _life("deep_rock")], 42)
	e.wobble = 0.05
	return e


func test_new_chains_settle_and_never_empty() -> void:
	var e := _eco()
	for t in 1800:
		e.step(1.0)
	for id in [&"core_crystal", &"lava_blob", &"ore_nugget", &"rock_beetle"]:
		var n := e.count(id)
		assert_bool(is_finite(n)).is_true()
		assert_float(n).override_failure_message("%s emptied" % id).is_greater(0.5)
		# RingEcology always adds immigration, so a counter nothing in the chain eats creeps past
		# capacity by at most immigration x time (the worms are its only eaters).
		var cap: float = e.rules[id].capacity * 1.1 + e.rules[id].immigration * 1800.0
		assert_float(n).override_failure_message("%s over capacity" % id).is_less_equal(cap)
	# The lava blobs sit at their steady number (immigration / death), not at zero, not swarming.
	assert_float(e.count(&"lava_blob")).is_between(4.0, 10.0)


func test_thinning_rock_beetles_lets_ore_nuggets_build_up() -> void:
	var base := _eco()
	var thin := _eco()
	for t in 1800:
		if t % 30 == 0:
			thin.kill(&"rock_beetle", thin.count(&"rock_beetle") * 0.8)
		base.step(1.0)
		thin.step(1.0)
	print("rings-content: base nuggets %.1f beetles %.1f | thinned nuggets %.1f beetles %.1f" % [
		base.count(&"ore_nugget"), base.count(&"rock_beetle"), thin.count(&"ore_nugget"), thin.count(&"rock_beetle")])
	assert_float(thin.count(&"rock_beetle")).is_less(base.count(&"rock_beetle") * 0.5)
	assert_float(thin.count(&"ore_nugget")).is_greater(base.count(&"ore_nugget"))
