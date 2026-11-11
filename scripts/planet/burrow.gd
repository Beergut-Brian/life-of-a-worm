## The burrow: home. Hollow out a chamber anywhere and sleep in it (hold still in a hollow for
## SLEEP_STILL s) and that is home; sleeping in another hollow moves home there. Things carried
## home become a trophy on the dug shelf, or (a seed) a garden in the castings by the door. The
## trait wall hangs here: Y opens it only in the burrow. Nothing in a burrow ever regrows (the
## world's keep zone). One burrow per bait tin, shared by both worms. Placeholder art, drawn here.
class_name Burrow
extends Node2D

signal home_set(player: int, at: Vector2)
signal brought_home(player: int, what: StringName, kind: StringName)   # trophy | seed

const SLEEP_STILL := 2.0
## A hollow: at least HOLLOW_SHARE of the cells within HOLLOW_TILES of the head are air.
const HOLLOW_TILES := 2.0
const HOLLOW_SHARE := 0.75
## In the burrow: within this many tiles of home.
const ROOM_TILES := 4.0
const SHELF_SLOTS := 8
const FOODS := "res://data/foods/%s.tres"

var world: PolarWorld
var has_home := false
var home := Vector2.ZERO
var trophies: Array[StringName] = []
var seeds: Array[Dictionary] = []      # {flavour, cell}
var _t := 0.0


## Pure rule, for tests: is the world hollow round pos (world-local px)?
static func is_hollow(w: PolarWorld, pos: Vector2, tiles := HOLLOW_TILES, share := HOLLOW_SHARE) -> bool:
	var cs := float(w.shape.cell_size)
	var c := pos / cs
	var r := tiles
	var total := 0
	var air := 0
	for y in range(floori(c.y - r), ceili(c.y + r) + 1):
		for x in range(floori(c.x - r), ceili(c.x + r) + 1):
			if (Vector2(x + 0.5, y + 0.5) - c).length_squared() <= r * r:
				total += 1
				if not w.is_solid(Vector2i(x, y)):
					air += 1
	return total > 0 and float(air) / total >= share


func in_room(pos: Vector2) -> bool:
	return has_home and pos.distance_to(home) <= ROOM_TILES * 16.0


## Can this worm fall asleep here right now?
func can_sleep(w: Worm) -> bool:
	return w.still_time >= SLEEP_STILL and not w.asleep and is_hollow(world, world.to_local(w.head_position()))


## Sleep: home is here now. The level autosaves on home_set.
func sleep(w: Worm) -> void:
	w.asleep = true
	Audio.play("sleep")
	set_home(world.to_local(w.head_position()), w.player)


func set_home(at: Vector2, player := 0) -> void:
	var moved := not has_home or at.distance_to(home) > ROOM_TILES * 16.0
	has_home = true
	home = at
	if moved and world:
		world.keep_zones.clear()
		world.add_keep_zone(home, (ROOM_TILES + 1.0) * 16.0)
	queue_redraw()
	home_set.emit(player, home)


## The worm carrying `food` (a group-food node with data: FoodData) reached home.
func bring(w: Worm, food: Node2D) -> StringName:
	var data: FoodData = food.data
	var kind := &"trophy"
	if data.id == &"seed" and world and _plant(data.flavour):
		kind = &"seed"
		Audio.play("home_seed")
	else:
		trophies.append(data.id)
		_dig_shelf(trophies.size() - 1)
		Audio.play("home_trophy")
	w.carrying = null
	food.call("take")
	brought_home.emit(w.player, data.id, kind)
	queue_redraw()
	return kind


func _plant(flavour: StringName) -> bool:
	var c := world.shape.cell_at(home)
	for r in range(1, int(ROOM_TILES) + 1):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var cell := c + Vector2i(x, y)
				if world.plant_seed(cell, flavour):
					seeds.append({ "flavour": String(flavour), "cell": [cell.x, cell.y] })
					return true
	return false


## The shelf is dug along the burrow's floor (the side toward the core): one notch per trophy.
func slot_position(i: int) -> Vector2:
	var down := -home.normalized()
	var side := down.orthogonal()
	var k := (i % SHELF_SLOTS) - (SHELF_SLOTS - 1) * 0.5
	return home + down * 2.4 * 16.0 + side * k * 12.0 - down * floorf(i / SHELF_SLOTS) * 14.0


func _dig_shelf(i: int) -> void:
	if world == null:
		return
	world.dig(world.shape.cell_at(slot_position(i)))


func to_dict() -> Dictionary:
	return { "has_home": has_home, "home": [home.x, home.y],
		"trophies": trophies.map(func(t): return String(t)), "seeds": seeds.duplicate(true) }


func from_dict(d: Dictionary) -> void:
	has_home = bool(d.get("has_home", false))
	var h: Array = d.get("home", [0, 0])
	home = Vector2(h[0], h[1])
	trophies.clear()
	for t in d.get("trophies", []):
		trophies.append(StringName(t))
	seeds.assign(d.get("seeds", []))
	if has_home and world:
		world.keep_zones.clear()
		world.add_keep_zone(home, (ROOM_TILES + 1.0) * 16.0)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if has_home and int(_t * 4.0) != int((_t - delta) * 4.0):
		queue_redraw()


func _draw() -> void:
	if not has_home:
		return
	var down := -home.normalized()
	var rot := down.angle() - PI / 2.0   # "up" of the burrow points away from the core
	# Bed: a soft mat where the worm slept.
	draw_set_transform(home + down * 10.0, rot, Vector2.ONE)
	draw_rect(Rect2(-14, -3, 28, 6), Color(0.75, 0.6, 0.4, 0.8))
	# Shelf plank under the trophy slots.
	draw_set_transform(home, rot, Vector2.ONE)
	var shelf_y := 2.4 * 16.0 + 6.0
	draw_rect(Rect2(-SHELF_SLOTS * 6.0 - 4.0, shelf_y, SHELF_SLOTS * 12.0 + 8.0, 3.0), Color("7a5230"))
	# Trait wall (placeholder plaque above the bed): one socket per earned trait of each worm.
	var y := -1.4 * 16.0
	draw_rect(Rect2(-30, y - 8, 60, 16), Color("4a3524"))
	draw_rect(Rect2(-30, y - 8, 60, 16), Color("2a1a14"), false, 2.0)
	var x := -24.0
	for w in Worm.all():
		for id in w.model.earned:
			var t := w.rules.find_trait(id)
			var col := t.color if t else Color.WHITE
			draw_circle(Vector2(x, y), 4.0, col if w.model.is_active(id) else col.darkened(0.5))
			x += 10.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in trophies.size():
		var p := slot_position(i)
		var f: FoodData = load(FOODS % trophies[i]) if ResourceLoader.exists(FOODS % trophies[i]) else null
		var col := f.color if f else Color.WHITE
		var bob := sin(_t * 2.0 + i) * 0.6
		draw_circle(p + Vector2(0, bob), 5.0, Color("2a1a14"))
		draw_circle(p + Vector2(0, bob), 4.0, col)
		draw_circle(p + Vector2(-1.2, -1.2 + bob), 1.2, col.lightened(0.5))
