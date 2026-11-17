## W-23 (worm-gap-close-47): what an autosave costs the frame it runs in. Streaming itself is
## measured in test_stream_budget.gd (one chunk build a frame, mean well under 8 ms), so the brief's
## "C# chunk serialiser only if streaming stutters" turns on the one other place the world is
## serialised: `PlanetLevel.save_now()`, every `PlanetLevel.AUTOSAVE` (30) s, on the main thread.
## It calls `PolarWorld.to_save()` (walks every edit, regrow time, casting and food size) and then
## `Save.flush()` turns the whole tin into tab-indented JSON and writes it. Both scale with the
## cells the worms have eaten, and castings are kept for good (a regrown tile keeps its castings, so
## it regrows faster next time), so the cost grows with every cell ever eaten, never shrinks.
##
## This suite prints the cost at two loads (the steady state of R-a's 10 min two-worm stress run,
## ~14,000 edits and ~15,000 castings, and four times that), checks the save still round-trips, and
## fails only if the cost per cell gets several times worse than measured. It never touches `Save`
## (no tin, no settings file is written).
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const FRAME_MS := 1000.0 / 60.0
## Cells eaten (each one is an edit, a regrow time and a casting until it regrows).
const LOADS := [14000, 56000]
## Measured on the producer box (llvmpipe, other lanes running): ~2.5 us a cell in to_save and
## ~1.4 us in the JSON, so ~4 us. The ceiling only catches a several-fold regression.
const MAX_US_PER_CELL := 25.0


func _played(cells: int) -> PolarWorld:
	var w := PolarWorld.new()
	w.build_overview = false
	w.setup_planet(StageTable.default_table().apply_crust(RINGS), PlanetLevel.RADIUS, 7, 32)
	for p in 2:
		w.set_stage(p, 7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	var n := 0
	var tries := 0
	while n < cells and tries < cells * 20:
		tries += 1
		var dir := Vector2.from_angle(rng.randf() * TAU)
		var cell := w.shape.cell_at(dir * rng.randf_range(20.0, PlanetLevel.RADIUS - 1.0) * 16.0)
		if w.is_solid(cell) and w.eat_tile(cell, n % 2):
			n += 1
	return w


func test_an_autosave_costs_a_known_share_of_a_frame_per_eaten_cell() -> void:
	for cells: int in LOADS:
		var w := _played(cells)
		assert_int(w.edits.tiles.size()).is_equal(cells)
		assert_int(w.castings_count()).is_equal(cells)
		var t0 := Time.get_ticks_usec()
		var data := w.to_save()
		var t1 := Time.get_ticks_usec()
		var json := JSON.stringify({"planet": data}, "\t")   # Save.flush() writes the tin this way
		var t2 := Time.get_ticks_usec()
		var save_ms := (t1 - t0) / 1000.0
		var json_ms := (t2 - t1) / 1000.0
		var total := save_ms + json_ms
		print("w23 autosave: %d cells eaten -> to_save %.1f ms + json %.1f ms = %.1f ms on the main thread (%.1f frames at 60 fps), %d KB, %.2f us a cell" % [
			cells, save_ms, json_ms, total, total / FRAME_MS, json.length() / 1024, total * 1000.0 / cells])
		assert_float(total * 1000.0 / cells).override_failure_message(
			"an autosave costs %.1f us a cell (ceiling %.1f)" % [total * 1000.0 / cells, MAX_US_PER_CELL]
		).is_less(MAX_US_PER_CELL)
		# Still a faithful save: a fresh world loaded from it has the same edits and castings.
		var back := PolarWorld.new()
		back.build_overview = false
		back.setup_planet(StageTable.default_table().apply_crust(RINGS), PlanetLevel.RADIUS, 7, 32)
		back.load_save(JSON.parse_string(json).planet)
		assert_bool(back.edits.tiles == w.edits.tiles).is_true()
		assert_int(back.castings_count()).is_equal(w.castings_count())
		back.free()
		w.free()


func test_castings_outlive_regrowth_so_the_save_only_grows() -> void:
	var w := _played(400)
	var before := JSON.stringify(w.to_save()).length()
	var cells: Array = w.edits.tiles.keys()
	for cell: Vector2i in cells:
		w._regrow(cell)   # what a due regrow pass does to each cell
	assert_int(w.edits.tiles.size()).is_equal(0)
	assert_int(w.castings_count()).is_equal(400)
	var after := JSON.stringify(w.to_save()).length()
	print("w23 autosave: 400 cells eaten %d bytes, all regrown %d bytes (castings kept)" % [before, after])
	assert_int(after).is_greater(0)
	assert_array(w.to_save().castings).has_size(800)
	w.free()
