class_name Main extends Control


enum LogicLevels {
	NONE,
	INTENDED_LOGIC,
	SIMPLE_SKIPS,
	ADVANCED_SKIPS,
}

const DATA_LINKS: Dictionary[String, String] = {
	"room requirements": "https://docs.google.com/spreadsheets/d/e/2PACX-1vQYd9mu0z_IXnGbZ0bUtAVHz3ZNRZymIfcYkz9HWXWNhd_ChxBTCdAVDcpHI3YMCtXrFNfkuvot1rbe/pub?gid=2144568902&single=true&output=csv",
	"items": "https://docs.google.com/spreadsheets/d/e/2PACX-1vQYd9mu0z_IXnGbZ0bUtAVHz3ZNRZymIfcYkz9HWXWNhd_ChxBTCdAVDcpHI3YMCtXrFNfkuvot1rbe/pub?gid=972951089&single=true&output=csv",
	"transition requirements": "https://docs.google.com/spreadsheets/d/e/2PACX-1vQYd9mu0z_IXnGbZ0bUtAVHz3ZNRZymIfcYkz9HWXWNhd_ChxBTCdAVDcpHI3YMCtXrFNfkuvot1rbe/pub?gid=1532215933&single=true&output=csv",
}

const KIND_MAXES: Dictionary[String, int] = {
	"room requirements": 12,
	"items": 8,
	"transition requirements": 8,
}

const MAP_WRAP_TRANSITIONS: Dictionary[String, String] = {
	"GA_vin_transi_P1": "LQ_vin_intro",
	"ST_tube_tech_F1_kassandra": "ST_pearl_halyn_P4",
	"ST_tube_tech_F1": "ST_pearl_halyn_P2"
}

var room_requirements_sheet: Array[Array]
var items_sheet: Array[Array]
var transition_requirements_sheet: Array[Array]

var highlight_rows_in_logic := true
var highlight_reachable_rows := true
var logic_kind: LogicLevels = LogicLevels.INTENDED_LOGIC

var player_state: PlayerState
signal update_itempool
signal update_transitions
var reachable_rooms: Array[String]
var simple_reachable_rooms: Array[String]
var advanced_reachable_rooms: Array[String]


func _ready() -> void:
	player_state = PlayerState.new()
	update_itempool.connect(func(): update_transitions.emit())
	update_itempool.connect(update_reachable)
	request_data()


func request_data():
	var requester := HTTPRequest.new()
	add_child(requester)
	
	requester.request_completed.connect(iterate_requests.bind(["room requirements", "items", "transition requirements"]), CONNECT_ONE_SHOT)
	requester.request(DATA_LINKS["room requirements"])
	print("Queued room requirements")


func iterate_requests(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, kinds: Array) -> void:
	on_finished_request(result, response_code, headers, body, kinds[0])
	kinds.remove_at(0)
	if kinds.is_empty():
		return
	get_child(-1).request_completed.connect(iterate_requests.bind(kinds), CONNECT_ONE_SHOT)
	get_child(-1).request(DATA_LINKS[kinds[0]])
	print("Queued " + kinds[0])


