extends Node

## ゲーム全体の状態とロジックを管理するオートロード（シングルトン）。
## res://resources/cards, resources/events, resources/enemies 以下の
## .tres ファイルを起動時に自動スキャンして読み込みます。
## → 新しいカード/イベント/敵はスクリプトを触らずフォルダに置くだけで反映されます。

const TOTAL_BATTLES := 21
const BOSS_INTERVAL := 7
const PREP_SECONDS := 7.0

const CARDS_DIR := "res://resources/cards"
const EVENTS_DIR := "res://resources/events"
const ENEMIES_DIR := "res://resources/enemies"
const ENEMY_ACTIONS_DIR := "res://resources/enemy_actions"
const BUCKLER_RELIC_ID := &"buckler"
const HORSESHOE_RELIC_ID := &"horseshoe"

var all_cards: Array[CardData] = []
var all_events: Array[EventData] = []
var all_enemies: Array[EnemyData] = []
var all_enemy_actions: Array[EnemyActionData] = []

## カード番号(id) → CardData テンプレート の対応表。番号でカードを引くのに使う。
var cards_by_id: Dictionary = {}

## 敵行動カード番号(id) → EnemyActionData の対応表。敵の deck_ids 解決に使う。
var enemy_actions_by_id: Dictionary = {}

## 主人公の初期(初手)デッキ。カード番号(id)を並べて指定する。ここを編集すればOK。
## 同じ番号を複数入れるとその枚数だけデッキに入る。空にすると全カード1枚ずつになる。
##
## 【カード番号の対応】

var starter_deck_ids: Array[int] = [
	1, 2, 3, 4, 5, 6, 7, 8   
]

# --- プレイヤー状態 ---
var hp: int = 50
var max_hp: int = 50
var gold: int = 20
var battle_index: int = 0

var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var owned_relic_ids: Array[StringName] = []

# --- バトル中の状態 ---
var current_enemy: EnemyData
var enemy_hp: int
var enemy_max_hp: int
var player_shield: int = 0
var enemy_shield: int = 0
var player_charge: int = 0  # プレイヤーの「溜め」。次の攻撃に加算される
var player_damage_buff: int = 0  # バフ(D)。戦闘中、自分の攻撃ダメージに加算
var enemy_damage_debuff: int = 0  # デバフ(E)。戦闘中、敵の攻撃ダメージから減算
var enemy_attack_growth: int = 0

var prep_hand: Array[CardData] = []
var slots: Array = [null, null, null]
var enemy_upcoming: Array = [] # 3要素: {type, value, hands, name}
var game_over_reason: String = "" # "win" / "lose"

func _ready() -> void:
	# 読み込みロジックは ResourceLibrary に分離
	all_cards.assign(ResourceLibrary.load_dir(CARDS_DIR))
	all_events.assign(ResourceLibrary.load_dir(EVENTS_DIR))
	all_enemies.assign(ResourceLibrary.load_dir(ENEMIES_DIR))
	all_enemy_actions.assign(ResourceLibrary.load_dir(ENEMY_ACTIONS_DIR))
	_build_card_index()
	_build_enemy_action_index()

## カード番号(id) → テンプレート の対応表を作る。重複IDは警告する。
func _build_card_index() -> void:
	cards_by_id.clear()
	for card in all_cards:
		card.rebuild()  # 構造フィールド式カードは card_type/value を自動生成
		if card.id <= 0:
			push_warning("カードに id が未設定です: %s" % card.card_name)
			continue
		if cards_by_id.has(card.id):
			push_warning("カード id が重複しています: %d (%s)" % [card.id, card.card_name])
		cards_by_id[card.id] = card

## 敵行動カード番号(id) → EnemyActionData の対応表を作る。重複IDは警告する。
func _build_enemy_action_index() -> void:
	enemy_actions_by_id.clear()
	for action in all_enemy_actions:
		if action.id <= 0:
			push_warning("敵行動カードに id が未設定です: %s" % action.action_name)
			continue
		if enemy_actions_by_id.has(action.id):
			push_warning("敵行動カード id が重複しています: %d (%s)" % [action.id, action.action_name])
		enemy_actions_by_id[action.id] = action

## 番号(id)からカードの新しいインスタンス（複製）を取得する。無ければ null。
## ※ 複製を返すのは、手札での同一参照バグ（セット済み判定が両方に効く）を避けるため。
func card_by_id(id: int) -> CardData:
	var template: CardData = cards_by_id.get(id)
	if template == null:
		return null
	return template.duplicate()

