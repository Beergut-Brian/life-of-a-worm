## Session flow (worm-session-1): solo playtest mode (P-09), the pause menu with its big door back to
## the launcher (P-06, C-08), and no forced movement: the camera fits both worms to the widest zoom,
## then follows one while the far worm gets the edge arrow and a held-B warp to its partner (P-07).
## Pausing over the tackle box or a rewatched cutscene holds them still and never softlocks.
## Runs in its own save profile and settings file (SuiteSandbox "worm_session").
class_name TestWormSession
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const PLANET := preload("res://scenes/levels/planet.tscn")
const PauseMenu := preload("res://scenes/ui/pause_menu.gd")
const Lobby := preload("res://scenes/ui/lobby.gd")

var _main: Node
var _level: PlanetLevel
var _quits := 0


func before() -> void:
	SuiteSandbox.enter("worm_session")
	Game.quit_requested.connect(_on_quit)


func after() -> void:
	Game.quit_requested.disconnect(_on_quit)
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
	_quits = 0


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	_main = null
	if is_instance_valid(_level):
		remove_child(_level)
		_level.free()
	_level = null
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	UiStyle.use_skin(null)
	Players.reset()
	Game.quit_exits = true
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func _on_quit() -> void:
	_quits += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Awaits physics frames until `done` is true, at most `limit` of them. Returns how many frames it
## took, or -1 if it never came true (assert on it: a timeout then fails by name, not as a later
## position assert). Camera and split tests wait on the state they mean with this, never a fixed
## frame count: on a slow CPU several physics ticks run per process frame, so a fixed count lands
## at a different point of the camera's ease and the worms' own physics.
func _until(done: Callable, limit: int) -> int:
	for i in limit:
		if done.call():
			return i
		await get_tree().physics_frame
	return limit if done.call() else -1


## The camera has caught up with its targets: centred within a pixel, the fit zoom reached and
## "up" turned to their mean up (PolarCamera.step eases all three, in process frames).
func _camera_settled(cam: PolarCamera) -> bool:
	var c := cam._centre()
	return cam.position.distance_to(c) <= 1.0 and cam.zoom_index == cam.fit_index() \
		and absf(angle_difference(cam.rotation, PolarCamera.up_rotation(c))) <= 0.01


## main.tscn -> lobby -> P1 starts alone -> the dock -> tin 1: the planet with Gulp.
func _play_planet() -> PlanetLevel:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Players.join_virtual(P1)
	var lobby: Lobby = _main.get_node("UI/Lobby")
	lobby.hold_step(P1, true, Lobby.HOLD_TO_START)
	lobby.count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS + 0.01)
	_main.dock.pick()
	return _main.level


func _pause_menu() -> PauseMenu:
	return _main.get_node("UI/PauseMenu")


## A bare planet in tin 1 with two worms, P2 at stage p2_stage.
func _two_worms(p2_stage := 1) -> PlanetLevel:
	BaitTins.open(0)
	Save.wipe()
	_level = PLANET.instantiate()
	add_child(_level)
	var still := func(_w: Worm) -> Dictionary: return {}
	var a := _level.spawn_worm(P1)
	a.autopilot = still
	var b := _level.spawn_worm(P2, _level.local_point(3, 0), p2_stage)
	b.autopilot = still
	return _level


# --- P-09 solo playtest mode ----------------------------------------------------------------

func test_solo_flag_from_args() -> void:
	assert_bool(Players.solo_from_args(PackedStringArray(["--solo"]))).is_true()
	assert_bool(Players.solo_from_args(PackedStringArray(["--profile=p1", "--solo"]))).is_true()
	assert_bool(Players.solo_from_args(PackedStringArray(["--solos", "solo"]))).is_false()
	assert_bool(Players.solo_from_args(PackedStringArray())).is_false()
	assert_bool(Players.solo).is_false()   # never on by default


func test_solo_from_the_hold_shows_the_icon_and_hatches_the_partner() -> void:
	var level := _play_planet()
	assert_int(Worm.all().size()).is_equal(1)
	var marker = Players._marker
	assert_bool(marker.is_showing()).is_false()
	assert_bool(Players.hold_step(7, true, 1.0)).is_false()
	Players.hold_step(7, false, 0.1)               # let go early: nothing
	assert_bool(Players.hold_step(7, true, 1.9)).is_false()
	assert_bool(Players.solo).is_false()
	assert_bool(Players.hold_step(7, true, 0.2)).is_true()   # 2.1 s of Select + Start
	assert_bool(Players.solo).is_true()
	assert_bool(marker.is_showing()).is_true()
	assert_array(Players.active_players()).is_equal([P1, P2])
	var eggs: Array = level.get_children().filter(func(n): return n is WormEgg)
	assert_int(eggs.size()).is_equal(1)                       # Burp drops in for the one pad
	Players.hold_step(7, false, 0.1)
	Players.hold_step(7, true, 2.1)                           # hold again: solo off
	assert_bool(Players.solo).is_false()
	assert_array(Players.active_players()).is_equal([P1])


