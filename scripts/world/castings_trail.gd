## G-01, the visible half: where a worm eats, a light scatter of warm brown castings lies on the
## tunnel floor behind it. PolarWorld already records castings per cell (a saved layer that makes
## food regrow faster), but that layer sits under the tunnel's back wall and never showed. This node
## draws the castings the player can see: little crumb piles on the floor side of open castings cells
## (the side toward the planet's centre), popping in as each tile is eaten so the trail reads as the
## result of eating.
##
## Cost is fixed: at most MAX_PILES piles exist; past that the pile farthest from every worm goes.
## Piles near a worm are refilled from the saved castings layer every SCAN seconds (old tunnels in a
## loaded tin show their castings again), and a pile goes when its tile grows back over it.
## One per world (`ensure`); it is a child of the PolarWorld, so it turns with the planet.
## Placeholder look, code-drawn: warm rich browns only, nothing dark (docs/kid-design.md).
class_name CastingsTrail
extends Node2D

const NODE_NAME := &"CastingsTrail"
## Piles on the planet at once (the cost cap).
const MAX_PILES := 160
## Seconds a new pile takes to pop in (overshoots, then settles).
const POP_TIME := 0.3
## Seconds between refills from the saved castings round each worm.
const SCAN := 0.5
## Cells checked round each worm's head on a refill.
const REACH_TILES := 10
## New piles a refill adds at most (spreads the cost over frames).
const PER_SCAN := 24
## Crumbs in one pile.
const CRUMBS := 4
## Warm rich soil: base, light crumb, shine. No near-black (kid design: nothing dark in the dirt).
const SOIL := Color("9a6236")
const SOIL_LIGHT := Color("c48a52")
const SOIL_SHINE := Color("e2b27a")

var world: PolarWorld
## cell -> {"pos": Vector2 (world-local), "born": float (seconds, -1 = already settled), "s": float}
var piles: Dictionary[Vector2i, Dictionary] = {}
## Piles added and dropped so far (tests count these, not the dictionary each frame).
var added := 0
var dropped := 0
var _t := 0.0
var _scan_t := 0.0
var _animating := false


## The world's one trail, made on first call.
static func ensure(w: PolarWorld) -> CastingsTrail:
	if w == null:
		return null
	var t := w.get_node_or_null(NodePath(NODE_NAME)) as CastingsTrail
	if t == null:
		t = CastingsTrail.new()
		t.name = NODE_NAME
		w.add_child(t)
		t.attach(w)
	return t


func attach(w: PolarWorld) -> void:
	world = w
	# Same z as the tile chunks and the worm's body; kept the world's last child so the castings
	# draw over the tunnel's back wall, and the worms (after the world) over the castings.
	z_index = -1
	if not world.tile_eaten.is_connected(_on_eaten):
		world.tile_eaten.connect(_on_eaten)
		world.tile_regrown.connect(_on_regrown)
		world.chunk_loaded.connect(_on_chunk_loaded)


func _process(delta: float) -> void:
	step(delta)


## One tick (tests call it with a fixed delta).
func step(delta: float) -> void:
	if world == null:
		return
	_t += delta
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = SCAN
		refill()
	if _animating:
		_animating = false
		for c in piles:
			var b: float = piles[c].born
			if b >= 0.0 and _t - b < POP_TIME:
				_animating = true
				break
		queue_redraw()


## Spacing between piles in cells: wider for bigger worms (their tunnels are wider too).
func gap_for(stage: int) -> int:
	return clampi((stage + 1) / 3, 1, 3)


## Crumb scale for a worm stage: castings grow with the worm so they read at every zoom.
func scale_for(stage: int) -> float:
	return 1.0 + 0.45 * float(maxi(stage, 1) - 1)


func _on_eaten(cell: Vector2i, _block: StringName, player: int) -> void:
	var stage := world.stage_of(player)
	add_pile(cell, stage, true)


func _on_regrown(cell: Vector2i, _block: StringName) -> void:
	if piles.erase(cell):
		queue_redraw()


func _on_chunk_loaded(_key: Vector2i) -> void:
	# New chunk layers are added after us: stay last so the back wall never covers the castings.
	if get_parent() == world and get_index() != world.get_child_count() - 1:
		world.move_child.call_deferred(self, -1)


