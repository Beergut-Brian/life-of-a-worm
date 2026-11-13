## S-15: stages 1 to 5 all happen in the one disk scene (scenes/levels/planet.tscn). A stage change
## swaps the worm's sprite set (head, every body segment, the tail, the stripe, the stage feature,
## all re-asked of WormLook at the new stage) and its collision size (the head circle from the
## stage row of data/stages.tres), and never the tile size: the planet's cells and every tile layer
## stay 16 px whatever stage the worm is at.
## A fake WormLook hands out a different texture per (stage, kind), so a sprite that was not swapped
## shows up as the wrong texture even while dev's art stub draws every stage alike.
extends GdUnitTestSuite

const PLANET := preload("res://scenes/levels/planet.tscn")
const TILE_PX := 16


## Same signatures as WormLook (scripts/worm/worm_hooks.gd); one texture per key.
class FakeLook extends RefCounted:
	var made := {}

	func _tex(key: String) -> Texture2D:
		if not made.has(key):
			var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
			img.fill(Color(randf(), randf(), randf()))
			made[key] = ImageTexture.create_from_image(img)
		return made[key]

	func segment_texture(player_id: int, stage: int, kind: StringName) -> Texture2D:
		return _tex("seg_%d_%d_%s" % [player_id, stage, kind])

	func face_texture(player_id: int, stage: int, mood: StringName) -> Texture2D:
		return _tex("face_%d_%d_%s" % [player_id, stage, mood])

	func feature_texture(stage: int) -> Texture2D:
		return _tex("feat_%d" % stage)

	func flavour_tint(_flavour_id: StringName) -> Color:
		return Color(1, 0.5, 0.2)


var _level: PlanetLevel
var _look: FakeLook


func before() -> void:
	SuiteSandbox.enter("stages_swap")


func after() -> void:
	for i in BaitTins.COUNT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path_for(BaitTins.slot_name(i))))
	Save.use_slot("")
	_hush()
	SuiteSandbox.leave()


func before_test() -> void:
	_look = FakeLook.new()
	WormHooks._look = _look


func after_test() -> void:
	_close()
	WormHooks._look = null   # the next caller picks the real look (or the stub) again
	_look = null
	Game.quit_exits = true
	Players.reset()
	Save.use_slot("")


func _open() -> PlanetLevel:
	Game.demo = false
	Game.quit_exits = false
	Players.reset()
	Audio.played.clear()
	BaitTins.open(0)
	Save.wipe()
	Save.set_value("seed", 77)   # a pinned planet, never randi()
	_level = PLANET.instantiate()
	_level.autosave_every = 9999.0
	add_child(_level)
	_level.stage_beat.make_story = false
	return _level


func _hush() -> void:
	for p in Audio._pool:
		p.stop()
		p.stream = null


func _close() -> void:
	_hush()
	if is_instance_valid(_level):
		for p in _level.find_children("*", "AudioStreamPlayer", true, false):
			(p as AudioStreamPlayer).stop()
		remove_child(_level)
		_level.free()
	_level = null


## Grow the way play does: segments, and the ring's apex when the body is big enough.
func _grow_to(w: Worm, stage: int) -> void:
	while w.model.stage < stage:
		if w.model.size_stage() > w.model.stage:
			w.model.eat_apex(w.model.stage)
		else:
			w.model.add_segment(&"")


func _radius(w: Worm) -> float:
	return ((w.get_node("Head/Shape") as CollisionShape2D).shape as CircleShape2D).radius


## The disk's tile size as the scene has it: the shape's cell size, then each distinct tile size of
## its tile layers (layers stream in and out with the worm, so their count changes; their size may not).
func _tile_sizes() -> Array:
	var out: Array = [_level.world.shape.cell_size]
	for n in _level.world.find_children("*", "TileMapLayer", true, false):
		var layer := n as TileMapLayer
		if layer.tile_set != null and not out.has(layer.tile_set.tile_size):
			out.append(layer.tile_set.tile_size)
	return out


func _segments(w: Worm) -> Array[WormSegment]:
	var out: Array[WormSegment] = []
	for n in w.body.get_children():
		if n is WormSegment and not n.is_queued_for_deletion():
			out.append(n)
	return out


