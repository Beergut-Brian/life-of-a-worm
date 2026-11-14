## Old Reel's jar shelf on the dock (S-10): one spot per bait tin, each holding that tin's planet jar
## if it has one (JarStore.shelf, from the shared `Jars` autoload). Each player walks a little worm
## along the planks with the stick or the d-pad; the jar in reach of a worm lifts and shows [a], and
## A opens it (the host plays JarOpenView). Nothing moves a worm but its player: no snap to a jar.
## An empty shelf says so in a picture (a planet, a mouth, an arrow into an empty jar), never in text.
## Placeholder art drawn in code (the worm-art lanes are held); either pad; B goes back to the tins.
class_name JarShelf
extends Control

signal jar_chosen(entry: Dictionary)   # { "slot": "tin2", "id": &"p1_tin2_5150" }
signal back()

const SPEED := 620.0          # px/s a worm walks along the planks
const REACH := 150.0          # px either side of a jar that counts as "at" it
const STEP_EVERY := 0.32      # seconds between footstep ticks while walking
const SPOT_X := [0.3, 0.5, 0.7]   # spot centres as a fraction of the width, tin 1..3
const LID := [Color("c94a3a"), Color("3a8f5a"), Color("d9a12b")]   # the dock's tin colours
const OUTLINE := Color("2a1a14")

var store: JarStore
var entries: Array[Dictionary] = []     # JarStore.shelf(): only the tins that have a jar
var walker_x := {}                      # player -> x px
var focus := {}                         # player -> spot index (-1 none)
var _textures := {}                     # jar id -> Texture2D of its planet
var _t := 0.0
var _step_t := {}
var _nope := {}                         # player -> seconds left of the "nothing here" wiggle


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


## Show the shelf for the current profile. `at_id`: start the worms beside this jar (after a leave).
func open(jars: JarStore = null, at_id: StringName = &"") -> void:
	store = jars if jars else get_node_or_null(^"/root/Jars") as JarStore
	position = Vector2.ZERO
	size = get_viewport_rect().size
	refresh()
	walker_x.clear()
	focus.clear()
	var start := size.x * 0.12
	for e in entries:
		if e.id == at_id:
			start = spot_x(spot_of(e.slot)) - REACH * 0.5
	var i := 0
	for p in _players():
		walker_x[p] = start - i * 90.0
		i += 1
	_update_focus(false)
	visible = true
	UiSound.play("ui_card")


func close() -> void:
	visible = false


func refresh() -> void:
	entries = store.shelf(slot_names()) if store else ([] as Array[Dictionary])
	_textures.clear()
	for e in entries:
		var data := store.peek(e.id)
		var p = data.get("planet", null)
		var stand := PlanetStandIn.from_save(p if p is Dictionary else {})
		if stand.seed_value == 0:
			stand.seed_value = int(data.get("seed", 0))
		_textures[e.id] = stand.texture(128)
	queue_redraw()


static func slot_names() -> PackedStringArray:
	var out := PackedStringArray()
	for i in BaitTins.COUNT:
		out.append(BaitTins.slot_name(i))
	return out


static func spot_of(slot: String) -> int:
	return slot_names().find(slot)


func spot_x(i: int) -> float:
	return size.x * SPOT_X[clampi(i, 0, SPOT_X.size() - 1)]


func entry_at(spot: int) -> Dictionary:
	for e in entries:
		if spot_of(e.slot) == spot:
			return e
	return {}


## Walk player p's worm by `axis` (-1..1) for `delta` seconds. The only thing that moves it.
func walk(p: int, axis: float, delta: float) -> void:
	if not walker_x.has(p):
		walker_x[p] = size.x * 0.12
	walker_x[p] = clampf(walker_x[p] + axis * SPEED * delta, 60.0, size.x - 60.0)
	if absf(axis) > 0.2:
		_step_t[p] = _step_t.get(p, 0.0) + delta
		if _step_t[p] >= STEP_EVERY:
			_step_t[p] = 0.0
			UiSound.play("ui_tick", 0.9 + 0.2 * randf())
	_update_focus(true)


## A for player p: open the jar in reach. False (a "nothing here" wiggle) when no jar is in reach.
func press_a(p: int) -> bool:
	var e := entry_at(focus.get(p, -1))
	if e.is_empty():
		_nope[p] = 0.4
		UiSound.play("ui_back")
		return false
	UiSound.play("ui_confirm")
	visible = false
	jar_chosen.emit(e)
	return true


func _update_focus(sound: bool) -> void:
	for p in walker_x:
		var best := -1
		var best_d := REACH
		for i in BaitTins.COUNT:
			var d := absf(walker_x[p] - spot_x(i))
			if d <= best_d and not entry_at(i).is_empty():
				best_d = d
				best = i
		if sound and best != focus.get(p, -1) and best != -1:
			UiSound.play("ui_move")
		focus[p] = best


