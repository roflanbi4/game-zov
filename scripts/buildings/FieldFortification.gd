class_name FieldFortification
extends StaticBody2D

enum FortType { SANDBAGS = 0, BARBED_WIRE = 1, AUTO_TURRET = 2 }

@export var fort_type: int = FortType.SANDBAGS

var health_component: HealthComponent

func _ready() -> void:
	add_to_group("mission_cleanup")
	health_component = HealthComponent.new()
	health_component.name = "HealthComponent"
	add_child(health_component)
	health_component.died.connect(_on_died)
	match fort_type:
		FortType.SANDBAGS:
			_build_sandbags()
		FortType.BARBED_WIRE:
			_build_barbed_wire()
		FortType.AUTO_TURRET:
			_build_auto_turret()

func _build_sandbags() -> void:
	health_component.max_hp = 180
	health_component.current_hp = 180
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(48.0, 16.0)
	shape.shape = rect_shape
	add_child(shape)
	var visual := ColorRect.new()
	visual.size = Vector2(48.0, 16.0)
	visual.position = Vector2(-24.0, -8.0)
	visual.color = Color(0.76, 0.68, 0.48)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)
	var cover_zone := Area2D.new()
	cover_zone.name = "CoverZone"
	cover_zone.set_script(preload("res://scripts/components/CoverZone.gd"))
	var cover_shape := CollisionShape2D.new()
	var cover_circle := CircleShape2D.new()
	cover_circle.radius = 45.0
	cover_shape.shape = cover_circle
	cover_zone.add_child(cover_shape)
	add_child(cover_zone)

func _build_barbed_wire() -> void:
	health_component.max_hp = 100
	health_component.current_hp = 100
	collision_layer = 0
	var visual := ColorRect.new()
	visual.size = Vector2(56.0, 14.0)
	visual.position = Vector2(-28.0, -7.0)
	visual.color = Color(0.55, 0.58, 0.62)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)
	var damage_zone := Area2D.new()
	damage_zone.name = "WireDamageZone"
	var zone_shape := CollisionShape2D.new()
	var zone_rect := RectangleShape2D.new()
	zone_rect.size = Vector2(56.0, 22.0)
	zone_shape.shape = zone_rect
	damage_zone.add_child(zone_shape)
	damage_zone.set_script(preload("res://scripts/buildings/WireDamage.gd"))
	add_child(damage_zone)

func _build_auto_turret() -> void:
	health_component.max_hp = 220
	health_component.current_hp = 220
	add_to_group("player_units")
	add_to_group("player_turrets")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 11.0
	shape.shape = circle
	add_child(shape)
	var visual := ColorRect.new()
	visual.size = Vector2(22.0, 22.0)
	visual.position = Vector2(-11.0, -11.0)
	visual.color = Color(0.25, 0.65, 0.85)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)
	var weapon := WeaponComponent.new()
	weapon.name = "WeaponComponent"
	weapon.attack_range = 380.0
	weapon.attack_damage = 22
	weapon.attack_cooldown = 0.65
	weapon.target_group = "enemy_units"
	weapon.burst_enabled = false
	weapon.set_meta("morale_penalty", 12)
	add_child(weapon)

func _on_died(_body: Node2D) -> void:
	queue_free()