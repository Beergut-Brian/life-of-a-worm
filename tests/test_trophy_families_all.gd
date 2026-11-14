## B-09 (worm-gap-close-39, Gary's pick): every find the worm can carry home belongs to exactly one
## trophy family, so whatever a player keeps on the shelf shows a charm and gives its family's small
## bonus. Before, only 8 of the 35 foods counted (a fossil, amber or a honeydew carried home did
## nothing). Per-trophy bonuses and caps are unchanged. Runs in its own Save profile.
class_name TestTrophyFamiliesAll
extends GdUnitTestSuite

const SUITE := "trophy_families_all"
const PLANET := preload("res://scenes/levels/planet.tscn")
const FOODS := "res://data/foods/"

var _level: PlanetLevel


func before() -> void:
	SuiteSandbox.enter(SUITE)


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	SuiteSandbox.leave()


func before_test() -> void:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	Audio.played.clear()


func after_test() -> void:
	for p in Audio._pool:
		p.stop()
	if is_instance_valid(_level):
		for n in _level.find_children("*", "AudioStreamPlayer", true, false):
			n.stop()
		remove_child(_level)
		_level.free()
	_level = null
	get_tree().paused = false
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func test_every_food_is_in_exactly_one_family() -> void:
	var families := TrophyFamily.load_all()
	assert_int(families.size()).is_equal(3)
	var none: Array[String] = []
	var twice: Array[String] = []
	var n := 0
	for f in ResourceLoader.list_directory(FOODS):
		if not f.ends_with(".tres"):
			continue
		n += 1
		var id := StringName(f.get_basename())
		var homes := families.filter(func(fam: TrophyFamily) -> bool: return fam.members.has(id))
		if homes.is_empty():
			none.append(String(id))
		elif homes.size() > 1:
			twice.append(String(id))
	assert_int(n).is_greater_equal(35)
	assert_array(none).override_failure_message("no trophy family: %s" % [none]).is_empty()
	assert_array(twice).override_failure_message("in two families: %s" % [twice]).is_empty()


func test_every_member_is_a_real_food() -> void:
	for fam in TrophyFamily.load_all():
		for m in fam.members:
			assert_bool(ResourceLoader.exists(FOODS + String(m) + ".tres")) \
				.override_failure_message("%s: %s is not a food" % [fam.id, m]).is_true()


func test_bonuses_and_caps_are_unchanged() -> void:
	var want := {
		&"stones": [{"wiggle_hop": 4.0}, 3],
		&"shinies": [{"pull_radius": 10.0, "pull_speed": 12.0}, 3],
		&"snacks": [{"speed": 3.0}, 3],
	}
	for fam in TrophyFamily.load_all():
		assert_dict(fam.per_trophy).is_equal(want[fam.id][0])
		assert_int(fam.cap).is_equal(want[fam.id][1])


## In play: a fossil, an amber and a honeydew carried home each count in their family, every worm
## feels it, and the shelf tags them in the family colour.
func test_new_finds_carried_home_give_their_family_bonus() -> void:
	BaitTins.open(0)
	Save.wipe()
	_level = PLANET.instantiate()
	add_child(_level)
	_level.home_slice.box.pause_tree = false
	var w := _level.spawn_worm(Players.P1)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	var at := w.cam_position()
	var c := _level.world.shape.cell_at(at)
	for y in range(-4, 5):
		for x in range(-4, 5):
			if _level.world.shape.center_of(c + Vector2i(x, y)).distance_to(at) <= 40.0:
				_level.world.dig(c + Vector2i(x, y))
	_level.burrow.set_home(at)
	var hop := w.model.stats.value("wiggle_hop")
	var pull := w.model.stats.value("pull_radius")
	var speed := w.model.stats.value("speed")
	for id in [&"fossil", &"amber", &"honeydew"]:
		var f := _level._add_food(id, w.mouth_position() + Vector2(2, 0))
		w.carrying = f
		f.set_carried(true)
		_level.burrow.note_pickup(w, false)
		assert_str(String(_level.burrow.bring(w, f))).is_equal("trophy")
	var counts := _level.burrow.family_counts()
	assert_int(int(counts.get(&"stones", 0))).is_equal(1)
	assert_int(int(counts.get(&"shinies", 0))).is_equal(1)
	assert_int(int(counts.get(&"snacks", 0))).is_equal(1)
	assert_float(w.model.stats.value("wiggle_hop")).is_equal_approx(hop + 4.0, 0.001)
	assert_float(w.model.stats.value("pull_radius")).is_equal_approx(pull + 10.0, 0.001)
	assert_float(w.model.stats.value("speed")).is_equal_approx(speed + 3.0, 0.001)
	var p2 := _level.spawn_worm(Players.P2)
	assert_float(p2.model.stats.value("wiggle_hop")).is_equal_approx(hop + 4.0, 0.001)
	assert_int(Audio.played.get("home_trophy", 0)).is_equal(3)
