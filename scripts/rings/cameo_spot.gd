## X-08: one spot kept empty for a later Jarling cameo (GAME.md "Jarling cameos"). Lives inside the
## placement data it belongs to: SecretData.cameos (a hidden place) or SurfaceLife.cameos (the grass).
## A cameo update fills `jarling` with a character id from assets/characters/ and CameoStands
## stands that character there; no code change. Empty (`&""`) = nothing stands there and nothing
## is drawn, so the spot looks like the ground round it.
class_name CameoSpot
extends Resource

## The spot's own name, unique across the planet (`<place>_<where>`). Never a character's name.
@export var id: StringName
## In a hidden place: tiles from the hall centre, x to the side, y up (away from the core), the
## same axes as SecretData.rooms. Unused on the surface.
@export var at := Vector2.ZERO
## On the surface: radians from the start (like PropData.angles). Unused in a hidden place.
@export var angle := 0.0
## The Jarling who stands here (an assets/characters/<id>/ folder), &"" = empty, as at launch.
@export var jarling: StringName = &""


func is_empty() -> bool:
	return jarling == &""
