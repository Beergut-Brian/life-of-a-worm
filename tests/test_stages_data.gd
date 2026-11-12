## Stages as data (S-14, S-15): thresholds, zoom, size, edible class, feature and slots come from
## data/stages.tres; a stage-up needs enough segments AND the apex; growth swaps the sprite set
## and the collision size, never the tile size.
class_name TestStagesData
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")


func after() -> void:
	for p in Audio._pool:
		p.stop()   # placeholder beeps still playing at exit leak their playbacks


func _table(segs: Array, apex: Array) -> StageTable:
	var t := StageTable.new()
	for i in segs.size():
		var d := StageData.new()
		d.stage = i + 1
		d.segments = segs[i]
		d.needs_apex = apex[i]
		d.slots = maxi(0, i)
		d.size = 1.0 + 0.5 * i
		d.collision_radius = 6.0 + 2.0 * i
		d.edible_size = i + 1
		t.stages.append(d)
	return t


func _rules(table: StageTable) -> WormRules:
	var r: WormRules = WormRules.default_rules().duplicate()
	r.stages = table
	return r


func _grow_to(m: WormGrowth, n: int) -> void:
	while m.segments.size() < n:
		m.add_segment(&"")


func test_rules_thresholds_and_slots_are_the_stage_table() -> void:
	var rules := WormRules.default_rules()
	var table := StageTable.default_table()
	assert_object(rules.stages).is_same(table)
	assert_int(table.max_stage()).is_equal(7)
	assert_int(rules.max_stage()).is_equal(7)
	for s in range(1, 8):
		var d := table.at(s)
		assert_int(d.stage).is_equal(s)
		assert_int(rules.stage_segments[s]).is_equal(d.segments)
		assert_int(rules.slots_for(s)).is_equal(d.slots)
	assert_str(table.at(1).name_hint).is_equal("Grub")


func test_changing_only_the_data_changes_the_pacing() -> void:
	var m := WormGrowth.new(_rules(_table([0, 4, 5], [false, false, false])))
	assert_int(m.stage).is_equal(1)   # 3 start segments
	m.add_segment(&"")
	assert_int(m.stage).is_equal(2)
	m.add_segment(&"")
	assert_int(m.stage).is_equal(3)
	assert_int(m.rules.max_stage()).is_equal(3)


func test_stage_up_needs_segments_and_the_apex() -> void:
	var m := WormGrowth.new()
	m.apex_gate = true
	_grow_to(m, m.rules.stage_segments[2] + 3)
	assert_int(m.stage).is_equal(1)            # long enough, apex not eaten
	var m2 := WormGrowth.new()
	m2.apex_gate = true
	assert_bool(m2.eat_apex(1)).is_false()     # apex eaten, too short
	assert_int(m2.stage).is_equal(1)
	_grow_to(m2, m2.rules.stage_segments[2])
	assert_int(m2.stage).is_equal(2)           # both: up
	assert_str(String(m2.last_cause)).is_equal("segments")
	assert_bool(m.eat_apex(1)).is_true()
	assert_str(String(m.last_cause)).is_equal("apex")


func test_a_stage_whose_data_waives_the_apex_needs_segments_only() -> void:
	var m := WormGrowth.new(_rules(_table([0, 4, 6], [false, false, true])))
	m.apex_gate = true
	_grow_to(m, 4)
	assert_int(m.stage).is_equal(2)            # stage 2 waives the apex in this table
	_grow_to(m, 8)
	assert_int(m.stage).is_equal(2)            # stage 3 does not
	m.eat_apex(2)
	assert_int(m.stage).is_equal(3)


func test_every_stage_row_is_filled_and_ordered() -> void:
	var table := StageTable.default_table()
	var prev: StageData = null
	for s in range(1, 8):
		var d := table.at(s)
		assert_bool(d.zoom_index >= 0 and d.zoom_index < PolarCamera.ZOOMS.size()).is_true()
		assert_float(d.collision_radius).is_greater(0.0)
		assert_int(d.edible_size).is_greater_equal(s)
		if s >= 2:
			assert_str(String(d.feature_id)).is_not_empty()
			assert_bool(d.needs_apex).is_true()
		assert_bool(d.in_disk).is_equal(s <= 5)
		if prev != null:
			assert_int(d.segments).is_greater(prev.segments)
			assert_int(d.zoom_index).is_less_equal(prev.zoom_index)   # never zooms back in
			assert_float(d.size).is_greater(prev.size)
			assert_float(d.collision_radius).is_greater(prev.collision_radius)
		prev = d
	assert_int(table.at(2).slots).is_equal(1)
	assert_int(table.at(6).slots).is_equal(5)
	assert_str(String(table.at(2).opens_ring)).is_equal("topsoil")


func test_growth_swaps_sprites_and_collision_but_never_the_tile_size() -> void:
	var w: Worm = WORM.instantiate()
	w.player = Players.P1
	add_child(w)
	auto_free(w)
	var shape := (w.get_node("Head/Shape") as CollisionShape2D).shape as CircleShape2D
	assert_float(shape.radius).is_equal(StageTable.default_table().at(1).collision_radius)
	w.model.start_at_stage(2)
	var d := StageTable.default_table().at(2)
	shape = (w.get_node("Head/Shape") as CollisionShape2D).shape as CircleShape2D
	assert_float(shape.radius).is_equal(d.collision_radius)
	assert_float(w.size_factor()).is_equal(d.size)
	assert_int(w.stage).is_equal(2)
	for n in w.body.get_children():
		if n is WormSegment:
			assert_int((n as WormSegment).stage).is_equal(2)
	var feat := w.look.get_node("Feature") as Sprite2D
	assert_object(feat.texture).is_same(WormHooks.look().feature_texture(2))
	# Tiles are 16 px at every stage: the planet's shape never changes with the worm.
	assert_int(DiskShape.new(300, 32).cell_size).is_equal(16)


func test_edible_size_class_comes_from_the_stage_row() -> void:
	var w: Worm = WORM.instantiate()
	add_child(w)
	auto_free(w)
	var food := FoodData.new()
	food.size_stage = 2
	assert_bool(w.can_eat(food)).is_false()
	w.model.start_at_stage(2)
	assert_bool(w.can_eat(food)).is_true()
	food.size_stage = StageTable.default_table().at(2).edible_size + 1
	assert_bool(w.can_eat(food)).is_false()
