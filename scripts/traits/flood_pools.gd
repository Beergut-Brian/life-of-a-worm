## D-08: flooded pockets in the dirt ring. A few seeded pools (same seed, same pools) sit where the
## ground has filled with water; every worm inside one is a `slow_zone` of kind water, so a plain
## worm wades at 1 - DRAG of its speed and a worm whose `drag/water` is low (Slick) swims at
## nearly full speed. Nothing pushes: the water only slows. Entering a pool always splashes (a
## blorp and a ripple ring); a worm that swims it also gets its trait's sting and ring.
## The pools keep clear of the spawn side (the top of the planet, where a new worm starts), so
## the first minutes are never in water.
class_name FloodPools
extends Node2D

signal splashed(player: int, swims: bool)

const POOLS := 5
## Water slows a plain worm to 1 - DRAG of its speed (the trait arena puddle uses 0.6 too).
const DRAG := 0.6
## Pools sit in this band of the planet radius (the dirt ring is 0.45 to 0.82).
const BAND := Vector2(0.5, 0.78)
## Half width along the ring and half depth across it, in tiles.
const HALF_LEN := 7.0
const HALF_DEPTH := 3.5
## No pool within this many radians of the top (the spawn side).
const SPAWN_CLEAR := 0.6
## A worm whose drag/water is at most this swims (its trait's sting on the splash).
const SWIM_AT := 0.5
const WATER := Color(0.25, 0.55, 1.0, 0.42)

var world: PolarWorld
var pools: Array[FloodPool] = []
## Splashes so far (tests read this; also the signal).
var splashes := 0
var _inside := {}   # Worm -> bool
var _t := 0.0


func _ready() -> void:
	world = get_parent() as PolarWorld
	z_index = 1
	if world == null or world.shape == null:
		return
	var cs := float(world.shape.cell_size)
	var r_px := float(world.shape.radius) * cs
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, "flood"])
	var spawn := -PI / 2.0
	var tries := 0
	while pools.size() < POOLS and tries < 200:
		tries += 1
		var a := rng.randf_range(-PI, PI)
		if absf(angle_difference(a, spawn)) < SPAWN_CLEAR:
			continue
		var ok := true
		for q in pools:
			if absf(angle_difference(a, q.angle)) < 0.35:
				ok = false
		if not ok:
			continue
		var p := FloodPool.new()
		p.pools = self
		p.angle = a
		p.radius = rng.randf_range(BAND.x, BAND.y) * r_px
		p.half_angle = HALF_LEN * cs / p.radius
		p.half_depth = HALF_DEPTH * cs
		p.drag = DRAG
		pools.append(p)
		add_child(p)


## The pool holding this world-space point, or null.
func pool_at(global_p: Vector2) -> FloodPool:
	for p in pools:
		if p.contains(global_p):
			return p
	return null


func _physics_process(_delta: float) -> void:
	for w in Worm.all():
		if w.world != world or w.model == null:
			continue
		var now := pool_at(w.head.global_position) != null
		if now and not _inside.get(w, false):
			_splash(w)
		_inside[w] = now


func _splash(w: Worm) -> void:
	splashes += 1
	var swims := w.model.stats.value("drag/water", 1.0) <= SWIM_AT
	Audio.play("lava_blob_blorp")
	var ring := WormRing.new()
	ring.color = Color(0.6, 0.85, 1.0)
	ring.life = 0.45
	ring.max_radius = 26.0 * w.size_factor()
	ring.position = w.head.position
	ring.z_index = 9
	w.fx.add_child(ring)
	if swims:
		w._trait_moment("drag/water")
	splashed.emit(w.player, swims)


func _process(delta: float) -> void:
	_t += delta
	for p in pools:
		p.queue_redraw()


## One flooded pocket: an arc of the dirt ring. A `slow_zone` (kind water) for Worm._zone_factor.
class FloodPool extends Node2D:
	var pools: FloodPools
	var kind: StringName = &"water"
	var drag := 0.6
	var angle := 0.0
	var radius := 0.0
	var half_angle := 0.1
	var half_depth := 50.0

	func _ready() -> void:
		add_to_group("slow_zone")

	func centre() -> Vector2:
		return Vector2.from_angle(angle) * radius

	func contains(global_p: Vector2) -> bool:
		var l := pools.world.to_local(global_p)
		return absf(l.length() - radius) <= half_depth \
			and absf(angle_difference(l.angle(), angle)) <= half_angle

	func _draw() -> void:
		var steps := 18
		var pts := PackedVector2Array()
		for i in steps + 1:
			var a := angle - half_angle + 2.0 * half_angle * i / steps
			pts.append(Vector2.from_angle(a) * (radius + half_depth))
		for i in range(steps, -1, -1):
			var a := angle - half_angle + 2.0 * half_angle * i / steps
			pts.append(Vector2.from_angle(a) * (radius - half_depth))
		draw_colored_polygon(pts, FloodPools.WATER)
		var rim := pts.duplicate()
		rim.append(pts[0])
		draw_polyline(rim, FloodPools.WATER.lightened(0.5), 2.0)
		# Ripples drift along the pool so it reads as water, not a blue rock.
		var t := pools._t
		for i in 5:
			var rr := radius - half_depth * 0.7 + half_depth * 1.4 * i / 4.0
			var f := fmod(t * 0.15 + i * 0.37, 1.0)
			var a0 := angle - half_angle * 0.85 + half_angle * 1.5 * f
			var span := 2.2 * pools.world.shape.cell_size / rr
			draw_arc(Vector2.ZERO, rr, a0, a0 + span, 6, Color(1, 1, 1, 0.5), 1.5)
