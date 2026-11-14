## D105 kid rule for stages 1 and 2: something new at least every 15 minutes, counted in the seeded
## pacing sim (tests/pacing_sim.gd, seeds 1 to 5, kid and adult) from signals only, never by polling.
## PacingSim already counts first tastes (every data/foods file in an open ring, the D105 foods too),
## traits and stage-ups. This suite's sim adds the other new things the kid meets:
##   - a creature of an open ring (data/creatures): the kid runs into one of them every MEET_MIN
##     minutes on average (a random one of the open rings'; the first time it is that kind, it's new);
##   - a ring's visible event (RingLife.events): first_after planet seconds after its ring opens, at
##     the kid's share of time in that ring (PRESENCE; the first stage's ring is home, always 1.0); a
##     rain-only one waits a whole shower cycle (the worst case).
## Each first meeting is a `first_meet` signal; the Recorder logs it as "new". The run goes until the
## stage-up to 3 (stages 1 and 2 played). The worst gap is printed with and without the D105 things.
extends GdUnitTestSuite

const NEW_EVERY_S := 15.0 * 60.0
## Minutes between running into some creature, and the share of time in the newest ring.
const MEET_MIN := { "kid": 2.0, "adult": 1.5 }
const PRESENCE := { "kid": 0.6, "adult": 0.8 }
const D105 := preload("res://tests/test_d105_stage12.gd")


class NoveltySim:
	extends PacingSim

	## A creature or a ring event met for the first time in this run ("creature x" / "event x").
	signal first_meet(what: String)

	var creatures: Array[CreatureData] = []
	var events: Array[RingEvent] = []
	var opened_at := {}     # ring -> clock it opened
	var met := {}
	var _sense := RandomNumberGenerator.new()

	func _init(p: Dictionary, seed_value: int) -> void:
		super(p, seed_value)
		_sense.seed = seed_value * 977 + 3
		for f in DirAccess.get_files_at("res://data/creatures/"):
			if f.ends_with(".tres"):
				var d := load("res://data/creatures/" + f) as CreatureData
				if d and not d.jarling:
					creatures.append(d)
		events = RingEvents.all_events(RingsDirector.LIVES)
		opened_at[rules.stage_info(1).opens_ring] = 0.0
		model.stage_changed.connect(_on_opened)

	func _on_opened(_from: int, to: int) -> void:
		var ring := rules.stage_info(to).opens_ring
		if ring != &"" and not opened_at.has(ring):
			opened_at[ring] = clock

	func _step(a: float) -> void:
		super._step(a)
		var rings := open_rings(model.stage)
		if _sense.randf() < 1.0 / (float(MEET_MIN[profile.name]) * 60.0):
			var here := creatures.filter(func(d: CreatureData) -> bool: return d.ring in rings)
			if not here.is_empty():
				var d: CreatureData = here[_sense.randi() % here.size()]
				_meet("creature " + String(d.id))
		for e in events:
			if met.has("event " + String(e.id)) or not opened_at.has(e.ring) or model.stage < e.stage_from:
				continue
			var wait := e.first_after + (RingsDirector.RAIN_EVERY if e.after_rain else 0.0)
			var share := 1.0 if e.ring == rules.stage_info(1).opens_ring else float(PRESENCE[profile.name])
			if clock >= float(opened_at[e.ring]) + wait / share:
				_meet("event " + String(e.id))

	func _meet(what: String) -> void:
		if met.has(what):
			return
		met[what] = true
		first_meet.emit(what)


static func play(p: Dictionary, sd: int) -> PacingSim.Recorder:
	var sim := NoveltySim.new(p, sd)
	var rec := PacingSim.Recorder.new(sim)
	sim.first_meet.connect(func(what: String) -> void: rec._new(what))
	sim.run(3)
	rec.end = sim.clock
	return rec


## Worst gap between "new" events, keeping only those `keep` says yes to (the run's end counts).
static func worst(rec: PacingSim.Recorder, keep: Callable) -> float:
	var times: Array = rec.times[&"new"]
	var last := 0.0
	var w := 0.0
	for i in times.size():
		if not keep.call(rec.labels[i]):
			continue
		w = maxf(w, float(times[i]) - last)
		last = float(times[i])
	return maxf(w, rec.end - last)


static func is_d105(label: String) -> bool:
	for id in D105.all_ids():
		if label.begins_with("food %s @" % id) or label.begins_with("creature %s @" % id) or label.begins_with("event %s @" % id):
			return true
	return false


func test_stages_one_and_two_show_something_new_at_least_every_fifteen_minutes() -> void:
	var lines: Array[String] = []
	var worst_all := 0.0
	var worst_old := 0.0
	for p in [PacingSim.KID, PacingSim.ADULT]:
		for sd in range(1, 6):
			var rec := play(p, sd)
			var with := worst(rec, func(_l: String) -> bool: return true)
			var without := worst(rec, func(l: String) -> bool: return not is_d105(l))
			var n_new := rec.labels.filter(func(l: String) -> bool: return is_d105(l)).size()
			worst_all = maxf(worst_all, with)
			worst_old = maxf(worst_old, without)
			lines.append("d105 novelty %s seed %d: stages 1-2 %.1f min, %d new things (%d D105), worst gap %.1f min (without D105 %.1f min), stage 2 at %.1f min" % [
				p.name, sd, rec.end / 60.0, rec.labels.size(), n_new, with / 60.0, without / 60.0, float(rec.stage_at.get(2, 0.0)) / 60.0])
			assert_float(with).override_failure_message(lines.back() + "\n" + "\n".join(rec.labels)).is_less_equal(NEW_EVERY_S)
	for l in lines:
		print(l)
	print("d105 novelty worst gap, seeds 1-5, kid and adult: %.1f min (without D105 %.1f min)" % [worst_all / 60.0, worst_old / 60.0])


## The new things land inside stages 1 and 2: in every seed the kid meets at least MIN_MET of them
## before the stage-up to 3, and across seeds 1 to 5 every D105 creature and event is met at least
## once (a food is a random draw of the ring's menu, so it may wait for a later stage).
const MIN_MET := 8


func test_the_d105_things_are_met_inside_stages_one_and_two() -> void:
	var ever := {}
	for sd in range(1, 6):
		var rec := play(PacingSim.KID, sd)
		var n := 0
		for l in rec.labels:
			if is_d105(l):
				n += 1
				ever[StringName(l.split(" ")[1])] = true
		print("d105 met kid seed %d: %d of %d D105 things in stages 1-2" % [sd, n, D105.all_ids().size()])
		assert_int(n).override_failure_message("seed %d met only %d" % [sd, n]).is_greater_equal(MIN_MET)
	var never: Array[String] = []
	for id in D105.all_ids():
		if not ever.has(id) and not D105.FOODS.has(id):
			never.append(String(id))
	assert_array(never).override_failure_message("never met in stages 1-2: %s" % [never]).is_empty()


func test_the_log_is_fed_by_the_meet_signal() -> void:
	var sim := NoveltySim.new(PacingSim.KID, 1)
	var rec := PacingSim.Recorder.new(sim)
	sim.first_meet.connect(func(what: String) -> void: rec._new(what))
	sim._meet("creature mite")
	sim._meet("creature mite")
	assert_int((rec.times[&"new"] as Array).size()).is_equal(1)
	assert_str(rec.labels[0]).starts_with("creature mite @")
