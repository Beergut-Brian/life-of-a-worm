## W-12: the disk's visible edge shrinks as it is eaten.
##
## The level draws the planet's back wall (the dark earth behind tunnels) as one full disk at the
## planet's radius, so a bite out of the crust only ever showed a dark notch and the planet's outline
## stayed a perfect circle. DiskEdge takes that wall over: the level's Polygon2D is cut down to a
## plain disk at `floor_r`, and the band from there out to the surface is drawn here, one thin wedge
## per angle. Each wedge reaches out to the outermost solid tile on its ray, so where the worm has
## eaten the crust (and the topsoil under it) open to the sky, the sky shows through and the planet
## is visibly smaller and lumpier. Sealed tunnels keep their wall (a solid tile further out stops
## the ray). Inside loaded chunks the tile art leaves those open cells without a back-wall tile
## (LanternTileArt.sky_open → is_open_to_sky), and they are redrawn whenever the edge moves.
## The same open cells are cleared from the world's overview picture, so the stage-6 planet shot
## (ChompDirector.frozen_planet_texture) shows a lumpy, bitten planet.
##
## Readable, never sudden: a wedge moves toward its target at SPEED px/s, so a bite sinks the rim
## over about a second and a regrown topsoil dent fills back in the same way. Eaten crust never
## regrows (StageTable.apply_crust), so those dents stay. The edge never sinks below `floor_r`: the
## topsoil's top minus TOPSOIL_DENT tiles, and nothing here changes a tile, so the playable disk is
## exactly the tiles the worm left (only the crust is lost for good).
##
## CrustBurst.watch() adds one next to the level's wall (DiskEdge.make_for). Placeholder look: the
## wall's own colour. Nothing to save: the edge is read from the world's tiles on load.
class_name DiskEdge
extends Node2D

## Wedges around the planet (a quarter degree each: about 1.3 tiles of arc at the surface).
const BUCKETS := 1440
## Px per second the drawn edge moves toward the real one.
const SPEED := 90.0
## Tiles under the top of the topsoil the edge may sink where eaten ground opens to the sky.
const TOPSOIL_DENT := 10
## Wedges re-read per frame in a slow sweep (catches tiles changed without a signal, e.g. gardens).
const SWEEP_PER_FRAME := 16
## Px the wedges overlap the cut-down wall disk, so no seam shows.
const OVERLAP := 3.0

var world: TileWorld
## The level's back-wall disk this edge took over (null in a bare test world).
var wall: Polygon2D
var color := Color("1b1712")
## The planet's full radius and the lowest the edge can go (px, world space).
var outer_r := 0.0
var floor_r := 0.0
## Per wedge: where the ground really ends, and where it is drawn this frame.
var target := PackedFloat32Array()
var shown := PackedFloat32Array()

var _cs := 16.0
var _dirty: Dictionary[int, bool] = {}
var _moving: Dictionary[int, bool] = {}
var _sweep := 0
var _cols := PackedColorArray()


## An edge for a world whose parent draws the full back-wall disk, added right after that wall.
## Null when there is no such wall (a bare world in a test).
static func make_for(p_world: TileWorld) -> DiskEdge:
	var parent := p_world.get_parent() if p_world != null else null
	if parent == null or p_world.shape == null:
		return null
	var r := float(p_world.shape.radius) * float(p_world.shape.cell_size)
	for c in parent.get_children():
		var poly := c as Polygon2D
		if poly == null or poly.polygon.size() < 32:
			continue
		if absf(poly.polygon[0].length() - r) < float(p_world.shape.cell_size):
			var e := DiskEdge.new()
			e.attach(p_world, poly)
			parent.add_child(e)
			parent.move_child(e, poly.get_index() + 1)
			return e
	return null


## The edge watching a world (null if none).
static func of(p_world: Object) -> DiskEdge:
	if p_world == null or not p_world.has_meta(&"disk_edge"):
		return null
	var e = p_world.get_meta(&"disk_edge")
	return e if is_instance_valid(e) else null


func _init() -> void:
	name = "DiskEdge"


