class_name ArtifactPickup
extends Area2D

enum BuffType { SPEED = 0, HP = 1 }

@export var buff_type: int = BuffType.SPEED

var picked_up: bool = false
var affected_squad: Node = null

func _ready() -> void:
	if get_node_or_null("CollisionShape2D") == null:
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 18.0
		cs.shape = circle
		add_child(cs)

	if get_node_or_null("ColorRect") == null:
		var rect := ColorRect.new()
		rect.size = Vector2(20.0, 20.0)
		rect.position = Vector2(-10.0, -10.0)
		rect.color = Color(0.9, 0.8, 0.2, 0.9)
		add_child(rect)

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if picked_up:
		return
	if not body.is_in_group("player_units"):
		return
	var squad: Node = body.get("squad_controller")
	if squad == null or not is_instance_valid(squad) or not squad.is_in_group("player_squads"):
		return

	picked_up = true
	affected_squad = squad

	for child in get_children():
		if child is CollisionShape2D:
			child.disabled = true
		if child is ColorRect:
			child.visible = false

	_apply_buff(squad)

func _apply_buff(squad: Node) -> void:
	var soldiers: Array = squad.get("soldiers")
	if soldiers == null:
		return
	for s in soldiers:
		if not is_instance_valid(s):
			continue
		if buff_type == BuffType.SPEED:
			if not s.has_meta("base_move_speed"):
				s.set_meta("base_move_speed", s.move_speed)
			var base_speed: float = float(s.get_meta("base_move_speed"))
			s.move_speed = base_speed * 1.3
		else:
			var health: HealthComponent = s.get_node_or_null("HealthComponent") as HealthComponent
			if health != null:
				var old_max: int = health.max_hp
				health.max_hp = int(round(old_max * 1.3))
				health.current_hp += health.max_hp - old_max

func _process(delta: float) -> void:
	if not picked_up or affected_squad == null or not is_instance_valid(affected_squad):
		return
	var soldiers: Array = affected_squad.get("soldiers")
	if soldiers == null:
		return
	for s in soldiers:
		if not is_instance_valid(s):
			continue
		var morale: MoraleComponent = s.get_node_or_null("MoraleComponent") as MoraleComponent
		if morale != null:
			morale.current_morale = maxf(0.0, morale.current_morale - 2.0 * delta)