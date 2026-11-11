## Sound for the prototype: Audio.play(cue) once the Audio lane ships assets/audio/sfx/<cue>.ogg,
## until then the placeholder res://assets/proto/chomp/<cue>.wav on the SFX bus.
class_name ProtoSfx
extends Node

const PROTO_DIR := "res://assets/proto/chomp/"

var _players := {}


func play(cue: String, pitch := 1.0) -> void:
	if _audio_has(cue):
		Audio.play(cue)
		return
	var p := _player(cue)
	if p == null:
		return
	p.pitch_scale = pitch
	p.play()


func stop(cue: String) -> void:
	if _players.has(cue):
		_players[cue].stop()


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


static func _audio_has(cue: String) -> bool:
	return ResourceLoader.exists(Audio.SFX_DIR + cue + ".ogg") or ResourceLoader.exists(Audio.SFX_DIR + cue + "_1.ogg")
