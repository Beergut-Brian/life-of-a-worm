## The one resolver. Every modifier of every active trait stacks here, the same way:
##   value(stat) = (base + sum of adds) * product of muls
## Traits are sorted by id first, so the result never depends on equip order. Parts: per slot,
## the highest part_priority wins (ties: the lower id). No trait is a special case.
class_name WormStats
extends RefCounted

var _values := {}
## slot -> { "texture": Texture2D, "spin": float, "trait": StringName, "color": Color, "offset": Vector2 }
var parts := {}
## Active trait ids, sorted.
var active: Array[StringName] = []


static func resolve(traits: Array, base: Dictionary, stage := 1) -> WormStats:
	var s := WormStats.new()
	var sorted := traits.duplicate()
	sorted.sort_custom(func(a: TraitData, b: TraitData) -> bool: return String(a.id) < String(b.id))
	var sums := {}
	var prods := {}
	for k in base:
		sums[String(k)] = float(base[k])
	for t: TraitData in sorted:
		s.active.append(t.id)
		for k in t.add:
			sums[String(k)] = float(sums.get(String(k), 0.0)) + float(t.add[k])
		for k in t.mul:
			prods[String(k)] = float(prods.get(String(k), 1.0)) * float(t.mul[k])
	for k in prods:
		if not sums.has(k):
			sums[k] = 0.0
	for k in sums:
		s._values[k] = sums[k] * float(prods.get(k, 1.0))
	var best := {}
	for t: TraitData in sorted:
		var tex := t.part_texture(stage)
		if t.part_slot == &"" or tex == null:
			continue
		var cur: TraitData = best.get(t.part_slot)
		if cur == null or t.part_priority > cur.part_priority:
			best[t.part_slot] = t
	for slot in best:
		var t: TraitData = best[slot]
		s.parts[slot] = { "texture": t.part_texture(stage), "spin": t.part_spin, "trait": t.id, "color": t.color, "offset": t.part_offset }
	return s


func value(stat: String, default := 0.0) -> float:
	return _values.get(stat, default)


func has(stat: String) -> bool:
	return _values.has(stat)


func values() -> Dictionary:
	return _values.duplicate()
