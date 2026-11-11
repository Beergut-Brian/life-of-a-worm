## Old Reel's tackle box (Y): the collection book and the only in-game menu. Pictures only, no
## words or numbers. The lid holds one lure peg per page; a completed page pins its lure. Down the
## side, picture tabs: foods, creatures, traits, secrets, cutscenes. The open page is Reel's sketch
## paper with one doodle per entry: found ones drawn and coloured, the rest a dotted outline.
## Stick up / down turns the page, left / right picks a sketch, A on a cutscene plays it again (A on
## anything else wiggles the doodle), B or Y shuts the box. The game waits while it is open (the
## tree pauses; this layer always runs). Every press has a sound and a visual.
## Placeholder look in Reel's doodle style, drawn in code; Art lane replaces it after D92.
class_name TackleBox
extends CanvasLayer

signal opened(player: int)
signal closed()
## A cutscene was picked to watch again.
signal rewatch(id: StringName)

const COLS := 5
const PAPER := Color("f7efd9")
const PENCIL := Color("4a3a30")
const TIN := Color("3f6f5a")
const TIN_LIGHT := Color("5d9a7c")
const PAGE_COLORS := { &"foods": Color("f08a3c"), &"creatures": Color("e0483a"), &"traits": Color("5fd0e8"),
	&"secrets": Color("ffd23f"), &"cutscenes": Color("8a7be0") }
const SKIES := [Color("f6b98a"), Color("9fd0f0"), Color("8cc8f4"), Color("8cc8f4"), Color("f09a6a"), Color("e07a5a"), Color("26305a"), Color("1b2244")]
## Seconds after opening before input counts (the Y that opened it is not a close).
const GRACE := 0.2

var tlog: TackleLog
var player := -1
var page := 0
var cursor := 0
var is_open := false
## Pause the tree while open (off in tests that step frames by hand).
var pause_tree := true
var _root: Control
var _t := 0.0
var _opened_at := 0.0
var _wiggle := 0.0
var _flip := 0.0
var _pin := {}            # page -> seconds since its lure was pinned (the lure bounces in)


func _init() -> void:
	name = "TackleBox"
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_box)
	add_child(_root)
	visible = false
	if tlog:
		tlog.page_completed.connect(func(p: StringName) -> void: _pin[p] = 0.0)


func open(p: int) -> void:
	if is_open:
		return
	player = p
	is_open = true
	visible = true
	_opened_at = _t
	if tlog:
		tlog.sync_seen()
		tlog.fresh = 0
	cursor = clampi(cursor, 0, maxi(0, _list().size() - 1))
	if pause_tree and is_inside_tree():
		get_tree().paused = true
	Audio.play("box_open")
	opened.emit(p)


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if pause_tree and is_inside_tree():
		get_tree().paused = false
	Audio.play("box_close")
	closed.emit()


func page_id() -> StringName:
	return TackleLog.PAGES[page]


func _list() -> Array:
	return tlog.entries.get(page_id(), []) if tlog else []


## Stick: dy turns the page, dx moves the cursor along the sketches.
func nav(dx: int, dy: int) -> void:
	if dy != 0:
		page = wrapi(page + dy, 0, TackleLog.PAGES.size())
		cursor = clampi(cursor, 0, maxi(0, _list().size() - 1))
		_flip = 1.0
		Audio.play("box_flip")
	elif dx != 0:
		var n := _list().size()
		if n > 0:
			cursor = wrapi(cursor + dx, 0, n)
		_wiggle = 0.0
		Audio.play("box_tick")


## A: watch a found cutscene again; anything else wiggles its doodle.
func confirm() -> void:
	var list := _list()
	if list.is_empty():
		Audio.play("bonk")
		return
	var id: StringName = list[cursor]
	if page_id() == &"cutscenes" and tlog.is_found(&"cutscenes", id):
		Audio.play("box_play")
		close()
		rewatch.emit(id)
		return
	_wiggle = 0.5
	Audio.play("box_tick" if tlog.is_found(page_id(), id) else "boop")


