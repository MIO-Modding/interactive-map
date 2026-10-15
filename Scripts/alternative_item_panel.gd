class_name AlternativeItemPanel extends PanelContainer


var item: Item = null

var item_category: String = ""


func _init(item_value: Item = null, category_value: String = "") -> void:
	item = item_value
	item_category = category_value


func _ready() -> void:
	setup()
	update()


func setup() -> void:
	set_texture()
	if item_category.is_empty():
		$H/Name.text = item.item_name
		$H/Name.self_modulate = Item.COLORS[item.classification]
		if item.type == Item.ItemTypes.EVENT:
			$H/Name.self_modulate = Item.COLORS[Item.ItemTypes.EVENT]
	else:
		$H/Name.text = item_category
		$H/Name.self_modulate = Item.COLORS[first_item_in_category().classification]


func update(grid_type: int = 0) -> void:
	if item_category.is_empty():
		$H/Name.text = item.get_node("Name").text
		visible = item.visible
		modulate = Color.WHITE if item.highlighted else Color(0.5, 0.5, 0.5)
	else:
		$H/Name.text = item_category
		visible = any_items_can(func(e): return e.visible)
		modulate = Color.WHITE if any_items_can(func(e): return e.highlighted) else Color(0.5, 0.5, 0.5)
		
		var items := get_items_in_category()
		var logic: Callable = func(e: Item): return Main.player_state.prog_items.has(e.item_name)
		if Archipelago.is_ap_connected():
			logic = func(e: Item): return Main.player_state.prog_items.has(e.item_name)
		$Control/Amount.text = str(items.filter(logic).size()) + "/" + str(items.size())
	
	match grid_type:
		0:
			$H/Name.show()
			custom_minimum_size = Vector2.ZERO
		1:
			$H/Name.hide()
			custom_minimum_size = Vector2.ONE * 100


func first_item_in_category() -> Item:
	if item_category.is_empty():
		return null
	for i: Item in Globals.main.get_node("%ItemPool").get_children():
		if i.category == item_category:
			return i
	return null


func get_items_in_category() -> Array[Item]:
	if item_category.is_empty():
		return []
	var result: Array[Item]
	for i: Item in Globals.main.get_node("%ItemPool").get_children():
		if i.category == item_category:
			result.append(i)
	return result


func any_items_can(method: Callable, all := false) -> bool:
	if item_category.is_empty():
		return false
	for i: Item in get_items_in_category():
		if method.call(i) != all:
			return not all
	return all


func set_texture() -> void:
	var catg: String
	
	catg = item.category if item_category.is_empty() else item_category
	
	if Main.MAP_ICON_TEXTURES.has(catg):
		$H/Sprite.texture = Main.MAP_ICON_TEXTURES[catg]
	else:
		$H/Sprite.texture = Main.MAP_ICON_TEXTURES["Misc"]
