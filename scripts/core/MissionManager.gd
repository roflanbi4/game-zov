class_name MissionManager
extends Node

# Step 7: Mission Manager - menu selection, mission construction, win/loss control.
# All missions, enemies, mutants and menus are built programmatically based on main_game.tscn.

enum Mission { NONE, M1, M2, M3, M4, SANDBOX }

@export var mission: Mission = Mission.NONE

var _menu: CanvasLayer
var _objective_label: Label
var _finish_overlay: Node
var _objective_text_override: String = ""

var _mission_start_time: float = 0.0
var _finished: bool = false
var _base: StaticBody2D
var _convoy_trucks: Array[VehicleUnit] = []

const _BUILDER := preload("res://scripts/core/MissionBuilder.gd")

func _ready() -> void:
	_menu = _build_menu()
	get_tree().root.add_child(_menu)

# --- Mission Manager ---

func _build_menu() -> CanvasLayer:
	var menu := CanvasLayer.new()
	menu.name = "MissionMenu"
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)
	var title := Label.new()
	title.text = "EAST RIFT ZONE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Mission Selection"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	vbox.add_child(subtitle)
	var missions: Array = [
[Mission.M1, "[Corps] Mission 1: Perimeter"],
[Mission.M2, "[Corps] Mission 2: Convoy in the fog"],
[Mission.M3, "[Syndicate] Mission 3: Night raid"],
[Mission.M4, "[Syndicate] Mission 4: Heart of the Rift"],
	]
	for entry in missions:
		var btn := Button.new()
		btn.text = str(entry[1])
		btn.custom_minimum_size = Vector2(460, 46)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_mission_selected.bind(int(entry[0])))
		vbox.add_child(btn)
	var sandbox_btn := Button.new()
	sandbox_btn.text = "Sandbox / Skirmish"
	sandbox_btn.custom_minimum_size = Vector2(460, 46)
	sandbox_btn.add_theme_font_size_override("font_size", 18)
	sandbox_btn.pressed.connect(_on_mission_selected.bind(Mission.SANDBOX))
	vbox.add_child(sandbox_btn)
	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(460, 46)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	vbox.add_child(quit_btn)
	return menu

func _on_mission_selected(m: int) -> void:
	_close_menu()
	await _start_mission(m)

func _close_menu() -> void:
	if is_instance_valid(_menu):
		_menu.queue_free()
		_menu = null
# --- Mission launch ---

func _start_mission(m: int) -> void:
	_close_menu()
	mission = m as Mission
	await get_tree().process_frame
	_clear_world()
	await get_tree().process_frame
	_build_base()
	var env: Node2D = preload("res://scripts/environment/ZoneEnvironment.gd").new()
	env.z_index = 0
	get_parent().add_child(env)
	env.generate_map(0)
	match m:
		Mission.M1: _BUILDER.build_mission_1(get_parent(), env)
		Mission.M2: _convoy_trucks = _BUILDER.build_mission_2(get_parent(), env)
		Mission.M3: _base = _BUILDER.build_mission_3(get_parent(), env)
		Mission.M4: _BUILDER.build_mission_4(get_parent(), env)
		Mission.SANDBOX: _BUILDER.build_sandbox(get_parent(), env)
		_: pass
	_mission_start_time = Time.get_ticks_msec() / 1000.0

func _clear_world() -> void:
	var keep: Array[String] = ["MissionManager", "SelectionManager", "Ground", "NavRegion", "GameCamera", "Main"]
	var main: Node = get_parent()
	if main != null:
		for child in main.get_children():
			if child.name not in keep:
				child.queue_free()
	for n in get_tree().get_nodes_in_group("mission_cleanup"):
		if is_instance_valid(n):
			n.queue_free()
	var cm = get_tree().root.get_node_or_null("CanvasModulate")
	if cm != null:
		cm.queue_free()

func _build_base() -> void:
	var eco := EconomyManager.new()
	eco.name = "EconomyManager"
	get_parent().call_deferred("add_child", eco)
	var hud := GameHUD.new()
	hud.name = "GameHUD"
	get_parent().call_deferred("add_child", hud)

	var fog := FogOfWarManager.new()
	fog.name = "FogOfWarManager"
	get_parent().call_deferred("add_child", fog)
	fog.add_to_group("fog_of_war")
	_objective_label = Label.new()
	_objective_label.name = "ObjectiveLabel"
	_objective_label.position = Vector2(230, 15)
	_objective_label.size = Vector2(400, 40)
	_objective_label.add_theme_font_size_override("font_size", 20)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_objective_label.modulate = Color.WHITE
	hud.add_child(_objective_label)

func _set_objective(text: String) -> void:
	_objective_text_override = text
	if is_instance_valid(_objective_label):
		_objective_label.text = "OBJECTIVE: " + text

func _on_base_destroyed(_node: Node2D) -> void:
	if mission == Mission.M3:
		_finish(true)

func _finish(won: bool) -> void:
	if _finished:
		return
	_finished = true
	mission = Mission.NONE
	_show_finish(won)

func _show_finish(won: bool) -> void:
	var layer := CanvasLayer.new()
	layer.name = "FinishOverlay"
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)
	var title := Label.new()
	title.text = "VICTORY!" if won else "DEFEAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4) if won else Color(1.0, 0.3, 0.3))
	vbox.add_child(title)
	var btn := Button.new()
	btn.text = "To mission selection"
	btn.custom_minimum_size = Vector2(300, 50)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(func() -> void: get_tree().reload_current_scene())
	vbox.add_child(btn)
	get_parent().add_child(layer)
	_finish_overlay = layer