func _process(delta: float) -> void:
	_t += delta
	_wiggle = maxf(0.0, _wiggle - delta)
	_flip = maxf(0.0, _flip - delta * 3.0)
	for p in _pin:
		_pin[p] += delta
	if not is_open:
		return
	_root.queue_redraw()
	if player < 0 or _t - _opened_at < GRACE:
		return
	if _pressed("jump") or _pressed("tackle"):
		close()
	elif _pressed("action"):
		confirm()
	elif _pressed("move_up"):
		nav(0, -1)
	elif _pressed("move_down"):
		nav(0, 1)
	elif _pressed("move_left"):
		nav(-1, 0)
	elif _pressed("move_right"):
		nav(1, 0)


func _pressed(a: String) -> bool:
	var act := Players.action(player, a)
	return InputMap.has_action(act) and Input.is_action_just_pressed(act)


# --- drawing --------------------------------------------------------------------------------------

func _draw_box() -> void:
	var k := _root.size.y / 1080.0
	var ox := (_root.size.x - 1920.0 * k) * 0.5
	_root.draw_set_transform(Vector2(ox, 0), 0.0, Vector2(k, k))
	_root.draw_rect(Rect2(-ox / k, 0, _root.size.x / k, 1080), Color(0.05, 0.04, 0.08, 0.6))
	# The tin and its lid.
	_root.draw_rect(Rect2(250, 236, 1420, 790), Color(0, 0, 0, 0.35))
	_root.draw_rect(Rect2(240, 226, 1420, 790), TIN)
	_root.draw_rect(Rect2(240, 226, 1420, 790), Color("223a30"), false, 6.0)
	_root.draw_rect(Rect2(240, 40, 1420, 170), TIN_LIGHT)
	_root.draw_rect(Rect2(240, 40, 1420, 170), Color("223a30"), false, 6.0)
	_draw_lures()
	_draw_tabs()
	_draw_page()
	# Shut: B (and Y) in the corner, picture of a closing lid.
	var sc := Vector2(1600, 960)
	UiStyle.draw_glyph(_root, sc, 52.0, "b")
	_root.draw_rect(Rect2(sc + Vector2(-110, -14), Vector2(56, 30)), TIN)
	_root.draw_rect(Rect2(sc + Vector2(-114, -26), Vector2(64, 12)), TIN_LIGHT)
	_root.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_lures() -> void:
	var n := TackleLog.PAGES.size()
	for i in n:
		var p: StringName = TackleLog.PAGES[i]
		var c := Vector2(400 + i * 280, 110)
		_root.draw_circle(c + Vector2(0, -40), 9.0, Color("c9b27a"))   # peg
		_root.draw_circle(c + Vector2(0, -40), 9.0, Color("223a30"), false, 2.0)
		if tlog and tlog.lures.has(p):
			var since: float = _pin.get(p, 9.0)
			var drop := maxf(0.0, 1.0 - since / 0.4) * -60.0
			var swing := sin(_t * 2.0 + i) * 0.12 + (sin(since * 18.0) * 0.5 * maxf(0.0, 1.0 - since) if since < 1.0 else 0.0)
			_draw_lure(c + Vector2(0, drop), swing, PAGE_COLORS[p])
		else:
			_doodle_ring(c + Vector2(0, 6), 30.0, Color(1, 1, 1, 0.25), i * 7, 2.0, true)


