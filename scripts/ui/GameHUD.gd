class_name GameHUD
extends CanvasLayer

var _sp_label: Label
var _day_night_btn: Button
var _is_night: bool = false
var _eco: EconomyManager

const GRENADE_MAX_RANGE: float = 260.0
const MINE_MAX_RANGE: float = 65.0
const BUILD_MAX_RANGE: float = 85.0

var _build_fort_type: int = -1
var _sandbag_btn: Button = null
var _barbed_btn: Button = null
var _turret_btn: Button = null

var _build_anchor_set: bool = false
var _build_anchor_pos: Vector2 = Vector2.ZERO
var _build_rotation: float = 0.0

# Ability panel state
var _selected_squad: Node2D = null
var _mine_mode: bool = false
var _artillery_mode: bool = false
var _grenade_mode: bool = false

# Aim overlay for grenade/mine preview
var _aim_overlay: Node2D = null

# Ability panel UI refs
var _abil_panel: PanelContainer = null
var _abil_label: Label = null
var _mine_btn: Button = null
var _arty_btn: Button = null
var _flare_btn: Button = null
var _flashlight_btn: Button = null
var _flare_mode: bool = false
var _veteran_btn: Button = null
var _nvg_btn: Button = null
var _cancel_mode_btn: Button = null

# Формации отряда
var formation_names: Array = ["Линия", "Колонна", "Клин", "Развал"]
var formation_tooltips: Array = [
	"Стрелковая цепь лицом к цели",
	"Гуськом вдоль дороги",
	"Клином вперёд",
	"Рассыпной порядок",
]

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

	var speed_hbox := HBoxContainer.new()
	var pause_btn := Button.new()
	pause_btn.text = "||"
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
	
	# Нижние кнопки закупки — прижаты к нижнему краю окна через якоря
	var grid := GridContainer.new()
	grid.columns = 4
	grid.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	grid.offset_left = 10
	grid.offset_top = -115
	grid.offset_bottom = -10
	add_child(grid)
	
	var rookie_btn := Button.new()
	rookie_btn.text = "Rookie Squad (100 SP)"
	rookie_btn.tooltip_text = "Нанять дешёвый 3-х человек отряд новобранцев"
	rookie_btn.pressed.connect(_on_rookie_squad)
	grid.add_child(rookie_btn)
	
	var vehicle_btn := Button.new()
	vehicle_btn.text = "Vehicle (BTR) (250 SP)"
	vehicle_btn.tooltip_text = "БТР: бронированная техника с пулемётом"
	vehicle_btn.pressed.connect(_on_vehicle_spawn)
	grid.add_child(vehicle_btn)
	
	var drone_btn := Button.new()
	drone_btn.text = "FPV Drone (75 SP)"
	drone_btn.tooltip_text = "FPV-камикадзе: высокоскоростной дрон-самоубийца"
	drone_btn.pressed.connect(_on_drone_spawn)
	grid.add_child(drone_btn)
	
	var specialist_btn := Button.new()
	specialist_btn.text = "Specialist (Medic) (80 SP)"
	specialist_btn.tooltip_text = "Прикрепить медика к выбранному отряду"
	specialist_btn.pressed.connect(_on_specialist_medic)
	grid.add_child(specialist_btn)
	
	var at_btn := Button.new()
	at_btn.text = "Бронебойщики (140 SP)"
	at_btn.tooltip_text = "Отряд с ПТ-средствами против техники"
	at_btn.pressed.connect(_on_at_squad)

	grid.add_child(at_btn)

	var sapper_btn := Button.new()
	sapper_btn.text = "Сапер (80 SP)"
	sapper_btn.tooltip_text = "Сапёр: мины, проволока, разминирование аномалий"
	sapper_btn.pressed.connect(_on_sapper)
	grid.add_child(sapper_btn)

	var radio_btn := Button.new()
	radio_btn.text = "Радист (90 SP)"
	radio_btn.tooltip_text = "Радист: артудары, дым, увеличенная дальность"
	radio_btn.pressed.connect(_on_radio)
	grid.add_child(radio_btn)

	var flare_btn := Button.new()
	flare_btn.text = "Осветительная ракета (30 SP)"
	flare_btn.tooltip_text = "Подсветить область ночью"
	flare_btn.pressed.connect(func() -> void:
		_flare_mode = true
		_mine_mode = false
		_artillery_mode = false
		_grenade_mode = false
		_show_notification("Кликните по карте для ракеты")
	)
	grid.add_child(flare_btn)
	_flare_btn = flare_btn

	var veteran_btn := Button.new()
	veteran_btn.text = "Ветераны (220 SP)"
	veteran_btn.tooltip_text = "Опытный отряд с повышенной меткостью и моралью"
	veteran_btn.pressed.connect(_on_veteran_squad)
	grid.add_child(veteran_btn)
	_veteran_btn = veteran_btn

	_update_sp_label()

	# --- Дебаг-панель: быстрый спавн врагов (справа сверху) ---
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
	debug_label.text = "[Тест: Спавн врагов]"
	debug_vbox.add_child(debug_label)

	var squad_btn := Button.new()
	squad_btn.text = "+ Враг: Отряд"
	squad_btn.pressed.connect(_on_debug_spawn_enemy_squad)
	debug_vbox.add_child(squad_btn)

	var btr_btn := Button.new()
	btr_btn.text = "+ Враг: БТР"
	btr_btn.pressed.connect(_on_debug_spawn_btr)
	debug_vbox.add_child(btr_btn)

	var dbg_drone_btn := Button.new()
	dbg_drone_btn.text = "+ Враг: FPV-дрон"
	dbg_drone_btn.pressed.connect(_on_debug_spawn_fpv_drone)
	debug_vbox.add_child(dbg_drone_btn)

	var mutant_btn := Button.new()
	mutant_btn.text = "+ Мутанты"
	mutant_btn.pressed.connect(_on_debug_spawn_mutants)
	debug_vbox.add_child(mutant_btn)

	# Ability panel for selected squad
	var abil_panel := PanelContainer.new()
	abil_panel.name = "AbilityPanel"
	abil_panel.position = Vector2(10, 100)
	abil_panel.size = Vector2(260, 105)
	abil_panel.visible = false
	add_child(abil_panel)
	_abil_panel = abil_panel

	var abil_vbox := VBoxContainer.new()
	abil_panel.add_child(abil_vbox)

	var abil_label := Label.new()
	abil_label.text = "Способности отряда:"
	abil_vbox.add_child(abil_label)
	_abil_label = abil_label

	var abil_hbox := HBoxContainer.new()
	abil_vbox.add_child(abil_hbox)

	var mine_btn := Button.new()
	mine_btn.text = "Мину (40 SP)"
	mine_btn.tooltip_text = "Поставить мину (требуется сапёр)"
	mine_btn.pressed.connect(_on_place_mine)
	abil_hbox.add_child(mine_btn)
	_mine_btn = mine_btn

	var sandbag_btn := Button.new()
	sandbag_btn.text = "Мешки (35 SP)"
	sandbag_btn.tooltip_text = "Построить мешки (укрытие)"
	sandbag_btn.pressed.connect(func() -> void:
		if _eco != null and _eco.get_sp() >= 35:
			_build_fort_type = FieldFortification.FortType.SANDBAGS
		else:
			_show_notification("Недостаточно SP")
	)
	abil_hbox.add_child(sandbag_btn)
	_sandbag_btn = sandbag_btn

	var barbed_btn := Button.new()
	barbed_btn.text = "Проволока (25 SP)"
	barbed_btn.tooltip_text = "Построить проволоку (замедление)"
	barbed_btn.pressed.connect(func() -> void:
		if _eco != null and _eco.get_sp() >= 25:
			_build_fort_type = FieldFortification.FortType.BARBED_WIRE
		else:
			_show_notification("Недостаточно SP")
	)
	abil_hbox.add_child(barbed_btn)
	_barbed_btn = barbed_btn

	var turret_btn := Button.new()
	turret_btn.text = "Турель (110 SP)"
	turret_btn.tooltip_text = "Построить автотурель"
	turret_btn.pressed.connect(func() -> void:
		if _eco != null and _eco.get_sp() >= 110:
			_build_fort_type = FieldFortification.FortType.AUTO_TURRET
		else:
			_show_notification("Недостаточно SP")
	)
	abil_hbox.add_child(turret_btn)
	_turret_btn = turret_btn

	var arty_btn := Button.new()
	arty_btn.text = "Артудар (100 SP)"
	arty_btn.tooltip_text = "Артиллерийский удар по области"
	arty_btn.pressed.connect(_on_artillery_strike)
	abil_hbox.add_child(arty_btn)
	_arty_btn = arty_btn

	var gren_btn := Button.new()
	gren_btn.text = "Граната (30 SP)"
	gren_btn.tooltip_text = "Бросить гранату"
	gren_btn.pressed.connect(_on_grenade)
	abil_hbox.add_child(gren_btn)

	var flashlight_btn := Button.new()
	flashlight_btn.text = "Фонарики: ВКЛ"
	flashlight_btn.tooltip_text = "Переключить фонарики отряда"
	flashlight_btn.pressed.connect(_on_flashlight_toggle)
	abil_hbox.add_child(flashlight_btn)
	_flashlight_btn = flashlight_btn

	var nvg_btn := Button.new()
	nvg_btn.text = "ПНВ (60 SP)"
	nvg_btn.tooltip_text = "Купить ПНВ для отряда"
	nvg_btn.pressed.connect(_on_nvg)
	abil_hbox.add_child(nvg_btn)
	_nvg_btn = nvg_btn

	var cancel_btn := Button.new()
	cancel_btn.text = "Отмена"
	cancel_btn.tooltip_text = "Отменить текущий режим строительства"
	cancel_btn.visible = false
	cancel_btn.pressed.connect(_on_cancel_mode_pressed)
	abil_hbox.add_child(cancel_btn)
	_cancel_mode_btn = cancel_btn

	# Вторая строка: тактические команды
	var tac_hbox := HBoxContainer.new()
	abil_vbox.add_child(tac_hbox)

	var attack_move_btn := Button.new()
	attack_move_btn.text = "Атака (Q)"
	attack_move_btn.tooltip_text = "Режим атаки-движения: юниты идут к точке и атакуют врагов по пути"
	attack_move_btn.pressed.connect(func() -> void:
		var sm: Node = get_parent().get_node_or_null("SelectionManager")
		if sm != null:
			sm.set("attack_move_mode", true)
		_show_notification("Режим атаки-движения: кликните ПКМ")
	)
	tac_hbox.add_child(attack_move_btn)

	var hold_btn := Button.new()
	hold_btn.text = "Стоять (H)"
	hold_btn.tooltip_text = "Остановить выделенные отряды и удерживать позицию"
	hold_btn.pressed.connect(func() -> void:
		var sm: Node = get_parent().get_node_or_null("SelectionManager")
		if sm != null and sm.has_method("issue_hold"):
			sm.call("issue_hold")
	)
	tac_hbox.add_child(hold_btn)

	var retreat_btn := Button.new()
	retreat_btn.text = "Отступить (R)"
	retreat_btn.tooltip_text = "Отступить к ближайшей своей точке или базе"
	retreat_btn.pressed.connect(func() -> void:
		var sm: Node = get_parent().get_node_or_null("SelectionManager")
		if sm != null and sm.has_method("issue_retreat"):
			sm.call("issue_retreat")
	)
	tac_hbox.add_child(retreat_btn)

	# Третья строка: формации отряда
	var form_hbox := HBoxContainer.new()
	abil_vbox.add_child(form_hbox)

	for i in range(4):
		var btn := Button.new()
		btn.text = formation_names[i]
		btn.tooltip_text = formation_tooltips[i]
		btn.pressed.connect(Callable(self, "_on_formation_selected").bind(i))
		form_hbox.add_child(btn)

	_aim_overlay = Node2D.new()
	_aim_overlay.name = "AimOverlay"
	_aim_overlay.z_index = 95
	_aim_overlay.draw.connect(_on_aim_overlay_draw)
	get_parent().add_child(_aim_overlay)
