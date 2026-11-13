## "That's why" for the heirloom (S-12): in a tin Old Reel made after a sun, the worm starts with a
## trait it never earned here. The moment it hatches, a picture bubble over it shows why: Reel's
## bait tin, then the trait that came out of it. Screen-sized and upright whatever the planet
## camera does; follows the head; fades after LIFE. No words.
class_name HeirloomBubble
extends Node2D

const LIFE := 5.0
const RISE := 70.0            # screen px above the head

var worm: Worm
var id: StringName
var _t := 0.0


static func show_over(w: Worm) -> HeirloomBubble:
	StoryPictures.register_all()   # bait_tin and trait:<id>
	var b := HeirloomBubble.new()
	b.worm = w
	b.id = OldReelTin.heirloom()
	b.z_index = 50
	var host: Node = w.get_parent() if w.get_parent() else w
	host.add_child(b)
	return b


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE or worm == null or not is_instance_valid(worm):
		queue_free()
		return
	var cam := get_viewport().get_camera_2d()
	global_position = worm.head.global_position
	if cam:
		global_rotation = cam.global_rotation
		scale = Vector2.ONE / cam.zoom
	queue_redraw()


func alpha() -> float:
	return clampf(minf(_t / 0.25, (LIFE - _t) / 0.6), 0.0, 1.0)


func _draw() -> void:
	var bob := sin(_t * 3.0) * 4.0
	PictoBubble.draw(self, Vector2(0, -RISE + bob), [&"bait_tin", StringName("trait:" + String(id)), &"face_happy"], alpha(), 1.6)
