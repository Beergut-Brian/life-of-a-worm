## D108 a (K-06): kid mode's timed "new" in the game. The clock (TimedNewClock), the look pool
## (TimedLooks: 3 hats x 4 colours x 2 patterns from existing art) and the worm.tscn child
## (TimedNew) that puts a look on the worm with a cue and a pop. The pacing side (gaps measured on
## the kid driver) is in tests/test_pacing_audit.gd.
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")

var _worms: Array[Worm] = []


func before() -> void:
	SuiteSandbox.enter("timed_new")


func after() -> void:
	SuiteSandbox.leave()


func before_test() -> void:
	Save.wipe()
	Players.solo = false


func after_test() -> void:
	Players.solo = false
	for w in _worms:
		if is_instance_valid(w):
			remove_child(w)
			w.free()
	_worms.clear()
	for p in Audio._pool:
		p.stop()


func _worm() -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = Players.P1
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	w.set_physics_process(false)
	_worms.append(w)
	return w


func _timed(w: Worm) -> TimedNew:
	var t: TimedNew = w.get_node("TimedNew")
	t.set_process(false)   # tests step the clock by hand
	return t


func test_the_clock_fires_after_twelve_minutes_of_play_only() -> void:
	var c := TimedNewClock.new()
	assert_float(TimedNewClock.EVERY_S).is_equal(720.0)
	for i in 719:
		assert_bool(c.step(1.0, true)).is_false()
	assert_bool(c.step(1.0, true)).is_true()
	assert_float(c.elapsed).is_equal(0.0)
	assert_int(c.fired).is_equal(1)


func test_a_real_new_event_restarts_the_wait() -> void:
	var c := TimedNewClock.new()
	for i in 700:
		c.step(1.0, true)
	c.reset()
	for i in 719:
		assert_bool(c.step(1.0, true)).is_false()
	assert_bool(c.step(1.0, true)).is_true()


func test_a_break_restarts_from_zero_with_no_burst() -> void:
	var c := TimedNewClock.new()
	for i in 600:
		c.step(1.0, true)
	for i in 3600:   # an hour in the pause menu
		assert_bool(c.step(1.0, false)).is_false()
	for i in 719:
		assert_bool(c.step(1.0, true)).is_false()
	assert_bool(c.step(1.0, true)).is_true()
	var d := TimedNewClock.new()
	for i in 600:
		d.step(1.0, true)
	d.interrupt()
	assert_bool(d.step(130.0, true)).is_false()


func test_each_stage_pool_has_24_looks_and_cycles_after_all() -> void:
	for s in range(1, 8):
		var seen := {}
		for k in TimedLooks.SIZE:
			var l := TimedLooks.look(s, k)
			var key := "%s|%s|%s" % [l.hat, l.colour.to_html(), l.pattern]
			assert_bool(seen.has(key)).override_failure_message("stage %d look %d repeats %s" % [s, k, key]).is_false()
			seen[key] = true
		assert_int(seen.size()).is_equal(24)
		assert_int(TimedLooks.look(s, 24).index).is_equal(TimedLooks.look(s, 0).index)
	var a := TimedLooks.look(1, 0)
	var b := TimedLooks.look(1, 1)
	assert_bool(a.hat != b.hat and a.colour != b.colour).is_true()


func test_looks_use_only_existing_art_and_bright_colours() -> void:
	for h in TimedLooks.HATS:
		var tex: Texture2D = TimedLooks.HAT_TEX[h]
		assert_object(tex).is_not_null()
		assert_str(tex.resource_path).starts_with("res://assets/proto/worm/")
	for s in range(1, 8):
		for c in TimedLooks.COLOURS:
			var col := TimedLooks.colour(s, c)
			assert_float(col.v).is_greater_equal(0.9)
			# never the players' green (P1) or red (P2) body hue
			if col.s > 0.2:
				assert_bool(col.h > 0.2 and col.h < 0.45).override_failure_message("green %s" % col.to_html()).is_false()
				assert_bool(col.h < 0.04 or col.h > 0.98).override_failure_message("red %s" % col.to_html()).is_false()


