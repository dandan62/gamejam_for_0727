extends Control
class_name PrepBulletView

signal clicked(card: CardData)
signal hover_started(card: CardData)
signal hover_ended(card: CardData)

const BULLET_TEXTURE := preload("res://assets/ui/prep/revolver_bullet.png")
const ROCK_TEXTURE := preload("res://assets/ui/prep/rock_icon_16.png")
const PAPER_TEXTURE := preload("res://assets/ui/prep/paper_icon_16.png")
const SCISSORS_TEXTURE := preload("res://assets/ui/prep/scissors_icon_16.png")

const BULLET_POSITION := Vector2(15, 0)
const BULLET_SIZE := Vector2(18, 38)

var card_data: CardData
var _visual_root: Control
var _hand_layer: Control
var _effect_label: Label
var _hit_button: Button


func _ready() -> void:
	size = Vector2(48, 55)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_visual_root = Control.new()
	_visual_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_visual_root)

	var bullet := TextureRect.new()
	bullet.position = BULLET_POSITION
	bullet.size = BULLET_SIZE
	bullet.texture = BULLET_TEXTURE
	bullet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bullet.stretch_mode = TextureRect.STRETCH_KEEP
	bullet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual_root.add_child(bullet)

	_effect_label = Label.new()
	_effect_label.position = Vector2(26, -5)
	_effect_label.size = Vector2(30, 13)
	_effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_label.add_theme_font_size_override("font_size", 8)
	_effect_label.add_theme_color_override("font_color", Color.WHITE)
	_effect_label.add_theme_color_override("font_outline_color", Color(0.04, 0.025, 0.015))
	_effect_label.add_theme_constant_override("outline_size", 1)
	_visual_root.add_child(_effect_label)

	_hand_layer = Control.new()
	_hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visual_root.add_child(_hand_layer)

	_hit_button = Button.new()
	_hit_button.position = BULLET_POSITION
	_hit_button.size = BULLET_SIZE
	_hit_button.flat = true
	_hit_button.focus_mode = Control.FOCUS_NONE
	_hit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty_style := StyleBoxEmpty.new()
	for style_name in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		_hit_button.add_theme_stylebox_override(style_name, empty_style)
	_hit_button.mouse_entered.connect(_on_mouse_entered)
	_hit_button.mouse_exited.connect(_on_mouse_exited)
	_hit_button.pressed.connect(_on_pressed)
	add_child(_hit_button)


func setup_card(data: CardData, interactive: bool = true) -> void:
	card_data = data
	_effect_label.text = _effect_text(data.card_type, data.value)
	_render_hands(data.janken_hands)
	_hit_button.visible = interactive


func setup_enemy(turn: Dictionary) -> void:
	card_data = null
	_effect_label.text = enemy_effect_text(str(turn.get("type", "attack")), int(turn.get("value", 0)))
	_render_hands(turn.get("hands", []))
	_hit_button.visible = false


## 敵行動タイプ（文字列）→ 表示テキスト。溜め=↑ / 貫通=⚡ を追加。
static func enemy_effect_text(type_str: String, value: int) -> String:
	match type_str:
		"skill":
			return "🛡%d" % value
		"power":
			return "✚%d" % value
		"charge":
			return "↑%d" % value
		"pierce":
			return "⚡%d" % value
	return "⚔%d" % value


static func effect_text(action_type: int, value: int) -> String:
	return _effect_text(action_type, value)


static func hand_texture(hand: int) -> Texture2D:
	match hand:
		CardData.Hand.ROCK:
			return ROCK_TEXTURE
		CardData.Hand.PAPER:
			return PAPER_TEXTURE
		CardData.Hand.SCISSORS:
			return SCISSORS_TEXTURE
	return null


static func _effect_text(action_type: int, value: int) -> String:
	match action_type:
		CardData.CardType.SKILL:
			return "🛡%d" % value
		CardData.CardType.POWER:
			return "✚%d" % value
		CardData.CardType.CHARGE:
			return "↑%d" % value
		CardData.CardType.SHIELD_BREAK:
			return "破"
	return "⚔%d" % value


func _render_hands(hands: Array) -> void:
	for child in _hand_layer.get_children():
		child.queue_free()

	if hands.is_empty():
		return

	var positions: Array[Vector2] = []
	if hands.size() == 1:
		positions.append(Vector2(15, 30))
	else:
		positions.append(Vector2(7, 30))
		positions.append(Vector2(23, 30))

	for index in range(min(hands.size(), positions.size())):
		var icon_texture := hand_texture(int(hands[index]))
		if icon_texture == null:
			continue
		var icon := TextureRect.new()
		icon.position = positions[index]
		icon.size = Vector2(17, 17)
		icon.texture = icon_texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hand_layer.add_child(icon)


func _on_mouse_entered() -> void:
	_visual_root.position.y = -2.0
	if card_data != null:
		hover_started.emit(card_data)


func _on_mouse_exited() -> void:
	_visual_root.position.y = 0.0
	if card_data != null:
		hover_ended.emit(card_data)


func _on_pressed() -> void:
	if card_data != null:
		clicked.emit(card_data)