func on_finished_request(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray, kind: String = "") -> void:
	room_requirements_sheet = []
	print("Recieved " + kind)
	
	assert(KIND_MAXES.has(kind))
	fill_sheet(kind, body, KIND_MAXES[kind])
	
	match kind:
		"room requirements":
			room_requirements_sheet = room_requirements_sheet.filter(func(e): return not e[0].is_empty())
			var skip_first := true
			for row in room_requirements_sheet:
				for cell in row:
					var label = Label.new()
					label.text = cell
					$TabContainer/RoomRequirements/GridContainer.add_child(label)
				
				if not skip_first:
					var panel: RoomPanel = preload("res://Scenes/room_panel.tscn").instantiate()
					panel.region_name = row[0]
					panel.room_id = row[1]
					panel.connected_rooms.assign(", ".split(row[2]) as Array)
					if not row[3].is_empty():
						panel.logical_coords = str_to_var("Vector2i" + row[3])
					panel.logical_coords_description = row[4]
					panel.notes = row[5]
					if not row[11].is_empty():
						panel.coords = str_to_var("Vector2i" + row[11])
					update_transitions.connect(panel.update)
					panel.hide()
					
					$TabContainer/Map/SubViewportContainer/SubViewport/Node2D/Panels.add_child(panel)
					panel.update()
				
				skip_first = false
				
		"items":
			items_sheet = items_sheet.filter(func(e): return not e[0].is_empty())
			var skip_first := true
			for row in items_sheet:
				if not skip_first:
					var item: Item = preload("res://Scenes/item.tscn").instantiate()
					item.item_name = row[0]
					item.max_amount = row[1].to_int()
					item.room = row[2]
					item.type = Item.ItemTypes[row[4].to_upper()]
					item.classification = Item.ItemClassifications[row[5].to_upper()]
					item.save_entry = row[6]
					update_itempool.connect(item.update)
					
					%ItemPool.add_child(item)
					item.update()
				else:
					skip_first = false
				
				for cell in row:
					var label = Label.new()
					label.text = cell
					$TabContainer/Items/GridContainer.add_child(label)
		"transition requirements":
			transition_requirements_sheet = transition_requirements_sheet.filter(func(e): return not e[0].is_empty())
			var skip_first := true
			for row in transition_requirements_sheet:
				if skip_first:
					skip_first = false
					continue
				
				var panel: TransitionPanel = preload("res://Scenes/transition_panel.tscn").instantiate()
				panel.from = row[0]
				panel.to = row[1]
				panel.first_pass = row[2] == "TRUE"
				panel.intended_string = row[3]
				panel.simple_string = row[4]
				panel.advanced_string = row[5]
				panel.door = row[6]
				panel.notes = row[7]
				update_transitions.connect(panel.update)
				$TabContainer/TransitionRequirements/VBoxContainer.add_child(panel)
			
			for i in range(3):
				await get_tree().process_frame
			
			update_reachable()
			update_transitions.emit()
			for i in range(4):
				await get_tree().process_frame
			update_map()
			update_itempool.connect(update_map)


func fill_sheet(sheet_kind: String, body: PackedByteArray, cap: int = -1) -> void:
	for i in body.get_string_from_utf8().split("\r\n"):
		var current = row_to_list(i, cap)
		if not is_empty_string_list(current):
			get("%s_sheet" % sheet_kind.to_snake_case()).append(current)


func row_to_list(row: String, cap := -1) -> Array:
	var result: Array[String] = []
	
	var pending: String
	for i in row.split(","):
		if pending.is_empty():
			if i.count("\"") % 2 == 1:
				pending = i
				pending = pending.trim_prefix("\"")
			else:
				result.append(i)
				if result.size() >= cap and cap > 0:
					return result
		else:
			pending += "," + i
			if i.count("\"") % 2 == 1:
				pending = pending.trim_suffix("\"")
				result.append(pending)
				if result.size() >= cap and cap > 0:
					return result
				pending = ""
	return result


func update_reachable() -> void:
	logic_kind = LogicLevels.INTENDED_LOGIC
	reachable_rooms = get_reachable()
	logic_kind = LogicLevels.SIMPLE_SKIPS
	simple_reachable_rooms = get_reachable()
	logic_kind = LogicLevels.ADVANCED_SKIPS
	advanced_reachable_rooms = get_reachable()
	logic_kind = LogicLevels.INTENDED_LOGIC


func get_reachable() -> Array[String]:
	var result: Array[String] = []
	var current_room: String
	var available: Array[String] = ["ST_security_fall_P1"]
	
	while not available.is_empty():
		current_room = available[-1]
		result.append(current_room)
		available.remove_at(-1)
		available.append_array(get_room_connections(current_room).filter(func(e): return not result.has(e)))
	
	return result


