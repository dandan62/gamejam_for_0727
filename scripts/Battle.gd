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

const PERSISTENT_PRECOMBAT_MUSIC_NAME := "PersistentPrecombatMusic"

# --- パネル ---
@onready var intro_panel: Control = %IntroPanel
@onready var before_fight_ui: BeforeFightUI = $IntroPanel/BeforeFightViewportContainer/BeforeFightViewport/BeforeFightUI
@onready var before_fight_enemy_info: Label = %BeforeFightEnemyInfo
@onready var prep_panel: Control = %PrepPanel
@onready var showdown_panel: Control = %ShowdownPanel

# --- 準備フェーズ ---
@onready var prep_ui: PrepSelectionUI = $PrepPanel/PrepViewportContainer/PrepViewport/PrepSelectionUI
@onready var duel_ui: DuelPhaseUI = $ShowdownPanel/ShowdownViewportContainer/ShowdownViewport/DuelPhaseUI
@onready var duel_text_overlay: DuelTextOverlay = %DuelTextOverlay
@onready var prep_insert_audio: AudioStreamPlayer = %PrepInsertAudio
@onready var intro_gunshot_audio: AudioStreamPlayer = %IntroGunshotAudio
@onready var precombat_music: AudioStreamPlayer = %PrecombatMusic
@onready var combat_music: AudioStreamPlayer = %CombatMusic

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
var prep_duration := GameManager.PREP_SECONDS
var prep_active := false
var confirmed := false

var turn_index := 0
var battle_over := false
var _enemy_hp_display: float = 0.0
var _player_hp_display: float = 0.0

func _ready() -> void:
	var precombat_stream := precombat_music.stream as AudioStreamMP3
	if precombat_stream != null:
		precombat_stream.loop = true
	var combat_stream := combat_music.stream as AudioStreamMP3
	if combat_stream != null:
		combat_stream.loop = true
	prep_ui.confirm_pressed.connect(_on_confirm_pressed)
	prep_ui.hand_card_clicked.connect(_on_hand_card_clicked)
	prep_ui.slot_clicked.connect(_on_slot_clicked)
	before_fight_ui.ready_pressed.connect(_on_start_battle_pressed)
	before_fight_ui.insert_sound_requested.connect(prep_insert_audio.play)
	before_fight_ui.gunshot_requested.connect(intro_gunshot_audio.play)
	before_fight_ui.deck_visibility_changed.connect(
		_on_before_fight_deck_visibility_changed
	)

	_show_intro()

## バトル開始前の「覚悟を決める」画面。押すまで準備フェーズは始まらない
func _show_intro() -> void:
	intro_panel.visible = true
	prep_panel.visible = false
	showdown_panel.visible = false
	prep_active = false
	var persistent_music := _get_persistent_precombat_music()
	if persistent_music == null or not persistent_music.playing:
		precombat_music.play()
	before_fight_enemy_info.text = _enemy_description(GameManager.current_enemy)
	before_fight_enemy_info.visible = true
	before_fight_ui.configure(
		GameManager.hp,
		GameManager.max_hp,
		GameManager.player_shield,
		GameManager.battle_index,
		GameManager.TOTAL_BATTLES
	)


func _enemy_description(enemy: EnemyData) -> String:
	if enemy == null:
		return "Unknown gunman. Stay alert."
	if not enemy.description.is_empty():
		return enemy.description
	return "%s: No further information." % enemy.enemy_name


func _on_before_fight_deck_visibility_changed(is_visible: bool) -> void:
	before_fight_enemy_info.visible = not is_visible


func _on_start_battle_pressed() -> void:
	precombat_music.stop()
	var persistent_music := _get_persistent_precombat_music()
	if persistent_music != null:
		persistent_music.stop()
		persistent_music.queue_free()
	combat_music.play()
	intro_panel.visible = false
	_start_prep()


