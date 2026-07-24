extends Resource
class_name EnemyData

## 敵1体分のデータ。[新規リソース] → EnemyData で作成し res://resources/enemies/ に保存。

@export var enemy_name: String = "ならず者"
@export var image: Texture2D
@export var max_hp: int = 35
@export var is_boss: bool = false

## 敵の山札を行動カードの番号(id)で指定する（推奨）。
## 例: [1, 1, 3, 4]  同じ番号を複数入れると出やすくなる。
## resources/enemy_actions/ の EnemyActionData を番号で参照する。
@export var deck_ids: Array[int] = []

## 山札を直接リソースで持たせたい場合はこちら（deck_ids が空のとき使う）。
## 同じ行動を濃くしたいときは同じ EnemyActionData を複数入れる（枚数＝出やすさ）。
## deck_ids も deck も空なら base_attack のランダム行動にフォールバックする。
@export var deck: Array[EnemyActionData] = []

## デッキが空のときに使う基礎攻撃力（フォールバック用）
@export var base_attack: int = 7

## --- HP依存の発狂ギミック ---
## HP割合がこの値以下になると発狂（0以下なら発狂しない）。例: 0.4
@export var enrage_below: float = 0.0
## 発狂中、攻撃系の value に加算するボーナス
@export var enrage_bonus: int = 0
