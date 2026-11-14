## Start fresh from the menu (Kaden's standing rule, 2026-11-09): on the bait-tin dock (Worm's menu
## for its saves) a played tin offers Continue (the tin itself: A, the dock's own pick) and, below
## it, New world (down then A, or Y). New asks first: a card where A must be HELD while a ring fills
## (a tap drains it with a back tick); B keeps the planet. Confirming never deletes the planet:
## BaitTins.start_fresh backs it up (and refuses if it can't) and the tin opens as a new planet (Old
## Reel's opening). A tin with a backup also offers Restore (X) on the dock; the lobby's Settings
## offers Restore old world (the newest backup of any tin), behind the same held-A card.
## A menu, so text labels and glyphs are fine here (docs/kid-design.md, "Menus are for grown-ups").
## It sits beside the dock (a child of main.tscn's UI) and drives it from outside, so the dock's own
## file stays as it is; with no Dock it does nothing (template-only boots).
class_name TinFresh
extends Control

enum Ask { NONE, NEW, RESTORE, RESTORE_NEWEST }
## Under a played tin: which choice is lit. CONTINUE = the tin (the dock has the pad), NEW = New
## world (this hook has the pad until up / B / left / right gives it back).
enum Choice { CONTINUE, NEW }

## Seconds A must be held to confirm.
const HOLD := 1.5

var dock: Dock
## The lobby's Settings panel (offers Restore old world). Null = no Settings route.
var settings: SettingsPanel
var choice := Choice.CONTINUE
var ask := Ask.NONE
var confirm := HoldConfirm.new()
## Which player's pad opened the card (only that pad's A / B answer it).
var asker := -1
var _tick := 0.0
## The node whose pad the open card took (the dock, or the lobby behind Settings).
var _took: Node
## The tin a Settings restore brings back (for the card's words).
var _restore_tin := -1
## The last draw put the dock's choices on screen (gap-close-36: they must be wiped when it goes).
var drew_choices := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_find_dock.call_deferred()


func _find_dock() -> void:
	if dock == null:
		dock = get_parent().get_node_or_null("Dock") as Dock
	if settings == null and dock != null:
		hook_settings(get_parent().get_node_or_null("Lobby/Settings") as SettingsPanel)


## The lobby's Settings shows Restore old world while any tin has a backup.
func hook_settings(panel: SettingsPanel) -> void:
	settings = panel
	if panel == null:
		return
	panel.restore_check = func() -> bool: return BaitTins.newest_backup() != ""
	panel.restore_asked.connect(func(p: int) -> void: open(Ask.RESTORE_NEWEST, p))


## The tin the dock has in focus, -1 when the dock is not up.
func tin() -> int:
	return dock.focus if dock != null and dock.visible else -1


## A played tin. Reads the dock's own summaries (filled when it opens or refreshes), so a big tin
## file is not parsed every frame.
func can_new(i: int) -> bool:
	if i < 0:
		return false
	if dock != null and i < dock._summaries.size():
		return not dock._summaries[i].is_empty()
	return not BaitTins.summary(i).is_empty()


func can_restore(i: int) -> bool:
	return i >= 0 and BaitTins.has_backup(i)


func open(kind: Ask, player := Players.P1) -> void:
	ask = kind
	asker = player
	if kind == Ask.NEW:
		choice = Choice.NEW
	if kind == Ask.RESTORE_NEWEST:
		_restore_tin = BaitTins.tin_of(BaitTins.newest_backup())
	confirm = HoldConfirm.new()
	confirm.hold_time = HOLD
	confirm.started.connect(func() -> void: UiSound.play("ui_tick"))
	confirm.cancelled.connect(func() -> void: UiSound.play("ui_back"))
	# The card has the pad: A must not open the tin (or press a Settings row) underneath.
	_took = dock if kind != Ask.RESTORE_NEWEST else (settings.get_parent() if settings else null)
	if _took != null:
		_took.set_process(false)
	UiSound.play("ui_card")
	queue_redraw()


