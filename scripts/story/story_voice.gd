## Voice fallbacks for story lines, the way The Hill does them. The cutscene player plays
## `res://assets/story/voice/<line_id>.ogg` when Gary has made it; otherwise it asks the host for
## the line's fallback bark (`bark:<cue>`), which lands here:
##   1. the speaker's library bark, `<characters dir>/<character>/voice/<cue>.ogg` (or `<cue>_1.ogg`),
##   2. else a short synth placeholder babble in the speaker's own pitch (low and slow for Old Reel,
##      high and quick for Bobber), so every line still makes a sound.
class_name StoryVoice
extends RefCounted

const VOICE_DIR := "res://assets/story/voice/"
const LIBRARY_DIRS: Array[String] = ["res://assets/characters/", "res://addons/openjar/characters/"]
const RATE := 22050
## character -> [base Hz, syllable secs, wobble]
const PITCH := {
	"old_reel": [118.0, 0.17, 0.10],
	"bobber": [330.0, 0.09, 0.18],
}
const CUES := ["join", "ready", "win", "lose", "oops", "cheer", "wait", "swap_in"]

static var _cache := {}


## The library bark for (character, cue), else a placeholder babble. Never null.
static func bark_stream(character: String, cue: String) -> AudioStream:
	var lib := library_bark(character, cue)
	return lib if lib != null else placeholder(character, cue)


static func library_bark(character: String, cue: String) -> AudioStream:
	for d in LIBRARY_DIRS:
		for f in ["%s%s/voice/%s.ogg" % [d, character, cue], "%s%s/voice/%s_1.ogg" % [d, character, cue]]:
			if ResourceLoader.exists(f):
				return load(f)
	return null


## A short babble: a few syllables of a warbling tone in the speaker's pitch; each cue its own
## contour (cheer rises, lose falls, wait wanders). Cached per (character, cue).
static func placeholder(character: String, cue: String) -> AudioStreamWAV:
	var key := character + ":" + cue
	if _cache.has(key):
		return _cache[key]
	var p: Array = PITCH.get(character, [220.0, 0.12, 0.12])
	var base: float = p[0]
	var syl: float = p[1]
	var wob: float = p[2]
	var n_syl := 3 + absi(hash(cue)) % 3
	var contour := 0.0
	match cue:
		"cheer", "win", "join":
			contour = 0.35
		"lose", "oops":
			contour = -0.3
	var data := PackedByteArray()
	var total := int(RATE * syl * n_syl)
	data.resize(total * 2)
	var phase := 0.0
	for i in total:
		var t := float(i) / RATE
		var k := t / (syl * n_syl)
		var s_i := int(t / syl)
		var in_syl := fmod(t, syl) / syl
		var f := base * (1.0 + contour * k + wob * sin(TAU * 5.0 * t) + 0.06 * ((s_i * 7) % 3 - 1))
		phase += TAU * f / RATE
		var env := sin(PI * in_syl) * (1.0 - 0.3 * k)
		var v := (sin(phase) * 0.6 + sin(phase * 2.0) * 0.25 + sin(phase * 3.0) * 0.1) * env * 0.5
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	_cache[key] = w
	return w


## A one-shot synth blip for a cue no sound file covers yet (skip, plop, rumble...).
static func blip(cue: String) -> AudioStreamWAV:
	var key := "blip:" + cue
	if _cache.has(key):
		return _cache[key]
	var f0 := 520.0
	var f1 := 780.0
	var secs := 0.12
	match cue:
		"story_plop":
			f0 = 700.0; f1 = 160.0; secs = 0.22
		"story_rumble", "story_chomp":
			f0 = 70.0; f1 = 50.0; secs = 0.5
		"story_skip":
			f0 = 600.0; f1 = 900.0; secs = 0.1
		"story_twinkle", "story_wink":
			f0 = 1400.0; f1 = 1900.0; secs = 0.18
		"story_whoosh":
			f0 = 300.0; f1 = 900.0; secs = 0.35
	var total := int(RATE * secs)
	var data := PackedByteArray()
	data.resize(total * 2)
	var phase := 0.0
	for i in total:
		var k := float(i) / total
		phase += TAU * lerpf(f0, f1, k) / RATE
		var env := minf(1.0, k * 20.0) * (1.0 - k)
		data.encode_s16(i * 2, int(sin(phase) * env * 0.4 * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	_cache[key] = w
	return w


## Drop cached streams (Story calls it on exit, so nothing leaks at quit).
static func clear_cache() -> void:
	_cache.clear()


## Every voice file Gary should make: line id -> expected path.
static func expected_files(lines_path := "res://data/story/lines.json") -> Dictionary:
	var out := {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(lines_path))
	if d is Dictionary:
		for l in d.get("lines", []):
			out[String(l.id)] = VOICE_DIR + String(l.id) + ".ogg"
	return out
