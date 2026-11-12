## Look B ground (A-07, A-08): every ring tile maps onto a textured material, the autotile atlas
## encodes material, edge ink and cut corners, grass grows on the side facing away from the core,
## every tile keeps the addon's full-square collision, and PolarWorld uses the art by default.
class_name TestLookTiles
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")


func _art() -> RingTileArt:
	return RingTileArt.new(RINGS.tile_defs())


func test_every_ring_tile_maps_to_its_own_material() -> void:
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RingTileArt.MANIFEST))
	var defs := RINGS.tile_defs()
	var art := _art()
	for i in range(1, defs.size()):
		var name := String(defs[i].id)
		assert_bool(man.tiles.has(name)).override_failure_message("no material for tile %s" % name).is_true()
		assert_int(art.material_of(i)).is_equal(man.materials.find(man.tiles[name]))


func test_tile_set_has_collision_and_the_shared_material_on_every_tile() -> void:
	var art := _art()
	var ts := art.tile_set()
	var src := ts.get_source(TileArt.SOLID_SOURCE) as TileSetAtlasSource
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RingTileArt.MANIFEST))
	assert_int(src.get_tiles_count()).is_equal(man.materials.size() * 16 + man.grassy.size() * 64)
	for i in src.get_tiles_count():
		var td := src.get_tile_data(src.get_tile_id(i), 0)
		assert_int(td.get_collision_polygons_count(0)).is_equal(1)
		assert_object(td.material).is_same(art.material)


func test_grass_grows_on_the_side_away_from_the_core() -> void:
	assert_int(RingTileArt.outward_side(Vector2i(0, -290))).is_equal(1)
	assert_int(RingTileArt.outward_side(Vector2i(290, 3))).is_equal(2)
	assert_int(RingTileArt.outward_side(Vector2i(-2, 290))).is_equal(3)
	assert_int(RingTileArt.outward_side(Vector2i(-290, 5))).is_equal(4)
	var art := _art()
	var defs := RINGS.tile_defs()
	var grass := -1
	var dirt := -1
	for i in defs.size():
		if defs[i].id == &"grass":
			grass = i
		elif defs[i].id == &"dirt":
			dirt = i
	assert_vector(art.solid_coords(Vector2i(0, -295), grass, 1)).is_equal(Vector2i(16 + 1, art.material_of(grass)))
	assert_vector(art.solid_coords(Vector2i(0, -200), dirt, 5)).is_equal(Vector2i(5, art.material_of(dirt)))
	assert_vector(art.wall_coords(Vector2i.ZERO, 0, false)).is_equal(TileArt.NO_TILE)


func test_mask_atlas_encodes_material_ink_and_cut_corners() -> void:
	var img := (RingTileArt.MASKS as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	for row in 3:
		var c := img.get_pixel(8, row * 16 + 8)
		assert_int(c.r8).is_equal(row)
		assert_int(c.g8 & 7).is_equal(6)  # mask 0: deep inside, darkest
	var up_left := 1 | 8
	var p := img.get_pixel(up_left * 16 + 0, 0)
	assert_float(p.a).is_equal(0.0)  # rounded corner cut away
	var edge := img.get_pixel(1 * 16 + 8, 0)  # mask "up open": top row is ink
	assert_int(edge.g8 & 7).is_equal(1)
	var lip := img.get_pixel(1 * 16 + 8, 1)
	assert_int(lip.g8 & 7).is_equal(2)


func test_polar_world_uses_ring_art_and_the_see_through_castings() -> void:
	var w := PolarWorld.new()
	w.build_overview = false
	w.setup_planet(RINGS, 40, 3, 32)
	assert_object(w.tile_art).is_instanceof(RingTileArt)
	var cs := w._build_cast_set()
	assert_object((cs.get_source(0) as TileSetAtlasSource).texture).is_same(RingTileArt.CASTINGS)
	w.free()
	var flat := PolarWorld.new()
	flat.build_overview = false
	flat.use_ring_art = false
	flat.setup_planet(RINGS, 40, 3, 32)
	assert_object(flat.tile_art).is_null()
	flat.free()
