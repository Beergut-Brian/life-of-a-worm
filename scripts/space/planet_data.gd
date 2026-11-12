## One themed planet type for stage 7 (data/planets/*.tres, S-18): the big planet that drifts by,
## the small foods that drift round it, and the rare star trait some of those foods carry.
## While its meal is unfinished the big planet is bigger than the worm (StageRule THREAT: it bumps);
## once `meal` of its foods are eaten it ripens to food (the ring of pips round it shows why).
## Placeholder art: SpacePlanet draws tinted circles in `color` / `accent`.
class_name PlanetData
extends Resource

@export var id: StringName
@export var color := Color.WHITE
@export var accent := Color.WHITE
## The big planet's size stage (the worm is 7): 8 or more bumps.
@export var size_stage := 9
## Its own size on screen, px (0 = SpacePlanet.radius_for(size_stage)).
@export var radius := 0.0
## The size stage it drops to once its meal is eaten (below 7, so it is food).
@export var ripe_stage := 6
## Its own foods (FoodData, size_stage below 7): drawn at random, `live_foods` at once round it.
@export var foods: Array[FoodData] = []
@export var live_foods := 6
## Foods of this planet to eat before the planet itself is food (one pip each round it).
@export var meal := 8
## Drift speed across the screen, px/s.
@export var drift := 24.0
## The rare trait: the chance a spawned food carries it (a twinkling star on it), once per run.
@export var star_trait: TraitData
@export_range(0.0, 1.0) var star_chance := 0.15
