## Pacing audit (K-06, W-24, S-19; numbers in handoff/pacing.md and data/BALANCE.md "Pacing
## audit"). A seeded, scripted driver (tests/pacing_sim.gd) plays the worm on the real stage table,
## body model and foods; every gap below is measured between signals, never by polling a counter.
##   eaten: WormGrowth.segment_added (a segment grew)
##   new:   a food kind tasted for the first time, a trait earned, a stage (new ring or new look)
## Kid rules: a segment at least every 2 minutes, something new at least every 15.
extends GdUnitTestSuite

const SEEDS := [1, 2, 3, 4, 5]
const SEGMENT_EVERY_S := 120.0
const NEW_EVERY_S := 900.0
const STAGE_MIN_H := 2.0
const STAGE_MAX_H := 4.0
const CHOMP_MIN_H := 15.0
const CHOMP_MAX_H := 25.0

## What 2 to 4 hours a stage would take (NOT applied; data/BALANCE.md "Pacing audit"): growth per
## segment 2.0 -> 5.0 (data/traits/worm_rules.tres) and these stage thresholds (data/stages.tres).
## Sized from the measured adult seconds per segment at each stage so a stage is ~3.3 h.
const PROPOSAL_GROWTH := 5.0
const PROPOSAL_THRESHOLDS := [0, 0, 411, 894, 1449, 2116, 2873, 2890]


static func line(p: Dictionary, seed_value: int, rec: PacingSim.Recorder) -> String:
	var st := []
	for s in rec.stage_at:
		if s > 1:
			st.append("s%d %.1f min" % [s, rec.stage_at[s] / 60.0])
	return "pacing %s seed %d: eaten median %.0f s worst %.0f s | food median %.0f s worst %.0f s | new median %.0f s worst %.0f s | %s" % [
		p.name, seed_value, rec.median(&"eaten"), rec.worst(&"eaten"), rec.median(&"food"),
		rec.worst(&"food"), rec.median(&"new"), rec.worst(&"new"), ", ".join(st)]


## Stage 1 (the dirt), both profiles, five seeds: a segment at least every 2 minutes, worst case.
func test_stage_one_grows_a_segment_at_least_every_two_minutes() -> void:
	for p in [PacingSim.KID, PacingSim.ADULT]:
		for sd in SEEDS:
			var rec := PacingSim.new(p, sd).run(2)
			print(line(p, sd, rec))
			assert_float(rec.worst(&"eaten")).override_failure_message(line(p, sd, rec)).is_less_equal(SEGMENT_EVERY_S)


## Stage 1: something new (a first taste, a trait, the stage-up) at least every 15 minutes.
func test_stage_one_shows_something_new_at_least_every_fifteen_minutes() -> void:
	for p in [PacingSim.KID, PacingSim.ADULT]:
		for sd in SEEDS:
			var rec := PacingSim.new(p, sd).run(2)
			assert_float(rec.worst(&"new")).override_failure_message(line(p, sd, rec)).is_less_equal(NEW_EVERY_S)
			assert_bool(rec.stage_at.has(2)).is_true()


## The whole disk, stage 1 to the chomp (stage 6): both rules hold at every stage.
func test_every_stage_keeps_both_kid_rules() -> void:
	for p in [PacingSim.KID, PacingSim.ADULT]:
		for sd in [1, 2, 3]:
			var rec := PacingSim.new(p, sd).run(6)
			print(line(p, sd, rec))
			assert_bool(rec.stage_at.has(6)).is_true()
			assert_float(rec.worst(&"eaten")).override_failure_message(line(p, sd, rec)).is_less_equal(SEGMENT_EVERY_S)
			assert_float(rec.worst(&"new")).override_failure_message(line(p, sd, rec)).is_less_equal(NEW_EVERY_S)


## Same seed, same run: the numbers in handoff/pacing.md can be re-made.
func test_a_seed_replays_the_same_run() -> void:
	var a := PacingSim.new(PacingSim.KID, 4).run(3)
	var b := PacingSim.new(PacingSim.KID, 4).run(3)
	assert_array(a.times[&"eaten"]).is_equal(b.times[&"eaten"])
	assert_array(a.labels).is_equal(b.labels)


