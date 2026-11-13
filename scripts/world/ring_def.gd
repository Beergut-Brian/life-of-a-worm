## One ring of the disk planet, core outward. Data lives in data/rings/rings.tres (Content lane tunes it).
class_name RingDef
extends Resource

@export var id: StringName
## Outer edge as a fraction of the planet radius (0..1]. Rings are listed core first.
@export_range(0.0, 1.0) var outer: float = 1.0
## Placeholder tile in the ring's dominant hue, and a sprinkled second tile (ore, clay, crystal).
@export var tile: StringName
@export var alt_tile: StringName
@export var hue: Color = Color.WHITE
@export var alt_hue: Color = Color.WHITE
## Share of cells that are alt_tile (seeded noise).
@export_range(0.0, 1.0) var alt_share: float = 0.15
## Smallest worm stage that can eat this ring's tiles.
@export var edible_from: int = 1
## Planet seconds from being eaten to growing back outside castings. 0 = never regrows.
@export var regrow_time: float = 240.0
## Food size a tile reaches when it grows back in castings (1 = the same as plain ground). Each size
## above 1 is worth RingSet.size_growth more plain tiles' growth and is drawn plump. Edibility does
## not change with it: a big tile is still edible from edible_from, so a worm can always eat it.
@export_range(1, 3) var castings_size: int = 2
## Flavour the tiles give (Diet and traits); a StringName the foods/traits lanes own.
@export var flavour: StringName
