extends Control
class_name PrepBulletView

signal clicked(card: CardData)
signal hover_started(card: CardData)
signal hover_ended(card: CardData)

const BULLET_TEXTURE := preload("res://assets/ui/prep/revolver_bullet.png")
const HEAVY_BULLET_TEXTURE := preload("res://assets/ui/bullets/heavy_bullet.png")
const AP_BULLET_TEXTURE := preload("res://assets/ui/bullets/ap_bullet.png")
const SLUG_TEXTURE := preload("res://assets/ui/bullets/slug.png")
const BUCKSHOT_TEXTURE := preload("res://assets/ui/bullets/buckshot.png")
const SILVER_BULLET_TEXTURE := preload("res://assets/ui/bullets/silver_bullet.png")
const SHOP_BASE_BULLET_TEXTURE := preload("res://assets/ui/shop/bullets/base_bullet.png")
const SHOP_HEAVY_BULLET_TEXTURE := preload("res://assets/ui/shop/bullets/heavy.png")
const SHOP_AP_BULLET_TEXTURE := preload("res://assets/ui/shop/bullets/ap_bullet.png")
const SHOP_SLUG_TEXTURE := preload("res://assets/ui/shop/bullets/slug.png")
const SHOP_BUCKSHOT_TEXTURE := preload("res://assets/ui/shop/bullets/buckshot.png")
const SHOP_SILVER_BULLET_TEXTURE := preload("res://assets/ui/shop/bullets/silver.png")
const ROCK_TEXTURE := preload("res://assets/ui/prep/rock_icon_16.png")
const PAPER_TEXTURE := preload("res://assets/ui/prep/paper_icon_16.png")
const SCISSORS_TEXTURE := preload("res://assets/ui/prep/scissors_icon_16.png")
const ALL_HANDS_TEXTURE := preload("res://assets/ui/prep/icon_all.png")
const HEALING_EFFECT_TEXTURE := preload("res://assets/ui/icons/icon_healing.png")
const QUESTION_HAND_TEXTURE := preload("res://assets/ui/icons/icon_question.png")
const SHIELD_EFFECT_TEXTURE := preload("res://assets/ui/icons/icon_shield.png")
const SWORD_EFFECT_TEXTURE := preload("res://assets/ui/icons/icon_sword.png")

enum BulletVisualMode { STANDARD, SHOP }

const BULLET_POSITION := Vector2(15, 0)
const BULLET_SIZE := Vector2(18, 38)
const EFFECT_LABEL_POSITION := Vector2(26, -5)
const SHOP_EFFECT_LABEL_POSITION := Vector2(26, 8)
const EFFECT_VALUE_POSITION := Vector2(39, -5)
const SHOP_EFFECT_VALUE_POSITION := Vector2(39, 8)
const EFFECT_ICON_RIGHT := 38.0
const EFFECT_ROW_HEIGHT := 13.0
const BOOSTED_VALUE_COLOR := Color(1.0, 0.82, 0.15)

var card_data: CardData
var _visual_root: Control
var _bullet_art: TextureRect
var _hand_layer: Control
var _effect_icon: TextureRect
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

	_bullet_art = TextureRect.new()
	_bullet_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bullet_art.stretch_mode = TextureRect.STRETCH_KEEP
	_bullet_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual_root.add_child(_bullet_art)
	_set_bullet_texture(BULLET_TEXTURE)

	_effect_icon = TextureRect.new()
	_effect_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_effect_icon.stretch_mode = TextureRect.STRETCH_KEEP
	_effect_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual_root.add_child(_effect_icon)

	_effect_label = Label.new()
	_effect_label.position = EFFECT_LABEL_POSITION
	_effect_label.size = Vector2(18, 13)
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


func setup_card(
	data: CardData,
	interactive: bool = true,
	visual_mode: BulletVisualMode = BulletVisualMode.STANDARD,
	display_value: int = -1,
	boosted_value: bool = false
) -> void:
	card_data = data
	var shown_value := data.value if display_value < 0 else display_value
	var bullet_texture: Texture2D
	if visual_mode == BulletVisualMode.SHOP:
		bullet_texture = shop_bullet_texture_for_enchant(data.enchant)
	else:
		bullet_texture = bullet_texture_for_enchant(data.enchant)
	_set_bullet_texture(bullet_texture)
	_effect_label.add_theme_color_override(
		"font_color",
		BOOSTED_VALUE_COLOR if boosted_value else Color.WHITE
	)
	_set_effect_visual(
		effect_icon_texture(data.card_type),
		effect_text(data.card_type, shown_value),
		visual_mode
	)
	_render_hands(data.janken_hands)
	_hit_button.visible = interactive


func setup_enemy(turn: Dictionary) -> void:
	card_data = null
	_set_bullet_texture(bullet_texture_for_enchant(int(turn.get("enchant", CardData.Enchant.NONE))))
	var type_str := str(turn.get("type", "attack"))
	var base_value := int(turn.get("value", 0))
	var shown_value := int(turn.get("display_value", base_value))
	_effect_label.add_theme_color_override(
		"font_color",
		BOOSTED_VALUE_COLOR if bool(turn.get("boosted_value", false)) else Color.WHITE
	)
	_set_effect_visual(
		enemy_effect_icon_texture(type_str),
		enemy_effect_text(type_str, shown_value),
		BulletVisualMode.STANDARD
	)
	_render_hands(turn.get("display_hands", turn.get("hands", [])))
	_hit_button.visible = false


