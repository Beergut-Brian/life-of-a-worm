## L-11 The gardener's boot stomps: the shadow and rumble warn first, then mid-hang the boot comes
## down (bonk, solid sole, dust). A smaller worm just under the sole is squashed the one eaten way
## (one segment, dizzy, sparkle); a worm deeper down, to the side, or bigger than the boot is not.
class_name TestBootStomp
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")
const BOOT := preload("res://scenes/creatures/boot.tscn")


func before() -> void:
	SuiteSandbox.enter("boot_stomp")


func after() -> void:
	for p in Audio._pool:
		p.stop()
	for i in 3:
		await get_tree().process_frame
	for p in Audio._pool:
		p.stream = null
	SuiteSandbox.leave()


func _worm(stage: int, p: int, at: Vector2) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = p
	w.model = WormGrowth.new()
	w.model.apex_gate = true
	w.model.start_at_stage(stage)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	w.position = at
	add_child(w)
	auto_free(w)
	return w


## A boot over the point (0, 0) of a flat surface, up = -y, its physics off (the test steps it).
func _boot() -> BootShadow:
	var b: BootShadow = BOOT.instantiate()
	add_child(b)
	auto_free(b)
	b.set_physics_process(false)
	b.pass_over(Vector2.ZERO, Vector2.UP)
	return b


## Steps the boot from now to `until` seconds of its life, counting stomps through the signal.
func _step_to(b: BootShadow, until: float, hits: Array) -> void:
	if not b.stomped.is_connected(hits.append):
		b.stomped.connect(hits.append)
	while b._life < until and not b._gone:
		b.step(1.0 / 60.0)


func test_it_warns_a_full_second_then_stomps_once() -> void:
	var b := _boot()
	var hits := []
	var before := int(Audio.played.get(BootShadow.STOMP_CUE, 0))
	assert_float(BootShadow.STOMP_AT).is_greater_equal(1.0)
	_step_to(b, BootShadow.STOMP_AT - 0.05, hits)
	assert_bool(b.did_stomp).is_false()
	assert_float(b.strength()).is_greater(0.5)   # the shadow is already big: the warning
	_step_to(b, BootShadow.STOMP_AT + 0.1, hits)
	assert_bool(b.did_stomp).is_true()
	assert_float(b.stomp_age()).is_greater_equal(0.0)   # the solid sole shows
	assert_int(int(Audio.played.get(BootShadow.STOMP_CUE, 0)) - before).is_equal(1)
	_step_to(b, BootShadow.STOMP_AT + BootShadow.STOMP_SHOW + 0.1, hits)
	assert_float(b.stomp_age()).is_less(0.0)
	assert_int(int(Audio.played.get(BootShadow.STOMP_CUE, 0)) - before).is_equal(1)   # once


func test_a_small_worm_just_under_the_sole_is_squashed_one_segment() -> void:
	var w := _worm(2, 0, Vector2(0, 0))
	await get_tree().physics_frame
	w.head.global_position = Vector2(10, 24)   # just under the surface, under the sole
	var segs := w.model.segments.size()
	var stage := w.model.stage
	var eaten := int(Audio.played.get("eaten", 0))
	var b := _boot()
	var hits := []
	_step_to(b, BootShadow.STOMP_AT + 0.05, hits)
	assert_array(hits).is_equal([0])
	assert_int(w.model.segments.size()).is_equal(segs - 1)
	assert_int(w.model.stage).is_equal(stage)        # never a stage
	assert_int(int(Audio.played.get("eaten", 0)) - eaten).is_equal(1)
	assert_bool(Gulp.is_safe(w)).is_true()           # sparkles: nothing eats it again at once


func test_deep_beside_or_bigger_worms_are_not_squashed() -> void:
	var deep := _worm(2, 0, Vector2.ZERO)
	var side := _worm(2, 1, Vector2.ZERO)
	var big := _worm(4, 0, Vector2.ZERO)
	await get_tree().physics_frame
	deep.head.global_position = Vector2(0, BootShadow.STOMP_DEPTH + 30.0)
	side.head.global_position = Vector2(200, 10)
	big.head.global_position = Vector2(-10, 20)
	var counts := [deep.model.segments.size(), side.model.segments.size(), big.model.segments.size()]
	var b := _boot()
	var hits := []
	_step_to(b, BootShadow.FADE * 2.0 + BootShadow.HOLD - 0.1, hits)
	assert_bool(b.did_stomp).is_true()
	assert_array(hits).is_empty()
	assert_int(deep.model.segments.size()).is_equal(counts[0])
	assert_int(side.model.segments.size()).is_equal(counts[1])
	assert_int(big.model.segments.size()).is_equal(counts[2])
