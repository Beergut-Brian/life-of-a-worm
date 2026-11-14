## D105 kid rule for stages 3 to 7: something new at least every 15 minutes, counted in the seeded
## pacing sim (tests/pacing_sim.gd, seeds 1 to 5, kid and adult) from signals only, never by polling.
## PacingSim already counts first tastes (every data/foods file in an open ring), traits and
## stage-ups. This suite's sim adds the other new things a kid meets in stages 3 to 7, each a
## `first_meet` signal the Recorder logs as "new":
##   - a creature of an open ring whose counter's stage gate (PopulationRule.stage_from) the worm
##     has reached: the kid runs into some creature every MEET_MIN minutes (with PRESENCE odds one
##     of the creatures new at this stage, else any of those);
##   - a ring event (every RingsDirector.all_lives() event, the sky and surface too): first_after
##     planet seconds after the worm reaches both its ring and its stage_from, at the kid's share of
##     time in that ring (PRESENCE in that stage's own new ring, half that in an older ring); a
##     rain-only one waits a whole shower cycle (the worst case);
##   - space (stage 7): the sim's stage 7 (WormGrowth's own stage-up at 40 segments) is the chomp;
##     then the kid eats a themed planet every PLANET_MIN minutes (each is new: a planet and its
##     foods), the sun after the fifth, and each space sight (SpaceSights) comes first_after space
##     seconds after its after_planets planets are eaten. The run ends SUN_MIN after the sun.
## The sky is open to the sim's food draws from SkyLife.edible_from (it is in play; PacingSim's
## stage table opens no stage on it). Pacing numbers are not changed: this only reads them.
extends GdUnitTestSuite

const NEW_EVERY_S := 15.0 * 60.0
const MEET_MIN := { "kid": 2.0, "adult": 1.5 }
const PRESENCE := { "kid": 0.6, "adult": 0.8 }
const PLANET_MIN := { "kid": 6.0, "adult": 3.0 }
const SUN_MIN := 3.0
const S37 := preload("res://tests/test_d105_stage37.gd")
const T := preload("res://tests/d105_stage37_table.gd")


