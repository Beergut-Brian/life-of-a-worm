## S-18 "one page per planet" (worm-gap-close-15): the collection book has a planets section with one
## sketch per PlanetData type, a type is found only once its whole planet is eaten in space (read from
## the tin's "space" -> "done", which SpaceDrift already saves), and eating it pops a little book page
## with that planet's sketch over the worms, with the book's page cue. Contacts are resolved directly
## (resolve_contact), never through a pile of bodies; pops are counted through child_entered_tree.
class_name TestBookPlanets
extends GdUnitTestSuite

const SPACE := "res://scenes/levels/space_stage.tscn"
const BOOK := preload("res://scenes/ui/book.tscn")
const PLANETS := [&"candy", &"clockwork", &"ice", &"jungle", &"junk"]

var _pops: Array[StringName] = []


func before() -> void:
	SuiteSandbox.enter("book_planets")


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
	_pops.clear()
	get_tree().paused = false


func _stage() -> SpaceStage:
	var s: SpaceStage = load(SPACE).instantiate()
	s.players.append(Players.P1)
	add_child(s)
	s.set_process(false)          # no stick
	s.drift.set_process(false)    # no spawning or drifting off
	s.child_entered_tree.connect(func(n: Node) -> void:
		if n is PlanetPagePop:
			_pops.append((n as PlanetPagePop).data.id))
	return auto_free(s)


func _eat_planet(s: SpaceStage) -> StringName:
	var big := s.drift.big
	var id := big.data.id
	big.ripen(big.data.ripe_stage)
	assert_int(s.resolve_contact(s.worms[0], big)).is_equal(StageRule.FOOD)
	return id


func test_one_planets_page_entry_per_planet_type() -> void:
	assert_bool(BookCatalog.SECTIONS.has(&"planets")).is_true()
	var ids: Array = BookCatalog.entries(&"planets").map(func(e): return e.id)
	assert_array(ids).is_equal(PLANETS)
	for e in BookCatalog.entries(&"planets"):
		assert_bool(e.data is PlanetData).is_true()
	# The book scene has a page for it.
	var b: Book = BOOK.instantiate()
	add_child(b)
	auto_free(b)
	var sections: Array = b.find_children("*", "", true, false) \
		.filter(func(n): return n is BookPage).map(func(n): return n.section)
	assert_bool(sections.has(&"planets")).is_true()


func test_a_planet_is_found_only_once_it_is_eaten_whole() -> void:
	assert_array(BookCatalog.found_set()[&"planets"]).is_empty()
	# Half a meal is not the planet.
	var s := _stage()
	var big := s.drift.big
	assert_object(big).is_not_null()
	assert_array(BookCatalog.found_set()[&"planets"]).is_empty()
	var id := _eat_planet(s)
	var found: Array = BookCatalog.found_set()[&"planets"]
	assert_array(found).is_equal([id])
	# It comes back from the tin, and the book shows it found and the others still grey.
	Save.flush()
	Save._load()
	var b: Book = BOOK.instantiate()
	add_child(b)
	auto_free(b)
	b.pause_tree = false
	b.open(Players.P1)
	assert_bool(b.is_found(&"planets", id)).is_true()
	for other in PLANETS:
		if other != id:
			assert_bool(b.is_found(&"planets", other)).is_false()
	b.close()


func test_eating_a_planet_whole_pops_its_page_with_the_page_cue() -> void:
	var s := _stage()
	var before := int(Audio.played.get("page_new", 0))
	var id := _eat_planet(s)
	assert_array(_pops).is_equal([id])
	assert_int(int(Audio.played.get("page_new", 0)) - before).is_equal(1)
	# The pop floats over the worms, then goes by itself.
	var pops: Array = s.get_children().filter(func(n): return n is PlanetPagePop)
	assert_int(pops.size()).is_equal(1)
	var pop: PlanetPagePop = pops[0]
	assert_float(pop.position.y).is_less(s.worms_centre().y)
	pop._process(PlanetPagePop.LIFE + 0.1)
	await get_tree().process_frame
	assert_bool(is_instance_valid(pop)).is_false()


func test_an_unknown_planet_id_pops_nothing() -> void:
	var s := _stage()
	assert_object(PlanetPagePop.pop(s, &"not_a_planet")).is_null()
	assert_array(_pops).is_empty()
