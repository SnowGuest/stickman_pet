class_name PetShadow
extends Node2D

## 2.5D 接触阴影：只画地面椭圆，不参与角色线条和颜色。
var floor_y: float = 0.0
var shadow_radius: float = 52.0
var shadow_alpha: float = 0.16
var _walking: bool = false


func setup(p_floor_y: float, p_scale: float = 1.0) -> void:
	floor_y = p_floor_y
	shadow_radius = 52.0 * p_scale
	z_index = -1
	queue_redraw()


func update_from_pose(pose: RigPose, walking: bool) -> void:
	position = Vector2(pose.root_pos.x, floor_y - 2.0)
	_walking = walking
	queue_redraw()


func _draw() -> void:
	var alpha := shadow_alpha * (1.0 if _walking else 1.15)
	var points := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		points.append(Vector2(cos(a) * shadow_radius,
				sin(a) * shadow_radius * 0.22))
	draw_colored_polygon(points, Color(0.0, 0.0, 0.0, alpha))
