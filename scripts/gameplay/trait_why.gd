## The "why" picture over a worm that just earned a trait (no words): a row of little segments in
## each flavour the trait asks for (TraitData.requires: 4 grey stone beads for Stone head), an arrow,
## and the trait's own part (its first part texture, else a star in the trait's colour). The beads
## light up one by one, the part pops, then everything shrinks into the worm's head. Code-drawn
## placeholder, the final look is the Art lane's.
class_name TraitWhy
extends Node2D

var worm: Worm
var trait_data: TraitData
var rules: WormRules
var life := 1.8
var _t := 0.0


func _ready() -> void:
	z_index = 45
	_follow()


func _process(delta: float) -> void:
	_t += delta
	if _t >= life or not is_instance_valid(worm):
		queue_free()
		return
	_follow()
	queue_redraw()


## Flavour colours in the order the bubble draws them: [[colour, count], ...], sorted by flavour.
func recipe() -> Array:
	var out: Array = []
	if trait_data == null:
		return out
	var keys := trait_data.requires.keys()
	keys.sort()
	for f in keys:
		var c := rules.flavour_color(StringName(f), Color.WHITE) if rules != null else Color.WHITE
		out.append([c, int(trait_data.requires[f])])
	return out


func _follow() -> void:
	if not is_instance_valid(worm):
		return
	var head := worm.head_position()
	var up := head.normalized() if head.length() > 1.0 else Vector2.UP
	var k := clampf((_t - life * 0.7) / (life * 0.3), 0.0, 1.0)
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	var screen := clampf(0.5 / cam.zoom.x, 1.0, 3.0) if cam != null else 1.0
	position = head + up * lerpf(62.0 * worm.size_factor() * screen, 0.0, ease(k, 2.0))
	rotation = up.angle() + PI / 2.0
	scale = Vector2.ONE * lerpf(1.5, 0.2, k) * screen


func _draw() -> void:
	var s := ease(minf(1.0, _t / 0.15), -2.0)
	var col := trait_data.color if trait_data != null else Color.WHITE
	var ink := Color(0.2, 0.15, 0.1)
	var w := 76.0 * s
	var h := 40.0 * s
	draw_rect(Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h)), Color(1, 1, 1, 0.88))
	draw_rect(Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h)), col, false, 3.0)
	# the beads: every segment the trait needs, in its flavour, lighting up left to right
	var beads: Array[Color] = []
	for r in recipe():
		for i in int(r[1]):
			beads.append(r[0])
	var n := beads.size()
	var cols := ceili(n / 2.0) if n > 6 else n
	var step := 6.5 * s
	var lit := int(_t / 0.06)
	for i in n:
		var row := i / cols if cols > 0 else 0
		var x := -17.0 * s - step * (cols - 1) * 0.5 + step * (i % cols)
		var y := (0.0 if n <= 6 else (row - 0.5) * 8.0) * s + sin(_t * 10.0 + i) * s
		var on := i < lit
		draw_circle(Vector2(x, y), 3.2 * s, beads[i].darkened(0.3) if on else Color(0.8, 0.8, 0.8))
		draw_circle(Vector2(x, y), 2.5 * s, beads[i] if on else Color(0.9, 0.9, 0.9))
	# arrow
	draw_line(Vector2(4, 0) * s, Vector2(13, 0) * s, ink, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(16, 0) * s, Vector2(11, -4) * s, Vector2(11, 4) * s]), ink)
	# the trait's part, popping once every bead is lit
	var pop := clampf((_t - n * 0.06) / 0.2, 0.0, 1.0)
	var bounce := 1.0 + 0.2 * absf(sin(_t * 9.0)) * pop
	var at := Vector2(27, 0) * s
	draw_circle(at, 11.0 * s * pop * bounce, Color(col, 0.35))
	var tex: Texture2D = trait_data.part_textures[0] if trait_data != null and not trait_data.part_textures.is_empty() else null
	if tex != null and pop > 0.0:
		var size := Vector2(18, 18) * s * pop * bounce
		draw_texture_rect(tex, Rect2(at - size * 0.5, size), false)
	elif pop > 0.0:
		var pts := PackedVector2Array()
		for i in 10:
			var r := (8.0 if i % 2 == 0 else 3.5) * s * pop * bounce
			pts.append(at + Vector2.from_angle(-PI / 2.0 + i * TAU / 10.0) * r)
		draw_colored_polygon(pts, col)
