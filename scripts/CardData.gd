extends Resource
class_name CardData

## カードデータ定義。
## エディタで [新規リソース] → CardData を選び、値を入れて
## res://resources/cards/ 以下に .tres として保存すれば新しいカードを作れます。

enum Hand { ROCK, PAPER, SCISSORS }
enum Rarity { COMMON, UNCOMMON, RARE }
enum CardType { ATTACK, SKILL, POWER }

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
	return ""

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
