## Every press answers (K-15 / C-26): a pad button that does nothing in play (Select alone outside
## solo, the shoulders, the stick clicks; keyboard R) plays "bonk", shakes the pressed button's
## glyph over that player's worm, gives the worm a little pop and opens their hint panel (which
## shows the buttons that do work). The rules are HintRules.refusal_for; this node routes presses.
## Made by PlanetHud. Presses while paused, in a menu or a cutscene never reach it (unhandled only).
class_name PressAnswer
extends Node

## The hud whose panels wake (PlanetHud), and the level whose glyphs shake (PlanetLevel).
var hud: Node
var level: Node
## Presses answered, newest last: [player, glyph] (tests read it).
var answered: Array = []


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		var b: int = event.button_index
		# Select while Start is held is the solo hold starting, not a stray press.
		if b == JOY_BUTTON_BACK and Input.is_joy_button_pressed(event.device, JOY_BUTTON_START):
			return
		var ans := HintRules.refusal_for(b, Players.solo)
		if not ans.is_empty():
			answer(player_of_device(event.device), ans)
	elif event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("restart"):
		var ans := HintRules.refusal_for(JOY_BUTTON_BACK, Players.solo)
		if not ans.is_empty():
			answer(player_of_device(Players.VIRTUAL), ans)


## Which player a device belongs to (solo: the worm with the pad). -1 when nobody has it.
static func player_of_device(device: int) -> int:
	if Players.solo:
		return Players.solo_focus
	for p in [Players.P1, Players.P2]:
		if Players.is_active(p) and Players.device_of(p) == device:
			return p
	return -1


## Answer one refused press for a player (ans from HintRules.refusal_for).
func answer(player: int, ans: Dictionary) -> void:
	if player < 0:
		return
	var w := Worm.of(player)
	if w == null:
		return
	Audio.play("bonk")
	w._pop(w.look, 0.85)
	if level and level.get("_glyphs") is Dictionary and level._glyphs.has(player):
		level._glyphs[player].refuse(String(ans.get("glyph", "")))
	if hud and hud.has_method("panel_of"):
		var panel: PlayerHints = hud.panel_of(player)
		if panel:
			panel.refuse()
	answered.append([player, String(ans.get("glyph", ""))])
