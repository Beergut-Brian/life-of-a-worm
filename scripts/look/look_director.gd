## Look B on the planet (docs/art-direction.md "Life of a Worm: final look", D92). One node in
## scenes/levels/planet.tscn; it waits for the planet's _ready and then adds, all game-side:
##   * ambient darkness per ring from data/rings/looks.tres (a CanvasModulate following the camera's
##     depth), with the day/night tint reaching down into the topsoil;
##   * a lantern PointLight2D on each worm's head, coloured light on glowing food (nearest few),
##     and daylight shafts through holes eaten in the grass crust;
##   * the soil parallax (three layers) behind the ground and the sky above the topsoil;
##   * rain that soaks the soil darker from the top down (RingsDirector.raining);
##   * FaceSprites on every food and creature, and Juice on every bite.
## Nothing here changes gameplay: it only reads the level and adds visuals.
class_name LookDirector
extends Node2D

const LOOKS := preload("res://data/rings/looks.tres")
const LANTERN := preload("res://assets/sprites/fx/lantern.png")
const GLOW := preload("res://assets/sprites/fx/glow.png")
const SHAFT := preload("res://assets/sprites/fx/shaft.png")
const LAYERS := preload("res://assets/sprites/world/parallax_soil.png")
const CLOUDS := preload("res://assets/sprites/world/clouds.png")
const SOIL_SHADER := preload("res://assets/shaders/soil_parallax.gdshader")
const SKY_SHADER := preload("res://assets/shaders/sky.gdshader")
const P_COLOURS := [Color("3cc24a"), Color("e4393c")]
## Seconds between scans for new foods, creatures and worms.
const SCAN_EVERY := 0.25
## A tile chomp puff per worm at most this often (tiles come many a second).
const TILE_PUFF_EVERY := 0.14

var looks: RingLooks = LOOKS
var level: Node2D
var world: PolarWorld
var rings_director: Node
var modulate_node: CanvasModulate
var soil: Polygon2D
var sky_layer: CanvasLayer
var sky: Polygon2D
## 0..1 through the day (0 dawn); wetness 0..1 (rain soaks in, then dries).
var day_phase := 0.0
var wetness := 0.0
## Override for frames and tests: a fixed day phase (-1 = follow the planet clock).
var fixed_phase := -1.0
var lanterns: Dictionary[Worm, PointLight2D] = {}
var glows: Array[PointLight2D] = []
var shafts: Array[Node2D] = []
var surface_px := 4800.0
var crust_px := 4742.0
var _bounds := Vector4.ZERO
var _scan_t := 0.0
var _puff_t: Dictionary[int, float] = {}
var _ready_done := false
var _food_cols: Dictionary[StringName, Color] = {}
## Script cost of the look per frame (µs): this node, and all FaceSprites together (stress report).
var frame_usec := 0
var sprites_usec := 0


func _ready() -> void:
	level = get_parent() as Node2D
	if level == null:
		return
	if level.is_node_ready():
		_on_level_ready()
	else:
		level.ready.connect(_on_level_ready, CONNECT_ONE_SHOT)


func _on_level_ready() -> void:
	world = level.get(&"world") as PolarWorld
	if world == null or world.rings == null:
		return
	rings_director = level.get_node_or_null("Rings")
	Juice.host = level
	Juice.core = level.global_position
	var radius_tiles := float(world.shape.get(&"radius")) if &"radius" in world.shape else 300.0
	var rs := world.rings.rings
	surface_px = radius_tiles * 16.0
	var outer := {}
	for r in rs:
		outer[r.id] = r.outer * surface_px
	crust_px = float(outer.get(&"topsoil", surface_px * 0.988))
	_bounds = Vector4(outer.get(&"core", 0.0), outer.get(&"deep_rock", 0.0), outer.get(&"dirt", 0.0), crust_px)
	z_index = 0
	modulate_node = CanvasModulate.new()
	modulate_node.name = "Ambient"
	add_child(modulate_node)
	_build_soil()
	_build_sky()
	var tm := (world.tile_art as RingTileArt).material if world.tile_art is RingTileArt else null
	if tm:
		tm.set_shader_parameter("surface_r", surface_px)
		if looks.grass.size() >= 3:
			tm.set_shader_parameter("grass_dark", looks.grass[0])
			tm.set_shader_parameter("grass_mid", looks.grass[1])
			tm.set_shader_parameter("grass_tip", looks.grass[2])
	world.tile_eaten.connect(_on_tile_eaten)
	world.tile_regrown.connect(func(_c: Vector2i, _b: StringName) -> void: _check_shafts())
	_scan_existing_holes()
	_ready_done = true
	_scan()
	_update(0.0, true)
	if Game.demo and LookFrames.preset_arg() != "":
		var fr := LookFrames.new()
		fr.name = "LookFrames"
		fr.look = self
		fr.preset = LookFrames.preset_arg()
		add_child(fr)


