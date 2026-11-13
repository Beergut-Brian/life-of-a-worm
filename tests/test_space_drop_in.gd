## Drop-in in space: a pad that joins after the chomp hatches its worm from an egg beside the first
## worm in space (not on the hidden planet), steers with its own stick, and a pad that leaves takes
## its worm with it, never the last one. Hatches count through SpaceDropIn.hatched, not by polling.
## Saves go to res://.scratch/space_drop_in_saves (Save.dir), never a real one.
extends GdUnitTestSuite

const SPACE := "res://scenes/levels/space_stage.tscn"
const DIR := "res://.scratch/space_drop_in_saves"

var _level: Node2D
var _stage: SpaceStage
var _hatched: Array[int] = []


func before() -> void:
	SuiteSandbox.enter("space_drop_in")
	DirAccess.make_dir_recursive_absolute(DIR)
	Save.dir = DIR
	Save.use_profile(SuiteSandbox.profile_for("space_drop_in"))


func after() -> void:
	Save.use_slot("")
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "/" + f))
	Save.dir = "user://saves"
	SuiteSandbox.leave()


func before_test() -> void:
	Game.demo = false
	Players.reset()
	Players.join_virtual(Players.P1)
	Save.use_slot("tin1")
	Save.wipe()
	Save.set_value("seed", 99)
	_hatched.clear()
	# Stands in for the hidden planet level the stage lives under.
	_level = Node2D.new()
	add_child(_level)
	_stage = load(SPACE).instantiate()
	_stage.players.append(Players.P1)
	_level.add_child(_stage)
	_stage.set_process(false)
	_stage.drift.set_process(false)
	(_stage.get_node("SpaceStory") as SpaceStory).auto = false
	(_stage.get_node("OldReelOffer") as OldReelOffer).auto = false
	_drop().hatched.connect(func(p: int) -> void: _hatched.append(p))


func after_test() -> void:
	if is_instance_valid(_level):
		_level.free()
	for s in get_tree().get_nodes_in_group(&"story"):
		s.free()
	Players.reset()
	Save.use_slot("")


func _drop() -> SpaceDropIn:
	return _stage.get_node("SpaceDropIn") as SpaceDropIn


func _crack(egg: WormEgg) -> void:
	egg._process(WormEgg.WOBBLE + 0.1)


func test_a_pad_joining_in_space_hatches_its_worm_beside_the_first() -> void:
	assert_int(_stage.worms.size()).is_equal(1)
	Players.join_virtual(Players.P2)                       # the real join signal
	await await_idle_frame()
	var egg: WormEgg = _drop().eggs.get(Players.P2)
	assert_object(egg).is_not_null()
	assert_bool(egg.get_parent() == _stage).is_true()     # in space, where the camera is
	assert_float(egg.position.distance_to(_stage.worms[0].position)).is_equal_approx(SpaceDropIn.BESIDE, 0.5)
	assert_array(_hatched).is_empty()                      # it wobbles first
	_crack(egg)
	assert_array(_hatched).is_equal([Players.P2])
	var w := _drop().worm_of(Players.P2)
	assert_object(w).is_not_null()
	assert_int(_stage.worms.size()).is_equal(2)
	assert_bool(_stage.players.has(Players.P2)).is_true()
	assert_bool(w.body_color() == _drop().worm_of(Players.P1).body_color()).is_false()  # its own colour


func test_the_new_worm_steers_with_its_own_stick() -> void:
	Players.join_virtual(Players.P2)
	await await_idle_frame()
	_crack(_drop().eggs[Players.P2])
	var w := _drop().worm_of(Players.P2)
	var right := Players.action(Players.P2, "move_right")
	Input.action_press(right)
	_stage._process(0.016)                                 # the stage reads every worm's stick
	Input.action_release(right)
	assert_float(w.steer.x).is_greater(0.5)
	assert_vector(_drop().worm_of(Players.P1).steer).is_equal(Vector2.ZERO)   # P1's stick is P1's


func test_the_hidden_planet_egg_for_the_joiner_is_cleared() -> void:
	var planet_egg := WormEgg.new()                         # what PlanetLevel.drop_in leaves
	planet_egg.player = Players.P2
	planet_egg.set_process(false)
	_level.add_child(planet_egg)
	var mine := WormEgg.new()
	mine.player = Players.P1
	mine.set_process(false)
	_level.add_child(mine)
	_drop().join(Players.P2)
	assert_bool(planet_egg.is_queued_for_deletion()).is_true()
	assert_bool(mine.is_queued_for_deletion()).is_false()


func test_it_hatches_once_and_never_twice() -> void:
	assert_object(_drop().join(Players.P1)).is_null()     # already in space
	var egg := _drop().join(Players.P2)
	assert_object(egg).is_not_null()
	assert_object(_drop().join(Players.P2)).is_null()     # its egg is already wobbling
	Players.join_virtual(Players.P2)
	_crack(egg)
	assert_object(_drop().join(Players.P2)).is_null()
	assert_array(_hatched).is_equal([Players.P2])
	assert_int(_stage.worms.size()).is_equal(2)


func test_a_pad_leaving_takes_its_worm_but_never_the_last() -> void:
	Players.join_virtual(Players.P2)
	await await_idle_frame()
	_crack(_drop().eggs[Players.P2])
	var w := _drop().worm_of(Players.P2)
	Players.player_left.emit(Players.P2)
	assert_bool(w.is_queued_for_deletion()).is_true()
	assert_int(_stage.worms.size()).is_equal(1)
	assert_bool(_stage.players.has(Players.P2)).is_false()
	Players.player_left.emit(Players.P1)                  # the last worm stays
	assert_int(_stage.worms.size()).is_equal(1)


func test_after_the_sun_the_joiner_glows_too() -> void:
	_stage.drift.sun_gone = true
	Players.join_virtual(Players.P2)
	var egg := _drop().join(Players.P2)
	_crack(egg)
	assert_float(_drop().worm_of(Players.P2).sun_glow).is_equal(1.0)
