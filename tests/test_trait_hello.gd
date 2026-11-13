## U-15: every trait has its own signature sound. Equipping plays that trait's sting once (never
## again on later frames), and a worm born already wearing traits (spawn, tin load) says a quiet
## hello with each one, once, with its part popping. Counted through Audio.played (equip) and
## TraitHello's `hello` signal / `played` counter (born with).
class_name TestTraitHello
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")


func before() -> void:
	SuiteSandbox.enter("trait_hello")


func after() -> void:
	for p in Audio._pool:
		p.stop()   # stings still playing at exit leak their playbacks
	for i in 3:
		await get_tree().process_frame
	for p in Audio._pool:
		p.stream = null
	SuiteSandbox.leave()


func _rules() -> WormRules:
	return WormRules.default_rules()


func _model(stage := 6) -> WormGrowth:
	var m := WormGrowth.new()
	m.apex_gate = true
	m.start_at_stage(stage)
	return m


func _worm(m: WormGrowth, p := 0, at := Vector2.ZERO) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = p
	w.model = m
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	w.position = at
	add_child(w)
	auto_free(w)
	return w


func _hello_of(w: Worm) -> TraitHello:
	return w.get_node("TraitHello") as TraitHello


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _delta(before: Dictionary, cue: String) -> int:
	return int(Audio.played.get(cue, 0)) - int(before.get(cue, 0))


func test_every_trait_has_a_sound_id_with_a_file() -> void:
	var traits := _rules().traits
	assert_int(traits.size()).is_greater_equal(10)
	for t in traits:
		assert_str(t.cue).override_failure_message("%s has no cue" % t.id).is_not_empty()
		assert_bool(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % t.cue)) \
			.override_failure_message("%s cue '%s' has no file" % [t.id, t.cue]).is_true()


func test_each_trait_stings_once_on_equip_not_every_frame() -> void:
	var traits := _rules().traits
	for i in traits.size():
		var t := traits[i]
		var w := _worm(_model(), 0, Vector2(600.0 * (i + 1), 0))
		await _frames(2)
		var before := Audio.played.duplicate()
		w.model.grant(t.id)   # earned straight onto the worm
		assert_int(_delta(before, t.cue)).override_failure_message("%s earn" % t.id).is_equal(1)
		w.model.toggle(t.id)   # off: silent
		w.model.toggle(t.id)   # on again, as from the trait wall
		assert_int(_delta(before, t.cue)).override_failure_message("%s equip" % t.id).is_equal(2)
		await _frames(20)
		assert_int(_delta(before, t.cue)).override_failure_message("%s frames" % t.id).is_equal(2)
		assert_int(int(_hello_of(w).played.get(t.id, 0))).override_failure_message(
			"%s: an equip is not a birth" % t.id).is_equal(0)


func test_a_worm_born_with_traits_says_each_hello_once() -> void:
	var rules := _rules()
	var m := _model()
	var want: Array[StringName] = []
	for t in rules.traits:
		if want.size() >= m.slots():
			break
		m.grant(t.id)
		want.append(t.id)
	assert_array(m.active).is_equal(want)
	var heard: Array = []
	var before := Audio.played.duplicate()
	var w: Worm = WORM.instantiate()
	w.model = m
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	var hi := w.get_node("TraitHello") as TraitHello
	hi.hello.connect(func(id: StringName, cue: String) -> void: heard.append([id, cue]))
	add_child(w)
	auto_free(w)
	await get_tree().create_timer(TraitHello.GAP * (want.size() + 2)).timeout
	await _frames(30)
	assert_int(heard.size()).is_equal(want.size())
	for i in want.size():
		assert_str(String(heard[i][0])).is_equal(String(want[i]))   # in the order they were put on
		assert_str(heard[i][1]).is_equal(rules.find_trait(want[i]).cue)
		assert_int(int(hi.played[want[i]])).is_equal(1)
	for id in want:   # the hello is the quiet player, not a second loud sting
		assert_int(_delta(before, rules.find_trait(id).cue)).is_equal(0)


func test_a_tin_load_onto_a_live_worm_says_hello() -> void:
	var w := _worm(_model())
	await _frames(3)
	var hi := _hello_of(w)
	assert_bool(hi.played.is_empty()).is_true()
	var saved := _model()
	var id := _rules().traits[0].id
	saved.grant(id)
	w.from_dict(saved.to_dict())   # no traits_changed: the body is rebuilt from data
	assert_bool(w.model.is_active(id)).is_true()
	await get_tree().create_timer(TraitHello.GAP * 2).timeout
	await _frames(10)
	assert_int(int(hi.played.get(id, 0))).is_equal(1)


func test_a_hello_is_seen_as_well_as_heard() -> void:
	var m := _model()
	var t := _rules().traits[0]
	m.grant(t.id)
	var w := _worm(m)
	await _frames(1)
	var rings_before := 0
	for c in w.fx.get_children():
		if c is WormRing:
			rings_before += 1
	_hello_of(w).say(t.id)
	var rings := 0
	for c in w.fx.get_children():
		if c is WormRing and (c as WormRing).color == t.color:
			rings += 1
	assert_int(rings).is_greater(rings_before)
	var quiet := false
	for c in _hello_of(w).get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).stream != null:
			quiet = (c as AudioStreamPlayer).volume_db < 0.0
	assert_bool(quiet).is_true()


func test_a_worm_born_bare_is_silent() -> void:
	var w := _worm(_model(1))
	await _frames(20)
	assert_bool(_hello_of(w).played.is_empty()).is_true()
