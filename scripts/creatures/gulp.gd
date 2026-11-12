## The one eaten path for anything that gulps a worm (beetles, the bird, the apex beetle). The
## creature shows the cause (it is drawn mid-gulp, jaws shut, the worm a bulge inside it); the worm
## pops out of its far end one segment shorter and dizzy (Worm.get_eaten: stars, wobble, `eaten`
## cue, never a pain sound), lands next to its partner if the partner is close, otherwise in the
## nearest open tunnel to the far end, and sparkles for 0.5 s, during which nothing can eat it.
class_name Gulp
extends RefCounted

## px: a partner this close to the far end is where the worm lands (next to them).
const PARTNER_NEAR := 160.0
## px: how far round the far end to look for an open tunnel.
const TUNNEL_SEARCH := 96.0
## px beside the partner's head (times its size factor), so the two heads never overlap.
const PARTNER_SIDE := 22.0


## Gulp `w`. `far_end` is the creature's back end in global px. Returns false (and does nothing)
## if the worm is still sparkling from the last time.
## `from` (optional) is the creature's centre: the worm comes out facing away from it, head first.
static func eat(creature_id: StringName, w: Node2D, far_end: Vector2, from = null) -> bool:
	if w == null or not is_instance_valid(w) or is_safe(w):
		return false
	var at := landing(w, far_end)
	if from is Vector2 and at.distance_to(from) > 0.5:
		w.heading = (at - from).angle()
	w.get_eaten(creature_id, at)
	var old := sparkle_of(w)
	if old:
		old.free()
	var s := EatenSparkle.new()
	s.tint = Players.COLOR.get(w.player, Color.WHITE)
	w.head.add_child(s)
	return true


## Still sparkling: no creature can eat it.
static func is_safe(w: Node) -> bool:
	var s := sparkle_of(w)
	return s != null and s.is_safe()


static func sparkle_of(w: Node) -> EatenSparkle:
	if w == null or not is_instance_valid(w) or w.get("head") == null:
		return null
	return w.head.get_node_or_null(NodePath(EatenSparkle.NAME)) as EatenSparkle


## Where the worm comes out: next to a nearby partner, else the nearest open tunnel to the far end,
## else the far end itself.
static func landing(w: Node2D, far_end: Vector2) -> Vector2:
	for o in w.get_tree().get_nodes_in_group(&"worms"):
		if o == w or not (o is Node2D) or o.get_parent() != w.get_parent() or o.get("head") == null:
			continue
		var hp: Vector2 = o.head_position()
		if hp.distance_to(far_end) <= PARTNER_NEAR:
			var side := (far_end - hp)
			side = side.normalized() if side.length() > 0.5 else Vector2.RIGHT
			var k: float = o.size_factor() if o.has_method("size_factor") else 1.0
			return hp + side * PARTNER_SIDE * maxf(1.0, k)
	var world: PolarWorld = w.get("world")
	if world == null:
		return far_end
	var r := 0.0
	while r <= TUNNEL_SEARCH:
		var n := 1 if r == 0.0 else 12
		for i in n:
			var p := far_end + Vector2.from_angle(TAU * i / n) * r
			var cell := world.shape.cell_at(world.to_local(p))
			if world.shape.contains(cell) and not world.is_solid(cell):
				return p
		r += 8.0
	return far_end
