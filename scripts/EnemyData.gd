extends Resource
class_name EnemyData

## 敵1体分のデータ。[新規リソース] → EnemyData で作成し res://resources/enemies/ に保存。

@export var id: int = 0
@export var enemy_name: String = "ならず者"
## 戦闘前画面に表示する敵の紹介文。
@export_multiline var description: String = ""
@export var image: Texture2D
@export var max_hp: int = 35
@export var is_boss: bool = false
## 通常敵の出現段階。0=1〜2戦目、1=3〜6戦目、2=8〜13戦目、3=15〜20戦目。
## ボスは CSV に合わせて 4 を設定するが、通常敵の抽選には使わない。
@export var tier: int = 0
## ボス戦の順番（1=7戦目、2=14戦目、3=21戦目）。
@export var boss_order: int = 0

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

## CSVのbuff_damage。すべての攻撃弾に加算する固定ダメージ。
@export var buff_damage: int = 0
## Timerボス用。準備時間から差し引く秒数。
@export var prep_time_penalty: float = 0.0
## Mischiefボス用。1ラウンド全体からランダムに「?」へ置き換える手アイコン数。
@export var hidden_hand_icons: int = 0
## Devilボス用。1発解決するたび次回以降の攻撃に加算する値。
@export var attack_growth_per_shot: int = 0
