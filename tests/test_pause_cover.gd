## C-08 (gap-close-36): Start pauses and nothing in play draws over the pause menu. Before this, the
## trait wall (layer 50) and the planet HUD's glyph strip (layer 20) stayed on top of the menu; now
## `PauseCover` (a child of main.tscn's UI) hides every arena CanvasLayer above the menu while paused
## and shows exactly those again on resume. Drives the real main.tscn. Own Save profile.
class_name TestPauseCover
extends GdUnitTestSuite

const P1 := Players.P1
const PauseMenu := preload("res://scenes/ui/pause_menu.gd")
const Lobby := preload("res://scenes/ui/lobby.gd")

var _main: Node


func before() -> void:
	SuiteSandbox.enter("pause_cover")


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	SuiteSandbox.leave()


func before_test() -> void:
	Save.wipe_settings()
	Players.reset()
	Game.demo = false
	Game.quit_exits = false
	Game.round_index = 0
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	_main = null
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	UiStyle.use_skin(null)
	Players.reset()
	Game.quit_exits = true
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


## main.tscn -> lobby -> P1 starts alone -> the dock -> tin 1. P1 at stage 2 with the trait wall open.
func _play_with_the_wall_open() -> Worm:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Players.join_virtual(P1)
	var lobby: Lobby = _main.get_node("UI/Lobby")
	lobby.hold_step(P1, true, Lobby.HOLD_TO_START)
	lobby.count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS + 0.01)
	_main.dock.pick()
	var w: Worm = Worm.all()[0]
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	w.model.start_at_stage(2)
	w.model.grant(&"wriggle")
	w.set_wall_open(true)
	return w


func _pause_menu() -> PauseMenu:
	return _main.get_node("UI/PauseMenu")


## Every visible CanvasLayer in the arena drawn above the menu's UI layer.
func _over_the_menu() -> Array:
	var ui_layer: int = (_main.get_node("UI") as CanvasLayer).layer
	return _main.get_node("Arena").find_children("*", "CanvasLayer", true, false).filter(
		func(l: CanvasLayer) -> bool: return l.visible and l.layer > ui_layer)


func test_the_wall_and_the_hud_never_draw_over_the_pause_menu() -> void:
	var w := _play_with_the_wall_open()
	var level: PlanetLevel = _main.level
	assert_object(_main.get_node_or_null("UI/PauseCover")).is_not_null()
	assert_bool(w._wall.visible).is_true()
	assert_bool(level.hud.visible).is_true()
	assert_array(_over_the_menu()).is_not_empty()      # in play, they are on top: as they should be
	Game.pause()
	assert_bool(_pause_menu().visible).is_true()
	assert_array(_over_the_menu()).is_empty()
	assert_bool(w._wall.visible).is_false()
	assert_bool(level.hud.visible).is_false()
	# The game itself stays visible behind the menu: the sky (under the menu) is not hidden.
	var sky := level.find_children("*", "CanvasLayer", true, false).filter(
		func(l: CanvasLayer) -> bool: return l.layer < 0)
	assert_array(sky).is_not_empty()
	for l in sky:
		assert_bool((l as CanvasLayer).visible).is_true()
	# B resumes: exactly what was showing comes back, the wall still open under the worm's control.
	_pause_menu().back()
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	assert_bool(w._wall.visible).is_true()
	assert_bool(w.wall_open).is_true()
	assert_bool(level.hud.visible).is_true()


func test_a_closed_wall_stays_closed_after_a_pause() -> void:
	var w := _play_with_the_wall_open()
	w.set_wall_open(false)
	Game.pause()
	_pause_menu().back()
	assert_bool(w._wall.visible).is_false()   # hidden before the pause, so not shown after it


func test_pause_over_the_tackle_box_still_hides_and_restores_it() -> void:
	_play_with_the_wall_open()
	var level: PlanetLevel = _main.level
	var box: TackleBox = level.home_slice.box
	level.home_slice.open_box(P1)
	Game.pause()
	assert_bool(box.visible).is_false()
	assert_array(_over_the_menu()).is_empty()
	_pause_menu().back()
	assert_bool(box.visible).is_true()
	box.close()
	assert_bool(get_tree().paused).is_false()


func test_main_menu_from_pause_leaves_nothing_behind() -> void:
	_play_with_the_wall_open()
	Game.pause()
	_pause_menu().press(PauseMenu.Choice.RESTART)            # "Main menu"
	assert_int(Game.state).is_equal(Game.State.LOBBY)
	assert_object(_main.level).is_null()
	var cover: PauseCover = _main.get_node("UI/PauseCover")
	assert_array(cover.hidden).is_empty()


## Found by the same frame (gap-close-36): the dock's Continue / New world choices under a played tin
## were drawn once and never wiped when the planet opened, so they hung over play (and the pause
## menu) for the whole session. TinFresh now redraws once when the dock goes.
func test_the_tin_choices_are_wiped_when_the_planet_opens() -> void:
	BaitTins.open(0)
	Save.wipe()
	Save.set_value("planet", { "seed": 7 })
	Save.set_value("stage", 2)
	Save.set_value("played", 1800.0)
	Save.flush()
	Save.use_slot("")
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Players.join_virtual(P1)
	var lobby: Lobby = _main.get_node("UI/Lobby")
	lobby.hold_step(P1, true, Lobby.HOLD_TO_START)
	lobby.count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS + 0.01)
	var fresh: TinFresh = _main.get_node("UI/TinFresh")
	_main.dock.focus = 0
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(fresh.drew_choices).is_true()       # on the dock: Continue / New world under tin 1
	_main.dock.pick()
	assert_object(_main.level).is_not_null()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(fresh.drew_choices).is_false()      # in play: wiped, nothing left over the planet
