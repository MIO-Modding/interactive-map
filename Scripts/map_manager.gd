extends Control


@onready var shape_option: OptionButton = $MapSettings/VBoxContainer/Filters/VBoxContainer/PositionContainer/VBoxContainer/ShapeOption

@onready var map_node: Node2D = $SubViewportContainer/SubViewport/Node2D


func _process(_delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	$SubViewportContainer/SubViewport.size = viewport_size - Vector2(0, 31)
	$ScrollContainer.size.x = viewport_size.x
	$ScrollContainer/PanelContainer.custom_minimum_size.x = viewport_size.x
	
	map_node.get_node("Camera2D").zoom = map_node.get_node("Camera2D").zoom.clamp(Vector2(0.5, 0.5), Vector2(20, 20))
	$"ZoomBox/+".disabled = map_node.get_node("Camera2D").zoom >= Vector2(20, 20)
	$"ZoomBox/-".disabled = map_node.get_node("Camera2D").zoom <= Vector2(0.5, 0.5)


func update_filter() -> void:
	var room_points = map_node.get_node("Points").get_children()
	var room_panels = map_node.get_node("Panels").get_children()
	var transition_lines = map_node.get_node("Lines").get_children()
	
	for i in room_points + transition_lines:
		i.show()
	
	var region_index: int = $MapSettings/VBoxContainer/Filters/VBoxContainer/AreaFilter.selected
	if region_index != 0:
		var region_text: String = $MapSettings/VBoxContainer/Filters/VBoxContainer/AreaFilter.get_item_text(region_index)
		for i: RoomPanel in room_panels:
			if region_text != i.region_name:
				i.point_node.hide()
		for i: TransitionLine in transition_lines:
			if not region_text in [get_node("/root/Main").get_room_panel(i.transition_panel.from).region_name, get_node("/root/Main").get_room_panel(i.transition_panel.to).region_name]:
				i.visible = false
	
	var selected_text: String = shape_option.get_item_text(shape_option.selected)
	var filter_logic: Callable = func(_c: Vector2i): return true
	match selected_text:
		"Shape...":
			pass
		"Circle":
			var radius: int = $MapSettings/VBoxContainer/Filters/VBoxContainer/PositionContainer/VBoxContainer/Circle/CircleRadius.value
			if radius > 0:
				filter_logic = func(c: Vector2i): return Geometry2D.is_point_in_circle(c, 
				$MapSettings/VBoxContainer/Filters/VBoxContainer/PositionContainer/VBoxContainer/Circle/CirclePosition.values,
				radius
				)
	if selected_text != "Shape...":
		for i in room_panels.filter(func(e): return not filter_logic.call(e.coords)):
			i.point_node.hide()
		for i in transition_lines.filter(
				func(e): return not (
					filter_logic.call(get_node("/root/Main").get_room_panel(e.transition_panel.from).coords) or filter_logic.call(get_node("/root/Main").get_room_panel(e.transition_panel.to).coords))):
			i.hide()
	


func _on_plus_pressed() -> void:
	map_node.get_node("Camera2D").zoom *= 1.1


func _on_minus_pressed() -> void:
	map_node.get_node("Camera2D").zoom /= 1.1


func _on_reset_pressed() -> void:
	map_node.get_node("Camera2D").zoom = Vector2.ONE


func _on_room_points_toggled(toggled_on: bool) -> void:
	map_node.get_node("Points").visible = toggled_on


func _on_transitions_toggled(toggled_on: bool) -> void:
	map_node.get_node("Lines").visible = toggled_on


func _on_map_image_toggled(toggled_on: bool) -> void:
	map_node.get_node("Textures").visible = toggled_on


func _on_area_filter_item_selected(_index: int) -> void:
	update_filter()


func _on_shape_option_item_selected(index: int) -> void:
	var selected_text: String = shape_option.get_item_text(index)
	var shape_boxes: Array[VBoxContainer]
	shape_boxes.assign(shape_option.get_parent().get_children().filter(func(e): return e is VBoxContainer))
	for i in shape_boxes:
		i.hide()
		if selected_text == str(i.name):
			i.show()
	map_node.get_node("Camera2D").draw_node.queue_redraw()
	update_filter()


func _on_circle_position_value_changed(_new_value: Vector2i) -> void:
	if map_node != null:
		map_node.get_node("Camera2D").draw_node.queue_redraw()
		update_filter()


func _on_circle_radius_value_changed(_value: float) -> void:
	if map_node != null:
		map_node.get_node("Camera2D").draw_node.queue_redraw()
		update_filter()
