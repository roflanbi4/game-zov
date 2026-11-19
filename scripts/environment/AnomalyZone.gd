class_name AnomalyZone
extends Area2D

enum AnomalyType { VORTEX = 0, THERMAL = 1, EMP = 2 }

@export var anomaly_type: int = AnomalyType.VORTEX
@export var radius: float = 120.0
@export var damage: int = 8

var _vortex_timers: Dictionary = {}
var _emp_original_speeds: Dictionary = {}
var _thermal_timer: float = 0.0

func _ready() -> void:
	if get_node_or_null("CollisionShape2D") == null:
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = radius
		cs.shape = circle
		add_child(cs)

	if get_node_or_null("ColorRect") == null:
		var rect := ColorRect.new()
		rect.size = Vector2(radius * 2.0, radius * 2.0)
		rect.position = Vector2(-radius, -radius)
		match anomaly_type:
			AnomalyType.VORTEX:
				rect.color = Color(0.5, 0.1, 0.8, 0.35)
			AnomalyType.THERMAL:
				rect.color = Color(0.9, 0.3, 0.1, 0.35)
			_:
				rect.color = Color(0.1, 0.6, 0.9, 0.35)
		add_child(rect)

	add_to_group("anomaly_zones")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	_try_sapper_disarm()

	match anomaly_type:
		AnomalyType.VORTEX:
			_process_vortex(delta)
		AnomalyType.THERMAL:
			_process_thermal(delta)
		AnomalyType.EMP:
			pass

func _try_sapper_disarm() -> void:
	for body in get_overlapping_bodies():
		if not (body is Node):
			continue
		var squad: Node = body.get("squad_controller")
		if squad == null or not is_instance_valid(squad):
			continue
		var specialist: SpecialistComponent = squad.get_node_or_null("SpecialistComponent") as SpecialistComponent
		if specialist != null and specialist.specialist_type == SpecialistComponent.Type.SAPPER:
			queue_free()
			return

func _process_vortex(delta: float) -> void:
	for body in get_overlapping_bodies():
		if not (body is CharacterBody2D):
			continue
		var to_center: Vector2 = global_position - body.global_position
		if to_center.length() > 1.0:
			body.velocity = body.velocity.lerp(to_center.normalized() * 140.0, 0.25)

		if not _vortex_timers.has(body):
			_vortex_timers[body] = 0.0
		_vortex_timers[body] = float(_vortex_timers[body]) + delta
		if float(_vortex_timers[body]) >= 1.0:
			_vortex_timers[body] = 0.0
			_apply_damage(body, damage)

func _process_thermal(delta: float) -> void:
	_thermal_timer += delta
	if _thermal_timer < 3.0:
		return
	_thermal_timer = 0.0
	for body in get_overlapping_bodies():
		if body is CharacterBody2D:
			_apply_damage(body, damage * 3)

func _on_body_entered(body: Node) -> void:
	if anomaly_type != AnomalyType.EMP:
		return
	if not (body is CharacterBody2D):
		return
	if body is DroneUnit:
		body.disabled = true
	elif body is VehicleUnit:
		if not _emp_original_speeds.has(body):
			_emp_original_speeds[body] = body.move_speed
		body.move_speed = body.move_speed * 0.3

func _on_body_exited(body: Node) -> void:
	if anomaly_type == AnomalyType.VORTEX:
		_vortex_timers.erase(body)
	if anomaly_type == AnomalyType.EMP:
		if body is DroneUnit:
			body.disabled = false
		elif body is VehicleUnit and _emp_original_speeds.has(body):
			body.move_speed = float(_emp_original_speeds[body])
			_emp_original_speeds.erase(body)

func _apply_damage(body: Node, amount: int) -> void:
	if body.has_method("take_damage"):
		body.take_damage(amount)
	else:
		var health: HealthComponent = body.get_node_or_null("HealthComponent") as HealthComponent
		if health != null:
			health.take_damage(amount)