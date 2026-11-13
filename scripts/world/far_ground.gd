## K-08: the far ground. Only the chunks round each worm are built as tiles (PolarWorld streams a
## small neighbourhood, W-23), so at the wide stage-4 and stage-5 zooms the rest of the disk showed
## the level's plain back wall: big near-black wedges in the deep rock and the core, the darkest
## thing a kid ever saw in the game. This draws the world's own overview picture (one pixel per
## OVERVIEW_STEP tiles, every ring in its colour, eaten cells clear) as one sprite under the chunk
## tiles, a little dimmer than lit ground, so the unbuilt part of the planet reads as the same
## coloured rings, never black. Streamed chunks draw on top and hide it; tunnels and bites stay open
## (the overview is clear there) and show the back wall as before.
##
## A child of the world (it turns with the planet), z between the back wall and the castings. Made
## by DiskEdge.make_for (CrustBurst.watch), so only a level with a back wall gets one; nothing here
## changes a tile or moves anything.
class_name FarGround
extends Sprite2D

## Above the level's back wall (-4) and DiskEdge, under the castings (-2) and the chunk tiles (-1).
const Z := -3
## The overview's flat ring colours scaled down to sit near the lit tile art's brightness, so the
## line between built and unbuilt ground is soft. Never below the K-08 floor: colour, not black.
const DIM := Color(0.62, 0.6, 0.66)

var world: PolarWorld


## One far ground for a planet world (null for a world without an overview, e.g. a bare test).
static func make_for(p_world: Node) -> FarGround:
	var pw := p_world as PolarWorld
	if pw == null or pw.planet_texture() == null:
		return null
	var existing := pw.get_node_or_null(^"FarGround") as FarGround
	if existing != null:
		return existing
	var g := FarGround.new()
	g.attach(pw)
	pw.add_child(g)
	pw.move_child(g, 0)
	return g


func attach(p_world: PolarWorld) -> void:
	world = p_world
	name = "FarGround"
	texture = world.planet_texture()
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = Z
	z_as_relative = true
	modulate = DIM
	var cs := float(world.shape.cell_size)
	var r := float(world.shape.radius)
	# overview pixel p covers cells p * STEP - r .. + STEP, and cell c spans c * cs .. + cs (px)
	position = Vector2(-r, -r) * cs
	scale = Vector2.ONE * PolarWorld.OVERVIEW_STEP * cs
