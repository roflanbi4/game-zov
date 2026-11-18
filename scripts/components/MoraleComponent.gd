class_name MoraleComponent
extends Node

@export var max_morale: float = 100.0
@export var panic_threshold: float = 30.0
@export var recovery_rate: float = 5.0
@export var combat_timeout: float = 3.0

var current_morale: float = 100.0
var is_panicked: bool = false
var cowardice_multiplier: float = 1.5

var soldier: CharacterBody2D = null
var health_component: HealthComponent = null
var weapon_component: WeaponComponent = null

var _base_move_speed: float = 0.0
var _base_attack_cooldown: float = 0.0
var _combat_timer: float = 0.0
var _medic_recovery_bonus: float = 0.0

var _bar_root: Node2D = null
var _bar_bg: ColorRect = null
var _bar_fg: ColorRect = null

func _ready() -> void:
	if soldier == null:
		soldier = get_parent() as CharacterBody2D
	if health_component == null and soldier != null:
		health_component = soldier.get_node_or_null("HealthComponent") as HealthComponent
	if weapon_component == null and soldier != null:
		weapon_component = soldier.get_node_or_null("WeaponComponent") as WeaponComponent
	if soldier != null and _base_move_speed == 0.0:
		_base_move_speed = soldier.move_speed
	if weapon_component != null and _base_attack_cooldown == 0.0:
		_base_attack_cooldown = weapon_component.attack_cooldown

	current_morale = max_morale
	_create_bar()
	_apply_panic_effects()
	_update_bar()

func _process(delta: float) -> void:
	if _combat_timer > 0.0:
		_combat_timer = maxf(0.0, _combat_timer - delta)
	else:
		var rate: float = recovery_rate + _medic_recovery_bonus
		current_morale = minf(max_morale, current_morale + rate * delta)
		_update_panic_state()

	_apply_panic_effects()
	_update_bar()

func reduce_morale(amount: float) -> void:
	if amount <= 0.0:
		return
	var actual: float = amount * cowardice_multiplier
	if health_component != null and health_component.in_cover:
		actual *= 0.5
	current_morale = clampf(current_morale - actual, 0.0, max_morale)
	_combat_timer = combat_timeout
	_update_panic_state()

func set_medic_recovery_bonus(bonus: float) -> void:
	_medic_recovery_bonus = bonus

func _update_panic_state() -> void:
	var should_panic: bool = current_morale < panic_threshold
	if should_panic != is_panicked:
		is_panicked = should_panic

func _apply_panic_effects() -> void:
	if soldier != null and is_instance_valid(soldier):
		if is_panicked:
			soldier.move_speed = _base_move_speed * 0.6
		else:
			soldier.move_speed = _base_move_speed
	if weapon_component != null and is_instance_valid(weapon_component):
		if is_panicked:
			weapon_component.attack_cooldown = _base_attack_cooldown * 2.0
		else:
			weapon_component.attack_cooldown = _base_attack_cooldown

func _create_bar() -> void:
	if soldier == null:
		return
	_bar_root = Node2D.new()
	_bar_root.name = "MoraleBar"
	_bar_root.position = Vector2(-12.0, -22.0)
	soldier.add_child(_bar_root)

	_bar_bg = ColorRect.new()
	_bar_bg.size = Vector2(24.0, 4.0)
	_bar_bg.color = Color(0.15, 0.15, 0.15, 0.85)
	_bar_root.add_child(_bar_bg)

	_bar_fg = ColorRect.new()
	_bar_fg.size = Vector2(24.0, 4.0)
	_bar_fg.color = Color.GREEN
	_bar_root.add_child(_bar_fg)

func _update_bar() -> void:
	if _bar_fg == null:
		return
	var ratio: float = 0.0
	if max_morale > 0.0:
		ratio = clampf(current_morale / max_morale, 0.0, 1.0)
	_bar_fg.size.x = 24.0 * ratio
	_update_bar_color()

func _update_bar_color() -> void:
	if _bar_fg == null:
		return
	if is_panicked:
		_bar_fg.color = Color.RED
	elif current_morale < 50.0:
		_bar_fg.color = Color.YELLOW
	else:
		_bar_fg.color = Color.GREEN