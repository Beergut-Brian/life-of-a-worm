## Standing rule "start fresh from the menu" (K-11): with a save present the menu (the bait-tin dock)
## shows Continue and New world, New asks with a held A, the old planet is kept as a backup under
## user://saves/backups (never deleted), a tin that can't be backed up is never wiped, and Restore
## (on the tin, or Settings > Restore old world) brings the newest backup back, backing up first.
## Runs in its own profile and settings file (SuiteSandbox) and starts each test on an empty save
## (Save.replace({})), never a real tin or the real settings.
extends GdUnitTestSuite

const PauseMenu := preload("res://scenes/ui/pause_menu.gd")
const Lobby := preload("res://scenes/ui/lobby.gd")
const SETTINGS := preload("res://scenes/ui/settings_panel.tscn")
## A save folder whose backups folder is a file: every backup fails there.
const BROKEN := "user://test_fresh_start_broken"

var _host: Control
var dock: Dock
var fresh: TinFresh
var _picked: Array[int] = []


func before() -> void:
	SuiteSandbox.enter("fresh_start")


func after() -> void:
	_clear_tins()
	SuiteSandbox.leave()


func before_test() -> void:
	Save.dir = "user://saves"
	Save.use_slot("")
	Save.replace({})
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
	if Save.dir == BROKEN:
		_clear_tins()
		DirAccess.remove_absolute(BROKEN.path_join("backups"))
		DirAccess.remove_absolute(Save.path_for(""))
		DirAccess.remove_absolute(BROKEN)
		Save.dir = "user://saves"


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
	assert_str(Save.settings_path).is_equal(SuiteSandbox.settings_for("fresh_start"))
	assert_str(Save.profile).is_equal(SuiteSandbox.profile_for("fresh_start"))


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
	assert_int(list.size()).is_equal(2)                         # nothing removed...
	assert_int(_mark_in(list[0])).is_equal(1)
	assert_int(_mark_in(list[1])).is_equal(2)                   # ...and the replaced one kept, newest
	assert_bool(BaitTins.restore(0)).is_true()                  # so a second Restore undoes it
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


func test_each_test_starts_on_an_empty_save_of_its_own_profile() -> void:
	assert_str(Save.profile).starts_with(SuiteSandbox.PROFILE_PREFIX)
	assert_str(Save.path_for("")).is_not_equal("user://saves/p1.json")
	assert_str(FileAccess.get_file_as_string(Save.path_for(""))).is_equal("{}")   # Save.replace({})
	for i in BaitTins.COUNT:
		assert_bool(BaitTins.summary(i).is_empty()).is_true()


func test_with_a_save_present_the_menu_shows_continue_and_new_world() -> void:
	_play_tin(0, 11)
	dock.open()
	dock.focus = 0
	assert_bool(fresh.can_new(0)).is_true()                     # Continue (the tin) and New world
	assert_int(fresh.choice).is_equal(TinFresh.Choice.CONTINUE)
	fresh.focus_new()                                           # down: New world lit
	assert_int(fresh.choice).is_equal(TinFresh.Choice.NEW)
	assert_bool(dock.is_processing()).is_false()                # A now asks, it doesn't open the tin
	fresh.focus_continue()
	await get_tree().process_frame
	assert_bool(dock.is_processing()).is_true()


func test_new_keeps_a_backup_file_and_the_old_save_still_reads() -> void:
	_play_tin(0, 12)
	var before := FileAccess.get_file_as_string(_tin_path(0))
	var kept := BaitTins.start_fresh(0)
	assert_str(kept.get_base_dir()).is_equal(Save.dir.path_join("backups"))
	var re := RegEx.create_from_string("^%s_tin1--\\d{8}T\\d{6}-\\d{3}\\.json$" % Save.profile)
	assert_object(re.search(kept.get_file())).is_not_null()     # <profile>_tin1--<UTC stamp>-<n>.json
	assert_str(FileAccess.get_file_as_string(kept)).is_equal(before)   # the whole save, as it was
	assert_int(_mark_in(kept)).is_equal(12)                     # and it reads as a planet
	BaitTins.open(0)                                            # the tin itself opens new
	assert_object(Save.get_value("planet")).is_null()
	Save.use_slot("")


