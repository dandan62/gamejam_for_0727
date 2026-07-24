extends Control
class_name PrepShieldFill

const SHIELD_TEXTURE := preload("res://assets/ui/prep/shield_bar.png")
const SHIELD_BOUNDS := Rect2i(12, 58, 55, 49)
const CHANGE_DURATION := 0.6

var _display_ratio := 0.0
var _target_ratio := 0.0
var _change_per_second := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func set_ratio(value: float) -> void:
	_target_ratio = clampf(value, 0.0, 1.0)
	if is_equal_approx(_display_ratio, _target_ratio):
		_display_ratio = _target_ratio
		set_process(false)
		queue_redraw()
		return
	_change_per_second = absf(_target_ratio - _display_ratio) / CHANGE_DURATION
	set_process(true)


func _process(delta: float) -> void:
	_display_ratio = move_toward(
		_display_ratio,
		_target_ratio,
		_change_per_second * delta
	)
	queue_redraw()
	if is_equal_approx(_display_ratio, _target_ratio):
		_display_ratio = _target_ratio
		set_process(false)


func _draw() -> void:
	var visible_rows := clampi(
		ceili(float(SHIELD_BOUNDS.size.y) * _display_ratio),
		0,
		SHIELD_BOUNDS.size.y
	)
	if visible_rows == 0:
		return

	var top_y := SHIELD_BOUNDS.end.y - visible_rows
	var visible_region := Rect2(
		SHIELD_BOUNDS.position.x,
		top_y,
		SHIELD_BOUNDS.size.x,
		visible_rows
	)
	draw_texture_rect_region(SHIELD_TEXTURE, visible_region, visible_region)
