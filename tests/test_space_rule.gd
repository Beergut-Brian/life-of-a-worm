## Space: bigger eats smaller, equal ignores, bigger bumps; one staged contact through real physics.
extends GdUnitTestSuite

const SCENE := "res://scenes/levels/space.tscn"


func before() -> void:
	SuiteSandbox.enter("space")


func after() -> void:
	SuiteSandbox.leave()


func test_stage_rule() -> void:
	assert_int(StageRule.relation(7, 5)).is_equal(StageRule.FOOD)
	assert_int(StageRule.relation(7, 7)).is_equal(StageRule.IGNORE)
	assert_int(StageRule.relation(7, 9)).is_equal(StageRule.THREAT)
	var n := Node.new()
	assert_int(StageRule.stage_of(n)).is_equal(-1)
	n.free()


func _space() -> SpaceLevel:
	var s: SpaceLevel = load(SCENE).instantiate()
	add_child(s)
	s.set_process(false)   # no stick, no demo autopilot
	return auto_free(s)


func test_resolve_contact_eats_smaller_and_bumps_bigger() -> void:
	var s := _space()
	var ate: Array = []
	s.ate.connect(func(p, what, g): ate.append(what))
	var small: SpacePlanet = s.get_node("Planets/Moon")
	var big: SpacePlanet = s.get_node("Planets/Clockwork")
	var segs := s.worm.segments
	assert_int(s.resolve_contact(s.worm, small)).is_equal(StageRule.FOOD)
	assert_bool(small.eaten).is_true()
	assert_array(ate).is_equal([&"planet_candy"])
	assert_int(s.worm.segments).is_equal(segs + 1)
	assert_int(s.resolve_contact(s.worm, small)).is_equal(StageRule.IGNORE)   # only once
	assert_int(s.resolve_contact(s.worm, big)).is_equal(StageRule.THREAT)
	assert_bool(big.eaten).is_false()
	assert_float(s.worm.velocity.length()).is_greater(100.0)


func test_contact_through_physics_eats_the_small_planet() -> void:
	var s := _space()
	var small: SpacePlanet = s.get_node("Planets/Moon")
	var big: SpacePlanet = s.get_node("Planets/Junk")
	# staged: everything else far away, the small planet just touching the mouth
	for p in s.planets():
		if p != small:
			p.position = Vector2(5000, 5000) + p.position
	small.linear_velocity = Vector2.ZERO
	small.position = s.worm.position + Vector2(90, 0)
	var ate: Array = []
	s.ate.connect(func(p, what, g): ate.append(what))
	for i in 6:
		await get_tree().physics_frame
	assert_int(s.eaten).is_equal(1)
	assert_array(ate).is_equal([&"planet_candy"])
	assert_bool(big.eaten).is_false()
	for i in 30:
		await get_tree().physics_frame
	assert_bool(is_instance_valid(small)).is_false()


func test_gravity_is_off() -> void:
	var s := _space()
	for p in s.planets():
		assert_float(p.gravity_scale).is_equal(0.0)
