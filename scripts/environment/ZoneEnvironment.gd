class_name ZoneEnvironment extends Node2D

const _CFG := preload("res://scripts/core/GameConfig.gd")

var checkpoint_pos: Vector2 = Vector2(1480.0, 720.0)
var town_pos: Vector2 = Vector2(1150.0, 340.0)
var crossroad_pos: Vector2 = Vector2(1280.0, 720.0)
var road_y: float = 720.0
var crossroad_x: float = -1.0

func _ready() -> void:
	add_to_group("mission_cleanup")
	z_index = 0

func generate_map(seed_val: int = 0) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()
	road_y = float(rng.randi_range(440, 1000))
	var add_branch: bool = rng.randf_range(0.0, 1.0) < 0.7
	if add_branch:
		crossroad_x = float(rng.randi_range(950, 1850))
	crossroad_pos = Vector2(crossroad_x, road_y) if crossroad_x > 0.0 else Vector2(float(rng.randi_range(950, 1450)), road_y)
	checkpoint_pos = Vector2(float(rng.randi_range(1550, 1950)), road_y)
	var town_y: float = float(rng.randi_range(280, 420)) if road_y > 720.0 else float(rng.randi_range(1020, 1160))
	town_pos = Vector2(float(rng.randi_range(750, 1750)), town_y)
	# --- РђРЎР¤РђР›Р¬РўРћР’РђРЇ Р”РћР РћР“Рђ ---
	var road: Area2D = Area2D.new()
	road.name = "Road"
	var road_coll: CollisionShape2D = CollisionShape2D.new()
	road_coll.shape = RectangleShape2D.new()
	(road_coll.shape as RectangleShape2D).size = Vector2(_CFG.MAP_WIDTH, 70.0)
	road.add_child(road_coll)

	var road_visual: ColorRect = ColorRect.new()
	road_visual.color = Color(0.22, 0.23, 0.25, 0.85)
	road_visual.size = Vector2(_CFG.MAP_WIDTH, 70.0)
	road_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	road.add_child(road_visual)

	# РџСЂРµСЂС‹РІРёСЃС‚Р°СЏ Р¶С‘Р»С‚Р°СЏ СЂР°Р·РјРµС‚РєР° РїРѕ С†РµРЅС‚СЂСѓ
	for i in range(0, int(_CFG.MAP_WIDTH), 60):
		var dash: ColorRect = ColorRect.new()
		dash.color = Color(0.95, 0.85, 0.05, 0.9)
		dash.size = Vector2(30.0, 6.0)
		dash.position = Vector2(float(i), 32.0)
		dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		road_visual.add_child(dash)

	# Р¦РµРЅС‚СЂРёСЂРѕРІР°РЅРёРµ
	road.position = Vector2(_CFG.MAP_WIDTH * 0.5, road_y)
	road_visual.position = Vector2(-_CFG.MAP_WIDTH * 0.5, -35.0)
	add_child(road)
	if add_branch:
		var branch_visual: ColorRect = ColorRect.new()
		branch_visual.size = Vector2(70.0, float(_CFG.MAP_HEIGHT))
		branch_visual.position = Vector2(crossroad_x - 35.0, 0.0)
		branch_visual.color = Color(0.22, 0.23, 0.25, 0.85)
		branch_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(branch_visual)

	# body_entered: +30% С‚РµС…РЅРёРєР°, +15% РїРµС…РѕС‚Р°
	road.body_entered.connect(func(body: Node) -> void:
		if body.get("move_speed") == null:
			return
		if not body.has_meta("terrain_base_move_speed"):
			body.set_meta("terrain_base_move_speed", body.get("move_speed"))
		if not body.has_meta("road_mult"):
			body.set_meta("road_mult", 1.0)
		if not body.has_meta("swamp_mult"):
			body.set_meta("swamp_mult", 1.0)
		var road_mult: float = 1.0
		if body.is_in_group("player_vehicles") or body.is_in_group("enemy_vehicles"):
			road_mult = 1.3
		elif body.is_in_group("player_units") or body.is_in_group("enemy_units"):
			road_mult = 1.15
		body.set_meta("road_mult", road_mult)
		var base_speed: float = float(body.get_meta("terrain_base_move_speed"))
		var current_road_mult: float = float(body.get_meta("road_mult"))
		var current_swamp_mult: float = float(body.get_meta("swamp_mult"))
		body.set("move_speed", base_speed * current_road_mult * current_swamp_mult)
	)

	# body_exited: РїРµСЂРµСЃС‡РёС‚Р°С‚СЊ СЃРєРѕСЂРѕСЃС‚СЊ Р±РµР· РґРѕСЂРѕРіРё
	road.body_exited.connect(func(body: Node) -> void:
		if not body.has_meta("terrain_base_move_speed"):
			return
		body.set_meta("road_mult", 1.0)
		var base_speed: float = float(body.get_meta("terrain_base_move_speed"))
		var current_road_mult: float = float(body.get_meta("road_mult"))
		var current_swamp_mult: float = 1.0
		if body.has_meta("swamp_mult"):
			current_swamp_mult = float(body.get_meta("swamp_mult"))
		body.set("move_speed", base_speed * current_road_mult * current_swamp_mult)
	)

	var placed: Array[Vector2] = []
	_build_checkpoint(rng, checkpoint_pos)
	_build_ruined_town(rng, town_pos, placed)

	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()
	# --- Р‘РћР›РћРўРђ (3вЂ“4 Р·РѕРЅС‹) ---
	var swamp_count: int = rng.randi_range(3, 4)
	for i in range(swamp_count):
		var swamp: Area2D = Area2D.new()
		swamp.name = "Swamp_%d" % i
		var swamp_coll: CollisionShape2D = CollisionShape2D.new()
		swamp_coll.shape = RectangleShape2D.new()
		(swamp_coll.shape as RectangleShape2D).size = Vector2(180.0, 130.0)
		swamp.add_child(swamp_coll)

		var swamp_visual: ColorRect = ColorRect.new()
		swamp_visual.color = Color(0.18, 0.24, 0.14, 0.78)
		swamp_visual.size = Vector2(180.0, 130.0)
		swamp_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swamp_visual.position = Vector2(-90.0, -65.0)
		swamp.add_child(swamp_visual)

		swamp.position = _pick_free_spot(rng, placed, 150.0)
		placed.append(swamp.position)
		add_child(swamp)

		swamp.body_entered.connect(func(body: Node) -> void:
			if body.get("move_speed") == null:
				return
			if not body.has_meta("terrain_base_move_speed"):
				body.set_meta("terrain_base_move_speed", body.get("move_speed"))
			if not body.has_meta("road_mult"):
				body.set_meta("road_mult", 1.0)
			if not body.has_meta("swamp_mult"):
				body.set_meta("swamp_mult", 1.0)
			body.set_meta("swamp_mult", 0.6)
			var base_speed: float = float(body.get_meta("terrain_base_move_speed"))
			var current_road_mult: float = float(body.get_meta("road_mult"))
			var current_swamp_mult: float = float(body.get_meta("swamp_mult"))
			body.set("move_speed", base_speed * current_road_mult * current_swamp_mult)
		)

		swamp.body_exited.connect(func(body: Node) -> void:
			if not body.has_meta("terrain_base_move_speed"):
				return
			body.set_meta("swamp_mult", 1.0)
			var base_speed: float = float(body.get_meta("terrain_base_move_speed"))
			var current_road_mult: float = 1.0
			if body.has_meta("road_mult"):
				current_road_mult = float(body.get_meta("road_mult"))
			var current_swamp_mult: float = float(body.get_meta("swamp_mult"))
			body.set("move_speed", base_speed * current_road_mult * current_swamp_mult)
		)
	# --- Р РђР”РРћРђРљРўРР’РќР«Р• Р›РЈР–Р (2вЂ“3 РїСЏС‚РЅР°) ---
	var rad_count: int = rng.randi_range(2, 3)
	for i in range(rad_count):
		var rad: Area2D = Area2D.new()
		rad.name = "RadPuddle_%d" % i
		var rad_coll: CollisionShape2D = CollisionShape2D.new()
		rad_coll.shape = RectangleShape2D.new()
		(rad_coll.shape as RectangleShape2D).size = Vector2(80.0, 80.0)
		rad.add_child(rad_coll)

		var rad_visual: ColorRect = ColorRect.new()
		rad_visual.color = Color(0.25, 0.85, 0.2, 0.42)
		rad_visual.size = Vector2(80.0, 80.0)
		rad_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rad.add_child(rad_visual)

		# РџРѕРґРїРёСЃСЊ "Р РђР”."
		var label: Label = Label.new()
		label.text = "RAD"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(80.0, 80.0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 10)
		rad.add_child(label)

		rad_visual.position = Vector2(-40.0, -40.0)
		label.position = Vector2(-40.0, -40.0)
		rad.position = _pick_free_spot(rng, placed, 130.0)
		placed.append(rad.position)
		rad.set_script(preload("res://scripts/environment/RadZone.gd"))
		add_child(rad)
	# --- Р Р–РђР’Р«Р• РћРЎРўР«Р’Р« РўР•РҐРќРРљР Р Р‘Р•РўРћРќРќР«Р• Р РЈРРќР« (5вЂ“6 РѕР±СЉРµРєС‚РѕРІ) ---
	var cover_count: int = rng.randi_range(5, 6)
	for i in range(cover_count):
		var is_btr: bool = rng.randi_range(0, 1) == 0
		var cover: StaticBody2D = StaticBody2D.new()
		cover.name = "Cover_%d" % i

		var cover_coll: CollisionShape2D = CollisionShape2D.new()
		cover_coll.shape = RectangleShape2D.new()
		var w: float
		var h: float
		if is_btr:
			w = 44.0
			h = 24.0
		else:
			w = 60.0
			h = 20.0
		(cover_coll.shape as RectangleShape2D).size = Vector2(w, h)
		cover.add_child(cover_coll)

		var cover_visual: ColorRect = ColorRect.new()
		if is_btr:
			cover_visual.color = Color(0.38, 0.26, 0.18)
		else:
			cover_visual.color = Color(0.45, 0.46, 0.48)
		cover_visual.size = Vector2(w, h)
		cover_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.add_child(cover_visual)

		# Р¦РµРЅС‚СЂРёСЂРѕРІР°РЅРёРµ cover_visual
		cover_visual.position = Vector2(-w / 2.0, -h / 2.0)

		# CoverZone (Area2D + CircleShape2D radius 55.0)
		var cover_zone: Area2D = Area2D.new()
		cover_zone.name = "CoverZone"
		var cz_coll: CollisionShape2D = CollisionShape2D.new()
		cz_coll.shape = CircleShape2D.new()
		(cz_coll.shape as CircleShape2D).radius = 55.0
		cover_zone.add_child(cz_coll)
		cover_zone.set_script(load("res://scripts/components/CoverZone.gd"))
		cover.add_child(cover_zone)

		cover.position = _pick_free_spot(rng, placed, 110.0)
		placed.append(cover.position)
		add_child(cover)
	# --- РљРћРЎРўР Р« РЎРўРђР›РљР•Р РћР’ (2 С‚РѕС‡РєРё) ---
	var campfire_count: int = 2
	for i in range(campfire_count):
		var campfire: Node2D = Node2D.new()
		campfire.name = "Campfire_%d" % i
		campfire.add_to_group("campfires")
		campfire.add_to_group("mission_cleanup")

		# РљРѕСЃС‚СЂРёС‰Рµ
		var base_rect: ColorRect = ColorRect.new()
		base_rect.color = Color(0.12, 0.1, 0.08, 0.95)
		base_rect.size = Vector2(14.0, 14.0)
		base_rect.position = Vector2(-7.0, -7.0)
		base_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		campfire.add_child(base_rect)

		# РџСѓР»СЊСЃРёСЂСѓСЋС‰РёР№ РѕСЂР°РЅР¶РµРІС‹Р№ РѕРіРѕРЅС‘Рє
		var flame: ColorRect = ColorRect.new()
		flame.name = "Flame"
		flame.color = Color(1.0, 0.55, 0.1, 0.95)
		flame.size = Vector2(8.0, 8.0)
		flame.position = Vector2(-4.0, -4.0)
		flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		campfire.add_child(flame)

		campfire.position = _pick_free_spot(rng, placed, 120.0)
		placed.append(campfire.position)
		campfire.set_script(preload("res://scripts/environment/Campfire.gd"))
		add_child(campfire)

	# --- РћР±РЅРѕРІР»РµРЅРёРµ РЅР°РІРёРіР°С†РёРѕРЅРЅРѕР№ СЃРµС‚РєРё РґР»СЏ РЅРѕРІС‹С… Р·РґР°РЅРёР№ Рё Р±Р»РѕРєРѕРІ ---
	var nav_region: NavigationRegion2D = get_node_or_null("/root/Main/NavRegion") as NavigationRegion2D
	if nav_region != null:
		var np: NavigationPolygon = NavigationPolygon.new()
		var verts: PackedVector2Array = PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(_CFG.MAP_WIDTH, 0.0),
			Vector2(_CFG.MAP_WIDTH, _CFG.MAP_HEIGHT),
			Vector2(0.0, _CFG.MAP_HEIGHT),
		])
		np.vertices = verts
		np.polygons = [PackedInt32Array([0, 1, 2, 3])]
		nav_region.navigation_polygon = np
