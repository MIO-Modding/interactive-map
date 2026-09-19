extends Control


const PRESETS: Array[Array] = [
	["PlayerState", "Map", "Info", "Saves"],
	["PlayerState", "Map", "Info", "ArchipelagoClient", "Saves", "Rando"],
	["RoomRequirements", "Items", "TransitionRequirements", "LocationRequirements"],
]


func _ready() -> void:
	for tab: Control in get_parent().get_children():
		var toggle := CheckButton.new()
		toggle.text = str(tab.name)
		toggle.toggled.connect(tab_toggle_toggled.bind(tab.get_index()))
		toggle.button_pressed = true
		if tab == self:
			toggle.disabled = true
		$ScrollContainer/VBoxContainer/ShownTabsFoldable/VBoxContainer.add_child(toggle)


func tab_toggle_toggled(toggled_on: bool, tab_idx: int) -> void:
	get_parent().set_tab_hidden(tab_idx, not toggled_on)


func toggle_tab_with_set(toggled_on: bool, tab_idx: int) -> void:
	tab_toggle_toggled(toggled_on, tab_idx)
	$ScrollContainer/VBoxContainer/ShownTabsFoldable/VBoxContainer.get_child(tab_idx + 1).button_pressed = toggled_on


func toggle_all_shown_tabs(toggled_on: bool) -> void:
	for tab: Control in get_parent().get_children():
		if tab == self:
			continue
		toggle_tab_with_set(toggled_on, tab.get_index())


func toggle_tab_by_name(toggled_on: bool, tab_name: String) -> void:
	toggle_tab_with_set(toggled_on, get_parent().get_node(tab_name).get_index())


func choose_tab_set(set_list: Array[String]) -> void:
	toggle_all_shown_tabs(false)
	for i in set_list:
		toggle_tab_by_name(true, i)


func _on_file_loc_pressed() -> void:
	if not OS.has_feature("web"):
		OS.shell_open(ProjectSettings.globalize_path("user://Data/"))


func _on_set_preset_item_selected(index: int) -> void:
	match index:
		0:
			toggle_all_shown_tabs(true)
		1:
			toggle_all_shown_tabs(false)
		_:
			var list: Array[String]
			list.assign(PRESETS[index - 2])
			choose_tab_set(list)
