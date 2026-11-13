## D-06 hidden seams and the D-05 Glow geode combo. A few seeded crystal seams hide in the rock
## (deep rock, and the bottom of the dirt so a stage-3 worm can reach some). Nobody sees them, until
## a worm that glows (`light_radius` > 0) comes within NEAR_TILES: then the seam shimmers through
## the rock, and the bulb pops with its trait's sting once per approach. A glowing worm that also
## bites stone (`bite_bonus/stone` > 0) cracks a shimmering seam open when its mouth reaches it: a
## geode bursts out in sparkles with a crack, the worm swallows it (crystal growth), and its stone
## part pops too. A glow-only worm just sees where the seams are. Nothing moves the worm.
## Every shimmer colour goes through GlowCap (light, never opaque): a seam never darkens a ring.
## Seams come back with the planet (seeded, not saved): a found geode is there again next visit.
class_name GeodeSeams
extends Node2D

signal shimmered(player: int, seam: int)
signal cracked(player: int, seam: int)

const DEEP := 6
const LOW_DIRT := 3
## Deep rock is 0.12 to 0.45 of the radius, the dirt 0.45 to 0.82.
const DEEP_BAND := Vector2(0.17, 0.42)
const DIRT_BAND := Vector2(0.48, 0.6)
const NEAR_TILES := 10.0
## Mouth within this many tiles of a shimmering seam cracks it (with the stone bite too).
const CRACK_TILES := 1.6
const GEM := Color(0.78, 0.5, 1.0)

var world: PolarWorld
## {pos (world-local px), found, glow (0..1 shimmer), near: {player: bool}}
var seams: Array[Dictionary] = []
var geode: FoodData
var _t := 0.0


func _ready() -> void:
	world = get_parent() as PolarWorld
	z_index = 2
	geode = FoodData.new()
	geode.id = &"geode_seam"
	geode.flavour = &"crystal"
	geode.growth = 2.0
	geode.size_stage = 1
	geode.color = GEM
	geode.radius = 6.0
	if world == null or world.shape == null:
		return
	var r_px := float(world.shape.radius) * world.shape.cell_size
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, "seams"])
	for i in DEEP + LOW_DIRT:
		var band := DEEP_BAND if i < DEEP else DIRT_BAND
		var a := rng.randf_range(-PI, PI)
		var r := rng.randf_range(band.x, band.y) * r_px
		seams.append({"pos": Vector2.from_angle(a) * r, "tilt": rng.randf_range(0, TAU),
			"found": false, "glow": 0.0, "near": {}})


func _physics_process(delta: float) -> void:
	var cs := float(world.shape.cell_size) if world else 16.0
	for i in seams.size():
		var s: Dictionary = seams[i]
		if s.found:
			continue
		var lit := false
		for w in Worm.all():
			if w.world != world or w.model == null:
				continue
			var stats := w.model.stats
			if stats.value("light_radius") <= 0.0:
				s.near[w.player] = false
				continue
			var pos: Vector2 = s.pos
			var d := (world.to_local(w.head.global_position) - pos).length() / cs
			var near := d <= NEAR_TILES
			if near and not s.near.get(w.player, false):
				w._trait_moment("light_radius")
				shimmered.emit(w.player, i)
			s.near[w.player] = near
			lit = lit or near
			var m := (world.to_local(w.mouth_position()) - pos).length() / cs
			if near and m <= CRACK_TILES * w.size_factor() and stats.value("bite_bonus/stone") > 0.0:
				_crack(w, i)
				break
		s.glow = move_toward(s.glow, 1.0 if lit else 0.0, delta * 2.0)


func _crack(w: Worm, i: int) -> void:
	var s: Dictionary = seams[i]
	s.found = true
	s.glow = 0.0
	Audio.play("egg_crack")
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.amount = 40
	burst.lifetime = 0.9
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 160.0
	burst.gravity = Vector2.ZERO
	burst.scale_amount_min = 4.0
	burst.scale_amount_max = 8.0
	burst.color = GEM
	burst.position = s.pos
	add_child(burst)
	burst.emitting = true
	burst.finished.connect(burst.queue_free)
	var ring := WormRing.new()
	ring.color = GEM
	ring.life = 0.6
	ring.max_radius = 5.0 * float(world.shape.cell_size)
	ring.position = s.pos
	add_child(ring)
	w._trait_moment("bite_bonus/stone")
	w.feed(geode)
	cracked.emit(w.player, i)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var cs := float(world.shape.cell_size) if world else 16.0
	for s in seams:
		if s.found or s.glow <= 0.0:
			continue
		var a: float = s.glow
		var pos: Vector2 = s.pos
		var dir := Vector2.from_angle(s.tilt)
		# A short vein of crystal points, each twinkling on its own beat.
		for k in 5:
			var p := pos + dir * (k - 2) * cs * 1.2 + dir.orthogonal() * sin(k * 1.7) * cs * 0.5
			var tw := 0.55 + 0.45 * sin(_t * 5.0 + k * 1.3)
			var sz := cs * (0.6 + 0.3 * tw)
			var c := GlowCap.tint(GEM, a * (0.6 + 0.4 * tw))
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -sz), p + Vector2(sz * 0.6, 0),
				p + Vector2(0, sz), p + Vector2(-sz * 0.6, 0)]), c)
			draw_line(p - Vector2(sz * 1.4, 0), p + Vector2(sz * 1.4, 0), GlowCap.tint(Color.WHITE, a * tw * 0.8), 1.5)
			draw_line(p - Vector2(0, sz * 1.4), p + Vector2(0, sz * 1.4), GlowCap.tint(Color.WHITE, a * tw * 0.8), 1.5)
		draw_circle(pos, cs * 4.0, GlowCap.tint(GEM, a * (0.16 + 0.06 * sin(_t * 3.0))))
