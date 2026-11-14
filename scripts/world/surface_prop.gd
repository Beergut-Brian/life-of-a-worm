## W-11: a multi-tile prop standing on the planet's surface (a crate, later fences, trees, houses),
## from a PropData. Its origin is the middle of its bottom edge, its local -y points away from the
## core (the placer rotates it upright). It is solid (a StaticBody2D on the world's layer), so
## every worm stops against it.
##
## A worm whose mouth touches it bites it, at most once per BITE_COOLDOWN. Who may bite is the one
## shared rule: World.is_edible_by(stage, self) with this prop's size_stage (StageRule: bigger
## eats smaller). A worm too small bonks: a wobble and the "bonk" cue, nothing breaks. A big enough
## worm's bite shows its cause at once: a new crack, a shudder, a chomp ring and dust, the
## "prop_crack" cue, and one chunk (a food) knocked out that falls (LooseFall). The last bite
## breaks it: the "prop_break" cue, a camera nudge, a burst of dust, the remaining chunks fly out
## and the prop pops away. The prop falls too if the ground under it is eaten.
## Drawn with the existing tile art (the lantern solid atlas), placeholder until the art round.
class_name SurfaceProp
extends Node2D

signal bitten(prop: SurfaceProp, player: int, hp_left: int)
signal bonked(prop: SurfaceProp, player: int)
signal broke(prop: SurfaceProp, player: int, chunks: Array)

const ATLAS := preload("res://assets/sprites/tiles/lantern_solid.png")
const BITE_COOLDOWN := 0.45
## A small worm pushing on it bonks at most this often (one boop, not a buzz).
const BONK_COOLDOWN := 1.2
## How far outside its edge a mouth still bites it, px.
const REACH := 6.0
const CRACK_CUE := "prop_crack"
const BREAK_CUE := "prop_break"
const BONK_CUE := "bonk"
const INK := Color("2a1a14")
const CS := 16.0
## Every standing prop is in this group (the tackle log finds the ones stood before it).
const GROUP := &"surface_props"
## Seconds a knocked-out chunk can't be eaten (it is seen flying out and landing first).
const CHUNK_BLOCK := 0.7

@export var data: PropData
## Save key (WorldDestruct sets it: "<id>_<index>").
var key := ""
var world: TileWorld
## Where the chunks go (the level's food layer); null = this prop's parent.
var chunk_parent: Node
var hp := 0
var broken := false
## Chunks knocked out so far.
var chunks_out: Array[Node2D] = []
## Every bite and bonk: {player, stage, bit: bool}. Tests read it.
var history: Array[Dictionary] = []
## StageRule.stage_of reads this (World.is_edible_by's Object branch).
var size_stage: int:
	get:
		return data.size_stage if data else 99

var fall: LooseFall
var _body: StaticBody2D
var _cool: Dictionary[int, float] = {}
var _wobble := 0.0
var _t := 0.0
var _row := 6
var _top_row := 6
var _cracks: Array[PackedVector2Array] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(GROUP)
	if world == null:
		world = get_tree().get_first_node_in_group(&"world") as TileWorld
	if hp <= 0:
		hp = data.hits
	z_index = 1
	_row = _atlas_row(data.tile)
	_top_row = _atlas_row(data.top_tile) if data.top_tile != &"" else _row
	_rng.seed = hash(key if key != "" else String(data.id))
	for i in data.hits - hp:
		_cracks.append(_crack())
	_body = StaticBody2D.new()
	_body.name = "Body"
	if world:
		_body.collision_layer = world.collision_layer
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size_px()
	cs.shape = rect
	cs.position = Vector2(0, -size_px().y * 0.5)
	_body.add_child(cs)
	add_child(_body)
	fall = LooseFall.new()
	fall.name = "Fall"
	fall.world = world
	fall.radius = 0.0
	add_child(fall)


func size_px() -> Vector2:
	return Vector2(data.size) * CS


## The prop's rectangle in its own frame (bottom centre at the origin).
func rect() -> Rect2:
	var s := size_px()
	return Rect2(Vector2(-s.x * 0.5, -s.y), s)


## Global centre (where the chunks come out).
func centre() -> Vector2:
	return to_global(Vector2(0, -size_px().y * 0.5))


func touches(global_point: Vector2) -> bool:
	return rect().grow(REACH).has_point(to_local(global_point))


func _physics_process(delta: float) -> void:
	_t += delta
	_wobble = maxf(0.0, _wobble - delta * 2.5)
	for p in _cool.keys():
		_cool[p] = maxf(0.0, _cool[p] - delta)
	if broken:
		return
	for w in Worm.all():
		if not w.is_inside_tree() or not is_instance_valid(w.head):
			continue
		if _cool.get(w.player, 0.0) <= 0.0 and touches(w.mouth_position()):
			bite(w.player, w.stage, w.mouth_position())
	if _wobble > 0.0:
		queue_redraw()


