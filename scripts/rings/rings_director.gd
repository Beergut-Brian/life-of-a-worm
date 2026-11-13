## The living rings of vertical slice A (GAME.md Depth 2, 4, 5; The world; Bugs and threats).
## A child of the planet scene (scenes/levels/planet.tscn, node "Rings"); it hooks itself to the
## PlanetLevel when that is ready and never edits it. It owns:
## - the food chain counters (RingEcology over data/rings/*_life.tres), stepped on the planet clock,
##   and the few live bodies spawned from them into live chunks round the worms (<= 40 creatures);
## - statically scattered ring foods that regrow where they were (data/foods/*.tres, RingFood);
## - the topsoil: grass, the picnic sandwich and its crumbs, the anthill, rain, the bird that pecks
##   near the top, the gardener's boot shadow;
## - gardens: a carried seed (RingFood.plants) dropped in castings plants a patch; garden bites give
##   extra growth in the garden's flavour; Green thumb doubles both castings regrowth and that yield;
## - the hidden places (every data/secrets/*.tres: the ant city, the sunken rowboat, the fossil
##   hall, the geode cathedral at the core, the topsoil's picnic basket, the sky's cloud nest, the surface's hollow stump): carved, kept, found once per tin by entering (signal secret_found(id)), each with its
##   found beat (SecretSpot: a picture bubble; the tackle box shows the same picture after);
## - the sky ring above the grass (data/rings/sky_life.tres, SkyLife): its counters, its scattered
##   clouds, toy planes and balloons (sky foods, edible from SkyLife.edible_from), and the balloon
##   stuck in the sky (SkyBalloon), popped once per tin by eating its tie, and its birds (SkyFlock);
## - the surface ring (data/rings/surface_life.tres, SurfaceLife): its counters and its apples, and
##   the lawnmower driving the grass (its counter's body from data/creatures/lawnmower.tres).
## Everything it keeps goes in the tin under Save key "rings".
class_name RingsDirector
extends Node2D

signal secret_found(id: StringName)

## The core's chain (core crystals scattered and growing back live; lava blobs live in the core
## and its rim) runs in play too (W-02).
const LIVES: Array[RingLife] = [preload("res://data/rings/dirt_life.tres"), preload("res://data/rings/topsoil_life.tres"),
		preload("res://data/rings/core_life.tres"), preload("res://data/rings/deep_rock_life.tres")]
## The sky ring: no tiles, so its band and stage live in the SkyLife itself.
const SKY: SkyLife = preload("res://data/rings/sky_life.tres")
## The surface ring (W-06): its counters (apples, the lawnmower) and the apples on the grass. Its
## props (the town) are data/props/*.tres, stood by WorldDestruct.
const SURFACE: SurfaceLife = preload("res://data/rings/surface_life.tres")
## The lawnmower's body (L-12): the surface's "lawnmower" counter spawns this (give_body), only there.
## Hidden places added after tins were already saved (X-01: the topsoil's picnic basket, the sky's
## cloud nest): their foods are placed after every other static, so an older tin's statics keep
## their slots. Their halls draw as SecretHalls.
const LATE_SECRETS: Array[StringName] = [&"picnic_basket", &"cloud_nest", &"hollow_stump"]
const LAWNMOWER: LawnmowerData = preload("res://data/creatures/lawnmower.tres")
## Every hidden place in data/secrets/, sorted by id (ant_city first). New ones are data only.
static var SECRETS: Array[SecretData] = _load_secrets()
const BIRD := preload("res://scenes/creatures/bird.tscn")
const BOOT := preload("res://scenes/creatures/boot.tscn")
const SANDWICH_CRUMB := preload("res://data/foods/crumb.tres")
const MAX_CREATURES := 40
const MAX_PLANTS := 24
const TICK := 1.0
const SPAWN_NEAR := 150.0     # px: never pops in this close to a worm
const SPAWN_FAR := 560.0
const DESPAWN_FAR := 900.0
const GARDEN_BONUS := 0.4     # growth per garden tile bitten (x2 with Green thumb)
const BIRD_REACH := 6.0       # tiles below the top of the topsoil a bird can reach (through the grass)
const BIRD_GAP := 18.0        # planet seconds between pecks with 3 birds about (fewer birds, rarer)
const BOOT_GAP := 75.0
const RAIN_EVERY := 240.0
const RAIN_LONG := 60.0
const RAIN_GARDEN := 1.5      # gardens grow this much faster in the rain
const ANT_LINE := 5
const ANT_GAP := 13.0
const SAVE_KEY := "rings"

