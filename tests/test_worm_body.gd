## The worm node: shared growth, getting eaten, carry vs swallow, Worm.stats().
class_name TestWormBody
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")
const FOOD := preload("res://scripts/arena/arena_food.gd")

var _carry := false


func _worm(player: int, at := Vector2.ZERO) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = player
	w.position = at
	w.autopilot = func(_w: Worm) -> Dictionary: return { "carry": _carry }
	add_child(w)
	return auto_free(w)


func _food(path: String, at: Vector2) -> Node2D:
	var f: Node2D = FOOD.new()
	f.data = load(path)
	f.position = at
	add_child(f)
	return auto_free(f)


func before_test() -> void:
	_carry = false


func test_bite_grows_eater_fully_and_partner_by_a_quarter() -> void:
	var a := _worm(Players.P1)
	var b := _worm(Players.P2, Vector2(200, 0))
	var grub: FoodData = load("res://data/foods/grub.tres")
	a.feed(grub)
	assert_float(a.model.growth).is_equal_approx(grub.growth, 0.0001)
	assert_float(b.model.growth).is_equal_approx(grub.growth * 0.25, 0.0001)
	assert_float(a.rules.partner_share).is_equal(0.25)
	# The share is plain: it never paints the partner's diet.
	for i in 8:
		a.feed(grub)
	assert_int(b.model.flavour_count(&"bug")).is_equal(0)
	assert_int(a.model.flavour_count(&"bug")).is_greater(0)


func test_solo_worm_eats_alone() -> void:
	var a := _worm(Players.P1)
	var start := a.model.segments.size()
	var grub: FoodData = load("res://data/foods/grub.tres")
	for i in 4:
		a.feed(grub)
	assert_int(a.model.segments.size()).is_equal(start + int(4 * grub.growth / a.rules.growth_per_segment))
	assert_int(a.get_node("Body").get_child_count()).is_equal(a.model.segments.size())


func test_eaten_by_bigger_costs_one_segment_never_a_stage() -> void:
	var a := _worm(Players.P1)
	a.model.start_at_stage(3)
	var stage := a.model.stage
	var n := a.model.segments.size()
	var who: Array = []
	a.eaten_by.connect(func(_p: int, c: StringName) -> void: who.append(c))
	a.get_eaten(&"beetle")
	assert_int(a.model.segments.size()).is_equal(n - 1)
	assert_int(a.model.stage).is_equal(stage)
	assert_array(who).contains_exactly([&"beetle"])


func test_hold_x_carries_instead_of_swallowing_and_release_drops() -> void:
	var a := _worm(Players.P1)
	_carry = true
	var f := _food("res://data/foods/bottle_cap.tres", Vector2(9, 0))
	var log: Array = []
	a.carried.connect(func(_p: int, w: StringName) -> void: log.append("carried:%s" % w))
	a.dropped.connect(func(_p: int, w: StringName) -> void: log.append("dropped:%s" % w))
	a.ate.connect(func(_p: int, w: StringName, _g: float) -> void: log.append("ate:%s" % w))
	var growth := a.model.growth
	await await_millis(150)
	assert_array(log).contains_exactly(["carried:bottle_cap"])
	assert_object(a.carrying).is_same(f)
	assert_float(a.model.growth).is_equal(growth)
	_carry = false
	await await_millis(100)
	assert_array(log).contains_exactly(["carried:bottle_cap", "dropped:bottle_cap"])
	assert_object(a.carrying).is_null()
	assert_bool(f.is_inside_tree() and f.visible).is_true()


func test_without_x_food_is_swallowed() -> void:
	var a := _worm(Players.P1)
	var f := _food("res://data/foods/bottle_cap.tres", Vector2(9, 0))
	var ate: Array = []
	a.ate.connect(func(_p: int, w: StringName, _g: float) -> void: ate.append(w))
	await await_millis(150)
	assert_array(ate).contains_exactly([&"bottle_cap"])
	assert_bool(f.visible).is_false()


func test_bigger_food_needs_a_bigger_worm_or_a_harder_head() -> void:
	var a := _worm(Players.P1)
	a.model.start_at_stage(2)
	var boulder: FoodData = load("res://data/foods/boulder.tres")
	assert_bool(a.can_eat(boulder)).is_false()
	a.model.grant(&"stone_head")
	assert_bool(a.model.is_active(&"stone_head")).is_true()
	assert_bool(a.can_eat(boulder)).is_true()


func test_static_stats_reads_the_live_worm() -> void:
	var a := _worm(Players.P1)
	a.model.start_at_stage(2)
	a.model.grant(&"wriggle")
	assert_float(Worm.stats(Players.P1).value("speed")).is_greater(Worm.stats(Players.P2).value("speed"))
	assert_object(Worm.of(Players.P1)).is_same(a)
	assert_object(Worm.of(Players.P2)).is_null()
