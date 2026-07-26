extends Resource
class_name EnemyActionData

## 敵の行動1つ分（＝敵の山札に入れる「行動カード」）。
## [新規リソース] → EnemyActionData で作成し、EnemyData の deck 配列に入れる。

## 攻撃 / スキル=防御 / パワー=回復
enum ActionType { ATTACK, SKILL, POWER }

## 行動カード固有の番号(ID)。敵の deck_ids から番号で参照する。
@export var id: int = 0

@export var action_name: String = "行動"

## じゃんけん属性（複数可）。値は CardData.Hand（0=グー / 1=パー / 2=チョキ）。
@export var janken_hands: Array[int] = [CardData.Hand.ROCK]

## 行動タイプ
@export var type: ActionType = ActionType.ATTACK

## 効果量（攻撃/貫通=ダメージ、スキル=シールド、パワー=回復、溜め=次の攻撃への加算）
@export var value: int = 7

## 敵弾の追加効果。現状はB=先頭スロット強化、C=シールド破壊を使用する。
@export var enchant: CardData.Enchant = CardData.Enchant.NONE
@export var enchant_size: CardData.Size = CardData.Size.SMALL

## Battle / GameManager が使う文字列タイプへ変換
func type_string() -> String:
	match type:
		ActionType.ATTACK: return "attack"
		ActionType.SKILL: return "skill"
		ActionType.POWER: return "power"
	return "attack"

func is_attack() -> bool:
	return type == ActionType.ATTACK


func get_enchant_value() -> int:
	if enchant == CardData.Enchant.NONE:
		return 0
	var levels: Dictionary = CardData.ENCHANT_VALUE.get(enchant, {})
	return int(levels.get(enchant_size, 0))
