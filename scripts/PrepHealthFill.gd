extends Control
class_name PrepHealthFill

var _heart_polygon := PackedVector2Array([
	Vector2(4, 19),
	Vector2(4, 13),
	Vector2(7, 7),
	Vector2(12, 4),
	Vector2(18, 3),
	Vector2(23, 5),
	Vector2(33, 14),
	Vector2(42, 5),
	Vector2(49, 3),
	Vector2(56, 5),
	Vector2(62, 10),
	Vector2(64, 16),
	Vector2(63, 22),
	Vector2(60, 28),
	Vector2(33, 57),
	Vector2(6, 29),
	Vector2(2, 22),
])

var _ratio := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_ratio(value: float) -> void:
	_ratio = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if _ratio <= 0.0:
		return
	var fill_top := lerpf(58.0, 2.0, _ratio)
	var clipped := _clip_polygon_below_y(_heart_polygon, fill_top)
	if clipped.size() >= 3:
		draw_colored_polygon(clipped, Color("#d92935"))


func _clip_polygon_below_y(points: PackedVector2Array, minimum_y: float) -> PackedVector2Array:
	var output: Array[Vector2] = []
	if points.is_empty():
		return PackedVector2Array()

	var previous := points[points.size() - 1]
	var previous_inside := previous.y >= minimum_y
	for current in points:
		var current_inside := current.y >= minimum_y
		if current_inside != previous_inside:
			var distance := current.y - previous.y
			if not is_zero_approx(distance):
				var amount := (minimum_y - previous.y) / distance
				output.append(previous.lerp(current, amount))
		if current_inside:
			output.append(current)
		previous = current
		previous_inside = current_inside

	return PackedVector2Array(output)
