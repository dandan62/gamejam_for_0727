extends Resource
class_name EnemyActionData

## 敵の行動1つ分（＝敵の山札に入れる「行動カード」）。
## [新規リソース] → EnemyActionData で作成し、EnemyData の deck 配列に入れる。

## 攻撃 / スキル=防御 / パワー=回復 / 溜め=次の攻撃強化 / 貫通=シールド無視攻撃
enum ActionType { ATTACK, SKILL, POWER, CHARGE, PIERCE }

@export var action_name: String = "行動"

## じゃんけん属性（複数可）。値は CardData.Hand（0=グー / 1=パー / 2=チョキ）。
@export var janken_hands: Array[int] = [CardData.Hand.ROCK]

## 行動タイプ
@export var type: ActionType = ActionType.ATTACK

## 効果量（攻撃/貫通=ダメージ、スキル=シールド、パワー=回復、溜め=次の攻撃への加算）
@export var value: int = 7

## Battle / GameManager が使う文字列タイプへ変換
func type_string() -> String:
	match type:
		ActionType.ATTACK: return "attack"
		ActionType.SKILL: return "skill"
		ActionType.POWER: return "power"
		ActionType.CHARGE: return "charge"
		ActionType.PIERCE: return "pierce"
	return "attack"

func is_attack() -> bool:
	return type == ActionType.ATTACK or type == ActionType.PIERCE
