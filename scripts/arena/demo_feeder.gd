## Scripted input for --demo-traits / --perf-traits: pretends to be a pad. It steers P1 to food of
## one flavour at a time until each trait's segments are filled (needs read from the TraitData),
## bursts, wiggles, carries one thing, drops P2 in after the third trait, then opens the trait
## wall and swaps one picture so five traits are on at once. It only ever returns stick/button
## intents; it never moves a worm itself.
extends Node

const ORDER: Array[StringName] = [&"bug", &"stone", &"crystal", &"junk", &"water"]
## The wall swap that ends the demo: this one off, that one on (arena code may name traits).
const WALL_OFF := &"stone_head"
const WALL_ON := &"slick"

var arena: Node2D
var t := 0.0
var _needs := {}
var _state := {}       # player -> per-worm brain state
var _p2_joined := false
var _wall_step := -1
var _wall_t := 0.0
var _logged := {}


func _ready() -> void:
	var rules := WormRules.default_rules()
	for tr in rules.traits:
		for f in tr.requires:
			_needs[StringName(f)] = maxi(int(_needs.get(StringName(f), 0)), int(tr.requires[f]))


func _process(delta: float) -> void:
	t += delta


func log_event(what: String) -> void:
	if not _logged.has(what):
		_logged[what] = true
		print("demo t=%.1f %s" % [t, what])


func setup_perf() -> void:
	(func() -> void:
		var ids: Array[StringName] = [&"wriggle", &"glow", &"magnet", &"slick", &"drill_head"]
		var i := 0
		for w in Worm.all():
			while w.model.segments.size() < 40:
				w.model.add_segment(ORDER[i % ORDER.size()])
				i += 1
			for id in w.model.active.duplicate():
				w.model.toggle(id)
			for id in ids:
				w.model.grant(id)
				if not w.model.is_active(id):
					w.model.toggle(id)
		).call_deferred()


## Worm autopilot: same keys as Worm._read_intent().
func drive(w: Worm) -> Dictionary:
	var s: Dictionary = _state.get(w.player, {})
	if s.is_empty():
		s = { "last_pos": w.head_position(), "stuck_t": 0.0, "dodge": 0.0, "dodge_dir": 1.0,
			"burst_t": 1.0, "wiggle_t": 4.0, "carry": 0, "carry_t": 0.0 }
		_state[w.player] = s
	var out := { "move": Vector2.ZERO, "burst": false, "wiggle": false, "carry": false,
		"tackle": false, "nav": 0, "confirm": false }
	if arena.perf:
		out.move = Vector2.from_angle(t * 0.9 + w.player * PI)
		out.burst = fmod(t + w.player, 2.0) < 0.02
		return out
	if w.player == Players.P1:
		_p1(w, s, out)
	else:
		_p2(w, s, out)
	_unstick(w, s, out)
	return out


func _p1(w: Worm, s: Dictionary, out: Dictionary) -> void:
	var m := w.model
	if m.earned.size() >= 3 and not _p2_joined:
		_p2_joined = true
		log_event("p2 drops in")
		Players.join_virtual(Players.P2)
	var want: StringName = &""
	for f in ORDER:
		if m.flavour_count(f) < int(_needs.get(f, 0)):
			want = f
			break
	if want == &"":
		log_event("all flavours filled, traits=%s active=%s stage=%d" % [m.earned, m.active, m.stage])
		_wall(w, out)
		if _wall_step >= 0:
			return
		var big := _nearest(w, func(d: FoodData) -> bool: return d.size_stage > 1)
		if big != null:
			out.move = (big.global_position - w.head_position()).normalized()
		return
	var target := _nearest(w, func(d: FoodData) -> bool: return d.flavour == want and d.size_stage == 1)
	if target == null:
		return
	var to := target.global_position - w.head_position()
	out.move = to.normalized()
	s.burst_t -= get_physics_process_delta_time()
	if s.burst_t <= 0.0 and to.length() > 90.0:
		s.burst_t = 2.2
		out.burst = true
	s.wiggle_t -= get_physics_process_delta_time()
	if s.wiggle_t <= 0.0 and to.length() < 40.0:
		s.wiggle_t = 7.0
		out.wiggle = true
	# Carry once: the first junk food goes in the mouth, rides along a bit, and is dropped.
	if want == &"junk" and s.carry == 0:
		s.carry = 1
	if s.carry == 1:
		out.carry = true
		if w.carrying != null:
			s.carry = 2
			s.carry_t = 1.6
			log_event("p1 carries %s" % w.carrying.data.id)
	elif s.carry == 2:
		out.carry = true
		out.move = Vector2(-1, 0.3).normalized()
		s.carry_t -= get_physics_process_delta_time()
		if s.carry_t <= 0.0:
			s.carry = 3
			out.carry = false
			log_event("p1 drops it")


## The wall swap, one press at a time like a pad would.
func _wall(w: Worm, out: Dictionary) -> void:
	var m := w.model
	if _wall_step == -1:
		if m.is_active(WALL_OFF) and not m.is_active(WALL_ON) and WALL_ON in m.earned:
			_wall_step = 0
			_wall_t = 0.0
			log_event("wall opens")
		else:
			if m.active.size() >= 5:
				log_event("five traits active: %s" % [m.active])
			return
	if _wall_step >= 99:
		return
	_wall_t += get_physics_process_delta_time()
	if _wall_t < 0.7:
		return
	_wall_t = 0.0
	var wall: TraitWall = w._wall
	match _wall_step:
		0:
			out.tackle = true
		1, 3:
			var goal := m.earned.find(WALL_OFF if _wall_step == 1 else WALL_ON)
			if wall.cursor != goal:
				out.nav = 1 if goal > wall.cursor else -1
				return
			out.confirm = true
		2:
			pass
		4:
			out.tackle = true
			log_event("wall closes, active=%s" % [m.active])
		5:
			_wall_step = 99
			log_event("five traits active: %s" % [m.active])
			return
	_wall_step += 1


func _p2(w: Worm, s: Dictionary, out: Dictionary) -> void:
	var p1 := Worm.of(Players.P1)
	var food := _nearest(w, func(d: FoodData) -> bool: return d.size_stage <= w.model.stage)
	var goal := food.global_position if food != null else w.head_position()
	# Every few seconds, go and say hello (pass through P1: boop + heart).
	if p1 != null and fmod(t, 9.0) < 2.5:
		goal = p1.head_position()
	out.move = (goal - w.head_position()).normalized()
	s.wiggle_t -= get_physics_process_delta_time()
	if s.wiggle_t <= 0.0:
		s.wiggle_t = 5.0
		out.wiggle = true


func _unstick(w: Worm, s: Dictionary, out: Dictionary) -> void:
	var dt := get_physics_process_delta_time()
	if s.dodge > 0.0:
		s.dodge -= dt
		out.move = out.move.rotated(PI * 0.5 * s.dodge_dir)
		return
	if out.move.length() < 0.1:
		s.stuck_t = 0.0
		return
	if w.head_position().distance_to(s.last_pos) < 20.0 * dt:
		s.stuck_t += dt
		if s.stuck_t > 0.4:
			s.dodge = 0.6
			s.dodge_dir = -s.dodge_dir
			s.stuck_t = 0.0
	else:
		s.stuck_t = 0.0
	s.last_pos = w.head_position()


func _nearest(w: Worm, pred: Callable) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for f in get_tree().get_nodes_in_group("food"):
		if not f.is_available() or not pred.call(f.data) or not w.can_eat(f.data):
			continue
		var d: float = f.global_position.distance_to(w.head_position())
		if d < best_d:
			best_d = d
			best = f
	return best
