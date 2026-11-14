## A ring's food chain (data/rings/<ring>_life.tres): its species and the foods scattered in it.
class_name RingLife
extends Resource

@export var ring: StringName
@export var species: Array[PopulationRule] = []
## Statically scattered foods (they regrow where they were after RingFood.regrow_time).
@export var scatter: Array[RingFood] = []
@export var scatter_count := 0
## Foods added after tins were already saved (D105 content): placed after every other static, so an
## older tin keeps its statics in their slots. Same rules as `scatter` otherwise.
@export var late_scatter: Array[RingFood] = []
@export var late_scatter_count := 0
## Visible events of this ring (RingEvent): a root pocket bursting, seeds blowing down, a fairy ring.
@export var events: Array[RingEvent] = []
