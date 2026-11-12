## W-10 / W-11 on the planet: a child of planet.tscn's root (like Rings), it hooks the level once the
## world is built. It makes the loose foods (pebbles; a cow later) fall toward the core with a
## LooseFall each, stands the surface props from data/props/*.tres on the surface, and keeps which
## props are bitten or broken in the tin (key "destruct"). Eating stays the world's: tiles go through
## World.eat_tile, and who may bite a prop is World.is_edible_by (the stage rule).
class_name WorldDestruct
extends Node2D

const SAVE_KEY := "destruct"
const PROPS_DIR := "res://data/props/"
const SCENES_DIR := "res://scenes/props/"
## Seconds between sweeps for new loose foods (regrown and newly placed pickups).
const SWEEP_EVERY := 0.5

## Food ids that are loose: they fall when the ground under them is eaten.
@export var loose_foods: Array[StringName] = [&"pebble"]

var world: TileWorld
var level: Node
var foods: Node
## Live props by save key.
var props: Dictionary[String, SurfaceProp] = {}
## Save key -> hp (0 = broken for good).
var state: Dictionary = {}

var _sweep := 0.0


func _ready() -> void:
	var p := get_parent()
	if p is PlanetLevel:
		p.ready.connect(_attach.bind(p), CONNECT_ONE_SHOT)
		Game.quit_requested.connect(_store)
		Game.state_changed.connect(func(_a: int, _b: int) -> void: _store())


func _attach(p: PlanetLevel) -> void:
	level = p
	setup(p.world, p.spawn_point, Save.get_value(SAVE_KEY, {}), p.foods_root)


## Builds the props on this world. saved = the tin's "destruct" dictionary ({} for a new one).
func setup(p_world: TileWorld, spawn: Vector2, saved: Dictionary, p_foods: Node = null) -> void:
	world = p_world
	foods = p_foods
	state = (saved.get("props", {}) as Dictionary).duplicate()
	var start := spawn.angle() if spawn != Vector2.ZERO else -PI / 2.0
	for d in load_props():
		for i in d.angles.size():
			var key := "%s_%d" % [d.id, i]
			var hp := int(state.get(key, d.hits))
			if hp <= 0:
				continue
			place(d, start + d.angles[i], key, hp)
	sweep_loose()


static func load_props() -> Array[PropData]:
	var out: Array[PropData] = []
	var dir := DirAccess.open(PROPS_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		var path := PROPS_DIR + f.trim_suffix(".remap")
		if not path.ends_with(".tres"):
			continue
		var r := load(path)
		if r is PropData:
			out.append(r)
	return out


## Stands a prop on the surface at this angle (radians, world frame), upright.
func place(d: PropData, angle: float, key: String, hp := -1) -> SurfaceProp:
	var path := SCENES_DIR + String(d.id) + ".tscn"
	var prop: SurfaceProp
	if ResourceLoader.exists(path):
		prop = (load(path) as PackedScene).instantiate() as SurfaceProp
	if prop == null:
		prop = SurfaceProp.new()
	prop.data = d
	prop.key = key
	prop.world = world
	prop.chunk_parent = foods
	prop.hp = hp if hp > 0 else d.hits
	prop.name = key.to_pascal_case()
	var up := Vector2.from_angle(angle)
	prop.position = up * surface_distance(world, angle)
	prop.rotation = angle + PI / 2.0
	world.add_child(prop)
	props[key] = prop
	state[key] = prop.hp
	prop.bitten.connect(func(p: SurfaceProp, _pl: int, left: int) -> void: state[p.key] = left)
	prop.broke.connect(func(p: SurfaceProp, _pl: int, _c: Array) -> void:
		state[p.key] = 0
		props.erase(p.key)
		_store())
	return prop


## Distance from the core to the top of the ground along this angle, px.
static func surface_distance(w: TileWorld, angle: float) -> float:
	var dir := Vector2.from_angle(angle)
	var r := float(w.shape.radius + 2) * float(w.shape.cell_size)
	while r > 0.0 and not w.is_solid(w.shape.cell_at(dir * r)):
		r -= 2.0
	while w.is_solid(w.shape.cell_at(dir * (r + 0.5))):
		r += 0.5
	return r


## Gives every loose food that has none a LooseFall.
func sweep_loose() -> void:
	if world == null:
		return
	for f in get_tree().get_nodes_in_group(&"food"):
		var d = f.get("data")
		if d == null or not (d.id in loose_foods) or f.has_node(^"Fall"):
			continue
		var lf := LooseFall.new()
		lf.name = "Fall"
		lf.world = world
		f.add_child(lf)


func _physics_process(delta: float) -> void:
	_sweep += delta
	if _sweep >= SWEEP_EVERY:
		_sweep = 0.0
		sweep_loose()


func to_dict() -> Dictionary:
	return { "props": state.duplicate() }


func _store() -> void:
	if level != null:
		Save.set_value(SAVE_KEY, to_dict())
