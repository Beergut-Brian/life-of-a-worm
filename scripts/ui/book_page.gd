## One section's page in the collection book: the right-hand page of the spread, a grid of sketches,
## one per data entry, grey silhouette until found, then the picture. Rows scroll with the cursor
## when a section has more than fit; a little arrow says there is more. Drawn by the Book.
class_name BookPage
extends Control

## Which section this page shows (BookCatalog.SECTIONS).
@export var section: StringName = &"foods"
var book: Book


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## First grid row on screen, so the cursor's row is always visible.
func top_row() -> int:
	if book == null:
		return 0
	var cur_row := book.cursor / Book.COLS
	return maxi(0, cur_row - (Book.ROWS - 1))


func _draw() -> void:
	if book == null or book.section_id() != section:
		return
	Book.fit(self)
	var l: Array = book.entries.get(section, [])
	var lift := book.flip * 24.0
	var origin := Vector2(1080, 200 - lift)
	var cell := Vector2(190, 200)
	var top := top_row()
	var rows := ceili(l.size() / float(Book.COLS))
	if l.is_empty():
		# This build's data has nothing for this section yet: one dotted slot, no invented entries.
		_dotted(origin + Vector2(cell.x * 1.5, cell.y), 70.0)
	for i in l.size():
		var r := i / Book.COLS
		if r < top or r >= top + Book.ROWS:
			continue
		var c := origin + Vector2((i % Book.COLS) * cell.x, (r - top) * cell.y)
		var e: Dictionary = l[i]
		var got := book.is_found(section, e.id)
		if i == book.cursor:
			if not book.on_tabs:
				var pop := 1.0 + 0.15 * book.hop
				var shake := Vector2(sin(book.t * 60.0) * 8.0 * book.bump, 0)
				_ring(c + shake, (88.0 + 3.0 * sin(book.t * 6.0)) * pop, book.cursor_color(), 6.0)
			if book.look > 0.0:
				c += Vector2(sin(book.t * 50.0) * 7.0 * book.look, 0)
		BookArt.draw_entry(self, section, e, c, got, book.t, i)
	# More rows above or below: a pencil arrow at the page edge.
	if top > 0:
		_arrow(Vector2(1365, 120 - lift), -1)
	if top + Book.ROWS < rows:
		_arrow(Vector2(1365, 960 - lift), 1)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ring(c: Vector2, r: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for j in 41:
		var a := TAU * j / 40.0
		pts.append(c + Vector2.from_angle(a) * r * (1.0 + 0.04 * sin(a * 3.0 + 1.0)))
	draw_polyline(pts, col, w)


func _dotted(c: Vector2, r: float) -> void:
	for j in range(0, 40, 2):
		var a := TAU * j / 40.0
		draw_line(c + Vector2.from_angle(a) * r, c + Vector2.from_angle(a + TAU / 40.0) * r, Color(BookArt.PENCIL, 0.3), 3.0)


func _arrow(c: Vector2, dir: int) -> void:
	var d := float(dir)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-22, -10 * d), c + Vector2(22, -10 * d), c + Vector2(0, 14 * d)]),
		Color(BookArt.PENCIL, 0.6))
