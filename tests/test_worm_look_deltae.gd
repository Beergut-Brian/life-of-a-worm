## Read check in numbers (CIEDE2000): Gulp and Burp read apart from each other, from the Lantern Deep
## dirt and topsoil palettes, and every diet stripe reads on both bodies. 20+ is the art lane's "ok".
class_name TestWormLookDeltaE
extends GdUnitTestSuite

const DIRT := ["2e1c13", "4a2e1f", "6c452c", "93653d", "43301f", "322317"]
## Grass high is the Lantern lane's fixed `#d0d48a` (was `#9fbf63`, ΔE 12 to any green: art-lantern-1 REPORT).
const TOPSOIL := ["1b2a1c", "2a4229", "3d5e36", "5b7e45", "2a3626", "1e281b", "d0d48a"]
const INK := Color("140c12")
const OK := 20.0


func after() -> void:
	WormLook.clear_cache()


func test_gulp_and_burp_read_apart() -> void:
	for stage in range(1, 4):
		var d := de2000(_body(0, stage), _body(1, stage))
		assert_float(d).override_failure_message("s%d Gulp vs Burp %.1f" % [stage, d]).is_greater(40.0)


func test_both_worms_read_on_dirt_and_topsoil() -> void:
	for p in [0, 1]:
		for stage in range(1, 4):
			var body := _body(p, stage)
			for hex in DIRT + TOPSOIL:
				var d := de2000(body, Color(hex))
				assert_float(d).override_failure_message("p%d s%d vs #%s %.1f" % [p, stage, hex, d]).is_greater(OK)


func test_every_diet_stripe_reads_on_both_bodies() -> void:
	for p in [0, 1]:
		var body := _body(p, 1)
		var band := _common(WormLook.segment_texture(p, 1, &"band").get_image())
		for f in TestWormLookApi.FLAVOURS:
			var d := de2000(band * WormLook.flavour_tint(f), body)
			assert_float(d).override_failure_message("p%d %s stripe %.1f" % [p, f, d]).is_greater(OK)


## The body's main colour: the most common opaque, non-ink pixel of the body segment.
func _body(p: int, stage: int) -> Color:
	return _common(WormLook.segment_texture(p, stage, &"body").get_image())


func _common(img: Image) -> Color:
	var counts := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.9 or de2000(c, INK) < 8.0:
				continue
			var k := c.to_html(false)
			counts[k] = counts.get(k, 0) + 1
	var best := ""
	for k in counts:
		if best == "" or counts[k] > counts[best]:
			best = k
	return Color(best)


static func _lab(c: Color) -> Vector3:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	var r: float = lin.call(c.r)
	var g: float = lin.call(c.g)
	var b: float = lin.call(c.b)
	var xyz := Vector3((0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047, 0.2126 * r + 0.7152 * g + 0.0722 * b,
			(0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883)
	var f := func(t: float) -> float: return pow(t, 1.0 / 3.0) if t > 216.0 / 24389.0 else (24389.0 / 27.0 * t + 16.0) / 116.0
	var fx: float = f.call(xyz.x)
	var fy: float = f.call(xyz.y)
	var fz: float = f.call(xyz.z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func de2000(c1: Color, c2: Color) -> float:
	var l1 := _lab(c1)
	var l2 := _lab(c2)
	var cb := (Vector2(l1.y, l1.z).length() + Vector2(l2.y, l2.z).length()) / 2.0
	var g := 0.5 * (1.0 - sqrt(pow(cb, 7) / (pow(cb, 7) + pow(25.0, 7))))
	var a1 := l1.y * (1.0 + g)
	var a2 := l2.y * (1.0 + g)
	var c1p := Vector2(a1, l1.z).length()
	var c2p := Vector2(a2, l2.z).length()
	var h1 := fposmod(rad_to_deg(atan2(l1.z, a1)), 360.0)
	var h2 := fposmod(rad_to_deg(atan2(l2.z, a2)), 360.0)
	var dl := l2.x - l1.x
	var dc := c2p - c1p
	var dh := 0.0
	if c1p * c2p != 0.0:
		dh = h2 - h1
		if dh > 180.0:
			dh -= 360.0
		elif dh < -180.0:
			dh += 360.0
	var d_h := 2.0 * sqrt(c1p * c2p) * sin(deg_to_rad(dh / 2.0))
	var lb := (l1.x + l2.x) / 2.0
	var cbp := (c1p + c2p) / 2.0
	var hb := h1 + h2
	if c1p * c2p != 0.0:
		hb = (h1 + h2 + 360.0) / 2.0 if absf(h1 - h2) > 180.0 else (h1 + h2) / 2.0
	var t := 1.0 - 0.17 * cos(deg_to_rad(hb - 30.0)) + 0.24 * cos(deg_to_rad(2.0 * hb)) \
			+ 0.32 * cos(deg_to_rad(3.0 * hb + 6.0)) - 0.20 * cos(deg_to_rad(4.0 * hb - 63.0))
	var dth := 30.0 * exp(-pow((hb - 275.0) / 25.0, 2))
	var rc := 2.0 * sqrt(pow(cbp, 7) / (pow(cbp, 7) + pow(25.0, 7)))
	var sl := 1.0 + 0.015 * pow(lb - 50.0, 2) / sqrt(20.0 + pow(lb - 50.0, 2))
	var sc := 1.0 + 0.045 * cbp
	var sh := 1.0 + 0.015 * cbp * t
	var rt := -sin(deg_to_rad(2.0 * dth)) * rc
	return sqrt(pow(dl / sl, 2) + pow(dc / sc, 2) + pow(d_h / sh, 2) + rt * (dc / sc) * (d_h / sh))


func test_de2000_matches_the_reference_pair() -> void:
	# Same sRGB -> Lab -> CIEDE2000 path as art/worms/tools/de2000.py: P1 vs P2 player colours = 75.8.
	assert_float(de2000(Color("3cc24a"), Color("e4393c"))).is_equal_approx(75.8, 0.2)
