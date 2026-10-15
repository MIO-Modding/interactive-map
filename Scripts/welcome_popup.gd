extends PanelContainer



func _ready() -> void:
	for preset: Settings.TabsPreset in get_presets():
		$VBoxContainer/Options.add_item_check(preset.preset_name)
	$VBoxContainer/Options.select(0)
	$VBoxContainer/Options.item_selected.emit(0)
	
	await Globals.main.finished_requesting
	if not Globals.main.get_preference("MISC>WELCOMED"):
		show()


func get_presets() -> Array[Settings.TabsPreset]:
	return $"../TabContainer/Settings".presets


func get_preset_by_name(preset_name: String) -> Settings.TabsPreset:
	for preset: Settings.TabsPreset in get_presets():
		if preset.preset_name == preset_name:
			return preset
	return null


func update_shown_tabs() -> void:
	var text := "Will show tabs: "
	var current_tabs: Array[String] = get_chosen_tabs()
	match current_tabs.size():
		0:
			text = "Will show no tabs"
		1:
			text = "Will show the '%s' tab" % current_tabs[0]
		2:
			text += current_tabs[0] + " and " + current_tabs[1]
		_:
			text += current_tabs.pop_front()
			var back: String = current_tabs.pop_back()
			for tab: String in current_tabs:
				text += ", " + tab
			text += ", and " + back
	
	$VBoxContainer/ShownTabs.text = text


func get_chosen_tabs() -> Array[String]:
	var result: Array[String]
	for preset_name: String in $VBoxContainer/Options.get_all_checked():
		for tab: String in get_preset_by_name(preset_name).tabs:
			if not tab in result:
				result.append(tab)
	return result


func _on_options_item_selected(index: int) -> void:
	var preset: Settings.TabsPreset = get_presets()[index]
	$VBoxContainer/Description.text = preset.description
	await get_tree().process_frame
	update_shown_tabs()


func _on_confirm_pressed() -> void:
	hide()
	Globals.main.set_preference("MISC>WELCOMED", true)
	$"../TabContainer/Settings".choose_tab_set(get_chosen_tabs())
