## L-03 / P-16: one apex per ring the worm opens, so play no longer stops at stage 3. Below the dirt
## beetle (2) and the topsoil stag beetle (3): the digger cricket deep in the dirt (opens 4), the pill
## bug in the deep rock (opens 5) and the ember newt in the core (opens 6). Each is a threat to a
## smaller worm, food once the body is long enough, tunnels only its own rings, and is gone for good
## once eaten (saved). ApexCall gives the wait a cause on screen: long enough but the apex not eaten,
## a picture of that apex points the way, with one `beetle_blink`. Own Save profile (SuiteSandbox).
class_name TestDeepApexes
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")
const HOMES := { 3: "dirt", 4: "deep_rock", 5: "core" }

var _level: PlanetLevel


func before() -> void:
	SuiteSandbox.enter("deep_apexes")


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


func _apex(ring_stage: int) -> ApexBeetle:
	for a in _level.apexes:
		if a.ring_stage == ring_stage:
			return a
	return null


func test_every_ring_the_worm_opens_has_an_apex_in_order() -> void:
	_open()
	assert_int(_level.apexes.size()).is_equal(5)
	for i in _level.apexes.size():
		var a := _level.apexes[i]
		assert_int(a.ring_stage).is_equal(i + 1)
		assert_int(a.size_stage).is_equal(i + 2)
	# Every stage the disk gates with an apex now has one (stages 2 to 6; 7 is space).
	var rules := WormRules.default_rules()
	for s in range(2, 7):
		if rules.needs_apex(s):
			assert_object(_apex(s - 1)).is_not_null()


func test_each_deep_apex_lives_in_its_own_ring_and_looks_its_own() -> void:
	_open()
	var looks := {}
	for rs in HOMES:
		var a := _apex(rs)
		var ring := _level.world.ring_of(_level.world.shape.cell_at(a.home))
		assert_str(String(ring.id)).is_equal(HOMES[rs])
		looks[a.look] = true
		# Bigger than the worm it threatens, so "bigger than me" reads at a glance (K-01).
		assert_float(a.radius).is_greater(_level.apexes[rs - 2].radius)
	assert_int(looks.size()).is_equal(3)
	assert_bool(ApexBeetle.shell_color(&"cricket", false) != ApexBeetle.shell_color(&"pillbug", false)).is_true()


func test_each_deep_apex_opens_its_stage_once_long_enough() -> void:
	for rs in HOMES:
		_free_level()
		_open()
		var w := _worm(Players.P1, rs)
		var a := _apex(rs)
		assert_int(a.relation_to(w)).is_equal(StageRule.THREAT)   # still too small
		a.bitten_by(w)
		assert_bool(a.is_gone()).is_false()
		_grow_to(w, w.rules.stage_segments[rs + 1])
		assert_int(w.model.stage).is_equal(rs)                   # long enough, apex not eaten: waits
		assert_int(a.relation_to(w)).is_equal(StageRule.FOOD)
		a.bitten_by(w)
		assert_int(w.model.stage).is_equal(rs + 1)
		assert_bool(a.is_gone()).is_true()
		assert_bool(Save.get_value(PlanetLevel.apex_key(rs), {}).get("gone", false)).is_true()


func test_each_deep_apex_tunnels_its_own_ring() -> void:
	_open()
	var world := _level.world
	for rs in HOMES:
		var a := _apex(rs)
		var cell := world.shape.cell_at(a.position + a.facing * a.radius * 0.6)
		assert_bool(world.is_edible_by(rs, cell)).is_true()
		var from := a.position
		for i in 20:
			a._move(a.facing * 2.0)
		assert_float(a.position.distance_to(from)).is_greater(30.0)
		assert_bool(world.is_solid(cell)).is_false()


func test_a_gone_deep_apex_stays_gone_after_a_reload() -> void:
	_open()
	var w := _worm(Players.P1, 3)
	_grow_to(w, w.rules.stage_segments[4])
	_apex(3).bitten_by(w)
	_level.save_now()
	_free_level()
	_open(false)
	assert_bool(_apex(3).is_gone()).is_true()
	assert_bool(_apex(4).is_gone()).is_false()
	var b := _worm(Players.P2, 3)
	assert_array(b.model.apex_eaten).contains([3])


func test_the_call_shows_only_while_a_long_enough_worm_waits_on_a_far_apex() -> void:
	_open()
	var call := _level.apex_call
	assert_object(call).is_not_null()
	var w := _worm(Players.P1, 3)
	call.step(0.1)
	assert_object(call.waiting_on(w)).is_null()                 # too short: nothing to wait on
	assert_int(Audio.played.get(ApexCall.CUE, 0)).is_equal(0)
	_grow_to(w, w.rules.stage_segments[4])
	assert_object(call.waiting_on(w)).is_same(_apex(3))
	call.step(0.1)
	call.step(0.1)
	assert_int(Audio.played.get(ApexCall.CUE, 0)).is_equal(1)   # once per worm per stage
	# Close enough to see the apex itself: the bubble steps aside.
	var a := _apex(3)
	a.global_position = w.cam_position() + Vector2(ApexBeetle.NOTICE * 0.5, 0)
	assert_object(call.waiting_on(w)).is_null()
	a.global_position = w.cam_position() + Vector2(ApexBeetle.NOTICE * 3.0, 0)
	a.bitten_by(w)
	assert_int(w.model.stage).is_equal(4)
	assert_object(call.waiting_on(w)).is_null()                 # eaten: the wait is over


func test_the_call_never_shows_without_the_gate() -> void:
	_open()
	var w := _worm(Players.P1, 3)
	_grow_to(w, w.rules.stage_segments[4])
	assert_object(_level.apex_call.waiting_on(w)).is_not_null()
	w.model.apex_gate = false   # the demo / a gate-free worm has nothing to wait on
	assert_object(_level.apex_call.waiting_on(w)).is_null()
