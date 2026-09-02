class_name LocationLine extends Line2D


@onready var camera: Camera2D = get_parent().get_parent().get_node("Camera2D")

var loc_panel: LocationPanel


func _ready() -> void:
	camera.zoom_changed.connect(func(v): width = 1 / ceilf(v / 10))
