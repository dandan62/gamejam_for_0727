extends Control

const STOCK_COUNT := 4
const WELCOME_TEXT := "Welcome in!\nHow may I help you?"
const LEAVE_HOVER_COLOR := Color(1.2, 1.12, 0.9, 1.0)
const BUCKLER := preload("res://resources/relics/buckler.tres")
const HORSESHOE := preload("res://resources/relics/horseshoe.tres")
const RELIC_STOCK := [BUCKLER, HORSESHOE]
const BULLET_POSITIONS := [
	Vector2(191, 4),
	Vector2(227, 4),
	Vector2(191, 54),
	Vector2(227, 54),
]
const RELIC_POSITIONS := {
	&"buckler": Vector2(258, 30),
	&"horseshoe": Vector2(260, 62),
}

@onready var item_layer: Control = %ItemLayer
@onready var dialogue_text: Label = %DialogueText
@onready var gold_label: Label = %GoldLabel
@onready var leave_art: TextureRect = %LeaveArt
@onready var leave_button: Button = %LeaveButton
@onready var store_music: AudioStreamPlayer = %StoreMusic
@onready var purchase_audio: AudioStreamPlayer = %PurchaseAudio
@onready var door_chime_audio: AudioStreamPlayer = %DoorChimeAudio

var card_stock: Array[Dictionary] = []
var relic_stock: Array[Dictionary] = []
var _hovered_key: StringName


func _ready() -> void:
	var music_stream := store_music.stream as AudioStreamMP3
	if music_stream != null:
		music_stream.loop = true
	store_music.play()
	door_chime_audio.play()
	leave_button.pressed.connect(_on_leave)
	leave_button.mouse_entered.connect(_on_leave_hovered)
	leave_button.mouse_exited.connect(_on_leave_unhovered)
	_build_stock()
	_render_stock()
	dialogue_text.text = WELCOME_TEXT


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_leave()


func _build_stock() -> void:
	var pool := GameManager.all_cards.filter(
		func(card: CardData) -> bool:
			return not GameManager.starter_deck_ids.has(card.id)
	)
	pool.shuffle()
	for index in range(min(STOCK_COUNT, pool.size())):
		var card := pool[index] as CardData
		card_stock.append({
			"card": card,
			"price": _price_for(card),
			"sold": false,
		})

	for relic_resource in RELIC_STOCK:
		var relic := relic_resource as RelicData
		relic_stock.append({
			"relic": relic,
			"sold": GameManager.owns_relic(relic.relic_id),
		})


func _price_for(card: CardData) -> int:
	match card.rarity:
		CardData.Rarity.COMMON:
			return randi_range(30, 40)
		CardData.Rarity.UNCOMMON:
			return randi_range(60, 70)
		CardData.Rarity.RARE:
			return randi_range(120, 130)
	return randi_range(30, 40)


func _render_stock() -> void:
	for child in item_layer.get_children():
		child.queue_free()

	for index in range(card_stock.size()):
		var item := card_stock[index]
		if bool(item.get("sold", false)):
			continue
		_add_card_view(index, item)

	for item in relic_stock:
		if bool(item.get("sold", false)):
			continue
		_add_relic_view(item)

	gold_label.text = str(GameManager.gold)


func _add_card_view(index: int, item: Dictionary) -> void:
	if index >= BULLET_POSITIONS.size():
		return
	var card := item.get("card") as CardData
	if card == null:
		return

	var view := PrepBulletView.new()
	item_layer.add_child(view)
	view.position = BULLET_POSITIONS[index] - PrepBulletView.BULLET_POSITION
	view.setup_card(card, true, PrepBulletView.BulletVisualMode.SHOP)
	view.clicked.connect(_on_card_pressed.bind(item))
	view.hover_started.connect(_on_card_hovered.bind(item))
	view.hover_ended.connect(_on_card_exited.bind(item))


func _add_relic_view(item: Dictionary) -> void:
	var relic := item.get("relic") as RelicData
	if relic == null or relic.icon == null:
		return
	var icon_position: Vector2 = RELIC_POSITIONS.get(relic.relic_id, Vector2.ZERO)
	var padding := Vector2(3, 4)

	var hit_root := Control.new()
	hit_root.position = icon_position - padding
	hit_root.size = relic.icon.get_size() + padding * 2.0
	hit_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_layer.add_child(hit_root)

	var visual := TextureRect.new()
	visual.position = padding
	visual.size = relic.icon.get_size()
	visual.texture = relic.icon
	visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visual.stretch_mode = TextureRect.STRETCH_KEEP
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_root.add_child(visual)

	var button := Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty_style := StyleBoxEmpty.new()
	for style_name in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(style_name, empty_style)
	button.mouse_entered.connect(_on_relic_hovered.bind(item, visual, padding.y))
	button.mouse_exited.connect(_on_relic_exited.bind(item, visual, padding.y))
	button.pressed.connect(_on_relic_pressed.bind(item))
	hit_root.add_child(button)


