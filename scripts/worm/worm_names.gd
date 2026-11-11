## The two worms' names, as the game shows them (Kaden, Docket D90, 2026-11-11): the green worm
## (Player 1's slot) is Gulp, the red worm (Player 2's slot) is Burp. The name goes with the slot
## colour, like the colour itself. Used by menu labels only; gameplay stays text-free.
class_name WormNames

const NAMES := ["Gulp", "Burp"]


## "Gulp" for Players.P1, "Burp" for Players.P2.
static func of(player: int) -> String:
	return NAMES[player] if player >= 0 and player < NAMES.size() else "Worm"
