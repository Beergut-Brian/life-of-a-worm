## The Mole's swap shop (feature/slice-burrow-1): the Mole is never food and never a threat; he pops
## out of the wall when a worm comes near, startled, then apologises; carry something to him and A
## swaps it for two seeds he keeps on his shelf; seeds and creatures are not for swapping; the
## shop and any seeds still lying there are saved. Runs in its own Save profile.
class_name TestSwapShop
extends GdUnitTestSuite

const SUITE := "swap"
const PLANET := preload("res://scenes/levels/planet.tscn")
const CLEAR_PX := 64.0   # nothing the level put down stays this close to the worm's mouth at the Mole

var _level: PlanetLevel
var _intent := {}


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
	_intent = {}
	Audio.played.clear()


func after_test() -> void:
	_free_level()
	get_tree().paused = false
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _open(tin: int, fresh := true) -> PlanetLevel:
	BaitTins.open(tin)
	if fresh:
		Save.wipe()
	_level = PLANET.instantiate()
	add_child(_level)
	_level.home_slice.box.pause_tree = false
	return _level


func _free_level() -> void:
	# Stop every sound first: a placeholder beep freed mid-play leaks its playback at exit.
	for p in Audio._pool:
		p.stop()
	if is_instance_valid(_level):
		for n in _level.find_children("*", "AudioStreamPlayer", true, false):
			n.stop()
		remove_child(_level)
		_level.free()
	_level = null


func _p1() -> Worm:
	var w := _level.spawn_worm(Players.P1)
	w.autopilot = func(_w: Worm) -> Dictionary: return _intent
	return w


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Digs a round room at `at` (world px).
func _hollow(at: Vector2, r := 40.0) -> void:
	var c := _level.world.shape.cell_at(at)
	var n := ceili(r / 16.0) + 1
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			var cell := c + Vector2i(x, y)
			if _level.world.shape.center_of(cell).distance_to(at) <= r:
				_level.world.dig(cell)


func _shop() -> SwapShop:
	return _level.home_slice.shop


## Moves the worm to the Mole's counter and clears the counter: a fresh planet takes a random seed
## (randi), and about 1 in 10 scatter a pickup (grub, pebble, seed, boulder) within reach of the
## mouth there; the worm would carry, eat or bonk that instead of what the test puts down.
func _to_mole(w: Worm) -> void:
	w.warp_to(_shop().mole_position() + (_shop().position.normalized().orthogonal() * 20.0))
	for f in get_tree().get_nodes_in_group(&"food"):
		if f.has_method("take") and f.global_position.distance_to(w.mouth_position()) < CLEAR_PX:
			f.take()


func test_the_mole_is_never_food() -> void:
	_open(0)
	assert_bool(_shop().is_in_group(&"food")).is_false()
	assert_bool(_shop().is_in_group(&"jarling")).is_true()
	assert_bool(_shop().is_in_group(&"creature")).is_true()


func test_he_pops_out_surprised_then_apologises() -> void:
	_open(0)
	var w := _p1()
	assert_int(_shop().state).is_equal(SwapShop.State.HIDDEN)
	_to_mole(w)
	await _frames(2)
	assert_int(_shop().state).is_equal(SwapShop.State.POP)
	assert_int(Audio.played.get("mole_pop", 0)).is_equal(1)
	await _frames(40)
	assert_int(_shop().state).is_equal(SwapShop.State.SORRY)
	assert_int(Audio.played.get("mole_sorry", 0)).is_equal(1)
	await _frames(90)
	assert_int(_shop().state).is_equal(SwapShop.State.OPEN)
	assert_bool(_level.home_slice.tlog.is_found(&"creatures", &"mole")).is_true()
	# Left alone, he goes back in.
	w.warp_to(_level.spawn_point)
	await _frames(int(SwapShop.HIDE_AFTER * 60.0) + 10)
	assert_int(_shop().state).is_equal(SwapShop.State.HIDDEN)


func test_a_carried_thing_swaps_for_two_seeds() -> void:
	_open(0)
	var w := _p1()
	_to_mole(w)
	_shop().pop_out()
	_shop()._set_state(SwapShop.State.OPEN)
	var peb := _level._add_food(&"bottle_cap", w.mouth_position() + Vector2(2, 0))
	_intent = { "carry": true }
	await _frames(3)
	assert_object(w.carrying).is_same(peb)
	assert_bool(_shop().can_trade(w)).is_true()
	await _frames(1)
	assert_bool(_shop().ready_for.get(Players.P1, false)).is_true()
	assert_str(HomeSlice.token_for(w, true, true)).is_equal("a")
	assert_bool(_shop().trade(w)).is_true()
	assert_object(w.carrying).is_null()
	assert_array(_shop().kept).contains_exactly([&"bottle_cap"])
	assert_int(_shop().loose.size()).is_equal(SwapShop.SEEDS_PER_TRADE)
	for s in _shop().loose:
		assert_str(String(s.data.id)).is_equal("seed")
		assert_bool(s.is_in_group(&"food")).is_true()
	assert_int(Audio.played.get("swap", 0)).is_equal(1)
	assert_int(_shop().state).is_equal(SwapShop.State.HAPPY)


func test_seeds_and_creatures_are_not_for_swapping() -> void:
	_open(0)
	var w := _p1()
	_to_mole(w)
	_shop()._set_state(SwapShop.State.OPEN)
	var seed := _level._add_food(&"seed", w.mouth_position() + Vector2(2, 0))
	_intent = { "carry": true }
	await _frames(3)
	assert_object(w.carrying).is_same(seed)
	assert_bool(_shop().can_trade(w)).is_false()
	assert_bool(_shop().trade(w)).is_false()
	assert_object(w.carrying).is_same(seed)
	assert_int(Audio.played.get("boop", 0)).is_greater(0)


func test_the_shop_is_saved_with_its_loose_seeds() -> void:
	_open(0)
	var w := _p1()
	_to_mole(w)
	_shop()._set_state(SwapShop.State.OPEN)
	_level._add_food(&"bottle_cap", w.mouth_position() + Vector2(2, 0))
	_intent = { "carry": true }
	await _frames(3)
	_shop().trade(w)
	_level.save_now()
	_free_level()
	Save.use_slot("")
	_open(0, false)
	await _frames(1)
	assert_array(_shop().kept).contains_exactly([&"bottle_cap"])
	assert_int(_shop().trades).is_equal(1)
	assert_int(_shop().loose.size()).is_equal(SwapShop.SEEDS_PER_TRADE)
