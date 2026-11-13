## Code-drawn trait parts (D-10): a TraitData with no part_textures and a `part_shape` gets a small
## pixel texture drawn here at runtime, in the trait's colour with the worm outline, so it shows on
## the worm, on the trait wall and in space through the same `part_texture()` as any other part.
## No files: the shapes are polygons rasterised once per (shape, colour) and cached.
class_name StarParts
extends RefCounted

const SIZE := 16
const OUTLINE := Color("2a1a14")
const SHAPES: Array[StringName] = [&"snowflake", &"leaf", &"nut", &"pinwheel", &"cog"]

static var _cache := {}


static func texture(shape: StringName, color: Color) -> Texture2D:
	var key := "%s/%s" % [shape, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var spec := _spec(shape)
	if spec.is_empty():
		return null
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var inside := []
	for y in SIZE:
		for x in SIZE:
			var p := (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(SIZE, SIZE) * 0.5) / (SIZE * 0.5 - 1.5)
			var c := Color(0, 0, 0, 0)
			if _hit(spec.fill, p) and not _hit(spec.get("cut", []), p):
				c = color.lightened(0.55) if _hit(spec.get("detail", []), p) else color
			inside.append(c.a > 0.0)
			img.set_pixel(x, y, c)
	for y in SIZE:
		for x in SIZE:
			if inside[y * SIZE + x]:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + o
				if q.x >= 0 and q.y >= 0 and q.x < SIZE and q.y < SIZE and inside[q.y * SIZE + q.x]:
					img.set_pixel(x, y, OUTLINE)
					break
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _hit(polys: Array, p: Vector2) -> bool:
	for poly in polys:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


## Polygons in -1..1 (y down): `fill` is the part, `cut` holes, `detail` a lighter pattern on it.
static func _spec(shape: StringName) -> Dictionary:
	match shape:
		&"snowflake":   # three crossed bars and a hub: frost
			var bars := []
			for k in 3:
				bars.append(_bar(Vector2.ZERO, k * PI / 3.0 + PI / 2.0, 1.0, 0.17))
			for k in 6:   # little side ticks near each tip
				var a := k * PI / 3.0 + PI / 2.0
				bars.append(_bar(Vector2.from_angle(a) * 0.6, a + PI / 2.0, 0.28, 0.13))
			return { "fill": bars, "detail": [_circle(Vector2.ZERO, 0.22, 6)] }
		&"leaf":        # a pointed leaf, tipped up-right, with a light vein: vines
			var pts := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				pts.append(Vector2(lerpf(-1.0, 1.0, t), -sin(t * PI) * 0.55))
			for i in range(11, 0, -1):
				var t := i / 12.0
				pts.append(Vector2(lerpf(-1.0, 1.0, t), sin(t * PI) * 0.55))
			return { "fill": [_turn(pts, -PI / 4.0)], "detail": [_bar(Vector2.ZERO, -PI / 4.0, 0.8, 0.07)] }
		&"nut":         # a hex nut with its hole: junk
			return { "fill": [_circle(Vector2.ZERO, 1.0, 6, PI / 6.0)], "cut": [_circle(Vector2.ZERO, 0.36, 12)],
					"detail": [_circle(Vector2.ZERO, 0.62, 6, PI / 6.0)] }
		&"pinwheel":    # a round sweet with three light wedges: candy
			var wedges := []
			for k in 3:
				var w := PackedVector2Array([Vector2.ZERO])
				for s in 5:
					w.append(Vector2.from_angle(k * TAU / 3.0 + s * 0.22) * 0.9)
				wedges.append(w)
			return { "fill": [_circle(Vector2.ZERO, 0.95, 20)], "detail": wedges }
		&"cog":         # eight teeth round a wheel with an axle hole: clockwork
			var parts := [_circle(Vector2.ZERO, 0.72, 16)]
			for k in 8:
				parts.append(_bar(Vector2.from_angle(k * TAU / 8.0) * 0.78, k * TAU / 8.0, 0.24, 0.17))
			return { "fill": parts, "cut": [_circle(Vector2.ZERO, 0.26, 10)] }
	return {}


static func _circle(c: Vector2, r: float, n: int, phase := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		out.append(c + Vector2.from_angle(phase + i * TAU / n) * r)
	return out


## A bar centred on c along angle a: half-length h, half-width w.
static func _bar(c: Vector2, a: float, h: float, w: float) -> PackedVector2Array:
	var d := Vector2.from_angle(a)
	var n := d.orthogonal()
	return PackedVector2Array([c + d * h + n * w, c - d * h + n * w, c - d * h - n * w, c + d * h - n * w])


static func _turn(pts: PackedVector2Array, a: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p.rotated(a))
	return out
