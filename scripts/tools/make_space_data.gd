## Writes data/planets/*.tres (S-18) and data/rings/space_life.tres (W-08). Reproducible: rerun after
## changing a number here, or edit the .tres files directly (this script then overwrites them).
##   godot --headless --path . -s scripts/tools/make_space_data.gd
extends SceneTree

const PLANET := preload("res://scripts/space/planet_data.gd")
const LIFE := preload("res://scripts/space/space_life.gd")
const FOOD := preload("res://scripts/worm/food_data.gd")
const TRAIT := preload("res://scripts/worm/trait_data.gd")
const RULE := preload("res://scripts/rings/population_rule.gd")

# id, colour, accent, radius px, meal, drift px/s, foods [[id, stage, radius, colour, growth]],
# star [id, colour, add]
const PLANETS := [
	["ice", "bfe6f5", "6fb3d9", 170.0, 8, 30.0,
		[["snowball", 5, 30.0, "f4fbff", 2.0], ["ice_cube", 5, 36.0, "9fdcf2", 2.0], ["frost_moon", 6, 52.0, "d8eef8", 3.0]],
		["frost_star", "7fe3ff", {"space_speed": 60.0}]],
	["jungle", "4fae5a", "2f7a3a", 240.0, 8, 26.0,
		[["coconut", 5, 34.0, "8a5a34", 2.0], ["vine_ball", 5, 32.0, "7cc84a", 2.0], ["fern_moon", 6, 54.0, "3f9a4a", 3.0]],
		["vine_star", "5fe36a", {"space_reach": 18.0}]],
	["junk", "8d8f96", "5c5e66", 280.0, 8, 22.0,
		[["tin_can", 5, 32.0, "c3c6cc", 2.0], ["old_bolt", 5, 28.0, "a6875a", 2.0], ["scrap_moon", 6, 56.0, "7a7c84", 3.0]],
		["anchor_star", "b9bcc6", {"space_steady": 0.4}]],
	["candy", "f39ac3", "d35f9a", 200.0, 8, 28.0,
		[["gumdrop", 5, 30.0, "ff6f91", 2.0], ["lollipop", 5, 34.0, "ffd94a", 2.0], ["cake_moon", 6, 54.0, "fbe3c8", 3.0]],
		["sugar_star", "ff8fd0", {"space_speed": 30.0, "space_reach": 8.0}]],
	["clockwork", "d7a645", "8f6a22", 320.0, 8, 20.0,
		[["cog", 5, 32.0, "c99a3a", 2.0], ["spring_coil", 5, 30.0, "b8b8c0", 2.0], ["clock_moon", 6, 56.0, "f0d68a", 3.0]],
		["tick_star", "ffcf5a", {"space_speed": 20.0, "space_steady": 0.25}]],
]


func _food(spec: Array) -> Resource:
	var f = FOOD.new()
	f.id = StringName(spec[0])
	f.flavour = &"star"
	f.size_stage = spec[1]
	f.radius = spec[2]
	f.color = Color(spec[3])
	f.growth = spec[4]
	return f


func _rule(id: String, start: float, plant: bool, growth: float, cap: float, death: float, imm: float,
		scale: float, live_max: int) -> Resource:
	var r = RULE.new()
	r.id = StringName(id)
	r.ring = &"space"
	r.start = start
	r.plant = plant
	r.growth_rate = growth
	r.capacity = cap
	r.death = death
	r.immigration = imm
	r.live_scale = scale
	r.live_max = live_max
	return r


func _init() -> void:
	var planets: Array = []
	for spec in PLANETS:
		var d = PLANET.new()
		d.id = StringName(spec[0])
		d.color = Color(spec[1])
		d.accent = Color(spec[2])
		d.size_stage = 9
		d.ripe_stage = 6
		d.radius = spec[3]
		d.meal = spec[4]
		d.drift = spec[5]
		for f in spec[6]:
			d.foods.append(_food(f))
		var t = TRAIT.new()
		t.id = StringName(spec[7][0])
		t.color = Color(spec[7][1])
		t.add = spec[7][2]
		t.part_slot = &"space"
		d.star_trait = t
		d.star_chance = 0.15
		var path := "res://data/planets/%s.tres" % spec[0]
		ResourceSaver.save(d, path)
		planets.append(path)
	var life = LIFE.new()
	life.ring = &"space"
	for path in planets:
		life.planets.append(load(path))
	life.moon = _food(["moon", 5, 40.0, "d9d6c8", 2.0])
	life.comet = _food(["comet", 4, 26.0, "9fe8ff", 1.5])
	life.species.append(_rule("moon", 12.0, true, 0.02, 20.0, 0.0, 0.01, 0.25, 4))
	life.species.append(_rule("comet", 2.0, false, 0.0, 6.0, 0.01, 0.03, 1.0, 2))
	life.species.append(_rule("planet", 5.0, false, 0.0, 5.0, 0.0, 0.0, 0.0, 0))
	life.species.append(_rule("sun", 1.0, false, 0.0, 1.0, 0.0, 0.0, 0.0, 0))
	life.spawn_min = 700.0
	life.spawn_max = 1100.0
	ResourceSaver.save(life, "res://data/rings/space_life.tres")
	print("space data written: %d planets" % planets.size())
	quit()