func test_a_timed_new_puts_a_look_on_the_worm_with_a_cue() -> void:
	var w := _worm()
	var t := _timed(w)
	await get_tree().process_frame
	for i in 4:
		w.model.add_segment(&"")
	await get_tree().process_frame
	var before := int(Audio.played.get(TimedNew.CUE, 0))
	var growth := w.model.growth
	var segs := w.model.segments.size()
	var stats := w.model.stats.value("speed")
	var stage := w.stage
	var heard := []
	t.fired.connect(func(p: int, look: Dictionary) -> void: heard.append([p, look]))
	t.fire()
	assert_int(heard.size()).is_equal(1)
	assert_object(t.hat()).is_not_null()
	assert_bool(t.hat().visible).is_true()
	assert_object(t.hat().texture).is_equal(TimedLooks.HAT_TEX[t.current.hat])
	assert_int(t.stripe_count()).is_equal(TimedLooks.PATTERN_SEGMENTS)
	assert_int(int(Audio.played.get(TimedNew.CUE, 0))).is_equal(before + 1)
	# Cosmetic only: no growth, no segment, no stat.
	assert_float(w.model.growth).is_equal(growth)
	assert_int(w.model.segments.size()).is_equal(segs)
	assert_float(w.model.stats.value("speed")).is_equal(stats)
	assert_int(w.stage).is_equal(stage)
	var first: int = t.current.index
	t.fire()
	assert_int(t.current.index).is_not_equal(first)


func test_the_clock_drives_the_look_and_real_events_reset_it() -> void:
	var w := _worm()
	var t := _timed(w)
	await get_tree().process_frame
	for i in 700:
		t.clock.step(1.0, true)
	w.trait_earned.emit(w.player, &"glow")
	assert_float(t.clock.elapsed).is_equal(0.0)
	for i in 700:
		t.clock.step(1.0, true)
	w.stage_changed.emit(w.player, 1, 2)
	assert_float(t.clock.elapsed).is_equal(0.0)
	t.clock.elapsed = TimedNewClock.EVERY_S - 0.000001
	t.set_process(true)
	await get_tree().process_frame
	await get_tree().process_frame
	t.set_process(false)
	assert_int(t.clock.fired).is_equal(1)
	assert_object(t.hat()).is_not_null()


func test_not_playing_states_stop_the_clock() -> void:
	var w := _worm()
	var t := _timed(w)
	await get_tree().process_frame
	assert_bool(t.is_playing()).is_true()
	w.asleep = true
	assert_bool(t.is_playing()).is_false()
	w.asleep = false
	w.wall_open = true
	assert_bool(t.is_playing()).is_false()
	w.wall_open = false
	t.clock.elapsed = 500.0
	t._notification(Node.NOTIFICATION_UNPAUSED)
	t.clock.step(1.0, true)
	assert_float(t.clock.elapsed).is_equal(1.0)


func test_the_look_and_pool_place_are_kept_in_the_tin() -> void:
	var w := _worm()
	var t := _timed(w)
	await get_tree().process_frame
	t.fire()
	t.fire()
	var on: int = t.current.index
	remove_child(w)
	w.free()
	_worms.clear()
	var w2 := _worm()
	var t2 := _timed(w2)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(int(t2.shown.get(1, 0))).is_equal(2)
	assert_int(t2.current.index).is_equal(on)
	assert_object(t2.hat()).is_not_null()


func test_adult_mode_never_shows_a_timed_look() -> void:
	Players.solo = true
	assert_bool(TimedNew.kid_mode()).is_false()
	var w := _worm()
	var t := _timed(w)
	await get_tree().process_frame
	assert_bool(t.enabled).is_false()
	t.fire()
	t.clock.elapsed = TimedNewClock.EVERY_S
	t.set_process(true)
	await get_tree().process_frame
	t.set_process(false)
	assert_object(t.hat()).is_null()
	assert_int(t.stripe_count()).is_equal(0)
	assert_bool(Save.get_value(TimedNew.SAVE_KEY, {}).is_empty()).is_true()