## The log is fed by signals: one "eaten" per segment_added, one "new" per first taste, and a
## stage-up logs a "new" with its ring or look.
func test_the_log_follows_the_signals() -> void:
	var sim := PacingSim.new(PacingSim.KID, 1)
	var rec := PacingSim.Recorder.new(sim)
	var pebble: FoodData = load("res://data/foods/pebble.tres")
	sim.clock = 10.0
	sim._taste(pebble)
	sim.clock = 20.0
	sim._taste(pebble)
	assert_int(rec.times[&"food"].size()).is_equal(2)
	assert_int(rec.labels.filter(func(s: String) -> bool: return s.begins_with("food pebble")).size()).is_equal(1)
	var before: int = rec.times[&"eaten"].size()
	sim.model.add_growth(sim.rules.growth_per_segment, &"root")
	assert_int(rec.times[&"eaten"].size()).is_equal(before + 1)
	sim.model.start_at_stage(2)
	assert_bool(rec.labels.any(func(s: String) -> bool: return s.begins_with("stage 2 (topsoil)"))).is_true()


## Food is met only in rings the stage has opened: stage 1 eats the dirt only.
func test_stage_one_meets_only_dirt_food() -> void:
	var sim := PacingSim.new(PacingSim.ADULT, 2)
	var rings := sim.open_rings(1)
	assert_array(rings).contains_exactly([&"dirt"])
	var rec := sim.run(2)
	for l in rec.labels:
		if l.begins_with("food "):
			var id := l.get_slice(" ", 1)
			var f: FoodData = load("res://data/foods/%s.tres" % id)
			assert_str(String(PacingSim.ring_of(f))).is_equal("dirt")


## The budget math for Kaden's 2 to 4 hours a stage, 15 to 25 to the chomp, on the PROPOSAL (not
## dev's data): an adult with intent spends 2 to 4 h in every stage 1 to 5 and 15 to 25 h to the
## chomp, and the kid still grows a segment at least every 2 minutes. It also prints the worst
## wait for something new, which the proposal breaks (no content spreads over those hours): the
## reason it is a proposal and not applied (data/BALANCE.md "Pacing audit").
func test_the_two_to_four_hour_proposal_fits_the_stage_budget() -> void:
	var r := PacingSim.rules_with(PROPOSAL_GROWTH, PackedInt32Array(PROPOSAL_THRESHOLDS))
	for sd in [1, 2, 3]:
		var rec := PacingSim.new(PacingSim.ADULT, sd, r).run(6)
		var at: Dictionary = rec.stage_at
		var hours := []
		for s in range(2, 7):
			assert_bool(at.has(s)).is_true()
			var h: float = (at[s] - at[s - 1]) / 3600.0
			hours.append("%.2f" % h)
			assert_float(h).override_failure_message("stage %d took %.2f h" % [s - 1, h]).is_between(STAGE_MIN_H, STAGE_MAX_H)
		var chomp: float = at[6] / 3600.0
		print("pacing proposal adult seed %d: stages %s h, chomp %.1f h, worst new %.0f min, segments %d" %
			[sd, ", ".join(hours), chomp, rec.worst(&"new") / 60.0, PROPOSAL_THRESHOLDS[6]])
		assert_float(chomp).is_between(CHOMP_MIN_H, CHOMP_MAX_H)
	for sd in [1, 2, 3]:
		var kid := PacingSim.new(PacingSim.KID, sd, r).run(2)
		print("pacing proposal kid seed %d: stage 1 %.1f h, eaten worst %.0f s, new worst %.0f min" %
			[sd, kid.end / 3600.0, kid.worst(&"eaten"), kid.worst(&"new") / 60.0])
		assert_float(kid.worst(&"eaten")).is_less_equal(SEGMENT_EVERY_S)


## Dev's real data against Kaden's chapter lengths, measured with the same driver (reported, the
## gap is Gary's pick): the first stage-up comes in minutes, not hours.
func test_dev_data_first_stage_up_is_reported() -> void:
	for p in [PacingSim.KID, PacingSim.ADULT]:
		var times := []
		for sd in SEEDS:
			times.append(PacingSim.new(p, sd).run(2).stage_at[2] / 60.0)
		times.sort()
		print("pacing first stage-up %s: median %.1f min, range %.1f to %.1f min (Kaden %.0f to %.0f h)" %
			[p.name, times[2], times[0], times[4], STAGE_MIN_H, STAGE_MAX_H])
		assert_float(times[0]).is_greater(0.0)


## D108 a: kid mode's timed new (scripts/gameplay/timed_new_clock.gd, TimedNew in the game). Its
## tolerance on the 12-minute paper number, in seconds.
const TIMED_TOLERANCE_S := 30.0
const ZERO_EAT_S := 2.0 * 3600.0
const PAUSE_AT_S := 3000.0
const PAUSE_S := 1800.0


static func timed_sim(p: Dictionary, sd: int) -> PacingSim:
	var sim := PacingSim.new(p, sd)
	sim.timed = true
	return sim


