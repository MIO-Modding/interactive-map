class_name Main extends Control


## Emited whenever the itempool is added to or taken away from
signal update_itempool
## Emitted whenever transitions should update (is connected to each individual 
##[TransitionPanel], [RoomPanel], and [LocationPanel]) (all [FeaturePanel]s [i]except[/i] for [Item.ItemPanel]s)
signal update_transitions
## Emitted when the [HttpRequest] for the sheet finishes requesting and loading all data
signal finished_requesting
## Emitted when [member wheel_rotation] is set
signal rotation_changed

## The levels of logic used
enum LogicLevels {
	NONE, ## Out of logic (ool)
	INTENDED_LOGIC, ## The player is intended in the game to be able to reach this room/location.
	SIMPLE_SKIPS, ## The player can preform simple skips to be able to reach this room/location.
	ADVANCED_SKIPS, ## The player can preform advanced skips to be able to reach this room/location.
}

## The associated colors for [enum LogicLevels]
const LEVEL_COLORS: Dictionary[LogicLevels, Color] = {
	LogicLevels.NONE: Color.WHITE,
	LogicLevels.INTENDED_LOGIC: Color.GREEN,
	LogicLevels.SIMPLE_SKIPS: Color.YELLOW,
	LogicLevels.ADVANCED_SKIPS: Color(1.0, 0.5, 0.0),
}

## The links to the csv exports for the sheets
const DATA_LINKS: Dictionary[String, String] = {
	"room requirements": "https://docs.google.com/spreadsheets/d/e/2PACX-1vQYd9mu0z_IXnGbZ0bUtAVHz3ZNRZymIfcYkz9HWXWNhd_ChxBTCdAVDcpHI3YMCtXrFNfkuvot1rbe/pub?gid=2144568902&single=true&output=csv",
	"items": "https://docs.google.com/spreadsheets/d/e/2PACX-1vQYd9mu0z_IXnGbZ0bUtAVHz3ZNRZymIfcYkz9HWXWNhd_ChxBTCdAVDcpHI3YMCtXrFNfkuvot1rbe/pub?gid=972951089&single=true&output=csv",
	"transition requirements": "https://docs.google.com/spreadsheets/d/e/2PACX-1vQYd9mu0z_IXnGbZ0bUtAVHz3ZNRZymIfcYkz9HWXWNhd_ChxBTCdAVDcpHI3YMCtXrFNfkuvot1rbe/pub?gid=1532215933&single=true&output=csv",
	"location requirements": "https://docs.google.com/spreadsheets/d/e/2PACX-1vQYd9mu0z_IXnGbZ0bUtAVHz3ZNRZymIfcYkz9HWXWNhd_ChxBTCdAVDcpHI3YMCtXrFNfkuvot1rbe/pub?gid=0&single=true&output=csv",
	"combat requirements": "https://docs.google.com/spreadsheets/d/e/2PACX-1vQYd9mu0z_IXnGbZ0bUtAVHz3ZNRZymIfcYkz9HWXWNhd_ChxBTCdAVDcpHI3YMCtXrFNfkuvot1rbe/pub?gid=760960441&single=true&output=csv",
}

## The columns used for each data set
const KIND_MAXES: Dictionary[String, int] = {
	"room requirements": 12,
	"items": 8,
	"transition requirements": 8,
	"location requirements": 13,
	"combat requirements": 5,
}

## The transitions that are wrapped around the map for each rotation
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

## X-coordinate ranges for regions of the lower part of the map around each shuttle
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

## The state of this player, including items given through this client and items received through archipelago.
static var player_state: PlayerState

## The values of the room requirements sheet, as a 2D array of strings.
var room_requirements_sheet: Array[Array]
## The values of the items sheet, as a 2D array of strings.
var items_sheet: Array[Array]
## The values of the transition requirements sheet, as a 2D array of strings.
var transition_requirements_sheet: Array[Array]
## The values of the location requirements sheet, as a 2D array of strings.
var location_requirements_sheet: Array[Array]
## The values of the combat requirements sheet, as a 2D array of strings.
var combat_requirements_sheet: Array[Array]

