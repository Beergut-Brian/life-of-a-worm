## A player's worm: head CharacterBody2D steered by the left stick, a kinematic segment chain that
## follows snake-style, a mouth that opens as food comes near, eat on contact, A burst, B wiggle,
## hold X to carry. Body data lives in `model` (WormGrowth); every number that traits can change
## is read from `model.stats` (WormStats) by stat name. This file never names a trait.
class_name Worm
extends Node2D

signal ate(player: int, what: StringName, growth: float)
signal segment_added(player: int, flavour: StringName)
signal segment_lost(player: int)
signal trait_earned(player: int, trait_id: StringName)
signal traits_changed(player: int, active: Array[StringName])
signal stage_changed(player: int, from: int, to: int)
signal carried(player: int, what: StringName)
signal dropped(player: int, what: StringName)
signal eaten_by(player: int, creature: StringName)
signal booped(player: int, other: int)

const ART := "res://assets/proto/worm/"
const SEGMENT_TEX := preload("res://assets/proto/worm/segment.png")
const BAND_TEX := preload("res://assets/proto/worm/band.png")
const HEAD_TEX := preload("res://assets/proto/worm/head.png")
const HEART_TEX := preload("res://assets/proto/worm/heart.png")
const NOTE_TEX := preload("res://assets/proto/worm/note.png")
const STAR_TEX := preload("res://assets/proto/worm/star.png")
const SHEEN_SHADER := preload("res://scripts/worm/worm_sheen.gdshader")
const BOOP_DIST := 14.0
const BOOP_COOLDOWN := 1.2
const BONK_COOLDOWN := 0.5
const DROP_BLOCK := 0.8
const CHOMP_CUES := 5
## Where a part of each slot sits. Slots are data names, not traits.
const SLOT_OFFSET := { &"head": Vector2(2, -1), &"crown": Vector2(-2, -12), &"back": Vector2(0, -8), &"tail": Vector2(-7, 0) }
const BACK_EVERY := 3

static var _all: Array[Worm] = []
static var _faces := {}

@export var player := 0
## Optional brain for demos and tests: func(worm) -> Dictionary with the keys of _read_intent().
var autopilot: Callable
var model: WormGrowth
var rules: WormRules
var heading := 0.0
var carrying: Node2D = null
var wall_open := false

var _positions: Array[Vector2] = []
var _seg_nodes: Array[Node2D] = []
var _burst_left := 0.0
var _burst_cool := 0.0
var _dance := 0.0
var _boop_cool := 0.0
var _bonk_cool := 0.0
var _dizzy := 0.0
var _time := 0.0
var _mouth := 0
var _sheen_mat: ShaderMaterial
var _part_nodes := {}          # slot -> Sprite2D (head/crown on the head)
var _parts_sig := ""
var _wall: TraitWall

@onready var head: CharacterBody2D = $Head
@onready var head_sprite: Sprite2D = $Head/Look/Sprite
@onready var face: Sprite2D = $Head/Look/Face
@onready var look: Node2D = $Head/Look
@onready var light: PointLight2D = $Head/Light
@onready var body: Node2D = $Body
@onready var dust: CPUParticles2D = $Head/Dust
@onready var crumbs: CPUParticles2D = $Head/Crumbs
@onready var fx: Node2D = $FX


static func of(p: int) -> Worm:
	for w in _all:
		if is_instance_valid(w) and w.player == p:
			return w
	return null


static func all() -> Array[Worm]:
	var out: Array[Worm] = []
	for w in _all:
		if is_instance_valid(w):
			out.append(w)
	return out


static func stats(p: int) -> WormStats:
	var w := of(p)
	if w != null and w.model != null:
		return w.model.stats
	var r := WormRules.default_rules()
	return WormStats.resolve([], r.base_stats)


func _enter_tree() -> void:
	if not self in _all:
		_all.append(self)
	add_to_group("worms")


func _exit_tree() -> void:
	_all.erase(self)


