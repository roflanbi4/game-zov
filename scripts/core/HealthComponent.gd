class_name HealthComponent
extends Node

@export var max_hp: int = 100
@export var cover_damage_reduction: float = 0.4

var current_hp: int
var in_cover: bool = false

signal died(soldier: Node2D)

func _ready() -> void:
	current_hp = max_hp

func take_damage(amount: int) -> void:
	var actual_damage: int = amount
	if in_cover:
		actual_damage = int(amount * (1.0 - cover_damage_reduction))
	current_hp -= actual_damage
	if get_parent() != null:
		var morale: MoraleComponent = get_parent().get_node_or_null("MoraleComponent") as MoraleComponent
		if morale != null:
			morale.reduce_morale(float(amount))
	if current_hp <= 0:
		current_hp = 0
		died.emit(get_parent() as Node2D)