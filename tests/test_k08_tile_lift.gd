## K-08 kid check, the ground itself: nothing in the dirt is dark. The Lantern tile textures are
## dark (art, held), so the tile shader lifts every tile toward its ring's own colour (a screen
## blend, LanternTileArt.lift_color is the same sum on the CPU). This suite takes each ring's tiles
## as the shader sees them (the mean colour of their atlas row), lifts them, darkens them as far as
## the shader ever does (deep ground far from air, `deep_tint`), lights them with the darkest
## ambient in that ring (Lantern.ambient_at), and checks the result is not dark. Back walls (the
## inside of a tunnel) get a weaker lift so a tunnel still reads darker than the ground round it.
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const RADIUS := 160
const STEPS := 12
## The shader's own default (shaders/lantern_tiles.gdshader `deep_tint`): the darkest the ground
## gets far from air.
const DEEP_TINT := Color(0.64, 0.61, 0.74)
## Luminance floors, measured on the screen colour (texture x lift x darkening x ambient).
## Deep ground was 0.12 to 0.17 before the lift, tunnel walls 0.11 to 0.14.
const DEEP_FLOOR := 0.2
const OPEN_FLOOR := 0.3
const WALL_FLOOR := 0.2


func _level() -> Dictionary:
	var level := Node2D.new()
	var lantern := Lantern.new()
	lantern.max_lights = 4
	level.add_child(lantern)
	add_child(level)
	auto_free(level)
	var w := PolarWorld.new()
	w.setup_planet(RINGS, RADIUS, 7)
	level.add_child(w)
	w.set_physics_process(false)
	return {lantern = lantern, world = w}


static func _darkness(c: Color) -> float:
	return minf(c.r, minf(c.g, c.b))


func _darkest_ambient(lantern: Lantern) -> Dictionary:
	var px := RADIUS * 16.0
	var out := {}
	var inner := 0.0
	for r: RingDef in RINGS.rings:
		var worst := Color.WHITE
		for i in STEPS:
			var f := lerpf(inner, r.outer, (i + 0.5) / STEPS)
			for ang in [0.0, 1.3, 2.9, 4.4]:
				var c := lantern.ambient_at(Vector2.from_angle(ang) * px * f)
				if _darkness(c) < _darkness(worst):
					worst = c
		out[r.id] = worst
		inner = r.outer
	return out


## The mean colour of one 16 px atlas row (opaque pixels only).
static func _row_mean(tex: Texture2D, row: int) -> Color:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var sum := Vector3.ZERO
	var n := 0
	for y in range(row * 16, row * 16 + 16):
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				sum += Vector3(c.r, c.g, c.b)
				n += 1
	sum /= maxf(n, 1)
	return Color(sum.x, sum.y, sum.z)


static func _mul(a: Color, b: Color) -> Color:
	return Color(a.r * b.r, a.g * b.g, a.b * b.b)


## ring id -> the solid tile names that ring draws (ground and alt).
static func _ring_tiles() -> Dictionary:
	var out := {}
	for r: RingDef in RINGS.rings:
		out[r.id] = [r.tile, r.alt_tile]
	return out


## ring id -> the back-wall row its tunnels show (LanternTileArt.WALL_OF).
static func _ring_wall_row(r: RingDef) -> int:
	var meta := LanternTileArt.load_meta()
	var art_ring := StringName(meta.tile_ring.get(String(r.tile), "dirt"))
	return int(meta.wall_rows.get(String(LanternTileArt.WALL_OF.get(art_ring, &"dirt")), 0))


func test_lift_is_a_screen_blend_that_keeps_the_texture_detail() -> void:
	var hue := Color(0.77, 0.5, 0.28)
	var dark := Color(0.1, 0.08, 0.05)
	var light := Color(0.3, 0.2, 0.12)
	var a := LanternTileArt.lift_color(dark, hue, LanternTileArt.SOLID_LIFT)
	var b := LanternTileArt.lift_color(light, hue, LanternTileArt.SOLID_LIFT)
	assert_float(a.get_luminance()).is_greater(dark.get_luminance())
	assert_float(b.get_luminance()).is_greater(a.get_luminance())   # detail kept, order kept
	assert_float(LanternTileArt.lift_color(Color.WHITE, hue, 1.0).r).is_equal_approx(1.0, 1e-6)
	assert_float(LanternTileArt.lift_color(dark, hue, 0.0).g).is_equal_approx(dark.g, 1e-6)


