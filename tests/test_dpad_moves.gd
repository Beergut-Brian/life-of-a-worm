## Feel rule "no stick-only requirement": on a pad the d-pad moves the worm and drives every menu
## that reads the move actions (dock, trait wall, tackle box), not only the stick. Players adds the
## d-pad buttons to move_* at boot (project.godot binds the stick and the keys only).
extends GdUnitTestSuite

const DIRS := ["move_left", "move_right", "move_up", "move_down"]


func before() -> void:
	SuiteSandbox.enter("dpad_moves")


func after() -> void:
	Players.reset()
	SuiteSandbox.leave()


func _dpad_events(name: String) -> Array:
	return InputMap.action_get_events(name).filter(func(ev: InputEvent) -> bool:
		return ev is InputEventJoypadButton and ev.button_index in Players.DPAD.values())


func test_every_move_action_has_its_dpad_button() -> void:
	for p in [Players.P1, Players.P2]:
		for a in DIRS:
			var list := _dpad_events(Players.action(p, a))
			assert_int(list.size()).is_equal(1)
			assert_int(list[0].button_index).is_equal(Players.DPAD[a])


func test_a_dpad_press_is_the_move_action() -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_DPAD_LEFT
	ev.device = 0
	ev.pressed = true
	assert_bool(InputMap.event_is_action(ev, Players.action(Players.P1, "move_left"))).is_true()
	assert_bool(InputMap.event_is_action(ev, Players.action(Players.P1, "move_right"))).is_false()


func test_adding_again_never_doubles() -> void:
	Players.add_dpad()
	Players.add_dpad()
	assert_int(_dpad_events(Players.action(Players.P1, "move_up")).size()).is_equal(1)


func test_an_assigned_pad_owns_its_dpad_like_its_stick() -> void:
	Players._assign(Players.P1, 3)
	var ev: InputEventJoypadButton = _dpad_events(Players.action(Players.P1, "move_down"))[0]
	assert_int(ev.device).is_equal(3)
	Players.reset()
	ev = _dpad_events(Players.action(Players.P1, "move_down"))[0]
	assert_int(ev.device).is_equal(-1)


func test_solo_keeps_the_dpad() -> void:
	Players.set_solo(true)
	assert_int(_dpad_events(Players.action(Players.P1, "move_left")).size()).is_greater_equal(1)
	Players.set_solo(false)
	Players.reset()
	assert_int(_dpad_events(Players.action(Players.P1, "move_left")).size()).is_equal(1)
