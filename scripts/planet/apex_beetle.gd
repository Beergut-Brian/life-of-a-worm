## The dirt ring's apex creature, grey-box placeholder: a big round beetle. To a worm that has not
## grown to its size it is a threat: it trundles closer, the `threat_near` rumble plays once, then it
## winds up for a full second (swells, shakes, jaws open, `beetle_windup`) before it lunges. A worm
## it catches pops out of its far end one segment shorter and dizzy; then it is full and dozes.
## Once the worm's body reaches its size (WormGrowth.size_stage() >= size_stage) it flips: pale,
## wide-eyed, it scuttles away (slower than a worm), and eating it is the ring's apex bite.
## Never steers a worm. Draws itself (no sprite yet: Art lane, see the report).
class_name ApexBeetle
extends Node2D

enum Mode { WANDER, STALK, WINDUP, LUNGE, FULL, FLEE, GONE }

signal ate_worm(player: int)
signal eaten(player: int)

const SPEED := 30.0
const FLEE_SPEED := 34.0
const LUNGE_SPEED := 190.0
const WINDUP := 1.0
const LUNGE := 0.35
const FULL := 6.0
const NOTICE := 260.0       # px: "within a screen" at stage-1 zoom
const STRIKE := 46.0        # px: starts the wind-up
const BITE := 16.0          # px added to the radius: a lunge that reaches the head eats it
const WANDER_RANGE := 120.0

@export var id := &"apex_beetle"
## Bigger eats smaller: a stage-1 worm is smaller; a worm grown to 2 eats it.
@export var size_stage := 2
## The ring stage whose apex this is (eating it opens size_stage).
@export var ring_stage := 1
@export var radius := 15.0
var world: PolarWorld
var home := Vector2.ZERO
var mode := Mode.WANDER
var facing := Vector2.RIGHT
var target: Worm
var _t := 0.0
var _mode_t := 0.0
var _threat_cool := 0.0
var _wander_to := Vector2.ZERO
var _anim := 0.0


func _ready() -> void:
	add_to_group("creatures")
	if home == Vector2.ZERO:
		home = position
	_wander_to = home


## FOOD for a worm grown to this size, else THREAT (the apex rule: the worm outgrows it).
func relation_to(w: Worm) -> int:
	if w == null or w.model == null:
		return StageRule.IGNORE
	return StageRule.FOOD if w.model.size_stage() >= size_stage else StageRule.THREAT


func is_food_for(w: Worm) -> bool:
	return relation_to(w) == StageRule.FOOD


func _physics_process(delta: float) -> void:
	step(delta)


## One tick (tests call it directly with a fixed delta).
func step(delta: float) -> void:
	if mode == Mode.GONE:
		return
	_t += delta
	_mode_t += delta
	_threat_cool = maxf(0.0, _threat_cool - delta)
	_anim += delta * (3.0 if mode == Mode.WANDER else 8.0)
	var near := _nearest()
	var w: Worm = near[0]
	var d: float = near[1]
	var any_food := w != null and is_food_for(w)
	match mode:
		Mode.WANDER, Mode.STALK:
			if any_food and d < NOTICE * 1.4:
				_set_mode(Mode.FLEE)
			elif w != null and not any_food and d < NOTICE and _threat_cool <= 0.0 and mode == Mode.WANDER:
				target = w
				_threat_cool = 10.0
				Audio.play("threat_near")
				_set_mode(Mode.STALK)
			if mode == Mode.STALK:
				if w == null or any_food or d > NOTICE * 1.5:
					_set_mode(Mode.WANDER)
				else:
					target = w
					_move_toward(w.cam_position(), SPEED, delta)
					if d < STRIKE + radius:
						Audio.play("beetle_windup")
						_set_mode(Mode.WINDUP)
			elif mode == Mode.WANDER:
				if position.distance_to(_wander_to) < 6.0 or _mode_t > 6.0:
					_wander_to = home + Vector2.from_angle(randf() * TAU) * randf_range(20.0, WANDER_RANGE)
					_mode_t = 0.0
				_move_toward(_wander_to, SPEED * 0.6, delta)
		Mode.WINDUP:
			if target and is_instance_valid(target):
				if is_food_for(target):
					_set_mode(Mode.FLEE)
					return
				facing = (target.cam_position() - position).normalized()
			if _mode_t >= WINDUP:
				Audio.play("beetle_lunge")
				_set_mode(Mode.LUNGE)
		Mode.LUNGE:
			_move(facing * LUNGE_SPEED * delta)
			if target and is_instance_valid(target) and not is_food_for(target):
				if target.cam_position().distance_to(position) < radius + BITE:
					_gulp(target)
					return
			if _mode_t >= LUNGE:
				_set_mode(Mode.STALK)
		Mode.FULL:
			if _mode_t >= FULL:
				_set_mode(Mode.WANDER)
		Mode.FLEE:
			if w == null or not any_food:
				_set_mode(Mode.WANDER)
			else:
				var away := (position - w.cam_position()).normalized()
				# Stay round home so the chase is short: lean back toward it when far.
				var back := (home - position) / maxf(WANDER_RANGE * 2.0, 1.0)
				_move_toward(position + (away + back).normalized() * 40.0, FLEE_SPEED, delta)
				if w.cam_position().distance_to(position) < radius + 10.0 * w.size_factor():
					bitten_by(w)
	queue_redraw()


