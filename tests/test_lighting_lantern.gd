## Lantern Deep lighting (Docket D92): the Lantern node swaps in the Lantern tiles when the world
## enters, keeps its light pool capped, lights every worm in its slot tint, opens a daylight shaft
## where the crust is eaten, and never lets the ambient go dark.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const RADIUS := 160


## A level stand-in: a parent with a Lantern child, then a PolarWorld added the way the planet does.
func _level(max_lights := 6) -> Dictionary:
	var level := Node2D.new()
	var lantern := Lantern.new()
	lantern.max_lights = max_lights
	level.add_child(lantern)
	add_child(level)
	auto_free(level)
	var w := PolarWorld.new()
	w.setup_planet(RINGS, RADIUS, 7)
	level.add_child(w)
	w.set_physics_process(false)
	return {level = level, lantern = lantern, world = w}


func _anchor(w: PolarWorld, cell: Vector2i) -> Node2D:
	var a := Node2D.new()
	a.position = w.shape.center_of(cell)
	w.get_parent().add_child(a)
	w.track(a)
	w.update_chunks(-1)
	return a


func test_the_world_gets_lantern_tiles_with_normals_and_collision() -> void:
	var d := _level()
	var w: PolarWorld = d.world
	assert_object(w.tile_art).is_instanceof(LanternTileArt)
	_anchor(w, Vector2i(100, 7))
	var art: LanternTileArt = w.tile_art
	var ts: TileSet = art.tile_set()
	var src := ts.get_source(TileArt.SOLID_SOURCE) as TileSetAtlasSource
	assert_object(src.texture).is_instanceof(CanvasTexture)
	assert_object((src.texture as CanvasTexture).normal_texture).is_not_null()
	var td := src.get_tile_data(art.solid_coords(Vector2i(100, 7), w.get_tile(Vector2i(100, 7)), 0), 0)
	assert_int(td.get_collision_polygons_count(0)).is_equal(1)
	assert_object(td.material).is_same(art.material)
	assert_bool(ts.has_source(TileArt.WALL_SOURCE)).is_true()


func test_every_ring_tile_has_its_own_lantern_row() -> void:
	var meta := LanternTileArt.load_meta()
	var rows: Dictionary = meta.solid_rows
	for def in RINGS.tile_defs():
		if def.id == &"air":
			continue
		assert_bool(rows.has(String(def.id))).override_failure_message("no Lantern row for %s" % def.id).is_true()


func test_a_dug_cell_shows_its_ring_back_wall_and_outside_the_disk_none() -> void:
	var d := _level()
	var art: LanternTileArt = d.world.tile_art
	var meta := LanternTileArt.load_meta()
	var dirt_row: int = meta.wall_rows.dirt
	assert_int(art.wall_coords(Vector2i(100, 7), 6, false).y).is_equal(dirt_row)
	assert_int(art.wall_coords(Vector2i(100, 7), 6, true).x).is_greater_equal(art.variants)
	assert_that(art.wall_coords(Vector2i(RADIUS + 4, 0), 0, false)).is_equal(TileArt.NO_TILE)


func test_the_pool_never_exceeds_its_cap() -> void:
	var d := _level(4)
	var lantern: Lantern = d.lantern
	for i in 30:
		lantern.emitters[StringName("fake%d" % i)] = {pos = Vector2(i * 8, 0), kind = Lantern.Kind.CRYSTAL, count = 1}
	lantern.assign(Vector2.ZERO, 100000.0)
	var lit := 0
	for l in lantern.lights:
		lit += 1 if l.enabled else 0
	assert_int(lantern.lights.size()).is_equal(4)
	assert_int(lit).is_equal(4)
	assert_int(lantern.active_lights).is_equal(4)


