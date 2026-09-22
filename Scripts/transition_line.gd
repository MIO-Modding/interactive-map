class_name TransitionLine extends Line2D


var transition_panel: TransitionPanel

var base_color: Color
var override_color: Color:
	set(v):
		override_color = v
		if v == Color.TRANSPARENT:
			default_color = base_color
		else:
			default_color = override_color

@onready var camera: Camera2D = get_parent().get_parent().get_node("Camera2D")


func _ready() -> void:
	camera.zoom_changed.connect(func(v): width = 1 / ceilf(v / 10))


func highlight(color := Color.HOT_PINK, timer: SceneTreeTimer = null) -> void:
	override_color = color
	await timer.timeout
	override_color = Color.TRANSPARENT