## A fishing lure hanging from its peg: line, a fish-shaped body in the page colour, eye, hook.
func _draw_lure(c: Vector2, swing: float, col: Color) -> void:
	var top := c + Vector2(0, -40)
	var body := top + Vector2(0, 62).rotated(swing)
	_root.draw_line(top, body + Vector2(0, -22).rotated(swing), Color(1, 1, 1, 0.7), 2.0)
	var pts := PackedVector2Array()
	for j in 16:
		var a := TAU * j / 16.0
		pts.append(body + Vector2(cos(a) * 16.0, sin(a) * 30.0).rotated(swing))
	_root.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	_root.draw_polyline(pts, PENCIL, 3.0)
	_root.draw_line(body + Vector2(-16, 0).rotated(swing), body + Vector2(16, 0).rotated(swing), Color(1, 1, 1, 0.6), 3.0)
	_root.draw_circle(body + Vector2(0, -14).rotated(swing), 5.0, Color.WHITE)
	_root.draw_circle(body + Vector2(0, -14).rotated(swing), 2.5, PENCIL)
	var hook := body + Vector2(0, 34).rotated(swing)
	_root.draw_arc(hook + Vector2(6, 6).rotated(swing), 7.0, PI * 0.0 + swing, PI * 1.2 + swing, 10, Color("c0c8d0"), 3.0)
	# Sparkle: it's a prize.
	var s := body + Vector2(20, -24).rotated(swing)
	var tw := 4.0 + 3.0 * absf(sin(_t * 3.0))
	_root.draw_line(s - Vector2(tw, 0), s + Vector2(tw, 0), Color(1, 1, 0.85), 2.0)
	_root.draw_line(s - Vector2(0, tw), s + Vector2(0, tw), Color(1, 1, 0.85), 2.0)


func _draw_tabs() -> void:
	for i in TackleLog.PAGES.size():
		var p: StringName = TackleLog.PAGES[i]
		var on := i == page
		var r := Rect2(268 + (14 if on else 0), 270 + i * 146, 150, 128)
		_root.draw_rect(r, PAPER if on else PAPER.darkened(0.25))
		_root.draw_rect(r, PENCIL, false, 3.0)
		if on:
			_root.draw_rect(Rect2(r.position + Vector2(r.size.x - 6, 0), Vector2(14, r.size.y)), PAPER)
		var col: Color = PAGE_COLORS[p]
		_tab_icon(r.get_center(), p, col)
		if tlog and tlog.lures.has(p):
			_root.draw_circle(r.position + Vector2(r.size.x - 22, 20), 9.0, col)
			_root.draw_circle(r.position + Vector2(r.size.x - 22, 20), 9.0, PENCIL, false, 2.0)


func _tab_icon(c: Vector2, p: StringName, col: Color) -> void:
	match p:
		&"foods":
			_food_doodle(c, 26.0, col, 3)
		&"creatures":
			_bug_doodle(c, 26.0, col)
		&"traits":
			_star(c, 30.0, col)
		&"secrets":
			_root.draw_circle(c + Vector2(0, -6), 14.0, col)
			_root.draw_circle(c + Vector2(0, -6), 14.0, PENCIL, false, 3.0)
			_root.draw_circle(c + Vector2(0, -6), 5.0, PENCIL)
			_root.draw_line(c + Vector2(0, 8), c + Vector2(0, 34), PENCIL, 5.0)
			_root.draw_line(c + Vector2(0, 26), c + Vector2(10, 26), PENCIL, 5.0)
		&"cutscenes":
			_dock_doodle(c, 36.0, 1, true, 1.0)


func _draw_page() -> void:
	var paper := Rect2(450, 262, 1180, 720)
	var lift := _flip * 30.0
	_root.draw_rect(Rect2(paper.position + Vector2(10, 10), paper.size), Color(0, 0, 0, 0.3))
	_root.draw_rect(Rect2(paper.position - Vector2(0, lift), paper.size), PAPER)
	for j in 11:   # faint ruled lines on Reel's paper
		var y := paper.position.y + 60 + j * 62 - lift
		_root.draw_line(Vector2(paper.position.x + 20, y), Vector2(paper.end.x - 20, y), Color(0.4, 0.55, 0.8, 0.12), 2.0)
	_root.draw_rect(Rect2(paper.position - Vector2(0, lift), paper.size), PENCIL, false, 3.0)
	var list := _list()
	var p := page_id()
	var cell := 216.0
	for i in list.size():
		var cx := paper.position.x + 130 + (i % COLS) * cell
		var cy := paper.position.y + 130 + (i / COLS) * 190 - lift
		var c := Vector2(cx, cy)
		var id: StringName = list[i]
		var got := tlog.is_found(p, id)
		if i == cursor:
			var col: Color = Players.COLOR[player] if player >= 0 else Color.WHITE
			_doodle_ring(c, 92.0 + 3.0 * sin(_t * 6.0), col, 99, 6.0, false)
			if _wiggle > 0.0:
				c += Vector2(sin(_t * 50.0) * 6.0 * _wiggle, 0)
		if got:
			_doodle(c, p, id, i)
		else:
			_doodle_ring(c, 58.0, Color(PENCIL, 0.35), i * 13, 3.0, true)
			PictoBubble.picture(_root, &"question", c, 50.0, 0.25)
		if p == &"cutscenes" and got and i == cursor:
			UiStyle.draw_glyph(_root, c + Vector2(70, 70), 46.0, "a")
	if tlog and tlog.is_complete(p):
		_draw_lure(Vector2(paper.end.x - 90, paper.position.y + 80 - lift), sin(_t) * 0.1, PAGE_COLORS[p])


