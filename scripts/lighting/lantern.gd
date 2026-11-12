## Lantern Deep lighting (look B, Docket D92), one reusable node. Drop it into a level as a child of
## the node that adds the TileWorld (planet.tscn, disk.tscn): when the world enters the tree it gets
## the Lantern tiles (LanternTileArt), and from then on this node runs
##   * a CanvasModulate: a dim, coloured ambient by the camera's ring (dim, never dark),
##   * a capped pool of PointLight2Ds (max_lights) handed each tick to the nearest emitters:
##     a light on every worm (warm white tinted toward its slot colour, P1 green / P2 red), crystal
##     and mushroom clusters, the Strangestone, the core glow, and a daylight shaft wherever the
##     surface crust has been eaten through.
## Emitters come from the tiles of loaded chunks (binned, so a cluster is one light) and follow the
## world's tile_dug / tile_regrown signals. No 2D shadows; ground darkening is in the tile shader.
class_name Lantern
extends Node2D

enum Kind { WORM, CRYSTAL, MUSHROOM, STRANGE, CORE, SHAFT }

const RADIAL := preload("res://assets/sprites/light/light_radial.png")
const SHAFT_TEX := preload("res://assets/sprites/light/light_shaft.png")
## Emitter clustering: one glow light per bin of this many tiles.
const BIN := 6
## Daylight shafts: one per this many tiles of surface arc.
const SHAFT_BIN := 5
## Look per kind: colour, energy, radius in tiles.
const LOOK := {
	Kind.WORM: [Color("fff1d6"), 1.2, 8.0],
	Kind.CRYSTAL: [Color("59e6ff"), 0.95, 6.0],
	Kind.MUSHROOM: [Color("c48ae0"), 0.8, 4.5],
	Kind.STRANGE: [Color("b8ff6a"), 0.9, 6.0],
	Kind.CORE: [Color("ff8a2a"), 1.1, 0.0],
	Kind.SHAFT: [Color("ffe2a8"), 1.0, 26.0],
}
## Glowing tile names -> kind.
const GLOW_TILES := {&"crystal": Kind.CRYSTAL, &"garden_crystal": Kind.CRYSTAL,
	&"mushroom": Kind.MUSHROOM, &"strangestone": Kind.STRANGE}
## Ambient by ring id (RingDef.id), dim not dark: warm in dirt, cool in rock, orange near the core.
const AMBIENT := {&"surface": Color("fffaf0"), &"topsoil": Color("d6cfba"), &"dirt": Color("c4ac94"),
	&"deep_rock": Color("a4acc8"), &"core": Color("d8aa8c")}
const AMBIENT_SKY := Color("ffffff")
## Never darker than this, whatever a ring says (kid check K-08: dim, not dark).
const AMBIENT_FLOOR := 0.55

@export var max_lights := 16
## Seconds between reassigning the pool to the nearest emitters.
@export var tick := 0.15
## Height used for normal-mapped shading (PointLight2D.height).
@export var light_height := 24.0
## Swap in the Lantern tiles when the world enters (false: lights only).
@export var tile_art := true
## Extra nodes that carry a worm-style light (stand-in eaters in the stress scene).
var follow: Array[Node2D] = []

var world: TileWorld
var art: LanternTileArt
var modulate_node: CanvasModulate
var lights: Array[PointLight2D] = []
## Per pool light: the node it follows every frame (a worm head), or null.
var _follow: Array = []
## Emitters: id -> {pos, kind, node?, count}. Worms are not stored here (read live each tick).
var emitters: Dictionary = {}
## Lights lit in the last tick (measured in the stress scene).
var active_lights := 0
var assign_usec := 0

var _glow_kind := PackedInt32Array()
var _chunk_bins: Dictionary[Vector2i, Array] = {}
var _acc := 0.0
var _ambient := Color.WHITE
var _crust_from := 0.0
var _radius_px := 0.0


