## The bait-tin dock shows what is inside each tin as a picture (P-05, C-22): a played tin stands open
## with its worms peeking out (player colour, diet stripes, stage size) and its stage pips; an empty
## tin keeps its lid on. Writes tin files into this suite's own profile.
class_name TestDockTins
extends GdUnitTestSuite


func before() -> void:
	SuiteSandbox.enter("dock_tins")


func after() -> void:
	for i in BaitTins.COUNT:
		_remove(i)
	SuiteSandbox.leave()


func before_test() -> void:
	for i in BaitTins.COUNT:
		_remove(i)


func _remove(i: int) -> void:
	var path := Save.path_for(BaitTins.slot_name(i))
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _write(i: int, worms: Dictionary, stage: int) -> void:
	DirAccess.make_dir_recursive_absolute("user://saves")
	var f := FileAccess.open(Save.path_for(BaitTins.slot_name(i)), FileAccess.WRITE)
	f.store_string(JSON.stringify({ "planet": {"x": 1}, "worms": worms, "stage": stage, "played": 600.0 }))
	f.close()


func _segs(n: int, cycle: Array) -> Array:
	var out := []
	for k in n:
		out.append(cycle[k % cycle.size()])
	return out


func test_an_empty_tin_keeps_its_lid_on() -> void:
	var pic := Dock.picture(BaitTins.summary(0))
	assert_bool(pic.open).is_false()
	assert_int(pic.pips).is_equal(0)
	assert_array(pic.worms).is_empty()


func test_a_played_tin_shows_each_worm_with_its_stripes_and_stage() -> void:
	_write(1, { "1": { "segments": _segs(22, ["bug", ""]), "stage": 4 },
		"0": { "segments": _segs(9, ["root", "stone", ""]), "stage": 2 } }, 4)
	var s := BaitTins.summary(1)
	assert_int(s.bodies.size()).is_equal(2)
	var pic := Dock.picture(s)
	assert_bool(pic.open).is_true()
	assert_int(pic.pips).is_equal(4)
	assert_int(pic.worms[0].player).is_equal(0)   # green first, then red
	assert_int(pic.worms[1].player).is_equal(1)
	assert_int(pic.worms[0].stage).is_equal(2)
	assert_int(pic.worms[1].stage).is_equal(4)
	# Longer worms peek out further; the stripes are the newest segments' flavours.
	assert_int(pic.worms[1].shown).is_greater(pic.worms[0].shown)
	assert_int(pic.worms[0].stripes.size()).is_equal(pic.worms[0].shown)
	assert_str(String(pic.worms[0].stripes[-1])).is_equal("")       # segment 9 of root, stone, ""
	assert_str(String(pic.worms[0].stripes[-2])).is_equal("stone")


func test_a_very_long_worm_is_capped_and_stage_pips_stop_at_seven() -> void:
	_write(2, { "0": { "segments": _segs(60, ["water"]), "stage": 9 } }, 9)
	var pic := Dock.picture(BaitTins.summary(2))
	assert_int(pic.worms[0].shown).is_equal(Dock.SHOW_SEGS)
	assert_int(pic.pips).is_equal(Dock.PIPS)


func test_the_dock_draws_every_kind_of_tin() -> void:
	_write(1, { "0": { "segments": _segs(5, ["root"]), "stage": 1 } }, 1)
	_write(2, { "0": { "segments": [], "stage": 3 }, "1": { "segments": _segs(12, ["bug"]), "stage": 3 } }, 3)
	var layer := CanvasLayer.new()
	add_child(layer)
	var d := Dock.new()
	layer.add_child(d)
	d.open()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(d.visible).is_true()
	assert_bool(Dock.picture(d._summaries[0]).open).is_false()
	assert_bool(Dock.picture(d._summaries[2]).open).is_true()
	layer.queue_free()
	await get_tree().process_frame


## worm-jar-reconcile-1: the jar shelf spot (Dock.SHELF) sits right of the three tin pictures, the
## stick wraps over it, and the tin's Continue / New world choices (TinFresh) are never offered on it.
func test_the_shelf_spot_sits_right_of_the_tins_and_tin_choices_skip_it() -> void:
	_write(2, { "0": { "segments": _segs(5, ["root"]), "stage": 2 } }, 2)
	var w := 1920.0
	for i in BaitTins.COUNT:
		assert_float(Dock.tin_x(i, w)).is_less(Dock.tin_x(Dock.SHELF, w))
		if i > 0:
			assert_float(Dock.tin_x(i, w) - Dock.tin_x(i - 1, w)).is_greater(200.0)   # tins never overlap
	var layer := CanvasLayer.new()
	add_child(layer)
	var d := Dock.new()
	layer.add_child(d)
	var tf := TinFresh.new()
	tf.dock = d
	layer.add_child(tf)
	d.open()
	d.focus = 2
	assert_int(tf.tin()).is_equal(2)
	assert_bool(tf.can_new(tf.tin())).is_true()
	d.move(1)
	assert_int(d.focus).is_equal(Dock.SHELF)
	assert_int(tf.tin()).is_equal(-1)
	assert_bool(tf.can_new(tf.tin())).is_false()
	d.move(1)
	assert_int(d.focus).is_equal(0)
	layer.queue_free()
	await get_tree().process_frame