func _players() -> Array:
	var out := []
	for p in [Players.P1, Players.P2]:
		if Players.is_active(p):
			out.append(p)
	return out if not out.is_empty() else [Players.P1]


func _process(delta: float) -> void:
	if not visible or Game.state == Game.State.PAUSED:
		return
	_t += delta
	for p in _nope.keys():
		_nope[p] = maxf(0.0, _nope[p] - delta)
	queue_redraw()
	for p in [Players.P1, Players.P2]:
		if not Players.is_active(p):
			continue
		var axis := Input.get_axis(Players.action(p, "move_left"), Players.action(p, "move_right"))
		walk(p, axis, delta)
		if Input.is_action_just_pressed(Players.action(p, "action")):
			if press_a(p):
				return
		elif Input.is_action_just_pressed(Players.action(p, "jump")):
			UiSound.play("ui_back")
			visible = false
			back.emit()
			return


func _draw() -> void:
	var v := size
	var shelf_y := v.y * 0.52
	var plank_y := v.y * 0.78
	draw_rect(Rect2(Vector2.ZERO, v), Color("f2b880"))                                  # dawn
	draw_rect(Rect2(0, v.y * 0.3, v.x, v.y * 0.1), Color("f7d2a0"))
	draw_circle(Vector2(v.x * 0.9, v.y * 0.18), 80.0, Color("fff1c8"))
	draw_rect(Rect2(0, plank_y - 40, v.x, v.y), Color("3f6f8f"))                          # pond
	# Old Reel's shed wall behind the shelf
	draw_rect(Rect2(v.x * 0.16, v.y * 0.12, v.x * 0.68, plank_y - v.y * 0.12), Color("6e4527"))
	for x in range(int(v.x * 0.16), int(v.x * 0.84), 96):
		draw_line(Vector2(x, v.y * 0.12), Vector2(x, plank_y), Color("5e3b20"), 4.0)
	draw_rect(Rect2(v.x * 0.14, v.y * 0.09, v.x * 0.72, 30), OUTLINE)                       # roof edge
	# the shelf plank on two brackets
	draw_rect(Rect2(v.x * 0.2, shelf_y, v.x * 0.6, 30), OUTLINE)
	draw_rect(Rect2(v.x * 0.2 + 6, shelf_y + 4, v.x * 0.6 - 12, 18), Color("a86b3c"))
	for bx in [v.x * 0.24, v.x * 0.76]:
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 14, shelf_y + 30), Vector2(bx + 14, shelf_y + 30),
				Vector2(bx, shelf_y + 90)]), OUTLINE)
	for i in BaitTins.COUNT:
		var e := entry_at(i)
		var lifted := false
		for p in focus:
			lifted = lifted or focus[p] == i
		_draw_jar(Vector2(spot_x(i), shelf_y), i, e, lifted)
	if entries.is_empty():
		_draw_how_to_fill(Vector2(v.x * 0.5, v.y * 0.19))
	# the dock planks the worms walk on
	draw_rect(Rect2(0, plank_y, v.x, 70), Color("8a5a34"))
	for x in range(0, int(v.x), 120):
		draw_line(Vector2(x, plank_y), Vector2(x, plank_y + 70), Color("5e3b20"), 3.0)
		draw_rect(Rect2(x + 50, plank_y + 70, 18, 200), Color("5e3b20"))
	for p in walker_x:
		_draw_walker(p, Vector2(walker_x[p], plank_y))
	UiStyle.draw_hint_strip(self, v, "[lr] Walk   [a] Open   [b] Back")


