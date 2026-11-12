## The look of Gulp (P1) and Burp (P2): every sprite of the worm heroes comes from here.
## The systems lane calls these and never draws worm art itself. Art lives in
## `assets/characters/<gulp|burp>/s<stage>/`, drawn per stage (sprite swap, never stretching).
##
##   segment_texture(player, stage, kind)  kind: head, body, tail (also band, tail_band: the
##                                         neutral-light diet stripe to modulate with flavour_tint)
##   face_texture(player, stage, mood)     overlay on the head sprite, same canvas and centre
##   feature_texture(stage, player = P1)   the stage feature (stage 3: Gulp's bow, Burp's cap), null
##                                         when the stage has none. Already drawn into that stage's
##                                         head texture: use this only for icons (tackle box, HUD)
##   flavour_tint(flavour)                 colour for the band sprite (`modulate`), white for &""
##
## Stages without their own art yet use the highest drawn stage. Unknown moods fall back to idle.
class_name WormLook
extends RefCounted

const ROOT := "res://assets/characters/"
const NAMES := ["gulp", "burp"]
const FLAVOURS_PATH := "res://data/look/flavours.tres"
## Stages that have their own sprite set.
const DRAWN_STAGES := 3
const KINDS: Array[StringName] = [&"head", &"body", &"tail", &"band", &"tail_band"]
const MOODS: Array[StringName] = [&"idle", &"ajar", &"open", &"chomp_1", &"chomp_2", &"chomp_3",
		&"squash", &"happy", &"worried", &"sleep"]
## Short names callers may use.
const MOOD_ALIAS := { &"chomp": &"chomp_1", &"boost": &"squash", &"asleep": &"sleep", &"wide": &"open" }
## The worm's three mouth states (closed / food near / food very near) as moods.
const MOUTH_MOODS: Array[StringName] = [&"idle", &"ajar", &"open"]
## Canvas size per stage: body/tail segment and head (the head canvas has room for the feature).
const SEGMENT_PX := [16, 16, 19, 22]
const HEAD_PX := [20, 20, 24, 32]

static var _cache := {}
static var _palette: Resource


static func segment_texture(player_id: int, stage: int, kind: StringName) -> Texture2D:
	if not kind in KINDS:
		push_warning("WormLook: unknown segment kind %s" % kind)
		kind = &"body"
	return _tex("%s/%s.png" % [_dir(player_id, stage), kind])


static func face_texture(player_id: int, stage: int, mood: StringName) -> Texture2D:
	return _tex("%s/face_%s.png" % [_dir(player_id, stage), mood_id(mood)])


static func feature_texture(stage: int, player_id := 0) -> Texture2D:
	var path := "%s/feature.png" % _dir(player_id, stage)
	return _tex(path) if ResourceLoader.exists(path) else null


static func flavour_tint(flavour_id: StringName) -> Color:
	if flavour_id == &"":
		return Color.WHITE
	if _palette == null:
		_palette = load(FLAVOURS_PATH)
	return _palette.call("tint", flavour_id)


## The face mood for the worm's mouth state 0..2.
static func mouth_mood(open_amt: int) -> StringName:
	return MOUTH_MOODS[clampi(open_amt, 0, MOUTH_MOODS.size() - 1)]


static func mood_id(mood: StringName) -> StringName:
	mood = MOOD_ALIAS.get(mood, mood)
	return mood if mood in MOODS else &"idle"


## Segment canvas size in px at a stage (spacing and collision can follow it).
static func segment_px(stage: int) -> int:
	return SEGMENT_PX[_stage(stage)]


static func head_px(stage: int) -> int:
	return HEAD_PX[_stage(stage)]


## Drop the texture cache (call when the last worm leaves, so nothing is held at exit).
static func clear_cache() -> void:
	_cache.clear()
	_palette = null


static func _stage(stage: int) -> int:
	return clampi(stage, 1, DRAWN_STAGES)


static func _dir(player_id: int, stage: int) -> String:
	return "%s%s/s%d" % [ROOT, NAMES[clampi(player_id, 0, 1)], _stage(stage)]


static func _tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
		if _cache[path] == null:
			push_error("WormLook: missing %s" % path)
	return _cache[path]