## Light New world under the focused played tin and take the pad from the dock.
func focus_new() -> void:
	choice = Choice.NEW
	_took = dock
	dock.set_process(false)
	UiSound.play("ui_move", 0.9)
	queue_redraw()


## Back to Continue (the tin): the dock has the pad again.
func focus_continue(sound := true) -> void:
	choice = Choice.CONTINUE
	if sound:
		UiSound.play("ui_move", 1.1)
	_give_back()
	queue_redraw()


## B, or letting the card go: back to the dock as it was.
## Back on New world when it was lit (the dock keeps waiting), else the pad goes back.
func cancel() -> void:
	var kind := ask
	ask = Ask.NONE
	UiSound.play("ui_back")
	if kind != Ask.NEW or choice != Choice.NEW:
		_give_back()
	queue_redraw()


func _give_back() -> void:
	var n := _took
	_took = null
	# Next frame, so the press that closed the card is not read again (B = back to lobby).
	(func() -> void:
		if is_instance_valid(n):
			n.set_process(true)).call_deferred()


func _confirmed() -> void:
	var i := tin()
	var kind := ask
	ask = Ask.NONE
	choice = Choice.CONTINUE
	_give_back()
	queue_redraw()
	if kind == Ask.NEW:
		if BaitTins.start_fresh(i) == "" and not BaitTins.summary(i).is_empty():
			UiSound.play("ui_back")   # it could not be backed up: the planet stays, nothing opens
			dock.refresh()
			return
		UiSound.play("ui_go")
		dock.refresh()
		dock.pick()                  # the empty tin opens as a new planet, as any empty tin does
	elif kind == Ask.RESTORE:
		UiSound.play("ui_confirm" if BaitTins.restore(i) else "ui_back")
		dock.refresh()
	elif kind == Ask.RESTORE_NEWEST:
		UiSound.play("ui_confirm" if BaitTins.restore_newest() >= 0 else "ui_back")
		if dock != null:
			dock.refresh()
		if settings != null:
			settings.refresh()


## One frame of the card for tests and _process: is the asker holding A, did they press B.
func step(delta: float, held: bool, back: bool) -> void:
	if ask == Ask.NONE:
		return
	if back and not confirm.is_holding():
		cancel()
		return
	confirm.step(delta, held)
	if confirm.is_holding():
		_tick += delta
		if _tick >= 0.25:            # a beep while the ring fills, so the hold is heard
			_tick = 0.0
			UiSound.play("ui_tick", 1.0 + confirm.progress)
	if confirm.done:
		_confirmed()


func _process(delta: float) -> void:
	if Game.state == Game.State.PAUSED:
		return
	if ask != Ask.NONE:
		if ask != Ask.RESTORE_NEWEST and (dock == null or not dock.visible):
			ask = Ask.NONE                    # the dock went away under the card
			choice = Choice.CONTINUE
			_give_back()
			return
		queue_redraw()
		step(delta, Input.is_action_pressed(Players.action(asker, "action")),
			Input.is_action_just_pressed(Players.action(asker, "jump")))
		return
	if dock == null:
		return
	if not dock.visible:
		if choice == Choice.NEW:
			focus_continue(false)
		if drew_choices:
			queue_redraw()   # the dock went: wipe its Continue / New world, or they stay over play
		return
	var i := tin()
	if choice == Choice.NEW and not can_new(i):
		focus_continue(false)
	queue_redraw()
	for p in [Players.P1, Players.P2]:
		if not Players.is_active(p):
			continue
		if choice == Choice.NEW:
			if Input.is_action_just_pressed(Players.action(p, "action")) \
					or Input.is_action_just_pressed(Players.action(p, "tackle")):
				open(Ask.NEW, p)
				return
			if Input.is_action_just_pressed(Players.action(p, "move_up")) \
					or Input.is_action_just_pressed(Players.action(p, "jump")):
				focus_continue()
				return
			for d in [-1, 1]:
				if Input.is_action_just_pressed(Players.action(p, "move_left" if d < 0 else "move_right")):
					focus_continue(false)
					dock.move(d)              # the next tin, on Continue
					return
		else:
			if Input.is_action_just_pressed(Players.action(p, "move_down")):
				if can_new(i):
					focus_new()
				else:
					UiSound.play("ui_back")   # an empty tin is already new: a no beep
				return
			if Input.is_action_just_pressed(Players.action(p, "tackle")):
				if can_new(i):
					open(Ask.NEW, p)
				else:
					UiSound.play("ui_back")
				return
		if Input.is_action_just_pressed(Players.action(p, "carry")):
			if can_restore(i):
				open(Ask.RESTORE, p)
			else:
				UiSound.play("ui_back")
			return


