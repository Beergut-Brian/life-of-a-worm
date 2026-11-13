## One kind of food (data/foods/*.tres). Content lane fills these; worm code only reads them.
class_name FoodData
extends Resource

@export var id: StringName
## The diet colour it paints a segment (`WormRules.flavour_colors`). &"" = plain.
@export var flavour: StringName
## Growth toward the next segment (`WormRules.growth_per_segment`).
@export var growth := 1.0
## Bigger eats smaller: edible when size_stage <= worm stage + bite_bonus/<flavour>.
@export var size_stage := 1
## Sprite colour of the pickup (placeholder art draws a blob in it).
@export var color := Color.WHITE
## Pickup radius in pixels (16 px = one stage-1 segment).
@export var radius := 5.0
## Its own sound when a worm swallows it, on top of the chomp (`FoodVoice`). "" = just the chomp.
@export var eat_cue := ""
