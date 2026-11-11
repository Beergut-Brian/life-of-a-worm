## The one rule, shared by the disk and space: bigger eats smaller, equal ignores, smaller is a threat.
## This is the stage-logic interface space reuses from the disk (GAME.md "Scale stages"); the disk's
## World.is_edible_by(stage, thing) should answer relation(stage, thing.size_stage) == FOOD.
class_name StageRule
extends RefCounted

enum { FOOD, THREAT, IGNORE }


static func relation(eater_stage: int, other_stage: int) -> int:
	if other_stage < eater_stage:
		return FOOD
	if other_stage > eater_stage:
		return THREAT
	return IGNORE


static func stage_of(thing) -> int:
	if thing is Object and "size_stage" in thing:
		return int(thing.size_stage)
	return -1