## Every sprite of the worm is from stage s's set: head, feature, each body segment, the tail, the
## stripe, and the face on the next drawn frame.
func _assert_sprite_set(w: Worm, s: int) -> void:
	var p := w.player
	assert_object(w.head_sprite.texture).is_same(_look.segment_texture(p, s, &"head"))
	assert_object((w.look.get_node("Feature") as Sprite2D).texture).is_same(_look.feature_texture(s))
	var segs := _segments(w)
	assert_int(segs.size()).is_greater(0)
	for i in segs.size():
		var seg := segs[i]
		var kind: StringName = &"tail" if seg == w._seg_nodes.back() else &"body"
		assert_int(seg.stage).is_equal(s)
		assert_str(String(seg.kind)).is_equal(String(kind))
		assert_object(seg.base.texture).is_same(_look.segment_texture(p, s, kind))
		assert_object(seg.band.texture).is_same(_look.segment_texture(p, s, &"band"))
	await get_tree().process_frame
	assert_bool(String(_look.made.find_key(w.face.texture)).begins_with("face_%d_%d_" % [p, s])).is_true()


## Grow one stage inside the disk scene and check the three halves of S-15.
func _check_stage(s: int) -> void:
	var table := StageTable.default_table()
	_open()
	var radius_px: int = _level.world.shape.radius
	var w := _level.spawn_worm(Players.P1)
	await get_tree().physics_frame
	await get_tree().process_frame   # the chunks round the worm stream in their tile layers
	var tiles_before := _tile_sizes()
	assert_int(int(tiles_before[0])).is_equal(TILE_PX)
	assert_int(tiles_before.size()).is_greater(1)   # the disk has tile layers to measure
	if s == 1:
		w.model.add_segment(&"")   # a body to look at: a hatchling has none
	else:
		_grow_to(w, s - 1)
		assert_float(_radius(w)).is_equal(table.at(s - 1).collision_radius)
		await _assert_sprite_set(w, s - 1)
		_grow_to(w, s)
	assert_int(w.model.stage).is_equal(s)
	# collision size: the stage row's, and a different one from the stage below
	assert_float(_radius(w)).is_equal(table.at(s).collision_radius)
	assert_float(w.size_factor()).is_equal(table.at(s).size)
	if s > 1:
		assert_float(_radius(w)).is_greater(table.at(s - 1).collision_radius)
	else:
		assert_float(_radius(w)).is_less(table.at(2).collision_radius)
	# sprite set: every sprite is the new stage's
	await _assert_sprite_set(w, s)
	# tile size: never changes, in the same scene, with the world still the same disk
	await get_tree().physics_frame
	assert_object(w.world).is_same(_level.world)
	assert_int(_level.world.stage_of(Players.P1)).is_equal(s)
	assert_array(_tile_sizes()).is_equal(tiles_before)
	for t in _tile_sizes().slice(1):
		assert_that(t).is_equal(Vector2i(TILE_PX, TILE_PX))
	assert_int(_level.world.shape.radius).is_equal(radius_px)


func test_stage_1_in_the_disk_scene_has_its_sprites_and_collision_and_16px_tiles() -> void:
	await _check_stage(1)


func test_stage_2_swaps_sprites_and_collision_in_the_disk_scene_tiles_stay_16px() -> void:
	await _check_stage(2)


func test_stage_3_swaps_sprites_and_collision_in_the_disk_scene_tiles_stay_16px() -> void:
	await _check_stage(3)


func test_stage_4_swaps_sprites_and_collision_in_the_disk_scene_tiles_stay_16px() -> void:
	await _check_stage(4)


func test_stage_5_swaps_sprites_and_collision_in_the_disk_scene_tiles_stay_16px() -> void:
	await _check_stage(5)


## Losing the tail segment hands the tail sprite to the new last one (the set has a tail piece).
func test_the_tail_sprite_moves_to_the_new_last_segment() -> void:
	_open()
	var w := _level.spawn_worm(Players.P1, null, 2)
	await get_tree().physics_frame
	var before := w._seg_nodes.size()   # head to tail (the body node holds them tail first)
	assert_int(before).is_greater(2)
	var old_tail := w._seg_nodes.back() as WormSegment
	assert_str(String(old_tail.kind)).is_equal("tail")
	w.model.lose_segment()
	assert_int(w._seg_nodes.size()).is_equal(before - 1)
	var new_tail := w._seg_nodes.back() as WormSegment
	assert_str(String(new_tail.kind)).is_equal("tail")
	assert_object(new_tail.base.texture).is_same(_look.segment_texture(w.player, 2, &"tail"))
	for i in w._seg_nodes.size() - 1:
		assert_str(String((w._seg_nodes[i] as WormSegment).kind)).is_equal("body")
