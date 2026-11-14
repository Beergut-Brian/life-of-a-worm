## The disk planet (docs/contracts.md "World: the polar disk"). A TileWorld on a DiskShape (polar
## chunks: ring band x angular sector) plus what Worm adds on top, all game-side so the vendored
## addon stays untouched:
##   * timestamped edits on the world's own simulated clock, so eaten tiles regrow;
##   * castings, a second layer written wherever a worm eats (drawn under the tiles, saved);
##   * gardens: a seed dropped in castings grows a patch that keeps refilling and spreading;
##   * food sizes: a tile that grows back in castings comes back bigger (RingDef.castings_size),
##     worth more growth and drawn plump; a ring never runs out (RingSet.scarce_share);
##   * a planet overview texture (1 px per 2 tiles) for the planet shot and the stage-6 chomp.
class_name PolarWorld
extends TileWorld

signal tile_eaten(cell: Vector2i, block: StringName, player: int)
signal tile_regrown(cell: Vector2i, block: StringName)
signal garden_planted(cell: Vector2i, flavour: StringName)
signal garden_grew(cell: Vector2i, flavour: StringName)
## A tile bigger than size 1 (grown back in castings) was eaten; tile_eaten fired just before.
signal big_tile_eaten(cell: Vector2i, player: int, size: int)

const CASTINGS_Z := -2
## Plump overlay on tiles that grew back bigger: above the tiles, under worms and pickups.
const SIZES_Z := 1
## A big bite plays its cue at most this often (a worm swallows many tiles a second).
const BIG_CUE_GAP := 0.3
## Overview: one pixel per this many tiles.
const OVERVIEW_STEP := 2

var clock := 0.0
## Planet seconds per real second. 1 in play; the demo speeds it up so regrowth shows in a frame.
var time_scale := 1.0
## True while the planet is not being played (the jar view, the planet shot): the clock stands
## still, so nothing regrows or grows. ChompDirector also disables the world node then.
var frozen := false
var rings: RingSet
## Chunks visited by the regrowth pass per physics frame (round robin over the live ones), so the
## pass is low frequency per chunk and never one big spike.
var regrow_chunks_per_frame := 2
## Regrowth and gardens never fill a cell this close (tiles) to a tracked eater, plus its radius.
var keep_clear_tiles := 3.0
## Circles (centre px, radius px) where nothing ever regrows: a worm's burrow. Not saved here; the
## burrow owner re-adds its zone after load_save().
var keep_zones: Array[Dictionary] = []
## At most this many cells regrow per physics frame (the rest wait a frame), so a big tunnel coming
## due at once never makes a spike. Tests pass budget -1 to regrow_pass, which has no cap.
var max_regrow_per_frame := 48
## Living-rings hooks (scripts/rings/rings_director.gd sets them every tick): Green thumb makes
## castings regrow this many times faster; rain makes gardens grow this many times faster.
var castings_speed := 1.0
var garden_speed := 1.0
var build_overview := true

## Measurements (stress scene reads them).
var chunk_build_ms: PackedFloat32Array = []
var regrown_total := 0
var regrow_frame_ms_max := 0.0

var _gen: DiskGenerator
var _disk: DiskShape
var _ids: Dictionary[StringName, int] = {}
var _tile_ring: Dictionary[int, int] = {}            # tile id -> ring index (garden tiles: -2)
var _times: Dictionary[Vector2i, Dictionary] = {}    # chunk key -> {cell: clock when eaten}
var _castings: Dictionary[Vector2i, Dictionary] = {} # chunk key -> {cell: true}
var _cast_layers: Dictionary[Vector2i, TileMapLayer] = {}
var _cast_set: TileSet
var _sizes: Dictionary[Vector2i, Dictionary] = {}    # chunk key -> {cell: size}, only sizes > 1
var _size_layers: Dictionary[Vector2i, TileMapLayer] = {}
var _size_set: TileSet
var _ring_out := PackedInt32Array()                  # ring index -> cells eaten and waiting
var _ring_cells := PackedFloat32Array()              # ring index -> cells in the ring (area)
var _scarce_step := PackedInt32Array()               # ring index -> last scarcity step seen
var _big_cue_at := -INF
var _gardens: Array[Dictionary] = []                 # {cell, flavour, tile, planted, next, cells}
var _garden_of: Dictionary[Vector2i, int] = {}       # cell -> garden index
var _stages: Dictionary[int, int] = {}
var _eaters: Array[Node2D] = []
var _rr_keys: Array[Vector2i] = []
var _next_due: Dictionary[Vector2i, float] = {}  # chunk key -> clock of its next due cell
var _rr_i := 0
var _loads_this_call := 0
var _overview: Image
var _overview_tex: ImageTexture
var _overview_dirty := false
var _overview_acc := 0.0
var _colors := PackedColorArray()


