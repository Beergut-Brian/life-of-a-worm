## One hidden place (data/secrets/*.tres): where it is, its unique food, its tackle-box page.
class_name SecretData
extends Resource

@export var id: StringName
@export var ring: StringName
## Where it is on the planet: angle from the start (radians, + = clockwise on screen) and depth
## as a fraction of the planet radius.
@export var angle_from_start := 0.3
@export var depth := 0.66
## Size of the main hall in tiles.
@export var radius_tiles := 6.0
## Its unique food (data/foods/<food>.tres), how many sit in it.
@export var food: StringName
@export var food_count := 5
## The tackle-box page it fills (Tackle lane reads this).
@export var page: StringName
@export var cue := "secret_found"
