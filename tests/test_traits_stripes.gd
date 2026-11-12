## Diet stripes (D-01): a food's flavour tints the newest segments through WormLook.flavour_tint,
## the body keeps a per-segment flavour count, and plain growth leaves no stripe.
class_name TestTraitsStripes
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")


func after() -> void:
	for p in Audio._pool:
		p.stop()   # placeholder beeps still playing at exit leak their playbacks


func _worm() -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = Players.P1
	add_child(w)
	return auto_free(w)


func _segments(w: Worm) -> Array[WormSegment]:
	var out: Array[WormSegment] = []
	for n in w.body.get_children():
		if n is WormSegment and not n.is_queued_for_deletion():
			out.append(n)
	return out


func _food(flavour: StringName, growth := 2.0) -> FoodData:
	var f := FoodData.new()
	f.flavour = flavour
	f.growth = growth
	return f


func test_eating_tints_the_newest_segments_in_the_food_flavour() -> void:
	var w := _worm()
	var start := w.model.segments.size()
	w.feed(_food(&"bug", 4.0))            # two segments' worth of bug
	w.feed(_food(&"stone", 2.0))          # then one of stone
	var segs := _segments(w)
	assert_int(segs.size()).is_equal(start + 3)
	assert_array(w.model.newest_flavours(3)).is_equal([&"bug", &"bug", &"stone"])
	var look := WormHooks.look()
	assert_str(String(segs[-1].flavour)).is_equal("stone")
	assert_that(segs[-1].tint()).is_equal(look.flavour_tint(&"stone"))
	assert_that(segs[-2].tint()).is_equal(look.flavour_tint(&"bug"))
	assert_that(segs[-3].tint()).is_equal(look.flavour_tint(&"bug"))
	assert_bool(segs[-1].tint() != segs[-2].tint()).is_true()   # two stripes you can tell apart
	# the older, plain segments carry no stripe
	assert_float(segs[0].tint().a).is_equal(0.0)


func test_per_segment_flavour_counts() -> void:
	var w := _worm()
	for i in 3:
		w.feed(_food(&"root"))
	w.feed(_food(&"junk"))
	var counts := w.model.flavour_counts()
	assert_int(counts.get(&"root", 0)).is_equal(3)
	assert_int(counts.get(&"junk", 0)).is_equal(1)
	assert_int(counts.get(&"", 0)).is_equal(w.model.rules.start_segments)
	assert_int(w.model.flavour_count(&"root")).is_equal(3)


func test_a_mixed_bite_takes_the_bigger_share() -> void:
	var m := WormGrowth.new()
	m.add_growth(0.6, &"water")
	m.add_growth(1.4, &"crystal")
	assert_str(String(m.segments[-1])).is_equal("crystal")


func test_every_slice_flavour_has_its_own_stripe_colour() -> void:
	var look := WormHooks.look()
	var seen := {}
	for f in [&"root", &"bug", &"stone", &"crystal", &"junk", &"water", &"cloud"]:
		var c: Color = look.flavour_tint(f)
		assert_bool(seen.has(c.to_html())).is_false()
		seen[c.to_html()] = true


func test_stripes_survive_save_and_load() -> void:
	var w := _worm()
	w.feed(_food(&"bug"))
	w.feed(_food(&"water"))
	var d: Dictionary = JSON.parse_string(JSON.stringify(w.to_dict()))
	var back: Worm = WORM.instantiate()
	back.from_dict(d)
	add_child(back)
	auto_free(back)
	var segs := _segments(back)
	assert_str(String(segs[-1].flavour)).is_equal("water")
	assert_str(String(segs[-2].flavour)).is_equal("bug")
