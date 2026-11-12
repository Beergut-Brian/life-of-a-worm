## STUB of WormLook (scripts/worm/worm_look.gd belongs to the worms-art lane). Same signatures,
## proto art from assets/proto/worm/, player colour baked in. WormHooks uses it only while the real
## file is missing; delete it once WormLook lands.
extends RefCounted

const ART := "res://assets/proto/worm/"
const KIND_FILE := { &"body": "segment.png", &"tail": "segment.png", &"band": "band.png", &"head": "head.png" }
const MOOD_OPEN := { &"idle": 0, &"sleep": 0, &"open": 1, &"wide": 2 }
const FEATURE_FILE := { 2: "feature_feelers.png" }

static var _cache := {}


static func segment_texture(player_id: int, _stage: int, kind: StringName) -> Texture2D:
	var key := "seg_%d_%s" % [player_id, kind]
	if not _cache.has(key):
		var src: Texture2D = load(ART + KIND_FILE.get(kind, "segment.png"))
		_cache[key] = src if kind == &"band" else _tinted(src, Players.COLOR[player_id])
	return _cache[key]


static func face_texture(player_id: int, _stage: int, mood: StringName) -> Texture2D:
	var key := "%sface_p%d_%d.png" % [ART, player_id + 1, MOOD_OPEN.get(mood, 0)]
	if not _cache.has(key):
		_cache[key] = load(key)
	return _cache[key]


static func feature_texture(stage: int) -> Texture2D:
	if not FEATURE_FILE.has(stage):
		return null
	var key := "feat_%d" % stage
	if not _cache.has(key):
		_cache[key] = load(ART + FEATURE_FILE[stage])
	return _cache[key]


static func flavour_tint(flavour_id: StringName) -> Color:
	return WormRules.default_rules().flavour_color(flavour_id, Color.WHITE)


static func clear_cache() -> void:
	_cache.clear()


static func _tinted(src: Texture2D, c: Color) -> Texture2D:
	var img := src.get_image()
	if img == null:
		return src
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			img.set_pixel(x, y, img.get_pixel(x, y) * c)
	return ImageTexture.create_from_image(img)
