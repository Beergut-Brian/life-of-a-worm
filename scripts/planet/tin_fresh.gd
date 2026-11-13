## Start fresh from the menu (Kaden's feel rule): on the bait-tin dock, a played tin offers
## Continue (A, the dock's own pick) and New (Y). New asks first: a card where A must be HELD while a
## ring fills; B keeps playing. Confirming never deletes the planet: BaitTins.start_fresh moves it
## to a backup and the tin opens as a new planet (Old Reel's opening). A tin with a backup also offers
## Restore (X), the same held-A card, which brings the newest backup back (BaitTins.restore).
## A menu, so text labels and glyphs are fine here (docs/kid-design.md, "Menus are for grown-ups").
## It sits beside the dock (a child of main.tscn's UI) and drives it from outside, so the dock's own
## file stays as it is; with no Dock it does nothing (template-only boots).
class_name TinFresh
extends Control

enum Ask { NONE, NEW, RESTORE }

## Seconds A must be held to confirm.
const HOLD := 1.5

var dock: Dock
var ask := Ask.NONE
var confirm := HoldConfirm.new()
## Which player's pad opened the card (only that pad's A / B answer it).
var asker := -1
var _tick := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_find_dock.call_deferred()


func _find_dock() -> void:
	if dock == null:
		dock = get_parent().get_node_or_null("Dock") as Dock


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
	confirm = HoldConfirm.new()
	confirm.hold_time = HOLD
	confirm.started.connect(func() -> void: UiSound.play("ui_tick"))
	confirm.cancelled.connect(func() -> void: UiSound.play("ui_back"))
	dock.set_process(false)          # the card has the pad: A must not open the tin underneath
	UiSound.play("ui_card")
	queue_redraw()


## B, or letting the card go: back to the dock as it was.
func cancel() -> void:
	ask = Ask.NONE
	UiSound.play("ui_back")
	_give_back_dock()
	queue_redraw()


func _give_back_dock() -> void:
	# Next frame, so the press that closed the card is not read again by the dock (B = back to lobby).
	(func() -> void:
		if dock != null:
			dock.set_process(true)).call_deferred()


func _confirmed() -> void:
	var i := tin()
	var kind := ask
	ask = Ask.NONE
	_give_back_dock()
	queue_redraw()
	if kind == Ask.NEW:
		BaitTins.start_fresh(i)
		UiSound.play("ui_go")
		dock.refresh()
		dock.pick()                  # the empty tin opens as a new planet, as any empty tin does
	elif kind == Ask.RESTORE:
		BaitTins.restore(i)
		UiSound.play("ui_confirm")
		dock.refresh()


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
	if dock == null or Game.state == Game.State.PAUSED:
		return
	if not dock.visible:
		if ask != Ask.NONE:
			ask = Ask.NONE
			dock.set_process(true)
		return
	queue_redraw()
	if ask != Ask.NONE:
		step(delta, Input.is_action_pressed(Players.action(asker, "action")),
			Input.is_action_just_pressed(Players.action(asker, "jump")))
		return
	var i := tin()
	for p in [Players.P1, Players.P2]:
		if not Players.is_active(p):
			continue
		if Input.is_action_just_pressed(Players.action(p, "tackle")):
			if can_new(i):
				open(Ask.NEW, p)
			else:
				UiSound.play("ui_back")       # an empty tin is already new: a no beep
			return
		if Input.is_action_just_pressed(Players.action(p, "carry")):
			if can_restore(i):
				open(Ask.RESTORE, p)
			else:
				UiSound.play("ui_back")
			return


func _draw() -> void:
	if dock == null or not dock.visible:
		return
	var v := get_viewport_rect().size
	var i := tin()
	# The dock's tins sit at x = 0.25, 0.5, 0.75 of the screen; the choices go under the focused one.
	var cx := v.x * (0.25 + 0.25 * i)
	var parts := PackedStringArray()
	if can_new(i):
		parts.append("[a] Continue   [y] New")
	if can_restore(i):
		parts.append("[x] Restore")
	if not parts.is_empty():
		var line := "   ".join(parts)
		var w := UiStyle.rich_width(line, UiStyle.Role.HINT, 30) + 48.0
		var r := Rect2(cx - w * 0.5, v.y * 0.62 + 196, w, 56)
		UiStyle.para(self, r, UiStyle.INK_SHOW)
		UiStyle.draw_rich(self, r.get_center(), line, UiStyle.Role.HINT, UiStyle.CREAM, 1, 30)
	if ask == Ask.NONE:
		return
	draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.6))
	var card := Rect2(v * 0.5 - Vector2(560, 230), Vector2(1120, 460))
	UiStyle.slab(self, card, UiStyle.deep(), UiStyle.SHADOW)
	var title := "START A NEW PLANET?" if ask == Ask.NEW else "BRING BACK THE OLD PLANET?"
	UiStyle.draw_show(self, card.position + Vector2(card.size.x * 0.5, 90), title, 64, UiStyle.CREAM, 1)
	var body := "Tin %d's planet is kept safe: [x] on this tin brings it back." % (i + 1) if ask == Ask.NEW \
		else "Tin %d gets its last planet back. The one in it now is kept too." % (i + 1)
	UiStyle.draw_rich(self, card.position + Vector2(card.size.x * 0.5, 170), body, UiStyle.Role.BODY,
		Color(UiStyle.CREAM, 0.85), 1)
	var ring := card.position + Vector2(card.size.x * 0.5, 290)
	draw_arc(ring, 58.0, 0.0, TAU, 48, Color(UiStyle.CREAM, 0.25), 14.0)
	if confirm.progress > 0.0:
		draw_arc(ring, 58.0, -PI * 0.5, -PI * 0.5 + TAU * confirm.progress, 48,
			UiStyle.player_color(asker), 14.0)
	UiStyle.draw_rich(self, ring, "[a]", UiStyle.Role.BUTTON, UiStyle.CREAM, 1, 56)
	UiStyle.draw_rich(self, card.position + Vector2(card.size.x * 0.5, 410),
		"Hold [a] Yes   [b] Keep playing", UiStyle.Role.HINT, UiStyle.CREAM, 1, 30)
