## T-01: the in-game tackle box (Y) shows every sketch of every page. A page longer than the paper's
## four rows (foods, traits) scrolls a row at a time so the cursor's sketch is always on the paper,
## with a pencil arrow at the edge while rows are hidden. Every push still ticks. Own Save profile.
class_name TestTackleBoxPages
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")
## A doodle's reach round its centre (the 58 px dotted ring of an unfound sketch, plus pencil).
const DOODLE_R := 62.0

var _level: PlanetLevel


func before() -> void:
	SuiteSandbox.enter("tackle_pages")


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	SuiteSandbox.leave()


func before_test() -> void:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	Audio.played.clear()


func after_test() -> void:
	for p in Audio._pool:
		p.stop()
	if is_instance_valid(_level):
		remove_child(_level)
		_level.free()
	_level = null
	get_tree().paused = false
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _box() -> TackleBox:
	BaitTins.open(0)
	Save.wipe()
	_level = PLANET.instantiate()
	add_child(_level)
	var box := _level.home_slice.box
	box.pause_tree = false
	box.open(Players.P1)
	return box


func _to_page(box: TackleBox, id: StringName) -> void:
	while box.page_id() != id:
		box.nav(0, 1)


func test_the_paper_holds_four_rows() -> void:
	# The last drawn row's doodles end on the paper, so a page never draws past its bottom edge,
	# and the first row clears the top-edge arrow.
	assert_float(TackleBox.FIRST_ROW + (TackleBox.ROWS - 1) * TackleBox.ROW_H + DOODLE_R).is_less(TackleBox.PAPER_H - 30.0)
	assert_float(TackleBox.FIRST_ROW - DOODLE_R).is_greater(30.0)


func test_long_pages_exist_so_the_scroll_is_needed() -> void:
	var box := _box()
	var longest := 0
	for p in TackleLog.PAGES:
		longest = maxi(longest, (box.tlog.entries[p] as Array).size())
	assert_int(longest).is_greater(TackleBox.COLS * TackleBox.ROWS)


func test_every_sketch_of_every_page_comes_onto_the_paper() -> void:
	var box := _box()
	for p in TackleLog.PAGES:
		_to_page(box, p)
		var n: int = (box.tlog.entries[p] as Array).size()
		assert_int(box.cursor).is_equal(0)
		assert_int(box.shown_rows().x).is_equal(0)
		var ticks0: int = Audio.played.get("box_tick", 0)
		for i in n:
			var shown := box.shown_rows()
			var row := box.cursor / TackleBox.COLS
			assert_bool(row >= shown.x and row <= shown.y) \
				.override_failure_message("%s sketch %d (row %d) is off the paper (rows %s)" % [p, box.cursor, row, shown]).is_true()
			assert_int(shown.y - shown.x).is_less(TackleBox.ROWS)
			if i < n - 1:
				box.nav(1, 0)
		assert_int(box.cursor).is_equal(n - 1)
		assert_int(Audio.played.get("box_tick", 0) - ticks0).is_equal(maxi(0, n - 1))   # every push ticks
		if n > 1:
			box.nav(1, 0)   # wraps back to the first sketch, and the page scrolls back up with it
			assert_int(box.cursor).is_equal(0)
			assert_int(box.shown_rows().x).is_equal(0)
		box.nav(0, 1)


func test_the_foods_page_scrolls_one_row_at_a_time() -> void:
	var box := _box()
	_to_page(box, &"foods")
	var n: int = (box.tlog.entries[&"foods"] as Array).size()
	var last_top := 0
	for i in n - 1:
		box.nav(1, 0)
		var top := box.top_row()
		assert_int(top - last_top).is_between(0, 1)
		last_top = top
	assert_int(last_top).is_equal(ceili(n / float(TackleBox.COLS)) - TackleBox.ROWS)
