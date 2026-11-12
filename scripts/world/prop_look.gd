## Placeholder looks for surface props (PropData.look): which footprint cells SurfaceProp draws with
## lantern tiles, and the simple marks drawn on top (doors, wheels, spots). Shapes only, no text,
## no new art: the art round replaces this. Cells count x from the left, y from the top (y = 0 is
## the row furthest from the core).
class_name PropLook
extends RefCounted

const INK := Color("2a1a14")
const CS := 16.0
const GLASS := Color("bfe6f0")
const WARM := Color("f6d77a")
const DARK := Color("3a2a22")
const WATER := Color("3f6f8f")
const RED := Color("d8443a")
const WHITE := Color("f4efe4")
const ORANGE := Color("e8862a")


## True when this footprint cell is drawn (the rest of the footprint is see-through).
static func filled(look: StringName, size: Vector2i, x: int, y: int) -> bool:
	var bottom := y == size.y - 1
	match look:
		&"tree":   # canopy rows on a one-tile trunk
			return y < size.y - 2 or x == size.x / 2
		&"fence":  # posts every other tile; the rails are marks
			return x % 2 == 0
		&"car":    # body along the bottom, cabin in the middle
			return bottom or (x > 0 and x < size.x - 1)
		&"hill":   # a mound: each row up is a tile narrower at both ends
			var inset := size.y - 1 - y
			return x >= inset * 2 and x < size.x - inset * 2
		&"water_tower":   # tank on two legs
			return y < size.y - 3 or x == 0 or x == size.x - 1
		&"court":  # slab and one hoop pole at the right
			return bottom or x == size.x - 1
		&"dock_shed":     # the shed on the left, the jetty out over the water on the right
			return x < size.x - 2 or bottom
	return true


## The tile row name for this cell (top_tile for the top rows).
static func tile_of(d: PropData, y: int) -> StringName:
	if d.top_tile != &"" and y < d.top_rows:
		return d.top_tile
	return d.tile