## 番号(id)から敵行動カードを取得する（テンプレート参照。敵側は変更しないので複製不要）。
func enemy_action_by_id(id: int) -> EnemyActionData:
	return enemy_actions_by_id.get(id)

## 敵の実効デッキを解決する。deck_ids があれば番号から引き、無ければ inline の deck を使う。
func resolve_enemy_deck(enemy: EnemyData) -> Array:
	if enemy == null:
		return []
	if not enemy.deck_ids.is_empty():
		var result: Array = []
		for id in enemy.deck_ids:
			var action := enemy_action_by_id(id)
			if action != null:
				result.append(action)
			else:
				push_warning("敵の deck_ids に存在しない行動カード番号: %d" % id)
		return result
	return enemy.deck

# ---------------- ゲーム開始/リセット ----------------
func new_game() -> void:
	hp = 50
	max_hp = 50
	gold = 20
	battle_index = 0
	discard_pile.clear()
	owned_relic_ids.clear()
	draw_pile = _build_starter_deck()
	draw_pile.shuffle()

func owns_relic(relic_id: StringName) -> bool:
	return owned_relic_ids.has(relic_id)

func add_relic(relic_id: StringName) -> bool:
	if relic_id.is_empty() or owns_relic(relic_id):
		return false
	owned_relic_ids.append(relic_id)
	return true

func starting_shield_bonus() -> int:
	return 5 if owns_relic(BUCKLER_RELIC_ID) else 0

func apply_battle_gold_bonus(base_amount: int) -> int:
	if not owns_relic(HORSESHOE_RELIC_ID):
		return base_amount
	return base_amount + roundi(float(base_amount) * 0.10)

func _build_starter_deck() -> Array[CardData]:
	var deck: Array[CardData] = []
	# starter_deck_ids が設定されていれば、その番号どおりにデッキを組む。
	if not starter_deck_ids.is_empty():
		for id in starter_deck_ids:
			var card := card_by_id(id)
			if card != null:
				deck.append(card)
			else:
				push_warning("starter_deck_ids に存在しないカード番号: %d" % id)
		return deck
	# 未指定なら全カードを1枚ずつ（独立インスタンス）でデッキに入れる。
	# ※ 同じリソースを共有参照で入れると、手札に同一オブジェクトが並んで
	#    セット済み判定が両方に効いてしまうため、必ず duplicate() する。
	for card in all_cards:
		deck.append(card.duplicate())
	return deck

## 現在プレイヤーが所持している全カード（山札＋捨札＋準備中の手札）を返す。
## 場所が違うだけで、これがデッキの全内容。重複参照は除いて数える。
func get_full_deck() -> Array:
	var all: Array = []
	for c in draw_pile:
		all.append(c)
	for c in discard_pile:
		all.append(c)
	for c in prep_hand:
		if not all.has(c):
			all.append(c)
	return all

func draw_cards(n: int) -> Array[CardData]:
	var drawn: Array[CardData] = []
	for i in range(n):
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			draw_pile.shuffle()
			discard_pile.clear()
		drawn.append(draw_pile.pop_back())
	return drawn

# ---------------- 敵生成 ----------------
func start_next_battle() -> void:
	battle_index += 1
	var is_boss := battle_index % BOSS_INTERVAL == 0
	current_enemy = _pick_enemy(is_boss)
	enemy_max_hp = current_enemy.max_hp
	enemy_hp = enemy_max_hp
	player_shield = starting_shield_bonus()
	enemy_shield = 0
	player_charge = 0
	player_damage_buff = 0
	enemy_damage_debuff = 0
	enemy_attack_growth = 0
	regenerate_enemy_upcoming()

func regenerate_enemy_upcoming() -> void:
	# 敵の山札（番号で解決）から3行動を引く。生成ロジックは EnemyAI に分離。
	var deck := resolve_enemy_deck(current_enemy)
	enemy_upcoming = EnemyAI.generate_round(current_enemy, deck, 3)
	var projected_growth := enemy_attack_growth
	for index in range(enemy_upcoming.size()):
		var turn: Dictionary = enemy_upcoming[index]
		if str(turn.get("type", "")) == "attack":
			var display_value := preview_enemy_attack_damage(turn, index, projected_growth)
			turn["display_value"] = display_value
			turn["boosted_value"] = display_value > int(turn.get("value", 0))
		enemy_upcoming[index] = turn
		if current_enemy != null:
			projected_growth += current_enemy.attack_growth_per_shot


