## Old Reel's next tin after the sun (S-12): the sun offers a new tin once per tin, Reel's scene
## plays then the heirloom choice (earned traits only), the new tin has its own seed and planet
## type, sits on the rail as a new planet, and gives the chosen trait (equipped) to every worm in
## it, across a reload. Every save goes to res://.scratch/old_reel_saves (Save.dir), never a real one.
extends GdUnitTestSuite

const SPACE := "res://scenes/levels/space_stage.tscn"
const PLANET := preload("res://scenes/levels/planet.tscn")
const DIR := "res://.scratch/old_reel_saves"
const OLD_SEED := 4242

var _level: PlanetLevel
var _stages: Array[SpaceStage] = []


func before() -> void:
	SuiteSandbox.enter("old_reel_tin")
	DirAccess.make_dir_recursive_absolute(DIR)
	Save.dir = DIR
	Save.use_profile(SuiteSandbox.profile_for("old_reel_tin"))


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
	Save.set_value("seed", OLD_SEED)
	Save.set_value("worms", {
		"0": { "stage": 7, "earned": ["glow", "magnet", "bogus_trait"], "active": ["glow"], "segments": [] },
		"1": { "stage": 7, "earned": ["slick"], "active": ["slick"], "segments": [] } })


func after_test() -> void:
	if is_instance_valid(_level):
		remove_child(_level)
		_level.free()
	_level = null
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
	(s.get_node("OldReelOffer") as OldReelOffer).auto = false
	_stages.append(s)
	return s


func _story() -> Story:
	var st := Story.new()
	st.persist = false
	st.speed = 8.0
	add_child(st)
	return st


func test_sun_eaten_offers_the_tin_once_never_twice_per_tin() -> void:
	var s := _stage()
	var offer: OldReelOffer = s.get_node("OldReelOffer")
	var fired: Array = []
	offer.offered.connect(func(d): fired.append(d))
	s.drift.sun_eaten.emit(Players.P1)
	assert_int(fired.size()).is_equal(1)
	assert_str(String(offer.state)).is_equal("waiting")
	var d := OldReelTin.offer()
	assert_str(String(d.slot)).is_equal("tin2")                  # the next free spot on the rail
	assert_bool(FileAccess.file_exists(Save.path_for("tin2"))).is_true()
	s.drift.sun_eaten.emit(Players.P1)                            # the sun again: nothing new
	assert_int(fired.size()).is_equal(1)
	assert_dict(OldReelTin.offer()).is_equal(d)
	# Reel's scene plays (skippable), then the choice; the worms hold still meanwhile.
	var st := _story()
	offer.play_scene()
	assert_str(String(st.current())).is_equal("new_tin")
	assert_bool(offer.holding()).is_true()
	s.worms[0].steer = Vector2.RIGHT
	offer._process(0.016)
	assert_vector(s.worms[0].steer).is_equal(Vector2.ZERO)
	st.skip()
	await await_millis(200)
	assert_str(String(offer.state)).is_equal("pick")
	assert_object(offer.pick).is_not_null()
	offer.pick.read_pads = false
	assert_bool(offer.pick.confirm()).is_true()
	assert_bool(bool(OldReelTin.offer().picked)).is_true()
	assert_str(String(OldReelTin.offer().heirloom)).is_equal("glow")
	# The same tin reloaded (or another sun in it) never offers again.
	Save.flush()
	s.free()
	var t := _stage()
	var fired2: Array = []
	(t.get_node("OldReelOffer") as OldReelOffer).offered.connect(func(x): fired2.append(x))
	t.drift.sun_eaten.emit(Players.P1)
	assert_int(fired2.size()).is_equal(0)
	assert_str(String((t.get_node("OldReelOffer") as OldReelOffer).state)).is_equal("idle")


func test_the_heirloom_list_offers_only_earned_traits() -> void:
	var list := OldReelTin.earned_traits(Players.P1)
	assert_array(list).is_equal([&"glow", &"magnet"])             # unknown ids are dropped
	assert_array(OldReelTin.earned_traits(Players.P2)).is_equal([&"slick"])
	OldReelTin.make(Players.P1)
	assert_bool(OldReelTin.choose(&"drill_head")).is_false()      # never earned: refused
	assert_bool(OldReelTin.choose(&"slick")).is_false()           # the other worm's
	var s := _stage()
	var offer: OldReelOffer = s.get_node("OldReelOffer")
	offer.open_pick()
	offer.pick.read_pads = false
	assert_array(offer.pick.traits).is_equal(list)                 # the picker shows exactly these
	offer.pick.move(1)
	assert_bool(offer.pick.confirm()).is_true()
	assert_str(String(OldReelTin.offer().heirloom)).is_equal("magnet")
	assert_bool(OldReelTin.choose(&"glow")).is_false()            # chosen once, kept