## Wether to highlight rows of sheets that their logic can be completed
var highlight_rows_in_logic := true
## Wether to highlight rows of sheets that are reachable
var highlight_reachable_rows := true
## The current logic kind, used to calculate reachable locations/items
var logic_kind: LogicLevels = LogicLevels.INTENDED_LOGIC

## Intended reachable rooms
var reachable_rooms: Array[String]
## Simple skips reachable rooms
var simple_reachable_rooms: Array[String]
## Advanced skips reachable rooms
var advanced_reachable_rooms: Array[String]

## The room that the player starts in, used for logic calculation
var starting_room := "ST_security_fall_P1"
## If double clicking a location should mark it as checked (and send the archipelago check)
var double_click_checks_locations := false
## If item received popups from archipelago shoul persist until acknowledged
var persistant_items := true
## If item recieved popups from archipelago should show their save flags
var show_item_flags := false

## Intended reachable locations
var reachable_locations: Array[LocationPanel]
## Simple skips reachable locations
var simple_reachable_locations: Array[LocationPanel]
## Advanced skips reachable locations
var advanced_reachable_locations: Array[LocationPanel]
## If the player is in go mode
var go_mode := false

## Theme for the scene
var window_theme := Theme.new()

## The current rotation of the wheel
var wheel_rotation := "0":
	set(v):
		wheel_rotation = v
		rotation_changed.emit()

## The save keys to preference nodes
@onready var preferences_to_save: Dictionary[String, Control] = {
	"MAP_SETTINGS>DOUBLE_CLICK_CHECK": $TabContainer/Map/MapSettings/VBoxContainer/DoubleChecker,
	"MAP_SETTINGS>ROOM_POINTS": $TabContainer/Map/MapSettings/VBoxContainer/RoomPoints,
	"MAP_SETTINGS>TRANSITIONS": $TabContainer/Map/MapSettings/VBoxContainer/Transitions,
	"MAP_SETTINGS>LOCATIONS": $TabContainer/Map/MapSettings/VBoxContainer/Locations,
	"MAP_SETTINGS>MAP_IMAGE_TYPE": $TabContainer/Map/MapSettings/VBoxContainer/MapImageType,
	"MAP_SETTINGS>MAP_ROTATION": $TabContainer/Map/MapSettings/VBoxContainer/Rotation,
	
	"FILTERS>AREA_FILTER": $TabContainer/Map/MapSettings/VBoxContainer/Filters/VBoxContainer/AreaFilter,
	"FILTERS>TYPE_FILTER": $TabContainer/Map/MapSettings/VBoxContainer/Filters/VBoxContainer/TypeFilter,
	"FILTERS>LOGIC_FILTER": $TabContainer/Map/MapSettings/VBoxContainer/Filters/VBoxContainer/LogicFilter,
	"FILTERS>CHECKED_FILTER": $TabContainer/Map/MapSettings/VBoxContainer/Filters/VBoxContainer/CheckedFilter,
	"FILTERS>SCOUTABLE_FILTER": $TabContainer/Map/MapSettings/VBoxContainer/Filters/VBoxContainer/ScoutableFilter,
	
	"CTRL_PANEL>HIGHLIGHT": $TabContainer/PlayerState/ControlPanel/VBoxContainer/HighlightToggle,
	"CTRL_PANEL>HIGHLIGHT_REACHABLE": $TabContainer/PlayerState/ControlPanel/VBoxContainer/HighlightReachable,
	"CTRL_PANEL>STARTING_ROOM": $TabContainer/PlayerState/ControlPanel/VBoxContainer/HBoxContainer/StartingLocation,
	
	"ARCHIPELAGO>PERSISTANT_ITEMS": $TabContainer/PlayerState/ControlPanel/VBoxContainer/ArchipelagoSettings/VBoxContainer/PersistantItems,
	"ARCHIPELAGO>SHOW_ITEM_FLAGS": $TabContainer/PlayerState/ControlPanel/VBoxContainer/ArchipelagoSettings/VBoxContainer/ItemFlags,
}


