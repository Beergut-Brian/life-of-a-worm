## Sound for the polar prototype: Audio.play(cue) once the Audio lane ships assets/audio/sfx/<cue>.ogg,
## until then the placeholder res://assets/proto/world/<cue>.wav on the SFX bus. Each cue has a
## minimum gap so a worm eating every frame makes a munch rhythm, not a buzz.
class_name WorldSfx
extends Node

const PROTO_DIR := "res://assets/proto/world/"

var min_gap := {"world_munch": 0.11, "world_regrow": 0.25, "world_sprout": 0.15}
var _players := {}
var _last := {}


func play(cue: String, pitch := 1.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(cue, -10.0)) < float(min_gap.get(cue, 0.0)):
		return
	_last[cue] = now
	if ResourceLoader.exists(Audio.SFX_DIR + cue + ".ogg"):
		Audio.play(cue)
		return
	var p := _player(cue)
	if p:
		p.pitch_scale = pitch
		p.play()


func _player(cue: String) -> AudioStreamPlayer:
	if _players.has(cue):
		return _players[cue]
	var path := PROTO_DIR + cue + ".wav"
	if not ResourceLoader.exists(path):
		return null
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.bus = &"SFX" if AudioServer.get_bus_index("SFX") != -1 else &"Master"
	add_child(p)
	_players[cue] = p
	return p


## Stop before leaving so no playback outlives the scene (it would leak at exit).
func _exit_tree() -> void:
	for p in _players.values():
		p.stop()
		p.stream = null
