## The final sprite for a food or creature (look B with A's faces, D92), put on as a child of the
## node that already runs it, so gameplay code stays where it is. Sheets: 4 columns (calm, blink,
## wide-eyed, smug) x 2 rows (idle/walk/flap frames), from scripts/look/gen/make_sprites.py.
## It mirrors the host's own state: `_scared`/`_carried` -> wide-eyed, `_smug`/stalking -> smug,
## a creature bigger than the nearest worm -> smug, else calm with a blink. The host's procedural
## drawing is hidden with self_modulate (birds keep theirs: it carries the peck shadow).
class_name FaceSprite
extends Sprite2D

enum Mood { CALM, BLINK, WIDE, SMUG }

const FOOD_DIR := "res://assets/sprites/food/%s.png"
const CREATURE_DIR := "res://assets/sprites/creatures/%s.png"

## Summed _process cost of every FaceSprite this frame (LookDirector reads and resets it).
static var usec := 0

var host: Node2D
var mood := Mood.CALM
var _t := 0.0
var _row_t := 0.0
var _row := 0
var _last := Vector2.INF
var _kind := &"food"


## The sheet for a food or creature id (creatures first for creatures), or null.
static func sheet_for(id: StringName, creature := false) -> Texture2D:
	var order := [CREATURE_DIR, FOOD_DIR] if creature else [FOOD_DIR, CREATURE_DIR]
	for d in order:
		var p: String = d % id
		if ResourceLoader.exists(p):
			return load(p)
	return null


## Puts a FaceSprite on `node` if it has a sheet; returns it (or null). Safe to call twice.
static func attach(node: Node2D) -> FaceSprite:
	if node.has_meta(&"face_sprite"):
		return node.get_meta(&"face_sprite")
	var kind := &"food"
	var id: StringName = &""
	if node is ApexBeetle:
		kind = &"apex"
		id = &"apex_beetle"
	elif node is Bird:
		kind = &"bird"
		id = (node as Bird).data.id if (node as Bird).data else &"bird"
	elif node is Creature:
		kind = &"creature"
		id = (node as Creature).data.id if (node as Creature).data else &""
	elif "data" in node and node.data is FoodData:
		id = node.data.id
	if id == &"":
		node.set_meta(&"face_sprite", null)
		return null
	var tex := sheet_for(id, kind != &"food")
	if tex == null:
		node.set_meta(&"face_sprite", null)
		return null
	var s := FaceSprite.new()
	s.name = "FaceSprite"
	s.texture = tex
	s.hframes = 4
	s.vframes = 2
	s.host = node
	s._kind = kind
	node.add_child(s)
	node.set_meta(&"face_sprite", s)
	if kind != &"bird":
		node.self_modulate.a = 0.0
	return s


func _process(delta: float) -> void:
	if host == null or not is_instance_valid(host):
		return
	var t0 := Time.get_ticks_usec()
	_step(delta)
	usec += Time.get_ticks_usec() - t0


func _step(delta: float) -> void:
	_t += delta
	visible = not _host_gone()
	if not visible:
		return
	mood = _mood()
	var moving := _last != Vector2.INF and host.position.distance_squared_to(_last) > 0.01
	_last = host.position
	var every := 0.6
	match _kind:
		&"creature", &"apex":
			every = 0.14 if moving else 0.5
		&"bird":
			every = 0.11
	_row_t += delta
	if _row_t >= every:
		_row_t = 0.0
		_row = 1 - _row
	frame = _row * 4 + int(mood)
	_place()


func _host_gone() -> bool:
	if _kind == &"apex":
		return host.mode == ApexBeetle.Mode.GONE
	return bool(host.get(&"_gone")) if &"_gone" in host else false


func _mood() -> Mood:
	if _kind == &"apex":
		var near = host._nearest()
		var w: Worm = near[0]
		if w != null and host.is_food_for(w):
			return Mood.WIDE
		if host.mode in [ApexBeetle.Mode.STALK, ApexBeetle.Mode.WINDUP, ApexBeetle.Mode.LUNGE]:
			return Mood.SMUG
		if w != null and near[1] < ApexBeetle.NOTICE:
			return Mood.SMUG
		return Mood.BLINK if fmod(_t, 3.1) < 0.14 else Mood.CALM
	var scared: bool = host.get(&"_scared") or host.get(&"_carried")
	if scared:
		return Mood.WIDE
	if float(host.get(&"_smug")) > 0.0:
		return Mood.SMUG
	if host is Creature:
		var c := host as Creature
		if c.mode == Creature.Mode.STALK or c.mode == Creature.Mode.WINDUP or _bigger_than_near_worm(c.data.size_stage, c.data.notice):
			return Mood.SMUG
	elif host is Bird:
		if _bigger_than_near_worm((host as Bird).data.size_stage, 220.0):
			return Mood.SMUG
	return Mood.BLINK if fmod(_t + float(get_instance_id() % 7) * 0.37, 2.6) < 0.12 else Mood.CALM


## A threat looks smug at a smaller worm within `reach` px.
func _bigger_than_near_worm(size_stage: int, reach: float) -> bool:
	for w in Worm.all():
		if w.model and w.model.stage < size_stage and w.head_position().distance_to(host.global_position) < reach:
			return true
	return false


## Mirrors the host's own bob, tremble, wind-up swell and facing.
func _place() -> void:
	var t := float(host.get(&"_t")) if &"_t" in host else _t
	var off := Vector2.ZERO
	var s := 1.0
	rotation = 0.0
	match _kind:
		&"food":
			off.y = sin(t * 3.0) * 0.6
			if host.get(&"_scared") and not host.get(&"_carried"):
				off.x = sin(t * 40.0) * 0.7
		&"creature":
			var c := host as Creature
			s = c.draw_scale()
			if c.mode == Creature.Mode.WINDUP or (c._scared and not c._carried):
				off.x = sin(t * 45.0) * 0.8
			flip_h = c.facing < 0.0
		&"apex":
			var a := host as ApexBeetle
			if a.mode == ApexBeetle.Mode.WINDUP:
				var k: float = a._mode_t / ApexBeetle.WINDUP
				s = 1.0 + 0.25 * k
				off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.5 * k
			elif a.mode == ApexBeetle.Mode.FULL:
				s = 1.15
			rotation = a.facing.angle()
		&"bird":
			s = 1.08
	position = (off).round()
	scale = Vector2(s, s)