func setup_planet(p_rings: RingSet, radius: int, p_seed: int, band := 32) -> void:
	rings = p_rings
	_disk = PolarShape.new(radius, band)
	_gen = DiskGenerator.new(rings)
	var palette := rings.tile_defs()
	_ids.clear()
	_colors.clear()
	for i in palette.size():
		_ids[palette[i].id] = i
		_colors.append(palette[i].color)
	_tile_ring.clear()
	for ri in rings.rings.size():
		var r := rings.rings[ri]
		_tile_ring[_ids[r.tile]] = ri
		if r.alt_tile != &"":
			_tile_ring[_ids[r.alt_tile]] = ri
	for f in rings.garden_tiles:
		_tile_ring[_ids[rings.garden_tiles[f]]] = -2
	water_hz = 0.0  # no water on this planet yet; the aquifer prototype turns it on
	chunk_radius = 2  # a rounded 5x5 per tracked node, <= 25 chunks (PolarShape, W-23)
	setup(_disk, _gen, palette, p_seed)
	clock = 0.0
	_times.clear()
	_next_due.clear()
	_castings.clear()
	_sizes.clear()
	_gardens.clear()
	_garden_of.clear()
	_count_rings()
	_cast_set = _build_cast_set()
	_size_set = _build_size_set()
	if not chunk_loaded.is_connected(_on_chunk_loaded):
		chunk_loaded.connect(_on_chunk_loaded)
		chunk_freed.connect(_on_chunk_freed)
		tile_dug.connect(_on_tile_dug)
	if build_overview:
		_build_overview()


func id_of(tile: StringName) -> int:
	return _ids.get(tile, -1)


# --- stages and edibility ----------------------------------------------------------------------

func set_stage(player: int, stage: int) -> void:
	_stages[player] = stage


func stage_of(player: int) -> int:
	return _stages.get(player, 1)


func ring_of(cell: Vector2i) -> RingDef:
	return rings.rings[_gen.ring_index(cell)]


func is_edible_by(stage: int, thing) -> bool:
	if thing is Vector2i:
		if not shape.contains(thing):
			return false
		return _tile_edible(stage, get_tile(thing))
	if thing is StringName or thing is String:
		return _tile_edible(stage, _ids.get(StringName(thing), 0))
	if thing is Object:
		var s := StageRule.stage_of(thing)
		return s >= 0 and StageRule.relation(stage, s) == StageRule.FOOD
	return false


func _tile_edible(stage: int, id: int) -> bool:
	if not is_solid_id(id) or palette[id] == null or not palette[id].breakable:
		return false
	var ri: int = _tile_ring.get(id, -1)
	if ri == -2:
		return true  # garden food: any worm
	return ri >= 0 and rings.rings[ri].edible_from <= stage


# --- eating ------------------------------------------------------------------------------------

func eat_tile(cell: Vector2i, player: int) -> bool:
	if not shape.contains(cell):
		return false
	var id := get_tile(cell)
	if not is_solid_id(id):
		return false
	var block: StringName = palette[id].id
	if not _tile_edible(stage_of(player), id):
		dig_blocked.emit(cell, block, player)
		return false
	var size := food_size(cell)
	set_tile(cell, 0)
	_set_time(cell, clock)
	_clear_size(cell)
	_add_castings(cell)
	_overview_set(cell, rings.castings_hue)
	tile_eaten.emit(cell, block, player)
	if size > 1:
		_feed_big(cell, player, size)
		big_tile_eaten.emit(cell, player, size)
	return true


