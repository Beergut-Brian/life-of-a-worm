## The balance sheet (data/BALANCE.md), recomputed. Seeded simulated runs over dev's stage table
## (data/stages.tres through WormRules), the real body model (WormGrowth + WormStats), the real foods
## (data/foods) and the worm's own code constants (Worm.TILE_GROWTH, BITE_RADIUS, DIG_SPEED). No
## number in here is a copy of the data: change the data and the printed sheet changes with it.
## Profiles and targets: data/BALANCE.md. Kaden's chapter lengths are printed, not asserted: the
## gap is in BALANCE.md under "Gary's pick needed".
extends GdUnitTestSuite

const FOODS_DIR := "res://data/foods/"
const BALANCE := "res://data/BALANCE.md"
const TILE_PX := 16.0

## Who is playing: share of seconds spent tunnelling new ground, foods met a minute, minutes to
## find and eat the apex once big enough, minutes between being eaten (0 = never).
const KID := { "name": "kid", "dig": 0.35, "foods_min": 0.6, "apex_min": 8.0, "eaten_min": 9.0 }
const ADULT := { "name": "adult", "dig": 0.6, "foods_min": 1.5, "apex_min": 4.0, "eaten_min": 0.0 }
const MAX_HOURS := 40.0
## Kaden (GAME.md, 2026-11-10): 2 to 4 hours a stage, 15 to 25 hours to the chomp.
const KADEN_STAGE_MIN_H := 2.0
const KADEN_CHOMP_MIN_H := 15.0


static func foods() -> Array[FoodData]:
	var out: Array[FoodData] = []
	for f in DirAccess.get_files_at(FOODS_DIR):
		if f.ends_with(".tres"):
			var r = load(FOODS_DIR + f)
			if r is FoodData:
				out.append(r)
	return out


## Tiles a worm of this stage swallows per second while tunnelling new ground: its base speed
## slowed by digging, through a bite 2 * BITE_RADIUS * size wide, on 16 px tiles.
static func tiles_per_s(rules: WormRules, stage: int) -> float:
	var size := rules.stage_info(stage).size
	var speed := float(rules.base_stats.get("speed", 80.0)) * float(rules.base_stats.get("dig_speed", Worm.DIG_SPEED))
	return speed * 2.0 * Worm.BITE_RADIUS * size / (TILE_PX * TILE_PX)


## One run: { stage_at: {stage: seconds}, mean_segment: s, max_gap: s, stage, segments, end }.
static func simulate(profile: Dictionary, seed_value: int, until_stage := 6) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rules := WormRules.default_rules()
	var m := WormGrowth.new(rules)
	m.apex_gate = true
	var menu := foods()
	var seg_times: Array[float] = []
	var stage_at := { 1: 0.0 }
	var clock := [0.0]   # lambdas capture locals by value: share the clock through an array
	var t := 0.0
	var last_progress := 0.0
	var max_gap := 0.0
	var apex_wait := -1.0
	m.segment_added.connect(func(_f: StringName) -> void: seg_times.append(clock[0]))
	m.stage_changed.connect(func(_a: int, to: int) -> void: stage_at[to] = clock[0])
	var n_seg := m.segments.size()
	var n_stage := m.stage
	while m.stage < until_stage and t < MAX_HOURS * 3600.0:
		t += 1.0
		clock[0] = t
		var info := rules.stage_info(m.stage)
		if rng.randf() < profile.dig:
			m.add_growth(tiles_per_s(rules, m.stage) * m.stats.value("tile_growth", Worm.TILE_GROWTH), &"root")
		if rng.randf() < profile.foods_min / 60.0:
			var pick: FoodData = menu[rng.randi() % menu.size()]
			if pick.size_stage <= info.edible_size:
				m.add_growth(pick.growth, pick.flavour)
		if profile.eaten_min > 0.0 and rng.randf() < 1.0 / (profile.eaten_min * 60.0):
			m.lose_segment()
		if m.size_stage() > m.stage:
			if apex_wait < 0.0:
				apex_wait = rng.randf_range(0.5, 1.5) * profile.apex_min * 60.0
			apex_wait -= 1.0
			if apex_wait <= 0.0:
				m.eat_apex(m.stage)
				apex_wait = -1.0
		if m.segments.size() > n_seg or m.stage > n_stage:
			max_gap = maxf(max_gap, t - last_progress)
			last_progress = t
		n_seg = m.segments.size()
		n_stage = m.stage
	var gaps: Array[float] = []
	for i in range(1, seg_times.size()):
		gaps.append(seg_times[i] - seg_times[i - 1])
	return { "stage_at": stage_at, "max_gap": max_gap, "end": t, "mean_segment": _mean(gaps),
		"segments": m.segments.size(), "stage": m.stage }


