## Pacing audit (K-06, W-24, S-19): a seeded, scripted driver plays a worm through the stages on the
## real body model (WormGrowth), the real stage table, the real foods (data/foods) and the worm's
## code constants. It never polls a counter per frame: every "something eaten" and "something new"
## is a signal (WormGrowth.segment_added / trait_earned / stage_changed, and this driver's own
## `tasted` / `first_taste`), and a Recorder on those signals keeps the clock of each.
##   var sim := PacingSim.new(PacingSim.KID, 3)
##   var rec := sim.run(2)        # play until the first stage-up
##   rec.gaps(&"eaten"), rec.gaps(&"new")
## Profiles match data/BALANCE.md (and tests/test_balance_stages.gd).
class_name PacingSim
extends RefCounted

## A food was eaten (any kind).
signal tasted(food_id: StringName)
## A food kind was eaten for the first time in this run.
signal first_taste(food_id: StringName)

const FOODS_DIR := "res://data/foods/"
const TILE_PX := 16.0
const MAX_HOURS := 60.0
const KID := { "name": "kid", "dig": 0.35, "foods_min": 0.6, "apex_min": 8.0, "eaten_min": 9.0 }
const ADULT := { "name": "adult", "dig": 0.6, "foods_min": 1.5, "apex_min": 4.0, "eaten_min": 0.0 }

var profile: Dictionary
var rules: WormRules
var model: WormGrowth
var rng := RandomNumberGenerator.new()
## Seconds since the run started (one step = one second of play).
var clock := 0.0
var menu: Array[FoodData] = []
var _tasted := {}


## One event log: kind -> times in seconds. Kinds: &"eaten" (a segment grew), &"food" (a food was
## eaten), &"new" (a first taste, a trait, a stage with its new ring or look). `labels` keeps what
## each "new" was, for the report.
class Recorder:
	extends RefCounted
	var sim: PacingSim
	var times := { &"eaten": [], &"food": [], &"new": [] }
	var labels: Array[String] = []
	var stage_at := { 1: 0.0 }
	var end := 0.0

	func _init(s: PacingSim) -> void:
		sim = s
		s.model.segment_added.connect(func(_f: StringName) -> void: _log(&"eaten"))
		s.tasted.connect(func(_id: StringName) -> void: _log(&"food"))
		s.first_taste.connect(func(id: StringName) -> void: _new("food " + String(id)))
		s.model.trait_earned.connect(func(id: StringName, _eq: bool) -> void: _new("trait " + String(id)))
		s.model.stage_changed.connect(_on_stage)

	func _log(kind: StringName) -> void:
		(times[kind] as Array).append(sim.clock)

	func _new(what: String) -> void:
		_log(&"new")
		labels.append("%s @%.0fs" % [what, sim.clock])

	func _on_stage(_from: int, to: int) -> void:
		stage_at[to] = sim.clock
		var d := sim.rules.stage_info(to)
		_new("stage %d (%s)" % [to, String(d.opens_ring) if d.opens_ring != &"" else String(d.feature_id)])

	## Waits between events of a kind, counted from the start of the run to the first one, and
	## from the last one to the end of the run (so a long quiet tail is a gap too).
	func gaps(kind: StringName) -> Array[float]:
		var out: Array[float] = []
		var last := 0.0
		for t in times[kind]:
			out.append(float(t) - last)
			last = float(t)
		if end - last > 0.0:
			out.append(end - last)
		return out

	func worst(kind: StringName) -> float:
		var g := gaps(kind)
		return g.max() if not g.is_empty() else INF

	func median(kind: StringName) -> float:
		var g := gaps(kind)
		if g.is_empty():
			return INF
		g.sort()
		var n := g.size()
		return g[n / 2] if n % 2 == 1 else (g[n / 2 - 1] + g[n / 2]) * 0.5


