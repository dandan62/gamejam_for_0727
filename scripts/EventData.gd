extends Resource
class_name EventData

## イベント1件分のデータ。
## [新規リソース] → EventData で作成し、res://resources/events/ に .tres 保存。
## GameManager.all_events に登録すればイベント抽選に出るようになります。

@export var event_name: String = "New Event"
@export var image: Texture2D
@export_multiline var description: String = "何かが起きた。"

## true にすると、このイベントを選んだときに通常の選択肢ではなく
## カード売り場（Shop.tscn）へ移動する。choices は無視される。
@export var is_shop: bool = false

## 選択肢（2〜4個程度を想定。is_shop=true のときは未使用）
@export var choices: Array[EventChoiceData] = []
