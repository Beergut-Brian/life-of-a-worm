## S-17: space remembers the worms (SpaceKeep, a child of space_stage.tscn). A worm that grew long
## in space is still long after the tin is reopened, curled the same way, the two worms the same
## distance apart and the drifting planet in the same place beside them. An old tin without the key
## opens exactly as before, and SpaceKeep never moves a worm once the stage is built.
extends GdUnitTestSuite

const SPACE := "res://scenes/levels/space_stage.tscn"


func before() -> void:
	SuiteSandbox.enter("space_keep")


func after() -> void:
	SuiteSandbox.leave()


func before_test() -> void:
	Save.wipe()
	Save.set_value("seed", 777)


func _stage(players: Array[int]) -> SpaceStage:
	var s: SpaceStage = load(SPACE).instantiate()
	for p in players:
		s.players.append(p)
	add_child(s)
	s.set_process(false)          # no stick
	s.drift.set_process(false)
	return s


func _drop(s: SpaceStage) -> void:
	remove_child(s)               # leaving the tree saves, like quitting out of space
	s.free()


func _body_len(w: SpaceWorm) -> float:
	var tr: PackedVector2Array = w._trail
	var n := 0.0
	for i in range(1, tr.size()):
		n += tr[i].distance_to(tr[i - 1])
	return n


func test_a_long_space_worm_comes_back_long_curled_and_beside_its_planet() -> void:
	var s := _stage([Players.P1, Players.P2])
	var a := s.worms[0]
	var b := s.worms[1]
	a.segments = 23
	b.segments = 14
	a.position += Vector2(-300, 120)
	# curl worm A: a trail from its head that bends round behind it
	var tr := PackedVector2Array()
	var at := a.global_position
	for i in 600:             # 2 px apart, like a real trail, turning a little each step
		tr.append(at)
		at += Vector2(-2.0, 0).rotated(i * 0.004)
	a._trail = tr
	b.position += Vector2(260, -80)
	var planet := s.drift.big
	assert_object(planet).is_not_null()
	planet.position = s.worms_centre() + Vector2(700, -250)
	planet.linear_velocity = Vector2(-11, 4)
	var gap := b.position - a.position
	var to_planet := planet.position - s.worms_centre()
	var bend := tr[300] - tr[0]
	_drop(s)
	assert_bool(Save.get_value(SpaceKeep.SAVE_KEY, {}).is_empty()).is_false()

	var s2 := _stage([Players.P1, Players.P2])
	var keep: SpaceKeep = s2.get_node("SpaceKeep")
	assert_bool(keep.restored).is_true()
	var a2 := s2.worms[0]
	var b2 := s2.worms[1]
	assert_int(a2.segments).is_equal(23)
	assert_int(b2.segments).is_equal(14)
	assert_vector(b2.position - a2.position).is_equal_approx(gap, Vector2(0.5, 0.5))
	assert_vector(s2.drift.big.position - s2.worms_centre()).is_equal_approx(to_planet, Vector2(0.5, 0.5))
	assert_vector(s2.drift.big.linear_velocity).is_equal_approx(Vector2(-11, 4), Vector2(0.01, 0.01))
	# the body bends the same way, and the trail is long enough for every segment
	var bend2: Vector2 = a2._trail[300] - a2._trail[0]
	assert_float(bend2.distance_to(bend)).is_less(14.0)
	assert_float(_body_len(a2)).is_greater_equal(23 * a2.seg_radius * 0.95)
	# put back round the stage's own start, so the arrival shot still opens where the planet was
	assert_float(s2.worms_centre().length()).is_less(60.0)
	_drop(s2)


func test_every_bite_saves_the_new_length() -> void:
	var s := _stage([Players.P1])
	var w := s.worms[0]
	var food: SpacePlanet = null
	for c in s.drift.get_children():
		if c is SpacePlanet and c.kind != &"planet" and c.kind != &"sun" and c.size_stage < w.size_stage:
			food = c
			break
	if food == null:
		food = SpacePlanet.new()
		food.kind = &"moon"
		food.size_stage = 4
		s.drift.add_child(food)
	var before := w.segments
	s.resolve_contact(w, food)
	assert_int(w.segments).is_equal(before + 1)
	var saved: Dictionary = Save.get_value(SpaceKeep.SAVE_KEY, {})
	assert_int(int(saved["worms"][str(w.player)]["seg"])).is_equal(before + 1)
	_drop(s)


func test_an_old_tin_without_the_key_opens_as_before() -> void:
	var s := _stage([Players.P1, Players.P2])
	var keep: SpaceKeep = s.get_node("SpaceKeep")
	assert_bool(keep.restored).is_false()
	assert_int(s.worms[0].segments).is_equal(10)
	assert_vector(s.worms[0].position).is_equal(Vector2(-60, 0))
	assert_vector(s.worms[1].position).is_equal(Vector2(60, 40))
	_drop(s)


func test_a_new_second_player_keeps_the_default_spot_and_length() -> void:
	var s := _stage([Players.P1])
	s.worms[0].segments = 19
	_drop(s)
	var s2 := _stage([Players.P1, Players.P2])
	assert_int(s2.worms[0].segments).is_equal(19)
	assert_int(s2.worms[1].segments).is_equal(10)
	_drop(s2)


func test_it_never_moves_a_worm_after_the_stage_is_built() -> void:
	var s := _stage([Players.P1, Players.P2])
	s.worms[0].segments = 17
	s.worms[0].position += Vector2(-200, 0)
	_drop(s)
	var s2 := _stage([Players.P1, Players.P2])
	for w in s2.worms:
		w.collision_layer = 0
		w.collision_mask = 0
	var at: Array[Vector2] = []
	for w in s2.worms:
		at.append(w.position)
	var keep: SpaceKeep = s2.get_node("SpaceKeep")
	for i in 20:
		keep._process(1.0)        # saves every SAVE_EVERY s
		await get_tree().physics_frame
	for i in s2.worms.size():
		assert_vector(s2.worms[i].position).is_equal_approx(at[i], Vector2(0.01, 0.01))
	_drop(s2)


func test_collisions_come_back_after_the_restore() -> void:
	var s := _stage([Players.P1])
	var layer := s.worms[0].collision_layer
	var mask := s.worms[0].collision_mask
	s.worms[0].segments = 12
	_drop(s)
	var s2 := _stage([Players.P1])
	assert_int(s2.worms[0].collision_layer).is_equal(0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(s2.worms[0].collision_layer).is_equal(layer)
	assert_int(s2.worms[0].collision_mask).is_equal(mask)
	_drop(s2)
