## Every growth stage, 1 to 7 (data/stages.tres). Thresholds, zoom, size, edible class, feature id
## and slots are tuned here from playtests without code changes (S-14).
class_name StageTable
extends Resource

const PATH := "res://data/stages.tres"

## Index 0 = stage 1.
@export var stages: Array[StageData] = []

static var _default: StageTable


static func default_table() -> StageTable:
	if _default == null:
		_default = load(PATH)
	return _default


func max_stage() -> int:
	return stages.size()


## The row for a stage, clamped into 1..max_stage().
func at(stage: int) -> StageData:
	return stages[clampi(stage, 1, stages.size()) - 1]


## Highest stage whose segment threshold `segments` meets (the apex gate is WormGrowth's).
func stage_for(segments: int) -> int:
	var s := 1
	for d in stages:
		if segments >= d.segments:
			s = maxi(s, d.stage)
	return s


## First stage that breaks the crust (StageData.crust_ring); -1 when no stage does.
func crust_stage() -> int:
	for d in stages:
		if d.crust_ring != &"":
			return d.stage
	return -1


## The crust ring's id (&"" when no stage names one).
func crust_ring() -> StringName:
	var s := crust_stage()
	return at(s).crust_ring if s > 0 else &""


## A copy of `rings` whose crust ring is edible from crust_stage() and never regrows. Every other
## ring keeps its own values; the loaded RingSet (a shared cached resource) is never changed.
func apply_crust(rings: RingSet) -> RingSet:
	var id := crust_ring()
	if id == &"":
		return rings
	var out: RingSet = rings.duplicate()
	var list: Array[RingDef] = []
	for r in rings.rings:
		var c: RingDef = r
		if r.id == id:
			c = r.duplicate()
			c.edible_from = crust_stage()
			c.regrow_time = 0.0
		list.append(c)
	out.rings = list
	return out
