extends Resource
class_name EnemyData

## 敵1体分のデータ。[新規リソース] → EnemyData で作成し res://resources/enemies/ に保存。

@export var enemy_name: String = "ならず者"
@export var image: Texture2D
@export var max_hp: int = 35
@export var is_boss: bool = false

## 敵の山札。毎ラウンド、この中から行動を引いて予告する。
## 同じ行動を濃くしたいときは同じ EnemyActionData を複数入れる（枚数＝出やすさ）。
## 空の場合は base_attack を使ったランダム行動にフォールバックする。
@export var deck: Array[EnemyActionData] = []

## デッキが空のときに使う基礎攻撃力（フォールバック用）
@export var base_attack: int = 7

## --- HP依存の発狂ギミック ---
## HP割合がこの値以下になると発狂（0以下なら発狂しない）。例: 0.4
@export var enrage_below: float = 0.0
## 発狂中、攻撃系の value に加算するボーナス
@export var enrage_bonus: int = 0
