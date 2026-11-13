## The burrow as home (feature/slice-burrow-1): a trophy lands on the dug ledge nearest the worm,
## a notch is dug when there is no ledge, trophy families give a capped standing bonus that every
## worm feels (and wears as a charm), the room grows with the stage, sleeping saves and a waiting
## trait opens the wall, Y awake is the tackle box, and the whole home round-trips through the tin
## and rides into a jar. Quitting at any moment loses nothing. Runs in its own Save profile.
class_name TestBurrowHome
extends GdUnitTestSuite

const SUITE := "burrow_home"
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


func _home_here(w: Worm) -> void:
	_hollow(w.cam_position(), 40.0)
	_level.burrow.set_home(w.cam_position())


func _bring(w: Worm, id: StringName, from := Vector2.INF) -> Node2D:
	var f := _level._add_food(id, w.mouth_position() + Vector2(2, 0))
	w.carrying = f
	f.set_carried(true)
	_level.burrow.note_pickup(w, false)
	_level.burrow.bring(w, f)
	return f


func test_trophy_lands_on_the_dug_ledge_nearest_the_worm() -> void:
	_open(0)
	var w := _p1()
	_home_here(w)
	var b := _level.burrow
	var near := b.home + b.home.normalized().orthogonal() * 30.0
	var ledge := b.free_ledge(near)
	assert_bool(ledge != Vector2i(-99999, -99999)).is_true()
	assert_bool(_level.world.is_solid(ledge)).is_false()
	var at := _level.world.shape.center_of(ledge)
	assert_bool(_level.world.is_solid(_level.world.shape.cell_at(at - at.normalized() * 16.0))).is_true()
	w.warp_to(near)
	_bring(w, &"pebble")
	assert_array(b.trophies).contains_exactly([&"pebble"])
	assert_bool(b.trophy_cells[0] == b.free_ledge(near)).is_false()   # that ledge is taken now
	assert_float(_level.world.shape.center_of(b.trophy_cells[0]).distance_to(near)).is_less(40.0)
	assert_int(Audio.played.get("home_trophy", 0)).is_equal(1)


func test_no_ledge_digs_a_notch_so_nothing_is_refused() -> void:
	_open(0)
	var w := _p1()
	_level.burrow.set_home(_level.local_point(40, 0))   # home in solid dirt: no ledge anywhere in it
	var b := _level.burrow
	assert_bool(b.free_ledge(b.home) == Vector2i(-99999, -99999)).is_true()
	var before := b.trophies.size()
	_bring(w, &"pebble")
	assert_int(b.trophies.size()).is_equal(before + 1)
	assert_bool(_level.world.is_solid(b.trophy_cells[-1])).is_false()   # the notch is dug


func test_family_bonus_is_felt_by_every_worm_and_capped() -> void:
	_open(0)
	var w := _p1()
	_home_here(w)
	var base := w.model.stats.value("wiggle_hop")
	var fam: TrophyFamily = load("res://data/trophies/stones.tres")
	var per: float = fam.per_trophy["wiggle_hop"]
	_bring(w, &"pebble")
	assert_float(w.model.stats.value("wiggle_hop")).is_equal_approx(base + per, 0.001)
	var p2 := _level.spawn_worm(Players.P2)
	assert_float(p2.model.stats.value("wiggle_hop")).is_equal_approx(base + per, 0.001)
	for i in fam.cap + 2:
		_bring(w, &"pebble")
	assert_float(w.model.stats.value("wiggle_hop")).is_equal_approx(base + per * fam.cap, 0.001)
	# Other stats untouched; a family not on the shelf gives nothing.
	assert_float(w.model.stats.value("pull_radius")).is_equal(0.0)
	# Traits still stack on top through the one resolver.
	w.model.start_at_stage(2)
	w.model.grant(&"wriggle")
	assert_float(w.model.stats.value("wiggle_hop")).is_greater_equal(base + per * fam.cap)
	# It shows on the worm: a charm node drawing the stones family.
	var charms := _level.get_children().filter(func(n): return n is TrophyCharms and n.worm == w)
	assert_int(charms.size()).is_equal(1)
	assert_int(int(_level.burrow.family_counts().get(&"stones", 0))).is_equal(fam.cap + 3)


func test_trading_a_trophy_away_drops_its_bonus() -> void:
	_open(0)
	var w := _p1()
	_home_here(w)
	var base := w.model.stats.value("speed")
	_bring(w, &"grub")
	assert_float(w.model.stats.value("speed")).is_greater(base)
	assert_str(String(_level.burrow.remove_trophy(&"grub"))).is_equal("grub")
	assert_float(w.model.stats.value("speed")).is_equal_approx(base, 0.001)