func _on_formation_selected(formation_index: int) -> void:
	var sm: Node = get_parent().get_node_or_null("SelectionManager")
	if sm != null:
		for squad in sm.selected_squads:
			if is_instance_valid(squad) and squad.has_method("set_formation"):
				squad.call("set_formation", formation_index)
	_show_notification("Формация: " + formation_names[formation_index])

func _on_sp_changed(new_amount: int) -> void:
	_update_sp_label()

func _update_sp_label() -> void:
	if _sp_label != null and _eco != null:
		_sp_label.text = "SP: " + str(_eco.get_sp())
func _on_aim_overlay_draw() -> void:
	if _build_fort_type >= 0:
		var selected: Node2D = _get_selected_squad()
		if selected == null:
			return
		var soldiers: Array = selected.get("soldiers")
		if soldiers == null:
			return
		var center: Vector2 = Vector2.ZERO
		var count: int = 0
		for s in soldiers:
			if is_instance_valid(s) and s is Node2D:
				center += (s as Node2D).global_position
				count += 1
		if count == 0:
			return
		center /= float(count)
		var mouse_world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()
		if _build_anchor_set == false:
			var in_range: bool = center.distance_to(mouse_world) <= BUILD_MAX_RANGE
			var color: Color = Color(0.2, 1.0, 0.3, 0.45) if in_range else Color(1.0, 0.2, 0.2, 0.45)
			_aim_overlay.draw_arc(center, BUILD_MAX_RANGE, 0.0, TAU, 48, Color(0.9, 0.9, 0.9, 0.5), 1.5)
			_aim_overlay.draw_line(center, mouse_world, color, 1.5)
			_aim_overlay.draw_circle(mouse_world, 8.0, color)
		else:
			_build_rotation = (mouse_world - _build_anchor_pos).angle() + PI / 2.0
			_aim_overlay.draw_line(_build_anchor_pos, mouse_world, Color(0.9, 0.9, 0.2, 0.7), 2.0)
			var fort_size: Vector2 = Vector2(48.0, 16.0)
			match _build_fort_type:
				FieldFortification.FortType.SANDBAGS:
					fort_size = Vector2(48.0, 16.0)
				FieldFortification.FortType.BARBED_WIRE:
					fort_size = Vector2(56.0, 14.0)
				FieldFortification.FortType.AUTO_TURRET:
					fort_size = Vector2(22.0, 22.0)
			_aim_overlay.draw_set_transform(_build_anchor_pos, _build_rotation, Vector2.ONE)
			_aim_overlay.draw_rect(Rect2(-fort_size / 2.0, fort_size), Color(0.2, 1.0, 0.3, 0.65), false, 2.0)
			_aim_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if not _grenade_mode and not _mine_mode:
		return
	var selected: Node2D = _get_selected_squad()
	if selected == null:
		return
	var soldiers: Array = selected.get("soldiers")
	if soldiers == null:
		return
	var center: Vector2 = Vector2.ZERO
	var count: int = 0
	for s in soldiers:
		if is_instance_valid(s) and s is Node2D:
			center += (s as Node2D).global_position
			count += 1
	if count == 0:
		return
	center /= float(count)
	var mouse_world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()
	var max_r: float = GRENADE_MAX_RANGE if _grenade_mode else MINE_MAX_RANGE
	var aoe_r: float = 50.0 if _grenade_mode else 25.0
	var in_range: bool = center.distance_to(mouse_world) <= max_r
	var color: Color = Color(0.2, 1.0, 0.3, 0.45) if in_range else Color(1.0, 0.2, 0.2, 0.45)
	_aim_overlay.draw_arc(center, max_r, 0.0, TAU, 48, Color(0.9, 0.9, 0.9, 0.5), 1.5)
	_aim_overlay.draw_line(center, mouse_world, color, 1.5)
	_aim_overlay.draw_circle(mouse_world, aoe_r, color)

