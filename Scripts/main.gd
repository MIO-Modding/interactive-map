class_name Main extends Control


enum LogicLevels {
	NONE,
	INTENDED_LOGIC,
	SIMPLE_SKIPS,
	ADVANCED_SKIPS,
}

const LEVEL_COLORS: Dictionary[LogicLevels, Color] = {
	LogicLevels.NONE: Color.WHITE,
	LogicLevels.INTENDED_LOGIC: Color.GREEN,
	LogicLevels.SIMPLE_SKIPS: Color.YELLOW,
	LogicLevels.ADVANCED_SKIPS: Color(1.0, 0.5, 0.0),
}

const DATA_LINKS: Dictionary[String, String] = {
	"room requirements": "https://docs.google.com/spreadsheets/d/e/2PACX-1vQYd9mu0z_IXnGbZ0bUtAVHz3ZNRZymIfcYkz9HWXWNhd_ChxBTCdAVDcpHI3YMCtXrFNfkuvot1rbe/pub?gid=2144568902&single=true&output=csv",
	"items": "https://docs.google.com/spreadsheets/d/e/2PACX-1vQYd9mu0z_IXnGbZ0bUtAVHz3ZNRZymIfcYkz9HWXWNhd_ChxBTCdAVDcpHI3YMCtXrFNfkuvot1rbe/pub?gid=972951089&single=true&output=csv",
	"transition requirements": "https://docs.google.com/spreadsheets/d/e/2PACX-1vQYd9mu0z_IXnGbZ0bUtAVHz3ZNRZymIfcYkz9HWXWNhd_ChxBTCdAVDcpHI3YMCtXrFNfkuvot1rbe/pub?gid=1532215933&single=true&output=csv",
	"location requirements": "https://docs.google.com/spreadsheets/d/e/2PACX-1vQYd9mu0z_IXnGbZ0bUtAVHz3ZNRZymIfcYkz9HWXWNhd_ChxBTCdAVDcpHI3YMCtXrFNfkuvot1rbe/pub?gid=0&single=true&output=csv",
}

const KIND_MAXES: Dictionary[String, int] = {
	"room requirements": 12,
	"items": 8,
	"transition requirements": 8,
	"location requirements": 13,
}

const MAP_WRAP_TRANSITIONS = {
	"0": {
		"GA_vin_transi_P1": "LQ_vin_intro",
		"ST_tube_tech_F1_kassandra": "ST_pearl_halyn_P4",
		"ST_tube_tech_F1": "ST_pearl_halyn_P2",
	},
	"120": {
		"GA_vin_transi_P1": "LQ_vin_intro",
		"ST_tube_vanilla_S1": "ST_tube_vanilla_C3",
		"ST_pearl_halyn_P5": "ST_tube_vanilla_C2",
	},
	"240": {
		"GA_vin_transi_P1": "LQ_vin_intro",
		"ST_cuves_goo_P7": "ST_cuves_goo_P8",
		"ST_cuves_goo_P2": "ST_cuves_goo_P1",
		"ST_tube_chase_P3": "ST_tube_chase_C2",
		"ST_pearl_conex_P1": "ST_pearl_lab_P0",
	},
}

## X-coordinate ranges for reegions of the lower part of the map around each shuttle
const SHUTTLE_REGIONS := { 
	"Lab": [-3600, -2500],
	"Vaults": [-2500, -650],
	"Crucible": [-650, 650],
}

## How much the x-coordinates of points in each region need to be offset by in each wheel rotation
const ROTATION_OFFSETS := { 
	"0": {
		"Lab": 0,
		"Vaults": 0,
		"Crucible": 0,
	},
	"120": {
		"Lab": 2904,
		"Vaults": -1452,
		"Crucible": -1452,
	},
	"240": {
		"Lab": 1452,
		"Vaults": 1452,
		"Crucible": -2904,
	},
}

var room_requirements_sheet: Array[Array]
var items_sheet: Array[Array]
var transition_requirements_sheet: Array[Array]
var location_requirements_sheet: Array[Array]

var highlight_rows_in_logic := true
var highlight_reachable_rows := true
var logic_kind: LogicLevels = LogicLevels.INTENDED_LOGIC

static var player_state: PlayerState
signal update_itempool
signal update_transitions
signal finished_requesting
signal rotation_changed
var reachable_rooms: Array[String]
var simple_reachable_rooms: Array[String]
var advanced_reachable_rooms: Array[String]

