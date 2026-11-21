class_name SpecialistComponent
extends Node

enum Type { NONE = 0, MEDIC = 1, SAPPER = 2, RADIO = 3 }

@export var specialist_type: int = Type.NONE

var squad_controller: Node2D = null
var _radio_applied: bool = false
var _heal_accum: float = 0.0

func _ready() -> void:
	if squad_controller == null:
		squad_controller = get_parent() as Node2D
	if specialist_type == Type.RADIO:
		_apply_radio_bonus()
	if specialist_type != Type.NONE:
		_attach_specialist_badge()
	if specialist_type != Type.MEDIC:
		_reset_medic_bonuses()

func _attach_specialist_badge() -> void:
	if squad_controller == null or not is_instance_valid(squad_controller):
		return
	var soldiers: Array = squad_controller.get("soldiers")
	if soldiers == null or soldiers.is_empty():
		return
	var color: Color = Color.WHITE
	match specialist_type:
		Type.MEDIC:
			color = Color(0.1, 1.0, 0.3, 1.0)
		Type.SAPPER:
			color = Color(1.0, 0.55, 0.0, 1.0)
		Type.RADIO:
			color = Color(0.0, 0.85, 1.0, 1.0)
		_:
			return
	for s in soldiers:
		var soldier: Node2D = s as Node2D
		if soldier == null or not is_instance_valid(soldier):
			continue
		var old_badge: ColorRect = soldier.get_node_or_null("SpecialistBadge") as ColorRect
		if old_badge != null:
			old_badge.queue_free()
		var badge := ColorRect.new()
		badge.name = "SpecialistBadge"
		badge.size = Vector2(8.0, 8.0)
		badge.position = Vector2(-4.0, -18.0)
		badge.color = color
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		soldier.add_child(badge)

func _process(delta: float) -> void:
	if squad_controller == null or not is_instance_valid(squad_controller):
		return
	var soldiers: Array = squad_controller.get("soldiers")
	if soldiers == null:
		return
	if specialist_type == Type.MEDIC:
		_process_medic(delta, soldiers)

func _process_medic(delta: float, soldiers: Array) -> void:
	_heal_accum += 4.0 * delta
	var heal_tick: int = 0
	while _heal_accum >= 1.0:
		_heal_accum -= 1.0
		heal_tick += 1
	if heal_tick <= 0:
		heal_tick = 0

	for i in range(soldiers.size()):
		var soldier: Node2D = soldiers[i] as Node2D
		if soldier == null or not is_instance_valid(soldier):
			continue
		var health: HealthComponent = soldier.get_node_or_null("HealthComponent") as HealthComponent
		var morale: MoraleComponent = soldier.get_node_or_null("MoraleComponent") as MoraleComponent

		var has_nearby_ally: bool = false
		for j in range(soldiers.size()):
			if i == j:
				continue
			var other: Node2D = soldiers[j] as Node2D
			if other != null and is_instance_valid(other):
				if soldier.global_position.distance_to(other.global_position) <= 100.0:
					has_nearby_ally = true
					break

		if has_nearby_ally:
			if health != null and heal_tick > 0:
				health.current_hp = mini(health.max_hp, health.current_hp + heal_tick)
			if morale != null:
				morale.set_medic_recovery_bonus(2.0)
		else:
			if morale != null:
				morale.set_medic_recovery_bonus(0.0)

func _apply_radio_bonus() -> void:
	if _radio_applied:
		return
	if squad_controller == null:
		return
	var soldiers: Array = squad_controller.get("soldiers")
	if soldiers == null:
		return
	for s in soldiers:
		var soldier: Node2D = s as Node2D
		if soldier == null or not is_instance_valid(soldier):
			continue
		var weapon: WeaponComponent = soldier.get_node_or_null("WeaponComponent") as WeaponComponent
		if weapon == null:
			continue
		if not weapon.has_meta("base_attack_range"):
			weapon.set_meta("base_attack_range", weapon.attack_range)
		var base_range: float = float(weapon.get_meta("base_attack_range"))
		weapon.attack_range = base_range * 1.25
		var detection: Area2D = weapon.get_node_or_null("DetectionArea") as Area2D
		if detection != null and detection.get_child_count() > 0:
			var shape_node: Node = detection.get_child(0)
			if shape_node is CollisionShape2D:
				var circle: CircleShape2D = (shape_node as CollisionShape2D).shape as CircleShape2D
				if circle != null:
					circle.radius = weapon.attack_range
	_radio_applied = true

func _reset_medic_bonuses() -> void:
	if squad_controller == null:
		return
	var soldiers: Array = squad_controller.get("soldiers")
	if soldiers == null:
		return
	for s in soldiers:
		var soldier: Node2D = s as Node2D
		if soldier == null or not is_instance_valid(soldier):
			continue
		var morale: MoraleComponent = soldier.get_node_or_null("MoraleComponent") as MoraleComponent
		if morale != null:
			morale.set_medic_recovery_bonus(0.0)

func disarm_anomaly(anomaly: Node) -> bool:
	if specialist_type != Type.SAPPER:
		return false
	if anomaly != null and is_instance_valid(anomaly):
		anomaly.queue_free()
		return true
	return false

func place_mine(position: Vector2) -> Node2D:
	if specialist_type != Type.SAPPER:
		return null
	var mine: Area2D = Area2D.new()
	mine.name = "Mine"

	var rect := ColorRect.new()
	rect.size = Vector2(8.0, 8.0)
	rect.position = Vector2(-4.0, -4.0)
	rect.color = Color(0.8, 0.4, 0.1, 1.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mine.add_child(rect)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	mine.add_child(shape)

	mine.global_position = position
	mine.body_entered.connect(_on_mine_body_entered.bind(mine))

	var tree: SceneTree = get_tree()
	if tree != null and tree.current_scene != null:
		tree.current_scene.add_child(mine)
	else:
		add_child(mine)
	return mine

func _on_mine_body_entered(body: Node2D, mine: Area2D) -> void:
	if not is_instance_valid(mine):
		return
	var groups: Array = body.get_groups()
	if "enemy_units" not in groups and "enemy_vehicles" not in groups:
		return
	var mine_pos: Vector2 = mine.global_position
	var cam: Camera2D = get_tree().get_first_node_in_group("rts_camera") as Camera2D
	if cam != null and cam.has_method("shake"):
		cam.call("shake", 10.0, 0.3)
	var damage: int = 120
	var radius: float = 70.0

	var enemies: Array = get_tree().get_nodes_in_group("enemy_units")
	enemies.append_array(get_tree().get_nodes_in_group("enemy_vehicles"))
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy is Node2D:
			if mine_pos.distance_to(enemy.global_position) <= radius:
				var health: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
				if health != null:
					health.take_damage(damage)
				elif enemy.has_method("take_damage"):
					enemy.take_damage(damage)
	mine.queue_free()

func build_fortification(pos: Vector2, fort_type: int, rot: float = 0.0) -> void:
	if specialist_type != Type.SAPPER:
		return
	var fort := FieldFortification.new()
	fort.fort_type = fort_type
	fort.rotation = rot
	get_tree().current_scene.add_child(fort)
	fort.global_position = pos
