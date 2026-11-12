## Look C's storybook grade on the dock and its cutscenes (Docket D92: "C's grade on the dock").
## A CanvasLayer with one full-screen ColorRect running shaders/dock_grade.gdshader over everything
## drawn below its layer. Only the dock scene carries one; nothing underground ever does.
class_name DockGrade
extends CanvasLayer

const SHADER := preload("res://shaders/dock_grade.gdshader")

## 0 = off, 1 = the full grade (the story can ease it, e.g. stronger in a flashback).
@export_range(0.0, 1.0) var strength := 1.0:
	set(v):
		strength = v
		if _mat:
			_mat.set_shader_parameter(&"strength", v)

var rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter(&"strength", strength)
	rect = ColorRect.new()
	rect.name = "Paper"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.material = _mat
	add_child(rect)
