## The trait jobs that happen in the planet's rock and water, hooked from a child of the worm scene
## (no trait is named: every job is keyed on a stat, the way PullDrag is).
##  - Rock a stage early: when the ring under the mouth is only edible because of the worm's
##    `bite_bonus/<ring flavour>` (stage + bonus reaches the ring's edible_from), the world lets this
##    worm bite it for this physics step. Each such bite pops the trait's part with its sting.
##    Each rock bite also kicks a little spray of stone chips off the bitten tile with a rock clack
##    (the bite beat: the kid sees the head chew rock it couldn't before).
##  - Bump, not bonk (D-05): a stone thing too big to bite even with the bonus (a big boulder) no
##    longer bonks the worm back; the head nudges it out of the way before the worm's step, so the
##    worm keeps going. The bump is soft: a boop, the boulder wobbles, a puff of grit, and the
##    stone part pops (the cause on screen).
##  - Makes sure this worm's world has its FloodPools (D-08), GeodeSeams (D-06, D-05 combo) and
##    SecretShimmer (D-06 secrets).
## Runs one step before the worm (process_physics_priority -1) and puts the world's stage back one
## step after it, so nothing else ever sees the raised stage.
class_name TraitKnacks
extends Node

## A rock bite's chip spray (the bite beat), at most once per CHIP_GAP.
signal rock_chipped(player: int, cell: Vector2i)
## A stone thing nudged aside instead of bonking the worm back (once per SHOVE_GAP while pushing).
signal bumped(player: int, what: StringName)

const CHIP_GAP := 0.18
const CHIP_CUE := "rock_beetle_clack"
const CHIP_COLOR := Color(0.78, 0.8, 0.84)
const SHOVE_GAP := 0.45
const BUMP_CUE := "boop"

var worm: Worm
## Tiles bitten only because of a bite bonus (tests read this).
var rock_bites := 0
## Chip sprays and soft bumps so far (tests read these).
var chips := 0
var bumps := 0
var _chip_cool := 0.0
var _shove_cool := 0.0
var _raised := false
var _after: Node


func _ready() -> void:
	worm = get_parent() as Worm
	process_physics_priority = -1
	_after = _AfterStep.new()
	_after.knacks = self
	_after.process_physics_priority = 1
	add_child(_after)


func _physics_process(delta: float) -> void:
	if worm == null or worm.world == null or worm.model == null or worm.world.rings == null:
		return
	var w := worm.world
	_attach(w)
	if not w.tile_eaten.is_connected(_on_tile_eaten):
		w.tile_eaten.connect(_on_tile_eaten)
	_chip_cool = maxf(0.0, _chip_cool - delta)
	_shove_cool = maxf(0.0, _shove_cool - delta)
	_shove_step(delta)
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
		if _chip_cool <= 0.0:
			_chip_cool = CHIP_GAP
			_chip(cell)


## The bite beat: grey-white stone chips fly off the bitten tile, with a rock clack.
func _chip(cell: Vector2i) -> void:
	var w := worm.world
	var cs := float(w.shape.cell_size)
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.amount = 10
	burst.lifetime = 0.45
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 110.0
	burst.gravity = Vector2.ZERO
	burst.scale_amount_min = 2.5
	burst.scale_amount_max = 4.5
	burst.color = CHIP_COLOR
	burst.z_index = 3
	burst.position = (Vector2(cell) + Vector2(0.5, 0.5)) * cs
	w.add_child(burst)
	burst.emitting = true
	burst.finished.connect(burst.queue_free)
	Audio.play(CHIP_CUE)
	chips += 1
	rock_chipped.emit(worm.player, cell)


## Bump, not bonk: every stone thing this worm has a bite bonus for but still can't bite, if the
## mouth will reach it this step, is nudged just out of reach ahead of the worm's own step, so the
## worm never meets it and never bonks back. Creatures are left alone (they have their own rules).
func _shove_step(delta: float) -> void:
	var stats := worm.model.stats
	var mouth := worm.mouth_position()
	var reach := stats.value("mouth_radius", 8.0)
	# How far the mouth can travel this step (a burst, skating), plus a little room.
	var travel := stats.value("speed") * maxf(1.0, stats.value("burst_speed", 1.0)) * 2.0 * delta + 3.0
	for f in worm.get_tree().get_nodes_in_group("food"):
		if f is Creature or not f.call("is_available"):
			continue
		var data: FoodData = f.data
		if data == null or worm.can_eat(data) \
				or stats.value("bite_bonus/" + String(data.flavour)) <= 0.0:
			continue
		var rel: Vector2 = f.global_position - mouth
		var keep := reach + data.radius + travel
		if rel.length() >= keep:
			continue
		var dir := rel.normalized() if rel.length() > 0.5 else Vector2.from_angle(worm.heading)
		f.global_position = mouth + dir * (keep + 1.0)
		if _shove_cool <= 0.0:
			_shove_cool = SHOVE_GAP
			_bump(f, data, mouth + dir * reach)


## The soft bump: a boop, the boulder wobbles, a puff of grit where they touch, the part pops.
func _bump(f: Node2D, data: FoodData, at: Vector2) -> void:
	Audio.play(BUMP_CUE)
	worm._trait_moment("bite_bonus/" + String(data.flavour))
	var tw := f.create_tween()
	tw.tween_property(f, "scale", Vector2(1.18, 0.85), 0.08)
	tw.tween_property(f, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	var puff := CPUParticles2D.new()
	puff.one_shot = true
	puff.amount = 8
	puff.lifetime = 0.4
	puff.explosiveness = 1.0
	puff.spread = 70.0
	puff.direction = Vector2.from_angle(worm.heading + PI)
	puff.initial_velocity_min = 30.0
	puff.initial_velocity_max = 70.0
	puff.gravity = Vector2.ZERO
	puff.scale_amount_min = 2.0
	puff.scale_amount_max = 4.0
	puff.color = data.color.lightened(0.35)
	puff.z_index = 3
	puff.top_level = true
	puff.global_position = at
	worm.add_child(puff)
	puff.emitting = true
	puff.finished.connect(puff.queue_free)
	bumps += 1
	bumped.emit(worm.player, data.id)


## One FloodPools, one GeodeSeams and one SecretShimmer per planet world, whoever gets there first.
static func _attach(w: PolarWorld) -> void:
	if w.get_node_or_null("FloodPools") == null:
		var pools := FloodPools.new()
		pools.name = "FloodPools"
		w.add_child(pools)
	if w.get_node_or_null("GeodeSeams") == null:
		var seams := GeodeSeams.new()
		seams.name = "GeodeSeams"
		w.add_child(seams)
	if w.get_node_or_null("SecretShimmer") == null:
		var shimmer := SecretShimmer.new()
		shimmer.name = "SecretShimmer"
		w.add_child(shimmer)


class _AfterStep extends Node:
	var knacks: TraitKnacks

	func _physics_process(_delta: float) -> void:
		knacks._restore()
