## Kid-check N2 (gap-close-36, Gary's pick): sleep can open the trait wall by itself, and the stick
## must never be taken away. A firm push up or down held BurrowWall.LEAVE_HOLD s shuts the wall with
## its cue and wakes the worm, which then moves; left / right still picks pictures, a tap does not
## shut it, and shutting it this way still equips a waiting trait into a free slot. Own Save profile.
class_name TestWallLetsGo
extends GdUnitTestSuite

const SUITE := "wall_lets_go"
const PLANET := preload("res://scenes/levels/planet.tscn")

var _level: PlanetLevel
var _intent := {}
var _stick := Vector2.ZERO


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
	_stick = Vector2.ZERO
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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await _frames(ceili(s * Engine.physics_ticks_per_second) + 1)


## A worm at stage 2 with Wriggle on and Stone head waiting (no free slot), asleep in a hollow: the
## wall opened by itself. The wall's stick reads _stick.
func _asleep_with_the_wall_open(free_slot := false) -> Worm:
	BaitTins.open(0)
	Save.wipe()
	_level = PLANET.instantiate()
	add_child(_level)
	_level.home_slice.box.pause_tree = false
	var w := _level.spawn_worm(Players.P1)
	w.autopilot = func(_w: Worm) -> Dictionary: return _intent
	w.model.start_at_stage(2)
	w.model.grant(&"wriggle")
	w.model.grant(&"stone_head")
	if free_slot:
		w.model.toggle(&"wriggle")
	var at := w.cam_position()
	var c := _level.world.shape.cell_at(at)
	for y in range(-4, 5):
		for x in range(-4, 5):
			var cell := c + Vector2i(x, y)
			if _level.world.shape.center_of(cell).distance_to(at) <= 40.0:
				_level.world.dig(cell)
	w.still_time = Burrow.SLEEP_STILL + 0.1
	await _frames(2)
	assert_bool(w.asleep).is_true()
	assert_bool(w.wall_open).is_true()
	assert_bool(w._wall is BurrowWall).is_true()
	(w._wall as BurrowWall).stick = func() -> Vector2: return _stick
	Audio.played.clear()
	return w


func test_pushing_the_stick_up_shuts_the_wall_and_the_worm_moves_off() -> void:
	var w := await _asleep_with_the_wall_open()
	_stick = Vector2(0.1, -1.0)
	await _seconds(BurrowWall.LEAVE_HOLD)
	assert_bool(w.wall_open).is_false()
	assert_bool(w.asleep).is_false()
	assert_int(Audio.played.get("wall_close", 0)).is_equal(1)
	# Awake and free: the same push now moves the worm, and Y is the tackle box again.
	var from := w.head_position()
	_stick = Vector2.ZERO
	_intent = { "move": Vector2(0.0, -1.0) }
	await _frames(10)
	assert_float(w.head_position().distance_to(from)).is_greater(4.0)
	assert_bool(w.in_burrow).is_false()
	assert_bool(w.wall_open).is_false()


func test_down_works_too() -> void:
	var w := await _asleep_with_the_wall_open()
	_stick = Vector2(0.0, 0.8)
	await _seconds(BurrowWall.LEAVE_HOLD)
	assert_bool(w.wall_open).is_false()


func test_a_tap_or_a_sideways_push_keeps_the_wall_open() -> void:
	var w := await _asleep_with_the_wall_open()
	var wall: BurrowWall = w._wall
	# A short tap up: not long enough.
	_stick = Vector2(0.0, -1.0)
	await _frames(maxi(1, floori(BurrowWall.LEAVE_HOLD * Engine.physics_ticks_per_second * 0.5)))
	_stick = Vector2.ZERO
	await _seconds(BurrowWall.LEAVE_HOLD)
	assert_bool(w.wall_open).is_true()
	assert_float(wall.push_t).is_equal(0.0)
	# Mostly sideways (the picking direction), even held: stays open.
	_stick = Vector2(1.0, 0.7)
	await _seconds(BurrowWall.LEAVE_HOLD * 2.0)
	assert_bool(w.wall_open).is_true()
	# A soft nudge up: stays open.
	_stick = Vector2(0.0, -0.4)
	await _seconds(BurrowWall.LEAVE_HOLD * 2.0)
	assert_bool(w.wall_open).is_true()
	assert_bool(w.asleep).is_true()


func test_leaving_by_stick_still_equips_the_waiting_trait_into_a_free_slot() -> void:
	var w := await _asleep_with_the_wall_open(true)
	assert_array(w.model.active).is_empty()
	_stick = Vector2(0.0, -1.0)
	await _seconds(BurrowWall.LEAVE_HOLD)
	assert_bool(w.wall_open).is_false()
	assert_array(w.model.active).contains_exactly([&"stone_head"])
