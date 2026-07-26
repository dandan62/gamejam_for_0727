extends Control
class_name BeforeFightUI

signal ready_pressed
signal insert_sound_requested
signal gunshot_requested

const DECK_COLUMNS := 5
const DECK_CELL_SIZE := Vector2(46, 72)
const DECK_BULLET_TOP_PADDING := 17.0
const HOVER_COLOR := Color(1.2, 1.12, 0.9, 1.0)
const BULLET_HOLE_PRE_TEXTURE := preload("res://assets/ui/title/bullet_hole_pre.png")
const BULLET_HOLE_TEXTURE := preload("res://assets/ui/title/bullet_hole.png")
const IMPACT_FRAME_SECONDS := 0.1
const HOLE_LIFETIME_SECONDS := 15.0
const HOLE_FADE_SECONDS := 3.0
const MAX_ACTIVE_HOLES := 64

@onready var health_fill: PrepHealthFill = %HealthFill
@onready var shield_fill: PrepShieldFill = %ShieldFill
@onready var health_text: Label = %HealthText
@onready var battle_count: Label = %BattleCount
@onready var deck_art: TextureRect = %DeckArt
@onready var ready_art: TextureRect = %ReadyArt
@onready var deck_button: Button = %DeckButton
@onready var ready_button: Button = %ReadyButton
@onready var deck_overlay: Control = %DeckOverlay
@onready var deck_dismiss_button: Button = %DeckDismissButton
@onready var deck_grid: GridContainer = %DeckGrid
@onready var board_click_area: Control = %BoardClickArea
@onready var bullet_hole_layer: Control = %BulletHoleLayer

var _active_holes: Array[TextureRect] = []


func _ready() -> void:
	size = Vector2(320, 180)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	deck_button.pressed.connect(_open_deck)
	ready_button.pressed.connect(_on_ready_pressed)
	deck_dismiss_button.pressed.connect(_close_deck)
	deck_button.mouse_entered.connect(_on_art_hovered.bind(deck_art))
	deck_button.mouse_exited.connect(_on_art_unhovered.bind(deck_art))
	ready_button.mouse_entered.connect(_on_art_hovered.bind(ready_art))
	ready_button.mouse_exited.connect(_on_art_unhovered.bind(ready_art))
	board_click_area.gui_input.connect(_on_board_click_area_gui_input)
	deck_overlay.visible = false


func configure(
	hp: int,
	max_hp: int,
	shield: int,
	battle_index: int,
	total_battles: int
) -> void:
	var hp_ratio := 0.0
	var shield_ratio := 0.0
	if max_hp > 0:
		hp_ratio = float(hp) / float(max_hp)
		shield_ratio = float(shield) / float(max_hp)
	health_fill.set_ratio(hp_ratio)
	shield_fill.set_ratio(shield_ratio)
	health_text.text = "%d/%d" % [hp, max_hp]
	battle_count.text = "Battles: %d/%d" % [battle_index, total_battles]
	_close_deck()


func _open_deck() -> void:
	insert_sound_requested.emit()
	for child in deck_grid.get_children():
		child.queue_free()

	var deck := GameManager.get_full_deck()
	deck.sort_custom(
		func(a: CardData, b: CardData) -> bool:
			if a.card_type != b.card_type:
				return a.card_type < b.card_type
			return a.id < b.id
	)

	for card in deck:
		var cell := Control.new()
		cell.custom_minimum_size = DECK_CELL_SIZE
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		deck_grid.add_child(cell)

		var bullet := PrepBulletView.new()
		bullet.position = Vector2(-1, DECK_BULLET_TOP_PADDING)
		cell.add_child(bullet)
		bullet.setup_card(card, false)

	deck_overlay.visible = true


func _close_deck() -> void:
	deck_overlay.visible = false


func _on_ready_pressed() -> void:
	gunshot_requested.emit()
	ready_pressed.emit()


func _on_board_click_area_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if not _is_sign_at(mouse_event.position):
		return

	var canvas_position := board_click_area.position + mouse_event.position
	_spawn_bullet_hole(canvas_position)
	board_click_area.accept_event()


func _is_sign_at(local_position: Vector2) -> bool:
	var sign_polygon := PackedVector2Array([
		Vector2(6, 0),
		Vector2(164, 0),
		Vector2(170, 6),
		Vector2(170, 59),
		Vector2(164, 65),
		Vector2(6, 65),
		Vector2(0, 59),
		Vector2(0, 6),
	])
	return Geometry2D.is_point_in_polygon(local_position, sign_polygon)


func _spawn_bullet_hole(canvas_position: Vector2) -> void:
	var hole := TextureRect.new()
	hole.texture = BULLET_HOLE_PRE_TEXTURE
	hole.position = Vector2(
		roundf(canvas_position.x - BULLET_HOLE_TEXTURE.get_width() * 0.5),
		roundf(canvas_position.y - BULLET_HOLE_TEXTURE.get_height() * 0.5)
	)
	hole.size = BULLET_HOLE_TEXTURE.get_size()
	hole.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hole.stretch_mode = TextureRect.STRETCH_KEEP
	hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hole.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bullet_hole_layer.add_child(hole)
	_active_holes.append(hole)
	gunshot_requested.emit()

	if _active_holes.size() > MAX_ACTIVE_HOLES:
		var oldest: TextureRect = _active_holes.pop_front() as TextureRect
		if is_instance_valid(oldest):
			oldest.queue_free()

	var hold_seconds := maxf(
		0.0,
		HOLE_LIFETIME_SECONDS - HOLE_FADE_SECONDS - IMPACT_FRAME_SECONDS
	)
	var lifecycle := hole.create_tween()
	lifecycle.tween_interval(IMPACT_FRAME_SECONDS)
	lifecycle.tween_callback(func() -> void:
		if is_instance_valid(hole):
			hole.texture = BULLET_HOLE_TEXTURE
	)
	lifecycle.tween_interval(hold_seconds)
	lifecycle.tween_property(hole, "modulate:a", 0.0, HOLE_FADE_SECONDS)
	lifecycle.tween_callback(func() -> void:
		_active_holes.erase(hole)
		if is_instance_valid(hole):
			hole.queue_free()
	)


func _on_art_hovered(art: TextureRect) -> void:
	art.self_modulate = HOVER_COLOR


func _on_art_unhovered(art: TextureRect) -> void:
	art.self_modulate = Color.WHITE


func _unhandled_input(event: InputEvent) -> void:
	if deck_overlay.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_deck()
