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
		return turns
	var work := deck.duplicate()
	work.shuffle()
	for i in range(count):
		var action: EnemyActionData = work[i % work.size()]
		turns.append(_action_to_turn(action, enemy))
	return turns

## 行動カード → Battle が使う行動データ {type, value, hands, name}
static func _action_to_turn(action: EnemyActionData, enemy: EnemyData) -> Dictionary:
	var hands := action.janken_hands.duplicate()
	return {
		"id": action.id,
		"type": action.type_string(),
		"value": action.value,
		"hands": hands,
		"display_hands": _hidden_display_hands(hands, enemy.hidden_hand_icons),
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
		"display_hands": _hidden_display_hands(hands, enemy.hidden_hand_icons),
		"name": turn_name(type_str),
		"enchant": CardData.Enchant.NONE,
		"enchant_value": 0,
	}


static func _hidden_display_hands(hands: Array, hidden_count: int) -> Array:
	var displayed := hands.duplicate()
	if displayed.is_empty() or hidden_count <= 0:
		return displayed
	var indices := range(displayed.size())
	indices.shuffle()
	for index in range(min(hidden_count, displayed.size())):
		displayed[indices[index]] = -1
	return displayed

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
