## Centipede (L-08, stage 3; feature/worm-creatures-2): a wavy chaser that gives up fast. Who it
## chases is CreatureSense alone (a worm smaller than stage 3); it gives up after `chase_time` or
## once the worm is past `give_up_distance`, turning away (GIVE_UP, huff cue); it winds up a full
## second before it can bite; a stage-4 worm is never chased and can eat it. Staged in fixed
## places with a fixed delta, inside its own save profile and settings file.
extends GdUnitTestSuite

const SUITE := "centipede"
const WORM := preload("res://scenes/players/worm.tscn")
const CENTIPEDE := preload("res://scenes/creatures/centipede.tscn")
const DATA := "res://data/creatures/centipede.tres"
const DT := 1.0 / 60.0


func before() -> void:
	SuiteSandbox.enter(SUITE)


func after() -> void:
	SuiteSandbox.leave()


func before_test() -> void:
	Audio.played.clear()
	Save.set_value(Outgrown.SAVE_KEY, {})


func _cd() -> CentipedeData:
	return load(DATA)


func _worm(at: Vector2, stage := 1) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = Players.P1
	var m := WormGrowth.new()
	if stage > 1:
		m.start_at_stage(stage)
	while m.segments.size() < 4:
		m.segments.append(&"")
	w.model = m
	w.set_meta("start_pos", at)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	w.set_physics_process(false)
	return auto_free(w)


func _centipede(at: Vector2) -> Centipede:
	var c: Centipede = CENTIPEDE.instantiate()
	c.position = at
	add_child(c)
	c.set_physics_process(false)
	return auto_free(c)


## Keep the worm's head `d` px to the right of the centipede (a kid holding the gap).
func _hold_gap(w: Worm, c: Creature, d: float) -> void:
	w.head.global_position = c.global_position + Vector2(d, 0)


func test_data_comes_first() -> void:
	var d: Resource = load(DATA)
	assert_bool(d is CentipedeData).is_true()
	assert_bool(d is CreatureData).is_true()
	var cd: CentipedeData = d
	assert_str(String(cd.id)).is_equal("centipede")
	assert_int(cd.size_stage).is_equal(3)
	assert_int(cd.behaviour).is_equal(CreatureData.Behaviour.WAVE)
	assert_float(cd.wave_amplitude).is_greater(0.0)
	assert_float(cd.chase_time).is_greater(0.0)
	assert_float(cd.chase_time).is_less_equal(4.0)   # gives up fast
	assert_float(cd.give_up_distance).is_greater(cd.notice)
	assert_float(cd.telegraph_time()).is_greater_equal(1.0)
	var node: Node = auto_free(CENTIPEDE.instantiate())
	assert_bool(node is Centipede).is_true()


func test_chase_triggers_only_for_a_smaller_worm() -> void:
	for stage in [1, 2, 3]:
		var w := _worm(Vector2(stage * 3000, 0), stage)
		var c := _centipede(w.head_position() + Vector2(120, 0))
		c.step(DT)
		if stage < 3:
			assert_int(c.mode).override_failure_message("stage %d should be chased" % stage).is_equal(Creature.Mode.STALK)
			assert_int(c.react_to(w)).is_equal(CreatureSense.React.AMBLE)
		else:
			assert_int(c.mode).override_failure_message("own size is ignored").is_not_equal(Creature.Mode.STALK)
			assert_int(c.react_to(w)).is_equal(CreatureSense.React.IGNORE)
	assert_int(Audio.played.get(_cd().bark, 0)).is_greater_equal(2)


func test_chase_is_a_wave() -> void:
	var w := _worm(Vector2(0, 0), 1)
	var c := _centipede(w.head_position() + Vector2(150, 0))
	var y_min := INF
	var y_max := -INF
	for i in 60:
		_hold_gap(w, c, 150.0)
		w.head.global_position.y = 0.0
		c.step(DT)
		y_min = minf(y_min, c.global_position.y)
		y_max = maxf(y_max, c.global_position.y)
	assert_int(c.mode).is_equal(Creature.Mode.STALK)
	# it swings side to side across its line to the worm, about wave_amplitude each way
	assert_float(y_max - y_min).is_greater(_cd().wave_amplitude)
	assert_float(y_max - y_min).is_less_equal(_cd().wave_amplitude * 2.0 + 2.0)


