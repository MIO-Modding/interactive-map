extends Control


const WHEEL_ROTATIONS = ["0", "120", "240"]

## where the map images need to be moved to in each rotation
const MAP_IMAGE_X_POSITIONS: Dictionary[String, Dictionary] = { 
	"0": {
		"Crucible": 1777.0,
		"Vaults": 304.813,
		"Lab": -1342.0,
	},
	"120": {
		"Crucible": 226.885,
		"Vaults": -1245.375,
		"Lab": 1766.035,
	},
	"240": {
		"Crucible": -1328.095,
		"Vaults": 1857.088,
		"Lab": 211.18,
	},
}

@onready var shape_option: OptionButton = $MapSettings/Foldable/VBoxContainer/Filters/VBoxContainer/PositionContainer/VBoxContainer/ShapeOption

@onready var map_node: Node2D = $SubViewportContainer/SubViewport/Node2D


func _ready() -> void:
	get_viewport().size_changed.connect(update_sizing)
	update_sizing()


func update_sizing() -> void:
	var viewport_size := get_viewport_rect().size
	$SubViewportContainer/SubViewport.size = viewport_size - Vector2(0, 31)
	$ScrollContainer.set_deferred("size", Vector2(viewport_size.x, $ScrollContainer.size.y))
	$ScrollContainer/PanelContainer.custom_minimum_size.x = viewport_size.x
	
	map_node.get_node("Camera2D").clamp_zoom()
	$"ZoomBox/+".disabled = map_node.get_node("Camera2D").zoom >= Vector2(20, 20)
	$"ZoomBox/-".disabled = map_node.get_node("Camera2D").zoom <= Vector2(0.5, 0.5)