func _process(delta: float) -> void:
	if _notification_timer > 0.0:
		_notification_timer -= delta
		if _notification_timer <= 0.0 and _notification_label != null:
			_notification_label.queue_free()
			_notification_label = null

	if _aim_overlay != null:
		_aim_overlay.queue_redraw()
	if _cancel_mode_btn != null:
		_cancel_mode_btn.visible = (_mine_mode or _grenade_mode or _artillery_mode or _flare_mode or _build_fort_type >= 0)

	if _abil_panel == null or _abil_label == null:
		return
	var squad: Node2D = _get_selected_squad()
	if squad == null:
		_abil_panel.visible = false
		return
	_abil_panel.visible = true

	var spec: SpecialistComponent = squad.get_node_or_null("SpecialistComponent") as SpecialistComponent
	var type_name: String = "Обычный"
	if spec != null:
		match spec.specialist_type:
			SpecialistComponent.Type.MEDIC:
				type_name = "Медик"
			SpecialistComponent.Type.SAPPER:
				type_name = "Сапер"
			SpecialistComponent.Type.RADIO:
				type_name = "Радист"
			_:
				type_name = "Обычный"
	_abil_label.text = "Отряд [" + type_name + "]"

	if _mine_btn != null:
		_mine_btn.visible = (spec != null and spec.specialist_type == SpecialistComponent.Type.SAPPER)
		if _sandbag_btn != null:
			_sandbag_btn.visible = (spec != null and spec.specialist_type == SpecialistComponent.Type.SAPPER)
		if _barbed_btn != null:
			_barbed_btn.visible = (spec != null and spec.specialist_type == SpecialistComponent.Type.SAPPER)
		if _turret_btn != null:
			_turret_btn.visible = (spec != null and spec.specialist_type == SpecialistComponent.Type.SAPPER)
	if _arty_btn != null:
		_arty_btn.visible = (spec != null and spec.specialist_type == SpecialistComponent.Type.RADIO)

	var soldiers: Array = squad.get("soldiers")
	if _flashlight_btn != null and squad != null:
		if soldiers != null and soldiers.size() > 0 and is_instance_valid(soldiers[0]):
			var on: bool = bool(soldiers[0].get("flashlight_on"))
			_flashlight_btn.text = "Фонарики: " + ("ВКЛ" if on else "ВЫКЛ")
	
	# ПНВ кнопка видима, если в отряде есть боец без ПНВ и не Veteran+
	if _nvg_btn != null:
		var any_need_nvg: bool = false
		for s in soldiers:
			if not is_instance_valid(s):
				continue
			var vc: VeterancyComponent = s.get_node_or_null("VeterancyComponent") as VeterancyComponent
			var rank: int = vc.rank if vc != null else VeterancyComponent.Rank.ROOKIE
			if not bool(s.get("has_nvg")) and rank < VeterancyComponent.Rank.VETERAN:
				any_need_nvg = true
				break
		_nvg_btn.visible = any_need_nvg
	

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

