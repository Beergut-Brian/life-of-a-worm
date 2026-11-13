## After the sun the run goes on to the next tin (S-12, R-08): once the heirloom tin is on the rail,
## NextTinTrip takes the players back to the bait-tin dock with the new tin picked out, so nobody is
## left in an empty sky. It never goes before the choice is done, goes once, and needs a host with
## close_level() and a dock (scenes/main.gd is the real one). Trips count through `left`, not by
## polling. Saves go to res://.scratch/next_tin_saves (Save.dir), never a real one.
extends GdUnitTestSuite

const SPACE := "res://scenes/levels/space_stage.tscn"
const DIR := "res://.scratch/next_tin_saves"


## Stands in for scenes/main.gd: the same two members the trip uses.
class FakeMain extends Node:
	var dock: Dock
	var closed := 0

	func close_level() -> void:
		closed += 1
		dock.close()


var _stages: Array[SpaceStage] = []
var _host: FakeMain
var _trips: Array[int] = []


func before() -> void:
	SuiteSandbox.enter("next_tin_trip")
	DirAccess.make_dir_recursive_absolute(DIR)
	Save.dir = DIR
	Save.use_profile(SuiteSandbox.profile_for("next_tin_trip"))


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
	Save.set_value("seed", 777)
	Save.set_value("worms", { "0": { "stage": 7, "earned": ["glow"], "active": ["glow"], "segments": [] } })
	_trips.clear()
	_host = FakeMain.new()
	_host.dock = Dock.new()
	_host.add_child(_host.dock)
	add_child(_host)


func after_test() -> void:
	for st in _stages:
		if is_instance_valid(st):
			st.free()
	_stages.clear()
	for s in get_tree().get_nodes_in_group(&"story"):
		s.free()
	if is_instance_valid(_host):
		_host.free()
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
	(s.get_node("SpaceStory") as SpaceStory).auto = false
	(s.get_node("OldReelOffer") as OldReelOffer).auto = false
	var trip := _trip(s)
	trip.host = _host
	trip.left.connect(func(f: int) -> void: _trips.append(f))
	_stages.append(s)
	return s


func _trip(s: SpaceStage) -> NextTinTrip:
	return s.get_node("NextTinTrip") as NextTinTrip


## The sun, Reel's offer straight to the choice (his scenes are test_space_story's), A on the trait.
func _pick(s: SpaceStage) -> OldReelOffer:
	var offer: OldReelOffer = s.get_node("OldReelOffer")
	s.drift.sun_eaten.emit(Players.P1)
	offer.open_pick()
	offer.pick.read_pads = false
	assert_bool(offer.pick.confirm()).is_true()
	return offer


## Runs the pick's lid, rail and fade out by hand, then the trip's own timer.
func _finish(offer: OldReelOffer, trip: NextTinTrip) -> void:
	var p := offer.pick
	for i in 400:
		if not is_instance_valid(p) or p.is_queued_for_deletion():
			break
		p._process(0.05)
	trip._process(NextTinTrip.DELAY + 0.1)
	await await_idle_frame()


func test_the_boot_scene_is_a_host_the_trip_can_use() -> void:
	var main: Script = load("res://scenes/main.gd")
	var has_dock := false
	for prop in main.get_script_property_list():
		if prop.name == "dock":
			has_dock = true
	assert_bool(has_dock).is_true()
	var has_close := false
	for m in main.get_script_method_list():
		if m.name == "close_level":
			has_close = true
	assert_bool(has_close).is_true()


func test_after_the_heirloom_the_dock_opens_on_the_new_tin() -> void:
	var s := _stage()
	var trip := _trip(s)
	var offer := _pick(s)
	assert_str(String(trip.state)).is_equal("idle")        # not while the lid and rail still play
	await _finish(offer, trip)
	assert_str(String(offer.state)).is_equal("done")
	assert_array(_trips).is_equal([1])                     # tin2: the next free rail spot
	assert_int(_host.closed).is_equal(1)                    # the old tin saved and closed
	assert_bool(_host.dock.visible).is_true()
	assert_int(_host.dock.focus).is_equal(1)
	assert_str(BaitTins.slot_name(_host.dock.focus)).is_equal(String(OldReelTin.offer().get("slot", "")))
	# The tin it points at opens as a new planet (so the opening plays) that keeps the heirloom.
	assert_dict(BaitTins.summary(_host.dock.focus)).is_empty()


func test_it_waits_for_the_choice_and_goes_only_once() -> void:
	var s := _stage()
	var trip := _trip(s)
	trip._process(30.0)
	assert_array(_trips).is_empty()                        # no sun, no offer: it stays
	s.drift.sun_eaten.emit(Players.P1)
	trip._process(30.0)
	assert_array(_trips).is_empty()                        # offered, still choosing: it stays
	var offer: OldReelOffer = s.get_node("OldReelOffer")
	offer.open_pick()
	offer.pick.read_pads = false
	offer.pick.confirm()
	await _finish(offer, trip)
	assert_int(_trips.size()).is_equal(1)
	offer.done.emit()
	assert_bool(trip.go()).is_false()
	trip._process(30.0)
	await await_idle_frame()
	assert_int(_trips.size()).is_equal(1)
	assert_int(_host.closed).is_equal(1)


func test_a_full_rail_still_goes_to_the_dock_without_moving_the_pick() -> void:
	for slot in ["tin2", "tin3"]:                          # every other spot taken
		Save.use_slot(slot)
		Save.set_value("seed", 1)
		Save.flush()
	Save.use_slot("tin1")
	var s := _stage()
	_host.dock.focus = 0
	var offer := _pick(s)
	assert_str(String(OldReelTin.offer().get("slot", "x"))).is_equal("")
	await _finish(offer, _trip(s))
	assert_array(_trips).is_equal([-1])
	assert_bool(_host.dock.visible).is_true()
	assert_int(_host.dock.focus).is_equal(0)


func test_with_no_host_it_stays_put() -> void:
	var s := _stage()
	var trip := _trip(s)
	trip.host = null                                       # the test runner is not the boot scene
	_pick(s)
	trip.state = &"waiting"
	assert_bool(trip.go()).is_false()
	assert_array(_trips).is_empty()
