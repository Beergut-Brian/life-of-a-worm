## WormStats: one resolver, every modifier stacks the same way, order never matters.
class_name TestTraitsResolver
extends GdUnitTestSuite

const BASE := { "speed": 100.0, "burst_time": 0.5, "light_radius": 0.0 }


func _trait(id: String, add := {}, mul := {}, slot := &"", prio := 0) -> TraitData:
	var t := TraitData.new()
	t.id = StringName(id)
	t.add = add
	t.mul = mul
	t.part_slot = slot
	t.part_priority = prio
	if slot != &"":
		var tex: Texture2D = PlaceholderTexture2D.new()
		t.part_textures = [tex]
	return t


func test_no_traits_is_the_base() -> void:
	var s := WormStats.resolve([], BASE)
	assert_float(s.value("speed")).is_equal(100.0)
	assert_float(s.value("burst_time")).is_equal(0.5)
	assert_dict(s.parts).is_empty()


func test_adds_sum_then_muls_multiply() -> void:
	var a := _trait("a", { "speed": 10.0, "light_radius": 1.0 })
	var b := _trait("b", { "speed": 30.0 }, { "speed": 2.0 })
	var c := _trait("c", {}, { "speed": 1.5, "burst_time": 3.0 })
	var s := WormStats.resolve([a, b, c], BASE)
	assert_float(s.value("speed")).is_equal_approx((100.0 + 10.0 + 30.0) * 2.0 * 1.5, 0.0001)
	assert_float(s.value("burst_time")).is_equal_approx(0.5 * 3.0, 0.0001)
	assert_float(s.value("light_radius")).is_equal(1.0)


func test_unknown_stat_starts_at_zero_and_mul_alone_keeps_it_zero() -> void:
	var s := WormStats.resolve([_trait("a", { "new_stat": 4.0 }), _trait("b", {}, { "other": 3.0 })], BASE)
	assert_float(s.value("new_stat")).is_equal(4.0)
	assert_float(s.value("other")).is_equal(0.0)


func test_order_never_matters() -> void:
	var rules := WormRules.default_rules()
	var list: Array = rules.traits.duplicate()
	var ref := WormStats.resolve(list, rules.base_stats, 6)
	var orders := [[5, 4, 3, 2, 1, 0], [2, 0, 5, 1, 4, 3], [1, 3, 5, 0, 2, 4]]
	for order in orders:
		var shuffled: Array = []
		for i in order:
			shuffled.append(list[i])
		var s := WormStats.resolve(shuffled, rules.base_stats, 6)
		assert_dict(s.values()).is_equal(ref.values())
		assert_array(s.parts.keys()).contains_exactly_in_any_order(ref.parts.keys())
		for slot in ref.parts:
			assert_str(String(s.parts[slot].trait)).is_equal(String(ref.parts[slot].trait))


func test_higher_priority_part_wins_its_slot_in_any_order() -> void:
	var low := _trait("low", {}, {}, &"head", 1)
	var high := _trait("high", {}, {}, &"head", 2)
	assert_str(String(WormStats.resolve([low, high], BASE).parts[&"head"].trait)).is_equal("high")
	assert_str(String(WormStats.resolve([high, low], BASE).parts[&"head"].trait)).is_equal("high")


## The proof: five real traits stacked at once, every one changes something you can see or feel.
func test_five_real_traits_stack_and_each_shows() -> void:
	var rules := WormRules.default_rules()
	var five: Array = []
	for id in [&"wriggle", &"drill_head", &"glow", &"magnet", &"slick"]:
		five.append(rules.find_trait(id))
	var base := WormStats.resolve([], rules.base_stats, 6)
	var s := WormStats.resolve(five, rules.base_stats, 6)
	assert_float(s.value("speed")).is_greater(base.value("speed"))
	assert_float(s.value("burst_time")).is_greater(base.value("burst_time"))
	assert_float(s.value("burst_speed")).is_greater(base.value("burst_speed"))
	assert_float(s.value("light_radius")).is_greater(0.0)
	assert_float(s.value("pull_radius")).is_greater(0.0)
	assert_float(s.value("sheen")).is_greater(0.0)
	assert_float(s.value("drag/water")).is_less(base.value("drag/water"))
	assert_float(s.value("bite_bonus/stone")).is_equal(1.0)
	assert_array(s.parts.keys()).contains_exactly_in_any_order([&"head", &"crown", &"back", &"tail", &"skin"])
	# Every trait in the stack has a part on the worm (none is only a number).
	var shown: Array = []
	for slot in s.parts:
		shown.append(s.parts[slot].trait)
	assert_array(shown).contains_exactly_in_any_order([&"wriggle", &"drill_head", &"glow", &"magnet", &"slick"])


func test_stone_and_drill_heads_stack_their_bite_but_show_one_head() -> void:
	var rules := WormRules.default_rules()
	var s := WormStats.resolve([rules.find_trait(&"drill_head"), rules.find_trait(&"stone_head")], rules.base_stats)
	assert_float(s.value("bite_bonus/stone")).is_equal(2.0)
	assert_str(String(s.parts[&"head"].trait)).is_equal("drill_head")
