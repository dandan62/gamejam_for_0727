extends Resource
class_name CardData

## カードデータ定義。
## エディタで [新規リソース] → CardData を選び、値を入れて
## res://resources/cards/ 以下に .tres として保存すれば新しいカードを作れます。

enum Hand { ROCK, PAPER, SCISSORS }
enum Rarity { COMMON, UNCOMMON, RARE }
## 攻撃 / スキル=防御 / パワー=回復 / 溜め=次の攻撃強化 / シールドブレイク=ダメージ無しで敵ブロック半減
enum CardType { ATTACK, SKILL, POWER, CHARGE, SHIELD_BREAK }

# ============================================================
# 構造フィールド式カード定義（新方式）
#   カードを「基本行動＋大きさ」＋「エンチャント＋大きさ」＋「じゃんけんの手」で定義する。
#   structured = true のカードは、これらから card_type / value / コードを自動生成する。
# ============================================================

## 基本行動（攻撃 / ガード / 回復）
enum ActionKind { ATTACK, GUARD, HEAL }
## 効果の大きさ（小=1 / 中=2 / 大=3）
enum Size { SMALL = 1, MEDIUM = 2, LARGE = 3 }
## エンチャント（追加効果）。効果内容は GameManager._apply_player_enchant で定義する。
enum Enchant { NONE, A, B, C, D, E, F }

## 基本行動×大きさ → 実際の効果量。ここを編集すれば大中小の値を調整できる。
const ACTION_VALUE := {
	ActionKind.ATTACK: { Size.SMALL: 8, Size.MEDIUM: 12, Size.LARGE: 15 },
	ActionKind.GUARD:  { Size.SMALL: 6, Size.MEDIUM: 8,  Size.LARGE: 12 },
	ActionKind.HEAL:   { Size.SMALL: 2, Size.MEDIUM: 3,  Size.LARGE: 5 },
}
## エンチャントの大きさ → 効果量（汎用）。エンチャント側で使う値。
const ENCHANT_VALUE := { Size.SMALL: 2, Size.MEDIUM: 4, Size.LARGE: 6 }

## カード固有の番号(ID)。カードを番号で管理・参照するためのユニークな値。
## デッキ構成やショップ・イベントで、この番号を使ってカードを指定できる。
@export var id: int = 0

## カード名
@export var card_name: String = "New Card"

## カード画像（Slay the Spire風の縦長イラスト推奨）
@export var image: Texture2D

## じゃんけん属性。複数付与可（配列に複数入れる）
@export var janken_hands: Array[Hand] = [Hand.ROCK]

## レアリティ
@export var rarity: Rarity = Rarity.COMMON

## カード種別（攻撃 / スキル(防御等) / パワー(継続効果)）
@export var card_type: CardType = CardType.ATTACK

## コスト（勝負フェーズの並べ替え制限などに将来使用可）
@export var cost: int = 1

## 効果量（攻撃ならダメージ、スキルならブロック、パワーなら継続効果値）
@export var value: int = 6

## カード説明文（{value} は value に自動置換されて表示されます）
@export_multiline var description: String = "{value} ダメージを与える。"

# ---- 構造フィールド式（structured=true で card_type/value を自動生成）----
## true にすると下の action/size/enchant から card_type と value を自動計算する。
@export var structured: bool = false
## 基本行動
@export var action: ActionKind = ActionKind.ATTACK
## 基本行動の大きさ（小/中/大）
@export var action_size: Size = Size.MEDIUM
## エンチャント（追加効果）
@export var enchant: Enchant = Enchant.NONE
## エンチャントの大きさ（小/中/大）
@export var enchant_size: Size = Size.MEDIUM

## 構造フィールドから card_type / value を計算して反映する。
## GameManager がカード読み込み時に呼ぶ（structured=false のカードは何もしない）。
func rebuild() -> void:
	if not structured:
		return
	card_type = _action_to_card_type(action)
	value = ACTION_VALUE[action][action_size]

func _action_to_card_type(a: int) -> CardType:
	match a:
		ActionKind.ATTACK: return CardType.ATTACK
		ActionKind.GUARD: return CardType.SKILL
		ActionKind.HEAL: return CardType.POWER
	return CardType.ATTACK

## エンチャントの効果量（NONE のときは 0）
func get_enchant_value() -> int:
	if enchant == Enchant.NONE:
		return 0
	return ENCHANT_VALUE[enchant_size]

## カードの内容を表すコード文字列（例: "攻2/A3/グチ"）。
func code() -> String:
	if not structured:
		return str(id)
	var a_char: String = ["攻", "守", "回"][action]
	var e_char: String = "-"
	if enchant != Enchant.NONE:
		e_char = "ABCDEF".substr(enchant - 1, 1)
	var hands_str: String = ""
	for h in janken_hands:
		hands_str += ["グ", "パ", "チ"][h]
	return "%s%d/%s%d/%s" % [a_char, action_size, e_char, enchant_size, hands_str]

func get_description_text() -> String:
	return description.replace("{value}", str(value))

func get_hand_icons() -> String:
	var icons := []
	for h in janken_hands:
		match h:
			Hand.ROCK: icons.append("グー")
			Hand.PAPER: icons.append("パー")
			Hand.SCISSORS: icons.append("チョキ")
	return "・".join(icons)

func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON: return Color(0.75, 0.75, 0.75)
		Rarity.UNCOMMON: return Color(0.35, 0.65, 1.0)
		Rarity.RARE: return Color(1.0, 0.8, 0.2)
	return Color.WHITE

func get_type_label() -> String:
	match card_type:
		CardType.ATTACK: return "攻撃"
		CardType.SKILL: return "スキル"
		CardType.POWER: return "パワー"
		CardType.CHARGE: return "溜め"
		CardType.SHIELD_BREAK: return "崩し"
	return ""

## 表示ラベル。プレイヤーのカードは「カード名を使わず番号のみ」で管理する方針。
## id>0（＝プレイヤーの正規カード）なら番号を返す。
## id=0（＝敵行動の一時表示など）は従来どおり card_name を返す。
func display_label() -> String:
	if structured:
		return code()
	if id > 0:
		return str(id)
	return card_name

## じゃんけん属性ごとの色。グー=赤 / チョキ=黄 / パー=青
static func hand_color(hand: int) -> Color:
	match hand:
		Hand.ROCK: return Color(0.85, 0.2, 0.2)      # 赤
		Hand.SCISSORS: return Color(0.95, 0.85, 0.2)  # 黄
		Hand.PAPER: return Color(0.25, 0.5, 0.95)     # 青
	return Color.WHITE

## カード枠の色。複数属性の場合は色を平均して混色する
func get_frame_color() -> Color:
	if janken_hands.is_empty():
		return Color.WHITE
	var r := 0.0
	var g := 0.0
	var b := 0.0
	for h in janken_hands:
		var c := hand_color(h)
		r += c.r
		g += c.g
		b += c.b
	var n := float(janken_hands.size())
	return Color(r / n, g / n, b / n)
