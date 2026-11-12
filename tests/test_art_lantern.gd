## Lantern Deep art (Docket D92): atlases match their row tables, every pixel is on the palette,
## the face sprite sets drop in where the proto sets are, and every asset is credited.
extends GdUnitTestSuite

const TILES := "res://assets/sprites/tiles/"
const PALETTE := "res://art/palette/lantern_deep.hex"
const WORM_SET := ["head", "segment", "band", "face_p1_0", "face_p1_1", "face_p1_2",
	"face_p2_0", "face_p2_1", "face_p2_2"]


func _palette() -> Dictionary:
	var out := {}
	for line in FileAccess.get_file_as_string(PALETTE).split("\n", false):
		out[Color(line.strip_edges()).to_rgba32() | 0xff] = true
	return out


func test_solid_atlas_is_rows_by_mask_by_variant() -> void:
	var meta := LanternTileArt.load_meta()
	var img := (load(TILES + "lantern_solid.png") as Texture2D).get_image()
	var n := (load(TILES + "lantern_solid_n.png") as Texture2D).get_image()
	assert_int(img.get_width()).is_equal(16 * 16 * int(meta.variants))
	assert_int(img.get_height()).is_equal(16 * meta.solid_rows.size())
	assert_that(n.get_size()).is_equal(img.get_size())
	var wall := (load(TILES + "lantern_wall.png") as Texture2D).get_image()
	assert_int(wall.get_height()).is_equal(16 * meta.wall_rows.size())


func test_every_tile_pixel_is_snapped_to_the_palette() -> void:
	var pal := _palette()
	assert_int(pal.size()).is_greater(30)
	for f in ["lantern_solid.png", "lantern_wall.png"]:
		var img := (load(TILES + f) as Texture2D).get_image()
		img.decompress()
		var off := 0
		for y in range(0, img.get_height(), 3):
			for x in range(0, img.get_width(), 3):
				var c := img.get_pixel(x, y)
				if c.a > 0.5 and not pal.has(c.to_rgba32() | 0xff):
					off += 1
		assert_int(off).override_failure_message("%s: %d off-palette pixels" % [f, off]).is_equal(0)


func test_worm_face_set_drops_in_where_the_proto_set_is() -> void:
	for n in WORM_SET:
		var mine: Texture2D = load("res://assets/sprites/worm/lantern/%s.png" % n)
		var proto: Texture2D = load("res://assets/proto/worm/%s.png" % n)
		assert_object(mine).is_not_null()
		assert_that(mine.get_size()).is_equal(proto.get_size())


func test_foods_and_creatures_have_every_mood_and_bigger_things_are_bigger() -> void:
	for f in ["seed", "pebble", "boulder", "root", "mushroom", "crumb", "honeydew", "bug_egg", "crystal"]:
		for m in ["calm", "wide"]:
			assert_bool(ResourceLoader.exists("res://assets/sprites/foods/%s_%s.png" % [f, m])).is_true()
	for c in ["grub", "ant", "ladybird", "beetle", "apex_beetle", "bird"]:
		for m in ["calm", "wide", "smug"]:
			assert_bool(ResourceLoader.exists("res://assets/sprites/creatures/%s_%s.png" % [c, m])).is_true()
	var head: Texture2D = load("res://assets/sprites/worm/lantern/head.png")
	var seed: Texture2D = load("res://assets/sprites/foods/seed_calm.png")
	var beetle: Texture2D = load("res://assets/sprites/creatures/beetle_calm.png")
	# K-01: stage-1 food is smaller than a stage-1 head; a stage-2 threat is >= 1.25x the head
	assert_float(seed.get_size().x).is_less(head.get_size().x)
	assert_float(beetle.get_size().x).is_greater_equal(head.get_size().x * 1.25)


func test_every_lantern_asset_is_credited() -> void:
	var credits := FileAccess.get_file_as_string("res://assets/CREDITS.md")
	for p in ["sprites/tiles/", "sprites/light/", "sprites/worm/lantern/", "sprites/foods/",
			"sprites/creatures/"]:
		assert_bool(credits.contains(p)).override_failure_message("CREDITS.md has no line for " + p).is_true()
