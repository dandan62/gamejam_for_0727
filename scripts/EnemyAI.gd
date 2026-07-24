extends RefCounted
class_name EnemyAI

## 敵の行動生成（状態を持たない純粋ロジック）。
## 敵の挙動を調整したいときは、基本このファイルだけを編集すればよい。

## 1ラウンド分（count 個）の行動を生成して返す。
## 敵に山札(deck)があればそこから引き、無ければ base_attack のランダム行動にする。
## enraged=true（発狂中）のときは攻撃系を優先的に引き、攻撃値にボーナスを加える。
static func generate_round(enemy: EnemyData, scale: float, count: int, enraged: bool = false) -> Array:
	var turns := []
	if enemy.deck.is_empty():
		for i in range(count):
			turns.append(generate_turn(enemy, scale))
		return turns
	var deck := enemy.deck.duplicate()
	if enraged:
		var attacks := deck.filter(func(a): return a.is_attack())
		if not attacks.is_empty():
			deck = attacks
	deck.shuffle()
	for i in range(count):
		var action: EnemyActionData = deck[i % deck.size()]
		turns.append(_action_to_turn(action, scale, enemy, enraged))
	return turns

## 行動カード → Battle が使う行動データ {type, value, hands, name}
static func _action_to_turn(action: EnemyActionData, scale: float, enemy: EnemyData, enraged: bool) -> Dictionary:
	var value := int(round(action.value * scale))
	if enraged and action.is_attack():
		value += enemy.enrage_bonus
	return {
		"type": action.type_string(),
		"value": value,
		"hands": action.janken_hands.duplicate(),
		"name": action.action_name,
	}

## 敵の1行動をランダム生成して返す（山札が無い敵のフォールバック）: {type, value, hands, name}
static func generate_turn(enemy: EnemyData, scale: float) -> Dictionary:
	var roll := randf()
	var type_str: String
	var value: int
	var base_atk := int(round(enemy.base_attack * scale))
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
		"hands": random_hand_set(),
		"name": turn_name(type_str),
	}

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
