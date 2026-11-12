## The burrow: home. Hollow out a chamber anywhere and sleep in it (hold still in a hollow for
## SLEEP_STILL s) and that is home; sleeping in another hollow moves home there (trophies, pets and
## the pantry come along: they are data). One burrow per bait tin, shared by both worms.
##
## Carried home (hold X), a thing becomes:
##  - a seed: a garden in the castings by the door;
##  - a small creature (a WildPet): a pet with a job (PetData), living by the bed. The first of a
##    kind plays the meet beat (Pet.meet). One past its kind's cap (PetData.max_kept, the ant crew
##    1) says hello to the one at home and runs back to the wild: still a "pet" homecoming;
##  - anything else: a trophy on a shelf. A shelf is any ledge the worm has dug inside the room (an
##    air cell with solid ground under it, toward the core); the trophy lands on the free ledge
##    nearest the worm. With no free ledge a notch is dug in the floor, so nobody is ever refused.
## Trophy families (data/trophies/) give every worm a small standing bonus (TrophyBonus).
## The bed is the sleep spot: falling asleep saves the tin, and Y while asleep opens the trait wall
## (it opens by itself when a newly earned trait is waiting). The room grows with the worm's stage.
## Nothing in a burrow ever regrows (the world's keep zone). Placeholder art, drawn here.
class_name Burrow
extends Node2D

signal home_set(player: int, at: Vector2)
signal brought_home(player: int, what: StringName, kind: StringName)   # trophy | seed | pet
## The family bonus changed (stat -> add); HomeSlice applies it to every worm.
signal bonus_changed(bonus: Dictionary)
## The room grew (a stage-up).
signal grew(stage: int)

const SLEEP_STILL := 2.0
## A hollow: at least HOLLOW_SHARE of the cells within HOLLOW_TILES of the head are air.
const HOLLOW_TILES := 2.0
const HOLLOW_SHARE := 0.75
## In the burrow: within room_tiles() of home (ROOM_TILES at stage 1, + ROOM_GROWTH a stage).
const ROOM_TILES := 4.0
const ROOM_GROWTH := 1.5
## The chamber carved round the bed when the burrow grows: CHAMBER_TILES + CHAMBER_GROWTH a stage.
const CHAMBER_TILES := 2.0
const CHAMBER_GROWTH := 1.0
const SHELF_SLOTS := 8
const MAX_PETS := 3
const FOODS := "res://data/foods/%s.tres"
const PETS := "res://data/pets/%s.tres"
const PET_SCRIPT := preload("res://scripts/pets/pet.gd")
const FOOD_SCRIPT := preload("res://scripts/arena/arena_food.gd")
const SEED := preload("res://data/foods/seed.tres")

var world: PolarWorld
var has_home := false
var home := Vector2.ZERO
var trophies: Array[StringName] = []
## Shelf cell of each trophy (parallel to trophies).
var trophy_cells: Array[Vector2i] = []
var seeds: Array[Dictionary] = []      # {flavour, cell}
## Pet nodes living here (Pet), saved by id.
var pets: Array[Node2D] = []
## Seeds the pets brought, waiting by the bed (ArenaFood nodes; eat them or carry them out).
var pantry: Array[Node2D] = []
## Pet kinds that have already had their meet beat in this tin (saved).
var met: Array[StringName] = []
## Night hook for the glow-worm lamp (Pet.is_dark): a day/night clock sets it; nothing does yet.
var night := false
## The biggest stage a worm of this tin has reached: the room's size.
var stage := 1
var families: Array[TrophyFamily] = []
var _t := 0.0
var _fallback := 0
## player -> the carried node it picked up inside the room (never "brought home" again).
var _picked_inside := {}
var _last_carry := {}


func _init() -> void:
	families = TrophyFamily.load_all()


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


static func room_tiles_for(s: int) -> float:
	return ROOM_TILES + ROOM_GROWTH * (maxi(1, s) - 1)


func room_tiles() -> float:
	return room_tiles_for(stage)


func in_room(pos: Vector2) -> bool:
	return has_home and pos.distance_to(home) <= room_tiles() * 16.0


## Can this worm fall asleep here right now?
func can_sleep(w: Worm) -> bool:
	return w.still_time >= SLEEP_STILL and not w.asleep and is_hollow(world, world.to_local(w.head_position()))


## Sleep: home is here now (the level autosaves on home_set). A trait waiting on the wall opens it.
func sleep(w: Worm) -> void:
	w.asleep = true
	Audio.play("sleep")
	set_home(world.to_local(w.head_position()), w.player)
	if w.model.earned.size() > w.model.active.size() and w.model.slots() > 0 and not w.wall_open:
		w.in_burrow = true   # asleep in the bed: the wall is open (the level keeps it so)
		w.set_wall_open(true)


