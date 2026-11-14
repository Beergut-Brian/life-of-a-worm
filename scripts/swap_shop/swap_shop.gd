## The Mole's swap shop, in a nook in the dirt ring. The Mole is a Jarling: never food, never a
## threat, drawn with a soft friend outline. When a worm comes near he pops out of the wall,
## startled, squints and apologises (bark + a sheepish bubble), then shows his offer as a
## PictoBubble: [the thing you carry] -> [seed][seed]. Carry something (hold X) up to him and press
## A: he keeps it on his shelf and two seeds pop out for you (carry them to castings: gardens). The
## seeds match what you gave when a small seed of that flavour exists (a stone thing brings pebbles
## for a rock garden, a bug thing bug eggs), else plain seeds (`seed_for`). No
## worm about for a while and he goes back into the wall. Everything is saved ("swap_shop").
class_name SwapShop
extends Node2D

signal traded(player: int, gave: StringName, got: StringName)
signal popped_out()

enum State { HIDDEN, POP, SORRY, OPEN, HAPPY }

## A worm's head within this (px) and he pops out; within TRADE_PX and A trades.
const NOTICE_PX := 110.0
const TRADE_PX := 48.0
const HIDE_AFTER := 4.0
const NOOK_PX := 34.0
const SEEDS_PER_TRADE := 2
## Where the seeds pop out: this far behind him (away from the worm) and apart (px).
const GIFT_BACK_PX := 14.0
const GIFT_SIDE_PX := 9.0
const SHELF := 6
const FOOD_SCRIPT := preload("res://scripts/arena/arena_food.gd")
const SEED := preload("res://data/foods/seed.tres")
const FOODS_DIR := "res://data/foods/"

static var _plantables: Array[RingFood] = []

var world: PolarWorld
var creature_id := &"mole"
var state := State.HIDDEN
## Things worms swapped to him, newest last (he keeps them on his shelf).
var kept: Array[StringName] = []
var trades := 0
## Loose seeds he gave that nobody has picked up yet (saved, so a quit loses none).
var loose: Array[Node2D] = []
var _t := 0.0
var _state_t := 0.0
var _alone := 0.0
var _met := false
## Players whose worm is ready to trade this frame (the level's hint and glyph read it).
var ready_for: Dictionary = {}
## His visits: he pops out of tunnel walls beside a worm digging far away (L-09).
var visit: MoleVisit


func _ready() -> void:
	add_to_group(&"creature")
	add_to_group(&"jarling")
	_face_up()
	PictoBubble.register_prefix("food:", _draw_food_pic)
	PictoBubble.register(&"swap_arrow", _draw_arrow_pic)
	visit = MoleVisit.new()
	visit.name = "Visit"
	visit.shop = self
	add_child(visit)


func _face_up() -> void:
	rotation = position.angle() + PI / 2.0   # local -y points away from the core


## A fresh planet: the nook is dug (a small room the Mole keeps, part of the dirt).
func carve_nook() -> void:
	if world == null:
		return
	var c := world.shape.cell_at(position)
	var n := ceili(NOOK_PX / 16.0) + 1
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			var cell := c + Vector2i(x, y)
			if world.shape.center_of(cell).distance_to(position) <= NOOK_PX and world.is_edible_by(1, cell):
				world.dig(cell)
	world.add_keep_zone(position, NOOK_PX + 16.0)


func mole_position() -> Vector2:
	return position + Vector2.from_angle(rotation + PI / 2.0) * 10.0   # his feet, on the nook floor


func _physics_process(delta: float) -> void:
	_t += delta
	_state_t += delta
	ready_for.clear()
	var near := false
	for w in Worm.all():
		var d := (w.head.global_position - global_position).length()
		if d <= NOTICE_PX:
			near = true
		if can_trade(w):
			ready_for[w.player] = true
			if _a_pressed(w):
				trade(w)
	_alone = 0.0 if near else _alone + delta
	match state:
		State.HIDDEN:
			if near and (visit == null or not visit.is_out()):
				pop_out()
		State.POP:
			if _state_t >= 0.5:
				_set_state(State.SORRY)
				Audio.play("mole_sorry")
		State.SORRY:
			if _state_t >= 1.4:
				_set_state(State.OPEN)
		State.HAPPY:
			if _state_t >= 1.2:
				_set_state(State.OPEN)
		State.OPEN:
			if _alone >= HIDE_AFTER:
				_set_state(State.HIDDEN)
				Audio.play("mole_hide")
	queue_redraw()


