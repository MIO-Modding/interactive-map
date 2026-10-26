class_name Settings extends Control


var presets: Array[TabsPreset] = [
	TabsPreset.new("Map Only", "For those who only want to look at the map", ["Map", "Info"]),
	TabsPreset.new("Basic", "The tabs you would most likely need", ["PlayerState", "Map", "Info", "Saves", "Links"]),
	TabsPreset.new("Archipelago", "Tabs for using archipelago", ["PlayerState", "Map", "Info", "ArchipelagoClient", "Saves", "Rando", "PopupHistory", "Links"]),
	TabsPreset.new("Sheets", "For reading the dev sheets", ["RoomRequirements", "Items", "TransitionRequirements", "LocationRequirements", "NonLocationComponents", "Links"]),
]

@onready var versions_option: OptionButton = $ScrollContainer/VBoxContainer/DataSettings/VBoxContainer/ArchipelagoData/VBoxContainer/HBoxContainer/Versions


func _ready() -> void:
	for preset: TabsPreset in presets:
		$ScrollContainer/VBoxContainer/ShownTabsFoldable/VBoxContainer/SetPreset.add_item(preset.preset_name)
	
	for tab: Control in get_parent().get_children():
		var toggle := CheckButton.new()
		toggle.text = str(tab.name)
		toggle.button_pressed = true
		toggle.toggled.connect(tab_toggle_toggled.bind(tab.get_index()))
		toggle.toggled.connect(Globals.main.save_all_preferences.unbind(1))
		if tab == self:
			toggle.disabled = true
		$ScrollContainer/VBoxContainer/ShownTabsFoldable/VBoxContainer.add_child(toggle)
	
	var temp: Array[String]
	temp.assign(presets[0].tabs)
	choose_tab_set(temp)
	await Globals.main.finished_requesting
	for type in RevertBox.get_all_setting_sections():
		var box := RevertBox.new(type)
		$ScrollContainer/VBoxContainer/RevertFoldable/VBoxContainer.add_child(box)
	get_parent().current_tab = 6
	await Globals.main.finished_other_requests
	
	update_available_ap_data()


func tab_toggle_toggled(toggled_on: bool, tab_idx: int) -> void:
	get_parent().set_tab_hidden(tab_idx, not toggled_on)


func toggle_tab_with_set(toggled_on: bool, tab_idx: int) -> void:
	tab_toggle_toggled(toggled_on, tab_idx)
	$ScrollContainer/VBoxContainer/ShownTabsFoldable/VBoxContainer.get_child(tab_idx + 1).set_pressed_no_signal(toggled_on)


func toggle_all_shown_tabs(toggled_on: bool) -> void:
	for tab: Control in get_parent().get_children():
		if tab == self:
			continue
		toggle_tab_with_set(toggled_on, tab.get_index())


func toggle_tab_by_name(toggled_on: bool, tab_name: String) -> void:
	if get_parent().has_node(tab_name):
		toggle_tab_with_set(toggled_on, get_parent().get_node(tab_name).get_index())


func choose_tab_set(set_list: Array[String]) -> void:
	toggle_all_shown_tabs(false)
	for i in set_list:
		toggle_tab_by_name(true, i)


func get_visible_tabs() -> Array[String]:
	var result: Array[String]
	result.assign(range(get_parent().get_tab_count()).filter(func(e): return not get_parent().is_tab_hidden(e)).map(func(e): return str(get_parent().get_child(e).name)))
	return result


func update_available_ap_data() -> void:
	Globals.main.ap_data_available.clear()
	for folder in DirAccess.get_directories_at("user://Data/APData"):
		Globals.main.ap_data_available.append(folder)
	
	for i in range(versions_option.item_count):
		versions_option.set_item_icon(i, preload("res://Sprites/ui/diamond_checked.svg") 
				if Globals.main.ap_data_available.has(versions_option.get_item_text(i)) else preload("res://Sprites/ui/diamond.svg"))
	
	_on_versions_item_selected(versions_option.selected)


