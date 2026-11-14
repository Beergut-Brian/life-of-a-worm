## Old Reel's jar shelf (worm-jar-2): one spot per bait tin, listing that tin's jar from the shared
## `Jars` store; walking (only the player's stick) focuses a jar, A opens it; opening loads the jar's
## tin slot first; leaving writes back into the same jar, shows it going back in, and returns to the
## shelf; a jar left open by a quit is put back at boot. Every save is this suite's sandbox profile,
## every jar a scratch dir (the shared autoload is pointed there and restored).
extends GdUnitTestSuite

const DIR := "user://test_jars_shelf"
const VIEW := "res://scenes/jars/jar_open.tscn"

var jars: JarStore
var _real_dir := ""
var _main: Node


func before() -> void:
	SuiteSandbox.enter("jars_shelf")
	Game.quit_exits = false
	_real_dir = Jars.dir
	Jars.dir = DIR


func after() -> void:
	if Jars.is_in_jar():
		Jars.close()
	Jars.clear()
	Jars.dir = _real_dir
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	Game.quit_exits = true
	SuiteSandbox.leave()


func before_test() -> void:
	Save.use_slot("")
	Save.wipe()
	for i in BaitTins.COUNT:
		BaitTins.open(i)
		Save.wipe()
	Save.use_slot("")
	Audio.played.clear()
	jars = auto_free(JarStore.new())
	jars.dir = DIR
	add_child(jars)
	jars.clear()
	Players.reset()
	Game.demo = false
	Game.round_index = 0
	Game._set_state(Game.State.LOBBY)


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	UiStyle.use_skin(null)
	if jars.is_in_jar():
		jars.close()
	if Jars.is_in_jar():
		Jars.close()
	jars.clear()
	Save.use_slot("")
	Players.reset()
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false
	for p in Audio._pool:   # placeholder beeps must not outlive the suite
		p.stop()


## Tin i holds a planet with `seed` and its own tackle box, and gets jarred. Returns the jar id.
func _jar_tin(i: int, seed_value: int, found := "grub") -> StringName:
	BaitTins.open(i)
	var p := PlanetStandIn.generate("", seed_value, 12)
	Save.set_value("seed", seed_value)
	Save.set_value("planet", p.to_save())
	Save.set_value("stage", 6)
	Save.set_value("tackle", {"found": {"foods": [found]}})
	var id := JarStore.current_planet_id(seed_value)
	assert_str(jars.snapshot(id)).is_not_empty()
	Save.use_slot("")
	return id


func _shelf() -> JarShelf:
	var s: JarShelf = auto_free(JarShelf.new())
	add_child(s)
	s.size = Vector2(1920, 1080)
	return s


func test_the_shelf_lists_one_entry_per_jar_in_tin_order() -> void:
	var a := _jar_tin(2, 303)
	var b := _jar_tin(0, 101)
	var got := jars.shelf(JarShelf.slot_names())
	assert_int(got.size()).is_equal(2)
	assert_str(got[0].slot).is_equal("tin1")
	assert_str(String(got[0].id)).is_equal(String(b))
	assert_str(got[1].slot).is_equal("tin3")
	assert_str(String(got[1].id)).is_equal(String(a))
	var s := _shelf()
	s.open(jars)
	assert_int(s.entries.size()).is_equal(2)
	assert_bool(s.entry_at(1).is_empty()).is_true()     # tin 2 has no jar: an outline, no entry


func test_an_empty_set_lists_nothing_and_another_profiles_jars_are_not_ours() -> void:
	assert_array(jars.shelf(JarShelf.slot_names())).is_empty()
	var other := JarStore.current_planet_id(77)
	Save.use_profile("gdunit_jars_shelf_other")
	BaitTins.open(0)
	Save.set_value("seed", 77)
	jars.snapshot(JarStore.current_planet_id(77))
	Save.wipe()
	Save.use_profile(SuiteSandbox.profile_for("jars_shelf"))
	assert_int(jars.list().size()).is_equal(1)
	assert_array(jars.shelf(JarShelf.slot_names())).is_empty()
	var s := _shelf()
	s.open(jars)
	assert_int(s.entries.size()).is_equal(0)
	assert_bool(other != &"").is_true()


func test_walking_up_focuses_a_jar_and_nothing_moves_the_worm_but_the_stick() -> void:
	_jar_tin(1, 202)
	var s := _shelf()
	s.open(jars)
	var p := Players.P1
	var x0: float = s.walker_x[p]
	assert_int(s.focus[p]).is_equal(-1)
	for i in 60:
		s.walk(p, 0.0, 1.0 / 60.0)
	assert_float(s.walker_x[p]).is_equal(x0)            # no stick, no movement: no snap to the jar
	assert_bool(s.press_a(p)).is_false()                # A out of reach: nothing opens
	var events := []
	s.jar_chosen.connect(func(e): events.append(e))
	while s.walker_x[p] < s.spot_x(1) - JarShelf.REACH:
		s.walk(p, 1.0, 1.0 / 60.0)
	s.walk(p, 1.0, 1.0 / 60.0)
	assert_int(s.focus[p]).is_equal(1)
	assert_float(s.walker_x[p]).is_less(s.spot_x(1))   # focused while still walking up, not pulled on
	assert_bool(s.press_a(p)).is_true()
	assert_int(events.size()).is_equal(1)
	assert_str(events[0].slot).is_equal("tin2")


