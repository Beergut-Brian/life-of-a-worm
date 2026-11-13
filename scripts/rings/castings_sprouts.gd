## G-06: rain soaks into the topsoil and makes castings sprout. While RingsDirector.raining, open
## tunnel cells with castings in the topsoil near a worm push up little green shoots that grow over a
## few seconds and sway (cosmetic first). A grown shoot a worm's mouth passes over is a nibble: a
## small root-flavour growth with the normal chomp cue and a green pop (the light garden bonus).
## The first shoots of a shower near a worm play `garden_plant`. Shoots stay after the rain until
## eaten or the tile grows back over them. Not saved (they come back with the next rain).
class_name CastingsSprouts
extends Node2D

const RING := &"topsoil"
const MAX := 36
const REACH_TILES := 14        # cells checked round each worm's head
const GROW := 6.0              # seconds from a poke to a full shoot
const SCAN := 0.5              # seconds between scans
const PER_SCAN := 3            # new shoots per scan at most
const CHANCE := 0.35           # a candidate cell sprouts this often per scan
const BITE_PX := 10.0
const CUE_GAP := 8.0
const LEAF := Color("7ed957")
const STEM := Color("3f9b3a")
const POP := Color("b6f28a")
## The nibble: counts as a root (tackle page and flavour), a quarter of a plain tile's growth.
static var NIBBLE: FoodData = _nibble()

var director: Node              # RingsDirector (reads .raining, .world)
var world: PolarWorld
## cell -> { "k": 0..1 growth, "t": sway phase }
var sprouts: Dictionary = {}
var rng := RandomNumberGenerator.new()
var _scan_t := 0.0
var _cue_t := 0.0
var _pops: Array[Dictionary] = []   # {at, t}


static func _nibble() -> FoodData:
	var f := FoodData.new()
	f.id = &"root"
	f.flavour = &"root"
	f.growth = 0.25
	f.size_stage = 1
	f.color = LEAF
	f.radius = 3.0
	return f


func _ready() -> void:
	z_index = 1
	rng.seed = 7


func _process(delta: float) -> void:
	step(delta)


## One tick (tests call it with a fixed delta).
func step(delta: float) -> void:
	if world == null:
		return
	_cue_t = maxf(0.0, _cue_t - delta)
	var wet := director != null and bool(director.get("raining"))
	_scan_t += delta
	if wet and _scan_t >= SCAN:
		_scan_t = 0.0
		_poke()
	for cell in sprouts.keys():
		var s: Dictionary = sprouts[cell]
		if world.is_solid(cell) or not world.has_castings(cell):
			sprouts.erase(cell)   # grown over or dug away
			continue
		s.t += delta
		if wet:
			s.k = minf(1.0, s.k + delta / GROW)
	_nibbles()
	for i in range(_pops.size() - 1, -1, -1):
		_pops[i].t += delta
		if _pops[i].t > 0.4:
			_pops.remove_at(i)
	queue_redraw()


## New shoots in open topsoil castings near the worms.
func _poke() -> void:
	if sprouts.size() >= MAX:
		return
	var made := 0
	for w in Worm.all():
		var c := world.shape.cell_at(w.cam_position())
		var cands: Array[Vector2i] = []
		for y in range(-REACH_TILES, REACH_TILES + 1):
			for x in range(-REACH_TILES, REACH_TILES + 1):
				var cell := c + Vector2i(x, y)
				if sprouts.has(cell) or not world.has_castings(cell) or world.is_solid(cell):
					continue
				var ring := world.ring_of(cell)
				if ring == null or ring.id != RING:
					continue
				if not _has_floor(cell):
					continue   # shoots grow up from a tunnel floor, never mid-air
				cands.append(cell)
		for cell in cands:
			if made >= PER_SCAN or sprouts.size() >= MAX:
				break
			if rng.randf() < CHANCE:
				sprouts[cell] = { "k": 0.0, "t": rng.randf() * TAU }
				made += 1
	if made > 0 and _cue_t <= 0.0:
		_cue_t = CUE_GAP
		Audio.play("garden_plant")


## The cell one tile nearer the core is solid ground.
func _has_floor(cell: Vector2i) -> bool:
	var at := world.shape.center_of(cell)
	return world.is_solid(world.shape.cell_at(at - at.normalized() * 16.0))


## A worm's mouth over a full shoot eats it.
func _nibbles() -> void:
	for w in Worm.all():
		if not w.has_method("mouth_position"):
			continue
		var m: Vector2 = w.mouth_position()
		var reach := BITE_PX * (w.size_factor() if w.has_method("size_factor") else 1.0)
		for cell in sprouts.keys():
			if sprouts[cell].k < 1.0:
				continue
			var at := world.shape.center_of(cell)
			if at.distance_to(m) <= reach:
				sprouts.erase(cell)
				_pops.append({ "at": at, "t": 0.0 })
				w.feed(NIBBLE)


func grown() -> int:
	var n := 0
	for cell in sprouts:
		if sprouts[cell].k >= 1.0:
			n += 1
	return n


func _draw() -> void:
	for cell in sprouts:
		var s: Dictionary = sprouts[cell]
		var at := world.shape.center_of(cell)
		var up := at.normalized()             # away from the core
		var side := up.orthogonal()
		var base := at - up * 6.0             # the floor of the tunnel cell
		var k: float = s.k
		var h := 3.0 + 9.0 * k
		var sway := sin(float(s.t) * 2.2) * 1.5 * k
		var tip := base + up * h + side * sway
		draw_line(base, tip, STEM, 2.0)
		if k > 0.3:
			var lk := (k - 0.3) / 0.7
			for sgn in [-1.0, 1.0]:
				draw_circle(base + up * h * 0.6 + side * sgn * 3.0 * lk + side * sway * 0.6, 2.2 * lk, LEAF)
		if s.k >= 1.0:
			draw_circle(tip, 2.5, LEAF.lightened(0.25))   # a bud: ready to nibble
	for p in _pops:
		var k: float = p.t / 0.4
		draw_arc(p.at, 4.0 + 10.0 * k, 0.0, TAU, 16, Color(POP, 1.0 - k), 2.0)