func eat_circle(pos: Vector2, radius_px: float, player: int) -> int:
	var cs := float(shape.cell_size)
	var r := radius_px / cs
	var c := pos / cs
	var n := 0
	var r2 := r * r
	for y in range(floori(c.y - r), ceili(c.y + r) + 1):
		for x in range(floori(c.x - r), ceili(c.x + r) + 1):
			if (Vector2(x + 0.5, y + 0.5) - c).length_squared() <= r2:
				var cell := Vector2i(x, y)
				if is_solid(cell) and eat_tile(cell, player):
					n += 1
	return n


## Something other than a worm removed a tile (TileWorld.dig: a creature, debris): it regrows too,
## at the slow outside-castings rate.
func _on_tile_dug(cell: Vector2i, _block: StringName, _player: int) -> void:
	_set_time(cell, clock)
	_clear_size(cell)
	_overview_set(cell, Color(0, 0, 0, 0))


func eaten_at(cell: Vector2i) -> float:
	var d = _times.get(shape.chunk_of(cell))
	return d.get(cell, -1.0) if d != null else -1.0


func _set_time(cell: Vector2i, t: float) -> void:
	var key := shape.chunk_of(cell)
	var d = _times.get(key)
	if d == null:
		d = {}
		_times[key] = d
	if not d.has(cell):
		_ring_out[_gen.ring_index(cell)] += 1
	d[cell] = t
	_next_due.erase(key)


func _clear_time(cell: Vector2i) -> void:
	var key := shape.chunk_of(cell)
	var d = _times.get(key)
	if d != null and d.has(cell):
		_ring_out[_gen.ring_index(cell)] -= 1
		d.erase(cell)
		if d.is_empty():
			_times.erase(key)


# --- regrowth ----------------------------------------------------------------------------------

func regrow_time(cell: Vector2i) -> float:
	if not shape.contains(cell) or _gen.base_tile(cell) == 1:
		return INF
	var ri := _gen.ring_index(cell)
	var base := rings.rings[ri].regrow_time
	if base <= 0.0:
		return INF
	return base * scarcity_factor(ri) * (rings.castings_factor / castings_speed if has_castings(cell) else 1.0)


func track_eater(node: Node2D) -> void:
	if not _eaters.has(node):
		_eaters.append(node)
	track(node)


func untrack_eater(node: Node2D) -> void:
	_eaters.erase(node)
	untrack(node)


func advance(delta: float) -> void:
	if frozen:
		return
	clock += delta * time_scale
	var t0 := Time.get_ticks_usec()
	_check_scarcity()
	_regrow_some(regrow_chunks_per_frame)
	_grow_gardens()
	regrow_frame_ms_max = maxf(regrow_frame_ms_max, (Time.get_ticks_usec() - t0) / 1000.0)
	_overview_acc += delta
	if _overview_dirty and _overview_acc >= 0.5:
		_overview_acc = 0.0
		_overview_dirty = false
		_overview_tex.update(_overview)


## Visits `budget` live chunks (round robin), regrowing every timestamped cell there that is due.
## budget < 0: every live chunk now (tests).
func regrow_pass(budget: int = -1) -> int:
	return _regrow_some(budget)


func _regrow_some(budget: int) -> int:
	if _rr_i >= _rr_keys.size():
		_rr_keys = loaded_chunks()
		_rr_i = 0
	var n := 0
	var visited := 0
	while _rr_i < _rr_keys.size() and (budget < 0 or visited < budget):
		var key := _rr_keys[_rr_i]
		_rr_i += 1
		visited += 1
		if not _chunks.has(key):
			continue
		var d = _times.get(key)
		if d == null or clock < float(_next_due.get(key, -INF)):
			continue
		var cast: Dictionary = _castings.get(key, {})
		var due: Array[Vector2i] = []
		var next := INF
		for cell: Vector2i in d:
			var ri := _gen.ring_index(cell)
			var base := rings.rings[ri].regrow_time
			if base <= 0.0 or _garden_of.has(cell):
				continue
			var at: float = d[cell] + base * scarcity_factor(ri) \
					* (rings.castings_factor / castings_speed if cast.has(cell) else 1.0)
			if clock >= at:
				due.append(cell)
			else:
				next = minf(next, at)
		# Skip this chunk until its next cell is due (a new edit here clears the mark).
		_next_due[key] = next if due.is_empty() else -INF
		for cell in due:
			if budget >= 0 and n >= max_regrow_per_frame:
				_rr_i -= 1  # this chunk again next frame
				break
			if _near_eater(cell):
				continue
			_regrow(cell)
			n += 1
		if budget >= 0 and n >= max_regrow_per_frame:
			break
	if budget < 0 and _rr_i >= _rr_keys.size():
		_rr_i = 0
		_rr_keys = loaded_chunks()
	regrown_total += n
	return n


