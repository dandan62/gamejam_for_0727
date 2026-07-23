extends Control

## カード売り場。4枚のカードを価格付きで陳列し、一覧から購入できる。

const CARD_SCENE := preload("res://scenes/Card.tscn")
const STOCK_COUNT := 4

@onready var shop_row: HBoxContainer = %ShopRow
@onready var info_label: Label = %InfoLabel
@onready var leave_button: Button = %LeaveButton

# 各商品: { "card": CardData, "price": int, "sold": bool }
var stock: Array = []

func _ready() -> void:
	_build_stock()
	_render()
	leave_button.pressed.connect(_on_leave)

func _build_stock() -> void:
	var pool := GameManager.all_cards.duplicate()
	pool.shuffle()
	var n: int = min(STOCK_COUNT, pool.size())
	for i in range(n):
		var card: CardData = pool[i]
		stock.append({"card": card, "price": _price_for(card), "sold": false})

func _price_for(card: CardData) -> int:
	match card.rarity:
		CardData.Rarity.COMMON: return 20
		CardData.Rarity.UNCOMMON: return 40
		CardData.Rarity.RARE: return 65
	return 25

func _render() -> void:
	info_label.text = "欲しいカードを購入しよう（所持金 %dG）" % GameManager.gold

	for c in shop_row.get_children():
		c.queue_free()

	for item in stock:
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 6)

		var view: CardView = CARD_SCENE.instantiate()
		col.add_child(view)
		view.setup(item.card)

		var price := Label.new()
		price.text = "%d G" % item.price
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(price)

		var buy := Button.new()
		if item.sold:
			buy.text = "売切"
			buy.disabled = true
		else:
			buy.text = "購入"
			buy.disabled = GameManager.gold < item.price
			buy.pressed.connect(_on_buy.bind(item))
		col.add_child(buy)

		shop_row.add_child(col)

func _on_buy(item: Dictionary) -> void:
	if item.sold or GameManager.gold < item.price:
		return
	GameManager.gold -= item.price
	# 共有参照を避けるため複製してデッキ（捨札）へ追加
	GameManager.discard_pile.append(item.card.duplicate())
	item.sold = true
	_render()

func _on_leave() -> void:
	GameManager.start_next_battle()
	get_tree().change_scene_to_file("res://scenes/Battle.tscn")
