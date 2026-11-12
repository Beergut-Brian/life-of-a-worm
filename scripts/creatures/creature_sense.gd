## How a creature reacts to one worm, from size alone (GAME.md "Bugs and threats"): smaller than
## the worm flees slowly, bigger ambles toward it, equal size ignores it; a Jarling is a friend.
## "The worm's size" for one creature is what the worm can bite of that creature's flavour: the
## stage row's edible size plus the worm's `bite_bonus/<flavour>` stat, the same sum
## `Worm.can_eat` uses, so food-or-not and flee-or-not can never disagree. Read-only: it never
## changes WormRules or WormStats.
class_name CreatureSense
extends RefCounted

enum React { FLEE, IGNORE, AMBLE, FRIEND }


## The table: creature size vs worm size.
static func react(creature_stage: int, worm_size: int, jarling := false) -> React:
	if jarling:
		return React.FRIEND
	if creature_stage < worm_size:
		return React.FLEE
	if creature_stage > worm_size:
		return React.AMBLE
	return React.IGNORE


## The worm's size as this creature sees it (edible size + bite bonus for its flavour).
static func worm_size(w: Node, data: FoodData) -> int:
	if w == null or w.get("model") == null:
		return 0
	var model: WormGrowth = w.model
	var bonus := model.stats.value("bite_bonus/" + String(data.flavour)) if data else 0.0
	return model.stage_info().edible_size + int(round(bonus))


static func of(data: FoodData, w: Node) -> React:
	if data == null or w == null or w.get("model") == null:
		return React.IGNORE
	return react(data.size_stage, worm_size(w, data), is_jarling(data))


## Food for this worm? Never for a Jarling; otherwise smaller or equal (what Worm.can_eat says).
static func is_food(data: FoodData, w: Node) -> bool:
	var r := of(data, w)
	return r == React.FLEE or r == React.IGNORE


## A threat to this worm: bigger than it (and never a Jarling).
static func is_threat(data: FoodData, w: Node) -> bool:
	return of(data, w) == React.AMBLE


static func is_jarling(data: Resource) -> bool:
	return data != null and data.get("jarling") == true