func set_home(at: Vector2, player := 0) -> void:
	var moved := not has_home or at.distance_to(home) > room_tiles() * 16.0
	var shift := at - home if has_home else Vector2.ZERO
	has_home = true
	home = at
	if moved:
		_keep_zone()
		# Things are data: they come along to the new home, re-shelved there.
		if shift != Vector2.ZERO:
			var ids := trophies.duplicate()
			trophies.clear()
			trophy_cells.clear()
			for id in ids:
				_shelve(id, home)
			for p in pets:
				p.position = pet_spot(pets.find(p))
			for i in pantry.size():
				pantry[i].position = pantry_spot(i)
				pantry[i].home = pantry[i].position
	queue_redraw()
	home_set.emit(player, home)


func _keep_zone() -> void:
	if world:
		world.keep_zones.clear()
		world.add_keep_zone(home, (room_tiles() + 1.0) * 16.0)


## The level calls this each frame for each carrying worm in the room: true when the carried thing
## came from outside (picked up in the room, it is just being moved about).
func should_bring(w: Worm) -> bool:
	if w.carrying == null or not is_instance_valid(w.carrying):
		return false
	if w.carrying.has_method("pet_id"):   # a creature carried in is always a new pet
		return true
	return _picked_inside.get(w.player) != w.carrying


## The level calls this each frame for every worm: remembers whether the thing it carries now was
## picked up inside the room.
func note_pickup(w: Worm, inside: bool) -> void:
	var c: Node2D = w.carrying if w.carrying != null and is_instance_valid(w.carrying) else null
	if c == null:
		_last_carry.erase(w.player)
		_picked_inside.erase(w.player)
		return
	if _last_carry.get(w.player) != c:
		_last_carry[w.player] = c
		if inside:
			_picked_inside[w.player] = c
		else:
			_picked_inside.erase(w.player)


## The worm carrying `food` (a group-food node with data: FoodData) reached home.
func bring(w: Worm, food: Node2D) -> StringName:
	var data: FoodData = food.data
	var kind := &"trophy"
	var pid: StringName = food.call("pet_id") if food.has_method("pet_id") else &""
	if pid != &"" and can_keep(pid):
		kind = &"pet"
		var p: Node2D = add_pet(pid)
		Audio.play("pet_home")
		if p and not met.has(pid):
			met.append(pid)
			p.meet()
	elif pid != &"" and pet_count(pid) > 0:
		kind = &"pet"   # one of its kind lives here already: a hello, then back to the wild
		for p in pets:
			if p.data.id == pid:
				p.meet_t = Pet.MEET_SECS * 0.5
				break
		Audio.play("pet_hello")
	elif data.id == &"seed" and world and _plant(data.flavour):
		kind = &"seed"
		Audio.play("home_seed")
	else:
		_shelve(data.id, w.head_position() - global_position if world == null else world.to_local(w.head_position()))
		Audio.play("home_trophy")
	w.carrying = null
	food.call("take")
	brought_home.emit(w.player, data.id, kind)
	queue_redraw()
	return kind


# --- trophies -------------------------------------------------------------------------------------

## Puts trophy `id` on the free dug ledge nearest `near` (a notch in the floor if there is none).
func _shelve(id: StringName, near: Vector2) -> Vector2i:
	var cell := free_ledge(near)
	if cell == Vector2i(-99999, -99999):
		cell = _dig_notch()
	trophies.append(id)
	trophy_cells.append(cell)
	bonus_changed.emit(bonus())
	return cell


## A ledge: an air cell in the room with solid ground under it (toward the core), not the bed, not
## already holding a trophy. Nearest to `near`; Vector2i(-99999, -99999) if none.
func free_ledge(near: Vector2) -> Vector2i:
	var none := Vector2i(-99999, -99999)
	if world == null or not has_home:
		return none
	var best := none
	var best_d := INF
	var c := world.shape.cell_at(home)
	var n := ceili(room_tiles())
	var bed := bed_position()
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			var cell := c + Vector2i(x, y)
			var at := world.shape.center_of(cell)
			if at.distance_to(home) > room_tiles() * 16.0 - 6.0 or at.distance_to(bed) < 14.0:
				continue
			if world.is_solid(cell) or trophy_cells.has(cell):
				continue
			var below := world.shape.cell_at(at - at.normalized() * 16.0)
			if not world.is_solid(below):
				continue
			var d := at.distance_to(near)
			if d < best_d:
				best_d = d
				best = cell
	return best


func _dig_notch() -> Vector2i:
	while true:
		var p := slot_position(_fallback)
		_fallback += 1
		if world == null:
			return Vector2i(roundi(p.x), roundi(p.y))
		var cell := world.shape.cell_at(p)
		if not trophy_cells.has(cell):
			world.dig(cell)
			return cell
	return Vector2i.ZERO


