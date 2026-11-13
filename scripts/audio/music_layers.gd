## Worm's music (U-12): one theme in seven layers, one more layer per stage (GAME.md "Audio": a
## ukulele plink in the dirt -> a brass band on the surface -> a cosmic pad in space).
##
## Every layer file is the same length and tempo; all of them start together and loop, so they stay
## in step, and a layer is only ever faded in or out, never restarted. Stage N plays layers 1..N.
## A stage-up fades the new layer in over FADE_IN while the stage beat plays (the beat is its cause
## on screen). While a dock cutscene plays, the whole theme ducks under Old Reel's voice.
##
## Files: res://assets/audio/music/theme_1.ogg .. theme_7.ogg (the Audio lane, U-17). A missing
## layer is simply skipped, and with no files at all this node is silent and costs nothing.
## The planet level owns one and sets `stage` to the tin's biggest stage (7 in space).
class_name MusicLayers
extends Node

const DIR := "res://assets/audio/music/"
const LAYERS := 7
const FADE_IN := 2.5
const FADE_OUT := 1.0
## A layer that is not playing yet sits here (still running, so it stays in step).
const QUIET_DB := -60.0
## The whole theme under a dock cutscene.
const DUCK_DB := -12.0

## Layer streams, index 0 = layer 1; null where there is no file. Set before _ready to inject
## (tests); otherwise loaded from DIR.
var streams: Array = []
## One player per layer that has a stream (index = layer - 1; null where there is none).
var players: Array = []
## The stage the music is playing (0 before the level sets it).
var stage := 0
## Ducked under a cutscene.
var ducked := false
## Duck while the tree's Story plays a scene (tests turn it off to duck by hand).
var follow_story := true

var _tweens := {}


func _init() -> void:
	name = "MusicLayers"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	if streams.is_empty():
		for i in LAYERS:
			var path := "%stheme_%d.ogg" % [DIR, i + 1]
			streams.append(load(path) if ResourceLoader.exists(path) else null)
	players.clear()
	for i in LAYERS:
		var s: AudioStream = streams[i] if i < streams.size() else null
		if s == null:
			players.append(null)
			continue
		if s is AudioStreamOggVorbis:
			s.loop = true
		var p := AudioStreamPlayer.new()
		p.name = "Layer%d" % (i + 1)
		p.bus = "Music"
		p.stream = s
		p.volume_db = QUIET_DB
		add_child(p)
		players.append(p)
	for p in players:   # all at once, so every layer is on the same beat
		if p != null:
			p.play()
	if stage > 0:
		_apply(0.0)


func has_music() -> bool:
	return players.any(func(p): return p != null)


## Play layers 1..n (fades the change in; a first call snaps).
func set_stage(n: int) -> void:
	n = clampi(n, 0, LAYERS)
	if n == stage:
		return
	var first := stage == 0
	stage = n
	if is_inside_tree():
		_apply(0.0 if first else -1.0)


## Is layer `i` (1-based) meant to be heard now?
func layer_on(i: int) -> bool:
	return i >= 1 and i <= stage


## Where layer `i` (1-based) is heading, in dB (QUIET_DB when off).
func target_db(i: int) -> float:
	return (DUCK_DB if ducked else 0.0) if layer_on(i) else QUIET_DB


func set_ducked(on: bool) -> void:
	if on == ducked:
		return
	ducked = on
	_apply(0.4)


func _process(_delta: float) -> void:
	if not has_music() or not follow_story:
		return
	var story := Story.find(get_tree())
	set_ducked(story != null and story.is_playing())


## Move every layer to its target: secs < 0 picks FADE_IN / FADE_OUT per layer, 0 snaps.
func _apply(secs: float) -> void:
	for i in players.size():
		var p: AudioStreamPlayer = players[i]
		if p == null:
			continue
		var to := target_db(i + 1)
		if _tweens.has(i) and _tweens[i].is_valid():
			_tweens[i].kill()
		var t := secs if secs >= 0.0 else (FADE_IN if to > p.volume_db else FADE_OUT)
		if t <= 0.0:
			p.volume_db = to
			continue
		var tw := create_tween()
		tw.tween_property(p, "volume_db", to, t)
		_tweens[i] = tw