func _on_rookie_squad() -> void:
	if _eco != null and _eco.spend_sp(100):
		_spawn_soldier_squad(3)

func _on_vehicle_spawn() -> void:
	if _eco != null and _eco.spend_sp(250):
		_spawn_vehicle()

func _on_drone_spawn() -> void:
	if _eco != null and _eco.spend_sp(75):
		_spawn_drone()

func _on_veteran_squad() -> void:
	if _eco != null and _eco.spend_sp(220):
		_spawn_veteran_squad()

func _on_nvg() -> void:
	var squad: Node2D = _get_selected_squad()
	if squad == null:
		_show_notification("Сначала выделите отряд!")
		return
	var soldiers: Array = squad.get("soldiers")
	if soldiers == null or soldiers.is_empty():
		return
	# Проверяем, есть ли уже ПНВ или Veteran+
	var all_have_nvg_or_veteran: bool = true
	for s in soldiers:
		if not is_instance_valid(s):
			continue
		var vc: VeterancyComponent = s.get_node_or_null("VeterancyComponent") as VeterancyComponent
		var rank: int = vc.rank if vc != null else VeterancyComponent.Rank.ROOKIE
		if not bool(s.get("has_nvg")) and rank < VeterancyComponent.Rank.VETERAN:
			all_have_nvg_or_veteran = false
			break
	if all_have_nvg_or_veteran:
		_show_notification("Отряд уже оснащён ПНВ или состоит из ветеранов!")
		return
	if _eco != null and _eco.spend_sp(60):
		for s in soldiers:
			if is_instance_valid(s):
				s.set("has_nvg", true)
				s.set("flashlight_on", false)
		_show_notification("ПНВ выданы отряду!")

