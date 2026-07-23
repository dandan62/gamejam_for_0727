extends Control
class_name CardBorder

## カードの枠を、じゃんけん属性ごとに縦方向で色分けして描画するオーバーレイ。
## 属性1つ → 単色枠 / 2つ → 左右2分割 / 3つ → 左右3分割。

var colors: Array[Color] = []
var thickness: float = 4.0

func set_colors(cols: Array) -> void:
	colors.clear()
	for c in cols:
		colors.append(c)
	queue_redraw()

func _draw() -> void:
	if colors.is_empty():
		return
	var w := size.x
	var h := size.y
	var n := colors.size()
	var seg_w := w / n
	var t := thickness

	# 上下の枠を属性数で等分し、各区画を対応色で塗る（左→右の分割）
	for i in range(n):
		var x0 := i * seg_w
		var col: Color = colors[i]
		draw_rect(Rect2(x0, 0, seg_w, t), col)          # 上辺
		draw_rect(Rect2(x0, h - t, seg_w, t), col)      # 下辺

	# 左右の辺は端の色に合わせる
	draw_rect(Rect2(0, 0, t, h), colors[0])             # 左辺 = 一番左の色
	draw_rect(Rect2(w - t, 0, t, h), colors[n - 1])     # 右辺 = 一番右の色
