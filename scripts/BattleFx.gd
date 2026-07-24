extends RefCounted
class_name BattleFx

## 勝負フェーズのダメージ/回復のフローティング数字演出（見た目だけ）。
## 演出を変えたいときはこのファイルだけを触ればよく、Battle.gd の進行ロジックと衝突しない。

const COLOR_DAMAGE := Color(1.0, 0.3, 0.25)
const COLOR_SHIELD := Color(0.4, 0.7, 1.0)
const COLOR_HEAL := Color(0.4, 0.9, 0.4)

## プレイヤーのカード効果に応じた数字を出す
static func spawn_player_effect(panel: Node, enemy_hp_bar: Control, player_slot: Control, card: CardData, enemy_before: int) -> void:
	match card.card_type:
		CardData.CardType.ATTACK:
			var dmg := enemy_before - GameManager.enemy_hp
			if dmg > 0:
				float_beside(panel, enemy_hp_bar, "-%d" % dmg, COLOR_DAMAGE)
		CardData.CardType.SKILL:
			float_text(panel, player_slot, "+%d" % card.value, COLOR_SHIELD)
		CardData.CardType.POWER:
			float_text(panel, player_slot, "+%d" % card.value, COLOR_HEAL)

## 敵の行動に応じた数字を出す
static func spawn_enemy_effect(panel: Node, player_hp_bar: Control, enemy_slot: Control, turn: Dictionary, player_before: int) -> void:
	match turn.type:
		"attack", "pierce":
			var dmg := player_before - GameManager.hp
			if dmg > 0:
				float_beside(panel, player_hp_bar, "-%d" % dmg, COLOR_DAMAGE)
		"skill":
			float_text(panel, enemy_slot, "+%d" % turn.value, COLOR_SHIELD)
		"power":
			float_text(panel, enemy_slot, "+%d" % turn.value, COLOR_HEAL)
		"charge":
			float_text(panel, enemy_slot, "溜+%d" % turn.value, Color(0.95, 0.85, 0.2))

## HPバーの右横に数字を出して、上へ動きながらフェード
static func float_beside(parent: Node, bar: Control, text: String, color: Color) -> void:
	var lbl := _make_label(text, color, 28)
	parent.add_child(lbl)
	lbl.global_position = bar.global_position + Vector2(bar.size.x + 8.0, -6.0)
	_animate(parent, lbl, 40.0)

## ノード（カード等）の上あたりに数字を出して、上へ動きながらフェード
static func float_text(parent: Node, anchor: Control, text: String, color: Color) -> void:
	var lbl := _make_label(text, color, 32)
	parent.add_child(lbl)
	lbl.global_position = anchor.global_position + Vector2(anchor.size.x * 0.5 - 20.0, 20.0)
	_animate(parent, lbl, 70.0)

static func _make_label(text: String, color: Color, size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.z_index = 20
	return lbl

static func _animate(parent: Node, lbl: Label, rise: float) -> void:
	var tw := parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - rise, 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(lbl.queue_free)
