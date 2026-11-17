extends CharacterBody2D

@export var move_speed: float = 180.0
@export var formation_offset: Vector2 = Vector2.ZERO

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var target_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_physics_process(false)

func set_destination(destination: Vector2) -> void:
	target_position = destination
	nav_agent.set_target_position(destination)
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		move_and_slide()
		set_physics_process(false)
		return
	
	var next_pos: Vector2 = nav_agent.get_next_path_position()
	
	if next_pos == Vector2.ZERO:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	var dir: Vector2 = (next_pos - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()