func test_each_worm_gets_a_light_tinted_toward_its_slot_colour() -> void:
	var d := _level()
	var lantern: Lantern = d.lantern
	var worms: Array[Node2D] = []
	for p in [Players.P1, Players.P2]:
		var fake := FakeLitWorm.new()
		fake.player = p
		d.level.add_child(fake)
		worms.append(fake)
	lantern.assign(Vector2.ZERO, 100.0)
	var green := lantern.lights[0].color
	var red := lantern.lights[1].color
	assert_bool(lantern.lights[0].enabled and lantern.lights[1].enabled).is_true()
	assert_float(green.g).is_greater(green.r)
	assert_float(red.r).is_greater(red.g)
	for w in worms:
		w.free()


func test_eating_through_the_crust_opens_a_daylight_shaft_and_regrowth_closes_it() -> void:
	var d := _level()
	var w: PolarWorld = d.world
	var lantern: Lantern = d.lantern
	var top := Vector2i(0, -(RADIUS - 1))       # in the grass crust, straight up
	_anchor(w, top)
	var shafts := func() -> int:
		var n := 0
		for k in lantern.emitters:
			n += 1 if lantern.emitters[k].kind == Lantern.Kind.SHAFT else 0
		return n
	var before: int = shafts.call()
	assert_int(w.dig(top).size()).is_equal(1)
	assert_int(shafts.call()).is_equal(before + 1)
	w.regrow_pass(-1)            # not due yet: still open
	assert_int(shafts.call()).is_equal(before + 1)
	w.clock += 100000.0
	w.keep_clear_tiles = 0.0
	w.regrow_pass(-1)
	assert_int(w.get_tile(top)).is_greater(0)
	assert_int(shafts.call()).is_equal(before)


func test_ambient_is_dim_never_dark_in_every_ring() -> void:
	var d := _level()
	var lantern: Lantern = d.lantern
	var px := RADIUS * 16.0
	for f in [0.05, 0.3, 0.6, 0.9, 0.99, 1.2]:
		var c := lantern.ambient_at(Vector2(0, -px * f))
		assert_float(minf(c.r, minf(c.g, c.b))).is_greater_equal(Lantern.AMBIENT_FLOOR)
	# deeper rings are dimmer than the surface
	assert_float(lantern.ambient_at(Vector2(0, -px * 0.6)).v).is_less(lantern.ambient_at(Vector2(0, -px * 1.2)).v)


func test_glowing_tiles_become_capped_light_emitters() -> void:
	var d := _level()
	var w: PolarWorld = d.world
	var lantern: Lantern = d.lantern
	_anchor(w, Vector2i(0, 10))      # the core: crystals and the Strangestone
	var kinds := {}
	for k in lantern.emitters:
		kinds[lantern.emitters[k].kind] = true
	assert_bool(kinds.has(Lantern.Kind.CORE)).is_true()
	assert_bool(kinds.has(Lantern.Kind.CRYSTAL) or kinds.has(Lantern.Kind.STRANGE)).is_true()


func test_the_dock_grade_covers_the_screen_and_only_the_dock_has_one() -> void:
	var g := DockGrade.new()
	add_child(g)
	auto_free(g)
	assert_object(g.rect).is_not_null()
	assert_object(g.rect.material).is_not_null()
	assert_int(g.rect.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var dock: Node = load("res://scenes/story/dock.tscn").instantiate()
	assert_object(dock.get_node_or_null("StoryGrade")).is_instanceof(DockGrade)
	dock.free()
	for path in ["res://scenes/levels/planet.tscn", "res://scenes/levels/disk.tscn"]:
		var s: Node = load(path).instantiate()
		assert_object(s.get_node_or_null("Lantern")).is_instanceof(Lantern)
		for c in s.get_children():
			assert_bool(c is DockGrade).is_false()
		s.free()


## Test double: a node in the "worms" group with a `player` and a `head`, like Worm.
class FakeLitWorm:
	extends Node2D
	var player := 0
	var head: Node2D

	func _init() -> void:
		head = Node2D.new()
		add_child(head)
		add_to_group(&"worms")