func current_prep_seconds() -> float:
	if current_enemy == null:
		return PREP_SECONDS
	return maxf(1.0, PREP_SECONDS - current_enemy.prep_time_penalty)


func normal_enemy_progression_bonus() -> int:
	if current_enemy == null or current_enemy.is_boss:
		return 0
	return mini(4, int(floor(float(maxi(0, battle_index - 1)) / BOSS_INTERVAL)) * 2)


func preview_enemy_attack_damage(
	turn: Dictionary,
	slot_index: int,
	projected_growth: int = -1
) -> int:
	var base_value := int(turn.get("value", 0))
	if str(turn.get("type", "")) != "attack":
		return base_value
	var growth := enemy_attack_growth if projected_growth < 0 else projected_growth
	var damage := base_value + growth + normal_enemy_progression_bonus()
	if current_enemy != null:
		damage += current_enemy.buff_damage
	if (
		int(turn.get("enchant", CardData.Enchant.NONE)) == CardData.Enchant.B
		and slot_index == 0
	):
		damage += int(turn.get("enchant_value", 0))
	return damage


func record_enemy_shot() -> void:
	if current_enemy != null:
		enemy_attack_growth += current_enemy.attack_growth_per_shot

func _pick_enemy(is_boss: bool) -> EnemyData:
	if is_boss:
		var boss_order := floori(float(battle_index) / float(BOSS_INTERVAL))
		for enemy in all_enemies:
			if enemy.is_boss and enemy.boss_order == boss_order:
				return enemy
	var pool := all_enemies.filter(func(e): return e.is_boss == is_boss)
	if pool.is_empty():
		pool = all_enemies
	if pool.is_empty():
		# フォールバック用ダミー敵（enemies フォルダが空の場合）
		var dummy := EnemyData.new()
		dummy.enemy_name = "ならず者"
		dummy.max_hp = 35
		dummy.base_attack = 7
		return dummy
	return pool[randi() % pool.size()]

# ---------------- じゃんけん判定 ----------------
## 判定ロジックは JankenRules に分離。既存の呼び出し（GameManager.resolve_hands）は
## そのまま使えるよう、ここで薄く委譲している。
func resolve_hands(player_hands: Array, enemy_hands: Array) -> Dictionary:
	return JankenRules.resolve_hands(player_hands, enemy_hands)

# ---------------- カード効果適用 ----------------
## UI向けの非破壊ダメージ予測。実際の攻撃式と同じく、戦闘中バフ、
## 旧式チャージ、先頭スロットのBエンチャントを含める。
func preview_player_attack_damage(
	card: CardData,
	slot_index: int = -1,
	damage_buff: int = -1,
	charge_bonus: int = -1
) -> int:
	if card == null:
		return 0
	if card.card_type != CardData.CardType.ATTACK:
		return card.value

	var resolved_buff := player_damage_buff if damage_buff < 0 else damage_buff
	var resolved_charge := player_charge if charge_bonus < 0 else charge_bonus
	var opening_bonus := 0
	if card.enchant == CardData.Enchant.B and slot_index == 0:
		opening_bonus = card.get_enchant_value()
	return card.value + resolved_buff + resolved_charge + opening_bonus


func apply_player_card(card: CardData, slot_index: int = -1) -> String:
	if card == null:
		return ""
	var enchant_value := card.get_enchant_value()
	var enchant_messages: Array[String] = []
	var attack_bonus := 0

	# Break C resolves before the ordinary attack. Unused break damage never
	# spills into HP; the base attack then resolves against the remaining shield.
	if card.enchant == CardData.Enchant.C:
		var broken := _damage_enemy_shield(enchant_value)
		if broken > 0:
			enchant_messages.append("敵ブロック-%d" % broken)

	# Charge B is an opening-slot damage bonus, not stored charge.
	if card.enchant == CardData.Enchant.B and slot_index == 0:
		attack_bonus = enchant_value
		enchant_messages.append("先制ダメージ+%d" % enchant_value)

	var enemy_hp_before := enemy_hp
	var player_hp_before := hp
	var message := _apply_player_base(card, attack_bonus)
	var hp_damage: int = max(0, enemy_hp_before - enemy_hp)

	match card.enchant:
		CardData.Enchant.D:
			player_damage_buff += enchant_value
			enchant_messages.append("与ダメ強化+%d" % enchant_value)
		CardData.Enchant.E:
			var removed := _remove_next_enemy_hands(slot_index, enchant_value)
			if removed > 0:
				enchant_messages.append("次の敵の手-%d" % removed)
		CardData.Enchant.F:
			if hp_damage > 0:
				hp = min(max_hp, hp + enchant_value)
				var healed := hp - player_hp_before
				if healed > 0:
					enchant_messages.append("ライフスティール+%d" % healed)

	if not enchant_messages.is_empty():
		message += " ＋ " + " ＋ ".join(enchant_messages)
	return message

