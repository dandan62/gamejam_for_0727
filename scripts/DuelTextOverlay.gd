extends Control
class_name DuelTextOverlay

@onready var round_draw: Label = %RoundDraw
@onready var effect_text: Label = %EffectText


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clear_result()


func show_result(state: StringName, description: String) -> void:
	round_draw.visible = state == &"draw"
	effect_text.text = description
	effect_text.visible = not description.is_empty()


func clear_result() -> void:
	round_draw.visible = false
	effect_text.visible = false
	effect_text.text = ""
