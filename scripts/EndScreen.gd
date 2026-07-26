extends Control

const PERSISTENT_TITLE_MUSIC_NAME := "PersistentTitleMusic"
const CREDITS_SCROLL_SPEED := 30.0
const CREDITS_FINAL_BOTTOM := 196.0

@onready var loss_panel: Control = %LossPanel
@onready var win_panel: Control = %WinPanel
@onready var credits_clip: Control = %CreditsClip
@onready var credits_text: RichTextLabel = %CreditsText
@onready var restart_button: Button = %RestartButton
@onready var return_button: Button = %ReturnButton
@onready var title_music: AudioStreamPlayer = %TitleMusic
@onready var ending_music: AudioStreamPlayer = %EndingMusic
@onready var death_message: Label = %DeathMessage

func _ready() -> void:
	var player_won := GameManager.game_over_reason == "win"
	loss_panel.visible = not player_won
	win_panel.visible = player_won
	if player_won:
		title_music.queue_free()
		ending_music.play()
		_play_ending_credits()
	else:
		ending_music.queue_free()
		death_message.text = "You died on the %s enemy..." % _ordinal(
			maxi(1, GameManager.battle_index)
		)
		_start_persistent_title_music()
	restart_button.pressed.connect(_on_restart_pressed)
	return_button.pressed.connect(_on_restart_pressed)


func _play_ending_credits() -> void:
	restart_button.visible = false
	await get_tree().process_frame
	if not is_inside_tree():
		return

	var content_height := maxf(
		1.0,
		float(credits_text.get_content_height())
	)
	credits_text.size = Vector2(credits_clip.size.x, content_height)
	var start_y := credits_clip.size.y
	var final_y := CREDITS_FINAL_BOTTOM - content_height
	credits_text.position = Vector2(0.0, start_y)
	var duration := maxf(
		1.0,
		(start_y - final_y) / CREDITS_SCROLL_SPEED
	)
	var roll := create_tween()
	roll.tween_property(
		credits_text,
		"position:y",
		final_y,
		duration
	).set_trans(Tween.TRANS_LINEAR)
	await roll.finished
	if not is_inside_tree():
		return
	restart_button.visible = true


static func _ordinal(value: int) -> String:
	var suffix := "th"
	var final_two_digits := absi(value) % 100
	if final_two_digits < 11 or final_two_digits > 13:
		match absi(value) % 10:
			1:
				suffix = "st"
			2:
				suffix = "nd"
			3:
				suffix = "rd"
	return "%d%s" % [value, suffix]


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