func _get_persistent_precombat_music() -> AudioStreamPlayer:
	return get_tree().root.get_node_or_null(
		PERSISTENT_PRECOMBAT_MUSIC_NAME
	) as AudioStreamPlayer

func _process(delta: float) -> void:
	# 準備フェーズのカウントダウン
	if prep_active:
		time_left = max(0.0, time_left - delta)
		prep_ui.update_timer(time_left, prep_duration)
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
	duel_text_overlay.clear_result()

	GameManager.regenerate_enemy_upcoming()
	GameManager.prep_hand = GameManager.draw_cards(GameManager.prep_hand_size())
	GameManager.slots = [null, null, null]
	confirmed = false

	prep_duration = GameManager.current_prep_seconds()
	time_left = prep_duration
	prep_active = true
	prep_ui.configure(
		GameManager.prep_hand,
		GameManager.slots,
		GameManager.enemy_upcoming,
		GameManager.hp,
		GameManager.max_hp,
		GameManager.player_shield,
		prep_duration,
		GameManager.player_damage_buff,
		GameManager.player_charge
	)

func _on_hand_card_clicked(card: CardData) -> void:
	if GameManager.slots.has(card):
		return
	var empty_index: int = GameManager.slots.find(null)
	if empty_index == -1:
		return
	GameManager.slots[empty_index] = card
	prep_ui.refresh_selection(GameManager.prep_hand, GameManager.slots)
	prep_insert_audio.play()

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
	duel_text_overlay.clear_result()

	battle_over = false
	show_enemy_name.text = GameManager.current_enemy.enemy_name
	_enemy_hp_display = float(GameManager.enemy_hp)
	enemy_hp_bar.max_value = GameManager.enemy_max_hp
	enemy_hp_bar.value = _enemy_hp_display
	_player_hp_display = float(GameManager.hp)
	player_hp_bar.max_value = GameManager.max_hp
	player_hp_bar.value = _player_hp_display
	log_label.text = ""
	duel_ui.begin_showdown(
		GameManager.hp,
		GameManager.max_hp,
		GameManager.player_shield,
		GameManager.enemy_hp,
		GameManager.enemy_max_hp,
		GameManager.enemy_shield
	)
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
	var player_card: CardData = GameManager.slots[turn_index]
	var enemy_turn: Dictionary = GameManager.enemy_upcoming[turn_index]
	var player_hands: Array = player_card.janken_hands if player_card else []
	var result: Dictionary = GameManager.resolve_hands(player_hands, enemy_turn.hands)

	duel_text_overlay.clear_result()
	var player_display_value := -1
	var player_value_boosted := false
	if player_card != null and player_card.card_type == CardData.CardType.ATTACK:
		player_display_value = GameManager.preview_player_attack_damage(player_card, turn_index)
		player_value_boosted = player_display_value > player_card.value
	elif player_card != null and player_card.card_type == CardData.CardType.SKILL:
		player_display_value = player_card.value + GameManager.player_block_bonus()
		player_value_boosted = player_display_value > player_card.value
	duel_ui.present_fight(
		player_card,
		enemy_turn,
		player_display_value,
		player_value_boosted
	)
	await get_tree().create_timer(0.25).timeout
	await duel_ui.play_shot_cycle()

	var effect_parts: Array[String] = []
	if result.player_acts and player_card:
		effect_parts.append(_apply_and_describe_player_card(player_card))
	if result.enemy_acts:
		effect_parts.append(_apply_and_describe_enemy_turn(enemy_turn))
	GameManager.record_enemy_shot()

	effect_parts = effect_parts.filter(func(text: String) -> bool: return not text.is_empty())
	var effect_text := " / ".join(effect_parts)
	if effect_text.is_empty():
		effect_text = "NO EFFECT"

	var round_state: StringName
	if result.player_acts and result.enemy_acts:
		round_state = &"draw"
	elif result.player_acts:
		round_state = &"won"
	else:
		round_state = &"lost"

	duel_ui.show_result(round_state)
	duel_text_overlay.show_result(round_state, effect_text)
	duel_ui.set_vitals(
		GameManager.hp,
		GameManager.max_hp,
		GameManager.player_shield,
		GameManager.enemy_hp,
		GameManager.enemy_max_hp,
		GameManager.enemy_shield
	)
	await get_tree().create_timer(0.7).timeout


