class_name TransitionLine extends Line2D


@onready var camera: Camera2D = get_parent().get_parent().get_node("Camera2D")

var transition_panel: TransitionPanel


func _ready() -> void:
	camera.zoom_changed.connect(func(v): width = 1 / ceilf(v / 10))
