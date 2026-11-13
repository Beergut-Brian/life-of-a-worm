## K-09: the cartoon burst when a house, cow or car is eaten. Code-drawn, no art files, no text:
## a white pop ring, a puff of round confetti, little squares and four-point stars in the prop's
## own colours, each inked, flying out and up and then falling toward the core with the disk's
## gravity (world.shape.gravity_at, like LooseFall) and settling on the first solid tile, spinning,
## fading, gone in LIFE seconds.
## Lives on the world (it turns with the planet). Frees itself.
class_name MayhemBurst
extends Node2D

const LIFE := 1.3
const FADE := 0.45
const INK := Color("2a1a14")
## Gravity when there is no world (tests, scratch scenes), px/s^2 toward the core.
const FALLBACK_G := 520.0

var colours: Array[Color] = [Color.WHITE]
var pieces := 24
var world: TileWorld
## Half the prop's size, px: the confetti starts spread over it.
var spread := 24.0
var t := 0.0
## Each piece: {p, v, col, r, kind (0 dot, 1 square, 2 star), spin, a, rest}.
var bits: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 4
	_rng.seed = hash(name) ^ int(global_position.x * 7.0)
	var up := _up()
	for i in pieces:
		var ang := _rng.randf_range(-PI, PI)
		var out := Vector2.from_angle(ang)
		var v := out * _rng.randf_range(110.0, 260.0) + up * _rng.randf_range(120.0, 260.0)
		bits.append({
			"p": out * _rng.randf_range(0.0, spread * 0.6),
			"v": v,
			"col": colours[i % colours.size()],
			"r": _rng.randf_range(3.0, 6.5),
			"kind": i % 3,
			"spin": _rng.randf_range(-9.0, 9.0),
			"a": _rng.randf_range(0.0, TAU),
			"rest": false,
		})


## Away from the core in this node's own frame.
func _up() -> Vector2:
	var parent := get_parent() as Node2D
	var core_local := to_local(parent.to_global(Vector2.ZERO)) if parent != null else Vector2(0, 1000)
	if world != null:
		core_local = to_local(world.to_global(Vector2.ZERO))
	return -core_local.normalized() if core_local.length() > 0.5 else Vector2.UP


func _gravity(local_p: Vector2) -> Vector2:
	if world != null and world.get("shape") != null:
		var wp := world.to_local(to_global(local_p))
		var g: Vector2 = world.shape.gravity_at(wp)
		# world frame -> this node's frame (rotation only)
		return g.rotated(world.global_rotation - global_rotation)
	return -_up() * FALLBACK_G


## True when this point (this node's frame) is inside a solid tile of the world.
func _solid(local_p: Vector2) -> bool:
	if world == null or world.get("shape") == null:
		return false
	return world.is_solid(world.shape.cell_at(world.to_local(to_global(local_p))))


func _process(delta: float) -> void:
	step(delta)


## Advances the burst; false once it is gone (tests drive it directly).
func step(delta: float) -> bool:
	t += delta
	for b in bits:
		if b.rest:
			continue
		b.v = (b.v as Vector2) * (1.0 - 0.6 * delta) + _gravity(b.p) * delta
		var next: Vector2 = (b.p as Vector2) + (b.v as Vector2) * delta
		if _solid(next) and not _solid(b.p):
			b.rest = true   # landed on the ground, like every loose thing
			continue
		b.p = next
		b.a = float(b.a) + float(b.spin) * delta
	queue_redraw()
	if t >= LIFE:
		queue_free()
		return false
	return true


func _draw() -> void:
	var alpha := clampf((LIFE - t) / FADE, 0.0, 1.0)
	# The pop: a white ring that snaps out in the first fifth of a second.
	if t < 0.22:
		var k := t / 0.22
		draw_arc(Vector2.ZERO, spread * (0.4 + k * 1.1), 0.0, TAU, 32, Color(1, 1, 1, 1.0 - k), 6.0 * (1.0 - k) + 1.0)
	for b in bits:
		var p: Vector2 = b.p
		var r: float = b.r
		var col: Color = b.col
		col.a = alpha
		var ink := Color(INK, alpha)
		match int(b.kind):
			0:
				draw_circle(p, r + 1.2, ink)
				draw_circle(p, r, col)
			1:
				draw_set_transform(p, float(b.a))
				draw_rect(Rect2(-r - 1.2, -r - 1.2, (r + 1.2) * 2.0, (r + 1.2) * 2.0), ink)
				draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), col)
				draw_set_transform(Vector2.ZERO)
			_:
				var pts := _star(p, r * 1.5, float(b.a))
				draw_colored_polygon(_star(p, r * 1.5 + 1.5, float(b.a)), ink)
				draw_colored_polygon(pts, col)


static func _star(c: Vector2, r: float, a: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 8:
		var rr := r if i % 2 == 0 else r * 0.42
		pts.append(c + Vector2.from_angle(a + TAU * i / 8.0) * rr)
	return pts
