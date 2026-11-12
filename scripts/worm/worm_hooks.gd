## The one door from worm code to the two art lanes' APIs (the three Worm lanes' shared contract):
##   WormLook (scripts/worm/worm_look.gd, worms-art lane):
##     segment_texture(player_id, stage, kind)  kind: &"body", &"band", &"head", &"tail"
##     face_texture(player_id, stage, mood)      mood: &"idle", &"open", &"wide", &"sleep"
##     feature_texture(stage)                    the stage's feature sprite, or null
##     flavour_tint(flavour_id) -> Color         the diet-stripe tint
##   Juice (scripts/fx/juice.gd, rings-art lane):
##     chomp(pos, colour, size), shake(strength), stage_flash(), debris(pos)
## Order: an autoload node of that name, else the real script (static functions), else the stub in
## scripts/worm/stubs/ with the same signatures. Textures come finished (player colour baked in);
## the worm only tints the band with flavour_tint.
class_name WormHooks
extends RefCounted

const LOOK_PATH := "res://scripts/worm/worm_look.gd"
const JUICE_PATH := "res://scripts/fx/juice.gd"
const LOOK_STUB := "res://scripts/worm/stubs/worm_look_stub.gd"
const JUICE_STUB := "res://scripts/worm/stubs/juice_stub.gd"

static var _look: Object
static var _juice: Object


static func look() -> Object:
	if not is_instance_valid(_look):
		_look = _pick(&"WormLook", LOOK_PATH, LOOK_STUB)
	return _look


static func juice() -> Object:
	if not is_instance_valid(_juice):
		_juice = _pick(&"Juice", JUICE_PATH, JUICE_STUB)
	return _juice


## Drops the stubs' static caches and the cached APIs (the last worm calls it on exit).
static func release() -> void:
	for o in [_look, _juice]:
		if o is Script and (o as Script).resource_path in [LOOK_STUB, JUICE_STUB]:
			o.call(&"clear_cache")
	_look = null
	_juice = null


## True while a stub stands in (said in the report; the real files are other lanes').
static func look_is_stub() -> bool:
	return look() is Script and (look() as Script).resource_path == LOOK_STUB


static func juice_is_stub() -> bool:
	return juice() is Script and (juice() as Script).resource_path == JUICE_STUB


static func _pick(autoload: StringName, path: String, stub: String) -> Object:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null and tree.root.has_node(NodePath(String(autoload))):
		return tree.root.get_node(NodePath(String(autoload)))
	if ResourceLoader.exists(path):
		return load(path)
	return load(stub)
