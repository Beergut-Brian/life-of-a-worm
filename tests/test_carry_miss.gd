## Feel rule "every action beeps": X that grabs nothing snaps the jaws on air with a small low cue
## (CarryMiss, a child of worm.tscn). X that grabs something keeps the worm's own carry cue only.
## Also the trait wall with nothing earned yet: the stick and A bonk and shake instead of silence.
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")
const DT := 1.0 / 60.0

var _press := false
var _worms: Array[Worm] = []


func after_test() -> void:
	for w in _worms:
		if is_instance_valid(w):
			remove_child(w)
			w.free()
	_worms.clear()
	for p in Audio._pool:
		p.stop()


func _worm() -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = Players.P1
	w.autopilot = func(_w: Worm) -> Dictionary: return { "carry": _press }
	add_child(w)
	w.set_physics_process(false)
	for n in ["BurstNudge", "CarryMiss", "PartnerStars", "CastingsHook"]:
		w.get_node(n).set_physics_process(false)
	_worms.append(w)
	var m: CarryMiss = w.get_node("CarryMiss")
	m.pressed_now = func() -> bool: return _press
	return w


func _frame(w: Worm, press: bool) -> void:
	_press = press
	w._physics_process(DT)
	(w.get_node("CarryMiss") as CarryMiss).step(w, DT)


func _crumb(at: Vector2) -> ArenaFood:
	var f := ArenaFood.new()
	f.data = FoodData.new()
	f.data.id = &"fake_crumb"
	f.data.flavour = &"junk"
	f.data.size_stage = 1
	f.data.radius = 6.0
	f.position = at
	add_child(f)
	auto_free(f)
	return f


func test_x_with_nothing_in_reach_snaps_and_beeps() -> void:
	var w := _worm()
	var m: CarryMiss = w.get_node("CarryMiss")
	_frame(w, true)
	assert_object(w.carrying).is_null()
	assert_int(m.count).is_equal(1)
	assert_object(m.get_node("Voice").stream).is_not_null()
	assert_bool(m.get_node("Voice").playing).is_true()
	assert_float(m._show).is_greater(0.0)              # the jaws are on screen


func test_x_that_grabs_food_is_not_a_miss() -> void:
	var w := _worm()
	_crumb(w.mouth_position())
	var m: CarryMiss = w.get_node("CarryMiss")
	_frame(w, true)
	assert_object(w.carrying).is_not_null()
	assert_int(m.count).is_equal(0)


func test_mashing_x_is_capped() -> void:
	var w := _worm()
	var m: CarryMiss = w.get_node("CarryMiss")
	for i in 30:
		_frame(w, i % 2 == 0)
	assert_int(m.count).is_greater(1)
	assert_int(m.count).is_less_equal(int(30 * DT / CarryMiss.MIN_GAP) + 1)


func test_an_empty_trait_wall_bonks_and_shakes() -> void:
	var w := _worm()
	assert_bool(w.model.earned.is_empty()).is_true()
	var wall := TraitWall.new()
	wall.worm = w
	add_child(wall)
	auto_free(wall)
	wall.set_open(true)
	wall.handle(1, false, false)
	assert_float(wall._shake).is_greater(0.0)
	wall._shake = 0.0
	wall.handle(0, true, false)
	assert_float(wall._shake).is_greater(0.0)
