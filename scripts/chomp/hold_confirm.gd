## Hold-to-confirm: hold for `hold_time` seconds while a ring fills; letting go cancels and the ring
## drains. Pure logic so it is testable; the chomp scene feeds it whether A is held.
class_name HoldConfirm
extends RefCounted

signal started()
signal cancelled()
signal confirmed()

var hold_time := 2.0
var progress := 0.0      # 0..1, the ring
var done := false
var _holding := false


func step(delta: float, held: bool) -> void:
	if done:
		return
	if held:
		if not _holding:
			_holding = true
			started.emit()
		progress = minf(1.0, progress + delta / hold_time)
		if progress >= 1.0:
			done = true
			confirmed.emit()
	else:
		if _holding:
			_holding = false
			cancelled.emit()
		progress = maxf(0.0, progress - delta * 2.0)


func is_holding() -> bool:
	return _holding
