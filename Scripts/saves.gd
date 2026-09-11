class_name SavesMenu extends Control


signal toggle_delete(on: bool)
signal mode_changed(mode: int)

const SAVES_FOLDER: String = "user://Data/Saves"
const STATE_PATH: String = SAVES_FOLDER + "/States/%s.dat"
const SAVE_FILES_PATH: String = SAVES_FOLDER + "/SaveFiles/%s.dat"
const METADATA_PATH: String = SAVES_FOLDER + "/Metadata/%s.dat"

var old_core_dialog: Array[String]

var mio_saves_path: String


func _ready() -> void:
	for i in [STATE_PATH, SAVE_FILES_PATH, METADATA_PATH]:
		validate_folders(i.trim_suffix("%s.dat"))
	
	Globals.main.finished_requesting.connect(update_display)
	mio_saves_path = find_mio_saves_path()


func update_display() -> void:
	var list: Array[String]
	list.assign(Array(DirAccess.get_files_at(STATE_PATH.trim_suffix("%s.dat"))))
	
	list.sort_custom(func(str1: String, str2: String): return str1.naturalnocasecmp_to(str2) < 0)
	
	for i in $Lists/State/V/Scroll/VBoxContainer.get_children():
		i.queue_free()
	
	for i in list:
		var state_panel := await StatePanel.new()
		state_panel.text = i.get_basename()
		state_panel.call_deferred("toggle_delete", $Lists/State/V/DeleteButton.button_pressed)
		$Lists/State/V/Scroll/VBoxContainer.add_child(state_panel)
	
	if not OS.has_feature("web") and not mio_saves_path.is_empty():
		var all_files: Array[String] = get_mio_saves()
		#for i in range(3):
			#if all_files.has("slot_%d" % i):
				#pass # make metadata
		
		var all_saves: Array[StatePanel]
		all_saves.assign($Lists/File/V/Scroll/VBoxContainer.get_children())
		
		if $Lists/File/V/ModeOption.selected == 2:
			var temp: Array[String]
			for i in range(all_files.size()):
				for save in all_saves:
					if save.save_index == i:
						temp.append(save.text)
			all_files.assign(temp)
		else:
			all_files.sort_custom(func(str1: String, str2: String): return str1.naturalnocasecmp_to(str2) < 0)
		
		var start_index = 0
		for i in range(3).map(func(e): return "slot_%d" % e):
			if all_files.has(i):
				start_index += 1
		
		for file_name in all_files:
			var state_panel := await StatePanel.new()
			
			if all_saves.is_empty():
				if range(3).map(func(e): return "slot_%d" % e).has(file_name):
					state_panel.save_index = file_name[-1].to_int()
				else:
					state_panel.save_index = start_index
					start_index += 1
			else:
				for i in all_saves:
					if i.text == file_name:
						state_panel.save_index = i.save_index
			
			state_panel.text = file_name
			state_panel.is_save_panel = true
			state_panel.call_deferred("toggle_delete", $Lists/State/V/DeleteButton.button_pressed)
			state_panel.call_deferred("set", "save_index", state_panel.save_index)
			$Lists/File/V/Scroll/VBoxContainer.add_child(state_panel)
		
		for i in all_saves:
			i.queue_free()


func validate_folders(path: String) -> void:
	var current_path: String = "user://"
	var as_list: Array = (path.trim_prefix(current_path)).split("/")
	for i in range(as_list.size()):
		current_path += "/" + as_list[i]
		if not DirAccess.dir_exists_absolute(current_path):
			DirAccess.make_dir_absolute(current_path)


func save_state(state: Main.PlayerState, file_name: String = "") -> void:
	if file_name.is_empty():
		file_name = "state" + str($Lists/State/V/Scroll/VBoxContainer.get_child_count() + 1)
	
	var data: Dictionary
	data["items"] = state.prog_items
	data["locations"] = state.checked_locations_serialized()
	FileAccess.open(STATE_PATH % file_name, FileAccess.WRITE).store_string(JSON.stringify(data))


func load_state(file_name: String) -> Main.PlayerState:
	var state := Main.PlayerState.new()
	state.main = Globals.main
	var stringified: String = FileAccess.get_file_as_string(STATE_PATH % file_name)
	var data = JSON.parse_string(stringified)
	state.prog_items.assign(data["items"])
	var locs: Array[LocationPanel] = []
	for i: LocationPanel in $"../LocationRequirements/VBoxContainer".get_children():
		if i.serialize() in data["locations"]:
			locs.append(i)
	state.checked_locations.assign(locs)
	return state


