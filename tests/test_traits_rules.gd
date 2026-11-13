## Earning, hybrids, slots: all from data/traits/*.tres and worm_rules.tres.
class_name TestTraitsRules
extends GdUnitTestSuite


func _rules() -> WormRules:
	return WormRules.default_rules()


func _fill(m: WormGrowth, flavour: StringName, n: int) -> void:
	for i in n:
		m.add_segment(flavour)


func test_every_single_flavour_trait_earns_exactly_at_its_threshold() -> void:
	var checked := 0
	for t in _rules().traits:
		if t.is_hybrid() or t.star:   # Star traits come from space planets, not flavours (D-10)
			continue
		var f: StringName = StringName(t.requires.keys()[0])
		var need := int(t.requires[f])
		var m := WormGrowth.new()
		_fill(m, f, need - 1)
		assert_bool(t.id in m.earned).override_failure_message("%s early" % t.id).is_false()
		m.add_segment(f)
		assert_bool(t.id in m.earned).override_failure_message("%s not earned" % t.id).is_true()
		checked += 1
	assert_int(checked).is_greater_equal(5)


func test_hybrid_needs_both_flavours() -> void:
	var drill := _rules().find_trait(&"drill_head")
	assert_bool(drill.is_hybrid()).is_true()
	assert_dict(drill.requires).contains_keys(["stone", "crystal"])
	var m := WormGrowth.new()
	_fill(m, &"stone", int(drill.requires["stone"]) + 3)
	assert_bool(&"drill_head" in m.earned).is_false()
	assert_bool(&"stone_head" in m.earned).is_true()
	_fill(m, &"crystal", int(drill.requires["crystal"]))
	assert_bool(&"drill_head" in m.earned).is_true()


func test_only_traits_with_two_flavours_are_hybrids() -> void:
	for t in _rules().traits:
		assert_bool(t.is_hybrid()).is_equal(t.requires.size() >= 2)


func test_slots_grow_one_at_stage_two_to_five_at_stage_six() -> void:
	var want := { 1: 0, 2: 1, 3: 2, 4: 3, 5: 4, 6: 5 }
	for s in want:
		assert_int(_rules().slots_for(s)).is_equal(want[s])
		var m := WormGrowth.new()
		m.start_at_stage(s)
		assert_int(m.stage).is_equal(s)
		assert_int(m.slots()).is_equal(want[s])


func test_newest_equips_when_a_slot_is_free_and_waits_when_full() -> void:
	var m := WormGrowth.new()
	m.start_at_stage(2)                       # one slot
	m.grant(&"wriggle")
	assert_array(m.active).contains_exactly([&"wriggle"])
	m.grant(&"glow")                          # full: earned, on the wall
	assert_array(m.earned).contains_exactly([&"wriggle", &"glow"])
	assert_array(m.active).contains_exactly([&"wriggle"])
	m.start_at_stage(3)                       # a second slot: the waiting one equips itself
	assert_array(m.active).contains_exactly([&"wriggle", &"glow"])


func test_wall_toggle_respects_slots() -> void:
	var m := WormGrowth.new()
	m.start_at_stage(2)
	m.grant(&"wriggle")
	m.grant(&"glow")
	assert_bool(m.toggle(&"glow")).is_false()  # full
	assert_bool(m.toggle(&"wriggle")).is_true()  # off
	assert_bool(m.toggle(&"glow")).is_true()  # on
	assert_array(m.active).contains_exactly([&"glow"])
	assert_array(m.earned).contains_exactly([&"wriggle", &"glow"])
	assert_bool(m.toggle(&"magnet")).is_false()  # not earned


func test_segment_every_growth_per_segment_and_flavour_is_the_biggest_share() -> void:
	var m := WormGrowth.new()
	var start := m.segments.size()
	var per := m.rules.growth_per_segment
	m.add_growth(per * 0.5, &"bug")
	assert_int(m.segments.size()).is_equal(start)
	m.add_growth(per * 0.3, &"")
	m.add_growth(per * 0.2, &"water")
	assert_int(m.segments.size()).is_equal(start + 1)
	assert_str(String(m.segments.back())).is_equal("bug")


func test_stage_and_traits_are_never_lost() -> void:
	var m := WormGrowth.new()
	m.start_at_stage(3)
	_fill(m, &"bug", 4)
	var stage := m.stage
	for i in 30:
		m.lose_segment()
	assert_int(m.stage).is_equal(stage)
	assert_bool(&"wriggle" in m.earned).is_true()
	assert_bool(&"wriggle" in m.active).is_true()
	assert_int(m.segments.size()).is_equal(1)