class Sim37:
	extends PacingSim

	signal first_meet(what: String)

	var creatures: Array[CreatureData] = []
	var gate := {}             # creature id -> stage_from
	var events: Array[RingEvent] = []
	var sights: Array[SpaceSight] = []
	var reached := {}          # stage -> clock it was reached
	var met := {}
	var planets: Array[StringName] = []
	var in_space := -1.0       # clock the chomp happened (stage 7), -1 before
	var eaten := 0
	var sun_at := -1.0
	var sight_wait := {}
	var _sense := RandomNumberGenerator.new()

	func _init(p: Dictionary, seed_value: int, r: WormRules = null) -> void:
		super(p, seed_value, r)
		_sense.seed = seed_value * 977 + 3
		for f in DirAccess.get_files_at("res://data/creatures/"):
			if f.ends_with(".tres"):
				var d := load("res://data/creatures/" + f) as CreatureData
				if d and not d.jarling:
					creatures.append(d)
					var rule := S37.rule_of(d.id)
					gate[d.id] = rule.stage_from if rule else 0
		events = RingEvents.all_events(RingsDirector.all_lives())
		sights = SpaceSights.all_sights()
		for s in sights:
			sight_wait[s.id] = 0.0
		var life: SpaceLife = load(SpaceDrift.LIFE_PATH)
		for d in SpaceDrift.shuffled(life.planets, seed_value):
			planets.append(d.id)
		reached[1] = 0.0
		model.stage_changed.connect(_on_stage)

	func _on_stage(_from: int, to: int) -> void:
		reached[to] = clock
		if to == 7:
			in_space = clock

	func open_rings(stage: int) -> Array[StringName]:
		var out := super.open_rings(stage)
		if stage >= RingsDirector.SKY.edible_from and stage < 7:
			out.append(RingsDirector.SKY.ring)
		if stage >= 7:
			out.clear()   # space: nothing of the disk
		return out

	func done() -> bool:
		return sun_at >= 0.0 and clock >= sun_at + SUN_MIN * 60.0

	func _step(a: float) -> void:
		if in_space >= 0.0:
			_space_step()
			return
		super._step(a)
		var rings := open_rings(model.stage)
		if _sense.randf() < 1.0 / (float(MEET_MIN[profile.name]) * 60.0):
			var stage := model.stage
			var here := creatures.filter(func(d: CreatureData) -> bool:
				return d.ring in rings and stage >= int(gate[d.id]))
			# mostly one of the creatures new at this stage (its new ring, or newly let out by its gate)
			var fresh := here.filter(func(d: CreatureData) -> bool:
				return maxi(S37.ring_stage(d.ring), int(gate[d.id])) == stage)
			if not fresh.is_empty() and _sense.randf() < float(PRESENCE[profile.name]):
				here = fresh
			if not here.is_empty():
				var d: CreatureData = here[_sense.randi() % here.size()]
				_meet("creature " + String(d.id))
		for e in events:
			if met.has("event " + String(e.id)):
				continue
			var from := maxi(S37.ring_stage(e.ring), e.stage_from)
			if model.stage < from or not reached.has(from):
				continue
			var share := float(PRESENCE[profile.name])
			if S37.ring_stage(e.ring) != from:
				share *= 0.5
			var wait := e.first_after + (RingsDirector.RAIN_EVERY if e.after_rain else 0.0)
			if clock >= float(reached[from]) + wait / share:
				_meet("event " + String(e.id))

	func _space_step() -> void:
		var t := clock - in_space
		var per := float(PLANET_MIN[profile.name]) * 60.0
		if t >= 60.0:
			_meet("space moon")
		if t >= 120.0:
			_meet("space comet")
		while eaten < planets.size() and t >= per * (eaten + 1):
			eaten += 1
		for i in eaten:
			_meet("planet " + String(planets[i]))
		if eaten >= planets.size() and sun_at < 0.0:
			sun_at = clock
			_meet("space sun")
		for s in sights:
			if met.has("sight " + String(s.id)) or eaten < s.after_planets:
				continue
			sight_wait[s.id] = float(sight_wait[s.id]) + 1.0
			if float(sight_wait[s.id]) >= s.first_after:
				_meet("sight " + String(s.id))

	func _meet(what: String) -> void:
		if met.has(what):
			return
		met[what] = true
		first_meet.emit(what)

	## Plays until the end of space (the sun and SUN_MIN after it), on PacingSim's own stage rule.
	func play_all() -> PacingSim.Recorder:
		var rec := PacingSim.Recorder.new(self)
		first_meet.connect(func(what: String) -> void: rec._new(what))
		var apex_wait := -1.0
		while not done() and clock < MAX_HOURS * 3600.0:
			clock += 1.0
			_step(apex_wait)
			if in_space < 0.0 and model.size_stage() > model.stage:
				if apex_wait < 0.0:
					apex_wait = rng.randf_range(0.5, 1.5) * float(profile.apex_min) * 60.0
				apex_wait -= 1.0
				if apex_wait <= 0.0:
					model.eat_apex(model.stage)
					apex_wait = -1.0
		rec.end = clock
		return rec


static func is_d105_37(label: String) -> bool:
	var kind_id := label.split(" @")[0]
	var parts := kind_id.split(" ")
	if parts.size() < 2:
		return false
	var id := StringName(parts[1])
	match parts[0]:
		"food":
			return T.FOODS.has(id)
		"creature":
			return T.CREATURES.has(id)
		"event":
			return T.EVENTS.has(id)
		"sight":
			return T.SIGHTS.has(id)
	return false


## Worst gap between "new" events from `from` (stage 3's clock) to the end, keeping only those
## `keep` says yes to.
static func worst_from(rec: PacingSim.Recorder, from: float, keep: Callable) -> float:
	var times: Array = rec.times[&"new"]
	var last := from
	var w := 0.0
	for i in times.size():
		var t := float(times[i])
		if t < from or not keep.call(rec.labels[i]):
			continue
		w = maxf(w, t - last)
		last = t
	return maxf(w, rec.end - last)


static func play(p: Dictionary, sd: int, r: WormRules = null) -> Array:
	var sim := Sim37.new(p, sd, r)
	var rec := sim.play_all()
	return [sim, rec]