func _ready() -> void:
	modulate_node = CanvasModulate.new()
	modulate_node.name = "Ambient"
	add_child(modulate_node)
	for i in max_lights:
		var l := PointLight2D.new()
		l.name = "Light%d" % i
		l.enabled = false
		l.texture = RADIAL
		l.height = light_height
		l.shadow_enabled = false
		add_child(l)
		lights.append(l)
		_follow.append(null)
	var p := get_parent()
	if p:
		p.child_entered_tree.connect(_on_sibling)
		for c in p.get_children():
			if c is TileWorld:
				attach(c, false)


func _on_sibling(node: Node) -> void:
	if node is TileWorld and node != world:
		attach(node, tile_art)


## Lights a world. With `swap_tiles` (only safe before chunks load or a save is applied) the world
## is set up again with the Lantern tiles; setup() is the addon's public entry and keeps the shape,
## generator, palette and seed.
func attach(w: TileWorld, swap_tiles := true) -> void:
	world = w
	if swap_tiles and w.shape != null and w.edits.tiles.is_empty():
		art = LanternTileArt.new(w)
		w.tile_art = art
		w.setup(w.shape, w.generator, w.palette, w.world_seed)
	_glow_kind.resize(w.palette.size())
	for i in w.palette.size():
		var def: TileDef = w.palette[i]
		_glow_kind[i] = int(GLOW_TILES.get(def.id, -1)) if def else -1
	var rad = w.shape.get(&"radius") if w.shape else null
	_radius_px = float(rad) * w.shape.cell_size if rad != null else 0.0
	_crust_from = 0.0
	var rs = w.get(&"rings")
	if rs != null and rs.rings.size() >= 2:
		_crust_from = rs.rings[rs.rings.size() - 2].outer * float(rad)
	emitters.clear()
	_chunk_bins.clear()
	if _radius_px > 0.0:
		emitters[&"core"] = {pos = Vector2.ZERO, kind = Kind.CORE, count = 1}
	w.chunk_loaded.connect(_on_chunk_loaded)
	w.chunk_freed.connect(_on_chunk_freed)
	w.tile_dug.connect(_on_tile_dug)
	if w.has_signal(&"tile_regrown"):
		w.connect(&"tile_regrown", _on_tile_regrown)
	for key in w.loaded_chunks():
		_on_chunk_loaded(key)


# --- emitters ------------------------------------------------------------------------------------

func _bin_id(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(cell.x / float(BIN)), floori(cell.y / float(BIN)))


func _in_crust(cell: Vector2i) -> bool:
	if _crust_from <= 0.0:
		return false
	var r := (Vector2(cell) + Vector2(0.5, 0.5)).length()
	return r >= _crust_from - 0.5 and r * world.shape.cell_size < _radius_px


func _shaft_key(cell: Vector2i) -> StringName:
	var a := Vector2(cell).angle()
	var step := float(SHAFT_BIN) / maxf(_crust_from, 1.0)
	return StringName("shaft_%d" % roundi(a / step))


func _add_glow(cell: Vector2i, kind: int) -> StringName:
	var b := _bin_id(cell)
	var key := StringName("g%d_%d_%d" % [kind, b.x, b.y])
	var e: Dictionary = emitters.get(key, {})
	var cs: float = world.shape.cell_size
	var p := (Vector2(cell) + Vector2(0.5, 0.5)) * cs
	if e.is_empty():
		emitters[key] = {pos = p, kind = kind, count = 1, sum = p}
	else:
		e.count += 1
		e.sum += p
		e.pos = e.sum / e.count
	return key


func _remove_glow(cell: Vector2i, kind: int) -> void:
	var b := _bin_id(cell)
	var key := StringName("g%d_%d_%d" % [kind, b.x, b.y])
	var e: Dictionary = emitters.get(key, {})
	if e.is_empty():
		return
	var p := (Vector2(cell) + Vector2(0.5, 0.5)) * float(world.shape.cell_size)
	e.count -= 1
	e.sum -= p
	if e.count <= 0:
		emitters.erase(key)
	else:
		e.pos = e.sum / e.count