func _set_state(s: int) -> void:
	state = s
	_state_t = 0.0


func pop_out() -> void:
	if state != State.HIDDEN:
		return
	_set_state(State.POP)
	Audio.play("mole_pop")
	if visit != null:
		visit.dig_t = 0.0
	popped_out.emit()


func is_out() -> bool:
	return state != State.HIDDEN


## A worm can trade when it is carrying something that isn't a seed or a creature, close to him,
## and he is out of the wall.
func can_trade(w: Worm) -> bool:
	if state == State.HIDDEN or state == State.POP:
		return false
	var c := w.carrying
	if c == null or not is_instance_valid(c) or c.has_method("pet_id") or c is Creature or c.data.id == &"seed":
		return false
	return w.head.global_position.distance_to(global_position + mole_position() - position) <= TRADE_PX


func _a_pressed(w: Worm) -> bool:
	if w.autopilot.is_valid():
		return false
	var act := Players.action(w.player, "action")
	return InputMap.has_action(act) and Input.is_action_just_pressed(act)


## The swap: the carried thing goes on his shelf, two seeds pop out toward the worm.
func trade(w: Worm) -> bool:
	if not can_trade(w):
		Audio.play("boop")
		return false
	var item: Node2D = w.carrying
	var id: StringName = item.data.id
	w.carrying = null
	item.call("take")
	kept.append(id)
	if kept.size() > SHELF:
		kept.remove_at(0)
	trades += 1
	var got := seed_for(item.data)
	var toward := (w.head.global_position - global_position).normalized()
	# They pop out behind him, away from the worm: in front, a worm waiting at the counter swallowed
	# one the same frame, so the kid saw him give one seed, not two.
	for i in SEEDS_PER_TRADE:
		var at := mole_position() - toward * GIFT_BACK_PX + toward.orthogonal() * (i - 0.5) * 2.0 * GIFT_SIDE_PX
		_give_seed(at, true, got)
	Audio.play("swap")
	_set_state(State.HAPPY)
	w._pop(w.look, 1.2)
	traded.emit(w.player, id, got.id)
	return true


## What he gives for `gave`: the smallest seed (a food that plants a garden) of the same flavour, if
## one is no bigger than a plain seed, so a stone thing brings pebbles and a bug thing bug eggs.
## Anything else, and anything that is itself a seed (so a swap never copies a seed), brings plain
## seeds. Read from data/foods, so a new seed food needs no code.
static func seed_for(gave: FoodData) -> FoodData:
	if gave == null or (gave is RingFood and (gave as RingFood).plants != &""):
		return SEED
	if _plantables.is_empty():
		for f in ResourceLoader.list_directory(FOODS_DIR):
			if f.ends_with(".tres"):
				var r := load(FOODS_DIR + f)
				if r is RingFood and (r as RingFood).plants != &"":
					_plantables.append(r)
		_plantables.sort_custom(func(a: RingFood, b: RingFood) -> bool:
			# the plain seed first among equals, so a later root seed (D105 cherry pit) never takes its place
			if a.size_stage != b.size_stage:
				return a.size_stage < b.size_stage
			if (a.id == SEED.id) != (b.id == SEED.id):
				return a.id == SEED.id
			return String(a.id) < String(b.id))
	for r in _plantables:
		if r.plants == gave.flavour and r.size_stage <= SEED.size_stage:
			return r
	return SEED


