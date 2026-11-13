## Kid-check N6 (K-07): a damaged tin is never lost unseen. A save file that cannot be read is
## moved aside to <file>.bak (then .bak2, ...) before anything can write over it, Save says so
## (`damaged`), and the tin opens as a fresh planet. Every write goes to a side file first and is
## swapped in whole, so a stopped write never leaves half a tin. All files live in
## res://.scratch/save_damaged (Save.dir), never a real save.
extends GdUnitTestSuite

const DIR := "res://.scratch/save_damaged"

var _seen: Array[String] = []


func before() -> void:
	SuiteSandbox.enter("save_damaged")
	DirAccess.make_dir_recursive_absolute(DIR)
	Save.dir = DIR
	Save.use_profile(SuiteSandbox.profile_for("save_damaged"))
	Save.damaged.connect(_on_damaged)


func after() -> void:
	Save.damaged.disconnect(_on_damaged)
	_clean()
	Save.use_slot("")
	Save.dir = "user://saves"
	SuiteSandbox.leave()


func before_test() -> void:
	_seen.clear()
	Save.use_slot("")
	_clean()


func _on_damaged(path: String) -> void:
	_seen.append(path)


func _clean() -> void:
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_an_unreadable_tin_is_kept_as_a_backup_and_never_written_over() -> void:
	var path := Save.path_for("tin2")
	_write(path, "{\"planet\": {\"seed\": 7, \"edits\": [")   # cut off mid-write
	Save.use_slot("tin2")
	assert_array(_seen).has_size(1)
	assert_str(_seen[0]).is_equal(path + ".bak")
	assert_str(Save.last_backup).is_equal(path + ".bak")
	assert_bool(FileAccess.file_exists(path + ".bak")).is_true()
	assert_str(FileAccess.get_file_as_string(path + ".bak")).is_equal("{\"planet\": {\"seed\": 7, \"edits\": [")
	assert_bool(FileAccess.file_exists(path)).is_false()
	# the tin plays on as a new planet, and its first autosave leaves the backup alone
	assert_object(Save.get_value("planet")).is_null()
	Save.set_value("seed", 99)
	Save.flush()
	assert_str(FileAccess.get_file_as_string(path + ".bak")).is_equal("{\"planet\": {\"seed\": 7, \"edits\": [")
	assert_int(int(JSON.parse_string(FileAccess.get_file_as_string(path)).seed)).is_equal(99)


func test_a_second_damaged_file_does_not_replace_the_first_backup() -> void:
	var path := Save.path_for("tin3")
	_write(path, "not json")
	Save.use_slot("tin3")
	Save.use_slot("")
	_write(path, "[1, 2]")   # valid JSON but not a tin
	Save.use_slot("tin3")
	assert_array(_seen).is_equal([path + ".bak", path + ".bak2"])
	assert_str(FileAccess.get_file_as_string(path + ".bak")).is_equal("not json")
	assert_str(FileAccess.get_file_as_string(path + ".bak2")).is_equal("[1, 2]")


func test_a_good_tin_or_a_missing_one_is_not_damaged() -> void:
	Save.use_slot("tin1")   # no file yet: an empty tin, nothing to keep
	Save.set_value("seed", 5)
	Save.flush()
	Save.use_slot("")
	Save.use_slot("tin1")   # a good file reads back
	assert_array(_seen).is_empty()
	assert_int(int(Save.get_value("seed"))).is_equal(5)
	assert_bool(FileAccess.file_exists(Save.path_for("tin1") + ".bak")).is_false()


func test_a_write_goes_through_a_side_file_and_leaves_none_behind() -> void:
	Save.use_slot("tin1")
	Save.set_value("seed", 11)
	Save.flush()
	var path := Save.path_for("tin1")
	assert_bool(FileAccess.file_exists(path + ".tmp")).is_false()
	assert_int(int(JSON.parse_string(FileAccess.get_file_as_string(path)).seed)).is_equal(11)
	# a stale side file from a stopped write is simply replaced; the tin itself was never touched
	_write(path + ".tmp", "half a tin")
	Save.set_value("seed", 12)
	Save.flush()
	assert_bool(FileAccess.file_exists(path + ".tmp")).is_false()
	assert_int(int(JSON.parse_string(FileAccess.get_file_as_string(path)).seed)).is_equal(12)
