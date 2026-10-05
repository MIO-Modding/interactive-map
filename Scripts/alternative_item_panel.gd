class_name AlternativeItemPanel extends PanelContainer


var item: Item


func _ready() -> void:
	setup()
	update()


func setup() -> void:
	set_texture()
	$H/Name.text = item.item_name
	$H/Name.self_modulate = Item.COLORS[item.classification]
	if item.type == Item.ItemTypes.EVENT:
		$H/Name.self_modulate = Item.COLORS[Item.ItemTypes.EVENT]


func update(grid_type: int = 0) -> void:
	$H/Name.text = item.get_node("Name").text
	visible = item.visible
	modulate = Color.WHITE if item.highlighted else Color(0.5, 0.5, 0.5)
	
	match grid_type:
		0:
			$H/Name.show()
			custom_minimum_size = Vector2.ZERO
		1:
			$H/Name.hide()
			custom_minimum_size = Vector2.ONE * 100


func set_texture() -> void:
	if Main.MAP_ICON_TEXTURES.has(item.category):
		$H/Sprite.texture = Main.MAP_ICON_TEXTURES[item.category]
	else:
		$H/Sprite.texture = Main.MAP_ICON_TEXTURES["Misc"]
