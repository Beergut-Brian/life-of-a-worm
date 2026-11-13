## W-12 on the real planet: the disk's visible edge (DiskEdge, scripts/world/disk_edge.gd) sinks
## where the worm eats the rim open to the sky, gradually (never a jump), never below its floor, and
## stays down where the crust is gone for good while regrown topsoil fills its dent back in. Open
## cells lose their back wall (sky shows) and get no castings piles; sealed tunnels keep both.
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")
const DT := 1.0 / 60.0

var _level: PlanetLevel
var _table: StageTable


func before() -> void:
	SuiteSandbox.enter("disk_edge")
	_table = StageTable.default_table()


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
	Audio.played.clear()
	BaitTins.open(0)
	Save.wipe()
	Save.set_value("seed", 77)   # a pinned planet, never randi()
	_level = PLANET.instantiate()
	_level.autosave_every = 9999.0
	add_child(_level)
	_level.stage_beat.make_story = false
	_edge().set_process(false)   # the tests step it themselves


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


func _edge() -> DiskEdge:
	return _level.crust.edge


func _stage5_worm() -> Worm:
	var w := _level.spawn_worm(Players.P1)
	while w.model.stage < _table.crust_stage():
		if w.model.size_stage() > w.model.stage:
			w.model.eat_apex(w.model.stage)
		else:
			w.model.add_segment(&"")
	return w


## Eats a round bite (radius ~3 tiles) at every half tile from the rim down `depth` tiles at `angle`,
## the way a stage-5 mouth chews in. Returns the tiles eaten.
func _bite(angle: float, depth: int) -> Array[Vector2i]:
	var world := _level.world
	var e := _edge()
	var out: Array[Vector2i] = []
	for d in range(0, depth * 2 + 1):
		var c0 := world.shape.cell_at(Vector2.from_angle(angle) * (e.outer_r - 8.0 - d * 8.0))
		for dx in range(-3, 4):
			for dy in range(-3, 4):
				var c := c0 + Vector2i(dx, dy)
				if dx * dx + dy * dy <= 10 and world.is_solid(c) and world.eat_tile(c, Players.P1):
					out.append(c)
	return out


func _settle(e: DiskEdge, frames := 600) -> int:
	for i in frames:
		var before := e.shown.duplicate()
		e.step(DT)
		if before == e.shown:
			return i
	return frames


func test_the_level_wall_is_cut_to_the_floor_and_the_edge_starts_whole() -> void:
	var e := _edge()
	assert_object(e).is_not_null()
	assert_object(e.wall).is_not_null()
	var far := 0.0
	for p in e.wall.polygon:
		far = maxf(far, p.length())
	assert_float(far).is_equal_approx(e.floor_r, 1.0)
	assert_float(e.floor_r).is_less(e.outer_r)
	# A fresh planet: the drawn edge is the full radius almost everywhere.
	assert_float(e.mean_radius()).is_greater(e.outer_r - 16.0)
	assert_object(DiskEdge.of(_level.world)).is_same(e)


func test_a_bite_through_the_crust_sinks_the_edge_gradually() -> void:
	_stage5_worm()
	var e := _edge()
	var a := _level.spawn_point.angle() + 0.05
	var mean0 := e.mean_radius()
	assert_float(e.edge_at(a)).is_equal(e.outer_r)
	var eaten := _bite(a, 6)
	assert_int(eaten.size()).is_greater(20)
	# The real edge moved at once, the drawn one has not jumped.
	assert_float(e.target_at(a)).is_less(e.outer_r - 4.0 * 16.0)
	assert_float(e.target_at(a)).is_greater_equal(e.floor_r)
	assert_float(e.edge_at(a)).is_equal(e.outer_r)
	var biggest := 0.0
	var frames := 0
	while e.edge_at(a) > e.target_at(a) and frames < 600:
		var was := e.edge_at(a)
		e.step(DT)
		biggest = maxf(biggest, was - e.edge_at(a))
		frames += 1
	assert_float(e.edge_at(a)).is_equal(e.target_at(a))
	assert_float(biggest).is_less_equal(DiskEdge.SPEED * DT + 0.001)   # never a jump
	assert_int(frames).is_greater(20)                                    # it reads as a sink
	assert_float(e.mean_radius()).is_less(mean0)