func get_room_connections(room: String) -> Array[String]:
	var result: Array[String] = []
	for i: TransitionPanel in $TabContainer/TransitionRequirements/VBoxContainer.get_children():
		if i.from == room:
			if in_logic(i):
				if not result.has(i.to):
					result.append(i.to)
	return result


func get_higher_logic(logic1: LogicLevels, logic2: LogicLevels) -> LogicLevels:
	return maxi(logic1, logic2) as LogicLevels


func get_logic(panel: TransitionPanel) -> LogicLevels:
	if panel.intended_logic.call():
		return LogicLevels.INTENDED_LOGIC
	
	if panel.simple_string != "-":
		if panel.simple_logic.call():
			return LogicLevels.SIMPLE_SKIPS
		if panel.advanced_logic.call():
			return LogicLevels.ADVANCED_SKIPS
	
	return LogicLevels.NONE


func in_logic(panel: TransitionPanel, override_logic_kind := LogicLevels.NONE) -> bool:
	if panel.door == "Wrong Side":
		return false
	
	if panel.intended_logic.call():
		return true
	
	if override_logic_kind == LogicLevels.NONE:
		override_logic_kind = logic_kind
	
	if panel.simple_string != "-":
		if override_logic_kind != LogicLevels.INTENDED_LOGIC:
			if panel.simple_logic.call():
				return true
	
	if panel.advanced_string != "-":
		if override_logic_kind == LogicLevels.ADVANCED_SKIPS:
			if panel.advanced_logic.call():
				return true
	
	return false


func is_empty_string_list(string_list: Array[String]) -> bool:
	return "".join(string_list).is_empty()


func update_map() -> void:
	await get_tree().process_frame
	
	for i in ($TabContainer/Map/SubViewportContainer/SubViewport/Node2D/Lines.get_children() +
			$TabContainer/Map/SubViewportContainer/SubViewport/Node2D/Points.get_children()):
		i.queue_free()
	
	var all_regions: Array[String]
	
	for room: RoomPanel in $TabContainer/Map/SubViewportContainer/SubViewport/Node2D/Panels.get_children():
		if not room.region_name in all_regions:
			all_regions.append(room.region_name)
			$TabContainer/Map/MapSettings/VBoxContainer/Filters/VBoxContainer/AreaFilter.add_item(room.region_name)
		
		var point := Polygon2D.new()
		point.polygon = [Vector2(1,0), Vector2(0,1), Vector2(-1,0), Vector2(0,-1)]
		point.self_modulate = Color(0, 0, 0)
		if highlight_reachable_rows:
			if reachable_rooms.has(room.room_id):
				point.self_modulate = TransitionPanel.LOGIC_LEVEL_COLORS["intended"]
			elif simple_reachable_rooms.has(room.room_id):
				point.self_modulate = TransitionPanel.LOGIC_LEVEL_COLORS["simple"]
			elif advanced_reachable_rooms.has(room.room_id):
				point.self_modulate = TransitionPanel.LOGIC_LEVEL_COLORS["advanced"]
		point.name = room.room_id
		point.set_meta("id", room.room_id)
		point.position = Vector2(room.coords) / 5 * Vector2(1, -1)
		room.point_node = point
		$TabContainer/Map/SubViewportContainer/SubViewport/Node2D/Points.add_child(point)
	
	for transition: TransitionPanel in $TabContainer/TransitionRequirements/VBoxContainer.get_children():
		var line: TransitionLine = preload("res://Scenes/transition_line.tscn").instantiate()
		line.name = transition.from + " -> " + transition.to
		line.default_color = Color(0.7, 0.7, 0.7)
		if highlight_reachable_rows:
			line.default_color = transition.modulate
			line.default_color.v -= 0.5
			if is_equal_approx(line.default_color.s, 0):
				line.z_index = 0
			else:
				line.z_index = 3 - transition.LOGIC_LEVEL_COLORS.values().find(transition.modulate)
		line.transition_panel = transition
		line.add_point($TabContainer/Map/SubViewportContainer/SubViewport/Node2D/Points.get_node(transition.from).position)
		if MAP_WRAP_TRANSITIONS.keys().has(transition.from) and MAP_WRAP_TRANSITIONS.values().has(transition.to):
			line.add_point(line.points[0] + Vector2(200, 0))
		elif MAP_WRAP_TRANSITIONS.values().has(transition.from) and MAP_WRAP_TRANSITIONS.keys().has(transition.to):
			line.add_point(line.points[0] + Vector2(-200, 0))
		else:
			line.add_point($TabContainer/Map/SubViewportContainer/SubViewport/Node2D/Points.get_node(transition.to).position)
		line.width = 1
		if line.points.has(Vector2(0, 0)):
			continue
		$TabContainer/Map/SubViewportContainer/SubViewport/Node2D/Lines.add_child(line)


