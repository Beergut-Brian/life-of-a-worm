## S-17 co-op camera fit in space (SpaceFit, a child of space_stage.tscn): two worms that drift
## apart stay on screen as the camera pulls back to MIN_ZOOM; past that it follows one worm and the
## far one gets an edge arrow in its colour; they share the screen again once close. It never moves
## a worm, and one worm alone keeps the stage's own zoom.
extends GdUnitTestSuite

const SPACE := "res://scenes/levels/space_stage.tscn"
const DT := 1.0 / 60.0


func before() -> void:
	SuiteSandbox.enter("space_fit")


func after() -> void:
	SuiteSandbox.leave()


func before_test() -> void:
	Save.wipe()
	Save.set_value("seed", 4242)


func _stage(players: Array[int]) -> SpaceStage:
	var s: SpaceStage = load(SPACE).instantiate()
	for p in players:
		s.players.append(p)
	add_child(s)
	s.set_process(false)          # no stick: the test runs the frame
	s.drift.set_process(false)
	s.get_node("SpaceFit").set_process(false)
	s.get_node("StarAward").set_process(false)
	s._t = 10.0
	s.ease_k = 1.0                # past the arrival shot
	for c in s.drift.get_children():
		if c is SpacePlanet:      # far away: nothing bumps a worm while the test places them
			c.position += Vector2(50000, 50000)
			c.linear_velocity = Vector2.ZERO
	for w in s.worms:
		w.collision_layer = 0
		w.collision_mask = 0
	return auto_free(s)


## One frame in the stage's order: the stage places its camera, then SpaceFit widens it.
func _frames(s: SpaceStage, n: int) -> void:
	var fit: SpaceFit = s.get_node("SpaceFit")
	for i in n:
		s.step_camera(DT)
		fit.step(DT)


func _place(s: SpaceStage, a: Vector2, b: Vector2) -> void:
	s.worms[0].position = a
	s.worms[1].position = b


func test_it_sits_after_the_stage_and_before_the_star_lean() -> void:
	var s := _stage([Players.P1, Players.P2])
	var fit := s.get_node("SpaceFit") as SpaceFit
	assert_object(fit).is_not_null()
	assert_int(fit.process_priority).is_greater(s.process_priority)
	assert_int(fit.process_priority).is_less((s.get_node("StarAward") as Node).process_priority)


func test_close_worms_keep_the_stage_zoom() -> void:
	var s := _stage([Players.P1, Players.P2])
	_place(s, Vector2(-100, 0), Vector2(100, 0))
	_frames(s, 120)
	assert_float(s.camera.zoom.x).is_equal_approx(SpaceStage.SPACE_ZOOM, 0.001)
	assert_array((s.get_node("SpaceFit") as SpaceFit).off_screen()).is_empty()


func test_one_worm_alone_keeps_the_stage_zoom() -> void:
	var s := _stage([Players.P1])
	s.worms[0].position = Vector2(4000, 0)
	_frames(s, 120)
	assert_float(s.camera.zoom.x).is_equal_approx(SpaceStage.SPACE_ZOOM, 0.001)


func test_worms_drifting_apart_both_stay_on_screen() -> void:
	var s := _stage([Players.P1, Players.P2])
	var fit := s.get_node("SpaceFit") as SpaceFit
	# without the fit, the stage's fixed zoom loses both off the sides
	_place(s, Vector2(-1800, 300), Vector2(1800, -300))
	s.step_camera(DT)
	var half := fit.view_size() * 0.5 / s.camera.zoom.x
	assert_float(1800.0).is_greater(half.x)
	_frames(s, 180)
	assert_bool(fit.split).is_false()
	assert_float(s.camera.zoom.x).is_less(SpaceStage.SPACE_ZOOM)
	assert_float(s.camera.zoom.x).is_greater_equal(SpaceFit.MIN_ZOOM - 0.001)
	assert_array(fit.off_screen()).is_empty()
	# and it eases back in when they come together
	_place(s, Vector2(-80, 0), Vector2(80, 0))
	_frames(s, 240)
	assert_float(s.camera.zoom.x).is_equal_approx(SpaceStage.SPACE_ZOOM, 0.01)


func test_too_far_apart_it_follows_the_bigger_worm_and_arrows_the_other() -> void:
	var s := _stage([Players.P1, Players.P2])
	var fit := s.get_node("SpaceFit") as SpaceFit
	s.worms[1].size_stage = 8         # P2 is bigger: the one the camera keeps
	var a := Vector2(-4000, 0)
	var b := Vector2(4000, 600)
	_place(s, a, b)
	_frames(s, 240)
	assert_bool(fit.split).is_true()
	assert_int(fit.anchor).is_equal(Players.P2)
	assert_float(s.camera.zoom.x).is_equal_approx(SpaceFit.MIN_ZOOM, 0.01)
	assert_float(s.camera.position.distance_to(b)).is_less(20.0)
	assert_array(fit.off_screen()).is_equal([s.worms[0]])
	# nobody was moved
	assert_vector(s.worms[0].position).is_equal(a)
	assert_vector(s.worms[1].position).is_equal(b)
	# close again (with room to spare): both framed, no arrow
	_place(s, Vector2(-500, 0), Vector2(500, 0))
	_frames(s, 240)
	assert_bool(fit.split).is_false()
	assert_int(fit.anchor).is_equal(-1)
	assert_array(fit.off_screen()).is_empty()


func test_the_anchor_is_the_solo_pad_else_the_bigger_else_the_current() -> void:
	var s := _stage([Players.P1, Players.P2])
	var ws: Array = s.worms.duplicate()
	assert_int(SpaceFit.pick_anchor(ws, Players.P2, -1)).is_equal(Players.P2)       # solo pad
	assert_int(SpaceFit.pick_anchor(ws, -1, -1)).is_equal(Players.P1)               # tie: P1 first
	assert_int(SpaceFit.pick_anchor(ws, -1, Players.P2)).is_equal(Players.P2)       # tie keeps current
	s.worms[0].size_stage = 9
	assert_int(SpaceFit.pick_anchor(ws, -1, Players.P2)).is_equal(Players.P1)       # bigger wins


func test_space_never_runs_out_however_far_or_wide_the_camera_goes() -> void:
	var s := _stage([Players.P1, Players.P2])
	s.worms[1].size_stage = 8
	_place(s, Vector2(-9000, 4000), Vector2(9000, -4000))
	_frames(s, 240)
	assert_float(s.camera.zoom.x).is_equal_approx(SpaceFit.MIN_ZOOM, 0.01)
	var half := (s.get_node("SpaceFit") as SpaceFit).view_size() * 0.5 / s.camera.zoom.x
	var seen := Rect2(s.camera.position - half, half * 2.0)
	var fields := 0
	for c in s.get_children():
		if c is Starfield:
			fields += 1
			c._process(DT)
			var r: Rect2 = c.view_rect()
			r.position += c.global_position
			assert_bool(r.encloses(seen)).override_failure_message("the navy fill ends inside the view").is_true()
	assert_int(fields).is_greater(0)
