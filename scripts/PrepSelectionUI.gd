extends Control
class_name PrepSelectionUI

signal hand_card_clicked(card: CardData)
signal slot_clicked(index: int)
signal confirm_pressed

const BELT_BULLET_POSITIONS := [
	Vector2(87, 130),
	Vector2(119, 130),
	Vector2(151, 130),
	Vector2(183, 130),
	Vector2(215, 130),
]
const ENEMY_BULLET_POSITIONS := [
	Vector2(111, 10),
	Vector2(151, 10),
	Vector2(191, 10),
]
const SLOT_CENTERS := [
	Vector2(120, 113),
	Vector2(160, 89),
	Vector2(200, 113),
]

@onready var enemy_bullet_layer: Control = %EnemyBulletLayer
@onready var hand_layer: Control = %HandLayer
@onready var slot_metadata_layer: Control = %SlotMetadataLayer
@onready var health_fill: PrepHealthFill = %HealthFill
@onready var health_text: Label = %HealthText
@onready var watch_needle: TextureRect = %WatchNeedle
@onready var confirm_art: TextureRect = %ConfirmArt
@onready var confirm_button: Button = %ConfirmButton

@onready var inserted_rounds: Array[TextureRect] = [
	%InsertedRound1,
	%InsertedRound2,
	%InsertedRound3,
]
@onready var slot_buttons: Array[Button] = [
	%SlotButton1,
	%SlotButton2,
	%SlotButton3,
]

var _hand: Array[CardData] = []
var _slots: Array = []
var _enemy_upcoming: Array = []
var _confirm_hovered := false
var _confirm_down := false


func _ready() -> void:
	size = Vector2(320, 180)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	confirm_button.focus_mode = Control.FOCUS_NONE
	confirm_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	confirm_button.mouse_entered.connect(_on_confirm_mouse_entered)
	confirm_button.mouse_exited.connect(_on_confirm_mouse_exited)
	confirm_button.button_down.connect(_on_confirm_button_down)
	confirm_button.button_up.connect(_on_confirm_button_up)

	for index in range(slot_buttons.size()):
		var button := slot_buttons[index]
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_slot_pressed.bind(index))


func configure(
	hand: Array[CardData],
	slots: Array,
	enemy_upcoming: Array,
	hp: int,
	max_hp: int,
	duration: float
) -> void:
	_hand.assign(hand)
	_slots = slots.duplicate()
	_enemy_upcoming = enemy_upcoming.duplicate(true)
	_confirm_hovered = false
	_confirm_down = false
	_update_confirm_visual()
	set_health(hp, max_hp)
	update_timer(duration, duration)
	_render_enemy_intents()
	_render_hand()
	_render_slots()


func refresh_selection(hand: Array[CardData], slots: Array) -> void:
	_hand.assign(hand)
	_slots = slots.duplicate()
	_render_hand()
	_render_slots()


func update_timer(time_left: float, duration: float) -> void:
	var progress := 1.0
	if duration > 0.0:
		progress = clampf(1.0 - time_left / duration, 0.0, 1.0)
	watch_needle.rotation = progress * TAU


func set_health(hp: int, max_hp: int) -> void:
	var ratio := 0.0
	if max_hp > 0:
		ratio = float(hp) / float(max_hp)
	health_fill.set_ratio(ratio)
	health_text.text = "%d/%d" % [hp, max_hp]


func _render_enemy_intents() -> void:
	_clear_layer(enemy_bullet_layer)
	for index in range(min(_enemy_upcoming.size(), ENEMY_BULLET_POSITIONS.size())):
		var view := PrepBulletView.new()
		enemy_bullet_layer.add_child(view)
		view.position = ENEMY_BULLET_POSITIONS[index] - Vector2(15, 0)
		view.setup_enemy(_enemy_upcoming[index])


func _render_hand() -> void:
	_clear_layer(hand_layer)
	for index in range(min(_hand.size(), BELT_BULLET_POSITIONS.size())):
		var card := _hand[index]
		if _slots.has(card):
			continue
		var view := PrepBulletView.new()
		hand_layer.add_child(view)
		view.position = BELT_BULLET_POSITIONS[index] - Vector2(15, 0)
		view.setup_card(card)
		view.clicked.connect(func(selected_card: CardData): hand_card_clicked.emit(selected_card))


func _render_slots() -> void:
	_clear_layer(slot_metadata_layer)
	for index in range(inserted_rounds.size()):
		var card: CardData = _slots[index] if index < _slots.size() else null
		inserted_rounds[index].visible = card != null
		slot_buttons[index].disabled = card == null
		if card == null:
			continue
		_add_slot_effect(index, card)
		_add_slot_hands(index, card.janken_hands)


func _add_slot_effect(index: int, card: CardData) -> void:
	var label := Label.new()
	label.position = SLOT_CENTERS[index] + Vector2(14, -7)
	label.size = Vector2(31, 13)
	label.text = PrepBulletView.effect_text(card.card_type, card.value)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.025, 0.015))
	label.add_theme_constant_override("outline_size", 1)
	slot_metadata_layer.add_child(label)


func _add_slot_hands(index: int, hands: Array) -> void:
	if hands.is_empty():
		return

	var center: Vector2 = SLOT_CENTERS[index]
	var positions: Array[Vector2] = []
	if hands.size() == 1:
		positions.append(center + Vector2(-8, -23))
	else:
		positions.append(center + Vector2(-17, -21))
		positions.append(center + Vector2(0, -21))

	for hand_index in range(min(hands.size(), positions.size())):
		var icon_texture := PrepBulletView.hand_texture(int(hands[hand_index]))
		if icon_texture == null:
			continue
		var icon := TextureRect.new()
		icon.position = positions[hand_index]
		icon.size = Vector2(17, 17)
		icon.texture = icon_texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_metadata_layer.add_child(icon)


func _clear_layer(layer: Control) -> void:
	for child in layer.get_children():
		child.queue_free()


func _on_slot_pressed(index: int) -> void:
	if index < _slots.size() and _slots[index] != null:
		slot_clicked.emit(index)


func _on_confirm_mouse_entered() -> void:
	_confirm_hovered = true
	_update_confirm_visual()


func _on_confirm_mouse_exited() -> void:
	_confirm_hovered = false
	_update_confirm_visual()


func _on_confirm_button_down() -> void:
	_confirm_down = true
	_update_confirm_visual()
	confirm_pressed.emit()


func _on_confirm_button_up() -> void:
	_confirm_down = false
	_update_confirm_visual()


func _update_confirm_visual() -> void:
	if _confirm_down:
		confirm_art.position = Vector2(0, 1)
		confirm_art.modulate = Color(0.72, 0.72, 0.72)
	elif _confirm_hovered:
		confirm_art.position = Vector2.ZERO
		confirm_art.modulate = Color(1.15, 1.15, 1.15)
	else:
		confirm_art.position = Vector2.ZERO
		confirm_art.modulate = Color.WHITE
