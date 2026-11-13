## How the burrow grows with the worm (B-06): one row per stage, index 0 = stage 1. Data, not code:
## data/burrow/growth.tres. The room is where home counts (shelves, pets, sleep, keep zone); the
## chamber is what a stage-up carves round the bed. From house_stage the chamber is a cavern with a
## buried house in it, whose rooms hold trophies as furniture.
class_name BurrowGrowth
extends Resource

const PATH := "res://data/burrow/growth.tres"

## Room radius in tiles, per stage.
@export var room_tiles: PackedFloat32Array = [4.0, 5.5, 7.0, 8.5, 10.0, 11.5, 13.0]
## Chamber radius carved round the bed at a stage-up, in tiles, per stage.
@export var chamber_tiles: PackedFloat32Array = [2.0, 3.0, 4.0, 5.0, 6.5, 7.5, 8.5]
## Size of a picture on the burrow's trait wall, in world px, per stage (it grows with the room).
@export var picture_px: PackedFloat32Array = [9.0, 10.0, 12.0, 14.0, 18.0, 20.0, 22.0]
## The stage the buried house turns up (the chamber is a cavern from then on).
@export var house_stage := 5
## The house, in tiles: width x height (walls and roof included).
@export var house_tiles := Vector2(6.0, 4.0)
## Furniture spots in the house: rooms across x floors (each holds one trophy).
@export var house_rooms := 3
@export var house_floors := 2

static var _cached: BurrowGrowth


static func get_default() -> BurrowGrowth:
	if _cached == null:
		_cached = load(PATH) if ResourceLoader.exists(PATH) else BurrowGrowth.new()
	return _cached


func _row(a: PackedFloat32Array, stage: int) -> float:
	return a[clampi(stage - 1, 0, a.size() - 1)]


func room_for(stage: int) -> float:
	return _row(room_tiles, stage)


func chamber_for(stage: int) -> float:
	return _row(chamber_tiles, stage)


func picture_for(stage: int) -> float:
	return _row(picture_px, stage)


func has_house(stage: int) -> bool:
	return stage >= house_stage


func house_spots() -> int:
	return house_rooms * house_floors
