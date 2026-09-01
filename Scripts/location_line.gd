class_name LocationLine extends Line2D


@onready var camera: Camera2D = get_parent().get_parent().get_node("Camera2D")

var loc_panel: LocationPanel


func _process(_delta: float) -> void:
	width = 0.6 / ceilf(camera.zoom.x / 10)
