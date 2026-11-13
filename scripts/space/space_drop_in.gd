## Drop-in in space (C-02 / CLAUDE.md "drop-in P2", S-11): a child of the SpaceStage scene. The stage
## builds its worms once, from the players in the game at the chomp, and the boot scene hands a
## joiner to the planet level (PlanetLevel.drop_in), which is hidden and switched off in space: its
## egg sat on the dead planet and the worm never came. Here a pad that joins in space hatches its
## worm from an egg beside the first worm instead, the same as on the planet: the egg wobbles and
## cracks (`egg_crack`), the worm pops out in its slot colour (`hatch`) and steers at once. The
## planet's own egg for that player is cleared. A pad that leaves takes its space worm with it.
## Nothing moves another worm.
class_name SpaceDropIn
extends Node

signal hatched(player: int)

## px beside the first worm (its body is SpaceStage.BODY_SHAPE across).
const BESIDE := 130.0
## The planet egg drawn at space scale.
const EGG_SCALE := 4.0
const POP := 0.35

var stage: SpaceStage
## True while a joiner's egg is wobbling: player -> WormEgg.
var eggs := {}


func _ready() -> void:
	name = "SpaceDropIn"
	stage = get_parent() as SpaceStage
	if stage == null:
		return
	Players.player_joined.connect(_on_joined)
	Players.player_left.connect(_on_left)


func _exit_tree() -> void:
	if Players.player_joined.is_connected(_on_joined):
		Players.player_joined.disconnect(_on_joined)
	if Players.player_left.is_connected(_on_left):
		Players.player_left.disconnect(_on_left)


func _on_joined(player: int, _device: int) -> void:
	join.call_deferred(player)   # after the boot scene's own handler made the planet's egg


func worm_of(player: int) -> SpaceWorm:
	for w in stage.worms:
		if is_instance_valid(w) and w.player == player:
			return w
	return null


## Hatch `player`'s worm in space from an egg beside the first worm. Null if it is already here.
func join(player: int) -> WormEgg:
	if stage == null or not is_instance_valid(stage) or worm_of(player) != null or eggs.has(player):
		return null
	_clear_planet_eggs(player)
	var at := Vector2.ZERO
	if not stage.worms.is_empty():
		var first: SpaceWorm = stage.worms[0]
		var side := first.velocity.normalized().orthogonal() if first.velocity.length() > 1.0 else Vector2.DOWN
		at = first.position + side * BESIDE
	var egg := WormEgg.new()
	egg.player = player
	egg.position = at
	egg.scale = Vector2.ONE * EGG_SCALE
	egg.z_index = 3
	eggs[player] = egg
	egg.hatched.connect(_hatch.bind(player, at))
	stage.add_child(egg)
	return egg


func _hatch(player: int, at: Vector2) -> void:
	eggs.erase(player)
	if worm_of(player) != null or not Players.is_active(player):
		return
	var w := stage._add_worm(player, at)
	stage.worms.append(w)
	if not stage.players.has(player):
		stage.players.append(player)
	if stage.drift != null and stage.drift.sun_gone:
		w.sun_glow = 1.0
	Audio.play("hatch")
	w.scale = Vector2.ONE * 0.3
	var tw := w.create_tween()
	tw.tween_property(w, "scale", Vector2.ONE, POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hatched.emit(player)


## The hidden planet's egg (PlanetLevel.drop_in) can never hatch a worm anyone sees.
func _clear_planet_eggs(player: int) -> void:
	var level := stage.get_parent()
	if level == null:
		return
	for c in level.get_children():
		if c is WormEgg and (c as WormEgg).player == player:
			c.queue_free()


func _on_left(player: int) -> void:
	if eggs.has(player):
		var e: WormEgg = eggs[player]
		eggs.erase(player)
		if is_instance_valid(e):
			e.queue_free()
	var w := worm_of(player)
	if w == null or stage.worms.size() <= 1:
		return   # the last worm stays: the stage always has someone to follow
	stage.worms.erase(w)
	stage.players.erase(player)
	w.queue_free()
