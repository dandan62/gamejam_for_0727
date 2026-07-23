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
}

enum Phase { PREP, SHOWDOWN }

# --- パネル ---
@onready var intro_panel: Control = %IntroPanel
@onready var intro_title: Label = %IntroTitle
@onready var intro_enemy_name: Label = %IntroEnemyName
@onready var start_battle_button: Button = %StartBattleButton
@onready var prep_panel: Control = %PrepPanel
@onready var showdown_panel: Control = %ShowdownPanel

# --- 準備フェーズ ---
@onready var timer_label: Label = %TimerLabel
@onready var timer_bar: ProgressBar = %TimerBar
@onready var forecast_row: HBoxContainer = %ForecastRow
@onready var hand_area: Control = %HandArea
@onready var slot_row: HBoxContainer = %SlotRow
@onready var confirm_button: Button = %ConfirmButton
@onready var prep_enemy_name: Label = %PrepEnemyName

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
	confirm_button.pressed.connect(_on_confirm_pressed)
	start_battle_button.pressed.connect(_on_start_battle_pressed)
	hand_area.resized.connect(_layout_hand)

	_show_intro()

## バトル開始前の「覚悟を決める」画面。押すまで準備フェーズは始まらない
func _show_intro() -> void:
	intro_panel.visible = true
	prep_panel.visible = false
	showdown_panel.visible = false
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
		_update_timer_display()
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

	GameManager.regenerate_enemy_upcoming()
	GameManager.prep_hand = GameManager.draw_cards(5)
	GameManager.slots = [null, null, null]
	confirmed = false

	prep_enemy_name.text = GameManager.current_enemy.enemy_name
	_render_forecast()
	_render_hand()
	_render_slots()

	time_left = GameManager.PREP_SECONDS
	prep_active = true
	_update_timer_display()

func _update_timer_display() -> void:
	# 残り秒数（切り上げ）を大きく表示
	var secs := int(ceil(time_left))
	timer_label.text = "残り %d 秒" % secs

	# プログレスバー
	timer_bar.max_value = GameManager.PREP_SECONDS
	timer_bar.value = time_left

	# 残り時間に応じて色を変える（緑→黄→赤）と、終盤は点滅させる
	var ratio := time_left / GameManager.PREP_SECONDS
	var col: Color
	if ratio > 0.5:
		col = Color(0.3, 0.85, 0.3)   # 緑
	elif ratio > 0.25:
		col = Color(0.95, 0.8, 0.2)   # 黄
	else:
		col = Color(0.9, 0.25, 0.2)   # 赤

	timer_label.add_theme_color_override("font_color", col)

	var bar_style := timer_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if bar_style:
		bar_style.bg_color = col

	# 残り3秒以下は文字を点滅させて注意を引く
	if time_left <= 3.0:
		timer_label.modulate.a = 0.4 + 0.6 * abs(sin(time_left * PI * 2.0))
	else:
		timer_label.modulate.a = 1.0

func _render_forecast() -> void:
	for c in forecast_row.get_children():
		c.queue_free()
	for i in range(GameManager.enemy_upcoming.size()):
		var turn: Dictionary = GameManager.enemy_upcoming[i]
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(120, 100)

		# カードと同じ背景＋角丸（枠色はじゃんけん属性で色分け）
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.12, 0.08)
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		box.add_theme_stylebox_override("panel", sb)

		var vbox := VBoxContainer.new()
		box.add_child(vbox)
		var title := Label.new()
		title.text = "ターン%d" % (i + 1)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(title)
		var type_str: String = {"attack": "攻撃", "skill": "スキル", "power": "パワー"}[turn.type]
		var type_label := Label.new()
		type_label.text = "%s (%d)" % [type_str, turn.value]
		type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(type_label)
		var hands_label := Label.new()
		hands_label.text = _hands_to_text(turn.hands)
		hands_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(hands_label)

		# じゃんけん属性を枠の色で表現（カードと同じ CardBorder を流用）
		var border := CardBorder.new()
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(border)
		var cols: Array[Color] = []
		for h in turn.hands:
			cols.append(CardData.hand_color(h))
		border.set_colors(cols)

		forecast_row.add_child(box)

func _hands_to_text(hands: Array) -> String:
	var parts: Array[String] = []
	for h in hands:
		match h:
			CardData.Hand.ROCK: parts.append("グー")
			CardData.Hand.PAPER: parts.append("パー")
			CardData.Hand.SCISSORS: parts.append("チョキ")
	return "・".join(parts)

func _render_hand() -> void:
	for c in hand_area.get_children():
		c.queue_free()
	for card in GameManager.prep_hand:
		var view: CardView = CARD_SCENE.instantiate()
		hand_area.add_child(view)
		view.setup(card)
		view.set_dimmed(GameManager.slots.has(card))
		view.clicked.connect(_on_hand_card_clicked)
	_layout_hand()

