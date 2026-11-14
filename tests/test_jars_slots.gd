## Planet jars from a real bait tin (a Save slot): the snapshot writes <dir>/<planet>.json and loads back
## identical, re-entering a jar has stage 6 off while a normal tin keeps it on, the jar file never holds
## the found-set (Old Reel's tackle box) or settings, and opening a jar shows the planet in its jar
## before it loads. Every file is in this suite's sandbox profile and its own jar dir.
extends GdUnitTestSuite

const DIR := "user://test_jars_slots"
const CHOMP := "res://scenes/levels/planet_chomp.tscn"
const OPEN_VIEW := "res://scenes/jars/jar_open.tscn"

var jars: JarStore


func before() -> void:
	SuiteSandbox.enter("jars_slots")


func after() -> void:
	for i in 3:
		BaitTins.open(i)
		Save.wipe()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(Save.slot)))
	Save.use_slot("")
	SuiteSandbox.leave()


func before_test() -> void:
	Save.use_slot("")
	Save.wipe()
	BaitTins.open(1)      # slot "tin2"
	Save.wipe()
	Audio.played.clear()
	jars = auto_free(JarStore.new())
	jars.dir = DIR
	jars.clear()
	add_child(jars)


func after_test() -> void:
	if jars.is_in_jar():
		jars.close()
	jars.clear()
	for p in Audio._pool:   # placeholder beeps must not outlive the suite
		p.stop()


## A tin as the planet level saves it, plus the tin's own things (found-set, a stray "solo").
func _seed_tin() -> StringName:
	var p := PlanetStandIn.generate("", 5150, 12)
	Save.set_value("seed", 5150)
	Save.set_value("planet", p.to_save())
	Save.set_value("stage", 6)
	Save.set_value("worms", {"0": {"segments": 9, "traits": ["glow"]}})
	Save.set_value("burrow", {"trophies": ["crystal"]})
	Save.set_value("home_slice", {"tackle": {"found": {"foods": ["grub"]}}, "shop": {"kept": ["bottle_cap"]}})
	Save.set_value("tackle", {"found": {"foods": ["grub"]}})
	Save.set_value("solo", true)
	Save.set_setting("music_volume", 0.42)
	return JarStore.current_planet_id(5150)