func _draw() -> void:
	var v := get_viewport_rect().size
	drew_choices = dock != null and dock.visible
	if drew_choices:
		_draw_choices(v)
	if ask == Ask.NONE:
		return
	draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.6))
	var card := Rect2(v * 0.5 - Vector2(560, 230), Vector2(1120, 460))
	UiStyle.slab(self, card, UiStyle.deep(), UiStyle.SHADOW)
	var i := tin() if ask != Ask.RESTORE_NEWEST else _restore_tin
	var title := "START A NEW WORLD?" if ask == Ask.NEW else "BRING BACK THE OLD WORLD?"
	UiStyle.draw_show(self, card.position + Vector2(card.size.x * 0.5, 90), title, 64, UiStyle.CREAM, 1)
	var body := ""
	match ask:
		Ask.NEW:
			body = "Tin %d's planet is kept safe: Settings > Restore old world brings it back." % (i + 1)
		_:
			body = "Tin %d gets its last planet back. The one in it now is kept too." % (i + 1)
	UiStyle.draw_rich(self, card.position + Vector2(card.size.x * 0.5, 170), body, UiStyle.Role.BODY,
		Color(UiStyle.CREAM, 0.85), 1)
	var ring := card.position + Vector2(card.size.x * 0.5, 290)
	draw_arc(ring, 58.0, 0.0, TAU, 48, Color(UiStyle.CREAM, 0.25), 14.0)
	if confirm.progress > 0.0:
		draw_arc(ring, 58.0, -PI * 0.5, -PI * 0.5 + TAU * confirm.progress, 48,
			UiStyle.player_color(asker), 14.0)
	UiStyle.draw_rich(self, ring, "[a]", UiStyle.Role.BUTTON, UiStyle.CREAM, 1, 56)
	UiStyle.draw_rich(self, card.position + Vector2(card.size.x * 0.5, 410),
		"Hold [a] Yes   [b] Keep it", UiStyle.Role.HINT, UiStyle.CREAM, 1, 30)


## Under the focused played tin: Continue, and New world below it (the lit one bright and wider),
## and Restore when the tin has a backup.
func _draw_choices(v: Vector2) -> void:
	var i := tin()
	if i < 0:
		return
	# The dock's tins sit at x = 0.25, 0.5, 0.75 of the screen; the choices go under the focused one.
	var cx := v.x * (0.25 + 0.25 * i)
	var y := v.y * 0.62 + 190
	var lines: Array = []
	if can_new(i):
		lines.append(["[a] Continue", choice == Choice.CONTINUE])
		lines.append(["[y] New world", choice == Choice.NEW])
	if can_restore(i):
		lines.append(["[x] Restore", false])
	for l in lines:
		var lit: bool = l[1]
		var w := UiStyle.rich_width(l[0], UiStyle.Role.HINT, 30) + (72.0 if lit else 48.0)
		var r := Rect2(cx - w * 0.5, y, w, 54 if lit else 46)
		UiStyle.para(self, r, UiStyle.accent if lit else Color(UiStyle.INK_SHOW, 0.85))
		UiStyle.draw_rich(self, r.get_center(), l[0], UiStyle.Role.HINT,
			UiStyle.INK_SHOW if lit else UiStyle.CREAM, 1, 30)
		y += r.size.y + 10
