class_name GameHUD
extends CanvasLayer

var _sp_label: Label
var _day_night_btn: Button
var _is_night: bool = false
var _eco: EconomyManager

const _SQUAD_SCRIPT := preload("res://scripts/core/SquadController.gd")

func _ready() -> void:
	_eco = get_tree().get_first_node_in_group("economy") as EconomyManager
	if _eco != null:
		_eco.sp_changed.connect(_on_sp_changed)
	
	# Верхний Panel: SP counter + Day/Night toggle
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
	
	# Нижние кнопки закупки
	var hbox := HBoxContainer.new()
	hbox.size = Vector2(400, 200)
	hbox.position = Vector2(10, 100)
	add_child(hbox)
	
	var rookie_btn := Button.new()
	rookie_btn.text = "Rookie Squad (100 SP)"
	rookie_btn.pressed.connect(_on_rookie_squad)
	hbox.add_child(rookie_btn)
	
	var vehicle_btn := Button.new()
	vehicle_btn.text = "Vehicle (BTR) (250 SP)"
	vehicle_btn.pressed.connect(_on_vehicle_spawn)
	hbox.add_child(vehicle_btn)
	
	var drone_btn := Button.new()
	drone_btn.text = "FPV Drone (75 SP)"
	drone_btn.pressed.connect(_on_drone_spawn)
	hbox.add_child(drone_btn)
	
	var specialist_btn := Button.new()
	specialist_btn.text = "Specialist (Medic) (80 SP)"
	specialist_btn.pressed.connect(_on_specialist_medic)
	hbox.add_child(specialist_btn)
	
	_update_sp_label()

func _on_sp_changed(new_amount: int) -> void:
	_update_sp_label()

func _update_sp_label() -> void:
	if _sp_label != null and _eco != null:
		_sp_label.text = "SP: " + str(_eco.get_sp())

func _on_day_night_toggled() -> void:
	var cm: CanvasModulate = get_tree().root.get_node_or_null("CanvasModulate") as CanvasModulate
	if cm == null:
		cm = CanvasModulate.new()
		cm.name = "CanvasModulate"
		get_tree().root.add_child(cm)
	
	if _is_night:
		# Дневной режим
		cm.color = Color(1, 1, 1)
		_day_night_btn.text = "Night"
		_is_night = false
		_restore_daylight_ranges()
	else:
		# Ночной режим
		cm.color = Color(0.25, 0.28, 0.38)
		_day_night_btn.text = "Day"
		_is_night = true
		_reduce_night_ranges()

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

func _on_rookie_squad() -> void:
	if _eco != null and _eco.spend_sp(100):
		_spawn_soldier_squad(3)

func _on_vehicle_spawn() -> void:
	if _eco != null and _eco.spend_sp(250):
		_spawn_vehicle()

func _on_drone_spawn() -> void:
	if _eco != null and _eco.spend_sp(75):
		_spawn_drone()

func _on_specialist_medic() -> void:
	if _eco != null and _eco.spend_sp(80):
		_attach_medic_to_selected()

func _spawn_soldier_squad(count: int) -> void:
	var squad = _SQUAD_SCRIPT.new()
	squad.position = Vector2(200, 400)
	
	for i in range(count):
		var soldier := Soldier.new()
		soldier.name = "Soldier_" + str(i)
		soldier.position = Vector2(i * 24 - 24, 0)
		
		# Soldier._ready требует NavigationAgent2D, CollisionShape2D, ColorRect
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
		rect.color = Color.BLUE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		soldier.add_child(rect)
		
		squad.add_child(soldier)
		soldier.add_to_group("player_units")
	
	get_tree().root.add_child(squad)

func _spawn_vehicle() -> void:
	var vehicle := VehicleUnit.new()
	vehicle.position = Vector2(200, 400)
	vehicle.is_enemy = false
	get_tree().root.add_child(vehicle)

func _spawn_drone() -> void:
	var drone := DroneUnit.new()
	drone.position = Vector2(200, 400)
	drone.drone_type = DroneUnit.DroneType.FPV_KAMIKAZE
	drone.is_enemy = false
	get_tree().root.add_child(drone)

func _attach_medic_to_selected() -> void:
	var target_squad: Node = null
	var sel_mgr: Node = get_tree().current_scene.get_node_or_null("SelectionManager")
	if sel_mgr != null:
		var selected: Array = sel_mgr.get("selected_squads")
		if selected != null and selected.size() > 0:
			target_squad = selected[0]
	if target_squad == null:
		var squads: Array = get_tree().get_nodes_in_group("player_squads")
		if squads.size() > 0:
			target_squad = squads[0]
	
	if target_squad != null:
		var spec := SpecialistComponent.new()
		spec.specialist_type = SpecialistComponent.Type.MEDIC
		target_squad.add_child(spec)