func test_the_burrow_grows_with_the_stage() -> void:
	_open(0)
	var w := _p1()
	_home_here(w)
	var b := _level.burrow
	var r1 := b.room_tiles()
	var far := b.home + b.home.normalized().orthogonal() * (r1 * 16.0 + 10.0)
	assert_bool(b.in_room(far)).is_false()
	w.model.start_at_stage(2)
	w.stage_changed.emit(Players.P1, 1, 2)
	assert_int(b.stage).is_equal(2)
	assert_float(b.room_tiles()).is_greater(r1)
	assert_bool(b.in_room(far)).is_true()
	assert_int(Audio.played.get("burrow_grow", 0)).is_equal(1)
	# The chamber was carved bigger round the bed.
	var edge := b.home + b.home.normalized().orthogonal() * (b.chamber_tiles() - 0.3) * 16.0
	assert_bool(_level.world.is_solid(_level.world.shape.cell_at(edge))).is_false()


func test_sleep_saves_and_a_waiting_trait_opens_the_wall() -> void:
	_open(0)
	var w := _p1()
	w.model.start_at_stage(2)
	w.model.grant(&"wriggle")
	w.model.grant(&"stone_head")   # one slot at stage 2: this one waits
	assert_int(w.model.earned.size()).is_greater(w.model.active.size())
	_hollow(w.cam_position())
	var saves := _level.saves
	w.still_time = Burrow.SLEEP_STILL + 0.1
	await _frames(2)
	assert_bool(w.asleep).is_true()
	assert_int(_level.saves).is_greater(saves)
	assert_bool(w.wall_open).is_true()
	assert_bool(w.in_burrow).is_true()


func test_y_awake_is_the_tackle_box_and_asleep_is_the_wall() -> void:
	_open(0)
	var w := _p1()
	_home_here(w)
	await _frames(1)
	_intent = { "tackle": true }
	await _frames(1)
	_intent = {}
	assert_bool(_level.home_slice.box.is_open).is_true()
	assert_bool(w.wall_open).is_false()
	_level.home_slice.box.close()
	w.asleep = true
	await _frames(1)
	_intent = { "tackle": true }
	await _frames(1)
	_intent = {}
	assert_bool(w.wall_open).is_true()
	assert_bool(_level.home_slice.box.is_open).is_false()


func test_home_round_trips_and_quitting_loses_nothing() -> void:
	_open(1)
	var w := _p1()
	_home_here(w)
	_level.save_now()
	# All after the last autosave: a trophy, a pet, a pantry seed, a page, a swap.
	_bring(w, &"pebble")
	_level.burrow.add_pet(&"ladybird", 7.0)
	_level.burrow.add_pantry()
	_level.home_slice.tlog.unlock(&"foods", &"grub")
	_level.home_slice.shop.kept.append(&"bottle_cap")
	var cells := _level.burrow.trophy_cells.duplicate()
	Game.quit()   # quit_exits is off: everything but the exit
	_free_level()
	Save.use_slot("")
	_open(1, false)
	var w2 := _p1()
	var b := _level.burrow
	assert_array(b.trophies).contains_exactly([&"pebble"])
	assert_array(b.trophy_cells).is_equal(cells)
	assert_array(b.pet_ids()).contains_exactly([&"ladybird"])
	assert_float(b.pets[0].t).is_equal_approx(7.0, 0.01)
	assert_int(b.pantry.size()).is_equal(1)
	assert_bool(_level.home_slice.tlog.is_found(&"foods", &"grub")).is_true()
	assert_array(_level.home_slice.shop.kept).contains_exactly([&"bottle_cap"])
	var fam: TrophyFamily = load("res://data/trophies/stones.tres")
	assert_float(TrophyBonus.of(w2).get("wiggle_hop", 0.0)).is_equal_approx(fam.per_trophy["wiggle_hop"], 0.001)


## The jar copies the tin's save file whole (JarStore.snapshot), so the burrow rides along as long
## as it is in that file. (JarStore still reads the slotless file: see the report, Needs other lanes.)
func test_the_burrow_is_in_the_tin_file_the_jar_copies() -> void:
	_open(2)
	var w := _p1()
	_home_here(w)
	_bring(w, &"crystal")
	_level.burrow.add_pet(&"ladybird")
	_level.save_now()
	var path := ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(2)))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_array(data.burrow.trophies).contains_exactly(["crystal"])
	assert_int((data.burrow.pets as Array).size()).is_equal(1)
	assert_bool(data.has(HomeSlice.SAVE_KEY)).is_true()
