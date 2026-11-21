extends Area2D

var _accum: float = 0.0

func _ready() -> void:
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	for body in get_overlapping_bodies():
		if not (body is Node2D):
			continue
		var groups: Array = body.get_groups()
		if "enemy_units" not in groups and "mutants" not in groups:
			continue
		if not body.has_meta("pre_wire_speed"):
			body.set_meta("pre_wire_speed", body.get("move_speed"))
		body.set("move_speed", float(body.get_meta("pre_wire_speed")) * 0.45)
		_accum += 4.0 * delta
		if _accum >= 1.0:
			_accum -= 1.0
			var health: HealthComponent = body.get_node_or_null("HealthComponent") as HealthComponent
			if health != null:
				health.take_damage(4)
			elif body.has_method("take_damage"):
				body.take_damage(4)

func _on_body_exited(body: Node2D) -> void:
	if body.has_meta("pre_wire_speed"):
		body.set("move_speed", float(body.get_meta("pre_wire_speed")))
		body.remove_meta("pre_wire_speed")