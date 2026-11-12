## The collection book (T-01), opened from the pause menu (Y on the book icon next to Back to Open
## Jar). An open sketchbook: the left page is the five section tabs, each with a row of slots that
## fill as things are found (the count as a picture, no numbers); the right page is the open
## section's grid, one sketch per data entry, grey silhouette until found, then the picture.
##
## The stick moves one cursor one cell per push, and only the cursor: the tree stays paused while the
## book is open, so no worm moves. Left off the grid's first column steps onto the tabs; up / down
## there turns to another section; right goes back to the grid. A looks closer (the sketch wiggles),
## B or Y shuts the book. Every press has a sound and a visual; a push against an edge bumps.
class_name Book
extends CanvasLayer

signal opened(player: int)
signal closed()
## The cursor moved (on_tabs = true when it sits on the section tabs).
signal moved(section: StringName, cursor: int, on_tabs: bool)

const COLS := 4
const ROWS := 4
const PAPER := BookArt.PAPER
const PENCIL := BookArt.PENCIL
const COVER := Color("2f5d4a")

## section -> Array[Dictionary] (BookCatalog.entries), loaded once.
var entries := {}
## section -> Array[StringName] found, refreshed on every open.
var found := {}
var section := 0
var cursor := 0
var on_tabs := false
var is_open := false
var player := -1
## Hidden while the book is open and shown again on close (the pause menu).
var host: CanvasItem
## Pause the tree while open (it already is under the pause menu; this keeps it so from anywhere).
var pause_tree := true
var t := 0.0
## Visual timers: flip (page lift), hop (cursor pop), bump (edge shake), look (A wiggle).
var flip := 0.0
var hop := 0.0
var bump := 0.0
var look := 0.0
var _was_paused := false
var _host_was_visible := false
var _open_frame := -1

@onready var _spread: Control = $Spread
var _pages: Array[BookPage] = []


func _init() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	entries = BookCatalog.all()
	for s in BookCatalog.SECTIONS:
		found[s] = [] as Array[StringName]
	_spread.draw.connect(_draw_spread)
	for n in $Pages.get_children():
		if n is BookPage:
			n.book = self
			_pages.append(n)
	visible = false
	Game.state_changed.connect(_on_game_state)


func section_id() -> StringName:
	return BookCatalog.SECTIONS[section]


func list() -> Array:
	return entries.get(section_id(), [])


func is_found(s: StringName, id: StringName) -> bool:
	return (found.get(s, []) as Array).has(id)


func open(p: int) -> void:
	if is_open:
		return
	player = p
	is_open = true
	_open_frame = Engine.get_process_frames()
	found = BookCatalog.found_set(get_tree() if is_inside_tree() else null)
	cursor = clampi(cursor, 0, maxi(0, list().size() - 1))
	if host:
		_host_was_visible = host.visible
		host.visible = false
	if pause_tree and is_inside_tree():
		_was_paused = get_tree().paused
		get_tree().paused = true
	visible = true
	flip = 1.0
	Audio.play("book_open")
	opened.emit(p)


## restore = false when Start resumed the game under us: leave the pause state and the host to Game.
func close(restore := true) -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if restore:
		if host:
			host.visible = _host_was_visible
		if pause_tree and is_inside_tree():
			get_tree().paused = _was_paused
		Audio.play("book_close")
	closed.emit()


## One push of the stick. Moves the cursor one step, never more; an edge bumps.
func nav(dx: int, dy: int) -> void:
	if not is_open:
		return
	var n := list().size()
	if on_tabs:
		if dy != 0:
			var to := section + dy
			if to < 0 or to >= BookCatalog.SECTIONS.size():
				_bump()
				return
			section = to
			cursor = 0
			flip = 1.0
			Audio.play("book_flip")
		elif dx > 0 and n > 0:
			on_tabs = false
			_hop("book_tick")
		elif dx != 0:
			_bump()
			return
	else:
		var col := cursor % COLS
		if dx < 0 and col == 0:
			on_tabs = true
			_hop("book_tick")
		elif dx != 0:
			var to := cursor + dx
			if to < 0 or to >= n or (dx > 0 and col == COLS - 1):
				_bump()
				return
			cursor = to
			_hop("book_tick")
		elif dy != 0:
			var to := cursor + dy * COLS
			if to < 0 or to >= n:
				_bump()
				return
			cursor = to
			_hop("book_tick")
	moved.emit(section_id(), cursor, on_tabs)


## A: on the tabs, step into the grid; on a sketch, look closer (it wiggles).
func confirm() -> void:
	if not is_open:
		return
	if on_tabs:
		if list().is_empty():
			_bump()
			return
		on_tabs = false
		_hop("book_tick")
		return
	var l := list()
	if l.is_empty():
		_bump()
		return
	look = 0.6
	Audio.play("book_look" if is_found(section_id(), l[cursor].id) else "boop")


func _hop(cue: String) -> void:
	hop = 1.0
	Audio.play(cue)


func _bump() -> void:
	bump = 1.0
	Audio.play("bonk")


func _on_game_state(_from: int, to: int) -> void:
	if is_open and host and to != Game.State.PAUSED:
		close(false)


