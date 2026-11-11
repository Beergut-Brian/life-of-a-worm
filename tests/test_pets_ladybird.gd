## The ladybird (feature/slice-burrow-1): carried home alive (hold X) it becomes a pet that lives
## by the bed; it fetches a seed every PetData.every seconds while fewer than max_waiting wait;
## a wild one can also simply be eaten (it is small food, and it comes back later); pets are saved
## by id. Runs in its own Save profile.
class_name TestPetsLadybird
extends GdUnitTestSuite

const SUITE := "pets"
const PLANET := preload("res://scenes/levels/planet.tscn")

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


func _wild() -> WildPet:
	return _level.home_slice.wild[0].node


func test_a_ladybird_carried_home_alive_becomes_a_pet() -> void:
	_open(0)
	var w := _p1()
	_level.burrow.set_home(_level.local_point(30, 0))
	var bug := _wild()
	bug.position = w.mouth_position() + Vector2(2, 0)
	bug.home = bug.position
	_intent = { "carry": true }
	await _frames(3)
	assert_object(w.carrying).is_same(bug)
	_hollow(w.cam_position())
	_level.burrow.set_home(w.cam_position())   # home is right here now
	await _frames(3)
	assert_array(_level.burrow.pet_ids()).contains_exactly([&"ladybird"])
	assert_object(w.carrying).is_null()
	assert_bool(bug.is_available()).is_false()   # the wild one left (it turns up again later)
	assert_int(Audio.played.get("pet_home", 0)).is_equal(1)
	assert_float(_level.burrow.pets[0].position.distance_to(_level.burrow.home)).is_less(Burrow.ROOM_TILES * 16.0)


func test_a_wild_ladybird_is_small_food_and_comes_back() -> void:
	_open(0)
	var w := _p1()
	var bug := _wild()
	var growth := w.model.growth + w.model.segments.size() * w.rules.growth_per_segment
	bug.position = w.mouth_position()
	await _frames(3)
	assert_bool(bug.is_available()).is_false()
	assert_float(w.model.growth + w.model.segments.size() * w.rules.growth_per_segment).is_greater(growth)
	assert_array(_level.burrow.pet_ids()).is_empty()
	_level.world.clock += _level.home_slice.LADYBIRD.regrow + 1.0
	await _frames(2)
	assert_bool(bug.is_available()).is_true()


func test_the_pet_fetches_seeds_to_the_bed_up_to_its_limit() -> void:
	_open(0)
	var w := _p1()
	_hollow(w.cam_position())
	_level.burrow.set_home(w.cam_position())
	var pet: Pet = _level.burrow.add_pet(&"ladybird")
	pet.set_physics_process(false)
	var d := pet.data
	pet.step(d.every - 0.5)
	assert_int(pet.state).is_equal(Pet.State.HOME)
	pet.step(1.0)
	assert_int(pet.state).is_equal(Pet.State.AWAY)
	assert_int(Audio.played.get("pet_away", 0)).is_equal(1)
	for i in 200:
		pet.step(0.05)
	assert_int(pet.state).is_equal(Pet.State.HOME)
	assert_int(_level.burrow.pantry.size()).is_equal(1)
	assert_int(Audio.played.get("pet_fetch", 0)).is_equal(1)
	var seed: Node2D = _level.burrow.pantry[0]
	assert_str(String(seed.data.id)).is_equal("seed")
	assert_bool(_level.burrow.in_room(seed.position)).is_true()
	# Fill to the limit: then it stays home.
	for k in 10:
		for i in 300:
			pet.step(0.1)
	assert_int(_level.burrow.pantry.size()).is_equal(d.max_waiting)
	assert_int(pet.state).is_equal(Pet.State.HOME)
	# Eating one frees a place; the job carries on.
	seed.take()
	await _frames(1)
	assert_int(_level.burrow.pantry.size()).is_equal(d.max_waiting - 1)


func test_pets_are_saved_by_id() -> void:
	_open(0)
	_p1()
	_level.burrow.set_home(_level.spawn_point)
	_level.burrow.add_pet(&"ladybird", 12.5)
	_level.save_now()
	var saved: Dictionary = Save.get_value("burrow", {})
	assert_array(saved.pets).is_equal([{ "id": "ladybird", "t": 12.5 }])
	_free_level()
	Save.use_slot("")
	_open(0, false)
	assert_array(_level.burrow.pet_ids()).contains_exactly([&"ladybird"])
