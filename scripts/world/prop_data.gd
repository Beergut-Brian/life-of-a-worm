## W-11: one kind of surface prop (data/props/*.tres): a multi-tile object standing on the
## surface that a big enough worm bites into edible chunks. SurfaceProp reads it; the Content lane
## fills more of these.
class_name PropData
extends Resource

@export var id: StringName
## Footprint in tiles (width along the ground, height away from the core).
@export var size := Vector2i(2, 2)
## Lantern tile-art row each cell is drawn with (assets/sprites/tiles/lantern_tiles.json solid_rows).
@export var tile: StringName = &"clay"
## Bites to break it. Every bite cracks it and knocks one chunk out.
@export_range(1, 20) var hits := 3
## Its size on the stage rule (StageRule / World.is_edible_by): a worm of a bigger stage bites it,
## a worm this size or smaller bonks off.
@export_range(1, 7) var size_stage := 4
## The food the chunks are.
@export var chunk: FoodData
## Chunks in all: one per bite, the rest burst out on the breaking bite.
@export_range(1, 20) var chunks := 4
## Where it stands: radians round the planet from the start point (one prop per entry).
@export var angles := PackedFloat32Array()
