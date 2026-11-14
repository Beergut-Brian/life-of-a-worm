## What Old Reel's tackle box knows: one page per kind (foods, creatures, traits, secrets, cutscenes),
## one sketch per entry, unlocked by signals as things happen. A page whose every entry is unlocked
## is complete: it emits page_completed once and pins a lure to the lid. Saved in the tin ("tackle").
##
## Sources (all duck-typed, nothing here owns them):
##  - foods: Worm.ate(player, what, growth) for every FoodData in data/foods/;
##  - creatures: every entry of the book's creatures section (BookCatalog: data/creatures, pets,
##    apexes, jarlings). Met when a node in group &"creature" with a `creature_id` (property or meta),
##    a ring creature (group &"creatures", its `data.id`) or a ring apex (ApexBeetle, its `id`) comes
##    within MEET_PX of a worm, or an apex is eaten; meet(id) for scripted meetings (the Mole pops out);
##  - traits: Worm.trait_earned (and the worm's earned list on spawn), every TraitData in data/traits/;
##  - secrets: any node with a `secret_found(id)` signal, connected as it enters the tree; secrets
##    listed in data/secrets/*.tres (id property), unknown ids are added to the page;
##  - cutscenes: the Story node's seen list and its cutscene_finished signal (Story.SCENES);
##  - things (T-05): every surface thing in data/props/ (PropData). Unlocked when a worm breaks one
##    (SurfaceProp.broke, connected as the prop enters the tree); a tin whose props were broken
##    before this page existed gets them on load, silently (the tin's "destruct" state).
class_name TackleLog
extends Node

signal unlocked(page: StringName, id: StringName)
signal page_completed(id: StringName)

const PAGES: Array[StringName] = [&"foods", &"creatures", &"traits", &"secrets", &"cutscenes", &"things"]
const MEET_PX := 120.0
## Creatures the slice knows about before data/creatures/ exists (the other lane adds files there).
const KNOWN_CREATURES: Array[StringName] = [&"beetle", &"ladybird", &"mole"]
const KNOWN_SECRETS: Array[StringName] = [&"ant_city"]
const SAVE_KEY := "tackle"

## page -> Array[StringName] of every entry on it (in order).
var entries := {}
## page -> Array[StringName] unlocked.
var found := {}
## Completed pages, in the order their lures were pinned.
var lures: Array[StringName] = []
## Unlocked since the box was last opened (the Y hint glows).
var fresh := 0
var _meet_t := 0.0


func _init() -> void:
	name = "TackleLog"
	entries[&"foods"] = _ids_in("res://data/foods/", "FoodData")
	var creatures: Array[StringName] = KNOWN_CREATURES.duplicate()
	for e in BookCatalog.entries(&"creatures"):   # the same list the book draws, so every sketch can be found
		if not creatures.has(e.id):
			creatures.append(e.id)
	entries[&"creatures"] = creatures
	entries[&"traits"] = _ids_in("res://data/traits/", "TraitData")
	var secrets: Array[StringName] = _ids_in("res://data/secrets/", "")
	if secrets.is_empty():
		secrets = KNOWN_SECRETS.duplicate()
	entries[&"secrets"] = secrets
	var scenes: Array[StringName] = []
	scenes.assign(Story.SCENES)
	entries[&"cutscenes"] = scenes
	entries[&"things"] = _ids_in("res://data/props/", "PropData")
	for p in PAGES:
		found[p] = [] as Array[StringName]


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	for n in get_tree().get_nodes_in_group(&"secrets"):
		_on_node_added(n)
	for n in get_tree().get_nodes_in_group(&"creature") + get_tree().get_nodes_in_group(&"creatures"):
		if n is ApexBeetle:   # the level makes its apexes before the home slice makes this log
			_on_node_added(n)
	for n in get_tree().get_nodes_in_group(SurfaceProp.GROUP):   # stood before this log was made
		_on_node_added(n)
	_watch_story()