func _process(delta: float) -> void:
	t += delta
	flip = maxf(0.0, flip - delta * 3.0)
	hop = maxf(0.0, hop - delta * 5.0)
	bump = maxf(0.0, bump - delta * 4.0)
	look = maxf(0.0, look - delta)
	if not is_open:
		return
	_spread.queue_redraw()
	for pg in _pages:
		pg.visible = pg.section == section_id()
		if pg.visible:
			pg.queue_redraw()
	if Engine.get_process_frames() == _open_frame:
		return   # the Y that opened the book is not also its close
	var input := MenuInput.read()
	if input.b != -1 or _tackle_pressed():
		close()
	elif input.a != -1:
		confirm()
	elif input.move != Vector2i.ZERO:
		# One axis per push: a diagonal is read as its sideways part.
		if input.move.x != 0:
			nav(input.move.x, 0)
		else:
			nav(0, input.move.y)


func _tackle_pressed() -> bool:
	for p in Players.active_players():
		var act := Players.action(p, "tackle")
		if InputMap.has_action(act) and Input.is_action_just_pressed(act):
			return true
	return false


func cursor_color() -> Color:
	return Players.COLOR.get(player, Color.WHITE)


## Draw in a 1920x1080 frame centred in whatever the control's size is. Returns the scale.
static func fit(ci: Control) -> float:
	var k := ci.size.y / 1080.0
	ci.draw_set_transform(Vector2((ci.size.x - 1920.0 * k) * 0.5, 0), 0.0, Vector2(k, k))
	return k


# --- the spread and the left page (tabs + slot counters) ------------------------------------------

func _draw_spread() -> void:
	var ci := _spread
	var k := fit(ci)
	var ox := (ci.size.x - 1920.0 * k) * 0.5 / k
	ci.draw_rect(Rect2(-ox, 0, ci.size.x / k, 1080), Color(0.05, 0.04, 0.08, 0.78))
	# Cover peeking out round the pages, then the two pages and the spine.
	ci.draw_rect(Rect2(150, 70, 1640, 960), Color(0, 0, 0, 0.35))
	ci.draw_rect(Rect2(130, 50, 1660, 960), COVER)
	ci.draw_rect(Rect2(130, 50, 1660, 960), COVER.darkened(0.4), false, 6.0)
	var lift := flip * 24.0
	ci.draw_rect(Rect2(160, 80, 790, 900), PAPER.darkened(0.04))
	ci.draw_rect(Rect2(970, 80 - lift, 790, 900), PAPER)
	for j in 13:   # ruled lines on the left page
		ci.draw_line(Vector2(180, 140 + j * 64), Vector2(930, 140 + j * 64), Color(0.4, 0.55, 0.8, 0.12), 2.0)
	ci.draw_rect(Rect2(950, 70, 20, 920), COVER.darkened(0.25))
	for j in 9:   # stitches on the spine
		ci.draw_line(Vector2(960, 100 + j * 104), Vector2(960, 130 + j * 104), PAPER.darkened(0.3), 3.0)
	for i in BookCatalog.SECTIONS.size():
		_draw_tab(ci, i)
	# Shut: B in the corner, beside a picture of a closing book.
	var sc := Vector2(1700, 950)
	UiStyle.draw_glyph(ci, sc, 52.0, "b")
	ci.draw_rect(Rect2(sc + Vector2(-112, -22), Vector2(52, 44)), COVER)
	ci.draw_rect(Rect2(sc + Vector2(-112, -22), Vector2(52, 44)), PAPER, false, 3.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_tab(ci: Control, i: int) -> void:
	var s: StringName = BookCatalog.SECTIONS[i]
	var here := i == section
	var row := Rect2(190, 110 + i * 172, 730, 150)
	var col: Color = BookArt.SECTION_COLORS[s]
	if here:
		ci.draw_rect(row, Color(col, 0.22))
		# A ribbon bookmark from this row across to the open page.
		ci.draw_rect(Rect2(row.end.x - 10, row.position.y + 50, 80, 50), col)
	var ic := row.position + Vector2(80, 75)
	if here and on_tabs:
		var pop := 1.0 + 0.15 * hop
		var shake := Vector2(sin(t * 60.0) * 8.0 * bump, 0)
		_ring(ci, ic + shake, (70.0 + 3.0 * sin(t * 6.0)) * pop, cursor_color(), 6.0)
	BookArt.tab_icon(ci, s, ic, t)
	# The counter: one slot per entry, filled in the section's colour when found.
	var l: Array = entries.get(s, [])
	var have: Array = found.get(s, [])
	var x0 := row.position.x + 170
	var per := clampi(l.size(), 1, 14)
	var gap := minf(40.0, 540.0 / per)
	for j in l.size():
		var p := Vector2(x0 + (j % 14) * gap, row.position.y + 55 + (j / 14) * 40)
		var got := have.has(l[j].id)
		if got:
			ci.draw_circle(p, gap * 0.36, col)
		ci.draw_circle(p, gap * 0.36, PENCIL if got else Color(PENCIL, 0.35), false, 3.0)
	if l.is_empty():
		# No data for this section on this build: an empty dotted box, not a made-up page.
		_ring(ci, Vector2(x0 + 30, row.position.y + 55), 18.0, Color(PENCIL, 0.3), 2.0, true)
	elif BookCatalog.count(l, have) == l.size():
		BookArt.star(ci, Vector2(row.end.x - 50, row.position.y + 40), 22.0, col, true)


func _ring(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float, dotted := false) -> void:
	var n := 40
	var pts := PackedVector2Array()
	for j in n + 1:
		var a := TAU * j / n
		pts.append(c + Vector2.from_angle(a) * r * (1.0 + 0.04 * sin(a * 3.0) + 0.03 * sin(a * 7.0)))
	if dotted:
		for j in range(0, n, 2):
			ci.draw_line(pts[j], pts[j + 1], col, w)
	else:
		ci.draw_polyline(pts, col, w)
