## The space ring (W-08, data/rings/space_life.tres): a RingLife for stage 7. Space has no tiles, no
## gravity and no planet clock of its own; its counters (moons, comets, planets, the sun) step on the
## space stage's time with the same PopulationRule rates as the rings, and SpaceDrift spawns live
## bodies from them round the worms. Big planets are the only threat: they bump, nothing hunts
## (L-19). The five themed planets come one at a time in a seeded random order; the sun comes last.
class_name SpaceLife
extends RingLife

## The planet types (data/planets/*.tres), shuffled per run with the tin's seed.
@export var planets: Array[PlanetData] = []
## Moons and comets: small food anywhere in space, between the themed foods.
@export var moon: FoodData
@export var comet: FoodData
@export var comet_speed := 140.0
## The sun: arrives once all five planets are eaten; that makes it food (the last meal).
@export var sun_stage := 6
@export var sun_radius := 420.0
@export var sun_color := Color("ffc93a")
@export var sun_accent := Color("ff8a1e")
## Spawn band round the worms' centre (px), and past this the drifting thing is gone for good.
@export var spawn_min := 900.0
@export var spawn_max := 1300.0
@export var forget_at := 2600.0
## How hard a bigger planet knocks a worm back (px/s), and a beat before the next planet drifts in.
@export var bump_speed := 520.0
@export var next_planet_after := 3.0
