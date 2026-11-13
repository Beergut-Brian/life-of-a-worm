## P-07, no forced movement: the shared camera fits both worms out to its widest zoom
## (PolarCamera.min_fit_index). Past that cap it no longer centres between them (which loses both
## worms off opposite edges); it follows one worm, the anchor, and the far worm gets the HUD's edge
## arrow in its colour (PlanetHud) and can hold B to warp to its partner. Nobody is ever moved.
## Anchor: in solo, the worm the pad drives (the camera follows the active player); in co-op, the
## bigger worm, since the smaller one is the one whose held B warps to its partner (C-14); a tie
## keeps the current anchor (P1 first). Both worms are framed again once they would fit with
## REJOIN to spare, so the camera does not flick at the edge.
class_name FarCamera
extends RefCounted

## Fit both again once their spread is this share of the widest view (hysteresis).
const REJOIN := 0.85

var split := false
## The player the camera follows while split, -1 when it frames everyone.
var anchor := -1


## True when every point of every worm fits the camera's widest allowed zoom, scaled by `slack`.
static func fits(camera: PolarCamera, worms: Array, slack := 1.0) -> bool:
	if worms.size() < 2:
		return true
	var view := camera.get_viewport_rect().size if camera.is_inside_tree() else Vector2(1920, 1080)
	var inv := Transform2D(-camera.rotation, Vector2.ZERO)
	var centre := Vector2.ZERO
	for w in worms:
		centre += PolarCamera._tpos(w)
	centre /= worms.size()
	var half := Vector2.ZERO
	for w in worms:
		var pts: Array = w.fit_points() if w.has_method("fit_points") else [PolarCamera._tpos(w)]
		for p: Vector2 in pts:
			var q: Vector2 = inv * (p - centre)
			half = half.max(q.abs())
	var z: float = PolarCamera.ZOOMS[clampi(camera.min_fit_index, 0, PolarCamera.ZOOMS.size() - 1)]
	var room := (view * 0.5 - Vector2.ONE * camera.fit_margin) / z
	return half.x <= room.x * slack and half.y <= room.y * slack


## Once a physics frame: the targets the camera should frame. `focus` is the solo pad's player, or -1.
func step(camera: PolarCamera, worms: Array[Node2D], focus := -1) -> Array[Node2D]:
	if worms.size() < 2:
		split = false
		anchor = -1
		return worms
	if not split and not fits(camera, worms):
		split = true
	elif split and fits(camera, worms, REJOIN):
		split = false
	if not split:
		anchor = -1
		return worms
	anchor = pick_anchor(worms, focus, anchor)
	for w in worms:
		if w.player == anchor:
			return [w] as Array[Node2D]
	return worms


static func pick_anchor(worms: Array, focus: int, current: int) -> int:
	if focus >= 0:
		for w in worms:
			if w.player == focus:
				return focus
	var best: Node2D = null
	for w in worms:
		if best == null or w.model.stage > best.model.stage:
			best = w
	for w in worms:
		if w != best and w.model.stage == best.model.stage:
			# A tie: keep whoever the camera already follows, else P1.
			var players: Array = worms.map(func(o): return o.player)
			if current in players:
				return current
			return players.min()
	return best.player