func _add_shaft(cell: Vector2i) -> StringName:
	var key := _shaft_key(cell)
	var e: Dictionary = emitters.get(key, {})
	if e.is_empty():
		var dir := Vector2(cell).normalized()
		emitters[key] = {pos = dir * _radius_px, kind = Kind.SHAFT, count = 1, dir = dir}
	else:
		e.count += 1
	return key


func _remove_shaft(cell: Vector2i) -> void:
	var key := _shaft_key(cell)
	var e: Dictionary = emitters.get(key, {})
	if e.is_empty():
		return
	e.count -= 1
	if e.count <= 0:
		emitters.erase(key)


func _on_chunk_loaded(key: Vector2i) -> void:
	var keys: Array = []
	for c: Vector2i in world.shape.chunk_cells(key):
		var id := world.get_tile(c)
		if id > 0:
			var k := _glow_kind[id] if id < _glow_kind.size() else -1
			if k >= 0:
				keys.append([c, k])
				_add_glow(c, k)
		elif _in_crust(c) and world.base_tile_of(c) > 0:
			keys.append([c, Kind.SHAFT])
			_add_shaft(c)
	_chunk_bins[key] = keys


func _on_chunk_freed(key: Vector2i) -> void:
	for pair in _chunk_bins.get(key, []):
		if pair[1] == Kind.SHAFT:
			_remove_shaft(pair[0])
		else:
			_remove_glow(pair[0], pair[1])
	_chunk_bins.erase(key)


func _on_tile_dug(cell: Vector2i, block: StringName, _player: int) -> void:
	var k: int = GLOW_TILES.get(block, -1)
	var key := world.shape.chunk_of(cell)
	var list: Array = _chunk_bins.get(key, [])
	if k >= 0:
		_remove_glow(cell, k)
		_erase_pair(list, cell, k)
	if _in_crust(cell):
		_add_shaft(cell)
		list.append([cell, Kind.SHAFT])
		_chunk_bins[key] = list


func _on_tile_regrown(cell: Vector2i, block: StringName) -> void:
	var key := world.shape.chunk_of(cell)
	var list: Array = _chunk_bins.get(key, [])
	if _in_crust(cell) and _erase_pair(list, cell, Kind.SHAFT):
		_remove_shaft(cell)
	var k: int = GLOW_TILES.get(block, -1)
	if k >= 0:
		_add_glow(cell, k)
		list.append([cell, k])
	_chunk_bins[key] = list


func _erase_pair(list: Array, cell: Vector2i, kind: int) -> bool:
	for i in list.size():
		if list[i][0] == cell and list[i][1] == kind:
			list.remove_at(i)
			return true
	return false


# --- the pool ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_acc += delta
	var cam := get_viewport().get_camera_2d()
	var focus := cam.get_screen_center_position() if cam else Vector2.ZERO
	_update_ambient(focus, delta)
	_follow_worms()
	if _acc < tick:
		return
	_acc = 0.0
	assign(focus, _view_radius(cam))


## The ambient for the ring under `focus`, eased so walking between rings fades rather than snaps.
func _update_ambient(focus: Vector2, delta: float) -> void:
	var want := ambient_at(focus)
	_ambient = _ambient.lerp(want, clampf(delta * 2.0, 0.0, 1.0))
	modulate_node.color = _ambient


func ambient_at(p: Vector2) -> Color:
	if world == null or _radius_px <= 0.0:
		return AMBIENT_SKY
	var f := p.length() / _radius_px
	if f >= 1.0:
		return AMBIENT_SKY
	var rs = world.get(&"rings")
	var c := AMBIENT_SKY
	if rs != null:
		for r: RingDef in rs.rings:
			if f < r.outer:
				c = AMBIENT.get(r.id, AMBIENT_SKY)
				break
	return Color(maxf(c.r, AMBIENT_FLOOR), maxf(c.g, AMBIENT_FLOOR), maxf(c.b, AMBIENT_FLOOR))