## 基本行動（攻撃/ガード/回復/溜め/崩し）の適用
func _apply_player_base(card: CardData, attack_bonus: int = 0) -> String:
	match card.card_type:
		CardData.CardType.ATTACK:
			var dmg: int = card.value + player_charge + player_damage_buff + attack_bonus
			player_charge = 0
			var blocked = min(enemy_shield, dmg)
			enemy_shield -= blocked
			dmg -= blocked
			enemy_hp = max(0, enemy_hp - dmg)
			return "あなたの「%s」！ 敵に%dダメージ" % [card.display_label(), dmg]
		CardData.CardType.SKILL:
			player_shield += card.value
			return "あなたは「%s」で%dのシールドを得た" % [card.display_label(), card.value]
		CardData.CardType.POWER:
			hp = min(max_hp, hp + card.value)
			return "あなたは「%s」で%d回復した" % [card.display_label(), card.value]
		CardData.CardType.CHARGE:
			player_charge += card.value
			return "あなたは「%s」で力を溜めた（次の攻撃+%d）" % [card.display_label(), card.value]
		CardData.CardType.SHIELD_BREAK:
			var before := enemy_shield
			enemy_shield = int(enemy_shield / 2.0)
			return "あなたの「%s」！ 敵のシールドを半減（%d→%d）" % [card.display_label(), before, enemy_shield]
	return ""

func _damage_enemy_shield(amount: int) -> int:
	var damaged: int = min(max(0, amount), enemy_shield)
	enemy_shield -= damaged
	return damaged

func _remove_next_enemy_hands(slot_index: int, amount: int) -> int:
	var next_index := slot_index + 1
	if slot_index < 0 or next_index >= enemy_upcoming.size():
		return 0
	var next_turn = enemy_upcoming[next_index]
	if not (next_turn is Dictionary):
		return 0
	var hands: Array = next_turn.get("hands", []).duplicate()
	var display_hands: Array = next_turn.get("display_hands", hands).duplicate()
	var removed: int = min(max(0, amount), hands.size())
	for _index in range(removed):
		hands.remove_at(0)
		if not display_hands.is_empty():
			display_hands.remove_at(0)
	next_turn["hands"] = hands
	next_turn["display_hands"] = display_hands
	enemy_upcoming[next_index] = next_turn
	return removed

func apply_enemy_turn(turn: Dictionary, slot_index: int = -1) -> String:
	match turn.type:
		"attack":
			if int(turn.get("enchant", CardData.Enchant.NONE)) == CardData.Enchant.C:
				_damage_player_shield(int(turn.get("enchant_value", 0)))
			var dmg: int = max(
				0,
				preview_enemy_attack_damage(turn, slot_index) - enemy_damage_debuff
			)
			var blocked = min(player_shield, dmg)
			player_shield -= blocked
			dmg -= blocked
			hp = max(0, hp - dmg)
			return "敵の「%s」！ あなたに%dダメージ" % [turn.name, dmg]
		"skill":
			enemy_shield += turn.value
			return "敵は「%s」で%dのシールドを得た" % [turn.name, turn.value]
		"power":
			enemy_hp = min(enemy_max_hp, enemy_hp + turn.value)
			return "敵は「%s」で%d回復した" % [turn.name, turn.value]
	return ""


func _damage_player_shield(amount: int) -> int:
	var damaged: int = min(max(0, amount), player_shield)
	player_shield -= damaged
	return damaged

# ---------------- イベント ----------------
func pick_random_event() -> EventData:
	if all_events.is_empty():
		return null
	return all_events[randi() % all_events.size()]

func apply_event_choice(choice: EventChoiceData) -> void:
	gold = max(0, gold + choice.gold_delta - choice.gold_cost)
	hp = clamp(hp + choice.hp_delta, 0, max_hp)
	max_hp += choice.max_hp_delta
	if choice.add_card != null:
		# 共有参照を避けるため必ず複製して追加する
		discard_pile.append(choice.add_card.duplicate())
	if choice.remove_random_card:
		var all_owned := draw_pile + discard_pile
		if not all_owned.is_empty():
			var target = all_owned[randi() % all_owned.size()]
			draw_pile.erase(target)
			discard_pile.erase(target)
