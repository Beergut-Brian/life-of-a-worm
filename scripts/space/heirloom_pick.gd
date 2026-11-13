## The heirloom choice (S-12), after Old Reel's "another tin" scene. No words: Reel's new bait tin
## sits open in the middle (its band and the little planet on it are the new planet's type), and
## the traits this worm earned float in a row above it. Stick left / right moves the ring (in the
## player's colour), A drops the ringed trait into the tin: its own sting, the lid shuts, and the
## tin slides down onto the dock rail. That is the cause on screen: the trait went in the tin.
## Only earned traits are offered, there is no "nothing" choice to fall into, and nothing here can
## lose a trait: the old tin keeps everything. With nothing earned the empty tin goes on the rail.
class_name HeirloomPick
extends CanvasLayer

signal chosen(id: StringName)
signal finished()

const GRACE := 0.5           # s before A counts (the press that skipped the scene doesn't pick)
const DROP := 0.7
const CLOSE := 0.4
const RAIL := 1.2
const HOLD := 1.0
const ICON := 150.0
const GAP := 210.0

## Trait ids to offer (earned only: OldReelTin.earned_traits).
var traits: Array[StringName] = []
var player := 0
var band := Color("c94a3a")
var planet_color := Color("5d9a46")
## Off in tests: no pad reading.
var read_pads := true

var cursor := 0
## &"choose" -> &"drop" -> &"close" -> &"rail" -> &"hold" -> &"out"
var phase := &"choose"
var picked: StringName = &""
var _t := 0.0
var _pt := 0.0
var _root: Node2D


func _init() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	StoryPictures.register_all()   # bait_tin and trait:<id>
	_root = Node2D.new()
	_root.draw.connect(_draw_all)
	add_child(_root)
	Audio.play("box_open")
	if traits.is_empty():
		_to(&"rail")
		chosen.emit(&"")


func move(dir: int) -> void:
	if phase != &"choose" or traits.size() < 2:
		return
	cursor = wrapi(cursor + dir, 0, traits.size())
	Audio.play("book_tick")


func confirm() -> bool:
	if phase != &"choose" or traits.is_empty():
		return false
	picked = traits[cursor]
	var t := WormRules.default_rules().find_trait(picked)
	Audio.play(t.cue if t and t.cue != "" else "drop")
	_to(&"drop")
	chosen.emit(picked)
	return true


func _to(p: StringName) -> void:
	phase = p
	_pt = 0.0


func _process(delta: float) -> void:
	_t += delta
	_pt += delta
	match phase:
		&"choose":
			if read_pads and _t > GRACE:
				_read_pads()
		&"drop":
			if _pt >= DROP:
				Audio.play("box_close")
				_to(&"close")
		&"close":
			if _pt >= CLOSE:
				_to(&"rail")
		&"rail":
			if _pt >= RAIL:
				Audio.play("jar_clink")
				_to(&"hold")
		&"hold":
			if _pt >= HOLD:
				_to(&"out")
		&"out":
			if _pt >= 0.5:
				finished.emit()
				queue_free()
	if _root:
		_root.queue_redraw()


func _read_pads() -> void:
	for p in [Players.P1, Players.P2]:
		if not Players.is_active(p):
			continue
		if Input.is_action_just_pressed(Players.action(p, "move_left")):
			move(-1)
		elif Input.is_action_just_pressed(Players.action(p, "move_right")):
			move(1)
		elif Input.is_action_just_pressed(Players.action(p, "action")):
			confirm()
			return


func _size() -> Vector2:
	return _root.get_viewport_rect().size if _root and _root.is_inside_tree() else Vector2(1920, 1080)


## Where the tin is drawn now and how big (1 = the open tin in the middle).
func tin_place() -> Array:
	var v := _size()
	var mid := Vector2(v.x * 0.5, v.y * 0.62)
	var rail := Vector2(v.x * 0.5, v.y * 0.9)
	var k := 0.0
	if phase == &"rail":
		k = smoothstep(0.0, 1.0, _pt / RAIL)
	elif phase in [&"hold", &"out"]:
		k = 1.0
	return [mid.lerp(rail, k), lerpf(1.0, 0.45, k)]


