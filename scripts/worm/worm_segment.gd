## One body segment on screen: the body sprite and its diet stripe. Both textures come from
## WormLook (through WormHooks); `flavour` tints the stripe with WormLook.flavour_tint (D-01).
## Setting `stage` swaps the sprite set. Parts (fins, sheen, the tail part) are added as children.
class_name WormSegment
extends Node2D

## Stage-1 segment width in pixels: art of any size is scaled to it, then by the stage size.
const BASE_PX := 16.0

var player := 0
var base: Sprite2D
var band: Sprite2D
var kind: StringName = &"body":
	set(v):
		kind = v
		_restyle()
var stage := 1:
	set(v):
		stage = v
		_restyle()
## The flavour this segment was grown from (&"" = plain, no stripe).
var flavour: StringName = &"":
	set(v):
		flavour = v
		_tint()


func _init(p_player := 0, p_stage := 1, p_flavour: StringName = &"", mat: Material = null) -> void:
	player = p_player
	base = Sprite2D.new()
	base.name = "Base"
	base.material = mat
	add_child(base)
	band = Sprite2D.new()
	band.name = "Band"
	band.material = mat
	add_child(band)
	stage = p_stage
	flavour = p_flavour


## The stripe colour on screen (transparent when plain).
func tint() -> Color:
	return band.modulate if band.visible else Color(1, 1, 1, 0)


func _restyle() -> void:
	if base == null:
		return
	var look := WormHooks.look()
	_set_tex(base, look.segment_texture(player, stage, kind))
	_set_tex(band, look.segment_texture(player, stage, &"band"))


func _tint() -> void:
	if band == null:
		return
	band.visible = flavour != &""
	band.modulate = WormHooks.look().flavour_tint(flavour) if band.visible else Color.WHITE


static func _set_tex(s: Sprite2D, tex: Texture2D) -> void:
	s.texture = tex
	var w := tex.get_width() if tex != null else 0
	s.scale = Vector2.ONE * (BASE_PX / w if w > 0 else 1.0)
