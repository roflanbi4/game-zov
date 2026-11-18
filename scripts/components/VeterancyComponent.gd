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