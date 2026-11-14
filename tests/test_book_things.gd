## T-05 (feature/worm-gap-close-40): the surface's things have their own page. Every prop in
## data/props/ (house, car, cow, tree, fence, hill, water tower, diner, court, dock shed, crate) is
## a sketch in the collection book and in Old Reel's tackle box: grey outline until a worm breaks
## one, then the picture it has on the planet. The first break of a kind plays the page sound once;
## bonks and bites that leave it standing find nothing; the page is kept in the tin, a tin whose
## props were broken before the page existed gets them silently, and the full page pins a lure.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const BOOK := preload("res://scenes/ui/book.tscn")
const UP := -PI / 2.0

var _keep: Array[Node] = []


func before() -> void:
	SuiteSandbox.enter("book_things")


func after() -> void:
	for p in Audio._pool:
		p.stop()
	SuiteSandbox.leave()


func before_test() -> void:
	Save.wipe()
	Audio.played.clear()


func after_test() -> void:
	get_tree().paused = false
	for i in range(_keep.size() - 1, -1, -1):
		var n := _keep[i]
		if is_instance_valid(n):
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.free()
	_keep.clear()


func _add(n: Node) -> Node:
	add_child(n)
	_keep.append(n)
	return n


func _world() -> PolarWorld:
	var w := PolarWorld.new()
	w.build_overview = false
	w.setup_planet(RINGS, 160, 7)
	_add(w)
	w.set_physics_process(false)
	return w


## The whole town stood on a small planet, nothing moving.
func _town(w: PolarWorld, saved := {}) -> WorldDestruct:
	var d := WorldDestruct.new()
	_add(d)
	d.set_physics_process(false)
	var foods := Node2D.new()
	_add(foods)
	d.setup(w, Vector2.from_angle(UP) * 1000.0, saved, foods)
	for p in d.props.values():
		p.set_physics_process(false)
		p.fall.set_physics_process(false)
	return d


func _log() -> TackleLog:
	return _add(TackleLog.new()) as TackleLog


func _break(p: SurfaceProp) -> void:
	for i in p.data.hits:
		p.bite(1, 7)
	for f in p.chunks_out:   # the chunks are test litter: keep them still and free them after
		if is_instance_valid(f):
			f.get_node("Fall").set_physics_process(false)
			_keep.append(f)


