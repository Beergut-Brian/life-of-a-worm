## The living rings' counters (GAME.md Depth 4): one number per species, stepped on the planet
## clock with the PopulationRule rates. Nothing is simulated outside these numbers; the director
## spawns a few live bodies from them into the chunks round the worms. Deterministic: the same
## rules, steps and kills always give the same numbers (an optional seeded wobble for variety).
class_name RingEcology
extends RefCounted

var rules: Dictionary[StringName, PopulationRule] = {}
var counts: Dictionary[StringName, float] = {}
## Seconds simulated so far (planet time).
var time := 0.0
## 0 = smooth; > 0 adds a seeded +-wobble share to each birth term.
var wobble := 0.0
var _rng := RandomNumberGenerator.new()
var _order: Array[StringName] = []


static func from_lives(lives: Array, seed_value := 1) -> RingEcology:
	var e := RingEcology.new()
	e._rng.seed = seed_value
	for life in lives:
		for r: PopulationRule in life.species:
			e.rules[r.id] = r
			e.counts[r.id] = r.start
			e._order.append(r.id)
	return e


func count(id: StringName) -> float:
	return counts.get(id, 0.0)


func ring_of(id: StringName) -> StringName:
	return rules[id].ring if rules.has(id) else &""


## Counters grouped by ring: {ring: {species: count}} (the save and the debug overlay).
func by_ring() -> Dictionary:
	var out := {}
	for id in _order:
		var r: StringName = rules[id].ring
		if not out.has(r):
			out[r] = {}
		out[r][id] = counts[id]
	return out


## Something (a worm) ate n of them.
func kill(id: StringName, n: float) -> void:
	if counts.has(id):
		counts[id] = maxf(0.0, counts[id] - n)


## Advance dt planet seconds (in steps of at most 1 s, so big catch-ups stay stable).
func step(dt: float) -> void:
	while dt > 0.0:
		var h := minf(dt, 1.0)
		_step(h)
		dt -= h
		time += h


func _step(h: float) -> void:
	var d: Dictionary[StringName, float] = {}
	for id in _order:
		d[id] = rules[id].immigration
	for id in _order:
		var r := rules[id]
		var n: float = counts[id]
		var room := maxf(0.0, 1.0 - n / maxf(r.capacity, 0.001))
		if r.plant:
			d[id] += r.growth_rate * n * room * _jiggle()
		else:
			d[id] -= r.death * n
		for prey: StringName in r.eats:
			if not counts.has(prey):
				continue
			var p: float = counts[prey]
			var intake: float = r.eats[prey] * n * p / (p + r.half_sat)
			d[prey] -= intake
			if not r.plant:
				d[id] += r.efficiency * intake * room * _jiggle()
	for id in _order:
		counts[id] = maxf(0.0, counts[id] + d[id] * h)


func _jiggle() -> float:
	return 1.0 if wobble <= 0.0 else 1.0 + _rng.randf_range(-wobble, wobble)


func to_dict() -> Dictionary:
	var c := {}
	for id in counts:
		c[String(id)] = snappedf(counts[id], 0.001)
	return { "time": time, "counts": c }


func from_dict(data: Dictionary) -> void:
	time = float(data.get("time", 0.0))
	var c: Dictionary = data.get("counts", {})
	for k in c:
		if counts.has(StringName(k)):
			counts[StringName(k)] = float(c[k])