func _on_card_hovered(_card: CardData, item: Dictionary) -> void:
	var card := item.get("card") as CardData
	if card == null:
		return
	_hovered_key = _card_key(card)
	var lines: Array[String] = [_card_effect_text(card)]
	var enchant_description := card.get_enchant_description()
	if not enchant_description.is_empty():
		lines.append(enchant_description)
	lines.append(_hand_text(card.janken_hands))
	lines.append("PRICE %dG" % int(item.get("price", 0)))
	dialogue_text.text = "\n".join(lines)


func _on_card_exited(card: CardData, _item: Dictionary) -> void:
	_clear_description_if(_card_key(card))


func _on_card_pressed(_card: CardData, item: Dictionary) -> void:
	if bool(item.get("sold", false)):
		return
	var price := int(item.get("price", 0))
	if GameManager.gold < price:
		dialogue_text.text = "NOT ENOUGH GOLD."
		return
	var card := item.get("card") as CardData
	if card == null:
		return

	GameManager.gold -= price
	GameManager.discard_pile.append(card.duplicate())
	item["sold"] = true
	_hovered_key = &""
	dialogue_text.text = ""
	purchase_audio.play()
	_render_stock()


func _on_relic_hovered(item: Dictionary, visual: TextureRect, rest_y: float) -> void:
	var relic := item.get("relic") as RelicData
	if relic == null:
		return
	visual.position.y = rest_y - 2.0
	_hovered_key = relic.relic_id
	dialogue_text.text = "%s\n%s\nPRICE %dG" % [
		relic.display_name,
		relic.description,
		relic.price,
	]


func _on_relic_exited(item: Dictionary, visual: TextureRect, rest_y: float) -> void:
	visual.position.y = rest_y
	var relic := item.get("relic") as RelicData
	if relic != null:
		_clear_description_if(relic.relic_id)


func _on_relic_pressed(item: Dictionary) -> void:
	if bool(item.get("sold", false)):
		return
	var relic := item.get("relic") as RelicData
	if relic == null:
		return
	if GameManager.gold < relic.price:
		dialogue_text.text = "NOT ENOUGH GOLD."
		return

	GameManager.gold -= relic.price
	GameManager.add_relic(relic.relic_id)
	item["sold"] = true
	_hovered_key = &""
	dialogue_text.text = ""
	purchase_audio.play()
	_render_stock()


func _clear_description_if(item_key: StringName) -> void:
	if _hovered_key != item_key:
		return
	_hovered_key = &""
	dialogue_text.text = ""


func _card_key(card: CardData) -> StringName:
	return StringName("card_%d" % card.id)


func _card_effect_text(card: CardData) -> String:
	match card.card_type:
		CardData.CardType.ATTACK:
			return "DEAL %d DAMAGE" % card.value
		CardData.CardType.SKILL:
			return "GAIN %d SHIELD" % card.value
		CardData.CardType.POWER:
			return "HEAL %d HP" % card.value
		CardData.CardType.CHARGE:
			return "NEXT ATTACK +%d" % card.value
		CardData.CardType.SHIELD_BREAK:
			return "BREAK HALF SHIELD"
	return ""


func _hand_text(hands: Array) -> String:
	var names: Array[String] = []
	for hand in hands:
		match int(hand):
			CardData.Hand.ROCK:
				names.append("ROCK")
			CardData.Hand.PAPER:
				names.append("PAPER")
			CardData.Hand.SCISSORS:
				names.append("SCISSORS")
	return " + ".join(names)


func _on_leave() -> void:
	var exit_chime := AudioStreamPlayer.new()
	exit_chime.stream = door_chime_audio.stream
	exit_chime.volume_db = door_chime_audio.volume_db
	get_tree().root.add_child(exit_chime)
	exit_chime.finished.connect(exit_chime.queue_free)
	exit_chime.play()
	GameManager.start_next_battle()
	get_tree().change_scene_to_file.call_deferred("res://scenes/Battle.tscn")


func _on_leave_hovered() -> void:
	leave_art.self_modulate = LEAVE_HOVER_COLOR


func _on_leave_unhovered() -> void:
	leave_art.self_modulate = Color.WHITE