func _pick_free_spot(rng: RandomNumberGenerator, placed: Array[Vector2], min_dist: float) -> Vector2:
	for attempt in range(40):
		var x: float = float(rng.randi_range(450, 2150))
		var y: float = float(rng.randi_range(180, 1260))
		if absf(y - road_y) < 110.0 or (crossroad_x > 0.0 and absf(x - crossroad_x) < 70.0):
			continue
		var candidate := Vector2(x, y)
		var ok: bool = true
		for p in placed:
			if p.distance_to(candidate) < min_dist:
				ok = false
				break
		if ok:
			return candidate
	return Vector2(float(rng.randi_range(450, 2150)), _CFG.MAP_HEIGHT * 0.5)

func _build_checkpoint(rng: RandomNumberGenerator, pos: Vector2) -> void:
	# Р‘РµС‚РѕРЅРЅС‹Рµ Р±Р»РѕРєРё РїРѕРїРµСЂС‘Рє РґРѕСЂРѕРіРё вЂ” РєРѕСЂРёРґРѕСЂ РјРµР¶РґСѓ РЅРёРјРё >= 80px
	var block1: StaticBody2D = StaticBody2D.new()
	block1.name = "CheckpointBlock1"
	block1.position = pos + Vector2(-70.0, 0.0)
	var cs1: CollisionShape2D = CollisionShape2D.new()
	var rs1: RectangleShape2D = RectangleShape2D.new()
	rs1.size = Vector2(50.0, 22.0)
	cs1.shape = rs1
	block1.add_child(cs1)
	var vis1: ColorRect = ColorRect.new()
	vis1.size = Vector2(50.0, 22.0)
	vis1.position = Vector2(-25.0, -11.0)
	vis1.color = Color(0.45, 0.46, 0.48)
	vis1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block1.add_child(vis1)
	add_child(block1)

	var block2: StaticBody2D = StaticBody2D.new()
	block2.name = "CheckpointBlock2"
	block2.position = pos + Vector2(70.0, 0.0)
	var cs2: CollisionShape2D = CollisionShape2D.new()
	var rs2: RectangleShape2D = RectangleShape2D.new()
	rs2.size = Vector2(50.0, 22.0)
	cs2.shape = rs2
	block2.add_child(cs2)
	var vis2: ColorRect = ColorRect.new()
	vis2.size = Vector2(50.0, 22.0)
	vis2.position = Vector2(-25.0, -11.0)
	vis2.color = Color(0.45, 0.46, 0.48)
	vis2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block2.add_child(vis2)
	add_child(block2)

	# Р›РёРЅРёРё РјРµС€РєРѕРІ СЃ РїРµСЃРєРѕРј (РІС‹РЅРµСЃРµРЅС‹ Р·Р° РїСЂРµРґРµР»С‹ РєРѕСЂРёРґРѕСЂР°)
	var barbed_wire1: FieldFortification = FieldFortification.new()
	barbed_wire1.fort_type = FieldFortification.FortType.BARBED_WIRE
	barbed_wire1.position = pos + Vector2(-95.0, -55.0)
	barbed_wire1.name = "BarbedWire1"
	add_child(barbed_wire1)

	var barbed_wire2: FieldFortification = FieldFortification.new()
	barbed_wire2.fort_type = FieldFortification.FortType.BARBED_WIRE
	barbed_wire2.position = pos + Vector2(-95.0, 55.0)
	barbed_wire2.name = "BarbedWire2"
	add_child(barbed_wire2)
	var sandbags1: FieldFortification = FieldFortification.new()
	sandbags1.fort_type = FieldFortification.FortType.SANDBAGS
	sandbags1.position = pos + Vector2(0.0, -55.0)
	sandbags1.name = "CheckpointSandbags1"
	add_child(sandbags1)

	var sandbags2: FieldFortification = FieldFortification.new()
	sandbags2.fort_type = FieldFortification.FortType.SANDBAGS
	sandbags2.position = pos + Vector2(0.0, 55.0)
	sandbags2.name = "CheckpointSandbags2"
	add_child(sandbags2)

	# Р’Р·СЂС‹РІРЅР°СЏ Р±РѕС‡РєР° СЂСЏРґРѕРј СЃ РјРµС€РєР°РјРё
	var barrel: ExplosiveProp = ExplosiveProp.new()
	barrel.position = pos + Vector2(30.0, -30.0)
	barrel.explosion_radius = 150.0
	barrel.explosion_damage = 80
	barrel.hp = 40
	add_child(barrel)

	# Р Р°Р·СЂСѓС€Р°РµРјС‹Р№ РїСЂРѕР¶РµРєС‚РѕСЂ РљРџРџ
	var spotlight: StaticBody2D = StaticBody2D.new()
	spotlight.name = "KPPSpotlight"
	spotlight.position = pos + Vector2(0.0, -60.0)
	spotlight.add_to_group("spotlights")
	spotlight.add_to_group("enemy_units")
	var scs: CollisionShape2D = CollisionShape2D.new()
	var scrs: RectangleShape2D = RectangleShape2D.new()
	scrs.size = Vector2(14.0, 14.0)
	scs.shape = scrs
	spotlight.add_child(scs)
	var shp: ColorRect = ColorRect.new()
	shp.size = Vector2(14.0, 14.0)
	shp.position = Vector2(-7.0, -7.0)
	shp.color = Color(1.0, 0.9, 0.2, 1.0)
	shp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spotlight.add_child(shp)
	var shc: HealthComponent = HealthComponent.new()
	shc.name = "HealthComponent"
	shc.max_hp = 60
	shc.current_hp = 60
	spotlight.add_child(shc)
	shc.died.connect(func(_n: Node2D) -> void: spotlight.queue_free())
	add_child(spotlight)

	# Р’СЂР°Р¶РµСЃРєР°СЏ Р°РІС‚РѕС‚СѓСЂРµР»СЊ Сѓ РљРџРџ
	var turret: FieldFortification = FieldFortification.new()
	turret.fort_type = FieldFortification.FortType.AUTO_TURRET
	turret.position = pos + Vector2(-25.0, -70.0)
	turret.name = "CheckpointTurret"
	add_child(turret)
	turret.remove_from_group("player_units")
	turret.remove_from_group("player_turrets")
	turret.add_to_group("enemy_units")
	var turret_visual: ColorRect = turret.get_node_or_null("ColorRect") as ColorRect
	if turret_visual != null:
		turret_visual.color = Color(0.85, 0.25, 0.25)
	var turret_weapon: WeaponComponent = turret.get_node_or_null("WeaponComponent") as WeaponComponent
	if turret_weapon != null:
		turret_weapon.target_group = "player_units"

	# 2 СЏС‰РёРєР° Р»СѓС‚Р° РІРЅСѓС‚СЂРё РљРџРџ
	var loot1: LootCrate = LootCrate.new()
	loot1.loot_type = LootCrate.LootType.TROPHY_RPG
	loot1.position = pos + Vector2(45.0, -45.0)
	add_child(loot1)

	var loot2: LootCrate = LootCrate.new()
	loot2.loot_type = LootCrate.LootType.SP_CACHE
	loot2.position = pos + Vector2(45.0, 45.0)
	add_child(loot2)

	# Р“Р°СЂРЅРёР·РѕРЅ РІСЂР°РіРѕРІ Сѓ РљРџРџ вЂ” РЅР° РѕС‚РєСЂС‹С‚РѕР№ РїР»РѕС‰Р°РґРєРµ РїРѕР·Р°РґРё СѓРєСЂРµРїР»РµРЅРёР№
	MissionBuilder.spawn_enemy_squad(get_parent(), pos + Vector2(95.0, -55.0), 3)
	MissionBuilder.spawn_enemy_squad(get_parent(), pos + Vector2(95.0, 55.0), 3)