## Draws the marks for the look inside r (the footprint rect, bottom centre at the origin).
static func draw_marks(ci: CanvasItem, d: PropData, r: Rect2) -> void:
	var s := d.size
	var c := func(x: float, y: float) -> Vector2: return r.position + Vector2(x, y) * CS
	match d.look:
		&"crate":
			ci.draw_line(r.position + Vector2(2, 2), r.end - Vector2(2, 2), Color(INK, 0.55), 2.0)
			ci.draw_line(Vector2(r.position.x + 2, r.end.y - 2), Vector2(r.end.x - 2, r.position.y + 2), Color(INK, 0.55), 2.0)
		&"tree":
			for p in [Vector2(0.7, 0.9), Vector2(2.2, 1.6), Vector2(1.4, 2.3)]:
				_dot(ci, c.call(p.x, p.y), 3.5, RED)
		&"fence":
			for fy in [0.6, 1.4]:
				var a: Vector2 = c.call(0.0, fy)
				var rail := Rect2(a, Vector2(r.size.x, 5.0))
				ci.draw_rect(rail.grow(1.0), INK)
				ci.draw_rect(rail, Color("b07a50"))
		&"house":
			_window(ci, Rect2(c.call(0.5, 1.4), Vector2(14, 12)))
			_window(ci, Rect2(c.call(s.x - 1.4, 1.4), Vector2(14, 12)))
			var door := Rect2(c.call(s.x * 0.5 - 0.45, s.y - 1.6), Vector2(15, 1.6 * CS))
			ci.draw_rect(door.grow(1.0), INK)
			ci.draw_rect(door, DARK)
			_dot(ci, door.position + Vector2(11, 14), 1.5, WARM)
		&"car":
			_window(ci, Rect2(c.call(1.2, 0.25), Vector2((s.x - 2.4) * CS, 9)))
			for wx in [0.8, s.x - 0.8]:
				_dot(ci, c.call(wx, s.y), 6.0, INK)
				_dot(ci, c.call(wx, s.y), 2.5, Color("9aa0a8"))
		&"cow":
			for p in [Vector2(0.6, 0.6), Vector2(1.6, 1.2), Vector2(2.3, 0.5)]:
				_dot(ci, c.call(p.x, p.y), 5.0, INK)
			var head: Vector2 = c.call(s.x - 0.3, 0.6)
			_dot(ci, head + Vector2(-2, -1), 2.0, INK)               # an eye
			_dot(ci, head + Vector2(1, 7), 3.5, Color("f2a7a0"))      # a pink nose
			ci.draw_line(head + Vector2(-5, -9), head + Vector2(-2, -13), WHITE, 2.0)   # a horn
		&"hill":
			for p in [Vector2(s.x * 0.35, s.y - 1.4), Vector2(s.x * 0.6, s.y - 0.9)]:
				_dot(ci, c.call(p.x, p.y), 2.5, WARM)
		&"water_tower":
			var top := s.y - 3
			for k in 2:
				ci.draw_line(c.call(1.0, top + k * 1.5), c.call(s.x - 1.0, top + 1.5 + k * 1.5), Color(INK, 0.8), 2.0)
				ci.draw_line(c.call(s.x - 1.0, top + k * 1.5), c.call(1.0, top + 1.5 + k * 1.5), Color(INK, 0.8), 2.0)
			_drop(ci, c.call(s.x * 0.5, top * 0.55), 7.0)
		&"diner":
			for k in 2:
				_window(ci, Rect2(c.call(0.4 + k * 1.7, 1.3), Vector2(1.4 * CS, 11)))
			var door := Rect2(c.call(s.x - 1.6, s.y - 1.7), Vector2(15, 1.7 * CS))
			ci.draw_rect(door.grow(1.0), INK)
			ci.draw_rect(door, GLASS)
			# a cup on the roof stripe instead of a sign
			var cup := Rect2(c.call(s.x * 0.5 - 0.3, 0.2), Vector2(10, 9))
			ci.draw_rect(cup.grow(1.0), INK)
			ci.draw_rect(cup, WHITE)
			ci.draw_arc(cup.position + Vector2(11, 4.5), 3.0, -PI / 2, PI / 2, 8, INK, 2.0)
		&"court":
			var slab := Rect2(c.call(0, s.y - 1), Vector2(r.size.x - CS, CS))
			ci.draw_line(slab.position + Vector2(0, 8), slab.end - Vector2(0, 8), WHITE, 1.5)
			ci.draw_line(Vector2(slab.get_center().x, slab.position.y + 2), Vector2(slab.get_center().x, slab.end.y - 2), WHITE, 1.5)
			var board := Rect2(c.call(s.x - 1.8, 0.4), Vector2(14, 12))
			ci.draw_rect(board.grow(1.0), INK)
			ci.draw_rect(board, WHITE)
			ci.draw_line(board.position + Vector2(-8, 15), board.position + Vector2(4, 15), ORANGE, 3.0)   # the hoop
			_dot(ci, c.call(1.6, s.y - 1.4), 5.0, ORANGE)   # a ball on the court
		&"dock_shed":
			var shed_w := s.x - 2
			var door := Rect2(c.call(shed_w * 0.5 - 0.45, s.y - 1.6), Vector2(14, 1.6 * CS))
			ci.draw_rect(door.grow(1.0), INK)
			ci.draw_rect(door, DARK)
			var pond := Rect2(c.call(shed_w, s.y - 0.45), Vector2(2 * CS, 0.45 * CS))
			ci.draw_rect(pond, WATER)
			for k in 4:   # jetty planks
				var x: Vector2 = c.call(shed_w + 0.5 * k, s.y - 1)
				ci.draw_line(x, x + Vector2(0, CS * 0.55), Color(INK, 0.6), 1.5)
			_dot(ci, c.call(s.x - 0.4, s.y - 1.2), 3.0, RED)   # a bobber by the jetty


static func _dot(ci: CanvasItem, at: Vector2, rad: float, col: Color) -> void:
	ci.draw_circle(at, rad + 1.0, INK)
	ci.draw_circle(at, rad, col)


static func _window(ci: CanvasItem, rect: Rect2) -> void:
	ci.draw_rect(rect.grow(1.5), INK)
	ci.draw_rect(rect, GLASS)


static func _drop(ci: CanvasItem, at: Vector2, rad: float) -> void:
	var pts := PackedVector2Array([at + Vector2(0, -rad * 1.6)])
	for i in 9:
		var a := PI * float(i) / 8.0
		pts.append(at + Vector2(cos(a) * rad, sin(a) * rad))
	ci.draw_colored_polygon(pts, Color("6fb3e0"))
	pts.append(pts[0])
	ci.draw_polyline(pts, INK, 1.5)
