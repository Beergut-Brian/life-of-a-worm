## D-07, Magnet's later half: a worm with Magnet sticks a piece of junk too big to eat onto its tail
## and drags it along; resting still lets it go. Grab and let-go are heard and seen. Without Magnet,
## or for junk it can already eat, nothing is dragged.
class_name TestPullDrag
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")


func before() -> void:
	SuiteSandbox.enter("pull_drag")


func after() -> void:
	for p in Audio._pool:
		p.stop()
	for i in 3:
		await get_tree().process_frame
	for p in Audio._pool:
		p.stream = null
	SuiteSandbox.leave()


func _worm(magnet := true) -> Worm:
	var w: Worm = WORM.instantiate()
	w.model = WormGrowth.new()
	w.model.apex_gate = true
	w.model.start_at_stage(2)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	auto_free(w)
	if magnet:
		w.model.grant(&"magnet")
	return w


func _junk(size_stage := 3, flavour := &"junk") -> ArenaFood:
	var f := ArenaFood.new()
	f.data = FoodData.new()
	f.data.id = &"fake_plank"
	f.data.flavour = flavour
	f.data.size_stage = size_stage
	f.data.radius = 6.0
	add_child(f)
	auto_free(f)
	return f


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Put the junk just behind the tail, then let the drag node look once.
func _behind_tail(w: Worm, f: ArenaFood) -> PullDrag:
	var drag := w.get_node("PullDrag") as PullDrag
	f.global_position = drag.tail_position() + Vector2(-8, 0)
	return drag


func test_magnet_grabs_big_junk_and_drags_it_behind_the_tail() -> void:
	var w := _worm()
	await _frames(2)
	var f := _junk()
	var drag := _behind_tail(w, f)
	var stings := int(Audio.played.get("trait_magnet", 0))
	await _frames(2)
	assert_object(drag.held).is_same(f)
	assert_int(drag.grabs).is_equal(1)
	assert_int(int(Audio.played.get("trait_magnet", 0))).is_greater(stings)
	assert_bool(f.is_available()).is_false()   # no bonks, no bites while on the beam
	var start := f.global_position
	w.autopilot = func(_w: Worm) -> Dictionary: return {"move": Vector2.RIGHT}
	await _frames(40)
	assert_float(f.global_position.x - start.x).is_greater(20.0)
	assert_float(f.global_position.distance_to(drag.tail_position())) \
			.is_less_equal(f.data.radius + PullDrag.SLACK + 0.5)


func test_resting_still_lets_go_with_a_sound() -> void:
	var w := _worm()
	await _frames(2)
	var f := _junk()
	var drag := _behind_tail(w, f)
	await _frames(2)
	assert_object(drag.held).is_same(f)
	var drops := int(Audio.played.get("drop", 0))
	await _frames(int(PullDrag.REST_LET_GO * Engine.physics_ticks_per_second) + 10)
	assert_object(drag.held).is_null()
	assert_int(drag.let_gos).is_equal(1)
	assert_int(int(Audio.played.get("drop", 0))).is_greater(drops)
	assert_vector(f.home).is_equal(f.position)   # it stays where it was dragged
	await _frames(60)
	assert_bool(f.is_available()).is_true()
	assert_object(drag.held).is_null()   # not grabbed again while the worm sits on it
	assert_int(drag.grabs).is_equal(1)
	w.autopilot = func(_w: Worm) -> Dictionary: return {"move": Vector2.RIGHT}
	await _frames(60)
	assert_int(drag.grabs).is_equal(1)
	_behind_tail(w, f)   # moved off, then back by it: it sticks again
	await _frames(3)
	assert_int(drag.grabs).is_equal(2)


func test_no_magnet_no_drag() -> void:
	var w := _worm(false)
	await _frames(2)
	var drag := _behind_tail(w, _junk())
	await _frames(4)
	assert_object(drag.held).is_null()


func test_only_big_junk_is_dragged() -> void:
	var w := _worm()
	await _frames(2)
	var small := _junk(1)   # edible: the magnet pulls it to the mouth instead (worm.gd)
	var drag := _behind_tail(w, small)
	await _frames(3)
	assert_object(drag.held).is_null()
	small.global_position = Vector2(5000, 5000)
	var rock := _junk(3, &"stone")   # a boulder is not magnetic
	_behind_tail(w, rock)
	await _frames(3)
	assert_object(drag.held).is_null()


func test_growing_big_enough_to_eat_it_lets_go() -> void:
	var w := _worm()
	await _frames(2)
	var f := _junk()
	var drag := _behind_tail(w, f)
	await _frames(2)
	assert_object(drag.held).is_same(f)
	w.model.apex_gate = false
	while w.model.stage < 3:
		w.model.add_segment(&"")
	await _frames(2)
	assert_object(drag.held).is_null()
	assert_bool(w.can_eat(f.data)).is_true()