func test_every_ring_ground_is_lifted_out_of_the_dark() -> void:
	var amb := _darkest_ambient(_level().lantern)
	var rows: Dictionary = LanternTileArt.load_meta().solid_rows
	var tiles := _ring_tiles()
	for r: RingDef in RINGS.rings:
		for t: StringName in tiles[r.id]:
			var mean := _row_mean(LanternTileArt.SOLID_TEX, int(rows[String(t)]))
			var lifted := LanternTileArt.lift_color(mean, r.hue, LanternTileArt.SOLID_LIFT)
			var open := _mul(lifted, amb[r.id])
			var deep := _mul(_mul(lifted, DEEP_TINT), amb[r.id])
			assert_float(open.get_luminance()).override_failure_message("%s %s next to a tunnel: %.3f" % [
					r.id, t, open.get_luminance()]).is_greater_equal(OPEN_FLOOR)
			assert_float(deep.get_luminance()).override_failure_message("%s %s deep in the ground: %.3f" % [
					r.id, t, deep.get_luminance()]).is_greater_equal(DEEP_FLOOR)


func test_without_the_lift_the_dirt_would_be_dark() -> void:
	# the floors are not loose: the bare textures fail them in the dirt and the deep rock
	var amb := _darkest_ambient(_level().lantern)
	var rows: Dictionary = LanternTileArt.load_meta().solid_rows
	for id in [&"dirt", &"deep_rock"]:
		var r: RingDef = RINGS.rings.filter(func(x: RingDef) -> bool: return x.id == id)[0]
		var deep := _mul(_mul(_row_mean(LanternTileArt.SOLID_TEX, int(rows[String(r.tile)])), DEEP_TINT), amb[id])
		assert_float(deep.get_luminance()).is_less(DEEP_FLOOR)


func test_tunnel_walls_are_lifted_but_stay_darker_than_the_ground() -> void:
	var amb := _darkest_ambient(_level().lantern)
	var rows: Dictionary = LanternTileArt.load_meta().solid_rows
	for r: RingDef in RINGS.rings:
		if r.id == &"surface":
			continue   # the surface's air is sky (no wall, W-12)
		var wall := LanternTileArt.lift_color(_row_mean(LanternTileArt.WALL_TEX, _ring_wall_row(r)), r.hue,
				LanternTileArt.WALL_LIFT)
		var ground := LanternTileArt.lift_color(_row_mean(LanternTileArt.SOLID_TEX, int(rows[String(r.tile)])),
				r.hue, LanternTileArt.SOLID_LIFT)
		var lit := _mul(wall, amb[r.id])
		assert_float(lit.get_luminance()).override_failure_message("%s tunnel wall %.3f" % [
				r.id, lit.get_luminance()]).is_greater_equal(WALL_FLOOR)
		assert_float(wall.get_luminance()).override_failure_message("%s tunnel no longer reads" % r.id) \
				.is_less(ground.get_luminance())


func test_the_planet_tiles_carry_the_lift_and_their_ring_colours() -> void:
	var w: PolarWorld = _level().world
	var art := w.tile_art as LanternTileArt
	art.tile_set()
	assert_float(float(art.material.get_shader_parameter(&"lift"))).is_equal(LanternTileArt.SOLID_LIFT)
	assert_float(float(art.wall_material.get_shader_parameter(&"lift"))).is_equal(LanternTileArt.WALL_LIFT)
	for m: ShaderMaterial in [art.material, art.wall_material]:
		assert_int(int(m.get_shader_parameter(&"ring_count"))).is_equal(RINGS.rings.size())
		var outer: PackedFloat32Array = m.get_shader_parameter(&"ring_outer")
		var hues: PackedVector3Array = m.get_shader_parameter(&"ring_hue")
		for i in RINGS.rings.size():
			var r: RingDef = RINGS.rings[i]
			assert_bool(is_equal_approx(outer[i], r.outer)).is_true()
			assert_bool(hues[i].is_equal_approx(Vector3(r.hue.r, r.hue.g, r.hue.b))).is_true()


func test_back_walls_use_the_wall_material() -> void:
	var w: PolarWorld = _level().world
	var art := w.tile_art as LanternTileArt
	var ts := art.tile_set()
	var wall := ts.get_source(TileArt.WALL_SOURCE) as TileSetAtlasSource
	var solid := ts.get_source(TileArt.SOLID_SOURCE) as TileSetAtlasSource
	assert_object(wall.get_tile_data(Vector2i(0, 0), 0).material).is_same(art.wall_material)
	assert_object(solid.get_tile_data(Vector2i(0, 0), 0).material).is_same(art.material)


func test_castings_gardens_stay_out_of_the_dark_in_any_ring() -> void:
	# gardens grow from castings beside a tunnel in any ring, so they are lifted by that ring's colour
	var amb := _darkest_ambient(_level().lantern)
	var rows: Dictionary = LanternTileArt.load_meta().solid_rows
	for r: RingDef in RINGS.rings:
		for g: StringName in RINGS.garden_tiles.values():
			var lifted := LanternTileArt.lift_color(_row_mean(LanternTileArt.SOLID_TEX, int(rows[String(g)])), r.hue,
					LanternTileArt.SOLID_LIFT)
			var lit := _mul(lifted, amb[r.id])
			assert_float(lit.get_luminance()).override_failure_message("%s in %s: %.3f" % [
					g, r.id, lit.get_luminance()]).is_greater_equal(DEEP_FLOOR)
