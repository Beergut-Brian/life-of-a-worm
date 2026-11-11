## The trophy bonus, shown on the worm: one charm per trophy family on the shelf, a bead per
## trophy up to the family's cap. Stones: grey studs down the back. Shinies: gold twinkles round
## the head. Snacks: leaves on the tail. Drawn over the worm, following its body.
class_name TrophyCharms
extends Node2D

var worm: Worm
var burrow: Burrow
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if worm == null or not is_instance_valid(worm):
		queue_free()
		return
	queue_redraw()


## World position of body point i (0 = head), clamped to the tail.
func _body(i: int) -> Vector2:
	var pts: Array[Vector2] = worm._positions
	if pts.is_empty():
		return worm.cam_position()
	return worm.position + pts[clampi(i, 0, pts.size() - 1)]


func _draw() -> void:
	if burrow == null or worm == null or not is_instance_valid(worm):
		return
	var counts := burrow.family_counts()
	var k := worm.size_factor()
	var n_body: int = worm._positions.size()
	for f in burrow.families:
		var n := mini(int(counts.get(f.id, 0)), f.cap)
		if n <= 0:
			continue
		match f.charm:
			&"studs":
				for i in n:
					var p := _body(1 + i)
					var up := p.normalized()
					var s := p + up * 4.5 * k
					draw_circle(s, 2.2 * k, Color("2a1a14"))
					draw_circle(s, 1.6 * k, f.color.lightened(0.15))
			&"twinkle":
				var h := _body(0)
				for i in n:
					var a := _t * 2.5 + TAU * i / n
					var s := h + Vector2.from_angle(a) * 9.0 * k
					var tw := (1.4 + 0.8 * absf(sin(_t * 6.0 + i))) * k
					draw_line(s - Vector2(tw, 0), s + Vector2(tw, 0), f.color, 1.0)
					draw_line(s - Vector2(0, tw), s + Vector2(0, tw), f.color, 1.0)
			&"leaf":
				var tail := _body(n_body - 1)
				var back := (tail - _body(n_body - 2)).normalized() if n_body > 1 else Vector2.LEFT
				for i in n:
					var dir := back.rotated((i - (n - 1) * 0.5) * 0.7 + sin(_t * 3.0 + i) * 0.15)
					var base := tail + back * 3.0 * k
					var tip := base + dir * 6.0 * k
					var side := dir.orthogonal() * 2.0 * k
					draw_colored_polygon(PackedVector2Array([base, (base + tip) * 0.5 + side, tip, (base + tip) * 0.5 - side]), f.color)
					draw_line(base, tip, f.color.darkened(0.35), 1.0)