## Worst wait between "new" events from `from_s` to `to_s` (both ends count as edges).
static func worst_between(rec: PacingSim.Recorder, from_s: float, to_s: float) -> float:
	var last := from_s
	var worst := 0.0
	for t in rec.times[&"new"]:
		if float(t) <= from_s or float(t) > to_s:
			continue
		worst = maxf(worst, float(t) - last)
		last = float(t)
	return maxf(worst, to_s - last)


## 1. Kid driver, stage 1, zero eating for 2 h of play: the timed new alone keeps the worst wait
## for something new at 12 minutes (+ 0.5 min).
func test_timed_new_fills_two_hours_of_zero_eating() -> void:
	for sd in SEEDS:
		var sim := timed_sim(PacingSim.KID_ZERO_EAT, sd)
		var rec := sim.run(2, ZERO_EAT_S)
		var worst := rec.worst(&"new")
		print("timed new kid zero-eat seed %d: stage %d, %d timed looks, worst new %.1f min" %
			[sd, sim.model.stage, rec.times[&"timed"].size(), worst / 60.0])
		assert_int(sim.model.stage).is_equal(1)
		assert_float(rec.end).is_equal(ZERO_EAT_S)
		assert_int(rec.times[&"timed"].size()).is_greater_equal(9)
		assert_float(worst).is_less_equal(TimedNewClock.EVERY_S + TIMED_TOLERANCE_S)


## 2. The same driver with a 30-minute pause mid-stage: nothing fires in the pause, no burst on
## resume, and the first timed new after resume comes no earlier than 12 minutes after it.
func test_timed_new_has_no_burst_after_a_pause() -> void:
	var sim := timed_sim(PacingSim.KID_ZERO_EAT, 1)
	sim.pauses = [[PAUSE_AT_S, PAUSE_S]]
	var rec := sim.run(2, ZERO_EAT_S)
	var resume := PAUSE_AT_S + PAUSE_S
	var after: Array = rec.times[&"timed"].filter(func(t: float) -> bool: return t > PAUSE_AT_S)
	assert_bool(after.is_empty()).is_false()
	assert_bool(rec.times[&"timed"].any(func(t: float) -> bool: return t > PAUSE_AT_S and t <= resume)).is_false()
	print("timed new pause: resume at %.1f min, first timed after it %.1f min later" %
		[resume / 60.0, (float(after[0]) - resume) / 60.0])
	assert_float(float(after[0]) - resume).is_greater_equal(TimedNewClock.EVERY_S)
	for i in range(1, after.size()):
		assert_float(float(after[i]) - float(after[i - 1])).is_greater_equal(TimedNewClock.EVERY_S)
	# Before and after the pause the timed new still fills every gap.
	assert_float(worst_between(rec, 0.0, PAUSE_AT_S)).is_less_equal(TimedNewClock.EVERY_S + TIMED_TOLERANCE_S)
	assert_float(worst_between(rec, resume, rec.end)).is_less_equal(TimedNewClock.EVERY_S + TIMED_TOLERANCE_S)


## 3. Kid driver with the timed new on, stages 1 to 4: worst wait for something new per stage
## (measured, printed for the report), at most 15 minutes in stages 2 to 4.
func test_timed_new_keeps_stages_two_to_four_under_fifteen_minutes() -> void:
	var worst_by_stage := { 1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0 }
	for sd in SEEDS:
		var rec := timed_sim(PacingSim.KID, sd).run(5)
		assert_bool(rec.stage_at.has(5)).is_true()
		var row := []
		for s in range(1, 5):
			var w := worst_between(rec, rec.stage_at[s], rec.stage_at[s + 1])
			worst_by_stage[s] = maxf(worst_by_stage[s], w)
			row.append("s%d %.1f" % [s, w / 60.0])
		print("timed new kid seed %d: worst new per stage (min) %s, %d timed looks" %
			[sd, ", ".join(row), rec.times[&"timed"].size()])
		for s in range(2, 5):
			assert_float(worst_between(rec, rec.stage_at[s], rec.stage_at[s + 1])).override_failure_message(
				"seed %d stage %d" % [sd, s]).is_less_equal(NEW_EVERY_S)
	print("timed new kid worst over seeds (min): s1 %.1f, s2 %.1f, s3 %.1f, s4 %.1f" %
		[worst_by_stage[1] / 60.0, worst_by_stage[2] / 60.0, worst_by_stage[3] / 60.0, worst_by_stage[4] / 60.0])


