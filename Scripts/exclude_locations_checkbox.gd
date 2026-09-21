class_name ExcludeLocationsCheckBox extends CheckBox


@export var exclude_list: Array[String]
@export var exclude_type := ""


func get_entry() -> String:
	return convert_to_entry(get_all_exclusions())


static func convert_to_entry(value: Array[String]) -> String:
	if value.is_empty():
		return "[]"
	return "\n  - ".join([""] + value)


func get_all_exclusions() -> Array[String]:
	var result: Array[String] = []
	if not button_pressed:
		return result
	result.assign(exclude_list)
	
	for loc: LocationPanel in Globals.main.get_node("TabContainer/LocationRequirements/VBoxContainer").get_children():
		if loc.type == exclude_type:
			result.append(Main.PlayerState.get_manual_serialized(loc, true))
	
	return result
