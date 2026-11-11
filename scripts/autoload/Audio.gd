## Sound on every action. Autoload: Audio.
## play("cue") looks for assets/audio/sfx/cue.ogg, or cue_1.ogg..cue_N.ogg and picks one.
## Missing cues warn once and never crash.
extends Node

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICE_DIR := "res://addons/openjar/characters/"
const POOL_SIZE := 12

var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _warned := {}
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	set_volume("Music", Save.get_setting("music_volume", 0.8))
	set_volume("SFX", Save.get_setting("sound_volume", 1.0))


## bus: "Music" or "SFX"; linear 0..1 (the Settings sliders). 0 mutes.
func set_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear <= 0.0)


func get_volume(bus: String) -> float:
	var i := AudioServer.get_bus_index(bus)
	if i == -1 or AudioServer.is_bus_mute(i):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(i))


func _exit_tree() -> void:
	for p in _pool:
		p.stream = null
	GreyBeep.clear()


## Every cue name that was played this session (tests and the report read it).
var played: Dictionary = {}


func play(cue: String, _position = null) -> void:
	played[cue] = int(played.get(cue, 0)) + 1
	var stream := _resolve(SFX_DIR, cue, true)
	if stream == null:
		stream = GreyBeep.stream(cue)   # grey-box: no file yet, a placeholder beep
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = randf_range(0.95, 1.05)
			p.play()
			return
	_pool[0].stream = stream
	_pool[0].play()


func music(track: String, fade: float = 0.5) -> void:
	var stream := _resolve(MUSIC_DIR, track)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	var tw := create_tween()
	if _music.playing:
		tw.tween_property(_music, "volume_db", -40.0, fade)
	tw.tween_callback(func():
		_music.stream = stream
		_music.volume_db = -40.0
		_music.play())
	tw.tween_property(_music, "volume_db", 0.0, fade)


func stop_music(fade: float = 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -40.0, fade)
	tw.tween_callback(_music.stop)


func bark(character: String, bark_name: String) -> void:
	var stream := _resolve("%s%s/voice/" % [VOICE_DIR, character], bark_name)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = 1.0
			p.play()
			return


## A looping player for a continuous cue (the tunnel scrunch): the file if there is one, else the
## placeholder loop. The caller owns the node (add it to its scene, set volume and pitch).
func loop_player(cue: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	var stream := _resolve(SFX_DIR, cue, true)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	p.stream = stream if stream != null else GreyBeep.stream(cue)
	return p


func _resolve(dir: String, cue: String, quiet := false) -> AudioStream:
	var key := dir + cue
	if _cache.has(key):
		var variants: Array = _cache[key]
		return variants.pick_random() if not variants.is_empty() else null
	var variants: Array = []
	if ResourceLoader.exists(dir + cue + ".ogg"):
		variants.append(load(dir + cue + ".ogg"))
	else:
		var i := 1
		while ResourceLoader.exists("%s%s_%d.ogg" % [dir, cue, i]):
			variants.append(load("%s%s_%d.ogg" % [dir, cue, i]))
			i += 1
	_cache[key] = variants
	if variants.is_empty():
		if not _warned.has(key) and not quiet:
			_warned[key] = true
			push_warning("Audio: no file for cue '%s' in %s" % [cue, dir])
		return null
	return variants.pick_random()
