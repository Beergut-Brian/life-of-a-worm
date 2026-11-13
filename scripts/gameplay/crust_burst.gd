## The crust burst (S-08). From StageTable.crust_stage() (stage 5 in data/stages.tres) a worm can
## bite the crust ring (StageData.crust_ring, the surface). Below that stage the surface is not food:
## the worm bonks off it (the world's dig_blocked), which is the cause the player sees. The first
## bite through, once per worm per tin and saved, is the breakthrough: the "breakthrough" cue, a
## grass-and-dirt burst, a flash and shake, a short camera pull-back and the why-bubble (sky over
## the worm). Crust tiles a worm eats never grow back (StageTable.apply_crust), so the disk shrinks,
## and `edge` (DiskEdge, W-12) makes the planet's outline sink where it is eaten open to the sky.
## The level only connects, sets its zoom through steer_camera() and saves to_dict(). Placeholder visuals.
class_name CrustBurst
extends Node

signal breakthrough(player: int)

const CUE := "breakthrough"
## Tin save key.
const SAVE_KEY := "crust"
## Seconds the camera stays one zoom step wider after a breakthrough.
const PULL_TIME := 1.4
const WHY_LIFE := 1.8

var world: PolarWorld
var camera: PolarCamera
var table: StageTable
## Players that have broken through in this tin.
var broken: Array[int] = []
## Crust tiles eaten for good in this tin (the disk shrinking).
var eaten := 0
## Every breakthrough played: {player, cell, stage}.
var history: Array[Dictionary] = []
## The planet's eaten outline (scripts/world/disk_edge.gd), next to the level's back wall; null
## when the world has none (a bare test world).
var edge: DiskEdge

var _pull_t := 0.0
var _base_min := -1


func _init(p_table: StageTable = null) -> void:
	table = p_table if p_table != null else StageTable.default_table()
	name = "CrustBurst"


func watch(p_world: PolarWorld) -> void:
	world = p_world
	if not world.tile_eaten.is_connected(_on_tile_eaten):
		world.tile_eaten.connect(_on_tile_eaten)
	if edge == null:
		edge = DiskEdge.make_for(world)


func crust_ring() -> StringName:
	return table.crust_ring()


func can_burst(stage: int) -> bool:
	var s := table.crust_stage()
	return s > 0 and stage >= s


func is_crust(cell: Vector2i, block: StringName) -> bool:
	if world == null or crust_ring() == &"":
		return false
	var ring := world.ring_of(cell)
	return ring.id == crust_ring() and (block == ring.tile or block == ring.alt_tile)


## The zoom cap with the breakthrough's pull-back applied (one step wider while it plays).
func cap(base: int) -> int:
	return maxi(0, base - 1) if _pull_t > 0.0 else base


## Sets the camera's zoom bounds for this frame: the stage's cap, one step wider during the
## pull-back (the camera's own floor is lowered for it, then restored).
func steer_camera(base: int) -> void:
	if camera == null:
		return
	if _base_min < 0:
		_base_min = camera.min_fit_index
	camera.max_fit_index = cap(base)
	camera.min_fit_index = mini(_base_min, camera.max_fit_index)


func _process(delta: float) -> void:
	_pull_t = maxf(0.0, _pull_t - delta)


func _on_tile_eaten(cell: Vector2i, block: StringName, player: int) -> void:
	if player < 0 or not is_crust(cell, block):
		return
	eaten += 1
	if player in broken:
		return
	broken.append(player)
	history.append({ "player": player, "cell": cell, "stage": world.stage_of(player) })
	_burst(player, cell)
	breakthrough.emit(player)
	var w := Worm.of(player)
	if w:
		w.breakthrough.emit(player)
	print("breakthrough: P%d" % (player + 1))


func _burst(player: int, cell: Vector2i) -> void:
	Audio.play(CUE)
	var at: Vector2 = world.shape.center_of(cell)
	var juice := WormHooks.juice()
	juice.stage_flash()
	juice.shake(0.8)
	juice.debris(at)
	if camera != null and SettingsPanel.screen_shake():
		camera.shake = maxf(camera.shake, 0.8)
	_pull_t = PULL_TIME
	var fx := CPUParticles2D.new()
	fx.name = "CrustFx"
	fx.position = at
	fx.one_shot = true
	fx.explosiveness = 0.95
	fx.amount = 48
	fx.lifetime = 1.2
	fx.direction = at.normalized() if at != Vector2.ZERO else Vector2.UP
	fx.spread = 50.0
	fx.initial_velocity_min = 120.0
	fx.initial_velocity_max = 320.0
	fx.gravity = -fx.direction * 300.0
	fx.scale_amount_min = 3.0
	fx.scale_amount_max = 6.0
	var grad := Gradient.new()
	grad.set_color(0, Color("8bb04a"))
	grad.set_color(1, Color("8a5a32"))
	fx.color_initial_ramp = grad
	fx.z_index = 6
	world.add_child(fx)
	fx.emitting = true
	fx.finished.connect(fx.queue_free)
	var w := Worm.of(player)
	if w:
		w.swell(1.6)
		var why := CrustWhy.new()
		why.worm = w
		why.color = Players.COLOR[player]
		why.life = WHY_LIFE
		world.add_child(why)


func to_dict() -> Dictionary:
	return { "broken": broken.duplicate(), "eaten": eaten }


func from_dict(d: Dictionary) -> void:
	broken.clear()
	for p in d.get("broken", []):
		broken.append(int(p))
	eaten = int(d.get("eaten", 0))