func _ready() -> void:
	$LoadingScreen.show()
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
	var label := Label.new()
	var checkbox := CheckBox.new()
	var content_box: GridContainer = get_node("TabContainer/ArchipelagoClient/CommonClient/Tabs/Console/ConnectBox/Row/Box/Margins/VBox/Content")
	label.text = "Manual?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	checkbox.size_flags_horizontal = Control.SIZE_EXPAND
	checkbox.toggled.connect(set_manual)
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.3, 0.3, 0.3)
	checkbox.add_theme_stylebox_override("normal", stylebox)
	checkbox.add_theme_stylebox_override("hover", stylebox)
	Archipelago.connected.connect(func(_e, _f): checkbox.disabled = true)
	Archipelago.disconnected.connect(func(): checkbox.disabled = false)
	content_box.add_child(label)
	content_box.move_child(label, 8)
	content_box.add_child(checkbox)
	content_box.move_child(checkbox, 9)
	
	request_data()
	
	await get_tree().process_frame
	get_node("TabContainer").get_child(0).get_child(0).focus_mode = Control.FOCUS_CLICK
	
	await get_tree().process_frame
	
	load_preferences()
	for i in preferences_to_save.values():
		if i is CheckBox or i is CheckButton:
			i.pressed.connect(save_all_preferences)
		elif i is OptionButton:
			i.item_selected.connect(save_all_preferences.unbind(1))


## Requests all the sheet data and loads it when it arrives
func request_data():
	var requester := HTTPRequest.new()
	add_child(requester)
	
	requester.request_completed.connect(iterate_requests.bind(DATA_LINKS.keys()), CONNECT_ONE_SHOT)
	$LoadingScreen/VBoxContainer/ProgressBar.value += 1
	$LoadingScreen/VBoxContainer/Label.text = "Requesting room requirements"
	requester.request(DATA_LINKS["room requirements"])
	Globals.trigger_popup("Queued room requirements")


## Receives a request and runs the next one from [param kinds]. Emits [signal finished_requesting] when finished.
## Runs [method on_finished_request] for each.
func iterate_requests(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, kinds: Array) -> void:
	await on_finished_request(result, response_code, headers, body, kinds[0])
	kinds.remove_at(0)
	if kinds.is_empty():
		for i in $VBoxContainer.get_children():
			i.queue_free()
		$LoadingScreen.visible = false
		finished_requesting.emit()
		return
	get_child(-1).request_completed.connect(iterate_requests.bind(kinds), CONNECT_ONE_SHOT)
	$LoadingScreen/VBoxContainer/ProgressBar.value += 1
	$LoadingScreen/VBoxContainer/Label.text = "Requesting " + kinds[0]
	get_child(-1).request(DATA_LINKS[kinds[0]])
	Globals.trigger_popup("Queued " + kinds[0])


