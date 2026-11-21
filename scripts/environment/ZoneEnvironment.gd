class_name ZoneEnvironment extends Node2D

func _ready() -> void:
	add_to_group("mission_cleanup")
	z_index = 0

func generate_map(seed_val: int = 0) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()
	# --- АСФАЛЬТОВАЯ ДОРОГА ---
	var road: Area2D = Area2D.new()
	road.name = "Road"
	var road_coll: CollisionShape2D = CollisionShape2D.new()
	road_coll.shape = RectangleShape2D.new()
	(road_coll.shape as RectangleShape2D).size = Vector2(1920.0, 70.0)
	road.add_child(road_coll)

	var road_visual: ColorRect = ColorRect.new()
	road_visual.color = Color(0.22, 0.23, 0.25, 0.85)
	road_visual.size = Vector2(1920.0, 70.0)
	road_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	road.add_child(road_visual)

	# Прерывистая жёлтая разметка по центру
	for i in range(0, 1920, 60):
		var dash: ColorRect = ColorRect.new()
		dash.color = Color(0.95, 0.85, 0.05, 0.9)
		dash.size = Vector2(30.0, 6.0)
		dash.position = Vector2(float(i), 32.0)
		dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		road_visual.add_child(dash)

	# Центрирование
	road.position = Vector2(960.0, 540.0)
	road_visual.position = Vector2(-960.0, -35.0)
	add_child(road)

	# body_entered: +30% техника, +15% пехота
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

	# body_exited: пересчитать скорость без дороги
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
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()
	var placed: Array[Vector2] = []
	# --- БОЛОТА (3–4 зоны) ---
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
	# --- РАДИОАКТИВНЫЕ ЛУЖИ (2–3 пятна) ---
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

		# Подпись "РАД."
		var label: Label = Label.new()
		label.text = "РАД."
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
	# --- РЖАВЫЕ ОСТЫВЫ ТЕХНИКИ И БЕТОННЫЕ РУИНЫ (5–6 объектов) ---
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

		# Центрирование cover_visual
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
	# --- КОСТРЫ СТАЛКЕРОВ (2 точки) ---
	var campfire_count: int = 2
	for i in range(campfire_count):
		var campfire: Node2D = Node2D.new()
		campfire.name = "Campfire_%d" % i
		campfire.add_to_group("campfires")
		campfire.add_to_group("mission_cleanup")

		# Кострище
		var base_rect: ColorRect = ColorRect.new()
		base_rect.color = Color(0.12, 0.1, 0.08, 0.95)
		base_rect.size = Vector2(14.0, 14.0)
		base_rect.position = Vector2(-7.0, -7.0)
		base_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		campfire.add_child(base_rect)

		# Пульсирующий оранжевый огонёк
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
func _pick_free_spot(rng: RandomNumberGenerator, placed: Array[Vector2], min_dist: float) -> Vector2:
	for attempt in range(40):
		var x: float = float(rng.randi_range(420, 1500))
		var y: float = float(rng.randi_range(160, 920))
		if absf(y - 540.0) < 105.0:
			continue
		var candidate := Vector2(x, y)
		var ok: bool = true
		for p in placed:
			if p.distance_to(candidate) < min_dist:
				ok = false
				break
		if ok:
			return candidate
	return Vector2(float(rng.randi_range(420, 1500)), 250.0)