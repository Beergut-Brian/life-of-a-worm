## Stage 7's drifting space (S-11, S-18, W-08, L-19), run by SpaceStage. The five themed planets
## (data/planets/*.tres) come one at a time in a seeded random order. Each big planet drifts by
## the worms (out past `forget_at` it comes back in from another side) with its own foods round it;
## it is bigger than the worm, so it bumps (a visible ring where it hit) and nothing hunts. Pips round
## it fill as its foods are eaten; when they are full it ripens to food, and eating it brings the
## next planet. After the fifth comes the sun, its five pips already full: the last meal.
## Moons and comets (the space ring's counters, a RingEcology over SpaceLife) drift in between.
## Some foods carry the planet's rare star trait (a twinkling star on them), once per run.
## Nothing here moves a worm: the stage reads the stick, this only spawns and drifts bodies.
class_name SpaceDrift
extends Node2D

## A big body (the next themed planet, or the sun) has started drifting in.
signal arrived(body: SpacePlanet)
signal planet_ripe(id: StringName)
signal planet_done(id: StringName)
signal star_earned(player: int, id: StringName)
signal sun_arrived()
signal sun_eaten(player: int)

const SAVE_KEY := "space"
const LIFE_PATH := "res://data/rings/space_life.tres"
## Small things (foods, moons, comets) are on layer 2: worm bodies pass through them and the mouth
## (mask 1 | 2) eats them; big planets and the sun are on layer 1 and push the worm's body.
const SMALL_LAYER := 2

var life: SpaceLife
var order: Array[PlanetData] = []
## Index into `order`; order.size() means it is the sun's turn.
var visit := 0
var done: Array[StringName] = []
## Star traits already eaten this run: [[player, id], ...] (a star shows up once per run).
var stars: Array = []
var meal_left := 0
var big: SpacePlanet
var sun: SpacePlanet
var sun_gone := false
var ecology: RingEcology
var run_seed := 0
## Returns the point the worms are round (stage-local); spawning and forgetting measure from it.
var centre_fn: Callable = func() -> Vector2: return Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _next_in := -1.0


## The planet types in this run's order: the same seed always gives the same order.
static func shuffled(planets: Array[PlanetData], seed_value: int) -> Array[PlanetData]:
	var out: Array[PlanetData] = planets.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


func setup(p_life: SpaceLife, seed_value: int, saved: Dictionary = {}) -> void:
	life = p_life
	run_seed = int(saved.get("seed", seed_value))
	_rng.seed = run_seed * 31 + 7
	order = shuffled(life.planets, run_seed)
	ecology = RingEcology.from_lives([life], run_seed)
	visit = clampi(int(saved.get("visit", 0)), 0, order.size())
	for id in saved.get("done", []):
		done.append(StringName(id))
	stars = saved.get("stars", []).duplicate(true)
	sun_gone = bool(saved.get("sun", false))
	meal_left = int(saved.get("meal_left", -1))
	if saved.has("ecology"):
		ecology.from_dict(saved["ecology"])


func current() -> PlanetData:
	return order[visit] if visit < order.size() else null


func star_taken(id: StringName) -> bool:
	for s in stars:
		if StringName(s[1]) == id:
			return true
	return false


## Bring in whatever is next: this run's current planet, or the sun, or (after the sun) nothing.
func begin() -> void:
	_next_in = -1.0
	if sun_gone:
		return
	var d := current()
	if d == null:
		_start_sun()
	else:
		_start_planet(d)


func _start_planet(d: PlanetData) -> void:
	if meal_left < 0 or meal_left > d.meal:
		meal_left = d.meal
	big = _spawn(&"planet", d.size_stage, d.radius if d.radius > 0.0 else SpacePlanet.radius_for(d.size_stage), d.color, d.accent, 1)
	big.name = "Planet_%s" % d.id
	big.data = d
	big.theme = d.id
	big.pips = d.meal
	big.pips_full = d.meal - meal_left
	_enter(big, d.drift)
	if meal_left == 0:
		big.ripen(d.ripe_stage)
	arrived.emit(big)


func _start_sun() -> void:
	sun = _spawn(&"sun", life.sun_stage, life.sun_radius, life.sun_color, life.sun_accent, 1)
	sun.name = "Sun"
	sun.theme = &"sun"
	sun.pips = order.size()
	for d in order:
		sun.pip_colors.append(d.color)
	_enter(sun, 14.0)
	sun.ripen(life.sun_stage)
	sun.pips_full = done.size()
	arrived.emit(sun)
	sun_arrived.emit()
	Audio.play("stage_up")


func _spawn(kind: StringName, stage: int, r: float, col: Color, col2: Color, layer: int) -> SpacePlanet:
	var p := SpacePlanet.new()
	p.kind = kind
	p.size_stage = stage
	p.radius_override = r
	p.tint = col
	p.tint2 = col2
	p.collision_layer = layer
	p.collision_mask = 1 | SMALL_LAYER
	add_child(p)
	return p


