## The bait-tin dock (grey-box placeholder): Old Reel's dock at dawn with three bait tins on the
## rail. After the lobby's countdown, pick a tin: left / right, A opens it (an empty tin is a new
## planet), B goes back to the lobby. A menu, so text is fine here (docs/kid-design.md). Either pad.
class_name Dock
extends Control

signal chosen(tin: int)

var focus := 0
var _t := 0.0
var _summaries: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open() -> void:
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
	draw_circle(Vector2(v.x * 0.78, v.y * 0.42), 90.0, Color("fff1c8"))                  # sun
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
		if on:
			draw_rect(r.grow(10), Color(UiStyle.CREAM, 0.9))
		draw_rect(r, Color("9aa4ad"))                                                       # the tin
		draw_rect(Rect2(r.position, Vector2(r.size.x, 26)), Color("c3ccd3"))                # lid
		draw_rect(Rect2(r.position + Vector2(0, 70), Vector2(r.size.x, 70)), Color("c94a3a") if i == 0 else (Color("3a8f5a") if i == 1 else Color("d9a12b")))
		var s: Dictionary = _summaries[i] if i < _summaries.size() else {}
		UiStyle.draw_show(self, r.position + Vector2(90, 105), "TIN %d" % (i + 1), 40, UiStyle.CREAM, 1)
		var line := "New planet" if s.is_empty() else "Stage %d  ·  %d segments" % [s.stage, s.segments]
		UiStyle.draw_text(self, Vector2(cx, v.y * 0.62 + 110), line, UiStyle.Role.BODY, UiStyle.CREAM if on else Color(UiStyle.CREAM, 0.7), 1)
		if not s.is_empty():
			UiStyle.draw_text(self, Vector2(cx, v.y * 0.62 + 160), "%d min played" % s.minutes, UiStyle.Role.HINT, Color(UiStyle.CREAM, 0.7), 1)
	UiStyle.draw_hint_strip(self, v, "[lr] Pick   [a] Open   [b] Back")