# One sketch per entry.
func _doodle(c: Vector2, p: StringName, id: StringName, i: int) -> void:
	match p:
		&"foods":
			var f: FoodData = load("res://data/foods/%s.tres" % id) if ResourceLoader.exists("res://data/foods/%s.tres" % id) else null
			_food_doodle(c, 18.0 + (f.radius * 5.0 if f else 20.0), f.color if f else Color.WHITE, i)
		&"creatures":
			match id:
				&"ladybird":
					LadybirdLook.draw(_root, c, 44.0, -PI / 2.0 + sin(_t * 2.0) * 0.2, _t)
				&"mole":
					MoleLook.draw(_root, c + Vector2(0, 42), 4.2, MoleLook.Face.HAPPY, _t)
				_:
					_bug_doodle(c, 46.0, Color("3a3046") if id == &"beetle" else Color("8c6a4a"))
		&"traits":
			var t: TraitData = null
			for r in _traits():
				if r.id == id:
					t = r
			var col := t.color if t else Color.WHITE
			_scribble_disc(c, 52.0, col, i)
			var tex := t.part_texture(1) if t else null
			if tex:
				var s := 72.0 / maxf(tex.get_width(), tex.get_height())
				_root.draw_texture_rect(tex, Rect2(c - tex.get_size() * s * 0.5, tex.get_size() * s), false)
			else:
				_star(c, 30.0, Color.WHITE)
		&"secrets":
			if id == &"ant_city":
				_scribble_disc(c + Vector2(0, 20), 50.0, Color("b07a4a"), i)
				for a in 5:
					var ap := c + Vector2(-34 + a * 17, 30 + sin(_t * 4.0 + a) * 3.0)
					_root.draw_circle(ap, 5.0, PENCIL)
					_root.draw_circle(ap + Vector2(6, 0), 4.0, PENCIL)
				_root.draw_rect(Rect2(c + Vector2(-10, -16), Vector2(20, 16)), PENCIL)   # a door in the mound
			else:
				_star(c, 50.0, PAGE_COLORS[&"secrets"])
		&"cutscenes":
			_dock_doodle(c, 70.0, i, true, 1.0)


func _traits() -> Array:
	var out := []
	for f in ResourceLoader.list_directory("res://data/traits/"):
		if f.ends_with(".tres"):
			var r := load("res://data/traits/" + f)
			if r is TraitData:
				out.append(r)
	return out


## A pencil circle that wobbles like a hand-drawn one; dotted for things not found yet.
func _doodle_ring(c: Vector2, r: float, col: Color, seed_i: int, w: float, dotted: bool) -> void:
	var n := 40
	var pts := PackedVector2Array()
	for j in n + 1:
		var a := TAU * j / n
		var wob := 1.0 + 0.04 * sin(a * 3.0 + seed_i) + 0.03 * sin(a * 7.0 + seed_i * 2.0)
		pts.append(c + Vector2.from_angle(a) * r * wob)
	if dotted:
		for j in range(0, n, 2):
			_root.draw_line(pts[j], pts[j + 1], col, w)
	else:
		_root.draw_polyline(pts, col, w)


