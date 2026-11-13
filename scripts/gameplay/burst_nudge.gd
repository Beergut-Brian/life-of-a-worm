## C-06 / kid-check N1: pressing A while the burst recharges used to do nothing at all. Now it puffs
## a few dust specks behind the head, plays the burst cue small and high (its own quiet player; no new
## sound file), and shows a ring round the head that fills as the burst comes back, so the kid sees
## why nothing zoomed and when it will. A child of scenes/players/worm.tscn: worm.gd stays untouched.
class_name BurstNudge
extends Node2D

signal nudged(player: int)

const LIFE := 0.6           # how long the ring and the puff show after a press
const RADIUS := 15.0        # ring radius round the head, before the stage size
const MIN_GAP := 0.12       # mashing: one nudge per 0.12 s at most (mashing is fine and funny)
const PUFFS := 3
const RING := Color(1.0, 0.96, 0.8)
const PUFF := Color(0.78, 0.68, 0.55)
const CUE := "res://assets/audio/sfx/burst.ogg"

## Did the player press A this physics frame? Tests swap this; the default reads the pad.
var pressed_now: Callable
var count := 0              # nudges shown, for tests (per call, not per frame)

var _prev_cool := 0.0
var _total := 0.0
var _show := 0.0
var _gap := 0.0
var _ready_frac := 0.0
var _puffs: Array[Vector4] = []   # x, y, time left, size
var _voice: AudioStreamPlayer


func _ready() -> void:
	z_index = 10
	_voice = AudioStreamPlayer.new()
	_voice.name = "Voice"
	_voice.bus = &"SFX"
	_voice.volume_db = -12.0
	_voice.pitch_scale = 1.7
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
		return false   # the autopilot never mashes into a recharge
	return Input.is_action_just_pressed(Players.action(w.player, "action"))


## Runs after the worm's own physics step (a child), so `_burst_cool` is this frame's value.
func _physics_process(delta: float) -> void:
	var w := get_parent() as Worm
	if w == null or w.model == null:
		return
	step(w, delta)


func step(w: Worm, delta: float) -> void:
	_gap = maxf(0.0, _gap - delta)
	var cool: float = w._burst_cool
	var started := cool > _prev_cool + 0.001
	if started:
		_total = cool
	elif cool > 0.0 and not w.wall_open and _pressed(w) and _gap <= 0.0:
		_nudge(w, cool)
	_prev_cool = cool
	if _total > 0.0:
		_ready_frac = clampf(1.0 - cool / _total, 0.0, 1.0)


func _nudge(w: Worm, cool: float) -> void:
	_gap = MIN_GAP
	_show = LIFE
	if _total <= 0.0:
		_total = cool
	_ready_frac = clampf(1.0 - cool / _total, 0.0, 1.0)
	var back := Vector2.from_angle(w.heading + PI)
	for i in PUFFS:
		var side := Vector2.from_angle(w.heading + PI / 2.0) * randf_range(-4.0, 4.0)
		var at := back * randf_range(8.0, 12.0) + side
		_puffs.append(Vector4(at.x, at.y, LIFE, randf_range(1.5, 2.5)))
	if _voice.stream:
		_voice.play()
	count += 1
	nudged.emit(w.player)


func showing() -> bool:
	return _show > 0.0


func ready_fraction() -> float:
	return _ready_frac


func _process(delta: float) -> void:
	var w := get_parent() as Worm
	if w != null and w.head != null:
		position = w.head.position
	if _show <= 0.0 and _puffs.is_empty():
		return
	_show = maxf(0.0, _show - delta)
	for i in _puffs.size():
		_puffs[i].z -= delta
		_puffs[i].x *= 1.0 + delta
		_puffs[i].y *= 1.0 + delta
	_puffs = _puffs.filter(func(v: Vector4) -> bool: return v.z > 0.0)
	queue_redraw()


func _draw() -> void:
	var w := get_parent() as Worm
	var size: float = w._size if w != null else 1.0
	if _show > 0.0:
		var k := _show / LIFE
		var r := RADIUS * size
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(RING, 0.25 * k), 2.0 * size)
		if _ready_frac > 0.0:
			draw_arc(Vector2.ZERO, r, -PI / 2.0, -PI / 2.0 + TAU * _ready_frac, 32, Color(RING, 0.9 * k), 2.5 * size)
	for p in _puffs:
		var k := p.z / LIFE
		draw_circle(Vector2(p.x, p.y) * size, p.w * size * (1.6 - 0.6 * k), Color(PUFF, 0.8 * k))
