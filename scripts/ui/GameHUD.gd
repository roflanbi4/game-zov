class_name GameHUD
extends CanvasLayer

var _sp_label: Label
var _day_night_btn: Button
var _is_night: bool = false
var _eco: EconomyManager

const GRENADE_MAX_RANGE: float = 260.0
const MINE_MAX_RANGE: float = 65.0
const BUILD_MAX_RANGE: float = 85.0

# Notification popup
var _notification_label: Label = null
var _notification_timer: float = 0.0

const _SQUAD_SCRIPT := preload("res://scripts/core/SquadController.gd")
const _VEHICLE_SCRIPT := preload("res://scripts/units/VehicleUnit.gd")
const _DRONE_SCRIPT := preload("res://scripts/units/DroneUnit.gd")
const _MUTANT_SPAWNER_SCRIPT := preload("res://scripts/ai/MutantWaveSpawner.gd")

func _ready() -> void:
	add_to_group("game_hud")
	_eco = get_tree().get_first_node_in_group("economy") as EconomyManager
	if _eco != null:
		_eco.sp_changed.connect(_on_sp_changed)

	# Top Panel: SP counter + Day/Night toggle
	var panel := PanelContainer.new()
	panel.name = "HUDPanel"
	panel.position = Vector2(10, 10)
	panel.size = Vector2(200, 80)
	add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	_sp_label = Label.new()
	_sp_label.name = "SPLabel"
	_sp_label.text = "SP: 200"
	vbox.add_child(_sp_label)

	_day_night_btn = Button.new()
	_day_night_btn.name = "DayNightBtn"
	_day_night_btn.text = "Night"
	_day_night_btn.size = Vector2(200, 30)
	_day_night_btn.pressed.connect(_on_day_night_toggled)
	vbox.add_child(_day_night_btn)

	var speed_hbox := HBoxContainer.new()
	var pause_btn := Button.new()
	pause_btn.text = "Pause"
	pause_btn.size = Vector2(40, 24)
	pause_btn.pressed.connect(func() -> void: Engine.time_scale = 0.0)
	speed_hbox.add_child(pause_btn)
	var btn_1x := Button.new()
	btn_1x.text = "1x"
	btn_1x.size = Vector2(40, 24)
	btn_1x.pressed.connect(func() -> void: Engine.time_scale = 1.0)
	speed_hbox.add_child(btn_1x)
	var btn_2x := Button.new()
	btn_2x.text = "2x"
	btn_2x.size = Vector2(40, 24)
	btn_2x.pressed.connect(func() -> void: Engine.time_scale = 2.0)
	speed_hbox.add_child(btn_2x)
	vbox.add_child(speed_hbox)

	# Reinforcement panel
	var rein_panel := HUDReinforcementPanel.new()
	rein_panel.name = "HUDReinforcementPanel"
	add_child(rein_panel)

	# Ability panel
	var abil_panel := HUDAbilityPanel.new()
	abil_panel.name = "HUDAbilityPanel"
	add_child(abil_panel)

	_update_sp_label()

	# Debug panel: quick enemy spawn (top right)
	var debug_panel := PanelContainer.new()
	debug_panel.name = "EnemyDebugPanel"
	debug_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	debug_panel.offset_left = -220
	debug_panel.offset_top = 10
	debug_panel.offset_right = -10
	debug_panel.offset_bottom = 175
	add_child(debug_panel)

	var debug_vbox := VBoxContainer.new()
	debug_panel.add_child(debug_vbox)

	var debug_label := Label.new()
	debug_label.text = "[Debug: Spawn Enemy]"
	debug_vbox.add_child(debug_label)

	var squad_btn := Button.new()
	squad_btn.text = "+ Enemy: Squad"
	squad_btn.pressed.connect(_on_debug_spawn_enemy_squad)
	debug_vbox.add_child(squad_btn)

	var btr_btn := Button.new()
	btr_btn.text = "+ Enemy: BTR"
	btr_btn.pressed.connect(_on_debug_spawn_btr)
	debug_vbox.add_child(btr_btn)

	var dbg_drone_btn := Button.new()
	dbg_drone_btn.text = "+ Enemy: FPV Drone"
	dbg_drone_btn.pressed.connect(_on_debug_spawn_fpv_drone)
	debug_vbox.add_child(dbg_drone_btn)

	var mutant_btn := Button.new()
	mutant_btn.text = "+ Mutants"
	mutant_btn.pressed.connect(_on_debug_spawn_mutants)
	debug_vbox.add_child(mutant_btn)

	var mm: MissionManager = get_parent().get_node_or_null("MissionManager") as MissionManager
	if mm != null and _day_night_btn != null:
		_day_night_btn.visible = (mm.mission == MissionManager.Mission.SANDBOX)

	# Minimap (bottom right)
	var minimap := HUDMinimap.new()
	minimap.name = "HUDMinimap"
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= 0.0:
		vp = Vector2(1280.0, 720.0)
	minimap.position = Vector2(vp.x - 250.0, vp.y - 145.0)
	add_child(minimap)

func _on_sp_changed(_new_amount: int) -> void:
	_update_sp_label()

func _update_sp_label() -> void:
	if _sp_label != null and _eco != null:
		_sp_label.text = "SP: " + str(_eco.get_sp())
func _process(delta: float) -> void:
	if _notification_timer > 0.0:
		_notification_timer -= delta
		if _notification_timer <= 0.0 and _notification_label != null:
			_notification_label.queue_free()
			_notification_label = null

func _on_day_night_toggled() -> void:
	set_night(not _is_night)

