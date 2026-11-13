## Space backdrop: navy fill and seeded stars in a few sizes; `parallax` < 1 drifts slower than the camera.
## The stars tile every 2 x extent and the fill follows the camera, so however far the worms roam
## or however wide the camera pulls back (SpaceFit), space never runs out at an edge.
class_name Starfield
extends Node2D

@export var extent := Vector2(6000, 4000)
@export var count := 700
@export var star_seed := 7
@export var parallax := 1.0

var _stars: Array = []


func _ready() -> void:
	z_index = -10
	process_priority = 100     # after anything that moves or zooms the camera this frame
	var rng := RandomNumberGenerator.new()
	rng.seed = star_seed
	for i in count:
		_stars.append([Vector2(rng.randf_range(-extent.x, extent.x), rng.randf_range(-extent.y, extent.y)),
				[3.0, 3.0, 3.0, 6.0, 9.0][rng.randi() % 5], rng.randf_range(0.4, 1.0)])


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and parallax != 1.0:
		position = _cam_centre(cam) * (1.0 - parallax)
	queue_redraw()


## Where the camera looks now (its own position: the screen centre can lag a frame behind).
static func _cam_centre(cam: Camera2D) -> Vector2:
	return cam.global_position + cam.offset


## The part of space the camera sees, in this node's own frame (a bit larger).
func view_rect() -> Rect2:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	if cam == null:
		return Rect2(-extent, extent * 2.0)
	var half := get_viewport_rect().size * 0.5 / cam.zoom + Vector2(64, 64)
	return Rect2(_cam_centre(cam) - global_position - half, half * 2.0)


func _draw() -> void:
	var view := view_rect()
	draw_rect(view, Color("141a3c"))
	var period := extent * 2.0
	# which copies of the star tile touch the view
	var x0 := floori((view.position.x + extent.x) / period.x)
	var x1 := floori((view.end.x + extent.x) / period.x)
	var y0 := floori((view.position.y + extent.y) / period.y)
	var y1 := floori((view.end.y + extent.y) / period.y)
	for s in _stars:
		var c := Color(1, 1, 0.9, s[2])
		for kx in range(x0, x1 + 1):
			for ky in range(y0, y1 + 1):
				var p: Vector2 = s[0] + Vector2(kx * period.x, ky * period.y)
				if view.has_point(p):
					draw_rect(Rect2(p - Vector2.ONE * s[1] / 2.0, Vector2.ONE * s[1]), c)
