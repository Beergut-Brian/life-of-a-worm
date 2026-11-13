## X-01 sweep: every file in data/secrets/ against the row. One hidden place in every ring (the five
## tile rings and the sky), each with a unique food that nothing else on the planet spawns, its
## tackle-box entry (secrets page and foods page), its own find picture and a find sound on disk.
## The per-place tests (test_secrets_2, test_secrets_3, test_core_cathedral, test_secret_surface)
## stage the find and the food in a world; this one makes sure no file slips past them.
extends GdUnitTestSuite

const DIR := "res://data/secrets/"
const RINGS := [&"core", &"deep_rock", &"dirt", &"topsoil", &"surface", &"sky"]


func _files() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".tres"):
			out.append(f)
	return out


func _scatter_ids() -> Dictionary:
	var ids := {}
	for life in RingsDirector.LIVES + [RingsDirector.SKY, RingsDirector.SURFACE]:
		for f in life.scatter:
			ids[f.id] = true
	return ids


func test_every_secret_file_is_loaded_and_named_for_its_file() -> void:
	var files := _files()
	assert_int(files.size()).is_greater_equal(RINGS.size())
	assert_int(RingsDirector.SECRETS.size()).is_equal(files.size())
	for f in files:
		var s := load(DIR + f) as SecretData
		assert_object(s).override_failure_message("%s is not a SecretData" % f).is_not_null()
		assert_str(String(s.id)).is_equal(f.get_basename())
		assert_object(RingsDirector.secret(s.id)).is_not_null()


func test_every_ring_has_its_hidden_place() -> void:
	var by_ring := {}
	for s in RingsDirector.SECRETS:
		assert_bool(s.ring in RINGS).override_failure_message("%s: ring %s" % [s.id, s.ring]).is_true()
		by_ring[s.ring] = true
	for ring in RINGS:
		assert_bool(by_ring.has(ring)).override_failure_message("no hidden place in %s" % ring).is_true()


func test_each_has_a_unique_food_nothing_else_spawns() -> void:
	var scatter := _scatter_ids()
	var seen := {}
	for s in RingsDirector.SECRETS:
		assert_int(s.food_count).override_failure_message("%s: no food" % s.id).is_greater(0)
		assert_bool(seen.has(s.food)).override_failure_message("%s shares %s" % [s.id, s.food]).is_false()
		seen[s.food] = true
		var path := "res://data/foods/%s.tres" % s.food
		assert_bool(ResourceLoader.exists(path)).override_failure_message("%s: no %s" % [s.id, path]).is_true()
		var d := load(path) as RingFood
		assert_object(d).is_not_null()
		assert_str(String(d.ring)).override_failure_message("%s: food in another ring" % s.id) \
				.is_equal(String(s.ring))
		assert_bool(scatter.has(s.food)).override_failure_message("%s: %s also scattered" % [s.id, s.food]) \
				.is_false()
		# no other secret hands it out as its extra
		for o in RingsDirector.SECRETS:
			assert_str(String(o.extra_food)).is_not_equal(String(s.food))


func test_each_has_its_tackle_box_entries_picture_and_sound() -> void:
	var tlog := TackleLog.new()
	for s in RingsDirector.SECRETS:
		assert_str(String(s.page)).is_equal("secret_%s" % s.id)
		assert_array(tlog.entries[&"secrets"]).override_failure_message("%s: no page" % s.id).contains([s.id])
		assert_array(tlog.entries[&"foods"]).override_failure_message("%s: food has no page" % s.id) \
				.contains([s.food])
		assert_bool(SecretLook.has(s.id)).override_failure_message("%s: no find picture" % s.id).is_true()
		assert_bool(ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % s.cue)) \
				.override_failure_message("%s: no %s.ogg" % [s.id, s.cue]).is_true()
	tlog.free()
