class_name FogDrawer
extends Node2D

var sources: Array = []
var is_night: bool = false

func update_night_alpha(enabled: bool) -> void:
	is_night = enabled

func _draw() -> void:
	for src in sources:
		var pos: Vector2 = (src["pos"] as Vector2) / 4.0
		var radius: float = float(src["radius"]) / 4.0
		if bool(src["cone"]):
			var dir: Vector2 = src["dir"] as Vector2
			var base_ang: float = dir.angle()
			var half_rad: float = deg_to_rad(float(src["half_deg"]))
			var pts := PackedVector2Array([
				pos,
				pos + Vector2(radius, 0.0).rotated(base_ang - half_rad),
				pos + Vector2(radius, 0.0).rotated(base_ang + half_rad)
			])
			draw_colored_polygon(pts, Color(1.0, 1.0, 1.0, 1.0))
		else:
			draw_circle(pos, radius, Color(1.0, 1.0, 1.0, 1.0))