var world: PolarWorld
var level: Node
## Where creatures live (the level's Actors node; self when testing).
var actors: Node2D
var ecology: RingEcology
var spawn_point := Vector2.ZERO
var planet_radius_px := 4800.0
var found: Dictionary = {}
## Secret ids whose halls are dug in this tin (a tin saved before a secret existed digs it on load).
var carved: Dictionary = {}
var raining := false
## Off in tests that step by hand.
var auto_tick := true
var bird_gap := BIRD_GAP
var boot_gap := BOOT_GAP
var trail := PackedVector2Array()
var sandwich := Vector2.ZERO
var anthill := Vector2.ZERO
## The sky's birds (W-07): flocks circling the band of air, startled by a worm, never food.
var flock: SkyFlock
var cities: Dictionary = {}           # secret id -> centre (world px)
var live: Dictionary = {}             # species -> Array[Node2D]
var castings_speed := 1.0
var dressing: TopsoilDressing
## G-06: castings in the topsoil sprout while it rains (scripts/rings/castings_sprouts.gd).
var sprouts: CastingsSprouts
var balloon: SkyBalloon
## X-08: the empty Jarling cameo spots (one bare marker each until a cameo update fills one).
var cameo_stands: CameoStands
var _statics: Array[Dictionary] = []  # {node, food}
var _rng := RandomNumberGenerator.new()
var _last_clock := 0.0
var _tick_t := 0.0
var _bird_t := 8.0
var _boot_t := 40.0
var _rain_t := 0.0
var _save_t := 0.0
var _shot := ""
var _fx: Array[Dictionary] = []
var _hooked: Array[Node] = []


static func _load_secrets() -> Array[SecretData]:
	var out: Array[SecretData] = []
	const DIR := "res://data/secrets/"
	for f in ResourceLoader.list_directory(DIR):
		if f.ends_with(".tres"):
			var r := load(DIR + f)
			if r is SecretData:
				out.append(r)
	out.sort_custom(func(a: SecretData, b: SecretData) -> bool: return String(a.id) < String(b.id))
	return out


static func secret(id: StringName) -> SecretData:
	for s in SECRETS:
		if s.id == id:
			return s
	return null


## Centre (relative to the hall centre, px) and radius (px) of each side room of s.
static func rooms_of(s: SecretData, centre: Vector2) -> Array[Vector3]:
	var up := centre.normalized() if centre != Vector2.ZERO else Vector2.UP
	var side := up.orthogonal()
	var out: Array[Vector3] = []
	for r in s.rooms:
		var o := (side * r.x + up * r.y) * 16.0
		out.append(Vector3(o.x, o.y, r.z * 16.0))
	return out


func _ready() -> void:
	z_index = 2
	add_to_group(&"rings")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rings-shot="):
			_shot = a.get_slice("=", 1)
	var p := get_parent()
	if p is PlanetLevel:
		# Children are ready before the parent: hook once the level has built its world.
		p.ready.connect(_attach.bind(p), CONNECT_ONE_SHOT)
		Game.quit_requested.connect(_store)
		Game.state_changed.connect(_on_game_state)


func _on_game_state(_from: int, _to: int) -> void:
	_store()


func _attach(p: PlanetLevel) -> void:
	level = p
	setup(p.world, p.spawn_point, p.planet_seed, Save.get_value(SAVE_KEY, {}), p.actors)
	p.worm_spawned.connect(hook_worm)
	for w in Worm.all():
		hook_worm(w)
	if _shot != "":
		_stage_shot.call_deferred()


