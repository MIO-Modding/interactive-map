class_name LocationIcon extends Polygon2D

@onready var camera: Camera2D = get_parent().get_parent().get_node("Camera2D")


func _ready() -> void:
	camera.zoom_changed.connect(func(v): scale = Vector2(1.0, 1.0) * clampf(((35.0 - v)/25.0), 0.4, 1.0))

var icon_type: String:
	set(v):
		if v not in Main.MAP_ICON_TEXTURES:
			v = "Default"
		icon_type = v
		$icon_image.texture = Main.MAP_ICON_TEXTURES[icon_type]

var is_checked: bool:
	set(v):
		is_checked = v
		if v:
			self_modulate.a = 0.05
			modulate.a = 0.3
		else:
			self_modulate.a = 1.0
			modulate.a = 1.0


var icon_style: String:
	set(v):
		icon_style = v
		if v == "Border Color":
			$icon_image.modulate = Color.WHITE
			$inner_background.modulate.a = 1
		elif v == "Full Color":
			$icon_image.modulate = Color.BLACK
			$inner_background.modulate.a = 0
			