func _apply_and_describe_player_card(card: CardData) -> String:
	var enemy_hp_before := GameManager.enemy_hp
	var enemy_shield_before := GameManager.enemy_shield
	var player_hp_before := GameManager.hp
	var player_shield_before := GameManager.player_shield
	var player_charge_before := GameManager.player_charge

	GameManager.apply_player_card(card, turn_index)

	match card.card_type:
		CardData.CardType.ATTACK:
			return _damage_summary(
				"DEALT",
				enemy_hp_before - GameManager.enemy_hp,
				enemy_shield_before - GameManager.enemy_shield
			)
		CardData.CardType.SKILL:
			return "GAINED %d SHIELD" % (GameManager.player_shield - player_shield_before)
		CardData.CardType.POWER:
			var healed := GameManager.hp - player_hp_before
			return "HEALED %d HP" % healed if healed > 0 else "HEALTH FULL"
		CardData.CardType.CHARGE:
			return "CHARGED +%d" % (GameManager.player_charge - player_charge_before)
		CardData.CardType.SHIELD_BREAK:
			return "BROKE %d SHIELD" % (enemy_shield_before - GameManager.enemy_shield)
	return ""


func _apply_and_describe_enemy_turn(turn: Dictionary) -> String:
	var player_hp_before := GameManager.hp
	var player_shield_before := GameManager.player_shield
	var enemy_hp_before := GameManager.enemy_hp
	var enemy_shield_before := GameManager.enemy_shield
	GameManager.apply_enemy_turn(turn, turn_index)
	if GameManager.last_enemy_attack_dodged:
		return "Dodged!"

	match str(turn.get("type", "")):
		"attack":
			return _damage_summary(
				"TOOK",
				player_hp_before - GameManager.hp,
				player_shield_before - GameManager.player_shield
			)
		"skill":
			return "ENEMY +%d SHIELD" % (GameManager.enemy_shield - enemy_shield_before)
		"power":
			var healed := GameManager.enemy_hp - enemy_hp_before
			return "ENEMY HEALED %d" % healed if healed > 0 else "ENEMY HEALTH FULL"
	return ""


func _damage_summary(verb: String, hp_damage: int, shield_damage: int) -> String:
	var parts: Array[String] = []
	if hp_damage > 0:
		parts.append("%s %d DAMAGE" % [verb, hp_damage])
	if shield_damage > 0:
		parts.append("BROKE %d SHIELD" % shield_damage)
	if parts.is_empty():
		return "NO DAMAGE"
	return " / ".join(parts)


func _play_turn_legacy() -> void:
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
		log_lines.append(GameManager.apply_player_card(player_card, turn_index))
		BattleFx.spawn_player_effect(showdown_panel, enemy_hp_bar, player_slot, player_card, enemy_before)
	if result.enemy_acts:
		var player_before := GameManager.hp
		log_lines.append(GameManager.apply_enemy_turn(enemy_turn, turn_index))
		BattleFx.spawn_enemy_effect(showdown_panel, player_hp_bar, enemy_slot, enemy_turn, player_before)
	GameManager.record_enemy_shot()

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

	var gold_reward := GameManager.roll_battle_gold_reward(
		GameManager.current_enemy.is_boss
	)
	GameManager.gold += gold_reward

	if GameManager.battle_index >= GameManager.TOTAL_BATTLES:
		GameManager.game_over_reason = "win"
		get_tree().change_scene_to_file("res://scenes/EndScreen.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/Event.tscn")