func test_the_edge_never_sinks_below_its_floor_and_never_eats_ground() -> void:
	_stage5_worm()
	var world := _level.world
	var e := _edge()
	var a := _level.spawn_point.angle() - 0.08
	_bite(a, 30)
	assert_float(e.target_at(a)).is_equal_approx(e.floor_r, 0.01)
	_settle(e)
	assert_float(e.edge_at(a)).is_equal_approx(e.floor_r, 0.01)
	# The floor sits in the topsoil, well clear of the dirt the worm still needs.
	var rings := world.rings.rings
	var topsoil_top: float = rings[rings.size() - 2].outer * e.outer_r
	var dirt_top: float = rings[rings.size() - 3].outer * e.outer_r
	assert_float(e.floor_r).is_equal_approx(topsoil_top - DiskEdge.TOPSOIL_DENT * 16.0, 0.5)
	assert_float(e.floor_r).is_greater(dirt_top)
	# The edge only draws: stepping it never changes a tile.
	var dir := Vector2.from_angle(a + 0.2)
	var solid_before := 0
	for i in 40:
		solid_before += 1 if world.is_solid(world.shape.cell_at(dir * (e.outer_r - 8.0 - i * 16.0))) else 0
	for i in 120:
		e.step(DT)
	var solid_after := 0
	for i in 40:
		solid_after += 1 if world.is_solid(world.shape.cell_at(dir * (e.outer_r - 8.0 - i * 16.0))) else 0
	assert_int(solid_after).is_equal(solid_before)


func test_the_crust_dent_stays_but_regrown_topsoil_fills_back_in() -> void:
	_stage5_worm()
	var world := _level.world
	var e := _edge()
	var a := _level.spawn_point.angle() + 0.12
	var eaten := _bite(a, 10)
	var crust_gone := eaten.filter(func(c: Vector2i) -> bool: return world.ring_of(c).id == _table.crust_ring())
	assert_int(crust_gone.size()).is_greater(0)
	_settle(e)
	var deep := e.edge_at(a)
	assert_float(deep).is_less(e.outer_r - 6.0 * 16.0)
	# A live chunk there (regrowth runs near a tracked eater), the eater well under the bite.
	var watcher := Node2D.new()
	world.add_child(watcher)
	watcher.position = Vector2.from_angle(a) * (e.outer_r - 40.0 * 16.0)
	world.track_eater(watcher)
	world.update_chunks()
	for i in 40:
		world.advance(60.0)
		world.regrow_pass()
	for c in crust_gone:
		assert_bool(world.is_solid(c)).is_false()   # the crust never grows back
	_settle(e, 2000)
	var crust_floor: float = world.rings.rings[world.rings.rings.size() - 2].outer * e.outer_r
	assert_float(e.edge_at(a)).is_greater(deep)                     # the topsoil filled its dent
	assert_float(e.edge_at(a)).is_less_equal(crust_floor + 16.0)    # the crust's part stays gone
	assert_float(e.mean_radius()).is_less(e.outer_r)
	world.untrack_eater(watcher)
	watcher.free()


