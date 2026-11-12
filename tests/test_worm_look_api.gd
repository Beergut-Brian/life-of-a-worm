## WormLook: every stage / kind / mood of both worms returns a texture at its stage's size.
class_name TestWormLookApi
extends GdUnitTestSuite

const FLAVOURS: Array[StringName] = [&"root", &"bug", &"stone", &"crystal", &"junk", &"water", &"cloud", &"star"]


func after() -> void:
	WormLook.clear_cache()


func test_every_stage_and_kind_has_a_segment_texture() -> void:
	for p in [Players.P1, Players.P2]:
		for stage in range(1, 4):
			for kind in WormLook.KINDS:
				var t := WormLook.segment_texture(p, stage, kind)
				assert_object(t).override_failure_message("p%d s%d %s" % [p, stage, kind]).is_not_null()
				var px := WormLook.head_px(stage) if kind == &"head" else WormLook.segment_px(stage)
				assert_vector(Vector2(t.get_size())).override_failure_message("p%d s%d %s size" % [p, stage, kind]).is_equal(Vector2(px, px))


func test_every_mood_has_a_face_the_size_of_the_head() -> void:
	for p in [Players.P1, Players.P2]:
		for stage in range(1, 4):
			for mood in WormLook.MOODS:
				var t := WormLook.face_texture(p, stage, mood)
				assert_object(t).override_failure_message("p%d s%d %s" % [p, stage, mood]).is_not_null()
				assert_int(t.get_width()).is_equal(WormLook.head_px(stage))


func test_stages_are_swapped_not_stretched() -> void:
	for p in [Players.P1, Players.P2]:
		var a := WormLook.segment_texture(p, 1, &"body")
		var b := WormLook.segment_texture(p, 2, &"body")
		var c := WormLook.segment_texture(p, 3, &"body")
		assert_bool(a != b and b != c).is_true()
		assert_int(a.get_width()).is_less(b.get_width())
		assert_int(b.get_width()).is_less(c.get_width())


func test_gulp_and_burp_have_their_own_art() -> void:
	for stage in range(1, 4):
		assert_bool(WormLook.segment_texture(0, stage, &"head") != WormLook.segment_texture(1, stage, &"head")).is_true()
		assert_bool(WormLook.face_texture(0, stage, &"idle") != WormLook.face_texture(1, stage, &"idle")).is_true()


func test_stage_3_feature_is_a_bow_and_a_cap() -> void:
	assert_object(WormLook.feature_texture(1)).is_null()
	assert_object(WormLook.feature_texture(2)).is_null()
	var bow := WormLook.feature_texture(3)
	var cap := WormLook.feature_texture(3, Players.P2)
	assert_object(bow).is_not_null()
	assert_object(cap).is_not_null()
	assert_bool(bow != cap).is_true()


func test_undrawn_stages_and_moods_fall_back() -> void:
	assert_object(WormLook.segment_texture(0, 5, &"body")).is_same(WormLook.segment_texture(0, 3, &"body"))
	assert_object(WormLook.face_texture(1, 1, &"no_such_mood")).is_same(WormLook.face_texture(1, 1, &"idle"))
	assert_object(WormLook.face_texture(0, 2, &"chomp")).is_same(WormLook.face_texture(0, 2, &"chomp_1"))
	assert_str(String(WormLook.mouth_mood(2))).is_equal("open")


func test_eight_flavours_have_their_own_tint() -> void:
	var seen := {}
	for f in FLAVOURS:
		var c := WormLook.flavour_tint(f)
		assert_bool(c != Color.WHITE).override_failure_message(String(f)).is_true()
		assert_bool(seen.has(c)).override_failure_message(String(f) + " repeats a colour").is_false()
		seen[c] = true
	assert_object(WormLook.flavour_tint(&"")).is_equal(Color.WHITE)


func test_the_band_is_neutral_so_the_tint_shows_true() -> void:
	for stage in range(1, 4):
		var img := WormLook.segment_texture(0, stage, &"band").get_image()
		var lit := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					assert_float(maxf(absf(c.r - c.g), absf(c.g - c.b))).is_less(0.03)
					if c.v > 0.6:
						lit += 1
		assert_int(lit).override_failure_message("band s%d has no light pixels" % stage).is_greater(4)