func test_opening_a_jar_loads_the_tins_slot_and_leaving_writes_back_to_the_same_jar() -> void:
	var id1 := _jar_tin(0, 101, "grub")
	var id3 := _jar_tin(2, 303, "beetle")
	var e: Dictionary = jars.shelf(JarShelf.slot_names())[1]
	assert_bool(jars.open_entry(e)).is_true()
	assert_str(Save.profile).is_equal(JarStore.JAR_PROFILE_PREFIX + String(id3))
	assert_int(int(Save.get_value("seed", 0))).is_equal(303)
	assert_dict(Save.get_value("tackle", {})).is_equal({"found": {"foods": ["beetle"]}})   # tin 3's box
	Save.set_value("played", 99.0)                      # play inside the jar
	Save.set_value("tackle", {"found": {"foods": ["beetle", "moth"]}})
	jars.close()
	assert_str(Save.profile).is_equal(SuiteSandbox.profile_for("jars_shelf"))
	assert_str(Save.slot).is_equal("tin3")              # back to the tin that holds this jar
	assert_dict(Save.get_value("tackle", {})).is_equal({"found": {"foods": ["beetle", "moth"]}})
	assert_float(float(jars.peek(id3).get("played", 0.0))).is_equal(99.0)
	assert_bool(jars.peek(id1).has("played")).is_false()
	assert_int(jars.list().size()).is_equal(2)          # the same jar, not a new one


func test_a_jar_left_open_by_a_quit_goes_back_at_boot() -> void:
	var id := _jar_tin(1, 202, "grub")
	assert_bool(jars.open_entry(jars.shelf(JarShelf.slot_names())[0])).is_true()
	Save.set_value("played", 42.0)
	Save.set_value("tackle", {"found": {"foods": ["grub", "snail"]}})
	Save.flush()
	jars._open_id = &""                                 # the game quit inside the jar: a new boot
	Save.use_profile(SuiteSandbox.profile_for("jars_shelf"))
	assert_int(jars.recover()).is_equal(1)
	assert_float(float(jars.peek(id).get("played", 0.0))).is_equal(42.0)
	assert_bool(jars.peek(id).has("tackle")).is_false()
	assert_bool(FileAccess.file_exists(Save.path_for("", JarStore.JAR_PROFILE_PREFIX + String(id)))).is_false()
	assert_str(Save.profile).is_equal(SuiteSandbox.profile_for("jars_shelf"))
	BaitTins.open(1)
	assert_dict(Save.get_value("tackle", {})).is_equal({"found": {"foods": ["grub", "snail"]}})
	Save.use_slot("")
	assert_int(jars.recover()).is_equal(0)


func test_the_leave_shows_the_planet_going_back_into_its_jar() -> void:
	var id := _jar_tin(0, 101)
	var v: JarOpenView = auto_free(load(VIEW).instantiate())
	add_child(v)
	v.set_process(false)
	var done := []
	v.closed.connect(func(i): done.append(i))
	assert_bool(v.show_close(jars, id)).is_true()
	assert_float(v.dive()).is_equal(1.0)                 # starts with the planet filling the screen
	v.advance(JarOpenView.OUT_END * 0.5)
	assert_float(v.dive()).is_between(0.01, 0.99)
	v.advance(JarOpenView.OUT_END)
	assert_float(v.dive()).is_equal(0.0)                 # back in its jar on the shelf
	assert_array(done).is_empty()
	v.advance(JarOpenView.CLOSE_END)
	assert_array(done).is_equal([id])
	assert_int(Audio.played.get("tunnel", 0)).is_equal(1)      # out through the glass
	assert_int(Audio.played.get("jar_clink", 0)).is_equal(1)   # the lid goes back on


## The real flow in main: dock -> shelf -> jar view -> the jar's planet -> Main menu -> back into the
## jar -> the shelf beside it. Nobody is left in a jar.
func test_main_dock_to_jar_and_back_to_the_shelf() -> void:
	var id := _jar_tin(1, 202)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Players.join_virtual(Players.P1)
	Game.start_round()
	assert_bool(_main.dock.visible).is_true()
	_main.dock.focus = Dock.SHELF
	_main.dock.pick()
	assert_bool(_main.shelf.visible).is_true()
	assert_int(_main.shelf.entries.size()).is_equal(1)
	_main.open_jar(_main.shelf.entries[0])
	assert_str(Save.slot).is_equal("tin2")
	var v: JarOpenView = _main.jar_view
	v.set_process(false)
	v.advance(JarOpenView.ENTER_AT + 0.1)
	assert_bool(Jars.is_in_jar()).is_true()
	assert_object(_main.level).is_not_null()
	assert_bool(JarStore.stage6_allowed()).is_false()
	Game.to_lobby()                                     # the pause menu's Main menu
	assert_bool(Jars.is_in_jar()).is_false()
	assert_str(Save.profile).is_equal(SuiteSandbox.profile_for("jars_shelf"))
	assert_object(_main.level).is_null()
	assert_bool(Jars.peek(id).has("planet")).is_true()
	var cv: JarOpenView = _main.jar_view
	assert_bool(cv.closing).is_true()
	cv.set_process(false)
	cv.advance(JarOpenView.CLOSE_END + 0.1)
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	assert_bool(_main.shelf.visible).is_true()          # back on the shelf, beside that jar
	assert_int(_main.shelf.focus[Players.P1]).is_equal(1)
