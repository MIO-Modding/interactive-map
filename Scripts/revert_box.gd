class_name RevertBox extends FoldableContainer


@export var setting_section: String


func _init(section: String = "") -> void:
	setting_section = section


func _ready() -> void:
	fold()
	
	if get_child_count() == 0:
		add_child(VBoxContainer.new())
		await get_tree().process_frame
		var all_button := Button.new()
		all_button.text = "All"
		all_button.pressed.connect(revert_all_settings)
		get_child(0).add_child(all_button)
	
	for setting in get_all_settings().map(func(e): return e.get_slice(">", 1)):
		var button := Button.new()
		button.text = "Revert " + setting.capitalize()
		button.pressed.connect(revert_setting.bind(setting))
		get_child(0).add_child(button)
	
	title = setting_section.capitalize()


static func get_all_setting_sections() -> Array[String]:
	var result: Array[String]
	for setting in Globals.main.default_preferences:
		var type := setting.get_slice(">", 0)
		if not result.has(type):
			result.append(type)
	return result


func get_all_settings() -> Array[String]:
	return Globals.main.default_preferences.keys().filter(func(e): return e.get_slice(">", 0) == setting_section)


func revert_setting(setting: String) -> void:
	var full_entry: String = setting_section + ">" + setting
	Globals.main.set_preference(full_entry, Globals.main.default_preferences[full_entry])


func revert_all_settings() -> void:
	for setting: String in get_all_settings():
		revert_setting(setting)