## A worm of this stage bites it at `at` (global). True when the bite cracked it.
func bite(player: int, stage: int, at := Vector2.INF) -> bool:
	if broken or data == null:
		return false
	if at == Vector2.INF:
		at = centre()
	_cool[player] = BITE_COOLDOWN
	var juice := WormHooks.juice()
	var can: bool = world.is_edible_by(stage, self) if world is PolarWorld else StageRule.relation(stage, size_stage) == StageRule.FOOD
	history.append({ "player": player, "stage": stage, "bit": can })
	if not can:
		_cool[player] = BONK_COOLDOWN
		_wobble = 0.35
		Audio.play(BONK_CUE)
		queue_redraw()
		bonked.emit(self, player)
		return false
	hp -= 1
	_cracks.append(_crack())
	_wobble = 1.0
	juice.chomp(at, Color("f3e7d0"), 1.2)
	juice.debris(at)
	if hp > 0:
		Audio.play(CRACK_CUE)
		_knock_out(1, at)
		bitten.emit(self, player, hp)
	else:
		bitten.emit(self, player, 0)
		_break(player, at)
	queue_redraw()
	return true


func _break(player: int, at: Vector2) -> void:
	broken = true
	Audio.play(BREAK_CUE)
	var juice := WormHooks.juice()
	juice.shake(0.45)   # the camera nudge (honours the screen-shake setting)
	juice.debris(centre())
	juice.chomp(centre(), Color("f3e7d0"), 2.0)
	_body.process_mode = Node.PROCESS_MODE_DISABLED
	_body.collision_layer = 0
	var rest := maxi(0, data.chunks - chunks_out.size())
	_knock_out(rest, at)
	broke.emit(self, player, chunks_out.duplicate())
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.25, 0.6), 0.08)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


## Knocks n chunks out of the prop, flying away from the bite and up, then falling.
func _knock_out(n: int, at: Vector2) -> void:
	if data.chunk == null:
		return
	var host: Node = chunk_parent if chunk_parent != null else get_parent()
	var up := Vector2.UP.rotated(global_rotation)
	var c := centre()
	var away := (c - at).normalized() if c.distance_to(at) > 0.5 else up.orthogonal()
	for i in n:
		var f := RingPickup.new()
		f.data = data.chunk
		f.name = "%sChunk%d" % [String(data.id).capitalize().replace(" ", ""), chunks_out.size()]
		var side := up.orthogonal() * _rng.randf_range(-0.5, 0.5) * size_px().x
		var start := c + side
		f.position = (host as Node2D).to_local(start) if host is Node2D else start
		host.add_child(f)
		var lf := LooseFall.new()
		lf.name = "Fall"
		lf.world = world
		f.add_child(lf)
		var spread := _rng.randf_range(-0.6, 0.6)
		lf.launch(up * _rng.randf_range(170.0, 250.0) + (away + up.orthogonal() * spread).normalized() * _rng.randf_range(90.0, 170.0))
		# Out of reach for a moment (the food protocol's drop block), so you see it fly and land
		# before the worm can gobble it.
		f.set_carried(false, CHUNK_BLOCK)
		chunks_out.append(f)


func _crack() -> PackedVector2Array:
	var r := rect().grow(-2.0)
	var edge := _rng.randi() % 3   # cracks start from the top or a side
	var p: Vector2
	match edge:
		0: p = Vector2(_rng.randf_range(r.position.x, r.end.x), r.position.y)
		1: p = Vector2(r.position.x, _rng.randf_range(r.position.y, r.end.y))
		_: p = Vector2(r.end.x, _rng.randf_range(r.position.y, r.end.y))
	var to := r.get_center() + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4))
	var pts := PackedVector2Array([p])
	var k := 4
	for i in range(1, k + 1):
		var q := p.lerp(to, float(i) / k)
		q += (to - p).orthogonal().normalized() * _rng.randf_range(-3.0, 3.0)
		pts.append(q)
	return pts


func _draw() -> void:
	if data == null:
		return
	var shudder := sin(_t * 60.0) * 1.5 * _wobble
	draw_set_transform(Vector2(shudder, 0), shudder * 0.02, Vector2.ONE)
	var r := rect()
	var look := data.look
	for y in data.size.y:
		for x in data.size.x:
			if PropLook.filled(look, data.size, x, y):
				draw_rect(Rect2(r.position + Vector2(x, y) * CS, Vector2(CS, CS)).grow(1.0), INK)
	for y in data.size.y:
		var row := _top_row if y < data.top_rows else _row
		for x in data.size.x:
			if not PropLook.filled(look, data.size, x, y):
				continue
			var open := 0
			if not _filled(x, y - 1): open |= 1
			if not _filled(x + 1, y): open |= 2
			if not _filled(x, y + 1): open |= 4
			if not _filled(x - 1, y): open |= 8
			var v := (x * 7 + y * 13 + hash(key)) % 4
			var src := Rect2(Vector2((open * 4 + absi(v)) * CS, row * CS), Vector2(CS, CS))
			draw_texture_rect_region(ATLAS, Rect2(r.position + Vector2(x, y) * CS, Vector2(CS, CS)), src)
	# Placeholder marks (crate braces, doors, wheels, spots), so it reads as a made thing, not ground.
	PropLook.draw_marks(self, data, r)
	for c in _cracks:
		draw_polyline(c, Color(1, 0.95, 0.8, 0.7), 3.0)
		draw_polyline(c, INK, 1.5)
	draw_set_transform(Vector2.ZERO)


func _filled(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= data.size.x or y >= data.size.y:
		return false
	return PropLook.filled(data.look, data.size, x, y)


static func _atlas_row(tile: StringName) -> int:
	var rows: Dictionary = LanternTileArt.load_meta().get("solid_rows", {})
	return int(rows.get(String(tile), rows.get("clay", 6)))


func to_dict() -> Dictionary:
	return { "hp": hp }
