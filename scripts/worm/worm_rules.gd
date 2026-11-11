## Tuning for growth, stages, slots and base stats (data/traits/worm_rules.tres).
class_name WormRules
extends Resource

const PATH := "res://data/traits/worm_rules.tres"

## Growth that makes one segment (a plain food is 1.0).
@export var growth_per_segment := 2.0
## Segments a new worm starts with.
@export var start_segments := 3
## Index = stage: segments needed to reach it (index 0 unused, stage 1 = 0).
@export var stage_segments: PackedInt32Array = [0, 0, 6, 10, 15, 20, 24, 40]
## Index = stage: active trait slots (1 at stage 2 to 5 at stage 6).
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


func flavour_color(flavour: StringName, fallback := Color.WHITE) -> Color:
	return flavour_colors.get(flavour, fallback)


func find_trait(id: StringName) -> TraitData:
	for t in traits:
		if t.id == id:
			return t
	return null