func request_ap_data(version: String) -> void:
	var app_res := Globals.main.get_application_res("Mio Archipelago")
	assert(version in app_res.release_tags)
	while Globals.main.requester_busy:
		await Globals.main.get_child(-1).request_completed
		await get_tree().process_frame
	
	Globals.main.requester_busy = true
	Globals.main.get_child(-1).request_completed.connect(recieve_ap_data.bind(version), CONNECT_ONE_SHOT)
	Globals.main.get_child(-1).request("https://github.com/%s/releases/download/v%s/devsheet.xlsx" % [app_res.repo, version])


func recieve_ap_data(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, version: String) -> void:
	Globals.main.requester_busy = false
	if response_code == 404:
		return
	var folder_path: String = "user://Data/APData/" + version
	if not DirAccess.dir_exists_absolute(folder_path):
		DirAccess.make_dir_absolute(folder_path)
	var data := XlsxParser.parse_data(body)
	for sheet: String in data["sheets"]:
		var lowered: String = sheet.to_lower()
		if lowered.replace("bosscombat", "boss/combat") in Main.DATA_LINKS:
			var file := FileAccess.open("%s/%s.csv" % [folder_path, lowered], FileAccess.WRITE)
			file.store_csv_line(PackedStringArray(data["sheets"][sheet]["headers"]))
			for row: PackedStringArray in data["sheets"][sheet]["rows"]:
				file.store_csv_line(row)
			file.close()
	update_available_ap_data()


func _on_file_loc_pressed() -> void:
	if not OS.has_feature("web"):
		OS.shell_open(ProjectSettings.globalize_path("user://Data/"))


func _on_set_preset_item_selected(index: int) -> void:
	match index:
		0:
			toggle_all_shown_tabs(true)
		1:
			toggle_all_shown_tabs(false)
		2:
			pass
		_:
			var list: Array[String]
			list.assign(presets[index - 3].tabs)
			choose_tab_set(list)
	Globals.main.save_all_preferences()


func _on_ui_scale_drag_ended(value_changed: bool) -> void:
	if value_changed:
		var value: float = $ScrollContainer/VBoxContainer/GraphicsFoldable/VBoxContainer/UiScale.value
		value = clampf(value, 0.5, 4.0)
		$ScrollContainer/VBoxContainer/GraphicsFoldable/VBoxContainer/UiScale.value = value
		get_tree().root.content_scale_factor = value


func _on_revert_all_pressed() -> void:
	for setting in Globals.main.default_preferences:
		Globals.main.set_preference(setting, Globals.main.default_preferences[setting])


func _on_delete_all_pressed() -> void:
	if FileAccess.file_exists("user://Data/prefs.dat"):
		DirAccess.remove_absolute("user://Data/prefs.dat")
	_on_quit_pressed()


func _on_install_ap_data_pressed() -> void:
	request_ap_data(versions_option.get_item_text(versions_option.selected))


func _on_load_pressed() -> void:
	var app_res := Globals.main.get_application_res("Mio Archipelago")
	var version := versions_option.get_item_text(versions_option.selected)
	assert(version in app_res.release_tags)
	var path: String = "user://Data/APData/%s/" % version
	assert(DirAccess.dir_exists_absolute(path))
	
	Globals.main.clear_all_data()
	var overrides: Dictionary[String, String] = get_parent().get_node("Saves").grab_overrides(path)
	for key in Main.DATA_LINKS:
		if key in overrides:
			Globals.main.on_finished_request(0, 0, [], overrides[key].to_utf8_buffer(), key)


func _on_versions_item_selected(index: int) -> void:
	var app_res := Globals.main.get_application_res("Mio Archipelago")
	$ScrollContainer/VBoxContainer/DataSettings/VBoxContainer/ArchipelagoData/VBoxContainer/HBoxContainer/Load.disabled = not versions_option.get_item_text(index) in app_res.release_tags


func _on_quit_pressed() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("location.reload()")
	else:
		get_tree().quit()


class TabsPreset extends Resource:
	var preset_name: String
	var description: String
	var tabs: Array[String]
	
	
	func _init(name_val: String, desc_value: String, tabs_value: Array[String]) -> void:
		preset_name = name_val
		description = desc_value
		tabs = tabs_value
