## The end of a run in order (R-08, Y-07, Y-08): reaching space plays stage 7's dock scene ("Up it
## went") once per tin, after the why bubble, with the worms held still; eating the sun plays the
## ending ("Still out there") and then Old Reel's new tin, and only then the heirloom choice. Every
## scene counts through Story.started, never by polling. Saves go to res://.scratch/space_story_saves
## (Save.dir), never a real one.
extends GdUnitTestSuite

const SPACE := "res://scenes/levels/space_stage.tscn"
const DIR := "res://.scratch/space_story_saves"

var _stages: Array[SpaceStage] = []
var _started: Array[StringName] = []


func before() -> void:
	SuiteSandbox.enter("space_story")
	DirAccess.make_dir_recursive_absolute(DIR)
	Save.dir = DIR
	Save.use_profile(SuiteSandbox.profile_for("space_story"))


func after() -> void:
	_clean()
	Save.use_slot("")
	Save.dir = "user://saves"
	SuiteSandbox.leave()


func before_test() -> void:
	Game.demo = false
	Players.reset()
	_clean()
	Save.use_slot("tin1")
	Save.wipe()
	Save.set_value("seed", 5151)
	Save.set_value("worms", { "0": { "stage": 7, "earned": ["glow"], "active": ["glow"], "segments": [] } })
	_started.clear()


func after_test() -> void:
	for st in _stages:
		if is_instance_valid(st):
			st.free()
	_stages.clear()
	for s in get_tree().get_nodes_in_group(&"story"):
		s.free()
	Players.reset()
	Save.use_slot("")


func _clean() -> void:
	Save.use_slot("")
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "/" + f))


func _stage() -> SpaceStage:
	var s: SpaceStage = load(SPACE).instantiate()
	s.players.append(Players.P1)
	add_child(s)
	s.set_process(false)
	s.drift.set_process(false)
	_space_story(s).auto = false
	_offer(s).auto = false
	_stages.append(s)
	return s


func _space_story(s: SpaceStage) -> SpaceStory:
	return s.get_node("SpaceStory") as SpaceStory


func _offer(s: SpaceStage) -> OldReelOffer:
	return s.get_node("OldReelOffer") as OldReelOffer


## The tin's own Story (persist on: `seen` lives in the scratch tin), sped up.
func _story() -> Story:
	var st := Story.new()
	st.speed = 8.0
	add_child(st)
	st.started.connect(func(id: StringName) -> void: _started.append(id))
	return st


func _skip(st: Story) -> void:
	st.skip()
	await await_millis(150)


func test_the_space_stage_carries_the_arrival_scene() -> void:
	var s := _stage()
	assert_object(_space_story(s)).is_not_null()
	assert_bool(Story.SCENES.has(SpaceStory.SCENE)).is_true()
	assert_bool(CutscenePlayer.load_scene(SpaceStory.SCENE).is_empty()).is_false()
	# After the "nothing pulls down any more" bubble, never over it.
	assert_float(SpaceStory.ARRIVE_DELAY).is_greater(SpaceStage.WHY_TIME)


func test_reaching_space_plays_up_it_went_after_the_why_bubble() -> void:
	var s := _stage()
	var st := _story()
	var ss := _space_story(s)
	ss.auto = true
	ss._process(SpaceStory.ARRIVE_DELAY - 0.2)
	assert_array(_started).is_empty()                     # the why bubble is still up
	ss._process(0.3)
	assert_array(_started).is_equal([&"stage_7"])
	assert_bool(ss.holding()).is_true()
	s.worms[0].steer = Vector2.RIGHT                       # the worms hold still while Reel talks
	ss._process(0.016)
	assert_vector(s.worms[0].steer).is_equal(Vector2.ZERO)
	await _skip(st)
	assert_bool(ss.holding()).is_false()
	assert_bool(st.has_seen(&"stage_7")).is_true()
	ss._process(10.0)                                     # never twice
	assert_array(_started).is_equal([&"stage_7"])


func test_a_tin_reloaded_in_space_does_not_replay_it() -> void:
	var s := _stage()
	var st := _story()
	assert_bool(_space_story(s).play_scene()).is_true()
	await _skip(st)
	Save.flush()
	s.free()
	st.free()
	_started.clear()
	var t := _stage()
	var st2 := _story()                                    # a fresh Story reads the tin's story_seen
	assert_bool(st2.has_seen(&"stage_7")).is_true()
	assert_bool(_space_story(t).play_scene()).is_false()
	assert_array(_started).is_empty()


func test_past_the_sun_it_plays_nothing() -> void:
	var s := _stage()
	_story()
	s.drift.sun_gone = true
	assert_bool(_space_story(s).play_scene()).is_false()
	assert_array(_started).is_empty()


func test_the_sun_plays_the_ending_then_the_new_tin_then_the_choice() -> void:
	var s := _stage()
	var st := _story()
	var offer := _offer(s)
	s.drift.sun_eaten.emit(Players.P1)
	assert_str(String(offer.state)).is_equal("waiting")
	offer.play_scene()
	assert_array(_started).is_equal([&"ending"])
	assert_bool(offer.holding()).is_true()
	await _skip(st)                                        # skipping the ending goes on to Reel's offer
	assert_array(_started).is_equal([&"ending", &"new_tin"])
	assert_str(String(offer.state)).is_equal("story")      # no choice over his scene
	assert_object(offer.pick).is_null()
	await _skip(st)
	assert_str(String(offer.state)).is_equal("pick")
	assert_object(offer.pick).is_not_null()
	assert_bool(st.has_seen(&"ending")).is_true()


func test_an_ending_already_seen_goes_straight_to_the_new_tin() -> void:
	var s := _stage()
	var st := _story()
	st.seen.append(&"ending")
	var offer := _offer(s)
	s.drift.sun_eaten.emit(Players.P1)
	offer.play_scene()
	assert_array(_started).is_equal([&"new_tin"])


func test_the_whole_end_of_a_run_plays_in_story_order() -> void:
	var s := _stage()
	var st := _story()
	assert_bool(_space_story(s).play_scene()).is_true()   # arriving in space
	await _skip(st)
	s.drift.sun_eaten.emit(Players.P1)                     # the last meal
	var offer := _offer(s)
	offer.play_scene()
	await _skip(st)
	await _skip(st)
	assert_array(_started).is_equal([&"stage_7", &"ending", &"new_tin"])
	var order := Story.SCENES
	assert_bool(order.find(&"stage_7") < order.find(&"ending") and order.find(&"ending") < order.find(&"new_tin")).is_true()
	offer.pick.read_pads = false
	assert_bool(offer.pick.confirm()).is_true()            # the heirloom goes into the new tin
	assert_str(String(OldReelTin.offer().heirloom)).is_equal("glow")
