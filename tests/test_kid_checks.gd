## Kid checks K-01, K-05, K-08 (GAME.md "Kid-design checks specific to this game"), proved from the
## data and the real code, with no copies of the numbers:
##   K-01 bigger-than-me reads at a glance: for every creature in data/creatures/ and every worm
##        stage, the size the kid sees (the creature's drawn radius against the worm's drawn head)
##        says "bigger" exactly when the rule (CreatureData.is_threat_to / Worm.can_eat) says threat.
##   K-05 the smaller worm catches up within a minute: two real worms share growth through
##        Worm.bite_tile / Worm.feed at the kid profile of data/BALANCE.md for 60 s of play.
##   K-08 nothing in the dirt is dark: every ring's ambient setting (Lantern.AMBIENT) and the
##        ground darkening (shaders/lantern_tiles.gdshader as the tiles use it) stay above the floor.
## A red test here is a real gap; handoff/REPORT.md of feature/worm-kid-checks-1 names the fix.
extends GdUnitTestSuite

const WORM := preload("res://scenes/players/worm.tscn")
const RINGS := preload("res://data/rings/rings.tres")
const CREATURES_DIR := "res://data/creatures/"
const SCENES_DIR := "res://scenes/creatures/"
const BALANCE := "res://data/BALANCE.md"
const TILE_SHADER := "res://shaders/lantern_tiles.gdshader"

## "Bigger" at a glance: a threat is drawn at least this many times the worm's head (the creatures
## lane's rule, PLAN-STATUS K-01). "Smaller": food, even at its biggest calm pose, is no bigger than
## the head.
const BIGGER := 1.25
## The kid profile of data/BALANCE.md ("Profiles"): share of seconds tunnelling new ground, foods met
## a minute. Kept in sync with tests/test_balance_stages.gd KID.
const KID_DIG := 0.35
const KID_FOODS_MIN := 0.6
const CATCH_UP_S := 60.0

var _spawned: Array[Node] = []


func before() -> void:
	SuiteSandbox.enter("kid_checks")


func after() -> void:
	for p in Audio._pool:
		p.stop()
	SuiteSandbox.leave()


func _worm(player: int, stage := 1) -> Worm:
	var w: Worm = WORM.instantiate()
	w.player = player
	var m := WormGrowth.new()
	if stage > 1:
		m.start_at_stage(stage)
	w.model = m
	w.set_meta("start_pos", Vector2(player * 400.0, 0.0))
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	w.set_physics_process(false)
	w.set_process(false)
	_spawned.append(w)
	return w


func after_test() -> void:
	for w in _spawned:
		if is_instance_valid(w):
			w.free()
	_spawned.clear()


## Every creature the data defines (a Jarling is never food nor threat, so it has no size relation).
static func creatures() -> Array[CreatureData]:
	var out: Array[CreatureData] = []
	for f in DirAccess.get_files_at(CREATURES_DIR):
		if f.ends_with(".tres"):
			var d := load(CREATURES_DIR + f) as CreatureData
			if d != null and not d.jarling:
				out.append(d)
	return out


## The worm head's radius on screen, px: the opaque part of the head sprite, times its scale and the
## stage's body size (Worm._apply_size), measured on a real worm of that stage.
func _head_px(stage: int) -> float:
	var w := _worm(Players.P1, stage)
	var spr := w.head_sprite
	var img := spr.texture.get_image()
	if img.is_compressed():
		img.decompress()
	var used := img.get_used_rect().size
	var r := maxf(used.x, used.y) * 0.5 * spr.scale.x * w.look.scale.x
	w.free()
	return r


