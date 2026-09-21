class_name StartInventoryCheckBox extends ExcludeLocationsCheckBox


@export var start_dict: Dictionary[String, int]
## Set to a save entry category
@export var start_type := ""


static func convert_to_dict_entry(value: Dictionary[String, int]) -> String:
	if value.is_empty():
		return "{}"
	var result: String = ""
	for i in value:
		result += "\n    %s: %d" % [i, value[i]]
	return result


func get_entire_pool() -> Dictionary[String, int]:
	var result: Dictionary[String, int] = {}
	if not button_pressed:
		return result
	result.assign(start_dict)
	
	for item: Item in %ItemPool.get_children():
		if item.save_entry.get_slice(":", 0) == start_type:
			result[Main.PlayerState.get_manual_item_name(item)] = item.max_amount
	
	return result