## Builds the rings on this world. saved = the tin's "rings" dictionary ({} for a new one).
func setup(p_world: PolarWorld, p_spawn: Vector2, p_seed: int, saved: Dictionary, p_actors: Node2D = null) -> void:
	world = p_world
	actors = p_actors if p_actors else self
	spawn_point = p_spawn
	planet_radius_px = float(world.shape.radius) * float(world.shape.cell_size)
	_rng.seed = p_seed * 7919 + 17
	ecology = RingEcology.from_lives(LIVES + [SKY, SURFACE], p_seed)
	LAWNMOWER.give_body(ecology)
	_last_clock = world.clock
	trail = _ant_trail()
	anthill = trail[trail.size() - 1]
	sandwich = polar(-0.06, 1.0)
	for s in SECRETS:
		cities[s.id] = polar(s.angle_from_start, s.depth)
		world.add_keep_zone(cities[s.id], (s.radius_tiles + 3.0) * 16.0)
		for r in rooms_of(s, cities[s.id]):
			world.add_keep_zone(cities[s.id] + Vector2(r.x, r.y), r.z + 2.0 * 16.0)
	if saved.is_empty():
		_build_new()
	else:
		ecology.from_dict(saved.get("eco", {}))
		for id in saved.get("found", []):
			found[StringName(id)] = true
		_rain_t = float(saved.get("rain_t", 0.0))
		if not saved.get("built", false):
			_build_new()
		else:
			# Tins from before "carved" was saved had only the ant city.
			for id in saved.get("carved", ["ant_city"]):
				carved[StringName(id)] = true
			for sd in SECRETS:
				if not carved.has(sd.id):
					_carve_secret(sd)
	_scatter(saved.get("statics", []))
	world.tile_eaten.connect(_on_tile_eaten)
	world.tile_regrown.connect(_on_tile_regrown)
	world.garden_planted.connect(func(cell: Vector2i, _f: StringName) -> void: _pop_fx(world.shape.center_of(cell), &"plant"))
	dressing = TopsoilDressing.new()
	dressing.name = "TopsoilDressing"
	dressing.director = self
	add_child(dressing)
	sprouts = CastingsSprouts.new()
	sprouts.name = "CastingsSprouts"
	sprouts.director = self
	sprouts.world = world
	add_child(sprouts)
	for s in SECRETS:
		var spot: SecretSpot = SecretHalls.new() if SecretHalls.draws(s.id) else SecretSpot.new()
		spot.name = "Secret_%s" % s.id
		spot.data = s
		spot.position = cities[s.id]
		spot.director = self
		add_child(spot)
	cameo_stands = CameoStands.new()
	cameo_stands.name = "CameoStands"
	add_child(cameo_stands)
	cameo_stands.setup(self)
	balloon = SkyBalloon.new()
	balloon.name = "SkyBalloon"
	balloon.sky = SKY
	balloon.director = self
	balloon.is_popped = bool(saved.get("balloon", false))
	balloon.position = polar(SKY.balloon_angle, SKY.balloon_height)
	add_child(balloon)
	flock = SkyFlock.new()
	flock.name = "SkyFlock"
	flock.setup(self, SKY, p_seed)
	add_child(flock)


## A point on the planet: angle from the start (radians, + = right of it on screen at the start)
## and depth as a fraction of the planet radius.
func polar(angle_from_start: float, depth: float) -> Vector2:
	return Vector2.from_angle(spawn_point.angle() + angle_from_start) * planet_radius_px * depth


func up_at(p: Vector2) -> Vector2:
	return p.normalized() if p != Vector2.ZERO else Vector2.UP


## Depth of a point as a fraction of the planet radius.
func depth_of(p: Vector2) -> float:
	return p.length() / planet_radius_px


func ring_band(ring: StringName) -> Vector2:
	if ring == SKY.ring:
		return Vector2(SKY.inner, SKY.outer)
	var inner := 0.0
	for r in world.rings.rings:
		if r.id == ring:
			return Vector2(inner, r.outer)
		inner = r.outer
	return Vector2(0.0, 1.0)


# --- a new tin: carve the ant city and its trail ----------------------------------------------

func _build_new() -> void:
	for s in SECRETS:
		_carve_secret(s)
	for i in trail.size() - 1:
		var a := trail[i]
		var b := trail[i + 1]
		var n := ceili(a.distance_to(b) / 8.0)
		for k in n + 1:
			var cell := world.shape.cell_at(a.lerp(b, float(k) / n))
			if world.is_edible_by(2, cell):
				world.dig(cell)


## Digs a hidden place's hall, its side rooms and the necks between them.
func _carve_secret(s: SecretData) -> void:
	var c: Vector2 = cities[s.id]
	_carve(c, s.radius_tiles * 16.0, s.carve_stage)
	for r in rooms_of(s, c):
		var o := Vector2(r.x, r.y)
		_carve(c + o, r.z, s.carve_stage)
		_carve(c + o * 0.5, 1.6 * 16.0, s.carve_stage)
	carved[s.id] = true


func _carve(at: Vector2, r: float, stage := 2) -> void:
	var c := world.shape.cell_at(at)
	var n := ceili(r / 16.0)
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			var cell := c + Vector2i(x, y)
			if world.shape.center_of(cell).distance_to(at) <= r and world.is_edible_by(stage, cell):
				world.dig(cell)


## The ant trail: from just right of the start pocket, through the dirt to the ant city, then up to
## the anthill on the surface. Ants march it back and forth: follow them and you find the city.
func _ant_trail() -> PackedVector2Array:
	var s: SecretData = secret(&"ant_city")
	var a := s.angle_from_start
	var d := s.depth
	var pts := PackedVector2Array()
	for p in [[0.04, 0.765], [0.08, 0.745], [a * 0.45, 0.735], [a * 0.62, 0.70], [a * 0.8, d + 0.012],
			[a - 0.02, d], [a + 0.03, d + 0.05], [a + 0.035, 0.80], [a + 0.05, 0.87], [a + 0.055, 0.95], [a + 0.058, 0.985], [a + 0.06, 1.0]]:
		pts.append(polar(p[0], p[1]))
	return pts