func _regrow(cell: Vector2i) -> void:
	var id := base_tile_of(cell)
	set_tile(cell, id)
	_clear_time(cell)  # castings stay under the regrown tile: eaten again, it comes back fast again
	var size := regrow_size(cell)
	if size > 1:
		_set_size(cell, size)
	_overview_set(cell, _colors[id])
	tile_regrown.emit(cell, palette[id].id)


## A burrow: cells within radius_px of centre are never refilled by regrowth.
func add_keep_zone(centre: Vector2, radius_px: float) -> void:
	keep_zones.append({ "c": centre, "r": radius_px })


func in_keep_zone(cell: Vector2i) -> bool:
	var p := shape.center_of(cell)
	for z in keep_zones:
		if p.distance_squared_to(z.c) < z.r * z.r:
			return true
	return false


func _near_eater(cell: Vector2i) -> bool:
	var p := shape.center_of(cell)
	var cs := float(shape.cell_size)
	if not keep_zones.is_empty() and in_keep_zone(cell):
		return true
	for e in _eaters:
		if not is_instance_valid(e):
			continue
		var r := keep_clear_tiles * cs + float(e.get(&"radius_px") if &"radius_px" in e else 0.0)
		if local_pos(e).distance_squared_to(p) < r * r:
			return true
	return false


# --- food sizes and a ring that never runs out -------------------------------------------------

## Size of the food in a cell: 1 for a plain tile, more for one that grew back in castings.
func food_size(cell: Vector2i) -> int:
	var d = _sizes.get(shape.chunk_of(cell))
	return int(d.get(cell, 1)) if d != null else 1


## The size a cell's tile reaches when it grows back: its ring's castings_size in castings, else 1.
## Garden cells keep their own rules (size 1).
func regrow_size(cell: Vector2i) -> int:
	if not has_castings(cell) or _garden_of.has(cell):
		return 1
	return maxi(1, ring_of(cell).castings_size)


## Cells in each tile ring are counted once (annulus area in cells; good enough for a share).
func _count_rings() -> void:
	var n := rings.rings.size()
	_ring_out.resize(n)
	_ring_out.fill(0)
	_scarce_step.resize(n)
	_scarce_step.fill(0)
	_ring_cells.resize(n)
	var inner := 0.0
	for i in n:
		var outer := rings.rings[i].outer * float(_disk.radius)
		_ring_cells[i] = PI * (outer * outer - inner * inner)
		inner = outer
	_ring_cells[0] = maxf(1.0, _ring_cells[0] - PI * rings.strangestone_radius * rings.strangestone_radius)


## Cells of ring ri eaten (or dug) and not grown back yet, anywhere on the planet.
func ring_eaten(ri: int) -> int:
	return _ring_out[ri] if ri >= 0 and ri < _ring_out.size() else 0


## Share of ring ri's cells that are eaten and waiting, 0..1.
func ring_eaten_share(ri: int) -> float:
	if ri < 0 or ri >= _ring_cells.size():
		return 0.0
	return clampf(float(_ring_out[ri]) / maxf(1.0, _ring_cells[ri]), 0.0, 1.0)


## Tiles of ring ri still there to eat, anywhere on the planet (cells minus eaten and waiting).
func food_left(ri: int) -> int:
	return maxi(0, int(_ring_cells[ri]) - _ring_out[ri])


