extends Control

const SIGN_HOVER_COLOR := Color(1.35, 1.22, 0.9, 1.0)
const CHOICE_HOVER_COLOR := Color(1.0, 0.84, 0.45, 1.0)
const REST_HEAL_AMOUNT := 15
const HURRY_GOLD_REWARD := 30
const PERSISTENT_PRECOMBAT_MUSIC_NAME := "PersistentPrecombatMusic"

@onready var branch_ui: Control = %BranchUI
@onready var rest_ui: Control = %RestUI
@onready var store_sign: TextureButton = %StoreSign
@onready var inn_sign: TextureButton = %InnSign
@onready var rest_button: Button = %RestButton
@onready var hurry_button: Button = %HurryButton
@onready var rest_text: Label = %RestText
@onready var hurry_text: Label = %HurryText
@onready var branch_music: AudioStreamPlayer = %BranchMusic


func _ready() -> void:
	_prepare_persistent_branch_music()
	_setup_sign(store_sign)
	_setup_sign(inn_sign)
	store_sign.pressed.connect(_on_store_sign_pressed)
	inn_sign.pressed.connect(_on_inn_sign_pressed)
	store_sign.mouse_entered.connect(_on_sign_hovered.bind(store_sign))
	store_sign.mouse_exited.connect(_on_sign_unhovered.bind(store_sign))
	inn_sign.mouse_entered.connect(_on_sign_hovered.bind(inn_sign))
	inn_sign.mouse_exited.connect(_on_sign_unhovered.bind(inn_sign))
	rest_button.pressed.connect(_on_rest_pressed)
	hurry_button.pressed.connect(_on_hurry_pressed)
	rest_button.mouse_entered.connect(_on_choice_hovered.bind(rest_text))
	rest_button.mouse_exited.connect(_on_choice_unhovered.bind(rest_text))
	hurry_button.mouse_entered.connect(_on_choice_hovered.bind(hurry_text))
	hurry_button.mouse_exited.connect(_on_choice_unhovered.bind(hurry_text))
	_show_branch()


func _setup_sign(sign_button: TextureButton) -> void:
	if sign_button.texture_normal == null:
		return
	var image := sign_button.texture_normal.get_image()
	if image == null or image.is_empty():
		return
	var click_mask := BitMap.new()
	click_mask.create_from_image_alpha(image, 0.1)
	sign_button.texture_click_mask = click_mask


func _show_branch() -> void:
	branch_ui.visible = true
	rest_ui.visible = false
	store_sign.self_modulate = Color.WHITE
	inn_sign.self_modulate = Color.WHITE
	rest_text.self_modulate = Color.WHITE
	hurry_text.self_modulate = Color.WHITE


func _on_sign_hovered(sign_button: TextureButton) -> void:
	sign_button.self_modulate = SIGN_HOVER_COLOR


func _on_sign_unhovered(sign_button: TextureButton) -> void:
	sign_button.self_modulate = Color.WHITE


func _on_store_sign_pressed() -> void:
	_stop_persistent_branch_music()
	get_tree().change_scene_to_file.call_deferred("res://scenes/Shop.tscn")


func _on_inn_sign_pressed() -> void:
	branch_ui.visible = false
	rest_ui.visible = true


func _on_choice_hovered(choice_text: Label) -> void:
	choice_text.self_modulate = CHOICE_HOVER_COLOR


func _on_choice_unhovered(choice_text: Label) -> void:
	choice_text.self_modulate = Color.WHITE


func _on_rest_pressed() -> void:
	GameManager.hp = min(GameManager.max_hp, GameManager.hp + REST_HEAL_AMOUNT)
	_go_to_next_battle()


func _on_hurry_pressed() -> void:
	GameManager.gold += HURRY_GOLD_REWARD
	_go_to_next_battle()


func _go_to_next_battle() -> void:
	GameManager.start_next_battle()
	get_tree().change_scene_to_file.call_deferred("res://scenes/Battle.tscn")


func _prepare_persistent_branch_music() -> void:
	var existing := get_tree().root.get_node_or_null(
		PERSISTENT_PRECOMBAT_MUSIC_NAME
	) as AudioStreamPlayer
	if existing != null:
		branch_music.queue_free()
		branch_music = existing
		return

	branch_music.name = PERSISTENT_PRECOMBAT_MUSIC_NAME
	var music_stream := branch_music.stream as AudioStreamMP3
	if music_stream != null:
		music_stream.loop = true
	branch_music.play()
	branch_music.call_deferred("reparent", get_tree().root)


func _stop_persistent_branch_music() -> void:
	if not is_instance_valid(branch_music):
		return
	branch_music.stop()
	branch_music.queue_free()