func test_open_cells_show_sky_and_sealed_tunnels_keep_their_wall() -> void:
	_stage5_worm()
	var world := _level.world
	var e := _edge()
	var a := _level.spawn_point.angle() - 0.15
	var art := world.tile_art as LanternTileArt
	assert_object(art).is_not_null()
	assert_bool(art.sky_open.is_valid()).is_true()
	# A sealed tunnel: topsoil eaten under a whole crust.
	var dir := Vector2.from_angle(a)
	var sealed := world.shape.cell_at(dir * (e.outer_r - 20.0 * 16.0))
	assert_bool(world.eat_tile(sealed, Players.P1)).is_true()
	assert_float(e.target_at(a)).is_equal(e.outer_r)
	assert_bool(e.is_open_to_sky(sealed)).is_false()
	assert_int(art.wall_coords(sealed, 0, false).x).is_greater_equal(0)
	# A bite open to the sky: no back wall there.
	_bite(a + 0.02, 5)
	var open := world.shape.cell_at(Vector2.from_angle(a + 0.02) * (e.outer_r - 3.0 * 16.0))
	assert_bool(world.is_solid(open)).is_false()
	assert_bool(e.is_open_to_sky(open)).is_true()
	assert_int(art.wall_coords(open, 0, false).x).is_equal(-1)


func test_no_castings_pile_hangs_in_the_open_sky() -> void:
	_stage5_worm()
	var world := _level.world
	var e := _edge()
	var trail := CastingsTrail.ensure(world)
	var a := _level.spawn_point.angle() + 0.2
	_bite(a, 3)          # all rim: open to the sky
	for c in trail.piles:
		assert_bool(e.is_open_to_sky(c)).is_false()
	var open := world.shape.cell_at(Vector2.from_angle(a) * (e.outer_r - 2.0 * 16.0))
	assert_bool(e.is_open_to_sky(open)).is_true()
	assert_bool(trail.add_pile(open, 5, false)).is_false()
	# Under a whole crust the castings still lie on the tunnel floor.
	var sealed := world.shape.cell_at(Vector2.from_angle(a - 0.6) * (e.outer_r - 24.0 * 16.0))
	assert_bool(world.eat_tile(sealed, Players.P1)).is_true()
	assert_bool(e.is_open_to_sky(sealed)).is_false()
	trail.piles.erase(sealed)
	assert_bool(trail.add_pile(sealed, 1, false)).is_true()


func test_the_stage_6_planet_picture_shows_the_bites() -> void:
	_stage5_worm()
	var world := _level.world
	var e := _edge()
	var a := _level.spawn_point.angle() + 0.3
	var img: Image = world._overview   # what ChompDirector.frozen_planet_texture copies
	var r: int = world.shape.radius
	var px := func(c: Vector2i) -> Color: return img.get_pixelv((c + Vector2i(r, r)) / 2)
	var even := func(c: Vector2i) -> Vector2i: return Vector2i(c.x - posmod(c.x + r, 2), c.y - posmod(c.y + r, 2))
	var rim: Vector2i = even.call(world.shape.cell_at(Vector2.from_angle(a) * (e.outer_r - 2.0 * 16.0)))
	assert_float(px.call(rim).a).is_greater(0.5)
	_bite(a, 5)
	assert_bool(e.is_open_to_sky(rim)).is_true()
	assert_float(px.call(rim).a).is_equal(0.0)          # a bite out of the planet's outline
	# A sealed tunnel deep under a whole crust keeps PolarWorld's castings hue.
	var sealed: Vector2i = even.call(world.shape.cell_at(Vector2.from_angle(a - 0.5) * (e.outer_r - 24.0 * 16.0)))
	assert_bool(world.eat_tile(sealed, Players.P1)).is_true()
	assert_bool(e.is_open_to_sky(sealed)).is_false()
	assert_float(px.call(sealed).a).is_greater(0.5)
	# A reloaded tin: a fresh edge on the same world clears the same bite.
	img.set_pixelv((rim + Vector2i(r, r)) / 2, Color.RED)
	var again := DiskEdge.new()
	again.attach(world)
	assert_float(px.call(rim).a).is_equal(0.0)
	again.free()
	world.set_meta(&"disk_edge", e)
	assert_object(DiskEdge.of(world)).is_same(e)