## Loads data from a sheet.
func on_finished_request(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray, kind: String = "") -> void:
	$LoadingScreen/VBoxContainer/ProgressBar.value += 1
	$LoadingScreen/VBoxContainer/Label.text = "Loading " + kind
	
	await get_tree().process_frame
	
	Globals.trigger_popup("Recieved " + kind)
	room_requirements_sheet = []
	
	assert(KIND_MAXES.has(kind))
	fill_sheet(kind, body, KIND_MAXES[kind])
	
	match kind:
		"room requirements":
			room_requirements_sheet = room_requirements_sheet.filter(func(e): return not e[0].is_empty())
			var skip_first := true
			var columns := parse_header_row(room_requirements_sheet[0])
			for row in room_requirements_sheet:
				for cell in row:
					var label = Label.new()
					label.text = cell
					$TabContainer/RoomRequirements/GridContainer.add_child(label)
				
				if not skip_first:
					var panel: RoomPanel = preload("res://Scenes/room_panel.tscn").instantiate()
					panel.region_name = row[columns["Region Name"]]
					panel.room_id = row[columns["Room ID"]]
					panel.connected_rooms.assign(row[columns["Connected Rooms"]].split(", ") as Array)
					if not row[columns["Room Coordinates (logical center)"]].is_empty():
						panel.logical_coords = str_to_var("Vector2i" + row[columns["Room Coordinates (logical center)"]])
					panel.logical_coords_description = row[columns["Center Description"]]
					panel.notes = row[columns["Remarks"]]
					if not row[columns["Room Text Position"]].is_empty():
						panel.coords = str_to_var("Vector2i" + row[columns["Room Text Position"]])
					update_transitions.connect(panel.update)
					panel.hide()
					
					$TabContainer/Map/SubViewportContainer/SubViewport/Node2D/Panels.add_child(panel)
					panel.update()
					
					if row[columns["Room ID"]] != "ST_security_fall_P1":
						$TabContainer/PlayerState/ControlPanel/VBoxContainer/HBoxContainer/StartingLocation.add_item(row[columns["Room ID"]])
				
				skip_first = false
				
		"items":
			items_sheet = items_sheet.filter(func(e): return not e[0].is_empty())
			var skip_first := true
			var columns := parse_header_row(items_sheet[0])
			for row in items_sheet:
				if not skip_first:
					var item: Item = preload("res://Scenes/item.tscn").instantiate()
					item.item_name = row[columns["Item Name"]]
					item.max_amount = row[columns["Amount"]].to_int()
					item.room = row[columns["Room ID"]]
					item.type = Item.ItemTypes[row[columns["Type"]].to_upper()]
					item.classification = Item.ItemClassifications[row[columns["AP Classification"]].to_upper()]
					item.save_entry = row[columns["Save Entry Key"]]
					item.notes = row[columns["Remarks"]]
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
			var columns := parse_header_row(transition_requirements_sheet[0])
			var skip_first := true
			for row in transition_requirements_sheet:
				if skip_first:
					skip_first = false
					continue
				
				var panel: TransitionPanel = preload("res://Scenes/transition_panel.tscn").instantiate()
				panel.from = row[columns["From"]]
				panel.to = row[columns["To"]]
				panel.first_pass = row[columns["First Pass"]] == "TRUE"
				panel.intended_string = row[columns["Intended Logic"]]
				panel.simple_string = row[columns["Simple Skips"]]
				panel.advanced_string = row[columns["Advanced Skips"]]
				panel.door = row[columns["Door?"]]
				panel.notes = row[columns["Remarks"]]
				update_transitions.connect(panel.update)
				$TabContainer/TransitionRequirements/VBoxContainer.add_child(panel)
			
			for i in range(3):
				await get_tree().process_frame
			
			update_reachable()
			update_transitions.emit()
		"location requirements":
			location_requirements_sheet = location_requirements_sheet.filter(func(e): return not e[0].is_empty())
			var skip_first := true
			var columns := parse_header_row(location_requirements_sheet[0])
			for row in location_requirements_sheet:
				if skip_first:
					skip_first = false
					continue
				if row[columns["Location Category"]] == "Junk Pile":
					continue
				
				var panel: LocationPanel = preload("res://Scenes/location_panel.tscn").instantiate()
				panel.region_name = row[columns["Region Name"]]
				panel.room_id = row[columns["Room ID"]]
				panel.loc_description = row[columns["Description of Location"]]
				if row[columns["Location Coordinates"]] == "N/A":
					panel.coords = Vector2i.ZERO
				else:
					panel.coords = str_to_var("Vector2i" + row[columns["Location Coordinates"]])
				panel.vanilla_item = row[columns["Vanilla Location Reward"]]
				panel.save_flag = row[columns["Flag"]]
				panel.intended_string = row[columns["Intended Logic"]]
				panel.simple_string = row[columns["Simple Skips"]]
				panel.advanced_string = row[columns["Advanced Skips"]]
				panel.notes = row[columns["Remarks"]]
				panel.type = row[columns["Location Category"]]
				update_transitions.connect(panel.update)
				$TabContainer/LocationRequirements/VBoxContainer.add_child(panel)
		"combat requirements":
			var boss_locations: Array[LocationPanel]
			for location: LocationPanel in $TabContainer/LocationRequirements/VBoxContainer.get_children():
				if location.save_flag.contains("BOSS"):
					boss_locations.append(location)
			
			combat_requirements_sheet = combat_requirements_sheet.filter(func(e): return not e[0].is_empty())
			var skip_first := true
			var columns := parse_header_row(combat_requirements_sheet[0])
			for row in combat_requirements_sheet:
				if skip_first:
					skip_first = false
					continue
				
				var loc_panel: LocationPanel
				for loc: LocationPanel in boss_locations:
					if loc.save_flag == row[columns["Save Flag"]]:
						loc_panel = loc
				if loc_panel == null:
					continue
				
				if loc_panel.advanced_string == "-":
					if loc_panel.simple_string == "-":
						loc_panel.advanced_string = combine_logic_strings(loc_panel.intended_string, row[columns["Requirements (Hard)"]])
					else:
						loc_panel.advanced_string = combine_logic_strings(loc_panel.simple_string, row[columns["Requirements (Hard)"]])
				else:
					loc_panel.advanced_string = combine_logic_strings(loc_panel.advanced_string, row[columns["Requirements (Hard)"]])
				if loc_panel.simple_string == "-":
					loc_panel.simple_string = combine_logic_strings(loc_panel.intended_string, row[columns["Requirements (Medium)"]])
				else:
					loc_panel.simple_string = combine_logic_strings(loc_panel.simple_string, row[columns["Requirements (Medium)"]])
				loc_panel.intended_string = combine_logic_strings(loc_panel.intended_string, row[columns["Requirements (Easy/Intended)"]])
			
			update_reachable()
			for i in range(4):
				await get_tree().process_frame
			update_map()
			update_itempool.connect(update_map)