static func bullet_texture_for_enchant(enchant: int) -> Texture2D:
	match enchant:
		CardData.Enchant.B:
			return HEAVY_BULLET_TEXTURE
		CardData.Enchant.C:
			return AP_BULLET_TEXTURE
		CardData.Enchant.D:
			return SLUG_TEXTURE
		CardData.Enchant.E:
			return BUCKSHOT_TEXTURE
		CardData.Enchant.F:
			return SILVER_BULLET_TEXTURE
	return BULLET_TEXTURE


static func shop_bullet_texture_for_enchant(enchant: int) -> Texture2D:
	match enchant:
		CardData.Enchant.B:
			return SHOP_HEAVY_BULLET_TEXTURE
		CardData.Enchant.C:
			return SHOP_AP_BULLET_TEXTURE
		CardData.Enchant.D:
			return SHOP_SLUG_TEXTURE
		CardData.Enchant.E:
			return SHOP_BUCKSHOT_TEXTURE
		CardData.Enchant.F:
			return SHOP_SILVER_BULLET_TEXTURE
	return SHOP_BASE_BULLET_TEXTURE


func _set_bullet_texture(texture: Texture2D) -> void:
	if _bullet_art == null or texture == null:
		return
	var texture_size := texture.get_size()
	_bullet_art.position = Vector2(
		BULLET_POSITION.x + floor((BULLET_SIZE.x - texture_size.x) * 0.5),
		BULLET_POSITION.y + BULLET_SIZE.y - texture_size.y
	)
	_bullet_art.size = texture_size
	_bullet_art.texture = texture


func _set_effect_visual(
	icon_texture: Texture2D,
	text: String,
	visual_mode: BulletVisualMode
) -> void:
	var plain_label_position := EFFECT_LABEL_POSITION
	var value_label_position := EFFECT_VALUE_POSITION
	if visual_mode == BulletVisualMode.SHOP:
		plain_label_position = SHOP_EFFECT_LABEL_POSITION
		value_label_position = SHOP_EFFECT_VALUE_POSITION

	_effect_label.text = text
	if icon_texture == null:
		_effect_icon.visible = false
		_effect_label.position = plain_label_position
		return

	var icon_size := icon_texture.get_size()
	_effect_icon.visible = true
	_effect_icon.texture = icon_texture
	_effect_icon.size = icon_size
	_effect_icon.position = Vector2(
		EFFECT_ICON_RIGHT - icon_size.x,
		value_label_position.y + floor((EFFECT_ROW_HEIGHT - icon_size.y) * 0.5)
	)
	_effect_label.position = value_label_position


## 敵行動タイプ（文字列）→ 表示テキスト。
static func enemy_effect_text(type_str: String, value: int) -> String:
	match type_str:
		"skill":
			return str(value)
		"power":
			return str(value)
	return str(value)


static func effect_text(action_type: int, value: int) -> String:
	if effect_icon_texture(action_type) != null:
		return str(value)
	return _effect_text(action_type, value)


static func effect_icon_texture(action_type: int) -> Texture2D:
	match action_type:
		CardData.CardType.ATTACK:
			return SWORD_EFFECT_TEXTURE
		CardData.CardType.SKILL:
			return SHIELD_EFFECT_TEXTURE
		CardData.CardType.POWER:
			return HEALING_EFFECT_TEXTURE
	return null


static func enemy_effect_icon_texture(type_str: String) -> Texture2D:
	match type_str:
		"skill":
			return SHIELD_EFFECT_TEXTURE
		"attack":
			return SWORD_EFFECT_TEXTURE
		"power":
			return HEALING_EFFECT_TEXTURE
	return null


static func hand_texture(hand: int) -> Texture2D:
	match hand:
		-1:
			return QUESTION_HAND_TEXTURE
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
			return str(value)
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
	if _is_all_hands(hands):
		var icon_size := ALL_HANDS_TEXTURE.get_size()
		var icon_position := (
			Vector2(15, 30)
			+ ((Vector2(17, 17) - icon_size) * 0.5).round()
		)
		_add_hand_icon(ALL_HANDS_TEXTURE, icon_position, icon_size)
		return

	var positions: Array[Vector2] = []
	var icon_box_size := Vector2(17, 17)
	var regular_icon_size := Vector2(17, 17)
	if hands.size() == 1:
		positions.append(Vector2(15, 30))
	elif hands.size() == 2:
		positions.append(Vector2(7, 30))
		positions.append(Vector2(23, 30))
	else:
		# Three full-size hand icons are wider than the 32-pixel spacing
		# used by adjacent belt bullets. Keep all three visible in a compact,
		# centered row so their order remains readable without overlap.
		icon_box_size = Vector2(11, 17)
		regular_icon_size = Vector2(11, 11)
		positions.append(Vector2(9, 30))
		positions.append(Vector2(19, 30))
		positions.append(Vector2(29, 30))

	for index in range(min(hands.size(), positions.size())):
		var icon_texture := hand_texture(int(hands[index]))
		if icon_texture == null:
			continue
		var icon_size := regular_icon_size
		if int(hands[index]) == -1:
			icon_size = icon_texture.get_size().min(icon_box_size)
		var icon_position := (
			positions[index]
			+ (icon_box_size - icon_size) * 0.5
		)
		_add_hand_icon(icon_texture, icon_position, icon_size)


static func _is_all_hands(hands: Array) -> bool:
	return (
		hands.size() == 3
		and int(hands[0]) == CardData.Hand.ROCK
		and int(hands[1]) == CardData.Hand.SCISSORS
		and int(hands[2]) == CardData.Hand.PAPER
	)


func _add_hand_icon(
	icon_texture: Texture2D,
	icon_position: Vector2,
	icon_size: Vector2
) -> void:
	var icon := TextureRect.new()
	icon.position = icon_position
	icon.size = icon_size
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