## Reads the world, cuts the wall (if any) down to the floor and snaps the edge to the tiles now.
func attach(p_world: TileWorld, p_wall: Polygon2D = null) -> void:
	world = p_world
	wall = p_wall
	_cs = float(world.shape.cell_size)
	outer_r = float(world.shape.radius) * _cs
	floor_r = outer_r * _topsoil_top() - TOPSOIL_DENT * _cs
	if wall != null:
		color = wall.color
		z_index = wall.z_index
		z_as_relative = wall.z_as_relative
		var pts := PackedVector2Array()
		for i in 256:
			pts.append(Vector2.from_angle(TAU * i / 256.0) * floor_r)
		wall.polygon = pts
	_cols = PackedColorArray([color, color, color, color])
	target.resize(BUCKETS)
	shown.resize(BUCKETS)
	for b in BUCKETS:
		target[b] = scan(b)
		shown[b] = target[b]
	for b in BUCKETS:
		if target[b] < outer_r:
			_redraw_cells(b, target[b], outer_r)   # a loaded tin's bites: overview and tiles
	world.set_meta(&"disk_edge", self)
	_hook_art()
	if world.has_signal(&"chunk_loaded") and not world.chunk_loaded.is_connected(_on_chunk_loaded):
		world.chunk_loaded.connect(_on_chunk_loaded, CONNECT_DEFERRED)
	for sig in [&"tile_eaten", &"tile_dug"]:
		if world.has_signal(sig) and not world.is_connected(sig, _on_tile_changed):
			world.connect(sig, _on_tile_changed)
	if world.has_signal(&"tile_regrown") and not world.is_connected(&"tile_regrown", _on_tile_regrown):
		world.connect(&"tile_regrown", _on_tile_regrown)
	queue_redraw()


## The tile art (the Lantern swaps its own in after setup) leaves sky-open cells without a wall.
func _hook_art() -> void:
	var art = world.tile_art
	if art != null and &"sky_open" in art and not (art.get(&"sky_open") as Callable).is_valid():
		art.set(&"sky_open", is_open_to_sky)


func _exit_tree() -> void:
	if world != null and is_instance_valid(world) and world.get_meta(&"disk_edge", null) == self:
		world.remove_meta(&"disk_edge")


## PolarWorld draws each chunk's saved castings (z under the back wall) when the chunk loads; in
## the open sky they would hang in the air, so they are hidden there (the castings stay recorded).
func _on_chunk_loaded(key: Vector2i) -> void:
	var layer := world.get_node_or_null("Castings_%d_%d" % [key.x, key.y]) as TileMapLayer
	if layer == null:
		return
	for c in layer.get_used_cells():
		if is_open_to_sky(c):
			layer.erase_cell(c)


## Castings at an open cell hidden, at a covered one shown again (PolarWorld's own variant pick).
func _castings_tile(c: Vector2i) -> void:
	if not world.has_method(&"has_castings"):
		return
	var key := world.shape.chunk_of(c)
	var layer := world.get_node_or_null("Castings_%d_%d" % [key.x, key.y]) as TileMapLayer
	if layer == null:
		return
	if is_open_to_sky(c):
		layer.erase_cell(c)
	elif world.has_castings(c) and world.has_method(&"_cast_variant"):
		layer.set_cell(c, 0, Vector2i(world.call(&"_cast_variant", c), 0))


## The planet picture (PolarWorld's overview, which the stage-6 planet shot freezes) shows the
## bites: a sky-open cell is clear there, a covered tunnel keeps the castings hue PolarWorld gave it.
func _overview_cell(c: Vector2i) -> void:
	if not world.has_method(&"_overview_set"):
		return
	if is_open_to_sky(c):
		world.call(&"_overview_set", c, Color(0, 0, 0, 0))
	elif world.has_method(&"has_castings") and world.has_castings(c):
		world.call(&"_overview_set", c, world.rings.castings_hue)


## Fraction of the radius where the ring under the crust (the topsoil) ends.
func _topsoil_top() -> float:
	var rings: RingSet = world.get(&"rings") if &"rings" in world else null
	if rings == null or rings.rings.size() < 2:
		return 1.0
	return rings.rings[rings.rings.size() - 2].outer


func bucket_of(angle: float) -> int:
	return posmod(int(floorf(fposmod(angle, TAU) / TAU * BUCKETS)), BUCKETS)


func angle_of(b: int) -> float:
	return (float(b) + 0.5) * TAU / BUCKETS


