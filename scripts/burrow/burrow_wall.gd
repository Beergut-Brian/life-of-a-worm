## The sleep chooser (D-13): the burrow's wall of pictures seen up close, opened asleep in the bed
## (by itself when a new trait is waiting, or with Y). Same buttons as the placeholder TraitWall it
## replaces (left / right picks, A equips / unequips, B or Y closes), drawn as framed pictures
## hanging from a string on a dirt wall, with a peg for every slot. No text.
## If the wall shuts and the player chose nothing, the burrow equips the newest trait by itself, into
## a free slot only; it never takes a trait off (Burrow.auto_equip). Placeholder look, drawn in code;
## the Worm art round replaces it.
class_name BurrowWall
extends TraitWall

var burrow: Burrow
## The player equipped or unequipped something since the wall opened.
var touched := false

## Gary's pick for kid-check N2 (gap-close-36): the stick always lets go of the wall. Sleep can open
## it by itself, so a kid who just pushes the stick to go must not be stuck: a firm push up or down
## (left / right still picks a picture) held LEAVE_HOLD s shuts the wall (the `wall_close` cue) and
## wakes the worm, which moves off at once. Screen directions, the same as the pictures' row.
const LEAVE_PUSH := 0.6
const LEAVE_HOLD := 0.25
## Reads the player's stick and d-pad (screen space). Tests swap it.
var stick: Callable = func() -> Vector2: return Players.move_vector(worm.player)
## How long the stick has been pushed up or down this time.
var push_t := 0.0


## The pictures on the wall, in order: every earned trait of this worm.
func pictures() -> Array[StringName]:
	return worm.model.earned.duplicate()


func set_open(on: bool) -> void:
	var was := visible
	super.set_open(on)
	if on and not was:
		touched = false
	elif was and not on and not touched and burrow != null:
		burrow.auto_equip(worm)
	push_t = 0.0


func handle(nav: int, confirm: bool, back: bool) -> void:
	var before := worm.model.active.duplicate()
	super.handle(nav, confirm, false)
	if worm.model.active != before:
		touched = true
	if not back and pushed_away(get_physics_process_delta_time()):
		back = true
		worm.asleep = false   # awake: the stick moves the worm from the next frame
		worm.still_time = 0.0
	if back:
		worm.set_wall_open(false)


## True once the stick has been held up or down (more up/down than sideways) for LEAVE_HOLD s.
func pushed_away(delta: float) -> bool:
	var v: Vector2 = stick.call() if stick.is_valid() else Vector2.ZERO
	if absf(v.y) >= LEAVE_PUSH and absf(v.y) > absf(v.x):
		push_t += delta
	else:
		push_t = 0.0
	return push_t >= LEAVE_HOLD


func _draw_wall() -> void:
	var model := worm.model
	var col: Color = Players.COLOR[worm.player]
	var n := maxi(model.earned.size(), 1)
	var w := n * (TILE + GAP) + GAP
	var vp := _root.get_viewport_rect().size
	var x0 := (vp.x - w) * 0.5
	var y0 := vp.y - TILE * 2.6 - (0.0 if worm.player == 0 else TILE * 2.7)
	var panel := Rect2(x0 - 24, y0 - 40, w + 48, TILE * 2.0 + 56)
	# A patch of burrow wall: warm dirt with a few pebbles, edged in the player's colour.
	_root.draw_rect(panel, Color("4a3020"))
	for i in 14:
		var p := panel.position + Vector2(fmod(i * 97.0, panel.size.x), fmod(i * 53.0, panel.size.y))
		_root.draw_circle(p, 3.0 + (i % 3), Color("5e4030"))
	_root.draw_rect(panel, col, false, 6.0)
	# The string the pictures hang from.
	var sy := y0 - 18.0
	_root.draw_line(Vector2(x0, sy), Vector2(x0 + w, sy), Color("d8c090"), 3.0)
	for i in model.earned.size():
		var t := model.rules.find_trait(model.earned[i])
		var on := model.is_active(t.id)
		var r := Rect2(x0 + GAP + i * (TILE + GAP), y0 + GAP * 0.5, TILE, TILE)
		if i == cursor and _shake > 0.0:
			r.position.x += sin(_shake * 80.0) * 6.0
		var top := Vector2(r.get_center().x, sy)
		_root.draw_line(top, r.position + Vector2(8, 0), Color("d8c090"), 2.0)
		_root.draw_line(top, r.position + Vector2(TILE - 8, 0), Color("d8c090"), 2.0)
		_root.draw_circle(top, 4.0, Color("c8a070"))   # the nail
		_root.draw_rect(r.grow(8.0), Color("7a5230"))   # the frame
		_root.draw_rect(r.grow(8.0), Color("2a1a14"), false, 2.0)
		_root.draw_rect(r, t.color.darkened(0.15 if on else 0.65))
		var tex := t.part_texture(model.stage)
		if tex != null:
			var s := floorf(TILE * 0.7 / maxf(tex.get_width(), tex.get_height()))
			var size := tex.get_size() * maxf(s, 1.0)
			_root.draw_texture_rect(tex, Rect2(r.get_center() - size * 0.5, size), false, Color.WHITE if on else Color(0.5, 0.5, 0.5))
		else:
			_root.draw_circle(r.get_center(), TILE * 0.3, t.color if on else t.color.darkened(0.5))
		if on:
			_root.draw_rect(r, Color(1, 1, 0.8), false, 4.0)
		if i == model.earned.size() - 1 and not on:
			# The newest one, still waiting: a little star in its corner.
			_root.draw_circle(r.position + Vector2(TILE - 10, 10), 7.0, Color(1, 0.95, 0.5))
		if i == cursor:
			_root.draw_rect(r.grow(14.0), col, false, 6.0)
	# A peg for each slot under the row, filled for each active trait.
	var slots := model.slots()
	var sx := x0 + (w - slots * 40.0) * 0.5
	for i in slots:
		var c := Vector2(sx + i * 40.0 + 20.0, y0 + TILE + GAP * 2.0 + 20.0)
		_root.draw_circle(c, 14.0, Color(0, 0, 0, 0.6))
		if i < model.active.size():
			_root.draw_circle(c, 11.0, model.rules.find_trait(model.active[i]).color)
		_root.draw_arc(c, 14.0, 0.0, TAU, 24, col, 3.0)
