## One species in a ring's food chain (data/rings/*_life.tres). Counters, not bodies: the whole
## ring's population is a number; a few of them are spawned live into the chunks round the worms.
## Per planet second:
##   plant:    +growth_rate * N * (1 - N / capacity)
##   animal:   +efficiency * intake * (1 - N / capacity) - death * N
##   intake from each prey p: eats[p] * N * P / (P + half_sat), taken off the prey
##   everyone: +immigration (a ring is never emptied for good)
class_name PopulationRule
extends Resource

@export var id: StringName
## RingDef.id it lives in.
@export var ring: StringName
@export var start := 10.0
@export var plant := false
@export var growth_rate := 0.0
@export var capacity := 100.0
@export var death := 0.0
@export var efficiency := 0.5
@export var immigration := 0.01
## prey species id -> attack rate.
@export var eats: Dictionary[StringName, float] = {}
@export var half_sat := 10.0
## Live bodies per counted one (8 live grubs stand for 32 counted) and the live cap for the species.
@export var live_scale := 0.25
@export var live_max := 8
## What a live one is: a creature scene (scenes/creatures/*.tscn) or a food (data/foods/*.tres).
@export_file("*.tscn", "*.tres") var live: String
## Spawn band inside the ring, as fractions of the planet radius (0 = use the whole ring).
@export var depth_min := 0.0
@export var depth_max := 0.0
