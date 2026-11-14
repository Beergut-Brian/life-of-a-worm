## Polar chunks on the disk: cell <-> chunk round trips in every quadrant and across the 0 / TAU
## seam, gravity toward the core, and one 5x5 neighbourhood per eater (two eaters, two sets).
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")


func _world(radius := 160) -> PolarWorld:
	var w := PolarWorld.new()
	w.setup_planet(RINGS, radius, 7)
	add_child(w)
	w.set_physics_process(false)
	return auto_free(w)


func _anchor(w: PolarWorld, cell: Vector2i) -> Node2D:
	var n := Node2D.new()
	n.position = w.shape.center_of(cell)
	add_child(n)
	return auto_free(n)


func test_cell_chunk_round_trip_every_quadrant() -> void:
	var w := _world()
	var disk := w.shape as DiskShape
	for r in [2.0, 20.0, 47.0, 100.0, 150.0]:
		for q in 4:
			for a in [0.07, 0.6, 1.2, 1.5]:
				var ang: float = q * PI / 2.0 + a
				var cell := Vector2i((Vector2.from_angle(ang) * r).floor())
				var key := disk.chunk_of(cell)
				assert_bool(disk.chunk_cells(key).has(cell)).override_failure_message("%s not in its chunk %s" % [cell, key]).is_true()
				# Sector lies in the angle's quadrant (ring 0 has exactly 4 sectors, one per quadrant).
				var n := disk.sectors_in(key.x)
				var mid_angle := fposmod((Vector2(cell) + Vector2(0.5, 0.5)).angle(), TAU)
				assert_int(key.y).is_equal(mini(int(mid_angle / TAU * n), n - 1))
				for c in disk.chunk_cells(key):
					if disk.chunk_of(c) != key:
						fail("chunk %s lists %s which maps to %s" % [key, c, disk.chunk_of(c)])
						return


func test_seam_at_zero_angle() -> void:
	var w := _world()
	var disk := w.shape as DiskShape
	var above := Vector2i(100, 0)   # mid (100.5, 0.5): angle just over 0
	var below := Vector2i(100, -1)  # mid (100.5, -0.5): angle just under TAU
	var ka := disk.chunk_of(above)
	var kb := disk.chunk_of(below)
	assert_int(ka.x).is_equal(kb.x)
	assert_int(ka.y).is_equal(0)
	assert_int(kb.y).is_equal(disk.sectors_in(kb.x) - 1)
	assert_bool(disk.neighbourhood(ka, 1).has(kb)).is_true()
	assert_bool(disk.neighbourhood(kb, 1).has(ka)).is_true()
	assert_bool(disk.chunk_cells(ka).has(above)).is_true()
	assert_bool(disk.chunk_cells(kb).has(below)).is_true()


func test_every_cell_in_exactly_one_chunk() -> void:
	var w := _world(96)
	var disk := w.shape as DiskShape
	var seen := {}
	for ring in disk.rings():
		for s in disk.sectors_in(ring):
			for c in disk.chunk_cells(Vector2i(ring, s)):
				assert_bool(seen.has(c)).override_failure_message("%s twice" % c).is_false()
				seen[c] = true
	var inside := 0
	for y in range(-96, 96):
		for x in range(-96, 96):
			if disk.contains(Vector2i(x, y)):
				inside += 1
	assert_int(seen.size()).is_equal(inside)


func test_gravity_points_at_the_core() -> void:
	var w := _world()
	var shape := w.shape
	for i in 12:
		var p := Vector2.from_angle(TAU * i / 12.0 + 0.1) * 1500.0
		var g := shape.gravity_at(p)
		assert_float(g.length()).is_equal_approx(shape.gravity, 0.01)
		assert_float(g.normalized().dot(-p.normalized())).is_equal_approx(1.0, 0.0001)
		var cell := shape.cell_at(p)
		var down := shape.below(cell)
		assert_bool(Vector2(down).length() < Vector2(cell).length()).is_true()
	assert_vector(shape.gravity_at(Vector2.ZERO)).is_equal(Vector2.ZERO)


func test_camera_up_is_away_from_the_core() -> void:
	for i in 8:
		var p := Vector2.from_angle(TAU * i / 8.0) * 1000.0
		var up_on_screen := Vector2.UP.rotated(PolarCamera.up_rotation(p))
		assert_float(up_on_screen.dot(p.normalized())).is_equal_approx(1.0, 0.0001)


func test_two_eaters_two_neighbourhoods() -> void:
	# Mid-disk (ring band 6 of 10), so no neighbourhood is clipped by the rim or the core.
	var w := _world(320)
	var disk := w.shape as DiskShape
	assert_int(w.chunk_radius).is_equal(2)
	var a := _anchor(w, Vector2i(0, -200))
	var b := _anchor(w, Vector2i(0, 199))
	w.track_eater(a)
	w.track_eater(b)
	w.update_chunks(-1)
	var na := disk.neighbourhood(disk.chunk_of(Vector2i(0, -200)), 2)
	var nb := disk.neighbourhood(disk.chunk_of(Vector2i(0, 199)), 2)
	# The rounded 5x5 (PolarShape, W-23): never clipped here, never over the brief's 25.
	assert_int(na.size()).is_between(20, 25)
	assert_int(nb.size()).is_between(20, 25)
	for k in na:
		assert_bool(nb.has(k)).override_failure_message("opposite sides share chunk %s" % k).is_false()
	var want := {}
	for k in na + nb:
		want[k] = true
	var live := w.loaded_chunks()
	assert_int(live.size()).is_equal(want.size())
	for k in live:
		assert_bool(want.has(k)).is_true()
	# One eater leaves: only its own neighbourhood goes.
	w.untrack_eater(b)
	w.update_chunks(-1)
	assert_int(w.loaded_chunks().size()).is_equal(na.size())