func _spawn_veteran_squad() -> void:
	var squad = _SQUAD_SCRIPT.new()
	squad.position = _get_free_spawn_pos()
	for i in range(3):
		var soldier := Soldier.new()
		soldier.name = "VetSoldier_" + str(i)
		soldier.position = Vector2(i * 24 - 24, 0)
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
		rect.color = Color(0.15, 0.55, 1.0)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		soldier.add_child(rect)
		squad.add_child(soldier)
		soldier.add_to_group("player_units")
	get_parent().add_child(squad)
	# Вызываем add_xp ПОСЛЕ добавления в сцену, т.к. VeterancyComponent создаётся в Soldier._ready()
	for s in squad.get("soldiers"):
		if is_instance_valid(s):
			var vc: VeterancyComponent = s.get_node_or_null("VeterancyComponent") as VeterancyComponent
			if vc != null:
				vc.add_xp(100)

func _spawn_soldier_squad(count: int) -> void:
	var squad = _SQUAD_SCRIPT.new()
	squad.position = _get_free_spawn_pos()

	for i in range(count):
		var soldier := Soldier.new()
		soldier.name = "Soldier_" + str(i)
		soldier.position = Vector2(i * 24 - 24, 0)

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

	get_parent().add_child(squad)

func _spawn_vehicle() -> void:
	var vehicle := VehicleUnit.new()
	vehicle.position = _get_free_spawn_pos()
	vehicle.is_enemy = false
	get_parent().add_child(vehicle)

func _spawn_drone() -> void:
	var drone := DroneUnit.new()
	drone.position = _get_free_spawn_pos()
	drone.drone_type = DroneUnit.DroneType.FPV_KAMIKAZE
	drone.is_enemy = false
	get_parent().add_child(drone)

func _get_selected_squad() -> Node2D:
	var sel_mgr: Node = get_tree().current_scene.get_node_or_null("SelectionManager")
	if sel_mgr != null:
		var selected: Array = sel_mgr.get("selected_squads")
		if selected != null and selected.size() > 0 and is_instance_valid(selected[0]):
			return selected[0] as Node2D
	return null

