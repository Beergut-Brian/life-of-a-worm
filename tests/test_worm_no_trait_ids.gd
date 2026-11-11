## No trait is a special case: worm code and the worm scene never name a trait id.
class_name TestWormNoTraitIds
extends GdUnitTestSuite

const DIRS := ["res://scripts/worm/"]
const EXTRA := ["res://scenes/players/worm.tscn"]


func _files() -> Array[String]:
	var out: Array[String] = []
	for d in DIRS:
		for f in DirAccess.get_files_at(d):
			if f.get_extension() in ["gd", "gdshader", "tscn", "tres"]:
				out.append(d + f)
	out.append_array(EXTRA)
	return out


func test_worm_code_names_no_trait() -> void:
	var ids: Array[String] = []
	for t in WormRules.default_rules().traits:
		ids.append(String(t.id))
	assert_int(ids.size()).is_greater_equal(6)
	var files := _files()
	assert_int(files.size()).is_greater_equal(6)
	for path in files:
		var text := FileAccess.get_file_as_string(path).to_lower()
		for id in ids:
			var re := RegEx.create_from_string("(?<![a-z0-9_])" + id + "(?![a-z0-9_])")
			var hit := re.search(text)
			assert_object(hit).override_failure_message("%s names trait '%s'" % [path, id]).is_null()
