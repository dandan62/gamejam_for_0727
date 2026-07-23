extends Resource
class_name EnemyData

## 敵1体分のデータ。[新規リソース] → EnemyData で作成し res://resources/enemies/ に保存。

@export var enemy_name: String = "ならず者"
@export var image: Texture2D
@export var max_hp: int = 35
@export var base_attack: int = 7
@export var is_boss: bool = false