# --- frame --------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _ready_done:
		return
	var t0 := Time.get_ticks_usec()
	sprites_usec = FaceSprite.usec
	FaceSprite.usec = 0
	_scan_t += delta
	if _scan_t >= SCAN_EVERY:
		_scan_t = 0.0
		_scan()
	for k in _puff_t:
		_puff_t[k] = maxf(0.0, _puff_t[k] - delta)
	_update(delta)
	frame_usec = Time.get_ticks_usec() - t0


func _camera() -> Camera2D:
	return get_viewport().get_camera_2d() if get_viewport() else null


func _update(delta: float, snap := false) -> void:
	day_phase = fixed_phase if fixed_phase >= 0.0 else fposmod(world.clock / maxf(looks.day_length, 1.0), 1.0)
	var raining: bool = rings_director != null and bool(rings_director.get(&"raining"))
	wetness = move_toward(wetness, 1.0 if raining else 0.0, delta / (20.0 if raining else 60.0))
	var cam := _camera()
	if cam == null:
		return
	var centre := cam.get_screen_center_position() - level.global_position
	var want := ambient_at(centre.length())
	var k := 1.0 if snap else 1.0 - exp(-delta * 4.0)
	modulate_node.color = modulate_node.color.lerp(want, k)
	var tint := looks.day_tint.sample(day_phase) if looks.day_tint else Color.WHITE
	var daylight := tint.get_luminance()
	# backdrop quads cover the screen around the camera
	var view := get_viewport_rect().size / cam.zoom * 1.5 + Vector2(64, 64)
	var xf := Transform2D(cam.global_rotation, view, 0.0, cam.get_screen_center_position())
	soil.global_transform = xf
	sky.transform = xf
	var cam_ang := centre.angle()
	var sm := soil.material as ShaderMaterial
	sm.set_shader_parameter("origin", level.global_position)
	sm.set_shader_parameter("cam_angle", cam_ang)
	sm.set_shader_parameter("cam_depth", surface_px - centre.length())
	var km := sky.material as ShaderMaterial
	km.set_shader_parameter("origin", level.global_position)
	km.set_shader_parameter("cam_angle", cam_ang)
	km.set_shader_parameter("top", looks.sky_top.sample(day_phase) if looks.sky_top else Color.SKY_BLUE)
	var hz: Color = looks.sky_horizon.sample(day_phase) if looks.sky_horizon else Color.WHITE
	km.set_shader_parameter("horizon", hz)
	km.set_shader_parameter("hill_far", Color(0.36, 0.52, 0.56) * tint)
	km.set_shader_parameter("hill_near", Color(0.22, 0.36, 0.3) * tint)
	km.set_shader_parameter("night", clampf((0.8 - daylight) / 0.4, 0.0, 1.0))
	km.set_shader_parameter("rain", wetness)
	km.set_shader_parameter("time", world.clock)
	var tm := (world.tile_art as RingTileArt).material if world.tile_art is RingTileArt else null
	if tm:
		tm.set_shader_parameter("wet", wetness)
		tm.set_shader_parameter("wet_depth", looks.soak_tiles * 16.0 * wetness + 24.0)
	for s in shafts:
		var e := daylight * daylight * (1.0 - 0.4 * wetness)
		(s.get_node("Light") as PointLight2D).energy = 1.4 * e
		(s.get_node("Beam") as Sprite2D).modulate.a = 0.22 * e
	_cull_lights(cam.get_screen_center_position())


## Ambient light at a distance (px) from the core: the ring's top-to-bottom ramp, with the day
## tint (and the rain's dimming) reaching down as far as the ring's `daylight` share.
func ambient_at(r_px: float) -> Color:
	var tint := looks.day_tint.sample(day_phase) if looks.day_tint else Color.WHITE
	tint = tint * lerpf(1.0, looks.rain_dim, wetness)
	if r_px >= surface_px:
		return tint
	var rs := world.rings.rings
	var inner := 0.0
	for r in rs:
		var o := r.outer * surface_px
		if r_px < o or r == rs[rs.size() - 1]:
			var look := looks.look_of(r.id)
			if look == null:
				return Color.WHITE
			var f := clampf((r_px - inner) / maxf(o - inner, 1.0), 0.0, 1.0)
			var base := look.ambient_bottom.lerp(look.ambient_top, f)
			var lit := base * Color.WHITE.lerp(tint, look.daylight)
			lit.a = 1.0
			return lit
		inner = o
	return Color.WHITE


