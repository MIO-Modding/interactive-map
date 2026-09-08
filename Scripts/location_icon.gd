class_name LocationIcon extends Polygon2D



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
