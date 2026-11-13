## D-16: every dirt and topsoil food has its own swallow sound on top of the chomp (FoodVoice),
## a tin load that hides eaten pickups is silent, and a food with no cue still just chomps.
class_name TestFoodVoice
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")
const SLICE_RINGS := [&"dirt", &"topsoil"]


func before() -> void:
	SuiteSandbox.enter("food_voice")


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


func _worm() -> Worm:
	var w: Worm = WORM.instantiate()
	w.model = WormGrowth.new()
	w.model.start_at_stage(2)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	auto_free(w)
	return w


func test_every_dirt_and_topsoil_food_has_its_own_sound_file() -> void:
	var n := 0
	for d in _foods():
		var ring: StringName = d.get("ring") if d.get("ring") != null else &""
		if not ring in SLICE_RINGS:
			continue
		n += 1
		assert_str(d.eat_cue).override_failure_message("%s has no swallow sound" % d.id).is_not_empty()
		assert_bool(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % d.eat_cue)) \
				.override_failure_message("%s: no file for %s" % [d.id, d.eat_cue]).is_true()
	assert_int(n).is_greater_equal(9)


func test_swallowing_plays_the_food_sound_and_the_chomp() -> void:
	var w := _worm()
	var grub := load("res://data/foods/grub.tres") as FoodData
	var voice := w.get_node("FoodVoice") as FoodVoice
	var squeaks := int(Audio.played.get("grub_squeak", 0))
	var chomps := 0
	for k in Audio.played:
		if String(k).begins_with("chomp_"):
			chomps += int(Audio.played[k])
	w.feed(grub)
	assert_int(int(Audio.played.get("grub_squeak", 0)) - squeaks).is_equal(1)
	assert_array(voice.played).contains(["grub_squeak"])
	var after := 0
	for k in Audio.played:
		if String(k).begins_with("chomp_"):
			after += int(Audio.played[k])
	assert_int(after - chomps).is_equal(1)


func test_a_food_without_a_cue_just_chomps() -> void:
	var w := _worm()
	var plain := FoodData.new()
	plain.id = &"fake_plain"
	w.feed(plain)
	assert_array((w.get_node("FoodVoice") as FoodVoice).played).is_empty()


func test_loading_a_tin_that_hides_eaten_pickups_is_silent() -> void:
	var f := RingPickup.new()
	f.data = load("res://data/foods/pebble.tres")
	add_child(f)
	auto_free(f)
	var before := int(Audio.played.get("rock_beetle_clack", 0))
	f.take()   # what RingsDirector / PlanetLevel do for a saved "eaten"
	assert_int(int(Audio.played.get("rock_beetle_clack", 0))).is_equal(before)
