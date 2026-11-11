## Applies the burrow's trophy bonus to a worm without any worm code knowing about trophies: the
## worm gets its own copy of its WormRules whose base_stats are the original plus the bonus, then
## the one resolver (WormStats) runs as usual, so traits still stack on top the same way.
class_name TrophyBonus
extends RefCounted


static func apply(w: Worm, bonus: Dictionary) -> void:
	if w == null or w.model == null:
		return
	var orig: WormRules = w.get_meta(&"base_rules") if w.has_meta(&"base_rules") else w.model.rules
	if not w.has_meta(&"base_rules"):
		w.set_meta(&"base_rules", orig)
	var r: WormRules = orig.duplicate()
	var base := orig.base_stats.duplicate()
	for k in bonus:
		if base.has(k):
			base[k] = float(base[k]) + float(bonus[k])
	r.base_stats = base
	w.model.rules = r
	w.rules = r
	w.model._resolve()
	w.set_meta(&"trophy_bonus", bonus.duplicate())


## The bonus currently applied to w ({} if none).
static func of(w: Worm) -> Dictionary:
	return w.get_meta(&"trophy_bonus", {}) if w else {}
