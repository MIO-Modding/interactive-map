class_name SavesMenu extends Control


signal toggle_delete(on: bool)

const STATE_PATH: String = "user://Data/Saves/States/%s.dat"
const SAVE_FILES_PATH: String = "user://Data/Saves/SaveFiles/%s.dat"

var mio_saves_path: String


func _ready() -> void:
	for i in [STATE_PATH, SAVE_FILES_PATH]:
		validate_folders(i.trim_suffix("%s.dat"))
	
	Globals.main.finished_requesting.connect(update_display)
	mio_saves_path = find_mio_saves_path()


func update_display() -> void:
	for i in $Lists/State/V/Scroll/VBoxContainer.get_children():
		i.queue_free()
	
	var list: Array[String]
	list.assign(Array(DirAccess.get_files_at(STATE_PATH.trim_suffix("%s.dat"))))
	
	list.sort_custom(func(str1: String, str2: String): return str1.naturalnocasecmp_to(str2) < 0)
	
	for i in list:
		var state_panel := await StatePanel.new()
		state_panel.text = i.get_basename()
		state_panel.call_deferred("toggle_delete", $Lists/State/V/DeleteButton.button_pressed)
		$Lists/State/V/Scroll/VBoxContainer.add_child(state_panel)


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
			result = "./.local/share/Steam/steamapps/compatdata/1672810/pfx/drive_c/users/steamuser/AppData/Local/MIO/Saves/Steam/"
			result += "/" + DirAccess.get_directories_at(result)[0]
	return result


func find_mio_saves_path() -> String:
	var result := find_mio_dir()
	if OS.has_feature("windows"):
		result += "\\%s.save"
	elif OS.has_feature("linux"):
		result += "/%s.save"
	return result


func save_save(state: Main.PlayerState) -> void:
	pass


func _on_new_state_pressed() -> void:
	save_state(Main.player_state)
	
	update_display()


func _on_delete_state_button_toggled(toggled_on: bool) -> void:
	toggle_delete.emit(toggled_on)
