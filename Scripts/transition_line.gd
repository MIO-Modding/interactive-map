class_name TransitionLine extends Line2D


@onready var camera: Camera2D = get_parent().get_parent().get_node("Camera2D")

var transition_panel: TransitionPanel


func _process(_delta: float) -> void:
	width = 1 / ceilf(camera.zoom.x / 10)