# --- scattered foods ---------------------------------------------------------------------------

func _scatter(saved: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng.seed + 3
	var placed: Array[Dictionary] = []
	for life in LIVES:
		var band := ring_band(life.ring)
		for i in life.scatter_count:
			if life.scatter.is_empty():
				break
			var food: RingFood = life.scatter[i % life.scatter.size()]
			var at := polar(rng.randf_range(-0.12, 0.12), rng.randf_range(band.x + 0.01, band.y - 0.01))
			placed.append({ "food": food, "at": at })
	# picnic crumbs under the sandwich
	for i in 7:
		placed.append({ "food": SANDWICH_CRUMB, "at": polar(-0.06 + rng.randf_range(-0.012, 0.012), rng.randf_range(0.955, 0.982)) })
	for s in SECRETS:
		if not s.id in LATE_SECRETS:
			_place_secret_foods(s, placed)
	# the sky goes last, so tins saved before it keep their statics in order
	for i in SKY.scatter_count:
		if SKY.scatter.is_empty():
			break
		var at := polar(rng.randf_range(-0.12, 0.12), rng.randf_range(SKY.inner + 0.01, SKY.outer - 0.01))
		placed.append({ "food": SKY.scatter[i % SKY.scatter.size()], "at": at })
	# the surface's apples, on top of the grass, after the sky (older tins keep their order)
	for i in SURFACE.scatter_count:
		if SURFACE.scatter.is_empty():
			break
		var at := polar(rng.randf_range(-SURFACE.scatter_spread, SURFACE.scatter_spread),
				rng.randf_range(SURFACE.scatter_inner, SURFACE.scatter_outer))
		placed.append({ "food": SURFACE.scatter[i % SURFACE.scatter.size()], "at": at })
	# hidden places added after the surface, last of all (older tins keep their order)
	for id in LATE_SECRETS:
		var late := secret(id)
		if late:
			_place_secret_foods(late, placed)
	for i in placed.size():
		var p := add_static(placed[i].food, placed[i].at)
		# A slot only takes its saved "eaten" if the same food was saved there (a tin from before a
		# new ring chain or hidden place shifts the list: those just start uneaten).
		if i < saved.size() and saved[i] is Array and saved[i].size() >= 2 and float(saved[i][1]) >= 0.0 \
				and String(saved[i][0]) == String(placed[i].food.id):
			p.gone_at = float(saved[i][1])
			p.take()
			p.gone_at = float(saved[i][1])


## A hidden place's foods: food_count around the hall, extra_food in its first side room.
func _place_secret_foods(s: SecretData, placed: Array[Dictionary]) -> void:
	var food: RingFood = load("res://data/foods/%s.tres" % s.food)
	var c: Vector2 = cities[s.id]
	for i in s.food_count:
		placed.append({ "food": food, "at": c + Vector2.from_angle(TAU * i / s.food_count) * s.radius_tiles * 9.0 })
	var rooms := rooms_of(s, c)
	if s.extra_food != &"" and not rooms.is_empty():
		placed.append({ "food": load("res://data/foods/%s.tres" % s.extra_food), "at": c + Vector2(rooms[0].x, rooms[0].y) })


func add_static(food: RingFood, at: Vector2) -> RingPickup:
	var p := RingPickup.new()
	p.data = food
	p.position = at
	add_child(p)
	p.home = at
	p.taken.connect(func(_n: Node2D) -> void: p.gone_at = world.clock)
	_statics.append({ "node": p, "food": food })
	return p


# --- worms ------------------------------------------------------------------------------------

func hook_worm(w: Worm) -> void:
	if _hooked.has(w):
		return
	_hooked.append(w)
	w.dropped.connect(_on_dropped.bind(w))
	w.tree_exiting.connect(_unhook.bind(w))


func _unhook(w: Worm) -> void:
	_hooked.erase(w)


func _worms() -> Array[Worm]:
	var out: Array[Worm] = []
	for w in Worm.all():
		if w.is_inside_tree() and w.model != null:
			out.append(w)
	return out


## A carried seed let go: if there is castings within a tile or two, it plants a garden there.
func _on_dropped(_player: int, what: StringName, w: Worm) -> void:
	var best: Node2D = null
	var best_d := 40.0 * w.size_factor()
	for f in get_tree().get_nodes_in_group(&"food"):
		if f.get("data") is RingFood and f.data.id == what and f.data.plants != &"":
			var d: float = f.global_position.distance_to(w.mouth_position())
			if d < best_d:
				best_d = d
				best = f
	if best == null:
		return
	if plant_at(world.to_local(best.global_position), best.data.plants):
		best.call("take")
		Audio.play("garden_plant")


## Plants a garden of flavour in the nearest open castings cell within 2 tiles of p. True if it took.
func plant_at(p: Vector2, flavour: StringName) -> bool:
	var c := world.shape.cell_at(p)
	for r in 3:
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				if world.plant_seed(c + Vector2i(x, y), flavour):
					return true
	return false


func _on_tile_eaten(cell: Vector2i, block: StringName, player: int) -> void:
	var b := String(block)
	if not b.begins_with("garden_"):
		return
	var w := Worm.of(player)
	if w == null or w.model == null:
		return
	var flavour := StringName(b.substr(7))
	w.model.add_growth(GARDEN_BONUS * (1.0 + w.model.stats.value("garden_yield", 0.0)), flavour)
	if _rng.randf() < 0.3:
		_pop_fx(world.shape.center_of(cell), &"yum")


func _on_tile_regrown(cell: Vector2i, _block: StringName) -> void:
	if castings_speed > 1.0 and world.has_castings(cell) and _fx.size() < 40 and _near_worm(world.shape.center_of(cell), 400.0):
		_pop_fx(world.shape.center_of(cell), &"leaf")


func _near_worm(p: Vector2, r: float) -> bool:
	for w in _worms():
		if world.to_local(w.head_position()).distance_to(p) < r:
			return true
	return false


# --- the frame --------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if world == null or not auto_tick:
		return
	frame(delta)


## One frame (tests call it directly).
func frame(delta: float) -> void:
	_check_secrets()
	_tick_t += delta
	if _tick_t >= TICK:
		_tick_t = 0.0
		tick()
	for i in range(_fx.size() - 1, -1, -1):
		_fx[i].t += delta
		if _fx[i].t > 1.2:
			_fx.remove_at(i)
	if not _fx.is_empty() or _fx_drawn:
		queue_redraw()
	_save_t += delta
	if _save_t >= 2.0:
		_store()


## One simulation tick: step the counters by the planet time since the last tick, apply traits and
## rain, regrow scattered foods, fit the live bodies to the counters, send birds and boots.
func tick() -> void:
	var dt := maxf(0.0, world.clock - _last_clock)
	_last_clock = world.clock
	ecology.step(dt)
	_traits_and_rain(dt)
	for s in _statics:
		var p: RingPickup = s.node
		if p.gone_at >= 0.0 and world.clock >= p.gone_at + s.food.regrow_time and _near_worm(p.home, 2000.0) \
				and not _near_worm(p.home, 60.0):
			p.gone_at = -1.0
			p.respawn()
	fit_live()
	_bird_t -= dt
	_boot_t -= dt
	if _bird_t <= 0.0:
		_bird_t = bird_gap * 3.0 / maxf(0.75, ecology.count(&"bird")) * _rng.randf_range(0.7, 1.3)
		send_bird()
	if _boot_t <= 0.0:
		_boot_t = boot_gap * _rng.randf_range(0.8, 1.4)
		send_boot()


func _traits_and_rain(dt: float) -> void:
	castings_speed = 1.0
	for w in _worms():
		castings_speed = maxf(castings_speed, 1.0 + w.model.stats.value("castings_speed", 0.0))
	_rain_t += dt
	raining = fmod(_rain_t, RAIN_EVERY) >= RAIN_EVERY - RAIN_LONG or _shot == "topsoil"
	if "castings_speed" in world:
		world.set("castings_speed", castings_speed)
		world.set("garden_speed", RAIN_GARDEN if raining else 1.0)


# --- live bodies ------------------------------------------------------------------------------

func creature_count() -> int:
	var n := 0
	for c in actors.get_children():
		if c is Creature and not c.is_queued_for_deletion():
			n += 1
	return n


func live_of(species: StringName) -> Array:
	var arr: Array = live.get(species, [])
	var out := []
	for n in arr:
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			out.append(n)
	live[species] = out
	return out


## Wanted live bodies of a species (its counter times live_scale, capped).
func wanted(rule: PopulationRule) -> int:
	return clampi(roundi(ecology.count(rule.id) * rule.live_scale), 0, rule.live_max)


## Spawns toward / frees down to the wanted numbers: a few per tick, only into live chunks near a
## worm, never on top of one; never more than MAX_CREATURES creatures at once.
func fit_live() -> void:
	var anchors := _anchors()
	for rule: PopulationRule in ecology.rules.values():
		var have := live_of(rule.id)
		var want := wanted(rule)
		if have.size() > want + 1:
			var far := _farthest(have, anchors)
			if far != null:
				far.queue_free()
			continue
		var budget := ANT_LINE if rule.id == &"ant" else 2
		while have.size() < want and budget > 0:
			budget -= 1
			var is_creature := rule.live.ends_with(".tscn")
			if is_creature and creature_count() >= MAX_CREATURES:
				break
			if not is_creature and have.size() >= MAX_PLANTS:
				break
			var made := _spawn(rule, anchors)
			if made.is_empty():
				break
			have.append_array(made)
		live[rule.id] = have


func _anchors() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for w in _worms():
		out.append(world.to_local(w.head_position()))
	return out


func _farthest(nodes: Array, anchors: Array[Vector2]) -> Node2D:
	var best: Node2D = null
	var best_d := DESPAWN_FAR if not anchors.is_empty() else -1.0
	for n in nodes:
		var d := INF
		for a in anchors:
			d = minf(d, a.distance_to(n.position))
		if d > best_d:
			best_d = d
			best = n
	return best


func _spawn(rule: PopulationRule, anchors: Array[Vector2]) -> Array:
	if anchors.is_empty():
		return []
	if rule.id == &"ant":
		return _spawn_ant_line(rule, anchors)
	var band := ring_band(rule.ring)
	var lo := rule.depth_min if rule.depth_min > 0.0 else band.x + 0.005
	var hi := rule.depth_max if rule.depth_max > 0.0 else band.y - 0.005
	for attempt in 10:
		var a: Vector2 = anchors[_rng.randi() % anchors.size()]
		var p := a + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(SPAWN_NEAR, SPAWN_FAR)
		var dp := depth_of(p)
		if dp < lo or dp > hi or not world.is_loaded(world.shape.cell_at(p)):
			continue
		var ok := true
		for b in anchors:
			if b.distance_to(p) < SPAWN_NEAR:
				ok = false
		for c in cities.values():
			if c.distance_to(p) < 9.0 * 16.0:
				ok = false
		if ok:
			return [_make(rule, p)]
	return []


## Ants come in marching lines of ANT_LINE on the trail, near a worm.
func _spawn_ant_line(rule: PopulationRule, anchors: Array[Vector2]) -> Array:
	var length := Creature._length(trail)
	var a: Vector2 = anchors[_rng.randi() % anchors.size()]
	var at := _trail_dist_nearest(a) + _rng.randf_range(-260.0, 260.0)
	at = clampf(at, ANT_GAP * ANT_LINE, length)
	var out := []
	var dir := 1.0 if _rng.randf() < 0.5 else -1.0
	for i in ANT_LINE:
		if creature_count() >= MAX_CREATURES or live_of(rule.id).size() + out.size() >= rule.live_max:
			break
		var c: Creature = _make(rule, Vector2.ZERO)
		c.path = trail
		c.path_at = at - i * ANT_GAP * dir
		c.path_dir = dir
		c._path_len = length
		c.position = c._point_at(c.path_at)
		out.append(c)
	return out


func _trail_dist_nearest(p: Vector2) -> float:
	var best := 0.0
	var best_d := INF
	var acc := 0.0
	for i in trail.size() - 1:
		var seg := trail[i].distance_to(trail[i + 1])
		var q := Geometry2D.get_closest_point_to_segment(p, trail[i], trail[i + 1])
		var d := q.distance_to(p)
		if d < best_d:
			best_d = d
			best = acc + trail[i].distance_to(q)
		acc += seg
	return best


func _make(rule: PopulationRule, at: Vector2) -> Node2D:
	var n: Node2D
	if rule.live.ends_with(".tscn"):
		var c: Creature = load(rule.live).instantiate()
		c.world = world
		c.species = rule.id
		c.taken.connect(_on_creature_taken.bind(rule))
		c.ate_worm.connect(_on_ate_worm)
		c.ate_creature.connect(func(prey: Creature) -> void: prey.set_meta("hunted", true))
		n = c
	else:
		var p := RingPickup.new()
		p.data = load(rule.live)
		p.species = rule.id
		p.taken.connect(func(f: Node2D) -> void:
			ecology.kill(rule.id, 1.0 / maxf(rule.live_scale, 0.001))
			f.queue_free())
		n = p
	n.position = at
	actors.add_child(n)
	if n is RingPickup:
		n.home = at
	n.scale = Vector2(0.2, 0.2)
	n.create_tween().tween_property(n, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	return n


## A worm (or a burrow trophy) took a live creature: the counter loses the share it stood for.
## Prey eaten by another live creature is already counted by the predation rate.
func _on_creature_taken(c: Creature, rule: PopulationRule) -> void:
	if not c.has_meta("hunted"):
		ecology.kill(rule.id, 1.0 / maxf(rule.live_scale, 0.001))


func _on_ate_worm(_player: int) -> void:
	if level and level.camera and SettingsPanel.screen_shake():
		level.camera.shake = maxf(level.camera.shake, 0.4)


# --- birds and the boot -----------------------------------------------------------------------

## Top of the ground (px from the core): the outer edge of the surface ring.
func ground_top() -> float:
	return planet_radius_px


## Top of the topsoil (px from the core): under it is only the thin grass crust.
func topsoil_top() -> float:
	return ring_band(&"topsoil").y * planet_radius_px


## A worm a bird can reach: within BIRD_REACH tiles of the top, and smaller than a bird.
func bird_target() -> Worm:
	var bird_stage := (load("res://data/creatures/bird.tres") as CreatureData).size_stage
	for w in _worms():
		var p := world.to_local(w.head_position())
		if p.length() >= topsoil_top() - BIRD_REACH * 16.0 and w.model.stage < bird_stage:
			return w
	return null


## Sends one bird at a reachable worm, else at a beetle near the top (birds eat beetles); else none.
func send_bird() -> Bird:
	if ecology.count(&"bird") < 0.3 or not get_tree().get_nodes_in_group(&"birds").is_empty():
		return null
	var at := Vector2.INF
	var w := bird_target()
	if w:
		at = world.to_local(w.head_position())
	else:
		for b in live_of(&"beetle"):
			if b.position.length() >= topsoil_top() - (BIRD_REACH + 8.0) * 16.0:
				at = b.position
				break
	if at == Vector2.INF or creature_count() >= MAX_CREATURES:
		return null
	var bird: Bird = BIRD.instantiate()
	bird.world = world
	bird.species = &"bird"
	bird.ate_worm.connect(_on_ate_worm)
	bird.ate_creature.connect(func(prey: Creature) -> void: prey.set_meta("hunted", true))
	actors.add_child(bird)
	bird.aim(at, up_at(at), ground_top())
	return bird


## The gardener's boot passes over as a shadow when a worm is up in the topsoil (stage 4 later).
func send_boot() -> BootShadow:
	var band := ring_band(&"topsoil")
	for w in _worms():
		var p := world.to_local(w.head_position())
		if depth_of(p) >= band.x and creature_count() < MAX_CREATURES:
			var boot: BootShadow = BOOT.instantiate()
			boot.world = world
			actors.add_child(boot)
			var up := up_at(p)
			boot.pass_over(up * ground_top(), up)
			return boot
	return null


# --- secrets ----------------------------------------------------------------------------------

func _check_secrets() -> void:
	for s in SECRETS:
		if found.has(s.id):
			continue
		var c: Vector2 = cities[s.id]
		for w in _worms():
			if world.to_local(w.head_position()).distance_to(c) <= (s.radius_tiles + 1.0) * 16.0:
				discover(s, w)
				break


func discover(s: SecretData, w: Worm = null) -> void:
	if found.has(s.id):
		return
	found[s.id] = true
	Audio.play(s.cue)
	for i in 10:
		_pop_fx(cities[s.id] + Vector2.from_angle(TAU * i / 10.0) * 40.0, &"confetti")
	if w:
		w._pop(w.look, 1.6)
	var spot := get_node_or_null("Secret_%s" % s.id) as SecretSpot
	if spot:
		spot.play_found_beat()
	print("secret_found: %s" % s.id)
	secret_found.emit(s.id)
	_store()
	if level:
		level.save_now()


# --- save -------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var statics := []
	for s in _statics:
		statics.append([String(s.food.id), s.node.gone_at])
	var f := []
	for id in found:
		f.append(String(id))
	var dug := []
	for id in carved:
		dug.append(String(id))
	return { "eco": ecology.to_dict(), "found": f, "rain_t": _rain_t, "built": true, "statics": statics, "carved": dug,
			"balloon": balloon != null and balloon.is_popped }


## SkyBalloon calls this when its tie is eaten: saved at once, like a find.
func balloon_popped(player: int) -> void:
	print("balloon_popped: %d" % player)
	_store()
	if level and level.has_method("save_now"):
		level.save_now()


func _store() -> void:
	_save_t = 0.0
	if level and ecology:
		Save.set_value(SAVE_KEY, to_dict())


# --- fx ---------------------------------------------------------------------------------------

var _fx_drawn := false


func _pop_fx(at: Vector2, kind: StringName) -> void:
	if _fx.size() < 60:
		_fx.append({ "at": at, "t": 0.0, "kind": kind, "r": _rng.randf() * TAU })
		queue_redraw()


func _draw() -> void:
	_fx_drawn = not _fx.is_empty()
	for f in _fx:
		var k: float = f.t / 1.2
		var up := up_at(f.at)
		var p: Vector2 = f.at + up * k * 18.0
		var a := 1.0 - k
		match f.kind:
			&"leaf":
				var s := 3.0 + 2.0 * sin(k * PI)
				draw_colored_polygon(PackedVector2Array([p, p + up.rotated(0.6) * s * 2.0, p + up * s * 2.6, p + up.rotated(-0.6) * s * 2.0]), Color(0.42, 0.85, 0.3, a))
			&"plant":
				for i in 6:
					var d := Vector2.from_angle(TAU * i / 6.0 + f.r) * (6.0 + k * 22.0)
					draw_circle(f.at + d, 2.5 * a + 0.5, Color(0.55, 0.95, 0.4, a))
			&"yum":
				draw_circle(p, 2.0 + 3.0 * k, Color(1, 0.9, 0.4, a))
			&"confetti":
				for i in 5:
					var d := Vector2.from_angle(f.r + i * 1.3) * k * 60.0
					var col := Color.from_hsv(fmod(f.r + i * 0.2, 1.0), 0.7, 1.0, a)
					draw_rect(Rect2(f.at + d - Vector2(2, 2), Vector2(4, 4)), col)


# --- real frames (--rings-shot=topsoil|garden|ant_city|secret:<id>) -------------------------

func _stage_shot() -> void:
	if level == null:
		return
	var w: Worm = Worm.of(Players.P1)
	match _shot:
		"topsoil":
			var at := polar(-0.05, 0.978)
			_carve(at, 40.0)
			w = w if w else level.spawn_worm(Players.P1, at, 2)
			w.warp_to(at)
			_bird_t = 0.3
			_boot_t = 2.5
			for i in 4:
				var rule: PopulationRule = ecology.rules[&"mushroom"]
				_make(rule, polar(-0.05 + (i - 1.5) * 0.008, 0.955 + 0.006 * i))
		"garden":
			var at := polar(0.0, 0.76)
			w = w if w else level.spawn_worm(Players.P1, at, 2)
			var c := world.shape.cell_at(at)
			for x in range(-14, 15):
				for y in range(-2, 3):
					world.eat_tile(c + Vector2i(x, y + (2 if x > 0 else 0)), Players.P1)
			for spec in [[-10, &"root"], [0, &"bug"], [10, &"stone"]]:
				plant_at(world.shape.center_of(c + Vector2i(spec[0], 0)), spec[1])
			w.warp_to(at + up_at(at) * 80.0)   # just above the tunnel, out of the patches' way
			for i in 80:
				world.advance(0.5)
		"ant_city":
			var cpos: Vector2 = cities[&"ant_city"]
			w = w if w else level.spawn_worm(Players.P1, cpos, 1)
			w.warp_to(cpos + up_at(cpos).orthogonal() * 40.0)
			ecology.counts[&"ant"] = 40.0
		"sky", "sky_pop":
			# a stage-5 worm in the sky beside the stuck balloon; sky_pop bites its tie after 1.5 s
			var tie_at := balloon.position + balloon.up() * -SKY.balloon_string
			var at := tie_at + balloon.up().orthogonal() * 90.0
			w = w if w else level.spawn_worm(Players.P1, at, 5)
			if w.model.stage < 5:
				w.model.start_at_stage(5)
			w.warp_to(at)
			balloon.reset()
			if _shot == "sky_pop":
				# the worm's own bite eats the tie (a stage-5 mouth on it)
				get_tree().create_timer(1.5).timeout.connect(func() -> void:
					w.warp_to(tie_at - (w.mouth_position() - w.head_position())))
		"birds":
			# a stage-5 worm in the sky; a flock flies in ahead of it and startles at ~1.5 s
			var at := polar(0.25, 1.22)
			w = w if w else level.spawn_worm(Players.P1, at, 5)
			if w.model.stage < 5:
				w.model.start_at_stage(5)
			w.warp_to(at)
			flock.place(0, 0.25 - 0.05, 1.225)
			flock._flocks[0].dir = 1.0
			flock.place(1, 0.25 + 0.05, 1.33)
		_ when _shot.begins_with("secret:"):
			# --rings-shot=secret:<id>: the worm (big enough for the hall's ring) just inside the
			# hall, so the frames show the find beat as it plays.
			var s := secret(StringName(_shot.trim_prefix("secret:")))
			if s == null:
				return
			found.erase(s.id)   # frames only: replay the find even if this tin had it
			var cpos: Vector2 = cities[s.id]
			var stage := maxi(1, s.carve_stage)
			var side := up_at(cpos).orthogonal()
			w = w if w else level.spawn_worm(Players.P1, cpos + side * 40.0, stage)
			if w.model.stage < stage:
				w.model.start_at_stage(stage)
			w.warp_to(cpos + side * 40.0)
