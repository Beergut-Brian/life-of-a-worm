## Feel rule "start fresh from the menu": a played tin offers Continue and New on the dock, New asks
## with a held A, the old planet is kept as a backup (never deleted), and Restore brings it back.
## Runs in its own profile and settings file (SuiteSandbox), never a real tin.
extends GdUnitTestSuite

const PauseMenu := preload("res://scenes/ui/pause_menu.gd")
const Lobby := preload("res://scenes/ui/lobby.gd")

var _host: Control
var dock: Dock
var fresh: TinFresh
var _picked: Array[int] = []


func before() -> void:
	SuiteSandbox.enter("tin_fresh")


func after() -> void:
	_clear_tins()
	SuiteSandbox.leave()


func before_test() -> void:
	_clear_tins()
	_picked.clear()
	_host = Control.new()
	_host.size = Vector2(1920, 1080)
	add_child(_host)
	dock = Dock.new()
	dock.name = "Dock"
	_host.add_child(dock)
	dock.chosen.connect(func(i: int) -> void: _picked.append(i))
	fresh = TinFresh.new()
	_host.add_child(fresh)
	fresh.dock = dock


func after_test() -> void:
	_host.free()


func _clear_tins() -> void:
	Save.use_slot("")
	for i in BaitTins.COUNT:
		for p in BaitTins.backups(i):
			DirAccess.remove_absolute(p)
		DirAccess.remove_absolute(Save.path_for(BaitTins.slot_name(i)))


## A played tin i whose planet is marked with `mark`.
func _play_tin(i: int, mark: int) -> void:
	BaitTins.open(i)
	Save.set_value("planet", { "mark": mark })
	Save.set_value("stage", 2)
	Save.flush()
	Save.use_slot("")


func _mark_in(path: String) -> int:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return int(d.planet.mark) if d is Dictionary else -1


func _tin_path(i: int) -> String:
	return Save.path_for(BaitTins.slot_name(i))


func _hold(seconds: float) -> void:
	var t := 0.0
	while t < seconds and fresh.ask != TinFresh.Ask.NONE:
		fresh.step(1.0 / 60.0, true, false)
		t += 1.0 / 60.0


func test_the_tests_use_their_own_settings_and_profile() -> void:
	assert_str(Save.settings_path).is_equal(SuiteSandbox.settings_for("tin_fresh"))
	assert_str(Save.profile).is_equal(SuiteSandbox.profile_for("tin_fresh"))


func test_new_keeps_the_old_planet_as_a_backup() -> void:
	_play_tin(0, 7)
	var kept := BaitTins.start_fresh(0)
	assert_bool(BaitTins.summary(0).is_empty()).is_true()      # the tin is a new planet
	assert_bool(FileAccess.file_exists(kept)).is_true()
	assert_int(_mark_in(kept)).is_equal(7)                      # the old planet, whole


func test_a_second_new_never_writes_over_the_first_backup() -> void:
	_play_tin(1, 1)
	BaitTins.start_fresh(1)
	_play_tin(1, 2)
	BaitTins.start_fresh(1)
	var list := BaitTins.backups(1)
	assert_int(list.size()).is_equal(2)
	assert_int(_mark_in(list[0])).is_equal(1)
	assert_int(_mark_in(list[1])).is_equal(2)


func test_new_on_an_empty_tin_keeps_nothing() -> void:
	assert_str(BaitTins.start_fresh(2)).is_equal("")
	assert_bool(BaitTins.has_backup(2)).is_false()


func test_restore_brings_back_the_newest_and_keeps_the_current_one() -> void:
	_play_tin(0, 1)
	BaitTins.start_fresh(0)
	_play_tin(0, 2)                                             # played on in the new planet
	assert_bool(BaitTins.restore(0)).is_true()
	assert_int(_mark_in(_tin_path(0))).is_equal(1)
	var list := BaitTins.backups(0)
	assert_int(list.size()).is_equal(1)
	assert_int(_mark_in(list[0])).is_equal(2)                   # nothing lost: a swap
	assert_bool(BaitTins.restore(0)).is_true()                  # and back again
	assert_int(_mark_in(_tin_path(0))).is_equal(2)


func test_restore_with_no_backup_does_nothing() -> void:
	_play_tin(0, 3)
	assert_bool(BaitTins.restore(0)).is_false()
	assert_int(_mark_in(_tin_path(0))).is_equal(3)