var starting_room := "ST_security_fall_P1"
var double_click_checks_locations := true
var persistant_items := true
var show_item_flags := false

var reachable_locations: Array[LocationPanel]
var simple_reachable_locations: Array[LocationPanel]
var advanced_reachable_locations: Array[LocationPanel]
var go_mode := false

var window_theme := Theme.new()

var wheel_rotation := "0":
	set(v):
		wheel_rotation = v
		rotation_changed.emit()


func _ready() -> void:
	player_state = PlayerState.new()
	player_state.main = self
	update_itempool.connect(func(): update_transitions.emit())
	update_itempool.connect(update_reachable)
	rotation_changed.connect(update_map)
	update_transitions.connect(update_go_mode)
	
	var client = preload("res://godot_ap/ui/common_client.tscn").instantiate()
	Archipelago.load_console(client, false)
	get_window().theme = window_theme
	get_window().theme_changed.connect(func(): if get_window().theme != window_theme: get_window().theme = window_theme)
	$TabContainer/ArchipelagoClient.add_child(client)
	
	request_data()


func request_data():
	var requester := HTTPRequest.new()
	add_child(requester)
	
	requester.request_completed.connect(iterate_requests.bind(["room requirements", "items", "transition requirements", "location requirements"]), CONNECT_ONE_SHOT)
	requester.request(DATA_LINKS["room requirements"])
	Globals.trigger_popup("Queued room requirements")


func iterate_requests(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, kinds: Array) -> void:
	on_finished_request(result, response_code, headers, body, kinds[0])
	kinds.remove_at(0)
	if kinds.is_empty():
		finished_requesting.emit()
		return
	get_child(-1).request_completed.connect(iterate_requests.bind(kinds), CONNECT_ONE_SHOT)
	get_child(-1).request(DATA_LINKS[kinds[0]])
	Globals.trigger_popup("Queued " + kinds[0])


func on_finished_request(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray, kind: String = "") -> void:
	room_requirements_sheet = []
	Globals.trigger_popup("Recieved " + kind)
	
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
					panel.connected_rooms.assign(row[2].split(", ") as Array)
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
					
					if row[1] != "ST_security_fall_P1":
						$TabContainer/PlayerState/ControlPanel/VBoxContainer/HBoxContainer/StartingLocation.add_item(row[1])
				
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
		"location requirements":
			location_requirements_sheet = location_requirements_sheet.filter(func(e): return not e[0].is_empty())
			var skip_first := true
			for row in location_requirements_sheet:
				if skip_first:
					skip_first = false
					continue
				
				var panel: LocationPanel = preload("res://Scenes/location_panel.tscn").instantiate()
				panel.region_name = row[0]
				panel.room_id = row[1]
				panel.loc_description = row[2]
				if row[3] == "N/A":
					panel.coords = Vector2i.ZERO
				else:
					panel.coords = str_to_var("Vector2i" + row[3])
				panel.vanilla_item = row[4]
				panel.save_flag = row[5]
				panel.intended_string = row[6]
				panel.simple_string = row[7]
				panel.advanced_string = row[8]
				panel.notes = row[9]
				panel.type = row[12]
				update_transitions.connect(panel.update)
				$TabContainer/LocationRequirements/VBoxContainer.add_child(panel)
			
			update_reachable()
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
	reachable_locations = get_reachable_locations(reachable_rooms)
	logic_kind = LogicLevels.SIMPLE_SKIPS
	simple_reachable_rooms = get_reachable()
	simple_reachable_locations = get_reachable_locations(simple_reachable_rooms)
	logic_kind = LogicLevels.ADVANCED_SKIPS
	advanced_reachable_rooms = get_reachable()
	advanced_reachable_locations = get_reachable_locations(advanced_reachable_rooms)
	logic_kind = LogicLevels.INTENDED_LOGIC


func get_reachable_locations(availible_rooms: Array[String]) -> Array[LocationPanel]:
	var result: Array[LocationPanel] = []
	
	for room in availible_rooms:
		for loc: LocationPanel in get_locations_for_room(room):
			if loc_in_logic(loc):
				result.append(loc)
	
	return result


func get_locations_for_room(room_id: String) -> Array[LocationPanel]:
	var result: Array[LocationPanel] = []
	for i: LocationPanel in $TabContainer/LocationRequirements/VBoxContainer.get_children():
		if i.room_id == room_id:
			result.append(i)
	return result


func get_reachable() -> Array[String]:
	var result: Array[String] = []
	var current_room: String
	var available: Array[String] = [starting_room]
	
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


