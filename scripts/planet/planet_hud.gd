## Gameplay HUD, text-free: the context hint panel (controller glyph + a little picture per action),
## an edge arrow in a worm's colour when it is off screen, a growing worm icon for each worm's
## stage (no numbers), and the stage-up white flash. The level feeds it each frame.
class_name PlanetHud
extends CanvasLayer

## Rows the panel can show: [glyph token, picture, hold?]. Context picks which.
const MOVE := ["stick", "worm", false]
const BURST := ["a", "zip", false]
const WIGGLE := ["b", "notes", false]
const HOME := ["b", "home", true]
const CARRY := ["x", "mouth", false]
const BOX := ["y", "box", false]
const WALL := ["y", "wall", false]
const DROP := ["x", "drop", false]
const SWAP := ["a", "swap", false]

var level: Node
var rows: Array = []
## Row pictures that are "ready" right now (drawn bright with a pulse).
var hot: Dictionary = {}
var _root: Control
var _flash: ColorRect
var _flash_frames := 0
var _t := 0.0
var _icon_stage := {}   # player -> stage the icon shows
var _icon_pulse := {}   # player -> seconds of pop left


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_hud)
	add_child(_root)
	_flash = ColorRect.new()
	_flash.color = Color.WHITE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.visible = false
	add_child(_flash)


## Two frames of white (the stage-up).
func flash() -> void:
	_flash_frames = 2
	_flash.visible = true


## The level calls this each frame with what is possible now.
func set_context(carry_ready: bool, has_home: bool, in_burrow: bool) -> void:
	rows = [MOVE, BURST, WIGGLE]
	if carry_ready:
		rows.append(CARRY)
	if has_home:
		rows.append(HOME)
	rows.append(WALL if in_burrow else BOX)
	hot = { "mouth": carry_ready, "wall": in_burrow }


## The home slice's context (HomeSlice, each frame after the level): carry_ready, carrying,
## has_home, wall (asleep in the bed), swap (at the Mole with something to swap), box_new.
func set_rows(ctx: Dictionary) -> void:
	rows = [MOVE, BURST, WIGGLE]
	if ctx.get("swap", false):
		rows.append(SWAP)
	if ctx.get("carrying", false):
		rows.append(DROP)
	elif ctx.get("carry_ready", false):
		rows.append(CARRY)
	if ctx.get("has_home", false):
		rows.append(HOME)
	rows.append(WALL if ctx.get("wall", false) else BOX)   # asleep in the bed, Y is the wall
	hot = { "mouth": ctx.get("carry_ready", false), "drop": ctx.get("carrying", false),
		"swap": ctx.get("swap", false), "wall": ctx.get("wall", false), "box": ctx.get("box_new", false) }


func _process(delta: float) -> void:
	_t += delta
	_track_icons(delta)
	if _flash_frames > 0:
		_flash_frames -= 1
		if _flash_frames == 0:
			_flash.visible = false
	_root.queue_redraw()


func _draw_hud() -> void:
	var view := _root.size
	_draw_panel(view)
	if level == null:
		return
	var cam: PolarCamera = level.camera
	var i := 0
	for w in Worm.all():
		_draw_stage_icon(Vector2(80 + i * ICON_GAP, 80), w)
		if cam and not cam.sees(w.cam_position(), 30.0):
			_draw_edge_arrow(view, cam, w)
		i += 1


func _draw_panel(view: Vector2) -> void:
	if rows.is_empty():
		return
	var h := 58.0
	var w := 150.0
	var r := Rect2(view.x - w - 40.0, view.y - 40.0 - h * rows.size() - 12.0, w, h * rows.size() + 12.0)
	_root.draw_rect(r, Color(0.08, 0.06, 0.1, 0.55))
	for k in rows.size():
		var row: Array = rows[k]
		var cy := r.position.y + 6.0 + h * k + h * 0.5
		var lit: bool = hot.get(row[1], false)
		var a := 1.0 if lit else 0.8
		if lit:
			a = 0.65 + 0.35 * absf(sin(_t * 5.0))
			_root.draw_rect(Rect2(r.position.x + 4, cy - h * 0.45, w - 8, h * 0.9), Color(1, 1, 1, 0.12))
		UiStyle.draw_glyph(_root, Vector2(r.position.x + 36.0, cy), 40.0, row[0], a)
		if row[2]:   # hold: a ring round the glyph
			_root.draw_arc(Vector2(r.position.x + 36.0, cy), 25.0, -PI / 2, -PI / 2 + TAU * fmod(_t * 0.5, 1.0), 24, Color(1, 1, 1, 0.7), 3.0)
		_draw_picture(Vector2(r.position.x + 105.0, cy), row[1], a)


