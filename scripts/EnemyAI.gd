extends RefCounted
class_name EnemyAI

## 敵の行動生成（状態を持たない純粋ロジック）。
## 敵の挙動を調整したいときは、基本このファイルだけを編集すればよい。

## 1ラウンド分（count 個）の行動を生成して返す。
## deck（解決済みの EnemyActionData 配列）から引く。空なら base_attack のランダム行動にする。
static func generate_round(enemy: EnemyData, deck: Array, count: int) -> Array:
	var turns := []
	if deck.is_empty():
		for i in range(count):
			turns.append(generate_turn(enemy))
	else:
		var work := deck.duplicate()
		work.shuffle()
		for i in range(count):
			var action: EnemyActionData = work[i % work.size()]
			turns.append(_action_to_turn(action))
	_conceal_random_hands_across_round(turns, enemy.hidden_hand_icons)
	return turns

## 行動カード → Battle が使う行動データ {type, value, hands, name}
static func _action_to_turn(action: EnemyActionData) -> Dictionary:
	var hands := action.janken_hands.duplicate()
	return {
		"id": action.id,
		"type": action.type_string(),
		"value": action.value,
		"hands": hands,
		"display_hands": hands.duplicate(),
		"name": action.action_name,
		"enchant": action.enchant,
		"enchant_value": action.get_enchant_value(),
	}

## 敵の1行動をランダム生成して返す（山札が無い敵のフォールバック）: {type, value, hands, name}
static func generate_turn(enemy: EnemyData) -> Dictionary:
	var roll := randf()
	var type_str: String
	var value: int
	var base_atk := enemy.base_attack
	if roll < 0.6:
		type_str = "attack"
		value = base_atk + randi() % 4
	elif roll < 0.85:
		type_str = "skill"
		value = int(round(base_atk * 0.7))
	else:
		type_str = "power"
		value = int(round(base_atk * 0.9))
	var hands := random_hand_set()
	return {
		"type": type_str,
		"value": value,
		"hands": hands,
		"display_hands": hands.duplicate(),
		"name": turn_name(type_str),
		"enchant": CardData.Enchant.NONE,
		"enchant_value": 0,
	}


static func _conceal_random_hands_across_round(
	turns: Array,
	hidden_count: int
) -> void:
	if turns.is_empty() or hidden_count <= 0:
		return
	var symbol_positions: Array[Vector2i] = []
	for turn_index in range(turns.size()):
		var turn: Dictionary = turns[turn_index]
		var hands: Array = turn.get("hands", [])
		for hand_index in range(hands.size()):
			symbol_positions.append(Vector2i(turn_index, hand_index))
	symbol_positions.shuffle()

	for index in range(min(hidden_count, symbol_positions.size())):
		var symbol_position := symbol_positions[index]
		var turn: Dictionary = turns[symbol_position.x]
		var displayed: Array = turn.get(
			"display_hands",
			turn.get("hands", [])
		).duplicate()
		displayed[symbol_position.y] = -1
		turn["display_hands"] = displayed
		turns[symbol_position.x] = turn

static func random_hand_set() -> Array:
	var all := [CardData.Hand.ROCK, CardData.Hand.PAPER, CardData.Hand.SCISSORS]
	all.shuffle()
	var count := 1 if randf() < 0.75 else 2
	return all.slice(0, count)

static func turn_name(type_str: String) -> String:
	match type_str:
		"attack": return ["射撃", "斬りかかり", "殴打"][randi() % 3]
		"skill": return ["身構え", "回避", "ガード"][randi() % 3]
		"power": return ["雄叫び", "闘気"][randi() % 2]
	return "行動"
