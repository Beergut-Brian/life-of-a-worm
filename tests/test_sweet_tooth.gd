## X-01 "sometimes the only source of a hybrid" (gap-close-38, Gary's pick): the jam drops in Old
## Reel's buried picnic basket are the one sweet food in the world, so Sweet tooth (sweet + bug,
## faster and a quicker burst recharge) can only be grown by a worm that found the basket.
class_name TestSweetTooth
extends GdUnitTestSuite

const BASKET := "res://data/secrets/picnic_basket.tres"
const JAM := "res://data/foods/jam_drop.tres"


func _rules() -> WormRules:
	return WormRules.default_rules()


## Every .tres under data/ (space planets and pets included), recursively.
func _all_tres(dir: String, out: Array[String]) -> Array[String]:
	for d in DirAccess.get_directories_at(dir):
		_all_tres(dir.path_join(d), out)
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == "tres":
			out.append(dir.path_join(f))
	return out


func _model(stage := 2) -> WormGrowth:
	var m := WormGrowth.new()
	m.apex_gate = true
	m.start_at_stage(stage)
	return m


func test_the_baskets_jam_is_the_only_sweet_thing_in_the_world() -> void:
	var sweet: Array[String] = []
	for path in _all_tres("res://data", []):
		var text := FileAccess.get_file_as_string(path)
		if text.contains('flavour = &"sweet"') or text.contains('plants = &"sweet"'):
			sweet.append(path)
	assert_array(sweet).contains_exactly([JAM])
	var basket: SecretData = load(BASKET)
	assert_str(String(basket.food)).is_equal("jam_drop")
	assert_int(basket.food_count).is_greater_equal(3)
	# No ring life scatters it and no other hidden place hands it out. (A trophy family only lists
	# what counts on the shelf, it hands nothing out: every food has one, B-09.)
	for path in _all_tres("res://data", []):
		if path == JAM or path == BASKET or path.begins_with("res://data/trophies/"):
			continue
		assert_bool(FileAccess.get_file_as_string(path).contains("jam_drop")) \
				.override_failure_message("%s also gives jam drops" % path).is_false()
	var jam: RingFood = load(JAM)
	assert_str(String(jam.flavour)).is_equal("sweet")
	assert_int(jam.size_stage).is_less_equal(basket.carve_stage)   # edible the moment it is found


func test_sweet_has_its_own_stripe_colour() -> void:
	var fc := _rules().flavour_colors
	assert_bool(fc.has(&"sweet")).is_true()
	for f in fc:
		if f != &"sweet":
			assert_bool(fc[f].is_equal_approx(fc[&"sweet"])).override_failure_message("sweet looks like %s" % f).is_false()
	assert_str(WormHooks.look().flavour_tint(&"sweet").to_html()).is_equal(fc[&"sweet"].to_html())


func test_sweet_tooth_is_a_hybrid_of_sweet_and_bug_that_is_felt() -> void:
	var t := _rules().find_trait(&"sweet_tooth")
	assert_object(t).is_not_null()
	assert_bool(t.is_hybrid()).is_true()
	assert_bool(t.star).is_false()
	assert_array(t.requires.keys().map(func(k) -> String: return String(k))).contains_exactly_in_any_order(["sweet", "bug"])
	assert_object(t.part_texture(3)).is_not_null()   # a round sweet on its back, drawn in code
	var rules := _rules()
	var wriggle := rules.find_trait(&"wriggle")
	var alone: Array[TraitData] = [wriggle]
	var both: Array[TraitData] = [wriggle, t]
	var a := WormStats.resolve(alone, rules.base_stats, 2)
	var b := WormStats.resolve(both, rules.base_stats, 2)
	assert_float(b.value("speed")).is_greater(a.value("speed"))
	assert_float(b.value("burst_cooldown")).is_less(a.value("burst_cooldown"))


func test_the_baskets_jam_and_ant_city_bugs_grow_it_at_stage_2() -> void:
	var jam: RingFood = load(JAM)
	var honeydew: FoodData = load("res://data/foods/honeydew.tres")
	var basket: SecretData = load(BASKET)
	var m := _model(2)
	for i in 4:
		m.add_growth(honeydew.growth, honeydew.flavour)
	assert_bool(&"sweet_tooth" in m.earned).is_false()
	var bites := 0
	while not &"sweet_tooth" in m.earned and bites < basket.food_count:
		m.add_growth(jam.growth, jam.flavour)
		bites += 1
	assert_bool(&"sweet_tooth" in m.earned).override_failure_message("one basket of jam is not enough").is_true()
	assert_int(m.flavour_count(&"sweet")).is_greater_equal(4)   # the pink stripes show why


func test_no_amount_of_every_other_food_grows_it() -> void:
	var m := _model(6)
	for f in DirAccess.get_files_at("res://data/foods/"):
		if f.get_extension() != "tres" or f == "jam_drop.tres":
			continue
		var food: FoodData = load("res://data/foods/" + f)
		for i in 12:
			m.add_growth(food.growth, food.flavour)
	assert_bool(&"sweet_tooth" in m.earned).is_false()
	assert_int(m.flavour_count(&"sweet")).is_equal(0)


func test_a_real_worm_eating_jam_wears_pink_stripes() -> void:
	SuiteSandbox.enter("sweet_tooth")
	var w: Worm = preload("res://scenes/players/worm.tscn").instantiate()
	w.model = _model(2)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	w.feed(load("res://data/foods/honeydew.tres"))
	for i in 4:
		w.feed(load(JAM))
	await get_tree().process_frame
	assert_bool(&"bug" in w.model.segments).is_true()
	assert_str(String(w.model.segments[-1])).is_equal("sweet")
	w.queue_free()
	await get_tree().process_frame
	for p in Audio._pool:
		p.stop()
		p.stream = null
	SuiteSandbox.leave()
