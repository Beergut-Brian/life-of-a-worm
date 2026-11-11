## Jar snapshot -> open -> close round trip, stage 6 disabled inside a jar, saves stay small.
extends GdUnitTestSuite

const DIR := "user://test_jars"

var jars: JarStore


func before() -> void:
	SuiteSandbox.enter("jars")


func after() -> void:
	SuiteSandbox.leave()


func before_test() -> void:
	Save.wipe()
	jars = auto_free(JarStore.new())
	jars.dir = DIR
	jars.clear()
	add_child(jars)


func after_test() -> void:
	if jars.is_in_jar():
		jars.close()
	jars.clear()


func _seed_tin() -> PlanetStandIn:
	var p := PlanetStandIn.generate("tin_1234", 1234, 30)
	Save.set_value("planet", p.to_save())
	Save.set_value("stage", 6)
	Save.set_value("traits", ["stone_head", "glow"])
	return p


func test_snapshot_writes_a_copy_of_the_save() -> void:
	var p := _seed_tin()
	var fired: Array = []
	jars.planet_jarred.connect(func(id): fired.append(id))
	var path := jars.snapshot(&"tin_1234")
	assert_str(path).is_equal(DIR + "/tin_1234.json")
	assert_bool(FileAccess.file_exists(path)).is_true()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_int(int(data.planet.seed)).is_equal(1234)
	assert_int(data.planet.bites.size()).is_equal(30)
	assert_array(data.jars).contains(["tin_1234"])
	assert_array(fired).is_equal([&"tin_1234"])
	assert_array(jars.list()).is_equal([&"tin_1234"])
	assert_array(Save.get_value("jars", [])).contains(["tin_1234"])
	# seed + edits: a planet with 30 edits stays small
	assert_int(FileAccess.get_file_as_bytes(path).size()).is_less(4096)
	# the stand-in rebuilds the same planet from the copy
	var back := PlanetStandIn.from_save(data.planet)
	assert_bool(back.image(64).get_data() == p.image(64).get_data()).is_true()


func test_open_loads_the_jar_with_stage6_disabled_and_close_returns() -> void:
	_seed_tin()
	jars.snapshot(&"tin_1234")
	var tin_profile := Save.profile
	assert_bool(JarStore.stage6_allowed()).is_true()
	# the tin goes on to eat its planet
	Save.set_value("stage", 7)
	Save.set_value("planet", null)
	Save.flush()
	assert_bool(jars.open(&"tin_1234")).is_true()
	assert_bool(jars.is_in_jar()).is_true()
	assert_str(Save.profile).is_equal("jar_tin_1234")
	assert_int(int(Save.get_value("stage"))).is_equal(6)
	assert_int(int(Save.get_value("planet").seed)).is_equal(1234)
	assert_bool(Save.get_value("jar", false)).is_true()
	assert_bool(JarStore.stage6_allowed()).is_false()
	# play inside the jar: a new bite is kept in the jar
	var planet: Dictionary = Save.get_value("planet")
	planet.bites.append([1.0, 0.5, 0.1])
	Save.set_value("planet", planet)
	jars.close()
	assert_str(Save.profile).is_equal(tin_profile)
	assert_int(int(Save.get_value("stage"))).is_equal(7)
	assert_bool(JarStore.stage6_allowed()).is_true()
	assert_bool(FileAccess.file_exists("user://saves/jar_tin_1234.json")).is_false()
	assert_bool(jars.open(&"tin_1234")).is_true()
	assert_int(Save.get_value("planet").bites.size()).is_equal(31)
	assert_bool(JarStore.stage6_allowed()).is_false()


func test_bad_or_missing_jar_ids() -> void:
	assert_str(jars.snapshot(&"../escape")).is_equal("")
	assert_bool(jars.open(&"nope")).is_false()
	assert_bool(jars.is_in_jar()).is_false()
