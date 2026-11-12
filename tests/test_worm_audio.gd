## Audio lane (worm-audio-1): every cue name the game plays resolves to a designed file in
## assets/audio/sfx/ and nothing falls back to GreyBeep's placeholder beep. The cue names are
## read from the code itself (scripts/ and scenes/ .gd files, data/ .tres), so a new call site
## without a file turns this suite red.
extends GdUnitTestSuite

const SFX_DIR := "res://assets/audio/sfx/"
const CUES_DOC := "res://assets/audio/CUES.md"
const CHOMP_CUES := 5   # scripts/worm/worm.gd CHOMP_CUES: "chomp_%d" % rel, rel in 1..5

## Lines that play a cue: Audio.play / Audio.loop_player, the prototype players (ProtoSfx,
## WorldSfx: `sfx.play`, `_sfx.play`, `get_node("Sfx").play`), the book's `_hop` and the polar
## world's `_near_sfx`. UiSound.play lines are not here: the menu kit owns its own sounds.
const CALL_PATTERNS := ["Audio.play(", "Audio.loop_player(", "sfx.play(", "\"Sfx\").play(",
	"_hop(\"", "_near_sfx(cell, \""]
## Cue fields in data/ resources (CreatureData.bark / windup_cue, SecretData.cue, TraitData.cue).
const DATA_FIELDS := ["bark", "windup_cue", "cue"]

## The GAME.md Audio table: these must exist even before anything calls them.
const TABLE := ["chomp_1", "chomp_2", "chomp_3", "chomp_4", "chomp_5", "tunnel", "burst", "wiggle",
	"stage_up", "threat_near", "eaten", "now_i_eat_you", "breakthrough", "planet_gone", "space_drift"]
## Ring ambience beds (GAME.md "Added 2026-11-10"), one per ring id in data/rings/rings.tres.
const BEDS := ["amb_dirt", "amb_topsoil", "amb_deep_rock", "amb_core", "amb_surface"]
const LOOPS := ["tunnel", "space_drift", "amb_dirt", "amb_topsoil", "amb_deep_rock", "amb_core", "amb_surface"]


static func _has_file(cue: String) -> bool:
	return ResourceLoader.exists(SFX_DIR + cue + ".ogg") or ResourceLoader.exists(SFX_DIR + cue + "_1.ogg")


static func _gd_files(dir: String, ext: String, out: Array[String]) -> Array[String]:
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.get_extension() == ext:
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if not sub.begins_with("."):
			_gd_files(dir.path_join(sub), ext, out)
	return out


## cue name -> "file:line" of one place that plays it.
static func used_cues() -> Dictionary:
	var cues := {}
	var lit := RegEx.create_from_string("\"([a-z][a-z0-9_]*(?:%d)?)\"")
	var files: Array[String] = []
	_gd_files("res://scripts", "gd", files)
	_gd_files("res://scenes", "gd", files)
	for path in files:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var line: String = lines[i]
			if line.strip_edges().begins_with("#"):
				continue
			var hit := false
			for pat in CALL_PATTERNS:
				if line.contains(pat):
					hit = true
					break
			if not hit or line.contains("UiSound.play("):
				continue
			for m in lit.search_all(line):
				var c: String = m.get_string(1)
				if c.ends_with("%d"):
					for k in range(1, CHOMP_CUES + 1):
						cues[c.replace("%d", str(k))] = "%s:%d" % [path, i + 1]
				else:
					cues[c] = "%s:%d" % [path, i + 1]
	var tres: Array[String] = []
	_gd_files("res://data", "tres", tres)
	var field := RegEx.create_from_string("^(%s) = \"([a-z][a-z0-9_]*)\"" % "|".join(DATA_FIELDS))
	for path in tres:
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var m := field.search(line)
			if m:
				cues[m.get_string(2)] = path
	return cues


func after_test() -> void:
	for p in Audio._pool:   # no playback outlives the suite (it would leak at exit)
		p.stop()
		p.stream = null


func test_scan_finds_the_known_call_sites() -> void:
	var cues := used_cues()
	for c in ["chomp_1", "chomp_5", "tunnel", "stage_up", "eaten", "boop", "box_open", "book_flip",
			"planet_gone", "world_munch", "jar_clink", "trait_glow", "bird_offended", "secret_found",
			"world_regrow", "book_tick"]:
		assert_bool(cues.has(c)).override_failure_message("scan missed '%s'" % c).is_true()
	assert_int(cues.size()).is_greater(80)


func test_every_used_cue_has_a_designed_file() -> void:
	var missing: Array[String] = []
	for c in used_cues():
		if not _has_file(c) and not UiSound.CUES.has(c):
			missing.append("%s (%s)" % [c, used_cues()[c]])
	assert_array(missing).override_failure_message("cues with no file: %s" % ", ".join(missing)).is_empty()


func test_game_md_table_and_ring_beds_have_files() -> void:
	for c in TABLE + BEDS:
		assert_bool(_has_file(c)).override_failure_message("no file for '%s'" % c).is_true()


func test_playing_every_cue_never_beeps() -> void:
	var cues := used_cues().keys() + TABLE + BEDS
	var before := 0
	for v in GreyBeep.beeped.values():
		before += int(v)
	for c in cues:
		Audio.play(c)
	var after := 0
	for v in GreyBeep.beeped.values():
		after += int(v)
	assert_int(after - before).override_failure_message(
		"placeholder beeps: %s" % str(GreyBeep.beeped)).is_equal(0)


func test_the_tunnel_and_beds_loop_from_files() -> void:
	for c in LOOPS:
		var p := Audio.loop_player(c)
		assert_object(p.stream).override_failure_message("'%s' is not an Ogg file" % c) \
			.is_instanceof(AudioStreamOggVorbis)
		assert_bool((p.stream as AudioStreamOggVorbis).loop).is_true()
		p.free()


func test_planet_gone_burp_fits_the_animation() -> void:
	# planet_chomp.gd fires the burp animation at BURP_AT = 2.2 s: the file must run past it.
	var s: AudioStream = load(SFX_DIR + "planet_gone.ogg")
	assert_float(s.get_length()).is_between(2.4, 3.0)


func test_cues_doc_lists_every_file() -> void:
	var doc := FileAccess.get_file_as_string(CUES_DOC)
	var missing: Array[String] = []
	for f in DirAccess.get_files_at(SFX_DIR):
		if f.get_extension() == "ogg" and not doc.contains(f):
			missing.append(f)
	assert_array(missing).override_failure_message("not in CUES.md: %s" % ", ".join(missing)).is_empty()


func test_every_file_is_credited() -> void:
	var credits := FileAccess.get_file_as_string("res://assets/CREDITS.md")
	assert_bool(credits.contains("scripts/tools/make_cues.py")).is_true()
	assert_bool(credits.contains("audio/sfx/")).is_true()
