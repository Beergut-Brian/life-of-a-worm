## Pets 2 (feature/pets-2): the glow-worm lamp and the ant crew. A glow-worm carried home alive
## becomes a pet (the ladybird's carry rule) and plays the meet beat; its lamp lights only while
## the room is dark (night, or home in a dark ring); the ant crew walks to the garden's seed bed
## every PetData.every s and nudges it on by PetData.nudge planet seconds; only one crew at a time.
## Runs in its own Save profile (SuiteSandbox), never the real user data.
class_name TestPets2
extends GdUnitTestSuite

const SUITE := "pets_2"
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


func _hollow(at: Vector2, r := 40.0) -> void:
	var c := _level.world.shape.cell_at(at)
	var n := ceili(r / 16.0) + 1
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			var cell := c + Vector2i(x, y)
			if _level.world.shape.center_of(cell).distance_to(at) <= r:
				_level.world.dig(cell)


func _wild(id: StringName) -> WildPet:
	for e in _level.home_slice.wild_more:
		if e.node.pet.id == id:
			return e.node
	return null


## Carries wild pet `bug` from the worm's mouth into a home dug right here.
func _carry_home(w: Worm, bug: WildPet) -> void:
	_intent = {}   # let go of X first: a fresh hold picks up
	await _frames(2)
	bug.position = w.mouth_position() + Vector2(2, 0)
	bug.home = bug.position
	_intent = { "carry": true }
	await _frames(3)
	assert_object(w.carrying).is_same(bug)
	_hollow(w.cam_position())
	_level.burrow.set_home(w.cam_position())
	await _frames(3)


## A seed bed a few tiles from home: a worm-eaten cell (castings) with a garden planted in it.
func _garden_near(home: Vector2) -> int:
	var world := _level.world
	var c := world.shape.cell_at(home)
	for d in range(4, 9):
		for o: Vector2i in [Vector2i(d, 0), Vector2i(-d, 0), Vector2i(0, d), Vector2i(0, -d)]:
			var cell := c + o
			if world.eat_tile(cell, 0) and world.plant_seed(cell, &"root"):
				return world.gardens().size() - 1
	return -1


func _pet(id: StringName) -> Pet:
	var p: Pet = _level.burrow.add_pet(id)
	p.set_physics_process(false)
	p.data = p.data.duplicate()   # tests tune it; never the shared resource
	return p


func test_a_glowworm_carried_home_alive_becomes_a_pet() -> void:
	_open(0)
	var w := _p1()
	var bug := _wild(&"glowworm")
	assert_object(bug).is_not_null()
	await _carry_home(w, bug)
	assert_array(_level.burrow.pet_ids()).contains_exactly([&"glowworm"])
	assert_object(w.carrying).is_null()
	assert_bool(bug.is_available()).is_false()
	assert_int(Audio.played.get("pet_home", 0)).is_equal(1)
	# First of its kind: the meet beat (bubble), remembered in the tin.
	var pet: Pet = _level.burrow.pets[0]
	assert_str(String(pet.data.job)).is_equal("lamp")
	assert_int(Audio.played.get("pet_meet", 0)).is_equal(1)
	assert_float(pet.meet_t).is_greater_equal(0.0)
	assert_array(_level.burrow.met).contains([&"glowworm"])
	assert_float(pet.position.distance_to(_level.burrow.home)).is_less(Burrow.room_tiles_for(1) * 16.0)


func test_the_lamp_lights_only_in_the_dark() -> void:
	_open(0)
	_p1()
	_level.burrow.set_home(_level.spawn_point)
	var pet := _pet(&"glowworm")
	assert_float(pet.light.texture_scale).is_equal_approx(pet.data.lamp_radius * 16.0 * 2.0 / 128.0, 0.001)
	# Daylight: no dark ring here and no night -> the lamp stays out.
	pet.data.dark_rings = []
	_level.burrow.night = false
	for i in 60:
		pet.step(0.05)
	assert_bool(pet.lit).is_false()
	assert_float(pet.light.energy).is_equal(0.0)
	assert_bool(pet.light.enabled).is_false()
	assert_int(Audio.played.get("pet_lamp", 0)).is_equal(0)
	# Night: it lights, brightens to full and wiggles now and then.
	_level.burrow.night = true
	var wiggled := false
	for i in 120:
		pet.step(0.05)
		wiggled = wiggled or pet.wiggle() > 0.0
	assert_bool(pet.lit).is_true()
	assert_bool(pet.light.enabled).is_true()
	assert_float(pet.light.energy).is_equal_approx(pet.data.lamp_energy, 0.001)
	assert_bool(wiggled).is_true()
	assert_int(Audio.played.get("pet_lamp", 0)).is_equal(1)
	# Morning: it fades out again.
	_level.burrow.night = false
	for i in 60:
		pet.step(0.05)
	assert_bool(pet.lit).is_false()
	assert_float(pet.wiggle()).is_equal(0.0)
	assert_bool(pet.light.enabled).is_false()
	# A dark ring (data) is dark by day too: the start is in one of the default dark rings.
	var ring := _level.world.ring_of(_level.world.shape.cell_at(_level.burrow.home))
	pet.data.dark_rings = [ring.id]
	pet.step(0.05)
	assert_bool(pet.lit).is_true()