func _ready() -> void:
	if model == null:
		model = WormGrowth.new()
	rules = model.rules
	model.segment_added.connect(_on_segment_added)
	model.segment_lost.connect(_on_segment_lost)
	model.stage_changed.connect(_on_stage_changed)
	model.trait_earned.connect(_on_trait_earned)
	model.traits_changed.connect(_on_traits_changed)
	_sheen_mat = ShaderMaterial.new()
	_sheen_mat.shader = SHEEN_SHADER
	var col: Color = Players.COLOR[player]
	head_sprite.texture = HEAD_TEX
	head_sprite.modulate = col
	head_sprite.material = _sheen_mat
	face.texture = _face_tex(0)
	light.texture = _light_texture()
	dust.color = Color(0.85, 0.72, 0.55)
	_positions.clear()
	_positions.append(head.position)
	for i in model.segments.size():
		_positions.append(head.position - Vector2(spacing() * (i + 1), 0))
		_add_segment_node(model.segments[i], false)
	_refresh_parts(false)


## Drop-in: the body unfolds out of the head with a pop (visual only; physics never scales).
func hatch() -> void:
	Audio.play("hatch")
	body.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(body, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	_pop(look, 1.8)
	_ring_fx(Players.COLOR[player])


## The trait wall (pictures only): Y opens and closes it, left / right picks, A equips / unequips.
func set_wall_open(on: bool) -> void:
	if on == wall_open:
		return
	wall_open = on
	if _wall == null:
		_wall = TraitWall.new()
		_wall.worm = self
		add_child(_wall)
	_wall.set_open(on)
	Audio.play("wall_open" if on else "wall_close")


func spacing() -> float:
	return model.stats.value("segment_spacing", 9.0)


## Everything the camera should keep on screen: head and every segment, in global space.
func body_rect() -> Rect2:
	var r := Rect2(head.global_position, Vector2.ZERO)
	for p in _positions:
		r = r.expand(to_global(p))
	return r


func head_position() -> Vector2:
	return head.global_position


func mouth_position() -> Vector2:
	return head.global_position + Vector2.from_angle(heading) * 9.0


## Swallow a food: full growth and its flavour to me, a share (plain) to every partner.
func feed(food: FoodData) -> void:
	var g := food.growth
	model.add_growth(g, food.flavour)
	ate.emit(player, food.id, g)
	var rel := clampi(food.size_stage - model.stage + 3, 1, CHOMP_CUES)
	Audio.play("chomp_%d" % rel)
	crumbs.color = food.color
	crumbs.restart()
	crumbs.emitting = true
	_pop(look, 1.25)
	for w in Worm.all():
		if w != self:
			w.receive_share(g * rules.partner_share)


## The partner's share of a bite: growth with no flavour.
func receive_share(amount: float) -> void:
	model.add_growth(amount, &"")
	_float_fx(STAR_TEX, head.position + Vector2(0, -12), Color(1, 1, 1, 0.8), 0.5)


## Gulped by a bigger thing: one segment shorter, dizzy; never a stage, never a trait.
func get_eaten(creature: StringName) -> void:
	model.lose_segment()
	_dizzy = 2.0
	Audio.play("eaten")
	eaten_by.emit(player, creature)


func can_eat(food: FoodData) -> bool:
	var bonus := model.stats.value("bite_bonus/" + String(food.flavour))
	return food.size_stage <= model.stage + int(round(bonus))


func _physics_process(delta: float) -> void:
	_time += delta
	var stats := model.stats
	var intent := _read_intent()
	var wall_was := wall_open
	if intent.tackle:
		set_wall_open(not wall_open)
	elif wall_open:
		_wall.handle(intent.nav, intent.confirm, intent.wiggle)
	if wall_open or wall_was:
		intent.move = Vector2.ZERO
		intent.burst = false
		intent.wiggle = false
	_burst_cool = maxf(0.0, _burst_cool - delta)
	_boop_cool = maxf(0.0, _boop_cool - delta)
	_bonk_cool = maxf(0.0, _bonk_cool - delta)
	_dizzy = maxf(0.0, _dizzy - delta)
	_dance = maxf(0.0, _dance - delta)
	if intent.burst and _burst_cool <= 0.0:
		_burst_left = stats.value("burst_time")
		_burst_cool = _burst_left + stats.value("burst_cooldown")
		Audio.play("burst")
		_pop(look, 1.2)
	if intent.wiggle:
		_wiggle()
	var move: Vector2 = intent.move
	var speed := 0.0
	if move.length() > 0.2:
		var want := move.angle()
		var turn := stats.value("turn_rate", 10.0) * delta
		heading = rotate_toward(heading, want, turn)
		speed = stats.value("speed") * minf(move.length(), 1.0)
	if _burst_left > 0.0:
		_burst_left -= delta
		speed = maxf(speed, stats.value("speed")) * stats.value("burst_speed", 1.0)
	if _dizzy > 0.0:
		speed *= 0.5
	speed *= _zone_factor(stats)
	head.velocity = Vector2.from_angle(heading) * speed
	head.move_and_slide()
	dust.emitting = _burst_left > 0.0
	_follow()
	_eat_and_carry(intent.carry, stats, delta)
	_boop_check()
	_update_look(delta, stats)


## Stick, A, B, X from the player's pad (or the autopilot).
func _read_intent() -> Dictionary:
	if autopilot.is_valid():
		var d: Dictionary = autopilot.call(self)
		for k in ["move", "burst", "wiggle", "carry", "tackle", "nav", "confirm"]:
			if not d.has(k):
				d[k] = Vector2.ZERO if k == "move" else (0 if k == "nav" else false)
		return d
	var nav := 0
	if Input.is_action_just_pressed(Players.action(player, "move_left")):
		nav = -1
	elif Input.is_action_just_pressed(Players.action(player, "move_right")):
		nav = 1
	return {
		"move": Players.move_vector(player),
		"burst": Input.is_action_just_pressed(Players.action(player, "action")),
		"wiggle": Input.is_action_just_pressed(Players.action(player, "jump")),
		"carry": Input.is_action_pressed(Players.action(player, "carry")),
		"tackle": Input.is_action_just_pressed(Players.action(player, "tackle")),
		"nav": nav,
		"confirm": Input.is_action_just_pressed(Players.action(player, "action")),
	}


func _zone_factor(stats: WormStats) -> float:
	var f := 1.0
	for z in get_tree().get_nodes_in_group("slow_zone"):
		if z.has_method("contains") and z.contains(head.global_position):
			f *= clampf(1.0 - float(z.drag) * stats.value("drag/" + String(z.kind), 1.0), 0.1, 1.0)
	return f


## Kinematic follow: each segment keeps `spacing` from the one in front, like a rope.
func _follow() -> void:
	var sp := spacing()
	_positions[0] = head.position
	for i in range(1, _positions.size()):
		var d := _positions[i] - _positions[i - 1]
		var l := d.length()
		if l > sp:
			_positions[i] = _positions[i - 1] + d / l * sp
		elif l < 0.001:
			_positions[i] = _positions[i - 1] - Vector2.from_angle(heading) * sp


func _eat_and_carry(carry_held: bool, stats: WormStats, delta: float) -> void:
	var mouth := mouth_position()
	var reach := stats.value("mouth_radius", 8.0)
	var pull_r := stats.value("pull_radius")
	var nearest := INF
	if carrying != null:
		if not is_instance_valid(carrying):
			carrying = null
		elif carry_held:
			carrying.global_position = mouth + Vector2.from_angle(heading) * 3.0
		else:
			var what: StringName = carrying.data.id
			carrying.call("set_carried", false, DROP_BLOCK)
			carrying = null
			Audio.play("drop")
			_pop(look, 1.15)
			dropped.emit(player, what)
	for f in get_tree().get_nodes_in_group("food"):
		if f == carrying or not f.call("is_available"):
			continue
		var data: FoodData = f.data
		var d: float = f.global_position.distance_to(mouth)
		var edible := can_eat(data)
		if edible:
			nearest = minf(nearest, d - data.radius)
		if pull_r > 0.0 and edible and d < pull_r and d > reach:
			f.call("drift_toward", mouth, stats.value("pull_speed") * delta)
		if d > reach + data.radius:
			continue
		if not edible:
			if _bonk_cool <= 0.0:
				_bonk_cool = BONK_COOLDOWN
				_burst_left = 0.0
				head.position -= Vector2.from_angle(heading) * 6.0
				Audio.play("bonk")
				f.call("smug")
				_pop(look, 0.8)
			continue
		if carry_held and carrying == null:
			carrying = f
			f.call("set_carried", true)
			Audio.play("carry")
			_pop(look, 1.15)
			carried.emit(player, data.id)
		elif not carry_held:
			f.call("take")
			feed(data)
	if carrying != null:
		_mouth = 1
	elif nearest < 10.0:
		_mouth = 2
	elif nearest < 30.0:
		_mouth = 1
	else:
		_mouth = 0


func _wiggle() -> void:
	_dance = 0.7
	Audio.play("wiggle")
	for i in 3:
		_float_fx(NOTE_TEX, head.position + Vector2(randf_range(-8, 8), -10), Color(1, 1, 1), 0.8)
	var r := model.stats.value("wiggle_radius")
	var hop := model.stats.value("wiggle_hop")
	for f in get_tree().get_nodes_in_group("food"):
		if f.call("is_available") and f != carrying and f.global_position.distance_to(head.global_position) < r:
			f.call("hop_toward", head.global_position, hop)


func _boop_check() -> void:
	for w in Worm.all():
		if w == self or w.player < player:
			continue
		if w.head.global_position.distance_to(head.global_position) < BOOP_DIST and _boop_cool <= 0.0 and w._boop_cool <= 0.0:
			_boop_cool = BOOP_COOLDOWN
			w._boop_cool = BOOP_COOLDOWN
			Audio.play("boop")
			var mid := (head.global_position + w.head.global_position) * 0.5 - global_position
			_float_fx(HEART_TEX, mid + Vector2(0, -8), Color(1, 1, 1), 1.0)
			_pop(look, 1.2)
			w._pop(w.look, 1.2)
			booped.emit(player, w.player)
			w.booped.emit(w.player, player)


func _update_look(_delta: float, stats: WormStats) -> void:
	var facing_left := cos(heading) < 0.0
	look.rotation = heading
	look.scale.y = -absf(look.scale.y) if facing_left else absf(look.scale.y)
	face.texture = _face_tex(_mouth)
	light.enabled = stats.value("light_radius") > 0.0
	light.texture_scale = maxf(0.01, stats.value("light_radius"))
	light.energy = 1.1 + 0.15 * sin(_time * 3.0)
	_sheen_mat.set_shader_parameter("sheen", stats.value("sheen"))
	var squash := _burst_left > 0.0
	var n := _seg_nodes.size()
	for i in n:
		var node := _seg_nodes[i]
		var p := _positions[i + 1]
		var ahead := _positions[i]
		var dir := (ahead - p)
		var ang := dir.angle() if dir.length() > 0.01 else heading
		var off := Vector2.ZERO
		if _dance > 0.0:
			off = Vector2.from_angle(ang + PI / 2) * sin(_time * 22.0 - i * 0.9) * 3.0
		elif _dizzy > 0.0:
			off = Vector2.from_angle(ang + PI / 2) * sin(_time * 6.0 - i * 0.5) * 1.5
		node.position = p + off
		node.rotation = ang
		var base_scale: float = node.get_meta("pop", 1.0)
		node.scale = Vector2(base_scale * (0.75 if squash else 1.0), base_scale * (1.25 if squash else 1.0))
	for slot in _part_nodes:
		var s: Sprite2D = _part_nodes[slot]
		var spin: float = s.get_meta("spin", 0.0)
		if spin > 0.0:
			s.scale.y = s.get_meta("pop", 1.0) * (0.55 + 0.45 * absf(cos(_time * spin * TAU)))
	if _dizzy > 0.0 and int(_time * 10.0) % 4 == 0:
		_float_fx(STAR_TEX, head.position + Vector2.from_angle(_time * 8.0) * 10.0, Color(1, 1, 1), 0.3)


func _face_tex(open_amt: int) -> Texture2D:
	var key := "%sface_p%d_%d.png" % [ART, player + 1, open_amt]
	if not _faces.has(key):
		_faces[key] = load(key)
	return _faces[key]


func _light_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 128
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


func _add_segment_node(flavour: StringName, pop := true) -> void:
	var node := Node2D.new()
	node.z_index = -1 - _seg_nodes.size()
	var base := Sprite2D.new()
	base.texture = SEGMENT_TEX
	base.modulate = Players.COLOR[player]
	base.material = _sheen_mat
	node.add_child(base)
	var band := Sprite2D.new()
	band.name = "Band"
	band.texture = BAND_TEX
	band.visible = flavour != &""
	band.modulate = rules.flavour_color(flavour)
	band.material = _sheen_mat
	node.add_child(band)
	body.add_child(node)
	_seg_nodes.append(node)
	if pop:
		node.set_meta("pop", 0.1)
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void: node.set_meta("pop", v), 0.1, 1.5, 0.12)
		tw.tween_method(func(v: float) -> void: node.set_meta("pop", v), 1.5, 1.0, 0.12)


