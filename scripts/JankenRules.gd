extends RefCounted
class_name JankenRules

## じゃんけんの勝敗判定（状態を持たない純粋ロジック）。
## ここを編集しても GameManager など他ファイルには影響しないので、
## じゃんけんの仕様変更はこのファイルだけで完結できる。

## 戻り値: {player_acts: bool, enemy_acts: bool}
## 複数手は「被った手」を相殺し、残った手で判定。あいこは両者行動。
static func resolve_hands(player_hands: Array, enemy_hands: Array) -> Dictionary:
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
	if beats(a) == b:
		return {"player_acts": true, "enemy_acts": false}
	if beats(b) == a:
		return {"player_acts": false, "enemy_acts": true}
	return {"player_acts": true, "enemy_acts": true}

## hand が勝てる相手の手を返す（グー→チョキ など）
static func beats(hand) -> int:
	match hand:
		CardData.Hand.ROCK: return CardData.Hand.SCISSORS
		CardData.Hand.SCISSORS: return CardData.Hand.PAPER
		CardData.Hand.PAPER: return CardData.Hand.ROCK
	return -1
