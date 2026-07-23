extends Node

## ゲーム全体の状態とロジックを管理するオートロード（シングルトン）。
## res://resources/cards, resources/events, resources/enemies 以下の
## .tres ファイルを起動時に自動スキャンして読み込みます。
## → 新しいカード/イベント/敵はスクリプトを触らずフォルダに置くだけで反映されます。

const TOTAL_BATTLES := 21
const BOSS_INTERVAL := 7
const PREP_SECONDS := 10.0

const CARDS_DIR := "res://resources/cards"
const EVENTS_DIR := "res://resources/events"
const ENEMIES_DIR := "res://resources/enemies"

var all_cards: Array[CardData] = []
var all_events: Array[EventData] = []
var all_enemies: Array[EnemyData] = []

var starter_deck_ids: Array[String] = [] # card_name のリスト。空なら all_cards からランダム構築

# --- プレイヤー状態 ---
var hp: int = 50
var max_hp: int = 50
var gold: int = 20
var battle_index: int = 0

var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []

# --- バトル中の状態 ---
var current_enemy: EnemyData
var enemy_hp: int
var enemy_max_hp: int
var player_shield: int = 0
var enemy_shield: int = 0

var prep_hand: Array[CardData] = []
var slots: Array = [null, null, null]
var enemy_upcoming: Array = [] # 3要素: {type, value, hands, name}
var current_scale: float = 1.0
var game_over_reason: String = "" # "win" / "lose"

func _ready() -> void:
	all_cards.assign(_load_resources_in_dir(CARDS_DIR, "CardData"))
	all_events.assign(_load_resources_in_dir(EVENTS_DIR, "EventData"))
	all_enemies.assign(_load_resources_in_dir(ENEMIES_DIR, "EnemyData"))

func _load_resources_in_dir(path: String, expected_class: String) -> Array:
	var results := []
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("フォルダが見つかりません: %s" % path)
		return results
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(path + "/" + file_name)
			if res != null:
				results.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	return results

# ---------------- ゲーム開始/リセット ----------------
func new_game() -> void:
	hp = 50
	max_hp = 50
	gold = 20
	battle_index = 0
	discard_pile.clear()
	draw_pile = _build_starter_deck()
	draw_pile.shuffle()

func _build_starter_deck() -> Array[CardData]:
	var deck: Array[CardData] = []
	if all_cards.is_empty():
		return deck
	# 全カードを1枚ずつ、独立したインスタンス（複製）としてデッキに入れる。
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
	current_scale = 1.0 + floor(float(battle_index - 1) / float(BOSS_INTERVAL)) * 0.4
	enemy_max_hp = int(round(current_enemy.max_hp * current_scale))
	enemy_hp = enemy_max_hp
	player_shield = 0
	enemy_shield = 0
	regenerate_enemy_upcoming()

func regenerate_enemy_upcoming() -> void:
	enemy_upcoming = [_generate_enemy_turn(current_scale), _generate_enemy_turn(current_scale), _generate_enemy_turn(current_scale)]

func _pick_enemy(is_boss: bool) -> EnemyData:
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

func _generate_enemy_turn(scale: float) -> Dictionary:
	var roll := randf()
	var type_str: String
	var value: int
	var base_atk := int(round(current_enemy.base_attack * scale))
	if roll < 0.6:
		type_str = "attack"
		value = base_atk + randi() % 4
	elif roll < 0.85:
		type_str = "skill"
		value = int(round(base_atk * 0.7))
	else:
		type_str = "power"
		value = int(round(base_atk * 0.9))
	return {
		"type": type_str,
		"value": value,
		"hands": _random_hand_set(),
		"name": _enemy_turn_name(type_str),
	}

func _random_hand_set() -> Array:
	var all := [CardData.Hand.ROCK, CardData.Hand.PAPER, CardData.Hand.SCISSORS]
	all.shuffle()
	var count := 1 if randf() < 0.75 else 2
	return all.slice(0, count)

func _enemy_turn_name(type_str: String) -> String:
	match type_str:
		"attack": return ["射撃", "斬りかかり", "殴打"][randi() % 3]
		"skill": return ["身構え", "回避", "ガード"][randi() % 3]
		"power": return ["雄叫び", "闘気"][randi() % 2]
	return "行動"

# ---------------- じゃんけん判定 ----------------
## 戻り値: {player_acts: bool, enemy_acts: bool}
func resolve_hands(player_hands: Array, enemy_hands: Array) -> Dictionary:
	if player_hands.is_empty():
		return {"player_acts": false, "enemy_acts": true}
	var common := player_hands.filter(func(h): return enemy_hands.has(h))
	var rem_a := player_hands.filter(func(h): return not common.has(h))
	var rem_b := enemy_hands.filter(func(h): return not common.has(h))

	if rem_a.is_empty() and rem_b.is_empty():
		return {"player_acts": true, "enemy_acts": true} # あいこ
	if rem_a.is_empty():
		return {"player_acts": false, "enemy_acts": true}
	if rem_b.is_empty():
		return {"player_acts": true, "enemy_acts": false}

	var a = rem_a[0]
	var b = rem_b[0]
	if _beats(a) == b:
		return {"player_acts": true, "enemy_acts": false}
	if _beats(b) == a:
		return {"player_acts": false, "enemy_acts": true}
	return {"player_acts": true, "enemy_acts": true}

func _beats(hand) -> int:
	match hand:
		CardData.Hand.ROCK: return CardData.Hand.SCISSORS
		CardData.Hand.SCISSORS: return CardData.Hand.PAPER
		CardData.Hand.PAPER: return CardData.Hand.ROCK
	return -1

# ---------------- カード効果適用 ----------------
func apply_player_card(card: CardData) -> String:
	if card == null:
		return ""
	match card.card_type:
		CardData.CardType.ATTACK:
			var dmg := card.value
			var blocked = min(enemy_shield, dmg)
			enemy_shield -= blocked
			dmg -= blocked
			enemy_hp = max(0, enemy_hp - dmg)
			return "あなたの「%s」！ 敵に%dダメージ" % [card.card_name, dmg]
		CardData.CardType.SKILL:
			player_shield += card.value
			return "あなたは「%s」で%dのシールドを得た" % [card.card_name, card.value]
		CardData.CardType.POWER:
			hp = min(max_hp, hp + card.value)
			return "あなたは「%s」で%d回復した" % [card.card_name, card.value]
	return ""

func apply_enemy_turn(turn: Dictionary) -> String:
	match turn.type:
		"attack":
			var dmg: int = turn.value
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