func _on_segment_added(flavour: StringName) -> void:
	var last := _positions[_positions.size() - 1]
	var prev := _positions[_positions.size() - 2] if _positions.size() > 1 else last
	_positions.append(last + (last - prev).normalized() * spacing() if last != prev else last - Vector2(spacing(), 0))
	_add_segment_node(flavour)
	_refresh_parts(false)
	Audio.play("segment_pop")
	segment_added.emit(player, flavour)


func _on_segment_lost() -> void:
	if _seg_nodes.is_empty():
		return
	var node: Node2D = _seg_nodes.pop_back()
	_positions.pop_back()
	_float_fx(STAR_TEX, node.position, Color(1, 1, 1), 0.6)
	node.queue_free()
	_refresh_parts(false)
	segment_lost.emit(player)


func _on_stage_changed(from: int, to: int) -> void:
	Audio.play("stage_up")
	_pop(look, 1.6)
	stage_changed.emit(player, from, to)


func _on_trait_earned(id: StringName, _equipped: bool) -> void:
	var t := rules.find_trait(id)
	if t != null:
		Audio.play(t.cue)
		_ring_fx(t.color)
	trait_earned.emit(player, id)


func _on_traits_changed(active: Array[StringName]) -> void:
	_refresh_parts(true)
	Audio.play("trait_swap")
	traits_changed.emit(player, active)


