## A worm's body as data: one flavour per segment, growth, stage, earned and active traits.
## No nodes, so tests and the save can drive it directly. Worm (the node) mirrors it on screen.
class_name WormGrowth
extends RefCounted

signal segment_added(flavour: StringName)
signal segment_lost()
signal stage_changed(from: int, to: int)
signal trait_earned(trait_id: StringName, equipped: bool)
signal traits_changed(active: Array[StringName])

var rules: WormRules
## Flavour per segment, index 0 next to the head; new segments join at the tail.
var segments: Array[StringName] = []
## Growth toward the next segment.
var growth := 0.0
## Growth per flavour since the last segment; the biggest share names the next segment.
var pending := {}
var stage := 1
## Earned traits in the order earned (never removed).
var earned: Array[StringName] = []
## Equipped traits, at most slots().
var active: Array[StringName] = []
var stats: WormStats
## Grey-box rule (GAME.md "Stage up"): a stage needs enough segments AND that ring's apex creature
## eaten. Off by default so the trait arena and its tests keep the segments-only prototype rule.
var apex_gate := false
## Stages whose apex creature this worm has eaten (eating the stage-1 apex opens stage 2).
var apex_eaten: Array[int] = []


func _init(r: WormRules = null) -> void:
	rules = r if r != null else WormRules.default_rules()
	for i in rules.start_segments:
		segments.append(&"")
	stage = rules.stage_for(segments.size())
	_resolve()


## Adds growth; pops segments as it fills. flavour &"" = plain (a partner's share).
## Returns how many segments were added.
func add_growth(amount: float, flavour: StringName = &"") -> int:
	growth += amount
	pending[flavour] = float(pending.get(flavour, 0.0)) + amount
	var added := 0
	while growth >= rules.growth_per_segment - 0.0001:
		growth -= rules.growth_per_segment
		add_segment(_pending_flavour())
		pending.clear()
		added += 1
	return added


func add_segment(flavour: StringName) -> void:
	segments.append(flavour)
	segment_added.emit(flavour)
	_check_traits()
	_check_stage()


## Eaten by something bigger: the newest segment goes, the stage and every trait stay.
func lose_segment() -> void:
	if segments.size() <= 1:
		return
	segments.pop_back()
	segment_lost.emit()


func flavour_count(flavour: StringName) -> int:
	return segments.count(flavour)


func slots() -> int:
	return rules.slots_for(stage)


func is_active(id: StringName) -> bool:
	return id in active


## Trait wall: equip or unequip. Equipping with every slot full does nothing (returns false).
func toggle(id: StringName) -> bool:
	if not id in earned:
		return false
	if id in active:
		active.erase(id)
	elif active.size() < slots():
		active.append(id)
	else:
		return false
	_resolve()
	traits_changed.emit(active.duplicate())
	return true


## Drop-in: start at a stage (the partner's minus one), plain segments.
func start_at_stage(s: int) -> void:
	s = clampi(s, 1, rules.max_stage())
	while segments.size() < rules.stage_segments[s]:
		segments.append(&"")
	for k in range(1, s):
		if not k in apex_eaten:
			apex_eaten.append(k)   # a hatchling starts past the apexes of the stages below it
	_check_stage()


## Debug / perf harness: earn a trait outright (fills nothing).
func grant(id: StringName) -> void:
	if rules.find_trait(id) != null and not id in earned:
		_earn(id)


func _pending_flavour() -> StringName:
	var best: StringName = &""
	var best_amount := -1.0
	var keys := pending.keys()
	keys.sort()
	for k in keys:
		if pending[k] > best_amount:
			best = k
			best_amount = pending[k]
	return best


func _check_traits() -> void:
	for t in rules.traits:
		if t.id in earned or t.requires.is_empty():
			continue
		var met := true
		for f in t.requires:
			if flavour_count(StringName(f)) < int(t.requires[f]):
				met = false
				break
		if met:
			_earn(t.id)


func _earn(id: StringName) -> void:
	earned.append(id)
	var equipped := active.size() < slots()
	if equipped:
		active.append(id)
		_resolve()
	trait_earned.emit(id, equipped)
	if equipped:
		traits_changed.emit(active.duplicate())


## The size the body has grown to (segments only, never below the stage). What creatures compare
## against: the stage-1 apex is a threat until this reaches 2, then it is food.
func size_stage() -> int:
	return maxi(stage, rules.stage_for(segments.size()))


## The highest stage the apex creatures eaten so far allow (no gate: the last stage).
func apex_cap() -> int:
	if not apex_gate:
		return rules.max_stage()
	var s := 1
	while s in apex_eaten:
		s += 1
	return s


## Ate the apex creature of the ring that belongs to `ring_stage`; returns true on a stage-up.
func eat_apex(ring_stage: int) -> bool:
	if not ring_stage in apex_eaten:
		apex_eaten.append(ring_stage)
	var before := stage
	_check_stage()
	return stage > before


func to_dict() -> Dictionary:
	var segs := []
	for f in segments:
		segs.append(String(f))
	var pend := {}
	for k in pending:
		pend[String(k)] = pending[k]
	return { "segments": segs, "growth": growth, "pending": pend, "stage": stage,
		"earned": earned.map(func(t): return String(t)), "active": active.map(func(t): return String(t)),
		"apex_eaten": apex_eaten.duplicate() }


## Restores a body saved by to_dict(); signals are not emitted (the node rebuilds from the data).
func from_dict(d: Dictionary) -> void:
	segments.clear()
	for f in d.get("segments", []):
		segments.append(StringName(f))
	growth = float(d.get("growth", 0.0))
	pending = {}
	var pend: Dictionary = d.get("pending", {})
	for k in pend:
		pending[StringName(k)] = float(pend[k])
	stage = int(d.get("stage", 1))
	earned.clear()
	for t in d.get("earned", []):
		if rules.find_trait(StringName(t)) != null:
			earned.append(StringName(t))
	active.clear()
	for t in d.get("active", []):
		if StringName(t) in earned and active.size() < slots():
			active.append(StringName(t))
	apex_eaten.clear()
	for a in d.get("apex_eaten", []):
		apex_eaten.append(int(a))
	_resolve()


func _check_stage() -> void:
	var s := maxi(stage, mini(rules.stage_for(segments.size()), apex_cap()))
	if s == stage:
		return
	var from := stage
	stage = s
	# More slots: the newest earned traits that are waiting equip themselves.
	var changed := false
	for i in range(earned.size() - 1, -1, -1):
		if active.size() >= slots():
			break
		if not earned[i] in active:
			active.append(earned[i])
			changed = true
	_resolve()
	stage_changed.emit(from, stage)
	if changed:
		traits_changed.emit(active.duplicate())


func _resolve() -> void:
	var list: Array = []
	for id in active:
		list.append(rules.find_trait(id))
	stats = WormStats.resolve(list, rules.base_stats, stage)
