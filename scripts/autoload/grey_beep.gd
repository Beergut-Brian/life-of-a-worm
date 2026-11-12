## Grey-box placeholder sounds: when assets/audio/sfx/ has no file for a cue, Audio.play() plays a
## short synthesized beep from here instead, so every action is heard before the Audio lane
## delivers files. Dropping <cue>.ogg (or <cue>_1.ogg ...) into assets/audio/sfx/ replaces it.
## Known cues get a shape that hints at the feel in GAME.md's Audio table; any other cue gets a
## plain beep whose pitch comes from its name (so two different cues never sound the same).
##
## 2026-11-12 (worm-audio-1): every cue the game plays now has a designed file
## (scripts/tools/make_cues.py, assets/audio/CUES.md), so this is only a safety net for a cue
## added later. Menu-kit cues (ui_move, ui_confirm, player_join, ...) go to UiSound's designed
## synth, never a beep. `beeped` counts every real beep so tests can prove none happens.
class_name GreyBeep
extends RefCounted

const RATE := 22050

static var _cache: Dictionary = {}
## cue -> times a placeholder beep was handed out (tests/test_worm_audio.gd reads it).
static var beeped: Dictionary = {}


## Recipe per cue: [[start Hz, end Hz, seconds, noise 0..1], ...] played one after another.
static func recipe(cue: String) -> Array:
	if cue.begins_with("chomp_"):
		var n := clampi(int(cue.get_slice("_", 1)), 1, 5)
		return [[260.0 - n * 30.0, 90.0 - n * 8.0, 0.05 + n * 0.03, 0.55]]
	match cue:
		"tunnel": return [[140.0, 120.0, 0.5, 0.85]]
		"burst": return [[300.0, 900.0, 0.12, 0.2]]
		"wiggle": return [[700.0, 900.0, 0.07, 0.0], [900.0, 700.0, 0.07, 0.3], [800.0, 1000.0, 0.07, 0.0]]
		"stage_up": return [[392.0, 392.0, 0.12, 0.0], [523.0, 523.0, 0.12, 0.0], [659.0, 659.0, 0.12, 0.0], [784.0, 1046.0, 0.4, 0.0]]
		"threat_near": return [[70.0, 55.0, 1.0, 0.25]]
		"eaten": return [[300.0, 80.0, 0.25, 0.1], [600.0, 600.0, 0.05, 0.0], [900.0, 1200.0, 0.2, 0.0]]
		"now_i_eat_you": return [[523.0, 523.0, 0.1, 0.0], [523.0, 523.0, 0.1, 0.0], [784.0, 784.0, 0.35, 0.0]]
		"carry": return [[500.0, 750.0, 0.08, 0.0]]
		"drop": return [[750.0, 450.0, 0.08, 0.0]]
		"sleep": return [[440.0, 330.0, 0.3, 0.0], [330.0, 262.0, 0.4, 0.0]]
		"warp": return [[200.0, 1400.0, 0.35, 0.15]]
		"warp_charge": return [[300.0, 600.0, 0.3, 0.0]]
		"segment_pop": return [[600.0, 1100.0, 0.06, 0.0]]
		"hatch", "egg_crack": return [[900.0, 400.0, 0.05, 0.7], [500.0, 900.0, 0.12, 0.0]]
		"bonk": return [[180.0, 120.0, 0.08, 0.3]]
		"boop": return [[660.0, 880.0, 0.1, 0.0]]
		"beetle_windup": return [[90.0, 260.0, 1.0, 0.15]]
		"beetle_lunge": return [[260.0, 120.0, 0.2, 0.5]]
		"home_trophy": return [[523.0, 523.0, 0.1, 0.0], [659.0, 784.0, 0.2, 0.0]]
		"home_seed": return [[392.0, 523.0, 0.15, 0.0], [659.0, 659.0, 0.15, 0.0]]
		"tackle_box": return [[330.0, 330.0, 0.08, 0.4], [440.0, 440.0, 0.1, 0.0]]
	var h := absi(cue.hash()) % 24
	var f := 220.0 * pow(2.0, h / 12.0)
	return [[f, f * 1.12, 0.12, 0.0]]


## Drops the cached streams (Audio calls it on exit, so none is reported leaked).
static func clear() -> void:
	_cache.clear()


static func stream(cue: String) -> AudioStreamWAV:
	if UiSound.CUES.has(cue):
		return UiSound.stream(cue)   # the shared menu kit's designed sound, not a beep
	beeped[cue] = int(beeped.get(cue, 0)) + 1
	if _cache.has(cue):
		return _cache[cue]
	var parts := recipe(cue)
	var total := 0
	for p in parts:
		total += int(p[2] * RATE)
	var data := PackedByteArray()
	data.resize(total * 2)
	var i := 0
	var phase := 0.0
	var seed_v := absi(cue.hash()) + 1
	for p in parts:
		var n := int(p[2] * RATE)
		for k in n:
			var t := float(k) / maxf(1.0, n - 1)
			var f: float = lerpf(p[0], p[1], t)
			phase += TAU * f / RATE
			seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
			var noise := float(seed_v) / float(0x7fffffff) * 2.0 - 1.0
			var tone := 1.0 if sin(phase) >= 0.0 else -1.0   # square: reads as "placeholder"
			var env := minf(1.0, k / 120.0) * (1.0 - t) * 0.9 + 0.1 * (1.0 - t)
			var v: float = lerpf(tone * 0.5, noise, p[3]) * env * 0.35
			data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
			i += 1
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	if cue == "tunnel":
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = total
	_cache[cue] = s
	return s
