## How one ring is lit and what lies behind it (look B). One per ring in data/rings/looks.tres.
class_name RingLook
extends Resource

@export var ring: StringName
## Ambient light (CanvasModulate) at the top and the bottom of the ring: darkness per ring.
@export var ambient_top := Color.WHITE
@export var ambient_bottom := Color.WHITE
## 0..1: how much the day/night tint reaches this ring (topsoil 1, dirt a little, deeper 0).
@export_range(0.0, 1.0) var daylight := 0.0
## Soil parallax behind the ring: far dark (two shades), mid roots and stones, near silhouettes.
@export var far_dark := Color.BLACK
@export var far_light := Color.BLACK
@export var mid := Color.BLACK
@export var near := Color.BLACK
@export var near_edge := Color.BLACK
