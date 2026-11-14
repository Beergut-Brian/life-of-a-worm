## A surface thing's sketch for the collection book and the tackle box (T-05): the same picture the
## thing has on the planet (its PropData footprint in lantern tiles plus PropLook's marks: windows,
## wheels, a cow's spots), shrunk to fit a page cell. Not found yet: the same outline, flat grey,
## no tiles and no marks, so the shape is the clue. No words, no new art.
class_name PropSketch
extends RefCounted

const ATLAS: Texture2D = SurfaceProp.ATLAS
const CS := PropLook.CS


## The scale that fits d's footprint in a square `box` px wide.
static func scale_for(d: PropData, box: float) -> float:
	return box / (float(maxi(d.size.x, d.size.y)) * CS)


## Draws d centred on c inside a square `box` px wide. `base` is the transform the caller is drawing
## with (Book.fit_matrix); it is put back before returning.
static func draw(ci: CanvasItem, d: PropData, c: Vector2, box: float, found: bool, base := Transform2D.IDENTITY) -> void:
	if d == null:
		return
	var k := scale_for(d, box)
	var size := Vector2(d.size) * CS
	# The footprint's top-left sits at -size/2, so the sketch is centred on c.
	ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(k, k), 0.0, c))
	var r := Rect2(-size * 0.5, size)
	var edge := BookArt.PENCIL if found else BookArt.GREY_DARK
	for y in d.size.y:
		for x in d.size.x:
			if PropLook.filled(d.look, d.size, x, y):
				ci.draw_rect(Rect2(r.position + Vector2(x, y) * CS, Vector2(CS, CS)).grow(1.5), edge)
	var row := SurfaceProp._atlas_row(d.tile)
	var top_row := SurfaceProp._atlas_row(d.top_tile) if d.top_tile != &"" else row
	for y in d.size.y:
		for x in d.size.x:
			if not PropLook.filled(d.look, d.size, x, y):
				continue
			var cell := Rect2(r.position + Vector2(x, y) * CS, Vector2(CS, CS))
			if not found:
				ci.draw_rect(cell, BookArt.GREY)
				continue
			var open := 0
			if not _filled(d, x, y - 1): open |= 1
			if not _filled(d, x + 1, y): open |= 2
			if not _filled(d, x, y + 1): open |= 4
			if not _filled(d, x - 1, y): open |= 8
			var v := (x * 7 + y * 13) % 4
			var src := Rect2(Vector2((open * 4 + v) * CS, (top_row if y < d.top_rows else row) * CS), Vector2(CS, CS))
			ci.draw_texture_rect_region(ATLAS, cell, src)
	if found:
		PropLook.draw_marks(ci, d, r)
	ci.draw_set_transform_matrix(base)


static func _filled(d: PropData, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= d.size.x or y >= d.size.y:
		return false
	return PropLook.filled(d.look, d.size, x, y)