func test_nothing_earned_still_puts_an_empty_tin_on_the_rail() -> void:
	Save.set_value("worms", {})
	OldReelTin.make(Players.P1)
	var s := _stage()
	var offer: OldReelOffer = s.get_node("OldReelOffer")
	offer.open_pick()
	assert_array(offer.pick.traits).is_empty()
	assert_str(String(offer.pick.phase)).is_equal("rail")
	assert_bool(bool(OldReelTin.offer().picked)).is_true()
	Save.use_slot("tin2")
	assert_str(String(OldReelTin.heirloom())).is_equal("")


func test_the_new_tin_round_trips_with_its_own_seed_and_keeps_the_heirloom() -> void:
	var d := OldReelTin.make(Players.P1)
	assert_bool(OldReelTin.choose(&"magnet")).is_true()
	var new_seed := int(d.seed)
	assert_int(new_seed).is_not_equal(OLD_SEED)
	assert_int(new_seed).is_equal(OldReelTin.next_seed(OLD_SEED))
	assert_str(String(d.theme)).is_equal(String(SpaceDrift.shuffled((load(SpaceDrift.LIFE_PATH) as SpaceLife).planets, new_seed)[0].id))
	assert_dict(BaitTins.summary(1)).is_empty()                    # on the rail as a new planet
	# Open it: a new planet from its own seed, the heirloom earned and equipped (stage 1, no slots).
	Save.use_slot("tin2")
	assert_str(String(OldReelTin.heirloom())).is_equal("magnet")
	_level = PLANET.instantiate()
	add_child(_level)
	_level.worm_spawned.connect(OldReelTin.give)
	var w := _level.spawn_worm(Players.P1)
	assert_int(_level.planet_seed).is_equal(new_seed)
	assert_int(w.model.stage).is_equal(1)
	assert_array(w.model.earned).contains([&"magnet"])
	assert_array(w.model.active).contains([&"magnet"])
	assert_array(w.model.earned).not_contains([&"glow"])          # only the one chosen
	_level.save_now()
	Save.flush()
	remove_child(_level)
	_level.free()
	_level = null
	Save.use_slot("")
	assert_dict(BaitTins.summary(1)).is_not_empty()
	# Reload: same seed, still keeps it (and still on at stage 1).
	Save.use_slot("tin2")
	_level = PLANET.instantiate()
	add_child(_level)
	_level.worm_spawned.connect(OldReelTin.give)
	var w2 := _level.spawn_worm(Players.P1)
	assert_int(_level.planet_seed).is_equal(new_seed)
	assert_array(w2.model.earned).contains([&"magnet"])
	assert_array(w2.model.active).contains([&"magnet"])
	assert_str(String(OldReelTin.heirloom())).is_equal("magnet")
	# The old tin is untouched and remembers it made the offer.
	remove_child(_level)
	_level.free()
	_level = null
	Save.use_slot("tin1")
	assert_int(int(Save.get_value("seed", 0))).is_equal(OLD_SEED)
	assert_str(String(OldReelTin.offer().slot)).is_equal("tin2")


func test_a_full_rail_keeps_the_offer_until_a_spot_is_free_and_never_overwrites() -> void:
	for slot in ["tin2", "tin3"]:
		var f := FileAccess.open(Save.path_for(slot), FileAccess.WRITE)
		f.store_string(JSON.stringify({ "seed": 7, "planet": { "edits": [] } }))
		f.close()
	var d := OldReelTin.make(Players.P1)
	assert_str(String(d.slot)).is_equal("")
	assert_bool(OldReelTin.place()).is_false()
	for slot in ["tin2", "tin3"]:
		assert_bool(FileAccess.get_file_as_string(Save.path_for(slot)).contains("\"planet\"")).is_true()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for("tin3")))
	assert_bool(OldReelTin.place()).is_true()
	assert_str(String(OldReelTin.offer().slot)).is_equal("tin3")


func test_only_real_tins_make_offers() -> void:
	Save.use_slot(BaitTins.DEMO)
	Save.wipe()
	assert_dict(OldReelTin.make(Players.P1)).is_empty()
	assert_bool(OldReelTin.offered()).is_false()


func test_the_book_and_the_pictures_know_the_heirloom() -> void:
	StoryPictures.register_all()
	assert_bool(PictoBubble.has_picture(&"bait_tin")).is_true()
	assert_bool(PictoBubble.has_picture(&"trait:glow")).is_true()
	assert_bool(Story.SCENES.has(&"new_tin")).is_true()           # rewatchable in the tackle box
	assert_bool(FileAccess.get_file_as_string("res://scripts/tackle/tackle_box.gd").contains("OldReelTin.heirloom()")).is_true()