func _get_free_spawn_pos(origin: Vector2 = Vector2(200.0, 400.0)) -> Vector2:
	var groups_to_check: Array[String] = ["player_units", "player_vehicles", "player_drones"]
	for attempt in range(50):
		var dx: int = (attempt % 7) - 3
		var dy: int = int(attempt / 7) - 3
		var candidate: Vector2 = origin + Vector2(dx * 65.0, dy * 65.0)
		if candidate.x < 60.0 or candidate.x > 1860.0 or candidate.y < 60.0 or candidate.y > 1020.0:
			continue
		var overlap: bool = false
		for g in groups_to_check:
			for node in get_tree().get_nodes_in_group(g):
				if is_instance_valid(node) and node is Node2D:
					if (node as Node2D).global_position.distance_to(candidate) < 60.0:
						overlap = true
						break
			if overlap:
				break
		if not overlap:
			return candidate
	return origin

func _can_add_specialist(target_squad: Node2D) -> bool:
	if target_squad == null:
		_show_notification("Сначала выделите отряд!")
		return false
	var spec: SpecialistComponent = target_squad.get_node_or_null("SpecialistComponent") as SpecialistComponent
	if spec != null and spec.specialist_type != SpecialistComponent.Type.NONE:
		_show_notification("В отряде уже есть специалист!")
		return false
	return true

func _on_specialist_medic() -> void:
	var target_squad: Node2D = _get_selected_squad()
	if not _can_add_specialist(target_squad):
		return
	if _eco != null and _eco.spend_sp(80):
		_attach_specialist_to_selected(SpecialistComponent.Type.MEDIC)

func _on_at_squad() -> void:
	if _eco != null and _eco.spend_sp(140):
		_spawn_at_squad()

func _spawn_at_squad() -> void:
	var squad = _SQUAD_SCRIPT.new()
	squad.position = _get_free_spawn_pos()
	for i in range(3):
		var soldier := Soldier.new()
		soldier.name = "AT_Soldier_" + str(i)
		soldier.position = Vector2(i * 24 - 24, 0)
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
		rect.color = Color(0.8, 0.4, 0.2, 1.0)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		soldier.add_child(rect)
		squad.add_child(soldier)
		soldier.add_to_group("player_units")
		var weapon: WeaponComponent = soldier.get_node_or_null("WeaponComponent")
		if weapon == null:
			weapon = WeaponComponent.new()
			weapon.name = "WeaponComponent"
			soldier.add_child(weapon)
		weapon.attack_range = 550.0
		weapon.attack_damage = 45
	get_parent().add_child(squad)

func _on_sapper() -> void:
	var target_squad: Node2D = _get_selected_squad()
	if not _can_add_specialist(target_squad):
		return
	if _eco != null and _eco.spend_sp(80):
		_attach_specialist_to_selected(SpecialistComponent.Type.SAPPER)

func _on_radio() -> void:
	var target_squad: Node2D = _get_selected_squad()
	if not _can_add_specialist(target_squad):
		return
	if _eco != null and _eco.spend_sp(90):
		_attach_specialist_to_selected(SpecialistComponent.Type.RADIO)

func _on_ew_station() -> void:
	if _eco != null and _eco.spend_sp(220):
		_spawn_ew_vehicle()

func _spawn_ew_vehicle() -> void:
	var vehicle := VehicleUnit.new()
	vehicle.position = _get_free_spawn_pos()
	vehicle.is_enemy = false
	vehicle.is_ew_jammer = true
	get_parent().add_child(vehicle)

func _attach_specialist_to_selected(spec_type: int) -> void:
	var target_squad: Node2D = _get_selected_squad()
	if target_squad == null:
		_show_notification("Сначала выделите отряд!")
		return
	var spec: SpecialistComponent = target_squad.get_node_or_null("SpecialistComponent") as SpecialistComponent
	if spec != null and spec.specialist_type != SpecialistComponent.Type.NONE:
		_show_notification("В отряде уже есть специалист!")
		return
	if spec == null:
		spec = SpecialistComponent.new()
		spec.name = "SpecialistComponent"
		target_squad.add_child(spec)
	spec.specialist_type = spec_type
	spec._ready()
	var type_name: String = "Специалист"
	match spec_type:
		SpecialistComponent.Type.MEDIC:
			type_name = "Медик"
		SpecialistComponent.Type.SAPPER:
			type_name = "Сапер"
		SpecialistComponent.Type.RADIO:
			type_name = "Радист"
	_show_notification(type_name + " добавлен в отряд!")

