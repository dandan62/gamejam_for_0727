extends Control

## 1回のバトル全体を管理するシーン。
## 内部に「準備フェーズ」パネルと「勝負フェーズ」パネルを持ち、
## 表示を切り替えることで1シーン内で完結させる。
## （GameManager.start_next_battle() は、このシーンに入る前に呼ばれている前提）

const CARD_SCENE := preload("res://scenes/Card.tscn")
const TYPE_MAP := {
	"attack": CardData.CardType.ATTACK,
	"skill": CardData.CardType.SKILL,
	"power": CardData.CardType.POWER,
	"charge": CardData.CardType.POWER,
	"pierce": CardData.CardType.ATTACK,
}

enum Phase { PREP, SHOWDOWN }

# --- パネル ---
@onready var intro_panel: Control = %IntroPanel
@onready var intro_title: Label = %IntroTitle
@onready var intro_enemy_name: Label = %IntroEnemyName
@onready var start_battle_button: Button = %StartBattleButton
@onready var prep_panel: Control = %PrepPanel
@onready var showdown_panel: Control = %ShowdownPanel
@onready var hud: Control = $HUD

# --- 準備フェーズ ---
@onready var prep_ui: PrepSelectionUI = $PrepPanel/PrepViewportContainer/PrepViewport/PrepSelectionUI

# --- 勝負フェーズ ---
@onready var show_enemy_name: Label = %ShowEnemyName
@onready var player_slot: Control = %PlayerCardSlot
@onready var enemy_slot: Control = %EnemyCardSlot
@onready var result_label: Label = %ResultLabel
@onready var log_label: Label = %LogLabel
@onready var enemy_hp_bar: ProgressBar = %EnemyHPBar
@onready var enemy_hp_text: Label = %EnemyHPText
@onready var enemy_shield_bar: ProgressBar = %EnemyShieldBar
@onready var player_hp_bar: ProgressBar = %PlayerHPBar
@onready var player_hp_text: Label = %PlayerHPText
@onready var player_shield_bar: ProgressBar = %PlayerShieldBar

var time_left: float
var prep_active := false
var confirmed := false

var turn_index := 0
var battle_over := false
var _enemy_hp_display: float = 0.0
var _player_hp_display: float = 0.0

func _ready() -> void:
	prep_ui.confirm_pressed.connect(_on_confirm_pressed)
	prep_ui.hand_card_clicked.connect(_on_hand_card_clicked)
	prep_ui.slot_clicked.connect(_on_slot_clicked)
	start_battle_button.pressed.connect(_on_start_battle_pressed)

	_show_intro()

## バトル開始前の「覚悟を決める」画面。押すまで準備フェーズは始まらない
func _show_intro() -> void:
	intro_panel.visible = true
	prep_panel.visible = false
	showdown_panel.visible = false
	hud.visible = true
	prep_active = false

	if GameManager.current_enemy.is_boss:
		intro_title.text = "ボス戦！"
	else:
		intro_title.text = "バトル開始"
	intro_enemy_name.text = "%s との対決" % GameManager.current_enemy.enemy_name

func _on_start_battle_pressed() -> void:
	intro_panel.visible = false
	_start_prep()

func _process(delta: float) -> void:
	# 準備フェーズのカウントダウン
	if prep_active:
		time_left = max(0.0, time_left - delta)
		prep_ui.update_timer(time_left, GameManager.PREP_SECONDS)
		if time_left <= 0.0:
			prep_active = false
			_confirm_set()

	# 勝負フェーズ：両者のHPバーを目標値へなめらかに追従
	if showdown_panel.visible:
		var t: float = clamp(delta * 8.0, 0.0, 1.0)

		enemy_hp_bar.max_value = GameManager.enemy_max_hp
		_enemy_hp_display = lerp(_enemy_hp_display, float(GameManager.enemy_hp), t)
		if abs(_enemy_hp_display - GameManager.enemy_hp) < 0.5:
			_enemy_hp_display = GameManager.enemy_hp
		enemy_hp_bar.value = _enemy_hp_display
		enemy_shield_bar.max_value = GameManager.enemy_max_hp
		enemy_shield_bar.value = GameManager.enemy_shield
		enemy_hp_text.text = _hp_text(GameManager.enemy_hp, GameManager.enemy_max_hp, GameManager.enemy_shield)

		player_hp_bar.max_value = GameManager.max_hp
		_player_hp_display = lerp(_player_hp_display, float(GameManager.hp), t)
		if abs(_player_hp_display - GameManager.hp) < 0.5:
			_player_hp_display = GameManager.hp
		player_hp_bar.value = _player_hp_display
		player_shield_bar.max_value = GameManager.max_hp
		player_shield_bar.value = GameManager.player_shield
		player_hp_text.text = _hp_text(GameManager.hp, GameManager.max_hp, GameManager.player_shield)

func _hp_text(hp: int, maxhp: int, shield: int) -> String:
	if shield > 0:
		return "%d / %d  [盾%d]" % [hp, maxhp, shield]
	return "%d / %d" % [hp, maxhp]

# =====================================================================
# 準備フェーズ
# =====================================================================
func _start_prep() -> void:
	prep_panel.visible = true
	showdown_panel.visible = false
	hud.visible = false

	GameManager.regenerate_enemy_upcoming()
	GameManager.prep_hand = GameManager.draw_cards(5)
	GameManager.slots = [null, null, null]
	confirmed = false

	time_left = GameManager.PREP_SECONDS
	prep_active = true
	prep_ui.configure(
		GameManager.prep_hand,
		GameManager.slots,
		GameManager.enemy_upcoming,
		GameManager.hp,
		GameManager.max_hp,
		GameManager.PREP_SECONDS
	)

