extends AudioStreamPlayer

const RESTART_DELAY_SECONDS := 2.0


func _ready() -> void:
	finished.connect(_on_finished)


func _on_finished() -> void:
	await get_tree().create_timer(RESTART_DELAY_SECONDS).timeout
	if is_inside_tree():
		play()
