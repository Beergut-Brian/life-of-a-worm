## K-08 on the real planet: unstreamed ground is never black. FarGround (scripts/world/far_ground.gd)
## draws the world's overview picture under the chunk tiles, so at the wide stage-5 zoom the parts of
## the disk with no tiles built show their ring colour instead of the near-black back wall. It lines up
## with the tiles cell for cell, sits between the back wall and the tiles, turns with the world, keeps
## eaten cells open, and every ring it shows is brighter than the back wall it covers.
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")

var _level: PlanetLevel


func before() -> void:
	SuiteSandbox.enter("far_ground")


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	_hush()
	SuiteSandbox.leave()


func before_test() -> void:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	BaitTins.open(0)
	Save.wipe()
	Save.set_value("seed", 77)
	_level = PLANET.instantiate()
	_level.autosave_every = 9999.0
	add_child(_level)
	_level.stage_beat.make_story = false


func after_test() -> void:
	_hush()
	if is_instance_valid(_level):
		_level.free()
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _hush() -> void:
	for p in Audio._pool:
		p.stop()
		p.stream = null


func _ground() -> FarGround:
	return _level.world.get_node_or_null(^"FarGround") as FarGround


static func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func test_the_planet_level_has_one_far_ground_under_the_tiles_and_over_the_wall() -> void:
	var g := _ground()
	assert_object(g).is_not_null()
	assert_object(g.get_parent()).is_same(_level.world)   # turns with the planet
	assert_object(g.texture).is_same(_level.world.planet_texture())
	assert_bool(g.z_as_relative).is_true()
	assert_int(g.z_index).is_greater(-4)                  # over the level's back wall (-4)
	assert_int(g.z_index).is_less(PolarWorld.CASTINGS_Z)  # under castings (-2) and chunk tiles (-1)
	# a second call never stacks another one
	assert_object(FarGround.make_for(_level.world)).is_same(g)
	var n := 0
	for c in _level.world.get_children():
		if c is FarGround:
			n += 1
	assert_int(n).is_equal(1)


func test_it_lines_up_with_the_tiles_cell_for_cell() -> void:
	var g := _ground()
	var world := _level.world
	var cs := float(world.shape.cell_size)
	var img: Image = world._overview
	for cell in [Vector2i(0, 0), Vector2i(-120, 37), Vector2i(64, -200), Vector2i(-2, -298)]:
		# the overview keeps one pixel per OVERVIEW_STEP cells: check the cells it keeps
		var c := Vector2i(cell.x - posmod(cell.x + world.shape.radius, PolarWorld.OVERVIEW_STEP),
				cell.y - posmod(cell.y + world.shape.radius, PolarWorld.OVERVIEW_STEP))
		var centre := (Vector2(c) + Vector2(0.5, 0.5)) * cs          # the tile's centre, world-local
		var tex_px := Vector2i(((centre - g.position) / g.scale).floor())
		var want := (c + Vector2i(world.shape.radius, world.shape.radius)) / PolarWorld.OVERVIEW_STEP
		assert_vector(Vector2(tex_px)).is_equal(Vector2(want))
		assert_bool(img.get_pixelv(tex_px).is_equal_approx(img.get_pixelv(want))).is_true()


func test_every_ring_it_shows_is_brighter_than_the_back_wall() -> void:
	var g := _ground()
	var img: Image = _level.world._overview
	var wall := _lum(PlanetLevel.BACK_WALL)
	var seen := {}
	for y in range(0, img.get_height(), 3):
		for x in range(0, img.get_width(), 3):
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			seen[c.to_html(false)] = c
	assert_int(seen.size()).is_greater(3)
	for k in seen:
		var shown: Color = seen[k] * g.modulate
		assert_float(_lum(shown)).override_failure_message(
				"ring colour %s shows at %.3f, back wall is %.3f" % [k, _lum(shown), wall]).is_greater(wall * 1.5)


func test_eaten_cells_stay_open() -> void:
	var world := _level.world
	world.set_stage(0, 7)
	var r: int = world.shape.radius
	var cell := Vector2i(-r / 2, 0)
	cell -= Vector2i(posmod(cell.x + r, PolarWorld.OVERVIEW_STEP), posmod(cell.y + r, PolarWorld.OVERVIEW_STEP))
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			world.eat_tile(cell + Vector2i(dx, dy), 0)
	var p := (cell + Vector2i(r, r)) / PolarWorld.OVERVIEW_STEP
	var col: Color = world._overview.get_pixelv(p)
	# eaten ground is a tunnel: clear in the overview (or the castings hue a bite leaves), never ground
	var ground: Color = world._colors[world._gen.base_tile(cell)]
	assert_bool(col.a < 0.5 or not col.is_equal_approx(ground)).is_true()


func test_a_bare_world_without_a_wall_gets_none() -> void:
	var parent := Node2D.new()
	add_child(parent)
	var w := PolarWorld.new()
	w.setup_planet(StageTable.default_table().apply_crust(PlanetLevel.RINGS), 60, 3, 32)
	parent.add_child(w)
	assert_object(DiskEdge.make_for(w)).is_null()
	assert_object(w.get_node_or_null(^"FarGround")).is_null()
	parent.free()
