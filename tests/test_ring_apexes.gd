## L-03 / P-16 / C-17: every ring in the slice has its apex. The topsoil has a stag beetle (size 3)
## that gates stage 3 the way the dirt beetle gates stage 2, so a stage-2 worm can stage up again.
## An apex is eaten once per tin and the bite counts for every worm: the partner, and a worm that
## joins later, never get stuck behind an apex that is already gone. Own Save profile (SuiteSandbox).
class_name TestRingApexes
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")

var _level: PlanetLevel


func before() -> void:
	SuiteSandbox.enter("ring_apexes")


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	SuiteSandbox.leave()


func before_test() -> void:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	Audio.played.clear()


func after_test() -> void:
	_free_level()
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _open(fresh := true) -> PlanetLevel:
	BaitTins.open(0)
	if fresh:
		Save.wipe()
		Save.set_value("seed", 4)
	_level = PLANET.instantiate()
	add_child(_level)
	return _level


func _free_level() -> void:
	if is_instance_valid(_level):
		Audio._pool.map(func(p: AudioStreamPlayer) -> void: p.stop())
		remove_child(_level)
		_level.free()
	_level = null


func _worm(player: int, stage: int) -> Worm:
	var w := _level.spawn_worm(player, null, stage)
	w.autopilot = func(_w: Worm) -> Dictionary: return { "move": Vector2.ZERO }
	return w


func _grow_to(w: Worm, segments: int) -> void:
	while w.model.segments.size() < segments:
		w.model.add_segment(&"")


func _topsoil() -> ApexBeetle:
	for a in _level.apexes:
		if a.ring_stage == 2:
			return a
	return null


func test_the_topsoil_has_its_own_apex_that_lives_in_the_topsoil() -> void:
	_open()
	assert_int(_level.apexes.size()).is_equal(5)   # + the deep ones (test_deep_apexes.gd)
	assert_object(_level.apexes[0]).is_same(_level.beetle)
	var t := _topsoil()
	assert_object(t).is_not_null()
	assert_int(t.size_stage).is_equal(3)
	assert_str(String(t.look)).is_equal("topsoil")
	var ring := _level.world.ring_of(_level.world.shape.cell_at(t.home))
	assert_str(String(ring.id)).is_equal("topsoil")


func test_the_topsoil_apex_opens_stage_3() -> void:
	_open()
	var w := _worm(Players.P1, 2)
	_grow_to(w, w.rules.stage_segments[3])
	assert_int(w.model.stage).is_equal(2)          # long enough, the topsoil apex not eaten
	var t := _topsoil()
	assert_int(t.relation_to(w)).is_equal(StageRule.FOOD)
	t.bitten_by(w)
	assert_int(w.model.stage).is_equal(3)
	assert_int(Audio.played.get("now_i_eat_you", 0)).is_equal(1)
	assert_int(Audio.played.get("stage_up", 0)).is_equal(1)
	assert_bool(t.is_gone()).is_true()
	assert_bool(Save.get_value("apex_2", {}).get("gone", false)).is_true()
	assert_bool(Save.get_value("apex", {}).get("gone", true)).is_false()   # the dirt one is untouched


func test_a_smaller_worm_finds_it_a_threat_never_food() -> void:
	_open()
	var w := _worm(Players.P1, 2)
	var t := _topsoil()
	assert_int(t.relation_to(w)).is_equal(StageRule.THREAT)
	t.bitten_by(w)                                   # a too-small mouth does nothing
	assert_bool(t.is_gone()).is_false()


func test_it_tunnels_through_topsoil_it_lives_in() -> void:
	_open()
	var t := _topsoil()
	var world := _level.world
	var cell := world.shape.cell_at(t.position + t.facing * t.radius * 0.6)
	assert_str(String(world.ring_of(cell).id)).is_equal("topsoil")
	assert_bool(world.is_edible_by(1, cell)).is_false()   # a stage-1 mouth (the dirt beetle) can't
	var from := t.position
	for i in 20:
		t._move(t.facing * 2.0)
	assert_float(t.position.distance_to(from)).is_greater(30.0)
	assert_bool(world.is_solid(cell)).is_false()


func test_an_apex_bite_counts_for_the_partner_too() -> void:
	_open()
	var a := _worm(Players.P1, 1)
	var b := _worm(Players.P2, 1)
	_grow_to(a, a.rules.stage_segments[2])
	_grow_to(b, b.rules.stage_segments[2])
	assert_int(b.model.stage).is_equal(1)
	_level.beetle.bitten_by(a)
	assert_int(a.model.stage).is_equal(2)
	assert_int(b.model.stage).is_equal(2)            # the beetle is gone for both, so both go up
	assert_int(Audio.played.get("now_i_eat_you", 0)).is_equal(1)   # one sting, for the biter


func test_a_worm_that_joins_later_is_not_stuck_behind_a_gone_apex() -> void:
	_open()
	var a := _worm(Players.P1, 1)
	_grow_to(a, a.rules.stage_segments[2])
	_level.beetle.bitten_by(a)
	_level.save_now()
	_free_level()
	_open(false)
	assert_bool(_level.beetle.is_gone()).is_true()
	assert_bool(_topsoil().is_gone()).is_false()
	var b := _worm(Players.P2, 1)
	assert_array(b.model.apex_eaten).contains([1])
	assert_array(b.model.apex_eaten).not_contains([2])
	_grow_to(b, b.rules.stage_segments[2])
	assert_int(b.model.stage).is_equal(2)


func test_an_old_tin_without_a_topsoil_apex_gets_a_fresh_one() -> void:
	_open()
	_level.save_now()
	Save._data.erase("apex_2")   # a tin saved before the topsoil apex existed
	Save.flush()
	_free_level()
	_open(false)
	assert_bool(_topsoil().is_gone()).is_false()
	assert_bool(_topsoil().visible).is_true()
