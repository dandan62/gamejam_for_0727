extends RefCounted
class_name JankenRules

## じゃんけんの勝敗判定（状態を持たない純粋ロジック）。
## ここを編集しても GameManager など他ファイルには影響しないので、
## じゃんけんの仕様変更はこのファイルだけで完結できる。

## 戻り値: {player_acts: bool, enemy_acts: bool}（＝どちらの行動が発動するか）
##
## 【勝敗の優先度】
##  1. 手の数が多い方が強い（例: 2個 vs 1個 → 2個側の勝ち）
##  2. 手の数が同じとき:
##     - 1個同士 → 普通のじゃんけん
##     - 2個同士 → 同じ手を除外し、残った手で判定
##       例) グー・チョキ vs パー・グー → グーを除外 → チョキ vs パー → チョキ(前者)の勝ち
##  ・全部同じ手（残りなし）はあいこ＝両者行動
static func resolve_hands(player_hands: Array, enemy_hands: Array) -> Dictionary:
	var pn := player_hands.size()
	var en := enemy_hands.size()

	# 優先度1: 手の数が多い方が勝つ
	if pn > en:
		return {"player_acts": true, "enemy_acts": false}
	if en > pn:
		return {"player_acts": false, "enemy_acts": true}

	# ここから手の数は同じ。0個同士（両者行動なし）はそのまま不発
	if pn == 0:
		return {"player_acts": false, "enemy_acts": false}

	# 優先度2: 同じ手を除外して、残った手で判定
	var common := player_hands.filter(func(h): return enemy_hands.has(h))
	var rem_a := player_hands.filter(func(h): return not common.has(h))
	var rem_b := enemy_hands.filter(func(h): return not common.has(h))

	# 全部同じ手（残りなし）→ あいこ＝両者行動
	if rem_a.is_empty() and rem_b.is_empty():
		return {"player_acts": true, "enemy_acts": true}

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
