## Diet-stripe colours: one per flavour (GAME.md Depth systems 1). WormLook.flavour_tint() reads it;
## the band sprite is neutral-light, so `modulate = tint` gives a shaded stripe in the flavour colour.
class_name FlavourPalette
extends Resource

@export var colors: Dictionary = {}
## Used for a flavour that has no colour yet.
@export var fallback := Color.WHITE


func tint(flavour: StringName) -> Color:
	return colors.get(flavour, fallback)


func ids() -> Array:
	return colors.keys()