func _view_radius(cam: Camera2D) -> float:
	var vs := get_viewport_rect().size
	var z := cam.zoom.x if cam else 1.0
	return vs.length() * 0.5 / maxf(z, 0.01)


func _worm_nodes() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for w in get_tree().get_nodes_in_group(&"worms"):
		var head = w.get(&"head")
		if head is Node2D and head.is_inside_tree():
			out.append(head)
	for n in follow:
		if is_instance_valid(n) and n.is_inside_tree():
			out.append(n)
	return out


func _follow_worms() -> void:
	# Worm lights move every frame (the rest of the pool only on ticks).
	for i in lights.size():
		var n = _follow[i]
		if n != null and is_instance_valid(n):
			lights[i].global_position = (n as Node2D).global_position


## Hands the pool to the worms first, then the nearest emitters that can reach the view.
func assign(focus: Vector2, view_radius: float) -> void:
	var t0 := Time.get_ticks_usec()
	var picks: Array = []
	for n in _worm_nodes():
		picks.append({node = n, kind = Kind.WORM, d = 0.0})
	var cand: Array = []
	for key in emitters:
		var e: Dictionary = emitters[key]
		var reach := _reach_px(e)
		var d: float = (e.pos as Vector2).distance_to(focus) - reach
		if e.kind == Kind.CORE:
			d = maxf(0.0, focus.length() - reach)
		if d <= view_radius:
			cand.append({e = e, d = d, kind = e.kind})
	cand.sort_custom(func(a, b): return a.d < b.d)
	picks.append_array(cand)
	active_lights = mini(picks.size(), lights.size())
	for i in lights.size():
		var l := lights[i]
		if i >= picks.size():
			l.enabled = false
			_follow[i] = null
			continue
		_follow[i] = picks[i].node if picks[i].kind == Kind.WORM else null
		_light(l, picks[i])
	assign_usec = Time.get_ticks_usec() - t0


func _reach_px(e: Dictionary) -> float:
	var look: Array = LOOK[e.kind]
	if e.kind == Kind.CORE:
		return core_radius_px()
	return look[2] * float(world.shape.cell_size) if world else look[2] * 16.0


func core_radius_px() -> float:
	var rs = world.get(&"rings") if world else null
	var outer: float = rs.rings[0].outer if rs != null and not rs.rings.is_empty() else 0.12
	return outer * _radius_px * 1.5


func _light(l: PointLight2D, pick: Dictionary) -> void:
	var kind: int = pick.kind
	var look: Array = LOOK[kind]
	l.enabled = true
	l.color = look[0]
	l.energy = look[1]
	l.rotation = 0.0
	l.offset = Vector2.ZERO
	l.texture = RADIAL
	var cs := float(world.shape.cell_size) if world else 16.0
	var radius: float = look[2] * cs
	match kind:
		Kind.WORM:
			var n: Node2D = pick.node
			l.global_position = n.global_position
			var w = n.get_parent()
			var p = w.get(&"player") if w else null
			if p is int and Players.COLOR.has(p):
				l.color = (look[0] as Color).lerp(Players.COLOR[p], 0.3)
		Kind.CORE:
			l.global_position = global_position_of(Vector2.ZERO)
			radius = core_radius_px()
		Kind.SHAFT:
			var e: Dictionary = pick.e
			l.texture = SHAFT_TEX
			l.global_position = global_position_of(e.pos)
			l.rotation = (-(e.dir as Vector2)).angle() - PI / 2.0
			l.offset = Vector2(0, SHAFT_TEX.get_height() * 0.5)
			l.texture_scale = radius / SHAFT_TEX.get_height()
			l.height = radius
			return
		_:
			l.global_position = global_position_of(pick.e.pos)
	l.texture_scale = radius * 2.0 / RADIAL.get_width()
	l.height = maxf(light_height, radius * 0.9)


func global_position_of(world_local: Vector2) -> Vector2:
	return world.to_global(world_local) if world else world_local
