## Pacing audit, the outing scale (S-19, GAME.md "Core loop": an outing is 20 to 40 minutes and
## what pulls you on is a new trait, a filled page, a nicer burrow). The same seeded driver as
## tests/test_pacing_audit.gd (tests/pacing_sim.gd) logs every trait earned through
## WormGrowth.trait_earned (Recorder kind &"trait"), so the wait between new traits is the outing
## length the data gives. Reported for dev's data and for the 2-to-4-hour proposal; the targets are
## Gary's pick (Docket D105), so only the measuring is pinned here, never the values.
extends GdUnitTestSuite

const SEEDS := [1, 2, 3, 4, 5]
const OUTING_MIN := 20.0
const OUTING_MAX := 40.0


## Minutes between trait moments: traits earned in the same second (one bite can finish two
## recipes) are one moment, and the quiet tail to the end of the run counts as a wait too.
static func waits(rec: PacingSim.Recorder) -> Array:
	var out := []
	var last := 0.0
	for t in rec.times[&"trait"]:
		if out.is_empty() or float(t) > last:
			out.append((float(t) - last) / 60.0)
			last = float(t)
	if rec.end > last:
		out.append((rec.end - last) / 60.0)
	return out


static func median(a: Array) -> float:
	var g := a.duplicate()
	g.sort()
	var n := g.size()
	return g[n / 2] if n % 2 == 1 else (g[n / 2 - 1] + g[n / 2]) * 0.5


func test_every_trait_earned_is_logged_once_through_the_signal() -> void:
	var sim := PacingSim.new(PacingSim.ADULT, 1)
	var heard := [0]
	sim.model.trait_earned.connect(func(_id: StringName, _eq: bool) -> void: heard[0] += 1)
	var rec := sim.run(6)
	assert_int(heard[0]).is_greater(0)
	assert_int((rec.times[&"trait"] as Array).size()).is_equal(heard[0])
	assert_int((rec.times[&"trait"] as Array).size()).is_equal(sim.model.earned.size())
	# one entry per trait, in time order, inside the run
	var last := 0.0
	for t in rec.times[&"trait"]:
		assert_float(float(t)).is_greater_equal(last)
		last = float(t)
	assert_float(last).is_less_equal(rec.end)


func test_a_seed_replays_the_same_trait_clock() -> void:
	var a := PacingSim.new(PacingSim.KID, 4).run(4)
	var b := PacingSim.new(PacingSim.KID, 4).run(4)
	assert_array(a.times[&"trait"]).is_equal(b.times[&"trait"])


## Dev's data, both profiles, five seeds to the chomp: the wait for each new trait moment, reported
## against Kaden's 20 to 40 minute outing.
func test_dev_outing_length_is_reported() -> void:
	for p in [PacingSim.KID, PacingSim.ADULT]:
		var medians := []
		var worsts := []
		for sd in SEEDS:
			var rec := PacingSim.new(p, sd).run(6)
			var w := waits(rec)
			assert_array(w).is_not_empty()
			medians.append(median(w))
			worsts.append(w.max())
		medians.sort()
		worsts.sort()
		print("pacing outing %s (dev data): new trait median %.1f min (seeds %.1f to %.1f), worst %.1f min (Kaden %.0f to %.0f min)" %
			[p.name, medians[2], medians[0], medians[4], worsts[4], OUTING_MIN, OUTING_MAX])
		assert_float(medians[0]).is_greater(0.0)


## The same measure on the 2-to-4-hour proposal (test_pacing_audit.gd), so Gary sees what it does
## to the outing before picking it. Reported, never applied.
func test_proposal_outing_length_is_reported() -> void:
	var r := PacingSim.rules_with(load("res://tests/test_pacing_audit.gd").PROPOSAL_GROWTH,
		PackedInt32Array(load("res://tests/test_pacing_audit.gd").PROPOSAL_THRESHOLDS))
	var medians := []
	for sd in [1, 2, 3]:
		var rec := PacingSim.new(PacingSim.ADULT, sd, r).run(6)
		var w := waits(rec)
		medians.append(median(w))
		print("pacing outing adult (proposal) seed %d: new trait median %.1f min, worst %.1f min, %d traits" %
			[sd, median(w), w.max(), (rec.times[&"trait"] as Array).size()])
	assert_float(medians.min()).is_greater(0.0)
