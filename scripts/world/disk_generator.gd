## The base disk from a seed: Strangestone seam at the centre, then the RingSet's rings core outward,
## each its dominant tile with a seeded sprinkle of its second tile. Deterministic per (shape, seed),
## independent of call order (TileWorld only stores edits against this).
class_name DiskGenerator
extends WorldGenerator

var ring_set: RingSet
var _ids: Dictionary[StringName, int] = {}
## Outer radius of each ring in tiles, squared; and its two tile ids.
var _r2 := PackedFloat32Array()
var _main := PackedInt32Array()
var _alt := PackedInt32Array()
var _alt_cut := PackedFloat32Array()
var _noise := FastNoiseLite.new()
var _stone_r2 := 9.0
var _seam_len := 6.0
var _radius := 1.0


func _init(p_rings: RingSet = null) -> void:
	ring_set = p_rings


func setup(p_shape: WorldShape, p_seed: int) -> void:
	super(p_shape, p_seed)
	var defs := ring_set.tile_defs()
	_ids.clear()
	for i in defs.size():
		_ids[defs[i].id] = i
	_radius = float((p_shape as DiskShape).radius)
	_r2.clear(); _main.clear(); _alt.clear(); _alt_cut.clear()
	for r in ring_set.rings:
		_r2.append(pow(r.outer * _radius, 2.0))
		_main.append(_ids[r.tile])
		_alt.append(_ids.get(r.alt_tile, _ids[r.tile]))
		# Noise in [-1, 1]; cells above the cut are alt. Roughly alt_share of cells.
		_alt_cut.append(1.0 - 2.0 * r.alt_share * 1.6)
	_stone_r2 = ring_set.strangestone_radius * ring_set.strangestone_radius
	_seam_len = ring_set.strangestone_radius * 2.0
	_noise.seed = p_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.09


func id_of(tile: StringName) -> int:
	return _ids.get(tile, -1)


func base_tile(cell: Vector2i) -> int:
	var m := Vector2(cell) + Vector2(0.5, 0.5)
	var d2 := m.length_squared()
	if d2 < _stone_r2 or (absf(m.y) < 1.0 and absf(m.x) < _seam_len):
		return 1
	var ring := 0
	var last := _r2.size() - 1
	while ring < last and d2 >= _r2[ring]:
		ring += 1
	if _noise.get_noise_2d(m.x, m.y) > _alt_cut[ring]:
		return _alt[ring]
	return _main[ring]


func base_chunk(cells: Array[Vector2i]) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(cells.size())
	var i := 0
	for c in cells:
		out[i] = base_tile(c)
		i += 1
	return out


## Index into ring_set.rings for a cell (outside the disk: the last ring).
func ring_index(cell: Vector2i) -> int:
	var d2 := (Vector2(cell) + Vector2(0.5, 0.5)).length_squared()
	var ring := 0
	var last := _r2.size() - 1
	while ring < last and d2 >= _r2[ring]:
		ring += 1
	return ring