func test_gives_up_after_the_chase_time_and_turns_away() -> void:
	var cd := _cd()
	var w := _worm(Vector2.ZERO, 1)
	var c := _centipede(w.head_position() + Vector2(120, 0))
	var t := 0.0
	var gave_up_at := -1.0
	for i in int((cd.chase_time + 1.0) / DT):
		_hold_gap(w, c, -120.0)   # the worm stays just out of strike, inside its reach
		c.step(DT)
		t += DT
		if c.mode == Creature.Mode.GIVE_UP:
			gave_up_at = t
			break
	assert_float(gave_up_at).is_equal_approx(cd.chase_time + DT, 3.0 * DT)
	assert_int(c.give_ups).is_equal(1)
	assert_float(c.facing).is_equal(1.0)   # the worm is to its left: it turns its head right, away
	assert_int(Audio.played.get("bird_offended", 0)).is_equal(1)
	# then it sulks: no new chase for rest_time, even with the worm in sight
	for i in int((cd.rest_time - 0.2) / DT):
		_hold_gap(w, c, -120.0)
		c.step(DT)
		assert_int(c.mode).is_not_equal(Creature.Mode.STALK)
	for i in int(0.5 / DT):
		_hold_gap(w, c, -120.0)
		c.step(DT)
	assert_int(c.mode).is_equal(Creature.Mode.STALK)


func test_gives_up_at_once_when_the_worm_leaves_its_reach() -> void:
	var cd := _cd()
	var w := _worm(Vector2.ZERO, 1)
	var c := _centipede(w.head_position() + Vector2(120, 0))
	c.step(DT)
	assert_int(c.mode).is_equal(Creature.Mode.STALK)
	_hold_gap(w, c, cd.give_up_distance + 10.0)
	c.step(DT)
	assert_int(c.mode).is_equal(Creature.Mode.GIVE_UP)
	assert_float(c.facing).is_equal(-1.0)


func test_catches_a_small_worm_after_a_full_second_wind_up() -> void:
	var w := _worm(Vector2.ZERO, 1)
	var segs := w.model.segments.size()
	var c := _centipede(w.head_position() + Vector2(90, 0))
	var eaten := []
	w.eaten_by.connect(func(_p: int, who: StringName) -> void: eaten.append(who))
	var t := 0.0
	var windup_at := -1.0
	for i in 300:
		c.step(DT)
		t += DT
		if windup_at < 0.0 and c.mode == Creature.Mode.WINDUP:
			windup_at = t
		if not eaten.is_empty():
			break
	assert_array(eaten).contains([&"centipede"])
	assert_float(windup_at).is_greater_equal(0.0)
	assert_float(t - windup_at).is_greater_equal(1.0)
	assert_bool(c.is_gulping()).is_true()   # the chaser is on screen biting at that moment
	assert_int(w.model.segments.size()).is_equal(segs - 1)


func test_a_stage_4_worm_is_not_chased_and_can_eat_it() -> void:
	var w := _worm(Vector2.ZERO, 4)
	var c := _centipede(w.head_position() + Vector2(60, 0))
	var d0 := c.global_position.distance_to(w.head_position())
	for i in 120:
		c.step(DT)
		assert_int(c.mode).is_not_equal(Creature.Mode.STALK)
		assert_int(c.mode).is_not_equal(Creature.Mode.WINDUP)
		assert_int(c.mode).is_not_equal(Creature.Mode.LUNGE)
	assert_int(c.mode).is_equal(Creature.Mode.FLEE)
	assert_float(c.global_position.distance_to(w.head_position())).is_greater(d0)
	assert_bool(c.threatens(w)).is_false()
	assert_bool(c.can_be_eaten_by(w)).is_true()
	assert_bool(c.is_in_group(&"food")).is_true()
	assert_bool(w.can_eat(_cd())).is_true()


func test_lives_in_the_dirt_ring() -> void:
	var life: RingLife = load("res://data/rings/dirt_life.tres")
	var found := false
	for rule in life.species:
		if rule.id == &"centipede":
			found = true
			assert_str(rule.live).is_equal("res://scenes/creatures/centipede.tscn")
	assert_bool(found).is_true()
