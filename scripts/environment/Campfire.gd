class_name Campfire extends Node2D

var _pulse: float = 0.0

func _ready() -> void:
	add_to_group("campfires")
	add_to_group("mission_cleanup")

func _process(delta: float) -> void:
	# Пульсация огонька
	_pulse += delta * 3.0
	var a: float = clampf(0.7 + 0.3 * sin(_pulse), 0.6, 1.0)
	var flame: ColorRect = get_node_or_null("Flame") as ColorRect
	if flame != null:
		flame.modulate.a = a

	# Регенерация морали союзникам в радиусе 95
	for u in get_tree().get_nodes_in_group("player_units"):
		if not is_instance_valid(u) or not (u is Node2D):
			continue
		var dist: float = global_position.distance_to((u as Node2D).global_position)
		if dist <= 95.0:
			var morale: MoraleComponent = u.get_node_or_null("MoraleComponent") as MoraleComponent
			if morale != null:
				morale.current_morale = minf(morale.max_morale, morale.current_morale + 3.0 * delta)