## A pet (data/pets/*.tres): a small creature that, carried home alive (hold X), lives in the burrow
## and does a job. `food` is its wild form for the worm (the duck-typed food interface: a worm can
## also just eat it, like any small thing). Job &"fetch": every `every` planet seconds it flies off
## and comes back with `fetch` (a FoodData id), which waits by the bed, at most `max_waiting`.
class_name PetData
extends Resource

@export var id: StringName
@export var food: FoodData
@export var job := &"fetch"
@export var fetch := &"seed"
@export var every := 45.0
@export var trip := 2.5
@export var max_waiting := 2
@export var color := Color(0.9, 0.15, 0.12)
## Planet seconds before a wild one that was eaten or taken home turns up again.
@export var regrow := 120.0
