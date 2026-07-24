extends Control
class_name DuelGaugeLayer

const HEALTH_TEXTURE := preload("res://assets/ui/duel/health_bar_contents.png")
const SHIELD_TEXTURE := preload("res://assets/ui/duel/shield_bar_contents.png")

const PLAYER_BAR := Rect2(55, 97, 46, 5)
const ENEMY_BAR := Rect2(218, 97, 46, 5)
const FILL_SPEED := 1.8

var _player_health := 1.0
var _player_shield := 0.0
var _enemy_health := 1.0
var _enemy_shield := 0.0

var _target_player_health := 1.0
var _target_player_shield := 0.0
var _target_enemy_health := 1.0
var _target_enemy_shield := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func set_values(
	player_hp: int,
	player_max_hp: int,
	player_shield: int,
	enemy_hp: int,
	enemy_max_hp: int,
	enemy_shield: int,
	immediate: bool = false
) -> void:
	_target_player_health = _ratio(player_hp, player_max_hp)
	_target_player_shield = _ratio(player_shield, player_max_hp)
	_target_enemy_health = _ratio(enemy_hp, enemy_max_hp)
	_target_enemy_shield = _ratio(enemy_shield, enemy_max_hp)

	if immediate:
		_player_health = _target_player_health
		_player_shield = _target_player_shield
		_enemy_health = _target_enemy_health
		_enemy_shield = _target_enemy_shield
		set_process(false)
	else:
		set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	var step := FILL_SPEED * delta
	_player_health = move_toward(_player_health, _target_player_health, step)
	_player_shield = move_toward(_player_shield, _target_player_shield, step)
	_enemy_health = move_toward(_enemy_health, _target_enemy_health, step)
	_enemy_shield = move_toward(_enemy_shield, _target_enemy_shield, step)
	queue_redraw()

	if (
		is_equal_approx(_player_health, _target_player_health)
		and is_equal_approx(_player_shield, _target_player_shield)
		and is_equal_approx(_enemy_health, _target_enemy_health)
		and is_equal_approx(_enemy_shield, _target_enemy_shield)
	):
		set_process(false)


func _draw() -> void:
	# The two bars mirror one another: the player fills from the left edge and
	# the enemy fills from the right edge.
	_draw_fill(HEALTH_TEXTURE, PLAYER_BAR, _player_health, false)
	_draw_fill(HEALTH_TEXTURE, ENEMY_BAR, _enemy_health, true)
	_draw_fill(SHIELD_TEXTURE, PLAYER_BAR, _player_shield, false)
	_draw_fill(SHIELD_TEXTURE, ENEMY_BAR, _enemy_shield, true)


func _draw_fill(texture: Texture2D, source: Rect2, ratio: float, mirror: bool) -> void:
	var width := floorf(source.size.x * clampf(ratio, 0.0, 1.0))
	if width <= 0.0:
		return

	var x := source.position.x
	if mirror:
		x += source.size.x - width
	var visible_region := Rect2(x, source.position.y, width, source.size.y)
	draw_texture_rect_region(texture, visible_region, visible_region)


func _ratio(value: int, maximum: int) -> float:
	if maximum <= 0:
		return 0.0
	return clampf(float(value) / float(maximum), 0.0, 1.0)
