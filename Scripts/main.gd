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
	"room requirements": 6,
	"items": 8,
	"transition requirements": 8,
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


func iterate_requests(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, kinds: Array) -> void:
	on_finished_request(result, response_code, headers, body, kinds[0])
	kinds.remove_at(0)
	if kinds.is_empty():
		return
	get_child(-1).request_completed.connect(iterate_requests.bind(kinds), CONNECT_ONE_SHOT)
	get_child(-1).request(DATA_LINKS[kinds[0]])


func on_finished_request(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray, kind: String = "") -> void:
	room_requirements_sheet = []
	print("Recieved " + kind)
	
	assert(KIND_MAXES.has(kind))
	fill_sheet(kind, body, KIND_MAXES[kind])
	
	match kind:
		"room requirements":
			for row in room_requirements_sheet:
				for cell in row:
					var label = Label.new()
					label.text = cell
					$TabContainer/RoomRequirements/GridContainer.add_child(label)
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
			
			update_transitions.emit()


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
			if i.count("\"") == 1:
				pending = i
				pending = pending.trim_prefix("\"")
			else:
				result.append(i)
				if result.size() >= cap and cap > 0:
					return result
		else:
			pending += "," + i
			if i.count("\"") == 1:
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
