extends Control

const TITLE_BOARD_TEXTURE := preload("res://assets/ui/title/title_board.png")
const BULLET_HOLE_PRE_TEXTURE := preload("res://assets/ui/title/bullet_hole_pre.png")
const BULLET_HOLE_TEXTURE := preload("res://assets/ui/title/bullet_hole.png")

const IMPACT_FRAME_SECONDS := 0.1
const HOLE_LIFETIME_SECONDS := 15.0
const HOLE_FADE_SECONDS := 3.0
const MAX_ACTIVE_HOLES := 64

@onready var board_click_area: Control = %BoardClickArea
@onready var bullet_hole_layer: Control = %BulletHoleLayer
@onready var title_gunshot_audio: AudioStreamPlayer = %TitleGunshotAudio

var _board_image: Image
var _active_holes: Array[TextureRect] = []


func _ready() -> void:
	_board_image = TITLE_BOARD_TEXTURE.get_image()


func _on_start_pressed() -> void:
	var transition_gunshot := AudioStreamPlayer.new()
	transition_gunshot.stream = title_gunshot_audio.stream
	transition_gunshot.volume_db = title_gunshot_audio.volume_db
	get_tree().root.add_child(transition_gunshot)
	transition_gunshot.finished.connect(transition_gunshot.queue_free)
	transition_gunshot.play()

	GameManager.new_game()
	GameManager.start_next_battle()
	get_tree().change_scene_to_file("res://scenes/Battle.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_board_click_area_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var board_position := board_click_area.position + mouse_event.position
	if not _is_wood_at(board_position):
		return
	_spawn_bullet_hole(board_position)


func _is_wood_at(canvas_position: Vector2) -> bool:
	if _board_image == null or _board_image.is_empty():
		return false
	var pixel := Vector2i(floori(canvas_position.x), floori(canvas_position.y))
	if not Rect2i(Vector2i.ZERO, _board_image.get_size()).has_point(pixel):
		return false
	return _board_image.get_pixelv(pixel).a > 0.1


func _spawn_bullet_hole(canvas_position: Vector2) -> void:
	var hole := TextureRect.new()
	hole.texture = BULLET_HOLE_PRE_TEXTURE
	hole.position = Vector2(
		roundf(canvas_position.x - BULLET_HOLE_TEXTURE.get_width() * 0.5),
		roundf(canvas_position.y - BULLET_HOLE_TEXTURE.get_height() * 0.5)
	)
	hole.size = BULLET_HOLE_TEXTURE.get_size()
	hole.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hole.stretch_mode = TextureRect.STRETCH_KEEP
	hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hole.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bullet_hole_layer.add_child(hole)
	_active_holes.append(hole)
	title_gunshot_audio.play()

	if _active_holes.size() > MAX_ACTIVE_HOLES:
		var oldest: TextureRect = _active_holes.pop_front() as TextureRect
		if is_instance_valid(oldest):
			oldest.queue_free()

	var hold_seconds := maxf(
		0.0,
		HOLE_LIFETIME_SECONDS - HOLE_FADE_SECONDS - IMPACT_FRAME_SECONDS
	)
	var lifecycle := hole.create_tween()
	lifecycle.tween_interval(IMPACT_FRAME_SECONDS)
	lifecycle.tween_callback(func() -> void:
		if is_instance_valid(hole):
			hole.texture = BULLET_HOLE_TEXTURE
	)
	lifecycle.tween_interval(hold_seconds)
	lifecycle.tween_property(hole, "modulate:a", 0.0, HOLE_FADE_SECONDS)
	lifecycle.tween_callback(func() -> void:
		_active_holes.erase(hole)
		if is_instance_valid(hole):
			hole.queue_free()
	)