func update_filter() -> void:
	var room_points = map_node.get_node("Points").get_children()
	var room_panels = map_node.get_node("Panels").get_children()
	var transition_lines = map_node.get_node("Lines").get_children()
	var location_points = map_node.get_node("LocPoints").get_children()
	var location_lines = map_node.get_node("LocLines").get_children()
	
	for i in room_points + transition_lines + location_points + location_lines:
		i.show()
	
	var region_index: int = $MapSettings/Foldable/VBoxContainer/Filters/VBoxContainer/AreaFilter.selected
	if region_index != 0:
		var region_text: String = $MapSettings/Foldable/VBoxContainer/Filters/VBoxContainer/AreaFilter.get_item_text(region_index)
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
			var radius: int = $MapSettings/Foldable/VBoxContainer/Filters/VBoxContainer/PositionContainer/VBoxContainer/Circle/CircleRadius.value
			if radius > 0:
				filter_logic = func(c: Vector2i): return Geometry2D.is_point_in_circle(c, 
				$MapSettings/Foldable/VBoxContainer/Filters/VBoxContainer/PositionContainer/VBoxContainer/Circle/CirclePosition.values,
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
	
	match $MapSettings/Foldable/VBoxContainer/Filters/VBoxContainer/LogicFilter.selected:
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
	
	match $MapSettings/Foldable/VBoxContainer/Filters/VBoxContainer/CheckedFilter.selected:
		0:
			pass
		1:
			for i in location_points:
				if not i.get_meta("panel").checked:
					hide_location_point(i)
		2:
			for i in location_points:
				if i.get_meta("panel").checked:
					hide_location_point(i)
	
	var loc_type_selected: String = $MapSettings/Foldable/VBoxContainer/Filters/VBoxContainer/TypeFilter.get_item_text($MapSettings/Foldable/VBoxContainer/Filters/VBoxContainer/TypeFilter.selected)
	if loc_type_selected != "Location Type...":
		for i in location_points:
			if i.get_meta("panel").type != loc_type_selected:
				hide_location_point(i)
	
	match $MapSettings/Foldable/VBoxContainer/Filters/VBoxContainer/ScoutableFilter.selected:
		0:
			pass
		1:
			for i in location_points:
				if not (i.get_meta("panel").serialize() in LocationPanel.SCOUTABLE_LOCS or i.get_meta("panel").loc_description.contains("Mel's Shop")):
					hide_location_point(i)
		2:
			for i in location_points:
				if i.get_meta("panel").serialize() in LocationPanel.SCOUTABLE_LOCS or i.get_meta("panel").loc_description.contains("Mel's Shop"):
					hide_location_point(i)
	
	if Archipelago.is_ap_connected():
		var hint_locs := Globals.main.get_hint_locs()
		match $MapSettings/Foldable/VBoxContainer/Filters/VBoxContainer/HintedFilter.selected:
			1:
				for i in location_points:
					if not hint_locs.has(i.get_meta("panel").serialize()):
						hide_location_point(i)
			2:
				for i in location_points:
					if hint_locs.has(i.get_meta("panel").serialize()):
						hide_location_point(i)


func hide_location_point(loc_point: Polygon2D) -> void:
	loc_point.hide()
	loc_point.get_meta("line").hide()


func update_maze(maze: String = "") -> void:
	if maze.is_empty():
		for maze_name in MazeVertex.all_mazes:
			update_maze(maze_name)
		return
	if not maze in MazeVertex.all_mazes: return
	var maze_parent: Node2D
	if MazeVertex.all_mazes[maze][0].background:
		maze_parent = $SubViewportContainer/SubViewport/Node2D/Mazes/TubesBack
	else:
		maze_parent = $SubViewportContainer/SubViewport/Node2D/Mazes/TubesFront
	if not maze_parent.has_node(maze):
		var new_node := Node2D.new()
		new_node.name = maze
		maze_parent.add_child(new_node)
	var maze_node: Node2D = maze_parent.get_node(maze)
	@warning_ignore("static_called_on_instance")
	Globals.free_all_children(maze_node)
	var ignore_first := true
	for vertex: MazeVertex in MazeVertex.all_mazes[maze]:
		if ignore_first:
			ignore_first = false
			continue
		if vertex.type == MazeVertex.VertexType.ENTRANCE: continue
		var segment_node := MazeVertex.MazeSegmentNode.new()
		segment_node.to_vertex = vertex
		maze_node.add_child(segment_node)


func _on_plus_pressed() -> void:
	map_node.get_node("Camera2D").zoom *= 1.1


func _on_minus_pressed() -> void:
	map_node.get_node("Camera2D").zoom /= 1.1


func _on_reset_pressed() -> void:
	map_node.get_node("Camera2D").zoom = Vector2.ONE


func _on_room_points_toggled(toggled_on: bool) -> void:
	map_node.get_node("LocLines").visible = toggled_on and $MapSettings/Foldable/VBoxContainer/Locations.button_pressed
	map_node.get_node("Points").visible = toggled_on


func _on_transitions_toggled(toggled_on: bool) -> void:
	map_node.get_node("Lines").visible = toggled_on


func _on_locations_toggled(toggled_on: bool) -> void:
	map_node.get_node("LocLines").visible = toggled_on and $MapSettings/Foldable/VBoxContainer/RoomPoints.button_pressed
	map_node.get_node("LocPoints").visible = toggled_on
	map_node.get_node("LocGroupLabels").visible = toggled_on


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


func _on_checked_filter_item_selected(_index: int) -> void:
	update_filter()


func _on_rotation_item_selected(index: int) -> void:
	var wheel_rotation: String = WHEEL_ROTATIONS[index]
	var positions = MAP_IMAGE_X_POSITIONS[wheel_rotation]
	for region in positions.keys():
		var map_image: Node2D = map_node.get_node("Textures").get_node(region)
		map_image.position.x = positions[region]
	map_node.get_node("Textures").get_node("Lab2").visible = wheel_rotation == "0"
	
	map_node.get_node("Skeleton/Bottom/Bottom1").position.x = map_node.get_node("Skeleton/Top").position.x - index * (1452 / 5.0)
	map_node.get_node("Skeleton/Bottom/Bottom2").position.x = map_node.get_node("Skeleton/Top").position.x + (3 - index) * (1452 / 5.0)
	map_node.get_node("Skeleton/Bottom/Bottom2").visible = wheel_rotation != "0"
	map_node.get_node("Colliders/Bottom/Bottom1").position.x = map_node.get_node("Skeleton/Bottom/Bottom1").position.x + 5.4
	map_node.get_node("Colliders/Bottom/Bottom2").position.x = map_node.get_node("Skeleton/Bottom/Bottom2").position.x + 5.4
	map_node.get_node("Colliders/Bottom/Bottom2").visible = map_node.get_node("Skeleton/Bottom/Bottom2").visible
	
	Globals.main.wheel_rotation = wheel_rotation


func _on_type_filter_item_selected(_index: int) -> void:
	update_filter()


func _on_map_image_type_item_selected(index: int) -> void:
	var list: Array[String] = ["Textures", "Skeleton", "Colliders"]
	for i in list:
		map_node.get_node(i).hide()
	if index > 0:
		map_node.get_node(list[index - 1]).show()


func _on_icon_style_item_selected(index: int) -> void:
	var icon_style = $MapSettings/Foldable/VBoxContainer/IconStyle.get_item_text(index)
	for loc_icon: LocationIcon in map_node.get_node("LocPoints").get_children():
		loc_icon.icon_style = icon_style


func _on_scoutable_filter_item_selected(_index: int) -> void:
	update_filter()


func _on_hinted_filter_item_selected(_index: int) -> void:
	update_filter()


func _on_map_icons_toggled(toggled_on: bool) -> void:
	map_node.get_node("Icons").visible = toggled_on


func _on_tubes_back_toggled(toggled_on: bool) -> void:
	map_node.get_node("Mazes/TubesBack").visible = toggled_on


func _on_tubes_front_toggled(toggled_on: bool) -> void:
	map_node.get_node("Mazes/TubesFront").visible = toggled_on
