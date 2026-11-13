## P-23 (and CLAUDE.md "no personal info"): the dock, pond, shed and town are invented and generic.
## Every shipped text (data, scenes, scripts, the story script) is scanned for things that point at a
## real person or place: e-mail addresses, web links, phone numbers, street addresses, named lakes,
## rivers, towns and "...ville"s, and a dock / pond / shed / town that belongs to anyone who is not one
## of the game's own invented characters. The Reviewer still reads every new prop and cutscene.
class_name TestNoPersonalInfo
extends GdUnitTestSuite

const ROOTS := ["res://data", "res://scenes", "res://scripts", "res://docs/story-script.md"]
## Tool scripts carry generator seeds and prompts, never shipped text.
const SKIP := ["res://scripts/tools"]
const EXT := ["json", "tres", "tscn", "gd", "md", "txt", "cfg"]
const PATTERNS := {
	"e-mail": "[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\\.[A-Za-z]{2,}",
	"web link": "https?://",
	"phone number": "\\(?\\b[0-9]{3}\\)?[-. ][0-9]{3}[-. ][0-9]{4}\\b",
	"street address": "\\b[0-9]+ [A-Z][a-z]+ (Street|St|Road|Rd|Avenue|Ave|Lane|Ln|Drive|Dr|Boulevard|Blvd|Court|Ct)\\b",
	"named water or mountain": "\\b(Lake|Mount|Mt|Port|Fort|Saint) [A-Z][a-z]+",
	"named place": "\\b[A-Z][a-z]+ (Lake|Pond|River|Creek|Bay|County|City|Township)\\b",
	"town name": "\\b[A-Z][a-z]+(ville|burg|borough)\\b",
}
## "<Word> dock / pond / shed / town / farm": the word must be ordinary or one of our own Jarlings.
const OWNED := "\\b([A-Z][a-z]+)('s)? ([Dd]ock|[Pp]ond|[Ss]hed|[Tt]own|[Ff]arm|[Ss]treet)\\b"
const OK_OWNERS := ["The", "A", "An", "Old", "Whole", "Placeholder", "Our", "His", "Her", "Their",
		"That", "This", "Same", "Little", "Big", "Quiet", "Sleepy", "Night", "Dawn", "Empty",
		"Reel", "Bobber", "Mole", "Grandma", "Grandpa"]


func _files(path: String, out: Array[String]) -> void:
	for s in SKIP:
		if path.begins_with(s):
			return
	if FileAccess.file_exists(path):
		if path.get_extension() in EXT:
			out.append(path)
		return
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		_files(path.path_join(f), out)
	for sub in d.get_directories():
		if not sub.begins_with("."):
			_files(path.path_join(sub), out)


func _shipped() -> Array[String]:
	var out: Array[String] = []
	for r in ROOTS:
		_files(r, out)
	return out


func test_the_scan_reads_the_story_and_the_data() -> void:
	var files := _shipped()
	assert_int(files.size()).is_greater(100)
	assert_bool(files.has("res://data/story/lines.json")).is_true()
	assert_bool(files.has("res://data/cutscenes/opening.json")).is_true()
	assert_bool(files.has("res://docs/story-script.md")).is_true()


func test_no_shipped_text_points_at_a_real_person_or_place() -> void:
	var hits: Array[String] = []
	var res := {}
	for k in PATTERNS:
		var re := RegEx.new()
		re.compile(PATTERNS[k])
		res[k] = re
	for path in _shipped():
		var text := FileAccess.get_file_as_string(path)
		for k in res:
			for m in (res[k] as RegEx).search_all(text):
				hits.append("%s: %s \"%s\"" % [path, k, m.get_string()])
	assert_array(hits).override_failure_message("\n".join(hits)).is_empty()


func test_the_dock_pond_shed_and_town_belong_to_nobody_real() -> void:
	var re := RegEx.new()
	re.compile(OWNED)
	var hits: Array[String] = []
	for path in _shipped():
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			if not m.get_string(1) in OK_OWNERS:
				hits.append("%s: \"%s\"" % [path, m.get_string()])
	assert_array(hits).override_failure_message("\n".join(hits)).is_empty()


func test_the_guard_catches_what_it_is_for() -> void:
	# Invented examples only: the patterns must fire on them.
	var samples := {
		"e-mail": "write to someone@example.org",
		"phone number": "call 555-010-0000",
		"street address": "at 12 Example Street",
		"named place": "down by Example Lake",
		"town name": "the folks in Sampleville",
	}
	for k in samples:
		var re := RegEx.new()
		re.compile(PATTERNS[k])
		assert_object(re.search(samples[k])).override_failure_message(k).is_not_null()
	var own := RegEx.new()
	own.compile(OWNED)
	var m := own.search("we went to Example's pond")
	assert_object(m).is_not_null()
	assert_bool(m.get_string(1) in OK_OWNERS).is_false()
	assert_bool(own.search("Reel's shed").get_string(1) in OK_OWNERS).is_true()
