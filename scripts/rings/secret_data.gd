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
## The worm stage whose bite RingsDirector carves the hall with (2 for dirt; 4 to open the rock).
@export var carve_stage := 2
## Side rooms off the main hall: x = tiles to the side, y = tiles up (away from the core),
## z = room radius in tiles. Each is carved and kept like the hall. Default: the ant city's three.
@export var rooms := PackedVector3Array([Vector3(9, 2, 2.6), Vector3(-9, 1, 2.6), Vector3(0, -6, 2.6)])
## One more food set in the first side room (&"" = none). The ant city keeps a bug egg there.
@export var extra_food: StringName = &"bug_egg"
