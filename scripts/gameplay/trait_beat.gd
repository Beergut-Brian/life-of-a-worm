## The trait beat (Y-16 / P-14): a worm earning a trait shows the cause with a camera beat, no words.
##   t = 0     (the worm already plays the trait's cue and its colour ring, scripts/worm/worm.gd)
##             a small shake and a burst in the trait's colour at the head;
##   t = 0     the shared camera leans in one whole-pixel step (PolarCamera.lean_in) for LEAN secs,
##             so the worm's new part fills more of the screen; the fit still never cuts a worm off;
##   t = 0     the TraitWhy picture pops over the worm: the flavour beads that earned it -> the part.
## Two moments never share the bubble spot: a trait earned during a stage-up beat (or right after
## another trait) waits its turn, GAP secs apart.
## StageBeat owns one and hooks every worm in the tree, so the level needs no new code.
class_name TraitBeat
extends Node

signal beat(player: int, trait_id: StringName)

const LEAN := 1.4
const GAP := 1.8
const SHAKE := 0.35

var camera: PolarCamera
## Every beat played: {player, trait, recipe}.
var history: Array[Dictionary] = []

var _busy_until := 0.0
var _clock := 0.0
var _queue: Array = []   # [worm, trait id]
var _leaning := 0


func _init() -> void:
	name = "TraitBeat"


func watch(w: Worm) -> void:
	if not w.trait_earned.is_connected(_on_trait_earned):
		w.trait_earned.connect(_on_trait_earned)


## A stage-up beat is on screen: hold trait beats until it is done.
func hold(secs: float) -> void:
	_busy_until = maxf(_busy_until, _clock + secs)


func _on_trait_earned(player: int, id: StringName) -> void:
	var w := Worm.of(player)
	if w == null:
		return
	if _clock < _busy_until or not _queue.is_empty():
		_queue.append([w, id])
		return
	play(w, id)


func play(w: Worm, id: StringName) -> void:
	var t := w.rules.find_trait(id) if w.rules != null else null
	if t == null:
		return
	_busy_until = _clock + GAP
	var juice := WormHooks.juice()
	var at := w.head_position()
	juice.shake(SHAKE)
	juice.chomp(at, t.color, 2.0)
	if camera != null and is_inside_tree():
		camera.lean_in += 1
		_leaning += 1
		var timer := get_tree().create_timer(LEAN, false)
		timer.timeout.connect(_unlean)
	var why := TraitWhy.new()
	why.worm = w
	why.trait_data = t
	why.rules = w.rules
	why.life = GAP
	var host := get_parent() if get_parent() != null else self
	host.add_child(why)
	history.append({"player": w.player, "trait": id, "recipe": why.recipe()})
	beat.emit(w.player, id)


func _unlean() -> void:
	if _leaning <= 0:
		return
	_leaning -= 1
	if is_instance_valid(camera):
		camera.lean_in = maxi(0, camera.lean_in - 1)


func _process(delta: float) -> void:
	_clock += delta
	while not _queue.is_empty() and _clock >= _busy_until:
		var q: Array = _queue.pop_front()
		if is_instance_valid(q[0]):
			play(q[0], q[1])


func _exit_tree() -> void:
	while _leaning > 0:
		_unlean()
