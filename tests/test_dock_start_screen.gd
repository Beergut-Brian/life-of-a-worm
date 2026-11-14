## P-05: the bait-tin dock is the start screen's backdrop and the save select, with the template
## lobby on top. Booted from the real main.tscn: the lobby's backdrop layer shows main.gd's dock
## picture (dawn sky, water, the rail and three tins on it), and after ready-up the dock screen is
## the tin (save slot) select: each tin on its rail opens its own save slot.
## The dock art itself is a placeholder until the Art lane's dock lands (held for direction).
extends GdUnitTestSuite

const Lobby := preload("res://scenes/ui/lobby.gd")
const MAIN := preload("res://scenes/main.gd")

var _main: Node


func before() -> void:
	SuiteSandbox.enter("dock_start_screen")


func after() -> void:
	SuiteSandbox.leave()


func before_test() -> void:
	Players.reset()
	Game.demo = false
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	UiStyle.use_skin(null)
	Players.reset()
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func _boot() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)


func _backdrop_texture() -> Texture2D:
	for c in _main.get_node("UI/Lobby/Backdrop").get_children():
		if c is TextureRect and (c as TextureRect).texture != null:
			return (c as TextureRect).texture
	return null


func test_the_start_screen_stands_on_the_dock() -> void:
	_boot()
	assert_int(Game.state).is_equal(Game.State.LOBBY)
	assert_bool(_main.get_node("UI/Lobby").visible).is_true()
	assert_int(UiStyle.skin().backdrop).is_equal(MenuSkin.Backdrop.TEXTURE)
	var tex := _backdrop_texture()
	assert_object(tex).override_failure_message("the lobby has no picture behind it").is_not_null()
	var shown := tex.get_image()
	var dock := MAIN.dock_texture().get_image()
	assert_vector(Vector2(shown.get_size())).is_equal(Vector2(dock.get_size()))
	for p in [Vector2i(5, 5), Vector2i(2, 170), Vector2i(310, 152), Vector2i(344, 152), Vector2i(378, 152), Vector2i(380, 112)]:
		assert_that(shown.get_pixelv(p)).is_equal(dock.get_pixelv(p))
	# what it shows is a dock: water under the sky, the rail, and three coloured tins on it
	assert_that(shown.get_pixel(5, 200)).is_equal(Color("3f6f8f"))
	assert_that(shown.get_pixel(2, 170)).is_equal(Color("8a5a34"))
	var tins := {}
	for i in 3:
		tins[shown.get_pixel(300 + i * 34 + 10, 152).to_html(false)] = true
	assert_int(tins.size()).is_equal(3)
	assert_bool(_main.dock.visible).is_false()   # the tin select waits for ready-up


func test_after_ready_up_the_dock_is_the_save_select() -> void:
	_boot()
	Players.join_virtual(Players.P1)
	(_main.get_node("UI/Lobby") as Lobby).hold_step(Players.P1, true, Lobby.HOLD_TO_START)
	(_main.get_node("UI/Lobby") as Lobby).count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS + 0.01)
	assert_bool(_main.get_node("UI/Lobby").visible).is_false()
	assert_bool(_main.dock.visible).is_true()
	assert_object(_main.level).is_null()   # nothing opens until a tin is picked
	# the rail holds one tin per save slot, then the jar shelf
	_main.dock.focus = 0
	for i in BaitTins.COUNT:
		assert_int(_main.dock.focus).is_equal(i)
		_main.dock.move(1)
	assert_int(_main.dock.focus).is_equal(Dock.SHELF)
	_main.dock.move(-1)
	_main.dock.pick()
	assert_str(Save.slot).is_equal(BaitTins.slot_name(BaitTins.COUNT - 1))
	assert_object(_main.level).is_not_null()
	assert_bool(_main.dock.visible).is_false()
