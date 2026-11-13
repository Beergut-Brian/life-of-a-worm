## Centipede (L-08, stage 3; feature/worm-creatures-2): a wavy chaser that gives up fast. Who it
## chases is CreatureSense alone (a worm smaller than stage 3); it gives up after `chase_time` or
## once the worm is past `give_up_distance`, turning away (GIVE_UP, huff cue); it winds up a full
## second before it can bite; a stage-4 worm is never chased and can eat it. Staged in fixed
## places with a fixed delta, inside its own save profile and settings file.
## feature/worm-centipede-1 adds: the wind-up hump runs head to tail before every lunge, the first
## give-up (only) leans the camera in, it never moves a worm itself, it is never drawn bigger than a
## worm of its own stage, and the dirt ring's counter spawns it only in its band, up to live_max.
extends GdUnitTestSuite

const SUITE := "centipede"
const WORM := preload("res://scenes/players/worm.tscn")
const CENTIPEDE := preload("res://scenes/creatures/centipede.tscn")
const DATA := "res://data/creatures/centipede.tres"
const DT := 1.0 / 60.0
const RINGS := preload("res://data/rings/rings.tres")
const RADIUS := 300
const UP := -PI / 2.0


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


# --- feature/worm-centipede-1 ------------------------------------------------------------------

func test_its_wind_up_wave_runs_down_the_body_before_every_lunge() -> void:
	var cd := _cd()
	assert_float(cd.telegraph_time()).is_between(1.0, 1.5)
	var w := _worm(Vector2.ZERO, 1)
	var c := _centipede(w.head_position() + Vector2(90, 0))
	var lunges := [0]
	var waves_at_lunge: Array[int] = []
	var wraps := [0]
	var last := [-1.0]
	var t_windup := [0.0]
	for i in 200:
		var was := c.mode
		var k_before := c.windup_wave()
		c.step(DT)
		if c.mode == Creature.Mode.WINDUP:
			t_windup[0] += DT
			var k := c.windup_wave()
			assert_float(k).is_between(0.0, 1.0)
			if last[0] >= 0.0 and k < last[0]:
				wraps[0] += 1   # a hump reached the tail, the next one starts at the head
			last[0] = k
		if was == Creature.Mode.WINDUP and c.mode == Creature.Mode.LUNGE:
			lunges[0] += 1
			waves_at_lunge.append(wraps[0])
			assert_float(k_before).is_greater(0.9)   # the last hump is at the tail as it lunges
			assert_float(t_windup[0]).is_greater_equal(1.0)
			break
	assert_int(lunges[0]).is_equal(1)
	assert_int(waves_at_lunge[0]).is_equal(int(Centipede.WINDUP_PASSES) - 1)
	assert_float(c.windup_wave()).is_equal(-1.0)   # no hump outside the wind-up


func test_the_hump_lifts_the_segment_it_is_on() -> void:
	var w := _worm(Vector2.ZERO, 1)
	var c := _centipede(w.head_position() + Vector2(90, 0))
	for i in 120:
		c.step(DT)
		if c.mode == Creature.Mode.WINDUP:
			break
	assert_int(c.mode).is_equal(Creature.Mode.WINDUP)
	var n := _cd().segments
	var tel := _cd().telegraph_time()
	# step until the hump is near the middle of the body, then the middle segment is lifted most
	while c.windup_wave() < 0.45 and c.mode == Creature.Mode.WINDUP:
		c.step(DT)
	var mid := roundi(c.windup_wave() * n)
	assert_float(c._hump(mid, n)).is_greater(0.8)
	assert_float(c._hump(0, n)).is_less(0.3)
	assert_float(c._hump(n, n)).is_less(0.3)
	assert_float(tel).is_greater(0.0)


func test_the_first_give_up_leans_the_camera_in_once() -> void:
	var cam := PolarCamera.new()
	add_child(cam)
	auto_free(cam)
	cam.set_process(false)
	cam.make_current()
	var w := _worm(Vector2.ZERO, 1)
	var c := _centipede(w.head_position() + Vector2(120, 0))
	var beats := [0]
	c.gave_up_beat.connect(func(_at: Vector2) -> void: beats[0] += 1)
	c.step(DT)
	assert_int(c.mode).is_equal(Creature.Mode.STALK)
	_hold_gap(w, c, _cd().give_up_distance + 10.0)
	c.step(DT)
	assert_int(c.mode).is_equal(Creature.Mode.GIVE_UP)
	assert_int(beats[0]).is_equal(1)
	assert_int(cam.lean_in).is_equal(1)
	for i in int((Centipede.BEAT_TIME + 0.1) / DT):
		c.step(DT)
	assert_int(cam.lean_in).is_equal(0)   # a short beat, then the camera is the kid's again
	# it gives up again later: no second beat
	c.rest = 0.0
	c._set_mode(Creature.Mode.IDLE)
	_hold_gap(w, c, 120.0)
	c.step(DT)
	assert_int(c.mode).is_equal(Creature.Mode.STALK)
	c.give_up()
	assert_int(c.give_ups).is_equal(2)
	assert_int(beats[0]).is_equal(1)
	assert_int(c.beats).is_equal(1)
	assert_int(cam.lean_in).is_equal(0)