## Rebuild every trait part from the resolved stats. pop: parts that are new pop on.
func _refresh_parts(pop: bool) -> void:
	var parts: Dictionary = model.stats.parts
	var sig := str(parts.keys()) + str(_seg_nodes.size())
	for slot in parts:
		sig += String(parts[slot].trait)
	if sig == _parts_sig and not pop:
		return
	var before := {}
	for slot in _part_nodes:
		before[slot] = _part_nodes[slot].get_meta("trait", &"")
		_part_nodes[slot].queue_free()
	_part_nodes.clear()
	for node in _seg_nodes:
		for c in node.get_children():
			if c.has_meta("part"):
				c.queue_free()
	_parts_sig = sig
	for slot in parts:
		var info: Dictionary = parts[slot]
		var is_new: bool = pop and before.get(slot, &"") != info.trait
		match slot:
			&"head", &"crown":
				var s := _part_sprite(info, SLOT_OFFSET.get(slot, Vector2.ZERO))
				s.z_index = 2
				look.add_child(s)
				_part_nodes[slot] = s
				if is_new:
					_pop_part(s)
			&"back":
				for i in range(1, _seg_nodes.size(), BACK_EVERY):
					var s := _part_sprite(info, SLOT_OFFSET[slot])
					s.z_index = -1
					_seg_nodes[i].add_child(s)
					if is_new:
						_pop_part(s)
			&"tail":
				if not _seg_nodes.is_empty():
					var s := _part_sprite(info, SLOT_OFFSET[slot])
					_seg_nodes[_seg_nodes.size() - 1].add_child(s)
					if is_new:
						_pop_part(s)
			_:
				for node in _seg_nodes:
					var s := _part_sprite(info, Vector2.ZERO)
					node.add_child(s)
					if is_new:
						_pop_part(s)
				var hs := _part_sprite(info, Vector2.ZERO)
				look.add_child(hs)
				_part_nodes[slot] = hs