func _on_hand_card_clicked(card: CardData) -> void:
	if GameManager.slots.has(card):
		return
	var empty_index: int = GameManager.slots.find(null)
	if empty_index == -1:
		return
	GameManager.slots[empty_index] = card
	prep_ui.refresh_selection(GameManager.prep_hand, GameManager.slots)

func _on_slot_clicked(index: int) -> void:
	GameManager.slots[index] = null
	prep_ui.refresh_selection(GameManager.prep_hand, GameManager.slots)

func _on_confirm_pressed() -> void:
	prep_active = false
	_confirm_set()

func _confirm_set() -> void:
	if confirmed:
		return
	confirmed = true
	prep_active = false
	for c in GameManager.prep_hand:
		if not GameManager.slots.has(c):
			GameManager.discard_pile.append(c)
	for c in GameManager.slots:
		if c:
			GameManager.discard_pile.append(c)
	_start_showdown()

# =====================================================================
# 勝負フェーズ
# =====================================================================
func _start_showdown() -> void:
	prep_panel.visible = false
	showdown_panel.visible = true
	hud.visible = true

	battle_over = false
	show_enemy_name.text = GameManager.current_enemy.enemy_name
	_enemy_hp_display = float(GameManager.enemy_hp)
	enemy_hp_bar.max_value = GameManager.enemy_max_hp
	enemy_hp_bar.value = _enemy_hp_display
	_player_hp_display = float(GameManager.hp)
	player_hp_bar.max_value = GameManager.max_hp
	player_hp_bar.value = _player_hp_display
	log_label.text = ""
	_auto_play()

## 3ターンを自動で順に進行させる（クリック不要）
func _auto_play() -> void:
	for i in range(3):
		turn_index = i
		await _play_turn()
		if GameManager.enemy_hp <= 0 or GameManager.hp <= 0:
			await get_tree().create_timer(0.9).timeout
			_end_battle()
			return
		await get_tree().create_timer(0.7).timeout
	# 3ターン終了・両者生存 → 次の準備フェーズへ
	await get_tree().create_timer(0.3).timeout
	_start_prep()

func _play_turn() -> void:
	for c in player_slot.get_children():
		c.queue_free()
	for c in enemy_slot.get_children():
		c.queue_free()

	var player_card: CardData = GameManager.slots[turn_index]
	var enemy_turn: Dictionary = GameManager.enemy_upcoming[turn_index]

	if player_card:
		var pv: CardView = CARD_SCENE.instantiate()
		player_slot.add_child(pv)
		pv.setup(player_card)
	else:
		var lbl := Label.new()
		lbl.text = "カード無し"
		player_slot.add_child(lbl)

	var ev: CardView = CARD_SCENE.instantiate()
	enemy_slot.add_child(ev)
	var temp := CardData.new()
	temp.card_name = enemy_turn.name
	temp.card_type = TYPE_MAP[enemy_turn.type]
	temp.value = enemy_turn.value
	temp.janken_hands.assign(enemy_turn.hands)
	ev.setup(temp)

	var player_hands: Array = player_card.janken_hands if player_card else []
	var result: Dictionary = GameManager.resolve_hands(player_hands, enemy_turn.hands)

	var result_text: String
	if result.player_acts and result.enemy_acts:
		result_text = "あいこ！ 両者行動"
	elif result.player_acts:
		result_text = "あなたの勝ち！"
	elif result.enemy_acts:
		result_text = "敵の勝ち！"
	else:
		result_text = "両者不発"
	result_label.text = result_text

	# 手を見せる間（ここで勝敗の相性を確認できる）
	await get_tree().create_timer(0.6).timeout

	var log_lines: Array[String] = []
	log_lines.append("ターン%d: %s" % [turn_index + 1, result_text])

	if result.player_acts and player_card:
		var enemy_before := GameManager.enemy_hp
		log_lines.append(GameManager.apply_player_card(player_card))
		BattleFx.spawn_player_effect(showdown_panel, enemy_hp_bar, player_slot, player_card, enemy_before)
	if result.enemy_acts:
		var player_before := GameManager.hp
		log_lines.append(GameManager.apply_enemy_turn(enemy_turn))
		BattleFx.spawn_enemy_effect(showdown_panel, player_hp_bar, enemy_slot, enemy_turn, player_before)

	log_label.text = "\n".join(log_lines)

	# ダメージ/回復のバーアニメを見せる間
	await get_tree().create_timer(0.5).timeout

func _end_battle() -> void:
	# ガードはバトル限りのリソース。次の画面へ持ち越さない
	GameManager.player_shield = 0
	GameManager.enemy_shield = 0

	if GameManager.hp <= 0:
		GameManager.game_over_reason = "lose"
		get_tree().change_scene_to_file("res://scenes/EndScreen.tscn")
		return

	var gold_reward := 40 if GameManager.current_enemy.is_boss else 15 + randi() % 10
	GameManager.gold += gold_reward

	if GameManager.battle_index >= GameManager.TOTAL_BATTLES:
		GameManager.game_over_reason = "win"
		get_tree().change_scene_to_file("res://scenes/EndScreen.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/Event.tscn")
