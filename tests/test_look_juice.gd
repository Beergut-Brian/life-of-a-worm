## Juice (A-14): chomp crumbs in the food's colour and bigger for a bigger bite, debris that falls
## toward the core, a pooled emitter count, shake that respects the setting, and a stage-up flash
## that is white for exactly two frames.
class_name TestLookJuice
extends GdUnitTestSuite

var _host: Node2D


func before_test() -> void:
	_host = Node2D.new()
	add_child(_host)
	Juice.host = _host
	Juice.core = Vector2.ZERO


func after_test() -> void:
	Juice.host = null
	_host.free()


func test_chomp_is_in_the_food_colour_and_scales_with_the_bite() -> void:
	var col := Color("a0703c")
	var small := Juice.chomp(Vector2(0, -300), col, 0.5)
	var small_amount := small.amount
	var small_speed := small.initial_velocity_max
	assert_object(small).is_not_null()
	assert_bool(small.emitting).is_true()
	assert_that(small.color).is_equal(col)
	var big := Juice.chomp(Vector2(0, -300), col, 3.0)
	assert_int(big.amount).is_greater(small_amount)
	assert_float(big.initial_velocity_max).is_greater(small_speed)


func test_debris_falls_toward_the_core() -> void:
	var p := Juice.debris(Vector2(400, 0))
	assert_vector(p.gravity.normalized()).is_equal_approx(Vector2(-1, 0), Vector2(0.01, 0.01))
	var q := Juice.debris(Vector2(0, -400))
	assert_vector(q.gravity.normalized()).is_equal_approx(Vector2(0, 1), Vector2(0.01, 0.01))


func test_emitters_are_pooled() -> void:
	for i in 40:
		Juice.chomp(Vector2(i, 0), Color.WHITE, 1.0)
	var n := _host.get_children().filter(func(c: Node) -> bool: return c is CPUParticles2D).size()
	assert_int(n).is_less_equal(Juice.POOL)


func test_shake_reaches_the_camera() -> void:
	var cam := PolarCamera.new()
	_host.add_child(cam)
	cam.make_current()
	Juice.shake(0.6)
	if SettingsPanel.screen_shake():
		assert_float(cam.shake).is_equal_approx(0.6, 0.001)
	else:
		assert_float(cam.shake).is_equal(0.0)
	Juice.shake(0.2)  # a smaller bite never cuts a bigger shake short
	if SettingsPanel.screen_shake():
		assert_float(cam.shake).is_greater_equal(0.59)


func test_stage_flash_is_white_for_two_frames() -> void:
	var before := Juice.flashes
	Juice.stage_flash()
	assert_int(Juice.flashes).is_equal(before + 1)
	var seen := 0
	for i in 6:
		await get_tree().process_frame
		if Juice.flash_visible():
			seen += 1
	assert_int(seen).is_equal(2)
