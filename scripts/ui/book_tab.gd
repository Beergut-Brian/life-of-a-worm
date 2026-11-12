## The book icon in the pause menu, beside Back to Open Jar: a little closed sketchbook with the Y
## glyph. Y while the pause menu is up (and no question or Settings is open) opens the collection
## book for whoever pressed it; the pause menu hides while the book is open and comes back on B.
## A new child of the pause menu's card: the pause menu's own buttons and script are untouched.
class_name BookTab
extends Control

@onready var book: Book = $Book
var _pm: Node
var _pop := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The pause menu joins its group in its own _ready, which runs after ours.
	_find_host.call_deferred()
	book.opened.connect(func(_p: int) -> void: _pop = 1.0)


func _find_host() -> void:
	_pm = _pause_menu()
	if _pm is CanvasItem:
		book.host = _pm


func _pause_menu() -> Node:
	var n := get_parent()
	while n and not n.is_in_group("openjar_pause_menu"):
		n = n.get_parent()
	return n


func _process(delta: float) -> void:
	_t += delta
	_pop = maxf(0.0, _pop - delta * 4.0)
	if is_visible_in_tree():
		queue_redraw()
	if book.is_open or not is_visible_in_tree() or Game.state != Game.State.PAUSED:
		return
	if _pm and _pm.has_method("in_submenu") and _pm.in_submenu():
		return
	for p in Players.active_players():
		var act := Players.action(p, "tackle")
		if InputMap.has_action(act) and Input.is_action_just_pressed(act):
			book.open(p)
			return


func _draw() -> void:
	var c := size * 0.5 + Vector2(0, -10)
	var k := 1.0 + 0.2 * _pop + 0.03 * sin(_t * 3.0)
	draw_set_transform(c, -0.08, Vector2(k, k))
	var cover := Rect2(-62, -78, 124, 150)
	draw_rect(Rect2(cover.position + Vector2(8, 8), cover.size), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(cover.position + Vector2(10, 4), cover.size - Vector2(10, 8)), BookArt.PAPER)   # page edges
	draw_rect(cover, Book.COVER)
	draw_rect(cover, BookArt.PAPER, false, 4.0)
	draw_rect(Rect2(cover.position, Vector2(18, cover.size.y)), Book.COVER.darkened(0.3))
	# A doodle of a worm on the cover.
	var pts := PackedVector2Array()
	for j in 8:
		pts.append(Vector2(-34 + j * 10, -6 + sin(j * 0.9 + _t * 3.0) * 8.0))
	draw_polyline(pts, Color("f2a0a8"), 14.0)
	draw_circle(pts[pts.size() - 1], 3.0, BookArt.PENCIL)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	UiStyle.draw_glyph(self, c + Vector2(64, 74), 54.0, "y")
