## One kind of creature (data/creatures/*.tres). It is also the FoodData a worm gets when it eats
## one, so `Worm.can_eat(creature.data)` is the same bigger-eats-smaller rule as every food.
## size_stage above the worm's stage = threat; at or below = food (it goes wide-eyed and runs).
class_name CreatureData
extends FoodData

enum Behaviour { WIGGLE, MARCH, TRUNDLE, PECK, STOMP }

@export var behaviour := Behaviour.WIGGLE
## The ring it lives in (RingDef.id).
@export var ring: StringName
## Seconds of warning (shadow, wind-up, rumble) before it can reach a worm. Never under 1.0.
@export var telegraph := 1.0
## Cue when it notices a worm or acts (`Audio.play`). Its one bark.
@export var bark := ""
## Cue for the wind-up (the telegraph).
@export var windup_cue := ""
## px per second in open air; half that through solid ground.
@export var speed := 20.0
## px: a smaller worm this close gets noticed (threats only).
@export var notice := 160.0
## px: this close the wind-up starts.
@export var strike := 40.0
## Live prey species it eats on contact (the visible side of the food chain).
@export var hunts: StringName
## Hat colour (ants wear tiny hats). Transparent = no hat.
@export var hat := Color.TRANSPARENT
## Second colour (shell shine, wing).
@export var accent := Color.WHITE


func telegraph_time() -> float:
	return maxf(1.0, telegraph)


func is_threat_to(worm_stage: int) -> bool:
	return size_stage > worm_stage
