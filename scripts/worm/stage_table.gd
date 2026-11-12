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