func _prop_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for d in WorldDestruct.load_props():
		ids.append(d.id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func test_every_surface_thing_has_a_sketch_in_the_book_and_the_box() -> void:
	var ids := _prop_ids()
	assert_int(ids.size()).is_greater_equal(11)
	assert_bool(BookCatalog.SECTIONS.has(&"things")).is_true()
	assert_array(BookCatalog.entries(&"things").map(func(e): return e.id)).is_equal(ids)
	for e in BookCatalog.entries(&"things"):
		assert_bool(e.data is PropData).is_true()
	assert_bool(TackleLog.PAGES.has(&"things")).is_true()
	var tlog := _log()
	assert_array(tlog.entries[&"things"]).is_equal(ids)
	# The book has a page node for the section, and every section a colour and a tab that fits.
	var b: Book = _add(BOOK.instantiate())
	var pages := b.get_node("Pages").get_children().filter(func(n): return n is BookPage and n.section == &"things")
	assert_int(pages.size()).is_equal(1)
	for s in BookCatalog.SECTIONS:
		assert_bool(BookArt.SECTION_COLORS.has(s)).is_true()
	for p in TackleLog.PAGES:
		assert_bool(TackleBox.PAGE_COLORS.has(p)).is_true()
	assert_float(TackleBox.tab_step() * TackleLog.PAGES.size()).is_less_equal(730.0)   # tabs stay on the tin


func test_every_sketch_fits_its_cell() -> void:
	for d in WorldDestruct.load_props():
		var k := PropSketch.scale_for(d, 132.0)
		assert_float(d.size.x * 16.0 * k).override_failure_message("%s too wide" % d.id).is_less_equal(132.01)
		assert_float(d.size.y * 16.0 * k).override_failure_message("%s too tall" % d.id).is_less_equal(132.01)
		# Something of it is drawn: at least one footprint cell is filled.
		var cells := 0
		for y in d.size.y:
			for x in d.size.x:
				if PropLook.filled(d.look, d.size, x, y):
					cells += 1
		assert_int(cells).override_failure_message("%s draws nothing" % d.id).is_greater(0)


func test_breaking_a_thing_finds_its_sketch_once_with_the_page_sound() -> void:
	var w := _world()
	var tlog := _log()          # made first: the props hook in as they are stood
	var town := _town(w)
	var seen := []
	tlog.unlocked.connect(func(page: StringName, id: StringName) -> void: seen.append([page, id]))
	var house: SurfaceProp = town.props["house_0"]
	# Too small: a bonk finds nothing.
	assert_bool(house.bite(1, 2)).is_false()
	assert_bool(tlog.is_found(&"things", &"house")).is_false()
	# Bitten but standing: still nothing.
	assert_bool(house.bite(1, 7)).is_true()
	assert_bool(house.broken).is_false()
	assert_bool(tlog.is_found(&"things", &"house")).is_false()
	assert_int(int(Audio.played.get("page_new", 0))).is_equal(0)
	_break(house)
	assert_bool(house.broken).is_true()
	assert_bool(tlog.is_found(&"things", &"house")).is_true()
	assert_array(seen).is_equal([[&"things", &"house"]])
	assert_int(int(Audio.played.get("page_new", 0))).is_equal(1)
	assert_int(tlog.fresh).is_equal(1)   # the Y hint glows
	# The second house is the same sketch: no second sound.
	_break(town.props["house_1"])
	assert_int(int(Audio.played.get("page_new", 0))).is_equal(1)
	assert_int(seen.size()).is_equal(1)
	# Another kind is another sketch.
	_break(town.props["cow_0"])
	assert_bool(tlog.is_found(&"things", &"cow")).is_true()
	assert_int(int(Audio.played.get("page_new", 0))).is_equal(2)
	# The book reads the same found-set (the log is live in the tree).
	assert_array(BookCatalog.found_set(get_tree())[&"things"]).contains_exactly_in_any_order([&"house", &"cow"])


func test_things_stood_before_the_log_are_found_too() -> void:
	var w := _world()
	var town := _town(w)        # the level stands its props before the home slice makes the log
	var tlog := _log()
	_break(town.props["tree_0"])
	assert_bool(tlog.is_found(&"things", &"tree")).is_true()


func test_the_page_is_kept_in_the_tin_and_the_full_page_pins_a_lure() -> void:
	var w := _world()
	var tlog := _log()
	var town := _town(w)
	var pinned := []
	tlog.page_completed.connect(func(p: StringName) -> void: pinned.append(p))
	var ids := _prop_ids()
	for i in ids.size() - 1:
		_break(town.props["%s_0" % ids[i]])
	assert_bool(tlog.is_complete(&"things")).is_false()
	assert_array(pinned).is_empty()
	# Saved and loaded: the same sketches, no sounds on load.
	var saved := tlog.to_dict()
	var again := _log()
	var cues0 := int(Audio.played.get("page_new", 0))
	again.from_dict(saved)
	assert_array(again.found[&"things"]).contains_exactly_in_any_order(tlog.found[&"things"])
	assert_int(int(Audio.played.get("page_new", 0))).is_equal(cues0)
	_keep.erase(again)
	remove_child(again)
	again.free()   # or it would hear the last break too
	# The last kind completes the page: one lure, once.
	_break(town.props["%s_0" % ids[-1]])
	assert_bool(tlog.is_complete(&"things")).is_true()
	assert_array(pinned).is_equal([&"things"])
	assert_array(tlog.lures).contains([&"things"])
	assert_int(int(Audio.played.get("lure_pin", 0))).is_equal(1)


func test_a_tin_from_before_the_page_gets_its_broken_things_silently() -> void:
	# An old tin: the house and one of two cows were broken, the car only bitten; no "things" saved.
	Save.set_value(WorldDestruct.SAVE_KEY, { "props": { "house_0": 0, "house_1": 0, "cow_1": 0, "car_0": 2 } })
	var tlog := _log()
	tlog.from_dict({ "found": { "foods": ["grub"] }, "lures": [], "fresh": 0 })
	assert_bool(tlog.is_found(&"things", &"house")).is_true()
	assert_bool(tlog.is_found(&"things", &"cow")).is_true()
	assert_bool(tlog.is_found(&"things", &"car")).is_false()
	assert_bool(tlog.is_found(&"foods", &"grub")).is_true()
	assert_int(int(Audio.played.get("page_new", 0))).is_equal(0)
	assert_int(tlog.fresh).is_equal(0)
	# A key with underscores in the id (water_tower_0, dock_shed_0) reads back whole.
	tlog.sync_broken({ "water_tower_0": 0, "dock_shed_0": 0, "not_a_thing_3": 0 })
	assert_bool(tlog.is_found(&"things", &"water_tower")).is_true()
	assert_bool(tlog.is_found(&"things", &"dock_shed")).is_true()
	assert_int(tlog.found[&"things"].size()).is_equal(4)


func test_the_tackle_box_and_the_book_draw_the_page_found_and_unfound() -> void:
	var tlog := _log()
	var box := TackleBox.new()
	box.tlog = tlog
	box.pause_tree = false
	_add(box)
	box.open(Players.P1)
	while box.page_id() != &"things":
		box.nav(0, 1)
	await get_tree().process_frame
	for id in tlog.entries[&"things"]:
		tlog.unlock(&"things", id)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(box.is_open).is_true()
	assert_int(box.shown_rows().x).is_equal(0)
	box.close()
	var b: Book = _add(BOOK.instantiate())
	b.pause_tree = false
	b.open(Players.P1)
	b.section = BookCatalog.SECTIONS.find(&"things")
	await get_tree().process_frame
	assert_bool(b.is_found(&"things", &"house")).is_true()
	await get_tree().process_frame
	b.close()
