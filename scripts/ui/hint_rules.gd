## The in-play hint rules (P-13, C-24..C-26), pure so tests can drive them: from one worm's
## context, which button rows its player's hint panel shows, which of them are lit, which glyph
## blinks over its head, and how a press that does nothing is answered. No nodes, no state.
##
## ctx keys (all optional):
##   carry_ready  bool  something carryable is in reach of the mouth (X picks it up)
##   carrying     bool  the mouth holds something (X puts it down)
##   swap         bool  at the Mole with something to swap (A swaps)
##   wall         bool  asleep in the bed, the trait wall is shut (Y opens it)
##   box_new      bool  the tackle box has a page the player has not looked at
##   warp         String  what held B warps to: "partner", "home" or "" (nothing to warp to)
##   partner_far  bool  the partner is out of sight (held B is the way back to them)
##   has_home     bool  older callers: same as warp "home" when warp is missing
class_name HintRules
extends RefCounted

## A row: [glyph token, picture, hold?]. Pictures are drawn by PlayerHints (no text).
const MOVE := ["stick", "worm", false]
const BURST := ["a", "zip", false]
const WIGGLE := ["b", "notes", false]
const HOME := ["b", "home", true]
const PARTNER := ["b", "partner", true]
const CARRY := ["x", "mouth", false]
const DROP := ["x", "drop", false]
const SWAP := ["a", "swap", false]
const BOX := ["y", "box", false]
const WALL := ["y", "wall", false]

## Seconds a panel stays full after it last changed or was asked for (Select, a refused press);
## then it folds down to its lit rows only, so it never sits over the play area for long.
const QUIET_AFTER := 8.0

## Pad buttons that do something in play. Anything else pressed in play is refused (bonk).
const PLAY_BUTTONS := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_START,
	JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]
## Buttons a child's fingers find that the game leaves alone (shoulders, stick clicks). The guide
## button belongs to the launcher / OS and paddles are rare, so neither is answered.
const IDLE_BUTTONS := [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_STICK,
	JOY_BUTTON_RIGHT_STICK]


static func warp_of(ctx: Dictionary) -> String:
	if ctx.has("warp"):
		return String(ctx.warp)
	return "home" if ctx.get("has_home", false) else ""


## The rows of a full panel, top to bottom.
static func rows_for(ctx: Dictionary) -> Array:
	var r: Array = [MOVE, BURST, WIGGLE]
	if ctx.get("swap", false):
		r.append(SWAP)
	if ctx.get("carrying", false):
		r.append(DROP)
	elif ctx.get("carry_ready", false):
		r.append(CARRY)
	match warp_of(ctx):
		"partner":
			r.append(PARTNER)
		"home":
			r.append(HOME)
	r.append(WALL if ctx.get("wall", false) else BOX)   # asleep in the bed, Y is the wall
	return r


## Pictures that are "ready" right now (drawn bright with a pulse).
static func hot_for(ctx: Dictionary) -> Dictionary:
	var carrying: bool = ctx.get("carrying", false)
	return { "mouth": ctx.get("carry_ready", false) and not carrying, "drop": carrying,
		"swap": ctx.get("swap", false), "wall": ctx.get("wall", false),
		"box": ctx.get("box_new", false),
		"partner": warp_of(ctx) == "partner" and ctx.get("partner_far", false) }


## The rows the panel draws: all of them while awake, else only the lit ones (folded).
static func visible_rows(ctx: Dictionary, awake: bool) -> Array:
	var all := rows_for(ctx)
	if awake:
		return all
	var hot := hot_for(ctx)
	return all.filter(func(row: Array) -> bool: return hot.get(row[1], false))


## The blinking glyph over the worm's head: A at the swap shop, X near something to carry, Y
## asleep in the bed (the trait wall), B when the partner is lost and held B brings you back.
static func glyph_for(ctx: Dictionary) -> String:
	if ctx.get("swap", false):
		return "a"
	if ctx.get("carry_ready", false) and not ctx.get("carrying", false):
		return "x"
	if ctx.get("wall", false):
		return "y"
	if hot_for(ctx).partner:
		return "b"
	return ""


## A signature of what the panel shows, so a change wakes it (rows or lit pictures differ).
static func signature(ctx: Dictionary) -> Array:
	var hot := hot_for(ctx)
	var lit: Array = hot.keys().filter(func(k: String) -> bool: return hot[k])
	lit.sort()
	return [rows_for(ctx), lit]


## How a pad press in play is answered when it does nothing by itself. Returns {} for a press
## the game handles, else { glyph: what shakes over the worm ("" = only the panel), wake: true }.
## `solo`: Select hands the pad over in solo, so it is not refused there.
static func refusal_for(button: int, solo: bool) -> Dictionary:
	if button == JOY_BUTTON_BACK:
		return {} if solo else { "glyph": "select", "wake": true }
	if button in IDLE_BUTTONS:
		return { "glyph": "stick" if button in [JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK] else "",
			"wake": true }
	return {}
