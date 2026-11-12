## The collection book (feature/worm-book-1): reads every data file it lists, shows a grey silhouette
## until an entry is found and the picture after, its cursor moves one step per push and never the
## worm, the found-set comes back from the tin, and Y on the pause menu opens it (B shuts it again).
class_name TestBook
extends GdUnitTestSuite

const SUITE := "book"
const BOOK := preload("res://scenes/ui/book.tscn")
const PAUSE := preload("res://scenes/ui/pause_menu.tscn")
const PLANET := preload("res://scenes/levels/planet.tscn")

var _book: Book
var _level: PlanetLevel
var _pm: Control
var _log: TackleLog
var _pressed: Array[String] = []


func before() -> void:
	SuiteSandbox.enter(SUITE)


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	SuiteSandbox.leave()


func before_test() -> void:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	Save.use_slot("")
	Save.wipe()
	get_tree().paused = false


func after_test() -> void:
	for a in _pressed:
		Input.action_release(a)
	_pressed.clear()
	for p in Audio._pool:
		p.stop()
	for n: Node in [_book, _pm, _log]:
		if is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.free()
	if is_instance_valid(_level):
		for n in _level.find_children("*", "AudioStreamPlayer", true, false):
			n.stop()
		remove_child(_level)
		_level.free()
	_book = null
	_pm = null
	_log = null
	_level = null
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _new_book() -> Book:
	_book = BOOK.instantiate()
	add_child(_book)
	return _book


func _press(player: int, action: String) -> void:
	var a := Players.action(player, action)
	Input.action_press(a)
	_pressed.append(a)


func _release_all() -> void:
	for a in _pressed:
		Input.action_release(a)
	_pressed.clear()


# --- data ----------------------------------------------------------------------------------------

func test_every_listed_data_file_loads() -> void:
	for s in BookCatalog.SECTIONS:
		var files := BookCatalog.files(s)
		assert_bool(files.is_empty()).override_failure_message("no data for %s" % s).is_false()
		for path in files:
			if path.ends_with(".json"):
				assert_bool(JSON.parse_string(FileAccess.get_file_as_string(path)) is Dictionary) \
					.override_failure_message(path).is_true()
			else:
				assert_object(load(path)).override_failure_message(path).is_not_null()
		var list := BookCatalog.entries(s)
		assert_bool(list.is_empty()).override_failure_message("no entries for %s" % s).is_false()
		for e in list:
			assert_str(String(e.id)).is_not_empty()
	# Every food, creature, trait, secret and cutscene the data defines is a slot; nothing else is.
	assert_int(BookCatalog.entries(&"foods").size()).is_equal(_count_class("res://data/foods/", "FoodData"))
	assert_int(BookCatalog.entries(&"traits").size()).is_equal(_count_class("res://data/traits/", "TraitData"))
	assert_int(BookCatalog.entries(&"secrets").size()).is_equal(_count_class("res://data/secrets/", "SecretData"))
	assert_int(BookCatalog.entries(&"creatures").size()) \
		.is_equal(_count_class("res://data/creatures/", "CreatureData") + _count_class("res://data/pets/", "PetData"))
	assert_int(BookCatalog.entries(&"cutscenes").size()).is_equal(BookCatalog.files(&"cutscenes").size())
	# worm_rules.tres sits in data/traits/ but is not a trait.
	var trait_ids := BookCatalog.entries(&"traits").map(func(e): return e.id)
	assert_bool(trait_ids.has(&"worm_rules")).is_false()
	# Cutscenes follow the story order.
	assert_str(String(BookCatalog.entries(&"cutscenes")[0].id)).is_equal("opening")


func _count_class(dir: String, cls: String) -> int:
	var n := 0
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with(".tres") and BookCatalog.is_class_or_sub(load(dir + f).get_script(), cls):
			n += 1
	return n


func test_every_page_draws_every_entry_both_ways() -> void:
	var b := _new_book()
	b.pause_tree = false
	b.open(Players.P1)
	# Draw each page with nothing found, then with everything found: no errors, one sketch each.
	for pass_found in [false, true]:
		for s in BookCatalog.SECTIONS:
			var ids: Array[StringName] = []
			if pass_found:
				for e in b.entries[s]:
					ids.append(e.id)
			b.found[s] = ids
		for i in BookCatalog.SECTIONS.size():
			b.section = i
			await get_tree().process_frame
			await get_tree().process_frame
	assert_bool(b.is_open).is_true()


# --- silhouette -> found -------------------------------------------------------------------------

func test_silhouette_until_found_then_picture() -> void:
	_log = TackleLog.new()
	add_child(_log)
	var b := _new_book()
	b.pause_tree = false
	b.open(Players.P1)
	assert_bool(b.is_found(&"foods", &"seed")).is_false()
	var none := BookCatalog.count(b.entries[&"foods"], b.found[&"foods"])
	b.close()
	_log.unlock(&"foods", &"seed")
	b.open(Players.P1)
	assert_bool(b.is_found(&"foods", &"seed")).is_true()
	assert_int(BookCatalog.count(b.entries[&"foods"], b.found[&"foods"])).is_equal(none + 1)
	# The live log wins over the tin while a game is running.
	assert_object(BookCatalog.live_log(get_tree())).is_same(_log)


# --- cursor --------------------------------------------------------------------------------------