func _draw_all() -> void:
	var v := _size()
	var a := 1.0 if phase != &"out" else 1.0 - _pt / 0.5
	_root.draw_rect(Rect2(Vector2.ZERO, v), Color(0.02, 0.03, 0.1, 0.6 * a))
	# the dock rail the tin goes onto
	var ry := v.y * 0.9 + 62.0
	_root.draw_rect(Rect2(0, ry, v.x, 26), Color(Color("6e4527"), a))
	for x in range(40, int(v.x), 160):
		_root.draw_rect(Rect2(x, ry + 26, 18, 80), Color(Color("5e3b20"), a))
	var place := tin_place()
	var c: Vector2 = place[0]
	var s: float = place[1]
	var lid_open := 1.0
	if phase == &"close":
		lid_open = 1.0 - _pt / CLOSE
	elif phase in [&"rail", &"hold", &"out"]:
		lid_open = 0.0
	if traits.is_empty() and phase != &"choose":
		lid_open = 0.0
	_draw_tin(c, s, lid_open, a)
	if phase == &"choose":
		var row_w := (traits.size() - 1) * GAP
		for i in traits.size():
			var ic := Vector2(v.x * 0.5 - row_w * 0.5 + i * GAP, v.y * 0.3 + sin(_t * 2.0 + i) * 8.0)
			if i == cursor:
				_root.draw_arc(ic, ICON * 0.62 + 4.0 * sin(_t * 6.0), 0, TAU, 48, Players.COLOR.get(player, Color.WHITE), 12.0)
				UiStyle.draw_glyph(_root, ic + Vector2(0, ICON * 0.75), 56.0, "a")
			PictoBubble.picture(_root, StringName("trait:" + String(traits[i])), ic, ICON * (1.12 if i == cursor else 0.9), a)
	elif phase == &"drop" and picked != &"":
		var row_w := (traits.size() - 1) * GAP
		var from := Vector2(v.x * 0.5 - row_w * 0.5 + cursor * GAP, v.y * 0.3)
		var k := _pt / DROP
		var at := from.lerp(c + Vector2(0, -60), k) + Vector2(0, -120.0 * sin(k * PI))
		PictoBubble.picture(_root, StringName("trait:" + String(picked)), at, ICON * lerpf(1.1, 0.6, k), a)
	if phase in [&"hold", &"out"]:
		var f := fmod(_pt, 1.0)   # the "it's in there" ring, off the closed tin on the rail
		_root.draw_arc(c, 120.0 + f * 80.0, 0, TAU, 40, Color(1, 0.85, 0.3, (1.0 - f) * a), 6.0)
		if picked != &"":
			PictoBubble.picture(_root, StringName("trait:" + String(picked)), c + Vector2(0, -150), 90.0, a)


## The bait tin, big: grey body, the new planet's band and a little planet on it, the lid hinged
## at the back (open = tipped up and back).
func _draw_tin(c: Vector2, s: float, open: float, a: float) -> void:
	var w := 300.0 * s
	var h := 230.0 * s
	var ink := Color(Color("3a2a44"), a)
	var body := Rect2(c + Vector2(-w * 0.5, -h * 0.5), Vector2(w, h))
	_root.draw_rect(body.grow(6.0 * s), ink)
	_root.draw_rect(body, Color(Color("9aa4ad"), a))
	_root.draw_rect(Rect2(body.position + Vector2(0, h * 0.35), Vector2(w, h * 0.3)), Color(band, a))
	_root.draw_circle(c + Vector2(0, h * 0.5 * 0.0), 42.0 * s, ink)
	_root.draw_circle(c, 36.0 * s, Color(planet_color, a))
	if open > 0.0:   # the dark inside
		_root.draw_rect(Rect2(body.position + Vector2(10 * s, -10 * s), Vector2(w - 20 * s, 18 * s)), Color(Color("2a2f3a"), a))
	var hinge := body.position + Vector2(w, 0)
	var ang := -open * 1.9
	_root.draw_set_transform(hinge, ang)
	_root.draw_rect(Rect2(Vector2(-w - 10 * s, -30 * s), Vector2(w + 20 * s, 30 * s)).grow(5.0 * s), ink)
	_root.draw_rect(Rect2(Vector2(-w - 10 * s, -30 * s), Vector2(w + 20 * s, 30 * s)), Color(Color("c3ccd3"), a))
	_root.draw_set_transform(Vector2.ZERO, 0.0)
