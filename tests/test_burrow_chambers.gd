## B-06 (worm-gap-close-20): one chamber layout per stage from 3 to 5 (data/burrow/growth.tres), and
## the buried house at stage 5. Everything the burrow carves stays inside the burrow's own room
## (`Burrow.in_room`, the area its collision walls ring) and under the surface: a home never opens
## the dirt to the sky, even when the worm beds down just under the grass. Own Save profile.
extends GdUnitTestSuite

const SUITE := "burrow_chambers"
const PLANET := preload("res://scenes/levels/planet.tscn")
const TILE := 16.0

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


func _open() -> PlanetLevel:
	BaitTins.open(0)
	Save.wipe()
	_level = PLANET.instantiate()
	add_child(_level)
	_level.home_slice.box.pause_tree = false
	return _level


## The open cells in a square round `at` (the burrow's whole reach at stage 7).
func _open_cells(at: Vector2) -> Dictionary:
	var out := {}
	var c := _level.world.shape.cell_at(at)
	var n := ceili(_level.burrow.growth.room_for(7)) + 2
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			var cell := c + Vector2i(x, y)
			if not _level.world.is_solid(cell):
				out[cell] = true
	return out


## Grows a home at `depth` (fraction of the radius) through stages 3, 4, 5 and checks each carve.
func _grow_home_at(depth: float) -> void:
	var b := _level.burrow
	var home := Vector2.from_angle(-PI / 2.0 + 0.3) * PlanetLevel.RADIUS * depth * TILE
	var surface := PlanetLevel.RADIUS * TILE
	b.grow_to(2)
	b.set_home(home)
	var last := -1.0
	for s in range(3, 6):
		var before := _open_cells(home)
		assert_bool(b.grow_to(s)).is_true()
		assert_float(b.chamber_tiles()).is_greater(last)   # each stage has its own, bigger chamber
		last = b.chamber_tiles()
		var dug := 0
		for cell in _open_cells(home):
			if before.has(cell):
				continue
			dug += 1
			var at: Vector2 = _level.world.shape.center_of(cell)
			assert_bool(b.in_room(at)).override_failure_message(
				"stage %d carved %s outside the burrow's room" % [s, at]).is_true()
			assert_float(at.length()).override_failure_message(
				"stage %d carved %s through the surface (%.0f px)" % [s, at, surface]).is_less(surface - TILE)
		assert_int(dug).override_failure_message("stage %d carved nothing" % s).is_greater(0)
	assert_bool(b.has_house()).is_true()
	for k in b.growth.house_spots():
		var p := b.house_spot(k)
		assert_bool(b.in_room(p)).is_true()
		assert_float(p.length()).is_less(surface - TILE)


func test_stages_3_to_5_carve_inside_the_room_at_the_start_depth() -> void:
	_open()
	_grow_home_at(PlanetLevel.START_DEPTH)


func test_a_home_just_under_the_grass_never_opens_to_the_sky() -> void:
	_open()
	_grow_home_at(0.96)
