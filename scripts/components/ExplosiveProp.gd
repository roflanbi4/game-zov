extends StaticBody2D

@export var explosion_radius: float = 200.0
@export var explosion_damage: int = 100
@export var hp: int = 50

var exploded: bool = false

func _ready() -> void:
	add_to_group("explosives")
	var health = HealthComponent.new()
	health.name = "HealthComponent"
	health.max_hp = hp
	health.current_hp = hp
	add_child(health)
	health.died.connect(_on_health_died)


func take_damage(amount: int) -> void:
	var health: HealthComponent = get_node_or_null("HealthComponent")
	if health:
		health.take_damage(amount)

func _on_health_died(_soldier: Node2D) -> void:
	if not exploded:
		_explode()

func _explode() -> void:
	exploded = true
	var explosion_area: Area2D = get_node_or_null("ExplosionArea")
	if explosion_area:
		var bodies: Array = explosion_area.get_overlapping_bodies()
		for body in bodies:
			if body is Node2D:
				var health: HealthComponent = body.get_node_or_null("HealthComponent")
				if health:
					var dist: float = global_position.distance_to(body.global_position)
					if dist <= explosion_radius:
						health.take_damage(explosion_damage)
	queue_free()