func test_the_ant_crew_walks_to_the_garden_every_60_s() -> void:
	_open(0)
	var w := _p1()
	_hollow(w.cam_position())
	_level.burrow.set_home(w.cam_position())
	var gi := _garden_near(_level.burrow.home)
	assert_int(gi).is_greater_equal(0)
	var pet := _pet(&"ant_crew")
	assert_float(pet.data.every).is_equal(60.0)
	var bed: Vector2i = _level.world.gardens()[gi].cell
	for trip in 2:
		pet.step(pet.data.every - 0.5)
		assert_int(pet.state).is_equal(Pet.State.HOME)
		pet.step(1.0)
		assert_int(pet.state).is_equal(Pet.State.WALK)
		assert_that(pet.target_cell).is_equal(bed)
		var went := 0.0
		while pet.state == Pet.State.WALK and went < 30.0:
			pet.step(0.1)
			went += 0.1
		assert_int(pet.state).is_equal(Pet.State.WORK)
		var at_bed := _level.world.shape.center_of(bed)
		assert_float(pet.position.distance_to(_level.burrow.to_local(_level.world.to_global(at_bed)))).is_less(2.0)
		while pet.state != Pet.State.HOME and went < 90.0:
			pet.step(0.1)
			went += 0.1
		assert_int(pet.state).is_equal(Pet.State.HOME)
		assert_int(pet.tends).is_equal(trip + 1)
	assert_int(Audio.played.get("pet_tend", 0)).is_equal(2)
	assert_int(Audio.played.get("pet_walk", 0)).is_equal(2)


func test_the_seed_bed_nudge_comes_from_data() -> void:
	_open(0)
	var w := _p1()
	_hollow(w.cam_position())
	_level.burrow.set_home(w.cam_position())
	var gi := _garden_near(_level.burrow.home)
	var pet := _pet(&"ant_crew")
	pet.data.nudge = 20.0
	var g: Dictionary = _level.world.gardens()[gi]
	var before := float(g.next)
	pet.step(pet.data.every + 0.1)
	for i in 600:
		pet.step(0.1)
		if pet.tends > 0:
			break
	assert_int(pet.tends).is_equal(1)
	assert_float(float(g.next)).is_equal_approx(before - 20.0, 0.001)
	# The bed eaten: the crew still walks there, but there is nothing to nudge.
	_level.world.eat_tile(g.cell, 0)
	assert_int(Pet.seed_bed_at(_level.world, g.cell)).is_equal(-1)
	var after_eat := float(g.next)
	for i in 1500:
		pet.step(0.1)
	assert_int(pet.tends).is_equal(1)
	assert_float(float(g.next)).is_equal(after_eat)


func test_only_one_ant_crew_at_a_time() -> void:
	_open(0)
	var w := _p1()
	var crew := _wild(&"ant_crew")
	var n := 0
	for e in _level.home_slice.wild_more:
		if e.node.pet.id == &"ant_crew":
			n += 1
	assert_int(n).is_equal(1)
	await _carry_home(w, crew)
	assert_int(_level.burrow.pet_count(&"ant_crew")).is_equal(1)
	assert_bool(_level.burrow.can_keep(&"ant_crew")).is_false()
	assert_bool(_level.burrow.can_keep(&"glowworm")).is_true()
	# The wild crew never turns up again while one lives at home.
	_level.world.clock += crew.pet.regrow + 1.0
	await _frames(2)
	assert_bool(crew.is_available()).is_false()
	# One carried in anyway (it came back before the crew moved in): a hello, still one crew.
	crew.respawn()
	w.carrying = crew
	assert_str(String(_level.burrow.bring(w, crew))).is_equal("pet")
	assert_int(_level.burrow.pet_count(&"ant_crew")).is_equal(1)
	assert_bool(crew.is_available()).is_false()   # it ran back to the wild
	assert_int(Audio.played.get("pet_hello", 0)).is_equal(1)
	assert_int(Audio.played.get("pet_meet", 0)).is_equal(1)


func test_met_pets_are_saved_and_do_not_meet_again() -> void:
	_open(0)
	_p1()
	_level.burrow.set_home(_level.spawn_point)
	_level.burrow.add_pet(&"glowworm", 3.0)
	_level.burrow.met.append(&"glowworm")
	_level.save_now()
	var saved: Dictionary = Save.get_value("burrow", {})
	assert_array(saved.met).is_equal(["glowworm"])
	var hs: Dictionary = Save.get_value(HomeSlice.SAVE_KEY, {})
	assert_int(hs.wild_more.size()).is_equal(HomeSlice.MORE_PETS_AT.size())
	_free_level()
	Save.use_slot("")
	_open(0, false)
	assert_array(_level.burrow.pet_ids()).contains_exactly([&"glowworm"])
	assert_array(_level.burrow.met).contains_exactly([&"glowworm"])
	assert_float(_level.burrow.pets[0].meet_t).is_less(0.0)
	assert_int(_level.home_slice.wild_more.size()).is_equal(HomeSlice.MORE_PETS_AT.size())
