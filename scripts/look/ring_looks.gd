## The planet's look data (data/rings/looks.tres, Art lane): darkness and parallax per ring, the
## day/night cycle and rain up top, and which foods glow. Read by LookDirector.
class_name RingLooks
extends Resource

@export var rings: Array[RingLook] = []
## Planet seconds for one day and night (it runs on the planet clock, so it is saved with it).
@export var day_length := 600.0
## Light up top through the day (offset 0 = dawn, 0.25 noon, 0.6 dusk, 0.8 midnight).
@export var day_tint: Gradient
## Sky colours through the day: high sky and horizon.
@export var sky_top: Gradient
@export var sky_horizon: Gradient
## How dark the rain makes the top (multiplies the ambient) and how deep it soaks (tiles).
@export var rain_dim := 0.82
@export var soak_tiles := 10.0
## The worms' lanterns: colour (mixed with the worm's own colour), reach (texture scale per stage-1
## size) and energy.
@export var lantern := Color("ffe9c4")
@export_range(0.0, 1.0) var lantern_tint := 0.22
@export var lantern_scale := 2.4
@export var lantern_energy := 1.05
## Food id -> light colour (alpha = energy). Glowing food casts coloured light.
@export var glow: Dictionary[StringName, Color] = {}
@export var max_glows := 12
## Daylight through holes eaten in the crust.
@export var sun := Color("ffe2a8")
@export var max_shafts := 8
## Grass blade colours (dark, mid, tip) for the tile shader.
@export var grass: PackedColorArray = PackedColorArray()


func look_of(ring: StringName) -> RingLook:
	for r in rings:
		if r.ring == ring:
			return r
	return null