## Tiny placeholder pictures, one per action (Art lane replaces with icons; names in the report).
func _draw_picture(c: Vector2, what: String, a: float) -> void:
	var ink := Color(1, 0.96, 0.9, a)
	var green: Color = Players.COLOR[Players.P1]
	green.a = a
	match what:
		"worm":
			for k in 4:
				_root.draw_circle(c + Vector2(-15 + k * 9, sin(_t * 4.0 + k) * 3.0), 7.0 if k == 3 else 6.0, green)
		"zip":
			for k in 3:
				_root.draw_line(c + Vector2(-22, -8 + k * 8), c + Vector2(6 - k * 6, -8 + k * 8), ink, 3.0)
			_root.draw_circle(c + Vector2(14, 0), 8.0, green)
		"notes":
			_root.draw_circle(c + Vector2(-8, 8), 5.0, ink)
			_root.draw_line(c + Vector2(-4, 8), c + Vector2(-4, -12), ink, 3.0)
			_root.draw_circle(c + Vector2(10, 4), 5.0, ink)
			_root.draw_line(c + Vector2(14, 4), c + Vector2(14, -14), ink, 3.0)
			_root.draw_line(c + Vector2(-4, -12), c + Vector2(14, -14), ink, 3.0)
		"home":
			_root.draw_colored_polygon(PackedVector2Array([c + Vector2(-18, -2), c + Vector2(0, -18), c + Vector2(18, -2)]), ink)
			_root.draw_rect(Rect2(c + Vector2(-13, -2), Vector2(26, 18)), ink)
			_root.draw_rect(Rect2(c + Vector2(-4, 6), Vector2(8, 10)), Color(0.2, 0.15, 0.1, a))
		"mouth":
			_root.draw_circle(c + Vector2(-4, 0), 13.0, green)
			_root.draw_circle(c + Vector2(6, 0), 6.0, Color(0.15, 0.05, 0.05, a))
			_root.draw_circle(c + Vector2(12, 0), 5.0, Color(1, 0.62, 0.11, a))
		"box":
			_root.draw_rect(Rect2(c + Vector2(-18, -8), Vector2(36, 22)), Color(0.35, 0.55, 0.4, a))
			_root.draw_rect(Rect2(c + Vector2(-18, -14), Vector2(36, 8)), Color(0.45, 0.7, 0.5, a))
			_root.draw_rect(Rect2(c + Vector2(-4, -4), Vector2(8, 6)), ink)
		"drop":
			_root.draw_circle(c + Vector2(-6, -4), 13.0, green)
			_root.draw_circle(c + Vector2(4, -4), 6.0, Color(0.15, 0.05, 0.05, a))
			_root.draw_circle(c + Vector2(10, 12 + 3.0 * sin(_t * 6.0)), 5.0, Color(1, 0.62, 0.11, a))
			_root.draw_line(c + Vector2(18, 2), c + Vector2(18, 14), ink, 2.0)
			_root.draw_line(c + Vector2(15, 11), c + Vector2(18, 14), ink, 2.0)
			_root.draw_line(c + Vector2(21, 11), c + Vector2(18, 14), ink, 2.0)
		"swap":
			_root.draw_circle(c + Vector2(-14, 0), 7.0, Color(0.55, 0.6, 0.68, a))
			_root.draw_circle(c + Vector2(14, -5), 4.5, Color(0.63, 0.44, 0.24, a))
			_root.draw_circle(c + Vector2(14, 6), 4.5, Color(0.63, 0.44, 0.24, a))
			_root.draw_line(c + Vector2(-5, -3), c + Vector2(6, -3), ink, 2.0)
			_root.draw_line(c + Vector2(3, -6), c + Vector2(6, -3), ink, 2.0)
			_root.draw_line(c + Vector2(6, 3), c + Vector2(-5, 3), ink, 2.0)
			_root.draw_line(c + Vector2(-2, 6), c + Vector2(-5, 3), ink, 2.0)
		"wall":
			_root.draw_rect(Rect2(c + Vector2(-20, -14), Vector2(40, 28)), Color(0.3, 0.2, 0.14, a))
			for k in 3:
				_root.draw_circle(c + Vector2(-11 + k * 11, 0), 5.0, [Color("ff9f1c"), Color("8d99ae"), Color("6ff0ff")][k] * Color(1, 1, 1, a))


## Stage icon size: the segment sprite's width at stage 1, and how much it grows per stage.
const ICON_BASE_PX := 26.0
const ICON_STEP_PX := 5.0
## Seconds of the pop when the icon grows (the stage-up).
const ICON_PULSE := 0.7
## Room per worm along the top edge (stage 7's icon is about 330 px long).
const ICON_GAP := 380.0


