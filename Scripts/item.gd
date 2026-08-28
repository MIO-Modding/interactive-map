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
	$Amount.value = get_node("/root/Main").player_state.prog_items.count(item_name)
