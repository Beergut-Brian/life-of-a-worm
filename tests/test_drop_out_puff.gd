## Kid-check N9 (C-21 drop-out): a worm whose pad unplugs leaves with a sound and a picture.
## Players.player_left makes its DropOutPuff (a worm.tscn child) open a ring in the player's
## colour where the head was and play `warp`, whichever runs first: the level taking the worm out
## (scenes/main.gd -> PlanetLevel.remove_worm) or the puff. The other worm shows nothing. Runs in
## its own Save profile; no pile, the worms stand still.
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")

var _level: PlanetLevel


func before() -> void:
	SuiteSandbox.enter("drop_out_puff")


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	SuiteSandbox.leave()


func before_test() -> void:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	BaitTins.open(0)
	Save.wipe()
	_level = PLANET.instantiate()
	add_child(_level)


func after_test() -> void:
	if is_instance_valid(_level):
		remove_child(_level)
		_level.free()
	_level = null
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _worm(p: int) -> Worm:
	var w := _level.spawn_worm(p)
	w.autopilot = func(_w: Worm) -> Dictionary: return { "move": Vector2.ZERO }
	return w


func _puffs() -> Array[Node]:
	return get_tree().get_nodes_in_group(&"drop_out_puff").filter(
		func(n: Node) -> bool: return not n.is_queued_for_deletion())


func _warps() -> int:
	return int(Audio.played.get("warp", 0))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func test_an_unplugged_worm_leaves_a_ring_in_its_colour_where_its_head_was() -> void:
	var p1 := _worm(Players.P1)
	var p2 := _worm(Players.P2)
	await _frames(2)
	var at := _level.actors.to_local(p2.head_position())
	var hook: DropOutPuff = p2.get_node("DropOutPuff")
	Audio.played.clear()
	Players.player_left.emit(Players.P2)   # the puff first, then the level (main.gd's order varies)
	_level.remove_worm(Players.P2)
	assert_int(hook.count).is_equal(1)
	assert_int((p1.get_node("DropOutPuff") as DropOutPuff).count).is_equal(0)
	assert_int(_warps()).is_equal(1)
	var puffs := _puffs()
	assert_int(puffs.size()).is_equal(1)
	assert_object(puffs[0].get_parent()).is_same(_level.actors)
	assert_vector(puffs[0].position).is_equal_approx(at, Vector2(0.5, 0.5))
	assert_that(puffs[0].tint).is_equal(Players.COLOR[Players.P2])
	assert_object(Worm.of(Players.P2)).is_null()


func test_the_puff_still_shows_when_the_level_took_the_worm_out_first() -> void:
	_worm(Players.P1)
	await _frames(2)
	var at := _level.actors.to_local(Worm.of(Players.P1).head_position())
	Audio.played.clear()
	_level.remove_worm(Players.P1)   # out of the tree, not yet freed
	Players.player_left.emit(Players.P1)
	var puffs := _puffs()
	assert_int(puffs.size()).is_equal(1)
	assert_vector(puffs[0].position).is_equal_approx(at, Vector2(0.5, 0.5))
	assert_that(puffs[0].tint).is_equal(Players.COLOR[Players.P1])
	assert_int(_warps()).is_equal(1)


func test_the_puff_opens_then_goes() -> void:
	_worm(Players.P1)
	await _frames(1)
	Players.player_left.emit(Players.P1)
	var puff: Node2D = _puffs()[0]
	puff.set_process(false)
	puff.step(DropOutPuff.SECS * 0.5)
	assert_bool(puff.is_queued_for_deletion()).is_false()
	puff.step(DropOutPuff.SECS * 0.6)
	assert_bool(puff.is_queued_for_deletion()).is_true()
