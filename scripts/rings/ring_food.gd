## A dirt or topsoil food (data/foods/*.tres): the FoodData the worm reads, plus what the living
## rings need. Worm code only sees the FoodData part (flavour, growth, size_stage, colour, radius).
class_name RingFood
extends FoodData

enum Look { BLOB, SEED, ROOT, MUSHROOM, CRUMB, HONEYDEW, EGG, PEBBLE }

## The ring it lives in (RingDef.id): where it is scattered and spawned.
@export var ring: StringName
## Planet seconds before an eaten one grows back where it was (statically placed foods).
@export var regrow_time := 120.0
## Carried and dropped in castings it plants a garden of this flavour (RingSet.garden_tiles); &"" = no.
@export var plants: StringName
## How the placeholder draws it (the face is always there; it goes wide-eyed near a bigger worm).
@export var look := Look.BLOB
## Second colour (cap of a mushroom, crust of a crumb, shine of honeydew).
@export var accent := Color.WHITE