func loc_in_logic(loc_panel: LocationPanel, override_logic_kind := LogicLevels.NONE) -> bool:
	if loc_panel.intended_logic.call():
		return true
	
	if override_logic_kind == LogicLevels.NONE:
		override_logic_kind = logic_kind
	
	if loc_panel.simple_string != "-":
		if override_logic_kind != LogicLevels.INTENDED_LOGIC:
			if loc_panel.simple_logic.call():
				return true
	
	if loc_panel.advanced_string != "-":
		if override_logic_kind == LogicLevels.ADVANCED_SKIPS:
			if loc_panel.advanced_logic.call():
				return true
	
	return false


func is_empty_string_list(string_list: Array[String]) -> bool:
	return "".join(string_list).is_empty()


## Get the position a point should be drawn on the map in different wheel rotations
func get_rotated_position(start_point: Vector2i) -> Vector2i:
	if start_point.y > 1000: # Don't change anything in the top part of the vessel
		return start_point
	if wheel_rotation == "0": # Don't change anything in rotation 0
		return start_point
	
	var point_region := ""
	for region in SHUTTLE_REGIONS: # find which region in the lower part of the ship the point is in
		if SHUTTLE_REGIONS[region][0] < start_point.x and start_point.x < SHUTTLE_REGIONS[region][1]:
			point_region = region
	start_point.x += ROTATION_OFFSETS[wheel_rotation][point_region] #adjust the x coordinate based on which region it's in
	return start_point


func update_map() -> void:
	await get_tree().process_frame
	var map_node: Node2D = $TabContainer/Map/SubViewportContainer/SubViewport/Node2D
	
	for i in ["Points", "Lines", "LocPoints", "LocLines"].map(func(e): return map_node.get_node(e).get_children()):
		for node in i:
			node.queue_free()

	await get_tree().process_frame
	
	var all_regions: Array[String]
	for i in range($TabContainer/Map/MapSettings/VBoxContainer/Filters/VBoxContainer/AreaFilter.item_count):
		if i == 0:
			continue
		all_regions.append($TabContainer/Map/MapSettings/VBoxContainer/Filters/VBoxContainer/AreaFilter.get_item_text(i))
	var all_location_types: Array[String]
	for i in range($TabContainer/Map/MapSettings/VBoxContainer/Filters/VBoxContainer/TypeFilter.item_count):
		if i == 0:
			continue
		all_location_types.append($TabContainer/Map/MapSettings/VBoxContainer/Filters/VBoxContainer/TypeFilter.get_item_text(i))
	
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
		point.position = Vector2(get_rotated_position(room.coords)) / 5 * Vector2(1, -1)
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
		var wrap_transitions = MAP_WRAP_TRANSITIONS[wheel_rotation]
		if wrap_transitions.keys().has(transition.from) and wrap_transitions.values().has(transition.to):
			line.add_point(line.points[0] + Vector2(200, 0))
		elif wrap_transitions.values().has(transition.from) and wrap_transitions.keys().has(transition.to):
			line.add_point(line.points[0] + Vector2(-200, 0))
		else:
			line.add_point($TabContainer/Map/SubViewportContainer/SubViewport/Node2D/Points.get_node(transition.to).position)
		line.width = 1 / ceilf(map_node.get_node("Camera2D").zoom.x / 10)
		if line.points.has(Vector2(0, 0)):
			continue
		$TabContainer/Map/SubViewportContainer/SubViewport/Node2D/Lines.add_child(line)
	
	var taken_positions: Array[Vector2i]
	for loc_panel: LocationPanel in $TabContainer/LocationRequirements/VBoxContainer.get_children():
		var room_panel: RoomPanel = get_room_panel(loc_panel.room_id)
		
		if not all_location_types.has(loc_panel.type):
			all_location_types.append(loc_panel.type)
			$TabContainer/Map/MapSettings/VBoxContainer/Filters/VBoxContainer/TypeFilter.add_item(loc_panel.type)
		
		var point := Polygon2D.new()
		point.set_meta("panel", loc_panel)
		point.polygon = [Vector2(1,0), Vector2(0,1), Vector2(-1,0), Vector2(0,-1)].map(func(e): return e / 2)
		point.self_modulate = Color.WHITE
		if highlight_reachable_rows:
			if reachable_locations.has(loc_panel):
				point.self_modulate = TransitionPanel.LOGIC_LEVEL_COLORS["intended"]
			elif simple_reachable_locations.has(loc_panel):
				point.self_modulate = TransitionPanel.LOGIC_LEVEL_COLORS["simple"]
			elif advanced_reachable_locations.has(loc_panel):
				point.self_modulate = TransitionPanel.LOGIC_LEVEL_COLORS["advanced"]
		loc_panel.modulate = point.self_modulate
		point.name = loc_panel.room_id + ": " + loc_panel.loc_description
		if loc_panel.room_id == "ST_security_secret_S1":
			point.position = room_panel.point_node.position
			point.position += Vector2(-30, 10)
		else:
			var temp_point: Vector2i = get_rotated_position(loc_panel.coords)
			if (Vector2(temp_point) / 5 * Vector2(1, -1)).distance_to(room_panel.point_node.position) <= 0.7:
				temp_point += Vector2i(10, 10)
			
			var iterations: int = 0
			while taken_positions.has(temp_point):
				iterations += 1
				temp_point.x -= 5
				if iterations % 5 == 0:
					temp_point.y -= 5
					temp_point.x += 25
			taken_positions.append(temp_point)
			
			point.position = Vector2(temp_point) / 5 * Vector2(1, -1)
		
		loc_panel.point_node = point
		$TabContainer/Map/SubViewportContainer/SubViewport/Node2D/LocPoints.add_child(point)
		
		var line: LocationLine = preload("res://Scenes/location_line.tscn").instantiate()
		line.loc_panel = loc_panel
		line.default_color = point.self_modulate
		line.default_color.v -= 0.5
		line.width = 1 / ceilf(map_node.get_node("Camera2D").zoom.x / 10)
		if loc_panel.room_id == "N/A":
			line.add_point(Vector2(100, 100))
		elif wheel_rotation == "120" and loc_panel.room_id == "ST_tube_vanilla_S1" and loc_panel.save_flag == "SHIELD_FRAGMENT:15":
			# workaround so this location doesn't draw a line across the map in rotatioon 120
			line.add_point(get_room_panel("ST_tube_vanilla_C3").point_node.position)
		else:
			line.add_point(room_panel.point_node.position)
		line.add_point(point.position)
		$TabContainer/Map/SubViewportContainer/SubViewport/Node2D/LocLines.add_child(line)
		loc_panel.update()
		
		point.set_meta("line", line)
		if is_location_event(loc_panel):
			point.self_modulate = Color.REBECCA_PURPLE
	
	$TabContainer/Map.update_filter()