## Fills a sheet with data from [param body], limiting the amount of columns to [param cap]
func fill_sheet(sheet_kind: String, body: PackedByteArray, cap: int = -1) -> void:
	for i in body.get_string_from_utf8().split("\r\n"):
		var current = row_to_list(i, cap)
		if not is_empty_string_list(current):
			get("%s_sheet" % sheet_kind.to_snake_case()).append(current)


## Converts a stringified row to an array, limiting the amount of columns to [param cap]
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


## Returns a dictionary of headings to their index
func parse_header_row(row: Array[String]) -> Dictionary[String, int]:
	var columns: Dictionary[String, int] = {}
	for index in range(len(row)):
		var heading = row[index]
		if not heading.is_empty():
			columns[heading] = index
	return columns


## 'Ands' two logic strings into one.
func combine_logic_strings(string1: String, string2: String) -> String:
	if string1 == "":
		return string2
	elif string2 == "":
		return string1
	elif string1 == "False":
		return string1
	elif string2 == "False":
		return string2
	elif string1 == "True":
		return string2
	elif string2 == "True":
		return string1
	return "(%s) and (%s)" % [string1, string2]


## Updates all reachable locations and items for each [enum LogicLevels]
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


## Returns all reachable locations
func get_reachable_locations(availible_rooms: Array[String]) -> Array[LocationPanel]:
	var result: Array[LocationPanel] = []
	
	for room in availible_rooms:
		for loc: LocationPanel in get_locations_for_room(room):
			if loc_in_logic(loc):
				result.append(loc)
	
	return result


## Returns all the locations in a room
func get_locations_for_room(room_id: String) -> Array[LocationPanel]:
	var result: Array[LocationPanel] = []
	for i: LocationPanel in $TabContainer/LocationRequirements/VBoxContainer.get_children():
		if i.room_id == room_id:
			result.append(i)
	return result


## Returns all reachable rooms
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


## Returns all rooms connected to [param room] that have their transition in logic.
func get_room_connections(room: String) -> Array[String]:
	var result: Array[String] = []
	for i: TransitionPanel in $TabContainer/TransitionRequirements/VBoxContainer.get_children():
		if i.from == room:
			if in_logic(i):
				if not result.has(i.to):
					result.append(i.to)
	return result