## One spot: the tin's jar (glass, its planet inside, a lid in the tin's colour) or a faint outline.
func _draw_jar(base: Vector2, spot: int, e: Dictionary, lifted: bool) -> void:
	var lift := (sin(_t * 4.0) * 6.0 - 22.0) if lifted else 0.0
	var r := Rect2(base + Vector2(-95, -230 + lift), Vector2(190, 230))
	if e.is_empty():
		_dashed_rect(r, Color(1, 1, 1, 0.35))
		_dashed_rect(Rect2(r.position + Vector2(10, -30), Vector2(170, 30)), Color(1, 1, 1, 0.35))
		draw_rect(Rect2(r.position + Vector2(60, r.size.y * 0.5 - 8), Vector2(70, 16)), Color(LID[spot], 0.5))
		return
	if lifted:
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(UiStyle.CREAM, 0.35 + 0.15 * sin(_t * 6.0))
		glow.set_corner_radius_all(48)
		draw_style_box(glow, r.grow(22))
	var glass := StyleBoxFlat.new()
	glass.bg_color = Color(0.75, 0.9, 1.0, 0.22)
	glass.set_corner_radius_all(38)
	draw_style_box(glass, r)
	var tex: Texture2D = _textures.get(e.id)
	var c := r.get_center() + Vector2(0, 14)
	var ps := 140.0
	draw_set_transform(c, _t * 0.4 + spot, Vector2.ONE)
	if tex:
		draw_texture_rect(tex, Rect2(-Vector2(ps, ps) / 2.0, Vector2(ps, ps)), false)
	else:
		draw_circle(Vector2.ZERO, ps / 2.0, Color("5fb04a"))
	draw_set_transform(Vector2.ZERO)
	var rim := StyleBoxFlat.new()
	rim.draw_center = false
	rim.border_color = Color(0.91, 0.96, 1.0)
	rim.set_border_width_all(8)
	rim.set_corner_radius_all(38)
	draw_style_box(rim, r)
	draw_line(r.position + Vector2(34, 50), r.position + Vector2(34, 170), Color(1, 1, 1, 0.6), 8.0)
	draw_rect(Rect2(r.position + Vector2(4, -34), Vector2(182, 40)), OUTLINE)                # lid
	draw_rect(Rect2(r.position + Vector2(10, -28), Vector2(170, 28)), LID[spot])
	if lifted:
		UiStyle.draw_rich(self, r.position + Vector2(95, -70), "[a]", UiStyle.Role.BODY, UiStyle.CREAM, 1, 72)


## The empty shelf, as a picture: a planet, a big mouth biting it, an arrow into an empty jar.
func _draw_how_to_fill(c: Vector2) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiStyle.CREAM, 0.92)
	sb.set_corner_radius_all(40)
	sb.border_color = OUTLINE
	sb.set_border_width_all(6)
	draw_style_box(sb, Rect2(c - Vector2(360, 100), Vector2(720, 200)))
	var pc := c + Vector2(-230, 0)
	draw_circle(pc, 74.0, OUTLINE)
	draw_circle(pc, 68.0, Color("5fb04a"))
	draw_circle(pc, 40.0, Color("8a5a34"))
	draw_circle(pc, 14.0, Color("f2c14e"))
	var mc := pc + Vector2(70, -40)                                              # the mouth, mid-bite
	draw_circle(mc, 44.0, OUTLINE)
	draw_circle(mc, 38.0, Color("3cc24a"))
	var open := 0.35 + 0.25 * absf(sin(_t * 3.0))
	draw_colored_polygon(PackedVector2Array([mc, mc + Vector2(-44, 44 * open).rotated(-0.3),
			mc + Vector2(-44, -44 * open).rotated(-0.3)]), OUTLINE)
	draw_circle(mc + Vector2(6, -18), 7.0, Color.WHITE)
	var a0 := c + Vector2(-60, 0)
	var a1 := c + Vector2(150, 0)
	draw_line(a0, a1, OUTLINE, 14.0)
	draw_colored_polygon(PackedVector2Array([a1 + Vector2(30, 0), a1 + Vector2(-10, -30), a1 + Vector2(-10, 30)]), OUTLINE)
	var jr := Rect2(c + Vector2(200, -80), Vector2(130, 160))
	var glass := StyleBoxFlat.new()
	glass.draw_center = false
	glass.border_color = Color("4a8fb0")
	glass.set_border_width_all(8)
	glass.set_corner_radius_all(26)
	draw_style_box(glass, jr)
	draw_rect(Rect2(jr.position + Vector2(4, -22), Vector2(122, 26)), OUTLINE)


func _draw_walker(p: int, feet: Vector2) -> void:
	var col := UiStyle.player_color(p)
	var wig := sin(_nope.get(p, 0.0) * 60.0) * 10.0 * minf(1.0, _nope.get(p, 0.0) * 5.0)
	var bob := absf(sin(walker_x[p] * 0.03)) * 8.0
	for k in 5:                                         # body segments, tail to head
		var at := feet + Vector2(-k * 26.0 + wig, -24.0 - bob * (1.0 if k == 0 else 0.4) - sin(k + walker_x[p] * 0.02) * 6.0)
		draw_circle(at, 26.0 - k * 1.5, OUTLINE)
		draw_circle(at, 22.0 - k * 1.5, col)
	var head := feet + Vector2(wig, -24.0 - bob)
	draw_circle(head + Vector2(8, -8), 7.0, Color.WHITE)
	draw_circle(head + Vector2(10, -8), 3.5, OUTLINE)


func _dashed_rect(r: Rect2, col: Color) -> void:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		draw_dashed_line(pts[i], pts[i + 1], col, 5.0, 18.0)