func test_saved_solo_never_restores_at_boot() -> void:
	# Tests write their own settings file, never the family's user://settings.json.
	assert_str(Save.settings_path).is_equal(SuiteSandbox.settings_for("worm_session"))
	Save.set_setting(SettingsPanel.SOLO, true)
	Save.reload_settings()                                    # as on the next boot
	_play_planet()
	await _frames(2)
	assert_bool(Players.solo).is_false()
	assert_bool(Players._marker.is_showing()).is_false()
	assert_array(Players.active_players()).is_equal([P1])
	assert_int(Worm.all().size()).is_equal(1)


func test_solo_select_hands_the_pad_and_the_camera_to_the_other_worm() -> void:
	var level := _two_worms()
	Players.set_solo(true)
	var far := level.local_point(240, 0)
	Worm.of(P2).warp_to(far - Worm.of(P2).position)
	# The split is due on the next physics frame (FarCamera.step); wait on it, not a frame count.
	assert_int(await _until(func() -> bool: return level.far_camera.split, 30)).is_not_equal(-1)
	assert_bool(FarCamera.fits(level.camera, Worm.all())).is_false()
	assert_int(level.far_camera.anchor).is_equal(P1)          # follows the pad's worm
	var sel := InputEventAction.new()
	sel.action = "restart"
	sel.pressed = true
	level._unhandled_input(sel)
	assert_int(Players.solo_focus).is_equal(P2)
	# The next FarCamera.step reads the new focus; wait on the handover, not a frame count.
	assert_int(await _until(func() -> bool: return level.far_camera.anchor == P2, 30)).is_not_equal(-1)
	assert_bool(level.far_camera.split).is_true()
	assert_array(level.camera.targets).is_equal([Worm.of(P2)])


# --- P-06 / C-08 pause menu and the door ----------------------------------------------------

func test_start_pauses_and_the_menu_has_a_big_door_icon() -> void:
	_play_planet()
	var start := InputEventAction.new()
	start.action = "pause"
	start.pressed = true
	Game._unhandled_input(start)
	assert_int(Game.state).is_equal(Game.State.PAUSED)
	var pm := _pause_menu()
	assert_bool(pm.visible).is_true()
	var door: Control = pm.get_node("Card/DoorIcon")
	assert_bool(door.is_visible_in_tree()).is_true()
	assert_float(door.size.x).is_greater_equal(120.0)
	assert_str(pm.get_node("Card/Buttons/Door").text).is_equal("Back to Open Jar")
	assert_bool(door.focused).is_false()
	pm._set_focus(PauseMenu.Choice.DOOR)
	assert_bool(door.focused).is_true()                       # lights with its bar
	Game._unhandled_input(start)                              # Start again resumes
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	assert_bool(get_tree().paused).is_false()


func test_door_returns_to_the_launcher_after_a_stay() -> void:
	_play_planet()
	Game.pause()
	var pm := _pause_menu()
	pm.press(PauseMenu.Choice.DOOR)
	var confirm: ConfirmDialog = pm.get_node("Confirm")
	assert_bool(confirm.active).is_true()
	pm.back()                                                 # B: Stay
	assert_bool(confirm.active).is_false()
	assert_int(_quits).is_equal(0)
	assert_int(Game.state).is_equal(Game.State.PAUSED)
	pm.press(PauseMenu.Choice.DOOR)
	confirm.choose(true)                                      # Leave
	assert_int(_quits).is_equal(1)                            # Game.quit(): exit 0, launcher resumes
	assert_bool(Save._dirty).is_false()                       # the tin saved first


