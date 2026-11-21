class_name HealthComponent
extends Node

@export var max_hp: int = 100
@export var cover_damage_reduction: float = 0.4

var current_hp: int
var cover_count: int = 0
var in_cover: bool:
	get:
		return cover_count > 0

signal died(soldier: Node2D)

func _ready() -> void:
	current_hp = max_hp

func take_damage(amount: int) -> void:
	var actual_damage: int = amount
	if in_cover:
		actual_damage = int(amount * (1.0 - cover_damage_reduction))
	current_hp -= actual_damage

	# Hit Flash: подсветить дочерний ColorRect или самого родителя
	var parent_node: Node = get_parent()
	var flash_target: CanvasItem = null
	if parent_node != null:
		var rect_child: ColorRect = parent_node.get_node_or_null("ColorRect") as ColorRect
		if rect_child != null:
			flash_target = rect_child
		elif parent_node is CanvasItem:
			flash_target = parent_node as CanvasItem
	if flash_target != null and is_instance_valid(flash_target):
		flash_target.modulate = Color(2.5, 2.5, 2.5, 1.0)
		var hit_tween := flash_target.create_tween()
		hit_tween.tween_property(flash_target, "modulate", Color.WHITE, 0.08)

	# Плавающие цифры урона
	if get_tree() != null and get_tree().current_scene != null and parent_node is Node2D:
		var dmg_label := Label.new()
		dmg_label.text = "-" + str(actual_damage)
		dmg_label.z_index = 60
		dmg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dmg_label.add_theme_font_size_override("font_size", 13)
		if actual_damage >= 35:
			dmg_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.15, 1.0))
		else:
			dmg_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.9, 1.0))
		var parent_2d: Node2D = parent_node as Node2D
		var start_pos: Vector2 = parent_2d.global_position - Vector2(12.0, 20.0)
		dmg_label.position = start_pos
		get_tree().current_scene.add_child(dmg_label)
		var dmg_tween := dmg_label.create_tween()
		dmg_tween.tween_property(dmg_label, "position", start_pos + Vector2(0.0, -24.0), 0.55)
		dmg_tween.parallel().tween_property(dmg_label, "modulate:a", 0.0, 0.55)
		dmg_tween.tween_callback(dmg_label.queue_free)

	if get_parent() != null:
		var morale: MoraleComponent = get_parent().get_node_or_null("MoraleComponent") as MoraleComponent
		if morale != null:
			morale.reduce_morale(float(amount))
	# Шок от крупного урона: дополнительный урон морали
	if actual_damage >= 25 and get_parent() != null:
		var morale_shock: MoraleComponent = get_parent().get_node_or_null("MoraleComponent") as MoraleComponent
		if morale_shock != null:
			morale_shock.reduce_morale(10.0)
	if current_hp <= 0:
		current_hp = 0
		died.emit(get_parent() as Node2D)