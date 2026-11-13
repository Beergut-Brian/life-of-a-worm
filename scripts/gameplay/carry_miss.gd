## Feel rule "every action beeps": X with nothing in reach used to do nothing at all (worm.gd only
## sounds X when it picks something up). Now an X press that grabs nothing snaps the mouth on air: a
## small low "carry" cue (its own quiet player, no new sound file) and two little jaws that clap shut
## at the mouth, so the kid hears and sees that X is a bite-and-hold with nothing to hold.
## A child of scenes/players/worm.tscn, after the worm's own physics step: worm.gd stays untouched.
class_name CarryMiss
extends Node2D

signal missed(player: int)

const LIFE := 0.3
const MIN_GAP := 0.15        # mashing X: one snap per 0.15 s at most
const CUE := "res://assets/audio/sfx/carry.ogg"
const JAW := Color(1.0, 0.96, 0.8)

## Did the player press X this physics frame? Tests swap this; the default reads the pad.
var pressed_now: Callable
var count := 0

var _show := 0.0
var _gap := 0.0
var _prev_bonk := 0.0
var _voice: AudioStreamPlayer


func _ready() -> void:
	z_index = 10
	top_level = true
	_voice = AudioStreamPlayer.new()
	_voice.name = "Voice"
	_voice.bus = &"SFX"
	_voice.volume_db = -10.0
	_voice.pitch_scale = 0.7
	if ResourceLoader.exists(CUE):
		_voice.stream = load(CUE)
	add_child(_voice)


func _exit_tree() -> void:
	if _voice:
		_voice.stop()


func _pressed(w: Worm) -> bool:
	if pressed_now.is_valid():
		return bool(pressed_now.call())
	if w.autopilot.is_valid():
		return false
	return Input.is_action_just_pressed(Players.action(w.player, "carry"))


func _physics_process(delta: float) -> void:
	var w := get_parent() as Worm
	if w == null or w.model == null:
		return
	step(w, delta)


func step(w: Worm, delta: float) -> void:
	_gap = maxf(0.0, _gap - delta)
	var bonked: bool = w._bonk_cool > _prev_bonk + 0.001   # the worm bonked this frame: it beeped
	_prev_bonk = w._bonk_cool
	if _show > 0.0:
		_show = maxf(0.0, _show - delta)
		global_position = w.mouth_position()
		queue_redraw()
	if not _pressed(w) or w.wall_open or _gap > 0.0:
		return
	if w.carrying != null or not w.cart.is_empty() or bonked:
		return                    # it grabbed something (the worm's own carry cue) or bonked
	_gap = MIN_GAP
	_show = LIFE
	count += 1
	global_position = w.mouth_position()
	rotation = w.heading
	if _voice.stream != null:
		_voice.play()
	missed.emit(w.player)
	queue_redraw()


func _draw() -> void:
	if _show <= 0.0:
		return
	var k := _show / LIFE                  # 1 -> 0
	var open := 0.9 * k                    # the jaws start open and clap shut
	var r := 10.0 + 4.0 * (1.0 - k)
	var a := Color(JAW, k)
	draw_line(Vector2.ZERO, Vector2.from_angle(-open) * r, a, 3.0)   # upper jaw
	draw_line(Vector2.ZERO, Vector2.from_angle(open) * r, a, 3.0)    # lower jaw
	draw_circle(Vector2.ZERO, 2.0, a)
