## K-09: eating a house, a cow or a car is cartoon mayhem. A child of planet.tscn's root (node
## "Mayhem", beside "Destruct"). It listens to every SurfaceProp's own `broke` signal (the prop
## carries its PropData, so its kind) and, when a house, cow or car is eaten, plays that kind's
## pop (the cow also squeaks) from the existing cue files and throws a MayhemBurst of confetti in
## the prop's own colours that falls to the core. The chunks are the destruct lane's (they already
## fall to the core with LooseFall). Nobody is inside: nothing is spawned but the burst, and the
## chunks the prop always made. No voice, no text. Other props keep the plain break.
class_name Mayhem
extends Node

## kind (PropData.id) -> {pop: cue, squeak: cue or "", extra: marks' colours for the confetti}.
## Every cue is an existing file in assets/audio/sfx/ (CUES.md): a different pop for each kind.
const KINDS := {
	&"house": { "pop": "mole_pop", "squeak": "", "pieces": 30,
		"extra": [Color("bfe6f0"), Color("3a2a22"), Color("f6d77a")] },   # windows, door, knob
	&"cow": { "pop": "boop", "squeak": "grub_squeak", "pieces": 22,
		"extra": [Color("f4efe4"), Color("2a1a14"), Color("f2a7a0")] },   # white, spots, nose
	&"car": { "pop": "boing", "squeak": "", "pieces": 26,
		"extra": [Color("bfe6f0"), Color("2a1a14"), Color("9aa0a8")] },   # glass, tyres, hubs
}

signal mayhem(kind: StringName, prop: SurfaceProp, burst: MayhemBurst)

var world: TileWorld
## Every eaten house / cow / car: {kind, key, cues: Array[String]}. Tests read it.
var history: Array[Dictionary] = []
var _watched: Dictionary[int, bool] = {}


static func is_mayhem(d: PropData) -> bool:
	return d != null and KINDS.has(d.id)


## The cues this kind plays when eaten, in order (pop, then the squeak if it has one).
static func cues_for(kind: StringName) -> Array[String]:
	var out: Array[String] = []
	var k: Dictionary = KINDS.get(kind, {})
	if k.is_empty():
		return out
	out.append(String(k.pop))
	if String(k.squeak) != "":
		out.append(String(k.squeak))
	return out


func _ready() -> void:
	var p := get_parent()
	if p is PlanetLevel:
		p.ready.connect(_attach.bind(p), CONNECT_ONE_SHOT)


func _attach(p: Node) -> void:
	var w: TileWorld = p.get("world")
	if w != null:
		watch(w)


## Hooks every surface prop on this world, now and later (WorldDestruct stands them on the world).
func watch(w: TileWorld) -> void:
	world = w
	if not w.child_entered_tree.is_connected(_on_child):
		w.child_entered_tree.connect(_on_child)
	for c in w.get_children():
		_on_child(c)


func _on_child(n: Node) -> void:
	var prop := n as SurfaceProp
	if prop == null or _watched.has(prop.get_instance_id()):
		return
	_watched[prop.get_instance_id()] = true
	prop.broke.connect(_on_broke)


func _on_broke(prop: SurfaceProp, _player: int, _chunks: Array) -> void:
	_watched.erase(prop.get_instance_id())
	if not is_mayhem(prop.data):
		return
	var kind := prop.data.id
	var cues := cues_for(kind)
	for cue in cues:
		Audio.play(cue)
	var b := MayhemBurst.new()
	b.name = "Mayhem%s" % String(kind).capitalize()
	b.colours = colours_of(prop.data)
	b.pieces = int(KINDS[kind].pieces)
	b.world = world
	b.spread = prop.size_px().length() * 0.5
	var host: Node2D = world if world != null else prop.get_parent() as Node2D
	host.add_child(b)
	b.global_position = prop.centre()
	history.append({ "kind": kind, "key": prop.key, "cues": cues })
	mayhem.emit(kind, prop, b)


## The prop's own colours: its tile (and roof) colour from the tile art, then its marks.
static func colours_of(d: PropData) -> Array[Color]:
	var out: Array[Color] = []
	out.append(tile_colour(d.tile))
	if d.top_tile != &"":
		out.append(tile_colour(d.top_tile))
	for c in KINDS.get(d.id, {}).get("extra", []):
		out.append(c)
	return out


static var _tile_cache: Dictionary = {}


## The average colour of a tile row's solid middle cell in the lantern atlas SurfaceProp draws with.
static func tile_colour(tile: StringName) -> Color:
	if _tile_cache.has(tile):
		return _tile_cache[tile]
	var col := Color("c8a27a")
	var img := SurfaceProp.ATLAS.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var row := SurfaceProp._atlas_row(tile)
		var sum := Color(0, 0, 0, 0)
		var n := 0
		for y in range(row * 16 + 3, row * 16 + 13):
			for x in range(3, 13):
				var px := img.get_pixel(x, y)
				if px.a > 0.5:
					sum += px
					n += 1
		if n > 0:
			col = Color(sum.r / n, sum.g / n, sum.b / n, 1.0)
	_tile_cache[tile] = col
	return col