## Where a trophy on `cell` sits (on the floor of its ledge).
func trophy_position(i: int) -> Vector2:
	var cell := trophy_cells[i]
	if world == null:
		return Vector2(cell)
	var at := world.shape.center_of(cell)
	return at - at.normalized() * 3.0


## Fallback floor notches along the burrow's floor (the side toward the core).
func slot_position(i: int) -> Vector2:
	var down := -home.normalized()
	var side := down.orthogonal()
	var k := (i % SHELF_SLOTS) - (SHELF_SLOTS - 1) * 0.5
	return home + down * 2.4 * 16.0 + side * k * 16.0 - down * floorf(i / SHELF_SLOTS) * 16.0


## Trophies per family on the shelf: family id -> count.
func family_counts() -> Dictionary:
	var out := {}
	for id in trophies:
		var f := TrophyFamily.family_of(families, id)
		if f:
			out[f.id] = int(out.get(f.id, 0)) + 1
	return out


## The standing bonus every worm gets from the shelf: stat -> add (each family up to its cap).
func bonus() -> Dictionary:
	var out := {}
	var counts := family_counts()
	for f in families:
		var n := mini(int(counts.get(f.id, 0)), f.cap)
		if n <= 0:
			continue
		for k in f.per_trophy:
			out[k] = float(out.get(k, 0.0)) + float(f.per_trophy[k]) * n
	return out


## Trades a shelf trophy away (the Mole's swap shop): removes the newest trophy of `id` (any if &"").
func remove_trophy(id: StringName = &"") -> StringName:
	for i in range(trophies.size() - 1, -1, -1):
		if id == &"" or trophies[i] == id:
			var got := trophies[i]
			trophies.remove_at(i)
			trophy_cells.remove_at(i)
			bonus_changed.emit(bonus())
			queue_redraw()
			return got
	return &""


# --- seeds, pets, pantry --------------------------------------------------------------------------

func _plant(flavour: StringName) -> bool:
	var c := world.shape.cell_at(home)
	for r in range(1, int(room_tiles()) + 1):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var cell := c + Vector2i(x, y)
				if world.plant_seed(cell, flavour):
					seeds.append({ "flavour": String(flavour), "cell": [cell.x, cell.y] })
					return true
	return false


func bed_position() -> Vector2:
	return home - home.normalized() * 10.0


func pet_spot(i: int) -> Vector2:
	var up := home.normalized()
	return home + up * 12.0 + up.orthogonal() * (i - 1) * 14.0


func pantry_spot(i: int) -> Vector2:
	var up := home.normalized()
	return home - up * 4.0 - up.orthogonal() * (22.0 + i * 9.0)


func add_pet(id: StringName, t := 0.0) -> Node2D:
	var path := PETS % id
	if not ResourceLoader.exists(path):
		return null
	var p: Node2D = PET_SCRIPT.new()
	p.data = load(path)
	p.burrow = self
	p.t = t
	p.position = pet_spot(pets.size())
	p.z_index = 2
	pets.append(p)
	add_child(p)
	return p


func pet_count(id: StringName) -> int:
	var n := 0
	for p in pets:
		if p.data.id == id:
			n += 1
	return n


## Room for one more pet of kind `id` (the total cap, and its own PetData.max_kept)?
func can_keep(id: StringName) -> bool:
	var path := PETS % id
	if pets.size() >= MAX_PETS or not ResourceLoader.exists(path):
		return false
	var d: PetData = load(path)
	return pet_count(id) < d.max_kept


func pet_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for p in pets:
		out.append(p.data.id)
	return out


## A pet came back with a seed: it waits by the bed (eat it, or carry it out to castings).
func add_pantry(_what: StringName = &"seed") -> Node2D:
	var f: Node2D = FOOD_SCRIPT.new()
	f.data = SEED
	f.position = pantry_spot(pantry.size())
	add_child(f)
	f.home = f.position
	pantry.append(f)
	f.taken.connect(func(n: Node2D) -> void:
		pantry.erase(n)
		n.queue_free())
	return f


# --- growing --------------------------------------------------------------------------------------

## A worm reached stage s: the room grows (a bigger chamber is carved round the bed, the keep zone
## and the shelf area grow with it).
func grow_to(s: int) -> bool:
	if s <= stage:
		return false
	stage = s
	if has_home and world:
		_keep_zone()
		var r := (CHAMBER_TILES + CHAMBER_GROWTH * (stage - 1)) * 16.0
		var c := world.shape.cell_at(home)
		var n := ceili(r / 16.0)
		for y in range(-n, n + 1):
			for x in range(-n, n + 1):
				var cell := c + Vector2i(x, y)
				if world.shape.center_of(cell).distance_to(home) <= r and world.is_edible_by(stage, cell) and not trophy_cells.has(cell):
					world.dig(cell)
		Audio.play("burrow_grow")
	grew.emit(stage)
	queue_redraw()
	return true


