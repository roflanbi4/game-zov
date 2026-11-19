class_name VeterancyComponent
extends Node

enum Rank { ROOKIE = 0, VETERAN = 1, ELITE = 2 }

@export var rank: int = Rank.ROOKIE
var xp: int = 0

const XP_VETERAN: int = 100
const XP_ELITE: int = 300

var soldier: CharacterBody2D = null
var health_component: HealthComponent = null
var weapon_component: WeaponComponent = null
var morale_component: MoraleComponent = null

var _base_max_hp: int = 0
var _base_attack_damage: int = 0

# XP Bar
var xp_bar: Node2D = null
var xp_bar_bg: ColorRect = null
var xp_bar_fill: ColorRect = null

func _ready() -> void:
	if soldier == null:
		soldier = get_parent() as CharacterBody2D
	if health_component == null and soldier != null:
		health_component = soldier.get_node_or_null("HealthComponent") as HealthComponent
	if weapon_component == null and soldier != null:
		weapon_component = soldier.get_node_or_null("WeaponComponent") as WeaponComponent
	if morale_component == null and soldier != null:
		morale_component = soldier.get_node_or_null("MoraleComponent") as MoraleComponent

	if health_component != null:
		_base_max_hp = health_component.max_hp
	if weapon_component != null:
		_base_attack_damage = weapon_component.attack_damage

	_apply_rank_bonuses()
	_create_xp_bar()

func _create_xp_bar() -> void:
	# Создаём шкалу опыта над бойцом (ребёнок родителя — солдата)
	if soldier == null or xp_bar != null:
		return
	xp_bar = Node2D.new()
	xp_bar.name = "XPBar"
	xp_bar.position = Vector2(-12.0, -17.0)
	xp_bar.z_index = 10
	xp_bar_bg = ColorRect.new()
	xp_bar_bg.size = Vector2(24.0, 3.0)
	xp_bar_bg.color = Color(0.15, 0.15, 0.2, 0.8)
	xp_bar.add_child(xp_bar_bg)
	xp_bar_fill = ColorRect.new()
	xp_bar_fill.size = Vector2(0.0, 3.0)
	xp_bar_fill.color = Color(0.2, 0.75, 1.0)
	xp_bar.add_child(xp_bar_fill)
	soldier.add_child(xp_bar)
	_update_xp_bar_visual()

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	var new_rank: int = rank
	if xp >= XP_ELITE:
		new_rank = Rank.ELITE
	elif xp >= XP_VETERAN:
		new_rank = Rank.VETERAN
	if new_rank > rank:
		rank = new_rank
		_apply_rank_bonuses()
	_update_xp_bar_visual()

func get_rank_name() -> String:
	match rank:
		Rank.VETERAN:
			return "Veteran"
		Rank.ELITE:
			return "Elite"
		_:
			return "Rookie"

func _hp_multiplier() -> float:
	match rank:
		Rank.VETERAN:
			return 1.25
		Rank.ELITE:
			return 1.5
		_:
			return 1.0

func _damage_multiplier() -> float:
	match rank:
		Rank.VETERAN:
			return 1.25
		Rank.ELITE:
			return 1.5
		_:
			return 1.0

func _cowardice_for_rank() -> float:
	match rank:
		Rank.VETERAN:
			return 1.0
		Rank.ELITE:
			return 0.6
		_:
			return 1.5

func _update_xp_bar_visual() -> void:
	if xp_bar_fill == null:
		return
	var progress_xp: int = xp
	if rank == Rank.ELITE:
		xp_bar_fill.size = Vector2(24.0, 3.0)
		xp_bar_fill.color = Color(1.0, 0.85, 0.2)  # золото
	elif rank == Rank.VETERAN:
		# Прогресс от 100 до 300 XP (золото)
		var p: float = float(xp - XP_VETERAN) / float(XP_ELITE - XP_VETERAN)
		xp_bar_fill.size = Vector2(clampf(p, 0.0, 1.0) * 24.0, 3.0)
		xp_bar_fill.color = Color(1.0, 0.85, 0.2)  # золото
	else:
		# Прогресс от 0 до 100 XP (синий)
		var p: float = float(xp) / float(XP_VETERAN)
		xp_bar_fill.size = Vector2(clampf(p, 0.0, 1.0) * 24.0, 3.0)
		xp_bar_fill.color = Color(0.2, 0.75, 1.0)  # синий

func _apply_rank_bonuses() -> void:
	if health_component != null and is_instance_valid(health_component):
		var new_max: int = int(round(_base_max_hp * _hp_multiplier()))
		var delta: int = new_max - health_component.max_hp
		health_component.max_hp = new_max
		health_component.current_hp = clampi(health_component.current_hp + delta, 0, new_max)
	if weapon_component != null and is_instance_valid(weapon_component):
		weapon_component.attack_damage = int(round(_base_attack_damage * _damage_multiplier()))
	if morale_component != null and is_instance_valid(morale_component):
		morale_component.cowardice_multiplier = _cowardice_for_rank()
	_update_xp_bar_visual()