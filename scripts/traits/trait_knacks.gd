## The trait jobs that happen in the planet's rock and water, hooked from a child of the worm scene
## (no trait is named: every job is keyed on a stat, the way PullDrag is).
##  - Rock a stage early: when the ring under the mouth is only edible because of the worm's
##    `bite_bonus/<ring flavour>` (stage + bonus reaches the ring's edible_from), the world lets this
##    worm bite it for this physics step. Each such bite pops the trait's part with its sting.
##  - Makes sure this worm's world has its FloodPools (D-08) and GeodeSeams (D-06, D-05 combo).
## Runs one step before the worm (process_physics_priority -1) and puts the world's stage back one
## step after it, so nothing else ever sees the raised stage.
class_name TraitKnacks
extends Node

var worm: Worm
## Tiles bitten only because of a bite bonus (tests read this).
var rock_bites := 0
var _raised := false
var _after: Node


func _ready() -> void:
	worm = get_parent() as Worm
	process_physics_priority = -1
	_after = _AfterStep.new()
	_after.knacks = self
	_after.process_physics_priority = 1
	add_child(_after)


func _physics_process(_delta: float) -> void:
	if worm == null or worm.world == null or worm.model == null or worm.world.rings == null:
		return
	var w := worm.world
	_attach(w)
	if not w.tile_eaten.is_connected(_on_tile_eaten):
		w.tile_eaten.connect(_on_tile_eaten)
	var need := early_ring_stage()
	if need > 0:
		w.set_stage(worm.player, need)
		_raised = true


## The stage the world must think this worm is for the ring under its mouth to be edible through a
## bite bonus, or 0 when the worm's own stage already decides it (or the bonus is not enough).
func early_ring_stage() -> int:
	var w := worm.world
	var cs := float(w.shape.cell_size)
	var p := w.to_local(worm.mouth_position()) / cs
	var cell := Vector2i(floori(p.x), floori(p.y))
	if not w.shape.contains(cell):
		return 0
	var ring := w.ring_of(cell)
	var stage := worm.model.stage
	if ring.edible_from <= stage:
		return 0
	var bonus := int(worm.model.stats.value("bite_bonus/" + String(ring.flavour)))
	if bonus <= 0 or stage + bonus < ring.edible_from:
		return 0
	return ring.edible_from


func _restore() -> void:
	if _raised and worm.world:
		worm.world.set_stage(worm.player, worm.model.stage)
	_raised = false


func _on_tile_eaten(cell: Vector2i, _block: StringName, p: int) -> void:
	if not _raised or p != worm.player:
		return
	var ring := worm.world.ring_of(cell)
	if ring.edible_from > worm.model.stage:
		rock_bites += 1
		worm._trait_moment("bite_bonus/" + String(ring.flavour))


## One FloodPools and one GeodeSeams per planet world, whoever gets there first.
static func _attach(w: PolarWorld) -> void:
	if w.get_node_or_null("FloodPools") == null:
		var pools := FloodPools.new()
		pools.name = "FloodPools"
		w.add_child(pools)
	if w.get_node_or_null("GeodeSeams") == null:
		var seams := GeodeSeams.new()
		seams.name = "GeodeSeams"
		w.add_child(seams)


class _AfterStep extends Node:
	var knacks: TraitKnacks

	func _physics_process(_delta: float) -> void:
		knacks._restore()