# --- save -----------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var cells := []
	for c in trophy_cells:
		cells.append([c.x, c.y])
	var pet_list := []
	for p in pets:
		pet_list.append({ "id": String(p.data.id), "t": p.t })
	return { "has_home": has_home, "home": [home.x, home.y],
		"trophies": trophies.map(func(t): return String(t)), "cells": cells,
		"seeds": seeds.duplicate(true), "pets": pet_list, "pantry": pantry.size(),
		"met": met.map(func(m): return String(m)),
		"stage": stage, "fallback": _fallback }


func from_dict(d: Dictionary) -> void:
	has_home = bool(d.get("has_home", false))
	var h: Array = d.get("home", [0, 0])
	home = Vector2(h[0], h[1])
	stage = int(d.get("stage", 1))
	_fallback = int(d.get("fallback", 0))
	trophies.clear()
	trophy_cells.clear()
	var cells: Array = d.get("cells", [])
	var list: Array = d.get("trophies", [])
	for i in list.size():
		trophies.append(StringName(list[i]))
		if i < cells.size():
			trophy_cells.append(Vector2i(int(cells[i][0]), int(cells[i][1])))
		elif world:
			trophy_cells.append(world.shape.cell_at(slot_position(i)))
		else:
			trophy_cells.append(Vector2i(i, 0))
	seeds.assign(d.get("seeds", []))
	for p in pets:
		p.queue_free()
	pets.clear()
	met.clear()
	for m in d.get("met", []):
		met.append(StringName(m))
	for e in d.get("pets", []):
		add_pet(StringName(e.get("id", "")), float(e.get("t", 0.0)))
		var id := StringName(e.get("id", ""))
		if not met.has(id):   # a tin from before the meet beat: these were met already
			met.append(id)
	for f in pantry:
		f.queue_free()
	pantry.clear()
	for i in int(d.get("pantry", 0)):
		add_pantry()
	if has_home:
		_keep_zone()
	bonus_changed.emit(bonus())
	queue_redraw()


# --- look -----------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	if has_home and int(_t * 4.0) != int((_t - delta) * 4.0):
		queue_redraw()


func _draw() -> void:
	if not has_home:
		return
	var down := -home.normalized()
	var rot := down.angle() - PI / 2.0   # "up" of the burrow points away from the core
	# Room outline: a faint warm ring shows how big home is (it grows with the stage).
	draw_arc(home, room_tiles() * 16.0, 0.0, TAU, 48, Color(1, 0.85, 0.55, 0.10), 2.0)
	# Bed: a soft leaf mat where the worm sleeps.
	draw_set_transform(bed_position(), rot, Vector2.ONE)
	draw_rect(Rect2(-15, -3, 30, 6), Color(0.48, 0.7, 0.36, 0.9))
	draw_rect(Rect2(-15, -3, 30, 6), Color("2a1a14"), false, 1.0)
	draw_circle(Vector2(-12, -2), 3.5, Color(0.9, 0.85, 0.7))   # pillow
	# Trait wall (placeholder plaque above the bed): one socket per earned trait of each worm.
	draw_set_transform(home, rot, Vector2.ONE)
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
		_draw_trophy(i)


func _draw_trophy(i: int) -> void:
	var p := trophy_position(i)
	var down := -p.normalized()
	var side := down.orthogonal()
	var f: FoodData = load(FOODS % trophies[i]) if ResourceLoader.exists(FOODS % trophies[i]) else null
	var col := f.color if f else Color.WHITE
	var fam := TrophyFamily.family_of(families, trophies[i])
	# The little plank it stands on, tagged in its family colour.
	draw_line(p + down * 5.0 - side * 7.0, p + down * 5.0 + side * 7.0, Color("7a5230"), 3.0)
	if fam:
		draw_line(p + down * 5.0 + side * 4.0, p + down * 5.0 + side * 7.0, fam.color, 3.0)
	var bob := -down * sin(_t * 2.0 + i) * 0.6
	var r := f.radius if f else 4.0
	draw_circle(p + bob, r + 1.0, Color("2a1a14"))
	draw_circle(p + bob, r, col)
	draw_circle(p + bob - side * 1.2 - down * 1.2, maxf(1.0, r * 0.28), col.lightened(0.5))
	# A sparkle now and then: it's a treasure.
	if fmod(_t + i * 0.7, 3.0) < 0.25:
		var s := p + bob - down * (r + 3.0) + side * 3.0
		draw_line(s - side * 2.0, s + side * 2.0, Color(1, 1, 0.8), 1.0)
		draw_line(s - down * 2.0, s + down * 2.0, Color(1, 1, 0.8), 1.0)