func test_stages_three_to_seven_show_something_new_at_least_every_fifteen_minutes() -> void:
	var lines: Array[String] = []
	var worst_all := 0.0
	var worst_old := 0.0
	for p in [PacingSim.KID, PacingSim.ADULT]:
		for sd in range(1, 6):
			var got := play(p, sd)
			var sim: Sim37 = got[0]
			var rec: PacingSim.Recorder = got[1]
			assert_bool(sim.done()).override_failure_message("%s seed %d never finished space" % [p.name, sd]).is_true()
			var s3 := float(rec.stage_at.get(3, 0.0))
			var with := worst_from(rec, s3, func(_l: String) -> bool: return true)
			var without := worst_from(rec, s3, func(l: String) -> bool: return not is_d105_37(l))
			var n_new := 0
			var n_all := 0
			for i in rec.labels.size():
				if float(rec.times[&"new"][i]) >= s3:
					n_all += 1
					if is_d105_37(rec.labels[i]):
						n_new += 1
			worst_all = maxf(worst_all, with)
			worst_old = maxf(worst_old, without)
			lines.append("d105 s37 novelty %s seed %d: stages 3-7 %.1f min (stage 3 at %.1f, 4 %.1f, 5 %.1f, 6 %.1f, space %.1f), %d new things (%d D105 3-7), worst gap %.1f min (without them %.1f min)" % [
				p.name, sd, (rec.end - s3) / 60.0, s3 / 60.0, float(rec.stage_at.get(4, 0.0)) / 60.0,
				float(rec.stage_at.get(5, 0.0)) / 60.0, float(rec.stage_at.get(6, 0.0)) / 60.0, sim.in_space / 60.0,
				n_all, n_new, with / 60.0, without / 60.0])
			assert_float(with).override_failure_message(lines.back() + "\n" + "\n".join(rec.labels)).is_less_equal(NEW_EVERY_S)
	for l in lines:
		print(l)
	print("d105 s37 novelty worst gap, stages 3-7, seeds 1-5, kid and adult: %.1f min (without the D105 3-7 things %.1f min)" % [worst_all / 60.0, worst_old / 60.0])


## On dev's stage table each kid seed meets at least MIN_MET of the new things in stages 3 to 7 (a
## kid's stage 6 is only ~8 minutes there). With longer stages (a what-if table, LONG_SEGMENTS,
## the thresholds BALANCE.md proposes from stages-1; the real data is never touched) every new creature, event and space
## sight is met at least once across seeds 1 to 5 (foods are random draws of the ring's menu).
const MIN_MET := 40
const LONG_SEGMENTS := [0, 0, 40, 90, 150, 210, 300, 360]


func test_the_new_things_are_met_in_stages_three_to_seven() -> void:
	for sd in range(1, 6):
		var rec: PacingSim.Recorder = play(PacingSim.KID, sd)[1]
		var n := rec.labels.filter(func(l: String) -> bool: return is_d105_37(l)).size()
		print("d105 s37 met kid seed %d: %d of %d new things" % [sd, n, S37.all_ids().size()])
		assert_int(n).override_failure_message("seed %d met only %d" % [sd, n]).is_greater_equal(MIN_MET)


func test_with_longer_stages_every_new_creature_event_and_sight_is_met() -> void:
	var r := PacingSim.rules_with(WormRules.default_rules().growth_per_segment, PackedInt32Array(LONG_SEGMENTS))
	var ever := {}
	for sd in range(1, 6):
		var rec: PacingSim.Recorder = play(PacingSim.KID, sd, r)[1]
		var n := 0
		for l in rec.labels:
			if is_d105_37(l):
				n += 1
				ever[StringName(l.split(" @")[0].split(" ")[1])] = true
		print("d105 s37 met kid seed %d, longer stages: %d of %d new things" % [sd, n, S37.all_ids().size()])
	var never: Array[String] = []
	for id in S37.all_ids():
		if not ever.has(id) and not T.FOODS.has(id):
			never.append(String(id))
	assert_array(never).override_failure_message("never met: %s" % [never]).is_empty()


func test_the_log_is_fed_by_the_meet_signal() -> void:
	var sim := Sim37.new(PacingSim.KID, 1)
	var rec := PacingSim.Recorder.new(sim)
	sim.first_meet.connect(func(what: String) -> void: rec._new(what))
	sim._meet("sight meteor_shower")
	sim._meet("sight meteor_shower")
	assert_int((rec.times[&"new"] as Array).size()).is_equal(1)
	assert_bool(is_d105_37(rec.labels[0])).is_true()
