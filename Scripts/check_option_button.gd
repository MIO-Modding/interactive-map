class_name CheckOptionButton extends OptionButton


var checks: Array[bool]


func _ready() -> void:
	item_selected.connect(func(idx: int): check_item(idx))


func add_item_check(label: String, id: int = -1, checked := false) -> void:
	checks.append(checked)
	add_icon_item(get_check_image(checked), label, id)


func remove_item_check(idx: int) -> void:
	checks.remove_at(idx)
	remove_item(idx)


func check_item(idx: int, value: Variant = null) -> void:
	checks[idx] = (not checks[idx]) if value == null else bool(value)
	set_item_icon(idx, get_check_image(checks[idx]))


func get_check_image(checked: bool) -> Texture2D:
	return preload("res://Sprites/ui/diamond_checked.svg") if checked else preload("res://Sprites/ui/diamond.svg")


func get_all_checked(checked := true) -> Array[String]:
	var result: Array[String] = []
	for i in range(checks.size()):
		if checks[i] == checked:
			result.append(get_item_text(i))
	return result