func is_location_event(loc_panel: LocationPanel) -> bool:
	for i: Item in %ItemPool.get_children():
		if i.item_name == loc_panel.vanilla_item or (i.save_entry == loc_panel.save_flag and loc_panel.save_flag != ""):
			return i.type == Item.ItemTypes.EVENT
	return false


func get_item_at_location(loc_panel: LocationPanel) -> Item:
	var converted_vanilla: String = loc_panel.vanilla_item
	if converted_vanilla.contains("Crystallised Nacre - "):
		converted_vanilla = "Crystallized Nacre"
	for i: Item in %ItemPool.get_children():
		if i.item_name == converted_vanilla or (i.save_entry == loc_panel.save_flag and loc_panel.save_flag != ""):
			return i
	return null


func get_event_location(item: Item) -> LocationPanel:
	for i: LocationPanel in $TabContainer/LocationRequirements/VBoxContainer.get_children():
		if i.vanilla_item == item.item_name or (item.save_entry == i.save_flag and i.save_flag != ""):
			return i
	return null


func line_clicked(line: TransitionLine) -> void:
	for i in $TabContainer/Map/ScrollContainer/PanelContainer/VBoxContainer.get_children():
		i.queue_free()
	
	$TabContainer/Map/ScrollContainer/PanelContainer/VBoxContainer.add_child(line.transition_panel.duplicate())
	var second_panel := get_transition_panel(line.transition_panel.from, line.transition_panel.to)
	if second_panel != null:
		$TabContainer/Map/ScrollContainer/PanelContainer/VBoxContainer.add_child(second_panel.duplicate())


