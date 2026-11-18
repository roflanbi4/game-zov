class_name EconomyManager
extends Node

@export var starting_sp: int = 200
@export var passive_sp_per_sec: float = 2.0
@export var capture_point_income: float = 5.0

var _sp: int = 200
var _sp_generation_timer: float = 0.0

signal sp_changed(new_amount: int)

func _ready() -> void:
	add_to_group("economy")
	_sp = starting_sp
	_sp_generation_timer = 0.0
	emit_sp_changed()

func _process(delta: float) -> void:
	_sp_generation_timer += delta
	while _sp_generation_timer >= 1.0:
		_sp_generation_timer -= 1.0
		_sp += int(passive_sp_per_sec)
		emit_sp_changed()

func spend_sp(amount: int) -> bool:
	if _sp >= amount:
		_sp -= amount
		emit_sp_changed()
		return true
	return false

func add_sp(amount: int) -> void:
	_sp += amount
	emit_sp_changed()

func get_sp() -> int:
	return _sp

func emit_sp_changed() -> void:
	sp_changed.emit(_sp)
