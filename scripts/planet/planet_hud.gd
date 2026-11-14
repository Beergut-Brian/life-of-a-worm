## Gameplay HUD, text-free: a hint panel per player (PlayerHints: controller glyph + a picture per
## action, rules in HintRules), the press answer for buttons that do nothing (PressAnswer),
## an edge arrow in a worm's colour when it is off screen, a growing worm icon for each worm's
## stage (no numbers), and the stage-up white flash. The level feeds it each frame.
class_name PlanetHud
extends CanvasLayer

var level: Node
## One hint panel per player in the level (PlayerHints), made on first use.
var panels: Dictionary = {}
## Routes presses that do nothing to a bonk, a glyph shake and a woken panel (PressAnswer).
var answer: PressAnswer
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
	answer = PressAnswer.new()
	answer.hud = self
	answer.level = level
	add_child(answer)


## Two frames of white (the stage-up).
func flash() -> void:
	_flash_frames = 2
	_flash.visible = true


## The level (then the home slice) calls this each frame for each worm with its own context
## (HintRules ctx keys). The player's panel follows it: rows, lit pictures, folding.
func set_player_context(player: int, ctx: Dictionary) -> void:
	var p := panel_of(player, true)
	p.show_context(ctx)


func panel_of(player: int, make := false) -> PlayerHints:
	if not panels.has(player):
		if not make:
			return null
		var p := PlayerHints.new()
		p.player = player
		_root.add_child(p)
		panels[player] = p
	return panels[player]


## Drop the panels of players with no worm in the level (left, or not joined).
func keep_panels(players: Array) -> void:
	for player in panels.keys():
		if not player in players:
			panels[player].queue_free()
			panels.erase(player)


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
	if level == null:
		return
	var cam: PolarCamera = level.camera
	var i := 0
	for w in Worm.all():
		_draw_stage_icon(Vector2(80 + i * ICON_GAP, 80), w)
		if cam and not cam.sees(w.cam_position(), 30.0):
			_draw_edge_arrow(view, cam, w)
		i += 1


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
