## S-18 (worm-space-book-1): each space planet type's one Star trait shows in the book and on the
## trait wall, not only in space. Eating a planet whole finds its Star on the book's traits page at
## once (in space no tackle log runs, so before this the Star stayed grey until the next home visit),
## the planets page and the traits page name the same Star, and the Star knows the planet it came
## from (StarTraits.planet_of), which the book's trait sketch and the wall tile draw beside it.
## One test per planet type. Contacts are resolved directly (resolve_contact).
class_name TestBookStars
extends GdUnitTestSuite

const SPACE := "res://scenes/levels/space_stage.tscn"
const BOOK := preload("res://scenes/ui/book.tscn")
const WORM := preload("res://scenes/players/worm.tscn")
const IDS := [&"ice", &"jungle", &"junk", &"candy", &"clockwork"]


func before() -> void:
	SuiteSandbox.enter("book_stars")


func after() -> void:
	for p in Audio._pool:
		p.stop()
	for i in 3:
		await get_tree().process_frame
	for p in Audio._pool:
		p.stream = null
	SuiteSandbox.leave()


func before_test() -> void:
	Save.wipe()
	get_tree().paused = false


func test_ice_star_in_the_book_and_on_the_wall() -> void:
	await _check(&"ice")


func test_jungle_star_in_the_book_and_on_the_wall() -> void:
	await _check(&"jungle")


func test_junk_star_in_the_book_and_on_the_wall() -> void:
	await _check(&"junk")


func test_candy_star_in_the_book_and_on_the_wall() -> void:
	await _check(&"candy")


func test_clockwork_star_in_the_book_and_on_the_wall() -> void:
	await _check(&"clockwork")


func test_a_star_on_a_saved_worm_is_found_in_the_book() -> void:
	var t := StarTraits.for_planet(&"junk")
	Save.set_value("worms", { "1": { "stage": 6, "earned": [String(t.id)], "active": [] } })
	assert_bool(BookCatalog.found_set()[&"traits"].has(t.id)).is_true()
	assert_array(BookCatalog.found_set()[&"planets"]).is_empty()   # the planet page is its own find
	# Plain traits on a saved worm still come only through the tackle log.
	Save.set_value("worms", { "0": { "stage": 6, "earned": ["magnet"], "active": [] } })
	assert_bool(BookCatalog.found_set()[&"traits"].has(&"magnet")).is_false()


func test_plain_traits_have_no_planet() -> void:
	for e in BookCatalog.entries(&"traits"):
		var t: TraitData = e.data
		if t.star:
			assert_object(StarTraits.planet_of(t)).override_failure_message("%s has no planet" % t.id).is_not_null()
		else:
			assert_object(StarTraits.planet_of(t)).is_null()


func _seed_first(id: StringName) -> int:
	var life: SpaceLife = load(SpaceDrift.LIFE_PATH)
	for s in 500:
		if SpaceDrift.shuffled(life.planets, s)[0].id == id:
			return s
	return -1


func _check(id: StringName) -> void:
	var d: PlanetData = load("res://data/planets/%s.tres" % id)
	var star: TraitData = StarTraits.for_planet(id)
	assert_object(star).override_failure_message("%s has no Star" % id).is_not_null()
	assert_object(d.star_trait).is_not_null()
	assert_str(String(d.star_trait.id)).is_equal(String(star.id))

	# Its Star has a page on the book's traits page, from data/traits/, and knows its planet.
	var pages: Array = BookCatalog.entries(&"traits").filter(func(e): return e.id == star.id)
	assert_int(pages.size()).override_failure_message("%s Star has %d trait pages" % [id, pages.size()]).is_equal(1)
	assert_bool((pages[0].data as TraitData).star).is_true()
	var from := StarTraits.planet_of(pages[0].data)
	assert_object(from).is_not_null()
	assert_str(String(from.id)).is_equal(String(id))
	assert_object(from.color).is_equal(d.color)
	assert_bool(BookCatalog.found_set()[&"traits"].has(star.id)).is_false()   # grey until earned

	# Eat it whole in space: the Star is found in the book right away (no tackle log in space).
	Save.set_value("seed", _seed_first(id))
	var s: SpaceStage = load(SPACE).instantiate()
	s.players.append(Players.P1)
	add_child(s)
	auto_free(s)
	s.set_process(false)
	s.drift.set_process(false)
	var big := s.drift.big
	assert_object(big.data).is_same(d)
	big.ripen(big.data.ripe_stage)
	assert_int(s.resolve_contact(s.worms[0], big)).is_equal(StageRule.FOOD)
	assert_object(BookCatalog.live_log(get_tree())).is_null()
	var found: Dictionary = BookCatalog.found_set(get_tree())
	assert_bool(found[&"traits"].has(star.id)).override_failure_message("%s Star not found in the book" % id).is_true()
	assert_bool(found[&"planets"].has(id)).is_true()
	for other in IDS:
		if other != id:
			assert_bool(found[&"traits"].has(StarTraits.for_planet(other).id)).is_false()

	# And from the tin: the open book shows it found on both pages.
	Save.flush()
	Save._load()
	var b: Book = BOOK.instantiate()
	add_child(b)
	auto_free(b)
	b.pause_tree = false
	b.open(Players.P1)
	assert_bool(b.is_found(&"traits", star.id)).is_true()
	assert_bool(b.is_found(&"planets", id)).is_true()
	b.close()

	# The trait wall: earned on a planet worm, its tile is a Star with that planet beside it.
	var w: Worm = WORM.instantiate()
	w.player = Players.P1
	w.model = WormGrowth.new()
	w.model.start_at_stage(6)
	w.autopilot = func(_w: Worm) -> Dictionary: return {}
	add_child(w)
	auto_free(w)
	assert_bool(StarTraits.record(Players.P1, star.id)).is_true()
	assert_bool(star.id in w.model.earned).is_true()
	var wall := TraitWall.new()
	wall.worm = w
	add_child(wall)
	auto_free(wall)
	wall.set_open(true)
	await get_tree().process_frame     # one draw of the wall with the Star tile
	var t: TraitData = w.model.rules.find_trait(star.id)
	assert_bool(t.star).is_true()
	assert_str(String(StarTraits.planet_of(t).id)).is_equal(String(id))
	wall.set_open(false)