## Adds a pile on `cell` unless another lies within the stage's gap. Returns true when one was added.
func add_pile(at_cell: Vector2i, stage: int, fresh: bool) -> bool:
	var cell := settle(at_cell)
	if piles.has(cell):
		return false
	var g := gap_for(stage)
	for dy in range(-g, g + 1):
		for dx in range(-g, g + 1):
			if piles.has(cell + Vector2i(dx, dy)):
				return false
	while piles.size() >= MAX_PILES:
		_drop_farthest()
	var mid := world.shape.center_of(cell)
	var down := -mid.normalized() if mid.length() > 0.5 else Vector2.DOWN
	var cs := float(world.shape.cell_size)
	piles[cell] = {"pos": mid + down * cs * 0.3, "born": _t if fresh else -1.0, "s": scale_for(stage)}
	added += 1
	if fresh:
		_animating = true
	queue_redraw()
	return true


## The floor cell under `cell`: walks toward the core while the next cell is open (castings fall to
## the tunnel floor). At most a few steps, loaded cells only.
func settle(cell: Vector2i) -> Vector2i:
	for i in 4:
		var b := world.shape.below(cell)
		if b == cell or not world.is_loaded(b) or world.is_solid(b):
			break
		cell = b
	return cell


## Refill from the saved castings layer round each worm (open cells only).
func refill() -> void:
	var n := 0
	for w in Worm.all():
		if w.world != world or not is_instance_valid(w.head):
			continue
		var stage := world.stage_of(w.player)
		var c0 := world.shape.cell_at(world.to_local(w.head.global_position))
		var g := gap_for(stage)
		for dy in range(-REACH_TILES, REACH_TILES + 1, g):
			for dx in range(-REACH_TILES, REACH_TILES + 1, g):
				var c := c0 + Vector2i(dx, dy)
				if not world.is_loaded(c) or world.is_solid(c) or not world.has_castings(c):
					continue
				if add_pile(c, stage, false):
					n += 1
					if n >= PER_SCAN:
						return


func _drop_farthest() -> void:
	var heads: Array[Vector2] = []
	for w in Worm.all():
		if w.world == world and is_instance_valid(w.head):
			heads.append(world.to_local(w.head.global_position))
	var worst := Vector2i.ZERO
	var worst_d := -1.0
	var oldest := INF
	for c in piles:
		var p: Vector2 = piles[c].pos
		var d := INF
		for h in heads:
			d = minf(d, p.distance_squared_to(h))
		if heads.is_empty():
			# No worm: the oldest goes (settled piles count as oldest).
			d = -float(piles[c].born)
		if d > worst_d or (d == worst_d and float(piles[c].born) < oldest):
			worst_d = d
			worst = c
			oldest = float(piles[c].born)
	piles.erase(worst)
	dropped += 1


func _draw() -> void:
	var cs := float(world.shape.cell_size) if world else 16.0
	for c: Vector2i in piles:
		var p: Dictionary = piles[c]
		var k := 1.0
		var born: float = p.born
		if born >= 0.0:
			var a := clampf((_t - born) / POP_TIME, 0.0, 1.0)
			k = a + sin(a * PI) * 0.45   # pops past full size, settles back
		if k <= 0.0:
			continue
		var pos: Vector2 = p.pos
		var down := -pos.normalized() if pos.length() > 0.5 else Vector2.DOWN
		var side := down.orthogonal()
		var s: float = p.s * k
		var h := hash(c)
		for i in CRUMBS:
			var hx := float((h >> (i * 4)) & 15) / 15.0 - 0.5
			var hy := float((h >> (i * 4 + 16)) & 15) / 15.0
			var at: Vector2 = pos + side * hx * cs * 0.75 * p.s - down * hy * cs * 0.18 * p.s
			var r := (1.9 + 0.6 * float(i % 3)) * s
			draw_circle(at, r, SOIL if i % 2 == 0 else SOIL_LIGHT)
			draw_circle(at - down * r * 0.35 - side * r * 0.25, r * 0.35, SOIL_SHINE)