func _part_sprite(info: Dictionary, offset: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = info.texture
	s.position = offset + info.get("offset", Vector2.ZERO)
	s.set_meta("part", true)
	s.set_meta("trait", info.trait)
	s.set_meta("spin", info.spin)
	return s


func _pop_part(s: Sprite2D) -> void:
	s.scale = Vector2.ZERO
	s.set_meta("pop", 1.0)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2(1.8, 1.8), 0.15).set_trans(Tween.TRANS_BACK)
	tw.tween_property(s, "scale", Vector2.ONE, 0.2)


func _pop(n: Node2D, amount: float) -> void:
	var sign_y := signf(n.scale.y) if n.scale.y != 0.0 else 1.0
	n.scale = Vector2(amount, amount * sign_y)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2(1.0, sign_y), 0.15)


func _float_fx(tex: Texture2D, at: Vector2, tint: Color, life: float) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = at
	s.modulate = tint
	s.z_index = 10
	fx.add_child(s)
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "position", at + Vector2(randf_range(-4, 4), -18), life)
	tw.tween_property(s, "modulate:a", 0.0, life).set_delay(life * 0.5)
	tw.chain().tween_callback(s.queue_free)


## Trait reveal: a ring in the trait's colour bursts out of the head.
func _ring_fx(c: Color) -> void:
	var ring := WormRing.new()
	ring.color = c
	ring.position = head.position
	ring.z_index = 9
	fx.add_child(ring)