func point_clicked(point: Polygon2D, double_click := false) -> void:
	for i in $TabContainer/Map/ScrollContainer/PanelContainer/VBoxContainer.get_children():
		i.queue_free()
	
	if point.has_meta("panel"):
		var panel: LocationPanel = point.get_meta("panel")
		if double_click and double_click_checks_locations:
			panel.checked = not panel.checked
		var duplicate_panel = panel.duplicate()
		duplicate_panel.room_id = panel.room_id
		duplicate_panel.loc_description = panel.loc_description
		duplicate_panel.original_color = panel.modulate
		
		$TabContainer/Map/ScrollContainer/PanelContainer/VBoxContainer.add_child(duplicate_panel)
		return
	
	if not point.has_meta("id"):
		return
	
	for panel: RoomPanel in $TabContainer/Map/SubViewportContainer/SubViewport/Node2D/Panels.get_children():
		if panel.room_id == point.get_meta("id", ""):
			var duplicate_panel = panel.duplicate()
			duplicate_panel.show()
			$TabContainer/Map/ScrollContainer/PanelContainer/VBoxContainer.add_child(duplicate_panel)
			break


func update_go_mode() -> void:
	var event: String
	event = $TabContainer/Map/MapSettings/VBoxContainer/GoalOption.get_item_text($TabContainer/Map/MapSettings/VBoxContainer/GoalOption.selected)
	var panel: LocationPanel = get_event_location(get_item_node(event))
	if player_state.ap_prog_items.has(event):
		Archipelago.set_client_status(AP.ClientStatus.CLIENT_GOAL)
	
	var level: LogicLevels
	if reachable_locations.has(panel):
		level = LogicLevels.INTENDED_LOGIC
	elif simple_reachable_locations.has(panel):
		level = LogicLevels.SIMPLE_SKIPS
	elif advanced_reachable_locations.has(panel):
		level = LogicLevels.ADVANCED_SKIPS
	else:
		level = LogicLevels.NONE
	
	if level == LogicLevels.NONE:
		go_mode = false
		$TabContainer/Map/MapSettings/VBoxContainer/GoModeLabel.text = "NO GO MODE"
		$TabContainer/Map/MapSettings/VBoxContainer/GoModeLabel.label_settings.font_color = Color.RED
	else:
		go_mode = true
		$TabContainer/Map/MapSettings/VBoxContainer/GoModeLabel.text = "GO MODE"
		$TabContainer/Map/MapSettings/VBoxContainer/GoModeLabel.label_settings.font_color = LEVEL_COLORS[level]


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


func get_location_panel(serial: String) -> LocationPanel:
	for i in $TabContainer/LocationRequirements/VBoxContainer.get_children():
		if PlayerState.serialize_location(i) == serial:
			return i
	return null


func get_item_node(item_name: String) -> Item:
	for i: Item in %ItemPool.get_children():
		if i.item_name == item_name:
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


func _on_starting_location_item_selected(index: int) -> void:
	if index == 0:
		$TabContainer/PlayerState/ControlPanel/VBoxContainer/HBoxContainer/StartingLocation.selected = (randi_range(1, $TabContainer/PlayerState/ControlPanel/VBoxContainer/HBoxContainer/StartingLocation.item_count))
		index = $TabContainer/PlayerState/ControlPanel/VBoxContainer/HBoxContainer/StartingLocation.selected
	starting_room = $TabContainer/PlayerState/ControlPanel/VBoxContainer/HBoxContainer/StartingLocation.get_item_text(index)
	update_reachable()
	update_transitions.emit()
	update_map()


func _on_persistant_items_toggled(toggled_on: bool) -> void:
	persistant_items = toggled_on


func _on_item_flags_toggled(toggled_on: bool) -> void:
	show_item_flags = toggled_on


func _on_goal_option_item_selected(_index: int) -> void:
	update_go_mode()


class PlayerState:
	var main: Main
	
	var prog_items: Array[String] = []
	var ap_prog_items: Array[String] = []
	
	var checked_locations: Array[LocationPanel]
	
	
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
			return (prog_items + ap_prog_items).has(item))
	
	
	func checked_locations_serialized() -> Array[String]:
		var result: Array[String]
		for i in checked_locations:
			if i == null:
				continue
			result.append(i.room_id + ": " + i.loc_description)
		return result
	
	
	static func serialize_location(loc: LocationPanel) -> String:
		return loc.room_id + ": " + loc.loc_description
	
	
	func check_location_serialized(serial: String, uncheck := false) -> void:
		if not checked_locations_serialized().has(serial):
			if not uncheck:
				checked_locations.append(main.get_location_panel(serial))
				
				for i in main.get_node("TabContainer/LocationRequirements/VBoxContainer").get_children():
					i.update()
		elif uncheck:
			checked_locations.erase(main.get_location_panel(serial))
			
			for i in main.get_node("TabContainer/LocationRequirements/VBoxContainer").get_children():
				i.update()
