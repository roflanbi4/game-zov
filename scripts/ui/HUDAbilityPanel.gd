class_name HUDAbilityPanel
extends PanelContainer

const GRENADE_MAX_RANGE: float = 260.0
const MINE_MAX_RANGE: float = 65.0
const BUILD_MAX_RANGE: float = 85.0

const TAU: float = 2 * PI


var _eco: EconomyManager

# Ability panel state
var _mine_mode: bool = false
var _artillery_mode: bool = false
var _grenade_mode: bool = false
var _flare_mode: bool = false


# Build fort state
var _build_fort_type: int = -1
var _build_anchor_set: bool = false
var _build_anchor_pos: Vector2 = Vector2.ZERO
var _build_rotation: float = 0.0

# Aim overlay
var _aim_overlay: Node2D = null

# UI refs
var _abil_label: Label = null
var _mine_btn: Button = null
var _sandbag_btn: Button = null
var _barbed_btn: Button = null
var _turret_btn: Button = null
var _arty_btn: Button = null
var _grenade_btn: Button = null
var _flashlight_btn: Button = null
var _nvg_btn: Button = null
var _cancel_mode_btn: Button = null

# Formation names (English)
var formation_names: Array = ["Line", "Column", "Wedge", "Spread"]
var formation_tooltips: Array = [
	"Rifle chain facing target",
	"Single file along the road",
	"Wedge forward",
	"Skirmish order",
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_eco = get_tree().get_first_node_in_group("economy") as EconomyManager
	name = "AbilityPanel"
	position = Vector2(10, 100)
	size = Vector2(260, 105)
	visible = false

	var vbox := VBoxContainer.new()
	add_child(vbox)

	_abil_label = Label.new()
	_abil_label.text = "Squad abilities:"
	vbox.add_child(_abil_label)

	# First row: abilities
	var abil_hbox := HBoxContainer.new()
	vbox.add_child(abil_hbox)

	_mine_btn = _make_btn("Mine (40 SP)", "Place mine (requires sapper)", _on_place_mine)
	abil_hbox.add_child(_mine_btn)

	_sandbag_btn = _make_btn("Sandbags (35 SP)", "Build sandbags (cover)", _build_sandbags)
	abil_hbox.add_child(_sandbag_btn)

	_barbed_btn = _make_btn("Barbed Wire (25 SP)", "Build barbed wire (slow)", _build_barbed)
	abil_hbox.add_child(_barbed_btn)

	_turret_btn = _make_btn("Turret (110 SP)", "Build auto-turret", _build_turret)
	abil_hbox.add_child(_turret_btn)

	_arty_btn = _make_btn("Artillery (100 SP)", "Artillery strike on area", _on_artillery_strike)
	abil_hbox.add_child(_arty_btn)

	_grenade_btn = _make_btn("Grenade (30 SP)", "Throw grenade", _on_grenade)
	abil_hbox.add_child(_grenade_btn)

	_flashlight_btn = _make_btn("Flashlight", "Toggle squad flashlight", _on_flashlight_toggle)
	abil_hbox.add_child(_flashlight_btn)

	_nvg_btn = _make_btn("NVG (60 SP)", "Buy NVG for squad", _on_nvg)
	abil_hbox.add_child(_nvg_btn)

	_cancel_mode_btn = _make_btn("Cancel", "Cancel current build mode", _on_cancel_mode_pressed)
	_cancel_mode_btn.visible = false
	abil_hbox.add_child(_cancel_mode_btn)

	# Second row: tactical commands
	var tac_hbox := HBoxContainer.new()
	vbox.add_child(tac_hbox)

	var attack_move_btn := Button.new()
	attack_move_btn.text = "Attack (Q)"
	attack_move_btn.tooltip_text = "Attack-move: units go to point and attack enemies on the way"
	attack_move_btn.pressed.connect(func() -> void:
		var sm: Node = get_tree().current_scene.get_node_or_null("SelectionManager")
		if sm != null:
			sm.set("attack_move_mode", true)
			_show_notification("Attack-move: click RMB")
	)
	tac_hbox.add_child(attack_move_btn)

	var hold_btn := Button.new()
	hold_btn.text = "Hold (H)"
	hold_btn.tooltip_text = "Stop selected squads and hold position"
	hold_btn.pressed.connect(func() -> void:
		var sm: Node = get_tree().current_scene.get_node_or_null("SelectionManager")
		if sm != null and sm.has_method("issue_hold"):
			sm.call("issue_hold")
	)
	tac_hbox.add_child(hold_btn)

	var retreat_btn := Button.new()
	retreat_btn.text = "Retreat (R)"
	retreat_btn.tooltip_text = "Retreat to nearest friendly point or base"
	retreat_btn.pressed.connect(func() -> void:
		var sm: Node = get_tree().current_scene.get_node_or_null("SelectionManager")
		if sm != null and sm.has_method("issue_retreat"):
			sm.call("issue_retreat")
	)
	tac_hbox.add_child(retreat_btn)

	# Third row: formations
	var form_hbox := HBoxContainer.new()
	vbox.add_child(form_hbox)

	for i in range(4):
		var fbtn := Button.new()
		fbtn.text = formation_names[i]
		fbtn.tooltip_text = formation_tooltips[i]
		fbtn.pressed.connect(Callable(self, "_on_formation_selected").bind(i))
		form_hbox.add_child(fbtn)

	_aim_overlay = Node2D.new()
	_aim_overlay.name = "AimOverlay"
	_aim_overlay.z_index = 95
	_aim_overlay.draw.connect(_on_aim_overlay_draw)
	_aim_overlay.add_to_group("mission_cleanup")
	get_tree().current_scene.call_deferred("add_child", _aim_overlay)

func _on_formation_selected(formation_index: int) -> void:
	var sm: Node = get_tree().current_scene.get_node_or_null("SelectionManager")
	if sm != null:
		for squad in sm.selected_squads:
			if is_instance_valid(squad) and squad.has_method("set_formation"):
				squad.call("set_formation", formation_index)
		_show_notification("Formation: " + formation_names[formation_index])
		
func _build_sandbags() -> void:
	if _eco != null and _eco.get_sp() >= 35:
		_build_fort_type = FieldFortification.FortType.SANDBAGS
	else:
		_show_notification("Not enough SP")

func _build_barbed() -> void:
	if _eco != null and _eco.get_sp() >= 25:
		_build_fort_type = FieldFortification.FortType.BARBED_WIRE
	else:
		_show_notification("Not enough SP")

func _build_turret() -> void:
	if _eco != null and _eco.get_sp() >= 110:
		_build_fort_type = FieldFortification.FortType.AUTO_TURRET
	else:
		_show_notification("Not enough SP")

func _on_place_mine() -> void:
	var target_squad: Node2D = _get_selected_squad()
	if target_squad == null:
		_show_notification("First select a squad!")
		return
	var spec: SpecialistComponent = target_squad.get_node_or_null("SpecialistComponent") as SpecialistComponent
	if spec == null or spec.specialist_type != SpecialistComponent.Type.SAPPER:
		_show_notification("Squad must have a sapper!")
		return
	if _eco != null and _eco.get_sp() >= 40:
		_mine_mode = true
		_artillery_mode = false
		_grenade_mode = false
		_flare_mode = false

func _on_artillery_strike() -> void:
	var target_squad: Node2D = _get_selected_squad()
	if target_squad == null:
		_show_notification("First select a squad!")
		return
	var spec: SpecialistComponent = target_squad.get_node_or_null("SpecialistComponent") as SpecialistComponent
	if spec == null or spec.specialist_type != SpecialistComponent.Type.RADIO:
		_show_notification("Squad must have a radio operator!")
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

func enable_flare_mode() -> void:
	if _eco != null and _eco.spend_sp(30):
		_flare_mode = true
		_mine_mode = false
		_artillery_mode = false
		_grenade_mode = false

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
		_show_notification("Squad has NVG/thermal - flashlight not needed")
		return
	var new_state: bool = true
	if is_instance_valid(soldiers[0]):
		new_state = not bool(soldiers[0].get("flashlight_on"))
	for s in soldiers:
		if is_instance_valid(s):
			s.set("flashlight_on", new_state)

func _on_nvg() -> void:
	var squad: Node2D = _get_selected_squad()
	if squad == null:
		_show_notification("First select a squad!")
		return
	var soldiers: Array = squad.get("soldiers")
	if soldiers == null or soldiers.is_empty():
		return
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
		_show_notification("Squad already equipped with NVG or veterans!")
		return
	if _eco != null and _eco.spend_sp(60):
		for s in soldiers:
			if is_instance_valid(s):
				s.set("has_nvg", true)
				s.set("flashlight_on", false)
		_show_notification("NVG issued to squad!")
	else:
		_show_notification("Not enough SP")

func _on_aim_overlay_draw() -> void:
	var selected: Node2D = _get_selected_squad()
	if selected == null:
		return
	var soldiers: Array = []
	if selected is SquadController:
		soldiers = (selected as SquadController).soldiers
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
	if _build_fort_type >= 0:
		if _build_anchor_set == false:
			var b_in_range: bool = center.distance_to(mouse_world) <= BUILD_MAX_RANGE
			var b_color: Color = Color(0.2, 1.0, 0.3, 0.45) if b_in_range else Color(1.0, 0.2, 0.2, 0.45)
			_aim_overlay.draw_arc(center, BUILD_MAX_RANGE, 0.0, TAU, 48, Color(0.9, 0.9, 0.9, 0.5), 1.5)
			_aim_overlay.draw_line(center, mouse_world, b_color, 1.5)
			_aim_overlay.draw_circle(mouse_world, 8.0, b_color)
		else:
			_build_rotation = (mouse_world - _build_anchor_pos).angle() + PI / 2.0
			_aim_overlay.draw_line(_build_anchor_pos, mouse_world, Color(0.9, 0.9, 0.2, 0.7), 2.0)
			var fort_size: Vector2 = Vector2(48.0, 16.0)
			match _build_fort_type:
				FieldFortification.FortType.SANDBAGS: fort_size = Vector2(48.0, 16.0)
				FieldFortification.FortType.BARBED_WIRE: fort_size = Vector2(56.0, 14.0)
				FieldFortification.FortType.AUTO_TURRET: fort_size = Vector2(22.0, 22.0)
			_aim_overlay.draw_set_transform(_build_anchor_pos, _build_rotation, Vector2.ONE)
			_aim_overlay.draw_rect(Rect2(-fort_size / 2.0, fort_size), Color(0.2, 1.0, 0.3, 0.65), false, 2.0)
			_aim_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if not _grenade_mode and not _mine_mode:
		return
	var max_r: float = GRENADE_MAX_RANGE if _grenade_mode else MINE_MAX_RANGE
	var aoe_r: float = 50.0 if _grenade_mode else 25.0
	var in_range: bool = center.distance_to(mouse_world) <= max_r
	var color: Color = Color(0.2, 1.0, 0.3, 0.45) if in_range else Color(1.0, 0.2, 0.2, 0.45)
	_aim_overlay.draw_arc(center, max_r, 0.0, TAU, 48, Color(0.9, 0.9, 0.9, 0.5), 1.5)
	_aim_overlay.draw_line(center, mouse_world, color, 1.5)
	_aim_overlay.draw_circle(mouse_world, aoe_r, color)

func _get_selected_squad() -> Node2D:
	var sel_mgr: Node = get_tree().current_scene.get_node_or_null("SelectionManager")
	if sel_mgr != null:
		var selected: Array = sel_mgr.get("selected_squads")
		if selected != null and selected.size() > 0 and is_instance_valid(selected[0]):
			return selected[0] as Node2D
	return null

func _show_notification(text: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("game_hud")
	if hud != null and hud.has_method("_show_notification"):
		hud.call("_show_notification", text)

func _on_cancel_mode_pressed() -> void:
	_mine_mode = false
	_grenade_mode = false
	_artillery_mode = false
	_flare_mode = false
	_build_fort_type = -1
	_build_anchor_set = false

func _make_btn(text: String, tooltip: String, callable: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.tooltip_text = tooltip
	btn.pressed.connect(callable)
	return btn

func _process(_delta: float) -> void:
	if _aim_overlay != null:
		_aim_overlay.queue_redraw()

	var squad: Node2D = _get_selected_squad()
	if squad == null:
		visible = false
		return
	visible = true

	if _cancel_mode_btn != null:
		_cancel_mode_btn.visible = (_mine_mode or _grenade_mode or _artillery_mode or _flare_mode or _build_fort_type >= 0)

	var spec: SpecialistComponent = squad.get_node_or_null("SpecialistComponent") as SpecialistComponent
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
			_flashlight_btn.text = "Flashlight: " + ("ON" if on else "OFF")

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

func _exit_tree() -> void:
	if _aim_overlay != null and is_instance_valid(_aim_overlay):
		_aim_overlay.queue_free()
		_aim_overlay = null


func _input(event: InputEvent) -> void:
	if get_viewport().gui_get_hovered_control() != null:
		return
	# Cancel any active mode on Esc
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
	# Cancel on RMB
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
	# Hotkey G for grenade
	if event is InputEventKey and event.keycode == KEY_G and event.pressed:
		if not _grenade_mode:
			if _eco != null and _eco.get_sp() >= 30:
				_grenade_mode = true
				_mine_mode = false
				_artillery_mode = false
				_flare_mode = false
			else:
				_show_notification("Not enough SP")
		else:
			_grenade_mode = false
	# Hotkey L for flashlight toggle
	if event is InputEventKey and event.keycode == KEY_L and event.pressed:
		_on_flashlight_toggle()
	# LMB click handling for all modes
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
		if _flare_mode:
			_flare_mode = false
			if _eco != null and _eco.spend_sp(30):
				var fog: FogOfWarManager = get_tree().get_first_node_in_group("fog_of_war") as FogOfWarManager
				if fog != null:
					fog.add_flare(world_pos, 420.0, 15.0)
			else:
				_show_notification("Not enough SP")
			get_viewport().set_input_as_handled()
			return
		if _mine_mode:
			_mine_mode = false
			get_viewport().set_input_as_handled()
			var selected: Node2D = _get_selected_squad()
			if selected != null:
				var soldiers: Array = []
				if selected is SquadController:
					soldiers = (selected as SquadController).soldiers
				var center: Vector2 = Vector2.ZERO
				var count: int = 0
				for s in soldiers:
					if is_instance_valid(s) and s is Node2D:
						center += (s as Node2D).global_position
						count += 1
				if count > 0:
					center /= float(count)
					if center.distance_to(world_pos) > MINE_MAX_RANGE:
						_show_notification("Too far!")
						return
				var spec: SpecialistComponent = selected.get_node_or_null("SpecialistComponent") as SpecialistComponent
				if spec != null and spec.specialist_type == SpecialistComponent.Type.SAPPER:
					if _eco != null and _eco.spend_sp(40):
						spec.place_mine(world_pos)
					else:
						_show_notification("Not enough SP")
			return
		if _artillery_mode:
			_artillery_mode = false
			_aoe_damage(world_pos, 100.0, 80)
		if _grenade_mode:
			_grenade_mode = false
			get_viewport().set_input_as_handled()
			var selected: Node2D = _get_selected_squad()
			if selected != null:
				var soldiers: Array = []
				if selected is SquadController:
					soldiers = (selected as SquadController).soldiers
				var center: Vector2 = Vector2.ZERO
				var count: int = 0
				for s in soldiers:
					if is_instance_valid(s) and s is Node2D:
						center += (s as Node2D).global_position
						count += 1
				if count > 0:
					center /= float(count)
					if center.distance_to(world_pos) > GRENADE_MAX_RANGE:
						_show_notification("Too far!")
						return
				if _eco != null and _eco.spend_sp(30):
					_aoe_damage(world_pos, 50.0, 60)
				else:
					_show_notification("Not enough SP")
			return
		if _build_fort_type >= 0:
			get_viewport().set_input_as_handled()
			var selected: Node2D = _get_selected_squad()
			if selected == null:
				_build_fort_type = -1
				_build_anchor_set = false
				return
			if not _build_anchor_set:
				var soldiers: Array = []
				if selected is SquadController:
					soldiers = (selected as SquadController).soldiers
				var center: Vector2 = Vector2.ZERO
				var count: int = 0
				for s in soldiers:
					if is_instance_valid(s) and s is Node2D:
						center += (s as Node2D).global_position
						count += 1
				if count > 0:
					center /= float(count)
					if center.distance_to(world_pos) > BUILD_MAX_RANGE:
						_show_notification("Too far!")
						return
				_build_anchor_pos = world_pos
				_build_anchor_set = true
				_build_rotation = 0.0
				_show_notification("Rotate with mouse & click LMB")
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
						_show_notification("Not enough SP")
func _aoe_damage(center: Vector2, radius: float, damage: int) -> void:
	var cam: Camera2D = get_tree().get_first_node_in_group("rts_camera") as Camera2D
	if cam != null and cam.has_method("shake"):
		cam.call("shake", 10.0, 0.3)
	var flash: ColorRect = ColorRect.new()
	flash.size = Vector2(radius * 2.0, radius * 2.0)
	flash.position = center - Vector2(radius, radius)
	flash.color = Color(1.0, 0.5, 0.0, 0.7)
	flash.z_index = 50
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.name = "AOEFlash"
	flash.add_to_group("mission_cleanup")
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