func test_it_never_moves_the_worm_on_its_own() -> void:
	# a chased worm holding its gap, a missed lunge, a give-up and the sulk: the head stays put
	# The worm starts well inside `notice` so the chase begins on the first step. (It used to start
	# exactly `notice` away; `prey_d < notice` is strict, so the centipede idled and wandered to a
	# randf() point, and whether it ever came close enough depended on the global RNG.)
	var at := Vector2(-40, 0)
	var w := _worm(Vector2.ZERO, 1)
	w.head.global_position = at
	var c := _centipede(at + Vector2(_cd().notice - 40.0, 0))
	var eaten := [0]
	w.eaten_by.connect(func(_p: int, _who: StringName) -> void: eaten[0] += 1)
	var saw := {}
	for i in 600:
		if c.mode == Creature.Mode.LUNGE:
			at = c.global_position + Vector2(-260, 0)   # the kid dodges the lunge
		w.head.global_position = at
		c.step(DT)
		if i == 0:
			assert_int(c.mode).is_equal(Creature.Mode.STALK)   # no wander, no dice
		saw[c.mode] = true
		assert_vector(w.head.global_position).is_equal(at)
	assert_int(eaten[0]).is_equal(0)
	assert_bool(saw.has(Creature.Mode.WINDUP)).is_true()
	assert_bool(saw.has(Creature.Mode.GIVE_UP)).is_true()
	assert_int(c.give_ups).is_greater_equal(1)   # counted per give_up() call, not per sampled frame
	# a worm its own size and a bigger one sitting right on it are never pushed either
	for stage in [3, 4]:
		var big := _worm(Vector2(stage * 4000, 0), stage)
		var c2 := _centipede(big.head_position() + Vector2(8, 0))
		var p0 := big.head.global_position
		for i in 120:
			c2.step(DT)
			assert_vector(big.head.global_position).is_equal(p0)


## The worm head's radius on screen, px (as tests/test_kid_checks.gd measures it).
func _head_px(w: Worm) -> float:
	var img := w.head_sprite.texture.get_image()
	if img.is_compressed():
		img.decompress()
	var used := img.get_used_rect().size
	return maxf(used.x, used.y) * 0.5 * w.head_sprite.scale.x * w.look.scale.x


func test_it_is_never_drawn_bigger_than_a_worm_of_its_stage() -> void:
	var cd := _cd()
	for stage in [3, 4]:
		var w := _worm(Vector2(stage * 5000, 0), stage)
		var c := _centipede(w.head_position() + Vector2(70, 0))
		var head := _head_px(w)
		for i in 90:
			c.step(DT)
			# its biggest circle is the head, 0.75 r (Centipede._draw_head)
			var shown := cd.radius * c.draw_scale() * 0.75
			assert_float(shown).override_failure_message(
				"stage %d: drawn %.1f px against a %.1f px head" % [stage, shown, head]).is_less_equal(head)
	# and to a smaller worm it does read as bigger (K-01, the other side)
	var small := _worm(Vector2(30000, 0), 2)
	var c3 := _centipede(small.head_position() + Vector2(300, 0))
	c3.step(DT)
	assert_float(cd.radius * c3.draw_scale() * 0.75).is_greater(_head_px(small))


func test_the_dirt_counter_spawns_it_only_in_its_band_up_to_live_max() -> void:
	var world := PolarWorld.new()
	world.build_overview = false
	world.setup_planet(RINGS, RADIUS, 7)
	add_child(world)
	world.set_physics_process(false)
	auto_free(world)
	var r0 := float(RADIUS) * 16.0
	var start := Vector2.from_angle(UP) * r0 * 0.68
	var w := _worm(start, 1)
	w.head.global_position = start
	world.track(w.head)
	world.update_chunks(-1)
	var dir := RingsDirector.new()
	dir.auto_tick = false
	add_child(dir)
	auto_free(dir)
	dir.setup(world, start, 4, {})
	dir.hook_worm(w)
	var rule: PopulationRule = dir.ecology.rules[&"centipede"]
	assert_str(String(rule.ring)).is_equal("dirt")
	assert_int(rule.live_max).is_between(1, 3)
	for id in dir.ecology.rules:
		if id != &"centipede":
			assert_bool(dir.ecology.rules[id].live.contains("centipede")).is_false()
	var band := dir.ring_band(&"dirt")
	var lo := maxf(rule.depth_min, band.x)
	var hi := band.y if rule.depth_max <= 0.0 else rule.depth_max
	# a big counter: still never more than live_max bodies at once
	dir.ecology.counts[&"centipede"] = 50.0
	var most := 0
	for i in 60:
		dir.fit_live()
		var have := dir.live_of(&"centipede")
		most = maxi(most, have.size())
		assert_int(have.size()).is_less_equal(rule.live_max)
		for n in have:
			(n as Node).set_physics_process(false)
			var d := dir.depth_of(n.position)
			assert_float(d).override_failure_message("centipede at depth %.3f" % d).is_between(lo, hi)
	assert_int(most).is_equal(rule.live_max)
