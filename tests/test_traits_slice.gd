## TraitData + the one WormStats resolver (D-04 to D-12, D-14): every slice trait is data, five
## traits stack with no special cases, slots grow with the stage, earned traits never go away and
## survive save/load.
class_name TestTraitsSlice
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")
const BASE_IDS := ["wriggle", "green_thumb", "stone_head", "glow", "magnet", "slick", "floaty"]
const HYBRID_IDS := ["drill_head", "skater", "garden_cart"]


func before() -> void:
	SuiteSandbox.enter("traits_slice")


func after() -> void:
	for p in Audio._pool:
		p.stop()   # placeholder beeps still playing at exit leak their playbacks
	SuiteSandbox.leave()


func _rules() -> WormRules:
	return WormRules.default_rules()


## A worm at `stage` that has filled segments for each trait in ids (earned the honest way).
func _worm_with(ids: Array, stage := 6) -> WormGrowth:
	var m := WormGrowth.new()
	m.apex_gate = true   # the stage stays put while we fill flavours
	m.start_at_stage(stage)
	for id in ids:
		var t := _rules().find_trait(StringName(id))
		for f in t.requires:
			while m.flavour_count(StringName(f)) < int(t.requires[f]):
				m.add_segment(StringName(f))
	return m


func test_every_slice_trait_is_data_with_a_part_a_cue_and_a_colour() -> void:
	for id in BASE_IDS + HYBRID_IDS:
		var t := _rules().find_trait(StringName(id))
		assert_object(t).is_not_null()
		assert_bool(t is TraitData).is_true()
		assert_bool(t.requires.is_empty()).is_false()
		assert_str(t.cue).is_equal("trait_" + id)
		assert_str(String(t.part_slot)).is_not_empty()
		for s in range(1, 8):
			assert_object(t.part_texture(s)).is_not_null()
		assert_bool(t.add.is_empty() and t.mul.is_empty()).is_false()   # felt, not only seen
		assert_bool(t.is_hybrid()).is_equal(id in HYBRID_IDS)


func test_hybrids_are_the_named_flavour_pairs() -> void:
	assert_dict(_rules().find_trait(&"drill_head").requires).contains_keys(["stone", "crystal"])
	assert_dict(_rules().find_trait(&"skater").requires).contains_keys(["bug", "water"])
	assert_dict(_rules().find_trait(&"garden_cart").requires).contains_keys(["root", "junk"])
	# a hybrid's part beats its base part in the same slot (Garden cart over Magnet on the tail)
	var s := WormStats.resolve([_rules().find_trait(&"magnet"), _rules().find_trait(&"garden_cart")], _rules().base_stats, 2)
	assert_str(String(s.parts[&"tail"].trait)).is_equal("garden_cart")
	assert_float(s.value("pull_radius")).is_equal(60.0)   # both still stack


func test_five_traits_stack_through_one_rule() -> void:
	var ids := ["wriggle", "stone_head", "glow", "magnet", "skater"]
	var m := _worm_with(["wriggle", "stone_head", "glow", "magnet", "skater"])
	m.active.clear()
	for id in ids:
		m.active.append(StringName(id))
	m._resolve()
	assert_int(m.active.size()).is_equal(5)
	var base := _rules().base_stats
	# The rule, computed from the data alone: (base + adds) * muls, for every stat any of them names.
	var stats := {}
	for k in base:
		stats[String(k)] = true
	for id in ids:
		var t := _rules().find_trait(StringName(id))
		for k in t.add:
			stats[String(k)] = true
		for k in t.mul:
			stats[String(k)] = true
	for k in stats:
		var sum := float(base.get(k, 0.0))
		var prod := 1.0
		for id in ids:
			var t := _rules().find_trait(StringName(id))
			sum += float(t.add.get(k, 0.0))
			prod *= float(t.mul.get(k, 1.0))
		assert_float(m.stats.value(k)).is_equal_approx(sum * prod, 0.0001)
	# and by hand for the ones a player feels
	assert_float(m.stats.value("speed")).is_equal_approx(80.0 * 1.3 * 1.1, 0.0001)
	assert_float(m.stats.value("burst_time")).is_equal_approx(0.25 * 1.8, 0.0001)
	assert_float(m.stats.value("drag/water")).is_equal_approx(0.5, 0.0001)
	assert_float(m.stats.value("bite_bonus/stone")).is_equal(1.0)
	assert_float(m.stats.value("light_radius")).is_equal_approx(1.8, 0.0001)
	assert_float(m.stats.value("pull_radius")).is_equal(60.0)
	assert_int(m.stats.parts.size()).is_equal(5)   # back, head, crown, tail, under


func test_float_and_slick_resolve_before_their_rings_exist() -> void:
	var s := WormStats.resolve([_rules().find_trait(&"floaty"), _rules().find_trait(&"slick")], _rules().base_stats, 3)
	assert_float(s.value("glide")).is_equal(1.0)
	assert_float(s.value("drag/water")).is_equal_approx(0.1, 0.0001)
	assert_float(s.value("sheen")).is_equal(1.0)
	assert_str(String(s.parts[&"above"].trait)).is_equal("floaty")
	assert_str(String(s.parts[&"skin"].trait)).is_equal("slick")


func test_slots_grow_one_at_stage_two_to_five_at_stage_six() -> void:
	var want := [0, 0, 1, 2, 3, 4, 5, 5]
	for s in range(1, 8):
		var m := WormGrowth.new()
		m.start_at_stage(s)
		assert_int(m.slots()).is_equal(want[s])
	var m6 := _worm_with(BASE_IDS)
	assert_int(m6.earned.size()).is_greater_equal(7)
	assert_int(m6.active.size()).is_equal(5)
	var waiting: StringName = m6.earned.filter(func(t): return not t in m6.active)[0]
	assert_bool(m6.toggle(waiting)).is_false()    # every slot full: nothing changes


func test_earned_traits_are_never_lost() -> void:
	var m := _worm_with(["wriggle"], 2)
	var earned := m.earned.duplicate()
	for i in 20:
		m.lose_segment()
	assert_array(m.earned).contains_exactly(earned)
	assert_int(m.stage).is_equal(2)
	m.toggle(&"wriggle")   # unequip: still earned
	assert_bool(&"wriggle" in m.earned).is_true()


func test_earned_traits_survive_save_and_load() -> void:
	var w: Worm = WORM.instantiate()
	w.model = _worm_with(["wriggle", "glow", "floaty"], 3)
	add_child(w)
	auto_free(w)
	var want_earned := w.model.earned.duplicate()
	var want_active := w.model.active.duplicate()
	assert_int(want_earned.size()).is_greater_equal(3)
	Save.set_value("worm_test", w.to_dict())
	Save.flush()
	Save._load()   # read the file back from disk
	var d: Dictionary = JSON.parse_string(JSON.stringify(Save.get_value("worm_test", {})))
	var back: Worm = WORM.instantiate()
	back.from_dict(d)
	add_child(back)
	auto_free(back)
	assert_array(back.model.earned).contains_exactly(want_earned)
	assert_array(back.model.active).contains_exactly(want_active)
	assert_int(back.model.stage).is_equal(3)
	assert_array(back.model.segments).is_equal(w.model.segments)
	assert_float(back.model.stats.value("speed")).is_equal(w.model.stats.value("speed"))