## The creature's biggest drawn circle, px, the same thing _head_px measures on the worm: how each
## look script sizes its main shape from data.radius. As food it is measured in its smallest calm
## pose (cowering, Creature.draw_scale 0.85, where the script uses it), as a threat at rest (no
## wind-up swell): the kindest reading for the code either way.
##   creature.gd (grub, ant, beetle; and creatures with no scene yet): a body of radius r
##   bird.gd: a body of radius r, cowering 0.85x when the nearest worm can eat it (wings out to
##            1.6 r are extra, flapping, not counted)
##   centipede.gd: the head, 0.75 r (body segments are 0.62 r)
##   boot_shadow.gd: the sole, 1.3 r long, drawn at 0.7x to 1.0x as it comes down (0.7x counted as
##            a threat); once outgrown, BootShadow.OUTGROWN x that, counted at its biggest (1.0x)
static func _body_px(d: CreatureData, as_food: bool) -> float:
	var path := SCENES_DIR + String(d.id) + ".tscn"
	var script := ""
	if ResourceLoader.exists(path):
		var st := (load(path) as PackedScene).get_state()
		for i in st.get_node_property_count(0):
			if st.get_node_property_name(0, i) == &"script":
				script = (st.get_node_property_value(0, i) as Script).resource_path.get_file()
	var cower := 0.85 if as_food else 1.0
	match script:
		"bird.gd":
			return d.radius * cower
		"centipede.gd":
			return d.radius * 0.75 * cower
		"boot_shadow.gd":
			# as food (outgrown) measured at full strength (1.0x), the biggest it gets
			return d.radius * 1.3 * (BootShadow.OUTGROWN if as_food else 0.7)
	return d.radius * cower


# --- K-01 -----------------------------------------------------------------------------------------

func test_k01_bigger_than_me_reads_from_size_alone_for_every_creature_and_stage() -> void:
	var rules := WormRules.default_rules()
	var all := creatures()
	assert_int(all.size()).is_greater_equal(1)
	var heads := {}
	for s in range(1, rules.max_stage() + 1):
		heads[s] = _head_px(s)
	var bad: Array[String] = []
	var lines: Array[String] = []
	for d in all:
		var met := ResourceLoader.exists(SCENES_DIR + String(d.id) + ".tscn")
		var row := "k01 %-11s r %4.1f%s:" % [d.id, d.radius, "" if met else " (no scene yet)"]
		for s in range(1, rules.max_stage() + 1):
			var head: float = heads[s]
			var edible := d.size_stage <= rules.stage_info(s).edible_size
			var threat := d.is_threat_to(s)
			assert_bool(edible == not threat).override_failure_message(
				"%s at worm stage %d: edible %s but threat %s" % [d.id, s, edible, threat]).is_true()
			var shown := _body_px(d, not threat)
			var ok := shown >= head * BIGGER if threat else shown <= head
			row += " s%d %s%.2f" % [s, "T" if threat else "F", shown / head]
			if not ok:
				row += "!"
				bad.append("%s at worm stage %d: %s but drawn %.1f px against a %.1f px head (%.2fx; needs %s)" % [
					d.id, s, "a threat" if threat else "food", shown, head, shown / head,
					">= %.2fx" % BIGGER if threat else "<= 1.00x"])
		lines.append(row)
	for l in lines:
		print(l)
	assert_array(bad).override_failure_message(
		"K-01: the size on screen says the wrong thing (bigger must mean threat, food must look smaller):\n  "
		+ "\n  ".join(bad)).is_empty()


# --- K-05 -----------------------------------------------------------------------------------------

## Tiles a second while tunnelling new ground (data/BALANCE.md "Profiles"; the same formula as
## tests/test_balance_stages.gd tiles_per_s), from the worm's own stats and size.
static func _tiles_per_s(w: Worm) -> float:
	var speed := w.model.stats.value("speed", 80.0) * w.model.stats.value("dig_speed", Worm.DIG_SPEED)
	return speed * 2.0 * Worm.BITE_RADIUS * w.size_factor() / 256.0


