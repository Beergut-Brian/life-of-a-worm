## Y-01: a new tin opens on the opening; the worms wait still under it; its handoff glides the camera
## from the grass down to the worm and hands the stick back (never moving the worm); a blinking stick
## hint stays until the worm moves; a tin that has seen the opening never plays it again.
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")

var _level: PlanetLevel


func before() -> void:
	SuiteSandbox.enter("opening_hook")


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	for p in Audio._pool:
		p.stop()
	SuiteSandbox.leave()


func before_test() -> void:
	OpeningHook.enabled = true
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	BaitTins.open(0)
	Save.wipe()
	_level = PLANET.instantiate()
	add_child(_level)
	_level.stage_beat.make_story = false


func after_test() -> void:
	OpeningHook.enabled = false
	if is_instance_valid(_level):
		remove_child(_level)
		_level.free()
	_level = null
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func test_the_opening_holds_the_worm_then_glides_down_and_hands_back_the_stick() -> void:
	var w := _level.spawn_worm(Players.P1)
	var hook := OpeningHook.start(_level, 4.0)
	assert_object(hook).is_not_null()
	assert_int(hook.state).is_equal(OpeningHook.State.SCENE)
	assert_bool(hook.story.is_playing()).is_true()
	assert_str(String(hook.story.current())).is_equal("opening")
	await _frames(3)
	assert_bool(w.autopilot.is_valid()).override_failure_message("the worm waits still under the scene").is_true()
	assert_object(w._read_intent().move).is_equal(Vector2.ZERO)
	# Any button skips; the opening's last step (always: true) is the handoff.
	hook.story.skip()
	await _frames(4)
	assert_int(hook.state).is_equal(OpeningHook.State.GLIDE)
	assert_bool(w.autopilot.is_valid()).override_failure_message("the stick is the player's again").is_false()
	assert_bool(hook.story.has_seen(&"opening")).is_true()
	# The glide starts on the grass straight above the worm and ends on the worm.
	var surface := float(PlanetLevel.RADIUS * _level.world.shape.cell_size)
	assert_float(hook.glide_from.length()).is_equal_approx(surface, 1.0)
	assert_float(hook.glide_from.angle_to(w.cam_position())).is_equal_approx(0.0, 0.01)
	assert_bool(_level.camera.fit).is_false()
	await get_tree().create_timer(OpeningHook.GLIDE * 0.5).timeout
	var mid: Vector2 = _level.camera.centre_override
	assert_float(mid.length()).is_less(surface - 50.0)                       # on its way down
	assert_float(mid.length()).is_greater(w.cam_position().length() + 50.0)  # not there yet
	await get_tree().create_timer(OpeningHook.GLIDE * 0.5 + 0.2).timeout
	assert_int(hook.state).is_equal(OpeningHook.State.HINT)
	assert_bool(_level.camera.fit).is_true()
	assert_that(_level.camera.centre_override).is_null()
	assert_vector(w.cam_position()).is_equal_approx(hook._hint_from, Vector2.ONE * 2.0)  # nothing moved it
	# The stick hint stays until the player moves the worm.
	w.autopilot = func(_w) -> Dictionary: return { "move": Vector2.from_angle(-PI / 2.0) }
	for i in 120:
		await get_tree().physics_frame
		if not is_instance_valid(hook):
			break
	assert_bool(is_instance_valid(hook)).override_failure_message("the hint goes once the worm moves").is_false()


func test_a_tin_that_saw_the_opening_never_plays_it_again() -> void:
	_level.spawn_worm(Players.P1)
	var story := Story.new()
	story.seen.append(&"opening")
	_level.add_child(story)
	assert_object(OpeningHook.start(_level)).is_null()
	assert_bool(story.is_playing()).is_false()


func test_switched_off_it_never_starts() -> void:
	_level.spawn_worm(Players.P1)
	OpeningHook.enabled = false
	assert_object(OpeningHook.start(_level)).is_null()
	assert_object(Story.find(get_tree())).is_null()