## Colour scribbled in (hatching), then a pencil outline: Reel colours inside the lines, mostly.
func _scribble_disc(c: Vector2, r: float, col: Color, seed_i: int) -> void:
	_root.draw_circle(c, r * 0.96, Color(col, 0.55))
	for j in 9:
		var y := -r * 0.8 + j * r * 0.2
		var hw := sqrt(maxf(0.0, r * r * 0.8 - y * y))
		_root.draw_line(c + Vector2(-hw, y + 6), c + Vector2(hw, y - 6), Color(col.darkened(0.15), 0.8), 4.0)
	_doodle_ring(c, r, PENCIL, seed_i, 3.0, false)


func _food_doodle(c: Vector2, r: float, col: Color, i: int) -> void:
	_scribble_disc(c, r, col, i)
	_root.draw_circle(c + Vector2(-r * 0.35, -r * 0.4), r * 0.18, Color(1, 1, 1, 0.8))
	for sx: float in [-1.0, 1.0]:
		_root.draw_circle(c + Vector2(sx * r * 0.35, -r * 0.05), maxf(2.0, r * 0.1), PENCIL)
	_root.draw_arc(c + Vector2(0, r * 0.15), r * 0.25, 0.2, PI - 0.2, 8, PENCIL, 2.0)


func _bug_doodle(c: Vector2, r: float, col: Color) -> void:
	for j in 3:
		for sx: float in [-1.0, 1.0]:
			var a := Vector2(sx * r * 0.7, -r * 0.3 + j * r * 0.35)
			_root.draw_line(c + a, c + a + Vector2(sx * r * 0.45, r * 0.15 + sin(_t * 8.0 + j) * 3.0), PENCIL, 3.0)
	_scribble_disc(c, r * 0.8, col, 5)
	_root.draw_circle(c + Vector2(0, -r * 0.85), r * 0.38, PENCIL)
	for sx: float in [-1.0, 1.0]:
		_root.draw_circle(c + Vector2(sx * r * 0.15, -r * 0.9), r * 0.1, Color.WHITE)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for j in 10:
		var a := -PI / 2.0 + TAU * j / 10.0
		pts.append(c + Vector2.from_angle(a) * (r if j % 2 == 0 else r * 0.45))
	_root.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	_root.draw_polyline(pts, PENCIL, 3.0)


## A tiny dock scene: sky in the scene's light, the pond, the dock with Reel's little hat.
func _dock_doodle(c: Vector2, r: float, i: int, framed: bool, a: float) -> void:
	var sky: Color = SKIES[clampi(i, 0, SKIES.size() - 1)]
	var box := Rect2(c - Vector2(r, r * 0.75), Vector2(r * 2.0, r * 1.5))
	_root.draw_rect(box, Color(sky, a))
	_root.draw_rect(Rect2(box.position + Vector2(0, box.size.y * 0.62), Vector2(box.size.x, box.size.y * 0.38)), Color(0.25, 0.45, 0.7, a))
	_root.draw_rect(Rect2(box.position + Vector2(box.size.x * 0.1, box.size.y * 0.55), Vector2(box.size.x * 0.5, box.size.y * 0.08)), Color(0.55, 0.38, 0.22, a))
	var hat := box.position + Vector2(box.size.x * 0.32, box.size.y * 0.42)
	_root.draw_rect(Rect2(hat - Vector2(r * 0.14, 0), Vector2(r * 0.28, r * 0.08)), Color(PENCIL, a))
	_root.draw_rect(Rect2(hat - Vector2(r * 0.08, r * 0.12), Vector2(r * 0.16, r * 0.12)), Color(PENCIL, a))
	if i >= 6:   # night: a moon
		_root.draw_circle(box.position + Vector2(box.size.x * 0.78, box.size.y * 0.25), r * 0.12, Color(1, 0.97, 0.8, a))
	else:
		_root.draw_circle(box.position + Vector2(box.size.x * 0.78, box.size.y * 0.25), r * 0.12, Color(1, 0.85, 0.3, a))
	if framed:
		_root.draw_rect(box, Color(PENCIL, a), false, 3.0)
