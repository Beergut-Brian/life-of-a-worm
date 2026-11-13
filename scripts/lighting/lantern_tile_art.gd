## Lantern Deep tiles (look B, Docket D92) for a TileWorld, through the addon's TileArt hook
## (addons/openjar/docs/contracts.md "Tile art and the light pass"). Atlases are baked by
## art/tools/lantern_tiles.py: solid tiles by kind x open mask x 4 variants, back walls by ring x
## ceiling x 4 variants, each with a normal map (CanvasTexture) so the light pool shades the bevels.
## Every tile shares one ShaderMaterial (shaders/lantern_tiles.gdshader): solid ground darkens away
## from open air, read from the world's overview texture on the GPU (no CPU flood fill).
class_name LanternTileArt
extends TileArt

const META_PATH := "res://assets/sprites/tiles/lantern_tiles.json"
const SOLID_TEX := preload("res://assets/sprites/tiles/lantern_solid.png")
const SOLID_N := preload("res://assets/sprites/tiles/lantern_solid_n.png")
const WALL_TEX := preload("res://assets/sprites/tiles/lantern_wall.png")
const WALL_N := preload("res://assets/sprites/tiles/lantern_wall_n.png")
const SHADER := preload("res://shaders/lantern_tiles.gdshader")
## Ring tile name (art/tools/lantern_tiles.py tile_ring) -> back-wall row name.
const WALL_OF := {&"core": &"core", &"strange": &"core", &"rock": &"rock", &"dirt": &"dirt",
	&"clay": &"dirt", &"castings": &"dirt", &"topsoil": &"topsoil", &"grass": &"grass"}

var world: TileWorld
var material: ShaderMaterial
var variants := 4
## Tile id -> atlas row in the solid source (-1: unknown name, drawn with the dirt row).
var row_of_id := PackedInt32Array()
## Ring index (RingSet order, core outward) -> wall row; ring outer radii as a share of the disk.
var wall_row_of_ring := PackedInt32Array()
var ring_outer := PackedFloat32Array()
var _meta: Dictionary = {}
var _radius := 0.0
## (cell) -> bool: true where an air cell is open to the sky (DiskEdge.is_open_to_sky, W-12). Those
## get no back wall, so the sky shows where the planet's rim has been eaten away. Unset: every air
## cell in the disk has its wall.
var sky_open := Callable()


func _init(p_world: TileWorld) -> void:
	world = p_world
	_meta = load_meta()
	variants = int(_meta.get("variants", 4))
	material = ShaderMaterial.new()
	material.shader = SHADER


static func load_meta() -> Dictionary:
	var f := FileAccess.open(META_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


func tile_set() -> TileSet:
	var rows: Dictionary = _meta.get("solid_rows", {})
	var tile_ring: Dictionary = _meta.get("tile_ring", {})
	var wall_rows: Dictionary = _meta.get("wall_rows", {})
	row_of_id.resize(world.palette.size())
	for i in world.palette.size():
		var def: TileDef = world.palette[i]
		row_of_id[i] = int(rows.get(String(def.id), rows.get("dirt", 0))) if def else 0
	_index_rings(tile_ring, wall_rows)
	var cs: int = world.shape.cell_size
	var ts := TileSet.new()
	ts.tile_size = Vector2i(cs, cs)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, world.collision_layer)
	var solid := _source(SOLID_TEX, SOLID_N, cs)
	ts.add_source(solid, SOLID_SOURCE)
	var h := cs * 0.5
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	var n_rows := SOLID_TEX.get_height() / cs
	for row in n_rows:
		for col in 16 * variants:
			var at := Vector2i(col, row)
			solid.create_tile(at)
			var td := solid.get_tile_data(at, 0)
			td.material = material
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, square)
	var wall := _source(WALL_TEX, WALL_N, cs)
	ts.add_source(wall, WALL_SOURCE)
	for row in WALL_TEX.get_height() / cs:
		for col in 2 * variants:
			var at := Vector2i(col, row)
			wall.create_tile(at)
			wall.get_tile_data(at, 0).material = material
	_hook_overview()
	return ts


func _source(tex: Texture2D, nrm: Texture2D, cs: int) -> TileSetAtlasSource:
	var ct := CanvasTexture.new()
	ct.diffuse_texture = tex
	ct.normal_texture = nrm
	ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var src := TileSetAtlasSource.new()
	src.texture = ct
	src.texture_region_size = Vector2i(cs, cs)
	return src


func _index_rings(tile_ring: Dictionary, wall_rows: Dictionary) -> void:
	wall_row_of_ring.clear()
	ring_outer.clear()
	_radius = float(world.shape.get(&"radius")) if world.shape.get(&"radius") != null else 0.0
	var rs = world.get(&"rings")
	if rs == null:
		return
	for r: RingDef in rs.rings:
		var art_ring := StringName(tile_ring.get(String(r.tile), "dirt"))
		var wall_name: StringName = WALL_OF.get(art_ring, &"dirt")
		wall_row_of_ring.append(int(wall_rows.get(String(wall_name), 0)))
		ring_outer.append(r.outer)


func _hook_overview() -> void:
	material.set_shader_parameter(&"cell_size", float(world.shape.cell_size))
	var tex: Texture2D = world.call(&"planet_texture") if world.has_method(&"planet_texture") else null
	material.set_shader_parameter(&"has_overview", tex != null and _radius > 0.0)
	if tex == null or _radius <= 0.0:
		return
	material.set_shader_parameter(&"overview", tex)
	material.set_shader_parameter(&"radius_tiles", _radius)
	material.set_shader_parameter(&"overview_span", float(tex.get_width() * PolarWorld.OVERVIEW_STEP))


## Re-reads the overview texture (the world builds it after setup()).
func refresh_overview() -> void:
	_hook_overview()


func solid_coords(cell: Vector2i, id: int, open: int) -> Vector2i:
	var row := row_of_id[id] if id >= 0 and id < row_of_id.size() else 0
	return Vector2i(open * variants + cell_hash(cell) % variants, row)


func wall_coords(cell: Vector2i, _base_id: int, ceiling: bool) -> Vector2i:
	var ri := ring_index(cell)
	if ri < 0:
		return NO_TILE
	if sky_open.is_valid() and sky_open.call(cell):
		return NO_TILE
	return Vector2i((variants if ceiling else 0) + cell_hash(cell) % variants, wall_row_of_ring[ri])


## Ring index (core outward) of a cell by its distance from the disk centre; -1 outside the disk.
func ring_index(cell: Vector2i) -> int:
	if _radius <= 0.0 or ring_outer.is_empty():
		return 0 if not wall_row_of_ring.is_empty() else -1
	var f := (Vector2(cell) + Vector2(0.5, 0.5)).length() / _radius
	for i in ring_outer.size():
		if f < ring_outer[i]:
			return i
	return -1
