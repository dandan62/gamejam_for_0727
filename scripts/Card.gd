extends PanelContainer
class_name CardView

## CardData を受け取って見た目を組み立てる、手札・スロット・敵行動表示に共通で使うカードUI。

signal clicked(card: CardData)

var card_data: CardData
var _border: CardBorder

func setup(data: CardData) -> void:
	card_data = data
	%Art.texture = data.image
	%NameLabel.text = data.display_label()
	%TypeLabel.text = data.get_type_label()
	%HandsLabel.text = data.get_hand_icons()

	var prefix := "⚔"
	match data.card_type:
		CardData.CardType.SKILL: prefix = "🛡"
		CardData.CardType.POWER: prefix = "✚"
		CardData.CardType.CHARGE: prefix = "↑"
		CardData.CardType.SHIELD_BREAK: prefix = "破"
	%ValueLabel.text = "%s %d" % [prefix, data.value]

	# 背景と角丸のみ（枠色はオーバーレイで属性ごとに描画する）
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.12, 0.08)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 属性ごとに色分けした枠を描画
	var cols: Array[Color] = []
	for h in data.janken_hands:
		cols.append(CardData.hand_color(h))
	if _border == null:
		_border = CardBorder.new()
		_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_border)
	_border.set_colors(cols)

func set_dimmed(dimmed: bool) -> void:
	modulate.a = 0.35 if dimmed else 1.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(card_data)
