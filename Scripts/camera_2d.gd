extends Camera2D


func _process(_delta: float) -> void:
	var previous_zoom: Vector2 = zoom
	
	if Input.is_action_just_released("scroll_up"):
		zoom *= 1.1
	if Input.is_action_just_released("scroll_down"):
		zoom /= 1.1
	
	position = get_global_mouse_position() - ((get_global_mouse_position() - position) * (previous_zoom / zoom))
