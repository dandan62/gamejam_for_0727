extends Control
class_name DuelPhaseUI

const DUEL_ANIMATION := preload("res://assets/ui/duel/duel_anim.png")
const SHOT_FRAME_SECONDS := 0.1
const ANIMATION_FRAMES := 5

@onready var gunmen: TextureRect = %Gunmen
@onready var gauge_layer: DuelGaugeLayer = %GaugeLayer
@onready var player_bullet_anchor: Control = %PlayerBulletAnchor
@onready var enemy_bullet_anchor: Control = %EnemyBulletAnchor
@onready var round_won: TextureRect = %RoundWon
@onready var round_lost: TextureRect = %RoundLost
@onready var round_draw: Label = %RoundDraw
@onready var effect_label: Label = %EffectLabel

var _animation_texture: AtlasTexture


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_animation_texture = AtlasTexture.new()
	_animation_texture.atlas = DUEL_ANIMATION
	gunmen.texture = _animation_texture
	_set_animation_frame(0)
	clear_result()


func begin_showdown(
	player_hp: int,
	player_max_hp: int,
	player_shield: int,
	enemy_hp: int,
	enemy_max_hp: int,
	enemy_shield: int
) -> void:
	_set_animation_frame(0)
	clear_result()
	_clear_bullet(player_bullet_anchor)
	_clear_bullet(enemy_bullet_anchor)
	gauge_layer.set_values(
		player_hp,
		player_max_hp,
		player_shield,
		enemy_hp,
		enemy_max_hp,
		enemy_shield,
		true
	)


func present_fight(player_card: CardData, enemy_turn: Dictionary) -> void:
	clear_result()
	_set_animation_frame(0)
	_clear_bullet(player_bullet_anchor)
	_clear_bullet(enemy_bullet_anchor)

	if player_card != null:
		var player_bullet := PrepBulletView.new()
		player_bullet_anchor.add_child(player_bullet)
		player_bullet.setup_card(player_card, false)

	var enemy_bullet := PrepBulletView.new()
	enemy_bullet_anchor.add_child(enemy_bullet)
	enemy_bullet.setup_enemy(enemy_turn)


func play_shot_cycle() -> void:
	for frame_index in range(1, ANIMATION_FRAMES):
		_set_animation_frame(frame_index)
		await get_tree().create_timer(SHOT_FRAME_SECONDS).timeout
	_set_animation_frame(0)


func show_result(state: StringName, effect_text: String) -> void:
	round_won.visible = state == &"won"
	round_lost.visible = state == &"lost"
	round_draw.visible = state == &"draw"
	effect_label.text = effect_text
	effect_label.visible = not effect_text.is_empty()


func clear_result() -> void:
	round_won.visible = false
	round_lost.visible = false
	round_draw.visible = false
	effect_label.visible = false
	effect_label.text = ""


func set_vitals(
	player_hp: int,
	player_max_hp: int,
	player_shield: int,
	enemy_hp: int,
	enemy_max_hp: int,
	enemy_shield: int
) -> void:
	gauge_layer.set_values(
		player_hp,
		player_max_hp,
		player_shield,
		enemy_hp,
		enemy_max_hp,
		enemy_shield
	)


func _set_animation_frame(frame_index: int) -> void:
	if _animation_texture == null:
		return
	var safe_frame := clampi(frame_index, 0, ANIMATION_FRAMES - 1)
	_animation_texture.region = Rect2(safe_frame * 320, 0, 320, 180)


func _clear_bullet(anchor: Control) -> void:
	for child in anchor.get_children():
		child.visible = false
		child.queue_free()
