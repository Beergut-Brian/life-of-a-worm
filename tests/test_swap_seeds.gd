## X-10 (worm-gap-close-39, Gary's pick): the Mole's seeds match what you gave him. A stone thing
## brings two pebbles (a rock garden), a bug thing two bug eggs (a bug garden); anything else, or a
## thing that is itself a seed, brings plain seeds, so a swap never copies a seed. His offer bubble
## shows the seed he will give, and seeds left lying there come back as the same seed after a reload.
## Both seeds pop out behind him, away from the worm. Runs in its own Save profile.
class_name TestSwapSeeds
extends GdUnitTestSuite

const SUITE := "swap_seeds"
const PLANET := preload("res://scenes/levels/planet.tscn")
const FOODS := "res://data/foods/"
const CLEAR_PX := 64.0

var _level: PlanetLevel


func before() -> void:
	SuiteSandbox.enter(SUITE)


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	SuiteSandbox.leave()


func before_test() -> void:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	Audio.played.clear()


func after_test() -> void:
	_free_level()
	get_tree().paused = false
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _free_level() -> void:
	for p in Audio._pool:
		p.stop()
	if is_instance_valid(_level):
		for n in _level.find_children("*", "AudioStreamPlayer", true, false):
			n.stop()
		remove_child(_level)
		_level.free()
	_level = null


func _food(id: StringName) -> FoodData:
	return load(FOODS + String(id) + ".tres")


func _gives(id: StringName) -> String:
	return String(SwapShop.seed_for(_food(id)).id)


func test_seeds_follow_the_flavour_of_what_you_gave() -> void:
	assert_str(_gives(&"fossil")).is_equal("pebble")       # stone
	assert_str(_gives(&"boulder")).is_equal("pebble")
	assert_str(_gives(&"brick")).is_equal("seed")          # junk: plain
	assert_str(_gives(&"honeydew")).is_equal("bug_egg")    # bug
	assert_str(_gives(&"grub")).is_equal("bug_egg")
	assert_str(_gives(&"mushroom")).is_equal("seed")       # root
	assert_str(_gives(&"bottle_cap")).is_equal("seed")
	assert_str(_gives(&"droplet")).is_equal("seed")        # water: no water garden
	assert_str(_gives(&"crystal")).is_equal("seed")        # the crystal seed is a core crystal, too big


func test_a_seed_is_never_copied() -> void:
	assert_str(_gives(&"pebble")).is_equal("seed")
	assert_str(_gives(&"bug_egg")).is_equal("seed")
	assert_str(_gives(&"ore_nugget")).is_equal("seed")
	assert_str(String(SwapShop.seed_for(null).id)).is_equal("seed")


func test_every_seed_he_gives_plants_a_garden_and_is_small() -> void:
	var garden_tiles: Dictionary = (load("res://data/rings/rings.tres") as RingSet).garden_tiles
	var seen := {}
	for f in ResourceLoader.list_directory(FOODS):
		if not f.ends_with(".tres"):
			continue
		var got := SwapShop.seed_for(load(FOODS + f))
		assert_bool(got is RingFood).is_true()
		var plants := (got as RingFood).plants
		assert_bool(garden_tiles.has(plants)).override_failure_message("%s -> %s plants %s" % [f, got.id, plants]).is_true()
		assert_int(got.size_stage).is_less_equal(SwapShop.SEED.size_stage)
		seen[got.id] = true
	assert_array(seen.keys()).contains_exactly_in_any_order([&"seed", &"pebble", &"bug_egg"])


func _to_mole(w: Worm) -> void:
	var shop := _level.home_slice.shop
	w.warp_to(shop.mole_position() + (shop.position.normalized().orthogonal() * 20.0))
	for f in get_tree().get_nodes_in_group(&"food"):
		if f.has_method("take") and f.global_position.distance_to(w.mouth_position()) < CLEAR_PX:
			f.take()


func test_a_stone_thing_swaps_for_two_pebbles_that_stay_pebbles_after_a_reload() -> void:
	BaitTins.open(0)
	Save.wipe()
	_level = PLANET.instantiate()
	add_child(_level)
	_level.home_slice.box.pause_tree = false
	var w := _level.spawn_worm(Players.P1)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	var shop := _level.home_slice.shop
	_to_mole(w)
	shop.pop_out()
	shop._set_state(SwapShop.State.OPEN)
	var got := []
	shop.traded.connect(func(_p: int, gave: StringName, g: StringName) -> void: got.append([gave, g]))
	var f := _level._add_food(&"fossil", w.mouth_position() + Vector2(2, 0))
	w.carrying = f
	f.set_carried(true)
	assert_bool(shop.can_trade(w)).is_true()
	assert_bool(shop.trade(w)).is_true()
	assert_array(got).is_equal([[&"fossil", &"pebble"]])
	assert_int(shop.loose.size()).is_equal(SwapShop.SEEDS_PER_TRADE)
	for s in shop.loose:
		assert_str(String(s.data.id)).is_equal("pebble")
		assert_bool(s.is_in_group(&"food")).is_true()
	assert_int(Audio.played.get("swap", 0)).is_equal(1)
	_level.save_now()
	_free_level()
	Save.use_slot("")
	BaitTins.open(0)
	_level = PLANET.instantiate()
	add_child(_level)
	_level.home_slice.box.pause_tree = false
	await get_tree().physics_frame
	shop = _level.home_slice.shop
	assert_int(shop.loose.size()).is_equal(SwapShop.SEEDS_PER_TRADE)
	for s in shop.loose:
		assert_str(String(s.data.id)).is_equal("pebble")


func test_an_old_tin_without_seed_ids_gets_plain_seeds() -> void:
	BaitTins.open(1)
	Save.wipe()
	_level = PLANET.instantiate()
	add_child(_level)
	var shop := _level.home_slice.shop
	for s in shop.loose:
		s.queue_free()
	shop.loose.clear()
	shop.from_dict({ "kept": ["scrap"], "trades": 1, "loose": [[shop.position.x, shop.position.y]] })
	await get_tree().process_frame
	assert_int(shop.loose.size()).is_equal(1)
	assert_str(String(shop.loose[0].data.id)).is_equal("seed")


## Both gifts reach the player: they pop out behind the Mole, so a worm waiting at his counter does
## not swallow one the same frame (it did: the kid saw one seed for a swap of "two").
func test_a_worm_waiting_at_the_counter_does_not_swallow_a_gift() -> void:
	BaitTins.open(2)
	Save.wipe()
	_level = PLANET.instantiate()
	add_child(_level)
	_level.home_slice.box.pause_tree = false
	var w := _level.spawn_worm(Players.P1)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	var shop := _level.home_slice.shop
	_to_mole(w)
	shop.pop_out()
	shop._set_state(SwapShop.State.OPEN)
	var f := _level._add_food(&"honeydew", w.mouth_position() + Vector2(2, 0))
	w.carrying = f
	f.set_carried(true)
	assert_bool(shop.trade(w)).is_true()
	for i in 30:
		await get_tree().physics_frame
	assert_int(shop.loose.size()).is_equal(SwapShop.SEEDS_PER_TRADE)
	for s in shop.loose:
		assert_str(String(s.data.id)).is_equal("bug_egg")
		assert_float(s.global_position.distance_to(w.mouth_position())).is_greater(8.0)
