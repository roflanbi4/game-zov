extends Area2D

@export var damage_reduction: float = 0.4

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	var health: HealthComponent = body.get_node_or_null("HealthComponent")
	if health:
		health.in_cover = true

func _on_body_exited(body: Node2D) -> void:
	var health: HealthComponent = body.get_node_or_null("HealthComponent")
	if health:
		health.in_cover = false