## Plays both worms for `seconds` at the kid profile in fixed 0.1 s steps: whole tiles go through
## Worm.bite_tile (which gives the partner its share), foods through Worm.feed. `eats` says which
## worms eat at all. Returns the segment-added events seen per worm (counted through the signal).
func _play(worms: Array[Worm], eats: Array[bool], seconds: float, food: FoodData) -> Array[int]:
	var added: Array[int] = []
	var tiles: Array[float] = []
	var foods: Array[float] = []
	for i in worms.size():
		added.append(0)
		tiles.append(0.0)
		foods.append(0.0)
		var k := i
		worms[i].segment_added.connect(func(_p: int, _f: StringName) -> void: added[k] += 1)
	var dt := 0.1
	for step in int(round(seconds / dt)):
		for i in worms.size():
			if not eats[i]:
				continue
			tiles[i] += _tiles_per_s(worms[i]) * KID_DIG * dt
			while tiles[i] >= 1.0:
				tiles[i] -= 1.0
				worms[i].bite_tile(&"")
			foods[i] += KID_FOODS_MIN / 60.0 * dt
			while foods[i] >= 1.0:
				foods[i] -= 1.0
				worms[i].feed(food)
	return added


func test_k05_the_smaller_worm_catches_up_within_a_minute_through_shared_growth() -> void:
	var rules := WormRules.default_rules()
	var doc := FileAccess.get_file_as_string(BALANCE)
	assert_bool(doc.contains("| partner share | %s |" % str(rules.partner_share))) \
		.override_failure_message("data/BALANCE.md lacks the partner share row").is_true()
	var food: FoodData = load("res://data/foods/seed.tres")
	# The usual gap: a drop-in hatchling at its partner's stage minus one (PlanetLevel.drop_in).
	var big_stage := 3
	var big := _worm(Players.P1, big_stage)
	var small := _worm(Players.P2, big_stage - 1)
	assert_int(Worm.all().size()).is_equal(2)
	var gap0 := big.model.segments.size() - small.model.segments.size()
	assert_int(gap0).is_greater(0)
	# The share itself is wired: one tile by the big worm gives the small one a quarter of it.
	var g0 := small.model.growth
	big.bite_tile(&"")
	assert_float(small.model.growth - g0).is_equal_approx(Worm.TILE_GROWTH * rules.partner_share, 0.0001)
	# Both play like a kid for a minute.
	var added := _play([big, small] as Array[Worm], [true, true] as Array[bool], CATCH_UP_S, food)
	assert_int(added[0] + added[1]).override_failure_message("nobody grew: the simulation fed nothing").is_greater(0)
	var gap := big.model.segments.size() - small.model.segments.size()
	print("k05 both eat: start gap %d segments, after %ds gap %d (big +%d, small +%d segments)" % [
		gap0, int(CATCH_UP_S), gap, added[0], added[1]])
	# The kindest case for catching up: only the smaller worm eats, the bigger one waits.
	var big2 := _worm(Players.P1, big_stage)
	var small2 := _worm(Players.P2, big_stage - 1)
	big.free()
	small.free()
	var gap2_0 := big2.model.segments.size() - small2.model.segments.size()
	var added2 := _play([big2, small2] as Array[Worm], [false, true] as Array[bool], CATCH_UP_S, food)
	var gap2 := big2.model.segments.size() - small2.model.segments.size()
	print("k05 only small eats: start gap %d, after %ds gap %d (big +%d, small +%d)" % [
		gap2_0, int(CATCH_UP_S), gap2, added2[0], added2[1]])
	assert_int(gap).override_failure_message(
		("K-05: the smaller worm does not catch up. A stage-%d hatchling %d segments behind its partner is "
		+ "still %d behind after %d s of kid-pace play by both (and %d behind even if only it eats). "
		+ "Shared growth is symmetric (each worm gets %.2f of the other's bites), so a gap never closes; "
		+ "the smaller worm needs a bigger share than the bigger one.") % [
			big_stage - 1, gap0, gap, int(CATCH_UP_S), gap2, rules.partner_share]).is_less_equal(0)


# --- K-08 -----------------------------------------------------------------------------------------