func _give_seed(at: Vector2, pop: bool, what: FoodData = SEED) -> Node2D:
	var f: Node2D = FOOD_SCRIPT.new()
	f.data = what
	f.position = at
	get_parent().add_child(f)
	f.home = at
	loose.append(f)
	f.taken.connect(func(n: Node2D) -> void:
		loose.erase(n)
		n.queue_free())
	if pop:
		f.scale = Vector2.ZERO
		f.create_tween().tween_property(f, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	return f


func _exit_tree() -> void:
	for f in loose:
		if is_instance_valid(f):
			f.queue_free()
	loose.clear()


func to_dict() -> Dictionary:
	var l := []
	for f in loose:
		if is_instance_valid(f):
			l.append([f.position.x, f.position.y, String(f.data.id)])
	return { "kept": kept.map(func(k): return String(k)), "trades": trades, "loose": l, "carved": true }


func from_dict(d: Dictionary) -> void:
	kept.clear()
	for k in d.get("kept", []):
		kept.append(StringName(k))
	trades = int(d.get("trades", 0))
	for e in d.get("loose", []):
		var what: FoodData = SEED
		if e.size() > 2:   # older tins saved only the spot: those were plain seeds
			var f := _food(StringName(e[2]))
			what = f if f else SEED
		_give_seed.call_deferred(Vector2(e[0], e[1]), false, what)


# --- look -----------------------------------------------------------------------------------------

func _draw() -> void:
	var feet := Vector2(0, 10)
	# His shelf of swapped things along the back of the nook.
	draw_line(Vector2(-22, -14), Vector2(22, -14), Color("7a5230"), 2.0)
	for i in kept.size():
		var f: FoodData = _food(kept[i])
		var p := Vector2(-18 + i * 7.0, -17)
		draw_circle(p, 3.0, Color("2a1a14"))
		draw_circle(p, 2.4, f.color if f else Color.WHITE)
	# Molehill lump in the wall when he is inside: a twitching nose pokes out now and then.
	var rise := 0.0
	var face := MoleLook.Face.SQUINT
	var bow := 0.0
	match state:
		State.HIDDEN:
			draw_circle(feet + Vector2(0, 2), 9.0, Color("5a4030"))
			if fmod(_t, 3.0) < 0.5:
				draw_circle(feet + Vector2(0, -6), 2.0, MoleLook.PINK)
				draw_circle(feet + Vector2(0, -7.5), 0.9, MoleLook.NOSE)
		State.POP:
			rise = clampf(_state_t / 0.25, 0.0, 1.0)
			face = MoleLook.Face.STARTLED
		State.SORRY:
			rise = 1.0
			face = MoleLook.Face.SORRY
			bow = sin(clampf(_state_t / 1.0, 0.0, 1.0) * PI) * 0.6
		State.HAPPY:
			rise = 1.0
			face = MoleLook.Face.HAPPY
		_:
			rise = 1.0
			face = MoleLook.Face.HOPEFUL if not ready_for.is_empty() else MoleLook.Face.SQUINT
	if rise > 0.0:
		MoleLook.draw(self, feet + Vector2(0, (1.0 - rise) * 12.0), 0.9, face, _t, bow, rise)
	# Bubbles: wordless, upright in the nook.
	var tip := feet + Vector2(0, -24)
	match state:
		State.POP:
			PictoBubble.draw(self, tip, [&"exclaim"], 1.0, 0.6)
		State.SORRY:
			PictoBubble.draw(self, tip, [&"face_sheepish"], 1.0, 0.6)
		State.HAPPY:
			PictoBubble.draw(self, tip, [&"heart", &"face_happy"], 1.0, 0.6)
		State.OPEN:
			var give := &"star"
			var got := &"food:seed"
			for w in Worm.all():
				if w.carrying != null and is_instance_valid(w.carrying) and not w.carrying.has_method("pet_id") and w.carrying.data.id != &"seed":
					give = StringName("food:" + String(w.carrying.data.id))
					got = StringName("food:" + String(seed_for(w.carrying.data).id))
			PictoBubble.draw(self, tip, [give, &"swap_arrow", got, got], 1.0, 0.6)
			if not ready_for.is_empty():
				var a := 0.4 + 0.6 * absf(sin(_t * 5.0))
				UiStyle.draw_glyph(self, tip + Vector2(0, -28), 12.0, "a", a)


func _food(id: StringName) -> FoodData:
	var p := "res://data/foods/%s.tres" % id
	return load(p) if ResourceLoader.exists(p) else null


func _draw_food_pic(ci: CanvasItem, id: StringName, c: Vector2, s: float, a: float) -> void:
	var f := _food(StringName(String(id).trim_prefix("food:")))
	var col := f.color if f else Color.WHITE
	var r := s * 0.3
	ci.draw_circle(c, r + s * 0.05, Color(MoleLook.INK, a))
	ci.draw_circle(c, r, Color(col, a))
	ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.4), r * 0.3, Color(1, 1, 1, 0.6 * a))


func _draw_arrow_pic(ci: CanvasItem, _id: StringName, c: Vector2, s: float, a: float) -> void:
	var u := s / 22.0
	var ink := Color(MoleLook.INK, a)
	ci.draw_line(c + Vector2(-7, -2) * u, c + Vector2(6, -2) * u, ink, 1.6 * u)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(4, -5) * u, c + Vector2(8, -2) * u, c + Vector2(4, 1) * u]), ink)
	ci.draw_line(c + Vector2(7, 3) * u, c + Vector2(-6, 3) * u, ink, 1.6 * u)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 0) * u, c + Vector2(-8, 3) * u, c + Vector2(-4, 6) * u]), ink)