## Returns the harder logic between the two
func get_higher_logic(logic1: LogicLevels, logic2: LogicLevels) -> LogicLevels:
	return maxi(logic1, logic2) as LogicLevels


## Gets the [enum LogicLevels] for [param panel]
func get_logic(panel: TransitionPanel) -> LogicLevels:
	if panel.intended_logic.call():
		return LogicLevels.INTENDED_LOGIC
	
	if panel.simple_string != "-":
		if panel.simple_logic.call():
			return LogicLevels.SIMPLE_SKIPS
		if panel.advanced_logic.call():
			return LogicLevels.ADVANCED_SKIPS
	
	return LogicLevels.NONE


## If the [param panel]'s logic is completable with the current logic kind (can override with [param override_logic_kind]
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


## If the [param loc_panel]'s logic is completable with the current logic kind (can override with [param override_logic_kind]
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


## If the [param string_list] contains only empty strings
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


## Updates the map
func update_map() -> void:
	await get_tree().process_frame
	var map_node: Node2D = $TabContainer/Map/SubViewportContainer/SubViewport/Node2D
	
	for i in ["Points", "Lines", "LocPoints", "LocLines"].map(func(e): return map_node.get_node(e).get_children()):
		for node: Node in i:
			node.free()
	
	#await get_tree().process_frame
	
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
			if wheel_rotation == "120" and loc_panel.room_id == "ST_tube_vanilla_S1" and loc_panel.save_flag == "SHIELD_FRAGMENT:15":
				# workaround so this location doesn't draw a line across the map in rotation 120
				temp_point = loc_panel.coords
				temp_point.x += ROTATION_OFFSETS["120"]["Lab"]
			
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
		else:
			line.add_point(room_panel.point_node.position)
		line.add_point(point.position)
		$TabContainer/Map/SubViewportContainer/SubViewport/Node2D/LocLines.add_child(line)
		loc_panel.update()
		
		point.set_meta("line", line)
		if is_location_event(loc_panel):
			point.self_modulate = Color.REBECCA_PURPLE
	
	$TabContainer/Map.update_filter()


## If the [param loc_panel] is an event location
func is_location_event(loc_panel: LocationPanel) -> bool:
	for i: Item in %ItemPool.get_children():
		if i.item_name == loc_panel.vanilla_item or (i.save_entry == loc_panel.save_flag and loc_panel.save_flag != ""):
			return i.type == Item.ItemTypes.EVENT
	return false


## Returns the item at the [param loc_panel]
func get_item_at_location(loc_panel: LocationPanel) -> Item:
	var converted_vanilla: String = loc_panel.vanilla_item
	for i in ["z", "s"]:
		if converted_vanilla.contains("Crystalli%sed Nacre - " % i):
			converted_vanilla = "Crystallised Nacre"
	for i: Item in %ItemPool.get_children():
		if i.item_name == converted_vanilla or (i.save_entry == loc_panel.save_flag and loc_panel.save_flag != ""):
			return i
	return null


## Returns the event location for the event [param item]
func get_event_location(item: Item) -> LocationPanel:
	for i: LocationPanel in $TabContainer/LocationRequirements/VBoxContainer.get_children():
		if i.vanilla_item == item.item_name or (item.save_entry == i.save_flag and i.save_flag != ""):
			return i
	return null


## Shows the [TransitionPanel] when a [param line] is clicked
func line_clicked(line: TransitionLine) -> void:
	for i in $TabContainer/Map/ScrollContainer/PanelContainer/VBoxContainer.get_children():
		i.queue_free()
	
	$TabContainer/Map/ScrollContainer/PanelContainer/VBoxContainer.add_child(line.transition_panel.duplicate())
	var second_panel := get_transition_panel(line.transition_panel.from, line.transition_panel.to)
	if second_panel != null:
		$TabContainer/Map/ScrollContainer/PanelContainer/VBoxContainer.add_child(second_panel.duplicate())


