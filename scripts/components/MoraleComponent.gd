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

var _panic_retreat_timer: float = 0.0
var _last_stand: bool = false
var _cover_indicator: ColorRect = null
var veterancy_component: VeterancyComponent = null
@export var retreat_speed: float = 180.0

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
	if soldier != null:
		veterancy_component = soldier.get_node_or_null("VeterancyComponent") as VeterancyComponent

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

	_update_last_stand()
	_update_panic_retreat(delta)
	_update_cover_indicator()

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
		if _last_stand:
			soldier.move_speed = _base_move_speed
		elif is_panicked:
			soldier.move_speed = _base_move_speed * 0.6
		else:
			soldier.move_speed = _base_move_speed
	if weapon_component != null and is_instance_valid(weapon_component):
		if _last_stand:
			weapon_component.attack_cooldown = _base_attack_cooldown * 0.65
		elif is_panicked:
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

func _update_last_stand() -> void:
	if soldier == null or not is_instance_valid(soldier):
		return
	if veterancy_component == null:
		veterancy_component = soldier.get_node_or_null("VeterancyComponent") as VeterancyComponent
	var rank: int = veterancy_component.rank if veterancy_component != null else 0

	var has_radio: bool = false
	var squad: Node2D = soldier.get_parent() as Node2D
	if squad != null:
		var spec: SpecialistComponent = squad.get_node_or_null("SpecialistComponent") as SpecialistComponent
		if spec != null and spec.specialist_type == SpecialistComponent.Type.RADIO:
			has_radio = true

	var hp_low: bool = false
	if health_component != null and health_component.max_hp > 0:
		hp_low = float(health_component.current_hp) / float(health_component.max_hp) < 0.35

	var should_last_stand: bool = (rank >= 1 or has_radio) and hp_low

	if should_last_stand and not _last_stand:
		_last_stand = true
		is_panicked = false
		var rect: ColorRect = soldier.get_node_or_null("ColorRect") as ColorRect
		if rect != null:
			rect.color = Color(1.0, 0.85, 0.2, 1.0)
	elif not should_last_stand and _last_stand:
		_last_stand = false
		var rect: ColorRect = soldier.get_node_or_null("ColorRect") as ColorRect
		if rect != null:
			rect.color = Color(0.2, 0.9, 0.3, 1.0)

func _update_panic_retreat(delta: float) -> void:
	if soldier == null or not is_instance_valid(soldier):
		return
	if _last_stand:
		return
	if veterancy_component == null:
		veterancy_component = soldier.get_node_or_null("VeterancyComponent") as VeterancyComponent
	var rank: int = veterancy_component.rank if veterancy_component != null else 0

	if current_morale < panic_threshold and rank == 0:
		_panic_retreat_timer += delta
		if _panic_retreat_timer >= 1.5:
			_panic_retreat_timer = 0.0
			if current_morale < 45.0:
				soldier.set_destination(soldier.global_position.move_toward(Vector2(200.0, 400.0), retreat_speed))

func _update_cover_indicator() -> void:
	if soldier == null or not is_instance_valid(soldier):
		return
	var health: HealthComponent = soldier.get_node_or_null("HealthComponent") as HealthComponent
	var cover: bool = health != null and health.in_cover

	if cover and _cover_indicator == null:
		_cover_indicator = ColorRect.new()
		_cover_indicator.name = "CoverIndicator"
		_cover_indicator.size = Vector2(6.0, 6.0)
		_cover_indicator.position = Vector2(-3.0, -3.0)
		_cover_indicator.color = Color.BLUE
		_cover_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		soldier.add_child(_cover_indicator)
	elif not cover and _cover_indicator != null:
		_cover_indicator.queue_free()
		_cover_indicator = null