## Segments in the icon at a stage: the head plus one body segment per stage (the count is the
## picture; no number is ever drawn).
static func icon_segments(stage: int) -> int:
	return maxi(1, stage) + 1


## Sprite width in the icon at a stage.
static func icon_px(stage: int) -> float:
	return ICON_BASE_PX + ICON_STEP_PX * (maxi(1, stage) - 1)


## The stage the icon shows for a player (-1 before it has seen that worm).
func icon_stage(player: int) -> int:
	return _icon_stage.get(player, -1)


## 1.0 at rest; above 1 while the icon pops after a stage-up.
func icon_scale(player: int) -> float:
	var left: float = _icon_pulse.get(player, 0.0)
	if left <= 0.0:
		return 1.0
	return 1.0 + 0.45 * sin(PI * (1.0 - left / ICON_PULSE))


## Notices stage-ups: a worm seen for the first time (loaded, hatched) just shows its stage; a
## bigger stage than last frame starts the pop.
func _track_icons(delta: float) -> void:
	for p in _icon_pulse.keys():
		_icon_pulse[p] = maxf(0.0, _icon_pulse[p] - delta)
	for w in Worm.all():
		var s: int = w.model.stage
		if _icon_stage.has(w.player) and s > _icon_stage[w.player]:
			_icon_pulse[w.player] = ICON_PULSE
		_icon_stage[w.player] = s


## The worm's own segment sprites (WormLook), head and face at the right, one more segment and a
## bigger sprite each stage, with a gentle wiggle; a ring pops out of the head at a stage-up.
func _draw_stage_icon(at: Vector2, w: Worm) -> void:
	var stage: int = _icon_stage.get(w.player, w.model.stage)
	var look := WormHooks.look()
	var n := icon_segments(stage)
	var k := icon_scale(w.player)
	var px := icon_px(stage) * k
	var step := px * 0.7
	var shade := Color(0, 0, 0, 0.45)
	var head := at + Vector2((n - 1) * step, 0)
	var back := Color(0.08, 0.06, 0.1, 0.55)   # the hint panel's backing, as a pill
	var br := px * 0.85
	var pill := PackedVector2Array()
	for j in 13:   # one capsule polygon, so the see-through backing has no darker seams
		pill.append(head + Vector2.from_angle(-PI / 2 + PI * j / 12.0) * br)
	for j in 13:
		pill.append(at + Vector2.from_angle(PI / 2 + PI * j / 12.0) * br)
	_root.draw_colored_polygon(pill, back)
	for i in n:   # tail first so the head draws on top
		var c := at + Vector2(i * step, sin(_t * 3.0 + i * 0.9) * px * 0.08)
		if i == n - 1:
			c = head
		_root.draw_circle(c, px * 0.58, shade)
		var kind: StringName = &"head" if i == n - 1 else (&"tail" if i == 0 else &"body")
		var tex: Texture2D = look.segment_texture(w.player, stage, kind)
		var sz := px * (1.15 if kind == &"head" else 1.0)
		if tex:
			_root.draw_texture_rect(tex, Rect2(c - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false)
	var face: Texture2D = look.face_texture(w.player, stage, &"idle")
	if face:
		var fs := px * 1.15
		_root.draw_texture_rect(face, Rect2(head - Vector2(fs, fs) * 0.5, Vector2(fs, fs)), false)
	if k > 1.0:
		var left: float = _icon_pulse.get(w.player, 0.0)
		var u := 1.0 - left / ICON_PULSE
		_root.draw_arc(head, px * (0.7 + 1.4 * u), 0.0, TAU, 32, Color(1, 1, 1, 0.8 * (1.0 - u)), 4.0)


func _draw_edge_arrow(view: Vector2, cam: PolarCamera, w: Worm) -> void:
	var q: Vector2 = Transform2D(-cam.rotation, Vector2.ZERO) * (w.cam_position() - cam.position)
	var dir := q.normalized()
	var half := view * 0.5 - Vector2(70, 70)
	var k := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	var p := view * 0.5 + dir * k
	var col: Color = Players.COLOR[w.player]
	var pulse := 1.0 + 0.15 * sin(_t * 6.0)
	var tip := p + dir * 34.0 * pulse
	var side := dir.orthogonal() * 22.0 * pulse
	_root.draw_colored_polygon(PackedVector2Array([tip, p + side, p - side]), col)
	_root.draw_circle(p - dir * 10.0, 18.0, col)
	_root.draw_circle(p - dir * 10.0, 7.0, Color.WHITE)
