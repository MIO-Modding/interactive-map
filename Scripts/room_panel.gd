class_name RoomPanel extends PanelContainer


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


func update() -> void:
	var main: Main = get_node("/root/Main")
	if main.highlight_reachable_rows:
		if main.reachable_rooms.has(room_id):
			modulate = TransitionPanel.LOGIC_LEVEL_COLORS.intended
		elif main.simple_reachable_rooms.has(room_id):
			modulate = TransitionPanel.LOGIC_LEVEL_COLORS.simple
		elif main.advanced_reachable_rooms.has(room_id):
			modulate = TransitionPanel.LOGIC_LEVEL_COLORS.advanced
		else:
			modulate = Color.WHITE
