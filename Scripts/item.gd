class_name Item extends HBoxContainer



enum ItemTypes {
	ITEM = 100,
	EVENT
}
enum ItemClassifications {
	PROGRESSION,
	USEFUL,
	FILLER,
	TRAP
}
const COLORS = {
	ItemClassifications.PROGRESSION: Color("d4edbc"),
	ItemClassifications.USEFUL: Color("ffe5a0"),
	ItemClassifications.FILLER: Color("e6cff2"),
	ItemClassifications.TRAP: Color("b10202"),
	ItemTypes.ITEM: Color("bfe1f6"),
	ItemTypes.EVENT: Color("ffc8aa")
}



var item_name: String:
	set(value):
		item_name = value
		$Name.text = value
var max_amount: int:
	set(value):
		value = clampi(value, 1, value)
		max_amount = value
		$Amount.max_value = value
var room: String
var type: ItemTypes = ItemTypes.ITEM:
	set(value):
		type = value
		if value == ItemTypes.EVENT:
			$Name.self_modulate = COLORS[ItemTypes.EVENT]
var classification: ItemClassifications:
	set(value):
		classification = value
		if type != ItemTypes.EVENT:
			$Name.self_modulate = COLORS[value]
var save_entry: String


func update() -> void:
	$Amount.value = $/root/Main.player_state.prog_items.count(item_name)
	$ApLabel.text = "AP: %d/%d" % [Globals.main.player_state.ap_prog_items.count(item_name), max_amount]
	
	$ApLabel.visible = Archipelago.is_ap_connected()
	$Amount.visible = not max_amount == 1
	$Toggle.visible = max_amount == 1
	$Toggle.set_pressed_no_signal($Amount.value > 0)


func _on_amount_value_changed(value: float) -> void:
	var amount: int = roundi(value)
	$/root/Main.player_state.prog_items = $/root/Main.player_state.prog_items.filter(func(e): return e != item_name)
	for i in amount:
		$/root/Main.player_state.prog_items.append(item_name)
	$/root/Main.update_itempool.emit()


func _on_toggle_toggled(toggled_on: bool) -> void:
	if toggled_on:
		if not $/root/Main.player_state.prog_items.has(item_name):
			$/root/Main.player_state.prog_items.append(item_name)
	else:
		$/root/Main.player_state.prog_items.erase(item_name)
	$/root/Main.update_itempool.emit()
