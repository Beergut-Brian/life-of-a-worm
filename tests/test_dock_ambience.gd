## U-16: the dock has its own quiet bed. Booted from the real main.tscn: on the start screen and the
## tin select the dock bed plays (the library's open-air bed until an `amb_dock` file lands); once a
## tin is picked and the planet (the dirt) is open it fades out and stops, and coming back to the
## dock brings it back. The planet's own ring bed is a different player (RingAmbience).
extends GdUnitTestSuite

const Lobby := preload("res://scenes/ui/lobby.gd")

var _main: Node


func before() -> void:
	SuiteSandbox.enter("dock_ambience")


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


func _boot() -> DockAmbience:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var a := _main.get_node_or_null("DockAmbience") as DockAmbience
	assert_object(a).override_failure_message("main.tscn has no DockAmbience").is_not_null()
	return a


func _ready_up() -> void:
	Players.join_virtual(Players.P1)
	(_main.get_node("UI/Lobby") as Lobby).hold_step(Players.P1, true, Lobby.HOLD_TO_START)
	(_main.get_node("UI/Lobby") as Lobby).count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS + 0.01)


func test_the_bed_is_a_real_library_file_never_a_beep() -> void:
	var c := DockAmbience.cue()
	assert_str(c).is_not_empty()
	assert_bool(ResourceLoader.exists(Audio.SFX_DIR + c + ".ogg")).is_true()
	var p := Audio.loop_player(c)
	assert_str(p.stream.resource_path).ends_with(c + ".ogg")
	assert_bool((p.stream as AudioStreamOggVorbis).loop).is_true()
	p.free()


func test_it_plays_on_the_start_screen_and_the_tin_select() -> void:
	var a := _boot()
	a.step(DockAmbience.FADE + 0.1)
	assert_bool(a.on_dock).is_true()
	assert_object(a.bed).is_not_null()
	assert_bool(a.bed.playing).is_true()
	assert_float(a.bed.volume_db).is_equal_approx(DockAmbience.LEVEL_DB, 0.01)
	assert_str(a.bed.stream.resource_path).ends_with(DockAmbience.cue() + ".ogg")
	_ready_up()
	assert_bool(_main.dock.visible).is_true()
	a.step(0.5)
	assert_bool(a.bed.playing).is_true()
	assert_float(a.bed.volume_db).is_equal_approx(DockAmbience.LEVEL_DB, 0.01)


func test_it_fades_out_in_the_dirt_and_comes_back_on_the_dock() -> void:
	var a := _boot()
	a.step(DockAmbience.FADE + 0.1)
	_ready_up()
	_main.dock.focus = 0
	_main.dock.pick()
	assert_object(_main.level).is_not_null()
	a.step(DockAmbience.FADE * 0.5)
	assert_bool(a.on_dock).is_false()
	assert_bool(a.bed.playing).is_true()          # a fade, not a cut
	assert_float(a.bed.volume_db).is_less(DockAmbience.LEVEL_DB - 1.0)
	a.step(DockAmbience.FADE)
	assert_bool(a.bed.playing).is_false()
	# the planet's ring bed is its own player, not the dock's
	assert_object(_main.level.get_node_or_null("RingAmbience")).is_not_null()
	_main.close_level()
	a.step(DockAmbience.FADE + 0.1)
	assert_bool(a.on_dock).is_true()
	assert_bool(a.bed.playing).is_true()
	assert_float(a.bed.volume_db).is_equal_approx(DockAmbience.LEVEL_DB, 0.01)


func test_the_demo_has_no_dock_bed() -> void:
	var a := DockAmbience.new()
	var host := Node.new()
	host.add_child(a)
	add_child(host)
	Game.demo = true
	a.step(1.0)
	assert_bool(a.on_dock).is_false()
	assert_object(a.bed).is_null()
	Game.demo = false
	host.free()