func _build_ruined_town(rng: RandomNumberGenerator, center: Vector2, placed: Array[Vector2]) -> void:
	# --- 2вЂ“3 РґР»РёРЅРЅС‹Рµ В«С…СЂСѓС‰С‘РІРєРёВ» (160x50 Рё 50x160, СЃС‚РµРЅС‹-height) ---
	var khrushchyovkas: Array[Vector2] = [
		Vector2(-220.0, -140.0),   # РіРѕСЂРёР·РѕРЅС‚Р°Р»СЊРЅР°СЏ 160x50
		Vector2(220.0, 20.0),      # РІРµСЂС‚РёРєР°Р»СЊРЅР°СЏ 50x160
		Vector2(0.0, 180.0),       # РіРѕСЂРёР·РѕРЅС‚Р°Р»СЊРЅР°СЏ 160x50
	]
	var khr_size: Array[Vector2] = [
		Vector2(160.0, 50.0),
		Vector2(50.0, 160.0),
		Vector2(160.0, 50.0),
	]
	var khrushchyovka_count: int = rng.randi_range(3, 4)
	for i in range(khrushchyovka_count):
		var building: StaticBody2D = StaticBody2D.new()
		building.name = "RuinedBuilding_Khrushchyovka_%d" % i
		building.position = center + khrushchyovkas[i % khrushchyovkas.size()] + Vector2(rng.randf_range(-25.0, 25.0), rng.randf_range(-25.0, 25.0))
		building.rotation = rng.randf_range(0.0, 1.0) * (PI * 0.5)
		building.set_meta("is_tall_wall", true)
		var bcs: CollisionShape2D = CollisionShape2D.new()
		var brs: RectangleShape2D = RectangleShape2D.new()
		brs.size = khr_size[i % khr_size.size()]
		bcs.shape = brs
		building.add_child(bcs)
		var bvis: ColorRect = ColorRect.new()
		bvis.size = brs.size
		bvis.position = -brs.size / 2.0
		bvis.color = Color(0.30, 0.32, 0.35)
		bvis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		building.add_child(bvis)
		add_child(building)

	# --- Р СЏРґ РіР°СЂР°Р¶РµР№ / СЃРєР»Р°РґРѕРІ (3вЂ“4 СѓР·РєРёС… Р±Р»РѕРєР° 75x32) ---
	var garages: Array[Vector2] = [
		Vector2(-320.0, 60.0),
		Vector2(320.0, 60.0),
		Vector2(-320.0, -100.0),
		Vector2(320.0, -100.0),
	]
	var garage_count: int = rng.randi_range(3, 4)
	for i in range(garage_count):
		var garage: StaticBody2D = StaticBody2D.new()
		garage.name = "Garage_%d" % i
		garage.position = center + garages[i % garages.size()] + Vector2(rng.randf_range(-25.0, 25.0), rng.randf_range(-25.0, 25.0))
		garage.rotation = rng.randf_range(0.0, 1.0) * (PI * 0.5)
		garage.set_meta("is_tall_wall", true)
		var gcs: CollisionShape2D = CollisionShape2D.new()
		var grs: RectangleShape2D = RectangleShape2D.new()
		grs.size = Vector2(75.0, 32.0)
		gcs.shape = grs
		garage.add_child(gcs)
		var gvis: ColorRect = ColorRect.new()
		gvis.size = Vector2(75.0, 32.0)
		gvis.position = Vector2(-37.5, -16.0)
		gvis.color = Color(0.36, 0.34, 0.31)
		gvis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		garage.add_child(gvis)
		add_child(garage)

	# --- Р”РІРѕСЂРѕРІР°СЏ РїР»РѕС‰Р°РґСЊ: 4вЂ“5 РЅРёР·РєРёС… СѓРєСЂС‹С‚РёР№ (CoverZone + СЂР¶Р°РІС‹Рµ РѕСЃС‚РѕРІС‹ РјР°С€РёРЅ) ---
	var cover_spots: Array[Vector2] = [
		Vector2(-90.0, -40.0), Vector2(90.0, -40.0),
		Vector2(-60.0, 60.0), Vector2(60.0, 60.0),
		Vector2(0.0, -90.0),
	]
	var cover_count: int = rng.randi_range(4, 5)
	for i in range(cover_count):
		# CoverZone
		var cover: Area2D = Area2D.new()
		cover.name = "CoverZone_Town_%d" % i
		cover.position = center + cover_spots[i]
		var cz: CollisionShape2D = CollisionShape2D.new()
		var czs: CircleShape2D = CircleShape2D.new()
		czs.radius = 30.0
		cz.shape = czs
		cover.add_child(cz)
		cover.set_script(load("res://scripts/components/CoverZone.gd"))
		add_child(cover)

		# Р Р¶Р°РІС‹Р№ РѕСЃС‚РѕРІ РјР°С€РёРЅС‹
		var wreck: StaticBody2D = StaticBody2D.new()
		wreck.name = "CarWreck_%d" % i
		wreck.position = center + cover_spots[i] + Vector2(rng.randi_range(-20, 20), rng.randi_range(-20, 20))
		var wcs: CollisionShape2D = CollisionShape2D.new()
		var wrs: RectangleShape2D = RectangleShape2D.new()
		wrs.size = Vector2(26.0, 14.0)
		wcs.shape = wrs
		wreck.add_child(wcs)
		var wvis: ColorRect = ColorRect.new()
		wvis.size = Vector2(26.0, 14.0)
		wvis.position = Vector2(-13.0, -7.0)
		wvis.color = Color(0.42, 0.30, 0.20)
		wvis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wreck.add_child(wvis)
		add_child(wreck)

	# --- РљРѕСЃС‚С‘СЂ СЃС‚Р°Р»РєРµСЂРѕРІ РІ С†РµРЅС‚СЂРµ РґРІРѕСЂР° ---
	var campfire: Node2D = Node2D.new()
	campfire.name = "Campfire_Town"
	campfire.add_to_group("campfires")
	campfire.add_to_group("mission_cleanup")
	var base_rect: ColorRect = ColorRect.new()
	base_rect.color = Color(0.12, 0.1, 0.08, 0.95)
	base_rect.size = Vector2(14.0, 14.0)
	base_rect.position = Vector2(-7.0, -7.0)
	base_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	campfire.add_child(base_rect)
	var flame: ColorRect = ColorRect.new()
	flame.name = "Flame"
	flame.color = Color(1.0, 0.55, 0.1, 0.95)
	flame.size = Vector2(8.0, 8.0)
	flame.position = Vector2(-4.0, -4.0)
	flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	campfire.add_child(flame)
	campfire.position = center + Vector2(0.0, -30.0)
	campfire.set_script(preload("res://scripts/environment/Campfire.gd"))
	add_child(campfire)

	# --- 2 СЏС‰РёРєР° Р»СѓС‚Р° ---
	var loot1: LootCrate = LootCrate.new()
	loot1.loot_type = LootCrate.LootType.SP_CACHE
	loot1.position = center + Vector2(60.0, 60.0)
	add_child(loot1)

	var loot2: LootCrate = LootCrate.new()
	loot2.loot_type = LootCrate.LootType.MEDKIT
	loot2.position = center + Vector2(-60.0, -60.0)
	add_child(loot2)

	# --- 1 СЃР»СѓС‡Р°Р№РЅР°СЏ Р°РЅРѕРјР°Р»РёСЏ РЅР° РѕРєСЂР°РёРЅРµ РєРІР°СЂС‚Р°Р»Р° ---
	var anomaly_pos: Vector2 = center + Vector2(-320.0, 200.0)
	var anomaly: AnomalyZone = AnomalyZone.new()
	anomaly.name = "TownAnomaly"
	anomaly.position = anomaly_pos
	anomaly.anomaly_type = AnomalyZone.AnomalyType.VORTEX
	anomaly.radius = 90.0
	anomaly.damage = 6
	add_child(anomaly)

	# РџРѕРјРµС‡Р°РµРј РІСЃСЋ Р·РѕРЅСѓ РіРѕСЂРѕРґРєР° (radius = 360px), С‡С‚РѕР±С‹ СЃР»СѓС‡Р°Р№РЅС‹Рµ Р±РѕР»РѕС‚Р° РЅРµ Р·Р°Р»РµР·Р°Р»Рё
	placed.append(center)


