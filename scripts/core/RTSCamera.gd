class_name RTSCamera
extends Camera2D

@export var pan_speed: float = 300.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.0
@export var edge_margin: float = 20.0

var screen_size: Vector2

func _ready() -> void:
	screen_size = get_viewport_rect().size
	# Ограничиваем камеру в пределах карты 1920x1080
	limit_left = 0
	limit_top = 0
	limit_right = 1920
	limit_bottom = 1080
	add_to_group("rts_camera")

func _process(delta: float) -> void:
	var input_dir: Vector2 = Vector2.ZERO
	
	# WASD + стрелочки (прямая проверка клавиш, без InputMap)
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	
	# Edge pan (screen-координаты подходят для определения края экрана)
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	if mouse_pos.x < edge_margin:
		input_dir.x -= 1.0
	elif mouse_pos.x > screen_size.x - edge_margin:
		input_dir.x += 1.0
	if mouse_pos.y < edge_margin:
		input_dir.y -= 1.0
	elif mouse_pos.y > screen_size.y - edge_margin:
		input_dir.y += 1.0
	
	# Перемещение камеры
	position += input_dir.normalized() * pan_speed * delta
	# Зажимаем в пределах карты
	position = position.clamp(Vector2.ZERO, Vector2(1920.0, 1080.0))

func shake(intensity: float = 8.0, duration: float = 0.25) -> void:
	var tween := create_tween()
	tween.tween_property(self, "offset", Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), duration * 0.33)
	tween.tween_property(self, "offset", Vector2.ZERO, duration * 0.33)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var new_zoom: float = clamp(zoom.x + zoom_speed, min_zoom, max_zoom)
			zoom = Vector2(new_zoom, new_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var new_zoom: float = clamp(zoom.x - zoom_speed, min_zoom, max_zoom)
			zoom = Vector2(new_zoom, new_zoom)