## W-15: the worm never uses gravity. It clings where it is, in a tunnel or in open air, and only the
## stick moves it (no forced movement). Loose things fall to the core; the worm does not.
class_name TestWormClings
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")


func before() -> void:
	SuiteSandbox.enter("worm_clings")


func after() -> void:
	SuiteSandbox.leave()


func _worm(at: Vector2) -> Worm:
	var w: Worm = WORM.instantiate()
	w.model = WormGrowth.new()
	w.model.start_at_stage(1)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	w.position = at
	add_child(w)
	auto_free(w)
	return w


func test_a_worm_left_alone_hangs_where_it_is_on_every_side_of_the_core() -> void:
	# Far out on four sides of the core, nothing under it: no stick, no drift toward the core.
	var worms: Array[Worm] = []
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		worms.append(_worm(Vector2.from_angle(a) * 900.0))
	await get_tree().physics_frame
	var start: Array[Vector2] = []
	for w in worms:
		start.append(w.head_position())
	for i in 40:
		await get_tree().physics_frame
	for i in worms.size():
		assert_float(worms[i].head_position().distance_to(start[i])) \
				.override_failure_message("worm %d slid without the stick" % i).is_less(0.01)


func test_only_the_stick_moves_the_worm() -> void:
	var w := _worm(Vector2(600, 0))
	await get_tree().physics_frame
	var start := w.head_position()
	w.autopilot = func(_w: Worm) -> Dictionary: return {"move": Vector2.RIGHT}
	for i in 20:
		await get_tree().physics_frame
	assert_float(w.head_position().distance_to(start)).is_greater(5.0)
