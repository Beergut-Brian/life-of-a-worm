## The living rings' counters (RingEcology over data/rings/*_life.tres): thin the beetles and the
## grubs boom (and the roots they eat drop); thin the birds and the grubs fall; nothing is ever
## emptied for good; the same seed gives the same numbers; the counters round-trip through a save.
extends GdUnitTestSuite

const LIVES := [preload("res://data/rings/dirt_life.tres"), preload("res://data/rings/topsoil_life.tres")]
const SEED := 42


func _eco() -> RingEcology:
	var e := RingEcology.from_lives(LIVES, SEED)
	e.wobble = 0.05
	return e


## Runs `seconds` planet seconds; every 30 s keeps only `keep` of the culled species (a hungry worm).
func _run(e: RingEcology, seconds: int, cull: StringName = &"", keep := 0.2) -> void:
	for t in seconds:
		if cull != &"" and t % 30 == 0:
			e.kill(cull, e.count(cull) * (1.0 - keep))
		e.step(1.0)


func test_thinning_the_beetles_makes_the_grubs_boom() -> void:
	var base := _eco()
	_run(base, 1800)
	var thin := _eco()
	_run(thin, 1800, &"beetle")
	print("rings: base grubs %.1f beetles %.1f roots %.1f | thinned grubs %.1f beetles %.1f roots %.1f" % [
		base.count(&"grub"), base.count(&"beetle"), base.count(&"root"),
		thin.count(&"grub"), thin.count(&"beetle"), thin.count(&"root")])
	assert_float(thin.count(&"beetle")).is_less(base.count(&"beetle") * 0.5)
	assert_float(thin.count(&"grub")).is_greater(base.count(&"grub") * 1.8)
	# ...and the grubs eat the roots down: the shift runs down the chain.
	assert_float(thin.count(&"root")).is_less(base.count(&"root") * 0.85)


func test_the_boom_shows_in_the_live_bodies() -> void:
	var base := _eco()
	_run(base, 1800)
	var thin := _eco()
	_run(thin, 1800, &"beetle")
	var rule: PopulationRule = thin.rules[&"grub"]
	var want_base := clampi(roundi(base.count(&"grub") * rule.live_scale), 0, rule.live_max)
	var want_thin := clampi(roundi(thin.count(&"grub") * rule.live_scale), 0, rule.live_max)
	assert_int(want_thin).is_greater_equal(want_base + 4)


## Mean of a species over the last `tail` seconds of a run (the chain swings; means don't).
func _mean(e: RingEcology, seconds: int, tail: int, id: StringName, cull: StringName = &"") -> float:
	var sum := 0.0
	for t in seconds:
		if cull != &"" and t % 30 == 0:
			e.kill(cull, e.count(cull) * 0.8)
		e.step(1.0)
		if t >= seconds - tail:
			sum += e.count(id)
	return sum / tail


## Two links away: with fewer birds about the beetles hunt freely and the grubs fall.
func test_thinning_the_birds_thins_the_grubs() -> void:
	var base := _mean(_eco(), 2400, 1200, &"grub")
	var thin := _mean(_eco(), 2400, 1200, &"grub", &"bird")
	print("rings: mean grubs base %.2f, birds thinned %.2f" % [base, thin])
	assert_float(thin).is_less(base * 0.7)


func test_a_ring_is_never_emptied_for_good() -> void:
	var e := _eco()
	for id in e.counts:
		e.kill(id, 99999.0)
	_run(e, 900)
	for id in e.counts:
		assert_float(e.count(id)).is_greater(0.5)


func test_same_seed_same_numbers() -> void:
	var a := _eco()
	var b := _eco()
	_run(a, 600, &"grub")
	_run(b, 600, &"grub")
	for id in a.counts:
		assert_float(a.count(id)).is_equal(b.count(id))


func test_counters_are_per_ring_and_round_trip() -> void:
	var a := _eco()
	_run(a, 120)
	var rings := a.by_ring()
	assert_bool(rings.has(&"dirt") and rings.has(&"topsoil")).is_true()
	assert_bool(rings[&"dirt"].has(&"beetle")).is_true()
	assert_bool(rings[&"topsoil"].has(&"ant")).is_true()
	var b := _eco()
	b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	for id in a.counts:
		assert_float(b.count(id)).is_equal_approx(a.count(id), 0.01)
	assert_float(b.time).is_equal(a.time)


func test_big_catch_up_steps_stay_stable() -> void:
	var a := _eco()
	a.step(3600.0)
	for id in a.counts:
		assert_bool(is_finite(a.count(id)) and a.count(id) >= 0.0).is_true()
		assert_float(a.count(id)).is_less_equal(a.rules[id].capacity + 1.0)
