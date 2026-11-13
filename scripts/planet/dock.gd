## The bait-tin dock (grey-box placeholder): Old Reel's dock at dawn with three bait tins on the
## rail. After the lobby's countdown, pick a tin: left / right, A opens it (an empty tin is a new
## planet), B goes back to the lobby. A menu, so text is fine here (docs/kid-design.md). Either pad.
## Each tin also shows what is inside as a picture, for a reader who can't read yet: a played tin
## stands open with its worms peeking out (green / red, their diet stripes, longer and fatter with
## their stage) and a row of stage pips; an empty tin keeps its lid on with a twinkle.
class_name Dock
extends Control

signal chosen(tin: int)

## Stage pips on a tin (stages 1..7).
const PIPS := 7
## Most segments a peeking worm shows (the rest are inside the tin).
const SHOW_SEGS := 9

var focus := 0
var _t := 0.0
var _summaries: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	refresh()
	visible = true
	UiSound.play("ui_card")


func close() -> void:
	visible = false


func refresh() -> void:
	_summaries.clear()
	for i in BaitTins.COUNT:
		_summaries.append(BaitTins.summary(i))
	queue_redraw()


func move(dir: int) -> void:
	focus = wrapi(focus + dir, 0, BaitTins.COUNT)
	UiSound.play("ui_move")
	queue_redraw()


func pick() -> void:
	UiSound.play("ui_confirm")
	visible = false
	chosen.emit(focus)


## The picture on a tin from its summary (BaitTins.summary): { open, pips, worms: [{ player, stage,
## shown, stripes }] }. `shown` is how many segments peek out; `stripes` their flavour ids, oldest
## first (tail end), "" = plain.
static func picture(s: Dictionary) -> Dictionary:
	if s.is_empty():
		return { "open": false, "pips": 0, "worms": [] }
	var worms: Array[Dictionary] = []
	for b in s.get("bodies", []):
		var segs: Array = b.get("segments", [])
		var shown := clampi(2 + segs.size() / 4, 2, SHOW_SEGS)
		worms.append({ "player": int(b.get("player", 0)), "stage": clampi(int(b.get("stage", 1)), 1, PIPS),
			"shown": shown, "stripes": segs.slice(maxi(0, segs.size() - shown)) })
	return { "open": true, "pips": clampi(int(s.get("stage", 1)), 1, PIPS), "worms": worms }


func _process(delta: float) -> void:
	if not visible or Game.state == Game.State.PAUSED:
		return
	_t += delta
	queue_redraw()
	for p in [Players.P1, Players.P2]:
		if not Players.is_active(p):
			continue
		if Input.is_action_just_pressed(Players.action(p, "move_left")):
			move(-1)
		elif Input.is_action_just_pressed(Players.action(p, "move_right")):
			move(1)
		elif Input.is_action_just_pressed(Players.action(p, "action")):
			pick()
			return
		elif Input.is_action_just_pressed(Players.action(p, "jump")):
			UiSound.play("ui_back")
			visible = false
			Game.to_lobby()
			return


func _draw() -> void:
	var v := size
	draw_rect(Rect2(Vector2.ZERO, v), Color("f2b880"))                                   # dawn
	draw_rect(Rect2(0, v.y * 0.35, v.x, v.y * 0.15), Color("f7d2a0"))
	draw_circle(Vector2(v.x * 0.9, v.y * 0.22), 90.0, Color("fff1c8"))                  # sun
	draw_rect(Rect2(0, v.y * 0.5, v.x, v.y * 0.5), Color("3f6f8f"))                       # pond
	for i in 6:
		var y := v.y * 0.56 + i * 60.0
		draw_line(Vector2(fmod(_t * 30.0 + i * 170.0, v.x), y), Vector2(fmod(_t * 30.0 + i * 170.0, v.x) + 120.0, y), Color(1, 1, 1, 0.25), 3.0)
	draw_rect(Rect2(0, v.y * 0.62, v.x, 60), Color("8a5a34"))                              # dock planks
	for x in range(0, int(v.x), 120):
		draw_line(Vector2(x, v.y * 0.62), Vector2(x, v.y * 0.62 + 60), Color("5e3b20"), 3.0)
		draw_rect(Rect2(x + 50, v.y * 0.62 + 60, 18, 200), Color("5e3b20"))                 # posts
	draw_rect(Rect2(0, v.y * 0.62 - 14, v.x, 14), Color("6e4527"))                         # rail
	UiStyle.draw_show(self, Vector2(v.x * 0.5, 120), "PICK A BAIT TIN", 72, UiStyle.CREAM, 1)
	for i in BaitTins.COUNT:
		var cx := v.x * (0.25 + 0.25 * i)
		var base := Vector2(cx, v.y * 0.62 - 14)
		var on := i == focus
		var lift := (sin(_t * 4.0) * 6.0 - 16.0) if on else 0.0
		var r := Rect2(base + Vector2(-90, -210 + lift), Vector2(180, 210))
		var s: Dictionary = _summaries[i] if i < _summaries.size() else {}
		var pic := picture(s)
		if on:
			draw_rect(r.grow(10), Color(UiStyle.CREAM, 0.9))
		draw_rect(r, Color("9aa4ad"))                                                       # the tin
		if pic.open:
			_draw_open_tin(r, pic, i)
		else:
			draw_rect(Rect2(r.position, Vector2(r.size.x, 26)), Color("c3ccd3"))            # lid on
			_draw_twinkle(r.position + Vector2(r.size.x - 22, 2), 18.0 + sin(_t * 5.0 + i) * 5.0)
		draw_rect(Rect2(r.position + Vector2(0, 70), Vector2(r.size.x, 70)), Color("c94a3a") if i == 0 else (Color("3a8f5a") if i == 1 else Color("d9a12b")))
		UiStyle.draw_show(self, r.position + Vector2(90, 105), "TIN %d" % (i + 1), 40, UiStyle.CREAM, 1)
		if pic.open:
			for k in PIPS:                                                                  # stage pips
				var c := r.position + Vector2(90 + (k - 3) * 22, 174)
				draw_circle(c, 8.0, Color("4a5560"))
				if k < pic.pips:
					draw_circle(c, 6.5, UiStyle.CREAM)
		var line := "New planet" if s.is_empty() else "Stage %d  ·  %d segments" % [s.stage, s.segments]
		UiStyle.draw_text(self, Vector2(cx, v.y * 0.62 + 110), line, UiStyle.Role.BODY, UiStyle.CREAM if on else Color(UiStyle.CREAM, 0.7), 1)
		if not s.is_empty():
			UiStyle.draw_text(self, Vector2(cx, v.y * 0.62 + 160), "%d min played" % s.minutes, UiStyle.Role.HINT, Color(UiStyle.CREAM, 0.7), 1)
	UiStyle.draw_hint_strip(self, v, "[lr] Pick   [a] Open   [b] Back")


