extends Resource
class_name EventChoiceData

## イベント内の選択肢1つ分のデータ。
## [新規リソース] → EventChoiceData で作成し、EventData の choices 配列に入れます。

## 選択肢のボタンに表示する文字
@export var label: String = "選択肢"

## 選ぶための条件（0以下なら無条件）。所持金がこれ未満だと選べない
@export var gold_cost: int = 0

## 選択時の増減（マイナス可）
@export var gold_delta: int = 0
@export var hp_delta: int = 0
@export var max_hp_delta: int = 0

## 選択時にデッキへ追加するカード（任意）
@export var add_card: CardData

## 選択時にデッキから1枚除去するか（レアカード等の交換イベント用、簡易プロトタイプでは未使用可）
@export var remove_random_card: bool = false

## 選んだ後に表示する結果テキスト
@export_multiline var result_text: String = ""
