## D-06 "secrets shimmer": while a worm whose trait lights (`light_radius` > 0) is within
## SHIMMER_TILES of a hidden place it has not found yet, the hall twinkles through the rock in the
## trait's colour, packed on the side facing the worm, so the kid sees where to dig. Each time a
## glowing worm comes into range its bulb pops with the Glow sting (the cause on screen). A plain
## worm never sees it; a found hall stops twinkling. Nothing steers the worm.
## A child of the PolarWorld (TraitKnacks._attach), so secret_spot.gd stays as it is. Every colour
## goes through GlowCap: light, never opaque, so a ring never gets darker.
class_name SecretShimmer
extends Node2D

signal shimmered(player: int, secret: StringName)

const SHIMMER_TILES := 12.0
const FADE := 2.5
const SPARKS := 9
const RESCAN := 1.0

var world: PolarWorld
## {secret id: {spot: SecretSpot, glow: 0..1, dir: Vector2, color: Color, near: {player: bool}}}
var halls := {}
## Glowing-worm approaches (one per worm per approach); tests read it.
var approaches := 0
var _scan := 0.0
var _t := 0.0


func _ready() -> void:
	world = get_parent() as PolarWorld
	z_index = 2


func _physics_process(delta: float) -> void:
	if world == null or world.shape == null:
		return
	_scan -= delta
	if _scan <= 0.0:
		_scan = RESCAN
		_rescan()
	var cs := float(world.shape.cell_size)
	for id in halls.keys():
		var h: Dictionary = halls[id]
		var spot: SecretSpot = h.spot
		if not is_instance_valid(spot) or spot.data == null:
			halls.erase(id)
			continue
		var found := spot.director != null and spot.director.found.has(spot.data.id)
		var at := hall_pos(spot)
		var reach := (spot.data.radius_tiles + SHIMMER_TILES) * cs
		var best := INF
		for w in Worm.all():
			if w.world != world or w.model == null or not w.is_inside_tree():
				continue
			var lit := w.model.stats.value("light_radius") > 0.0
			var to := world.to_local(w.head.global_position) - at
			var near := lit and not found and to.length() <= reach
			if near and not h.near.get(w.player, false):
				approaches += 1
				w._trait_moment("light_radius")   # the bulb pops: that's why it twinkles
				shimmered.emit(w.player, StringName(id))
			h.near[w.player] = near
			if near and to.length() < best:
				best = to.length()
				if to.length() > 0.01:
					h.dir = to.normalized()
				var t := w._trait_for("light_radius")
				if t != null:
					h.color = t.color
		h.glow = move_toward(h.glow, 1.0 if best < INF else 0.0, delta * FADE)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _rescan() -> void:
	for n in get_tree().root.find_children("Secret_*", "SecretSpot", true, false):
		var spot := n as SecretSpot
		if spot == null or spot.data == null or halls.has(spot.data.id):
			continue
		halls[spot.data.id] = {"spot": spot, "glow": 0.0, "dir": Vector2.UP,
			"color": Color(0.4353, 0.9412, 1.0), "near": {}}


## A hall's centre in world-local px.
func hall_pos(spot: SecretSpot) -> Vector2:
	return world.to_local(spot.global_position)


## How much a hall twinkles right now (0..1), or 0 when it is not known.
func glow_of(id: StringName) -> float:
	return float(halls[id].glow) if halls.has(id) else 0.0


## Every colour one hall's twinkles use at this glow and time (the draw uses exactly these).
static func spark_colors(base: Color, glow: float, t: float) -> Array[Color]:
	var out: Array[Color] = []
	for i in SPARKS + 4:
		var tw := 0.5 + 0.5 * sin(t * 4.0 + i * 1.7)
		out.append(GlowCap.tint(base.lightened(0.5), glow * (0.45 + 0.55 * tw)))
		out.append(GlowCap.tint(base, glow * 0.25 * tw))
		out.append(GlowCap.tint(Color.WHITE, glow * (0.4 + 0.6 * tw)))
	return out


func _draw() -> void:
	if world == null or world.shape == null:
		return
	var cs := float(world.shape.cell_size)
	for id in halls:
		var h: Dictionary = halls[id]
		if h.glow <= 0.0 or not is_instance_valid(h.spot):
			continue
		var spot: SecretSpot = h.spot
		var at := hall_pos(spot)
		var r: float = spot.data.radius_tiles * cs
		var face: float = (h.dir as Vector2).angle()
		var cols := spark_colors(h.color, h.glow, _t)
		for i in SPARKS + 4:
			var p: Vector2
			var arm: float
			if i < SPARKS:
				var f := float(i) / float(SPARKS - 1) - 0.5   # across the near side
				var a := face + f * 2.4 + sin(_t * 0.7 + i) * 0.08
				p = at + Vector2.from_angle(a) * r * (0.92 + 0.12 * sin(_t * 1.3 + i * 2.1))
				arm = (10.0 + 8.0 * (0.5 + 0.5 * sin(_t * 4.0 + i * 1.7))) * (1.0 - absf(f) * 0.8)
			else:
				p = at + Vector2.from_angle(face + PI * 0.5 * (i - SPARKS) + _t * 0.2) * r * 0.45
				arm = 7.0 + 4.0 * (0.5 + 0.5 * sin(_t * 3.1 + i * 2.6))
			draw_circle(p, arm * 0.7, cols[i * 3 + 1])
			draw_line(p - Vector2(arm, 0), p + Vector2(arm, 0), cols[i * 3], 3.0)
			draw_line(p - Vector2(0, arm), p + Vector2(0, arm), cols[i * 3], 3.0)
			draw_circle(p, 2.5, cols[i * 3 + 2])
