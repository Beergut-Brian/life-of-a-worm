## P-14 eaten beat: a gulped worm gets a camera move to the bite (EatenBeat, a child of worm.tscn).
## The camera centres between the worm and the creature that ate it, leans one step in, shakes a
## little and lets go after EatenBeat.LIFE; the worm is never moved by the beat; a shot that already
## owns the camera (the planet chomp) is left alone.
class_name TestEatenBeat
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")

## Far from the core, so "up" is the +y direction and the camera's frame is steady.
const AT := Vector2(0, 2000)

var _cam: PolarCamera


func before_test() -> void:
	_cam = auto_free(PolarCamera.new())
	_cam.fit = false
	add_child(_cam)
	_cam.zoom_index = 7   # 3x: about 160 world px from the centre to the top of the screen


func _worm(player: int, at: Vector2) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = player
	w.position = at
	w.autopilot = func(_w: Worm) -> Dictionary: return { "move": Vector2.ZERO }
	add_child(w)
	auto_free(w)
	w.get_node("EatenBeat").camera = _cam
	return w


func _eater(at: Vector2) -> Node2D:
	var c := Node2D.new()
	c.add_to_group(&"creatures")
	c.position = at
	add_child(c)
	return auto_free(c)


func _aim(targets: Array[Node2D]) -> void:
	_cam.targets = targets
	_cam.snap()
	await get_tree().process_frame


func test_getting_eaten_moves_the_camera_to_the_bite_with_the_eater_on_screen() -> void:
	var w := _worm(Players.P1, AT)
	await _aim([w])
	var head := w.head_position()
	# Radially outward, 200 px: inside REACH, but off the top of a 3x screen centred on the worm.
	var beetle := _eater(head + head.normalized() * 200.0)
	assert_bool(_cam.sees(beetle.global_position)).is_false()
	var beats: Array = []
	w.get_node("EatenBeat").beat.connect(func(p: int, c: StringName, e: Node2D) -> void: beats.append([p, c, e]))
	w.get_eaten(&"beetle")
	var popped := w.head_position()
	await await_millis(500)
	assert_array(beats).is_equal([[Players.P1, &"beetle", beetle]])
	assert_bool(_cam.centre_override is Vector2).is_true()
	assert_float((_cam.centre_override as Vector2).distance_to((head + beetle.global_position) * 0.5)).is_less(1.0)
	assert_bool(_cam.sees(beetle.global_position)).is_true()
	assert_bool(_cam.sees(w.head_position())).is_true()
	assert_int(_cam.lean_in).is_equal(1)
	# The camera moved; the worm did not.
	assert_float(w.head_position().distance_to(popped)).is_less(1.0)
	await await_millis(int(EatenBeat.LIFE * 1000.0))
	assert_that(_cam.centre_override).is_null()
	assert_int(_cam.lean_in).is_equal(0)
	assert_bool(_cam.has_meta(EatenBeat.OWNER)).is_false()


func test_the_beat_shakes_the_camera() -> void:
	var w := _worm(Players.P1, AT)
	await _aim([w])
	_eater(w.head_position() + Vector2(30, 0))
	_cam.shake = 0.0
	w.get_eaten(&"bird")
	assert_float(_cam.shake).is_greater_equal(EatenBeat.SHAKE)


func test_a_shot_that_owns_the_camera_is_left_alone() -> void:
	var w := _worm(Players.P1, AT)
	await _aim([w])
	_eater(w.head_position() + Vector2(30, 0))
	var shot := Vector2(5, 5)
	_cam.centre_override = shot
	w.get_eaten(&"beetle")
	await await_millis(300)
	assert_that(_cam.centre_override).is_equal(shot)
	assert_int(_cam.lean_in).is_equal(0)
	assert_array(w.get_node("EatenBeat").history).is_empty()


func test_two_bites_back_to_back_lean_one_step_and_let_go() -> void:
	var a := _worm(Players.P1, AT)
	var b := _worm(Players.P2, AT + Vector2(120, 0))
	await _aim([a, b])
	_eater(a.head_position() + Vector2(0, 40))
	_eater(b.head_position() + Vector2(0, 40))
	a.get_eaten(&"beetle")
	await await_millis(200)
	b.get_eaten(&"beetle")
	await await_millis(200)
	assert_int(_cam.lean_in).is_equal(1)
	assert_bool(_cam.get_meta(EatenBeat.OWNER) == b.get_node("EatenBeat")).is_true()
	await await_millis(int(EatenBeat.LIFE * 1000.0) + 200)
	assert_that(_cam.centre_override).is_null()
	assert_int(_cam.lean_in).is_equal(0)


func test_the_centre_keeps_a_far_partner_in_the_middle() -> void:
	var a := _worm(Players.P1, AT)
	var b := _worm(Players.P2, AT + Vector2(600, 0))
	await _aim([a, b])
	var bite := a.head_position() + Vector2(0, 40)
	var c := EatenBeat.centre_for(_cam, bite)
	# Between the bite and the partner, not on the bite alone.
	assert_float(c.x).is_between(bite.x + 200.0, b.head_position().x - 200.0)


func test_no_creature_near_still_centres_on_the_worm() -> void:
	var w := _worm(Players.P1, AT)
	await _aim([w])
	_eater(w.head_position() + Vector2(0, 900))   # far outside REACH: not the eater
	w.get_eaten(&"boot")
	await await_millis(100)
	var h: Dictionary = w.get_node("EatenBeat").history[0]
	assert_bool(h.eater).is_false()
	assert_float((_cam.centre_override as Vector2).distance_to(w.head_position())).is_less(2.0)


func test_every_level_worm_has_the_beat() -> void:
	var w: Worm = auto_free(WORM.instantiate())
	assert_object(w.get_node_or_null("EatenBeat")).is_instanceof(EatenBeat)
