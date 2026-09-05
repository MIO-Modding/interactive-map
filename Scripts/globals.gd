extends Node



var main: Main

var LOCATION_NAME_TO_ID: Dictionary[String, int]
var ITEM_NAME_TO_ID: Dictionary[String, int]

var queued_refresh := false


func _ready() -> void:
	main = get_node("/root/Main")
	Archipelago.connected.connect(connect_script)
	Archipelago.disconnected.connect(disconnect_script)
	Archipelago.remove_location.connect(remove_location)
	
	main.get_node("TabContainer/PlayerState/ControlPanel/VBoxContainer/ArchipelagoSettings").hide()
	
	await main.finished_requesting
	ITEM_NAME_TO_ID = get_item_name_to_id()


func _process(_delta: float) -> void:
	if queued_refresh:
		main.update_itempool.emit()
		queued_refresh = false


func connect_script(_conn: ConnectionInfo, _json: Dictionary) -> void:
	main.player_state.ap_prog_items = []
	for i: LocationPanel in main.get_node("TabContainer/LocationRequirements/VBoxContainer").get_children():
		i.checked = false
		if i.has_node("Checked"):
			i.get_node("Checked").disabled = true
	Archipelago.conn.obtained_item.connect(get_item)
	LOCATION_NAME_TO_ID.assign(Archipelago.conn.get_gamedata_for_player(Archipelago.conn.player_id).location_name_to_id)
	main.get_node("TabContainer/PlayerState/ControlPanel/VBoxContainer/ArchipelagoSettings").show()
	
	main.update_itempool.emit()
	
	await get_tree().process_frame
	for i in main.get_node("VBoxContainer").get_children():
		i.queue_free()


func disconnect_script() -> void:
	main.player_state.ap_prog_items = []
	for i: LocationPanel in main.get_node("TabContainer/LocationRequirements/VBoxContainer").get_children():
		i.checked = false
		if i.has_node("Checked"):
			i.get_node("Checked").disabled = false
	main.get_node("TabContainer/PlayerState/ControlPanel/VBoxContainer/ArchipelagoSettings").hide()


func remove_location(loc_id: int) -> void:
	await get_tree().process_frame
	var loc_name: String = LOCATION_NAME_TO_ID.find_key(loc_id)
	var loc_panel: LocationPanel = main.get_location_panel(loc_name)
	if loc_panel != null:
		loc_panel.checked = true


func get_item(item: NetworkItem) -> void:
	main.player_state.ap_prog_items.append(item.get_name())
	trigger_popup("Received item: %s" % item.get_name(), Color.GREEN, true)
	
	queued_refresh = true


func check_location(location: LocationPanel, send := true) -> void:
	if location == null:
		return
	var item: Item = main.get_item_at_location(location)
	if item == null:
		printerr(location.vanilla_item)
		return
	if item.type == Item.ItemTypes.EVENT:
		if send:
			main.player_state.ap_prog_items.append(item.item_name)
		else:
			main.player_state.ap_prog_items.erase(item.item_name)
		main.update_itempool.emit()
	else:
		var serialized: String
		serialized = Main.PlayerState.serialize_location(location)
		if serialized.contains("Capucine") and not LOCATION_NAME_TO_ID.keys().has(serialized):
			serialized = "Capucine: " + location.loc_description
		if not LOCATION_NAME_TO_ID.keys().has(serialized):
			serialized = serialized.strip_edges()
			printerr("%s not in ap locations" % serialized)
		Archipelago.collect_location(LOCATION_NAME_TO_ID[serialized])


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


func trigger_popup(text: String, color := Color.WHITE, is_item := false) -> void:
	var popup := PanelContainer.new()
	var container := HBoxContainer.new()
	popup.add_child(container)
	var label := Label.new()
	label.text = text
	label.label_settings = LabelSettings.new()
	label.label_settings.font_color = color
	label.label_settings.font_size = 30
	label.size_flags_horizontal = Control.SIZE_EXPAND
	if is_item:
		var node: Item = main.get_item_node(text.get_slice(": ", 1))
		if node != null:
			if main.show_item_flags:
				label.text += " (%s)" % node.save_entry
			label.label_settings.font_color = Item.COLORS[node.classification]
	container.add_child(label)
	if is_item and main.persistant_items:
		var button := Button.new()
		button.text = "Added?"
		button.pressed.connect(func(): popup.queue_free(), CONNECT_ONE_SHOT)
		container.add_child(button)
	main.get_node("VBoxContainer").add_child(popup)
	
	print_rich("[color=%s]%s[/color]" % [label.label_settings.font_color.to_html(false), text])
	
	if is_item and main.persistant_items:
		return
	await get_tree().create_timer(3).timeout
	if is_instance_valid(popup):
		popup.queue_free()


func fix_underscores(input: String) -> String:
	return input.replace("_", "\\_")