func test_cursor_moves_one_step_and_tabs_turn_sections() -> void:
	var b := _new_book()
	b.pause_tree = false
	b.open(Players.P1)
	assert_int(b.cursor).is_equal(0)
	b.nav(1, 0)
	assert_int(b.cursor).is_equal(1)
	b.nav(0, 1)
	assert_int(b.cursor).is_equal(1 + Book.COLS)
	b.nav(0, -1)
	b.nav(-1, 0)
	assert_int(b.cursor).is_equal(0)
	assert_bool(b.on_tabs).is_false()
	b.nav(-1, 0)   # off the first column: onto the tabs
	assert_bool(b.on_tabs).is_true()
	b.nav(0, -1)   # already the first section: a bump, nothing moves
	assert_str(String(b.section_id())).is_equal("foods")
	assert_float(b.bump).is_greater(0.0)
	b.nav(0, 1)
	assert_str(String(b.section_id())).is_equal("creatures")
	assert_int(b.cursor).is_equal(0)
	b.nav(1, 0)
	assert_bool(b.on_tabs).is_false()
	# Every move made a sound.
	assert_int(Audio.played.get("book_tick", 0)).is_greater(0)
	assert_int(Audio.played.get("book_flip", 0)).is_greater(0)
	assert_int(Audio.played.get("bonk", 0)).is_greater(0)


func test_the_cursor_never_moves_the_worm() -> void:
	BaitTins.open(0)
	Save.wipe()
	Players.join_virtual(Players.P1)
	_level = PLANET.instantiate()
	add_child(_level)
	var w := _level.spawn_worm(Players.P1)
	for i in 30:
		await get_tree().physics_frame
	var b := _new_book()
	b.open(Players.P1)
	assert_bool(get_tree().paused).is_true()
	var at := w.head.global_position
	var box := w.body_rect()
	for i in 6:
		await get_tree().process_frame
		_press(Players.P1, "move_right" if i % 2 == 0 else "move_down")
		await get_tree().process_frame
		_release_all()
	for i in 10:
		await get_tree().physics_frame
	assert_bool(b.cursor > 0).override_failure_message("the stick should have moved the cursor").is_true()
	assert_vector(w.head.global_position).is_equal(at)
	assert_object(w.body_rect()).is_equal(box)
	b.close()
	assert_bool(get_tree().paused).is_false()


# --- save ----------------------------------------------------------------------------------------

func test_a_saved_found_set_round_trips_through_the_tin() -> void:
	BaitTins.open(1)
	Save.wipe()
	var log := TackleLog.new()
	log.from_dict({ "found": { "foods": ["seed", "grub"], "creatures": ["beetle"], "traits": ["wriggle"],
		"secrets": ["ant_city"], "cutscenes": [] } })
	Save.set_value(BookCatalog.TIN_KEY, { BookCatalog.LOG_KEY: log.to_dict() })
	Save.set_value(Story.SAVE_KEY, ["opening"])
	log.free()
	Save.flush()
	var slot := Save.slot
	Save.use_slot("")
	assert_bool(BookCatalog.saved_found().is_empty()).is_true()
	Save.use_slot(slot)   # back from disk
	var f := BookCatalog.found_set(get_tree())
	assert_array(f[&"foods"]).contains_exactly_in_any_order([&"seed", &"grub"])
	assert_array(f[&"creatures"]).contains_exactly([&"beetle"])
	assert_array(f[&"traits"]).contains_exactly([&"wriggle"])
	assert_array(f[&"secrets"]).contains_exactly([&"ant_city"])
	assert_array(f[&"cutscenes"]).contains_exactly([&"opening"])
	var b := _new_book()
	b.pause_tree = false
	b.open(Players.P2)
	assert_bool(b.is_found(&"foods", &"grub")).is_true()
	assert_bool(b.is_found(&"foods", &"pebble")).is_false()
	assert_bool(b.is_found(&"cutscenes", &"opening")).is_true()


# --- pause menu ----------------------------------------------------------------------------------

func test_y_on_the_pause_menu_opens_the_book_and_b_shuts_it() -> void:
	Players.join_virtual(Players.P1)
	_pm = PAUSE.instantiate()
	add_child(_pm)
	await get_tree().process_frame   # BookTab finds its pause menu deferred
	var tab: BookTab = _pm.get_node("Card/BookTab")
	assert_object(tab.book.host).is_same(_pm)
	Game._set_state(Game.State.PLAYING)
	Game.pause()
	assert_bool(_pm.visible).is_true()
	await get_tree().process_frame
	_press(Players.P1, "tackle")
	await get_tree().process_frame
	_release_all()
	assert_bool(tab.book.is_open).is_true()
	assert_bool(_pm.visible).is_false()
	assert_int(Game.state).is_equal(Game.State.PAUSED)
	await get_tree().process_frame
	_press(Players.P1, "jump")
	await get_tree().process_frame
	_release_all()
	await get_tree().process_frame
	assert_bool(tab.book.is_open).is_false()
	assert_bool(_pm.visible).is_true()
	assert_int(Game.state).is_equal(Game.State.PAUSED)   # B shut the book, it did not resume
	assert_bool(get_tree().paused).is_true()


func test_start_resuming_under_the_book_closes_it_cleanly() -> void:
	Players.join_virtual(Players.P1)
	_pm = PAUSE.instantiate()
	add_child(_pm)
	await get_tree().process_frame
	var tab: BookTab = _pm.get_node("Card/BookTab")
	Game._set_state(Game.State.PLAYING)
	Game.pause()
	tab.book.open(Players.P1)
	Game.resume()
	assert_bool(tab.book.is_open).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_bool(_pm.visible).is_false()