## A played tin: the lid tipped back, the dark inside, the worms peeking out of it.
func _draw_open_tin(r: Rect2, pic: Dictionary, tin_i: int) -> void:
	var hinge := r.position + Vector2(r.size.x, 0)
	var lid := PackedVector2Array()
	for p in [Vector2(0, 0), Vector2(-r.size.x, 0), Vector2(-r.size.x, -22), Vector2(0, -22)]:
		lid.append(hinge + p.rotated(0.55))
	draw_colored_polygon(lid, Color("c3ccd3"))                                              # lid, tipped back
	draw_rect(Rect2(r.position, Vector2(r.size.x, 14)), Color("2a2622"))                    # the dark inside
	var n: int = pic.worms.size()
	for j in n:
		var w: Dictionary = pic.worms[j]
		var x := r.position.x + r.size.x * 0.5 + (j - (n - 1) * 0.5) * 64.0
		_draw_peeking_worm(Vector2(x, r.position.y + 10), w, float(j + tin_i))
	draw_rect(Rect2(r.position + Vector2(0, 10), Vector2(r.size.x, 8)), Color("c3ccd3"))    # front rim


## One worm out of the tin: tail end down in the tin, head up, a gentle sway.
func _draw_peeking_worm(base: Vector2, w: Dictionary, phase: float) -> void:
	var colour := UiStyle.player_color(w.player)
	var dark := colour.darkened(0.45)
	var rad := 10.0 + 2.0 * float(w.stage)
	var shown: int = w.shown
	var pts: Array[Vector2] = []
	for k in shown + 1:
		var f := float(k) / float(shown)
		pts.append(base + Vector2(sin(_t * 2.2 + phase + k * 0.8) * 10.0 * f, -k * rad * 1.15))
	var rules := WormRules.default_rules()
	for k in shown:                                                                         # tail to neck
		var c := pts[k]
		draw_circle(c, rad + 2.0, dark)
		draw_circle(c, rad, colour)
		var fl := String(w.stripes[k]) if k < w.stripes.size() else ""
		if fl != "":
			draw_circle(c, rad * 0.5, rules.flavour_color(StringName(fl), colour))
	var h := pts[shown]
	var hr := rad * 1.3
	draw_circle(h, hr + 2.0, dark)                                                          # head
	draw_circle(h, hr, colour)
	var look := Vector2(sin(_t * 1.3 + phase) * 0.15, 0)
	if w.player == 0:                                                                       # one big eye
		draw_circle(h + Vector2(0, -hr * 0.15), hr * 0.5, Color.WHITE)
		draw_circle(h + Vector2(0, -hr * 0.1) + look * hr, hr * 0.25, Color("1c1714"))
	else:                                                                                   # two small eyes
		for sx in [-1.0, 1.0]:
			draw_circle(h + Vector2(sx * hr * 0.38, -hr * 0.15), hr * 0.3, Color.WHITE)
			draw_circle(h + Vector2(sx * hr * 0.3, -hr * 0.1), hr * 0.15, Color("1c1714"))   # a little cross-eyed
	draw_arc(h + Vector2(0, hr * 0.35), hr * 0.35, 0.3, PI - 0.3, 10, Color("1c1714"), 3.0)  # smile


## A four-point twinkle: this tin is new.
func _draw_twinkle(c: Vector2, size: float) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		var a := k * PI / 4.0 - PI / 2.0
		pts.append(c + Vector2.from_angle(a) * (size if k % 2 == 0 else size * 0.3))
	draw_colored_polygon(pts, Color("fff6c8"))