## Put a big body on the spawn band and aim it past the worms, so it drifts by (never at them).
func _enter(p: SpacePlanet, speed: float) -> void:
	var c: Vector2 = centre_fn.call()
	var a := _rng.randf() * TAU
	var dist := life.spawn_max + p.radius
	p.position = c + Vector2.from_angle(a) * dist
	var aim := c + Vector2.from_angle(a + PI / 2.0) * _rng.randf_range(250.0, 450.0)
	p.drift = (aim - p.position).normalized() * speed
	p.linear_velocity = p.drift


func _small(kind: StringName, f: FoodData, at: Vector2, vel: Vector2) -> SpacePlanet:
	var p := _spawn(kind, f.size_stage, f.radius, f.color, f.color.darkened(0.25), SMALL_LAYER)
	p.food = f
	p.theme = f.id
	p.position = at
	p.drift = vel
	p.linear_velocity = vel
	return p


func smalls(kind: StringName) -> Array[SpacePlanet]:
	var out: Array[SpacePlanet] = []
	for c in get_children():
		if c is SpacePlanet and c.kind == kind and not c.eaten:
			out.append(c)
	return out


func _process(delta: float) -> void:
	if life == null:
		return
	ecology.step(delta)
	var c: Vector2 = centre_fn.call()
	for p in get_children():
		if not (p is SpacePlanet) or p.eaten:
			continue
		if p.position.distance_to(c) > life.forget_at + p.radius:
			if p == big or p == sun:
				_enter(p, p.drift.length())      # it drifts by again
			else:
				p.queue_free()                   # drifted off for good
	_top_up(c)
	if _next_in >= 0.0:
		_next_in -= delta
		if _next_in < 0.0:
			begin()


func _top_up(c: Vector2) -> void:
	var d := current()
	if big != null and d != null and not d.foods.is_empty():
		var have := smalls(&"food").filter(func(p): return p.data == d).size()
		if have < d.live_foods:
			var f: FoodData = d.foods[_rng.randi() % d.foods.size()]
			var at := big.position + Vector2.from_angle(_rng.randf() * TAU) * (big.radius + _rng.randf_range(140.0, 420.0))
			var p := _small(&"food", f, at, big.linear_velocity + Vector2.from_angle(_rng.randf() * TAU) * 10.0)
			p.data = d
			if d.star_trait != null and not star_taken(d.star_trait.id) and not _star_out() and _rng.randf() < d.star_chance:
				p.star_trait = d.star_trait
	for spec in [[&"moon", life.moon, 12.0], [&"comet", life.comet, life.comet_speed]]:
		var f: FoodData = spec[1]
		var rule: PopulationRule = ecology.rules.get(spec[0])
		if f == null or rule == null:
			continue
		var want := mini(rule.live_max, int(ecology.count(spec[0]) * rule.live_scale))
		if smalls(spec[0]).size() < want:
			var a := _rng.randf() * TAU
			var at := c + Vector2.from_angle(a) * _rng.randf_range(life.spawn_min, life.spawn_max)
			var aim := c + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, 500.0)
			_small(spec[0], f, at, (aim - at).normalized() * float(spec[2]))


func _star_out() -> bool:
	for p in smalls(&"food"):
		if p.star_trait != null:
			return true
	return false


## The stage's eaten path calls this after a worm ate `p` (SpacePlanet.be_eaten already ran).
func on_eaten(eater: SpaceWorm, p: SpacePlanet) -> void:
	if p.star_trait != null and not star_taken(p.star_trait.id):
		if eater.add_star(p.star_trait):
			stars.append([eater.player, String(p.star_trait.id)])
			star_earned.emit(eater.player, p.star_trait.id)
			Audio.play("secret_found")
	match p.kind:
		&"food":
			if big != null and p.data == current() and not big.ripe:
				meal_left = maxi(0, meal_left - 1)
				big.pips_full = p.data.meal - meal_left
				if meal_left == 0:
					big.ripen(p.data.ripe_stage)
					planet_ripe.emit(p.data.id)
					Audio.play("now_i_eat_you")
		&"moon", &"comet":
			var rule: PopulationRule = ecology.rules.get(p.kind)
			if rule != null:
				ecology.kill(p.kind, 1.0 / maxf(rule.live_scale, 0.001))
		&"planet":
			if p == big:
				done.append(p.data.id)
				visit += 1
				big = null
				meal_left = -1
				ecology.kill(&"planet", 1.0)
				planet_done.emit(p.data.id)
				Audio.play("planet_gone")
				_next_in = life.next_planet_after
		&"sun":
			sun_gone = true
			sun = null
			ecology.kill(&"sun", 1.0)
			sun_eaten.emit(eater.player)
	save()


func to_save() -> Dictionary:
	var names: Array = []
	for id in done:
		names.append(String(id))
	return { "seed": run_seed, "visit": visit, "done": names, "stars": stars, "sun": sun_gone,
			"meal_left": meal_left, "ecology": ecology.to_dict() }


func save() -> void:
	Save.set_value(SAVE_KEY, to_save())
