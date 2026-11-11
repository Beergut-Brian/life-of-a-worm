## A ring's food chain (data/rings/<ring>_life.tres): its species and the foods scattered in it.
class_name RingLife
extends Resource

@export var ring: StringName
@export var species: Array[PopulationRule] = []
## Statically scattered foods (they regrow where they were after RingFood.regrow_time).
@export var scatter: Array[RingFood] = []
@export var scatter_count := 0