## 4. Timed news give zero growth: with them on, every stage-up comes at the same second as without
## (segments alone drive stage-up; tests/test_balance_stages.gd keeps its own times).
func test_timed_new_does_not_move_stage_up_times() -> void:
	for sd in [1, 2, 3]:
		var plain := PacingSim.new(PacingSim.KID, sd).run(5)
		var timed := timed_sim(PacingSim.KID, sd).run(5)
		assert_dict(timed.stage_at).is_equal(plain.stage_at)
		assert_array(timed.times[&"eaten"]).is_equal(plain.times[&"eaten"])
		assert_float(plain.worst(&"eaten")).is_less_equal(SEGMENT_EVERY_S)


## 5. Adult driver: the timed new never shows (count 0), the same runs as with it off.
func test_adult_driver_shows_no_timed_news() -> void:
	for sd in SEEDS:
		var rec := timed_sim(PacingSim.ADULT, sd).run(3)
		assert_int(rec.times[&"timed"].size()).is_equal(0)
		assert_bool(rec.labels.any(func(l: String) -> bool: return l.begins_with("timed look"))).is_false()


## What-if (NOT applied): on the 2 to 4 h proposal (data/BALANCE.md "Pacing audit"), where content
## alone leaves the kid hours without a new thing (worm-pacing-apply-2), the timed new keeps every
## kid stage 1 to 4 at most 12 minutes (+ 0.5) without something new. Printed for the report.
func test_timed_new_closes_the_proposal_kid_gap() -> void:
	var r := PacingSim.rules_with(PROPOSAL_GROWTH, PackedInt32Array(PROPOSAL_THRESHOLDS))
	for sd in [1, 2]:
		var sim := PacingSim.new(PacingSim.KID, sd, r)
		sim.timed = true
		var rec := sim.run(5)
		var row := []
		for s in range(1, 5):
			if not rec.stage_at.has(s + 1):
				break
			var w := worst_between(rec, rec.stage_at[s], rec.stage_at[s + 1])
			row.append("s%d %.1f" % [s, w / 60.0])
			assert_float(w).is_less_equal(TimedNewClock.EVERY_S + TIMED_TOLERANCE_S)
		print("timed new proposal kid seed %d: worst new per stage (min) %s, %d timed looks in %.1f h" %
			[sd, ", ".join(row), rec.times[&"timed"].size(), rec.end / 3600.0])
		assert_bool(rec.stage_at.has(5)).is_true()


## Worst wait between events of `kind` from `from_s` to `to_s` (both ends count as edges).
static func worst_kind_between(rec: PacingSim.Recorder, kind: StringName, from_s: float, to_s: float) -> float:
	var last := from_s
	var worst := 0.0
	for t in rec.times[kind]:
		if float(t) <= from_s or float(t) > to_s:
			continue
		worst = maxf(worst, float(t) - last)
		last = float(t)
	return maxf(worst, to_s - last)


## Kid mode (the kid driver with the timed new on, as the game runs it) keeps both kid rules in
## every stage 1 to 5, seeds 1 to 5: a segment at least every 2 minutes and something new at least
## every 15, counted per stage between the stage-up signals (not only over the whole run). Prints
## the per-stage worst and the adult's chomp time for handoff/pacing.md (worm-pacing-apply-4, D116).
func test_kid_mode_keeps_both_kid_rules_in_every_stage() -> void:
	for sd in SEEDS:
		var rec := timed_sim(PacingSim.KID, sd).run(6)
		assert_bool(rec.stage_at.has(6)).is_true()
		var row := []
		for s in range(1, 6):
			var a: float = rec.stage_at[s]
			var b: float = rec.stage_at[s + 1]
			var seg := worst_kind_between(rec, &"eaten", a, b)
			var new := worst_kind_between(rec, &"new", a, b)
			row.append("s%d seg %.0f s new %.1f min" % [s, seg, new / 60.0])
			assert_float(seg).override_failure_message("seed %d stage %d segment worst %.0f s" % [sd, s, seg]) \
				.is_less_equal(SEGMENT_EVERY_S)
			assert_float(new).override_failure_message("seed %d stage %d new worst %.1f min" % [sd, s, new / 60.0]) \
				.is_less_equal(NEW_EVERY_S)
		print("pacing kid mode seed %d: chomp %.1f min | %s" % [sd, rec.stage_at[6] / 60.0, "; ".join(row)])
		var adult := PacingSim.new(PacingSim.ADULT, sd).run(6)
		print("pacing adult seed %d: chomp %.1f min (Kaden %.0f to %.0f h)" % [sd,
			adult.stage_at[6] / 60.0, CHOMP_MIN_H, CHOMP_MAX_H])