func set_night(enabled: bool) -> void:
	var fog: FogOfWarManager = get_tree().get_first_node_in_group("fog_of_war") as FogOfWarManager
	if fog != null:
		fog.set_night(enabled)
	if enabled == _is_night:
		return
	var cm: CanvasModulate = get_tree().root.get_node_or_null("CanvasModulate") as CanvasModulate
	if cm == null:
		cm = CanvasModulate.new()
		cm.name = "CanvasModulate"
		get_tree().root.add_child(cm)
	if enabled:
		cm.color = Color(0.25, 0.28, 0.38)
		_day_night_btn.text = "Day"
		_is_night = true
		_reduce_night_ranges()
	else:
		cm.color = Color.WHITE
		_day_night_btn.text = "Night"
		_is_night = false
		_restore_daylight_ranges()

func _restore_daylight_ranges() -> void:
	var squads: Array = get_tree().get_nodes_in_group("player_squads")
	for squad in squads:
		var soldiers: Array = squad.get("soldiers")
		if soldiers == null:
			continue
		for soldier in soldiers:
			if is_instance_valid(soldier):
				var weapon: WeaponComponent = soldier.get_node_or_null("WeaponComponent") as WeaponComponent
				if weapon != null and weapon.has_meta("base_attack_range"):
					weapon.attack_range = float(weapon.get_meta("base_attack_range"))

func _reduce_night_ranges() -> void:
	var squads: Array = get_tree().get_nodes_in_group("player_squads")
	for squad in squads:
		var soldiers: Array = squad.get("soldiers")
		if soldiers == null:
			continue
		for soldier in soldiers:
			if is_instance_valid(soldier):
				var weapon: WeaponComponent = soldier.get_node_or_null("WeaponComponent") as WeaponComponent
				if weapon != null:
					if not weapon.has_meta("base_attack_range"):
						weapon.set_meta("base_attack_range", weapon.attack_range)
					weapon.attack_range = float(weapon.get_meta("base_attack_range")) * 0.5

func _show_notification(text: String) -> void:
	if _notification_label != null:
		_notification_label.queue_free()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_notification_label = Label.new()
	_notification_label.text = text
	_notification_label.position = Vector2(viewport_size.x / 2.0 - 100.0, 20.0)
	_notification_label.size = Vector2(200.0, 30.0)
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notification_label)
	_notification_timer = 2.0

func _on_debug_spawn_enemy_squad() -> void:
	var squad: SquadController = _SQUAD_SCRIPT.new()
	squad.name = "EnemySquad_Debug"
	squad.position = Vector2(950, 380)
	squad.add_to_group("enemy_squads")

	for i in range(3):
		var soldier: Soldier = Soldier.new()
		soldier.name = "EnemySoldier_" + str(i)
		soldier.position = Vector2(i * 20 - 20, 0)

		var nav := NavigationAgent2D.new()
		nav.name = "NavigationAgent2D"
		soldier.add_child(nav)

		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 6.0
		cs.shape = circle
		soldier.add_child(cs)

		var rect := ColorRect.new()
		rect.size = Vector2(16.0, 16.0)
		rect.position = Vector2(-8.0, -8.0)
		rect.color = Color.RED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		soldier.add_child(rect)

		squad.add_child(soldier)
		soldier.add_to_group("enemy_units")

	get_parent().add_child(squad)
	squad.move_squad(Vector2(550, 400))

func _on_debug_spawn_btr() -> void:
	var v: VehicleUnit = _VEHICLE_SCRIPT.new()
	v.name = "EnemyBTR_Debug"
	v.position = Vector2(980, 440)
	v.is_enemy = true
	get_parent().add_child(v)
	v.set_destination(Vector2(550, 400))

func _on_debug_spawn_fpv_drone() -> void:
	var d: DroneUnit = _DRONE_SCRIPT.new()
	d.name = "EnemyFPVDrone_Debug"
	d.position = Vector2(1000, 350)
	d.drone_type = DroneUnit.DroneType.FPV_KAMIKAZE
	d.is_enemy = true
	get_parent().add_child(d)

func _on_debug_spawn_mutants() -> void:
	var spawner: MutantWaveSpawner = null
	for node in get_tree().get_nodes_in_group("mutant_spawner"):
		if node is MutantWaveSpawner:
			spawner = node
			break
	if spawner == null:
		spawner = _MUTANT_SPAWNER_SCRIPT.new()
		spawner.name = "MutantWaveSpawner_Debug"
		get_parent().add_child(spawner)
	spawner._spawn_wave()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed:
		var selected: Node2D = _get_selected_squad()
		if selected != null and selected is Node2D:
			var cam: Camera2D = get_tree().get_first_node_in_group("rts_camera") as Camera2D
			if cam != null:
				var soldiers: Array = []
				if selected is SquadController:
					soldiers = (selected as SquadController).soldiers
				if soldiers != null and not soldiers.is_empty():
					var center: Vector2 = Vector2.ZERO
					var count: int = 0
					for s in soldiers:
						if is_instance_valid(s) and s is Node2D:
							center += (s as Node2D).global_position
							count += 1
					if count > 0:
						center /= float(count)
						cam.position = center
		get_viewport().set_input_as_handled()
		return

func _get_selected_squad() -> Node2D:
	var sel_mgr: Node = get_tree().current_scene.get_node_or_null("SelectionManager")
	if sel_mgr != null:
		var selected: Array = sel_mgr.get("selected_squads")
		if selected != null and selected.size() > 0 and is_instance_valid(selected[0]):
			return selected[0] as Node2D
	return null

func _exit_tree() -> void:
	Engine.time_scale = 1.0