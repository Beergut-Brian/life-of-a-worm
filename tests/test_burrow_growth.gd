## B-06 and D-13 (worm-burrow-1): the burrow grows with the worm from data (data/burrow/growth.tres)
## and by the house stage is a cavern with a buried house whose rooms take trophies as furniture;
## sleeping opens the burrow's wall of pictures (BurrowWall), which lists every earned trait, and a
## player who shuts it without choosing gets the newest trait equipped into a free slot, once; it
## never swaps an active trait out. Own Save profile.
class_name TestBurrowGrowth
extends GdUnitTestSuite

const SUITE := "burrow_growth"
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
	for p in Audio._pool:
		p.stop()
	if is_instance_valid(_level):
		for n in _level.find_children("*", "AudioStreamPlayer", true, false):
			n.stop()
		remove_child(_level)
		_level.free()
	_level = null
	get_tree().paused = false
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _open(tin := 0) -> PlanetLevel:
	BaitTins.open(tin)
	Save.wipe()
	_level = PLANET.instantiate()
	add_child(_level)
	_level.home_slice.box.pause_tree = false
	return _level


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


## Stage 2, Wriggle on, Stone head earned with no slot left: it waits.
func _two_traits(w: Worm) -> void:
	w.model.start_at_stage(2)
	w.model.grant(&"wriggle")
	w.model.grant(&"stone_head")
	assert_array(w.model.active).contains_exactly([&"wriggle"])


func _fall_asleep(w: Worm) -> void:
	_hollow(w.cam_position())
	w.still_time = Burrow.SLEEP_STILL + 0.1
	await _frames(2)


func test_the_room_radius_grows_by_stage_from_data() -> void:
	var g: BurrowGrowth = load(BurrowGrowth.PATH)
	assert_object(g).is_not_null()
	var last := 0.0
	for s in range(1, 8):
		assert_float(Burrow.room_tiles_for(s)).is_equal(g.room_tiles[s - 1])
		assert_float(Burrow.room_tiles_for(s)).is_greater(last)
		assert_float(g.chamber_for(s)).is_less(g.room_for(s))
		last = Burrow.room_tiles_for(s)
	# The burrow reads the numbers, it does not hold them: other data, other room.
	var b := Burrow.new()
	var custom := BurrowGrowth.new()
	custom.room_tiles = PackedFloat32Array([3.0, 20.0])
	b.growth = custom
	b.stage = 2
	assert_float(b.room_tiles()).is_equal(20.0)
	b.free()


func test_each_stage_carves_a_bigger_chamber() -> void:
	_open()
	var w := _p1()
	_hollow(w.cam_position())
	var b := _level.burrow
	b.set_home(w.cam_position())
	var side := b.home.normalized().orthogonal()
	for s in range(2, 6):
		b.grow_to(s)
		var edge := b.home + side * (b.chamber_tiles() - 1.0) * 16.0
		assert_bool(_level.world.is_solid(_level.world.shape.cell_at(edge))).is_false()
		assert_float(b.room_tiles()).is_equal(b.growth.room_for(s))
	assert_int(Audio.played.get("burrow_grow", 0)).is_equal(4)


func test_the_buried_house_appears_at_stage_5_and_takes_furniture() -> void:
	_open()
	var w := _p1()
	_hollow(w.cam_position())
	var b := _level.burrow
	b.set_home(w.cam_position())
	b.grow_to(4)
	assert_bool(b.has_house()).is_false()
	assert_bool(b.house_spot_cells().is_empty()).is_true()
	b.grow_to(b.growth.house_stage)
	assert_int(b.growth.house_stage).is_equal(5)
	assert_bool(b.has_house()).is_true()
	assert_int(b.house_spot_cells().size()).is_equal(b.growth.house_spots())
	# The house is in the cavern: inside the room, and its rooms are dug out.
	for k in b.growth.house_spots():
		assert_bool(b.in_room(b.house_spot(k))).is_true()
	assert_bool(_level.world.is_solid(_level.world.shape.cell_at(b.house_spot(0)))).is_false()
	# A trophy brought home now is furniture: it stands in a room of the house.
	var f := _level._add_food(&"pebble", w.mouth_position() + Vector2(2, 0))
	w.carrying = f
	f.set_carried(true)
	b.note_pickup(w, false)
	b.bring(w, f)
	assert_bool(b.house_spot_cells().has(b.trophy_cells[-1])).is_true()
	var k := b.house_spot_cells().find(b.trophy_cells[-1])
	assert_vector(b.trophy_position(b.trophies.size() - 1)).is_equal(b.house_spot(k))
	# It comes back from the tin the same way.
	var d := b.to_dict()
	b.from_dict(d)
	assert_bool(b.has_house()).is_true()
	assert_bool(b.house_spot_cells().has(b.trophy_cells[-1])).is_true()


