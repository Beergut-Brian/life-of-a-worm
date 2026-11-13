## D-11 Hybrids at launch: ten two-flavour TraitData rows, each earned only when both flavours are
## filled, each changing something the worm feels on top of its two base traits, each its own look
## (slot + shape/texture + colour), and the trait wall still fits every trait a worm can earn.
class_name TestHybrids
extends GdUnitTestSuite

const NEW_HYBRIDS := ["beetle_shell", "firefly", "spring_tail", "lodestone", "radar", "rain_garden", "lamp_fish"]


func _rules() -> WormRules:
	return WormRules.default_rules()


func _hybrids() -> Array:
	return _rules().traits.filter(func(t: TraitData) -> bool: return t.is_hybrid() and not t.star)


## Flavours the world's foods actually carry (data/foods), so a hybrid is earnable in play.
func _food_flavours() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at("res://data/foods/"):
		if f.get_extension() != "tres":
			continue
		var r: Resource = load("res://data/foods/" + f)
		if r is FoodData:
			out[String(r.flavour)] = true
	return out


func _fill(m: WormGrowth, flavour: StringName, n: int) -> void:
	while m.flavour_count(flavour) < n:
		m.add_segment(flavour)


func test_ten_hybrids_and_the_base_traits_at_launch() -> void:
	var base := _rules().traits.filter(func(t: TraitData) -> bool: return not t.is_hybrid() and not t.star)
	assert_int(base.size()).is_greater_equal(7)
	assert_int(_hybrids().size()).is_greater_equal(10)
	for id in NEW_HYBRIDS:
		var t := _rules().find_trait(StringName(id))
		assert_object(t).override_failure_message("%s missing" % id).is_not_null()
		assert_bool(t is TraitData).is_true()
		assert_bool(t.is_hybrid()).is_true()


func test_every_hybrid_is_a_different_pair_of_flavours_the_foods_carry() -> void:
	var seen := {}
	var foods := _food_flavours()
	for t in _hybrids():
		assert_int(t.requires.size()).is_equal(2)
		var pair: Array = t.requires.keys().map(func(k) -> String: return String(k))
		pair.sort()
		var key := "+".join(pair)
		assert_bool(seen.has(key)).override_failure_message("%s repeats %s" % [t.id, key]).is_false()
		seen[key] = t.id
		if t.id in NEW_HYBRIDS:   # the new ones are all earnable today (no cloud food exists yet)
			for f in pair:
				assert_bool(foods.has(f)).override_failure_message("%s needs %s: no food has it" % [t.id, f]).is_true()


func test_a_hybrid_needs_both_flavours_filled_at_once() -> void:
	for id in NEW_HYBRIDS:
		var t := _rules().find_trait(StringName(id))
		var fl: Array = t.requires.keys()
		var m := WormGrowth.new()
		m.apex_gate = true
		m.start_at_stage(6)
		_fill(m, StringName(fl[0]), int(t.requires[fl[0]]) + 2)
		_fill(m, StringName(fl[1]), int(t.requires[fl[1]]) - 1)
		assert_bool(t.id in m.earned).override_failure_message("%s early" % id).is_false()
		m.add_segment(StringName(fl[1]))
		assert_bool(t.id in m.earned).override_failure_message("%s not earned" % id).is_true()


func test_each_new_hybrid_is_felt_over_its_two_base_traits() -> void:
	# The resolved stats with the hybrid on must differ from its two base traits alone, on every
	# stat the hybrid names (test_traits_visible checks the stat is read by game code).
	var rules := _rules()
	for id in NEW_HYBRIDS:
		var h := rules.find_trait(StringName(id))
		var bases: Array[TraitData] = []
		for t in rules.traits:
			if not t.is_hybrid() and not t.star and String(t.requires.keys()[0]) in h.requires.keys().map(func(k) -> String: return String(k)):
				bases.append(t)
		var with: Array[TraitData] = bases.duplicate()
		with.append(h)
		var a := WormStats.resolve(bases, rules.base_stats, 4)
		var b := WormStats.resolve(with, rules.base_stats, 4)
		for stat in h.add.keys() + h.mul.keys():
			var gap := absf(b.value(String(stat)) - a.value(String(stat)))
			assert_float(gap).override_failure_message("%s: %s unchanged" % [id, stat]).is_greater(0.001)


func test_every_trait_looks_different_on_the_wall() -> void:
	# Slot + picture + colour: no two traits (base, hybrid or Star) share all three.
	var seen := {}
	for t in _rules().traits:
		var pic := String(t.part_shape) if t.part_textures.is_empty() else t.part_textures[0].resource_path
		var key := "%s|%s|%s" % [t.part_slot, pic, t.color.to_html()]
		assert_bool(seen.has(key)).override_failure_message("%s looks like %s" % [t.id, seen.get(key)]).is_false()
		seen[key] = t.id
		assert_object(t.part_texture(3)).is_not_null()


func test_hybrid_colour_is_a_blend_of_its_two_flavours() -> void:
	var fc := _rules().flavour_colors
	for id in NEW_HYBRIDS:
		var t := _rules().find_trait(StringName(id))
		var fl: Array = t.requires.keys()
		var mix: Color = fc[StringName(fl[0])].lerp(fc[StringName(fl[1])], 0.5)
		# Close to the halfway colour (lodestone is darkened a little to read as iron).
		assert_float(Vector3(t.color.r - mix.r, t.color.g - mix.g, t.color.b - mix.b).length()) \
			.override_failure_message("%s colour" % id).is_less(0.2)


func test_the_wall_fits_every_trait_a_worm_can_earn_in_one_row() -> void:
	var n := _rules().traits.size()
	assert_float(TraitWall.tile_size(3, 1920.0)).is_equal(TraitWall.TILE)   # a few: full size
	var tile := TraitWall.tile_size(n, 1920.0)
	assert_float(n * (tile + TraitWall.GAP) + TraitWall.GAP).is_less_equal(1920.0 - 16.0)
	assert_float(tile).is_greater_equal(TraitWall.MIN_TILE)
