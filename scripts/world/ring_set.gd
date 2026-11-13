## The whole planet recipe: rings core outward, castings and garden tuning, the Strangestone seam.
class_name RingSet
extends Resource

@export var rings: Array[RingDef] = []
## regrow_time is multiplied by this where a worm left castings (0.25 = four times as fast).
@export_range(0.01, 1.0) var castings_factor: float = 0.25
## Extra growth per food size above 1, in plain tiles (1.0: a size-2 tile is worth two plain ones).
@export var size_growth: float = 1.0
## A ring is never exhausted: once more than this share of its cells is eaten and waiting, its
## regrow times shrink, down to scarce_factor x when it is all eaten.
@export_range(0.0, 1.0) var scarce_share: float = 0.5
@export_range(0.01, 1.0) var scarce_factor: float = 0.2
## Planet seconds between a garden filling one more cell.
@export var garden_interval: float = 4.0
## A patch spreads through castings up to this many tiles from its seed.
@export var garden_max_radius: int = 10
## Flavour -> tile name for garden patches (the tile is food of that flavour).
@export var garden_tiles: Dictionary[StringName, StringName] = {}
@export var garden_hues: Dictionary[StringName, Color] = {}
## The unbreakable Strangestone seam at the very centre: a disk this many tiles across plus a
## thin seam twice as long.
@export var strangestone_radius: float = 3.0
@export var strangestone_hue: Color = Color("b8ff6a")
@export var castings_hue: Color = Color("2a1a10")


## Palette for TileWorld: index = tile id, 0 = air, 1 = strangestone, then each ring's two tiles,
## then garden tiles. Names are unique.
func tile_defs() -> Array[TileDef]:
	var out: Array[TileDef] = []
	out.append(_def(&"air", Color.TRANSPARENT, false, false))
	out.append(_def(&"strangestone", strangestone_hue, true, false))
	for r in rings:
		out.append(_def(r.tile, r.hue, true, true))
		if r.alt_tile != &"":
			out.append(_def(r.alt_tile, r.alt_hue, true, true))
	for f in garden_tiles:
		out.append(_def(garden_tiles[f], garden_hues.get(f, Color.WHITE), true, true))
	return out


func _def(id: StringName, color: Color, solid: bool, breakable: bool) -> TileDef:
	var d := TileDef.new()
	d.id = id
	d.color = color
	d.solid = solid
	d.breakable = breakable
	return d