func _file(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func test_planet_id_names_the_tin() -> void:
	assert_str(String(JarStore.current_planet_id(5150))).is_equal("gdunit_jars_slots_tin2_5150")


func test_snapshot_of_a_tin_writes_the_jar_and_loads_back_identical() -> void:
	var id := _seed_tin()
	var path := jars.snapshot(id)
	assert_str(path).is_equal(DIR + "/" + String(id) + ".json")
	assert_bool(FileAccess.file_exists(path)).is_true()
	# the jar is the tin's slot file (not the profile's slotless one), minus the tin's own keys
	var tin := _file(Save.path_for(Save.slot))
	var jar := _file(path)
	assert_dict(jar).is_equal(JarStore.strip_tin_only(tin))
	assert_int(int(jar.planet.seed)).is_equal(5150)
	assert_int(int(jar.worms["0"].segments)).is_equal(9)
	assert_array(jar.burrow.trophies).contains_exactly(["crystal"])
	assert_dict(jars.peek(id)).is_equal(jar)
	# loads back identical: every planet key of the jar is what the opened save holds
	assert_bool(jars.open(id)).is_true()
	for key in jar:
		if key == "home_slice":
			assert_dict(Save.get_value(key).shop).is_equal(jar[key].shop)
		else:
			assert_that(Save.get_value(key)).is_equal(jar[key])


func test_reentering_a_jar_has_stage6_off_and_the_tin_keeps_it_on() -> void:
	var id := _seed_tin()
	jars.snapshot(id)
	# a normal planet: stage 6 is on and the chomp can begin
	assert_bool(JarStore.stage6_allowed()).is_true()
	var c: PlanetChomp = _chomp()
	assert_bool(c.begin()).is_true()
	c.free()
	assert_bool(jars.open(id)).is_true()
	assert_str(Save.profile).is_equal("jar_" + String(id))
	assert_bool(JarStore.stage6_allowed()).is_false()
	var inside: PlanetChomp = _chomp()
	assert_bool(inside.begin()).is_false()
	inside.free()
	jars.close()
	# back in the same tin slot, stage 6 on again
	assert_str(Save.profile).is_equal(SuiteSandbox.profile_for("jars_slots"))
	assert_str(Save.slot).is_equal("tin2")
	assert_int(int(Save.get_value("seed"))).is_equal(5150)
	assert_bool(JarStore.stage6_allowed()).is_true()
	assert_bool(FileAccess.file_exists("user://saves/jar_%s.json" % id)).is_false()


func test_the_jar_file_holds_no_found_set_and_no_settings() -> void:
	var id := _seed_tin()
	var jar := _file(jars.snapshot(id))
	assert_bool(jar.has("tackle")).is_false()
	assert_bool(jar.home_slice.has("tackle")).is_false()
	assert_bool(jar.home_slice.has("shop")).is_true()
	assert_bool(jar.has("solo")).is_false()
	assert_bool(jar.has("settings")).is_false()
	assert_bool(JSON.stringify(jar).contains("music_volume")).is_false()
	assert_bool(JSON.stringify(jar).contains("grub")).is_false()


func test_the_found_set_is_lent_into_the_jar_and_comes_back_with_new_finds() -> void:
	var id := _seed_tin()
	jars.snapshot(id)
	assert_bool(jars.open(id)).is_true()
	assert_array(Save.get_value("home_slice").tackle.found.foods).contains_exactly(["grub"])
	var hs: Dictionary = Save.get_value("home_slice").duplicate(true)
	hs.tackle.found.foods.append("glowcap")
	Save.set_value("home_slice", hs)
	jars.close()
	# the tin's book has the find; the jar file still has no found-set
	assert_array(Save.get_value("home_slice").tackle.found.foods).contains_exactly(["grub", "glowcap"])
	assert_array(Save.get_value("home_slice").shop.kept).contains_exactly(["bottle_cap"])
	var jar := _file(DIR + "/" + String(id) + ".json")
	assert_bool(jar.home_slice.has("tackle")).is_false()
	assert_bool(jar.has("tackle")).is_false()


func test_opening_a_jar_shows_the_planet_in_it_then_loads() -> void:
	var id := _seed_tin()
	jars.snapshot(id)
	var v: JarOpenView = auto_free(load(OPEN_VIEW).instantiate())
	add_child(v)
	v.set_process(false)
	assert_bool(v.show_jar(jars, &"no_such_jar")).is_false()
	var got: Array = []
	v.entered.connect(func(x): got.append(x))
	assert_bool(v.show_jar(jars, id)).is_true()
	assert_object(v.planet_texture).is_not_null()     # the jar's own planet is drawn in the glass
	var dt := 1.0 / 60.0
	for i in int((JarOpenView.ENTER_AT - 0.1) / dt):
		v.advance(dt)
	# still on the shelf, diving: nothing loaded yet, a sound on each beat so far
	assert_bool(v.opened).is_false()
	assert_bool(jars.is_in_jar()).is_false()
	assert_float(v.dive()).is_greater(0.5)
	assert_int(Audio.played.get("jar_clink", 0)).is_equal(1)
	assert_int(Audio.played.get("burst", 0)).is_equal(1)     # lid pop (reuses burst until jar_open exists)
	assert_int(Audio.played.get("tunnel", 0)).is_equal(1)    # dive (reuses tunnel until jar_enter exists)
	for i in 20:
		v.advance(dt)
	assert_bool(v.opened).is_true()
	assert_array(got).is_equal([id])
	assert_bool(jars.is_in_jar()).is_true()
	assert_bool(JarStore.stage6_allowed()).is_false()
	assert_float(v.dive()).is_equal(1.0)


func _chomp() -> PlanetChomp:
	var c: PlanetChomp = load(CHOMP).instantiate()
	c.autostart = false
	c.auto_space = false
	var own := JarStore.new()   # a private store on a scratch shelf, never the shared Jars autoload
	own.name = "Jars"
	own.dir = DIR
	c.add_child(own)
	add_child(c)
	c.set_process(false)
	return c
