extends Node

const CURSOR_TEXTURE: Texture2D = preload("res://assets/ui/cursor.png")
const CURSOR_SCALE := 4
const CURSOR_HOTSPOT := Vector2(46, 46)

var _scaled_cursor_texture: ImageTexture

func _ready() -> void:
	var cursor_image := CURSOR_TEXTURE.get_image()
	cursor_image.resize(
		cursor_image.get_width() * CURSOR_SCALE,
		cursor_image.get_height() * CURSOR_SCALE,
		Image.INTERPOLATE_NEAREST
	)
	_scaled_cursor_texture = ImageTexture.create_from_image(cursor_image)

	Input.set_custom_mouse_cursor(
		_scaled_cursor_texture,
		Input.CURSOR_ARROW,
		CURSOR_HOTSPOT
	)
	Input.set_custom_mouse_cursor(
		_scaled_cursor_texture,
		Input.CURSOR_POINTING_HAND,
		CURSOR_HOTSPOT
	)
