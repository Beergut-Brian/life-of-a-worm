## U-15: a worm born already wearing traits (a new round, a tin load, a respawn) says hello with
## each one: that trait's own sting (`TraitData.cue`), quiet, one after another, and its part pops
## (plus a small ring in its colour) so every sound has a cause on screen.
## Earning or equipping a trait is louder and stays in worm.gd (`_on_trait_earned`,
## `_on_traits_changed`); this node only covers traits that arrive with no traits_changed signal:
## the ones active when the worm enters the tree, and the ones a `from_dict` load puts on.
## A child of worm.tscn, like Knacks and PullDrag. No trait is named: everything is read from data.
class_name TraitHello
extends Node

## A trait said hello (tests count these; once per trait per birth, never per frame).
signal hello(trait_id: StringName, cue: String)

## Quieter than an earn sting (Audio.play is 0 dB).
const QUIET_DB := -10.0
## Seconds between two hellos, so a full build plays as a little phrase, not a chord.
const GAP := 0.22
const SFX_DIR := "res://assets/audio/sfx/"

## trait id -> hellos played (tests and the report read it).
var played: Dictionary = {}
var worm: Worm
var _model: WormGrowth
var _known: Array[StringName] = []
var _queue: Array[StringName] = []
var _wait := 0.0


func _ready() -> void:
	worm = get_parent() as Worm
	if worm != null and not worm.is_node_ready():
		worm.ready.connect(_hook, CONNECT_ONE_SHOT)   # after Worm._ready made its model and parts
	elif worm != null:
		_hook.call_deferred()


func _exit_tree() -> void:
	for c in get_children():
		if c is AudioStreamPlayer:
			(c as AudioStreamPlayer).stop()   # a sting still playing at exit leaks its playback


## Start watching the worm's model; everything it already wears is "born with" and queues a hello.
func _hook() -> void:
	if worm == null or worm.model == null:
		return
	if _model != null and _model.traits_changed.is_connected(_on_traits_changed):
		_model.traits_changed.disconnect(_on_traits_changed)
	_model = worm.model
	_model.traits_changed.connect(_on_traits_changed)
	_known = []
	_queue.clear()
	_notice(_model.active)


## An equip / swap: worm.gd already stings it, so only remember it (no hello on top).
func _on_traits_changed(active: Array[StringName]) -> void:
	_known = active.duplicate()
	for id in _queue.duplicate():
		if not id in active:
			_queue.erase(id)


func _notice(active: Array[StringName]) -> void:
	for id in active:
		if not id in _known and not id in _queue:
			_queue.append(id)
	_known = active.duplicate()


func _process(delta: float) -> void:
	if worm == null or not worm.is_node_ready() or worm.model == null:
		return
	if worm.model != _model:
		_hook()   # a fresh body: born again
	elif _model.active != _known:
		_notice(_model.active)   # changed with no signal: a load put these on
	if _queue.is_empty():
		_wait = 0.0
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = GAP
	var id: StringName = _queue.pop_front()
	if _model.is_active(id):
		say(id)


## One hello: the trait's sting, quiet, and its part pops with a small ring in its colour.
func say(id: StringName) -> void:
	var t := worm.rules.find_trait(id) if worm.rules != null else null
	if t == null or t.cue == "":
		return
	played[id] = int(played.get(id, 0)) + 1
	_play(t.cue)
	_show(t)
	hello.emit(id, t.cue)


func _play(cue: String) -> void:
	var path := SFX_DIR + cue + ".ogg"
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.volume_db = QUIET_DB
	p.stream = load(path) if ResourceLoader.exists(path) else GreyBeep.stream(cue)
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()


func _show(t: TraitData) -> void:
	var stack: Array[Node] = [worm]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Sprite2D and StringName(n.get_meta("trait", &"")) == t.id and (n as Sprite2D).visible:
			var s := n as Sprite2D
			var tw := s.create_tween()
			tw.tween_property(s, "scale", Vector2(1.5, 1.5), 0.12).set_trans(Tween.TRANS_BACK)
			tw.tween_property(s, "scale", Vector2.ONE, 0.18)
	var ring := WormRing.new()
	ring.color = t.color
	ring.life = 0.3
	ring.max_radius = 18.0 * maxf(worm.head.scale.x, 1.0)
	ring.position = worm.head.position
	ring.z_index = 9
	worm.fx.add_child(ring)
