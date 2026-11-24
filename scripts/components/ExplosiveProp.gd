class_name ExplosiveProp
extends StaticBody2D


@export var explosion_radius: float = 200.0
@export var explosion_damage: int = 100
@export var hp: int = 50

var exploded: bool = false

func _ready() -> void:
	add_to_group("explosives")
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	cs.shape = circle
	add_child(cs)

	var rect := ColorRect.new()
	rect.size = Vector2(20.0, 20.0)
	rect.position = Vector2(-10.0, -10.0)
	rect.color = Color(0.85, 0.15, 0.1, 1.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)

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
	var cam: Camera2D = get_tree().get_first_node_in_group("rts_camera") as Camera2D
	if cam != null and cam.has_method("shake"):
		cam.call("shake", 10.0, 0.3)
	var targets: Array = []
	for g in ["player_units", "enemy_units", "mutants"]:
		targets.append_array(get_tree().get_nodes_in_group(g))
	for body in targets:
		if not is_instance_valid(body) or not (body is Node2D):
			continue
		var dist: float = global_position.distance_to((body as Node2D).global_position)
		if dist > explosion_radius:
			continue
		var health: HealthComponent = (body as Node).get_node_or_null("HealthComponent") as HealthComponent
		if body is VehicleUnit:
			(body as VehicleUnit).take_damage(explosion_damage, true)
		elif health != null:
			health.take_damage(explosion_damage)
		elif body.has_method("take_damage"):
			body.take_damage(explosion_damage)
	queue_free()