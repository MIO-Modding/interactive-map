extends Control


const BASE_PATH: String = "user://Data/%s.dat"


func save_state(state: Main.PlayerState, file_name: String = "") -> void:
	if file_name.is_empty():
		file_name = "state" + str($Lists/State/V/Scroll/VBoxContainer.get_child_count() - 1)
	
	var data: Dictionary
	data["items"] = state.prog_items
	data["locations"] = state.checked_locations_serialized()
	FileAccess.open(BASE_PATH % file_name, FileAccess.WRITE).store_string(JSON.stringify(data))


func load_state(file_name: String) -> Main.PlayerState:
	var state := Main.PlayerState.new()
	var stringified: String = FileAccess.get_file_as_string(BASE_PATH % file_name)
	var data = JSON.parse_string(stringified)
	state.prog_items = data["items"]
	var locs: Array[LocationPanel] = []
	for i: LocationPanel in $"../LocationRequirements/VBoxContainer".get_children():
		if i.serialize() in data["locations"]:
			locs.append(i)
	state.checked_locations.assign(locs)
	return state


func rename_state(current_name: String, target_name: String) -> void:
	DirAccess.rename_absolute(BASE_PATH % current_name, BASE_PATH % target_name)
	delete_state(current_name)


func delete_state(state_name: String) -> void:
	DirAccess.remove_absolute(BASE_PATH % state_name)


func clear_state() -> void:
	Main.player_state.checked_locations = []
	Main.player_state.prog_items = []


func _on_new_state_pressed() -> void:
	pass # Replace with function body.
