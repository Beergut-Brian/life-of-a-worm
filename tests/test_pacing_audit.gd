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
