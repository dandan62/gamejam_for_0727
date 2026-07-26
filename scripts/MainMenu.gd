extends Control

const TITLE_BOARD_TEXTURE := preload("res://assets/ui/title/title_board.png")
const BULLET_HOLE_PRE_TEXTURE := preload("res://assets/ui/title/bullet_hole_pre.png")
const BULLET_HOLE_TEXTURE := preload("res://assets/ui/title/bullet_hole.png")

const IMPACT_FRAME_SECONDS := 0.1
const HOLE_LIFETIME_SECONDS := 15.0
const HOLE_FADE_SECONDS := 3.0
const MAX_ACTIVE_HOLES := 64
const PERSISTENT_TITLE_MUSIC_NAME := "PersistentTitleMusic"
const CURTAIN_OPEN_SECONDS := 1.2
const BOARD_RISE_SECONDS := 0.95
const BOARD_RISE_DELAY_SECONDS := 0.05
const INTRO_FADE_SECONDS := 0.25
const INTRO_LINES: Array[String] = [
	"[center]They said he was the sharpest shooter in the Wild West.[/center]",
	"[center]But it wasn’t speed that made him unbeatable.[/center]",
	"[center]Before a hand reached for a holster, before a bullet left its chamber… he had already seen how the duel would end.[/center]",
	"[center]The man who could outdraw the future itself—[/center]",
	"[center]His name — was [b]Bobby Mundane...[/b][/center]",
]
const INTRO_HOLD_SECONDS: Array[float] = [2.6, 2.4, 4.8, 2.5, 3.0]

@onready var board_click_area: Control = %BoardClickArea
@onready var bullet_hole_layer: Control = %BulletHoleLayer
@onready var title_gunshot_audio: AudioStreamPlayer = %TitleGunshotAudio
@onready var title_music: AudioStreamPlayer = %TitleMusic
@onready var left_curtain: TextureRect = %LeftCurtain
@onready var right_curtain: TextureRect = %RightCurtain
@onready var title_board_group: Control = %TitleBoardGroup
@onready var start_art: TextureRect = %StartArt
@onready var quit_art: TextureRect = %QuitArt
@onready var start_button: Button = %StartButton
@onready var quit_button: Button = %QuitButton
@onready var monologue_layer: Control = %MonologueLayer
@onready var monologue_text: RichTextLabel = %MonologueText
@onready var skip_button: Button = %SkipButton

var _board_image: Image
var _active_holes: Array[TextureRect] = []
var _opening_expedition := false
var _intro_skip_requested := false


func _ready() -> void:
	_board_image = TITLE_BOARD_TEXTURE.get_image()
	var persistent_music := get_tree().root.get_node_or_null(
		PERSISTENT_TITLE_MUSIC_NAME
	) as AudioStreamPlayer
	if persistent_music != null:
		var scene_music := title_music
		title_music = persistent_music
		scene_music.queue_free()
	else:
		title_music.play()


func _on_start_pressed() -> void:
	if _opening_expedition:
		return
	_opening_expedition = true
	_disable_menu_input()

	var transition_gunshot := AudioStreamPlayer.new()
	transition_gunshot.stream = title_gunshot_audio.stream
	transition_gunshot.volume_db = title_gunshot_audio.volume_db
	get_tree().root.add_child(transition_gunshot)
	transition_gunshot.finished.connect(transition_gunshot.queue_free)
	transition_gunshot.play()

	await _play_opening_animation()
	if not is_inside_tree():
		return
	await _play_intro_monologue()
	if not is_inside_tree():
		return

	GameManager.new_game()
	GameManager.start_next_battle()
	_stop_title_music()
	get_tree().change_scene_to_file.call_deferred("res://scenes/Battle.tscn")


func _disable_menu_input() -> void:
	start_button.disabled = true
	quit_button.disabled = true
	start_button.release_focus()
	quit_button.release_focus()
	board_click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_art.visible = false
	quit_art.visible = false


func _play_opening_animation() -> void:
	var opening := create_tween()
	opening.set_parallel(true)
	opening.tween_method(
		_set_left_curtain_x,
		left_curtain.position.x,
		-float(left_curtain.size.x),
		CURTAIN_OPEN_SECONDS
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	opening.tween_method(
		_set_right_curtain_x,
		right_curtain.position.x,
		320.0,
		CURTAIN_OPEN_SECONDS
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	opening.tween_method(
		_set_title_board_y,
		title_board_group.position.y,
		-180.0,
		BOARD_RISE_SECONDS
	).set_delay(BOARD_RISE_DELAY_SECONDS).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
	await opening.finished


func _set_left_curtain_x(value: float) -> void:
	left_curtain.position.x = roundf(value)


func _set_right_curtain_x(value: float) -> void:
	right_curtain.position.x = roundf(value)


func _set_title_board_y(value: float) -> void:
	title_board_group.position.y = roundf(value)


func _play_intro_monologue() -> void:
	_intro_skip_requested = false
	skip_button.disabled = false
	monologue_text.visible = true
	monologue_text.modulate.a = 0.0
	monologue_layer.visible = true

	for index in range(INTRO_LINES.size()):
		if _intro_skip_requested:
			break
		monologue_text.position.y = 56.0 if index == 2 else 68.0
		monologue_text.text = INTRO_LINES[index]
		monologue_text.modulate.a = 0.0

		var faded_in := await _fade_monologue_text(1.0, INTRO_FADE_SECONDS)
		if not faded_in:
			break
		var held := await _wait_during_intro(INTRO_HOLD_SECONDS[index])
		if not held:
			break
		var faded_out := await _fade_monologue_text(0.0, INTRO_FADE_SECONDS)
		if not faded_out:
			break

	monologue_text.text = ""
	monologue_text.modulate.a = 0.0
	monologue_layer.visible = false


func _fade_monologue_text(target_alpha: float, duration: float) -> bool:
	var start_alpha := monologue_text.modulate.a
	var start_ms := Time.get_ticks_msec()
	var duration_ms := maxf(1.0, duration * 1000.0)
	while true:
		if _intro_skip_requested or not is_inside_tree():
			return false
		var elapsed_ms := float(Time.get_ticks_msec() - start_ms)
		var progress := clampf(elapsed_ms / duration_ms, 0.0, 1.0)
		monologue_text.modulate.a = lerpf(start_alpha, target_alpha, progress)
		if progress >= 1.0:
			return true
		await get_tree().process_frame
	return false


func _wait_during_intro(duration: float) -> bool:
	var end_ms := Time.get_ticks_msec() + int(duration * 1000.0)
	while Time.get_ticks_msec() < end_ms:
		if _intro_skip_requested or not is_inside_tree():
			return false
		await get_tree().process_frame
	return true


func _on_skip_intro_pressed() -> void:
	if not monologue_layer.visible:
		return
	_intro_skip_requested = true
	skip_button.disabled = true
	monologue_layer.visible = false


func _stop_title_music() -> void:
	if not is_instance_valid(title_music):
		return
	title_music.stop()
	if title_music.get_parent() == get_tree().root:
		title_music.queue_free()


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