func test_pause_over_the_tackle_box_holds_it_and_never_softlocks() -> void:
	var level := _play_planet()
	var box: TackleBox = level.home_slice.box
	level.home_slice.open_box(P1)
	assert_bool(get_tree().paused).is_true()
	Game.pause()
	var pm := _pause_menu()
	assert_bool(pm.visible).is_true()
	assert_bool(box.visible).is_false()                       # the pause menu is on top
	assert_int(box.process_mode).is_equal(Node.PROCESS_MODE_PAUSABLE)   # and the only reader
	pm.back()                                                 # B: resume
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	assert_bool(get_tree().paused).is_true()                  # the box still holds the game
	assert_bool(box.visible).is_true()
	assert_int(box.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	box.close()
	assert_bool(get_tree().paused).is_false()
	# Again, then the door from over the box: still quits.
	level.home_slice.open_box(P1)
	Game.pause()
	pm.press(PauseMenu.Choice.DOOR)
	pm.get_node("Confirm").choose(true)
	assert_int(_quits).is_equal(1)


func test_main_menu_from_over_the_tackle_box_unpauses() -> void:
	var level := _play_planet()
	level.home_slice.open_box(P1)
	Game.pause()
	_pause_menu().press(PauseMenu.Choice.RESTART)            # "Main menu"
	assert_int(Game.state).is_equal(Game.State.LOBBY)
	assert_bool(get_tree().paused).is_false()
	assert_object(_main.level).is_null()


# --- P-07 no forced movement ----------------------------------------------------------------

func test_camera_fits_both_then_follows_one_and_arrows_the_far_worm() -> void:
	var level := _two_worms()
	var cam := level.camera
	var a := Worm.of(P1)
	var b := Worm.of(P2)
	# Both worms framed: the first physics frame's FarCamera.step hands the camera both of them.
	assert_int(await _until(func() -> bool: return cam.targets.size() == 2, 30)).is_not_equal(-1)
	assert_bool(level.far_camera.split).is_false()
	assert_bool(FarCamera.fits(cam, [a, b])).is_true()
	b.warp_to(level.local_point(240, 0) - b.position)      # 237 tiles (3,792 px) past the widest zoom
	# Wait for what the test means: the split on and the camera settled on the anchor. Bound: the
	# split is due on the next physics frame; the ease (follow 6/s from at most half the worms' 48 px
	# spread, ln(24)/6 = 0.53 s, ~32 frames; no zoom step, fit_hold 0.4 s each) is well inside 300.
	assert_int(await _until(func() -> bool: return level.far_camera.split, 30)).is_not_equal(-1)
	assert_int(await _until(_camera_settled.bind(cam), 300)).is_not_equal(-1)
	# The split is measured against where the worms are now, not how far either slid meanwhile.
	assert_bool(level.far_camera.split).is_true()
	assert_bool(FarCamera.fits(cam, [a, b])).is_false()
	assert_array(cam.targets).is_equal([a])          # a tie: P1 keeps the camera
	assert_bool(cam.sees(a.cam_position(), 30.0)).is_true()
	# PlanetHud draws a worm's edge arrow exactly when not cam.sees(pos, 30.0) (_draw_hud).
	assert_bool(cam.sees(b.cam_position(), 30.0)).is_false()
	# Held B: the far worm warps to its partner; the partner does not move. Both are measured against
	# the partner where it stands at the warp, so its own earlier physics never enters the numbers.
	# PlanetLevel._on_warp_requested lands the warper's head 16 px beside the partner's head, along
	# the ground (partner.normalized().orthogonal() * 16); b's node sits at the origin, so exact.
	var a_before_warp := a.cam_position()
	var landing := a_before_warp + a_before_warp.normalized().orthogonal() * 16.0
	level._on_warp_requested(P2)
	assert_vector(b.cam_position()).is_equal_approx(landing, Vector2.ONE * 0.01)
	assert_vector(a.cam_position()).is_equal(a_before_warp)
	# Split clears once both fit with REJOIN to spare: 16 px apart, due on the next physics frame.
	assert_int(await _until(func() -> bool: return not level.far_camera.split, 30)).is_not_equal(-1)
	assert_bool(FarCamera.fits(cam, [a, b], FarCamera.REJOIN)).is_true()
	assert_int(cam.targets.size()).is_equal(2)


func test_far_camera_follows_the_bigger_worm() -> void:
	var level := _two_worms(2)
	var b := Worm.of(P2)
	Worm.of(P1).warp_to(level.local_point(240, 0) - Worm.of(P1).position)
	# The split is due on the next physics frame (FarCamera.step); wait on it, not a frame count.
	assert_int(await _until(func() -> bool: return level.far_camera.split, 30)).is_not_equal(-1)
	assert_bool(FarCamera.fits(level.camera, Worm.all())).is_false()
	assert_int(level.far_camera.anchor).is_equal(P2)
	assert_array(level.camera.targets).is_equal([b])
