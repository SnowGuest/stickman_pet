class_name StickHead
extends Node2D

var radius: float = 18.0
var color: Color = Color("#FF6600")
var hollow: bool = true
var line_width: float = 6.0


func configure(p_radius: float, p_color: Color, p_hollow: bool, p_line_width: float) -> void:
	radius = p_radius
	color = p_color
	hollow = p_hollow
	line_width = p_line_width
	queue_redraw()


func _draw() -> void:
	if hollow:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, line_width, true)
	else:
		draw_circle(Vector2.ZERO, radius, color)
