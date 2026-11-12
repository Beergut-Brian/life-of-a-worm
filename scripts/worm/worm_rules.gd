## Tuning for growth, stages, slots and base stats (data/traits/worm_rules.tres).
class_name WormRules
extends Resource

const PATH := "res://data/traits/worm_rules.tres"

## Growth that makes one segment (a plain food is 1.0).
@export var growth_per_segment := 2.0
## Segments a new worm starts with.
@export var start_segments := 3
## The stage rows (data/stages.tres). Setting it fills stage_segments and slots_per_stage below
## from the table, so pacing has one source; the arrays are only a fallback for bare test rules.
@export var stages: StageTable:
	set(v):
		stages = v
		if v != null and not v.stages.is_empty():
			var segs := PackedInt32Array([0])
			var sl := PackedInt32Array([0])
			for d in v.stages:
				segs.append(d.segments)
				sl.append(d.slots)
			stage_segments = segs
			slots_per_stage = sl
## Index = stage: segments needed to reach it (index 0 unused, stage 1 = 0). From `stages`.
@export var stage_segments: PackedInt32Array = [0, 0, 6, 10, 15, 20, 24, 40]
## Index = stage: active trait slots (1 at stage 2 to 5 at stage 6). From `stages`.
@export var slots_per_stage: PackedInt32Array = [0, 0, 1, 2, 3, 4, 5, 5]
## Every bite also grows the partner by this share of its growth.
@export_range(0.0, 1.0) var partner_share := 0.25
## Stat name -> base value before traits.
@export var base_stats: Dictionary = {}
## Flavour -> stripe colour.
@export var flavour_colors: Dictionary = {}
## Every trait that can be earned.
@export var traits: Array[TraitData] = []

static var _default: WormRules


static func default_rules() -> WormRules:
	if _default == null:
		_default = load(PATH)
	return _default


func max_stage() -> int:
	return stage_segments.size() - 1


func stage_for(segments: int) -> int:
	var s := 1
	for i in range(1, stage_segments.size()):
		if segments >= stage_segments[i]:
			s = i
	return s


func slots_for(stage: int) -> int:
	return slots_per_stage[clampi(stage, 0, slots_per_stage.size() - 1)]


## The stage's row (size, zoom, edible class, feature). Bare rules fall back to data/stages.tres.
func stage_info(stage: int) -> StageData:
	var t := stages if stages != null else StageTable.default_table()
	return t.at(stage)


## Does this stage wait for the apex creature of the ring below (data, per stage)?
func needs_apex(stage: int) -> bool:
	if stage < 2 or stage > max_stage():
		return false
	return stage_info(stage).needs_apex


func flavour_color(flavour: StringName, fallback := Color.WHITE) -> Color:
	return flavour_colors.get(flavour, fallback)


func find_trait(id: StringName) -> TraitData:
	for t in traits:
		if t.id == id:
			return t
	return null