func line_clicked(line: TransitionLine) -> void:
	for i in $TabContainer/Map/ScrollContainer/PanelContainer/VBoxContainer.get_children():
		i.queue_free()
	
	$TabContainer/Map/ScrollContainer/PanelContainer/VBoxContainer.add_child(line.transition_panel.duplicate())
	var second_panel := get_transition_panel(line.transition_panel.from, line.transition_panel.to)
	if second_panel != null:
		$TabContainer/Map/ScrollContainer/PanelContainer/VBoxContainer.add_child(second_panel.duplicate())


func point_clicked(point: Polygon2D) -> void:
	if not point.has_meta("id"):
		return
	for i in $TabContainer/Map/ScrollContainer/PanelContainer/VBoxContainer.get_children():
		i.queue_free()
	
	for panel: RoomPanel in $TabContainer/Map/SubViewportContainer/SubViewport/Node2D/Panels.get_children():
		if panel.room_id == point.get_meta("id", ""):
			var duplicate_panel = panel.duplicate()
			duplicate_panel.show()
			$TabContainer/Map/ScrollContainer/PanelContainer/VBoxContainer.add_child(duplicate_panel)
			break


func get_transition_panel(to: String, from: String) -> TransitionPanel:
	for i: TransitionPanel in $TabContainer/TransitionRequirements/VBoxContainer.get_children():
		if i.to == to and i.from == from:
			return i
	return null


func get_room_panel(id: String) -> RoomPanel:
	for i: RoomPanel in $TabContainer/Map/SubViewportContainer/SubViewport/Node2D.get_node("Panels").get_children():
		if i.room_id == id:
			return i
	return null


func _on_highlight_toggle_toggled(toggled_on: bool) -> void:
	highlight_rows_in_logic = toggled_on
	update_transitions.emit()


func _on_highlight_reachable_toggled(toggled_on: bool) -> void:
	highlight_reachable_rows = toggled_on
	update_transitions.emit()

func _on_clear_button_pressed() -> void:
	player_state.prog_items.clear()
	update_itempool.emit()


func _on_all_button_pressed() -> void:
	for item: Item in %ItemPool.get_children():
		for i in range(item.max_amount):
			player_state.prog_items.append(item.item_name)
	update_itempool.emit()


func _on_give_starting_button_pressed() -> void:
	for i in ["Slash", "Modifier - Self-Awareness"]:
		if not player_state.prog_items.has(i):
			player_state.prog_items.append(i)
	update_itempool.emit()


class PlayerState:
	var prog_items: Array[String] = []
	
	
	func and_call(calls: Array[Callable]) -> Callable:
		return (func() -> bool:
			for i in calls:
				if not i.call():
					return false
			return true)
	
	
	func or_call(calls: Array[Callable]) -> Callable:
		return (func() -> bool:
			for i in calls:
				if i.call():
					return true
			return false)
	
	
	func has_call(item: String) -> Callable:
		return (func() -> bool:
			if item == "False":
				return false
			elif item == "True":
				return true
			return prog_items.has(item))
