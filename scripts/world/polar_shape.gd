## Life of a Worm's disk shape: the addon's DiskShape with a rounder streaming neighbourhood (W-23).
## The plain DiskShape square grows to 31 chunks (~31k tiles) per worm wherever a band edge adds
## sectors. Here the two edge rows of the neighbourhood (`radius_chunks` rings out and in) reach
## less far sideways than the worm's own ring and the rings next to it: the outer row one sector
## less each side, the inner row (fewer, wider sectors) only the sectors over the worm's own chunk.
## That brings the worst case to the brief's 25 chunks (~25k tiles); the inner row's cut loses no
## more of the screen than a one-sector cut would. The first chunk ring round the worm
## (every chunk touching the worm's own) is always whole, so nothing next to the worm is ever
## missing; the trimmed chunks are the far corners, already off screen at the stage 1 to 4 zooms.
## With radius 1 this is exactly DiskShape's neighbourhood.
class_name PolarShape
extends DiskShape

## Sectors taken off each side of the edge rows (distance == radius_chunks) of a neighbourhood.
var outer_trim := 1
var inner_trim := 2


func neighbourhood(key: Vector2i, radius_chunks: int = 1) -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	var own := sectors_in(key.x)
	var turn := (key.y + 0.5) / own
	for ring in range(maxi(key.x - radius_chunks, 0), mini(key.x + radius_chunks, rings() - 1) + 1):
		var n := sectors_in(ring)
		var reach := radius_chunks
		if radius_chunks >= 2 and ring - key.x == radius_chunks:
			reach = maxi(radius_chunks - outer_trim, 0)
		elif radius_chunks >= 2 and key.x - ring == radius_chunks:
			reach = maxi(radius_chunks - inner_trim, 0)
		# The sectors of this ring that touch the span of `key`, plus `reach` each way.
		var lo := floori((turn - 0.5 / own) * n) - reach
		var hi := ceili((turn + 0.5 / own) * n) - 1 + reach
		if key.x == ring:
			lo = key.y - reach
			hi = key.y + reach
		for s in range(lo, hi + 1):
			var k := Vector2i(ring, posmod(s, n))
			if not keys.has(k):
				keys.append(k)
	return keys
