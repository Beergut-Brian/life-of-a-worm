## Space backdrop: navy fill and seeded stars in a few sizes; `parallax` < 1 drifts slower than the camera.
class_name Starfield
extends Node2D

@export var extent := Vector2(6000, 4000)
@export var count := 700
@export var star_seed := 7
@export var parallax := 1.0

var _stars: Array = []


func _ready() -> void:
	z_index = -10
	var rng := RandomNumberGenerator.new()
	rng.seed = star_seed
	for i in count:
		_stars.append([Vector2(rng.randf_range(-extent.x, extent.x), rng.randf_range(-extent.y, extent.y)),
				[3.0, 3.0, 3.0, 6.0, 9.0][rng.randi() % 5], rng.randf_range(0.4, 1.0)])


func _process(_delta: float) -> void:
	if parallax != 1.0:
		var cam := get_viewport().get_camera_2d()
		if cam:
			position = cam.get_screen_center_position() * (1.0 - parallax)


func _draw() -> void:
	draw_rect(Rect2(-extent * 1.5, extent * 3.0), Color("141a3c"))
	for s in _stars:
		var c := Color(1, 1, 0.9, s[2])
		draw_rect(Rect2(s[0] - Vector2.ONE * s[1] / 2.0, Vector2.ONE * s[1]), c)
