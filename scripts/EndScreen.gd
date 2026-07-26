extends Control

@onready var title_label: Label = %TitleLabel
@onready var desc_label: Label = %DescLabel
@onready var restart_button: Button = %RestartButton

func _ready() -> void:
	if GameManager.game_over_reason == "win":
		title_label.text = "クリア！"
		desc_label.text = "全%d バトルを制覇した！ ガンマンの伝説は続く…" % GameManager.TOTAL_BATTLES
	else:
		title_label.text = "ゲームオーバー"
		desc_label.text = "バトル%d で倒れた。またの挑戦を待つ。" % GameManager.battle_index
	restart_button.pressed.connect(_on_restart_pressed)

func _on_restart_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/MainMenu.tscn")