func test_a_backup_that_fails_stops_new_and_leaves_the_save_alone() -> void:
	Save.dir = BROKEN
	DirAccess.make_dir_recursive_absolute(BROKEN)
	var f := FileAccess.open(BROKEN.path_join("backups"), FileAccess.WRITE)   # a file, not a folder
	f.store_string("not a folder")
	f.close()
	_play_tin(0, 13)
	var before := FileAccess.get_file_as_string(_tin_path(0))
	assert_str(BaitTins.start_fresh(0)).is_equal("")
	assert_str(FileAccess.get_file_as_string(_tin_path(0))).is_equal(before)
	dock.open()
	dock.focus = 0
	fresh.open(TinFresh.Ask.NEW)                                # and through the held-A card
	_hold(TinFresh.HOLD + 0.1)
	assert_array(_picked).is_empty()                            # nothing opened
	assert_int(_mark_in(_tin_path(0))).is_equal(13)
	assert_bool(fresh.can_new(0)).is_true()                     # still Continue and New


func test_restore_refuses_when_the_world_it_replaces_cannot_be_backed_up() -> void:
	_play_tin(0, 14)
	BaitTins.start_fresh(0)
	var kept := BaitTins.backups(0)[0]
	Save.dir = BROKEN                                           # same file names, backups fail
	DirAccess.make_dir_recursive_absolute(BROKEN)
	var f := FileAccess.open(BROKEN.path_join("backups"), FileAccess.WRITE)
	f.store_string("not a folder")
	f.close()
	_play_tin(0, 15)
	assert_bool(BaitTins.restore(0, kept)).is_false()
	assert_int(_mark_in(_tin_path(0))).is_equal(15)
	Save.dir = "user://saves"
	_clear_tins()
	Save.dir = BROKEN


func test_settings_restore_brings_the_newest_back_and_backs_up_the_world_first() -> void:
	_play_tin(1, 21)
	BaitTins.start_fresh(1)                                     # tin 2's old planet, the newest backup
	_play_tin(1, 22)                                            # a new planet played in tin 2
	_play_tin(0, 23)                                            # tin 1 is not touched
	var panel: SettingsPanel = SETTINGS.instantiate()
	_host.add_child(panel)
	fresh.hook_settings(panel)
	panel.open()
	assert_bool(panel._restore.visible).is_true()               # Settings offers Restore old world
	panel._set_focus(SettingsPanel.Row.RESTORE, false)
	panel.handle({ "move": Vector2i.ZERO, "a": Players.P1, "b": -1 })
	assert_int(fresh.ask).is_equal(TinFresh.Ask.RESTORE_NEWEST)  # asks first, with the held A
	assert_int(_mark_in(_tin_path(1))).is_equal(22)
	_hold(TinFresh.HOLD + 0.1)
	assert_int(_mark_in(_tin_path(1))).is_equal(21)             # the newest backup is back
	var list := BaitTins.backups(1)
	assert_int(list.size()).is_equal(2)
	assert_int(_mark_in(list[1])).is_equal(22)                  # the world it replaced, backed up
	assert_int(_mark_in(_tin_path(0))).is_equal(23)


func test_settings_hides_restore_with_no_backup_and_the_pause_panel_never_offers_it() -> void:
	_play_tin(0, 31)
	var panel: SettingsPanel = SETTINGS.instantiate()
	_host.add_child(panel)
	fresh.hook_settings(panel)
	panel.open()
	assert_bool(panel._restore.visible).is_false()
	panel._set_focus(SettingsPanel.Row.SOLO, false)
	panel.move_focus(1)
	assert_int(panel.focus).is_equal(SettingsPanel.Row.SOLO)    # no hidden row to land on
	BaitTins.start_fresh(0)
	var plain: SettingsPanel = SETTINGS.instantiate()           # the pause menu's: no restore_check
	_host.add_child(plain)
	plain.open()
	assert_bool(plain._restore.visible).is_false()


func test_backups_made_beside_the_tin_move_into_the_backups_folder() -> void:
	_play_tin(2, 41)
	var old := _tin_path(2).trim_suffix(".json") + ".old1.json"
	DirAccess.rename_absolute(_tin_path(2), old)
	var list := BaitTins.backups(2)
	assert_int(list.size()).is_equal(1)
	assert_bool(FileAccess.file_exists(old)).is_false()
	assert_int(_mark_in(list[0])).is_equal(41)                  # moved, never lost
