## L-09 "pops out of walls" (worm-gap-close-24): while a worm digs through the dirt ring far from
## his nook, the Mole now and then pops out of the tunnel wall beside it, startled, apologises,
## shows his swap offer with an arrow home, and sinks back. He never moves the worm, never eats the
## wall, is never food, and the tackle box meets him. Planet seed pinned; the visit is stepped by
## hand (physics processing off) except where the test needs a real digging worm.
class_name TestMoleVisit
extends GdUnitTestSuite

const SUITE := "mole_visit"
const PLANET := preload("res://scenes/levels/planet.tscn")
const SEED := 4242
## Far from the nook (26 tiles right of the start): 30 tiles left of the start, 2 tiles down.
const AWAY_AT := Vector2(-30, -2)

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
	BaitTins.open(0)
	Save.wipe()
	Save.set_value("seed", SEED)
	_level = PLANET.instantiate()
	add_child(_level)
	_level.home_slice.box.pause_tree = false


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


func _visit() -> MoleVisit:
	return _level.home_slice.shop.visit


## A worm in a short dug tunnel (just its head's width) far from the nook, heading right.
func _digger() -> Worm:
	var w := _level.spawn_worm(Players.P1)
	w.autopilot = func(_w: Worm) -> Dictionary: return _intent
	var at := _level.local_point(AWAY_AT.x, AWAY_AT.y)
	_hollow(at, 10.0)
	w.warp_to(at)
	return w


func _hollow(at: Vector2, r: float) -> void:
	var world := _level.world
	var c := world.shape.cell_at(at)
	var n := ceili(r / 16.0) + 1
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			var cell := c + Vector2i(x, y)
			if world.shape.center_of(cell).distance_to(at) <= r:
				world.dig(cell)


func test_the_spot_far_from_the_nook_is_dirt() -> void:
	var w := _digger()
	await _frames(2)
	assert_bool(_visit().in_dirt_away(w)).is_true()
	# Next to his nook he does not visit: there he pops out of his own wall.
	w.warp_to(_level.home_slice.shop.mole_position())
	await _frames(2)
	assert_bool(_visit().in_dirt_away(w)).is_false()


func test_a_digging_worm_meets_him_in_the_tunnel_wall() -> void:
	var w := _digger()
	var v := _visit()
	var seen := [0]
	v.visited.connect(func(_p: int) -> void: seen[0] += 1)
	await _frames(2)
	assert_int(v.state).is_equal(MoleVisit.State.NONE)
	assert_bool(v.visible).is_false()
	# Nearly time for a visit: a few frames of digging bank the rest.
	v.dig_t = MoleVisit.VISIT_EVERY - 0.05
	_intent = { "move": Vector2.RIGHT.rotated(w.heading) }
	await _frames(12)
	assert_int(seen[0]).is_equal(1)
	assert_int(v.visits).is_equal(1)
	assert_bool(v.is_out()).is_true()
	assert_bool(v.visible).is_true()
	assert_int(Audio.played.get("mole_pop", 0)).is_equal(1)
	assert_float(v.dig_t).is_less(1.0)
	# He is in a dirt wall, beside the worm, never in the food group.
	assert_bool(_level.world.is_solid(v._wall_cell)).is_true()
	assert_float(v.global_position.distance_to(w.head.global_position)).is_less(MoleVisit.REACH_PX + MoleVisit.IN_WALL_PX + 4.0)
	assert_bool(v.is_in_group(&"food")).is_false()
	assert_bool(v.is_in_group(&"jarling")).is_true()


func test_he_apologises_points_home_and_sinks_back() -> void:
	var w := _digger()
	await _frames(2)
	var v := _visit()
	v.set_physics_process(false)
	assert_bool(v.visit(w)).is_true()
	var cell := v._wall_cell
	var head := w.head.global_position
	assert_int(v.state).is_equal(MoleVisit.State.POP)
	v.step(MoleVisit.POP_T + 0.01)
	assert_int(v.state).is_equal(MoleVisit.State.SORRY)
	assert_int(Audio.played.get("mole_sorry", 0)).is_equal(1)
	v.step(MoleVisit.SORRY_T + 0.01)
	assert_int(v.state).is_equal(MoleVisit.State.POINT)
	v.step(MoleVisit.POINT_T + 0.01)
	assert_int(v.state).is_equal(MoleVisit.State.SINK)
	assert_int(Audio.played.get("mole_hide", 0)).is_equal(1)
	v.step(MoleVisit.SINK_T + 0.01)
	assert_int(v.state).is_equal(MoleVisit.State.NONE)
	assert_bool(v.visible).is_false()
	# He never moved the worm and left the wall as it was.
	assert_vector(w.head.global_position).is_equal(head)
	assert_bool(_level.world.is_solid(cell)).is_true()
	# One at a time: a second call while out does nothing.
	assert_bool(v.visit(w)).is_true()
	assert_bool(v.visit(w)).is_false()
	assert_int(v.visits).is_equal(2)


func test_he_ducks_back_in_when_his_wall_is_bitten() -> void:
	var w := _digger()
	await _frames(2)
	var v := _visit()
	v.set_physics_process(false)
	assert_bool(v.visit(w)).is_true()
	v.step(MoleVisit.POP_T + 0.01)
	_level.world.dig(v._wall_cell)
	v.step(0.01)
	assert_int(v.state).is_equal(MoleVisit.State.SINK)


func test_no_wall_in_reach_no_visit() -> void:
	var w := _digger()
	_hollow(w.head.global_position, MoleVisit.REACH_PX + 24.0)
	await _frames(2)
	var v := _visit()
	assert_dict(v.wall_spot(w)).is_empty()
	assert_bool(v.visit(w)).is_false()
	assert_int(v.state).is_equal(MoleVisit.State.NONE)


func test_the_tackle_box_meets_him_on_a_visit() -> void:
	var w := _digger()
	await _frames(2)
	var tlog := _level.home_slice.tlog
	assert_bool(tlog.is_found(&"creatures", &"mole")).is_false()
	var v := _visit()
	v.set_physics_process(false)
	assert_bool(v.visit(w)).is_true()
	await _frames(20)
	assert_bool(tlog.is_found(&"creatures", &"mole")).is_true()
