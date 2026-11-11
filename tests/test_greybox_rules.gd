## Grey-box rules on the worm and the apex beetle, no world: the stage-up needs segments AND the
## ring's apex; the apex flips from threat to food when the worm grows to its size and telegraphs
## a full second before it lunges; getting eaten costs one segment, never a stage, and pops the
## worm out of the beetle's far end. Objects are staged in fixed places; steps use a fixed delta.
class_name TestGreyboxRules
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")
const DT := 1.0 / 60.0


func _worm(at := Vector2.ZERO) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = Players.P1
	var m := WormGrowth.new()
	m.apex_gate = true
	w.model = m
	w.set_meta("start_pos", at)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	return auto_free(w)


func _grow_to(m: WormGrowth, segs: int) -> void:
	while m.segments.size() < segs:
		m.add_segment(&"")


func _beetle(at: Vector2) -> ApexBeetle:
	var b := ApexBeetle.new()
	b.position = at
	add_child(b)
	return auto_free(b)


func test_stage_up_needs_segments_and_the_apex() -> void:
	var m := WormGrowth.new()
	m.apex_gate = true
	_grow_to(m, m.rules.stage_segments[2])
	assert_int(m.size_stage()).is_equal(2)
	assert_int(m.stage).is_equal(1)            # long enough, apex not eaten: still stage 1
	assert_bool(m.eat_apex(1)).is_true()
	assert_int(m.stage).is_equal(2)


func test_apex_before_enough_segments_waits_for_them() -> void:
	var m := WormGrowth.new()
	m.apex_gate = true
	assert_bool(m.eat_apex(1)).is_false()
	assert_int(m.stage).is_equal(1)
	_grow_to(m, m.rules.stage_segments[2])
	assert_int(m.stage).is_equal(2)            # the segment that reaches 6 stages up
	_grow_to(m, m.rules.stage_segments[3])
	assert_int(m.stage).is_equal(2)            # stage 3 needs the next ring's apex


func test_without_the_gate_segments_alone_stage_up() -> void:
	var m := WormGrowth.new()                   # the trait arena's prototype rule
	_grow_to(m, m.rules.stage_segments[2])
	assert_int(m.stage).is_equal(2)


func test_apex_flips_from_threat_to_food() -> void:
	var w := _worm()
	var b := _beetle(Vector2(400, 0))
	assert_int(b.relation_to(w)).is_equal(StageRule.THREAT)
	_grow_to(w.model, w.rules.stage_segments[2])
	assert_int(w.model.stage).is_equal(1)
	assert_int(b.relation_to(w)).is_equal(StageRule.FOOD)


func test_apex_telegraphs_a_second_then_eats_one_segment_never_a_stage() -> void:
	var w := _worm()
	w.model.start_at_stage(2)
	w.model.apex_eaten.append(2)
	w.model.stage = 2
	# A stage-2 worm vs a size-3 apex: still a threat.
	var b := _beetle(Vector2(30, 0))
	b.size_stage = 3
	b.ring_stage = 2
	var monitor := monitor_signals(b, false)
	var segs := w.model.segments.size()
	var t := 0.0
	var windup_at := -1.0
	var lunge_at := -1.0
	while t < 4.0 and lunge_at < 0.0:
		b.step(DT)
		t += DT
		if b.mode == ApexBeetle.Mode.WINDUP and windup_at < 0.0:
			windup_at = t
		if b.mode in [ApexBeetle.Mode.LUNGE, ApexBeetle.Mode.FULL] and lunge_at < 0.0:
			lunge_at = t
	assert_float(windup_at).is_greater_equal(0.0)
	assert_float(lunge_at - windup_at).is_greater_equal(ApexBeetle.WINDUP - DT)
	for i in 30:
		b.step(DT)
	await assert_signal(monitor).is_emitted("ate_worm", [Players.P1])
	assert_int(w.model.segments.size()).is_equal(segs - 1)
	assert_int(w.model.stage).is_equal(2)
	# Popped out of the far end: on the other side of the beetle from where it bit.
	assert_float(w.cam_position().distance_to(b.position)).is_greater(b.radius)
	assert_float((w.cam_position() - b.position).dot(b.facing)).is_less(0.0)


func test_food_apex_is_eaten_on_contact_and_is_gone() -> void:
	var w := _worm()
	_grow_to(w.model, w.rules.stage_segments[2])
	var b := _beetle(w.cam_position() + Vector2(8, 0))
	var monitor := monitor_signals(b, false)
	for i in 3:
		b.step(DT)
	await assert_signal(monitor).is_emitted("eaten", [Players.P1])
	assert_bool(b.is_gone()).is_true()


func test_growth_round_trips_through_a_dict() -> void:
	var m := WormGrowth.new()
	m.apex_gate = true
	var grub: FoodData = load("res://data/foods/grub.tres")
	for i in 9:
		m.add_growth(grub.growth, grub.flavour)
	m.eat_apex(1)
	var d := m.to_dict()
	var n := WormGrowth.new()
	n.apex_gate = true
	n.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_array(n.segments).is_equal(m.segments)
	assert_int(n.stage).is_equal(m.stage)
	assert_array(n.earned).is_equal(m.earned)
	assert_array(n.active).is_equal(m.active)
	assert_array(n.apex_eaten).is_equal(m.apex_eaten)
	assert_float(n.growth).is_equal_approx(m.growth, 0.0001)


func test_camera_rotation_is_capped_and_zoom_is_whole_pixel() -> void:
	var cam := PolarCamera.new()
	var a := Node2D.new()
	a.position = Vector2(0, -1000)
	add_child(a)
	auto_free(a)
	cam.targets = [a]
	cam.fit = true
	add_child(cam)
	auto_free(cam)
	cam.snap()
	a.position = Vector2(1000, 0)   # the worm jumps a quarter turn round the planet
	var before := cam.rotation
	cam.step(0.1)
	assert_float(absf(angle_difference(before, cam.rotation))).is_less_equal(cam.max_turn_rate * 0.1 + 0.0001)
	for i in 40:
		cam.step(0.1)
		assert_bool(cam.zoom.x in PolarCamera.ZOOMS).is_true()
		assert_int(cam.zoom_index).is_less_equal(cam.max_fit_index)