## A ring is never exhausted: past RingSet.scarce_share eaten, its regrow times shrink toward
## RingSet.scarce_factor, so the emptier a ring gets the faster it fills. 1 while it is well fed.
func scarcity_factor(ri: int) -> float:
	var share := ring_eaten_share(ri)
	if share <= rings.scarce_share:
		return 1.0
	var t := (share - rings.scarce_share) / maxf(0.0001, 1.0 - rings.scarce_share)
	return lerpf(1.0, rings.scarce_factor, clampf(t, 0.0, 1.0))


## A ring that just got scarcer (in tenths) wakes the chunks it has skipped, so the shorter times
## apply at once instead of at the old due time.
func _check_scarcity() -> void:
	for i in _ring_out.size():
		var step := int(ring_eaten_share(i) * 10.0)
		if step != _scarce_step[i]:
			if step > _scarce_step[i]:
				_next_due.clear()
			_scarce_step[i] = step


func _set_size(cell: Vector2i, size: int) -> void:
	var key := shape.chunk_of(cell)
	var d = _sizes.get(key)
	if d == null:
		d = {}
		_sizes[key] = d
	d[cell] = size
	var layer: TileMapLayer = _size_layers.get(key)
	if layer:
		layer.set_cell(cell, 0, Vector2i(mini(size, 3) - 2, 0))


func _clear_size(cell: Vector2i) -> void:
	var key := shape.chunk_of(cell)
	var d = _sizes.get(key)
	if d == null or not d.has(cell):
		return
	d.erase(cell)
	if d.is_empty():
		_sizes.erase(key)
	var layer: TileMapLayer = _size_layers.get(key)
	if layer:
		layer.erase_cell(cell)


func big_tile_count() -> int:
	var n := 0
	for k in _sizes:
		n += _sizes[k].size()
	return n


## A big tile is worth more: (size - 1) x RingSet.size_growth extra plain tiles' growth, in the
## ring's flavour, to the worm that ate it (on top of the worm's own bite_tile), with a cue.
func _feed_big(cell: Vector2i, player: int, size: int) -> void:
	var flavour := ring_of(cell).flavour
	for w in Worm.all():
		if w.player != player or w.world != self or w.model == null:
			continue
		var g: float = w.model.stats.value("tile_growth", Worm.TILE_GROWTH)
		w.model.add_growth(g * rings.size_growth * float(size - 1), flavour)
	var now := Time.get_ticks_msec() / 1000.0
	if now - _big_cue_at >= BIG_CUE_GAP:
		_big_cue_at = now
		Audio.play("chomp_bite")


