class_name FogOfWarManager
extends Node2D

const SUB_W: int = 480
const SUB_H: int = 270
const SCALE: float = 4.0

var is_night: bool = false
var _rect: TextureRect
var _flares: Array = []
var _time: float = 0.0
var _night_synced: bool = false
var _update_timer: float = 0.0
var _sub_viewport: SubViewport
var _fog_drawer: Node2D
var _fog_base: ColorRect

func _ready() -> void:
	z_index = 50
	add_to_group("fog_of_war")

	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2(SUB_W, SUB_H)
	_sub_viewport.transparent_bg = true
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub_viewport)

	_fog_base = ColorRect.new()
	_fog_base.name = "FogBase"
	_fog_base.size = Vector2(SUB_W, SUB_H)
	_fog_base.color = Color(0, 0, 0, 0.45)
	_sub_viewport.add_child(_fog_base)

	_fog_drawer = Node2D.new()
	_fog_drawer.name = "FogDrawer"
	_fog_drawer.set_script(preload("res://scripts/core/FogDrawer.gd"))
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
	_fog_drawer.material = mat
	_sub_viewport.add_child(_fog_drawer)

	_rect = TextureRect.new()
	_rect.name = "FogRect"
	_rect.size = Vector2(SUB_W, SUB_H)
	_rect.scale = Vector2(SCALE, SCALE)
	_rect.texture = _sub_viewport.get_texture()
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_try_sync_night()

func _try_sync_night() -> void:
	if _night_synced:
		return
	var hud: GameHUD = get_parent().get_node_or_null("GameHUD") as GameHUD
	if hud != null:
		is_night = hud._is_night
		_night_synced = true
	else:
		call_deferred("_try_sync_night")

func set_night(enabled: bool) -> void:
	is_night = enabled
	if _fog_base != null:
		_fog_base.color = Color(0, 0, 0, 0.90 if enabled else 0.45)
	if _fog_drawer != null:
		_fog_drawer.update_night_alpha(enabled)
		_fog_drawer.queue_redraw()

func add_flare(pos: Vector2, radius: float = 420.0, duration: float = 15.0) -> void:
	var node := _make_flare_visual(pos, radius)
	get_parent().add_child(node)
	var expire: float = Time.get_ticks_msec() / 1000.0 + duration
	_flares.append({"pos": pos, "radius": radius, "expire": expire, "duration": duration, "node": node})

func _make_flare_visual(pos: Vector2, radius: float) -> Node2D:
	var root := Node2D.new()
	root.global_position = pos
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(24):
		var a: float = TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	poly.polygon = pts
	poly.color = Color(1.0, 0.9, 0.5, 0.35)
	root.add_child(poly)
	return root

func _process(delta: float) -> void:
	_time += delta
	var now: float = Time.get_ticks_msec() / 1000.0
	for i in range(_flares.size() - 1, -1, -1):
		var f: Dictionary = _flares[i]
		var remaining: float = float(f["expire"]) - now
		if remaining <= 0.0:
			var n: Node = f["node"] as Node
			if is_instance_valid(n):
				n.queue_free()
			_flares.remove_at(i)
			continue
		var node: Node2D = f["node"] as Node2D
		if is_instance_valid(node):
			var dur: float = float(f["duration"])
			var base_a: float = clampf(remaining / dur, 0.0, 1.0) * 0.4
			var pulse: float = 0.8 + 0.2 * sin(_time * 4.0)
			node.modulate.a = base_a * pulse
	_update_timer += delta
	if _update_timer >= 0.1:
		_update_timer = 0.0
		_update_fog()

