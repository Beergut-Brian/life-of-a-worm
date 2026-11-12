## A pet (data/pets/*.tres): a small creature that, carried home alive (hold X), lives in the burrow
## and does a job. `food` is its wild form for the worm (the duck-typed food interface: a worm can
## also just eat it, like any small thing). Jobs (Pet):
##  - &"fetch" (ladybird): every `every` planet seconds it flies off and comes back with `fetch` (a
##    FoodData id), which waits by the bed, at most `max_waiting`.
##  - &"lamp" (glow-worm): while the room is dark (Burrow.night, or home in one of `dark_rings`) it
##    lights the room: a light of `lamp_radius` tiles, and a short wiggle every `wiggle_every` s.
##  - &"tend" (ant crew): every `every` s it walks to the seed bed of the garden nearest home (within
##    `tend_range` tiles), works there `work` s and, if the cell is still a seed bed, nudges the
##    garden on: its next growth comes `nudge` planet seconds sooner. Then it walks home.
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
## Placeholder look drawn in code (PetLook): &"ladybird" | &"glowworm" | &"ant_crew".
@export var look := &"ladybird"
## At most this many of this pet live in one burrow (Burrow.MAX_PETS caps all of them).
@export var max_kept := 3
## The wild one never comes back while this many live in the burrow (0: always comes back).
@export var wild_max := 0

@export_group("Lamp")
## Light radius in tiles.
@export var lamp_radius := 5.0
@export var lamp_energy := 0.9
@export var lamp_color := Color(1.0, 0.93, 0.55)
## Rings (RingDef.id) where the room counts as dark even by day.
@export var dark_rings: Array[StringName] = [&"dirt", &"deep_rock", &"core"]
@export var wiggle_every := 5.0

@export_group("Tend")
## Walking speed, px per second.
@export var walk_speed := 24.0
## Only gardens whose seed bed is this many tiles from home or closer are tended.
@export var tend_range := 30.0
## Seconds spent working at the bed.
@export var work := 1.5
## Planet seconds the garden's next growth is pulled forward (the regrow boost).
@export var nudge := 8.0
