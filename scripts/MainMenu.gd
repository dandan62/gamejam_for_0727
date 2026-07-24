extends Control

func _on_start_pressed() -> void:
	GameManager.new_game()
	GameManager.start_next_battle()
	get_tree().change_scene_to_file("res://scenes/Battle.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