static func _mean(a: Array[float]) -> float:
	if a.is_empty():
		return INF
	var s := 0.0
	for x in a:
		s += x
	return s / a.size()


static func report(profile: Dictionary, r: Dictionary) -> String:
	var parts := []
	var at: Dictionary = r.stage_at
	for s in range(2, 7):
		if at.has(s):
			parts.append("s%d %.0f min (+%.0f)" % [s, at[s] / 60.0, (at[s] - at.get(s - 1, 0.0)) / 60.0])
	return "balance %s: %s | segment every %.0f s | longest wait for progress %.0f s" % [profile.name,
		", ".join(parts), r.mean_segment, r.max_gap]


## The "numbers" table of BALANCE.md, one row per stage, built from the data and code constants.
static func sheet_rows() -> PackedStringArray:
	var rules := WormRules.default_rules()
	var table := rules.stages
	var out := PackedStringArray()
	for s in range(1, table.max_stage() + 1):
		var d := table.at(s)
		var opens := String(d.opens_ring) if d.opens_ring != &"" else "-"
		if d.crust_ring != &"":
			opens += " + " + String(d.crust_ring) + " (crust)"
		out.append("| %d | %d | %.2f | %.1f | %d | %d | %d | %s | %s | %s |" % [s, rules.stage_segments[s],
			d.size, d.collision_radius, d.zoom_index, d.edible_size, rules.slots_for(s), opens,
			String(d.feature_id) if d.feature_id != &"" else "-", "disk" if d.in_disk else "scripted"])
	return out


func test_seeded_time_to_each_stage_prints_and_is_repeatable() -> void:
	for p in [KID, ADULT]:
		var a := simulate(p, 7)
		var b := simulate(p, 7)
		print(report(p, a))
		assert_dict(a.stage_at).is_equal(b.stage_at)
		assert_int(a.stage).is_equal(6)   # both profiles reach the planet chomp inside the run cap


## Kid check: ordinary eating adds a segment at least every 2 minutes on average, and a 5-year-old
## never goes ten minutes without something growing (a segment or a stage), at any stage.
func test_a_kid_sees_progress_in_any_ten_minutes() -> void:
	for s in [1, 2, 3]:
		var r := simulate(KID, s)
		assert_float(r.mean_segment).is_less_equal(120.0)
		assert_float(r.max_gap).is_less_equal(600.0)


## Each stage is reached, in order, and none is a blink (a stage-up never chains into the next one
## inside a minute for an adult with intent).
func test_every_stage_is_reached_in_order() -> void:
	var r := simulate(ADULT, 3)
	var at: Dictionary = r.stage_at
	for s in range(2, 7):
		assert_bool(at.has(s)).is_true()
		assert_float(at[s] - at[s - 1]).is_greater_equal(60.0)


## Kaden's chapter lengths, measured and printed (not asserted: the gap is Gary's pick, BALANCE.md).
func test_chapter_lengths_against_kaden_are_reported() -> void:
	var r := simulate(ADULT, 7)
	var at: Dictionary = r.stage_at
	var shortest := INF
	for s in range(2, 7):
		shortest = minf(shortest, (at[s] - at[s - 1]) / 3600.0)
	print("balance chapters: adult shortest stage %.2f h (Kaden %.0f h+), to the chomp %.2f h (Kaden %.0f h+)" %
		[shortest, KADEN_STAGE_MIN_H, at[6] / 3600.0, KADEN_CHOMP_MIN_H])
	assert_float(at[6]).is_greater(0.0)


## The sheet in data/BALANCE.md matches the data: every row the table and code give is in the file.
func test_the_sheet_in_balance_md_matches_the_data() -> void:
	var doc := FileAccess.get_file_as_string(BALANCE)
	assert_str(doc).is_not_empty()
	for row in sheet_rows():
		print(row)
		assert_bool(doc.contains(row)).override_failure_message("BALANCE.md is stale, missing: " + row).is_true()
	assert_bool(doc.contains("| tile growth per tile | %s |" % str(Worm.TILE_GROWTH))).is_true()
	assert_bool(doc.contains("| growth per segment | %s |" % str(WormRules.default_rules().growth_per_segment))).is_true()