## 手札を扇状（円弧）に配置する。中央を基準に左右へ広げ、端ほど外側へ傾ける。
func _layout_hand() -> void:
	var views := hand_area.get_children()
	var n := views.size()
	if n == 0:
		return

	var card_w := 118.0
	var card_h := 158.0
	var area_w := hand_area.size.x
	if area_w <= 0.0:
		area_w = 1200.0
	var center_x := area_w * 0.5

	var step := 110.0                 # カード中心どうしの間隔（カード幅より狭く＝少し重なる）
	var spread := deg_to_rad(24.0)    # 手札全体の開き角
	var base_y := 2.0
	var total := step * float(n - 1)

	for i in range(n):
		var view: Control = views[i]
		view.pivot_offset = Vector2(card_w * 0.5, card_h)   # 下端中央を軸に回転
		var centered := 0.0
		if n > 1:
			centered = float(i) / float(n - 1) - 0.5        # -0.5 .. 0.5
		var angle := centered * spread
		var anchor_x := center_x + centered * total
		var dip := pow(centered * 2.0, 2.0) * 20.0          # 端ほど少し下げて弧を作る
		var anchor_y := base_y + card_h + dip
		view.position = Vector2(anchor_x, anchor_y) - Vector2(card_w * 0.5, card_h)
		view.rotation = angle

func _render_slots() -> void:
	for c in slot_row.get_children():
		c.queue_free()
	for i in range(GameManager.slots.size()):
		var card: CardData = GameManager.slots[i]
		if card:
			var view: CardView = CARD_SCENE.instantiate()
			slot_row.add_child(view)
			view.setup(card)
			view.clicked.connect(func(_c): _on_slot_clicked(i))
		else:
			var placeholder := PanelContainer.new()
			placeholder.custom_minimum_size = Vector2(140, 190)
			var label := Label.new()
			label.text = "%d番\n(空き)" % (i + 1)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			placeholder.add_child(label)
			slot_row.add_child(placeholder)

func _on_hand_card_clicked(card: CardData) -> void:
	if GameManager.slots.has(card):
		return
	var empty_index: int = GameManager.slots.find(null)
	if empty_index == -1:
		return
	GameManager.slots[empty_index] = card
	_render_hand()
	_render_slots()

func _on_slot_clicked(index: int) -> void:
	GameManager.slots[index] = null
	_render_hand()
	_render_slots()

func _on_confirm_pressed() -> void:
	prep_active = false
	_confirm_set()

func _confirm_set() -> void:
	if confirmed:
		return
	confirmed = true
	prep_active = false
	timer_label.modulate.a = 1.0
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
		_spawn_player_effect(player_card, enemy_before)
	if result.enemy_acts:
		var player_before := GameManager.hp
		log_lines.append(GameManager.apply_enemy_turn(enemy_turn))
		_spawn_enemy_effect(enemy_turn, player_before)

	log_label.text = "\n".join(log_lines)

	# ダメージ/回復のバーアニメを見せる間
	await get_tree().create_timer(0.5).timeout

# ---- ダメージ・回復のフローティング数字演出 ----
func _spawn_player_effect(card: CardData, enemy_before: int) -> void:
	match card.card_type:
		CardData.CardType.ATTACK:
			var dmg := enemy_before - GameManager.enemy_hp
			if dmg > 0:
				# 敵がダメージ → 敵HPバーの横に表示
				_float_beside(enemy_hp_bar, "-%d" % dmg, Color(1.0, 0.3, 0.25))
		CardData.CardType.SKILL:
			_float_text(player_slot, "+%d" % card.value, Color(0.4, 0.7, 1.0))
		CardData.CardType.POWER:
			_float_text(player_slot, "+%d" % card.value, Color(0.4, 0.9, 0.4))

func _spawn_enemy_effect(turn: Dictionary, player_before: int) -> void:
	match turn.type:
		"attack":
			var dmg := player_before - GameManager.hp
			if dmg > 0:
				# 自分がダメージ → 自分HPバーの横に表示
				_float_beside(player_hp_bar, "-%d" % dmg, Color(1.0, 0.3, 0.25))
		"skill":
			_float_text(enemy_slot, "+%d" % turn.value, Color(0.4, 0.7, 1.0))
		"power":
			_float_text(enemy_slot, "+%d" % turn.value, Color(0.4, 0.9, 0.4))

## HPバーの右横にダメージ/効果数字を出してフェードさせる
func _float_beside(bar: Control, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", color)
	lbl.z_index = 20
	showdown_panel.add_child(lbl)
	lbl.global_position = bar.global_position + Vector2(bar.size.x + 8.0, -6.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 40.0, 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(lbl.queue_free)

func _float_text(anchor: Control, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", color)
	lbl.z_index = 20
	showdown_panel.add_child(lbl)
	lbl.global_position = anchor.global_position + Vector2(anchor.size.x * 0.5 - 20.0, 20.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 70.0, 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(lbl.queue_free)

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