func _on_place_mine() -> void:
	var target_squad: Node2D = _get_selected_squad()
	if target_squad == null:
		_show_notification("Сначала выделите отряд!")
		return
	var spec: SpecialistComponent = target_squad.get_node_or_null("SpecialistComponent") as SpecialistComponent
	if spec == null or spec.specialist_type != SpecialistComponent.Type.SAPPER:
		_show_notification("В отряде должен быть сапер!")
		return
	if _eco != null and _eco.get_sp() >= 40:
		_mine_mode = true
		_artillery_mode = false
		_grenade_mode = false
		_flare_mode = false

func _on_artillery_strike() -> void:
	var target_squad: Node2D = _get_selected_squad()
	if target_squad == null:
		_show_notification("Сначала выделите отряд!")
		return
	var spec: SpecialistComponent = target_squad.get_node_or_null("SpecialistComponent") as SpecialistComponent
	if spec == null or spec.specialist_type != SpecialistComponent.Type.RADIO:
		_show_notification("В отряде должен быть радист!")
		return
	if _eco != null and _eco.spend_sp(100):
		_artillery_mode = true
		_mine_mode = false
		_grenade_mode = false
		_flare_mode = false

func _on_grenade() -> void:
	if _eco != null and _eco.get_sp() >= 30:
		_grenade_mode = true
		_mine_mode = false
		_artillery_mode = false
		_flare_mode = false

func _on_flashlight_toggle() -> void:
	var squad: Node2D = _get_selected_squad()
	if squad == null:
		return
	var soldiers: Array = squad.get("soldiers")
	if soldiers == null or soldiers.is_empty():
		return
	var has_rookie_without_nvg: bool = false
	for s in soldiers:
		if not is_instance_valid(s):
			continue
		var vc: VeterancyComponent = s.get_node_or_null("VeterancyComponent") as VeterancyComponent
		var rank: int = vc.rank if vc != null else VeterancyComponent.Rank.ROOKIE
		if not bool(s.get("has_nvg")) and rank == VeterancyComponent.Rank.ROOKIE:
			has_rookie_without_nvg = true
			break
	if not has_rookie_without_nvg:
		_show_notification("У отряда ПНВ/тепловизор — фонарики не нужны")
		return
	var new_state: bool = true
	if is_instance_valid(soldiers[0]):
		new_state = not bool(soldiers[0].get("flashlight_on"))
	for s in soldiers:
		if is_instance_valid(s):
			s.set("flashlight_on", new_state)