func rename_state(current_name: String, target_name: String) -> void:
	DirAccess.rename_absolute(STATE_PATH % current_name, STATE_PATH % target_name)
	delete_state(current_name)


func delete_state(state_name: String) -> void:
	DirAccess.remove_absolute(STATE_PATH % state_name)


func clear_state() -> void:
	Main.player_state.checked_locations = []
	Main.player_state.prog_items = []


func find_mio_dir() -> String:
	var result: String
	if not OS.has_feature("web"):
		if OS.has_feature("windows"):
			result = OS.get_environment("LOCALAPPDATA") + "\\MIO\\Saves\\Steam"
			result += "\\" + DirAccess.get_directories_at(result)[0]
		elif OS.has_feature("linux"):
			result = OS.get_environment("HOME") + "/.local/share/Steam/steamapps/compatdata/1672810/pfx/drive_c/users/steamuser/AppData/Local/MIO/Saves/Steam/"
			result += "/" + DirAccess.get_directories_at(result)[0]
	return result


func find_mio_saves_path() -> String:
	var result := find_mio_dir()
	if OS.has_feature("windows"):
		result += "\\%s.save"
	elif OS.has_feature("linux"):
		result += "/%s.save"
	return result


func get_mio_saves() -> Array[String]:
	var result: Array[String]
	var folder := DirAccess.open(mio_saves_path.trim_suffix("%s.save"))
	
	if folder:
		folder.list_dir_begin()
		var current := folder.get_next()
		
		while not current.is_empty():
			if not folder.current_is_dir():
				if current.ends_with(".save") and not current.contains("_bck_"):
					result.append(current.get_basename())
			current = folder.get_next()
	
	return result


func save_save(_state: Main.PlayerState, file_name: String = "") -> void:
	if file_name.is_empty():
		file_name = "slot_" + str($Lists/FIle/V/Scroll/VBoxContainer.get_child_count() + 1)
	
	Globals.trigger_popup("This does not work yet")
	
	pass


func load_save(file_name: String) -> Main.PlayerState:
	var state := Main.PlayerState.new()
	var file := FileAccess.open(mio_saves_path.replace("\\", "/") % file_name, FileAccess.READ)
	var contents: String = file.get_as_text()
	var data: Dictionary[String, Array]
	for i: String in Array(contents.split("}\n\n")):
		if i.is_empty():
			continue
		var key: String = i.get_slice(" {\n", 0)
		data[key] = Array(i.get_slice(" {\n", 1).split("\n  "))
		data[key][0] = data[key][0].trim_prefix("  ")
	#print(data["Saved_entries"])
	var leftover_items: Array[Item]
	leftover_items.assign(%ItemPool.get_children())
	
	for data_entry: String in data["Saved_entries"]:
		
		if not data_entry.contains("key") or data_entry.contains("pairs.0.") or data_entry.contains("pairs.1."):
			continue
		var save_entry: String = data_entry.get_slice(".key = String(\"", 1).trim_suffix("\")")
		
		var bad_entry := false
		for i in ["ARENA", "DIALOG", "BOSS_MEET", "BOSS_TRY", "BREAKABLE", "DISCOVERED_ZONE", "DOOR", "FLASHBACK",
				"FLOOR_ELEVATOR", "GAME", "ITEM_DISCOVERED", "ITEM_NOTIF", "TITLE_CARD", "SQUAD", "STATS"]:
			if save_entry in old_core_dialog:
				break
			if save_entry.begins_with(i):
				bad_entry = true
				break
		if bad_entry:
			continue
		
		var item: Item
		for test_item in leftover_items:
			if test_item.save_entry == save_entry:
				item = test_item
				leftover_items.erase(item)
				break
		if item == null:
			continue
		state.prog_items.append(item.item_name)
	
	return state


func make_meta_file(from: StatePanel) -> void:
	pass


func _on_new_state_pressed() -> void:
	save_state(Main.player_state)
	
	update_display()


func _on_delete_state_button_toggled(toggled_on: bool) -> void:
	toggle_delete.emit(toggled_on)


func _on_difference_pressed() -> void:
	var page := InfoPage.new()
	page.name = "States VS Save Files"
	page.text = """
# States VS Save Files

#### States
States are this map's way of saving your progress. It is a type native to this, and only usable to this.
It stores the items you set and the locations you've checked.
It does not store any archipelago information, that will be automatically restored when you re-connect to the server.

#### Save Files
These are saves that mio can actually read.
It also doesn't store any archipelago information.
"""
	get_parent().get_node("Info").add_page_node(page)
	get_parent().get_node("Info").select_last_page()


func _on_mode_option_item_selected(index: int) -> void:
	update_display()
	await get_tree().process_frame
	mode_changed.emit(index)
