## Look B contrast (A-07, A-08): both worms' green and red stay distinct on the dirt and topsoil
## rings, measured with CIEDE2000 on the real tile textures (every colour that covers at least 1%
## of a material), and each ring keeps its dominant hue (dirt brown, topsoil green).
class_name TestLookContrast
extends GdUnitTestSuite

const RINGS := preload("res://data/rings/rings.tres")
const LOOKS := preload("res://data/rings/looks.tres")
const P1 := Color("3cc24a")
const P2 := Color("e4393c")
## ΔE2000: under 10 loses the worm; 20+ is comfortable (art/direction/deltae.md bands).
const MAIN_MIN := 20.0
const SPECK_MIN := 15.0


func _shares(material: String) -> Dictionary:
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RingTileArt.MANIFEST))
	var i: int = man.materials.find(material)
	assert_int(i).is_greater_equal(0)
	var img := (RingTileArt.MATS as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var s := int(man.size)
	var counts := {}
	for y in s:
		for x in s:
			var c := img.get_pixel(i * s + x, y)
			var key := c.to_html(false)
			counts[key] = counts.get(key, 0) + 1
	var out := {}
	for k in counts:
		out[k] = float(counts[k]) / float(s * s)
	return out


func _materials_of(ring_id: StringName) -> Array[String]:
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RingTileArt.MANIFEST))
	var out: Array[String] = []
	for r in RINGS.rings:
		if r.id == ring_id:
			for t in [r.tile, r.alt_tile]:
				if t != &"":
					out.append(man.tiles[String(t)])
	return out


func test_delta_e_matches_the_option_sheet() -> void:
	# art/direction/README.md, option B dirt dominant #6c452c: P1 54.9, P2 26.2
	assert_float(DeltaE.de2000(P1, Color("6c452c"))).is_equal_approx(54.9, 0.6)
	assert_float(DeltaE.de2000(P2, Color("6c452c"))).is_equal_approx(26.2, 0.6)
	assert_float(DeltaE.de2000(P1, P1)).is_equal_approx(0.0, 0.001)


func test_both_worms_stay_distinct_on_dirt_and_topsoil() -> void:
	for ring in [&"dirt", &"topsoil"]:
		var mats := _materials_of(ring)
		assert_int(mats.size()).is_equal(2)
		for m in mats:
			var shares := _shares(m)
			for hex in shares:
				var share: float = shares[hex]
				if share < 0.01:
					continue
				var need := MAIN_MIN if share >= 0.05 else SPECK_MIN
				for worm in [P1, P2]:
					var de := DeltaE.de2000(worm, Color(hex))
					assert_float(de).override_failure_message("%s/%s #%s (%.0f%%) vs %s: ΔE %.1f < %.0f" % [
						ring, m, hex, share * 100.0, worm.to_html(false), de, need]).is_greater_equal(need)


func test_each_ring_keeps_its_dominant_hue() -> void:
	var dirt := _dominant(_shares("dirt"))
	var top := _dominant(_shares("topsoil"))
	assert_bool(dirt.r > dirt.g and dirt.g > dirt.b).override_failure_message("dirt not brown: %s" % dirt.to_html(false)).is_true()
	assert_bool(top.g > top.r and top.g > top.b).override_failure_message("topsoil not green: %s" % top.to_html(false)).is_true()


func test_grass_blades_stay_clear_of_both_worms() -> void:
	assert_int(LOOKS.grass.size()).is_equal(3)
	for c in LOOKS.grass:
		assert_float(DeltaE.de2000(P1, c)).is_greater_equal(SPECK_MIN)
		assert_float(DeltaE.de2000(P2, c)).is_greater_equal(MAIN_MIN)


func _dominant(shares: Dictionary) -> Color:
	var best := ""
	for k in shares:
		if best == "" or shares[k] > shares[best]:
			best = k
	return Color(best)
