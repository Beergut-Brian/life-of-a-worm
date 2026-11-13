## X-08: the planet's Jarling cameo spots in play. One child Node2D per CameoSpot (named
## `Cameo_<id>`, feet on the spot, turned so up is away from the core), from every hidden place's
## SecretData.cameos and the surface's SurfaceLife.cameos. An empty spot gets a bare marker: no
## drawing, no body, no carve, so it looks and plays like the ground round it. A filled spot
## (`jarling` set to an assets/characters/<id>/ folder with a pixel.png) stands that Jarling's
## pixel form there; a later cameo update only edits the data. Jarlings are never food: the stand
## is a picture, not a RingPickup.
class_name CameoStands
extends Node2D

const PIXEL := "res://assets/characters/%s/pixel.png"

## Spot id -> its marker node.
var spots := {}


## Builds the markers from `director`'s hidden places (at their carved centres) and its surface.
func setup(director: RingsDirector) -> void:
	for s in RingsDirector.SECRETS:
		var c: Vector2 = director.cities[s.id]
		for k in s.cameos:
			stand(k, c + SecretData.cameo_offset(k, c))
	for k in RingsDirector.SURFACE.cameos:
		stand(k, director.polar(k.angle, 1.0))


static func pixel_path(jarling: StringName) -> String:
	return PIXEL % jarling


## One marker for `k` with its feet at `at`; stands its Jarling when the spot names one.
func stand(k: CameoSpot, at: Vector2) -> Node2D:
	var n := Node2D.new()
	n.name = "Cameo_%s" % k.id
	n.position = at
	n.rotation = at.angle() + PI / 2.0
	add_child(n)
	spots[k.id] = n
	if k.is_empty() or not ResourceLoader.exists(pixel_path(k.jarling)):
		return n
	var tex: Texture2D = load(pixel_path(k.jarling))
	var sprite := Sprite2D.new()
	sprite.name = "Jarling"
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.offset = Vector2(0.0, -tex.get_size().y * 0.5)   # feet on the spot
	n.add_child(sprite)
	return n