## A worm's mouth reached it while it is food: the apex bite.
func bitten_by(w: Worm) -> void:
	if mode == Mode.GONE or not is_food_for(w):
		return
	_set_mode(Mode.GONE)
	visible = false
	remove_from_group("creatures")
	eaten.emit(w.player)


func is_gone() -> bool:
	return mode == Mode.GONE


func _gulp(w: Worm) -> void:
	# Out of the far end: behind the beetle, on the side away from where it bit.
	var out := global_position - facing * (radius + 14.0)
	w.get_eaten(id, out)
	_set_mode(Mode.FULL)
	ate_worm.emit(w.player)


func _set_mode(m: Mode) -> void:
	mode = m
	_mode_t = 0.0


func _nearest() -> Array:
	var best: Worm = null
	var bd := INF
	for w in Worm.all():
		var d := w.cam_position().distance_to(global_position)
		if d < bd:
			bd = d
			best = w
	return [best, bd]


func _move_toward(p: Vector2, speed: float, delta: float) -> void:
	var v := p - position
	if v.length() < 0.5:
		return
	facing = facing.lerp(v.normalized(), minf(1.0, delta * 4.0)).normalized()
	_move(facing * speed * delta)


## Moves and chews its own tunnel through what a stage-1 mouth could eat (dirt), never stone.
func _move(v: Vector2) -> void:
	var to := position + v
	if world:
		var cell := world.shape.cell_at(to + facing * radius * 0.6)
		if world.is_solid(cell) and not world.is_edible_by(1, cell):
			return  # stone: it turns instead (next frame's wander target)
		for o in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if world.is_edible_by(1, cell + o):
				world.dig(cell + o)
	position = to


func _draw() -> void:
	if mode == Mode.GONE:
		return
	var food := false
	var w: Worm = _nearest()[0]
	if w != null:
		food = is_food_for(w)
	var r := radius
	var swell := 1.0
	var jitter := Vector2.ZERO
	if mode == Mode.WINDUP:
		var k := _mode_t / WINDUP
		swell = 1.0 + 0.25 * k
		jitter = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.5 * k
	elif mode == Mode.FULL:
		swell = 1.15
	draw_set_transform(jitter, facing.angle(), Vector2.ONE * swell)
	var shell := Color("c9b8ff") if food else Color("3b2d63")
	var rim := Color("2a1a14")
	# Legs (three a side), walking.
	for i in 3:
		var x := (i - 1) * r * 0.6
		var wob := sin(_anim * 2.0 + i * 2.1) * r * 0.15
		for sgn in [-1.0, 1.0]:
			draw_line(Vector2(x, sgn * r * 0.6), Vector2(x + wob, sgn * r * 1.25), rim, 3.0)
	draw_circle(Vector2.ZERO, r + 2.0, rim)
	draw_circle(Vector2.ZERO, r, shell)
	draw_line(Vector2(-r, 0), Vector2(r * 0.4, 0), rim, 2.0)   # wing seam
	draw_circle(Vector2(-r * 0.3, -r * 0.35), r * 0.25, shell.lightened(0.35))   # shine
	# Head with eyes: smug half-lids as a threat, wide eyes as food.
	var hc := Vector2(r * 0.95, 0)
	draw_circle(hc, r * 0.55 + 2.0, rim)
	draw_circle(hc, r * 0.55, shell.darkened(0.2))
	for sgn in [-1.0, 1.0]:
		var e := hc + Vector2(r * 0.2, sgn * r * 0.25)
		var er := r * (0.24 if food else 0.18)
		draw_circle(e, er, Color.WHITE)
		draw_circle(e + Vector2(er * 0.3, 0), er * (0.45 if food else 0.6), Color.BLACK)
		if not food:
			draw_line(e + Vector2(-er, -er * 0.2 * sgn), e + Vector2(er, -er * 0.9 * sgn), shell.darkened(0.2), er * 0.9)
	# Jaws: open wide on the wind-up and the lunge.
	var open := 0.15
	if mode == Mode.WINDUP:
		open = 0.15 + 0.6 * (_mode_t / WINDUP)
	elif mode == Mode.LUNGE:
		open = 0.9
	for sgn in [-1.0, 1.0]:
		var base := hc + Vector2(r * 0.45, sgn * r * 0.2)
		draw_line(base, base + Vector2.from_angle(sgn * open).rotated(0) * r * 0.7, rim, 3.0)
	if mode == Mode.FULL:
		for i in 3:   # dozing: little bubbles
			var a := _t * 1.5 + i * 2.0
			draw_circle(hc + Vector2(0, -r) + Vector2(sin(a) * 3.0, -fmod(a * 6.0, 18.0)), 2.0 + i, Color(1, 1, 1, 0.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if food:
		# Sweat drops: it knows.
		draw_circle(Vector2(0, -r * 1.5) + Vector2(sin(_t * 9.0) * 2.0, 0), 2.5, Color("7fd6ff"))


func to_dict() -> Dictionary:
	return { "gone": mode == Mode.GONE, "pos": [position.x, position.y], "home": [home.x, home.y] }


func from_dict(d: Dictionary) -> void:
	var p: Array = d.get("pos", [])
	if p.size() == 2:
		position = Vector2(p[0], p[1])
	var h: Array = d.get("home", [])
	if h.size() == 2:
		home = Vector2(h[0], h[1])
	if d.get("gone", false):
		_set_mode(Mode.GONE)
		visible = false
		remove_from_group("creatures")