# --- backdrop -----------------------------------------------------------------------------------

func _unit_quad() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])


func _build_soil() -> void:
	soil = Polygon2D.new()
	soil.name = "SoilParallax"
	soil.polygon = _unit_quad()
	soil.z_index = -3
	var m := ShaderMaterial.new()
	m.shader = SOIL_SHADER
	m.set_shader_parameter("layers", LAYERS)
	m.set_shader_parameter("surface_r", surface_px)
	m.set_shader_parameter("bounds", _bounds)
	var cols := PackedVector3Array()
	for id in [&"core", &"deep_rock", &"dirt", &"topsoil", &"surface"]:
		var l := looks.look_of(id)
		for c in ([l.far_dark, l.far_light, l.mid, l.near, l.near_edge] if l else [Color.BLACK, Color.BLACK, Color.BLACK, Color.BLACK, Color.BLACK]):
			cols.append(Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("cols", cols)
	soil.material = m
	add_child(soil)


func _build_sky() -> void:
	sky_layer = CanvasLayer.new()
	sky_layer.name = "Sky"
	sky_layer.layer = -9
	sky_layer.follow_viewport_enabled = true
	sky = Polygon2D.new()
	sky.polygon = _unit_quad()
	var m := ShaderMaterial.new()
	m.shader = SKY_SHADER
	m.set_shader_parameter("clouds", CLOUDS)
	m.set_shader_parameter("surface_r", surface_px)
	sky.material = m
	sky_layer.add_child(sky)
	add_child(sky_layer)


# --- worms, food and creatures ------------------------------------------------------------------

func _scan() -> void:
	for w in Worm.all():
		if not lanterns.has(w) or not is_instance_valid(lanterns[w]):
			_add_lantern(w)
		var l := lanterns[w]
		if w.model:
			l.texture_scale = looks.lantern_scale * w.size_factor()
	for n in get_tree().get_nodes_in_group(&"food"):
		if n is Node2D and not n.has_meta(&"face_sprite") and level.is_ancestor_of(n):
			FaceSprite.attach(n)
			_add_glow(n)
	for n in get_tree().get_nodes_in_group(&"birds"):
		if n is Node2D and not n.has_meta(&"face_sprite"):
			FaceSprite.attach(n)
	var apex = level.get(&"beetle")
	if apex is Node2D and not apex.has_meta(&"face_sprite"):
		FaceSprite.attach(apex)


func _add_lantern(w: Worm) -> void:
	var l := PointLight2D.new()
	l.name = "Lantern"
	l.texture = LANTERN
	l.color = looks.lantern.lerp(P_COLOURS[clampi(w.player, 0, 1)], looks.lantern_tint)
	l.energy = looks.lantern_energy
	l.texture_scale = looks.lantern_scale
	w.head.add_child(l)
	lanterns[w] = l
	if not w.ate.is_connected(_on_worm_ate):
		w.ate.connect(_on_worm_ate.bind(w))


func _add_glow(n: Node2D) -> void:
	var d = n.get(&"data")
	if d == null or not looks.glow.has(d.id):
		return
	var c: Color = looks.glow[d.id]
	var l := PointLight2D.new()
	l.name = "Glow"
	l.texture = GLOW
	l.color = Color(c.r, c.g, c.b)
	l.energy = c.a * 2.0
	l.texture_scale = 1.6 + float(d.radius) * 0.12
	n.add_child(l)
	glows.append(l)


## Only the nearest max_glows glowing foods and max_shafts shafts light up (cheap at any count).
func _cull_lights(at: Vector2) -> void:
	glows.assign(glows.filter(func(l) -> bool: return is_instance_valid(l)))
	glows.sort_custom(func(a: PointLight2D, b: PointLight2D) -> bool:
		return a.global_position.distance_squared_to(at) < b.global_position.distance_squared_to(at))
	for i in glows.size():
		var host := glows[i].get_parent() as Node2D
		var gone: bool = host != null and bool(host.get(&"_gone"))
		glows[i].enabled = i < looks.max_glows and not gone and glows[i].global_position.distance_to(at) < 900.0
	var by_d := shafts.duplicate()
	by_d.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(at) < b.global_position.distance_squared_to(at))
	for i in by_d.size():
		by_d[i].visible = i < looks.max_shafts