func _input(event: InputEvent) -> void:
	if get_viewport().gui_get_hovered_control() != null:
		return
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed:
		var selected: Node2D = _get_selected_squad()
		if selected != null and selected is Node2D:
			var cam: Camera2D = get_tree().get_first_node_in_group("rts_camera") as Camera2D
			if cam != null:
				var soldiers: Array = selected.get("soldiers")
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
	# Cancel any active mode on Esc or RMB
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if _build_anchor_set:
			_build_anchor_set = false
			get_viewport().set_input_as_handled()
			return
		if _mine_mode or _grenade_mode or _artillery_mode or _flare_mode or _build_fort_type >= 0:
			_mine_mode = false
			_grenade_mode = false
			_artillery_mode = false
			_flare_mode = false
			_build_fort_type = -1
			_build_anchor_set = false
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _build_anchor_set:
			_build_anchor_set = false
			get_viewport().set_input_as_handled()
			return
		if _mine_mode or _grenade_mode or _artillery_mode or _flare_mode or _build_fort_type >= 0:
			_mine_mode = false
			_grenade_mode = false
			_artillery_mode = false
			_flare_mode = false
			_build_fort_type = -1
			_build_anchor_set = false
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
		if _flare_mode:
			_flare_mode = false
			if _eco != null and _eco.spend_sp(30):
				var fog: FogOfWarManager = get_tree().get_first_node_in_group("fog_of_war") as FogOfWarManager
				if fog != null:
					fog.add_flare(world_pos, 420.0, 15.0)
			else:
				_show_notification("Недостаточно SP")
			get_viewport().set_input_as_handled()
			return
		if _mine_mode:
			_mine_mode = false
			get_viewport().set_input_as_handled()
			var selected: Node2D = _get_selected_squad()
			if selected != null:
				var soldiers: Array = selected.get("soldiers")
				var center: Vector2 = Vector2.ZERO
				var count: int = 0
				for s in soldiers:
					if is_instance_valid(s) and s is Node2D:
						center += (s as Node2D).global_position
						count += 1
				if count > 0:
					center /= float(count)
					if center.distance_to(world_pos) > MINE_MAX_RANGE:
						_show_notification("Слишком далеко!")
						return
				var spec: SpecialistComponent = selected.get_node_or_null("SpecialistComponent") as SpecialistComponent
				if spec != null and spec.specialist_type == SpecialistComponent.Type.SAPPER:
					if _eco != null and _eco.spend_sp(40):
						spec.place_mine(world_pos)
					else:
						_show_notification("Недостаточно SP")
			return
		if _artillery_mode:
			_artillery_mode = false
			_aoe_damage(world_pos, 100.0, 80)
		if _grenade_mode:
			_grenade_mode = false
			get_viewport().set_input_as_handled()
			var selected: Node2D = _get_selected_squad()
			if selected != null:
				var soldiers: Array = selected.get("soldiers")
				var center: Vector2 = Vector2.ZERO
				var count: int = 0
				for s in soldiers:
					if is_instance_valid(s) and s is Node2D:
						center += (s as Node2D).global_position
						count += 1
				if count > 0:
					center /= float(count)
					if center.distance_to(world_pos) > GRENADE_MAX_RANGE:
						_show_notification("Слишком далеко!")
						return
				if _eco != null and _eco.spend_sp(30):
					_aoe_damage(world_pos, 50.0, 60)
				else:
					_show_notification("Недостаточно SP")
			return
		if _build_fort_type >= 0:
			get_viewport().set_input_as_handled()
			var selected: Node2D = _get_selected_squad()
			if selected == null:
				_build_fort_type = -1
				_build_anchor_set = false
				return
			if not _build_anchor_set:
				var soldiers: Array = selected.get("soldiers")
				var center: Vector2 = Vector2.ZERO
				var count: int = 0
				for s in soldiers:
					if is_instance_valid(s) and s is Node2D:
						center += (s as Node2D).global_position
						count += 1
				if count > 0:
					center /= float(count)
					if center.distance_to(world_pos) > BUILD_MAX_RANGE:
						_show_notification("Слишком далеко!")
						return
				_build_anchor_pos = world_pos
				_build_anchor_set = true
				_build_rotation = 0.0
				_show_notification("Поверните мышью и нажмите ЛКМ")
			else:
				var fort_type: int = _build_fort_type
				_build_fort_type = -1
				_build_anchor_set = false
				var spec: SpecialistComponent = selected.get_node_or_null("SpecialistComponent") as SpecialistComponent
				if spec != null and spec.specialist_type == SpecialistComponent.Type.SAPPER:
					var cost: int = 0
					match fort_type:
						FieldFortification.FortType.SANDBAGS:
							cost = 35
						FieldFortification.FortType.BARBED_WIRE:
							cost = 25
						FieldFortification.FortType.AUTO_TURRET:
							cost = 110
					if _eco != null and _eco.spend_sp(cost):
						spec.build_fortification(_build_anchor_pos, fort_type, _build_rotation)
					else:
						_show_notification("Недостаточно SP")

func _on_cancel_mode_pressed() -> void:
	_mine_mode = false
	_grenade_mode = false
	_artillery_mode = false
	_flare_mode = false
	_build_fort_type = -1
	_build_anchor_set = false

func _aoe_damage(center: Vector2, radius: float, damage: int) -> void:
	var cam: Camera2D = get_tree().get_first_node_in_group("rts_camera") as Camera2D
	if cam != null and cam.has_method("shake"):
		cam.call("shake", 10.0, 0.3)
	# Вспышка взрыва
	var flash: ColorRect = ColorRect.new()
	flash.size = Vector2(radius * 2.0, radius * 2.0)
	flash.position = center - Vector2(radius, radius)
	flash.color = Color(1.0, 0.5, 0.0, 0.7)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.name = "AOEFlash"
	get_tree().current_scene.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)

	var targets: Array = []
	targets.append_array(get_tree().get_nodes_in_group("enemy_units"))
	targets.append_array(get_tree().get_nodes_in_group("enemy_vehicles"))
	targets.append_array(get_tree().get_nodes_in_group("enemy_drones"))
	var hit_targets: Array[Node] = []
	for obj in targets:
		if obj not in hit_targets:
			hit_targets.append(obj)
	for obj in hit_targets:
		if is_instance_valid(obj) and obj is Node2D:
			if center.distance_to(obj.global_position) <= radius:
				var health: HealthComponent = obj.get_node_or_null("HealthComponent") as HealthComponent
				if health != null:
					health.take_damage(damage)
				elif obj.has_method("take_damage"):
					obj.take_damage(damage)

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
		rect.mouse_filter = 2
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

func _exit_tree() -> void:
	Engine.time_scale = 1.0