func test_k08_no_dirt_ring_ambient_setting_is_below_the_floor() -> void:
	# The agreed floor (PLAN-STATUS K-08: "never under 0.6").
	assert_float(Lantern.AMBIENT_FLOOR).is_greater_equal(0.6)
	var low: Array[String] = []
	for r: RingDef in RINGS.rings:
		# The setting itself, not rescued by the clamp in Lantern.ambient_at.
		assert_bool(Lantern.AMBIENT.has(r.id)).override_failure_message(
			"ring %s has no ambient of its own (falls back to the sky's)" % r.id).is_true()
		var c: Color = Lantern.AMBIENT.get(r.id, Lantern.AMBIENT_SKY)
		var m := minf(c.r, minf(c.g, c.b))
		print("k08 ambient %-9s %s min channel %.2f" % [r.id, c.to_html(false), m])
		if m < Lantern.AMBIENT_FLOOR:
			low.append("%s %s (%.2f)" % [r.id, c.to_html(false), m])
	assert_array(low).override_failure_message("K-08: ring ambients under the %.2f floor: %s" % [
		Lantern.AMBIENT_FLOOR, ", ".join(low)]).is_empty()


func test_k08_the_ambient_in_play_is_above_the_floor_in_the_middle_of_every_ring() -> void:
	var level := Node2D.new()
	var lantern := Lantern.new()
	level.add_child(lantern)
	add_child(level)
	auto_free(level)
	var w := PolarWorld.new()
	w.setup_planet(RINGS, 160, 7)
	level.add_child(w)
	w.set_physics_process(false)
	var px := 160.0 * w.shape.cell_size
	var inner := 0.0
	for r: RingDef in RINGS.rings:
		var c := lantern.ambient_at(Vector2(0, -px * (inner + r.outer) * 0.5))
		inner = r.outer
		assert_float(minf(c.r, minf(c.g, c.b))).override_failure_message(
			"K-08: ambient in %s is %s" % [r.id, c.to_html(false)]).is_greater_equal(Lantern.AMBIENT_FLOOR)


## The deepest ground keeps at least 1 - max_dark of its colour in every channel (the shader's own
## promise, "Never black"), with the uniforms as the tiles' material really has them.
func test_k08_ground_darkening_never_goes_past_its_cap() -> void:
	var sh: Shader = load(TILE_SHADER)
	assert_object(sh).is_not_null()
	var max_dark := _uniform(sh, "max_dark").to_float()
	var tv := _uniform(sh, "deep_tint").trim_prefix("vec3(").trim_suffix(")").split(",")
	assert_int(tv.size()).is_equal(3)
	var t := Vector3(tv[0].to_float(), tv[1].to_float(), tv[2].to_float())
	# fragment(): mix(c, c * deep_tint, (smoothstep(...) * max_dark) / max_dark * max_dark * 2.0); at
	# full depth smoothstep is 1, so the mix weight is 2 * max_dark.
	var weight := max_dark * 2.0
	var keep := Vector3.ONE.lerp(t, weight)
	var floor_keep := 1.0 - max_dark
	var dim := Lantern.AMBIENT_FLOOR * minf(keep.x, minf(keep.y, keep.z))
	print("k08 darkening: max_dark %.2f deep_tint %s -> deepest ground keeps %.2f %.2f %.2f (floor %.2f); x dimmest ambient %.2f" % [
		max_dark, t, keep.x, keep.y, keep.z, floor_keep, dim])
	assert_float(weight).override_failure_message("K-08: darkening overshoots the tint").is_less_equal(1.0)
	for k in 3:
		assert_float(keep[k]).override_failure_message("K-08: deepest ground keeps only %.2f" % keep[k]) \
			.is_greater_equal(floor_keep)
	# Nothing in the code overrides those two uniforms (the tiles keep the shader's values).
	for f in ["res://scripts/lighting/lantern_tile_art.gd", "res://scripts/lighting/lantern.gd"]:
		var code := FileAccess.get_file_as_string(f)
		assert_bool(code.contains("\"max_dark\"") or code.contains("\"deep_tint\"")) \
			.override_failure_message("%s overrides the darkening uniforms: test them where they are set" % f).is_false()


## The default value of `uniform <type> name = value;` in the shader source.
static func _uniform(sh: Shader, name: String) -> String:
	var re := RegEx.create_from_string("uniform\\s+\\w+\\s+" + name + "\\s*(?::[^=]*)?=\\s*([^;]+);")
	var m := re.search(sh.code)
	return m.get_string(1).strip_edges() if m else ""