func light_counts() -> Dictionary:
	var on := func(arr: Array) -> int:
		return arr.filter(func(l) -> bool: return is_instance_valid(l) and l.enabled and l.is_visible_in_tree()).size()
	var shaft_lights: Array = []
	for s in shafts:
		shaft_lights.append(s.get_node("Light"))
	return {"lanterns": on.call(lanterns.values()), "glows": on.call(glows), "shafts": on.call(shaft_lights),
		"glows_total": glows.size(), "shafts_total": shafts.size()}


# --- juice ---------------------------------------------------------------------------------------

func _colour_of(what: StringName) -> Color:
	if _food_cols.has(what):
		return _food_cols[what]
	var c := Color(0.55, 0.38, 0.2)
	for p in ["res://data/foods/%s.tres", "res://data/creatures/%s.tres"]:
		if ResourceLoader.exists(p % what):
			var d = load(p % what)
			if d and &"color" in d:
				c = d.color
				break
	var id := world.id_of(what)
	if id > 0 and world.palette[id]:
		c = world.palette[id].color
	_food_cols[what] = c
	return c


func _on_worm_ate(_player: int, what: StringName, growth: float, w: Worm) -> void:
	if not is_instance_valid(w) or world.id_of(what) > 0:
		return  # tiles: _on_tile_eaten
	Juice.chomp(w.mouth_position(), _colour_of(what), 0.8 + growth * 0.6)
	Juice.shake(clampf(0.1 + growth * 0.06, 0.0, 0.45))


func _on_tile_eaten(cell: Vector2i, block: StringName, player: int) -> void:
	if world.shape.center_of(cell).length() >= crust_px - 8.0:
		_try_shaft(cell)
	if _puff_t.get(player, 0.0) > 0.0:
		return
	_puff_t[player] = TILE_PUFF_EVERY
	var w := Worm.of(player)
	var at := world.to_global(world.shape.center_of(cell))
	var col := _colour_of(block)
	if w:
		Juice.chomp(w.mouth_position(), col, 0.5)
	if randf() < 0.5:
		Juice.debris(at, col.darkened(0.15), 4)


# --- daylight shafts ------------------------------------------------------------------------------

## A crust cell eaten all the way through to the sky (every cell above it is air) opens a shaft.
func _open_to_sky(cell: Vector2i) -> bool:
	var p := world.shape.center_of(cell)
	var up := p.normalized()
	var r := p.length()
	while r < surface_px + 8.0:
		var c := world.shape.cell_at(up * r)
		if world.shape.contains(c) and world.is_solid(c):
			return false
		r += 8.0
	return true


func _try_shaft(cell: Vector2i) -> void:
	if not _open_to_sky(cell):
		return
	var up := world.shape.center_of(cell).normalized()
	var top := up * surface_px
	for s in shafts:
		if s.position.distance_to(top) < 40.0:
			return
	var s := Node2D.new()
	s.name = "Shaft%d" % shafts.size()
	s.position = top
	s.rotation = up.angle() + PI / 2.0  # local +y points at the core
	s.z_index = 4
	var l := PointLight2D.new()
	l.name = "Light"
	l.texture = SHAFT
	l.offset = Vector2(0, SHAFT.get_height() * 0.5 - 6.0)
	l.color = looks.sun
	l.energy = 1.4
	s.add_child(l)
	var beam := Sprite2D.new()
	beam.name = "Beam"
	beam.texture = SHAFT
	beam.offset = l.offset
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	beam.material = add
	beam.modulate = Color(looks.sun.r, looks.sun.g, looks.sun.b, 0.22)
	s.add_child(beam)
	add_child(s)
	shafts.append(s)


## Holes that grew back close their shafts.
func _check_shafts() -> void:
	for s in shafts.duplicate():
		var c := world.shape.cell_at(s.position.normalized() * (surface_px - 8.0))
		if world.is_solid(c):
			shafts.erase(s)
			s.queue_free()


func _scan_existing_holes() -> void:
	for cell: Vector2i in world.edits.tiles:
		if world.edits.tiles[cell] == 0 and world.shape.center_of(cell).length() >= crust_px - 8.0:
			_try_shaft(cell)