func test_a_grown_worms_new_home_gets_the_house_at_once() -> void:
	_open()
	var w := _p1()
	var b := _level.burrow
	b.grow_to(5)   # stage 5 before any home
	_hollow(w.cam_position())
	b.set_home(w.cam_position())
	assert_bool(b.has_house()).is_true()
	var edge := b.home + b.home.normalized().orthogonal() * (b.chamber_tiles() - 1.0) * 16.0
	assert_bool(_level.world.is_solid(_level.world.shape.cell_at(edge))).is_false()


func test_the_sleep_chooser_lists_the_earned_traits() -> void:
	_open()
	var w := _p1()
	_two_traits(w)
	await _fall_asleep(w)
	assert_bool(w.asleep).is_true()
	assert_bool(w.wall_open).is_true()
	assert_bool(w._wall is BurrowWall).is_true()
	var wall: BurrowWall = w._wall
	assert_array(wall.pictures()).contains_exactly([&"wriggle", &"stone_head"])
	assert_bool(wall.visible).is_true()


## Shut the wall to get out of it (B), choosing nothing.
func _shut_without_choosing(w: Worm) -> void:
	assert_bool(w.wall_open).is_true()
	_intent = { "wiggle": true }
	await _frames(1)
	_intent = {}
	await _frames(1)
	assert_bool(w.wall_open).is_false()


## Every slot full (stage 2, one slot, Wriggle on): shutting the wall equips nothing and takes nothing
## off. Stone head keeps waiting (GAME.md 2026-11-11: the wall never auto-unequips anything).
func test_the_newest_trait_waits_when_every_slot_is_full() -> void:
	_open()
	var w := _p1()
	_two_traits(w)
	await _fall_asleep(w)
	Audio.played.clear()   # equipping Wriggle on the way here played its own cue
	await _shut_without_choosing(w)
	assert_array(w.model.active).contains_exactly([&"wriggle"])
	assert_array(w.model.earned).contains_exactly([&"wriggle", &"stone_head"])
	assert_int(Audio.played.get("trait_swap", 0)).is_equal(0)
	assert_array(_level.burrow.offered.get(Players.P1, [])).not_contains([&"stone_head"])
	# Again: still nothing swapped.
	w.set_wall_open(true)
	await _frames(1)
	w.set_wall_open(false)
	assert_array(w.model.active).contains_exactly([&"wriggle"])


## A free slot: shutting the wall without choosing puts the newest trait in it, once per trait, and
## the tin remembers that it was offered.
func test_the_newest_trait_fills_a_free_slot_when_the_player_never_chooses() -> void:
	_open()
	var w := _p1()
	_two_traits(w)
	w.model.toggle(&"wriggle")   # the slot is free now, Stone head waiting
	assert_array(w.model.active).is_empty()
	await _fall_asleep(w)
	Audio.played.clear()
	await _shut_without_choosing(w)
	assert_array(w.model.active).contains_exactly([&"stone_head"])
	assert_int(Audio.played.get("trait_swap", 0)).is_greater_equal(1)
	# Once only: take it off by choice, sleep again, close: it stays the player's choice.
	w.model.toggle(&"stone_head")
	w.set_wall_open(true)
	await _frames(1)
	w.set_wall_open(false)
	assert_array(w.model.active).is_empty()
	# And it is remembered in the tin.
	var b := _level.burrow
	var d := b.to_dict()
	b.offered.clear()
	b.from_dict(d)
	assert_array(b.offered.get(Players.P1, [])).contains([&"stone_head"])


## A stage that adds a slot equips the newest waiting trait into it, and nothing comes off.
func test_a_stage_that_adds_a_slot_equips_the_newest_waiting_trait() -> void:
	_open()
	var w := _p1()
	_two_traits(w)
	await _fall_asleep(w)
	await _shut_without_choosing(w)
	assert_array(w.model.active).contains_exactly([&"wriggle"])
	var slots := w.model.slots()
	w.model.apex_eaten.append(2)
	var n := 0
	while w.model.stage < 3 and n < 100:
		w.model.add_segment(&"")
		n += 1
	assert_int(w.model.stage).is_equal(3)
	assert_int(w.model.slots()).is_greater(slots)
	assert_array(w.model.active).contains_exactly_in_any_order([&"wriggle", &"stone_head"])


func test_a_player_who_chooses_keeps_the_choice() -> void:
	_open()
	var w := _p1()
	_two_traits(w)
	await _fall_asleep(w)
	var wall: BurrowWall = w._wall
	# A on the picture under the cursor (Wriggle, first): takes it off. Then B.
	wall.cursor = 0
	_intent = { "confirm": true }
	await _frames(1)
	_intent = { "wiggle": true }
	await _frames(1)
	_intent = {}
	await _frames(1)
	assert_bool(w.wall_open).is_false()
	assert_array(w.model.active).is_empty()   # the player's choice: nothing forced back on
