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
	var location_points = map_node.get_node("LocPoints").get_children()
	
	for i in room_points + transition_lines + location_points + map_node.get_node("LocLines").get_children():
		i.show()
	
	var region_index: int = $MapSettings/VBoxContainer/Filters/VBoxContainer/AreaFilter.selected
	if region_index != 0:
		var region_text: String = $MapSettings/VBoxContainer/Filters/VBoxContainer/AreaFilter.get_item_text(region_index)
		for i: RoomPanel in room_panels:
			if region_text != i.region_name:
				i.point_node.hide()
		for i: TransitionLine in transition_lines:
			if not region_text in [$/root/Main.get_room_panel(i.transition_panel.from).region_name, $/root/Main.get_room_panel(i.transition_panel.to).region_name]:
				i.visible = false
		for i: Polygon2D in location_points:
			if region_text != i.get_meta("panel").region_name:
				hide_location_point(i) 
	
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
					filter_logic.call($/root/Main.get_room_panel(e.transition_panel.from).coords) or filter_logic.call($/root/Main.get_room_panel(e.transition_panel.to).coords))):
			i.hide()
		for i in location_points.filter(func(e): return not filter_logic.call(e.get_meta("panel").coords)):
			hide_location_point(i)
	
	match $MapSettings/VBoxContainer/Filters/VBoxContainer/LogicFilter.selected:
		0:
			pass
		1: # int
			for i in room_panels:
				if not i.room_id in $/root/Main.reachable_rooms:
					i.point_node.hide()
			for i: TransitionLine in transition_lines:
				if TransitionPanel.LOGIC_LEVEL_COLORS.values().has(i.transition_panel.modulate):
					if TransitionPanel.LOGIC_LEVEL_COLORS.find_key(i.transition_panel.modulate) != "intended":
						i.hide()
				else:
					i.hide()
			for i in location_points:
				if TransitionPanel.LOGIC_LEVEL_COLORS.values().has(i.get_meta("panel").modulate):
					if TransitionPanel.LOGIC_LEVEL_COLORS.find_key(i.get_meta("panel").modulate) != "intended":
						hide_location_point(i)
				else:
					hide_location_point(i)
		2: # sim
			for i in room_panels:
				if not i.room_id in $/root/Main.simple_reachable_rooms:
					i.point_node.hide()
			for i: TransitionLine in transition_lines:
				if TransitionPanel.LOGIC_LEVEL_COLORS.values().has(i.transition_panel.modulate):
					if not TransitionPanel.LOGIC_LEVEL_COLORS.find_key(i.transition_panel.modulate) in ["intended", "simple"]:
						i.hide()
				else:
					i.hide()
			for i in location_points:
				if TransitionPanel.LOGIC_LEVEL_COLORS.values().has(i.get_meta("panel").modulate):
					if TransitionPanel.LOGIC_LEVEL_COLORS.find_key(i.get_meta("panel").modulate) in ["intended", "simple"]:
						hide_location_point(i)
				else:
					print(i.get_meta("panel").modulate)
					hide_location_point(i)
		3: # adv
			for i in room_panels:
				if not i.room_id in $/root/Main.advanced_reachable_rooms:
					i.point_node.hide()
			for i: TransitionLine in transition_lines:
				if TransitionPanel.LOGIC_LEVEL_COLORS.values().has(i.transition_panel.modulate):
					if not TransitionPanel.LOGIC_LEVEL_COLORS.find_key(i.transition_panel.modulate) in ["intended", "simple", "advanced"]:
						i.hide()
				else:
					i.hide()
			for i in location_points:
				if TransitionPanel.LOGIC_LEVEL_COLORS.values().has(i.get_meta("panel").modulate):
					if TransitionPanel.LOGIC_LEVEL_COLORS.find_key(i.get_meta("panel").modulate) in ["intended", "simple", "advanced"]:
						hide_location_point(i)
				else:
					hide_location_point(i)


func hide_location_point(loc_point: Polygon2D) -> void:
	loc_point.hide()
	loc_point.get_meta("line").hide()


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


func _on_locations_toggled(toggled_on: bool) -> void:
	map_node.get_node("LocLines").visible = toggled_on
	map_node.get_node("LocPoints").visible = toggled_on


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


func _on_logic_filter_item_selected(_index: int) -> void:
	update_filter()