## Where the ground ends along wedge b's centre ray (px from the core), never below floor_r.
func scan(b: int) -> float:
	var dir := Vector2.from_angle(angle_of(b))
	var step := _cs * 0.5
	var r := outer_r - step * 0.5
	while r > floor_r:
		var c := world.shape.cell_at(dir * r)
		if world.shape.contains(c) and world.is_solid(c):
			return minf(outer_r, r + step * 0.5)
		r -= step
	return floor_r


## An air cell beyond the ground's end on its wedge: the sky shows there, not a back wall.
func is_open_to_sky(cell: Vector2i) -> bool:
	if target.is_empty():
		return false
	var p := world.shape.center_of(cell)
	var r := p.length()
	return r > floor_r and r > target[bucket_of(p.angle())]


## The drawn edge at an angle (px from the core).
func edge_at(angle: float) -> float:
	return shown[bucket_of(angle)]


func target_at(angle: float) -> float:
	return target[bucket_of(angle)]


## The planet's drawn radius averaged around the disk: falls as the crust is eaten.
func mean_radius() -> float:
	var s := 0.0
	for v in shown:
		s += v
	return s / float(BUCKETS)


func _on_tile_changed(cell: Vector2i, _block: StringName, _player: int) -> void:
	mark(cell)


func _on_tile_regrown(cell: Vector2i, _block: StringName) -> void:
	mark(cell)


## A tile changed: re-read the wedges over it right away (only near the rim), so anything asking
## is_open_to_sky in the same frame (the tile art, castings) already sees the new edge.
func mark(cell: Vector2i) -> void:
	var p := world.shape.center_of(cell)
	if p.length() < floor_r - _cs:
		return
	var b := bucket_of(p.angle())
	for k in range(-1, 2):
		rescan(posmod(b + k, BUCKETS))


## Re-reads wedge b; where its edge moved, the tiles along it are redrawn and it starts easing.
func rescan(b: int) -> void:
	var was := target[b]
	target[b] = scan(b)
	if target[b] != was:
		_redraw_cells(b, was, target[b])
	if target[b] != shown[b]:
		_moving[b] = true


func _process(delta: float) -> void:
	step(delta)


## One frame: re-read changed wedges (plus a slow sweep), then ease the drawn edge toward them.
func step(delta: float) -> void:
	if world == null or target.is_empty():
		return
	_hook_art()
	for i in SWEEP_PER_FRAME:
		_dirty[_sweep] = true
		_sweep = (_sweep + 1) % BUCKETS
	for b in _dirty:
		rescan(b)
	_dirty.clear()
	if _moving.is_empty():
		return
	var d := SPEED * delta
	var done: Array[int] = []
	for b in _moving:
		shown[b] = move_toward(shown[b], target[b], d)
		if shown[b] == target[b]:
			done.append(b)
	for b in done:
		_moving.erase(b)
	queue_redraw()


## The tiles along wedge b between two edge radii get their back wall taken off (or put back).
func _redraw_cells(b: int, r0: float, r1: float) -> void:
	var trail := world.get_node_or_null(^"CastingsTrail")
	var dir := Vector2.from_angle(angle_of(b))
	var side := dir.orthogonal() * _cs * 0.5
	var seen: Dictionary[Vector2i, bool] = {}
	var r := minf(r0, r1) - _cs
	var top := maxf(r0, r1) + _cs
	while r <= top:
		for k in [-1.0, 0.0, 1.0]:
			var c := world.shape.cell_at(dir * r + side * k)
			if not seen.has(c) and not world.is_solid(c):
				seen[c] = true
				if world.tile_art != null and world.has_method(&"_redraw_art"):
					world.call(&"_redraw_art", c)   # the addon's per-cell art refresh (TileWorld)
				_castings_tile(c)
				_overview_cell(c)
				if trail != null and trail.piles.has(c) and is_open_to_sky(c):
					trail.piles.erase(c)   # no crumb piles hanging in the sky
					trail.queue_redraw()
		r += _cs * 0.5


func _draw() -> void:
	if shown.is_empty():
		return
	var lo := floor_r - OVERLAP
	var d0 := Vector2.from_angle(0.0)
	for b in BUCKETS:
		var d1 := Vector2.from_angle(float(b + 1) * TAU / BUCKETS)
		var r := shown[b]
		if r > floor_r:
			draw_primitive(PackedVector2Array([d0 * lo, d0 * r, d1 * r, d1 * lo]), _cols, PackedVector2Array())
		d0 = d1
