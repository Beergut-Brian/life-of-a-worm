## A trait (data/traits/*.tres): earned by filling segments of flavours, felt through modifiers,
## seen as a part on the worm. Worm code never names a trait; every effect goes through WormStats.
class_name TraitData
extends Resource

@export var id: StringName
## flavour -> filled segments needed. Two flavours = a hybrid. All must be met at once.
@export var requires: Dictionary = {}
## stat -> number added to the base (summed over active traits).
@export var add: Dictionary = {}
## stat -> factor (multiplied over active traits, after the adds).
@export var mul: Dictionary = {}
## Where the part sits: head, crown, back, tail, skin. &"" = no part.
@export var part_slot: StringName
## One texture per stage (index stage - 1); the last one repeats for later stages.
@export var part_textures: Array[Texture2D] = []
## Two parts in one slot: the higher priority shows (a hybrid head beats its base head).
@export var part_priority := 0
## Turns per second for a spinning part (0 = still).
@export var part_spin := 0.0
## Signature sound (reveal sting), a cue name for Audio.play.
@export var cue := ""
## Picture colour on the trait wall and the reveal flash.
@export var color := Color.WHITE


func is_hybrid() -> bool:
	return requires.size() >= 2


func part_texture(stage: int) -> Texture2D:
	if part_textures.is_empty():
		return null
	return part_textures[clampi(stage - 1, 0, part_textures.size() - 1)]
