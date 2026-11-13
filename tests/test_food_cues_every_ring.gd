## D-16 past the slice: every food in data/foods/, in every ring (dirt to sky), is a full RingFood
## (flavour, growth, size stage, ring, regrow time; 0 for prop debris) with its own swallow sound on top of the chomp.
## Deep-rock, core, surface and sky foods borrow existing cues by material (stones clack, crystals and
## metal clink, wood munches, balloons boing) until the Audio lane makes per-food files.
## cloud_puff.tres waits on feature/worm-gap-close-9 (it changes that file), so it is exempt here.
class_name TestFoodCuesEveryRing
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")
const RINGS := [&"dirt", &"topsoil", &"deep_rock", &"core", &"surface", &"sky"]
## Food files another in-flight branch edits; its cue lands with or after that branch.
const WAITING := [&"cloud_puff"]


func before() -> void:
	SuiteSandbox.enter("food_cues_every_ring")


func after() -> void:
	for p in Audio._pool:
		p.stop()
	for i in 3:
		await get_tree().process_frame
	for p in Audio._pool:
		p.stream = null
	SuiteSandbox.leave()


func _foods() -> Array[FoodData]:
	var out: Array[FoodData] = []
	for f in DirAccess.get_files_at("res://data/foods"):
		if f.ends_with(".tres"):
			out.append(load("res://data/foods/" + f) as FoodData)
	return out


func test_every_food_file_is_a_full_ring_food_with_a_sound_file() -> void:
	var by_ring := {}
	for d in _foods():
		assert_object(d).is_not_null()
		assert_bool(d is RingFood).override_failure_message("%s is not a RingFood" % d.id).is_true()
		var r := d as RingFood
		assert_bool(r.ring in RINGS).override_failure_message("%s: ring %s" % [d.id, r.ring]).is_true()
		assert_str(String(d.flavour)).override_failure_message("%s: no flavour" % d.id).is_not_empty()
		assert_float(d.growth).override_failure_message("%s: no growth" % d.id).is_greater(0.0)
		assert_int(d.size_stage).is_between(1, 6)
		# 0 = debris from a broken prop (brick, plank, turf...): a house never grows back.
		assert_float(r.regrow_time).override_failure_message("%s: regrow" % d.id).is_greater_equal(0.0)
		by_ring[r.ring] = int(by_ring.get(r.ring, 0)) + 1
		if d.id in WAITING:
			continue
		assert_str(d.eat_cue).override_failure_message("%s has no swallow sound" % d.id).is_not_empty()
		assert_bool(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % d.eat_cue)) \
				.override_failure_message("%s: no file for %s" % [d.id, d.eat_cue]).is_true()
	# Every ring the worm digs through has foods on file.
	for ring in RINGS:
		assert_int(int(by_ring.get(ring, 0))).override_failure_message("no foods in %s" % ring).is_greater(0)


func test_a_deep_rock_and_a_sky_food_play_their_sound_on_a_swallow() -> void:
	var w: Worm = WORM.instantiate()
	w.model = WormGrowth.new()
	w.model.start_at_stage(5)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	auto_free(w)
	var voice := w.get_node("FoodVoice") as FoodVoice
	for id in [&"amber", &"sky_balloon"]:
		var d := load("res://data/foods/%s.tres" % id) as FoodData
		var before := int(Audio.played.get(d.eat_cue, 0))
		w.feed(d)
		assert_int(int(Audio.played.get(d.eat_cue, 0)) - before).is_equal(1)
	assert_array(voice.played).is_equal(["jar_clink", "boing"])
