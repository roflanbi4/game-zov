class_name LootCrate
extends Area2D

enum LootType { SP_CACHE = 0, MEDKIT = 1, TROPHY_RPG = 2 }

@export var loot_type: int = LootType.SP_CACHE

var _label: Label

func _ready() -> void:
	add_to_group("mission_cleanup")
	add_to_group("loot_crates")
	var rect := ColorRect.new()
	rect.size = Vector2(14.0, 14.0)
	rect.position = Vector2(-7.0, -7.0)
	match loot_type:
		LootType.SP_CACHE:
			rect.color = Color(0.95, 0.75, 0.2, 1.0)
		LootType.MEDKIT:
			rect.color = Color(0.2, 0.8, 0.2, 1.0)
		LootType.TROPHY_RPG:
			rect.color = Color(0.8, 0.4, 0.9, 1.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)

	_label = Label.new()
	_label.text = _get_label_text()
	_label.position = Vector2(-16.0, -22.0)
	_label.add_theme_font_size_override("font_size", 10)
	add_child(_label)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)

func _get_label_text() -> String:
	match loot_type:
		LootType.SP_CACHE:
			return "+45 SP"
		LootType.MEDKIT:
			return "Medkit"
		LootType.TROPHY_RPG:
			return "RPG"
	return ""

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player_units") or body.is_in_group("player_turrets") or body.is_in_group("player_drones"):
		return
	match loot_type:
		LootType.SP_CACHE:
			var eco: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
			if eco != null:
				eco.add_sp(45)
		LootType.MEDKIT:
			_heal_squad(body)
		LootType.TROPHY_RPG:
			_upgrade_weapon(body)
	_show_notification()
	queue_free()

func _heal_squad(body: Node2D) -> void:
	var squad: Node2D = body.get_parent() as Node2D
	var soldiers: Array = []
	if squad is SquadController:
		soldiers = (squad as SquadController).soldiers
	if not soldiers.is_empty():
		for s in soldiers:
			if is_instance_valid(s):
				var health: HealthComponent = s.get_node_or_null("HealthComponent") as HealthComponent
				var morale: MoraleComponent = s.get_node_or_null("MoraleComponent") as MoraleComponent
				if health != null:
					health.current_hp = mini(health.max_hp, health.current_hp + 50)
				if morale != null:
					morale.current_morale = minf(morale.max_morale, morale.current_morale + 25.0)
	else:
		var health: HealthComponent = body.get_node_or_null("HealthComponent") as HealthComponent
		if health != null:
			health.current_hp = mini(health.max_hp, health.current_hp + 50)

func _upgrade_weapon(body: Node2D) -> void:
	var squad: Node2D = body.get_parent() as Node2D
	var soldiers: Array = []
	if squad is SquadController:
		soldiers = (squad as SquadController).soldiers
	if not soldiers.is_empty():
		for s in soldiers:
			if is_instance_valid(s):
				var weapon: WeaponComponent = s.get_node_or_null("WeaponComponent") as WeaponComponent
				if weapon != null:
					weapon.attack_damage += 12
					weapon.attack_range += 60.0
					weapon.is_anti_tank = true
	else:
		var weapon: WeaponComponent = body.get_node_or_null("WeaponComponent") as WeaponComponent
		if weapon != null:
			weapon.attack_damage += 12
			weapon.attack_range += 60.0
			weapon.is_anti_tank = true

func _show_notification() -> void:
	var hud: Node = get_tree().get_first_node_in_group("game_hud")
	if hud != null and hud.has_method("_show_notification"):
		hud.call("_show_notification", "Loot received!")
