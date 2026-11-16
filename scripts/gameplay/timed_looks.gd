## D108 a: the pool of timed looks, built only from art the worm already has (no new art): one hat
## (the worm's heart, note or star sprite, worn on the head) x one colour stripe (the segment band
## art, tinted) x one segment pattern (a collar behind the head, or the tail tip). 3 x 4 x 2 = 24
## looks a stage; each stage tints its four colours differently. A stage's pool cycles only after
## all 24 were shown: look k of a stage is pool index (k * STRIDE) % SIZE, and STRIDE is coprime to
## SIZE, so k = 0..23 visit every look once and two looks in a row differ in hat and colour.
## Cosmetic only: a look has no stat, speed or growth.
class_name TimedLooks
extends RefCounted

const HATS: Array[StringName] = [&"heart", &"note", &"star"]
const HAT_TEX := {
	&"heart": preload("res://assets/proto/worm/heart.png"),
	&"note": preload("res://assets/proto/worm/note.png"),
	&"star": preload("res://assets/proto/worm/star.png"),
}
const COLOURS := 4
const PATTERNS: Array[StringName] = [&"collar", &"tail"]
const SIZE := 24
const STRIDE := 7
## Segments a pattern stripes (at the collar: right behind the head; at the tail: the last ones).
const PATTERN_SEGMENTS := 4


## The k-th look shown in this stage (k counts from 0, wraps after SIZE).
static func look(stage: int, k: int) -> Dictionary:
	var i := posmod(k * STRIDE, SIZE)
	return {
		"stage": stage,
		"index": i,
		"hat": HATS[i % HATS.size()],
		"colour": colour(stage, (i / HATS.size()) % COLOURS),
		"pattern": PATTERNS[i / (HATS.size() * COLOURS)],
	}


## Bright, never dark (kid check: nothing dark or creepy), and never the players' own green or red
## so a stripe always shows on either worm. Stage s wears four of the eight, a different four (or
## order) each stage: PALETTE[(s - 1 + 2c) % 8].
const PALETTE: Array[Color] = [
	Color("ffd93b"),   # sunny yellow
	Color("ff9a2e"),   # orange
	Color("ff7ac8"),   # pink
	Color("c77dff"),   # lilac
	Color("5fb8ff"),   # sky blue
	Color("3ee6e0"),   # aqua
	Color("ffffff"),   # white
	Color("ff5fa2"),   # bubblegum
]


static func colour(stage: int, c: int) -> Color:
	return PALETTE[posmod(stage - 1 + 2 * c, PALETTE.size())]


## Segment indexes (0 = right behind the head) a pattern stripes on a body of `n` segments.
static func striped(pattern: StringName, n: int) -> Array[int]:
	var out: Array[int] = []
	var k := mini(PATTERN_SEGMENTS, n)
	for j in k:
		out.append(j if pattern == &"collar" else n - 1 - j)
	return out
