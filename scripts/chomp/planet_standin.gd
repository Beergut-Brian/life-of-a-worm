## Stand-in for the tile world's planet until openjar-addons v0.2.0: a seeded disk drawn into an Image,
## rings in their dominant hues, with bites cut out of it. It exposes the one thing the chomp needs from
## the real world: a texture of the remaining planet (`texture()`), plus its ring colours for debris.
## Save shape (small: seed + edits): { "id": String, "seed": int, "bites": [[angle, radius, size], ...] }
## where angle is radians, radius and size are fractions of the planet radius.
class_name PlanetStandIn
extends RefCounted

## Outside in, as fractions of the radius: sky halo, topsoil, dirt, rock, core (GAME.md palette rule).
const RINGS := [
	[1.00, Color("7ec8f0")],   # sky blue
	[0.93, Color("5fb04a")],   # topsoil green
	[0.84, Color("8a5a3a")],   # dirt brown
	[0.58, Color("6f7f9c")],   # rock grey-blue
	[0.30, Color("f08a2c")],   # core orange
]
const OUTLINE := Color("2a1a14")

var id := ""
var seed_value := 0
var bites: Array = []


static func from_save(d: Dictionary) -> PlanetStandIn:
	var p := PlanetStandIn.new()
	p.id = String(d.get("id", ""))
	p.seed_value = int(d.get("seed", 0))
	p.bites = (d.get("bites", []) as Array).duplicate(true)
	return p


## A fresh planet with a few surface bites, as if stages 4 and 5 had chewed the crust.
static func generate(planet_id: String, seed_in: int, bite_count := 9) -> PlanetStandIn:
	var p := PlanetStandIn.new()
	p.id = planet_id
	p.seed_value = seed_in
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_in
	for i in bite_count:
		p.bites.append([snappedf(rng.randf() * TAU, 0.001), snappedf(rng.randf_range(0.9, 1.02), 0.001),
				snappedf(rng.randf_range(0.08, 0.17), 0.001)])
	return p


func to_save() -> Dictionary:
	return { "id": id, "seed": seed_value, "bites": bites }


func ring_colors() -> Array[Color]:
	var out: Array[Color] = []
	for r in RINGS:
		out.append(r[1])
	return out


## The remaining planet as pixels: size x size, transparent outside the disk and inside bites.
func image(size := 288) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var half := size * 0.5
	var radius := half - 2.0
	var cuts: Array = []
	for b in bites:
		var c := Vector2(cos(b[0]), sin(b[0])) * float(b[1]) * radius
		cuts.append([c, float(b[2]) * radius])
	# Lumpy rings: each boundary wobbles a little with the angle, from the seed.
	var wobble: Array[float] = []
	for i in 6:
		wobble.append(rng.randf_range(0.0, TAU))
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5 - half, y + 0.5 - half)
			var r := p.length() / radius
			if r > 1.0 or _in_bite(p, cuts):
				continue
			var a := p.angle()
			var col: Color = RINGS[0][1]
			for i in RINGS.size():
				var edge: float = RINGS[i][0] - 0.02 * (sin(a * 5.0 + wobble[i]) + 1.0) * float(i > 0)
				if r <= edge:
					col = RINGS[i][1]
			# speckle: pebbles, roots and glints so the rings read as stuff, not flat paint
			var n := _hash(x, y)
			if n < 0.06:
				col = col.darkened(0.25)
			elif n > 0.97:
				col = col.lightened(0.3)
			img.set_pixel(x, y, col)
	_outline(img)
	return img


func texture(size := 288) -> ImageTexture:
	return ImageTexture.create_from_image(image(size))


func _in_bite(p: Vector2, cuts: Array) -> bool:
	for c in cuts:
		if p.distance_to(c[0]) < c[1]:
			return true
	return false


func _hash(x: int, y: int) -> float:
	var h := hash(Vector3i(x, y, seed_value))
	return float(h & 0xffff) / 65535.0


## Thick dark outline round every edge (the art direction's chunky look).
func _outline(img: Image) -> void:
	var size := img.get_width()
	var edge: Array[Vector2i] = []
	for y in size:
		for x in size:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + o
				if q.x >= 0 and q.y >= 0 and q.x < size and q.y < size and img.get_pixelv(q).a > 0.0:
					edge.append(Vector2i(x, y))
					break
	for e in edge:
		img.set_pixelv(e, OUTLINE)