## The plump look, drawn in code (no art): a soft light dome over the tile, a dark rim under it and
## two shine dots, in white and black at low alpha so it suits every ring's hue. Column 0 is
## size 2, column 1 size 3 and up (fuller dome, a third dot).
func _build_size_set() -> TileSet:
	var cs := shape.cell_size
	var img := Image.create_empty(cs * 2, cs, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for v in 2:
		var x0 := v * cs
		var c := Vector2(cs * 0.5, cs * 0.5)
		var r := cs * (0.42 + 0.06 * v)
		for y in cs:
			for x in cs:
				var p := Vector2(x + 0.5, y + 0.5)
				var d := p.distance_to(c) / r
				if d > 1.0:
					continue
				var top := clampf((c.y - p.y) / r, -1.0, 1.0)
				var col := Color(1, 1, 1, 0.10 + 0.22 * maxf(0.0, top) * (1.0 - d))
				if d > 0.82:
					col = Color(0, 0, 0, 0.28) if p.y > c.y else Color(1, 1, 1, 0.30)
				img.set_pixel(x0 + x, y, col)
		img.fill_rect(Rect2i(x0 + int(cs * 0.3), int(cs * 0.26), 2, 2), Color(1, 1, 1, 0.85))
		img.fill_rect(Rect2i(x0 + int(cs * 0.5), int(cs * 0.2), 1, 1), Color(1, 1, 1, 0.7))
		if v == 1:
			img.fill_rect(Rect2i(x0 + int(cs * 0.64), int(cs * 0.3), 1, 1), Color(1, 1, 1, 0.7))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(cs, cs)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(cs, cs)
	ts.add_source(src, 0)
	for v in 2:
		src.create_tile(Vector2i(v, 0))
	return ts


# --- castings ----------------------------------------------------------------------------------

func has_castings(cell: Vector2i) -> bool:
	var d = _castings.get(shape.chunk_of(cell))
	return d != null and d.has(cell)


func castings_count() -> int:
	var n := 0
	for k in _castings:
		n += _castings[k].size()
	return n


func _add_castings(cell: Vector2i) -> void:
	var key := shape.chunk_of(cell)
	var d = _castings.get(key)
	if d == null:
		d = {}
		_castings[key] = d
	d[cell] = true
	var layer: TileMapLayer = _cast_layers.get(key)
	if layer:
		layer.set_cell(cell, 0, Vector2i(_cast_variant(cell), 0))


func _remove_castings(cell: Vector2i) -> void:
	var key := shape.chunk_of(cell)
	var d = _castings.get(key)
	if d == null:
		return
	d.erase(cell)
	if d.is_empty():
		_castings.erase(key)
	var layer: TileMapLayer = _cast_layers.get(key)
	if layer:
		layer.erase_cell(cell)


func _cast_variant(cell: Vector2i) -> int:
	return posmod(cell.x * 7 + cell.y * 13, 4)


func _on_chunk_loaded(key: Vector2i) -> void:
	var layer := TileMapLayer.new()
	layer.name = "Castings_%d_%d" % [key.x, key.y]
	layer.tile_set = _cast_set
	layer.z_index = CASTINGS_Z
	layer.collision_enabled = false
	var d = _castings.get(key)
	if d != null:
		for cell: Vector2i in d:
			layer.set_cell(cell, 0, Vector2i(_cast_variant(cell), 0))
	add_child(layer)
	_cast_layers[key] = layer
	var sl := TileMapLayer.new()
	sl.name = "Sizes_%d_%d" % [key.x, key.y]
	sl.tile_set = _size_set
	sl.z_index = SIZES_Z
	sl.collision_enabled = false
	var sd = _sizes.get(key)
	if sd != null:
		for cell: Vector2i in sd:
			sl.set_cell(cell, 0, Vector2i(mini(int(sd[cell]), 3) - 2, 0))
	add_child(sl)
	_size_layers[key] = sl
	_loads_this_call += 1


func _on_chunk_freed(key: Vector2i) -> void:
	var layer: TileMapLayer = _cast_layers.get(key)
	if layer:
		_cast_layers.erase(key)
		remove_child(layer)
		layer.queue_free()
	var sl: TileMapLayer = _size_layers.get(key)
	if sl:
		_size_layers.erase(key)
		remove_child(sl)
		sl.queue_free()


## Dark rich soil with lighter crumbs, four variants. No collision: castings never block.
func _build_cast_set() -> TileSet:
	var cs := shape.cell_size
	var img := Image.create_empty(cs * 4, cs, false, Image.FORMAT_RGBA8)
	var base := rings.castings_hue
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for v in 4:
		img.fill_rect(Rect2i(v * cs, 0, cs, cs), base)
		for k in 7:
			var p := Vector2i(v * cs + rng.randi_range(1, cs - 3), rng.randi_range(1, cs - 3))
			img.fill_rect(Rect2i(p, Vector2i(2, 2)), base.lightened(0.25 + 0.1 * (k % 3)))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(cs, cs)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(cs, cs)
	ts.add_source(src, 0)
	for v in 4:
		src.create_tile(Vector2i(v, 0))
	return ts


# --- gardens -----------------------------------------------------------------------------------

func plant_seed(cell: Vector2i, flavour: StringName) -> bool:
	if not rings.garden_tiles.has(flavour) or not has_castings(cell) or get_tile(cell) != 0:
		return false
	if _garden_of.has(cell):
		return false
	var tile := _ids[rings.garden_tiles[flavour]]
	var g := {"cell": cell, "flavour": flavour, "tile": tile, "planted": clock,
		"next": clock + rings.garden_interval, "cells": [cell]}
	_gardens.append(g)
	_garden_of[cell] = _gardens.size() - 1
	set_tile(cell, tile)  # the sprout shows at once
	_overview_set(cell, _colors[tile])
	garden_planted.emit(cell, flavour)
	return true


func gardens() -> Array[Dictionary]:
	return _gardens


func garden_cells(index: int) -> Array:
	return _gardens[index].cells


## Each garden in a live chunk whose turn has come fills one cell: first a patch cell that was eaten,
## else the castings cell next to the patch nearest the seed, open or regrown (castings stay under
## regrown tiles, so a patch keeps spreading along old tunnels). Several turns catch up at once.
func _grow_gardens() -> void:
	for gi in _gardens.size():
		var g := _gardens[gi]
		if clock < g.next or not is_loaded(g.cell):
			continue
		var steps := 0
		while clock >= g.next and steps < 8:
			g.next += rings.garden_interval / maxf(garden_speed, 0.01)
			steps += 1
			var c := _garden_target(gi)
			if c == Vector2i(1 << 30, 0):
				continue
			if not _garden_of.has(c):
				_garden_of[c] = gi
				g.cells.append(c)
			set_tile(c, g.tile)
			_clear_time(c)
			_overview_set(c, _colors[g.tile])
			garden_grew.emit(c, g.flavour)


func _garden_target(gi: int) -> Vector2i:
	var g := _gardens[gi]
	var none := Vector2i(1 << 30, 0)
	var best := none
	var best_d := INF
	var max_r2 := float(rings.garden_max_radius * rings.garden_max_radius)
	for c: Vector2i in g.cells:
		if get_tile(c) == 0 and is_loaded(c) and not _near_eater(c):
			return c
	for c: Vector2i in g.cells:
		for o in _NEIGHBOURS:
			var n: Vector2i = c + o
			if _garden_of.has(n) or not has_castings(n) or not is_loaded(n):
				continue
			var d := float((n - g.cell).length_squared())
			if d > max_r2 or d >= best_d or _near_eater(n):
				continue
			best = n
			best_d = d
	return best


# --- overview ----------------------------------------------------------------------------------

func planet_texture() -> Texture2D:
	return _overview_tex


func _build_overview() -> void:
	var r := _disk.radius
	var size := ceili(2.0 * r / OVERVIEW_STEP)
	_overview = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var clear := Color(0, 0, 0, 0)
	for py in size:
		for px in size:
			var cell := Vector2i(px * OVERVIEW_STEP - r, py * OVERVIEW_STEP - r)
			_overview.set_pixel(px, py, _colors[_gen.base_tile(cell)] if _disk.contains(cell) else clear)
	for cell in edits.tiles:
		var id: int = edits.tiles[cell]
		_overview_set(cell, rings.castings_hue if id == 0 else _colors[id])
	if _overview_tex == null:
		_overview_tex = ImageTexture.create_from_image(_overview)
	else:
		_overview_tex.set_image(_overview)


func _overview_set(cell: Vector2i, col: Color) -> void:
	if _overview == null:
		return
	var r := _disk.radius
	if posmod(cell.x + r, OVERVIEW_STEP) != 0 or posmod(cell.y + r, OVERVIEW_STEP) != 0:
		return
	var p := (cell + Vector2i(r, r)) / OVERVIEW_STEP
	if p.x >= 0 and p.y >= 0 and p.x < _overview.get_width() and p.y < _overview.get_height():
		_overview.set_pixelv(p, col)
		_overview_dirty = true


# --- look ---------------------------------------------------------------------------------------

## Overrides the addon's flat tile set (same atlas layout and collision: tile id i at (i - 1, 0)) with
## a softer edge: a 1 px shade on the bottom and right only, so a field of tiles reads as ground,
## not graph paper. Wanted upstream as a TileWorld option (see the R-a report).
func _build_tile_set() -> TileSet:
	var ts := super()
	var src := ts.get_source(0) as TileSetAtlasSource
	var cs := shape.cell_size
	var img := Image.create_empty(cs * maxi(palette.size() - 1, 1), cs, false, Image.FORMAT_RGBA8)
	for i in range(1, palette.size()):
		var col: Color = palette[i].color if palette[i] else Color.MAGENTA
		var x0 := (i - 1) * cs
		img.fill_rect(Rect2i(x0, 0, cs, cs), col)
		img.fill_rect(Rect2i(x0, cs - 1, cs, 1), col.darkened(0.12))
		img.fill_rect(Rect2i(x0 + cs - 1, 0, 1, cs), col.darkened(0.12))
	src.texture = ImageTexture.create_from_image(img)
	return ts


# --- chunks, frame, save -----------------------------------------------------------------------

## Times each chunk load (script side: base tiles, TileMapLayer cells, castings layer). The
## TileMapLayer's collision and render quadrants build later in the frame; frame times show that.
func update_chunks(budget: int = -1) -> void:
	_loads_this_call = 0
	var t0 := Time.get_ticks_usec()
	super(budget)
	if _loads_this_call > 0:
		var ms := (Time.get_ticks_usec() - t0) / 1000.0 / _loads_this_call
		for i in _loads_this_call:
			chunk_build_ms.append(ms)


func _physics_process(delta: float) -> void:
	super(delta)
	if shape != null:
		advance(delta)


func to_save() -> Dictionary:
	var data := super()
	data["radius"] = _disk.radius
	data["band"] = _disk.band
	data["clock"] = clock
	var times := []
	for key in _times:
		var d: Dictionary = _times[key]
		for cell: Vector2i in d:
			times.append_array([cell.x, cell.y, int(round(d[cell] * 10.0))])
	data["times"] = times
	var cast := []
	for key in _castings:
		for cell: Vector2i in _castings[key]:
			cast.append_array([cell.x, cell.y])
	data["castings"] = cast
	var sizes := []
	for key in _sizes:
		for cell: Vector2i in _sizes[key]:
			sizes.append_array([cell.x, cell.y, int(_sizes[key][cell])])
	data["sizes"] = sizes
	var gardens := []
	for g in _gardens:
		gardens.append([g.cell.x, g.cell.y, String(g.flavour), int(round(g.planted * 10.0))])
	data["gardens"] = gardens
	return data


## Same RingSet, radius, band and seed as the save (setup_planet first). Gardens replant from their
## seed cell and regrow on the clock (their cells are edits, so the patch itself comes back as-is).
func load_save(data: Dictionary) -> void:
	clock = float(data.get("clock", 0.0))
	_times.clear()
	_next_due.clear()
	_castings.clear()
	_sizes.clear()
	_ring_out.fill(0)
	_scarce_step.fill(0)
	_gardens.clear()
	_garden_of.clear()
	var t: Array = data.get("times", [])
	for i in range(0, t.size() - 2, 3):
		_set_time(Vector2i(int(t[i]), int(t[i + 1])), float(t[i + 2]) / 10.0)
	var c: Array = data.get("castings", [])
	for i in range(0, c.size() - 1, 2):
		var cell := Vector2i(int(c[i]), int(c[i + 1]))
		var key := shape.chunk_of(cell)
		if not _castings.has(key):
			_castings[key] = {}
		_castings[key][cell] = true
	var sz: Array = data.get("sizes", [])   # tins from before food sizes have none: all size 1
	for i in range(0, sz.size() - 2, 3):
		var cell := Vector2i(int(sz[i]), int(sz[i + 1]))
		var key := shape.chunk_of(cell)
		if not _sizes.has(key):
			_sizes[key] = {}
		_sizes[key][cell] = int(sz[i + 2])
	super(data)
	for g in data.get("gardens", []):
		var cell := Vector2i(int(g[0]), int(g[1]))
		var flavour := StringName(g[2])
		var tile := _ids[rings.garden_tiles[flavour]]
		var cells := [cell]
		# The patch is every garden-tile edit connected to the seed (it was saved as edits).
		var open: Array[Vector2i] = [cell]
		while not open.is_empty():
			var p: Vector2i = open.pop_back()
			for o in _NEIGHBOURS:
				var n: Vector2i = p + o
				if not _garden_of.has(n) and not cells.has(n) and edits.tiles.get(n, -1) == tile:
					cells.append(n)
					open.append(n)
		_gardens.append({"cell": cell, "flavour": flavour, "tile": tile,
			"planted": float(g[3]) / 10.0, "next": clock + rings.garden_interval, "cells": cells})
		for pc in cells:
			_garden_of[pc] = _gardens.size() - 1
	if build_overview:
		_build_overview()
