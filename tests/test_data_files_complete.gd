## D-16 sweep: every file in data/foods/ and data/traits/ has every field the game reads, walked
## file by file (the rules list and the ring lives are checked elsewhere; a file that is on disk
## but missing from them, or missing a field, turns this red).
##  - Foods: id = file name, flavour the rules know, growth, size stage, radius, a colour, the drawn
##    look (the sprite until Art's per-food sprites, D92), ring, regrow time, swallow sound on disk.
##  - Traits: id = file name, listed in worm_rules.tres, earned from flavours the foods have (or a
##    star from its planet), changes a stat, shows a part (art or a drawn shape), a colour and its
##    sting on disk.
extends GdUnitTestSuite

const FOODS := "res://data/foods/"
const TRAITS := "res://data/traits/"


func _tres(dir: String, skip := "") -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tres") and f != skip:
			out.append(f)
	return out


func _food_flavours() -> Dictionary:
	var out := {}
	for f in _tres(FOODS):
		out[(load(FOODS + f) as FoodData).flavour] = true
	return out


func test_every_food_file_has_every_field() -> void:
	var rules := WormRules.default_rules()
	var looks: int = RingFood.Look.size()
	assert_int(_tres(FOODS).size()).is_greater(20)
	for f in _tres(FOODS):
		var d := load(FOODS + f) as RingFood
		assert_object(d).override_failure_message("%s is not a RingFood" % f).is_not_null()
		var id := f.get_basename()
		assert_str(String(d.id)).is_equal(id)
		assert_bool(rules.flavour_colors.has(d.flavour)) \
				.override_failure_message("%s: flavour %s has no colour in the rules" % [id, d.flavour]).is_true()
		assert_float(d.growth).override_failure_message("%s: growth" % id).is_greater(0.0)
		assert_int(d.size_stage).override_failure_message("%s: size stage" % id).is_between(1, 6)
		assert_float(d.radius).override_failure_message("%s: radius" % id).is_greater(0.0)
		assert_float(d.color.a).override_failure_message("%s: colour" % id).is_greater(0.5)
		assert_float(d.accent.a).override_failure_message("%s: accent" % id).is_greater(0.5)
		assert_int(d.look).override_failure_message("%s: look" % id).is_between(0, looks - 1)
		assert_str(String(d.ring)).override_failure_message("%s: ring" % id).is_not_empty()
		assert_float(d.regrow_time).override_failure_message("%s: regrow" % id).is_greater_equal(0.0)
		assert_bool(d.plants == &"" or rules.flavour_colors.has(d.plants)) \
				.override_failure_message("%s: plants %s" % [id, d.plants]).is_true()
		assert_bool(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % d.eat_cue)) \
				.override_failure_message("%s: no swallow sound %s" % [id, d.eat_cue]).is_true()


func test_every_trait_file_has_every_field() -> void:
	var rules := WormRules.default_rules()
	var listed := {}
	for t in rules.traits:
		listed[t.resource_path] = true
	var flavours := _food_flavours()
	var files := _tres(TRAITS, "worm_rules.tres")
	assert_int(files.size()).is_greater_equal(10)
	assert_int(rules.traits.size()).is_equal(files.size())
	for f in files:
		var t := load(TRAITS + f) as TraitData
		assert_object(t).override_failure_message("%s is not a TraitData" % f).is_not_null()
		var id := f.get_basename()
		assert_str(String(t.id)).is_equal(id)
		assert_bool(listed.has(TRAITS + f)).override_failure_message("%s not in worm_rules" % id).is_true()
		if t.star:
			assert_str(String(t.star_planet)).override_failure_message("%s: star with no planet" % id) \
					.is_not_empty()
			assert_dict(t.requires).is_empty()
		else:
			assert_int(t.requires.size()).override_failure_message("%s: earned from nothing" % id).is_between(1, 2)
			for fl in t.requires:
				assert_bool(flavours.has(fl)).override_failure_message("%s: no food is %s" % [id, fl]).is_true()
				assert_int(int(t.requires[fl])).is_greater(0)
		assert_int(t.add.size() + t.mul.size()).override_failure_message("%s: no stat" % id).is_greater(0)
		assert_str(String(t.part_slot)).override_failure_message("%s: no part slot" % id).is_not_empty()
		assert_bool(t.part_textures.size() > 0 or t.part_shape != &"") \
				.override_failure_message("%s: no part to show" % id).is_true()
		assert_float(t.color.a).override_failure_message("%s: colour" % id).is_greater(0.5)
		assert_bool(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % t.cue)) \
				.override_failure_message("%s: no sting %s" % [id, t.cue]).is_true()
