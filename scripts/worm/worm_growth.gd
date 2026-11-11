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


func _check_stage() -> void:
	var s := maxi(stage, rules.stage_for(segments.size()))
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
