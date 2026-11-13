## Kid-check N9 (C-21 / P-10 drop-out): a worm whose pad unplugs (Players.player_left) used to be
## freed with no sound or picture. Now it leaves the way it arrives, in reverse: a ring in the
## player's colour (green P1, red P2) opens where its head was, specks fly out and settle, and the
## `warp` cue plays (the same wormhole sound as held-B). The puff (DropOutPuff.Puff) is a sibling of
## the worm in the level, so it outlives the worm. A child of scenes/players/worm.tscn: worm.gd and
## planet_level.gd stay untouched. The worm comes back with its own body on the next join.
class_name DropOutPuff
extends Node

signal left(player: int)

## Seconds the puff shows.
const SECS := 0.9
const RING := 34.0

var count := 0   # puffs shown, for tests (per call)

var _host: Node2D
var _at := Vector2.ZERO


func _ready() -> void:
	Players.player_left.connect(_on_left)


func _exit_tree() -> void:
	_remember()


func _physics_process(_delta: float) -> void:
	_remember()


## Where the head is and who holds the worm, kept so the puff still has a place if the level has
## already taken the worm out by the time the signal reaches this node.
func _remember() -> void:
	var w := get_parent() as Worm
	if w == null or not w.is_inside_tree():
		return
	var host := w.get_parent() as Node2D
	if host == null:
		return
	_host = host
	_at = host.to_local(w.head_position())


func _on_left(player: int) -> void:
	var w := get_parent() as Worm
	if w == null or w.player != player:
		return
	_remember()
	if _host == null or not is_instance_valid(_host) or not _host.is_inside_tree():
		return
	var p := Puff.new()
	p.position = _at
	p.tint = Players.COLOR.get(player, Color.WHITE)
	_host.add_child(p)
	Audio.play("warp")
	count += 1
	left.emit(player)


## The ring and specks. Frees itself after SECS.
class Puff extends Node2D:
	var tint := Color.WHITE
	var t := 0.0

	func _ready() -> void:
		add_to_group(&"drop_out_puff")
		z_index = 5

	func _process(delta: float) -> void:
		step(delta)

	func step(delta: float) -> void:
		t += delta
		queue_redraw()
		if t >= SECS:
			queue_free()

	func _draw() -> void:
		var k := clampf(t / SECS, 0.0, 1.0)
		var a := 1.0 - k
		draw_arc(Vector2.ZERO, RING * (0.3 + 0.7 * k), 0.0, TAU, 32, Color(tint, a), 4.0 * a + 1.0)
		draw_circle(Vector2.ZERO, RING * 0.35 * (1.0 - k), Color(0.05, 0.03, 0.08, 0.8 * a))   # the hole it went into
		for i in 8:
			var d := Vector2.RIGHT.rotated(i * TAU / 8.0 + 0.3) * RING * (0.4 + 0.9 * k)
			draw_circle(d, 3.0 * a + 0.5, Color(tint.lightened(0.3), a))
