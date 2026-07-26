extends Control

const PERSISTENT_TITLE_MUSIC_NAME := "PersistentTitleMusic"

@onready var loss_panel: Control = %LossPanel
@onready var win_panel: Control = %WinPanel
@onready var title_label: Label = %TitleLabel
@onready var desc_label: Label = %DescLabel
@onready var restart_button: Button = %RestartButton
@onready var return_button: Button = %ReturnButton
@onready var title_music: AudioStreamPlayer = %TitleMusic

func _ready() -> void:
	var player_won := GameManager.game_over_reason == "win"
	loss_panel.visible = not player_won
	win_panel.visible = player_won
	if player_won:
		title_music.queue_free()
		title_label.text = "クリア！"
		desc_label.text = "全%d バトルを制覇した！ ガンマンの伝説は続く…" % GameManager.TOTAL_BATTLES
	else:
		_start_persistent_title_music()
	restart_button.pressed.connect(_on_restart_pressed)
	return_button.pressed.connect(_on_restart_pressed)


func _start_persistent_title_music() -> void:
	var persistent_music := get_tree().root.get_node_or_null(
		PERSISTENT_TITLE_MUSIC_NAME
	) as AudioStreamPlayer
	if persistent_music != null:
		title_music.queue_free()
		title_music = persistent_music
		if not title_music.playing:
			title_music.play()
		return

	title_music.name = PERSISTENT_TITLE_MUSIC_NAME
	title_music.play()
	title_music.call_deferred("reparent", get_tree().root)


func _on_restart_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/MainMenu.tscn")
