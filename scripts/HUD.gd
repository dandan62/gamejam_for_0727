extends HBoxContainer

const CARD_SCENE := preload("res://scenes/Card.tscn")

@onready var battle_label: Label = %BattleLabel
@onready var hp_bar: ProgressBar = %HPBar
@onready var shield_bar: ProgressBar = %ShieldBar
@onready var hp_text: Label = %HPText
@onready var gold_label: Label = %GoldLabel

@onready var deck_button: Button = %DeckButton
@onready var deck_overlay: Control = %DeckOverlay
@onready var deck_title: Label = %DeckTitle
@onready var close_button: Button = %CloseButton
@onready var card_grid: HFlowContainer = %CardGrid
@onready var dim: Panel = %Dim

var _hp_display: float = 0.0

func _ready() -> void:
	_hp_display = float(GameManager.hp)
	hp_bar.max_value = GameManager.max_hp
	hp_bar.value = _hp_display

	deck_button.pressed.connect(_open_deck)
	close_button.pressed.connect(_close_deck)
	dim.gui_input.connect(_on_dim_input)
	deck_overlay.visible = false

func _process(delta: float) -> void:
	battle_label.text = "バトル %d / %d" % [GameManager.battle_index, GameManager.TOTAL_BATTLES]
	gold_label.text = "Gold: %d" % GameManager.gold
	if GameManager.player_shield > 0:
		hp_text.text = "%d / %d  [盾%d]" % [GameManager.hp, GameManager.max_hp, GameManager.player_shield]
	else:
		hp_text.text = "%d / %d" % [GameManager.hp, GameManager.max_hp]

	# HPバーを目標値へなめらかに追従させる（ダメージ/回復が滑らかに反映される）
	var t: float = clamp(delta * 8.0, 0.0, 1.0)
	hp_bar.max_value = GameManager.max_hp
	_hp_display = lerp(_hp_display, float(GameManager.hp), t)
	if abs(_hp_display - GameManager.hp) < 0.5:
		_hp_display = GameManager.hp
	hp_bar.value = _hp_display

	# ガード（シールド）を青いバーで表示
	shield_bar.max_value = GameManager.max_hp
	shield_bar.value = GameManager.player_shield

# ---------------- 山札ビュー ----------------
func _open_deck() -> void:
	for c in card_grid.get_children():
		c.queue_free()

	var deck := GameManager.get_full_deck()
	# 見やすいように種別→名前順で並べ替え
	deck.sort_custom(func(a, b):
		if a.card_type != b.card_type:
			return a.card_type < b.card_type
		return a.card_name < b.card_name)

	deck_title.text = "山札 （%d枚）" % deck.size()
	for card in deck:
		var v: CardView = CARD_SCENE.instantiate()
		card_grid.add_child(v)
		v.setup(card)

	deck_overlay.visible = true

func _close_deck() -> void:
	deck_overlay.visible = false

func _on_dim_input(event: InputEvent) -> void:
	# 背景（カード以外）をクリックしたら閉じる
	if event is InputEventMouseButton and event.pressed:
		_close_deck()
