class_name RoomPanel extends FeaturePanel


var region_name: String:
	set(v):
		region_name = v
		$HBoxContainer/Region.text = v
var room_id: String:
	set(v):
		room_id = v
		$HBoxContainer/ID.text = v
var connected_rooms: Array[String]:
	set(v):
		connected_rooms.assign(v)
		for i in $HBoxContainer/Connected/VBoxContainer.get_children():
			i.queue_free()
		for i in v:
			var label := Label.new()
			label.text = i
			$HBoxContainer/Connected/VBoxContainer.add_child(label)
var logical_coords: Vector2i:
	set(v):
		logical_coords = v
		$HBoxContainer/LogicalCoords.text = str(v)
var logical_coords_description: String:
	set(v):
		logical_coords_description = v
		$HBoxContainer/LogicalCoordsNotes.text = v
var notes: String:
	set(v):
		notes = v
		$HBoxContainer/Notes.text = v
var coords: Vector2i:
	set(v):
		coords = v
		$HBoxContainer/Coords.text = str(v)

var point_node: Polygon2D

var astar_id: int


const BASE_WIKITEXT: String = """
# Room: %s (%s)

### Connected Rooms
- %s

### Coordinates
Position: %s
Logical Center: %s

### Notes
%s
"""


func _init() -> void:
	await tree_entered
	for i in get_child(0).get_children():
		if i is Label:
			i.add_theme_color_override("font_color", Color.WHITE)


func update() -> void:
	var main: Main = $/root/Main
	if main.highlight_reachable_rows:
		if main.reachable_rooms.has(room_id):
			modulate = TransitionPanel.LOGIC_LEVEL_COLORS.intended
		elif main.simple_reachable_rooms.has(room_id):
			modulate = TransitionPanel.LOGIC_LEVEL_COLORS.simple
		elif main.advanced_reachable_rooms.has(room_id):
			modulate = TransitionPanel.LOGIC_LEVEL_COLORS.advanced
		else:
			modulate = Color.WHITE


func get_wikitext() -> String:
	return BASE_WIKITEXT % [
		Globals.fix_underscores(room_id), 
		region_name, 
		get_connected_markdown(), 
		str(coords), 
		("%s (%s)" % [str(logical_coords), logical_coords_description]) if logical_coords != Vector2i.ZERO else "N/A",
		Globals.fix_underscores(notes),
	]


func get_pagename() -> String:
	return room_id


func get_connected_markdown() -> String:
	return "\n- ".join(connected_rooms.map(Globals.fix_underscores))


func highlight_path() -> void:
	if room_id.is_empty():
		return
	var path_string: String
	var path: Array[String]
	var timer := get_tree().create_timer(5)
	path.assign(Array(Globals.main.astar_web.get_id_path(Globals.main.room_order.find(Globals.main.starting_room), Globals.main.room_order.find(room_id))).map(func(e): return Globals.main.room_order[e]))
	path_string = "->".join(path)
	for i: TransitionPanel in Globals.main.get_node("TabContainer/TransitionRequirements/VBoxContainer").get_children():
		if (i.from + "->" + i.to) in path_string or (i.to + "->" + i.from) in path_string:
			i.transition_line.highlight(Color.HOT_PINK, timer)


func _on_link_pressed() -> void:
	Globals.main.get_node("TabContainer/Info").add_page(Globals.main.get_room_panel($HBoxContainer/ID.text))
