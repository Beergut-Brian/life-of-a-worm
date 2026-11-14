## U-15: a trait is heard when it does its job, not only when it is earned. The worm already
## stings a trait at work for bites, carries, pulls, light and water (`Worm._trait_moment`); this
## node adds the presses and places those miss, so every planet trait has a moment of its own:
##   burst  (A)            -> the trait that floats it (glide, open ground) or makes it longer,
##                            faster or sooner (burst_time / burst_speed / burst_cooldown)
##   wiggle (B)            -> the trait that widens or strengthens the wiggle's hop
##   skate                 -> the skate trait, once each time the worm starts skating open ground
##   a garden tile bitten  -> the trait that grows the garden's yield (throttled per patch)
## Each moment is `Worm._trait_moment`: the trait's own sting, its part pops, a ring in its colour.
## It only reads the worm (nothing here moves it). A child of worm.tscn, like TraitHello.
class_name TraitUse
extends Node

## Stats a burst can owe to a trait, in the order a burst asks for them.
const BURST_STATS: Array[String] = ["burst_time", "burst_speed", "burst_cooldown"]
const WIGGLE_STATS: Array[String] = ["wiggle_radius", "wiggle_hop"]
## Seconds between two garden stings (a patch is many tiles).
const GARDEN_GAP := 2.0

## event -> times a trait was heard for it (tests read this).
var heard: Dictionary = {}
var worm: Worm
var _world: PolarWorld
var _last_cool := 0.0
var _last_dance := 0.0
var _skating := false
var _last_pos := Vector2.ZERO
var _garden_wait := 0.0


func _ready() -> void:
	worm = get_parent() as Worm


func _exit_tree() -> void:
	if _world != null and is_instance_valid(_world) and _world.tile_eaten.is_connected(_on_tile_eaten):
		_world.tile_eaten.disconnect(_on_tile_eaten)


func _physics_process(delta: float) -> void:
	if worm == null or not worm.is_node_ready() or worm.model == null:
		return
	_garden_wait = maxf(0.0, _garden_wait - delta)
	if worm.world != _world:
		_watch(worm.world)
	var stats := worm.model.stats
	# a burst just fired: its cooldown jumped up (the worm sets it the frame A goes off)
	if worm._burst_cool > _last_cool + 0.001:
		if worm.in_open and stats.value("glide") > 0.0:
			use("burst", ["glide"], true)
		else:
			use("burst", BURST_STATS, true)
	_last_cool = worm._burst_cool
	# a wiggle just started: the dance timer jumped up
	if worm._dance > _last_dance + 0.001:
		use("wiggle", WIGGLE_STATS)
	_last_dance = worm._dance
	var moved := worm.head.position.distance_to(_last_pos) > 0.01
	_last_pos = worm.head.position
	var skating := worm.in_open and moved and stats.value("skate") > 0.0
	if skating and not _skating:
		skating = use("skate", ["skate"])   # held by the throttle: try again next frame
	_skating = skating


## The first trait that moves one of these stats does its moment. True if one did. `press`: a
## burst (already rate-limited by its own cooldown) is never swallowed by the last bite's moment;
## anything else keeps the worm's moment throttle, so mashing B is not a sting per press.
func use(event: String, stats: Array, press := false) -> bool:
	if not press and worm._moment_cool > 0.0:
		return false
	for s in stats:
		var t := worm._trait_for(s)
		if t == null:
			continue
		worm._moment_cool = 0.0
		worm._trait_moment(s)
		heard[event] = int(heard.get(event, 0)) + 1
		return true
	return false


func _watch(w: PolarWorld) -> void:
	if _world != null and is_instance_valid(_world) and _world.tile_eaten.is_connected(_on_tile_eaten):
		_world.tile_eaten.disconnect(_on_tile_eaten)
	_world = w
	if _world != null:
		_world.tile_eaten.connect(_on_tile_eaten)


func _on_tile_eaten(_cell: Vector2i, block: StringName, player: int) -> void:
	if worm == null or player != worm.player or not String(block).begins_with("garden_"):
		return
	garden_bite()


## A garden tile went down this worm's mouth: the yield trait is heard, once per GARDEN_GAP.
func garden_bite() -> void:
	if _garden_wait > 0.0:
		return
	if use("garden", ["garden_yield"]):
		_garden_wait = GARDEN_GAP
