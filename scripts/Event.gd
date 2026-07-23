extends Control

@onready var name_label: Label = %EventNameLabel
@onready var desc_label: Label = %DescLabel
@onready var image_rect: TextureRect = %EventImage
@onready var choices_box: VBoxContainer = %ChoicesBox

var event: EventData

func _ready() -> void:
	var options := _pick_two_events()
	if options.is_empty():
		# イベントが1つも登録されていない場合はそのまま次のバトルへ
		_go_to_next_battle()
		return
	if options.size() == 1:
		# 1種類しかなければ選択を挟まずそのまま表示
		_show_event(options[0])
		return
	_show_selection(options)

# ---------------- フェーズ1：2つのイベントから選ぶ ----------------
func _show_selection(options: Array) -> void:
	image_rect.texture = null
	name_label.text = "分かれ道"
	desc_label.text = "どちらへ向かう？"
	_clear_choices()
	for ev in options:
		var btn := Button.new()
		btn.text = "%s\n%s" % [ev.event_name, ev.description]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(360, 0)
		btn.pressed.connect(_show_event.bind(ev))
		choices_box.add_child(btn)

# ---------------- フェーズ2：選んだイベントの選択肢 ----------------
func _show_event(selected: EventData) -> void:
	event = selected
	# カード売り場イベントなら専用のショップ画面へ
	if event.is_shop:
		get_tree().change_scene_to_file("res://scenes/Shop.tscn")
		return
	name_label.text = event.event_name
	desc_label.text = event.description
	image_rect.texture = event.image
	_clear_choices()
	for choice in event.choices:
		var btn := Button.new()
		btn.text = _format_choice_label(choice)
		btn.disabled = GameManager.gold < choice.gold_cost
		btn.pressed.connect(_on_choice_pressed.bind(choice))
		choices_box.add_child(btn)

func _pick_two_events() -> Array:
	var pool := GameManager.all_events.duplicate()
	pool.shuffle()
	return pool.slice(0, min(2, pool.size()))

func _clear_choices() -> void:
	for c in choices_box.get_children():
		c.queue_free()

func _format_choice_label(choice: EventChoiceData) -> String:
	if choice.gold_cost > 0:
		return "%s (%dG)" % [choice.label, choice.gold_cost]
	return choice.label

func _on_choice_pressed(choice: EventChoiceData) -> void:
	GameManager.apply_event_choice(choice)
	_go_to_next_battle()

func _go_to_next_battle() -> void:
	GameManager.start_next_battle()
	get_tree().change_scene_to_file("res://scenes/Battle.tscn")