func _collect_sources() -> Array:
	var tree: SceneTree = get_tree()
	if tree == null:
		return []
	var sources: Array = []
	for squad in tree.get_nodes_in_group("player_squads"):
		if not is_instance_valid(squad):
			continue
		var soldiers: Array = squad.get("soldiers")
		if soldiers == null:
			continue
		for s in soldiers:
			if not is_instance_valid(s):
				continue
			var rank: int = 0
			var vc: VeterancyComponent = s.get_node_or_null("VeterancyComponent") as VeterancyComponent
			if vc != null:
				rank = vc.rank
			var has_nvg: bool = bool(s.get("has_nvg"))
			var flashlight_on: bool = bool(s.get("flashlight_on"))
			var thermal: bool = false
			var r: float = 450.0  # день
			if is_night:
				if rank == VeterancyComponent.Rank.ROOKIE and not has_nvg:
					r = 110.0  # новичок без ПНВ 
				elif has_nvg:
					r = 290.0  # ПНВ — не тепловизор
					thermal = false
				elif rank == VeterancyComponent.Rank.VETERAN:
					r = 380.0  # ветеран — тепловизор
					thermal = true
				elif rank == VeterancyComponent.Rank.ELITE:
					r = 430.0  # элита — тепловизор
					thermal = true
			sources.append({"pos": s.global_position, "radius": r, "thermal": thermal, "cone": false, "dir": Vector2.ZERO})
			if is_night and rank == VeterancyComponent.Rank.ROOKIE and not has_nvg and flashlight_on:
				var raw_dir: Variant = s.get("_last_facing")
				var dir: Vector2 = Vector2.RIGHT
				if raw_dir is Vector2 and (raw_dir as Vector2).length() > 0.01:
					dir = (raw_dir as Vector2).normalized()
				sources.append({"pos": s.global_position, "radius": 320.0, "thermal": false, "cone": true, "dir": dir, "half_deg": 25.0})
	for v in get_tree().get_nodes_in_group("player_vehicles"):
		if is_instance_valid(v) and v is Node2D:
			sources.append({"pos": (v as Node2D).global_position, "radius": 450.0, "thermal": true, "cone": false, "dir": Vector2.ZERO})
	for d in get_tree().get_nodes_in_group("player_drones"):
		if is_instance_valid(d) and d is Node2D:
			sources.append({"pos": (d as Node2D).global_position, "radius": 450.0, "thermal": true, "cone": false, "dir": Vector2.ZERO})
	for cp in get_tree().get_nodes_in_group("control_points"):
		if is_instance_valid(cp) and cp is Node2D:
			var owner_val: int = int(cp.get("point_owner"))
			if owner_val == ControlPoint.Owner.PLAYER:
				sources.append({"pos": (cp as Node2D).global_position, "radius": 250.0, "thermal": false, "cone": false, "dir": Vector2.ZERO})
	for f in _flares:
		sources.append({"pos": f["pos"], "radius": float(f["radius"]), "thermal": false, "cone": false, "dir": Vector2.ZERO})
	return sources

func _update_fog() -> void:
	var sources: Array = _collect_sources()
	_fog_drawer.sources = sources
	_fog_drawer.update_night_alpha(is_night)
	_fog_drawer.queue_redraw()
	_update_visibility(sources)

func _source_sees(src: Dictionary, pos: Vector2) -> bool:
	var radius: float = float(src["radius"])
	var dist: float = pos.distance_to(src["pos"])
	if bool(src["cone"]):
		if dist <= radius:
			var dir: Vector2 = src["dir"]
			var ang: float = abs(dir.angle_to(pos - src["pos"]))
			return ang <= deg_to_rad(float(src["half_deg"]))
		return false
	return dist <= radius

func _is_visible(pos: Vector2, sources: Array, thermal_only: bool = false) -> bool:
	for src in sources:
		if thermal_only and not bool(src["thermal"]):
			continue
		if _source_sees(src, pos):
			return true
	return false

func _update_visibility(sources: Array) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var enemy_groups: Array[String] = ["enemy_units", "enemy_vehicles", "enemy_drones", "mutants"]
	for g in enemy_groups:
		for node in tree.get_nodes_in_group(g):
			if not is_instance_valid(node) or not (node is Node2D):
				continue
			var vis: bool = _is_visible((node as Node2D).global_position, sources)
			(node as Node).visible = vis
			if is_night and vis and _is_visible((node as Node2D).global_position, sources, true):
				(node as CanvasItem).modulate = Color(1.0, 0.55, 0.2, 1.0)
			elif not is_night:
				(node as CanvasItem).modulate = Color.WHITE
	for g in ["anomaly_zones", "artifact_pickups"]:
		for node in tree.get_nodes_in_group(g):
			if not is_instance_valid(node) or not (node is Node2D):
				continue
			(node as Node).visible = _is_visible((node as Node2D).global_position, sources)

func _exit_tree() -> void:
	_restore_all_visibility()

func _restore_all_visibility() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var groups: Array[String] = ["enemy_units", "enemy_vehicles", "enemy_drones", "mutants", "anomaly_zones", "artifact_pickups"]
	for g in groups:
		for node in tree.get_nodes_in_group(g):
			if is_instance_valid(node):
				node.visible = true
				if node is CanvasItem:
					(node as CanvasItem).modulate = Color.WHITE
