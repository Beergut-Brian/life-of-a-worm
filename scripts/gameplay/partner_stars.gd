## C-18 / kid-check N3: every tile one worm digs also grows its partner by a quarter, but only food
## bites used to show that share (a star off the partner's head), so a tunnelling partner made this
## worm's segments pop for no visible reason. Now the same small star rises off this worm's head
## while another worm digs, at most one every EVERY s so a long tunnel is a steady twinkle, not a
## shower. A child of scenes/players/worm.tscn: worm.gd stays untouched.
class_name PartnerStars
extends Node

signal shown(player: int)

const EVERY := 0.6
const TINT := Color(1, 1, 1, 0.8)

var count := 0              # stars shown, for tests (per call)

var _world: PolarWorld
var _cool := 0.0
var _pending := false


func _exit_tree() -> void:
	_watch(null)


func _physics_process(delta: float) -> void:
	var w := get_parent() as Worm
	if w == null:
		return
	step(w, delta)


func step(w: Worm, delta: float) -> void:
	if w.world != _world:
		_watch(w.world)
	_cool = maxf(0.0, _cool - delta)
	if _pending and _cool <= 0.0:
		_pending = false
		_cool = EVERY
		w._float_fx(Worm.STAR_TEX, w.head.position + Vector2(0, -12), TINT, 0.5)
		count += 1
		shown.emit(w.player)


func _watch(world: PolarWorld) -> void:
	if _world != null and is_instance_valid(_world) and _world.tile_eaten.is_connected(_on_tile_eaten):
		_world.tile_eaten.disconnect(_on_tile_eaten)
	_world = world
	if _world != null:
		_world.tile_eaten.connect(_on_tile_eaten)


func _on_tile_eaten(_cell: Vector2i, _block: StringName, p: int) -> void:
	var me := get_parent() as Worm
	if me == null or p == me.player:
		return
	for o in Worm.all():
		if o != me and o.player == p:   # only a worm's dig shares growth (worm.gd bite_tile)
			_pending = true
			return