func test_a_played_tin_offers_continue_and_new_an_empty_one_does_not() -> void:
	_play_tin(1, 4)
	dock.open()
	assert_bool(fresh.can_new(0)).is_false()
	assert_bool(fresh.can_new(1)).is_true()
	assert_bool(fresh.can_restore(1)).is_false()


func test_new_asks_with_a_held_a_then_opens_the_tin_as_a_new_planet() -> void:
	_play_tin(0, 5)
	dock.open()
	dock.focus = 0
	fresh.open(TinFresh.Ask.NEW)
	assert_bool(dock.is_processing()).is_false()                # A can't open the tin under the card
	_hold(TinFresh.HOLD * 0.5)
	assert_int(fresh.ask).is_equal(TinFresh.Ask.NEW)            # half a hold is not a yes
	assert_bool(BaitTins.summary(0).is_empty()).is_false()
	_hold(TinFresh.HOLD)
	assert_int(fresh.ask).is_equal(TinFresh.Ask.NONE)
	assert_array(_picked).is_equal([0])                         # the dock opened the tin...
	assert_bool(BaitTins.summary(0).is_empty()).is_true()       # ...as a new planet
	assert_int(_mark_in(BaitTins.backups(0)[0])).is_equal(5)    # and the old one is kept


func test_letting_go_or_b_keeps_the_planet() -> void:
	_play_tin(0, 6)
	dock.open()
	fresh.open(TinFresh.Ask.NEW)
	_hold(TinFresh.HOLD * 0.8)
	for i in 30:
		fresh.step(1.0 / 60.0, false, false)                    # let go: the ring drains
	assert_float(fresh.confirm.progress).is_less(0.5)
	fresh.step(1.0 / 60.0, false, true)                         # B
	assert_int(fresh.ask).is_equal(TinFresh.Ask.NONE)
	assert_array(_picked).is_empty()
	assert_int(_mark_in(_tin_path(0))).is_equal(6)
	assert_bool(BaitTins.has_backup(0)).is_false()


func test_restore_card_brings_the_old_planet_back() -> void:
	_play_tin(2, 8)
	BaitTins.start_fresh(2)
	dock.open()
	dock.focus = 2
	assert_bool(fresh.can_restore(2)).is_true()
	fresh.open(TinFresh.Ask.RESTORE)
	_hold(TinFresh.HOLD + 0.1)
	assert_int(_mark_in(_tin_path(2))).is_equal(8)
	assert_array(_picked).is_empty()                            # restore stays on the dock


func test_the_boot_scene_has_the_tin_fresh_hook_beside_the_dock() -> void:
	var st := (load("res://scenes/main.tscn") as PackedScene).get_state()
	var found := false
	for n in st.get_node_count():
		if st.get_node_name(n) == &"TinFresh" and String(st.get_node_path(n, true)) == "./UI":
			found = true
	assert_bool(found).is_true()


## The whole path in the real boot scene, with a save present: lobby -> dock (Continue / New) ->
## held-A New -> a new planet; then pause -> Main menu -> lobby -> the dock again, offering Restore.
func test_through_the_boot_scene_new_then_pause_back_to_restore() -> void:
	_play_tin(0, 9)
	Players.reset()
	Game.demo = false
	Game.round_index = 0
	Game._set_state(Game.State.LOBBY)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	Players.join_virtual(Players.P1)
	var lobby: Lobby = main.get_node("UI/Lobby")
	lobby.hold_step(Players.P1, true, Lobby.HOLD_TO_START)
	lobby.count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS + 0.01)
	var f: TinFresh = main.get_node("UI/TinFresh")
	assert_object(f.dock).is_same(main.dock)
	assert_bool(main.dock.visible).is_true()
	assert_bool(f.can_new(0)).is_true()                     # Continue and New on the played tin
	f.open(TinFresh.Ask.NEW)
	for i in int(TinFresh.HOLD * 60.0) + 2:
		f.step(1.0 / 60.0, true, false)
	assert_object(main.level).is_not_null()                 # the tin opened as a new planet
	assert_int(_mark_in(BaitTins.backups(0)[0])).is_equal(9)
	Game.pause()
	(main.get_node("UI/PauseMenu") as PauseMenu).press(PauseMenu.Choice.RESTART)   # "Main menu"
	assert_int(Game.state).is_equal(Game.State.LOBBY)
	assert_object(main.level).is_null()
	Game.start_round()                                      # the lobby's ready-up ends in this
	assert_bool(main.dock.visible).is_true()
	assert_bool(f.can_restore(0)).is_true()                 # the old planet can come back
	main.free()
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false
	Players.reset()
