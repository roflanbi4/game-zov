extends Node2D

@export var selection_color: Color = Color(0.0, 1.0, 0.0, 0.25)
@export var border_color: Color = Color(0.0, 1.0, 0.0, 0.9)

var is_selecting: bool = false
var selection_start: Vector2 = Vector2.ZERO
var selection_end: Vector2 = Vector2.ZERO
var selected_units: Array[CharacterBody2D] = []

signal selection_changed(selected: Array[CharacterBody2D])

func _ready() -> void:
	z_index = 100

func _process(_delta: float) -> void:
	if is_selecting:
		selection_end = get_global_mouse_position()
		queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			is_selecting = true
			selection_start = get_global_mouse_position()
			selection_end = selection_start
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			is_selecting = false
			_select_units_in_box()
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_issue_move_command(get_global_mouse_position())

func _draw() -> void:
	if is_selecting:
		var rect: Rect2 = Rect2(selection_start.min(selection_end), (selection_start - selection_end).abs())
		draw_rect(rect, selection_color, true)
		draw_rect(rect, border_color, false, 2.0)

func _select_units_in_box() -> void:
	var rect: Rect2 = Rect2(selection_start.min(selection_end), (selection_start - selection_end).abs())
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.modulate = Color.WHITE
	selected_units.clear()
	selection_changed.emit(selected_units)

func _issue_move_command(_target: Vector2) -> void:
	for unit in selected_units:
		pass