static func all_foods() -> Array[FoodData]:
	var out: Array[FoodData] = []
	var files := DirAccess.get_files_at(FOODS_DIR)
	files.sort()
	for f in files:
		if f.ends_with(".tres"):
			var r = load(FOODS_DIR + f)
			if r is FoodData:
				out.append(r)
	return out


## Tiles a worm of this stage swallows per second while tunnelling new ground (BALANCE.md).
static func tiles_per_s(r: WormRules, stage: int) -> float:
	var size := r.stage_info(stage).size
	var speed := float(r.base_stats.get("speed", 80.0)) * float(r.base_stats.get("dig_speed", Worm.DIG_SPEED))
	return speed * 2.0 * Worm.BITE_RADIUS * size / (TILE_PX * TILE_PX)


## Rules with a different growth per segment and stage thresholds, for "what if" budget runs; the
## real data is never touched. thresholds: index = stage (0 and 1 unused), like stage_segments.
static func rules_with(growth_per_segment: float, thresholds: PackedInt32Array) -> WormRules:
	var base := WormRules.default_rules()
	var r: WormRules = base.duplicate()
	var table: StageTable = base.stages.duplicate(true)
	for d in table.stages:
		if d.stage < thresholds.size() and d.stage > 1:
			d.segments = thresholds[d.stage]
	r.stages = table
	r.growth_per_segment = growth_per_segment
	return r


func _init(p: Dictionary, seed_value: int, r: WormRules = null) -> void:
	profile = p
	rng.seed = seed_value
	rules = r if r != null else WormRules.default_rules()
	model = WormGrowth.new(rules)
	model.apex_gate = true
	menu = all_foods()


## The rings open to a worm at this stage: every ring a stage up to it opened, and the crust ring
## from the crust stage on. Foods are met only there (stage 1: the dirt).
func open_rings(stage: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for s in range(1, stage + 1):
		var d := rules.stage_info(s)
		if d.opens_ring != &"":
			out.append(d.opens_ring)
		if d.crust_ring != &"":
			out.append(d.crust_ring)
	return out


## The ring a food lives in (RingFood.ring; a plain FoodData is met everywhere: &"").
static func ring_of(f: FoodData) -> StringName:
	return f.ring if f is RingFood else &""


## Plays until the worm reaches `until_stage` (or the hour cap) and returns the event log.
func run(until_stage := 2) -> Recorder:
	var rec := Recorder.new(self)
	var apex_wait := -1.0
	while model.stage < until_stage and clock < MAX_HOURS * 3600.0:
		clock += 1.0
		_step(apex_wait)
		if model.size_stage() > model.stage:
			if apex_wait < 0.0:
				apex_wait = rng.randf_range(0.5, 1.5) * float(profile.apex_min) * 60.0
			apex_wait -= 1.0
			if apex_wait <= 0.0:
				model.eat_apex(model.stage)
				apex_wait = -1.0
	rec.end = clock
	return rec


func _step(_apex_wait: float) -> void:
	var info := rules.stage_info(model.stage)
	if rng.randf() < float(profile.dig):
		model.add_growth(tiles_per_s(rules, model.stage) * model.stats.value("tile_growth", Worm.TILE_GROWTH), &"root")
	if rng.randf() < float(profile.foods_min) / 60.0:
		var rings := open_rings(model.stage)
		var here: Array[FoodData] = menu.filter(func(f: FoodData) -> bool: return ring_of(f) in rings)
		if not here.is_empty():
			var pick: FoodData = here[rng.randi() % here.size()]
			if pick.size_stage <= info.edible_size:   # too big: a bonk, nothing eaten
				_taste(pick)
	if float(profile.eaten_min) > 0.0 and rng.randf() < 1.0 / (float(profile.eaten_min) * 60.0):
		model.lose_segment()


func _taste(f: FoodData) -> void:
	var first := not _tasted.has(f.id)
	_tasted[f.id] = true
	model.add_growth(f.growth, f.flavour)
	tasted.emit(f.id)
	if first:
		first_taste.emit(f.id)