## Every resource in dir with an `id` (of script class `cls` if given), sorted by id.
static func _ids_in(dir: String, cls: String) -> Array[StringName]:
	var out: Array[StringName] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in ResourceLoader.list_directory(dir):
		if not f.ends_with(".tres"):
			continue
		var r := load(dir + f)
		if r == null or not (&"id" in r):
			continue
		if cls != "" and not _is_class(r.get_script(), cls):
			continue
		if not out.has(r.id):
			out.append(r.id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


# --- unlocking ----------------------------------------------------------------------------------

## Unlocks entry `id` on `page`. Unknown ids on the secrets page are added to it. True if new.
func unlock(page: StringName, id: StringName) -> bool:
	if not entries.has(page):
		return false
	var list: Array = entries[page]
	if not list.has(id):
		if page != &"secrets":
			return false
		list.append(id)
	var have: Array = found[page]
	if have.has(id):
		return false
	have.append(id)
	fresh += 1
	Audio.play("page_new")
	unlocked.emit(page, id)
	_check_page(page)
	return true


func is_found(page: StringName, id: StringName) -> bool:
	return found.has(page) and (found[page] as Array).has(id)


func is_complete(page: StringName) -> bool:
	var list: Array = entries.get(page, [])
	if list.is_empty():
		return false
	for id in list:
		if not is_found(page, id):
			return false
	return true


func _check_page(page: StringName) -> void:
	if is_complete(page) and not lures.has(page):
		lures.append(page)
		Audio.play("lure_pin")
		page_completed.emit(page)


func meet(id: StringName) -> bool:
	return unlock(&"creatures", id)


func note_secret(id: StringName) -> void:
	unlock(&"secrets", id)


func note_cutscene(id: StringName) -> void:
	unlock(&"cutscenes", id)


## Hooks one worm's signals (food eaten, traits earned) and syncs what it already earned.
func watch_worm(w: Worm) -> void:
	if not w.ate.is_connected(_on_ate):
		w.ate.connect(_on_ate)
		w.trait_earned.connect(_on_trait)
	for id in w.model.earned:
		unlock(&"traits", id)


func _on_ate(_player: int, what: StringName, _growth: float) -> void:
	unlock(&"foods", what)
	if (entries[&"creatures"] as Array).has(what):
		unlock(&"creatures", what)


func _on_trait(_player: int, id: StringName) -> void:
	unlock(&"traits", id)


func _on_node_added(n: Node) -> void:
	if n is ApexBeetle:
		var a := n as ApexBeetle
		if not a.eaten.is_connected(_on_apex_eaten):
			a.eaten.connect(_on_apex_eaten.bind(a))
	if n is SurfaceProp and not (n as SurfaceProp).broke.is_connected(_on_prop_broke):
		(n as SurfaceProp).broke.connect(_on_prop_broke)
	if n.has_signal(&"secret_found") and not n.is_connected(&"secret_found", note_secret):
		n.connect(&"secret_found", note_secret)
	if n is Story:
		_watch_story.call_deferred()


func _on_apex_eaten(_player: int, a: ApexBeetle) -> void:
	meet(a.id)


## A worm broke a surface thing: its sketch is found (the first of its kind; later ones are quiet).
func _on_prop_broke(prop: SurfaceProp, _player: int, _chunks: Array) -> void:
	if prop.data:
		unlock(&"things", prop.data.id)


## Things already broken in this tin (WorldDestruct's saved state: "<id>_<n>" -> hits left), for a
## tin played before the things page existed. No sound, no fresh mark: nothing just happened.
func sync_broken(state: Dictionary) -> void:
	for key: String in state:
		if int(state[key]) > 0:
			continue
		var id := StringName(key.substr(0, key.rfind("_")))
		if (entries[&"things"] as Array).has(id) and not is_found(&"things", id):
			(found[&"things"] as Array).append(id)
	if is_complete(&"things") and not lures.has(&"things"):
		lures.append(&"things")


func _watch_story() -> void:
	var s := Story.find(get_tree())
	if s == null:
		return
	if not s.cutscene_finished.is_connected(note_cutscene):
		s.cutscene_finished.connect(note_cutscene)
	for id in s.seen:
		unlock(&"cutscenes", id)


## Cutscenes already seen in this tin (the Story node's list, else the tin's own `story_seen`).
func sync_seen() -> void:
	var s := Story.find(get_tree()) if is_inside_tree() else null
	var ids: Array = s.seen if s else Save.get_value(Story.SAVE_KEY, [])
	for id in ids:
		unlock(&"cutscenes", StringName(id))


func _physics_process(delta: float) -> void:
	_meet_t += delta
	if _meet_t < 0.25:
		return
	_meet_t = 0.0
	var worms := Worm.all()
	if worms.is_empty():
		return
	for c in get_tree().get_nodes_in_group(&"creature") + get_tree().get_nodes_in_group(&"creatures"):
		var id := creature_of(c)
		if id == &"" or is_found(&"creatures", id) or not (c is Node2D):
			continue
		if c is ApexBeetle and (c as ApexBeetle).is_gone():
			meet(id)   # eaten in an older visit of this tin (before its page existed): it was met then
			continue
		if not c.is_visible_in_tree():
			continue
		for w in worms:
			if (c as Node2D).global_position.distance_to(w.head.global_position) <= MEET_PX:
				meet(id)
				break


static func creature_of(n: Node) -> StringName:
	# An apex is its own page (data/apexes/), even where the slice tags it "beetle" (HomeSlice).
	if n is ApexBeetle:
		return (n as ApexBeetle).id
	if n.has_meta(&"creature_id"):
		return StringName(n.get_meta(&"creature_id"))
	if &"creature_id" in n:
		return StringName(n.get(&"creature_id"))
	var d = n.get(&"data") if &"data" in n else null
	if d is CreatureData:
		return (d as CreatureData).id
	return &""


# --- save ---------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var f := {}
	for p in found:
		f[String(p)] = (found[p] as Array).map(func(x): return String(x))
	return { "found": f, "lures": lures.map(func(x): return String(x)), "fresh": fresh,
		"secrets": (entries[&"secrets"] as Array).map(func(x): return String(x)) }


## Loads silently (no sounds, no page_completed for pages already pinned).
func from_dict(d: Dictionary) -> void:
	for id in d.get("secrets", []):
		if not (entries[&"secrets"] as Array).has(StringName(id)):
			(entries[&"secrets"] as Array).append(StringName(id))
	var f: Dictionary = d.get("found", {})
	for p in PAGES:
		var have: Array[StringName] = []
		for id in f.get(String(p), []):
			have.append(StringName(id))
		found[p] = have
	lures.clear()
	for p in d.get("lures", []):
		lures.append(StringName(p))
	fresh = int(d.get("fresh", 0))
	var destruct = Save.get_value(WorldDestruct.SAVE_KEY, {})
	if destruct is Dictionary and destruct.get("props") is Dictionary:
		sync_broken(destruct.props)


## True when the script or any base script is the named global class (RingFood extends FoodData).
static func _is_class(sc: Script, cls: String) -> bool:
	while sc != null:
		if sc.get_global_name() == cls:
			return true
		sc = sc.get_base_script()
	return false