## Shows the [LocationPanel] or [RoomPanel] when a [param point] is clicked 
## (checks the location if it's a location point, [param double_click] is true, and [member double_click_checks_locations
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


## Checks if the player is in go mode and updates the label for it
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


## Gets the [TransitionPanel] for the room [param from] going into [param to]
func get_transition_panel(to: String, from: String) -> TransitionPanel:
	for i: TransitionPanel in $TabContainer/TransitionRequirements/VBoxContainer.get_children():
		if i.to == to and i.from == from:
			return i
	return null


## Gets the [RoomPanel] for the given [param id]
func get_room_panel(id: String) -> RoomPanel:
	for i: RoomPanel in $TabContainer/Map/SubViewportContainer/SubViewport/Node2D.get_node("Panels").get_children():
		if i.room_id == id:
			return i
	return null


## Gets the [LocationPanel] for the serialized value [param serial]
func get_location_panel(serial: String) -> LocationPanel:
	for i in $TabContainer/LocationRequirements/VBoxContainer.get_children():
		if PlayerState.serialize_location(i) == serial:
			return i
	return null


## Gets the [Item] with name [param item_name]
func get_item_node(item_name: String) -> Item:
	for i: Item in %ItemPool.get_children():
		if i.item_name == item_name:
			return i
	return null


## Sets the game name and [member is_manual]
func set_manual(is_manual: bool) -> void:
	Globals.is_manual = is_manual
	if not Archipelago.is_ap_connected():
		Archipelago.AP_GAME_NAME = "Manual_MIO_Samwell" if is_manual else "Memories in Orbit"


## Saves the player's preferences
func save_all_preferences() -> void:
	if not DirAccess.dir_exists_absolute("user://Data"):
		DirAccess.make_dir_absolute("user://Data")
	
	var file := FileAccess.open("user://Data/prefs.dat", FileAccess.WRITE)
	
	var result: Dictionary[String, Variant]
	for i in preferences_to_save:
		result[i] = get_preference(i)
	var stringified: String = JSON.stringify(result)
	stringified = stringified.replace(",", ",\n\t").replace("{", "{\n\t").replace("}", "\n}")
	file.store_string(stringified)


## Gets the preference value with the given [param key]
func get_preference(key: String) -> Variant:
	var node: Control = preferences_to_save[key]
	if node is CheckBox or node is CheckButton:
		return node.button_pressed
	elif node is OptionButton:
		return node.selected
	else:
		printerr("Unrecognised node for %s" % node.get_path())
	return ""


## Loads the player's preferences
func load_preferences() -> void:
	if not DirAccess.dir_exists_absolute("user://Data"):
		DirAccess.make_dir_absolute("user://Data")
	if not FileAccess.file_exists("user://Data/prefs.dat"):
		FileAccess.open("user://Data/prefs.dat", FileAccess.WRITE)
		return
	
	var stringified: String = FileAccess.get_file_as_string("user://Data/prefs.dat")
	stringified = stringified.replace("\n}", "}").replace("{\n\t", "{").replace(",\n\t", ",")
	var data: Dictionary = JSON.parse_string(stringified)
	for i in preferences_to_save:
		if data.has(i):
			set_preference(i, data[i])


## Sets the preference at [param entry] with [param value]
func set_preference(entry: String, value: Variant) -> void:
	var node: Control = preferences_to_save[entry]
	if node is CheckBox or node is CheckButton:
		node.button_pressed = value
	elif node is OptionButton:
		node.select(value)
		node.item_selected.emit(value)


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


func _on_skip_button_pressed() -> void:
	$LoadingScreen.visible = false


func _on_double_checker_toggled(toggled_on: bool) -> void:
	double_click_checks_locations = toggled_on


func _on_deathlink_send_pressed() -> void:
	Globals.send_deathlink($TabContainer/PlayerState/ControlPanel/VBoxContainer/ArchipelagoSettings/VBoxContainer/DeathLink/Cause.text)


