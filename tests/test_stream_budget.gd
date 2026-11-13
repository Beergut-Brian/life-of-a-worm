## W-23 frame-time budget on the 25-chunk streaming path (worm-gap-close-15), on the planet the game
## really builds (PlanetLevel.RADIUS, the stage table's crust, band 32): each worm keeps one
## chunk_radius-2 neighbourhood, a frame never builds more than chunk_budget_per_frame chunks, a
## frame that builds never also frees, and the script side of one chunk build stays well inside a
## 60 fps frame.
## Measured (worm-gap-close-15): the polar "5x5" is 19 chunks near the core, 23 at 0.2 depth and 31
## (31,376 tiles) from 0.35 depth out, because a band edge with more sectors adds chunks. W-23's
## target is 25 chunks / ~25k tiles, so the worst case is ~25% over; trimming it is a change to
## DiskShape.neighbourhood (addon) or PolarWorld.chunk_radius. These caps lock today's worst case so
## it can't grow while that is decided. Loads and frees are counted
## through the world's chunk_loaded / chunk_freed signals per update_chunks call, never polled.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
## Script-side ms for one chunk build (base tiles, TileMapLayer cells, castings + sizes layers).
## A 60 fps frame is 16.7 ms; the software-renderer box measures ~2.3 ms mean (R-a, loaded box).
## The ceiling is generous because the producer box is shared and swings 3-10x run to run.
const CHUNK_MS_MEAN_MAX := 8.0
## Today's measured worst neighbourhood per worm (see above); W-23's target is 25 / ~25,000.
const HOOD_CHUNKS_MAX := 31
const HOOD_TILES_MAX := 32000

var _loads := 0
var _frees := 0


func _world(radius := PlanetLevel.RADIUS) -> PolarWorld:
	var w := PolarWorld.new()
	w.setup_planet(StageTable.default_table().apply_crust(RINGS), radius, 11, 32)
	add_child(w)
	w.set_physics_process(false)   # the test steps update_chunks itself, one call per "frame"
	w.chunk_loaded.connect(func(_k: Vector2i) -> void: _loads += 1)
	w.chunk_freed.connect(func(_k: Vector2i) -> void: _frees += 1)
	return auto_free(w)


func _eater(w: PolarWorld, angle: float, depth := 0.6) -> Node2D:
	var n := Node2D.new()
	n.position = Vector2.from_angle(angle) * w.shape.radius * depth * w.shape.cell_size
	add_child(n)
	w.track(n)
	return auto_free(n)


## Steps one streaming frame the way TileWorld._physics_process does. Returns [loads, frees].
func _frame(w: PolarWorld) -> Array[int]:
	_loads = 0
	_frees = 0
	w.update_chunks(w.chunk_budget_per_frame)
	return [_loads, _frees]


func _settle(w: PolarWorld, max_frames := 400) -> int:
	var n := 0
	while n < max_frames:
		var f := _frame(w)
		n += 1
		if f[0] == 0 and f[1] == 0:
			break
	return n


func _tiles(w: PolarWorld) -> int:
	var t := 0
	for k in w.loaded_chunks():
		t += w.shape.chunk_cells(k).size()
	return t


func test_one_worm_keeps_one_five_by_five_neighbourhood() -> void:
	var w := _world()
	var e := _eater(w, -PI / 2.0)
	_settle(w)
	var key := w.shape.chunk_of(w.shape.cell_at(e.position))
	var hood := w.shape.neighbourhood(key, w.chunk_radius)
	assert_int(w.chunk_radius).is_equal(2)
	assert_int(w.loaded_chunks().size()).is_equal(hood.size())
	assert_int(w.loaded_chunks().size()).is_less_equal(HOOD_CHUNKS_MAX)
	# Thousands of tiles, never the whole ~280k-tile disk.
	var tiles := _tiles(w)
	assert_int(tiles).is_greater(2000)
	assert_int(tiles).is_less_equal(HOOD_TILES_MAX)


func test_no_depth_or_angle_streams_more_than_the_measured_worst() -> void:
	var w := _world()
	var worst := 0
	var worst_tiles := 0
	for di in 19:
		for ai in 16:
			var p: Vector2 = Vector2.from_angle(TAU * ai / 16.0 + 0.1) * w.shape.radius * (0.05 + di * 0.05) * w.shape.cell_size
			var hood: Array[Vector2i] = w.shape.neighbourhood(w.shape.chunk_of(w.shape.cell_at(p)), w.chunk_radius)
			var t := 0
			for k in hood:
				t += w.shape.chunk_cells(k).size()
			worst = maxi(worst, hood.size())
			worst_tiles = maxi(worst_tiles, t)
	print("stream_budget: worst neighbourhood %d chunks, %d tiles" % [worst, worst_tiles])
	assert_int(worst).is_less_equal(HOOD_CHUNKS_MAX)
	assert_int(worst_tiles).is_less_equal(HOOD_TILES_MAX)


func test_a_frame_builds_at_most_its_budget_and_never_builds_and_frees_together() -> void:
	var w := _world()
	assert_int(w.chunk_budget_per_frame).is_equal(1)
	var e := _eater(w, -PI / 2.0)
	var first := _settle(w)
	# The first neighbourhood streams in over frames, one chunk each, not in one hitch.
	assert_int(first).is_greater_equal(w.loaded_chunks().size())
	# Then the worm swims a quarter of the way round at mid depth, one small step a frame.
	var worst_loads := 0
	var worst_frees := 0
	var both := 0
	var total_loads := 0
	var steps := 240
	for i in steps:
		var a := -PI / 2.0 + (PI / 2.0) * float(i + 1) / steps
		e.position = Vector2.from_angle(a) * w.shape.radius * 0.6 * w.shape.cell_size
		var f := _frame(w)
		worst_loads = maxi(worst_loads, f[0])
		worst_frees = maxi(worst_frees, f[1])
		total_loads += f[0]
		if f[0] > 0 and f[1] > 0:
			both += 1
	_settle(w)
	assert_int(total_loads).override_failure_message("the worm crossed no chunk").is_greater(0)
	assert_int(worst_loads).is_less_equal(w.chunk_budget_per_frame)
	assert_int(worst_frees).is_less_equal(2 * w.chunk_budget_per_frame)
	assert_int(both).is_equal(0)
	assert_int(w.loaded_chunks().size()).is_less_equal(HOOD_CHUNKS_MAX)


func test_two_worms_far_apart_stream_two_neighbourhoods_only() -> void:
	var w := _world()
	_eater(w, -PI / 2.0)
	_eater(w, PI / 2.0)
	_settle(w)
	assert_int(w.loaded_chunks().size()).is_greater(HOOD_CHUNKS_MAX)
	assert_int(w.loaded_chunks().size()).is_less_equal(2 * HOOD_CHUNKS_MAX)


func test_a_chunk_build_fits_well_inside_a_frame() -> void:
	var w := _world()
	var e := _eater(w, 0.0)
	_settle(w)
	w.chunk_build_ms.clear()
	for i in 360:
		var a := TAU * float(i + 1) / 360.0
		e.position = Vector2.from_angle(a) * w.shape.radius * 0.6 * w.shape.cell_size
		_frame(w)
	var n := w.chunk_build_ms.size()
	assert_int(n).is_greater(10)
	var sum := 0.0
	for ms in w.chunk_build_ms:
		sum += ms
	var mean := sum / n
	print("stream_budget: %d chunk builds, mean %.2f ms (ceiling %.1f)" % [n, mean, CHUNK_MS_MEAN_MAX])
	assert_float(mean).is_less(CHUNK_MS_MEAN_MAX)
