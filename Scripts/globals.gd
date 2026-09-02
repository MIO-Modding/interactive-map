extends Node



var main: Main

var LOCATION_NAME_TO_ID: Dictionary[String, int]
var ITEM_NAME_TO_ID: Dictionary[String, int]



func _ready() -> void:
	main = get_node("/root/Main")
	Archipelago.connected.connect(connect_script)
	Archipelago.disconnected.connect(disconnect_script)
	Archipelago.remove_location.connect(remove_location)
	await main.finished_requesting
	LOCATION_NAME_TO_ID = get_loc_name_to_id()
	ITEM_NAME_TO_ID = get_item_name_to_id()


func connect_script(_conn: ConnectionInfo, _json: Dictionary) -> void:
	main.player_state.ap_prog_items = []
	for i: LocationPanel in main.get_node("TabContainer/LocationRequirements/VBoxContainer").get_children():
		i.checked = false
		if i.has_node("Checked"):
			i.get_node("Checked").disabled = true
	Archipelago.conn.obtained_item.connect(get_item)
	
	main.update_itempool.emit()


func disconnect_script() -> void:
	main.player_state.ap_prog_items = []
	for i: LocationPanel in main.get_node("TabContainer/LocationRequirements/VBoxContainer").get_children():
		i.checked = false
		if i.has_node("Checked"):
			i.get_node("Checked").disabled = false


func remove_location(loc_id: int) -> void:
	await get_tree().process_frame
	var loc_name: String = LOCATION_NAME_TO_ID.find_key(loc_id)
	var loc_panel: LocationPanel = main.get_location_panel(loc_name)
	if loc_panel != null:
		loc_panel.checked = true


func get_item(item: NetworkItem) -> void:
	main.player_state.ap_prog_items.append(item.get_name())
	
	main.update_itempool.emit()


func check_location(location: LocationPanel) -> void:
	if location == null:
		return
	var item: Item = main.get_item_at_location(location)
	if item == null:
		printerr(location.vanilla_item)
		return
	if item.type == Item.ItemTypes.EVENT:
		main.player_state.ap_prog_items.append(item.item_name)
		main.update_itempool.emit()
	else:
		Archipelago.collect_location(LOCATION_NAME_TO_ID[Main.PlayerState.serialize_location(location)])


func get_loc_name_to_id() -> Dictionary[String, int]:
	var result: Dictionary[String, int] = {}
	var id: int = 0
	for i: LocationPanel in main.get_node("TabContainer/LocationRequirements/VBoxContainer").get_children():
		if not main.is_location_event(i):
			id += 1
			result[Main.PlayerState.serialize_location(i)] = id
	return result


func get_item_name_to_id() -> Dictionary[String, int]:
	return {}