class PlayerState:
	## Class for holding items given by the client, received from archipelago, and checked locations
	
	## Reference to main
	var main: Main
	
	## Items given from the client
	var prog_items: Array[String] = []
	## Items received from archipelago
	var ap_prog_items: Array[String] = []
	## Checked [LocationPanel]s
	var checked_locations: Array[LocationPanel]
	
	
	## Returns a callable that calls [param calls] with the and operator
	func and_call(calls: Array[Callable]) -> Callable:
		return (func() -> bool:
			for i in calls:
				if not i.call():
					return false
			return true)
	
	
	## Returns a callable that calls [param calls] with the or operator
	func or_call(calls: Array[Callable]) -> Callable:
		return (func() -> bool:
			for i in calls:
				if i.call():
					return true
			return false)
	
	
	## Returns a callable for if the player has the [param item]
	func has_call(item: String) -> Callable:
		return (func() -> bool:
			if item == "False":
				return false
			elif item == "True":
				return true
			return full_itemset().has(item))
	
	
	## Returns [member checked_locations] but serializes them
	func checked_locations_serialized() -> Array[String]:
		var result: Array[String]
		for i in checked_locations:
			if i == null:
				continue
			result.append(i.room_id + ": " + i.loc_description)
		return result
	
	
	func full_itemset() -> Array[String]:
		return Globals.main.player_state.prog_items + Globals.main.player_state.ap_prog_items
	
	
	## Serializes the [param loc], adding its 
	## [member LocationPanel.room_id] and [member LocationPanel.loc_description] with ": " in the middle
	static func serialize_location(loc: LocationPanel) -> String:
		return loc.room_id + ": " + loc.loc_description
	
	
	## Serializes the [param loc], in manual form. [br]
	## This form is [member LocationPanel.room_id]--([member LocationPanel.vanilla_item])
	static func get_manual_serialized(loc: LocationPanel) -> String:
		var result: String
		var room: String = loc.room_id
		var item: String = loc.vanilla_item
		if loc.vanilla_item.contains("Capucined"):
			room = "Capucine"
		if loc.vanilla_item.contains("Crystallized Nacre") or loc.vanilla_item.contains("Crystallised Nacre"):
			item = "Crystallised Nacre"
		
		result = "%s--(%s)" % [room, item]
		return result
	
	
	## Gets the item name for [param item] in manual form. [br]
	## This form is [member Item.save_entry] ([member Item.item_name]) [br]
	## The : in [member Item.save_entry] is replaced with a >
	static func get_manual_item_name(item: Item) -> String:
		var result: String
		result = "%s (%s)" % [item.save_entry.replace(":", ">"), item.item_name]
		return result
	
	
	## Gets the [LocationPanel] for the [param loc_name] in manual form
	## (see [method get_manual_serialized] for this form)
	static func get_manual_loc_node(loc_name: String) -> LocationPanel:
		var room: String = loc_name.get_slice("--(", 0)
		var item: String = loc_name.get_slice("--(", 1).trim_suffix(")")
		if room == "Capucine":
			room = "LQ_ruins_hall_C1"
		for i: LocationPanel in Globals.main.get_node("TabContainer/LocationRequirements/VBoxContainer").get_children():
			if i.room_id == room:
				if loc_name.contains("Crystalli"):
					if i.vanilla_item.contains("Crystallised Nacre") or i.vanilla_item.contains("Crystallized Nacre"):
						return i
				elif i.vanilla_item.containsn(item):
					return i
		return null
	
	
	## Gets the item name from [param item] in manual form
	## (see [method get_manual_item_name] for this form)
	static func convert_from_manual_item(item: String) -> String:
		var save_entry: String = item.get_slice(" (", 0).replace(">", ":")
		if save_entry == "Crystallised Nacre":
			return save_entry
		for i: Item in Globals.main.get_node("%ItemPool").get_children():
			if i.save_entry == save_entry:
				return i.item_name
		printerr("Item with save entry %s not found" % save_entry)
		return ""
	
	
	## Checks the location from the [param serial] (unchecks if [param uncheck] is true)
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
